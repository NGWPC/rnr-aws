
import os

from pydantic import ConfigDict
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    STAGES : set = {
        "action",
        "minor",
        "major",
        "moderate",
    }

    BASE_URL : str = "https://api.water.noaa.gov/nwps/v1"

    rate_limit: int = 8

    rabbitmq_default_username: str = "guest"
    rabbitmq_default_password: str = "guest"
    rabbitmq_default_host: str = "localhost"
    rabbitmq_default_port: int = 5672

    aio_pika_url: str = "amqp://{}:{}@{}:{}/"
    redis_url: str = "localhost"
    redis_port: int = 6379

    flooded_data_queue: str = "hml_files"
    error_queue: str = "error_queue"

    log_path: str = "/app/data/logs"

    model_config = ConfigDict(extra="allow", arbitrary_types_allowed=True)

    def __init__(self, **data):
        super(Settings, self).__init__(**data)
        if os.getenv("RABBITMQ_HOST") is not None:
            self.rabbitmq_default_host = os.getenv("RABBITMQ_HOST")
        if os.getenv("REDIS_HOST") is not None:
            self.redis_url = os.getenv("REDIS_HOST") 

        self.aio_pika_url = self.aio_pika_url.format(
            self.rabbitmq_default_username,
            self.rabbitmq_default_password,
            self.rabbitmq_default_host,
            self.rabbitmq_default_port,
        )
