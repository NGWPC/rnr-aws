variable "app_name" {
  description = "The name of the application, used for resource tagging and naming."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'test', 'prod')."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the security groups will be created."
  type        = string
}

variable "rabbitmq_console_cidr" {
  description = "The CIDR block allowed to access the RabbitMQ web management console."
  type        = string
}
