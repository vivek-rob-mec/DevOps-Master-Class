# AWS Masterclass — Lesson 34 Part 3

# Amazon EventBridge in Depth

## Event Buses, Rules, Event Patterns, Pipes, Scheduler, Archives, Replay, Cross-Account Routing, Global Endpoints & Production Event Architecture

We have now learned:

```text
SQS
=
DURABLE WORK QUEUE


SNS
=
PUB/SUB FAN-OUT
```

Now we introduce a third messaging primitive:

```text
EventBridge
=
EVENT ROUTING FABRIC
```

The mental model is:

```text
                         EVENT PRODUCERS

             AWS Services
                  │
          Your Applications
                  │
           SaaS Providers
                  │
                  ▼
             EVENTBRIDGE
               EVENT BUS
                  │
       ┌──────────┼──────────┐
       ▼          ▼          ▼
     Rule A     Rule B     Rule C
       │          │          │
       ▼          ▼          ▼
      SQS       Lambda    Step Functions
```

Amazon EventBridge is a serverless event-routing service for building event-driven systems. Event buses are designed for **many-source → many-target** routing, while EventBridge Pipes is designed for **point-to-point** integrations between one source and one target. ([AWS Documentation][1])

---

# Part A — The Event-Driven Architecture Mental Model

## 1. Command vs Event

This distinction is fundamental.

### Command

```text
CreateInvoice
SendEmail
ChargePayment
```

means:

> “I want someone to perform this action.”

### Event

```text
OrderCreated
PaymentAuthorized
InvoiceGenerated
UserRegistered
```

means:

> “Something already happened.”

That distinction changes system coupling.

---

# 2. Command-Oriented Architecture

Example:

```text
Order Service
    │
    ├── call Inventory
    ├── call Email
    ├── call Analytics
    ├── call CRM
    └── call Fraud
```

The Order service knows:

```text
who
```

needs to react.

That creates coupling.

---

# 3. Event-Oriented Architecture

Better:

```text
Order Service
     │
     ▼
"OrderCreated"
     │
     ▼
EventBridge
     │
 ┌───┼────────────┬───────────┐
 ▼   ▼            ▼           ▼
Fraud Analytics Inventory   Email
```

The producer says only:

```text
An order was created.
```

It does **not** need to know every consumer.

That is the heart of:

# Event-Driven Architecture — EDA

---

# 4. EventBridge's Role

EventBridge receives events and evaluates them against:

```text
RULES
```

Each rule contains an:

```text
EVENT PATTERN
```

If the event matches:

```text
EVENT
  │
  ▼
RULE
  │
 match?
  │
 YES
  ▼
TARGET
```

An EventBridge rule sends matching events to configured targets; each rule can currently have up to five targets. ([AWS Documentation][2])

---

# Part B — Event Structure

## 5. EventBridge Event Envelope

A typical EventBridge event looks conceptually like:

```json
{
  "version": "0",
  "id": "event-id",
  "detail-type": "Order Created",
  "source": "com.company.orders",
  "account": "123456789012",
  "time": "2026-08-14T05:30:00Z",
  "region": "ap-south-1",
  "resources": [],
  "detail": {
    "orderId": "ORD-1001",
    "customerId": "CUS-2001",
    "amount": 12000
  }
}
```

The most important fields for application event design are often:

```text
source

detail-type

detail
```

because rules commonly use these to decide where events should go. Event patterns can match event metadata and values inside `detail`. ([AWS Documentation][3])

---

# 6. `source`

Example:

```json
"source": "com.yourdatascientist.orders"
```

Think:

```text
WHO PRODUCED THIS EVENT?
```

Good sources are stable logical namespaces.

Examples:

```text
com.company.orders

com.company.payments

com.company.identity
```

Avoid meaningless:

```text
app1
service2
misc
```

---

# 7. `detail-type`

Example:

```json
"detail-type": "Order Created"
```

Think:

```text
WHAT HAPPENED?
```

Other examples:

```text
Order Cancelled

Payment Failed

User Registered

Deployment Completed
```

---

# 8. `detail`

This contains domain-specific payload:

```json
{
  "orderId": "ORD-1001",
  "status": "CREATED",
  "total": 12000
}
```

This should describe enough about the event for consumers to decide what to do without exposing unnecessary internal implementation details.

---

# 9. Event Naming Philosophy

Prefer past-tense facts:

```text
OrderCreated

PaymentCaptured

UserSuspended
```

over command-like event names:

```text
CreateOrder

CapturePayment

SuspendUser
```

The first says:

```text
something happened.
```

The second says:

```text
someone should do something.
```

That difference matters greatly once many services depend on your event contracts.

---

# Part C — Event Buses

## 10. What Is an Event Bus?

An:

# Event Bus

is the routing surface that receives events and evaluates them against rules.

```text
              Event Bus

Event 1 ───────┐
Event 2 ───────┤
Event 3 ───────┤
AWS events ────┘
               │
         ┌─────┼─────┐
         ▼     ▼     ▼
       Rule A Rule B Rule C
```

EventBridge supports default, custom, and partner event-bus patterns. ([AWS Documentation][4])

---

# 11. Default Event Bus

Every AWS account/Region has a:

```text
default event bus
```

which automatically receives supported AWS service events. ([AWS Documentation][4])

Example:

```text
EC2 state changed
        │
        ▼
Default Event Bus
        │
        ▼
Rule:
state = stopped
        │
        ▼
SNS / Lambda / automation
```

---

# 12. Default Bus Is Excellent for AWS Events

Examples:

```text
EC2 instance state changes

EBS snapshot events

CloudTrail API events

Auto Scaling events

some service status events
```

depending on service integration.

So if the requirement says:

> “React whenever an EC2 instance changes state.”

Start thinking:

```text
EventBridge default bus
```

---

# 13. Custom Event Bus

For application/domain events, create:

```text
custom event bus
```

Example:

```text
orders-bus
```

Architecture:

```text
Order Service
      │
      ▼
PutEvents
      │
      ▼
orders-bus
      │
 ┌────┼────┐
 ▼    ▼    ▼
Rules...
```

Custom buses can also be configured with resource policies, KMS encryption choices, archives, and related controls. ([AWS Documentation][5])

---

# 14. Why Separate Buses?

You might have:

```text
default
security-events
application-events
audit-events
```

Benefits can include:

```text
clear ownership

different resource policies

different archives

logical boundaries

different consumers
```

But do not create hundreds of buses merely for decoration.

Use buses to represent meaningful:

```text
routing
security
ownership
or lifecycle
```

boundaries.

---

# 15. Partner Event Bus

EventBridge can receive events from supported SaaS partners.

Architecture:

```text
SaaS Partner
     │
     ▼
Partner Event Source
     │
     ▼
Partner Event Bus
     │
     ▼
Rules
     │
     ▼
AWS Targets
```

A partner source is associated with a partner event bus before rules can process the partner events. ([AWS Documentation][6])

---

# Part D — Rules

## 16. What Is a Rule?

A rule says:

```text
IF event matches X
THEN send it to Y.
```

Example:

```text
IF
source = com.company.orders

AND
detail-type = Order Created

THEN
send to Inventory SQS
```

---

# 17. One Event Can Match Many Rules

Example event:

```text
OrderCreated
```

Rules:

```text
Rule A
→ inventory


Rule B
→ analytics


Rule C
→ fraud


Rule D
→ customer notification
```

Same event can therefore fan out:

```text
OrderCreated
     │
     ▼
EventBridge
     │
 ┌───┼─────┬────┐
 ▼   ▼     ▼    ▼
A    B     C    D
```

This begins to resemble SNS fan-out.

The difference is how routing decisions are expressed.

---

# Part E — Event Patterns

## 18. Event Pattern

Suppose incoming event:

```json
{
  "source": "com.company.orders",
  "detail-type": "Order Created",
  "detail": {
    "region": "IN",
    "total": 20000,
    "priority": "high"
  }
}
```

Rule:

```json
{
  "source": [
    "com.company.orders"
  ],
  "detail-type": [
    "Order Created"
  ]
}
```

matches.

Event patterns specify only fields you care about; EventBridge compares those fields to the corresponding fields in the incoming event. ([AWS Documentation][7])

---

# 19. Exact Matching

Example:

```json
{
  "detail": {
    "status": [
      "FAILED"
    ]
  }
}
```

Matches:

```text
status=FAILED
```

but not:

```text
status=SUCCESS
```

---

# 20. Multiple Values

```json
{
  "detail": {
    "status": [
      "FAILED",
      "TIMED_OUT"
    ]
  }
}
```

means:

```text
FAILED OR TIMED_OUT
```

for that property.

---

# 21. Numeric Matching

Example conceptually:

```json
{
  "detail": {
    "amount": [
      {
        "numeric": [
          ">=",
          100000
        ]
      }
    ]
  }
}
```

Use:

```text
high-value orders
→ fraud review
```

while ordinary orders follow a different route.

EventBridge supports numeric comparison operators in patterns. ([AWS Documentation][8])

---

# 22. `anything-but`

Example:

```json
{
  "detail": {
    "environment": [
      {
        "anything-but": "development"
      }
    ]
  }
}
```

Meaning:

```text
match everything
EXCEPT development.
```

EventBridge supports `anything-but` for strings and numeric values. ([AWS Documentation][8])

---

# 23. Prefix Matching

Conceptually:

```json
{
  "detail": {
    "service": [
      {
        "prefix": "payment-"
      }
    ]
  }
}
```

Matches:

```text
payment-api

payment-worker

payment-reconciliation
```

---

# 24. Suffix Matching

Conceptually:

```text
*.pdf
```

can be represented using suffix-style event-pattern operators where supported.

Useful for:

```text
filename types

resource naming conventions

ARN suffix patterns
```

EventBridge's advanced comparison operators include prefix/suffix-style matching. ([AWS Documentation][8])

---

# 25. Wildcard Matching

Event patterns also support wildcard matching for strings in applicable fields.

Example mental use:

```text
*/production/*
```

when exact values are not appropriate.

But:

```text
precise patterns
>
giant wildcard patterns
```

because overly broad matching can cause unintended targets, cost, or even recursive loops. AWS explicitly warns that poorly designed rules can create infinite event loops. ([AWS Documentation][3])

---

# 26. Exists Matching

Sometimes:

```text
field exists
```

is itself the condition.

Example:

```text
detail.errorCode exists
```

could route failed business events into an incident pipeline.

---

# Part F — Avoid Event Loops

## 27. Infinite Event Loop

Bad:

```text
S3 policy changed
     │
     ▼
EventBridge rule
     │
     ▼
Lambda
     │
     ▼
changes S3 policy
     │
     ▼
NEW EVENT
     │
     ▼
same rule
     │
     ▼
Lambda
     │
     ▼
...
```

AWS specifically warns that rule patterns can accidentally create recursive loops that increase costs and cause throttling. ([AWS Documentation][3])

---

# 28. Break the Loop

Use:

```text
more precise source

specific detail-type

state transition condition

custom marker

different event source

idempotent remediation
```

Example:

```text
Rule matches:
status=NON_COMPLIANT
AND
remediated != true
```

not:

```text
match every configuration change.
```

---

# Part G — Event Targets

## 29. What Is a Target?

A target is:

```text
WHERE MATCHING EVENTS GO.
```

Examples include:

```text
Lambda

SQS

SNS

Step Functions

Kinesis

ECS tasks

API Gateway

API destinations

other event buses

other supported AWS services
```

depending on target capabilities. EventBridge rules can route to AWS resources, API destinations, and other event buses. ([AWS Documentation][2])

---

# 30. Target Permissions

EventBridge must be authorized to invoke or write to the target.

Architecture:

```text
Rule
 │
 ▼
EventBridge
 │
 ▼
IAM / resource policy
 │
 ▼
Target
```

For example:

```text
EventBridge → SQS
```

requires the appropriate queue resource policy.

```text
EventBridge → ECS
```

often uses an IAM role.

Target delivery authorization is distinct from the producer's permission to call:

```text
events:PutEvents
```

---

# Part H — Input Transformation

## 31. Don't Always Forward the Entire Event

Original:

```json
{
  "source": "com.company.orders",
  "detail-type": "Order Created",
  "account": "...",
  "region": "ap-south-1",
  "detail": {
    "orderId": "ORD-100",
    "total": 500
  }
}
```

Target may need only:

```json
{
  "orderId": "ORD-100",
  "total": 500
}
```

Use EventBridge input transformation rather than creating Lambda merely to rearrange JSON.

---

# 32. Transformation Architecture

```text
Original Event
      │
      ▼
Event Pattern
      │
      ▼
Input Transformer
      │
      ▼
Target-Specific Payload
```

Pipes also support input transformers before enrichment and target delivery. ([AWS Documentation][9])

---

# 33. Avoid “Glue Lambda” Where Possible

Bad:

```text
EventBridge
    │
    ▼
Lambda
  only changes:
  foo → bar
    │
    ▼
SQS
```

If the transformation can be handled natively:

```text
EventBridge
    │
    ▼
Input Transformer
    │
    ▼
SQS
```

you reduce:

```text
deployment surface

function maintenance

cold starts

logging noise

runtime dependencies
```

---

# Part I — Event Delivery Retries

## 34. Target Delivery Failure

Suppose:

```text
EventBridge
    │
    ▼
Target
    X
```

because the target is:

```text
temporarily unavailable

throttled

returning retryable error
```

EventBridge retries retryable target-delivery failures.

By default EventBridge retries target delivery for up to:

```text
24 hours

and

185 retry attempts
```

using exponential backoff with jitter. ([AWS Documentation][10])

---

# 35. Retry Policy

You can configure:

```text
MaximumEventAgeInSeconds

MaximumRetryAttempts
```

Current EventBridge retry-policy bounds support an event age up to:

```text
86,400 sec
=
24 hours
```

and up to:

```text
185 retry attempts.
```

([AWS Documentation][11])

---

# 36. If All Retries Fail

Without DLQ:

```text
EventBridge
   │
   ▼
retry exhausted
   │
   ▼
event dropped
```

With DLQ:

```text
EventBridge
   │
   ▼
retry exhausted
   │
   ▼
SQS DLQ
```

AWS recommends configuring target DLQs when failed deliveries must be retained for later investigation. ([AWS Documentation][12])

---

# Part J — EventBridge DLQ

## 37. Rule Target DLQ

Architecture:

```text
Event
 │
 ▼
Rule
 │
 ▼
Target
 X
 │
 retry
 │
 retry
 │
 retry
 ▼
SQS DLQ
```

This DLQ means:

```text
EVENTBRIDGE COULD NOT
DELIVER TO TARGET.
```

It does not necessarily mean:

```text
target accepted the event
but its internal business operation failed.
```

Same reliability-layer principle we learned with SNS.

---

# 38. Example — EventBridge → Lambda

```text
EventBridge
   │
   ▼
Lambda service
```

Two boundaries can matter:

```text
Boundary 1:
EventBridge successfully invokes Lambda?


Boundary 2:
What happens inside the Lambda invocation?
```

For asynchronous Lambda invocation, once Lambda accepts the event, Lambda's own asynchronous processing model becomes relevant.

Never collapse all failures into:

```text
"EventBridge failed."
```

---

# Part K — Event Bus Encryption

## 39. EventBridge Event Bus Encryption

When creating a custom bus, EventBridge supports encryption controls including customer-managed KMS keys. ([AWS Documentation][5])

If a customer-managed KMS key is used, AWS recommends associating an event-bus DLQ because non-retriable KMS failures—such as a disabled or missing key—can prevent EventBridge from processing applicable custom/partner events. ([AWS Documentation][13])

Architecture:

```text
Producer
   │
   ▼
Event Bus
   │
 KMS
   │
   ▼
Rules
```

---

# Part L — Archive

## 40. What If You Need Event History?

Normal routing:

```text
event arrives
    │
    ▼
rules evaluate
    │
    ▼
targets
```

But later you realize:

```text
Our fraud service was broken
for 2 hours.
```

Can we reprocess historical events?

Use:

# EventBridge Archive

---

# 41. Archive Architecture

```text
                     Event Bus
                        │
             ┌──────────┴─────────┐
             ▼                    ▼
           Rules                Archive
             │                    │
             ▼                    ▼
          Targets             Historical
                                Events
```

EventBridge archives can retain events that match an optional event pattern and later replay them to the event bus that originally received them. ([AWS Documentation][14])

---

# 42. Archive Filter

Maybe you don't need everything.

Example:

```text
Archive only:
PaymentFailed
OrderCreated
```

not:

```text
every low-value telemetry event.
```

When creating an archive, you can apply an event pattern to select which events are retained. ([AWS Documentation][2])

---

# 43. Archive Retention

You define an archive retention policy.

AWS also supports creating an archive with indefinite retention when created alongside an event bus, although this can later be updated. ([AWS Documentation][2])

Production question:

```text
How long do I need
business-event replay capability?
```

Examples:

```text
7 days

30 days

90 days

regulatory period
```

depending on requirements and cost.

---

# Part M — Replay

## 44. Replay

Suppose Fraud Service failed between:

```text
10:00
and
11:30
```

After fixing it:

```text
Archive
  │
  ▼
select event window
  │
  ▼
Replay
  │
  ▼
Original Event Bus
  │
  ▼
Rules evaluate again
```

EventBridge replay sends archived events back to the bus that originally received them. ([AWS Documentation][14])

---

# 45. Replay Is Not “Send Straight to One Target”

Important.

Conceptually:

```text
Archive
   │
   ▼
EVENT BUS
   │
   ▼
RULES
```

not:

```text
Archive
   │
   ▼
specific Lambda
```

Therefore current routing rules can influence how replayed events flow.

---

# 46. Idempotency Still Matters

Suppose:

```text
OrderCreated
```

was successfully processed by:

```text
Inventory
Email
Analytics
```

but only Fraud failed.

If you replay the event onto the bus:

```text
Inventory
Email
Analytics
```

may see it again too depending on rule design.

Therefore:

```text
EVENT REPLAY
REQUIRES
IDEMPOTENT CONSUMERS.
```

This is the same distributed-systems principle appearing again.

---

# Part N — Schema Registry

## 47. Event Contracts Become Important

When you have:

```text
100 services
```

publishing:

```text
500 event types
```

developers ask:

```text
What does OrderCreated look like?

What fields exist?

Is customerId string?

What changed in v2?
```

EventBridge provides schema capabilities to describe event structures. It includes schemas for AWS-generated events and supports custom/uploaded schemas and schema discovery from event-bus traffic. ([AWS Documentation][15])

---

# 48. Schema Mental Model

```text
Event Producer
      │
      ▼
OrderCreated
      │
      ▼
Schema Registry
      │
      ▼
Known structure
      │
      ├── orderId: string
      ├── total: number
      └── customerId: string
```

Schemas can also generate/download code bindings for supported languages. ([AWS Documentation][15])

---

# 49. Schema Does NOT Eliminate Versioning Discipline

Even with a registry:

```text
producer changes event
```

can break consumers.

You still need:

```text
backward compatibility

event versioning

deprecation strategy

consumer coordination
```

A registry documents contracts.

It does not magically make incompatible changes safe.

---

# Part O — Cross-Account Event Routing

## 50. Enterprise Problem

You have:

```text
AWS Organization

Security Account

Application Account A

Application Account B

Data Account

Operations Account
```

Events need central routing.

Architecture:

```text
Account A ─────┐
Account B ─────┤
Account C ─────┤
               ▼
       Central Event Bus
               │
       ┌───────┼────────┐
       ▼       ▼        ▼
   Security  Data     Operations
```

EventBridge supports sending events between event buses in different accounts using bus resource policies and IAM roles. ([AWS Documentation][16])

---

# 51. Receiver Bus Policy

The receiving bus can use a resource policy to allow:

```text
Account A

Account B

or

AWS Organization
```

to send events.

Event-bus resource policies can authorize cross-account `PutEvents` and can use organization/account conditions. ([AWS Documentation][17])

---

# 52. Modern Cross-Account Requirement

AWS now requires IAM roles for **new cross-account event-bus targets** created after March 2, 2023. AWS recommends this role-based approach because organization boundaries and SCPs then participate in the authorization path. ([AWS Documentation][16])

Modern mental model:

```text
Sender Rule
    │
    ▼
IAM Role
    │
    ▼
Receiver Event Bus
    │
    ▼
Resource Policy
```

---

# 53. Organization Policy

Rather than listing:

```text
50 account IDs
```

you can allow:

```text
AWS Organization ID
```

under an appropriately constrained bus policy.

Architecture:

```text
Organization o-abcd1234
        │
        ▼
Central Bus Policy
        │
        ▼
PutEvents allowed
```

with additional controls as appropriate.

---

# 54. Central Event Account

A common enterprise design:

```text
                    AWS ORGANIZATION

          ┌──────────┼──────────┐
          ▼          ▼          ▼
       Prod A      Prod B     Prod C
          │          │          │
          └──────────┼──────────┘
                     ▼
              Event Routing
                 Account
                     │
                     ▼
              Central Event Bus
                     │
          ┌──────────┼───────────┐
          ▼          ▼           ▼
      Security      Data       Ops
```

This provides:

```text
central routing

central policy

cross-account decoupling
```

while still letting workloads own their local processing.

---

# Part P — Bus-to-Bus Routing

## 55. Event Bus Can Target Another Event Bus

Example:

```text
Application Bus
      │
      ▼
Rule
      │
      ▼
Central Bus
      │
      ▼
more rules
```

EventBridge supports other buses as rule targets within the same or different accounts. ([AWS Documentation][2])

---

# 56. Why Bus-to-Bus?

Maybe:

```text
local app account
```

should publish only to:

```text
local bus
```

Then governance rule forwards certain events to:

```text
central security bus.
```

Producer doesn't need cross-account knowledge.

---

# Part Q — API Destinations

## 57. EventBridge Can Call External HTTPS APIs

Architecture:

```text
EventBridge
    │
    ▼
API Destination
    │
    ▼
HTTPS endpoint
    │
    ▼
Partner / SaaS
```

API Destinations let EventBridge call HTTPS endpoints from event-bus rules or Pipes. ([AWS Documentation][18])

---

# 58. Example

```text
OrderShipped
     │
     ▼
EventBridge
     │
     ▼
API Destination
     │
     ▼
Shipping partner webhook
```

This can eliminate a Lambda whose only job is:

```text
HTTP POST event
to partner.
```

---

# 59. API Destination Timeout

Current EventBridge API Destination requests have a maximum client execution timeout of:

```text
5 seconds.
```

If the endpoint takes longer, EventBridge times out the call and retry handling applies according to configured policy. ([AWS Documentation][18])

So do not use an API Destination for an external API that routinely takes:

```text
30 seconds
```

to respond.

---

# Part R — EventBridge Pipes

## 60. Why Pipes?

Suppose:

```text
SQS
 │
 ▼
Lambda
 │
 filter JSON
 │
 enrich from API
 │
 reformat event
 │
 ▼
Step Functions
```

Much of that Lambda may be integration glue rather than business logic.

EventBridge Pipes lets you build:

```text
SOURCE
  │
  ▼
FILTER
  │
  ▼
TRANSFORM
  │
  ▼
ENRICHMENT
  │
  ▼
TARGET
```

Pipes are designed for one-source → one-target point-to-point integrations. ([AWS Documentation][19])

---

# 61. Event Bus vs Pipe

Never confuse them.

### Event Bus

```text
many sources
   │
   ▼
BUS
   │
many rules
   │
   ▼
many targets
```

### Pipe

```text
ONE SOURCE
    │
    ▼
filter
    │
    ▼
enrichment
    │
    ▼
ONE TARGET
```

AWS explicitly frames Event Buses as many-to-many and Pipes as point-to-point. ([AWS Documentation][1])

---

# 62. Pipes Sources

Pipes supports event/stream/queue sources including service families such as:

```text
SQS

Kinesis

DynamoDB Streams

Kafka/MSK

Amazon MQ

other supported event-stream sources
```

with exact source capabilities depending on source type. Pipes filtering uses EventBridge event-pattern semantics. ([AWS Documentation][20])

---

# 63. Pipe Filtering

Example:

```text
SQS
 │
 contains:
 PaymentApproved
 PaymentFailed
 RefundRequested
 │
 ▼
Pipe Filter
 │
 only:
 PaymentFailed
 │
 ▼
Step Functions
```

Now nonmatching records do not invoke the enrichment/target through that Pipe. Pipes filtering uses the same general pattern language as EventBridge rules/Lambda event-source filtering. ([AWS Documentation][20])

---

# 64. Pipe Transformation

Before enrichment:

```text
Source Record
     │
     ▼
Input Transformer
     │
     ▼
Enrichment-friendly payload
```

and another transformation can shape data for the target.

Pipes supports input transformers both for enrichment input and target input. ([AWS Documentation][9])

---

# 65. Enrichment

Suppose source event contains:

```json
{
  "customerId": "C-123"
}
```

but target needs:

```json
{
  "customerId": "C-123",
  "riskLevel": "HIGH"
}
```

Enrichment architecture:

```text
Pipe
 │
 ▼
Enrichment
 │
 ├── Lambda
 ├── API Gateway
 ├── Step Functions
 └── supported API destination patterns
 │
 ▼
Target
```

An enrichment can also effectively suppress delivery by returning an empty response where supported. ([AWS Documentation][21])

---

# 66. Pipe Target

Targets can include various AWS services.

For Lambda or Step Functions targets, because those services don't expose batch APIs in this context, EventBridge converts pipe batches to JSON arrays and passes them to the target. ([AWS Documentation][22])

---

# 67. Pipes Batching

With batching enabled:

```text
Source
   │
   ▼
multiple records
   │
   ▼
Pipe
   │
   ▼
batch target API
```

where supported.

Input transformations are applied per individual record rather than to the batch as a single opaque object. ([AWS Documentation][23])

---

# 68. Pipes Retry/DLQ

Pipe retry behavior depends partly on the source type because queue/stream sources already have their own lifecycle semantics. When creating a Pipe, AWS exposes retry/age settings where applicable and optional DLQ configuration; current configurable retry attempt bounds include `0–185` and event age `1 minute–24 hours` for supported cases. ([AWS Documentation][24])

Again:

```text
PIPE SOURCE TYPE
MATTERS.
```

---

# Part S — EventBridge Scheduler

## 69. EventBridge Rules Used to Handle Most Schedules

Older tutorials teach:

```text
EventBridge Rule
    │
    ▼
cron(...)
```

This still exists as:

```text
scheduled rules
```

but AWS now explicitly recommends:

# EventBridge Scheduler

for scheduled target invocation because it is more flexible and scalable. ([AWS Documentation][25])

---

# 70. Scheduler Mental Model

```text
                    Scheduler

       ┌──────────────┼───────────────┐
       ▼              ▼               ▼
    One-time         Rate            Cron
       │              │               │
       └──────────────┼───────────────┘
                      ▼
                    Target
```

Scheduler supports:

```text
one-time schedules

rate expressions

cron expressions
```

plus retry policies and flexible execution windows. ([AWS Documentation][26])

---

# 71. One-Time Schedule

Example:

```text
Run exactly once:
2026-08-20 10:00 Asia/Kolkata
```

Excellent for:

```text
send reminder tomorrow

perform scheduled maintenance

execute deferred workflow

expire account at specific time
```

rather than trying to implement:

```text
sleep(6 days)
```

inside an application.

---

# 72. Recurring Rate

Examples conceptually:

```text
every 5 minutes

every hour

every 7 days
```

Use rate expressions when the requirement is interval-oriented.

---

# 73. Cron

Use cron when calendar semantics matter:

```text
Monday–Friday
09:00

first day of month

midnight every Sunday
```

Scheduler is the modern choice for these application scheduling use cases. ([AWS Documentation][26])

---

# 74. Time Zones

A major practical advantage over older EventBridge scheduled-rule habits is that Scheduler supports schedule definitions built around local time-zone needs rather than forcing every application team to mentally operate only in UTC.

So:

```text
9 AM India
```

can be modeled as a real scheduling requirement rather than repeatedly converting it in application code.

---

# Part T — Flexible Time Windows

## 75. Not Every Task Needs Exact Second-Level Timing

Imagine:

```text
10 million customers
```

all need a daily maintenance action around:

```text
01:00 AM
```

Invoking all at exactly 01:00 can create a huge spike.

Use a:

# Flexible Time Window

Example:

```text
scheduled:
01:00

window:
15 minutes
```

Scheduler can invoke the target anywhere within that configured flexible window. ([AWS Documentation][27])

---

# 76. Why Flexible Windows Matter

Without flexibility:

```text
01:00
  │
  ▼
1,000,000 invocations
            💥
```

With:

```text
15-minute window
```

Scheduler can distribute the work across the window.

This reduces sudden pressure on:

```text
Lambda

databases

external APIs

downstream queues
```

---

# 77. Exact vs Flexible

If you don't want flexibility, configure:

```text
FlexibleTimeWindow=OFF
```

If you use flexible execution:

```text
FLEXIBLE
+
maximum window
```

must be specified. ([AWS Documentation][27])

---

# Part U — Scheduler Retry & DLQ

## 78. Scheduler Target Fails

Architecture:

```text
Schedule
   │
   ▼
Target
   X
   │
 retry
   │
 retry
   │
 ▼
DLQ
```

Scheduler supports retry policy and a Standard SQS DLQ for failed target delivery after the retry policy is exhausted. ([AWS Documentation][28])

---

# 79. Scheduler Retry Limits

Current Scheduler retry policy supports maximum event age up to:

```text
86,400 seconds
=
24 hours
```

and up to:

```text
185 retry attempts.
```

([AWS Documentation][29])

---

# 80. Scheduler Execution Role

Scheduler needs an IAM role that the service can assume.

Trust principal:

```text
scheduler.amazonaws.com
```

The execution role must then be authorized to call the selected target. ([AWS Documentation][30])

Architecture:

```text
Scheduler
   │
sts:AssumeRole
   ▼
SchedulerExecutionRole
   │
   ▼
lambda:InvokeFunction
or
sqs:SendMessage
or
other target action
```

---

# 81. Automatically Delete Completed Schedule

One-time schedules can accumulate forever if you create millions of them and never delete them.

Scheduler supports:

```text
ActionAfterCompletion=DELETE
```

so a schedule can automatically be removed after its final invocation. For a one-time schedule, deletion occurs after it has invoked the target once. ([AWS Documentation][31])

This is excellent lifecycle hygiene.

---

# Part V — Scheduler vs SQS Delay

## 82. SQS Delay

Maximum:

```text
15 minutes.
```

Use for:

```text
small short-delay messaging.
```

---

# 83. Scheduler

Use when you need:

```text
tomorrow

next week

specific timestamp

calendar recurrence

timezone support

millions of independent schedules
```

Mental rule:

```text
SHORT QUEUE DELAY
→ SQS


ACTUAL SCHEDULING
→ EventBridge Scheduler
```

---

# Part W — Scheduler vs Legacy Scheduled Rules

## 84. New Architecture

Prefer:

```text
EventBridge Scheduler
```

for:

```text
scheduled Lambda

scheduled SQS message

scheduled Step Functions workflow
```

rather than starting new work around legacy EventBridge scheduled rules.

AWS explicitly recommends Scheduler over scheduled rules for scheduled target invocation. ([AWS Documentation][25])

---

# Part X — Global Endpoints

## 85. Regional Event Routing Problem

Imagine:

```text
Primary Region:
ap-south-1
```

goes unhealthy.

Publishers still send:

```text
PutEvents
→ ap-south-1
```

Your event-driven architecture now has a Regional dependency.

EventBridge provides:

# Global Endpoints

for Regional failover. ([AWS Documentation][32])

---

# 86. Global Endpoint Architecture

```text
                       Publisher
                           │
                           ▼
                  EventBridge Global
                       Endpoint
                           │
                    Route 53 health
                           │
              ┌────────────┴─────────────┐
              ▼                          ▼
         PRIMARY REGION              SECONDARY
          ap-south-1                 e.g. ap-southeast-1
              │                          │
              ▼                          ▼
           Bus A                       Bus B
```

You configure matching event buses/rules in primary and secondary Regions. ([AWS Documentation][33])

---

# 87. Health Check Controls Failover

Global endpoint failover uses a Route 53 health check.

Conceptually:

```text
Primary healthy?
     │
  ┌──┴───┐
 YES     NO
 │        │
 ▼        ▼
Primary Secondary
```

---

# 88. Event Replication

AWS recommends enabling event replication on EventBridge global endpoints.

Replication helps validate the secondary path and is required for automatic recovery from failover back to the primary Region; without it, manual health-check reset is required for failback. ([AWS Documentation][32])

---

# 89. Health Check Design Trap

AWS advises against basing the global endpoint Route 53 health check on an individual subscriber's metrics.

Why?

Suppose:

```text
one Lambda consumer
```

is broken.

You don't want:

```text
whole event publishing Region
```

to fail over merely because one downstream subscriber is unhealthy. ([AWS Documentation][34])

Failover should represent:

```text
event ingestion/routing availability
```

not:

```text
every downstream business component.
```

---

# Part Y — Choreography vs Orchestration

## 90. EventBridge Often Enables Choreography

Consider order workflow:

```text
OrderCreated
     │
     ▼
Inventory reserves
     │
     ▼
InventoryReserved
     │
     ▼
Payment captures
     │
     ▼
PaymentCaptured
     │
     ▼
Shipping starts
```

No central coordinator tells every service what to do.

Each service reacts to events.

This is:

# Choreography

---

# 91. Choreography Advantages

```text
loose coupling

independent services

easy new subscribers

natural domain events
```

But problems include:

```text
harder end-to-end visibility

complex failure flows

workflow state distributed
```

---

# 92. Orchestration

Contrast:

```text
Step Functions
      │
      ▼
Reserve Inventory
      │
      ▼
Capture Payment
      │
      ▼
Create Shipment
```

A central workflow explicitly coordinates each step.

This is:

# Orchestration

We'll cover this deeply in Lesson 34 Part 4.

---

# 93. When EventBridge Is Excellent

Use EventBridge choreography when:

```text
services should react independently

event producers shouldn't know consumers

many consumers may appear later

routing rules should be decoupled

events represent domain facts
```

---

# 94. When Step Functions May Be Better

Use orchestration when:

```text
there is a clear workflow

step ordering matters

business transaction state matters

you need retries/catches per step

you need explicit compensation

you need end-to-end execution state
```

---

# Part Z — SNS vs EventBridge

## 95. SNS

Best mental model:

```text
TOPIC
+
SUBSCRIPTIONS
```

Excellent for:

```text
simple fan-out

SQS fan-out

notifications

email/SMS

ordered FIFO queue fan-out
```

---

# 96. EventBridge

Best mental model:

```text
BUS
+
RULES
+
EVENT PATTERNS
```

Excellent for:

```text
application event routing

AWS service events

cross-account buses

rich pattern matching

SaaS integrations

archives/replay

API destinations

large EDA platforms
```

AWS's decision guidance positions EventBridge as a richer routing service compared with SNS's topic-centric fan-out and SQS's queueing model. ([AWS Documentation][1])

---

# 97. Don't Pick Based on Which Service Is “Newer”

Bad:

```text
EventBridge is newer
therefore use EventBridge everywhere.
```

Instead ask:

```text
Do I need a queue?
→ SQS


Do I need simple pub/sub fan-out?
→ SNS


Do I need rich event-routing rules?
→ EventBridge


Do I need point-to-point source integration?
→ Pipes
```

---

# Part AA — EventBridge vs Pipes

## 98. Decision

```text
Many sources?
Many targets?
Multiple independent consumers?
        │
        ▼
      BUS


One source?
One target?
Need filter/enrichment?
        │
        ▼
      PIPE
```

---

# 99. Example — SQS to Step Functions

Instead of:

```text
SQS
 │
 ▼
Lambda
 │
 ▼
Step Functions
```

where Lambda simply calls:

```text
StartExecution
```

consider:

```text
SQS
 │
 ▼
EventBridge Pipe
 │
 ▼
Step Functions
```

if the Pipe capabilities fit your filtering, transformation and enrichment requirements.

---

# Part AB — Hands-On Event Bus Lab

Region:

```bash
export AWS_REGION=ap-south-1
```

Goal:

```text
Application
     │
     ▼
custom event bus
     │
     ▼
rule:
OrderCreated
     │
     ▼
SQS target
```

---

# 100. Create Custom Bus

```bash
aws events create-event-bus \
  --name ecommerce-events \
  --region "$AWS_REGION"
```

Verify:

```bash
aws events describe-event-bus \
  --name ecommerce-events \
  --region "$AWS_REGION"
```

---

# 101. Create Target Queue

```bash
QUEUE_URL=$(aws sqs create-queue \
  --queue-name order-created-events \
  --region "$AWS_REGION" \
  --query QueueUrl \
  --output text)
```

Get ARN:

```bash
QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text \
  --region "$AWS_REGION")
```

---

# 102. Create Event Rule

Pattern:

```json
{
  "source": [
    "com.yourdatascientist.orders"
  ],
  "detail-type": [
    "Order Created"
  ]
}
```

Save as:

```text
order-created-pattern.json
```

Then:

```bash
aws events put-rule \
  --name order-created \
  --event-bus-name ecommerce-events \
  --event-pattern file://order-created-pattern.json \
  --state ENABLED \
  --region "$AWS_REGION"
```

---

# 103. Queue Policy

The SQS target must allow EventBridge:

```text
events.amazonaws.com
```

to call:

```text
sqs:SendMessage
```

for the appropriate rule/source ARN.

Conceptually:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "events.amazonaws.com"
  },
  "Action": "sqs:SendMessage",
  "Resource": "QUEUE_ARN",
  "Condition": {
    "ArnEquals": {
      "aws:SourceArn": "RULE_ARN"
    }
  }
}
```

---

# 104. Add Target

```bash
aws events put-targets \
  --event-bus-name ecommerce-events \
  --rule order-created \
  --targets \
    "Id"="OrdersQueue","Arn"="$QUEUE_ARN" \
  --region "$AWS_REGION"
```

---

# 105. Publish Custom Event

```bash
aws events put-events \
  --entries '[
    {
      "Source": "com.yourdatascientist.orders",
      "DetailType": "Order Created",
      "Detail": "{\"orderId\":\"ORD-1001\",\"amount\":12000}",
      "EventBusName": "ecommerce-events"
    }
  ]' \
  --region "$AWS_REGION"
```

Producer authorization normally requires:

```text
events:PutEvents
```

against the appropriate bus/resource policy model.

---

# 106. Receive from SQS

```bash
aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --wait-time-seconds 20 \
  --region "$AWS_REGION"
```

Expected architecture:

```text
PutEvents
    │
    ▼
ecommerce-events
    │
    ▼
Rule matched
    │
    ▼
SQS
```

---

# Part AC — Test Event Patterns

## 107. Before Deploying a Rule

One excellent production habit:

```text
TEST PATTERN
before enabling routing.
```

You don't want:

```text
rule unexpectedly matches
10 million events.
```

or:

```text
matches zero.
```

Create:

```text
pattern JSON

sample event JSON
```

and use EventBridge's pattern-testing capabilities before production rollout.

---

# Part AD — Archive Lab

## 108. Create Archive

Conceptually:

```bash
aws events create-archive \
  --archive-name ecommerce-archive \
  --event-source-arn "$EVENT_BUS_ARN" \
  --retention-days 30 \
  --region "$AWS_REGION"
```

EventBridge archives are associated with a source event bus and can filter/select stored events. ([AWS Documentation][14])

---

# 109. Replay Flow

Once events exist:

```text
Archive
   │
   ▼
start replay
   │
   ▼
source event bus
   │
   ▼
matching rules
```

Use a controlled time range and carefully understand what subscribers will see again. ([AWS Documentation][35])

---

# Part AE — Scheduler CLI Lab

## 110. Goal

Create:

```text
One-time schedule
     │
     ▼
SQS
```

instead of:

```text
application sleeps
until tomorrow.
```

---

# 111. Scheduler IAM Trust

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "scheduler.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Then give the execution role only:

```text
sqs:SendMessage
```

to the target queue.

Scheduler's service principal and target-specific execution-role model are documented by AWS. ([AWS Documentation][30])

---

# 112. One-Time Schedule Concept

```bash
aws scheduler create-schedule \
  --name todo-reminder \
  --schedule-expression \
    "at(2026-08-20T10:00:00)" \
  --flexible-time-window '{"Mode":"OFF"}' \
  --target '{
    "Arn":"<QUEUE_ARN>",
    "RoleArn":"<SCHEDULER_ROLE_ARN>",
    "Input":"{\"task\":\"send-reminder\"}"
  }'
```

Use explicit time-zone configuration where needed for local schedule semantics.

---

# 113. Automatic Cleanup

For one-time schedules, configure:

```text
ActionAfterCompletion=DELETE
```

so schedules do not remain indefinitely after their final invocation. ([AWS Documentation][31])

---

# Part AF — Terraform Event Bus

## 114. Custom Event Bus

```hcl
resource "aws_cloudwatch_event_bus" "app" {
  name = "ecommerce-events"
}
```

---

# 115. Rule

```hcl
resource "aws_cloudwatch_event_rule" "order_created" {
  name = "order-created"

  event_bus_name =
    aws_cloudwatch_event_bus.app.name

  event_pattern = jsonencode({
    source = [
      "com.yourdatascientist.orders"
    ]

    "detail-type" = [
      "Order Created"
    ]
  })
}
```

---

# 116. SQS Target

```hcl
resource "aws_cloudwatch_event_target" "orders" {
  rule =
    aws_cloudwatch_event_rule.order_created.name

  event_bus_name =
    aws_cloudwatch_event_bus.app.name

  target_id = "OrdersQueue"

  arn = aws_sqs_queue.order_events.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 10
  }

  dead_letter_config {
    arn = aws_sqs_queue.eventbridge_dlq.arn
  }
}
```

Remember target DLQ means:

```text
EventBridge delivery failed.
```

not:

```text
SQS consumer later failed.
```

---

# 117. Archive Terraform Mental Model

Production IaC should manage:

```text
bus

archive

rule

target

DLQ

permissions

KMS
```

together so your recovery path isn't something remembered only after the incident happens.

---

# Part AG — EventBridge Pipe Terraform Mental Model

## 118. Pipe Architecture

```text
SQS
 │
 ▼
Pipe
 │
 ├── filter
 ├── input transformation
 └── enrichment
 │
 ▼
Step Functions
```

Your IaC must also create a Pipe execution role allowing the Pipe to:

```text
read source

invoke enrichment

invoke target
```

with least privilege.

---

# Part AH — Production Multi-Account Architecture

## 119. Full Enterprise Model

```text
                          AWS ORGANIZATION

        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
     App Account A        App Account B       App Account C
        │                    │                    │
        ▼                    ▼                    ▼
    Local Event Bus      Local Event Bus      Local Event Bus
        │                    │                    │
        └────────────────────┼────────────────────┘
                             ▼
                    Central Event Bus
                    Event Platform Account
                             │
          ┌──────────────────┼───────────────────┐
          ▼                  ▼                   ▼
      Security Rule       Data Rule          Ops Rule
          │                  │                   │
          ▼                  ▼                   ▼
         SQS             Firehose             SNS
          │                                      │
          ▼                                      ▼
      Security                               Operations


                 CENTRAL BUS ALSO HAS:

                       Archive
                          │
                          ▼
                        Replay


                 REGIONAL RESILIENCE:

                      Global Endpoint
                          │
                 ┌────────┴────────┐
                 ▼                 ▼
             Mumbai            Singapore
```

Cross-account event routing is controlled with event-bus resource policies and sender IAM roles; Global Endpoints can provide Regional routing/failover for event ingestion. ([AWS Documentation][16])

---

# Part AI — Observability

## 120. EventBridge Isn't “Set and Forget”

Monitor:

```text
event ingestion

rule matching

target invocation

failed invocation

DLQ depth

throttling

archive usage

replay activity
```

depending on your architecture.

---

# 121. Three Reliability Questions

For every EventBridge pipeline ask:

```text
1.
Did producer successfully publish?


2.
Did the event match the intended rule?


3.
Did EventBridge successfully deliver
to the target?
```

Then:

```text
4.
Did the target actually process it?
```

These are distinct stages.

---

# 122. Example

```text
Producer
   ✓
   │
   ▼
Event Bus
   ✓
   │
   ▼
Rule
   ✓
   │
   ▼
SQS
   ✓
   │
   ▼
Consumer
   X
```

EventBridge is perfectly healthy.

The incident is in:

```text
SQS / consumer processing.
```

---

# Part AJ — Troubleshooting

## 123. “PutEvents Succeeded but Target Saw Nothing”

Check:

```text
correct bus?

rule enabled?

event pattern actually matches?

wrong source?

wrong detail-type?

wrong numeric/string datatype?

target configured?

target permission?

DLQ?

CloudWatch EventBridge metrics?
```

The most common mental mistake is:

```text
published to bus
=
must reach target
```

No.

It only reaches a target if:

```text
a rule matches.
```

---

# 124. Pattern Looks Correct but Doesn't Match

Remember event patterns are structured JSON matching.

Potential issues:

```text
wrong nesting

detail vs top-level field

case mismatch

number vs string

wrong detail-type spelling

unexpected event source
```

Only specify fields you need and test patterns with representative sample events. ([AWS Documentation][7])

---

# 125. Target Is Failing

Check:

```text
target IAM permission

target resource policy

target availability

throttling

EventBridge retry policy

target DLQ

MaximumEventAge

MaximumRetryAttempts
```

Default retry delivery is 24 hours / up to 185 attempts for retriable failures. ([AWS Documentation][10])

---

# 126. DLQ Has Messages

Ask:

```text
Did EventBridge fail delivery?

or

did target accept and then fail internally?
```

If message is in:

```text
EventBridge target DLQ
```

that means delivery was not successfully completed after EventBridge's handling.

Investigate target authorization and availability first.

---

# 127. Cross-Account Event Not Arriving

Check both sides.

### Sender

```text
rule target correct?

IAM role?

events:PutEvents?
```

### Receiver

```text
event bus resource policy?

correct account/org?

correct Region?

conditions?
```

Modern cross-account bus targets require IAM roles for new target configurations. ([AWS Documentation][16])

---

# 128. Scheduler Didn't Invoke Target

Check:

```text
schedule enabled?

time zone?

cron expression?

execution role trust?

target permissions?

target ARN?

retry policy?

Scheduler DLQ?
```

Scheduler troubleshooting specifically highlights the Scheduler execution role and its target permissions. ([AWS Documentation][30])

---

# 129. Schedule Ran at Unexpected Time

Think:

```text
timezone

DST

cron interpretation

flexible time window
```

If:

```text
FlexibleTimeWindow=FLEXIBLE
```

then invocation is intentionally allowed within the configured window rather than exactly at the nominal schedule timestamp. ([AWS Documentation][27])

---

# 130. Pipe Produces No Target Invocations

Check:

```text
source has records?

Pipe started?

source IAM?

filter rejects everything?

enrichment returning empty response?

target permissions?

batching?
```

Remember an enrichment can suppress downstream delivery by returning an empty result in supported scenarios. ([AWS Documentation][21])

---

# 131. API Destination Always Times Out

Check whether external endpoint response is slower than:

```text
5 seconds.
```

That is the current API Destination maximum client-execution timeout. ([AWS Documentation][18])

If the external workflow takes 30 seconds, use a more asynchronous integration design.

---

# 132. Archive Replay Caused Duplicate Actions

Expected risk.

Replay sends events back through the original bus/rule-routing path. ([AWS Documentation][14])

Consumers must therefore be:

```text
idempotent

replay-aware where needed

safe for duplicate event delivery
```

---

# Part AK — Certification / Interview Scenarios

## 133. Scenario

> React when an EC2 instance transitions to `stopped`.

Think:

```text
EventBridge
default event bus
+
event pattern
```

The default bus automatically receives supported AWS service events. ([AWS Documentation][4])

---

# 134. Scenario

> Application publishes business events and many services route on different payload attributes.

Think:

```text
EventBridge custom event bus
+
rules
+
event patterns.
```

---

# 135. Scenario

> Need a simple message broadcast to SQS, email and SMS.

Think:

```text
SNS
```

rather than unnecessarily building a custom EventBridge event platform.

---

# 136. Scenario

> Need durable buffer where one worker processes each job.

Think:

```text
SQS.
```

---

# 137. Scenario

> Need many-to-many event routing with AWS services, applications and SaaS.

Think:

```text
EventBridge Event Bus.
```

Event buses are designed for many-source → many-target routing. ([AWS Documentation][1])

---

# 138. Scenario

> Need SQS → filtering → enrichment → Step Functions with minimal glue code.

Think:

```text
EventBridge Pipes.
```

Pipes provide point-to-point source → target integrations with optional filtering, transformation and enrichment. ([AWS Documentation][19])

---

# 139. Scenario

> Need run task exactly once next Friday.

Think:

```text
EventBridge Scheduler
one-time schedule.
```

---

# 140. Scenario

> Need send SQS message in three days.

Not:

```text
SQS DelaySeconds
```

because SQS delay max is 15 minutes.

Use:

```text
EventBridge Scheduler.
```

---

# 141. Scenario

> Need to run 500k scheduled jobs around midnight without sending all at precisely the same instant.

Think:

```text
EventBridge Scheduler
+
Flexible Time Window.
```

([AWS Documentation][27])

---

# 142. Scenario

> Need events retained so they can be replayed after fixing a broken consumer.

Think:

```text
EventBridge Archive
+
Replay.
```

([AWS Documentation][14])

---

# 143. Scenario

> EventBridge cannot deliver to Lambda after all retries; need retain failed events.

Think:

```text
EventBridge target
SQS DLQ.
```

([AWS Documentation][12])

---

# 144. Scenario

> EventBridge target retry defaults?

Current default:

```text
up to 24 hours

and

up to 185 attempts

with exponential backoff
and jitter.
```

([AWS Documentation][10])

---

# 145. Scenario

> Need events from 40 AWS accounts routed centrally.

Think:

```text
central EventBridge bus

resource policy allowing
AWS Organization

sender IAM roles
```

([AWS Documentation][16])

---

# 146. Scenario

> Need multi-Region EventBridge publishing failover.

Think:

```text
EventBridge Global Endpoint

Route 53 health check

primary/secondary bus

event replication.
```

([AWS Documentation][32])

---

# 147. Scenario

> One subscriber failure shouldn't trigger whole-Region event-publishing failover.

Correct.

Do not build the global endpoint health check around one subscriber metric. AWS explicitly recommends against this design. ([AWS Documentation][34])

---

# 148. Scenario

> Need EventBridge to call external SaaS HTTPS endpoint directly.

Think:

```text
API Destination.
```

But remember:

```text
5-second endpoint timeout.
```

([AWS Documentation][18])

---

# Part AL — Decision Matrix

| Requirement                           | Best starting point   |
| ------------------------------------- | --------------------- |
| Durable async work queue              | **SQS**               |
| Fan-out publication                   | **SNS**               |
| Email/SMS notification                | **SNS**               |
| Rich event routing                    | **EventBridge Bus**   |
| AWS service event reaction            | **EventBridge**       |
| Cross-account event fabric            | **EventBridge**       |
| One source → one target integration   | **EventBridge Pipes** |
| Filter/enrich without glue Lambda     | **Pipes**             |
| Task tomorrow at 10 AM                | **Scheduler**         |
| Cron/time-zone scheduling             | **Scheduler**         |
| Replay historical bus events          | **Archive + Replay**  |
| Multi-Region event ingress failover   | **Global Endpoints**  |
| Explicit multi-step business workflow | **Step Functions**    |

---

# Part AM — Permanent EventBridge Mental Model

```text
                           EVENTBRIDGE

                                │
             ┌──────────────────┼───────────────────┐
             ▼                  ▼                   ▼
         EVENT BUS             PIPES             SCHEDULER
             │                  │                   │
         many-to-many       point-to-point       time-driven
             │                  │                   │
             ▼                  ▼                   ▼
           RULES              FILTER             CRON/RATE/AT
             │                  │                   │
             ▼                  ▼                   ▼
       EVENT PATTERNS       TRANSFORM            TARGET
             │                  │
             ▼                  ▼
          TARGETS           ENRICHMENT
             │                  │
             ▼                  ▼
       retries + DLQ          TARGET


                  BUS CAPABILITIES

                 Archive / Replay
                       │
                 Cross Account
                       │
                 Global Endpoint
                       │
                  Schema Registry
```

---

# 149. 40 Rules to Burn Into Memory

```text
1. EventBridge is an event-routing service.

2. Events describe things that happened.

3. Commands request that something happen.

4. Event-driven systems reduce producer/consumer coupling.

5. Event buses are many-source → many-target.

6. Pipes are one-source → one-target.

7. Scheduler is time-driven invocation.

8. The default bus receives supported AWS service events.

9. Use custom buses for application/domain routing
   when appropriate.

10. SaaS partner sources can use partner buses.

11. Rules decide where events go.

12. Rules contain event patterns.

13. One event can match multiple rules.

14. Event patterns match only fields you specify.

15. Patterns support exact and advanced comparisons.

16. Numeric filters can route high-value events.

17. anything-but provides exclusion matching.

18. Avoid overly broad rules.

19. Poor rules can create infinite event loops.

20. EventBridge targets require proper permissions.

21. Use input transformation before creating glue Lambda.

22. EventBridge retries retriable target failures.

23. Current default retry handling is
    24 hours / up to 185 attempts.

24. Add target DLQs for important delivery paths.

25. Target DLQ means EventBridge delivery failed.

26. It does not automatically mean target business
    processing failed after acceptance.

27. Archives retain selected bus events.

28. Replay sends archived events back to the source bus.

29. Replay requires idempotent consumers.

30. Schema Registry documents event structures.

31. Cross-account buses use resource policies.

32. New cross-account bus targets require IAM roles.

33. Organization IDs simplify central bus authorization.

34. API Destinations call HTTPS endpoints.

35. API Destination response timeout is 5 seconds.

36. Pipes support filtering, transforms and enrichment.

37. Scheduler should replace most new scheduled-rule designs.

38. Flexible time windows smooth scheduled workload spikes.

39. Global Endpoints provide Regional EventBridge failover.

40. SQS = queue,
    SNS = fan-out,
    EventBridge = routing,
    Step Functions = orchestration.
```

---

# ✅ Lesson 34 Part 3 Complete — Amazon EventBridge

You now understand:

```text
✓ event-driven architecture
✓ events vs commands
✓ loose coupling
✓ choreography

✓ EventBridge fundamentals
✓ event envelope
✓ source
✓ detail-type
✓ detail

✓ default event bus
✓ custom event buses
✓ partner event buses

✓ rules
✓ targets
✓ event patterns
✓ exact matching
✓ multiple-value matching
✓ numeric matching
✓ anything-but
✓ prefix/suffix
✓ wildcard
✓ exists matching
✓ infinite-loop prevention

✓ input transformers
✓ glue-Lambda avoidance

✓ EventBridge target retries
✓ exponential backoff
✓ jitter
✓ 24-hour default event age
✓ 185 default retry attempts
✓ target DLQs

✓ event-bus KMS encryption
✓ event-bus encryption DLQ

✓ EventBridge Archive
✓ archive filters
✓ retention
✓ Replay
✓ replay/idempotency considerations

✓ Schema Registry
✓ schema discovery
✓ code bindings
✓ event contracts

✓ cross-account EventBridge
✓ event-bus resource policies
✓ AWS Organizations
✓ sender IAM roles
✓ bus-to-bus routing
✓ central event account architecture

✓ API Destinations
✓ 5-second execution timeout

✓ EventBridge Pipes
✓ source
✓ filter
✓ transform
✓ enrichment
✓ target
✓ batching
✓ Pipe retry/DLQ behavior

✓ EventBridge Scheduler
✓ one-time schedules
✓ rate schedules
✓ cron
✓ flexible time windows
✓ execution roles
✓ retries
✓ Scheduler DLQ
✓ automatic schedule deletion
✓ Scheduler vs SQS delay
✓ Scheduler vs legacy scheduled rules

✓ Global Endpoints
✓ Route 53 health checks
✓ primary/secondary Regions
✓ event replication
✓ failover design

✓ SNS vs EventBridge
✓ SQS vs SNS vs EventBridge
✓ choreography vs orchestration

✓ CLI hands-on
✓ Terraform architecture
✓ multi-account production design
✓ troubleshooting
✓ SAA-C03/DOP-C02 scenarios
```

# Next — Lesson 34 Part 4

# **AWS Step Functions in Depth — Durable Workflow Orchestration, Standard vs Express, Retries, Catch, Map, Distributed Map, Callbacks & Saga Compensation**

Now we move from:

```text
EVENT CHOREOGRAPHY
```

to:

```text
EXPLICIT WORKFLOW ORCHESTRATION.
```

Instead of services independently reacting:

```text
OrderCreated
    │
    ▼
EventBridge
    │
 ┌──┼──────┐
 ▼  ▼      ▼
A   B      C
```

we'll build:

```text
                    Step Functions

                         Start
                           │
                           ▼
                    Validate Order
                           │
                           ▼
                   Reserve Inventory
                           │
                     ┌─────┴─────┐
                     ▼           ▼
                  success      failure
                     │           │
                     ▼           ▼
                Capture Pay    Compensate
                     │
                     ▼
                Create Shipment
                     │
                     ▼
                       End
```

Next we'll go deep into **Amazon States Language, Standard vs Express workflows, Task/Choice/Pass/Wait/Parallel/Map/Succeed/Fail states, optimized service integrations, `.sync`, callback task tokens, Retry and Catch, exponential backoff and jitter, execution timeouts, payload limits, Map vs Distributed Map, item processors, concurrency, human approval workflows, EventBridge integration, SQS callbacks, ECS/Fargate jobs, Lambda orchestration, error propagation, idempotency, Saga compensation, Terraform, observability, and a complete production order-processing workflow.**

[1]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html?utm_source=chatgpt.com "What Is Amazon EventBridge? - Amazon ..."
[2]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-targets.html?utm_source=chatgpt.com "Event bus targets in Amazon EventBridge"
[3]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html?utm_source=chatgpt.com "Creating Amazon EventBridge event patterns"
[4]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-bus.html?utm_source=chatgpt.com "Event buses in Amazon EventBridge"
[5]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-event-bus.html?utm_source=chatgpt.com "Creating an event bus in Amazon EventBridge"
[6]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-saas.html?utm_source=chatgpt.com "Receiving events from a SaaS partner with Amazon EventBridge"
[7]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-pattern.html?utm_source=chatgpt.com "Event pattern syntax - Amazon EventBridge"
[8]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-pattern-operators.html?utm_source=chatgpt.com "Comparison operators for use in event patterns ..."
[9]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-input-transformation.html?utm_source=chatgpt.com "Amazon EventBridge Pipes input transformation"
[10]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-retry-policy.html?utm_source=chatgpt.com "How EventBridge retries delivering events"
[11]: https://docs.aws.amazon.com/eventbridge/latest/APIReference/API_RetryPolicy.html?utm_source=chatgpt.com "RetryPolicy - Amazon EventBridge"
[12]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-dlq.html?utm_source=chatgpt.com "Using dead-letter queues to process undelivered events in ..."
[13]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-encryption-event-bus-dlq.html?utm_source=chatgpt.com "Using dead-letter queues to capture encrypted event errors ..."
[14]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-archive.html?utm_source=chatgpt.com "Archiving and replaying events in Amazon EventBridge"
[15]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-schema.html?utm_source=chatgpt.com "Amazon EventBridge schemas"
[16]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cross-account.html?utm_source=chatgpt.com "Sending and receiving events between AWS accounts in ..."
[17]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-bus-perms.html?utm_source=chatgpt.com "Permissions for event buses in Amazon EventBridge"
[18]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-api-destinations.html?utm_source=chatgpt.com "API destinations as targets in Amazon EventBridge"
[19]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes.html?utm_source=chatgpt.com "Amazon EventBridge Pipes"
[20]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-event-filtering.html?utm_source=chatgpt.com "Event filtering in Amazon EventBridge Pipes"
[21]: https://docs.aws.amazon.com/eventbridge/latest/userguide/pipes-enrichment.html?utm_source=chatgpt.com "Event enrichment in Amazon EventBridge Pipes"
[22]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-event-target.html?utm_source=chatgpt.com "Amazon EventBridge Pipes targets"
[23]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-batching-concurrency.html?utm_source=chatgpt.com "Amazon EventBridge Pipes batching and concurrency"
[24]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-create.html?utm_source=chatgpt.com "Creating an Amazon EventBridge pipe"
[25]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rules.html?utm_source=chatgpt.com "Rules in Amazon EventBridge"
[26]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/what-is-scheduler.html?utm_source=chatgpt.com "What is Amazon EventBridge Scheduler?"
[27]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/managing-schedule-flexible-time-windows.html?utm_source=chatgpt.com "Configuring flexible time windows in EventBridge Scheduler"
[28]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/managing-schedule.html?utm_source=chatgpt.com "Managing a schedule in EventBridge Scheduler"
[29]: https://docs.aws.amazon.com/scheduler/latest/APIReference/API_RetryPolicy.html?utm_source=chatgpt.com "RetryPolicy - EventBridge Scheduler"
[30]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/troubleshooting.html?utm_source=chatgpt.com "Troubleshooting Amazon EventBridge Scheduler"
[31]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/managing-schedule-delete.html?utm_source=chatgpt.com "Deleting a schedule in EventBridge Scheduler"
[32]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-global-endpoints.html?utm_source=chatgpt.com "Making applications Regional-fault tolerant with global ..."
[33]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-ge-create-endpoint.html?utm_source=chatgpt.com "Creating a global endpoint in Amazon EventBridge"
[34]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-ge-best-practices.html?utm_source=chatgpt.com "Best practices for Amazon EventBridge global endpoints"
[35]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-tutorial-archive-replay.html?utm_source=chatgpt.com "Tutorial: Archive and replay events in Amazon EventBridge"
