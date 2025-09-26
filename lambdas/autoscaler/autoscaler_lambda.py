import boto3
import os
import logging
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_queue_depth(cw_client, mq_broker_name, mq_queue_name):
    """
    Get the number of messages on the RabbitMQ broker.
    NOTE: This uses the broker-level 'MessageCount' as a proxy for the specific queue depth.
    """
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=5)

        response = cw_client.get_metric_data(
            MetricDataQueries=[
                {
                    'Id': 'mq_message_count',
                    'MetricStat': {
                        'Metric': {
                            'Namespace': 'AWS/AmazonMQ',
                            'MetricName': 'MessageCount', 
                            'Dimensions': [
                                {'Name': 'Broker', 'Value': mq_broker_name},
                            ]
                        },
                        'Period': 60,
                        'Stat': 'Average',
                    },
                    'ReturnData': True,
                },
            ],
            StartTime=start_time,
            EndTime=end_time,
            ScanBy='TimestampDescending',
            MaxDatapoints=1
        )

        if response['MetricDataResults'][0]['Values']:
            # This value is the total for the broker
            queue_size = response['MetricDataResults'][0]['Values'][0] 
            logger.info(f"Broker '{mq_broker_name}' has a total of {queue_size} messages.")
            return queue_size
        else:
            logger.warning(f"No metric data found for MessageCount for broker '{mq_broker_name}'. Assuming 0.")
            return 0

    except Exception as e:
        logger.error(f"Error getting MessageCount metric for broker '{mq_broker_name}': {e}")
        raise

def get_running_task_count(ecs_client, cluster_name, service_name):
    """
    Get the number of running tasks for the ECS service.
    """
    try:
        response = ecs_client.describe_services(cluster=cluster_name, services=[service_name])
        if response['services']:
            running_count = response['services'][0]['runningCount']
            logger.info(f"Service '{service_name}' in cluster '{cluster_name}' has {running_count} running tasks.")
            return running_count
        else:
            logger.error(f"ECS service '{service_name}' not found in cluster '{cluster_name}'.")
            return 0
    except Exception as e:
        logger.error(f"Error describing ECS service '{service_name}': {e}")
        raise

def publish_backlog_per_task_metric(cw_client, cluster_name, service_name, backlog_per_task):
    """
    Publish the BacklogPerTask metric to CloudWatch.
    """
    try:
        cw_client.put_metric_data(
            Namespace='ECS/Service/RabbitMQ',
            MetricData=[
                {
                    'MetricName': 'BacklogPerTask',
                    'Dimensions': [
                        {'Name': 'ClusterName', 'Value': cluster_name},
                        {'Name': 'ServiceName', 'Value': service_name},
                    ],
                    'Value': backlog_per_task,
                    'Unit': 'Count'
                },
            ]
        )
        logger.info(f"Successfully published BacklogPerTask metric with value: {backlog_per_task}")
    except Exception as e:
        logger.error(f"Error publishing BacklogPerTask metric: {e}")
        raise

def lambda_handler(event, context):
    """
    Main Lambda handler function.
    """
    cluster_name = os.environ.get("ECS_CLUSTER_NAME")
    service_name = os.environ.get("ECS_SERVICE_NAME")
    mq_broker_name = os.environ.get("MQ_BROKER_NAME")
    mq_queue_name = os.environ.get("MQ_QUEUE_NAME")
    region = os.environ.get("AWS_REGION")

    if not all([cluster_name, service_name, mq_broker_name, mq_queue_name, region]):
        logging.error("One or more environment variables are not set.")
        return {'statusCode': 500, 'body': 'Missing environment variables'}

    # These clients are now created here and passed to the functions
    ecs_client = boto3.client('ecs', region_name=region)
    cw_client = boto3.client('cloudwatch', region_name=region)

    try:
        queue_depth = get_queue_depth(cw_client, mq_broker_name, mq_queue_name)
        running_task_count = get_running_task_count(ecs_client, cluster_name, service_name)

        if running_task_count > 0:
            backlog_per_task = queue_depth / running_task_count
        else:
            backlog_per_task = 0

        publish_backlog_per_task_metric(cw_client, cluster_name, service_name, backlog_per_task)

        return {'statusCode': 200, 'body': 'Metric published successfully'}

    except Exception as e:
        logging.error(f"An error occurred: {e}")
        return {'statusCode': 500, 'body': 'An error occurred during execution'}
