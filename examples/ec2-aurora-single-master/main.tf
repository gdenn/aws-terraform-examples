locals {

  availability_zones = data.aws_availability_zones.azs.*.name

  # aurora
  db_port           = 3306
  db_engine_version = var.aurora_engine_version ? var.aurora_engine_version : data.aws_rds_engine_version.aurora_version.name

  # ec2 instance
  ec2_instance_type     = "t3.micro"
  ec2_volume_type       = "gp3"
  ec2_volume_size_in_gb = "8"

  # naming conventions
  app_prefix     = "${var.organization_prefix}-${var.app_id}"
  stack_prefix   = "${app_prefix}-aurora"
  log_group_name = "${app_prefix}-logs"
  vpc_name       = "${app_prefix}-vpc"

  # following AWS best practices
  # https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/defining-and-publishing-a-tagging-schema.html
  tags = {
    "${var.organization_prefix}:automation:EnvironmentId"      = var.environment_id
    "${var.organization_prefix}:disaster-recovery:rpo"         = var.rpo
    "${var.organization_prefix}:data:classification"           = var.data_classification
    "${var.organization_prefix}:cost-allocation:ApplicationId" = var.app_id
    "${var.organization_prefix}:access-control:LayerId"        = "data_Layer"
  }
}

data "aws_availability_zones" "azs" {
  state = "available"
}

#####################################################
# VPC
#####################################################

module "vpc" {
  source             = "../../modules/vpc"
  profile            = var.profile
  environment        = var.environment_id
  region             = var.region
  log_group_name     = local.log_group_name
  availability_zones = local.availability_zones
  vpc_name           = local.vpc_name
}

#####################################################
# AURORA CLUSTER
#####################################################

# for Aurora cluster VPC deployment
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name        = "${stack_prefix}-subnet-group"
  description = "subnet group for the aurora cluster"

  # put RDBMS into a private, isolated subnet
  # (no route to NGW or ING) 
  subnet_ids = module.vpc.data_subnet

  tags = local.tags
}

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier   = "${stack_prefix}-cluster"
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name
  engine               = var.aurora_engine
  engine_version       = local.db_engine_version

  backup_retention_period = var.backup_retention_in_days
  preferred_backup_window = var.preffered_backup_window
  skip_final_snapshot     = false # take a snapshot before deleting the aurora cluster

  database_name   = var.database_name
  master_password = var.master_password
  master_username = var.master_username

  storage_encrypted = true
  kms_key_id        = aws_kms_key.aurora_encryption_key.arn

  vpc_security_group_ids          = [aws_security_group.aurora_ingress_from_ec2_sg.id]
  db_cluster_parameter_group_name = aws_db_parameter_group.aurora_cluster_parameter_group.name

  tags = local.tags
}

resource "aws_rds_cluster_instance" "aurora_cluster_instance" {
  count          = var.cluster_instance_count
  identifier     = "${stack_prefix}-cluster-instance-${count.index}"
  instance_class = var.cluster_instance_type

  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  engine             = aws_rds_cluster.aurora_cluster.engine
  engine_version     = aws_rds_cluster.aurora_cluster.engine_version

  tags = local.tags
}

resource "aws_db_parameter_group" "aurora_cluster_parameter_group" {
  name        = "${stack_prefix}-cluster"
  family      = "aurora5.6"
  description = "RDS default cluster parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

data "aws_rds_engine_version" "aurora_version" {
  engine = var.aurora_engine

  filter {
    name   = "engine-mode"
    values = ["serverless"]
  }
}

resource "aws_kms_key" "aurora_encryption_key" {
  description         = "encrpytion key for aurora databsae"
  is_enabled          = true
  enable_key_rotation = true

  tags = local.tags
}

#####################################################
# SSM PARAMETERS
#####################################################

resource "aws_ssm_parameter" "aurora_writer_endpoint" {
  name  = "${stack_prefix}-writer-endpoint"
  type  = "String"
  value = aws_rds_cluster.aurora_cluster.endpoint

  tags = local.tags
}

resource "aws_ssm_parameter" "aurora_reader_endpoint" {
  name  = "${stack_prefix}-reader-endpoint"
  type  = "String"
  value = aws_rds_cluster.aurora_cluster.reader_endpoint

  tags = local.tags
}

resource "aws_ssm_parameter" "aurora_master_password" {
  name  = "${stack_prefix}-master-password"
  type  = "SecureString"
  value = var.master_password

  tags = local.tags
}

resource "aws_ssm_parameter" "aurora_master_username" {
  name  = "${stack_prefix}-master-username"
  type  = "String"
  value = var.master_username

  tags = local.tags
}

#####################################################
# EC2 INSTANCE
#####################################################

resource "aws_instance" "instance" {
  ami           = data.aws_ami.amzn2.id
  instance_type = local.ec2_instance_type1
  user_data     = templatefile("user-data.sh", {})
  subnet_id     = element(module.vpc.web_subnet, 0)

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  depends_on = [
    aws_iam_role_policy_attachment.smm_policy_attachment,
  ]

  security_groups = [aws_security_group.ec2_egress_to_aurora_sg.id]

  root_block_device {
    delete_on_termination = true
    volume_type           = local.ec2_volume_type
    volume_size           = local.ec2_volume_size_in_gb
  }

  tags = local.tags
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${stack_prefix}-ec2-instance-profile"
  role = aws_iam_role.instance_profile.name

  tags = local.tags
}

resource "aws_iam_role" "instance_profile" {
  name = "${stack_prefix}-ec2-instance-profile-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "rds_full_access_policy_attachment" {
  role       = aws_iam_role.instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ec2_ssh_via_ssm_policy_attachment" {
  role       = aws_iam_role.instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

  tags = local.tags
}

data "aws_ami" "amzn2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"]
}

#####################################################
# SECURITY GROUPS
#####################################################

resource "aws_security_group" "ec2_egress_to_aurora_sg" {
  name = "${stack_prefix}-ec2-egress-to-aurora-sg"

  description = "allow egress to tcp/${local.db_port} to aurora db"
  vpc_id      = module.vpc.vpc_id

  egress = [
    {
      description      = "allow egress to aurora db"
      from_port        = local.db_port
      to_port          = local.db_port
      protocol         = "tcp"
      security_groups  = [aws_security_group.aurora_ingress_from_ec2_sg.id]
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
    }
  ]

  tags = local.tags
}

resource "aws_security_group" "aurora_ingress_from_ec2_sg" {
  name = "${stack_prefix}-aurora-ingress-from-ec2-sg"

  description = "allow ingress from tcp/${local.db_port} from ec2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress = [
    {
      description      = "allow egress to aurora db"
      from_port        = local.db_port
      to_port          = local.db_port
      protocol         = "tcp"
      security_groups  = [aws_security_group.ec2_egress_to_aurora_sg.id]
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
    }
  ]

  tags = local.tags
}