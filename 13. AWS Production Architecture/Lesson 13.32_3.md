# AWS Masterclass — Lesson 32 Part 3

# AWS Systems Manager & Production Fleet Operations

## Session Manager, Run Command, State Manager, Patch Manager, Automation, Inventory, Maintenance Windows & Hybrid Operations

In the previous parts:

```text
CloudWatch
    │
    ▼
How is my system behaving?


CloudTrail
    │
    ▼
Who changed something?


AWS Config
    │
    ▼
What changed?


EventBridge
    │
    ▼
How should AWS react?


NOW
    │
    ▼
Systems Manager
    │
    ▼
How do I OPERATE
hundreds or thousands
of servers safely?
```

AWS Systems Manager is designed to centrally view, manage, and operate nodes across AWS, on-premises, and multicloud environments. Its tools include Session Manager, Run Command, Patch Manager, State Manager, Automation, Inventory, Fleet Manager, and related capabilities. ([AWS Documentation][1])

---

# 1. The Old Server-Administration Model

A traditional environment often looks like this:

```text
Engineer Laptop
      │
      │ SSH
      ▼
Bastion Host
      │
      │ SSH
      ▼
Production EC2
```

Requirements:

```text
Port 22

SSH keys

bastion host

key rotation

bastion patching

network access

authorized_keys management
```

At small scale it seems manageable.

At 500 servers:

```text
500 servers
×
SSH users
×
SSH keys
×
sudo permissions
×
patching
×
configuration
=
OPERATIONS PROBLEM
```

Systems Manager gives us a different operating model:

```text
Engineer
   │
   ▼
IAM
   │
   ▼
Systems Manager
   │
   ▼
SSM Agent
   │
   ▼
Managed Node
```

For Session Manager specifically, AWS supports administration without opening inbound ports, maintaining bastion hosts, or distributing SSH keys. ([AWS Documentation][2])

---

# 2. What Is a Managed Node?

AWS uses the term:

# Managed node

for a machine configured so Systems Manager can manage it.

That may be:

```text
EC2

On-prem server

VMware VM

VM in another cloud

edge device
```

after the required Systems Manager setup. ([AWS Documentation][3])

The single most useful mental model is:

```text
                 MANAGED NODE

                     =
                     
              SSM AGENT
                  +
          AWS AUTHORIZATION
                  +
         NETWORK CONNECTIVITY
```

If a server isn't appearing in Systems Manager, investigate those three layers first. AWS's troubleshooting guidance similarly focuses on SSM Agent health, IAM permissions/registration, and connectivity to Systems Manager endpoints. ([docs.aws.amazon.com][4])

---

# 3. SSM Agent

The:

# AWS Systems Manager Agent — SSM Agent

runs on the managed machine.

Architecture:

```text
                  AWS SYSTEMS MANAGER
                         ▲
                         │
                   HTTPS / messages
                         │
                    SSM Agent
                         │
                         ▼
                    Operating OS
```

SSM Agent runs on EC2, on-premises servers, VMs, and supported edge devices and processes requests from Systems Manager tools. ([AWS Documentation][5])

---

# 4. SSM Agent Does the Work Locally

Suppose you use Run Command:

```text
aws ssm send-command
```

The architecture is conceptually:

```text
Administrator
      │
      ▼
Systems Manager API
      │
      ▼
Systems Manager service
      │
      ▼
SSM Agent
      │
      ▼
execute command locally
      │
      ▼
return status/output
```

Systems Manager is therefore not magically SSHing into the box.

The:

```text
SSM Agent
```

is the local execution/control component.

---

# 5. Check SSM Agent on Linux

On many Linux systems:

```bash
sudo systemctl status amazon-ssm-agent
```

Restart:

```bash
sudo systemctl restart amazon-ssm-agent
```

Enable:

```bash
sudo systemctl enable amazon-ssm-agent
```

Inspect logs:

```bash
sudo journalctl -u amazon-ssm-agent
```

SSM Agent also maintains its own logs describing executions, scheduled actions, errors, and health information. AWS documents platform-specific SSM Agent log locations and recommends forwarding agent logs to CloudWatch Logs when centralized analysis is needed. ([AWS Documentation][6])

---

# 6. Do Not Run Ancient SSM Agent Versions

Some Systems Manager features require minimum SSM Agent versions.

For example, current Session Manager prerequisites state that port-forwarding and SSH-through-Session-Manager sessions require SSM Agent `3.0.222.0` or later, while streaming session data to CloudWatch Logs requires `3.0.284.0` or later. ([AWS Documentation][7])

Production rule:

```text
SSM Agent
should itself be managed.
```

Systems Manager Quick Setup can periodically check and update SSM Agent across fleets. ([AWS Documentation][8])

---

# PART A — GIVING EC2 PERMISSION TO BECOME MANAGED

# 7. Systems Manager Needs AWS Permissions

SSM Agent must be able to authenticate to AWS.

Two important modern EC2 models are:

```text
OPTION A
Instance Profile
      │
      ▼
IAM Role
      │
      ▼
SSM permissions
```

or:

```text
OPTION B
Default Host Management Configuration
      │
      ▼
Account/Region-level
SSM management permissions
```

AWS currently recommends Default Host Management Configuration when its account-level operating model suits the environment; traditional instance profiles remain supported. ([AWS Documentation][9])

---

# 8. Traditional Instance Profile

Classic architecture:

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
AmazonSSMManagedInstanceCore
```

`AmazonSSMManagedInstanceCore` provides the core permissions commonly used by EC2 instance roles for Systems Manager communications. Session Manager's current prerequisites also reference it as a role configuration that provides required Systems Manager permissions. ([AWS Documentation][7])

The workload receives temporary IAM role credentials.

Do not place:

```text
AWS_ACCESS_KEY_ID

AWS_SECRET_ACCESS_KEY
```

inside the server just to make SSM work.

---

# 9. Newer Model — Default Host Management Configuration

AWS also provides:

# Default Host Management Configuration — DHMC

It can automatically make EC2 instances Systems Manager managed nodes across an account and Region without requiring you to manually attach a dedicated Systems Manager instance profile to each machine. AWS currently uses the managed policy `AmazonSSMManagedEC2InstanceDefaultPolicy` for the default management role. ([AWS Documentation][10])

Mental model:

```text
ACCOUNT + REGION
      │
      ▼
Default Host Management
      │
      ▼
Systems Manager role
      │
      ▼
all qualifying EC2
      │
      ▼
managed automatically
```

---

# 10. Important DHMC Requirements

Current AWS documentation says DHMC requires qualifying EC2 instances to use:

```text
IMDSv2
```

and it must be enabled separately in each Region where you want the behavior. ([AWS Documentation][10])

One particularly important edge case:

If an instance already has an attached instance profile allowing:

```text
ssm:UpdateInstanceInformation
```

SSM Agent prefers those instance-profile permissions instead of the DHMC credentials. That can prevent the instance from using the intended DHMC role. ([AWS Documentation][10])

### Never forget

```text
Existing IAM role
can affect
which SSM credential source wins.
```

---

# 11. Which Model Should I Use?

### Instance profile

Good when:

```text
each workload already
has an IAM role

and

you want explicit
per-instance role control
```

Example:

```text
TodoAppEC2Role
    │
    ├── S3 app permissions
    ├── Secrets Manager
    └── SSM core permissions
```

### DHMC

Good when:

```text
central platform team
wants fleet-wide SSM onboarding
```

without manually touching every EC2 role.

In large organizations, account-wide host management often reduces configuration drift.

---

# PART B — NETWORK CONNECTIVITY

# 12. SSM Is an OUTBOUND Model

This is one of the most important architectural differences from SSH.

Traditional SSH:

```text
Administrator
      │
      │ inbound TCP/22
      ▼
EC2
```

Session Manager:

```text
EC2 SSM Agent
      │
      │ outbound HTTPS
      ▼
Systems Manager
      ▲
      │
Administrator
```

Therefore your EC2 instance doesn't need:

```text
Inbound 22
```

just for Session Manager administration. Session Manager explicitly supports managed-node access without opening inbound ports. ([AWS Documentation][2])

---

# 13. Private EC2 Is Fine

Architecture:

```text
Internet
   X
   │
Private EC2
   │
   │ outbound Systems Manager path
   ▼
Systems Manager
```

The instance can have:

```text
NO PUBLIC IPv4

NO PORT 22

NO BASTION
```

provided the agent has authorization and network connectivity to the required Systems Manager service endpoints. ([AWS Documentation][2])

---

# 14. Two Network Models

## Option 1 — Internet/NAT egress

```text
Private EC2
     │
     ▼
NAT Gateway
     │
     ▼
Systems Manager public endpoints
```

## Option 2 — PrivateLink

```text
Private EC2
     │
     ▼
Interface VPC Endpoints
     │
     ▼
Systems Manager
```

AWS Systems Manager supports private connectivity using VPC interface endpoints powered by AWS PrivateLink. ([AWS Documentation][11])

---

# 15. Important Systems Manager Endpoints

For modern SSM designs, the important endpoint families include:

```text
ssm.<region>.amazonaws.com

ssmmessages.<region>.amazonaws.com
```

and older Regions may still expose `ec2messages` compatibility paths. AWS now recommends `ssmmessages`; Regions launched in 2024 or later support only `ssmmessages` rather than `ec2messages`. ([AWS Documentation][12])

For Mumbai (`ap-south-1`), build new designs around:

```text
ssm

ssmmessages
```

rather than depending on legacy `ec2messages`.

---

# 16. VPC Endpoint Security Group

Your interface VPC endpoint has a security group.

It must allow:

```text
TCP 443
```

from the managed-node network/security-group path.

AWS explicitly notes that the endpoint security group must allow inbound HTTPS from the managed instances that need to connect through it. ([AWS Documentation][13])

Architecture:

```text
EC2 Security Group
 outbound 443
       │
       ▼
VPC Endpoint SG
 inbound 443
       │
       ▼
Systems Manager
```

---

# 17. DNS Matters Too

If you use custom DNS infrastructure, Systems Manager endpoint names must resolve correctly.

AWS recommends forwarding relevant `amazonaws.com` queries to the VPC's Amazon DNS resolver when a custom DNS server is used with private endpoints. ([AWS Documentation][13])

So:

```text
SSM not connected
```

can actually be:

```text
DNS problem.
```

---

# PART C — SESSION MANAGER

# 18. What Is Session Manager?

Session Manager provides interactive shell connectivity to managed nodes through Systems Manager.

It supports:

```text
EC2

on-prem nodes

VMs

Linux

Windows

macOS where supported
```

without requiring open inbound administration ports, bastion hosts, or SSH keys. ([AWS Documentation][2])

Architecture:

```text
Administrator
      │
      ▼
IAM authorization
      │
      ▼
Session Manager
      │
      ▼
SSM Agent
      │
      ▼
Shell
```

---

# 19. No-SSH Production Architecture

Bad:

```text
Security Group:

22/tcp
0.0.0.0/0
```

Better:

```text
Production EC2 SG

Inbound:
80/443 or application traffic only

NO SSH ingress
```

Administration:

```text
IAM Identity Center
       │
       ▼
Admin/Operations Role
       │
       ▼
Session Manager
       │
       ▼
Private EC2
```

The attack surface is significantly reduced because there is no internet-facing SSH listener solely for administration. Session Manager was specifically designed to eliminate the need for inbound management ports and bastion hosts. ([AWS Documentation][2])

---

# 20. Start a Session

First:

```bash
aws sts get-caller-identity
```

List managed nodes:

```bash
aws ssm describe-instance-information \
  --region ap-south-1
```

Then:

```bash
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --region ap-south-1
```

For CLI sessions, AWS requires the Session Manager plugin in addition to a compatible AWS CLI installation. ([AWS Documentation][2])

---

# 21. Two Different Permission Sets Exist

Do not confuse:

```text
NODE permissions
```

with:

```text
HUMAN permissions.
```

### Node

Needs permission to communicate with Systems Manager.

### Engineer

Needs authorization such as:

```text
ssm:StartSession

ssm:TerminateSession

ssm:ResumeSession
```

appropriately scoped.

AWS provides example IAM policies that restrict Session Manager users to specific managed nodes and let users terminate only their own sessions. ([AWS Documentation][14])

---

# 22. Tag-Based Session Access

A powerful pattern:

```text
EC2 tags:

Environment=Production
Team=Platform
```

Then IAM:

```text
Platform engineers
may StartSession
only where:

Team=Platform
```

This scales much better than maintaining a list of 300 instance IDs.

Mental model:

```text
NODE TAGS
    +
IAM CONDITIONS
    =
fleet access policy
```

---

# 23. `ssm-user`

By default, Session Manager commonly creates/uses the system-generated:

```text
ssm-user
```

on managed nodes; on Linux/macOS this user is added to sudoers by the standard Session Manager behavior. AWS also supports **Run As** so sessions can be started under a specified existing OS identity instead. ([AWS Documentation][15])

This is security-sensitive.

Do not assume:

```text
IAM StartSession
=
harmless read-only access.
```

The resulting OS account privileges matter.

---

# 24. Session Manager Run As

You can configure:

```text
SSMSessionRunAs
```

so a user's IAM identity/tag maps to a specific OS account.

Example:

```text
IAM identity
    │
    │ SSMSessionRunAs=prodops
    ▼
Session Manager
    │
    ▼
OS account:
prodops
```

AWS verifies the OS user exists before starting the Run-As session. ([AWS Documentation][15])

This allows better separation than:

```text
everyone → root-like ssm-user.
```

---

# 25. Session Logging

Session Manager can integrate with:

```text
CloudTrail
CloudWatch Logs
Amazon S3
```

for auditing/session logging depending on session configuration. CloudTrail records Session Manager API activity, and interactive session content can be configured for S3 or CloudWatch Logs. ([AWS Documentation][16])

Architecture:

```text
Session
   │
   ├── API audit ──► CloudTrail
   │
   └── session data
          │
          ├──► CloudWatch Logs
          └──► S3
```

---

# 26. Session Content Logging Has a Big Limitation

AWS explicitly states that session-content logging is **not available** for Session Manager sessions that use:

```text
SSH tunneling

or

port forwarding
```

because Session Manager is transporting encrypted tunnel traffic rather than inspecting the application-layer SSH/forwarded payload. ([AWS Documentation][17])

### Exam / production trap

```text
Session Manager tunnel
≠
all tunneled content automatically recorded.
```

---

# 27. KMS Session Encryption

Session Manager already uses TLS for its communication.

You can additionally configure a symmetric AWS KMS key for session-data encryption between the user's local machine and managed node. Both the user and the managed node require appropriate KMS permissions. ([AWS Documentation][18])

This connects directly to Lesson 31:

```text
Session Manager
    │
    ▼
KMS authorization
```

---

# 28. Port Forwarding

Session Manager can create a local port-forwarding tunnel.

Example use case:

```text
Laptop
localhost:5432
     │
     ▼
Session Manager
     │
     ▼
Private server / DB endpoint
:5432
```

This means an engineer may access a private service without exposing that service publicly.

For example, you can use the AWS-provided port-forwarding session document from the CLI rather than opening a database port to your laptop's public IP. Current Session Manager prerequisites require SSM Agent `3.0.222.0` or later for port forwarding. ([AWS Documentation][7])

---

# 29. Production Benefit

Instead of:

```text
Database SG:

5432
from engineer home IP
```

you can use:

```text
Engineer
   │
   ▼
Session Manager tunnel
   │
   ▼
approved managed node
   │
   ▼
Private database
```

You retain IAM-based control over who may initiate the administrative access path.

---

# PART D — JUST-IN-TIME NODE ACCESS

# 30. Modern Systems Manager Goes Beyond Permanent `StartSession`

AWS Systems Manager now has:

# Just-in-time node access

introduced to reduce standing node privileges.

Instead of giving an engineer permanent:

```text
ssm:StartSession
```

access, users can request temporary, time-bound access governed by approval policies. Systems Manager retains JIT access requests for one year and emits EventBridge events for relevant request/approval status changes. ([AWS Documentation][19])

---

# 31. JIT Mental Model

Traditional:

```text
Engineer
   │
   │ permanent StartSession
   ▼
Production server
```

JIT:

```text
Engineer
   │
   ▼
Request access
   │
   ▼
Approval policy
   │
 ┌─┴─────────────┐
 ▼               ▼
Auto approval   Human approval
   │               │
   └──────┬────────┘
          ▼
 Temporary access
          │
          ▼
      Production
          │
          ▼
       expires
```

This is much closer to:

```text
ZERO STANDING PRIVILEGES
```

than permanently giving everyone production shell access. ([AWS Documentation][19])

---

# 32. JIT Approval Policies

Current Systems Manager supports:

```text
AUTO-APPROVAL

MANUAL APPROVAL

DENY-ACCESS
```

policies. Manual policies can define approval levels, numbers of required approvers, target nodes, and allowed access duration. ([AWS Documentation][20])

An architecture could therefore be:

```text
Dev nodes
→ auto-approved


Production web
→ one approval


Production database
→ two approval levels
```

---

# 33. Important JIT Migration Trap

Enabling JIT does **not** magically remove existing Session Manager access.

AWS states that to make users go through JIT rather than ordinary Session Manager, you must remove their existing:

```text
ssm:StartSession
```

permissions. Otherwise they can continue to use ordinary Session Manager permissions. ([AWS Documentation][21])

Never forget:

```text
ADDING JIT
without
REMOVING standing access
does not create zero-standing access.
```

---

# PART E — RUN COMMAND

# 34. Session Manager Is Interactive

Use it when a human needs:

```text
interactive shell
```

But what if you need to run:

```text
sudo systemctl restart nginx
```

across:

```text
500 instances?
```

Do **not** open 500 shells.

Use:

# Systems Manager Run Command

Run Command can execute commands remotely across one or many managed nodes. ([AWS Documentation][22])

---

# 35. Run Command Architecture

```text
Administrator / Automation
          │
          ▼
      Run Command
          │
          ▼
       SSM Document
          │
     ┌────┼──────┐
     ▼    ▼      ▼
   EC2-1 EC2-2  EC2-500
```

This transforms:

```text
server-by-server administration
```

into:

```text
fleet operations.
```

---

# 36. SSM Documents

Systems Manager operations use:

# SSM Documents

Documents define the actions Systems Manager should perform.

Common AWS-provided examples include:

```text
AWS-RunShellScript

AWS-RunPowerShellScript
```

and many service-specific command/automation documents.

Think:

```text
DOCUMENT
=
reusable operations definition
```

instead of:

```text
random command pasted
into 500 shells.
```

---

# 37. Basic Run Command

Linux example:

```bash
aws ssm send-command \
  --instance-ids i-0123456789abcdef0 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["uptime","df -h","free -m"]' \
  --region ap-south-1
```

This sends the shell commands through Systems Manager rather than requiring SSH connectivity to the node. Run Command supports selecting one or more managed nodes as command targets. ([AWS Documentation][22])

---

# 38. Tags Are Better Than Instance IDs

Instead of:

```text
i-123
i-456
i-789
...
```

target:

```text
Environment=Production

Application=Todo
```

Conceptually:

```bash
aws ssm send-command \
  --targets \
    "Key=tag:Environment,Values=Production" \
    "Key=tag:Application,Values=Todo" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo systemctl status nginx"]' \
  --region ap-south-1
```

Run Command supports tag-based fleet targets and rate controls for large operations. ([AWS Documentation][23])

---

# 39. Never Restart 5,000 Servers at Once

Run Command supports:

```text
MaxConcurrency

MaxErrors
```

For example:

```text
Concurrency = 10%

Max errors = 1%
```

Systems Manager then limits the size of the active wave and can halt further rollout when the configured error threshold is exceeded. ([AWS Documentation][23])

Architecture:

```text
1000 servers
     │
     ▼
max-concurrency 10%
     │
     ▼
100 at a time
     │
     ▼
failure threshold reached?
     │
  ┌──┴──┐
 NO    YES
 │      │
 ▼      X
next   stop
wave
```

---

# 40. Production Command Rollout

For a risky command:

```text
1 canary
   ↓
5 nodes
   ↓
10%
   ↓
25%
   ↓
remaining fleet
```

Even though Run Command lets you execute at huge scale, **being able to do something instantly does not mean you should**.

---

# 41. Store Run Command Output

Run Command output can be sent to:

```text
CloudWatch Logs
```

for near-real-time centralized output, and supported workflows can also store command response information in S3. ([AWS Documentation][24])

Architecture:

```text
Run Command
     │
     ▼
500 nodes
     │
     ▼
stdout/stderr
     │
     ▼
CloudWatch Logs
```

This is much better than manually copying terminal output from every machine.

---

# 42. A Subtle Script Failure Trap

Suppose:

```bash
command_that_fails
echo "finished"
```

The final `echo` returns:

```text
0
```

and your overall script can appear successful if your script doesn't properly propagate earlier failures. AWS documents that Run Command reports the exit code of the last command in the script by default. ([AWS Documentation][25])

Safer shell logic might use:

```bash
set -euo pipefail
```

where appropriate.

Your automation must propagate failures correctly.

---

# 43. Session Manager vs Run Command

```text
SESSION MANAGER
=
human interactive access


RUN COMMAND
=
remote fleet execution
```

Example:

```text
Need to investigate one server manually?
→ Session Manager

Need to restart agent on 400 servers?
→ Run Command
```

---

# PART F — STATE MANAGER

# 44. Run Command Is Imperative

Run Command says:

```text
DO THIS NOW.
```

Example:

```text
install nginx
```

But what if someone removes nginx tomorrow?

Run Command does nothing automatically.

That leads us to:

# State Manager

---

# 45. State Manager Is Desired State

State Manager associations define:

```text
THIS RESOURCE
SHOULD REMAIN
IN THIS STATE.
```

Example:

```text
Antivirus installed

SSM Agent current

security daemon running

specific configuration present
```

and State Manager reapplies the association according to its schedule and supported triggers to reduce configuration drift. ([AWS Documentation][26])

---

# 46. State Manager Association

The key object is:

# Association

```text
Association
│
├── Document
├── Parameters
├── Targets
├── Schedule
├── Concurrency
└── Error threshold
```

AWS defines an association as a configuration assigned to resources to establish and maintain a desired state. ([AWS Documentation][26])

---

# 47. Example

Desired state:

```text
CloudWatch Agent
must be installed
and running.
```

Architecture:

```text
State Manager
      │
      ▼
Association
      │
      ▼
every day
      │
      ▼
all production servers
      │
      ▼
agent installed?
  │              │
 YES             NO
  │               │
  ▼               ▼
nothing          install
```

This is configuration management.

---

# 48. Association Execution Behavior

Current State Manager can execute associations when they are created and then according to schedule; edits to an association/document and certain target availability changes can also trigger reapplication. ([AWS Documentation][26])

Think:

```text
desired state
must continually be enforced,
not merely configured once.
```

---

# 49. State Manager vs Ansible

There is conceptual overlap:

```text
State Manager
→ AWS-native desired-state operations

Ansible
→ general-purpose configuration management
```

They are not mutually exclusive.

For example:

```text
Terraform
→ provision infrastructure

Ansible
→ configure complex application host

Systems Manager
→ continuous fleet operations,
patching, access and remote execution
```

Your company may use all three.

---

# 50. Current State Manager IAM Detail

AWS's current July 2026 documentation recommends using a **custom IAM role** where you want explicit control over State Manager permissions and notes that service-linked-role support for State Manager is being phased out. ([AWS Documentation][26])

This is exactly why we keep checking current documentation rather than relying on five-year-old blog posts.

---

# PART G — PATCH MANAGER

# 51. Why Patching Is Hard

You have:

```text
1000 servers
```

running:

```text
Ubuntu
Amazon Linux
Windows
RHEL
```

New CVE appears.

You need:

```text
Which servers need patch?

Which patch is approved?

When may it install?

Does reboot occur?

Did installation succeed?

Which servers remain noncompliant?
```

That is:

# Systems Manager Patch Manager

Patch Manager automates patching of Systems Manager managed nodes with security and other supported updates. ([AWS Documentation][27])

---

# 52. Patch Manager Architecture

```text
Patch baseline/policy
       │
       ▼
Which patches approved?
       │
       ▼
Patch schedule
       │
       ▼
Managed nodes
       │
       ▼
Scan / Install
       │
       ▼
Patch compliance
```

---

# 53. Patch Baseline

A:

# Patch baseline

defines which patches should be:

```text
approved

rejected

automatically approved
after defined conditions
```

AWS provides predefined baselines, and you can create custom baselines. ([AWS Documentation][28])

Think:

```text
Patch repository
     │
     ▼
Patch baseline
     │
     ├── approved
     ├── waiting
     └── rejected
```

---

# 54. Patch Compliance Does Not Mean “Latest Everything”

This is subtle.

In Patch Manager:

```text
COMPLIANT
```

means the node has the patches required by **your selected baseline/policy criteria**, not necessarily every possible package update available on the internet. AWS explicitly defines compliance against the approval criteria configured in the applicable baseline. ([AWS Documentation][29])

So:

```text
Compliant
≠
all packages newest version.
```

---

# 55. Patch Operations

Two key modes:

```text
SCAN
```

and:

```text
SCAN + INSTALL
```

### Scan

```text
Tell me what's missing.
```

### Install

```text
Apply approved patches.
```

Current Patch Manager patch policies support either scanning or scanning and installing according to the policy. ([AWS Documentation][30])

---

# 56. Modern Recommended Pattern — Patch Policies

AWS currently recommends Systems Manager:

# Patch policies

configured through:

```text
Quick Setup
```

for centralized recurring patch management.

A policy can define:

```text
schedule

baseline

targets

scan/install behavior
```

and can be applied centrally across supported accounts and Regions. ([AWS Documentation][31])

---

# 57. Organization Patching

Architecture:

```text
AWS Organization
      │
      ▼
Systems Manager
Quick Setup
      │
      ▼
Patch Policy
      │
 ┌────┼─────────┐
 ▼    ▼         ▼
Dev  Stage     Prod
```

Current patch-policy support includes `ap-south-1` among supported Regions. ([AWS Documentation][30])

---

# 58. Production Patch Waves

Do not patch all production systems simultaneously.

Better:

```text
Wave 1
Development
     │
     ▼
validate


Wave 2
Staging
     │
     ▼
application tests


Wave 3
Prod canary
5%
     │
     ▼
monitor


Wave 4
Prod fleet
```

This combines:

```text
patch management
+
deployment discipline.
```

---

# 59. Patch Groups

You can group managed nodes using tags/patch-group concepts so different server classes use different patching strategies.

Example:

```text
PatchGroup=WebServers

PatchGroup=DatabaseServers
```

AWS now recommends patch policies via Quick Setup for centrally mapping patch baselines to managed nodes, although classic patch-group/maintenance-window patterns remain supported. ([AWS Documentation][32])

---

# 60. On-Demand Patching

Patch Manager also supports:

```text
Patch now
```

for an immediate patching operation rather than waiting for the next scheduled policy/window. ([AWS Documentation][27])

Use cases:

```text
critical zero-day

urgent security update

new build validation
```

But production still needs:

```text
change management
testing
rollback/replacement strategy
```

around the patch.

---

# PART H — MAINTENANCE WINDOWS

# 61. What Is a Maintenance Window?

A:

# Maintenance Window

defines a scheduled period in which approved operational tasks may execute.

Think:

```text
Saturday
22:00–02:00
        │
        ▼
maintenance allowed
```

Systems Manager Maintenance Windows can schedule Run Command, Automation, Lambda, and Step Functions tasks. ([AWS Documentation][33])

---

# 62. Important Maintenance Window Concepts

```text
Schedule

Duration

Cutoff

Targets

Tasks

Priority

Concurrency

Error threshold
```

### Duration

How long the window remains open.

### Cutoff

How long before window end new task invocations should stop starting.

AWS maintenance-window scheduling explicitly supports duration and cutoff controls. ([AWS Documentation][34])

---

# 63. Example

```text
Window:
Production-Patching

Schedule:
Saturday 22:00

Duration:
4 hours

Cutoff:
1 hour
```

Means conceptually:

```text
22:00
window starts

01:00
stop launching new work

02:00
window ends
```

---

# 64. Maintenance Window Tasks

Current task types include:

```text
Run Command

Automation

Lambda

Step Functions Standard workflow
```

and tasks can be assigned priorities; priority `0` is the highest. Tasks with the same priority may run in parallel. ([AWS Documentation][33])

---

# 65. Maintenance Windows vs State Manager

A useful distinction:

```text
STATE MANAGER
=
keep resource in desired state
on recurring association schedule


MAINTENANCE WINDOW
=
perform operational work
inside approved maintenance period
```

Examples:

```text
CloudWatch Agent must always exist
→ State Manager


Patch database servers
Saturday 11 PM
→ Maintenance Window
```

AWS documents both tools as complementary, with Maintenance Windows additionally providing task priority and window-specific controls. ([AWS Documentation][35])

---

# PART I — INVENTORY

# 66. What Is Systems Manager Inventory?

Inventory collects:

```text
METADATA
```

about managed nodes.

Examples include information about:

```text
installed applications

network configuration

system properties

system updates

AWS components
```

AWS explicitly states that Inventory collects metadata rather than proprietary workload content. ([AWS Documentation][36])

---

# 67. Why Inventory Matters

Security asks:

> Which servers have vulnerable package X installed?

Without inventory:

```text
SSH server 1
dpkg -l

SSH server 2
dpkg -l

SSH server 3
...
```

With Inventory:

```text
Fleet
 │
 ▼
Inventory metadata
 │
 ▼
Central query
```

---

# 68. Inventory Uses State Manager Underneath

When you configure Systems Manager Inventory, the configuration is stored as a:

```text
State Manager association
```

that defines what metadata to collect, from which nodes, and at what schedule. ([AWS Documentation][37])

This is a great example of Systems Manager tools building on one another.

---

# 69. Example Queries

Inventory can help answer:

```text
Which machines run nginx?

Which OS versions exist?

Which servers have CloudWatch Agent?

Which nodes lack required software?

Which Windows hosts have specific installed updates?
```

Central inventory information can also be stored in S3 for broader analysis. ([AWS Documentation][36])

---

# PART J — FLEET MANAGER

# 70. Fleet Manager

Fleet Manager gives a centralized UI for viewing and managing Systems Manager managed nodes across AWS and on-premises environments. ([AWS Documentation][38])

Think:

```text
                    Fleet Manager

                ┌──────┬───────┬──────┐
                ▼      ▼       ▼      ▼
              Linux  Windows  Hybrid  EC2
```

It helps operators inspect fleet health and perform common management/troubleshooting operations without constantly establishing manual remote sessions.

---

# 71. Fleet Manager Can Go Deep

Depending on OS/functionality, Fleet Manager can help inspect/manage areas such as:

```text
processes

file system

users/groups

Windows registry

performance information
```

and supports browser-based Windows Server Remote Desktop using its GUI connectivity capability. ([AWS Documentation][39])

Again:

```text
central fleet operations
```

instead of:

```text
manually RDP every Windows server.
```

---

# PART K — AUTOMATION

# 72. Run Command Executes Commands

But production procedures often contain multiple steps:

```text
1. Snapshot volume

2. Stop application

3. Modify configuration

4. Restart

5. Validate health

6. Roll back if validation fails
```

For this use:

# Systems Manager Automation

Automation uses:

```text
runbooks
```

to execute multi-step operational workflows. ([AWS Documentation][40])

---

# 73. Automation Runbook

Conceptually:

```text
Automation Runbook
       │
       ├── Step 1
       │     create snapshot
       │
       ├── Step 2
       │     run command
       │
       ├── Step 3
       │     call AWS API
       │
       ├── Step 4
       │     wait
       │
       └── Step 5
             verify
```

Each Automation step invokes defined Systems Manager/AWS actions and can pass outputs between steps. ([AWS Documentation][41])

---

# 74. Example — Recover EC2

Runbook:

```text
Start
  │
  ▼
Create EBS snapshot
  │
  ▼
Stop instance
  │
  ▼
Change configuration
  │
  ▼
Start instance
  │
  ▼
health check
  │
 ┌┴─────────┐
OK         FAIL
│           │
▼           ▼
Finish    rollback
```

Instead of:

```text
10 lines in a wiki
and hope engineer follows them.
```

you encode the operational procedure.

---

# 75. Automation Supports Human Approval

Automation runbooks support:

```text
aws:approve
```

steps.

Example:

```text
Prepare change
      │
      ▼
Approval required
      │
   ┌──┴──┐
approve deny
   │      │
   ▼      X
Production mutation
```

Current Automation supports specifying approvers and minimum approval counts. ([AWS Documentation][42])

This is excellent for:

```text
production database restart

security quarantine

large fleet patching

failover
```

---

# 76. Automation IAM Role

Automation often needs to call APIs such as:

```text
ec2:StopInstances

ec2:CreateSnapshot

ssm:SendCommand

autoscaling:*
```

on your behalf.

Therefore it can use an:

```text
AutomationAssumeRole
```

with the exact permissions the runbook requires. AWS documents dedicated Automation service-role patterns for this purpose. ([AWS Documentation][43])

Do not give every runbook:

```text
AdministratorAccess.
```

---

# 77. Multi-Account Automation

Automation can execute across:

```text
multiple AWS accounts

multiple AWS Regions

Organizations OUs
```

from a central automation account using administration/execution role patterns. ([AWS Documentation][44])

Architecture:

```text
Central Operations Account
        │
        ▼
Automation
        │
        ├────► Dev / Mumbai
        ├────► Stage / Mumbai
        ├────► Prod / Mumbai
        └────► DR / Singapore
```

This is a powerful enterprise operation model.

---

# PART L — DISTRIBUTOR

# 78. How Do You Deploy Operations Software to the Fleet?

Examples:

```text
CloudWatch Agent

security agent

internal monitoring tool

company CLI

backup agent
```

Systems Manager:

# Distributor

lets you package and publish software to Systems Manager managed nodes. AWS provides packages for software such as Amazon CloudWatch Agent and lets you publish your own packages. ([AWS Documentation][45])

---

# 79. Distributor Architecture

```text
Software package
       │
       ▼
Distributor
       │
       ▼
Systems Manager
       │
 ┌─────┼──────┐
 ▼     ▼      ▼
EC2   EC2    On-prem
```

Combine it with State Manager:

```text
Distributor
→ package software


State Manager
→ guarantee it remains installed
```

Excellent pairing.

---

# PART M — HYBRID & MULTICLOUD

# 80. Systems Manager Is Not EC2-Only

You can manage:

```text
on-prem servers

VMs in other clouds

edge devices

supported IoT/Greengrass environments
```

using the hybrid/multicloud Systems Manager model. ([AWS Documentation][46])

Architecture:

```text
                 AWS Systems Manager

           ┌─────────┼─────────┐
           ▼         ▼         ▼
          EC2     Data Center  Other Cloud
                      │
                      ▼
                  SSM Agent
```

---

# 81. Hybrid Activation

Non-EC2 nodes normally register using:

```text
Activation ID
+
Activation Code
```

created through Systems Manager.

The code/ID are used when installing/registering SSM Agent; after registration, the machine receives a managed-node identifier typically beginning with:

```text
mi-
```

and remains registered after the original activation expires until it is explicitly deregistered. ([AWS Documentation][3])

---

# 82. Activation Credentials Are Sensitive

The:

```text
Activation Code
+
Activation ID
```

allow machines to register against the activation.

AWS warns you to copy and protect these values when created because the activation code isn't something you can simply redisplay later after losing it. ([AWS Documentation][3])

Treat them as temporary bootstrap credentials.

---

# 83. Important 2026 Hybrid Change

This is a current update older courses will not contain.

Effective **June 30, 2026**, AWS removed the old Systems Manager advanced-instances tier and its former 1,000-instance hybrid managed-node limit. AWS also states that starting **September 30, 2026**, Session Manager and Run Command will use pay-as-you-go pricing when used with hybrid managed nodes. ([AWS Documentation][46])

Since today is August 14, 2026:

```text
June 30 change
=
already effective


September 30 pricing change
=
upcoming
```

Keep this in mind when designing large hybrid fleets.

---

# PART N — QUICK SETUP & ORGANIZATION MANAGEMENT

# 84. One Account Is Easy

You can manually configure:

```text
IAM role

SSM Agent

Inventory

Patch Manager

Agent updates
```

But across:

```text
80 accounts
20 Regions
```

manual setup creates drift.

Systems Manager Quick Setup can centrally configure host-management and patching settings across AWS Organizations scopes, accounts, and Regions. ([AWS Documentation][47])

---

# 85. Organization Baseline

Conceptually:

```text
AWS Organization
      │
      ▼
Systems Manager
Quick Setup
      │
      ├── Default Host Management
      ├── SSM Agent updates
      ├── Inventory
      └── Patch Policy
           │
    ┌──────┼────────┐
    ▼      ▼        ▼
   Dev   Stage     Prod
```

This is the operational equivalent of what we learned with:

```text
Organizations
+
SCPs
+
Firewall Manager
+
Config
```

for governance.

---

# PART O — COMPLIANCE, OPSCENTER & EVENTBRIDGE

# 86. Systems Manager Compliance

Systems Manager provides compliance reporting for areas including:

```text
Patch Manager

State Manager associations
```

letting operators identify fleet nodes that aren't meeting the expected patch or configuration state. ([AWS Documentation][48])

Mental model:

```text
Desired state
       │
       ▼
fleet execution
       │
       ▼
Compliance
       │
    ┌──┴─────┐
    ▼        ▼
Compliant  Noncompliant
```

---

# 87. Systems Manager + EventBridge

Many Systems Manager operations emit EventBridge events.

Examples include Automation execution status and other supported tool events. ([AWS Documentation][49])

Architecture:

```text
Run Command fails
      │
      ▼
EventBridge
      │
      ▼
SNS / Lambda
      │
      ▼
Operations alert
```

That connects directly to Part 2.

---

# 88. OpsCenter

Systems Manager OpsCenter gives operations teams a central location for:

```text
OpsItems

investigation context

related AWS resources

Automation runbooks
```

and integrates with EventBridge so AWS events can automatically create operational work items. ([AWS Documentation][48])

Think:

```text
Event
  │
  ▼
OpsItem
  │
  ▼
Engineer investigates
  │
  ▼
Automation runbook
  │
  ▼
Resolution
```

---

# PART P — HANDS-ON “NO SSH” LAB

We'll use:

```text
Region:
ap-south-1
```

and an existing Linux EC2 instance.

## Goal

Convert this:

```text
Laptop
  │
  │ SSH :22
  ▼
EC2
```

into:

```text
Laptop
  │
  ▼
IAM
  │
  ▼
Session Manager
  │
  ▼
EC2
```

with:

```text
NO inbound SSH.
```

---

# 89. Step 1 — Check Identity

```bash
export AWS_REGION=ap-south-1

aws sts get-caller-identity
```

Always establish:

```text
WHO AM I?
```

before diagnosing Systems Manager.

---

# 90. Step 2 — Check SSM Agent

On the EC2 host:

```bash
sudo systemctl status amazon-ssm-agent
```

If needed:

```bash
sudo systemctl start amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
```

Agent troubleshooting should always happen before randomly changing IAM policies. AWS specifically recommends checking SSM Agent health and logs when Run Command or Session Manager isn't working. ([AWS Documentation][50])

---

# 91. Step 3 — IAM Instance Role Option

Create trust policy:

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

Create role:

```bash
aws iam create-role \
  --role-name EC2-SSM-CoreRole \
  --assume-role-policy-document file://ec2-trust.json
```

Attach the standard core policy:

```bash
aws iam attach-role-policy \
  --role-name EC2-SSM-CoreRole \
  --policy-arn \
  arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

The alternative for large fleets is DHMC rather than manually adding this capability to every instance profile. ([AWS Documentation][9])

---

# 92. Step 4 — Instance Profile

```bash
aws iam create-instance-profile \
  --instance-profile-name EC2-SSM-CoreProfile
```

Add role:

```bash
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2-SSM-CoreProfile \
  --role-name EC2-SSM-CoreRole
```

Attach to instance if it doesn't already have a workload role/profile:

```bash
aws ec2 associate-iam-instance-profile \
  --instance-id i-0123456789abcdef0 \
  --iam-instance-profile \
    Name=EC2-SSM-CoreProfile \
  --region "$AWS_REGION"
```

### Important

If the EC2 already has an application IAM role, don't blindly replace it.

Instead:

```text
update existing role
or
choose DHMC
```

according to your architecture.

---

# 93. Step 5 — Check Managed Node

Wait for registration/heartbeat, then:

```bash
aws ssm describe-instance-information \
  --region "$AWS_REGION"
```

You want to see information such as:

```text
InstanceId

PingStatus

PlatformName

PlatformVersion

AgentVersion
```

A managed node periodically signals Systems Manager to report availability; prolonged connection loss is reflected in Fleet Manager status. ([AWS Documentation][4])

---

# 94. Step 6 — Start Session

```bash
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --region "$AWS_REGION"
```

Once this works:

```text
IAM
+
Agent
+
Network
```

are functioning sufficiently for Session Manager.

---

# 95. Step 7 — Remove SSH Ingress

Now remove the Security Group rule:

```text
TCP 22
0.0.0.0/0
```

or your temporary admin CIDR if SSH is no longer required operationally.

Validate:

```text
Session Manager
=
still works
```

Now the architecture becomes:

```text
Inbound SG:

80/443/app traffic
ONLY


Admin:
Session Manager
```

---

# 96. Step 8 — Run Fleet Command

```bash
aws ssm send-command \
  --targets \
    "Key=tag:Environment,Values=Production" \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["hostname","uptime","df -h"]' \
  --max-concurrency "10%" \
  --max-errors "1" \
  --region "$AWS_REGION"
```

This is the beginning of fleet operations rather than server-by-server administration. Run Command supports both target selection and concurrency/error rate controls. ([AWS Documentation][23])

---

# 97. Step 9 — Patch Scan Only

Before actually patching:

```bash
aws ssm send-command \
  --instance-ids i-0123456789abcdef0 \
  --document-name AWS-RunPatchBaseline \
  --parameters \
    '{"Operation":["Scan"],"RebootOption":["NoReboot"]}' \
  --region "$AWS_REGION"
```

This asks Patch Manager to evaluate patch state without immediately installing approved updates.

AWS supports Scan and Install modes through Patch Manager workflows. ([AWS Documentation][30])

---

# PART Q — PRODUCTION TROUBLESHOOTING

# 98. “Instance Is Not Showing in Systems Manager”

Use this exact flow:

```text
INSTANCE NOT MANAGED
        │
        ▼
1. Is SSM Agent installed?
        │
        ▼
2. Is SSM Agent running?
        │
        ▼
3. Correct IAM/registration?
        │
        ▼
4. Can it reach SSM endpoints?
        │
        ▼
5. DNS working?
        │
        ▼
6. VPC endpoint SG allows 443?
        │
        ▼
7. Proxy/firewall interfering?
        │
        ▼
8. Check SSM Agent logs
```

These are the major failure categories AWS documents for unavailable managed nodes and SSM Agent connectivity failures. ([AWS Documentation][4])

---

# 99. Error — `TargetNotConnected`

Common causes:

```text
SSM Agent stopped

node cannot reach endpoint

wrong Region

IAM/registration problem

old agent

proxy misconfiguration
```

AWS's Session Manager troubleshooting guide specifically points to agent versions, IAM instance permissions, network routing/firewalling, and proxy configuration when nodes fail to connect. ([AWS Documentation][51])

---

# 100. Private EC2 Has No NAT

If you're intentionally running:

```text
NO INTERNET EGRESS
```

create the necessary VPC endpoints.

At minimum for modern Session Manager architecture, inspect connectivity to:

```text
ssm.<region>

ssmmessages.<region>
```

and configure any other endpoints/storage access needed by the Systems Manager capabilities you're using. AWS notes that certain SSM Agent workflows may also require access to AWS-managed S3 buckets. ([AWS Documentation][50])

---

# 101. Session Works but Logs Don't Appear

Check:

```text
Session preferences

CloudWatch Logs permissions

S3 permissions

KMS key permissions

SSM Agent version
```

And ask:

```text
Is this port forwarding
or SSH-over-Session Manager?
```

If yes, session-content logging isn't available for that tunnel type. ([AWS Documentation][17])

---

# 102. Run Command Shows Success but Something Failed

Check script exit-code behavior.

Bad:

```bash
critical_command
echo "done"
```

Better:

```bash
set -euo pipefail

critical_command

echo "done"
```

AWS notes that the final command exit code determines overall script status unless you explicitly structure the script to exit on earlier errors. ([AWS Documentation][25])

---

# 103. Run Command Broke Too Many Servers

You probably failed to use:

```text
MaxConcurrency

MaxErrors

canary targeting
```

At scale:

```text
remote execution
must be treated like deployment.
```

AWS provides these controls specifically to limit concurrent execution and stop large fleet operations when failure thresholds are exceeded. ([AWS Documentation][23])

---

# 104. Patch Failed

Check:

```text
package repository connectivity

OS/package-manager health

baseline

approved/rejected patch rules

SSM Agent

IAM

disk space

reboot requirements

maintenance timing
```

Don't interpret every:

```text
NON_COMPLIANT
```

node as an SSM failure.

It can simply mean the node hasn't installed all patches approved by its chosen baseline. ([AWS Documentation][29])

---

# 105. State Manager Keeps Changing My Configuration Back

That's probably not a bug.

If:

```text
Association says:
nginx config = X
```

and you manually change:

```text
X → Y
```

State Manager may later reapply:

```text
X
```

because its entire purpose is maintaining desired state. ([AWS Documentation][26])

Never troubleshoot configuration management without checking:

```text
WHO OWNS THE DESIRED STATE?
```

---

# PART R — TERRAFORM

# 106. EC2 Role

```hcl
resource "aws_iam_role" "ec2_ssm" {
  name = "prod-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role = aws_iam_role.ec2_ssm.name

  policy_arn =
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

Then:

```hcl
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "prod-ec2-ssm"

  role = aws_iam_role.ec2_ssm.name
}
```

In a DHMC-centric organization you may not need to duplicate SSM core onboarding permissions into every workload instance role. AWS supports both management models. ([AWS Documentation][10])

---

# 107. State Manager Association

Conceptual Terraform:

```hcl
resource "aws_ssm_association" "cloudwatch_agent" {
  name = "AmazonCloudWatch-ManageAgent"

  targets {
    key = "tag:Environment"

    values = [
      "Production"
    ]
  }

  parameters = {
    action = "configure"
    mode   = "ec2"
  }
}
```

The architecture is:

```text
Terraform
   │
   ▼
State Manager association
   │
   ▼
all tagged production servers
```

not:

```text
Terraform SSH provisioner
into every server.
```

That separation is much more production-friendly.

---

# 108. Terraform + Systems Manager Philosophy

Try to avoid infrastructure such as:

```hcl
provisioner "remote-exec" {
  inline = [
    "sudo apt update",
    "sudo apt install ...",
    "..."
  ]
}
```

as the main long-lived configuration-management strategy.

A stronger separation is often:

```text
Terraform
→ AWS infrastructure


Systems Manager / Ansible
→ node operations/configuration


CI/CD
→ application deployment
```

because failed SSH provisioners tightly couple infrastructure state with server shell availability.

---

# PART S — INTERVIEW / CERTIFICATION DECISION TABLE

| Requirement                                 | Systems Manager tool           |
| ------------------------------------------- | ------------------------------ |
| Shell without port 22                       | **Session Manager**            |
| Temporary approved node shell               | **Just-in-time node access**   |
| Execute command across 500 nodes            | **Run Command**                |
| Keep configuration continuously applied     | **State Manager**              |
| Patch fleet                                 | **Patch Manager**              |
| Operate only in approved maintenance period | **Maintenance Windows**        |
| Collect installed-software metadata         | **Inventory**                  |
| Central node GUI/management                 | **Fleet Manager**              |
| Multi-step operational workflow             | **Automation**                 |
| Require approval in runbook                 | **Automation `aws:approve`**   |
| Deploy operations software packages         | **Distributor**                |
| Manage on-prem/other-cloud server           | **Hybrid activation**          |
| Track patch/configuration compliance        | **Systems Manager Compliance** |

---

# 109. SAA-C03 Scenario

> Security requires administrators to access private EC2 servers without a bastion host, public IP, SSH key, or inbound port 22.

Think:

```text
AWS Systems Manager
Session Manager
```

Session Manager explicitly supports secure administration without inbound ports, bastions, or SSH-key management. ([AWS Documentation][2])

---

# 110. DOP-C02 Scenario

> Run a diagnostic script on 2,000 EC2 instances while ensuring only 5% execute it at once.

Think:

```text
Systems Manager Run Command

MaxConcurrency=5%
```

and configure an appropriate:

```text
MaxErrors
```

threshold. ([AWS Documentation][23])

---

# 111. Scenario

> Ensure CloudWatch Agent remains installed on every production server.

Think:

```text
Systems Manager State Manager
```

because the requirement is desired state rather than a one-time command. ([AWS Documentation][26])

---

# 112. Scenario

> Find all servers that have package `openssl` version X installed.

Think:

```text
Systems Manager Inventory
```

because Inventory centrally collects installed-software and system metadata from managed nodes. ([AWS Documentation][36])

---

# 113. Scenario

> Patch 60 AWS accounts across multiple Regions from one centralized policy.

Think:

```text
Patch Manager
+
Quick Setup
+
Patch Policies
+
AWS Organizations
```

Patch policies provide centralized recurring patch configuration across accounts and Regions. ([AWS Documentation][27])

---

# 114. Scenario

> Production restart must wait for two human approvals.

Think:

```text
Systems Manager Automation
+
aws:approve
```

not a shell script hidden in Jenkins. ([AWS Documentation][42])

---

# 115. Scenario

> Security wants engineers to request production shell access only when needed, with temporary approved access rather than permanent session permission.

Current answer:

```text
Systems Manager
Just-in-Time Node Access
```

with approval policies. ([AWS Documentation][19])

---

# 116. Scenario

> Private instance cannot connect to Session Manager and has no NAT.

Think:

```text
Systems Manager
Interface VPC endpoints
```

and verify:

```text
ssm

ssmmessages

endpoint SG 443

private DNS

node IAM
```

before adding a public IP. ([AWS Documentation][13])

---

# 117. The Whole Systems Manager Mental Map

```text
                      SYSTEMS MANAGER

                           MANAGED NODE
                               │
                 ┌─────────────┼─────────────┐
                 │             │             │
             SSM Agent      IAM/Auth      Network
                 │             │             │
                 └─────────────┼─────────────┘
                               ▼
                          SYSTEMS MANAGER
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
    Session Manager       Run Command          Patch Manager
          │                    │                    │
    interactive shell      fleet commands        patch fleet

          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
     State Manager         Automation           Inventory
          │                    │                    │
     desired state        multi-step runbook      metadata

          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
 Maintenance Windows       Distributor          Fleet Manager
          │                    │                    │
    approved periods        packages            fleet UI

                               │
                               ▼
                     HYBRID / MULTICLOUD
                               │
                               ▼
                       Hybrid Activation
```

---

# 118. The Most Important Security Model

The goal is **not** merely:

```text
"Replace SSH command
with SSM command."
```

The mature model is:

```text
                        HUMAN ACCESS

                    IAM Identity Center
                           │
                           ▼
                    Operations Role
                           │
                 ┌─────────┴─────────┐
                 ▼                   ▼
           JIT approval         Session Manager
                 │                   │
                 └─────────┬─────────┘
                           ▼
                     Managed Node
                           │
                           X
                         SSH 22


                     FLEET CHANGES

                        Pipeline
                           │
                           ▼
                     Run Command /
                       Automation
                           │
                  concurrency limits
                           │
                           ▼
                         Fleet


                    CONFIGURATION

                     State Manager


                       PATCHING

                     Patch Policy


                         AUDIT

               CloudTrail + CloudWatch
```

---

# 119. 30 Rules to Burn Into Memory

```text
1. Systems Manager is a fleet-operations platform.

2. A managed node requires:
   Agent + authorization + connectivity.

3. SSM Agent runs on the managed machine.

4. Session Manager does not require inbound port 22.

5. Session Manager can remove the need for bastion hosts.

6. EC2 can use an instance profile for SSM permissions.

7. DHMC can provide account/Region-wide
   host management permissions.

8. DHMC currently requires IMDSv2.

9. Existing instance-role SSM permissions can
   affect DHMC credential selection.

10. New SSM designs should use ssmmessages.

11. VPC endpoints enable private SSM connectivity.

12. Endpoint security groups need HTTPS connectivity.

13. Session Manager user permissions and
    node permissions are different.

14. Run As can map sessions to specific OS users.

15. Session APIs can be audited with CloudTrail.

16. Interactive session output can be sent to
    CloudWatch Logs/S3 when supported.

17. SSH and port-forwarding tunnel content
    cannot be recorded by Session Manager.

18. JIT access reduces standing node privilege.

19. Run Command is for fleet command execution.

20. Use tag targets instead of giant instance-ID lists.

21. MaxConcurrency limits blast radius.

22. MaxErrors can halt a bad fleet operation.

23. State Manager maintains desired configuration.

24. Patch Manager evaluates patches against baselines.

25. Patch compliance means compliant with
    the selected baseline criteria.

26. Patch Policies are the modern centralized
    patch-management approach.

27. Maintenance Windows control WHEN work executes.

28. Inventory tells you WHAT exists on the fleet.

29. Automation encodes operational procedures.

30. Production server management should depend on
    identity + automation, not shared SSH keys.
```

---

# 120. The Permanent Troubleshooting Formula

Whenever someone says:

> “SSM isn't working.”

Do not randomly edit security groups.

Use:

```text
                    SSM FAILURE

                        WHO?
                         │
                         ▼
              aws sts get-caller-identity


                      AGENT?
                         │
                         ▼
          systemctl status amazon-ssm-agent


                   NODE IDENTITY?
                         │
                         ▼
        instance profile / DHMC / activation


                    NETWORK?
                         │
                         ▼
        ssm + ssmmessages HTTPS connectivity


                       DNS?
                         │
                         ▼
           Regional endpoint resolution


                   SSM STATUS?
                         │
                         ▼
       aws ssm describe-instance-information


                   AGENT LOGS?
                         │
                         ▼
           amazon-ssm-agent logs


                  STILL BROKEN?
                         │
                         ▼
          inspect IAM / proxy / endpoint SG
```

That eliminates most Systems Manager troubleshooting confusion.

---

# ✅ Lesson 32 Part 3 Complete

You now understand:

```text
✓ AWS Systems Manager architecture
✓ managed nodes
✓ SSM Agent
✓ IAM instance profiles
✓ AmazonSSMManagedInstanceCore
✓ Default Host Management Configuration
✓ AmazonSSMManagedEC2InstanceDefaultPolicy
✓ IMDSv2 requirement
✓ SSM credential selection

✓ SSM network architecture
✓ ssm endpoint
✓ ssmmessages endpoint
✓ legacy ec2messages distinction
✓ VPC endpoints
✓ AWS PrivateLink
✓ private EC2 administration

✓ Session Manager
✓ no inbound SSH
✓ no bastion architecture
✓ CLI sessions
✓ Session Manager plugin
✓ IAM access
✓ tag-based access
✓ ssm-user
✓ Run As
✓ CloudTrail session audit
✓ CloudWatch/S3 session logging
✓ KMS session encryption
✓ port forwarding
✓ SSH/port-forward logging limitation

✓ just-in-time node access
✓ zero-standing privilege model
✓ auto approval
✓ manual approval
✓ deny policies
✓ temporary access

✓ Run Command
✓ SSM Documents
✓ AWS-RunShellScript
✓ tag-based fleet targeting
✓ MaxConcurrency
✓ MaxErrors
✓ CloudWatch command output
✓ exit-code handling

✓ State Manager
✓ associations
✓ desired state
✓ drift correction
✓ schedules
✓ rate control

✓ Patch Manager
✓ patch baselines
✓ predefined/custom baselines
✓ Scan
✓ Install
✓ compliance
✓ patch groups
✓ patch policies
✓ Quick Setup
✓ Patch Now
✓ production patch waves

✓ Maintenance Windows
✓ schedules
✓ duration
✓ cutoff
✓ targets
✓ task priority
✓ Run Command tasks
✓ Automation tasks
✓ Lambda / Step Functions tasks

✓ Inventory
✓ software metadata
✓ system metadata
✓ network metadata
✓ Fleet Manager

✓ Systems Manager Automation
✓ runbooks
✓ multi-step workflows
✓ approvals
✓ service roles
✓ multi-account
✓ multi-Region

✓ Distributor
✓ hybrid activation
✓ on-prem / multicloud nodes
✓ 2026 hybrid Systems Manager changes

✓ Compliance
✓ OpsCenter
✓ EventBridge integration
✓ Terraform patterns
✓ complete no-SSH hands-on lab
✓ troubleshooting
✓ SAA-C03 / DOP-C02 scenarios
```

---

# Next — Lesson 32 Part 4

# **AWS X-Ray, Application Signals, Synthetics, RUM & End-to-End Observability**

CloudWatch Part 1 taught us:

```text
METRICS
+
LOGS
```

But imagine:

```text
User clicks Checkout
        │
        ▼
CloudFront
        │
        ▼
ALB
        │
        ▼
Node.js API
        │
        ▼
Payment Service
        │
        ▼
SQS
        │
        ▼
Worker
        │
        ▼
DynamoDB
```

and the whole request takes:

```text
8.7 seconds.
```

CPU dashboards cannot tell us where those **8.7 seconds** went.

Next we'll build:

```text
                     ONE USER REQUEST

                            │
                            ▼
                           RUM
                    real browser view
                            │
                            ▼
                         Synthetics
                      external probes
                            │
                            ▼
                       Application
                            │
                            ▼
                    OpenTelemetry
                            │
                            ▼
                       AWS X-Ray
                            │
             ┌──────────────┼───────────────┐
             ▼              ▼               ▼
           API           Service B       Database
          60ms            400ms           3.2s
                                            │
                                            ▼
                                      ROOT CAUSE

                            +
                    Application Signals
                            │
                            ▼
                   Services / SLOs / latency
```

We'll cover **distributed tracing, trace IDs, spans/segments, sampling, service maps, annotations vs metadata, OpenTelemetry/ADOT, X-Ray trace analysis, CloudWatch Application Signals, service-level objectives, CloudWatch Synthetics canaries, browser monitoring with RUM, Internet Monitor, cross-account observability, correlation between logs/metrics/traces, Terraform, and a full production latency incident from browser → ALB → Node.js → database.**

[1]: https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html?utm_source=chatgpt.com "What is AWS Systems Manager? - ..."
[2]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html?utm_source=chatgpt.com "AWS Systems Manager Session Manager"
[3]: https://docs.aws.amazon.com/systems-manager/latest/userguide/hybrid-activation-managed-nodes.html?utm_source=chatgpt.com "Create a hybrid activation to register nodes with Systems ..."
[4]: https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager-troubleshooting-managed-nodes.html?utm_source=chatgpt.com "Troubleshooting managed node availability"
[5]: https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html?utm_source=chatgpt.com "Working with SSM Agent - AWS Systems Manager"
[6]: https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent-logs.html?utm_source=chatgpt.com "Viewing SSM Agent logs - AWS Systems Manager"
[7]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-prerequisites.html?utm_source=chatgpt.com "Step 1: Complete Session Manager prerequisites"
[8]: https://docs.aws.amazon.com/systems-manager/latest/userguide/quick-setup-host-management.html?utm_source=chatgpt.com "Set up Amazon EC2 host management using Quick Setup"
[9]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-instance-profile.html?utm_source=chatgpt.com "Verify or add instance permissions for Session Manager"
[10]: https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager-default-host-management-configuration.html?utm_source=chatgpt.com "Managing EC2 instances automatically with Default Host ..."
[11]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-privatelink.html?utm_source=chatgpt.com "(Optional) Use AWS PrivateLink to set up a VPC endpoint ..."
[12]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-messageAPIs.html?utm_source=chatgpt.com "Reference: ec2messages, ssmmessages, and other API operations"
[13]: https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html?utm_source=chatgpt.com "Improve the security of EC2 instances by using VPC ..."
[14]: https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-quickstart.html?utm_source=chatgpt.com "Sample IAM policies for Session Manager"
[15]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-preferences-run-as.html?utm_source=chatgpt.com "Turn on Run As support for Linux and macOS managed nodes"
[16]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-auditing.html?utm_source=chatgpt.com "Logging session activity - AWS Systems Manager"
[17]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-logging.html?utm_source=chatgpt.com "Enabling and disabling session logging"
[18]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-preferences-enable-encryption.html?utm_source=chatgpt.com "Turn on KMS key encryption of session data (console)"
[19]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-just-in-time-node-access.html?utm_source=chatgpt.com "Just-in-time node access using Systems Manager"
[20]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-just-in-time-node-access-approval-policies.html?utm_source=chatgpt.com "Create approval policies for your nodes"
[21]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-just-in-time-node-access-start-session.html?utm_source=chatgpt.com "Start a just-in-time node access session - AWS Documentation"
[22]: https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html?utm_source=chatgpt.com "AWS Systems Manager Run Command"
[23]: https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-multiple.html?utm_source=chatgpt.com "Run commands at scale - AWS Systems Manager"
[24]: https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up-cwlogs.html?utm_source=chatgpt.com "Configuring Amazon CloudWatch Logs for Run Command"
[25]: https://docs.aws.amazon.com/systems-manager/latest/userguide/troubleshooting-remote-commands.html?utm_source=chatgpt.com "Troubleshooting Systems Manager Run Command"
[26]: https://docs.aws.amazon.com/systems-manager/latest/userguide/state-manager-about.html?utm_source=chatgpt.com "Understanding how State Manager works"
[27]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager.html?utm_source=chatgpt.com "AWS Systems Manager Patch Manager"
[28]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-predefined-and-custom-patch-baselines.html?utm_source=chatgpt.com "Predefined and custom patch baselines"
[29]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-release-history.html?utm_source=chatgpt.com "Document history - AWS Systems Manager"
[30]: https://docs.aws.amazon.com/systems-manager/latest/userguide/quick-setup-patch-manager.html?utm_source=chatgpt.com "Configure patching for instances in an organization using a ..."
[31]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-policies.html?utm_source=chatgpt.com "Patch policy configurations in Quick Setup"
[32]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-tag-a-patch-group.html?utm_source=chatgpt.com "Creating and managing patch groups - AWS Documentation"
[33]: https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-maintenance-assign-tasks.html?utm_source=chatgpt.com "Assign tasks to a maintenance window using the console"
[34]: https://docs.aws.amazon.com/systems-manager/latest/userguide/maintenance-windows-schedule-options.html?utm_source=chatgpt.com "Maintenance window scheduling and active period options"
[35]: https://docs.aws.amazon.com/systems-manager/latest/userguide/state-manager-vs-maintenance-windows.html?utm_source=chatgpt.com "State Manager and Maintenance Windows: Key use cases"
[36]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-inventory.html?utm_source=chatgpt.com "AWS Systems Manager Inventory"
[37]: https://docs.aws.amazon.com/systems-manager/latest/userguide/inventory-about.html?utm_source=chatgpt.com "Learn more about Systems Manager Inventory"
[38]: https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager.html?utm_source=chatgpt.com "AWS Systems Manager Fleet Manager"
[39]: https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager-remote-desktop-connections.html?utm_source=chatgpt.com "Connecting to a Windows Server managed instance using ..."
[40]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html?utm_source=chatgpt.com "AWS Systems Manager Automation"
[41]: https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-troubleshooting.html?utm_source=chatgpt.com "Troubleshooting Systems Manager Automation - AWS Documentation"
[42]: https://docs.aws.amazon.com/systems-manager/latest/userguide/running-automations-require-approvals.html?utm_source=chatgpt.com "Run an automation that requires approvals - AWS Systems Manager"
[43]: https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-setup-iam.html?utm_source=chatgpt.com "Create the service roles for Automation using the console"
[44]: https://docs.aws.amazon.com/systems-manager/latest/userguide/running-automations-multiple-accounts-regions.html?utm_source=chatgpt.com "Running automations in multiple AWS Regions and accounts"
[45]: https://docs.aws.amazon.com/systems-manager/latest/userguide/distributor.html?utm_source=chatgpt.com "AWS Systems Manager Distributor"
[46]: https://docs.aws.amazon.com/systems-manager/latest/userguide/activations.html?utm_source=chatgpt.com "AWS Systems Manager Hybrid Activations"
[47]: https://docs.aws.amazon.com/systems-manager/latest/userguide/quick-setup-default-host-management-configuration.html?utm_source=chatgpt.com "Set up the Default Host Management Configuration for an ..."
[48]: https://docs.aws.amazon.com/systems-manager/latest/userguide/logging-and-monitoring.html?utm_source=chatgpt.com "Logging and monitoring in AWS Systems Manager"
[49]: https://docs.aws.amazon.com/systems-manager/latest/userguide/monitoring-systems-manager-event-examples.html?utm_source=chatgpt.com "Amazon EventBridge event examples for Systems Manager"
[50]: https://docs.aws.amazon.com/systems-manager/latest/userguide/troubleshooting-ssm-agent.html?utm_source=chatgpt.com "Troubleshooting SSM Agent - AWS Systems Manager"
[51]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-troubleshooting.html?utm_source=chatgpt.com "Troubleshooting Session Manager - AWS Documentation"
