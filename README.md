# Reference Architecture for a Serverless Data Processing Pipeline

This repository contains the infrastructure-as-code (IaC) and basic CI pipelines for a serverless RnR data processing application deployment on AWS. This solution is designed to be scalable, resilient, and cost-effective, leveraging modern cloud-native technologies. The infrastructure is defined using Terraform, and continuous integration and artifact deployment are handled by GitHub Actions.

## Architecture Overview 

Triggers: An EventBridge Scheduler kicks off processes on defined schedules.

Data Ingestion: A Producer Lambda function fetches data from external weather APIs, checks for duplicates using ElastiCache for Redis, and sends messages to a central RabbitMQ Broker (Amazon MQ).

Core Processing: A long-running Fargate Worker Task (ECS) consumes messages from RabbitMQ, performs the main business logic, and uses S3 for shared storage.

Autoscaling: An Autoscaler Lambda, triggered by an EventBridge schedule, calculates the backlog of messages per running task and publishes a custom CloudWatch metric. CloudWatch Alarms monitor this metric and trigger Application Auto Scaling policies to adjust the number of Fargate tasks up to a defined maximum number of workers.

Data Storage: The worker task reads from an Input S3 Bucket and writes its results to an Output S3 Bucket.

Post-Processing: A Post-Process Lambda is triggered on a schedule and processes any new objects created in the Output S3 bucket to perform final actions.

Security: IAM Roles aim to provide least-privilege permissions, and Secrets Manager securely stores RabbitMQ credentials.

## Pre-requisites

- An AWS Account
- A VPC with private subnets
- An S3 Bucket for Terraform state and Lambda code
- Terraform installed locally
- AWS CLI configured with appropriate credentials

### Bucket Policy Requirements
This application's IaC requires an existing S3 bucket to store input and output data currently.
To allow the ECS tasks and Lambda functions created by this stack to access the bucket, the bucket owner must update the bucket policy to grant permissions to the application’s IAM roles.

After deploying this stack, provide the following IAM role ARNs (created by Terraform) to the S3 Bucket Owner.

```
arn:aws:iam::<ACCOUNT_ID>:role/<APP_NAME>-<ENV>-lambda-producer-role
arn:aws:iam::<ACCOUNT_ID>:role/<APP_NAME>-<ENV>-ecs-task-role
arn:aws:iam::<ACCOUNT_ID>:role/<APP_NAME>-<ENV>-lambda-postproc-role
```

You will want to integrate the following or request that theythe owner integrate the following statement with their bucket policy:

```
{
  "Sid": "AllowRnRTestAppRolesS3Access",
  "Effect": "Allow",
  "Principal": {
    "AWS": [
      "arn:aws:iam::<ACCOUNT_ID>:role/<APP_NAME>-<ENV>-lambda-producer-role",
      "arn:aws:iam::<ACCOUNT_ID>:role/<APP_NAME>-<ENV>-ecs-task-role",
      "arn:aws:iam::<ACCOUNT_ID>:role/<APP_NAME>-<ENV>-lambda-postproc-role"
    ]
  },
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::<BUCKET_NAME>",
    "arn:aws:s3:::<BUCKET_NAME>/*"
  ]
}
```
### CI/CD Pipelines

This repository includes two GitHub Actions workflows:

1. cicd-container.yml: This workflow is triggered on pushes and pull requests to the main and development branches. It builds the Docker image for the Fargate worker, scans it for vulnerabilities using Trivy, and pushes it to GitHub Container Registry (ghcr.io).

2. cicd-lambdas.yml: This workflow is triggered on pushes to the main branch when files in the lambdas or lambda_layers directories change. It packages the Lambda functions and layers into zip files and uploads them as artifacts, ready for deployment.

### Future Improvements for Consideration

- Production-Ready Messaging: For a production environment, the Amazon MQ for RabbitMQ broker should likely be configured in a cluster with a multi-AZ deployment for high availability.
- Enhanced Security: The security groups could be made more restrictive. For example, the egress rules could be limited to only the necessary endpoints.
- Distributed Tracing or Enhance Logging: Implementing a tool like AWS X-Ray would provide end-to-end tracing of requests as they flow through the system, from the producer Lambda to the Fargate worker.
- Dead-Letter Queues (DLQs): To improve resiliency, DLQs could be configured for the RabbitMQ queues to handle messages that cannot be processed successfully.
- Monitoring and notifications: For a production environment, the this solution will likely need to be integrated with a monitoring and notification system configured for appropriate issue escalation.
