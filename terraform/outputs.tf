# -----------------------------------------------------------------------------
# Root Module Outputs
# -----------------------------------------------------------------------------

output "gpkg_data_bucket_name" {
  description = "The name of the S3 bucket for storing GPKG domain data."
  value       = module.data_stores.gpkg_data_bucket_name
}

output "output_data_bucket_name" {
  description = "The name of the S3 bucket for storing output data."
  value       = module.data_stores.output_data_bucket_name
}

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
