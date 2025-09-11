output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "The ARN of the ECS task role for the application container."
  value       = aws_iam_role.ecs_task_role.arn
}

output "lambda_producer_role_arn" {
  description = "The ARN of the IAM role for the data producer Lambda."
  value       = aws_iam_role.lambda_producer_role.arn
}

output "lambda_postproc_role_arn" {
  description = "The ARN of the IAM role for the post-processing Lambda."
  value       = aws_iam_role.lambda_postproc_role.arn
}

output "scheduler_role_arn" {
  description = "The ARN of the IAM role for the EventBridge Scheduler."
  value       = aws_iam_role.scheduler_role.arn
}

