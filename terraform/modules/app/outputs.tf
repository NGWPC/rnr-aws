output "ecs_service_name" {
  description = "The name of the ECS Fargate service."
  value       = aws_ecs_service.worker.name
}

output "lambda_producer_arn" {
  description = "The ARN of the producer Lambda function."
  value       = aws_lambda_function.producer.arn
}

output "lambda_postproc_arn" {
  description = "The ARN of the post-processing Lambda function."
  value       = aws_lambda_function.post_process.arn
}

output "lambda_postproc_function_name" {
  description = "The name of the post-processing Lambda function."
  value       = aws_lambda_function.post_process.function_name
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}