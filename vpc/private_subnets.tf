locals {
  computing_subnet_count = length(var.subnet_computing_cidrs)
  data_subnet_count = length(var.subnet_data_cidrs)
  reserved_subnet_count = length(var.subnet_reserved_cidrs)
}

/* COMPUTING SUBNET */
resource "aws_subnet" "subnet_computing" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false

  count      = local.computing_subnet_count
  cidr_block = element(var.subnet_computing_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.vpc_name}-subnet-computing-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "subnet_computing_route_table_association" {
  count          = local.computing_subnet_count
  subnet_id      = aws_subnet.subnet_computing[count.index].id
  route_table_id = aws_route_table.private_subnet.id
}

/* COMPUTING SUBNET */
resource "aws_subnet" "subnet_data" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false

  count      = local.data_subnet_count
  cidr_block = element(var.subnet_data_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.vpc_name}-subnet-data-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "subnet_data_route_table_association" {
  count          = local.data_subnet_count
  subnet_id      = aws_subnet.subnet_data[count.index].id
  route_table_id = aws_route_table.private_subnet.id
}

/* RESERVED SUBNET */
resource "aws_subnet" "subnet_reserved" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = false

  count      = local.reserved_subnet_count
  cidr_block = element(var.subnet_data_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.vpc_name}-subnet-data-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "subnet_reserved_route_table_association" {
  count          = local.reserved_subnet_count
  subnet_id      = aws_subnet.subnet_reserved[count.index].id
  route_table_id = aws_route_table.private_subnet.id
}