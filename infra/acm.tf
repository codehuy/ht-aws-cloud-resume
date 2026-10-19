import {
  to = aws_acm_certificate.site
  id = "arn:aws:acm:us-east-1:186441610858:certificate/d9bb1171-c545-468c-ae45-44f1fbee197b"
}

resource "aws_acm_certificate" "site" {
  domain_name               = "huy-tran.com"
  subject_alternative_names = ["www.huy-tran.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}