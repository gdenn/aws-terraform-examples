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

variable "subnet_web_cidrs" {
  type = list(string)
  description = "public subnet cidrs"
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "subnet_computing_cidrs" {
  type = list(string)
  description = "private computing subnet cidrs"
  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "subnet_data_cidrs" {
  type = list(string)
  description = "private data subnet cidrs"
  default = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]
}

variable "subnet_reserved_cidrs" {
  type = list(string)
  description = "private reserved subnet cidrs"
  default = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "profile" {
  type    = string
  description = "aws profile"
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