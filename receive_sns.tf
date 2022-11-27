data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "/tmp/lambda-${random_id.id.hex}.zip"
  source {
    content  = file("index.mjs")
    filename = "index.mjs"
  }
}

data "aws_arn" "appsync" {
  arn = aws_appsync_graphql_api.appsync.arn
}

resource "aws_lambda_function" "lambda" {
  function_name = "${random_id.id.hex}-function"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  environment {
    variables = {
			APIURL = aws_appsync_graphql_api.appsync.uris["GRAPHQL"]
			apiRegion = data.aws_arn.appsync.region
			NODE_NO_WARNINGS = "1"
    }
  }

  timeout = 30
  handler = "index.handler"
  runtime = "nodejs18.x"
  role    = aws_iam_role.lambda_exec.arn
}

data "aws_iam_policy_document" "lambda_exec_role_policy" {
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
      "appsync:GraphQL",
    ]
    resources = [
			"${aws_appsync_graphql_api.appsync.arn}/types/Mutation/fields/receivedNotification"
    ]
  }
}

resource "aws_cloudwatch_log_group" "lambda_loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy" "lambda_exec_role" {
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_exec_role_policy.json
}

resource "aws_iam_role" "lambda_exec" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "sns" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "sns.amazonaws.com"
  source_arn = aws_sns_topic.topic.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.topic.arn
  protocol = "lambda"
  endpoint = aws_lambda_function.lambda.arn
}
