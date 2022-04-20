locals {
  timestamp  = formatdate("YYMMDDhhmmss", timestamp())
  root_dir   = abspath("../${var.function_name}")
  dist_zip   = "${local.root_dir}/build/distributions/${var.function_name}.zip"
  table_name = "${var.function_name}-${var.run_name}"
}

resource "aws_s3_bucket" "b" {
  bucket = "uc1-code"
}

resource "aws_s3_object" "uc1-package" {
  bucket = aws_s3_bucket.b.bucket
  key    = "uc1-code"
  source = local.dist_zip

  etag = filebase64sha256(local.dist_zip)
}

resource "aws_iam_role" "uc1" {
  name = "uc1_iam"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_dynamo" {
  name        = "lambda_dynamo"
  path        = "/"
  description = "IAM policy for DynamoDB access from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1582485790003",
      "Action": [
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:*:*:*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "uc1-store" {
  s3_bucket     = aws_s3_bucket.b.bucket
  s3_key        = aws_s3_object.uc1-package.key
  function_name = "${var.function_name}-${var.run_name}"
  role          = aws_iam_role.uc1.arn
  handler       = "uc1.Store"

  source_code_hash = filebase64sha256(local.dist_zip)

  runtime = "java11"

  memory_size = var.function_memory
  timeout     = 120

  environment {
    variables = {
      TABLE_NAME = local.table_name
      REGION     = var.region
    }
  }

  tags = {
    Run = var.run_name
  }
}

resource "aws_iam_role_policy_attachment" "dynamo" {
  role       = aws_iam_role.uc1.name
  policy_arn = aws_iam_policy.lambda_dynamo.arn
}

resource "aws_iam_role_policy_attachment" "uc1-basic-exec-role" {
  role       = aws_iam_role.uc1.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "${var.function_name}_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "url" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.uc1-store.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "url" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.url.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.uc1-store.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "identifier"
  range_key    = "timestamp"

  attribute {
    name = "identifier"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  tags = {
    Run = var.run_name
  }
}
