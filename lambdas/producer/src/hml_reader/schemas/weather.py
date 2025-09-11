from datetime import datetime

from pydantic import BaseModel, Field

class HML(BaseModel):
    rdf: str = Field(alias="@rdf:about")
    id: str
    wmo_collective_id: str = Field(alias="wmoCollectiveId")
    issuing_office: str = Field(alias="issuingOffice")
    issuance_time: datetime = Field(alias="issuanceTime")
    product_code: str = Field(alias="productCode")
    product_name: str = Field(alias="productName")

    class Config:
        populate_by_name = True
