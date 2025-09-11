"""A file to support reading/managing JSON-LD formatted data"""
from datetime import datetime
import json
from typing import Any

import aio_pika
import httpx
import redis
import redis.exceptions
from rdflib import Graph
from tqdm import tqdm
import xmltodict

from hml_reader.schemas.weather import HML
from hml_reader.settings import Settings

settings = Settings()

def fetch_weather_products(headers) -> list[Any]:
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


async def publish(channel: aio_pika.channel, hml: HML) -> None:
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
                

async def fetch_data() -> None:
    connection = await aio_pika.connect_robust(
        settings.aio_pika_url,
        heartbeat=30
    )

    async with connection:
        channel = await connection.channel(publisher_confirms=False)
        await channel.declare_queue(
            settings.flooded_data_queue,
            durable=True
        )
        print("Successfully connected to RabbitMQ")
        headers = {
            'Accept': 'application/ld+json',
            'User-Agent': '(water.noaa.gov, user@rtx.com)'
        }
        hml_data = fetch_weather_products(headers)
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
                    await publish(channel, hml_obj)
                    r.set(hml_id, hml_obj.json())
                    r.expire(hml_id, 604800)  # exires after a week
        except redis.exceptions.ConnectionError as e:
            raise e("Cannot run Redis service") 
        