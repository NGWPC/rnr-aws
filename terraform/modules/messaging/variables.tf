variable "app_name" {
  description = "The name of the application, used for resource tagging and naming."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'test', 'prod')."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for deploying the message broker."
  type        = list(string)
}

variable "rabbitmq_security_group_ids" {
  description = "A list of security group IDs to associate with the message broker."
  type        = list(string)
}

variable "rabbitmq_username" {
  description = "The username for the RabbitMQ broker admin user."
  type        = string
  sensitive   = true
  default     = "admin"
}
