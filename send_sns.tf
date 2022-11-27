data "aws_arn" "sns" {
  arn = aws_sns_topic.topic.arn
}

resource "aws_appsync_datasource" "none" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "none"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "NONE"
}

resource "aws_appsync_datasource" "sns" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "sns"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "HTTP"
	http_config {
		endpoint = "https://sns.${data.aws_arn.sns.region}.amazonaws.com"
		authorization_config {
			authorization_type = "AWS_IAM"
			aws_iam_config {
				signing_region = data.aws_arn.sns.region
				signing_service_name = "sns"
			}
		}
	}
}

resource "aws_appsync_resolver" "Mutation_sendNotification" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Mutation"
  field       = "sendNotification"
  data_source = aws_appsync_datasource.sns.name
	request_template = <<EOF
{
	"version": "2018-05-29",
	"method": "POST",
	"params": {
		"query": {
			"Action": "Publish",
			"Version": "2010-03-31",
			"TopicArn": "$utils.urlEncode("${aws_sns_topic.topic.arn}")",
			"Message": "$utils.urlEncode($ctx.args.message)"
		},
		"body": " ",
		"headers": {
			"Content-Type" : "application/xml"
		},
	},
	"resourcePath": "/"
}
EOF

	response_template = <<EOF
#if ($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
#if ($ctx.result.statusCode < 200 || $ctx.result.statusCode >= 300)
	$util.error($ctx.result.body, "StatusCode$ctx.result.statusCode")
#end
$util.toJson($util.xml.toMap($ctx.result.body).PublishResponse.PublishResult.MessageId)
EOF
}

resource "aws_appsync_resolver" "Mutation_receivedNotification" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Mutation"
  field       = "receivedNotification"
  data_source = aws_appsync_datasource.none.name
	request_template = <<EOF
{
	"version": "2018-05-29",
	"payload": $util.toJson($ctx.args.message)
}
EOF

	response_template = <<EOF
$util.toJson($ctx.result)
EOF
}

