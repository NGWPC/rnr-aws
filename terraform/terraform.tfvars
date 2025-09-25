# -----------------------------------------------------------------------------
#  'IaC test' Deployment
# -----------------------------------------------------------------------------

aws_region          = "us-east-1"
app_name            = "rnrtest"
environment         = "test"
team_name           = "EDFS"

# --- Existing Network Details ---
vpc_name                = "Test-Main"
subnet_name_pattern     = "Test-App*"
rabbitmq_console_cidr   = "10.0.0.0/8"

# --- Application Image and Code ---
# This would typically be passed in from a CI/CD pipeline
docker_image_uri                    = "ghcr.io/ngwpc/rnr-aws/troute-rnr:latest"        
lambda_code_bucket_name             = "ngwpc-infra-test"
#lambda_producer_zip_s3_key         = "lambda-zips/data-producer/v1.0.0.zip"
#lambda_postproc_zip_s3_key         = "lambda-zips/post-processor/v1.0.0.zip"
lambda_autoscaler_zip_s3_key        = "lambda-zips/autoscaler.zip"
lambda_producer_zip_s3_key          = "lambda-zips/producer.zip"
lambda_postproc_zip_s3_key          = "lambda-zips/postprocess.zip"
lambda_postproc_layer_zip_s3_key    = "lambda-zips/postprocess_dependencies.zip"

# Add vars that populate env vars in lambdas and fargate tasks
app_bucket_name             = "edfs-data"
app_output_s3_key           = "rnr/pi-7/troute-output"
postprocess_output_s3_key   = "rnr/pi-7/rnr-output"
hydrofabric_s3_key          = "rnr/pi-7/parquet"

# Fargate Compute Configuration
fargate_cpu                 = 8192
fargate_memory              = 16384
fargate_initial_task_count  = 1
fargate_max_task_count      = 6

# --- Schedule ---
producer_schedule_expression = "rate(5 minutes)"
postprocess_schedule_expression = "rate(10 minutes)"

# Example to force delete the created secrets in secrets manager without waiting for the scheduled deletion, should you want to quickly delete and recreate the infrastructure.
# This should only be necessary in test environments where you want to quickly delete and recreate the infrastructure.
# aws secretsmanager delete-secret --secret-id rnrtest/test/rabbitmq-credentials --force-delete-without-recovery --region us-east-1


