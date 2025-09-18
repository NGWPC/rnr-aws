# -----------------------------------------------------------------------------
#  'Non-functional IaC test' Deployment
# -----------------------------------------------------------------------------

aws_region          = "us-east-1"
app_name            = "rnrtest"
environment         = "test"
team_name           = "EDFS"

# --- Existing Network Details ---
vpc_name            = "Test-Main"
subnet_name_pattern = "Test-App*"

# --- Application Image and Code ---
# This would typically be passed in from a CI/CD pipeline
docker_image_uri                    = "ghcr.io/ngwpc/rnr-aws:main"
lambda_code_bucket_name             = "ngwpc-infra-test"
#lambda_producer_zip_s3_key         = "lambda-zips/data-producer/v1.0.0.zip"
#lambda_postproc_zip_s3_key         = "lambda-zips/post-processor/v1.0.0.zip"
lambda_producer_zip_s3_key          = "lambda-zips/producer.zip"
lambda_postproc_zip_s3_key          = "lambda-zips/postprocess.zip"
lambda_postproc_layer_zip_s3_key    = "lambda-zips/postprocess_dependencies.zip"

# Add vars that populate env vars in lambdas and fargate tasks
app_bucket_name             = "edfs-data"
app_output_s3_key           = "rnr/pi-7/troute-output"
postprocess_output_s3_key   = "rnr/pi-7/rnr-output"
hydrofabric_s3_key          = "rnr/pi-7/parquet"

# Fargate Compute Configuration
fargate_cpu                 = 1024 # 8192
fargate_memory              = 2048 # 16384
fargate_initial_task_count  = 1
fargate_max_task_count      = 2

# --- Schedule ---
producer_schedule_expression = "rate(5 minutes)"
postprocess_schedule_expression = "rate(10 minutes)"

