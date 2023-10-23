import json
import math
import boto3
from time import gmtime, strftime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('mathExponentDb')

def lambda_handler(event, context):
    base = event.get('base')
    exponent = event.get('exponent')

    if base is None or exponent is None:
        return {
            'statusCode': 400,
            'body': json.dumps('Error: Missing base or exponent in the input event.')
        }

    try:
        base = int(base)
        exponent = int(exponent)
        math_result = math.pow(base, exponent)
        
        now = strftime("%a, %d %b %Y %H:%M:%S +0000", gmtime())
        response = table.put_item(
            Item={
                'ID': str(math_result),
                'LatestGreetingTime': now
            }
        )
        
        response_body = {
            'result': math_result,
            'message': 'Calculation successful.'
        }

        return {
            'statusCode': 200,
            'body': json.dumps(response_body)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
