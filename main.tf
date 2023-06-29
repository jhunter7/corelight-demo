# Create API Gateway
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "corelight-demo"
  description = "API Gateway for triggering Lambda functions"
}

# Create SQS Queue
resource "aws_sqs_queue" "sqs_queue" {
  name = "corelight-demo-sqs"
  depends_on = [
    aws_iam_user_policy_attachment.attach_policy_to_user1
  ]
}

data "aws_sqs_queue" "data" {
  name = "corelight-demo-sqs"
  depends_on = [
    aws_sqs_queue.sqs_queue
  ]
}

#Event source from SQS
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
#  event_source_arn = "${data.aws_sqs_queue.data.arn}"
  event_source_arn = "arn:aws:sqs:us-east-1:642660919026:corelight-demo-sqs"
  enabled          = true
  function_name    = "${aws_lambda_function.lambda_function_2.arn}"
  batch_size       = 1
}

# Create S3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "corelight-demo-1"
  acl    = "private"
}

resource "aws_api_gateway_resource" "api_gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "myresource"
}

# API Int
resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.api_gateway_resource.id
  http_method = aws_api_gateway_method.api_gateway_method.http_method
  integration_http_method = "ANY"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method" "api_gateway_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_gateway_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Function 1: API Gateway trigger 
resource "aws_lambda_function" "lambda_function" {
  filename      = "${path.module}/python/1/lambda_function.py.zip"
  function_name = "corelight-demo-lambda-1"
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  timeout       = 10
  role          = aws_iam_role.lambda_role.arn
}

resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = "corelight-demo-lambda-1"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:${var.accountId}:${aws_api_gateway_rest_api.api_gateway.id}/*/*"
#  ${aws_api_gateway_method.api_gateway_method.http_method}${aws_api_gateway_resource.proxy.path}"
}

# Function 2: sqs trigger
resource "aws_lambda_function" "lambda_function_2" {
  filename      = "${path.module}/python/2/lambda_function.py.zip"
  function_name = "corelight-demo-lambda-2"
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  timeout       = 10
  role          = aws_iam_role.lambda_role.arn
}

# Function 3: s3 trigger
resource "aws_lambda_function" "lambda_function_3" {
  filename      = "${path.module}/python/3/lambda_function.py.zip"
  function_name = "corelight-demo-lambda-3"
  runtime       = "python3.8"
  handler       = "lambda_function.lambda_handler"
  timeout       = 10
  role          = aws_iam_role.lambda_role.arn
}

# IAM Roles
resource "aws_iam_role" "lambda_role" {
  name = "LambdaRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name = "sqs_exec"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sqs:SendMessage",
            "Resource": "arn:aws:sqs:us-east-1:*:corelight-demo-sqs"
        }
    ]
}
EOF
}


# Attach necessary IAM policies to the Lambda role
resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "LambdaPolicyAttachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}


resource "aws_iam_policy_attachment" "attach_sqs" {
  name       = "LambdaPolicyAttachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_user_policy_attachment" "attach_policy_to_user1" {
  user       = "techops_user_2"
  policy_arn = aws_iam_policy.policy.arn
  depends_on = [
    aws_iam_policy.policy
  ]
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_function_3.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]

  }
}
resource "aws_lambda_permission" "test" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function_3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.bucket.id}"
}

