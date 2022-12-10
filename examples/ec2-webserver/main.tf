locals {
  availability_zone  = "eu-central-1a"
  availability_zone2 = "eu-central-1b"
  instance_type      = "t3.micro"
  environment        = "sdlc"
  region             = "eu-central-1"
}

module "vpc" {
  source             = "../../modules/vpc"
  profile            = var.profile
  environment        = local.environment
  region             = local.region
  availability_zones = [local.availability_zone, local.availability_zone2]
  vpc_name           = "ec2-webserver-vpc"
  log_group_name     = "web-server-vpc-flow-logs"
}

#####################################################
# EC2 WEB SERVER
#####################################################

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amzn2.id
  instance_type = local.instance_type
  user_data     = templatefile("user-data.sh", {})
  subnet_id     = element(module.vpc.web_subnet, 0)

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  depends_on = [
    aws_iam_role_policy_attachment.smm_policy_attachment,
    aws_iam_role_policy_attachment.cw_agent_policy_attachment
  ]

  security_groups = [aws_security_group.web_server_sg.id]

  root_block_device {
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = "8"
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
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_policy" "cw_agent_policy" {
  name        = "cw-agent-policy"
  path        = "/"
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
  role       = aws_iam_role.instance_profile.name
  policy_arn = aws_iam_policy.cw_agent_policy.arn
}

resource "aws_iam_role_policy_attachment" "smm_policy_attachment" {
  role       = aws_iam_role.instance_profile.name
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
# WEB SERVER SECURITY GROUP
#####################################################

resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "allow http traffic from alb"
  vpc_id      = module.vpc.vpc_id
  ingress = [
    {
      description      = "allow http from alb"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      security_groups  = [aws_security_group.alb_security_group.id]
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
    }
  ]
}

#####################################################
# ALB SECURITY GROUP
#####################################################

resource "aws_security_group" "alb_security_group" {
  name        = "alb-security-group"
  description = "alb security group"
  vpc_id      = module.vpc.vpc_id
  ingress = [
    {
      description      = "allow https traffic from the internet"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
  egress = [
    {
      description      = "allow http traffic to web server ec2 instance"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "allow https traffic to web server ec2 instance"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}

#####################################################
# ALB TARGET GROUP
#####################################################
resource "aws_lb_target_group" "web_server_target_group" {
  name        = "web-server-target-group"
  port        = 80
  target_type = "instance"
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id

  health_check {
    healthy_threshold = 3
    unhealthy_threshold = 3
    interval = 20
    timeout = 5
  }
}

resource "aws_alb_target_group_attachment" "web_server_target_group_attachement" {
  count            = length(aws_instance.web_server)
  target_group_arn = aws_lb_target_group.web_server_target_group.arn
  target_id        = element(aws_instance.web_server.*.id, count.index)
  port             = 80
}

#####################################################
# ALB
#####################################################
resource "aws_alb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = module.vpc.web_subnet
}

#####################################################
# ALB LISTENER
#####################################################
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_server_target_group.arn
  }
}