locals {
  container_name = "hello_world_service"
  container_image = "express-hello-world"
  container_port = 8080
  host_port = 80
  task_memory = 2048
  task_cpu = 512
  service_desired_count = 1
  service_name = "hello_world_service"
  environment = "test"
  region = "eu-central-1"
  availability_zone = "eu-central-1a"
  availability_zone2 = "eu-central-1b"
}

module "vpc" {
  source             = "../../modules/vpc"
  profile            = var.profile
  environment        = local.environment
  region             = local.region
  availability_zones = [local.availability_zone, local.availability_zone2]
  vpc_name           = "ecs-cluster-vpc"
  log_group_name     = "ecs-cluster-vpc-flow-logs"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "test-ecs-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "nodejs_hello_wold_task" {
  family = "service"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = local.task_cpu
  memory = local.task_memory

  container_definitions = jsonencode([{
    name: local.container_name,
    image: local.container_image,
    cpu: local.task_cpu,
    memory: local.task_memory,
    essential: true,
    portMappings: [{
      containerPort = local.container_port,
      protocol = "tcp"
      hostPort = local.host_port
    }]
  }])
}

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

  network_configuration {
    assign_public_ip = false
    security_groups = []
    subnets = module.vpc.computing_subnet
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.service_target_group.arn
    container_name = local.container_name
    container_port = local.host_port
  }
}

resource "aws_alb" "ecs_alb" {
  name = "ecsalb"
  internal = false
  load_balancer_type = "application"
  security_groups = []
  subnets = module.vpc.web_subnet
  enable_deletion_protection = false
}

resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port = local.host_port
  protocol = "tcp"

  default_action {
    target_group_arn = aws_alb_target_group.service_target_group.arn
    type = "forward"
  }
}

resource "aws_alb_target_group" "service_target_group" {
  name = "serviceTargetGroup"
  port = local.host_port
  protocol = "HTTP"
  vpc_id = module.vpc.vpc_id
  
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 10
    timeout = 3
    interval = 10
    path = "/"
    port = local.host_port
  }
}