# AWS Masterclass — Lesson 31 Part 3

# AWS Certificate Manager, TLS/HTTPS & Production Certificate Architecture

We have now protected:

```text
Part 1
Data at rest
    │
    ▼
KMS

Part 2
Passwords / API keys / credentials
    │
    ▼
Secrets Manager / Parameter Store

Part 3
Data moving across networks
    │
    ▼
TLS / HTTPS / ACM
```

This lesson answers one of the most important production questions:

> **When a user enters `https://app.example.com`, how does the browser know it is talking to the real server, and how does AWS encrypt that connection?**

The production architecture is:

```text
Browser
   │
   │ HTTPS / TLS
   ▼
Certificate presented
   │
   ▼
Identity verified
   │
   ▼
Encrypted connection established
   │
   ▼
CloudFront / ALB / API Gateway
```

AWS Certificate Manager manages X.509 TLS certificates for AWS-integrated services and supports public, private, and imported certificates. ([AWS Documentation][1])

---

# 1. HTTP vs HTTPS

Plain HTTP:

```text
Browser
   │
   │ HTTP
   ▼
Server
```

doesn't itself provide TLS encryption.

HTTPS means:

```text
HTTP
+
TLS
```

So:

```text
Browser
   │
   │ HTTPS
   │
   │ TLS-protected connection
   ▼
Server
```

TLS provides the foundation for:

```text
Confidentiality
Integrity
Server authentication
```

and can optionally authenticate clients as well with **mutual TLS**.

---

# 2. What Is TLS Actually Protecting?

Imagine a login request:

```text
username=vivek
password=SuperSecret
```

Without transport encryption, an observer on an untrusted network might potentially inspect or manipulate network traffic.

TLS establishes an authenticated encrypted channel:

```text
Application data
       │
       ▼
TLS encryption
       │
       ▼
Network
       │
       ▼
TLS decryption
       │
       ▼
Application data
```

This is:

```text
ENCRYPTION IN TRANSIT
```

whereas:

```text
S3 SSE-KMS
EBS encryption
RDS encryption
```

primarily address:

```text
ENCRYPTION AT REST
```

---

# 3. TLS Uses More Than One Type of Cryptography

This connects directly to our KMS lesson.

TLS combines concepts such as:

```text
Asymmetric cryptography
        │
        ├── authentication
        └── key establishment/signatures

                +

Symmetric cryptography
        │
        └── bulk session encryption
```

Why?

Symmetric cryptography is efficient for encrypting lots of application traffic.

Public-key cryptography lets parties authenticate identities and establish the keying material required for the secure session.

---

# 4. Certificate Mental Model

A server certificate contains information such as:

```text
Certificate
│
├── Domain identity
├── Public key
├── Issuer
├── Validity dates
├── Serial number
├── Signature
└── Subject Alternative Names
```

Application Load Balancer documentation describes server certificates as X.509 certificates containing identity information, validity, a public key, serial number, and CA signature. ([AWS Documentation][2])

---

# 5. Public Key vs Private Key

Conceptually:

```text
             KEY PAIR

        ┌───────────────┐
        │               │
        ▼               ▼
   PUBLIC KEY       PRIVATE KEY
        │               │
 certificate          protected
 distributes it       carefully
```

The public key is designed to be distributed.

The private key must remain protected.

If an attacker obtains your private key, that can compromise important parts of your TLS identity/security model.

---

# 6. What Does ACM Do With the Private Key?

For ACM-managed certificates used by integrated AWS services, ACM manages the private-key lifecycle for you rather than requiring you to copy private keys onto load balancers manually. ACM protects certificate private keys as part of its certificate-management architecture. ([AWS Documentation][3])

This is one major reason ACM is preferable to:

```text
certificate.pem
private-key.pem
```

manually copied across servers.

---

# 7. Certificate Authority — CA

How does the browser know:

```text
www.example.com certificate
```

should be trusted?

A:

# Certificate Authority

digitally signs certificates.

Conceptually:

```text
Trusted Root CA
      │
      ▼
Intermediate CA
      │
      ▼
Server Certificate
      │
      ▼
www.example.com
```

This forms the:

# Certificate Chain

---

# 8. Chain of Trust

Client:

```text
Server certificate
      │
      ▼
Who signed it?
      │
      ▼
Intermediate CA
      │
      ▼
Who signed that?
      │
      ▼
Trusted Root CA
```

The operating system/browser has a trusted root store.

If the chain terminates in a trusted CA and validation succeeds:

```text
certificate may be trusted
```

assuming hostname, validity, revocation/policy, and other checks also succeed.

---

# 9. TLS Handshake — Simplified Production Model

When you visit:

```text
https://www.example.com
```

roughly:

```text
1. Client connects
       │
       ▼
2. TLS capabilities exchanged
       │
       ▼
3. Server sends certificate
       │
       ▼
4. Client validates certificate
       │
       ├── trusted issuer?
       ├── correct hostname?
       ├── valid dates?
       └── valid chain?
       │
       ▼
5. Cryptographic key agreement
       │
       ▼
6. Session keys established
       │
       ▼
7. HTTP traffic encrypted
```

Modern ALB security policies support TLS 1.3 as well as policies supporting TLS 1.2, with forward-secrecy-capable suites available. ([AWS Documentation][4])

---

# 10. Do Not Memorize This Old TLS Explanation

You may hear:

> “The browser generates a symmetric key and encrypts it using the server's RSA public key.”

That describes older RSA key-exchange models and is a poor mental model for modern TLS.

For production understanding, think:

```text
Certificate
=
server authentication

Key agreement
=
establish shared secret

Symmetric keys
=
encrypt application traffic
```

This stays conceptually correct for modern TLS architectures.

---

# 11. Domain Name Must Match the Certificate

Suppose browser requests:

```text
api.example.com
```

but certificate covers:

```text
shop.example.com
```

That's a hostname mismatch.

The certificate must cover the requested custom domain through the relevant certificate identity/SAN. CloudFront explicitly verifies that alternate domain names are covered by the attached certificate's SAN, either exactly or through a valid wildcard. ([AWS Documentation][5])

---

# 12. SAN — Subject Alternative Name

Suppose one certificate protects:

```text
example.com

www.example.com

api.example.com

admin.example.com
```

These additional identities are represented using:

# Subject Alternative Names

or:

```text
SANs
```

ACM lets a public certificate request contain multiple domain names. ([AWS Documentation][6])

---

# 13. Wildcard Certificates

Example:

```text
*.example.com
```

covers:

```text
www.example.com
api.example.com
shop.example.com
```

But it does **not** cover:

```text
example.com
```

and it does **not** cover:

```text
api.dev.example.com
```

because an ACM wildcard protects only one subdomain level and the `*` must be in the leftmost position. ([AWS Documentation][6])

---

# 14. Apex + Wildcard

Therefore a common certificate request is:

```text
example.com
*.example.com
```

This gives:

```text
example.com
      ✓

www.example.com
      ✓

api.example.com
      ✓
```

ACM explicitly recommends adding both names when you need the apex plus its first-level subdomains. ([AWS Documentation][6])

---

# 15. A Wildcard Is Not Recursive

Never forget:

```text
*.example.com
```

does not mean:

```text
everything at every depth
```

It means approximately:

```text
ONE label
.
example.com
```

So:

```text
foo.example.com      ✓

foo.bar.example.com  ✗
```

([AWS Documentation][7])

---

# 16. AWS Certificate Manager — ACM

ACM handles much of the complexity around:

```text
certificate request
storage
deployment to integrated AWS services
renewal
```

for public and private X.509 certificates. ([AWS Documentation][1])

Common integrations include:

```text
CloudFront
Application Load Balancer
Network Load Balancer
API Gateway
```

among supported AWS services. ([AWS Documentation][8])

---

# 17. Public ACM Certificate

Use:

```text
PUBLIC certificate
```

when clients such as:

```text
Chrome
Firefox
Safari
mobile applications
public API clients
```

need to trust your service using normal public PKI.

Examples:

```text
www.example.com

api.example.com
```

---

# 18. Private Certificate

For internal environments:

```text
payments.internal.example.com

database.corp.example.com

service.internal.example.com
```

you may use a private certificate architecture backed by:

# AWS Private CA

rather than requiring public CA trust.

AWS Private CA lets organizations operate private PKI hierarchies and issue private certificates for internal trust environments. ([AWS Documentation][9])

---

# 19. Public vs Private Certificate

Mental model:

```text
PUBLIC ACM CERT
        │
        ▼
Public internet trust


PRIVATE CERT
        │
        ▼
Organization-controlled
private trust
```

Private certificates are useful for:

```text
internal services
enterprise devices
mTLS
service-to-service identity
private infrastructure
```

when clients have your private CA hierarchy in their trust store.

---

# 20. ACM Domain Validation

Before Amazon issues a publicly trusted certificate, ACM must verify that you control the requested domain.

Current ACM validation methods include:

```text
DNS validation

Email validation

HTTP validation
```

HTTP validation is currently associated with CloudFront certificate workflows; DNS remains AWS's recommended general-purpose method when you can modify DNS. ([AWS Documentation][10])

---

# 21. DNS Validation

ACM gives you a CNAME such as conceptually:

```text
_acme-value.example.com
        │
        CNAME
        ▼
_random.acm-validations.aws
```

When ACM sees that expected public DNS record:

```text
you have demonstrated
control of the DNS namespace
```

ACM DNS validation uses generated CNAME records for this proof. ([AWS Documentation][11])

---

# 22. Why DNS Validation Is My Preferred Production Choice

AWS recommends DNS validation where possible because, among other benefits, DNS-validated certificates can renew automatically while the certificate remains eligible/in use and the required validation record remains present. ([AWS Documentation][10])

Therefore:

```text
DO NOT DELETE
ACM VALIDATION CNAME
```

just because:

```text
certificate status
=
ISSUED
```

You may break future managed renewal.

---

# 23. Important 2026 Certificate Lifetime Change

This is important because many older AWS tutorials are now outdated.

As of 2026, ACM-issued public certificates have a validity period of:

```text
198 days
```

and ACM begins the public-certificate renewal process roughly:

```text
45 days before expiration
```

AWS changed the public validity period to comply with newer CA/B Forum certificate-lifetime requirements. ([AWS Documentation][12])

So don't memorize old material saying:

```text
ACM public certificate
=
395 days
```

as the current rule.

---

# 24. Email Validation

ACM can also send validation messages to standard domain administration addresses such as:

```text
admin@
administrator@
hostmaster@
postmaster@
webmaster@
```

For email-validated certificates, renewal requires domain-owner action rather than the seamless DNS-validation renewal model. ([AWS Documentation][13])

For infrastructure automation:

```text
DNS validation
```

is generally much easier.

---

# 25. Route 53 + ACM

If Route 53 hosts the public zone, ACM can help create the required validation records through the console when you have appropriate Route 53 permissions. ([AWS Documentation][11])

Architecture:

```text
ACM
 │
 │ validation CNAME
 ▼
Route 53
 │
 ▼
Public DNS
 │
 ▼
ACM verifies control
 │
 ▼
Certificate ISSUED
```

---

# 26. DNS Provider Does NOT Have to Be Route 53

Suppose domain is registered or DNS hosted elsewhere:

```text
GoDaddy
Cloudflare
another registrar/DNS provider
```

You can still request an ACM certificate.

You simply copy ACM's required validation CNAME into that DNS provider's public zone. ([AWS Documentation][11])

Remember:

```text
ACM
≠
Route 53 requirement
```

---

# 27. Common DNS Validation Error

Some DNS providers automatically append:

```text
example.com
```

to the record name.

If ACM gives:

```text
_abc.example.com
```

and you enter the full name into a provider that automatically appends the zone, you could accidentally create:

```text
_abc.example.com.example.com
```

Then validation fails. AWS specifically documents this as a common ACM DNS-validation problem. ([AWS Documentation][11])

---

# 28. ACM Validation Timeout

If ACM cannot validate the generated DNS challenge within the required period, the request can move to:

```text
Validation timed out
```

The current documented certificate request validation window is 72 hours, after which you need to correct the DNS problem and request a new certificate. ([AWS Documentation][14])

---

# 29. CAA — Certification Authority Authorization

DNS can contain:

```text
CAA
```

records specifying which certificate authorities may issue certificates for the domain.

For example:

```text
example.com
CAA
...
```

If your CAA policy doesn't authorize the Amazon CA, ACM issuance can fail even if the basic ownership validation succeeded. ([AWS Documentation][15])

So:

```text
Pending/failed ACM issuance
```

can be caused by:

```text
DNS CNAME
or
CAA policy
```

depending on the error.

---

# 30. CloudFront Certificate Rule — Burn This Into Memory

For a custom domain on CloudFront:

```text
Certificate must be in:

us-east-1
US East (N. Virginia)
```

CloudFront only supports ACM viewer certificates from `us-east-1`. ([AWS Documentation][16])

This is one of the most important certification and production rules.

---

# 31. CloudFront Architecture

```text
Browser
   │
   ▼
https://www.example.com
   │
   ▼
Route 53
   │
   ▼
CloudFront
   │
   └── ACM Certificate
       Region = us-east-1
   │
   ▼
Origin
```

The origin itself could be:

```text
S3
ALB
API Gateway
custom origin
```

---

# 32. Why Your Mumbai Region Does Not Change This

Suppose:

```text
S3 / ALB / EC2
=
ap-south-1
```

but viewers connect to:

```text
CloudFront
```

The **viewer certificate** is still:

```text
us-east-1
```

because it belongs to CloudFront's global viewer-facing TLS configuration. ([AWS Documentation][17])

---

# 33. CloudFront Certificate Must Cover Every Alias

Suppose distribution aliases:

```text
example.com

www.example.com

api.example.com
```

The attached certificate must cover those names through exact SAN entries or appropriate wildcard coverage. CloudFront checks that relationship before accepting an alternate domain name. ([AWS Documentation][5])

---

# 34. ALB Certificate Architecture

Suppose:

```text
ALB
Region:
ap-south-1
```

HTTPS listener:

```text
443
```

uses an ACM server certificate available to that Regional load-balancer configuration. ALB terminates the front-end TLS connection and decrypts requests before routing them to targets. ([AWS Documentation][18])

Architecture:

```text
Client
   │
   │ HTTPS
   ▼
ALB :443
   │
   │ ACM certificate
   │
   ▼
TLS termination
   │
   ▼
Target Group
```

---

# 35. CloudFront + ALB Often Means TWO Certificates

This surprises many engineers.

Architecture:

```text
Browser
   │
   │ HTTPS #1
   ▼
CloudFront
   │
   │ Certificate:
   │ us-east-1
   │
   │ HTTPS #2
   ▼
ALB
   │
   │ Regional certificate
   │ e.g. ap-south-1
   ▼
Application
```

If both viewer→CloudFront and CloudFront→ALB connections use HTTPS, there are two separate TLS connections with potentially separate certificates. CloudFront's certificate must be in `us-east-1`; the ALB's HTTPS listener uses the certificate attached to the Regional load balancer. ([AWS Documentation][19])

This is **extremely important**.

---

# 36. TLS Termination at ALB

ALB can terminate TLS:

```text
Client
   │ HTTPS
   ▼
ALB
   │ HTTP
   ▼
EC2
```

or you can maintain encryption toward the backend:

```text
Client
   │ HTTPS
   ▼
ALB
   │ HTTPS
   ▼
EC2
```

ALB target groups support HTTP and HTTPS. When HTTPS is used to targets, ALB creates a TLS connection to the target. ([AWS Documentation][20])

---

# 37. Important ALB Backend Certificate Detail

For an HTTPS target group, Application Load Balancer establishes TLS with the target but currently **does not validate the target certificate**. ([AWS Documentation][20])

That's a useful advanced detail.

It means:

```text
ALB → target HTTPS
```

provides encryption in transit, but the backend certificate validation semantics are not the same as a normal browser validating a public web certificate.

---

# 38. ALB Requires a Default Certificate

An HTTPS listener must have:

```text
one default certificate
```

You may then add more certificates to the listener's certificate list. ([AWS Documentation][2])

Architecture:

```text
ALB :443
 │
 ├── Default certificate
 │
 ├── api.example.com certificate
 │
 └── shop.example.com certificate
```

How does ALB choose?

# SNI

---

# 39. SNI — Server Name Indication

Client sends the requested hostname during TLS negotiation:

```text
api.example.com
```

ALB can then select the appropriate certificate from its list.

This lets one listener/IP combination securely serve multiple domain certificates. Application Load Balancer supports certificate lists and smart certificate selection using SNI. ([AWS Documentation][2])

---

# 40. Multiple Applications on One ALB

Example:

```text
                ALB :443
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
 api.example.com shop...    admin...
       │           │           │
    Cert A       Cert B      Cert C
```

Then host-based listener rules can route:

```text
api.example.com
→ API target group

shop.example.com
→ shop target group
```

SNI chooses the TLS certificate.

ALB listener rules choose the backend.

Two different layers.

---

# 41. SAN Certificate vs Multiple SNI Certificates

Option A:

```text
one certificate
with SANs:

api.example.com
shop.example.com
admin.example.com
```

Option B:

```text
Certificate A
api.example.com

Certificate B
shop.example.com

Certificate C
admin.example.com
```

ALB supports either strategy through its certificate list. ([AWS Documentation][2])

Tradeoff:

```text
SAN cert
=
fewer certificates

Separate certs
=
smaller identity/lifecycle blast radius
```

---

# 42. TLS Security Policy

Certificate answers:

```text
WHO is this endpoint?
```

ALB security policy controls things such as:

```text
TLS protocol versions
cipher suites
key exchange compatibility
```

When creating an HTTPS listener, AWS requires both a certificate and a security policy. ([AWS Documentation][18])

Do not treat:

```text
certificate
```

and:

```text
TLS policy
```

as the same thing.

---

# 43. TLS 1.2 vs TLS 1.3

Application Load Balancer currently supports predefined policies with TLS 1.3, including policies that also support TLS 1.2 for broader client compatibility. ([AWS Documentation][4])

Production decisions depend on clients:

```text
Modern browsers/API clients
       │
       ▼
TLS 1.3 preferred

Older enterprise/device clients
       │
       ▼
may require compatible TLS 1.2 policy
```

Security policy selection is a security **and compatibility** decision.

---

# 44. RSA vs ECDSA Certificates

ACM supports both RSA and ECDSA public-key algorithms for certificates. Current ACM public-certificate requests support RSA 2048 and ECDSA P-256/P-384 options, while ACM's broader certificate/import support includes additional algorithms and sizes. ([AWS Documentation][21])

ECDSA often provides:

```text
smaller keys
efficient cryptographic operations
```

for comparable security, but client compatibility must be considered. ([AWS Documentation][7])

---

# 45. CloudFront Certificate Compatibility

Don't assume every algorithm ACM can store can be used by every integrated service.

AWS explicitly notes that ACM-integrated services support their own subsets of certificate algorithms/key sizes. ([AWS Documentation][22])

Mental rule:

```text
ACM supports certificate
        │
        X not enough
        ▼
Target AWS service
must also support it
```

---

# 46. API Gateway Custom Domains

Suppose API Gateway has default domain:

```text
abc123.execute-api.ap-south-1.amazonaws.com
```

but you want:

```text
api.example.com
```

You configure:

```text
API Gateway Custom Domain
+
ACM certificate
+
DNS mapping
```

API Gateway requires the certificate to cover the custom domain. ([AWS Documentation][23])

---

# 47. Regional API Gateway Certificate

For a:

```text
REGIONAL custom domain
```

the ACM certificate must be in the:

```text
same Region as the Regional API
```

So:

```text
API Gateway
ap-south-1

Certificate
ap-south-1
```

([AWS Documentation][24])

---

# 48. Edge-Optimized API Gateway Certificate

For:

```text
EDGE-OPTIMIZED
REST API custom domain
```

the certificate must be:

```text
us-east-1
```

because API Gateway's edge-optimized architecture uses CloudFront. ([AWS Documentation][25])

Never forget:

```text
API Gateway Regional
→ same Region

API Gateway Edge-Optimized
→ us-east-1
```

---

# 49. Route 53 + API Gateway

After creating:

```text
api.example.com
```

as API Gateway custom domain, DNS still must map:

```text
api.example.com
```

to the API Gateway custom-domain endpoint.

API Gateway documentation explicitly notes that the custom-domain setup is incomplete until DNS is mapped appropriately. ([AWS Documentation][23])

This connects directly to Lesson 29.

---

# 50. mTLS — Mutual TLS

Normal public TLS:

```text
Client
    │
    ▼
Server certificate
    │
    ▼
Client authenticates server
```

Mutual TLS:

```text
Client certificate
        │
        ▼
Server validates client

             AND

Server certificate
        │
        ▼
Client validates server
```

Therefore:

```text
BOTH SIDES
authenticate cryptographically
```

---

# 51. Why Use mTLS?

Use cases include:

```text
B2B APIs

machine-to-machine communication

IoT devices

internal high-trust APIs

partner integrations
```

API Gateway describes mTLS as two-way authentication requiring clients to present trusted X.509 certificates, and specifically cites IoT and B2B scenarios. ([AWS Documentation][26])

---

# 52. ALB mTLS

Application Load Balancer now supports mutual TLS modes where it can validate client certificates against a configured trust store or pass certificate information through to the application. ([AWS Documentation][27])

Conceptually:

```text
Client
 │
 │ client cert
 ▼
ALB
 │
 ├── validate certificate
 │
 ▼
Backend
```

The trust chain can use third-party CA certificates or certificates from AWS Private CA. ([AWS Documentation][27])

---

# 53. API Gateway mTLS

For API Gateway custom domains, mTLS uses a trust store stored in:

```text
Amazon S3
```

The trust store contains trusted CA certificates that API Gateway uses to validate client certificates. ([AWS Documentation][28])

Architecture:

```text
Client Certificate
        │
        ▼
API Gateway
        │
        ▼
Truststore in S3
        │
        ▼
trusted?
  │           │
 YES          NO
  │           │
  ▼           X
API
```

---

# 54. ACM Public Certificates — Important 2026 Export Change

Older AWS material often taught:

> “You cannot export the private key of an ACM public certificate.”

That is no longer universally correct.

ACM now supports **exportable public certificates** when you request the certificate with export enabled. You can export the certificate, certificate chain, and private key for deployment outside ACM-integrated AWS services. ([AWS Documentation][29])

This is an important 2026 update.

---

# 55. Managed vs Exportable Public Certificate

Think:

```text
ACM-managed integrated-service cert
        │
        ▼
CloudFront / ALB / API Gateway
```

versus:

```text
ACM exportable public cert
        │
        ▼
export certificate
+ private key
+ chain
        │
        ▼
external/custom server
```

ACM continues to manage renewal of exportable public certificates and makes renewed certificate material available, but deployment of renewed material to unmanaged infrastructure remains your operational responsibility. ([AWS Documentation][29])

---

# 56. Imported Certificate

You can also obtain a certificate from another CA and:

```text
IMPORT
```

it into ACM.

You provide:

```text
certificate body

certificate private key

certificate chain
```

in the required PEM formats. ([AWS Documentation][30])

But there is an important operational difference.

---

# 57. Imported Certificate Renewal

ACM does **not** automatically renew certificates that you imported from a third-party issuer.

You must:

```text
obtain renewed certificate
       │
       ▼
reimport/update ACM
```

before expiration. ([AWS Documentation][30])

Therefore:

```text
AMAZON-ISSUED
```

and:

```text
IMPORTED
```

have different renewal responsibilities.

---

# 58. Managed Renewal

For eligible ACM-issued certificates, ACM handles managed renewal. DNS-validated certificates can renew automatically when the certificate remains eligible/in use and the DNS validation record remains present. ([AWS Documentation][31])

Typical integrated setup:

```text
ACM Certificate
    │
    ▼
ALB
```

or:

```text
ACM Certificate
    │
    ▼
CloudFront
```

lets ACM replace the certificate behind the service integration without you manually uploading a new PEM bundle. ([AWS Documentation][2])

---

# 59. Most Common Renewal Failure

For DNS-validated ACM certificates:

```text
Validation CNAME deleted
```

is one of the most common renewal problems.

AWS specifically states that missing or inaccurate validation CNAMEs are the likely cause when DNS-validated managed renewal fails. ([AWS Documentation][32])

So never clean up:

```text
_random.acm-validations.aws
```

because:

> “It looks unused.”

---

# 60. Monitor Certificate Expiry Anyway

Even with automatic renewal, production environments should monitor certificates.

ACM emits EventBridge events for conditions such as:

```text
Certificate Approaching Expiration

Certificate Expired

Certificate Available

Certificate Renewal Action Required

Certificate Revoked
```

([AWS Documentation][33])

Automation should notify your operations/security team before users discover an expiry.

---

# 61. Terraform Multi-Region Provider Pattern

Now let's build our common architecture:

```text
Application Region
=
ap-south-1

CloudFront certificate
=
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

This pattern is necessary because ACM certificates are Regional while CloudFront requires its ACM viewer certificate in `us-east-1`. ([AWS Documentation][17])

---

# 62. Terraform — CloudFront ACM Certificate

```hcl
resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name = "example.com"

  subject_alternative_names = [
    "*.example.com"
  ]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
```

The current AWS Terraform provider supports `DNS` or `EMAIL` as `validation_method` for requested ACM certificates. ([Terraform Registry][34])

---

# 63. Create Route 53 Validation Records

Conceptually:

```hcl
resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.public.zone_id

  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}
```

These records prove domain control to ACM. ([AWS Documentation][11])

---

# 64. Terraform Certificate Validation

```hcl
resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1

  certificate_arn =
    aws_acm_certificate.cloudfront.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cloudfront_cert_validation :
    record.fqdn
  ]
}
```

The Terraform provider's `aws_acm_certificate_validation` resource models completion of certificate validation. ([Terraform Registry][35])

Important:

```text
certificate requested
in us-east-1

validation resource
must operate against
that same certificate Region
```

---

# 65. Terraform — CloudFront Viewer Certificate

```hcl
resource "aws_cloudfront_distribution" "web" {

  # ...

  aliases = [
    "example.com",
    "www.example.com"
  ]

  viewer_certificate {
    acm_certificate_arn =
      aws_acm_certificate_validation.cloudfront.certificate_arn

    ssl_support_method = "sni-only"

    minimum_protocol_version =
      "TLSv1.2_2021"
  }
}
```

The certificate must cover all aliases and be an ACM certificate in `us-east-1`. ([AWS Documentation][5])

---

# 66. Terraform — ALB Certificate

For the Mumbai ALB, request a separate Regional certificate:

```hcl
resource "aws_acm_certificate" "alb" {
  domain_name = "origin.example.com"

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
```

Because the default provider is:

```text
ap-south-1
```

this certificate belongs to your Mumbai application-side TLS setup.

---

# 67. Terraform — ALB HTTPS Listener

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn

  port     = 443
  protocol = "HTTPS"

  certificate_arn =
    aws_acm_certificate_validation.alb.certificate_arn

  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "forward"

    target_group_arn =
      aws_lb_target_group.app.arn
  }
}
```

ALB HTTPS listeners require a server certificate and an SSL/TLS security policy. ALB currently provides TLS 1.3-capable predefined policies. ([AWS Documentation][18])

---

# 68. Complete CloudFront + ALB Certificate Architecture

```text
                         INTERNET
                            │
                            ▼
                 www.example.com
                            │
                            ▼
                         Route 53
                            │
                            ▼
                        CloudFront
                            │
               ACM certificate #1
                    us-east-1
                            │
                       HTTPS
                            │
                            ▼
                 origin.example.com
                            │
                            ▼
                           ALB
                     ap-south-1
                            │
               ACM certificate #2
                    ap-south-1
                            │
                            ▼
                       Target Group
                            │
                            ▼
                        EC2 / ECS
```

### Never forget:

```text
CloudFront viewer TLS
=
us-east-1 certificate

ALB TLS
=
Regional certificate
```

([AWS Documentation][17])

---

# 69. Route 53 Alias Layer

Then DNS:

```text
example.com
      │
      ▼
Alias
      │
      ▼
CloudFront
```

and optionally your protected origin DNS:

```text
origin.example.com
      │
      ▼
Alias
      │
      ▼
ALB
```

But if CloudFront should be the only public entry point, don't casually expose an origin hostname/design that allows users to bypass your CloudFront/WAF controls.

---

# 70. Hands-On Certificate Request — CloudFront

Request public certificate in the required Region:

```bash
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names "*.example.com" \
  --validation-method DNS \
  --region us-east-1
```

Then inspect:

```bash
aws acm describe-certificate \
  --certificate-arn <CERTIFICATE_ARN> \
  --region us-east-1
```

Look for:

```text
Status

DomainValidationOptions

NotBefore

NotAfter

RenewalEligibility
```

The CloudFront requirement for the certificate's ACM Region remains `us-east-1`. ([AWS Documentation][16])

---

# 71. Certificate Troubleshooting Decision Tree

```text
                 HTTPS BROKEN
                     │
                     ▼
              Does DNS resolve?
               │           │
              NO          YES
               │           │
               ▼           ▼
          Route 53       TLS handshake?
                           │       │
                          FAIL     OK
                           │       │
                           ▼       ▼
                     Certificate  HTTP/App
                     investigation
```

TLS investigation:

```text
correct domain?

correct certificate Region?

certificate issued?

certificate attached?

expired?

SAN covers hostname?

CAA issue?

validation CNAME missing?

unsupported TLS policy/client?

wrong certificate selected via SNI?
```

---

# 72. `curl` Troubleshooting

Use:

```bash
curl -Iv https://www.example.com
```

Inspect:

```text
TLS negotiation

certificate subject

issuer

expiry

HTTP status
```

For a specific origin behind DNS:

```bash
curl -Iv https://origin.example.com
```

This separates:

```text
CloudFront TLS
```

from:

```text
ALB TLS
```

---

# 73. `openssl s_client`

Extremely useful:

```bash
openssl s_client \
  -connect www.example.com:443 \
  -servername www.example.com
```

Why `-servername`?

Because it sends the hostname using:

```text
SNI
```

which is essential when an endpoint serves multiple certificates.

Useful output includes:

```text
certificate chain

server certificate

protocol

cipher

verification
```

---

# 74. Inspect Certificate Dates

```bash
echo | openssl s_client \
  -connect www.example.com:443 \
  -servername www.example.com \
  2>/dev/null \
  | openssl x509 \
      -noout \
      -subject \
      -issuer \
      -dates
```

You can quickly see:

```text
subject=

issuer=

notBefore=

notAfter=
```

Excellent during certificate incidents.

---

# 75. Browser Says “Certificate Not Valid for This Domain”

Most likely:

```text
hostname mismatch
```

Example:

```text
requested:
api.example.com

certificate:
www.example.com
```

Fix:

```text
certificate must include:

api.example.com

or valid wildcard
*.example.com
```

CloudFront makes the same SAN/wildcard coverage requirement for aliases. ([AWS Documentation][5])

---

# 76. `*.example.com` but Apex Fails

Certificate:

```text
*.example.com
```

Browser:

```text
https://example.com
```

fails hostname coverage.

Why?

Wildcard doesn't protect apex.

Fix certificate request:

```text
example.com
*.example.com
```

([AWS Documentation][7])

---

# 77. CloudFront Says Certificate Doesn't Exist

First question:

```text
Which Region did you create it in?
```

If:

```text
ap-south-1
```

CloudFront won't use it as the viewer ACM certificate.

Create/request/import CloudFront's certificate in:

```text
us-east-1
```

([AWS Documentation][17])

---

# 78. ALB Certificate Not Available

Check:

```text
correct AWS account?

correct Region?

certificate status = ISSUED?

supported key type?

certificate attached to correct listener?
```

An ALB HTTPS listener selects certificates available to that Regional load-balancer configuration. ([AWS Documentation][18])

---

# 79. Certificate Stuck `PENDING_VALIDATION`

Check:

```bash
dig CNAME _validation-record.example.com
```

Verify exact:

```text
name
type
value
```

against:

```bash
aws acm describe-certificate
```

Common reasons include malformed DNS names, public DNS not resolving the validation record, or a CAA restriction. ([AWS Documentation][11])

---

# 80. Private Hosted Zone Cannot Validate a Public Certificate

ACM public DNS validation requires the validation DNS record to be publicly resolvable.

Putting it only inside:

```text
Route 53 Private Hosted Zone
```

won't satisfy normal public certificate issuance. AWS explicitly notes this in its DNS-validation troubleshooting guidance. ([AWS Documentation][36])

This connects directly to Lesson 29:

```text
Private DNS
≠
Public DNS ownership proof
```

---

# 81. Certificate Renewed but Clients Still See Old Certificate

Check:

```text
Which endpoint?
CloudFront?
ALB?
API Gateway?
Custom server?

Which certificate ARN attached?

Was imported cert manually renewed?

Was exported cert redeployed?

DNS pointing to expected endpoint?
```

ACM-issued certificates integrated with supported AWS services can update through managed renewal, while imported certificates require manual renewal/reimport and exported certificates require you to manage deployment of renewed exported material to unmanaged infrastructure. ([AWS Documentation][2])

---

# 82. Production Certificate Design Rules

```text
PUBLIC WEBSITE
      │
      ▼
Public ACM certificate


INTERNAL PRIVATE PKI
      │
      ▼
AWS Private CA / private certificate


CloudFront
      │
      ▼
ACM us-east-1


Regional ALB
      │
      ▼
Regional ACM certificate


Regional API Gateway
      │
      ▼
same-region ACM certificate


Edge-optimized API Gateway
      │
      ▼
ACM us-east-1
```

([AWS Documentation][17])

---

# 83. SAA-C03 Scenario

> CloudFront distribution in front of an application in Mumbai needs `www.example.com`.

Certificate Region?

```text
us-east-1
```

Not:

```text
ap-south-1
```

([AWS Documentation][16])

---

# 84. SAA-C03 Scenario

> Regional API Gateway API in Mumbai uses `api.example.com`.

Certificate:

```text
ap-south-1
```

because Regional API Gateway custom domains use ACM certificates in the API's Region. ([AWS Documentation][37])

---

# 85. SAA-C03 Scenario

> Need one certificate for `www.example.com`, `api.example.com` and `shop.example.com`.

Options:

```text
*.example.com
```

or:

```text
SAN certificate with
those names
```

But if you also need:

```text
example.com
```

add that apex identity separately because the wildcard doesn't cover it. ([AWS Documentation][6])

---

# 86. Scenario

> Internal B2B API requires each client company to present a certificate.

Think:

```text
mTLS
```

using an mTLS-capable front door such as API Gateway or Application Load Balancer depending on the architecture. ([AWS Documentation][27])

---

# 87. Scenario

> Imported certificate expires next week. Will ACM automatically renew it?

```text
NO
```

Imported third-party certificates do not receive ACM managed renewal; renew from the issuing CA and reimport/update them. ([AWS Documentation][30])

---

# 88. Scenario

> DNS-validated ACM certificate used by ALB is approaching expiry.

First inspect:

```text
validation CNAME still exists?

certificate still associated/in use?

renewal status?
```

ACM's DNS-managed renewal depends on continued validation and eligibility. ([AWS Documentation][31])

---

# 89. Scenario

> Public ACM certificate should be deployed on non-AWS infrastructure.

As of 2026, evaluate an:

```text
ACM exportable public certificate
```

which allows export of the certificate, chain, and private key. ([AWS Documentation][29])

Older blanket advice saying:

```text
ACM public certificates
can never be exported
```

is no longer correct.

---

# 90. Never-Forget Certificate Map

```text
                        CERTIFICATE
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
          IDENTITY       PUBLIC KEY       ISSUER
             │                              │
             ▼                              ▼
            SAN                         CA CHAIN
             │                              │
             ▼                              ▼
      example.com                     Trusted Root
      *.example.com
```

---

# 91. Never-Forget AWS Region Map

```text
                       AWS TLS CERTIFICATES

CloudFront
    │
    └── ACM us-east-1


ALB in Mumbai
    │
    └── ACM ap-south-1


Regional API Gateway Mumbai
    │
    └── ACM ap-south-1


Edge-Optimized API Gateway
    │
    └── ACM us-east-1
```

([AWS Documentation][17])

---

# 92. Never-Forget TLS Architecture

```text
CLIENT
  │
  ▼
DNS resolves hostname
  │
  ▼
TCP/transport connection
  │
  ▼
TLS handshake
  │
  ├── certificate presented
  ├── hostname validated
  ├── chain validated
  ├── cryptographic negotiation
  └── session keys established
  │
  ▼
HTTPS application traffic
```

Notice:

```text
DNS
```

and:

```text
TLS
```

are different layers.

DNS tells the client:

```text
WHERE to connect
```

TLS helps establish:

```text
WHO am I connected to
+
encrypted channel
```

---

# 93. 25 Rules to Burn Into Memory

```text
1. HTTPS = HTTP over TLS.

2. TLS protects data in transit.

3. Certificates authenticate endpoint identity.

4. Certificate contains a public key.

5. Private keys must remain protected.

6. Certificate authorities create a chain of trust.

7. SAN identifies additional certificate hostnames.

8. Wildcard must be leftmost.

9. *.example.com covers only one subdomain level.

10. *.example.com does not cover example.com.

11. ACM manages certificates for integrated AWS services.

12. DNS validation is usually the best automation choice.

13. Do not delete ACM DNS validation CNAME records.

14. ACM public certificates currently have a
    198-day validity period.

15. ACM starts public renewal roughly 45 days
    before expiration.

16. CloudFront ACM viewer certificates belong
    in us-east-1.

17. Regional ALB uses its Regional certificate.

18. Regional API Gateway uses same-Region ACM.

19. Edge-optimized API Gateway uses us-east-1 ACM.

20. ALB can use multiple certificates through SNI.

21. TLS policy and certificate are different controls.

22. mTLS authenticates both server and client.

23. Imported certificates are not automatically
    renewed by ACM.

24. Exportable ACM public certificates now exist.

25. Always test DNS, certificate, TLS and application
    layers separately.
```

The **most important architecture from this lesson** is:

```text
Browser
   │
   │ HTTPS
   ▼
CloudFront
   │
   │ ACM #1
   │ us-east-1
   │
   │ HTTPS to origin
   ▼
ALB
   │
   │ ACM #2
   │ application Region
   ▼
Application
```

Do not think:

```text
"One domain = one certificate everywhere."
```

Think:

```text
ONE TLS CONNECTION
=
ONE TLS TERMINATION POINT
=
certificate architecture for that connection
```

That will make CloudFront, ALB, API Gateway and hybrid HTTPS designs much easier to reason about.

---

# ✅ Lesson 31 Part 3 Complete

You now understand:

```text
✓ HTTP vs HTTPS
✓ TLS fundamentals
✓ symmetric vs asymmetric roles
✓ TLS handshake
✓ X.509 certificates
✓ public/private keys
✓ certificate authorities
✓ certificate chains
✓ SANs
✓ wildcard certificates
✓ wildcard limitations

✓ ACM
✓ public certificates
✓ private certificates
✓ AWS Private CA
✓ DNS validation
✓ email validation
✓ HTTP validation
✓ CAA
✓ Route 53 integration

✓ current 198-day ACM public cert lifetime
✓ 45-day renewal window
✓ automatic managed renewal
✓ renewal failures

✓ CloudFront certificate us-east-1 rule
✓ ALB certificates
✓ regional certificate architecture
✓ API Gateway Regional certificates
✓ API Gateway edge-optimized certificates

✓ TLS termination
✓ HTTPS to ALB targets
✓ backend TLS behavior
✓ SNI
✓ multiple ALB certificates
✓ TLS security policies
✓ TLS 1.2 / TLS 1.3
✓ RSA vs ECDSA

✓ mTLS
✓ ALB mTLS
✓ API Gateway mTLS
✓ trust stores

✓ imported certificates
✓ exportable public ACM certificates
✓ 2026 ACM behavior updates

✓ Terraform provider aliases
✓ Terraform DNS validation
✓ CloudFront + ALB dual-certificate architecture
✓ CLI/OpenSSL troubleshooting
✓ certificate renewal troubleshooting
✓ SAA-C03 production scenarios
```

# Next — Lesson 31 Part 4

# **GuardDuty, Security Hub, Inspector, Macie & AWS Threat Detection Architecture**

Now we move from:

```text
PROTECT
```

to:

```text
DETECT
```

The next architecture will be:

```text
                      AWS ORGANIZATION
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼

          GuardDuty      Inspector      Macie
              │             │             │
              ▼             ▼             ▼
          Threats      Vulnerability     Sensitive
         / anomalies      exposure         data
              │             │             │
              └─────────────┼─────────────┘
                            ▼
                       Security Hub
                            │
                            ▼
                   Central Findings
                            │
                            ▼
                       EventBridge
                            │
                ┌───────────┼───────────┐
                ▼           ▼           ▼
              SNS       Automation     SIEM
```

We’ll cover **GuardDuty data sources and findings, malware protection, EKS/ECS/S3/RDS protections, Inspector vulnerability scanning for EC2/ECR/Lambda, CVEs/CVSS, Macie sensitive-data discovery, Security Hub CSPM and finding aggregation, AWS Security Finding Format, delegated administrator multi-account design, EventBridge remediation, suppression vs remediation, Terraform, incident triage, and a full AWS security-operations capstone**.

[1]: https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html?utm_source=chatgpt.com "What is AWS Certificate Manager?"
[2]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html?utm_source=chatgpt.com "SSL certificates for your Application Load Balancer"
[3]: https://docs.aws.amazon.com/acm/latest/userguide/acm-concepts.html?utm_source=chatgpt.com "AWS Certificate Manager concepts"
[4]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/describe-ssl-policies.html?utm_source=chatgpt.com "Security policies for your Application Load Balancer"
[5]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html?utm_source=chatgpt.com "Requirements for using SSL/TLS certificates with CloudFront"
[6]: https://docs.aws.amazon.com/acm/latest/userguide/acm-public-certificates.html?utm_source=chatgpt.com "Request a public certificate in AWS Certificate Manager"
[7]: https://docs.aws.amazon.com/acm/latest/userguide/acm-certificate-characteristics.html?utm_source=chatgpt.com "AWS Certificate Manager public certificate characteristics ..."
[8]: https://docs.aws.amazon.com/acm/latest/userguide/acm-services.html?utm_source=chatgpt.com "Managed automation with integrated services"
[9]: https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html?utm_source=chatgpt.com "What is AWS Private CA? - AWS Private Certificate Authority"
[10]: https://docs.aws.amazon.com/acm/latest/userguide/domain-ownership-validation.html?utm_source=chatgpt.com "Validate domain ownership for AWS Certificate Manager ..."
[11]: https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html?utm_source=chatgpt.com "AWS Certificate Manager DNS validation"
[12]: https://docs.aws.amazon.com/acm/latest/userguide/dochistory.html?utm_source=chatgpt.com "Document history - AWS Certificate Manager"
[13]: https://docs.aws.amazon.com/acm/latest/userguide/email-validation.html?utm_source=chatgpt.com "AWS Certificate Manager email validation"
[14]: https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-cert-requests.html?utm_source=chatgpt.com "Troubleshoot certificate requests - AWS Certificate Manager"
[15]: https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-caa.html?utm_source=chatgpt.com "Certification Authority Authorization (CAA) problems"
[16]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-procedures.html?utm_source=chatgpt.com "Configure alternate domain names and HTTPS"
[17]: https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_ViewerCertificate.html?utm_source=chatgpt.com "ViewerCertificate - Amazon CloudFront"
[18]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html?utm_source=chatgpt.com "Create an HTTPS listener for your Application Load Balancer"
[19]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-integrations.html?utm_source=chatgpt.com "Integrations for your Application Load Balancer"
[20]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html?utm_source=chatgpt.com "Target groups for your Application Load Balancers"
[21]: https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html?utm_source=chatgpt.com "AWS Certificate Manager public certificates"
[22]: https://docs.aws.amazon.com/acm/latest/userguide/import-certificate-prerequisites.html?utm_source=chatgpt.com "Prerequisites for importing ACM certificates"
[23]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-custom-domains.html?utm_source=chatgpt.com "Custom domain name for public REST APIs in API Gateway"
[24]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-regional-api-custom-domain-migrate.html?utm_source=chatgpt.com "Migrate a custom domain name to a different API endpoint ..."
[25]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-edge-optimized-custom-domain-name.html?utm_source=chatgpt.com "Set up an edge-optimized custom domain name in API Gateway"
[26]: https://docs.aws.amazon.com/apigateway/latest/developerguide/rest-api-mutual-tls.html?utm_source=chatgpt.com "How to turn on mutual TLS authentication for your REST APIs ..."
[27]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/mutual-authentication.html?utm_source=chatgpt.com "Mutual authentication with TLS in Application Load Balancer"
[28]: https://docs.aws.amazon.com/cli/latest/reference/apigateway/create-domain-name.html?utm_source=chatgpt.com "create-domain-name"
[29]: https://docs.aws.amazon.com/acm/latest/userguide/acm-exportable-certificates.html?utm_source=chatgpt.com "AWS Certificate Manager exportable public certificates"
[30]: https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html?utm_source=chatgpt.com "Import certificates into AWS Certificate Manager"
[31]: https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html?utm_source=chatgpt.com "Managed certificate renewal in AWS Certificate Manager"
[32]: https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-renewal.html?utm_source=chatgpt.com "Troubleshoot managed certificate renewal"
[33]: https://docs.aws.amazon.com/acm/latest/userguide/supported-events.html?utm_source=chatgpt.com "Amazon EventBridge support for ACM - AWS Certificate ..."
[34]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate?utm_source=chatgpt.com "aws_acm_certificate | Resources | hashicorp/aws | Terraform"
[35]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation?utm_source=chatgpt.com "aws_acm_certificate_validation | Resources | hashicorp/aws"
[36]: https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-DNS-validation.html?utm_source=chatgpt.com "Troubleshoot DNS validation problems"
[37]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-specify-certificate-for-custom-domain-name.html?utm_source=chatgpt.com "Get certificates ready in AWS Certificate Manager"
