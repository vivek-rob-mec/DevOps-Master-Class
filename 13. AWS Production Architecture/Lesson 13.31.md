# AWS Masterclass — Phase 3

# Lesson 30: AWS WAF, Shield and Production DDoS Protection

## 1. Lesson objectives

In this lesson, you will learn how to:

* Understand network, transport and application-layer attacks.
* Distinguish AWS WAF, Shield Standard and Shield Advanced.
* Build a Web ACL and associate it with CloudFront or an ALB.
* Use AWS Managed Rules safely.
* Write custom URI, header, IP, geographic and rate-limiting rules.
* Use `Count`, `Block`, `Allow`, `CAPTCHA` and `Challenge`.
* Detect and control malicious bots.
* Protect login and account-registration endpoints.
* Avoid WAF false positives.
* Understand body-inspection and oversized-request limits.
* Configure WAF logs, metrics and alarms.
* Protect the origin from direct access.
* Automate WAF deployment with Terraform.
* Respond to an active DDoS or application-layer attack.

---

# 2. Production security architecture

A common public application architecture is:

```text
                                Internet
                                    |
                         Layer 3/4 DDoS traffic
                                    |
                                    v
                          AWS Shield Standard
                                    |
                                    v
                              Route 53
                                    |
                                    v
                              CloudFront
                                    |
                              AWS Shield
                                    |
                                    v
                             AWS WAF Web ACL
                          /       |        \
                      Allow     Challenge   Block
                                    |
                                    v
                          Application Load Balancer
                                    |
                            Target group health
                                    |
                                    v
                         EC2 Auto Scaling Group
                           /                \
                       RDS                  Cache
```

For higher-risk workloads:

```text
CloudFront / Route 53 / ALB / Global Accelerator
                         |
                         v
                 Shield Advanced
                         |
           Advanced detection and mitigation
                         |
        Automatic application-layer mitigation
                         |
              Shield Response Team support
                         |
                  DDoS cost protection
```

AWS WAF examines HTTP and HTTPS requests sent to supported resources. Shield Standard is automatically available to AWS customers and protects against common network and transport-layer DDoS attacks, while Shield Advanced adds enhanced detection, response capabilities and additional protection options. ([AWS Documentation][1])

---

# 3. First mental model: WAF versus Shield

## AWS WAF

AWS WAF is a **web application firewall**.

It answers:

```text
Should this individual HTTP request be allowed?
```

It can inspect:

```text
Source IP
Country
URI path
Query strings
Headers
Cookies
HTTP method
Request body
JSON body
Request rate
Known attack patterns
Bot signals
Authentication behavior
```

## AWS Shield

AWS Shield is primarily a **DDoS protection service**.

It answers:

```text
Is a large-scale attack attempting to exhaust
the network, transport or application resources?
```

## Simple distinction

```text
AWS WAF:
Request-level filtering

AWS Shield:
DDoS detection and mitigation
```

## Security-layer relationship

```text
Shield
  ↓
Protects service availability against DDoS

WAF
  ↓
Filters HTTP requests

Application security
  ↓
Validates authentication, authorization and business logic
```

WAF cannot repair insecure application code, and Shield cannot determine whether an authenticated user should be allowed to access another customer’s invoice.

---

# 4. What is a DDoS attack?

DDoS stands for:

```text
Distributed Denial of Service
```

The attacker uses many distributed systems to send enough traffic or work to make a service unavailable.

```text
Compromised device 1 ─┐
Compromised device 2 ─┤
Compromised device 3 ─┼──> Your application
Compromised device 4 ─┤
Compromised device N ─┘
```

The goal may be to exhaust:

* Network bandwidth.
* Connection tables.
* CPU.
* Memory.
* Application worker threads.
* Database connections.
* Expensive API operations.
* Third-party API quotas.
* Autoscaling budgets.

---

# 5. Attack layers

## Layer 3: Network layer

Example attack categories:

```text
Large packet floods
IP-level traffic exhaustion
```

The attacker attempts to consume network capacity.

## Layer 4: Transport layer

Example categories:

```text
TCP SYN floods
UDP floods
Connection exhaustion
```

The attack targets TCP, UDP or connection-handling infrastructure.

## Layer 7: Application layer

Example:

```http
GET /api/search?q=expensive-query
```

The request may look like legitimate HTTP but be repeated at enormous scale.

Other examples:

```text
Repeated login attempts
Credential stuffing
Large search queries
Repeated report generation
Cart abuse
Scraping
Inventory hoarding
Expensive GraphQL queries
```

Shield Standard and Shield Advanced provide DDoS protections across network and transport layers, while application-layer DDoS protection commonly combines Shield Advanced capabilities with AWS WAF request filtering. ([AWS Documentation][2])

---

# 6. What resources can AWS WAF protect?

AWS WAF currently supports resources including:

```text
Amazon CloudFront distributions
Application Load Balancers
Amazon API Gateway REST APIs
AWS AppSync GraphQL APIs
Amazon Cognito user pools
AWS App Runner services
AWS Verified Access instances
AWS Amplify
Amazon Bedrock AgentCore Gateway
```

A Web ACL is associated with a supported resource, and AWS WAF evaluates requests before they reach the protected application. ([AWS Documentation][1])

---

# 7. What is a Web ACL?

Web ACL stands for:

```text
Web Access Control List
```

Newer AWS console and documentation language may also describe it as a:

```text
Protection pack
```

The API and Terraform resource still use names such as:

```text
WebACL
aws_wafv2_web_acl
```

A Web ACL contains:

```text
Default action
Ordered rules
Managed rule groups
Custom rule groups
Visibility configuration
Logging configuration
Associated resources
Body inspection settings
```

## Example

```text
Web ACL: production-cloudfront-waf

Priority 10:
Block explicitly denied IPs

Priority 20:
AWS IP reputation rules

Priority 30:
AWS common attack protections

Priority 40:
Rate limit login endpoint

Priority 50:
Challenge suspicious bots

Priority 60:
Allow trusted monitoring

Default:
Allow
```

---

# 8. Web ACL scope and Region

AWS WAF has two scopes:

```text
CLOUDFRONT
REGIONAL
```

## CloudFront scope

For CloudFront:

```hcl
scope = "CLOUDFRONT"
```

CloudFront Web ACL resources are handled in:

```text
us-east-1
```

## Regional scope

For an ALB, Regional API Gateway API or another Regional resource:

```hcl
scope = "REGIONAL"
```

The Web ACL must exist in the same Region as the protected resource.

```text
ALB in ap-south-1
    ↓
REGIONAL WAF Web ACL in ap-south-1
```

A CloudFront Web ACL has the global scope represented through `us-east-1`, while Regional resources use Regional Web ACLs. Each protected resource can have only one Web ACL, although one Web ACL may protect multiple eligible resources subject to association restrictions. ([AWS Documentation][3])

---

# 9. One WAF at CloudFront or one at ALB?

Consider:

```text
User
  ↓
CloudFront
  ↓
ALB
  ↓
Application
```

You could associate WAF with:

```text
CloudFront
```

or:

```text
ALB
```

or use carefully designed controls at both layers with separate Web ACLs.

## WAF at CloudFront

Advantages:

* Requests filtered near the edge.
* Malicious traffic may never reach the Region.
* Protects S3 and ALB origins behind the distribution.
* Useful for global applications.
* Integrates naturally with edge rate limiting and bot protection.

## WAF at ALB

Advantages:

* Protects the Regional ALB directly.
* Useful when users access the ALB without CloudFront.
* Can apply Regional application-specific controls.
* Useful for internal or Regional-only applications.

## Recommended public architecture

```text
Internet
   ↓
CloudFront + WAF
   ↓
Restricted ALB origin
```

If direct ALB access remains available, an attacker may bypass the CloudFront WAF.

Therefore, CloudFront protection should normally be combined with origin-access restrictions.

---

# 10. Default action

Every Web ACL requires a default action.

Typical options:

```text
Allow
Block
```

## Default allow

```text
Evaluate rules
    ↓
If no rule blocks the request
    ↓
Allow it
```

Common for public applications:

```text
Default action: Allow

Rules:
Block known threats
Block denied IPs
Rate limit abuse
Challenge suspicious clients
```

## Default block

```text
Evaluate rules
    ↓
If no rule explicitly allows the request
    ↓
Block it
```

Suitable for strict allowlist systems:

```text
Internal administration API
Known partner CIDRs
Machine-to-machine API
Private corporate service
```

### Production warning

A default-block Web ACL can cause a complete outage when a required client, health checker or API path is not explicitly allowed.

---

# 11. Rule priorities

AWS WAF evaluates rules in priority order.

```text
Lower priority number
        ↓
Evaluated earlier
```

Example:

| Priority | Rule                         |
| -------: | ---------------------------- |
|        0 | Trusted monitoring allowlist |
|       10 | Emergency IP block           |
|       20 | Rate-limit login             |
|       30 | IP reputation group          |
|       40 | Common managed protections   |
|       50 | Bot challenge                |

The first terminating match generally ends Web ACL evaluation.

This means priority changes behavior.

## Example problem

```text
Priority 10:
Allow corporate IP

Priority 20:
Block /admin
```

A request from the corporate IP may be allowed before the later block rule is evaluated.

## Better question

Do you intend:

```text
Corporate IP may access everything
```

or:

```text
Corporate IP is trusted only for selected admin paths
```

Rule order must represent the actual business policy.

---

# 12. Rule actions

AWS WAF rule actions include:

```text
Allow
Block
Count
CAPTCHA
Challenge
```

## Allow

Allows the matching request and normally stops evaluation.

## Block

Blocks the request and normally stops evaluation.

## Count

Records the match and continues evaluating later rules.

Use Count for:

* Testing.
* False-positive analysis.
* Traffic discovery.
* New managed-rule rollout.
* Measuring attack volume.

## CAPTCHA

Presents a human-interaction puzzle when token requirements are not satisfied.

## Challenge

Uses a silent browser challenge rather than an explicit visual puzzle when possible.

`Count` is non-terminating. `CAPTCHA` and `Challenge` can act as non-terminating or terminating actions depending on whether the request has a valid token. AWS charges additional fees for CAPTCHA and Challenge use. ([AWS Documentation][4])

---

# 13. The safest WAF deployment method

Never start with:

```text
New managed rules
    ↓
Immediately block production traffic
```

Use:

```text
1. Deploy to a test environment.
2. Run tests.
3. Deploy to production in Count mode.
4. Enable WAF logs.
5. Review legitimate matches.
6. Add exclusions or scope-down logic.
7. Enable blocking gradually.
8. Monitor errors and support reports.
```

AWS explicitly recommends testing and tuning rules before production enforcement, including the use of Count mode against production traffic before enabling blocking. ([AWS Documentation][5])

---

# 14. Rule statements

A statement defines what a rule matches.

Common statement types include:

```text
IP set match
Geographic match
String or byte match
Regular-expression match
SQL injection match
Cross-site scripting match
Size constraint
Rate-based statement
Managed rule group
Custom rule group
Label match
Logical AND, OR and NOT
```

## Conceptual rule

```text
IF
    path begins with /api/login
AND
    source country is not expected
AND
    request rate is excessive
THEN
    Challenge or Block
```

---

# 15. IP sets

An IP set stores IPv4 or IPv6 CIDR ranges.

Example:

```text
203.0.113.10/32
198.51.100.0/24
2001:db8::/32
```

Use IP sets for:

* Trusted office networks.
* Partner allowlists.
* Known attacker blocklists.
* Security scanner addresses.
* Monitoring service CIDRs.
* Emergency incident blocking.

## Do not place large IP lists directly into many rules

Create one reusable IP set:

```text
production-trusted-partners
```

Then reference it from Web ACL rules.

---

# 16. Allowlisting trusted IPs

Example policy:

```text
IF source IP is in trusted_admin_ips
AND URI begins with /admin
THEN allow
```

Do not write:

```text
IF source IP is trusted
THEN allow everything
```

unless that is truly intended.

A safer design combines:

```text
IP address
+
URI path
+
HTTP method
+
Authentication
```

WAF allowlisting is an additional control, not a replacement for application authentication.

---

# 17. Client IP and forwarded headers

The source IP visible to WAF depends on the protected resource and proxy chain.

For some architectures, the actual client address is carried in:

```http
X-Forwarded-For: client-ip, proxy-1, proxy-2
```

AWS WAF can be configured to use a forwarded-IP header for applicable IP and rate-based matching. You must also define fallback behavior for missing or invalid forwarded addresses. ([AWS Documentation][6])

## Security warning

Never blindly trust a client-supplied forwarded-IP header.

If an untrusted client can directly set:

```http
X-Forwarded-For: 203.0.113.10
```

it may impersonate a trusted source.

Only use a forwarded header when:

* A trusted proxy reliably sets or normalizes it.
* Direct origin access is blocked.
* You understand which address position represents the real client.
* Spoofed values are removed or overwritten.

---

# 18. Geographic match rules

A geographic match rule identifies requests based on source country.

Example:

```text
Allow:
India
Singapore
United States

Challenge:
All other countries
```

Use cases:

* Region-specific services.
* Licensing restrictions.
* High-risk administrative endpoints.
* Traffic analysis.
* Challenge instead of immediate blocking.

## Limitation

Geolocation is based on IP mapping.

It can be affected by:

* VPNs.
* Corporate egress gateways.
* Mobile carriers.
* Proxy services.
* Incorrect location databases.

Do not use country alone as a strong identity check.

---

# 19. String and URI matching

Example:

```text
Block requests where URI path begins with:
/internal-debug
```

Another example:

```text
Allow only POST on:
/api/webhook/provider-a
```

Possible inspection targets:

```text
URI path
Query string
Single query argument
Single header
All headers
Cookies
HTTP method
Request body
JSON body
```

## Normalize input

Attackers may use:

```text
Uppercase and lowercase changes
URL encoding
Double encoding
Whitespace
Null bytes
HTML entity encoding
```

AWS WAF supports text transformations before inspection.

Examples:

```text
LOWERCASE
URL_DECODE
HTML_ENTITY_DECODE
COMPRESS_WHITE_SPACE
```

---

# 20. Regular-expression rules

Regex rules can match flexible URI or input patterns.

Example:

```regex
^/api/v[0-9]+/admin/
```

Use regex carefully.

Poor regex design can:

* Match legitimate requests.
* Consume more WAF capacity.
* Become difficult to maintain.
* Hide the actual security requirement.

Prefer simple byte matching when the condition is straightforward.

---

# 21. SQL injection protection

SQL injection attempts to manipulate SQL queries through untrusted input.

Example malicious input:

```text
' OR 1=1 --
```

A vulnerable application might produce:

```sql
SELECT *
FROM users
WHERE username = '' OR 1=1 --';
```

AWS WAF can identify common SQL injection patterns.

But WAF is not the primary fix.

The application must use:

```text
Parameterized queries
Prepared statements
Least-privilege database users
Input validation
Safe ORM usage
```

Correct:

```javascript
await database.query(
  "SELECT * FROM users WHERE username = $1",
  [username]
);
```

Incorrect:

```javascript
await database.query(
  `SELECT * FROM users WHERE username = '${username}'`
);
```

---

# 22. Cross-site scripting protection

Cross-site scripting, or XSS, attempts to inject executable browser content.

Example:

```html
<script>stealSession()</script>
```

AWS WAF can detect common XSS patterns.

Application controls are still required:

```text
Output encoding
Template auto-escaping
Content Security Policy
Input validation
Safe DOM APIs
HttpOnly cookies
```

WAF reduces exposure but cannot understand every valid application context.

---

# 23. Size-constraint rules

A size-constraint rule matches request components based on their size.

Example:

```text
Block request body larger than 1 MiB
for /api/profile
```

This can protect against:

* Unexpectedly large payloads.
* Memory exhaustion.
* Parser abuse.
* Incorrect file uploads.
* Large query strings.
* Oversized cookies.

Be path-specific.

A general 1 MiB limit would break legitimate 10 MiB file uploads.

---

# 24. AWS Managed Rules

AWS Managed Rules are rule groups maintained by AWS.

Common categories include:

```text
Core Rule Set
Known bad inputs
SQL database protection
Linux operating-system patterns
Unix operating-system patterns
Windows operating-system patterns
PHP application patterns
WordPress patterns
IP reputation
Anonymous IP sources
Bot Control
Fraud Control
```

Most AWS Managed Rules groups are included with standard WAF charges, while Bot Control and Fraud Control groups have additional fees. ([AWS Documentation][7])

## Benefits

* Maintained by AWS.
* Updated as threat patterns evolve.
* Faster baseline deployment.
* Common attack coverage.
* Versioning for supported groups.

## Limitations

* Can create false positives.
* Cannot understand every application.
* May inspect only part of large bodies.
* Needs tuning and exclusions.
* Does not replace secure development.

---

# 25. Recommended managed-rule starting point

A common baseline is:

```text
AWSManagedRulesAmazonIpReputationList
AWSManagedRulesAnonymousIpList
AWSManagedRulesCommonRuleSet
AWSManagedRulesKnownBadInputsRuleSet
```

Then add workload-specific groups:

```text
AWSManagedRulesSQLiRuleSet
AWSManagedRulesLinuxRuleSet
AWSManagedRulesPHPRuleSet
AWSManagedRulesWordPressRuleSet
```

Do not attach every available rule group without understanding:

* WCU consumption.
* Duplicate protections.
* False positives.
* Request-body requirements.
* Application technology.

---

# 26. False positives

A false positive occurs when:

```text
A legitimate request matches a security rule
and is incorrectly blocked.
```

Examples:

```text
A blog editor submits HTML.
A search query contains SQL-like syntax.
A base64 token resembles an attack signature.
A GraphQL body contains nested syntax.
A file upload includes binary content.
A developer API intentionally accepts code snippets.
```

## Correct response

Do not disable the whole managed group immediately.

Prefer:

```text
Exclude one internal rule
Override one rule to Count
Scope the group away from a safe path
Allow a known parameter
Use a label-based exception
Fix unusual application behavior
```

---

# 27. Scope-down statements

A scope-down statement limits where a larger rule applies.

Example:

```text
Apply SQL injection rule group only to:
/api/*
```

Another:

```text
Apply Bot Control only to:
Public website paths

Exclude:
Static assets
Health checks
Trusted webhooks
```

This improves:

* Accuracy.
* Cost control.
* WCU usage.
* Performance.
* False-positive management.

---

# 28. Rule overrides

Managed rule groups contain many internal rules.

You can override an internal rule action.

Example:

```text
Managed group default:
Block

Specific rule override:
Count
```

This lets you keep all other protections active while investigating one problematic rule.

Example workflow:

```text
1. Rule blocks valid file upload.
2. Override only that rule to Count.
3. Review logs.
4. Add a narrow exception.
5. Restore Block when safe.
```

---

# 29. Labels

AWS WAF rules can attach labels to matching requests.

Example label:

```text
awswaf:managed:aws:core-rule-set:CrossSiteScripting_QueryArguments
```

A later rule can match that label.

Architecture:

```text
Managed rule detects suspicious input
        ↓
Applies label
        ↓
Later custom rule evaluates:
Path, IP, country and label
        ↓
Block, Count or Challenge
```

Labels let you separate:

```text
Detection
```

from:

```text
Final action
```

This is useful for advanced tuning.

---

# 30. Rate-based rules

A rate-based rule tracks request rates for an aggregation key.

Common aggregation:

```text
Per source IP
```

Examples:

```text
Limit login requests per IP
Limit password-reset requests
Limit search requests
Limit expensive report generation
Limit API requests from anonymous clients
```

Conceptual rule:

```text
IF
    path begins with /api/login
AND
    one IP exceeds the configured request rate
THEN
    Block or Challenge
```

Rate-based rules can use scope-down statements so only matching traffic is counted and rate limited. Actions can include Block, Count, CAPTCHA or Challenge. ([AWS Documentation][8])

---

# 31. Rate-limit design example

Suppose normal login behavior is:

```text
1–5 attempts per user
```

Attack behavior may be:

```text
Hundreds of attempts from one IP
```

A rule might be:

```text
Path:
/api/login

Aggregation:
Source IP

Action:
Challenge first
Block at a higher threshold
```

Use layered controls:

```text
Moderately suspicious rate
    → Challenge

Extreme request rate
    → Block
```

---

# 32. Rate limiting is approximate

AWS WAF rate-based rules are designed for traffic-rate control, not exact financial or quota accounting.

Do not use a WAF rate rule as the only system for:

```text
Exactly 100 API calls per paid account
Billing enforcement
Contractual quotas
Token balances
Inventory limits
```

Implement exact account limits inside:

```text
API Gateway usage plans
Application middleware
Redis or Valkey counters
A dedicated quota system
```

Use WAF to absorb abuse before it consumes application resources.

---

# 33. NAT and shared-IP problem

Many legitimate users may share one public IP:

```text
Corporate network
Mobile carrier
University
Large office
Public Wi-Fi
```

If you rate limit only by source IP:

```text
Thousands of users
        ↓
One NAT IP
        ↓
One rate bucket
```

You may block all of them together.

Possible approaches:

* Higher IP threshold.
* CAPTCHA or Challenge instead of immediate Block.
* Aggregate by another supported key.
* Application-level limits by user or API key.
* Exclude known partner NAT ranges.
* Use path-specific limits.

---

# 34. CAPTCHA versus Challenge

## CAPTCHA

The user may see an interactive puzzle.

Use when:

* Human confirmation is necessary.
* Silent checks are insufficient.
* Abuse is high.
* Blocking would affect too many legitimate users.

## Challenge

AWS WAF uses a silent browser challenge and token when possible.

Use when:

* You want minimal user interruption.
* You need to distinguish browsers from simple automation.
* The client supports the challenge process.

AWS recommends CAPTCHA or Challenge where outright blocking is too disruptive but allowing all traffic would permit unacceptable bot activity. ([AWS Documentation][4])

## API warning

Non-browser clients may not support CAPTCHA or browser challenges.

Examples:

```text
Mobile applications
CLI tools
Webhook providers
Server-to-server APIs
Monitoring agents
```

Do not challenge those clients without a compatible integration strategy.

---

# 35. Bot Control

AWS WAF Bot Control identifies and manages bot traffic.

Bot categories can include:

```text
Search engines
Monitoring systems
Scrapers
Automated browsers
Content fetchers
Advertising bots
Malicious automation
```

Not all bots are malicious.

Examples of useful bots:

```text
Search-engine crawlers
Uptime monitors
Approved partner integrations
Accessibility tools
Security scanners
```

Bot Control can apply labels and actions that help distinguish verified, unverified, friendly and suspicious automated traffic. AWS also supports targeted bot-protection capabilities and Web Bot Authentication for compatible bots and AI agents accessing CloudFront distributions. ([AWS Documentation][9])

---

# 36. Bot Control deployment pattern

```text
1. Add Bot Control.
2. Override rules to Count initially.
3. Enable logs and sampled requests.
4. Identify verified bots.
5. Identify business-required bots.
6. Add narrow exceptions.
7. Challenge suspicious automated browsers.
8. Block clearly malicious automation.
9. Review continuously.
```

## Common false-positive clients

```text
In-app browsers
Old mobile libraries
Custom HTTP clients
Headless test tools
Synthetic monitoring
Accessibility systems
Partner SDKs
```

AWS warns that nonstandard user agents, in-app browsers and unusual client libraries can trigger bot-detection signals. ([AWS Documentation][10])

---

# 37. Credential stuffing

Credential stuffing occurs when attackers use previously stolen username-password combinations against your login page.

```text
Stolen credentials
        ↓
Automated login attempts
        ↓
Successful account takeover
```

Controls include:

```text
Rate limiting
Bot Control
Fraud Control ATP
MFA
Risk-based authentication
Password breach detection
Login notifications
Device analysis
Account lock protections
```

---

# 38. Fraud Control ATP

ATP stands for:

```text
Account Takeover Prevention
```

AWS WAF Fraud Control ATP focuses on malicious login behavior and account takeover attempts.

It can help analyse:

* Login requests.
* Suspicious credentials.
* Automated login behavior.
* Compromised credential usage.
* High-risk authentication patterns.

ATP requires application-specific configuration such as identifying the login path and relevant request fields. ([AWS Documentation][11])

## ATP is not a replacement for

```text
MFA
Secure password storage
Account authorization
Session security
Credential rotation
Breach monitoring
```

---

# 39. Account creation fraud prevention

Account creation fraud prevention, or ACFP, protects registration flows from abuse such as:

```text
Mass fake-account creation
Promotional abuse
Trial abuse
Automated registrations
Disposable identity usage
```

Useful controls include:

* Bot signals.
* Request velocity.
* CAPTCHA or Challenge.
* Email or phone verification.
* Device and account reputation.
* Application-level fraud models.

Bot Control, ATP and ACFP are intelligent threat-mitigation options that address different stages of automated and fraudulent application behavior. ([AWS Documentation][12])

---

# 40. Request-body inspection limits

AWS WAF does not necessarily inspect an unlimited request body.

Current limits include:

```text
Application Load Balancer:
First 8 KB of body

AWS AppSync:
First 8 KB

CloudFront, API Gateway, Cognito,
App Runner and Verified Access:
16 KB by default

Eligible resources:
Can increase body inspection up to 64 KB
```

Headers also have aggregate inspection limits when inspecting all headers. ([AWS Documentation][13])

## Why this matters

Suppose malicious content is located after the inspection limit:

```text
First 16 KB:
Normal data

Later body section:
Attack payload
```

A body rule may not see the later content.

---

# 41. Oversized-request handling

For body or JSON inspection, rules have an oversized-component behavior.

Conceptually:

```text
CONTINUE
MATCH
NO_MATCH
```

## Continue

Inspect available content and continue normally.

## Match

Treat oversized content as matching the rule.

Useful for paths where large bodies should never occur.

## No match

Treat oversized content as not matching.

This can be dangerous if attackers deliberately exceed the inspection limit.

## Recommended design

For paths such as:

```text
/api/login
/api/password-reset
/api/search
```

where bodies should be small:

```text
Add an early size rule
    ↓
Block unexpectedly large requests
```

For upload paths:

```text
/upload
/videos
/import
```

allow larger requests but protect them using:

* File-size limits.
* Content-type validation.
* Malware scanning.
* Pre-signed S3 uploads.
* Application validation.

---

# 42. JSON body inspection

AWS WAF can inspect parsed JSON bodies.

This is useful for APIs such as:

```json
{
  "username": "user@example.com",
  "password": "value"
}
```

You can inspect:

```text
All JSON values
JSON keys
A specific JSON pointer
```

## Parsing problem

Malformed JSON can affect inspection behavior.

The application must still reject invalid JSON safely and enforce:

* Schema validation.
* Type validation.
* Length constraints.
* Allowed fields.
* Nested-depth limits.

---

# 43. File-upload architecture

Do not route large uploads through every layer unnecessarily:

```text
User
  ↓
CloudFront
  ↓
WAF
  ↓
ALB
  ↓
EC2
  ↓
S3
```

A more scalable pattern is:

```text
1. Application authenticates user.
2. Application creates pre-signed S3 upload URL.
3. User uploads directly to S3.
4. S3 event triggers scanning.
5. Application marks file safe after validation.
```

WAF protects the API that issues the upload authorization, while S3 handles the large object transfer.

---

# 44. Custom block responses

Instead of the default WAF response, you can return a custom status and body.

Example:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
```

```json
{
  "error": "rate_limit_exceeded",
  "message": "Please retry later."
}
```

Other possible custom headers:

```http
Retry-After: 60
X-Security-Action: blocked
```

Do not reveal:

```text
Exact rule name
Internal security logic
Detection thresholds
Infrastructure details
```

to an attacker.

---

# 45. WAF capacity units

WCU stands for:

```text
Web ACL Capacity Unit
```

Rules consume WCU based on their inspection complexity.

Examples:

```text
Simple IP match:
Relatively low capacity

Regex inspection:
Higher capacity

Managed rule group:
Defined group capacity

Bot or fraud protections:
Significant capacity
```

The total WCU of your rules must fit Web ACL quotas. AWS notes that using more than 1,500 WCUs incurs charges beyond the basic Web ACL price. ([AWS Documentation][5])

## Capacity design

Do not add rules based only on:

```text
“More rules means more security.”
```

Review:

* Duplicate inspection.
* Managed-group overlap.
* Regex necessity.
* Scope-down statements.
* Cost.
* False-positive risk.

---

# 46. WAF logging

AWS WAF logs can be delivered to:

```text
CloudWatch Logs
Amazon S3
Amazon Data Firehose
```

Logs include information such as:

* Timestamp.
* Web ACL.
* Terminating rule.
* Matching rules.
* Request headers.
* URI.
* Query string.
* Source address.
* Country.
* HTTP method.
* Labels.
* Rate-rule information.
* Oversized inspected fields.
* Final action.

AWS WAF supports log filtering and field redaction, and full logging is separate from sampled-request visibility. ([AWS Documentation][14])

---

# 47. Logging-destination naming

WAF logging destinations generally require names beginning with:

```text
aws-waf-logs-
```

Examples:

```text
aws-waf-logs-production-cloudfront
aws-waf-logs-production-alb
```

This naming applies to supported destinations such as CloudWatch log groups, S3 buckets or Firehose streams according to their configuration requirements. ([AWS Documentation][15])

---

# 48. Protect sensitive log data

WAF logs may contain:

```text
Authorization headers
Cookies
Query strings
Session identifiers
Email addresses
User agents
Request bodies
```

Configure redaction or data protection for sensitive fields.

Examples:

```text
Authorization
Cookie
X-API-Key
Sensitive query parameters
```

## Important distinction

Logging redaction affects WAF log output.

It does not automatically prevent those fields from appearing in:

* Sampled requests.
* CloudFront logs.
* ALB logs.
* Application logs.
* Security Lake.

AWS notes that WAF logging redaction is specific to the WAF logging configuration and does not automatically redact sampled requests. ([AWS Documentation][14])

---

# 49. Log filtering

You may not need to retain every allowed request.

Possible log-filter strategy:

```text
Keep:
BLOCK
CAPTCHA
CHALLENGE
Managed-rule matches
Rate-limit matches

Drop:
Ordinary ALLOW traffic
```

Benefits:

* Lower log-storage cost.
* Faster security analysis.
* Less sensitive-data retention.
* Easier incident investigation.

However, during initial tuning, full or broader logging can help establish a baseline.

---

# 50. Sampled requests

Sampled requests provide a quick view of traffic that matched rules.

Use them to inspect:

* Request path.
* Rule action.
* Source address.
* Headers.
* Matching rule.
* False positives.

Sampled requests are useful for rapid investigation, but they are not a complete audit log.

For reliable forensic workflows, enable full WAF logging.

---

# 51. CloudWatch metrics

Each Web ACL and rule can publish metrics.

Important measurements include:

```text
AllowedRequests
BlockedRequests
CountedRequests
CaptchaRequests
ChallengeRequests
RequestsWithValidCaptchaToken
RequestsWithValidChallengeToken
```

You should monitor both absolute volume and ratios.

Example:

```text
Blocked-request count rises by 1,000%
```

Possible explanations:

```text
Real attack
New WAF rule
False positive
Marketing traffic
Application release
Monitoring system change
```

---

# 52. Recommended alarms

Create alarms for:

```text
Blocked request spike
Allowed request collapse
Rate-rule spike
CAPTCHA or Challenge spike
WAF log-delivery failure
CloudFront 4xx increase
CloudFront 5xx increase
ALB target 5xx increase
Origin latency increase
Shield DDoS detection
```

## Correlate layers

```text
WAF blocks increase
+
Origin traffic remains stable
=
WAF may be successfully absorbing abuse
```

```text
WAF blocks increase
+
Origin CPU increases
+
Database connections increase
=
Attack may also contain traffic that is not being blocked
```

---

# 53. Shield Standard

Shield Standard is automatically included for AWS customers at no additional Shield subscription cost.

It provides protection against common network and transport-layer DDoS attacks targeting AWS-hosted applications. ([AWS Documentation][16])

Typical architecture:

```text
Route 53
CloudFront
Elastic Load Balancing
AWS Global Accelerator
```

already benefits from AWS’s infrastructure-level DDoS protections.

## Shield Standard does not provide

* Dedicated Shield Response Team engagement.
* Advanced event visibility.
* DDoS-related cost protection.
* Shield Advanced automatic application-layer response.
* Advanced health-based DDoS detection features.

---

# 54. Shield Advanced

Shield Advanced is a paid DDoS-protection service for critical applications.

It adds capabilities including:

```text
Advanced DDoS detection
Enhanced visibility
Layer 3, 4 and 7 protections
Shield Response Team support
Automatic application-layer mitigation
Health-based detection options
Protection groups
DDoS cost-protection opportunities
```

Supported protected-resource types include resources such as CloudFront distributions, Route 53 hosted zones, Elastic Load Balancing load balancers, Elastic IP resources and Global Accelerator standard accelerators. ([AWS Documentation][17])

---

# 55. When to consider Shield Advanced

Consider Shield Advanced for:

* Revenue-critical public websites.
* Financial applications.
* Gaming services.
* Media streaming.
* Healthcare portals.
* Government systems.
* High-profile events.
* Frequently attacked brands.
* Strict availability commitments.
* Applications where an attack-driven scaling bill would be material.

Shield Advanced is not required for every development application.

The decision should consider:

```text
Business impact
Threat profile
Availability requirements
Attack history
Operational maturity
Support requirements
Cost exposure
```

---

# 56. Shield Response Team

Shield Advanced customers can access the Shield Response Team, or SRT, for DDoS incident support.

The SRT can assist with:

* Attack analysis.
* Mitigation guidance.
* WAF rule support.
* DDoS event response.
* Escalation during critical incidents.

For efficient engagement, prepare:

```text
Resource ARNs
Application architecture
Known-good traffic patterns
Emergency contacts
Route 53 and CloudFront configuration
WAF logs
Current incident timeline
Business impact
```

Dedicated SRT support is one of the Shield Advanced capabilities. ([AWS Documentation][17])

---

# 57. Automatic application-layer DDoS mitigation

Shield Advanced can automatically create and manage WAF rules in response to application-layer DDoS activity.

Conceptually:

```text
Shield detects Layer 7 anomaly
        ↓
Analyses traffic characteristics
        ↓
Creates or updates mitigation rule
        ↓
WAF blocks or counts malicious traffic
```

Automatic application-layer mitigation requires AWS WAF v2 and adds a Shield-managed rule group to the Web ACL. AWS documents that this managed response uses 150 WCUs. ([AWS Documentation][18])

## Deployment modes

Depending on configuration, automatic mitigation may use:

```text
Count
Block
```

Begin carefully and monitor impact, particularly for applications with highly variable legitimate traffic.

---

# 58. Health-based DDoS detection

Shield Advanced can use Route 53 health checks to improve understanding of whether an attack is affecting application health.

Architecture:

```text
DDoS traffic detected
       +
Route 53 health check failing
       ↓
Higher confidence that availability is affected
```

A meaningful health check should test:

```text
Application readiness
Critical dependency availability
Actual customer-serving path
```

Avoid a health endpoint that returns `200` even when the application cannot serve real users.

---

# 59. DDoS cost protection

A DDoS attack may cause additional charges from:

```text
CloudFront traffic
Data transfer
Load balancer usage
EC2 Auto Scaling
Route 53
Global Accelerator
```

Shield Advanced provides qualifying cost-protection opportunities for certain usage increases caused by DDoS attacks against protected resources.

This is not an automatic guarantee for every charge.

You must:

* Protect eligible resources correctly.
* Follow Shield Advanced requirements.
* Retain event information.
* Contact AWS through the documented process.

([AWS Documentation][17])

---

# 60. Shield Advanced protection groups

Protection groups combine protected resources into logical application units.

Example:

```text
Production web application
├── CloudFront distribution
├── Route 53 hosted zone
├── ALB
└── Global Accelerator
```

This helps Shield Advanced evaluate and manage protections at an application or service level rather than considering every resource in isolation.

---

# 61. Origin bypass problem

Architecture:

```text
User
  ↓
CloudFront + WAF
  ↓
ALB
```

But if the ALB is publicly accessible:

```text
Attacker
  └──────────────> ALB directly
```

The attacker bypasses:

* CloudFront caching.
* CloudFront WAF.
* Edge rate limiting.
* Some Shield edge advantages.

## Protection approaches

### CloudFront secret header

CloudFront sends:

```http
X-Origin-Verify: strong-random-secret
```

ALB listener:

```text
Header matches
    → Forward

Header missing or incorrect
    → Fixed 403 response
```

### Restrict ALB security group

Where practical, restrict inbound traffic to AWS-managed CloudFront origin-facing address ranges or use supported managed prefix lists.

### Private-origin architecture

Use a design that allows CloudFront to reach a private origin where supported.

### Application hostname validation

Reject unexpected `Host` values.

Use more than one control for sensitive services.

---

# 62. Webhook exception design

Suppose a payment provider calls:

```text
POST /api/webhooks/payment
```

A general Bot Control or Challenge rule may break it because the provider is not a browser.

Create a narrow exception:

```text
IF
    path equals /api/webhooks/payment
AND
    source IP is from provider range
AND
    HTTP method is POST
THEN
    skip browser challenge
```

The application must still verify:

```text
Webhook signature
Timestamp
Replay protection
Event identifier
Expected payload
```

An IP allowlist alone is not enough.

---

# 63. Health-check exception design

Your ALB or monitoring service may request:

```text
/health
```

Do not allow all security checks to be bypassed merely because the path is `/health`.

A better rule:

```text
IF
    path is /health
AND
    source is trusted monitor or expected service
THEN
    allow
```

Public health endpoints should return minimal information.

Bad response:

```json
{
  "databaseHost": "prod-db.internal",
  "databaseVersion": "17.2",
  "activeUsers": 12782,
  "secretStore": "connected"
}
```

Better:

```json
{
  "status": "healthy"
}
```

---

# 64. Multi-account WAF management

Large organizations may have:

```text
Development account
Staging account
Production account
Shared-services account
Security account
```

AWS Firewall Manager can centrally apply WAF and Shield policies across accounts and resources in AWS Organizations.

Use it for:

* Required baseline managed rules.
* Central logging.
* Consistent Web ACL policies.
* Automatic protection of new resources.
* Security-team ownership.
* Organization-wide remediation.

Central policies can define pre-process and post-process rule groups around account-managed rules. ([AWS Documentation][19])

---

# 65. Terraform provider architecture

Use separate providers for CloudFront and Regional WAF resources:

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
aws.us_east_1:
CloudFront Web ACL
CloudFront-scoped WAF logging resources where applicable

aws:
Regional ALB Web ACL
Regional log group
Regional Web ACL association
```

---

# 66. Terraform CloudFront Web ACL

```hcl
resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name        = "production-cloudfront-waf"
  description = "Production CloudFront protection"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "production-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "production-cloudfront-waf"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

---

# 67. Terraform IP reputation rule

```hcl
rule {
  name     = "aws-ip-reputation"
  priority = 10

  override_action {
    none {}
  }

  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesAmazonIpReputationList"
      vendor_name = "AWS"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "aws-ip-reputation"
    sampled_requests_enabled   = true
  }
}
```

The group’s internal actions are used because:

```hcl
override_action {
  none {}
}
```

For initial testing, you can override behavior to count rather than block.

---

# 68. Terraform common managed protections

```hcl
rule {
  name     = "aws-common-rules"
  priority = 20

  override_action {
    none {}
  }

  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesCommonRuleSet"
      vendor_name = "AWS"

      rule_action_override {
        name = "SizeRestrictions_BODY"

        action_to_use {
          count {}
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "aws-common-rules"
    sampled_requests_enabled   = true
  }
}
```

This example keeps the group active while placing one potentially disruptive rule in Count mode for observation.

Exact internal rule names can change by managed-group version, so verify them in the AWS documentation and your selected version before deployment.

---

# 69. Terraform IP blocklist

```hcl
resource "aws_wafv2_ip_set" "blocked_ipv4" {
  provider = aws.us_east_1

  name               = "production-blocked-ipv4"
  description        = "Emergency IPv4 blocklist"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"

  addresses = [
    "203.0.113.10/32",
    "198.51.100.0/24"
  ]
}
```

Rule:

```hcl
rule {
  name     = "block-explicit-ip-list"
  priority = 0

  action {
    block {}
  }

  statement {
    ip_set_reference_statement {
      arn = aws_wafv2_ip_set.blocked_ipv4.arn
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "block-explicit-ip-list"
    sampled_requests_enabled   = true
  }
}
```

---

# 70. Terraform login rate limit

```hcl
rule {
  name     = "login-rate-limit"
  priority = 30

  action {
    block {
      custom_response {
        response_code = 429

        response_header {
          name  = "Retry-After"
          value = "60"
        }

        custom_response_body_key = "rate-limit-response"
      }
    }
  }

  statement {
    rate_based_statement {
      limit              = 100
      aggregate_key_type = "IP"

      scope_down_statement {
        byte_match_statement {
          positional_constraint = "STARTS_WITH"
          search_string         = "/api/login"

          field_to_match {
            uri_path {}
          }

          text_transformation {
            priority = 0
            type     = "LOWERCASE"
          }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "login-rate-limit"
    sampled_requests_enabled   = true
  }
}
```

Custom response body:

```hcl
custom_response_body {
  key          = "rate-limit-response"
  content_type = "APPLICATION_JSON"

  content = jsonencode({
    error   = "rate_limit_exceeded"
    message = "Please retry later."
  })
}
```

The threshold is illustrative. Derive the real limit from production traffic and shared-IP behavior.

---

# 71. Challenge suspicious traffic

```hcl
rule {
  name     = "challenge-suspicious-region-login"
  priority = 40

  action {
    challenge {}
  }

  statement {
    and_statement {
      statement {
        byte_match_statement {
          positional_constraint = "STARTS_WITH"
          search_string         = "/api/login"

          field_to_match {
            uri_path {}
          }

          text_transformation {
            priority = 0
            type     = "LOWERCASE"
          }
        }
      }

      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = ["IN", "SG", "US"]
            }
          }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "challenge-suspicious-login"
    sampled_requests_enabled   = true
  }
}
```

Do not use this rule for non-browser authentication clients unless they support the challenge mechanism.

---

# 72. Attach WAF to CloudFront

Within the CloudFront distribution:

```hcl
resource "aws_cloudfront_distribution" "site" {
  # Other distribution configuration omitted.

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn
}
```

CloudFront association is managed through the CloudFront distribution configuration rather than the normal Regional `AssociateWebACL` API. ([AWS Documentation][20])

---

# 73. Regional ALB Web ACL

```hcl
resource "aws_wafv2_web_acl" "alb" {
  name        = "production-alb-waf"
  description = "Regional ALB protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "production-alb-waf"
    sampled_requests_enabled   = true
  }
}
```

Associate it:

```hcl
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.application.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
```

---

# 74. Terraform WAF logging

CloudWatch log group:

```hcl
resource "aws_cloudwatch_log_group" "waf" {
  provider = aws.us_east_1

  name              = "aws-waf-logs-production-cloudfront"
  retention_in_days = 30
}
```

Logging configuration:

```hcl
resource "aws_wafv2_web_acl_logging_configuration" "cloudfront" {
  provider = aws.us_east_1

  resource_arn = aws_wafv2_web_acl.cloudfront.arn

  log_destination_configs = [
    aws_cloudwatch_log_group.waf.arn
  ]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
```

Review the current AWS provider schema for log filtering and data-protection options before applying them.

---

# 75. AWS CLI validation

List Web ACLs:

```bash
aws wafv2 list-web-acls \
  --scope CLOUDFRONT \
  --region us-east-1
```

For an ALB:

```bash
aws wafv2 list-web-acls \
  --scope REGIONAL \
  --region ap-south-1
```

Get Web ACL:

```bash
aws wafv2 get-web-acl \
  --scope CLOUDFRONT \
  --region us-east-1 \
  --name production-cloudfront-waf \
  --id "$WEB_ACL_ID"
```

Get sampled requests:

```bash
aws wafv2 get-sampled-requests \
  --web-acl-arn "$WEB_ACL_ARN" \
  --rule-metric-name aws-common-rules \
  --scope CLOUDFRONT \
  --time-window StartTime="$START",EndTime="$END" \
  --max-items 100 \
  --region us-east-1
```

---

# 76. Safe WAF testing

Use controlled test requests.

## Test a blocked URI

```bash
curl -i \
  https://www.example.com/internal-debug
```

## Test a suspicious query

```bash
curl -i \
  --get \
  --data-urlencode "q=' OR 1=1 --" \
  https://www.example.com/api/search
```

Use only systems that you own or have authorization to test.

## Check response

```text
HTTP 403:
WAF may have blocked it

HTTP 429:
Rate rule may have blocked it

HTTP 200:
Rule may be in Count mode, excluded or not matching
```

Then inspect:

* WAF logs.
* Sampled requests.
* Rule metrics.
* CloudFront or ALB logs.
* Application logs.

---

# 77. Common problem: WAF blocks valid requests

Symptoms:

```text
Users receive 403
Application has no request log
CloudFront reports WAF block
```

Troubleshooting:

```text
1. Identify terminating rule in WAF log.
2. Identify matching internal managed rule.
3. Reproduce request safely.
4. Confirm whether input is legitimate.
5. Override rule to Count temporarily.
6. Add narrow exception.
7. Test.
8. Restore enforcement.
```

Do not disable the entire Web ACL during an incident unless absolutely necessary.

---

# 78. Common problem: WAF does not block attack

Possible causes:

```text
Web ACL not associated
Wrong scope or Region
Rule priority issue
Rule left in Count mode
Request bypasses CloudFront
Wrong forwarded IP configuration
Attack payload beyond body-inspection limit
Rule inspects wrong component
Text transformation missing
Scope-down statement excludes traffic
```

Check association:

```bash
aws cloudfront get-distribution-config \
  --id "$DISTRIBUTION_ID" \
  --query 'DistributionConfig.WebACLId'
```

For ALB:

```bash
aws wafv2 get-web-acl-for-resource \
  --resource-arn "$ALB_ARN" \
  --region ap-south-1
```

---

# 79. Common problem: rate rule blocks legitimate users

Possible causes:

```text
Many users share one NAT IP
Threshold too low
Health checks included
Static assets included
Mobile-carrier traffic aggregated
Proxy address treated as client
Login retries caused by an application bug
```

Fixes:

* Restrict rule to exact expensive paths.
* Exclude static resources.
* Increase threshold.
* Use Challenge before Block.
* Correct forwarded-IP logic.
* Add trusted-service exceptions.
* Use account-level application limits.

---

# 80. Common problem: bots bypass IP limits

Sophisticated bots can rotate:

```text
IP addresses
User agents
Sessions
Cloud providers
Residential proxies
```

A per-IP rule may see:

```text
10 requests from each IP
×
100,000 IPs
=
1,000,000 requests
```

Additional controls:

```text
Bot Control
Challenge tokens
Device or session signals
Account-level limits
Behavior analysis
Endpoint-specific capacity protection
Application fraud controls
```

---

# 81. Common problem: WAF logs contain secrets

Possible causes:

```text
Authorization header not redacted
Cookies retained
API key in query string
Sensitive form fields logged
Debug logging enabled elsewhere
```

Actions:

1. Update WAF redaction or filtering.
2. Rotate exposed credentials where required.
3. Reduce log access.
4. Review CloudFront, ALB and application logs.
5. Apply retention and deletion policies.
6. Prevent secrets in query strings.

---

# 82. Common problem: large upload bypasses body rule

Cause:

```text
Payload exceeds WAF inspection limit.
Malicious content appears after inspected bytes.
```

Solutions:

* Separate upload endpoint.
* Block oversize bodies on non-upload paths.
* Upload directly to S3.
* Scan uploaded files after arrival.
* Validate file signatures.
* Limit content type and size.
* Do not rely only on WAF body inspection.

---

# 83. DDoS incident-response sequence

When traffic spikes dramatically:

```text
1. Confirm customer impact.
2. Determine whether traffic is legitimate or malicious.
3. Check Shield events.
4. Review CloudFront and ALB metrics.
5. Review WAF rule matches and logs.
6. Identify top IPs, countries, paths and user agents.
7. Add emergency rate, IP or path rules.
8. Use Count briefly when uncertainty is high.
9. Protect expensive endpoints first.
10. Verify origin access cannot bypass CloudFront.
11. Increase application capacity only when useful.
12. Protect databases and dependencies.
13. Engage SRT if subscribed and appropriate.
14. Monitor recovery.
15. Document attack indicators and lessons.
```

---

# 84. Do not blindly scale during an attack

Suppose attackers repeatedly call an endpoint that performs an expensive database report.

```text
Attack traffic increases
        ↓
EC2 Auto Scaling adds instances
        ↓
More application instances open DB connections
        ↓
Database becomes overloaded
        ↓
Cost and outage severity increase
```

Better sequence:

```text
Filter malicious traffic
        ↓
Rate limit expensive paths
        ↓
Add cache where valid
        ↓
Protect database concurrency
        ↓
Scale legitimate capacity
```

Autoscaling is a capacity feature, not an attack-classification system.

---

# 85. Layered defence for a login endpoint

A secure login flow might include:

```text
CloudFront
   ↓
AWS WAF
   ├── IP reputation
   ├── Rate limit
   ├── Bot challenge
   └── ATP
   ↓
Application
   ├── Generic error responses
   ├── Password hashing
   ├── MFA
   ├── Account risk analysis
   ├── Session rotation
   └── Audit logs
   ↓
Database
```

No individual layer is sufficient.

---

# 86. Production rollout plan

## Phase 1: Visibility

```text
Enable WAF
Enable logging
Enable metrics
All custom and managed rules in Count
```

## Phase 2: Low-risk blocks

```text
Block explicit bad IPs
Block known reputation lists
Block impossible paths
Block obviously oversized login bodies
```

## Phase 3: Managed enforcement

```text
Enable common managed rules
Tune false positives
Enable SQLi and XSS protections
```

## Phase 4: Abuse controls

```text
Rate limit login
Rate limit password reset
Challenge suspicious bots
Enable Bot Control
```

## Phase 5: Advanced protection

```text
Fraud Control
Shield Advanced
Automatic L7 mitigation
Central Firewall Manager policies
```

---

# 87. Production checklist

```text
[ ] Correct WAF scope is selected
[ ] CloudFront Web ACL is managed in us-east-1
[ ] Regional Web ACL is in the resource Region
[ ] Web ACL is associated with the correct resource
[ ] Direct origin bypass is restricted
[ ] Default action is intentional
[ ] Rule priorities are reviewed
[ ] New rules are tested in Count mode
[ ] Managed-rule false positives are tuned
[ ] IP reputation rules are enabled
[ ] Login and reset paths are rate limited
[ ] NAT/shared-IP effects are considered
[ ] Browser challenges exclude server clients
[ ] Webhooks have narrow exceptions
[ ] Health checks have safe exceptions
[ ] Body-inspection limits are documented
[ ] Oversized-request handling is configured
[ ] Upload architecture is separated
[ ] Authorization and cookie fields are redacted
[ ] WAF logging is enabled
[ ] Log retention is configured
[ ] CloudWatch alarms are configured
[ ] WAF metrics are correlated with origin metrics
[ ] Bot traffic is monitored
[ ] ATP/ACFP are evaluated for authentication flows
[ ] Shield Standard coverage is understood
[ ] Shield Advanced is evaluated for critical workloads
[ ] SRT engagement process is documented
[ ] Emergency IP and rate rules are prepared
[ ] Multi-account controls are considered
[ ] Incident runbooks are tested
```

---

# 88. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
AWS WAF filters HTTP and HTTPS requests.

Shield Standard provides automatic baseline DDoS protection.

Shield Advanced provides enhanced DDoS protection.
```

## Solutions Architect Associate

Understand:

```text
Web ACLs
CloudFront versus Regional scope
Managed rules
IP sets
Geographic rules
Rate-based rules
WAF logging
CloudFront origin protection
Shield Standard versus Advanced
```

## DevOps Engineer Professional

Understand:

```text
Terraform WAF deployment
Count-mode rollout
Managed-rule tuning
Central Firewall Manager policies
Bot and Fraud Control
Application-layer DDoS mitigation
EventBridge and CloudWatch response
Shield Advanced protection groups
SRT engagement
Automated incident rules
Logging and forensic analysis
```

---

# 89. Interview questions

## Question 1: What is the difference between AWS WAF and AWS Shield?

**Answer:**

AWS WAF inspects and filters HTTP and HTTPS requests using configurable rules. AWS Shield provides DDoS detection and mitigation, especially for network and transport-layer attacks, with Shield Advanced adding enhanced application-layer and response capabilities.

## Question 2: What is a Web ACL?

**Answer:**

A Web ACL is an ordered collection of WAF rules with a default action. It is associated with supported AWS resources so WAF can inspect their requests.

## Question 3: What is the difference between CloudFront and Regional WAF scope?

**Answer:**

CloudFront Web ACLs use the `CLOUDFRONT` scope and are managed through `us-east-1`. ALBs and other Regional resources use the `REGIONAL` scope in the resource’s Region.

## Question 4: What is Count mode?

**Answer:**

Count records rule matches and continues evaluating later rules without blocking the request. It is useful for tuning and false-positive analysis.

## Question 5: What is a rate-based rule?

**Answer:**

It tracks request rates using an aggregation key such as source IP and applies an action when the configured rate is exceeded.

## Question 6: Why can IP rate limiting block legitimate users?

**Answer:**

Many users may share a public IP through NAT, mobile carriers, corporate networks or proxies, causing all their requests to count against one rate bucket.

## Question 7: What is a false positive?

**Answer:**

A legitimate request that incorrectly matches a security rule and is blocked or challenged.

## Question 8: How should managed WAF rules be deployed?

**Answer:**

Test in staging, deploy in Count mode, inspect logs, tune exclusions and scope-down logic, then enable enforcement gradually.

## Question 9: What is Bot Control?

**Answer:**

Bot Control identifies and categorizes automated traffic and can apply labels or actions to friendly, verified, suspicious or malicious bots.

## Question 10: What is Fraud Control ATP?

**Answer:**

ATP is Account Takeover Prevention. It protects login endpoints from malicious authentication behavior such as credential stuffing.

## Question 11: Does WAF inspect an unlimited request body?

**Answer:**

No. Inspection limits depend on the protected resource. For example, ALB body inspection is limited to the first 8 KB, while eligible CloudFront configurations can inspect up to 64 KB.

## Question 12: What is Shield Standard?

**Answer:**

Shield Standard is automatic baseline DDoS protection available to AWS customers without an additional Shield subscription fee.

## Question 13: What does Shield Advanced add?

**Answer:**

It adds enhanced DDoS detection and visibility, Shield Response Team support, automatic application-layer mitigation options and qualifying DDoS cost protection.

## Question 14: Can WAF prevent every SQL injection attack?

**Answer:**

No. WAF can identify common attack patterns, but the application must still use parameterized queries, input validation and least-privilege database access.

## Question 15: Why restrict direct origin access?

**Answer:**

If attackers can call the ALB or origin directly, they may bypass CloudFront caching, CloudFront WAF and edge security controls.

---

# 90. Never-forget revision

```text
AWS WAF:
Filters HTTP and HTTPS requests.

Web ACL:
Ordered WAF rules plus a default action.

Rule statement:
Defines what to match.

Rule action:
Allow, Block, Count, CAPTCHA or Challenge.

Count:
Observe without blocking.

Managed rule group:
AWS- or vendor-maintained protections.

IP set:
Reusable CIDR collection.

Rate-based rule:
Controls excessive request rates.

Scope-down statement:
Limits where a broader rule applies.

False positive:
Legitimate request incorrectly matched.

Label:
Metadata added by one rule and used by another.

Bot Control:
Identifies and manages automated traffic.

ATP:
Protects login flows from account takeover.

ACFP:
Protects registration flows from fake-account abuse.

Shield Standard:
Automatic baseline DDoS protection.

Shield Advanced:
Enhanced DDoS detection, mitigation and response.

SRT:
Shield Response Team.

WCU:
Web ACL Capacity Unit.

Firewall Manager:
Central organization-wide security policy management.
```

## One-line memory trick

```text
Shield protects availability.
WAF filters requests.
Managed rules provide a baseline.
Count mode prevents unsafe rollouts.
Rate limits protect expensive endpoints.
Logs prove what actually happened.
```

## Lesson 30 outcome

You can now design an architecture where:

```text
Network flood arrives
    → Shield mitigates infrastructure-level attack traffic.

Known malicious IP connects
    → WAF reputation rules block it.

Login endpoint is attacked
    → Rate limit, Bot Control and ATP respond.

A valid request resembles an attack
    → Count mode and logs help tune the rule.

A bot rotates across many IPs
    → Challenge and Bot Control add behavior-based protection.

Attackers bypass CloudFront
    → Origin restrictions reject direct access.

Large DDoS event affects a critical application
    → Shield Advanced and SRT support the response.
```

**Next lesson: Lesson 31 — AWS IAM advanced architecture: users, roles, policies, permission boundaries, SCPs, resource policies, STS, cross-account access, identity federation and production troubleshooting.**

[1]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html?utm_source=chatgpt.com "AWS WAF"
[2]: https://docs.aws.amazon.com/waf/latest/developerguide/ddos-overview.html?utm_source=chatgpt.com "How AWS Shield and Shield Advanced work - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[3]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl-associating-aws-resource.html?utm_source=chatgpt.com "Associating or disassociating protection with an AWS ..."
[4]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-captcha-and-challenge.html?utm_source=chatgpt.com "CAPTCHA and Challenge in AWS WAF - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[5]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html?utm_source=chatgpt.com "Configuring protection in AWS WAF"
[6]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-forwarded-ip-address.html?utm_source=chatgpt.com "Using forwarded IP addresses in AWS WAF"
[7]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-managed-rule-groups.html?utm_source=chatgpt.com "Using managed rule groups in AWS WAF - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[8]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based.html?utm_source=chatgpt.com "Using rate-based rule statements in AWS WAF - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[9]: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-bot.html?utm_source=chatgpt.com "AWS WAF Bot Control rule group - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[10]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-bot-control-use-cases.html?utm_source=chatgpt.com "Choosing and configuring Bot Control for your use case - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[11]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-atp.html?utm_source=chatgpt.com "AWS WAF Fraud Control account takeover prevention (ATP) - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[12]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-managed-protections.html?utm_source=chatgpt.com "Intelligent threat mitigation in AWS WAF - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[13]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl-setting-body-inspection-limit.html?utm_source=chatgpt.com "Considerations for managing body inspection in AWS WAF"
[14]: https://docs.aws.amazon.com/waf/latest/developerguide/logging.html?utm_source=chatgpt.com "Logging AWS WAF protection pack (web ACL) traffic - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[15]: https://docs.aws.amazon.com/waf/latest/developerguide/logging-management-configure.html?utm_source=chatgpt.com "Configuring logging for a protection pack (web ACL) - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[16]: https://docs.aws.amazon.com/shield/?utm_source=chatgpt.com "AWS Shield Documentation"
[17]: https://docs.aws.amazon.com/waf/latest/developerguide/ddos-advanced-summary-capabilities.html?utm_source=chatgpt.com "AWS Shield Advanced capabilities and options - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[18]: https://docs.aws.amazon.com/waf/latest/developerguide/ddos-automatic-app-layer-response.html?utm_source=chatgpt.com "Automating application layer DDoS mitigation with Shield Advanced - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[19]: https://docs.aws.amazon.com/waf/latest/developerguide/waf-policies-rule-groups.html?utm_source=chatgpt.com "Rule group management for AWS WAF policies - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[20]: https://docs.aws.amazon.com/waf/latest/developerguide/security_iam_service-with-iam.html?utm_source=chatgpt.com "How AWS WAF works with IAM"
