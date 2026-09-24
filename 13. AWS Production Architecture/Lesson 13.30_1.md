# AWS Masterclass — Lesson 30 Part 1

# AWS IAM Fundamentals, Identities, Roles, Policies & Authorization Logic

We have now entered one of the most important lessons in the entire AWS course.

Almost every AWS service eventually reaches this question:

```text
WHO
is trying to do

WHAT

to WHICH resource

under WHAT conditions

and

WHO/WHAT is allowed to stop them?
```

That is IAM.

AWS Identity and Access Management controls **authentication**—who or what the caller is—and **authorization**—what that authenticated principal is permitted to do. ([AWS Documentation][1])

---

# 1. IAM Is the Authorization Layer of AWS

Consider:

```bash
aws s3 ls
```

Looks simple.

Behind the scenes:

```text
AWS CLI
   │
   ▼
Credentials
   │
   ▼
AWS authentication
   │
   ▼
Who are you?
   │
   ▼
IAM Principal
   │
   ▼
What action?
s3:ListAllMyBuckets
   │
   ▼
Applicable policies
   │
   ▼
ALLOW or DENY?
```

The request succeeds only if AWS's authorization logic permits it.

---

# 2. Authentication vs Authorization

These two words must never become mixed.

## Authentication

```text
Who are you?
```

Examples:

```text
IAM Identity Center login

IAM user credentials

IAM role credentials

federated identity

EC2 role

GitHub OIDC identity
```

## Authorization

```text
What are you allowed to do?
```

Examples:

```text
Can you:

ec2:RunInstances?

s3:GetObject?

kms:Decrypt?

iam:PassRole?

ecr:CreateRepository?
```

Mental model:

```text
Authentication
      │
      ▼
   IDENTITY
      │
      ▼
Authorization
      │
      ▼
 PERMISSIONS
```

IAM provides both identity and permissions infrastructure. ([AWS Documentation][1])

---

# 3. The AWS Request Model

Every AWS API request can be thought of as:

```text
REQUEST
  │
  ├── Principal
  │
  ├── Action
  │
  ├── Resource
  │
  └── Context
```

For example:

```text
Principal
=
arn:aws:iam::111122223333:role/DevOpsRole


Action
=
ec2:RunInstances


Resource
=
EC2-related resources


Context
=
region
source IP
MFA
principal tags
resource tags
VPC endpoint
time
organization
etc.
```

IAM policies describe what combinations of these are allowed or denied. AWS services publish the actions, resource types, and condition keys they support in the Service Authorization Reference. ([AWS Documentation][2])

---

# 4. The Most Important IAM Diagram

Memorize this:

```text
                        AWS API REQUEST
                              │
                              ▼
                        AUTHENTICATE
                              │
                              ▼
                           PRINCIPAL
                              │
                              ▼
                    COLLECT APPLICABLE
                         POLICIES
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
        Identity Policy  Resource Policy      SCP
             │                │                │
             ├──── Permissions Boundary ───────┤
             │
             ├──────── Session Policy ─────────┤
             │
             ▼
        other applicable policy layers
                              │
                              ▼
                     EXPLICIT DENY?
                         │         │
                        YES       NO
                         │         │
                         ▼         ▼
                       DENY    Is there an
                              applicable ALLOW?
                                  │       │
                                 YES      NO
                                  │       │
                                  ▼       ▼
                                ALLOW   IMPLICIT
                                         DENY
```

AWS starts from an implicit-deny position. An applicable explicit `Deny` overrides applicable `Allow` permissions. ([AWS Documentation][3])

This is the foundation of virtually every IAM troubleshooting problem.

---

# 5. IAM Has Three Core Identity Concepts

Traditional IAM contains:

```text
IAM User

IAM User Group

IAM Role
```

alongside the AWS account root user. ([AWS Documentation][4])

But their purposes are very different.

---

# 6. AWS Account Root User

When an AWS account is created, the original account identity is:

# Root user

It has extraordinary control over the account.

AWS strongly recommends **not using root for everyday administrative work** and protecting the root identity carefully. ([AWS Documentation][5])

Think:

```text
ROOT
  │
  ├── account ownership-level operations
  │
  └── break-glass / root-only operations
```

not:

```text
ROOT
  │
  ├── terraform apply
  ├── aws s3 ls
  ├── create EC2 every day
  └── Jenkins deployments
```

---

# 7. Root User Security

For a standalone important AWS account:

```text
Root credentials
       │
       ▼
Strongly protected
       │
       ├── MFA
       ├── no routine use
       ├── no unnecessary access keys
       └── secure recovery information
```

AWS recommends MFA for root and privileged identities, and currently recommends phishing-resistant methods such as passkeys/security keys where possible. ([AWS Documentation][6])

AWS Organizations also now provides centralized root-access management options for member accounts, including configurations where member-account root credentials are removed. ([AWS Documentation][7])

We'll go much deeper into Organizations later in Lesson 30.

---

# 8. Human Access — Modern AWS Model

Historically many tutorials taught:

```text
Employee
   │
   ▼
IAM User
   │
password
access key
```

That still exists.

But AWS's current security guidance recommends using **federation/IAM roles and temporary credentials**, and IAM Identity Center is the recommended AWS solution for centralized workforce access to AWS accounts and applications. ([AWS Documentation][6])

Modern enterprise architecture:

```text
                   EMPLOYEE
                      │
                      ▼
          Corporate Identity Provider
                      │
        ┌─────────────┴─────────────┐
        │                           │
   Microsoft Entra                Okta
   Active Directory              etc.
        │                           │
        └─────────────┬─────────────┘
                      ▼
              IAM Identity Center
                      │
                      ▼
                 Permission Set
                      │
                      ▼
                  IAM Role
                      │
                      ▼
          Temporary AWS Credentials
```

Much better than creating one permanent IAM user in every AWS account for every employee.

---

# 9. Workforce vs Workload Identities

This distinction is extremely useful.

## Workforce

Humans:

```text
Developer

DevOps engineer

Security engineer

DBA

Finance

Auditor
```

Modern direction:

```text
Identity Provider
       │
       ▼
IAM Identity Center
       │
       ▼
temporary role
```

AWS Identity Center can connect to an existing external identity provider/directory or use its own identity store. ([AWS Documentation][8])

---

# 10. Workload Identity

Machines:

```text
EC2

Lambda

ECS Task

EKS workload

CodeBuild

GitHub Actions

Jenkins

application
```

should normally receive:

```text
temporary role credentials
```

rather than:

```text
hardcoded IAM user access key
```

AWS recommends IAM roles for workloads precisely so long-lived credentials don't need to be distributed into compute environments. ([AWS Documentation][6])

---

# 11. IAM User

An IAM user represents an identity created directly inside one AWS account.

It can have:

```text
console password

access keys

policies

MFA
```

depending on configuration.

Example:

```text
AWS Account
    │
    ▼
IAM User
vivek
```

IAM users remain supported, but AWS's current best practice favors federated/temporary role-based access for most workforce use cases. ([AWS Documentation][9])

---

# 12. Long-Lived Access Keys

IAM-user API credentials traditionally look like:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

The problem:

```text
created once
     │
     ▼
copied into laptop
     │
     ▼
copied into Jenkins
     │
     ▼
copied into .env
     │
     ▼
committed to Git
     │
     ▼
credential leak
```

Role-based temporary credentials reduce this long-lived credential problem because temporary credentials expire. ([AWS Documentation][10])

---

# 13. Never Put IAM Keys in Application Source Code

Bad:

```javascript
const AWS_ACCESS_KEY_ID = "AKIA...";
const AWS_SECRET_ACCESS_KEY = "...";
```

Also bad:

```dockerfile
ENV AWS_ACCESS_KEY_ID=...
ENV AWS_SECRET_ACCESS_KEY=...
```

Also dangerous:

```text
GitHub repository

Jenkinsfile

AMI

EC2 user-data

Terraform source
```

Better architecture:

```text
Application
    │
    ▼
IAM Role
    │
    ▼
temporary credentials
    │
    ▼
AWS API
```

AWS explicitly recommends roles for EC2 applications instead of distributing long-term credentials. ([AWS Documentation][11])

---

# 14. IAM User Groups

An IAM group is a collection of IAM users.

Example:

```text
IAM Group:
Developers
     │
     ├── Alice
     ├── Bob
     └── Vivek
```

Attach:

```text
ReadOnlyDevelopmentPolicy
```

to the group.

Then users in the group inherit the group's permissions. ([AWS Documentation][12])

---

# 15. Group ≠ Role

Huge distinction.

```text
GROUP
=
permission-management container
for IAM users
```

while:

```text
ROLE
=
assumable identity
with permissions
```

A group cannot be used as an authenticated `Principal` in a resource-based policy because an IAM group is not itself an authenticated principal. ([AWS Documentation][13])

So this idea is wrong:

```json
"Principal": {
  "AWS": "arn:aws:iam::111122223333:group/Developers"
}
```

Groups aren't principals.

---

# 16. IAM Role

This is the most important identity construct.

An IAM role is an identity that can be **assumed** by a trusted principal.

Examples:

```text
EC2 assumes EC2Role

Lambda assumes LambdaRole

Employee assumes AdminRole

Account A principal assumes Account B role

GitHub Actions assumes DeployRole
```

Roles are fundamental to temporary credentials, service identities, federation, and cross-account access. AWS specifically identifies roles as the primary mechanism for delegated cross-account access. ([AWS Documentation][14])

---

# 17. A Role Has Two Different Questions

Every role forces you to answer:

## Question 1

```text
WHO MAY ASSUME THIS ROLE?
```

Defined by:

# Trust policy

## Question 2

```text
WHAT MAY THE ROLE DO
AFTER IT IS ASSUMED?
```

Defined by:

# Permission policy

This distinction is absolutely essential.

---

# 18. Role Mental Model

```text
                    IAM ROLE
                       │
          ┌────────────┴────────────┐
          │                         │
          ▼                         ▼
     TRUST POLICY            PERMISSION POLICY
          │                         │
          ▼                         ▼
   WHO can become it?        WHAT can it do?
```

AWS documentation describes roles as having a trust relationship determining trusted principals and permissions that determine what the resulting role identity can do. ([AWS Documentation][15])

---

# 19. Example — EC2 Role

Suppose EC2 must download objects from:

```text
s3://prod-app-config
```

Architecture:

```text
EC2
 │
 │ assume role automatically
 ▼
AppEC2Role
 │
 │ permission
 ▼
s3:GetObject
 │
 ▼
prod-app-config
```

Two policies are involved conceptually.

---

# 20. EC2 Role Trust Policy

Who may assume it?

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Meaning:

```text
EC2 service
     │
     ▼
may assume
     │
     ▼
AppEC2Role
```

Role trust policies are resource-based policies, and `Principal` specifies who can assume the role. ([AWS Documentation][13])

---

# 21. EC2 Role Permission Policy

Now:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::prod-app-config/*"
    }
  ]
}
```

This answers:

```text
Once EC2 has become AppEC2Role,
what may AppEC2Role do?
```

Answer:

```text
Get S3 objects
from prod-app-config
```

---

# 22. Trust Policy Does NOT Grant S3 Permission

If trust policy says:

```text
EC2 may assume this role
```

that doesn't mean:

```text
EC2 may do anything in AWS.
```

The trust policy only answers:

```text
WHO MAY ASSUME THE ROLE?
```

The role's permissions policy answers:

```text
WHAT CAN THE ROLE DO?
```

This distinction explains a huge number of `AccessDenied` incidents.

---

# 23. Permission Policy Does NOT Make a Role Assumable

Suppose role has:

```json
"Action": "s3:*",
"Resource": "*"
```

but the trust policy does not trust your principal.

You still cannot assume the role.

Think:

```text
Permission Policy
=
permissions inside room

Trust Policy
=
who can enter room
```

You need both.

---

# 24. STS — AWS Security Token Service

How does role assumption create credentials?

Through:

# AWS STS

One of the most important calls is:

```text
sts:AssumeRole
```

The operation returns temporary credentials consisting of:

```text
AccessKeyId

SecretAccessKey

SessionToken
```

for the assumed-role session. ([AWS Documentation][16])

Architecture:

```text
Principal
   │
   ▼
sts:AssumeRole
   │
   ▼
IAM Role
   │
   ▼
STS Temporary Credentials
   │
   ├── Access Key
   ├── Secret Key
   └── Session Token
   │
   ▼
AWS API
```

---

# 25. Temporary Credentials

Unlike permanent IAM-user access keys:

```text
temporary credentials
       │
       ▼
expire
```

AWS uses temporary security credentials as the basis for roles and federation. ([AWS Documentation][10])

That means:

```text
stolen permanent credential
=
potentially useful until disabled/rotated
```

whereas:

```text
stolen temporary session
=
limited lifetime
```

assuming no other compromise.

This does not eliminate security requirements, but it greatly improves credential lifecycle.

---

# 26. AssumeRole Example

Suppose:

```text
Account:
111122223333

Role:
DevOpsDeployRole
```

CLI:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::111122223333:role/DevOpsDeployRole \
  --role-session-name vivek-deploy
```

Result contains temporary credentials.

You normally don't manually copy these in mature workflows; AWS CLI profiles, Identity Center, SDK credential providers, compute roles, and federation automate this process. AWS CLI role profiles use `sts:AssumeRole` in the background. ([AWS Documentation][17])

---

# 27. The Best IAM Debugging Command

Before investigating almost any permission problem, run:

```bash
aws sts get-caller-identity
```

This answers:

```text
WHO AM I ACTUALLY AUTHENTICATED AS?
```

Example conceptually:

```json
{
  "Account": "111122223333",
  "Arn": "arn:aws:sts::111122223333:assumed-role/DevOpsRole/vivek",
  "UserId": "..."
}
```

This prevents the classic debugging mistake:

> “I attached the policy to my user.”

when your CLI is actually using:

```text
some-other-role
```

---

# 28. Credential Chain Problems

You think:

```text
AWS CLI
=
vivek-admin
```

but perhaps:

```text
AWS_PROFILE=dev
```

or EC2 instance credentials or another environment variable is active.

Always establish:

```text
CURRENT PRINCIPAL
```

before changing policies.

Mental troubleshooting order:

```text
aws sts get-caller-identity
          │
          ▼
Which account?
          │
          ▼
Which role/user?
          │
          ▼
THEN inspect policies
```

---

# 29. EC2 Instance Profile

An EC2 instance does not attach an IAM role to itself in exactly the same underlying IAM API sense as the console wording suggests.

EC2 uses an:

# Instance Profile

Conceptually:

```text
EC2
 │
 ▼
Instance Profile
 │
 ▼
IAM Role
 │
 ▼
Temporary Credentials
```

An instance profile can contain one role; applications on EC2 can then obtain role credentials automatically. ([AWS Documentation][18])

---

# 30. How the EC2 Application Gets Credentials

Architecture:

```text
Application
running on EC2
      │
      ▼
AWS SDK credential provider chain
      │
      ▼
EC2 Instance Metadata Service
      │
      ▼
Instance Profile
      │
      ▼
IAM Role
      │
      ▼
Temporary credentials
```

AWS SDKs and AWS CLI running on EC2 can automatically retrieve the temporary role credentials from EC2 instance metadata rather than requiring you to manually fetch or embed them. ([AWS Documentation][11])

---

# 31. This Is Why You Should Not Put Keys on EC2

Bad:

```text
EC2
 │
 ▼
~/.aws/credentials

AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

Better:

```text
EC2
 │
 ▼
Instance Profile
 │
 ▼
IAM Role
 │
 ▼
temporary credentials
```

AWS explicitly recommends this approach. ([AWS Documentation][19])

---

# 32. IAM Policy Anatomy

Consider:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadApplicationFiles",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::prod-app/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-south-1"
        }
      }
    }
  ]
}
```

Core elements:

```text
Version

Statement

Sid

Effect

Action

Resource

Condition
```

AWS defines these JSON policy elements formally; `Condition` is optional and controls when a statement applies. ([AWS Documentation][20])

---

# 33. `Version`

You'll commonly see:

```json
"Version": "2012-10-17"
```

Do not interpret this as:

```text
policy creation date
```

It identifies the IAM policy language version.

It's normal to see:

```text
2012-10-17
```

in policies created in 2026.

---

# 34. `Statement`

Policies contain one or more statements.

Example:

```json
"Statement": [
  {},
  {},
  {}
]
```

Each statement can represent a separate authorization rule.

Think:

```text
Policy
 │
 ├── Rule 1
 ├── Rule 2
 └── Rule 3
```

---

# 35. `Sid`

`Sid` means:

```text
Statement ID
```

Example:

```json
"Sid": "AllowReadFromArtifacts"
```

It helps humans identify policy statements.

Think:

```text
LABEL
```

not:

```text
permission by itself
```

---

# 36. `Effect`

Must be:

```text
Allow
```

or:

```text
Deny
```

AWS defines `Effect` as determining whether a matching statement explicitly allows or denies the requested operation. ([AWS Documentation][21])

Example:

```json
"Effect": "Allow"
```

---

# 37. `Action`

`Action` answers:

```text
WHAT AWS API OPERATION?
```

Examples:

```text
ec2:DescribeInstances

ec2:RunInstances

s3:GetObject

s3:PutObject

kms:Decrypt

ecr:CreateRepository

iam:PassRole
```

AWS services define their available IAM actions in the Service Authorization Reference. ([AWS Documentation][2])

---

# 38. Wildcard Actions

Dangerous broad permission:

```json
"Action": "*"
```

means conceptually:

```text
all applicable AWS actions
```

Service wildcard:

```json
"Action": "s3:*"
```

means:

```text
all S3 IAM actions
```

Useful for certain highly privileged administration roles.

Dangerous for normal workloads.

Least privilege normally means reducing this to the APIs the workload actually needs.

---

# 39. `Resource`

`Resource` answers:

```text
ON WHICH RESOURCE?
```

AWS requires statements to specify either `Resource` or `NotResource`; supported resource-level permissions depend on the action/service. ([AWS Documentation][22])

Example:

```json
"Resource": "arn:aws:s3:::prod-app/*"
```

---

# 40. ARN

ARN means:

# Amazon Resource Name

General pattern:

```text
arn:partition:service:region:account-id:resource
```

Example EC2:

```text
arn:aws:ec2:ap-south-1:111122223333:instance/i-123456789
```

Example role:

```text
arn:aws:iam::111122223333:role/ProductionDeployRole
```

Example S3 object:

```text
arn:aws:s3:::my-bucket/path/file.txt
```

Notice S3 ARN structure differs because services define resources differently.

---

# 41. `Resource: "*"`

Sometimes:

```json
"Resource": "*"
```

is required because an AWS API doesn't support resource-level restrictions.

For other APIs it may simply be overly broad.

Therefore don't blindly conclude:

```text
Resource "*"
=
always insecure
```

or:

```text
Resource "*"
=
always okay
```

Check the Service Authorization Reference to determine which resource types an action supports. ([AWS Documentation][2])

---

# 42. `Condition`

`Condition` answers:

```text
UNDER WHAT CIRCUMSTANCES
does this statement apply?
```

AWS compares policy condition operators and context keys against values in the request context. ([AWS Documentation][23])

Example:

```json
"Condition": {
  "StringEquals": {
    "aws:RequestedRegion": "ap-south-1"
  }
}
```

Meaning conceptually:

```text
permission applies
only if

requested Region
=
ap-south-1
```

---

# 43. Conditions Make IAM Extremely Powerful

You can create permission models based on contexts such as:

```text
MFA

source IP

VPC endpoint

AWS Organization

principal tags

resource tags

requested Region

source account

source ARN

TLS/security transport
```

when the relevant action/service/context supports those condition keys.

This is where IAM evolves from:

```text
ALLOW API
```

into:

```text
ALLOW API
ONLY UNDER CONTROLLED CONDITIONS
```

---

# 44. Example — Deny Outside Approved Region

Conceptual guardrail:

```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": [
        "ap-south-1",
        "us-east-1"
      ]
    }
  }
}
```

But be careful: global services and actions whose request context doesn't behave like regional services need deliberate exclusions/design. Never deploy a broad regional-deny policy without validating service behavior.

The important concept is:

```text
Condition
=
contextual control
```

---

# 45. `Principal`

Here's another major confusion.

`Principal` answers:

```text
WHO?
```

You normally see it in:

```text
resource-based policies
```

such as:

```text
S3 bucket policy

KMS key policy

IAM role trust policy
```

AWS requires `Principal` in resource-based policies where a principal must be specified; role trust policies use it to identify who may assume the role. ([AWS Documentation][13])

---

# 46. Why Identity Policies Usually Don't Need `Principal`

If a policy is attached directly to:

```text
DevOpsRole
```

the identity already answers:

```text
WHO?
```

So identity policy:

```json
{
  "Effect": "Allow",
  "Action": "ec2:DescribeInstances",
  "Resource": "*"
}
```

doesn't need:

```text
Principal
```

because:

```text
policy is attached to DevOpsRole
```

---

# 47. Resource-Based Policy

Example S3 bucket:

```text
prod-artifacts
```

Bucket policy:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::111122223333:role/JenkinsRole"
  },
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::prod-artifacts/*"
}
```

This reads as:

```text
RESOURCE:
prod-artifacts objects

says:

PRINCIPAL:
JenkinsRole

may perform:

ACTION:
GetObject
```

Resource-based policies grant permissions to specified principals and may grant access to principals in the same or other accounts, depending on the service and authorization context. ([AWS Documentation][24])

---

# 48. Identity Policy vs Resource Policy

## Identity-based

Attached to:

```text
User
Group
Role
```

Answers:

```text
What may this identity do?
```

## Resource-based

Attached to:

```text
S3 bucket
KMS key
SQS queue
SNS topic
Lambda function
IAM role trust relationship
etc.
```

Answers:

```text
Who may interact with this resource?
```

AWS explicitly distinguishes these two policy types. ([AWS Documentation][25])

---

# 49. The Building Security Analogy

Think of:

```text
Identity policy
```

as:

```text
Your employee badge says:
"You may enter Building A."
```

Resource policy:

```text
Building A's door says:
"Employees from Team X may enter."
```

Cross-account or sensitive-resource access may require authorization rules on both sides depending on the policy model.

---

# 50. Explicit Deny — The IAM King

Suppose:

Policy A:

```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}
```

Policy B:

```json
{
  "Effect": "Deny",
  "Action": "s3:DeleteObject",
  "Resource": "*"
}
```

Can you delete?

```text
NO
```

Because:

```text
Explicit Deny
>
Allow
```

AWS's evaluation model makes an applicable explicit deny override applicable allows. ([AWS Documentation][26])

---

# 51. Implicit Deny

Suppose you have:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "*"
}
```

Nothing mentions:

```text
s3:DeleteObject
```

Are you allowed to delete?

```text
NO
```

Not because a policy explicitly said:

```text
Deny DeleteObject
```

but because AWS starts from:

```text
DENIED BY DEFAULT
```

and no applicable allow was found. ([AWS Documentation][3])

This is:

# Implicit Deny

---

# 52. Implicit vs Explicit Deny

```text
IMPLICIT DENY

No Allow found
```

versus:

```text
EXPLICIT DENY

A Deny statement
actively matches the request
```

This distinction matters because:

```text
adding an Allow
```

may solve an implicit deny.

But:

```text
adding another Allow
```

does **not** override an explicit deny.

---

# 53. The IAM Formula

For now memorize:

```text
DEFAULT
=
DENY
```

Then:

```text
Applicable Allow
=
possibly ALLOW
```

But:

```text
Applicable Explicit Deny
=
DENY ALWAYS
```

So:

```text
ALLOW + DENY
=
DENY
```

```text
ALLOW + no explicit deny
=
potentially ALLOW
```

```text
no ALLOW
=
DENY
```

Later we'll layer:

```text
SCP
permissions boundaries
session policies
resource control policies
VPC endpoint policies
KMS policies
```

on top of this.

---

# 54. Example — Your EC2 Error

You've encountered errors like:

```text
not authorized to perform:
ec2:DescribeSecurityGroups
```

Suppose your role has:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:RunInstances"
  ],
  "Resource": "*"
}
```

Terraform calls:

```text
ec2:DescribeSecurityGroups
```

No applicable allow.

Result:

```text
IMPLICIT DENY
```

Fix:

```text
add required Describe permission
```

assuming no higher-level explicit denial exists.

---

# 55. Why Terraform Needs More IAM Than the Final Resource Action

You might think:

> “Terraform only needs `ec2:RunInstances` because I'm creating an EC2 instance.”

But provider workflow may need to:

```text
DescribeImages

DescribeSubnets

DescribeSecurityGroups

DescribeInstanceTypes

CreateTags

RunInstances

DescribeInstances
```

depending on configuration.

Infrastructure automation therefore needs permissions for:

```text
discovery
+
creation
+
tagging
+
verification
```

not merely the obvious create API.

This is why reading the exact AccessDenied action is so important.

---

# 56. IAM Troubleshooting Rule #1

Never start with:

```text
Attach AdministratorAccess
```

to see whether things work.

Instead:

```text
1. Identify principal

2. Identify denied action

3. Identify resource

4. Identify applicable policy layers

5. Determine implicit vs explicit deny

6. Add/fix least privilege

7. Retest
```

This teaches you IAM rather than bypassing it.

---

# 57. Step 1 — Identify Principal

Run:

```bash
aws sts get-caller-identity
```

Ask:

```text
Account?

User?

Role?

Assumed-role session?
```

You'd be surprised how many IAM incidents end here.

---

# 58. Step 2 — Read the Exact Error

Example:

```text
User:
arn:aws:sts::111122223333:assumed-role/JenkinsRole/build-125

is not authorized to perform:

ecr:CreateRepository

on resource:
arn:aws:ecr:ap-south-1:111122223333:repository/dev-todo-backend
```

Extract:

```text
PRINCIPAL
=
JenkinsRole


ACTION
=
ecr:CreateRepository


RESOURCE
=
repository


REGION
=
ap-south-1


ACCOUNT
=
111122223333
```

Now IAM becomes a structured troubleshooting problem.

---

# 59. Step 3 — Ask Whether There Is an Allow

Inspect:

```text
Role policies

Group policies if IAM user

Resource policy

Permission set

session policy
```

depending on identity type.

Question:

```text
Does any applicable policy
ALLOW the exact action
on the exact resource
under the current context?
```

---

# 60. Step 4 — Search for Denies

Then ask:

```text
SCP deny?

permissions boundary deny/limit?

resource policy deny?

identity policy deny?

session policy limit?

VPC endpoint policy?

KMS key policy?

RCP?
```

We'll master all these in Parts 2–4.

The key is:

```text
A policy saying Allow
does not prove
effective permission.
```

AWS evaluates multiple applicable policy types, and explicit denies override allows. ([AWS Documentation][24])

---

# 61. Same-Account vs Cross-Account

Same-account authorization can often combine identity-based and resource-based permissions according to service rules.

Cross-account gets more demanding.

Conceptually:

```text
Account A
requesting principal

       │
       ▼
     request
       │
       ▼

Account B
resource
```

AWS evaluates authorization from both the requesting/trusted account side and the resource-owning/trusting account side; cross-account access generally needs permission to survive both evaluations. ([AWS Documentation][27])

---

# 62. Cross-Account Role Example

Development account:

```text
111111111111
```

Production:

```text
222222222222
```

Goal:

```text
DevOps engineer
      │
      ▼
Assume ProdDeployRole
      │
      ▼
Production account
```

Architecture:

```text
Account A
DevOps identity
      │
      │ sts:AssumeRole
      ▼
────────────────────────────
Account B

ProdDeployRole
      │
      ▼
temporary production session
```

Roles are the primary AWS IAM mechanism for this delegated cross-account access. ([AWS Documentation][14])

---

# 63. Two Permissions Exist in Cross-Account AssumeRole

On source side:

```text
DevOps principal
```

needs authorization to call:

```text
sts:AssumeRole
```

against the target role.

Target role also needs a trust policy allowing the principal/account to assume it.

Think:

```text
SOURCE:
Am I allowed to ask?
```

```text
TARGET:
Do I trust you?
```

Both matter.

---

# 64. Target Trust Policy

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:role/DevOpsRole"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Meaning:

```text
Production ProdDeployRole
trusts
Development DevOpsRole
```

Trust policies determine who can assume a role. ([AWS Documentation][28])

---

# 65. Target Permission Policy

Once assumed:

```text
ProdDeployRole
```

might receive:

```json
{
  "Effect": "Allow",
  "Action": [
    "ecs:UpdateService",
    "ecs:DescribeServices"
  ],
  "Resource": "*"
}
```

That means:

```text
DevOpsRole
       │
       ▼
assumes
       │
       ▼
ProdDeployRole
       │
       ▼
receives ProdDeployRole permissions
```

The source identity does not magically carry all its original permissions into the target role session.

---

# 66. Cross-Account Is Extremely Powerful

Rather than creating:

```text
Vivek IAM user
```

in:

```text
Dev account

Staging account

Prod account

Security account

Shared Services account
```

you can use centralized workforce identity and assume roles into the required accounts.

Modern enterprise:

```text
Corporate Identity
       │
       ▼
IAM Identity Center
       │
       ├── Dev role
       ├── Staging role
       ├── Prod read-only role
       └── Production admin role
```

IAM Identity Center is specifically designed for assigning workforce access across AWS accounts. ([AWS Documentation][8])

---

# 67. IAM Identity Center Permission Sets

Conceptually:

```text
Permission Set:
DeveloperAccess
```

could represent:

```text
EC2 read

ECS update

CloudWatch read

S3 artifact read
```

Assign:

```text
Developers group
       │
       ▼
Development Account
       │
       ▼
DeveloperAccess
```

Identity Center then provisions the relevant AWS-account access through IAM roles and temporary credentials. ([AWS Documentation][29])

We'll build this properly in a later IAM part.

---

# 68. AWS Identity Center ≠ IAM User Group

Don't confuse:

```text
IAM user group
```

with:

```text
IAM Identity Center group
```

IAM group:

```text
lives inside one AWS account's IAM
and groups IAM users.
```

Identity Center groups:

```text
represent workforce identities
for centralized account/application assignments.
```

Different systems.

---

# 69. `Principal` Examples

A resource policy may trust:

### AWS account

```json
"Principal": {
  "AWS": "arn:aws:iam::111122223333:root"
}
```

### IAM role

```json
"Principal": {
  "AWS": "arn:aws:iam::111122223333:role/AppRole"
}
```

### AWS service

```json
"Principal": {
  "Service": "ec2.amazonaws.com"
}
```

### Federated principal

Used in SAML/OIDC/federation architectures.

AWS documents the valid principal categories for resource policies and role trust relationships. ([AWS Documentation][13])

---

# 70. Service Principal

When you see:

```json
"Service": "lambda.amazonaws.com"
```

this means:

```text
AWS Lambda service
```

is trusted in that role relationship.

Examples:

```text
ec2.amazonaws.com

lambda.amazonaws.com
```

and other AWS service principals.

Different AWS services use different service-principal values and service-role patterns.

---

# 71. Why Lambda Needs an Execution Role

Architecture:

```text
Lambda Function
      │
      ▼
Lambda service assumes
      │
      ▼
Execution Role
      │
      ▼
temporary credentials
      │
      ├── logs:PutLogEvents
      ├── s3:GetObject
      └── dynamodb:GetItem
```

Trust:

```text
Lambda may assume role
```

Permissions:

```text
Role may call required APIs.
```

Same role model as EC2.

---

# 72. AWS Managed vs Customer Managed vs Inline Policies

Identity permissions can be delivered in different forms.

## AWS managed policy

Created/maintained by AWS.

Example conceptually:

```text
ReadOnlyAccess
```

## Customer managed policy

Created and managed by you.

Can be attached to multiple:

```text
users
groups
roles
```

## Inline policy

Embedded directly inside one identity/resource context.

Mental recommendation for reusable organizational permission sets:

```text
customer-managed policy
```

is often easier to centrally version/reuse than repeating many inline policies.

---

# 73. Why Managed Policy Reuse Matters

Imagine:

```text
20 application roles
```

all need:

```text
read-only artifact access
```

Bad operational design:

```text
20 separately copied inline policies
```

Then requirements change.

You have 20 independent copies.

Better:

```text
AppArtifactReadPolicy
       │
       ├── Role A
       ├── Role B
       ├── Role C
       └── ...
```

One reusable policy model.

---

# 74. But One Giant Shared Policy Is Also Bad

Do not create:

```text
CompanyDeveloperPolicy
```

containing:

```text
EC2
S3
RDS
IAM
KMS
EKS
Secrets
Route53
Organizations
Billing
everything
```

and attach it everywhere.

Least privilege encourages decomposition according to:

```text
job function

workload requirement

environment

resource boundary
```

not one mega-policy.

---

# 75. Resource-Level Least Privilege

Bad:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "*"
}
```

Better when possible:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::prod-app-config/*"
}
```

Even better, if workload only needs:

```text
configs/
```

then:

```json
"Resource":
"arn:aws:s3:::prod-app-config/configs/*"
```

IAM least privilege asks:

```text
WHAT
```

and:

```text
WHERE
```

not merely:

```text
Can application access S3?
```

---

# 76. Action-Level Least Privilege

Bad:

```json
"Action": "s3:*"
```

if application only reads.

Better:

```json
"Action": [
  "s3:GetObject"
]
```

If it also needs metadata:

```json
"Action": [
  "s3:GetObject",
  "s3:GetObjectAttributes"
]
```

depending on actual API usage.

Build from observed requirements.

---

# 77. Why `Describe*` Often Uses `"Resource": "*"`

Many AWS describe/list APIs do not support scoping down to a specific resource ARN.

Example style:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeInstances",
    "ec2:DescribeSecurityGroups"
  ],
  "Resource": "*"
}
```

This can be correct because the action's service authorization definition may not support resource-level restrictions. Verify in the AWS Service Authorization Reference. ([AWS Documentation][2])

So security review must understand:

```text
Action capability
```

not blindly reject every wildcard.

---

# 78. Conditions Can Restore Scope

Even if action requires:

```text
Resource: "*"
```

sometimes suitable condition keys can still constrain when/how it's usable.

Think:

```text
Resource-level restriction unavailable
            │
            ▼
Can we constrain:
region?
tags?
organization?
VPC endpoint?
principal?
```

Again, condition-key support is action/service specific. ([AWS Documentation][2])

---

# 79. IAM and KMS Are Special Together

Suppose IAM role says:

```json
{
  "Effect": "Allow",
  "Action": "kms:Decrypt",
  "Resource": "arn:aws:kms:..."
}
```

Does that automatically guarantee decryption?

Not necessarily.

KMS has its own authorization model involving:

```text
key policies

IAM policies

grants
```

We'll cover it deeply.

This is why:

```text
IAM says Allow
```

doesn't always imply:

```text
AWS request will succeed
```

when resource-specific authorization layers exist.

---

# 80. Policy Evaluation — Simplified Same-Account Case

Suppose:

```text
Role policy:
Allow s3:GetObject
```

and:

```text
Bucket policy:
no deny
```

and no boundary/SCP/etc. blocks it.

Result:

```text
ALLOW
```

Now bucket policy says:

```text
Deny s3:GetObject
```

for your principal/context.

Result:

```text
DENY
```

Explicit deny overrides allow. ([AWS Documentation][30])

---

# 81. Why Adding `AdministratorAccess` Sometimes Still Doesn't Fix It

Suppose:

```text
Identity Policy:
AdministratorAccess
```

but:

```text
SCP:
Deny ec2:RunInstances
```

Effective:

```text
DENY
```

Or:

```text
Permissions Boundary
does not permit IAM action
```

Effective permissions may still be limited.

AWS policy evaluation combines multiple policy types, and an explicit deny remains authoritative. ([AWS Documentation][26])

That's why this debugging strategy is poor:

```text
"Attach Admin and see."
```

---

# 82. Encoded Authorization Failure Messages

Some AWS authorization failures, particularly EC2-related ones, can include an encoded authorization message.

You can decode such a message using:

```bash
aws sts decode-authorization-message \
  --encoded-message '<message>'
```

but the caller needs:

```text
sts:DecodeAuthorizationMessage
```

permission. AWS intentionally protects decoded details because they can contain privileged authorization information. ([AWS Documentation][31])

This is an advanced and extremely useful troubleshooting technique.

---

# 83. Example Decode Workflow

Error:

```text
UnauthorizedOperation

Encoded authorization failure message:
ABCDEF....
```

Then:

```bash
aws sts decode-authorization-message \
  --encoded-message 'ABCDEF...'
```

You may receive additional information about:

```text
principal

requested action

resource

matched statements

whether authorization failed
```

according to the encoded context. ([AWS Documentation][31])

This can expose the real denial more quickly than guessing.

---

# 84. `AccessDenied` Troubleshooting Map

Memorize:

```text
                    ACCESS DENIED
                         │
                         ▼
              aws sts get-caller-identity
                         │
                         ▼
                 Correct principal?
                  │             │
                 NO            YES
                  │             │
                  ▼             ▼
            fix credentials   Exact action?
                                │
                                ▼
                           Exact resource?
                                │
                                ▼
                          Applicable Allow?
                           │           │
                          NO          YES
                           │           │
                           ▼           ▼
                     implicit deny   Explicit deny?
                                       │       │
                                      YES      NO
                                       │       │
                                       ▼       ▼
                                  find deny   inspect
                                  layer       conditions/
                                              resource
```

Then consider:

```text
SCP

permissions boundary

session policy

resource policy

KMS

VPC endpoint policy

RCP

trust policy
```

depending on the request.

---

# 85. `AssumeRole` Troubleshooting

Error:

```text
AccessDenied:
not authorized to perform sts:AssumeRole
```

Ask two questions:

```text
1.
Does source principal
have permission to AssumeRole?
```

and:

```text
2.
Does target role
TRUST the principal?
```

If either side fails:

```text
AssumeRole fails.
```

Role trust relationships and source-side permissions are both central to delegated-role access. ([AWS Documentation][32])

---

# 86. `AssumeRole` ≠ `iam:PassRole`

These are different and often confused.

```text
sts:AssumeRole
```

means:

```text
I want to BECOME this role
temporarily.
```

```text
iam:PassRole
```

means:

```text
I want to tell an AWS service
to USE this role.
```

We'll cover `PassRole` deeply later because it is one of the most important privilege-escalation concepts in AWS.

---

# 87. Example of Future `PassRole`

Suppose you launch EC2 and specify:

```text
AdminEC2Role
```

The caller may need:

```text
iam:PassRole
```

because:

```text
you are passing a role
to EC2
```

not personally assuming that role.

This distinction will matter greatly in privilege-escalation defense.

---

# 88. Service Role vs User-Assumed Role

### Service role

```text
EC2/Lambda/ECS
     │
     ▼
assumes role
```

### Human/cross-account role

```text
User/federated identity/role
     │
     ▼
sts:AssumeRole
```

Both are IAM roles.

Different trusted principal.

---

# 89. Temporary Credential Flow — EC2

```text
EC2 application
     │
     ▼
Instance Metadata
     │
     ▼
Role credentials
     │
     ▼
AWS SDK
     │
     ▼
S3
```

Credentials rotate automatically through the AWS-managed mechanism; applications using the standard SDK credential chain don't need to manually rotate static keys. ([AWS Documentation][33])

---

# 90. Temporary Credential Flow — Human

```text
Employee
    │
    ▼
Identity Center
    │
    ▼
authenticate
    │
    ▼
permission assignment
    │
    ▼
AWS role
    │
    ▼
temporary session
    │
    ▼
AWS Console / CLI
```

IAM Identity Center provides account access through permission assignments and temporary credentials. ([AWS Documentation][29])

---

# 91. Temporary Credential Flow — CI/CD

Modern idea:

```text
GitHub Actions
     │
     ▼
OIDC identity
     │
     ▼
AWS STS
     │
     ▼
DeployRole
     │
     ▼
temporary AWS credentials
```

Instead of:

```text
GitHub Secret:
AWS_ACCESS_KEY_ID

GitHub Secret:
AWS_SECRET_ACCESS_KEY
```

We will build this fully in the federation/OIDC part of Lesson 30.

---

# 92. Real Production Identity Architecture

```text
                         AWS ORGANIZATION
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
              HUMANS                     WORKLOADS
                 │                           │
                 ▼                           ▼
        IAM Identity Center             IAM Roles
                 │                           │
          Corporate IdP              ┌──────┼──────┐
                 │                   ▼      ▼      ▼
                 │                  EC2    ECS   Lambda
                 │
        Permission Sets
                 │
                 ▼
          Temporary Roles

                               │
                               ▼
                             IAM
                               │
                         authorization
                               │
             ┌─────────────────┼─────────────────┐
             ▼                 ▼                 ▼
            S3                KMS               RDS
            ECR               EC2               EKS
```

This is the model to aim for—not hundreds of permanent access keys.

---

# 93. Terraform — EC2 Role Baseline

Trust policy:

```hcl
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}
```

Role:

```hcl
resource "aws_iam_role" "app" {
  name = "prod-app-ec2-role"

  assume_role_policy =
    data.aws_iam_policy_document.ec2_assume_role.json
}
```

This is:

```text
TRUST
```

not application permissions.

---

# 94. Terraform Permission Policy

```hcl
data "aws_iam_policy_document" "app_permissions" {
  statement {
    sid    = "ReadApplicationConfig"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::prod-app-config/*"
    ]
  }
}
```

Then:

```hcl
resource "aws_iam_policy" "app" {
  name = "prod-app-policy"

  policy =
    data.aws_iam_policy_document.app_permissions.json
}
```

Attach:

```hcl
resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app.arn
}
```

---

# 95. Terraform Instance Profile

```hcl
resource "aws_iam_instance_profile" "app" {
  name = "prod-app-instance-profile"

  role = aws_iam_role.app.name
}
```

EC2:

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  iam_instance_profile =
    aws_iam_instance_profile.app.name

  # ...
}
```

Mental chain:

```text
EC2
 │
 ▼
Instance Profile
 │
 ▼
Role
 │
 ▼
Policy
```

---

# 96. Application Code Becomes Cleaner

Without role:

```javascript
const client = new S3Client({
  credentials: {
    accessKeyId: "...",
    secretAccessKey: "..."
  }
});
```

With role:

```javascript
const client = new S3Client({});
```

The standard SDK credential provider chain can retrieve compute-role credentials automatically in the EC2 environment. ([AWS Documentation][11])

This is both:

```text
cleaner
```

and:

```text
more secure.
```

---

# 97. Basic Hands-On IAM Inspection Lab

Start by identifying yourself:

```bash
aws sts get-caller-identity
```

Then inspect IAM roles if your permissions allow:

```bash
aws iam list-roles \
  --max-items 20
```

Inspect specific role:

```bash
aws iam get-role \
  --role-name YOUR_ROLE
```

Trust policy is visible under:

```text
AssumeRolePolicyDocument
```

---

# 98. List Attached Managed Policies

```bash
aws iam list-attached-role-policies \
  --role-name YOUR_ROLE
```

Inline:

```bash
aws iam list-role-policies \
  --role-name YOUR_ROLE
```

You want to establish:

```text
WHO TRUSTS/ASSUMES ROLE?
```

and:

```text
WHAT PERMISSIONS DOES ROLE HAVE?
```

separately.

---

# 99. EC2 Inspection

Find instance profile:

```bash
aws ec2 describe-instances \
  --region ap-south-1 \
  --query \
  'Reservations[].Instances[].{
      InstanceId:InstanceId,
      Profile:IamInstanceProfile.Arn
  }'
```

If:

```text
Profile = null
```

your instance has no attached EC2 instance profile.

An application running there will not magically inherit an EC2 IAM role.

---

# 100. Safe IAM Practice Lab

Create a role conceptually:

```text
Lesson30ReadOnlyS3Role
```

Trust:

```text
your current test principal
```

Permissions:

```text
s3:ListAllMyBuckets
```

Then assume it:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT-ID>:role/Lesson30ReadOnlyS3Role \
  --role-session-name lesson30
```

Observe the returned temporary credentials.

Then compare:

```text
original identity
```

with:

```text
assumed-role identity.
```

The purpose isn't to create admin access.

It's to see:

```text
IDENTITY TRANSFORMATION
```

in action.

---

# 101. Common IAM Error — Wrong Principal

You changed:

```text
JenkinsRole policy
```

but error principal says:

```text
arn:aws:sts::...:assumed-role/TerraformRole/...
```

You're editing the wrong identity.

Correct action:

```text
read the ARN
```

not:

```text
guess which role Jenkins uses.
```

---

# 102. Common IAM Error — Wrong Resource ARN

Policy:

```json
"Resource":
"arn:aws:s3:::mybucket"
```

Application calls:

```text
s3:GetObject
```

on:

```text
mybucket/file.txt
```

Object ARN is:

```text
arn:aws:s3:::mybucket/file.txt
```

not merely:

```text
arn:aws:s3:::mybucket
```

This bucket-vs-object resource distinction is one of the most common S3 IAM mistakes.

---

# 103. Common IAM Error — Wrong Action

Policy:

```text
ecr:GetAuthorizationToken
```

but workflow creates repository.

Needed:

```text
ecr:CreateRepository
```

Different API.

IAM does not reason:

> “This looks approximately ECR-related.”

Exact permissions matter.

---

# 104. Common IAM Error — Allow Exists But Condition Doesn't Match

Policy:

```json
{
  "Effect": "Allow",
  "Action": "ec2:RunInstances",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": "ap-south-1"
    }
  }
}
```

Request:

```text
us-east-1
```

Statement doesn't grant the requested operation.

Result may effectively be:

```text
implicit deny
```

assuming no other applicable allow.

Conditions participate directly in policy matching. ([AWS Documentation][23])

---

# 105. Common IAM Error — Explicit Deny Somewhere Else

Role:

```text
AdministratorAccess
```

yet:

```text
AccessDenied.
```

Potential:

```text
Organizations SCP
```

or:

```text
permissions boundary
```

or:

```text
resource policy
```

or another explicit-deny layer.

Remember:

```text
ADMIN POLICY
≠
guaranteed effective administrator access
```

in a governed AWS environment.

---

# 106. Common IAM Error — Trust Policy Missing

Role permissions:

```text
perfect
```

Caller permission:

```text
sts:AssumeRole allowed
```

Target trust:

```text
doesn't trust caller
```

Result:

```text
AssumeRole denied.
```

Check:

```bash
aws iam get-role \
  --role-name TargetRole
```

and inspect:

```text
AssumeRolePolicyDocument
```

---

# 107. Common IAM Error — Group Used as Principal

You try:

```json
"Principal": {
  "AWS": "arn:aws:iam::123456789012:group/Developers"
}
```

Not valid as the authenticated principal model because groups are permission containers, not principals. ([AWS Documentation][13])

Instead trust:

```text
role

user

account

service

federated principal
```

as appropriate.

---

# 108. Production Identity Principles

A strong AWS environment normally aims toward:

```text
HUMANS
  │
  ▼
Federation / Identity Center
  │
  ▼
temporary roles


WORKLOADS
  │
  ▼
service/workload roles
  │
  ▼
temporary credentials


CI/CD
  │
  ▼
federated/OIDC or controlled role
  │
  ▼
temporary credentials
```

AWS's current IAM best practices explicitly recommend temporary role credentials for both human and workload access whenever possible. ([AWS Documentation][6])

---

# 109. Never-Forget IAM Identity Map

```text
                        AWS IAM
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
          USER           GROUP           ROLE
            │              │              │
      direct identity   users only     assumable
            │              │            identity
            │              │              │
            ▼              ▼              ▼
        long-lived      permission      temporary
      credentials may   organization    credentials
          exist


MODERN HUMAN ACCESS
        │
        ▼
IAM Identity Center
        │
        ▼
temporary role


MODERN WORKLOAD ACCESS
        │
        ▼
IAM Role
```

---

# 110. Never-Forget Policy Map

```text
IAM POLICY STATEMENT
        │
        ├── Effect
        │     Allow / Deny
        │
        ├── Action
        │     WHAT?
        │
        ├── Resource
        │     WHERE?
        │
        ├── Condition
        │     WHEN / UNDER WHAT CONTEXT?
        │
        └── Principal
              WHO?
              resource policies
```

Memory sentence:

```text
WHO
can do
WHAT
to
WHICH RESOURCE
under
WHICH CONDITIONS?
```

---

# 111. Never-Forget Role Map

```text
                          ROLE
                            │
               ┌────────────┴────────────┐
               ▼                         ▼
            TRUST                     PERMISSIONS
               │                         │
               ▼                         ▼
          WHO CAN ASSUME?          WHAT CAN IT DO?
               │                         │
               └───────────┬─────────────┘
                           ▼
                      STS SESSION
                           │
                           ▼
                 temporary credentials
```

---

# 112. Never-Forget Authorization Formula

```text
START
=
DENY
```

```text
NO APPLICABLE ALLOW
=
IMPLICIT DENY
```

```text
APPLICABLE ALLOW
+
NO BLOCKING POLICY
=
ALLOW
```

```text
APPLICABLE ALLOW
+
EXPLICIT DENY
=
DENY
```

And:

```text
100 ALLOW statements

+

1 applicable explicit DENY

=

DENY
```

That rule will stay true throughout the rest of IAM. ([AWS Documentation][34])

---

# 113. The 25 IAM Rules to Burn Into Memory

```text
1. IAM controls authentication and authorization.

2. Always identify the caller before debugging permission.

3. Root is not for everyday work.

4. Protect root with strong MFA/security controls.

5. Modern workforce access should favor federation
   and IAM Identity Center.

6. Workloads should generally use IAM roles.

7. Avoid long-lived AWS keys in applications.

8. IAM groups contain users; groups are not principals.

9. IAM roles are assumable identities.

10. Roles provide temporary credentials.

11. STS powers role assumption.

12. A role has a trust policy and permission policies.

13. Trust policy = WHO can assume.

14. Permission policy = WHAT the role can do.

15. Instance profile connects EC2 to an IAM role.

16. AWS SDKs can automatically obtain EC2 role credentials.

17. Effect = Allow or Deny.

18. Action = API operation.

19. Resource = target ARN/resource.

20. Condition = contextual restriction.

21. Principal appears in resource-based policy contexts.

22. AWS denies requests by default.

23. No Allow = implicit deny.

24. Explicit Deny overrides Allow.

25. Administrator permissions do not necessarily override
    SCPs, boundaries, resource denies, or other guardrails.
```

And the most important operational rule:

```text
WHEN YOU SEE:

AccessDenied

DO NOT RANDOMLY EDIT IAM.
```

Use:

```text
WHO?
↓
aws sts get-caller-identity

WHAT?
↓
exact denied Action

WHERE?
↓
exact Resource

ALLOW?
↓
identity/resource policy

BLOCK?
↓
explicit deny / guardrail

CONDITION?
↓
request context
```

That is how experienced AWS engineers troubleshoot IAM.

---

# ✅ Lesson 30 Part 1 Complete

You now understand:

```text
✓ IAM mental model
✓ authentication vs authorization
✓ AWS request context
✓ root user
✓ MFA principles
✓ workforce vs workload identity
✓ IAM Identity Center
✓ IAM users
✓ IAM groups
✓ IAM roles
✓ temporary credentials
✓ STS
✓ AssumeRole
✓ trust policies
✓ permission policies
✓ service principals
✓ instance profiles
✓ EC2 role credential delivery
✓ JSON policy anatomy
✓ Version
✓ Statement
✓ Sid
✓ Effect
✓ Action
✓ Resource
✓ Condition
✓ Principal
✓ ARNs
✓ identity-based policies
✓ resource-based policies
✓ explicit deny
✓ implicit deny
✓ same-account concepts
✓ cross-account role concepts
✓ least privilege
✓ Terraform IAM role design
✓ AccessDenied troubleshooting
✓ DecodeAuthorizationMessage
```

---

# Next — Lesson 30 Part 2

# **IAM Policy Evaluation Deep Dive — SCPs, Permissions Boundaries, Session Policies, Resource Policies & Effective Permissions**

This next part is where IAM becomes truly enterprise-grade.

We'll dissect a request like:

```text
Developer says:

"I HAVE AdministratorAccess.

WHY AM I STILL GETTING AccessDenied?"
```

and follow it through:

```text
                     AWS REQUEST
                          │
                          ▼
                 Identity Policy
                          │
                     Allow EC2:*
                          │
                          ▼
               Permissions Boundary
                          │
                   allows EC2 only
                          │
                          ▼
                        SCP
                          │
                  Deny us-east-2
                          │
                          ▼
                   Session Policy
                          │
                          ▼
                  Resource Policy
                          │
                          ▼
                 VPC Endpoint Policy
                          │
                          ▼
                   KMS Key Policy
                          │
                          ▼
                   FINAL DECISION
```

We'll cover **AWS Organizations SCPs, the difference between “grants permissions” and “maximum permissions,” permissions boundaries, session policies, resource-based policy edge cases, AWS Organizations Resource Control Policies (RCPs), cross-account evaluation, `NotAction`, `NotResource`, why `Deny + NotAction` is powerful and dangerous, policy intersection vs union, service-linked roles, role chaining, session duration, policy simulator thinking, and real AccessDenied labs based on EC2, S3, ECR, KMS, and Terraform**.

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html?utm_source=chatgpt.com "What is IAM? - AWS Identity and Access Management"
[2]: https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html?utm_source=chatgpt.com "Actions, resources, and condition keys for AWS services"
[3]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic_policy-eval-denyallow.html?utm_source=chatgpt.com "How AWS enforcement code logic evaluates requests to ..."
[4]: https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction_identity-management.html?utm_source=chatgpt.com "Compare IAM identities and credentials"
[5]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html?utm_source=chatgpt.com "AWS account root user - AWS Identity and Access ..."
[6]: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html?utm_source=chatgpt.com "Security best practices in IAM - AWS Identity and Access ..."
[7]: https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html?utm_source=chatgpt.com "Root user best practices for your AWS account"
[8]: https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html?utm_source=chatgpt.com "What is IAM Identity Center?"
[9]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users.html?utm_source=chatgpt.com "IAM users - AWS Identity and Access Management"
[10]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp.html?utm_source=chatgpt.com "Temporary security credentials in IAM"
[11]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_use-resources.html?utm_source=chatgpt.com "Use temporary credentials with AWS resources"
[12]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_groups.html?utm_source=chatgpt.com "IAM user groups - AWS Identity and Access Management"
[13]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_principal.html?utm_source=chatgpt.com "AWS JSON policy elements: Principal - AWS Documentation"
[14]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html?utm_source=chatgpt.com "IAM roles - AWS Identity and Access Management"
[15]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_common-scenarios_third-party.html?utm_source=chatgpt.com "Access to AWS accounts owned by third parties"
[16]: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html?utm_source=chatgpt.com "AssumeRole - AWS Security Token Service"
[17]: https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-role.html?utm_source=chatgpt.com "Using an IAM role in the AWS CLI"
[18]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html?utm_source=chatgpt.com "Use instance profiles - IAM roles"
[19]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html?utm_source=chatgpt.com "Use an IAM role to grant permissions to applications ..."
[20]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html?utm_source=chatgpt.com "IAM JSON policy element reference"
[21]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_effect.html?utm_source=chatgpt.com "IAM JSON policy elements: Effect"
[22]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_resource.html?utm_source=chatgpt.com "IAM JSON policy elements: Resource"
[23]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition.html?utm_source=chatgpt.com "IAM JSON policy elements: Condition"
[24]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html?utm_source=chatgpt.com "Policies and permissions in AWS Identity and Access ..."
[25]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_identity-vs-resource.html?utm_source=chatgpt.com "Identity-based policies and resource- ..."
[26]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html?utm_source=chatgpt.com "Policy evaluation logic - AWS Identity and Access ..."
[27]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic-cross-account.html?utm_source=chatgpt.com "Cross-account policy evaluation logic"
[28]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_update-role-trust-policy.html?utm_source=chatgpt.com "Update a role trust policy - AWS Documentation - Amazon.com"
[29]: https://docs.aws.amazon.com/marketplace/latest/buyerguide/buyer-iam-users-groups-policies.html?utm_source=chatgpt.com "Controlling access to AWS Marketplace subscriptions"
[30]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic_policy-eval-basics.html?utm_source=chatgpt.com "Policy evaluation for requests within a single account"
[31]: https://docs.aws.amazon.com/cli/latest/reference/sts/decode-authorization-message.html?utm_source=chatgpt.com "decode-authorization-message"
[32]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-custom.html?utm_source=chatgpt.com "Create a role using custom trust policies - AWS Documentation"
[33]: https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot_roles.html?utm_source=chatgpt.com "Troubleshoot IAM roles - AWS Identity and Access Management"
[34]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic_AccessPolicyLanguage_Interplay.html?utm_source=chatgpt.com "The difference between explicit and implicit denies"
