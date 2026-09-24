# AWS Masterclass — Phase 3

# Lesson 28: Amazon CloudFront Production Architecture

## 1. Lesson objective

In this lesson, you will learn how to design, secure, deploy and troubleshoot a production content-delivery architecture using Amazon CloudFront.

We will cover:

* How a CDN works.
* Edge locations, cache hits and cache misses.
* Static and dynamic content delivery.
* S3, ALB, EC2, API Gateway and other origins.
* CloudFront distributions and cache behaviors.
* Cache keys, cache policies and origin request policies.
* TTLs and `Cache-Control`.
* Origin Access Control for private S3 content.
* HTTPS, ACM certificates and custom domains.
* CloudFront Functions and Lambda@Edge.
* Signed URLs and signed cookies.
* AWS WAF and origin protection.
* Origin Shield and origin failover.
* Invalidations and versioned assets.
* Logging, metrics and production troubleshooting.
* Terraform implementation.

---

# 2. What is Amazon CloudFront?

Amazon CloudFront is AWS’s content delivery network, or CDN.

It delivers static and dynamic web content through a worldwide network of edge locations. When a viewer requests content, CloudFront directs the request to an edge location that can provide low-latency delivery. ([AWS Documentation][1])

CloudFront can deliver:

```text
HTML
CSS
JavaScript
Images
Fonts
Videos
API responses
Software packages
Downloads
Dynamic websites
WebSocket traffic
```

CloudFront can sit in front of both static storage and application infrastructure:

```text
Viewer
   |
   v
CloudFront
   |
   ├── S3
   ├── Application Load Balancer
   ├── EC2
   ├── API Gateway
   ├── Lambda function URL
   └── External HTTP origin
```

CloudFront supports multiple AWS and custom origin types, including S3, load balancers, EC2-hosted applications, API Gateway and external HTTP servers. ([AWS Documentation][2])

---

# 3. The CloudFront mental model

Use this simple definition:

```text
CloudFront is a globally distributed reverse proxy
with caching, security and edge-compute capabilities.
```

CloudFront performs three major jobs:

```text
1. Accept viewer requests close to the viewer.
2. Serve cached content when possible.
3. Forward uncached or uncacheable requests to an origin.
```

## Never-forget analogy

```text
Origin:
The central warehouse.

CloudFront edge location:
A local distribution centre.

Cached object:
Inventory already stored near the customer.

Cache miss:
The local centre must request the item from the warehouse.

Cache hit:
The local centre already has the item.
```

CloudFront reduces latency and origin load by serving eligible cached objects from its edge network instead of retrieving them from the origin for every viewer request. ([AWS Documentation][1])

---

# 4. Production architecture

A common production architecture is:

```text
                             Users
                  India / Europe / America
                               |
                               v
                         Route 53 DNS
                               |
                               v
                        Amazon CloudFront
                        /       |       \
                Edge cache   AWS WAF   Edge code
                               |
                  ┌────────────┴────────────┐
                  |                         |
             Static behavior          API behavior
                /assets/*                 /api/*
                  |                         |
                  v                         v
            Private S3 bucket        Public/internal ALB
               through OAC                  |
                                            v
                                  EC2 Auto Scaling Group
                                            |
                                       RDS / Cache
```

Example request routing:

```text
/assets/app.a82f91.js
    → S3 origin
    → Cached for one year

/api/products
    → ALB origin
    → No caching or short caching

/index.html
    → S3 origin
    → Short TTL

/private/course.mp4
    → S3 origin
    → Signed URL required
```

A single distribution can contain multiple cache behaviors, with each behavior forwarding matching URL paths to a selected origin and applying its own caching, security and request-forwarding configuration. ([AWS Documentation][3])

---

# 5. Viewer, edge and origin terminology

## Viewer

The user, browser, mobile application or API client making a request.

```text
Viewer request:
Browser → CloudFront
```

## Edge location

The CloudFront location that receives the viewer request.

## Origin

The authoritative backend from which CloudFront retrieves content.

```text
Origin request:
CloudFront → S3 or ALB
```

## Viewer response

```text
CloudFront → Browser
```

## Origin response

```text
S3 or ALB → CloudFront
```

This distinction becomes extremely important when working with:

* HTTPS policies.
* Edge functions.
* Request headers.
* Cache policies.
* Response-header policies.
* Error handling.

---

# 6. The complete request flow

Suppose a user requests:

```text
https://www.example.com/assets/logo.png
```

The flow is:

```text
1. Browser resolves www.example.com through DNS.
2. Route 53 returns the CloudFront distribution.
3. Browser establishes HTTPS with CloudFront.
4. CloudFront determines the matching cache behavior.
5. CloudFront calculates the cache key.
6. CloudFront checks its edge cache.
7. If found, CloudFront returns the cached object.
8. If not found, CloudFront sends an origin request.
9. The origin returns the object.
10. CloudFront may cache it.
11. CloudFront returns it to the viewer.
```

CloudFront chooses whether an object can be served from cache by using the request’s cache key and the configured cache policy. Cache-key components can include URL path, selected query strings, selected headers and selected cookies. ([AWS Documentation][4])

---

# 7. Cache hit and cache miss

## Cache hit

The requested object exists in the edge cache and remains valid.

```text
Viewer
   |
   v
CloudFront edge cache
   |
   v
Response returned

Origin is not contacted
```

Advantages:

* Lower latency.
* Reduced origin requests.
* Reduced origin compute load.
* Reduced database load.
* Better handling of traffic spikes.

## Cache miss

CloudFront does not have a valid cached version.

```text
Viewer
   |
   v
CloudFront
   |
   v
Origin
   |
   v
CloudFront caches response
   |
   v
Viewer
```

## Cache-hit ratio

```text
Cache-hit ratio =
Requests served from cache / Cacheable requests
```

Example:

```text
Cacheable requests: 1,000,000
Cache hits:           900,000
Cache misses:         100,000

Cache-hit ratio = 90%
```

CloudFront defines cache-hit ratio as the proportion of requests served directly from cache compared with the applicable requests received by the distribution. ([AWS Documentation][5])

---

# 8. Static versus dynamic content

## Static content

Static content generally returns the same object to many users.

Examples:

```text
CSS
JavaScript
Images
Fonts
Videos
Downloadable files
Versioned application bundles
```

Static content is highly cacheable.

Example:

```http
Cache-Control: public, max-age=31536000, immutable
```

## Dynamic content

Dynamic content can vary by:

* User.
* Authentication.
* Cookie.
* Query parameter.
* Language.
* Device.
* Location.
* Database state.

Examples:

```text
Shopping cart
Account balance
Order history
Admin dashboard
Personal recommendations
Authenticated API
```

CloudFront can accelerate dynamic content even when caching is disabled because viewers connect to a nearby edge and CloudFront uses AWS’s network path toward the origin. However, the greatest origin-load reduction occurs when responses can safely be cached. ([Amazon Web Services, Inc.][6])

---

# 9. What is a CloudFront distribution?

A distribution is the primary CloudFront configuration resource.

It defines:

```text
Origins
Origin groups
Default cache behavior
Ordered cache behaviors
Custom domain names
TLS certificate
Logging
Geographic restrictions
AWS WAF association
HTTP versions
IPv6 support
Price class or plan configuration
```

When created, CloudFront provides a domain similar to:

```text
d111111abcdef8.cloudfront.net
```

You can later associate custom names such as:

```text
www.example.com
cdn.example.com
api.example.com
```

CloudFront alternate domain names must be configured on the distribution and covered by the attached certificate. ([AWS Documentation][7])

---

# 10. Origins

An origin is a source from which CloudFront retrieves content.

## S3 bucket origin

Suitable for:

```text
Static websites
Images
JavaScript
CSS
Videos
Downloads
Documentation
Single-page applications
```

Recommended architecture:

```text
Viewer
   |
   v
CloudFront
   |
   | Authenticated request through OAC
   v
Private S3 bucket
```

## ALB origin

Suitable for:

```text
Dynamic web applications
REST APIs
Container applications
EC2 Auto Scaling workloads
WebSocket applications
```

## EC2 custom origin

CloudFront can connect directly to a publicly reachable EC2 endpoint, but an ALB is usually preferable for production because it provides health checks, TLS termination and multi-instance traffic distribution.

## API Gateway origin

Useful for APIs exposed through API Gateway.

## External custom origin

CloudFront can use any suitably reachable HTTP or HTTPS server as a custom origin.

CloudFront officially supports S3 and a range of custom or AWS-managed HTTP origins. ([AWS Documentation][2])

---

# 11. S3 REST endpoint versus S3 website endpoint

This distinction is extremely important.

## S3 REST bucket endpoint

Conceptually:

```text
my-bucket.s3.ap-south-1.amazonaws.com
```

Advantages:

* Supports Origin Access Control.
* Bucket can remain private.
* Supports authenticated CloudFront-to-S3 requests.
* Supports HTTPS from CloudFront to S3.
* Recommended for secure static-content delivery.

## S3 website endpoint

Conceptually:

```text
my-bucket.s3-website.ap-south-1.amazonaws.com
```

It behaves like a website server and supports S3 website-routing features.

However:

* It is configured as a custom origin.
* OAC and OAI cannot be used.
* The website endpoint does not support HTTPS communication from CloudFront to the origin.
* Content generally needs to be publicly reachable at the website endpoint.

AWS explicitly states that S3 website endpoints must be configured as custom origins and cannot use OAC or OAI. ([AWS Documentation][8])

## Production recommendation

For most secure static applications:

```text
Use:
Private S3 bucket REST endpoint + OAC

Avoid:
Public S3 website endpoint
```

---

# 12. Origin Access Control

Origin Access Control, or OAC, lets CloudFront authenticate requests sent to supported origins such as S3.

Architecture:

```text
Public internet
      |
      v
CloudFront
      |
      | AWS-signed origin request
      v
Private S3 bucket
```

The S3 bucket policy permits access only through the intended CloudFront distribution.

AWS recommends OAC instead of the older Origin Access Identity because OAC supports all S3 Regions, SSE-KMS, and dynamic S3 requests such as `PUT` and `DELETE` when configured appropriately. ([AWS Documentation][8])

## OAC versus OAI

| Feature                | OAC       | OAI                 |
| ---------------------- | --------- | ------------------- |
| Current recommendation | Yes       | Legacy              |
| SSE-KMS support        | Yes       | Limited             |
| Newer Regions          | Yes       | Limited             |
| Dynamic S3 methods     | Supported | Not fully supported |
| SigV4 request signing  | Yes       | Older access model  |

---

# 13. OAC signing behavior

OAC supports different signing modes.

The recommended normal S3 configuration is:

```text
Signing behavior:
Always sign origin requests
```

Flow:

```text
Viewer requests object
        ↓
CloudFront validates viewer request
        ↓
CloudFront creates signed S3 request
        ↓
S3 verifies CloudFront permission
        ↓
S3 returns object
```

This enables the bucket to remain private.

A mode that does not sign requests requires the S3 origin to be publicly accessible, which defeats the normal private-origin design. ([AWS Documentation][8])

---

# 14. S3 bucket policy for OAC

A typical policy allows the CloudFront service principal to read objects only when the request originates from your distribution.

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
      "Resource": "arn:aws:s3:::production-static-site/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/E123EXAMPLE"
        }
      }
    }
  ]
}
```

This condition prevents another distribution from using the same permission.

The bucket should also use:

```text
S3 Block Public Access: enabled
Object Ownership: Bucket owner enforced
```

OAC’s standard S3 configuration expects the bucket owner to control objects, with `Bucket owner enforced` being the default for new buckets. ([AWS Documentation][8])

---

# 15. SSE-KMS with OAC

If S3 objects are encrypted with a customer-managed KMS key:

```text
CloudFront
   |
   v
S3 object encrypted with KMS
```

You need permissions at two levels:

```text
1. S3 bucket policy
2. KMS key policy
```

The KMS key policy must permit the required CloudFront distribution access through the service principal and appropriate source conditions.

Without the correct KMS policy:

```text
CloudFront requests object
        ↓
S3 locates object
        ↓
KMS decrypt denied
        ↓
403 response
```

OAC supports S3 objects encrypted with SSE-KMS, unlike the legacy OAI model’s restricted support. ([AWS Documentation][8])

---

# 16. Custom origin protection

For an ALB origin, the ALB is normally internet-facing because CloudFront needs to reach it unless you use an architecture specifically supporting private origin connectivity.

A common protection method is:

```text
CloudFront adds secret origin header
        ↓
ALB listener rule checks header
        ↓
Only matching requests reach application
```

Example header:

```text
X-Origin-Verify: long-random-secret
```

ALB listener logic:

```text
If header matches:
    Forward to target group

Otherwise:
    Return 403
```

Additional controls can include:

* AWS WAF at CloudFront.
* Restrictive origin security rules.
* Rotated custom headers.
* Private-origin connectivity where supported.
* Authentication at the application.

Do not treat a custom header as the only security boundary for a sensitive application.

---

# 17. Default and ordered cache behaviors

Every distribution has:

```text
One default cache behavior
Zero or more ordered cache behaviors
```

## Default behavior

Matches requests that do not match a more specific behavior.

```text
Path pattern:
Default (*)
```

## Ordered behavior

Matches a particular path.

Example:

```text
/assets/*
/api/*
/videos/*
/private/*
```

CloudFront evaluates ordered path patterns and uses the matching behavior; otherwise it applies the default behavior. ([AWS Documentation][3])

## Example design

| Path             | Origin | Caching     |
| ---------------- | ------ | ----------- |
| `/assets/*`      | S3     | One year    |
| `/images/*`      | S3     | One day     |
| `/api/public/*`  | ALB    | 30 seconds  |
| `/api/private/*` | ALB    | Disabled    |
| `/downloads/*`   | S3     | Signed URLs |
| Default          | S3     | Short TTL   |

---

# 18. Path-pattern warning

Suppose your behaviors are:

```text
/api/*
/*
```

A request to:

```text
/api/orders
```

uses the API behavior.

A request to:

```text
/api
```

might not match `/api/*` as you expect because it lacks the trailing slash and following path component.

Consider including explicit patterns or normalizing requests.

Also remember that CloudFront selects a behavior based on the request path before origin processing. Application rewrites at the origin do not cause CloudFront to repeat cache-behavior selection.

---

# 19. Viewer protocol policy

The viewer protocol policy controls how users connect to CloudFront.

Options include:

```text
Allow HTTP and HTTPS
Redirect HTTP to HTTPS
HTTPS only
```

## Recommended public website setting

```text
Redirect HTTP to HTTPS
```

Flow:

```text
http://www.example.com
        ↓
301 or 302 redirect
        ↓
https://www.example.com
```

## Sensitive API setting

```text
HTTPS only
```

A request using HTTP is rejected instead of redirected.

For modern production systems, avoid transmitting authentication tokens, sessions or private information over plaintext HTTP.

---

# 20. Origin protocol policy

The origin protocol policy controls CloudFront-to-custom-origin communication.

Options generally include:

```text
HTTP only
HTTPS only
Match viewer
```

Recommended for ALB origins:

```text
HTTPS only
Minimum origin TLS: TLS 1.2
```

Architecture:

```text
Viewer ──HTTPS──> CloudFront ──HTTPS──> ALB
```

CloudFront’s current preconfigured load-balancer origin settings use HTTPS-only and TLS 1.2 as the minimum origin protocol. ([AWS Documentation][9])

---

# 21. Allowed HTTP methods

CloudFront behaviors can allow different method sets.

Common choices:

```text
GET, HEAD

GET, HEAD, OPTIONS

GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
```

## Static S3 delivery

Usually:

```text
GET
HEAD
OPTIONS when CORS is needed
```

## API origin

Often:

```text
GET
HEAD
OPTIONS
PUT
POST
PATCH
DELETE
```

Only methods configured as cached methods are cached. Dynamic write methods should not be treated as ordinary cached object retrieval.

---

# 22. Automatic compression

CloudFront can compress eligible objects before delivering them to viewers that support compression.

Common content:

```text
HTML
CSS
JavaScript
JSON
XML
SVG
Text
```

Common encodings:

```text
gzip
Brotli
```

Enable:

```text
Compress objects automatically: true
```

A correct cache policy accounts for accepted compression encodings so compressed and uncompressed variants can be handled correctly. ([AWS Documentation][4])

Do not precompress every object without verifying:

* Correct `Content-Encoding`.
* Correct content type.
* Cache-key behavior.
* Origin compatibility.
* Browser compatibility.

---

# 23. The cache key

The cache key tells CloudFront whether two viewer requests should use the same cached object.

At minimum, the path is part of the cache key.

```text
/images/logo.png
```

You may also include:

```text
Selected query strings
Selected headers
Selected cookies
Accepted compression format
```

Example:

```text
Path:
/products

Query string:
category=laptops

Header:
Accept-Language: en

Cookie:
currency=USD
```

CloudFront may treat different combinations as separate cached versions.

Cache policies control which query strings, headers and cookies are included in the cache key. ([AWS Documentation][4])

---

# 24. Cache-key explosion

Suppose CloudFront includes every header, cookie and query parameter.

Requests:

```text
/products?category=laptop&utm_source=google
/products?category=laptop&utm_source=email
/products?category=laptop&utm_source=linkedin
```

If `utm_source` is included in the cache key, three separate objects may be cached even though the content is identical.

Cookies can make the problem much worse:

```text
session=abc
session=def
session=ghi
```

Now every user may create a unique cache entry.

This leads to:

```text
Low cache-hit ratio
High origin traffic
More edge storage variants
Higher latency
More application load
```

AWS recommends forwarding or caching based only on headers actually needed to vary the response because unnecessary headers reduce cache efficiency. ([AWS Documentation][10])

## Never-forget rule

```text
Include a value in the cache key only when it changes the response.
```

---

# 25. Cache policy

A cache policy controls:

```text
Minimum TTL
Default TTL
Maximum TTL
Headers in cache key
Cookies in cache key
Query strings in cache key
Compression-key settings
```

Example design for static assets:

```text
Minimum TTL: 1 day
Default TTL: 30 days
Maximum TTL: 1 year

Headers: none
Cookies: none
Query strings: none
Compression: gzip and Brotli
```

Example design for language-specific public content:

```text
Headers:
Accept-Language

Cookies:
None

Query strings:
Only contentVersion
```

CloudFront provides managed cache policies and also supports custom cache policies when your application requires exact behavior. ([AWS Documentation][4])

---

# 26. Origin request policy

An origin request policy determines which viewer values CloudFront forwards to the origin without necessarily including them in the cache key.

It can forward:

```text
Headers
Cookies
Query strings
```

Example:

```text
Origin needs:
X-Request-ID

But response does not vary by:
X-Request-ID
```

Then:

```text
Forward X-Request-ID using origin request policy.
Do not include it in cache policy.
```

This preserves cache reuse while allowing the origin to receive required information.

Values included in the cache key are automatically forwarded to the origin. An origin request policy lets you forward additional values without including them in the cache key. ([AWS Documentation][11])

---

# 27. Cache policy versus origin request policy

Use this distinction:

```text
Cache policy:
What makes one cached response different from another?

Origin request policy:
What additional request information does the origin need?
```

## Example

Request:

```http
GET /products?category=laptop&utm_campaign=sale
CloudFront-Viewer-Country: IN
Authorization: Bearer ...
```

Design:

```text
Cache key:
category

Forward to origin:
category
CloudFront-Viewer-Country

Do not cache:
Authorization-based private response
```

Be very careful with authorization. Caching authenticated responses under an insufficient cache key can expose one user’s content to another user.

---

# 28. Managed policies

AWS provides managed cache and origin-request policies for common scenarios.

Typical managed-policy patterns include:

```text
Caching optimized
Caching disabled
Forward selected CloudFront headers
Forward all viewer values except Host
```

Managed policies are useful starting points, but you must understand what they include.

For example:

```text
CachingDisabled
```

is appropriate for personalized APIs, while a caching-optimized policy is appropriate for static public assets.

Do not select “forward everything” without analysing cache-key and origin-host behavior.

---

# 29. The `Host` header problem

Suppose the viewer requests:

```text
api.example.com
```

CloudFront forwards:

```http
Host: api.example.com
```

But the origin is:

```text
my-api.execute-api.ap-south-1.amazonaws.com
```

The origin may expect its own hostname and reject the request.

For some API Gateway or Lambda URL integrations, an origin request policy that forwards all viewer headers except the viewer `Host` header is appropriate.

The exact policy depends on what hostname the origin expects.

---

# 30. Response headers policy

A response headers policy lets CloudFront add or manage response headers without modifying the origin.

Common uses:

* CORS.
* Security headers.
* Custom headers.
* Removing undesired headers.

Example security headers:

```http
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'self'
```

Example CORS headers:

```http
Access-Control-Allow-Origin: https://www.example.com
Access-Control-Allow-Methods: GET,HEAD,OPTIONS
Access-Control-Allow-Headers: Authorization,Content-Type
```

Do not deploy an overly restrictive Content Security Policy without testing the application’s scripts, fonts, images, API connections and analytics dependencies.

---

# 31. TTL hierarchy

CloudFront cache duration can be influenced by:

```text
Origin Cache-Control headers
Origin Expires header
Cache-policy minimum TTL
Cache-policy default TTL
Cache-policy maximum TTL
Error-cache minimum TTL
```

CloudFront supports origin directives including:

```http
Cache-Control: max-age=300
Cache-Control: s-maxage=3600
Cache-Control: no-cache
Cache-Control: no-store
Cache-Control: private
```

It also supports stale-content directives such as:

```http
stale-while-revalidate
stale-if-error
```

([AWS Documentation][12])

---

# 32. `max-age` versus `s-maxage`

## `max-age`

Controls how long browsers and shared caches may consider a response fresh, depending on the broader directive set.

```http
Cache-Control: public, max-age=300
```

## `s-maxage`

Targets shared caches such as CloudFront.

```http
Cache-Control: public, max-age=60, s-maxage=3600
```

Meaning:

```text
Browser:
Cache for 60 seconds

CloudFront:
Cache for 3600 seconds
```

This lets CloudFront reduce origin traffic while browsers check CloudFront more frequently.

---

# 33. Recommended TTL strategy for a frontend

A production single-page application might use:

## Hashed assets

```text
/assets/app.a82f91.js
/assets/styles.b72cc4.css
```

Header:

```http
Cache-Control: public, max-age=31536000, immutable
```

The file name changes whenever content changes.

## `index.html`

```http
Cache-Control: public, max-age=0, s-maxage=60, must-revalidate
```

The HTML is updated frequently and points to the new hashed assets.

## Images with versioned names

```http
Cache-Control: public, max-age=2592000
```

## API response

Depending on the business requirement:

```http
Cache-Control: no-store
```

or:

```http
Cache-Control: public, s-maxage=30
```

CloudFront can use object-specific cache headers while enforcing configured minimum and maximum bounds through its cache policy. ([AWS Documentation][12])

---

# 34. Minimum TTL warning

Suppose the origin returns:

```http
Cache-Control: no-store
```

But your cache policy has:

```text
Minimum TTL: 60 seconds
```

CloudFront can still cache the response according to that minimum policy requirement.

For sensitive or personalized paths:

```text
Minimum TTL: 0
Default TTL: 0
Maximum TTL: 0
```

or attach a managed caching-disabled policy.

Never configure a nonzero minimum TTL for responses that must never be shared between users unless you have explicitly proved the cache key isolates every required variation.

---

# 35. `stale-while-revalidate`

Example:

```http
Cache-Control:
public,
s-maxage=300,
stale-while-revalidate=60
```

Meaning:

```text
Fresh for:
300 seconds

For the next 60 seconds:
CloudFront may serve stale content while refreshing it
```

This reduces the latency spike that would otherwise occur when a popular object expires.

CloudFront supports the `stale-while-revalidate` directive for serving stale content during asynchronous refresh. ([AWS Documentation][12])

---

# 36. `stale-if-error`

Example:

```http
Cache-Control:
public,
s-maxage=300,
stale-if-error=86400
```

If the origin temporarily fails after the object becomes stale, CloudFront can serve the stale object during the specified error window.

This can improve resilience for content where slightly old data is preferable to an error page.

Suitable for:

```text
Public articles
Product descriptions
Documentation
Static configuration
Public images
```

Use caution for:

```text
Current account balance
Payment state
Inventory reservation
Security permissions
Real-time incident state
```

CloudFront supports `stale-if-error` in its cache-control handling. ([AWS Documentation][12])

---

# 37. Cache invalidation

An invalidation tells CloudFront to remove cached objects before their normal expiration.

Example:

```bash
aws cloudfront create-invalidation \
  --distribution-id E123EXAMPLE \
  --paths "/index.html" "/config.json"
```

Invalidate all paths:

```bash
aws cloudfront create-invalidation \
  --distribution-id E123EXAMPLE \
  --paths "/*"
```

CloudFront supports path invalidations and, in supported configurations, semantic invalidation using cache tags. ([AWS Documentation][13])

## Important wildcard rule

When using the CLI:

```bash
--paths "/*"
```

Quote the wildcard so that the local shell does not expand it into local filenames. ([AWS Documentation][14])

---

# 38. Invalidation versus versioning

Suppose you deploy:

```text
/app.js
```

Every release replaces the same object.

You may need to invalidate it after every deployment.

Better:

```text
/app.8fa21c.js
/app.b13e72.js
```

The HTML references the new version.

Advantages:

* No stale asset conflict.
* Old and new application versions can coexist.
* Better rollback.
* Long TTLs become safe.
* Less invalidation work.

AWS recommends choosing between invalidation and versioned filenames according to how you manage object changes. ([AWS Documentation][13])

## Recommended deployment strategy

```text
Version static assets.
Invalidate only short-lived entry files.
```

Example:

```text
Upload hashed files
Upload index.html last
Invalidate /index.html
```

---

# 39. Custom domain and HTTPS

To use:

```text
https://cdn.yourdatascientist.tech
```

you need:

```text
1. Domain in the CloudFront alternate domain names.
2. Certificate covering that domain.
3. Route 53 alias pointing to CloudFront.
4. HTTPS viewer policy.
```

For a CloudFront viewer certificate in ACM, the certificate must be requested or imported in:

```text
us-east-1
US East (N. Virginia)
```

CloudFront checks that each alternate domain name is covered by the certificate’s subject alternative names. ([AWS Documentation][15])

---

# 40. Wildcard certificate behavior

A certificate for:

```text
*.yourdatascientist.tech
```

covers one subdomain level:

```text
cdn.yourdatascientist.tech
api.yourdatascientist.tech
www.yourdatascientist.tech
```

It does not normally cover:

```text
yourdatascientist.tech
```

and does not cover deeper names such as:

```text
api.dev.yourdatascientist.tech
```

A common certificate request includes:

```text
yourdatascientist.tech
*.yourdatascientist.tech
```

All CloudFront alternate domain names, including wildcard names, must be covered by the certificate’s SAN entries. ([AWS Documentation][16])

---

# 41. Route 53 alias to CloudFront

Terraform:

```hcl
resource "aws_route53_record" "cdn_ipv4" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "cdn.yourdatascientist.tech"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn_ipv6" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "cdn.yourdatascientist.tech"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
```

The CloudFront alternate domain name must be configured before the DNS alias sends production traffic to it.

---

# 42. Signed URLs

A signed URL grants time-limited or policy-limited access to an individual CloudFront resource.

Example:

```text
https://cdn.example.com/private/course.mp4
?Expires=...
&Signature=...
&Key-Pair-Id=...
```

Flow:

```text
1. User authenticates with application.
2. Application checks entitlement.
3. Application creates signed URL.
4. User requests file using signed URL.
5. CloudFront validates signature and policy.
6. CloudFront returns content if permitted.
```

CloudFront signed URLs support RSA 2048 and ECDSA 256 signatures. ([AWS Documentation][17])

Use signed URLs when:

* Access is for one file.
* The client does not support cookies.
* You want a unique expiration per download.
* You need one-time-style distribution workflows.

---

# 43. Signed cookies

Signed cookies grant access to multiple restricted objects without changing each URL.

Typical use case:

```text
/private-course/*
/subscriber/*
/hls-video/*
```

Flow:

```text
Application authenticates user
        ↓
Application sets CloudFront signed cookies
        ↓
Browser requests many restricted files
        ↓
CloudFront validates cookies
```

Use signed cookies when:

* A user needs multiple protected files.
* HLS video requires many segments.
* You do not want query parameters added to every URL.
* An authenticated website section contains many objects.

AWS recommends signed URLs for individual resources and signed cookies for access to groups of resources or when URLs should remain unchanged. ([AWS Documentation][18])

---

# 44. Trusted key groups

The normal private-content design uses:

```text
Public key:
Stored in CloudFront key group

Private key:
Stored securely by signing application
```

The application signs the policy using the private key.

CloudFront validates the signature using the public key.

```text
Signing service
   |
   | private key
   v
Signed URL or cookie
   |
   v
CloudFront
   |
   | public key from trusted key group
   v
Allow or deny
```

Never store the private signing key:

* In a public repository.
* In frontend JavaScript.
* In the S3 website.
* In a container image.
* In CloudFront code.
* In unsecured CI logs.

CloudFront requires valid signed URLs or cookies when a behavior is configured to trust the associated signer or key group. ([AWS Documentation][19])

---

# 45. Canned versus custom policy

## Canned policy

Controls:

```text
Resource
Expiration time
```

Useful for straightforward time-limited access.

## Custom policy

Can additionally control conditions such as:

```text
Start time
Expiration time
IP address range
Wildcard resource path
```

Use a custom policy when access requires more than simple expiration.

Example:

```text
Allow:
https://cdn.example.com/private/*

From:
2026-07-27 10:00 UTC

Until:
2026-07-27 12:00 UTC

Source:
Specific IP range
```

CloudFront validates that the signed policy and URL have not been modified. ([AWS Documentation][20])

---

# 46. CloudFront Functions

CloudFront Functions runs lightweight JavaScript at edge locations.

Supported event points:

```text
Viewer request
Viewer response
```

Suitable uses:

* URL redirects.
* URL rewrites.
* Header normalization.
* Query-string normalization.
* Lightweight JWT checks.
* Security headers.
* Cache-key normalization.
* Country or device-based request handling.
* A/B routing metadata.

CloudFront Functions is intended for lightweight, short-running operations and can execute at very high request scale. ([AWS Documentation][21])

---

# 47. CloudFront Function example

Redirect `/old-path` to `/new-path`:

```javascript
function handler(event) {
    var request = event.request;

    if (request.uri === "/old-path") {
        return {
            statusCode: 301,
            statusDescription: "Moved Permanently",
            headers: {
                location: {
                    value: "/new-path"
                }
            }
        };
    }

    return request;
}
```

SPA rewrite example:

```javascript
function handler(event) {
    var request = event.request;

    if (
        !request.uri.includes(".") &&
        !request.uri.startsWith("/api/")
    ) {
        request.uri = "/index.html";
    }

    return request;
}
```

Test rewrites carefully so that they do not convert missing static files into successful HTML responses unexpectedly.

---

# 48. Lambda@Edge

Lambda@Edge runs Lambda functions in response to CloudFront events.

Supported event types:

```text
Viewer request
Viewer response
Origin request
Origin response
```

Suitable when you need:

* Network access.
* Third-party libraries.
* Request-body access.
* More CPU or memory.
* Longer execution.
* Complex authentication.
* Dynamic origin selection.
* Advanced response generation.

Lambda@Edge functions are created in `us-east-1`, and Lambda replicates associated versions to locations used by CloudFront. ([AWS Documentation][21])

---

# 49. CloudFront Functions versus Lambda@Edge

| Requirement             | CloudFront Functions | Lambda@Edge |
| ----------------------- | -------------------- | ----------- |
| Lightweight redirect    | Best fit             | Possible    |
| Header modification     | Best fit             | Possible    |
| Cache-key normalization | Best fit             | Possible    |
| Network access          | No                   | Yes         |
| Request body            | No                   | Yes         |
| Third-party libraries   | Highly limited       | Yes         |
| Origin events           | No                   | Yes         |
| Submillisecond logic    | Best fit             | Heavier     |
| Python support          | No                   | Yes         |
| Larger memory           | No                   | Yes         |

CloudFront Functions supports viewer events and lightweight JavaScript, while Lambda@Edge supports viewer and origin events, Node.js or Python, network access and more execution resources. ([AWS Documentation][21])

## Memory trick

```text
Simple and extremely fast:
CloudFront Functions

Complex and origin-aware:
Lambda@Edge
```

---

# 50. Origin Shield

Origin Shield adds an additional centralized caching layer between CloudFront’s edge network and the origin.

Without Origin Shield:

```text
Edge A ──miss──> Origin
Edge B ──miss──> Origin
Edge C ──miss──> Origin
```

With Origin Shield:

```text
Edge A ──┐
Edge B ──┼──> Origin Shield ──> Origin
Edge C ──┘
```

Advantages:

* Fewer duplicate origin requests.
* Better cache-hit performance at the origin-facing layer.
* Reduced load on sensitive origins.
* Useful for live streaming or highly popular global content.
* Better request collapsing for common misses.

Origin Shield is also compatible with CloudFront origin groups and failover. ([AWS Documentation][22])

Choose an Origin Shield Region close to the origin, not necessarily close to viewers.

---

# 51. Origin failover

CloudFront origin failover uses an origin group:

```text
Origin group
├── Primary origin
└── Secondary origin
```

Example:

```text
Primary:
S3 bucket in ap-south-1

Secondary:
S3 bucket in ap-southeast-1
```

or:

```text
Primary:
ALB in Mumbai

Secondary:
ALB in Singapore
```

If the primary origin fails according to configured connection failures or HTTP status codes, CloudFront sends an eligible request to the secondary origin. ([AWS Documentation][23])

---

# 52. Origin failover conditions

You can configure failover for selected error responses such as:

```text
403
404
500
502
503
504
```

Choose carefully.

Example:

```text
404 from primary
```

might mean:

```text
Object genuinely does not exist
```

Failing over to the secondary may be unnecessary.

A stronger general failover set for application infrastructure might focus on:

```text
500
502
503
504
```

The correct configuration depends on how the origin represents failures.

---

# 53. Critical origin-failover limitation

CloudFront origin failover only applies to viewer requests using:

```text
GET
HEAD
OPTIONS
```

It does not fail over write methods such as:

```text
POST
PUT
PATCH
DELETE
```

([AWS Documentation][23])

This means CloudFront origin failover is excellent for:

* Static files.
* Downloads.
* Read-only web content.
* Cacheable APIs.
* Read-only API operations.

It is not a complete failover solution for a transactional write API.

For writes, you need application and data-layer multi-Region architecture.

---

# 54. Origin timeout and failover speed

By default, CloudFront can make multiple connection attempts to the primary origin before failing over.

The documented default origin connection pattern can result in up to approximately 30 seconds before failover:

```text
3 attempts × 10 seconds
```

You can reduce connection attempts and timeouts when faster failure detection is more important, but aggressive values may create unnecessary failovers during brief network delays. ([AWS Documentation][23])

Test using realistic:

* Origin latency.
* Connection setup time.
* TLS negotiation.
* Peak traffic.
* Regional network conditions.

---

# 55. AWS WAF with CloudFront

AWS WAF inspects HTTP requests before they reach your application.

Architecture:

```text
Internet
    |
    v
CloudFront
    |
    v
AWS WAF web ACL
    |
    ├── Allow
    ├── Block
    ├── Count
    ├── CAPTCHA
    └── Challenge
    |
    v
Origin
```

Typical WAF protections:

* SQL injection patterns.
* Cross-site scripting patterns.
* Known malicious inputs.
* IP reputation.
* Bot traffic.
* Geographic restrictions.
* Rate-based blocking.
* Header or path matching.
* Custom allowlists and blocklists.

AWS WAF web ACLs associated with CloudFront use global scope and are managed through `us-east-1` in region-aware tooling. ([AWS Documentation][24])

---

# 56. Recommended WAF rollout

Do not immediately block all requests using newly added rules.

Safer rollout:

```text
1. Add managed rule in COUNT mode.
2. Review sampled and logged requests.
3. Identify false positives.
4. Add exclusions or scope-down logic.
5. Change action to BLOCK.
6. Continue monitoring.
```

Common false-positive areas:

```text
File uploads
JSON bodies
GraphQL
Search queries
Base64 input
HTML editors
Developer tools
Large request bodies
```

A security rule that blocks legitimate customers is still a production incident.

---

# 57. Rate-based WAF rule

Example goal:

```text
Block an IP when requests exceed an approved threshold
during the configured evaluation window.
```

Terraform concept:

```hcl
resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name  = "production-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "production-cloudfront-waf"
    sampled_requests_enabled   = true
  }
}
```

The threshold above is illustrative. Determine the actual limit from known client behavior, NAT aggregation, API traffic and load testing.

---

# 58. DDoS protection

CloudFront includes the standard AWS Shield protection available to AWS resources.

A production protection stack can be:

```text
Route 53
   ↓
CloudFront
   ↓
AWS Shield
   ↓
AWS WAF
   ↓
Private/restricted origin
```

CloudFront helps absorb and distribute large traffic volumes at the edge, while WAF handles application-layer filtering.

For high-risk workloads requiring enhanced support, cost protection or specialised response capabilities, evaluate Shield Advanced according to the business risk.

---

# 59. Geographic restriction

CloudFront can allow or deny content based on viewer country.

Examples:

```text
Allow only:
India, Singapore, United States

Block:
Specific countries
```

Use cases:

* Licensing restrictions.
* Regulatory controls.
* Country-specific services.
* Content-distribution agreements.

CloudFront’s geographic restrictions work at the distribution level. More granular path- or rule-specific geographic decisions can be implemented using AWS WAF. ([AWS Documentation][25])

Geo restriction is not a perfect identity control. VPNs and proxy networks can affect the apparent viewer location.

---

# 60. Error caching

CloudFront can cache certain origin error responses.

Example:

```text
Origin returns 404
CloudFront caches 404 for configured period
```

This protects the origin from repeated requests for nonexistent content.

But an excessive error TTL can prolong an outage.

Example:

```text
Application temporarily returns 500.
CloudFront caches it for five minutes.
Application recovers after ten seconds.
Users continue seeing cached 500.
```

Configure:

```text
Error caching minimum TTL
Custom error response
Response page
Response status
```

CloudFront can cache 4xx and 5xx responses according to error settings and cache-control rules. ([AWS Documentation][26])

---

# 61. Custom error responses

For an S3-hosted single-page application, a deep-link request might be:

```text
/dashboard
```

S3 has no object named `/dashboard`, so it returns an error.

One method is:

```text
404 or 403
    ↓
Return /index.html
    ↓
Response code 200
```

However, this can hide genuine missing assets.

Example:

```text
/assets/missing.js
```

should probably remain a real error, not return HTML with status 200.

A more controlled SPA design uses a CloudFront Function rewrite only for paths that do not look like files and are not API routes.

---

# 62. Standard access logs

CloudFront standard access logs contain viewer-request information such as:

* Request time.
* Edge location.
* Request path.
* Viewer IP.
* Status code.
* Processing result.
* Response size.
* User agent.
* Referrer.
* Cache result.

Standard logging can be delivered using current supported logging destinations, including S3, CloudWatch Logs and Data Firehose through standard logging v2. ([AWS Documentation][27])

Use standard logs for:

* Historical analysis.
* Security investigations.
* Cache analysis.
* Traffic trends.
* Status-code reporting.
* Cost analysis.

---

# 63. Real-time access logs

Real-time logs are delivered within seconds through Kinesis Data Streams.

You configure:

```text
Sampling rate
Selected fields
Kinesis stream
Cache behavior association
IAM role
```

Use real-time logs for:

* Live incident response.
* Canary validation.
* Immediate cache analysis.
* Security detection.
* Streaming observability.
* Live delivery-performance analysis.

CloudFront real-time access logs support selectable fields and sampling percentages and are delivered to Kinesis Data Streams. ([AWS Documentation][28])

---

# 64. Important CloudWatch metrics

CloudFront publishes operational metrics to CloudWatch.

Important metrics include:

```text
Requests
BytesDownloaded
BytesUploaded
TotalErrorRate
4xxErrorRate
5xxErrorRate
CacheHitRate
OriginLatency
Function errors
Function execution metrics
```

CloudFront metrics and edge-function metrics can be used to monitor and troubleshoot distributions. ([AWS Documentation][29])

## Recommended alarms

```text
5xx error rate above normal baseline
4xx rate unexpectedly high
Cache-hit ratio drops
Origin latency increases
Request volume spikes
Edge-function errors occur
WAF blocked-request rate changes unexpectedly
```

Use baselines rather than universal thresholds.

---

# 65. Understanding `X-Cache`

Inspect a response:

```bash
curl -I https://cdn.example.com/assets/app.js
```

Possible header:

```http
X-Cache: Hit from cloudfront
```

Other possibilities:

```text
Miss from cloudfront
Error from cloudfront
RefreshHit from cloudfront
```

## First request

```text
X-Cache: Miss from cloudfront
```

CloudFront probably contacted the origin.

## Later request

```text
X-Cache: Hit from cloudfront
```

CloudFront served a cached response.

A miss is not necessarily a problem. It may be caused by:

* First request at that edge.
* Object expiration.
* Unique query string.
* Unique cookie.
* Header variation.
* Invalidation.
* Cache disabled.
* Noncacheable response.

---

# 66. Useful response headers

Run:

```bash
curl -I https://cdn.example.com/assets/app.js
```

Inspect:

```text
X-Cache
Age
Via
Cache-Control
Expires
ETag
Last-Modified
Content-Encoding
Content-Type
Content-Length
Server
```

## `Age`

Example:

```http
Age: 245
```

The cached response has been stored for approximately 245 seconds in the relevant caching path.

## `Cache-Control`

Shows origin or modified caching directives.

## `ETag`

Can help with validation and conditional requests.

---

# 67. Terraform provider architecture

CloudFront is a global service, but related resources may require specific Regions.

Use:

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

Use the normal provider for:

```text
S3 in ap-south-1
ALB in ap-south-1
EC2 in ap-south-1
Route 53 resources
```

Use `aws.us_east_1` for:

```text
ACM certificate for CloudFront
WAF web ACL with CLOUDFRONT scope
Lambda@Edge source function
```

CloudFront custom-domain certificates and CloudFront-scoped WAF resources are handled through `us-east-1` in AWS tooling. ([AWS Documentation][30])

---

# 68. Terraform OAC

```hcl
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "production-static-oac"
  description                       = "Access private static website bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

The distribution attaches the OAC to its S3 origin.

---

# 69. Terraform cache policy

```hcl
resource "aws_cloudfront_cache_policy" "static_assets" {
  name        = "production-static-assets"
  comment     = "Long-lived caching for hashed assets"
  default_ttl = 2592000
  max_ttl     = 31536000
  min_ttl     = 86400

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}
```

This is suitable only when the asset name changes with its content.

---

# 70. Terraform response headers policy

```hcl
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "production-security-headers"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = false
      override                   = true
    }
  }
}
```

Enable `preload` only when the organisation understands the long-lived browser consequences of HSTS preload registration.

---

# 71. Terraform distribution example

```hcl
resource "aws_cloudfront_distribution" "site" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Production frontend distribution"

  default_root_object = "index.html"

  aliases = [
    "yourdatascientist.tech",
    "www.yourdatascientist.tech"
  ]

  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "private-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  origin {
    domain_name = aws_lb.application.dns_name
    origin_id   = "application-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]

      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verification_secret
    }
  }

  default_cache_behavior {
    target_origin_id       = "private-s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    cache_policy_id = aws_cloudfront_cache_policy.static_assets.id

    response_headers_policy_id = (
      aws_cloudfront_response_headers_policy.security.id
    )

    compress = true
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "application-alb-origin"
    viewer_protocol_policy = "https-only"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "PUT",
      "POST",
      "PATCH",
      "DELETE"
    ]

    cached_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id

    origin_request_policy_id = (
      data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    )

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cloudfront.arn
    ssl_support_method  = "sni-only"

    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  tags = {
    Name        = "production-cloudfront"
    Environment = "production"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_acm_certificate_validation.cloudfront
  ]
}
```

The API behavior above disables caching by default. Introduce API caching later only after verifying authentication, variation and freshness requirements.

---

# 72. Terraform S3 bucket policy

```hcl
data "aws_iam_policy_document" "static_bucket" {
  statement {
    sid = "AllowCloudFrontDistribution"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.static.arn}/*"
    ]

    principals {
      type = "Service"

      identifiers = [
        "cloudfront.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.site.arn
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id
  policy = data.aws_iam_policy_document.static_bucket.json
}
```

---

# 73. Safe frontend deployment sequence

A reliable deployment pattern is:

```text
1. Build application.
2. Generate content-hashed assets.
3. Upload immutable assets to S3.
4. Upload images and fonts.
5. Upload index.html last.
6. Create a limited invalidation.
7. Test CloudFront domain.
8. Test custom domain.
9. Verify asset versions.
10. Monitor error rate.
```

Example:

```bash
aws s3 sync dist/ s3://production-static-site/ \
  --exclude "index.html" \
  --cache-control "public,max-age=31536000,immutable"
```

Upload entry file:

```bash
aws s3 cp dist/index.html \
  s3://production-static-site/index.html \
  --cache-control "public,max-age=0,s-maxage=60,must-revalidate" \
  --content-type "text/html"
```

Invalidate:

```bash
aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/index.html"
```

---

# 74. CloudFront deployment status

After creating or updating a distribution, the status moves through deployment.

Check:

```bash
aws cloudfront get-distribution \
  --id "$DISTRIBUTION_ID" \
  --query 'Distribution.{
    Status:Status,
    DomainName:DomainName,
    Enabled:DistributionConfig.Enabled
  }'
```

Expected:

```text
Status:
InProgress
    ↓
Deployed
```

Do not direct important production DNS traffic to an incompletely configured distribution before validating:

* Certificate.
* Alternate domain.
* Origins.
* Behaviors.
* OAC.
* WAF.
* Error handling.

---

# 75. Troubleshooting: CloudFront 403 with S3

Symptoms:

```text
403 Forbidden
AccessDenied
```

Common causes:

```text
OAC not attached
Bucket policy missing
Incorrect distribution ARN in bucket policy
S3 Block Public Access misunderstood
Object does not exist
KMS key denies decryption
Using S3 website endpoint with OAC
Object key case mismatch
```

Validation:

```bash
aws s3api head-object \
  --bucket production-static-site \
  --key index.html
```

Check OAC:

```bash
aws cloudfront get-distribution \
  --id "$DISTRIBUTION_ID"
```

Inspect:

```text
Origin domain
OriginAccessControlId
Bucket policy
KMS key policy
```

OAC requires a supported S3 bucket origin and correct S3 permission; it cannot secure an S3 website endpoint. ([AWS Documentation][8])

---

# 76. Troubleshooting: CloudFront 502

A `502 Bad Gateway` often indicates CloudFront could not establish or complete a valid connection to the custom origin.

Possible causes:

* Origin DNS failure.
* TLS certificate mismatch.
* Invalid origin certificate.
* Unsupported TLS configuration.
* ALB listener missing.
* Origin connection refused.
* Wrong origin port.
* Application closed connection.
* Lambda@Edge error.

Test the origin directly:

```bash
curl -Iv https://origin.example.com/health
```

Test TLS name:

```bash
openssl s_client \
  -connect origin.example.com:443 \
  -servername origin.example.com
```

Verify that the certificate presented by the origin covers the hostname CloudFront uses as the origin domain.

---

# 77. Troubleshooting: CloudFront 504

A `504 Gateway Timeout` typically means CloudFront connected to the origin but did not receive a timely response.

Possible causes:

```text
Application request is slow
Database query is slow
Origin read timeout too low
Target group has unhealthy capacity
Origin is overloaded
Dependency timeout
Network connection stalls
```

Investigate:

* CloudFront origin latency.
* ALB target response time.
* Application logs.
* Database performance.
* Downstream API latency.
* Origin timeout configuration.

Do not solve every 504 by increasing the timeout. That can hide application-performance problems and hold connections for longer.

---

# 78. Troubleshooting: stale content

Symptoms:

```text
New deployment completed
CloudFront still serves old file
```

Check:

```text
Cache-Control
Object path
ETag
CloudFront Age header
Cache behavior
Query-string cache key
Invalidation path
Browser cache
Service worker cache
```

Commands:

```bash
curl -I https://cdn.example.com/index.html
```

```bash
curl -H "Cache-Control: no-cache" \
  -I https://cdn.example.com/index.html
```

CloudFront and the browser are separate caches.

Even after CloudFront is updated, a browser or service worker may still serve an older object.

---

# 79. Troubleshooting: low cache-hit ratio

Possible causes:

* Forwarding every cookie.
* Forwarding unnecessary headers.
* Including tracking query strings.
* TTL too short.
* Frequent invalidation.
* Responses marked `no-store`.
* Authorization on every request.
* Unique paths for every request.
* Very low request repetition.
* Multiple unneeded cache variations.

Inspect real-time or standard log fields around:

```text
Cache result
URI
Query string
Cookies
Headers
Edge location
Response status
```

CloudFront cache statistics reports show hits, misses, errors and transferred bytes, even without enabling standard access logs. ([AWS Documentation][31])

---

# 80. Troubleshooting: CORS failure

Symptoms:

```text
Blocked by CORS policy
No Access-Control-Allow-Origin header
Preflight request failed
```

Check:

```text
OPTIONS is allowed
OPTIONS reaches correct behavior
Origin supports OPTIONS
Response headers policy includes required CORS headers
Origin and CloudFront do not create conflicting headers
Authorization header is allowed
Requested method is allowed
```

Test:

```bash
curl -i -X OPTIONS \
  -H "Origin: https://www.example.com" \
  -H "Access-Control-Request-Method: GET" \
  https://api.example.com/resource
```

Do not use:

```http
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
```

together in a credentialed browser flow.

---

# 81. Troubleshooting: custom domain certificate error

Symptoms:

```text
SSL certificate mismatch
ERR_CERT_COMMON_NAME_INVALID
CloudFront alternate domain error
```

Check:

```text
Certificate is in us-east-1
Certificate status is ISSUED
SAN covers exact hostname
Alternate domain exists on distribution
DNS points to correct distribution
Hostname is not attached to another distribution
```

CloudFront does not allow the same exact alternate domain name to remain associated with two distributions simultaneously. ([AWS Documentation][32])

---

# 82. Troubleshooting: direct ALB access still works

You intended:

```text
Users → CloudFront → ALB
```

But users can also access:

```text
ALB DNS → application
```

Possible controls:

1. Require a secret CloudFront origin header.
2. Use ALB listener rules to reject requests without it.
3. Use WAF or network restrictions appropriate to the architecture.
4. Use a private-origin solution where supported.
5. Ensure the application validates expected hostnames.
6. Rotate the secret periodically.

Do not rely only on hiding the ALB DNS name. It is not a security control.

---

# 83. Common production mistakes

## Mistake 1: Making S3 public

Better:

```text
Private bucket + OAC
```

## Mistake 2: Forwarding all headers and cookies

Result:

```text
Near-zero cache reuse
```

## Mistake 3: Caching private API responses

Result:

```text
Potential cross-user data exposure
```

## Mistake 4: Using `/app.js` with a one-year TTL

Result:

```text
Old application code remains cached
```

Use content-hashed filenames.

## Mistake 5: Invalidating `/*` after every release

Result:

```text
Higher operational overhead
Origin traffic spike
Slower warm-up
```

## Mistake 6: No origin protection

Result:

```text
Attackers bypass CloudFront and WAF
```

## Mistake 7: Assuming failover works for POST

It does not. CloudFront origin failover is limited to `GET`, `HEAD` and eligible `OPTIONS` requests. ([AWS Documentation][23])

## Mistake 8: Using one cache behavior for everything

Static files and authenticated APIs require different caching and forwarding rules.

---

# 84. Production design checklist

```text
[ ] Custom domain is configured
[ ] ACM certificate is in us-east-1
[ ] Certificate covers every alternate domain
[ ] HTTP redirects to HTTPS or is rejected
[ ] Minimum viewer TLS policy is modern
[ ] S3 origin is private
[ ] OAC is used instead of legacy OAI
[ ] S3 Block Public Access is enabled
[ ] Bucket policy restricts source distribution
[ ] KMS policy is configured when SSE-KMS is used
[ ] ALB origin uses HTTPS
[ ] Direct origin access is restricted
[ ] Static and dynamic paths use separate behaviors
[ ] Cache key contains only required values
[ ] Authentication responses are not shared accidentally
[ ] TTLs reflect content freshness
[ ] Hashed assets use long TTLs
[ ] HTML entry files use short TTLs
[ ] Invalidation is limited
[ ] Compression is enabled
[ ] Security response headers are configured
[ ] CORS is tested
[ ] AWS WAF is associated
[ ] WAF rules are tested in count mode
[ ] Rate limiting is configured where appropriate
[ ] Origin failover is tested where used
[ ] Failover limitations are documented
[ ] Origin Shield is evaluated
[ ] Standard or real-time logs are enabled
[ ] CloudWatch alarms are configured
[ ] Cache-hit ratio is monitored
[ ] 4xx and 5xx rates are monitored
[ ] Origin latency is monitored
[ ] Terraform state and secrets are protected
[ ] Deployment and rollback procedures are tested
```

---

# 85. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
CloudFront is a global CDN.
It caches content near users.
It improves delivery performance.
It can reduce origin load.
```

## Solutions Architect Associate

Understand:

```text
S3 and custom origins
OAC
Cache behaviors
Cache keys
TTL
Origin request policies
Signed URLs and cookies
ACM in us-east-1
Origin failover
WAF
Route 53 alias records
```

## DevOps Engineer Professional

Understand:

```text
Terraform deployment
Cache invalidation automation
Versioned assets
Real-time logging
WAF rollout
CloudFront Functions
Lambda@Edge
Origin Shield
Origin failover testing
Observability
Secure origin design
Multi-Region delivery
Deployment rollback
```

---

# 86. Interview questions

## Question 1: What is CloudFront?

**Answer:**

CloudFront is AWS’s content delivery network. It distributes static and dynamic content through edge locations, caches eligible responses near viewers and forwards misses or uncacheable requests to configured origins.

## Question 2: What is the difference between an edge location and an origin?

**Answer:**

An edge location receives viewer requests and may serve cached content. The origin is the authoritative backend, such as S3 or an ALB, from which CloudFront retrieves content on a miss.

## Question 3: What is Origin Access Control?

**Answer:**

OAC lets CloudFront send authenticated requests to supported origins such as S3. It enables the S3 bucket to remain private while allowing access through the intended CloudFront distribution.

## Question 4: Why is OAC preferred over OAI?

**Answer:**

OAC is the current recommended model and supports all S3 Regions, SSE-KMS and dynamic S3 request methods in supported configurations.

## Question 5: What is a cache key?

**Answer:**

A cache key identifies a specific cached variation. It can include the request path and selected query strings, headers, cookies and compression settings.

## Question 6: What is the difference between a cache policy and an origin request policy?

**Answer:**

A cache policy controls the cache key and TTLs. An origin request policy forwards additional headers, cookies or query strings to the origin without necessarily including them in the cache key.

## Question 7: Why can forwarding all cookies reduce performance?

**Answer:**

It can create separate cache entries for each cookie combination, causing a low cache-hit ratio and more requests to the origin.

## Question 8: What is the difference between signed URLs and signed cookies?

**Answer:**

Signed URLs are usually suitable for one protected object or clients without cookie support. Signed cookies are suitable for access to multiple protected objects without changing their URLs.

## Question 9: Where must an ACM certificate for CloudFront be located?

**Answer:**

It must be requested or imported into ACM in `us-east-1`.

## Question 10: When should you use CloudFront Functions?

**Answer:**

Use CloudFront Functions for lightweight viewer-request or viewer-response logic such as redirects, rewrites, header changes and cache-key normalization.

## Question 11: When should you use Lambda@Edge?

**Answer:**

Use Lambda@Edge when you need origin events, network access, third-party libraries, request-body access, more memory or more complex processing.

## Question 12: Does CloudFront origin failover support POST requests?

**Answer:**

No. Origin failover applies only to `GET`, `HEAD` and eligible `OPTIONS` viewer requests.

## Question 13: Why use versioned asset names?

**Answer:**

Versioned names let each release create a new cacheable object. This supports long TTLs, reliable rollback and fewer invalidations.

## Question 14: What causes a CloudFront 502?

**Answer:**

Typical causes include origin DNS or connection problems, incorrect ports, TLS certificate mismatch, unsupported TLS settings, origin connection failure or edge-function errors.

## Question 15: What causes a CloudFront 504?

**Answer:**

A 504 commonly means that CloudFront connected to the origin but did not receive a response within the configured timeout.

---

# 87. Never-forget revision

```text
CloudFront:
Global CDN and reverse proxy.

Viewer:
User or client requesting content.

Edge location:
CloudFront location serving the viewer.

Origin:
Authoritative backend.

Cache hit:
Object served from edge cache.

Cache miss:
Object requested from origin.

Distribution:
CloudFront configuration.

Cache behavior:
Path-based delivery rules.

Cache key:
Values identifying one cached variation.

Cache policy:
Cache key and TTL settings.

Origin request policy:
Extra values forwarded to origin.

Response headers policy:
Headers CloudFront adds to responses.

OAC:
Authenticated CloudFront access to private S3.

TTL:
How long an object remains fresh.

Invalidation:
Remove an object before expiration.

Signed URL:
Private access to an individual object.

Signed cookie:
Private access to multiple objects.

CloudFront Functions:
Lightweight viewer-edge logic.

Lambda@Edge:
Advanced viewer and origin-edge logic.

Origin Shield:
Additional origin-facing caching layer.

Origin group:
Primary and secondary origin.

AWS WAF:
Application-layer request filtering.
```

## One-line memory trick

```text
Route 53 finds CloudFront.
CloudFront protects and caches.
The cache policy chooses the variation.
The origin request policy chooses what is forwarded.
OAC protects S3.
WAF protects the application.
```

## Lesson 28 outcome

You can now design an architecture where:

```text
Static file requested
    → Served from the nearest available cache.

Object not cached
    → Retrieved securely from private S3.

Dynamic API requested
    → Forwarded to an ALB without unsafe caching.

Private video requested
    → Signed URL or cookie is validated.

Origin receives excessive traffic
    → Cache and Origin Shield reduce requests.

Primary read origin fails
    → CloudFront uses a secondary origin.

Malicious request arrives
    → AWS WAF evaluates it at the edge.

New frontend is released
    → Hashed assets deploy with long TTLs.
```

**Next lesson: Lesson 29 — AWS Certificate Manager, TLS/SSL, certificate validation, wildcard certificates, ALB and CloudFront certificate placement, renewal, trust chains, mTLS and production troubleshooting.**

[1]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Introduction.html?utm_source=chatgpt.com "What is Amazon CloudFront? - Amazon CloudFront"
[2]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html?utm_source=chatgpt.com "Use various origins with CloudFront distributions - Amazon CloudFront"
[3]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistValuesCacheBehavior.html?utm_source=chatgpt.com "Cache behavior settings - Amazon CloudFront"
[4]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cache-key-understand-cache-policy.html?utm_source=chatgpt.com "Understand cache policies - Amazon CloudFront"
[5]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/ConfiguringCaching.html?utm_source=chatgpt.com "Caching and availability - Amazon CloudFront"
[6]: https://aws.amazon.com/cloudfront/?utm_source=chatgpt.com "Amazon CloudFront - Content Delivery Network"
[7]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-https-alternate-domain-names.html?utm_source=chatgpt.com "Use alternate domain names and HTTPS - Amazon CloudFront"
[8]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html?utm_source=chatgpt.com "Restrict access to an Amazon S3 origin - Amazon CloudFront"
[9]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/template-preconfigured-origin-settings.html?utm_source=chatgpt.com "Preconfigured distribution settings reference"
[10]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/header-caching.html?utm_source=chatgpt.com "Cache content based on request headers - Amazon CloudFront"
[11]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/understanding-how-origin-request-policies-and-cache-policies-work-together.html?utm_source=chatgpt.com "Understand how origin request policies and cache policies work together - Amazon CloudFront"
[12]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Expiration.html?utm_source=chatgpt.com "Manage how long content stays in the cache (expiration) - Amazon CloudFront"
[13]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html?utm_source=chatgpt.com "Invalidate files to remove content - Amazon CloudFront"
[14]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/invalidation-specifying-objects.html?utm_source=chatgpt.com "What you need to know when invalidating paths - Amazon CloudFront"
[15]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/CreatingCNAME.html?utm_source=chatgpt.com "Add an alternate domain name - Amazon CloudFront"
[16]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/alternate-domain-names-wildcard.html?utm_source=chatgpt.com "Use wildcards in alternate domain names - Amazon CloudFront"
[17]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-urls.html?utm_source=chatgpt.com "Use signed URLs - Amazon CloudFront"
[18]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-choosing-signed-urls-cookies.html?utm_source=chatgpt.com "Decide to use signed URLs or signed cookies - Amazon CloudFront"
[19]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-trusted-signers.html?utm_source=chatgpt.com "Specify signers that can create signed URLs and signed cookies - Amazon CloudFront"
[20]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-creating-signed-url-custom-policy.html?utm_source=chatgpt.com "Create a signed URL using a custom policy - Amazon CloudFront"
[21]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/edge-functions-choosing.html?utm_source=chatgpt.com "Differences between CloudFront Functions and Lambda@Edge - Amazon CloudFront"
[22]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/origin-shield.html?utm_source=chatgpt.com "Use Amazon CloudFront Origin Shield - Amazon CloudFront"
[23]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/high_availability_origin_failover.html?utm_source=chatgpt.com "Optimize high availability with CloudFront origin failover - Amazon CloudFront"
[24]: https://docs.aws.amazon.com/waf/latest/developerguide/how-aws-waf-works-resources.html?utm_source=chatgpt.com "Resources that you can protect with AWS WAF - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[25]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/georestrictions.html?utm_source=chatgpt.com "Restrict the geographic distribution of your content - Amazon CloudFront"
[26]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/HTTPStatusCodes.html?utm_source=chatgpt.com "How CloudFront processes HTTP 4xx and 5xx status codes from your origin - Amazon CloudFront"
[27]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html?utm_source=chatgpt.com "Access logs (standard logs) - Amazon CloudFront"
[28]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/real-time-logs.html?utm_source=chatgpt.com "Use real-time access logs - Amazon CloudFront"
[29]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/monitoring-using-cloudwatch.html?utm_source=chatgpt.com "Monitor CloudFront metrics with Amazon CloudWatch"
[30]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html?utm_source=chatgpt.com "Requirements for using SSL/TLS certificates with CloudFront - Amazon CloudFront"
[31]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cache-statistics.html?utm_source=chatgpt.com "View CloudFront cache statistics reports - AWS Documentation"
[32]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/CNAMEs.html?utm_source=chatgpt.com "Use custom URLs by adding alternate domain names (CNAMEs) - Amazon CloudFront"
