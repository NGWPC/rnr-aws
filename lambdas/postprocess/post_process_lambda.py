import boto3
import os
import re
from datetime import datetime, timedelta

import pandas as pd
import xarray as xr
import geopandas as gpd
import pandas as pd
import polars as pl

s3 = boto3.client("s3")

def to_geopandas(df: pd.DataFrame, crs: str = "EPSG:5070") -> gpd.GeoDataFrame:
    """Converts the geometries in a pandas df to a geopandas dataframe

    Parameters
    ----------
    df: pd.DataFrame
        The iceberg table you are trying to read from
    crs: str, optional
        A string representing the CRS to set in the gdf, by default "EPSG:5070"

    Returns
    -------
    gpd.DataFrame
        The resulting queried row, but in a geodataframe

    Raises
    ------
    ValueError
        Raised if the table does not have a geometry column
    """
    if "geometry" not in df.columns:
        raise ValueError("The provided table does not have a geometry column.")

    return gpd.GeoDataFrame(df, geometry=gpd.GeoSeries.from_wkb(df["geometry"]), crs=crs)


def lambda_handler(event, context):
    print("PostProcess Lambda triggered with:", event)
    
    data_dict = {
        "feature_id": [],
        "feature_id_str": [],
        "strm_order": [],
        "name": [],
        "state": [],
        "streamflow_cfs": [],
        "inherited_rfc_forecasts": [],
        "max_status": [],
        "reference_time": [],
        "update_time": [],
        "geom": [],
    }
    current_time = datetime.now()
    twenty_four_hours_ago = current_time - timedelta(hours=24)
    timestamp = current_time.strftime("%Y-%m-%d_%H:%M:%S")

    # Reading in the hydrofabric
    print("Reading the hydrofabric")
    flowpaths = to_geopandas(pd.read_parquet(settings.data_dir / "parquet/flowpaths.parquet"))
    flowpaths = flowpaths.set_index("id")
    write_file = False
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        print(f"Processing file {key} from {bucket}")

        output_bucket = os.getenv("OUTPUT_BUCKET", bucket)
        output_key = f"processed/{key}"

        s3.put_object(Bucket=output_bucket, Key=output_key, Body=b"dummy processed output")
        print(f"Wrote dummy processed file to {output_bucket}/{output_key}")

    return {"status": "processed"}
