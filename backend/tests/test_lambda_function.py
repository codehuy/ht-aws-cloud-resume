import importlib
import json

import boto3
import pytest
from moto import mock_aws

TABLE_NAME = "visitor-count"


@pytest.fixture
def setup(monkeypatch):
    # Fake credentials, so nothing can reach real AWS.
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.delenv("AWS_SESSION_TOKEN", raising=False)
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    monkeypatch.setenv("TABLE_NAME", TABLE_NAME)

    with mock_aws():
        table = boto3.resource("dynamodb").create_table(
            TableName=TABLE_NAME,
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        table.put_item(Item={"id": "count", "views": 0})

        # Import after the mock and env vars are in place,
        # since the module connects to the table when loaded.
        import lambda_function
        importlib.reload(lambda_function)

        yield lambda_function, table


def test_returns_200_and_count(setup):
    handler, _ = setup
    response = handler.lambda_handler({}, None)

    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == {"count": 1}


def test_increments_on_each_call(setup):
    handler, _ = setup
    first = json.loads(handler.lambda_handler({}, None)["body"])["count"]
    second = json.loads(handler.lambda_handler({}, None)["body"])["count"]

    assert second == first + 1


def test_count_persists_in_table(setup):
    handler, table = setup
    handler.lambda_handler({}, None)
    handler.lambda_handler({}, None)

    item = table.get_item(Key={"id": "count"})["Item"]
    assert item["views"] == 2


def test_returns_json_content_type(setup):
    handler, _ = setup
    response = handler.lambda_handler({}, None)

    assert response["headers"]["Content-Type"] == "application/json"


def test_starts_from_zero_if_item_missing(setup):
    handler, table = setup
    table.delete_item(Key={"id": "count"})

    response = handler.lambda_handler({}, None)
    assert json.loads(response["body"]) == {"count": 1}