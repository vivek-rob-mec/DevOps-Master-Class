# AWS Masterclass — Lesson 33 Part 1

# AWS Lambda from First Principles

## Execution Environments, Cold Starts, Memory/CPU, Concurrency, IAM, VPC Networking, Versions, Aliases & Production Design

We have spent a lot of time learning how to operate servers:

```text
EC2
 │
 ├── OS
 ├── patching
 ├── processes
 ├── scaling
 ├── AMIs
 ├── SSH / SSM
 ├── Auto Scaling
 └── load balancing
```

Lambda changes the operating model:

```text
                    APPLICATION EVENT
                           │
                           ▼
                         Lambda
                           │
                    YOUR FUNCTION
                           │
                           ▼
                        RESULT

AWS manages:
────────────
servers
host OS
capacity
runtime infrastructure
scaling infrastructure
fault-tolerance infrastructure
```

AWS defines Lambda Functions as serverless compute that executes code in response to events or API calls while Lambda manages underlying infrastructure, scaling, routing, and fault tolerance. ([AWS Documentation][1])

But remember:

```text
SERVERLESS
≠
NO SERVERS EXIST

SERVERLESS
=
YOU DON'T MANAGE THE SERVERS
```

That distinction is fundamental.

---

# 1. Traditional EC2 vs Lambda

With EC2:

```text
Request
   │
   ▼
ALB
   │
   ▼
EC2
   │
   ▼
Node.js process
```

You decide:

```text
How many EC2 instances?

What size?

Which AMI?

How to patch?

How to scale?

What if an instance fails?

How many processes?

How to deploy?
```

With Lambda:

```text
Request/Event
      │
      ▼
    Lambda
      │
      ▼
   Handler
```

AWS creates and manages execution capacity as demand changes. ([AWS Documentation][1])

---

# 2. Lambda Is Event Driven

A function normally executes because something happened.

Examples:

```text
API Gateway request
        │
        ▼
      Lambda


S3 object uploaded
        │
        ▼
      Lambda


SQS message
        │
        ▼
      Lambda


EventBridge event
        │
        ▼
      Lambda


DynamoDB stream record
        │
        ▼
      Lambda
```

Lambda integrates with AWS services as event sources or invokers; the exact invocation model depends on the source. ([AWS Documentation][1])

---

# 3. Lambda Function Mental Model

Think:

```text
Lambda Function
│
├── Code
├── Runtime
├── Handler
├── Memory
├── Timeout
├── IAM Execution Role
├── Environment Variables
├── Networking
├── Layers
├── /tmp storage
├── Versions
├── Aliases
└── Concurrency configuration
```

All of those together define the runtime behavior of your function.

---

# 4. Function Handler

The handler is the entry point Lambda calls.

Node.js example:

```javascript
export const handler = async (event, context) => {
  console.log("Received event:", event);

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "Hello from Lambda"
    })
  };
};
```

The mental model:

```text
Lambda receives event
        │
        ▼
find handler
        │
        ▼
handler(event, context)
        │
        ▼
application logic
        │
        ▼
return result
```

---

# 5. `event`

The:

```text
event
```

contains information supplied by whatever invoked the function.

For API Gateway it might contain:

```text
HTTP method
path
headers
query string
body
```

For SQS:

```text
message records
```

For S3:

```text
bucket
object key
event information
```

Therefore:

```text
event schema
depends on event source.
```

---

# 6. `context`

The Lambda context object provides runtime information about the current invocation.

Typical concepts include:

```text
request ID

function information

remaining execution time

memory configuration
```

Application code can use this information for diagnostics or timeout-aware logic.

---

# 7. Execution Environment

Your Lambda handler does **not** execute directly on some abstract API.

Lambda creates a:

# Execution Environment

which is an isolated runtime environment containing the runtime, your function code, layers/extensions, environment variables and resources needed by the invocation. ([AWS Documentation][2])

Think:

```text
                    EXECUTION ENVIRONMENT

                ┌─────────────────────────┐
                │ Runtime                 │
                │                         │
                │ Node.js / Python / Java │
                │                         │
                │ Your code               │
                │                         │
                │ Dependencies            │
                │                         │
                │ Extensions              │
                │                         │
                │ Memory                  │
                │                         │
                │ /tmp                    │
                └─────────────────────────┘
```

---

# 8. Lambda Lifecycle

For standard Lambda functions, the fundamental lifecycle is:

```text
INIT
 │
 ▼
INVOKE
 │
 ▼
freeze/reuse
 │
 ▼
more INVOKES
 │
 ▼
SHUTDOWN
```

AWS describes the execution-environment lifecycle around initialization, invocation and shutdown. ([AWS Documentation][2])

This one diagram explains:

```text
cold starts

warm starts

connection reuse

/tmp caching

static initialization
```

---

# 9. INIT Phase

During initialization, Lambda performs work including:

```text
Extensions initialization
        │
        ▼
Runtime initialization
        │
        ▼
Function static initialization
```

AWS currently describes these as the main initialization tasks before the environment is ready to invoke the handler. ([AWS Documentation][2])

Example:

```javascript
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

const dynamodb = new DynamoDBClient({
  region: process.env.AWS_REGION
});

export const handler = async (event) => {
  // ...
};
```

This:

```javascript
const dynamodb = new DynamoDBClient(...)
```

is outside the handler.

That matters.

---

# 10. Cold Start

Suppose no suitable execution environment exists.

Lambda must:

```text
create environment
      │
      ▼
start runtime
      │
      ▼
load code
      │
      ▼
run initialization
      │
      ▼
invoke handler
```

That first request sees additional initialization latency.

This is a:

# Cold Start

AWS defines a cold start as an invocation that requires Lambda to initialize a new execution environment before running the function. ([AWS Documentation][3])

---

# 11. Warm Invocation

After an invocation completes, Lambda can reuse the execution environment.

Then:

```text
Environment already exists
        │
        ▼
runtime already loaded
        │
        ▼
dependencies initialized
        │
        ▼
invoke handler
```

The next invocation may avoid much of the initialization cost.

AWS recommends taking advantage of execution-environment reuse by initializing reusable clients and connections outside the handler where appropriate. ([AWS Documentation][4])

---

# 12. Very Important: Never Assume Warm Reuse

This is wrong:

```javascript
let counter = 0;

export const handler = async () => {
  counter++;

  // assume this is globally reliable state
};
```

Execution environments can disappear and Lambda can create many environments simultaneously.

Therefore:

```text
execution-environment memory
=
possible cache

NOT
=
durable database
```

AWS describes standard Lambda functions as short-lived compute that should not rely on state persisting between invocations. ([AWS Documentation][5])

For durable state use something like:

```text
DynamoDB

RDS

S3

ElastiCache

EFS
```

depending on the requirement.

---

# 13. Correct Use of Environment Reuse

Good things to reuse:

```text
AWS SDK clients

database connection pools

HTTP clients

parsed configuration

static lookup data

temporary cache
```

when safe.

Example:

```javascript
import { SecretsManagerClient } from "@aws-sdk/client-secrets-manager";

const secrets = new SecretsManagerClient({});

export const handler = async (event) => {
  // reuse client
};
```

AWS explicitly recommends initializing SDK clients and database connections outside the handler so subsequent invocations in the same environment can reuse them. ([AWS Documentation][4])

---

# 14. Cold Start Optimization Rule

Do not place unnecessary heavy initialization before your handler.

Bad:

```javascript
import giganticLibrary from "gigantic-library";

const allData = load5GBOfStuff();
const connection = connectToSomething();

export const handler = async () => {
  // tiny operation
};
```

Every new environment may need to pay those initialization costs.

Think:

```text
COLD START
≈
runtime initialization
+
dependency loading
+
your initialization
```

---

# 15. `/tmp` Storage

Every standard execution environment gets local temporary storage at:

```text
/tmp
```

The current configurable range is:

```text
512 MB
to
10,240 MB
```

in 1-MB increments. `/tmp` data is unique to an execution environment and may remain when that environment is reused; AWS encrypts `/tmp` at rest with an AWS-managed key. ([AWS Documentation][2])

---

# 16. `/tmp` Can Be a Cache

Example:

```text
Invocation 1

download ML model
      │
      ▼
/tmp/model.bin


Invocation 2
same execution environment
      │
      ▼
model already in /tmp
      │
      ▼
reuse
```

AWS specifically notes that `/tmp` contents may survive freeze/reuse and can serve as a transient cache. ([AWS Documentation][2])

But:

```text
/tmp
≠
durable storage.
```

Never rely on it for permanent business data.

---

# 17. Lambda Memory

Lambda's standard function memory can currently be configured from:

```text
128 MB
to
10,240 MB
```

in 1-MB increments. ([AWS Documentation][6])

But this setting does much more than control RAM.

---

# 18. Memory Controls CPU Too

AWS allocates CPU power proportionally to configured memory.

At:

```text
1,769 MB
```

the function receives approximately the equivalent of:

```text
1 vCPU
```

of compute. ([AWS Documentation][6])

So:

```text
increase memory
       │
       ├── more RAM
       └── more CPU
```

This is one of the most important Lambda optimization concepts.

---

# 19. Why 128 MB Can Be Slower

Suppose your function is CPU-intensive.

At:

```text
128 MB
```

it may take:

```text
6 seconds
```

At:

```text
2048 MB
```

it might take:

```text
800 ms
```

because additional memory also increases CPU resources. AWS explicitly notes that increasing memory can dramatically improve performance for CPU-, network-, or memory-bound functions. ([AWS Documentation][6])

That means:

```text
MORE MEMORY
can sometimes
LOWER TOTAL COST
```

if execution becomes sufficiently faster.

---

# 20. Do Not Optimize Lambda by Memory Price Alone

Bad thought:

```text
128 MB is cheapest.
Use it everywhere.
```

Better:

```text
Test:

128
256
512
1024
1769
2048
4096
...
```

and compare:

```text
latency
cost
CPU utilization
memory usage
cold-start impact
```

Optimize:

```text
COST PER SUCCESSFUL REQUEST
```

not merely:

```text
COST PER GB-SECOND.
```

---

# 21. Timeout

Lambda's standard function timeout can currently be configured from:

```text
1 second
```

up to:

```text
900 seconds
=
15 minutes
```

and the console default is 3 seconds. ([AWS Documentation][7])

---

# 22. Timeout Is a Safety Boundary

Suppose code does:

```text
call external API
      │
      ▼
API never responds
      │
      ▼
function waits forever?
```

No.

Lambda eventually terminates the invocation when its configured timeout is reached. ([AWS Documentation][7])

Use timeout intentionally.

---

# 23. Do Not Set Every Function to 15 Minutes

If an API request should normally finish in:

```text
200 ms
```

a timeout of:

```text
900 seconds
```

can hide serious defects.

Better:

```text
Expected:
200 ms

Reasonable max:
2–5 sec
```

depending on the operation and downstream dependencies.

Timeout should answer:

> At what point is this invocation no longer useful?

---

# 24. Lambda Concurrency

Now we reach one of the most important topics in serverless.

Suppose one invocation takes:

```text
2 seconds
```

and at the same time:

```text
100 requests
```

arrive.

Lambda may need approximately:

```text
100 concurrent executions
```

to process them simultaneously.

Concurrency means:

```text
NUMBER OF INVOCATIONS
RUNNING AT THE SAME TIME.
```

---

# 25. Concurrency Formula

A useful estimation formula is:

```text
Concurrency
≈
Requests per second
×
Average duration in seconds
```

AWS uses this same formula when estimating required Lambda concurrency. ([AWS Documentation][8])

Example:

```text
100 requests/sec
×
0.5 sec

=
50 concurrency
```

---

# 26. Duration Has a Huge Effect on Concurrency

Suppose:

```text
1000 requests/sec
```

### Function duration = 100 ms

```text
1000 × 0.1
=
100 concurrency
```

### Function duration = 2 sec

```text
1000 × 2
=
2000 concurrency
```

Same traffic.

Very different capacity requirement.

This is why:

```text
LATENCY OPTIMIZATION
also
REDUCES CONCURRENCY PRESSURE.
```

---

# 27. Regional Account Concurrency

The standard documented default regional concurrent-execution quota is:

```text
1,000
```

and it can be increased; AWS also notes that new accounts can initially receive reduced Lambda concurrency/memory quota profiles that grow with usage. ([AWS Documentation][5])

Always check:

```text
Service Quotas
```

for the actual account rather than assuming exactly 1,000.

---

# 28. Concurrency Is Shared

Imagine account concurrency:

```text
1000
```

Functions:

```text
checkout
payment
thumbnail
report
email
```

Without reservations they can compete for the regional unreserved pool.

Example:

```text
report function
unexpectedly consumes
900 concurrency

         │
         ▼

checkout
payment
email

must compete
for what remains
```

This creates the:

# Noisy Neighbor Problem

inside your own Lambda account.

---

# 29. Reserved Concurrency

Reserved concurrency says:

```text
This function gets
a dedicated concurrency allocation

AND

cannot scale above that allocation.
```

AWS describes reserved concurrency as both reserving capacity for that function and placing a maximum on its concurrency. It has no additional reserved-concurrency charge. ([AWS Documentation][3])

Example:

```text
Account:
1000

checkout:
reserved = 300
```

Now:

```text
checkout can use
up to 300

and those 300 are not
available to other functions.
```

---

# 30. Reserved Concurrency Is Also a Circuit Breaker

Suppose a buggy Lambda calls:

```text
expensive downstream database
```

with extreme concurrency.

Set:

```text
reserved concurrency = 20
```

Now at most approximately:

```text
20 simultaneous function executions
```

can hit the dependency.

This can protect:

```text
RDS

legacy API

third-party payment API

limited connection pool
```

from serverless-scale overload.

---

# 31. Reserved Concurrency = 0

An important operational trick:

```text
ReservedConcurrency = 0
```

intentionally throttles the function and prevents normal processing until the reservation is changed. AWS documents this as a way to deliberately stop function processing. ([AWS Documentation][9])

This can be useful during:

```text
incident containment

runaway event loop

unexpected cost event

bad deployment
```

---

# 32. Reserved Concurrency Does NOT Eliminate Cold Starts

This is an exam trap.

Reserved concurrency says:

```text
capacity allocation / maximum
```

but environments are still created on demand.

Therefore:

```text
Reserved concurrency
≠
pre-warmed environments.
```

AWS explicitly distinguishes reserved concurrency from provisioned concurrency: reserved concurrency does not pre-initialize environments. ([AWS Documentation][3])

---

# 33. Provisioned Concurrency

Provisioned concurrency says:

```text
Create and initialize
N execution environments
BEFORE requests arrive.
```

Architecture:

```text
Provisioned = 100

Lambda prepares:

Env 1
Env 2
Env 3
...
Env 100
```

They are ready for invocation, reducing cold-start latency for traffic that fits inside the provisioned allocation. ([AWS Documentation][3])

---

# 34. Reserved vs Provisioned

| Feature                        | Reserved                          | Provisioned                |
| ------------------------------ | --------------------------------- | -------------------------- |
| Protect concurrency allocation | Yes                               | Uses allocated concurrency |
| Maximum concurrency            | Yes                               | Not necessarily            |
| Pre-initialized                | No                                | **Yes**                    |
| Cold-start reduction           | No                                | **Yes**                    |
| Additional charge              | No reserved-capacity fee          | **Yes**                    |
| Main use                       | isolation / throttle / protection | predictable low latency    |

AWS distinguishes the two in exactly this way operationally. ([AWS Documentation][3])

---

# 35. Use Both Together

Example:

```text
Checkout Lambda

Reserved:
500

Provisioned:
200
```

Interpretation:

```text
First ~200 concurrent requests
        │
        ▼
pre-initialized capacity

Requests 201–500
        │
        ▼
Lambda may create
on-demand environments

Above 500
        │
        ▼
throttle
```

AWS supports combining reserved and provisioned concurrency; provisioned concurrency cannot exceed the function's reserved concurrency when both are configured. ([AWS Documentation][3])

---

# 36. Concurrency Scaling Rate

For standard on-demand Lambda scaling, AWS currently documents a per-function scaling rate of:

```text
1,000 additional execution environments
every 10 seconds
```

per Region/function. ([AWS Documentation][10])

Meaning a sudden enormous jump:

```text
0
→
50,000 concurrent requests instantly
```

does not imply infinite capacity materializes at exactly the same instant.

Serverless is highly elastic.

It is not:

```text
unbounded instantaneous compute.
```

---

# 37. Lambda Can Overwhelm the Database

Imagine:

```text
API Gateway
   │
   ▼
Lambda
auto-scales rapidly
   │
   ▼
RDS
```

Lambda might scale far faster than:

```text
RDS connection limits
```

can tolerate.

Example:

```text
1000 Lambda environments

each opens:
10 DB connections

=
10,000 DB connections
```

Now serverless scaling caused your database outage.

Production design requires:

```text
reserved concurrency

connection reuse

RDS Proxy where appropriate

correct connection pools

backpressure
```

not merely “Lambda auto-scales.”

---

# 38. Cold-Start Reduction Strategy

A practical order:

```text
1. Measure whether cold starts matter.

2. Reduce dependency/package size.

3. Move reusable initialization outside handler.

4. Allocate sufficient memory/CPU.

5. Avoid unnecessary initialization.

6. Use provisioned concurrency
   when predictable low latency matters.

7. Consider runtime-specific startup features
   where applicable.
```

AWS recommends environment reuse and provisioned concurrency as key performance mechanisms. ([AWS Documentation][4])

---

# 39. Runtimes — Current 2026 State

As of August 2026, Lambda's supported managed runtimes include current options such as:

```text
Node.js 24
Node.js 22

Python 3.14
Python 3.13
Python 3.12

Java 25
Java 21
Java 17 AL2023

.NET 10
.NET 8

Ruby 4.0
Ruby 3.4
...
```

and OS-only `provided.al2023` is available for custom/AOT runtimes. AWS recommends moving toward Amazon Linux 2023-based runtimes because Amazon Linux 2 reached end of life on June 30, 2026. ([AWS Documentation][11])

For a new Node.js Lambda today, I would generally begin with:

```text
nodejs24.x
```

unless dependency compatibility requires another supported runtime.

---

# 40. x86_64 vs arm64

All currently supported managed Lambda runtimes support:

```text
x86_64

arm64
```

architectures. ([AWS Documentation][11])

Arm64 uses AWS Graviton-based execution.

Your dependencies must support whichever architecture you choose.

This especially matters for:

```text
native npm packages

compiled Python wheels

binary layers

custom runtimes
```

---

# 41. Deployment Formats

Lambda supports two major function deployment-package models:

```text
.zip archive

or

container image
```

for standard Lambda functions. ([AWS Documentation][12])

---

# 42. ZIP Package

Current standard limits include:

```text
50 MB compressed
when uploaded directly through API/SDK/console path

250 MB
maximum uncompressed contents
including layers/custom runtimes
```

with S3 used for larger zip uploads within the uncompressed constraint. ([AWS Documentation][5])

This is a strong fit for ordinary:

```text
Node.js
Python
Java
small functions
```

---

# 43. Container Image

Lambda container images currently support:

```text
up to 10 GB
uncompressed
including layers
```

and are stored in Amazon ECR. ([AWS Documentation][5])

Useful when:

```text
large native dependencies

custom Linux packages

ML libraries

existing container build pipeline

custom runtime needs
```

---

# 44. Lambda Container ≠ ECS Container

Very important.

Running:

```text
Docker image
```

in Lambda does **not** mean Lambda becomes ECS.

Lambda still controls:

```text
execution lifecycle

scaling

invocation model

timeout

runtime contract
```

The image simply becomes the deployment packaging format.

---

# 45. Lambda Image Tags Are Resolved to Digests

Suppose Lambda was deployed from:

```text
todo-lambda:latest
```

and later you push a new image using the same tag.

Lambda does **not** automatically switch the function to that newly pushed image; Lambda resolves the deployed tag to a specific image digest, so you must update the Lambda function code/configuration to deploy the new image. ([AWS Documentation][13])

This is excellent immutable-deployment behavior.

---

# Part B — IAM Security

# 46. Lambda Execution Role

A Lambda function needs an:

# Execution Role

when it must access AWS resources.

Trust relationship:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "lambda.amazonaws.com"
  },
  "Action": "sts:AssumeRole"
}
```

The Lambda service assumes this role and exposes temporary AWS credentials to the function execution environment. AWS recommends least-privilege permissions for this role. ([AWS Documentation][14])

---

# 47. Example Execution Role

Suppose Lambda only reads:

```text
prod/todo/*
```

from DynamoDB.

Do not use:

```text
AdministratorAccess
```

or:

```text
AmazonDynamoDBFullAccess
```

when a narrower policy works.

Example conceptual policy:

```json
{
  "Effect": "Allow",
  "Action": [
    "dynamodb:GetItem",
    "dynamodb:Query"
  ],
  "Resource": "arn:aws:dynamodb:ap-south-1:111122223333:table/Todo"
}
```

AWS explicitly recommends reducing Lambda execution roles to least privilege before production deployment. ([AWS Documentation][14])

---

# 48. CloudWatch Logging Permission

The basic console-created execution role commonly receives:

```text
AWSLambdaBasicExecutionRole
```

which allows Lambda to create/write CloudWatch Logs. ([AWS Documentation][14])

Conceptually:

```text
Lambda
  │
  ▼
Execution Role
  │
  ├── logs permissions
  ├── DynamoDB
  ├── S3
  └── Secrets Manager
```

depending on what the function needs.

---

# 49. Environment Variables

Use environment variables for ordinary operational configuration such as:

```text
TABLE_NAME=Todo

ENVIRONMENT=production

LOG_LEVEL=info
```

Current Lambda quotas allow an aggregate of:

```text
4 KB
```

of environment-variable values/configuration per function. ([AWS Documentation][5])

---

# 50. Don't Store Production Passwords There by Default

AWS explicitly recommends using:

```text
Secrets Manager
```

instead of Lambda environment variables for:

```text
database credentials

API keys

authorization tokens
```

when handling sensitive secrets. ([AWS Documentation][15])

This connects directly to Lesson 31.

Architecture:

```text
Lambda
  │
  ▼
Execution Role
  │
  ▼
Secrets Manager
  │
  ▼
cached secret
```

---

# Part C — Invocation Models

# 51. Synchronous Invocation

Synchronous means:

```text
Caller
  │
  ▼
Lambda
  │
  ▼
handler runs
  │
  ▼
Caller waits
  │
  ▼
response returned
```

AWS Lambda waits for function completion and returns the response to the caller. ([AWS Documentation][16])

Examples often include:

```text
API Gateway
direct SDK invocation
application waiting for result
```

---

# 52. Direct CLI Invocation

Example:

```bash
aws lambda invoke \
  --function-name todo-function \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"list"}' \
  response.json
```

Then:

```bash
cat response.json
```

AWS documents `aws lambda invoke` as the CLI path for synchronous direct invocation. ([AWS Documentation][16])

---

# 53. Important Error Trap

For a synchronous invocation, Lambda's API can return:

```text
HTTP 200
```

because Lambda successfully executed the invocation request even if your **function code itself returned an error**.

You must inspect function error information/payload rather than assuming:

```text
HTTP 200 from Lambda API
=
business logic success.
```

AWS explicitly documents this distinction. ([AWS Documentation][16])

---

# 54. Asynchronous Invocation

Asynchronous invocation:

```text
Producer
  │
  ▼
Lambda async queue
  │
  ▼
Producer gets accepted response
  │
  ▼
Lambda processes event later
```

This separates:

```text
event submission
```

from:

```text
function execution.
```

For function errors, Lambda's default asynchronous behavior retries twice after the original attempt, with delays; throttling/system errors can be retried for up to six hours by default. ([AWS Documentation][17])

We'll go deeply into:

```text
retry policy

maximum event age

destinations

DLQs

duplicate delivery
```

in Part 2.

---

# 55. Idempotency Is Mandatory Thinking

AWS warns that asynchronous processing and queue/event-source processing can result in duplicate event delivery. ([AWS Documentation][17])

Suppose event:

```json
{
  "orderId": "123",
  "amount": 5000
}
```

is delivered twice.

Bad Lambda:

```text
charge customer
charge customer again
```

Correct architecture:

```text
event ID / order ID
      │
      ▼
have we processed?
  │            │
 YES           NO
  │             │
  ▼             ▼
return       process
             record result
```

This is:

# Idempotency

One of the most important serverless design principles.

---

# Part D — VPC Lambda

# 56. Lambda Does NOT Need Your VPC for Everything

By default, Lambda can communicate with public AWS service endpoints and the internet through the Lambda-managed network environment.

You attach it to your VPC when it needs private VPC resources such as:

```text
private RDS

ElastiCache

private internal ALB

private EC2 service

private IP endpoint
```

---

# 57. VPC Architecture

```text
                  Lambda Service
                       │
                       ▼
                 Lambda Function
                       │
                       ▼
                Hyperplane ENI
                       │
                       ▼
                     VPC
                  ┌────┴────┐
                  ▼         ▼
                 RDS    ElastiCache
```

Lambda uses managed Hyperplane ENIs to connect VPC-attached functions to resources in the selected VPC subnets/security groups. ([AWS Documentation][18])

---

# 58. Hyperplane ENI

Modern Lambda VPC networking does not create a unique ENI for every invocation.

Lambda creates/reuses managed:

```text
Hyperplane ENIs
```

associated with subnet/security-group combinations; multiple functions using the same combination can share those network resources. Each current Hyperplane ENI supports up to 65,000 connections/ports. ([AWS Documentation][18])

---

# 59. Public Subnet Myth

This is a major certification trap.

You put a Lambda function in:

```text
public subnet
```

Does Lambda automatically get internet access?

```text
NO.
```

AWS explicitly states that connecting a Lambda function to a public subnet does **not** give the function a public IP or internet access. ([AWS Documentation][18])

---

# 60. VPC Lambda Internet Access

Typical architecture:

```text
Lambda
   │
   ▼
Private Subnet
   │
   ▼
Route Table
   │
   ▼
NAT Gateway
   │
   ▼
Internet Gateway
   │
   ▼
Internet
```

if the VPC-attached function needs outbound IPv4 internet access.

Alternatively use:

```text
VPC endpoints
```

for supported AWS services and avoid NAT for those service calls.

---

# 61. Security Groups Apply

If Lambda needs RDS:

```text
Lambda SG
   │
   │ TCP 5432
   ▼
RDS SG
```

RDS rule:

```text
Source:
LambdaSecurityGroup

Port:
5432
```

not:

```text
0.0.0.0/0 :5432
```

The Lambda-selected VPC security groups participate in the VPC networking path. ([AWS Documentation][18])

---

# 62. VPC NACL Trap

For VPC-connected Lambda, network ACLs must not accidentally block ephemeral traffic.

AWS documents that Hyperplane ENIs use ephemeral ports:

```text
1024–65535
```

for VPC networking; restrictive NACL designs can therefore cause intermittent failures. ([AWS Documentation][19])

Security groups are stateful.

NACLs are not.

Remember this from the VPC lesson.

---

# Part E — Versions & Aliases

# 63. `$LATEST`

Your editable Lambda function is:

```text
$LATEST
```

Conceptually:

```text
Developer changes code
       │
       ▼
    $LATEST
```

This is where development changes occur before you publish an immutable version.

---

# 64. Published Version

When you publish:

```text
Version 1
```

Lambda locks the code and most configuration settings for that version so it provides a consistent immutable target. ([AWS Documentation][20])

Then:

```text
$LATEST
   │
   ├── edit
   ├── edit
   ▼
Publish
   │
   ▼
Version 1
```

Later:

```text
$LATEST
   │
   ▼
Publish
   │
   ▼
Version 2
```

---

# 65. Why Versions Matter

Bad deployment:

```text
Production invokes $LATEST
```

while developers continuously modify it.

Better:

```text
Production
    │
    ▼
Alias: prod
    │
    ▼
Version 42
```

Now production is pinned to an immutable function version.

---

# 66. Alias

An alias is a stable logical name pointing to a version.

Example:

```text
dev
   └── Version 51


staging
   └── Version 50


prod
   └── Version 47
```

Clients can invoke:

```text
prod
```

instead of caring about the numeric version. AWS aliases are designed as stable pointers to function versions. ([AWS Documentation][21])

---

# 67. Weighted Alias

Lambda aliases can split traffic between two versions.

Example:

```text
prod alias
   │
   ├── 97% → Version 41
   │
   └──  3% → Version 42
```

AWS supports weighted alias routing specifically for canary deployment patterns. ([AWS Documentation][22])

---

# 68. Canary Deployment

Deployment:

```text
Version 41
known good

Version 42
new
```

Start:

```text
99%
v41

1%
v42
```

Monitor:

```text
Errors

Duration

p95

business failures
```

Then:

```text
90/10

50/50

0/100
```

or rollback:

```text
100% → v41
```

This is much safer than replacing all production traffic instantly.

---

# 69. Provisioned Concurrency + Aliases

Provisioned concurrency is configured against:

```text
published version

or
alias
```

not `$LATEST`. ([AWS Documentation][8])

This is another reason production architectures should use:

```text
versions
+
aliases
```

instead of invoking `$LATEST`.

---

# Part F — Production Monitoring

# 70. Core Lambda Metrics

When troubleshooting Lambda, start with metrics such as:

```text
Invocations

Errors

Duration

Throttles

ConcurrentExecutions
```

and, when applicable:

```text
ProvisionedConcurrencyUtilization

ProvisionedConcurrencySpilloverInvocations
```

AWS exposes concurrency and provisioned-concurrency metrics through CloudWatch for this purpose. ([AWS Documentation][23])

---

# 71. Throttle Troubleshooting

Suppose:

```text
Invocations ↑

ConcurrentExecutions reaches limit

Throttles ↑
```

Check:

```text
function reserved concurrency?

regional account concurrency?

other functions consuming pool?

provisioned allocation?

event-source maximum concurrency?

function duration too high?
```

Do not immediately request a quota increase.

Sometimes the actual root cause is:

```text
function became 10× slower
```

which caused concurrency to increase 10×.

---

# 72. Duration Is One of Your Most Important Metrics

Example:

```text
Traffic:
100 requests/sec


Yesterday:
100 ms
→ ~10 concurrency


Today:
4 sec
→ ~400 concurrency
```

Nothing changed in request rate.

Your function became slow.

Then:

```text
concurrency rises

throttling may follow
```

Therefore monitor:

```text
Duration
+
Concurrency
+
Throttles
```

together.

---

# Part G — Node.js Hands-On Lab

Let's build a simple Lambda for the Todo application mental model.

## `index.mjs`

```javascript
export const handler = async (event, context) => {
  console.log(
    JSON.stringify({
      level: "INFO",
      requestId: context.awsRequestId,
      event
    })
  );

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "Todo Lambda is working",
      requestId: context.awsRequestId
    })
  };
};
```

---

# 73. Create IAM Role

Create trust policy:

```json
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
```

Create:

```bash
aws iam create-role \
  --role-name todo-lambda-role \
  --assume-role-policy-document file://lambda-trust.json
```

Attach logging permissions:

```bash
aws iam attach-role-policy \
  --role-name todo-lambda-role \
  --policy-arn \
  arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

That managed policy provides the basic CloudWatch Logs permissions commonly used for Lambda execution roles. ([AWS Documentation][14])

---

# 74. Package Code

```bash
zip function.zip index.mjs
```

Then:

```bash
aws iam get-role \
  --role-name todo-lambda-role \
  --query 'Role.Arn' \
  --output text
```

Save the role ARN.

---

# 75. Create Lambda

Current Node.js runtime example:

```bash
aws lambda create-function \
  --function-name todo-api-function \
  --runtime nodejs24.x \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --role arn:aws:iam::<ACCOUNT_ID>:role/todo-lambda-role \
  --memory-size 512 \
  --timeout 5 \
  --region ap-south-1
```

`nodejs24.x` is a currently supported Amazon Linux 2023-based runtime as of August 2026. ([AWS Documentation][11])

---

# 76. Invoke

```bash
aws lambda invoke \
  --function-name todo-api-function \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"test"}' \
  response.json \
  --region ap-south-1
```

Then:

```bash
cat response.json
```

---

# 77. Inspect Configuration

```bash
aws lambda get-function-configuration \
  --function-name todo-api-function \
  --region ap-south-1
```

Inspect:

```text
Runtime

Role

Handler

MemorySize

Timeout

LastModified

State

Architectures

EphemeralStorage
```

---

# 78. Increase Memory

```bash
aws lambda update-function-configuration \
  --function-name todo-api-function \
  --memory-size 1024 \
  --region ap-south-1
```

Then run load/performance tests again.

Do not guess whether:

```text
512 MB
```

or:

```text
1024 MB
```

is better.

Measure:

```text
Duration

cost

p95

cold start
```

---

# 79. Configure Reserved Concurrency

```bash
aws lambda put-function-concurrency \
  --function-name todo-api-function \
  --reserved-concurrent-executions 20 \
  --region ap-south-1
```

Now you've placed a maximum concurrency boundary around the function. Reserved concurrency is both a guarantee for the function and a limit on how far that function may scale. ([AWS Documentation][3])

---

# 80. Emergency Stop

During an incident:

```bash
aws lambda put-function-concurrency \
  --function-name todo-api-function \
  --reserved-concurrent-executions 0 \
  --region ap-south-1
```

Function processing will be intentionally throttled. ([AWS Documentation][9])

Restore later with the correct concurrency value or remove the reservation.

---

# 81. Publish Version

```bash
aws lambda publish-version \
  --function-name todo-api-function \
  --description "Production candidate" \
  --region ap-south-1
```

Suppose response gives:

```text
Version 1
```

That version is now immutable for code and most configuration. ([AWS Documentation][20])

---

# 82. Create Production Alias

```bash
aws lambda create-alias \
  --function-name todo-api-function \
  --name prod \
  --function-version 1 \
  --description "Production alias" \
  --region ap-south-1
```

Then consumers can target:

```text
todo-api-function:prod
```

instead of:

```text
todo-api-function:$LATEST
```

---

# Part H — Terraform

# 83. IAM Role

```hcl
resource "aws_iam_role" "lambda" {
  name = "todo-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "lambda.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
```

---

# 84. Logging Policy

```hcl
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = aws_iam_role.lambda.name

  policy_arn =
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

Then add narrowly scoped policies for actual application dependencies rather than broad administrator permissions. AWS recommends least privilege for Lambda execution roles. ([AWS Documentation][14])

---

# 85. Lambda Resource

```hcl
resource "aws_lambda_function" "todo" {
  function_name = "todo-api"

  role = aws_iam_role.lambda.arn

  runtime = "nodejs24.x"
  handler = "index.handler"

  filename         = "function.zip"
  source_code_hash = filebase64sha256("function.zip")

  memory_size = 1024
  timeout     = 5

  architectures = [
    "arm64"
  ]

  environment {
    variables = {
      ENVIRONMENT = "production"
      LOG_LEVEL   = "info"
    }
  }
}
```

Do not put DB passwords or API keys directly into that `environment.variables` block; use Secrets Manager/Parameter Store patterns instead. AWS recommends Secrets Manager for database credentials, API keys and authorization tokens used by Lambda. ([AWS Documentation][15])

---

# 86. Reserved Concurrency Terraform

```hcl
resource "aws_lambda_function" "todo" {
  # ...

  reserved_concurrent_executions = 50
}
```

This is especially useful if:

```text
Lambda
      │
      ▼
RDS
```

and you want a hard ceiling on concurrent application pressure.

---

# 87. VPC Lambda Terraform

```hcl
resource "aws_lambda_function" "api" {
  # ...

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_group_ids = [
      aws_security_group.lambda.id
    ]
  }
}
```

Remember:

```text
subnets
+
security groups
```

determine the VPC connectivity Lambda establishes through managed Hyperplane networking. ([AWS Documentation][18])

---

# Part I — Common Production Failures

# 88. `Task timed out`

Example:

```text
Task timed out after 3.00 seconds
```

Do **not** immediately change:

```text
3 seconds → 900 seconds
```

Investigate:

```text
Which dependency?

DNS?

Network?

database?

external API?

cold start?

CPU starvation?

connection pool?
```

Timeout is often a symptom.

---

# 89. `Rate Exceeded` / Throttling

Possible reasons:

```text
reserved concurrency reached

regional concurrency exhausted

provisioned concurrency exhausted + other ceiling

event-source limit

downstream architecture
```

Check:

```text
ConcurrentExecutions

Throttles

ClaimedAccountConcurrency

ProvisionedConcurrencySpilloverInvocations
```

where applicable. AWS provides those concurrency metrics specifically for diagnosing allocation and spillover. ([AWS Documentation][23])

---

# 90. Lambda in Public Subnet Has No Internet

You already know the answer:

```text
PUBLIC SUBNET
DOES NOT GIVE
LAMBDA A PUBLIC IP.
```

For IPv4 internet access from a VPC-attached Lambda, typically use:

```text
private subnet
→ NAT Gateway
```

or relevant AWS service VPC endpoints when the destination is supported. ([AWS Documentation][18])

---

# 91. Function Suddenly Opens Thousands of DB Connections

Check:

```text
Did concurrency increase?

Did duration increase?

Connection pool size?

Connections initialized
inside every request?

Reserved concurrency?

Database connection limit?
```

Your architecture needs:

```text
Lambda concurrency
≤
safe downstream capacity
```

not simply:

```text
Lambda concurrency
=
as high as AWS permits.
```

---

# 92. Function Is Slow Only on First Request

Likely investigate:

```text
cold start

dependency loading

static initialization

VPC initialization/config changes

large package

runtime initialization
```

Use tracing and Lambda logs/metrics to separate:

```text
initialization
```

from:

```text
handler duration.
```

AWS's execution lifecycle and tracing data distinguish initialization from invocation work. ([AWS Documentation][2])

---

# 93. New Image Pushed but Lambda Still Runs Old Code

If using a Lambda container image:

```text
ECR tag:
latest
```

was updated.

But Lambda still references the digest resolved at deployment time.

Run an explicit:

```text
update-function-code
```

deployment to point Lambda at the new image. ([AWS Documentation][13])

---

# Part J — Certification / Interview Traps

# 94. Scenario

> Function requires more CPU but isn't running out of RAM.

What do you change?

```text
Increase Lambda memory.
```

Why?

Because CPU allocation scales proportionally with Lambda memory. ([AWS Documentation][6])

---

# 95. Scenario

> Critical API must avoid most cold-start latency.

Think:

```text
Provisioned Concurrency
```

not:

```text
Reserved Concurrency.
```

Provisioned concurrency pre-initializes environments; reserved concurrency doesn't. ([AWS Documentation][3])

---

# 96. Scenario

> Payment function must always have up to 100 concurrent capacity even when another Lambda floods the account.

Think:

```text
Reserved Concurrency
```

to isolate part of the account concurrency pool. ([AWS Documentation][3])

---

# 97. Scenario

> Lambda must never use more than 20 concurrent DB connections/executions.

Think:

```text
Reserved Concurrency = 20
```

assuming your function-to-connection model matches that concurrency model.

Reserved concurrency is a hard function concurrency ceiling. ([AWS Documentation][3])

---

# 98. Scenario

> Lambda needs to connect to private RDS.

Think:

```text
Lambda VPC attachment
+
private subnets
+
security groups
```

through Lambda's managed Hyperplane networking. ([AWS Documentation][18])

---

# 99. Scenario

> Lambda was placed in a public subnet but can't reach the internet.

Expected behavior.

```text
Public subnet
does not automatically provide
public IP/internet access
to Lambda.
```

([AWS Documentation][18])

---

# 100. Scenario

> Need deployment package containing several GB of native libraries.

Evaluate:

```text
Lambda container image
```

which currently supports up to:

```text
10 GB uncompressed
```

for a Lambda function image. ([AWS Documentation][5])

---

# 101. Scenario

> Need function to run 45 minutes continuously.

Standard Lambda Function is not the correct ordinary execution primitive because a standard invocation has a maximum of 15 minutes. ([AWS Documentation][5])

Depending on the workload, evaluate alternatives such as:

```text
Step Functions / durable orchestration

ECS/Fargate

AWS Batch

EC2
```

rather than fighting the execution model.

---

# 102. Scenario

> Need temporary local scratch space of 6 GB.

Configure:

```text
Lambda Ephemeral Storage
=
6144 MB
```

because current `/tmp` supports 512–10,240 MB. ([AWS Documentation][24])

---

# 103. Scenario

> Need permanent storage of 6 GB shared across invocations.

Do **not** choose `/tmp`.

Think:

```text
S3
EFS
database
```

depending on access requirements.

`/tmp` is per execution environment and temporary. ([AWS Documentation][24])

---

# 104. Scenario

> Need safe production canary deployment.

Use:

```text
published versions
+
alias
+
weighted routing
```

for controlled traffic shifting. ([AWS Documentation][20])

---

# 105. Serverless Doesn't Remove Architecture

A bad serverless system:

```text
API Gateway
     │
     ▼
Lambda
     │
     ▼
RDS

Lambda scales to 10,000
RDS supports 500 connections

              💥
```

A good design:

```text
API Gateway
     │
     ▼
Lambda
     │
     ├── reserved concurrency
     ├── connection reuse
     ├── timeouts
     ├── retries
     └── backpressure
          │
          ▼
         RDS
```

Serverless removes infrastructure management.

It does **not** remove:

```text
capacity engineering

failure handling

security design

distributed-systems design

cost engineering
```

---

# 106. The Lambda Master Mental Model

```text
                     EVENT / REQUEST
                            │
                            ▼
                          LAMBDA
                            │
                  execution environment
                            │
                 ┌──────────┼──────────┐
                 ▼          ▼          ▼
               INIT       INVOKE    SHUTDOWN
                 │          │
                 ▼          ▼
            cold start    handler
                            │
              ┌─────────────┼───────────────┐
              ▼             ▼               ▼
             IAM          VPC            /tmp
              │             │               │
              ▼             ▼               ▼
             AWS        private          transient
           services     resources           cache

                            │
                            ▼
                       CONCURRENCY
                            │
                  ┌─────────┴─────────┐
                  ▼                   ▼
              Reserved           Provisioned
                  │                   │
            protect/limit        pre-initialize
```

---

# 107. 30 Lambda Rules to Burn Into Memory

```text
1. Serverless means you don't manage servers.

2. Lambda is event-driven compute.

3. A handler is your function entry point.

4. `event` contains trigger-specific input.

5. Lambda runs code inside execution environments.

6. The main lifecycle is INIT → INVOKE → SHUTDOWN.

7. New execution environment = potential cold start.

8. Reused environment = warm invocation opportunity.

9. Never rely on memory between invocations for durable state.

10. Initialize reusable clients outside the handler.

11. /tmp is temporary execution-environment storage.

12. /tmp currently supports 512 MB–10 GB.

13. Lambda memory currently supports 128 MB–10 GB.

14. More memory also gives more CPU.

15. ~1,769 MB corresponds to roughly one vCPU.

16. Standard Lambda timeout is at most 15 minutes.

17. Concurrency = simultaneous executing invocations.

18. Approximate concurrency =
    requests/sec × duration.

19. Duration directly influences concurrency pressure.

20. Reserved concurrency protects AND limits a function.

21. Reserved concurrency does not remove cold starts.

22. Provisioned concurrency pre-initializes environments.

23. Reserved concurrency = 0 can stop processing.

24. Lambda standard scaling is fast but not instantaneous.

25. Protect downstream systems from Lambda scaling.

26. VPC Lambda uses managed Hyperplane networking.

27. Putting Lambda in a public subnet doesn't give it a public IP.

28. Use execution roles with least privilege.

29. Use published versions + aliases for production.

30. Design every Lambda for duplicate-safe/idempotent execution.
```

---

# ✅ Lesson 33 Part 1 Complete

You now understand:

```text
✓ serverless mental model
✓ event-driven computing
✓ Lambda handler
✓ event
✓ context

✓ execution environments
✓ INIT
✓ INVOKE
✓ SHUTDOWN
✓ cold starts
✓ warm starts
✓ execution reuse
✓ static initialization
✓ connection reuse

✓ /tmp
✓ ephemeral storage
✓ transient caching

✓ memory sizing
✓ CPU scaling
✓ 1,769-MB vCPU relationship
✓ timeout
✓ 15-minute limit

✓ concurrency
✓ concurrency formula
✓ regional account concurrency
✓ per-function scaling
✓ throttling

✓ reserved concurrency
✓ provisioned concurrency
✓ downstream protection
✓ cold-start mitigation

✓ current Node.js/Python/Java runtimes
✓ Amazon Linux 2023
✓ x86_64
✓ arm64

✓ ZIP deployments
✓ container-image deployments
✓ ECR
✓ image digest behavior

✓ execution roles
✓ Lambda trust policy
✓ CloudWatch logging permissions
✓ least privilege
✓ environment variables
✓ Secrets Manager integration

✓ synchronous invocation
✓ asynchronous invocation
✓ retries overview
✓ idempotency

✓ VPC Lambda
✓ private subnets
✓ public-subnet myth
✓ Hyperplane ENIs
✓ security groups
✓ NACL ephemeral ports

✓ $LATEST
✓ versions
✓ aliases
✓ weighted aliases
✓ canary deployments

✓ CLI hands-on
✓ Terraform architecture
✓ production failure scenarios
✓ SAA-C03 / DOP-C02 interview traps
```

# Next — Lesson 33 Part 2

# **Lambda Event Sources, Retries, SQS, Streams, DLQs, Destinations & Idempotency**

Now we'll answer the deeper distributed-systems question:

```text
WHAT HAPPENS
WHEN LAMBDA FAILS?
```

We'll build:

```text
                     EVENT PRODUCERS

       ┌───────────────┼─────────────────┐
       ▼               ▼                 ▼
      S3              SNS             EventBridge
       │               │                 │
       └───────────────┼─────────────────┘
                       ▼
                  ASYNC LAMBDA
                       │
                    retries
                       │
                  ┌────┴────┐
                  ▼         ▼
               SUCCESS    FAILURE
                  │         │
                  ▼         ▼
            Destination   DLQ /
                         Destination


                         SQS
                          │
                          ▼
                    Event Source
                       Mapping
                          │
                          ▼
                        Lambda
                          │
                    batch processing
                          │
                 ┌────────┴─────────┐
                 ▼                  ▼
             successful           failed
               items               items
                                     │
                                     ▼
                            partial batch response
                                     │
                                     ▼
                                SQS DLQ


                Kinesis / DynamoDB Streams
                          │
                          ▼
                       batches
                          │
                   ordering/shards
                          │
                          ▼
                        Lambda
```

We’ll cover **push vs poll invocation, synchronous vs asynchronous vs event-source mapping, S3/SNS/EventBridge invocation, SQS polling, visibility timeout, batch size, batch windows, duplicates, idempotency keys, partial batch responses, FIFO ordering, maximum concurrency, the new SQS provisioned poller mode, Kinesis/DynamoDB Streams checkpoints, bisect-batch-on-error, maximum record age, parallelization factor, Lambda async retry rules, DLQ vs on-failure destinations, S3 failure destinations, Powertools idempotency/batch processing, poison messages, backpressure, event filtering, CloudWatch metrics and full Terraform production patterns.**

[1]: https://docs.aws.amazon.com/lambda/latest/dg/welcome.html?utm_source=chatgpt.com "What is AWS Lambda? - AWS Lambda"
[2]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html "Understanding the Lambda execution environment lifecycle - AWS Lambda"
[3]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html "Understanding Lambda function scaling - AWS Lambda"
[4]: https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html?utm_source=chatgpt.com "Best practices for working with AWS Lambda functions"
[5]: https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html "Lambda quotas - AWS Lambda"
[6]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-memory.html "Configure Lambda function memory - AWS Lambda"
[7]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-timeout.html?utm_source=chatgpt.com "Configure Lambda function timeout"
[8]: https://docs.aws.amazon.com/lambda/latest/dg/provisioned-concurrency.html?utm_source=chatgpt.com "Configuring provisioned concurrency for a function"
[9]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-concurrency.html?utm_source=chatgpt.com "Configuring reserved concurrency for a function"
[10]: https://docs.aws.amazon.com/lambda/latest/dg/scaling-behavior.html?utm_source=chatgpt.com "Lambda scaling behavior"
[11]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html "Lambda runtimes - AWS Lambda"
[12]: https://docs.aws.amazon.com/lambda/latest/dg/images-create.html?utm_source=chatgpt.com "Create a Lambda function using a container image"
[13]: https://docs.aws.amazon.com/lambda/latest/dg/nodejs-image.html "Deploy Node.js Lambda functions with container images - AWS Lambda"
[14]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html?utm_source=chatgpt.com "Defining Lambda function permissions with an execution role"
[15]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html?utm_source=chatgpt.com "Working with Lambda environment variables"
[16]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-sync.html "Invoke a Lambda function synchronously - AWS Lambda"
[17]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-error-handling.html "How Lambda handles errors and retries with asynchronous invocation - AWS Lambda"
[18]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html "Giving Lambda functions access to resources in an Amazon VPC - AWS Lambda"
[19]: https://docs.aws.amazon.com/lambda/latest/dg/troubleshooting-networking.html?utm_source=chatgpt.com "Troubleshoot networking issues in Lambda"
[20]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-versions.html "Manage Lambda function versions - AWS Lambda"
[21]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-aliases.html?utm_source=chatgpt.com "Create an alias for a Lambda function"
[22]: https://docs.aws.amazon.com/lambda/latest/dg/configuring-alias-routing.html "Implement Lambda canary deployments using a weighted alias - AWS Lambda"
[23]: https://docs.aws.amazon.com/lambda/latest/dg/monitoring-concurrency.html?utm_source=chatgpt.com "Monitoring concurrency - AWS Lambda"
[24]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-ephemeral-storage.html?utm_source=chatgpt.com "Configure ephemeral storage for Lambda functions"
