# AWS Masterclass — Phase 3

# Lesson 57: GuardDuty, Security Hub, Inspector, Macie, Detective and IAM Access Analyzer

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Design centralized AWS security monitoring.
* Distinguish threat detection, vulnerability management, posture management, data discovery and access analysis.
* Enable security services across AWS Organizations.
* Use delegated security-administrator accounts.
* Understand GuardDuty data sources and protection plans.
* Investigate critical GuardDuty attack sequences.
* Use malware protection for EC2 and S3.
* Aggregate findings through Security Hub.
* Manage Security Hub standards, controls and workflow states.
* Automate finding enrichment, ticketing and remediation.
* Scan EC2, ECR, Lambda and source repositories using Inspector.
* Prioritize vulnerabilities using exposure and exploitability context.
* Generate and scan software bills of materials.
* Discover credentials, PII, PHI and financial data in S3 using Macie.
* Investigate correlated security activity using Detective.
* Detect external, internal and unused access using IAM Access Analyzer.
* Prevent dangerous IAM policies in CI/CD.
* Build EventBridge-based security response pipelines.
* Design safe automated containment.
* Provision security controls using Terraform.
* Conduct an end-to-end incident investigation.

---

# 2. The AWS security-service mental model

These services solve different security problems.

```text
Amazon GuardDuty
    → Is malicious or suspicious activity happening?

AWS Security Hub
    → What security findings and posture failures exist centrally?

Amazon Inspector
    → Which workloads contain exploitable vulnerabilities?

Amazon Macie
    → Where is sensitive data stored in S3?

Amazon Detective
    → How are suspicious entities and activities connected?

IAM Access Analyzer
    → Who can access resources, and are permissions excessive?
```

## Never-forget distinction

```text
GuardDuty:
Threat detection

Security Hub:
Finding aggregation and security posture

Inspector:
Vulnerability management

Macie:
Sensitive-data discovery

Detective:
Security investigation

Access Analyzer:
Permission analysis
```

---

# 3. Security monitoring architecture

A mature AWS organization should not operate each security service separately in every workload account.

```text
AWS Organizations
        |
        v
Central security account
        |
        ├── GuardDuty delegated administrator
        ├── Security Hub delegated administrator
        ├── Inspector delegated administrator
        ├── Macie delegated administrator
        ├── Detective administrator
        └── IAM Access Analyzer organization analyzers
                |
                v
       Centralized findings
                |
                v
          EventBridge
                |
      ┌─────────┼──────────┐
      v         v          v
   Ticketing   Alerts   Remediation
              SNS      Step Functions/
                       SSM Automation
```

GuardDuty, Security Hub CSPM, Inspector, Macie and Detective support multi-account administration patterns using AWS Organizations or administrator/member relationships. Their administrator configuration remains Regional, so deployment must cover every Region in which resources might exist—not only the primary application Region. ([AWS Documentation][1])

---

# 4. Why enable security services in unused Regions?

Attackers who obtain AWS credentials may deliberately create resources in a Region your team rarely checks.

Example:

```text
Company workloads:
ap-south-1

Compromised credentials:
Create EC2 crypto-mining instances in another Region
```

Therefore, detective services should normally be enabled in all supported commercial Regions, including Regions where you do not intentionally deploy applications. AWS Security Incident Response similarly recommends GuardDuty coverage across active commercial Regions so suspicious activity is detected even in Regions without normal workloads. ([AWS Documentation][2])

---

# 5. Central security-account responsibilities

The security account should normally own:

```text
Organization-wide security configuration
Finding aggregation
Security dashboards
Security automation
Investigation tooling
Long-term finding archive
SIEM integrations
Incident-response roles
```

It should not ordinarily host:

```text
Customer-facing application workloads
Development experiments
General CI/CD runners
Untrusted third-party integrations
```

Separating security administration reduces the chance that a compromised workload account can disable monitoring or destroy investigation evidence.

---

# Part 1 — Amazon GuardDuty

# 6. What is Amazon GuardDuty?

Amazon GuardDuty is a managed threat-detection service that continuously analyzes AWS data sources and workload telemetry to identify suspicious or malicious activity.

It uses:

* Threat-intelligence feeds.
* Malicious IP and domain lists.
* File hashes.
* Statistical analysis.
* Machine-learning models.
* Behavioral baselines.
* Multi-signal correlation.

GuardDuty generates findings rather than blocking activity directly. ([AWS Documentation][3])

```text
AWS activity and telemetry
        |
        v
     GuardDuty
        |
        v
Security finding
        |
        v
Investigation and response
```

---

# 7. GuardDuty foundational data sources

GuardDuty foundational threat detection analyzes sources including:

```text
AWS CloudTrail management events
Amazon VPC Flow Logs
Route 53 Resolver DNS query logs
```

You do not need to manually create your own VPC Flow Logs or Route 53 query-log resources for GuardDuty’s managed analysis pipeline. Optional protection plans add additional data sources and workload telemetry. ([AWS Documentation][4])

---

# 8. GuardDuty protection plans

Depending on Region and workload type, GuardDuty protection capabilities include:

```text
S3 Protection
EKS Protection
Runtime Monitoring
RDS Protection
Lambda Protection
Malware Protection for EC2
Malware Protection for S3
Extended Threat Detection
```

Foundational detection starts after GuardDuty is enabled, while optional protection plans must be configured according to the organization’s required coverage. ([AWS Documentation][4])

---

# 9. GuardDuty detector

A GuardDuty detector is the Regional service configuration for one AWS account.

```text
AWS account
    |
    v
GuardDuty detector in ap-south-1

AWS account
    |
    v
Separate detector in us-east-1
```

GuardDuty is Regional. Enabling a detector in Mumbai does not automatically create equivalent coverage in every other Region.

---

# 10. GuardDuty finding

A finding represents a potential security issue involving:

* IAM credentials.
* EC2 instances.
* Containers.
* EKS clusters.
* ECS workloads.
* S3 buckets.
* Databases.
* Lambda functions.
* IP addresses.
* Domains.
* Malware.
* Multi-stage attack activity.

A finding includes the affected resource, activity, severity, timestamps and remediation guidance. ([AWS Documentation][5])

---

# 11. GuardDuty severity levels

GuardDuty uses a numerical severity from 1.0 to 10.0:

| Severity |    Range | General interpretation                          |
| -------- | -------: | ----------------------------------------------- |
| Low      |  1.0–3.9 | Suspicious attempt or reconnaissance            |
| Medium   |  4.0–6.9 | Anomalous activity that may indicate compromise |
| High     |  7.0–8.9 | Resource is likely compromised or misused       |
| Critical | 9.0–10.0 | High-confidence or multi-stage attack activity  |

Critical and high findings require urgent triage. Medium findings require contextual investigation, while low findings may still reveal reconnaissance or weak controls. ([AWS Documentation][6])

---

# 12. Example credential-compromise finding

```text
Finding:
CredentialAccess:IAMUser/AnomalousBehavior

Potential indicators:
- API calls from a new country
- Services never used by this identity
- Unusual credential enumeration
- Security-control discovery
- Resource creation at abnormal time
```

Response:

```text
1. Identify the IAM principal.

2. Determine whether access is authorized.

3. Disable or revoke exposed credentials.

4. Inspect CloudTrail activity.

5. Review created or modified resources.

6. Rotate dependent credentials.

7. Evaluate privilege escalation.

8. Preserve evidence.

9. Remediate and monitor.
```

Do not merely archive a credential-compromise finding because the IP address is unfamiliar.

---

# 13. Extended Threat Detection

GuardDuty Extended Threat Detection correlates signals across resources, data sources and time to detect multi-stage attacks.

Instead of generating only isolated findings:

```text
Unusual credential use
Suspicious API discovery
Malicious EC2 communication
S3 data access
```

it can correlate them into:

```text
Attack sequence:
Potentially compromised credentials and resources
```

Extended Threat Detection is enabled for GuardDuty accounts and produces attack-sequence findings that help identify broader compromises with greater confidence. ([AWS Documentation][7])

---

# 14. Attack-sequence finding

An attack-sequence finding contains:

* Related signals.
* Timeline.
* Impacted entities.
* MITRE ATT&CK tactics.
* Potentially compromised resources.
* Consolidated severity.
* Remediation guidance.

Examples include sequences indicating compromised:

```text
AWS credentials
EC2 instances
ECS clusters
S3 resources
```

GuardDuty correlates suspicious actions such as malware execution, credential misuse, malicious network communication and resource manipulation into high-confidence sequences. ([AWS Documentation][8])

---

# 15. Why attack sequences matter

Isolated findings can look harmless:

```text
Finding A:
DescribeInstances from unusual location

Finding B:
CreateAccessKey

Finding C:
S3 object enumeration

Finding D:
EC2 instance contacting mining domain
```

Viewed separately, each may receive insufficient attention.

Viewed as a sequence:

```text
Credential compromise
    |
    v
Environment reconnaissance
    |
    v
Privilege persistence
    |
    v
Data discovery
    |
    v
Malicious compute
```

the incident priority becomes much clearer.

---

# 16. GuardDuty Investigation preview

As of August 2026, **GuardDuty Investigation is in public preview** in selected Regions. It can perform AI-powered analysis of GuardDuty findings or AWS accounts and return:

* Risk disposition.
* Confidence score.
* MITRE ATT&CK classification.
* Supporting evidence.
* Related activity from up to the previous 90 days.
* Recommended next actions.

Because it is a preview feature, it should assist analysts rather than replace evidence review or become the only production incident-response dependency. ([AWS Documentation][9])

---

# 17. S3 Protection

GuardDuty S3 Protection analyzes CloudTrail data events for S3 to detect suspicious object and bucket activity.

Potential scenarios include:

* Unusual object access.
* Data discovery.
* Data exfiltration patterns.
* Access from malicious infrastructure.
* Unusual use of credentials against S3.

S3 Protection findings require the protection feature and relevant GuardDuty configuration. ([AWS Documentation][10])

---

# 18. Malware Protection for S3

Malware Protection for S3 scans newly uploaded objects or new object versions in selected S3 buckets.

```text
Object uploaded
      |
      v
GuardDuty malware scan
      |
      ├── Clean
      ├── Malware detected
      ├── Scan failed
      └── Unsupported/size condition
```

Scan results can be published to EventBridge and CloudWatch. Optional object tagging can mark the result on the S3 object. When used independently without a GuardDuty detector, scanning can operate but normal GuardDuty findings are not generated because findings belong to a detector. ([AWS Documentation][11])

---

# 19. Secure upload pipeline

```text
User upload
    |
    v
Quarantine S3 bucket
    |
    v
GuardDuty Malware Protection for S3
    |
    ├── Clean tag
    |      |
    |      v
    |  Move/copy to trusted bucket
    |
    └── Malware detected
           |
           v
       Isolate object
       Notify security
       Block processing
```

Never let downstream parsers, OCR workers or document-processing services consume unscanned uploads from untrusted users.

---

# 20. Malware Protection for EC2

GuardDuty Malware Protection for EC2 can scan EBS volumes associated with potentially compromised EC2 workloads.

It supports:

* GuardDuty-initiated malware scans following relevant findings.
* On-demand malware scans.
* Detection of malicious files.
* Scan findings connected to affected EC2 resources.

GuardDuty also provides finding types specific to malware detected through EC2 scanning. ([AWS Documentation][12])

---

# 21. Runtime Monitoring

GuardDuty Runtime Monitoring analyzes operating-system-level behavior from:

* EC2 instances.
* EKS workloads.
* ECS workloads.
* Fargate workloads where supported.

It can detect suspicious process execution, unusual file behavior, privilege escalation, container activity and malicious network connections from inside running workloads. ([AWS Documentation][13])

---

# 22. Why runtime monitoring matters

Control-plane logs may show:

```text
ECS task launched normally
```

but runtime telemetry may reveal:

```text
Container launched shell
Downloaded crypto miner
Modified system binary
Contacted malicious domain
Attempted privilege escalation
```

Control-plane activity alone cannot identify every action occurring inside a running workload.

---

# 23. RDS Protection

GuardDuty RDS Protection analyzes login activity for supported database engines to identify suspicious access patterns.

Potential signals include:

* Abnormal database login behavior.
* Suspicious authentication activity.
* Access from unusual sources.
* Patterns inconsistent with the learned baseline.

RDS Protection depends on supported database configuration and healthy telemetry collection. ([AWS Documentation][14])

---

# 24. Lambda Protection

Lambda Protection analyzes network activity from Lambda functions.

Potential use cases:

* Function contacting a malicious IP.
* Compromised dependency communicating externally.
* Unexpected cryptocurrency-mining endpoint.
* Data exfiltration attempts.
* Function behaving differently from its normal pattern.

A normal Lambda invocation does not prove that the code executed safely.

---

# 25. GuardDuty multi-account deployment

Use AWS Organizations and designate a delegated GuardDuty administrator account.

```text
Organizations management account
        |
        | Delegates GuardDuty administration
        v
Security account
        |
        ├── Member account A
        ├── Member account B
        └── Member account C
```

The delegated administrator and membership configuration must be established in every desired Region because GuardDuty administration is Regional. ([AWS Documentation][1])

---

# 26. GuardDuty auto-enable modes

Organization configuration supports:

```text
ALL
    → Existing and new members

NEW
    → Future member accounts

NONE
    → No automatic action
```

For a production organization, `ALL` is normally the safest starting point so existing accounts are not accidentally excluded. Optional protection-plan auto-enable settings should also be managed centrally. ([AWS Documentation][15])

---

# 27. GuardDuty administrator placement

Recommended:

```text
Organizations management account:
Only organization-level governance

Dedicated security account:
GuardDuty delegated administrator
```

Avoid using the Organizations management account as the daily GuardDuty operational account.

The security account should have:

* Restricted administrative access.
* MFA.
* Central incident-response roles.
* Limited workload resources.
* Protected logging.
* Separate security automation roles.

---

# 28. GuardDuty finding publication

GuardDuty automatically sends findings to EventBridge.

```text
GuardDuty finding
       |
       v
Default EventBridge bus
       |
       ├── SNS notification
       ├── Lambda enrichment
       ├── Security Hub
       ├── Ticketing
       ├── Step Functions
       └── SSM Automation
```

EventBridge provides near-real-time finding delivery to supported targets. ([AWS Documentation][16])

---

# 29. GuardDuty EventBridge pattern

```json
{
  "source": [
    "aws.guardduty"
  ],
  "detail-type": [
    "GuardDuty Finding"
  ],
  "detail": {
    "severity": [
      {
        "numeric": [
          ">=",
          7
        ]
      }
    ]
  }
}
```

This routes high and critical findings.

Do not send every low-severity finding directly to an urgent paging channel.

---

# 30. GuardDuty suppression rules

Suppression rules automatically suppress findings matching defined criteria.

Use for:

* Verified security testing.
* Known scanners.
* Expected administrative tooling.
* Documented benign activity.
* Low-value recurring signals.

GuardDuty suppression is powerful: suppressed findings are not sent to Security Hub CSPM, Detective, S3 exports or EventBridge. Therefore, an incorrect suppression rule can hide important security evidence from the complete downstream pipeline. ([AWS Documentation][17])

---

# 31. Safe suppression process

```text
1. Investigate several occurrences.

2. Prove the activity is expected.

3. Restrict the rule narrowly.

4. Document:
   owner
   reason
   expiry date
   affected resources

5. Review the rule periodically.

6. Remove it when the exception ends.
```

Bad suppression:

```text
Suppress all medium findings
```

Better:

```text
Suppress one specific finding type
for one authorized scanner role
from one approved source network
until a review date
```

---

# 32. GuardDuty remediation principle

GuardDuty detects; it does not automatically clean the environment.

Possible containment actions:

```text
Compromised IAM credentials
    → Disable or revoke credentials

Compromised EC2 instance
    → Isolate security group
    → Preserve evidence
    → Replace instance

Malicious S3 object
    → Quarantine object
    → Block downstream access

Compromised container
    → Stop task
    → Isolate service
    → Replace image

Suspicious database login
    → Revoke credentials
    → Restrict network path
```

AWS provides resource-specific remediation guidance for GuardDuty findings. ([AWS Documentation][18])

---

# Part 2 — AWS Security Hub

# 33. What is AWS Security Hub?

AWS Security Hub provides a central security view that combines:

* Security posture findings.
* Threat findings.
* Vulnerability findings.
* Sensitive-data findings.
* Access findings.
* Third-party security findings.
* Security standards and controls.
* Automation and workflow management.

Current AWS documentation distinguishes broader **AWS Security Hub** from the **Security Hub CSPM** posture-management capability. Security Hub receives findings from services including GuardDuty, Inspector, Macie and IAM Access Analyzer. ([AWS Documentation][19])

---

# 34. Security Hub architecture

```text
GuardDuty ─────────┐
Inspector ─────────┤
Macie ─────────────┤
Access Analyzer ───┤
Security Hub CSPM ─┼──> AWS Security Hub
Partner tools ─────┘           |
                               v
                       Central findings
                               |
                               v
                    Automation and response
```

---

# 35. Security Hub CSPM

Security Hub CSPM evaluates AWS resource configurations against security standards and controls.

Examples:

```text
S3 public access should be blocked
CloudTrail should be enabled
KMS rotation should be enabled
RDS storage should be encrypted
Security groups should restrict public ingress
IAM root user should have MFA
```

Many CSPM controls depend on AWS Config to evaluate resource configuration. ([AWS Documentation][20])

---

# 36. Security standards

A security standard is a collection of controls mapped to:

* AWS best practices.
* Industry guidance.
* Regulatory frameworks.
* Organizational requirements.

A standard does not by itself prove compliance with an entire law or certification.

```text
Security Hub standard:
Technical-control assessment

Formal compliance:
Technical controls
+
Processes
+
People
+
Evidence
+
Legal interpretation
```

Security Hub CSPM maps requirements in standards to security controls and performs checks against those controls. ([AWS Documentation][21])

---

# 37. Control and finding

```text
Control:
S3 buckets should block public access

Resource:
production-upload-bucket

Finding:
FAILED for that bucket
```

One control can produce findings for several resources.

```text
Control S3.1
├── Bucket A: PASSED
├── Bucket B: FAILED
└── Bucket C: PASSED
```

---

# 38. Security score

Security Hub CSPM calculates security scores based on enabled controls and their passing status.

A security score is useful for:

* Measuring direction.
* Comparing organizational units.
* Tracking remediation progress.
* Identifying broad posture decline.

It should not become the only objective.

A team can improve a score by disabling difficult controls, which would create misleading governance. Disabled controls require documented justification.

---

# 39. Finding formats

Existing Security Hub CSPM APIs and automation commonly use the **AWS Security Finding Format**, or ASFF.

The broader current Security Hub experience also documents normalization using the **Open Cybersecurity Schema Framework**, or OCSF.

Therefore, when creating integrations, verify whether the specific API, EventBridge event or product surface uses ASFF or OCSF rather than assuming one universal schema. ([AWS Documentation][19])

---

# 40. Security Hub workflow status

Common CSPM finding workflow states are:

```text
NEW
NOTIFIED
RESOLVED
SUPPRESSED
```

## NEW

Not yet reviewed or re-opened by a new failure.

## NOTIFIED

Owner has been notified or investigation is underway.

## RESOLVED

The issue has been remediated or closed operationally.

## SUPPRESSED

The issue is an accepted exception or should not appear in normal active workflow.

Changing a finding to `RESOLVED` or `SUPPRESSED` does not prevent a new finding from being generated when the problem occurs again. ([AWS Documentation][22])

---

# 41. Security Hub workflow

```text
Finding generated
      |
      v
NEW
      |
      v
NOTIFIED
      |
      ├── Remediated → RESOLVED
      |
      └── Approved exception → SUPPRESSED
```

Each finding should have:

* Owner.
* Severity.
* Business impact.
* Remediation deadline.
* Ticket.
* Evidence.
* Final disposition.

---

# 42. Central configuration

Security Hub CSPM central configuration allows a delegated administrator to configure across accounts and Regions:

* Service enablement.
* Security standards.
* Controls.
* Control parameters.
* Organizational-unit assignments.

Configuration policies can be applied centrally to AWS Organizations accounts and OUs. ([AWS Documentation][23])

---

# 43. Policy assignment architecture

```text
Security Hub delegated administrator
        |
        ├── Production OU
        |      → Strict production policy
        |
        ├── Sandbox OU
        |      → Development policy
        |
        └── Security OU
               → Security-service policy
```

Examples:

## Production policy

```text
Security Hub enabled
AWS Foundational Security Best Practices enabled
CIS controls enabled
No public-access control exceptions
```

## Sandbox policy

```text
Security Hub enabled
Core standards enabled
Selected low-risk controls disabled
Short remediation SLA
```

---

# 44. Cross-Region finding aggregation

Security Hub CSPM can aggregate:

* Findings.
* Finding updates.
* Insights.
* Control compliance.
* Security scores.

from linked Regions into a designated home Region. ([AWS Documentation][24])

For an India-centered environment:

```text
Home Region:
ap-south-1

Linked Regions:
All supported operational Regions
```

Choose the home Region intentionally because changing it requires removing and recreating the finding aggregator.

---

# 45. Automation rules

Security Hub CSPM automation rules can update finding fields based on matching criteria.

Examples:

```text
Finding from approved penetration test
    → Workflow status = SUPPRESSED

Critical GuardDuty finding
    → Severity remains critical
    → Workflow status = NEW

Development-account low finding
    → Severity adjusted according to policy

Specific unsupported resource
    → Add note and owner
```

Automation rules can update fields such as workflow status and severity. In cross-Region aggregation configurations, rules are managed from the home Region for linked Regions. ([AWS Documentation][25])

---

# 46. Automation rules versus EventBridge

## Security Hub automation rule

```text
Modifies finding metadata
```

Examples:

* Change workflow status.
* Adjust severity.
* Add notes.
* Normalize finding fields.

## EventBridge rule

```text
Triggers external action
```

Examples:

* Create ticket.
* Invoke Lambda.
* Send SNS message.
* Start Step Functions.
* Run SSM command.
* Call API destination.

Security Hub sends new and updated findings to EventBridge in near real time. ([AWS Documentation][26])

---

# 47. Security Hub EventBridge pattern

```json
{
  "source": [
    "aws.securityhub"
  ],
  "detail-type": [
    "Security Hub Findings - Imported"
  ],
  "detail": {
    "findings": {
      "Severity": {
        "Label": [
          "CRITICAL"
        ]
      },
      "Workflow": {
        "Status": [
          "NEW"
        ]
      }
    }
  }
}
```

The exact event structure must be validated against the specific Security Hub/CSPM event schema used in your account. Security Hub CSPM finding-import events contain one finding per event. ([AWS Documentation][27])

---

# 48. Finding automation architecture

```text
Security Hub finding
        |
        v
EventBridge rule
        |
        v
Step Functions
        |
        ├── Enrich resource data
        ├── Determine account owner
        ├── Create ticket
        ├── Notify security team
        ├── Request approval
        ├── Run containment
        └── Update finding status
```

This is safer than placing complete incident logic inside one Lambda function.

---

# 49. Finding archive

Security Hub is a finding-management system, not necessarily the only long-term forensic archive.

For long retention:

```text
Security Hub/EventBridge
        |
        v
Data Firehose or Lambda
        |
        v
Security S3 bucket
        |
        v
Athena / SIEM / security data lake
```

Security Hub documentation recommends exporting findings when longer-term retention is required. ([AWS Documentation][28])

---

# Part 3 — Amazon Inspector

# 50. What is Amazon Inspector?

Amazon Inspector is a vulnerability-management service that automatically discovers and continually scans supported AWS workloads for:

* Software vulnerabilities.
* Package CVEs.
* Lambda code vulnerabilities.
* Container-image vulnerabilities.
* Unintended EC2 network exposure.
* Code-repository security issues where Code Security is configured.

Inspector produces detailed findings when a vulnerability or exposure is detected. ([AWS Documentation][29])

---

# 51. Inspector resource coverage

Core scanning targets include:

```text
Amazon EC2 instances
Amazon ECR container images
AWS Lambda functions and layers
```

Newer Inspector capabilities also include Code Security for connected source repositories. ([AWS Documentation][30])

---

# 52. EC2 scanning

Inspector EC2 scanning detects:

* Installed package vulnerabilities.
* Operating-system vulnerabilities.
* Supported language package vulnerabilities.
* Network reachability exposure.

Inspector can use agent-based inventory through Systems Manager or agentless scanning using EBS snapshots for eligible instances. ECR and Lambda scanning do not require SSM Agent. ([AWS Documentation][31])

---

# 53. Agent-based versus agentless scanning

## Agent-based

```text
EC2
 |
 v
SSM Agent and inventory
 |
 v
Inspector vulnerability analysis
```

Advantages:

* Continuous inventory.
* Deep package visibility.
* Integration with Systems Manager.

Dependencies:

* Supported OS.
* Working SSM Agent.
* IAM instance profile.
* SSM connectivity.

## Agentless

```text
EC2 EBS volume
      |
      v
Temporary snapshot-based analysis
      |
      v
Inspector
```

Advantages:

* No host agent dependency.
* Coverage when SSM is unavailable.

Review cost, eligibility and encryption permissions before relying on agentless scanning.

---

# 54. Network-reachability findings

Inspector analyzes network paths to identify potentially reachable EC2 services.

Example:

```text
Internet
   |
   v
Internet Gateway
   |
   v
Public subnet
   |
   v
Security group allows 22
   |
   v
EC2 SSH service
```

A vulnerable package on an internet-reachable service should generally be prioritized above the same vulnerability on an isolated, non-running development instance.

---

# 55. ECR scanning

Inspector scans container images stored in private ECR repositories for package vulnerabilities.

```text
CI/CD pushes image
        |
        v
Amazon ECR
        |
        v
Inspector enhanced scanning
        |
        v
Vulnerability findings
```

When enhanced ECR scanning is activated, Inspector becomes the preferred scanning service for the private registry. ([AWS Documentation][32])

---

# 56. Image tag is not image identity

Tags are mutable:

```text
todo-api:latest
```

can point to a different image tomorrow.

Inspector findings should be tracked using:

```text
Image digest
Repository
Build ID
Source commit
Deployment version
```

Example:

```text
sha256:abc123...
```

Pin production deployments by digest when strong image immutability is required.

---

# 57. ECR image remediation workflow

```text
Inspector finding
      |
      v
Identify affected image digest
      |
      v
Find source repository and build
      |
      v
Update vulnerable dependency/base image
      |
      v
Build new image
      |
      v
Scan new image
      |
      v
Deploy canary
      |
      v
Retire vulnerable image
```

Do not patch running containers manually.

Containers should normally be rebuilt from corrected source and redeployed.

---

# 58. Lambda scanning

Inspector supports:

```text
Lambda standard scanning
Lambda code scanning
```

Standard scanning evaluates vulnerable packages in functions and layers.

Code scanning analyzes supported application code for certain security weaknesses. ([AWS Documentation][33])

---

# 59. Lambda-layer risk

Suppose 100 Lambda functions use:

```text
shared-node-dependencies:7
```

A vulnerability in that layer can affect all 100 functions.

Therefore track:

* Function.
* Layer ARN.
* Layer version.
* Runtime.
* Package version.
* Deployment pipeline.

Replacing the layer does not automatically change functions pinned to the old layer version.

---

# 60. Inspector finding types

Inspector findings include categories such as:

```text
Package vulnerability
Code vulnerability
Network reachability
```

A package-vulnerability finding identifies a CVE affecting an installed package in EC2, ECR or Lambda. Findings include affected package versions, fixed versions where known and vulnerability intelligence. ([AWS Documentation][34])

---

# 61. Inspector score

CVSS gives a general vulnerability score.

Inspector can add environmental context such as:

* Network reachability.
* Exploitability intelligence.
* Workload exposure.
* Package context.

The Inspector score can therefore differ from a generic CVSS base score and help prioritize vulnerabilities according to the AWS environment. ([AWS Documentation][35])

---

# 62. Vulnerability prioritization

Do not prioritize only by CVSS.

A better risk model includes:

```text
Severity
×
Exploit availability
×
Internet reachability
×
Business criticality
×
Privilege level
×
Data sensitivity
×
Exposure duration
```

Example:

```text
CVSS 8.0
Internet-facing production API
Known exploit
Customer data access
    → Immediate priority
```

versus:

```text
CVSS 9.0
Stopped development instance
No network path
No sensitive data
    → Still remediate, but lower immediate urgency
```

---

# 63. Inspector finding lifecycle

Inspector findings use statuses such as:

```text
ACTIVE
SUPPRESSED
CLOSED
```

* Active: vulnerability remains detected.
* Suppressed: hidden by a suppression rule.
* Closed: remediation is detected or the affected resource is no longer relevant.

Suppression does not fix the vulnerability; it only changes finding visibility. ([AWS Documentation][36])

---

# 64. Inspector suppression

Use suppression for:

* Accepted risk with expiry.
* False positive.
* Package not reachable in execution path.
* Temporary vendor exception.
* Non-production workload with approved deadline.

A suppression rule only hides matching findings. Inspector continues storing them until remediation, at which point they are closed. ([AWS Documentation][37])

Every suppression should have:

```text
Business owner
Technical justification
Compensating controls
Expiry date
Review date
Ticket
```

---

# 65. Inspector coverage

A security dashboard showing “zero critical findings” is meaningless if resources are not being scanned.

Monitor Inspector coverage status for:

* EC2 instances.
* ECR repositories/images.
* Lambda functions.
* Accounts.
* Regions.
* Scan types.
* Partial errors.

Inspector provides account and resource coverage views, including states such as actively monitoring with partial errors. ([AWS Documentation][38])

---

# 66. Unsupported operating systems

A workload can lose meaningful scanning when:

* The OS reaches end of support.
* Required SSM inventory stops.
* Runtime becomes unsupported.
* Package metadata cannot be collected.

Inspector support varies by OS, package ecosystem and language. Unsupported or discontinued environments require migration rather than permanent suppression. ([AWS Documentation][39])

---

# 67. Software Bill of Materials

An SBOM lists application components, packages and versions.

```text
TodoApp image
├── node 22.x
├── express
├── mongodb driver
├── winston
├── openssl
└── OS packages
```

The Amazon Inspector SBOM Generator can create SBOMs for directories, archives, container images, local systems and supported compiled binaries. ([AWS Documentation][40])

---

# 68. Inspector in CI/CD

Inspector CI/CD integration can:

```text
Container image
      |
      v
Inspector SBOM Generator
      |
      v
CycloneDX-compatible SBOM
      |
      v
Inspector Scan API
      |
      v
Vulnerability report
```

This allows vulnerabilities to be detected before the image is pushed or deployed. ([AWS Documentation][41])

---

# 69. CI/CD vulnerability gate

Example policy:

```text
Block release when:
- Critical vulnerability has a fix
- High vulnerability has known exploit
- Secret is detected in repository
- Unsupported base OS is used

Warn but allow when:
- Medium vulnerability
- No fix available
- Approved risk exception exists
```

Do not permanently block every build for every vulnerability.

A gate without exceptions and ownership often causes teams to bypass the scanner.

---

# 70. Code Security

Amazon Inspector Code Security connects supported code repositories and applies scan configurations to inspect source projects.

Use it to shift detection earlier than image deployment.

```text
Source repository
       |
       v
Inspector Code Security
       |
       v
Code findings
       |
       v
Developer remediation
```

Code Security must be explicitly activated and configured for repositories and scan schedules. ([AWS Documentation][42])

---

# 71. Inspector organization deployment

Use an Inspector delegated administrator account and centrally auto-enable scan types for organization members.

Current organization configuration can automatically enable:

```text
EC2 scanning
ECR scanning
Lambda standard scanning
Lambda code scanning
```

for new member accounts. ([Terraform Registry][43])

Coverage configuration should be managed in all required Regions.

---

# Part 4 — Amazon Macie

# 72. What is Amazon Macie?

Amazon Macie is a data-security service that discovers sensitive data and identifies S3 data-security risks using:

* Pattern matching.
* Managed data identifiers.
* Custom data identifiers.
* Statistical and machine-learning techniques.
* S3 inventory and security configuration analysis.

Macie focuses on Amazon S3 data estates. ([AWS Documentation][44])

---

# 73. Macie finding categories

Macie generates:

```text
Policy findings
Sensitive-data findings
```

## Policy finding

Indicates an S3 security or privacy risk.

Examples:

* Public bucket.
* Public object access.
* Broad cross-account access.
* Encryption-related issue.

## Sensitive-data finding

Indicates sensitive content detected in an analyzed S3 object.

Examples:

* Credentials.
* Credit-card data.
* Passport numbers.
* Personal information.
* Health information.

([AWS Documentation][45])

---

# 74. Managed data identifiers

Managed identifiers can detect categories such as:

```text
Credentials
Financial data
Personally identifiable information
Protected health information
```

Examples include:

* AWS secret access keys.
* Private keys.
* Credit-card numbers.
* Bank-account numbers.
* Passport numbers.
* National identifiers.
* Health-insurance identifiers.

([AWS Documentation][46])

---

# 75. Finding AWS credentials in S3

Example:

```text
s3://production-exports/debug.txt

Contents:
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

Macie can detect credential patterns, but response must go beyond deleting the file.

```text
1. Disable or rotate credential immediately.

2. Inspect CloudTrail usage.

3. Identify where else the credential exists.

4. Remove object and versions where appropriate.

5. Review logs, backups and build artifacts.

6. Fix the process that generated the file.

7. Confirm no unauthorized access occurred.
```

---

# 76. Automated sensitive-data discovery

Automated discovery continually evaluates S3 inventory and samples representative eligible objects to build broad visibility into where sensitive data may exist.

Macie evaluates S3 inventory daily and selects eligible objects for analysis using sampling. It is designed for broad, continuing data-estate awareness rather than guaranteed full scanning of every object. ([AWS Documentation][47])

---

# 77. Sensitive-data discovery job

A discovery job is explicitly configured to analyze selected S3 objects.

```text
Macie job
   |
   ├── Selected buckets
   ├── Inclusion/exclusion criteria
   ├── Managed identifiers
   ├── Custom identifiers
   ├── Allow lists
   └── One-time or scheduled execution
```

Use a job when you need:

* Complete analysis of a defined dataset.
* Migration assessment.
* Compliance evidence.
* Investigation of a particular bucket.
* Validation before sharing data.
* Classification of newly acquired datasets.

---

# 78. Automated discovery versus job

| Requirement                   | Automated discovery |           Discovery job |
| ----------------------------- | ------------------: | ----------------------: |
| Broad S3 visibility           |           Excellent | Requires explicit scope |
| Sampling                      |                 Yes |  According to job scope |
| Targeted investigation        |             Limited |               Excellent |
| Repeatable compliance scan    |             Limited |               Excellent |
| Continuous prioritization     |           Excellent | Scheduled if configured |
| Specific identifier selection |        Configurable |            Configurable |

Use both:

```text
Automated discovery:
Find where risk might be

Discovery job:
Examine important datasets thoroughly
```

---

# 79. Custom data identifiers

A custom data identifier can use:

* Regular expression.
* Keywords.
* Ignore words.
* Proximity rules.

Example corporate identifier:

```text
Pattern:
YDS-[A-Z]{3}-[0-9]{8}

Keyword:
customer reference
```

Custom identifiers supplement Macie’s managed identifiers for proprietary formats and intellectual property. ([AWS Documentation][48])

---

# 80. Custom identifier risk

A broad regular expression can create:

* Thousands of false positives.
* High analysis cost.
* Finding overload.
* Analyst fatigue.

Testing process:

```text
1. Build representative sample files.

2. Test the custom identifier.

3. Measure false positives.

4. Add keywords and proximity.

5. Add allow lists.

6. Run against a limited bucket.

7. Expand after validation.
```

---

# 81. Allow lists

Allow lists tell Macie that specific matching text should not be treated as sensitive.

Example:

```text
Test credit-card number used in documentation
Approved dummy account number
Known synthetic customer data
```

An allow list should not be used to ignore real production data merely because it is common.

---

# 82. Supported S3 content

Macie supports most common S3 storage classes and a wide variety of structured, semi-structured and document formats, subject to current service limitations.

Objects must be stored in supported S3 general-purpose buckets, storage classes and file formats to be analyzed. ([AWS Documentation][49])

Coverage reporting should identify:

* Objects Macie analyzed.
* Objects skipped.
* Unsupported formats.
* Encryption-access failures.
* Storage-class limitations.
* Oversized or malformed content.

---

# 83. Discovery results repository

Macie can store detailed sensitive-data discovery results in an S3 repository.

Results are produced for objects that:

* Contained sensitive data.
* Did not contain sensitive data.
* Could not be analyzed.

This is different from a finding, which is generated only for detected sensitive data or policy issues. ([AWS Documentation][50])

Protect the results repository because it may reveal:

* Bucket names.
* Object paths.
* Data classifications.
* Detection details.
* Security posture.

---

# 84. Macie finding severity

Macie sensitive-data findings use:

```text
Low
Medium
High
```

Severity depends on the type and number of detected occurrences. When several sensitive-data types exist in one object, the finding takes the highest applicable severity. ([AWS Documentation][51])

Do not equate:

```text
Low severity
=
Safe to ignore
```

A low-volume private key or credential can still be business-critical depending on context.

---

# 85. Macie remediation workflow

```text
Sensitive-data finding
        |
        v
Confirm data type and object
        |
        v
Determine business owner
        |
        v
Assess exposure
        |
        ├── Publicly accessible?
        ├── Cross-account?
        ├── Downloaded?
        └── Credential still active?
        |
        v
Contain access
        |
        v
Rotate credentials if relevant
        |
        v
Move, encrypt, redact or delete data
        |
        v
Fix data-generation process
```

---

# 86. Macie organization deployment

Use a delegated Macie administrator account.

```text
Security account
    |
    ├── Macie member A
    ├── Macie member B
    └── Macie member C
```

Automated discovery in an organization can include S3 bucket inventory from member accounts. ([AWS Documentation][47])

Enable Macie only after reviewing:

* Number of buckets.
* Object volume.
* Discovery scope.
* Sensitive-data job cost.
* Required Regions.
* Delegated administrator design.

---

# 87. Macie cost controls

Primary cost considerations include:

* S3 bucket inventory monitoring.
* Automated discovery.
* Volume of data inspected by jobs.
* Repeated scans.
* Large compressed archives.
* Duplicate datasets.
* Broad identifier sets.

Optimizations:

```text
Use automated discovery for prioritization
Use targeted jobs for high-value buckets
Exclude known irrelevant prefixes
Avoid rescanning unchanged archives unnecessarily
Use S3 Inventory and tags for scope
Review estimated job cost before running
```

---

# Part 5 — Amazon Detective

# 88. What is Amazon Detective?

Amazon Detective helps investigate security findings and suspicious activities by creating a behavior graph from AWS activity.

It applies:

* Graph analysis.
* Statistical analysis.
* Machine learning.
* Behavioral baselines.
* Visual relationships.

Detective helps identify the root cause, affected resources and unusual behavior surrounding security events. ([AWS Documentation][52])

---

# 89. Behavior graph

A behavior graph links entities such as:

```text
AWS accounts
IAM users
IAM roles
Role sessions
EC2 instances
IP addresses
User agents
Security findings
```

with activities such as:

```text
API calls
Login attempts
Network flows
Resource interactions
```

Detective extracts and analyzes CloudTrail management events, VPC Flow Logs and GuardDuty findings to build time-based behavioral views. ([AWS Documentation][53])

---

# 90. Detective investigation example

GuardDuty finding:

```text
IAM credentials used from malicious IP
```

Detective investigation:

```text
Compromised role session
        |
        ├── First seen from new IP
        ├── Enumerated S3 buckets
        ├── Created new access key
        ├── Modified security group
        └── Launched EC2 instance
```

This provides a broader timeline than the original finding.

---

# 91. Investigation starting points

A Detective investigation can start from:

```text
Finding
Finding group
Entity
```

Examples of entities:

* IAM role.
* IAM user.
* EC2 instance.
* AWS account.
* External IP address.

The investigation process includes triage, scope analysis and determination of whether activity is malicious or expected. ([AWS Documentation][54])

---

# 92. Finding groups

Detective finding groups correlate findings and entities that appear related to one potential security event.

```text
GuardDuty credential finding ─┐
Inspector EC2 finding ────────┤
Suspicious IP evidence ───────┼──> Finding group
IAM role behavior ────────────┘
```

Finding groups reduce the risk of investigating each finding in isolation and missing the larger incident. ([AWS Documentation][55])

---

# 93. Finding-group severity

A Detective finding group inherits the highest severity among its associated findings.

Prioritize groups that:

* Contain critical or high findings.
* Affect many entities.
* Include IAM credentials.
* Show lateral movement.
* Span multiple accounts.
* Involve public-facing resources.
* Include malware or persistence.

([AWS Documentation][56])

---

# 94. Generative AI finding summaries

Detective can generate natural-language summaries for finding groups.

These can help:

* Summarize involved resources.
* Explain relationships.
* Identify likely threat behavior.
* Reduce initial analysis time.

AWS warns that generative summaries may not always be fully accurate. Analysts must verify claims against underlying findings, CloudTrail activity and resource evidence. ([AWS Documentation][57])

---

# 95. GuardDuty and Detective integration

When GuardDuty and Detective are enabled, GuardDuty findings are ingested into Detective, and analysts can pivot from GuardDuty to entity profiles in Detective.

Supported investigation pivots can include:

* Account.
* IAM role.
* IAM user or session.
* EC2 instance.
* IP address.
* User agent.

([AWS Documentation][58])

---

# 96. Security Hub findings in Detective

GuardDuty findings are part of Detective’s core investigation data.

Other AWS security findings aggregated through Security Hub CSPM can be enabled as an optional Detective data source, expanding finding-group correlations beyond GuardDuty. ([AWS Documentation][59])

---

# 97. Detective administrator alignment

AWS recommends aligning the Detective administrator with the GuardDuty and Security Hub CSPM delegated administrator where practical.

```text
Central security account:
GuardDuty admin
Security Hub admin
Detective admin
```

This improves access consistency and investigation across member accounts. ([AWS Documentation][60])

---

# 98. Detective is not a SIEM replacement

Detective is optimized for AWS investigation and behavior graphs.

A broader SIEM may also provide:

* On-premises logs.
* Endpoint detection.
* SaaS audit events.
* Identity-provider data.
* Firewall logs.
* Long-term correlation.
* Regulatory retention.

Use Detective as a high-value AWS investigation tool inside the broader incident-response ecosystem.

---

# Part 6 — IAM Access Analyzer

# 99. What is IAM Access Analyzer?

IAM Access Analyzer provides several capabilities:

```text
External access analysis
Internal access analysis
Unused access analysis
IAM policy validation
Custom policy checks
Policy generation
```

It helps identify resources shared outside a zone of trust and assists with least-privilege IAM design. ([AWS Documentation][61])

---

# 100. Zone of trust

An analyzer defines a zone of trust as:

```text
One AWS account
or
One AWS organization
```

Example organization analyzer:

```text
Trusted:
Accounts inside o-example

External:
Public access
Accounts outside o-example
External federated principals
```

Access Analyzer uses automated reasoning technology to evaluate resource policies and determine potential access paths. ([AWS Documentation][62])

---

# 101. External-access analyzer

External analysis identifies supported resources accessible from outside the trusted account or organization.

Examples:

* Public S3 bucket.
* SQS queue accessible by another account.
* SNS topic permitting an external publisher.
* Secrets Manager secret shared externally.
* KMS key allowing outside principals.
* Lambda function callable externally.
* ECR repository shared outside organization.
* Public or shared snapshots.

Access Analyzer evaluates supported resource policies and sharing configuration. ([AWS Documentation][63])

---

# 102. External finding example

```text
Resource:
production-todo-exports S3 bucket

Finding:
Accessible by account 999999999999

Policy:
Principal = external account
Action = s3:GetObject
```

Investigation questions:

```text
Is the account an approved partner?
Is an organization condition present?
Is access limited to one prefix?
Does the external role require an external ID?
Is sensitive data stored there?
When was access last used?
```

---

# 103. Internal-access analyzer

Internal access analysis identifies access paths from IAM users and roles inside the zone of trust to specified critical resources.

Example:

```text
DeveloperRole
    |
    v
Can access production KMS key
```

or:

```text
CI role
    |
    v
Can retrieve production database secret
```

This answers:

```text
Which internal principals can reach this critical resource?
```

rather than only identifying outside access. ([AWS Documentation][64])

---

# 104. Unused-access analyzer

Unused access analysis identifies:

* Roles not used during the configured window.
* Unused IAM-user access keys.
* Unused console passwords.
* Unused services.
* Unused actions.
* Permissions granted but not exercised.

([AWS Documentation][64])

Example:

```text
Role grants:
s3:*
dynamodb:*
kms:*
secretsmanager:*

Observed use:
s3:GetObject only
```

This provides evidence for reducing permissions.

---

# 105. Unused does not always mean unnecessary

A disaster-recovery role may not be used for months.

A break-glass role may have no normal activity.

Before removing access:

```text
1. Identify owner.

2. Understand workload purpose.

3. Check seasonal and DR usage.

4. Review CloudTrail history window.

5. Test narrower policy.

6. Roll out safely.

7. Preserve emergency access where justified.
```

---

# 106. Policy validation

IAM Access Analyzer validates IAM policies for:

* JSON syntax.
* Invalid actions.
* Unsupported resources.
* Missing required elements.
* Overly permissive statements.
* Security warnings.
* Best-practice recommendations.

AWS documents more than 100 policy checks. ([AWS Documentation][65])

CLI:

```bash
aws accessanalyzer validate-policy \
  --policy-type IDENTITY_POLICY \
  --policy-document file://policy.json
```

---

# 107. Policy validation in CI/CD

```text
Pull request
    |
    v
Terraform generates IAM policy
    |
    v
Access Analyzer validation
    |
    ├── Errors → Block
    ├── Security warnings → Review/block
    └── Suggestions → Report
```

Example pipeline:

```bash
FINDINGS=$(
  aws accessanalyzer validate-policy \
    --policy-type IDENTITY_POLICY \
    --policy-document file://policy.json \
    --query 'findings[?findingType==`ERROR` || findingType==`SECURITY_WARNING`]'
)

if [ "$FINDINGS" != "[]" ]; then
  echo "IAM policy failed validation"
  echo "$FINDINGS"
  exit 1
fi
```

---

# 108. Custom policy checks

Custom policy checks can detect whether a proposed policy:

* Grants new access compared with an existing policy.
* Allows specific critical actions.
* Violates organizational permission standards.

Example:

```text
Fail deployment if new policy permits:
iam:CreateAccessKey
iam:PassRole
kms:ScheduleKeyDeletion
organizations:LeaveOrganization
cloudtrail:StopLogging
```

Custom checks allow CI/CD to test policies against organization-specific security requirements. Charges apply per custom check. ([AWS Documentation][66])

---

# 109. Policy generation

Access Analyzer can analyze CloudTrail activity for a role or user and generate a policy based on observed service and action usage.

```text
Broad existing role
        |
        v
CloudTrail activity analysis
        |
        v
Generated narrower policy
```

This is a starting point—not a final policy—because CloudTrail history may not include rare disaster-recovery or seasonal operations. ([AWS Documentation][67])

---

# 110. Archive rules

Archive rules automatically archive findings that match approved access patterns.

Example:

```text
External account:
Approved backup account

Resource prefix:
central-backups-*

Action:
Archive finding automatically
```

Archive rules can be applied to new and, when chosen, existing findings. They should represent documented approved sharing—not a method for hiding unresolved exposure. ([AWS Documentation][68])

---

# 111. Access Analyzer response workflow

```text
Access finding
      |
      v
Is access required?
      |
   ┌──┴───┐
   v      v
  No     Yes
   |      |
   v      v
Remove   Restrict principal,
access   action, resource,
         conditions and duration
            |
            v
      Document/archive rule
```

---

# Part 7 — Complete Security Operations Pipeline

# 112. Central finding pipeline

```text
GuardDuty ─────────────┐
Inspector ─────────────┤
Macie ─────────────────┤
Access Analyzer ───────┤
Security Hub CSPM ─────┼──> Security Hub
Third-party findings ──┘         |
                                  v
                             EventBridge
                                  |
                ┌─────────────────┼────────────────┐
                v                 v                v
             Critical          Medium          Informational
                |                 |                |
                v                 v                v
          Incident page       Ticket queue     Dashboard/archive
                |
                v
          Step Functions
                |
                ├── Enrich
                ├── Contain
                ├── Preserve evidence
                ├── Notify
                └── Update finding
```

---

# 113. Finding enrichment

Before paging, enrich a finding with:

* Account name.
* OU.
* Environment.
* Resource tags.
* Application owner.
* Business criticality.
* Internet exposure.
* Data classification.
* On-call team.
* Recent deployment.
* Related CloudTrail activity.
* Existing ticket.
* Exception status.

Raw finding:

```text
EC2 instance i-123 compromised
```

Enriched incident:

```text
Production TodoApp API instance
Publicly reachable
Handles customer data
Owned by Platform Team
Deployment occurred 20 minutes ago
No approved exception
```

---

# 114. Safe automated response levels

## Level 1 — Notify

```text
Create ticket
Send alert
Add context
```

Low risk.

## Level 2 — Restrict

```text
Remove public bucket policy
Block malicious IP
Disable exposed access key
```

Moderate risk.

## Level 3 — Isolate

```text
Replace security group
Stop ECS service
Quarantine EC2 instance
Revoke active sessions
```

High operational risk.

## Level 4 — Destructive

```text
Terminate instance
Delete object
Delete credentials
Destroy resource
```

Requires strong approval and evidence in most environments.

---

# 115. Automated containment guardrails

Every automatic response should have:

```text
Exact finding criteria
Account and environment scope
Resource tags
Maximum actions per interval
Idempotency
Dry-run mode
Audit log
Rollback procedure
Approval for destructive actions
Failure destination
Security-team ownership
```

Bad:

```text
Any GuardDuty finding
    → Terminate affected instance
```

Better:

```text
Critical crypto-mining finding
AND sandbox account
AND instance tagged AutoContain=true
    → Replace security group with quarantine group
```

---

# 116. Compromised IAM credential response

```text
GuardDuty credential finding
        |
        v
Identify access key/session
        |
        v
Is it long-lived access key?
        |
   ┌────┴────┐
   v         v
 Yes         No
  |          |
  v          v
Disable key  Revoke sessions/
             update role policy
        |
        v
Inspect CloudTrail timeline
        |
        v
Identify persistence and modified resources
        |
        v
Rotate dependent credentials
```

Do not immediately delete the IAM principal before preserving evidence and understanding what was changed.

---

# 117. Compromised EC2 response

```text
1. Do not SSH interactively unless the forensic plan permits it.

2. Record instance metadata and tags.

3. Isolate network access.

4. Preserve EBS snapshots.

5. Capture relevant logs and memory if required.

6. Review IAM role activity.

7. Find lateral movement.

8. Replace—not manually clean—the instance.

9. Fix the image or deployment source.

10. Monitor for recurrence.
```

---

# 118. Malicious S3 upload response

```text
1. Block downstream processing.

2. Preserve object metadata and hash.

3. Restrict access.

4. Tag/quarantine the object.

5. Identify uploader identity.

6. Review related uploads.

7. Scan associated archives.

8. Notify security/data owner.

9. Update upload-validation controls.

10. Delete only after evidence requirements are met.
```

---

# 119. Inspector vulnerability response SLA

Example policy:

| Finding                      | Exposure                   |     Remediation SLA |
| ---------------------------- | -------------------------- | ------------------: |
| Critical with active exploit | Internet-facing production |            24 hours |
| Critical                     | Internal production        |              3 days |
| High with exploit            | Production                 |              7 days |
| High                         | Development                |             14 days |
| Medium                       | Production                 |             30 days |
| Low                          | Any                        | Planned maintenance |

The exact SLA is an organizational risk decision, not an AWS default.

---

# 120. Sensitive-data response SLA

Example:

```text
Active AWS credential in public S3:
Immediate incident

Private key in restricted internal bucket:
Critical investigation

Customer PII in approved encrypted data lake:
Potentially expected

Customer PII in debug export:
High-priority remediation

Synthetic test data:
Document and suppress if verified
```

Classification must consider both data type and exposure.

---

# Part 8 — Terraform Implementation

# 121. Terraform GuardDuty detector

```hcl
resource "aws_guardduty_detector" "security" {
  enable = true

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    ManagedBy   = "Terraform"
    Environment = "organization"
    Purpose     = "threat-detection"
  }
}
```

The current AWS provider recommends separate detector-feature resources for newer GuardDuty features rather than the deprecated inline `datasources` block. ([Terraform Registry][69])

---

# 122. GuardDuty organization administrator

From the Organizations management account:

```hcl
resource "aws_guardduty_organization_admin_account" "security" {
  admin_account_id = var.security_account_id
}
```

This must be deployed for each Region where the security account will centrally administer GuardDuty.

---

# 123. GuardDuty organization configuration

From the delegated security-administrator account:

```hcl
resource "aws_guardduty_organization_configuration" "security" {
  detector_id = aws_guardduty_detector.security.id

  auto_enable_organization_members = "ALL"
}
```

GuardDuty organization configuration requires the account to already be designated as the delegated administrator in that Region. ([Terraform Registry][70])

---

# 124. GuardDuty feature configuration

The current provider exposes organization feature configuration separately.

Conceptual example:

```hcl
resource "aws_guardduty_organization_configuration_feature" "s3" {
  detector_id = aws_guardduty_detector.security.id

  name        = "S3_DATA_EVENTS"
  auto_enable = "ALL"
}

resource "aws_guardduty_organization_configuration_feature" "runtime" {
  detector_id = aws_guardduty_detector.security.id

  name        = "RUNTIME_MONITORING"
  auto_enable = "ALL"
}
```

Feature names and additional configuration blocks should be validated against the pinned AWS provider version. The provider added a dedicated organization-feature resource for protection-plan configuration. ([Terraform Registry][71])

---

# 125. Malware Protection for S3

```hcl
resource "aws_guardduty_malware_protection_plan" "uploads" {
  role = aws_iam_role.guardduty_malware.arn

  protected_resource {
    s3_bucket {
      bucket_name = aws_s3_bucket.quarantine.id

      object_prefixes = [
        "uploads/"
      ]
    }
  }

  actions {
    tagging {
      status = "ENABLED"
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

The provider supports a GuardDuty malware-protection plan with protected S3 bucket prefixes and optional result tagging. ([Terraform Registry][72])

---

# 126. Security Hub account and finding aggregation

```hcl
resource "aws_securityhub_account" "security" {
  enable_default_standards = false
}

resource "aws_securityhub_finding_aggregator" "home" {
  linking_mode = "ALL_REGIONS"

  depends_on = [
    aws_securityhub_account.security
  ]
}
```

A finding aggregator makes the current Region the Security Hub CSPM home Region for linked-region aggregation. ([Terraform Registry][73])

---

# 127. Security Hub central configuration

```hcl
resource "aws_securityhub_organization_admin_account" "security" {
  admin_account_id = var.security_account_id
}

resource "aws_securityhub_organization_configuration" "security" {
  auto_enable           = false
  auto_enable_standards = "NONE"

  organization_configuration {
    configuration_type = "CENTRAL"
  }

  depends_on = [
    aws_securityhub_finding_aggregator.home,
    aws_securityhub_organization_admin_account.security
  ]
}
```

Central configuration requires a delegated administrator and a Security Hub finding aggregator. The delegated administrator must be an organization member account rather than the Organizations management account for central mode. ([Terraform Registry][74])

---

# 128. Security Hub configuration policy

```hcl
resource "aws_securityhub_configuration_policy" "production" {
  name        = "production-security-baseline"
  description = "Security Hub baseline for production accounts"

  configuration_policy {
    service_enabled = true

    enabled_standard_arns = [
      var.aws_foundational_security_standard_arn,
      var.cis_standard_arn
    ]

    security_controls_configuration {
      disabled_control_identifiers = []

      enabled_control_identifiers = []
    }
  }
}
```

Configuration policies centrally define Security Hub service, standard and control settings and require central organization configuration. ([Terraform Registry][75])

Association:

```hcl
resource "aws_securityhub_configuration_policy_association" "production_ou" {
  target_id = var.production_ou_id

  policy_id = (
    aws_securityhub_configuration_policy.production.id
  )
}
```

---

# 129. Inspector organization configuration

```hcl
resource "aws_inspector2_delegated_admin_account" "security" {
  account_id = var.security_account_id
}

resource "aws_inspector2_enabler" "security" {
  account_ids = [
    data.aws_caller_identity.current.account_id
  ]

  resource_types = [
    "EC2",
    "ECR",
    "LAMBDA",
    "LAMBDA_CODE"
  ]
}

resource "aws_inspector2_organization_configuration" "security" {
  auto_enable {
    ec2         = true
    ecr         = true
    lambda      = true
    lambda_code = true
  }
}
```

The Inspector organization configuration manages automatic enablement for EC2, ECR, Lambda standard and Lambda code scanning. ([Terraform Registry][43])

---

# 130. Macie account

```hcl
resource "aws_macie2_account" "security" {
  status = "ENABLED"

  finding_publishing_frequency = "FIFTEEN_MINUTES"
}
```

The provider manages Macie account status and policy-finding publication frequency. ([Terraform Registry][76])

Organization administrator:

```hcl
resource "aws_macie2_organization_admin_account" "security" {
  admin_account_id = var.security_account_id

  depends_on = [
    aws_macie2_account.security
  ]
}
```

---

# 131. Detective graph

```hcl
resource "aws_detective_graph" "security" {
  tags = {
    ManagedBy = "Terraform"
    Purpose   = "security-investigation"
  }
}
```

An AWS account can own one Detective behavior graph per Region. ([Terraform Registry][77])

Organization administrator:

```hcl
resource "aws_detective_organization_admin_account" "security" {
  account_id = var.security_account_id
}
```

---

# 132. Access Analyzer organization analyzer

```hcl
resource "aws_accessanalyzer_analyzer" "external" {
  analyzer_name = "organization-external-access"

  type = "ORGANIZATION"

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "external-access-analysis"
  }
}
```

Internal and unused-access analyzers use different analyzer types and configuration. Validate the supported analyzer type and resource filters against the pinned provider release. The current provider supports account and organization analyzers, including internal-access configurations. ([Terraform Registry][78])

---

# 133. Critical GuardDuty EventBridge rule

```hcl
resource "aws_cloudwatch_event_rule" "guardduty_critical" {
  name = "security-guardduty-critical"

  event_pattern = jsonencode({
    source = [
      "aws.guardduty"
    ]

    detail-type = [
      "GuardDuty Finding"
    ]

    detail = {
      severity = [
        {
          numeric = [
            ">=",
            9
          ]
        }
      ]
    }
  })

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "security-response"
  }
}
```

---

# 134. EventBridge target

```hcl
resource "aws_cloudwatch_event_target" "guardduty_response" {
  rule = aws_cloudwatch_event_rule.guardduty_critical.name

  target_id = "SecurityResponseWorkflow"

  arn      = aws_sfn_state_machine.security_response.arn
  role_arn = aws_iam_role.eventbridge_security_response.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 10
  }

  dead_letter_config {
    arn = aws_sqs_queue.security_automation_dlq.arn
  }
}
```

Always configure a DLQ for critical security automation so failed response events are not silently lost.

---

# 135. Quarantine security group

```hcl
resource "aws_security_group" "quarantine" {
  name        = "security-quarantine"
  description = "Isolation group for compromised EC2 resources"

  vpc_id = aws_vpc.production.id

  egress = []

  tags = {
    Name      = "security-quarantine"
    ManagedBy = "Terraform"
  }
}
```

Applying it should require strict automation conditions and tested rollback. Forensic collection may require limited controlled connectivity to security tools rather than absolute isolation.

---

# Part 9 — Hands-on Security Lab

# 136. Lab goal

Create a safe security-monitoring lab:

```text
Enable GuardDuty
Generate sample findings
Route high-severity findings to SNS
Enable Access Analyzer
Validate an IAM policy
Review findings
Cleanup automation resources
```

Region:

```text
ap-south-1
```

Estimated focused time:

```text
45–60 minutes
```

GuardDuty and other security services can incur charges after trial periods, so review enabled protection plans and disable lab-only resources after testing.

---

# 137. Check GuardDuty detector

```bash
aws guardduty list-detectors \
  --region ap-south-1
```

If no detector exists:

```bash
DETECTOR_ID=$(
  aws guardduty create-detector \
    --enable \
    --finding-publishing-frequency FIFTEEN_MINUTES \
    --region ap-south-1 \
    --query DetectorId \
    --output text
)

echo "$DETECTOR_ID"
```

If one exists:

```bash
DETECTOR_ID=$(
  aws guardduty list-detectors \
    --region ap-south-1 \
    --query 'DetectorIds[0]' \
    --output text
)
```

---

# 138. Generate sample GuardDuty findings

```bash
aws guardduty create-sample-findings \
  --detector-id "$DETECTOR_ID" \
  --region ap-south-1
```

GuardDuty supports sample findings for testing dashboards and event-processing pipelines without creating real malicious activity. ([AWS Documentation][79])

List findings:

```bash
FINDING_IDS=$(
  aws guardduty list-findings \
    --detector-id "$DETECTOR_ID" \
    --region ap-south-1 \
    --query 'FindingIds' \
    --output json
)

echo "$FINDING_IDS"
```

---

# 139. Retrieve finding details

```bash
aws guardduty get-findings \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$(
    echo "$FINDING_IDS" |
    jq -r '.[]' |
    head -n 10
  )" \
  --region ap-south-1
```

Review:

```text
type
severity
resource
service.action
firstSeen
lastSeen
count
```

---

# 140. Create SNS topic

```bash
TOPIC_ARN=$(
  aws sns create-topic \
    --name security-lab-findings \
    --region ap-south-1 \
    --query TopicArn \
    --output text
)

echo "$TOPIC_ARN"
```

Add an approved email subscription only in a controlled lab:

```bash
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "your-approved-email@example.com" \
  --region ap-south-1
```

The email subscription must be confirmed.

---

# 141. Create EventBridge rule

```bash
aws events put-rule \
  --name security-lab-guardduty-high \
  --event-pattern '{
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"],
    "detail": {
      "severity": [{
        "numeric": [">=", 7]
      }]
    }
  }' \
  --state ENABLED \
  --region ap-south-1
```

Allow EventBridge to publish:

```bash
aws sns set-topic-attributes \
  --topic-arn "$TOPIC_ARN" \
  --attribute-name Policy \
  --attribute-value "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"Service\": \"events.amazonaws.com\"
      },
      \"Action\": \"sns:Publish\",
      \"Resource\": \"$TOPIC_ARN\"
    }]
  }" \
  --region ap-south-1
```

Add target:

```bash
aws events put-targets \
  --rule security-lab-guardduty-high \
  --targets "Id"="SecurityLabSns","Arn"="$TOPIC_ARN" \
  --region ap-south-1
```

---

# 142. Create Access Analyzer

```bash
ANALYZER_NAME="security-lab-external-access"

aws accessanalyzer create-analyzer \
  --analyzer-name "$ANALYZER_NAME" \
  --type ACCOUNT \
  --region ap-south-1
```

Check:

```bash
aws accessanalyzer list-analyzers \
  --region ap-south-1
```

---

# 143. Validate an unsafe IAM policy

Create:

```bash
cat > /tmp/unsafe-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*"
  }]
}
EOF
```

Validate:

```bash
aws accessanalyzer validate-policy \
  --policy-type IDENTITY_POLICY \
  --policy-document file:///tmp/unsafe-policy.json \
  --region ap-south-1
```

Review:

```text
findingType
issueCode
findingDetails
locations
learnMoreLink
```

Remove:

```bash
rm -f /tmp/unsafe-policy.json
```

---

# 144. Lab cleanup

Remove target:

```bash
aws events remove-targets \
  --rule security-lab-guardduty-high \
  --ids SecurityLabSns \
  --region ap-south-1
```

Delete rule:

```bash
aws events delete-rule \
  --name security-lab-guardduty-high \
  --region ap-south-1
```

Delete SNS topic:

```bash
aws sns delete-topic \
  --topic-arn "$TOPIC_ARN" \
  --region ap-south-1
```

Delete Access Analyzer:

```bash
aws accessanalyzer delete-analyzer \
  --analyzer-name "$ANALYZER_NAME" \
  --region ap-south-1
```

Do not disable an organization’s existing production GuardDuty detector merely to clean up the lab.

---

# Part 10 — Troubleshooting

# 145. GuardDuty has no findings

Possible reasons:

* No suspicious activity occurred.
* Wrong Region.
* Detector disabled.
* Protection plan disabled.
* Member account not associated.
* Organization auto-enable not applied.
* Workload unsupported.
* Telemetry unavailable.
* Suppression rule hides findings.
* Finding was archived.

“No findings” does not prove secure operation.

Check:

```bash
aws guardduty get-detector \
  --detector-id "$DETECTOR_ID" \
  --region ap-south-1
```

---

# 146. New organization accounts are not protected

Check:

* Correct delegated administrator.
* Correct Region.
* Auto-enable mode.
* Optional protection-plan auto-enable.
* Account joined before `NEW` mode was configured.
* Opt-in Region status.
* Member-account limit.
* Account association state.

GuardDuty’s `NEW` mode has ordering considerations in opt-in Regions: the account should opt into the Region before it becomes a new organization member for automatic enablement to apply as expected. ([AWS Documentation][1])

---

# 147. GuardDuty finding is missing from Security Hub

Check:

* Security Hub enabled in same account and Region.
* GuardDuty integration enabled.
* Finding suppressed in GuardDuty.
* Finding archived.
* Region linked to the Security Hub home Region.
* Correct finding filter.
* Workflow status.
* Integration acceptance.
* Finding publication timing.

Suppressed GuardDuty findings are not forwarded to Security Hub CSPM. ([AWS Documentation][17])

---

# 148. Security Hub score is unexpectedly low

Check:

* AWS Config enabled.
* Config recorder covers required resources.
* Newly enabled standards.
* Newly enabled controls.
* Failed controls across member accounts.
* Disabled resources still recorded.
* Controls with unavailable data.
* Region aggregation.
* Recently added accounts.
* Control parameter configuration.

Do not disable a control solely to increase the score.

---

# 149. Security Hub control has no data

Possible causes:

* AWS Config disabled.
* Resource type not recorded.
* Control not supported in Region.
* Service-linked role issue.
* Recently enabled standard.
* Evaluation has not run yet.
* No applicable resources.
* Central configuration not associated.

Many posture controls rely on AWS Config, so confirm the Config recorder before debugging Security Hub itself. ([AWS Documentation][20])

---

# 150. Inspector EC2 instance is not scanned

Check:

* Inspector enabled in Region.
* Supported operating system.
* SSM Agent status.
* Instance IAM role.
* Systems Manager connectivity.
* Inventory association.
* EBS eligibility for agentless scanning.
* KMS permissions for encrypted volumes.
* Instance state.
* Inspector coverage status.
* Deep-inspection errors.

---

# 151. ECR image has no Inspector finding

Check:

* Enhanced scanning enabled.
* Repository uses private ECR.
* Image was pushed after configuration.
* Scan-duration/rescan configuration.
* Supported package format.
* Image is not expired by scan settings.
* Correct Region.
* Inspector is the preferred registry scanner.
* Image digest rather than tag.

---

# 152. Vulnerability remains after patch

Check:

* New package actually installed.
* Container was rebuilt.
* Image digest changed.
* Lambda function was redeployed.
* Old layer still attached.
* EC2 package inventory refreshed.
* Running workload still uses old image.
* Fixed version is the correct vendor version.
* Finding update has propagated.

Updating source code alone does not remediate a deployed runtime.

---

# 153. Inspector suppression hides too much

Check rule criteria:

* Severity too broad.
* Repository pattern too broad.
* Package name omitted.
* Account or Region omitted.
* Resource tag too broad.
* Expiry not documented.

Inspector suppression does not remediate findings; deleting the rule returns matching active findings to normal visibility. ([AWS Documentation][37])

---

# 154. Macie did not inspect an object

Check:

* Supported S3 bucket type.
* Supported storage class.
* Supported file format.
* KMS key permission.
* Object size and structure.
* Compressed archive limitations.
* Job inclusion/exclusion criteria.
* Prefix filter.
* Object changed after inventory.
* Macie service role.
* Cross-account encryption key.

Review the discovery result, not only the findings list, because failed or clean analyses do not necessarily create findings. ([AWS Documentation][50])

---

# 155. Macie generated too many false positives

Actions:

* Review matched text and context.
* Use recommended managed identifiers.
* Narrow custom regular expressions.
* Add keywords.
* Add proximity rules.
* Create narrowly defined allow lists.
* Separate synthetic test data.
* Re-run against sample objects.
* Avoid suppressing complete finding categories.

The default automated-discovery configuration uses a recommended managed-identifier set intended to balance broad detection with reduced noise. ([AWS Documentation][80])

---

# 156. Detective does not show an entity

Check:

* Correct Region.
* Account is a behavior-graph member.
* Entity is supported.
* Finding has been ingested.
* GuardDuty finding export timing.
* AWS security findings data source enabled.
* Search identifier correct.
* Entity exists within graph time scope.

Detective only contains data for enabled members in its behavior graph. ([AWS Documentation][81])

---

# 157. Detective data appears delayed

GuardDuty updates to existing findings are exported according to GuardDuty’s configured publication frequency. AWS recommends reducing the frequency to 15 minutes when using Detective and needing current updates. ([AWS Documentation][58])

Check:

```text
GuardDuty finding export frequency
Security Hub ingestion
Detective member status
Region
Data-source package status
```

---

# 158. Access Analyzer finding looks incorrect

Remember what the finding means:

```text
Policy permits a potential access path
```

It does not necessarily mean:

```text
The external principal has already accessed the resource
```

Access Analyzer evaluates resource policies and trust relationships but may not know every control inside the external account. ([AWS Documentation][62])

Verify:

* Resource policy.
* Organization conditions.
* Principal ARN.
* SCPs.
* Permission boundaries.
* KMS policy.
* Actual CloudTrail usage.

---

# 159. Access Analyzer did not report an external principal

Check:

* Analyzer type.
* Analyzer Region.
* Resource type supported.
* Resource-based policy supported.
* Zone of trust.
* Policy-change processing delay.
* Finding archived by a rule.
* Resource created in another Region.
* Sharing performed by an unsupported mechanism.

It can take time after policy changes for new or updated findings to appear. ([AWS Documentation][82])

---

# 160. Automated remediation caused outage

Response:

```text
1. Stop automation rule.

2. Roll back resource change.

3. Preserve EventBridge and Step Functions history.

4. Identify overbroad finding match.

5. Review tags/account scope.

6. Add approval or dry-run stage.

7. Add maximum-action safety limit.

8. Test in sandbox.

9. Re-enable gradually.
```

Security automation must be treated like production application code.

---

# 161. Production readiness checklist

```text
[ ] Dedicated security account exists
[ ] Delegated administrators are aligned where practical
[ ] Security services are enabled in all approved Regions
[ ] New organization accounts are automatically enrolled
[ ] GuardDuty detector coverage is monitored
[ ] Optional GuardDuty protection plans are documented
[ ] Runtime Monitoring is enabled for supported workloads
[ ] S3 Protection is enabled where required
[ ] Malware Protection for EC2 is configured
[ ] Untrusted S3 upload buckets use malware scanning
[ ] Extended Threat Detection findings are prioritized
[ ] GuardDuty Investigation preview is not the sole evidence source
[ ] Suppression rules have owners and expiry dates
[ ] Critical GuardDuty findings reach EventBridge
[ ] Security Hub has a designated home Region
[ ] Cross-Region aggregation is enabled
[ ] Central configuration policies cover all OUs
[ ] AWS Config supports required CSPM controls
[ ] Security standards are intentionally selected
[ ] Disabled controls have documented justification
[ ] Finding workflow statuses are managed
[ ] Security Hub automation rules are reviewed
[ ] Findings are archived for required retention
[ ] Inspector scans EC2, ECR and Lambda
[ ] Inspector coverage failures are alarmed
[ ] ECR images are tracked by digest
[ ] Critical vulnerability SLAs exist
[ ] CI/CD includes SBOM/vulnerability scanning
[ ] Unsupported operating systems are migrated
[ ] Inspector suppression rules expire
[ ] Macie administrator is centralized
[ ] Automated sensitive-data discovery is configured
[ ] High-value buckets have targeted discovery jobs
[ ] Custom data identifiers are tested
[ ] Macie discovery results repository is encrypted
[ ] Credential findings trigger immediate rotation
[ ] Detective behavior graph includes required accounts
[ ] Security Hub findings data source is enabled in Detective
[ ] Finding groups are used for investigation
[ ] Generative summaries are verified against evidence
[ ] External-access organization analyzer exists
[ ] Internal-access analysis covers critical resources
[ ] Unused-access analysis supports least privilege
[ ] IAM policies are validated in CI/CD
[ ] Custom policy checks protect critical actions
[ ] Archive rules reflect approved access only
[ ] Security finding enrichment includes resource ownership
[ ] Automated response uses least-privilege roles
[ ] Destructive response requires approval
[ ] Automation has DLQs and rollback procedures
[ ] Security incident drills are performed
[ ] Service cost and coverage are reviewed monthly
```

---

# 162. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
GuardDuty:
Threat detection

Security Hub:
Central security findings

Inspector:
Vulnerability scanning

Macie:
Sensitive-data discovery

Detective:
Security investigation

IAM Access Analyzer:
Access-policy analysis
```

## Solutions Architect Associate

Understand:

```text
GuardDuty data sources
Security Hub standards
Inspector EC2/ECR/Lambda scanning
Macie S3 classification
Detective behavior graphs
Access Analyzer external findings
EventBridge security automation
```

## DevOps Engineer Professional

Understand:

```text
Organization delegated administrators
Regional security-service configuration
GuardDuty protection plans
Extended Threat Detection
Runtime Monitoring
Security Hub central configuration
Finding automation
Inspector CI/CD integration
SBOM generation
Macie automated discovery
Detective finding groups
Unused-access analysis
Custom IAM policy checks
Controlled automated remediation
```

---

# 163. Interview questions

## Question 1: What is Amazon GuardDuty?

**Answer:**

GuardDuty is a managed threat-detection service that analyzes AWS activity, network telemetry, DNS activity and optional workload data to identify suspicious or malicious behavior.

## Question 2: Does GuardDuty automatically block an attack?

**Answer:**

No. GuardDuty generates findings. EventBridge, Lambda, Step Functions, SSM Automation or human incident-response processes perform containment and remediation.

## Question 3: What are GuardDuty foundational data sources?

**Answer:**

They include CloudTrail management events, VPC Flow Logs and Route 53 Resolver DNS query logs.

## Question 4: What is Extended Threat Detection?

**Answer:**

It correlates signals across data sources, resources and time to detect multi-stage attacks and create attack-sequence findings.

## Question 5: What is GuardDuty Runtime Monitoring?

**Answer:**

It analyzes operating-system-level behavior from supported EC2, ECS, EKS and Fargate workloads to detect suspicious process and runtime activity.

## Question 6: What is Security Hub?

**Answer:**

Security Hub centralizes security findings and provides posture-management capabilities, standards, controls, workflow management and security automation.

## Question 7: What is Security Hub CSPM?

**Answer:**

It is Security Hub’s cloud-security-posture-management capability, which evaluates AWS resources against security standards and controls.

## Question 8: Why does Security Hub use AWS Config?

**Answer:**

Many Security Hub CSPM controls depend on AWS Config resource configuration and compliance evaluations.

## Question 9: What is a Security Hub workflow status?

**Answer:**

It represents the operational state of a finding, such as `NEW`, `NOTIFIED`, `RESOLVED` or `SUPPRESSED`.

## Question 10: What does Amazon Inspector scan?

**Answer:**

Inspector scans supported EC2 instances, private ECR images, Lambda functions and layers, and configured code repositories.

## Question 11: What is an Inspector score?

**Answer:**

It adjusts vulnerability severity using AWS environment context such as network reachability and exploitability information.

## Question 12: What is an SBOM?

**Answer:**

A software bill of materials is a structured list of the components, libraries and packages contained in a software artifact.

## Question 13: What is Amazon Macie?

**Answer:**

Macie is a data-security service that discovers sensitive data and identifies S3 data-security risks.

## Question 14: What is the difference between automated Macie discovery and a discovery job?

**Answer:**

Automated discovery continually samples the S3 estate for broad visibility. A discovery job analyzes a specifically configured dataset and identifier scope.

## Question 15: What is Amazon Detective?

**Answer:**

Detective builds a behavior graph from AWS activity and security findings to help analysts understand relationships, timelines and root causes.

## Question 16: What is a Detective finding group?

**Answer:**

It is a correlated collection of findings and entities that appear related to the same potential security incident.

## Question 17: What is IAM Access Analyzer?

**Answer:**

It analyzes resource and IAM policies to identify external access, internal access, unused permissions and policy issues.

## Question 18: What is an external-access analyzer?

**Answer:**

It identifies supported resources accessible by principals outside the analyzer’s trusted account or organization.

## Question 19: What are IAM Access Analyzer custom policy checks?

**Answer:**

They test whether a proposed policy grants new access or permits organization-defined critical actions before deployment.

## Question 20: How should critical security findings be automated safely?

**Answer:**

Use narrowly scoped EventBridge rules, enrichment, idempotent workflows, resource tags, maximum-action limits, audit logs, rollback procedures and approval for destructive actions.

---

# 164. Never-forget revision

```text
GuardDuty:
Detects suspicious activity.

Protection plan:
Adds workload-specific telemetry.

Attack sequence:
Correlated multi-stage threat.

Runtime Monitoring:
Observes process and workload behavior.

Security Hub:
Central security finding platform.

Security Hub CSPM:
Configuration posture and controls.

Security standard:
Collection of security requirements.

Inspector:
Finds workload vulnerabilities.

Inspector score:
Vulnerability severity plus AWS context.

SBOM:
Inventory of software components.

Macie:
Discovers sensitive S3 data.

Managed identifier:
AWS-provided sensitive-data detector.

Custom identifier:
Organization-defined detection pattern.

Detective:
Investigates behavior relationships.

Behavior graph:
Connected entities and activity.

Finding group:
Correlated potential incident.

Access Analyzer:
Analyzes access and policies.

External access:
Access from outside the trusted zone.

Internal access:
Access from principals inside the trusted zone.

Unused access:
Permissions or credentials not recently used.

Suppression:
Hides known findings; does not remediate them.
```

## One-line memory trick

```text
GuardDuty finds the attacker.
Inspector finds vulnerable software.
Macie finds sensitive data.
Access Analyzer finds excessive access.
Security Hub brings findings together.
Detective explains the incident.
EventBridge starts the response.
```

## Lesson 57 outcome

You can now design security where:

```text
Credentials behave abnormally
    → GuardDuty generates a threat finding.

Several suspicious actions form one attack
    → Extended Threat Detection creates an attack sequence.

A container executes malicious processes
    → Runtime Monitoring detects workload behavior.

A production image contains an exploitable CVE
    → Inspector identifies and prioritizes it.

A secret key is stored in S3
    → Macie discovers the credential.

A resource is shared with an outside account
    → Access Analyzer reports the access path.

Several findings involve one IAM role
    → Detective correlates them into a finding group.

Findings exist across accounts and Regions
    → Security Hub centralizes them.

A critical finding arrives
    → EventBridge starts a controlled response workflow.

A remediation could disrupt production
    → Approval and containment guardrails prevent unsafe automation.
```

**Next lesson: Lesson 58 — AWS Organizations, Control Tower, Service Control Policies, account vending and multi-account landing-zone architecture: organizational units, delegated administrators, preventive controls, detective controls, centralized networking, identity, logging and governance.**

[1]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html?utm_source=chatgpt.com "Managing GuardDuty accounts with AWS Organizations"
[2]: https://docs.aws.amazon.com/security-ir/latest/userguide/what-is.html?utm_source=chatgpt.com "AWS Security Incident Response User Guide"
[3]: https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html?utm_source=chatgpt.com "What is Amazon GuardDuty? - Amazon ..."
[4]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_settingup.html?utm_source=chatgpt.com "Getting started with GuardDuty - AWS Documentation"
[5]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-active.html?utm_source=chatgpt.com "GuardDuty finding types"
[6]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings-severity.html?utm_source=chatgpt.com "Severity levels of GuardDuty findings - Amazon GuardDuty"
[7]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-extended-threat-detection.html?utm_source=chatgpt.com "GuardDuty Extended Threat Detection - AWS Documentation"
[8]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-attack-sequence-finding-types.html?utm_source=chatgpt.com "GuardDuty attack sequence finding types"
[9]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-investigation.html?utm_source=chatgpt.com "GuardDuty Investigation (Preview) - AWS Documentation"
[10]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-s3.html?utm_source=chatgpt.com "GuardDuty S3 Protection finding types"
[11]: https://docs.aws.amazon.com/guardduty/latest/ug/gdu-malware-protection-s3.html?utm_source=chatgpt.com "GuardDuty Malware Protection for S3"
[12]: https://docs.aws.amazon.com/guardduty/latest/ug/findings-malware-protection.html?utm_source=chatgpt.com "Malware Protection for EC2 finding types"
[13]: https://docs.aws.amazon.com/guardduty/latest/ug/findings-runtime-monitoring.html?utm_source=chatgpt.com "GuardDuty Runtime Monitoring finding types"
[14]: https://docs.aws.amazon.com/guardduty/latest/ug/troubleshooting-rds-protection-guardduty.html?utm_source=chatgpt.com "Troubleshooting RDS Protection monitoring issues"
[15]: https://docs.aws.amazon.com/guardduty/latest/ug/set-guardduty-auto-enable-preferences.html?utm_source=chatgpt.com "Setting organization auto-enable preferences"
[16]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings_eventbridge.html?utm_source=chatgpt.com "Processing GuardDuty findings with Amazon EventBridge"
[17]: https://docs.aws.amazon.com/guardduty/latest/ug/findings_suppression-rule.html?utm_source=chatgpt.com "Suppression rules in GuardDuty - Amazon GuardDuty"
[18]: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_remediate.html?utm_source=chatgpt.com "Remediating detected GuardDuty security findings - Amazon GuardDuty"
[19]: https://docs.aws.amazon.com/securityhub/latest/userguide/what-is-securityhub-v2.html?utm_source=chatgpt.com "Introduction to AWS Security Hub"
[20]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-settingup.html?utm_source=chatgpt.com "Enabling Security Hub CSPM - AWS Documentation"
[21]: https://docs.aws.amazon.com/securityhub/latest/userguide/standards-reference.html?utm_source=chatgpt.com "Standards reference for Security Hub CSPM"
[22]: https://docs.aws.amazon.com/securityhub/latest/userguide/findings-workflow-status.html?utm_source=chatgpt.com "Setting the workflow status of findings in Security Hub CSPM - AWS Security Hub"
[23]: https://docs.aws.amazon.com/securityhub/latest/userguide/central-configuration-intro.html?utm_source=chatgpt.com "Understanding central configuration in Security Hub CSPM"
[24]: https://docs.aws.amazon.com/securityhub/latest/userguide/finding-aggregation.html?utm_source=chatgpt.com "Understanding cross-Region aggregation in Security Hub CSPM"
[25]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-v2-automation-rules.html?utm_source=chatgpt.com "Automation rules in Security Hub - AWS Documentation"
[26]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-cloudwatch-events.html?utm_source=chatgpt.com "Using EventBridge for automated response and remediation"
[27]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-cwe-integration-types.html?utm_source=chatgpt.com "Security Hub CSPM event types in EventBridge"
[28]: https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-findings.html?utm_source=chatgpt.com "Creating and updating findings in Security Hub CSPM"
[29]: https://docs.aws.amazon.com/inspector/latest/user/what-is-inspector.html?utm_source=chatgpt.com "What is Amazon Inspector? - Amazon Inspector"
[30]: https://docs.aws.amazon.com/inspector/latest/user/scanning-resources.html?utm_source=chatgpt.com "Automated scan types in Amazon Inspector"
[31]: https://docs.aws.amazon.com/inspector/latest/user/scanning-ec2.html?utm_source=chatgpt.com "Scanning Amazon EC2 instances with Amazon Inspector"
[32]: https://docs.aws.amazon.com/inspector/latest/user/scanning-ecr.html?utm_source=chatgpt.com "Scanning Amazon Elastic Container Registry ..."
[33]: https://docs.aws.amazon.com/inspector/latest/user/scanning-lambda.html?utm_source=chatgpt.com "Scanning AWS Lambda functions with Amazon Inspector"
[34]: https://docs.aws.amazon.com/inspector/latest/user/findings-types.html?utm_source=chatgpt.com "Amazon Inspector finding types - Amazon Inspector"
[35]: https://docs.aws.amazon.com/inspector/latest/user/findings-understanding-score.html?utm_source=chatgpt.com "Viewing the Amazon Inspector score and understanding ..."
[36]: https://docs.aws.amazon.com/inspector/latest/user/findings-understanding.html?utm_source=chatgpt.com "Understanding Amazon Inspector findings - Amazon Inspector"
[37]: https://docs.aws.amazon.com/inspector/latest/user/findings-managing-supression-rules.html?utm_source=chatgpt.com "Suppressing Amazon Inspector findings - Amazon Inspector"
[38]: https://docs.aws.amazon.com/inspector/latest/user/assessing-coverage.html?utm_source=chatgpt.com "Assessing Amazon Inspector coverage of your AWS environment - Amazon Inspector"
[39]: https://docs.aws.amazon.com/inspector/latest/user/supported.html?utm_source=chatgpt.com "Supported operating systems and programming languages ..."
[40]: https://docs.aws.amazon.com/inspector/latest/user/sbom-generator.html?utm_source=chatgpt.com "Amazon Inspector SBOM Generator"
[41]: https://docs.aws.amazon.com/inspector/latest/user/scanning-cicd.html?utm_source=chatgpt.com "Integrating Amazon Inspector scans into your CI/CD pipeline"
[42]: https://docs.aws.amazon.com/inspector/latest/user/code-security-assessments.html?utm_source=chatgpt.com "Amazon Inspector Code Security"
[43]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/inspector2_organization_configuration?utm_source=chatgpt.com "aws_inspector2_organization_configuration | Resources | hashicorp/aws | Terraform | Terraform Registry"
[44]: https://docs.aws.amazon.com/macie/latest/user/what-is-macie.html?utm_source=chatgpt.com "What is Amazon Macie? - Amazon Macie"
[45]: https://docs.aws.amazon.com/macie/latest/user/findings-types.html?utm_source=chatgpt.com "Types of Macie findings - Amazon Macie"
[46]: https://docs.aws.amazon.com/macie/latest/user/mdis-reference.html?utm_source=chatgpt.com "Detailed reference: Managed data identifiers by category"
[47]: https://docs.aws.amazon.com/macie/latest/user/discovery-asdd-how-it-works.html?utm_source=chatgpt.com "How automated sensitive data discovery works"
[48]: https://docs.aws.amazon.com/macie/latest/user/cdis-options.html?utm_source=chatgpt.com "Configuration options for custom data identifiers"
[49]: https://docs.aws.amazon.com/macie/latest/user/discovery-supported-storage.html?utm_source=chatgpt.com "Supported storage classes and formats - Amazon Macie"
[50]: https://docs.aws.amazon.com/macie/latest/user/discovery-results-repository-s3.html?utm_source=chatgpt.com "Storing and retaining sensitive data discovery results"
[51]: https://docs.aws.amazon.com/macie/latest/user/findings-severity.html?utm_source=chatgpt.com "Severity scoring for Macie findings - Amazon Macie"
[52]: https://docs.aws.amazon.com/detective/latest/userguide/what-is-detective.html?utm_source=chatgpt.com "What is Amazon Detective? - Amazon Detective"
[53]: https://docs.aws.amazon.com/detective/latest/userguide/graph-data-structure-overview.html?utm_source=chatgpt.com "Overview of the behavior graph data structure - Amazon Detective"
[54]: https://docs.aws.amazon.com/detective/latest/userguide/detective-investigation-about.html?utm_source=chatgpt.com "How Detective is used for investigation - Amazon Detective"
[55]: https://docs.aws.amazon.com/detective/latest/userguide/groups-about.html?utm_source=chatgpt.com "Analyzing finding groups - Amazon Detective"
[56]: https://docs.aws.amazon.com/detective/latest/userguide/understanding-groups.html?utm_source=chatgpt.com "Understanding the finding groups page - Amazon Detective"
[57]: https://docs.aws.amazon.com/detective/latest/userguide/finding-group-summary.html?utm_source=chatgpt.com "Finding group summary powered by generative AI - Amazon Detective"
[58]: https://docs.aws.amazon.com/guardduty/latest/ug/detective-integration.html?utm_source=chatgpt.com "Integrating with Amazon Detective - Amazon GuardDuty"
[59]: https://docs.aws.amazon.com/detective/latest/userguide/analyzing-findings.html?utm_source=chatgpt.com "Analyzing findings in Amazon Detective - Amazon Detective"
[60]: https://docs.aws.amazon.com/detective/latest/userguide/detective-enabling.html?utm_source=chatgpt.com "Enabling Detective - Amazon Detective"
[61]: https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html?utm_source=chatgpt.com "AWS Identity and Access Management Access Analyzer ..."
[62]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-concepts.html?utm_source=chatgpt.com "Understand how IAM Access Analyzer findings work - AWS Identity and Access Management"
[63]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-resources.html?utm_source=chatgpt.com "IAM Access Analyzer supported resource types for external ..."
[64]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-findings.html?utm_source=chatgpt.com "IAM Access Analyzer findings"
[65]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html?utm_source=chatgpt.com "Policies and permissions in AWS Identity and Access ..."
[66]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-custom-policy-checks.html?utm_source=chatgpt.com "Validate policies with IAM Access Analyzer custom policy checks"
[67]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-generation.html?utm_source=chatgpt.com "IAM Access Analyzer policy generation - AWS Documentation"
[68]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-archive-rules.html?utm_source=chatgpt.com "Archive rules - AWS Identity and Access Management"
[69]: https://registry.terraform.io/providers/hashicorp/awS/latest/docs/resources/guardduty_detector?utm_source=chatgpt.com "aws_guardduty_detector | Resources | hashicorp/aws | Terraform | Terraform Registry"
[70]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_organization_configuration?utm_source=chatgpt.com "aws_guardduty_organization_configuration | Resources | hashicorp/aws | Terraform | Terraform Registry"
[71]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_organization_configuration_feature?utm_source=chatgpt.com "aws_guardduty_organization_configuration_feature | Resources | hashicorp/aws | Terraform | Terraform Registry"
[72]: https://registry.terraform.io/providers/hashicorp/awS/latest/docs/resources/guardduty_malware_protection_plan?utm_source=chatgpt.com "aws_guardduty_malware_protection_plan | Resources | hashicorp/aws | Terraform | Terraform Registry"
[73]: https://registry.terraform.io/providers/-/aws/latest/docs/resources/securityhub_finding_aggregator?utm_source=chatgpt.com "aws_securityhub_finding_aggregator | Resources | hashicorp/aws | Terraform | Terraform Registry"
[74]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_organization_configuration?utm_source=chatgpt.com "aws_securityhub_organization_configuration | Resources | hashicorp/aws | Terraform | Terraform Registry"
[75]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_configuration_policy?utm_source=chatgpt.com "aws_securityhub_configuration_policy | Resources | hashicorp/aws | Terraform | Terraform Registry"
[76]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/macie2_account?utm_source=chatgpt.com "aws_macie2_account | Resources | hashicorp/aws | Terraform | Terraform Registry"
[77]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/detective_graph?utm_source=chatgpt.com "aws_detective_graph | Resources | hashicorp/aws | Terraform | Terraform Registry"
[78]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer.html?utm_source=chatgpt.com "aws_accessanalyzer_analyzer | Resources | hashicorp/aws | Terraform | Terraform Registry"
[79]: https://docs.aws.amazon.com/guardduty/latest/ug/sample_findings.html?utm_source=chatgpt.com "Generating sample findings in GuardDuty - Amazon GuardDuty"
[80]: https://docs.aws.amazon.com/macie/latest/user/discovery-asdd-settings-defaults.html?utm_source=chatgpt.com "Default settings for automated sensitive data discovery"
[81]: https://docs.aws.amazon.com/detective/latest/userguide/detective-search.html?utm_source=chatgpt.com "Searching for a finding or entity in Detective - Amazon Detective"
[82]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-getting-started.html?utm_source=chatgpt.com "Getting started with AWS Identity and Access Management Access Analyzer - AWS Identity and Access Management"
