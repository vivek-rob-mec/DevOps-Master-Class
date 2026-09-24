# Module 13 — AWS Production Architecture

# Lesson 38 — AWS Organizations, Control Tower & Multi-Account Governance

## Part 5: Centralized AWS Security, Logging & Audit Architecture

We now have:

```text
AWS Organizations               ✓
SCP / RCP governance            ✓
Control Tower                   ✓
IAM Identity Center             ✓
```

But an enterprise with 100 AWS accounts still has a major question:

> **Where do all security alerts, audit records, vulnerabilities, sensitive-data findings, resource-compliance results, network logs, and incident evidence go—and who is allowed to investigate them?**

If every workload team manages security independently:

```text
Payments Account
├── GuardDuty
├── Inspector
├── CloudTrail
└── logs

Orders Account
├── GuardDuty
├── Inspector
├── CloudTrail
└── logs

Analytics Account
├── GuardDuty
├── Inspector
├── CloudTrail
└── logs

...
```

you eventually create:

```text
security islands
```

instead of an enterprise security program.

AWS's current Security Reference Architecture recommends dedicated **Security Tooling** and **Log Archive** accounts under a Security OU, with security services delegated away from the Organizations management account wherever supported. ([AWS Documentation][1])

---

# 38.409 The enterprise security-account model

Our starting architecture:

```text
                         AWS ORGANIZATION

                              ROOT
                               │
             ┌─────────────────┼───────────────────┐
             │                 │                   │
             ▼                 ▼                   ▼

         Security OU      Infrastructure OU     Workloads OU
             │                                      │
      ┌──────┴────────┐                        ┌────┴─────┐
      ▼               ▼                        ▼          ▼

 Security Tooling   Log Archive              Prod       NonProd
     Account          Account
      │                 │
      │                 │
      ▼                 ▼
 Security services    Immutable/
 administration      controlled logs
      │
      │
      ├── Security Hub
      ├── GuardDuty
      ├── Inspector
      ├── Macie
      ├── Detective
      ├── Access Analyzer
      └── Config aggregation
```

AWS SRA specifically separates a centralized **Security Tooling account** from the **Log Archive account**: the former administers security services and investigations, while the latter is intended as a tightly controlled central log repository. ([AWS Documentation][1])

---

# 38.410 Why two security accounts instead of one?

Because:

```text
SECURITY TOOLING
```

and:

```text
LOG STORAGE
```

have different responsibilities.

### Security Tooling account

People/processes here may:

```text
view findings

investigate incidents

run queries

manage GuardDuty

manage Inspector

manage Security Hub

configure automation

integrate SIEM/SOAR
```

### Log Archive account

Its job should largely be:

```text
receive logs

protect logs

retain logs

archive logs
```

not:

```text
run every security-analysis workload.
```

AWS SRA explicitly recommends this separation, including a model where the Security Tooling account manages CloudTrail while the organization-trail S3 bucket lives in Log Archive. ([AWS Documentation][1])

---

# 38.411 Never-forget distinction

```text
SECURITY TOOLING
=
CONTROL + ANALYSIS


LOG ARCHIVE
=
EVIDENCE
```

That mental model will stay useful across the entire security section.

---

# 38.412 Security account ≠ management account

Bad architecture:

```text
ORGANIZATIONS MANAGEMENT ACCOUNT

Organizations
Control Tower
Billing
Security Hub
GuardDuty
Inspector
Macie
CloudTrail investigations
SOC workloads
SIEM tooling
```

Better:

```text
MANAGEMENT ACCOUNT
      │
      │ delegate
      ▼
SECURITY TOOLING ACCOUNT
      │
      ├── GuardDuty administration
      ├── Inspector administration
      ├── Security Hub administration
      ├── Macie administration
      └── Access Analyzer
```

AWS recommends minimizing use of the Organizations management account and delegating supported security services to member accounts; management-account principals are also not constrained by SCPs, which further strengthens the case for keeping normal security operations out of that account. ([AWS Documentation][2])

---

# 38.413 Delegated Administrator recap

The pattern:

```text
MANAGEMENT ACCOUNT
      │
      │ one-time / rare designation
      ▼

SECURITY TOOLING ACCOUNT

Delegated Administrator
for Service X
      │
      ▼
organization-wide service management
```

Delegation is service-specific.

Being delegated administrator for:

```text
GuardDuty
```

does not automatically make the account delegated administrator for:

```text
Inspector
Security Hub
Macie
CloudTrail
```

Each service has its own Organizations integration and administrative model. ([AWS Documentation][3])

---

# 38.414 Security operating model

Think in four layers:

```text
                     SECURITY OPERATIONS

                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼

       COLLECT              DETECT             RESPOND
          │                   │                   │
      CloudTrail           GuardDuty          EventBridge
      VPC Flow             Inspector           Lambda
      Config               Macie               SSM
      DNS logs             Security Hub        ticket/SIEM
          │                   │                   │
          └───────────────────┼───────────────────┘
                              ▼
                           RETAIN
                              │
                       Log Archive /
                       Security Lake
```

A mature security program needs all four.

---

# 38.415 Logs vs findings

Very important distinction.

### Log

Raw-ish event record:

```text
User X called DeleteBucket
```

or:

```text
10.1.2.3 → 8.8.8.8:443
ACCEPT
```

Examples:

```text
CloudTrail

VPC Flow Logs

Route 53 query logs

application logs
```

---

### Finding

A security service has already interpreted evidence and says:

```text
"This activity appears suspicious."
```

or:

```text
"This EC2 instance has a critical CVE."
```

Examples:

```text
GuardDuty finding

Inspector vulnerability finding

Macie sensitive-data finding

Security Hub control finding
```

Permanent shortcut:

```text
LOG
=
WHAT HAPPENED


FINDING
=
WHY SECURITY THINKS
YOU SHOULD CARE
```

---

# 38.416 CloudTrail — audit foundation

CloudTrail answers:

> **Who called which AWS API, when, from where, against what?**

An AWS Organizations **organization trail** can record events across all accounts in the organization. AWS now also supports a CloudTrail delegated administrator account that can create/manage organization trails and organization event data stores on behalf of the organization. ([AWS Documentation][4])

Architecture:

```text
AWS ORGANIZATION
      │
      ├── Account A
      ├── Account B
      ├── Account C
      └── Account D
             │
             ▼
     ORGANIZATION TRAIL
             │
             ▼
       LOG ARCHIVE S3
```

---

# 38.417 Organization trail vs account trail

Account trail:

```text
ACCOUNT A
  │
  ▼
Trail A
```

Organization trail:

```text
ORGANIZATION
  │
  ├── Account A
  ├── Account B
  ├── Account C
  └── future member accounts
        │
        ▼
organization trail
```

This makes central audit management much easier at scale. ([AWS Documentation][5])

---

# 38.418 CloudTrail delegated administrator

A useful enterprise pattern:

```text
Management Account
      │
      │ delegate
      ▼
Security Tooling
      │
      ▼
Manage organization CloudTrail
      │
      ▼
Logs stored separately
      │
      ▼
Log Archive Account
```

CloudTrail officially supports registering a member account as delegated administrator for organization trails and event data stores. ([AWS Documentation][4])

This gives us:

```text
ADMINISTRATION
≠
STORAGE
```

again.

---

# 38.419 CloudTrail log-protection model

A strong Log Archive bucket may use:

```text
Block Public Access

restrictive bucket policy

KMS encryption

versioning

S3 Object Lock

lifecycle/archive policy
```

AWS S3 security guidance explicitly calls out Object Lock as a way to help protect CloudTrail logs from deletion, and AWS SRA currently recommends versioning, customer-managed encryption, and Object Lock for its central log repository. ([AWS Documentation][6])

---

# 38.420 S3 Object Lock mental model

Normal S3 object:

```text
Write
 ↓
Modify/Delete
```

Object Lock:

```text
Write
 ↓
Retention / Legal Hold
 ↓
WORM-style protection
 ↓
cannot normally delete/overwrite
during protected period
```

AWS describes S3 Object Lock as a **write-once-read-many (WORM)** mechanism. ([AWS Documentation][7])

---

# 38.421 Why log immutability matters

Imagine attacker gets:

```text
AdministratorAccess
```

in Payments account.

They perform:

```text
CreateBackdoorRole
DownloadSensitiveData
DeleteDatabase
```

Then attempt:

```text
Delete audit logs
```

If centralized evidence sits in:

```text
separate account
+
protected bucket
+
Object Lock
```

forensics becomes much harder to erase.

That's defense in depth.

---

# 38.422 Log Archive permissions

Application developers generally should not have:

```text
s3:DeleteObject
```

on centralized audit buckets.

Even many security analysts might receive:

```text
read/query access
```

without:

```text
delete/change retention.
```

Think separation:

```text
PRODUCERS
→ write logs


ANALYSTS
→ read evidence


ARCHIVE ADMINS
→ tightly controlled retention management
```

---

# 38.423 Retention is a policy decision

Don't retain everything forever merely because:

```text
"security"
```

Ask:

```text
regulation?

forensics requirement?

storage cost?

data classification?

legal hold?

business retention policy?
```

CloudTrail and S3 documentation both support using lifecycle policies to transition or delete records according to your required retention model. ([AWS Documentation][8])

---

# 38.424 AWS Config — configuration history

CloudTrail answers:

```text
Who changed something?
```

AWS Config helps answer:

```text
What did this resource configuration
look like before and after?
```

Config records resource configuration and relationships over time and evaluates resources against Config rules. ([AWS Documentation][9])

Example:

```text
Security Group

09:00
22 allowed only from corporate CIDR

09:14
0.0.0.0/0 added

09:37
rule removed
```

Config provides configuration-state history useful for audit and compliance investigation.

---

# 38.425 CloudTrail vs Config

```text
CLOUDTRAIL
=
WHO DID WHAT API ACTION?


CONFIG
=
WHAT CONFIGURATION DID
THE RESOURCE HAVE?
```

Use both.

---

# 38.426 AWS Config Aggregator

At enterprise scale:

```text
100 accounts
×
10 Regions
```

you don't want to inspect Config account by account.

A Config aggregator can collect configuration and compliance data from multiple AWS accounts and Regions into a central view. It can use AWS Organizations as its source so individual member authorizations don't have to be configured separately. ([AWS Documentation][10])

Architecture:

```text
Account A / Mumbai ─┐
Account A / SG      │
Account B / Mumbai  │
Account B / SG      │
Account C / Mumbai  ├──► CONFIG AGGREGATOR
Account C / SG      │
                    │
                    ▼
             Security Tooling
```

---

# 38.427 Aggregation does not enable Config recording

This is a useful conceptual distinction:

```text
CONFIG RECORDER
=
collect configuration in source account/Region


CONFIG AGGREGATOR
=
centralize already-produced
configuration/compliance data
```

Aggregation is not a substitute for enabling appropriate Config recording at source.

---

# 38.428 Organization Config rules

Organizations integration can also help deploy:

```text
Config rules

Conformance packs
```

across accounts.

AWS Organizations currently supports organization-wide AWS Config rule/conformance-pack administration and allows delegated administration for aggregation. ([AWS Documentation][3])

This complements:

```text
Control Tower detective controls.
```

---

# 38.429 Security Hub — central security posture/finding layer

Think:

# **Security Hub = security findings + posture aggregation/control plane.**

Security Hub CSPM can aggregate findings from services including GuardDuty, Inspector, and Macie and normalize supported findings into the **AWS Security Finding Format (ASFF)**. ([AWS Documentation][11])

Architecture:

```text
GuardDuty ──────┐
Inspector ──────┤
Macie ──────────┤
Config/Controls ┤
third party ────┘
                │
                ▼
          SECURITY HUB
                │
         normalized findings
                │
                ▼
        Security Operations
```

---

# 38.430 Security Hub is not the same as CloudTrail

CloudTrail:

```text
millions of API events
```

Security Hub:

```text
security findings/posture results
```

Don't ship all CloudTrail records into Security Hub and assume that's its role.

Think:

```text
CloudTrail
=
audit-event history


Security Hub
=
security finding/posture aggregation
```

---

# 38.431 ASFF

Security Hub CSPM normalizes incoming findings into:

# AWS Security Finding Format — ASFF

That gives different producers a standardized structure for fields such as:

```text
severity

resource

account

Region

workflow state

finding type
```

AWS currently uses ASFF for Security Hub CSPM finding normalization and automation. ([AWS Documentation][12])

Mental shortcut:

```text
Different security tools
      │
      ▼
ASFF
      │
      ▼
common finding model
```

---

# 38.432 Security Hub delegated administrator

The Organizations management account can designate a member account—commonly Security Tooling—as delegated Security Hub administrator. AWS recommends keeping the same delegated administrator across Regions/security services when practical for consistent governance. ([AWS Documentation][13])

Architecture:

```text
Management Account
      │
      ▼
Security Tooling
      │
Delegated Security Hub Admin
      │
      ▼
member-account findings
```

---

# 38.433 Security Hub central configuration

Modern Security Hub CSPM supports:

# Central Configuration

The delegated administrator can centrally define:

```text
whether Security Hub CSPM is enabled

which standards are enabled

which controls are enabled
```

for:

```text
Root

OUs

specific accounts
```

across a home Region and linked Regions. ([AWS Documentation][14])

---

# 38.434 Configuration-policy mental model

```text
Security Hub Delegated Admin
        │
        ▼
Configuration Policy
        │
        ├── Root
        │
        ├── Production OU
        │
        └── NonProd OU
```

Example:

```text
PRODUCTION

Enable:
AWS Foundational Security Best Practices
required controls


SANDBOX

different selected controls
```

New accounts can inherit policy from Root/OU association. ([AWS Documentation][15])

---

# 38.435 Security Hub home Region

Security Hub CSPM can designate a:

```text
Home Region
```

plus:

```text
Linked Regions.
```

The home Region becomes both the central configuration Region and the aggregation location for cross-Region posture/finding data. ([AWS Documentation][16])

For our architecture:

```text
Security Hub Home:
ap-south-1

Linked:
ap-southeast-1
```

could be a logical model if those Regions align with the enterprise's security design.

---

# 38.436 Cross-Region aggregation

Security Hub CSPM can replicate to its home Region:

```text
findings

insights

control-compliance status

security scores
```

from linked Regions. ([AWS Documentation][17])

So:

```text
Singapore GuardDuty finding
      │
      ▼
Security Hub Singapore
      │
      ▼
cross-Region aggregation
      │
      ▼
Security Hub home Region
```

Security analysts obtain a consolidated Regional view.

---

# 38.437 GuardDuty — threat detection

Think:

# **GuardDuty = managed threat detection from AWS telemetry.**

We don't need to feed it manually with:

```text
antivirus signatures.
```

Instead, GuardDuty analyzes supported AWS telemetry and protection-plan data to identify suspicious activity.

For our governance discussion, the critical concept is:

```text
organization management
+
delegated administration.
```

GuardDuty supports an Organizations delegated administrator that can manage member-account status and protection-plan configuration. ([AWS Documentation][18])

---

# 38.438 GuardDuty organization architecture

```text
                  SECURITY TOOLING
                 GuardDuty Admin
                       │
           ┌───────────┼───────────┐
           ▼           ▼           ▼

       Payments      Orders     Analytics
       GuardDuty     GuardDuty   GuardDuty
           │           │           │
           └───────────┼───────────┘
                       ▼
                    FINDINGS
```

---

# 38.439 GuardDuty is Regional

Important.

GuardDuty's delegated administrator relationship is **Regional**.

If you designate Security Tooling only in:

```text
ap-south-1
```

you have not automatically created the same delegated-admin setup in every other Region. AWS recommends repeating the designation in each Region where GuardDuty is enabled. ([AWS Documentation][18])

Permanent rule:

```text
Organizations
=
global-ish account hierarchy


GuardDuty
=
regional security service
```

---

# 38.440 GuardDuty auto-enable

Organization configuration can define GuardDuty auto-enable behavior such as:

```text
ALL

NEW

NONE
```

for member accounts, and protection plans can have their own organization settings. ([AWS Documentation][19])

Example:

```text
ALL

existing accounts ✓
new accounts      ✓
```

versus:

```text
NEW

future accounts ✓
existing accounts require
their current state to be considered
```

---

# 38.441 Why auto-enable matters

Without it:

```text
Create new AWS account
      │
      ▼
developer deploys workload
      │
      ▼
3 months later
      │
      ▼
"Oops, GuardDuty was never enabled."
```

With organizational onboarding:

```text
Account Factory
      │
      ▼
new account
      │
      ▼
security organization policy
      │
      ▼
GuardDuty enabled/configured
```

This is security-by-default.

---

# 38.442 Amazon Inspector — vulnerability management

Think:

# **Inspector = continuously identify software vulnerabilities/exposure for supported compute artifacts/workloads.**

Current Inspector multi-account capabilities include scanning/finding management for supported resource types such as:

```text
EC2

ECR

Lambda
```

and the delegated administrator can view aggregated findings and manage scan activation for organization members. ([AWS Documentation][20])

---

# 38.443 GuardDuty vs Inspector

Do not confuse them.

```text
GUARDDUTY

"Is suspicious or malicious
activity happening?"


INSPECTOR

"What known vulnerabilities/exposure
exist in my compute/software?"
```

Examples:

```text
GuardDuty:
unusual credential activity


Inspector:
critical OpenSSL CVE
in container image
```

Different problems.

---

# 38.444 Inspector delegated administrator

Organizations management account:

```text
designates
      │
      ▼
Security Tooling
      │
      ▼
Inspector delegated admin
      │
      ▼
organization-wide scan/finding management
```

Amazon Inspector officially supports delegated administrator centralized organization management. ([AWS Documentation][21])

---

# 38.445 Modern Inspector organization policies

Current AWS Organizations also supports **Amazon Inspector policies** that can centrally define where Inspector and scan types are automatically enabled across:

```text
Root

OU

Account
```

for existing and new accounts. ([AWS Documentation][22])

This is a newer, strong enterprise governance pattern:

```text
Production OU
      │
      ▼
Inspector organization policy
      │
      ▼
EC2/ECR/Lambda scanning configuration
```

---

# 38.446 CI/CD + Inspector

Remember our ECR pipelines.

Concept:

```text
Developer pushes code
      │
      ▼
container image
      │
      ▼
ECR
      │
      ▼
Inspector scanning
      │
      ▼
finding
      │
      ▼
Security Hub / pipeline decision
```

Now vulnerability detection becomes part of artifact governance, not a yearly security exercise.

---

# 38.447 Amazon Macie — sensitive-data security

Think:

# **Macie = S3 data-security and sensitive-data discovery.**

In a multi-account organization, a delegated Macie administrator can centrally assess S3 security posture and sensitive-data discovery across associated member accounts. ([AWS Documentation][23])

Examples:

```text
PII

credentials

financial data

other sensitive patterns
```

depending on managed/custom data identifiers and discovery configuration.

---

# 38.448 Macie organization architecture

```text
Security Tooling
   Macie Admin
       │
       ├── Payments S3
       ├── Orders S3
       ├── Analytics S3
       └── Data Lake S3
              │
              ▼
       sensitive-data findings
```

---

# 38.449 Macie is also Regional

Macie organization administration is configured Regionally; AWS requires the same delegated Macie administrator across the Regions where the organization uses Macie. ([AWS Documentation][24])

So again:

```text
delegated administrator
```

does not always mean:

```text
one global switch
for every security service.
```

Always verify service regionality.

---

# 38.450 GuardDuty vs Inspector vs Macie

Memorize:

| Service   | Main question                                        |
| --------- | ---------------------------------------------------- |
| GuardDuty | Is suspicious activity occurring?                    |
| Inspector | What software vulnerabilities/exposure exist?        |
| Macie     | Where is sensitive data in S3 and how is it exposed? |

That's a very useful certification/interview distinction.

---

# 38.451 Amazon Detective

Detective is useful for:

```text
investigation

entity relationships

behavior context

finding investigation
```

rather than being your initial organization-wide policy guardrail.

AWS still supports a Detective organization administrator/delegated administrator relationship and organization behavior graphs in 2026. ([AWS Documentation][25])

Mental model:

```text
GuardDuty finding
      │
      ▼
"Something looks suspicious."
      │
      ▼
Detective
      │
      ▼
"What related entities/activity
help explain what happened?"
```

---

# 38.452 Detection vs investigation

```text
GUARDDUTY
=
DETECT


DETECTIVE
=
INVESTIGATE
```

Security Hub can also allow analysts to pivot from GuardDuty findings into Detective investigations. ([AWS Documentation][11])

---

# 38.453 IAM Access Analyzer

Think:

> **Who can access my resources—and is that access inside or outside my intended trust boundary?**

An external-access analyzer defines a:

# Zone of trust.

This can be:

```text
one account
```

or:

```text
entire AWS Organization.
```

IAM Access Analyzer analyzes supported resource policies and reports access from principals outside the selected zone of trust. ([AWS Documentation][26])

---

# 38.454 Organization as trust zone

If analyzer trust zone:

```text
o-company
```

then:

```text
Payments Account → Orders Account
```

is internal to the organization.

But:

```text
Unknown external AWS account
→ Payments S3 bucket
```

may generate an external-access finding if supported resource-policy analysis determines external access exists. ([AWS Documentation][27])

---

# 38.455 Access Analyzer delegated administrator

IAM Access Analyzer supports an Organizations delegated administrator so a member account—commonly Security Tooling—can create/manage organization-level analyzers. ([AWS Documentation][28])

Architecture:

```text
Management
   │
   ▼
Security Tooling
Access Analyzer delegated admin
   │
   ▼
Organization = zone of trust
   │
   ▼
External access findings
```

---

# 38.456 External vs internal vs unused access

Modern IAM Access Analyzer capabilities include multiple analysis types.

Think broadly:

```text
EXTERNAL ACCESS

Who outside the trust zone
can reach our resources?


INTERNAL ACCESS

Which internal principals
can access resources?


UNUSED ACCESS

Which permissions/credentials
haven't been used?
```

AWS currently supports organization-level dashboards/analyzers for these analysis categories, though Regional behavior differs by analyzer type. ([AWS Documentation][29])

---

# 38.457 Access Analyzer is Regional for resource access

For external/internal resource-access analysis, IAM Access Analyzer is Regional and should be configured in the relevant Regions. AWS explicitly notes this, while unused-access analysis does not require creating analyzers in every resource Region in the same way. ([AWS Documentation][30])

Again:

```text
security-service regionality
```

must be designed deliberately.

---

# 38.458 Security Hub as central findings plane

Now combine:

```text
GuardDuty ────┐
Inspector ────┤
Macie ────────┤
security controls
third parties ┘
              │
              ▼
        SECURITY HUB
              │
              ▼
          Findings
              │
      ┌───────┼────────┐
      ▼       ▼        ▼
   SOC UI  EventBridge SIEM
```

Security Hub CSPM explicitly aggregates findings from multiple AWS security services. ([AWS Documentation][11])

---

# 38.459 Security Hub is not a SIEM replacement by definition

Security Hub is excellent for:

```text
AWS security findings

security standards

control posture

normalization

finding workflow
```

A SIEM often goes broader:

```text
AWS logs

on-prem logs

identity-provider logs

endpoint telemetry

firewalls

SaaS

correlation

threat hunting

long-term analytics
```

This is one place Amazon Security Lake can help bridge AWS and wider security analytics.

---

# 38.460 Security Lake

Think:

# **Amazon Security Lake = centralized security data lake using OCSF.**

Security Lake collects supported AWS and custom/third-party security data, normalizes native AWS sources to the **Open Cybersecurity Schema Framework (OCSF)**, and stores the data in Apache Parquet format in S3-based data lakes. ([AWS Documentation][31])

Architecture:

```text
CloudTrail ──────┐
VPC Flow Logs ───┤
Route53 DNS ─────┤
EKS Audit ───────┤
WAF ─────────────┤
Security Hub ────┤
Third Party ─────┘
                 │
                 ▼
            SECURITY LAKE
                 │
               OCSF
                 │
              Parquet
                 │
                 ▼
                 S3
```

---

# 38.461 OCSF

# Open Cybersecurity Schema Framework

Mental model:

```text
AWS Log A
format A

Firewall Log
format B

Identity Log
format C

      │
      ▼
     OCSF
      │
      ▼
common security schema
```

Security Lake uses OCSF as the normalization model for supported data sources. ([AWS Documentation][31])

---

# 38.462 Why normalization matters

Without a common schema:

```text
source_ip

srcIP

sourceAddress

client_ip
```

may all mean approximately:

```text
where did the connection come from?
```

Security analysts spend enormous effort transforming data.

OCSF aims to make security data easier to correlate across producers.

---

# 38.463 Current native Security Lake AWS sources

AWS currently documents native collection for sources including:

```text
CloudTrail management events

CloudTrail S3/Lambda data events

EKS audit logs

Route 53 Resolver query logs

Security Hub CSPM findings

VPC Flow Logs

WAFv2 logs
```

along with custom/third-party sources. ([AWS Documentation][32])

Don't memorize that as a permanent exhaustive list; service integrations continue to evolve.

---

# 38.464 Security Lake organization administration

Security Lake integrates with AWS Organizations through a delegated administrator.

The delegated administrator can:

```text
enable/configure collection
for member accounts

collect logs across enabled Regions

automatically include new accounts

configure subscribers
```

AWS requires the management account to designate the Security Lake delegated administrator and currently does **not** allow the management account itself to serve as that delegated administrator. ([AWS Documentation][33])

---

# 38.465 Which account for Security Lake?

AWS SRA currently recommends using:

# **Log Archive**

as the delegated Security Lake administrator, while security analysts/tools can consume that data from Security Tooling as subscribers. ([AWS Documentation][1])

Concept:

```text
LOG ARCHIVE
Security Lake data owner
       │
       ▼
Security Lake
       │
       │ subscriber
       ▼
SECURITY TOOLING
SIEM / Analysts / Detection
```

Excellent separation.

---

# 38.466 Security Lake vs Log Archive bucket

They overlap conceptually but aren't identical.

### Traditional central archive

```text
raw service logs
→ central S3
```

### Security Lake

```text
security-focused sources
→ normalized OCSF
→ Parquet
→ governed subscriber/query model
```

You might use both as part of one enterprise architecture depending on compliance and analytics needs.

---

# 38.467 Security Lake vs Security Hub

Another very important distinction.

```text
SECURITY HUB

security findings/posture
high-level security issues


SECURITY LAKE

large-volume security
logs/events/findings data
for analytics/hunting
```

Think:

```text
Hub
=
FINDINGS


Lake
=
DATA
```

---

# 38.468 SOC / SIEM integration

A common production pattern:

```text
                     AWS SECURITY SOURCES
                             │
                             ▼
                        Security Lake
                             │
                  ┌──────────┴─────────┐
                  ▼                    ▼

               Athena              SIEM/MDR
                                   subscriber
```

Security Lake supports subscriber integrations that can consume OCSF/Parquet data and supports query access patterns using services such as Athena and Redshift as well as third-party integrations. ([AWS Documentation][32])

---

# 38.469 EventBridge security automation

Security Hub findings can flow into:

# Amazon EventBridge.

Current Security Hub documentation says new and updated findings are sent to EventBridge in near real time, enabling automated response rules. ([AWS Documentation][34])

Architecture:

```text
GuardDuty finding
      │
      ▼
Security Hub
      │
      ▼
EventBridge
      │
 ┌────┼───────────┐
 ▼    ▼           ▼
SNS  Lambda      SSM
```

---

# 38.470 Security-response example

Finding:

```text
CRITICAL

Compromised EC2 suspected
```

EventBridge:

```text
Severity = CRITICAL

ResourceType = EC2
```

Target:

```text
Lambda
```

Action:

```text
Tag instance
      │
      ▼
isolate security group
      │
      ▼
capture forensic metadata
      │
      ▼
open incident
```

This is:

# SOAR-style automation

Security Orchestration, Automation and Response.

---

# 38.471 Automate carefully

Bad:

```text
Any GuardDuty finding
      │
      ▼
Terminate EC2 immediately
```

You may destroy:

```text
forensic evidence

business service

incident context
```

Better:

```text
Finding
   ↓
classify severity/confidence
   ↓
enrich context
   ↓
safe containment
   ↓
approval if destructive
   ↓
remediation
```

The same Lesson 37 principle applies:

```text
DETECT
≠
DECIDE
≠
ACT
```

---

# 38.472 Example containment instead of destruction

Rather than:

```text
TerminateInstance
```

consider incident-specific containment such as:

```text
attach quarantine SG

remove from load balancer

disable compromised credential

snapshot volumes

preserve logs

block network path
```

depending on response playbook.

Security automation should preserve evidence where practical.

---

# 38.473 Security Hub automation rules

Security Hub supports automation rules that can automatically modify finding fields such as:

```text
severity

workflow status
```

based on matching criteria. ([AWS Documentation][35])

Example:

```text
Finding from approved pentest account
      │
      ▼
lower severity / suppress workflow

Finding against prod payment DB
      │
      ▼
raise priority
```

This reduces manual triage.

---

# 38.474 Finding state is not resource state

Suppose Security Hub finding:

```text
Workflow:
RESOLVED
```

That doesn't necessarily mean:

```text
resource vulnerability is physically fixed
```

unless your workflow/process guarantees it.

Always distinguish:

```text
finding workflow state
```

from:

```text
actual resource remediation.
```

---

# 38.475 Central security workflow

```text
FINDING
   │
   ▼
Security Hub
   │
   ▼
Enrichment
   │
   ▼
Severity / priority
   │
   ▼
EventBridge
   │
   ▼
Ticket / SIEM / Pager
   │
   ▼
Investigation
   │
   ▼
Containment
   │
   ▼
Remediation
   │
   ▼
Validation
   │
   ▼
Close finding
```

That's an operational security lifecycle.

---

# 38.476 Application team still has responsibility

Centralized security does not mean:

```text
Security Team
fixes every application CVE.
```

Better ownership model:

```text
SECURITY

detect
prioritize
govern
escalate
guide


APPLICATION TEAM

patch
deploy
validate
```

Example:

```text
Inspector:
Critical image CVE
       │
       ▼
Security Team triages
       │
       ▼
Payments Team fixes Docker image
       │
       ▼
CI/CD rebuilds
       │
       ▼
Inspector rescans
```

---

# 38.477 Security Hub vs Control Tower controls

They are related but distinct.

Control Tower:

```text
landing-zone governance controls
```

Security Hub CSPM:

```text
security posture standards
+
control findings
+
finding aggregation
```

Some concepts/resources overlap through Config and security standards, but don't treat the services as interchangeable.

---

# 38.478 Config vs Security Hub controls

Config:

```text
Resource configuration compliance engine
```

Security Hub:

```text
Security control/standard posture
+
findings aggregation
```

A Security Hub security control may use AWS Config-based evaluation underneath for certain resources.

You usually consume the security-oriented posture through Security Hub and broader configuration governance through Config.

---

# 38.479 Security control hierarchy

A mature architecture can layer:

```text
SCP / RCP
    │
    ▼
PREVENT bad actions

Control Tower
    │
    ▼
landing-zone governance

Config
    │
    ▼
configuration compliance

Security Hub
    │
    ▼
security posture/findings

GuardDuty/Inspector/Macie
    │
    ▼
specialized detection
```

No single tool solves every problem.

---

# 38.480 Preventive vs detective security

Example requirement:

> Production S3 should not become public.

Possible layers:

```text
S3 Block Public Access

SCP/RCP

Control Tower preventive controls

Security Hub detective controls

Config rules

IAM Access Analyzer
```

Defense in depth means:

```text
prevent
+
detect
+
audit
```

not one magical setting.

---

# 38.481 Security services and regionality

This is a major enterprise lesson.

Some organizational security capabilities are:

```text
regional

multi-Region configurable

global-ish organization integration
```

For example, GuardDuty's delegated administrator is Region-specific; Macie administration is Regional; IAM Access Analyzer resource analyzers are Regional; Security Hub CSPM can use a home/linked-Region aggregation model. ([AWS Documentation][18])

So when someone says:

> "Security is enabled in the organization."

ask:

> **In which Regions?**

---

# 38.482 Our Mumbai/Singapore security architecture

For the production/DR architecture:

```text
PRIMARY
ap-south-1

DR
ap-southeast-1
```

you want relevant security services active/configured in both.

Conceptually:

```text
              SECURITY TOOLING

        ┌────────────┴────────────┐
        ▼                         ▼

   ap-south-1                ap-southeast-1

   GuardDuty                  GuardDuty
   Inspector                  Inspector
   Macie where used           Macie where used
   Access Analyzer            Access Analyzer
   Security Hub               Security Hub
        │                         │
        └──────────┬──────────────┘
                   ▼
         Security Hub Home
         cross-Region view
```

This prevents the DR Region from becoming a security blind spot.

---

# 38.483 Security parity is DR parity

Remember Part 3's principle:

```text
Application DR ✓
Security governance ✕
```

is incomplete DR.

If Singapore becomes primary during disaster, it must also have:

```text
threat detection

vulnerability scanning

audit logs

centralized findings

network logs

incident response
```

working.

Security needs to survive the same failover.

---

# 38.484 VPC Flow Logs

For network investigations:

```text
source

destination

ports

protocol

accept/reject

traffic metadata
```

are extremely useful.

Concept:

```text
Workload VPC
     │
     ▼
VPC Flow Logs
     │
     ▼
central logging / Security Lake / analytics
```

Security Lake currently supports VPC Flow Logs as a native source. ([AWS Documentation][32])

---

# 38.485 Route 53 Resolver query logs

DNS often reveals:

```text
malware callbacks

unexpected domains

internal service usage

exfiltration behavior
```

Security Lake currently supports Route 53 Resolver query logs as a native source. ([AWS Documentation][36])

Combine:

```text
DNS
+
Flow Logs
+
CloudTrail
```

for much stronger investigations.

---

# 38.486 EKS audit logs

In Kubernetes-heavy environments, control-plane API activity matters.

Security Lake supports:

```text
EKS audit logs
```

as a native source. ([AWS Documentation][32])

So:

```text
kubectl / API action
      │
      ▼
EKS audit event
      │
      ▼
Security Lake
```

can become part of the broader security-data estate.

---

# 38.487 WAF logs

Web attacks are another signal:

```text
SQL injection attempts

bot traffic

malicious IPs

request patterns
```

Security Lake currently supports WAFv2 logs as native input. ([AWS Documentation][36])

Now you can correlate:

```text
WAF request
      │
      ▼
application/API behavior
      │
      ▼
CloudTrail/GuardDuty finding
```

during an investigation.

---

# 38.488 Central logging design

A mature logging architecture might look like:

```text
                   ORGANIZATION ACCOUNTS

                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼

    CloudTrail      VPC/DNS logs      App/Security logs
        │                │                │
        └────────────────┼────────────────┘
                         ▼
                   LOG ARCHIVE
                         │
                 immutable retention
                         │
             ┌───────────┴────────────┐
             ▼                        ▼

       Traditional S3            Security Lake
         raw archive               OCSF data
             │                        │
             └────────────┬───────────┘
                          ▼
                  SECURITY TOOLING
                          │
                     SOC / SIEM
```

Different security consumers can work from the appropriate layer.

---

# 38.489 Don't centralize all application logs blindly

If every:

```text
DEBUG

TRACE

HTTP request body
```

from every application is retained forever in the central security archive:

```text
cost explodes
```

and you may centralize unnecessary sensitive data.

Log strategy should classify:

```text
security logs

audit logs

operational logs

application debug logs

regulated data
```

and assign appropriate:

```text
retention

access

masking

destination
```

policies.

---

# 38.490 Logging can leak secrets

Bad application:

```text
POST /login

password=supersecret
```

and code logs:

```text
Request body:
password=supersecret
```

Now your secure central log archive contains:

```text
credentials.
```

Centralization does not fix insecure logging practices.

Application teams should avoid logging:

```text
passwords

access tokens

private keys

unnecessary PII

full payment data
```

according to workload requirements.

---

# 38.491 Encryption keys

Central logs and security data are often encrypted with KMS.

Then ask:

```text
Who controls KMS key policy?

Who can decrypt?

Can workload admins modify key policy?

Can incident responders decrypt?

Will cross-account log delivery work?
```

A secure log bucket with a broken KMS policy becomes:

```text
very secure unusable evidence.
```

Security availability still matters.

---

# 38.492 Log-delivery permissions

CloudTrail organization trails need the destination S3/KMS policies to permit the expected delivery path.

AWS specifically recommends including `aws:SourceArn` restrictions in S3/KMS/SNS policies used for organization trails where appropriate, reducing overly broad service access. ([AWS Documentation][37])

Mental principle:

```text
Allow service delivery
```

but constrain:

```text
which source resource
is allowed to use that permission.
```

---

# 38.493 Security tooling itself needs least privilege

Do not create:

```text
SOCAnalyst
=
AdministratorAccess
```

merely because security teams investigate incidents.

Instead separate roles:

```text
SecurityReadOnly

ThreatHunter

IncidentResponder

ForensicAdmin

SecurityServiceAdmin
```

Then use stronger access only when required.

Security teams are also subject to least privilege.

---

# 38.494 Security analyst vs incident responder

Example:

### Analyst

```text
read Security Hub

read GuardDuty

query Security Lake

read CloudTrail
```

### Incident Responder

May additionally:

```text
quarantine instance

disable key

revoke sessions

modify SG

isolate workload
```

These are very different risk levels.

---

# 38.495 Break-glass security role

A severe incident might require:

```text
OrganizationIncidentResponse
```

with powerful emergency permissions.

But as with Identity Center:

```text
rarely used

strong MFA

short session

approval

alerting

post-use review
```

should surround it.

The emergency role is not a normal work role.

---

# 38.496 Protect the security services themselves

Production OU guardrails may deny ordinary application administrators from actions such as:

```text
disabling GuardDuty

disabling Inspector

removing Config

deleting CloudTrail

modifying security-owned resources
```

depending on the exact governance model.

This is where Part 2's SCP design becomes directly useful.

---

# 38.497 Security-service protection flow

```text
Application Admin

AdministratorAccess
      │
      ▼
tries DisableSecurityControl
      │
      ▼
SCP
      │
      X
DENIED
```

Even local account admins cannot casually turn off central security visibility if the organization guardrail is correctly designed.

---

# 38.498 Beware blocking security service-linked roles

Remember Part 2:

```text
Service-linked roles
```

can be treated specially with organization policies.

Don't write simplistic blanket guardrails that accidentally break security-service operation.

Always test organization policies against:

```text
security services

backup

logging

Control Tower

AWS Config

automation
```

before Root-wide deployment.

---

# 38.499 New-account security onboarding

Ideal lifecycle:

```text
Developer requests account
      │
      ▼
Account Factory / AFT
      │
      ▼
new member account
      │
      ├── Control Tower baseline
      ├── Identity assignments
      ├── GuardDuty
      ├── Inspector
      ├── Config
      ├── Security Hub
      ├── CloudTrail
      ├── central logs
      └── network onboarding
```

The goal is:

> **A new account is secure by default before the application team starts using it.**

---

# 38.500 Account onboarding should be idempotent

If account security onboarding pipeline runs twice:

```text
run #1
GuardDuty enable

run #2
GuardDuty enable
```

it should converge safely.

Do not create automation that produces:

```text
duplicate trails

duplicate aggregators

duplicate SIEM subscriptions

conflicting policies
```

on reruns.

Platform/security automation needs the same idempotency principles as application automation.

---

# 38.501 Security finding ownership

Every finding needs:

```text
owner

severity

SLA

workflow
```

Example:

| Finding                         | Owner                        |
| ------------------------------- | ---------------------------- |
| Inspector critical CVE          | Application team             |
| Macie public sensitive bucket   | Data/app owner + Security    |
| GuardDuty credential compromise | Incident response            |
| Access Analyzer external trust  | Resource owner + Security    |
| Security Hub control failure    | Platform/security governance |

Centralizing findings without ownership merely creates a giant queue.

---

# 38.502 Severity is not priority

Suppose:

```text
Critical CVE
```

on:

```text
isolated test instance
scheduled for destruction
```

versus:

```text
High-severity credential finding
```

against:

```text
production payment administrator.
```

Priority must incorporate:

```text
severity

asset criticality

internet exposure

data sensitivity

exploitability

business context
```

not severity label alone.

---

# 38.503 Security context enrichment

A useful SOC pipeline enriches findings with:

```text
Account

OU

Environment

Application

Owner

CostCenter

DataClassification

InternetFacing

Region
```

Then:

```text
Inspector finding
```

becomes:

```text
CRITICAL

Payments-Prod

InternetFacing=true

Owner=Payments-SRE
```

That's far more actionable.

---

# 38.504 Tags become security metadata

This is another reason enterprise tagging matters.

Example:

```text
Environment=Prod
Application=Payments
Owner=PaymentsTeam
DataClassification=PCI
```

Security automation can then route:

```text
PCI critical finding
```

differently from:

```text
Sandbox informational finding.
```

Governance metadata powers automation.

---

# 38.505 EventBridge routing

Example:

```text
Security Hub
      │
      ▼
EventBridge
      │
      ├── Severity CRITICAL + Prod
      │       ↓
      │     Pager
      │
      ├── Inspector + High
      │       ↓
      │     Jira
      │
      └── Macie + SensitiveData
              ↓
          Security queue
```

Security Hub's EventBridge integration supports near-real-time event-driven response to findings. ([AWS Documentation][34])

---

# 38.506 Central EventBridge architecture

In multi-account environments, you can design:

```text
Member security event
      │
      ▼
central finding aggregation
      │
      ▼
Security Tooling EventBridge
      │
      ▼
response automation
```

or controlled cross-account event-bus models depending on the exact service/event design.

Be explicit about:

```text
event source

account

Region

bus permissions

target execution role.
```

---

# 38.507 Automated remediation safety levels

A useful hierarchy:

```text
LEVEL 1
Notify only

LEVEL 2
Open ticket

LEVEL 3
Enrich finding

LEVEL 4
Non-destructive containment

LEVEL 5
Automated remediation

LEVEL 6
Destructive remediation
```

The risk increases as you descend.

Not every finding should automatically reach Level 6.

---

# 38.508 Example safe automatic response

Finding:

```text
IAM access key exposed
```

Possible response:

```text
disable credential

notify owner

capture CloudTrail context

open Sev-1 incident
```

This may be safer than:

```text
delete entire IAM identity
```

because deletion can destroy context or break dependent workloads.

The correct response depends on incident playbook.

---

# 38.509 Forensics account pattern

Larger environments may also use a dedicated:

```text
Forensics Account
```

or tightly controlled investigation environment.

Concept:

```text
Compromised EC2
      │
      ▼
EBS snapshot
      │
      ▼
forensic copy
      │
      ▼
isolated investigation account
```

This prevents analysts from repeatedly inspecting compromised evidence in-place.

The exact account design depends on legal/security requirements.

---

# 38.510 Security Tooling should not become a shared production dependency

Your application should not require:

```text
Security Tooling Account
```

to serve customer requests.

Security tooling is part of:

```text
control/monitoring plane
```

not application serving path.

If Security Hub has a problem:

```text
payments should continue processing
```

while security monitoring may degrade.

This reduces coupling.

---

# 38.511 Security availability vs application availability

Example:

```text
GuardDuty unavailable temporarily
```

Application:

```text
should normally continue.
```

But incident response should recognize:

```text
security visibility degraded.
```

This may trigger:

```text
operational alert
```

without automatically taking production offline.

Different systems have different SLOs.

---

# 38.512 Centralized security blast radius

Centralization gives huge benefits but introduces high-value administrative accounts.

If Security Tooling is compromised:

```text
organization-wide visibility
```

may be at risk.

Therefore it deserves:

```text
strong IAM

restricted network access

short privileged sessions

MFA

SCP protections

CloudTrail

separation of duties

minimal workloads
```

The centralized security account itself is a crown-jewel account.

---

# 38.513 Log Archive is also a crown jewel

Why?

It holds:

```text
evidence of attacker actions

compliance records

network logs

historical API records
```

Attackers may want to destroy it.

Therefore Log Archive should typically have:

```text
very limited human access

no development workloads

strong S3 policies

KMS controls

immutability where needed

alerting on policy/retention changes
```

---

# 38.514 Management / Security / Log Archive triad

Memorize:

```text
MANAGEMENT ACCOUNT
=
organization governance authority


SECURITY TOOLING
=
security operations authority


LOG ARCHIVE
=
security evidence repository
```

Keeping these roles separate creates stronger administrative boundaries.

---

# 38.515 Security Lake subscriber model

Security Lake can give a subscriber controlled access to selected security data.

Concept:

```text
SECURITY LAKE
      │
      ├── Subscriber: Security Tooling
      ├── Subscriber: enterprise SIEM
      └── Subscriber: MDR provider
```

Security Lake manages subscriber access patterns for consuming data stored in the data lake. ([AWS Documentation][33])

This avoids:

```text
give every SIEM
full admin access
to Log Archive.
```

---

# 38.516 Third-party SOC integration

Enterprise could use:

```text
Security Lake
     │
     ▼
third-party SIEM
```

or:

```text
Security Hub findings
     │
     ▼
EventBridge/API
     │
     ▼
SOAR/SIEM
```

These address different data volumes/use cases:

```text
Security Hub
→ prioritized findings


Security Lake
→ broader normalized security data
```

---

# 38.517 Security Hub finding workflow

A typical finding lifecycle:

```text
NEW
 │
 ▼
triaged
 │
 ▼
assigned
 │
 ▼
investigating
 │
 ▼
remediated
 │
 ▼
validated
 │
 ▼
resolved
```

Automation rules can update workflow/severity fields, but technical remediation still needs to be verified. ([AWS Documentation][35])

---

# 38.518 Threat-detection architecture

```text
                    AWS ORGANIZATION
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
     Prod               NonProd            Network
        │                  │                  │
        └──────────────────┼──────────────────┘
                           ▼
                    SECURITY SIGNALS

      ┌─────────────┬────────────┬─────────────┐
      ▼             ▼            ▼             ▼

 GuardDuty      Inspector      Macie     Access Analyzer
      │             │            │             │
      └─────────────┴─────┬──────┴─────────────┘
                          ▼
                     Security Hub
                          │
                ┌─────────┴──────────┐
                ▼                    ▼
           EventBridge          Security Lake
                │                    │
                ▼                    ▼
         Response/SOAR            SIEM/Hunt
```

That's a useful enterprise mental picture.

---

# 38.519 Logging architecture

```text
                      AWS ACCOUNTS

        ┌────────────────┼──────────────────┐
        ▼                ▼                  ▼

    CloudTrail       VPC Flow           DNS/EKS/WAF
        │                │                  │
        └────────────────┼──────────────────┘
                         ▼
                   LOG ARCHIVE
                         │
            ┌────────────┴─────────────┐
            ▼                          ▼
       immutable S3               Security Lake
                                      │
                                      ▼
                                   OCSF
                                      │
                                      ▼
                                 SIEM/Athena
```

AWS currently supports the native Security Lake sources shown earlier and recommends the Log Archive account as the central evidence/security-data location in its SRA pattern. ([AWS Documentation][36])

---

# 38.520 Security governance architecture

Now overlay Control Tower and Organizations:

```text
                    ORGANIZATIONS
                         │
                         ▼
                    SCP / RCP
                         │
                         ▼
                  CONTROL TOWER
                         │
                         ▼
                      CONFIG
                         │
                         ▼
                  SECURITY HUB
                         │
                         ▼
        GuardDuty / Inspector / Macie
```

Mental model:

```text
ORGANIZATIONS
=
what cannot be done


CONTROL TOWER
=
landing-zone controls


CONFIG
=
what configuration exists


SECURITY HUB
=
security posture


SPECIALIZED SERVICES
=
specific security risks
```

---

# 38.521 Security service responsibility map

| Service             | Core mental model                         |
| ------------------- | ----------------------------------------- |
| CloudTrail          | API audit trail                           |
| AWS Config          | Resource configuration history/compliance |
| GuardDuty           | Threat detection                          |
| Inspector           | Vulnerability management                  |
| Macie               | Sensitive-data discovery/security for S3  |
| Security Hub        | Security findings + posture aggregation   |
| Detective           | Investigation/context                     |
| IAM Access Analyzer | Resource/identity access analysis         |
| Security Lake       | Normalized security data lake             |
| EventBridge         | Event-driven response plumbing            |

Memorize the **question each service answers**, not only the service name.

---

# 38.522 Example incident — compromised AWS key

Suppose GuardDuty reports suspicious credential usage.

Flow:

```text
GuardDuty
   │
   ▼
Finding:
suspicious IAM credential use
   │
   ▼
Security Hub
   │
   ▼
EventBridge
   │
   ├── page Security
   ├── invoke containment workflow
   └── create incident
```

Investigator uses:

```text
CloudTrail
```

to ask:

```text
Which APIs did the key call?
```

Config to ask:

```text
What resources changed?
```

Detective to examine related activity/context.

Access Analyzer to inspect newly introduced external trust.

Security Lake/SIEM to correlate wider telemetry.

Now you can see how the services cooperate.

---

# 38.523 Example incident — vulnerable container

Inspector:

```text
ECR image:
payments:v42

Critical CVE
```

Flow:

```text
Inspector
   │
   ▼
Security Hub
   │
   ▼
EventBridge
   │
   ▼
Payments vulnerability queue
   │
   ▼
developer patch
   │
   ▼
CI build v43
   │
   ▼
ECR
   │
   ▼
Inspector rescan
```

Security does not directly SSH into the container and patch it manually.

Immutable delivery remains the better production pattern.

---

# 38.524 Example incident — sensitive S3 data exposed

Macie identifies:

```text
sensitive customer records
```

in an unexpected bucket.

IAM Access Analyzer reports:

```text
external access possible.
```

Security Hub combines findings/context.

EventBridge opens high-priority incident.

Possible remediation:

```text
block external access

correct bucket policy

rotate exposed credentials if needed

notify data owner

investigate CloudTrail accesses
```

Now multiple specialized tools reinforce one another.

---

# 38.525 Example incident — unauthorized network egress

Suppose security detects:

```text
EC2
→ suspicious external IP
```

Investigation may combine:

```text
GuardDuty finding

VPC Flow Logs

Route53 query logs

CloudTrail

application logs
```

Security Lake can centralize several of these telemetry classes in OCSF for hunting/correlation. ([AWS Documentation][32])

---

# 38.526 Cross-account incident response

Security team may need to access:

```text
Payments-Prod

Orders-Prod

Network Account
```

during one incident.

Possible model:

```text
Security Tooling Account

IncidentResponder role
      │
      ├── AssumeRole → Payments
      ├── AssumeRole → Orders
      └── AssumeRole → Network
```

Trust should be:

```text
preconfigured

least privilege

monitored
```

not created during the attack.

---

# 38.527 Preconfigured IR roles

Every workload account might contain:

```text
OrganizationIncidentResponseRole
```

trusted to:

```text
Security Tooling
```

with carefully scoped response permissions.

Then:

```text
Incident
   │
   ▼
Security team assumes known role
```

instead of:

```text
"Who knows the Prod root password?"
```

---

# 38.528 Incident permissions should match actions

Examples:

```text
Read CloudTrail       ✓
Describe EC2          ✓
Snapshot EBS          ✓
Modify SG             maybe
Disable IAM key       maybe
Terminate resource    highly controlled
Delete audit logs     ✕
```

Design IR authorization from your runbooks.

---

# 38.529 Protect against confused-deputy access

When AWS services write centrally, use conditions such as:

```text
aws:SourceArn

aws:SourceAccount
```

where supported.

AWS specifically recommends `aws:SourceArn` in organization-trail resource policies to constrain delivery permissions. ([AWS Documentation][37])

Never rely on:

```text
Principal = AWS service
+
Resource = *
```

without considering whether a tighter condition is available.

---

# 38.530 Security costs matter

Organization security can generate significant costs:

```text
CloudTrail data events

Config recording

GuardDuty protection plans

Inspector scans

Macie discovery jobs

Security Hub controls

Security Lake ingestion/storage

S3 storage

Athena/SIEM queries
```

Do not disable important controls purely for cost.

Instead design:

```text
data scope

retention

high-value telemetry

lifecycle

storage tiers

query efficiency
```

so security spending is intentional.

---

# 38.531 CloudTrail management vs data events

A high-level distinction:

```text
MANAGEMENT EVENT

"Changed the bucket policy"


DATA EVENT

"Read object X"
```

Data events can be extremely valuable but far more numerous.

Security/logging design should decide which high-volume data-event types require collection.

Security Lake currently natively supports CloudTrail management events and selected data-event classes such as S3 and Lambda. ([AWS Documentation][32])

---

# 38.532 Security telemetry tiers

A useful model:

### Tier 1 — always high value

```text
CloudTrail management events

critical IAM/security events

GuardDuty findings
```

### Tier 2 — high-volume security telemetry

```text
VPC Flow Logs

DNS query logs

WAF logs

selected data events
```

### Tier 3 — application-specific

```text
authentication logs

payment security events

application audit records
```

Design retention/analytics separately.

---

# 38.533 Long-term archive vs hot analytics

Do not keep every log in the most expensive query/storage tier forever.

Think:

```text
HOT

recent incidents
fast search
shorter retention

     ↓

WARM

months
regular investigations

     ↓

ARCHIVE

years
compliance/forensics
```

S3 lifecycle/archive policies can support this type of retention architecture. ([AWS Documentation][8])

---

# 38.534 Security Lake helps query efficiency

Security Lake stores normalized data in:

```text
Apache Parquet
```

which is columnar and more analytics-friendly than repeatedly scanning unstructured text logs.

AWS explicitly stores Security Lake native source data in Parquet and OCSF format. ([AWS Documentation][32])

This can materially improve security-data analytics patterns.

---

# 38.535 Don't confuse Security Lake with S3 Glacier

```text
SECURITY LAKE
=
security data organization/
normalization/consumption system


GLACIER STORAGE CLASSES
=
low-cost archival storage tiers
```

One is an analytics/security data service.

One is storage economics.

---

# 38.536 SOC dashboard

A centralized security dashboard might show:

```text
Critical GuardDuty:
5

Critical Inspector:
47

Macie sensitive exposure:
2

Security Hub failed controls:
123

Access Analyzer external findings:
8

Accounts missing expected configuration:
0
```

Then operators drill down by:

```text
Account

OU

Region

Owner

Severity

Application
```

This is why central account metadata matters.

---

# 38.537 Security metrics

Security teams should measure more than:

```text
number of findings.
```

Useful operational metrics:

```text
MTTD
Mean Time To Detect

MTTR
Mean Time To Respond/Remediate

critical finding age

patch SLA compliance

unowned findings

accounts without coverage

security-control pass rate

external-access findings

incident recurrence
```

You cannot improve what you don't measure.

---

# 38.538 "No findings" is not necessarily good

If GuardDuty dashboard says:

```text
0 findings
```

possible interpretations:

```text
No suspicious activity
```

or:

```text
GuardDuty not enabled.
```

or:

```text
wrong Region.
```

or:

```text
member accounts not associated.
```

or:

```text
protection plan disabled.
```

Always verify **coverage**, not only finding count.

---

# 38.539 Coverage dashboard

Track:

```text
100 organization accounts

GuardDuty enabled:
100 / 100

Inspector:
98 / 100 ✕

Security Hub:
100 / 100

Config recording:
100 / 100

CloudTrail:
organization trail healthy

Macie where required:
35 / 35

Access Analyzer Regions:
expected coverage
```

Coverage gaps should generate security-platform alerts.

---

# 38.540 Security account onboarding test

When creating a new account:

```text
AccountCreated
      │
      ▼
wait for baseline
      │
      ▼
validate:

CloudTrail ✓
Config ✓
GuardDuty ✓
Inspector ✓
Security Hub ✓
central log delivery ✓
Identity ✓
network ✓
```

Don't wait for the first attack to discover onboarding failed.

---

# 38.541 Security game day

Remember Lesson 37?

We can apply game days to security.

Scenario:

```text
Compromised administrator credential
```

Inject safely:

```text
controlled API activity
```

Measure:

```text
GuardDuty detection?

Security Hub finding?

EventBridge routed?

on-call paged?

CloudTrail searchable?

incident role works?

containment works?

evidence preserved?
```

Security resilience is testable.

---

# 38.542 Another security game day

Scenario:

```text
S3 bucket policy accidentally
grants external account access
```

Expected:

```text
Access Analyzer detects

Security Hub/other workflow surfaces

owner identified

response triggered

policy fixed

verification passes
```

Game days validate the detection pipeline end-to-end.

---

# 38.543 Don't test with real exfiltration

Security exercises should have controlled blast radius.

Do not:

```text
upload real customer records
to attacker-controlled system
```

just to prove Macie/DLP works.

Use:

```text
synthetic test data

dedicated test accounts

safe controlled findings

documented test mechanisms
```

where possible.

---

# 38.544 Security Hub finding suppression

Not every known/accepted finding should page continuously.

Use controlled:

```text
suppression

workflow state

automation rules
```

but require:

```text
business justification

owner

expiry/review
```

Otherwise:

```text
suppression
```

becomes:

```text
hide security problems forever.
```

Security Hub supports automation rules for changing severity/workflow metadata automatically. ([AWS Documentation][35])

---

# 38.545 Accepted risk

Example:

```text
Legacy application
cannot patch Library X
for 14 days
```

Risk process:

```text
finding
 ↓
business justification
 ↓
compensating control
 ↓
expiry date
 ↓
owner
 ↓
planned remediation
```

Not:

```text
click Suppress
and forget.
```

---

# 38.546 Security finding lifecycle needs SLA

Example:

```text
Critical:
24 hours

High:
7 days

Medium:
30 days
```

These are illustrative only.

Actual SLA should derive from:

```text
risk

regulation

exploitability

business impact.
```

Security Hub severity and Inspector vulnerability severity are prioritization signals, not universal remediation deadlines.

---

# 38.547 Vulnerability ≠ incident

Inspector says:

```text
CVE present
```

That doesn't automatically mean:

```text
attacker exploited it.
```

GuardDuty suspicious behavior also doesn't automatically prove:

```text
full compromise.
```

Security analysis combines:

```text
vulnerability

threat signal

exposure

asset context

behavior
```

to determine risk.

---

# 38.548 Example risk multiplication

```text
Critical CVE
+
internet-facing EC2
+
active exploit known
+
production payment service
```

→ extremely urgent.

Same CVE:

```text
offline lab AMI
never launched
```

→ different operational priority.

Context matters.

---

# 38.549 Security Hub central configuration vs finding aggregation

These are related but distinct concepts.

### Central configuration

```text
What Security Hub settings,
standards, and controls
should accounts/Regions use?
```

### Cross-Region aggregation

```text
Where should findings/posture data
be centrally viewed?
```

Current Security Hub CSPM integrates the two through a home/linked-Region model, but don't confuse their purposes. ([AWS Documentation][16])

---

# 38.550 GuardDuty admin vs Security Hub admin

GuardDuty admin:

```text
manages GuardDuty organization
```

Security Hub admin:

```text
manages Security Hub organization
```

They can be the same:

```text
Security Tooling account
```

and AWS recommends coordinating delegated administrators across security services for consistency, but the registrations remain service-specific. ([AWS Documentation][11])

---

# 38.551 Inspector admin vs Security Hub admin

Same principle.

Inspector findings can flow into Security Hub, but:

```text
Inspector delegated administrator
```

controls Inspector.

```text
Security Hub delegated administrator
```

controls Security Hub.

Integration does not merge the two administrative models.

---

# 38.552 Management account should not be SOC workstation

Because management account has exceptional organization privileges.

A security analyst investigating a suspicious EC2 instance should usually not need:

```text
Organizations management account
```

credentials.

Better:

```text
Security Tooling
```

with delegated permissions.

This follows the AWS SRA delegated-administration pattern. ([AWS Documentation][38])

---

# 38.553 Security Tooling account layout

Conceptually:

```text
SECURITY TOOLING

├── Security Hub
├── GuardDuty admin
├── Inspector admin
├── Macie admin
├── Detective
├── Access Analyzer
├── Config aggregator
├── EventBridge
├── response Lambda/SSM
├── security dashboards
└── SIEM subscriber/integration
```

Don't treat this as a required exact list; choose services according to workload/risk.

---

# 38.554 Log Archive account layout

```text
LOG ARCHIVE

├── CloudTrail archive
├── Config logs/history
├── security log buckets
├── Security Lake
├── Object Lock
├── lifecycle/archive
└── tightly controlled KMS keys
```

AWS SRA currently recommends Log Archive as the Security Lake delegated administrator in its reference pattern. ([AWS Documentation][1])

---

# 38.555 Central security architecture — full diagram

```text
                             AWS ORGANIZATION

                                   │
                ┌──────────────────┼──────────────────┐
                ▼                  ▼                  ▼

           PRODUCTION          NONPROD             NETWORK
             ACCOUNTS          ACCOUNTS             ACCOUNT

                │                  │                  │
                └──────────────────┼──────────────────┘
                                   │
                      SECURITY TELEMETRY/FINDINGS
                                   │
          ┌────────────┬───────────┼──────────┬─────────────┐
          ▼            ▼           ▼          ▼             ▼

      GuardDuty    Inspector     Macie     Config      Access Analyzer
          │            │           │          │             │
          └────────────┴───────────┼──────────┴─────────────┘
                                   ▼
                          SECURITY HUB CSPM
                                   │
                         Home / Linked Regions
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼

               EventBridge                 Security Lake
                    │                             │
        ┌───────────┼───────────┐             OCSF/Parquet
        ▼           ▼           ▼                │
      Pager       Lambda       SIEM              ▼
                             / Ticket           SIEM /
                                             Athena / Hunt


                     LOGGING / EVIDENCE PLANE

          CloudTrail / Flow / DNS / WAF / EKS Audit
                              │
                              ▼
                       LOG ARCHIVE ACCOUNT
                              │
                    KMS + Object Lock +
                     lifecycle retention
```

That's the production security operations model.

---

# 38.556 Security troubleshooting sequence

When security says:

> "We aren't receiving findings from Singapore."

Walk systematically:

```text
1. Is the security service enabled
   in ap-southeast-1?

2. Is the delegated administrator
   designated in that Region if required?

3. Is the member account associated?

4. Is auto-enable/config policy correct?

5. Is the specific protection plan enabled?

6. Does the service/resource type support
   that Region?

7. Is Security Hub enabled in that Region?

8. Is Singapore a linked Security Hub Region?

9. Is cross-Region aggregation configured?

10. Is EventBridge rule in correct Region?

11. Is the central target role authorized?
```

Do not immediately assume:

```text
Security Hub bug.
```

---

# 38.557 Logging troubleshooting sequence

Central CloudTrail missing account:

```text
1. Account still in Organization?

2. Organization trail healthy?

3. Trail includes appropriate event types?

4. S3 bucket policy permits delivery?

5. KMS policy permits encryption?

6. Log Archive bucket available?

7. SCP didn't block an administrator action?

8. Duplicate/conflicting account trails?

9. Correct Region/multi-Region trail settings?

10. CloudTrail event actually in scope?
```

---

# 38.558 Config troubleshooting sequence

Config aggregator missing Region:

```text
1. Is Config recording enabled there?

2. Recorder healthy?

3. Resource type recorded?

4. Account part of Organization?

5. Aggregator Organization source correct?

6. Region included?

7. Delegated admin/IAM role valid?

8. Has data had time to aggregate?
```

AWS lists invalid aggregator IAM roles as one explicit cause of organization aggregation failures. ([AWS Documentation][39])

---

# 38.559 Security Hub troubleshooting

Finding exists in GuardDuty but not central dashboard:

```text
GuardDuty finding
      │
      ▼
Is Security Hub integration enabled?
      │
      ▼
Security Hub enabled locally?
      │
      ▼
admin/member relationship correct?
      │
      ▼
home/linked Region configuration?
      │
      ▼
central aggregation?
```

Security Hub only aggregates from Regions/accounts in which the relevant Security Hub service is enabled/configured. ([AWS Documentation][17])

---

# 38.560 Interview question — Security Tooling vs Log Archive

Strong answer:

> **The Security Tooling account is the operational security account used to centrally administer security services, aggregate findings, and run incident-response tooling. The Log Archive account is a more tightly controlled evidence repository for centralized logs and, in the AWS SRA pattern, can also own Security Lake. Separating administration from immutable evidence reduces blast radius and improves separation of duties.** ([AWS Documentation][1])

---

# 38.561 Interview question — CloudTrail vs Config

```text
CloudTrail
=
API activity history


Config
=
resource configuration history
and compliance
```

Use both during investigations.

---

# 38.562 Interview question — GuardDuty vs Inspector

```text
GuardDuty
=
threat detection


Inspector
=
software vulnerability/exposure management
```

---

# 38.563 Interview question — GuardDuty vs Detective

```text
GuardDuty
=
detect suspicious activity


Detective
=
investigate relationships/context
```

AWS still supports organization-level Detective administrator models in 2026. ([AWS Documentation][40])

---

# 38.564 Interview question — Macie

Strong answer:

> **Amazon Macie is focused on S3 data security and sensitive-data discovery. In Organizations, a delegated administrator can centrally manage Macie and assess the S3 data estate of member accounts.** ([AWS Documentation][41])

---

# 38.565 Interview question — IAM Access Analyzer

Strong answer:

> **IAM Access Analyzer uses policy analysis to identify resource access relative to a defined zone of trust, such as an AWS account or entire AWS Organization. Organization-level analyzers can be managed through a delegated administrator.** ([AWS Documentation][26])

---

# 38.566 Interview question — Security Hub

Strong answer:

> **Security Hub CSPM centralizes security posture and findings, normalizes supported findings into ASFF, can centrally manage standards/controls across an organization, and supports cross-Region aggregation to a home Region.** ([AWS Documentation][12])

---

# 38.567 Interview question — Security Lake

Strong answer:

> **Amazon Security Lake centralizes security logs and events from supported AWS and custom sources, normalizes AWS-native data into OCSF, stores it in Parquet format, and exposes it to subscribers and analytics tools for threat hunting, SIEM integration, and security analytics.** ([AWS Documentation][32])

---

# 38.568 Interview question — Security Hub vs Security Lake

```text
SECURITY HUB
=
findings + security posture


SECURITY LAKE
=
large-scale normalized
security event/log data
```

They complement each other.

---

# 38.569 Interview trap — delegated administrator means global automatically

Wrong.

Many security services remain Region-scoped in important ways.

GuardDuty and Macie, for example, require Region-specific delegated-administrator configuration, while Security Hub CSPM supports a home/linked-Region aggregation model. ([AWS Documentation][18])

---

# 38.570 Interview trap — Security Hub scans vulnerabilities

Not primarily.

Inspector performs vulnerability scanning/management for supported resources.

Security Hub aggregates and normalizes the resulting security findings/posture.

---

# 38.571 Interview trap — Config tells you who changed the security group

Config tells you:

```text
what changed in configuration.
```

CloudTrail is what you typically inspect to determine:

```text
which principal/API call caused it.
```

Together:

```text
CONFIG
+
CLOUDTRAIL
```

produce a stronger investigation.

---

# 38.572 Interview trap — Security Lake replaces CloudTrail

No.

Security Lake may ingest selected CloudTrail events, but CloudTrail remains the AWS API audit service and organization-trail mechanism.

Security Lake is a security data lake/normalization layer.

---

# 38.573 Interview trap — centralized findings mean centralized remediation automatically

No.

Security Hub can:

```text
aggregate

normalize

route
```

but your organization must define:

```text
owners

runbooks

automation

permissions

SLA

response process.
```

A dashboard full of findings is not a security operations program.

---

# 38.574 Interview trap — Object Lock means nobody can ever delete anything

Not necessarily.

Object Lock has different retention modes and configuration semantics. Governance mode, for example, permits specially authorized principals to override retention, while compliance-mode protections are stronger. ([AWS Documentation][7])

Choose according to compliance/risk requirements.

---

# 38.575 Interview trap — enable every service in every account without design

Security coverage is important, but service scope should still be intentional.

Example:

```text
Macie
```

focuses on S3 sensitive-data security; cost/scope may need deliberate selection.

Likewise:

```text
CloudTrail data events
```

can be extremely high-volume.

Architect:

```text
coverage
+
risk
+
cost
```

together.

---

# 38.576 Security response interview scenario

Interviewer:

> An EC2 instance is suspected of compromise. How would your organization detect and respond?

Strong reasoning:

```text
1. GuardDuty or another detection source
   generates the signal.

2. Security Hub aggregates and
   normalizes the finding.

3. EventBridge sends the event
   to the response workflow.

4. Security Tooling determines/
   automates the containment level.

5. Preconfigured incident role
   accesses the workload account.

6. Instance can be isolated from
   production traffic/networking.

7. Volumes and relevant evidence
   can be preserved.

8. CloudTrail identifies AWS API activity.

9. VPC Flow Logs/DNS/Security Lake
   provide network context.

10. Detective can provide additional
    investigation context.

11. Credentials are revoked if compromised.

12. Application owner rebuilds from
    a trusted immutable artifact.

13. Root cause and persistence mechanisms
    are validated before reopening traffic.
```

That's a production security answer.

---

# 38.577 Complete security controls ladder

```text
                        SECURITY

                           │
                           ▼
                       PREVENT

               SCP / RCP / IAM /
               Block Public Access
                           │
                           ▼
                        RECORD

               CloudTrail / Config /
               Flow / DNS / App Logs
                           │
                           ▼
                        DETECT

              GuardDuty / Inspector /
              Macie / Access Analyzer
                           │
                           ▼
                       AGGREGATE

                     Security Hub
                           │
                           ▼
                        ANALYZE

               Security Lake / SIEM /
                     Detective
                           │
                           ▼
                        RESPOND

                EventBridge / Lambda /
                SSM / Incident Team
                           │
                           ▼
                         RETAIN

                Log Archive / Object Lock
```

That is the security lifecycle to remember.

---

# 38.578 Never-forget Part 5 rules

```text
1.
Security Tooling manages security;
Log Archive preserves evidence.


2.
Don't operate routine SOC tooling
from the Organizations management account.


3.
CloudTrail tells you who did what.


4.
Config tells you what configuration
the resource had.


5.
GuardDuty detects suspicious activity.


6.
Inspector finds vulnerabilities.


7.
Macie protects/discovers
sensitive S3 data.


8.
Detective helps investigations.


9.
Access Analyzer evaluates access
relative to a trust boundary.


10.
Security Hub aggregates
findings and posture.


11.
Security Lake centralizes
normalized security data.


12.
Security Hub ≠ Security Lake.


13.
ASFF is Security Hub's
finding normalization format.


14.
OCSF is Security Lake's
security data schema.


15.
EventBridge connects findings
to response automation.


16.
Security automation should preserve
evidence and control blast radius.


17.
Security services must be designed
for all required Regions.


18.
DR Region must have security parity.


19.
Use delegated administrators
instead of the management account
where supported.


20.
Centralized logs should be
strongly protected and, where required,
made immutable.


21.
Centralized findings need owners,
SLAs and response runbooks.


22.
No findings does not prove
security coverage.


23.
New accounts should onboard
into security automatically.


24.
Security tooling itself is
a crown-jewel environment.


25.
Security should be tested
with game days just like DR.
```

---

# 38.579 Part 5 checkpoint

You now understand:

```text
✓ Security OU architecture

✓ Security Tooling account

✓ Log Archive account

✓ delegated security administration

✓ organization CloudTrail

✓ CloudTrail delegated admin

✓ central S3 log storage

✓ S3 Object Lock

✓ log retention/lifecycle

✓ AWS Config

✓ Config aggregators

✓ organization Config governance

✓ Security Hub CSPM

✓ ASFF

✓ central configuration

✓ home + linked Regions

✓ GuardDuty

✓ GuardDuty organization auto-enable

✓ Inspector

✓ Inspector organization policies

✓ Macie

✓ Detective

✓ IAM Access Analyzer

✓ zone of trust

✓ Security Lake

✓ OCSF

✓ security subscribers

✓ SIEM integration

✓ EventBridge security automation

✓ finding workflows

✓ incident-response roles

✓ cross-account response

✓ forensic separation

✓ security service regionality

✓ Multi-Region security parity

✓ coverage monitoring

✓ security game days
```

---

# ✅ Lesson 38 — Part 5 Complete

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
Network + Shared Services Accounts      NEXT

Part 7
Account Factory + AFT

Part 8
Delegated Administration

Part 9
Terraform Governance Capstone

Part 10
Final Revision + Interview Mastery
```

# Next — Lesson 38, Part 6

## Central Network Account, Shared Services & Enterprise Connectivity

Next we'll combine **Lesson 36 networking** with **Lesson 38 governance** and answer:

> **Who should own Transit Gateway, Direct Connect, VPN, Route 53 Resolver, IPAM, centralized egress, Network Firewall, DNS, shared VPC services, and cross-account connectivity in a 100-account enterprise?**

We'll build:

```text
                       AWS ORGANIZATION

                             │
                    Infrastructure OU
                             │
             ┌───────────────┼───────────────┐
             ▼               ▼               ▼

         Network          Shared          Platform
         Account          Services        Account
             │               │
             ▼               ▼
            TGW             DNS
             │              AD
     Direct Connect      Private CA
        / VPN            shared tools
             │
    ┌────────┼─────────┐
    ▼        ▼         ▼
Payments   Orders    Analytics
 Account   Account    Account
```

Then we'll cover **Network Account ownership, TGW cross-account sharing with AWS RAM, VPC attachment governance, AWS IPAM delegation, centralized DNS Resolver, Route 53 Profiles, shared private hosted zones, centralized egress, Network Firewall inspection VPCs, NAT design, Direct Connect/VPN ownership, Firewall Manager, private endpoints, Shared VPC/subnet patterns, hybrid DNS, multi-Region network accounts, SCP protection, and full enterprise network troubleshooting**.

[1]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/security-tooling.html?utm_source=chatgpt.com "Security OU – Security Tooling account"
[2]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_delegate_policies.html?utm_source=chatgpt.com "Delegated administrator for AWS Organizations"
[3]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services_list.html?utm_source=chatgpt.com "AWS services that you can use with AWS Organizations"
[4]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-delegated-administrator.html?utm_source=chatgpt.com "Organization delegated administrator - AWS CloudTrail"
[5]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html?utm_source=chatgpt.com "Creating a trail for an organization - AWS CloudTrail"
[6]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html?utm_source=chatgpt.com "Security best practices for Amazon S3"
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html?utm_source=chatgpt.com "Locking objects with Object Lock"
[8]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/best-practices-security.html?utm_source=chatgpt.com "Security best practices in AWS CloudTrail"
[9]: https://docs.aws.amazon.com/config/latest/APIReference/Welcome.html?utm_source=chatgpt.com "Welcome - AWS Config"
[10]: https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html?utm_source=chatgpt.com "Multi-Account Multi-Region Data Aggregation for AWS Config"
[11]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-account-restrictions-recommendations.html?utm_source=chatgpt.com "Recommendations for managing multiple accounts in ..."
[12]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-findings.html?utm_source=chatgpt.com "Creating and updating findings in Security Hub CSPM"
[13]: https://docs.aws.amazon.com/securityhub/latest/userguide/designate-orgs-admin-account.html?utm_source=chatgpt.com "Integrating Security Hub CSPM with AWS Organizations"
[14]: https://docs.aws.amazon.com/securityhub/latest/userguide/start-central-configuration.html?utm_source=chatgpt.com "Enabling central configuration in Security Hub CSPM"
[15]: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-securityhub-organizationconfiguration.html?utm_source=chatgpt.com "AWS::SecurityHub::OrganizationConfiguration"
[16]: https://docs.aws.amazon.com/securityhub/latest/userguide/aggregation-central-configuration.html?utm_source=chatgpt.com "Impact of central configuration on cross-Region aggregation"
[17]: https://docs.aws.amazon.com/securityhub/latest/userguide/finding-aggregation.html?utm_source=chatgpt.com "Understanding cross-Region aggregation in Security Hub ..."
[18]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html?utm_source=chatgpt.com "Managing GuardDuty accounts with AWS Organizations"
[19]: https://docs.aws.amazon.com/guardduty/latest/ug/set-guardduty-auto-enable-preferences.html?utm_source=chatgpt.com "Setting organization auto-enable preferences"
[20]: https://docs.aws.amazon.com/organizations/latest/userguide/services-that-can-integrate-inspector2.html?utm_source=chatgpt.com "Amazon Inspector and AWS Organizations"
[21]: https://docs.aws.amazon.com/inspector/latest/user/designating-admin.html?utm_source=chatgpt.com "Designating a delegated administrator account for Amazon ..."
[22]: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_inspector.html?utm_source=chatgpt.com "Amazon Inspector policies - AWS Organizations"
[23]: https://docs.aws.amazon.com/macie/latest/user/accounts-mgmt-ao.html?utm_source=chatgpt.com "Managing multiple Macie accounts with AWS Organizations"
[24]: https://docs.aws.amazon.com/macie/latest/user/accounts-mgmt-ao-admin-change.html?utm_source=chatgpt.com "Changing the Macie administrator account for an organization"
[25]: https://docs.aws.amazon.com/detective/latest/userguide/accounts-remove-admin-overview.html?utm_source=chatgpt.com "Removing the Detective administrator account"
[26]: https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html?utm_source=chatgpt.com "AWS Identity and Access Management Access Analyzer ..."
[27]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-findings.html?utm_source=chatgpt.com "IAM Access Analyzer findings"
[28]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-delegated-administrator.html?utm_source=chatgpt.com "Delegated administrator for IAM Access Analyzer"
[29]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-dashboard.html?utm_source=chatgpt.com "View the IAM Access Analyzer findings dashboard"
[30]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-getting-started.html?utm_source=chatgpt.com "Permissions required to use IAM Access Analyzer"
[31]: https://docs.aws.amazon.com/security-lake/latest/userguide/source-management.html?utm_source=chatgpt.com "Source management in Security Lake"
[32]: https://docs.aws.amazon.com/security-lake/latest/userguide/what-is-security-lake.html?utm_source=chatgpt.com "Amazon Security Lake"
[33]: https://docs.aws.amazon.com/security-lake/latest/userguide/multi-account-management.html?utm_source=chatgpt.com "Managing multiple accounts with AWS Organizations in ..."
[34]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-cloudwatch-events.html?utm_source=chatgpt.com "Using EventBridge for automated response and remediation"
[35]: https://docs.aws.amazon.com/securityhub/latest/userguide/automations.html?utm_source=chatgpt.com "Automatically modifying and acting on findings in Security ..."
[36]: https://docs.aws.amazon.com/security-lake/latest/userguide/internal-sources.html?utm_source=chatgpt.com "Collecting data from AWS services in Security Lake"
[37]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-an-organizational-trail-prepare.html?utm_source=chatgpt.com "Prepare for creating a trail for your organization"
[38]: https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/management-account.html?utm_source=chatgpt.com "The management account, trusted access, and delegated ..."
[39]: https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data-troubleshooting.html?utm_source=chatgpt.com "Troubleshooting for Multi-Account Multi-Region Data ..."
[40]: https://docs.aws.amazon.com/detective/latest/userguide/accounts-orgs-transition.html?utm_source=chatgpt.com "Using Organizations to manage behavior graph accounts"
[41]: https://docs.aws.amazon.com/macie/latest/user/macie-accounts.html?utm_source=chatgpt.com "Managing multiple Macie accounts as an organization"
