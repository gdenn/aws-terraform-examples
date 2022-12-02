locals {
  azs_count = length(var.availability_zones)
  computing_offset = local.azs_count
  data_offset = local.azs_count * 2
}

/* WEB */
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

/* COMPUTING SUBNET */
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
  route_table_id = aws_route_table.private_subnet.id
}

/* DATA SUBNET */
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