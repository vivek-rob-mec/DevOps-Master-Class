# AWS Masterclass — Lesson 32 Part 2

# CloudTrail, AWS Config & EventBridge

## Who Changed What, What Changed, and How AWS Automatically Reacts

Part 1 answered:

```text
HOW IS MY SYSTEM
BEHAVING?
        │
        ▼
   CloudWatch
```

Part 2 answers three completely different questions:

```text
WHO changed it?
      │
      ▼
 CloudTrail


WHAT did the resource
look like before/after?
      │
      ▼
   AWS Config


WHEN something happens,
what should AWS do automatically?
      │
      ▼
 EventBridge
```

The production mental model is:

```text
             PRODUCTION INCIDENT

Security Group suddenly allows
0.0.0.0/0 → TCP/22
            │
            ▼
      CLOUDTRAIL
            │
      Who performed it?
      Which API?
      From what IP?
      Which role/session?
            │
            ▼
        AWS CONFIG
            │
      What was the SG
      configuration before?
      What is it now?
      Is it compliant?
            │
            ▼
       EVENTBRIDGE
            │
      Detect event/change
            │
       ┌────┼────────┐
       ▼    ▼        ▼
     SNS  Lambda   SSM
            │
            ▼
      Alert / Remediate
```

That is one of the most reusable operational architectures in AWS.

---

# PART A — CLOUDWATCH vs CLOUDTRAIL vs CONFIG

# 1. Never Confuse These Three Services

Suppose somebody modifies a production security group at 10:15.

### CloudWatch

May tell you:

```text
Network traffic increased.

5xx rate changed.

CPU changed.
```

### CloudTrail

May tell you:

```text
Role:
ProductionAdmin

called:

AuthorizeSecurityGroupIngress

at:

10:15

from:

203.x.x.x
```

### AWS Config

May tell you:

```text
Before:
22 allowed only from 10.20.0.0/16

After:
22 allowed from 0.0.0.0/0
```

So:

```text
CloudWatch
=
BEHAVIOR


CloudTrail
=
API/AUDIT HISTORY


AWS Config
=
RESOURCE CONFIGURATION HISTORY
```

CloudTrail records activity taken by users, roles, and AWS services, while Config records point-in-time resource configuration and relationships. ([AWS Documentation][1])

---

# PART B — AWS CLOUDTRAIL

# 2. What Is CloudTrail?

AWS CloudTrail is AWS's:

```text
AUDIT / API ACTIVITY RECORD
```

It helps answer:

```text
WHO?

DID WHAT?

WHEN?

FROM WHERE?

TO WHICH RESOURCE?

WITH WHAT RESULT?
```

CloudTrail records actions made through the AWS Console, CLI, SDKs, APIs, and service-to-service activity where supported. ([AWS Documentation][1])

---

# 3. Example

You run:

```bash
aws ec2 stop-instances \
  --instance-ids i-0123456789abcdef0
```

CloudTrail can record information such as:

```text
eventTime
eventSource
eventName
awsRegion
sourceIPAddress
userIdentity
requestParameters
responseElements
resources
errorCode
```

CloudTrail event records include identity, source IP, request details, response details, resource information, and other audit context. ([AWS Documentation][2])

---

# 4. CloudTrail's Four Important Event Categories

Current CloudTrail recognizes:

```text
1. Management events

2. Data events

3. Network activity events

4. Insights events
```

([aws.amazon.com][3])

These are very different.

---

# 5. Management Events

Management events describe:

```text
CONTROL PLANE
```

operations.

Examples:

```text
CreateVpc

RunInstances

StopInstances

CreateUser

AttachRolePolicy

CreateBucket

DeleteTrail

AuthorizeSecurityGroupIngress
```

Think:

```text
"Changing or managing
AWS infrastructure."
```

CloudTrail management events capture control-plane actions such as creating or deleting AWS resources. ([aws.amazon.com][3])

---

# 6. Management Read vs Write

Management events can broadly be:

```text
READ
```

such as:

```text
DescribeInstances

GetRole

ListBuckets
```

and:

```text
WRITE
```

such as:

```text
RunInstances

TerminateInstances

CreateRole

PutBucketPolicy
```

For most incident investigation:

```text
WRITE management events
```

are especially important because they represent infrastructure changes.

---

# 7. Event History — Built In Automatically

Every AWS account automatically gets CloudTrail:

```text
Event History
```

without you creating a trail.

Current Event History provides:

```text
90 days
```

of management events, per Region. ([AWS Documentation][4])

So if someone asks:

> “Who stopped this EC2 instance yesterday?”

you may be able to investigate immediately without previously creating a CloudTrail trail.

---

# 8. Event History Limitations

This is an important exam trap.

Event History shows:

```text
MANAGEMENT EVENTS ONLY
```

It does **not** show:

```text
Data events

Insights events

Network activity events
```

and it is limited to the most recent 90 days in one account and one Region. ([AWS Documentation][4])

### Never forget

```text
CloudTrail exists automatically
≠
everything is automatically retained forever.
```

---

# 9. Event History Is Region-Specific

Suppose someone creates an EC2 instance in:

```text
eu-west-1
```

but you're inspecting CloudTrail Event History in:

```text
ap-south-1
```

you may not see the event there.

Event History records and searches management events on a per-Region basis. ([AWS Documentation][4])

Always ask:

```text
WHICH REGION?
```

---

# 10. Hands-On — Find Recent Events

Use:

```bash
export AWS_REGION=ap-south-1
```

Check identity:

```bash
aws sts get-caller-identity
```

Then:

```bash
aws cloudtrail lookup-events \
  --region "$AWS_REGION"
```

Filter by API:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes \
    AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --region "$AWS_REGION"
```

CloudTrail's `lookup-events` operation searches recent CloudTrail Event History management events. ([AWS Documentation][4])

---

# 11. Security Incident Example

Suppose:

```text
SSH suddenly exposed publicly.
```

Search:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes \
    AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --region ap-south-1
```

Then inspect:

```text
Username / role

CloudTrailEvent

EventTime

ResourceName
```

Inside the CloudTrail JSON, look particularly at:

```text
userIdentity

sourceIPAddress

eventName

eventSource

requestParameters

errorCode

userAgent
```

---

# 12. `userIdentity` Is Extremely Important

Suppose the event says:

```text
userIdentity.type
=
AssumedRole
```

Then inspect:

```text
sessionIssuer

ARN

principalId

sessionContext
```

This may reveal:

```text
TerraformRole

GitHubDeployRole

ProductionAdminRole
```

rather than merely:

```text
"some AWS user."
```

This connects directly to our IAM lesson.

---

# 13. CloudTrail + SourceIdentity

If you implemented:

```text
sts:SourceIdentity
```

during role federation, CloudTrail can provide stronger attribution back toward the original user behind an assumed role.

So instead of:

```text
AdminRole/session123
```

you may have audit context pointing back to:

```text
employee-5827
```

This is one reason we discussed SourceIdentity during IAM.

---

# 14. Data Events

Management events tell you:

```text
"Bucket was created."
```

Data events can tell you:

```text
"Object inside the bucket was read."
```

Example:

```text
s3:GetObject

s3:PutObject
```

or other supported high-volume data-plane resource actions.

CloudTrail data events represent operations performed on or within resources, such as reading or writing an S3 object. ([aws.amazon.com][3])

---

# 15. Data Events Are Not Logged by Default by Trails

This is critical.

By default:

```text
CloudTrail trails
```

do **not** automatically log all data events.

You must configure the desired resource types/event selectors. ([AWS Documentation][5])

Why?

Because data-plane operations can be:

```text
MILLIONS
or
BILLIONS
```

of events.

Example:

```text
every S3 GetObject

every Lambda invocation
```

can create enormous audit volume.

---

# 16. Management vs Data Event

Memorize:

```text
Create S3 bucket
=
MANAGEMENT EVENT


Get an object
inside S3 bucket
=
DATA EVENT
```

Another example:

```text
Create Lambda function
=
MANAGEMENT


Invoke Lambda function
=
DATA EVENT
```

---

# 17. Selective Data Event Logging

Do not automatically log every high-volume data event unless needed.

Instead:

```text
Critical bucket:
customer-financial-data
        │
        ▼
log S3 object data events


Public static asset bucket:
millions of requests
        │
        ▼
evaluate whether detailed
CloudTrail data events are necessary
```

Use event selectors or advanced selectors to scope data-event capture to the resources and operations that matter.

---

# 18. Current CloudTrail Data-Event Aggregation

A newer CloudTrail capability can aggregate high-volume data-event activity into:

```text
5-minute summaries
```

for trends such as:

```text
access frequency

error rate

common users/actions
```

while detailed logs can still be retained where needed. ([Amazon Web Services, Inc.][3])

This can help when raw data-event volume is enormous.

---

# 19. Network Activity Events

This is a newer CloudTrail category many older courses do not teach.

Network activity events provide visibility into AWS API calls made through:

```text
VPC endpoints
```

from private VPCs to AWS services.

They can also provide useful visibility into denied calls through those endpoints. ([AWS Documentation][6])

---

# 20. Example Network Activity Scenario

Imagine:

```text
Private EC2
    │
    ▼
S3 Gateway/Interface path
or other VPC endpoint
    │
    ▼
AWS Service API
```

You want to know:

```text
Which principal
used this private endpoint?

Which API was called?

Was it denied?

Did credentials from outside
our organization attempt to use it?
```

CloudTrail network activity events are designed for this kind of investigation. ([AWS Documentation][6])

---

# 21. CloudTrail Insights

Normal API behavior:

```text
CreateUser:
very rare

AttachRolePolicy:
rare

DescribeInstances:
frequent
```

Suddenly:

```text
CreateUser
CreateUser
CreateUser
CreateUser
...
```

or a sudden spike in API failures.

CloudTrail Insights analyzes API-call activity and error-rate behavior to identify unusual patterns. ([Amazon Web Services, Inc.][3])

---

# 22. Why Insights Is Different

CloudTrail standard event:

```text
"API call occurred."
```

CloudTrail Insights:

```text
"This pattern of API activity
is unusual compared with baseline."
```

So:

```text
CloudTrail
=
EVENT RECORD


CloudTrail Insights
=
ANOMALY IN EVENT BEHAVIOR
```

---

# 23. Trails

If you need:

```text
long-term audit logs

organization logging

S3 archival

CloudWatch Logs delivery

data event logging

network activity event logging

compliance retention
```

you create:

# CloudTrail Trail

A trail delivers CloudTrail activity to S3 and can optionally integrate with CloudWatch Logs and EventBridge. ([Amazon Web Services, Inc.][3])

---

# 24. Production Trail Architecture

```text
AWS Accounts
      │
      ▼
   CloudTrail
      │
      ▼
Multi-Region Trail
      │
      ├────────► Central S3
      │
      ├────────► CloudWatch Logs
      │
      └────────► EventBridge
```

AWS recommends multi-Region trails so events from all enabled Regions are captured consistently. ([AWS Documentation][7])

---

# 25. Why Multi-Region Trail?

Imagine your company only operates in:

```text
ap-south-1
```

but compromised credentials create:

```text
50 EC2 instances
in us-east-2
```

If you're logging only Mumbai:

```text
security blind spot.
```

A multi-Region trail captures events across all enabled Regions and helps detect unexpected activity in otherwise unused Regions. ([AWS Documentation][7])

---

# 26. Organization Trail

For AWS Organizations:

```text
AWS Organization
      │
 ┌────┼─────┐
 ▼    ▼     ▼
Dev Stage Prod
      │
      ▼
Organization Trail
      │
      ▼
Central Log Account/S3
```

CloudTrail supports organization trails that log events across member accounts. ([AWS Documentation][8])

This is far better than asking every workload team to remember to configure auditing manually.

---

# 27. Central Security Logging Architecture

A mature design:

```text
               AWS ORGANIZATION
                      │
                      ▼
              Organization Trail
                      │
                      ▼
                 Log Archive
                   Account
                      │
              ┌───────┴───────┐
              ▼               ▼
          S3 audit bucket     KMS
              │
              ▼
      immutable/controlled logs
```

Then workload administrators should not casually have:

```text
DeleteObject

PutBucketPolicy

DisableCloudTrail
```

against centralized security logging infrastructure.

---

# 28. CloudTrail Log Encryption

CloudTrail logs delivered to S3 use server-side encryption by default, and you can additionally configure SSE-KMS with a customer-managed KMS key. ([Amazon Web Services, Inc.][3])

Then authorization becomes:

```text
CloudTrail
      │
      ▼
S3 bucket policy
      │
      ▼
KMS key policy
```

Exactly like our earlier KMS lessons.

---

# 29. Log File Integrity Validation

What if someone modifies an audit file after CloudTrail writes it?

CloudTrail supports:

```text
LOG FILE INTEGRITY VALIDATION
```

using SHA-256 hashing and RSA digital signatures to help detect whether delivered CloudTrail log/digest files were modified, deleted, or forged. ([AWS Documentation][9])

This is especially valuable for:

```text
audit

forensics

compliance evidence
```

---

# 30. Never Trust Audit Logs You Cannot Protect

Logging architecture should protect against:

```text
disable logging

modify logs

delete logs

modify bucket policy

disable KMS key
```

This is why production logging often uses:

```text
separate account

organization trail

strict bucket policy

KMS

S3 versioning/Object Lock where applicable

least privilege
```

---

# 31. Important 2026 CloudTrail Lake Change

Many older AWS courses will tell you:

```text
Use CloudTrail Lake
for new centralized audit analytics.
```

As of **May 31, 2026**, CloudTrail Lake is no longer open to new customers. Existing customers may continue using existing CloudTrail Lake capabilities, but AWS says it will receive only critical bug fixes/security updates and recommends CloudWatch as the migration/alternative path. CloudTrail itself—including Trails, Insights, and aggregated events—continues to be fully supported. ([AWS Documentation][10])

### Never forget current state

```text
CloudTrail
=
fully supported


CloudTrail Lake
=
existing customers only
from May 31, 2026 onward
```

---

# 32. Newer CloudTrail + CloudWatch Architecture

AWS now supports direct CloudTrail-to-CloudWatch Logs ingestion using:

```text
telemetry enablement rules
```

and service-linked channels, including centralized collection patterns. ([Amazon Web Services, Inc.][3])

So a modern architecture can look like:

```text
CloudTrail Events
      │
      ▼
CloudWatch Logs
      │
      ├── Logs Insights
      ├── SQL
      ├── PPL
      ├── alerts
      ├── centralization
      └── security analytics
```

This is especially relevant for new customers after the CloudTrail Lake availability change.

---

# PART C — AWS CONFIG

# 33. CloudTrail Still Doesn't Tell You Everything

Suppose CloudTrail says:

```text
AuthorizeSecurityGroupIngress
was called at 10:15.
```

Great.

Now the incident responder asks:

> “Exactly what did the security group look like at 10:14?”

CloudTrail's job is not primarily to maintain full state snapshots of resources.

That is AWS Config's job.

---

# 34. What Is AWS Config?

AWS Config continuously or periodically records supported AWS resource configuration information and can maintain configuration history, relationships, and compliance evaluation. ([AWS Documentation][11])

Think:

```text
RESOURCE
    │
    ▼
AWS Config
    │
    ├── current state
    ├── historical state
    ├── relationships
    └── compliance
```

---

# 35. Configuration Item — CI

The core Config object is:

# Configuration Item

A CI represents:

```text
point-in-time resource state.
```

For example:

```text
Security Group:
sg-1234
```

CI could contain:

```text
resource ID

resource type

configuration

relationships

tags

capture time

status
```

AWS defines a configuration item as a point-in-time view containing metadata, attributes, relationships, configuration, and related event information. ([AWS Documentation][11])

---

# 36. Security Group Timeline

Example:

```text
09:00
SSH:
10.0.0.0/16


10:15
SSH:
0.0.0.0/0


10:22
SSH:
10.0.0.0/16
```

AWS Config gives you the resource:

```text
CONFIGURATION HISTORY
```

across those states. ([AWS Documentation][11])

---

# 37. Config vs CloudTrail

This is your permanent mental model:

```text
CloudTrail:

10:15
AdminRole called:
AuthorizeSecurityGroupIngress


AWS Config:

09:59 state:
SSH only internal

10:16 state:
SSH public
```

Together:

```text
WHO changed it?
+
WHAT changed?
```

---

# 38. Resource Relationships

Config doesn't only know isolated resource state.

It can understand supported relationships such as:

```text
EC2 Instance
    │
    ├── attached EBS
    │
    └── associated Security Group
```

AWS Config creates resource relationship information for supported resources. ([AWS Documentation][11])

This helps answer questions such as:

```text
Which EC2 instances
are affected by this SG?
```

---

# 39. Configuration Recorder

AWS Config uses a:

```text
Configuration Recorder
```

to record selected resource types.

Current Config has:

```text
Customer-managed recorder

Service-linked recorder
```

depending on who controls the recording scope. ([AWS Documentation][11])

---

# 40. Continuous vs Daily Recording

Current AWS Config supports two main recording frequencies:

```text
CONTINUOUS

DAILY
```

### Continuous

```text
Record changes
whenever they occur.
```

### Daily

```text
Capture the most recent
different state from the
previous 24-hour period.
```

Continuous is the default recording frequency. ([AWS Documentation][12])

---

# 41. When Continuous Makes Sense

For:

```text
Production security groups

IAM/security infrastructure

critical networking

critical S3 policies

compliance-sensitive resources
```

you usually care about every meaningful configuration transition.

Example:

```text
09:00 safe

09:15 public

09:20 safe again
```

Daily recording could potentially leave you with less fine-grained change history than continuous recording.

---

# 42. Important Firewall Manager Relationship

AWS specifically recommends:

```text
Continuous Config recording
```

when using AWS Firewall Manager because Firewall Manager depends on timely Config resource monitoring. ([AWS Documentation][12])

This connects directly to Lesson 31 Part 5.

---

# 43. Configuration History

Config maintains:

```text
a collection of CIs
for a resource over time.
```

It can answer:

```text
When was it created?

What changed yesterday?

What did it look like before incident?

What relationships changed?
```

Configuration history can also be delivered to S3. ([AWS Documentation][11])

---

# 44. Configuration Snapshot

A snapshot answers:

```text
"What does the recorded
environment look like
at this point in time?"
```

Example:

```text
All EC2

All security groups

All recorded S3 buckets

All supported RDS resources
```

AWS Config snapshots represent the recorded resources and their configurations as a point-in-time collection. ([AWS Documentation][11])

---

# PART D — CONFIG RULES

# 45. Recording State Is Useful — Compliance Is Better

You don't want only:

```text
Port 22 is public.
```

You want:

```text
Port 22 is public
AND
this violates our policy.
```

That is where:

# AWS Config Rules

come in.

---

# 46. Config Rule Mental Model

```text
AWS Resource
     │
     ▼
Configuration
     │
     ▼
Config Rule
     │
 ┌───┴────────┐
 ▼            ▼
COMPLIANT   NON_COMPLIANT
```

AWS Config rules evaluate recorded/configured resource settings against expected conditions. ([AWS Documentation][11])

---

# 47. Example — Restricted SSH

AWS provides a managed rule:

```text
restricted-ssh
```

Its rule identifier is:

```text
INCOMING_SSH_DISABLED
```

It evaluates security groups as noncompliant when SSH is unrestricted from:

```text
0.0.0.0/0
```

or:

```text
::/0
```

([AWS Documentation][13])

That is perfect for our incident example.

---

# 48. Managed Config Rules

AWS provides predefined managed rules for scenarios such as:

```text
EBS encryption

restricted SSH

required tags

S3 security

CloudTrail configuration

IAM security
```

and many other common controls. ([AWS Documentation][14])

Use managed rules where they meet the requirement instead of writing custom logic unnecessarily.

---

# 49. Custom Config Rules

If managed rules cannot express your requirement, Config supports custom rules using:

```text
AWS Lambda

or

AWS CloudFormation Guard
```

logic. ([AWS Documentation][11])

Example custom company rule:

```text
Production EC2
must:

have Environment=prod

use approved security groups

use encrypted root EBS

have approved AMI lineage
```

---

# 50. Trigger Types

Current Config rule triggering can include:

```text
Configuration change

Periodic

Hybrid
```

depending on the rule. ([AWS Documentation][11])

### Change Trigger

```text
SG changed
→ evaluate immediately after Config records change
```

### Periodic

```text
Evaluate every N hours
```

### Hybrid

```text
Both change-based
and scheduled evaluation
```

---

# 51. Detective vs Proactive Evaluation

Modern Config distinguishes:

```text
DETECTIVE

PROACTIVE
```

### Detective

Evaluate:

```text
resources already deployed.
```

### Proactive

Evaluate proposed resource properties:

```text
before deployment
```

for rules that support proactive mode. ([AWS Documentation][11])

This is extremely useful in IaC pipelines.

---

# 52. Important Proactive Rule Trap

Proactive Config evaluation:

```text
DOES NOT itself block deployment.
```

It evaluates whether proposed configuration would be compliant or noncompliant.

You must integrate that result into:

```text
CI/CD policy gate

deployment workflow
```

if you want it to prevent infrastructure from being deployed. ([AWS Documentation][11])

---

# PART E — REMEDIATION

# 53. Config Can Remediate Noncompliance

Suppose:

```text
restricted-ssh
=
NON_COMPLIANT
```

AWS Config can associate a remediation action.

Config remediation uses:

```text
AWS Systems Manager Automation
documents
```

to perform corrective actions. ([AWS Documentation][15])

Architecture:

```text
Config Rule
   │
   ▼
NON_COMPLIANT
   │
   ▼
Remediation
   │
   ▼
SSM Automation
   │
   ▼
Fix Resource
```

---

# 54. Manual vs Automatic Remediation

AWS Config supports:

```text
Manual remediation

Automatic remediation
```

depending on the configured action. ([AWS Documentation][16])

Use manual remediation where:

```text
change is risky

business context needed

potential outage
```

Use automatic remediation where:

```text
violation is unambiguous

fix is safe

blast radius known
```

---

# 55. Auto-Remediation Can Cause Outages

Imagine security group has:

```text
0.0.0.0/0 → 443
```

which is correct for an internet-facing ALB.

A poorly designed automation that removes every:

```text
0.0.0.0/0
```

rule could take the application offline.

Therefore:

```text
NON_COMPLIANT
≠
blindly mutate everything
```

You need precise policy semantics.

---

# PART F — CONFORMANCE PACKS

# 56. One Rule Does Not Make a Security Baseline

Production might require:

```text
EBS encrypted

SSH restricted

S3 public access controlled

CloudTrail enabled

MFA requirements

required tags

RDS encryption
```

Instead of manually deploying dozens of individual rules:

```text
CONFORMANCE PACK
```

can group Config rules and remediation actions into one deployable package. ([AWS Documentation][17])

---

# 57. Conformance Pack

Mental model:

```text
Security Baseline
      │
      ▼
Conformance Pack
      │
 ┌────┼──────────┐
 ▼    ▼          ▼
Rule1 Rule2      RuleN
 │     │           │
 └─────┼───────────┘
       ▼
Remediation
```

Conformance packs can be deployed in one account/Region or across an AWS Organization. ([AWS Documentation][17])

---

# 58. Example Production Pack

```text
Production-Baseline
│
├── restricted-ssh
├── encrypted-volumes
├── approved-amis
├── cloudtrail-enabled
├── s3-public-access-controls
├── rds-encryption
└── required-tags
```

Now your security baseline becomes:

```text
VERSIONABLE

REPEATABLE

MULTI-ACCOUNT
```

rather than manual configuration.

---

# PART G — CONFIG AGGREGATORS

# 59. 100 Accounts Problem

Without aggregation:

```text
Security engineer
   │
   ├── log into account 1
   ├── account 2
   ├── account 3
   └── ...
```

Not scalable.

AWS Config Aggregator provides:

```text
MULTI-ACCOUNT
+
MULTI-REGION
```

configuration/compliance visibility in a single account and Region. ([AWS Documentation][18])

---

# 60. Aggregator Architecture

```text
          AWS ORGANIZATION
               │
       ┌───────┼─────────┐
       ▼       ▼         ▼
      Dev    Stage      Prod
       │       │         │
       └───────┼─────────┘
               ▼
         Config Aggregator
               │
               ▼
         Security Account
```

---

# 61. Important Aggregator Limitation

Config Aggregator gives:

```text
READ-ONLY aggregated visibility.
```

It does not automatically give you mutating authority into the source accounts.

AWS explicitly describes the aggregator as a replicated, read-only view of source configuration and compliance data. ([AWS Documentation][11])

---

# PART H — CONFIG ADVANCED QUERIES

# 62. Query AWS Resource State with SQL-Like Syntax

AWS Config Advanced Queries supports a subset of SQL `SELECT` syntax against current configuration data. ([AWS Documentation][19])

Example question:

> Which EC2 instances use security group `sg-123456`?

Conceptually:

```sql
SELECT
  resourceId,
  resourceType
WHERE
  resourceType = 'AWS::EC2::Instance'
  AND relationships.resourceId = 'sg-123456'
```

AWS documents resource-relationship queries like this for Config advanced querying. ([AWS Documentation][20])

---

# 63. Why This Is Powerful

Without Config:

```text
Call EC2 API
Call RDS API
Call S3 API
Call ELB API
Normalize results
```

With Config Advanced Query:

```text
query current
configuration inventory
across supported resources
```

This is excellent for:

```text
asset inventory

security investigations

compliance reporting

architecture discovery
```

---

# PART I — EVENTBRIDGE

# 64. Now We Know Who and What

CloudTrail:

```text
WHO changed it.
```

Config:

```text
WHAT changed.
```

But how do we automatically react?

That is:

# Amazon EventBridge

---

# 65. What Is EventBridge?

EventBridge is a serverless event-routing service for building event-driven architectures.

It connects:

```text
Event Producers
       │
       ▼
Event Bus
       │
       ▼
Rules
       │
       ▼
Targets
```

Sources can include AWS services, custom applications, and SaaS integrations. ([AWS Documentation][21])

---

# 66. The EventBridge Mental Model

```text
SOURCE
   │
   ▼
 EVENT
   │
   ▼
EVENT BUS
   │
   ▼
 RULE
   │
"Does event match?"
   │
 ┌─┴───┐
YES    NO
 │      │
 ▼      X
TARGET
```

Example:

```text
EC2 Instance
stopped
    │
    ▼
EventBridge
    │
    ▼
Rule matches:
state=stopped
    │
    ▼
Lambda
```

---

# 67. Event Bus

An EventBridge event bus receives events and routes them to zero or more targets through rules. ([AWS Documentation][22])

Common types you'll encounter:

```text
Default event bus

Custom event bus

Partner event bus
```

The default bus automatically receives events from many AWS services. ([AWS Documentation][22])

---

# 68. Rule

A rule answers:

```text
"Which events do I care about?"
```

Example event pattern:

```json
{
  "source": ["aws.ec2"],
  "detail-type": [
    "EC2 Instance State-change Notification"
  ],
  "detail": {
    "state": ["stopped"]
  }
}
```

If the event matches:

```text
invoke target.
```

EventBridge rules compare incoming events against JSON event patterns. ([AWS Documentation][23])

---

# 69. EventBridge Is Content-Based Routing

You don't have to process:

```text
every EC2 event
```

You can ask for:

```text
only:
EC2 stopped
```

or:

```text
only:
production resources
```

or:

```text
only:
specific event types
```

EventBridge supports advanced pattern operators including prefixes, suffixes, `anything-but`, numeric comparisons, and other content filters. ([AWS Documentation][24])

---

# 70. Event Can Match Multiple Rules

Example event:

```text
EC2 stopped
```

could match:

```text
Rule A
→ notify operations

Rule B
→ record event

Rule C
→ trigger remediation
```

An event bus evaluates each rule independently; a matching event can therefore fan out through multiple rules. ([AWS Documentation][22])

---

# 71. Targets

EventBridge rules can target AWS services and other destinations.

Typical examples:

```text
Lambda

SNS

SQS

Step Functions

another EventBridge bus

API destinations
```

EventBridge can also invoke HTTP endpoints using API destinations. ([AWS Documentation][25])

---

# 72. EventBridge + CloudTrail

This is central to our incident.

CloudTrail can send supported event types to the default EventBridge event bus, including:

```text
AWS API Call via CloudTrail

AWS Console Signin via CloudTrail

AWS Console Action via CloudTrail

AWS Service Event via CloudTrail

AWS Insight via CloudTrail

AWS Network Activity Event via CloudTrail
```

([AWS Documentation][26])

---

# 73. Important CloudTrail/EventBridge Requirement

For CloudTrail event categories delivered to EventBridge:

```text
you need an active CloudTrail trail
with appropriate logging.
```

CloudTrail Event History alone is not the same as configuring that event delivery path. ([AWS Documentation][26])

This is an important current behavior.

---

# 74. Write vs Read-Only Management Events in EventBridge

Current EventBridge rule states distinguish management events delivered by CloudTrail.

Normal:

```text
ENABLED
```

matches write/mutating management events delivered via CloudTrail, while read-only management events require:

```text
ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS
```

on the applicable bus/rule. ([AWS Documentation][26])

Why?

Read-only APIs can be extremely high volume.

Examples:

```text
DescribeKey

GetRole

GetPolicy
```

---

# PART J — SECURITY GROUP INCIDENT AUTOMATION

# 75. EventBridge Pattern for Security Group Changes

Suppose we want to detect ingress modifications.

A CloudTrail-based EventBridge event can be matched conceptually with:

```json
{
  "source": ["aws.ec2"],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "ec2.amazonaws.com"
    ],
    "eventName": [
      "AuthorizeSecurityGroupIngress",
      "ModifySecurityGroupRules"
    ]
  }
}
```

Now:

```text
SG change
   │
   ▼
CloudTrail
   │
   ▼
EventBridge
   │
   ▼
rule matches
```

AWS documents the `AWS API Call via CloudTrail` EventBridge pattern for reacting to API changes. ([AWS Documentation][26])

---

# 76. First Response Should Often Be Notification

Target:

```text
SNS
```

Message:

```text
SECURITY GROUP MODIFIED

Account:
123456789012

Role:
ProductionAdmin

Event:
AuthorizeSecurityGroupIngress

Region:
ap-south-1

Time:
10:15
```

This gives the team immediate visibility.

---

# 77. Better Response — Enrichment

Instead of sending raw JSON:

```text
EventBridge
    │
    ▼
Lambda
    │
    ├── parse CloudTrail event
    ├── identify security group
    ├── query Config
    ├── identify attached EC2/ALB resources
    └── notify SOC
```

Now the notification can say:

```text
sg-abc123 was modified.

Affected:
3 production EC2 instances

New rule:
0.0.0.0/0 TCP 22

Actor:
assumed-role/ProductionAdmin
```

Much more actionable.

---

# 78. EventBridge Input Transformer

If you don't need full Lambda enrichment, EventBridge supports:

```text
Input Transformer
```

to select fields from an incoming event and reshape the payload before delivering it to a target. ([AWS Documentation][27])

This is useful for simple:

```text
event → formatted SNS/SQS message
```

flows.

---

# PART K — RETRIES AND DLQs

# 79. What If Target Is Down?

Suppose:

```text
EventBridge
    │
    ▼
Lambda
    X
throttled/unavailable
```

EventBridge retries retriable failures.

Current default retry behavior is:

```text
up to 24 hours

up to 185 attempts

with exponential backoff + jitter
```

([AWS Documentation][28])

---

# 80. After Retries Are Exhausted

Without a DLQ:

```text
event can be dropped
after retries are exhausted.
```

With:

```text
SQS Dead-Letter Queue
```

failed delivery can be preserved for later analysis/reprocessing. ([AWS Documentation][28])

Architecture:

```text
EventBridge
     │
     ▼
Target
     X
     │
  retries
     │
     X
     ▼
SQS DLQ
```

---

# 81. Production Rule

For important automation:

```text
CONFIGURE A DLQ.
```

Especially:

```text
security incident automation

financial workflow

compliance processing

critical notifications
```

AWS recommends DLQs for EventBridge targets when you need to retain events that could not be delivered. ([AWS Documentation][29])

---

# 82. At-Least-Once Thinking

Event-driven systems must assume:

```text
an event may be delivered
more than once.
```

Therefore target processing should be:

# Idempotent

Example:

Bad remediation:

```text
Each duplicate event
creates another resource.
```

Better:

```text
Check desired/current state.

If already fixed:
do nothing.
```

EventBridge uses at-least-once delivery semantics for targets, so duplicate-safe consumers are important. ([AWS Documentation][30])

---

# PART L — ARCHIVE AND REPLAY

# 83. Imagine a Bug in Your Event Consumer

Events arrive:

```text
Monday
Tuesday
Wednesday
```

but your Lambda had a bug.

After you fix it:

> “Can I replay the original events?”

EventBridge supports:

```text
Archive

Replay
```

for event buses. ([AWS Documentation][31])

---

# 84. Archive

```text
Event Bus
    │
    ├── rules
    │
    └── Archive
```

You can archive selected event-bus events according to the archive configuration.

---

# 85. Replay

Later:

```text
Archive
   │
   ▼
Replay
   │
   ▼
Original Event Bus
   │
   ▼
Rules
```

Current EventBridge replay sends archived events back to the **same source event bus**; replay does not delete them from the archive. ([AWS Documentation][31])

---

# 86. Why Archive/Replay Is Valuable

Excellent for:

```text
debugging

consumer bug recovery

testing new rule logic

reprocessing missed downstream workflows
```

But again:

```text
target must be idempotent.
```

because you're intentionally processing previous events again.

---

# PART M — CROSS-ACCOUNT EVENTBRIDGE

# 87. Central Security Event Bus

Imagine:

```text
AWS Organization

Dev
Stage
Prod
Security
```

Each workload account produces security events.

Architecture:

```text
Dev EventBridge
        \
Stage ────► Security Account
        /    Central Event Bus
Prod ──/
              │
              ▼
          SOC Automation
```

EventBridge supports sending events between event buses across AWS accounts and supported cross-Region destinations. ([AWS Documentation][32])

---

# 88. Resource Policy

The receiving EventBridge bus can use a resource policy controlling:

```text
which accounts
or organization principals
may PutEvents.
```

This lets you build centralized:

```text
security

operations

audit

deployment-event
```

architectures.

---

# PART N — EVENTBRIDGE SCHEDULER

# 89. EventBridge Is Also Associated With Scheduling

You may encounter older architectures:

```text
EventBridge scheduled rule
```

using:

```text
rate()

cron()
```

These still exist but AWS labels traditional scheduled rules as:

```text
legacy.
```

For new scheduled workload designs, use:

# Amazon EventBridge Scheduler

instead. ([AWS Documentation][33])

---

# 90. EventBridge Scheduler Mental Model

```text
Schedule
   │
   ├── one-time
   ├── rate
   └── cron
       │
       ▼
EventBridge Scheduler
       │
       ▼
Target
```

Use cases:

```text
start ECS task nightly

trigger Step Functions

invoke Lambda tomorrow

run maintenance weekly

send delayed task
```

We'll revisit EventBridge heavily in the serverless/event-driven lesson.

---

# PART O — CLOUDTRAIL + CONFIG + EVENTBRIDGE FULL INCIDENT

# 91. Production Incident

At:

```text
10:15 AM
```

production security group becomes:

```text
TCP 22
0.0.0.0/0
```

Let's troubleshoot it correctly.

---

# 92. Step 1 — Verify Current State

```bash
aws ec2 describe-security-groups \
  --group-ids sg-0123456789abcdef0 \
  --region ap-south-1
```

Confirm:

```text
Is SSH actually public?
```

Never investigate an imagined state.

---

# 93. Step 2 — CloudTrail

Search:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes \
    AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --region ap-south-1
```

Now determine:

```text
Actor

Role/session

Time

Source IP

User agent

Request parameters
```

This answers:

# WHO?

---

# 94. Step 3 — AWS Config History

Query the resource's configuration history:

```bash
aws configservice get-resource-config-history \
  --resource-type AWS::EC2::SecurityGroup \
  --resource-id sg-0123456789abcdef0 \
  --region ap-south-1
```

Now compare:

```text
before

after
```

This answers:

# WHAT CHANGED?

AWS Config's configuration history is specifically designed to provide historical resource states. ([AWS Documentation][11])

---

# 95. Step 4 — Config Compliance

Use:

```text
restricted-ssh
```

The security group should become:

```text
NON_COMPLIANT
```

if TCP/22 is unrestricted to IPv4 `0.0.0.0/0` or IPv6 `::/0`. ([AWS Documentation][13])

---

# 96. Step 5 — Identify Blast Radius

Use Config relationships or AWS APIs:

```text
Which instances use SG?

Which ENIs?

Which ALBs?

Which services?
```

An insecure SG attached to:

```text
unused test EC2
```

and the same SG attached to:

```text
production database
```

have very different severity.

---

# 97. Step 6 — EventBridge

CloudTrail API call:

```text
AuthorizeSecurityGroupIngress
```

is delivered to EventBridge.

Rule matches:

```text
security group mutation.
```

Target:

```text
Lambda / Step Functions
```

then evaluates:

```text
Was unrestricted SSH created?
```

---

# 98. Step 7 — Safe Automatic Response

Possible flow:

```text
Detect SG change
       │
       ▼
Inspect event
       │
       ▼
Is port 22/3389
open to 0.0.0.0/0?
       │
   ┌───┴────┐
  NO       YES
   │        │
   ▼        ▼
 Ignore   classify environment
              │
       ┌──────┼────────┐
       ▼      ▼        ▼
     Dev    Stage     Prod
                       │
                       ▼
               Notify Security
                       │
                       ▼
              optional automatic
                 remediation
```

This is safer than:

```text
"Any SG change → undo it."
```

---

# 99. Step 8 — Remediate

Possible options:

```text
Config automatic remediation
via SSM Automation
```

or:

```text
EventBridge
→ Lambda/Step Functions
→ EC2 revoke-security-group-ingress
```

Choose based on:

```text
policy complexity

risk

audit requirements

response time

need for human approval
```

---

# 100. Step 9 — Notify

Send:

```text
Resource
Old configuration
New configuration
CloudTrail actor
Account
Region
Severity
Remediation result
```

to:

```text
SNS

Slack/SIEM integration

incident system
```

A good alert answers:

```text
WHAT happened?

WHO did it?

WHAT is affected?

WHAT happened automatically?

WHAT should I do now?
```

---

# PART P — TERRAFORM

# 101. Terraform CloudTrail

Current HashiCorp AWS provider exposes:

```text
aws_cloudtrail
```

including data-event selector capabilities. ([Terraform Registry][34])

Example:

```hcl
resource "aws_cloudtrail" "organization" {
  name = "production-audit"

  s3_bucket_name = aws_s3_bucket.audit.id

  include_global_service_events = true
  is_multi_region_trail         = true

  enable_log_file_validation = true

  kms_key_id = aws_kms_key.cloudtrail.arn
}
```

For organization deployments, additional organization-specific settings and permissions should be configured according to your logging account architecture.

---

# 102. Terraform Security Principle

Avoid:

```text
CloudTrail bucket
=
same bucket where developers
have broad S3 admin access
```

Better:

```text
Dedicated audit bucket

Separate security/log account

Restricted writers

Restricted deletions

KMS

integrity validation
```

---

# 103. Terraform AWS Config Recorder

The current AWS provider exposes:

```text
aws_config_configuration_recorder
```

and creating the resource alone does not automatically start recording; Config recorder status is managed separately. ([Terraform Registry][35])

Conceptually:

```hcl
resource "aws_config_configuration_recorder" "main" {
  name     = "production-config"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = true
  }
}
```

---

# 104. Terraform Config Rule

Current provider:

```text
aws_config_config_rule
```

requires an existing configuration recorder. ([Terraform Registry][36])

Example:

```hcl
resource "aws_config_config_rule" "restricted_ssh" {
  name = "restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [
    aws_config_configuration_recorder.main
  ]
}
```

The managed rule checks security groups for unrestricted SSH access. ([AWS Documentation][13])

---

# 105. Terraform Conformance Pack

The AWS provider exposes:

```text
aws_config_conformance_pack
```

for packaging Config rules and remediation actions. ([Terraform Registry][37])

This is useful for:

```text
production baseline

PCI controls

security baseline

tagging baseline
```

deployed repeatedly.

---

# 106. Terraform EventBridge Rule

Current provider uses the historical resource naming:

```text
aws_cloudwatch_event_rule
```

because EventBridge evolved from CloudWatch Events. ([Terraform Registry][38])

Example:

```hcl
resource "aws_cloudwatch_event_rule" "sg_change" {
  name = "detect-security-group-changes"

  event_pattern = jsonencode({
    source = ["aws.ec2"]

    detail-type = [
      "AWS API Call via CloudTrail"
    ]

    detail = {
      eventSource = [
        "ec2.amazonaws.com"
      ]

      eventName = [
        "AuthorizeSecurityGroupIngress",
        "ModifySecurityGroupRules"
      ]
    }
  })
}
```

---

# 107. EventBridge Target

Current provider resource:

```text
aws_cloudwatch_event_target
```

manages the EventBridge rule target. ([Terraform Registry][39])

Example:

```hcl
resource "aws_cloudwatch_event_target" "security_lambda" {
  rule = aws_cloudwatch_event_rule.sg_change.name

  arn = aws_lambda_function.security_response.arn
}
```

Then grant EventBridge permission to invoke the function.

---

# PART Q — TROUBLESHOOTING

# 108. “CloudTrail Doesn't Show My S3 GetObject”

Likely:

```text
You only have management-event history.
```

`GetObject` is a:

```text
DATA EVENT
```

and data events need appropriate trail/event selection. ([AWS Documentation][5])

---

# 109. “CloudTrail Doesn't Show Event from Three Months Ago”

Event History only retains:

```text
90 days.
```

For longer historical logging, use a trail and durable storage such as S3/CloudWatch according to the architecture. ([AWS Documentation][4])

---

# 110. “I Don't See the Event in EventBridge”

Check:

```text
Is CloudTrail trail active?

Is required event type logged?

Correct Region?

Correct default event bus?

Correct event pattern?

Is this a read-only management event?

Does rule state include read-only CloudTrail management events?
```

CloudTrail-originated EventBridge events require an active trail, and read-only management events need the expanded rule state. ([AWS Documentation][26])

---

# 111. “Config Says Nothing About the Resource”

Check:

```text
Config enabled in this Region?

Recorder running?

Resource type included?

Recording frequency?

Was Config enabled at the time?
```

AWS Config only builds history from the point where the recorder captures the supported resource. ([AWS Documentation][40])

---

# 112. “Config Rule Says NON_COMPLIANT but Nothing Was Fixed”

Config rule:

```text
detects compliance.
```

It does **not** automatically remediate unless you configure:

```text
remediation action
```

using SSM Automation/manual/automatic remediation. ([AWS Documentation][15])

---

# 113. “Aggregator Shows Resource but I Can't Modify It”

Correct behavior.

Config Aggregator provides:

```text
read-only aggregated visibility.
```

It does not make the aggregator account an administrator of the source resource. ([AWS Documentation][11])

---

# 114. “EventBridge Lambda Missed an Event”

Check:

```text
Event pattern

target permission

Lambda throttling

retry metrics

DLQ

rule state

event source

Region
```

Remember EventBridge will retry retriable target failures by default for up to 24 hours/185 attempts, then drop the event unless you configured a DLQ. ([AWS Documentation][28])

---

# 115. “EventBridge Rule Is Triggering Itself Forever”

Classic loop:

```text
Rule detects:
bucket policy change

Lambda fixes:
bucket policy

fix creates:
bucket policy change

Rule detects again
```

Result:

```text
INFINITE EVENT LOOP
```

AWS specifically warns that rules can cause recursive loops if automated remediation generates the same event the rule matches. ([AWS Documentation][23])

Fix with:

```text
precise event patterns

state checks

tags/markers

idempotency

change-source filtering
```

---

# PART R — SAA-C03 / DOP-C02 SCENARIOS

# 116. Scenario

> Need to know who terminated an EC2 instance yesterday.

Think:

```text
CloudTrail Event History
```

Search:

```text
TerminateInstances
```

---

# 117. Scenario

> Need to know who downloaded an object from sensitive S3 bucket.

Think:

```text
CloudTrail S3 data events
```

not management Event History alone. ([AWS Documentation][5])

---

# 118. Scenario

> Need to know what a security group looked like before yesterday's change.

Think:

```text
AWS Config configuration history.
```

([AWS Documentation][11])

---

# 119. Scenario

> Need to continuously flag public SSH access.

Think:

```text
AWS Config

restricted-ssh
```

([AWS Documentation][13])

---

# 120. Scenario

> Need to automatically fix noncompliant Config resources.

Think:

```text
Config remediation

+
SSM Automation
```

([AWS Documentation][15])

---

# 121. Scenario

> Need one security compliance baseline across 100 AWS accounts.

Think:

```text
AWS Config
Conformance Packs
+
AWS Organizations
```

([AWS Documentation][41])

---

# 122. Scenario

> Need centralized multi-account, multi-Region Config visibility.

Think:

```text
AWS Config Aggregator
```

([AWS Documentation][18])

---

# 123. Scenario

> EC2 goes into stopped state and Lambda should execute automatically.

Think:

```text
EventBridge event bus
+
rule
+
Lambda target
```

([AWS Documentation][22])

---

# 124. Scenario

> Need to react specifically when someone calls `StopInstances`.

Think:

```text
CloudTrail
+
EventBridge
AWS API Call via CloudTrail
```

([AWS Documentation][42])

---

# 125. Scenario

> Event target may fail and event must not disappear.

Think:

```text
EventBridge Retry Policy
+
SQS DLQ
```

([AWS Documentation][28])

---

# 126. Scenario

> Need to reprocess yesterday's application events after fixing a consumer.

Think:

```text
EventBridge Archive
+
Replay
```

([AWS Documentation][31])

---

# 127. Scenario

> Need Lambda to run every night at 2 AM.

For new architectures:

```text
EventBridge Scheduler
```

rather than building around legacy scheduled rules. ([AWS Documentation][33])

---

# PART S — NEVER-FORGET MASTER DIAGRAM

```text
                     AWS CHANGE

                        │
                        ▼
                  API REQUEST
                        │
                        ▼
                    CloudTrail
                        │
              WHO / WHAT API / WHEN
                        │
                        ▼

                     Resource
                        │
                        ▼
                    AWS Config
                        │
             BEFORE / AFTER / COMPLIANCE
                        │
                        ▼

                  EventBridge
                        │
                 MATCH EVENT
                        │
            ┌───────────┼────────────┐
            ▼           ▼            ▼
          Alert       Analyze       Fix
            │           │            │
            ▼           ▼            ▼
           SNS        Lambda       SSM
                                    │
                                    ▼
                               Remediation
```

---

# 128. 30 Rules to Burn Into Memory

```text
1. CloudWatch tells you how systems behave.

2. CloudTrail tells you who performed AWS activity.

3. AWS Config records resource configuration state.

4. EventBridge reacts to events.

5. CloudTrail Event History exists automatically.

6. Event History currently retains 90 days.

7. Event History shows management events only.

8. Management events are control-plane actions.

9. Data events are resource/data-plane operations.

10. S3 GetObject is a data event.

11. Data events require explicit logging configuration.

12. Network activity events provide VPC endpoint API visibility.

13. CloudTrail Insights detects unusual API activity patterns.

14. Trails provide ongoing durable audit logging.

15. Prefer multi-Region CloudTrail trails.

16. Organizations should use centralized organization trails.

17. Protect CloudTrail logs separately from workloads.

18. Enable CloudTrail log integrity validation for strong audit assurance.

19. CloudTrail Lake stopped accepting new customers
    on May 31, 2026.

20. AWS recommends CloudWatch as the modern
    audit analytics path for new designs.

21. AWS Config's core record is the Configuration Item.

22. Config history shows before/after resource state.

23. Config rules evaluate compliance.

24. Managed Config rules avoid unnecessary custom code.

25. Proactive Config evaluation does not itself block deployment.

26. Config remediation uses SSM Automation.

27. Conformance Packs group compliance rules/remediations.

28. EventBridge rule = pattern + target.

29. Use retry policies and DLQs for important events.

30. Event consumers and remediation workflows
    should be idempotent.
```

---

# The Most Important Troubleshooting Formula

When a resource mysteriously changes:

```text
1.
IS IT REALLY CHANGED?
        │
        ▼
service API / console


2.
WHO CHANGED IT?
        │
        ▼
CloudTrail


3.
WHAT WAS IT BEFORE?
        │
        ▼
AWS Config


4.
DID IT VIOLATE POLICY?
        │
        ▼
Config Rule


5.
WHO ELSE IS AFFECTED?
        │
        ▼
Config relationships /
resource inventory


6.
HOW DO WE REACT?
        │
        ▼
EventBridge


7.
HOW DO WE FIX?
        │
        ▼
SSM / Lambda /
Step Functions


8.
HOW DO WE PREVENT REPEAT?
        │
        ▼
IaC + Config +
SCP + IAM + alerts
```

That is an enterprise AWS operations runbook.

---

# ✅ Lesson 32 Part 2 Complete

You now understand:

```text
✓ CloudWatch vs CloudTrail vs Config
✓ CloudTrail fundamentals
✓ event records
✓ userIdentity
✓ API audit context

✓ management events
✓ read/write management events
✓ data events
✓ network activity events
✓ Insights events

✓ Event History
✓ 90-day history
✓ Event History limitations
✓ Regional behavior

✓ trails
✓ multi-Region trails
✓ organization trails
✓ central audit account
✓ S3 trail storage
✓ KMS encryption
✓ integrity validation

✓ current CloudTrail Lake availability change
✓ 2026 CloudTrail → CloudWatch direction
✓ telemetry enablement/direct integration concepts

✓ AWS Config
✓ configuration recorder
✓ customer/service-linked recorders
✓ continuous vs daily recording
✓ Configuration Items
✓ configuration history
✓ snapshots
✓ relationships

✓ Config rules
✓ managed rules
✓ custom Lambda rules
✓ CloudFormation Guard rules
✓ restricted-ssh
✓ change/periodic/hybrid triggers
✓ detective evaluation
✓ proactive evaluation

✓ remediation
✓ SSM Automation
✓ manual/automatic remediation
✓ conformance packs
✓ organization conformance packs
✓ aggregators
✓ Advanced Query

✓ EventBridge
✓ default/custom event buses
✓ rules
✓ event patterns
✓ content filtering
✓ input transformers
✓ targets
✓ CloudTrail events through EventBridge
✓ read-only event considerations
✓ retries
✓ 24-hour / 185-attempt default retry model
✓ DLQs
✓ idempotency
✓ archive
✓ replay
✓ cross-account events
✓ EventBridge Scheduler

✓ full security-group forensic workflow
✓ Terraform CloudTrail
✓ Terraform AWS Config
✓ Terraform Config rules
✓ Terraform EventBridge
✓ SAA-C03 scenarios
✓ DOP-C02 troubleshooting
```

# Next — Lesson 32 Part 3

# **AWS Systems Manager & Production Fleet Operations**

Now we move from:

```text
OBSERVE / AUDIT / DETECT
```

to:

```text
OPERATE AWS SERVERS
WITHOUT SSHING INTO EVERYTHING
```

We'll build:

```text
                    SYSTEMS MANAGER

                          │
       ┌──────────────────┼──────────────────┐
       ▼                  ▼                  ▼
 Session Manager       Run Command       Patch Manager
       │                  │                  │
       ▼                  ▼                  ▼
 No inbound SSH       execute safely     patch fleets


       ┌──────────────────┼─────────────────────┐
       ▼                  ▼                     ▼
   Inventory          Automation          State Manager
       │                  │                     │
       ▼                  ▼                     ▼
 software/packages    runbooks             desired state


                         FLEET
                          │
                ┌─────────┼─────────┐
                ▼         ▼         ▼
               EC2      On-prem   Hybrid
```

We’ll cover **SSM Agent, managed-node requirements, IAM instance profiles, Session Manager, shell access without port 22, port forwarding, Run Command, documents, State Manager, Patch Manager, patch baselines/policies, Maintenance Windows, Inventory, Automation runbooks, Distributor, Parameter Store integration, hybrid/on-prem activation, VPC endpoints/private SSM operation, central multi-account operations, Terraform, incident response, and a production “no SSH” server-management capstone**.

[1]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html "What Is AWS CloudTrail? - AWS CloudTrail"
[2]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-record-contents.html?utm_source=chatgpt.com "CloudTrail record contents for management, data, and ..."
[3]: https://aws.amazon.com/cloudtrail/features/ "AWS CloudTrail Features - Amazon Web Services"
[4]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html "Working with CloudTrail event history - AWS CloudTrail"
[5]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html?utm_source=chatgpt.com "Logging data events - AWS CloudTrail"
[6]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-network-events-with-cloudtrail.html?utm_source=chatgpt.com "Logging network activity events - AWS CloudTrail"
[7]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/best-practices-security.html?utm_source=chatgpt.com "Security best practices in AWS CloudTrail"
[8]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html?utm_source=chatgpt.com "Creating a trail for an organization - AWS CloudTrail"
[9]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-log-file-validation-intro.html?utm_source=chatgpt.com "Validating CloudTrail log file integrity"
[10]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-lake-service-availability-change.html "CloudTrail Lake availability change - AWS CloudTrail"
[11]: https://docs.aws.amazon.com/config/latest/developerguide/config-concepts.html "AWS Config terminology and concepts - AWS Config"
[12]: https://docs.aws.amazon.com/config/latest/developerguide/managing-recorder_console-change-recording-frequency.html?utm_source=chatgpt.com "Changing the recording frequency for the customer managed ..."
[13]: https://docs.aws.amazon.com/config/latest/developerguide/restricted-ssh.html?utm_source=chatgpt.com "restricted-ssh - AWS Config"
[14]: https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config_use-managed-rules.html?utm_source=chatgpt.com "AWS Config Managed Rules"
[15]: https://docs.aws.amazon.com/config/latest/developerguide/remediation.html?utm_source=chatgpt.com "Remediating Noncompliant Resources with AWS Config"
[16]: https://docs.aws.amazon.com/config/latest/developerguide/setup-autoremediation.html?utm_source=chatgpt.com "Setting Up Auto Remediation for AWS Config"
[17]: https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html?utm_source=chatgpt.com "Conformance Packs for AWS Config"
[18]: https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html?utm_source=chatgpt.com "Multi-Account Multi-Region Data Aggregation for AWS Config"
[19]: https://docs.aws.amazon.com/config/latest/developerguide/querying-AWS-resources.html?utm_source=chatgpt.com "Querying the Current Configuration State of AWS ..."
[20]: https://docs.aws.amazon.com/config/latest/developerguide/faq.html?utm_source=chatgpt.com "Frequently Asked Questions - AWS Config"
[21]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html?utm_source=chatgpt.com "What Is Amazon EventBridge? - Amazon ..."
[22]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-bus.html "Event buses in Amazon EventBridge - Amazon EventBridge"
[23]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html?utm_source=chatgpt.com "Creating Amazon EventBridge event patterns"
[24]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-pattern-operators.html?utm_source=chatgpt.com "Comparison operators for use in event patterns ..."
[25]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-targets.html?utm_source=chatgpt.com "Event bus targets in Amazon EventBridge"
[26]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-service-event-cloudtrail.html?utm_source=chatgpt.com "AWS service events delivered via AWS CloudTrail"
[27]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-transform-target-input.html?utm_source=chatgpt.com "Amazon EventBridge input transformation"
[28]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-retry-policy.html "How EventBridge retries delivering events - Amazon EventBridge"
[29]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-monitoring-events-best-practices.html?utm_source=chatgpt.com "Best practices for monitoring event delivery in ..."
[30]: https://docs.aws.amazon.com/decision-guides/latest/decision-guides/sns-or-sqs-or-eventbridge.html?utm_source=chatgpt.com "Amazon SQS, Amazon SNS, or Amazon EventBridge?"
[31]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-archive.html?utm_source=chatgpt.com "Archiving and replaying events in Amazon EventBridge"
[32]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cross-account.html?utm_source=chatgpt.com "Sending and receiving events between AWS accounts in ..."
[33]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-rule-schedule.html?utm_source=chatgpt.com "Creating a scheduled rule (legacy) in Amazon EventBridge"
[34]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail?utm_source=chatgpt.com "aws_cloudtrail | Resources | hashicorp/aws - Terraform Registry"
[35]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder.html?utm_source=chatgpt.com "aws_config_configuration_recor..."
[36]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_config_rule?utm_source=chatgpt.com "aws_config_config_rule | Resources | hashicorp/aws | Terraform"
[37]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_conformance_pack?utm_source=chatgpt.com "aws_config_conformance_pack | Resources | hashicorp/aws"
[38]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule?utm_source=chatgpt.com "aws_cloudwatch_event_rule | Resources | hashicorp/aws"
[39]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target?utm_source=chatgpt.com "aws_cloudwatch_event_target | Resources | hashicorp/aws"
[40]: https://docs.aws.amazon.com/config/latest/developerguide/how-does-config-work.html?utm_source=chatgpt.com "How AWS Config Works"
[41]: https://docs.aws.amazon.com/config/latest/developerguide/conformance-pack-organization-apis.html?utm_source=chatgpt.com "Managing Conformance Packs for AWS Config Across all ..."
[42]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-log-api-call.html?utm_source=chatgpt.com "Create an EventBridge rule that reacts to AWS API calls via ..."
