# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 4: IAM Identity Center — Enterprise Workforce Access Deep Dive

So far we built:

```text
AWS Organizations
      │
      ├── Management Account
      ├── OUs
      ├── Member Accounts
      ├── SCPs / RCPs
      │
      ▼
AWS Control Tower
      │
      ├── Landing Zone
      ├── Audit
      ├── Log Archive
      ├── Controls
      └── Account Factory
```

Now we need to solve the **human access problem**.

Imagine:

```text
1,000 employees

100 AWS accounts

4 common access levels
```

The naive model could become:

```text
1,000 users
×
100 accounts

=
100,000 per-account identity relationships
```

We absolutely do **not** want to manually create an IAM user for every employee in every account.

The production solution is:

# **AWS IAM Identity Center**

IAM Identity Center provides centralized workforce access to multiple AWS accounts and applications; with multi-account permissions, administrators can assign centralized permission sets to users and groups across AWS Organizations accounts. AWS recommends using an **organization instance** for this model because it supports the full Identity Center feature set, including multi-account access and current Multi-Region capabilities. ([AWS Documentation][1])

---

# 38.295 First separate workforce identity from workload identity

This distinction is fundamental.

### Workforce identity

Humans:

```text
Vivek
Alice
Bob
SRE team
Developers
Security engineers
DBAs
Auditors
```

Need access to:

```text
AWS Console
AWS CLI
AWS accounts
business applications
```

IAM Identity Center primarily solves this workforce-access problem.

---

### Workload identity

Machines:

```text
EC2
Lambda
ECS tasks
EKS workloads
CI/CD pipelines
applications
```

They normally use mechanisms such as:

```text
IAM Roles

instance profiles

task roles

IRSA / Pod Identity patterns

OIDC federation

service roles
```

So:

```text
IAM Identity Center
≠
replacement for ECS task roles
```

and:

```text
IAM Identity Center
≠
where Lambda execution roles
should come from.
```

Permanent mental model:

```text
HUMANS
   ↓
IAM Identity Center


WORKLOADS
   ↓
IAM roles / workload federation
```

---

# 38.296 Traditional IAM-user problem

Old design:

```text
PROD ACCOUNT
├── vivek
├── alice
├── bob
└── john


DEV ACCOUNT
├── vivek
├── alice
├── bob
└── john


SECURITY ACCOUNT
├── vivek
├── alice
...
```

Now Alice leaves the company.

Someone must remember:

```text
delete Alice from Prod
delete Alice from Dev
delete Alice from QA
delete Alice from Security
delete access keys
delete MFA
...
```

One forgotten identity can become lingering access.

Centralized workforce federation changes the model.

---

# 38.297 Modern model

```text
                CORPORATE IDENTITY

               Microsoft Entra ID
                     or
                    Okta
                     or
             Identity Center directory
                     │
                     ▼
             IAM IDENTITY CENTER
                     │
                 GROUPS
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼

     Developers     SRE       Security
         │           │           │
         ▼           ▼           ▼

 Permission Set  Permission   Permission
  Developer       Set SRE      Set Audit
         │           │           │
         └───────────┼───────────┘
                     ▼
                AWS ACCOUNTS
```

Identity Center can use its own directory, Active Directory integration, or an external SAML 2.0 identity provider such as Microsoft Entra ID or Okta. When an external IdP is used, users and groups must also be provisioned into Identity Center—typically through SCIM or manual provisioning—because SAML authentication alone doesn't provide Identity Center with a complete user/group directory. ([AWS Documentation][2])

---

# 38.298 The key four objects

You should reduce Identity Center to four things:

```text
1. IDENTITY SOURCE

Who are the humans?


2. USERS / GROUPS

How are humans organized?


3. PERMISSION SET

What AWS permissions may they receive?


4. ACCOUNT ASSIGNMENT

In which AWS account
does that user/group get
that permission set?
```

Everything else builds around these.

---

# 38.299 Identity Source

Question:

> Where does IAM Identity Center learn who `vivek@company.com` is?

That's your:

# Identity Source

Common patterns:

```text
IAM Identity Center directory

Active Directory

External SAML IdP
    ├── Microsoft Entra ID
    ├── Okta
    └── other compatible provider
```

An organization has one configured identity source for its IAM Identity Center instance. ([AWS Documentation][3])

---

# 38.300 Option 1 — Identity Center directory

Small company:

```text
No existing corporate IdP
```

You can manage:

```text
users
groups
passwords
MFA
```

directly in the Identity Center directory.

Architecture:

```text
User
 │
username/password + MFA
 │
 ▼
IAM Identity Center directory
 │
 ▼
AWS access portal
```

Identity Center supports native password and MFA management when the Identity Center directory is the identity source. ([AWS Documentation][4])

---

# 38.301 Option 2 — Active Directory

Enterprise already has:

```text
Corporate Active Directory
```

Then AWS may integrate IAM Identity Center with Active Directory through supported AWS Directory Service configurations.

Conceptually:

```text
Corporate AD
     │
     ▼
AWS Directory integration
     │
     ▼
IAM Identity Center
```

AWS supports connected Active Directory as an Identity Center identity source, including AWS Managed Microsoft AD and supported self-managed AD integration patterns. ([AWS Documentation][5])

---

# 38.302 Option 3 — External Identity Provider

Very common modern enterprise pattern:

```text
Microsoft Entra ID
        │
        ├── SAML
        │
        ▼
 IAM Identity Center
        ▲
        │
        └── SCIM
```

or:

```text
Okta
 │
 ├── SAML authentication
 │
 └── SCIM provisioning
 ▼
IAM Identity Center
```

AWS officially supports external SAML IdP integration and provides specific configuration guidance for providers including Microsoft Entra ID and Okta. ([AWS Documentation][2])

---

# 38.303 SAML vs SCIM

This confusion appears constantly.

## SAML

Think:

# Authentication / federation

```text
User
  │
  ▼
Entra ID
  │
  │ SAML assertion
  ▼
IAM Identity Center
```

Question answered:

> **Who is this person, and has the IdP authenticated them?**

---

## SCIM

Think:

# Identity lifecycle provisioning

```text
Entra ID
   │
   │ SCIM
   ▼
Identity Center

Create user
Update user
Create group
Update group membership
Disable/delete identity
```

External-IdP users and groups must be provisioned into IAM Identity Center before account/application assignments can be made; SCIM provides automated provisioning for this lifecycle. ([AWS Documentation][2])

---

# 38.304 Permanent shortcut

```text
SAML
=
SIGN IN


SCIM
=
SYNC IDENTITIES
```

Or:

```text
SAML:
authentication


SCIM:
provisioning
```

Do not answer:

> “SCIM is the protocol AWS uses to authenticate to the console.”

Wrong.

---

# 38.305 Example employee lifecycle

HR adds:

```text
Alice
Department = Engineering
```

Entra/Okta:

```text
Alice created
     │
     ▼
added to:
AWS-Developers
     │
     ▼
SCIM
     │
     ▼
IAM Identity Center
Alice + group membership appear
```

Then:

```text
AWS-Developers
       │
       ▼
Developer permission set
       │
       ▼
Dev accounts
```

Alice can access AWS according to centrally defined assignments.

This model significantly reduces the need for per-account long-lived IAM workforce users.

---

# 38.306 Group-based access beats user-by-user access

Bad:

```text
Vivek → ProdReadOnly
Alice → ProdReadOnly
John  → ProdReadOnly
Sara  → ProdReadOnly
...
```

Better:

```text
GROUP:
Production-Readers
        │
        ▼
Permission Set:
ReadOnly
        │
        ▼
Production accounts
```

Then employee lifecycle becomes:

```text
add/remove person
from group
```

rather than changing dozens of account assignments.

IAM Identity Center supports assigning AWS account access to both users and groups, with permission sets reusable across accounts. ([AWS Documentation][6])

---

# 38.307 Recommended enterprise group model

Conceptually:

```text
AWS-Prod-ReadOnly

AWS-Prod-SRE

AWS-Dev-Admin

AWS-Security-Audit

AWS-Network-Admin

AWS-Billing-ReadOnly
```

Then map:

```text
GROUP
   │
   ▼
PERMISSION SET
   │
   ▼
ACCOUNT / ACCOUNT GROUP
```

This makes access explainable.

---

# 38.308 Permission Set

A:

# Permission Set

is essentially a centrally maintained template describing what permissions a workforce user receives in an assigned AWS account.

Example:

```text
Permission Set:
ProductionReadOnly

Policies:
ViewOnlyAccess
+ custom application visibility
```

IAM Identity Center stores permission sets centrally and provisions them to one or more AWS accounts. ([AWS Documentation][7])

---

# 38.309 Permission Set is NOT itself an IAM role

This distinction matters.

You create:

```text
IAM Identity Center

Permission Set:
ProductionSRE
```

Then assign it to:

```text
Payments-Prod account
```

IAM Identity Center creates and manages the corresponding IAM role **inside that account**. ([AWS Documentation][8])

Flow:

```text
PERMISSION SET

ProductionSRE
      │
      │ provision
      ▼

PAYMENTS ACCOUNT

IAM Role
AWSReservedSSO_ProductionSRE_xxxxx
```

---

# 38.310 Generated `AWSReservedSSO_` roles

If you've ever opened IAM and seen:

```text
AWSReservedSSO_AdministratorAccess_abcd1234
```

those are usually Identity Center-managed roles created when permission sets are assigned.

AWS documents the general role format as:

```text
AWSReservedSSO_<permission-set-name>_<unique-suffix>
```

under the Identity Center reserved IAM path. ([AWS Documentation][9])

---

# 38.311 Don't edit those roles manually

Suppose IAM shows:

```text
AWSReservedSSO_DeveloperAccess_abcd1234
```

and you click:

```text
Edit role permissions
```

You may receive:

```text
Cannot perform the operation
on the protected role
```

because Identity Center owns these roles. Changes should be made through the Identity Center permission set rather than manually in the target account. ([AWS Documentation][10])

Permanent rule:

```text
Permission Set
=
source of truth


AWSReservedSSO role
=
generated implementation
```

---

# 38.312 One Permission Set can serve many accounts

Example:

```text
Permission Set:
ProductionReadOnly
```

can be provisioned to:

```text
Payments-Prod
Orders-Prod
Analytics-Prod
Customer-Prod
```

Then:

```text
Security-Auditors group
```

gets:

```text
ProductionReadOnly
```

across all of them.

Identity Center explicitly supports assigning a single permission set to multiple organization accounts. ([AWS Documentation][6])

---

# 38.313 One user can have multiple Permission Sets

Vivek might have:

```text
Dev Account

Administrator
```

and:

```text
Prod Account

ReadOnly
```

and:

```text
Network Account

NetworkOperator
```

Even within one account, a user can have more than one permission set and choose the least-privileged role appropriate to the task. AWS explicitly recommends this pattern rather than using administrative access for routine operations. ([AWS Documentation][8])

---

# 38.314 Enterprise example

```text
VIVEK
 │
 ├── DEV ACCOUNT
 │      └── DeveloperAdmin
 │
 ├── PROD ACCOUNT
 │      ├── ProdReadOnly
 │      └── IncidentResponder
 │
 └── SECURITY ACCOUNT
        └── SecurityViewer
```

This is much better than:

```text
Vivek = Administrator
everywhere.
```

---

# 38.315 Permission Set policy options

A permission set can contain combinations of:

```text
AWS managed policies

customer managed IAM policies

inline policy

permissions boundary
```

IAM Identity Center supports these mechanisms when building custom permission sets. ([AWS Documentation][11])

---

# 38.316 Predefined Permission Set

Quick starting point:

```text
Permission Set:
ReadOnly
```

using an AWS managed policy.

AWS Identity Center supports predefined permission sets based on AWS managed policies, including common and job-function policies. ([AWS Documentation][12])

Good for:

```text
initial setup
labs
common generic roles
```

But enterprise least privilege often eventually requires custom permissions.

---

# 38.317 Custom Permission Set

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:Describe*",
        "ecs:List*",
        "ecs:UpdateService",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "cloudwatch:GetMetricData"
      ],
      "Resource": "*"
    }
  ]
}
```

Could represent:

```text
ProductionApplicationOperator
```

without granting:

```text
iam:*
organizations:*
rds:DeleteDBCluster
```

That is closer to real least privilege.

---

# 38.318 Customer-managed policy gotcha

Suppose permission set references:

```text
Customer managed policy:
CompanyProdOperator
```

Identity Center does not magically invent that IAM policy independently in every target account.

AWS requires a customer-managed policy with the **same name and path** to exist in each account to which that permission set is provisioned. ([AWS Documentation][11])

So:

```text
Permission Set
       │
       ▼
references:
CompanyProdOperator
```

Target accounts need:

```text
Payments:
CompanyProdOperator ✓

Orders:
CompanyProdOperator ✓

Analytics:
CompanyProdOperator ✓
```

This is where Terraform/AFT/platform automation becomes useful.

---

# 38.319 Permission Set + Permissions Boundary

Remember Part 2:

```text
Permissions Boundary
=
maximum permission
the role may receive
```

Identity Center allows a permission set to apply an AWS-managed or customer-managed policy as the permissions boundary of its generated account role. ([AWS Documentation][13])

Architecture:

```text
Permission Set policies
       │
       ▼
possible permissions
       │
       ∩
       │
Boundary
       │
       ▼
effective maximum
```

---

# 38.320 Example developer boundary

Permission set:

```text
DeveloperAdministrator
```

might allow broad:

```text
EC2
ECS
Lambda
S3
DynamoDB
CloudWatch
```

Boundary prevents:

```text
Organizations admin
IAM privilege escalation
security-control removal
```

Then the organization's SCPs still sit above that.

---

# 38.321 The complete workforce permission stack

A workforce user may effectively encounter:

```text
USER / GROUP
      │
      ▼
PERMISSION SET
      │
      ▼
AWSReservedSSO Role
      │
      ▼
Permissions Boundary
      │
      ▼
SCP
      │
      ▼
RCP / Resource Policy
      │
      ▼
SERVICE
```

So:

```text
Permission Set says Allow
```

does **not** mean:

```text
request must succeed.
```

Everything from Part 2 still applies.

---

# 38.322 Identity Center does not bypass SCPs

Suppose:

```text
Permission Set:
AdministratorAccess
```

Production OU SCP says:

```text
Deny organizations:LeaveOrganization
```

Result:

```text
User can be very powerful
inside Prod

BUT

cannot bypass the SCP.
```

Identity Center-created roles are still IAM roles in the member account and remain subject to organization guardrails such as applicable SCPs.

This is exactly why:

```text
Identity Center
+
Organizations
```

work so well together.

---

# 38.323 Account Assignment

Now connect everything.

An assignment is conceptually:

```text
WHO
     +
WHAT PERMISSION
     +
WHICH ACCOUNT
```

Example:

```text
GROUP
Production-SRE

      +

PERMISSION SET
ProductionOperator

      +

ACCOUNT
Payments-Prod
```

Result:

```text
Production-SRE
can assume
ProductionOperator
in Payments-Prod.
```

Identity Center's multi-account access system is explicitly built around assigning users/groups plus permission sets to AWS accounts. ([AWS Documentation][6])

---

# 38.324 Three-dimensional access matrix

Think:

| Principal    | Account                    | Permission Set  |
| ------------ | -------------------------- | --------------- |
| Developers   | Dev                        | DeveloperAdmin  |
| Developers   | Prod                       | ProdReadOnly    |
| SRE          | Prod                       | ProdOperator    |
| Security     | All workloads              | SecurityAudit   |
| Network Team | Network                    | NetworkAdmin    |
| Finance      | Management/Billing context | BillingReadOnly |

This matrix is much easier to audit than thousands of individual IAM users.

---

# 38.325 AWS Access Portal

Users normally start at the:

# AWS access portal

After signing in, they see the AWS accounts and roles/permission sets to which they are assigned. Identity Center provides the portal as a centralized single-sign-on entry point for authorized AWS accounts and applications. ([AWS Documentation][14])

Conceptually:

```text
AWS ACCESS PORTAL

AWS Accounts

▼ Payments-Prod
    ├── ProdReadOnly
    └── IncidentResponder

▼ Payments-Dev
    └── DeveloperAdmin

▼ Network
    └── NetworkReadOnly
```

---

# 38.326 Least-privileged role selection

Suppose you have:

```text
AdministratorAccess

and

ReadOnlyAccess
```

in the same account.

Need only to inspect CloudWatch?

Choose:

```text
ReadOnlyAccess
```

not:

```text
AdministratorAccess.
```

AWS explicitly recommends assigning administrative users additional restricted permission sets so they can use least privilege during normal work instead of operating permanently with administrative permissions. ([AWS Documentation][8])

---

# 38.327 Temporary credentials

One huge advantage:

Identity Center users obtain:

```text
temporary AWS credentials
```

rather than needing permanent IAM-user access keys for routine CLI development.

After portal/Identity Center authentication, AWS can provide temporary credentials usable by the CLI and SDKs for the assigned account role. ([AWS Documentation][14])

This is much safer than distributing:

```text
AKIA...
secret-key...
```

to every engineer.

---

# 38.328 Session duration

Permission sets have an AWS-account session duration.

Current AWS behavior:

```text
default:
1 hour

minimum:
1 hour

maximum:
12 hours
```

IAM Identity Center creates the associated IAM role with a maximum role session duration of 12 hours. ([AWS Documentation][15])

---

# 38.329 Why session duration is a security decision

Suppose:

```text
ProductionAdmin session
=
12 hours
```

Credential theft at:

```text
09:01
```

could potentially leave a broad window of credential usefulness.

Compare:

```text
ProdReadOnly
8 hours
```

versus:

```text
ProdAdministrator
1 hour
```

A mature organization may choose different durations according to privilege and operational need.

---

# 38.330 Portal session vs account-role session

Two concepts exist:

```text
Identity Center portal/authentication session
```

and:

```text
AWS account permission-set session
```

They are not identical.

AWS currently lets a permission-set account session run for 1–12 hours, while the AWS access portal authentication session has its own maximum-session setting. ([AWS Documentation][8])

Mental model:

```text
SIGNED INTO PORTAL
       │
       ▼
choose account + permission set
       │
       ▼
ACCOUNT ROLE SESSION
```

---

# 38.331 MFA

For Identity Center-directory users, IAM Identity Center can enforce MFA.

For an external identity provider:

```text
Entra
Okta
etc.
```

MFA is managed by the **external IdP**, not by the IAM Identity Center MFA settings. AWS explicitly states that Identity Center MFA isn't supported as the MFA mechanism for external-IdP authentication. ([AWS Documentation][16])

This is a common interview question.

---

# 38.332 External IdP MFA flow

```text
Vivek
  │
  ▼
Microsoft Entra ID
  │
password
  +
MFA / conditional access
  │
  ▼
SAML assertion
  │
  ▼
IAM Identity Center
  │
  ▼
AWS account access
```

So if Entra is the corporate IdP:

```text
MFA policy
```

belongs primarily in:

```text
Entra
```

not duplicated independently in Identity Center.

---

# 38.333 Why this matters operationally

Suppose security says:

> Require phishing-resistant MFA for production administrators.

External IdP architecture may enforce that through:

```text
corporate conditional-access policy
+
strong authenticator
```

at the IdP.

Identity Center then handles:

```text
AWS account authorization.
```

This preserves:

```text
authentication policy
```

at the corporate identity system and:

```text
AWS permissions
```

at AWS.

---

# 38.334 AWS CLI with IAM Identity Center

Instead of:

```bash
aws configure
```

and permanently storing:

```text
Access Key ID
Secret Access Key
```

modern CLI users can configure an Identity Center profile.

Typical setup:

```bash
aws configure sso
```

Then authenticate:

```bash
aws sso login --profile prod-readonly
```

AWS CLI v2 supports direct Identity Center authentication and retrieves temporary credentials for the configured account and role. ([AWS Documentation][17])

---

# 38.335 Example CLI config

Conceptually:

```ini
[sso-session company]
sso_start_url = https://company.awsapps.com/start
sso_region = ap-south-1
sso_registration_scopes = sso:account:access

[profile payments-prod-readonly]
sso_session = company
sso_account_id = 111122223333
sso_role_name = ProdReadOnly
region = ap-south-1
output = json
```

Then:

```bash
aws sso login --profile payments-prod-readonly
```

And verify:

```bash
aws sts get-caller-identity \
  --profile payments-prod-readonly
```

The current AWS CLI uses Identity Center token-provider configuration to obtain and refresh temporary credentials during the authenticated session. ([AWS Documentation][18])

---

# 38.336 Why CLI SSO is better than developer access keys

Old:

```text
~/.aws/credentials

aws_access_key_id =
AKIAxxxxxxxx

aws_secret_access_key =
xxxxxxxxxxxxxxxx
```

Potentially valid for months or years.

Better:

```text
Browser authentication
      │
      ▼
Identity Center
      │
      ▼
temporary role credentials
      │
      ▼
expire automatically
```

Temporary federated workforce credentials drastically reduce dependence on long-lived IAM-user credentials.

---

# 38.337 Developer experience

Engineer can maintain profiles:

```text
payments-dev-admin

payments-prod-readonly

network-readonly
```

and switch:

```bash
aws s3 ls \
  --profile payments-dev-admin
```

or:

```bash
aws ecs list-clusters \
  --profile payments-prod-readonly
```

The same centralized corporate identity backs them.

---

# 38.338 ABAC

Now advanced identity governance.

# Attribute-Based Access Control

Instead of:

```text
Alice gets Policy A
Bob gets Policy B
Carol gets Policy C
```

you define access using attributes such as:

```text
Department = Payments

Project = Phoenix

CostCenter = 1234
```

Identity Center can pass configured user attributes into AWS account sessions as **session tags**, which IAM policies can reference using `aws:PrincipalTag/<key>`. ([AWS Documentation][19])

---

# 38.339 ABAC example

User attribute:

```text
Department = Payments
```

Resource tag:

```text
Department = Payments
```

Policy concept:

```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:ResourceTag/Department":
        "${aws:PrincipalTag/Department}"
    }
  }
}
```

Meaning:

```text
Payments user
      ↓
may interact with
Payments-tagged resources
```

assuming the relevant service/action supports the condition keys.

---

# 38.340 Why ABAC scales

Without ABAC:

```text
Team A
→ policy A

Team B
→ policy B

Team C
→ policy C

Team D
→ policy D
```

With appropriate ABAC:

```text
ONE policy

allow access where:

Principal.Project
=
Resource.Project
```

Now moving Alice:

```text
Project=Alpha
        ↓
Project=Beta
```

can change effective access based on synchronized identity attributes rather than requiring a new per-resource IAM policy.

---

# 38.341 Identity attributes may come from external IdP

Example:

```text
Entra user:

department = Payments

costCenter = 4100
```

Attribute mappings:

```text
Entra
   │
   ▼
IAM Identity Center
   │
   ▼
session tags
   │
   ▼
IAM policy
```

Identity Center supports attribute mappings and Attributes for Access Control for this model. ([AWS Documentation][20])

---

# 38.342 ABAC danger

If authorization depends on:

```text
Department=Security
```

then ask:

> Who is allowed to change the `Department` attribute?

If ordinary users can self-modify security-critical attributes, they may escalate privileges.

ABAC therefore requires:

```text
trusted identity attributes
+
controlled attribute lifecycle
```

not merely clever IAM JSON.

---

# 38.343 RBAC vs ABAC

## RBAC

Role-Based Access Control:

```text
SecurityEngineer
      ↓
SecurityPolicy
```

Identity Center group + permission-set assignments are naturally suited to this model.

---

## ABAC

Attribute-Based Access Control:

```text
Department=Payments

Resource:
Department=Payments
```

Access calculated from attributes.

---

# 38.344 Real enterprise often combines them

Example:

```text
GROUP:
Developers

       ↓

PERMISSION SET:
DeveloperBase

       ↓

ABAC:
Project must match
resource tag
```

So:

```text
RBAC
defines job function

ABAC
narrows resource scope
```

Very powerful combination.

---

# 38.345 Identity Center and Control Tower

Remember Part 3.

Control Tower commonly integrates with IAM Identity Center to provide centralized access to landing-zone accounts, including accounts created through Account Factory unless identity access is being self-managed through an alternate setup. ([AWS Documentation][21])

Architecture:

```text
CONTROL TOWER
      │
      ▼
new account
      │
      ▼
AWS Organizations
      │
      ▼
IAM Identity Center
      │
      ▼
user/group assignments
```

---

# 38.346 Production group architecture

Example:

```text
IDENTITY PROVIDER

Groups:
│
├── AWS-Platform-Admins
├── AWS-Prod-SRE
├── AWS-Developers
├── AWS-Security-Auditors
├── AWS-Network-Admins
└── AWS-FinOps
```

Mapping:

```text
Platform-Admins
→ PlatformAdmin permission set


Prod-SRE
→ ProdOperator


Developers
→ DevAdmin + ProdReadOnly


Security-Auditors
→ SecurityAudit


Network-Admins
→ NetworkAdmin


FinOps
→ BillingViewer
```

Keep the group model understandable enough that an auditor can answer:

> Why does this human have this AWS access?

---

# 38.347 Avoid account names inside every identity-group name when unnecessary

If you have 400 accounts, this design can explode:

```text
AWS-PaymentsProd-Vivek
AWS-PaymentsProd-Alice
AWS-OrdersProd-Vivek
...
```

Prefer reusable structures where appropriate:

```text
team group
+
permission set
+
account assignment
```

Automation can then generate account mappings without generating a unique identity construct for every person.

---

# 38.348 Separate administrator from normal access

Example:

```text
Vivek

Normal:
ProdReadOnly

Emergency:
ProdAdmin
```

Do not encourage engineers to operate continuously as:

```text
AdministratorAccess.
```

AWS explicitly recommends administrative users receive lower-privilege permission sets for normal work. ([AWS Documentation][8])

---

# 38.349 Just-in-time access concept

IAM Identity Center by itself does not automatically mean every organization has a full approval-based JIT privilege system.

But you can design workflows where:

```text
Engineer requests privileged access
         │
         ▼
approval
         │
         ▼
temporary group/account assignment
         │
         ▼
short session
         │
         ▼
access removed
```

using appropriate identity/governance automation.

Mental goal:

```text
Standing admin access
↓
minimize
```

---

# 38.350 User offboarding

Employee leaves:

```text
Alice disabled
in corporate IdP
```

With centralized federation/provisioning, her AWS workforce access can be removed centrally rather than deleting IAM users account by account.

For external IdPs, SCIM is intended to automate user/group lifecycle synchronization into IAM Identity Center. ([AWS Documentation][2])

---

# 38.351 Important active-session nuance

Disabling/deleting an identity does not always imply every already-issued AWS role session instantly vanishes.

AWS provides explicit procedures for revoking active permission-set sessions when credentials are compromised, including prepared Deny mechanisms. ([AWS Documentation][22])

Therefore incident response requires thinking about:

```text
future login prevention

AND

existing active sessions.
```

---

# 38.352 Credential-compromise response

If:

```text
Vivek's federated session
is compromised
```

response may include:

```text
1. Disable/restrict identity.

2. Remove relevant assignments/group membership.

3. Revoke active sessions.

4. Review CloudTrail.

5. Rotate any downstream credentials
   the user could access.

6. Investigate actions performed.
```

Do not assume:

```text
Disable user
=
all existing temporary sessions
magically terminated instantly.
```

---

# 38.353 External IdP troubleshooting — SCIM

Symptom:

```text
User exists in Entra

but does not appear
in IAM Identity Center.
```

Investigate:

```text
SCIM provisioning enabled?

User/group assigned to AWS app?

SCIM token valid?

attributes unique?

provisioning logs?
```

AWS documents synchronization failures from duplicate required attributes; username, primary email, external ID, and group-name uniqueness can matter for provisioning. ([AWS Documentation][10])

---

# 38.354 External IdP troubleshooting — login

Symptom:

```text
User provisioned

but SAML login fails.
```

Investigate:

```text
SAML metadata

certificate

ACS URL

NameID mapping

username match

user provisioning state
```

AWS specifically lists NameID/user mapping and ACS endpoint mismatch among common external-IdP sign-in problems. ([AWS Documentation][10])

---

# 38.355 The "SAML worked but access denied" distinction

Suppose:

```text
Entra login succeeds
```

then user sees:

```text
No AWS accounts available.
```

Authentication is probably working.

Problem may be:

```text
No Identity Center account assignment
```

or wrong:

```text
group membership

permission set assignment
```

Mental troubleshooting split:

```text
Can't sign in?
→ Identity source / SAML / MFA


Can sign in,
but no account?
→ assignment


Can enter account
but API denied?
→ permission set / IAM / SCP / RCP
```

Excellent troubleshooting shortcut.

---

# 38.356 Three-layer Identity Center troubleshooting

```text
LAYER 1
IDENTITY

Does user exist?
Can user authenticate?


LAYER 2
ASSIGNMENT

Which accounts?
Which permission sets?


LAYER 3
AUTHORIZATION

Does generated role allow action?
Boundary?
SCP?
RCP?
Resource policy?
```

Do not debug layer 3 when layer 1 is broken.

---

# 38.357 `AWSReservedSSO` resource-policy trap

Suppose an EKS cluster or KMS key policy references a generated Identity Center role ARN:

```text
AWSReservedSSO_AdministratorAccess_abcd1234
```

That role name includes a unique suffix. AWS warns that permission-set role ARNs can matter when referenced by resource policies and documents special guidance for managing those references safely. ([AWS Documentation][9])

The broader lesson:

```text
Identity Center role
is service-managed implementation.

Don't hard-code fragile assumptions
about generated roles everywhere.
```

---

# 38.358 Multi-Region IAM Identity Center — major 2026 update

This is especially important because older AWS courses may now be outdated.

IAM Identity Center gained **Multi-Region support in 2026**. An organization instance can now be replicated from its primary Region into additional supported Regions for resilient workforce access. AWS replicates identities, groups, permission sets, assignments, sessions, and other relevant metadata to the configured additional Regions. ([AWS Documentation][23])

Old simplistic statement:

> "IAM Identity Center is permanently one-Region only."

is now outdated.

---

# 38.359 Primary Region and additional Regions

Architecture:

```text
              IAM IDENTITY CENTER

                 PRIMARY REGION
                  ap-south-1
                       │
                       │ replication
                       ▼
               ADDITIONAL REGION
               ap-southeast-1
```

Identity Center currently replicates its instance data asynchronously to configured additional Regions; after initial replication, incremental changes typically propagate quickly, though the model remains asynchronously replicated/eventually consistent. ([AWS Documentation][24])

---

# 38.360 This fits our DR architecture

We already designed:

```text
APPLICATION

Mumbai
  ↓
Singapore DR
```

Now identity can also be considered:

```text
WORKFORCE ACCESS

IAM Identity Center
Mumbai
  ↓
additional Region
Singapore
```

So enterprise DR isn't only:

```text
ECS
Aurora
Route 53
```

It also includes:

```text
Can privileged engineers
still access AWS
during the incident?
```

That is an excellent production question.

---

# 38.361 Important Multi-Region prerequisite

Current IAM Identity Center Multi-Region replication requires planning around an **external identity provider**; AWS's current Identity Center guidance states that if you plan to replicate Identity Center to additional Regions, you need an external IdP. ([AWS Documentation][16])

So:

```text
Identity Center native directory
+
"we'll just replicate it tomorrow"
```

should not be assumed without verifying current prerequisites.

---

# 38.362 External IdP also needs DR configuration

Suppose Identity Center primary Region fails.

Additional Region:

```text
Identity Center ✓
```

But your external IdP still points SAML only to:

```text
Primary Region ACS URL.
```

Users may still be unable to sign in.

AWS documents that failover to an additional Identity Center Region requires updating/configuring the external IdP's assertion consumer service path for the additional Region. ([AWS Documentation][25])

Again:

```text
replica exists
≠
end-to-end recovery works.
```

Lesson 37 strikes again.

---

# 38.363 Identity Center Regional replication mental flow

Normal:

```text
Employee
  │
  ▼
External IdP
  │
  ▼
Identity Center
ap-south-1
  │
  ▼
AWS Account
```

Regional disruption:

```text
Employee
  │
  ▼
External IdP
  │
  ▼
Identity Center
ap-southeast-1
  │
  ▼
AWS Account
```

but only if:

```text
additional Region active

IdP integration prepared

portal/ACS path understood

permissions already provisioned

runbook tested
```

---

# 38.364 Identity DR still needs break glass

This is critical.

AWS currently recommends configuring **break-glass access even when IAM Identity Center has been replicated to additional Regions**. Why?

Because Identity Center redundancy doesn't necessarily protect you from a failure of your external identity provider itself. ([AWS Documentation][26])

Think:

```text
IAM Identity Center
Mumbai X

Singapore ✓

BUT

Corporate IdP X
```

Federated login may still be unavailable.

---

# 38.365 Emergency access vs break glass

Two related concepts.

### Identity Center emergency access pattern

AWS documents an emergency-access design where trusted users can use **direct federation from the external IdP** to preconfigured AWS IAM roles if IAM Identity Center itself is disrupted. ([AWS Documentation][27])

Architecture:

```text
External IdP
     │
     │ direct federation
     ▼
Emergency IAM Role
     │
     ▼
AWS Console
```

---

# 38.366 But that still depends on the IdP

If:

```text
Identity Center X
```

but:

```text
Entra ✓
```

direct-federation emergency access can help.

If:

```text
Identity Center X
+
Entra X
```

that path may also fail.

That's why AWS separately recommends a true AWS break-glass process for privileged access that does not rely solely on the normal centralized identity path. ([AWS Documentation][26])

---

# 38.367 Break-glass principles

Emergency access should be:

```text
pre-provisioned

rarely used

strongly protected

monitored

tested

documented
```

and not:

```text
"During the outage we'll figure out
how to create an administrator."
```

AWS Well-Architected recommends establishing emergency-access procedures before incidents occur. ([AWS Documentation][28])

---

# 38.368 Example enterprise access architecture

```text
                 MICROSOFT ENTRA ID

          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼

      Developers        SRE          Security
          │              │              │
          └──────────────┼──────────────┘
                         │
                       SAML
                         │
                         ▼
                IAM IDENTITY CENTER
                         ▲
                         │
                        SCIM
                         │
                 identity lifecycle
                         │
                         ▼
                   PERMISSION SETS

             ┌───────────┼────────────┐
             ▼           ▼            ▼

          DevAdmin   ProdOperator   SecurityAudit

             │           │            │
             └───────────┼────────────┘
                         ▼

                    AWS ORGANIZATION

           ┌─────────────┼──────────────┐
           ▼             ▼              ▼

         DEV           PROD          SECURITY
       Account        Account         Account
          │             │               │
  AWSReservedSSO  AWSReservedSSO   AWSReservedSSO
       Roles          Roles            Roles

                         │
                         ▼
                   SCP / RCP Layer
```

That is the enterprise workforce access control plane.

---

# 38.369 Add Multi-Region resiliency

```text
                    EXTERNAL IdP
                         │
                         ▼
               IAM IDENTITY CENTER

                  PRIMARY REGION
                   ap-south-1
                         │
               async replication
                         ▼
                ADDITIONAL REGION
                ap-southeast-1

                         │
                         ▼
                  AWS ORGANIZATION
```

And separately:

```text
BREAK-GLASS ACCESS
       │
       ▼
preconfigured emergency
AWS access path
```

Now the identity layer also participates in the organization's resilience architecture. ([AWS Documentation][23])

---

# 38.370 Production Permission Set design

A reasonable hierarchy might look like:

```text
01 — ViewOnly

02 — ReadOnly

03 — Developer

04 — ApplicationOperator

05 — SREOperator

06 — NetworkOperator

07 — SecurityAudit

08 — SecurityAdmin

09 — PlatformAdmin

10 — EmergencyAdmin
```

But don't create roles simply because the list looks mature.

Create them around:

```text
actual job functions

least privilege

separation of duties

risk
```

---

# 38.371 Example Production SRE Permission Set

Allow:

```text
ECS deployments

read CloudWatch

read logs

inspect ALB

limited Auto Scaling

Systems Manager diagnostics
```

Maybe deny/omit:

```text
IAM administration

Organizations

delete database

delete backup vault

disable CloudTrail
```

Then:

```text
Production OU SCP
```

adds broader organization guardrails.

---

# 38.372 Example Developer model

```text
DEV ACCOUNT

Developers
→ DeveloperAdmin


PROD ACCOUNT

Developers
→ ProdReadOnly
```

The same person does **not** need the same privilege level everywhere.

This is one of the strongest reasons to centralize account access with reusable permission sets. ([AWS Documentation][6])

---

# 38.373 Example Security model

```text
Security Team

Workload Accounts
→ SecurityAudit


Security Tooling Account
→ SecurityAdmin


Management Account
→ extremely limited
  organization-admin access
```

Don't conclude:

```text
Security engineer
=
AdministratorAccess across
every AWS account forever.
```

Separation of duties still matters.

---

# 38.374 Management Account access

Part 1 taught us that the Organizations management account is unusually sensitive.

So access might be:

```text
CloudPlatform-Core group
       │
       ▼
OrganizationAdmin
       │
       ▼
Management Account
```

with:

```text
few members

strong MFA

short sessions

heavy monitoring

no daily workload use
```

Identity Center centralizes access, but it does not reduce the importance of carefully protecting the management account.

---

# 38.375 Identity Center administrative delegation

Enterprise access administration itself should also be governed.

You may separate:

```text
Identity administrators

Permission-set administrators

Account-assignment administrators

Organization administrators
```

rather than making one giant team:

```text
AWSSuperAdmins.
```

IAM Identity Center provides IAM permissions for delegating management of account permissions and permission sets. ([AWS Documentation][29])

---

# 38.376 Terraform and Identity Center

Terraform can manage items such as:

```text
permission sets

account assignments

group mappings
```

through the AWS provider.

A conceptual repository:

```text
identity/
│
├── permission-sets/
│   ├── prod-readonly.tf
│   ├── prod-sre.tf
│   ├── dev-admin.tf
│   └── security-audit.tf
│
├── assignments/
│   ├── production.tf
│   ├── nonproduction.tf
│   └── security.tf
│
└── boundaries/
```

Identity-as-code gives you:

```text
pull request

review

history

repeatability

auditability
```

instead of uncontrolled console assignments.

We will integrate this into the Terraform governance capstone later in Lesson 38.

---

# 38.377 Avoid putting individual people directly into Terraform where possible

Bad scaling model:

```hcl
user = "vivek"
user = "alice"
user = "john"
```

everywhere.

Better:

```text
IdP Group
AWS-Prod-SRE
      │
      ▼
account assignment
```

Then HR/identity lifecycle stays inside the identity platform, while AWS IaC manages:

```text
group-to-permission-to-account mappings.
```

Cleaner separation.

---

# 38.378 Access review question

A good auditor should be able to ask:

> Why can Alice modify ECS in production?

And you can answer:

```text
Alice
  ↓
member of AWS-Prod-SRE
  ↓
SCIM synchronized
  ↓
IAM Identity Center
  ↓
ProdOperator permission set
  ↓
assigned to Payments-Prod
  ↓
AWSReservedSSO role
  ↓
ECS UpdateService allowed
```

That's explainable authorization.

---

# 38.379 Common production mistake — one Admin permission set

Bad organization:

```text
Permission Set:
AdministratorAccess

Assigned to:
Developers
SRE
Security
Network
Platform
```

You successfully implemented centralized authentication.

You failed at authorization.

Remember:

```text
SSO
≠
least privilege.
```

---

# 38.380 Common mistake — hundreds of IAM users remain

Organization enables Identity Center but keeps:

```text
600 human IAM users
with access keys
```

for normal day-to-day work.

You now have:

```text
centralized identity
+
legacy identity sprawl.
```

Plan a controlled migration away from unnecessary long-lived workforce IAM credentials.

---

# 38.381 Common mistake — no SCIM

Company has:

```text
Entra ID
```

but manually provisions every person into IAM Identity Center.

Employee joins:

```text
manual create
```

Employee changes team:

```text
manual update
```

Employee leaves:

```text
hope somebody remembers.
```

Where supported, automated SCIM provisioning greatly improves lifecycle consistency. ([AWS Documentation][2])

---

# 38.382 Common mistake — SAML assumed to provision users

SAML login succeeds only if Identity Center knows the corresponding user.

IAM Identity Center does not perform automatic just-in-time user/group creation from SAML alone; external identities must already be provisioned manually or through SCIM. ([AWS Documentation][10])

Permanent rule:

```text
SAML
does not replace
directory provisioning.
```

---

# 38.383 Common mistake — MFA configured in wrong place

External identity provider:

```text
Entra / Okta
```

Company tries to configure:

```text
Identity Center native MFA
```

for those federated logins.

Wrong control plane.

For external IdP users, MFA is controlled by the external identity provider. ([AWS Documentation][30])

---

# 38.384 Common mistake — session duration too long everywhere

Don't blindly configure:

```text
12 hours
```

for:

```text
ProductionAdmin

ManagementAccountAdmin

SecurityAdmin
```

just because 12 hours is supported.

Use session duration as part of privileged-access risk design.

---

# 38.385 Common mistake — fragile generated-role ARN

Don't spread:

```text
AWSReservedSSO_<name>_<suffix>
```

hard-coded across:

```text
KMS
EKS
bucket policies
custom application configuration
```

without understanding lifecycle implications.

Identity Center owns these generated roles, and AWS publishes special guidance for safely referencing permission-set roles from resource policies. ([AWS Documentation][9])

---

# 38.386 Common mistake — no emergency access

Enterprise:

```text
100% dependent on Identity Center
+
100% dependent on Entra
```

No emergency procedure.

Then identity provider incident occurs.

Application healthy.

AWS engineers can't access it.

That is an **identity-layer single point of operational failure**.

AWS recommends pre-provisioned break-glass access even where Identity Center Multi-Region replication is configured. ([AWS Documentation][26])

---

# 38.387 Common mistake — emergency access never tested

A runbook saying:

```text
"Use emergency admin role."
```

does not prove:

```text
credentials exist

MFA works

trust works

role works

engineers know procedure
```

Identity emergency access belongs in game days just like database failover.

Remember Lesson 37's principle:

> **A recovery mechanism that is never tested is an assumption.**

---

# 38.388 Identity Game Day

Scenario:

```text
IAM Identity Center
primary Region unavailable.
```

Test:

```text
Can engineers use
additional Region?
```

Then:

```text
External IdP unavailable.
```

Test:

```text
Can approved emergency operators
still obtain break-glass access?
```

Measure:

```text
Time to obtain admin access

Who approved it?

Was CloudTrail generated?

Could access be removed afterward?
```

Now identity is part of SRE/resilience engineering.

---

# 38.389 Interview question — IAM vs IAM Identity Center

Strong answer:

> **IAM manages identities, roles, policies, and authorization within AWS accounts and for workloads. IAM Identity Center provides centralized workforce federation and multi-account/application access. Identity Center ultimately provisions or uses IAM roles in AWS accounts for the account-level permissions represented by permission sets.** ([AWS Documentation][1])

---

# 38.390 Interview question — Permission Set vs IAM Role

```text
PERMISSION SET

centrally defined template
inside IAM Identity Center


IAM ROLE

actual AWS account identity
used for service authorization
```

When a permission set is assigned to an account, IAM Identity Center creates/manages the corresponding role in that account. ([AWS Documentation][8])

---

# 38.391 Interview question — SAML vs SCIM

```text
SAML
=
authentication/federation


SCIM
=
user/group provisioning
and lifecycle synchronization
```

External IdP integrations commonly use both because authentication and directory provisioning solve different problems. ([AWS Documentation][2])

---

# 38.392 Interview question — external IdP MFA

Answer:

> If IAM Identity Center uses an external IdP such as Microsoft Entra ID or Okta, MFA for those users is managed by the external IdP rather than IAM Identity Center's native MFA configuration. ([AWS Documentation][16])

---

# 38.393 Interview question — CLI access

Answer:

> Engineers can configure AWS CLI v2 to authenticate through IAM Identity Center, sign in through the browser-based flow, and obtain temporary role credentials rather than maintaining long-lived IAM-user access keys. ([AWS Documentation][17])

---

# 38.394 Interview question — ABAC

Strong answer:

> **IAM Identity Center can map workforce identity attributes and pass selected attributes to AWS account sessions as session tags. IAM policies can then use `aws:PrincipalTag` conditions to implement attribute-based access control.** ([AWS Documentation][19])

---

# 38.395 Interview question — why groups?

Because:

```text
user lifecycle
```

becomes:

```text
change group membership
```

rather than:

```text
edit dozens of AWS account assignments.
```

Groups also map more naturally to enterprise job functions and identity-provider lifecycle management.

---

# 38.396 Interview question — session duration

Current permission-set AWS-account sessions:

```text
1 hour minimum

1 hour default

12 hours maximum
```

according to current IAM Identity Center documentation. ([AWS Documentation][15])

---

# 38.397 Interview question — Multi-Region Identity Center

A strong current answer:

> **IAM Identity Center now supports Multi-Region replication for eligible organization instances. The primary instance can replicate workforce identities, groups, permission sets, assignments, sessions, and other metadata to additional supported Regions. This capability was introduced in 2026, so older material that describes Identity Center as strictly single-Region is outdated.** ([AWS Documentation][23])

---

# 38.398 Interview trap — Multi-Region means no break glass

Wrong.

AWS still recommends break-glass access because:

```text
Identity Center Region resilience
```

does not guarantee:

```text
external IdP availability.
```

([AWS Documentation][26])

---

# 38.399 Interview trap — permission set bypasses SCP

Wrong.

The permission set becomes an IAM role in the target account.

That role is still constrained by:

```text
SCP

RCP

permissions boundary

resource policy

service authorization
```

where applicable.

---

# 38.400 Interview trap — IAM Identity Center eliminates IAM

Wrong.

Identity Center actually relies on IAM roles in target AWS accounts for account access. ([AWS Documentation][31])

Better:

```text
IAM Identity Center
=
central workforce control plane


IAM
=
account authorization foundation
```

---

# 38.401 Interview trap — SCIM authenticates users

Wrong.

```text
SAML
→ authentication


SCIM
→ provisioning
```

---

# 38.402 Interview trap — every human should get an IAM user too

No.

Routine human workforce access should generally use centralized federation and temporary credentials where suitable.

Dedicated IAM identities may remain for tightly controlled exceptional cases such as particular emergency-access designs, but they should not recreate general workforce identity sprawl.

---

# 38.403 Troubleshooting matrix

| Symptom                                 | First place to investigate            |
| --------------------------------------- | ------------------------------------- |
| User cannot authenticate                | IdP / SAML / MFA                      |
| User missing from Identity Center       | SCIM/provisioning                     |
| User signs in but sees no account       | Account assignment                    |
| Account visible but wrong role          | Permission-set assignment             |
| API denied inside account               | Permission set / IAM / SCP / RCP      |
| CLI can't log in                        | SSO profile / cached session / portal |
| Entra user login mismatch               | SAML attributes / NameID              |
| New team membership not visible         | SCIM group sync                       |
| `AWSReservedSSO` role can't be edited   | Modify permission set centrally       |
| Regional Identity Center failover fails | Additional Region + IdP ACS/runbook   |
| All federated identity unavailable      | Break-glass procedure                 |

---

# 38.404 Identity troubleshooting mnemonic

Remember:

# **I-G-P-A-R**

```text
I
IDENTITY

Does user exist?


G
GROUP

Correct membership?


P
PERMISSION SET

Correct rights?


A
ASSIGNMENT

Correct AWS account?


R
RESTRICTIONS

SCP / boundary / RCP / resource policy?
```

Then for external federation add:

```text
SAML + SCIM
```

at the beginning.

---

# 38.405 Complete enterprise identity flow

```text
                         EMPLOYEE

                            │
                            ▼
                    CORPORATE IdP
                  Entra / Okta / AD
                            │
               ┌────────────┴────────────┐
               │                         │
             SAML                      SCIM
               │                         │
          authentication          provisioning
               │                         │
               └────────────┬────────────┘
                            ▼
                   IAM IDENTITY CENTER

                   Users / Groups
                            │
                            ▼
                    Permission Sets

           ┌────────────────┼─────────────────┐
           ▼                ▼                 ▼

       DevAdmin        ProdOperator       AuditRead

           │                │                 │
           ▼                ▼                 ▼

      DEV ACCOUNT      PROD ACCOUNT    SECURITY ACCOUNT

           │                │                 │
           ▼                ▼                 ▼

      AWSReservedSSO   AWSReservedSSO    AWSReservedSSO
          IAM Role        IAM Role          IAM Role

           │                │                 │
           └────────────────┼─────────────────┘
                            ▼
                   SCP / RCP / IAM
                            │
                            ▼
                       AWS SERVICES
```

That's the entire workforce authorization pipeline.

---

# 38.406 One final Multi-Region identity map

```text
                   CORPORATE EXTERNAL IdP

                           │
                           ▼
                IAM IDENTITY CENTER
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼

       PRIMARY REGION              ADDITIONAL REGION
        ap-south-1                 ap-southeast-1
             │                           │
             └──────── replication ──────┘
                           │
                           ▼
                    AWS ORGANIZATION

                           +

                   BREAK-GLASS ACCESS
                           │
                           ▼
              independent emergency path
```

Identity deserves the same resilience thinking as:

```text
network

database

compute

DNS.
```

---

# 38.407 Never-forget Part 4 rules

```text
1.
IAM Identity Center solves
centralized workforce access.


2.
Workloads still use normal
IAM workload identities.


3.
Identity Source tells AWS
where users come from.


4.
Prefer group-based assignments
over user-by-user sprawl.


5.
Permission Set =
central access template.


6.
Assignment =
user/group
+
permission set
+
AWS account.


7.
Permission Set is provisioned
as an Identity Center-managed
IAM role in the target account.


8.
AWSReservedSSO roles
should not be manually edited.


9.
SAML =
authentication.


10.
SCIM =
user/group provisioning.


11.
External IdP controls MFA
for external-IdP users.


12.
Use temporary Identity Center
credentials for human CLI access
instead of routine long-lived keys.


13.
Permission-set session duration
is currently 1–12 hours.


14.
RBAC and ABAC can be combined.


15.
ABAC attributes must come from
trusted identity data.


16.
Identity Center roles
do not bypass SCPs.


17.
Authentication success
doesn't mean authorization success.


18.
Identity Center added
Multi-Region support in 2026.


19.
Regional replication does not
eliminate dependence on the
external IdP.


20.
Maintain and test
break-glass access.
```

---

# 38.408 Part 4 checkpoint

You now understand:

```text
✓ Workforce vs workload identities

✓ IAM Identity Center

✓ Organization instance

✓ Identity sources

✓ Identity Center directory

✓ Active Directory

✓ External SAML IdP

✓ Microsoft Entra / Okta patterns

✓ SAML

✓ SCIM

✓ Users and groups

✓ Permission sets

✓ Generated AWSReservedSSO roles

✓ Account assignments

✓ AWS access portal

✓ Temporary CLI credentials

✓ aws configure sso

✓ Session duration

✓ MFA ownership

✓ AWS managed policies

✓ Customer managed policies

✓ Inline policies

✓ Permission-set boundaries

✓ Identity Center + SCP interaction

✓ RBAC

✓ ABAC

✓ Session tags

✓ aws:PrincipalTag

✓ Offboarding

✓ Session revocation

✓ Login troubleshooting

✓ SCIM troubleshooting

✓ Multi-Region IAM Identity Center

✓ IdP failover dependency

✓ Emergency federation

✓ Break-glass access
```

---

# ✅ Lesson 38 — Part 4 Complete

```text
Part 1
Enterprise Multi-Account Architecture
+ AWS Organizations                     ✓

Part 2
SCP + RCP + IAM Policy Evaluation       ✓

Part 3
AWS Control Tower Landing Zone          ✓

Part 4
IAM Identity Center                     ✓

Part 5
Central Security + Logging              NEXT

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

# Next — Lesson 38, Part 5

## Centralized AWS Security, Logging & Audit Architecture

Next we connect the accounts to an enterprise security operations model:

```text
                      AWS ORGANIZATION

                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼

       Workloads        Network           Security
          │                                  │
          │                                  ├── Audit
          │                                  ├── Security Tooling
          │                                  └── Log Archive
          │
          └──────────────────┬───────────────┘
                             ▼
                     CENTRAL SECURITY
                             │
             ┌───────────────┼───────────────┐
             ▼               ▼               ▼

         CloudTrail       GuardDuty      Security Hub

             │               │               │
             ▼               ▼               ▼

         AWS Config       Inspector         Macie

             │               │               │
             └───────────────┼───────────────┘
                             ▼
                       EventBridge / SIEM
```

We'll cover **organization CloudTrail, immutable central logs, AWS Config aggregation, Security Hub central configuration, GuardDuty delegated administration, Inspector, Macie, Detective, IAM Access Analyzer, central finding aggregation, EventBridge automation, SIEM integration, Security Lake, cross-account incident response, log retention, KMS, SCP protection of security controls, and a complete production SOC architecture**.

[1]: https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html?utm_source=chatgpt.com "What is IAM Identity Center?"
[2]: https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-identity-source-idp.html?utm_source=chatgpt.com "External identity providers - AWS IAM Identity Center"
[3]: https://docs.aws.amazon.com/singlesignon/latest/userguide/tutorials.html?utm_source=chatgpt.com "IAM Identity Center identity source tutorials"
[4]: https://docs.aws.amazon.com/singlesignon/latest/userguide/managing-workforce-access-identity-center-directory.html?utm_source=chatgpt.com "Managing access for users in the Identity Center directory"
[5]: https://docs.aws.amazon.com/singlesignon/latest/userguide/gs-ad.html?utm_source=chatgpt.com "Using Active Directory as an identity source"
[6]: https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-accounts.html?utm_source=chatgpt.com "Configure access to AWS accounts - AWS IAM Identity Center"
[7]: https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsets.html?utm_source=chatgpt.com "Create, manage, and delete permission sets"
[8]: https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html?utm_source=chatgpt.com "Manage AWS accounts with permission sets"
[9]: https://docs.aws.amazon.com/singlesignon/latest/userguide/referencingpermissionsets.html?utm_source=chatgpt.com "Referencing permission sets in resource policies ..."
[10]: https://docs.aws.amazon.com/singlesignon/latest/userguide/troubleshooting.html?utm_source=chatgpt.com "Troubleshooting IAM Identity Center issues"
[11]: https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetcustom.html?utm_source=chatgpt.com "Custom permissions for AWS managed and ..."
[12]: https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetpredefined.html?utm_source=chatgpt.com "Predefined permissions for AWS managed policies"
[13]: https://docs.aws.amazon.com/singlesignon/latest/userguide/howtocreatepermissionset.html?utm_source=chatgpt.com "Create a permission set - AWS IAM Identity Center"
[14]: https://docs.aws.amazon.com/singlesignon/latest/userguide/howtogetcredentials.html?utm_source=chatgpt.com "Getting IAM Identity Center user credentials for the AWS ..."
[15]: https://docs.aws.amazon.com/singlesignon/latest/userguide/howtosessionduration.html?utm_source=chatgpt.com "Set session duration for AWS accounts"
[16]: https://docs.aws.amazon.com/singlesignon/latest/userguide/confirm-identity-source.html?utm_source=chatgpt.com "Confirm your identity sources in IAM Identity Center"
[17]: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html?utm_source=chatgpt.com "Configuring IAM Identity Center authentication with ..."
[18]: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso-concepts.html?utm_source=chatgpt.com "AWS IAM Identity Center concepts for the AWS CLI"
[19]: https://docs.aws.amazon.com/singlesignon/latest/userguide/attributesforaccesscontrol.html?utm_source=chatgpt.com "Attributes for access control - AWS IAM Identity Center"
[20]: https://docs.aws.amazon.com/singlesignon/latest/userguide/attributemappingsconcept.html?utm_source=chatgpt.com "Attribute mappings between IAM Identity Center and ..."
[21]: https://docs.aws.amazon.com/controltower/latest/userguide/sso.html?utm_source=chatgpt.com "Working with AWS IAM Identity Center and AWS Control ..."
[22]: https://docs.aws.amazon.com/singlesignon/latest/userguide/revoke-user-permissions.html?utm_source=chatgpt.com "Revoke user access - AWS IAM Identity Center"
[23]: https://docs.aws.amazon.com/singlesignon/latest/userguide/multi-region-iam-identity-center.html?utm_source=chatgpt.com "Using IAM Identity Center across multiple AWS Regions"
[24]: https://docs.aws.amazon.com/singlesignon/latest/userguide/replicate-to-additional-region.html?utm_source=chatgpt.com "Replicate IAM Identity Center to an additional Region"
[25]: https://docs.aws.amazon.com/singlesignon/latest/userguide/multi-region-failover.html?utm_source=chatgpt.com "Failover to an additional Region for AWS account access"
[26]: https://docs.aws.amazon.com/singlesignon/latest/userguide/resiliency-regional-behavior.html?utm_source=chatgpt.com "Resiliency design and Regional behavior"
[27]: https://docs.aws.amazon.com/singlesignon/latest/userguide/emergency-access.html?utm_source=chatgpt.com "Set up emergency access to the AWS Management Console"
[28]: https://docs.aws.amazon.com/wellarchitected/latest/framework/sec_permissions_emergency_process.html?utm_source=chatgpt.com "SEC03-BP03 Establish emergency access process"
[29]: https://docs.aws.amazon.com/singlesignon/latest/userguide/iam-auth-access-using-id-policies.html?utm_source=chatgpt.com "Identity-based policy examples for IAM Identity Center"
[30]: https://docs.aws.amazon.com/singlesignon/latest/userguide/mfa-getting-started.html?utm_source=chatgpt.com "Prompt users for MFA - AWS IAM Identity Center"
[31]: https://docs.aws.amazon.com/singlesignon/latest/userguide/identity-center-and-iam-roles.html?utm_source=chatgpt.com "IAM roles created by IAM Identity Center"
