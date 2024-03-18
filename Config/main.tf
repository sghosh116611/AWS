
provider "aws" {
  region = "us-east-1" 
}

# Create IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

# Attach policies to IAM role for Lambda function
resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  roles       = [aws_iam_role.lambda_role.name]
}

# Create Lambda function
resource "aws_lambda_function" "lambda_function" {
  filename      = "ec2_monitoring_lambda.zip"
  function_name = "ec2DetailedMonitoringLambdaFunction"
  role          = aws_iam_role.lambda_role.arn
  handler = "compliance.py"
  runtime       = "python3.12" 
}

# Create Lambda permission for Config
resource "aws_lambda_permission" "lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.arn
  principal     = "config.amazonaws.com"
  statement_id  = "AllowExecutionFromConfig"
}

# Create AWS Config Configuration Recorder to monitor only the EC2 instances daily
resource "aws_config_configuration_recorder" "config_recorder" {
  name     = "example-recorder"
  role_arn = #Arn of your IAM Account
  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types                = ["AWS::EC2::Instance"]
  }
  recording_mode {
    recording_frequency = "CONTINUOUS"
  }
}

# Create AWS Config rule
resource "aws_config_config_rule" "config_rule" {
  name = "ec2-monitoring-rule" 
  description = "Monitors EC2 instances for Detailed monitoring" 
  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.lambda_function.arn
    source_detail {
      event_source = "aws.config"
      message_type = "ConfigurationItemChangeNotification"
    }
  }
  depends_on = [
    aws_config_configuration_recorder.config_recorder,
    aws_lambda_permission.lambda_permission,
  ]
}

# Output Lambda function ARN
output "lambda_function_arn" {
  value = aws_lambda_function.lambda_function.arn
}

# Output Config rule name
output "config_rule_name" {
  value = aws_config_config_rule.config_rule.name
}
