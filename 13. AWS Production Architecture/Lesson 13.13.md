# AWS Masterclass — Lesson 12

## Serverless on AWS — Lambda, API Gateway, DynamoDB, SQS, SNS, EventBridge, Step Functions, Retries, DLQs, and Event-Driven Architecture

Today we move from:

```text
run server all the time
manage OS
patch runtime
scale EC2/ECS capacity
pay for idle resources
```

to:

```text
run code when an event happens
AWS manages server infrastructure
scale automatically
pay mainly for execution/events/requests
connect services through events
```

AWS Lambda is a serverless compute service that runs code without you provisioning or managing servers, and functions are commonly triggered by services such as API Gateway, S3, SQS, EventBridge, and many other AWS services. ([AWS Documentation][1])

---

# 1. What does serverless really mean?

Serverless does **not** mean there are no servers.

Correct meaning:

```text
Serverless means you do not manage the servers directly.
AWS manages infrastructure, scaling, runtime environment, and availability layer.
You manage code, permissions, events, configuration, logs, and data flow.
```

Think like this:

```text
EC2:
  You rent and manage a full server.

ECS/EKS:
  You run containers with orchestration.

Lambda:
  You upload function code.
  AWS runs it only when invoked.
```

Simple analogy:

```text
EC2:
  Own/manage the kitchen.

ECS:
  Use a managed kitchen team but still package meals.

Lambda:
  Give AWS a recipe.
  AWS cooks only when an order arrives.
```

---

# 2. Core serverless services

| Need                                | AWS service                           |
| ----------------------------------- | ------------------------------------- |
| Run code on event                   | Lambda                                |
| Public API endpoint                 | API Gateway                           |
| Serverless NoSQL database           | DynamoDB                              |
| Queue between services              | SQS                                   |
| Publish message to many subscribers | SNS                                   |
| Route events between apps/services  | EventBridge                           |
| Orchestrate multi-step workflow     | Step Functions                        |
| Store files/events                  | S3                                    |
| Store secrets                       | Secrets Manager / SSM Parameter Store |
| Logs/metrics                        | CloudWatch                            |

A common production serverless API looks like this:

```text
User
  ↓
API Gateway
  ↓
Lambda
  ↓
DynamoDB
```

A common event-driven backend looks like this:

```text
Order created
  ↓
EventBridge
  ├── Lambda: send email
  ├── Lambda: update analytics
  └── SQS: fulfillment queue
```

---

# 3. AWS Lambda from zero

Lambda is a function runner.

You write:

```text
function code
handler
runtime
dependencies
environment variables
IAM permissions
timeout
memory
trigger
```

AWS runs it when an event happens.

Example event sources:

```text
API Gateway request
S3 object upload
SQS message
EventBridge scheduled event
DynamoDB stream event
SNS notification
Step Functions task
```

AWS Lambda runs your code on high-availability infrastructure and manages compute resources such as server and OS maintenance, capacity provisioning, automatic scaling, and logging integration. ([AWS Documentation][2])

---

# 4. Lambda function, handler, event, context

## Function

A Lambda function is your deployed code unit.

Example:

```text
createOrderFunction
sendEmailFunction
resizeImageFunction
processPaymentWebhookFunction
```

## Handler

The handler is the entry point.

Python example:

```python
def handler(event, context):
    return {
        "statusCode": 200,
        "body": "hello"
    }
```

Node.js example:

```javascript
exports.handler = async (event) => {
  return {
    statusCode: 200,
    body: "hello"
  };
};
```

## Event

The event is the input.

Example API Gateway event:

```json
{
  "requestContext": {
    "http": {
      "method": "GET"
    }
  },
  "rawPath": "/health"
}
```

Example SQS event:

```json
{
  "Records": [
    {
      "body": "{\"orderId\":\"123\"}"
    }
  ]
}
```

## Context

Context contains runtime metadata.

Example:

```text
function name
request ID
remaining execution time
memory limit
log stream
```

Never confuse:

```text
event:
  input data

context:
  Lambda runtime metadata
```

---

# 5. Lambda runtime

Runtime means language environment.

Examples:

```text
Python
Node.js
Java
Go
.NET
Ruby
custom runtime
container image runtime
```

Runtime decides:

```text
how your handler is called
what language version runs
how dependencies are packaged
how cold start behaves
```

Production rule:

```text
Use a supported runtime.
Keep dependencies small.
Avoid heavy startup logic unless required.
```

---

# 6. Lambda execution role

A Lambda function needs an IAM role.

This role allows Lambda to do things.

Minimum:

```text
write logs to CloudWatch Logs
```

If Lambda needs DynamoDB:

```text
dynamodb:PutItem
dynamodb:GetItem
dynamodb:UpdateItem
```

If Lambda needs S3:

```text
s3:GetObject
s3:PutObject
```

Never hardcode AWS keys inside Lambda.

Correct pattern:

```text
Lambda execution role
  ↓
temporary permissions
  ↓
AWS SDK uses role automatically
```

---

# 7. Lambda timeout and memory

Lambda has important configuration:

```text
timeout:
  max runtime duration

memory:
  RAM allocated to function

CPU:
  increases with memory allocation

ephemeral storage:
  temporary /tmp storage
```

Important:

```text
More memory can also mean more CPU.
Sometimes increasing memory makes Lambda faster and cheaper overall because it finishes sooner.
```

Bad Lambda design:

```text
timeout = 15 minutes
function waits on slow external service
no retries/DLQ
no idempotency
```

Good Lambda design:

```text
small focused function
clear timeout
safe retries
logs and metrics
idempotent processing
DLQ/on-failure destination where needed
```

---

# 8. Cold start and warm start

## Cold start

Cold start happens when Lambda needs to prepare a new execution environment.

It may include:

```text
download code/package
initialize runtime
run global initialization code
start handler
```

## Warm start

Warm start happens when Lambda reuses an existing environment.

Faster because setup already happened.

Production optimization:

```text
keep package small
avoid huge global initialization
reuse SDK/database clients outside handler
use provisioned concurrency for latency-critical functions
choose runtime carefully
```

Never panic about cold starts for every workload. They matter most for:

```text
latency-sensitive APIs
user-facing login/payment flows
large Java/.NET packages
VPC-heavy or dependency-heavy functions
```

---

# 9. API Gateway

API Gateway gives your backend a public API endpoint.

Simple meaning:

```text
API Gateway receives HTTP requests and forwards them to backend integrations such as Lambda, HTTP services, or AWS services.
```

AWS describes API Gateway as a fully managed service for creating, publishing, maintaining, monitoring, and securing APIs at any scale. ([Amazon Web Services, Inc.][3])

Flow:

```text
Browser / mobile app / client
  ↓ HTTPS request
API Gateway
  ↓ integration
Lambda
  ↓
DynamoDB / S3 / other service
```

---

# 10. API Gateway core terms

## API

The API is the public interface.

Example:

```text
orders-api
```

## Route

Route matches request method and path.

Examples:

```text
GET /health
POST /orders
GET /orders/{id}
DELETE /orders/{id}
```

## Integration

Integration is the backend.

Example:

```text
Lambda function
HTTP backend
AWS service
```

## Stage

Stage is deployed environment.

Examples:

```text
dev
staging
prod
$default
```

## Authorizer

Authorizer checks identity.

Examples:

```text
JWT authorizer
Lambda authorizer
IAM authorization
Cognito authorizer
```

API Gateway supports HTTP APIs and REST APIs; HTTP APIs are commonly used for lower-latency, lower-cost Lambda-backed APIs, while REST APIs provide more legacy/advanced API Gateway features. ([AWS Documentation][4])

---

# 11. Lambda invocation types

There are three important patterns.

## Synchronous invocation

Client waits for response.

Example:

```text
API Gateway → Lambda → response to user
```

Good for:

```text
HTTP APIs
request/response apps
validation endpoints
small reads/writes
```

If Lambda fails, user sees error.

---

## Asynchronous invocation

Event is accepted, Lambda runs in background.

Example:

```text
S3 object uploaded
  ↓
Lambda processes image
```

Good for:

```text
background processing
notifications
event handlers
file processing
```

Lambda manages retries for asynchronous invocations, and discarded events can be captured with a dead-letter queue or destination depending on configuration. ([AWS Documentation][5])

---

## Event source mapping

Lambda polls a stream or queue and invokes your function with records.

Examples:

```text
SQS → Lambda
DynamoDB Streams → Lambda
Kinesis → Lambda
```

Good for:

```text
queue workers
stream processing
batch records
reliable asynchronous processing
```

Lambda event source mappings process records from queue/stream services in batches and have retry behavior that depends on the event source and configuration. ([AWS Documentation][6])

---

# 12. DynamoDB in serverless

DynamoDB is a natural serverless database for Lambda.

Why?

```text
no server management
scales automatically with traffic pattern
pay-per-request option
fast key-value/document access
IAM-based access
streams integration
```

Typical serverless API:

```text
API Gateway
  ↓
Lambda
  ↓
DynamoDB table
```

Example:

```text
POST /orders:
  Lambda validates request
  writes item to DynamoDB

GET /orders/{id}:
  Lambda reads item by primary key
  returns JSON
```

DynamoDB is fully managed and serverless NoSQL, designed for high-performance applications at scale. ([Amazon Web Services, Inc.][7])

---

# 13. SQS — queue service

SQS means:

```text
Simple Queue Service
```

Simple meaning:

```text
SQS stores messages until a consumer processes them.
```

Flow:

```text
Producer
  ↓ sends message
SQS queue
  ↓ Lambda/worker polls message
Consumer processes
```

Use SQS when:

```text
you need buffering
you need retry
consumer may be temporarily down
producer and consumer should be decoupled
work should be processed asynchronously
```

Example:

```text
API receives order
  ↓
puts message into SQS
  ↓
worker Lambda processes fulfillment
```

SQS is best thought of as a **work queue**.

---

# 14. SQS visibility timeout

When a consumer receives a message, SQS hides it for a period.

That period is visibility timeout.

```text
Lambda receives message.
SQS hides message.
Lambda processes message.
Lambda deletes message if successful.
If Lambda fails, message becomes visible again after timeout.
```

Design rule:

```text
visibility timeout should be longer than maximum processing time
```

If visibility timeout is too short:

```text
same message may be processed multiple times concurrently
```

So your consumer must be:

```text
idempotent
```

Meaning:

```text
processing the same message twice should not corrupt data
```

---

# 15. DLQ — Dead Letter Queue

DLQ means:

```text
Dead Letter Queue
```

Simple meaning:

```text
A DLQ stores messages/events that failed too many times.
```

Use DLQ for:

```text
debugging failed messages
manual replay
protecting main queue
avoiding infinite retry loops
```

Flow:

```text
SQS main queue
  ↓ retries fail repeatedly
SQS DLQ
  ↓ engineer investigates
```

Production rule:

```text
Every important async pipeline should have a failure path:
DLQ, on-failure destination, alert, or replay mechanism.
```

---

# 16. SNS — pub/sub notification

SNS means:

```text
Simple Notification Service
```

Simple meaning:

```text
SNS publishes one message to many subscribers.
```

AWS describes SNS as a fully managed publisher/subscriber messaging service where publishers send messages to a topic, and subscribers can receive messages through endpoints such as SQS, Lambda, HTTP/S, email, mobile push, and SMS. ([AWS Documentation][8])

Flow:

```text
Publisher
  ↓
SNS topic
  ├── SQS queue
  ├── Lambda function
  ├── Email subscriber
  └── HTTPS endpoint
```

Use SNS when:

```text
one event should notify many systems
fanout is needed
email/SMS/mobile push is needed
simple pub/sub is enough
```

Example:

```text
OrderPlaced event
  ↓
SNS topic
  ├── email notification Lambda
  ├── warehouse SQS queue
  └── analytics SQS queue
```

---

# 17. EventBridge — event router

EventBridge is an event bus.

Simple meaning:

```text
EventBridge receives events and routes them to targets using rules.
```

AWS describes EventBridge as a serverless service that uses events to connect application components and build scalable event-driven applications. ([AWS Documentation][9])

Core terms:

```text
event:
  something happened

event bus:
  place where events are sent

rule:
  pattern that matches events

target:
  service that receives matching events
```

Flow:

```text
Application emits event:
  source = "todo.app"
  detail-type = "TodoCreated"

EventBridge rule:
  if detail-type == TodoCreated

Targets:
  Lambda
  SQS
  Step Functions
```

Use EventBridge when:

```text
you need event routing
many producers/consumers
SaaS/AWS/app integration
event filtering
clean event-driven architecture
scheduled events
```

---

# 18. SNS vs SQS vs EventBridge

This is exam and interview-critical.

| Service        | Simple meaning        | Best for                                  |
| -------------- | --------------------- | ----------------------------------------- |
| SQS            | Queue                 | buffer work for consumers                 |
| SNS            | Pub/sub fanout        | send one message to many subscribers      |
| EventBridge    | Event bus/router      | route/filter events between services/apps |
| Step Functions | Workflow orchestrator | coordinate multi-step process             |

Never confuse:

```text
SQS:
  one or more consumers process queued work

SNS:
  topic broadcasts to subscribers

EventBridge:
  event routing and filtering bus

Step Functions:
  ordered workflow/state machine
```

Example:

```text
Need order processing worker:
  SQS

Need notify email + warehouse + analytics:
  SNS

Need route business events by type/source:
  EventBridge

Need payment → inventory → shipping → email workflow:
  Step Functions
```

---

# 19. Step Functions

Step Functions coordinates multiple steps.

Simple meaning:

```text
Step Functions is serverless workflow orchestration.
```

AWS Step Functions lets you create workflows, also called state machines, to build distributed applications, automate processes, orchestrate microservices, and build data or ML pipelines. A workflow is made of states, and task states can call services such as Lambda or other AWS APIs. ([AWS Documentation][10])

Example order workflow:

```text
Start
  ↓
Validate order
  ↓
Charge payment
  ↓
Reserve inventory
  ↓
Create shipment
  ↓
Send email
  ↓
End
```

Why not just one huge Lambda?

```text
hard to retry one step
hard to see where it failed
hard to pause/wait
hard to manage long workflows
hard to audit state transitions
```

With Step Functions:

```text
each step is visible
retry policies are explicit
errors are catchable
workflow execution history is available
long-running workflows are easier
```

---

# 20. Step Functions state types

Common states:

```text
Task:
  do work, call Lambda/service/API

Choice:
  if/else branching

Wait:
  pause for time

Parallel:
  run branches at same time

Map:
  process list of items

Pass:
  pass/transform data

Succeed:
  successful end

Fail:
  failed end
```

Example:

```text
Choice:
  if paymentStatus == APPROVED
    continue shipping
  else
    fail order
```

---

# 21. Retries and idempotency

Serverless systems retry often.

Retries are good because temporary failures happen.

But retries can cause duplicates.

Example:

```text
Lambda processes payment.
Network timeout happens.
System retries.
Payment may be charged twice if code is not idempotent.
```

Idempotency means:

```text
same request/event repeated multiple times
still produces one correct result
```

Good design:

```text
use unique request ID
store processed event IDs
use conditional writes in DynamoDB
make external calls safely
deduplicate messages where needed
```

Production rule:

```text
In event-driven systems, always assume duplicate delivery can happen.
```

---

# 22. Serverless architecture patterns

## Pattern 1 — Simple API

```text
Client
  ↓
API Gateway
  ↓
Lambda
  ↓
DynamoDB
```

Use for:

```text
CRUD APIs
small backends
mobile/web APIs
internal tools
```

---

## Pattern 2 — Async background work

```text
API Gateway
  ↓
Lambda
  ↓
SQS queue
  ↓
Worker Lambda
```

Use for:

```text
email sending
image processing
report generation
payment follow-up
slow external API calls
```

---

## Pattern 3 — Fanout

```text
Order service
  ↓
SNS topic
  ├── email queue
  ├── warehouse queue
  └── analytics queue
```

Use for:

```text
one event needs many independent consumers
```

---

## Pattern 4 — Event bus

```text
Application events
  ↓
EventBridge
  ├── Lambda target
  ├── SQS target
  └── Step Functions target
```

Use for:

```text
business events
microservice integration
SaaS integrations
loose coupling
```

---

## Pattern 5 — Workflow

```text
API/Event
  ↓
Step Functions
  ├── validate
  ├── payment
  ├── inventory
  ├── shipping
  └── notification
```

Use for:

```text
multi-step processes
human approval
long-running orchestration
clear retry/catch logic
```

---

# 23. Serverless vs containers vs EC2

| Requirement                  | Better option                  |
| ---------------------------- | ------------------------------ |
| Short event-driven task      | Lambda                         |
| HTTP API with simple logic   | API Gateway + Lambda           |
| Long-running web server      | ECS/Fargate or EC2             |
| Full OS control              | EC2                            |
| Kubernetes ecosystem         | EKS                            |
| Background queue worker      | Lambda + SQS or ECS worker     |
| Large ML model always loaded | ECS/EC2/EKS                    |
| Scheduled cleanup job        | EventBridge Scheduler + Lambda |
| Complex workflow             | Step Functions                 |
| Static website               | S3 + CloudFront                |

Simple rule:

```text
Use Lambda when work is event-driven, short-lived, stateless, and can scale per event.

Use containers when the app is long-running, stateful in memory, needs custom runtime/server behavior, or has heavy dependencies.

Use EC2 when you need full server control.
```

---

# 24. Production serverless checklist

Before production:

```text
1. Is Lambda timeout correct?
2. Is memory right-sized?
3. Are permissions least privilege?
4. Are secrets stored outside code?
5. Are logs structured?
6. Are CloudWatch alarms configured?
7. Is retry behavior understood?
8. Is DLQ/on-failure destination configured?
9. Is function idempotent?
10. Is API authenticated?
11. Is throttling/rate limiting configured?
12. Is DynamoDB key design correct?
13. Is tracing enabled where needed?
14. Is deployment automated?
15. Is rollback possible?
16. Is cost monitored?
17. Are reserved/provisioned concurrency settings needed?
18. Are environment variables safe?
19. Are errors observable?
20. Is cleanup plan ready for labs?
```

---

# 25. Hands-On Lab 12A — Serverless Orders API

We will create:

```text
DynamoDB table
Lambda execution role
Lambda function
API Gateway HTTP API
routes through Lambda proxy
CloudWatch logs
```

Architecture:

```text
curl/browser
  ↓
API Gateway HTTP API
  ↓
Lambda Python function
  ↓
DynamoDB Orders table
```

Cost warning:

```text
This is low-cost for tiny testing, but API Gateway, Lambda, DynamoDB, and CloudWatch Logs can generate charges.
Run cleanup after the lab.
```

Region:

```text
ap-south-1
```

---

## Step 1 — Set variables

```bash
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TS="$(date +%Y%m%d%H%M%S)"

TABLE_NAME="aws-masterclass-orders-${TS}"
FUNCTION_NAME="aws-masterclass-orders-api-${TS}"
ROLE_NAME="aws-masterclass-lambda-orders-role-${TS}"
API_NAME="aws-masterclass-orders-http-api-${TS}"

echo "ACCOUNT_ID=$ACCOUNT_ID"
echo "TABLE_NAME=$TABLE_NAME"
echo "FUNCTION_NAME=$FUNCTION_NAME"
echo "ROLE_NAME=$ROLE_NAME"
echo "API_NAME=$API_NAME"
```

---

## Step 2 — Create DynamoDB table

```bash
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=orderId,AttributeType=S \
  --key-schema AttributeName=orderId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=aws-masterclass Key=Environment,Value=dev
```

Wait:

```bash
aws dynamodb wait table-exists \
  --table-name "$TABLE_NAME"
```

Validate:

```bash
aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --query 'Table.{TableName:TableName,Status:TableStatus,BillingMode:BillingModeSummary.BillingMode}'
```

---

## Step 3 — Create Lambda execution role

Create trust policy:

```bash
cat > /tmp/lambda-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create role:

```bash
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/lambda-trust-policy.json
```

Attach basic CloudWatch Logs permission:

```bash
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

Add least-privilege DynamoDB access:

```bash
cat > /tmp/lambda-dynamodb-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "OrdersTableAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name OrdersTableAccess \
  --policy-document file:///tmp/lambda-dynamodb-policy.json
```

Get role ARN:

```bash
ROLE_ARN="$(aws iam get-role \
  --role-name "$ROLE_NAME" \
  --query 'Role.Arn' \
  --output text)"

echo "$ROLE_ARN"
```

Wait for IAM propagation:

```bash
sleep 20
```

---

## Step 4 — Create Lambda code

```bash
mkdir -p /tmp/aws-masterclass-serverless
cd /tmp/aws-masterclass-serverless

cat > app.py <<'EOF'
import json
import os
import uuid
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def make_response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "content-type": "application/json"
        },
        "body": json.dumps(body)
    }


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path = event.get("rawPath", "")

    if method == "GET" and path == "/health":
        return make_response(200, {
            "status": "healthy",
            "service": "orders-api"
        })

    if method == "POST" and path == "/orders":
        try:
            payload = json.loads(event.get("body") or "{}")
        except json.JSONDecodeError:
            return make_response(400, {"message": "Invalid JSON body"})

        customer_id = payload.get("customerId")
        amount = payload.get("amount")

        if not customer_id or amount is None:
            return make_response(400, {
                "message": "customerId and amount are required"
            })

        order_id = str(uuid.uuid4())
        item = {
            "orderId": order_id,
            "customerId": str(customer_id),
            "amount": str(amount),
            "status": "CREATED",
            "createdAt": datetime.now(timezone.utc).isoformat()
        }

        table.put_item(Item=item)

        return make_response(201, {
            "message": "Order created",
            "order": item
        })

    if method == "GET" and path.startswith("/orders/"):
        order_id = path.split("/orders/", 1)[1]

        result = table.get_item(Key={"orderId": order_id})
        item = result.get("Item")

        if not item:
            return make_response(404, {
                "message": "Order not found",
                "orderId": order_id
            })

        return make_response(200, {
            "order": item
        })

    return make_response(404, {
        "message": "Route not found",
        "method": method,
        "path": path
    })
EOF
```

Package:

```bash
zip function.zip app.py
```

---

## Step 5 — Create Lambda function

```bash
aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime python3.12 \
  --handler app.handler \
  --role "$ROLE_ARN" \
  --zip-file fileb://function.zip \
  --timeout 10 \
  --memory-size 256 \
  --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
  --tags Project=aws-masterclass,Environment=dev
```

Wait:

```bash
aws lambda wait function-active \
  --function-name "$FUNCTION_NAME"
```

Get ARN:

```bash
FUNCTION_ARN="$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --query 'Configuration.FunctionArn' \
  --output text)"

echo "$FUNCTION_ARN"
```

---

## Step 6 — Test Lambda directly

```bash
cat > /tmp/health-event.json <<'EOF'
{
  "requestContext": {
    "http": {
      "method": "GET"
    }
  },
  "rawPath": "/health"
}
EOF

aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --payload fileb:///tmp/health-event.json \
  /tmp/lambda-response.json

cat /tmp/lambda-response.json
```

Expected:

```json
{
  "statusCode": 200,
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"status\": \"healthy\", \"service\": \"orders-api\"}"
}
```

---

## Step 7 — Create HTTP API Gateway

Create API:

```bash
API_ID="$(aws apigatewayv2 create-api \
  --name "$API_NAME" \
  --protocol-type HTTP \
  --query 'ApiId' \
  --output text)"

echo "$API_ID"
```

Create Lambda integration:

```bash
INTEGRATION_ID="$(aws apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --integration-type AWS_PROXY \
  --integration-uri "$FUNCTION_ARN" \
  --payload-format-version "2.0" \
  --query 'IntegrationId' \
  --output text)"

echo "$INTEGRATION_ID"
```

Create routes:

```bash
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "GET /health" \
  --target "integrations/$INTEGRATION_ID"

aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "POST /orders" \
  --target "integrations/$INTEGRATION_ID"

aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "GET /orders/{orderId}" \
  --target "integrations/$INTEGRATION_ID"
```

Create default stage with auto-deploy:

```bash
aws apigatewayv2 create-stage \
  --api-id "$API_ID" \
  --stage-name '$default' \
  --auto-deploy
```

Allow API Gateway to invoke Lambda:

```bash
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id apigw-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/*/*"
```

Get endpoint:

```bash
API_ENDPOINT="$(aws apigatewayv2 get-api \
  --api-id "$API_ID" \
  --query 'ApiEndpoint' \
  --output text)"

echo "$API_ENDPOINT"
```

---

## Step 8 — Test API

Health:

```bash
curl "$API_ENDPOINT/health"
```

Create order:

```bash
CREATE_RESPONSE="$(curl -s -X POST "$API_ENDPOINT/orders" \
  -H "content-type: application/json" \
  -d '{"customerId":"cust-101","amount":1500}')"

echo "$CREATE_RESPONSE" | jq .
```

Extract order ID:

```bash
ORDER_ID="$(echo "$CREATE_RESPONSE" | jq -r '.order.orderId')"

echo "$ORDER_ID"
```

Get order:

```bash
curl "$API_ENDPOINT/orders/$ORDER_ID" | jq .
```

Validate DynamoDB item:

```bash
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key "{\"orderId\":{\"S\":\"$ORDER_ID\"}}"
```

Check Lambda logs:

```bash
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/$FUNCTION_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

---

# 26. Cleanup Lab 12A

Delete API Gateway:

```bash
aws apigatewayv2 delete-api \
  --api-id "$API_ID"
```

Delete Lambda:

```bash
aws lambda delete-function \
  --function-name "$FUNCTION_NAME"
```

Delete Lambda log group:

```bash
aws logs delete-log-group \
  --log-group-name "/aws/lambda/$FUNCTION_NAME" || true
```

Delete IAM role policy and role:

```bash
aws iam delete-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name OrdersTableAccess

aws iam detach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam delete-role \
  --role-name "$ROLE_NAME"
```

Delete DynamoDB table:

```bash
aws dynamodb delete-table \
  --table-name "$TABLE_NAME"

aws dynamodb wait table-not-exists \
  --table-name "$TABLE_NAME"
```

Verify:

```bash
aws lambda get-function --function-name "$FUNCTION_NAME" || true
aws apigatewayv2 get-api --api-id "$API_ID" || true
aws dynamodb describe-table --table-name "$TABLE_NAME" || true
```

---

# 27. Common serverless errors and fixes

## Error 1 — Lambda AccessDenied for DynamoDB

Cause:

```text
Lambda execution role does not have DynamoDB permission.
```

Fix:

```text
Check Lambda role.
Check policy action.
Check table ARN.
Check region/account.
```

Debug:

```bash
aws lambda get-function-configuration \
  --function-name "$FUNCTION_NAME" \
  --query 'Role'
```

---

## Error 2 — API Gateway returns 500

Possible causes:

```text
Lambda code crashed
Lambda returned invalid proxy response
Lambda permission missing for API Gateway
bad integration URI
timeout
```

Check logs:

```bash
aws logs tail "/aws/lambda/$FUNCTION_NAME" --follow
```

---

## Error 3 — API Gateway cannot invoke Lambda

Cause:

```text
missing lambda add-permission for apigateway.amazonaws.com
```

Fix:

```bash
aws lambda get-policy \
  --function-name "$FUNCTION_NAME"
```

Then add permission if missing.

---

## Error 4 — Lambda timeout

Cause:

```text
slow downstream service
network issue
bad retry loop
database call stuck
timeout too low
```

Fix:

```text
increase timeout only if justified
optimize code
add better logs
check downstream service
use async queue for slow work
```

---

## Error 5 — Duplicate processing

Cause:

```text
event retried
SQS visibility timeout too short
Lambda failed after partially completing work
consumer not idempotent
```

Fix:

```text
use idempotency key
conditional writes
deduplication table
safe external calls
DLQ after max retries
```

---

# 28. Production serverless architecture for your Todo/App journey

A production-grade serverless version of your app could be:

```text
Route 53
  ↓
CloudFront
  ↓
API Gateway
  ↓
Lambda API handlers
  ↓
DynamoDB
```

Async processing:

```text
Lambda API
  ↓
SQS queue
  ↓
Worker Lambda
  ↓
SNS/EventBridge notification
```

Workflow:

```text
EventBridge event
  ↓
Step Functions
  ├── validate
  ├── write DynamoDB
  ├── send notification
  └── update audit trail
```

Observability:

```text
CloudWatch Logs
CloudWatch Metrics
X-Ray tracing
alarms on errors/throttles/dlq depth
```

Security:

```text
IAM least privilege
API auth
WAF if public API
Secrets Manager
KMS where required
CloudTrail audit
```

---

# 29. Certification angle

## CLF-C02

Know:

```text
Lambda runs code without managing servers.
API Gateway creates and manages APIs.
DynamoDB is serverless NoSQL.
SQS is queue messaging.
SNS is pub/sub messaging.
EventBridge routes events.
Step Functions orchestrates workflows.
```

## SAA-C03

Know deeply:

```text
sync vs async Lambda invocation
API Gateway + Lambda integration
Lambda execution role
Lambda timeout/memory/concurrency
DynamoDB key design
SQS visibility timeout and DLQ
SNS fanout
EventBridge rules/event buses
Step Functions Standard vs Express idea
serverless retry behavior
idempotency
private access and least privilege
```

## DOP-C02

Know operationally:

```text
serverless CI/CD
SAM/CDK/Terraform deployments
Lambda aliases and versions
canary deployments
CloudWatch alarms
X-Ray tracing
DLQ replay
SQS redrive
API Gateway logs
throttling
reserved concurrency
failed event destinations
rollback and incident response
```

---

# 30. Interview answer

Memorize this:

```text
Serverless on AWS means building applications without directly managing servers. AWS Lambda runs code in response to events, API Gateway exposes HTTP APIs, DynamoDB provides serverless NoSQL storage, SQS provides durable queues, SNS provides pub/sub fanout, EventBridge routes events between services, and Step Functions orchestrates multi-step workflows.

For a simple serverless API, I use API Gateway in front of Lambda and DynamoDB behind it. API Gateway handles the public HTTP endpoint, Lambda contains business logic, and DynamoDB stores data. Lambda uses an IAM execution role with least-privilege permissions instead of hardcoded credentials.

For asynchronous processing, I use SQS between producers and consumers so workloads are buffered and retried safely. I configure visibility timeout, DLQs, and alarms. For broadcasting one event to multiple consumers, I use SNS. For event-driven application integration and filtering, I use EventBridge. For multi-step workflows with retries, branching, and execution history, I use Step Functions.

In production serverless systems, I focus on idempotency, retry behavior, DLQs, timeouts, memory tuning, least-privilege IAM, structured logs, metrics, tracing, throttling, API authentication, deployment automation, and cost monitoring.
```

---

# 31. Quick quiz

```text
1. What does serverless mean?
2. What is Lambda?
3. What is a Lambda handler?
4. What is the Lambda event?
5. What is Lambda context?
6. What is API Gateway?
7. What is DynamoDB used for in serverless?
8. What is SQS?
9. What is SNS?
10. What is EventBridge?
11. What is Step Functions?
12. What is synchronous invocation?
13. What is asynchronous invocation?
14. What is event source mapping?
15. What is visibility timeout?
16. What is DLQ?
17. What is idempotency?
18. When should you use SQS?
19. When should you use SNS?
20. When should you use Step Functions?
```

Answers:

```text
1. You do not manage servers directly; AWS manages infrastructure.
2. Event-driven serverless compute service.
3. Entry point function Lambda calls.
4. Input data passed to Lambda.
5. Runtime metadata passed to Lambda.
6. Managed API front door.
7. Serverless NoSQL data store.
8. Queue for buffering work.
9. Pub/sub fanout notification service.
10. Event bus/router.
11. Workflow orchestration service.
12. Caller waits for Lambda response.
13. Event accepted and processed in background.
14. Lambda polls queue/stream and invokes function with records.
15. Time SQS hides a message while being processed.
16. Queue/location for failed messages/events.
17. Repeated processing still produces correct result.
18. When you need decoupled asynchronous work queue.
19. When one message must fan out to many subscribers.
20. When you need multi-step workflow, retries, branching, and state.
```

# Next Lesson

```text
AWS Lesson 13 — Security and IAM in Production:
IAM policies, roles, permission boundaries, SCPs, KMS, Secrets Manager, SSM Parameter Store, WAF, Shield, GuardDuty, Inspector, CloudTrail, Config, and real AccessDenied troubleshooting
```

[1]: https://docs.aws.amazon.com/lambda/latest/dg/welcome.html?linkId=114959379&sc_campaign=Docs&sc_category=AWS_Lambda&sc_channel=sm&sc_content=Docs&sc_country=Global%2CGlobal+%28Public+Sector+Users%29&sc_geo=GLOBAL&sc_outcome=awareness&sc_publisher=LINKEDIN&trk=Docs_LINKEDIN&utm_source=chatgpt.com "What is AWS Lambda? - AWS Lambda"
[2]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-functions-chapter.html?utm_source=chatgpt.com "AWS Lambda Functions - AWS Lambda"
[3]: https://aws.amazon.com/api-gateway/?utm_source=chatgpt.com "Amazon API Gateway | API Management | Amazon Web Services"
[4]: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html?utm_source=chatgpt.com "API Gateway HTTP APIs - Amazon API Gateway"
[5]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-error-handling.html?utm_source=chatgpt.com "How Lambda handles errors and retries with asynchronous invocation - AWS Lambda"
[6]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-invocation.html?utm_source=chatgpt.com "Understanding Lambda function invocation methods - AWS Lambda"
[7]: https://aws.amazon.com/documentation-overview/sqs/?utm_source=chatgpt.com "Amazon Simple Queue Service Documentation"
[8]: https://docs.aws.amazon.com/sns/latest/dg/welcome.html?utm_source=chatgpt.com "What is Amazon SNS? - Amazon Simple Notification Service"
[9]: https://docs.aws.amazon.com/eventbridge/latest/ref/welcome.html?utm_source=chatgpt.com "AWS Events Reference - Amazon EventBridge"
[10]: https://docs.aws.amazon.com/step-functions/latest/dg/welcome.html?utm_source=chatgpt.com "What is Step Functions? - AWS Step Functions"
