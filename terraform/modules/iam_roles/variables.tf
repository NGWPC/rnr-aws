variable "app_name" {
  description = "The name of the application, used for resource tagging and naming."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'test', 'prod')."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where resources are deployed."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID where resources are deployed."
  type        = string
}

variable "input_data_bucket_arn" {
  description = "The ARN of the S3 bucket for GPKG domain data, used for ECS task permissions."
  type        = string
}

variable "output_data_bucket_arn" {
  description = "The ARN of the S3 bucket for output data, used for ECS task permissions."
  type        = string
}

variable "rabbitmq_secret_arn" {
  description = "The ARN of the RabbitMQ credentials secret in Secrets Manager."
  type        = string
}
