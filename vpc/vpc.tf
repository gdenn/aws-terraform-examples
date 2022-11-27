locals {
  subnet_count = length(var.availability_zones)
  nat_gw_count = var.environment == "production" ? local.subnet_count : 1
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
  depends_on = [aws_internet_gateway.main_igw]
  count = local.nat_gw_count
}

resource "aws_nat_gateway" "natgw" {
  count = local.nat_gw_count
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id = aws_subnet.subnet_web[count.index].id
  depends_on = [aws_internet_gateway.main_igw]

  tags = {
    Name = "natgw-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table" "private_subnet" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.vpc_name}-private-subnet-route-table"
    Environment = var.environment
  }
}

resource "aws_route" "private_subnet" {
  count = local.subnet_count
  route_table_id = aws_route_table.private_subnet.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.natgw[count.index].id
}

resource "aws_route_table" "public_subnet" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
}