variable "profile" {
  type        = string
  description = "aws profile"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "availability_zones" {
  type = list(string)
}

variable "environment_id" {
  type        = string
  description = "type of environment"
  default     = "Dev"
  validation {
    condition     = contains(["Dev", "Prod", "Test", "Sandbox"], var.environment_id)
    error_message = "valid values: 'Dev', 'Prod', 'Test', 'Sandbox'"
  }
}

variable "app_id" {
  type        = string
  description = "identifies the application that these DBMs belongs to"
}

variable "rpo" {
  type        = string
  description = "recovery point objective for the aurora db"
  default     = "5min"
}

variable "organization_prefix" {
  type        = string
  description = "unique identifier for your organization"
}

variable "data_classification" {
  type        = string
  description = "identifies how sensitive your data is"
  validation {
    condition     = contains(["Public", "Private", "Confidential", "Restricted"])
    error_message = "valad values: 'Public', 'Private', 'Confidential', 'Restricted'"
  }
}

variable "database_name" {
  type        = string
  description = "name of the database in the aurora cluster"
  default     = "postgres"
}

variable "aurora_engine" {
  type        = string
  description = "engine: either 'aurora_postgres' or 'aurora_mysql'"
  default     = "aurora_postgres"
  validation {
    condition     = contains(["aurora_postgres", "aurora_mysql"])
    error_message = "valid values: 'aurora_postgres', 'aurora_mysql'"
  }
}

variable "aurora_engine_version" {
  type        = string
  default     = ""
  description = "(optional) version of the aurora engine"
}

variable "backup_retention_in_days" {
  type        = number
  description = "retention period until backups will be removed"
  default     = 1
}

variable "preffered_backup_window" {
  type        = string
  description = "aurora performs daily full load backup, provide a preferred time window"
  default     = "02:00-04:00"
}

variable "master_password" {
  type        = string
  description = "password of the admin user"
}

variable "master_username" {
  type        = string
  description = "name of the admin user"
}

variable "cluster_instance_type" {
  type        = string
  description = "type of aurora cluster instances"
  default     = "db.r4.large"
}

variable "cluster_instance_count" {
  type        = number
  description = "total count of aurora cluster instances"
  default     = 1
}