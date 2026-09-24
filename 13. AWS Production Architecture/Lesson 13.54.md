# AWS Masterclass — Phase 3

# Lesson 53: Amazon API Gateway and AWS AppSync Production API Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Choose between API Gateway REST, HTTP and WebSocket APIs.
* Choose between API Gateway, AppSync GraphQL and AppSync Events.
* Integrate APIs with Lambda, ECS, ALB and AWS services.
* ([AWS Documentation][1]) APIs using IAM, Cognito, JWT and Lambda authorizers.
* Understand why API keys are not authentication credentials.
* Configure throttling, quotas, validation, caching and AWS WAF.
* Design stages, deployments and canary releases.
* Configure custom domains and ACM certificates.
* Build production WebSocket connection management.
* Design GraphQL schemas, resolvers, mutations and subscriptions.
* Use AppSync pipeline resolvers and direct data-source integrations.
* Implement AppSync server-side caching and merged APIs.
* Build real-time pub/sub systems using AppSync Events.
* Configure logging, metrics, tracing and alarms.
* Provision production APIs using Terraform.
* Troubleshoot `401`, `403`, `429`, `502`, CORS and resolver failures.

---

# 2. API front-door mental model

An API front door sits between clients and backend services.

```text
Web / Mobile / Partner / Internal client
                    |
                    v
             API front door
                    |
          ┌─────────┼─────────┐
          v         v         v
       Lambda      ECS       AWS service
                  / ALB      integration
```

The front door can provide:

```text
Routing
Authentication
Authorization
TLS termination
Throttling
Request validation
Transformation
Caching
Logging
Metrics
Versioning
Custom domains
```

API Gateway supports REST, HTTP and WebSocket APIs. AppSync provides managed GraphQL and Pub/Sub APIs. ([AWS Documentation][2]) API choices

```text
API Gateway REST API
API Gateway HTTP API
API Gateway WebSocket API
AppSync GraphQL API
AppSync Event API
```

## Quick decision table

| Requirement                                    | Recommended starting point |
| ---------------------------------------------- | -------------------------- |
| Lean RESTful Lambda or ALB API                 | HTTP API                   |
| API keys, usage plans or API caching           | REST API                   |
| Request validation and mapping templates       | REST API                   |
| Private API endpoint inside a VPC              | REST API                   |
| Bidirectional custom WebSocket protocol        | WebSocket API              |
| Client selects exact response fields           | AppSync GraphQL            |
| One GraphQL endpoint over several data sources | AppSync GraphQL            |
| GraphQL real-time updates tied to mutations    | AppSync subscriptions      |
| Generic real-time publish/subscribe channels   | AppSync Events             |

REST APIs contain more API-management features, while HTTP APIs provide a smaller, lower-cost feature set. AWS specifically recommends REST APIs when features such as API keys, per-client throttling, request validation, caching, WAF or private API endpoints are needed. ([AWS Documentation][1])azon API Gateway

# 4. HTTP API

HTTP APIs are designed for straightforward RESTful routing.

```text
Client
   |
   v
HTTP API
   |
   ├── Lambda
   ├── Public HTTP service
   └── Private ALB/NLB/Cloud Map service
```

Strong use cases:

* Serverless Lambda APIs.
* Public microservice routing.
* Cognito or OIDC JWT authorization.
* ALB-backed ECS APIs.
* Lower-cost, lower-complexity APIs.
* Simple proxy integrations.

HTTP APIs support Lambda, HTTP proxy and private VPC-link integrations, including private integrations to ALB, NLB and AWS Cloud Map services. ([AWS Documentation][3])

REST APIs provide more advanced API-management controls.

```text
Client
   |
   v
REST API
   |
   ├── Resource and method tree
   ├── Request validator
   ├── Authorizer
   ├── Usage plan
   ├── Mapping template
   ├── API cache
   └── Backend integration
```

Choose a REST API when you require:

* API keys and usage plans.
* Per-client quotas.
* API Gateway response caching.
* Request validation.
* Advanced request or response transformations.
* AWS WAF integration.
* Edge-optimized endpoints.
* Private API endpoints.
* Canary deployments at the stage level.
* More mature API-management capabilities.

([AWS Documentation][1]) versus REST API

| Feature                    |                   HTTP API |                    REST API |
| -------------------------- | -------------------------: | --------------------------: |
| Lambda proxy               |                        Yes |                         Yes |
| Public HTTP proxy          |                        Yes |                         Yes |
| Private ALB integration    |                        Yes |                         Yes |
| JWT authorizer             |                     Native | Cognito/Lambda alternatives |
| Lambda authorizer          |                        Yes |                         Yes |
| IAM authorization          |                        Yes |                         Yes |
| API keys and usage plans   |                         No |                         Yes |
| Request validation         |                    Limited |                         Yes |
| API Gateway response cache |                         No |                         Yes |
| WAF association            |          No direct support |                         Yes |
| Private frontend API       |                         No |                         Yes |
| Edge-optimized endpoint    |                         No |                         Yes |
| Canary stage deployment    | Different deployment model |                         Yes |
| Lower cost and simplicity  |                   Stronger |                       Lower |

The service comparison should be checked whenever choosing an API type because capabilities continue to evolve. ([AWS Documentation][1])t API

A WebSocket API maintains a persistent, bidirectional connection.

```text
Client
   |
   | Persistent WebSocket
   v
API Gateway WebSocket API
   |
   ├── $connect
   ├── $disconnect
   ├── sendMessage
   ├── subscribe
   └── $default
```

Unlike request-response REST APIs, the backend can later send a message to an already connected client. WebSocket routes can integrate with Lambda, HTTP endpoints and AWS services. ([AWS Documentation][4]).

* Collaborative editing.
* Live dashboards.
* Deployment-status updates.
* Multiplayer applications.
* Real-time notification delivery.
* Interactive support tools.

---

# 8. AppSync GraphQL

AppSync GraphQL provides one typed endpoint through which clients request exactly the data they need.

```text
Web / mobile client
        |
        v
AppSync GraphQL API
        |
   ┌────┼──────────┐
   v    v          v
DynamoDB Lambda   Aurora/OpenSearch/HTTP
```

AppSync can combine several data sources through one schema, support real-time subscriptions and combine separately owned GraphQL APIs through merged APIs. ([AWS Documentation][5])Events

AppSync Events provides managed real-time Pub/Sub APIs.

```text
Publisher
   |
   | HTTP or WebSocket
   v
AppSync Event API
   |
   v
Namespace / Channel
   |
   ├── Subscriber A
   ├── Subscriber B
   └── Subscriber C
```

Clients can publish using HTTP or WebSocket and subscribe over WebSocket. Channels are grouped into namespaces where authorization and handler logic can be configured. ([AWS Documentation][6])eway integration types

An API route or method must connect to a backend integration.

Common integration patterns:

```text
Lambda proxy
Lambda custom integration
HTTP proxy
HTTP custom integration
AWS service integration
Mock integration
Private VPC integration
```

API Gateway defines different integration types such as `AWS_PROXY`, `AWS`, `HTTP_PROXY`, `HTTP` and `MOCK`, depending on the selected API type. ([AWS Documentation][7])proxy integration

```text
Client request
      |
      v
API Gateway
      |
      v
Lambda event
      |
      v
Lambda response
      |
      v
HTTP response
```

Example HTTP API Lambda event:

```json
{
  "version": "2.0",
  "routeKey": "POST /todos",
  "rawPath": "/todos",
  "headers": {
    "authorization": "Bearer ..."
  },
  "requestContext": {
    "http": {
      "method": "POST",
      "path": "/todos"
    }
  },
  "body": "{\"title\":\"Learn API Gateway\"}",
  "isBase64Encoded": false
}
```

Example Lambda response:

```json
{
  "statusCode": 201,
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"todoId\":\"501\"}"
}
```

Proxy integration gives the Lambda function substantial control over status, headers and body.

---

# 12. Do not use Lambda only as an HTTP forwarding layer

Unnecessary:

```text
API Gateway
    |
    v
Lambda
    |
    v
Private ALB
    |
    v
ECS
```

Better:

```text
API Gateway
    |
    v
VPC link
    |
    v
Private ALB
    |
    v
ECS
```

A direct private integration removes:

* Lambda cold starts.
* Lambda invocation cost.
* An additional timeout boundary.
* Unnecessary forwarding code.
* Another deployment component.

Use Lambda when it performs real business logic, authorization, transformation or orchestration.

---

# 13. VPC links V2

A VPC link connects API Gateway to private resources inside your VPC.

```text
Public client
     |
     v
API Gateway HTTP or REST API
     |
     v
VPC link V2
     |
     v
Private ALB
     |
     v
ECS Fargate service
```

VPC links V2 can be reused across APIs and routes and can connect to ALB listeners, NLB listeners or Cloud Map services. AWS recommends VPC links V2 over legacy VPC-link resources for new supported designs. ([AWS Documentation][3]) integration versus private API

These are different concepts.

## Private integration

```text
Public API Gateway endpoint
          |
          v
Private backend in VPC
```

The API frontend may be publicly callable, but the backend is private.

## Private API

```text
Client inside VPC
       |
       v
Interface VPC endpoint
       |
       v
Private API Gateway REST API
```

The API endpoint itself is accessible only through private connectivity.

Private API Gateway frontend endpoints are currently a REST API capability and are invoked through interface VPC endpoints powered by AWS PrivateLink. ([AWS Documentation][8]) API architecture

```text
Corporate network
      |
      | VPN / Direct Connect
      v
Amazon VPC
      |
      v
execute-api interface endpoint
      |
      v
Private REST API
      |
      v
Lambda / AWS service / private backend
```

Security layers can include:

```text
VPC endpoint policy
API resource policy
IAM authorization
Lambda authorizer
Backend authorization
```

Do not assume that private networking removes the need for authentication and authorization.

---

# 16. Private custom domains

API Gateway supports custom domain names for private REST APIs.

```text
https://internal-api.yourdatascientist.tech
```

Invoking a private custom domain requires:

* A private custom-domain resource policy.
* A private API resource policy.
* A VPC endpoint association.
* VPC endpoint permission.
* DNS capable of resolving the domain privately.

Public and private custom domains cannot be mixed with the opposite API endpoint type. ([AWS Documentation][9])point types

REST APIs support:

```text
Edge optimized
Regional
Private
```

## Edge optimized

```text
Global client
   |
   v
AWS-managed CloudFront distribution
   |
   v
API Gateway Region
```

## Regional

```text
Client
   |
   v
Regional API Gateway endpoint
```

## Private

```text
Private network
   |
   v
Interface VPC endpoint
   |
   v
Private REST API
```

Regional endpoints are normally preferred when:

* Clients are concentrated in or near one Region.
* You want to place your own CloudFront distribution in front.
* You need Regional WAF and routing control.
* You are designing a multi-Region API.

([AWS Documentation][10])ents and stages

For REST APIs:

```text
API configuration
      |
      v
Deployment snapshot
      |
      v
Stage
```

A deployment is a point-in-time API snapshot.

A stage is a named reference to a deployment, such as:

```text
dev
staging
production
```

Stage settings can include:

* Logging.
* Throttling.
* Caching.
* Stage variables.
* Canary configuration.
* Metrics.

([AWS Documentation][11])ariables

Stage variables act like stage-specific configuration.

```text
production:
backendAlias = production

staging:
backendAlias = staging
```

They can influence:

* Lambda aliases.
* HTTP endpoint names.
* Mapping behaviour.
* Backend selection.

([AWS Documentation][12]) in stage variables because configuration can be visible to administrators and deployment tooling.

Use Secrets Manager or Parameter Store for secrets.

---

# 20. `$default` stage for HTTP APIs

HTTP APIs commonly use:

```text
$default
```

With automatic deployment enabled:

```text
Route configuration changes
        |
        v
Automatically available through $default stage
```

This is convenient for development, but production teams may prefer explicit deployment control so infrastructure changes pass through review, testing and promotion.

---

# 21. Custom domains

Default API Gateway endpoint:

```text
https://abc123.execute-api.ap-south-1.amazonaws.com
```

Custom domain:

```text
https://api.yourdatascientist.tech
```

Benefits:

* Stable client URL.
* Branded endpoint.
* Version or service mappings.
* Easier migration between APIs.
* TLS-policy control.
* Route 53 integration.

API mappings can connect paths such as:

```text
/v1/todos
/v2/todos
/admin
```

to different APIs or stages. API Gateway also supports newer routing rules for REST custom domains based on headers, base paths or both. ([AWS Documentation][13])tificate Region rule

## Regional custom domain

The ACM certificate must be in the same Region as the API.

For your preferred deployment Region:

```text
API:
ap-south-1

ACM certificate:
ap-south-1
```

## Edge-optimized custom domain

The ACM certificate must be in:

```text
us-east-1
```

([AWS Documentation][14])mportant Region rule you encountered with CloudFront certificates.

---

# 23. API versioning

Common URL versioning:

```text
https://api.example.com/v1/todos
https://api.example.com/v2/todos
```

Alternative header versioning:

```http
Accept: application/vnd.todoapp.v2+json
```

For most public REST APIs, path versioning is easier to:

* Document.
* Cache.
* Route.
* Test.
* Monitor.
* Deprecate.

Do not create a new version for every additive field.

Use a major version when you introduce incompatible behaviour.

---

# Part 2 — Authentication and authorization

# 24. Authentication versus authorization

## Authentication

```text
Who are you?
```

Examples:

* Verify JWT.
* Verify AWS SigV4 signature.
* Validate API credential.
* Execute custom authorizer.

## Authorization

```text
What are you allowed to do?
```

Examples:

* User can read only their todos.
* Admin can delete any todo.
* Partner can invoke only `/reports`.
* Service role can publish but not delete.

API Gateway and AppSync can verify identity, but backend business authorization may still be required.

---

# 25. IAM authorization

Architecture:

```text
AWS workload
    |
    | SigV4-signed request
    v
API Gateway / AppSync
    |
    v
IAM policy evaluation
```

Strong fit for:

* Service-to-service APIs.
* Internal AWS workloads.
* CI/CD tooling.
* Administrative automation.
* Cross-account machine access.

Avoid requiring browser users to possess long-lived IAM access keys.

For browser or mobile users, use Cognito or another OIDC identity provider.

---

# 26. Cognito user-pool authorization

```text
User
  |
  v
Cognito user pool
  |
  | JWT
  v
API Gateway / AppSync
```

The token can contain:

```text
sub
username
groups
scopes
tenant claims
expiration
issuer
audience/client ID
```

REST APIs support Cognito user-pool authorizers. Access tokens can be authorized using OAuth scopes, while identity claims can also be used in method authorization logic. ([AWS Documentation][15])I JWT authorizer

HTTP APIs can validate JWTs issued by Cognito or another compatible OIDC/OAuth 2.0 identity provider.

Configuration includes:

```text
Issuer
Audience
Required scopes
Identity source
```

Request:

```http
Authorization: Bearer eyJ...
```

API Gateway validates the token before invoking the backend. ([AWS Documentation][16]):

```text
todo/read
todo/write
todo/admin
```

Do not grant every client one broad scope.

---

# 28. Lambda authorizer

Use a Lambda authorizer when authorization depends on custom logic.

Examples:

* Custom legacy tokens.
* HMAC signatures.
* Tenant entitlement database.
* Partner-specific access rules.
* Migration from a nonstandard identity system.

Flow:

```text
Client request
      |
      v
API Gateway
      |
      v
Lambda authorizer
      |
      ├── Allow with context
      └── Deny
```

Both REST and HTTP APIs support Lambda authorizers, although their input and response models differ. ([AWS Documentation][17])zer context

An authorizer can return context such as:

```json
{
  "principalId": "user-104",
  "tenantId": "tenant-38",
  "role": "ADMIN"
}
```

The backend receives the trusted authorizer result.

Do not trust a client-supplied header like:

```http
X-Tenant-Id: tenant-38
```

unless you verify that the authenticated user is actually a member of that tenant.

---

# 30. API keys are not authentication

API keys are designed primarily for:

* Client identification.
* Usage tracking.
* Usage plans.
* Per-client throttling.
* Quota allocation.

AWS recommends using API keys alongside IAM, Cognito or an authorizer rather than treating the API key as the complete authorization mechanism. ([AWS Documentation][18])ver knows API key
=
Authorized user

````

Better:

```text
JWT or IAM:
Authentication and authorization

API key:
Usage-plan identity
````

---

# 31. Mutual TLS

Mutual TLS authenticates the client using a certificate.

```text
Client certificate
       |
       v
API Gateway custom domain
       |
       v
Certificate truststore verification
```

Use cases:

* Partner-to-partner APIs.
* B2B integrations.
* Regulated machine clients.
* Certificate-based device access.

For REST APIs, mutual TLS uses a Regional custom domain and an appropriate TLS security policy. ([AWS Documentation][19]) the certificate holder. You may still need application-level permissions.

---

# 32. AppSync authorization modes

AppSync GraphQL supports:

```text
API key
AWS IAM
Amazon Cognito user pools
OpenID Connect
AWS Lambda authorization
```

An API can use a default mode plus additional authorization modes. ([AWS Documentation][20])Default:
Cognito user pools

Additional:
IAM for backend services
API key for temporary public demo queries

````

---

# 33. AppSync field-level authorization

GraphQL authorization can vary by operation or field.

Conceptual schema:

```graphql
type Todo
  @aws_cognito_user_pools
  @aws_iam {
  todoId: ID!
  title: String!
  internalAuditNote: String @aws_iam
}
````

Possible model:

```text
Normal users:
Read title and status

Trusted backend role:
Read audit fields

Administrators:
Perform delete mutation
```

Authorization should be reinforced inside resolvers using authenticated identity and tenant context.

---

# Part 3 — Throttling, validation and caching

# 34. Throttling mental model

API throttling protects backends from unlimited request rates.

```text
Client requests
      |
      v
Token bucket
      |
      ├── Token available → Request accepted
      └── No token        → HTTP 429
```

API Gateway uses rate and burst concepts.

```text
Rate:
Sustained requests per second

Burst:
Temporary request spike capacity
```

---

# 35. API Gateway account quota

API Gateway applies an account-level Regional throttle across REST, HTTP, WebSocket and callback APIs. The documented default is currently 10,000 requests per second with additional burst capacity, although account and Region-specific quota settings should be verified before production launch. ([AWS Documentation][21])city only around this front-door quota.

Also inspect:

```text
Lambda concurrency
ALB target capacity
ECS task count
Database connections
Downstream vendor rate limits
```

---

# 36. Layered throttling

```text
Account throttle
      |
      v
Stage throttle
      |
      v
Route or method throttle
      |
      v
Usage-plan throttle
      |
      v
Backend limits
```

Use different controls for different concerns:

```text
Global account protection
API-level protection
Expensive-route protection
Per-customer usage policy
Backend concurrency control
```

REST API throttles and quotas are best-effort targets rather than absolute hard financial or security limits. ([AWS Documentation][22])ve route throttling

Example routes:

```text
GET /todos:
Cheap

POST /reports:
Expensive

POST /ai/summary:
Very expensive
```

Configuration concept:

```text
GET /todos:
500 RPS

POST /reports:
10 RPS

POST /ai/summary:
2 RPS per client
```

Do not give every route the same throttle simply because they share one API.

---

# 38. HTTP `429` handling

Clients should implement:

```text
Bounded retry
Exponential backoff
Jitter
Respect Retry-After when supplied
Idempotency for retried writes
```

Bad:

```text
429
  |
  v
Retry immediately forever
```

This creates a retry storm.

---

# 39. Request validation

REST APIs can validate:

* Required headers.
* Query parameters.
* Path parameters.
* Request bodies against models.

```text
Invalid request
      |
      v
Rejected by API Gateway
      |
      v
Backend not invoked
```

Benefits:

* Lower backend cost.
* Faster failure.
* Consistent client errors.
* Reduced malformed traffic.

Validation does not replace business validation.

Example:

```text
API Gateway:
title must be a string

Application:
user may create only 100 active todos
```

---

# 40. Caching

REST API caching can store backend responses at a stage.

```text
Client
   |
   v
API Gateway cache
   |
   ├── Hit  → Return cached response
   └── Miss → Invoke backend
```

Caching can lower backend load and improve response latency. API Gateway caching is a REST API feature. ([AWS Documentation][23])

* Public reference data.
* Product catalog.
* Configuration.
* Read-heavy reports.
* Expensive but infrequently changing results.

Poor candidates:

* Highly user-specific sensitive responses.
* Rapidly changing inventory.
* Permission-dependent data without identity in the cache key.
* Non-idempotent methods.

---

# 41. Cache-key security

Bad cache key:

```text
GET /todos
```

when results differ by authenticated user.

Potential failure:

```text
User A request fills cache
      |
      v
User B receives User A data
```

Correct cache key may include:

```text
User or tenant identity
Path parameters
Relevant query parameters
Representation version
```

Caching authentication-dependent responses requires careful review.

---

# 42. AppSync caching

AppSync provides managed in-memory server-side caching for unit and pipeline resolvers.

```text
GraphQL field
      |
      v
AppSync cache
      |
      ├── Hit
      └── Resolver/data source
```

Caching can reduce resolver and data-source load. ([AWS Documentation][24])include every dimension that changes the response, particularly:

```text
User identity
Tenant ID
Resolver arguments
Authorization-sensitive fields
```

---

# Part 4 — Security controls

# 43. AWS WAF

AWS WAF can protect supported API frontends from:

* Known malicious patterns.
* IP-based abuse.
* Rate-based abuse.
* Geographic restrictions.
* Common injection attacks.
* Bot traffic.

REST APIs and AppSync APIs support AWS WAF association. AppSync WAF can inspect and block requests before resolver execution. ([AWS Documentation][1])t does not replace:

* Authentication.
* Authorization.
* Input validation.
* Business rate limits.
* Secure backend coding.

---

# 44. CORS

CORS controls whether browser JavaScript from one origin may call another origin.

Example:

```text
Frontend:
https://app.yourdatascientist.tech

API:
https://api.yourdatascientist.tech
```

Required response headers might include:

```http
Access-Control-Allow-Origin: https://app.yourdatascientist.tech
Access-Control-Allow-Methods: GET,POST,PUT,DELETE
Access-Control-Allow-Headers: Authorization,Content-Type
```

Avoid:

```http
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
```

for credentialed browser APIs.

CORS is a browser policy, not an API authentication mechanism.

---

# 45. Disable unnecessary default endpoints

When using a custom domain, consider disabling the default execute-api endpoint where supported.

Goal:

```text
Allowed:
https://api.yourdatascientist.tech

Not intended:
https://abc123.execute-api.ap-south-1.amazonaws.com
```

This helps ensure clients pass through the intended:

* Domain.
* TLS policy.
* WAF configuration.
* DNS routing.
* Governance layer.

---

# 46. Backend isolation

Secure flow:

```text
Internet
   |
   v
API Gateway
   |
   v
VPC link
   |
   v
Internal ALB
   |
   v
Private ECS tasks
   |
   v
Private database
```

The ECS service should normally accept traffic only from its intended load balancer security group.

Do not expose the backend publicly merely because API Gateway also exists.

---

# Part 5 — Deployment safety

# 47. REST API canary release

A canary release sends a percentage of stage traffic to a new deployment.

```text
Production stage
      |
      ├── 95% → Current deployment
      └──  5% → Canary deployment
```

Canary traffic receives separate logging and metrics, allowing the new deployment to be evaluated before promotion. ([AWS Documentation][25])5XX rate
4XX rate
Latency
Integration latency
Authorization failures
Business success rate
Backend errors

````

---

# 48. Canary promotion

Deployment flow:

```text
1. Deploy candidate.

2. Route 5% traffic.

3. Observe technical and business metrics.

4. Increase to 25%.

5. Increase to 50%.

6. Promote to production.

7. Set canary percentage to zero.
````

API Gateway supports promoting a canary deployment to the stage’s primary deployment. ([AWS Documentation][26])
Set canary traffic to 0%

````

A canary release is useful only if metrics and rollback decisions are automated or operationally clear.

---

# 49. Lambda alias deployment

Even when API Gateway configuration does not change, Lambda aliases can provide backend canaries.

```text
API Gateway
    |
    v
Lambda alias: production
    |
    ├── Version 41 → 90%
    └── Version 42 → 10%
````

This separates:

* API contract deployment.
* Application code deployment.

Use CodeDeploy alarms to stop or roll back unhealthy Lambda deployments.

---

# 50. OpenAPI as source of truth

For REST and HTTP APIs, consider maintaining an OpenAPI specification in Git.

```text
openapi.yaml
├── Routes
├── Schemas
├── Security definitions
├── Error responses
├── API Gateway integrations
└── Documentation
```

Benefits:

* Code review.
* Contract testing.
* Client generation.
* Documentation generation.
* Repeatable deployment.
* Drift reduction.

The Terraform AWS provider can create a REST API from an OpenAPI document and then publish it through explicit deployment and stage resources. ([Terraform Registry][27])I Gateway WebSocket APIs

# 51. WebSocket connection lifecycle

```text
Client opens connection
        |
        v
$connect route
        |
        v
Connection accepted
        |
        v
Application messages
        |
        v
$disconnect route
```

Useful routes:

```text
$connect
$disconnect
$default
sendMessage
subscribe
unsubscribe
```

A route-selection expression selects an integration using a field from the incoming message.

Example client message:

```json
{
  "action": "sendMessage",
  "roomId": "devops-class",
  "message": "Hello"
}
```

Route-selection expression:

```text
$request.body.action
```

---

# 52. Store connection IDs

API Gateway assigns a connection ID.

```text
connectionId:
dL8xYexample=
```

Store it with application context:

```text
PK = ROOM#devops-class
SK = CONNECTION#dL8xYexample

userId = user-104
connectedAt = ...
expiresAt = ...
```

A DynamoDB table is commonly used because connection membership is:

* Frequently updated.
* Key-based.
* Horizontally scalable.
* Naturally expirable.

---

# 53. Sending messages to clients

Backend flow:

```text
Business event
      |
      v
Lookup connection IDs
      |
      v
API Gateway Management API
      |
      v
Connected clients
```

Conceptual Node.js:

```javascript
import {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand
} from "@aws-sdk/client-apigatewaymanagementapi";

const client = new ApiGatewayManagementApiClient({
  endpoint: process.env.WEBSOCKET_CALLBACK_URL
});

await client.send(
  new PostToConnectionCommand({
    ConnectionId: connectionId,
    Data: Buffer.from(
      JSON.stringify({
        type: "TODO_UPDATED",
        todoId: "501"
      })
    )
  })
);
```

The callback endpoint uses the deployed WebSocket stage or custom domain.

---

# 54. Stale connections

A stored connection can become stale because:

* The client closed unexpectedly.
* The device lost connectivity.
* `$disconnect` delivery was delayed.
* The connection expired.
* The table cleanup did not run.

When callback delivery reports that the connection is gone:

```text
Delete stale connection record
```

Do not retry a permanently stale connection indefinitely.

---

# 55. WebSocket authorization

The `$connect` route is the primary connection-establishment authorization point.

Possible controls:

```text
IAM
Lambda authorizer
Token validation
Tenant membership check
```

After connection, the backend should not blindly trust every message.

Per-message authorization may still be required for actions such as:

```text
join private room
send administrative command
subscribe to another user’s channel
```

A user authenticated at connection time may not be authorized for every later route.

---

# 56. WebSocket scaling model

Avoid:

```text
Broadcast to every stored connection
inside one Lambda invocation
```

Better:

```text
Event
  |
  v
SQS / Kinesis
  |
  v
Fan-out workers
  |
  v
PostToConnection
```

This provides:

* Controlled concurrency.
* Retries.
* Back-pressure.
* Batch distribution.
* DLQ handling.

---

# Part 7 — AWS AppSync GraphQL

# 57. GraphQL mental model

REST:

```text
GET /users/104
GET /users/104/todos
GET /users/104/profile
```

GraphQL:

```graphql
query GetUserDashboard {
  user(id: "104") {
    name
    profile {
      avatarUrl
    }
    todos(status: OPEN) {
      todoId
      title
    }
  }
}
```

One request can retrieve fields from several backend data sources through one typed schema.

---

# 58. GraphQL schema

Example:

```graphql
type Todo {
  todoId: ID!
  userId: ID!
  title: String!
  description: String
  status: TodoStatus!
  createdAt: AWSDateTime!
  updatedAt: AWSDateTime!
}

enum TodoStatus {
  OPEN
  IN_PROGRESS
  COMPLETED
}

type Query {
  getTodo(todoId: ID!): Todo
  listTodos(
    userId: ID!
    status: TodoStatus
    limit: Int
    nextToken: String
  ): TodoConnection!
}

type Mutation {
  createTodo(input: CreateTodoInput!): Todo!
  updateTodo(input: UpdateTodoInput!): Todo!
  deleteTodo(todoId: ID!): Todo!
}

type Subscription {
  onTodoUpdated(userId: ID!): Todo
    @aws_subscribe(mutations: ["updateTodo"])
}
```

A GraphQL schema defines the client contract, field types, operations and relationships. ([AWS Documentation][28])mutation and subscription

## Query

Reads data.

```graphql
query {
  getTodo(todoId: "501") {
    title
    status
  }
}
```

## Mutation

Changes data.

```graphql
mutation {
  updateTodo(
    input: {
      todoId: "501"
      status: COMPLETED
    }
  ) {
    todoId
    status
  }
}
```

## Subscription

Receives real-time updates.

```graphql
subscription {
  onTodoUpdated(userId: "104") {
    todoId
    status
  }
}
```

AppSync manages the subscription WebSocket connection and distributes mutation results to matching subscribers. ([AWS Documentation][29])r

A resolver connects a GraphQL field to data or logic.

```text
Query.getTodo
      |
      v
Resolver
      |
      v
DynamoDB GetItem
```

Examples:

```text
Query.getTodo         → DynamoDB
Query.searchTodos     → OpenSearch
Mutation.createTodo   → Pipeline resolver
Todo.owner            → Lambda or DynamoDB
```

AppSync JavaScript resolvers use the `APPSYNC_JS` runtime, which supports an ECMAScript-like subset plus AppSync utility functions. ([AWS Documentation][30])resolver versus Lambda resolver

## Direct data-source resolver

```text
AppSync
   |
   v
DynamoDB
```

Benefits:

* Lower latency.
* No Lambda cold start.
* Lower operational overhead.
* Fewer services.
* Fine-grained data-source IAM role.

## Lambda resolver

```text
AppSync
   |
   v
Lambda
   |
   v
Several systems or complex logic
```

Use Lambda when:

* Complex reusable libraries are needed.
* Several external calls are required.
* Existing code must be reused.
* Resolver-runtime constraints are unsuitable.
* Heavy computation is required.

AWS recommends direct data-source access where it provides the needed functionality and Lambda for more complex business logic. ([AWS Documentation][31])solver

A unit resolver connects one GraphQL field to one data-source operation.

```text
Query.getTodo
      |
      v
DynamoDB GetItem
```

Example JavaScript resolver:

```javascript
import { util } from "@aws-appsync/utils";

export function request(ctx) {
  return {
    operation: "GetItem",
    key: util.dynamodb.toMapValues({
      PK: `TODO#${ctx.args.todoId}`,
      SK: `TODO#${ctx.args.todoId}`
    })
  };
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }

  return ctx.result;
}
```

---

# 63. Pipeline resolver

A pipeline resolver runs several AppSync functions in sequence.

```text
Mutation.createTodo
        |
        v
Check authorization
        |
        v
Validate quota
        |
        v
Write DynamoDB item
        |
        v
Publish audit event
```

Pipeline resolvers are useful when one GraphQL field requires several data operations or an authorization step before fetching or changing data. ([AWS Documentation][32])e resolver state

Resolver context can carry values through:

```text
ctx.args
ctx.identity
ctx.source
ctx.prev
ctx.result
ctx.stash
ctx.error
```

Example:

```javascript
export function request(ctx) {
  ctx.stash.todoId = util.autoId();
  ctx.stash.userId = ctx.identity.sub;

  return {};
}
```

Later pipeline functions can use:

```javascript
ctx.stash.todoId
ctx.stash.userId
```

Do not trust client-supplied ownership fields when the authenticated identity already provides the correct owner.

---

# 65. GraphQL N+1 problem

Query:

```graphql
query {
  listTodos {
    items {
      todoId
      owner {
        name
      }
    }
  }
}
```

Potential backend behaviour:

```text
1 request to list 100 todos
+
100 requests to retrieve owners
```

This is the N+1 problem.

Mitigations:

* Batch Lambda resolvers.
* Denormalized data.
* DynamoDB single-table patterns.
* Resolver caching.
* Pipeline batching.
* Query redesign.
* Restricting deeply nested operations.

GraphQL reduces client round trips but can increase backend resolver work if schema design is careless.

---

# 66. Pagination

Do not return unbounded arrays.

Bad:

```graphql
listTodos: [Todo!]!
```

Better:

```graphql
type TodoConnection {
  items: [Todo!]!
  nextToken: String
}

type Query {
  listTodos(
    userId: ID!
    limit: Int
    nextToken: String
  ): TodoConnection!
}
```

Cursor or token-based pagination scales better than returning every item or using large offsets.

---

# 67. GraphQL query complexity

A valid GraphQL query can still be expensive.

```graphql
query {
  tenants {
    users {
      todos {
        comments {
          author {
            profile {
              ...
            }
          }
        }
      }
    }
  }
}
```

Protect AppSync with:

* Schema design.
* Authorization.
* Pagination.
* Resolver-level limits.
* WAF.
* Caching.
* Query-depth and operation controls where appropriate.
* Monitoring per resolver and data source.

---

# 68. AppSync subscriptions

AppSync subscriptions are normally triggered by GraphQL mutations.

```text
Client A subscribes
        |
        v
onTodoUpdated(userId: "104")

Client B performs updateTodo
        |
        v
Mutation result
        |
        v
Matching subscribers receive selected fields
```

The mutation selection set influences the data available to subscription delivery. ([AWS Documentation][29])d subscription filtering

Basic filtering can use client-provided subscription arguments.

Enhanced filters let backend resolver logic define more advanced delivery conditions.

Example:

```text
Deliver when:
tenantId = tenant-38
AND
priority in [HIGH, CRITICAL]
AND
status != COMPLETED
```

Enhanced subscription filters are configured in subscription resolver logic and support richer logical operators than simple subscription arguments. ([AWS Documentation][33])d filters when clients should not control the entire authorization or routing condition.

---

# 70. Subscription security

Bad subscription:

```graphql
subscription {
  onAnyTodoUpdated {
    todoId
    userId
    title
  }
}
```

A user may receive another tenant’s data.

Better:

```text
Authenticated tenant:
tenant-38

Subscription filter:
tenantId = tenant-38
```

The server must derive trusted tenant scope from:

```text
ctx.identity
```

not solely from client arguments.

---

# 71. Conflict detection

AppSync supports version-based conflict detection and resolution for synchronization scenarios.

Possible approaches include:

```text
Optimistic concurrency
Automatic merge
Custom Lambda conflict handling
```

This is useful for mobile or occasionally connected clients updating synchronized records. ([AWS Documentation][34])quire a business decision:

```text
Last writer wins?
Merge nonoverlapping fields?
Reject and ask user?
Run custom resolution logic?
```

---

# 72. Merged APIs

Merged APIs combine several source AppSync GraphQL APIs into one endpoint.

```text
Team A source API ─┐
Team B source API ─┼──> Merged GraphQL API
Team C source API ─┘
```

The merged API imports source:

* Types.
* Resolvers.
* Data sources.
* Functions.

The merged-API owner controls front-door settings such as authorization, logging, tracing, caching and WAF. Schema conflicts must be resolved when source definitions overlap incompatibly. ([AWS Documentation][35])ge organisations.

* Domain-oriented teams.
* One client-facing graph.
* Independent source API ownership.

---

# 73. Private AppSync API

AppSync supports private GraphQL and real-time endpoints accessible through VPC connectivity.

```text
Internal application
       |
       v
AppSync VPC endpoint
       |
       v
Private AppSync API
```

Private APIs restrict access to internal applications without exposing GraphQL or real-time endpoints publicly. ([AWS Documentation][36])rnal platform APIs.

* Regulated workloads.
* Service-to-service GraphQL.
* Corporate-network applications.

---

# 74. AppSync custom domain

Default endpoints include separate GraphQL and real-time hostnames.

A custom domain can provide a unified memorable hostname for both.

```text
https://graphql.yourdatascientist.tech/graphql
wss://graphql.yourdatascientist.tech/realtime
```

AppSync supports custom domains for GraphQL and real-time APIs. ([AWS Documentation][37])pSync Events

# 75. When to choose AppSync Events

Choose AppSync Events when:

* You need channel-based Pub/Sub.
* Clients publish and subscribe in real time.
* No GraphQL data-query layer is required.
* You want managed WebSocket scaling.
* You want namespace-level authorization and handlers.
* You want millions of subscriber connections without operating connection infrastructure.

AppSync Events is designed as a serverless WebSocket Pub/Sub API service. ([AWS Documentation][6])ce and channel

```text
Namespace:
todo

Channels:
todo/user/104
todo/tenant/38
todo/project/devops
```

A namespace defines:

* Available channel patterns.
* Authorization behaviour.
* Publish handlers.
* Subscribe handlers.
* Data-source integrations.

Channels are created on demand when clients publish or subscribe. ([AWS Documentation][38])andler lifecycle

Conceptual handlers:

```text
onPublish
onSubscribe
```

Example:

```javascript
export function onSubscribe(ctx) {
  const userTenant = ctx.identity.claims["custom:tenantId"];
  const requestedTenant = ctx.channel.split("/")[2];

  if (userTenant !== requestedTenant) {
    util.unauthorized();
  }
}
```

Handlers can perform custom logic and may integrate with data sources. AppSync Events supports direct handlers or request/response handlers for data-source-backed processing. ([AWS Documentation][39]) Event data sources

An Event API can use data-source integrations to:

* Save a published event in DynamoDB.
* Invoke Lambda after publication.
* Validate subscriptions against Aurora.
* Query authorization state.
* Route events through broader event architectures.
* Call HTTP endpoints.

([AWS Documentation][40])Client publishes todo update
|
v
onPublish handler
|
├── Validate payload
├── Store audit record
├── Invoke processing Lambda
└── Broadcast event

````

---

# 79. GraphQL subscription versus AppSync Events

## GraphQL subscription

```text
Mutation changes GraphQL data
        |
        v
Subscribers receive mutation output
````

Choose when real-time updates are part of a GraphQL data API.

## AppSync Events

```text
Publisher sends arbitrary channel event
        |
        v
Channel subscribers receive event
```

Choose for generic Pub/Sub, chat, live signals or collaboration events independent of GraphQL mutations.

---

# Part 9 — Observability

# 80. API Gateway access logs

Access logs should capture a structured record for every request.

Example JSON format:

```json
{
  "requestId": "$context.requestId",
  "ip": "$context.identity.sourceIp",
  "requestTime": "$context.requestTime",
  "httpMethod": "$context.httpMethod",
  "routeKey": "$context.routeKey",
  "status": "$context.status",
  "responseLength": "$context.responseLength",
  "integrationError": "$context.integrationErrorMessage"
}
```

API Gateway can publish access and execution logs to CloudWatch Logs. ([AWS Documentation][41])Authorization tokens.

* Passwords.
* Session cookies.
* Full sensitive request bodies.
* Payment information.

---

# 81. Execution logs versus access logs

## Access log

One structured summary per request.

Use for:

* Traffic analytics.
* Status codes.
* Latency.
* Source IP.
* Request IDs.
* Incident correlation.

## Execution log

Detailed API Gateway processing information.

Use for:

* Mapping-template failures.
* Integration debugging.
* Authorizer errors.
* Backend responses.
* Request transformations.

Execution logging can expose payloads and therefore needs tighter privacy review.

---

# 82. API Gateway metrics

Monitor:

```text
Count
4XXError
5XXError
Latency
IntegrationLatency
CacheHitCount
CacheMissCount
```

Interpretation:

```text
Latency:
Total API Gateway request duration

IntegrationLatency:
Time spent waiting for backend
```

If:

```text
Latency high
IntegrationLatency high
```

the backend is likely slow.

If:

```text
Latency high
IntegrationLatency low
```

investigate:

* Authorizer.
* Request transformation.
* API Gateway overhead.
* Response transformation.
* Network/client behaviour.

---

# 83. API Gateway X-Ray

API Gateway REST stages can enable X-Ray active tracing.

```text
Client
   |
   v
API Gateway trace segment
   |
   v
Lambda
   |
   v
DynamoDB / HTTP / downstream services
```

X-Ray helps correlate request latency across API Gateway and participating backend services. ([AWS Documentation][42]) logging

AppSync GraphQL logs can expose:

* Query parsing.
* Validation.
* Field resolution.
* Resolver execution.
* Data-source calls.
* Errors.

AppSync also supports request, resolver and data-source metrics configurations. ([AWS Documentation][43])gs selectively because full resolver logging can create substantial volume and expose sensitive values.

---

# 85. AppSync X-Ray

AppSync GraphQL APIs can enable X-Ray tracing.

```text
GraphQL request
      |
      v
AppSync
      |
      ├── Resolver A
      ├── Resolver B
      └── Data-source calls
```

This helps identify which GraphQL resolver or downstream system contributes to request latency. ([AWS Documentation][44]) Event logging

Event APIs can log:

* Request-level information.
* Handler execution.
* Headers.
* Processing details.
* Token consumption.

([AWS Documentation][45])oads as potentially sensitive when deciding whether to include full request data.

---

# 87. Recommended alarms

API Gateway:

```text
5XX error rate above SLO
Unexpected 4XX increase
P95/P99 latency increase
Integration latency increase
429 throttles
Authorizer failures
WebSocket connection errors
```

AppSync:

```text
GraphQL request errors
Resolver errors
High resolver latency
Data-source errors
Subscription failures
Connection failures
Event-handler failures
Cache hit-rate decline
```

Backend:

```text
Lambda errors and throttles
ECS target response time
ALB unhealthy hosts
Database connections
DynamoDB throttles
External API errors
```

Front-door alarms without backend alarms provide only part of the incident picture.

---

# Part 10 — Production TodoApp architecture

# 88. REST/HTTP TodoApp architecture

```text
Users
  |
  v
CloudFront
  |
  v
AWS WAF
  |
  v
API Gateway
  |
  ├── Cognito JWT authorizer
  |
  ├── Lambda functions
  |
  └── VPC link
         |
         v
     Internal ALB
         |
         v
     ECS Todo API
         |
         ├── Aurora
         ├── ElastiCache
         ├── SQS
         └── EventBridge
```

Recommended API choice:

```text
HTTP API:
Lean API, JWT, Lambda/ECS proxy

REST API:
Usage plans, caching, validation,
private API or advanced API management
```

---

# 89. GraphQL TodoApp architecture

```text
React / mobile client
        |
        v
AppSync GraphQL
        |
        ├── Cognito authorization
        ├── DynamoDB todo resolver
        ├── Lambda business resolver
        ├── OpenSearch search resolver
        └── Real-time subscriptions
```

Strong fit when a dashboard needs:

```text
User profile
Open todos
Completed count
Recent activity
Team membership
```

through one client-selected query.

---

# 90. Real-time TodoApp architecture

```text
Todo updated
     |
     v
EventBridge
     |
     v
AppSync Events publisher
     |
     v
Channel:
todo/tenant/38
     |
     ├── Web client A
     ├── Web client B
     └── Mobile client
```

Alternative:

```text
updateTodo GraphQL mutation
        |
        v
AppSync GraphQL subscription
```

Use subscriptions when the event directly follows a GraphQL mutation.

Use AppSync Events when real-time signals come from several systems or do not naturally belong to GraphQL mutations.

---

# Part 11 — Terraform implementation

# 91. Terraform HTTP API

```hcl
resource "aws_apigatewayv2_api" "todo" {
  name          = "production-todo-http"
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
    ManagedBy   = "Terraform"
  }
}
```

---

# 92. HTTP API JWT authorizer

```hcl
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id = aws_apigatewayv2_api.todo.id

  name            = "production-cognito"
  authorizer_type = "JWT"

  identity_sources = [
    "$request.header.Authorization"
  ]

  jwt_configuration {
    audience = [
      aws_cognito_user_pool_client.todo.id
    ]

    issuer = (
      "https://${aws_cognito_user_pool.todo.endpoint}"
    )
  }
}
```

---

# 93. Lambda integration and route

```hcl
resource "aws_apigatewayv2_integration" "todo_lambda" {
  api_id = aws_apigatewayv2_api.todo.id

  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.todo_api.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "create_todo" {
  api_id = aws_apigatewayv2_api.todo.id

  route_key = "POST /todos"

  target = (
    "integrations/${aws_apigatewayv2_integration.todo_lambda.id}"
  )

  authorization_type = "JWT"
  authorizer_id       = aws_apigatewayv2_authorizer.cognito.id

  authorization_scopes = [
    "todo/write"
  ]
}
```

The exact supported timeout and provider arguments should be verified against the selected integration type and current provider version.

---

# 94. Lambda invoke permission

```hcl
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.todo_api.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = (
    "${aws_apigatewayv2_api.todo.execution_arn}/*/*"
  )
}
```

Restrict the source ARN more tightly when only specific routes or stages should invoke the function.

---

# 95. HTTP API stage and access logs

```hcl
resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/production-todo-http"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_apigatewayv2_stage" "production" {
  api_id = aws_apigatewayv2_api.todo.id

  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn

    format = jsonencode({
      requestId          = "$context.requestId"
      sourceIp           = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      protocol           = "$context.protocol"
      httpMethod         = "$context.httpMethod"
      routeKey           = "$context.routeKey"
      status             = "$context.status"
      responseLength     = "$context.responseLength"
      integrationError   = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = 500
    throttling_rate_limit  = 250
  }

  tags = {
    Environment = "production"
  }
}
```

The current Terraform provider exposes API Gateway v2 stage logging and route-throttle configuration through `aws_apigatewayv2_stage`. ([Terraform Registry][46])I private ALB integration

```hcl
resource "aws_apigatewayv2_vpc_link" "todo" {
  name = "production-todo"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  security_group_ids = [
    aws_security_group.api_gateway_vpc_link.id
  ]
}

resource "aws_apigatewayv2_integration" "private_alb" {
  api_id = aws_apigatewayv2_api.todo.id

  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"

  integration_uri = (
    aws_lb_listener.internal_https.arn
  )

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.todo.id

  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id = aws_apigatewayv2_api.todo.id

  route_key = "ANY /{proxy+}"

  target = (
    "integrations/${aws_apigatewayv2_integration.private_alb.id}"
  )

  authorization_type = "JWT"
  authorizer_id       = aws_apigatewayv2_authorizer.cognito.id
}
```

The provider’s v2 integration resource accepts an ALB or NLB listener ARN for HTTP API private integrations. ([Terraform Registry][47])rm REST API using OpenAPI

```hcl
resource "aws_api_gateway_rest_api" "todo" {
  name = "production-todo-rest"

  body = templatefile(
    "${path.module}/openapi.yaml",
    {
      lambda_invoke_arn = aws_lambda_function.todo_api.invoke_arn
      cognito_pool_arn  = aws_cognito_user_pool.todo.arn
    }
  )

  endpoint_configuration {
    types = [
      "REGIONAL"
    ]
  }

  disable_execute_api_endpoint = true

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}

resource "aws_api_gateway_deployment" "todo" {
  rest_api_id = aws_api_gateway_rest_api.todo.id

  triggers = {
    redeployment = sha1(
      aws_api_gateway_rest_api.todo.body
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "production" {
  rest_api_id  = aws_api_gateway_rest_api.todo.id
  deployment_id = aws_api_gateway_deployment.todo.id

  stage_name = "production"

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format          = jsonencode({
      requestId  = "$context.requestId"
      status     = "$context.status"
      latency    = "$context.responseLatency"
      error      = "$context.error.message"
    })
  }
}
```

Terraform models the REST API, immutable deployment snapshot and stage as separate resources. ([Terraform Registry][27])I method settings

```hcl
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.todo.id
  stage_name  = aws_api_gateway_stage.production.stage_name

  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "ERROR"
    data_trace_enabled     = false
    throttling_rate_limit  = 500
    throttling_burst_limit = 1000
    caching_enabled        = false
  }
}
```

Use a separate `aws_api_gateway_stage` rather than relying on the deployment resource’s older stage shortcut when managing method settings. ([Terraform Registry][48])rm AppSync GraphQL API

```hcl
resource "aws_appsync_graphql_api" "todo" {
  name = "production-todo-graphql"

  authentication_type = "AMAZON_COGNITO_USER_POOLS"

  user_pool_config {
    aws_region     = var.aws_region
    default_action = "ALLOW"
    user_pool_id   = aws_cognito_user_pool.todo.id
  }

  additional_authentication_provider {
    authentication_type = "AWS_IAM"
  }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ERROR"
    exclude_verbose_content  = true
  }

  xray_enabled = true

  visibility = "GLOBAL"

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

The current Terraform provider supports managing GraphQL APIs and associating them with resources such as resolvers and WAF ACLs. ([Terraform Registry][49])c DynamoDB data source

```hcl
resource "aws_appsync_datasource" "todos" {
  api_id = aws_appsync_graphql_api.todo.id

  name = "TodoTable"
  type = "AMAZON_DYNAMODB"

  service_role_arn = aws_iam_role.appsync_dynamodb.arn

  dynamodb_config {
    table_name = aws_dynamodb_table.todos.name
    region     = var.aws_region
  }
}
```

Use an AppSync-specific service role with only the table actions required by its resolvers.

---

# 101. AppSync schema

```hcl
resource "aws_appsync_graphql_api" "todo" {
  # API configuration omitted for brevity.
}

resource "aws_appsync_resolver" "get_todo" {
  api_id = aws_appsync_graphql_api.todo.id

  type       = "Query"
  field      = "getTodo"
  data_source = aws_appsync_datasource.todos.name

  kind = "UNIT"

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = file(
    "${path.module}/resolvers/getTodo.js"
  )
}
```

Ensure schema creation occurs before resolver creation through explicit resource references or dependencies.

---

# 102. Terraform WAF association

```hcl
resource "aws_wafv2_web_acl_association" "appsync" {
  resource_arn = aws_appsync_graphql_api.todo.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}
```

Create rules for:

* Managed common threats.
* Known bad inputs.
* IP reputation.
* Rate limiting.
* Geographic restrictions where justified.

---

# Part 12 — CLI validation

# 103. Test an HTTP API

```bash
curl \
  --request GET \
  --url "https://api.yourdatascientist.tech/todos" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Accept: application/json"
```

Create:

```bash
curl \
  --request POST \
  --url "https://api.yourdatascientist.tech/todos" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "title": "Learn API Gateway",
    "priority": "HIGH"
  }'
```

---

# 104. Inspect API Gateway APIs

HTTP APIs:

```bash
aws apigatewayv2 get-apis \
  --region ap-south-1
```

Routes:

```bash
aws apigatewayv2 get-routes \
  --api-id "$API_ID" \
  --region ap-south-1
```

Stages:

```bash
aws apigatewayv2 get-stages \
  --api-id "$API_ID" \
  --region ap-south-1
```

REST APIs:

```bash
aws apigateway get-rest-apis \
  --region ap-south-1
```

---

# 105. GraphQL request

```bash
curl \
  --request POST \
  --url "https://graphql.yourdatascientist.tech/graphql" \
  --header "Authorization: $ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "query": "query GetTodo($id: ID!) { getTodo(todoId: $id) { todoId title status } }",
    "variables": {
      "id": "501"
    }
  }'
```

Remember that GraphQL can return:

```http
HTTP 200
```

with resolver or field errors inside:

```json
{
  "data": {
    "getTodo": null
  },
  "errors": [
    {
      "message": "Todo not found"
    }
  ]
}
```

Clients must inspect the GraphQL `errors` array rather than relying only on HTTP status.

---

# Part 13 — Troubleshooting

# 106. `401 Unauthorized`

Check:

* Authorization header exists.
* Token has not expired.
* JWT issuer is correct.
* Audience/client ID is correct.
* Required scope exists.
* Token type is correct.
* Authorizer identity source is correct.
* Lambda authorizer response format is valid.
* Client clock is correct.

Distinguish:

```text
401:
Identity could not be authenticated

403:
Identity was authenticated but access was denied
```

---

# 107. `403 Forbidden`

Possible causes:

* IAM principal lacks `execute-api:Invoke`.
* API resource policy denies access.
* VPC endpoint policy denies private API.
* Cognito scope is missing.
* Lambda authorizer returns Deny.
* AppSync field authorization denies operation.
* WAF blocks request.
* mTLS certificate is not trusted.
* Wrong tenant or role.
* Default API endpoint was disabled.

Troubleshoot from outer to inner layers:

```text
DNS/TLS
  |
  v
WAF
  |
  v
API resource policy
  |
  v
Authentication
  |
  v
Authorization
  |
  v
Backend
```

---

# 108. `429 Too Many Requests`

Check:

* Account API Gateway quota.
* Stage or route throttle.
* Usage-plan throttle.
* Lambda concurrency.
* AppSync request limits.
* WAF rate-based rule.
* Backend rate limit.
* Client retry storm.

Actions:

```text
Add bounded client backoff
Reduce request bursts
Use caching
Batch operations
Request quota increase
Scale backend
Set route-specific throttling
```

Do not only raise the API Gateway limit if the backend is already overloaded.

---

# 109. `500` and `502`

## `500`

Possible causes:

* Mapping-template error.
* Authorizer execution error.
* API Gateway internal configuration.
* Invalid integration response.
* AppSync resolver failure.

## `502 Bad Gateway`

Possible causes:

* Lambda proxy response has invalid shape.
* Backend closed connection.
* ALB target returned invalid response.
* TLS negotiation to backend failed.
* Integration response mapping failed.
* Backend response exceeded supported limits.

For Lambda proxy, verify:

```json
{
  "statusCode": 200,
  "headers": {},
  "body": "{}"
}
```

and make sure `body` is a string.

---

# 110. API works through default endpoint but not custom domain

Check:

* ACM certificate Region.
* Certificate covers the hostname.
* Custom-domain status is available.
* API mapping exists.
* Route 53 alias points to correct API domain.
* TLS policy.
* Private custom-domain association.
* Public versus private domain type.
* Default stage path differences.
* CloudFront or DNS cache.

Regional domain:

```text
Certificate:
Same API Region
```

Edge-optimized:

```text
Certificate:
us-east-1
```

---

# 111. VPC integration returns timeout

Check:

* VPC link status.
* Selected subnets.
* VPC-link security group.
* ALB listener.
* ALB target health.
* ECS security group.
* Route and network ACL.
* Backend protocol and port.
* Internal DNS or Cloud Map.
* Backend processing time.
* Path handling.

A healthy API Gateway endpoint cannot compensate for an unhealthy ALB target group.

---

# 112. CORS error

Browser message:

```text
Blocked by CORS policy
```

Check:

* `OPTIONS` response.
* Allowed origin exact match.
* Allowed methods.
* Allowed headers.
* Credentials configuration.
* Error responses include CORS headers.
* CloudFront caches by `Origin` where necessary.
* Backend and API Gateway are not adding conflicting headers.

Test using browser developer tools because `curl` does not enforce browser CORS policy.

---

# 113. AppSync “missing resolver”

GraphQL field:

```graphql
type Query {
  getTodo(todoId: ID!): Todo
}
```

but no resolver is attached.

Result may be `null` or an unexpected response depending on field behaviour.

Check:

* Correct API ID.
* Type name case.
* Field name case.
* Resolver deployed.
* Data source exists.
* Resolver code is valid.
* Schema deployment completed first.

AppSync documents missing resolvers, key mappings, invalid return types and template problems among common resolver mistakes. ([AWS Documentation][50])c DynamoDB key error

Schema argument:

```text
todoId
```

Table key:

```text
PK
SK
```

Resolver incorrectly sends:

```json
{
  "todoId": "501"
}
```

Correct resolver may need:

```json
{
  "PK": "TODO#501",
  "SK": "TODO#501"
}
```

Verify:

* Partition-key name.
* Sort-key name.
* Key type.
* DynamoDB conversion.
* Single-table prefixes.
* IAM permissions.
* Region.

---

# 115. GraphQL returns `null` unexpectedly

Check:

* Resolver output matches GraphQL field type.
* Non-null field was not returned as `null`.
* Resolver response does not wrap the result incorrectly.
* Data-source item exists.
* Authorization did not filter the result.
* Pipeline `ctx.prev.result` is correct.
* Cache does not contain stale null data.
* Field name matches returned object property.

GraphQL non-null propagation can cause a parent object to become null when a required child field fails.

---

# 116. Subscription receives no events

Check:

* WebSocket connected.
* Client is authorized.
* Subscription mutation mapping is correct.
* The mutation actually ran.
* Mutation selection set contains required fields.
* Subscription filter matches.
* Tenant filter derives from identity correctly.
* Client reconnected after network loss.
* Custom-domain real-time endpoint is correct.
* Resolver does not suppress event delivery.

---

# 117. WebSocket callback returns gone

Meaning:

```text
Connection ID is no longer active
```

Action:

```text
Delete connection from registry
Do not retry it indefinitely
```

Also inspect:

* Connection TTL cleanup.
* `$disconnect` processing.
* Client reconnection.
* Multi-device connection records.
* Channel membership cleanup.

---

# 118. Slow GraphQL query

Check:

* Number of resolvers.
* N+1 behaviour.
* DynamoDB scans.
* OpenSearch query complexity.
* Lambda cold starts.
* Pipeline resolver steps.
* Unbounded list fields.
* Deep nested query.
* Cache hit rate.
* Data-source latency.
* Field-level X-Ray trace.

Do not solve every slow query by increasing backend capacity. Fix schema and resolver access patterns.

---

# 119. REST or GraphQL?

Choose REST when:

* Resources and operations are straightforward.
* HTTP caching semantics are important.
* External partners expect OpenAPI.
* Each endpoint has a clear bounded response.
* Client needs are predictable.

Choose GraphQL when:

* Several client types need different fields.
* Data comes from several backends.
* Over-fetching or under-fetching is significant.
* A typed schema is valuable.
* Real-time subscriptions fit the data model.

Do not choose GraphQL only because it appears more modern.

---

# 120. API Gateway WebSocket or AppSync Events?

Choose API Gateway WebSocket when:

* You need custom route semantics.
* You want complete control of connection storage.
* The protocol is application-specific.
* Backend-driven callback control is required.
* Existing WebSocket architecture should be migrated.

Choose AppSync Events when:

* The main requirement is channel-based Pub/Sub.
* You want managed connection and channel scaling.
* HTTP/WebSocket publishing is useful.
* Namespace-level handlers and authorization fit.
* You want less connection-management code.

---

# 121. Production readiness checklist

```text
[ ] API type decision is documented
[ ] REST versus HTTP feature comparison is completed
[ ] AppSync versus API Gateway decision is documented
[ ] Public, Regional, edge or private endpoint is intentional
[ ] Private integration and private API are not confused
[ ] Backend resources remain private
[ ] Authentication mode is appropriate
[ ] Authorization is enforced per tenant and resource
[ ] API keys are not used as the sole authentication control
[ ] JWT issuer and audience are validated
[ ] OAuth scopes are least privilege
[ ] Lambda authorizer caching is reviewed
[ ] IAM invocation policies are least privilege
[ ] mTLS is evaluated for partner APIs
[ ] WAF is attached where supported and required
[ ] CORS allows only required origins
[ ] Default execute-api endpoint is reviewed
[ ] Throttling protects downstream capacity
[ ] Expensive routes have lower limits
[ ] Clients implement bounded backoff for 429 responses
[ ] Request validation is enabled
[ ] Response caching is tenant-safe
[ ] Cache keys include all identity dimensions
[ ] Custom domain certificate is in the correct Region
[ ] DNS records are managed by infrastructure as code
[ ] OpenAPI or GraphQL schema is stored in Git
[ ] Breaking changes require a new contract version
[ ] Canary deployment and rollback are tested
[ ] Access logs are structured
[ ] Sensitive headers and bodies are not logged
[ ] Metrics and alarms exist
[ ] X-Ray tracing is enabled where useful
[ ] WebSocket connections have cleanup logic
[ ] WebSocket messages are authorized, not only connections
[ ] GraphQL list fields are paginated
[ ] GraphQL query cost is controlled
[ ] Resolver access patterns avoid scans
[ ] N+1 behaviour is tested
[ ] AppSync subscription filters enforce tenant isolation
[ ] AppSync cache keys are identity-safe
[ ] AppSync Events namespaces have explicit authorization
[ ] VPC-link and backend health are monitored
[ ] Multi-Region API recovery is documented
```

---

# 122. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
API Gateway:
Managed REST, HTTP and WebSocket frontend

AppSync:
Managed GraphQL and Pub/Sub APIs

Cognito:
User authentication and token issuance

WAF:
Web request filtering
```

## Solutions Architect Associate

Understand:

```text
REST versus HTTP APIs
Lambda proxy integration
VPC links
Private REST APIs
Regional versus edge endpoints
JWT and Cognito authorizers
API caching
Throttling
WebSocket routes
AppSync queries, mutations and subscriptions
```

## DevOps Engineer Professional

Understand:

```text
Canary API deployment
OpenAPI infrastructure deployment
Custom-domain certificate Regions
WAF and mTLS
Stage logging and tracing
Lambda authorizer failures
Tenant-safe caching
GraphQL resolver monitoring
Pipeline resolvers
Merged APIs
Private AppSync APIs
Real-time connection recovery
```

---

# 123. Interview questions

## Question 1: What is Amazon API Gateway?

**Answer:**

It is a managed service for creating, publishing, securing, monitoring and operating REST, HTTP and WebSocket APIs.

## Question 2: What is the difference between HTTP and REST APIs?

**Answer:**

HTTP APIs provide a leaner, lower-cost feature set. REST APIs provide advanced API-management features such as usage plans, API keys, caching, request validation, WAF integration and private API endpoints.

## Question 3: What is a Lambda proxy integration?

**Answer:**

API Gateway forwards request information to Lambda in a standard event format, and Lambda returns the HTTP status, headers and body.

## Question 4: What is a VPC link?

**Answer:**

It is a managed connection that lets API Gateway integrate with private resources such as an internal ALB, NLB or Cloud Map service.

## Question 5: What is the difference between a private integration and private API?

**Answer:**

A private integration connects an API to a private backend. A private API makes the API Gateway endpoint itself accessible only through private VPC connectivity.

## Question 6: Are API keys authentication credentials?

**Answer:**

No. They are mainly used for client identification, usage plans, throttling and quotas. Authentication should use IAM, Cognito, JWTs or authorizers.

## Question 7: What is an API Gateway stage?

**Answer:**

A stage is a named reference to an API deployment and contains environment-specific settings such as logs, throttling, caching and canary configuration.

## Question 8: Where must an ACM certificate exist for a Regional custom domain?

**Answer:**

In the same AWS Region as the API.

## Question 9: Where must an edge-optimized custom-domain certificate exist?

**Answer:**

In `us-east-1`.

## Question 10: What is an API Gateway canary deployment?

**Answer:**

It routes a percentage of stage traffic to a candidate deployment so it can be monitored before promotion.

## Question 11: What is a WebSocket route?

**Answer:**

It maps a WebSocket message route key, such as `sendMessage`, to a backend integration.

## Question 12: Why store WebSocket connection IDs?

**Answer:**

The backend needs connection IDs to send callback messages to currently connected clients.

## Question 13: What is AWS AppSync?

**Answer:**

It is a managed service for building secure GraphQL and Pub/Sub APIs with support for data-source integrations and real-time communication.

## Question 14: What is an AppSync resolver?

**Answer:**

A resolver connects a GraphQL field to a data source or custom processing logic.

## Question 15: What is a pipeline resolver?

**Answer:**

It executes several AppSync functions in sequence to resolve one GraphQL field.

## Question 16: What triggers an AppSync GraphQL subscription?

**Answer:**

A configured GraphQL mutation triggers it, and matching subscribers receive selected mutation-result fields.

## Question 17: What is an AppSync merged API?

**Answer:**

It combines schema, resolver, function and data-source components from several source AppSync APIs into one GraphQL endpoint.

## Question 18: What is AppSync Events?

**Answer:**

It is a managed real-time Pub/Sub API service where clients publish to channels and subscribe using WebSockets.

## Question 19: What is the GraphQL N+1 problem?

**Answer:**

One list resolver causes many additional per-item resolver calls, creating excessive backend requests.

## Question 20: How should an API be protected from excessive traffic?

**Answer:**

Use layered throttling, WAF where supported, caching, backend concurrency limits, validation and client backoff rather than relying on one throttle setting.

---

# 124. Never-forget revision

```text
HTTP API:
Lean RESTful API front door.

REST API:
Advanced API-management front door.

WebSocket API:
Persistent bidirectional connection.

AppSync GraphQL:
Typed, client-selected data API.

AppSync Events:
Managed channel-based Pub/Sub.

Integration:
Backend called by a route or method.

VPC link:
Private path to VPC backends.

Private integration:
Private backend.

Private API:
Private API Gateway frontend.

Stage:
Named API deployment environment.

JWT authorizer:
Validates OIDC/OAuth token.

Lambda authorizer:
Runs custom authorization logic.

API key:
Usage identity, not complete authentication.

Throttle:
Controls request rate and burst.

Cache:
Avoids repeated backend requests.

Canary:
Routes a percentage to a candidate release.

Resolver:
Connects a GraphQL field to data.

Pipeline resolver:
Runs several resolver functions.

Subscription:
Real-time GraphQL update.

Namespace:
AppSync Event channel grouping.

Connection ID:
WebSocket callback identity.
```

## One-line memory trick

```text
Use HTTP APIs for lean REST.
Use REST APIs for advanced management.
Use WebSockets for custom bidirectional protocols.
Use GraphQL for client-driven data composition.
Use AppSync Events for managed Pub/Sub.
Authenticate every caller.
Authorize every resource.
Throttle before the backend fails.
```

## Lesson 53 outcome

You can now design APIs where:

```text
A simple Lambda API needs JWT authentication
    → HTTP API provides the lean front door.

Partners require API keys and quotas
    → REST API usage plans manage consumption.

ECS runs behind a private ALB
    → VPC link exposes it without public tasks.

Only internal VPC workloads may invoke the API
    → A private REST API uses an interface endpoint.

A release needs gradual exposure
    → Canary deployment receives controlled traffic.

Browser clients need live status updates
    → WebSocket API or AppSync Events pushes updates.

Mobile and web clients require different data shapes
    → AppSync GraphQL resolves only requested fields.

One GraphQL operation needs several data steps
    → A pipeline resolver composes the process.

Several teams own separate GraphQL domains
    → A merged API creates one client endpoint.

An API becomes overloaded
    → Throttling, caching and backend concurrency protect it.
```

**Next lesson: Lesson 54 — Amazon Cognito production identity architecture: user pools, identity pools, OAuth 2.0, OIDC, hosted login, managed login, MFA, federation, groups, token scopes, machine identities, Lambda triggers and secure API authorization.**

[1]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html?utm_source=chatgpt.com "Choose between REST APIs and HTTP APIs"
[2]: https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html?utm_source=chatgpt.com "Amazon API Gateway - AWS Documentation"
[3]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-private.html?utm_source=chatgpt.com "Create private integrations for HTTP APIs in API Gateway"
[4]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api.html?utm_source=chatgpt.com "API Gateway WebSocket APIs"
[5]: https://docs.aws.amazon.com/appsync/latest/devguide/what-is-appsync.html?utm_source=chatgpt.com "What is AWS AppSync?"
[6]: https://docs.aws.amazon.com/appsync/latest/eventapi/event-api-welcome.html?utm_source=chatgpt.com "AWS AppSync Events"
[7]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-integration-types.html?utm_source=chatgpt.com "Choose an API Gateway API integration type"
[8]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-private-apis.html?utm_source=chatgpt.com "Private REST APIs in API Gateway"
[9]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-private-api-test-invoke-url.html?utm_source=chatgpt.com "Invoke a private API - AWS Documentation - Amazon.com"
[10]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-endpoint-types.html?utm_source=chatgpt.com "API endpoint types for REST APIs in API Gateway"
[11]: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-stages.html?utm_source=chatgpt.com "Set up a stage for a REST API in API Gateway"
[12]: https://docs.aws.amazon.com/apigateway/latest/developerguide/stage-variables.html?utm_source=chatgpt.com "Use stage variables for a REST API in API Gateway"
[13]: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-custom-domains.html?utm_source=chatgpt.com "Custom domain name for public REST APIs in API Gateway"
[14]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-regional-api-custom-domain-create.html?utm_source=chatgpt.com "Set up a Regional custom domain name in API Gateway"
[15]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-integrate-with-cognito.html?utm_source=chatgpt.com "Control access to REST APIs using Amazon Cognito user ..."
[16]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html?utm_source=chatgpt.com "Control access to HTTP APIs with JWT authorizers in API ..."
[17]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html?utm_source=chatgpt.com "Use API Gateway Lambda authorizers"
[18]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html?utm_source=chatgpt.com "Usage plans and API keys for REST APIs in API Gateway"
[19]: https://docs.aws.amazon.com/apigateway/latest/developerguide/rest-api-mutual-tls.html?utm_source=chatgpt.com "How to turn on mutual TLS authentication for your REST APIs ..."
[20]: https://docs.aws.amazon.com/appsync/latest/devguide/security-authz.html?utm_source=chatgpt.com "Configuring authorization and authentication to secure ..."
[21]: https://docs.aws.amazon.com/apigateway/latest/developerguide/limits.html?utm_source=chatgpt.com "Amazon API Gateway quotas"
[22]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html?utm_source=chatgpt.com "Throttle requests to your REST APIs for better throughput in ..."
[23]: https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-caching.html?utm_source=chatgpt.com "Cache settings for REST APIs in API Gateway"
[24]: https://docs.aws.amazon.com/appsync/latest/devguide/enabling-caching.html?utm_source=chatgpt.com "Configuring server-side caching and API payload ..."
[25]: https://docs.aws.amazon.com/apigateway/latest/developerguide/canary-release.html?utm_source=chatgpt.com "Set up an API Gateway canary release deployment"
[26]: https://docs.aws.amazon.com/apigateway/latest/developerguide/promote-canary-deployment.html?utm_source=chatgpt.com "Promote a canary release - Amazon API Gateway"
[27]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api.html?utm_source=chatgpt.com "aws_api_gateway_rest_api | Resources | hashicorp/aws | Terraform | Terraform Registry"
[28]: https://docs.aws.amazon.com/appsync/latest/devguide/designing-your-schema.html?utm_source=chatgpt.com "Designing your GraphQL schema"
[29]: https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-real-time-data.html?utm_source=chatgpt.com "Using subscriptions for real-time data applications in AWS ..."
[30]: https://docs.aws.amazon.com/appsync/latest/devguide/resolver-util-reference-js.html?utm_source=chatgpt.com "AWS AppSync JavaScript runtime features for resolvers ..."
[31]: https://docs.aws.amazon.com/appsync/latest/devguide/choosing-data-source.html?utm_source=chatgpt.com "Choosing between direct data source access and proxying ..."
[32]: https://docs.aws.amazon.com/appsync/latest/devguide/pipeline-resolvers.html?utm_source=chatgpt.com "Configuring and using pipeline resolvers in AWS AppSync ..."
[33]: https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-real-time-enhanced-filtering.html?utm_source=chatgpt.com "Defining enhanced subscriptions filters in AWS AppSync"
[34]: https://docs.aws.amazon.com/appsync/latest/devguide/conflict-detection-and-resolution.html?utm_source=chatgpt.com "Conflict detection and resolution in AWS AppSync"
[35]: https://docs.aws.amazon.com/appsync/latest/devguide/merged-api.html?utm_source=chatgpt.com "Merging APIs in AWS AppSync"
[36]: https://docs.aws.amazon.com/appsync/latest/devguide/using-private-apis.html?utm_source=chatgpt.com "Using AWS AppSync Private APIs"
[37]: https://docs.aws.amazon.com/appsync/latest/devguide/custom-domain-name.html?utm_source=chatgpt.com "Configuring custom domain names for GraphQL and real- ..."
[38]: https://docs.aws.amazon.com/appsync/latest/eventapi/channel-namespaces.html?utm_source=chatgpt.com "Understanding channel namespaces - AWS AppSync Events"
[39]: https://docs.aws.amazon.com/appsync/latest/eventapi/channel-namespace-handlers.html?utm_source=chatgpt.com "Process real-time events with AWS AppSync event handlers"
[40]: https://docs.aws.amazon.com/appsync/latest/eventapi/event-api-concepts.html?utm_source=chatgpt.com "AWS AppSync Events concepts"
[41]: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-logging.html?utm_source=chatgpt.com "Set up CloudWatch logging for REST APIs in API Gateway"
[42]: https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-enabling-xray.html?utm_source=chatgpt.com "Set up AWS X-Ray with API Gateway REST APIs"
[43]: https://docs.aws.amazon.com/appsync/latest/devguide/monitoring.html?utm_source=chatgpt.com "Using CloudWatch to monitor and log GraphQL API data"
[44]: https://docs.aws.amazon.com/appsync/latest/devguide/x-ray-tracing.html?utm_source=chatgpt.com "Using AWS X-Ray to trace requests in AWS AppSync"
[45]: https://docs.aws.amazon.com/appsync/latest/eventapi/event-api-monitoring-cw-logs.html?utm_source=chatgpt.com "Configuring CloudWatch Logs on Event APIs"
[46]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage?utm_source=chatgpt.com "aws_apigatewayv2_stage | Resources | hashicorp/aws | Terraform | Terraform Registry"
[47]: https://registry.terraform.io/providers/-/aws/latest/docs/resources/apigatewayv2_integration?utm_source=chatgpt.com "aws_apigatewayv2_integration | Resources | hashicorp/aws | Terraform | Terraform Registry"
[48]: https://registry.terraform.io/providers/hashicorp/aws/6.10.0/docs/resources/api_gateway_method_settings?utm_source=chatgpt.com "aws_api_gateway_method_settings | Resources | hashicorp/aws | Terraform | Terraform Registry"
[49]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_graphql_api?utm_source=chatgpt.com "aws_appsync_graphql_api | Resources | hashicorp/aws | Terraform | Terraform Registry"
[50]: https://docs.aws.amazon.com/appsync/latest/devguide/troubleshooting-and-common-mistakes.html?utm_source=chatgpt.com "Troubleshooting and common mistakes in AWS AppSync"
