import boto3
import os

s3 = boto3.client("s3")

def lambda_handler(event, context):
    print("PostProcess Lambda triggered with:", event)

    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        print(f"Processing file {key} from {bucket}")

        output_bucket = os.getenv("OUTPUT_BUCKET", bucket)
        output_key = f"processed/{key}"

        s3.put_object(Bucket=output_bucket, Key=output_key, Body=b"dummy processed output")
        print(f"Wrote dummy processed file to {output_bucket}/{output_key}")

    return {"status": "processed"}
