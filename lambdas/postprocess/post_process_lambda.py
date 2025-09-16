import os
import re
import boto3
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd
import xarray as xr

# Initialize the S3 client from boto3
s3_client = boto3.client("s3")


def extract_timestamp_from_filename(filename: str) -> datetime | None:
    """Extract timestamp from filename like 'troute_output_202505061230.nc'

    Parameters
    ----------
    filename : str
        The filename to extract timestamp from (format: troute_output_YYYYMMDDHHMM.nc)

    Returns
    -------
    datetime | None
        The extracted datetime, or None if parsing fails
    """
    # Pattern to match troute_output_*.nc and extract the timestamp
    pattern = r"troute_output_(\d{12})\.nc"

    match = re.search(pattern, filename)
    if not match:
        return None
    timestamp_str = match.group(1)

    try:
        # Parse YYYYMMDDHHMM format
        year = int(timestamp_str[:4])
        month = int(timestamp_str[4:6])
        day = int(timestamp_str[6:8])
        hour = int(timestamp_str[8:10])
        minute = int(timestamp_str[10:12])
        return datetime(year, month, day, hour, minute)
    except (ValueError, IndexError) as e:
        print(f"Error parsing timestamp from {filename}: {e}")
        return None


def lambda_handler(event, context):
    print("PostProcess Lambda triggered with:", event)

    bucket_name = os.getenv("APP_BUCKET_NAME")
    if not bucket_name:
        return {
            "status": "error",
            "message": "APP_BUCKET_NAME environment variable not set",
        }

    troute_output_path = os.getenv("APP_OUTPUT_S3_KEY")
    if not troute_output_path:
        return {
            "status": "error",
            "message": "APP_OUTPUT_S3_KEY environment variable not set",
        }

    hydrofabric_path = os.getenv("HYDROFABRIC_S3_KEY")
    if not hydrofabric_path:
        return {
            "status": "error",
            "message": "HYDROFABRIC_S3_KEY environment variable not set",
        }

    rnr_path = os.getenv("POSTPROCESS_OUTPUT_S3_KEY")
    if not rnr_path:
        return {
            "status": "error",
            "message": "POSTPROCESS_OUTPUT_S3_KEY environment variable not set",
        }

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

    # Reading in the hydrofabric by downloading it to the /tmp/ directory first
    s3_key = f"{hydrofabric_path}/flowpaths.parquet"
    print(f"Attempting to download Hydrofabric Data from bucket: '{bucket_name}', Key: '{s3_key}'")

    local_hydrofabric_path = "/tmp/flowpaths.parquet"
    s3_client.download_file(
        Bucket=bucket_name,
        Key=s3_key,
        Filename=local_hydrofabric_path,
    )
    flowpaths = pd.read_parquet(local_hydrofabric_path)
    flowpaths = flowpaths.set_index("id")

    print("Opening all forecasts for times after the current timestep")

    # Use a boto3 paginator to list relevant .nc files
    paginator = s3_client.get_paginator("list_objects_v2")
    pages = paginator.paginate(Bucket=bucket_name, Prefix=troute_output_path)

    processed_files = False
    for page in pages:
        for obj in page.get("Contents", []):
            s3_key = obj["Key"]
            if not s3_key.endswith(".nc"):
                continue

            filename = Path(s3_key).name
            file_timestamp = extract_timestamp_from_filename(filename)

            # Filter files created within the last 24 hours
            if file_timestamp and file_timestamp >= twenty_four_hours_ago:
                processed_files = True
                
                # Download the .nc file to the /tmp/ directory to be read by xarray
                local_nc_path = f"/tmp/{filename}"
                s3_client.download_file(
                    Bucket=bucket_name, Key=s3_key, Filename=local_nc_path
                )
                ds = xr.open_dataset(local_nc_path, engine="netcdf4")

                # Find which feature_id and time index corresponds to the global max
                global_max_flow = ds.flow.max()
                max_location = (
                    ds.flow.where(ds.flow == global_max_flow)
                    .stack(flat_dim=["feature_id", "time"])
                    .dropna("flat_dim")
                )
                max_time_idx = max_location.time.values[0]
                max_ds = ds.sel(time=max_time_idx)
                catchments = [f"wb-{_id}" for _id in max_ds.feature_id.values]
                filtered_flowpaths = flowpaths.loc[flowpaths.index.isin(catchments)]
                
                data_dict["feature_id"].extend(
                    max_ds.feature_id.values
                ) # Using the hydrofabric v2.2 IDs since there are many NHD feature IDs per hydrofabric catchment
                data_dict["feature_id_str"].extend(catchments)
                data_dict["strm_order"].extend(
                    [max_ds.attrs["stream_order"]] * len(catchments)
                )
                data_dict["name"].extend([max_ds.attrs["name"]] * len(catchments))
                data_dict["state"].extend([max_ds.attrs["state"]] * len(catchments))
                data_dict["max_status"].extend(
                    [max_ds.attrs["max_status"]] * len(catchments)
                )
                data_dict["reference_time"].extend(
                    [max_ds.attrs["file_reference_time"]] * len(catchments)
                )
                data_dict["update_time"].extend([timestamp] * len(catchments))
                data_dict["streamflow_cfs"].extend(max_ds.flow.values * 35.3147) # to cfs
                
                total_miles = 0.0
                miles_upstream = [total_miles]
                # Flowpaths are pre-sorted by upstream to downstream
                for i, (_, row) in enumerate(filtered_flowpaths.iterrows()):
                    if (
                        i != len(filtered_flowpaths) - 1
                    ): # Skipping the last segment since its miles from upstream based on the upstream connection
                        total_miles += row["lengthkm"] * 0.621371 # converting km to miles
                        miles_upstream.append(total_miles)
                
                data_dict["inherited_rfc_forecasts"].extend(
                    [
                        f"{max_ds.attrs['max_status']} issued {max_ds.attrs['file_reference_time']} at {max_ds.attrs['rfc_location']} ({max_ds.attrs['rfc_reach_id']} [order {max_ds.attrs['stream_order']}]) {miles} miles upstream"
                        for miles in miles_upstream
                    ]
                )
                data_dict["geom"].extend(filtered_flowpaths.geometry.values.tolist())
                ds.close()

                # Clean up the downloaded NetCDF file to conserve space in /tmp/
                os.remove(local_nc_path)

    # If any files were processed, write the output to a local CSV and upload to S3
    if processed_files:
        output_filename = f"output_inundation_{timestamp}.csv"
        local_output_path = f"/tmp/{output_filename}"
        df = pd.DataFrame(data_dict)

        # Per instructions, the binary geometry data is intentionally not converted to WKT
        df.to_csv(local_output_path, index=False)

        # Upload the final output file to S3
        output_s3_key = f"{rnr_path}/{output_filename}"
        s3_client.upload_file(
            Filename=local_output_path, Bucket=bucket_name, Key=output_s3_key
        )
        print(f"Successfully uploaded {output_s3_key} to S3.")
        return {"status": "processed"}
    else:
        print("No new files to process.")
        return {"status": "no data processed"}