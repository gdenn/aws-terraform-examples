output "ec2_id" {
  value = aws_instance.web_server.id
}

output "ami" {
  value = data.aws_ami.amzn2.id
}