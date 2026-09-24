# AWS Masterclass — Lesson 30 Part 2

# IAM Effective Permissions Deep Dive — SCPs, Permissions Boundaries, Session Policies, RCPs & AccessDenied

Part 1 gave us:

```text
WHO?
WHAT?
WHICH RESOURCE?
UNDER WHAT CONDITIONS?
```

Now we answer the much harder question:

> **“My policy clearly says `Allow`. Why is AWS still returning `AccessDenied`?”**

Because an identity policy is only **one layer** of AWS authorization.

A real enterprise request might pass through:

```text
                    AWS API REQUEST
                          │
                          ▼
                  Identity Policy
                          │
                          ▼
                 Resource Policy
                          │
                          ▼
               Permissions Boundary
                          │
                          ▼
                    Session Policy
                          │
                          ▼
            Organizations SCP Guardrail
                          │
                          ▼
            Organizations RCP Guardrail
                          │
                          ▼
              VPC Endpoint Policy
                          │
                          ▼
                  KMS Key Policy
                          │
                          ▼
                    FINAL RESULT
```

AWS starts from implicit deny, evaluates the policies applicable to the request, and an applicable explicit `Deny` overrides an `Allow`. ([AWS Documentation][1])

---

# 1. The First IAM Formula

Start with:

```text
DEFAULT
=
DENY
```

Then:

```text
Does something allow it?
        │
       YES
        │
        ▼
Maybe allowed
```

But then:

```text
Does ANY applicable policy
explicitly deny it?
        │
       YES
        │
        ▼
       DENY
```

Therefore:

```text
Allow + Allow
=
Allow
```

but:

```text
Allow + Deny
=
DENY
```

And:

```text
No Allow
=
Implicit Deny
```

This remains the core IAM evaluation rule. ([AWS Documentation][2])

---

# 2. Union vs Intersection — The IAM Concept That Changes Everything

Some permission sources combine approximately as a:

# Union

For example, within the same account, ordinary identity-based permissions and resource-based permissions can often contribute permissions together, assuming no explicit deny or other limiting policy interferes. ([AWS Documentation][3])

Think:

```text
Identity Policy

Allow:
s3:GetObject
```

plus:

```text
Bucket Policy

Allow:
s3:PutObject
```

can conceptually result in:

```text
GetObject
+
PutObject
```

under the applicable same-account evaluation rules.

---

# 3. Guardrails Work More Like Intersections

Now introduce:

```text
Permissions Boundary
SCP
Session Policy
RCP
```

These generally **limit** effective permissions.

Think:

```text
Identity policy:
EC2 + S3 + Lambda + IAM
```

Boundary:

```text
EC2 + S3
```

Effective identity permission:

```text
EC2 + S3
```

not:

```text
EC2 + S3 + Lambda + IAM
```

Permissions boundaries define the maximum identity permissions rather than directly granting permissions. ([AWS Documentation][4])

---

# 4. The “Permissions Ceiling” Mental Model

Imagine your identity policy says:

```text
AdministratorAccess
=
*
```

But permissions boundary says:

```text
Allowed ceiling:

EC2
S3
CloudWatch
```

Then:

```text
AdministratorAccess

         ∩

Boundary

         =

EC2
S3
CloudWatch
```

The boundary does not add permission.

It limits what identity policies can effectively provide. ([AWS Documentation][4])

### Never forget

```text
Permissions Boundary
=
MAXIMUM IDENTITY PERMISSIONS
```

---

# 5. Example Permissions Boundary

Developer policy:

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

Boundary:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:*",
    "s3:*",
    "cloudwatch:*"
  ],
  "Resource": "*"
}
```

Developer tries:

```text
ec2:RunInstances
```

Potential:

```text
Allowed
```

Developer tries:

```text
iam:CreateUser
```

The identity policy says yes.

Boundary doesn't allow it.

Result:

```text
DENY
```

because the effective identity permissions are the intersection of the identity policy and boundary. ([AWS Documentation][1])

---

# 6. A Boundary Does NOT Grant Permission

Suppose:

```text
Boundary:
Allow s3:*
```

but user identity policy has:

```text
no S3 Allow
```

Can the user access S3?

```text
NO
```

The boundary only says:

> “S3 is within the maximum permissions this identity could receive.”

An identity policy or other applicable grant still has to provide the actual permission. ([AWS Documentation][5])

Mental model:

```text
Boundary
=
ceiling

Policy
=
actual assigned permissions
```

---

# 7. Why Permissions Boundaries Exist

Suppose your company allows developers to create IAM roles.

Danger:

```text
Developer
   │
   ▼
iam:CreateRole
   │
   ▼
Create AdminRole
   │
   ▼
Attach AdministratorAccess
```

That becomes:

```text
privilege escalation
```

Instead:

```text
Developer-created role
        │
        ▼
must have boundary:
DeveloperBoundary
```

Then even if the developer attaches:

```text
AdministratorAccess
```

the role cannot exceed the boundary.

This is one of the major enterprise use cases for permissions boundaries. AWS describes them as maximum-permission controls for users and roles. ([AWS Documentation][6])

---

# 8. Example Developer Delegation Model

```text
Central Security Team
       │
       ▼
Creates boundary:
WorkloadBoundary
       │
       ▼
Developer
can create workload roles
       │
       ▼
Every workload role
MUST attach WorkloadBoundary
```

Boundary might forbid:

```text
iam:*
organizations:*
account:*
kms:ScheduleKeyDeletion
```

while allowing normal workload services.

Now the developer can manage application permissions without becoming the organization's security administrator.

---

# 9. Boundary Explicit Deny

Boundary can contain:

```json
{
  "Effect": "Deny",
  "Action": "iam:*",
  "Resource": "*"
}
```

Even if identity policy allows:

```json
"Action": "iam:*"
```

result:

```text
DENY
```

An explicit deny in either the identity policy or boundary overrides applicable allows. ([AWS Documentation][1])

---

# 10. Permissions Boundary Does Not Apply Everywhere

Here's where IAM becomes advanced.

Boundaries primarily constrain permissions granted to an IAM user or role through identity-based permissions. Resource-based policies have some important principal-specific evaluation nuances. ([AWS Documentation][4])

Do not simplify IAM to:

```text
boundary ALWAYS limits everything
```

because that is not completely accurate.

---

# 11. Resource Policy Grant to a Role ARN

Suppose S3 bucket policy grants to:

```text
arn:aws:iam::111122223333:role/AppRole
```

Then permissions granted to that role are still subject to implicit limitations from an applicable permissions boundary or session policy. ([AWS Documentation][4])

Conceptually:

```text
Bucket Policy
Allow AppRole
       │
       ▼
Role
       │
       ▼
Boundary still matters
```

---

# 12. Resource Policy Grant Directly to a Role Session ARN

Now suppose a same-account resource policy grants directly to:

```text
arn:aws:sts::111122223333:
assumed-role/AppRole/session123
```

AWS treats that as a grant directly to the role **session**. In that specific same-account case, implicit denies in identity policies, permissions boundaries, and session policies don't limit that direct session grant; explicit denies still remain effective. ([AWS Documentation][4])

This is an advanced edge case.

### Do not use it as a permission-bypass trick.

The important takeaway is:

```text
ROLE ARN
and
ROLE SESSION ARN
can participate differently
in resource-policy evaluation.
```

---

# 13. Why You Must Know the Caller ARN

Run:

```bash
aws sts get-caller-identity
```

You may see:

```text
arn:aws:sts::111122223333:
assumed-role/AppRole/build-123
```

That's the:

```text
ROLE SESSION ARN
```

not:

```text
arn:aws:iam::111122223333:
role/AppRole
```

This distinction can matter for advanced resource-policy evaluation. ([AWS Documentation][2])

---

# 14. Session Policies

Now consider:

```text
IAM Role:
ProductionAdminRole
```

Role identity policy permits:

```text
EC2
S3
RDS
Lambda
CloudWatch
```

But you assume the role while supplying a session policy allowing only:

```text
S3
```

Effective role session:

```text
S3
```

Session policies restrict the resulting temporary session and cannot grant permissions beyond the role's underlying identity-based permissions. ([AWS Documentation][7])

---

# 15. Session Policy Formula

```text
Role Permissions
       ∩
Session Policy
       =
Session Permissions
```

Example:

```text
Role:

EC2
S3
RDS
```

Session:

```text
S3
RDS
```

Effective:

```text
S3
RDS
```

The session policy is a limiter, not an amplifier. ([AWS Documentation][7])

---

# 16. Session Policy Cannot Add Permissions

Role:

```text
s3:GetObject
```

Session policy:

```text
ec2:TerminateInstances
```

Can the session terminate EC2?

```text
NO
```

because:

```text
Role does not grant it.
```

Session policies cannot grant permissions beyond what the assumed role's identity policies provide. ([AWS Documentation][7])

---

# 17. Why Use Session Policies?

Suppose a central role is capable of:

```text
read S3 bucket A

read S3 bucket B

read S3 bucket C
```

But a temporary workflow should access only:

```text
bucket B
```

AssumeRole session policy:

```text
bucket B only
```

Now one reusable role can create narrower temporary sessions.

Session policies are particularly useful when temporary sessions need stricter permissions than the base role. ([AWS Documentation][8])

---

# 18. AssumeRole Supports Session Policies

The `AssumeRole` family of APIs can accept session policy information. AWS supports one inline JSON session policy plus managed policy references according to the STS operation's supported parameters. ([AWS Documentation][9])

Conceptually:

```text
Principal
   │
   ▼
AssumeRole
   │
   ├── Role ARN
   ├── session name
   └── session restrictions
   │
   ▼
Temporary credentials
with reduced permissions
```

---

# 19. Role Session Duration

An IAM role can normally have a configured maximum session duration of up to:

```text
12 hours
```

depending on its `MaxSessionDuration` setting and the role-assumption method. ([AWS Documentation][10])

But there is an extremely important exception:

# Role Chaining

---

# 20. Role Chaining

Suppose:

```text
Human
 │
 ▼
Role A
 │
 ▼
Role B
```

Using credentials from:

```text
Role A
```

to assume:

```text
Role B
```

is:

# role chaining

AWS currently limits a chained role session to a maximum of:

```text
1 hour
```

regardless of Role B's configured maximum session duration. ([AWS Documentation][11])

---

# 21. Role Chaining Example

Role B configuration:

```text
MaxSessionDuration
=
12 hours
```

Direct federation → Role B:

```text
potentially up to configured max
```

But:

```text
Role A
  │
  ▼
AssumeRole Role B
```

Request:

```text
DurationSeconds = 7200
```

Result:

```text
fails
```

because role chaining is capped at one hour. ([AWS Documentation][7])

### Certification rule

```text
ROLE CHAINING
=
MAX 1 HOUR
```

---

# 22. AWS Organizations SCPs

Now we move above the account.

Suppose:

```text
AWS Organization
```

contains:

```text
Management Account

Security OU

Production OU
  ├── Prod-App
  └── Prod-Data

Development OU
  ├── Dev-A
  └── Dev-B
```

AWS Organizations lets you apply:

# Service Control Policies

to:

```text
Organization Root
OU
Account
```

SCPs set maximum permissions available to identities in affected **member accounts**. They do not themselves grant permissions. ([AWS Documentation][12])

---

# 23. SCP Mental Model

Think:

```text
ORGANIZATION SECURITY CEILING
```

Example:

```text
Production OU SCP

Deny:
iam:CreateUser

Deny:
organizations:LeaveOrganization

Deny:
cloudtrail:StopLogging
```

Even if a production-account administrator attaches:

```text
AdministratorAccess
```

to themselves:

```text
SCP deny
wins.
```

AWS explicitly notes that an SCP restriction can prevent an action even when `AdministratorAccess` is attached. ([AWS Documentation][13])

---

# 24. SCP Does NOT Grant Permission

Suppose SCP says:

```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}
```

IAM role has:

```text
no S3 permissions
```

Can it read S3?

```text
NO
```

SCPs establish permission guardrails; the IAM user/role still needs actual permission from identity/resource policies. ([AWS Documentation][12])

---

# 25. SCP Formula

Simplified:

```text
Identity Permissions

        ∩

Permissions Boundary

        ∩

Applicable SCP permissions

        =

Effective identity permissions
```

assuming no other policy layers affect the request. AWS documents that when these three are present, the action must survive all three policy types. ([AWS Documentation][13])

---

# 26. SCP Inheritance

Suppose:

```text
Organization Root
    │
    ▼
Production OU
    │
    ▼
Payments OU
    │
    ▼
Payments Account
```

Restrictions can be inherited through the hierarchy.

AWS states that the member account has only permissions permitted by every parent above it under the applicable SCP strategy. ([AWS Documentation][13])

Conceptually:

```text
Root
 ∩
Prod OU
 ∩
Payments OU
 ∩
Account
```

---

# 27. Deny-List SCP Strategy

Default organizations commonly begin with:

```text
FullAWSAccess
```

and add explicit-deny SCPs.

Example:

```json
{
  "Effect": "Deny",
  "Action": [
    "organizations:LeaveOrganization"
  ],
  "Resource": "*"
}
```

Everything else continues through the SCP layer unless restricted elsewhere.

AWS describes SCPs as coarse-grained guardrails and provides deny-list patterns as common examples. ([AWS Documentation][14])

---

# 28. Allow-List SCP Strategy

More restrictive design:

```text
Only explicitly approved services
survive the SCP layer.
```

Conceptually:

```text
Allow:
EC2
S3
CloudWatch
```

Everything not admitted by the applicable SCP hierarchy becomes unavailable even if IAM says:

```text
AdministratorAccess
```

AWS Organizations supports allow-list and deny-list SCP strategies. ([AWS Documentation][13])

---

# 29. SCP Does Affect Member-Account Root

This surprises many people.

In an Organizations **member account**, SCPs apply to the account's root user too. ([AWS Documentation][13])

So:

```text
Member account root
```

does not necessarily mean:

```text
SCP bypass.
```

This is a major reason Organizations is useful for enterprise guardrails.

---

# 30. SCP Does NOT Affect Management Account Principals

SCPs do **not** restrict users or roles in the Organizations:

```text
Management Account
```

They apply to member accounts. ([AWS Documentation][12])

This is one reason AWS recommends heavily protecting the management account and minimizing workloads there.

---

# 31. Delegated Administrator Is Still Affected

Suppose:

```text
Security Account
```

is designated as an Organizations delegated administrator.

It remains a:

```text
member account
```

so SCPs can still apply to it. ([AWS Documentation][12])

Delegated administrator:

```text
≠ management account
```

---

# 32. Service-Linked Roles and SCPs

Another important exception:

AWS Organizations states that SCPs do **not** restrict permissions attached to service-linked roles. ([AWS Documentation][13])

A service-linked role is a special role created for an AWS service to perform actions on your behalf.

Think:

```text
Normal IAM Role
→ SCP applies

Service-Linked Role
→ SCP exception
```

for the service-linked-role permissions described by AWS.

---

# 33. Why Service-Linked Role Exception Exists

Imagine AWS service:

```text
Auto Scaling
```

requires its AWS-managed service-linked role to perform necessary infrastructure operations.

If your SCP could arbitrarily remove required permissions from that service-linked role:

```text
AWS managed service
could become internally unusable.
```

AWS therefore excludes service-linked role permissions from SCP restriction. ([AWS Documentation][13])

---

# 34. Permissions Boundary Cannot Be Applied to Service-Linked Role

AWS also documents that you cannot apply an IAM permissions boundary to a service-linked role. ([AWS Documentation][6])

So:

```text
Service-linked roles
```

are intentionally special identities.

Do not treat them exactly like workload-created application roles.

---

# 35. SCP Example — Protect CloudTrail

Conceptual production guardrail:

```json
{
  "Effect": "Deny",
  "Action": [
    "cloudtrail:StopLogging",
    "cloudtrail:DeleteTrail"
  ],
  "Resource": "*"
}
```

Even a local account admin cannot bypass that with an IAM allow while the SCP applies.

This is the type of centrally enforced security control SCPs are designed to provide. ([AWS Documentation][15])

---

# 36. SCP Example — Restrict Regions

A common pattern is:

```text
Approved:

ap-south-1
us-east-1
```

Deny operations elsewhere, often using:

```text
aws:RequestedRegion
```

with carefully chosen exceptions for global-service APIs.

This can become powerful—but a badly designed Region-deny SCP can break global services. AWS recommends testing SCPs carefully before broad deployment. ([AWS Documentation][14])

---

# 37. Never Deploy Untested SCP at Root

AWS recommends testing SCP effects in narrower test accounts/OUs before moving policies upward toward broad organizational scope. ([AWS Documentation][14])

Good rollout:

```text
Test Account
    │
    ▼
Test OU
    │
    ▼
Small production OU
    │
    ▼
Wider OU
```

Bad:

```text
write SCP
   │
   ▼
attach to organization root
immediately
```

An SCP mistake can break every member account under that hierarchy.

---

# 38. Resource Control Policies — RCPs

Now the modern Organizations counterpart to SCPs:

# Resource Control Policies

SCP asks:

```text
What may identities
in these member accounts do?
```

RCP asks:

```text
What actions/principals
may be permitted against
resources in these member accounts?
```

RCPs provide centralized maximum-permission guardrails for supported resources and do not grant permission themselves. ([AWS Documentation][16])

---

# 39. SCP vs RCP

Burn this into memory:

```text
SCP
=
IDENTITY-SIDE organizational guardrail
```

```text
RCP
=
RESOURCE-SIDE organizational guardrail
```

Conceptually:

```text
Principal
   │
   │ SCP
   ▼
AWS request
   │
   │ RCP
   ▼
Resource
```

RCPs complement SCPs by centrally governing access to supported resources. ([AWS Documentation][17])

---

# 40. Why RCPs Matter

Imagine S3 bucket in Production:

```text
prod-sensitive-data
```

A developer accidentally writes bucket policy:

```json
{
  "Effect": "Allow",
  "Principal": "*",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::prod-sensitive-data/*"
}
```

With a suitable RCP, your organization can establish a higher-level resource guardrail limiting which principals may be permitted to access protected resources.

RCPs are specifically intended as organization-scale preventative controls on resources. ([AWS Documentation][18])

---

# 41. RCP Does NOT Grant Access

Just like SCP:

```text
RCP = guardrail
```

not:

```text
RCP = permission grant
```

You still need:

```text
identity policy
and/or
resource policy
```

to actually authorize the operation. ([AWS Documentation][19])

---

# 42. RCP Applies Even to External Principals Accessing Your Resource

This is one of the strongest RCP capabilities.

Suppose:

```text
Account A
inside your organization

owns S3 bucket
```

and:

```text
Account B
outside your organization
```

tries accessing that bucket.

An applicable RCP on the resource-owning account can still restrict access to that resource even though the caller is external. ([AWS Documentation][19])

That makes RCP strongly:

```text
RESOURCE CENTRIC
```

---

# 43. RCPs Apply Only to Supported Services/Resources

As of the current documentation, RCP coverage applies to a subset of AWS services. That current list includes services such as S3, KMS, DynamoDB, ECR, SQS, CloudWatch Logs, EventBridge, Secrets Manager, STS, CloudFront and others; AWS can expand the set over time. ([AWS Documentation][19])

Therefore never assume:

```text
RCP supports every AWS service
```

without checking the current Organizations documentation.

---

# 44. RCP Does Not Apply to Management-Account Resources

Like SCP's management-account exception for principals, RCPs do not affect resources owned by the Organizations management account. ([AWS Documentation][19])

Again:

```text
Management Account
=
special trust boundary
```

Protect it heavily.

---

# 45. RCPs Affect Member Account Root Access to Resources

An applicable RCP can affect principals, including root users, accessing resources in member accounts, subject to documented exceptions. ([AWS Documentation][19])

So even:

```text
root
```

does not automatically defeat an RCP on a member-account resource.

---

# 46. Service-Linked Roles and RCPs

RCPs do not restrict calls made using service-linked roles. ([AWS Documentation][16])

So both:

```text
SCP
```

and:

```text
RCP
```

have important service-linked-role exceptions.

---

# 47. Modern Enterprise Authorization Map

You can now imagine:

```text
                     ORGANIZATION
                          │
             ┌────────────┴────────────┐
             ▼                         ▼
            SCP                       RCP
     identity guardrail        resource guardrail
             │                         │
             └────────────┬────────────┘
                          ▼
                     AWS REQUEST
                          │
             ┌────────────┴────────────┐
             ▼                         ▼
       identity policies         resource policies
             │                         │
             ▼                         ▼
        boundaries               bucket/key/etc.
             │
             ▼
       session policies
```

This is much closer to real enterprise IAM.

---

# 48. Session Policy + Boundary + SCP

Suppose role policy allows:

```text
EC2
S3
RDS
Lambda
```

Boundary allows:

```text
EC2
S3
RDS
```

SCP allows:

```text
EC2
S3
```

Session policy permits:

```text
S3 only
```

Effective:

```text
S3
```

Think:

```text
Role
 ∩ Boundary
 ∩ SCP
 ∩ Session
 =
S3
```

AWS documents this intersection model for limiting policies. ([AWS Documentation][4])

---

# 49. Now Add an Explicit Deny

Suppose resource policy contains:

```text
Deny s3:GetObject
```

for your current context.

Then:

```text
Effective S3 permission
=
DENY
```

No number of allows overrides the applicable explicit deny. ([AWS Documentation][2])

---

# 50. `NotAction`

Normal:

```json
"Action": [
  "s3:GetObject",
  "s3:PutObject"
]
```

means:

```text
these actions
```

`NotAction` means:

```text
all applicable actions
EXCEPT the listed actions
```

within the statement's scope. ([AWS Documentation][20])

This is extremely powerful.

And extremely easy to misuse.

---

# 51. `Deny + NotAction`

Suppose:

```json
{
  "Effect": "Deny",
  "NotAction": [
    "iam:*"
  ],
  "Resource": "*"
}
```

Conceptually:

```text
DENY everything
except IAM actions
```

This does **not** automatically grant IAM permission.

It merely says IAM actions are excluded from this specific deny. They still need an applicable allow elsewhere. ([AWS Documentation][20])

### Never forget

```text
NotAction in Deny
≠
Allow the excluded action
```

---

# 52. Classic MFA Pattern With `NotAction`

You may see policies conceptually like:

```text
Deny most APIs
unless MFA authenticated

except APIs required
to obtain/configure MFA
```

`NotAction` can make such policies much shorter.

But because the scope becomes broad, one mistake can accidentally deny a huge portion of AWS.

Use it only when you fully understand the policy universe.

---

# 53. `NotResource`

Normal:

```json
"Resource": "arn:aws:s3:::prod/*"
```

means:

```text
this resource
```

`NotResource` means:

```text
every applicable resource
EXCEPT those listed
```

AWS warns that `NotResource`, especially with `Allow`, can unintentionally grant far broader permissions than intended. ([AWS Documentation][21])

---

# 54. `Deny + NotResource` Example

Requirement:

> Users may work in S3 but must never interact with objects outside approved bucket.

Conceptual statement:

```json
{
  "Effect": "Deny",
  "Action": "s3:*",
  "NotResource": [
    "arn:aws:s3:::approved",
    "arn:aws:s3:::approved/*"
  ]
}
```

Meaning:

```text
Deny S3 operations
on everything EXCEPT
approved bucket/resources.
```

Again, excluded resources still need actual allows elsewhere. `NotResource` does not create permission by itself. ([AWS Documentation][21])

---

# 55. Why `Allow + NotResource` Is Dangerous

Example:

```json
{
  "Effect": "Allow",
  "Action": "*",
  "NotResource": "arn:aws:s3:::secret/*"
}
```

This can effectively authorize an enormous universe of actions/resources outside that excluded target, subject to other applicable controls.

AWS explicitly warns that `NotResource` with `Effect: Allow` can grant much more than intended. ([AWS Documentation][21])

Production rule:

```text
Treat:

Allow + NotResource

as a security-sensitive construct.
```

---

# 56. VPC Endpoint Policies

Suppose your EC2 accesses S3 through:

```text
S3 Gateway VPC Endpoint
```

The endpoint can have a policy.

Architecture:

```text
EC2
 │
 ▼
S3 VPC Endpoint
 │
 │ Endpoint Policy
 ▼
S3
```

AWS endpoint policies use IAM policy syntax and act as an additional control on requests that traverse that endpoint. ([AWS Documentation][22])

---

# 57. VPC Endpoint Policy Does NOT Grant IAM Permission

This is essential.

Endpoint policy:

```text
Allow s3:GetObject
```

Role policy:

```text
No s3:GetObject
```

Does the endpoint policy give the EC2 role S3 permission?

```text
NO
```

VPC endpoint policies are additional boundaries; the caller's actual permissions must also allow the request. ([AWS Documentation][23])

Mental model:

```text
IAM says:
"May this principal do this?"

Endpoint policy says:
"May this request pass through THIS endpoint?"
```

---

# 58. Default Endpoint Policy

For services supporting endpoint policies, an endpoint can use a default full-access endpoint policy if you don't attach a custom restriction. ([AWS Documentation][22])

But:

```text
Full endpoint policy
```

does not mean:

```text
all EC2 instances suddenly have full service permissions.
```

Normal IAM/resource policies still apply.

---

# 59. Example Endpoint Restriction

Suppose S3 endpoint should reach only:

```text
prod-artifacts
```

Endpoint policy:

```text
Allow requests only to prod-artifacts
```

Role may have permission to:

```text
prod-artifacts
and
another-bucket
```

But when traffic uses that endpoint:

```text
another-bucket
```

can be blocked by the endpoint policy.

This is defense-in-depth.

---

# 60. Bucket Policy Can Also Restrict VPC Endpoint

S3 bucket policy can use conditions such as the VPC endpoint identity to restrict access to requests arriving through approved endpoints. AWS documents this as an S3 private-access control technique. ([AWS Documentation][24])

Now there can be:

```text
Identity Policy
      │
      ▼
Endpoint Policy
      │
      ▼
Bucket Policy
      │
      ▼
S3
```

All need to be considered during troubleshooting.

---

# 61. KMS Changes the Authorization Story Again

Suppose:

```text
S3 object
encrypted with
SSE-KMS
```

Your IAM role has:

```text
s3:GetObject
```

but no working KMS permission.

What happens?

```text
Access denied / decryption failure
```

because reading the object requires both:

```text
S3 authorization
```

and:

```text
KMS authorization
```

for the relevant key operation. AWS KMS authorization includes key policies, IAM policies where enabled, and grants. ([AWS Documentation][25])

---

# 62. KMS Key Policy Is Fundamental

Every KMS key has a:

# Key Policy

AWS states that IAM policy allows on a KMS key are ineffective unless the key policy permits IAM-based delegation or otherwise grants the required access. ([AWS Documentation][26])

This is why:

```text
IAM:
Allow kms:Decrypt
```

doesn't automatically mean:

```text
Decrypt succeeds.
```

---

# 63. KMS Same-Account Mental Model

Typical default key-policy model:

```text
KMS Key Policy
     │
     ▼
allows account
to delegate access through IAM
     │
     ▼
IAM Role Policy
allows kms:Decrypt
     │
     ▼
Role can decrypt
```

If the key policy doesn't permit the delegation/access model:

```text
IAM allow alone
may have no effect.
```

([AWS Documentation][27])

---

# 64. KMS Cross-Account Is Even Stricter

Suppose:

```text
Account A role
```

needs KMS key in:

```text
Account B
```

AWS KMS cross-account authorization generally needs:

```text
Key policy in Account B
+
IAM permission in Account A
```

Neither alone is sufficient for the external principal's use of the key. ([AWS Documentation][28])

Mental model:

```text
KEY OWNER
must trust

AND

CALLER ACCOUNT
must delegate
```

---

# 65. Full SSE-KMS Read Chain

```text
Application
    │
    ▼
s3:GetObject
    │
    ▼
S3 authorization
    │
    ▼
Object encrypted?
    │
    ▼
KMS Decrypt
    │
    ▼
KMS authorization
    │
    ▼
key policy / IAM / grant / guardrails
    │
    ▼
plaintext object
```

Troubleshoot every layer.

---

# 66. AdministratorAccess Still May Fail KMS

Even a role with broad IAM `AdministratorAccess` can encounter KMS denial if the KMS key authorization model doesn't allow the operation, or if an SCP/RCP/boundary/etc. restricts it. ([AWS Documentation][25])

That's one of the most common reasons people say:

> “But I'm admin!”

IAM administration does not magically rewrite every KMS key policy.

---

# 67. SCP + KMS

Suppose:

```text
IAM Policy:
Allow kms:Decrypt
```

```text
KMS key policy:
allows role/account
```

but:

```text
SCP:
Deny kms:Decrypt
```

Result:

```text
DENY
```

The explicit organization-level deny wins. ([AWS Documentation][2])

---

# 68. RCP + KMS

Current RCP support includes AWS KMS resources, subject to documented RCP exceptions. ([AWS Documentation][19])

This enables organization-level resource-side restrictions around KMS keys.

So modern KMS troubleshooting can involve:

```text
IAM policy
key policy
grants
permissions boundary
SCP
RCP
VPC endpoint policy
```

That's why KMS permissions often feel harder than normal IAM.

---

# 69. IAM Effective Permissions — Full Mental Model

```text
                    REQUEST
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
                Resource Policy
                       │
                       ▼
                    RCP
                       │
                       ▼
             VPC Endpoint Policy
                       │
                       ▼
              KMS Key Policy
                       │
                       ▼
              Any explicit Deny?
                │             │
               YES           NO
                │             │
                ▼             ▼
               DENY       Is required
                          permission allowed?
                             │      │
                            YES     NO
                             │      │
                             ▼      ▼
                           ALLOW   DENY
```

Not every request uses every box.

The skill is determining **which boxes apply**.

---

# 70. Real Example — EC2 Describe Error

Terraform reports:

```text
UnauthorizedOperation:

ec2:DescribeSecurityGroups
```

First:

```bash
aws sts get-caller-identity
```

Suppose:

```text
TerraformRole
```

Identity policy:

```text
Allow ec2:*
```

Yet denied.

Now inspect:

```text
Boundary?
SCP?
Session policy?
```

If SCP contains:

```text
Deny ec2:DescribeSecurityGroups
```

then:

```text
identity Allow
+
SCP Deny
=
DENY
```

Attaching another IAM policy will not fix it. ([AWS Documentation][13])

---

# 71. Real Example — ECR CreateRepository

Error:

```text
not authorized to perform:

ecr:CreateRepository
```

Debug:

```text
1. get-caller-identity

2. Does identity policy allow
   ecr:CreateRepository?

3. Does boundary permit ECR?

4. Does SCP allow ECR?

5. Is request using session restriction?

6. Are conditions correct?
```

If IAM has:

```text
ecr:GetAuthorizationToken
ecr:PutImage
```

but not:

```text
ecr:CreateRepository
```

that's simply:

```text
implicit deny.
```

No organization mystery is required.

---

# 72. Real Example — S3 AccessDenied

Application role:

```text
s3:GetObject
```

Object:

```text
s3://prod-secret/config.json
```

Potential blockers:

```text
Identity policy

permissions boundary

session policy

SCP

RCP

bucket policy

VPC endpoint policy

KMS key policy
```

if encrypted with KMS.

This is why S3 `AccessDenied` debugging must be layered rather than random. ([AWS Documentation][2])

---

# 73. Real Example — Role Is Admin but Can't Create IAM User

Role:

```text
AdministratorAccess
```

Boundary:

```text
Allow EC2/S3 only
```

Result:

```text
iam:CreateUser
=
DENIED
```

The boundary limits effective identity permissions to its ceiling. ([AWS Documentation][4])

---

# 74. Real Example — Admin Role Can't Launch in Region

Identity:

```text
AdministratorAccess
```

SCP:

```text
Deny outside ap-south-1
```

Request:

```text
ec2:RunInstances
in us-west-2
```

Result:

```text
DENY
```

Because an applicable SCP deny overrides the identity allow. ([AWS Documentation][13])

---

# 75. Real Example — Session Is More Restricted Than Role

Role normally allows:

```text
S3
EC2
RDS
```

Automation assumes it with session policy:

```text
S3 only
```

Then runs:

```text
ec2:DescribeInstances
```

Result:

```text
DENY
```

because session permissions are the intersection of the role identity permissions and session policy. ([AWS Documentation][7])

---

# 76. Real Example — S3 Through Endpoint

Role allows:

```text
s3:GetObject
on Bucket A and Bucket B
```

VPC endpoint policy allows:

```text
Bucket A only
```

Request through endpoint to:

```text
Bucket B
```

Result:

```text
DENY
```

Endpoint policy is an additional boundary on requests traversing that endpoint. ([AWS Documentation][23])

---

# 77. Real Example — KMS Cross-Account

Role in Account A:

```text
Allow kms:Decrypt
for key in Account B
```

But Account B KMS key policy does not trust Account A.

Result:

```text
DENY
```

For cross-account KMS use, both the owning key policy and caller-account IAM delegation are required. ([AWS Documentation][28])

---

# 78. AccessDenied Messages Are Getting Better

AWS can include denial context such as:

```text
with an explicit deny
in a permissions boundary
```

or references to applicable policy types in certain AccessDenied responses. AWS's IAM troubleshooting documentation provides examples of policy-type-specific denial messages. ([AWS Documentation][29])

Always read the full error.

Not just:

```text
AccessDenied
```

---

# 79. Encoded Authorization Failure Messages

Certain AWS services, notably EC2 workflows, may provide:

```text
Encoded authorization failure message
```

Use:

```bash
aws sts decode-authorization-message \
  --encoded-message '...'
```

if your principal has:

```text
sts:DecodeAuthorizationMessage
```

This can provide detailed authorization context and is far better than guessing.

---

# 80. Policy Simulator

AWS IAM Policy Simulator can help test:

```text
identity-based policies

permissions boundaries
```

and evaluate how specific actions/resources/context values might resolve. ([AWS Documentation][30])

Use cases:

```text
Would DevOpsRole
allow s3:GetObject?

Would boundary block iam:CreateRole?

Would this Condition match?
```

---

# 81. Policy Simulator Is Not the Entire Universe

Do not assume:

```text
Simulator says Allowed
=
production request definitely succeeds
```

because real authorization may also involve:

```text
SCP
RCP
resource-specific service rules
VPC endpoint policies
KMS authorization
external account policy
```

and other contextual factors.

AWS's simulator documentation itself focuses on specific supported policy types and contexts. ([AWS Documentation][30])

Treat it as:

```text
diagnostic tool
```

not:

```text
absolute proof of every real-world policy layer.
```

---

# 82. Service Authorization Reference — Essential IAM Tool

When writing least privilege, look up:

```text
Action

Resource types

Required dependent actions

Condition keys
```

for each AWS API.

AWS's Service Authorization Reference explicitly tells you whether an action supports resource-level permissions; when the resource-type column is empty, the action requires:

```json
"Resource": "*"
```

([AWS Documentation][31])

This explains many:

```text
Why can't I scope Describe* to one ARN?
```

questions.

---

# 83. IAM Action May Need Dependent Permissions

Some operations internally require related permissions.

Example pattern:

```text
Create resource
```

may also require:

```text
PassRole

CreateTags

DescribeSomething
```

depending on the AWS service and API.

Always inspect the service authorization documentation and exact AccessDenied call sequence instead of assuming one obvious action is enough. ([AWS Documentation][31])

---

# 84. Service-Linked Roles

A service-linked role is a special IAM role linked directly to an AWS service and containing permissions required for that service to perform actions on your behalf. ([AWS Documentation][16])

Example conceptual roles:

```text
Auto Scaling service-linked role

Organizations service-linked role

Cost Optimization service-linked role
```

You typically don't redesign their policies the same way as application roles.

---

# 85. Service Role vs Service-Linked Role

### Service role

You create/configure:

```text
LambdaExecutionRole

ECSTaskExecutionRole

CustomCodeBuildRole
```

### Service-linked role

Defined specifically for:

```text
AWS service integration
```

and managed according to that service's service-linked role contract.

Remember:

```text
service role
≠
service-linked role
```

---

# 86. Terraform Permissions Boundary Pattern

Example:

```hcl
resource "aws_iam_policy" "workload_boundary" {
  name = "WorkloadBoundary"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:*",
          "dynamodb:*",
          "logs:*",
          "cloudwatch:*"
        ]

        Resource = "*"
      }
    ]
  })
}
```

Then role:

```hcl
resource "aws_iam_role" "app" {
  name = "production-app-role"

  assume_role_policy =
    data.aws_iam_policy_document.ec2_assume.json

  permissions_boundary =
    aws_iam_policy.workload_boundary.arn
}
```

Now attached identity permissions cannot expand the role beyond the boundary's effective ceiling. ([AWS Documentation][6])

---

# 87. Terraform Does Not Magically Bypass Organization Guardrails

Terraform role:

```text
AdministratorAccess
```

Terraform tries:

```text
Create VPC
```

SCP denies:

```text
ec2:CreateVpc
```

Terraform gets:

```text
AccessDenied
```

Terraform isn't special.

It's just another principal making AWS API calls.

---

# 88. Terraform Role Design

A mature Terraform execution role might have:

```text
Identity Policy
    │
    ▼
Required infrastructure APIs

Boundary
    │
    ▼
Maximum allowed domains/services

SCP
    │
    ▼
Organization controls

Session
    │
    ▼
Pipeline-specific restriction
```

Then:

```text
CloudTrail
```

records the resulting AWS API activity.

That is enterprise IaC security.

---

# 89. Protecting IAM With a Boundary

Developer permission:

```text
iam:CreateRole
iam:AttachRolePolicy
```

can be dangerous without constraints.

Production pattern:

```text
Developer may create roles

BUT

roles must have:
arn:aws:iam::<account>:policy/WorkloadBoundary
```

combined with policy conditions and protections preventing them from modifying/removing the boundary.

We'll go deeper into privilege escalation and `iam:PassRole` in the next IAM part.

---

# 90. Why Boundary Alone Is Not Enough

If developer can:

```text
delete boundary policy

change boundary policy

create another unrestricted role

pass powerful existing role to EC2/Lambda
```

the security model may fail.

So permission delegation requires controlling:

```text
CreateRole

PutRolePermissionsBoundary

DeleteRolePermissionsBoundary

AttachRolePolicy

PutRolePolicy

PassRole

policy version management
```

This is why IAM delegation is an architecture problem, not a single JSON document.

---

# 91. `iam:PassRole` Preview

Suppose developer cannot:

```text
AssumeRole AdminRole
```

but can:

```text
iam:PassRole AdminRole
```

to:

```text
Lambda
```

and can create Lambda code.

Potential:

```text
Developer
   │
   ▼
Create Lambda
   │
   ▼
Pass AdminRole
   │
   ▼
Lambda runs with AdminRole
   │
   ▼
privilege escalation
```

This is one of the most important IAM security concepts and deserves its own deep section in Part 3.

---

# 92. Cross-Account Effective Permission

Suppose:

```text
Account A principal
         │
         ▼
Account B resource
```

Cross-account authorization requires the request to survive policy evaluation in both the caller/trusted side and resource-owning/trusting side. AWS permits the operation only when both account evaluations authorize it. ([AWS Documentation][32])

Mental model:

```text
Account A
Can caller make request?
     │
     ▼
AND
     │
     ▼
Account B
Does resource/account accept caller?
```

---

# 93. Example Cross-Account S3

Account A role identity policy:

```text
Allow s3:GetObject
Bucket B
```

Account B bucket policy:

```text
Allow Account A role
```

Then request may succeed if no boundary/SCP/RCP/etc. denies it.

If either side lacks the appropriate authorization:

```text
DENY
```

([AWS Documentation][3])

---

# 94. Cross-Account RCP Adds Another Resource Guardrail

Now Account B is in an Organization with RCP:

```text
Deny access
unless principal belongs
to approved organization
```

Even if Bucket B policy mistakenly trusts some external party:

```text
RCP can prevent the resource
from accepting that access.
```

This illustrates why RCPs are powerful protection against overly permissive resource policies. ([AWS Documentation][19])

---

# 95. “AdministratorAccess” Mental Correction

Never think:

```text
AdministratorAccess
=
god mode
```

Think:

```text
AdministratorAccess
=
very broad identity-based Allow
```

which can still be constrained by:

```text
SCP

permissions boundary

session policy

RCP

resource explicit deny

VPC endpoint policy

KMS key policy

cross-account authorization
```

depending on the request. ([AWS Documentation][2])

This is the correct enterprise mental model.

---

# 96. SAA-C03 Scenario

> Developer has `AdministratorAccess` but can't launch EC2 in `eu-west-1`. Company allows workloads only in Mumbai.

Think:

```text
Organizations SCP
```

using appropriate Region restrictions.

SCP can deny actions despite local IAM AdministratorAccess. ([AWS Documentation][13])

---

# 97. Scenario

> Developers are allowed to create IAM roles but must never create roles with permissions beyond a predefined workload permission set.

Think:

```text
Permissions Boundary
```

plus IAM policies requiring that boundary on role creation and protecting the boundary itself. Boundaries provide the maximum-permissions mechanism required for this design. ([AWS Documentation][6])

---

# 98. Scenario

> One AssumeRole session must have less permission than the normal role.

Think:

```text
Session Policy
```

because session policies reduce permissions for an individual temporary role session. ([AWS Documentation][8])

---

# 99. Scenario

> Organization wants to prevent its S3 resources from being shared outside approved principals even if someone creates a permissive bucket policy.

Strong modern candidate:

```text
Resource Control Policy
```

for supported resources/services, combined with normal S3 controls. RCPs are designed as centralized resource-side preventive guardrails. ([AWS Documentation][18])

---

# 100. Scenario

> Role has S3 permission, bucket policy permits it, but request through the private S3 endpoint is denied.

Inspect:

```text
VPC Endpoint Policy
```

because the endpoint policy acts as another authorization boundary for requests traversing that endpoint. ([AWS Documentation][23])

---

# 101. Scenario

> Role has `s3:GetObject` but cannot retrieve SSE-KMS-encrypted object.

Inspect:

```text
kms:Decrypt

KMS key policy

IAM policy

SCP/RCP/boundary

endpoint policy
```

as applicable.

S3 object authorization and KMS key authorization are separate requirements. ([AWS Documentation][25])

---

# 102. Scenario

> Role has maximum session duration of 12 hours, but a second `AssumeRole` call fails when requesting two hours.

Think:

```text
ROLE CHAINING
```

Chained role sessions are currently capped at one hour. ([AWS Documentation][7])

---

# 103. Scenario

> SCP has `Allow s3:*`. User has no IAM policies. Why doesn't S3 work?

Because:

```text
SCP does not grant permission.
```

It only defines the Organizations-level maximum/guardrail.

You still need an actual identity/resource permission grant. ([AWS Documentation][12])

---

# 104. Scenario

> Boundary has `Allow ec2:*`; role has no EC2 permission. Can it launch EC2?

```text
NO
```

Same reason:

```text
Boundary
does not grant.
```

It only defines maximum identity permission. ([AWS Documentation][5])

---

# 105. Scenario

> Endpoint policy says `Allow s3:*`, but IAM role has no S3 permission.

```text
DENY
```

Endpoint policies don't grant service permissions on their own. ([AWS Documentation][23])

Notice a pattern emerging.

---

# 106. The Three “Does Not Grant” Rules

Burn these in:

```text
SCP
does NOT grant permission
```

```text
Permissions Boundary
does NOT grant permission
```

```text
VPC Endpoint Policy
does NOT grant the caller's service permission
```

And similarly:

```text
RCP
does NOT grant permission
```

They're constraints/guardrails. ([AWS Documentation][12])

---

# 107. AccessDenied Production Runbook

When you encounter:

```text
ACCESS DENIED
```

use this sequence.

### Step 1

```bash
aws sts get-caller-identity
```

Determine:

```text
Account
Role/User
Assumed session
```

### Step 2

Read exact:

```text
Action
Resource
Region
Context
```

### Step 3

Find actual grant:

```text
Identity Policy?
Resource Policy?
```

### Step 4

Check limits:

```text
Permissions Boundary?
Session Policy?
SCP?
```

### Step 5

Check resource controls:

```text
Resource Policy?
RCP?
```

### Step 6

Check path controls:

```text
VPC Endpoint Policy?
```

### Step 7

Check service-specific controls:

```text
KMS Key Policy?
```

### Step 8

Search:

```text
explicit deny?
condition mismatch?
wrong ARN?
```

### Step 9

Use:

```text
CloudTrail
Policy Simulator
DecodeAuthorizationMessage
```

when useful.

This layered process mirrors AWS's policy evaluation model. ([AWS Documentation][2])

---

# 108. Never-Forget IAM Effective Permissions Diagram

```text
                    WHAT CAN I REALLY DO?
                              │
                              ▼
                       Identity Policy
                              │
                              ▼
                     Resource Policies
                              │
                              ▼
                  Permissions Boundary
                              │
                              ▼
                       Session Policy
                              │
                              ▼
                       Organizations
                    ┌─────────┴──────────┐
                    ▼                    ▼
                   SCP                  RCP
                    │                    │
                    └─────────┬──────────┘
                              ▼
                     Endpoint Policy
                              │
                              ▼
                       KMS / Service
                     Specific Policies
                              │
                              ▼
                       EXPLICIT DENY?
                        │           │
                       YES         NO
                        │           │
                        ▼           ▼
                      DENY      Valid Allow?
                                  │      │
                                 YES     NO
                                  │      │
                                  ▼      ▼
                                ALLOW   DENY
```

---

# 109. The 30 Rules to Burn Into Memory

```text
1. AWS starts from implicit deny.

2. An applicable explicit deny beats every allow.

3. Identity policies normally grant permissions.

4. Resource policies can grant permissions to principals.

5. Permissions boundaries do not grant permission.

6. A permissions boundary defines a maximum
   for identity permissions.

7. Identity permissions and boundaries intersect.

8. Session policies restrict temporary sessions.

9. Session policies cannot add permissions
   beyond the base role.

10. Role chaining is limited to one-hour sessions.

11. SCPs are Organizations identity-side guardrails.

12. SCPs do not grant permission.

13. SCPs apply to member accounts.

14. SCPs can restrict member-account root users.

15. SCPs don't restrict management-account principals.

16. SCPs don't restrict service-linked-role permissions.

17. RCPs are organization-level resource guardrails.

18. RCPs do not grant permission.

19. RCPs can protect supported resources
    even from external callers.

20. RCPs do not apply to management-account resources.

21. Resource policies and identity policies can combine,
    subject to other limiting policy layers.

22. Role ARN and role-session ARN can have
    different resource-policy evaluation behavior.

23. VPC endpoint policies are additional boundaries.

24. Endpoint policies do not create caller IAM permission.

25. KMS key policies are fundamental to KMS authorization.

26. Cross-account KMS normally needs permission
    on both key-owner and caller sides.

27. NotAction means all applicable actions
    except those listed.

28. NotResource means all applicable resources
    except those listed.

29. Allow + NotResource is especially dangerous
    if misunderstood.

30. AdministratorAccess is not immunity
    from higher-level guardrails.
```

And the most important rule from this lesson:

```text
"I HAVE AN ALLOW"

does NOT answer:

"AM I AUTHORIZED?"
```

The correct question is:

```text
What is my EFFECTIVE permission
after EVERY applicable layer
has been evaluated?
```

---

# ✅ Lesson 30 Part 2 Complete

You now understand:

```text
✓ effective permissions
✓ union vs intersection
✓ explicit deny
✓ implicit deny

✓ permissions boundaries
✓ boundaries as ceilings
✓ delegated role creation
✓ boundary limitations
✓ role ARN vs session ARN nuance

✓ session policies
✓ AssumeRole session restrictions
✓ role chaining
✓ one-hour chaining limit

✓ AWS Organizations SCPs
✓ SCP inheritance
✓ allow-list SCPs
✓ deny-list SCPs
✓ member-account root behavior
✓ management-account exception
✓ service-linked-role exception

✓ Resource Control Policies
✓ RCP mental model
✓ RCP vs SCP
✓ resource-side organizational guardrails
✓ external-principal protection
✓ current supported-service limitation

✓ NotAction
✓ NotResource

✓ VPC endpoint policies
✓ endpoint policy vs IAM permission

✓ KMS key policy interaction
✓ IAM + KMS
✓ cross-account KMS

✓ Terraform boundary design

✓ EC2 AccessDenied debugging
✓ ECR AccessDenied debugging
✓ S3 AccessDenied debugging
✓ SSE-KMS debugging
✓ endpoint-policy debugging
✓ policy simulator thinking
✓ effective-permission runbook
```

# Next — Lesson 30 Part 3

# **IAM Privilege Escalation Defense — `iam:PassRole`, Federation, OIDC, MFA, ABAC & Confused Deputy**

This is where we move from:

```text
"What permission does this user have?"
```

to:

```text
"Can this user turn
the permissions they have
into MORE permissions?"
```

We'll cover the extremely important chain:

```text
Developer
    │
    ▼
iam:PassRole
    │
    ▼
PowerfulRole
    │
    ▼
Lambda / EC2 / ECS
    │
    ▼
code executes
with PowerfulRole
    │
    ▼
PRIVILEGE ESCALATION
```

Then we'll build:

```text
✓ iam:PassRole in depth
✓ why PassRole is not AssumeRole
✓ PassRole resource scoping
✓ service conditions
✓ EC2/Lambda escalation paths
✓ role creation escalation
✓ managed-policy version escalation

✓ SAML federation
✓ OIDC federation
✓ AssumeRoleWithWebIdentity
✓ GitHub Actions OIDC
✓ Jenkins alternatives
✓ no long-lived CI/CD keys

✓ ExternalId
✓ confused deputy problem
✓ aws:SourceArn
✓ aws:SourceAccount
✓ service-to-service trust

✓ MFA enforcement
✓ MFA context
✓ privileged-role assumptions

✓ ABAC
✓ principal tags
✓ resource tags
✓ session tags
✓ environment/project ownership

✓ IAM Access Analyzer
✓ unused-access analysis
✓ policy generation
✓ credential reports
✓ last-accessed data

✓ full enterprise least-privilege architecture
```

Part 3 will be especially important for **DevOps pipelines, Terraform, GitHub/Jenkins, cross-account deployments, security interviews, SAA-C03, and DOP-C02**, because `iam:PassRole` and federated temporary credentials are at the center of secure AWS automation.

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html?utm_source=chatgpt.com "Policy evaluation logic - AWS Identity and Access ..."
[2]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic_policy-eval-denyallow.html?utm_source=chatgpt.com "How AWS enforcement code logic evaluates requests to ..."
[3]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_identity-vs-resource.html?utm_source=chatgpt.com "Identity-based policies and resource- ..."
[4]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html?utm_source=chatgpt.com "Permissions boundaries for IAM entities"
[5]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_controlling.html?utm_source=chatgpt.com "Control access to AWS resources using policies"
[6]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html?utm_source=chatgpt.com "IAM roles - AWS Identity and Access Management"
[7]: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html?utm_source=chatgpt.com "AssumeRole - AWS Security Token Service"
[8]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_assumerole.html?utm_source=chatgpt.com "Permissions for AssumeRole, AssumeRoleWithSAML, and ..."
[9]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html?utm_source=chatgpt.com "Policies and permissions in AWS Identity and Access ..."
[10]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_update-role-settings.html?utm_source=chatgpt.com "Update settings for a role - AWS Documentation - Amazon.com"
[11]: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_manage-assume.html?utm_source=chatgpt.com "Methods to assume a role"
[12]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html?utm_source=chatgpt.com "Service control policies (SCPs) - AWS Organizations"
[13]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html "Service control policies (SCPs) - AWS Organizations"
[14]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html?utm_source=chatgpt.com "Service control policy examples - AWS Organizations"
[15]: https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_least_privileges.html?utm_source=chatgpt.com "SEC03-BP02 Grant least privilege access"
[16]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html?utm_source=chatgpt.com "Resource control policies (RCPs) - AWS Organizations"
[17]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_authorization_policies.html?utm_source=chatgpt.com "Authorization policies in AWS Organizations"
[18]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps_examples.html?utm_source=chatgpt.com "Resource control policy examples - AWS Organizations"
[19]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html "Resource control policies (RCPs) - AWS Organizations"
[20]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_notaction.html?utm_source=chatgpt.com "IAM JSON policy elements: NotAction"
[21]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_notresource.html?utm_source=chatgpt.com "IAM JSON policy elements: NotResource"
[22]: https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html?utm_source=chatgpt.com "Control access to VPC endpoints using endpoint policies"
[23]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sts_vpc_endpoint_policies.html?utm_source=chatgpt.com "Control access to AWS STS with VPC endpoint policies"
[24]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies-vpc-endpoint.html?utm_source=chatgpt.com "Controlling access from VPC endpoints with bucket policies"
[25]: https://docs.aws.amazon.com/kms/latest/developerguide/policy-evaluation.html?utm_source=chatgpt.com "Troubleshooting AWS KMS permissions"
[26]: https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html?utm_source=chatgpt.com "Key policies in AWS KMS - AWS Key Management Service"
[27]: https://docs.aws.amazon.com/kms/latest/developerguide/iam-policies.html?utm_source=chatgpt.com "Using IAM policies with AWS KMS"
[28]: https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-modifying-external-accounts.html?utm_source=chatgpt.com "Allowing users in other accounts to use a KMS key"
[29]: https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot_access-denied.html?utm_source=chatgpt.com "Troubleshoot access denied error messages"
[30]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html?utm_source=chatgpt.com "IAM policy testing with the IAM policy simulator"
[31]: https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html?utm_source=chatgpt.com "Actions, resources, and condition keys for AWS services"
[32]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic-cross-account.html?utm_source=chatgpt.com "Cross-account policy evaluation logic"
