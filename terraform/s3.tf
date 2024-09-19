

# S3 bucket for hosting a static website
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name

  tags = var.common_tags
}

# S3 bucket policy to only allow access from CloudFront
resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          "AWS": "${aws_cloudfront_origin_access_identity.s3_access_identity.iam_arn}"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}


resource "aws_s3_bucket_website_configuration" "example" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

}


resource "aws_s3_bucket_cors_configuration" "example" {
  bucket = aws_s3_bucket.website_bucket.id

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

# Output the website URL
output "website_url" {
  value = aws_s3_bucket.website_bucket.website_endpoint
}




##############

# CloudFront Origin Access Identity (OAI) to restrict access to S3
resource "aws_cloudfront_origin_access_identity" "s3_access_identity" {
  comment = "OAI for S3 access from CloudFront"
}


# CloudFront distribution with S3 as origin
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website_bucket.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.common_tags
}

# Output the CloudFront URL
output "cloudfront_url" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
