# AWS Masterclass — Phase 3

# Lesson 42: Amazon API Gateway Production Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Choose between REST, HTTP and WebSocket APIs.
* Design resources, methods, routes, integrations, deployments and stages.
* Integrate API Gateway with Lambda, HTTP services and AWS services.
* Expose private ECS, EKS and EC2 applications through VPC links.
* Configure request and response transformations.
* Implement IAM, JWT, Cognito and Lambda authorization.
* Protect APIs using resource policies, private endpoints, mutual TLS and WAF.
* Configure throttling, quotas and usage plans.
* Use custom domains and API mappings.
* Implement API caching.
* Deploy API changes through stages and canary releases.
* Monitor latency, errors and backend performance.
* Troubleshoot `401`, `403`, `429`, `502` and `504` errors.
* Build API Gateway infrastructure using Terraform.

---

# 2. What is Amazon API Gateway?

Amazon API Gateway is a managed service for creating, publishing, securing, monitoring and operating:

```text
REST APIs
HTTP APIs
WebSocket APIs
```

API Gateway can route requests to Lambda functions, public HTTP endpoints, private VPC workloads and supported AWS service actions. ([AWS Documentation][1])

Basic architecture:

```text
Client
  |
  | HTTPS request
  v
Amazon API Gateway
  |
  ├── Authentication and authorization
  ├── Request validation
  ├── Throttling
  ├── Routing
  ├── Transformation
  ├── Logging
  └── Monitoring
          |
          v
Backend integration
```

Possible backends:

```text
AWS Lambda
Application Load Balancer
Network Load Balancer
ECS or EKS service
EC2-hosted application
Public HTTP service
Selected AWS service API
```

---

# 3. API Gateway is an API frontend

API Gateway is not normally where your complete application logic lives.

Its role is to sit between clients and backends:

```text
Internet or private client
          |
          v
API Gateway
          |
          v
Application backend
```

API Gateway responsibilities can include:

```text
TLS termination
Authentication
Authorization
Routing
Rate limiting
Request validation
Transformation
Access logging
Custom domain handling
```

Backend responsibilities include:

```text
Business logic
Database transactions
Domain validation
Long-running processing
Persistent state
```

---

# 4. API Gateway API types

API Gateway offers three major API products:

```text
REST API
HTTP API
WebSocket API
```

REST and HTTP APIs both expose request-response HTTP endpoints. WebSocket APIs provide stateful, full-duplex communication in which clients and backends can send messages independently after establishing a connection. ([AWS Documentation][1])

---

# 5. REST API

REST APIs provide the broadest API Gateway feature set.

Choose REST APIs when you need features such as:

* API keys.
* Usage plans.
* Per-client throttling and quotas.
* Request validation.
* Mapping templates.
* API Gateway-managed response caching.
* Direct AWS WAF association.
* Private API endpoints.
* Edge-optimized endpoints.
* REST API canary deployments.
* Detailed gateway-response customization.
* X-Ray active tracing.

AWS specifically recommends REST APIs when these advanced API-management capabilities are required. ([AWS Documentation][2])

---

# 6. HTTP API

HTTP APIs provide a simpler, lower-cost API Gateway product for common API use cases.

They support capabilities such as:

* Lambda integrations.
* Public HTTP integrations.
* Private VPC integrations.
* JWT authorizers.
* Lambda authorizers.
* IAM authorization.
* Built-in CORS configuration.
* Automatic deployment.
* Custom domains.
* Stage and route throttling.

HTTP APIs provide fewer advanced management features than REST APIs but are often the best choice for straightforward serverless APIs and service proxies. ([AWS Documentation][3])

---

# 7. REST API versus HTTP API

| Requirement                  |                      HTTP API |               REST API |
| ---------------------------- | ----------------------------: | ---------------------: |
| Lambda proxy integration     |                           Yes |                    Yes |
| Public HTTP backend          |                           Yes |                    Yes |
| Private ALB/NLB integration  |                           Yes |                    Yes |
| IAM authorization            |                           Yes |                    Yes |
| Lambda authorizer            |                           Yes |                    Yes |
| Native JWT authorizer        |                           Yes |                     No |
| Cognito user-pool authorizer |             Through JWT model | Native REST authorizer |
| API keys                     |                            No |                    Yes |
| Usage plans                  |                            No |                    Yes |
| Per-client quota             |                            No |                    Yes |
| Request validation           | No comparable managed feature |                    Yes |
| Mapping templates            |     Limited parameter mapping |           Advanced VTL |
| Managed API cache            |                            No |                    Yes |
| Direct AWS WAF association   |                            No |                    Yes |
| Private API endpoint         |                            No |                    Yes |
| REST canary deployment       |                            No |                    Yes |
| Built-in CORS automation     |                           Yes |            More manual |
| X-Ray active tracing         |                            No |                    Yes |

The definitive feature comparison identifies API keys, per-client throttling, request validation, WAF integration and private API endpoints as reasons to choose REST APIs. ([AWS Documentation][2])

## Selection rule

```text
Simple Lambda or HTTP API with JWT authentication?
    → HTTP API

Need API keys, caching, request validation or WAF?
    → REST API

Need real-time two-way communication?
    → WebSocket API
```

---

# 8. WebSocket API

A WebSocket API creates a persistent, full-duplex connection.

```text
Client
  |
  | WebSocket handshake
  v
API Gateway WebSocket API
  |
  v
Backend integration
```

After connection establishment:

```text
Client → Backend messages
Backend → Client callback messages
```

Common use cases:

* Chat systems.
* Live dashboards.
* Real-time notifications.
* Multiplayer applications.
* Collaborative tools.
* Progress updates.
* Device status.
* AI response streaming patterns.

WebSocket APIs route messages according to message content and support backend callbacks through the API Gateway Management API. ([AWS Documentation][4])

---

# 9. WebSocket routes

WebSocket APIs include three predefined route concepts:

```text
$connect
$disconnect
$default
```

You can also define custom routes.

```text
$connect:
Runs when the connection is established.

$disconnect:
Runs when the connection is closed.

$default:
Runs when no custom route matches.

Custom route:
Runs based on the route-selection expression.
```

For example:

```json
{
  "action": "sendMessage",
  "message": "Hello"
}
```

Route-selection expression:

```text
$request.body.action
```

Matching route:

```text
sendMessage
```

API Gateway evaluates the route key from the message and invokes the corresponding integration. ([AWS Documentation][5])

---

# 10. WebSocket connection limits

API Gateway WebSocket connections currently have:

```text
Idle timeout:
10 minutes

Maximum connection lifetime:
2 hours
```

Clients should implement reconnection and heartbeat behavior rather than assuming a permanent connection. ([AWS Documentation][5])

Example heartbeat:

```text
Client
  |
  | ping every few minutes
  v
WebSocket API
```

Store connection information externally:

```text
connectionId
userId
tenantId
subscription groups
expiration
```

DynamoDB is commonly used for this connection registry.

---

# 11. API lifecycle components

The main API Gateway concepts are:

```text
API
Route or resource
Method
Integration
Deployment
Stage
Custom domain
API mapping
```

For a REST API:

```text
Resource:
  /todos

Method:
  GET

Integration:
  Lambda function

Deployment:
  Immutable API snapshot

Stage:
  production
```

For an HTTP API:

```text
Route:
  GET /todos

Integration:
  Lambda function

Stage:
  production
```

---

# 12. REST resources and methods

REST APIs use a resource hierarchy:

```text
/
└── todos
    ├── GET
    ├── POST
    └── {todoId}
        ├── GET
        ├── PUT
        └── DELETE
```

Each HTTP method can have its own:

* Authorization.
* Request validator.
* Integration.
* Throttling.
* Cache configuration.
* Response mapping.

A REST API is formally a collection of resources and methods connected to backend integrations. ([AWS Documentation][6])

---

# 13. HTTP API routes

HTTP APIs define a route using:

```text
HTTP method + path
```

Examples:

```text
GET /todos
POST /todos
GET /todos/{todoId}
DELETE /todos/{todoId}
```

A special route is:

```text
$default
```

It handles requests that do not match another route.

Example:

```text
ANY /{proxy+}
```

can route many paths through one proxy integration, but explicit route definitions often provide clearer authorization and observability.

---

# 14. Integration types

API Gateway integration types include:

```text
Lambda proxy integration
Lambda non-proxy integration
HTTP proxy integration
HTTP custom integration
AWS service integration
Private integration
Mock integration
```

An integration endpoint can be a Lambda function, an HTTP service or a supported AWS service action. ([AWS Documentation][7])

---

# 15. Lambda proxy integration

Lambda proxy integration passes a standardized representation of the incoming request to Lambda.

```text
Client request
      |
      v
API Gateway
      |
      | Headers, path, query, body and context
      v
Lambda
```

Lambda returns the response:

```json
{
  "statusCode": 200,
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"message\":\"success\"}"
}
```

Lambda proxy is the preferred Lambda integration for most applications because the function receives the full request context and controls the HTTP response. ([AWS Documentation][8])

---

# 16. HTTP API payload-format versions

For HTTP API Lambda integrations, the payload-format version determines the request and response structure.

Common versions:

```text
1.0
2.0
```

Version `2.0` is the modern, more compact HTTP API format.

Terraform:

```hcl
integration_type       = "AWS_PROXY"
integration_uri        = aws_lambda_function.todo_api.invoke_arn
payload_format_version = "2.0"
```

When creating HTTP API Lambda integrations through the CLI, SDK or CloudFormation, you must explicitly define the payload-format version. ([AWS Documentation][9])

---

# 17. Lambda non-proxy integration

A non-proxy REST integration lets API Gateway transform both the request and response.

```text
Client payload
      |
      v
Mapping template
      |
      v
Lambda-specific payload
```

Response:

```text
Lambda result
      |
      v
Integration response mapping
      |
      v
Client response
```

This is useful when:

* The external API contract differs from the backend contract.
* The backend cannot be changed.
* Different backend errors must become specific HTTP responses.
* Legacy payload transformation is required.

REST non-proxy integrations require more configuration and use mapping templates or parameter mappings. ([AWS Documentation][10])

---

# 18. Velocity Template Language

REST API mapping templates use Apache Velocity Template Language, or VTL.

Example:

```vtl
{
  "todoId": "$input.params('todoId')",
  "requestId": "$context.requestId",
  "body": $input.json('$')
}
```

VTL can transform:

* Headers.
* Query parameters.
* Path parameters.
* Request bodies.
* Integration responses.

Keep templates small and version controlled. Complex business logic belongs in application code, not in VTL.

---

# 19. HTTP proxy integration

HTTP proxy integration forwards requests to an HTTP backend with minimal transformation.

```text
Client
  |
  v
API Gateway
  |
  v
HTTP backend
```

Examples:

```text
Public API service
ALB
NLB
ECS application
EKS ingress
EC2-hosted application
```

Proxy integration is simpler, while custom HTTP integration provides more control over request and response transformations. ([AWS Documentation][11])

---

# 20. Direct AWS service integration

A REST API can call selected AWS service operations without an intermediate Lambda function.

Examples:

```text
API Gateway → SQS SendMessage
API Gateway → Step Functions StartExecution
API Gateway → DynamoDB PutItem
API Gateway → Kinesis PutRecord
```

Architecture:

```text
Client
  |
  v
API Gateway
  |
  | Assumes integration role
  v
AWS service API
```

Benefits:

* Fewer components.
* No Lambda cold start.
* Lower operational overhead.
* Direct IAM-controlled integration.

Use Lambda when validation, transformation or business logic exceeds API Gateway’s safe mapping capabilities.

---

# 21. Private integration

A private integration lets a public API Gateway endpoint securely invoke resources inside a VPC.

```text
Internet client
      |
      v
API Gateway
      |
      v
VPC link
      |
      v
Private ALB or NLB
      |
      v
ECS, EKS or EC2 application
```

VPC links V2 support private integrations for HTTP and REST APIs. HTTP APIs can integrate with an ALB, NLB or AWS Cloud Map service; REST VPC links V2 support ALB and NLB integrations, while Cloud Map is not supported for REST private integrations. ([AWS Documentation][12])

---

# 22. TodoApp private integration

```text
Users
  |
  v
api.yourdatascientist.tech
  |
  v
API Gateway HTTP API
  |
  v
VPC Link V2
  |
  v
Internal ALB
  |
  v
ECS TodoApp backend
```

Benefits:

* Backend containers remain private.
* No public ALB required.
* API Gateway handles client authentication.
* ALB performs target routing and health checks.
* ECS scales independently.

---

# 23. Private API versus private integration

These terms are different.

## Private API endpoint

```text
Private client
      |
      v
Interface VPC endpoint
      |
      v
Private API Gateway REST API
```

The API itself is not publicly reachable.

## Private integration

```text
Public or private API Gateway endpoint
      |
      v
VPC link
      |
      v
Private backend
```

The frontend may be public while the backend remains private.

## Memory trick

```text
Private API:
Who can reach API Gateway?

Private integration:
How does API Gateway reach the backend?
```

---

# 24. Integration timeout

HTTP API integrations have a maximum integration timeout of 30 seconds. WebSocket integration timeouts are between 50 milliseconds and 29 seconds. REST API integrations normally default to 29 seconds; Regional and private REST APIs can request or configure longer timeouts within applicable quotas. ([AWS Documentation][13])

Do not hold an API request open for a long business process.

Bad:

```text
Client waits
  |
  v
API Gateway
  |
  v
15-minute processing job
```

Better:

```text
POST /reports
      |
      v
Validate request
      |
      v
Send SQS message
      |
      v
Return 202 Accepted
```

Response:

```json
{
  "jobId": "job-104",
  "status": "ACCEPTED"
}
```

The client later checks:

```text
GET /reports/job-104
```

---

# 25. Response streaming

Regional REST APIs now support streaming integration responses for compatible `HTTP_PROXY` and `AWS_PROXY` integrations.

This can improve time to first byte and support responses that remain active beyond the ordinary buffered integration pattern. ([AWS Documentation][14])

Possible use cases:

* AI-generated responses.
* Progressive data generation.
* Large streamed HTTP responses.
* Long-running streamed backend output.

Do not confuse streaming with unlimited backend duration or unlimited payload size. Validate the complete chain, including Lambda, CloudFront and client timeouts.

---

# 26. Payload size

The maximum request payload size for REST and HTTP APIs is currently:

```text
10 MB
```

This quota is fixed for REST APIs and documented for HTTP APIs. ([AWS Documentation][15])

For large uploads:

```text
Client
  |
  | Request presigned URL
  v
API Gateway + Lambda
  |
  v
Presigned S3 URL
```

Then:

```text
Client
  |
  | Direct upload
  v
Amazon S3
```

Do not send 500-MB files through API Gateway.

---

# 27. Request validation

REST APIs can perform basic request validation before invoking the backend.

Validation can check:

* Required headers.
* Required query parameters.
* Required path parameters.
* Request body against a model schema.

If validation fails, API Gateway can return `400 Bad Request` without calling the integration. ([AWS Documentation][16])

Example schema:

```json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "CreateTodo",
  "type": "object",
  "required": [
    "title"
  ],
  "properties": {
    "title": {
      "type": "string",
      "minLength": 1
    },
    "priority": {
      "type": "string",
      "enum": [
        "LOW",
        "MEDIUM",
        "HIGH"
      ]
    }
  }
}
```

---

# 28. Gateway validation is not enough

API Gateway validation handles the external contract.

Your backend must still validate:

* Business rules.
* Authorization ownership.
* Database constraints.
* Cross-field dependencies.
* Current resource state.
* Tenant boundaries.

Example:

```text
API Gateway:
priority is a valid string.

Backend:
User is permitted to create a HIGH-priority todo.
```

---

# 29. Cross-Origin Resource Sharing

CORS controls whether browser-based JavaScript from one origin can call an API hosted at another origin.

Example:

```text
Frontend:
https://app.yourdatascientist.tech

API:
https://api.yourdatascientist.tech
```

HTTP APIs have built-in CORS configuration. REST APIs require CORS headers and often an `OPTIONS` preflight method or corresponding proxy-backend behavior. ([AWS Documentation][3])

---

# 30. Secure CORS configuration

Production example:

```text
Allowed origin:
https://app.yourdatascientist.tech

Allowed methods:
GET, POST, PUT, DELETE, OPTIONS

Allowed headers:
Authorization, Content-Type, X-Request-Id

Allow credentials:
Only when required
```

Avoid:

```text
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
```

Browsers prohibit this insecure combination, and it represents overly broad access intent.

Remember:

```text
CORS is browser enforcement.

CORS is not API authentication.
```

A nonbrowser client can call the endpoint regardless of browser CORS policy.

---

# 31. Deployments and stages

A deployment is a snapshot of API configuration.

A stage is a named reference to a deployment or API lifecycle state.

```text
API configuration
      |
      v
Deployment 42
      |
      v
Stage: production
```

Common stages:

```text
development
testing
staging
production
```

HTTP API stages can use automatic deployment so route or integration changes become available without manually creating a deployment. ([AWS Documentation][17])

---

# 32. Separate account versus separate stage

Stages can separate API versions:

```text
/dev
/staging
/prod
```

But stages are not a replacement for AWS-account isolation.

Preferred production design:

```text
Development AWS account
  └── development API

Staging AWS account
  └── staging API

Production AWS account
  └── production API
```

Use stages primarily for API lifecycle or controlled versions inside the same environment—not as your only production security boundary.

---

# 33. Stage variables

Stage variables provide stage-specific string values.

Example:

```text
development:
lambdaAlias = development

production:
lambdaAlias = production
```

Integration URI can reference the stage variable:

```text
${stageVariables.lambdaAlias}
```

REST and HTTP APIs support stage variables for integration configuration. ([AWS Documentation][18])

Do not store secrets in stage variables.

Use:

```text
Secrets Manager
Parameter Store
AppConfig
```

---

# 34. REST canary deployment

REST APIs support stage-level canary releases.

Example:

```text
Production deployment:
90% traffic

Canary deployment:
10% traffic
```

Canary settings can also override stage variables, allowing the canary to invoke a different Lambda alias or backend. ([AWS Documentation][19])

Canary workflow:

```text
1. Deploy new API configuration as canary.
2. Route 5% of requests.
3. Monitor errors and latency.
4. Increase to 25%.
5. Increase to 100%.
6. Promote or roll back.
```

---

# 35. API Gateway canary versus Lambda alias canary

You may perform gradual deployment at two layers.

## API Gateway canary

Tests:

* Routes.
* Mapping templates.
* Authorizers.
* API configuration.
* Integration selection.
* Stage variables.

## Lambda weighted alias

Tests:

* Function code.
* Lambda configuration.
* Runtime changes.
* Dependency changes.

For a simple Lambda proxy API, a Lambda weighted alias is often enough. For API-contract or routing changes, use an API Gateway canary or a separate API version.

---

# 36. Custom domains

Default API URL:

```text
https://abc123.execute-api.ap-south-1.amazonaws.com/production
```

Custom domain:

```text
https://api.yourdatascientist.tech
```

Custom domains provide:

* Stable client-facing hostname.
* TLS certificate management.
* API mappings.
* Cleaner URLs.
* Separation from generated API IDs.

Both REST and HTTP APIs support custom domains. ([AWS Documentation][20])

---

# 37. ACM certificate Region

For a Regional API Gateway custom domain:

```text
Certificate Region:
Same Region as the API
```

For an edge-optimized REST API custom domain:

```text
Certificate Region:
us-east-1
```

This is because edge-optimized API Gateway endpoints use a managed CloudFront distribution. ([AWS Documentation][21])

For your preferred deployment:

```text
Regional API:
ap-south-1

ACM certificate:
ap-south-1
```

For an edge-optimized REST API:

```text
ACM certificate:
us-east-1
```

---

# 38. Regional versus edge-optimized REST endpoints

REST API endpoint types include:

```text
Regional
Edge-optimized
Private
```

## Regional

Best when:

* Clients are mainly near the API Region.
* You use your own CloudFront distribution.
* You need Regional control.
* Multi-Region routing is implemented externally.

## Edge-optimized

Uses an API Gateway-managed CloudFront distribution and is intended for geographically distributed clients.

## Private

Accessible through an interface VPC endpoint rather than the public internet. ([AWS Documentation][22])

---

# 39. Custom domain API mappings

One custom domain can map paths to multiple APIs or stages.

```text
api.yourdatascientist.tech/todos
    → Todo REST API

api.yourdatascientist.tech/users
    → User HTTP API

api.yourdatascientist.tech/admin
    → Admin API
```

HTTP API mappings require an API, stage and custom domain. ([AWS Documentation][23])

This gives clients one stable domain while backends evolve independently.

---

# 40. Disable the default endpoint

After configuring a custom domain, disable the generated `execute-api` endpoint.

```text
Allowed:
https://api.yourdatascientist.tech

Disabled:
https://abc123.execute-api.ap-south-1.amazonaws.com
```

REST, HTTP and WebSocket APIs support disabling the default endpoint. Requests to a disabled REST default endpoint receive `403 Forbidden`. ([AWS Documentation][24])

Benefits:

* Clients must use the controlled hostname.
* WAF or CloudFront cannot be bypassed through the generated URL.
* Certificate and routing policy are centralized.
* Public API inventory becomes cleaner.

---

# 41. API authorization models

Common API Gateway authorization options are:

```text
NONE
AWS IAM
JWT authorizer
Amazon Cognito user-pool authorizer
Lambda authorizer
Resource policy
Mutual TLS
```

Authorization choices differ by API type.

---

# 42. IAM authorization

IAM authorization requires callers to sign requests using AWS Signature Version 4.

```text
AWS identity
      |
      | Signed request
      v
API Gateway
      |
      | execute-api:Invoke evaluation
      v
Backend
```

Best for:

* Service-to-service APIs.
* Internal AWS automation.
* CLI or SDK clients.
* Cross-account AWS workloads.
* Administrative APIs.

REST and HTTP APIs support IAM authorization. ([AWS Documentation][25])

---

# 43. IAM invocation policy

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:ap-south-1:123456789012:abc123/production/GET/todos/*"
    }
  ]
}
```

This can be attached to:

* IAM role.
* IAM Identity Center permission set.
* EC2 role.
* Lambda role.
* ECS task role.
* Cross-account application role.

---

# 44. JWT authorizers

HTTP API JWT authorizers validate tokens issued through OAuth 2.0 or OpenID Connect identity providers.

API Gateway validates token properties and can enforce authorization scopes on individual routes. ([AWS Documentation][26])

Architecture:

```text
User
  |
  v
Cognito or OIDC provider
  |
  | JWT access token
  v
HTTP API JWT authorizer
  |
  v
Lambda or HTTP backend
```

Route example:

```text
GET /todos:
Required scope = todos/read

POST /todos:
Required scope = todos/write
```

---

# 45. Access tokens versus ID tokens

Use access tokens for API authorization.

```text
Access token:
What may the client access?

ID token:
Who authenticated?
```

API Gateway notes that JWT structure alone does not always provide a standard method to distinguish an access token from an ID token. Configure:

* Correct issuer.
* Correct audience.
* Required scopes.
* Expected claims.

Do not accept any valid JWT from the issuer without checking whether it is intended for your API. ([AWS Documentation][26])

---

# 46. Cognito user-pool authorizers

REST APIs support Amazon Cognito user pools as a native authorizer.

```text
User
  |
  v
Cognito User Pool
  |
  v
JWT
  |
  v
REST API Cognito authorizer
```

Cognito authorizers are an alternative to IAM and Lambda authorizers for user-facing REST APIs. ([AWS Documentation][27])

For HTTP APIs, Cognito user pools are usually configured through the generic JWT authorizer model.

---

# 47. Lambda authorizers

A Lambda authorizer implements custom authorization logic.

```text
Client request
      |
      v
API Gateway
      |
      v
Lambda authorizer
      |
      ├── Allow
      └── Deny
```

Use cases:

* Legacy tokens.
* Custom API keys.
* External authorization service.
* Tenant-level policy.
* Multiple identity sources.
* Custom signed requests.
* Complex entitlement checks.

REST and HTTP APIs both support Lambda authorizers. ([AWS Documentation][28])

---

# 48. REST Lambda authorizer types

REST APIs provide:

```text
TOKEN authorizer
REQUEST authorizer
```

## TOKEN

Reads one bearer-token identity source.

## REQUEST

Can use several request elements:

* Headers.
* Query parameters.
* Path parameters.
* Stage variables.
* Context.

REST Lambda authorizers return an IAM policy and principal identifier. ([AWS Documentation][28])

---

# 49. HTTP Lambda authorizer responses

HTTP API Lambda authorizers support:

```text
Payload format 1.0:
IAM policy response

Payload format 2.0:
IAM policy or simplified Boolean response
```

A simple response might be:

```json
{
  "isAuthorized": true,
  "context": {
    "tenantId": "tenant-104"
  }
}
```

The returned context can be passed to integrations and access logs. ([AWS Documentation][29])

---

# 50. Authorizer caching

API Gateway can cache Lambda authorizer results.

Benefits:

* Reduced authorizer invocation cost.
* Lower request latency.
* Less pressure on identity services.

Risks:

* Revoked access may remain accepted until cache expiry.
* An overly broad cached IAM policy can affect several routes.
* Incorrect identity-source selection can reuse the wrong result.

REST authorizer caching defaults and limits depend on the authorizer configuration; the REST API supports a result TTL up to one hour. ([AWS Documentation][30])

Design cache keys to include all information affecting authorization.

---

# 51. WebSocket authorization

For WebSocket APIs, authorization occurs during connection establishment.

```text
Client
  |
  | $connect
  v
Authorizer
  |
  v
Persistent connection
```

A Lambda authorizer can only be attached to the `$connect` route because the connection becomes stateful after establishment. IAM authorization is also supported. ([AWS Documentation][31])

After connection:

* Store the authorized user with the `connectionId`.
* Recheck business authorization for sensitive actions.
* Remove stale connections.
* Do not assume the user’s permissions can never change.

---

# 52. API Gateway resource policies

A resource policy controls who may invoke a REST API.

You can permit or deny based on:

* AWS account.
* IAM principal.
* Source IP range.
* VPC.
* VPC endpoint.
* AWS Organization.

Resource policies can be combined with IAM or authorizers. ([AWS Documentation][32])

Example private-source restriction:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "execute-api:/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceVpce": "vpce-0123456789abcdef0"
        }
      }
    }
  ]
}
```

---

# 53. Private REST APIs

A private REST API is invoked through an interface VPC endpoint for:

```text
com.amazonaws.ap-south-1.execute-api
```

```text
Private client
      |
      v
Interface VPC endpoint
      |
      v
Private REST API
```

Private API access normally combines:

```text
VPC endpoint policy
+
API resource policy
+
Method authorization
```

Private APIs require a resource policy, and the policy can restrict requests using `aws:SourceVpc` or `aws:SourceVpce`. ([AWS Documentation][33])

---

# 54. On-premises access to a private API

```text
On-premises network
      |
      v
Direct Connect or VPN
      |
      v
Amazon VPC
      |
      v
API Gateway VPC endpoint
      |
      v
Private REST API
```

Private APIs can be accessed from an on-premises network through private connectivity and suitable DNS forwarding. ([AWS Documentation][34])

Use this for:

* Internal enterprise APIs.
* Banking or regulated integrations.
* Hybrid-cloud control planes.
* Internal operational APIs.
* Workloads that must not expose public endpoints.

---

# 55. Mutual TLS

Mutual TLS authenticates both sides of the TLS connection.

Normal TLS:

```text
Client verifies server certificate.
```

Mutual TLS:

```text
Client verifies server certificate.
Server verifies client certificate.
```

API Gateway supports mTLS for compatible REST and HTTP custom domains using a certificate truststore stored in S3. ([AWS Documentation][35])

Use cases:

* Partner APIs.
* B2B integration.
* Banking clients.
* Device authentication.
* Enterprise workload identity.

---

# 56. mTLS truststore

Truststore:

```text
S3 bucket
└── certificates.pem
```

The bundle contains trusted issuing CA certificates.

Connection:

```text
Client certificate
      |
      v
API Gateway
      |
      v
Validate chain against truststore
```

Important operational facts:

* Use S3 versioning for truststore history.
* Monitor certificate expiry.
* Rotate truststores deliberately.
* API Gateway checks certificate trust and expiry during connection.
* API Gateway does not verify certificate revocation status automatically. ([AWS Documentation][35])

Therefore short-lived client certificates and external revocation controls may be necessary.

---

# 57. API keys

REST API keys identify API consumers for usage-plan accounting.

```text
Client
  |
  | x-api-key
  v
REST API
  |
  v
Usage plan
```

API keys are used for:

* Metering.
* Per-client throttling.
* Per-client quotas.
* Developer-plan differentiation.

API keys are not a strong authentication mechanism. AWS recommends using IAM, Cognito or Lambda authorizers for authorization. ([AWS Documentation][36])

Never treat possession of an API key as proof of user identity.

---

# 58. Usage plans

A usage plan connects:

```text
API stages
+
API keys
+
Throttle limits
+
Quota limits
```

Example:

```text
Free plan:
10 requests/second
10,000 requests/month

Premium plan:
100 requests/second
1,000,000 requests/month
```

Usage-plan throttling and quotas apply to requests associated with individual API keys across stages included in the plan. ([AWS Documentation][36])

---

# 59. Throttling mental model

API Gateway uses token-bucket throttling concepts.

```text
Steady-state rate:
Tokens replenished per second

Burst:
Temporary bucket capacity
```

Example:

```text
Rate:
100 requests/second

Burst:
200 requests
```

A short burst can use available tokens, but prolonged traffic above the steady-state rate receives:

```text
429 Too Many Requests
```

---

# 60. Account-level quota

The default API Gateway account-level throttle quota is currently:

```text
10,000 requests per second
per AWS account per Region
```

with a default maximum token-bucket capacity of up to `5,000`, though account and Region-specific quotas can vary and some quotas can be increased. ([AWS Documentation][37])

This quota is shared across:

```text
REST APIs
HTTP APIs
WebSocket APIs
WebSocket callback APIs
```

One runaway API can therefore affect another API in the same account and Region.

---

# 61. Throttling hierarchy

Possible throttling layers include:

```text
AWS account and Region
        ↓
API stage
        ↓
Route or method
        ↓
Usage plan
        ↓
Individual API key
```

The most restrictive applicable limit controls the request.

Protect expensive routes separately:

```text
GET /todos:
500 requests/second

POST /reports:
10 requests/second

POST /ai-analysis:
2 requests/second
```

---

# 62. Backend protection

API Gateway throttling protects more than API Gateway.

It protects:

* Lambda concurrency.
* Database connections.
* ECS capacity.
* External APIs.
* Expensive AI endpoints.
* Downstream service quotas.

Example:

```text
API Gateway:
100 requests/second

Lambda reserved concurrency:
50

Database safe concurrency:
40
```

Limits should be coordinated from the backend outward.

---

# 63. Client retry strategy

When a client receives `429` or a temporary `5xx`:

```text
Retry
+
Exponential backoff
+
Jitter
+
Maximum attempt limit
```

Do not retry immediately in a tight loop.

Bad:

```text
Request → 429
Request → 429
Request → 429
Request → 429
```

Better:

```text
Attempt 1
Wait randomized 200–400 ms
Attempt 2
Wait randomized 500–900 ms
Attempt 3
```

For write operations, retries require idempotency keys.

---

# 64. REST API caching

REST APIs support managed stage caching.

```text
Client request
      |
      v
API Gateway cache
      |
      ├── Cache hit → Return response
      |
      └── Cache miss → Invoke backend
```

API cache benefits:

* Reduced backend calls.
* Lower backend latency.
* Protection from repeated reads.
* Reduced database pressure.

The largest individual response eligible for API Gateway caching is currently 1 MiB. ([AWS Documentation][38])

---

# 65. Cache keys

A cache key identifies distinct responses.

Example:

```text
GET /todos?userId=104
```

Cache key:

```text
userId
```

If the API is tenant-specific, include:

```text
Tenant identifier
User identifier where necessary
Relevant query parameters
Relevant headers
```

Bad cache key:

```text
GET /todos
```

when every user should see different data.

This can create cross-user data leakage.

---

# 66. Cache invalidation

Caching introduces staleness.

Strategies:

* Short TTL.
* Explicit cache flush.
* Client cache invalidation.
* Versioned URL.
* Cache bypass for critical reads.
* No caching for highly dynamic resources.

Use caching primarily for safe read operations:

```text
GET
HEAD
```

Do not cache writes or personalized sensitive data without an explicit correctness design.

---

# 67. AWS WAF

AWS WAF can be directly associated with API Gateway REST API stages.

WAF helps protect against:

* SQL injection.
* Cross-site scripting.
* Malicious bots.
* Known-bad IP addresses.
* Excessive request rates.
* Suspicious headers and payload patterns.
* Geographic restrictions.

Direct WAF integration is a REST API feature, not a native HTTP API feature in the API Gateway feature comparison. ([AWS Documentation][39])

---

# 68. WAF architecture

```text
Client
  |
  v
AWS WAF web ACL
  |
  ├── Block malicious request
  |
  └── Allow request
          |
          v
      REST API
```

Recommended rules:

```text
AWS managed core rule set
Known bad inputs
SQL database protection
IP reputation
Rate-based rule
Application-specific allow and block rules
```

Start new rules in:

```text
COUNT mode
```

Review results, then move to:

```text
BLOCK mode
```

to reduce accidental production denial.

---

# 69. Access logs

Access logs record one structured entry per API request.

Recommended JSON format:

```json
{
  "requestId": "$context.requestId",
  "extendedRequestId": "$context.extendedRequestId",
  "sourceIp": "$context.identity.sourceIp",
  "requestTime": "$context.requestTime",
  "httpMethod": "$context.httpMethod",
  "routeKey": "$context.routeKey",
  "path": "$context.path",
  "status": "$context.status",
  "responseLength": "$context.responseLength",
  "integrationStatus": "$context.integrationStatus",
  "integrationLatency": "$context.integrationLatency",
  "responseLatency": "$context.responseLatency",
  "authorizerError": "$context.authorizer.error"
}
```

REST, HTTP and WebSocket APIs support CloudWatch access logging, although available context variables differ. ([AWS Documentation][40])

---

# 70. Execution logging

REST and WebSocket APIs support execution logging in addition to access logging.

## Access logs

Answer:

```text
Who called?
Which path?
What status?
How long?
```

## Execution logs

Answer:

```text
How did API Gateway process the request?
What integration error occurred?
Which mapping or authorization step failed?
```

API Gateway manages execution-log groups for supported REST and WebSocket stages. ([AWS Documentation][40])

Avoid logging sensitive request or response bodies.

---

# 71. Important metrics

Core API Gateway CloudWatch metrics include:

```text
Count
4XXError or 4xx
5XXError or 5xx
Latency
IntegrationLatency
DataProcessed
CacheHitCount
CacheMissCount
```

`IntegrationLatency` measures backend time, while `Latency` includes integration time plus API Gateway processing overhead. ([AWS Documentation][41])

---

# 72. Latency diagnosis

Example:

```text
Latency:
1,500 ms

IntegrationLatency:
1,450 ms
```

Likely conclusion:

```text
Backend is responsible for most latency.
```

Another example:

```text
Latency:
1,500 ms

IntegrationLatency:
100 ms
```

Investigate:

* Authorizer latency.
* Request mapping.
* WAF.
* API Gateway overhead.
* Response processing.
* Network/client behavior.

---

# 73. API Gateway alarms

Recommended alarms:

```text
5xx error rate > threshold
4xx error rate unexpectedly high
p95 Latency above SLO
p95 IntegrationLatency high
429 responses increasing
Cache hit ratio decreasing
WebSocket connection errors
Authorizer failures
```

Page on customer-impact symptoms:

```text
5xx rate
availability
latency SLO
```

Create lower-priority tickets for:

```text
Gradual 4xx increase
cache degradation
traffic anomalies
```

---

# 74. X-Ray tracing

API Gateway active X-Ray tracing is supported for REST APIs across:

```text
Regional
Edge-optimized
Private
```

X-Ray helps separate API Gateway latency from Lambda, HTTP and downstream-service latency. HTTP and WebSocket APIs do not have the same API Gateway active-tracing support. ([AWS Documentation][42])

Trace path:

```text
Client
  |
  v
API Gateway
  |
  v
Lambda
  |
  v
DynamoDB
```

---

# 75. API error classification

Common status codes:

```text
400:
Invalid request

401:
Authentication missing or invalid

403:
Authenticated but forbidden,
resource policy denied,
WAF blocked,
or default endpoint disabled

404:
Route or resource not found

429:
Throttle or quota exceeded

500:
API Gateway or integration configuration error

502:
Invalid or failed backend response

504:
Integration timeout
```

API Gateway provides gateway-response types such as `THROTTLED`, `QUOTA_EXCEEDED` and `INTEGRATION_TIMEOUT`. ([AWS Documentation][43])

---

# 76. Troubleshooting `401 Unauthorized`

Check:

```text
Authorization header exists
Token prefix is correct
Token is not expired
JWT issuer is correct
JWT audience is correct
Required scope is present
Authorizer identity source is configured
Lambda authorizer returns expected format
```

For a WebSocket API, verify authorization occurs on:

```text
$connect
```

Do not investigate backend Lambda first if API Gateway rejected the request before integration.

---

# 77. Troubleshooting `403 Forbidden`

Possible causes:

```text
IAM explicit deny
Missing execute-api:Invoke
API resource policy denial
VPC endpoint policy denial
Wrong source VPC or endpoint
WAF block
mTLS certificate rejected
Disabled execute-api endpoint
Lambda authorizer Deny
Invalid API key configuration
```

Troubleshooting order:

```text
1. Check WAF logs.
2. Check access logs.
3. Check authorizer logs.
4. Check resource policy.
5. Check IAM or SCP.
6. Check VPC endpoint policy.
7. Check custom-domain mapping.
```

---

# 78. Troubleshooting `429 Too Many Requests`

Check:

* Account-level API Gateway throttle.
* Stage throttle.
* Route or method throttle.
* Usage-plan throttle.
* API-key quota.
* Lambda throttling.
* Backend-generated `429`.

Access logs should include:

```text
status
integrationStatus
requestId
routeKey
```

This helps distinguish:

```text
API Gateway throttling
```

from:

```text
Backend service throttling
```

---

# 79. Troubleshooting `502 Bad Gateway`

Common Lambda proxy causes:

* Lambda returned malformed response.
* `statusCode` missing.
* `body` is not a string.
* Invalid response headers.
* Function crashed.
* Lambda permission missing.
* Backend connection terminated.
* Integration response mapping failed.

Correct response:

```javascript
return {
  statusCode: 200,
  headers: {
    "content-type": "application/json"
  },
  body: JSON.stringify({
    message: "success"
  })
};
```

---

# 80. Troubleshooting `504 Gateway Timeout`

A `504` normally means the integration did not respond before API Gateway’s integration timeout. ([AWS Documentation][43])

Check:

```text
Lambda duration
Backend HTTP logs
ALB target response time
Database latency
External API latency
VPC link health
DNS resolution
Connection timeout
Response timeout
```

Do not solve every `504` by extending the API timeout.

Prefer asynchronous processing when the operation is naturally long-running.

---

# 81. Troubleshooting CORS

Symptoms:

```text
Request works in curl.
Request fails in browser.
```

Check:

* Browser sent an `OPTIONS` preflight.
* `Access-Control-Allow-Origin` is correct.
* Requested method appears in `Access-Control-Allow-Methods`.
* Requested headers appear in `Access-Control-Allow-Headers`.
* Error responses include CORS headers.
* Lambda proxy responses include required headers.
* Credentials configuration matches the origin policy.

CORS errors can hide the real backend error because the browser refuses to expose the response.

---

# 82. Troubleshooting private integration

Check:

```text
VPC link status
ALB/NLB listener
Target-group health
Route table
Security groups
Backend protocol
Backend hostname and certificate
Integration URI
Stage path forwarding
Backend timeout
```

REST private integrations include the API stage in the backend request path by default unless parameter mapping removes it. ([AWS Documentation][12])

Example unexpected backend path:

```text
/production/todos
```

when the backend expects:

```text
/todos
```

---

# 83. Terraform HTTP API with Lambda

```hcl
resource "aws_apigatewayv2_api" "todo" {
  name          = "production-todo-api"
  protocol_type = "HTTP"

  disable_execute_api_endpoint = true

  cors_configuration {
    allow_origins = [
      "https://app.yourdatascientist.tech"
    ]

    allow_methods = [
      "GET",
      "POST",
      "PUT",
      "DELETE",
      "OPTIONS"
    ]

    allow_headers = [
      "authorization",
      "content-type",
      "x-request-id"
    ]

    max_age = 3600
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 84. Terraform Lambda integration

```hcl
resource "aws_apigatewayv2_integration" "todo_lambda" {
  api_id = aws_apigatewayv2_api.todo.id

  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_alias.production.invoke_arn

  integration_method     = "POST"
  payload_format_version = "2.0"

  timeout_milliseconds = 29000
}
```

Routes:

```hcl
resource "aws_apigatewayv2_route" "get_todos" {
  api_id = aws_apigatewayv2_api.todo.id

  route_key = "GET /todos"
  target    = "integrations/${aws_apigatewayv2_integration.todo_lambda.id}"

  authorization_type = "JWT"
  authorizer_id       = aws_apigatewayv2_authorizer.jwt.id

  authorization_scopes = [
    "todos/read"
  ]
}

resource "aws_apigatewayv2_route" "create_todo" {
  api_id = aws_apigatewayv2_api.todo.id

  route_key = "POST /todos"
  target    = "integrations/${aws_apigatewayv2_integration.todo_lambda.id}"

  authorization_type = "JWT"
  authorizer_id       = aws_apigatewayv2_authorizer.jwt.id

  authorization_scopes = [
    "todos/write"
  ]
}
```

---

# 85. Terraform JWT authorizer

```hcl
resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id = aws_apigatewayv2_api.todo.id

  name             = "todoapp-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer = var.jwt_issuer

    audience = [
      var.jwt_audience
    ]
  }
}
```

---

# 86. Terraform Lambda permission

```hcl
resource "aws_lambda_permission" "api_gateway" {
  statement_id = "AllowApiGatewayInvoke"

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.todo_api.function_name
  qualifier     = aws_lambda_alias.production.name

  principal = "apigateway.amazonaws.com"

  source_arn = (
    "${aws_apigatewayv2_api.todo.execution_arn}/*/*"
  )
}
```

Restrict the source ARN further when only selected methods and paths should invoke the function.

---

# 87. Terraform stage and access logs

```hcl
resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/production-todo-api"
  retention_in_days = 30

  kms_key_id = aws_kms_key.logs.arn

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}

resource "aws_apigatewayv2_stage" "production" {
  api_id = aws_apigatewayv2_api.todo.id

  name        = "production"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn

    format = jsonencode({
      requestId          = "$context.requestId"
      sourceIp           = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      routeKey           = "$context.routeKey"
      path               = "$context.path"
      status             = "$context.status"
      responseLength     = "$context.responseLength"
      integrationStatus  = "$context.integrationStatus"
      integrationLatency = "$context.integrationLatency"
      responseLatency    = "$context.responseLatency"
      errorMessage       = "$context.error.message"
    })
  }

  default_route_settings {
    throttling_rate_limit  = 100
    throttling_burst_limit = 200

    detailed_metrics_enabled = true
  }

  tags = {
    Environment = "production"
  }
}
```

---

# 88. Terraform custom domain

```hcl
resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.yourdatascientist.tech"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api.certificate_arn

    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "todo" {
  api_id      = aws_apigatewayv2_api.todo.id
  domain_name = aws_apigatewayv2_domain_name.api.id
  stage       = aws_apigatewayv2_stage.production.id
}
```

Route 53 alias:

```hcl
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.yourdatascientist.tech"
  type    = "A"

  alias {
    name = (
      aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    )

    zone_id = (
      aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    )

    evaluate_target_health = false
  }
}
```

---

# 89. Terraform private HTTP integration

```hcl
resource "aws_apigatewayv2_vpc_link" "backend" {
  name = "production-todo-backend"

  subnet_ids = var.private_subnet_ids

  security_group_ids = [
    aws_security_group.api_gateway_vpc_link.id
  ]

  tags = {
    Environment = "production"
  }
}

resource "aws_apigatewayv2_integration" "private_alb" {
  api_id = aws_apigatewayv2_api.todo.id

  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"

  integration_uri = (
    aws_lb_listener.internal_http.arn
  )

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.backend.id

  payload_format_version = "1.0"
}
```

---

# 90. AWS CLI: create a basic HTTP API

```bash
aws apigatewayv2 create-api \
  --name production-todo-api \
  --protocol-type HTTP \
  --target "$LAMBDA_ARN" \
  --region ap-south-1
```

List APIs:

```bash
aws apigatewayv2 get-apis \
  --region ap-south-1
```

List routes:

```bash
aws apigatewayv2 get-routes \
  --api-id "$API_ID" \
  --region ap-south-1
```

List integrations:

```bash
aws apigatewayv2 get-integrations \
  --api-id "$API_ID" \
  --region ap-south-1
```

---

# 91. Test the API

Invoke through the custom domain:

```bash
curl \
  --request GET \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "X-Request-Id: test-104" \
  https://api.yourdatascientist.tech/todos
```

Verbose TLS and header diagnostics:

```bash
curl \
  --verbose \
  --request GET \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  https://api.yourdatascientist.tech/todos
```

Test CORS preflight:

```bash
curl \
  --include \
  --request OPTIONS \
  --header "Origin: https://app.yourdatascientist.tech" \
  --header "Access-Control-Request-Method: POST" \
  --header "Access-Control-Request-Headers: authorization,content-type" \
  https://api.yourdatascientist.tech/todos
```

---

# 92. Production TodoApp architecture

```text
Browser
  |
  v
CloudFront
  |
  v
api.yourdatascientist.tech
  |
  v
API Gateway HTTP API
  |
  ├── JWT authorizer
  ├── CORS
  ├── Route throttling
  ├── Access logging
  └── Custom domain
          |
          v
Lambda alias: production
  |
  ├── DynamoDB
  ├── EventBridge
  ├── SQS
  └── Secrets Manager
```

Alternative container architecture:

```text
Browser
  |
  v
API Gateway HTTP API
  |
  v
VPC Link V2
  |
  v
Internal ALB
  |
  v
ECS TodoApp backend
```

---

# 93. REST API production architecture

Choose REST API for a partner-facing managed API:

```text
Partner
  |
  | mTLS + API key + OAuth token
  v
Custom domain
  |
  v
AWS WAF
  |
  v
Regional REST API
  |
  ├── Usage plan
  ├── Request validator
  ├── API cache
  ├── Canary deployment
  └── X-Ray tracing
          |
          v
Private integration
          |
          v
Internal ALB
```

Each control solves a different concern:

```text
mTLS:
Client certificate identity

OAuth:
User or application authorization

API key:
Usage-plan tracking

WAF:
Request filtering

Request validator:
Contract validation

Throttle:
Capacity protection
```

---

# 94. Common architecture mistakes

## Mistake 1: Choosing REST API for every simple Lambda endpoint

HTTP APIs may be simpler and less expensive when advanced REST features are unnecessary.

## Mistake 2: Using API keys as authentication

API keys support metering and usage plans, not strong identity.

## Mistake 3: Keeping the default endpoint enabled

Clients can bypass the custom domain and its intended traffic controls.

## Mistake 4: Allowing unlimited request rates

A sudden spike can overwhelm Lambda, ECS or the database.

## Mistake 5: Waiting synchronously for long jobs

API integration timeouts make this unreliable.

## Mistake 6: Logging full authorization headers

This can expose bearer tokens and credentials.

## Mistake 7: Caching without tenant-aware keys

One user may receive another user’s response.

## Mistake 8: Using one Lambda authorizer cache entry for different permissions

An overly broad cached policy can grant access to unintended routes.

## Mistake 9: Making the backend public unnecessarily

Use VPC links for private container or EC2 services.

## Mistake 10: Deploying API changes directly to production

Use stages, aliases, canaries and automated rollback.

---

# 95. Production readiness checklist

```text
[ ] Correct API type selected
[ ] API contract is version controlled
[ ] OpenAPI definition is maintained
[ ] Routes follow consistent naming
[ ] Request payload limits are understood
[ ] Large uploads use S3 presigned URLs
[ ] Long work is asynchronous
[ ] Integration timeouts are intentional
[ ] Authentication method is documented
[ ] Authorization is enforced per route
[ ] Access tokens and scopes are validated
[ ] Lambda authorizer caching is safe
[ ] API keys are not used as authentication
[ ] Resource policies are least privilege
[ ] Private APIs restrict VPC endpoints
[ ] Private integrations use VPC links
[ ] Custom domain is configured
[ ] Correct ACM Region is used
[ ] Default execute-api endpoint is disabled
[ ] TLS policy is current
[ ] mTLS truststore is versioned
[ ] Certificate expiry is monitored
[ ] CORS allows only required origins
[ ] Throttle limits protect the backend
[ ] Client retry guidance uses backoff and jitter
[ ] REST API usage plans are configured where required
[ ] REST API request validation is enabled
[ ] Cache keys prevent cross-user leakage
[ ] WAF is associated where required
[ ] Access logs are structured JSON
[ ] Sensitive data is excluded from logs
[ ] CloudWatch alarms cover latency and errors
[ ] X-Ray is enabled for critical REST APIs
[ ] Canary or alias-based deployment is configured
[ ] Rollback is automated
[ ] 401, 403, 429, 502 and 504 runbooks exist
```

---

# 96. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
API Gateway:
Managed API frontend

REST API:
Feature-rich API management

HTTP API:
Simpler lower-cost HTTP API

WebSocket API:
Persistent two-way communication
```

## Solutions Architect Associate

Understand:

```text
Lambda proxy integration
HTTP versus REST API
Private API
Private integration
VPC link
Custom domains
IAM authorization
JWT authorization
Cognito authorizers
Throttling
Caching
```

## DevOps Engineer Professional

Understand:

```text
Canary deployments
Stage variables
Resource policies
mTLS
Usage plans
Authorizer caching
WAF
Structured access logging
X-Ray
Terraform deployments
Automated rollback
Multi-account API governance
```

---

# 97. Interview questions

## Question 1: What is Amazon API Gateway?

**Answer:**

It is a managed service for creating, publishing, securing, monitoring and operating REST, HTTP and WebSocket APIs.

## Question 2: What is the difference between HTTP and REST APIs?

**Answer:**

HTTP APIs are simpler and lower cost for common Lambda and HTTP proxy use cases. REST APIs provide advanced features including API keys, usage plans, managed caching, request validation, WAF integration, private endpoints and canary deployments.

## Question 3: When should you use a WebSocket API?

**Answer:**

Use it when clients and backends need persistent, bidirectional communication, such as chat, live dashboards and real-time notifications.

## Question 4: What is Lambda proxy integration?

**Answer:**

API Gateway passes the complete HTTP request context to Lambda, and Lambda returns the HTTP status, headers and body.

## Question 5: What is a VPC link?

**Answer:**

It provides managed private connectivity from API Gateway to supported resources such as an internal ALB, NLB or supported Cloud Map service.

## Question 6: What is the difference between a private API and private integration?

**Answer:**

A private API controls how clients privately reach API Gateway. A private integration controls how API Gateway privately reaches the backend.

## Question 7: What is an API Gateway stage?

**Answer:**

It is a named API lifecycle environment that references a deployment and contains settings such as logging, throttling and variables.

## Question 8: What is an API Gateway deployment?

**Answer:**

It is an immutable snapshot of API configuration that can be associated with a stage.

## Question 9: What is a JWT authorizer?

**Answer:**

It validates an OIDC or OAuth 2.0 JWT and can enforce issuer, audience and authorization scopes for HTTP API routes.

## Question 10: What is a Lambda authorizer?

**Answer:**

It invokes custom Lambda code to authenticate and authorize a request before API Gateway calls the backend.

## Question 11: What are API keys used for?

**Answer:**

They identify clients for usage-plan metering, throttling and quotas. They should not be used as the sole authentication mechanism.

## Question 12: What is an API Gateway resource policy?

**Answer:**

It is a resource-based policy controlling which principals, IP ranges, VPCs or VPC endpoints can invoke a REST API.

## Question 13: What is mutual TLS?

**Answer:**

It is TLS authentication in which the client verifies the API certificate and API Gateway also verifies the client certificate against an S3-hosted truststore.

## Question 14: What is the difference between `Latency` and `IntegrationLatency`?

**Answer:**

`IntegrationLatency` measures backend response time. `Latency` measures the complete time API Gateway spends processing the request, including integration time.

## Question 15: What causes a `429` response?

**Answer:**

An account, stage, route, usage-plan or API-key throttle or quota may have been exceeded, or the backend may have returned its own `429`.

## Question 16: What commonly causes API Gateway `502` errors with Lambda?

**Answer:**

A malformed Lambda proxy response, function failure, invalid headers, missing invocation permission or integration-mapping failure.

## Question 17: What commonly causes `504` errors?

**Answer:**

The backend did not return before the API Gateway integration timeout.

## Question 18: How do you upload large files through an API architecture?

**Answer:**

Return an S3 presigned URL and let the client upload directly to S3 rather than proxying the file through API Gateway.

## Question 19: How can you deploy API changes safely?

**Answer:**

Use version-controlled definitions, separate environments, canary deployments or Lambda weighted aliases, CloudWatch alarms and automated rollback.

## Question 20: How do you protect an API backend from traffic spikes?

**Answer:**

Configure API Gateway throttling, Lambda concurrency controls or container autoscaling, database limits, queues for asynchronous work and client retry policies with backoff.

---

# 98. Never-forget revision

```text
API Gateway:
Managed API frontend.

REST API:
Feature-rich API-management product.

HTTP API:
Simpler lower-cost HTTP API.

WebSocket API:
Persistent bidirectional API.

Resource:
REST API URL path.

Method:
REST HTTP operation.

Route:
HTTP API method and path.

Integration:
Backend API Gateway invokes.

Deployment:
Immutable API configuration snapshot.

Stage:
Named API lifecycle environment.

Lambda proxy:
Pass complete request to Lambda.

VPC link:
Private connection to VPC backend.

Private API:
API reached through VPC endpoint.

JWT authorizer:
Validates OAuth/OIDC token.

Lambda authorizer:
Custom authorization logic.

Resource policy:
Controls who may invoke the API.

Usage plan:
API-key throttling and quota.

mTLS:
Server and client certificate authentication.

API cache:
REST response cache.

Canary:
Percentage-based test deployment.

Access log:
One record per client request.

IntegrationLatency:
Backend response time.
```

## One-line memory trick

```text
Choose HTTP for simplicity.
Choose REST for control.
Choose WebSocket for real time.
Authenticate every caller.
Throttle before overload.
Keep backends private.
Log every request.
Deploy gradually.
```

## Lesson 42 outcome

You can now design an API where:

```text
A simple Lambda service needs JWT authentication
    → HTTP API provides routes and JWT authorization.

Partners need quotas and API keys
    → REST API usage plans control consumption.

A private ECS service needs public API access
    → VPC Link connects API Gateway to an internal ALB.

An internal API must never be public
    → Private REST API uses an execute-api VPC endpoint.

A client must present a certificate
    → Mutual TLS validates the client trust chain.

Traffic suddenly spikes
    → Throttling protects Lambda and the database.

The backend takes several minutes
    → API returns 202 and queues asynchronous work.

A new release is risky
    → Canary traffic validates it before promotion.

Users report slow responses
    → Latency and IntegrationLatency isolate the cause.
```

**Next lesson: Lesson 43 — Amazon DynamoDB production architecture: partitions, keys, access patterns, indexes, consistency, transactions, Streams, capacity modes, throttling, global tables, backups and single-table design.**

[1]: https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html?utm_source=chatgpt.com "What is Amazon API Gateway? - Amazon API Gateway"
[2]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html?utm_source=chatgpt.com "Choose between REST APIs and HTTP APIs"
[3]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html?utm_source=chatgpt.com "API Gateway HTTP APIs - Amazon API Gateway"
[4]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-overview-developer-experience.html?utm_source=chatgpt.com "API Gateway use cases"
[5]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api-overview.html?utm_source=chatgpt.com "Overview of WebSocket APIs in API Gateway"
[6]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-rest-api.html?utm_source=chatgpt.com "API Gateway REST APIs - Amazon API Gateway"
[7]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-integration-settings.html?utm_source=chatgpt.com "Integrations for REST APIs in API Gateway - Amazon API Gateway"
[8]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-integration-types.html?utm_source=chatgpt.com "Choose an API Gateway API integration type - Amazon API Gateway"
[9]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html?utm_source=chatgpt.com "Create AWS Lambda proxy integrations for HTTP APIs in API Gateway - Amazon API Gateway"
[10]: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-integrations.html?utm_source=chatgpt.com "Lambda integrations for REST APIs in API Gateway - Amazon API Gateway"
[11]: https://docs.aws.amazon.com/apigateway/latest/developerguide/setup-http-integrations.html?utm_source=chatgpt.com "HTTP integrations for REST APIs in API Gateway - Amazon API Gateway"
[12]: https://docs.aws.amazon.com/apigateway/latest/developerguide/private-integration.html?utm_source=chatgpt.com "Private integrations for REST APIs in API Gateway - Amazon API Gateway"
[13]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-quotas.html?utm_source=chatgpt.com "Quotas for configuring and running an HTTP API in API ..."
[14]: https://docs.aws.amazon.com/apigateway/latest/developerguide/response-transfer-mode.html?utm_source=chatgpt.com "Stream the integration response for your proxy integrations in API Gateway - Amazon API Gateway"
[15]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-execution-service-limits-table.html?utm_source=chatgpt.com "Quotas for configuring and running a REST API in API ..."
[16]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-method-request-validation.html?utm_source=chatgpt.com "Request validation for REST APIs in API Gateway - Amazon API Gateway"
[17]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-stages.html?utm_source=chatgpt.com "Stages for HTTP APIs in API Gateway"
[18]: https://docs.aws.amazon.com/apigateway/latest/developerguide/aws-api-gateway-stage-variables-reference.html?utm_source=chatgpt.com "API Gateway stage variables reference for REST APIs in API Gateway - Amazon API Gateway"
[19]: https://docs.aws.amazon.com/apigateway/latest/developerguide/create-canary-deployment.html?utm_source=chatgpt.com "Create a canary release deployment - Amazon API Gateway"
[20]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-custom-domains.html?utm_source=chatgpt.com "Custom domain name for public REST APIs in API Gateway - Amazon API Gateway"
[21]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-edge-optimized-custom-domain-name.html?utm_source=chatgpt.com "Set up an edge-optimized custom domain name in API Gateway - Amazon API Gateway"
[22]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-endpoint-types.html?utm_source=chatgpt.com "API endpoint types for REST APIs in API Gateway"
[23]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-mappings.html?utm_source=chatgpt.com "Map API stages to a custom domain name for HTTP APIs - Amazon API Gateway"
[24]: https://docs.aws.amazon.com/apigateway/latest/developerguide/rest-api-disable-default-endpoint.html?utm_source=chatgpt.com "Disable the default endpoint for REST APIs - Amazon API Gateway"
[25]: https://docs.aws.amazon.com/apigateway/latest/developerguide/permissions.html?utm_source=chatgpt.com "Control access to a REST API with IAM permissions - Amazon API Gateway"
[26]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html?utm_source=chatgpt.com "Control access to HTTP APIs with JWT authorizers in API Gateway - Amazon API Gateway"
[27]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-integrate-with-cognito.html?utm_source=chatgpt.com "Control access to REST APIs using Amazon Cognito user pools as an authorizer - Amazon API Gateway"
[28]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html?utm_source=chatgpt.com "Use API Gateway Lambda authorizers - Amazon API Gateway"
[29]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-lambda-authorizer.html?utm_source=chatgpt.com "Control access to HTTP APIs with AWS Lambda authorizers - Amazon API Gateway"
[30]: https://docs.aws.amazon.com/apigateway/latest/api/API_Authorizer.html?utm_source=chatgpt.com "Authorizer - Amazon API Gateway"
[31]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api-lambda-auth.html?utm_source=chatgpt.com "Control access to WebSocket APIs with AWS Lambda REQUEST authorizers - Amazon API Gateway"
[32]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-resource-policies.html?utm_source=chatgpt.com "Control access to a REST API with API Gateway resource policies - Amazon API Gateway"
[33]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-resource-policies-create-attach.html?utm_source=chatgpt.com "Create and attach an API Gateway resource policy to an API - Amazon API Gateway"
[34]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-private-api-test-invoke-url.html?utm_source=chatgpt.com "Invoke a private API - Amazon API Gateway"
[35]: https://docs.aws.amazon.com/apigateway/latest/developerguide/rest-api-mutual-tls.html?utm_source=chatgpt.com "How to turn on mutual TLS authentication for your REST APIs in API Gateway - Amazon API Gateway"
[36]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html?utm_source=chatgpt.com "Usage plans and API keys for REST APIs in API Gateway - Amazon API Gateway"
[37]: https://docs.aws.amazon.com/apigateway/latest/developerguide/limits.html?utm_source=chatgpt.com "Amazon API Gateway quotas - Amazon API Gateway"
[38]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-caching.html?utm_source=chatgpt.com "Cache settings for REST APIs in API Gateway"
[39]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-control-access-aws-waf.html?utm_source=chatgpt.com "Use AWS WAF to protect your REST APIs in API Gateway"
[40]: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-logging.html?utm_source=chatgpt.com "Set up CloudWatch logging for REST APIs in API Gateway"
[41]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-metrics.html?utm_source=chatgpt.com "Monitor CloudWatch metrics for HTTP APIs in API Gateway - Amazon API Gateway"
[42]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-xray.html?utm_source=chatgpt.com "Trace user requests to REST APIs using X-Ray in API Gateway - Amazon API Gateway"
[43]: https://docs.aws.amazon.com/apigateway/latest/developerguide/supported-gateway-response-types.html?utm_source=chatgpt.com "Gateway response types for API Gateway - Amazon API Gateway"
