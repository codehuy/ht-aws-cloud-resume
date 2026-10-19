# --- Hosted zone ---

resource "aws_route53_zone" "site" {
  name    = "huy-tran.com"
  comment = ""

  lifecycle {
    prevent_destroy = true
  }
}

# --- ACM validation records ---

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => dvo
  }

  zone_id = aws_route53_zone.site.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300
}

# --- Site aliases to CloudFront ---

locals {
  site_aliases = {
    "apex_A"    = { name = "huy-tran.com", type = "A" }
    "apex_AAAA" = { name = "huy-tran.com", type = "AAAA" }
    "www_A"     = { name = "www.huy-tran.com", type = "A" }
    "www_AAAA"  = { name = "www.huy-tran.com", type = "AAAA" }
  }
}

resource "aws_route53_record" "site" {
  for_each = local.site_aliases

  zone_id = aws_route53_zone.site.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}