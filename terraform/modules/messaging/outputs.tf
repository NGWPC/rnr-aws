output "rabbitmq_broker_id" {
  description = "The ID of the RabbitMQ broker."
  value       = aws_mq_broker.rabbitmq.id
}

output "rabbitmq_endpoint" {
  description = "The AMQP endpoint of the RabbitMQ broker."
  value       = aws_mq_broker.rabbitmq.instances[0].endpoints[0]
}

output "rabbitmq_broker_arn" {
  description = "The ARN of the RabbitMQ broker."
  value       = aws_mq_broker.rabbitmq.arn
}

output "rabbitmq_secret_arn" {
  description = "The ARN of the Secrets Manager secret for RabbitMQ credentials."
  value       = aws_secretsmanager_secret.rabbitmq.arn
}