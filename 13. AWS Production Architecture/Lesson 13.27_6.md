# AWS Masterclass — Lesson 27 Part 6

# S3 Static Websites + CloudFront + OAC + ACM + DNS + WAF

This part connects almost everything we've learned:

```text
S3
IAM
KMS
DNS
TLS
CloudFront
Caching
WAF
Terraform
CI/CD
```

Our target production architecture is:

```text
                        Internet
                           │
                           ▼
                       Route 53
                           │
                    app.example.com
                           │
                           ▼
                    ┌─────────────┐
                    │ CloudFront  │
                    │             │
                    │ HTTPS       │
                    │ Cache       │
                    │ WAF         │
                    │ OAC         │
                    └──────┬──────┘
                           │
                    SigV4 signed
                     HTTPS request
                           │
                           ▼
                   ┌──────────────┐
                   │  PRIVATE S3  │
                   │              │
                   │ BPA = ON     │
                   │ ACL = OFF    │
                   │ SSE-S3/KMS   │
                   └──────────────┘
```

The crucial architecture rule is:

> **For a secure CloudFront + S3 site, use the regular S3 bucket origin with OAC—not the S3 website endpoint.**

CloudFront OAC works with normal S3 bucket origins. If you use an S3 **website endpoint**, CloudFront must treat it as a custom HTTP origin, and neither OAC nor OAI can be used. ([AWS Documentation][1])

---

# 1. First Understand the Two S3 Endpoints

This distinction causes a huge number of CloudFront mistakes.

An S3 bucket can be addressed conceptually in two different ways:

```text
S3 BUCKET

├── REST / bucket endpoint
│
│   bucket.s3.ap-south-1.amazonaws.com
│
└── Website endpoint
    │
    bucket.s3-website.<region>.amazonaws.com
```

These endpoints behave differently.

## S3 REST endpoint

Use it for:

```text
CloudFront + OAC
private bucket
HTTPS origin
SSE-KMS
normal S3 authorization
```

Architecture:

```text
CloudFront
    │
    │ OAC signed request
    ▼
S3 REST endpoint
    │
    ▼
Private objects
```

OAC can sign requests to this origin with SigV4, and AWS recommends the **Always sign requests** setting. With that setting, CloudFront-to-S3 communication is HTTPS. ([AWS Documentation][1])

---

# 2. S3 Website Endpoint

The website endpoint provides website-specific behavior such as:

```text
index documents
error documents
website redirects
directory-like index behavior
```

But S3 website endpoints support only HTTP, not HTTPS, and they cannot be protected with CloudFront OAC/OAI. ([AWS Documentation][2])

Architecture:

```text
CloudFront
    │
    │ custom HTTP origin
    ▼
S3 WEBSITE endpoint
```

This usually implies a different security posture because CloudFront cannot authenticate to it with OAC.

---

# 3. Production Choice

For our production architecture:

```text
                   CloudFront
                       │
                       │ OAC
                       ▼
              S3 REST bucket endpoint
                       │
                PRIVATE BUCKET
```

not:

```text
CloudFront
    │
    ▼
S3 website endpoint
```

for the normal secure private-origin pattern. AWS's current CloudFront guidance specifically requires a regular S3 bucket origin for OAC. ([AWS Documentation][1])

---

# 4. Why CloudFront?

Suppose the bucket is in:

```text
ap-south-1
Mumbai
```

and a user is in another continent.

Without CloudFront:

```text
User
 │
 │ every request
 ▼
S3 Mumbai
```

With CloudFront:

```text
User
 │
 ▼
nearest CloudFront edge
 │
 ├── CACHE HIT
 │      │
 │      └── return immediately
 │
 └── CACHE MISS
        │
        ▼
      S3 origin
```

CloudFront distributes static and dynamic content through a global network of edge locations and serves cached content near viewers when possible. ([AWS Documentation][3])

---

# 5. CloudFront Cache Hit vs Miss

### First request

```text
Viewer
   │
   ▼
CloudFront Edge
   │
   │ MISS
   ▼
S3
   │
   ▼
CloudFront caches object
   │
   ▼
Viewer
```

### Subsequent request

```text
Viewer
   │
   ▼
CloudFront Edge
   │
   │ HIT
   ▼
Viewer
```

The origin might not receive another request until that cached object becomes stale or is invalidated. CloudFront exposes hit/miss information through cache statistics and access logging. ([AWS Documentation][4])

---

# 6. Why the S3 Bucket Should Stay Private

Bad architecture:

```text
Internet
   │
   ├──────────────▶ S3
   │
   └──────────────▶ CloudFront
```

Users can bypass CloudFront.

Better:

```text
Internet
   │
   ▼
CloudFront
   │
   │ OAC
   ▼
Private S3
```

Now:

```text
direct S3 request
      │
      X
 AccessDenied
```

while:

```text
CloudFront request
      │
      ▼
S3 bucket policy
allows CloudFront
      │
      ▼
object returned
```

OAC is designed specifically to restrict an S3 origin so that CloudFront is the authorized access path. ([AWS Documentation][1])

---

# 7. OAC — Origin Access Control

OAC means:

```text
Origin Access Control
```

The mental model:

```text
Viewer
   │
   ▼
CloudFront
   │
   │ signs request
   │ using SigV4
   ▼
S3
   │
   ▼
Bucket policy checks:
"Is this the approved
CloudFront distribution?"
```

AWS recommends OAC's `Always sign` behavior for S3 origins. ([AWS Documentation][1])

---

# 8. OAC vs Legacy OAI

Older architectures often used:

```text
OAI
=
Origin Access Identity
```

Current architecture should normally use:

```text
OAC
=
Origin Access Control
```

AWS's current documentation explicitly recommends OAC settings and provides a migration path from legacy OAI to OAC. OAC also supports scenarios such as SSE-KMS-protected S3 objects that OAI doesn't support in the same way. ([AWS Documentation][1])

Mental model:

```text
OAI
=
legacy


OAC
=
modern preferred design
```

---

# 9. S3 Bucket Policy for OAC

CloudFront itself is the principal:

```json
{
  "Principal": {
    "Service": "cloudfront.amazonaws.com"
  }
}
```

But don't allow every CloudFront distribution in the world.

Restrict it with:

```text
AWS:SourceArn
```

to your distribution.

Production-style policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-private-site/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn":
            "arn:aws:cloudfront::123456789012:distribution/E123ABC456XYZ"
        }
      }
    }
  ]
}
```

AWS uses this same `cloudfront.amazonaws.com` + `AWS:SourceArn` pattern in its OAC guidance. ([AWS Documentation][1])

---

# 10. Notice the Object ARN

Again:

```text
arn:aws:s3:::my-private-site/*
```

not:

```text
arn:aws:s3:::my-private-site
```

because:

```text
s3:GetObject
```

operates on **objects**.

That connects directly to S3 Security Part 2.

---

# 11. Keep Block Public Access ON

For this architecture:

```text
BlockPublicAcls       = true
IgnorePublicAcls      = true
BlockPublicPolicy     = true
RestrictPublicBuckets = true
```

is perfectly compatible with CloudFront OAC because the bucket isn't public.

We're granting:

```text
specific AWS service principal
+
specific distribution SourceArn
```

not:

```text
Principal = "*"
```

AWS recommends keeping public access blocked for secure S3-hosted content and using CloudFront for secure delivery. ([AWS Documentation][2])

---

# 12. Object Ownership

Use:

```text
BucketOwnerEnforced
```

which means:

```text
ACLs disabled
```

Then authorization is driven by:

```text
IAM
+
bucket policy
+
OAC
```

instead of old object ACL complexity.

This is the modern S3 ownership model we've already learned.

---

# 13. What Happens if Objects Use SSE-S3?

Simple:

```text
CloudFront
   │
   ▼
S3
   │
SSE-S3 encrypted object
```

S3 handles the normal server-side encryption transparently.

---

# 14. What if Objects Use SSE-KMS?

Now:

```text
CloudFront
   │
   ▼
S3
   │
   ▼
KMS
```

CloudFront must also be permitted through the KMS key policy.

AWS explicitly requires KMS-key permissions for a CloudFront distribution using OAC to access an SSE-KMS S3 origin. ([AWS Documentation][1])

Example policy statement:

```json
{
  "Sid": "AllowCloudFrontSSEKMS",
  "Effect": "Allow",
  "Principal": {
    "Service": "cloudfront.amazonaws.com"
  },
  "Action": [
    "kms:Decrypt",
    "kms:Encrypt",
    "kms:GenerateDataKey*"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "AWS:SourceArn":
        "arn:aws:cloudfront::123456789012:distribution/E123ABC456XYZ"
    }
  }
}
```

AWS documents this distribution-SourceArn KMS pattern for OAC. ([AWS Documentation][1])

---

# 15. CloudFront HTTPS

Viewer architecture:

```text
HTTP request
    │
    ▼
CloudFront
    │
    ▼
301/redirect
    │
    ▼
HTTPS
```

Use:

```text
viewer_protocol_policy
=
redirect-to-https
```

for ordinary public sites.

CloudFront supports requiring or redirecting viewer connections to HTTPS. ([AWS Documentation][5])

---

# 16. ACM Certificate Region — The Rule You Must Never Forget

Your S3 bucket might be:

```text
ap-south-1
```

Your application infrastructure might also be:

```text
ap-south-1
```

But the ACM certificate used for:

```text
Viewer
   │ HTTPS
   ▼
CloudFront
```

must be requested or imported in:

```text
us-east-1
US East (N. Virginia)
```

CloudFront only uses ACM viewer certificates from `us-east-1`. ([AWS Documentation][6])

### Never forget

```text
CloudFront ACM
=
us-east-1
```

---

# 17. Certificate Must Cover the Domain

Suppose CloudFront serves:

```text
app.example.com
```

Your certificate must include:

```text
app.example.com
```

or an applicable wildcard such as:

```text
*.example.com
```

CloudFront checks that every alternate domain name is covered by the certificate's SANs or a matching wildcard. ([AWS Documentation][6])

---

# 18. Wildcard Important Detail

A certificate for:

```text
*.example.com
```

covers:

```text
app.example.com
www.example.com
cdn.example.com
```

but a wildcard at that level does not automatically represent the apex:

```text
example.com
```

If you need both, request certificate names such as:

```text
example.com
*.example.com
```

This follows CloudFront's requirement that the exact domain or a wildcard at the matching level be covered by the certificate. ([AWS Documentation][6])

---

# 19. DNS Architecture

Now:

```text
app.example.com
```

must point to CloudFront.

With Route 53:

```text
Hosted Zone
example.com
     │
     ▼
A / AAAA Alias
     │
     ▼
d123abc.cloudfront.net
```

Route 53 alias records can point both apex domains and subdomains to CloudFront. ([AWS Documentation][7])

This solves the problem that normal DNS CNAMEs cannot be used at the zone apex.

---

# 20. Three Things Must Match

For:

```text
https://app.example.com
```

you need:

```text
DNS
app.example.com
        │
        ▼

CloudFront Alias
app.example.com
        │
        ▼

ACM SAN
app.example.com
```

If DNS points to CloudFront but the distribution doesn't include that alternate domain name, CloudFront can return a 403. ([AWS Documentation][8])

---

# 21. Default Root Object

Without configuration:

```text
https://example.com/
```

means the CloudFront request path is:

```text
/
```

CloudFront doesn't automatically know you intended:

```text
/index.html
```

Set:

```text
default_root_object = "index.html"
```

Then:

```text
/
```

returns:

```text
/index.html
```

CloudFront documents exactly this behavior. ([AWS Documentation][9])

---

# 22. Famous Default Root Object Mistake

Wrong:

```text
/index.html
```

Correct:

```text
index.html
```

The CloudFront `DefaultRootObject` must not start with `/`; AWS notes that `/index.html` can cause a 403. ([AWS Documentation][9])

Memorize:

```text
default_root_object = "index.html"

NOT

default_root_object = "/index.html"
```

---

# 23. But Default Root Object Does NOT Solve SPA Routing

Suppose React has routes:

```text
/
/dashboard
/profile
/settings
```

Browser initially requests:

```text
https://app.example.com/
```

Fine:

```text
CloudFront
→ index.html
→ React loads
```

Now user refreshes:

```text
https://app.example.com/dashboard
```

CloudFront asks S3 for:

```text
/dashboard
```

But S3 contains:

```text
index.html
assets/app.js
assets/app.css
```

not:

```text
dashboard
```

Result:

```text
403 / 404
```

CloudFront's default root object only applies to the distribution root; it doesn't automatically map arbitrary SPA routes back to `index.html`. ([AWS Documentation][9])

---

# 24. SPA Solution A — Custom Error Response

A common SPA solution:

```text
S3 returns 403/404
       │
       ▼
CloudFront
       │
       ▼
serve /index.html
       │
       ▼
return 200
       │
       ▼
React Router handles route
```

Conceptually:

```hcl
custom_error_response {
  error_code            = 403
  response_code         = 200
  response_page_path    = "/index.html"
  error_caching_min_ttl = 0
}

custom_error_response {
  error_code            = 404
  response_code         = 200
  response_page_path    = "/index.html"
  error_caching_min_ttl = 0
}
```

CloudFront supports custom error pages and changing the response returned to the viewer. ([AWS Documentation][10])

---

# 25. But That Has a Drawback

Suppose a real asset is missing:

```text
/assets/logo-does-not-exist.png
```

Origin says:

```text
404
```

Your SPA fallback says:

```text
return index.html
HTTP 200
```

Now a missing image might return HTML with status 200.

So:

```text
403/404 → index.html
```

is easy but broad.

For more precise routing, edge rewriting can be better.

---

# 26. SPA Solution B — CloudFront Function

CloudFront Functions can rewrite a viewer request before it reaches the origin. AWS provides examples of rewriting request URIs and adding `index.html` to suitable routes. ([AWS Documentation][11])

Conceptually:

```javascript
function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (!uri.includes(".")) {
    request.uri = "/index.html";
  }

  return request;
}
```

Then:

```text
/dashboard
    │
    ▼
CloudFront Function
    │
    ▼
/index.html
    │
    ▼
S3
```

while:

```text
/assets/app.js
```

still maps to:

```text
/assets/app.js
```

This gives more precise SPA behavior.

---

# 27. Caching Strategy

A React build may produce:

```text
index.html

assets/
├── app.a8bd921.js
├── vendor.c71a912.js
└── style.e92bd31.css
```

The hashed files are excellent candidates for long cache durations because a content change produces a **new filename**.

Architecture:

```text
app.a8bd921.js
        │
   long TTL
        │
        ▼
CloudFront
```

New deployment:

```text
app.f92ca12.js
```

No collision with old cached content.

CloudFront recommends versioned file names for frequently updated content rather than relying primarily on invalidations. ([AWS Documentation][12])

---

# 28. Production Cache Pattern

For hashed assets:

```text
Cache-Control:
public,max-age=31536000,immutable
```

For:

```text
index.html
```

something shorter is usually appropriate, for example:

```text
Cache-Control:
no-cache
```

or an intentionally short TTL.

The reason is:

```text
index.html
    │
    ▼
references current hashed assets
```

You want users to discover new deployments reasonably quickly.

CloudFront cache policies interact with origin `Cache-Control` and `Expires` headers; importantly, a nonzero minimum TTL can force caching even when the origin sends `no-cache`, `no-store`, or `private`. ([AWS Documentation][13])

---

# 29. Deploy Static Site

Suppose the frontend build is:

```text
dist/
├── index.html
└── assets/
```

Upload long-lived assets:

```bash
aws s3 sync \
  dist/assets/ \
  s3://my-private-site/assets/ \
  --delete \
  --cache-control "public,max-age=31536000,immutable"
```

Then upload the shell separately:

```bash
aws s3 cp \
  dist/index.html \
  s3://my-private-site/index.html \
  --cache-control "no-cache" \
  --content-type "text/html"
```

This gives CloudFront a much better caching model than applying the same TTL to every file.

---

# 30. Cache Invalidation

Suppose CloudFront has cached:

```text
/index.html
```

but you've just deployed a new one.

Force expiration:

```bash
aws cloudfront create-invalidation \
  --distribution-id E123ABC456XYZ \
  --paths "/index.html" "/"
```

Or broad emergency invalidation:

```bash
aws cloudfront create-invalidation \
  --distribution-id E123ABC456XYZ \
  --paths "/*"
```

CloudFront invalidations remove cached content before its normal expiration so the next request fetches it again from the origin. ([AWS Documentation][12])

For routine deployments, versioned/hash filenames are usually preferable to invalidating all assets. ([AWS Documentation][12])

---

# 31. CloudFront Signed URL vs S3 Presigned URL

This is a certification trap.

We learned:

```text
S3 Presigned URL
```

in Part 5.

Now we have:

```text
CloudFront Signed URL
```

They are different.

| S3 presigned URL                          | CloudFront signed URL                            |
| ----------------------------------------- | ------------------------------------------------ |
| Direct access to S3                       | Access through CloudFront                        |
| Signed with AWS credentials               | Signed using CloudFront trusted signer/key group |
| Useful for upload/download API operations | Usually private content delivery                 |
| Bypasses CloudFront cache path            | Uses CloudFront                                  |
| Time-limited S3 request                   | Time/policy-limited CDN access                   |

CloudFront recommends trusted key groups for signed URLs and signed cookies. ([AWS Documentation][14])

---

# 32. CloudFront Signed URL

Use when:

```text
one private file
```

should be accessible temporarily.

Example:

```text
paid-course/video-01.mp4
```

Flow:

```text
User authenticates
      │
      ▼
Application
      │
      ▼
CloudFront signed URL
      │
      ▼
Viewer
      │
      ▼
CloudFront verifies signature
      │
      ▼
content
```

CloudFront signed URLs are designed to restrict access to individual files or specific resources. ([AWS Documentation][15])

---

# 33. Signed Cookies

Suppose user needs:

```text
/course/module1/*
```

containing:

```text
video1
video2
PDF
images
captions
```

Creating a signed URL for every file is inconvenient.

Use:

```text
CloudFront signed cookies
```

to authorize a group of resources without modifying each content URL. ([AWS Documentation][16])

Mental shortcut:

```text
ONE FILE
   │
   ▼
Signed URL


MANY FILES / PATH
   │
   ▼
Signed Cookies
```

---

# 34. WAF in Front of CloudFront

Production:

```text
Internet
   │
   ▼
AWS WAF
   │
   ▼
CloudFront
   │
   ▼
S3
```

WAF can evaluate requests before they're served by your distribution.

Possible controls include:

```text
managed rule groups
IP rules
rate-based controls
bot/security rules
geographic/application rules
```

A CloudFront standard distribution can be associated with a WAF web ACL. ([AWS Documentation][17])

---

# 35. WAF Region Rule

Another:

```text
us-east-1
```

rule.

For CloudFront:

```text
ACM viewer certificate
=
us-east-1
```

and:

```text
WAF Web ACL for CloudFront
=
global scope represented in us-east-1
```

AWS requires CloudFront WAFv2 resources to be created with `CLOUDFRONT` scope in `us-east-1`. ([AWS Documentation][18])

### Never forget

```text
CloudFront-related:

ACM → us-east-1
WAF → us-east-1/global
```

---

# 36. Full Terraform Provider Pattern

Our main resources:

```text
S3
=
ap-south-1
```

But ACM and CloudFront WAF-related regional resources:

```text
us-east-1
```

Terraform:

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

This multi-provider pattern is fundamental for CloudFront deployments.

---

# 37. Terraform S3

```hcl
resource "aws_s3_bucket" "site" {
  bucket = var.site_bucket_name
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
```

Notice:

```text
NO public website policy
```

because this is a private OAC architecture.

---

# 38. Terraform OAC

```hcl
resource "aws_cloudfront_origin_access_control" "site" {
  name = "site-oac"

  description = "OAC for private static-site bucket"

  origin_access_control_origin_type = "s3"

  signing_behavior = "always"
  signing_protocol = "sigv4"
}
```

The AWS Terraform provider currently provides a dedicated `aws_cloudfront_origin_access_control` resource for this CloudFront/S3 relationship. ([Terraform Registry][19])

---

# 39. Terraform CloudFront Distribution

```hcl
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "site" {

  enabled             = true
  default_root_object = "index.html"

  aliases = [
    var.domain_name
  ]

  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "private-s3"

    origin_access_control_id =
      aws_cloudfront_origin_access_control.site.id

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  default_cache_behavior {
    target_origin_id = "private-s3"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id =
      data.aws_cloudfront_cache_policy.optimized.id

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.cloudfront_certificate_arn

    ssl_support_method = "sni-only"

    minimum_protocol_version =
      "TLSv1.2_2021"
  }
}
```

CloudFront's current Terraform resource supports S3 origins, cache behavior configuration, alternate domain names, and an OAC ID on an origin. ([Terraform Registry][20])

---

# 40. Bucket Policy After Distribution Exists

```hcl
data "aws_iam_policy_document" "site" {

  statement {
    sid = "AllowCloudFrontRead"

    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "cloudfront.amazonaws.com"
      ]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.site.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.site.arn
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = data.aws_iam_policy_document.site.json
}
```

This is the same service-principal + distribution-SourceArn authorization model AWS recommends for OAC. ([AWS Documentation][1])

---

# 41. Route 53 Alias

Assuming the hosted zone is Route 53:

```hcl
data "aws_route53_zone" "main" {
  name = var.zone_name
}

resource "aws_route53_record" "site" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name =
      aws_cloudfront_distribution.site.domain_name

    zone_id =
      aws_cloudfront_distribution.site.hosted_zone_id

    evaluate_target_health = false
  }
}
```

Route 53 aliases are the normal way to point both root domains and subdomains at CloudFront distributions. ([AWS Documentation][7])

---

# 42. ACM Provider Pattern

Certificate:

```hcl
resource "aws_acm_certificate" "site" {
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
```

The important part:

```text
provider = aws.us_east_1
```

because CloudFront viewer certificates in ACM must reside in `us-east-1`. ([AWS Documentation][6])

---

# 43. Build + Deploy Flow

Your CI/CD pipeline can become:

```text
Git push
   │
   ▼
CI
   │
npm ci
   │
npm test
   │
npm run build
   │
   ▼
dist/
   │
   ▼
S3 sync
   │
   ▼
CloudFront invalidation
   │
   ▼
users receive new app
```

Commands:

```bash
npm ci
npm test
npm run build
```

then:

```bash
aws s3 sync \
  dist/assets/ \
  s3://"$BUCKET"/assets/ \
  --delete \
  --cache-control "public,max-age=31536000,immutable"
```

then:

```bash
aws s3 cp \
  dist/index.html \
  s3://"$BUCKET"/index.html \
  --cache-control "no-cache" \
  --content-type "text/html"
```

and optionally:

```bash
aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/" "/index.html"
```

---

# 44. Validation

First CloudFront itself:

```bash
curl -I \
  https://d123456abcdef.cloudfront.net/
```

Expected:

```text
HTTP/2 200
```

Then custom domain:

```bash
curl -I \
  https://app.example.com/
```

Then direct S3:

```bash
curl -I \
  https://my-private-site.s3.ap-south-1.amazonaws.com/index.html
```

For the private OAC design:

```text
direct S3
=
AccessDenied
```

is actually good.

It proves:

```text
CloudFront works

AND

users cannot bypass CloudFront
```

---

# 45. Verify DNS

```bash
dig app.example.com
```

or:

```bash
nslookup app.example.com
```

You should ultimately see resolution toward CloudFront's infrastructure.

If CloudFront default URL works but custom domain doesn't, focus first on:

```text
DNS
CloudFront alternate domain
certificate
```

rather than S3.

---

# 46. 403 Troubleshooting — The Golden Chain

CloudFront returns:

```text
403 Forbidden
```

Use:

```text
Viewer
  │
  ▼
Correct custom domain?
  │
  ▼
CloudFront alias configured?
  │
  ▼
Certificate covers hostname?
  │
  ▼
WAF blocking?
  │
  ▼
Correct origin?
  │
  ▼
REST S3 endpoint?
  │
  ▼
OAC attached?
  │
  ▼
Bucket policy?
  │
  ▼
AWS:SourceArn correct?
  │
  ▼
Object exists?
  │
  ▼
Correct key/path?
  │
  ▼
SSE-KMS?
  │
  ▼
KMS policy?
```

AWS lists incorrect custom domains, WAF, origin authorization, bad paths, nonexistent S3 objects, OAI/OAC problems, signed URL/cookie issues, and other controls among common CloudFront 403 causes. ([AWS Documentation][8])

---

# 47. Scenario — CloudFront URL Works, Custom Domain Gives 403

You test:

```text
https://d123.cloudfront.net
```

Result:

```text
200
```

But:

```text
https://app.example.com
```

returns:

```text
403
```

Think:

```text
CloudFront alternate domain/CNAME
```

before S3.

AWS notes that pointing DNS to a distribution without adding the hostname to the CloudFront distribution can result in a 403. ([AWS Documentation][8])

---

# 48. Scenario — Root Gives 403 but `/index.html` Works

```text
https://example.com/index.html
=
200
```

but:

```text
https://example.com/
=
403
```

Check:

```text
DefaultRootObject
```

and ensure it is:

```text
index.html
```

not:

```text
/index.html
```

AWS explicitly documents that a leading slash can cause this exact kind of 403. ([AWS Documentation][9])

---

# 49. Scenario — Root Works but `/dashboard` Fails

```text
/
=
200


/dashboard
=
403
```

For React/Vue/Angular SPA:

```text
not necessarily OAC problem
```

Likely:

```text
SPA route
does not correspond to
an S3 object
```

Implement:

```text
CloudFront Function rewrite
```

or carefully configured SPA fallback behavior.

---

# 50. Scenario — Everything 403 After OAC

Check bucket policy:

```text
Principal:
cloudfront.amazonaws.com
```

then:

```text
Action:
s3:GetObject
```

then:

```text
Resource:
bucket/*
```

then:

```text
AWS:SourceArn:
correct distribution ARN
```

AWS's OAC model depends on exactly these elements. ([AWS Documentation][1])

---

# 51. Scenario — SSE-KMS Site Returns 403

If normal SSE-S3 works but changing the bucket to SSE-KMS causes:

```text
403
```

think:

```text
S3 permission
+
KMS permission
```

Check:

```text
CloudFront service principal
      │
      ▼
KMS key policy
      │
      ▼
AWS:SourceArn distribution
```

OAC requires appropriate KMS-key permissions for SSE-KMS content. ([AWS Documentation][1])

---

# 52. Scenario — CloudFront Still Serves Old Deployment

You changed:

```text
index.html
```

in S3.

But CloudFront returns old content.

Likely:

```text
cache hit
```

not:

```text
S3 upload failed
```

Check caching headers and distribution cache policy.

Then either:

```text
wait for TTL
```

or:

```text
invalidate
```

or, for assets, use:

```text
versioned/hash filenames
```

CloudFront recommends versioned filenames for frequent content updates. ([AWS Documentation][12])

---

# 53. Scenario — Direct S3 URL Gives 403

Architecture uses:

```text
CloudFront + OAC
```

and direct S3 gives:

```text
403
```

Good.

Don't "fix" it by making S3 public.

The entire goal was:

```text
Viewer
   X
   │
   ▼
S3


Viewer
   │
   ▼
CloudFront
   │
   ▼
S3
```

---

# 54. Scenario — Website Endpoint + OAC

You configure origin:

```text
bucket.s3-website...
```

and then try to attach OAC.

Architectural mismatch.

Website endpoint means:

```text
CUSTOM ORIGIN
```

and CloudFront explicitly says OAC/OAI cannot be used with an S3 website endpoint. ([AWS Documentation][1])

Use:

```text
bucket regional REST endpoint
```

instead.

---

# 55. SAA-C03 Scenarios

| Requirement                  | First answer                        |
| ---------------------------- | ----------------------------------- |
| Secure static website        | CloudFront + private S3 + OAC       |
| HTTPS custom domain          | CloudFront + ACM                    |
| CloudFront ACM certificate   | `us-east-1`                         |
| Prevent S3 bypass            | private bucket + OAC                |
| S3 website endpoint with OAC | Not supported                       |
| `/` should serve home page   | Default root object                 |
| React refresh gives 403      | SPA routing/fallback                |
| Globally cache static assets | CloudFront                          |
| Protected single CDN object  | CloudFront signed URL               |
| Protect many CDN files       | signed cookies                      |
| Web attack filtering         | AWS WAF                             |
| Updated file remains stale   | TTL/invalidation/versioned filename |

These behaviors follow current CloudFront, S3, ACM, Route 53, and WAF guidance. ([AWS Documentation][1])

---

# 56. Interview Question

> **How would you securely host a React application on AWS?**

A strong answer:

> I'd build the React application into static assets and store them in a private S3 general-purpose bucket with Block Public Access enabled and ACLs disabled. I'd place CloudFront in front of S3 and use Origin Access Control so only the CloudFront distribution can retrieve objects from the bucket. I'd redirect viewers to HTTPS, attach an ACM certificate from `us-east-1`, configure the custom hostname as a CloudFront alternate domain name, and point Route 53 aliases to the distribution. I'd cache immutable hashed assets for a long period while keeping `index.html` short-lived, and use a CloudFront Function or carefully designed error fallback for SPA routes. For higher-security internet applications I'd associate AWS WAF, and if the S3 content used SSE-KMS I'd update the KMS key policy so the OAC-enabled distribution could decrypt it. ([AWS Documentation][1])

That is a **production architecture answer**, not:

> “Enable S3 website hosting.”

---

# 57. Never-Forget Static Site Architecture

```text
                       USER
                        │
                      HTTPS
                        │
                        ▼
                    Route 53
                        │
                        ▼
                  ┌───────────┐
                  │CloudFront │
                  │           │
                  │ Cache     │
                  │ HTTPS     │
                  │ OAC       │
                  │ WAF       │
                  └─────┬─────┘
                        │
                     SigV4
                        │
                        ▼
                  ┌───────────┐
                  │Private S3 │
                  │           │
                  │ BPA ON    │
                  │ ACL OFF   │
                  │ SSE       │
                  └───────────┘

Viewer certificate:
us-east-1

S3 bucket:
ap-south-1
```

---

# 58. The 15 Rules to Permanently Remember

1. **S3 website endpoint and S3 REST endpoint are different.** Website endpoints behave like public/custom HTTP origins; the regular bucket endpoint supports private OAC access. ([AWS Documentation][1])
2. **OAC + private S3 is the modern CloudFront/S3 security pattern.**
3. **Keep S3 Block Public Access enabled.**
4. **Use `cloudfront.amazonaws.com` plus the distribution `AWS:SourceArn` in the bucket policy.** ([AWS Documentation][1])
5. **OAC and OAI don't work with an S3 website endpoint.** ([AWS Documentation][1])
6. **CloudFront viewer ACM certificates live in `us-east-1`.** ([AWS Documentation][6])
7. **Certificate SANs must cover every custom CloudFront hostname.** ([AWS Documentation][6])
8. **Route 53 alias → CloudFront is the normal DNS pattern.** ([AWS Documentation][7])
9. **Default root object is `index.html`, not `/index.html`.** ([AWS Documentation][9])
10. **Default root object does not solve every SPA route.**
11. **Use long caching for hashed immutable assets and shorter caching for the HTML shell.**
12. **Prefer versioned filenames over broad invalidations for routine asset updates.** ([AWS Documentation][12])
13. **CloudFront signed URLs are different from S3 presigned URLs.**
14. **SSE-KMS requires CloudFront authorization in the KMS key policy.** ([AWS Documentation][1])
15. **A direct S3 403 can be exactly what you want when CloudFront + OAC is working.**

The biggest rule:

```text
PUBLIC WEBSITE
does NOT require
PUBLIC S3 BUCKET.
```

With CloudFront OAC:

```text
PUBLIC:
CloudFront

PRIVATE:
S3
```

That is the architecture to remember.

---

# ✅ Lesson 27 Part 6 Complete

You now understand:

```text
✓ S3 website endpoint
✓ S3 REST origin
✓ OAC
✓ OAI legacy distinction
✓ private S3
✓ bucket policy
✓ AWS:SourceArn
✓ SSE-KMS + OAC
✓ CloudFront CDN
✓ cache hit / miss
✓ HTTPS
✓ ACM us-east-1
✓ SAN / wildcard behavior
✓ custom domains
✓ Route 53 alias
✓ default root object
✓ SPA routing
✓ CloudFront Functions
✓ custom error responses
✓ cache-control strategy
✓ hashed assets
✓ invalidations
✓ CloudFront signed URLs
✓ signed cookies
✓ AWS WAF
✓ WAF CloudFront scope
✓ Terraform multi-provider design
✓ Terraform S3 + OAC + CloudFront
✓ CI/CD deployment
✓ 403 troubleshooting
✓ CloudFront/S3/KMS troubleshooting
```

## Next — Lesson 27 Part 7: Advanced S3 Architecture

Next we'll finish the deeper S3 platform capabilities:

```text
S3 ADVANCED ARCHITECTURE

        │
        ├── S3 Access Points
        ├── Access Point policies
        ├── VPC-only Access Points
        ├── Multi-Region Access Points
        ├── active-active S3 access
        ├── failover controls
        ├── S3 Access Grants
        ├── S3 Batch Operations
        ├── Batch Replication
        ├── S3 Inventory-driven operations
        ├── S3 Storage Lens
        ├── S3 Express One Zone
        ├── Directory buckets
        ├── high-performance workloads
        ├── S3 event-driven data lakes
        ├── Athena / Glue architecture
        ├── Macie security concepts
        ├── CloudTrail auditing
        ├── large-enterprise bucket design
        ├── multi-account S3 governance
        ├── Terraform enterprise patterns
        └── final Lesson 27 certification review
```

After that, you should be able to design S3 not just as **“a bucket for files,”** but as an enterprise object-storage platform spanning security, CDN delivery, DR, analytics, automation, governance, cost, and multi-account architecture.

[1]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html "Restrict access to an Amazon S3 origin - Amazon CloudFront"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/HostingWebsiteOnS3Setup.html?utm_source=chatgpt.com "Tutorial: Configuring a static website on Amazon S3"
[3]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Introduction.html?utm_source=chatgpt.com "What is Amazon CloudFront? - Amazon CloudFront"
[4]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cache-statistics.html?utm_source=chatgpt.com "View CloudFront cache statistics reports - AWS Documentation"
[5]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-https.html?utm_source=chatgpt.com "Use HTTPS with CloudFront"
[6]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html "Requirements for using SSL/TLS certificates with CloudFront - Amazon CloudFront"
[7]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-cloudfront-distribution.html?utm_source=chatgpt.com "Routing traffic to an Amazon CloudFront distribution by using ..."
[8]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/http-403-permission-denied.html "HTTP 403 status code (Permission Denied) - Amazon CloudFront"
[9]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DefaultRootObject.html "Specify a default root object - Amazon CloudFront"
[10]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/GeneratingCustomErrorResponses.html?utm_source=chatgpt.com "Generate custom error responses - Amazon CloudFront"
[11]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/example_cloudfront_functions_url_rewrite_single_page_apps_section.html?utm_source=chatgpt.com "Add index.html to request URLs without a file name in ..."
[12]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html "Invalidate files to remove content - Amazon CloudFront"
[13]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Expiration.html?utm_source=chatgpt.com "Manage how long content stays in the cache (expiration)"
[14]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-trusted-signers.html?utm_source=chatgpt.com "Specify signers that can create signed URLs and signed cookies"
[15]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-urls.html?utm_source=chatgpt.com "Use signed URLs - Amazon CloudFront"
[16]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-cookies.html?utm_source=chatgpt.com "Use signed cookies - Amazon CloudFront"
[17]: https://docs.aws.amazon.com/waf/latest/developerguide/cloudfront-features.html?utm_source=chatgpt.com "Using AWS WAF with Amazon CloudFront"
[18]: https://docs.aws.amazon.com/waf/latest/developerguide/how-aws-waf-works-resources.html?utm_source=chatgpt.com "Resources that you can protect with AWS WAF"
[19]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control?utm_source=chatgpt.com "aws_cloudfront_origin_access_c..."
[20]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution "Terraform Registry"
