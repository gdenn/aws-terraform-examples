variable "environment" {
  type        = string
  description = "environment type (staging/prod/sdlc)"
  default     = "production"
}

variable "cidr" {
  type        = string
  description = "vpc cidr"
  default     = "10.0.0.0/16"
}

variable "cidr_offset" {
  description = "offset that we pass to the cidrsubnet function to build subnets"
  default = 8
}

variable "profile" {
  type    = string
  description = "aws profile"
}

variable "log_group_name" {
  type    = string
  description = "vpc-flow-logs"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_name" {
  type    = string
  description = "vpc name"
  default = "test"
}

variable "availability_zones" {
  type = list(string)
  description = "list of availability zones"
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}