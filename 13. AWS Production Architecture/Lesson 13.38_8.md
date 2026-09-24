# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 8: AWS Organizations Delegated Administration — Deep Dive

We have repeatedly used terms such as:

```text
Security Hub delegated administrator

GuardDuty delegated administrator

IPAM delegated administrator

CloudTrail delegated administrator
```

Now we need to understand what AWS is actually doing.

The central problem is:

> **How can we keep the AWS Organizations management account highly restricted while still allowing Security, Network, Backup, Identity, and Platform teams to administer organization-wide AWS services?**

The answer is built from three related but different mechanisms:

```text
TRUSTED ACCESS

SERVICE-LINKED ROLES

DELEGATED ADMINISTRATOR
```

---

# 38.876 The core enterprise problem

Without delegation:

```text
                    MANAGEMENT ACCOUNT
                            │
           ┌────────────────┼─────────────────┐
           ▼                ▼                 ▼
       GuardDuty       Security Hub         IPAM
       Inspector        CloudTrail          Backup
       Macie            Config              Firewall
                            │
                            ▼
                       Daily operations
```

Now dozens of engineers require access to:

```text
Organizations Management Account
```

That is exactly what we **do not** want.

AWS recommends limiting use of the management account to tasks that must be performed there and using delegated administrator accounts for supported services. One reason is especially important: SCPs don't restrict principals in the Organizations management account. ([AWS Documentation][1])

Better:

```text
                    MANAGEMENT ACCOUNT

                    Organizations authority
                           │
             delegation / trusted access
                           │
       ┌───────────────────┼───────────────────┐
       ▼                   ▼                   ▼

 SECURITY TOOLING       NETWORK          BACKUP / LOGGING
       │                   │                   │
 GuardDuty              IPAM                Backup
 Inspector          Network Manager       CloudTrail
 Security Hub       Firewall Manager       Config
 Macie
 Access Analyzer
```

---

# 38.877 Three concepts that must never be confused

## 1. Trusted Access

```text
AWS Organizations
      │
      ▼
"Service X is allowed to
operate across this organization."
```

## 2. Service-Linked Role

```text
Member Account
      │
      ▼
AWS service-specific IAM role
      │
      ▼
Service assumes it
```

## 3. Delegated Administrator

```text
Management Account
      │
      ▼
"Member Account X may centrally
administer Service Y."
```

Permanent shortcut:

```text
TRUSTED ACCESS
=
service ↔ organization trust


SERVICE-LINKED ROLE
=
service ↔ member-account execution


DELEGATED ADMIN
=
human/admin control moved
to member account
```

---

# 38.878 Trusted Access — deep mental model

AWS Organizations itself does not automatically allow every AWS service to inspect/configure every organization member.

Instead, supported services integrate through:

# **Trusted Access**

Concept:

```text
AWS ORGANIZATION
      │
      ▼
enable trusted access
for Service X
      │
      ▼
Service X can perform
its documented organization-level tasks
```

When trusted access is enabled, the trusted service can create service-linked roles in member accounts when those roles are required for organization-level operations. Trusted access grants permissions to the AWS **service**, not to your ordinary IAM users or roles. ([AWS Documentation][2])

---

# 38.879 Trusted access does NOT grant users permissions

Suppose:

```text
Trusted access:
GuardDuty = ENABLED
```

Does that mean:

```text
DeveloperRole
can administer GuardDuty?
```

# No.

Trusted access says:

```text
GuardDuty service
may integrate with Organizations
```

not:

```text
all IAM identities
receive GuardDuty permissions.
```

AWS explicitly states that trusted access affects the trusted service's ability to act for the organization; it does not otherwise grant permissions to users or roles. ([AWS Documentation][2])

---

# 38.880 Trusted Access vs IAM

Remember our previous lesson pattern:

```text
RAM share
≠ IAM permission

SCP
≠ IAM grant

Trusted access
≠ IAM grant
```

AWS permissions remain layered.

---

# 38.881 Service-linked roles

When a trusted service needs to perform operations in member accounts, AWS may create:

# Service-Linked Roles — SLRs

Example concept:

```text
MEMBER ACCOUNT

AWS service-linked role
        │
        ▼
trusted AWS service
assumes role
        │
        ▼
performs only documented
service operations
```

These roles have predefined service-specific permissions and are generally managed by AWS rather than manually edited by customers. ([AWS Documentation][2])

---

# 38.882 `AWSServiceRoleForOrganizations`

Every full-feature Organizations environment also has an important Organizations service-linked role:

```text
AWSServiceRoleForOrganizations
```

AWS Organizations uses that role to support creating service-linked roles needed by trusted integrated services in member accounts. ([AWS Documentation][2])

Think:

```text
Organizations
      │
      ▼
AWSServiceRoleForOrganizations
      │
      ▼
helps trusted services
establish required SLRs
```

---

# 38.883 Never manually "clean up" service-linked roles casually

Engineer sees:

```text
AWSServiceRoleForAccessAnalyzer
AWSServiceRoleForOrganizations
AWSServiceRoleForBackup
...
```

and thinks:

> “Unused IAM role—I'll delete it.”

Dangerous.

These are often critical components of AWS service integrations.

Rule:

```text
AWS SERVICE-LINKED ROLE

Do not delete/edit
unless you understand the
service lifecycle that owns it.
```

---

# 38.884 Delegated Administrator

Now the administrative side.

AWS Organizations supports registering member accounts as:

# Delegated Administrators

for supported AWS services.

A delegated administrator can perform organization-wide administrative tasks for that service without requiring operators to work from the Organizations management account. ([AWS Documentation][1])

Architecture:

```text
MANAGEMENT ACCOUNT
      │
      │ designate
      ▼
SECURITY TOOLING
      │
      │ delegated administrator
      ▼
GUARDDUTY
      │
      ├── Account A
      ├── Account B
      └── Account C
```

---

# 38.885 Delegation is service-specific

This is critical.

If:

```text
Security Tooling
=
GuardDuty delegated admin
```

that does **not** automatically mean:

```text
Security Tooling
=
Inspector admin
=
Macie admin
=
CloudTrail admin
=
Backup admin
```

Each service has its own organization integration.

Think:

```text
ACCOUNT
+
SERVICE
=
delegated-administrator relationship
```

not:

```text
one global "super delegated admin"
```

---

# 38.886 Trusted Access usually comes first

General model:

```text
1. Enable trusted access
        ↓
2. Register delegated administrator
        ↓
3. Configure organization-level service
        ↓
4. Configure member auto-enrollment/
   policies/etc.
```

AWS Organizations explicitly says to confirm that the service supports delegated administrators and enable trusted access before registering one. ([AWS Documentation][1])

---

# 38.887 But use the service's own setup flow when possible

This is a subtle production best practice.

AWS recommends using the **trusted service's own console/API/CLI** to enable or disable Organizations integration when available rather than directly toggling service access from Organizations.

Why?

Because the service may need to:

```text
create resources

initialize configuration

create service-linked roles

perform cleanup
```

as part of the integration lifecycle. ([AWS Documentation][2])

Mental rule:

```text
PREFER

Service X console/API
     ↓
Organizations integration


rather than blindly calling

organizations:
EnableAWSServiceAccess
```

unless the service's documentation tells you to.

---

# 38.888 Generic CLI mental model

At Organizations API level:

```bash
aws organizations enable-aws-service-access \
  --service-principal <SERVICE_PRINCIPAL>
```

Then:

```bash
aws organizations register-delegated-administrator \
  --account-id <ACCOUNT_ID> \
  --service-principal <SERVICE_PRINCIPAL>
```

Conceptually:

```text
enable service trust
       │
       ▼
delegate account
```

But some services require or recommend a service-specific API instead of only the generic Organizations command.

Always check the service documentation.

---

# 38.889 How to see trusted services

Useful operational command:

```bash
aws organizations \
  list-aws-service-access-for-organization
```

This helps answer:

> Which AWS services currently have trusted access to our organization?

---

# 38.890 How to inspect delegated administrators

Conceptually:

```bash
aws organizations list-delegated-administrators
```

and for a specific service:

```bash
aws organizations list-delegated-administrators \
  --service-principal <SERVICE_PRINCIPAL>
```

You can also determine which services a particular account is delegated to.

This becomes very useful in audits.

---

# 38.891 Delegated admin still needs IAM permission

Very important.

AWS Organizations registering:

```text
Account X
as delegated admin
```

does not automatically mean:

```text
every user in Account X
can administer Service X.
```

`RegisterDelegatedAdministrator` grants the account's service integration relationship and some read-only Organizations visibility, but the principals operating inside that account still need the appropriate service permissions. ([AWS Documentation][3])

Again:

```text
DELEGATED ACCOUNT
≠
every identity is admin.
```

---

# 38.892 Example

Security Tooling is:

```text
Inspector delegated administrator
```

but Vivek logs in with:

```text
SecurityReadOnly
```

permission set.

Can he disable Inspector across the organization?

Not if his IAM/permission-set permissions don't grant that operation.

Correct model:

```text
DELEGATED ACCOUNT STATUS
        ∩
IAM / Permission Set
        ∩
SCP
        =
effective admin ability
```

---

# 38.893 SCPs still affect delegated admin accounts

Remember:

```text
Delegated Administrator
=
MEMBER ACCOUNT
```

not:

```text
Management Account.
```

Therefore applicable SCPs still constrain its IAM principals.

That is actually an advantage.

You can delegate administration while retaining organization-level guardrails.

---

# 38.894 Why delegated accounts are safer than management

Management account:

```text
SCP protection ✕
```

Member delegated account:

```text
SCP protection ✓
```

Therefore:

```text
delegation
=
not merely organizational convenience

it also creates a more governable
administrative environment
```

AWS explicitly uses this as part of its recommendation to keep operational work out of the management account. ([AWS Documentation][1])

---

# 38.895 Disabling trusted access is NOT disabling the AWS service

This is an important trap.

Suppose:

```text
GuardDuty trusted access
=
disabled
```

That does not necessarily mean:

```text
GuardDuty service
is disabled in every account.
```

AWS says disabling trusted access removes the service's ability to perform organization-level operations; users with ordinary service IAM permissions can still use the service unless separately restricted. ([AWS Documentation][2])

Think:

```text
TRUSTED ACCESS OFF
=
organization integration broken/removed


SERVICE OFF
=
different operation
```

---

# 38.896 Why disabling trusted access directly can hurt

If you disable Organizations integration abruptly:

```text
Organizations
   ↓
DisableAWSServiceAccess
```

the service might lose its ability to:

```text
aggregate member data

configure new accounts

perform cross-account actions

create required SLRs
```

and cleanup behavior differs by service. AWS recommends disabling through the service's own workflow when possible so the service can remove integration-specific resources safely. ([AWS Documentation][2])

---

# 38.897 Enterprise delegated-account architecture

A good starting point:

```text
                         MANAGEMENT ACCOUNT

                     Organization authority only
                              │
              ┌───────────────┼────────────────┐
              │               │                │
              ▼               ▼                ▼

       SECURITY TOOLING     NETWORK        LOG / BACKUP
              │               │                │
       Security Hub           IPAM           CloudTrail
       GuardDuty          Network Manager     Backup
       Inspector          Firewall Manager    Security Lake
       Macie
       Access Analyzer
       Detective
```

This is a logical operating model, not an AWS requirement that every organization must use exactly these account names.

---

# 38.898 GuardDuty delegated administration

From Part 5:

```text
SECURITY TOOLING
     │
     ▼
GuardDuty delegated admin
```

GuardDuty is Regional. AWS requires the **same member account** to serve as GuardDuty delegated administrator across Regions where GuardDuty organization management is used, but you designate/configure the relationship in the applicable Regions. ([AWS Documentation][4])

Architecture:

```text
            Security Tooling

       ┌───────────┴────────────┐
       ▼                        ▼

GuardDuty Mumbai          GuardDuty Singapore
 delegated admin           delegated admin

     same AWS account
```

---

# 38.899 GuardDuty auto-enable

The delegated GuardDuty admin can set organization auto-enable behavior such as:

```text
ALL

NEW

NONE
```

for GuardDuty and relevant protection plans. ([AWS Documentation][5])

Think:

```text
ALL
=
existing + future members


NEW
=
future member accounts


NONE
=
don't automatically change members
```

---

# 38.900 Why same GuardDuty admin across Regions?

Imagine:

```text
Mumbai → SecurityToolingA

Singapore → SecurityToolingB
```

Now incident visibility and administration become fragmented.

AWS therefore requires the same delegated GuardDuty administrator account across Regions. ([AWS Documentation][4])

This aligns nicely with:

```text
ONE SECURITY TOOLING ACCOUNT

multi-Region service administration
```

---

# 38.901 Security Hub delegated administrator

Security Hub CSPM supports a delegated administrator for organization-wide posture and finding administration. With central configuration enabled, the delegated administrator creates configuration policies that can manage Security Hub CSPM, standards, and controls across accounts and Regions. ([AWS Documentation][6])

Architecture:

```text
Security Tooling
      │
      ▼
Security Hub delegated admin
      │
      ▼
Configuration Policies
      │
   ┌──┼─────────────┐
   ▼  ▼             ▼
Root Prod OU     Sandbox OU
```

---

# 38.902 Security Hub Regional nuance

Without central configuration, delegated-administrator designation is Region-specific and should be consistently configured in each Region.

With central configuration, Security Hub CSPM automatically establishes the same delegated administrator in the:

```text
Home Region
+
Linked Regions
```

used by central configuration. ([AWS Documentation][6])

So current best mental model:

```text
Security Hub central configuration
=
one security-account operating model
across configured Regions
```

---

# 38.903 Security Hub removal is dangerous

Advanced nuance:

If Security Hub CSPM central configuration is in use and the management account removes the delegated administrator through Organizations, AWS deletes the central configuration policies and policy associations. Member accounts retain their existing settings but become self-managed. ([AWS Documentation][7])

So:

```text
Change delegated admin
```

is **not** merely:

```text
replace account ID.
```

It can change the organization's security-control management state.

Treat it as a migration.

---

# 38.904 Amazon Inspector delegated admin

Inspector is also Regional.

Current AWS behavior requires:

```text
one delegated administrator
for the organization
```

and if that account is designated in one Region, the same account must be used as delegated administrator in all other Inspector Regions. You must perform the designation in each Region where Inspector is used. ([AWS Documentation][8])

---

# 38.905 Inspector 2026 organization-policy model

Modern Inspector also supports **AWS Organizations Inspector policies** that centrally govern scan-type enablement across:

```text
Root

OU

Account
```

AWS recommends setting the Inspector delegated administrator before creating these organization policies. When policies manage scan enablement, the policy takes precedence over ordinary delegated-admin/member enablement settings. ([AWS Documentation][9])

This creates two layers:

```text
ORGANIZATIONS POLICY
=
which scan types must be enabled


INSPECTOR DELEGATED ADMIN
=
operational scanning/finding administration
```

---

# 38.906 Very important Inspector distinction

Suppose Production OU policy says:

```text
EC2 scanning = ENABLED
```

Can the Inspector delegated admin simply disable EC2 scanning for that Production account?

Not when the account is governed by the Inspector organization policy.

The Organizations policy is the governance layer and takes precedence for policy-managed enablement. ([AWS Documentation][10])

This mirrors what we've learned repeatedly:

```text
POLICY GOVERNANCE
>
local administrator preference
```

---

# 38.907 Removing Inspector delegated admin does not necessarily stop scanning

Current behavior:

If you remove the delegated Inspector administrator:

```text
Inspector remains activated
in its member accounts

existing scan settings remain

accounts become standalone
```

and if Organizations Inspector policies manage enablement, those policies continue to apply. ([AWS Documentation][11])

Again:

```text
remove delegated admin
≠
disable service
```

---

# 38.908 Macie delegated administration

For Macie:

```text
Security Tooling
     │
     ▼
Macie delegated administrator
```

can centrally manage organization members and sensitive-data discovery posture.

Macie organization configuration is Regional; if used in multiple Regions, AWS requires the **same Macie administrator account** in all those Regions, while designation is performed separately in each Region. ([AWS Documentation][12])

---

# 38.909 Macie mental model

```text
SAME ADMIN ACCOUNT

       │
  ┌────┴────────┐
  ▼             ▼
Mumbai       Singapore
Macie         Macie
```

Not:

```text
different security admin
per Region.
```

---

# 38.910 Access Analyzer delegated administration

IAM Access Analyzer supports an Organizations delegated administrator that can create organization-scoped analyzers.

Only the Organizations management account can add, remove, or change that delegated administrator. ([AWS Documentation][13])

Example:

```text
Security Tooling
      │
      ▼
Organization Access Analyzer
      │
      ▼
Zone of trust =
AWS Organization
```

---

# 38.911 Access Analyzer Regional nuance

For:

```text
External Access

Internal Access
```

IAM Access Analyzer is Regional, so analyzers must be created in the Regions in which you require resource-access analysis.

Unused-access analysis has different Regional behavior and does not require one analyzer per resource Region in the same way. ([AWS Documentation][14])

Again:

```text
"Delegated administrator configured"
```

does not mean:

```text
"All Regions are covered."
```

---

# 38.912 CloudTrail delegated administrators

CloudTrail now supports organization delegated administrators that can manage organization trails and organization event data stores on behalf of the organization. ([AWS Documentation][15])

Possible model:

```text
Management Account
      │
      ▼
Security Tooling
CloudTrail delegated admin
      │
      ▼
Organization Trail

logs
      │
      ▼
Log Archive Account
```

Notice again:

```text
ADMIN
≠
LOG STORAGE
```

---

# 38.913 CloudTrail supports multiple delegated admins

Current CloudTrail documentation allows the organization management account to register **up to three** CloudTrail delegated administrators. Only the management account can add or remove them. ([AWS Documentation][16])

This is an important lesson:

> **There is no universal “one delegated administrator per AWS service” rule.**

Each service defines its own model.

---

# 38.914 Why multiple CloudTrail admins might help

You could separate:

```text
Security Operations

Compliance

Platform Audit
```

if organizational requirements justify it.

But don't create multiple admins just because AWS allows them.

More administrative principals can mean:

```text
more complexity

more privileged access

more ownership ambiguity
```

Use least privilege.

---

# 38.915 AWS Config delegated administration

Config has an interesting implementation detail.

For organization-level use, AWS documentation distinguishes trusted service access for:

```text
config.amazonaws.com
```

for organization aggregation and:

```text
config-multiaccountsetup.amazonaws.com
```

for organization rules/conformance-pack multi-account setup. ([AWS Documentation][17])

Concept:

```text
Security / Compliance Account
       │
       ▼
AWS Config delegated admin
       │
       ├── Organization Aggregator
       ├── Organization Config rules
       └── Conformance packs
```

---

# 38.916 Why Config makes a good delegated service

Without delegation:

```text
Management Account
must be used
for central compliance operations
```

With delegated administration:

```text
Security / Compliance Account
        │
        ▼
aggregated configuration
and compliance
```

Much cleaner separation.

---

# 38.917 IPAM delegated administrator

This was Part 6.

AWS lets the management account delegate one of its member accounts to be the organization IPAM account.

That account becomes responsible for:

```text
creating IPAM

creating pools

monitoring address use

sharing pools

organization-wide discovery
```

A Network/Network-Hub account is the typical pattern. ([AWS Documentation][18])

Architecture:

```text
Management
   │
   ▼
delegate
   │
   ▼
Network Account
   │
   ▼
IPAM
   │
   ├── Prod Pool
   ├── Dev Pool
   └── DR Pool
```

---

# 38.918 IPAM service-linked role behavior

When an organization member is delegated as IPAM administrator, IPAM creates the necessary service-linked role in organization member accounts so it can discover IP address usage and CIDRs across those accounts. ([AWS Documentation][18])

This is an excellent concrete example of the relationship:

```text
TRUSTED ACCESS
      ↓
SERVICE-LINKED ROLE
      ↓
DELEGATED ADMINISTRATOR
      ↓
ORGANIZATION-WIDE VIEW
```

---

# 38.919 Firewall Manager is different again

Firewall Manager supports:

```text
default administrator

+
additional administrators
```

and additional administrators can receive restricted administrative scope by:

```text
OU/accounts

Regions

Firewall Manager policy types
```

instead of every administrator necessarily receiving organization-wide firewall power. ([AWS Documentation][19])

This is a very advanced least-privilege capability.

---

# 38.920 Example Firewall Manager admin split

```text
SECURITY ACCOUNT A

Scope:
Production OU
Network Firewall


SECURITY ACCOUNT B

Scope:
Web workloads
AWS WAF


NETWORK SECURITY TEAM

Scope:
selected Regions
specific firewall policies
```

Firewall Manager supports multiple administrators with administrative scopes, while one default administrator has full scope. ([AWS Documentation][19])

---

# 38.921 Default Firewall Manager administrator

The first administrator created when onboarding an organization becomes the:

```text
DEFAULT ADMINISTRATOR
```

with full administrative scope and capability to manage third-party firewall integrations.

Additional administrators can be scoped more narrowly. ([AWS Documentation][19])

Do not memorize Firewall Manager as:

```text
exactly one delegated admin.
```

That's outdated/incomplete.

---

# 38.922 AWS Backup delegated administration

AWS Backup also supports delegated administrators.

A Backup delegated administrator can:

```text
monitor cross-account jobs

manage backup policies
```

once the relevant delegation and IAM permissions are configured. However, some organization-level opt-in controls remain management-account responsibilities. ([AWS Documentation][20])

A strong architecture:

```text
Management Account
      │
      ▼
Central Backup Account
      │
      ├── backup policy administration
      ├── cross-account monitoring
      └── backup operations
```

---

# 38.923 AWS Backup has two delegation layers

This is a great advanced point.

Registering an account as Backup delegated administrator lets it perform cross-account Backup administration/monitoring.

But to let it manage **AWS Organizations Backup Policies**, current AWS guidance also requires:

```text
IAM permissions
+
Organizations resource-based
delegation policy
```

for backup policy management. ([AWS Documentation][20])

So:

```text
Backup delegated admin registration
```

alone does **not** automatically mean:

```text
may manage all Organizations
backup policies.
```

---

# 38.924 Resource-based delegation policy in Organizations

This brings us to a more advanced concept.

AWS Organizations itself now supports:

# Resource-Based Delegation Policies

These let the management account delegate certain Organizations policy-management operations to selected member accounts. ([AWS Documentation][21])

This is different from:

```text
Service delegated administrator
```

Think:

```text
SERVICE DELEGATION

"Security Account administers Inspector."


ORGANIZATIONS POLICY DELEGATION

"Backup Account may administer
specific Organizations Backup policies."
```

---

# 38.925 Don't confuse Organizations policy delegation with service delegation

Example:

```text
Backup Account
```

may need:

1. AWS Backup delegated-administrator relationship.

2. `AWSBackupOrganizationAdminAccess` or equivalent IAM permission.

3. Organizations resource-based delegation permission allowing Backup policy management.

AWS Backup explicitly documents this layered requirement. ([AWS Documentation][20])

That is a senior-level AWS governance concept.

---

# 38.926 IAM Identity Center delegation

IAM Identity Center has its own delegated-administration model.

The Identity Center organization instance still resides in the Organizations management account, but administration can be delegated to a member account so routine identity administration occurs outside the management account. ([AWS Documentation][22])

Architecture:

```text
Management Account

Identity Center instance
       │
       ▼
Identity delegated admin
       │
       ▼
Identity / Platform account
```

---

# 38.927 Identity Center delegated admin limitation

A very important protection:

Permission sets provisioned for access to the **Organizations management account** cannot be modified by the Identity Center delegated administrator; they must be managed from the management-account side. ([AWS Documentation][22])

That's intentional.

It prevents:

```text
Identity delegated admin
      │
      ▼
modify own access
to Organizations management
```

too freely.

---

# 38.928 Management-account identity deserves special treatment

AWS even recommends special caution around:

```text
groups
```

used for management-account assignments, because an identity-provider group administrator could indirectly alter who has privileged management-account access by changing group membership. ([AWS Documentation][22])

For the most privileged account:

```text
WHO CONTROLS GROUP MEMBERSHIP?
```

is itself a security question.

---

# 38.929 Security Lake delegated administrator

Security Lake is another special case.

The Organizations management account **cannot** itself act as the Security Lake delegated administrator. A member account must be chosen. AWS also requires designation through the Security Lake registration operation rather than relying solely on generic Organizations delegated-admin registration. ([AWS Documentation][23])

AWS SRA commonly places this responsibility in:

```text
Log Archive Account
```

which fits our Part 5 architecture.

---

# 38.930 A major lesson: service models are not identical

Look at what we've discovered:

```text
GuardDuty
same admin account across Regions


Inspector
one admin account;
same across Regions,
configured regionally


Security Hub
central configuration home/linked Regions


Macie
same account across Regions,
configured regionally


CloudTrail
up to three delegated admins


Firewall Manager
default + multiple scoped admins


Security Lake
management account cannot be DA


Identity Center
delegated admin exists,
but management-account
permission sets remain protected


Backup
delegated admin + possible
Organizations policy delegation
```

Therefore:

# **Never design delegated administration from memory alone.**

Check each service's current Organizations integration.

---

# 38.931 Enterprise delegation matrix

A practical architecture might look like:

| Service             | Suggested account         | Main purpose                      |
| ------------------- | ------------------------- | --------------------------------- |
| GuardDuty           | Security Tooling          | Threat detection administration   |
| Security Hub        | Security Tooling          | Posture/finding administration    |
| Inspector           | Security Tooling          | Vulnerability administration      |
| Macie               | Security Tooling          | Sensitive-data administration     |
| Detective           | Security Tooling          | Investigation                     |
| IAM Access Analyzer | Security Tooling          | Organization access analysis      |
| CloudTrail          | Security Tooling or Audit | Organization trail administration |
| AWS Config          | Security/Compliance       | Compliance aggregation            |
| IPAM                | Network                   | Address governance                |
| Network Manager     | Network                   | Network management                |
| Firewall Manager    | Security/Network Security | Firewall policies                 |
| AWS Backup          | Central Backup            | Backup policy/monitoring          |
| Security Lake       | Log Archive               | Security data lake                |
| IAM Identity Center | Identity/Platform         | Workforce access administration   |

This is a **recommended operating model**, not a requirement that every enterprise use the same account names. Service capabilities differ and should be validated individually. ([AWS Documentation][23])

---

# 38.932 Why not one delegated admin account for everything?

At first glance:

```text
CentralAdminAccount
```

sounds simpler.

But then one compromise gives control of:

```text
security

networking

backup

identity

logging
```

across the whole enterprise.

A better model often uses responsibility boundaries:

```text
SECURITY TOOLING
→ security


NETWORK
→ network


BACKUP
→ recovery


LOG ARCHIVE
→ security data


IDENTITY
→ workforce access
```

This is:

# Separation of Duties.

---

# 38.933 But don't create 30 admin accounts either

The other extreme:

```text
GuardDutyAdmin account

InspectorAdmin account

MacieAdmin account

SecurityHubAdmin account

AccessAnalyzerAdmin account

DetectiveAdmin account
```

may create unnecessary account sprawl.

AWS itself often recommends using the same delegated administrator across related security services where appropriate for consistent governance. Security Hub, for example, explicitly recommends consistent delegated administration across security services. ([AWS Documentation][24])

A reasonable pattern:

```text
SECURITY TOOLING
=
many related security services
```

while still separating fundamentally different duties such as:

```text
network

backup

identity

evidence storage.
```

---

# 38.934 The "minimum management-account usage" principle

Use the management account for things such as:

```text
Create organization

Create/change delegated admin

some trusted-access setup

critical org-level configuration

management-account-only operations
```

Then leave.

Routine:

```text
GuardDuty triage

Inspector administration

IP allocation

Firewall policies

backup monitoring
```

should occur from delegated accounts when supported.

---

# 38.935 Service delegation does not transfer Organizations ownership

If Security Tooling is GuardDuty delegated administrator:

```text
Security Tooling
```

does **not** become:

```text
Organizations management account.
```

It cannot simply:

```text
close arbitrary accounts

change all Organizations settings

take over billing

become account owner
```

It receives only the service-defined organization administrative permissions plus limited Organizations visibility required for that service. ([AWS Documentation][3])

---

# 38.936 Think "scope of authority"

```text
MANAGEMENT ACCOUNT
=
organization authority


DELEGATED ADMIN
=
service-specific authority


MEMBER ACCOUNT ADMIN
=
local account authority
```

These are three very different power levels.

---

# 38.937 Regional service delegation checklist

Before configuring any delegated service ask:

```text
Is the service Global or Regional?

Is the DA relationship Regional?

Must the same account be used
across Regions?

Do I need to repeat designation?

Is there a home/linked Region model?

Does organization policy handle
Region enablement?

What happens in opt-in Regions?
```

This single checklist prevents many security gaps.

---

# 38.938 Example — Mumbai configured, Singapore forgotten

Architecture:

```text
SecurityTooling
      │
      ▼
GuardDuty delegated admin
ap-south-1
```

but nothing in:

```text
ap-southeast-1
```

Primary fails.

Singapore becomes production.

Result:

```text
Application DR ✓

Threat Detection Governance ✕
```

That's why we keep connecting governance to DR.

---

# 38.939 Delegated admin deployment should be IaC

Do not rely on:

```text
"We clicked the console
three years ago."
```

Maintain an authoritative service-delegation registry.

Example conceptual configuration:

```yaml
delegations:

  security-tooling:
    services:
      - guardduty
      - securityhub
      - inspector
      - macie
      - access-analyzer

  network:
    services:
      - ipam
      - network-manager

  central-backup:
    services:
      - backup

  log-archive:
    services:
      - security-lake
```

Then enforce/validate using:

```text
Terraform

CloudFormation

AWS CLI automation

policy-as-code
```

where supported.

---

# 38.940 Terraform mental model

Generic Organizations resources/APIs can represent concepts such as:

```text
trusted-service access

delegated administrator
```

but remember:

> **Service-specific delegation APIs may perform additional initialization.**

AWS explicitly recommends using the trusted service's own integration workflow when available. ([AWS Documentation][2])

So blindly doing only:

```text
Organizations resource
```

may not fully configure Service X.

---

# 38.941 Example IaC ownership

A clean repository could be:

```text
organization/
│
├── trusted-services/
│   ├── security.tf
│   ├── network.tf
│   └── backup.tf
│
├── delegations/
│   ├── security-tooling.tf
│   ├── network.tf
│   ├── backup.tf
│   └── log-archive.tf
│
└── policies/
    ├── scp/
    ├── rcp/
    ├── backup/
    └── inspector/
```

Now delegation is a governed platform artifact.

---

# 38.942 Change delegated administrator carefully

Changing:

```text
Security Tooling A
      ↓
Security Tooling B
```

is not one generic AWS operation.

For many services the safe process is:

```text
1. Inventory current configuration.

2. Understand service-specific
   removal behavior.

3. Remove/deregister old DA.

4. Register new DA.

5. Reassociate members if needed.

6. Restore central configuration.

7. Validate every Region.

8. Validate findings/data.

9. Update IAM and automation.

10. Remove obsolete privileges.
```

Different services preserve or remove different pieces of state.

---

# 38.943 Example — Inspector administrator change

Current Inspector behavior:

```text
remove DA
      │
      ▼
member accounts remain enabled

scan settings retained
      │
      ▼
accounts temporarily standalone
```

until a new delegated administrator is established/associated as needed. ([AWS Documentation][11])

That's relatively safe from a scanning-continuity perspective.

---

# 38.944 Example — Security Hub admin change

Security Hub central configuration is more delicate.

Removing the delegated admin via Organizations while central configuration is active deletes central configuration policies and their associations. Accounts keep their current settings but become self-managed. ([AWS Documentation][7])

So the change plan must reconstruct:

```text
configuration policies

associations

home/linked Region control
```

for the new administrator.

---

# 38.945 Example — trusted access disabled accidentally

Suppose platform engineer executes:

```bash
aws organizations disable-aws-service-access \
  --service-principal <service>
```

without using the service's cleanup workflow.

Potential result:

```text
new account integration fails

cross-account aggregation stops

delegated admin loses visibility

SLR creation stops

historical configuration may remain
```

exact behavior depends on the service. ([AWS Documentation][2])

This deserves an incident.

---

# 38.946 Monitor trusted access

A governance monitoring job should periodically check:

```bash
aws organizations \
  list-aws-service-access-for-organization
```

Compare:

```text
EXPECTED
vs
ACTUAL
```

Example:

```text
GuardDuty       expected ✓ actual ✓
Inspector       expected ✓ actual ✓
Security Hub    expected ✓ actual ✓
IPAM            expected ✓ actual ✕
```

Then alert on drift.

---

# 38.947 Monitor delegated administrators too

Expected:

```text
GuardDuty       → Security Tooling
Inspector       → Security Tooling
IPAM            → Network
Backup          → Central Backup
Security Lake   → Log Archive
```

Actual:

```text
GuardDuty       → Security Tooling
Inspector       → unknown old account  ✕
```

That is organizational drift.

---

# 38.948 Delegation registry

Maintain:

| Service       | Delegated account | Owner      | Regions              | Criticality |
| ------------- | ----------------- | ---------- | -------------------- | ----------- |
| GuardDuty     | Security Tooling  | Security   | All enabled          | Critical    |
| Inspector     | Security Tooling  | Security   | All workload Regions | Critical    |
| Security Hub  | Security Tooling  | Security   | Home + linked        | Critical    |
| IPAM          | Network           | NetOps     | Org-wide             | Critical    |
| Backup        | Central Backup    | Backup/SRE | Required Regions     | Critical    |
| Security Lake | Log Archive       | Security   | Selected Regions     | High        |

This becomes part of your cloud CMDB/platform inventory.

---

# 38.949 Delegated administrators are crown-jewel accounts

A delegated administrator may control:

```text
hundreds of accounts
```

for one service.

Therefore:

```text
Security Tooling
Network
Backup
Identity
```

must receive stronger controls than an ordinary Dev account.

At minimum consider:

```text
restricted privileged access

short sessions

strong MFA

central audit

no random workloads

tight egress

separation of duties

break-glass process

change review
```

---

# 38.950 Privilege escalation through delegation

Suppose an attacker compromises:

```text
Identity delegated admin
```

and can:

```text
change Identity Center groups
```

that map to privileged account access.

That's a serious indirect privilege-escalation path.

AWS specifically recommends tightly controlling identity-store write operations and SCIM token creation when Identity Center administration is delegated. ([AWS Documentation][22])

Delegated admin security must consider:

```text
what can this service
indirectly grant?
```

not just the service's own API names.

---

# 38.951 Backup delegated admin is also sensitive

A compromised Backup administrator might influence:

```text
backup policies

retention configuration

backup monitoring

recovery operations
```

depending on permissions.

Remember Lesson 37:

```text
Backup
=
last line of recovery
```

So Backup administration deserves strong separation from ordinary application administration.

---

# 38.952 Network delegated admin is sensitive

A compromised Network account controlling IPAM/network services could influence:

```text
address allocation

global network topology

firewall policy

routing control
```

depending on delegated services.

Therefore:

```text
Network Account
```

is also a crown-jewel platform account.

---

# 38.953 One service can require several IAM layers

Example: AWS Backup delegated administrator managing Organizations Backup policies.

Possible authorization layers:

```text
Backup account
is registered DA
       │
       ▼
Identity Center permission set
       │
       ▼
AWSBackupOrganizationAdminAccess
       │
       ▼
Organizations resource-based
delegation policy
       │
       ▼
SCP
       │
       ▼
Backup policy operation
```

One missing layer:

```text
AccessDenied.
```

This is why enterprise troubleshooting needs the complete permission model.

---

# 38.954 Delegated admin troubleshooting mnemonic

Remember:

# **T-D-I-R-S**

```text
T
TRUST

Is trusted access enabled?


D
DELEGATION

Is correct account delegated?


I
IAM

Does caller have service permission?


R
REGION

Correct Region / Regional designation?


S
SERVICE STATE

Are members/policies/configuration
actually enabled?
```

Very useful.

---

# 38.955 Troubleshooting — delegated admin sees no members

Example:

```text
Security Tooling
=
Macie delegated admin
```

but member account missing.

Check:

```text
T:
trusted access?

D:
same Macie admin account?

I:
permission?

R:
correct Region?

S:
member enabled/associated?
```

Macie must be configured in each Region used by the organization. ([AWS Documentation][25])

---

# 38.956 Troubleshooting — Inspector works in Mumbai, not Singapore

Check:

```text
Inspector enabled in Singapore?

same delegated admin account?

delegation performed in Singapore?

organization Inspector policy
includes Singapore?

member associated?

scan type enabled?
```

Inspector is Regional and requires delegation/configuration in each Region where it is used. ([AWS Documentation][8])

---

# 38.957 Troubleshooting — Config aggregator empty

Check:

```text
trusted access:
config.amazonaws.com?

delegated admin registered?

aggregator role?

source accounts?

Regions?

Config recording enabled
in source accounts?
```

AWS Config requires the appropriate Organizations service access before a delegated administrator creates an organization aggregator. ([AWS Documentation][17])

---

# 38.958 Troubleshooting — IPAM doesn't discover organization VPCs

Check:

```text
correct delegated IPAM account?

Organizations integration?

service-linked role?

IPAM created by delegated account?

organization membership intact?
```

Once properly delegated, IPAM uses its service-linked role integration to discover organization-member CIDRs. ([AWS Documentation][18])

---

# 38.959 Troubleshooting — Backup DA can monitor but cannot edit policies

This is a classic advanced issue.

Check:

```text
Backup delegated admin ✓

cross-account monitoring ✓

AWSBackupOrganizationAdminAccess?

Organizations resource-based
delegation policy?
```

AWS explicitly says registering a Backup delegated administrator alone does not grant Backup-policy management; IAM and Organizations policy delegation are also required. ([AWS Documentation][20])

---

# 38.960 Troubleshooting — Identity delegated admin can't change management-account permission set

This may be:

```text
EXPECTED SECURITY BEHAVIOR.
```

Identity Center prevents the delegated admin from altering permission sets that are provisioned to the Organizations management account. ([AWS Documentation][22])

Do not "fix" this by weakening the architecture.

---

# 38.961 Interview question — trusted access

Strong answer:

> **Trusted access allows a supported AWS service to integrate with AWS Organizations and perform documented operations across organization accounts. The service can use service-linked roles in member accounts when required. Trusted access gives authority to the AWS service itself; it does not grant IAM permissions to ordinary users or roles.** ([AWS Documentation][2])

---

# 38.962 Interview question — delegated administrator

Strong answer:

> **A delegated administrator is a member account that the Organizations management account designates to perform organization-level administration for a supported AWS service. It allows routine service administration to move out of the management account while keeping the management account as the organization's authority. The delegated account's users still need appropriate service IAM permissions and remain subject to applicable SCPs.** ([AWS Documentation][1])

---

# 38.963 Interview — trusted access vs delegated admin

```text
TRUSTED ACCESS

"May Service X work
with this Organization?"


DELEGATED ADMIN

"Which member account
administers Service X?"
```

That distinction should be instant.

---

# 38.964 Interview — service-linked role

> **A service-linked role is an IAM role tied to an AWS service. In Organizations integrations, trusted services can use service-linked roles in member accounts to perform the service-specific operations required for centralized administration.** ([AWS Documentation][2])

---

# 38.965 Interview — delegated admin vs management account

```text
MANAGEMENT ACCOUNT

owns organization authority

can establish/remove delegation


DELEGATED ADMIN

member account

owns service-specific
operational administration
```

Delegated administrator:

```text
≠ second management account.
```

---

# 38.966 Interview trap — enabling trusted access enables service for every account

# Wrong.

Trusted access enables the organization's integration with the service.

Actual member enablement depends on:

```text
service configuration

organization policy

auto-enable setting

Region

member association
```

depending on the service.

---

# 38.967 Interview trap — delegated admin bypasses SCP

# Wrong.

Delegated administrator is a member account and its principals remain constrained by applicable SCPs.

---

# 38.968 Interview trap — one delegated admin rule for all services

# Wrong.

Current AWS services have very different models:

```text
CloudTrail
→ multiple admins possible

Firewall Manager
→ default + scoped admins

GuardDuty
→ one same account across Regions

Inspector
→ one organization admin

Security Lake
→ management account cannot be DA
```

Always consult current service-specific documentation. ([AWS Documentation][16])

---

# 38.969 Interview trap — disable trusted access to block employees from the service

# Wrong.

Disabling trusted access affects Organizations integration.

It does not remove IAM permissions that users/roles already have to operate the service locally. Use IAM and/or SCPs when you need to restrict principals from the service. ([AWS Documentation][2])

---

# 38.970 Interview trap — Security Hub delegated admin can be changed casually

Wrong when central configuration is involved.

Removing it through Organizations can delete Security Hub CSPM configuration policies and associations and return accounts to self-managed configuration. ([AWS Documentation][7])

Treat the change as a migration.

---

# 38.971 Interview trap — Inspector delegated admin removal disables scans

Wrong.

Current Inspector behavior retains member activation/scan settings when the delegated admin is removed, and Organizations Inspector policies continue to enforce managed enablement. ([AWS Documentation][11])

---

# 38.972 Interview trap — Backup DA automatically manages Backup policies

Wrong.

Backup delegated-administrator registration, IAM permission, and Organizations policy-management delegation are separate concerns. ([AWS Documentation][20])

---

# 38.973 Interview trap — IAM Identity Center delegated admin controls management-account permission sets

Not fully.

Permission sets provisioned for access to the Organizations management account remain protected from modification by the delegated Identity Center administrator. ([AWS Documentation][22])

---

# 38.974 Production delegation design

For our enterprise architecture:

```text
                       AWS ORGANIZATION
                              │
                    MANAGEMENT ACCOUNT
                              │
             trusted access / delegation
                              │
       ┌──────────────────────┼──────────────────────┐
       ▼                      ▼                      ▼

 SECURITY TOOLING           NETWORK              BACKUP
       │                      │                      │
 GuardDuty                  IPAM                 AWS Backup
 Security Hub          Firewall Manager
 Inspector            Network Manager
 Macie
 Detective
 Access Analyzer
 CloudTrail*
       │
       │
       ▼
  LOG ARCHIVE
       │
 Security Lake
 immutable logs
```

`CloudTrail*` administration could sit in Security Tooling/Audit while actual log storage remains in Log Archive.

That separation keeps:

```text
CONTROL

OPERATIONS

EVIDENCE

NETWORK

RECOVERY
```

from collapsing into the management account.

---

# 38.975 New-account delegated-service lifecycle

AFT creates:

```text
payments-prod
```

Then what?

Ideally organization service integrations mean:

```text
Account joins Production OU
      │
      ▼
Organization policies inherited
      │
      ▼
trusted services recognize member
      │
      ├── GuardDuty
      ├── Inspector
      ├── Security Hub
      ├── Backup
      ├── Config
      └── network governance
      │
      ▼
Delegated administrators
gain centralized management visibility
```

This is where Parts 5, 6, 7, and 8 finally join together.

---

# 38.976 Complete organizational control plane

```text
                         MANAGEMENT ACCOUNT
                               │
                               ▼
                         AWS ORGANIZATIONS
                               │
            ┌──────────────────┼───────────────────┐
            │                  │                   │
            ▼                  ▼                   ▼

        TRUSTED ACCESS      POLICIES          DELEGATION
            │                  │                   │
            │             SCP / RCP               │
            │             Backup policy           │
            │             Inspector policy        │
            │                  │                   │
            ▼                  ▼                   ▼
      SERVICE-LINKED      GOVERNANCE         MEMBER ADMIN
          ROLES              LIMITS            ACCOUNTS
            │                                      │
            ▼                                      ▼
      MEMBER ACCOUNTS                       Security / Network
                                            Backup / Identity
```

Think of Organizations as coordinating:

```text
WHO MAY ADMINISTER

WHICH SERVICE

ACROSS WHICH ACCOUNTS

UNDER WHICH POLICIES
```

---

# 38.977 Delegation security checklist

Before designating an account:

```text
□ Does service support delegated admin?

□ Is trusted access required/enabled?

□ Which account should own the duty?

□ Can management account be DA?

□ How many DAs does service support?

□ Is relationship Regional?

□ Same account required across Regions?

□ What IAM permission set do admins need?

□ What SCP protects delegated account?

□ Which service-linked roles are created?

□ What happens when DA is removed?

□ What happens if trusted access is disabled?

□ How will new accounts auto-enroll?

□ How will configuration drift be detected?

□ What break-glass path exists?
```

Use this checklist before every service integration.

---

# 38.978 Never-forget Part 8 rules

```text
1.
Trusted Access lets the AWS service
work with Organizations.


2.
Trusted Access does not grant
ordinary IAM permissions.


3.
Service-linked roles let the service
act inside member accounts.


4.
Delegated Administrator tells AWS
which member account administers
the integrated service.


5.
Delegated administrator
is still a member account.


6.
SCPs still apply to delegated admins.


7.
Management-account SCPs still do not apply.


8.
Prefer service-native integration
setup/cleanup when AWS provides it.


9.
Disabling trusted access
does not necessarily disable the service.


10.
Delegation is service-specific.


11.
There is no universal
delegated-admin count model.


12.
Regional behavior differs
service by service.


13.
GuardDuty uses the same delegated
admin account across Regions.


14.
Inspector uses one delegated admin
and is configured regionally.


15.
Macie uses the same admin
across configured Regions.


16.
Security Hub central configuration
has home/linked Region behavior.


17.
CloudTrail can currently have
multiple delegated admins.


18.
Firewall Manager supports
default + scoped administrators.


19.
Security Lake requires
a member delegated admin.


20.
Backup policy management may require
Organizations policy delegation
in addition to service delegation.


21.
Identity Center delegated admin
cannot freely modify management-account
permission sets.


22.
Delegated accounts are crown jewels.


23.
Monitor trusted access
and delegated admins for drift.


24.
Account onboarding should automatically
inherit service coverage.


25.
Changing delegated admins
is a migration, not a casual toggle.
```

---

# 38.979 Part 8 checkpoint

You can now explain:

```text
✓ Trusted Access

✓ Service-linked roles

✓ AWSServiceRoleForOrganizations

✓ Delegated Administrator

✓ Trusted access vs delegated admin

✓ Delegated admin vs management account

✓ service-specific IAM permissions

✓ SCP interaction

✓ organization integration lifecycle

✓ disabling trusted access

✓ GuardDuty delegated admin

✓ Security Hub delegated admin

✓ Inspector delegated admin

✓ Inspector organization policies

✓ Macie delegated admin

✓ IAM Access Analyzer delegated admin

✓ CloudTrail delegated admins

✓ Config delegated administration

✓ IPAM delegated admin

✓ Firewall Manager multiple admins

✓ AWS Backup delegated admin

✓ Organizations resource-based
  delegation policy

✓ IAM Identity Center delegation

✓ Security Lake delegation

✓ Regional delegation behavior

✓ delegated admin migration

✓ delegation drift monitoring

✓ multi-account troubleshooting
```

---

# ✅ Lesson 38 — Part 8 Complete

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
Central Security + Logging              ✓

Part 6
Network + Shared Services Accounts      ✓

Part 7
Account Factory + AFT                   ✓

Part 8
Delegated Administration                ✓

Part 9
Terraform Governance Capstone           NEXT

Part 10
Final Revision + Interview Mastery
```

# Next — Lesson 38, Part 9

## Terraform Multi-Account Governance Capstone

Now we stop treating each piece separately.

We will build one complete enterprise architecture:

```text
                         AWS ORGANIZATION

                       Management Account
                              │
                              ▼
                            ROOT
                              │
        ┌─────────────────────┼────────────────────┐
        ▼                     ▼                    ▼
   Security OU        Infrastructure OU        Workloads
        │                     │                    │
 Security Tooling          Network              Prod
 Log Archive               Shared               NonProd
                            AFT
```

Then implement the IaC structure for:

```text
Organizations
OUs
Accounts
SCPs
RCP concepts
trusted service access
delegated administrators
IAM Identity Center
Control Tower/AFT integration
RAM
IPAM
TGW
central DNS
security administration
central logging
backup governance
account vending
```

We'll specifically build the **provider-alias and assume-role model**, separate state boundaries, management-account bootstrap vs delegated-account Terraform, a production repository layout, dependency ordering, `for_each` account/OU maps, SCP attachments, delegated-service configuration, cross-account providers, CI/CD execution roles, drift detection, validation commands, failure injection, and finally a **`payments-prod` account from Git request → governed account → network/security/identity ready**.

That will be the practical capstone tying all of **Lesson 38** together.

[1]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_delegated_admin.html?utm_source=chatgpt.com "AWS Organizations"
[2]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html "Using AWS Organizations with other AWS services - AWS Organizations"
[3]: https://docs.aws.amazon.com/organizations/latest/APIReference/API_RegisterDelegatedAdministrator.html?utm_source=chatgpt.com "RegisterDelegatedAdministrator - AWS Organizations"
[4]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html?utm_source=chatgpt.com "Managing GuardDuty accounts with AWS Organizations"
[5]: https://docs.aws.amazon.com/guardduty/latest/ug/set-guardduty-auto-enable-preferences.html?utm_source=chatgpt.com "Setting organization auto-enable preferences"
[6]: https://docs.aws.amazon.com/securityhub/latest/userguide/designate-orgs-admin-account.html?utm_source=chatgpt.com "Integrating Security Hub CSPM with AWS Organizations"
[7]: https://docs.aws.amazon.com/securityhub/latest/userguide/remove-admin-overview.html?utm_source=chatgpt.com "Removing or changing the delegated administrator"
[8]: https://docs.aws.amazon.com/inspector/latest/user/designating-admin.html?utm_source=chatgpt.com "Designating a delegated administrator account for Amazon ..."
[9]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_inspector.html?utm_source=chatgpt.com "Amazon Inspector policies - AWS Organizations"
[10]: https://docs.aws.amazon.com/inspector/latest/user/managing-multiple-accounts.html?utm_source=chatgpt.com "Managing multiple accounts in Amazon Inspector with ..."
[11]: https://docs.aws.amazon.com/inspector/latest/user/remove-delegated-admin.html?utm_source=chatgpt.com "Removing the delegated administrator in Amazon Inspector"
[12]: https://docs.aws.amazon.com/macie/latest/user/accounts-mgmt-ao-notes.html?utm_source=chatgpt.com "Considerations for using Macie with AWS Organizations"
[13]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-delegated-administrator.html?utm_source=chatgpt.com "Delegated administrator for IAM Access Analyzer"
[14]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-getting-started.html?utm_source=chatgpt.com "Permissions required to use IAM Access Analyzer"
[15]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-delegated-administrator.html?utm_source=chatgpt.com "Organization delegated administrator - AWS CloudTrail"
[16]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-settings.html "Configure CloudTrail settings - AWS CloudTrail"
[17]: https://docs.aws.amazon.com/config/latest/developerguide/aggregated-register-delegated-administrator.html?utm_source=chatgpt.com "Registering a Delegated Administrator for AWS Config"
[18]: https://docs.aws.amazon.com/vpc/latest/ipam/enable-integ-ipam.html?utm_source=chatgpt.com "Integrate IPAM with accounts in an AWS Organization"
[19]: https://docs.aws.amazon.com/waf/latest/developerguide/fms-administrators.html "Using AWS Firewall Manager administrators - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[20]: https://docs.aws.amazon.com/aws-backup/latest/devguide/manage-cross-account.html "Managing AWS Backup resources across multiple AWS accounts - AWS Backup"
[21]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_delegate_policies.html "Delegated administrator for AWS Organizations - AWS Organizations"
[22]: https://docs.aws.amazon.com/singlesignon/latest/userguide/delegated-admin.html "Delegated administration - AWS IAM Identity Center"
[23]: https://docs.aws.amazon.com/security-lake/latest/userguide/multi-account-management.html?utm_source=chatgpt.com "Managing multiple accounts with AWS Organizations in ..."
[24]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-v2-set-da.html?utm_source=chatgpt.com "Designating a delegated administrator in Security Hub"
[25]: https://docs.aws.amazon.com/macie/latest/user/accounts-mgmt-ao-integrate.html?utm_source=chatgpt.com "Integrating and configuring an organization in Macie"
