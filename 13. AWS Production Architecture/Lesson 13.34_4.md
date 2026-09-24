# AWS Masterclass — Lesson 34 Part 4

# AWS Step Functions in Depth

## Durable Workflow Orchestration, Standard vs Express, Retries, Catch, Map, Distributed Map, Callbacks, Human Approval & Saga Compensation

We have learned three asynchronous building blocks:

```text
SQS
=
QUEUE


SNS
=
PUB/SUB FAN-OUT


EventBridge
=
EVENT ROUTING / CHOREOGRAPHY
```

Now suppose a business process has a **specific sequence**:

```text
Order
  │
  ▼
Validate
  │
  ▼
Reserve Inventory
  │
  ▼
Capture Payment
  │
  ▼
Create Shipment
  │
  ▼
Notify Customer
```

and you need to know:

```text
Which step are we on?

What succeeded?

What failed?

Should we retry?

Should we wait?

Should we compensate?

Should two tasks run in parallel?

Should a human approve something?
```

This is where:

# AWS Step Functions

becomes powerful.

Step Functions is AWS's managed workflow orchestration service. Workflows are defined as **state machines** using the Amazon States Language, and states can invoke Lambda, AWS services, HTTPS APIs, nested workflows, jobs, callbacks, branches, loops, and conditional logic. ([AWS Documentation][1])

---

# 1. Choreography vs Orchestration

From EventBridge:

```text
OrderCreated
     │
     ▼
EventBridge
     │
 ┌───┼───────────┐
 ▼   ▼           ▼
A    B           C
```

Each service reacts independently.

That is:

# Choreography

Step Functions instead gives us:

```text
                 Step Functions
                       │
                       ▼
                Validate Order
                       │
                       ▼
              Reserve Inventory
                       │
                       ▼
                Capture Payment
                       │
                       ▼
                Create Shipment
                       │
                       ▼
                     DONE
```

That is:

# Orchestration

The central workflow explicitly decides what happens next.

---

# 2. When Step Functions Is Better

Think Step Functions when the business requirement sounds like:

```text
Do A

then B

if B fails retry

if C rejects go to D

wait 2 hours

ask human for approval

run E and F in parallel

process every item

if payment succeeded
but shipping fails
refund payment
```

These are workflow semantics.

---

# 3. State Machine

A Step Functions workflow is called a:

# State Machine

Conceptually:

```text
State Machine
│
├── StartAt
│
└── States
    │
    ├── State A
    ├── State B
    ├── State C
    └── State D
```

Both Standard and Express workflows are defined using the Amazon States Language. ([AWS Documentation][2])

---

# 4. Amazon States Language — ASL

ASL is JSON-based.

Simplest example:

```json
{
  "StartAt": "Hello",
  "States": {
    "Hello": {
      "Type": "Pass",
      "Next": "Done"
    },

    "Done": {
      "Type": "Succeed"
    }
  }
}
```

Execution:

```text
Start
 │
 ▼
Hello
 │
 ▼
Done
```

---

# Part A — Standard vs Express Workflows

# 5. The First Step Functions Decision

When creating a state machine, you choose:

```text
STANDARD

or

EXPRESS
```

That workflow type is immutable after creation. ([AWS Documentation][2])

So:

```text
choose correctly
before production.
```

---

# 6. Standard Workflow

Standard Workflows are designed for:

```text
long-running workflows

durable business processes

auditable executions

human approval

jobs lasting minutes/hours/days

payment/order workflows

complex orchestration
```

A Standard execution can run for up to **one year** and Step Functions stores its execution history. AWS describes Standard execution semantics as **exactly once**, except where your ASL explicitly configures retries. ([AWS Documentation][2])

---

# 7. Express Workflow

Express is designed for:

```text
high-volume

short-running

event processing

stream transformation

microservice orchestration

very frequent executions
```

An Express workflow can run for a maximum of:

```text
5 minutes.
```

([AWS Documentation][2])

---

# 8. Important Express Nuance

There are actually two Express execution modes:

```text
Asynchronous Express

Synchronous Express
```

Their guarantees differ.

AWS currently defines:

```text
Standard
=
exactly-once workflow execution


Async Express
=
at-least-once


Sync Express
=
at-most-once
```

([AWS Documentation][2])

This is an excellent advanced interview point.

---

# 9. Why Async Express Needs Idempotency

Suppose:

```text
Express workflow
    │
    ▼
Charge Customer
```

Async Express can potentially run steps more than once.

Therefore:

```text
non-idempotent side effect
+
at-least-once execution
=
danger
```

AWS specifically positions Express for idempotent actions because of its execution semantics. ([AWS Documentation][3])

---

# 10. Standard Does Not Mean “Forget Idempotency”

AWS gives Standard an exactly-once workflow model. ([AWS Documentation][3])

But application engineers should still protect external side effects where ambiguity exists.

For example:

```text
workflow
  │
  ▼
external payment gateway
  │
  ▼
network breaks
after provider charged
before your system records result
```

No workflow engine can magically make an external system transactionally atomic with your application.

So:

```text
Step Functions semantics
+
business idempotency
```

remain complementary.

---

# 11. Standard vs Express Table

| Characteristic              | Standard          | Express                                  |
| --------------------------- | ----------------- | ---------------------------------------- |
| Maximum execution           | 1 year            | 5 minutes                                |
| Primary workload            | Durable workflows | High-volume short workloads              |
| Workflow semantics          | Exactly once      | Async: at least once; Sync: at most once |
| Full Step Functions history | Yes               | CloudWatch Logs required                 |
| `.sync` job integration     | Yes               | No                                       |
| `.waitForTaskToken`         | Yes               | No                                       |
| Distributed Map             | Yes               | No                                       |
| Human approval              | Excellent fit     | Poor fit                                 |
| Long Wait states            | Excellent fit     | Limited by 5-minute execution            |
| Pricing model               | State transitions | Executions + duration + memory           |

These differences are current AWS-defined workflow characteristics. ([AWS Documentation][2])

---

# 12. Simple Selection Rule

```text
Does workflow need to run
> 5 minutes?
      │
     YES
      │
      ▼
   STANDARD


Need human callback?
      │
     YES
      ▼
   STANDARD


Need .sync job integration?
      │
     YES
      ▼
   STANDARD


Very high-volume
short idempotent workflow?
      │
     YES
      ▼
   EXPRESS
```

---

# Part B — The Eight Core State Types

Step Functions currently defines these major ASL state types:

```text
Task

Choice

Pass

Wait

Parallel

Map

Succeed

Fail
```

([AWS Documentation][4])

You should know every one.

---

# 13. Task State

A:

# Task

represents actual work.

```text
Task
 │
 ├── Lambda
 ├── DynamoDB
 ├── ECS
 ├── Batch
 ├── SNS
 ├── SQS
 ├── Step Functions
 ├── HTTPS API
 └── other supported service
```

AWS defines a Task as a single unit of work performed by Lambda, an integrated AWS service, an activity, or an HTTPS API. ([AWS Documentation][5])

---

# 14. Lambda Task

Example:

```json
{
  "ValidateOrder": {
    "Type": "Task",
    "Resource": "arn:aws:states:::lambda:invoke",
    "Arguments": {
      "FunctionName": "validate-order",
      "Payload": "{% $states.input %}"
    },
    "Next": "ReserveInventory"
  }
}
```

Step Functions provides optimized Lambda service integrations as part of its AWS service integration model. ([AWS Documentation][6])

---

# 15. Choice State

Choice provides:

```text
IF / ELSE
```

workflow logic.

Example:

```text
            Payment Result
                  │
            ┌─────┴─────┐
            ▼           ▼
        APPROVED      DECLINED
            │           │
            ▼           ▼
         Ship        Cancel
```

Choice states provide conditional branches in state-machine execution. ([AWS Documentation][7])

---

# 16. Choice Example

```json
{
  "CheckPayment": {
    "Type": "Choice",

    "Choices": [
      {
        "Variable": "$.payment.status",
        "StringEquals": "APPROVED",
        "Next": "CreateShipment"
      }
    ],

    "Default": "PaymentRejected"
  }
}
```

Think:

```text
Choices
=
conditions

Default
=
else
```

---

# 17. Pass State

Pass performs no external work.

It can be used to:

```text
reshape data

assign values

inject test values

create placeholders

simplify workflow logic
```

A Pass state passes input to output without performing work. ([AWS Documentation][8])

---

# 18. Wait State

Wait pauses workflow progress.

Conceptually:

```text
Send Reminder
     │
     ▼
Wait 24 hours
     │
     ▼
Check Response
```

Excellent for:

```text
cooling periods

delayed retries

approval deadlines

business timers

subscription grace periods
```

Because Standard workflows can exist for up to one year, waiting does not require a server or Lambda process to remain running for the entire duration. ([AWS Documentation][2])

---

# 19. Do NOT Make Lambda Sleep

Bad:

```javascript
await sleep(86400000);
```

inside Lambda.

You would be attempting to hold compute for a business timer, and Lambda itself cannot run longer than its own invocation limit.

Better:

```text
Lambda
  │
  ▼
Wait State
  │
24 hours
  │
  ▼
next state
```

---

# 20. Succeed State

A:

```json
{
  "Type": "Succeed"
}
```

terminates the workflow or branch successfully. ([AWS Documentation][9])

---

# 21. Fail State

A:

```json
{
  "Type": "Fail",
  "Error": "PaymentRejected",
  "Cause": "Payment provider declined transaction"
}
```

terminates execution as failed unless handled in an enclosing error-handling context. ([AWS Documentation][10])

---

# 22. Parallel State

Suppose after order creation you need:

```text
                     Order Created

                         │
              ┌──────────┴──────────┐
              ▼                     ▼
         Create Invoice        Send Email
              │                     │
              └──────────┬──────────┘
                         ▼
                      Continue
```

Parallel runs branches concurrently and waits for all branches to finish before continuing. ([AWS Documentation][11])

---

# 23. Parallel Example

```json
{
  "DoThingsInParallel": {
    "Type": "Parallel",

    "Branches": [
      {
        "StartAt": "CreateInvoice",
        "States": {
          "CreateInvoice": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "End": true
          }
        }
      },

      {
        "StartAt": "SendNotification",
        "States": {
          "SendNotification": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "End": true
          }
        }
      }
    ],

    "Next": "Continue"
  }
}
```

---

# 24. Parallel Failure Behavior

If one Parallel branch has an unhandled failure, the Parallel state fails and Step Functions stops the branches it controls. Already-running Lambda functions themselves cannot be forcibly stopped just because their Parallel branch was canceled. ([AWS Documentation][11])

That is a subtle but important production detail.

---

# Part C — Map State

# 25. Map

Map means:

```text
for each item
run this workflow.
```

Example input:

```json
{
  "orders": [
    {"id": "A"},
    {"id": "B"},
    {"id": "C"}
  ]
}
```

Map:

```text
A → process
B → process
C → process
```

potentially in parallel.

Step Functions supports **Inline Map** and **Distributed Map** processing modes. ([AWS Documentation][12])

---

# 26. Inline Map

Inline Map:

```text
Parent workflow
     │
     ▼
Map
 ├── item 1
 ├── item 2
 ├── item 3
 └── item ...
```

Each iteration exists inside the parent workflow execution history.

Current Inline Map limit:

```text
up to 40 concurrent iterations.
```

([AWS Documentation][12])

---

# 27. Inline Map Constraints

Inline mode is generally appropriate when:

```text
input dataset ≤ 256 KiB

execution history remains
under 25,000 events

concurrency ≤ 40
```

AWS specifically recommends Distributed Map when those boundaries become problematic. ([AWS Documentation][13])

---

# 28. Distributed Map

Now imagine:

```text
10 million files
```

in S3.

You don't want:

```text
one giant parent execution
containing millions of events.
```

Distributed Map executes iterations as:

```text
CHILD WORKFLOW EXECUTIONS
```

rather than stuffing everything into one execution history. ([AWS Documentation][13])

---

# 29. Distributed Map Architecture

```text
                   Parent Workflow

                         │
                         ▼
                   Distributed Map
                         │
       ┌─────────────────┼─────────────────┐
       ▼                 ▼                 ▼
 Child Workflow 1   Child Workflow 2   Child Workflow 3
       │                 │                 │
       ▼                 ▼                 ▼
    item A             item B            item C
```

Each child gets its own execution history. ([AWS Documentation][12])

---

# 30. Distributed Map Concurrency

Current Distributed Map supports up to:

```text
10,000 parallel
child workflow executions
```

for one Map Run. ([AWS Documentation][14])

That is dramatically different from Inline Map's 40 concurrent iterations.

---

# 31. Distributed Map Data Sources

Distributed Map can process datasets such as:

```text
JSON arrays

large CSV files

S3 object lists

large datasets stored in S3
```

without requiring all data to fit in the parent's 256-KiB payload. ([AWS Documentation][12])

---

# 32. Map Run

When Distributed Map runs, Step Functions creates a:

# Map Run

resource.

It tracks:

```text
child executions

success count

failure count

timeout count

result writing

redrive status
```

You can inspect it from the Step Functions console or APIs such as `DescribeMapRun`. ([AWS Documentation][15])

---

# 33. Tolerated Failure Percentage

Imagine processing:

```text
1,000,000 images
```

and:

```text
12 malformed images
```

You may not want the entire billion-scale pipeline to fail for a tiny percentage of bad items.

Distributed Map allows:

```text
ToleratedFailurePercentage
```

or a tolerated failure count. The Map Run fails once the configured threshold is exceeded. ([AWS Documentation][13])

---

# 34. Example

```text
1,000 files

tolerance:
1%

allowed failures:
up to approximately 10
```

If failed/timed-out items exceed the configured threshold, Step Functions returns:

```text
States.ExceedToleratedFailureThreshold
```

([AWS Documentation][13])

---

# 35. ResultWriter

With large Distributed Maps you often don't want enormous child outputs returned into the parent state.

Instead:

```text
child results
     │
     ▼
ResultWriter
     │
     ▼
S3
```

Step Functions tracks how many child outputs were successfully written by `ResultWriter`. ([AWS Documentation][16])

---

# Part D — Service Integration Patterns

Step Functions service integrations have three major patterns:

```text
1. Request Response

2. Run a Job (.sync)

3. Wait for Callback
   (.waitForTaskToken)
```

([AWS Documentation][17])

These are essential.

---

# 36. Request Response

This is the default.

```text
Step Functions
      │
      ▼
Call AWS API
      │
      ▼
API responds
      │
      ▼
next state
```

Example:

```text
DynamoDB PutItem
```

Once the API call returns:

```text
workflow continues.
```

Both Standard and Express workflows support Request Response integrations. ([AWS Documentation][1])

---

# 37. Request Response Does NOT Mean Job Completion

Imagine:

```text
Start long-running batch job
```

The service's API may return:

```text
Job accepted
```

immediately.

Normal Request Response means:

```text
Step Functions continues
after API acceptance
```

not:

```text
after actual 3-hour job finishes.
```

---

# 38. `.sync` — Run a Job

For selected integrated services:

```text
Step Functions
      │
      ▼
start job
      │
      ▼
WAIT
      │
      ▼
job completes
      │
      ▼
next state
```

Use resource suffix:

```text
.sync
```

AWS documents `.sync` for integrations such as Batch and ECS where Step Functions can wait for the downstream job to finish. ([AWS Documentation][18])

---

# 39. ECS Example

Instead of:

```text
Lambda
  │
  ▼
start Fargate
  │
  ▼
poll ECS repeatedly
  │
  ▼
wait
```

use:

```text
Step Functions
     │
     ▼
ecs:runTask.sync
     │
     ▼
Fargate
     │
   complete
     │
     ▼
next state
```

Step Functions provides ECS/Fargate optimized integrations for running tasks and waiting on them. ([AWS Documentation][19])

---

# 40. Express Does Not Support `.sync`

This is an important exam trap.

```text
Standard
→ .sync supported


Express
→ .sync NOT supported
```

([AWS Documentation][2])

---

# Part E — Callback with Task Token

# 41. What If Step Functions Cannot Know When Work Is Done?

Imagine:

```text
Step Functions
     │
     ▼
Send request
to external worker
     │
     ▼
wait...

Worker completes
3 hours later
```

Polling would be wasteful.

Instead use:

# Task Token Callback

---

# 42. Callback Architecture

```text
Step Functions
      │
      ▼
Generate task token
      │
      ▼
Send token + task
      │
      ▼
External worker
      │
  performs work
      │
      ▼
SendTaskSuccess(token)
      │
      ▼
Step Functions resumes
```

The `.waitForTaskToken` pattern pauses the workflow until the token is returned through the Step Functions callback APIs. ([AWS Documentation][18])

---

# 43. SQS Callback Pattern

A beautiful architecture:

```text
Step Functions
      │
      ▼
SQS SendMessage.waitForTaskToken
      │
      ▼
Queue
      │
      ▼
External Worker
      │
      ▼
finish task
      │
      ▼
SendTaskSuccess
      │
      ▼
workflow resumes
```

AWS provides an optimized SQS integration specifically supporting this callback model. ([AWS Documentation][20])

---

# 44. Example

```json
{
  "WaitForExternalWorker": {
    "Type": "Task",

    "Resource":
      "arn:aws:states:::sqs:sendMessage.waitForTaskToken",

    "Arguments": {
      "QueueUrl": "QUEUE_URL",

      "MessageBody": {
        "order": "{% $states.input %}",
        "taskToken": "{% $states.context.Task.Token %}"
      }
    },

    "Next": "ProcessResult"
  }
}
```

This follows AWS's documented SQS callback integration shape. ([AWS Documentation][20])

---

# 45. Human Approval

The same pattern is perfect for:

```text
expense approval

loan approval

security exception approval

production deployment approval

manual fraud review
```

Architecture:

```text
Workflow
  │
  ▼
Generate Token
  │
  ▼
Approval system
  │
  ▼
Human reviews
  │
 ┌┴──────┐
 ▼       ▼
Approve Reject
 │       │
 ▼       ▼
SendTaskSuccess /
SendTaskFailure
```

Callback tasks can pause a Standard workflow for external processes or human approval up to the workflow's maximum lifetime. ([AWS Documentation][18])

---

# 46. Task Token Security

Task tokens are powerful.

Anyone holding a valid token may be able to complete the corresponding task if authorized to call the callback API.

Therefore:

```text
do not log task token
publicly

do not expose it
in URLs unnecessarily

protect it like
a capability credential.
```

AWS also requires callbacks using task tokens to come from principals in the **same AWS account** as the workflow. ([AWS Documentation][18])

---

# 47. Express Does Not Support Callbacks

Another certification rule:

```text
Standard
→ waitForTaskToken


Express
→ NOT supported
```

([AWS Documentation][2])

So:

```text
human approval
=
almost always Standard.
```

---

# Part F — Retry

# 48. Failure Happens

A Task may fail because:

```text
Lambda throttled

API temporarily unavailable

network fault

DynamoDB throttling

ECS service problem

application exception
```

You should not immediately fail every workflow.

Use:

# Retry

---

# 49. Retry Example

```json
{
  "Retry": [
    {
      "ErrorEquals": [
        "States.TaskFailed"
      ],

      "IntervalSeconds": 2,

      "MaxAttempts": 3,

      "BackoffRate": 2
    }
  ]
}
```

`Task`, `Parallel`, and `Map` states support retry policies. ([AWS Documentation][21])

---

# 50. Exponential Backoff

Given:

```text
IntervalSeconds = 2

BackoffRate = 2
```

retry timing becomes roughly:

```text
2 sec

4 sec

8 sec
```

before further retries, subject to retry configuration.

Step Functions applies `BackoffRate` to increase retry delays. ([AWS Documentation][21])

---

# 51. Why Backoff?

Without it:

```text
Database overload
      │
      ▼
1000 workflows fail
      │
      ▼
1000 retries instantly
      │
      ▼
database even more overloaded
```

This is a:

```text
retry storm.
```

Exponential backoff helps reduce immediate repeated pressure.

---

# 52. `MaxDelaySeconds`

Suppose exponential backoff becomes:

```text
2

4

8

16

32

64

128
...
```

You may want to cap it.

Use:

```json
"MaxDelaySeconds": 30
```

Step Functions supports limiting the maximum retry delay using `MaxDelaySeconds`. ([AWS Documentation][21])

---

# 53. Retry Jitter

If 1000 workflows all fail simultaneously:

```text
retry after 2 sec
```

means:

```text
1000 retry again
at nearly same instant.
```

Use:

```json
"JitterStrategy": "FULL"
```

to randomize retry delays and spread the load. ([AWS Documentation][21])

This is excellent production behavior.

---

# 54. Production Retry Example

```json
{
  "Retry": [
    {
      "ErrorEquals": [
        "Lambda.ServiceException",
        "Lambda.SdkClientException",
        "Lambda.TooManyRequestsException"
      ],

      "IntervalSeconds": 2,
      "MaxAttempts": 5,
      "BackoffRate": 2,
      "MaxDelaySeconds": 30,
      "JitterStrategy": "FULL"
    }
  ]
}
```

AWS specifically recommends handling transient Lambda service exceptions and documents Lambda throttling as `Lambda.TooManyRequestsException`. ([AWS Documentation][21])

---

# 55. Don't Retry Everything Blindly

Suppose:

```text
PaymentDeclined
```

is a business error.

Retrying:

```text
10 times
```

is probably useless.

But:

```text
PaymentProviderTimeout
```

may deserve retries.

Classify:

```text
TRANSIENT
→ Retry


PERMANENT BUSINESS ERROR
→ Catch
```

---

# Part G — Catch

# 56. Catch Means “Fallback”

Retry says:

```text
try same state again.
```

Catch says:

```text
if failure remains,
go somewhere else.
```

`Task`, `Map`, and `Parallel` states support Catch handlers. ([AWS Documentation][21])

---

# 57. Retry Before Catch

If a state contains both:

```text
Retry

and

Catch
```

Step Functions first exhausts the matching retry policy. If retries do not resolve the error, the matching Catch transition is taken. ([AWS Documentation][22])

Mental model:

```text
Task fails
   │
   ▼
Retry?
   │
  YES
   │
   ▼
retry attempts
   │
still fails
   │
   ▼
Catch?
   │
  YES
   │
   ▼
fallback
```

---

# 58. Catch Example

```json
{
  "CapturePayment": {
    "Type": "Task",

    "Resource":
      "arn:aws:states:::lambda:invoke",

    "Retry": [
      {
        "ErrorEquals": [
          "PaymentProviderTimeout"
        ],

        "IntervalSeconds": 2,
        "MaxAttempts": 3,
        "BackoffRate": 2
      }
    ],

    "Catch": [
      {
        "ErrorEquals": [
          "PaymentDeclined"
        ],

        "Next": "ReleaseInventory"
      },

      {
        "ErrorEquals": [
          "States.ALL"
        ],

        "Next": "ManualReview"
      }
    ],

    "Next": "CreateShipment"
  }
}
```

---

# 59. `States.ALL`

```text
States.ALL
```

acts as the broad wildcard in Retry/Catch matching, but it must appear alone and last in the relevant matching array; importantly, it does not catch every terminal/runtime error category automatically. ([AWS Documentation][21])

So:

```text
States.ALL
≠
magical catch literally anything.
```

---

# 60. Important Errors

Know these:

```text
States.Timeout

States.TaskFailed

States.DataLimitExceeded

States.Runtime

States.HeartbeatTimeout

States.Permissions

States.ExceedToleratedFailureThreshold
```

Step Functions defines built-in errors with the `States.` prefix. ([AWS Documentation][21])

---

# 61. `States.Timeout`

Occurs when a Task exceeds its configured timeout or misses a configured heartbeat window; workflow-level timeout can also produce `States.Timeout`. ([AWS Documentation][21])

---

# 62. `States.TaskFailed`

Acts as a broad match for Task failures except `States.Timeout`. ([AWS Documentation][21])

This is often more appropriate than:

```text
States.ALL
```

when you want normal Task failures but want timeout handling separately.

---

# 63. `States.Runtime`

Often indicates workflow-data-processing problems such as trying to apply a JSON path to invalid/null data.

AWS says:

```text
States.Runtime
```

is not retriable and is not caught by `States.ALL`. ([AWS Documentation][21])

This usually means:

```text
your workflow definition/data contract
is wrong.
```

---

# 64. `States.DataLimitExceeded`

Step Functions has a workflow payload boundary of:

```text
256 KiB
```

for Task input/result data. Oversized state input/output can produce `States.DataLimitExceeded`. ([AWS Documentation][20])

---

# 65. Do Not Pass Large Data Through Workflow State

Bad:

```text
Step Functions state
contains:
200 MB CSV
```

Instead:

```text
S3
 │
 ▼
object
```

then workflow passes:

```json
{
  "bucket": "data-bucket",
  "key": "large.csv"
}
```

This avoids Step Functions payload growth.

---

# Part H — Data Flow

# 66. State Input and Output

Every state receives:

```text
INPUT
```

and normally produces:

```text
OUTPUT.
```

Conceptually:

```text
State A output
     │
     ▼
State B input
     │
     ▼
State B output
```

Modern Step Functions supports both traditional JSONPath data manipulation and newer JSONata/variables capabilities. ([AWS Documentation][23])

---

# 67. Traditional JSONPath Pipeline

For JSONPath workflows, remember this order:

```text
InputPath
   │
   ▼
Parameters
   │
   ▼
Task
   │
   ▼
ResultSelector
   │
   ▼
ResultPath
   │
   ▼
OutputPath
```

AWS documents this processing order for state inputs/results. ([AWS Documentation][4])

This causes many production bugs.

---

# 68. InputPath

Input:

```json
{
  "order": {
    "id": "O-1",
    "total": 500
  },

  "user": {
    "id": "U-1"
  }
}
```

```json
"InputPath": "$.order"
```

Task receives:

```json
{
  "id": "O-1",
  "total": 500
}
```

---

# 69. Parameters

Parameters lets you construct what is passed to an integrated service.

Example concept:

```json
"Parameters": {
  "orderId.$": "$.order.id",
  "environment": "production"
}
```

---

# 70. ResultPath

Task result:

```json
{
  "approved": true
}
```

With:

```json
"ResultPath": "$.payment"
```

original input can become:

```json
{
  "order": {...},
  "payment": {
    "approved": true
  }
}
```

instead of completely replacing state input.

---

# 71. OutputPath

Finally:

```json
"OutputPath": "$.payment"
```

could send only:

```json
{
  "approved": true
}
```

to the next state.

---

# Part I — JSONata and Workflow Variables

# 72. Modern Step Functions Data Processing

A significant newer Step Functions capability is:

```text
workflow variables
+
JSONata
```

These simplify passing and transforming data without long chains of `InputPath`, `Parameters`, `ResultSelector`, `ResultPath`, and `OutputPath`. ([AWS Documentation][24])

---

# 73. JSONata State Variables

Step Functions exposes contextual values such as:

```text
$states.input

$states.result

$states.errorOutput

$states.context
```

where supported. ([AWS Documentation][25])

---

# 74. Example

Conceptually:

```json
"Assign": {
  "orderId":
    "{% $states.input.order.id %}"
}
```

You can reuse:

```text
$orderId
```

later rather than preserving huge nested payloads purely to carry one field across ten states.

Workflow variables are available in later compatible scopes, whereas a state's output naturally flows only to the next state. ([AWS Documentation][24])

---

# 75. Context Object

Useful information includes execution metadata.

JSONata:

```text
$states.context.Execution.Id
```

JSONPath:

```text
$$.Execution.Id
```

The Context object exposes execution/state-machine information to workflows. ([AWS Documentation][26])

This is excellent for:

```text
correlation IDs

audit logging

idempotency keys

trace metadata
```

---

# Part J — Timeouts and Heartbeats

# 76. Task Timeout

A Task can define:

```json
"TimeoutSeconds": 300
```

Meaning:

```text
If Task takes > 5 min
→ States.Timeout
```

([AWS Documentation][21])

This prevents workflows from waiting indefinitely on broken work.

---

# 77. Heartbeat

For long-running workers:

```text
Task starts
   │
   ▼
worker
   │
heartbeat
   │
heartbeat
   │
heartbeat
```

If heartbeats stop beyond:

```text
HeartbeatSeconds
```

Step Functions can produce:

```text
States.HeartbeatTimeout
```

([AWS Documentation][21])

---

# 78. Why Heartbeats Matter

Imagine worker:

```text
job expected:
3 hours
```

You don't want:

```text
workflow waits 3 hours
to discover worker died
at minute 2.
```

Heartbeat:

```text
every 30 sec

missing > allowed period
→ fail early
```

---

# Part K — Nested Workflows

# 79. Workflows Should Be Modular

Bad:

```text
one state machine
with
700 states
```

Better:

```text
Order Workflow
    │
    ├── Payment Workflow
    ├── Fulfillment Workflow
    └── Notification Workflow
```

Step Functions can invoke another Step Functions state machine as a service integration, enabling reusable nested workflows. ([AWS Documentation][27])

---

# 80. Why Nested Workflows?

Benefits:

```text
reuse

separation of responsibility

simpler visual graphs

independent ownership

easier testing

smaller execution histories
```

AWS specifically recommends nested workflows to reduce complexity and reuse common processes. ([AWS Documentation][27])

---

# Part L — Saga Pattern

# 81. Distributed Transaction Problem

Suppose:

```text
1. Reserve inventory  ✓

2. Capture payment    ✓

3. Create shipment    ✗
```

You cannot simply:

```text
ROLLBACK DATABASE
```

because these operations may live in different systems.

This is where:

# Saga

becomes useful.

---

# 82. Saga Mental Model

Forward actions:

```text
Reserve Inventory
       │
       ▼
Capture Payment
       │
       ▼
Create Shipment
```

Compensating actions:

```text
Shipment fails
       │
       ▼
Refund Payment
       │
       ▼
Release Inventory
```

That is not a traditional database rollback.

It is:

```text
business compensation.
```

---

# 83. Step Functions Saga

```text
                      Start
                        │
                        ▼
                Reserve Inventory
                        │
                        ▼
                  Capture Payment
                        │
                        ▼
                 Create Shipment
                        │
               ┌────────┴─────────┐
               ▼                  ▼
            success             failure
               │                  │
               ▼                  ▼
              Done          Refund Payment
                                  │
                                  ▼
                           Release Inventory
                                  │
                                  ▼
                                Fail
```

Retry/Catch and explicit compensating Tasks make Step Functions a good orchestration engine for Saga workflows. ([AWS Documentation][22])

---

# 84. Compensation Is Not Inverse Code

Example:

```text
CapturePayment
```

compensation may be:

```text
RefundPayment
```

not:

```text
reverse database row.
```

Likewise:

```text
ShipOrder
```

may not have a perfect automatic inverse once the courier physically picked up the parcel.

Saga requires business semantics.

---

# 85. Compensation Must Also Be Idempotent

Suppose:

```text
RefundPayment
```

is retried.

If compensation is not idempotent:

```text
₹5000 refund
+
₹5000 refund again
```

could become a new incident.

So:

```text
forward action
+
compensation
```

should both be designed safely.

---

# Part M — Human Approval Workflow

# 86. Example

Expense:

```text
₹50,000
```

requires manager approval.

```text
Submit Expense
     │
     ▼
Amount > ₹10,000?
     │
    YES
     │
     ▼
Send Approval Request
with Task Token
     │
     ▼
WAIT
     │
     ▼
Manager
  │       │
approve reject
  │       │
  ▼       ▼
Pay     Reject
```

Callback tokens are specifically designed for workflows that must pause for an external decision or process. ([AWS Documentation][18])

---

# 87. Approval Timeout

Never wait forever.

Use:

```text
Task timeout

or

workflow timeout
```

to define:

```text
approval expires after 48 hours.
```

Then Catch:

```text
States.Timeout
      │
      ▼
Escalate / Reject
```

Timeout errors are supported in Step Functions error handling. ([AWS Documentation][21])

---

# Part N — ECS / Fargate Jobs

# 88. Why Not Put Every Workload in Lambda?

Suppose a task needs:

```text
20 minutes

large binaries

special Linux packages

4 vCPU

large memory
```

Lambda may not be the right execution engine.

Use:

```text
Step Functions
      │
      ▼
ECS/Fargate
```

Step Functions supports ECS/Fargate service integrations including waiting for jobs or using task-token callbacks. ([AWS Documentation][19])

---

# 89. Architecture

```text
Workflow
   │
   ▼
ecs:runTask.sync
   │
   ▼
Fargate Task
   │
   ▼
20-minute processing
   │
   ▼
exit 0
   │
   ▼
Workflow continues
```

Step Functions coordinates.

Fargate computes.

---

# Part O — SQS Integration

# 90. Direct SQS Integration

Sometimes this:

```text
Step Functions
      │
      ▼
Lambda
      │
      ▼
SQS SendMessage
```

is unnecessary.

Use:

```text
Step Functions
      │
      ▼
SQS SendMessage
```

directly.

Step Functions has an optimized `sqs:sendMessage` integration. ([AWS Documentation][20])

---

# 91. Example

```json
{
  "SendToQueue": {
    "Type": "Task",

    "Resource":
      "arn:aws:states:::sqs:sendMessage",

    "Arguments": {
      "QueueUrl":
        "https://sqs.ap-south-1.amazonaws.com/123456789012/orders",

      "MessageBody":
        "{% $states.input %}"
    },

    "End": true
  }
}
```

This avoids glue Lambda.

---

# Part P — Step Functions vs Lambda Glue Code

# 92. Bad Orchestrator Lambda

```javascript
await validate();

await retryThreeTimes(reserveInventory);

if (paymentFailed) {
  await releaseInventory();
}

await Promise.all([
  createInvoice(),
  sendEmail()
]);

await sleepForApproval();
```

Problems:

```text
custom retry logic

custom state management

custom failure tracking

custom sleep handling

custom visual debugging

custom recovery
```

---

# 93. Better Separation

```text
Step Functions
=
workflow logic


Lambda
=
business computation
```

Example:

```text
Step Functions:
"retry payment"


Lambda:
"call payment provider"
```

Do not place orchestration inside Lambda if Step Functions can express it natively.

---

# Part Q — Redrive

# 94. Workflow Failed at State 17

Historically you might:

```text
restart entire workflow
```

which could repeat 16 successful operations.

Step Functions supports:

# Redrive

for eligible failed Standard executions, allowing execution to resume from an unsuccessful state rather than beginning everything again. ([AWS Documentation][28])

---

# 95. Redrive Eligibility

Current major conditions include:

```text
execution did not succeed

Standard execution

within redrive window

history has capacity
to append redrive events
```

The current redrive eligibility period is **14 days** after completion for qualifying Standard executions. ([AWS Documentation][29])

---

# 96. Redrive Example

Original:

```text
Validate          ✓

Reserve           ✓

Payment           ✓

Shipment          ✗
```

Redrive:

```text
Shipment
   │
   ▼
retry from failed state
```

instead of:

```text
Validate again

Reserve again

Payment again
```

This is extremely valuable operationally.

---

# 97. Distributed Map Redrive

Distributed Map also supports redrive behavior.

For qualifying failed child executions, the parent Map Run can restart failed work rather than rerun everything. Standard child workflows may resume from failed states; Express children are started again as new executions. ([AWS Documentation][30])

---

# Part R — Execution History

# 98. Standard History

Standard workflows retain execution details inside Step Functions and support APIs such as:

```text
DescribeExecution

GetExecutionHistory

ListExecutions
```

([AWS Documentation][31])

This makes Standard excellent for:

```text
financial workflow audit

incident diagnosis

business process tracing
```

---

# 99. Express History

Express does **not** persist execution history inside Step Functions the same way Standard does.

To inspect Express execution history, enable:

```text
CloudWatch Logs.
```

([AWS Documentation][32])

This is important before putting Express into production.

---

# 100. Log Delivery Nuance

AWS states CloudWatch Logs delivery is best effort.

If your application requires guaranteed workflow-history retention for Express, AWS recommends storing required state/audit information separately or using Standard workflows. ([AWS Documentation][32])

---

# Part S — X-Ray and Observability

# 101. Step Functions Observability

Use:

```text
Execution History

CloudWatch Metrics

CloudWatch Logs

X-Ray

EventBridge
```

for different layers of visibility. AWS provides CloudWatch, X-Ray, and event-integration mechanisms for workflow monitoring. ([AWS Documentation][33])

---

# 102. X-Ray

Step Functions can send workflow tracing information into X-Ray when tracing is enabled and supported by the Region/integrated services. ([AWS Documentation][34])

Architecture:

```text
API Gateway
    │
    ▼
Step Functions
    │
 ┌──┼────────┐
 ▼  ▼        ▼
Lambda ECS  DynamoDB
```

X-Ray helps correlate latency through this workflow path.

---

# 103. Important Operational Metrics

Watch metrics around:

```text
ExecutionsStarted

ExecutionsSucceeded

ExecutionsFailed

ExecutionsTimedOut

ExecutionsAborted

ExecutionTime

ExecutionThrottled
```

depending on workflow type and operational concern.

For Standard workflows, Step Functions uses token-bucket state-transition quotas and reports throttled state transitions through `ExecutionThrottled`. ([AWS Documentation][14])

---

# Part T — Quotas

# 104. Execution History Limit

A Standard workflow execution has:

```text
25,000 execution-history events
```

as a key limit. ([AWS Documentation][35])

If you have enormous loops:

```text
Map
Map
Map
Map
```

you can hit this boundary.

---

# 105. Continue-as-New Pattern

For very long workflows:

```text
workflow reaches
~large history
     │
     ▼
start new execution
     │
     ▼
continue processing
```

AWS documents this pattern specifically for avoiding the Standard workflow history limit. ([AWS Documentation][35])

Distributed Map also helps when high iteration counts would otherwise inflate the parent's history. ([AWS Documentation][12])

---

# 106. Open Executions

The current Standard quota is:

```text
1,000,000 open executions
per account per Region
```

and this particular limit does not apply to Express. ([AWS Documentation][36])

Again:

```text
serverless
≠
no quotas.
```

---

# 107. Mumbai Standard Transition Quota

For Standard workflows in Regions outside the three specially listed high-default regions, the current documented state-transition token bucket is:

```text
800 bucket

800 transitions/sec refill
```

and `ap-south-1` falls into that “all other Regions” category. ([AWS Documentation][14])

Do not treat this as a forever hardcoded architecture assumption—Step Functions quotas can change and some are adjustable.

---

# 108. Mumbai StartExecution Default

For Standard `StartExecution` outside AWS's three higher-default Regions, current documented defaults are:

```text
bucket:
800

refill:
150/sec
```

Express currently has a much larger documented `StartExecution` default. ([AWS Documentation][14])

This matters in high-volume orchestration designs.

---

# Part U — Step Functions Versions and Aliases

# 109. Workflow Deployment Needs Versioning Too

Just like Lambda:

```text
do not treat
mutable latest definition
as the only production identity.
```

Step Functions supports:

```text
versions

aliases
```

for controlled state-machine deployment. The CLI supports publishing immutable versions and invoking them directly or through aliases. ([AWS Documentation][37])

---

# 110. Production Model

```text
State Machine

Version 41
Version 42
Version 43

      │
      ▼
Alias: PROD
      │
      ▼
Version 42
```

This creates a more controlled production workflow target.

---

# Part V — Terraform

# 111. Terraform Resource

The current HashiCorp AWS provider uses:

```text
aws_sfn_state_machine
```

for Step Functions state machines. ([Terraform Registry][38])

---

# 112. IAM Role

```hcl
resource "aws_iam_role" "step_functions" {
  name = "order-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "states.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
```

The workflow execution role should have only the service permissions required by states in the workflow.

---

# 113. State Machine Terraform

```hcl
resource "aws_sfn_state_machine" "order" {
  name = "order-workflow"

  role_arn = aws_iam_role.step_functions.arn

  type = "STANDARD"

  definition = jsonencode({
    Comment = "Order processing workflow"

    StartAt = "Validate"

    States = {
      Validate = {
        Type = "Task"

        Resource =
          "arn:aws:states:::lambda:invoke"

        Arguments = {
          FunctionName =
            aws_lambda_function.validate.arn

          Payload = "{% $states.input %}"
        }

        Next = "ReserveInventory"
      }

      ReserveInventory = {
        Type = "Task"

        Resource =
          "arn:aws:states:::lambda:invoke"

        Arguments = {
          FunctionName =
            aws_lambda_function.reserve.arn

          Payload = "{% $states.input %}"
        }

        Next = "CapturePayment"
      }

      CapturePayment = {
        Type = "Task"

        Resource =
          "arn:aws:states:::lambda:invoke"

        Arguments = {
          FunctionName =
            aws_lambda_function.payment.arn

          Payload = "{% $states.input %}"
        }

        Next = "Done"
      }

      Done = {
        Type = "Succeed"
      }
    }
  })
}
```

`aws_sfn_state_machine` manages the state-machine definition and execution-role relationship in Terraform. ([Terraform Registry][38])

---

# Part W — Full Production Order Workflow

# 114. Requirement

We want:

```text
1. Validate order

2. Reserve inventory

3. Capture payment

4. Fraud check

5. Create shipment

6. In parallel:
   - invoice
   - email
   - analytics

7. If shipment fails:
   refund payment

8. If payment fails:
   release inventory

9. High-value orders:
   manual approval
```

---

# 115. Architecture

```text
                          START
                            │
                            ▼
                     Validate Order
                            │
                      ┌─────┴─────┐
                      ▼           ▼
                    valid       invalid
                      │           │
                      ▼           ▼
                Reserve Stock    FAIL
                      │
                      ▼
                Capture Payment
                      │
              ┌───────┴────────┐
              ▼                ▼
           success           failure
              │                │
              ▼                ▼
          Fraud Check      Release Stock
              │                │
              ▼                ▼
      High Value Order?       FAIL
          │       │
         YES      NO
          │       │
          ▼       │
     Human Approval
          │       │
          └───┬───┘
              ▼
       Create Shipment
              │
         ┌────┴─────┐
         ▼          ▼
      success      failure
         │          │
         ▼          ▼
      Parallel    Refund
     ┌───┼───┐      │
     ▼   ▼   ▼      ▼
   Email Inv Analytics Release Stock
     │   │   │      │
     └───┼───┘      ▼
         ▼         FAIL
       SUCCEED
```

---

# 116. Why This Is Better Than Lambda Chains

Without Step Functions:

```text
Lambda A
calls Lambda B
calls Lambda C
calls Lambda D...
```

Problems:

```text
hidden workflow

custom retry logic

hard-to-see state

tight function coupling

manual compensation code

poor auditability
```

With Step Functions:

```text
workflow
=
visible graph

business transitions
=
explicit

failure paths
=
explicit
```

---

# Part X — Sample Error Strategy

# 117. Inventory Retry

```text
Inventory service throttled
        │
        ▼
Retry
2 sec
4 sec
8 sec
        │
 still fails
        ▼
Catch
        │
        ▼
Fail Workflow
```

---

# 118. Payment Failure

```text
Provider Timeout
→ retry


Card Declined
→ don't retry


Unexpected technical error
→ manual review
```

That is far better than:

```text
States.ALL
retry 10 times
```

on every failure.

---

# 119. Shipment Failure

Shipment failure occurs **after payment**.

Therefore:

```text
Shipment failed
      │
      ▼
Refund Payment
      │
      ▼
Release Inventory
      │
      ▼
Notify Failure
```

That is Saga compensation.

---

# Part Y — Testing

# 120. Test Individual States

Step Functions provides a `TestState` API capability that can test states in isolation, and AWS's documentation applies it to all core ASL state types. ([AWS Documentation][4])

This is useful when debugging:

```text
input transformation

Choice logic

service call parameters

retry behavior

state output
```

without running the entire production workflow.

---

# 121. Test Failure Paths

Don't test only:

```text
happy path.
```

Also test:

```text
Lambda timeout

Lambda throttling

DynamoDB throttle

payment decline

SQS permission error

callback timeout

malformed task token

Map item failure

Parallel branch failure

payload too large
```

Most production workflow bugs live in:

```text
failure paths.
```

---

# Part Z — Troubleshooting

# 122. `States.DataLimitExceeded`

Likely:

```text
workflow payload
became > 256 KiB.
```

Common cause:

```text
every state appends
large responses
to previous input.
```

Fix:

```text
trim data

use Output/ResultPath correctly

store large objects in S3
```

The payload boundary and DataLimitExceeded behavior are documented by Step Functions. ([AWS Documentation][20])

---

# 123. `States.Runtime`

Check:

```text
JSONPath points to nonexistent/null node?

wrong OutputPath?

wrong ResultPath?

JSONata expression invalid?
```

`States.Runtime` is not normally recoverable with an ordinary catch-all retry strategy. ([AWS Documentation][21])

---

# 124. Workflow Stuck in Running

Look for:

```text
Wait state

task-token callback

.sync job

activity

long-running service integration
```

For callback tasks verify:

```text
worker received token?

worker returned token?

correct account?

SendTaskSuccess permission?
```

Task-token callbacks require a valid same-account principal to return the token. ([AWS Documentation][18])

---

# 125. ECS Task Finished but Workflow Still Waiting

With `.sync`, inspect:

```text
Step Functions execution role

ECS permissions

EventBridge integration path

downstream status APIs
```

AWS uses service-specific monitoring methods—including EventBridge or downstream polling APIs—to detect completion for `.sync` integrations. ([AWS Documentation][36])

---

# 126. Express Workflow Missing in Execution History

Expected if logging wasn't configured.

Express history is not stored in Step Functions in the same way as Standard; configure CloudWatch Logs. ([AWS Documentation][32])

---

# 127. Parallel State Fails Even Though 2/3 Branches Succeeded

Expected.

One unhandled branch failure causes the overall Parallel state to fail. ([AWS Documentation][11])

Add:

```text
Retry/Catch
```

inside branches or around the Parallel state based on intended semantics.

---

# 128. Distributed Map Suddenly Fails

Check:

```text
ToleratedFailurePercentage

ToleratedFailureCount

ItemReader

ResultWriter

child workflow failures

child workflow throttling
```

Distributed Map emits dedicated failure types such as:

```text
States.ItemReaderFailed

States.ResultWriterFailed

States.ExceedToleratedFailureThreshold
```

([AWS Documentation][21])

---

# 129. Too Many Standard Executions Throttled

Check:

```text
StartExecution rate

state transition rate

nested workflows

Distributed Map child start rate

account quotas
```

Step Functions exposes service quotas and `ExecutionThrottled` for Standard state-transition throttling. ([AWS Documentation][14])

---

# Part AA — Certification / Interview Scenarios

# 130. Scenario

> Workflow may run for three days.

Answer:

```text
Step Functions Standard
```

because Express maxes at five minutes while Standard supports up to one year. ([AWS Documentation][2])

---

# 131. Scenario

> Process millions of very short idempotent events.

Think:

```text
Express Workflow
```

especially when high execution volume matters and workflow duration remains under five minutes. ([AWS Documentation][3])

---

# 132. Scenario

> User calls API and must synchronously receive workflow result.

Consider:

```text
Synchronous Express
```

for a short-running microservice workflow.

AWS supports Synchronous Express via `StartSyncExecution` and API Gateway integrations. ([AWS Documentation][3])

---

# 133. Scenario

> Wait six hours for manager approval.

Answer:

```text
Standard
+
waitForTaskToken.
```

Express does not support callback integration and cannot run longer than five minutes. ([AWS Documentation][2])

---

# 134. Scenario

> Start Fargate batch job and continue only after it finishes.

Answer:

```text
Standard Step Functions
+
ecs:runTask.sync
```

([AWS Documentation][19])

---

# 135. Scenario

> One Lambda is only calling SQS SendMessage.

Consider replacing the glue function with:

```text
Step Functions
→ SQS optimized integration.
```

([AWS Documentation][20])

---

# 136. Scenario

> Need retry with exponential backoff and randomized delay.

Use:

```text
Retry

BackoffRate

MaxDelaySeconds

JitterStrategy=FULL
```

([AWS Documentation][21])

---

# 137. Scenario

> Retry fails, then invoke recovery workflow.

Use:

```text
Retry
+
Catch
```

Step Functions applies retry policies before matching the Catch fallback. ([AWS Documentation][22])

---

# 138. Scenario

> Need process 25 items in parallel.

Use:

```text
Inline Map
```

if its other dataset/history requirements fit.

Inline Map supports up to 40 concurrent iterations. ([AWS Documentation][12])

---

# 139. Scenario

> Need process 5 million S3 objects at high concurrency.

Think:

```text
Distributed Map
```

which supports S3-backed large datasets and up to 10,000 concurrent child executions. ([AWS Documentation][13])

---

# 140. Scenario

> 2% of data files may legitimately fail but workflow should continue.

Use Distributed Map:

```text
ToleratedFailurePercentage
```

configured to the acceptable business threshold. ([AWS Documentation][13])

---

# 141. Scenario

> Three independent tasks should run concurrently and all must complete before continuing.

Use:

```text
Parallel
```

not Map.

Parallel runs predefined independent branches and joins after all complete. ([AWS Documentation][11])

---

# 142. Scenario

> Same workflow steps must run once for every item in a dynamic array.

Use:

```text
Map
```

not Parallel.

Map dynamically repeats the same processing logic per item. ([AWS Documentation][7])

---

# 143. Scenario

> Workflow failed after 20 successful steps; fix issue and resume without re-running everything.

Evaluate:

```text
Standard execution Redrive.
```

Eligible failed Standard executions can currently be redriven within their redrive window. ([AWS Documentation][29])

---

# 144. Scenario

> Need rollback across inventory, payment and shipping services.

There is no cross-service ACID rollback.

Use:

```text
Saga compensation
```

such as:

```text
ReleaseInventory

RefundPayment

CancelShipment
```

implemented through Catch/fallback workflow states.

---

# 145. The Permanent Orchestration Decision Tree

```text
                      BUSINESS PROCESS
                             │
                             ▼
                  Need explicit sequence?
                      │             │
                     NO            YES
                      │             │
                      ▼             ▼
                 EventBridge    Step Functions
                                │
                    ┌───────────┴────────────┐
                    ▼                        ▼
               < 5 minutes?           > 5 minutes /
                    │                  callback/job?
               high volume?                  │
                    │                        ▼
                    ▼                    STANDARD
                 EXPRESS
```

Then:

```text
Need run one operation?
→ Task


Need conditional branch?
→ Choice


Need delay?
→ Wait


Need multiple fixed branches?
→ Parallel


Need same steps per item?
→ Map


Need massive data processing?
→ Distributed Map


Need external completion?
→ waitForTaskToken


Need long-running AWS job?
→ .sync
```

---

# 146. Permanent Failure Decision Tree

```text
                    TASK FAILED
                         │
                         ▼
                 Is error transient?
                    │        │
                   YES      NO
                    │        │
                    ▼        ▼
                  Retry    Catch
                    │        │
          retries exhausted  │
                    │        │
                    └────┬───┘
                         ▼
                Recovery / Compensation
                         │
                ┌────────┴─────────┐
                ▼                  ▼
              recover             cannot
                │                  │
                ▼                  ▼
            continue             Fail
```

---

# 147. 45 Rules to Burn Into Memory

```text
1. Step Functions is workflow orchestration.

2. A workflow definition is a state machine.

3. State machines use Amazon States Language.

4. Standard and Express are different workflow types.

5. Workflow type cannot be changed after creation.

6. Standard can run up to one year.

7. Express can run up to five minutes.

8. Standard workflow semantics are exactly once.

9. Async Express is at least once.

10. Sync Express is at most once.

11. Express workloads should usually be idempotent.

12. Standard stores execution history.

13. Express needs CloudWatch Logs for execution history.

14. Task performs actual work.

15. Choice implements conditional logic.

16. Pass performs no external work.

17. Wait models time without sleeping compute.

18. Parallel runs predefined branches concurrently.

19. Map repeats the same logic for each item.

20. Succeed ends successfully.

21. Fail terminates with failure.

22. Inline Map supports up to 40 concurrent iterations.

23. Distributed Map supports up to 10,000 child executions.

24. Distributed Map is for large-scale processing.

25. Step Functions payloads have a 256-KiB boundary.

26. Put large payloads in S3, not workflow state.

27. Request Response waits for API response.

28. .sync waits for job completion.

29. waitForTaskToken waits for external callback.

30. Express does not support .sync.

31. Express does not support task-token callbacks.

32. Task tokens should be protected like credentials.

33. Retry handles transient errors.

34. Catch handles fallback/recovery.

35. Retry happens before Catch.

36. Use exponential backoff.

37. Add jitter to large-scale retries.

38. Don't retry permanent business errors.

39. Saga compensation is not database rollback.

40. Compensating actions must also be idempotent.

41. Standard failed executions can be redriven when eligible.

42. Nested workflows reduce complexity.

43. Avoid orchestration glue Lambda when native
    integrations exist.

44. Monitor workflow failures, timeouts and throttling.

45. SQS = queue,
    SNS = fan-out,
    EventBridge = choreography,
    Step Functions = orchestration.
```

---

# 148. Final Architecture

```text
                        API Gateway
                             │
                             ▼
                     Start Order Workflow
                             │
                             ▼
                      STEP FUNCTIONS
                             │
                    Validate Order
                             │
                             ▼
                    Reserve Inventory
                             │
                             ▼
                     Capture Payment
                             │
                        Retry/Catch
                             │
                             ▼
                       Fraud Check
                             │
                     ┌───────┴────────┐
                     ▼                ▼
                 ordinary         high value
                     │                │
                     │         Human Approval
                     │          Task Token
                     │                │
                     └───────┬────────┘
                             ▼
                    ECS RunTask.sync
                      Create Shipment
                             │
                    ┌────────┴────────┐
                    ▼                 ▼
                 SUCCESS            FAILURE
                    │                 │
                    ▼                 ▼
                 Parallel         Compensation
              ┌─────┼─────┐        │
              ▼     ▼     ▼        ▼
            Email Invoice Analytics Refund
              │     │     │        │
              └─────┼─────┘        ▼
                    ▼          Release Stock
                  SUCCEED            │
                                     ▼
                                    FAIL


      LARGE BATCH PROCESSING
              │
              ▼
       Distributed Map
              │
        up to 10k children
              │
              ▼
             S3


      OBSERVABILITY
      ─────────────

      Execution History
            +
      CloudWatch Logs
            +
      CloudWatch Metrics
            +
           X-Ray
            +
       EventBridge events
```

---

# ✅ Lesson 34 Part 4 Complete — AWS Step Functions

You now understand:

```text
✓ orchestration vs choreography
✓ state machines
✓ Amazon States Language

✓ Standard workflows
✓ Express workflows
✓ async Express
✓ synchronous Express
✓ exactly-once
✓ at-least-once
✓ at-most-once

✓ Task
✓ Choice
✓ Pass
✓ Wait
✓ Parallel
✓ Map
✓ Succeed
✓ Fail

✓ Inline Map
✓ Distributed Map
✓ Map Runs
✓ 40 Inline concurrency
✓ 10,000 Distributed children
✓ ItemReader concepts
✓ ResultWriter concepts
✓ tolerated failure thresholds

✓ Request Response
✓ .sync
✓ waitForTaskToken
✓ callbacks
✓ human approvals
✓ SQS callbacks
✓ ECS/Fargate workflows

✓ Retry
✓ Catch
✓ BackoffRate
✓ MaxAttempts
✓ MaxDelaySeconds
✓ JitterStrategy
✓ States.ALL
✓ States.TaskFailed
✓ States.Timeout
✓ States.Runtime
✓ States.DataLimitExceeded

✓ task timeouts
✓ heartbeats

✓ JSONPath
✓ InputPath
✓ Parameters
✓ ResultSelector
✓ ResultPath
✓ OutputPath

✓ JSONata
✓ workflow variables
✓ $states.input
✓ $states.result
✓ $states.errorOutput
✓ Context object

✓ nested workflows
✓ reusable orchestration

✓ Saga
✓ compensating transactions
✓ idempotent compensation

✓ workflow Redrive
✓ Distributed Map redrive

✓ Standard execution history
✓ Express CloudWatch logging
✓ X-Ray
✓ CloudWatch metrics

✓ execution-history quotas
✓ regional throttling concepts

✓ Terraform
✓ Step Functions IAM role
✓ production order workflow
✓ troubleshooting
✓ certification/interview scenarios
```

# ✅ Lesson 34 — Messaging & Event-Driven Architecture COMPLETE

You now have the complete AWS messaging/orchestration mental model:

```text
                              APPLICATION

                                  │
         ┌────────────────────────┼─────────────────────────┐
         ▼                        ▼                         ▼
        SQS                      SNS                   EventBridge
         │                        │                         │
      QUEUE                   FAN-OUT                  EVENT BUS
         │                        │                         │
         ▼                        ▼                         ▼
   Work Distribution       Pub/Sub Copies          Rich Event Routing
         │                        │                         │
         └────────────────────────┼─────────────────────────┘
                                  │
                                  ▼
                           Step Functions
                                  │
                                  ▼
                           ORCHESTRATION
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
           Lambda               ECS                AWS APIs
              │                   │                   │
              └───────────────────┼───────────────────┘
                                  ▼
                         Durable Workflow State
```

# Next — Lesson 35

# **Amazon ECS, Fargate & Production Container Architecture**

Now we return to containers—but at AWS production scale:

```text
                         Internet
                            │
                            ▼
                         Route 53
                            │
                            ▼
                        CloudFront
                            │
                            ▼
                           ALB
                            │
                            ▼
                      ECS Service
                    ┌───────┴───────┐
                    ▼               ▼
                Fargate Task    Fargate Task
                    │               │
                    └───────┬───────┘
                            ▼
                        Application
                            │
               ┌────────────┼────────────┐
               ▼            ▼            ▼
             RDS          Redis          SQS
```

Next we'll cover **ECS cluster architecture, task definitions, tasks, services, desired count, Fargate vs EC2 capacity, awsvpc networking, ENIs, task CPU/memory sizing, container dependencies, essential containers, health checks, ALB target groups, dynamic port mapping, service discovery, Cloud Map, Service Connect, deployment controllers, rolling updates, deployment circuit breakers, blue/green deployments, ECS Exec, ECR image management, IAM task roles vs execution roles, Secrets Manager, autoscaling, capacity providers, Fargate Spot, ECS Managed Instances, GPU/container workloads, observability, Container Insights, FireLens, Terraform, troubleshooting, cost optimization, and a complete production Node.js container architecture.**

[1]: https://docs.aws.amazon.com/step-functions/latest/dg/welcome.html?utm_source=chatgpt.com "What is Step Functions?"
[2]: https://docs.aws.amazon.com/step-functions/latest/dg/choosing-workflow-type.html "Choosing workflow type in Step Functions - AWS Step Functions"
[3]: https://docs.aws.amazon.com/step-functions/latest/dg/choosing-workflow-type.html?utm_source=chatgpt.com "Choosing workflow type in Step Functions"
[4]: https://docs.aws.amazon.com/step-functions/latest/dg/test-state-isolation.html?utm_source=chatgpt.com "Testing state machines with TestState API"
[5]: https://docs.aws.amazon.com/step-functions/latest/dg/state-task.html?utm_source=chatgpt.com "Task workflow state - AWS Step Functions"
[6]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-lambda.html?utm_source=chatgpt.com "Invoke an AWS Lambda function with Step Functions"
[7]: https://docs.aws.amazon.com/step-functions/latest/dg/workflow-states.html?utm_source=chatgpt.com "Discovering workflow states to use in Step Functions"
[8]: https://docs.aws.amazon.com/step-functions/latest/dg/state-pass.html?utm_source=chatgpt.com "Pass workflow state - AWS Step Functions"
[9]: https://docs.aws.amazon.com/step-functions/latest/dg/state-succeed.html?utm_source=chatgpt.com "Succeed workflow state - AWS Step Functions"
[10]: https://docs.aws.amazon.com/step-functions/latest/dg/state-fail.html?utm_source=chatgpt.com "Fail workflow state - AWS Step Functions"
[11]: https://docs.aws.amazon.com/step-functions/latest/dg/state-parallel.html?utm_source=chatgpt.com "Parallel workflow state - AWS Step Functions"
[12]: https://docs.aws.amazon.com/step-functions/latest/dg/state-map.html?utm_source=chatgpt.com "Map workflow state - AWS Step Functions"
[13]: https://docs.aws.amazon.com/step-functions/latest/dg/state-map-distributed.html?utm_source=chatgpt.com "Using Map state in Distributed mode for large-scale ..."
[14]: https://docs.aws.amazon.com/step-functions/latest/dg/service-quotas.html?utm_source=chatgpt.com "Step Functions service quotas - AWS Documentation"
[15]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-examine-map-run.html?utm_source=chatgpt.com "Viewing a Distributed Map Run execution in Step Functions"
[16]: https://docs.aws.amazon.com/cli/latest/reference/stepfunctions/describe-map-run.html?utm_source=chatgpt.com "describe-map-run — AWS CLI 2.36.2 Command Reference"
[17]: https://docs.aws.amazon.com/step-functions/latest/dg/integrate-services.html?utm_source=chatgpt.com "Integrating services with Step Functions"
[18]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-to-resource.html?utm_source=chatgpt.com "Discover service integration patterns in Step Functions"
[19]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-ecs.html?utm_source=chatgpt.com "Run Amazon ECS or Fargate tasks with Step Functions"
[20]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-sqs.html?utm_source=chatgpt.com "Send messages to an Amazon SQS queue with Step ..."
[21]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html "Handling errors in Step Functions workflows - AWS Step Functions"
[22]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html?utm_source=chatgpt.com "Handling errors in Step Functions workflows"
[23]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-input-output-filtering.html?utm_source=chatgpt.com "Processing input and output in Step Functions"
[24]: https://docs.aws.amazon.com/step-functions/latest/dg/workflow-variables.html?utm_source=chatgpt.com "Passing data between states with variables"
[25]: https://docs.aws.amazon.com/step-functions/latest/dg/transforming-data.html?utm_source=chatgpt.com "Transforming data with JSONata in Step Functions"
[26]: https://docs.aws.amazon.com/step-functions/latest/dg/input-output-contextobject.html?utm_source=chatgpt.com "Accessing execution data from the Context object in Step ..."
[27]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-stepfunctions.html?utm_source=chatgpt.com "Start a new AWS Step Functions state machine from ..."
[28]: https://docs.aws.amazon.com/step-functions/latest/dg/redrive-executions.html?utm_source=chatgpt.com "Restarting state machine executions with redrive in Step ..."
[29]: https://docs.aws.amazon.com/cli/latest/reference/stepfunctions/redrive-execution.html?utm_source=chatgpt.com "redrive-execution — AWS CLI 2.36.20 Command Reference"
[30]: https://docs.aws.amazon.com/step-functions/latest/dg/redrive-map-run.html?utm_source=chatgpt.com "Redriving Map Runs in Step Functions executions"
[31]: https://docs.aws.amazon.com/cli/latest/reference/stepfunctions/describe-execution.html?utm_source=chatgpt.com "describe-execution — AWS CLI 2.36.20 Command ..."
[32]: https://docs.aws.amazon.com/step-functions/latest/dg/cw-logs.html?utm_source=chatgpt.com "Using CloudWatch Logs to log execution history in Step ..."
[33]: https://docs.aws.amazon.com/step-functions/latest/dg/monitoring-logging.html?utm_source=chatgpt.com "Logging and monitoring AWS Step Functions service ..."
[34]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-xray-tracing.html?utm_source=chatgpt.com "Trace Step Functions request data in AWS X-Ray"
[35]: https://docs.aws.amazon.com/step-functions/latest/dg/tutorial-continue-new.html?utm_source=chatgpt.com "Continue long-running workflows using Step Functions API ..."
[36]: https://docs.aws.amazon.com/step-functions/latest/dg/troubleshooting.html?utm_source=chatgpt.com "Troubleshooting issues in Step Functions"
[37]: https://docs.aws.amazon.com/cli/latest/reference/stepfunctions/publish-state-machine-version.html?utm_source=chatgpt.com "publish-state-machine-version"
[38]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine?utm_source=chatgpt.com "aws_sfn_state_machine | Resources | hashicorp/aws | Terraform"
