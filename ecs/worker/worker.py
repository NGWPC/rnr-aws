import os, time, json
import boto3
import pika

def get_rabbitmq_creds():
    secret_arn = os.getenv("RABBITMQ_SECRET_ARN")
    rabbit_mq_endpoint = os.getenv("RABBITMQ_ENDPOINT")
    region     = os.getenv("AWS_REGION", "us-east-1")

    client = boto3.client("secretsmanager", region_name=region)
    secret_value = client.get_secret_value(SecretId=secret_arn)
    secret = json.loads(secret_value["SecretString"])
    return secret["username"], secret["password"], rabbit_mq_endpoint

print("Starting ECS Worker...")

while True:
    try:
        user, pwd, rabbit_mq_endpoint = get_rabbitmq_creds()
        creds = pika.PlainCredentials(user, pwd)
        conn = pika.BlockingConnection(pika.ConnectionParameters(host=rabbit_mq_endpoint, credentials=creds))
        channel = conn.channel()
        channel.queue_declare(queue="test")

        channel.basic_publish(exchange="", routing_key="test", body="Hello from ECS Worker")
        print("Sent test message to RabbitMQ")
        conn.close()
    except Exception as e:
        print(f"Error: {e}")
    time.sleep(30)
