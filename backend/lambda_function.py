import json
import os
import boto3


TABLE_NAME = os.environ["TABLE_NAME"]
ALLOWED_ORIGIN = os.environ["ALLOWED_ORIGIN"]

table = boto3.resource("dynamodb").Table(TABLE_NAME)


def lambda_handler(event, context):
    response = table.update_item(
        Key={"id": "count"},
        UpdateExpression="ADD #v :incr",
        ExpressionAttributeNames={"#v": "views"},
        ExpressionAttributeValues={":incr": 1},
        ReturnValues="UPDATED_NEW",
    )
    count = int(response["Attributes"]["views"])

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
        },
        "body": json.dumps({"count": count}),
    }