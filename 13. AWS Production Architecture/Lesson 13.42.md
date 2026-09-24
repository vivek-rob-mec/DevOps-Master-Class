# AWS Masterclass — Phase 3

# Lesson 41: AWS Lambda Production Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Decide when Lambda is the correct compute service.
* Understand handlers, events, context and execution environments.
* Distinguish cold starts from warm invocations.
* Optimize initialization and dependency loading.
* Configure memory, CPU, timeout and temporary storage.
* Package functions using ZIP archives, layers and container images.
* Understand synchronous, asynchronous and poll-based invocation.
* Configure retries, destinations and dead-letter queues.
* Consume SQS and stream events safely.
* Handle partial batch failures.
* Design idempotent Lambda functions.
* Calculate concurrency requirements.
* Use reserved and provisioned concurrency.
* Prevent Lambda from overwhelming databases and APIs.
* Connect functions to private VPC resources.
* Configure versions, aliases and canary deployments.
* Secure execution roles and resource-based policies.
* Retrieve secrets safely.
* Monitor Lambda with CloudWatch, X-Ray and Powertools.
* Deploy Lambda functions using Terraform.

---

# 2. What is AWS Lambda?

AWS Lambda runs application code without requiring you to provision, patch or manage servers. Lambda creates and scales execution environments in response to invocations and handles the underlying infrastructure automatically. ([AWS Documentation][1])

```text
Event
  |
  v
AWS Lambda
  |
  v
Function code
  |
  v
Result or side effect
```

Typical triggers include:

```text
API Gateway
S3
SQS
SNS
EventBridge
DynamoDB Streams
Kinesis
CloudWatch Logs
Step Functions
```

Lambda integrates with hundreds of AWS service and SaaS event sources. ([AWS Documentation][1])

---

# 3. Lambda’s responsibility versus your responsibility

## AWS manages

```text
Physical servers
Hypervisor and isolation
Operating-system infrastructure
Runtime provisioning
Capacity scaling
Availability Zone distribution
Infrastructure patching
Execution-environment creation
```

## You manage

```text
Application code
Dependencies
Runtime selection
IAM permissions
Memory and timeout
Error handling
Retries and idempotency
Networking
Observability
Security of business logic
Cost controls
```

Serverless does not mean:

```text
No architecture
No operations
No security
No debugging
```

It means the server infrastructure is managed for you.

---

# 4. Current Lambda platform note

Current AWS Lambda documentation distinguishes several Lambda compute models, including traditional short-lived Lambda Functions, Durable Functions for long-running stateful execution and newer managed execution models. Standard Lambda functions remain limited to 15 minutes per invocation, while Durable Functions can retain workflow state over much longer periods. This lesson focuses primarily on conventional event-driven Lambda Functions. ([AWS Documentation][2])

---

# 5. When Lambda is a strong choice

Lambda is well suited for:

* Event-driven processing.
* APIs with variable traffic.
* Lightweight microservices.
* S3 file processing.
* Queue consumers.
* Scheduled automation.
* Security remediation.
* Data transformation.
* Webhooks.
* Notification handling.
* Infrastructure automation.
* Short-running ETL.
* Step Functions tasks.

Example:

```text
User uploads image to S3
        |
        v
S3 event
        |
        v
Lambda image processor
        |
        v
Thumbnail stored in S3
```

---

# 6. When Lambda may not be the best choice

Evaluate ECS, EKS, EC2, Batch or Fargate when the workload requires:

* More than 15 minutes in one invocation.
* Long-running persistent processes.
* Full operating-system control.
* Custom kernel capabilities.
* Stable local state.
* Constant high CPU utilization.
* Large GPU workloads.
* Complex background daemons.
* Thousands of persistent network connections.
* Predictable continuous compute where containers may be more economical.

Lambda should not be selected merely because it is labelled serverless.

---

# 7. Lambda handler

The handler is the entry point Lambda invokes.

Node.js example:

```javascript
export const handler = async (event, context) => {
  console.log("Received event:", JSON.stringify(event));

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "Todo processed successfully"
    })
  };
};
```

Python example:

```python
def lambda_handler(event, context):
    print(f"Received event: {event}")

    return {
        "statusCode": 200,
        "body": "Todo processed successfully"
    }
```

The event contains input from the invoking service, while the context object includes invocation and function metadata.

---

# 8. Event format depends on the trigger

An API Gateway event is different from an SQS event.

## API Gateway concept

```json
{
  "requestContext": {},
  "headers": {},
  "body": "{\"title\":\"Learn Lambda\"}"
}
```

## SQS concept

```json
{
  "Records": [
    {
      "messageId": "abc-123",
      "body": "{\"todoId\":\"todo-501\"}"
    }
  ]
}
```

## S3 concept

```json
{
  "Records": [
    {
      "s3": {
        "bucket": {
          "name": "production-uploads"
        },
        "object": {
          "key": "documents/file.pdf"
        }
      }
    }
  ]
}
```

Never assume the event structure. Validate it against the exact triggering service and event version.

---

# 9. Context object

The context object commonly provides information such as:

```text
Function name
Function version
Invocation request ID
Remaining execution time
Memory limit
Log group
Log stream
Invoked function ARN
```

Node.js example:

```javascript
export const handler = async (event, context) => {
  console.log({
    requestId: context.awsRequestId,
    functionName: context.functionName,
    functionVersion: context.functionVersion,
    remainingMs: context.getRemainingTimeInMillis()
  });
};
```

Use the request ID in structured logs so one invocation can be traced easily.

---

# 10. Lambda execution environment

Lambda invokes each concurrent request inside an isolated execution environment.

The environment contains:

```text
Runtime
Function code
Dependencies
Environment variables
Temporary /tmp storage
Extensions
Temporary AWS credentials
```

The primary lifecycle phases are:

```text
Init
Invoke
Shutdown
```

During initialization, Lambda starts extensions, starts the runtime and runs code outside the handler. Lambda may freeze and later reuse the environment for subsequent invocations. ([AWS Documentation][2])

---

# 11. Initialization phase

Code outside the handler executes during initialization.

```javascript
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

const dynamo = new DynamoDBClient({});
const configuration = loadConfiguration();

export const handler = async (event) => {
  // dynamo and configuration can be reused
};
```

During a new environment’s initialization, Lambda:

```text
Starts extensions
Bootstraps the runtime
Loads application code
Executes global initialization
```

For ordinary on-demand environments, initialization is normally limited separately from handler execution, while SnapStart and provisioned concurrency have different initialization behavior. ([AWS Documentation][2])

---

# 12. Cold start

A cold start occurs when Lambda must create and initialize a new execution environment before running the handler.

```text
Request
  |
  v
Create execution environment
  |
  v
Initialize runtime
  |
  v
Load dependencies
  |
  v
Execute global code
  |
  v
Invoke handler
```

Cold-start duration can include:

```text
Runtime startup
Large dependency loading
Framework initialization
Extension initialization
VPC readiness
Configuration loading
Application initialization
```

---

# 13. Warm invocation

When an existing environment is available:

```text
Request
  |
  v
Reuse initialized environment
  |
  v
Invoke handler
```

Global objects may still exist:

```javascript
let invocationCount = 0;

export const handler = async () => {
  invocationCount += 1;

  return {
    invocationCount
  };
};
```

However, Lambda does not guarantee how long an execution environment remains available.

Never depend on local memory as the authoritative data store.

---

# 14. Safe state reuse

Safe reusable items include:

* AWS SDK clients.
* Database connection pools.
* Parsed configuration.
* Static lookup data.
* Cached secrets with controlled expiry.
* HTTP keep-alive clients.
* Compiled templates.

Unsafe assumptions include:

```text
The same environment will handle the next request.
A local variable is shared across every Lambda instance.
A /tmp file will always exist.
A database connection will never become stale.
```

Execution-environment reuse is an optimization, not a durability guarantee.

---

# 15. Database connection example

Bad:

```javascript
export const handler = async () => {
  const connection = await createDatabaseConnection();

  const result = await connection.query("SELECT 1");

  await connection.close();

  return result;
};
```

This establishes a connection every invocation.

Better:

```javascript
let database;

async function getDatabase() {
  if (!database) {
    database = await createDatabaseConnection();
  }

  return database;
}

export const handler = async () => {
  const db = await getDatabase();

  try {
    return await db.query("SELECT 1");
  } catch (error) {
    database = undefined;
    throw error;
  }
};
```

Connections must still handle:

* Idle closure.
* Credential rotation.
* Network interruption.
* Database failover.
* Maximum lifetime.
* Pool exhaustion.

---

# 16. Cold-start optimization

Reduce cold-start impact by:

* Keeping deployment packages small.
* Importing only required libraries.
* Avoiding large frameworks for tiny functions.
* Moving reusable setup outside the handler.
* Lazy-loading rarely used modules.
* Reducing extension count.
* Avoiding unnecessary network calls during initialization.
* Choosing an appropriate runtime.
* Measuring initialization duration.
* Using SnapStart or provisioned concurrency where appropriate.

AWS specifically recommends optimizing static initialization because initialization code is commonly the largest controllable contributor to cold-start duration. ([AWS Documentation][3])

---

# 17. Provisioned concurrency

Provisioned concurrency keeps a specified number of execution environments initialized and ready.

```text
Without provisioned concurrency:
Request → Initialize → Invoke

With provisioned concurrency:
Pre-initialized environment → Invoke
```

Provisioned concurrency is intended for latency-sensitive workloads such as interactive APIs and is configured on a published version or alias, not `$LATEST`. It incurs additional charges. ([AWS Documentation][4])

Use cases:

* Customer login API.
* Payment validation.
* Interactive mobile API.
* Low-latency Java application.
* Predictable peak traffic.

---

# 18. Provisioned concurrency is not reserved concurrency

## Reserved concurrency

```text
Guarantees capacity for a function
+
Limits its maximum concurrency
```

## Provisioned concurrency

```text
Pre-initializes execution environments
to reduce cold-start latency
```

Reserved concurrency has no direct additional charge, while provisioned concurrency does. ([AWS Documentation][4])

A function can use both:

```text
Reserved concurrency:
100

Provisioned concurrency:
30
```

Meaning:

```text
30 environments initialized
Function can scale to at most 100 concurrent executions
```

---

# 19. Lambda SnapStart

SnapStart initializes a function when publishing a version, snapshots the initialized memory and disk state, encrypts the snapshot and restores new execution environments from that snapshot rather than running full initialization each time. ([AWS Documentation][5])

```text
Publish version
      |
      v
Initialize function
      |
      v
Create encrypted snapshot
      |
      v
Invocation
      |
      v
Restore from snapshot
```

Current supported managed runtimes include:

```text
Java 11 and later
Python 3.12 and later
.NET 8 and later
```

SnapStart is not currently supported for Node.js, container-image functions, provisioned concurrency, EFS or ephemeral storage above 512 MB. ([AWS Documentation][6])

---

# 20. SnapStart uniqueness problem

Suppose initialization creates:

```text
Random identifier
Encryption nonce
Temporary credential
Database connection
Timestamp
```

SnapStart may restore multiple environments from one initial state.

Therefore, uniqueness-sensitive state may need regeneration after restore.

Use runtime hooks where supported:

```text
Before snapshot
After restore
```

AWS provides runtime-hook mechanisms for supported Java, Python and .NET SnapStart runtimes. ([AWS Documentation][7])

---

# 21. SnapStart versus provisioned concurrency

| Requirement                             | SnapStart               | Provisioned concurrency      |
| --------------------------------------- | ----------------------- | ---------------------------- |
| Reduces initialization latency          | Yes                     | Yes                          |
| Additional preallocated capacity charge | Different pricing model | Yes                          |
| Supported on `$LATEST`                  | No                      | No                           |
| Supported on container images           | No                      | Yes                          |
| Supports Node.js                        | No                      | Yes                          |
| Supports EFS                            | No                      | Yes                          |
| Best for strict predictable low latency | Sometimes               | Strongest fit                |
| Scales from snapshot                    | Yes                     | Pre-initialized environments |

AWS recommends provisioned concurrency when strict cold-start latency requirements cannot be met adequately using SnapStart. ([AWS Documentation][5])

---

# 22. Memory and CPU

Lambda memory can be configured from:

```text
128 MB
to
10,240 MB
```

in 1-MB increments.

CPU capacity increases proportionally with memory. At 1,769 MB, a function receives approximately the equivalent of one vCPU. ([AWS Documentation][8])

```text
More memory
    +
More CPU
    +
More network capability
    =
Potentially shorter execution duration
```

Increasing memory can sometimes lower total cost if execution time falls significantly.

---

# 23. Memory tuning example

Function A:

```text
Memory:
512 MB

Duration:
4 seconds
```

Function B:

```text
Memory:
1,024 MB

Duration:
1.7 seconds
```

Although Function B uses more memory, its shorter runtime might make cost comparable or lower.

Do not choose memory by guessing.

Benchmark:

```text
128
256
512
1,024
1,769
3,008
```

against:

* Duration.
* p95 latency.
* Maximum memory used.
* Cost.
* Cold-start duration.
* Downstream behavior.

---

# 24. Timeout

Lambda timeout can be configured from one second up to:

```text
900 seconds
15 minutes
```

The default timeout is three seconds. ([AWS Documentation][9])

Bad:

```text
Normal processing:
8 seconds

Timeout:
900 seconds
```

A stuck dependency may consume capacity for 15 minutes.

Better:

```text
Normal:
8 seconds

p99:
15 seconds

Timeout:
20–30 seconds
```

Set the timeout long enough for normal variation but short enough to detect failure promptly.

---

# 25. Downstream timeouts

The Lambda timeout should not be the only timeout.

Configure:

```text
HTTP connection timeout
HTTP response timeout
Database query timeout
SDK retry policy
Socket timeout
```

Example:

```text
Lambda timeout:
30 seconds

Database query timeout:
5 seconds

External HTTP timeout:
3 seconds

Internal retry budget:
2 attempts
```

This leaves enough time to log, clean up and return a controlled failure.

---

# 26. Temporary storage

Lambda provides temporary local storage at:

```text
/tmp
```

It can be configured from:

```text
512 MB
to
10,240 MB
```

in 1-MB increments, and the data is encrypted at rest with an AWS-managed key. ([AWS Documentation][10])

Use `/tmp` for:

* Downloaded S3 files.
* Intermediate ETL data.
* Image processing.
* PDF generation.
* Temporary ML models.
* Compressed archives.
* Local caching.

---

# 27. `/tmp` is not permanent storage

```text
/tmp may survive:
Warm invocation reuse

/tmp may disappear:
New execution environment
Environment shutdown
Scaling event
```

Do not store:

* Authoritative uploads.
* Permanent reports.
* Critical checkpoints.
* Shared application data.

Use:

```text
S3
DynamoDB
RDS
EFS
ElastiCache
```

for durable or shared state.

---

# 28. Deployment package types

Lambda supports two main deployment package types:

```text
ZIP archive
Container image
```

You select the package type when creating the function. An existing function cannot be converted directly from ZIP to container image or the reverse; create a new function instead. ([AWS Documentation][11])

---

# 29. ZIP deployment package limits

Current limits include:

```text
50 MB zipped:
Direct API, SDK or console upload

250 MB unzipped:
Function code plus layers and custom runtime

Maximum layers:
5
```

For larger ZIP archives, the deployment package can be provided through S3, but the uncompressed function-and-layer limit still applies. ([AWS Documentation][12])

---

# 30. Container images

Lambda container images can be up to:

```text
10 GB uncompressed
including all image layers
```

The image must be stored in Amazon ECR in the same Region as the function, although cross-account repositories can be used with appropriate permissions. Lambda supports Linux-based single-architecture images. ([AWS Documentation][11])

Use container images when:

* Native libraries are large.
* A custom runtime is required.
* Existing container build tooling is preferred.
* Dependencies exceed ZIP limits.
* Consistent local development is important.

---

# 31. Container image example

```dockerfile
FROM public.ecr.aws/lambda/nodejs:24

COPY package*.json ${LAMBDA_TASK_ROOT}/

RUN npm ci --omit=dev

COPY src/ ${LAMBDA_TASK_ROOT}/

CMD ["index.handler"]
```

Build:

```bash
docker build \
  --platform linux/arm64 \
  -t todo-lambda:1.0.0 .
```

Tag and push to ECR:

```bash
docker tag \
  todo-lambda:1.0.0 \
  ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/todo-lambda:1.0.0

docker push \
  ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/todo-lambda:1.0.0
```

Use immutable version tags or image digests for production—not `latest`.

---

# 32. Lambda layers

A layer is a separately versioned ZIP archive containing reusable:

* Libraries.
* Custom runtimes.
* Configuration.
* Extensions.
* Shared code.

Each layer version is immutable and has its own ARN. Functions must reference an exact layer version. ([AWS Documentation][13])

```text
Function package
      +
Shared dependency layer
      +
Observability extension layer
```

---

# 33. Layer advantages and risks

## Advantages

* Share common dependencies.
* Reduce duplication in function ZIP files.
* Centralize custom runtime components.
* Distribute extensions.

## Risks

* Hidden dependency coupling.
* Breaking multiple functions through careless upgrades.
* Large combined unzipped size.
* Runtime compatibility issues.
* Slower initialization from unnecessary libraries.
* Difficult local testing.

Pin exact layer versions:

```text
my-shared-layer:17
```

Do not reference an abstract “latest” layer in production.

---

# 34. Lambda extensions

Extensions can integrate Lambda with:

* Monitoring tools.
* Security agents.
* Secrets retrieval.
* Configuration systems.
* Telemetry platforms.
* Governance tools.

Extensions participate in execution-environment lifecycle phases and share the environment’s CPU, memory, permissions and resources. ([AWS Documentation][14])

An extension can increase:

```text
Initialization time
Memory consumption
Shutdown duration
Network calls
Cost
```

Only install extensions that provide measurable value.

---

# 35. Invocation methods

Lambda invocation behavior falls into three main patterns:

```text
Synchronous invocation
Asynchronous invocation
Event source mapping
```

Understanding the invocation method is essential because:

```text
Retries differ
Error destinations differ
Concurrency behavior differs
Batch handling differs
```

([AWS Documentation][15])

---

# 36. Synchronous invocation

Examples:

* API Gateway.
* Application Load Balancer.
* Direct SDK `RequestResponse`.
* Step Functions task.
* Lambda Function URL.

```text
Caller
  |
  | Request
  v
Lambda
  |
  | Response or error
  v
Caller
```

For function-code errors in direct synchronous invocation, Lambda returns the error to the caller and does not automatically retry it. The caller or upstream service decides whether to retry. ([AWS Documentation][16])

---

# 37. Synchronous retry danger

Suppose the client times out after Lambda successfully writes to a database:

```text
Lambda writes order
        |
        v
Response lost
        |
        v
Client retries
        |
        v
Duplicate order
```

Therefore even synchronous functions should use idempotency keys for business-changing operations.

```json
{
  "idempotencyKey": "create-order-user104-request501"
}
```

---

# 38. Asynchronous invocation

Examples include:

* S3 notifications.
* SNS.
* EventBridge.
* Direct invocation using `InvocationType=Event`.

```text
Producer
  |
  v
Lambda asynchronous event queue
  |
  v
Function
```

The producer receives confirmation that Lambda accepted the event—not the final function result. ([AWS Documentation][17])

---

# 39. Asynchronous retry behavior

For asynchronous function errors, Lambda normally:

```text
Initial invocation
      |
      v
Retry after approximately 1 minute
      |
      v
Retry after approximately 2 more minutes
```

For throttling and Lambda service errors, Lambda can retry from its internal event queue for up to six hours by default, using exponential backoff. Duplicate deliveries remain possible, so handlers must be idempotent. ([AWS Documentation][18])

---

# 40. Asynchronous event age and retries

You can configure asynchronous invocation settings including:

```text
Maximum retry attempts
Maximum event age
On-success destination
On-failure destination
```

When the configured event age or retry limit is exceeded, Lambda discards the event unless a destination or dead-letter mechanism retains information about the failed invocation. ([AWS Documentation][19])

Example policy:

```text
Maximum event age:
1 hour

Maximum retry attempts:
2

Failure destination:
SQS failure queue
```

---

# 41. Async destination versus DLQ

## Lambda dead-letter queue

Receives the original event payload after asynchronous processing fails.

Destinations can include:

```text
SQS
SNS
```

## Lambda on-failure destination

Receives a richer invocation record containing:

```text
Original request
Response context
Error details
Attempt information
Function metadata
```

Destinations support resources such as SQS, SNS, Lambda and EventBridge, depending on success or failure configuration. ([AWS Documentation][20])

Prefer destinations for modern asynchronous designs because the diagnostic context is richer.

---

# 42. Event source mappings

For polling sources, Lambda creates and manages pollers.

Common event-source mappings include:

```text
SQS
Kinesis
DynamoDB Streams
Amazon MSK
Self-managed Kafka
Amazon MQ
DocumentDB change streams
```

```text
Queue or stream
      |
      v
Lambda-managed poller
      |
      v
Batch of records
      |
      v
Function invocation
```

Event-source mappings provide batching, filtering, scaling and source-specific failure controls. ([AWS Documentation][21])

---

# 43. Lambda with SQS

```text
Producer
  |
  v
SQS queue
  |
  v
Lambda event-source mapping
  |
  v
Lambda worker
```

Lambda polls the queue, invokes the function synchronously with a batch and deletes successfully processed messages after successful batch handling.

The queue and function must be in the same AWS Region, although they may be in different AWS accounts. AWS recommends setting the SQS visibility timeout to at least six times the function timeout to accommodate retries and throttling behavior. ([AWS Documentation][22])

---

# 44. SQS batch size

For an SQS event-source mapping:

```text
Standard queue:
Up to 10,000 records per batch

FIFO queue:
Up to 10 records per batch
```

The default batch size is 10. A batching window is supported for standard queues but not FIFO queues. ([AWS Documentation][23])

Large batches improve efficiency but increase:

* Failure blast radius.
* Memory usage.
* Processing duration.
* Payload size.
* Duplicate work after failure.

---

# 45. Whole-batch failure problem

Batch:

```text
Message A → success
Message B → success
Message C → failure
Message D → success
```

Without partial batch failure handling:

```text
Entire invocation fails
        |
        v
A, B, C and D become eligible for retry
```

Successful records may be processed again.

---

# 46. Partial batch responses

Configure the event-source mapping with:

```text
ReportBatchItemFailures
```

Then return only the failed item identifiers.

Node.js example:

```javascript
export const handler = async (event) => {
  const failures = [];

  for (const record of event.Records) {
    try {
      await processMessage(JSON.parse(record.body));
    } catch (error) {
      failures.push({
        itemIdentifier: record.messageId
      });
    }
  }

  return {
    batchItemFailures: failures
  };
};
```

Lambda processes partial batch responses only when the event-source mapping explicitly enables `ReportBatchItemFailures`. ([AWS Documentation][24])

---

# 47. FIFO partial batch caution

For FIFO queues:

```text
A succeeds
B fails
C follows B in same group
D follows B in same group
```

After B fails, continuing to process C and D may violate business ordering.

Recommended FIFO behavior:

```text
Stop processing the message group after the first failure.
Return the failed and unprocessed records.
```

Ordering semantics are more important than maximizing throughput.

---

# 48. SQS scaling control

You can configure maximum concurrency on an SQS event-source mapping to stop one queue from consuming all function concurrency or overwhelming a downstream dependency.

Current SQS mappings can also use provisioned polling mode with configurable dedicated poller counts. Provisioned polling mode and standard maximum-concurrency configuration cannot be enabled together. ([AWS Documentation][22])

Example:

```text
Function reserved concurrency:
100

Queue A maximum concurrency:
60

Queue B maximum concurrency:
20
```

This leaves capacity for other event sources or direct invocation.

---

# 49. Stream event sources

For Kinesis and DynamoDB Streams, Lambda processes ordered records from shards.

```text
Shard 1 → ordered records → Lambda
Shard 2 → ordered records → Lambda
```

Failure handling options include:

* Maximum record age.
* Maximum retry attempts.
* Bisect batch on function error.
* Partial batch response.
* Failure destination.

By default, some stream failures can block progress on the affected shard until records expire or are handled. ([AWS Documentation][21])

---

# 50. Bisect batch on error

Batch:

```text
[A, B, C, D, E, F, G, H]
```

Failure:

```text
Split into:
[A, B, C, D]
[E, F, G, H]
```

If the second half fails:

```text
Split into:
[E, F]
[G, H]
```

This helps isolate a poison record without writing custom binary-search logic.

---

# 51. Idempotency

Lambda integrations frequently use at-least-once delivery or retries.

An idempotent function produces one logical business effect even when the same event is handled repeatedly.

```text
Event ID:
evt-501
```

Consumer flow:

```text
Receive evt-501
      |
      v
Check idempotency store
      |
      ├── Already complete → Return prior result
      |
      └── Not complete
              |
              v
         Perform action
              |
              v
       Record completion
```

AWS Lambda best practices explicitly recommend idempotent function code. ([AWS Documentation][25])

---

# 52. DynamoDB idempotency pattern

Table:

```text
Partition key:
idempotencyKey

Attributes:
status
result
expiry
createdAt
```

Conditional claim:

```javascript
import {
  DynamoDBClient,
  PutItemCommand
} from "@aws-sdk/client-dynamodb";

const client = new DynamoDBClient({});

async function claimEvent(eventId) {
  await client.send(new PutItemCommand({
    TableName: process.env.IDEMPOTENCY_TABLE,
    Item: {
      idempotencyKey: { S: eventId },
      status: { S: "IN_PROGRESS" },
      expiry: {
        N: String(Math.floor(Date.now() / 1000) + 86400)
      }
    },
    ConditionExpression: "attribute_not_exists(idempotencyKey)"
  }));
}
```

Handle:

* Concurrent duplicate invocations.
* Stale `IN_PROGRESS` records.
* Function crashes after the side effect.
* Expiration policy.
* Result retrieval.

---

# 53. Concurrency

Lambda concurrency is the number of invocations being processed simultaneously.

```text
Concurrency =
Requests per second
×
Average duration in seconds
```

Example:

```text
Request rate:
200 requests/second

Average duration:
0.25 seconds

Required concurrency:
200 × 0.25 = 50
```

Each concurrent request ordinarily requires an execution environment. ([AWS Documentation][26])

---

# 54. Concurrency example with slow dependency

Before database slowdown:

```text
100 requests/second
× 0.2 seconds
= 20 concurrency
```

After database slowdown:

```text
100 requests/second
× 3 seconds
= 300 concurrency
```

Traffic did not change, but concurrency increased fifteen times because duration increased.

This can trigger:

* Lambda throttling.
* More database connections.
* Higher cost.
* API timeout.
* Queue backlog.
* Cascading failure.

---

# 55. Regional concurrency quota

The default account concurrency quota is generally:

```text
1,000 concurrent executions
per AWS Region
```

New accounts may initially receive lower quota profiles, and concurrency can be increased through Service Quotas. Lambda also has a per-function scaling rate of 1,000 new execution environments every 10 seconds. ([AWS Documentation][12])

Do not assume the default will satisfy a large production launch.

---

# 56. Shared unreserved concurrency

Suppose the Region has:

```text
Account concurrency:
1,000
```

Functions:

```text
Image processor
Email sender
Payment API
Report generator
```

Without reserved concurrency, one runaway function can consume the shared pool and throttle others.

```text
Image loop:
950 concurrency

Remaining:
50 for every other function
```

---

# 57. Reserved concurrency

Reserved concurrency:

```text
Guarantees an allocation
+
Caps maximum concurrency
```

Example:

```text
Payment API:
Reserved concurrency = 200

Report generator:
Reserved concurrency = 20
```

The payment API always has protected capacity, while the report generator cannot exceed 20 and overwhelm the reporting database. ([AWS Documentation][4])

---

# 58. Reserved concurrency as a kill switch

Setting:

```text
Reserved concurrency = 0
```

prevents the function from processing invocations.

Use cautiously for:

* Recursive loops.
* Security incidents.
* Runaway cost.
* Broken event consumer.

But remember:

* Events may continue accumulating.
* Async events may age.
* SQS queues may grow.
* Upstream callers may receive throttling.

Always combine the kill switch with an incident plan.

---

# 59. Downstream protection

Lambda can scale faster than many databases.

Example:

```text
Lambda concurrency:
1,000

Database maximum safe connections:
150
```

Without protection:

```text
Lambda opens 1,000 connections
        |
        v
Database connection exhaustion
```

Controls:

* Reserved concurrency.
* SQS maximum concurrency.
* RDS Proxy.
* Database connection pooling.
* Batch writes.
* Rate limiting.
* Back-pressure.
* Cache.
* Smaller retry volume.

---

# 60. RDS Proxy concept

```text
Lambda execution environments
          |
          v
       RDS Proxy
          |
          v
    Managed connection pool
          |
          v
       RDS database
```

RDS Proxy reduces direct connection churn and helps multiplex Lambda connections to supported relational databases.

It does not remove the need to:

* Set concurrency limits.
* Tune transactions.
* Optimize queries.
* Handle failover.
* Monitor connection usage.

---

# 61. Function versions

`$LATEST` is the mutable unpublished function state.

Publishing creates an immutable numbered version:

```text
$LATEST
   |
   v
Publish
   |
   v
Version 1
```

A published version locks code and version-specific configuration such as memory, environment variables, runtime, layers, VPC settings, timeout, architecture and ephemeral storage. Operational controls such as reserved concurrency are not version-publication triggers. ([AWS Documentation][27])

---

# 62. Lambda aliases

An alias is a named pointer to a published version.

```text
production → version 42
staging    → version 43
```

Clients invoke:

```text
arn:aws:lambda:...:function:todo-api:production
```

rather than:

```text
arn:aws:lambda:...:function:todo-api:42
```

Aliases simplify event-source, permission and deployment management. ([AWS Documentation][28])

---

# 63. Weighted aliases

A Lambda alias can split traffic between two function versions.

```text
production alias
├── 90% → version 42
└── 10% → version 43
```

Both versions used by the weighted alias must use the same execution role and compatible DLQ configuration. ([AWS Documentation][29])

Use weighted aliases for:

* Canary deployments.
* Controlled production testing.
* Gradual rollout.
* Fast rollback.

---

# 64. Canary deployment

Example:

```text
Step 1:
10% → new version
90% → old version

Observe:
Errors
Latency
Throttles
Business metrics

Step 2:
50% → new version

Step 3:
100% → new version
```

If errors increase:

```text
Alias → old version
```

AWS CodeDeploy and SAM can automate canary and linear Lambda deployments with alarm-based rollback. ([AWS Documentation][29])

---

# 65. Deployment hooks

A Lambda CodeDeploy deployment may use:

```text
BeforeAllowTraffic hook
AfterAllowTraffic hook
```

Examples:

```text
Before traffic:
Run integration test against new version

After traffic:
Validate production health
```

The hooks should fail the deployment when validation fails, allowing rollback before full customer exposure.

---

# 66. Lambda deployment strategies

## All at once

```text
100% immediately
```

Fast but highest risk.

## Canary

```text
Small percentage
Wait
Remaining traffic
```

## Linear

```text
Shift a fixed percentage repeatedly
until complete
```

Use:

* All-at-once for low-risk development.
* Canary for critical APIs.
* Linear for gradual broad observation.

---

# 67. Execution role

The execution role determines what the function code can access.

```text
Lambda function
      |
      | Temporary credentials
      v
Execution role
      |
      v
S3 / DynamoDB / SQS / Secrets Manager
```

Lambda assumes this role and supplies temporary credentials to the runtime. The role should contain only the permissions required by the function. ([AWS Documentation][30])

---

# 68. Resource-based policy

A resource-based policy determines who or which service may invoke the Lambda function.

```text
Execution role:
What Lambda may do

Resource policy:
Who may invoke Lambda
```

For example, S3 requires function resource-policy permission to invoke Lambda. Lambda resource policies can grant invocation access to AWS services, accounts or organizations and can be scoped to a function, alias or version. ([AWS Documentation][31])

---

# 69. S3 invocation permission

Terraform concept:

```hcl
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"

  source_arn     = aws_s3_bucket.uploads.arn
  source_account = data.aws_caller_identity.current.account_id
}
```

Use both source ARN and source account where supported to prevent another account from reusing an expected bucket name or service relationship.

---

# 70. Least-privilege execution policy

Bad:

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

Better:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadTodoConfiguration",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:ap-south-1:123456789012:parameter/production/todoapp/*"
    },
    {
      "Sid": "WriteTodoTable",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:ap-south-1:123456789012:table/production-todos"
    }
  ]
}
```

Separate functions by responsibility when their permissions differ substantially.

---

# 71. Environment variables

Environment variables are useful for nonsecret operational configuration:

```text
TABLE_NAME
QUEUE_URL
LOG_LEVEL
ENVIRONMENT
FEATURE_FLAG_NAME
```

The combined environment-variable size limit is 4 KB. Values are literal strings and are locked with other version-specific configuration when a function version is published. AWS recommends Secrets Manager for credentials, API keys and authorization tokens instead of environment variables. ([AWS Documentation][32])

---

# 72. Secrets retrieval

Use:

```text
AWS Secrets Manager
Systems Manager Parameter Store
AWS AppConfig
```

The Parameters and Secrets Lambda Extension or Powertools Parameters utility can retrieve and locally cache secrets and parameters, reducing repeated API calls. ([AWS Documentation][33])

```text
Lambda
  |
  v
Local extension cache
  |
  ├── Cached → return
  |
  └── Missing/expired → retrieve from Secrets Manager
```

Choose cache TTL according to secret-rotation frequency.

---

# 73. Do not hard-code credentials

Never include:

```javascript
const accessKeyId = "AKIA...";
const secretAccessKey = "...";
```

Lambda automatically supplies temporary AWS credentials for the execution role.

Hard-coded credentials create:

* Source-control exposure.
* Rotation difficulty.
* Shared secret risk.
* Incident-response complexity.
* Long-lived access.

---

# 74. VPC attachment

By default, a Lambda function runs in a Lambda-managed network environment and can access public AWS service endpoints.

Attach it to your VPC when it must reach private resources such as:

* RDS.
* ElastiCache.
* Internal ALB.
* Private EC2 service.
* Private OpenSearch.
* VPC-only service endpoint.

Lambda uses managed Hyperplane ENIs associated with the selected subnet and security-group combination. ([AWS Documentation][34])

---

# 75. Lambda VPC architecture

```text
Lambda execution environment
        |
        v
Hyperplane ENI
        |
        v
Private subnet
        |
        ├── RDS
        ├── ElastiCache
        └── Internal service
```

Hyperplane ENIs can be reused by functions using the same subnet and security-group combination and scale automatically as network connection requirements grow. ([AWS Documentation][34])

---

# 76. VPC does not automatically provide internet access

Attaching Lambda to a public subnet does not automatically give it a public IP.

For internet access from a VPC-attached function:

```text
Lambda
   |
   v
Private subnet
   |
   v
NAT gateway
   |
   v
Internet gateway
```

Alternatively, avoid internet paths for AWS services by using:

* S3 gateway endpoint.
* DynamoDB gateway endpoint.
* Secrets Manager interface endpoint.
* SQS interface endpoint.
* SNS interface endpoint.
* ECR endpoints.
* CloudWatch Logs endpoint.

---

# 77. VPC subnet selection

Select subnets across multiple Availability Zones:

```text
Private subnet A
Private subnet B
Private subnet C
```

Do not attach Lambda to only one subnet unless there is a specific architectural reason.

Check:

* Available IP addresses.
* Route tables.
* NAT path.
* VPC endpoints.
* Network ACLs.
* Security groups.
* DNS resolution.

---

# 78. Lambda security group

For database access:

```text
Lambda security group
        |
        | Outbound TCP 5432
        v
Database security group

Database security group:
Inbound TCP 5432 from Lambda security group
```

Avoid:

```text
RDS inbound:
0.0.0.0/0 on 5432
```

Security-group references are clearer and safer than broad CIDR access.

---

# 79. VPC networking troubleshooting

Common errors:

```text
Task timed out
ECONNREFUSED
ETIMEDOUT
ENETUNREACH
Temporary failure in name resolution
```

Check:

1. Correct VPC.
2. Correct private subnets.
3. Lambda security-group egress.
4. Destination security-group ingress.
5. Route tables.
6. NAT gateway or VPC endpoints.
7. DNS support.
8. Network ACL ephemeral ports.
9. Database listener.
10. Subnet free IP addresses.

VPC Lambda networking uses ephemeral ports, and restrictive NACLs that do not allow the required ephemeral range can cause intermittent connection failures. ([AWS Documentation][35])

---

# 80. Function URLs

Lambda Function URLs provide a dedicated HTTPS endpoint for a function.

```text
Client
  |
  v
Lambda Function URL
  |
  v
Lambda
```

Lambda currently supports HTTP invocation through either Function URLs or API Gateway. ([AWS Documentation][36])

Use Function URLs for:

* Simple webhooks.
* Small internal services.
* Lightweight prototypes.
* Simple authenticated endpoints.

Use API Gateway when you need richer capabilities such as:

* Request validation.
* Usage plans.
* API keys.
* Advanced authorization.
* API lifecycle and stages.
* Detailed routing.
* Caching.
* WebSocket APIs.
* Extensive throttling policy.

---

# 81. Response streaming

Lambda can stream response data through supported Function URL, API Gateway proxy and `InvokeWithResponseStream` integrations.

Benefits:

* Better time to first byte.
* Partial response delivery.
* Reduced need to buffer the whole response.
* Responses up to 200 MB instead of the normal 6-MB synchronous buffered-response limit.

The first 6 MB is not subject to the later streaming cap; the remaining streamed response is currently limited to 2 MB per second. ([AWS Documentation][37])

---

# 82. Invocation payload limits

Current function limits include:

```text
Synchronous request:
6 MB

Synchronous response:
6 MB

Streamed response:
Up to 200 MB

Asynchronous event:
1 MB
```

([AWS Documentation][12])

For larger input:

```text
Upload to S3
      |
      v
Invoke Lambda with bucket and key
```

Do not pass large files directly through every service integration.

---

# 83. Recursive loops

Example:

```text
S3 uploads bucket
      |
      v
Lambda
      |
      v
Writes result to same prefix
      |
      v
S3 invokes Lambda again
```

Or:

```text
SQS queue
   |
   v
Lambda
   |
   v
Same SQS queue
```

Recursive loops can consume concurrency rapidly and produce unexpected cost.

Lambda detects selected recursive patterns involving SQS, S3 and SNS and typically stops the chain after approximately 16 recursive invocations, but this protection does not cover every AWS service or architecture. ([AWS Documentation][38])

---

# 84. Prevent recursive loops

Use:

* Separate input and output buckets.
* Separate S3 prefixes.
* Event filtering.
* Metadata flags.
* Distinct source and destination queues.
* Idempotency.
* Reserved-concurrency cap.
* CloudWatch concurrency alarm.
* Budget alert.

Example:

```text
uploads/raw/*
    |
    v
Lambda
    |
    v
uploads/processed/*
```

Configure S3 notifications only for:

```text
Prefix:
raw/
```

---

# 85. Logging

Lambda automatically sends function logs to CloudWatch Logs when the execution role has the required log permissions. ([AWS Documentation][39])

Default log group:

```text
/aws/lambda/function-name
```

Use structured JSON:

```javascript
console.log(JSON.stringify({
  level: "INFO",
  service: "todo-processor",
  requestId: context.awsRequestId,
  eventId: event.eventId,
  message: "Processing todo"
}));
```

---

# 86. Important Lambda metrics

Monitor:

```text
Invocations
Errors
Duration
Throttles
ConcurrentExecutions
UnreservedConcurrentExecutions
IteratorAge
DeadLetterErrors
DestinationDeliveryFailures
AsyncEventAge
AsyncEventsDropped
ProvisionedConcurrencySpilloverInvocations
ProvisionedConcurrencyUtilization
RecursiveInvocationsDropped
```

Lambda automatically publishes invocation metrics to CloudWatch. ([AWS Documentation][40])

---

# 87. Duration monitoring

Monitor:

```text
Average
p95
p99
Maximum
```

A rising maximum near the configured timeout indicates a potential timeout incident.

Example alarm:

```text
p95 Duration > 80% of timeout
```

For a 30-second timeout:

```text
Alert threshold:
24 seconds
```

---

# 88. Throttle monitoring

A throttle means Lambda could not start an invocation because concurrency capacity was unavailable or limited.

Possible causes:

* Account concurrency exhausted.
* Reserved concurrency reached.
* Provisioned concurrency insufficient for latency expectation.
* Function scaling rate exceeded.
* Event-source maximum concurrency reached.

A high throttle count should be correlated with:

```text
ConcurrentExecutions
UnreservedConcurrentExecutions
Queue backlog
API errors
Function duration
```

---

# 89. Queue consumer dashboard

For SQS-triggered Lambda, display together:

```text
Lambda Errors
Lambda Throttles
Lambda ConcurrentExecutions
Lambda Duration
SQS Visible Messages
SQS In-flight Messages
SQS Age of Oldest Message
SQS DLQ Depth
```

Interpretation:

```text
Backlog increasing
+
Errors increasing
+
Concurrency falling
=
Function failures causing poller backoff
```

Lambda reduces SQS polling concurrency when function errors occur. ([AWS Documentation][24])

---

# 90. Distributed tracing

Enable X-Ray or OpenTelemetry tracing to understand:

```text
Trigger
Lambda initialization
Handler duration
AWS SDK calls
Database calls
Downstream APIs
```

Example:

```text
API Gateway
    |
    v
Lambda
    |
    ├── DynamoDB 20 ms
    ├── SQS 15 ms
    └── External API 900 ms
```

X-Ray tracing is integrated with Lambda, though support differs for some event-source mapping types. ([AWS Documentation][41])

---

# 91. Powertools for AWS Lambda

Powertools provides utilities for common serverless production patterns, including:

* Structured logging.
* Tracing.
* Metrics.
* Idempotency.
* Parameters and secrets.
* Batch processing.
* Event handling.
* Input validation.

Powertools is available for several major Lambda runtime languages. ([AWS Documentation][42])

Example TypeScript concepts:

```typescript
import { Logger } from "@aws-lambda-powertools/logger";
import { Metrics } from "@aws-lambda-powertools/metrics";

const logger = new Logger({
  serviceName: "todo-processor"
});

const metrics = new Metrics({
  namespace: "TodoApp",
  serviceName: "todo-processor"
});
```

---

# 92. Lambda code signing

Lambda code signing uses AWS Signer to ensure that only trusted signed ZIP packages and layers are deployed.

When code signing is attached, Lambda validates new deployments against trusted signing profiles. Existing unsigned code continues running until a new package is deployed. Container-image functions do not currently support Lambda code-signing configuration. ([AWS Documentation][43])

Use for:

* Regulated production.
* Deployment-pipeline integrity.
* Preventing unapproved manual uploads.
* Supply-chain controls.

---

# 93. Runtime maintenance

Use a currently supported runtime and plan upgrades before deprecation.

Current documentation recommends moving from Amazon Linux 2–based Lambda runtimes to Amazon Linux 2023–based runtimes where available because AL2 reached end of life in June 2026. ([AWS Documentation][44])

Do not assume AWS runtime deprecation automatically updates your application safely.

Test:

* Language version.
* Native dependencies.
* SDK behavior.
* TLS.
* Timezone data.
* Binary compatibility.
* Performance.
* Cold starts.

---

# 94. Terraform Lambda execution role

```hcl
resource "aws_iam_role" "lambda" {
  name = "production-todo-processor"

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

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

Logging policy:

```hcl
resource "aws_iam_role_policy" "lambda_logging" {
  name = "cloudwatch-logging"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]

      Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
    }]
  })
}
```

---

# 95. Terraform Lambda function

```hcl
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/production-todo-processor"
  retention_in_days = 30

  kms_key_id = aws_kms_key.logs.arn

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}

resource "aws_lambda_function" "processor" {
  function_name = "production-todo-processor"

  role    = aws_iam_role.lambda.arn
  runtime = "nodejs24.x"
  handler = "index.handler"

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  memory_size = 1024
  timeout     = 60

  architectures = [
    "arm64"
  ]

  ephemeral_storage {
    size = 1024
  }

  environment {
    variables = {
      ENVIRONMENT       = "production"
      IDEMPOTENCY_TABLE = aws_dynamodb_table.idempotency.name
      LOG_LEVEL         = "INFO"
    }
  }

  tracing_config {
    mode = "Active"
  }

  reserved_concurrent_executions = 50

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda_logging
  ]

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

The AWS Terraform provider supports Lambda function, alias and event-source mapping resources. ([Terraform Registry][45])

---

# 96. Terraform SQS event-source mapping

```hcl
resource "aws_lambda_event_source_mapping" "todo_queue" {
  event_source_arn = aws_sqs_queue.todo_processing.arn
  function_name    = aws_lambda_alias.production.arn

  batch_size                         = 10
  maximum_batching_window_in_seconds = 5

  function_response_types = [
    "ReportBatchItemFailures"
  ]

  scaling_config {
    maximum_concurrency = 40
  }

  filter_criteria {
    filter {
      pattern = jsonencode({
        body = {
          eventType = ["TodoCreated"]
        }
      })
    }
  }
}
```

Set the function timeout and queue visibility timeout together.

Example:

```text
Function timeout:
60 seconds

Recommended starting visibility timeout:
At least 360 seconds
```

---

# 97. Terraform version and alias

```hcl
resource "aws_lambda_function" "processor" {
  function_name = "production-todo-processor"

  role    = aws_iam_role.lambda.arn
  runtime = "nodejs24.x"
  handler = "index.handler"

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  publish = true
}

resource "aws_lambda_alias" "production" {
  name = "production"

  function_name    = aws_lambda_function.processor.function_name
  function_version = aws_lambda_function.processor.version

  description = "Production traffic"
}
```

Always connect production event sources to an alias or version rather than unintentionally invoking mutable `$LATEST`.

---

# 98. Terraform provisioned concurrency

```hcl
resource "aws_lambda_provisioned_concurrency_config" "production" {
  function_name                     = aws_lambda_function.processor.function_name
  qualifier                         = aws_lambda_alias.production.name
  provisioned_concurrent_executions = 10
}
```

Provisioned concurrency must target a published version or alias, and the event source must invoke that qualifier to receive the preinitialized capacity benefit. ([AWS Documentation][4])

---

# 99. Lambda CLI commands

List functions:

```bash
aws lambda list-functions \
  --region ap-south-1
```

Inspect configuration:

```bash
aws lambda get-function-configuration \
  --function-name production-todo-processor \
  --region ap-south-1
```

Invoke synchronously:

```bash
aws lambda invoke \
  --function-name production-todo-processor:production \
  --payload '{"todoId":"todo-501"}' \
  --cli-binary-format raw-in-base64-out \
  --region ap-south-1 \
  response.json
```

Invoke asynchronously:

```bash
aws lambda invoke \
  --function-name production-todo-processor:production \
  --invocation-type Event \
  --payload '{"todoId":"todo-501"}' \
  --cli-binary-format raw-in-base64-out \
  --region ap-south-1 \
  response.json
```

---

# 100. Troubleshooting: function times out

Check:

```text
Downstream API latency
Database query latency
DNS resolution
VPC routing
NAT availability
Socket timeout
SDK retries
Memory and CPU
Large input file
Deadlock
Infinite loop
```

Review CloudWatch:

```text
Duration
Max Duration
Errors
ConcurrentExecutions
Memory usage in REPORT log
Init Duration
```

Do not immediately increase the Lambda timeout without determining where time is spent.

---

# 101. Troubleshooting: function is throttled

Symptoms:

```text
TooManyRequestsException
429 response
Lambda Throttles metric
Queue backlog growth
```

Check:

1. Regional concurrency.
2. Function reserved concurrency.
3. Provisioned concurrency spillover.
4. SQS maximum concurrency.
5. Function duration.
6. Scaling-rate limits.
7. Other functions consuming unreserved concurrency.

Potential fixes:

* Request quota increase.
* Reduce duration.
* Add reserved concurrency.
* Increase safe event-source concurrency.
* Buffer with SQS.
* Protect downstream dependencies.

---

# 102. Troubleshooting: function has cold starts despite provisioned concurrency

Check:

* Invocation uses the correct alias.
* Provisioned concurrency is configured on that alias or version.
* Traffic exceeds provisioned capacity.
* Event-source mapping invokes `$LATEST` or unqualified function.
* Alias was updated but provisioned capacity is still preparing.
* New traffic is spilling into on-demand concurrency.

AWS notes that invoking a version or alias different from the one holding provisioned concurrency still results in normal cold-start behavior. ([AWS Documentation][46])

---

# 103. Troubleshooting: Lambda cannot reach RDS

Check:

```text
Correct VPC
Correct subnets
Lambda security group
RDS security group
Route table
Database hostname
DNS
Database port
NACL ephemeral ports
Credentials
Database maximum connections
```

From the function, log controlled diagnostics:

```javascript
console.log({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT
});
```

Never log passwords.

---

# 104. Troubleshooting: SQS messages continuously retry

Check:

* Function throws on one batch record.
* Partial batch response not enabled.
* Visibility timeout too short.
* Message body schema changed.
* Idempotency logic fails.
* Consumer lacks downstream permission.
* Function timeout.
* DLQ `maxReceiveCount`.
* FIFO ordering blockage.

Inspect:

```text
Lambda Errors
SQS AgeOfOldestMessage
SQS ReceiveCount
DLQ message body
CloudWatch logs
```

---

# 105. Troubleshooting: missing logs

Check:

* Execution role has log permissions.
* Function was invoked.
* Correct Region.
* Correct log group.
* Log-level filtering.
* Function failed before logging.
* Custom logging configuration.
* CloudWatch Logs KMS key policy.
* VPC endpoint if using private log delivery requirements.

Lambda’s execution role must permit CloudWatch Logs actions for normal function logging. ([AWS Documentation][47])

---

# 106. Common Lambda mistakes

## Mistake 1: Storing permanent state in global variables

Execution environments are temporary.

## Mistake 2: Creating database connections every invocation

This increases latency and database load.

## Mistake 3: No concurrency limit for a database consumer

Lambda may overwhelm the database.

## Mistake 4: Treating retries as exceptional

Retries and duplicates are normal in event-driven systems.

## Mistake 5: Processing SQS batches without partial failure handling

One poison message can reprocess every successful item.

## Mistake 6: Using `$LATEST` in production integrations

Deployments become mutable and rollback is harder.

## Mistake 7: Hard-coding secrets

Use Secrets Manager or Parameter Store.

## Mistake 8: Attaching Lambda to a VPC unnecessarily

This adds networking dependencies without benefit.

## Mistake 9: Setting a 15-minute timeout for every function

Failures remain active too long.

## Mistake 10: Enabling unlimited recursion

A loop can exhaust concurrency and create significant cost.

---

# 107. Production architecture for your TodoApp

```text
Users
  |
  v
CloudFront
  |
  v
API Gateway
  |
  v
Todo API Lambda
  |
  ├── DynamoDB
  |
  ├── EventBridge: TodoCreated
  |
  └── SQS: long-running processing
```

Background path:

```text
SQS
 |
 v
Todo Processor Lambda
 |
 ├── Idempotency table
 ├── External AI service
 ├── S3 output
 └── EventBridge: TodoProcessed
```

Operational controls:

```text
Versions and production alias
Canary deployment
Reserved concurrency
SQS maximum concurrency
Partial batch response
DLQ
Structured logging
X-Ray/OpenTelemetry
CloudWatch alarms
Secrets Manager
```

---

# 108. Production readiness checklist

```text
[ ] Function has one clear responsibility
[ ] Invocation type is documented
[ ] Events are schema validated
[ ] Business operations are idempotent
[ ] Dependencies are initialized outside handler where safe
[ ] Database connections are reused safely
[ ] Memory has been performance tested
[ ] Timeout is based on measured duration
[ ] Downstream calls have shorter timeouts
[ ] /tmp size is intentional
[ ] Permanent data is stored externally
[ ] Runtime is currently supported
[ ] Package is minimized
[ ] Layers are pinned to versions
[ ] Execution role is least privilege
[ ] Resource policy restricts invokers
[ ] Secrets are not stored in plain environment variables
[ ] Function uses multiple-AZ subnets where VPC access is needed
[ ] NAT or VPC endpoints are correctly configured
[ ] Database concurrency is protected
[ ] Reserved concurrency is configured where needed
[ ] Provisioned concurrency or SnapStart is evaluated
[ ] Production event sources use aliases
[ ] Canary deployment is configured
[ ] Async failures have destinations
[ ] SQS sources have DLQs
[ ] Partial batch response is enabled
[ ] Visibility timeout matches processing time
[ ] Stream failures have retry limits
[ ] Structured logs include request and event IDs
[ ] CloudWatch alarms cover errors, throttles and duration
[ ] Queue alarms cover age and DLQ depth
[ ] Tracing is enabled
[ ] Recursive-loop risk is tested
[ ] Code signing is evaluated
[ ] Rollback procedure is documented
```

---

# 109. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Lambda:
Serverless event-driven compute

Trigger:
AWS service or client invoking the function

Execution role:
Permissions used by function code

CloudWatch:
Function logs and metrics
```

## Solutions Architect Associate

Understand:

```text
Synchronous versus asynchronous invocation
Event-source mappings
Lambda timeout
Memory and CPU scaling
Concurrency
Reserved concurrency
Provisioned concurrency
VPC attachment
Versions and aliases
DLQs and destinations
```

## DevOps Engineer Professional

Understand:

```text
Partial batch response
Stream failure handling
Canary aliases
CodeDeploy
Concurrency protection
Idempotency
SnapStart
Powertools
Code signing
Cross-account policies
Terraform deployment
Observability and rollback
```

---

# 110. Interview questions

## Question 1: What is AWS Lambda?

**Answer:**

Lambda is an event-driven compute service that runs code and automatically manages provisioning, scaling and underlying infrastructure.

## Question 2: What is a cold start?

**Answer:**

A cold start occurs when Lambda creates a new execution environment, initializes the runtime, loads code and dependencies, and then invokes the handler.

## Question 3: What is a warm invocation?

**Answer:**

It is an invocation using an already initialized execution environment.

## Question 4: Can you rely on warm environments?

**Answer:**

No. Reuse is an optimization and is never guaranteed.

## Question 5: What is reserved concurrency?

**Answer:**

It reserves concurrent capacity exclusively for a function while also defining that function’s maximum concurrency.

## Question 6: What is provisioned concurrency?

**Answer:**

It keeps a specified number of execution environments preinitialized to reduce cold-start latency.

## Question 7: What is SnapStart?

**Answer:**

It snapshots an initialized published function version and restores execution environments from that snapshot to reduce initialization latency.

## Question 8: How does Lambda CPU allocation work?

**Answer:**

CPU capacity increases proportionally with configured function memory.

## Question 9: What is Lambda’s maximum normal execution time?

**Answer:**

Fifteen minutes for a standard Lambda function invocation.

## Question 10: What is an event-source mapping?

**Answer:**

It is a Lambda-managed poller configuration connecting a queue or stream to a Lambda function.

## Question 11: What is the difference between asynchronous invocation and SQS invocation?

**Answer:**

Asynchronous invocation uses Lambda’s internal event queue and retry policy. For SQS, Lambda polls the external SQS queue through an event-source mapping, and retries are controlled largely through queue visibility and redrive behavior.

## Question 12: What is partial batch response?

**Answer:**

It lets a function report only failed records so successfully processed records in the batch do not need to be retried.

## Question 13: Why must Lambda functions be idempotent?

**Answer:**

Because retries and duplicate event delivery can occur across asynchronous and polling integrations.

## Question 14: What is the difference between an execution role and a resource-based policy?

**Answer:**

The execution role defines what the function code may access. The resource-based policy defines who or which AWS service may invoke the function.

## Question 15: Does placing Lambda in a public subnet provide internet access?

**Answer:**

No. VPC-attached Lambda functions do not receive public IP addresses. Internet access normally requires a private subnet routed through a NAT gateway.

## Question 16: What is a Lambda alias?

**Answer:**

It is a named pointer to a published function version.

## Question 17: How can you perform a Lambda canary deployment?

**Answer:**

Publish a new version and use a weighted alias or CodeDeploy to gradually shift traffic while monitoring alarms.

## Question 18: What should be stored in `/tmp`?

**Answer:**

Temporary invocation or execution-environment files, not authoritative or durable application data.

## Question 19: How do you protect a database from Lambda scale?

**Answer:**

Use reserved concurrency, event-source maximum concurrency, connection reuse, RDS Proxy, batching and database capacity controls.

## Question 20: How would you troubleshoot repeated SQS processing?

**Answer:**

Check function errors, visibility timeout, partial batch configuration, message deletion behavior, idempotency, DLQ settings and processing duration.

---

# 111. Never-forget revision

```text
Lambda:
Serverless event-driven compute.

Handler:
Function entry point.

Event:
Input from the invoker.

Context:
Invocation metadata.

Cold start:
New environment initialization.

Warm invocation:
Reuse of initialized environment.

Provisioned concurrency:
Preinitialized environments.

Reserved concurrency:
Guaranteed capacity and maximum limit.

SnapStart:
Snapshot-based initialization acceleration.

Execution role:
What Lambda may access.

Resource policy:
Who may invoke Lambda.

Version:
Immutable function snapshot.

Alias:
Named pointer to a version.

Event-source mapping:
Lambda-managed queue or stream poller.

Partial batch response:
Retry only failed records.

Destination:
Retains async invocation result details.

Idempotency:
Repeated invocation has one logical effect.

Layer:
Versioned shared dependency package.

Extension:
Lifecycle-integrated external process.

VPC Lambda:
Function with access to private VPC resources.

`/tmp`:
Temporary local encrypted storage.
```

## One-line memory trick

```text
Initialize once.
Reuse safely.
Expect retries.
Protect dependencies.
Version everything.
Deploy through aliases.
Observe every invocation.
```

## Lesson 41 outcome

You can now design Lambda where:

```text
An API receives unpredictable traffic
    → Lambda scales with demand.

Cold-start latency matters
    → Provisioned concurrency or SnapStart is evaluated.

A queue message fails
    → Partial batch response retries only that message.

The same event arrives twice
    → Idempotency prevents duplicate business effects.

A traffic spike occurs
    → Reserved concurrency protects critical functions.

The database has limited connections
    → Concurrency limits and RDS Proxy protect it.

A release contains a bug
    → Weighted alias rolls traffic back quickly.

The function needs private RDS access
    → Hyperplane ENIs connect Lambda to private subnets.

Credentials rotate
    → Secrets Manager caching supplies current credentials.

A recursive event loop begins
    → Loop detection, alarms and concurrency limits contain it.
```

**Next lesson: Lesson 42 — Amazon API Gateway production architecture: REST APIs, HTTP APIs, WebSocket APIs, integrations, stages, throttling, quotas, authorizers, caching, custom domains, private APIs, WAF and Lambda integration.**

[1]: https://docs.aws.amazon.com/lambda/latest/dg/welcome.html?utm_source=chatgpt.com "What is AWS Lambda? - AWS Lambda"
[2]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html "Understanding the Lambda execution environment lifecycle - AWS Lambda"
[3]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html?utm_source=chatgpt.com "Understanding the Lambda execution environment lifecycle - AWS Lambda"
[4]: https://docs.aws.amazon.com/lambda/latest/dg/provisioned-concurrency.html "Configuring provisioned concurrency for a function - AWS Lambda"
[5]: https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html?utm_source=chatgpt.com "Improving startup performance with Lambda SnapStart - AWS Lambda"
[6]: https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html "Improving startup performance with Lambda SnapStart - AWS Lambda"
[7]: https://docs.aws.amazon.com/lambda/latest/dg/snapstart-runtime-hooks-python.html?utm_source=chatgpt.com "Lambda SnapStart runtime hooks for Python"
[8]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-memory.html?utm_source=chatgpt.com "Configure Lambda function memory"
[9]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-timeout.html?utm_source=chatgpt.com "Configure Lambda function timeout"
[10]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-ephemeral-storage.html "Configure ephemeral storage for Lambda functions - AWS Lambda"
[11]: https://docs.aws.amazon.com/lambda/latest/dg/images-create.html?utm_source=chatgpt.com "Create a Lambda function using a container image - AWS Lambda"
[12]: https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html "Lambda quotas - AWS Lambda"
[13]: https://docs.aws.amazon.com/lambda/latest/dg/chapter-layers.html "Managing Lambda dependencies with layers - AWS Lambda"
[14]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-extensions.html?utm_source=chatgpt.com "Augment Lambda functions using Lambda extensions - AWS Lambda"
[15]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-invocation.html?utm_source=chatgpt.com "Understanding Lambda function invocation methods - AWS Lambda"
[16]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-retries.html?utm_source=chatgpt.com "Understanding retry behavior in Lambda - AWS Lambda"
[17]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async.html?utm_source=chatgpt.com "Invoking a Lambda function asynchronously - AWS Lambda"
[18]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-error-handling.html "How Lambda handles errors and retries with asynchronous invocation - AWS Lambda"
[19]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-configuring.html?utm_source=chatgpt.com "Configuring error handling settings for Lambda asynchronous invocations - AWS Lambda"
[20]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-retain-records.html?utm_source=chatgpt.com "Capturing records of Lambda asynchronous invocations - AWS Lambda"
[21]: https://docs.aws.amazon.com/lambda/latest/api/API_CreateEventSourceMapping.html?utm_source=chatgpt.com "CreateEventSourceMapping - AWS Lambda"
[22]: https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-configure.html?utm_source=chatgpt.com "Creating and configuring an Amazon SQS event source mapping - AWS Lambda"
[23]: https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-parameters.html?utm_source=chatgpt.com "Lambda parameters for Amazon SQS event source mappings - AWS Lambda"
[24]: https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-errorhandling.html?utm_source=chatgpt.com "Handling errors for an SQS event source in Lambda - AWS Lambda"
[25]: https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html?utm_source=chatgpt.com "Best practices for working with AWS Lambda functions - AWS Lambda"
[26]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html "Understanding Lambda function scaling - AWS Lambda"
[27]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-versions.html "Manage Lambda function versions - AWS Lambda"
[28]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-aliases.html?utm_source=chatgpt.com "Create an alias for a Lambda function - AWS Lambda"
[29]: https://docs.aws.amazon.com/lambda/latest/dg/configuring-alias-routing.html?utm_source=chatgpt.com "Implement Lambda canary deployments using a weighted alias - AWS Lambda"
[30]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-permissions.html?utm_source=chatgpt.com "Managing permissions in AWS Lambda - AWS Lambda"
[31]: https://docs.aws.amazon.com/lambda/latest/dg/access-control-resource-based.html?utm_source=chatgpt.com "Viewing resource-based IAM policies in Lambda - AWS Lambda"
[32]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html?utm_source=chatgpt.com "Working with Lambda environment variables"
[33]: https://docs.aws.amazon.com/lambda/latest/dg/with-secrets-manager.html?utm_source=chatgpt.com "Use Secrets Manager secrets in Lambda functions - AWS Lambda"
[34]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html "Giving Lambda functions access to resources in an Amazon VPC - AWS Lambda"
[35]: https://docs.aws.amazon.com/lambda/latest/dg/troubleshooting-networking.html?utm_source=chatgpt.com "Troubleshoot networking issues in Lambda"
[36]: https://docs.aws.amazon.com/lambda/latest/dg/urls-invocation.html?utm_source=chatgpt.com "Invoking Lambda function URLs - AWS Lambda"
[37]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-response-streaming.html "Response streaming for Lambda functions - AWS Lambda"
[38]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-recursion.html "Use Lambda recursive loop detection to prevent infinite loops - AWS Lambda"
[39]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-monitoring.html?utm_source=chatgpt.com "Monitoring, debugging, and troubleshooting Lambda functions - AWS Lambda"
[40]: https://docs.aws.amazon.com/lambda/latest/dg/monitoring-metrics.html?utm_source=chatgpt.com "Using CloudWatch metrics with Lambda - AWS Lambda"
[41]: https://docs.aws.amazon.com/lambda/latest/dg/services-xray.html?utm_source=chatgpt.com "Visualize Lambda function invocations using AWS X-Ray - AWS Lambda"
[42]: https://docs.aws.amazon.com/lambda/latest/dg/powertools-for-lambda.html?utm_source=chatgpt.com "Powertools for AWS Lambda - AWS Lambda"
[43]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-codesigning.html?utm_source=chatgpt.com "Using code signing to verify code integrity with Lambda - AWS Lambda"
[44]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html?utm_source=chatgpt.com "Lambda runtimes"
[45]: https://registry.terraform.io/providers/-/aws/latest/docs/resources/lambda_function?utm_source=chatgpt.com "aws_lambda_function | Resources | hashicorp/aws | Terraform | Terraform Registry"
[46]: https://docs.aws.amazon.com/lambda/latest/dg/troubleshooting-invocation.html?utm_source=chatgpt.com "Troubleshoot invocation issues in Lambda - AWS Lambda"
[47]: https://docs.aws.amazon.com/lambda/latest/api/API_CreateFunction.html?utm_source=chatgpt.com "CreateFunction - AWS Lambda"
