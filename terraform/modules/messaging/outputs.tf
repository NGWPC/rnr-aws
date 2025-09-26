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

output "rabbitmq_broker_name" {
  description = "The name of the RabbitMQ broker."
  value       = aws_mq_broker.rabbitmq.broker_name
}

output "rabbitmq_secret_arn" {
  description = "The ARN of the Secrets Manager secret for RabbitMQ credentials."
  value       = aws_secretsmanager_secret.rabbitmq.arn
}

output "rabbitmq_web_console_url" {
  description = "The web console URL for the RabbitMQ broker."
  value       = aws_mq_broker.rabbitmq.instances[0].console_url
}
