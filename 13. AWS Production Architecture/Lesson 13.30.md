# AWS Masterclass — Phase 3

# Lesson 29: AWS Certificate Manager, TLS and Production Certificate Architecture

## 1. Lesson objective

In this lesson, you will learn how to:

* Understand TLS, SSL, HTTPS and X.509 certificates.
* Understand public keys, private keys and certi([AWS Documentation][1]) using AWS Certificate Manager.
* Validate certificates using DNS or email.
* Use wildcard and Subject Alternative Name certificates correctly.
* Place certificates in the correct AWS Region.
* Configure certificates for CloudFront, ALB and NLB.
* Build end-to-end encrypted architectures.
* Understand certificate renewal and rotation.
* Import and export certificates.
* Build private PKI using AWS Private CA.
* Configure mutual TLS on an Application Load Balancer.
* Monitor certificate expiration.
* Troubleshoot common TLS and ACM failures.
* Deploy certificates using Terraform and the AWS CLI.

---

# 2. Production TLS architecture

A secure production request can have several separate TLS connections:

```text
                              User
                                |
                                | HTTPS
                                | Certificate in us-east-1
                                v
                         Amazon CloudFront
                                |
                                | HTTPS
                                | Origin certificate
                                v
                    Application Load Balancer
                         ap-south-1
                                |
                                | HTTP or HTTPS
                                v
                       EC2 / ECS / EKS
                                |
                                | TLS
                                v
                         RDS / ElastiCache
```

The certificates are not necessarily the same.

```text
Viewer → CloudFront:
CloudFront viewer certificate

CloudFront → ALB:
ALB server certificate

ALB → EC2:
Target-side certificate, when HTTPS is used

Application → RDS:
RDS server certificate
```

A CloudFront viewer certificate from ACM must be located in `us-east-1`. A certificate attached to a Regional Application Load Balancer must exist in the same Region as that load balancer. ([AWS Documentation][2]). What problem does TLS solve?

Without TLS:

```text
Browser
   |
   | Plain HTTP
   v
Application
```

An attacker positioned on the network may be able to:

* Read credentials.
* Read session cookies.
* Modify responses.
* Inject malicious code.
* Redirect traffic.
* Impersonate the server.

With TLS:

```text
Browser
   |
   | Encrypted and authenticated connection
   v
Application
```

TLS primarily provides:

```text
Confidentiality
Integrity
Authentication
```

## Confidentiality

The information is encrypted so that an observer cannot easily read it.

## Integrity

Changes made during transport can be detected.

## Server authentication

The client verifies that the server possesses the private key associated with a certificate issued for the requested domain.

---

# 4. SSL versus TLS

People commonly say:

```text
SSL certificate
```

but modern secure connections use TLS.

```text
SSL:
Older, obsolete protocol family

TLS:
Modern successor to SSL
```

The term “SSL certificate” remains common because it is widely recognized, but an AWS service such as an ALB uses X.509 server certificates to establish TLS connections. ([AWS Documentation][3]). HTTP versus HTTPS

## HTTP

```text
http://example.com
```

Typical port:

```text
80
```

Traffic is not protected by TLS.

## HTTPS

```text
https://example.com
```

Typical port:

```text
443
```

HTTPS means:

```text
HTTP carried inside a TLS connection
```

A common ALB design is:

```text
Listener 80:
Redirect to HTTPS

Listener 443:
Terminate TLS and forward to the application
```

---

# 6. Simplified TLS handshake

When a browser opens:

```text
https://api.yourdatascientist.tech
```

a simplified handshake is:

```text
1. Client connects to the server.

2. Client sends:
   - Supported TLS versions
   - Supported cipher suites
   - Requested hostname using SNI
   - Key-agreement information

3. Server sends:
   - Selected TLS settings
   - Server certificate
   - Certificate chain
   - Key-agreement information

4. Client validates:
   - Certificate is not expired
   - Domain name matches
   - Issuer is trusted
   - Certificate chain is valid
   - Signature is valid

5. Client and server derive session keys.

6. Encrypted application traffic begins.
```

The private key itself is not normally transmitted to the browser.

---

# 7. Public and private keys

A certificate is associated with a public-private key pair.

```text
Public key:
Can be shared

Private key:
Must remain secret
```

The certificate contains the public key and identity information.

The private key proves control of the certificate identity during the TLS handshake.

## Critical security rule

```text
A leaked certificate is usually public information.

A leaked private key is a security incident.
```

Anyone who obtains the private key may be able to impersonate the service, depending on where and how the key is usable.

---

# 8. What is inside a certificate?

An X.509 certificate commonly contains:

```text
Subject information
Subject Alternative Names
Public key
Issuer
Serial number
Validity period
Signature algorithm
Key usage
Extended key usage
CA digital signature
```

ALB documentation describes a server certificate as containing identification information, a validity period, a public key, a serial number and the issuer’s digital signature. ([AWS Documentation][3])a remote certificate:

```bash
openssl s_client \
  -connect api.yourdatascientist.tech:443 \
  -servername api.yourdatascientist.tech \
  </dev/null
```

Inspect the certificate details:

```bash
openssl s_client \
  -connect api.yourdatascientist.tech:443 \
  -servername api.yourdatascientist.tech \
  -showcerts </dev/null 2>/dev/null |
openssl x509 -noout -text
```

---

# 9. Certificate trust chain

A normal public certificate chain looks like:

```text
Trusted root CA
       |
       v
Intermediate CA
       |
       v
Leaf/server certificate
```

## Root CA

The highest authority in the hierarchy.

The root certificate is normally self-signed and is trusted through the client’s trust store.

## Intermediate CA

A CA whose certificate was signed by a parent CA.

It issues lower-level CA or server certificates.

## Leaf certificate

The certificate installed on CloudFront, an ALB, NLB or web server.

AWS Certificate Manager issues leaf or end-entity certificates through intermediate certificate authorities. ([AWS Documentation][4])se intermediate CAs?

If a leaf or intermediate certificate is compromised, it can be replaced without distributing a completely new root certificate to every client.

The root CA should normally be used rarely and protected more strictly than issuing CAs. ([AWS Documentation][5])0. What is AWS Certificate Manager?

AWS Certificate Manager, or ACM, manages X.509 certificates used by integrated AWS services.

ACM can:

* Issue public certificates.
* Issue private certificates through AWS Private CA.
* Store certificates.
* Import third-party certificates.
* Export eligible public or private certificates.
* Integrate certificates with AWS services.
* Manage renewal for eligible ACM-issued certificates.

ACM certificates can cover one domain, multiple specific domains, wildcard domains or a combination of those names. ([AWS Documentation][6])l model

```text
ACM:
Certificate lifecycle manager

Route 53:
Domain validation and DNS routing

CloudFront or ALB:
Uses the certificate to terminate TLS
```

---

# 11. ACM certificate types

You should distinguish four major categories:

```text
1. ACM-issued public certificate
2. ACM exportable public certificate
3. Imported certificate
4. ACM private certificate issued by AWS Private CA
```

---

# 12. ACM-issued public certificate

A normal ACM public certificate is trusted by ordinary browsers and public clients.

Suitable for:

```text
Public websites
Public APIs
CloudFront distributions
Internet-facing ALBs
Internet-facing NLB TLS listeners
API Gateway custom domains
```

Before ACM can issue the certificate, you must prove that you control every requested domain name.

Current ACM public certificate requests support RSA 2048, ECDSA P-256 and ECDSA P-384 key algorithms. Public ACM certificates are currently valid for **198 days**, and ACM begins the managed-renewal process **45 days before expiration**. ([AWS Documentation][1])3. Exportable ACM public certificates

ACM now supports public certificates that can be explicitly requested as exportable.

An exportable public certificate lets you retrieve:

```text
Certificate
Certificate chain
Encrypted private key
```

This is useful when deploying a public certificate to:

* Customer-managed EC2 web servers.
* On-premises systems.
* Kubernetes ingress controllers.
* Appliances.
* Infrastructure outside integrated AWS services.

ACM manages the renewal process for exportable certificates and notifies you when renewed certificate material is available, but external deployment must still retrieve and install the renewed material. ([AWS Documentation][7])ity warning

The ability to export a private key increases responsibility.

Protect exported private keys using:

* Strong passphrases.
* Restricted IAM permissions.
* Secrets-management systems.
* Encrypted deployment channels.
* Audit logging.
* Minimal human access.

---

# 14. Imported certificates

You can import a certificate issued by another CA into ACM.

You typically provide:

```text
Certificate body
Private key
Certificate chain
```

Use imported certificates when:

* Your organization has a required public CA.
* You already own a certificate.
* You need certificate characteristics ACM does not issue.
* You use an enterprise PKI.
* A vendor requires a specific issuer.

## Critical renewal difference

```text
ACM-issued certificate:
Eligible for ACM-managed renewal

Imported certificate:
Not automatically renewed by ACM
```

To renew an imported certificate, obtain a renewed certificate from the issuer and reimport it. Reimporting over the existing certificate preserves its ARN and existing AWS service associations. ([AWS Documentation][8])5. Private certificates

Private certificates are trusted only by systems that trust your private certificate authority.

Suitable for:

```text
Internal APIs
Service-to-service TLS
Corporate devices
Private ALBs
Internal applications
mTLS client certificates
Kubernetes workloads
IoT devices
VPN-related identity
```

Private certificates are not automatically trusted by public browsers.

You must distribute the private CA’s root certificate to the clients that should trust it.

AWS Private CA provides managed private CA hierarchies capable of issuing certificates for servers, users, devices, API endpoints and other private PKI identities. ([AWS Documentation][9])6. Domain validation

Before issuing a public certificate, ACM verifies that you control the domain.

Validation options include:

```text
DNS validation
Email validation
HTTP validation in specific CloudFront workflows
```

AWS recommends DNS validation for most ACM public certificate workflows. ([AWS Documentation][10])7. DNS validation

With DNS validation, ACM provides a CNAME record.

Example:

```dns
_abc123.api.yourdatascientist.tech.
CNAME
_xyz789.acm-validations.aws.
```

Flow:

```text
1. Request certificate.
2. ACM provides validation CNAME.
3. Add CNAME to authoritative DNS.
4. ACM queries DNS.
5. Domain ownership is validated.
6. Certificate is issued.
```

Keep the validation CNAME in DNS.

The record is used both for initial validation and future managed renewal. As long as the certificate remains eligible for renewal and the CNAME remains correct, ACM can revalidate ownership without additional action. ([AWS Documentation][11]) delete validation records casually

Deleting the CNAME may not immediately break the currently issued certificate.

However:

```text
Current certificate:
May continue working until expiration

Renewal:
May fail because ACM can no longer validate ownership
```

---

# 18. Route 53 validation

When DNS is hosted in Route 53, ACM can create the validation records for you through the console.

The automated flow is:

```text
ACM certificate request
        ↓
Create Route 53 validation records
        ↓
Route 53 publishes CNAME
        ↓
ACM validates domain
        ↓
Certificate becomes ISSUED
```

The Route 53 hosted zone must be the zone that is actually authoritative for the domain.

Creating the validation record in a duplicate or non-authoritative hosted zone does not validate the certificate.

Verify authoritative name servers:

```bash
dig NS yourdatascientist.tech
```

Verify validation:

```bash
dig CNAME \
  _validation-token.yourdatascientist.tech
```

---

# 19. Email validation

With email validation, ACM sends validation messages to approved domain contacts or common administrative addresses.

Examples can include:

```text
admin@example.com
administrator@example.com
hostmaster@example.com
postmaster@example.com
webmaster@example.com
```

A domain owner must approve the request.

Email-validated certificates require domain-owner action during renewal, and ACM begins sending renewal notices 45 days before expiration. ([AWS Documentation][12])NS validation is normally better

DNS validation is easier to automate and does not depend on a person finding and approving renewal messages before expiration.

Use email validation only when DNS records cannot be modified.

---

# 20. HTTP validation

ACM also supports HTTP-based domain validation in specific CloudFront distribution-tenant workflows.

In that workflow, CloudFront can use an HTTP redirect or a validation file on the existing origin to prove domain control.

HTTP validation is not the normal replacement for DNS validation in ordinary ACM certificate requests, and wildcard certificates require DNS or email validation rather than HTTP validation. ([AWS Documentation][13])1. Wildcard certificates

A wildcard certificate uses an asterisk in the leftmost label.

Example:

```text
*.yourdatascientist.tech
```

It covers:

```text
www.yourdatascientist.tech
api.yourdatascientist.tech
jenkins.yourdatascientist.tech
grafana.yourdatascientist.tech
```

It does not cover:

```text
yourdatascientist.tech
```

It also does not cover:

```text
api.dev.yourdatascientist.tech
```

A wildcard protects only one subdomain level. ([AWS Documentation][14])n certificate request

To protect both the apex and first-level subdomains, request:

```text
yourdatascientist.tech
*.yourdatascientist.tech
```

---

# 22. Subject Alternative Names

SAN stands for:

```text
Subject Alternative Name
```

A single certificate can contain several names:

```text
yourdatascientist.tech
www.yourdatascientist.tech
api.yourdatascientist.tech
static.yourdatascientist.tech
```

Modern certificate validation primarily relies on the SAN extension.

CloudFront requires every alternate domain name to be covered by an exact or valid wildcard SAN on the attached certificate. ([AWS Documentation][2])ersus separate certificates

Use one SAN certificate when:

* Domains share the same ownership and lifecycle.
* The same CloudFront distribution needs all names.
* Operational simplicity matters.

Use separate certificates when:

* Teams own different domains.
* Services require independent rotation.
* Compromise isolation matters.
* Certificate access should be separated.

---

# 23. Certificate Region placement

ACM certificates are Regional resources.

A certificate in one Region is not automatically usable in another Region. ([AWS Documentation][8])ment table

| AWS service                       | Certificate location                         |
| --------------------------------- | -------------------------------------------- |
| CloudFront viewer HTTPS           | `us-east-1`                                  |
| ALB HTTPS listener                | Same Region as ALB                           |
| NLB TLS listener                  | Same Region as NLB                           |
| Regional API Gateway domain       | Same Region as API                           |
| Edge-optimized API Gateway domain | `us-east-1`                                  |
| CloudFront origin ALB             | Same Region as origin ALB                    |
| Lambda@Edge-related certificate   | CloudFront viewer certificate in `us-east-1` |

## Your architecture

```text
CloudFront:
Certificate in us-east-1

ALB in Mumbai:
Certificate in ap-south-1
```

You may therefore request two ACM certificates for the same domain names in two different Regions.

---

# 24. CloudFront viewer certificate

For:

```text
https://yourdatascientist.tech
```

the browser establishes TLS with CloudFront.

The certificate must:

* Exist in ACM in `us-east-1`.
* Be issued or validly imported.
* Cover every CloudFront alternate domain name.
* Be attached to the distribution.
* Be trusted by public clients.
* Be unexpired.

CloudFront supports only one viewer certificate attached to a distribution at a time, although that certificate can contain multiple SANs or wildcard coverage. ([AWS Documentation][2])5. CloudFront-to-origin certificate

The connection from CloudFront to an HTTPS custom origin is a separate TLS connection.

```text
Viewer
   |
   | Certificate A
   v
CloudFront
   |
   | Certificate B
   v
Origin
```

When CloudFront connects to a custom origin over HTTPS, the certificate presented by the origin must match:

* The configured CloudFront origin domain, or
* The forwarded `Host` header when that header is intentionally forwarded.

If the names do not match, CloudFront returns `502 Bad Gateway`. ([AWS Documentation][2])le

CloudFront origin domain:

```text
origin.yourdatascientist.tech
```

The ALB certificate must contain:

```text
origin.yourdatascientist.tech
```

or an applicable wildcard such as:

```text
*.yourdatascientist.tech
```

---

# 26. Application Load Balancer TLS termination

An ALB HTTPS listener requires at least one server certificate.

```text
Client
   |
   | TLS encrypted
   v
ALB HTTPS listener
   |
   | Decrypted request
   v
Listener rules
   |
   v
Target group
```

The ALB:

1. Negotiates TLS with the client.
2. Presents the selected server certificate.
3. Decrypts the request.
4. Applies listener rules.
5. Forwards the request to a target.

An ALB secure listener requires both a certificate and an ELB security policy. ([AWS Documentation][15])7. Server Name Indication

SNI stands for:

```text
Server Name Indication
```

SNI lets a client specify the requested hostname during the TLS handshake.

This allows one ALB HTTPS listener to serve multiple domains:

```text
api.example.com
app.example.com
admin.example.com
```

Each domain can have a different certificate.

```text
Client requests api.example.com
        ↓
SNI hostname sent
        ↓
ALB selects matching certificate
```

ALB uses SNI-aware smart certificate selection. When multiple certificates match, it selects the best certificate supported by the client using criteria including key algorithm, expiration, hashing algorithm and key length. ([AWS Documentation][3])8. Default certificate and certificate list

An ALB HTTPS listener has:

```text
Default certificate
+
Optional certificate list
```

## Default certificate

Used when:

* The client does not support SNI.
* No hostname matches another certificate.
* It is selected as the best applicable certificate.

## Certificate list

Allows additional certificates for other hostnames.

Example:

```text
Default:
example.com

Certificate list:
api.example.com
admin.example.net
*.service.example.org
```

You can replace the default certificate or update the certificate list without recreating the load balancer. ([AWS Documentation][16])9. TLS security policy

The ALB security policy determines:

* Supported TLS versions.
* Supported cipher suites.
* Cipher preference.
* Compatibility with older clients.

Example conceptual choices:

```text
Modern policy:
TLS 1.3 and TLS 1.2

Compatibility policy:
May support older TLS versions
```

Use the newest AWS-managed policy compatible with your client population and compliance requirements.

ALBs use AWS-managed security policies rather than arbitrary custom cipher lists. ([AWS Documentation][16])t blindly support old clients

Older TLS versions and legacy cipher suites may introduce security weaknesses.

Test:

* Browsers.
* Mobile clients.
* Java runtimes.
* Embedded devices.
* Partner integrations.
* Monitoring tools.

before changing the policy.

---

# 30. End-to-end encryption

TLS termination at the ALB can be followed by either HTTP or HTTPS to targets.

## TLS termination with HTTP targets

```text
Client ──HTTPS──> ALB ──HTTP──> EC2
```

Advantages:

* Simpler target configuration.
* Lower certificate-management overhead.
* Traffic stays within controlled VPC networking.

## Re-encryption with HTTPS targets

```text
Client ──HTTPS──> ALB ──HTTPS──> EC2
```

Advantages:

* Encryption continues to the target.
* Useful for compliance requirements.
* Useful across connected or complex networks.
* Protects target-side transport.

## Important ALB behavior

When an ALB target group uses HTTPS, the ALB establishes TLS to the target but does **not** validate the target’s certificate. Self-signed or expired target certificates can therefore be used from the ALB’s perspective. ([AWS Documentation][17])ns HTTPS target groups provide encryption, but not ordinary CA-based target identity verification by the ALB.

---

# 31. Certificate renewal

Certificate renewal consists of two different stages:

```text
1. Issue renewed certificate material.
2. Deploy or associate the renewed certificate.
```

For certificates managed entirely through ACM and attached to integrated AWS services, ACM can handle both stages transparently.

Current ACM public certificates are valid for 198 days, and ACM checks renewal criteria beginning 45 days before expiration. ([AWS Documentation][1])alidated renewal requirements

For reliable managed renewal:

```text
Certificate must remain eligible.
Certificate should be associated with an integrated AWS service.
Validation CNAME must remain correct.
Certificate must still be in use.
```

Missing or incorrect DNS validation CNAMEs are a common cause of renewal failure. ([AWS Documentation][18])2. Why certificate pinning can break renewal

Certificate pinning makes an application trust a specific certificate or public key rather than the normal CA trust hierarchy.

ACM renewal can generate a new key pair.

Therefore:

```text
Application pins old public key
        ↓
ACM renews certificate with new key pair
        ↓
Application rejects renewed certificate
```

AWS recommends not pinning individual ACM-issued certificates because managed renewal can change the public key. ([AWS Documentation][19])ning is unavoidable, design it around an appropriate CA trust strategy and safe overlap rather than one short-lived leaf certificate.

---

# 33. Monitor renewal status

Useful ACM certificate statuses include:

```text
PENDING_VALIDATION
ISSUED
INACTIVE
EXPIRED
VALIDATION_TIMED_OUT
REVOKED
FAILED
```

Inspect a certificate:

```bash
aws acm describe-certificate \
  --certificate-arn "$CERTIFICATE_ARN" \
  --region us-east-1
```

Useful fields:

```text
Status
DomainName
SubjectAlternativeNames
NotBefore
NotAfter
InUseBy
RenewalEligibility
RenewalSummary
DomainValidationOptions
```

Query:

```bash
aws acm describe-certificate \
  --certificate-arn "$CERTIFICATE_ARN" \
  --region us-east-1 \
  --query 'Certificate.{
    Status:Status,
    NotAfter:NotAfter,
    RenewalEligibility:RenewalEligibility,
    InUseBy:InUseBy,
    Domains:SubjectAlternativeNames
  }'
```

---

# 34. ACM events and alerts

ACM can send AWS Health and EventBridge notifications when managed renewal encounters validation problems.

For DNS-validation failures, AWS documents notifications before expiration at intervals including:

```text
30 days
15 days
7 days
3 days
1 day
```

([AWS Documentation][20])tion workflow can be:

```text
ACM renewal event
        ↓
Amazon EventBridge
        ↓
SNS
        ↓
Email, Slack or incident platform
```

Do not depend only on someone manually checking the ACM console.

---

# 35. Request a certificate with AWS CLI

For CloudFront:

```bash
aws acm request-certificate \
  --domain-name yourdatascientist.tech \
  --subject-alternative-names "*.yourdatascientist.tech" \
  --validation-method DNS \
  --key-algorithm RSA_2048 \
  --region us-east-1 \
  --idempotency-token vivekcf2026
```

For an ALB in Mumbai:

```bash
aws acm request-certificate \
  --domain-name yourdatascientist.tech \
  --subject-alternative-names "*.yourdatascientist.tech" \
  --validation-method DNS \
  --key-algorithm RSA_2048 \
  --region ap-south-1 \
  --idempotency-token vivekalb26
```

The two certificates have separate ARNs because they exist in different Regions.

---

# 36. Retrieve validation records

```bash
aws acm describe-certificate \
  --certificate-arn "$CERTIFICATE_ARN" \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[*].{
    Domain:DomainName,
    Name:ResourceRecord.Name,
    Type:ResourceRecord.Type,
    Value:ResourceRecord.Value
  }' \
  --output table
```

Add the displayed records to the authoritative DNS zone.

Then monitor:

```bash
watch -n 15 "
aws acm describe-certificate \
  --certificate-arn '$CERTIFICATE_ARN' \
  --region us-east-1 \
  --query 'Certificate.Status' \
  --output text
"
```

Expected transition:

```text
PENDING_VALIDATION
        ↓
ISSUED
```

---

# 37. Terraform provider layout

For CloudFront and an ALB in `ap-south-1`:

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

Use:

```text
aws:
ALB and Regional certificate

aws.us_east_1:
CloudFront certificate
```

---

# 38. Terraform CloudFront certificate

```hcl
resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name = "yourdatascientist.tech"

  subject_alternative_names = [
    "*.yourdatascientist.tech"
  ]

  validation_method = "DNS"

  key_algorithm = "RSA_2048"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "yourdatascientist-tech-cloudfront"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

## Why `create_before_destroy`?

Certificate replacement should happen in this order:

```text
Create new certificate
        ↓
Validate new certificate
        ↓
Attach new certificate
        ↓
Remove old certificate
```

Not:

```text
Delete old certificate
        ↓
Create replacement
        ↓
Production outage
```

---

# 39. Terraform DNS validation records

```hcl
resource "aws_route53_record" "cloudfront_validation" {
  for_each = {
    for option in aws_acm_certificate.cloudfront.domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      type   = option.resource_record_type
      record = option.resource_record_value
    }
  }

  zone_id = aws_route53_zone.public.zone_id

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]

  ttl = 300

  allow_overwrite = true
}
```

Certificate validation:

```hcl
resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.cloudfront.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cloudfront_validation :
    record.fqdn
  ]
}
```

## Validation-record note

ACM can sometimes use the same validation CNAME for closely related names such as an apex and wildcard.

Review the Terraform plan and avoid managing identical Route 53 record sets through conflicting resources.

---

# 40. Attach certificate to CloudFront

```hcl
resource "aws_cloudfront_distribution" "site" {
  enabled = true

  aliases = [
    "yourdatascientist.tech",
    "www.yourdatascientist.tech"
  ]

  # Origins and cache behaviors omitted here.

  viewer_certificate {
    acm_certificate_arn = (
      aws_acm_certificate_validation.cloudfront.certificate_arn
    )

    ssl_support_method = "sni-only"

    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [
    aws_acm_certificate_validation.cloudfront
  ]
}
```

The aliases must be covered by the SANs in the certificate.

---

# 41. Terraform ALB certificate

```hcl
resource "aws_acm_certificate" "alb" {
  domain_name = "origin.yourdatascientist.tech"

  validation_method = "DNS"

  key_algorithm = "RSA_2048"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "production-alb-certificate"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

Validation:

```hcl
resource "aws_route53_record" "alb_validation" {
  for_each = {
    for option in aws_acm_certificate.alb.domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      type   = option.resource_record_type
      record = option.resource_record_value
    }
  }

  zone_id = aws_route53_zone.public.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn = aws_acm_certificate.alb.arn

  validation_record_fqdns = [
    for record in aws_route53_record.alb_validation :
    record.fqdn
  ]
}
```

---

# 42. Terraform ALB HTTPS listener

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.application.arn

  port     = 443
  protocol = "HTTPS"

  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  certificate_arn = (
    aws_acm_certificate_validation.alb.certificate_arn
  )

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }
}
```

HTTP-to-HTTPS redirect:

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.application.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}
```

---

# 43. Multiple ALB certificates

Add an additional SNI certificate:

```hcl
resource "aws_lb_listener_certificate" "additional" {
  listener_arn = aws_lb_listener.https.arn

  certificate_arn = (
    aws_acm_certificate_validation.additional.certificate_arn
  )
}
```

This allows the same ALB listener to support different domains.

Example:

```text
api.company-a.com
api.company-b.com
api.yourdatascientist.tech
```

---

# 44. Test TLS with `curl`

```bash
curl -Iv https://api.yourdatascientist.tech
```

Inspect:

```text
TLS version
Selected cipher
Server certificate
Certificate subject
Certificate issuer
Expiration date
Hostname validation
HTTP response
```

Force a specific TLS version:

```bash
curl -Iv \
  --tlsv1.2 \
  --tls-max 1.2 \
  https://api.yourdatascientist.tech
```

---

# 45. Test TLS with OpenSSL

```bash
openssl s_client \
  -connect api.yourdatascientist.tech:443 \
  -servername api.yourdatascientist.tech \
  -showcerts
```

The `-servername` argument sends SNI.

Without it, you may receive the ALB’s default certificate rather than the certificate for the hostname you intended to test.

Show expiration:

```bash
echo | openssl s_client \
  -connect api.yourdatascientist.tech:443 \
  -servername api.yourdatascientist.tech \
  2>/dev/null |
openssl x509 -noout -dates
```

Show SANs:

```bash
echo | openssl s_client \
  -connect api.yourdatascientist.tech:443 \
  -servername api.yourdatascientist.tech \
  2>/dev/null |
openssl x509 -noout -ext subjectAltName
```

Show issuer and subject:

```bash
echo | openssl s_client \
  -connect api.yourdatascientist.tech:443 \
  -servername api.yourdatascientist.tech \
  2>/dev/null |
openssl x509 -noout -subject -issuer -serial
```

---

# 46. Test the origin separately

CloudFront viewer endpoint:

```bash
curl -Iv https://www.yourdatascientist.tech
```

CloudFront origin endpoint:

```bash
curl -Iv https://origin.yourdatascientist.tech
```

This separates:

```text
Viewer → CloudFront TLS issue
```

from:

```text
CloudFront → origin TLS issue
```

If the CloudFront URL works using HTTP origin traffic but fails after changing the origin policy to HTTPS, inspect the origin certificate name and chain.

---

# 47. Troubleshooting: `PENDING_VALIDATION`

Possible causes:

```text
CNAME record not created
Record created in wrong hosted zone
Registrar points to different name servers
Validation record entered incorrectly
DNS provider appended the domain twice
CNAME flattening or proxying changed the record
Domain has restrictive CAA records
DNS propagation is incomplete
```

Check authoritative delegation:

```bash
dig NS yourdatascientist.tech
```

Check validation CNAME:

```bash
dig CNAME _token.yourdatascientist.tech
```

Query an authoritative name server directly:

```bash
dig @<authoritative-name-server> \
  CNAME _token.yourdatascientist.tech
```

An ACM certificate remains unavailable to an ALB while it is still pending validation. ([AWS Documentation][21])8. Troubleshooting: wildcard does not cover the apex

Certificate:

```text
*.yourdatascientist.tech
```

Request:

```text
https://yourdatascientist.tech
```

Result:

```text
Certificate name mismatch
```

Fix by requesting both:

```text
yourdatascientist.tech
*.yourdatascientist.tech
```

The wildcard applies only to the first-level subdomains, not the bare apex domain. ([AWS Documentation][14])9. Troubleshooting: deeper subdomain mismatch

Certificate:

```text
*.yourdatascientist.tech
```

Request:

```text
api.dev.yourdatascientist.tech
```

The certificate does not match.

Options:

```text
*.dev.yourdatascientist.tech
```

or:

```text
api.dev.yourdatascientist.tech
```

or a SAN certificate containing the exact hostname.

---

# 50. Troubleshooting: CloudFront cannot find certificate

Possible causes:

```text
Certificate is in ap-south-1 instead of us-east-1
Certificate is still pending validation
Certificate is expired
Certificate is in another AWS account
Certificate does not cover the alias
Wrong Terraform provider used
```

For CloudFront, request or import the viewer certificate in `us-east-1`. ([AWS Documentation][22])1. Troubleshooting: ALB cannot find certificate

Possible causes:

```text
Certificate is in us-east-1 but ALB is in ap-south-1
Certificate status is not ISSUED
Certificate belongs to another account
IAM permission prevents listing or attaching certificates
Certificate is not valid for use as a server certificate
```

ACM certificates are Regional. An ALB can use a certificate available in the load balancer’s Region. ([AWS Documentation][8])2. Troubleshooting: certificate-name mismatch

Symptoms:

```text
ERR_CERT_COMMON_NAME_INVALID
hostname mismatch
certificate is not valid for requested name
```

Check:

```bash
echo | openssl s_client \
  -connect api.yourdatascientist.tech:443 \
  -servername api.yourdatascientist.tech \
  2>/dev/null |
openssl x509 -noout -ext subjectAltName
```

Compare the SAN names with the requested hostname.

The match must be:

```text
Exact hostname
```

or:

```text
Valid wildcard at the correct level
```

---

# 53. Troubleshooting: incomplete certificate chain

Symptoms may include:

```text
Browser works on some devices but not others
Unable to get local issuer certificate
Unknown CA
Certificate chain incomplete
```

A third-party imported certificate should normally include the required intermediate chain in the correct order.

Conceptually:

```text
Server certificate
Intermediate CA 1
Intermediate CA 2
```

Do not normally provide the trusted root as though it were an intermediate.

Check:

```bash
openssl s_client \
  -connect api.example.com:443 \
  -servername api.example.com \
  -showcerts
```

---

# 54. Troubleshooting: private key mismatch

When importing a certificate, the private key must correspond to the public key in the certificate.

Check certificate public-key fingerprint:

```bash
openssl x509 \
  -in certificate.pem \
  -pubkey -noout |
openssl sha256
```

Check private-key public component:

```bash
openssl pkey \
  -in private-key.pem \
  -pubout |
openssl sha256
```

The hashes should match.

For RSA keys, another traditional comparison is:

```bash
openssl x509 -noout -modulus -in certificate.pem |
openssl sha256

openssl rsa -noout -modulus -in private-key.pem |
openssl sha256
```

---

# 55. Troubleshooting: certificate expired

Check:

```bash
echo | openssl s_client \
  -connect api.example.com:443 \
  -servername api.example.com \
  2>/dev/null |
openssl x509 -noout -dates
```

Possible reasons:

* Imported certificate was not manually renewed.
* DNS validation record was deleted.
* Certificate was not eligible for managed renewal.
* Email approval was missed.
* Renewed external certificate was not redeployed.
* Application still presents an old local certificate.
* Wrong certificate remains attached to the listener.

---

# 56. Troubleshooting: CloudFront 502 after enabling HTTPS origin

Common causes:

```text
Origin certificate does not match origin domain
Certificate chain is incomplete
Certificate is expired
Origin supports incompatible TLS settings
Origin listener is not configured for HTTPS
CloudFront connects to wrong origin port
```

CloudFront returns `502 Bad Gateway` when the origin certificate name does not match the configured origin name or applicable forwarded host. ([AWS Documentation][23])``bash
openssl s_client 
-connect origin.yourdatascientist.tech:443 
-servername origin.yourdatascientist.tech

````

---

# 57. Troubleshooting: renewal failed

For DNS-validated certificates, inspect:

```text
Validation CNAME still exists
CNAME value is unchanged
Domain is still delegated to correct DNS servers
Certificate is associated with an integrated service
Renewal eligibility is ELIGIBLE
CAA records allow issuance
````

ACM identifies missing or incorrect validation CNAME records as a common cause of DNS-renewal failure. ([AWS Documentation][18])```bash
aws acm describe-certificate 
--certificate-arn "$CERTIFICATE_ARN" 
--region "$REGION" 
--query 'Certificate.{
Status:Status,
Renewal:RenewalSummary,
Eligibility:RenewalEligibility,
InUseBy:InUseBy
}'

````

---

# 58. Imported-certificate rotation

Safe process:

```text
1. Obtain renewed certificate.
2. Validate certificate and chain locally.
3. Back up current material securely.
4. Reimport using the existing ACM certificate ARN.
5. Verify ACM details.
6. Test the endpoint.
7. Monitor handshake failures.
````

Reimporting to the same ARN preserves the existing association with services such as the ALB. ([AWS Documentation][8])

```bash
aws acm import-certificate \
  --certificate-arn "$EXISTING_CERTIFICATE_ARN" \
  --certificate fileb://certificate.pem \
  --private-key fileb://private-key.pem \
  --certificate-chain fileb://chain.pem \
  --region ap-south-1
```

---

# 59. Certificate rotation with zero downtime

For an ALB with SNI:

```text
1. Create and validate new certificate.
2. Add new certificate to listener certificate list.
3. Test using the intended hostname.
4. Make it the default when necessary.
5. Observe access logs and handshake metrics.
6. Remove old certificate after overlap period.
```

For CloudFront:

```text
1. Create and validate new certificate in us-east-1.
2. Update the distribution.
3. Wait for deployment status Deployed.
4. Test all alternate domains.
5. Remove old certificate only after confirmation.
```

Keep both old and new trust paths available where your platform supports overlap.

---

# 60. RSA versus ECDSA

## RSA

Advantages:

* Very broad client compatibility.
* Common enterprise default.
* Suitable for legacy client populations.

Example:

```text
RSA 2048
```

## ECDSA

Advantages:

* Smaller keys and signatures.
* Efficient TLS handshakes.
* Good modern-client support.

Examples:

```text
ECDSA P-256
ECDSA P-384
```

ACM public certificate requests currently support RSA 2048, ECDSA P-256 and ECDSA P-384. ([AWS Documentation][1])dvantage

An ALB can hold both RSA and ECDSA certificates for the same hostname and use its SNI smart-selection algorithm to choose a certificate supported by the client. ([AWS Documentation][3])1. Mutual TLS

Normal TLS authenticates the server to the client.

```text
Client verifies server certificate
```

Mutual TLS, or mTLS, authenticates both sides.

```text
Client verifies server certificate
Server verifies client certificate
```

Flow:

```text
Client presents client certificate
        ↓
ALB verifies certificate chain
        ↓
Trusted client is accepted
        ↓
Request reaches application
```

Use mTLS for:

* Partner APIs.
* Machine-to-machine services.
* Enterprise devices.
* High-security internal APIs.
* Industrial or IoT clients.
* APIs where possession of a client certificate is required.

An ALB can perform client-certificate authentication using a third-party CA or AWS Private CA trust chain. ([AWS Documentation][24])2. ALB mTLS modes

ALB supports two major mTLS modes:

```text
Verify mode
Passthrough mode
```

## Verify mode

The ALB validates the client certificate using a configured trust store.

```text
Client certificate
        ↓
ALB validates
        ↓
Trusted → forward request
Untrusted → reject TLS handshake
```

Verify mode requires:

* Trust store.
* CA certificate bundle.
* Optional certificate-revocation lists.
* Listener mTLS configuration.

## Passthrough mode

The ALB accepts the client certificate chain without verifying it and sends certificate information to the target using HTTP headers.

```text
Client certificate
        ↓
ALB does not verify
        ↓
Certificate chain forwarded in headers
        ↓
Application verifies and authorizes
```

ALB documentation distinguishes passthrough mode, where the target performs validation, from verify mode, where the ALB validates the X.509 client certificate. ([AWS Documentation][24])3. ALB trust store

A trust store contains CA certificates that the ALB trusts for client authentication.

Architecture:

```text
S3 CA bundle
     |
     v
ALB trust store
     |
     v
HTTPS listener in verify mode
```

Create a trust store:

```bash
aws elbv2 create-trust-store \
  --name partner-client-trust \
  --ca-certificates-bundle-s3-bucket production-mtls-trust \
  --ca-certificates-bundle-s3-key ca-bundle.pem \
  --region ap-south-1
```

The CA bundle is stored in S3 and referenced by the ELB trust-store resource. ([AWS Documentation][25])-store security

Protect:

* S3 bucket permissions.
* Object versioning.
* CA bundle modification rights.
* Trust-store update permissions.
* Revocation-list update permissions.
* CloudTrail logs.

Changing the trust store changes which client identities can connect.

---

# 64. Terraform ALB mTLS concept

```hcl
resource "aws_lb_trust_store" "client_ca" {
  name = "production-client-ca"

  ca_certificates_bundle_s3_bucket = (
    aws_s3_bucket.mtls_trust.id
  )

  ca_certificates_bundle_s3_key = (
    aws_s3_object.ca_bundle.key
  )
}
```

Listener concept:

```hcl
resource "aws_lb_listener" "mtls" {
  load_balancer_arn = aws_lb.application.arn

  port     = 443
  protocol = "HTTPS"

  certificate_arn = aws_acm_certificate.server.arn

  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  mutual_authentication {
    mode            = "verify"
    trust_store_arn = aws_lb_trust_store.client_ca.arn
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }
}
```

Verify provider-version support before using recently introduced resource arguments.

---

# 65. AWS Private CA hierarchy

A mature private PKI normally separates root and issuing functions.

```text
Offline or tightly controlled root CA
             |
             v
      Subordinate issuing CA
             |
             ├── Server certificates
             ├── Client certificates
             ├── Device certificates
             └── Workload certificates
```

AWS Private CA supports root and subordinate CA hierarchies, including multiple subordinate levels. ([AWS Documentation][26])mended hierarchy

```text
Root CA:
Used rarely

Issuing subordinate CA:
Used for normal certificate issuance
```

Compromise of the root affects trust in the entire hierarchy, so the root should have the strongest security controls and limited use. ([AWS Documentation][5])6. Private-certificate issuance

After creating an AWS Private CA, request a private certificate through ACM:

```bash
aws acm request-certificate \
  --domain-name service.internal.yourdatascientist.tech \
  --certificate-authority-arn "$PRIVATE_CA_ARN" \
  --key-algorithm RSA_2048 \
  --region ap-south-1
```

Private certificates requested through ACM can be integrated with supported AWS services.

Private end-entity certificates can also be issued directly through AWS Private CA when you need greater control over certificate templates or validity periods. ([AWS Documentation][27])7. Private certificate export

An ACM private certificate can be exported with its encrypted private key.

```bash
aws acm export-certificate \
  --certificate-arn "$PRIVATE_CERTIFICATE_ARN" \
  --passphrase fileb://passphrase.bin \
  --region ap-south-1
```

This allows deployment to:

* Nginx.
* Apache.
* Kubernetes.
* On-premises servers.
* Appliances.
* Client devices.

ACM supports exporting private certificates and their encrypted private keys. ([AWS Documentation][28])8. Certificate revocation

When a certificate or private key is compromised:

```text
1. Stop using the certificate.
2. Replace or rotate it.
3. Revoke it where supported.
4. Publish updated revocation information.
5. Update trust stores.
6. Investigate how compromise occurred.
```

Private PKI revocation mechanisms can include:

```text
Certificate Revocation Lists
Online Certificate Status Protocol
Short certificate validity
Trust-store removal
```

A revocation strategy must include how quickly clients receive updated revocation information.

---

# 69. Certificate Transparency

Publicly trusted certificate authorities normally publish issued public certificates into Certificate Transparency logs.

This helps domain owners and security teams discover unexpected certificates issued for their domains.

Operationally:

```text
Monitor:
yourdatascientist.tech
*.yourdatascientist.tech

Alert:
Unexpected public certificate detected
```

Certificate Transparency logs do not reveal the certificate’s private key, but they make public certificate issuance visible.

---

# 70. Certificate inventory

Maintain an inventory including:

| Field            | Example                     |
| ---------------- | --------------------------- |
| Certificate ARN  | `arn:aws:acm:...`           |
| Domain names     | Apex and wildcard           |
| Type             | Public, private or imported |
| Region           | `us-east-1`                 |
| Service          | CloudFront                  |
| Expiration       | Exact date                  |
| Validation       | DNS                         |
| Renewal          | Managed or manual           |
| Owner            | Platform team               |
| Environment      | Production                  |
| Rotation runbook | Link or identifier          |

List certificates:

```bash
aws acm list-certificates \
  --region us-east-1
```

Include additional statuses:

```bash
aws acm list-certificates \
  --certificate-statuses \
    ISSUED \
    PENDING_VALIDATION \
    EXPIRED \
    FAILED \
  --region us-east-1
```

Repeat for every AWS Region in which certificates may exist.

---

# 71. Certificate migration strategy

When migrating from manually managed Nginx certificates to ALB and ACM:

```text
1. Inventory existing domains and certificates.
2. Request equivalent ACM certificates.
3. Add all required SANs.
4. Complete DNS validation.
5. Create ALB HTTPS listener.
6. Test with ALB DNS and Host header.
7. Update Route 53.
8. Keep old endpoint available.
9. Monitor TLS and HTTP errors.
10. Remove old certificate after successful cutover.
```

Test the ALB before DNS cutover:

```bash
curl -Iv \
  --resolve api.example.com:443:<ALB_IP_FOR_TESTING> \
  https://api.example.com/
```

Because ALB IPs can change, use this only for temporary diagnostics, not permanent configuration.

---

# 72. Production certificate-security practices

```text
[ ] Use DNS validation where possible
[ ] Keep ACM validation CNAMEs in DNS
[ ] Use separate providers for CloudFront and Regional resources
[ ] Enable create_before_destroy in Terraform
[ ] Never commit private keys
[ ] Restrict acm:ExportCertificate
[ ] Restrict acm:ImportCertificate
[ ] Restrict listener-certificate changes
[ ] Monitor ACM renewal events
[ ] Monitor certificate expiration independently
[ ] Use a modern TLS security policy
[ ] Redirect HTTP to HTTPS
[ ] Protect private CA root permissions
[ ] Use subordinate CAs for normal issuance
[ ] Rotate compromised certificates immediately
[ ] Test the complete certificate chain
[ ] Test exact hostname matching
[ ] Maintain certificate ownership metadata
[ ] Document imported-certificate renewal
[ ] Test mTLS trust-store changes
[ ] Protect CA bundles in S3
```

---

# 73. Production checklist

```text
[ ] CloudFront certificate is in us-east-1
[ ] ALB certificate is in the ALB Region
[ ] Certificate status is ISSUED
[ ] Apex domain is explicitly covered
[ ] Wildcard coverage is at correct level
[ ] Every SAN is intentional
[ ] Route 53 validation records remain present
[ ] CloudFront aliases match certificate SANs
[ ] Origin certificate matches CloudFront origin domain
[ ] HTTP is redirected or rejected
[ ] TLS 1.2 or newer is used where possible
[ ] ALB security policy is reviewed
[ ] Certificate renewal eligibility is monitored
[ ] EventBridge renewal alerts are configured
[ ] Imported certificates have manual renewal automation
[ ] Exportable certificate deployment is automated
[ ] Private keys are not written to CI logs
[ ] Terraform state access is restricted
[ ] Certificate rotation is tested
[ ] mTLS trust store is protected
[ ] CA revocation process is documented
[ ] Certificate inventory is maintained
[ ] Emergency replacement procedure exists
```

---

# 74. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
ACM provisions and manages TLS certificates.

TLS encrypts network traffic.

CloudFront and ALB can use ACM certificates.
```

## Solutions Architect Associate

Understand:

```text
DNS validation
Wildcard limitations
CloudFront certificate in us-east-1
ALB certificate in the ALB Region
TLS termination
SNI
Certificate renewal
Public versus private certificates
```

## DevOps Engineer Professional

Understand:

```text
Terraform provider aliases
Automated validation
Renewal monitoring
Imported-certificate rotation
Certificate replacement
EventBridge alerts
Private CA hierarchy
mTLS
Trust-store deployment
End-to-end encryption
Incident response for leaked keys
```

---

# 75. Interview questions

## Question 1: What is AWS Certificate Manager?

**Answer:**

ACM is an AWS service for requesting, storing, importing, exporting and renewing eligible X.509 certificates used with AWS-integrated services and other supported workloads.

## Question 2: Why must a CloudFront certificate be in `us-east-1`?

**Answer:**

CloudFront is a global service and requires ACM viewer certificates to be requested or imported in the US East, North Virginia Region.

## Question 3: Where should an ALB certificate be created?

**Answer:**

It must be in the same AWS Region as the ALB.

## Question 4: Does `*.example.com` cover `example.com`?

**Answer:**

No. The apex domain must be listed separately.

## Question 5: Does `*.example.com` cover `api.dev.example.com`?

**Answer:**

No. A wildcard covers only one subdomain level.

## Question 6: What is DNS validation?

**Answer:**

ACM provides a CNAME record that you publish in authoritative DNS. The record proves control of the requested domain and supports future managed renewal.

## Question 7: Why should the DNS validation CNAME remain in place?

**Answer:**

ACM can use it to revalidate domain control during managed certificate renewal.

## Question 8: What is SNI?

**Answer:**

SNI lets the client send the requested hostname during the TLS handshake, allowing one load-balancer listener to select among certificates for multiple domains.

## Question 9: What is the difference between public and private certificates?

**Answer:**

A public certificate is trusted by ordinary public clients through public CA trust stores. A private certificate is trusted only by clients configured to trust the organization’s private CA.

## Question 10: Does ACM renew imported certificates?

**Answer:**

No. Imported certificates must be renewed through their original issuer and reimported into ACM.

## Question 11: Can ACM public certificates be exported?

**Answer:**

Yes, when they are specifically requested as exportable public certificates. The private key must then be handled and deployed securely.

## Question 12: What happens when an ALB terminates TLS?

**Answer:**

The ALB presents its server certificate, negotiates TLS with the client, decrypts the request, applies listener rules and forwards the request to a target.

## Question 13: Does an ALB validate certificates on HTTPS targets?

**Answer:**

No. It establishes an encrypted TLS connection but does not validate the target certificate.

## Question 14: What is mTLS?

**Answer:**

Mutual TLS authenticates both server and client using certificates.

## Question 15: What is the difference between ALB mTLS verify and passthrough modes?

**Answer:**

In verify mode, the ALB validates the client certificate against a trust store. In passthrough mode, the ALB forwards client-certificate information to the application, which performs validation.

---

# 76. Never-forget revision

```text
TLS:
Encrypts and authenticates a network connection.

Certificate:
Binds a public key to an identity.

Private key:
Secret proof of certificate control.

Public key:
Shared cryptographic key inside the certificate.

CA:
Authority that signs certificates.

Root CA:
Top trust anchor.

Intermediate CA:
Issues lower-level certificates.

Leaf certificate:
Certificate used by the server or client.

ACM:
AWS certificate lifecycle manager.

DNS validation:
CNAME proving domain control.

Wildcard:
Covers one subdomain level.

SAN:
List of hostnames covered by the certificate.

SNI:
Hostname sent during TLS negotiation.

CloudFront certificate:
Must be in us-east-1.

ALB certificate:
Must be in the ALB Region.

Imported certificate:
No ACM-managed renewal.

Private certificate:
Trusted only by configured private-PKI clients.

mTLS:
Both client and server present certificates.

Trust store:
CA bundle used to validate client certificates.
```

## One-line memory trick

```text
Route 53 proves domain control.
ACM issues the certificate.
CloudFront or ALB presents it.
TLS protects the connection.
DNS CNAME keeps renewal working.
```

## Lesson 29 outcome

You can now design certificate architecture where:

```text
User connects to CloudFront
    → Certificate from us-east-1 is presented.

CloudFront connects to ALB
    → Regional origin certificate is validated.

ALB serves several domains
    → SNI selects the correct certificate.

ACM certificate approaches expiration
    → Managed renewal begins automatically.

External certificate expires soon
    → Renewed certificate is reimported to the same ARN.

Partner API requires strong machine identity
    → ALB mTLS verifies a client certificate.

Internal services need private trust
    → AWS Private CA issues private certificates.
```

**Next lesson: Lesson 30 — AWS WAF, Shield, DDoS protection, managed rule groups, rate limiting, bot control, CAPTCHA, logging and production web-security architecture.**

[1]: https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html?utm_source=chatgpt.com "AWS Certificate Manager public certificates"
[2]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html?utm_source=chatgpt.com "Requirements for using SSL/TLS certificates with CloudFront"
[3]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html?utm_source=chatgpt.com "SSL certificates for your Application Load Balancer"
[4]: https://docs.aws.amazon.com/privateca/latest/userguide/PcaTerms.html?utm_source=chatgpt.com "Terms and concepts for AWS Private CA"
[5]: https://docs.aws.amazon.com/privateca/latest/userguide/ca-best-practices.html?utm_source=chatgpt.com "AWS Private CA best practices"
[6]: https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html?utm_source=chatgpt.com "What is AWS Certificate Manager?"
[7]: https://docs.aws.amazon.com/acm/latest/userguide/export-public-certificate.html?utm_source=chatgpt.com "Export an AWS Certificate Manager public certificate"
[8]: https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html?utm_source=chatgpt.com "Import certificates into AWS Certificate Manager"
[9]: https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html?utm_source=chatgpt.com "What is AWS Private CA? - AWS Private Certificate Authority"
[10]: https://docs.aws.amazon.com/acm/latest/userguide/certificate-validation.html?utm_source=chatgpt.com "Troubleshoot certificate validation"
[11]: https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html?utm_source=chatgpt.com "AWS Certificate Manager DNS validation"
[12]: https://docs.aws.amazon.com/acm/latest/userguide/domain-ownership-validation.html?utm_source=chatgpt.com "Validate domain ownership for AWS Certificate Manager ..."
[13]: https://docs.aws.amazon.com/acm/latest/userguide/acm-certificate-characteristics.html?utm_source=chatgpt.com "AWS Certificate Manager public certificate characteristics ..."
[14]: https://docs.aws.amazon.com/acm/latest/userguide/acm-concepts.html?utm_source=chatgpt.com "AWS Certificate Manager concepts"
[15]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html?utm_source=chatgpt.com "Create an HTTPS listener for your Application Load Balancer"
[16]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-certificates.html?utm_source=chatgpt.com "Update an HTTPS listener for your Application Load Balancer"
[17]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html?utm_source=chatgpt.com "Target groups for your Application Load Balancers"
[18]: https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-renewal.html?utm_source=chatgpt.com "Troubleshoot managed certificate renewal"
[19]: https://docs.aws.amazon.com/acm/latest/userguide/acm-bestpractices.html?utm_source=chatgpt.com "Best practices - AWS Certificate Manager"
[20]: https://docs.aws.amazon.com/acm/latest/userguide/dns-renewal-validation.html?utm_source=chatgpt.com "Renewal for domains validated by DNS"
[21]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-troubleshooting.html?utm_source=chatgpt.com "Troubleshoot your Application Load Balancers"
[22]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-procedures.html?utm_source=chatgpt.com "Configure alternate domain names and HTTPS"
[23]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistValuesOrigin.html?utm_source=chatgpt.com "Origin settings - Amazon CloudFront"
[24]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/mutual-authentication.html?utm_source=chatgpt.com "Mutual authentication with TLS in Application Load Balancer"
[25]: https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_CreateTrustStore.html?utm_source=chatgpt.com "CreateTrustStore - Elastic Load Balancing"
[26]: https://docs.aws.amazon.com/privateca/latest/userguide/ca-hierarchy.html?utm_source=chatgpt.com "Design a CA hierarchy - AWS Private Certificate Authority"
[27]: https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-private.html?utm_source=chatgpt.com "Request a private certificate in AWS Certificate Manager"
[28]: https://docs.aws.amazon.com/acm/latest/userguide/export-private.html?utm_source=chatgpt.com "Export an AWS Certificate Manager private certificate"
