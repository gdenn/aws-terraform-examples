locals {
  subnet_count = length(var.availability_zones)
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

################################################################################
# FLOW LOGS
################################################################################

resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn = aws_iam_role.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_log_group.arn
  traffic_type = "ALL"
  vpc_id = aws_vpc.main.id
  
}
resource "aws_cloudwatch_log_group" "vpc_log_group" {
  name = var.log_group_name
}

resource "aws_iam_role" "flow_logs_role" {
  name = "flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }
  })
}

resource "aws_iam_role_policy" "create_log_group_policy" {
  name = "allow-log-group-policy"
  role = aws_iam_role.flow_logs_role.name

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


################################################################################
# INGWG / NATGW
################################################################################

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
  depends_on = [aws_internet_gateway.main_igw]
  count = local.subnet_count
}

resource "aws_nat_gateway" "natgw" {
  count = local.subnet_count
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id = aws_subnet.subnet_web[count.index].id
  depends_on = [aws_internet_gateway.main_igw]

  tags = {
    Name = "natgw-${count.index}"
    Environment = var.environment
  }
}

################################################################################
# ROUTING
################################################################################

resource "aws_route_table" "private_subnet" {
  count = local.subnet_count
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.vpc_name}-private-subnet-route-table-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route" "private_subnet" {
  count = local.subnet_count
  route_table_id = aws_route_table.private_subnet[count.index].id
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

resource "aws_route_table" "private_isolated_subnet" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.vpc_name}-private-isolated-subnet-route-table"
    Environment = var.environment
  }
}

locals {
  azs_count = length(var.availability_zones)
  computing_offset = local.azs_count
  data_offset = local.azs_count * 2
}

################################################################################
# WEB SUBNET
################################################################################

resource "aws_subnet" "subnet_web" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true

  count      = local.azs_count
  cidr_block = cidrsubnet(var.cidr, var.cidr_offset, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.vpc_name}-subnet-web"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "subnet_web_route_table_association" {
  count          = local.azs_count
  subnet_id      = aws_subnet.subnet_web[count.index].id
  route_table_id = aws_route_table.public_subnet.id
}

################################################################################
# COMPUTING SUBNET
################################################################################

resource "aws_subnet" "subnet_computing" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false

  count      = local.azs_count
  cidr_block = cidrsubnet(var.cidr, var.cidr_offset, count.index + local.computing_offset)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.vpc_name}-subnet-computing-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "subnet_computing_route_table_association" {
  count          = local.azs_count
  subnet_id      = aws_subnet.subnet_computing[count.index].id
  route_table_id = aws_route_table.private_subnet[count.index].id
}

################################################################################
# DATA SUBNET
################################################################################

resource "aws_subnet" "subnet_data" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false

  count      = local.azs_count
  cidr_block = cidrsubnet(var.cidr, var.cidr_offset, count.index + local.data_offset)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.vpc_name}-subnet-data-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "subnet_data_route_table_association" {
  count          = local.azs_count
  subnet_id      = aws_subnet.subnet_data[count.index].id
  route_table_id = aws_route_table.private_isolated_subnet.id
}