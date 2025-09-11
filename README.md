# Reference Architecture for a Serverless Data Processing Pipeline

This repository contains the infrastructure-as-code (IaC) and most basic CI/CD pipelines for a serverless data processing application on AWS. The infrastructure is defined using Terraform, and continuous integration is handled by GitHub Actions.

## Architecture Overview 

Triggers: An EventBridge Scheduler kicks off the process on a defined schedule.

Data Ingestion: A Producer Lambda function sends messages to a central RabbitMQ Broker (Amazon MQ). It also has access to and ElasticCache (Redis) for caching.

Core Processing: A long-running Fargate Worker Task (ECS) consumes messages from RabbitMQ, performs the main business logic, and uses EFS and S3 for shared storage. It also has ElastiCache (Redis) for caching, though that may only be required by the Data ingestion (#TODO: Clarify Access requirements)

Data Storage: The worker task reads from an Input S3 Bucket and writes its results to an Output S3 Bucket.

Post-Processing: A Post-Process Lambda is triggered by new objects created in the Output S3 bucket to perform final actions.  (#TODO: Clarify how this really is triggered)

Security: IAM Roles aim to provide least-privilege permissions, and Secrets Manager securely stores RabbitMQ credentials.

## Action Items for Development Team

To integrate the real application code, one would need to review and update the following areas.

- [ ] Lambda Functions

    The placeholder Lambda code is located in lambdas/producer/producer_lambda.py and lambdas/postprocess/post_process_lambda.py.

    Action: Replace the contents of these files with your production-ready Python code.

    Action: Update the corresponding requirements.txt file in each Lambda's directory with any new Python dependencies.

- [ ] ECS Worker Task

    The placeholder ECS worker code is located in ecs/worker/worker.py.

    Action: Replace this with the core data processing logic, image, ETC.

- [ ] IAM Permissions

    The current IAM roles have basic permissions for S3 access, VPC networking, and reading the RabbitMQ secret. The role definitions are in terraform/modules/iam_roles/main.tf.

    Action: Identify any other required AWS services, and provide the list of required permissions to the infrastructure team for IAM policy updates.

- [ ] Environment Variables & Secrets

    The infrastructure passes a basic example set of environment variables (bucket names, RabbitMQ endpoint, ETC.) to the compute services. These are defined in terraform/modules/app/main.tf.

    Action: Identify any additional configuration values or secrets your application needs. For non-sensitive values, we can add them as new environment variables. For sensitive values (API keys, ETC.), we will likely add them to AWS Secrets Manager and grant the necessary IAM permissions to access them.
