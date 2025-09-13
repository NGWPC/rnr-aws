import os
import re
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd
import xarray as xr
import geopandas as gpd
import pandas as pd
import s3fs

fs = s3fs.S3FileSystem()


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

    return gpd.GeoDataFrame(
        df, geometry=gpd.GeoSeries.from_wkb(df["geometry"]), crs=crs
    )


def lambda_handler(event, context):
    print("PostProcess Lambda triggered with:", event)

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

    # Reading in the hydrofabric
    print("Reading the hydrofabric")
    flowpaths = to_geopandas(pd.read_parquet(f"{hydrofabric_path.rstrip('/')}/flowpaths.parquet"))
    flowpaths = flowpaths.set_index("id")

    print("Opening all forecasts for times after the current timestep")
    s3_path = troute_output_path[5:]
    all_nc_files = fs.glob(f"{s3_path}/**/*.nc")
    for nc_file in all_nc_files:
        filename = Path(nc_file).name
        file_timestamp = extract_timestamp_from_filename(filename)
        # Filter files created within the last 24 hours
        if (
            file_timestamp and twenty_four_hours_ago <= file_timestamp <= current_time
        ):  # Searches for files with timestamps within the past 24 hours
            full_s3_url = f"s3://{nc_file}"
            ds = xr.open_dataset(full_s3_url, engine="netcdf4")

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
            )  # Using the hydrofabric v2.2 IDs since there are many NHD feature IDs per hydrofabric catchment
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
            data_dict["streamflow_cfs"].extend(max_ds.flow.values * 35.3147)  # to cfs

            total_miles = 0.0
            miles_upstream = [total_miles]
            # Flowpaths are pre-sorted by upstream to downstream
            for i, (_, row) in enumerate(filtered_flowpaths.iterrows()):
                if (
                    i != len(filtered_flowpaths) - 1
                ):  # Skipping the last segment since its miles from upstream based on the upstream connection
                    total_miles += row["lengthkm"] * 0.621371  # converting km to miles
                    miles_upstream.append(total_miles)

            data_dict["inherited_rfc_forecasts"].extend(
                [
                    f"{max_ds.attrs['max_status']} issued {max_ds.attrs['file_reference_time']} at {max_ds.attrs['rfc_location']} ({max_ds.attrs['rfc_reach_id']} [order {max_ds.attrs['stream_order']}]) {miles} miles upstream"
                    for miles in miles_upstream
                ]
            )
            data_dict["geom"].extend(filtered_flowpaths.geometry.values.tolist())
            ds.close()

        output_filename = f"output_inundation_{timestamp}.csv"
        df = pd.DataFrame(data_dict)
        df.to_parquet(f"{rnr_path.rstrip('/')}/{output_filename}")
        return {"status": "processed"}
    else:
        return {"status": "no data processed"}
