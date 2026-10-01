import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client("sqs")
queue_url = os.environ["QUEUE_URL"]


def handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        message = {
            "bucket": bucket,
            "key": key,
        }

        response = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message),
        )

        logger.info(
            "Sent SQS message %s for s3://%s/%s",
            response["MessageId"],
            bucket,
            key,
        )

    return {"statusCode": 200}
