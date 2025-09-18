# -----------------------------------------------------------------------------
# Root Module Outputs
# -----------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = module.application.ecs_cluster_name
}

output "ecs_service_name" {
  description = "The name of the ECS Fargate service for the T-Route worker."
  value       = module.application.ecs_service_name
}

output "rabbitmq_broker_id" {
  description = "The ID of the Amazon MQ for RabbitMQ broker."
  value       = module.messaging.rabbitmq_broker_id
}

output "rabbitmq_web_console_url" {
  description = "The Amazon RabbitMQ web console URL."
  value       = module.messaging.rabbitmq_web_console_url
}
