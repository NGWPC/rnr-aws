# Reference Architecture for a Serverless Data Processing Pipeline

This repository contains the infrastructure-as-code (IaC) and basic CI pipelines for a serverless RnR data processing application deployment on AWS. The infrastructure is defined using Terraform, and continuous integration is handled by GitHub Actions.

## Architecture Overview 

Triggers: An EventBridge Scheduler kicks off processes on defined schedules.

Data Ingestion: A Producer Lambda function sends messages to a central RabbitMQ Broker (Amazon MQ). It also has access to and ElasticCache (Redis) for caching.

Core Processing: A long-running Fargate Worker Task (ECS) consumes messages from RabbitMQ, performs the main business logic, and uses S3 for shared storage.

Autoscaler: Provides AWS MQ RabbitMQ depth based autoscaling by way of a lambda and cloudwatch events.

Data Storage: The worker task reads from an Input S3 Bucket and writes its results to an Output S3 Bucket.

Post-Processing: A Post-Process Lambda is triggered on a schedule and processes any new objects created in the Output S3 bucket to perform final actions.

Security: IAM Roles aim to provide least-privilege permissions, and Secrets Manager securely stores RabbitMQ credentials.

## Pre-requisites

- A VPC with private Subnets
- An S3 Bucket accessible by the 

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
