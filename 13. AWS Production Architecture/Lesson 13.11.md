# AWS Masterclass — Lesson 10

## CloudFront In Depth — CDN, Origins, Cache Policies, OAC, Invalidation, Signed URLs, WAF, Logs, and Production Troubleshooting

Today we go deep into **CloudFront**, because it connects many AWS production concepts:

```text id="lesson-focus"
CDN
edge locations
distribution
origin
cache behavior
cache key
cache policy
origin request policy
response headers policy
S3 private origin
ALB origin
OAC
invalidation
signed URLs
signed cookies
WAF
logs
403/502 troubleshooting
cost-safe cleanup
```

Your uploaded architect course includes **CloudFront** under networking and content delivery , and your AWS Academy developing outline includes caching with **CloudFront** as part of the caching module .

---

# 1. What is CloudFront?

CloudFront is AWS’s **Content Delivery Network**, or CDN.

Simple meaning:

```text id="cloudfront-simple"
CloudFront sits between users and your origin,
serves cached content from locations close to users,
and forwards requests to the origin only when needed.
```

AWS describes CloudFront as a service for securely delivering data, videos, applications, and APIs globally with low latency and high transfer speeds. ([AWS Documentation][1])

Basic flow:

```text id="basic-flow"
User
  ↓
CloudFront edge location
  ↓ if cache miss
Origin:
  S3 / ALB / EC2 / API Gateway
```

---

# 2. Why CloudFront exists

Without CloudFront:

```text id="without-cloudfront"
User in Delhi
  ↓
Origin in ap-south-1
```

Every request goes to origin.

With CloudFront:

```text id="with-cloudfront"
User in Delhi
  ↓
Nearby CloudFront edge
  ↓ only if cache miss
Origin in ap-south-1
```

Benefits:

```text id="benefits"
lower latency
less origin load
global content delivery
HTTPS termination
DDoS protection integration
WAF integration
path-based origin routing
private S3 delivery through OAC
```

Never think CloudFront is only for static websites. It can front:

```text id="cloudfront-fronts"
S3 static assets
ALB web apps
API Gateway APIs
EC2 custom origins
Lambda function URLs
media workloads
multi-origin apps
```

---

# 3. CloudFront vocabulary

## Distribution

A distribution is the main CloudFront resource.

```text id="distribution"
CloudFront distribution:
  global CDN configuration
```

It contains:

```text id="distribution-contains"
origins
cache behaviors
default cache behavior
viewer certificate
alternate domain names
logging settings
WAF association
price class
error responses
```

---

## Origin

Origin means the backend CloudFront fetches from.

Examples:

```text id="origins"
S3 bucket
Application Load Balancer
API Gateway
EC2 public DNS
custom web server
```

Simple:

```text id="origin-simple"
Origin = real source of content
CloudFront = global front door/cache
```

---

## Viewer

Viewer means the client making request to CloudFront.

```text id="viewer"
browser
mobile app
curl
API client
```

---

## Cache behavior

A cache behavior says:

```text id="cache-behavior"
For requests matching this path,
use this origin,
with these cache/security/request rules.
```

Example:

```text id="behaviors-example"
/assets/*:
  origin = S3
  cache long

/api/*:
  origin = ALB
  cache disabled or short

default:
  origin = frontend
```

CloudFront cache behaviors map request patterns to origins and settings. ([AWS Documentation][2])

---

# 4. The most important CloudFront architecture

Production web app:

```text id="prod-arch"
User
  ↓ HTTPS
CloudFront
  ├── /assets/* → private S3 bucket through OAC
  └── /api/*    → ALB in ap-south-1
                    ↓
                  EC2/ECS/EKS app
                    ↓
                  database
```

For your `yourdatascientist.tech` future setup:

```text id="yourdomain"
app.yourdatascientist.tech
  ↓
CloudFront
  ├── static files from private S3
  └── backend traffic to ALB
```

---

# 5. Cache hit vs cache miss

## Cache hit

```text id="cache-hit"
User requests /logo.png
CloudFront already has /logo.png cached
CloudFront returns it directly
Origin is not contacted
```

Good result:

```text id="hit-result"
fast response
less origin load
lower origin cost
```

## Cache miss

```text id="cache-miss"
User requests /logo.png
CloudFront does not have it cached
CloudFront fetches it from origin
CloudFront stores it
CloudFront returns it to user
```

Important terms:

```text id="cache-terms"
Hit:
  served from CloudFront cache

Miss:
  fetched from origin

TTL:
  how long cached object stays fresh

Invalidation:
  force CloudFront to remove cached object
```

---

# 6. Cache key

This is extremely important.

Cache key decides whether two requests are considered the same cached object.

Example 1:

```text id="cache-key-simple"
Request:
  /logo.png

Cache key:
  path only
```

All users requesting `/logo.png` get same cached object.

Example 2:

```text id="cache-key-query"
Request:
  /products?id=10
  /products?id=20

Cache key includes query string:
  these are different cache objects
```

Example 3:

```text id="cache-key-cookie"
Request includes session cookie.

If cookie is in cache key:
  different users can get different cache objects.

If cookie is not in cache key:
  dangerous for personalized content.
```

Golden rule:

```text id="cache-key-rule"
Only include headers, cookies, and query strings in the cache key
when they actually change the response.
```

Why?

```text id="cache-key-why"
Too many cache key values:
  low cache hit ratio

Too few cache key values:
  wrong content may be served
```

---

# 7. Cache policy

A cache policy controls:

```text id="cache-policy-controls"
TTL settings
which headers affect cache key
which cookies affect cache key
which query strings affect cache key
compression behavior
```

CloudFront cache policies define cache key settings and TTL behavior, and TTLs work together with origin `Cache-Control` and `Expires` headers to decide how long cached objects remain valid. ([AWS Documentation][3])

Common choices:

```text id="cache-policy-choices"
Static assets:
  Managed-CachingOptimized

APIs/dynamic content:
  Managed-CachingDisabled

Custom needs:
  create custom cache policy
```

---

# 8. Origin request policy

Origin request policy controls what CloudFront sends to origin on an origin request.

It can forward:

```text id="origin-request-forward"
headers
cookies
query strings
CloudFront-added headers
```

Important distinction:

```text id="cache-vs-origin-policy"
Cache policy:
  What makes a cache entry unique?

Origin request policy:
  What should CloudFront send to origin?
```

CloudFront origin request policies control which query strings, headers, and cookies are sent to the origin, and values included in the cache key are automatically included in origin requests. ([AWS Documentation][4])

Example:

```text id="api-policy"
For /api/*:
  cache disabled
  forward authorization header
  forward query strings
  maybe forward cookies

For /assets/*:
  cache optimized
  do not forward unnecessary cookies
```

---

# 9. Response headers policy

Response headers policy controls headers CloudFront adds to responses.

Use it for:

```text id="headers-use"
security headers
CORS headers
custom headers
Server-Timing
remove/override origin headers
```

Examples of security headers:

```text id="security-headers"
Strict-Transport-Security
X-Content-Type-Options
X-Frame-Options
Referrer-Policy
Content-Security-Policy
```

CloudFront response headers policies can add or remove HTTP response headers and can be attached to cache behaviors. ([AWS Documentation][5])

Production use:

```text id="response-prod"
Attach response headers policy to add baseline security headers.
Use CORS headers carefully for APIs/assets.
```

---

# 10. S3 origin: REST endpoint vs website endpoint

This is a common confusion.

## S3 REST origin

Example:

```text id="s3-rest"
my-bucket.s3.ap-south-1.amazonaws.com
```

Use with:

```text id="rest-use"
private S3 bucket
CloudFront OAC
S3 bucket policy
HTTPS to S3
```

## S3 website endpoint

Example:

```text id="s3-website"
my-bucket.s3-website.ap-south-1.amazonaws.com
```

Use when:

```text id="website-use"
you specifically need S3 website hosting behavior
```

But important:

```text id="website-warning"
S3 website endpoints are custom HTTP origins,
not S3 REST origins.
They do not support OAC the same way.
They do not support HTTPS from CloudFront to S3 website endpoint.
```

AWS documentation notes that if an S3 bucket is configured as a website endpoint, CloudFront cannot use HTTPS to communicate with that origin because S3 website endpoints do not support HTTPS. ([AWS Documentation][6])

Production rule:

```text id="s3-prod-rule"
For private static content:
  use S3 REST origin + CloudFront OAC

Avoid:
  public S3 website bucket for production private-origin pattern
```

---

# 11. OAC — Origin Access Control

OAC means:

```text id="oac"
Origin Access Control
```

Simple meaning:

```text id="oac-simple"
OAC lets CloudFront securely access a private S3 bucket.
Users cannot bypass CloudFront and access S3 directly.
```

Flow:

```text id="oac-flow"
User
  ↓
CloudFront
  ↓ signed request using OAC
Private S3 bucket
```

AWS CloudFront supports OAC and OAI for authenticated requests to S3 origins, and OAC is the modern approach for restricting direct S3 access through CloudFront. ([AWS Documentation][7])

Bucket policy idea:

```json id="bucket-policy-example"
{
  "Effect": "Allow",
  "Principal": {
    "Service": "cloudfront.amazonaws.com"
  },
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket/*",
  "Condition": {
    "StringEquals": {
      "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/E123ABC456"
    }
  }
}
```

Meaning:

```text id="bucket-policy-meaning"
Only this CloudFront distribution can read objects.
Direct public access is still blocked.
```

---

# 12. OAC vs OAI

| Feature           | OAC                        | OAI                  |
| ----------------- | -------------------------- | -------------------- |
| Status            | modern/recommended pattern | older legacy pattern |
| S3 private access | yes                        | yes                  |
| SigV4 support     | better                     | limited              |
| SSE-KMS support   | better                     | limited              |
| New projects      | prefer OAC                 | avoid unless legacy  |

Simple rule:

```text id="oac-rule"
New CloudFront + S3 projects:
  use OAC

Existing old distributions:
  may still use OAI, but plan migration carefully
```

---

# 13. ALB origin

CloudFront can use ALB as origin.

Flow:

```text id="alb-origin-flow"
User
  ↓ HTTPS
CloudFront
  ↓ HTTP/HTTPS
ALB
  ↓
EC2/ECS/EKS targets
```

Use ALB origin when:

```text id="alb-origin-use"
dynamic application
REST API
backend service
multi-target app
path-based routing behind ALB
CloudFront WAF/caching/TLS in front
```

Important:

```text id="alb-origin-warning"
If ALB is public,
users may bypass CloudFront and hit ALB directly unless you restrict it.
```

Common protections:

```text id="alb-origin-protection"
custom header from CloudFront to ALB/app
AWS WAF at CloudFront
ALB security group restricted where possible
app checks expected header
CloudFront-only architecture patterns
```

---

# 14. Viewer protocol policy

Viewer protocol policy controls user → CloudFront protocol.

Options:

```text id="viewer-options"
allow-all:
  allow HTTP and HTTPS

redirect-to-https:
  HTTP redirects to HTTPS

https-only:
  reject HTTP
```

Production default:

```text id="viewer-prod"
redirect-to-https
```

For APIs with strict security:

```text id="api-prod"
https-only
```

---

# 15. Origin protocol policy

Origin protocol policy controls CloudFront → custom origin protocol.

Options for custom origins:

```text id="origin-protocol"
http-only
https-only
match-viewer
```

Production guidance:

```text id="origin-prod"
CloudFront → ALB should use HTTPS when end-to-end encryption is required.
For internal/simple labs, HTTP to ALB is common.
```

If using HTTPS to ALB, the ALB certificate must match the origin domain name used by CloudFront.

---

# 16. CloudFront and ACM certificate rule

For custom domains on CloudFront:

```text id="cert-rule"
ACM certificate must be in us-east-1.
```

Even if origin is in:

```text id="origin-region"
ap-south-1
```

CloudFront custom-domain viewer certificate must be in:

```text id="cf-cert-region"
us-east-1
```

CloudFront documentation states that ACM certificates used with CloudFront must be requested or imported in the US East, N. Virginia Region, `us-east-1`. ([AWS Documentation][1])

---

# 17. Invalidation

Invalidation removes cached content before TTL expires.

Example:

```bash id="invalidation-example"
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/index.html"
```

Use when:

```text id="invalidation-use"
CloudFront still serves old content
and you need fresh content immediately
```

AWS documentation says you can remove a file from CloudFront edge caches by invalidating it, and the next viewer request causes CloudFront to fetch the latest version from origin. It also recommends versioned file names for frequent updates because versioning improves control and can reduce invalidation cost. ([AWS Documentation][8])

Best practice:

```text id="versioned-assets"
Use versioned filenames:
  app.abc123.js
  style.def456.css

Then cache static assets for a long time.
```

Use invalidation mainly for:

```text id="invalidate-list"
index.html
emergency rollback
mistaken file
small number of paths
```

Avoid frequent:

```text id="avoid-invalidation"
aws cloudfront create-invalidation --paths "/*"
```

---

# 18. Signed URLs and signed cookies

Use these for private content.

## Signed URL

A signed URL gives temporary access to one private resource.

Example:

```text id="signed-url-example"
User paid for course video.
Backend generates signed URL valid for 10 minutes.
User can stream/download only during that time.
```

CloudFront signed URLs can restrict access to private content for a limited time, even for just a few minutes. ([AWS Documentation][9])

Use signed URL when:

```text id="signed-url-use"
one file
temporary download
email link
paid invoice/download
private document
```

## Signed cookie

Signed cookies give access to multiple restricted files without changing each URL.

Use signed cookies when:

```text id="signed-cookie-use"
subscriber area
many videos
many images
private course content
keep normal URLs
```

CloudFront signed cookies are useful when you want to control access to multiple restricted files or do not want to change your current URLs. ([AWS Documentation][10])

Never confuse:

```text id="signed-never"
S3 pre-signed URL:
  temporary direct S3 access

CloudFront signed URL:
  temporary CloudFront access

CloudFront signed cookie:
  temporary CloudFront access to multiple files
```

---

# 19. AWS WAF with CloudFront

WAF means:

```text id="waf"
Web Application Firewall
```

Use it to protect HTTP/HTTPS applications from bad requests.

WAF can help with:

```text id="waf-use"
SQL injection patterns
cross-site scripting patterns
bad bots
rate limiting
IP allow/block lists
country-based rules
managed rule groups
OWASP-style protections
```

AWS WAF web ACLs provide fine-grained control over HTTP(S) requests and can be associated with CloudFront, API Gateway, ALB, AppSync, Cognito, App Runner, Amplify, and other supported resources. ([AWS Documentation][11])

Important CloudFront WAF rule:

```text id="waf-region"
CloudFront WAF web ACL is global
and uses us-east-1 style global scope.
```

AWS WAF documentation says a global web ACL can be associated with a CloudFront distribution and has a hard-coded US East/N. Virginia Region. ([AWS Documentation][12])

Production default:

```text id="waf-prod"
Public production CloudFront:
  attach WAF
  start with managed rules
  add rate limiting
  monitor false positives
```

---

# 20. CloudFront logs

CloudFront logging helps troubleshoot and analyze traffic.

Types:

```text id="log-types"
standard logs:
  access logs delivered periodically

real-time logs:
  near real-time request logs

CloudTrail:
  API activity logs for CloudFront config changes
```

CloudFront standard logging can send access logs to CloudWatch Logs, Amazon Data Firehose, or S3, and real-time logs provide information within seconds of requests. ([AWS Documentation][13])

Useful log fields:

```text id="log-fields"
timestamp
edge location
client IP
HTTP method
host
URI path
status code
result type
bytes sent
user agent
referer
origin latency
cache hit/miss behavior
```

Use logs for:

```text id="logs-use"
403 troubleshooting
502 troubleshooting
cache hit analysis
bot traffic detection
popular path analysis
latency analysis
security investigation
```

---

# 21. CloudFront error codes

## 403 Forbidden

Usually means access or permissions issue.

Common causes:

```text id="403-causes"
S3 bucket policy missing CloudFront permission
OAC not attached
wrong S3 origin type
object does not exist
default root object missing
viewer requests directory path without index handling
WAF blocks request
signed URL/cookie invalid or expired
```

## 404 Not Found

Usually means object/path does not exist.

```text id="404"
CloudFront reached origin,
but origin did not find requested object/path.
```

## 502 Bad Gateway

Often origin connection/TLS issue.

Common causes:

```text id="502-causes"
ALB origin TLS certificate mismatch
origin closed connection
wrong origin protocol policy
origin DNS issue
ALB listener problem
target application crash
```

## 503 Service Unavailable

Common causes:

```text id="503-causes"
origin unavailable
ALB no healthy targets
origin overloaded
CloudFront distribution issue
```

## 504 Gateway Timeout

Common causes:

```text id="504-causes"
origin did not respond in time
security group blocked CloudFront/ALB path
target app slow
NACL/firewall issue
```

---

# 22. Production cache rules

Use this table.

| Path          | Origin  | Cache policy      | Origin request policy                |
| ------------- | ------- | ----------------- | ------------------------------------ |
| `/assets/*`   | S3      | long cache        | minimal forwarding                   |
| `/images/*`   | S3      | long cache        | minimal forwarding                   |
| `/index.html` | S3      | short cache       | minimal forwarding                   |
| `/api/*`      | ALB/API | disabled or short | forward needed headers/query/cookies |
| `/admin/*`    | ALB     | disabled or short | forward auth/session info            |
| `/health`     | ALB     | disabled          | minimal forwarding                   |

Golden rule:

```text id="golden-cache"
Cache static/versioned content aggressively.
Do not cache personalized or authenticated responses unless designed carefully.
```

Dangerous mistake:

```text id="danger-cache"
Caching /api/user/profile without including user identity in cache key.
```

Result:

```text id="danger-result"
User A might receive User B's cached response.
```

---

# 23. Hands-On Lab 10A — Private S3 Website Through CloudFront OAC

This lab creates:

```text id="lab-creates"
1 private S3 bucket
2 small objects
1 CloudFront OAC
1 CloudFront distribution
1 S3 bucket policy scoped to CloudFront distribution
```

Cost warning:

```text id="cost"
CloudFront, S3 storage, S3 requests, CloudFront requests, and data transfer may generate charges.
Keep test objects tiny.
Delete everything after the lab.
CloudFront deletion can take time because distributions must be disabled before deletion.
```

Region:

```text id="region"
S3 bucket:
  ap-south-1

CloudFront:
  global

ACM custom domain:
  not used in this lab
```

We will use the default CloudFront domain first:

```text id="default-domain"
https://dxxxxx.cloudfront.net
```

---

## Step 1 — Set variables

```bash id="vars"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TS="$(date +%Y%m%d%H%M%S)"

BUCKET="aws-masterclass-cf-oac-${ACCOUNT_ID}-${TS}"
ORIGIN_ID="s3-origin-${BUCKET}"

echo "ACCOUNT_ID=$ACCOUNT_ID"
echo "BUCKET=$BUCKET"
```

---

## Step 2 — Create S3 bucket

```bash id="create-bucket"
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
```

Block public access:

```bash id="block-public"
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
```

Enable encryption:

```bash id="bucket-encryption"
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'
```

---

## Step 3 — Upload content

```bash id="upload-content"
mkdir -p /tmp/aws-masterclass-cloudfront

cat > /tmp/aws-masterclass-cloudfront/index.html <<'EOF'
<!doctype html>
<html>
  <head>
    <title>AWS Masterclass CloudFront OAC</title>
  </head>
  <body>
    <h1>Hello from private S3 through CloudFront OAC</h1>
    <p>This S3 bucket is private. CloudFront is the public entry point.</p>
  </body>
</html>
EOF

cat > /tmp/aws-masterclass-cloudfront/health.json <<'EOF'
{"status":"healthy","service":"cloudfront-oac-lab"}
EOF

aws s3 cp /tmp/aws-masterclass-cloudfront/index.html "s3://$BUCKET/index.html" \
  --content-type "text/html"

aws s3 cp /tmp/aws-masterclass-cloudfront/health.json "s3://$BUCKET/health.json" \
  --content-type "application/json"
```

---

## Step 4 — Confirm direct S3 is private

```bash id="direct-s3-test"
curl -I "https://${BUCKET}.s3.ap-south-1.amazonaws.com/index.html" || true
```

Expected:

```text id="direct-s3-expected"
403 Forbidden
```

That is good. The bucket is private.

---

## Step 5 — Create Origin Access Control

```bash id="oac-config"
cat > /tmp/oac-config.json <<EOF
{
  "Name": "aws-masterclass-oac-${TS}",
  "Description": "OAC for AWS Masterclass private S3 origin",
  "SigningProtocol": "sigv4",
  "SigningBehavior": "always",
  "OriginAccessControlOriginType": "s3"
}
EOF

OAC_ID="$(aws cloudfront create-origin-access-control \
  --origin-access-control-config file:///tmp/oac-config.json \
  --query 'OriginAccessControl.Id' \
  --output text)"

echo "OAC_ID=$OAC_ID"
```

---

## Step 6 — Get managed cache policy ID

```bash id="cache-policy-id"
CACHE_POLICY_ID="$(aws cloudfront list-cache-policies \
  --type managed \
  --query "CachePolicyList.Items[?CachePolicy.CachePolicyConfig.Name=='Managed-CachingOptimized'].CachePolicy.Id | [0]" \
  --output text)"

echo "CACHE_POLICY_ID=$CACHE_POLICY_ID"
```

---

## Step 7 — Create CloudFront distribution config

```bash id="dist-config"
cat > /tmp/cf-distribution-config.json <<EOF
{
  "CallerReference": "aws-masterclass-${TS}",
  "Comment": "AWS Masterclass private S3 with CloudFront OAC",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "${ORIGIN_ID}",
        "DomainName": "${BUCKET}.s3.ap-south-1.amazonaws.com",
        "OriginAccessControlId": "${OAC_ID}",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "${ORIGIN_ID}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "CachePolicyId": "${CACHE_POLICY_ID}"
  },
  "PriceClass": "PriceClass_100",
  "Restrictions": {
    "GeoRestriction": {
      "RestrictionType": "none",
      "Quantity": 0
    }
  },
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true
  }
}
EOF
```

---

## Step 8 — Create CloudFront distribution

```bash id="create-dist"
CREATE_OUTPUT="$(aws cloudfront create-distribution \
  --distribution-config file:///tmp/cf-distribution-config.json)"

CF_ID="$(echo "$CREATE_OUTPUT" | jq -r '.Distribution.Id')"
CF_DOMAIN="$(echo "$CREATE_OUTPUT" | jq -r '.Distribution.DomainName')"

echo "CF_ID=$CF_ID"
echo "CF_DOMAIN=$CF_DOMAIN"
```

---

## Step 9 — Add S3 bucket policy for CloudFront OAC

```bash id="bucket-policy"
cat > /tmp/s3-oac-bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${CF_ID}"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket "$BUCKET" \
  --policy file:///tmp/s3-oac-bucket-policy.json
```

---

## Step 10 — Wait for CloudFront deployment

```bash id="wait-deployed"
aws cloudfront wait distribution-deployed \
  --id "$CF_ID"
```

Check:

```bash id="get-dist"
aws cloudfront get-distribution \
  --id "$CF_ID" \
  --query 'Distribution.{Id:Id,Status:Status,DomainName:DomainName,Enabled:DistributionConfig.Enabled}' \
  --output table
```

---

## Step 11 — Test CloudFront

```bash id="test-cf"
curl -I "https://${CF_DOMAIN}/"
curl "https://${CF_DOMAIN}/"

curl -I "https://${CF_DOMAIN}/health.json"
curl "https://${CF_DOMAIN}/health.json"
```

Expected:

```text id="expected"
HTTP 200
HTML page for /
JSON health response for /health.json
```

Direct S3 should still be blocked:

```bash id="test-direct-s3"
curl -I "https://${BUCKET}.s3.ap-south-1.amazonaws.com/index.html" || true
```

Expected:

```text id="expected-s3"
403 Forbidden
```

This proves:

```text id="proof"
Users can access through CloudFront.
Users cannot bypass CloudFront and read S3 directly.
```

---

# 24. Test invalidation

Update `index.html`:

```bash id="update-index"
cat > /tmp/aws-masterclass-cloudfront/index.html <<'EOF'
<!doctype html>
<html>
  <head>
    <title>AWS Masterclass CloudFront OAC</title>
  </head>
  <body>
    <h1>Updated content from private S3 through CloudFront</h1>
    <p>This page was updated, then CloudFront cache was invalidated.</p>
  </body>
</html>
EOF

aws s3 cp /tmp/aws-masterclass-cloudfront/index.html "s3://$BUCKET/index.html" \
  --content-type "text/html"
```

Create invalidation:

```bash id="create-invalidation"
aws cloudfront create-invalidation \
  --distribution-id "$CF_ID" \
  --paths "/index.html" "/"
```

Test again after a short wait:

```bash id="test-updated"
curl "https://${CF_DOMAIN}/"
```

---

# 25. Troubleshooting Lab 10A

## Problem: CloudFront returns 403

Check distribution origin:

```bash id="check-origin"
aws cloudfront get-distribution \
  --id "$CF_ID" \
  --query 'Distribution.DistributionConfig.Origins.Items'
```

Check bucket policy:

```bash id="check-bucket-policy"
aws s3api get-bucket-policy \
  --bucket "$BUCKET" \
  --query Policy \
  --output text | jq .
```

Check object exists:

```bash id="check-object"
aws s3api head-object \
  --bucket "$BUCKET" \
  --key index.html
```

Common fixes:

```text id="fix-403"
Bucket policy SourceArn must match distribution ID.
OAC must be attached to origin.
Origin must use S3 REST endpoint, not website endpoint.
Object key must exist.
DefaultRootObject should be index.html.
Distribution must be deployed.
```

---

## Problem: CloudFront still shows old content

Fix:

```bash id="fix-old-content"
aws cloudfront create-invalidation \
  --distribution-id "$CF_ID" \
  --paths "/index.html" "/"
```

Better long-term:

```text id="better-cache"
Use versioned asset filenames.
Keep index.html short TTL.
Cache app.hash.js and style.hash.css for long TTL.
```

---

## Problem: direct S3 works publicly

That is bad for this lab.

Check:

```bash id="check-public"
aws s3api get-public-access-block \
  --bucket "$BUCKET"

aws s3api get-bucket-policy \
  --bucket "$BUCKET" \
  --query Policy \
  --output text | jq .
```

Fix:

```text id="fix-public"
Enable Block Public Access.
Remove public bucket policy.
Use OAC-only bucket policy.
```

---

# 26. Cleanup Lab 10A

CloudFront cleanup takes time.

## Step 1 — Disable distribution

```bash id="disable-dist"
aws cloudfront get-distribution-config \
  --id "$CF_ID" \
  --query 'DistributionConfig' \
  --output json > /tmp/cf-current-config.json

ETAG="$(aws cloudfront get-distribution-config \
  --id "$CF_ID" \
  --query 'ETag' \
  --output text)"

jq '.Enabled=false' /tmp/cf-current-config.json > /tmp/cf-disabled-config.json

aws cloudfront update-distribution \
  --id "$CF_ID" \
  --if-match "$ETAG" \
  --distribution-config file:///tmp/cf-disabled-config.json
```

Wait:

```bash id="wait-disabled"
aws cloudfront wait distribution-deployed \
  --id "$CF_ID"
```

---

## Step 2 — Delete distribution

```bash id="delete-dist"
ETAG="$(aws cloudfront get-distribution-config \
  --id "$CF_ID" \
  --query 'ETag' \
  --output text)"

aws cloudfront delete-distribution \
  --id "$CF_ID" \
  --if-match "$ETAG"
```

---

## Step 3 — Delete OAC

```bash id="delete-oac"
OAC_ETAG="$(aws cloudfront get-origin-access-control \
  --id "$OAC_ID" \
  --query 'ETag' \
  --output text)"

aws cloudfront delete-origin-access-control \
  --id "$OAC_ID" \
  --if-match "$OAC_ETAG"
```

If deletion fails, wait a few minutes and retry.

---

## Step 4 — Delete S3 objects and bucket

```bash id="delete-s3"
aws s3 rm "s3://$BUCKET" --recursive

aws s3api delete-bucket-policy \
  --bucket "$BUCKET" || true

aws s3api delete-bucket \
  --bucket "$BUCKET" \
  --region ap-south-1
```

Verify:

```bash id="verify-cleanup"
aws s3api list-buckets \
  --query "Buckets[?Name=='$BUCKET']"

aws cloudfront list-distributions \
  --query "DistributionList.Items[?Id=='$CF_ID']"
```

---

# 27. Production CloudFront design checklist

Before creating CloudFront in production, answer:

```text id="checklist"
1. What domain will users use?
2. Is ACM certificate in us-east-1?
3. Does certificate cover exact domain?
4. What are the origins?
5. Is S3 private with OAC?
6. Is ALB origin protected from bypass?
7. What paths should go to S3?
8. What paths should go to ALB/API?
9. What should be cached?
10. What must never be cached?
11. Which headers/query strings/cookies affect response?
12. What cache policy is needed?
13. What origin request policy is needed?
14. What response headers policy is needed?
15. Should WAF be attached?
16. Are logs enabled?
17. What is invalidation strategy?
18. Are static assets versioned?
19. What custom error pages are needed?
20. What is cleanup/rollback plan?
```

---

# 28. Common production patterns

## Pattern 1 — Static site

```text id="static-site"
Route 53
  ↓
CloudFront
  ↓ OAC
Private S3
```

Use for:

```text id="static-use"
portfolio
React build
documentation
landing pages
static assets
```

---

## Pattern 2 — Full-stack app

```text id="fullstack"
Route 53
  ↓
CloudFront
  ├── /assets/* → private S3
  └── /api/*    → ALB
                    ↓
                  ECS/EC2/EKS
```

Use for:

```text id="fullstack-use"
real SaaS app
frontend + backend
global users
single public domain
```

---

## Pattern 3 — API acceleration

```text id="api"
Route 53
  ↓
CloudFront
  ↓
API Gateway or ALB
```

Use for:

```text id="api-use"
global API clients
WAF/rate limiting at edge
TLS/custom domain centralization
some cacheable GET APIs
```

---

## Pattern 4 — Private paid content

```text id="private-paid"
Authenticated app
  ↓
generates signed URL/cookie
  ↓
CloudFront
  ↓
private S3
```

Use for:

```text id="private-use"
paid videos
private course files
customer invoices
download portal
```

---

# 29. CloudFront vs Route 53 vs ALB

Never confuse:

| Service    | Main job                                  |
| ---------- | ----------------------------------------- |
| Route 53   | DNS: maps domain to destination           |
| CloudFront | CDN/global edge/cache/security front door |
| ALB        | Regional load balancer for app targets    |
| S3         | Object storage origin                     |
| ACM        | TLS certificate management                |
| WAF        | HTTP request filtering/protection         |

Flow:

```text id="service-flow"
Route 53:
  where should app.example.com go?

CloudFront:
  should this response come from cache or origin?

ALB:
  which healthy backend target should handle request?

EC2/ECS:
  run the application

S3:
  store static files

WAF:
  should this request be blocked?
```

---

# 30. Certification angle

## CLF-C02

Know:

```text id="clf"
CloudFront is a CDN.
CloudFront uses edge locations.
CloudFront improves latency and reduces origin load.
CloudFront can serve S3 and application origins.
ACM provides TLS certificates.
WAF can protect web apps.
```

## SAA-C03

Know deeply:

```text id="saa"
S3 origin vs custom origin
OAC for private S3
cache behavior routing
cache policy vs origin request policy
response headers policy
CloudFront + Route 53 Alias
ACM us-east-1 for CloudFront
HTTP to HTTPS redirect
custom error responses
signed URLs/signed cookies
CloudFront with ALB origin
CloudFront 403/502/504 troubleshooting
```

## DOP-C02

Know operationally:

```text id="dop"
cache invalidation in deployment pipeline
versioned static assets
CloudFront logs
WAF managed rules
WAF rate limiting
origin health checks
blue/green with CloudFront behaviors
cache policy rollback
CloudFront distribution deployment delays
incident runbooks for 403/502
```

---

# 31. Interview answer

Memorize this:

```text id="interview-answer"
Amazon CloudFront is AWS’s CDN and global edge service. It sits in front of origins such as S3, ALB, API Gateway, or EC2 and serves cached content from edge locations close to users. A CloudFront distribution contains origins, cache behaviors, cache policies, origin request policies, response headers policies, TLS certificates, alternate domain names, logging, and optional WAF protection.

For static content, I prefer a private S3 bucket with CloudFront Origin Access Control. The S3 bucket blocks public access, and the bucket policy allows only the specific CloudFront distribution to read objects. For dynamic applications, I use CloudFront in front of an ALB and route paths such as /api/* to the ALB while routing /assets/* to S3.

Cache policy controls the cache key and TTL behavior. Origin request policy controls which headers, cookies, and query strings CloudFront forwards to the origin. Response headers policy adds security or CORS headers. I cache versioned static assets aggressively, avoid caching personalized API responses unless carefully designed, and use invalidations mainly for urgent changes or index.html.

For production, I attach a us-east-1 ACM certificate for CloudFront custom domains, redirect viewers to HTTPS, use WAF for public apps, enable logs, and troubleshoot errors layer by layer. For 403 errors, I check OAC, bucket policy, object path, WAF, and signed URL/cookie settings. For 502 or 504 errors, I check the origin protocol, ALB health, TLS certificate, security groups, and application availability.
```

---

# 32. Quick quiz

```text id="quiz"
1. What is CloudFront?
2. What is a CDN?
3. What is a CloudFront distribution?
4. What is an origin?
5. What is a cache behavior?
6. What is cache hit?
7. What is cache miss?
8. What is cache key?
9. What does cache policy control?
10. What does origin request policy control?
11. What does response headers policy control?
12. What is OAC?
13. Why use OAC with S3?
14. What is the difference between S3 REST endpoint and S3 website endpoint?
15. Which ACM region is required for CloudFront custom domain?
16. What is invalidation?
17. Why are versioned file names better for frequent updates?
18. What are signed URLs used for?
19. What are signed cookies used for?
20. What are common causes of CloudFront 403?
```

Answers:

```text id="answers"
1. AWS CDN/global edge service.
2. Content Delivery Network.
3. Global CloudFront configuration.
4. Backend source such as S3 or ALB.
5. Path-based rule with origin/cache/request settings.
6. Response served from CloudFront cache.
7. CloudFront fetches from origin.
8. Values used to identify a unique cached response.
9. TTL and what headers/cookies/query strings affect cache key.
10. What headers/cookies/query strings CloudFront forwards to origin.
11. Headers CloudFront adds/removes/overrides in responses.
12. Origin Access Control.
13. To keep S3 private and allow only CloudFront access.
14. REST endpoint supports private OAC pattern; website endpoint is HTTP website hosting style.
15. us-east-1.
16. Removing cached object before TTL expires.
17. They avoid waiting for expiry and reduce invalidation dependency.
18. Temporary access to specific private content.
19. Access to multiple private files without changing URLs.
20. Wrong OAC, bucket policy, object path, WAF, signed URL/cookie, or default root object.
```

---

# Next Lesson

```text id="next"
AWS Lesson 11 — Containers on AWS:
ECR, ECS, Fargate, EKS, container networking, task definitions, services, load balancing, autoscaling, and choosing EC2 vs ECS vs EKS vs Lambda
```

[1]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html?utm_source=chatgpt.com "Use various origins with CloudFront distributions - Amazon CloudFront"
[2]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/understanding-response-headers-policies.html?utm_source=chatgpt.com "Understand response headers policies - Amazon CloudFront"
[3]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cache-key-understand-cache-policy.html?utm_source=chatgpt.com "Understand cache policies - Amazon CloudFront"
[4]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/controlling-origin-requests.html?utm_source=chatgpt.com "Control origin requests with a policy - Amazon CloudFront"
[5]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/modifying-response-headers.html?utm_source=chatgpt.com "Add or remove HTTP headers in CloudFront responses with a policy - Amazon CloudFront"
[6]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/RequestAndResponseBehaviorS3Origin.html?utm_source=chatgpt.com "Request and response behavior for Amazon S3 origins - Amazon CloudFront"
[7]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html?utm_source=chatgpt.com "Restrict access to an Amazon S3 origin - Amazon CloudFront"
[8]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html?utm_source=chatgpt.com "Invalidate files to remove content - Amazon CloudFront"
[9]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-urls.html?utm_source=chatgpt.com "Use signed URLs - Amazon CloudFront"
[10]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-cookies.html?utm_source=chatgpt.com "Use signed cookies - Amazon CloudFront"
[11]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html?utm_source=chatgpt.com "Configuring protection in AWS WAF - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[12]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl-associating-aws-resource.html?utm_source=chatgpt.com "Associating or disassociating protection with an AWS resource - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[13]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/standard-logging.html?utm_source=chatgpt.com "Configure standard logging (v2) - Amazon CloudFront"
