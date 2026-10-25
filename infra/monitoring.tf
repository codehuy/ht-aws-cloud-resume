variable "alert_email" {
  description = "Email address for alarm notifications"
  type        = string
  sensitive   = true
}

# --- Alert topic ---

resource "aws_sns_topic" "alerts" {
  name = "visitor-count-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- Alarm on Lambda errors ---

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name        = "visitor-count-errors"
  alarm_description = "The visitor-count Lambda returned one or more errors."

  namespace   = "AWS/Lambda"
  metric_name = "Errors"
  dimensions = {
    FunctionName = aws_lambda_function.visitor_count.function_name
  }

  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}