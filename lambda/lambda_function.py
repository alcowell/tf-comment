import json
from datetime import datetime


def lambda_handler(event, context):
    """Comment Lambda function

    Parameters
    ----------
    event: dict, required
        API Gateway Lambda Proxy Input Format

        Event doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format

    context: object, required
        Lambda Context runtime methods and attributes

        Context doc: https://docs.aws.amazon.com/lambda/latest/dg/python-context-object.html

    Returns
    ------
    API Gateway Lambda Proxy Output Format: dict

        Return doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html
    """
    print("This is a comment!")
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
    headers = {
        "Access-Control-Allow-Origin": "http://localhost:3000",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
    }
    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "comments": [
                    {
                        "id": 1,
                        "post_id": "da56a8f9-4520-4164-ba66-350a47b9a3ae",
                        "content": "This is a comment!",
                        "created_at": f"{now}",
                        "created_by": "user1",
                    },
                ]
            }
        ),
        "headers": headers,
    }
