terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
variable "AWS_ACCESS_KEY_ID" {
  description = "AWS account access key"
  type        = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS account secret key"
  type        = string
}

provider "aws" {
  region     = "us-west-2"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

##defining your AWS Lambda function and other necessary resources in it.
resource "aws_lambda_function" "mathExponentLambda" {
  function_name = "PowerOfMathLambda"
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  filename      = "lambda_function.zip"
  role          = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = "mathExponentDb"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda-dynamodb-policy-attachment"
  policy_arn = aws_iam_policy.lambda_policy.arn
  roles      = [aws_iam_role.lambda_role.name]
}


resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "dynamodb:PutItem"
      ],
      Effect   = "Allow",
      Resource = "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
    }]
  })
}

data "aws_caller_identity" "current" {}

variable "dynamodb_table_name" {
  description = "mathExponentDb"
  type        = string
}

## creating the API Gateway to invoke the lamdba function
#creating an API Gateway REST API.
resource "aws_api_gateway_rest_api" "mathExponentApi" {
  name        = "mathExponentApi"
  description = "API Gateway to invoke the mathExponent Lambda function"
}

#creating a resource under the API Gateway.
resource "aws_api_gateway_resource" "mathExponentresource" {
  rest_api_id = aws_api_gateway_rest_api.mathExponentApi.id
  parent_id   = aws_api_gateway_rest_api.mathExponentApi.root_resource_id
  path_part   = "calculate"
}

#creating an HTTP method (POST) for the resource.
resource "aws_api_gateway_method" "mathExponentMethod" {
  rest_api_id   = aws_api_gateway_rest_api.mathExponentApi.id
  resource_id   = aws_api_gateway_resource.mathExponentresource.id
  http_method   = "POST"
  authorization = "NONE"
}

#configuring the integration between the API Gateway and your Lambda function.
resource "aws_api_gateway_integration" "mathExponentIntegration" {
  rest_api_id             = aws_api_gateway_rest_api.mathExponentApi.id
  resource_id             = aws_api_gateway_resource.mathExponentresource.id
  http_method             = aws_api_gateway_method.mathExponentMethod.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.mathExponentLambda.invoke_arn
}

#deploying the API Gateway to a stage named "dev".
resource "aws_api_gateway_deployment" "mathExponentDeployment" {
  depends_on  = [aws_api_gateway_integration.mathExponentIntegration]
  rest_api_id = aws_api_gateway_rest_api.mathExponentApi.id
  stage_name  = "dev"
}

#To allow API Gateway to invoke your Lambda function, I added a permission to the Lambda function.
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mathExponentLambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_api_gateway_rest_api.mathExponentApi.execution_arn
}

#to get the API Gateway endpoint URL after deployment
output "api_gateway_url" {
  value = aws_api_gateway_deployment.mathExponentDeployment.invoke_url
}


#creating an s3 bucket
resource "aws_s3_bucket" "expononetbucket" {
  bucket = "exponentbucket"


  # Enable versioning for the bucket 
  versioning {
    enabled = true
  }
}
# storing the html file in the s3 bucket
resource "aws_s3_object" "html_file" {
  bucket = aws_s3_bucket.expononetbucket.bucket
  key    = "index.html"
  source = "/Users/KLAIRE/Desktop/AWSProjects/index.html" # Path to your local HTML file


}


