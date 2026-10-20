terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "ht-tfstate-186441610858"
    key          = "cloud-resume/github-oidc.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume these roles, as owner/name"
  type        = string
}

# --- Look up the resources this project manages ---

data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "site" {
  bucket = "ht-cloud-resume"
}

data "aws_s3_bucket" "state" {
  bucket = "ht-tfstate-${data.aws_caller_identity.current.account_id}"
}

data "aws_cloudfront_distribution" "site" {
  id = "E2VSU25P7SKR2A"
}

data "aws_dynamodb_table" "counter" {
  name = "visitor-count"
}

data "aws_lambda_function" "counter" {
  function_name = "visitor-count"
}

data "aws_iam_role" "lambda" {
  name = "visitor-count-lambda"
}

data "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/visitor-count"
}

data "aws_apigatewayv2_api" "counter" {
  api_id = "z3a0lb435b"
}

data "aws_route53_zone" "site" {
  name = "huy-tran.com"
}

data "aws_acm_certificate" "site" {
  domain   = "huy-tran.com"
  statuses = ["ISSUED"]
}

locals {
  oac_arn = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:origin-access-control/E1XHW58ASLQBHN"
}

# --- OIDC provider ---

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# --- Trust policy: only this repo's main branch ---

data "aws_iam_policy_document" "github_trust" {
  statement {
    tactions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

# --- Frontend role: sync files and invalidate the cache ---

resource "aws_iam_role" "frontend" {
  name               = "github-frontend-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

data "aws_iam_policy_document" "frontend" {
  statement {
    sid       = "ListSiteBucket"
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.site.arn]
  }

  statement {
    sid       = "WriteSiteObjects"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${data.aws_s3_bucket.site.arn}/*"]
  }

  statement {
    sid       = "InvalidateCache"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [data.aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "frontend" {
  name   = "github-frontend-deploy"
  role   = aws_iam_role.frontend.id
  policy = data.aws_iam_policy_document.frontend.json
}

# --- Terraform role: read everything, modify only this project ---

resource "aws_iam_role" "terraform" {
  name               = "github-terraform-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

resource "aws_iam_role_policy_attachment" "terraform_read" {
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "terraform" {
  statement {
    sid       = "StateReadWrite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${data.aws_s3_bucket.state.arn}/cloud-resume/terraform.tfstate*"]
  }

  statement {
    sid = "DynamoDB"
    actions = [
      "dynamodb:UpdateTable",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
    ]
    resources = [data.aws_dynamodb_table.counter.arn]
  }

  statement {
    sid = "Lambda"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UntagResource",
    ]
    resources = [data.aws_lambda_function.counter.arn]
  }

  statement {
    sid = "LambdaLogs"
    actions = [
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = ["${data.aws_cloudwatch_log_group.lambda.arn}*"]
  }

  statement {
    sid = "LambdaRole"
    actions = [
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = [data.aws_iam_role.lambda.arn]
  }

  statement {
    sid       = "PassLambdaRole"
    actions   = ["iam:PassRole"]
    resources = [data.aws_iam_role.lambda.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid     = "ApiGateway"
    actions = ["apigateway:PATCH", "apigateway:PUT", "apigateway:POST", "apigateway:DELETE"]
    resources = [
      data.aws_apigatewayv2_api.counter.arn,
      "${data.aws_apigatewayv2_api.counter.arn}/*",
    ]
  }

  statement {
    sid = "CloudFront"
    actions = [
      "cloudfront:UpdateDistribution",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
    ]
    resources = [data.aws_cloudfront_distribution.site.arn, local.oac_arn]
  }

  statement {
    sid = "SiteBucketConfig"
    actions = [
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
    ]
    resources = [data.aws_s3_bucket.site.arn]
  }

  statement {
    sid = "Route53"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ChangeTagsForResource",
    ]
    resources = [data.aws_route53_zone.site.arn]
  }

  statement {
    sid = "Certificate"
    actions = [
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
    ]
    resources = [data.aws_acm_certificate.site.arn]
  }
}

resource "aws_iam_role_policy" "terraform" {
  name   = "github-terraform-deploy"
  role   = aws_iam_role.terraform.id
  policy = data.aws_iam_policy_document.terraform.json
}

# --- Outputs for the GitHub workflows ---

output "frontend_role_arn" {
  value = aws_iam_role.frontend.arn
}

output "terraform_role_arn" {
  value = aws_iam_role.terraform.arn
}