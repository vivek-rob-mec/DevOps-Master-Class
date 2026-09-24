# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 2: SCPs, RCPs & AWS Permission Evaluation — Deep Dive

This part solves one of the most frustrating AWS production problems:

> **“My role has `AdministratorAccess`. Why am I still getting `AccessDenied`?”**

Because in enterprise AWS:

```text
IAM policy
```

is only **one layer** of authorization.

---

# 38.83 The authorization mental model

A request might pass through several controls:

```text
                    AWS API REQUEST
                          │
                          ▼
                  Who is the principal?
                          │
                          ▼
                  Identity Policy
                          │
                          ▼
                Permissions Boundary
                          │
                          ▼
                   Session Policy
                          │
                          ▼
                        SCP
                          │
                          ▼
                        RCP
                          │
                          ▼
                 Resource Policy
                          │
                          ▼
               VPC Endpoint Policy?
                          │
                          ▼
               Service-specific policy?
                          │
                          ▼
                    FINAL DECISION
```

AWS evaluates multiple applicable policy types together, and an explicit `Deny` overrides an `Allow`. ([AWS Documentation][1])

---

# 38.84 Authentication vs authorization

Before authorization, AWS first needs to know:

```text
WHO ARE YOU?
```

Examples:

```text
IAM user

IAM role session

IAM Identity Center session

EC2 role

Lambda execution role

federated identity
```

That's authentication.

Then AWS asks:

```text
WHAT ARE YOU ALLOWED TO DO?
```

That's authorization.

Never mix:

```text
authentication failure
```

with:

```text
AccessDenied authorization failure.
```

---

# 38.85 The three IAM rules

Almost every permissions problem becomes easier if you remember:

```text
RULE 1

Default = DENY


RULE 2

Explicit ALLOW
can overcome implicit deny


RULE 3

Explicit DENY
beats ALLOW
```

AWS permission evaluation consistently gives explicit denial precedence over applicable allows. ([AWS Documentation][1])

---

# 38.86 Default deny

Imagine a new IAM role with:

```text
no policies
```

Request:

```text
ec2:RunInstances
```

Result:

```text
DENIED
```

Not because somebody wrote:

```json
{
  "Effect": "Deny"
}
```

but because nothing granted the action.

That's:

# Implicit Deny

---

# 38.87 Explicit Allow

Now identity policy says:

```json
{
  "Effect": "Allow",
  "Action": "ec2:RunInstances",
  "Resource": "*"
}
```

That creates a potential permission.

But only if another controlling policy does not restrict it.

This is where many engineers stop thinking too early.

---

# 38.88 Explicit Deny

Suppose IAM says:

```text
Allow ec2:*
```

but an SCP says:

```text
Deny ec2:RunInstances
```

Result:

```text
RunInstances
DENIED
```

Even attaching:

```text
AdministratorAccess
```

doesn't bypass the SCP. AWS explicitly states that SCP restrictions apply even when an account administrator attaches `AdministratorAccess`. ([AWS Documentation][2])

---

# 38.89 Identity-based policy

Attached to:

```text
IAM user

IAM group

IAM role
```

Question answered:

> **What is this identity granted?**

Example:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:ListBucket"
  ],
  "Resource": "*"
}
```

Think:

```text
PRINCIPAL
   │
   ▼
permissions
```

---

# 38.90 Resource-based policy

Attached to a resource.

Examples:

```text
S3 bucket policy

KMS key policy

SQS queue policy

SNS topic policy

Secrets Manager resource policy

IAM role trust policy
```

Mental direction:

```text
RESOURCE
   │
   ▼
Who may access me?
```

Within an account, identity- and resource-based permissions generally combine as a union, while explicit denies override allows. ([AWS Documentation][1])

---

# 38.91 Identity policy vs resource policy

Think:

```text
IDENTITY POLICY

Role:
PaymentsApp

"Role may access Bucket X."
```

versus:

```text
RESOURCE POLICY

Bucket X:

"PaymentsApp may access me."
```

Depending on:

```text
same account
cross-account
service
principal form
other guardrails
```

the evaluation rules differ.

We'll handle cross-account shortly.

---

# 38.92 Permissions Boundary

A permissions boundary says:

> **Even if somebody attaches more IAM policies to this user/role, how powerful is it allowed to become?**

Example:

```text
Identity Policy:

Allow
s3:*
ec2:*
iam:*


Permissions Boundary:

Allow
s3:*
ec2:*


Effective maximum:

S3  ✓
EC2 ✓
IAM ✕
```

AWS describes the effective identity permissions as the intersection of the identity policy and permissions boundary. ([AWS Documentation][1])

---

# 38.93 Why permissions boundaries are useful

Imagine you want developers to create their own application IAM roles.

Danger:

```text
Developer
   │
   ▼
iam:CreateRole
   │
   ▼
creates
SuperAdminRole
   │
   ▼
privilege escalation
```

Instead:

```text
Developer
   │
   ▼
may create roles

BUT

every role must use
DeveloperBoundary
```

Boundary:

```text
No Organizations administration
No IAM admin
No security-control modification
```

AWS recommends permissions boundaries when delegating IAM administration so delegated principals cannot grant permissions beyond the approved maximum. ([AWS Documentation][3])

---

# 38.94 Session Policy

Temporary credentials can also be constrained by:

# Session Policies

For example:

```text
Role permissions:
S3 + EC2 + RDS

AssumeRole session policy:
S3 only
```

The session becomes more restrictive.

A session policy doesn't expand the role's permissions; it restricts the temporary session.

AWS AccessDenied messages can explicitly indicate that a request failed because no session policy allowed the action or because a session policy explicitly denied it. ([AWS Documentation][4])

---

# 38.95 SCP

Now organization level.

# Service Control Policy

Mental question:

> **What is the maximum permission available to principals in this member account?**

Example:

```text
IAM AdministratorAccess
         │
         ▼
      everything

SCP
         │
         ▼
No RDS deletion
No Org leaving
No unapproved Region

         │
         ▼

Effective admin
inside those organizational limits
```

SCPs are principal-centric organization guardrails and never directly grant permission. ([AWS Documentation][5])

---

# 38.96 RCP

# Resource Control Policy

Now turn the direction around.

Question:

> **What is the maximum access that resources in these accounts may accept?**

Architecture:

```text
                 ORGANIZATION

          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼

         SCP                   RCP

   protects limits       protects limits
     on principals         on resources

 "What may our       "Who/what may access
 identities do?"      our resources?"
```

AWS explicitly describes SCPs as principal-centric and RCPs as resource-centric authorization guardrails. ([AWS Documentation][5])

---

# 38.97 SCP + RCP together

A useful data-perimeter picture:

```text
                      YOUR AWS ORG

                ┌────────────────────┐
                │                    │
      identities│                    │resources
                │                    │
             SCP│                    │RCP
                │                    │
                └────────────────────┘
```

SCP:

```text
Stop our identities
doing prohibited things.
```

RCP:

```text
Stop our resources
accepting prohibited access.
```

AWS specifically notes that the two can be used together as complementary controls around identities and resources. ([AWS Documentation][5])

---

# 38.98 Full evaluation shortcut

For a typical principal in an Organizations member account, think conceptually:

```text
Permission granted by identity/resource policy?
                  │
                  ▼
Boundary allows?
                  │
                  ▼
Session allows?
                  │
                  ▼
SCP path permits?
                  │
                  ▼
RCP permits resource access?
                  │
                  ▼
Any explicit Deny anywhere?
                  │
                  ├── YES → DENY
                  │
                  └── NO  → potentially ALLOW
```

Actual IAM evaluation has nuances for specific resource-policy principal types, but this mental model is excellent for troubleshooting most production cases. AWS documents the intersection among identity permissions, SCPs and RCPs for organization-member requests, with explicit deny taking precedence. ([AWS Documentation][1])

---

# 38.99 Same-account basic evaluation

Suppose:

```text
Account A
```

contains:

```text
Role PaymentsApp
Bucket PaymentsData
```

Identity policy:

```text
Allow s3:GetObject
```

No explicit denies.

Result:

```text
GetObject ✓
```

AWS normally evaluates identity-based and resource-based grants together for same-account access; an applicable allow can authorize the action unless some restrictive policy or explicit deny blocks it. ([AWS Documentation][1])

---

# 38.100 Cross-account changes the game

Suppose:

```text
Account A
PaymentsApp role

        │
        │ access
        ▼

Account B
SharedBucket
```

For cross-account authorization AWS performs evaluation on both sides.

```text
TRUSTED / CALLER ACCOUNT
        │
        ▼
Does principal side permit request?


RESOURCE / TRUSTING ACCOUNT
        │
        ▼
Does resource side permit request?
```

Both sides must reach an allowed result for cross-account access to succeed. ([AWS Documentation][6])

---

# 38.101 Cross-account S3 example

Account A role:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource":
    "arn:aws:s3:::shared-data/*"
}
```

But Account B bucket has no cross-account grant.

Result:

```text
AccessDenied
```

One side saying:

```text
"I want access"
```

does not mean the other account says:

```text
"I trust you."
```

---

# 38.102 AssumeRole has two major sides

Suppose:

```text
Account A
DeveloperRole

       │ AssumeRole
       ▼

Account B
ProductionReadOnlyRole
```

You generally reason about:

### Caller side

```text
DeveloperRole
must be permitted to call:

sts:AssumeRole
```

### Target role side

Its trust policy must trust the caller.

If the trust policy doesn't allow it:

```text
AssumeRole
DENIED
```

AWS AccessDenied troubleshooting explicitly identifies missing or explicit-deny role trust policies as a cause of `sts:AssumeRole` failures. ([AWS Documentation][4])

---

# 38.103 Why AdministratorAccess may still fail

Consider:

```text
DeveloperRole
AdministratorAccess
```

Request:

```text
ec2:RunInstances
ap-south-1
```

Result:

```text
AccessDenied
```

Possible causes:

```text
SCP

permissions boundary

session policy

resource policy

RCP

VPC endpoint policy

service-specific condition

role trust

KMS key policy
```

This is why looking only at:

```text
IAM → Role → Permissions
```

is not enough.

---

# 38.104 SCP inheritance

Suppose:

```text
ROOT
 │
 ▼
Workloads OU
 │
 ▼
Production OU
 │
 ▼
Payments Account
```

SCP evaluation considers the path through the organization hierarchy.

AWS states that when using allow-style SCPs, a permission must remain allowed at every level from Root through the applicable OU hierarchy to the account; an explicit deny at any level in the path blocks descendants. ([AWS Documentation][7])

Think:

```text
Root
  ∩
Workloads
  ∩
Production
  ∩
Payments
```

---

# 38.105 Example SCP path

Root:

```text
Allow everything
```

Workloads:

```text
Allow everything
```

Production:

```text
Deny ec2:TerminateInstances
```

Payments account:

```text
Allow everything
```

Result:

```text
TerminateInstances
DENIED
```

because the `Deny` at Production OU affects descendant accounts. ([AWS Documentation][7])

---

# 38.106 FullAWSAccess

When SCPs are enabled, AWS Organizations uses the AWS-managed:

```text
FullAWSAccess
```

SCP as the permissive default.

Important:

```text
FullAWSAccess SCP
```

does **not** grant AWS permissions.

It simply avoids imposing additional SCP restrictions. ([AWS Documentation][7])

---

# 38.107 Two SCP strategies

## Deny-list strategy

Keep:

```text
FullAWSAccess
```

and add specific:

```text
Deny
```

guardrails.

Example:

```text
Everything may potentially be granted

EXCEPT:

leave organization
disable logging
unapproved Regions
```

This is easier to adopt gradually.

AWS's published SCP examples primarily use this style and recommends testing before broad rollout. ([AWS Documentation][8])

---

# 38.108 Allow-list strategy

Remove broad allowance and explicitly permit only selected services/actions.

Example:

```text
Allowed at Root:
S3
EC2
CloudWatch

Everything else:
implicit organizational deny
```

This is much stricter.

But the operational burden is larger because every required service/API must stay permitted through the entire OU/account path. AWS's SCP evaluation documentation explains that an allow must exist at each hierarchy level when using this model. ([AWS Documentation][7])

---

# 38.109 Which strategy would I start with?

For many organizations:

```text
Deny-list guardrails first
```

is safer operationally.

Why?

Because moving directly from:

```text
everything works
```

to:

```text
only specifically allowlisted APIs work
```

can break:

```text
deployments
security tooling
automation
AWS service integrations
```

if you don't deeply understand every dependency.

AWS itself recommends testing SCPs in a representative test OU and gradually expanding deployment scope. ([AWS Documentation][8])

---

# 38.110 SCP affects the member-account root user

Very important.

Inside a **member account**, SCPs can restrict:

```text
IAM users

IAM roles

member-account root user
```

AWS explicitly states SCPs apply to the member account root user as well as users and roles. ([AWS Documentation][2])

So:

```text
"I'll log in as root
and bypass the SCP."
```

doesn't work for an SCP attached to that member account hierarchy.

---

# 38.111 But not the management account

The major exception:

```text
AWS Organizations
Management Account
```

is not restricted by SCPs.

AWS explicitly states that SCPs don't affect users or roles in the management account. ([AWS Documentation][2])

That is one major reason we learned:

> **Do not place ordinary workloads in the management account.**

---

# 38.112 Delegated administrator accounts ARE restricted

Suppose:

```text
Security Account
```

is delegated administrator for a security service.

It is still:

```text
a member account
```

so applicable SCPs still constrain its principals. AWS explicitly calls this out. ([AWS Documentation][2])

Delegated administrator:

```text
≠ management account.
```

---

# 38.113 Service-linked roles exception

Important advanced exception:

SCPs don't restrict:

# Service-linked roles

AWS services rely on these predefined roles to operate integrations and service functionality. AWS Organizations documentation explicitly states SCPs do not affect service-linked roles. ([AWS Documentation][2])

So don't assume:

```text
SCP Deny service:X
```

necessarily controls an AWS service's service-linked role in the same way it controls your normal IAM roles.

---

# 38.114 Guardrail #1 — approved Regions

Suppose we approve:

```text
ap-south-1

ap-southeast-1
```

and want to restrict most Regional operations elsewhere.

Conceptual SCP:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyOutsideApprovedRegions",
      "Effect": "Deny",
      "NotAction": [
        "cloudfront:*",
        "iam:*",
        "organizations:*",
        "route53:*",
        "support:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "ap-south-1",
            "ap-southeast-1"
          ]
        }
      }
    }
  ]
}
```

AWS documents this general `Deny + NotAction + aws:RequestedRegion` pattern for Region restriction. ([AWS Documentation][9])

---

# 38.115 Why `NotAction` is important here

At first you might write:

```json
{
  "Effect": "Deny",
  "Action": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": [
        "ap-south-1"
      ]
    }
  }
}
```

Danger.

Some AWS global services use endpoints associated with a particular home Region.

AWS specifically warns that services such as IAM, CloudFront, Route 53 and Support need appropriate exemptions in Region-deny policies, and additional global services used by the organization may need exemption as well. ([AWS Documentation][9])

---

# 38.116 Never copy a Region SCP blindly

The exact:

```text
NotAction
```

list depends on services you use.

AWS's own example explicitly says to adjust the list for additional global services such as Organizations, Global Accelerator, WAF and others. ([AWS Documentation][9])

So production process:

```text
Identify approved Regions
      │
      ▼
inventory global services
      │
      ▼
build exception list
      │
      ▼
test in sandbox OU
      │
      ▼
roll out gradually
```

---

# 38.117 Guardrail #2 — prevent leaving the organization

A classic enterprise guardrail is preventing ordinary member-account principals from calling:

```text
organizations:LeaveOrganization
```

Conceptually:

```json
{
  "Effect": "Deny",
  "Action": "organizations:LeaveOrganization",
  "Resource": "*"
}
```

AWS Organizations includes this use case in its SCP evaluation examples. ([AWS Documentation][10])

Why?

Because an account leaving the organization could escape organization governance mechanisms.

---

# 38.118 Guardrail #3 — protect security controls

Conceptually, a production OU might deny destructive operations against centralized controls, for example:

```text
StopConfigurationRecorder

DeleteConfigRule

DeleteTrail

Disable security tooling

Remove critical logging configuration
```

AWS Managed Services publishes SCP guardrail examples that deny actions such as deleting/stopping AWS Config recorders and rules, illustrating this preventive-control pattern. ([AWS Documentation][11])

The precise actions must match your security architecture.

---

# 38.119 Security guardrail philosophy

Do not write:

```text
Deny guardduty:*
```

unless your intention is really:

```text
nobody may use GuardDuty
```

Usually you want to stop:

```text
disabling
deleting
modifying
```

specific organization-managed security configuration.

Good guardrail design is:

```text
block destructive control-plane actions
```

without blocking:

```text
normal read/investigation operations
```

unless required.

---

# 38.120 Break-glass exception

Suppose the Security team needs an emergency role:

```text
OrganizationBreakGlassRole
```

You might design a deny with an exception based on:

```text
aws:PrincipalArn
```

Conceptually:

```json
{
  "Effect": "Deny",
  "Action": [
    "some:CriticalAction"
  ],
  "Resource": "*",
  "Condition": {
    "ArnNotLike": {
      "aws:PrincipalArn":
        "arn:aws:iam::*:role/OrganizationBreakGlassRole"
    }
  }
}
```

AWS documents `aws:PrincipalArn` as a global condition key suitable for comparing the calling IAM role/user ARN; for IAM roles it returns the role ARN, not the assumed-role session ARN. ([AWS Documentation][12])

---

# 38.121 Why role ARN behavior matters

You may see the active session as:

```text
arn:aws:sts::123456789012:
assumed-role/OrganizationBreakGlassRole/Vivek
```

but `aws:PrincipalArn` for an IAM role request evaluates using:

```text
arn:aws:iam::123456789012:
role/OrganizationBreakGlassRole
```

AWS explicitly documents this behavior. ([AWS Documentation][12])

That makes role-based policy exceptions much easier to manage than enumerating every session name.

---

# 38.122 Break-glass must be dangerous by design

Do not create:

```text
BreakGlassRole
```

and then let everyone assume it daily.

Use controls around it:

```text
restricted assumers

strong MFA

temporary access

alert on assumption

CloudTrail monitoring

incident approval

post-use review
```

The purpose is:

```text
emergency recovery
```

not:

```text
SCP workaround.
```

---

# 38.123 `aws:PrincipalOrgID`

This is one of the best cross-account condition keys.

Suppose S3 should accept access from any current account in your organization.

Instead of maintaining:

```text
111111111111
222222222222
333333333333
...
```

you can use:

```text
aws:PrincipalOrgID
```

AWS automatically evaluates whether the requesting principal belongs to the specified organization, and membership changes don't require manually updating every account ID in the policy. ([AWS Documentation][12])

---

# 38.124 S3 organization-only example

Concept:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::company-private-data",
    "arn:aws:s3:::company-private-data/*"
  ],
  "Condition": {
    "StringNotEquals": {
      "aws:PrincipalOrgID":
        "o-exampleorgid"
    }
  }
}
```

AWS publishes this pattern for denying S3 access to principals outside an organization and notes that explicit deny provides stronger defense than merely conditioning one Allow statement. ([AWS Documentation][13])

---

# 38.125 Important AWS-service exception

Be careful.

An organization-only deny may unintentionally affect AWS service principals that need to deliver data to your bucket, such as logging services.

AWS warns that `aws:PrincipalOrgID` conditions can affect AWS service access and points architects toward service-principal-aware conditions such as `aws:PrincipalIsAWSService` when appropriate. ([AWS Documentation][12])

Again:

```text
policy looks secure
```

doesn't automatically mean:

```text
policy works.
```

---

# 38.126 SCP vs `aws:PrincipalOrgID`

Don't confuse them.

### SCP

Controls:

```text
principals belonging to
affected member accounts.
```

### Resource policy + PrincipalOrgID

Controls:

```text
who may enter
this specific resource.
```

They solve related but different directions of access control.

---

# 38.127 Now RCPs deeply

RCP:

```text
Organization policy
attached to:

Root
OU
Account
```

but it controls access to:

```text
resources owned
inside affected member accounts.
```

AWS defines RCPs as preventive resource-centric guardrails over the maximum available access to organization resources. ([AWS Documentation][14])

---

# 38.128 RCP default policy

When RCPs are enabled, AWS automatically attaches:

```text
RCPFullAWSAccess
```

to:

```text
Root

every OU

every account
```

and that policy cannot be detached.

It allows permissions to pass through RCP evaluation without granting permissions itself. ([AWS Documentation][15])

---

# 38.129 Current custom RCPs are deny-oriented

This is an important 2026 nuance.

For custom RCPs:

```text
Effect must be Deny.
```

AWS currently supports `Allow` only in the AWS-managed `RCPFullAWSAccess` policy. ([AWS Documentation][16])

So think:

```text
RCPFullAWSAccess
+
custom Deny guardrails
```

rather than building custom allow-list RCPs the way you might with SCPs.

---

# 38.130 RCP syntax differences

Current RCP rules include:

```text
Principal required

Principal can only be "*"

Action required

Resource / NotResource required

Condition supported
```

and custom RCPs do not support:

```text
NotPrincipal

NotAction
```

AWS documents these current syntax constraints. ([AWS Documentation][16])

---

# 38.131 RCP example — require TLS for S3

AWS publishes an RCP pattern like:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": "*",
  "Condition": {
    "BoolIfExists": {
      "aws:SecureTransport": "false"
    }
  }
}
```

Meaning:

```text
Resources in affected accounts:

don't accept S3 operations
using insecure transport.
```

This is explicitly documented in the current RCP syntax guide. ([AWS Documentation][16])

---

# 38.132 Why RCP can be stronger than editing 500 bucket policies

Imagine:

```text
500 AWS accounts

10,000 S3 buckets
```

You want one organization-level resource access rule.

Without RCP:

```text
modify thousands
of resource policies
```

With RCP:

```text
organization-level
resource guardrail
```

That's the scaling benefit AWS designed RCPs to provide. ([AWS Documentation][14])

---

# 38.133 RCP particularly matters for external principals

This is subtle and powerful.

Suppose:

```text
Vendor Account
outside your AWS Organization
```

accesses:

```text
S3 bucket
inside your organization.
```

An SCP attached to your account does not apply to the vendor's IAM identity because that identity is managed outside your organization.

AWS explicitly states SCPs do not constrain users and roles from outside accounts. ([AWS Documentation][2])

But an RCP controls:

```text
the resource inside your account
```

and therefore can restrict what external identities are allowed to do to it. AWS specifically calls this out as a major RCP use case. ([AWS Documentation][5])

---

# 38.134 This is the SCP/RCP breakthrough

```text
                     THIRD PARTY

                         │
                         │
                         ▼
                   YOUR RESOURCE
```

SCP question:

```text
Is the third party one
of OUR principals?

No.

SCP doesn't govern
their identity directly.
```

RCP question:

```text
Is the resource OUR resource?

Yes.

RCP can constrain
what the resource accepts.
```

That's why RCPs matter.

---

# 38.135 RCP service support is not universal

Do not assume every AWS service/resource supports RCP authorization.

AWS's RCP syntax documentation points to a dedicated current list of services that support RCPs. ([AWS Documentation][16])

So before designing:

```text
organization-wide RCP
for Service X
```

verify:

```text
Service X supports RCP
```

first.

---

# 38.136 RCP does not grant access

Same trap as SCP.

RCP:

```text
Deny bad access
```

doesn't mean:

```text
good access is automatically granted.
```

The identity/resource still needs an applicable normal permissions grant.

AWS explicitly states RCPs are guardrails and never directly grant permission. ([AWS Documentation][17])

---

# 38.137 Service-linked role exception also matters to RCPs

AWS also states that RCPs do not restrict the effective permissions of service-linked roles, nor do they affect AWS services' ability to assume their service-linked roles. ([AWS Documentation][14])

Again:

```text
normal principal
```

and:

```text
AWS-managed service-linked role
```

do not always follow identical organization-policy effects.

---

# 38.138 IAM `PassRole` — privilege escalation trap

One dangerous permission deserves special attention:

```text
iam:PassRole
```

Suppose developer cannot directly:

```text
s3:DeleteBucket
```

but can create Lambda and pass:

```text
AdministratorRole
```

to it.

Then:

```text
Developer
   │
   │ iam:PassRole
   ▼
Lambda
   │
   ▼
AdministratorRole
   │
   ▼
high privilege action
```

The developer indirectly gained power.

AWS recommends restricting `iam:PassRole` to specific roles and, where useful, constraining the service/resource to which the role may be passed. ([AWS Documentation][18])

---

# 38.139 Production PassRole rule

Avoid:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

for ordinary developers.

Prefer:

```text
Pass only:

application execution roles

with approved permission boundary

to approved services
```

This is a huge privilege-escalation prevention technique.

---

# 38.140 Full AccessDenied troubleshooting flow

Now the practical sequence.

User says:

```text
I have AdministratorAccess
but:

AccessDenied
```

Do this:

```text
STEP 1
Identify exact caller

STEP 2
Identify exact API action

STEP 3
Identify exact resource

STEP 4
Determine same-account or cross-account

STEP 5
Check identity policy

STEP 6
Check permissions boundary

STEP 7
Check session policy

STEP 8
Check SCP hierarchy

STEP 9
Check RCP on resource's hierarchy

STEP 10
Check resource policy

STEP 11
Check trust policy

STEP 12
Check VPC endpoint policy

STEP 13
Check service-specific policy/KMS

STEP 14
Check request conditions

STEP 15
Use CloudTrail + simulation
```

AWS AccessDenied messages increasingly identify the policy type responsible for denials, including SCPs, RCPs, boundaries, sessions, resource policies, VPC endpoint policies, trust policies and identity policies. ([AWS Documentation][19])

---

# 38.141 Step 1 — identify who you actually are

Run:

```bash
aws sts get-caller-identity
```

Never assume your shell is using:

```text
the role you think it is.
```

You may actually be:

```text
different profile

different account

different assumed role

old credentials

SSO session
```

The ARN immediately narrows the investigation.

---

# 38.142 Example output

```json
{
  "UserId": "...",
  "Account": "111122223333",
  "Arn":
    "arn:aws:sts::111122223333:
     assumed-role/DeveloperRole/vivek"
}
```

Now you know:

```text
Account
111122223333

Role
DeveloperRole

Session
vivek
```

Start there.

---

# 38.143 Step 2 — identify exact API action

Error:

```text
UnauthorizedOperation
```

isn't enough.

Find:

```text
ec2:DescribeInstanceTypes
```

versus:

```text
ec2:RunInstances
```

versus:

```text
ec2:CreateTags
```

Many AWS workflows perform multiple APIs.

For example:

```text
terraform apply
```

may need:

```text
Describe*

Create*

Tag*

Attach*

PassRole
```

One missing API can fail the entire resource creation.

---

# 38.144 Step 3 — read the AccessDenied wording

Modern AWS errors may say things like:

```text
because no identity-based policy allows...
```

or:

```text
with an explicit deny in
a service control policy
```

or:

```text
because no permissions boundary allows...
```

or:

```text
with an explicit deny in
a resource control policy
```

AWS's troubleshooting guide documents these distinct error forms. ([AWS Documentation][19])

Read the error carefully before editing policies randomly.

---

# 38.145 Example

Suppose:

```text
User ... is not authorized to perform:
codecommit:ListRepositories

with an explicit deny in
a service control policy
```

Then adding:

```text
AdministratorAccess
```

to the role is pointless.

The failure is above IAM role permissions.

Go investigate:

```text
SCP.
```

AWS even includes policy ARN information in some AccessDenied messages to help locate the responsible SCP/RCP. ([AWS Documentation][19])

---

# 38.146 Step 4 — inspect organization path

For the caller account:

```text
Root
 │
 ▼
Workloads
 │
 ▼
Production
 │
 ▼
Payments
```

You need to inspect applicable SCPs at:

```text
Root

Workloads OU

Production OU

Payments account
```

A deny anywhere on that hierarchy can restrict the account. ([AWS Documentation][7])

---

# 38.147 RCP path is resource-side

Suppose principal is in:

```text
App Account
```

but accesses:

```text
Data Account bucket.
```

SCP analysis focuses heavily on:

```text
principal's organizational path.
```

RCP analysis focuses on:

```text
resource-owning account's
organizational path.
```

That direction helps prevent confusion.

---

# 38.148 Cross-account debugging

Draw it:

```text
ACCOUNT A
CALLER

Role
 │
 │ request
 ▼

ACCOUNT B
RESOURCE
```

Then debug two sides:

```text
CALLER SIDE

identity policy
boundary
session
SCP


RESOURCE SIDE

resource policy
RCP
KMS/key policy
service-specific restrictions
```

Cross-account evaluation succeeds only when the required authorization on both sides succeeds. ([AWS Documentation][6])

---

# 38.149 VPC endpoint policy trap

Suppose everything looks correct:

```text
IAM ✓

SCP ✓

bucket policy ✓
```

but request goes through:

```text
S3 VPC Endpoint
```

whose endpoint policy does not allow the operation.

Result:

```text
AccessDenied
```

AWS specifically documents both implicit and explicit VPC endpoint policy denials as possible causes of authorization failure. ([AWS Documentation][4])

Never forget the network path can introduce another authorization policy.

---

# 38.150 KMS — common enterprise trap

Example:

```text
Role can:
s3:GetObject
```

but object is encrypted with:

```text
SSE-KMS
```

and the role lacks usable KMS authorization.

Result:

```text
S3 permission looks correct

but decrypt fails.
```

For KMS you must often reason about:

```text
IAM policy

KMS key policy

grants

SCP/RCP

conditions
```

rather than only S3.

---

# 38.151 IAM Policy Simulator

AWS provides:

# IAM Policy Simulator

It can test:

```text
identity-based policies

permissions boundaries

SCPs

provided resource policies
```

without sending a live API request. ([AWS Documentation][20])

This is extremely useful for testing:

```text
Would DeveloperRole
be allowed to call
ec2:RunInstances?
```

---

# 38.152 Current simulator limitation — RCPs

Important current limitation:

> The IAM Policy Simulator does **not** currently support RCP evaluation.

AWS explicitly documents this. ([AWS Documentation][20])

Therefore:

```text
Simulator says ALLOW
```

doesn't guarantee:

```text
live request succeeds
```

if an RCP applies.

---

# 38.153 Simulator isn't the production environment

AWS also warns simulation can differ from live behavior for advanced cases such as:

```text
VPC endpoint policies

role chaining

certain resource-policy scenarios
```

so always validate important controls in a safe live environment after simulation. ([AWS Documentation][20])

Mental model:

```text
Simulator
=
excellent debugging/testing aid

NOT
absolute production proof.
```

---

# 38.154 CloudTrail during authorization troubleshooting

CloudTrail is extremely useful because it lets you inspect:

```text
who

what API

which Region

source IP

request parameters

error code

event time
```

instead of relying on:

```text
"I clicked something
and AWS said denied."
```

Use the failing request as evidence.

---

# 38.155 Production SCP rollout strategy

Do not:

```text
write powerful SCP

attach to Root

go home.
```

AWS strongly recommends testing SCPs in a separate or representative OU before applying them more broadly. ([AWS Documentation][8])

Use:

```text
Draft
  ↓
policy review
  ↓
test OU
  ↓
test accounts
  ↓
observe failures
  ↓
Production OU
  ↓
broader deployment
```

---

# 38.156 Production RCP rollout is even more sensitive

AWS explicitly recommends thoroughly testing RCPs before attaching them broadly, particularly at the organization root. ([AWS Documentation][15])

Why?

An RCP can affect:

```text
external integrations

AWS services

cross-account applications

logging

backup

security tooling
```

if you misunderstand which principals/resources are involved.

---

# 38.157 Policy deployment as code

Treat organization policies like application code:

```text
organizations/
│
├── scp/
│   ├── deny-unapproved-regions.json
│   ├── protect-security-controls.json
│   └── prevent-org-leave.json
│
├── rcp/
│   ├── enforce-tls.json
│   └── restrict-external-access.json
│
└── tests/
```

Workflow:

```text
Pull Request
    ↓
security review
    ↓
policy validation
    ↓
test OU
    ↓
simulation
    ↓
controlled rollout
```

Not:

```text
edit production SCP
live in console
without review.
```

---

# 38.158 Don't build one giant SCP

Bad:

```text
CorporateEverythingPolicy.json

4,900 lines
```

Problems:

```text
hard to reason about

hard to test

hard to identify denial source

blast radius huge
```

Better conceptual separation:

```text
RegionGuardrail

SecurityControlProtection

OrganizationMembershipProtection

IAMGuardrail

NetworkSharingGuardrail
```

Then attach deliberately based on governance requirements.

---

# 38.159 Coarse guardrails, fine IAM

SCPs and RCPs are intended as:

```text
coarse-grained preventative guardrails
```

not substitutes for:

```text
least-privilege workload IAM.
```

AWS explicitly describes both as guardrails; normal identity/resource policies remain necessary for actual permission grants. ([AWS Documentation][8])

So:

```text
SCP
=
organization rule


IAM
=
application/user permission
```

---

# 38.160 Example permission stack

Developer wants:

```text
s3:PutObject
```

Identity policy:

```text
ALLOW
```

Boundary:

```text
ALLOW
```

SCP:

```text
ALLOW / no deny
```

RCP:

```text
no deny
```

Bucket policy:

```text
compatible
```

Endpoint policy:

```text
ALLOW
```

Result:

```text
SUCCESS
```

---

# 38.161 Change one layer

SCP:

```text
Deny s3:PutObject
```

Everything else:

```text
ALLOW
```

Result:

```text
DENY
```

This is the point:

```text
Permissions are not additive
across restrictive boundaries.
```

One explicit deny can end the evaluation.

---

# 38.162 Scenario — developer admin but EC2 denied outside Mumbai

Role:

```text
AdministratorAccess
```

Region:

```text
eu-west-1
```

SCP:

```text
only ap-south-1
and ap-southeast-1
```

Result:

```text
ec2:RunInstances
AccessDenied
```

Reason:

```text
IAM grants the action

but organizational
Region guardrail denies it.
```

Exactly expected.

---

# 38.163 Scenario — vendor cannot read bucket

Bucket policy:

```text
Allow VendorRole
```

but RCP says:

```text
Deny principals
outside our approved organization
```

Result:

```text
Vendor
DENIED
```

This demonstrates resource-centric governance: an RCP can constrain access by an external identity to a resource owned in your organization. ([AWS Documentation][5])

---

# 38.164 Scenario — EC2 launch fails despite EC2 full access

User has:

```text
ec2:*
```

but Terraform launches instance with IAM instance profile.

Terraform needs:

```text
iam:PassRole
```

User lacks it.

Result:

```text
RunInstances workflow fails.
```

Never assume:

```text
"EC2FullAccess"
=
everything needed
to launch every possible EC2 configuration.
```

Dependent service permissions matter.

---

# 38.165 Scenario — AssumeRole fails

Caller policy:

```text
Allow sts:AssumeRole
```

Target:

```text
ProdReadOnlyRole
```

trust policy does not trust caller.

Result:

```text
AccessDenied
```

Remember:

```text
caller permission
+
target trust
```

both matter in cross-account role assumption. ([AWS Documentation][4])

---

# 38.166 Scenario — service works manually but fails through VPC endpoint

Laptop:

```text
S3 GetObject ✓
```

EC2 inside private VPC:

```text
S3 GetObject ✕
```

Possible cause:

```text
S3 endpoint policy.
```

Same IAM principal.

Different request path.

Therefore inspect:

```text
network-adjacent policy controls.
```

AWS AccessDenied guidance specifically documents VPC endpoint policy denials. ([AWS Documentation][19])

---

# 38.167 Interview trap — SCP grants permission

Question:

> An SCP contains `"Allow": "s3:*"`. Does that grant every user S3 access?

# No.

It only means S3 is within the maximum organizational permission boundary at that level.

The user/role still needs an applicable IAM/resource grant. ([AWS Documentation][21])

---

# 38.168 Interview trap — AdministratorAccess beats SCP

# No.

SCP explicit restrictions remain effective against member-account principals even if they have `AdministratorAccess`. ([AWS Documentation][2])

---

# 38.169 Interview trap — member root bypasses SCP

# No.

SCPs also constrain the member-account root user. ([AWS Documentation][2])

---

# 38.170 Interview trap — management account is protected by SCP

# No.

Management-account principals are outside SCP enforcement. ([AWS Documentation][2])

---

# 38.171 Interview trap — RCP grants resource permission

# No.

It constrains the maximum access a resource may accept.

Normal resource/identity permission still has to grant access. ([AWS Documentation][14])

---

# 38.172 Interview trap — SCP protects against external vendor access

Not necessarily.

An SCP attached to your account controls principals managed by your organization member accounts; it doesn't directly govern the vendor's outside identity.

For resource-side restrictions against external identities:

```text
RCP
and/or
resource policy
```

is often the relevant direction. ([AWS Documentation][2])

---

# 38.173 Interview trap — IAM Simulator proves live access

No.

Simulator:

```text
useful
```

but not definitive.

It currently does not simulate RCPs and can differ from live behavior in some advanced cases. ([AWS Documentation][20])

---

# 38.174 Interview trap — Region deny with `"Action":"*"` is simple and safe

Not automatically.

Global services can use fixed home endpoints such as `us-east-1`, so Region restrictions need carefully designed `NotAction` exceptions for global services your organization depends on. ([AWS Documentation][9])

---

# 38.175 Senior interview answer — explain AWS authorization

A strong answer:

> **AWS begins with implicit deny. Applicable identity and resource policies can grant access, while permissions boundaries, session policies, SCPs and RCPs may constrain the effective permission set. Cross-account access also requires authorization on both the caller side and the resource/trusting-account side. An explicit deny in an applicable policy overrides allows. For AccessDenied troubleshooting, I identify the caller, exact API and resource first, then walk through identity policy, boundary, session policy, SCP hierarchy, RCP, resource/trust policy, endpoint policy, KMS/service-specific authorization and request conditions.** ([AWS Documentation][1])

That is a senior-level answer.

---

# 38.176 The full policy mental map

```text
                         REQUEST
                            │
                            ▼
                         PRINCIPAL
                            │
                ┌───────────┼───────────┐
                │           │           │
                ▼           ▼           ▼
            Identity     Boundary     Session
             Policy       Policy       Policy
                │           │           │
                └───────────┼───────────┘
                            ▼
                           SCP
                     Principal Guardrail
                            │
                            ▼

                       AWS RESOURCE
                            │
               ┌────────────┼────────────┐
               │            │            │
               ▼            ▼            ▼
           Resource        RCP         Service
            Policy      Resource      Specific
                       Guardrail        Policy
                            │
                            ▼
                     Endpoint Policy?
                            │
                            ▼
                       Any DENY?
                     /          \
                   YES           NO
                    │             │
                    ▼             ▼
                   DENY         ALLOW
                        if required
                        grants exist
```

---

# 38.177 The never-forget formulas

### Formula 1

```text
SCP
=
principal-centric
organization guardrail
```

### Formula 2

```text
RCP
=
resource-centric
organization guardrail
```

### Formula 3

```text
SCP / RCP
DO NOT GRANT
```

### Formula 4

```text
EXPLICIT DENY
>
ALLOW
```

### Formula 5

```text
Permissions Boundary
=
maximum permissions
IAM administration may grant
to that identity
```

### Formula 6

```text
Cross Account
=
caller side
+
resource/trust side
```

---

# 38.178 AccessDenied five-word troubleshooting mnemonic

Remember:

# **WHO → WHAT → WHERE → BOUNDARY → DENY**

```text
WHO
Which principal/session?


WHAT
Which exact API?


WHERE
Which account/Region/resource?


BOUNDARY
Boundary/SCP/RCP/session?


DENY
Which explicit deny/policy?
```

Then investigate the detailed layers.

---

# 38.179 Final SCP/RCP comparison

| Question                                                   | SCP                               | RCP                                        |
| ---------------------------------------------------------- | --------------------------------- | ------------------------------------------ |
| Organization policy?                                       | Yes                               | Yes                                        |
| Grants permission?                                         | No                                | No                                         |
| Focus                                                      | Principal                         | Resource                                   |
| Attached to Root/OU/account                                | Yes                               | Yes                                        |
| Useful for member identities                               | Yes                               | Indirectly through resource access         |
| Useful against external principals accessing org resources | Not directly                      | Yes                                        |
| Custom Allow model                                         | SCP can use allow-list strategies | Custom RCP `Allow` not supported currently |
| Explicit deny                                              | Yes                               | Yes                                        |
| Management-account principal restriction                   | SCP: no                           | Different resource-side scope              |
| Service-linked roles                                       | Not restricted                    | Not restricted                             |
| Requires Organizations all-features model                  | Yes                               | Yes                                        |

Current AWS documentation treats SCPs and RCPs as independent but complementary organization authorization controls. ([AWS Documentation][5])

---

# 38.180 Part 2 checkpoint

You should now be able to explain and troubleshoot:

```text
✓ implicit deny

✓ explicit allow

✓ explicit deny

✓ identity policies

✓ resource policies

✓ permissions boundaries

✓ session policies

✓ SCPs

✓ SCP inheritance

✓ FullAWSAccess

✓ deny-list vs allow-list SCP

✓ management-account exception

✓ member root-user behavior

✓ service-linked-role behavior

✓ Region restrictions

✓ aws:RequestedRegion

✓ NotAction

✓ aws:PrincipalArn

✓ aws:PrincipalOrgID

✓ break-glass exceptions

✓ PassRole privilege escalation

✓ RCPs

✓ RCPFullAWSAccess

✓ custom RCP deny model

✓ RCP external-access protection

✓ same-account authorization

✓ cross-account authorization

✓ AssumeRole trust

✓ VPC endpoint policy failures

✓ KMS authorization failures

✓ IAM Policy Simulator

✓ RCP simulator limitation

✓ deterministic AccessDenied debugging
```

---

# ✅ Lesson 38 — Part 2 Complete

```text
Part 1
Enterprise Multi-Account Architecture
+ AWS Organizations                     ✓

Part 2
SCP + RCP + IAM Policy Evaluation       ✓

Part 3
AWS Control Tower Landing Zone          NEXT

Part 4
IAM Identity Center

Part 5
Central Security + Logging

Part 6
Network + Shared Services Accounts

Part 7
Account Factory + AFT

Part 8
Delegated Administration

Part 9
Terraform Governance Capstone

Part 10
Final Revision + Interview Mastery
```

# Next — Lesson 38, Part 3

## AWS Control Tower & Enterprise Landing Zone Deep Dive

Next we'll build the environment that surrounds the organization:

```text
                    AWS CONTROL TOWER

                          Landing Zone
                              │
             ┌────────────────┼────────────────┐
             ▼                ▼                ▼

        Organizations      Security        Identity
             │                │                │
             ▼                ▼                ▼
            OUs          Log Archive      IAM Identity
          Accounts          Audit            Center

                              │
                              ▼
                           CONTROLS
                  ┌───────────┼───────────┐
                  ▼           ▼           ▼
              Preventive   Detective   Proactive

                              │
                              ▼
                      ACCOUNT FACTORY
                              │
                              ▼
                     GOVERNED ACCOUNTS
```

We'll cover **landing-zone internals, governed vs registered OUs, enrolled accounts, Audit/Log Archive design, home Region, controls, preventive vs detective vs proactive enforcement, drift, organization trails, Config aggregation, Account Factory, existing Organizations adoption, Control Tower limitations, Terraform integration, and production troubleshooting**.

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html "Policy evaluation logic - AWS Identity and Access Management"
[2]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[3]: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html?utm_source=chatgpt.com "Security best practices in IAM - AWS Identity and Access ..."
[4]: https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot_access-denied.html "Troubleshoot access denied error messages - AWS Identity and Access Management"
[5]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_authorization_policies.html "Authorization policies in AWS Organizations - AWS Organizations"
[6]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic-cross-account.html?utm_source=chatgpt.com "Cross-account policy evaluation logic"
[7]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_evaluation.html "SCP evaluation - AWS Organizations"
[8]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html?utm_source=chatgpt.com "Service control policy examples - AWS Organizations"
[9]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_aws_deny-requested-region.html "AWS: Denies access to AWS based on the requested Region - AWS Identity and Access Management"
[10]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_evaluation.html?utm_source=chatgpt.com "SCP evaluation - AWS Organizations"
[11]: https://docs.aws.amazon.com/managedservices/latest/userguide/scp-library-compliance.html?utm_source=chatgpt.com "Curated SCPs and Config Rules for AMS Advanced."
[12]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html "AWS global condition context keys - AWS Identity and Access Management"
[13]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html "Examples of Amazon S3 bucket policies - Amazon Simple Storage Service"
[14]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[15]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps_evaluation.html "RCP evaluation - AWS Organizations"
[16]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps_syntax.html "RCP syntax - AWS Organizations"
[17]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps_examples.html?utm_source=chatgpt.com "Resource control policy examples - AWS Organizations"
[18]: https://docs.aws.amazon.com/prescriptive-guidance/latest/least-privilege-cloudformation/best-practices-identity-based-policies.html?utm_source=chatgpt.com "Best practices for configuring identity-based policies ..."
[19]: https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot_access-denied.html?utm_source=chatgpt.com "Troubleshoot access denied error messages"
[20]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html?utm_source=chatgpt.com "IAM policy testing with the IAM policy simulator"
[21]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_syntax.html "SCP syntax - AWS Organizations"
