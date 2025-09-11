import os
import json
from datetime import datetime
from typing import Any

import aioboto3
import aio_pika
import httpx
import redis
import redis.exceptions
from rdflib import Graph
from tqdm import tqdm
import xmltodict

from hml_reader.schemas.weather import HML
from hml_reader.settings import Settings


async def get_rabbitmq_creds():
    secret_arn = os.getenv("RABBITMQ_SECRET_ARN")
    rabbit_mq_endpoint = os.getenv("RABBITMQ_ENDPOINT")
    region = os.getenv("AWS_REGION", "us-east-1")

    session = aioboto3.Session()
    async with session.client("secretsmanager", region_name=region) as client: # type: ignore
        secret_value = await client.get_secret_value(SecretId=secret_arn)
        secret = json.loads(secret_value["SecretString"])
        return secret["username"], secret["password"], rabbit_mq_endpoint


async def get_settings():
    return Settings()

def fetch_weather_products() -> list[Any]:
    url = "https://api.weather.gov/products"
    headers = {
        'Accept': 'application/ld+json',
        'User-Agent': '(water.noaa.gov, user@rtx.com)'
    }
    
    params = {
        'type': 'HML'
    }

    timeout_config = httpx.Timeout(
        connect=5.0,
        read=30.0,
        write=5.0,
        pool=5.0
    )
    
    limits_config = httpx.Limits(
        max_keepalive_connections=5,
        max_connections=10,
        keepalive_expiry=30.0
    )
    
    with httpx.Client(timeout=timeout_config, limits=limits_config) as client:
        response = client.get(url, headers=headers, params=params)
        
        if response.status_code == 200:
            response_json = response.json()
            response_json['@context']["@version"] = float(response_json['@context']["@version"])
            
            data = json.dumps(response_json)
            g = Graph()
            g.parse(data=data, format='json-ld')
            data_dict = xmltodict.parse(g.serialize(format="pretty-xml"))
            return data_dict['rdf:RDF']['rdf:Description']
        else:
            raise httpx.HTTPError(f"Error fetching data: {response.status_code}")

async def publish(channel: aio_pika.channel, hml: HML, settings: Settings) -> None:
    if not channel:
        raise RuntimeError(
            "Message could not be sent as there is no RabbitMQ Connection"
        )
    async with channel.transaction():
        msg = hml.json().encode()
        try:
            await channel.default_exchange.publish(
                aio_pika.Message(body=msg),
                routing_key=settings.flooded_data_queue,
                mandatory=True
            )
        except aio_pika.exceptions.DeliveryError as e:
            raise e("Message rejected")
                

async def lambda_handler(event, context):
    print("Producer Lambda triggered")

    user, pwd, rabbit_mq_endpoint = await get_rabbitmq_creds()
    
    connection = await aio_pika.connect_robust(
        f"amqp://{user}:{pwd}@{rabbit_mq_endpoint}/",
        heartbeat=30
    )
    settings = await get_settings()

    async with connection:
        channel = await connection.channel(publisher_confirms=False)
        await channel.declare_queue(
            settings.flooded_data_queue,
            durable=True
        )
        print("Successfully connected to RabbitMQ")
        hml_data = fetch_weather_products()
        try:
            r = redis.Redis(
                host=settings.redis_url,
                port=settings.redis_port,
                decode_responses=True
            )
            hml_data = sorted(hml_data, key=lambda x: datetime.fromisoformat(x["issuanceTime"]))
            for hml in tqdm(hml_data, desc="reading through api.weather.gov HML outputs"):
                hml_id = hml["id"]
                if r.get(hml_id) is None:
                    hml_obj = HML(**hml)
                    await publish(channel, hml_obj, settings)
                    r.set(hml_id, hml_obj.json())
                    r.expire(hml_id, 604800)  # exires after a week
        except redis.exceptions.ConnectionError as e:
            raise e("Cannot run Redis service") 
    return {"status": "ok"}
