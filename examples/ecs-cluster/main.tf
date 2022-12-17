locals {
  container_name = "hello_world_service"
  container_image = "express-hello-world"
  container_port = 8080
  host_port = 8080
  task_memory = 2048
  task_cpu = 512
  service_desired_count = 1
  service_name = "hello_world_service"
  environment = "test"
  region = "eu-central-1"
  availability_zone = "eu-central-1a"
  availability_zone2 = "eu-central-1b"
}

#####################################################
# VPC
#####################################################

module "vpc" {
  source             = "../../modules/vpc"
  profile            = var.profile
  environment        = local.environment
  region             = local.region
  availability_zones = [local.availability_zone, local.availability_zone2]
  vpc_name           = "ecs-cluster-vpc"
  log_group_name     = "ecs-cluster-vpc-flow-logs"
}

#####################################################
# ECS CLUSTER
#####################################################

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "test-ecs-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

#####################################################
# ECS TASK
#####################################################

resource "aws_ecs_task_definition" "nodejs_hello_wold_task" {
  family = "service"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = local.task_cpu
  memory = local.task_memory

  container_definitions = jsonencode([{
    name = local.container_name,
    image = local.container_image,
    cpu = local.task_cpu,
    memory = local.task_memory,
    essential = true,
    execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  
    portMappings: [{
      containerPort = local.container_port,
      protocol = "tcp"
      hostPort = local.container_port
    }]
  }])
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Statement = {
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Effect = "Allow",
      Sid = ""
    }
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_role_policy" {
  role  = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#####################################################
# ECS SERVICE
#####################################################

resource "aws_ecs_service" "hello_world_service" {
  name = local.service_name
  cluster = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.nodejs_hello_wold_task.id
  desired_count = local.service_desired_count
  deployment_maximum_percent = 200
  deployment_minimum_healthy_percent = 50
  launch_type = "FARGATE"
  scheduling_strategy = "REPLICA"
  platform_version = "LATEST"

  depends_on = [
    aws_alb_target_group.service_target_group
  ]

  network_configuration {
    assign_public_ip = false
    security_groups = [aws_security_group.ecs_task_sg.id]
    subnets = module.vpc.computing_subnet
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.service_target_group.arn
    container_name = local.container_name
    container_port = local.container_port
  }
}

#####################################################
# ALB SETUP
#####################################################

resource "aws_alb" "ecs_alb" {
  name = "ecsalb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = module.vpc.web_subnet

  enable_deletion_protection = false
}

resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.service_target_group.arn
  }
}

resource "aws_alb_target_group" "service_target_group" {
  name = "serviceTargetGroup"
  port = 80
  protocol = "HTTP"
  vpc_id = module.vpc.vpc_id
  target_type = "ip"
  
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 10
    timeout = 3
    interval = 10
    path = "/"
    port = local.host_port
  }
}

#####################################################
# SECURITY GROUPS
#####################################################

resource "aws_security_group" "ecs_task_sg" {
  name = "ECSTaskSG"
  vpc_id = module.vpc.vpc_id

  ingress {
    protocol = "TCP"
    from_port = local.host_port
    to_port = local.host_port
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}

resource "aws_security_group" "alb_sg" {
  name = "ALBSg"
  vpc_id = module.vpc.vpc_id

  ingress {
    protocol = "TCP"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}