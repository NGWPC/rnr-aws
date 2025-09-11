# -----------------------------------------------------------------------------
# Input Variables
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy the infrastructure in."
  type        = string
}

variable "app_name" {
  description = "A name for the application, used to prefix resource names."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'test', 'prod')."
  type        = string
}

# --- Network Configuration ---
variable "vpc_name" {
  description = "The name tag of the existing VPC to deploy into."
  type        = string
}

variable "subnet_name_pattern" {
  description = "The name tag pattern to match for existing private subnets (e.g., 'Test-App*')."
  type        = string
}

# --- Application Configuration ---
variable "docker_image_uri" {
  description = "The full URI of the public Docker image on ghcr.io (e.g., 'ghcr.io/user/repo:tag')."
  type        = string
}

variable "lambda_code_bucket_name" {
  description = "The name of the S3 bucket where Lambda function ZIP files are stored."
  type        = string
}

variable "lambda_producer_zip_s3_key" {
  description = "The S3 key for the producer Lambda function's ZIP file."
  type        = string
}

variable "lambda_postproc_zip_s3_key" {
  description = "The S3 key for the post-processing Lambda function's ZIP file."
  type        = string
}

# --- Compute Configuration ---
variable "fargate_cpu" {
  description = "The amount of CPU to allocate to the Fargate task."
  type        = number
  default     = 1024 # 1 vCPU
}

variable "fargate_memory" {
  description = "The amount of memory (in MiB) to allocate to the Fargate task."
  type        = number
  default     = 2048 # 2 GB
}

variable "fargate_initial_task_count" {
  description = "The initial number of Fargate tasks to run."
  type        = number
  default     = 1
}

# --- Messaging Configuration ---

variable "rabbitmq_user" {
  description = "The master username for the RabbitMQ broker."
  type        = string
  sensitive   = true
  default     = "admin"
}

# --- Orchestration Configuration ---

variable "producer_schedule_expression" {
  description = "The schedule expression for triggering the producer Lambda (e.g., 'rate(5 minutes)')."
  type        = string
  default     = "rate(15 minutes)"
}
