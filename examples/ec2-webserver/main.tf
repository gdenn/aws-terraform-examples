locals {
  availability_zone = "eu-central-1a"
  instance_type = "t3.micro"
  environment = "sdlc"
  region = "eu-central-1"
}

module "vpc" {
  source = "../../modules/vpc"
  profile = var.profile
  environment = local.environment
  region = local.region
  availability_zones = [ local.availability_zone ]
  vpc_name = "ec2-webserver-vpc"
}

#####################################################
# EC2 WEB SERVER
#####################################################

resource "aws_instance" "web_server" {
  ami               = data.aws_ami.amzn2.id
  instance_type     = local.instance_type
  user_data = templatefile("user-data.sh", {})
  subnet_id = element(module.vpc.web_subnet, 0)

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  depends_on = [
    aws_iam_role_policy_attachment.smm_policy_attachment,
    aws_iam_role_policy_attachment.cw_agent_policy_attachment
  ]

  root_block_device {
    delete_on_termination = true
    volume_type = "gp3"
    volume_size = "8"
  }

  tags = {
    Environment = local.environment
    Name        = "ec2-web-server"
  }
}

#####################################################
# EC2 INSTANCE PROFILE
#####################################################

resource "aws_iam_instance_profile" "instance_profile" {
  name = "web-server-instance-profile"
  role = aws_iam_role.instance_profile.name
}

resource "aws_iam_role" "instance_profile" {
  name = "web-server-instance-profile"
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
        Sid = ""
      },
    ]
  })
}

resource "aws_iam_policy" "cw_agent_policy" {
  name = "cw-agent-policy"
  path = "/"
  description = "policy to alow ec2 instance to push metrics and logs to CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Effect = "Allow",
        Resource = [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_agent_policy_attachment" {
  role = aws_iam_role.instance_profile.name
  policy_arn = aws_iam_policy.cw_agent_policy.arn
}

resource "aws_iam_role_policy_attachment" "smm_policy_attachment" {
  role = aws_iam_role.instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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
# ALB
#####################################################