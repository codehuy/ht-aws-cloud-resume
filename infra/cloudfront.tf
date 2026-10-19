# --- Origin access control ---

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "oac-ht-cloud-resume.s3.us-east-1.amazonaws.com-mv4chwaz6ce"
  description                       = "Created by CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- Distribution ---

resource "aws_cloudfront_distribution" "site" {
  aliases             = ["huy-tran.com", "www.huy-tran.com"]
  comment             = "resume-site through clickops"
  default_root_object = "index.html"
  enabled             = true
  http_version        = "http2"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  staging             = false
  wait_for_deployment = true
  web_acl_id          = "arn:aws:wafv2:us-east-1:186441610858:global/webacl/CreatedByCloudFront-0bd98043/ba9930bf-3fbd-455e-9e64-c01c17f71ff9"

  tags = {
    Name = "resume-site"
  }

  origin {
    domain_name                 = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                   = "ht-cloud-resume.s3.us-east-1.amazonaws.com-mv4cbr3lqdb"
    origin_access_control_id    = aws_cloudfront_origin_access_control.site.id
    connection_attempts         = 3
    connection_timeout          = 10
    response_completion_timeout = 0
  }

  default_cache_behavior {
    target_origin_id       = "ht-cloud-resume.s3.us-east-1.amazonaws.com-mv4cbr3lqdb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    compress               = true
    default_ttl            = 0
    max_ttl                = 0
    min_ttl                = 0
    smooth_streaming       = false
    trusted_key_groups     = []
    trusted_signers        = []

    grpc_config {
      enabled = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn            = "arn:aws:acm:us-east-1:186441610858:certificate/d9bb1171-c545-468c-ae45-44f1fbee197b"
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }
}