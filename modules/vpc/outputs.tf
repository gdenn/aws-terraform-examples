output "vpc_cidr" {
  value = var.cidr
}

output "azs" {
  value = var.availability_zones
}

output "web_subnet" {
  value = aws_subnet.subnet_web[*].id
}

output "data_subnet" {
  value = aws_subnet.subnet_data[*].id
}

output "computing_subnet" {
  value = aws_subnet.subnet_computing[*].id
}