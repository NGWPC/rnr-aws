output "fargate_sg_id" {
  description = "The ID of the Fargate service security group."
  value       = aws_security_group.fargate.id
}

output "lambda_sg_id" {
  description = "The ID of the Lambda function security group."
  value       = aws_security_group.lambda.id
}

output "elasticache_sg_id" {
  description = "The ID of the ElastiCache security group."
  value       = aws_security_group.elasticache.id
}

output "rabbitmq_sg_id" {
  description = "The ID of the RabbitMQ security group."
  value       = aws_security_group.rabbitmq.id
}
