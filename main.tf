provider "aws" {
}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "appsync" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
  statement {
    actions = [
      "sns:Publish"
    ]
    resources = [
			aws_sns_topic.topic.arn
    ]
  }
}

resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync.id
  policy = data.aws_iam_policy_document.appsync.json
}

resource "aws_appsync_graphql_api" "appsync" {
  name                = "appsync_test"
  schema              = file("schema.graphql")
  authentication_type = "AWS_IAM"
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync.arn
    field_log_level          = "ALL"
  }
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

resource "aws_sns_topic" "topic" {
}
