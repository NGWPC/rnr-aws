variable "app_name" {
  description = "The name of the application, used for resource tagging and naming."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'test', 'prod')."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for deploying ElastiCache."
  type        = list(string)
}

variable "elasticache_security_group_ids" {
  description = "A list of security group IDs to associate with the ElastiCache cluster."
  type        = list(string)
}

