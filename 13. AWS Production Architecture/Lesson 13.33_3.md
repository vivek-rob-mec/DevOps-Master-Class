# AWS Masterclass — Lesson 33 Part 3

# Amazon API Gateway from First Principles

## REST APIs, HTTP APIs, WebSocket APIs, Lambda Integration, Authentication, Throttling, Custom Domains, WAF, Logging & Production Design

In Parts 1 and 2 we built Lambda itself:

```text
Part 1
Lambda execution model
    │
    ├── cold starts
    ├── concurrency
    ├── IAM
    ├── VPC
    └── versions


Part 2
Lambda reliability
    │
    ├── retries
    ├── SQS
    ├── streams
    ├── DLQs
    └── idempotency
```

Now customers need a safe way to reach our functions.

```text
Browser
Mobile App
CLI
Partner System
      │
      ▼
 ????????
      │
      ▼
    Lambda
```

That missing front door is often:

# Amazon API Gateway

AWS defines API Gateway as a managed service for creating, publishing, maintaining, monitoring, and securing **REST, HTTP, and WebSocket APIs** at scale. ([AWS Documentation][1])

---

# 1. What Problem Does API Gateway Solve?

Imagine exposing Lambda directly to customers.

You would still need to solve:

```text
HTTPS endpoint

HTTP routing

authentication

authorization

CORS

rate limiting

request validation

custom domain

API versions

monitoring

access logs

TLS certificates

WAF

backend integrations
```

API Gateway provides the API-facing layer for many of those responsibilities.

Architecture:

```text
                    INTERNET

 Browser ──────┐
 Mobile ───────┤
 CLI ──────────┤
 Partner ──────┘
               │
               ▼
          API Gateway
               │
        ┌──────┼───────┐
        │      │       │
      Auth   Route   Throttle
        │      │       │
        └──────┼───────┘
               ▼
             Lambda
               │
       ┌───────┼────────┐
       ▼       ▼        ▼
   DynamoDB   SQS      S3
```

---

# 2. API Gateway Is Not the Application

Never think:

```text
API Gateway
=
my business logic
```

Usually:

```text
API Gateway
=
front door / API management layer
```

while:

```text
Lambda
ECS
EC2
Step Functions
other AWS service
```

contains the application logic.

---

# 3. The Three API Gateway Products

API Gateway currently has three major API styles:

```text
API Gateway
│
├── REST API
│
├── HTTP API
│
└── WebSocket API
```

REST and HTTP APIs are stateless request/response APIs; WebSocket APIs support stateful persistent client connections. ([AWS Documentation][1])

Choosing the right one matters because the feature sets differ significantly.

---

# PART A — HTTP API vs REST API

# 4. The First Decision

For a normal JSON API, the first question is usually:

```text
Do I need
REST API
or
HTTP API?
```

AWS's current guidance is roughly:

```text
Need advanced API-management features?
        │
       YES
        ▼
     REST API


Need straightforward
low-cost HTTP routing?
        │
       YES
        ▼
     HTTP API
```

REST APIs support more API-management features, while HTTP APIs intentionally provide a smaller feature set and lower-cost model. ([AWS Documentation][2])

---

# 5. HTTP API — Think “Lean API Front Door”

HTTP APIs are excellent for architectures such as:

```text
Web/Mobile
    │
    ▼
HTTP API
    │
    ▼
Lambda
    │
    ▼
DynamoDB
```

especially when you need:

```text
HTTP routes

Lambda proxy integration

JWT authorization

IAM authorization

Lambda authorizers

CORS

custom domain

simple throttling

private backend integrations
```

without the richer REST API management feature set. HTTP APIs support JWT, IAM, and Lambda authorizers. ([AWS Documentation][3])

---

# 6. REST API — Think “Full API Management”

REST APIs become important when requirements include features such as:

```text
API keys

usage plans

per-client throttling

request validation

API Gateway-managed caching

AWS WAF integration

private API endpoint

canary deployment

extensive transformation/control
```

AWS specifically recommends REST APIs over HTTP APIs when you require API keys, per-client throttling, request validation, WAF integration, or private API endpoints. ([AWS Documentation][2])

---

# 7. Never-Forget Comparison

| Requirement              |                           HTTP API |                    REST API |
| ------------------------ | ---------------------------------: | --------------------------: |
| Lambda backend           |                                  ✅ |                           ✅ |
| JWT authorizer           |                                  ✅ | Other auth models available |
| IAM auth                 |                                  ✅ |                           ✅ |
| Lambda authorizer        |                                  ✅ |                           ✅ |
| CORS                     |                                  ✅ |                           ✅ |
| Regional custom domain   |                                  ✅ |                           ✅ |
| API keys / usage plans   |                                  ❌ |                           ✅ |
| API Gateway cache        |                                  ❌ |                           ✅ |
| Request validation       | Limited/not REST validator feature |                           ✅ |
| WAF direct integration   |                                  ❌ |                           ✅ |
| Private API endpoint     |                                  ❌ |                           ✅ |
| Canary stage deployments |        ❌ REST-style canary feature |                           ✅ |
| Edge-optimized endpoint  |                                  ❌ |                           ✅ |
| Lower-cost simpler API   |               **Primary strength** |                           — |

The major feature distinctions are documented by AWS's current REST-vs-HTTP comparison. ([AWS Documentation][2])

---

# 8. My Production Selection Rule

Use:

```text
HTTP API
```

unless you specifically require a REST-only capability.

Do not use REST API because:

```text
"REST sounds more professional."
```

Choose it because you need:

```text
WAF
usage plans
API keys
request validation
caching
private endpoint
canary controls
```

or another REST-specific feature.

---

# PART B — HTTP METHODS, RESOURCES & ROUTES

# 9. Basic HTTP API Design

Suppose our Todo API needs:

```text
GET    /todos

POST   /todos

GET    /todos/{id}

DELETE /todos/{id}
```

Those are routes.

Conceptually:

```text
API Gateway
│
├── GET /todos
│      └── Lambda ListTodos
│
├── POST /todos
│      └── Lambda CreateTodo
│
├── GET /todos/{id}
│      └── Lambda GetTodo
│
└── DELETE /todos/{id}
       └── Lambda DeleteTodo
```

---

# 10. Route = Method + Path

For HTTP APIs:

```text
GET /todos
```

and:

```text
POST /todos
```

are different routes.

Think:

```text
Route Key

=
HTTP Method
+
Path
```

API Gateway HTTP API routes can forward path and query-string parameters to their integrations. ([AWS Documentation][4])

---

# 11. Path Parameter

Example:

```text
GET /todos/123
```

Route:

```text
GET /todos/{id}
```

The application receives:

```text
id=123
```

---

# 12. Query Parameter

Example:

```text
GET /todos?status=completed&limit=10
```

API Gateway HTTP APIs forward query-string parameters to the backend integration by default. ([AWS Documentation][4])

Your Lambda may receive:

```json
{
  "queryStringParameters": {
    "status": "completed",
    "limit": "10"
  }
}
```

depending on the payload format.

---

# 13. `$default` Route

HTTP APIs can define:

```text
$default
```

which handles requests not matched by a more specific route.

Architecture:

```text
GET /todos
   │
   ▼
explicit route


GET /something-new
   │
   ▼
$default
```

Useful for:

```text
single-router Lambda

framework adapters

proxy-style APIs
```

But do not hide a badly designed API behind one huge default handler without reason.

---

# PART C — LAMBDA PROXY INTEGRATION

# 14. The Most Common Serverless Integration

For Lambda:

```text
Client
   │
   ▼
API Gateway
   │
   ▼
Lambda Proxy Integration
   │
   ▼
Lambda receives request object
```

With a proxy integration, API Gateway passes HTTP request information—including headers, query parameters, path values and body—to Lambda, and Lambda returns a response that API Gateway translates back to HTTP. ([AWS Documentation][5])

---

# 15. Why “Proxy”?

API Gateway does relatively little business-level transformation.

Your Lambda decides:

```text
request interpretation

validation

business logic

response body

response status

response headers
```

Conceptually:

```text
HTTP request
     │
     ▼
API Gateway wrapper
     │
     ▼
Lambda event
     │
     ▼
Lambda response
     │
     ▼
HTTP response
```

---

# 16. HTTP API Payload Formats

For Lambda proxy integrations with HTTP APIs, API Gateway currently supports:

```text
payloadFormatVersion = 1.0

or

payloadFormatVersion = 2.0
```

If you create the integration through CLI, SDK, or infrastructure definitions, you should explicitly specify the payload format. ([AWS Documentation][5])

---

# 17. Payload Format 2.0

For most new HTTP API + Lambda applications, you'll commonly encounter:

```text
2.0
```

because it has a streamlined request structure.

Example conceptually:

```json
{
  "version": "2.0",
  "routeKey": "GET /todos/{id}",
  "rawPath": "/todos/123",
  "headers": {},
  "queryStringParameters": {},
  "pathParameters": {
    "id": "123"
  },
  "requestContext": {},
  "body": null
}
```

Version 2.0 differs from 1.0 in areas including cookies, duplicate headers/query parameters, and `rawPath`. ([AWS Documentation][5])

---

# 18. Important Payload 1.0 vs 2.0 Differences

Version 2.0:

```text
no multiValueHeaders

no multiValueQueryStringParameters

adds cookies field

adds rawPath

combines duplicate headers/query parameters
```

Version 1.0 retains the older API Gateway proxy-event shape. ([AWS Documentation][5])

---

# 19. Node.js Lambda for HTTP API

```javascript
export const handler = async (event) => {
  const id = event.pathParameters?.id;

  return {
    statusCode: 200,
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify({
      id,
      title: "Learn API Gateway"
    })
  };
};
```

Architecture:

```text
GET /todos/123
      │
      ▼
API Gateway
      │
      ▼
event.pathParameters.id
      │
      ▼
123
```

---

# 20. Bad Lambda Response Can Become 502

For REST Lambda proxy integrations, if Lambda doesn't return the response format API Gateway expects, API Gateway can return:

```text
502 Bad Gateway
```

rather than the application's intended response. ([AWS Documentation][6])

So:

```text
Lambda executed
```

does **not** necessarily mean:

```text
API Gateway produced valid HTTP response.
```

---

# PART D — CORS

# 21. What Is CORS?

Imagine frontend:

```text
https://app.example.com
```

calls API:

```text
https://api.example.com
```

Those are different origins.

Browsers enforce:

# Cross-Origin Resource Sharing

rules for such script-initiated requests. API Gateway supports CORS configuration for both HTTP and REST APIs. ([AWS Documentation][7])

---

# 22. Common CORS Failure

Frontend console:

```text
Blocked by CORS policy
```

Backend engineer says:

```text
"But curl works!"
```

Exactly.

CORS is primarily:

```text
browser-enforced behavior.
```

Curl/Postman do not reproduce browser CORS enforcement in the same way.

---

# 23. HTTP API CORS

HTTP APIs can be configured centrally with:

```text
Allowed origins

Allowed methods

Allowed headers

Exposed headers

Credentials

Max age
```

and API Gateway handles the CORS configuration. An important behavior is that once CORS is configured at the HTTP API level, API Gateway ignores CORS headers produced by the backend integration and applies its configured CORS behavior instead. ([AWS Documentation][7])

---

# 24. Restrict Production Origins

Development:

```text
AllowOrigin = *
```

may be convenient.

Production authentication involving cookies/credentials often requires more deliberate configuration.

Better:

```text
https://app.yourdatascientist.tech
```

rather than indiscriminately:

```text
*
```

where the application's security model does not require universal browser origins.

---

# PART E — AUTHENTICATION & AUTHORIZATION

# 25. Authentication vs Authorization

Never confuse:

```text
Authentication
=
WHO ARE YOU?


Authorization
=
WHAT MAY YOU DO?
```

API Gateway supports several authorization models depending on API type. ([AWS Documentation][3])

---

# 26. Four Important API Auth Patterns

You need to recognize:

```text
JWT Authorizer

Cognito User Pool Authorizer

Lambda Authorizer

AWS IAM / SigV4
```

They solve different problems.

---

# 27. HTTP API JWT Authorizer

HTTP APIs have native:

# JWT Authorizers

for OIDC/OAuth 2.0 JWTs. API Gateway validates incoming JWTs against configured issuer/audience information before forwarding authorized requests. ([AWS Documentation][8])

Architecture:

```text
User
 │
 ▼
Identity Provider
 │
 ▼
JWT
 │
 ▼
API Gateway
 │
 ▼
JWT Authorizer
 │
 ├── signature valid?
 ├── issuer valid?
 ├── audience valid?
 ├── time claims valid?
 └── required scope?
       │
       ▼
     Lambda
```

---

# 28. Example Cognito + HTTP API

```text
Browser
   │
   ▼
Cognito User Pool
   │
   ▼
JWT access token
   │
   ▼
Authorization: Bearer <token>
   │
   ▼
API Gateway HTTP API
   │
   ▼
JWT Authorizer
   │
   ▼
Lambda
```

This is often a clean modern architecture for user-facing HTTP APIs.

---

# 29. Route Scopes

Suppose token contains OAuth scope:

```text
todos.read
```

Then route:

```text
GET /todos
```

can require:

```text
todos.read
```

while:

```text
POST /todos
```

might require:

```text
todos.write
```

That moves coarse API authorization closer to the API boundary.

---

# 30. REST API + Cognito User Pool

REST APIs support a native:

```text
COGNITO_USER_POOLS
```

authorizer type.

The client authenticates with Cognito, obtains a token, and supplies it—typically through the `Authorization` header—to API Gateway. ([AWS Documentation][9])

---

# 31. Lambda Authorizer

Sometimes authorization logic is custom.

Example:

```text
Request
  │
  ▼
API Gateway
  │
  ▼
Lambda Authorizer
  │
  ├── validate legacy token
  ├── consult custom policy DB
  ├── tenant lookup
  ├── Verify Permissions
  └── custom authorization
         │
         ▼
    Allow / Deny
```

Both HTTP APIs and REST APIs support Lambda-based authorizers. ([AWS Documentation][10])

---

# 32. Authorizer Caching

Lambda authorizers can cache authorization results.

This reduces:

```text
authorizer invocations

latency

cost
```

but creates an important security consideration:

```text
How long should authorization
remain cached?
```

For HTTP API Lambda authorizers, API Gateway uses configured identity sources as the authorizer cache key. ([AWS Documentation][11])

---

# 33. Caching Trap

Suppose:

```text
user loses admin privilege
```

but authorization result is cached for:

```text
10 minutes.
```

The user may continue receiving the cached authorization result during that TTL.

So:

```text
higher cache TTL
=
better performance

but potentially
slower permission revocation
```

Choose deliberately.

---

# 34. IAM / SigV4 Authorization

For machine-to-machine AWS-native communication, API Gateway can use:

```text
AWS_IAM
```

authorization.

The caller signs its request using:

# Signature Version 4

and needs:

```text
execute-api
```

permission for the route/API. HTTP APIs support this directly. ([AWS Documentation][12])

Architecture:

```text
EC2 / Lambda / CLI
      │
      ▼
IAM credentials
      │
      ▼
SigV4 signed request
      │
      ▼
API Gateway
      │
      ▼
IAM authorization
```

---

# 35. When IAM Auth Is Excellent

Use it when clients are:

```text
other AWS workloads

internal automation

CI/CD

AWS CLI

trusted service roles
```

and you already have IAM identity.

It is less natural when clients are ordinary consumers with no AWS identity.

---

# PART F — API KEYS & USAGE PLANS

# 36. API Keys Are NOT Authentication

This rule must be burned into memory.

AWS explicitly says:

> API keys should not be used for authentication or authorization.

Use IAM, Lambda authorizers, Cognito, JWT/OIDC mechanisms, etc., for real access control. ([AWS Documentation][13])

---

# 37. Then What Are API Keys For?

REST API usage plans use API keys primarily for:

```text
client identification

metering

usage tracking

per-client throttling

quotas
```

A usage plan associates API stages/methods and can define target request rates/quotas for clients identified by API keys. ([AWS Documentation][13])

---

# 38. Partner API Example

```text
Partner A
API Key A
   │
   └── 100 req/sec
       1M requests/month


Partner B
API Key B
   │
   └── 20 req/sec
       100k requests/month
```

This is a REST API use case.

But security can still be:

```text
OAuth/JWT
+
API key
```

where the key manages consumption and the token manages identity.

---

# PART G — THROTTLING

# 39. Why Throttle?

Without control:

```text
Client
  │
  ▼
1,000,000 req/sec
  │
  ▼
API Gateway
  │
  ▼
Lambda
  │
  ▼
RDS
        💥
```

API throttling protects:

```text
backend capacity

cost

availability

fairness
```

---

# 40. API Gateway Uses Token-Bucket-Style Throttling

For REST APIs, API Gateway applies throttling using token-bucket behavior involving:

```text
rate

+
burst
```

limits. ([AWS Documentation][14])

Think:

```text
Rate
=
sustained throughput target


Burst
=
temporary spike allowance
```

---

# 41. HTTP API Throttling

HTTP APIs support throttling at API/stage/route level, but AWS states throttling is:

```text
best effort
```

and should be treated as a target rather than an exact guaranteed ceiling. ([AWS Documentation][15])

This mirrors our WAF lesson:

```text
throttle target
≠
hard financial transaction limiter
```

---

# 42. Throttling Layers

A mature serverless application might have:

```text
API Gateway throttle
       │
       ▼
Lambda reserved concurrency
       │
       ▼
SQS buffering
       │
       ▼
DB connection limit
```

Each layer protects a different resource.

Never expect one throttle to solve all capacity problems.

---

# PART H — REQUEST VALIDATION

# 43. Bad Request

Client sends:

```json
{
  "title": 123,
  "unexpected": "..."
}
```

You may want to reject it before Lambda performs business work.

REST APIs provide API Gateway request-validation capabilities for request parameters and bodies/models. ([AWS Documentation][16])

---

# 44. Validation Architecture

```text
Client
  │
  ▼
API Gateway
  │
  ▼
Request Validator
  │
 ┌┴────────────┐
 │             │
valid        invalid
 │             │
 ▼             ▼
Lambda        4xx
```

Benefit:

```text
fewer bad Lambda invocations

consistent API contract

lower backend load
```

---

# 45. But Backend Validation Is Still Required

API Gateway validation is:

```text
edge/API-level defense
```

not a replacement for application validation.

The backend still needs to protect against:

```text
logical invalidity

authorization violations

unexpected states

direct/internal calls

business invariants
```

Defense in depth.

---

# PART I — API GATEWAY CACHING

# 46. REST API Cache

REST APIs support managed API caching.

```text
Client
  │
  ▼
API Gateway
  │
  ▼
Cache
  │
 ┌┴─────────┐
hit        miss
 │           │
 ▼           ▼
return     backend
cached      │
           ▼
         Lambda
```

Caching can reduce backend requests and improve response latency. ([AWS Documentation][17])

---

# 47. Good Cache Candidates

```text
GET /products

GET /catalog

GET /public/config
```

Bad or dangerous candidates without deliberate cache keys:

```text
GET /my-account

GET /my-balance
```

because user-specific responses could be mixed if cache-key design is wrong.

---

# PART J — REST API STAGES & DEPLOYMENTS

# 48. Deployment

For REST APIs, think:

```text
API configuration
      │
      ▼
Deployment snapshot
      │
      ▼
Stage
```

A stage is a named reference to a deployed API snapshot. It can carry settings for logging, throttling, caching, variables and canary behavior. ([AWS Documentation][18])

---

# 49. Typical Stages

```text
dev

staging

prod
```

Example URLs conceptually:

```text
.../dev/todos

.../staging/todos

.../prod/todos
```

With a custom domain you can hide or remap stage path details.

---

# 50. Stage Variables

REST stage variables behave like deployment-stage configuration variables.

Example:

```text
dev:
lambdaAlias=dev


prod:
lambdaAlias=prod
```

Then API integration can vary backend behavior by stage. ([AWS Documentation][19])

---

# 51. Don't Put Secrets in Stage Variables

Treat stage variables as configuration.

Not as:

```text
secret vault.
```

Use:

```text
Secrets Manager
Parameter Store
IAM
```

for sensitive material.

---

# PART K — CANARY RELEASES

# 52. REST API Canary Release

REST API stages support API Gateway canary deployments.

Conceptually:

```text
Production Stage
      │
      ├── 95%
      │    ▼
      │  current deployment
      │
      └── 5%
           ▼
         canary deployment
```

AWS supports attaching a new canary deployment to an existing production stage and gradually shifting traffic. ([AWS Documentation][20])

---

# 53. API Canary + Lambda Alias Canary

You can potentially have:

```text
API Gateway canary
```

and:

```text
Lambda weighted alias
```

but be careful.

Stacking two independent traffic splits can become difficult to reason about:

```text
API 10% canary
×
Lambda alias 10% new version

=
different effective traffic paths
```

Usually choose a clear deployment-control layer unless you have a deliberate multi-dimensional rollout design.

---

# PART L — CUSTOM DOMAINS

# 54. Default API Gateway URL

Without a custom domain your endpoint looks conceptually like:

```text
https://abc123.execute-api.ap-south-1.amazonaws.com
```

That works but isn't customer friendly.

Instead:

```text
https://api.yourdatascientist.tech
```

---

# 55. Regional Custom Domain

For a Regional API Gateway custom domain:

```text
API:
ap-south-1

ACM certificate:
ap-south-1
```

The certificate must be in the **same Region as the API/custom domain**. ([AWS Documentation][21])

This is different from CloudFront.

---

# 56. Your AWS Rule

For your usual architecture:

```text
Regional API Gateway
in ap-south-1
        │
        ▼
ACM certificate
in ap-south-1
```

But:

```text
CloudFront certificate
        │
        ▼
us-east-1
```

Keep those mental models separate.

---

# 57. Edge-Optimized REST Custom Domain

REST APIs can also use an:

```text
Edge-optimized
```

endpoint.

API Gateway creates/manages a CloudFront distribution in front of the API, and the associated ACM certificate must be in:

```text
us-east-1
```

for the edge-optimized custom domain. ([AWS Documentation][22])

---

# 58. REST Endpoint Types

REST APIs support:

```text
EDGE

REGIONAL

PRIVATE
```

endpoint types. ([AWS Documentation][23])

Mental model:

```text
EDGE
=
API Gateway-managed CloudFront path


REGIONAL
=
regional API endpoint


PRIVATE
=
accessible through VPC endpoint architecture
```

---

# 59. HTTP API Custom Domains

HTTP APIs use Regional custom domains and require the certificate in the API's Region. A Regional domain can map both HTTP and REST API stages. ([AWS Documentation][24])

---

# 60. Route 53 Mapping

Architecture:

```text
api.yourdatascientist.tech
       │
       ▼
Route 53 Alias
       │
       ▼
API Gateway Custom Domain
       │
       ▼
API Mapping
       │
       ▼
HTTP/REST Stage
```

API mappings let one custom domain route different paths to different APIs/stages. ([AWS Documentation][25])

Example:

```text
api.example.com/orders
      │
      ▼
Orders API


api.example.com/users
      │
      ▼
Users API
```

---

# PART M — PRIVATE APIs vs PRIVATE INTEGRATIONS

# 61. This Terminology Confuses Many Engineers

Two different things:

```text
PRIVATE API
```

versus:

```text
PRIVATE INTEGRATION
```

They are not the same.

---

# 62. Private REST API

A:

# Private API

means the API Gateway endpoint itself is privately reachable through VPC endpoint architecture instead of being public.

Current AWS support:

```text
Private API endpoints
=
REST APIs only
```

not HTTP APIs. ([AWS Documentation][26])

Architecture:

```text
Private EC2
   │
   ▼
execute-api
Interface VPC Endpoint
   │
   ▼
Private REST API
   │
   ▼
backend
```

---

# 63. HTTP API Private Integration

HTTP API may still be publicly callable while routing internally to a private backend.

Example:

```text
Internet Client
     │
     ▼
HTTP API
public endpoint
     │
     ▼
VPC Link
     │
     ▼
Internal ALB
     │
     ▼
ECS
```

HTTP API private integrations support VPC Link connectivity to private ALB/NLB listeners and AWS Cloud Map-discovered services. ([AWS Documentation][27])

---

# 64. Private API vs Private Backend

Remember:

```text
Private REST API

=
CLIENT → API Gateway
is private


HTTP/REST private integration

=
API Gateway → BACKEND
is private
```

That distinction appears frequently in architecture questions.

---

# PART N — WAF

# 65. API Gateway + WAF

AWS WAF can be directly associated with:

```text
API Gateway REST API stages
```

to help protect against application-layer attacks such as SQL injection and XSS. ([AWS Documentation][28])

Architecture:

```text
Internet
   │
   ▼
WAF
   │
   ▼
API Gateway REST API
   │
   ▼
Lambda
```

---

# 66. Why This Influences HTTP vs REST Selection

Suppose requirement says:

> “The API must be directly protected by an AWS WAF Web ACL.”

AWS's current REST-vs-HTTP feature comparison says:

```text
REST API
=
WAF support


HTTP API
=
not direct WAF feature
```

([AWS Documentation][2])

This can decide the API type immediately.

---

# 67. HTTP API + CloudFront/WAF Architecture

If you still want HTTP API simplicity but need edge/WAF controls, an architecture can instead be:

```text
Internet
   │
   ▼
CloudFront
   │
   ▼
AWS WAF
   │
   ▼
HTTP API
   │
   ▼
Lambda
```

But now you are explicitly operating another front-door layer and should ensure the API origin cannot be trivially bypassed if CloudFront is meant to enforce the policy.

---

# PART O — ACCESS LOGGING

# 68. API Gateway Access Logs

A production API should answer:

```text
Who called?

Which route?

When?

What status?

How long?

Which request ID?

Which client/source?

What authorization context?
```

API Gateway provides access logging using `$context` variables that you choose in the log format. ([AWS Documentation][29])

---

# 69. Structured JSON Logs

Good access log format conceptually:

```json
{
  "requestId": "$context.requestId",
  "ip": "$context.identity.sourceIp",
  "requestTime": "$context.requestTime",
  "httpMethod": "$context.httpMethod",
  "routeKey": "$context.routeKey",
  "status": "$context.status",
  "responseLength": "$context.responseLength"
}
```

Structured logs are much easier to query with:

```text
CloudWatch Logs Insights
```

than random plaintext.

---

# 70. Request ID Correlation

A very strong incident workflow:

```text
API Gateway request ID
         │
         ▼
Lambda log
         │
         ▼
trace ID
         │
         ▼
downstream logs
```

When possible, propagate your own correlation/request ID too:

```text
X-Correlation-Id
```

across services.

---

# 71. Do Not Log Authorization Secrets

Avoid storing:

```text
Bearer tokens

API secrets

cookies

passwords
```

in ordinary access/application logs.

Logging should create observability, not a second credential database.

---

# PART P — CLOUDWATCH METRICS & TRACING

# 72. API Gateway Metrics

Useful API operational metrics include categories such as:

```text
request counts

4xx

5xx

latency

integration latency
```

with API/stage dimensions depending on API type. API Gateway publishes CloudWatch metrics for monitoring request execution. ([AWS Documentation][30])

---

# 73. Latency vs Integration Latency

Conceptually:

```text
API Gateway Latency
=
full API Gateway processing path


Integration Latency
=
time waiting on backend integration
```

Example:

```text
Total latency:
900 ms

Integration latency:
850 ms
```

likely means:

```text
backend dominates.
```

Whereas:

```text
Total:
900 ms

Integration:
100 ms
```

means investigate API Gateway/authorizer/transformation/network behavior outside the backend itself.

---

# 74. REST API X-Ray

API Gateway REST API stages can enable active X-Ray tracing. ([AWS Documentation][31])

Architecture:

```text
Client
  │
  ▼
API Gateway
  │
  ▼
X-Ray trace
  │
  ▼
Lambda
  │
  ▼
DynamoDB
```

For new application instrumentation, continue following our previous lesson:

```text
OpenTelemetry / ADOT
```

for application-side tracing rather than starting new code on legacy X-Ray SDK instrumentation.

---

# PART Q — WEB SOCKET APIs

# 75. Why WebSocket?

Normal HTTP:

```text
Client
   │
   │ request
   ▼
Server
   │
   │ response
   ▼
Client

connection/request complete
```

WebSocket:

```text
Client
   ║
   ║ persistent connection
   ║
   ▼
Server

both sides can send
messages over connection
```

Good for:

```text
chat

live notifications

gaming events

live dashboards

collaboration

real-time updates
```

---

# 76. API Gateway WebSocket Routes

WebSocket APIs have three important predefined routes:

```text
$connect

$disconnect

$default
```

and you can create custom application routes. ([AWS Documentation][32])

---

# 77. `$connect`

Executed when a client establishes a WebSocket connection.

```text
Client
   │
   ▼
WebSocket upgrade
   │
   ▼
$connect
   │
   ▼
Lambda
   │
   ├── authenticate
   ├── store connection ID
   └── allow/deny
```

For WebSocket APIs, authorization is performed on the `$connect` route; because the WebSocket is stateful, auth happens when the connection is established rather than per later message route. ([AWS Documentation][33])

---

# 78. Store Connection IDs

A typical WebSocket system uses DynamoDB:

```text
$connect Lambda
      │
      ▼
DynamoDB
{
  userId,
  connectionId
}
```

Then when you need to notify the user:

```text
Event
  │
  ▼
Lambda
  │
  ▼
lookup connectionId
  │
  ▼
API Gateway Management API
  │
  ▼
send WebSocket message
```

---

# 79. `$disconnect`

When a connection ends:

```text
$disconnect
   │
   ▼
Lambda
   │
   ▼
delete connection record
```

AWS invokes `$disconnect` when the client/server connection closes, although real-time systems should always tolerate stale connection state and cleanup failures. ([AWS Documentation][34])

---

# 80. `$default`

If no custom route matches:

```text
message
  │
  ▼
$routeSelectionExpression
  │
  ▼
no match
  │
  ▼
$default
```

Useful for:

```text
unknown message types

generic processor

error handling
```

---

# PART R — OPENAPI

# 81. API as Code

Do not build a large production API exclusively by clicking:

```text
Create route
Create method
Create model
...
```

Use:

```text
Terraform

CloudFormation/SAM

OpenAPI
```

where appropriate.

API Gateway supports importing API definitions using OpenAPI with AWS-specific extensions for integrations and authorizers. ([AWS Documentation][35])

---

# 82. OpenAPI Example Concept

```yaml
openapi: 3.0.1

paths:
  /todos:
    get:
      responses:
        "200":
          description: OK

    post:
      responses:
        "201":
          description: Created
```

Then API Gateway-specific extensions can define:

```text
Lambda integration

authorizer

request configuration
```

This lets your API contract become version-controlled.

---

# PART S — TERRAFORM HTTP API

# 83. API Resource

The current HashiCorp AWS provider uses:

```text
aws_apigatewayv2_api
```

for HTTP and WebSocket APIs. ([Terraform Registry][36])

Example:

```hcl
resource "aws_apigatewayv2_api" "todo" {
  name          = "todo-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "https://app.yourdatascientist.tech"
    ]

    allow_methods = [
      "GET",
      "POST",
      "DELETE",
      "OPTIONS"
    ]

    allow_headers = [
      "authorization",
      "content-type"
    ]
  }
}
```

---

# 84. Lambda Integration

```hcl
resource "aws_apigatewayv2_integration" "todo" {
  api_id = aws_apigatewayv2_api.todo.id

  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.todo.invoke_arn

  integration_method = "POST"

  payload_format_version = "2.0"
}
```

`aws_apigatewayv2_integration` manages API Gateway v2 integrations, including Lambda proxy integrations. ([Terraform Registry][37])

---

# 85. Route

```hcl
resource "aws_apigatewayv2_route" "get_todos" {
  api_id = aws_apigatewayv2_api.todo.id

  route_key = "GET /todos"

  target = "integrations/${aws_apigatewayv2_integration.todo.id}"
}
```

The provider's v2 route resource supports HTTP API authorization modes such as `NONE`, `JWT`, `AWS_IAM`, and custom Lambda authorization. ([Terraform Registry][38])

---

# 86. Stage

```hcl
resource "aws_apigatewayv2_stage" "prod" {
  api_id = aws_apigatewayv2_api.todo.id

  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn =
      aws_cloudwatch_log_group.api.arn

    format = jsonencode({
      requestId = "$context.requestId"
      routeKey  = "$context.routeKey"
      status    = "$context.status"
      ip        = "$context.identity.sourceIp"
    })
  }
}
```

HTTP API stages are named references to deployed API lifecycle states such as dev/prod, with `$default` commonly used to expose routes without a stage path segment. ([AWS Documentation][39])

---

# 87. Lambda Permission

This step is frequently forgotten.

API Gateway needs permission to invoke the Lambda function:

```hcl
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.todo.function_name

  principal = "apigateway.amazonaws.com"

  source_arn =
    "${aws_apigatewayv2_api.todo.execution_arn}/*/*"
}
```

Otherwise:

```text
API Gateway configured
+
Lambda healthy

but

invocation denied.
```

---

# PART T — TERRAFORM JWT AUTHORIZER

# 88. HTTP API JWT Authorizer

```hcl
resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id = aws_apigatewayv2_api.todo.id

  authorizer_type = "JWT"

  name = "cognito-jwt"

  identity_sources = [
    "$request.header.Authorization"
  ]

  jwt_configuration {
    audience = [
      var.cognito_client_id
    ]

    issuer =
      "https://${aws_cognito_user_pool.pool.endpoint}"
  }
}
```

`aws_apigatewayv2_authorizer` supports JWT and request/Lambda authorizers for HTTP APIs. ([Terraform Registry][40])

---

# 89. Protected Route

```hcl
resource "aws_apigatewayv2_route" "create_todo" {
  api_id = aws_apigatewayv2_api.todo.id

  route_key = "POST /todos"

  target =
    "integrations/${aws_apigatewayv2_integration.todo.id}"

  authorization_type = "JWT"

  authorizer_id =
    aws_apigatewayv2_authorizer.jwt.id

  authorization_scopes = [
    "todos.write"
  ]
}
```

Now:

```text
request
  │
  ▼
JWT validation
  │
  ▼
scope todos.write?
  │
 ┌┴────┐
yes   no
 │     │
 ▼     ▼
Lambda 4xx
```

---

# PART U — CUSTOM DOMAIN TERRAFORM

# 90. Domain

For a Regional HTTP API in Mumbai:

```hcl
resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.yourdatascientist.tech"

  domain_name_configuration {
    certificate_arn =
      aws_acm_certificate.api.arn

    endpoint_type = "REGIONAL"

    security_policy = "TLS_1_2"
  }
}
```

The certificate must exist in `ap-south-1` because the HTTP API custom domain is Regional. ([AWS Documentation][21])

---

# 91. API Mapping

```hcl
resource "aws_apigatewayv2_api_mapping" "todo" {
  api_id = aws_apigatewayv2_api.todo.id

  domain_name =
    aws_apigatewayv2_domain_name.api.id

  stage =
    aws_apigatewayv2_stage.prod.id
}
```

API mappings connect a custom domain/path to an API stage. ([Terraform Registry][41])

---

# 92. Route 53

Conceptually:

```hcl
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id

  name = "api.yourdatascientist.tech"
  type = "A"

  alias {
    name =
      aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name

    zone_id =
      aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id

    evaluate_target_health = false
  }
}
```

Architecture:

```text
api.yourdatascientist.tech
        │
        ▼
Route 53
        │
        ▼
API Gateway
        │
        ▼
JWT
        │
        ▼
Lambda
```

---

# PART V — CLI HANDS-ON HTTP API

# 93. Goal

Build:

```text
curl
 │
 ▼
HTTP API
 │
 ▼
Lambda
 │
 ▼
JSON
```

Region:

```bash
export AWS_REGION=ap-south-1
```

---

# 94. Check Identity

```bash
aws sts get-caller-identity
```

Always start here.

---

# 95. Create HTTP API

Assuming Lambda already exists:

```bash
aws apigatewayv2 create-api \
  --name todo-http-api \
  --protocol-type HTTP \
  --region "$AWS_REGION"
```

Save:

```text
ApiId
```

---

# 96. Create Lambda Integration

```bash
aws apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --integration-type AWS_PROXY \
  --integration-uri "$LAMBDA_ARN" \
  --payload-format-version 2.0 \
  --region "$AWS_REGION"
```

HTTP API Lambda proxy integrations support payload versions `1.0` and `2.0`. ([AWS Documentation][5])

---

# 97. Create Route

```bash
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "GET /todos" \
  --target "integrations/$INTEGRATION_ID" \
  --region "$AWS_REGION"
```

---

# 98. Create `$default` Stage

```bash
aws apigatewayv2 create-stage \
  --api-id "$API_ID" \
  --stage-name '$default' \
  --auto-deploy \
  --region "$AWS_REGION"
```

---

# 99. Allow API Gateway to Invoke Lambda

```bash
aws lambda add-permission \
  --function-name todo-api \
  --statement-id apigateway-http-api \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn \
  "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/*"
```

---

# 100. Test

```bash
curl -i \
  "https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/todos"
```

Expected:

```text
HTTP/2 200
content-type: application/json
```

and your function response.

---

# PART W — PRODUCTION SERVERLESS API

# 101. Public Todo API Architecture

```text
                         INTERNET
                             │
                             ▼
                          Route 53
                             │
                             ▼
                      api.example.com
                             │
                             ▼
                        API Gateway
                             │
                  ┌──────────┼──────────┐
                  ▼          ▼          ▼
                CORS       JWT       Throttle
                  │          │          │
                  └──────────┼──────────┘
                             ▼
                           Routes
                             │
           ┌─────────────────┼────────────────┐
           ▼                 ▼                ▼
      GET /todos       POST /todos     DELETE /todos
           │                 │                │
           └─────────────────┼────────────────┘
                             ▼
                           Lambda
                             │
                 ┌───────────┼───────────┐
                 ▼           ▼           ▼
             DynamoDB       SQS     EventBridge
                             │
                             ▼
                       async workers


OBSERVABILITY
─────────────

API Gateway access logs
        +
Lambda structured logs
        +
CloudWatch Metrics
        +
OpenTelemetry traces
        +
CloudTrail configuration audit
```

---

# 102. Larger Enterprise REST Architecture

When features require REST:

```text
Internet
   │
   ▼
Route 53
   │
   ▼
Regional REST API
   │
   ├── WAF
   ├── Cognito/Lambda authorizer
   ├── API key
   ├── usage plan
   ├── request validator
   ├── cache
   ├── throttle
   └── access logs
        │
        ▼
      Lambda
        │
   ┌────┼────┐
   ▼    ▼    ▼
  DDB  SQS  RDS
```

REST APIs directly support WAF, request validation, usage plans/API keys, private endpoints and API Gateway caching—features that can justify their heavier model. ([AWS Documentation][2])

---

# PART X — TROUBLESHOOTING

# 103. `403 Forbidden`

Possible causes:

```text
JWT missing/invalid

IAM deny

API resource policy deny

API key invalid

WAF block

wrong stage/domain mapping
```

Don't jump directly to Lambda logs if API Gateway rejected the request before Lambda invocation.

Ask:

```text
Did Lambda even run?
```

---

# 104. `401 Unauthorized`

For JWT-protected HTTP APIs, inspect:

```text
Authorization header

Bearer token

issuer

audience

token expiry

scope

JWT signature/key
```

AWS's JWT authorizer troubleshooting guidance identifies invalid/missing token configuration as a common reason for `401 Unauthorized`. ([AWS Documentation][42])

---

# 105. `502 Bad Gateway`

For Lambda proxy integrations investigate:

```text
Lambda error?

invalid response shape?

function timeout?

backend exception?

integration permission?
```

A malformed Lambda proxy response is one documented cause of API Gateway returning `502`. ([AWS Documentation][6])

---

# 106. `504` / High Latency

Check:

```text
API Gateway latency

integration latency

Lambda Duration

Lambda cold-start/init

downstream DB/API latency

Lambda concurrency

VPC networking
```

Use:

```text
API Gateway
→ Lambda
→ trace
→ downstream metrics
```

instead of guessing.

---

# 107. Browser Fails but Curl Works

Suspect:

```text
CORS
```

Check:

```text
Origin

preflight OPTIONS

allowed headers

allowed methods

credentials

backend/API CORS behavior
```

For HTTP APIs, remember API Gateway's configured CORS behavior overrides backend CORS headers. ([AWS Documentation][7])

---

# 108. Custom Domain Shows Certificate Error

Check:

```text
certificate covers hostname?

certificate issued?

Regional or edge endpoint?

certificate correct Region?

DNS target correct?
```

Rule:

```text
Regional custom domain
→ certificate same Region


Edge-optimized REST
→ certificate us-east-1
```

([AWS Documentation][22])

---

# 109. Lambda Works When Invoked Directly but API Fails

Likely:

```text
API Gateway → Lambda permission
```

Check Lambda resource policy:

```bash
aws lambda get-policy \
  --function-name todo-api
```

Look for:

```text
Principal:
apigateway.amazonaws.com
```

and correct:

```text
SourceArn
```

---

# 110. API Is Being Hammered

Check:

```text
API Gateway Count

4xx

5xx

throttled requests

WAF logs if REST/WAF

Lambda concurrency

Lambda throttles

downstream capacity
```

Then consider:

```text
API throttle

REST usage plan

WAF rate rules

Lambda reserved concurrency
```

depending on threat versus legitimate workload.

---

# 111. API Key Leaked

Do not think:

```text
"Authentication has been compromised."
```

unless you incorrectly used the API key as authentication.

AWS explicitly says API keys should not be treated as authentication/authorization credentials. ([AWS Documentation][13])

Rotate the key for:

```text
usage tracking
quota/throttle identity
```

and separately investigate the actual auth mechanism.

---

# 112. Private Backend Returns Timeout

Architecture:

```text
HTTP API
  │
  ▼
VPC Link
  │
  ▼
ALB
  │
  ▼
ECS
```

Check:

```text
VPC Link status

ALB listener

target health

security groups

routing

backend port

integration URI
```

HTTP API private integrations use a VPC Link and the ALB/NLB listener ARN or Cloud Map service as the integration target. ([AWS Documentation][27])

---

# PART Y — CERTIFICATION / INTERVIEW SCENARIOS

# 113. Scenario

> Simple Lambda-backed JSON API, JWT auth, no caching/API keys/WAF requirement, minimize complexity.

Think:

```text
API Gateway HTTP API
```

AWS positions HTTP APIs as the lighter-weight option when the richer REST-specific management capabilities aren't needed. ([AWS Documentation][2])

---

# 114. Scenario

> Need API keys, usage plans, quotas and per-client throttling.

Think:

```text
REST API
```

Usage plans/API keys are a REST API capability. ([AWS Documentation][13])

---

# 115. Scenario

> Need AWS WAF directly on API Gateway.

Think:

```text
REST API
```

because WAF protection is directly supported for API Gateway REST APIs. ([AWS Documentation][28])

---

# 116. Scenario

> Need API reachable only privately through VPC endpoint.

Think:

```text
Private REST API
```

because API Gateway private API endpoints currently support REST APIs only. ([AWS Documentation][26])

---

# 117. Scenario

> Public API Gateway must reach internal ECS service behind private ALB.

Think:

```text
HTTP API
+
VPC Link
+
internal ALB
```

HTTP API private integrations support this design. ([AWS Documentation][27])

---

# 118. Scenario

> Need OAuth/OIDC JWT validation without running custom auth Lambda.

Think:

```text
HTTP API
+
JWT Authorizer
```

([AWS Documentation][8])

---

# 119. Scenario

> AWS workload needs to invoke API using its IAM role.

Think:

```text
AWS_IAM authorization
+
SigV4
+
execute-api permission
```

([AWS Documentation][12])

---

# 120. Scenario

> Need API Gateway to reject invalid request body before calling backend.

Think:

```text
REST API
+
request validator/model
```

([AWS Documentation][16])

---

# 121. Scenario

> Need API Gateway-native response caching.

Think:

```text
REST API caching
```

([AWS Documentation][17])

---

# 122. Scenario

> Need real-time chat with persistent clients.

Think:

```text
API Gateway WebSocket API
```

with:

```text
$connect
$disconnect
$default
custom routes
```

([AWS Documentation][32])

---

# 123. Scenario

> Edge-optimized REST custom domain in Mumbai. Where must certificate exist?

Answer:

```text
us-east-1
```

because the edge-optimized API Gateway custom domain uses an API Gateway-managed CloudFront distribution. ([AWS Documentation][43])

---

# 124. Scenario

> Regional API Gateway custom domain in Mumbai. Certificate Region?

Answer:

```text
ap-south-1
```

same Region as the Regional API/custom domain. ([AWS Documentation][21])

---

# 125. Scenario

> Lambda receives HTTP API event different from tutorial.

Check:

```text
payloadFormatVersion
```

because:

```text
1.0
≠
2.0
```

and their event structures differ. ([AWS Documentation][5])

---

# 126. Scenario

> Need controlled API traffic rollout without changing DNS.

For REST API:

```text
stage canary deployment
```

is one option. ([AWS Documentation][20])

For Lambda code rollout behind the API:

```text
Lambda version
+
weighted alias
```

may also be appropriate.

---

# PART Z — NEVER-FORGET DECISION TREE

```text
                   NEED AN API
                       │
                       ▼
              Request/response?
                 │           │
                YES          NO
                 │           │
                 ▼           ▼
         HTTP or REST      WebSocket
                 │
                 ▼
     Need WAF / API keys /
     usage plans / cache /
     validation / private
     API endpoint?
          │          │
         YES         NO
          │           │
          ▼           ▼
       REST API     HTTP API
```

Then security:

```text
Who is calling?
     │
     ├── End user with OIDC/JWT
     │       ▼
     │    JWT/Cognito
     │
     ├── AWS workload
     │       ▼
     │    IAM/SigV4
     │
     └── Custom legacy auth
             ▼
        Lambda Authorizer
```

Then backend:

```text
Where does API send request?
      │
      ├── Lambda
      ├── public HTTP backend
      ├── AWS service
      └── private ALB/NLB/Cloud Map
               │
               ▼
             VPC Link
```

---

# 127. 40 Rules to Burn Into Memory

```text
1. API Gateway is an API front door.

2. It supports REST, HTTP and WebSocket APIs.

3. HTTP APIs are leaner and generally simpler.

4. REST APIs provide richer API-management features.

5. Don't choose REST merely because the API is RESTful.

6. HTTP route = HTTP method + path.

7. Lambda proxy integration passes request context
   to Lambda.

8. HTTP Lambda proxy payload formats are 1.0 or 2.0.

9. Know which payload format your handler expects.

10. CORS is primarily browser-enforced.

11. HTTP APIs can manage CORS centrally.

12. JWT authorizers are excellent for OIDC/OAuth clients.

13. IAM auth requires SigV4 and execute-api permission.

14. Lambda authorizers support custom authorization.

15. Authorizer caching trades latency for revocation delay.

16. API keys are NOT authentication credentials.

17. API keys are primarily usage-plan/client-metering tools.

18. Usage plans are a REST API feature.

19. REST APIs support per-client usage-plan throttling.

20. Throttling is capacity protection, not perfect security.

21. API Gateway throttling is best effort.

22. REST APIs support request validation.

23. REST APIs support API Gateway-managed caching.

24. REST API stages reference deployment snapshots.

25. Stage variables are configuration, not secret storage.

26. REST stages support canary deployments.

27. Regional custom-domain ACM cert = same Region.

28. Edge-optimized REST cert = us-east-1.

29. REST endpoints can be Edge, Regional or Private.

30. Private API endpoint currently means REST API.

31. Private API and private integration are different concepts.

32. HTTP API can privately integrate through VPC Link.

33. HTTP private integrations support ALB/NLB/Cloud Map.

34. WAF directly protects REST API stages.

35. Access logs should be structured.

36. Don't log bearer tokens or secrets.

37. Monitor request count, errors and latency.

38. WebSocket authorization occurs on $connect.

39. Use IaC/OpenAPI for production APIs.

40. Always protect the backend from API traffic,
    not just the API Gateway itself.
```

---

# 128. Complete Production Architecture

```text
                           USERS

                       Web / Mobile
                            │
                            ▼
                         Route 53
                            │
                            ▼
               api.yourdatascientist.tech
                            │
                            ▼
                       API Gateway
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
           CORS            Auth         Throttle
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
            JWT           IAM          Lambda Auth
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                          Routes
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
          GET /todos    POST /todos   DELETE /todos
              │             │             │
              └─────────────┼─────────────┘
                            ▼
                          Lambda
                            │
                     reserved concurrency
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
         DynamoDB          SQS         EventBridge
                            │
                            ▼
                        Async workers


                  SECURITY / OBSERVABILITY

API Gateway Access Logs
          │
          ▼
CloudWatch Logs

API Metrics
          │
          ▼
CloudWatch Alarms

Application
          │
          ▼
OpenTelemetry / Traces

Configuration changes
          │
          ▼
CloudTrail
```

---

# 129. Final Production Checklist

Before calling an API “production ready,” verify:

```text
□ Correct API type chosen

□ Custom domain configured

□ TLS certificate correct Region

□ Authentication configured

□ Authorization/scopes designed

□ CORS intentionally restricted

□ Request validation where required

□ API throttling configured

□ Lambda concurrency protects dependencies

□ Secrets not stored in API/stage config

□ Access logs enabled

□ Sensitive headers not logged

□ CloudWatch alarms enabled

□ 4xx/5xx monitored

□ Latency monitored

□ Integration latency monitored

□ Lambda tracing/log correlation enabled

□ WAF if required

□ API Gateway → Lambda permission scoped

□ Deployment is version controlled

□ Terraform/OpenAPI stored in Git

□ Rollback strategy exists

□ Load testing performed

□ Failure/retry behavior understood

□ Downstream capacity tested
```

---

# ✅ Lesson 33 Part 3 Complete

You now understand:

```text
✓ API Gateway fundamentals
✓ API front-door architecture

✓ HTTP APIs
✓ REST APIs
✓ WebSocket APIs
✓ selection criteria

✓ methods
✓ paths
✓ routes
✓ route keys
✓ path parameters
✓ query parameters
✓ $default routes

✓ Lambda proxy integrations
✓ payload format 1.0
✓ payload format 2.0
✓ response structures
✓ 502 integration failures

✓ CORS
✓ browser origin behavior
✓ HTTP API CORS handling

✓ authentication
✓ authorization
✓ JWT authorizers
✓ Cognito
✓ Lambda authorizers
✓ authorizer caching
✓ IAM/SigV4

✓ API keys
✓ usage plans
✓ quotas
✓ per-client throttling
✓ API key security misconception

✓ API Gateway throttling
✓ rate
✓ burst
✓ token-bucket thinking

✓ request validation
✓ backend validation
✓ REST API caching

✓ REST deployments
✓ stages
✓ stage variables
✓ canary releases

✓ custom domains
✓ ACM
✓ Regional certificates
✓ edge-optimized certificates
✓ Route 53
✓ API mappings

✓ edge endpoints
✓ Regional endpoints
✓ private REST APIs
✓ private integrations
✓ VPC Links
✓ private ALB/NLB
✓ Cloud Map

✓ AWS WAF
✓ CloudFront/WAF alternative architecture

✓ access logging
✓ structured logs
✓ request IDs
✓ CloudWatch metrics
✓ X-Ray/API tracing

✓ WebSocket APIs
✓ $connect
✓ $disconnect
✓ $default
✓ persistent connections

✓ OpenAPI
✓ Terraform
✓ apigatewayv2
✓ Lambda permissions
✓ JWT Terraform
✓ custom-domain Terraform

✓ CLI hands-on
✓ production architecture
✓ troubleshooting
✓ certification scenarios
```

# ✅ Lesson 33 — AWS Lambda & API Gateway COMPLETE

You have now built the complete serverless request-processing model:

```text
                          CLIENT
                            │
                            ▼
                       API Gateway
                            │
                            ▼
                         Lambda
                            │
          ┌─────────────────┼────────────────┐
          ▼                 ▼                ▼
       DynamoDB            SQS           EventBridge
                            │
                            ▼
                    Event Source Mapping
                            │
                            ▼
                         Lambda
                            │
                       idempotency
                            │
                            ▼
                       downstream


                RELIABILITY CONTROLS

             retries
               +
             DLQs
               +
          destinations
               +
          concurrency
               +
          backpressure
               +
          observability
```

---

# Next — Lesson 34

# **AWS Messaging & Event-Driven Architecture — SQS, SNS, EventBridge & Step Functions in Depth**

We used SQS and EventBridge as Lambda integrations already.

Now we'll stop treating them as “Lambda triggers” and learn them as independent distributed-system building blocks:

```text
                         PRODUCER
                            │
             ┌──────────────┼───────────────┐
             ▼              ▼               ▼
            SQS            SNS          EventBridge
             │              │               │
             │          fan-out           routing
             │              │               │
             ▼              ▼               ▼
          Worker        subscribers       targets


                          WORKFLOW
                            │
                            ▼
                     Step Functions
                            │
               ┌────────────┼────────────┐
               ▼            ▼            ▼
            Lambda        ECS          AWS APIs
               │            │            │
               └────────────┼────────────┘
                            ▼
                    durable orchestration
```

Next we'll go deep into **queueing theory, Standard vs FIFO SQS, visibility timeout, long polling, delay queues, retention, DLQs/redrive, SNS fan-out, filtering, FIFO topics, raw delivery, EventBridge buses/rules/Pipes/Scheduler/schema routing, SNS vs SQS vs EventBridge decision-making, choreography vs orchestration, Step Functions Standard vs Express workflows, state types, retries/catches, Map/Distributed Map, callback tokens, service integrations, compensation/Saga patterns, Terraform, and a full production order-processing architecture.**

[1]: https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html?utm_source=chatgpt.com "Amazon API Gateway - AWS Documentation"
[2]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html?utm_source=chatgpt.com "Choose between REST APIs and HTTP APIs"
[3]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-access-control.html?utm_source=chatgpt.com "Control and manage access to HTTP APIs in API Gateway"
[4]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-routes.html?utm_source=chatgpt.com "Create routes for HTTP APIs in API Gateway - AWS Documentation"
[5]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html?utm_source=chatgpt.com "Create AWS Lambda proxy integrations for HTTP APIs in ..."
[6]: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html?utm_source=chatgpt.com "Lambda proxy integrations in API Gateway"
[7]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-cors.html?utm_source=chatgpt.com "Configure CORS for HTTP APIs in API Gateway - AWS Documentation"
[8]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html?utm_source=chatgpt.com "Control access to HTTP APIs with JWT authorizers in API ..."
[9]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-integrate-with-cognito.html?utm_source=chatgpt.com "Control access to REST APIs using Amazon Cognito user ..."
[10]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html?utm_source=chatgpt.com "Use API Gateway Lambda authorizers"
[11]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-lambda-authorizer.html?utm_source=chatgpt.com "Control access to HTTP APIs with AWS Lambda authorizers"
[12]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-access-control-iam.html?utm_source=chatgpt.com "Control access to HTTP APIs with IAM authorization in API ..."
[13]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html?utm_source=chatgpt.com "Usage plans and API keys for REST APIs in API Gateway"
[14]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html?utm_source=chatgpt.com "Throttle requests to your REST APIs for better throughput in ..."
[15]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-throttling.html?utm_source=chatgpt.com "Throttle requests to your HTTP APIs for better throughput in ..."
[16]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-method-request-validation.html?utm_source=chatgpt.com "Request validation for REST APIs in API Gateway"
[17]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-caching.html?utm_source=chatgpt.com "Cache settings for REST APIs in API Gateway"
[18]: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-stages.html?utm_source=chatgpt.com "Set up a stage for a REST API in API Gateway"
[19]: https://docs.aws.amazon.com/apigateway/latest/developerguide/stage-variables.html?utm_source=chatgpt.com "Use stage variables for a REST API in API Gateway"
[20]: https://docs.aws.amazon.com/apigateway/latest/developerguide/canary-release.html?utm_source=chatgpt.com "Set up an API Gateway canary release deployment"
[21]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-regional-api-custom-domain-create.html?utm_source=chatgpt.com "Set up a Regional custom domain name in API Gateway"
[22]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-specify-certificate-for-custom-domain-name.html?utm_source=chatgpt.com "Get certificates ready in AWS Certificate Manager"
[23]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-endpoint-types.html?utm_source=chatgpt.com "API endpoint types for REST APIs in API Gateway"
[24]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-custom-domain-names.html?utm_source=chatgpt.com "Custom domain names for HTTP APIs in API Gateway"
[25]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-mappings.html?utm_source=chatgpt.com "Map API stages to a custom domain name for HTTP APIs"
[26]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-private-apis.html?utm_source=chatgpt.com "Private REST APIs in API Gateway"
[27]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-private.html?utm_source=chatgpt.com "Create private integrations for HTTP APIs in API Gateway"
[28]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-control-access-aws-waf.html?utm_source=chatgpt.com "Use AWS WAF to protect your REST APIs in API Gateway"
[29]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-variables-for-access-logging.html?utm_source=chatgpt.com "Variables for access logging for API Gateway"
[30]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-metrics-and-dimensions.html?utm_source=chatgpt.com "Amazon API Gateway dimensions and metrics"
[31]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-enabling-xray.html?utm_source=chatgpt.com "Set up AWS X-Ray with API Gateway REST APIs"
[32]: https://docs.aws.amazon.com/apigateway/latest/developerguide/websocket-api-develop-routes.html?utm_source=chatgpt.com "Create routes for WebSocket APIs in API Gateway"
[33]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api-route-keys-connect-disconnect.html?utm_source=chatgpt.com "$connect and $disconnect routes - Amazon API Gateway"
[34]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api-overview.html?utm_source=chatgpt.com "Overview of WebSocket APIs in API Gateway"
[35]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-as-lambda-proxy-export-swagger-with-extensions.html?utm_source=chatgpt.com "OpenAPI definitions of sample API integrated with a ..."
[36]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api?utm_source=chatgpt.com "aws_apigatewayv2_api | Resources | hashicorp/aws | Terraform"
[37]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration?utm_source=chatgpt.com "aws_apigatewayv2_integration | Resources | hashicorp/aws"
[38]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route.html?utm_source=chatgpt.com "aws_apigatewayv2_route | Resources | hashicorp/aws"
[39]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-stages.html?utm_source=chatgpt.com "Stages for HTTP APIs in API Gateway"
[40]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_authorizer?utm_source=chatgpt.com "aws_apigatewayv2_authorizer | Resources | hashicorp/aws"
[41]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api_mapping?utm_source=chatgpt.com "aws_apigatewayv2_api_mapping | Resources | hashicorp/aws"
[42]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-troubleshooting-jwt.html?utm_source=chatgpt.com "Troubleshooting issues with HTTP API JWT authorizers"
[43]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-edge-optimized-custom-domain-name.html?utm_source=chatgpt.com "Set up an edge-optimized custom domain name in API Gateway"
