resource "aws_subnet" "subnet_web" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true

  count      = length(var.subnet_web_cidrs)
  cidr_block = element(var.subnet_web_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name        = "${var.vpc_name}-subnet-web"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "subnet_web_route_table_association" {
  count          = length(var.subnet_web_cidrs)
  subnet_id      = aws_subnet.subnet_web[count.index].id
  route_table_id = aws_route_table.public_subnet.id
}