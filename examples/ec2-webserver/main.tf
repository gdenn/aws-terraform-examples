local {
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

resource "aws_instance" "web_server" {
  ami               = data.aws_ami.amzn2.id
  instance_type     = local.instance_type
  user_data = templatefile("user-data.sh", {})
  subnet_id = element(module.vpc.subnet_web, 0).id

  root_block_device {
    delete_on_termination = true
    volume_type = "gp3"
    volume_size = "2"
  }

  tags = {
    Environment = local.environment
    Name        = "ec2-web-server"
  }
}


data "aws_ami" "amzn2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"]
}