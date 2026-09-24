# AWS Masterclass — Phase 3

# Lesson 39: AWS Systems Manager Production Operations

## 1. Lesson objectives

By the end of this lesson, you will be able to:

* Manage EC2, on-premises and multicloud servers as Systems Manager managed nodes.
* Access private instances without public IP addresses, bastion hosts or inbound SSH rules.
* Execute commands across large fleets using Run Command.
* Build reusable operational workflows using Automation runbooks.
* Maintain required configurations using State Manager.
* Patch Linux and Windows fleets using Patch Manager.
* Schedule disruptive operations using Maintenance Windows.
* Collect software, operating-system and configuration metadata using Inventory.
* Troubleshoot servers through Fleet Manager.
* Distribute software packages with Distributor.
* Record, investigate and remediate operational issues through OpsCenter.
* Control production changes with Change Calendar and Change Manager.
* Operate Systems Manager across multiple AWS accounts and Regions.
* Register on-premises and non-AWS machines using hybrid activations.
* Design secure private connectivity using VPC endpoints.
* Automate Systems Manager resources with Terraform and AWS CLI.

---

# 2. What is AWS Systems Manager?

AWS Systems Manager is a centralized operations platform for viewing, managing and operating nodes across:

* Amazon EC2.
* On-premises data centres.
* Other cloud environments.
* Edge environments.
* Supported IoT devices.

The unified Systems Manager experience can aggregate operational information across AWS accounts and Regions. ([AWS Documentation][1])

## Systems Manager mental model

```text
AWS Systems Manager
│
├── Node access
│   ├── Session Manager
│   ├── Fleet Manager
│   └── Just-in-time access
│
├── Fleet operations
│   ├── Run Command
│   ├── Automation
│   ├── State Manager
│   └── Distributor
│
├── Security and maintenance
│   ├── Patch Manager
│   ├── Maintenance Windows
│   ├── Change Calendar
│   └── Change Manager
│
├── Visibility
│   ├── Inventory
│   ├── Explorer
│   ├── Compliance
│   └── OpsCenter
│
└── Application configuration
    └── Parameter Store
```

## One-line memory trick

```text
Session Manager connects.
Run Command executes.
Automation orchestrates.
State Manager maintains.
Patch Manager updates.
Inventory discovers.
OpsCenter investigates.
```

---

# 3. Traditional server administration problem

A traditional EC2 administration design often looks like:

```text
Administrator
      |
      | SSH over internet
      v
Bastion host
      |
      | SSH
      v
Private EC2 instances
```

This requires:

* Public or externally reachable infrastructure.
* Inbound port 22 or 3389.
* SSH-key management.
* Bastion-host patching.
* Bastion-host monitoring.
* User provisioning on operating systems.
* Session-audit tooling.
* Network access to every managed server.

Systems Manager enables a different model:

```text
Administrator
      |
      | IAM-authenticated API request
      v
Systems Manager
      |
      | Outbound agent connection
      v
Private managed node
```

Session Manager provides interactive browser or CLI access without requiring inbound ports, bastion hosts or long-lived SSH keys. ([AWS Documentation][2])

---

# 4. What is a managed node?

A managed node is a machine configured for Systems Manager.

Supported categories include:

```text
Amazon EC2 instance
On-premises server
Virtual machine in another cloud
Edge device
AWS IoT Greengrass core device
```

([AWS Documentation][3])

For a server to become a managed node, it generally needs:

```text
1. Supported operating system
2. SSM Agent installed and running
3. IAM permissions
4. Network access to Systems Manager endpoints
5. Correct AWS Region configuration
```

---

# 5. SSM Agent

SSM Agent is software running on the managed node.

```text
Systems Manager service
        |
        | Commands and session messages
        v
SSM Agent
        |
        v
Operating system
```

The agent:

* Registers the node.
* Receives Systems Manager instructions.
* Executes documents and commands.
* Returns command output and status.
* Establishes Session Manager channels.
* Reports inventory and compliance.
* Applies State Manager associations.

AWS regularly releases new SSM Agent versions, and outdated agents can prevent newer Systems Manager capabilities from working correctly. AWS recommends automating agent updates. ([AWS Documentation][4])

Check the agent on Ubuntu:

```bash
sudo systemctl status amazon-ssm-agent
```

Restart it:

```bash
sudo systemctl restart amazon-ssm-agent
```

View logs:

```bash
sudo journalctl -u amazon-ssm-agent -f
```

Common Linux log location:

```text
/var/log/amazon/ssm/amazon-ssm-agent.log
```

Common Windows location:

```text
C:\ProgramData\Amazon\SSM\Logs\
```

---

# 6. EC2 permissions for Systems Manager

An EC2 managed node needs permission to communicate with Systems Manager.

There are two main approaches:

```text
Default Host Management Configuration
or
IAM instance profile
```

AWS recommends Default Host Management Configuration for centrally enabling the required permissions across EC2 instances in an account and Region. It must be enabled separately in every Region where it is required. ([AWS Documentation][5])

## Option 1: IAM instance profile

```text
EC2 instance
     |
     v
IAM instance profile
     |
     v
IAM role
     |
     v
Systems Manager permissions
```

Common AWS-managed policy:

```text
AmazonSSMManagedInstanceCore
```

Trust policy:

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

Attach the policy:

```bash
aws iam attach-role-policy \
  --role-name ProductionEC2SystemsManagerRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

---

# 7. Terraform EC2 Systems Manager role

```hcl
resource "aws_iam_role" "ssm_node" {
  name = "production-ec2-systems-manager"

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

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_node" {
  name = "production-ec2-systems-manager"
  role = aws_iam_role.ssm_node.name
}
```

Launch template:

```hcl
resource "aws_launch_template" "application" {
  name_prefix   = "production-application-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ssm_node.arn
  }

  metadata_options {
    http_tokens = "required"
  }
}
```

---

# 8. Systems Manager network connectivity

SSM Agent initiates outbound communication.

Therefore, you ordinarily do not need inbound access from Systems Manager to the server.

The node needs access to Systems Manager-related service endpoints through one of these:

```text
NAT gateway
Internet gateway with appropriate routing
Proxy server
AWS PrivateLink interface endpoints
```

For isolated private subnets, use VPC interface endpoints to keep Systems Manager communication on the AWS network. ([AWS Documentation][6])

---

# 9. Private Systems Manager architecture

```text
Private EC2 instance
No public IP
No NAT gateway
No inbound SSH
       |
       v
Interface VPC endpoints
       |
       ├── Systems Manager endpoint
       ├── Session messaging endpoint
       └── EC2 messaging endpoint where required
              |
              v
       Systems Manager service
```

Additional endpoints may be required depending on the workload:

```text
S3
CloudWatch Logs
KMS
Secrets Manager
ECR
STS
```

For example, if commands download scripts from a private S3 bucket, the node also needs S3 connectivity and IAM permission for that bucket.

---

# 10. Security groups for interface endpoints

An interface VPC endpoint creates network interfaces inside your subnets.

Recommended pattern:

```text
Managed-node security group
        |
        | Outbound TCP 443
        v
Endpoint security group

Endpoint security group:
Inbound TCP 443 only from managed-node security groups
```

Do not open endpoint security groups to the entire internet.

Example:

```hcl
resource "aws_security_group" "ssm_endpoints" {
  name   = "production-ssm-endpoints"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "HTTPS from managed nodes"
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = [aws_security_group.application.id]
  }
}
```

---

# 11. Fleet Manager managed-node states

A managed node can appear:

```text
Online
Connection lost
Inactive
```

If it does not appear at all, common reasons include:

* No SSM Agent.
* Agent stopped.
* Missing instance role.
* Wrong Region.
* No endpoint connectivity.
* DNS resolution failure.
* Unsupported operating system.
* Duplicate or corrupted local registration.
* Incorrect hybrid activation.

---

# 12. Session Manager

Session Manager provides interactive access to managed nodes.

```text
Administrator
      |
      | IAM-authorized StartSession
      v
Systems Manager
      |
      | Secure channel
      v
SSM Agent
      |
      v
Linux shell or Windows PowerShell
```

Benefits:

* No inbound SSH port.
* No inbound RDP port for shell access.
* No bastion host required.
* No SSH key distribution.
* IAM-based authorization.
* CloudTrail API auditing.
* Optional session logs.
* Optional KMS encryption.
* Central session preferences.

([AWS Documentation][2])

---

# 13. Starting a browser session

From the console:

```text
Systems Manager
→ Fleet Manager or Session Manager
→ Select managed node
→ Start session
```

From AWS CLI:

```bash
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --region ap-south-1
```

The local AWS CLI requires the Session Manager plugin for interactive CLI sessions.

Check plugin:

```bash
session-manager-plugin
```

---

# 14. Session Manager IAM policy

Example policy allowing sessions only to tagged production application instances:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StartTaggedApplicationSessions",
      "Effect": "Allow",
      "Action": [
        "ssm:StartSession"
      ],
      "Resource": [
        "arn:aws:ec2:ap-south-1:123456789012:instance/*",
        "arn:aws:ssm:ap-south-1:123456789012:document/SSM-SessionManagerRunShell"
      ],
      "Condition": {
        "StringEquals": {
          "ssm:resourceTag/Environment": "production",
          "ssm:resourceTag/Application": "TodoApp"
        }
      }
    },
    {
      "Sid": "ManageOwnSessions",
      "Effect": "Allow",
      "Action": [
        "ssm:ResumeSession",
        "ssm:TerminateSession"
      ],
      "Resource": "arn:aws:ssm:*:*:session/${aws:username}-*"
    }
  ]
}
```

In an IAM Identity Center design, use role-session and principal-tag conditions rather than relying only on `${aws:username}`.

---

# 15. Session logging

Session Manager can be configured to send supported interactive session logs to:

```text
CloudWatch Logs
Amazon S3
```

You can also configure KMS encryption for session data.

Recommended production settings:

```text
[ ] CloudWatch Logs enabled
[ ] S3 archival enabled where required
[ ] Log group encrypted
[ ] S3 bucket encrypted
[ ] Session log bucket isolated
[ ] CloudTrail organization trail enabled
[ ] Session reason required operationally
```

## Critical limitation

Session content logging is not available for sessions that use:

```text
SSH over Session Manager
Port forwarding
```

For these modes, Session Manager acts as an encrypted tunnel and cannot inspect or record the inner SSH or forwarded application traffic. ([AWS Documentation][2])

Therefore:

```text
StartSession API event:
Auditable through CloudTrail

Commands transmitted inside SSH tunnel:
Not recorded by Session Manager
```

---

# 16. Session Manager port forwarding

Session Manager can forward a local port to a port on the managed node.

Example: access PostgreSQL on the managed node:

```bash
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{
    "portNumber":["5432"],
    "localPortNumber":["15432"]
  }' \
  --region ap-south-1
```

Then connect locally:

```bash
psql \
  --host 127.0.0.1 \
  --port 15432 \
  --username todoapp_user \
  --dbname todoapp
```

Traffic path:

```text
Local port 15432
      |
      v
Session Manager tunnel
      |
      v
Managed node port 5432
```

---

# 17. Port forwarding to a remote host

The managed node can also act as a private network hop to another remote host.

```text
Developer laptop
       |
       | Session Manager tunnel
       v
Managed EC2 node
       |
       v
Private RDS database
```

Example:

```bash
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{
    "host":["production-db.example.ap-south-1.rds.amazonaws.com"],
    "portNumber":["5432"],
    "localPortNumber":["15432"]
  }' \
  --region ap-south-1
```

Remote-host port forwarding requires a sufficiently recent SSM Agent; the current documentation requires version `3.1.1374.0` or later. ([AWS Documentation][7])

The remote database does not have to be a Systems Manager managed node.

It only needs to be reachable from the selected managed node.

---

# 18. Session Manager versus SSH

| Requirement             | Direct SSH       | Session Manager shell                         |
| ----------------------- | ---------------- | --------------------------------------------- |
| Inbound port 22         | Required         | Not required                                  |
| Public IP or bastion    | Often            | Not required                                  |
| SSH keys                | Required         | Not required                                  |
| IAM authorization       | Indirect         | Native                                        |
| Session content logging | External tooling | Supported for normal shell                    |
| Port forwarding         | Yes              | Yes                                           |
| Traditional SSH tools   | Native           | Possible through tunnel                       |
| OS user management      | Required         | Still relevant for authorization and commands |

## Recommended default

```text
Normal operations:
Session Manager shell

Legacy tool requiring SSH:
SSH over Session Manager

Emergency network failure:
Strictly controlled break-glass path
```

---

# 19. Just-in-time node access

Just-in-time access allows users to request temporary, time-bound node access only when required.

```text
Engineer requests access
        |
        v
Approval policy
        |
        ├── Deny
        ├── Auto-approve
        └── Manual approval
                |
                v
      Temporary session access
                |
                v
          Access expires
```

This reduces long-standing `ssm:StartSession` permissions. Systems Manager can also record supported Windows RDP sessions for audit and compliance. ([AWS Documentation][8])

Approval-policy precedence is:

```text
1. Deny-access
2. Auto-approval
3. Manual approval
```

([AWS Documentation][9])

## Important enforcement point

Enabling just-in-time access does not automatically remove existing direct Session Manager permissions.

After testing JIT access, remove ordinary `ssm:StartSession` permission from users who must use the approval workflow. ([AWS Documentation][10])

---

# 20. Run Command

Run Command executes noninteractive administrative commands across managed nodes.

Use cases:

* Restarting a service.
* Installing a package.
* Updating configuration.
* Collecting diagnostic information.
* Rotating certificates.
* Running security scans.
* Checking file versions.
* Applying one-time fixes.
* Executing scripts across tagged fleets.

Run Command can target EC2 and registered hybrid or multicloud nodes. ([AWS Documentation][11])

```text
Administrator
      |
      | SendCommand API
      v
Systems Manager
      |
      v
Target selection
      |
      ├── Node A
      ├── Node B
      └── Node C
```

---

# 21. Run Command versus Session Manager

```text
Session Manager:
Interactive human session

Run Command:
Noninteractive remote execution
```

Use Session Manager when:

```text
An engineer needs to explore and troubleshoot.
```

Use Run Command when:

```text
The same known action must run repeatedly or across many nodes.
```

Avoid opening interactive sessions to execute the same command manually on 100 servers.

---

# 22. Run a shell command

```bash
aws ssm send-command \
  --document-name AWS-RunShellScript \
  --targets "Key=tag:Application,Values=TodoApp" \
  --parameters 'commands=[
    "systemctl status todoapp",
    "df -h",
    "free -m"
  ]' \
  --comment "Collect TodoApp diagnostics" \
  --region ap-south-1
```

PowerShell example:

```bash
aws ssm send-command \
  --document-name AWS-RunPowerShellScript \
  --targets "Key=tag:Environment,Values=production" \
  --parameters 'commands=[
    "Get-Service",
    "Get-Volume"
  ]' \
  --region ap-south-1
```

---

# 23. Targeting managed nodes

Run Command can target:

```text
Specific managed-node IDs
Tags
Resource groups
All matching managed nodes
```

Example:

```text
Key=tag:PatchGroup
Values=TodoApp-Production
```

Tag-based targeting supports dynamic fleet management.

When a new instance joins an Auto Scaling group and receives the required tags, it becomes part of future matching operations.

## Warning

Validate tag scope before executing a disruptive command.

Bad:

```text
Key=tag:Environment,Values=production
```

when the command is intended only for TodoApp.

Better:

```text
Environment=production
Application=TodoApp
Role=worker
```

---

# 24. Run Command rate controls

For large fleets, control:

```text
MaxConcurrency
MaxErrors
```

Example:

```bash
aws ssm send-command \
  --document-name AWS-RunShellScript \
  --targets "Key=tag:Application,Values=TodoApp" \
  --parameters 'commands=["sudo systemctl restart todoapp"]' \
  --max-concurrency "10%" \
  --max-errors "2" \
  --region ap-south-1
```

Meaning:

```text
Run on no more than 10% of targets simultaneously.

Stop sending the command to additional targets
after the configured error threshold is reached.
```

This limits blast radius.

---

# 25. Command output

Run Command output can be:

* Viewed through Systems Manager.
* Retrieved using the CLI.
* Sent to CloudWatch Logs.
* Stored in Amazon S3.

Retrieve invocation details:

```bash
aws ssm list-command-invocations \
  --command-id COMMAND_ID \
  --details \
  --region ap-south-1
```

For long output, configure S3 or CloudWatch Logs rather than relying only on inline command results.

---

# 26. Command status

Possible command statuses include concepts such as:

```text
Pending
InProgress
Success
Failed
TimedOut
Cancelled
Undeliverable
Terminated
```

Interpret carefully:

```text
Command-level Success
```

does not always prove that every individual target completed successfully unless the command and error thresholds are reviewed.

Always inspect:

```text
Target count
Success count
Failure count
Delivery status
Standard output
Standard error
```

---

# 27. SSM documents

Systems Manager documents define actions Systems Manager performs.

Common document types include:

```text
Command
Automation
Policy
Session
Package
ChangeCalendar
```

([AWS Documentation][12])

AWS-managed documents include:

```text
AWS-RunShellScript
AWS-RunPowerShellScript
AWS-ConfigureAWSPackage
AWS-RunPatchBaseline
AWS-StartPortForwardingSession
```

Custom documents let you standardize organization-specific operations.

---

# 28. Custom command document

Example:

```yaml
schemaVersion: "2.2"
description: Restart and validate TodoApp
parameters:
  ServiceName:
    type: String
    default: todoapp
mainSteps:
  - action: aws:runShellScript
    name: restartApplication
    inputs:
      runCommand:
        - "sudo systemctl restart {{ ServiceName }}"
        - "sudo systemctl is-active {{ ServiceName }}"
        - "curl --fail http://localhost:3002/health"
```

Create it:

```bash
aws ssm create-document \
  --name TodoApp-RestartAndValidate \
  --document-type Command \
  --document-format YAML \
  --content file://restart-todoapp.yaml \
  --region ap-south-1
```

Benefits:

* Version-controlled operation.
* Reviewed command sequence.
* Parameter validation.
* Consistent execution.
* Reduced typing errors.
* Easier auditing.

---

# 29. Document versioning

Custom documents can have multiple versions.

```text
Version 1:
Restart service

Version 2:
Restart and check process

Version 3:
Restart, check process and call health endpoint
```

Use a controlled default version.

Do not update production runbooks silently without:

* Code review.
* Testing.
* Change approval.
* Version tracking.
* Rollback capability.

---

# 30. Systems Manager Automation

Automation executes multi-step operational workflows called runbooks.

```text
Automation runbook
│
├── Step 1: Create snapshot
├── Step 2: Stop application
├── Step 3: Modify resource
├── Step 4: Start application
├── Step 5: Validate health
└── Step 6: Roll back on failure
```

Automation supports rate controls, conditional logic, approvals, AWS API calls, scripts and multi-account execution. ([AWS Documentation][13])

---

# 31. Run Command versus Automation

## Run Command

```text
Executes commands on managed operating systems.
```

## Automation

```text
Orchestrates operations across AWS resources,
APIs, managed nodes and multiple steps.
```

Example:

```text
Run Command:
Restart Nginx on an EC2 instance.

Automation:
Create AMI
→ deregister instance from target group
→ restart Nginx
→ validate
→ re-register target
→ notify team
```

---

# 32. Automation actions

Common Automation actions include concepts such as:

```text
aws:executeAwsApi
aws:executeScript
aws:runCommand
aws:branch
aws:waitForAwsResourceProperty
aws:assertAwsResourceProperty
aws:approve
aws:invokeLambdaFunction
aws:changeInstanceState
aws:createStack
aws:executeAutomation
```

Runbooks can operate entirely on AWS resources without requiring every target to be a managed node.

---

# 33. Automation service role

A runbook can assume an IAM role:

```text
AutomationAssumeRole
```

Architecture:

```text
Engineer
   |
   | StartAutomationExecution
   v
Systems Manager Automation
   |
   | sts:AssumeRole
   v
Automation execution role
   |
   v
Approved AWS actions
```

This separates:

```text
Who may start the runbook
```

from:

```text
Which actions the runbook may perform
```

Users do not need direct permission for every underlying API if the securely designed runbook and role mediate the operation.

---

# 34. Automation runbook example

```yaml
description: Restart an EC2 instance and wait until it is healthy
schemaVersion: "0.3"

assumeRole: "{{ AutomationAssumeRole }}"

parameters:
  InstanceId:
    type: String

  AutomationAssumeRole:
    type: String
    default: ""

mainSteps:
  - name: stopInstance
    action: aws:changeInstanceState
    inputs:
      InstanceIds:
        - "{{ InstanceId }}"
      DesiredState: stopped

  - name: startInstance
    action: aws:changeInstanceState
    inputs:
      InstanceIds:
        - "{{ InstanceId }}"
      DesiredState: running

  - name: verifyInstance
    action: aws:assertAwsResourceProperty
    inputs:
      Service: ec2
      Api: DescribeInstanceStatus
      InstanceIds:
        - "{{ InstanceId }}"
      PropertySelector: "$.InstanceStatuses[0].InstanceState.Name"
      DesiredValues:
        - running
```

For production, also validate EC2 status checks and application health.

---

# 35. Automation rate controls

Automation can target many resources using:

```text
Concurrency
Error threshold
```

Systems Manager supports adaptive concurrency for automation at scale, with current documentation describing scaling from 100 concurrent automations up to 500 where applicable. ([AWS Documentation][14])

Production example:

```text
Concurrency:
5%

Error threshold:
1%
```

This means:

```text
Deploy gradually.

Stop expanding the operation
when failures exceed the acceptable limit.
```

---

# 36. Multi-account Automation

Automation can run across:

* Multiple AWS accounts.
* Multiple AWS Regions.
* AWS Organizations OUs.

Centralized pattern:

```text
Operations account
       |
       v
Systems Manager Automation
       |
       ├── Production account / ap-south-1
       ├── Staging account / ap-south-1
       └── DR account / ap-southeast-1
```

([AWS Documentation][15])

Use:

* Administration role in the central account.
* Execution roles in target accounts.
* Strict trust policies.
* OU scoping.
* Concurrency controls.
* CloudTrail and runbook logs.

---

# 37. State Manager

State Manager keeps managed nodes and supported AWS resources in a declared state.

```text
Desired state:
CloudWatch Agent must be installed and running.

Current state:
CloudWatch Agent missing.

State Manager:
Installs the agent and reports compliance.
```

State Manager is a secure, scalable configuration-management capability built around associations. ([AWS Documentation][16])

Use cases:

* Keep SSM Agent updated.
* Ensure CloudWatch Agent is installed.
* Maintain antivirus software.
* Apply configuration files.
* Run compliance checks.
* Enforce service state.
* Maintain operating-system settings.
* Collect Inventory.

---

# 38. State Manager association

An association links:

```text
SSM document
+
Targets
+
Parameters
+
Schedule
+
Rate controls
```

Example:

```text
Document:
AWS-ConfigureAWSPackage

Package:
AmazonCloudWatchAgent

Target:
Environment=production

Schedule:
Every day

Desired result:
Latest approved CloudWatch Agent installed
```

---

# 39. Terraform State Manager association

```hcl
resource "aws_ssm_association" "cloudwatch_agent" {
  name = "AWS-ConfigureAWSPackage"

  association_name = "install-cloudwatch-agent"

  parameters = {
    action           = "Install"
    installationType = "Uninstall and reinstall"
    name             = "AmazonCloudWatchAgent"
    version          = "latest"
  }

  targets {
    key    = "tag:Environment"
    values = ["production"]
  }

  schedule_expression = "rate(1 day)"

  compliance_severity = "HIGH"

  max_concurrency = "10%"
  max_errors      = "1"
}
```

Using `latest` automatically can introduce untested updates.

For critical production fleets, pin an approved version and promote versions through development and staging first.

---

# 40. State Manager rate controls

State Manager supports concurrency and error thresholds for associations. If the error threshold is reached, Systems Manager stops sending the association command to further nodes until its next scheduled execution. ([AWS Documentation][17])

Recommended rollout:

```text
Development:
100% concurrency

Staging:
25% concurrency

Production:
5% or fixed small batch
```

---

# 41. Patch Manager

Patch Manager automates operating-system and application patching on managed nodes.

It supports patching across:

* EC2.
* On-premises systems.
* Multicloud nodes.
* Supported Linux distributions.
* Windows Server.
* Supported macOS environments.

Patch Manager can centrally scan and install security-related and other approved updates. ([AWS Documentation][18])

---

# 42. Patch Manager concepts

```text
Patch baseline
Patch group
Patch policy
Scan
Install
Patch compliance
Reboot option
```

## Patch baseline

Defines:

* Which patches are approved.
* Which patches are rejected.
* Product and classification rules.
* Severity.
* Approval delay.
* Explicit approved patches.
* Explicit rejected patches.

## Patch group

Groups nodes that should use the same patch baseline.

## Patch policy

A Quick Setup configuration that centrally defines patch schedules and baselines across accounts and Regions. ([AWS Documentation][19])

---

# 43. Scan versus install

## Scan

```text
Inspect installed and missing patches.
Do not install patches.
Report compliance.
```

## Install

```text
Install approved missing patches.
Optionally reboot.
Report compliance.
```

Recommended lifecycle:

```text
1. Scan fleet.
2. Review compliance.
3. Test approved patches in development.
4. Install in staging.
5. Validate application.
6. Install in production waves.
7. Confirm compliance.
```

---

# 44. Patch baseline example

```text
Operating system:
Ubuntu

Approved classifications:
Security

Approval delay:
7 days after release

Rejected patch:
Known incompatible kernel version

Reboot:
Only when required and approved
```

Why delay approval?

```text
Vendor releases patch
        ↓
Development and community testing
        ↓
Seven-day approval delay
        ↓
Automatic production eligibility
```

For actively exploited critical vulnerabilities, use an emergency patch process instead of waiting for the normal delay.

---

# 45. Patch groups

Tag instances:

```text
Patch Group = TodoApp-Production
```

or, depending on the selected workflow:

```text
PatchGroup = TodoApp-Production
```

Patch-group tags and key requirements differ according to the supported patching approach and operating system. AWS currently recommends centralized Quick Setup patch policies for most new organizational patch-management deployments. ([AWS Documentation][20])

Example grouping:

```text
TodoApp-Development
TodoApp-Staging
TodoApp-Production-A
TodoApp-Production-B
```

Production A and B allow alternate patch waves.

---

# 46. Patch policy through Quick Setup

A patch policy can define:

* Target accounts.
* Target Regions.
* Scan schedule.
* Install schedule.
* Baseline.
* Reboot behavior.
* S3 output.
* Compliance reporting.
* Required IAM policy deployment.

Quick Setup can apply patch policies across an AWS Organization, selected OUs, selected accounts and selected Regions. ([AWS Documentation][21])

Architecture:

```text
Systems Manager delegated administrator
        |
        v
Quick Setup patch policy
        |
        ├── Production OU
        ├── NonProduction OU
        └── Hybrid nodes
```

---

# 47. Patch production waves

Example:

```text
Saturday 22:00:
Production group A

Validate:
Application health
Error rate
Database connectivity

Sunday 22:00:
Production group B
```

For load-balanced servers:

```text
1. Remove node from load balancer.
2. Drain connections.
3. Patch.
4. Reboot if required.
5. Validate service.
6. Return node to load balancer.
7. Continue with next node.
```

Patch Manager alone does not automatically understand every application’s safe-draining requirements.

Use Automation or load-balancer-aware operational workflows.

---

# 48. Patch prerequisites

Patch operations depend on more than SSM connectivity.

Managed nodes may also require:

* Access to operating-system package repositories.
* DNS.
* Proxy configuration.
* S3 access for required package assets.
* Local administrator or root execution.
* Supported Python and package tooling where applicable.
* Sufficient disk space.
* Healthy package database.

([AWS Documentation][22])

For an Ubuntu node in a private subnet:

```text
Systems Manager endpoints:
Command delivery

NAT or internal package mirror:
Ubuntu package downloads
```

Systems Manager VPC endpoints alone do not provide Ubuntu repository packages.

---

# 49. Patch compliance

Patch compliance can report states such as:

```text
Installed
Installed pending reboot
Missing
Failed
Not applicable
Rejected
```

Operational policy example:

```text
Critical missing patches:
Page or urgent ticket

High-severity missing patches:
Remediate within seven days

Medium:
Normal maintenance cycle

Pending reboot:
Schedule or complete reboot
```

A patch can be installed but not fully effective until the node reboots.

---

# 50. Maintenance Windows

Maintenance Windows define when potentially disruptive operations may run.

Examples:

* Operating-system patching.
* Driver updates.
* Software installation.
* Database maintenance scripts.
* Automation workflows.
* Server restarts.

([AWS Documentation][23])

```text
Maintenance window
│
├── Schedule
├── Duration
├── Cutoff
├── Targets
└── Tasks
```

---

# 51. Maintenance Window schedule

Example:

```text
Schedule:
Saturday 22:00 Asia/Kolkata

Duration:
4 hours

Cutoff:
1 hour
```

Meaning:

```text
Window opens:
22:00

No new tasks start after:
01:00

Existing operations may finish before:
02:00
```

The cutoff prevents a long task from starting too close to the end of the approved maintenance period.

---

# 52. Maintenance Window task types

Maintenance Windows can run:

```text
Run Command
Automation
AWS Lambda
AWS Step Functions
```

([AWS Documentation][24])

Example:

```text
Task 1:
Notify operations team

Task 2:
Deregister target from ALB

Task 3:
Install patches

Task 4:
Reboot

Task 5:
Validate application

Task 6:
Register target with ALB

Task 7:
Publish completion status
```

---

# 53. Terraform Maintenance Window

```hcl
resource "aws_ssm_maintenance_window" "production_patch" {
  name = "production-todoapp-patching"

  schedule = "cron(0 30 16 ? * SAT *)"

  duration = 4
  cutoff   = 1

  allow_unassociated_targets = false

  tags = {
    Environment = "production"
    Application = "TodoApp"
  }
}

resource "aws_ssm_maintenance_window_target" "production_patch" {
  window_id     = aws_ssm_maintenance_window.production_patch.id
  resource_type = "INSTANCE"

  targets {
    key    = "tag:PatchGroup"
    values = ["TodoApp-Production"]
  }

  name = "todoapp-production-nodes"
}
```

AWS maintenance-window cron schedules are evaluated according to the schedule configuration used by the service. Confirm UTC or timezone handling explicitly instead of assuming local time.

---

# 54. Inventory

Systems Manager Inventory collects metadata from managed nodes.

Examples:

* Operating-system details.
* Installed applications.
* Network configuration.
* Windows updates.
* Running services.
* Files.
* Registry data.
* AWS components.
* Custom inventory.

Inventory helps answer:

```text
Which servers have Java 11?

Which nodes contain Log4j?

Which systems run Ubuntu 22.04?

Which servers are missing the CloudWatch Agent?

Which application versions exist in production?
```

([AWS Documentation][25])

---

# 55. Enable Inventory with State Manager

Use the document:

```text
AWS-GatherSoftwareInventory
```

CLI:

```bash
aws ssm create-association \
  --name AWS-GatherSoftwareInventory \
  --targets Key=tag:Environment,Values=production \
  --schedule-expression "rate(12 hours)" \
  --parameters '{
    "applications":["Enabled"],
    "awsComponents":["Enabled"],
    "networkConfig":["Enabled"],
    "services":["Enabled"],
    "windowsUpdates":["Enabled"]
  }' \
  --region ap-south-1
```

Avoid collecting unnecessary file inventory across entire filesystems; it can add processing, data volume and cost.

---

# 56. Custom Inventory

You can publish organization-specific metadata.

Example:

```json
{
  "SchemaVersion": "1.0",
  "TypeName": "Custom:TodoApp",
  "Content": [
    {
      "ApplicationVersion": "4.2.1",
      "Environment": "production",
      "DeploymentId": "deploy-20260728-01",
      "ConfigurationVersion": "17"
    }
  ]
}
```

Use custom inventory to track:

* Application version.
* Business owner.
* Configuration version.
* Patch ring.
* Deployment ID.
* Security-agent version.
* Database-client version.

---

# 57. Resource data sync

Inventory data from multiple accounts and Regions can be synchronized into a central S3 bucket.

```text
Managed nodes
      |
      v
Systems Manager Inventory
      |
      v
Resource data sync
      |
      v
Central S3 bucket
      |
      ├── Athena
      └── Analytics dashboards
```

Resource data sync automatically updates centralized inventory data as new inventory is collected. It supports multi-account and multi-Region aggregation. ([AWS Documentation][26])

Inventory sync preserves the inventory file for a node after the managed node itself is deleted. For active nodes, newer files normally replace older current inventory data. Use AWS Config’s `SSM:ManagedInstanceInventory` resource type when historical inventory changes are required. ([AWS Documentation][26])

---

# 58. Fleet Manager

Fleet Manager provides a console interface for remotely viewing and managing nodes.

Capabilities include:

* Node health and connection status.
* Operating-system details.
* Filesystem browsing.
* Process inspection.
* User and group management.
* Registry inspection on Windows.
* Performance counters.
* Windows Event Viewer access.
* Remote Desktop for supported Windows Server nodes.
* Session access.

([AWS Documentation][27])

---

# 59. Fleet performance monitoring

Fleet Manager can retrieve real-time performance information including:

```text
CPU utilization
Disk I/O utilization
Network traffic
Memory usage
```

Fleet Manager uses Session Manager to retrieve these performance counters, so the node role and Session Manager configuration must support the operation. ([AWS Documentation][28])

This is useful for ad hoc troubleshooting.

For long-term alerting and historical metrics, use CloudWatch Agent and CloudWatch dashboards.

---

# 60. Windows Remote Desktop through Fleet Manager

Fleet Manager Remote Desktop provides browser-based RDP connectivity to supported Windows Server nodes using Amazon DCV.

Current documentation supports up to four simultaneous connections within one browser window. ([AWS Documentation][29])

Architecture:

```text
Browser
   |
   v
Fleet Manager Remote Desktop
   |
   v
Managed Windows Server
```

Benefits:

* No publicly exposed port 3389.
* No direct network route from administrator workstation.
* IAM-based authorization.
* Optional RDP recording with just-in-time access.

---

# 61. Distributor

Systems Manager Distributor packages and publishes software to managed nodes.

Use cases:

* Deploy CloudWatch Agent.
* Deploy security agents.
* Deploy internal tools.
* Install monitoring collectors.
* Distribute company scripts.
* Maintain approved package versions.

Distributor supports AWS-provided, partner and custom packages. ([AWS Documentation][30])

```text
Software package
      |
      v
Distributor package
      |
      v
Versioned manifest
      |
      v
Run Command or State Manager
      |
      v
Managed nodes
```

---

# 62. Distributor versus package repository

Distributor is for controlled Systems Manager deployment.

It does not necessarily replace:

* `apt` repository.
* `yum` repository.
* Windows package repository.
* Artifact repository.
* Container registry.

Example:

```text
apt repository:
General operating-system packages

Distributor:
Internal security scanner with custom
installation and uninstallation scripts
```

Packages can be deployed as a specific version or configured to track the latest version. ([AWS Documentation][31])

---

# 63. OpsCenter

OpsCenter provides a unified place to view, investigate and remediate operational issues associated with AWS resources.

An issue is represented as:

```text
OpsItem
```

An OpsItem can include:

* Title.
* Severity.
* Category.
* Affected resources.
* Related CloudWatch alarm.
* Related Config finding.
* Operational data.
* Runbook.
* Status.
* Timeline.
* Comments.

([AWS Documentation][32])

---

# 64. OpsCenter incident workflow

```text
CloudWatch alarm enters ALARM
        |
        v
EventBridge rule
        |
        v
Create OpsItem
        |
        v
Operations engineer investigates
        |
        v
Runs Automation remediation
        |
        v
Validates recovery
        |
        v
Resolves OpsItem
```

Example:

```text
Alarm:
EC2 filesystem usage > 90%

OpsItem:
production-todoapp-disk-space

Related resource:
i-0123456789abcdef0

Runbook:
TodoApp-CleanOldReleases
```

---

# 65. Incident Manager current availability

AWS Systems Manager Incident Manager stopped accepting new customers on **November 7, 2025**. Existing customers can continue using it, but AWS has stated that no new features or capabilities will be added. ([AWS Documentation][33])

For a new environment in 2026, design incident workflows using combinations such as:

```text
CloudWatch Alarms
EventBridge
Systems Manager OpsCenter
Systems Manager Automation
Amazon Q Developer in chat applications
SNS
PagerDuty, ServiceNow or another ITSM platform
```

Existing Incident Manager customers may continue using response plans, contacts, escalation plans and incident timelines.

---

# 66. Explorer

Systems Manager Explorer provides an operations dashboard for:

* Managed-node information.
* Patch compliance.
* State Manager compliance.
* OpsItems.
* Operational data.
* Multi-account and multi-Region views.

([AWS Documentation][34])

Explorer can aggregate data through resource data syncs.

Organization-wide aggregation is gathered through the Organizations management-account context for the Explorer view. ([AWS Documentation][35])

---

# 67. Change Calendar

Change Calendar defines periods when operational changes are allowed or blocked.

```text
OPEN:
Change may proceed.

CLOSED:
Change should not proceed.
```

Example:

```text
Normal maintenance:
Saturday 22:00–Sunday 02:00

Blackout:
Diwali sales period

Blackout:
Financial year-end close

Emergency:
Authorized emergency change process
```

Change Calendar entries are stored as Systems Manager `ChangeCalendar` documents using iCalendar-formatted data. ([AWS Documentation][36])

---

# 68. Automation with Change Calendar

Automation can be configured to respect a Change Calendar.

```text
Engineer starts production automation
        |
        v
Automation checks Change Calendar
        |
        ├── OPEN → Continue
        └── CLOSED → Do not perform change
```

([AWS Documentation][37])

This protects against:

* Accidental production restarts during peak hours.
* Scheduled deployments during business blackout periods.
* Patching during critical processing windows.

---

# 69. Change Manager

Change Manager provides an enterprise workflow for:

* Change requests.
* Approvals.
* Implementation.
* Reporting.
* Change templates.
* Multi-account and multi-Region operations.

It can be managed from a delegated administrator account in an AWS Organization. ([AWS Documentation][38])

Architecture:

```text
Engineer submits change
        |
        v
Approved change template
        |
        v
Reviewer approval
        |
        v
Automation runbook
        |
        v
Target accounts and Regions
        |
        v
Implementation report
```

---

# 70. Change Manager use case

Example request:

```text
Change:
Restart production TodoApp workers.

Reason:
Apply memory-leak configuration.

Risk:
Medium.

Planned time:
Saturday 23:00.

Rollback:
Restore old configuration and restart workers.

Automation:
TodoApp-UpdateWorkerConfiguration.
```

Reviewers can approve or reject before execution.

This separates:

```text
Who requests
Who approves
Who executes
```

---

# 71. Parameter Store operational use

Parameter Store stores:

```text
String
StringList
SecureString
```

It is useful for:

* Environment configuration.
* Agent configuration.
* Approved AMI IDs.
* Runbook parameters.
* Feature settings.
* Internal service endpoints.
* Change-control values.

([AWS Documentation][39])

Example hierarchy:

```text
/production/todoapp/operations/cloudwatch-agent-config
/production/todoapp/operations/patch-group
/production/todoapp/operations/maintenance-window
/production/todoapp/application/log-level
```

Secrets requiring automatic rotation remain a stronger fit for Secrets Manager.

---

# 72. Hybrid and multicloud nodes

Systems Manager can manage non-EC2 machines through hybrid activations.

Examples:

```text
On-premises VMware server
Azure virtual machine
Google Cloud virtual machine
Physical data-centre server
Edge server
```

A hybrid activation generates:

```text
Activation ID
Activation code
```

The activation is used when registering SSM Agent.

([AWS Documentation][40])

---

# 73. Hybrid-node identity

Hybrid nodes do not use EC2 instance profiles.

Their Systems Manager permission comes from the IAM service role associated with the hybrid activation. ([AWS Documentation][41])

```text
On-premises server
       |
       v
Activation registration
       |
       v
Managed-node identity
       |
       v
Hybrid Systems Manager IAM service role
```

Protect activation codes like temporary registration credentials.

Do not store them in source control or reusable machine images after registration.

---

# 74. Current hybrid-node pricing transition

As of **July 28, 2026**:

* The previous advanced-instances tier was removed on **June 30, 2026**.
* The former 1,000-node limit for hybrid managed nodes was removed.
* A paid advanced tier is no longer required to use Session Manager on non-EC2 nodes.
* Pay-as-you-go pricing for Session Manager and Run Command on hybrid managed nodes is scheduled to begin on **September 30, 2026**. ([AWS Documentation][40])

This change applies to hybrid managed nodes, not ordinary EC2 usage in exactly the same way.

Review current Systems Manager pricing before operating large hybrid fleets.

---

# 75. Create a hybrid activation

```bash
aws ssm create-activation \
  --default-instance-name on-prem-production \
  --description "Production data-center servers" \
  --iam-role HybridSystemsManagerRole \
  --registration-limit 20 \
  --expiration-date "2026-08-15T00:00:00Z" \
  --region ap-south-1
```

Activation expiration can be set up to 30 days in advance; without an explicit expiration, the activation code normally expires after 24 hours. ([AWS Documentation][42])

The registered node receives an ID conceptually similar to:

```text
mi-0123456789abcdef0
```

---

# 76. Quick Setup

Systems Manager Quick Setup automates common recommended configurations.

Examples:

* Default host management.
* Patch policies.
* Inventory collection.
* Agent update policies.
* Organization-wide configuration.
* CloudWatch Agent deployment.

Quick Setup can create required IAM roles and apply configurations across multiple accounts and Regions. ([AWS Documentation][43])

```text
Delegated administrator
        |
        v
Quick Setup configuration
        |
        ├── Selected OUs
        ├── Selected accounts
        └── Selected Regions
```

---

# 77. Multi-account Systems Manager design

A production organization can use:

```text
AWS Organizations
│
├── Operations account
│   ├── Systems Manager delegated administration
│   ├── Automation runbooks
│   ├── Quick Setup policies
│   ├── Explorer
│   └── OpsCenter
│
├── Production accounts
│   └── Managed nodes
│
├── NonProduction accounts
│   └── Managed nodes
│
└── Hybrid environment
    └── Registered managed nodes
```

Use separate roles for:

* Systems Manager administration.
* Automation execution.
* Patch administration.
* Session access.
* Session approval.
* Read-only fleet visibility.
* Emergency operations.

---

# 78. Production Session Manager security

Recommended architecture:

```text
Engineer
   |
   v
IAM Identity Center
   |
   v
Temporary operations role
   |
   v
Just-in-time approval
   |
   v
Session Manager
   |
   v
Private EC2 instance
```

Controls:

```text
[ ] No public IP required
[ ] No inbound SSH or RDP
[ ] MFA at identity provider
[ ] Temporary credentials
[ ] Session reason
[ ] JIT approval for production
[ ] Session logs for normal shell
[ ] CloudTrail enabled
[ ] Tag-based resource restrictions
[ ] SCP protects logging
```

---

# 79. Production patch architecture

```text
Security team
      |
      v
Approved patch baselines
      |
      v
Quick Setup patch policy
      |
      ├── Development wave
      ├── Staging wave
      ├── Production A
      └── Production B
              |
              v
     Compliance aggregation
              |
              v
       Explorer / S3 / Athena
```

Emergency flow:

```text
Critical vulnerability
      |
      v
Security approval
      |
      v
Emergency Automation runbook
      |
      v
Canary patch group
      |
      v
Production rollout with rate control
```

---

# 80. Practical lab: prepare a managed EC2 instance

## Step 1: Verify IAM role

```bash
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef0 \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --region ap-south-1
```

## Step 2: Verify agent

On the instance:

```bash
sudo systemctl status amazon-ssm-agent
```

## Step 3: Check managed-node visibility

```bash
aws ssm describe-instance-information \
  --filters Key=InstanceIds,Values=i-0123456789abcdef0 \
  --region ap-south-1
```

Expected fields include:

```text
PingStatus
PlatformName
PlatformVersion
AgentVersion
LastPingDateTime
```

---

# 81. Practical lab: Session Manager access

Start session:

```bash
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --region ap-south-1
```

Inside:

```bash
whoami
hostname
uptime
df -h
free -m
systemctl status nginx
```

Exit:

```bash
exit
```

Validate CloudTrail:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes \
    AttributeKey=EventName,AttributeValue=StartSession \
  --region ap-south-1
```

---

# 82. Practical lab: Run Command

Send diagnostics:

```bash
COMMAND_ID=$(
  aws ssm send-command \
    --document-name AWS-RunShellScript \
    --instance-ids i-0123456789abcdef0 \
    --parameters 'commands=[
      "hostname",
      "uptime",
      "df -h",
      "free -m",
      "systemctl is-active nginx"
    ]' \
    --comment "Production diagnostics lab" \
    --query Command.CommandId \
    --output text \
    --region ap-south-1
)
```

Read result:

```bash
aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id i-0123456789abcdef0 \
  --region ap-south-1
```

---

# 83. Practical lab: patch scan

Run scan without installing:

```bash
aws ssm send-command \
  --document-name AWS-RunPatchBaseline \
  --instance-ids i-0123456789abcdef0 \
  --parameters '{
    "Operation":["Scan"],
    "RebootOption":["NoReboot"]
  }' \
  --comment "Patch compliance scan" \
  --region ap-south-1
```

Review compliance:

```bash
aws ssm list-compliance-items \
  --resource-ids i-0123456789abcdef0 \
  --resource-types ManagedInstance \
  --filters \
    Key=ComplianceType,Values=Patch,Type=EQUAL \
  --region ap-south-1
```

Do not change `Scan` to `Install` on production before validating the baseline, reboot policy and maintenance window.

---

# 84. Practical lab: Inventory association

```bash
aws ssm create-association \
  --name AWS-GatherSoftwareInventory \
  --association-name production-inventory \
  --targets Key=InstanceIds,Values=i-0123456789abcdef0 \
  --schedule-expression "rate(12 hours)" \
  --region ap-south-1
```

Query inventory:

```bash
aws ssm get-inventory \
  --filters \
    Key=AWS:InstanceInformation.InstanceId,Values=i-0123456789abcdef0 \
  --region ap-south-1
```

---

# 85. Troubleshooting: node is not managed

Run:

```bash
aws ssm describe-instance-information \
  --region ap-south-1
```

Then check:

```text
1. Instance state is running.
2. SSM Agent is installed.
3. SSM Agent is running.
4. Instance profile exists.
5. IAM role contains required permissions.
6. Node can resolve DNS.
7. Node can reach HTTPS endpoints.
8. VPC endpoint security group allows TCP 443.
9. Correct Region is configured.
10. System clock is accurate.
```

Agent log:

```bash
sudo tail -n 200 \
  /var/log/amazon/ssm/amazon-ssm-agent.log
```

---

# 86. Troubleshooting: `TargetNotConnected`

Error:

```text
An error occurred (TargetNotConnected)
when calling the StartSession operation
```

Possible causes:

* SSM Agent offline.
* Managed node appears in another Region.
* Missing IAM permissions.
* Agent too old.
* Network route missing.
* VPC endpoint DNS disabled.
* Interface-endpoint security group blocks 443.
* Local agent registration corrupted.
* Instance is shutting down.

Session Manager has a dedicated troubleshooting workflow for permissions, agent, endpoint and configuration problems. ([AWS Documentation][44])

---

# 87. Troubleshooting: node online but session fails

Check the human operator’s IAM permissions:

```text
ssm:StartSession
ssm:TerminateSession
ssm:ResumeSession
```

Also check permission for the session document.

Then inspect:

```text
SCP
Permissions boundary
Identity Center permission set
Session policy
Resource tags
KMS key policy
CloudWatch Logs policy
S3 session-log policy
JIT access policy
```

An EC2 instance can be correctly managed while the operator remains unauthorized to start a session.

---

# 88. Troubleshooting: Run Command remains Pending

Possible causes:

* SSM Agent offline.
* Target tag does not match.
* Node joined after command target resolution.
* Agent is busy.
* Command could not be delivered.
* Network connectivity failed.
* Wrong Region.
* Target is not a managed node.

Review:

```bash
aws ssm list-command-invocations \
  --command-id COMMAND_ID \
  --details \
  --region ap-south-1
```

---

# 89. Troubleshooting: command says Success but task failed

Bad script:

```bash
systemctl restart todoapp
curl http://localhost:3002/health
echo "Finished"
```

Without proper shell failure handling, later commands may continue and the final exit code may be zero.

Better:

```bash
set -euo pipefail

systemctl restart todoapp

curl \
  --fail \
  --silent \
  --show-error \
  http://localhost:3002/health
```

Ensure every automation produces a meaningful exit code.

---

# 90. Troubleshooting: patch operation fails

Check:

```text
SSM Agent version
Operating-system support
Package repository connectivity
Proxy configuration
Disk space
Package database lock
Patch baseline
Patch policy IAM role
S3 access
Local administrator permission
Reboot status
```

A Quick Setup patch policy can also fail when it references a custom patch baseline that has subsequently been deleted. ([AWS Documentation][45])

Ubuntu examples:

```bash
sudo apt-get update

sudo dpkg --configure -a

sudo apt-get --fix-broken install

df -h

ps aux | grep -E 'apt|dpkg'
```

---

# 91. Troubleshooting: Maintenance Window did not run

Check:

* Window enabled.
* Schedule and timezone interpretation.
* Window duration.
* Cutoff.
* Target tags.
* Registered task.
* Service role.
* Task priority.
* IAM permission.
* Run Command or Automation status.
* Node connectivity.
* Execution history.

Maintenance Windows has separate target and task registration; creating a window alone does not make anything execute. ([AWS Documentation][46])

---

# 92. Troubleshooting: Automation stopped early

Check:

```text
MaxErrors
MaxConcurrency
Step failure
Branch condition
Assume role
API throttling
Target resource state
Timeout
Output variable
Runbook syntax
```

For an `aws:executeAwsApi` step, verify:

* Automation execution role.
* API input types.
* Resource Region.
* Service quotas.
* Expected response path.

---

# 93. Troubleshooting: Inventory missing software

Possible causes:

* Inventory association not configured.
* Association has not executed yet.
* Applications inventory disabled.
* Unsupported package metadata.
* Node offline.
* SSM Agent outdated.
* Inventory interval too long.
* Custom inventory placed in wrong location or schema.

Check associations:

```bash
aws ssm describe-instance-associations-status \
  --instance-id i-0123456789abcdef0 \
  --region ap-south-1
```

---

# 94. Common operational mistakes

## Mistake 1: Opening SSH despite Session Manager availability

This preserves unnecessary attack surface.

## Mistake 2: Giving all engineers unrestricted `ssm:StartSession`

Production access should be resource-scoped and preferably just-in-time.

## Mistake 3: Assuming port-forwarding sessions are command-logged

The tunnel content is not recorded by Session Manager. ([AWS Documentation][2])

## Mistake 4: Running untested commands against tag-selected production fleets

A mistyped tag scope can affect hundreds of nodes.

## Mistake 5: Patching every server simultaneously

This can cause complete service outage.

## Mistake 6: Treating patch installation as application validation

The operating system can patch successfully while the application fails afterward.

## Mistake 7: Auto-remediating without rollback

Automation can spread a bad change faster than a human.

## Mistake 8: Using `latest` package versions in production

Unreviewed upgrades can introduce incidents.

## Mistake 9: Collecting excessive Inventory data

Broad file and registry collection can add unnecessary processing and storage.

## Mistake 10: Using interactive sessions for repeatable operations

Repeatable actions should become reviewed documents or Automation runbooks.

---

# 95. Production design for your TodoApp

```text
TodoApp Production account
│
├── Private EC2 or ECS hosts
│   ├── No public administration IPs
│   ├── SSM Agent
│   ├── CloudWatch Agent
│   └── Systems Manager IAM role
│
├── Systems Manager
│   ├── Session Manager with JIT access
│   ├── Run Command diagnostics
│   ├── Automation deployment runbooks
│   ├── State Manager agent enforcement
│   ├── Patch Manager wave A and B
│   ├── Inventory collection
│   └── OpsCenter remediation
│
├── Maintenance Windows
│   └── Saturday patch period
│
├── Change Calendar
│   └── Block production changes during peak periods
│
└── Central Operations account
    ├── Explorer
    ├── Quick Setup
    ├── Cross-account Automation
    └── Compliance reporting
```

---

# 96. TodoApp incident-remediation example

Scenario:

```text
CloudWatch:
Todo API disk usage > 90%
```

Flow:

```text
CloudWatch Alarm
      |
      v
EventBridge
      |
      v
OpsItem created
      |
      v
Automation runbook:
TodoApp-CleanOldReleases
      |
      ├── Verify /releases path
      ├── Keep latest five releases
      ├── Delete older release artifacts
      ├── Remove old logs
      ├── Check free disk space
      └── Validate application
              |
              v
         Resolve OpsItem
```

Safety controls:

```text
Never delete current symlink target.
Never delete active PM2 release.
Stop if free space does not improve.
Stop after configured maximum deletion.
Record deleted paths.
```

---

# 97. Production security checklist

```text
[ ] Managed nodes have no unnecessary public IP
[ ] Inbound SSH and RDP are closed
[ ] SSM Agent is automatically updated
[ ] Default Host Management or instance roles are configured
[ ] Systems Manager uses private endpoints where appropriate
[ ] Session access is tag-scoped
[ ] Production access is just-in-time
[ ] Normal shell sessions are logged
[ ] Session-log storage is encrypted
[ ] CloudTrail captures session APIs
[ ] Port-forwarding limitations are documented
[ ] Run Command uses rate controls
[ ] Command output is centralized
[ ] Custom SSM documents are version controlled
[ ] Automation uses dedicated execution roles
[ ] Automation error thresholds are configured
[ ] State Manager associations are monitored
[ ] Patch policies use staged waves
[ ] Reboot behavior is defined
[ ] Maintenance Windows protect disruptive work
[ ] Change Calendar blackout periods exist
[ ] Inventory collection is intentionally scoped
[ ] Hybrid activations are short-lived and protected
[ ] Quick Setup configurations are centrally owned
[ ] OpsItems link to runbooks
[ ] Emergency access has a documented process
```

---

# 98. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Systems Manager:
Centralized server and operations management.

Session Manager:
Secure server access without inbound SSH.

Parameter Store:
Central configuration storage.

Patch Manager:
Automated patching.
```

## Solutions Architect Associate

Understand:

```text
Managed nodes
SSM Agent
IAM instance profiles
Private VPC endpoints
Session Manager
Run Command
Patch Manager
Maintenance Windows
Parameter Store
Hybrid activations
```

## DevOps Engineer Professional

Understand:

```text
Automation runbooks
State Manager associations
Patch policies
Multi-account Quick Setup
Rate controls
Change Calendar
Change Manager
Inventory resource data sync
OpsCenter
Just-in-time access
Cross-account remediation
```

---

# 99. Interview questions

## Question 1: What is AWS Systems Manager?

**Answer:**

It is a centralized operations platform for viewing, accessing, configuring, patching and automating managed nodes across AWS, on-premises and multicloud environments.

## Question 2: What is a managed node?

**Answer:**

It is an EC2 instance or supported non-EC2 machine with SSM Agent, appropriate permissions and network connectivity to Systems Manager.

## Question 3: Why use Session Manager instead of SSH?

**Answer:**

Session Manager avoids inbound port 22, bastion hosts and SSH-key distribution while providing IAM authorization, CloudTrail auditing and supported session logging.

## Question 4: Does Session Manager require a public IP?

**Answer:**

No. A private node can use NAT connectivity or Systems Manager interface VPC endpoints.

## Question 5: Can port-forwarding session content be logged?

**Answer:**

No. Session Manager records the session API activity but cannot record the encrypted traffic carried inside SSH or port-forwarding tunnels.

## Question 6: What is Run Command?

**Answer:**

It remotely executes noninteractive administrative commands across one or many managed nodes.

## Question 7: What is the difference between Run Command and Automation?

**Answer:**

Run Command executes commands on managed operating systems. Automation orchestrates multi-step workflows involving AWS APIs, resources, scripts, approvals and Run Command.

## Question 8: What are rate controls?

**Answer:**

Concurrency limits how many targets run simultaneously, while an error threshold stops expanding the operation after too many failures.

## Question 9: What is State Manager?

**Answer:**

State Manager continuously or periodically keeps managed nodes and supported AWS resources in a defined desired state through associations.

## Question 10: What is a State Manager association?

**Answer:**

It connects an SSM document with targets, parameters, a schedule and optional rate controls.

## Question 11: What is Patch Manager?

**Answer:**

It scans and installs approved operating-system and application patches on Systems Manager managed nodes.

## Question 12: What is a patch baseline?

**Answer:**

It defines which patches are approved or rejected and the rules controlling when patches become approved.

## Question 13: What is a patch policy?

**Answer:**

It is a Quick Setup configuration that centrally defines patch schedules, baselines, targets and compliance across accounts and Regions.

## Question 14: What is a Maintenance Window?

**Answer:**

It defines an approved scheduled period when potentially disruptive operational tasks may run.

## Question 15: What is Systems Manager Inventory?

**Answer:**

It collects operating-system, software, service, network and custom metadata from managed nodes.

## Question 16: What is Fleet Manager?

**Answer:**

It is a console interface for viewing and remotely managing nodes, including processes, filesystems, users, performance and supported Windows RDP sessions.

## Question 17: What is OpsCenter?

**Answer:**

It provides a centralized place to investigate and remediate operational issues represented as OpsItems.

## Question 18: What is a hybrid activation?

**Answer:**

It provides temporary registration credentials and an IAM service-role association for enrolling non-EC2 machines as Systems Manager managed nodes.

## Question 19: What is Change Calendar?

**Answer:**

It defines open and closed periods during which controlled operational changes are allowed or blocked.

## Question 20: How would you patch a production fleet safely?

**Answer:**

Scan first, test patches in development and staging, divide production into patch waves, use Maintenance Windows and rate controls, drain load-balanced nodes, validate after each patch and retain a rollback or replacement strategy.

---

# 100. Never-forget revision

```text
SSM Agent:
Software connecting a node to Systems Manager.

Managed node:
Machine registered and online in Systems Manager.

Session Manager:
Interactive IAM-controlled node access.

Just-in-time access:
Temporary approved production access.

Run Command:
Noninteractive commands across nodes.

SSM document:
Reusable definition of an operation.

Automation:
Multi-step AWS operational workflow.

State Manager:
Maintains desired configuration.

Association:
Document plus targets, parameters and schedule.

Patch Manager:
Scans and installs approved patches.

Patch baseline:
Patch approval and rejection rules.

Patch policy:
Central account and Region patch configuration.

Maintenance Window:
Approved disruptive-operation schedule.

Inventory:
Node software and configuration metadata.

Fleet Manager:
Graphical fleet-management interface.

Distributor:
Versioned software-package deployment.

OpsCenter:
Operational issue investigation and remediation.

Change Calendar:
Open and closed change periods.

Change Manager:
Request, approve and implement changes.

Hybrid activation:
Registers non-EC2 machines.
```

## One-line memory trick

```text
Connect with Session Manager.
Execute with Run Command.
Orchestrate with Automation.
Enforce with State Manager.
Patch with Patch Manager.
Schedule with Maintenance Windows.
Discover with Inventory.
Remediate with OpsCenter.
```

## Lesson 39 outcome

You can now design operations where:

```text
Private EC2 instance needs administration
    → Session Manager connects without inbound SSH.

Production access must be temporary
    → Just-in-time approval grants time-bound access.

A diagnostic command must run on 100 servers
    → Run Command uses tags and rate controls.

A complex recovery procedure is repeated
    → Automation turns it into a controlled runbook.

CloudWatch Agent must exist everywhere
    → State Manager enforces the package.

Production nodes need monthly security updates
    → Patch policies and Maintenance Windows roll out in waves.

Security team needs software inventory
    → Inventory aggregates metadata centrally.

CloudWatch raises an operational issue
    → OpsCenter links the resource, alarm and remediation runbook.

On-premises servers need the same management
    → Hybrid activations register them as managed nodes.
```

**Next lesson: Lesson 40 — Amazon EventBridge, SNS, SQS, Step Functions and production event-driven architecture: queues, pub/sub, retries, dead-letter queues, ordering, idempotency and workflow orchestration.**

[1]: https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html?utm_source=chatgpt.com "What is AWS Systems Manager? - ..."
[2]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html?utm_source=chatgpt.com "AWS Systems Manager Session Manager"
[3]: https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager-managed-nodes.html?utm_source=chatgpt.com "Working with managed nodes"
[4]: https://docs.aws.amazon.com/systems-manager/latest/userguide/manually-install-ssm-agent-linux.html?utm_source=chatgpt.com "Manually installing and uninstalling SSM Agent on EC2 ..."
[5]: https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-permissions.html?utm_source=chatgpt.com "Configure instance permissions required for Systems Manager"
[6]: https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html?utm_source=chatgpt.com "Improve the security of EC2 instances by using VPC ..."
[7]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html?utm_source=chatgpt.com "Start a session - AWS Systems Manager"
[8]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-just-in-time-node-access.html?utm_source=chatgpt.com "Just-in-time node access using Systems Manager"
[9]: https://docs.aws.amazon.com/systems-manager/latest/userguide/just-in-time-node-access-faq.html?utm_source=chatgpt.com "Just-in-time node access frequently asked questions"
[10]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-just-in-time-node-access-setting-up.html?utm_source=chatgpt.com "Setting up just-in-time access with Systems Manager"
[11]: https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html?utm_source=chatgpt.com "AWS Systems Manager Run Command"
[12]: https://docs.aws.amazon.com/systems-manager/latest/userguide/documents.html?utm_source=chatgpt.com "AWS Systems Manager Documents"
[13]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html?utm_source=chatgpt.com "AWS Systems Manager Automation"
[14]: https://docs.aws.amazon.com/systems-manager/latest/userguide/running-automations-scale.html?utm_source=chatgpt.com "Run automated operations at scale - AWS Systems Manager"
[15]: https://docs.aws.amazon.com/systems-manager/latest/userguide/running-automations-multiple-accounts-regions.html?utm_source=chatgpt.com "Running automations in multiple AWS Regions and accounts"
[16]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state.html?utm_source=chatgpt.com "AWS Systems Manager State Manager"
[17]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state-manager-targets-and-rate-controls.html?utm_source=chatgpt.com "Understanding targets and rate controls in State Manager ..."
[18]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager.html?utm_source=chatgpt.com "AWS Systems Manager Patch Manager"
[19]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-policies.html?utm_source=chatgpt.com "Patch policy configurations in Quick Setup"
[20]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-tag-a-patch-group.html?utm_source=chatgpt.com "Creating and managing patch groups - AWS Documentation"
[21]: https://docs.aws.amazon.com/systems-manager/latest/userguide/quick-setup-patch-manager.html?utm_source=chatgpt.com "Configure patching for instances in an organization using a ..."
[22]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-prerequisites.html?utm_source=chatgpt.com "Patch Manager prerequisites"
[23]: https://docs.aws.amazon.com/systems-manager/latest/userguide/maintenance-windows.html?utm_source=chatgpt.com "AWS Systems Manager Maintenance Windows"
[24]: https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-maintenance-assign-tasks.html?utm_source=chatgpt.com "Assign tasks to a maintenance window using the console"
[25]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-inventory.html?utm_source=chatgpt.com "AWS Systems Manager Inventory"
[26]: https://docs.aws.amazon.com/systems-manager/latest/userguide/inventory-create-resource-data-sync.html?utm_source=chatgpt.com "Creating a resource data sync for Inventory"
[27]: https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager.html?utm_source=chatgpt.com "AWS Systems Manager Fleet Manager"
[28]: https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager-monitoring-node-performance.html?utm_source=chatgpt.com "Monitoring managed node performance - AWS Documentation"
[29]: https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager-remote-desktop-connections.html?utm_source=chatgpt.com "Connecting to a Windows Server managed instance using ..."
[30]: https://docs.aws.amazon.com/systems-manager/latest/userguide/distributor.html?utm_source=chatgpt.com "AWS Systems Manager Distributor"
[31]: https://docs.aws.amazon.com/systems-manager/latest/userguide/distributor-working-with-packages-deploy.html?utm_source=chatgpt.com "Install or update Distributor packages - AWS Systems Manager"
[32]: https://docs.aws.amazon.com/systems-manager/latest/userguide/OpsCenter.html?utm_source=chatgpt.com "AWS Systems Manager OpsCenter"
[33]: https://docs.aws.amazon.com/incident-manager/latest/userguide/incident-manager-availability-change.html?utm_source=chatgpt.com "AWS Systems Manager Incident Manager availability change"
[34]: https://docs.aws.amazon.com/systems-manager/latest/userguide/Explorer.html?utm_source=chatgpt.com "AWS Systems Manager Explorer"
[35]: https://docs.aws.amazon.com/systems-manager/latest/userguide/Explorer-resource-data-sync-understanding.html?utm_source=chatgpt.com "Understanding resource data syncs for Explorer"
[36]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-change-calendar.html?utm_source=chatgpt.com "AWS Systems Manager Change Calendar"
[37]: https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-change-calendar-integration.html?utm_source=chatgpt.com "Implement change controls for Automation - AWS Systems ..."
[38]: https://docs.aws.amazon.com/systems-manager/latest/userguide/change-manager.html?utm_source=chatgpt.com "AWS Systems Manager Change Manager"
[39]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html?utm_source=chatgpt.com "AWS Systems Manager Parameter Store"
[40]: https://docs.aws.amazon.com/systems-manager/latest/userguide/activations.html?utm_source=chatgpt.com "AWS Systems Manager Hybrid Activations"
[41]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-instance-profile.html?utm_source=chatgpt.com "Verify or add instance permissions for Session Manager"
[42]: https://docs.aws.amazon.com/systems-manager/latest/userguide/hybrid-activation-managed-nodes.html?utm_source=chatgpt.com "Create a hybrid activation to register nodes with Systems ..."
[43]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-quick-setup.html?utm_source=chatgpt.com "AWS Systems Manager Quick Setup"
[44]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-troubleshooting.html?utm_source=chatgpt.com "Troubleshooting Session Manager - AWS Documentation"
[45]: https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-update-or-delete-a-patch-baseline.html?utm_source=chatgpt.com "Updating or deleting a custom patch baseline"
[46]: https://docs.aws.amazon.com/systems-manager/latest/userguide/troubleshooting-maintenance-windows.html?utm_source=chatgpt.com "Troubleshooting maintenance windows"
