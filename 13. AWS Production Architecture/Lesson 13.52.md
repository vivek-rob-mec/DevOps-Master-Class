# AWS Masterclass — Phase 3

# Lesson 51: AWS Step Functions Production Workflow Orchestration

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Model business processes as visual state machines.
* Choose between Standard and Express Workflows.
* Use Task, Choice, Wait, Parallel, Map, Pass, Succeed and Fail states.
* Call AWS services without unnecessary Lambda functions.
* Use request-response, `.sync` and callback integration patterns.
* Build human-approval workflows using task tokens.
* Configure timeouts, heartbeats, retries and error catches.
* Implement compensation using the saga pattern.
* Process large datasets using Distributed Map.
* Control workflow concurrency to protect downstream systems.
* Use JSONPath, JSONata and workflow variables.
* Avoid the 256-KiB payload and 25,000-event history limits.
* Restart failed Standard executions with redrive.
* Design idempotent and replay-safe workflows.
* Split large systems into nested state machines.
* Deploy state machines safely using versions and aliases.
* Add CloudWatch Logs, metrics, EventBridge events and X-Ray tracing.
* Provision Step Functions using Terraform.
* Troubleshoot production workflow failures.

---

# 2. What is AWS Step Functions?

AWS Step Functions is a managed workflow-orchestration service.

Instead of placing the entire business process inside one Lambda function, script or application service, you describe the process as a state machine.

```text
Request
   |
   v
AWS Step Functions
   |
   ├── Validate input
   ├── Call Lambda
   ├── Write DynamoDB item
   ├── Run ECS task
   ├── Wait for approval
   ├── Retry temporary failures
   ├── Compensate previous actions
   └── Complete workflow
```

Step Functions can directly integrate with more than 200 AWS services and thousands of AWS API operations through optimized and AWS SDK integrations. ([AWS Documentation][1])

## One-line memory trick

```text
Lambda performs work.

Step Functions decides:
what runs,
when it runs,
what happens next,
and what happens when it fails.
```

---

# 3. Orchestration versus choreography

## Orchestration

A central workflow controls the process.

```text
Step Functions
    |
    ├── Call inventory
    ├── Charge payment
    ├── Create order
    └── Send notification
```

The workflow knows:

* The sequence.
* The decision rules.
* The retry rules.
* The timeout rules.
* The compensation steps.
* The final outcome.

## Choreography

Services react to events without one central controller.

```text
OrderCreated event
    |
    ├── Inventory service reacts
    ├── Billing service reacts
    ├── Notification service reacts
    └── Analytics service reacts
```

Use orchestration when the process has:

* A defined sequence.
* Dependencies between steps.
* Central error handling.
* Human approvals.
* Compensation.
* Long waits.
* A clear business outcome.

Use choreography when services can react independently and loose coupling is more important than a central process view.

A production system often uses both:

```text
Step Functions:
Controls one business transaction.

EventBridge:
Publishes events about the transaction.
```

---

# 4. Why not put everything in one Lambda?

A large orchestration Lambda often becomes:

```text
Lambda handler
├── Call service A
├── Retry service A
├── Sleep
├── Call service B
├── Store progress
├── Poll job
├── Handle approval
├── Retry service C
├── Roll back service A
└── Send notification
```

Problems:

* Complicated retry code.
* Difficult state persistence.
* Long-running compute charges.
* Poor visibility.
* Difficult recovery.
* Hard-coded wait loops.
* Complex partial-failure handling.
* Deployment risk.
* Large blast radius.

With Step Functions:

```text
State machine
├── Each step visible
├── State persisted
├── Retries declared
├── Waits do not require busy code
├── Errors are routed explicitly
└── Execution history is inspectable
```

---

# 5. State machine mental model

A Step Functions workflow is called a:

```text
State machine
```

One run of that state machine is called an:

```text
Execution
```

Example:

```text
State machine:
TodoAccountDeletionWorkflow

Executions:
├── deletion-user-104
├── deletion-user-205
└── deletion-user-306
```

You define the workflow using Amazon States Language, a JSON-based language describing states and their transitions. ([AWS Documentation][2])

---

# 6. Core state types

Step Functions supports these main workflow states:

```text
Task
Choice
Wait
Parallel
Map
Pass
Succeed
Fail
```

([AWS Documentation][2])

## Task

Performs work.

```text
Invoke Lambda
Run ECS task
Write DynamoDB item
Send SQS message
Call external HTTPS API
```

## Choice

Adds conditional branching.

```text
Payment approved?
├── Yes → Continue
└── No  → Reject order
```

## Wait

Pauses for a duration or until a timestamp.

## Parallel

Runs different branches concurrently.

## Map

Runs the same workflow for several input items.

## Pass

Transforms or passes data without external work.

## Succeed

Ends successfully.

## Fail

Ends unsuccessfully.

---

# 7. Basic workflow example

```json
{
  "Comment": "Basic Todo workflow",
  "StartAt": "ValidateTodo",
  "States": {
    "ValidateTodo": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Arguments": {
        "FunctionName": "todo-validator",
        "Payload": "{% $states.input %}"
      },
      "Output": "{% $states.result.Payload %}",
      "Next": "IsValid"
    },
    "IsValid": {
      "Type": "Choice",
      "Choices": [
        {
          "Condition": "{% $states.input.valid = true %}",
          "Next": "TodoAccepted"
        }
      ],
      "Default": "TodoRejected"
    },
    "TodoAccepted": {
      "Type": "Succeed"
    },
    "TodoRejected": {
      "Type": "Fail",
      "Error": "TodoValidationFailed",
      "Cause": "The todo request was invalid"
    }
  }
}
```

Flow:

```text
ValidateTodo
     |
     v
IsValid?
  /      \
Yes      No
 |        |
 v        v
Success  Failure
```

---

# 8. Standard versus Express Workflows

Step Functions provides two workflow types:

```text
Standard Workflow
Express Workflow
```

The workflow type cannot be changed after the state machine is created. ([AWS Documentation][3])

| Characteristic         |                        Standard |                                  Express |
| ---------------------- | ------------------------------: | ---------------------------------------: |
| Maximum duration       |                        One year |                             Five minutes |
| Execution model        | Exactly-once workflow execution | Async: at least once; sync: at most once |
| Execution history      |        Stored by Step Functions |                 Requires CloudWatch Logs |
| Pricing                |               State transitions |          Executions, duration and memory |
| `.sync` integrations   |                       Supported |                            Not supported |
| Task-token callbacks   |                       Supported |                            Not supported |
| Activities             |                       Supported |                            Not supported |
| Distributed Map parent |                       Supported |                            Not supported |
| Typical workload       |      Long-running orchestration |              High-volume short workflows |

([AWS Documentation][3])

---

# 9. Standard Workflows

Use Standard Workflows for:

* Payments.
* Provisioning infrastructure.
* Human approvals.
* Account deletion.
* Multi-hour or multi-day workflows.
* Batch jobs.
* ECS tasks.
* Data-processing jobs.
* Workflows needing full audit history.
* Workflows needing callback task tokens.
* Workflows using Distributed Map.

Standard executions can run for up to one year and maintain a Step Functions execution history containing up to 25,000 events. Their execution records are normally retained for 90 days after completion. ([AWS Documentation][4])

```text
User account deletion
       |
       v
Wait seven days
       |
       v
Request approval
       |
       v
Run data export
       |
       v
Delete account
```

This process cannot fit safely into a five-minute Express Workflow.

---

# 10. Standard exactly-once model

AWS describes Standard Workflows as using an exactly-once workflow-execution model: states are not started more than once unless retry behaviour is configured. ([AWS Documentation][3])

However, your business operations should still be idempotent because:

* You may configure retries.
* You may redrive a failed execution.
* An external service may time out after completing work.
* A callback worker may send a result twice.
* Operators may start a second execution.
* Downstream APIs may have their own delivery semantics.

Therefore:

```text
Exactly-once workflow orchestration
does not remove the need for
idempotent business actions.
```

---

# 11. Express Workflows

Use Express Workflows for:

* High-volume transformations.
* Short event-processing pipelines.
* IoT event processing.
* High-volume request validation.
* API backend orchestration.
* Short DynamoDB operations.
* Short parallel computations.
* Idempotent event handling.

Express executions run for a maximum of five minutes and do not have execution history stored directly by Step Functions; CloudWatch Logs must be enabled to inspect their execution details. ([AWS Documentation][3])

---

# 12. Asynchronous Express Workflow

```text
Caller
  |
  | StartExecution
  v
Express workflow starts
  |
  v
Caller immediately receives start confirmation
```

The caller does not wait for the result.

Execution model:

```text
At least once
```

The workflow may run more than once, so every action should be idempotent. ([AWS Documentation][3])

Suitable example:

```text
EventBridge event
      |
      v
Express workflow
      |
      ├── Transform event
      ├── Write DynamoDB item idempotently
      └── Publish metric
```

---

# 13. Synchronous Express Workflow

```text
Caller
  |
  | StartSyncExecution
  v
Express workflow runs
  |
  v
Result returned to caller
```

Execution model:

```text
At most once
```

If the execution is interrupted, it is not automatically restarted. Synchronous Express is useful for short microservice or API orchestration. ([AWS Documentation][3])

Architecture:

```text
API Gateway
    |
    v
Synchronous Express Workflow
    |
    ├── Validate request
    ├── Retrieve DynamoDB item
    ├── Call service
    └── Return response
```

---

# 14. Choosing the workflow type

```text
Does the workflow need to run over five minutes?
    → Standard

Does it need a human callback?
    → Standard

Does it need ECS/Batch/Glue .sync?
    → Standard

Does it need Distributed Map as the parent?
    → Standard

Is it a short, high-volume, idempotent workflow?
    → Express

Does an API need an immediate workflow response?
    → Synchronous Express

Does an event trigger short asynchronous processing?
    → Asynchronous Express
```

Express Workflows support request-response service integrations but do not support `.sync` or `.waitForTaskToken` integration patterns. ([AWS Documentation][5])

---

# 15. Service-integration patterns

Step Functions provides three important service-integration patterns:

```text
Request Response
Run a Job (.sync)
Wait for Callback (.waitForTaskToken)
```

([AWS Documentation][5])

---

# 16. Request-response integration

Step Functions calls an API and waits for the immediate API response.

```text
Step Functions
      |
      | Call DynamoDB PutItem
      v
DynamoDB
      |
      | API response
      v
Next state
```

Example:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::dynamodb:putItem",
  "Arguments": {
    "TableName": "production-todos",
    "Item": {
      "PK": {
        "S": "{% 'TODO#' & $states.input.todoId %}"
      },
      "Status": {
        "S": "PENDING"
      }
    }
  },
  "Next": "ContinueWorkflow"
}
```

The workflow waits for the `PutItem` API response, not for some later business activity involving that item.

---

# 17. Run-a-job integration

The `.sync` pattern starts a job and waits until it completes.

```text
Step Functions
      |
      | Start ECS task
      v
ECS task running
      |
      | Step Functions waits
      v
ECS task completed
      |
      v
Next workflow state
```

Example:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::ecs:runTask.sync",
  "Arguments": {
    "Cluster": "production",
    "LaunchType": "FARGATE",
    "TaskDefinition": "todo-data-export",
    "NetworkConfiguration": {
      "AwsvpcConfiguration": {
        "Subnets": [
          "subnet-private-a",
          "subnet-private-b"
        ],
        "SecurityGroups": [
          "sg-export-task"
        ],
        "AssignPublicIp": "DISABLED"
      }
    }
  },
  "Next": "VerifyExport"
}
```

Step Functions provides `.sync` integrations for supported long-running jobs such as ECS tasks, AWS Batch, Glue, CodeBuild and SageMaker AI jobs. ([AWS Documentation][5])

---

# 18. Callback integration

The callback pattern starts external work and pauses until the external process returns a task token.

```text
Step Functions
      |
      | Send task token
      v
External worker or human process
      |
      | SendTaskSuccess / SendTaskFailure
      v
Step Functions continues
```

Example:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::sqs:sendMessage.waitForTaskToken",
  "Arguments": {
    "QueueUrl": "https://sqs.ap-south-1.amazonaws.com/123456789012/approvals",
    "MessageBody": {
      "requestId": "{% $states.input.requestId %}",
      "taskToken": "{% $states.context.Task.Token %}",
      "action": "APPROVE_ACCOUNT_DELETION"
    }
  },
  "HeartbeatSeconds": 3600,
  "TimeoutSeconds": 604800,
  "Next": "ProcessApproval"
}
```

The external worker completes the task with `SendTaskSuccess` or fails it with `SendTaskFailure`; workers can also send heartbeats while work continues. ([AWS Documentation][6])

---

# 19. Human approval workflow

```text
Request account deletion
        |
        v
Store request
        |
        v
Send approval link
        |
        v
Workflow waits
        |
      /   \
Approve   Reject
  |         |
  v         v
Delete    Cancel
```

A production approval design commonly uses:

```text
Step Functions
    |
    v
SQS / Lambda / API Gateway
    |
    v
Approval web application
    |
    v
SendTaskSuccess or SendTaskFailure
```

Step Functions can pause Standard Workflows while waiting for a human or external system to return a task token. ([AWS Documentation][7])

---

# 20. Protecting task tokens

A task token represents authority to complete one waiting task.

Treat it as a secret.

Do not:

* Log it in plaintext.
* Put it in a publicly readable URL.
* Store it in browser local storage unnecessarily.
* Send it to unrelated systems.
* Reuse it.
* Allow arbitrary users to submit it.

Better approval flow:

```text
Approval link contains:
opaque approval ID

Backend database stores:
approval ID → encrypted task token

Authenticated approver:
approves request

Backend:
retrieves task token
calls SendTaskSuccess
```

---

# 21. Task timeout

Use `TimeoutSeconds` to define the maximum total duration of a Task state.

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::ecs:runTask.sync",
  "TimeoutSeconds": 3600
}
```

If the Task does not complete within the configured timeout, Step Functions reports `States.Timeout`. A state-machine-level timeout can also terminate the complete execution. ([AWS Documentation][8])

Never leave external work without a bounded timeout.

---

# 22. Heartbeats

Heartbeats answer:

```text
Is the external worker still alive and making progress?
```

Example:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::sqs:sendMessage.waitForTaskToken",
  "HeartbeatSeconds": 300,
  "TimeoutSeconds": 86400
}
```

The worker must call:

```text
SendTaskHeartbeat
```

within every heartbeat interval.

If the heartbeat interval is exceeded, the task fails with `States.HeartbeatTimeout`. Heartbeats do not extend the absolute task timeout. ([AWS Documentation][8])

## Distinction

```text
HeartbeatSeconds:
Maximum silence between progress signals.

TimeoutSeconds:
Maximum total task duration.
```

---

# 23. Wait state

A Wait state pauses the workflow without requiring a Lambda function to sleep.

```json
{
  "Type": "Wait",
  "Seconds": 300,
  "Next": "CheckStatus"
}
```

Or wait until an absolute timestamp:

```json
{
  "Type": "Wait",
  "TimestampPath": "$.scheduledDeletionTime",
  "Next": "DeleteAccount"
}
```

Wait states can use a relative number of seconds or an absolute timestamp. ([AWS Documentation][9])

Use cases:

* Delayed account deletion.
* Cooling-off period.
* Scheduled follow-up.
* Polling interval.
* Retry delay.
* Waiting for external consistency.

---

# 24. Choice state

Choice states implement conditional logic.

```json
{
  "Type": "Choice",
  "Choices": [
    {
      "Condition": "{% $states.input.approved = true %}",
      "Next": "Approved"
    },
    {
      "Condition": "{% $states.input.approved = false %}",
      "Next": "Rejected"
    }
  ],
  "Default": "InvalidApprovalResponse"
}
```

Always define a sensible `Default` branch unless every possible input is guaranteed to match. A Choice state with no matching condition and no default can fail at runtime. ([AWS Documentation][10])

---

# 25. Parallel state

Parallel runs different branches concurrently and waits for all branches to terminate.

```text
                 ┌── Send notification
Start Parallel ──┼── Update search index
                 └── Publish analytics event
```

Example:

```json
{
  "Type": "Parallel",
  "Branches": [
    {
      "StartAt": "NotifyUser",
      "States": {
        "NotifyUser": {
          "Type": "Task",
          "Resource": "arn:aws:states:::sns:publish",
          "Arguments": {
            "TopicArn": "arn:aws:sns:ap-south-1:123456789012:notifications",
            "Message": "Todo completed"
          },
          "End": true
        }
      }
    },
    {
      "StartAt": "PublishEvent",
      "States": {
        "PublishEvent": {
          "Type": "Task",
          "Resource": "arn:aws:states:::events:putEvents",
          "Arguments": {
            "Entries": [
              {
                "Source": "todoapp.workflow",
                "DetailType": "TodoCompleted",
                "Detail": "{% $string($states.input) %}"
              }
            ]
          },
          "End": true
        }
      }
    }
  ],
  "Next": "Complete"
}
```

If one branch fails without being handled, the Parallel state fails and its branches are stopped from the workflow’s perspective. Already-running Lambda invocations cannot be forcibly stopped by Step Functions. ([AWS Documentation][11])

---

# 26. Parallel does not guarantee simultaneous execution

Parallel means:

```text
Run branches as concurrently as possible.
```

It does not mean:

```text
Every operation starts in the exact same microsecond.
```

Each integrated service still has:

* API throttles.
* Concurrency limits.
* Scheduling delay.
* Network latency.
* Capacity constraints.

Do not use Parallel as a distributed transaction guarantee.

---

# 27. Inline Map

Inline Map applies the same workflow to each item in a JSON array.

```json
{
  "Type": "Map",
  "Items": "{% $states.input.todos %}",
  "MaxConcurrency": 10,
  "ItemProcessor": {
    "StartAt": "ValidateTodo",
    "States": {
      "ValidateTodo": {
        "Type": "Task",
        "Resource": "arn:aws:states:::lambda:invoke",
        "Arguments": {
          "FunctionName": "validate-todo",
          "Payload": "{% $states.input %}"
        },
        "End": true
      }
    }
  },
  "Next": "Complete"
}
```

Inline Map accepts a JSON array, supports up to 40 concurrent iterations and stores iteration events in the parent execution history. ([AWS Documentation][12])

Use Inline Map when:

* Input fits inside the workflow payload.
* Concurrency is 40 or less.
* Execution history remains under 25,000 events.
* You need simple per-item processing.

---

# 28. Distributed Map

Distributed Map is designed for large-scale parallel processing.

```text
S3 dataset
    |
    v
Distributed Map
    |
    ├── Child execution 1
    ├── Child execution 2
    ├── Child execution 3
    └── ... up to controlled concurrency
```

Distributed Map:

* Runs each iteration as a child workflow execution.
* Supports up to 10,000 parallel child executions.
* Can read JSON arrays and several S3-based data sources.
* Maintains separate execution histories for child executions.
* Can write results to S3.
* Supports tolerated failure thresholds.
* Requires a Standard Workflow as its parent. ([AWS Documentation][13])

---

# 29. Distributed Map example

```json
{
  "Type": "Map",
  "ItemReader": {
    "Resource": "arn:aws:states:::s3:getObject",
    "ReaderConfig": {
      "InputType": "CSV",
      "CSVHeaderLocation": "FIRST_ROW"
    },
    "Arguments": {
      "Bucket": "production-todo-imports",
      "Key": "{% $states.input.objectKey %}"
    }
  },
  "ItemProcessor": {
    "ProcessorConfig": {
      "Mode": "DISTRIBUTED",
      "ExecutionType": "EXPRESS"
    },
    "StartAt": "ImportTodo",
    "States": {
      "ImportTodo": {
        "Type": "Task",
        "Resource": "arn:aws:states:::lambda:invoke",
        "Arguments": {
          "FunctionName": "import-todo",
          "Payload": "{% $states.input %}"
        },
        "End": true
      }
    }
  },
  "MaxConcurrency": 500,
  "ToleratedFailurePercentage": 1,
  "ResultWriter": {
    "Resource": "arn:aws:states:::s3:putObject",
    "Arguments": {
      "Bucket": "production-todo-import-results",
      "Prefix": "{% $states.context.Execution.Id %}"
    }
  },
  "End": true
}
```

The Distributed Map parent must be Standard, but the child execution type can be Standard or Express. Results can be exported to S3 using `ResultWriter`. ([AWS Documentation][13])

---

# 30. Distributed Map failure thresholds

A bulk workflow may tolerate a limited number of failures.

Example:

```text
Items:
100,000

Allowed failure percentage:
1%

Maximum acceptable failures:
1,000
```

Configuration:

```json
{
  "ToleratedFailurePercentage": 1
}
```

or:

```json
{
  "ToleratedFailureCount": 1000
}
```

A Distributed Map fails when the configured failure threshold is exceeded and reports `States.ExceedToleratedFailureThreshold`. Some child executions may continue briefly while the Map Run transitions to failure. ([AWS Documentation][13])

---

# 31. Concurrency must protect downstream services

Distributed Map can create thousands of concurrent executions.

That does not mean your database can support thousands of concurrent writes.

```text
Distributed Map:
10,000 child executions

RDS safe connections:
300

Result:
Database failure
```

Configure:

```text
MaxConcurrency
```

from the capacity of the slowest downstream dependency.

Example:

```text
Lambda reserved concurrency:
500

DynamoDB safe write rate:
2,000 writes/s

Average child:
4 writes/s

Safe child concurrency:
approximately 500
```

AWS explicitly recommends limiting Map concurrency so it does not exceed downstream service capacity. ([AWS Documentation][13])

---

# 32. Amazon States Language data flow

Each state receives JSON input and produces JSON output.

```text
Execution input
      |
      v
State A input
      |
      v
State A result
      |
      v
State A output
      |
      v
State B input
```

Step Functions supports:

```text
JSONPath
JSONata
Workflow variables
```

JSONPath provides path-based input and output filtering. JSONata provides expressions, transformations and variables. ([AWS Documentation][14])

---

# 33. JSONPath processing

Traditional JSONPath fields include:

```text
InputPath
Parameters
ResultSelector
ResultPath
OutputPath
```

Conceptual order:

```text
State input
   |
   v
InputPath
   |
   v
Parameters
   |
   v
Task
   |
   v
ResultSelector
   |
   v
ResultPath
   |
   v
OutputPath
   |
   v
State output
```

Example:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::lambda:invoke",
  "InputPath": "$.todo",
  "Parameters": {
    "FunctionName": "process-todo",
    "Payload.$": "$"
  },
  "ResultSelector": {
    "processedTodo.$": "$.Payload"
  },
  "ResultPath": "$.processingResult",
  "OutputPath": "$.processingResult"
}
```

---

# 34. JSONata

JSONata provides expression-based transformations.

Example input:

```json
{
  "firstName": "Vivek",
  "lastName": "Saroj",
  "todos": [
    {
      "status": "OPEN"
    },
    {
      "status": "COMPLETED"
    }
  ]
}
```

JSONata expressions:

```text
Full name:
{% $states.input.firstName & " " & $states.input.lastName %}

Open todos:
{% $states.input.todos[status = "OPEN"] %}

Todo count:
{% $count($states.input.todos) %}
```

Step Functions currently implements JSONata based on the JSONata 2.0.6 specification, with Step Functions-specific variables and functions. ([AWS Documentation][14])

---

# 35. Workflow variables

Workflow variables let you store values without carrying every value through every state output.

```json
{
  "Type": "Pass",
  "Assign": {
    "requestId": "{% $states.context.Execution.Id %}",
    "userId": "{% $states.input.userId %}",
    "startedAt": "{% $now() %}"
  },
  "Next": "ProcessRequest"
}
```

Later:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::lambda:invoke",
  "Arguments": {
    "FunctionName": "process-request",
    "Payload": {
      "requestId": "{% $requestId %}",
      "userId": "{% $userId %}"
    }
  },
  "End": true
}
```

Variables reduce the need to repeatedly merge workflow metadata into each state’s JSON output. ([AWS Documentation][15])

---

# 36. Context object

The context object provides execution metadata.

Useful values include concepts such as:

```text
Execution ID
Execution name
State machine ID
Current state name
Retry count
Task token
Map item index
Map item value
```

Example JSONata:

```text
{% $states.context.Execution.Id %}
{% $states.context.State.Name %}
{% $states.context.State.RetryCount %}
{% $states.context.Task.Token %}
```

Use the execution ID as a correlation identifier across:

* Logs.
* DynamoDB workflow records.
* EventBridge events.
* ECS environment variables.
* Notifications.
* Audit records.

---

# 37. The 256-KiB payload limit

The maximum input or output size for a task, state or execution is:

```text
256 KiB
```

as a UTF-8 encoded payload. ([AWS Documentation][4])

Bad:

```text
State output contains:
50,000 database records
or
a large document
or
a binary file
```

Better:

```text
Large data
   |
   v
Amazon S3

Workflow state:
{
  "bucket": "...",
  "key": "...",
  "versionId": "...",
  "checksum": "..."
}
```

AWS recommends storing larger data in S3 and passing a reference through the state machine. ([AWS Documentation][16])

---

# 38. `States.DataLimitExceeded`

`States.DataLimitExceeded` can occur when:

* A connector output exceeds the payload quota.
* A state output exceeds the payload quota.
* State input becomes too large after parameter processing.

`States.ALL` does not catch this error, though it can be targeted explicitly in `Retry` or `Catch`. ([AWS Documentation][8])

The best fix is normally:

```text
Reduce payload size
or
store data externally
```

rather than retrying the same oversized operation.

---

# 39. Execution-history limit

Standard Workflow execution history has a hard limit of:

```text
25,000 events
```

If event 25,000 is not successful workflow completion, the execution fails because of the history limit. ([AWS Documentation][16])

Large history can result from:

* Large Inline Maps.
* Frequent polling loops.
* Thousands of retries.
* Long-running repeated checks.
* Excessive nested state transitions.

Solutions:

* Use Distributed Map.
* Start a new nested execution.
* Replace polling with `.sync`.
* Replace polling with a task-token callback.
* Process larger batches per iteration.

---

# 40. Continue as a new execution

For workflows approaching the history limit:

```text
Execution 1
    |
    | Start new execution with progress checkpoint
    v
Execution 2
    |
    v
Execution 3
```

Step Functions recommends starting a new execution from a Task state for workflows that would exceed the one-year or 25,000-event boundaries. ([AWS Documentation][17])

Example progress input:

```json
{
  "jobId": "bulk-import-104",
  "nextPageToken": "abc123",
  "processedItems": 100000,
  "parentExecutionId": "..."
}
```

---

# 41. Retry

`Retry` is available on:

```text
Task
Parallel
Map
```

states. ([AWS Documentation][8])

Example:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::lambda:invoke",
  "Arguments": {
    "FunctionName": "process-todo",
    "Payload": "{% $states.input %}"
  },
  "Retry": [
    {
      "ErrorEquals": [
        "Lambda.ServiceException",
        "Lambda.SdkClientException",
        "Lambda.TooManyRequestsException"
      ],
      "IntervalSeconds": 2,
      "BackoffRate": 2,
      "MaxAttempts": 5,
      "MaxDelaySeconds": 30,
      "JitterStrategy": "FULL"
    }
  ],
  "Next": "Continue"
}
```

Step Functions retriers are evaluated in order and can apply increasing retry intervals. ([AWS Documentation][8])

---

# 42. Exponential backoff

Example:

```text
IntervalSeconds = 2
BackoffRate = 2

Retry waits:
2 seconds
4 seconds
8 seconds
16 seconds
```

This reduces pressure on a temporarily unavailable service.

Without backoff:

```text
1,000 failed workflows
×
immediate retry
=
retry storm
```

Use jitter so many workflows do not retry at exactly the same time.

---

# 43. Do not retry every error

Retry:

* Service throttling.
* Temporary network failure.
* Lambda service exception.
* Transient downstream unavailability.
* Temporary lock conflict.

Usually do not retry:

* Invalid user input.
* Permission denied.
* Unsupported request.
* Schema validation failure.
* Missing required resource.
* Permanent business rejection.

Example:

```json
"Retry": [
  {
    "ErrorEquals": [
      "Lambda.TooManyRequestsException",
      "Lambda.ServiceException"
    ],
    "MaxAttempts": 5
  },
  {
    "ErrorEquals": [
      "ValidationError",
      "AccessDenied"
    ],
    "MaxAttempts": 0
  }
]
```

---

# 44. Catch

`Catch` routes a failed state to a recovery path after retries are exhausted.

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::lambda:invoke",
  "Arguments": {
    "FunctionName": "charge-subscription",
    "Payload": "{% $states.input %}"
  },
  "Retry": [
    {
      "ErrorEquals": [
        "PaymentProviderTemporaryFailure"
      ],
      "IntervalSeconds": 2,
      "MaxAttempts": 3,
      "BackoffRate": 2
    }
  ],
  "Catch": [
    {
      "ErrorEquals": [
        "PaymentRejected"
      ],
      "Next": "NotifyPaymentRejected"
    },
    {
      "ErrorEquals": [
        "States.ALL"
      ],
      "Next": "CompensateWorkflow"
    }
  ],
  "Next": "ActivateSubscription"
}
```

Catchers are available on Task, Parallel and Map states. ([AWS Documentation][8])

---

# 45. Preserve error information

Use `ResultPath` in JSONPath workflows to retain original input and add error details.

```json
"Catch": [
  {
    "ErrorEquals": [
      "States.ALL"
    ],
    "ResultPath": "$.workflowError",
    "Next": "RecordFailure"
  }
]
```

Result:

```json
{
  "todoId": "501",
  "userId": "104",
  "workflowError": {
    "Error": "DatabaseUnavailable",
    "Cause": "Connection timed out"
  }
}
```

This gives the recovery state both:

* Original workflow context.
* Failure information.

---

# 46. Important built-in errors

## `States.Timeout`

Task or workflow exceeded its configured timeout.

## `States.HeartbeatTimeout`

Worker failed to heartbeat within the required interval.

## `States.TaskFailed`

General task failure wildcard except timeout.

## `States.Permissions`

Execution role lacks required permission.

## `States.DataLimitExceeded`

Payload exceeded the supported limit.

## `States.Runtime`

Invalid runtime data processing, such as applying a path to incompatible input.

## `States.ExceedToleratedFailureThreshold`

Distributed Map failure threshold was exceeded.

## `States.ItemReaderFailed`

Distributed Map could not read the dataset.

## `States.ResultWriterFailed`

Distributed Map could not write results.

([AWS Documentation][8])

---

# 47. `States.ALL` limitations

`States.ALL` is a wildcard, but:

* It must appear alone in a catcher.
* It does not catch `States.Runtime`.
* It does not catch `States.DataLimitExceeded` unless that error is named explicitly. ([AWS Documentation][8])

Bad assumption:

```text
Catch States.ALL
=
No execution can ever fail
```

State-machine-level timeouts and certain runtime failures still require external monitoring.

---

# 48. External handling for complete workflow failure

Catch blocks handle errors within Task, Parallel and Map states.

They do not wrap the complete state-machine execution itself. ([AWS Documentation][8])

For top-level failure handling:

```text
Step Functions execution
        |
        | FAILED / TIMED_OUT / ABORTED event
        v
EventBridge
        |
        ├── SNS alert
        ├── Incident Lambda
        ├── SQS remediation queue
        └── Recovery workflow
```

Standard execution status-change events can be delivered through EventBridge without continuously polling `DescribeExecution`. ([AWS Documentation][18])

---

# 49. Compensation and the saga pattern

Distributed systems rarely support one ACID transaction across:

* Payment provider.
* ECS service.
* DynamoDB.
* Email provider.
* External API.

Instead, use a saga.

```text
Step 1: Reserve resource
Step 2: Charge payment
Step 3: Activate subscription
Step 4: Send notification
```

If step 3 fails:

```text
Compensate step 2:
Refund payment

Compensate step 1:
Release resource
```

---

# 50. Saga workflow

```text
ReservePremiumSlot
        |
        v
ChargePayment
        |
        v
ActivatePremiumPlan
        |
        v
Complete
```

Failure path:

```text
ActivatePremiumPlan fails
        |
        v
RefundPayment
        |
        v
ReleasePremiumSlot
        |
        v
Workflow failed safely
```

The compensation operation is not a technical rollback in time.

It is a new business action:

```text
Charge:
₹999

Compensation:
Create refund for ₹999
```

---

# 51. Compensation-state example

```json
{
  "ChargePayment": {
    "Type": "Task",
    "Resource": "arn:aws:states:::lambda:invoke",
    "Arguments": {
      "FunctionName": "charge-payment",
      "Payload": "{% $states.input %}"
    },
    "Output": "{% $states.result.Payload %}",
    "Catch": [
      {
        "ErrorEquals": [
          "States.ALL"
        ],
        "Next": "ReleaseReservation"
      }
    ],
    "Next": "ActivatePlan"
  },
  "ActivatePlan": {
    "Type": "Task",
    "Resource": "arn:aws:states:::lambda:invoke",
    "Arguments": {
      "FunctionName": "activate-plan",
      "Payload": "{% $states.input %}"
    },
    "Catch": [
      {
        "ErrorEquals": [
          "States.ALL"
        ],
        "Next": "RefundPayment"
      }
    ],
    "Next": "Success"
  },
  "RefundPayment": {
    "Type": "Task",
    "Resource": "arn:aws:states:::lambda:invoke",
    "Arguments": {
      "FunctionName": "refund-payment",
      "Payload": "{% $states.input %}"
    },
    "Next": "ReleaseReservation"
  }
}
```

---

# 52. Compensation operations must be idempotent

Suppose:

```text
Refund succeeds
    |
    v
Network response is lost
    |
    v
Step Functions retries
```

Without idempotency:

```text
Customer receives two refunds
```

Use:

```text
refundIdempotencyKey =
originalPaymentId + workflowExecutionId
```

The payment service should return the original refund result when the same key is presented again.

Every compensation state should support safe repeated execution.

---

# 53. Idempotency design

An idempotent operation gives the same business result when repeated.

Example DynamoDB pattern:

```text
PK:
IDEMPOTENCY#execution-id#state-name
```

Conditional write:

```text
attribute_not_exists(PK)
```

Flow:

```text
State starts
    |
    v
Conditional idempotency write
    |
    ├── New operation → Perform work
    └── Already exists → Return saved result
```

Store:

* Workflow execution ID.
* State name.
* Business operation ID.
* Status.
* Result.
* Expiration time.

---

# 54. Business idempotency versus workflow idempotency

Workflow execution ID alone may not be enough.

Example:

```text
User presses "Upgrade" twice
    |
    v
Two different workflow executions
```

Use a business key:

```text
subscription-upgrade:
USER#104
PLAN#PREMIUM
BILLING_PERIOD#2026-08
```

Then two workflow executions still reference the same business action.

---

# 55. Redrive

Redrive restarts an unsuccessful Standard Workflow execution from the step that did not complete successfully.

Step Functions preserves successful state results and execution history rather than rerunning every successful earlier state. Eligible failed, aborted or timed-out Standard executions can currently be redriven during a 14-day period. Express Workflows do not support redrive. ([AWS Documentation][19])

```text
Validate input        → succeeded
Reserve resources     → succeeded
Charge payment        → succeeded
Activate account      → failed
Send notification     → not run
```

After redrive:

```text
Activate account      → rerun
Send notification     → continue if successful
```

---

# 56. Redrive behaviour

A redriven execution uses:

* The same execution ARN.
* The same original input.
* The same state-machine definition.
* The same version or alias association.
* Preserved results from successful states. ([AWS Documentation][19])

If you fix the state-machine definition after failure:

```text
Redrive:
Uses old definition

New StartExecution:
Uses updated definition
```

Therefore choose between:

```text
Redrive:
Transient failure fixed outside definition.

New execution:
Workflow logic itself was incorrect.
```

---

# 57. Redrive and retries

When redrive reruns a Task, Parallel or Inline Map state with configured retries, its retry-attempt count resets, allowing the retry policy to run again. ([AWS Documentation][8])

This means a downstream side effect may be attempted again.

Idempotency remains mandatory.

---

# 58. Redrive command

```bash
aws stepfunctions redrive-execution \
  --execution-arn "$EXECUTION_ARN" \
  --region ap-south-1
```

Inspect:

```bash
aws stepfunctions describe-execution \
  --execution-arn "$EXECUTION_ARN" \
  --region ap-south-1
```

Use redrive only after the root cause is corrected.

Examples:

* Restored database connectivity.
* Fixed missing IAM permission.
* Recreated missing secret.
* Resolved external vendor outage.
* Increased downstream capacity.

---

# 59. Nested workflows

One state machine can start another state machine.

```text
Parent:
UserOnboarding

Children:
├── CreateIdentity
├── CreateBillingProfile
├── ProvisionWorkspace
└── SendWelcomeMessage
```

Benefits:

* Smaller workflow definitions.
* Reusable business subflows.
* Independent ownership.
* Separate deployment lifecycle.
* Separate execution history.
* Easier testing.
* Reduced history-size pressure.

Step Functions supports starting nested state-machine executions through service integration. ([AWS Documentation][20])

---

# 60. Nested workflow example

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::states:startExecution.sync:2",
  "Arguments": {
    "StateMachineArn": "arn:aws:states:ap-south-1:123456789012:stateMachine:ExportUserData",
    "Input": {
      "userId": "{% $states.input.userId %}",
      "AWS_STEP_FUNCTIONS_STARTED_BY_EXECUTION_ID": "{% $states.context.Execution.Id %}"
    }
  },
  "Next": "DeleteUserData"
}
```

The special parent execution identifier helps link the child execution to its parent in the console and execution metadata. ([AWS Documentation][17])

---

# 61. Direct AWS service integrations

Do not create a Lambda merely to call one AWS API.

Unnecessary:

```text
Step Functions
    |
    v
Lambda
    |
    v
DynamoDB PutItem
```

Better:

```text
Step Functions
    |
    v
DynamoDB PutItem
```

Direct integrations reduce:

* Code.
* Runtime dependencies.
* Cold starts.
* Lambda cost.
* Deployment units.
* Failure points.

Use Lambda when you need genuine custom business logic—not simply an SDK wrapper.

---

# 62. Optimized versus AWS SDK integrations

## Optimized integration

Customised for workflow use.

Examples:

* Lambda output handling.
* ECS `.sync`.
* Batch `.sync`.
* DynamoDB operations.
* EventBridge event publishing.
* SQS message sending.

## AWS SDK integration

Calls an AWS API similarly to the AWS SDK.

AWS SDK integrations expose thousands of API operations across over 200 AWS services. AWS recommends optimized integrations when available because they provide workflow-specific behaviour. ([AWS Documentation][1])

---

# 63. EventBridge partial failures

An EventBridge `PutEvents` request may return HTTP 200 while individual entries fail.

Therefore inspect:

```text
FailedEntryCount
```

and per-entry error results.

A successful API response does not necessarily mean every event entry was accepted. ([AWS Documentation][21])

For critical events:

* Send one event per state.
* Inspect failure count.
* Retry only failed entries.
* Use deterministic event IDs.
* Consider an outbox pattern.

---

# 64. Calling HTTPS APIs

An HTTP Task calls an HTTPS endpoint directly:

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::http:invoke",
  "Arguments": {
    "ApiEndpoint": "https://api.example.com/v1/todos",
    "Method": "POST",
    "ConnectionArn": "arn:aws:events:ap-south-1:123456789012:connection/vendor-api/...",
    "RequestBody": {
      "todoId": "{% $states.input.todoId %}"
    }
  },
  "Next": "ProcessResponse"
}
```

HTTP Tasks use EventBridge Connections for authentication and can call public or supported private HTTPS APIs. The HTTP request-and-response duration has a hard limit of 60 seconds. ([AWS Documentation][22])

Use a callback pattern when the external operation takes longer than 60 seconds.

---

# 65. Cross-account service access

A Task state can assume a target IAM role to access a resource in another AWS account.

```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::lambda:invoke",
  "Credentials": {
    "RoleArn": "arn:aws:iam::222222222222:role/ProductionWorkflowTaskRole"
  },
  "Arguments": {
    "FunctionName": "arn:aws:lambda:ap-south-1:222222222222:function:production-task",
    "Payload": "{% $states.input %}"
  },
  "End": true
}
```

Step Functions supports cross-account access by assuming an IAM role specified for the task. ([AWS Documentation][23])

Use:

* Exact target roles.
* Least privilege.
* Organisation conditions.
* Restricted trust policies.
* Session tags where useful.

---

# 66. Execution role

Every state machine uses an IAM execution role.

```text
Step Functions
      |
      | Assumes execution role
      v
AWS services
```

The role may need permissions such as:

```text
lambda:InvokeFunction
dynamodb:PutItem
ecs:RunTask
iam:PassRole
events:PutEvents
sqs:SendMessage
states:StartExecution
logs:CreateLogDelivery
xray:PutTraceSegments
```

Grant only permissions required by the state-machine definition.

---

# 67. Restrict `iam:PassRole`

A workflow starting ECS tasks may need to pass:

* ECS task role.
* ECS task execution role.

Bad:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

Better:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": [
    "arn:aws:iam::123456789012:role/TodoExportTaskRole",
    "arn:aws:iam::123456789012:role/TodoExportExecutionRole"
  ],
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ecs-tasks.amazonaws.com"
    }
  }
}
```

Broad `iam:PassRole` could let the workflow launch work under an unintended privileged role.

---

# 68. Secrets

Do not place secrets directly in:

* State-machine definitions.
* Execution input.
* Execution names.
* CloudWatch log output.
* Error causes.
* EventBridge event details.
* Task-token URLs.

Use:

* Secrets Manager references.
* Parameter Store.
* Service-specific secret injection.
* EventBridge Connections.
* ECS task secrets.
* Lambda environment encryption.

Remember:

```text
Execution input and output
may appear in:
console history,
CloudWatch Logs,
debugging tools,
and audit workflows.
```

---

# 69. Logging configuration

Standard Workflows retain execution history in Step Functions.

Express Workflows require CloudWatch Logs for execution-level debugging. ([AWS Documentation][24])

Log levels include:

```text
ALL
ERROR
FATAL
OFF
```

You can also choose whether to include execution input and output data. ([Terraform Registry][25])

Production guidance:

```text
Development:
ALL with execution data

Production nonsensitive workflow:
ALL or ERROR according to volume

Sensitive workflow:
Log metadata but exclude execution data
```

---

# 70. CloudWatch metrics

Important Step Functions metrics include:

```text
ExecutionsStarted
ExecutionsSucceeded
ExecutionsFailed
ExecutionsTimedOut
ExecutionsAborted
ExecutionTime
ExecutionThrottled
ActivitiesTimedOut
ActivitiesFailed
ExpressExecutionBilledDuration
ExpressExecutionBilledMemory
```

Step Functions metrics can use at-least-once and best-effort delivery, so status metrics may occasionally emit more than once. ([AWS Documentation][26])

Create alarms for:

```text
ExecutionsFailed > 0
ExecutionsTimedOut > 0
ExecutionThrottled > 0
Failure rate above threshold
p95 execution duration increasing
Open executions approaching quota
```

---

# 71. EventBridge execution events

Standard Workflow execution-status changes can be sent to EventBridge.

```text
Step Functions
      |
      | ExecutionStatusChange
      v
EventBridge
      |
      ├── SNS
      ├── Lambda
      ├── SQS
      ├── Incident system
      └── Recovery workflow
```

Example pattern:

```json
{
  "source": [
    "aws.states"
  ],
  "detail-type": [
    "Step Functions Execution Status Change"
  ],
  "detail": {
    "status": [
      "FAILED",
      "TIMED_OUT",
      "ABORTED"
    ]
  }
}
```

Step Functions sends execution events to the account’s default EventBridge bus. ([AWS Documentation][18])

---

# 72. X-Ray tracing

X-Ray can provide trace visibility across a Step Functions workflow and integrated services.

```text
API request
    |
    v
Step Functions
    |
    ├── Lambda
    ├── DynamoDB
    └── ECS/API call
```

Enable tracing to correlate:

* Workflow execution.
* Lambda invocation.
* Downstream service calls.
* Latency.
* Errors.

X-Ray does not trace child executions started by Distributed Map because of trace-document size constraints. ([AWS Documentation][27])

---

# 73. Workflow versions

A state-machine version is:

```text
Numbered
Immutable
Executable
```

Example:

```text
TodoWorkflow:1
TodoWorkflow:2
TodoWorkflow:3
```

A revision is an immutable snapshot created when the state machine is updated, but it cannot be executed directly. A published version has its own ARN and can be invoked. ([AWS Documentation][28])

---

# 74. Aliases

An alias points to one or two state-machine versions.

```text
Alias:
PROD
  |
  ├── Version 8 → 90%
  └── Version 9 → 10%
```

Aliases can route execution traffic gradually between versions for canary workflow deployment. ([AWS Documentation][28])

Application configuration:

```text
Call:
arn:aws:states:ap-south-1:123456789012:stateMachine:TodoWorkflow:PROD
```

The application does not need to know which numeric version currently receives traffic.

---

# 75. Canary deployment

Deployment:

```text
Version 8:
Stable

Version 9:
New workflow
```

Phase 1:

```text
PROD alias:
Version 8 = 90%
Version 9 = 10%
```

Monitor:

* Failure rate.
* Execution duration.
* Downstream error rate.
* Compensation rate.
* Business completion rate.

Phase 2:

```text
Version 9 = 100%
```

Rollback:

```text
Version 8 = 100%
```

Aliases support routing to at most two versions, enabling gradual rollout. ([AWS Documentation][28])

---

# 76. Why call an alias instead of the unqualified ARN?

Unqualified ARN:

```text
stateMachine:TodoWorkflow
```

uses the latest state-machine revision when an execution starts.

Alias ARN:

```text
stateMachine:TodoWorkflow:PROD
```

uses controlled version routing. ([AWS Documentation][28])

Production recommendation:

```text
Applications call aliases:
DEV
STAGING
PROD
```

not the continuously changing unqualified definition.

---

# 77. Testing workflows

Test at several levels.

## Definition validation

Check:

* Valid ASL.
* Valid transitions.
* Valid terminal states.
* Correct integration parameters.
* Correct JSONPath or JSONata.

## Unit testing

Test individual:

* Lambda functions.
* Compensation actions.
* Idempotency logic.
* Approval handlers.
* Data transforms.

## Integration testing

Run the state machine against test AWS resources.

## Failure testing

Inject:

* Lambda exceptions.
* Throttling.
* Timeouts.
* Callback expiration.
* Permission denial.
* Poison Map items.
* Downstream unavailability.

Step Functions supports mocked service integrations for workflow testing scenarios, reducing the need to invoke every real dependency during tests. ([AWS Documentation][29])

---

# 78. Production TodoApp deletion workflow

```text
Deletion requested
        |
        v
Validate request
        |
        v
Check legal retention
        |
       / \
 Retain   Continue
   |         |
   v         v
Reject   Wait cooling period
                |
                v
          Request approval
                |
              /   \
          Approve Reject
             |      |
             v      v
       Export data Cancel
             |
             v
       Delete search docs
             |
             v
       Delete todo records
             |
             v
       Disable account
             |
             v
       Publish audit event
             |
             v
           Success
```

Recommended state-machine type:

```text
Standard
```

because it may:

* Wait for several days.
* Wait for human approval.
* Run ECS export tasks.
* Require full execution history.
* Need compensation and redrive.

---

# 79. TodoApp bulk import workflow

```text
CSV uploaded to S3
        |
        v
Validate file metadata
        |
        v
Distributed Map
├── Parse row
├── Validate todo
├── Write DynamoDB
├── Publish event
└── Record failed row
        |
        v
Write import summary
        |
        v
Notify user
```

Recommended:

```text
Standard parent
+
Express Distributed Map children
```

where each row operation is:

* Short.
* High volume.
* Idempotent.
* Independently retryable.

---

# 80. TodoApp premium upgrade saga

```text
Reserve premium capacity
        |
        v
Charge payment
        |
        v
Enable premium plan
        |
        v
Send confirmation
```

Failure compensation:

```text
Enable premium fails
        |
        v
Refund payment
        |
        v
Release reservation
```

Each action should use:

```text
business idempotency key
+
workflow execution ID
+
operation name
```

---

# 81. Terraform execution role

```hcl
resource "aws_iam_role" "step_functions" {
  name = "production-todo-workflow"

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

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 82. Terraform least-privilege policy

```hcl
resource "aws_iam_role_policy" "step_functions" {
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "InvokeWorkflowFunctions"
        Effect = "Allow"

        Action = [
          "lambda:InvokeFunction"
        ]

        Resource = [
          aws_lambda_function.validate_deletion.arn,
          aws_lambda_function.delete_search_documents.arn,
          aws_lambda_function.publish_audit.arn
        ]
      },
      {
        Sid    = "RunExportTask"
        Effect = "Allow"

        Action = [
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks"
        ]

        Resource = [
          aws_ecs_task_definition.user_export.arn,
          "${aws_ecs_cluster.production.arn}/*"
        ]
      },
      {
        Sid    = "PassExportRoles"
        Effect = "Allow"

        Action = [
          "iam:PassRole"
        ]

        Resource = [
          aws_iam_role.export_task.arn,
          aws_iam_role.export_execution.arn
        ]

        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },
      {
        Sid    = "SendApprovalMessage"
        Effect = "Allow"

        Action = [
          "sqs:SendMessage"
        ]

        Resource = aws_sqs_queue.approvals.arn
      },
      {
        Sid    = "PublishAuditEvents"
        Effect = "Allow"

        Action = [
          "events:PutEvents"
        ]

        Resource = aws_cloudwatch_event_bus.application.arn
      }
    ]
  })
}
```

---

# 83. Terraform CloudWatch log group

```hcl
resource "aws_cloudwatch_log_group" "workflow" {
  name              = "/aws/stepfunctions/production-todo-deletion"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs.arn

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 84. Terraform state machine

```hcl
resource "aws_sfn_state_machine" "account_deletion" {
  name     = "production-todo-account-deletion"
  role_arn = aws_iam_role.step_functions.arn

  type = "STANDARD"

  definition = templatefile(
    "${path.module}/account-deletion.asl.json",
    {
      validation_function_arn = aws_lambda_function.validate_deletion.arn
      approval_queue_url      = aws_sqs_queue.approvals.url
      ecs_cluster_arn         = aws_ecs_cluster.production.arn
      task_definition_arn     = aws_ecs_task_definition.user_export.arn
      private_subnet_ids      = jsonencode([
        aws_subnet.private_a.id,
        aws_subnet.private_b.id
      ])
      task_security_group_id = aws_security_group.export_task.id
    }
  )

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.workflow.arn}:*"
    include_execution_data = false
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  encryption_configuration {
    type       = "CUSTOMER_MANAGED_KMS_KEY"
    kms_key_id = aws_kms_key.step_functions.arn
  }

  publish = true

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

The current HashiCorp AWS provider supports logging, tracing, customer-managed KMS encryption and publishing state-machine versions through `aws_sfn_state_machine`. ([Terraform Registry][30])

---

# 85. Terraform alias

```hcl
resource "aws_sfn_alias" "production" {
  name        = "PROD"
  description = "Production TodoApp account-deletion workflow"

  routing_configuration {
    state_machine_version_arn = (
      aws_sfn_state_machine.account_deletion.state_machine_version_arn
    )

    weight = 100
  }
}
```

Canary configuration:

```hcl
resource "aws_sfn_alias" "production" {
  name = "PROD"

  routing_configuration {
    state_machine_version_arn = var.stable_version_arn
    weight                    = 90
  }

  routing_configuration {
    state_machine_version_arn = var.candidate_version_arn
    weight                    = 10
  }
}
```

Terraform aliases support one or two version routing configurations with percentage weights. ([Terraform Registry][31])

---

# 86. Start an execution

```bash
EXECUTION_NAME="delete-user-104-$(date +%Y%m%d%H%M%S)"

aws stepfunctions start-execution \
  --state-machine-arn "$PRODUCTION_ALIAS_ARN" \
  --name "$EXECUTION_NAME" \
  --input '{
    "requestId": "delete-request-501",
    "userId": "104",
    "requestedBy": "user-104"
  }' \
  --region ap-south-1
```

Use a meaningful execution name containing a safe business identifier.

Do not include:

* Passwords.
* Email addresses where avoidable.
* Tokens.
* Secret values.
* Full personally identifying information.

---

# 87. Inspect execution history

```bash
aws stepfunctions describe-execution \
  --execution-arn "$EXECUTION_ARN" \
  --region ap-south-1
```

History:

```bash
aws stepfunctions get-execution-history \
  --execution-arn "$EXECUTION_ARN" \
  --reverse-order \
  --max-results 100 \
  --region ap-south-1
```

`GetExecutionHistory` is available for Standard executions, not Express executions. ([AWS Documentation][32])

For Express, use CloudWatch Logs.

---

# 88. Production alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "workflow_failures" {
  alarm_name = "production-todo-workflow-failures"

  namespace   = "AWS/States"
  metric_name = "ExecutionsFailed"

  dimensions = {
    StateMachineArn = aws_sfn_alias.production.arn
  }

  statistic = "Sum"
  period    = 300

  evaluation_periods  = 1
  datapoints_to_alarm = 1

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  alarm_actions = [
    aws_sns_topic.operations.arn
  ]

  treat_missing_data = "notBreaching"
}
```

Also alarm on:

```text
ExecutionsTimedOut
ExecutionThrottled
ExecutionsAborted
Execution duration SLO
Distributed Map failures
Callback timeout count
Compensation count
```

---

# 89. Cost model

## Standard

Charged primarily by:

```text
State transitions
```

Example:

```text
Validate
Choice
Write DynamoDB
Parallel
Notify
Succeed
```

Each completed state transition contributes to cost. ([AWS Documentation][3])

## Express

Charged based on:

```text
Executions
+
Duration
+
Memory consumption
```

([AWS Documentation][3])

---

# 90. Cost optimization

Avoid unnecessary transitions.

Inefficient:

```text
Task
Wait 1 second
Task
Wait 1 second
Task
Wait 1 second
```

Better:

* Use `.sync`.
* Use a callback token.
* Increase polling interval.
* Batch records.
* Use Express for high-volume short workflows.
* Use nested Express workflows for repetitive idempotent work.
* Use direct AWS service integrations.
* Use Distributed Map carefully.

Never remove essential validation, error handling or compensation merely to reduce transitions.

---

# 91. Troubleshooting `States.Permissions`

Symptoms:

```text
States.Permissions
AccessDeniedException
not authorized to perform ...
```

Check:

1. State-machine execution role.
2. Exact resource ARN.
3. Resource-based policy.
4. KMS key policy.
5. `iam:PassRole`.
6. Cross-account trust policy.
7. Permissions boundary.
8. Service control policy.
9. VPC endpoint policy.
10. Alias or version permission.

The error means the state lacked sufficient privileges to perform its operation. ([AWS Documentation][8])

---

# 92. Troubleshooting Lambda output

Optimized Lambda invocation returns a structure containing fields such as:

```json
{
  "ExecutedVersion": "$LATEST",
  "Payload": {
    "result": "success"
  },
  "StatusCode": 200
}
```

If you pass the entire response forward accidentally, later states may expect:

```text
$.result
```

but the data is actually:

```text
$.Payload.result
```

Use JSONata:

```json
"Output": "{% $states.result.Payload %}"
```

or JSONPath `OutputPath`/`ResultSelector`.

---

# 93. Troubleshooting `States.Runtime`

Common causes:

* `InputPath` selects data that does not exist.
* `OutputPath` is applied to `null`.
* JSONata expression returns the wrong type.
* Choice comparison receives an unexpected type.
* A required variable is unavailable.
* Result transformation assumes a different service response.

`States.Runtime` cannot be retried and is not caught by `States.ALL`. ([AWS Documentation][8])

Fix the workflow definition or input contract.

---

# 94. Troubleshooting `States.DataLimitExceeded`

Check:

* Lambda output size.
* Service-integration output.
* Map result array.
* Parallel result array.
* Execution input.
* Included stack traces.
* Base64 data.
* Full database result set.
* Distributed Map result output.

Fix:

```text
Write large data to S3
+
Pass an S3 reference
```

Do not repeatedly retry an oversized payload.

---

# 95. Troubleshooting callback never completes

Check:

* Worker received the token.
* Token was not altered or truncated.
* `SendTaskSuccess` or `SendTaskFailure` was called.
* Worker used the correct Region.
* Token has not timed out.
* Approval ID maps to the correct token.
* IAM caller has `states:SendTaskSuccess`.
* Heartbeats are being sent.
* Worker logs do not expose the token.
* The workflow execution is still running.

Use both:

```text
HeartbeatSeconds
TimeoutSeconds
```

to prevent indefinite waits. AWS recommends heartbeats for callback tasks. ([AWS Documentation][16])

---

# 96. Troubleshooting `.sync` task remains running

Check:

* External job is actually running.
* Step Functions execution role can describe the job.
* EventBridge permissions exist where required.
* Cross-account polling permissions exist.
* ECS task or Batch job has enough capacity.
* Job entered a terminal state.
* Workflow timeout is sufficient.

For same-account `.sync` operations, Step Functions may combine EventBridge events with API polling to monitor completion. Cross-account `.sync` integrations rely on polling the target resource. ([AWS Documentation][6])

---

# 97. Troubleshooting Express history missing

This is expected unless logging is configured.

```text
Express execution
    |
    v
No Step Functions-managed execution history
```

Configure CloudWatch Logs:

```hcl
logging_configuration {
  log_destination        = "${aws_cloudwatch_log_group.workflow.arn}:*"
  include_execution_data = true
  level                  = "ALL"
}
```

Express workflow history depends on CloudWatch Logs. ([AWS Documentation][24])

---

# 98. Troubleshooting Distributed Map backlog

Check:

* Open Map Run quota.
* Child execution concurrency.
* Standard or Express child dispatch rates.
* Downstream Lambda concurrency.
* S3 ItemReader permissions.
* S3 ResultWriter permissions.
* Failure threshold.
* Child execution failures.

The current hard quotas include 1,000 open Map Runs and up to 10,000 parallel child executions per Map Run. ([AWS Documentation][33])

---

# 99. Troubleshooting HTTP Task timeout

HTTP Tasks have a hard request-and-response duration limit of:

```text
60 seconds
```

([AWS Documentation][4])

If the external system takes longer:

```text
HTTP Task starts job
      |
      v
External system immediately returns job ID
      |
      v
Use polling with Wait
or
callback task token
```

Do not increase `TimeoutSeconds` expecting the HTTP connection itself to remain open beyond the service limit.

---

# 100. Troubleshooting execution throttling

Metric:

```text
ExecutionThrottled
```

Standard Workflow state transitions use regional token-bucket quotas. Express transitions do not use the same state-transition quota model. In Regions other than the largest listed regions, the current default Standard state-transition bucket and refill rate are lower, so high-volume systems should monitor and request quota increases before launch. ([AWS Documentation][4])

Actions:

* Request quota increase.
* Reduce unnecessary states.
* Use Express for suitable high-volume short workflows.
* Distribute workloads across accounts or Regions only when architecturally valid.
* Avoid retry storms.
* Stagger batch starts.

---

# 101. Production checklist

```text
[ ] Standard versus Express decision is documented
[ ] Workflow type matches maximum duration
[ ] Express operations are idempotent
[ ] State-machine definition is stored in Git
[ ] State machine uses a production alias
[ ] Versions are published for releases
[ ] Canary routing is available
[ ] Execution role is least privilege
[ ] iam:PassRole is restricted
[ ] Secrets are absent from workflow payloads
[ ] Large data is stored in S3
[ ] Payload remains under 256 KiB
[ ] Standard history remains under 25,000 events
[ ] Long-running workflows can continue as new executions
[ ] Every external task has TimeoutSeconds
[ ] Callback tasks have HeartbeatSeconds
[ ] Retries target only transient failures
[ ] Backoff and jitter are configured
[ ] Retry count is bounded
[ ] Catch paths preserve error information
[ ] Top-level failures emit EventBridge alerts
[ ] Business operations are idempotent
[ ] Compensation operations are idempotent
[ ] Compensation failures are monitored
[ ] Human approvals are authenticated
[ ] Task tokens are protected
[ ] Map concurrency protects downstream services
[ ] Distributed Map failure thresholds are intentional
[ ] Distributed Map results are stored in S3 when large
[ ] Redrive procedures are documented
[ ] Redrive versus new execution decision is clear
[ ] Nested workflows are used for reusable subflows
[ ] Direct integrations replace unnecessary Lambda wrappers
[ ] CloudWatch Logs are enabled
[ ] Sensitive execution data is excluded from logs
[ ] CloudWatch alarms exist
[ ] X-Ray is enabled where useful
[ ] Workflow failure injection has been tested
[ ] Timeout and retry behaviour has been tested
[ ] Rollback and compensation have been tested
```

---

# 102. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
AWS Step Functions:
Managed workflow orchestration

State machine:
Workflow definition

Execution:
One workflow run

Task:
Performs work

Choice:
Conditional branch

Wait:
Pauses workflow
```

## Solutions Architect Associate

Understand:

```text
Standard versus Express
Task, Choice, Parallel and Map
Service integrations
Retries and catches
Callback task tokens
Execution roles
Direct Lambda/DynamoDB/SQS integrations
Human approval
```

## DevOps Engineer Professional

Understand:

```text
Exactly-once versus at-least-once semantics
Idempotency
Saga compensation
Distributed Map
Failure thresholds
Execution redrive
Versions and aliases
Canary workflow deployment
Cross-account task roles
Execution throttling
CloudWatch and EventBridge monitoring
```

---

# 103. Interview questions

## Question 1: What is AWS Step Functions?

**Answer:**

AWS Step Functions is a managed workflow-orchestration service that coordinates AWS services, applications and external systems through visual state machines.

## Question 2: What is the difference between a state machine and an execution?

**Answer:**

A state machine is the workflow definition. An execution is one running instance of that definition.

## Question 3: What is the difference between Standard and Express Workflows?

**Answer:**

Standard Workflows support long-running, durable, auditable orchestration for up to one year. Express Workflows support high-volume, short workflows running for up to five minutes.

## Question 4: What execution model does Standard use?

**Answer:**

Standard uses an exactly-once workflow-execution model, although configured retries, redrives and external service behaviour still require idempotent business actions.

## Question 5: What execution models do Express Workflows use?

**Answer:**

Asynchronous Express uses at-least-once execution. Synchronous Express uses at-most-once execution.

## Question 6: What are the three Step Functions integration patterns?

**Answer:**

Request-response, run-a-job using `.sync`, and callback using `.waitForTaskToken`.

## Question 7: When would you use `.sync`?

**Answer:**

Use it when Step Functions should start a supported long-running job, such as an ECS, Batch or Glue job, and wait for it to complete.

## Question 8: What is a task token?

**Answer:**

It is a unique token representing a waiting Task state. An external worker uses it with `SendTaskSuccess` or `SendTaskFailure` to resume the workflow.

## Question 9: What is the difference between timeout and heartbeat?

**Answer:**

Timeout limits the task’s total duration. Heartbeat limits how long a worker can remain silent between progress signals.

## Question 10: What does `Retry` do?

**Answer:**

It automatically reruns Task, Parallel or Map states for matching errors using configurable intervals, attempts and backoff.

## Question 11: What does `Catch` do?

**Answer:**

It routes a failed Task, Parallel or Map state to a recovery state after retries are exhausted.

## Question 12: What is the saga pattern?

**Answer:**

It coordinates several local transactions and performs compensating actions when a later operation fails.

## Question 13: What is Inline Map?

**Answer:**

It processes a JSON array inside the parent execution, with up to 40 concurrent iterations and shared parent execution history.

## Question 14: What is Distributed Map?

**Answer:**

It processes large datasets using separate child workflow executions, supporting up to 10,000 concurrent child executions and S3 input sources.

## Question 15: What is the Step Functions payload limit?

**Answer:**

The maximum state, task or execution input or output is 256 KiB.

## Question 16: What is the Standard execution-history limit?

**Answer:**

A Standard execution can contain up to 25,000 history events.

## Question 17: What is redrive?

**Answer:**

Redrive restarts an unsuccessful Standard execution from its failed step while preserving successful earlier state results.

## Question 18: Why use state-machine aliases?

**Answer:**

Aliases provide stable invocation ARNs and can route traffic between up to two immutable workflow versions for canary deployments.

## Question 19: Why are idempotent actions important?

**Answer:**

Retries, redrives, duplicate external calls and repeated workflow starts can execute the same business operation more than once.

## Question 20: How should a complete workflow failure be monitored?

**Answer:**

Use CloudWatch metrics and EventBridge execution-status events to trigger alerts or remediation for failed, timed-out or aborted executions.

---

# 104. Never-forget revision

```text
Step Functions:
Managed workflow orchestrator.

State machine:
Workflow definition.

Execution:
One workflow run.

Standard:
Long-running and auditable.

Express:
Short and high volume.

Task:
Performs work.

Choice:
Conditional branch.

Wait:
Pauses execution.

Parallel:
Runs different branches concurrently.

Map:
Repeats one workflow over items.

Inline Map:
Up to 40 concurrent iterations.

Distributed Map:
Up to 10,000 child executions.

Request Response:
Wait for immediate API response.

.sync:
Wait for a job to finish.

.waitForTaskToken:
Wait for an external callback.

Retry:
Repeat transiently failed work.

Catch:
Route failed work to recovery.

Heartbeat:
Proof that a worker is still active.

Timeout:
Maximum allowed duration.

Saga:
Local transactions plus compensation.

Idempotency:
Safe repeated execution.

Redrive:
Resume failed Standard execution.

Version:
Immutable executable workflow snapshot.

Alias:
Stable pointer with weighted version routing.

JSONPath:
Path-based JSON processing.

JSONata:
Expression-based transformation.

Execution role:
AWS permissions used by the workflow.
```

## One-line memory trick

```text
Model the process visibly.
Call services directly.
Retry only temporary failures.
Time out every external task.
Make every action idempotent.
Compensate instead of pretending to roll back.
Version the workflow.
Monitor the business result.
```

## Lesson 51 outcome

You can now design workflows where:

```text
A process lasts several days
    → Standard Workflow preserves its state.

Millions of short events need transformation
    → Express Workflow handles high volume.

An ECS export job must complete first
    → .sync waits for task completion.

A human must approve deletion
    → Task token pauses the workflow.

A vendor API is temporarily unavailable
    → Retry uses backoff and jitter.

A later business action fails
    → Saga compensation reverses previous effects.

A CSV contains millions of records
    → Distributed Map processes child executions.

The workflow reaches a temporary failure
    → Redrive resumes from the failed state.

A new workflow definition needs safe release
    → Versions and aliases provide canary routing.

The complete execution fails
    → EventBridge and CloudWatch trigger an incident.
```

**Next lesson: Lesson 52 — Amazon SQS, SNS and EventBridge production messaging architecture: queues, topics, event buses, ordering, retries, dead-letter queues, deduplication, filtering, fan-out, Pipes, Scheduler and event-driven design.**

[1]: https://docs.aws.amazon.com/step-functions/latest/dg/integrate-services.html?utm_source=chatgpt.com "Integrating services with Step Functions - AWS Step Functions"
[2]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-statemachines.html?utm_source=chatgpt.com "Learn about state machines in Step Functions - AWS Step Functions"
[3]: https://docs.aws.amazon.com/step-functions/latest/dg/choosing-workflow-type.html "Choosing workflow type in Step Functions - AWS Step Functions"
[4]: https://docs.aws.amazon.com/step-functions/latest/dg/service-quotas.html "Step Functions service quotas - AWS Step Functions"
[5]: https://docs.aws.amazon.com/step-functions/latest/dg/integrate-optimized.html?utm_source=chatgpt.com "Integrating optimized services with Step Functions - AWS Step Functions"
[6]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-to-resource.html?utm_source=chatgpt.com "Discover service integration patterns in Step Functions - AWS Step Functions"
[7]: https://docs.aws.amazon.com/step-functions/latest/dg/tutorial-human-approval.html?utm_source=chatgpt.com "Deploying a workflow that waits for human approval in Step Functions - AWS Step Functions"
[8]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html "Handling errors in Step Functions workflows - AWS Step Functions"
[9]: https://docs.aws.amazon.com/step-functions/latest/dg/state-wait.html?utm_source=chatgpt.com "Wait workflow state - AWS Step Functions"
[10]: https://docs.aws.amazon.com/step-functions/latest/dg/state-choice.html?utm_source=chatgpt.com "Choice workflow state - AWS Step Functions"
[11]: https://docs.aws.amazon.com/step-functions/latest/dg/state-parallel.html?utm_source=chatgpt.com "Parallel workflow state - AWS Step Functions"
[12]: https://docs.aws.amazon.com/step-functions/latest/dg/state-map-inline.html?utm_source=chatgpt.com "Using Map state in Inline mode in Step Functions workflows - AWS Step Functions"
[13]: https://docs.aws.amazon.com/step-functions/latest/dg/state-map-distributed.html?utm_source=chatgpt.com "Using Map state in Distributed mode for large-scale parallel workloads in Step Functions - AWS Step Functions"
[14]: https://docs.aws.amazon.com/step-functions/latest/dg/transforming-data.html?utm_source=chatgpt.com "Transforming data with JSONata in Step Functions - AWS Step Functions"
[15]: https://docs.aws.amazon.com/step-functions/latest/dg/workflow-variables.html?utm_source=chatgpt.com "Passing data between states with variables - AWS Step Functions"
[16]: https://docs.aws.amazon.com/step-functions/latest/dg/sfn-best-practices.html?utm_source=chatgpt.com "Best practices for Step Functions - AWS Step Functions"
[17]: https://docs.aws.amazon.com/step-functions/latest/dg/tutorial-continue-new.html?utm_source=chatgpt.com "Continue long-running workflows using Step Functions API (recommended) - AWS Step Functions"
[18]: https://docs.aws.amazon.com/step-functions/latest/dg/eventbridge-integration.html?utm_source=chatgpt.com "Automating Step Functions event delivery with EventBridge - AWS Step Functions"
[19]: https://docs.aws.amazon.com/step-functions/latest/dg/redrive-executions.html?utm_source=chatgpt.com "Restarting state machine executions with redrive in Step Functions - AWS Step Functions"
[20]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-stepfunctions.html?utm_source=chatgpt.com "Start a new AWS Step Functions state machine from a running execution - AWS Step Functions"
[21]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-eventbridge.html?utm_source=chatgpt.com "Add EventBridge events with Step Functions - AWS Step Functions"
[22]: https://docs.aws.amazon.com/step-functions/latest/dg/call-https-apis.html?utm_source=chatgpt.com "Call HTTPS APIs in Step Functions workflows - AWS Step Functions"
[23]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-access-cross-acct-resources.html?utm_source=chatgpt.com "Accessing resources in other AWS accounts in Step Functions - AWS Step Functions"
[24]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-view-execution-details.html?utm_source=chatgpt.com "Viewing execution details in the Step Functions console - AWS Step Functions"
[25]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine.html?utm_source=chatgpt.com "aws_sfn_state_machine | Resources | hashicorp/aws | Terraform | Terraform Registry"
[26]: https://docs.aws.amazon.com/step-functions/latest/dg/procedure-cw-metrics.html?utm_source=chatgpt.com "Monitoring Step Functions metrics using Amazon CloudWatch - AWS Step Functions"
[27]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-xray-tracing.html?utm_source=chatgpt.com "Trace Step Functions request data in AWS X-Ray - AWS Step Functions"
[28]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-cd-aliasing-versioning.html "Manage continuous deployments with versions and aliases in Step Functions - AWS Step Functions"
[29]: https://docs.aws.amazon.com/step-functions/latest/dg/concepts-cd-aliasing-versioning.html?utm_source=chatgpt.com "Manage continuous deployments with versions and aliases in Step Functions - AWS Step Functions"
[30]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine?utm_source=chatgpt.com "aws_sfn_state_machine | Resources | hashicorp/aws | Terraform | Terraform Registry"
[31]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_alias?utm_source=chatgpt.com "aws_sfn_alias | Resources | hashicorp/aws | Terraform | Terraform Registry"
[32]: https://docs.aws.amazon.com/step-functions/latest/apireference/API_GetExecutionHistory.html?utm_source=chatgpt.com "GetExecutionHistory - AWS Step Functions"
[33]: https://docs.aws.amazon.com/step-functions/latest/dg/service-quotas.html?utm_source=chatgpt.com "Step Functions service quotas - AWS Step Functions"
Lesson 13.53..md
