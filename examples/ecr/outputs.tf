
output "ecr_url" {
  value = aws_ecr_repository.ecr.repository_url
  description = "url of the container registry"
}