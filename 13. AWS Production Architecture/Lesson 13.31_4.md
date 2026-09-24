# AWS Masterclass — Lesson 31 Part 4

# GuardDuty, Inspector, Macie & Security Hub

## Threat Detection, Vulnerability Management, Sensitive-Data Discovery & Central Security Operations

So far in Lesson 31:

```text
Part 1
KMS
│
└── Protect cryptographic keys + encrypted data

Part 2
Secrets Manager / Parameter Store
│
└── Protect credentials + configuration

Part 3
ACM / TLS / HTTPS
│
└── Protect data in transit

Part 4
│
▼
DETECT SECURITY PROBLEMS
```

Now our question changes from:

```text
"How do I protect this?"
```

to:

```text
"How do I know
something bad is happening?"
```

The four-service mental model is:

```text
                     AWS SECURITY OPERATIONS

                             │
       ┌─────────────────────┼──────────────────────┐
       │                     │                      │
       ▼                     ▼                      ▼
   GuardDuty             Inspector                Macie
       │                     │                      │
       ▼                     ▼                      ▼
THREAT BEHAVIOR        VULNERABILITIES        SENSITIVE DATA
       │                     │                      │
       │                     │                      │
       └─────────────────────┼──────────────────────┘
                             ▼
                     Security Hub CSPM
                             │
                             ▼
                      CENTRAL FINDINGS
                             │
                      ┌──────┴──────┐
                      ▼             ▼
                 EventBridge     Analyst/SIEM
                      │
                      ▼
                  Automation
```

---

# 1. The Most Important Distinction

Do not confuse these services.

## GuardDuty

Asks:

> **“Is suspicious or malicious activity happening?”**

## Inspector

Asks:

> **“Does this workload contain vulnerabilities or unwanted exposure that an attacker could exploit?”**

## Macie

Asks:

> **“Where is sensitive data located in S3, and is that data exposed or poorly protected?”**

## Security Hub CSPM

Asks:

> **“Can I centralize findings and continuously assess my security configuration against security controls?”**

Security Hub CSPM receives findings from services including GuardDuty, Inspector, Macie, IAM Access Analyzer, AWS Config, Route 53 Resolver DNS Firewall, and others, normalizing them into AWS Security Finding Format. ([AWS Documentation][1])

---

# 2. Threat vs Vulnerability

This distinction is critical.

Suppose your EC2 server contains:

```text
OpenSSL vulnerability
CVE-XXXX
```

but nobody has exploited it.

That is primarily:

```text
Inspector territory
```

Now suppose the server suddenly starts:

```text
running cryptomining
contacting malicious domains
scanning other servers
using stolen credentials
```

That is:

```text
GuardDuty territory
```

Mental model:

```text
VULNERABILITY
=
door is weak

THREAT
=
someone appears to be attacking/
abusing the door
```

---

# 3. Where Macie Fits

Suppose the compromised workload accesses:

```text
s3://customer-data
```

containing:

```text
passport numbers
credit-card data
personal information
financial records
```

Macie helps answer:

```text
What sensitive data
exists in these S3 objects?
```

Macie currently focuses its automated sensitive-data discovery and discovery jobs on your **Amazon S3 data estate**. ([AWS Documentation][2])

---

# 4. Security Hub Is Not “GuardDuty 2”

Security Hub isn't primarily doing GuardDuty-style behavioral threat detection.

Instead:

```text
GuardDuty
    │
    ▼
finding
    │
    ┐
Inspector finding
    │
    ├────────► Security Hub CSPM
Macie finding
    │
    ┘
```

plus:

```text
Security Hub security controls
        │
        ▼
configuration/posture findings
```

Security Hub CSPM provides both control-based posture assessment and centralized ingestion of security findings. ([AWS Documentation][1])

---

# Amazon GuardDuty

# 5. What Is GuardDuty?

Amazon GuardDuty continuously monitors and analyzes AWS data sources and event streams for suspicious or potentially malicious behavior using threat intelligence, machine learning, behavioral techniques, and other detections. ([AWS Documentation][3])

Think:

```text
AWS ACTIVITY
    │
    ▼
GuardDuty
    │
    ├── known malicious indicators
    ├── anomalous behavior
    ├── attack patterns
    └── runtime signals
    │
    ▼
Security Finding
```

---

# 6. GuardDuty Foundational Data Sources

When GuardDuty is enabled, its foundational detection analyzes sources including:

```text
CloudTrail management events

EC2 VPC Flow Log information

DNS query information
```

GuardDuty consumes these internally for detection; you don't have to separately enable VPC Flow Logs merely so GuardDuty foundational monitoring can use the relevant flow-log data. ([AWS Documentation][3])

---

# 7. CloudTrail Management Activity

Suppose credentials suddenly perform:

```text
CreateUser

AttachRolePolicy

DisableCloudTrail

CreateAccessKey

DescribeSecrets

RunInstances
```

in an unusual pattern.

GuardDuty can analyze CloudTrail management activity as part of its foundational threat-detection model. ([AWS Documentation][3])

This is why GuardDuty is heavily connected to our IAM lesson.

---

# 8. VPC Network Activity

GuardDuty can analyze network-flow information associated with EC2 workloads.

Example suspicious behavior:

```text
EC2
 │
 ├──► known command-and-control IP
 │
 ├──► scanning many ports
 │
 └──► suspicious crypto-mining endpoint
```

Potential result:

```text
GuardDuty finding
```

---

# 9. DNS Activity

Imagine malware running on EC2 asks DNS:

```text
random-malicious-domain.example
```

GuardDuty can analyze DNS activity and threat intelligence to detect suspicious domain communication as part of its threat-detection capabilities. ([AWS Documentation][3])

Remember:

```text
DNS resolution works
```

doesn't mean:

```text
DNS destination is safe.
```

---

# 10. GuardDuty Protection Plans

GuardDuty has expanded far beyond the original foundational EC2/IAM threat-detection model.

Current capabilities include protection plans for areas such as:

```text
S3

EKS

Runtime Monitoring

EC2 malware scanning

S3 malware scanning

RDS

Lambda
```

and newer GuardDuty protection capabilities continue to evolve. ([AWS Documentation][4])

---

# 11. S3 Protection

GuardDuty S3 Protection monitors:

```text
CloudTrail S3 data events
```

for object-level activity that might indicate things such as:

```text
data exfiltration

data destruction

suspicious S3 access
```

across S3 buckets in the account. ([AWS Documentation][5])

Example:

```text
Compromised credential
        │
        ▼
lists huge numbers of S3 objects
        │
        ▼
downloads unusual volume
        │
        ▼
GuardDuty
        │
        ▼
potential exfiltration finding
```

---

# 12. EKS Protection

GuardDuty EKS Protection analyzes:

```text
EKS audit logs
```

for suspicious Kubernetes control-plane activities. GuardDuty receives an independent stream of EKS audit-log information, so enabling EKS control-plane audit logging to CloudWatch is not required just for GuardDuty EKS Protection to perform its monitoring. ([AWS Documentation][6])

Potential issues include:

```text
unauthorized Kubernetes API calls

attempts to retrieve secrets

suspicious pod operations

abnormal identities
```

---

# 13. EKS Protection vs Runtime Monitoring

These are not identical.

```text
EKS Protection
        │
        ▼
Kubernetes audit/control-plane activity
```

versus:

```text
Runtime Monitoring
        │
        ▼
What processes/files/network activity
are happening INSIDE workloads?
```

That distinction is extremely important.

---

# 14. Runtime Monitoring

GuardDuty Runtime Monitoring observes operating-system-level, networking, file, and related runtime activity for supported:

```text
EC2

EKS

ECS including supported Fargate workloads
```

to identify potential runtime compromise. ([AWS Documentation][7])

Conceptually:

```text
Container
   │
   ├── process starts
   ├── file changes
   ├── suspicious binary
   ├── network activity
   └── privilege behavior
        │
        ▼
 GuardDuty Runtime
        │
        ▼
     Finding
```

---

# 15. Runtime Monitoring Goes Deeper Than Flow Logs

VPC Flow Logs might tell you:

```text
10.0.1.5
connected to
198.x.x.x:443
```

Runtime monitoring can provide visibility closer to:

```text
Which workload?

What process?

What runtime behavior?

What file/system event?
```

That makes runtime detection useful for container/host compromise scenarios. ([AWS Documentation][7])

---

# 16. ECS Fargate Runtime Monitoring

For supported ECS Fargate configurations, GuardDuty can deploy a security-agent sidecar for monitored tasks when automated agent configuration is used. ([AWS Documentation][8])

Mental architecture:

```text
ECS Fargate Task
│
├── Application container
│
└── GuardDuty security-agent sidecar
          │
          ▼
    runtime telemetry
          │
          ▼
      GuardDuty
```

---

# 17. Malware Protection for EC2

GuardDuty Malware Protection for EC2 scans attached:

```text
EBS volumes
```

for potential malware.

The GuardDuty-initiated mode can perform an **agentless** scan when GuardDuty generates a qualifying finding indicating potential malware-related compromise. There is also an on-demand scan mode. ([AWS Documentation][9])

This is useful because you don't necessarily need to install a traditional antivirus agent merely for this malware scan path.

---

# 18. Important Malware Scan Mental Model

```text
GuardDuty behavioral signal
        │
        ▼
Possible EC2 compromise
        │
        ▼
EBS malware scan
        │
        ▼
Malicious file found?
```

Network/anomaly detection tells you:

```text
"something suspicious happened"
```

Malware scanning may tell you:

```text
"malicious artifact exists on disk"
```

These are complementary signals.

---

# 19. Malware Protection for S3

GuardDuty Malware Protection for S3 can scan newly uploaded objects in selected S3 buckets for malware. Current GuardDuty also supports an on-demand S3 malware scan capability. ([AWS Documentation][10])

Architecture:

```text
User uploads file
       │
       ▼
       S3
       │
       ▼
GuardDuty Malware Scan
       │
   ┌───┴────┐
   ▼        ▼
 CLEAN    MALWARE
```

This is particularly useful for:

```text
document upload portals

customer file ingestion

software artifact intake

data-exchange buckets
```

---

# 20. GuardDuty Malware Protection for S3 ≠ Macie

Do not confuse them.

```text
GuardDuty malware scan
=
"Is this object malicious?"
```

```text
Macie
=
"Does this object contain sensitive information?"
```

Example:

```text
customer-passports.csv
```

might be:

```text
not malware
```

but:

```text
extremely sensitive
```

Macie and GuardDuty solve different questions.

---

# 21. RDS Protection

GuardDuty RDS Protection analyzes login activity for supported database environments to identify suspicious or anomalous login behavior. ([AWS Documentation][11])

Example:

```text
Database normally:
Mumbai application hosts

Suddenly:
unusual source
unusual login pattern
credential behavior anomaly
        │
        ▼
GuardDuty RDS Protection
```

This is not:

```text
SQL query optimization
```

and not:

```text
database vulnerability scanning.
```

---

# 22. Lambda Protection

GuardDuty Lambda Protection monitors network activity associated with Lambda invocations to detect suspicious network behavior, including Lambda functions that aren't configured with traditional VPC networking. ([AWS Documentation][12])

Example:

```text
Compromised Lambda dependency
        │
        ▼
Lambda contacts malicious endpoint
        │
        ▼
GuardDuty
        │
        ▼
Lambda threat finding
```

---

# 23. Extended Threat Detection

One isolated event may not look dangerous.

Example:

```text
1. unusual API call

2. suspicious credential usage

3. runtime process starts

4. network connection to suspicious endpoint

5. data-access activity
```

Individually:

```text
maybe suspicious
```

together:

```text
ATTACK SEQUENCE
```

GuardDuty Extended Threat Detection correlates multiple signals over time and across relevant data sources/resources to identify multi-stage attacks. ([AWS Documentation][13])

---

# 24. Why Attack Sequences Matter

Security analysts do not want:

```text
Finding 1

Finding 2

Finding 3

Finding 4

Finding 5
```

with no context.

They want:

```text
Initial access
      ↓
credential abuse
      ↓
execution
      ↓
persistence/escalation
      ↓
data access
```

GuardDuty's Extended Threat Detection can represent related signals as higher-level attack-sequence findings for supported scenarios. ([AWS Documentation][14])

---

# Amazon Inspector

# 25. What Is Inspector?

Amazon Inspector is primarily a:

# Vulnerability Management Service

It continuously discovers and evaluates supported workloads and can produce findings when it identifies:

```text
software vulnerabilities

package vulnerabilities

code vulnerabilities

network exposure/reachability issues
```

depending on resource and scanning mode. ([AWS Documentation][15])

---

# 26. GuardDuty vs Inspector

Memorize:

```text
Inspector
=
Could this be exploited?
```

```text
GuardDuty
=
Does activity look like
it IS being attacked/abused?
```

Example:

```text
Apache vulnerable version
        │
        ▼
Inspector finding


Apache spawns cryptominer
        │
        ▼
GuardDuty finding
```

---

# 27. Inspector EC2 Scanning

Amazon Inspector can scan EC2 for:

```text
OS/package vulnerabilities

application-language package vulnerabilities

network reachability/exposure
```

using supported agent-based and agentless mechanisms. AWS currently supports hybrid scanning, which can use SSM-based inventory and EBS-snapshot-based scanning according to eligibility/configuration. ([AWS Documentation][16])

---

# 28. Inspector Agent-Based EC2 Flow

Conceptually:

```text
EC2
 │
 ▼
SSM/Inspector scanning mechanism
 │
 ▼
Package inventory
 │
 ▼
Inspector vulnerability intelligence
 │
 ▼
Finding
```

Current Inspector documentation recommends its Enhanced EC2 Scanning mechanism where supported; agent-based scanning depends on the instance meeting SSM and operating-system requirements. ([AWS Documentation][16])

---

# 29. Agentless EC2 Scanning

Inspector can also use:

```text
EBS snapshots
```

to gather software information for eligible instances without depending solely on in-instance scanning.

Mental model:

```text
EC2 EBS
   │
   ▼
snapshot-based inspection
   │
   ▼
package inventory
   │
   ▼
vulnerability analysis
```

This is useful when an instance isn't suitable for the normal agent-based path. ([AWS Documentation][16])

---

# 30. Network Reachability

Inspector isn't only asking:

```text
"Is vulnerable package X installed?"
```

It can also evaluate network reachability/exposure for EC2.

This allows prioritization such as:

```text
Critical vulnerability
+
internet reachable
=
very different risk
```

from:

```text
Same vulnerability
+
isolated private host
+
no reachable attack path
```

Inspector incorporates environmental information such as network reachability into its EC2 risk scoring. ([AWS Documentation][17])

---

# 31. CVE

You will constantly see:

```text
CVE
```

which means:

# Common Vulnerabilities and Exposures

Inspector maintains vulnerability intelligence and can rescan supported resources when relevant new CVEs become known, rather than requiring you to schedule a monthly scanner manually. ([AWS Documentation][15])

---

# 32. CVSS

A CVE often has a:

```text
CVSS score
```

describing technical vulnerability severity.

But:

```text
CVSS 9.8
```

doesn't necessarily mean:

```text
"Fix this exact host before absolutely everything else."
```

You also care about:

```text
internet exposure

exploit availability

resource importance

running workload

business criticality
```

Inspector's EC2 score can incorporate environmental reachability and vulnerability intelligence rather than relying solely on the base CVSS number. ([AWS Documentation][17])

---

# 33. Inspector ECR Scanning

Inspector can integrate with Amazon ECR enhanced scanning.

```text
Container image pushed
        │
        ▼
Amazon ECR
        │
        ▼
Inspector enhanced scanning
        │
        ▼
OS packages
+
programming-language packages
        │
        ▼
CVEs
```

Inspector can continuously rescan actively monitored images when new relevant CVEs become available. ([AWS Documentation][18])

---

# 34. Basic ECR Scan vs Enhanced Scan

Do not confuse:

```text
ECR Basic Scanning
```

with:

```text
ECR Enhanced Scanning
powered by Inspector
```

Enhanced scanning provides Inspector vulnerability management features and continuous scanning options for operating-system and programming-language package vulnerabilities. ([AWS Documentation][18])

---

# 35. Why Continuous Scanning Matters

Imagine image:

```text
todo-api:v1
```

was scanned Monday:

```text
No critical CVEs
```

Friday:

```text
new CVE published
```

Your Docker image has not changed.

But your risk **has** changed.

With continuous Inspector monitoring:

```text
new CVE intelligence
        │
        ▼
existing active image reconsidered
        │
        ▼
new finding
```

for monitored images. ([AWS Documentation][18])

This is why:

```text
"Image passed scan when built"
```

is not enough for production security.

---

# 36. Running-Container Context

Inspector can map ECR images to running containers in supported ECS and EKS environments, improving your ability to distinguish:

```text
vulnerable image
not used anywhere
```

from:

```text
vulnerable image
currently running in production
```

for supported mappings. ([AWS Documentation][18])

---

# 37. Lambda Standard Scanning

When Lambda standard scanning is enabled, Inspector discovers supported Lambda functions/layers and scans their package dependencies for vulnerabilities.

It rescans when:

```text
function/layer changes

or

new relevant CVEs are published
```

among supported triggers. ([AWS Documentation][19])

---

# 38. Lambda Code Scanning

Inspector can additionally perform code-vulnerability analysis for Lambda functions.

Examples include detections related to:

```text
data leaks

injection flaws

missing encryption

weak cryptography
```

through its Lambda code-scanning capabilities. ([AWS Documentation][20])

That is different from package CVE scanning.

---

# 39. Inspector Code Security

Current Inspector also has a broader:

```text
Code Security
```

scan type that can evaluate:

```text
first-party application code

dependencies

Infrastructure as Code
```

using Amazon Q Developer scanning technology. ([AWS Documentation][19])

One current integration nuance: Inspector Code Security findings are not sent through the classic Security Hub CSPM Inspector integration in the same way as ordinary Inspector findings; AWS documents them as available through Inspector itself/API. ([AWS Documentation][21])

---

# Amazon Macie

# 40. What Is Macie?

Amazon Macie is primarily about:

# DATA SECURITY FOR S3

Current Macie sensitive-data discovery operates against your S3 data estate using:

```text
managed identifiers

custom identifiers

allow lists

sampling/jobs
```

to identify sensitive information. ([AWS Documentation][2])

---

# 41. Example Sensitive Data

Think:

```text
credit-card numbers

government IDs

credentials

financial information

health-related identifiers

personal information

custom organization-specific patterns
```

depending on the managed/custom identifiers you configure.

---

# 42. Automated Sensitive Data Discovery

Macie can perform automated sensitive-data discovery across S3.

It:

```text
evaluates bucket inventory daily
        │
        ▼
selects representative objects
using sampling
        │
        ▼
analyzes those objects
        │
        ▼
updates sensitivity information/findings
```

Automated discovery is designed for broad visibility rather than exhaustive scanning of every byte of every object. ([AWS Documentation][2])

---

# 43. Why Sampling Matters

Suppose:

```text
20 PB
of S3 data
```

You may not want to scan every object continuously.

Automated discovery gives:

```text
broad ongoing visibility
```

using representative sampling.

When something warrants deeper investigation:

```text
run targeted discovery job
```

instead. ([AWS Documentation][2])

---

# 44. Sensitive Data Discovery Jobs

A Macie discovery job lets you specify:

```text
which buckets

which objects/criteria

which sensitive-data identifiers

custom identifiers

allow lists
```

for more targeted analysis. ([AWS Documentation][22])

Example:

```text
Job:

Bucket:
prod-customer-uploads

Find:
passport numbers
credit cards
email addresses
custom customer IDs
```

---

# 45. Managed Data Identifier

Macie provides managed identifiers for recognized categories/patterns of sensitive information.

Instead of building every detection regex yourself:

```text
Macie managed identifier
```

can identify supported sensitive-data patterns. ([AWS Documentation][2])

---

# 46. Custom Data Identifier

Suppose your company has an internal ID:

```text
YDS-CUST-12345678
```

You might build a custom identifier for your particular pattern.

Mental model:

```text
Managed identifier
=
AWS-recognized sensitive pattern


Custom identifier
=
YOUR organization's pattern
```

---

# 47. Allow Lists

Sometimes a matching pattern is legitimate and should not be treated as sensitive.

Example:

```text
test@example.com
```

appears in thousands of development objects.

Macie allow lists let you specify text/pattern exceptions so analyses can ignore approved matches. ([AWS Documentation][2])

---

# 48. Macie Sensitive Data Finding

Example:

```text
S3 object
customer-export.csv
        │
        ▼
Macie analyzes
        │
        ▼
Sensitive data detected
        │
        ▼
Sensitive data finding
```

Macie also creates discovery-result records for analyzed objects, including objects where no sensitive data was found or analysis couldn't complete. ([AWS Documentation][23])

---

# 49. Policy Finding vs Sensitive-Data Finding

Macie has another important class of issue:

```text
POLICY FINDING
```

For example:

```text
S3 bucket is publicly accessible
```

versus:

```text
SENSITIVE-DATA FINDING
```

such as:

```text
Object contains sensitive identifiers.
```

The dangerous combination is:

```text
PUBLIC BUCKET
+
SENSITIVE DATA
```

Macie's automated discovery is designed to help identify exactly these kinds of high-risk combinations. ([AWS Documentation][2])

---

# AWS Security Hub CSPM

# 50. What Is Security Hub CSPM?

Think of Security Hub CSPM as:

```text
SECURITY FINDING NORMALIZATION

+

SECURITY POSTURE CONTROLS

+

CENTRAL SECURITY VIEW

+

AUTOMATION
```

It receives findings from integrated security services and also evaluates security controls/standards for your AWS environment. ([AWS Documentation][1])

---

# 51. The “Single Pane” Architecture

```text
GuardDuty ───────────┐
                     │
Inspector ───────────┤
                     │
Macie ───────────────┤
                     │
IAM Access Analyzer ─┤
                     │
AWS Config ──────────┤
                     ▼
              Security Hub CSPM
                     │
                     ▼
             Normalized Findings
```

Security Hub CSPM integrates with all of those AWS finding sources. ([AWS Documentation][21])

---

# 52. AWS Security Finding Format — ASFF

Different services naturally produce different finding schemas.

Without normalization:

```text
GuardDuty JSON format

Inspector JSON format

Macie JSON format

Config format
```

Your SOC would need separate processing logic.

Security Hub uses:

# AWS Security Finding Format

```text
ASFF
```

to normalize findings into a standard JSON structure including information such as:

```text
source

account

resource

severity

workflow state

finding ID

timestamps
```

and related security context. ([AWS Documentation][1])

---

# 53. Why ASFF Is Important

Now your automation can reason about:

```text
Severity = CRITICAL
```

without writing:

```text
if GuardDuty:
  parse one schema

if Inspector:
  parse another

if Macie:
  parse another
```

Conceptually:

```text
Many Producers
      │
      ▼
     ASFF
      │
      ▼
One automation model
```

---

# 54. Security Standards

Security Hub CSPM organizes posture checks into:

```text
security standards
```

which contain:

```text
security controls.
```

Current Security Hub CSPM includes standards such as AWS Foundational Security Best Practices and newer standards such as AI Security Best Practices and AWS Resource Tagging, among other currently supported frameworks. ([AWS Documentation][24])

---

# 55. AWS Foundational Security Best Practices

This is a particularly important standard.

Conceptually, controls might assess whether resources align with recommended security configurations.

Think:

```text
Is service logging enabled?

Is encryption configured?

Is public exposure controlled?

Are recommended security settings present?
```

The actual enabled controls vary as AWS evolves the standard. AWS's FSBP standard is designed as a general security-best-practice baseline. ([AWS Documentation][24])

---

# 56. Control Finding vs Threat Finding

Another essential distinction.

### GuardDuty

```text
Possible compromised credential
```

= behavioral/threat finding.

### Security Hub Control

```text
S3 bucket does not meet
required security configuration
```

= posture/control finding.

One asks:

```text
"Something bad happening?"
```

The other:

```text
"Configuration fails our expected baseline?"
```

---

# 57. Security Hub Doesn't Remediate Everything Automatically

Security Hub provides:

```text
findings

controls

automation rules

EventBridge integration
```

But it doesn't mean:

```text
every finding
will magically repair itself.
```

Security Hub CSPM can use automation rules to modify/suppress/triage findings, and EventBridge can trigger custom automated response workflows. ([AWS Documentation][1])

---

# 58. Automation Rule vs EventBridge

These have different jobs.

## Security Hub Automation Rule

Example:

```text
If:
Product = Inspector

AND
Account = sandbox

AND
Severity = LOW

Then:
Workflow = SUPPRESSED
```

Used primarily for:

```text
finding management/triage.
```

## EventBridge

Example:

```text
Critical GuardDuty finding
        │
        ▼
EventBridge
        │
        ▼
Lambda / Step Functions / SSM
        │
        ▼
contain resource
```

Used for:

```text
external response automation.
```

Security Hub supports both patterns. ([AWS Documentation][25])

---

# 59. Do Not Auto-Remediate Everything

Suppose GuardDuty says:

```text
EC2 possibly compromised
```

A dangerous automation would be:

```text
terminate instance immediately
```

for every finding.

Why?

You might destroy:

```text
forensic evidence

important production workload

customer data in ephemeral storage
```

Better response often follows:

```text
Detect
  ↓
Validate severity/context
  ↓
Contain
  ↓
Preserve evidence
  ↓
Investigate
  ↓
Remediate
```

Automation should match confidence and business impact.

---

# 60. Good Automated Containment Example

For a high-confidence compromised EC2 event:

```text
GuardDuty finding
       │
       ▼
Security Hub
       │
       ▼
EventBridge
       │
       ▼
Step Functions / Lambda
       │
       ├── tag instance Quarantined
       │
       ├── isolate network access
       │
       ├── snapshot EBS
       │
       ├── gather metadata
       │
       └── alert SOC
```

Then a human/security workflow decides the final remediation.

---

# 61. Inspector Automation Is Different

Inspector finding:

```text
Critical package CVE
```

might trigger:

```text
ticket

Patch Manager workflow

image rebuild

deployment pipeline

container rebuild
```

not:

```text
"block attacker IP"
```

because Inspector is telling you about a vulnerability, not necessarily an active attack.

---

# 62. Macie Automation Is Different Again

Macie:

```text
Sensitive data
+
public bucket
```

might trigger:

```text
block public access

ticket data owner

quarantine object/bucket workflow

notify security/privacy team
```

But you should verify the business context before performing destructive actions.

---

# 63. Detective Fits After Detection

Amazon Detective is useful primarily for:

```text
INVESTIGATION
```

after a security signal exists.

Security Hub supports pivoting findings into Detective, including GuardDuty findings, to investigate relationships and activity using Detective's behavior graphs/analytics. ([AWS Documentation][21])

Mental model:

```text
GuardDuty
=
detect

Security Hub
=
centralize/prioritize

Detective
=
investigate
```

---

# 64. The Incident Lifecycle

Memorize:

```text
PREVENT
   │
   ▼
IAM / SG / KMS / WAF
   │
   ▼
DETECT
   │
   ▼
GuardDuty / Inspector / Macie
   │
   ▼
AGGREGATE
   │
   ▼
Security Hub
   │
   ▼
INVESTIGATE
   │
   ▼
Detective / CloudTrail / logs
   │
   ▼
RESPOND
   │
   ▼
EventBridge / Lambda / SSM
   │
   ▼
RECOVER
```

That is security operations as a system.

---

# Multi-Account Security Architecture

# 65. Don't Manage Security Service-by-Service in 100 Accounts

Bad:

```text
100 accounts
×
20 Regions
×
manually enabling everything
```

Better:

```text
AWS Organizations
       │
       ▼
Security Account
       │
       ├── GuardDuty delegated admin
       ├── Inspector delegated admin
       ├── Macie delegated admin
       └── Security Hub delegated admin
```

These services support Organizations-based centralized administration models. ([AWS Documentation][26])

---

# 66. Security Account Pattern

```text
                   AWS ORGANIZATION
                         │
                         ▼
                  Security Account
                         │
       ┌─────────────────┼──────────────────┐
       ▼                 ▼                  ▼
  GuardDuty          Inspector            Macie
  Delegated          Delegated          Delegated
    Admin               Admin              Admin
       │                 │                  │
       └─────────────────┼──────────────────┘
                         ▼
                  Security Hub CSPM
                         │
                         ▼
                    Home Region
```

Keeping central security operations outside workload accounts reduces the risk that a compromised workload administrator can hide or manipulate security oversight.

---

# 67. GuardDuty Is Regional

GuardDuty's Organizations administration is Regional.

If you designate the GuardDuty administrator only in one Region, that administrator arrangement applies to GuardDuty in that Region; AWS recommends configuring desired Regions accordingly. ([AWS Documentation][26])

So never think:

```text
Enable GuardDuty
in ap-south-1
=
everything globally protected.
```

---

# 68. Macie Is Regional Too

Macie organization integration must also be configured across the Regions where you intend to use it, with the same delegated administrator used across those Regions. ([AWS Documentation][27])

Remember:

```text
S3 namespace feels global
```

but:

```text
Macie service operation
is Regional.
```

---

# 69. Inspector Multi-Account

Inspector supports centralized organization administration using a delegated administrator that can view aggregated member-account findings and manage supported scan enablement/settings. ([AWS Documentation][15])

This lets your central security team answer:

```text
Which production accounts
have critical vulnerable EC2/ECR/Lambda resources?
```

from a centralized model.

---

# 70. Security Hub Central Configuration

Security Hub CSPM supports central configuration through its delegated administrator.

From a designated:

```text
HOME REGION
```

you can centrally manage Security Hub CSPM configuration policies for:

```text
accounts

OUs

standards

controls

linked Regions
```

and prevent configuration drift in centrally managed targets. ([AWS Documentation][28])

---

# 71. Security Hub Home Region

Current Security Hub terminology uses:

```text
Home Region
```

for the Region that serves as the central configuration/aggregation point.

Linked Regions can send:

```text
findings

insights

other Security Hub data
```

to that home Region. ([AWS Documentation][28])

Architecture:

```text
ap-south-1
Security Hub
      │
      │
      ▼
   HOME REGION
      ▲
      │
 ┌────┼──────────────┐
 │    │              │
 ▼    ▼              ▼
Singapore       Frankfurt      other linked Regions
```

You can choose the home Region according to organizational requirements and currently supported Security Hub rules.

---

# 72. Finding Aggregation

Without cross-Region aggregation:

```text
Mumbai findings
stay in Mumbai view

Singapore findings
stay in Singapore view
```

With Security Hub cross-Region aggregation:

```text
Mumbai
     \
Singapore ─────► Home Region
     /
Frankfurt
```

Security Hub uses a finding aggregator resource for this configuration. ([AWS Documentation][29])

---

# 73. Findings from GuardDuty

GuardDuty sends its finding types into Security Hub CSPM when the integration is active; AWS documents that enabling Security Hub CSPM activates this GuardDuty integration automatically. ([AWS Documentation][21])

So:

```text
GuardDuty detector
        │
        ▼
GuardDuty finding
        │
        ▼
Security Hub ASFF
```

---

# 74. Findings from Inspector

Amazon Inspector findings are automatically integrated into Security Hub CSPM after Security Hub is enabled for the integration, with the Code Security caveat mentioned earlier. ([AWS Documentation][21])

---

# 75. Findings from Macie

Current integration behavior is slightly different:

```text
Macie policy findings
```

automatically flow into Security Hub after Security Hub is enabled.

Sending:

```text
Macie sensitive-data findings
```

can be additionally configured. ([AWS Documentation][21])

This distinction is worth remembering.

---

# Full Incident Example

# 76. Incident — Compromised EC2 Server

Suppose:

```text
Internet
    │
    ▼
ALB
    │
    ▼
EC2
```

EC2 contains an unpatched vulnerable package.

---

# 77. Stage 1 — Inspector

Inspector reports:

```text
Critical CVE
        │
        ▼
EC2 instance
        │
        ▼
Network reachable
```

Security team should prioritize remediation.

But nobody fixes it.

---

# 78. Stage 2 — Attack

Attacker exploits the service.

Now runtime behavior becomes:

```text
web process
    │
    ▼
download suspicious binary
    │
    ▼
execute
    │
    ▼
connect external endpoint
```

---

# 79. Stage 3 — GuardDuty

GuardDuty sees suspicious:

```text
network

runtime

credential/API
```

signals.

Potential result:

```text
GuardDuty threat finding
```

or, where supported patterns align:

```text
attack-sequence finding.
```

---

# 80. Stage 4 — Security Hub

Security Hub now has:

```text
Inspector:
critical vulnerability

GuardDuty:
possible compromise
```

The two findings together are much more important than either finding in isolation.

---

# 81. Stage 5 — Automated Containment

EventBridge rule:

```text
IF
GuardDuty critical
AND
resource type EC2

THEN
invoke Step Functions
```

Workflow:

```text
Tag instance
      ↓
Quarantine network
      ↓
Snapshot storage
      ↓
Notify security team
      ↓
Create incident/ticket
```

---

# 82. Stage 6 — Investigation

Use:

```text
CloudTrail
VPC/network data
GuardDuty evidence
Detective
application logs
OS/runtime telemetry
```

to understand:

```text
initial access

actions performed

credentials used

resources touched

data accessed
```

---

# 83. Stage 7 — Remediation

Don't simply:

```text
clean malware
and return server
```

A safer immutable infrastructure strategy is often:

```text
fix vulnerability
      ↓
rebuild AMI/container
      ↓
rotate compromised credentials
      ↓
deploy known-good workload
      ↓
terminate compromised workload
```

while preserving required forensic evidence.

---

# Second Incident — Sensitive Data

# 84. Sensitive S3 Bucket Scenario

Imagine:

```text
customer-data-prod
```

contains:

```text
PII
financial records
```

Macie reports:

```text
Sensitive data
```

Then a policy finding indicates:

```text
bucket potentially exposed
```

GuardDuty later observes:

```text
unusual object-access pattern
```

Now:

```text
Macie
=
WHAT sensitive data is at risk

GuardDuty
=
WHAT suspicious activity occurred

Security Hub
=
central incident view
```

This is why the services work together.

---

# 85. Security Finding ≠ Confirmed Breach

Never assume:

```text
finding
=
100% compromise.
```

A finding is a security signal requiring evaluation.

Security operations should use:

```text
severity

resource criticality

confidence/context

network exposure

business impact

related findings
```

to determine response.

---

# 86. Suppress vs Remediate

Suppression should mean:

```text
We understand this finding
and intentionally don't need
normal analyst attention.
```

Not:

```text
This alert is annoying,
so suppress everything.
```

Good example:

```text
Known approved test scanner
in isolated security account
```

Possible suppression.

Bad example:

```text
Critical prod threat
we haven't investigated
```

Do not suppress to make dashboards green.

---

# Hands-On Read-Only Inspection Lab

Use:

```bash
export AWS_REGION=ap-south-1
```

First:

```bash
aws sts get-caller-identity
```

Always know which security account/principal you're using.

---

# 87. GuardDuty — Find Detector

```bash
aws guardduty list-detectors \
  --region "$AWS_REGION"
```

A GuardDuty detector identifies the GuardDuty service configuration for the account in a Region; GuardDuty is Regional. ([AWS Documentation][26])

Then:

```bash
export DETECTOR_ID="<detector-id>"
```

---

# 88. List GuardDuty Findings

```bash
aws guardduty list-findings \
  --detector-id "$DETECTOR_ID" \
  --max-results 20 \
  --region "$AWS_REGION"
```

Use the returned finding IDs with `get-findings` when you want detailed finding information.

---

# 89. Inspector Findings

```bash
aws inspector2 list-findings \
  --max-results 20 \
  --region "$AWS_REGION"
```

Inspect:

```text
severity

resource type

resource ID

package/CVE

fix availability

network exposure
```

depending on finding type.

---

# 90. Inspector Coverage

A security dashboard showing zero findings is meaningless if nothing is actually being scanned.

Think:

```text
FINDINGS
+
COVERAGE
```

Always ask:

```text
How many EC2 instances scanned?

How many ECR images active?

How many Lambda functions covered?
```

Inspector has coverage data specifically so you can distinguish:

```text
secure
```

from:

```text
not being inspected.
```

---

# 91. Macie Session

Check whether Macie is enabled:

```bash
aws macie2 get-macie-session \
  --region "$AWS_REGION"
```

Then:

```bash
aws macie2 list-findings \
  --region "$AWS_REGION"
```

Remember Macie discovery primarily tells you about sensitive-data/security risk across S3. ([AWS Documentation][30])

---

# 92. Security Hub Findings

```bash
aws securityhub get-findings \
  --max-results 20 \
  --region "$AWS_REGION"
```

Now you can inspect normalized findings from multiple integrated producers using ASFF. ([AWS Documentation][1])

---

# 93. Useful Security Hub Filtering Mental Model

In a SOC workflow, filter by:

```text
Severity

Product

Account

Region

Resource Type

Workflow Status

Record State
```

rather than reading thousands of findings chronologically.

Example priorities:

```text
CRITICAL
+
Production
+
Active
```

first.

---

# Terraform / IaC

# 94. Security Services Should Be Infrastructure as Code

At minimum, an IaC security baseline should address:

```text
GuardDuty enablement

Inspector scanning

Macie enablement

Security Hub enablement

Organizations integration

delegated administrators

Region coverage

Security Hub aggregation

EventBridge response rules
```

The current HashiCorp AWS provider exposes resource families for GuardDuty, Inspector2, Macie2, and Security Hub. ([Terraform Registry][31])

---

# 95. GuardDuty Terraform Mental Model

Conceptually:

```hcl
resource "aws_guardduty_detector" "main" {
  enable = true
}
```

Then organization-level configuration can control:

```text
member accounts

auto-enablement

protection plans
```

according to the exact provider version you're using.

Because GuardDuty protection-plan capabilities evolve, always check the current AWS provider schema before copying old Terraform examples.

---

# 96. Why Region Loops Matter

Bad security Terraform:

```text
GuardDuty only
ap-south-1
```

while company workloads also run in:

```text
ap-southeast-1

us-east-1
```

Better design:

```text
approved_regions = [
  ap-south-1,
  ap-southeast-1,
  us-east-1
]
```

and deliberately configure security-service coverage in each appropriate Region.

GuardDuty, Macie, Inspector, and much of Security Hub operate with important Regional configuration considerations. ([AWS Documentation][26])

---

# 97. Security Hub Central Configuration Is Better Than Drift

Imagine:

```text
100 AWS accounts
```

and each account admin manually decides:

```text
which Security Hub controls to enable.
```

Soon you get:

```text
Account A = 120 controls

Account B = 116

Account C = 98

Account D = unknown
```

Security Hub central configuration lets the delegated administrator define configuration policies for centrally managed OUs/accounts across the home and linked Regions, reducing this drift. ([AWS Documentation][28])

---

# 98. Production Organization Design

```text
                       AWS ORGANIZATION
                             │
                             ▼
                       Security OU
                             │
                             ▼
                      Security Account
                             │
         ┌───────────────────┼────────────────────┐
         ▼                   ▼                    ▼
     GuardDuty            Inspector              Macie
     delegated            delegated            delegated
       admin                admin                admin
         │                   │                    │
         └───────────────────┼────────────────────┘
                             ▼
                     Security Hub CSPM
                             │
                         Home Region
                             │
                    Cross-Region Findings
                             │
         ┌───────────────────┼────────────────────┐
         ▼                   ▼                    ▼
    EventBridge          Detective               SIEM
         │
         ▼
  Step Functions
         │
      Response
```

---

# 99. What Each Service Should Trigger

| Finding                           | Likely first response                   |
| --------------------------------- | --------------------------------------- |
| GuardDuty compromised credentials | Investigate + revoke/rotate credentials |
| GuardDuty EC2 compromise          | Contain workload + preserve evidence    |
| GuardDuty malware                 | Quarantine/investigate                  |
| Inspector critical CVE            | Patch/rebuild/deploy                    |
| Inspector vulnerable image        | Rebuild container image                 |
| Inspector Lambda CVE              | Update dependency/layer                 |
| Macie sensitive public bucket     | Remove exposure + assess data impact    |
| Security Hub failed control       | Fix configuration/posture               |
| Access Analyzer external trust    | Validate/remove unintended trust        |

This is far more useful than treating every service finding identically.

---

# 100. Production Prioritization Formula

Think:

```text
PRIORITY
≈

Severity
×
Exploitability
×
Exposure
×
Business Criticality
×
Evidence of Active Attack
```

Example:

```text
CVSS 9.8
isolated dev host
```

may be important.

But:

```text
CVSS 8.1
internet-facing production host
+
GuardDuty compromise finding
+
customer-data access
```

may require immediate incident response.

Security is about context.

---

# 101. Certification Trap — Inspector vs GuardDuty

Question:

> Find known CVEs in EC2 instances and ECR images.

Answer:

```text
Amazon Inspector
```

Not:

```text
GuardDuty
```

Inspector continuously scans supported EC2, ECR and Lambda resources for vulnerability-related findings. ([AWS Documentation][32])

---

# 102. Certification Trap — GuardDuty

Question:

> Detect unusual credential behavior, malicious network communication, suspicious runtime activity and attack sequences.

Answer:

```text
Amazon GuardDuty
```

([AWS Documentation][3])

---

# 103. Certification Trap — Macie

Question:

> Automatically identify sensitive information stored across S3.

Answer:

```text
Amazon Macie
```

([AWS Documentation][2])

---

# 104. Certification Trap — Security Hub

Question:

> Centralize findings from multiple AWS security services and continuously evaluate security controls.

Answer:

```text
AWS Security Hub CSPM
```

([AWS Documentation][1])

---

# 105. Scenario — Critical CVE, No Attack Evidence

Use:

```text
Inspector
```

to understand vulnerability.

Then:

```text
patch/rebuild
```

Don't claim GuardDuty will necessarily report something merely because a CVE exists.

---

# 106. Scenario — Cryptomining Process

Use:

```text
GuardDuty Runtime Monitoring
```

where the workload/resource is supported and Runtime Monitoring is configured appropriately. ([AWS Documentation][7])

Inspector doesn't tell you:

```text
"cryptominer is currently executing"
```

just because a vulnerable package exists.

---

# 107. Scenario — Malicious User Upload

Requirement:

> Customers upload PDFs and ZIP files to S3. Detect malware.

Think:

```text
GuardDuty Malware Protection for S3
```

([AWS Documentation][10])

If requirement is:

> Detect credit-card numbers inside uploaded files.

Think:

```text
Macie
```

---

# 108. Scenario — Container CVEs

Requirement:

> Continuously scan ECR images when new vulnerabilities become known.

Think:

```text
ECR Enhanced Scanning
+
Amazon Inspector
```

([AWS Documentation][18])

---

# 109. Scenario — Central Organization Security

Requirement:

> 100 accounts, many Regions, central security team.

Architecture:

```text
AWS Organizations
+
delegated security administrator account
+
GuardDuty
+
Inspector
+
Macie
+
Security Hub CSPM
```

with deliberate Regional coverage and Security Hub central configuration/aggregation. ([AWS Documentation][26])

---

# 110. What Not to Do

```text
"Security Hub is enabled,
therefore GuardDuty is enabled everywhere."
```

Wrong.

```text
"Inspector reports CVE,
therefore server is compromised."
```

Wrong.

```text
"GuardDuty had no findings,
therefore there are no vulnerabilities."
```

Wrong.

```text
"Macie scans EC2 disks for secrets."
```

Wrong mental model.

```text
"Zero findings means secure."
```

Potentially very wrong if coverage is incomplete.

---

# 111. Coverage Is a Security Metric

For every service ask:

```text
GuardDuty:
Which accounts/Regions/plans covered?

Inspector:
Which EC2/ECR/Lambda resources covered?

Macie:
Which buckets/accounts analyzed?

Security Hub:
Which accounts/Regions/controls configured?
```

The security question is not:

```text
"Is the service enabled somewhere?"
```

It is:

```text
"Is the intended asset population
actually covered?"
```

---

# 112. Never-Forget Master Map

```text
                    AWS SECURITY DETECTION

                           GuardDuty
                               │
                     ACTIVE THREAT SIGNALS
                               │
                               ▼
                          Security Hub
                               ▲
                               │
                     VULNERABILITY SIGNALS
                               │
                           Inspector


                               ▲
                               │
                     SENSITIVE DATA SIGNALS
                               │
                             Macie


Security Hub
    │
    ├── normalize findings
    ├── posture controls
    ├── standards
    ├── cross-account view
    ├── cross-Region aggregation
    ├── automation rules
    └── EventBridge
            │
            ▼
       RESPONSE / SIEM
```

---

# 113. 30 Rules to Burn Into Memory

```text
1. GuardDuty = threat detection.

2. Inspector = vulnerability management.

3. Macie = S3 data security / sensitive-data discovery.

4. Security Hub CSPM = central posture + findings.

5. Vulnerability does not equal compromise.

6. Finding does not automatically equal confirmed breach.

7. GuardDuty foundational detection uses
   CloudTrail management, network-flow and DNS data.

8. S3 Protection detects suspicious S3 data access.

9. EKS Protection analyzes EKS audit activity.

10. Runtime Monitoring looks inside supported workloads.

11. Malware Protection for EC2 scans EBS volumes.

12. Malware Protection for S3 scans uploaded S3 objects.

13. RDS Protection analyzes suspicious login behavior.

14. Lambda Protection analyzes suspicious Lambda networking.

15. Extended Threat Detection correlates
    multi-stage attack signals.

16. Inspector scans EC2 vulnerabilities/exposure.

17. ECR enhanced scanning uses Inspector.

18. Continuous scanning matters because
    new CVEs appear after an image was built.

19. Inspector scans Lambda dependencies.

20. Macie automated discovery uses sampling.

21. Macie discovery jobs are targeted/deeper scans.

22. Macie managed identifiers detect known categories.

23. Custom identifiers detect your own patterns.

24. Macie malware scanning is NOT its job.

25. Security Hub normalizes findings using ASFF.

26. Security Hub automation rules manage findings.

27. EventBridge triggers external remediation workflows.

28. Security services need multi-account
    AND multi-Region coverage.

29. Zero findings without coverage data means very little.

30. Detection → investigation → containment →
    remediation → recovery.
```

---

# The One Comparison to Never Forget

```text
Server contains vulnerable package
        │
        ▼
INSPECTOR


Server communicates with malware C2
        │
        ▼
GUARDDUTY


S3 object contains customer passport data
        │
        ▼
MACIE


All those findings need central visibility
        │
        ▼
SECURITY HUB
```

That single diagram answers a huge number of SAA-C03 and DOP-C02 questions.

---

# ✅ Lesson 31 Part 4 Complete

You now understand:

```text
✓ detection vs prevention
✓ threat vs vulnerability
✓ GuardDuty fundamentals
✓ foundational data sources
✓ CloudTrail threat analysis
✓ VPC/DNS threat detection
✓ S3 Protection
✓ EKS Protection
✓ Runtime Monitoring
✓ ECS/Fargate runtime monitoring
✓ EC2 malware scanning
✓ S3 malware scanning
✓ RDS Protection
✓ Lambda Protection
✓ Extended Threat Detection
✓ attack sequences

✓ Amazon Inspector
✓ EC2 scanning
✓ agent-based scanning
✓ agentless scanning
✓ Enhanced EC2 Scanning
✓ network reachability
✓ CVE
✓ CVSS
✓ Inspector scoring
✓ ECR enhanced scanning
✓ continuous container scanning
✓ running-container mapping
✓ Lambda scanning
✓ Lambda code scanning
✓ Inspector Code Security

✓ Amazon Macie
✓ S3 sensitive-data discovery
✓ automated discovery
✓ sampling
✓ discovery jobs
✓ managed identifiers
✓ custom identifiers
✓ allow lists
✓ policy findings
✓ sensitive-data findings

✓ Security Hub CSPM
✓ ASFF
✓ security standards
✓ security controls
✓ FSBP
✓ integrated findings
✓ automation rules
✓ EventBridge
✓ cross-Region aggregation
✓ home Region
✓ delegated administration
✓ central configuration

✓ Amazon Detective role
✓ incident-response workflow
✓ multi-account architecture
✓ multi-Region architecture
✓ CLI investigation
✓ Terraform/IaC mental model
✓ production incident scenarios
✓ SAA-C03 / DOP-C02 traps
```

# Next — Lesson 31 Part 5

# **AWS WAF, Shield, Network Firewall & Firewall Manager — Production Perimeter Security**

Part 4 taught us:

```text
DETECT
```

Part 5 moves back in front of the application:

```text
                    INTERNET ATTACKER
                           │
                           ▼
                        Route 53
                           │
                           ▼
                       CloudFront
                           │
                 ┌─────────┴─────────┐
                 ▼                   ▼
               Shield               WAF
                 │                   │
                 │              SQL injection
                 │              XSS
                 │              bots
                 │              rate abuse
                 │              IP reputation
                 │                   │
                 └──────────┬────────┘
                            ▼
                           ALB
                            │
                            ▼
                       Application


                 EAST/WEST / VPC TRAFFIC
                            │
                            ▼
                    AWS Network Firewall
                            │
                            ▼
                         Workloads


                    ORGANIZATION SCALE
                            │
                            ▼
                    Firewall Manager
```

We'll cover **WAF Web ACLs, managed rule groups, SQLi/XSS protection, rate-based rules, bot control, CAPTCHA/challenge, IP sets, regex sets, labels, scope-down statements, CloudFront-vs-Regional WAF placement, Shield Standard vs Shield Advanced, DDoS layers, DRT/SRT response, cost-protection considerations, Network Firewall stateful/stateless inspection, Suricata-compatible rules, centralized inspection VPCs, Transit Gateway routing, Firewall Manager organization policies, Terraform, logging, false-positive tuning, and a full internet-facing production security capstone**.

After that we'll close the broader **Lesson 31 AWS Security Architecture chapter** and move into the next major AWS Production Architecture lesson.

[1]: https://docs.aws.amazon.com/securityhub/latest/userguide/what-is-securityhub.html "Introduction to AWS Security Hub CSPM - AWS Security Hub"
[2]: https://docs.aws.amazon.com/macie/latest/user/discovery-asdd.html "Performing automated sensitive data discovery - Amazon Macie"
[3]: https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html "What is Amazon GuardDuty? - Amazon GuardDuty"
[4]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-pricing.html?utm_source=chatgpt.com "Pricing in GuardDuty - AWS Documentation"
[5]: https://docs.aws.amazon.com/guardduty/latest/ug/s3-protection.html?utm_source=chatgpt.com "GuardDuty S3 Protection"
[6]: https://docs.aws.amazon.com/guardduty/latest/ug/kubernetes-protection.html?utm_source=chatgpt.com "GuardDuty EKS Protection"
[7]: https://docs.aws.amazon.com/guardduty/latest/ug/runtime-monitoring.html?utm_source=chatgpt.com "GuardDuty Runtime Monitoring"
[8]: https://docs.aws.amazon.com/guardduty/latest/ug/how-runtime-monitoring-works-ecs-fargate.html?utm_source=chatgpt.com "How Runtime Monitoring works with Fargate (Amazon ECS ..."
[9]: https://docs.aws.amazon.com/guardduty/latest/ug/malware-protection.html?utm_source=chatgpt.com "GuardDuty Malware Protection for EC2"
[10]: https://docs.aws.amazon.com/guardduty/latest/ug/gdu-malware-protection-s3.html?utm_source=chatgpt.com "GuardDuty Malware Protection for S3"
[11]: https://docs.aws.amazon.com/guardduty/latest/ug/rds-protection.html?utm_source=chatgpt.com "GuardDuty RDS Protection"
[12]: https://docs.aws.amazon.com/guardduty/latest/ug/lambda-protection.html?utm_source=chatgpt.com "GuardDuty Lambda Protection"
[13]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-extended-threat-detection.html?utm_source=chatgpt.com "GuardDuty Extended Threat Detection - AWS Documentation"
[14]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-attack-sequence-finding-types.html?utm_source=chatgpt.com "GuardDuty attack sequence finding types"
[15]: https://docs.aws.amazon.com/inspector/latest/user/what-is-inspector.html "What is Amazon Inspector? - Amazon Inspector"
[16]: https://docs.aws.amazon.com/inspector/latest/user/scanning-ec2.html?utm_source=chatgpt.com "Scanning Amazon EC2 instances with Amazon Inspector"
[17]: https://docs.aws.amazon.com/inspector/latest/user/findings-understanding-score.html?utm_source=chatgpt.com "Viewing the Amazon Inspector score and understanding ..."
[18]: https://docs.aws.amazon.com/inspector/latest/user/scanning-ecr.html "Scanning Amazon Elastic Container Registry container images with Amazon Inspector - Amazon Inspector"
[19]: https://docs.aws.amazon.com/inspector/latest/user/scanning-resources.html "Automated scan types in Amazon Inspector - Amazon Inspector"
[20]: https://docs.aws.amazon.com/inspector/latest/user/scanning_resources_lambda_code.html?utm_source=chatgpt.com "Amazon Inspector Lambda code scanning"
[21]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-internal-providers.html "AWS service integrations with Security Hub CSPM - AWS Security Hub"
[22]: https://docs.aws.amazon.com/macie/latest/user/discovery-jobs.html?utm_source=chatgpt.com "Running sensitive data discovery jobs - Amazon Macie"
[23]: https://docs.aws.amazon.com/macie/latest/user/findings.html?utm_source=chatgpt.com "Reviewing and analyzing Macie findings - AWS Documentation"
[24]: https://docs.aws.amazon.com/securityhub/latest/userguide/standards-reference.html "Standards reference for Security Hub CSPM - AWS Security Hub"
[25]: https://docs.aws.amazon.com/securityhub/latest/userguide/automation-rules.html?utm_source=chatgpt.com "Understanding automation rules in Security Hub CSPM"
[26]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html?utm_source=chatgpt.com "Managing GuardDuty accounts with AWS Organizations"
[27]: https://docs.aws.amazon.com/macie/latest/user/accounts-mgmt-ao-integrate.html "Integrating and configuring an organization in Macie - Amazon Macie"
[28]: https://docs.aws.amazon.com/securityhub/latest/userguide/central-configuration-intro.html "Understanding central configuration in Security Hub CSPM - AWS Security Hub"
[29]: https://docs.aws.amazon.com/securityhub/latest/userguide/finding-aggregation-enable.html "Enabling cross-Region aggregation - AWS Security Hub"
[30]: https://docs.aws.amazon.com/macie/latest/user/data-classification.html "Discovering sensitive data with Macie - Amazon Macie"
[31]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector "Terraform Registry"
[32]: https://docs.aws.amazon.com/inspector/latest/user/scanning-resources.html?utm_source=chatgpt.com "Automated scan types in Amazon Inspector"
