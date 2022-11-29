output "vpc_cidr" {
  value = var.cidr
}

output "azs" {
  value = var.availability_zones
}

output "web_subnets" {
  value = ["${aws_subnet.subnet_web.*.id}"]
}

output "data_subnets" {
  value = ["${aws_subnet.subnet_data.*.id}"]
}

output "computing_subnets" {
  value = ["${aws_subnet.subnet_computing.*.id}"]
}