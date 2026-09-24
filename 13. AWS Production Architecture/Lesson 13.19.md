# AWS Masterclass — Lesson 18

## Cost Optimization and FinOps — Budgets, Cost Explorer, Tags, CUR/Data Exports, Savings Plans, Right-Sizing, Cleanup, and Cost Governance

Today’s lesson is about preventing this nightmare:

```text
You created a small lab.
You forgot NAT Gateway, ALB, EC2, EBS, snapshots, logs, or public IPv4.
After a few days, the bill is much higher than expected.
```

Cost optimization is not just “make AWS cheap.” The AWS Well-Architected Cost Optimization pillar defines it as running systems to deliver business value at the lowest price point, while still meeting functional requirements. ([AWS Documentation][1])

---

## 1. What is FinOps?

FinOps means cloud financial operations.

Simple meaning:

```text
FinOps = engineering + finance + product teams working together
to understand, control, optimize, and forecast cloud cost.
```

AWS calls this Cloud Financial Management, and describes it as managing cost transparency, control, planning, and optimization across AWS environments. ([AWS Documentation][2])

FinOps is not only finance work.

```text
Finance:
  What is our budget?

Engineering:
  Why did this resource cost increase?

Product:
  Is this feature worth the infrastructure cost?

DevOps/SRE:
  Can we reduce waste without hurting reliability?
```

Good DevOps engineers do not say:

```text
Cost is finance team's problem.
```

They say:

```text
Cost is an architecture, automation, tagging, observability, and governance problem.
```

---

## 2. AWS cost mental model

AWS cost usually comes from four things:

```text
Running time:
  EC2, RDS, NAT Gateway, ALB, ECS/Fargate

Storage:
  S3, EBS, EFS, snapshots, CloudWatch Logs

Requests/operations:
  Lambda requests, API Gateway requests, S3 requests, DynamoDB reads/writes

Data transfer:
  internet egress, NAT Gateway data processing, cross-AZ traffic, cross-Region traffic
```

Beginner mistake:

```text
I stopped EC2, so cost is zero.
```

Reality:

```text
Stopped EC2:
  no instance compute charge

Still possible charges:
  EBS volumes
  Elastic IP if idle/associated pattern charges apply
  snapshots
  load balancer
  NAT Gateway
  CloudWatch Logs
  RDS
  public IPv4
```

Production thinking:

```text
Every AWS resource should have:
  owner
  environment
  purpose
  lifecycle
  budget visibility
  cleanup plan
```

---

## 3. Core AWS cost tools

| Need                               | AWS tool                              |
| ---------------------------------- | ------------------------------------- |
| Alert when spend crosses threshold | AWS Budgets                           |
| Analyze historical spend           | Cost Explorer                         |
| Detect unusual spend               | Cost Anomaly Detection                |
| Detailed billing dataset           | Cost and Usage Reports / Data Exports |
| Prioritize savings opportunities   | Cost Optimization Hub                 |
| Right-size compute                 | Compute Optimizer                     |
| Allocate cost by team/app          | Cost allocation tags                  |
| Forecast and purchase commitments  | Savings Plans / Reserved Instances    |
| Estimate before building           | AWS Pricing Calculator                |

AWS Billing and Cost Management now includes cost analysis, Data Exports, Cost Explorer, Cost Anomaly Detection, Cost Optimization Hub, budgets, purchasing tools, and billing preferences in one broader cost-management area. ([AWS Documentation][3])

---

## 4. AWS Budgets

AWS Budgets lets you track cost, usage, reservation/Savings Plan coverage, and receive alerts when thresholds are crossed. AWS notes that budget status is updated several times a day, but costs can continue changing before or after notifications arrive, so budgets are alerts, not hard spend-stoppers. ([AWS Documentation][4])

Common budget types:

```text
Cost budget:
  alert when monthly spend crosses a $ threshold

Usage budget:
  alert when usage crosses a threshold

Savings Plans budget:
  track utilization or coverage

Reservation budget:
  track RI utilization or coverage
```

Beginner setup:

```text
Monthly cost budget:
  $5 or $10 for labs

Alert thresholds:
  50%
  80%
  100%
```

For your AWS labs, a practical budget is:

```text
Budget name:
  aws-masterclass-monthly-lab-budget

Amount:
  $5

Alert:
  50%, 80%, 100%

Email:
  your email address
```

Important:

```text
AWS Budgets tells you cost is increasing.
It does not automatically delete resources unless you configure specific budget actions.
```

---

## 5. Cost Explorer

Cost Explorer is for analyzing and visualizing your AWS cost and usage. AWS documentation says Cost Explorer can show up to the last 13 months of data, forecast likely spend for the next 18 months, and provide Reserved Instance purchase recommendations. ([AWS Documentation][5])

Use Cost Explorer to answer:

```text
Which service cost the most this month?
Which account spent the most?
Which region is expensive?
Which tag value owns this spend?
Why did cost increase yesterday?
How much did NAT Gateway cost?
How much did EC2 cost by instance family?
```

Good filters:

```text
Service:
  EC2, RDS, NAT Gateway, CloudWatch, S3

Region:
  ap-south-1, us-east-1

Linked account:
  dev, staging, prod

Tag:
  Project, Environment, Owner

Usage type:
  data transfer, NAT data processing, instance-hours
```

Production rule:

```text
Cost Explorer is for investigation.
Budgets are for alerting.
CUR/Data Exports are for deep reporting.
Tags are for allocation.
```

---

## 6. Cost Anomaly Detection

Cost Anomaly Detection uses machine learning to detect unusual spend patterns and can alert by email or SNS. AWS says it can investigate root causes across dimensions such as service, account, Region, and usage type. ([AWS Documentation][6])

Use it for:

```text
sudden NAT Gateway spike
unexpected EC2 spend
new expensive service usage
runaway CloudWatch Logs ingestion
unexpected cross-region traffic
```

Important limitation:

```text
Anomaly detection is not instant.
You still need budgets and cleanup automation.
```

---

## 7. Cost allocation tags

Tags are how you make AWS cost understandable.

Without tags:

```text
EC2 cost:
  $124.32

Question:
  who owns it?
  which app?
  dev or prod?
```

With tags:

```text
Project = todo-app
Environment = dev
Owner = vivek
CostCenter = learning
ManagedBy = terraform
```

Then you can see:

```text
todo-app dev cost:
  $18.42
```

AWS supports user-defined cost allocation tags. After you apply tags to resources and activate the tag keys in Billing and Cost Management, AWS can include cost grouped by those tags in cost allocation reporting. ([AWS Documentation][7])

Recommended AWS tags:

```text
Project:
  todo-app

Environment:
  dev / staging / prod

Owner:
  vivek

ManagedBy:
  terraform / ansible / console / pipeline

CostCenter:
  learning / platform / product-a

Application:
  todo-api / frontend / observability

DataClassification:
  public / internal / confidential

AutoDelete:
  true / false

ExpiresOn:
  2026-07-31
```

Never rely only on resource names.

```text
Name tag is useful for humans.
Cost allocation tags are useful for billing and governance.
```

---

## 8. CUR and Data Exports

CUR means Cost and Usage Report.

AWS says Cost and Usage Reports contain the most comprehensive set of AWS cost and usage data available. ([AWS Documentation][8])

AWS Data Exports is now the recommended path for CUR 2.0 exports, and AWS documentation says CUR 2.0 is the new recommended way to receive detailed cost and usage data. ([AWS Documentation][9])

Use CUR/Data Exports when:

```text
Cost Explorer is not detailed enough.
You need account/team chargeback.
You need BI dashboards.
You want Athena/QuickSight reporting.
You need daily/hourly line-item cost analysis.
You need ECS/EKS split cost allocation.
```

Architecture:

```text
AWS Billing Data
  ↓
Data Exports / CUR 2.0
  ↓
S3 bucket
  ↓
Athena / QuickSight / dashboards
  ↓
Finance + Engineering reporting
```

For ECS/EKS, split cost allocation data can add container-level cost visibility for ECS tasks and EKS pods in CUR. ([AWS Documentation][10])

---

## 9. Cost Optimization Hub

Cost Optimization Hub consolidates and prioritizes savings recommendations across accounts and Regions. AWS says it helps track cost efficiency and view recommendations for resources such as EC2, RDS, OpenSearch, and other supported services. ([AWS Documentation][11])

Use it to find:

```text
idle resources
right-sizing opportunities
Savings Plans opportunities
reservation opportunities
storage cleanup opportunities
```

Practical DevOps workflow:

```text
Every week:
  open Cost Optimization Hub
  export/top-list savings opportunities
  classify safe vs risky
  create Jira/GitHub issues
  implement using IaC
  measure savings next month
```

---

## 10. Compute Optimizer

Compute Optimizer analyzes resource configuration and utilization metrics to generate optimization recommendations for resources such as EC2 instances, Auto Scaling groups, Lambda functions, EBS volumes, and ECS services on Fargate. ([AWS Documentation][12])

It can help answer:

```text
Is this EC2 instance oversized?
Is this Lambda memory too high or too low?
Is this EBS volume over-provisioned?
Is this ECS Fargate service under/over-provisioned?
```

Right-sizing example:

```text
Current:
  m5.large
  average CPU 5%
  memory low

Recommendation:
  smaller instance family/size

Action:
  test in staging
  update Terraform
  deploy during maintenance window
  monitor latency/errors
```

Important:

```text
Do not blindly apply recommendations.
Check production traffic patterns, memory, burst needs, peak hours, and SLOs.
```

---

## 11. Savings Plans

Savings Plans are commitment-based discounts. Compute Savings Plans apply to eligible compute usage across EC2, Lambda, and Fargate. ([AWS Documentation][13])

Simple meaning:

```text
You commit to spend a certain $/hour for 1 or 3 years.
AWS gives discounted pricing for eligible usage.
```

Example learning block:

```text
On-Demand:
  flexible, no commitment

Savings Plan:
  commit to $2/hour of compute usage
  receive lower rates for eligible compute
```

Savings Plans are good when:

```text
baseline compute usage is steady
production workloads run all month
you understand usage pattern
you do not expect major architecture changes soon
```

Avoid buying too early when:

```text
you are still experimenting
usage is unstable
you might shut down workloads
you do not understand monthly baseline
```

AWS documents that Compute Savings Plans are more flexible than EC2 Reserved Instances because they are based on a committed spend amount rather than specific instance configurations. ([AWS Documentation][14])

---

## 12. Reserved Instances

Reserved Instances are older reservation-style pricing commitments, commonly associated with EC2, RDS, Redshift, and other services.

Simple meaning:

```text
Reserved Instance:
  discount in exchange for reserving a specific usage pattern
```

Savings Plans vs Reserved Instances:

| Feature          | Savings Plans                     | Reserved Instances                      |
| ---------------- | --------------------------------- | --------------------------------------- |
| Commitment basis | $/hour spend                      | instance/service reservation attributes |
| Flexibility      | usually more flexible for compute | often more specific                     |
| Best for         | steady compute usage              | predictable instance/database usage     |
| Risk             | overcommitment                    | wrong family/region/term/payment option |

Rule:

```text
First optimize waste.
Then right-size.
Then buy commitments.
```

Do not buy Savings Plans or RIs to cover waste.

---

## 13. Biggest AWS cost traps

### Trap 1 — NAT Gateway

NAT Gateway is useful but can become expensive because it has hourly charges and data processing/data transfer dimensions. AWS has a dedicated NAT Gateway pricing page and recommends strategies to reduce data transfer charges, such as keeping traffic in the same AZ where possible and using VPC endpoints for AWS services when appropriate. ([AWS Documentation][15])

Common mistake:

```text
Private EC2 downloads many GB from S3 through NAT Gateway.
```

Better:

```text
Use S3 Gateway VPC Endpoint.
Traffic to S3 avoids NAT Gateway data processing path.
```

Other NAT cost traps:

```text
one NAT Gateway forgotten after lab
per-AZ NAT Gateways in dev
ECR pulls through NAT instead of VPC endpoints
CloudWatch Logs traffic through NAT
cross-AZ NAT usage
```

---

### Trap 2 — Load balancers

ALB/NLB can cost even when traffic is low.

Mistake:

```text
Create ALB for one-hour lab.
Forget it for 10 days.
```

Fix:

```text
Tag ALBs.
Delete after lab.
Use scripts to list old ALBs.
Use Terraform destroy.
```

---

### Trap 3 — EBS volumes and snapshots

Stopped EC2 instances can still have EBS volumes.

Deleted EC2 instances can leave snapshots.

Mistake:

```text
Terminate EC2, but keep old snapshots forever.
```

Fix:

```text
List unattached EBS volumes.
Review old snapshots.
Apply lifecycle process.
Use tags and retention rules.
```

Compute Optimizer even has recommended actions such as snapshotting and deleting EBS volumes that are unattached for 32 or more days. ([AWS Documentation][16])

---

### Trap 4 — CloudWatch Logs

CloudWatch Logs keeps log groups indefinitely by default unless you set retention. ([AWS Documentation][17])

Mistake:

```text
Lambda logs
ECS logs
VPC Flow Logs
ALB logs
debug logs

Retention:
  Never expire
```

Fix:

```text
dev logs:
  1–7 days

staging:
  14–30 days

prod:
  30–365 days depending compliance
```

---

### Trap 5 — S3 without lifecycle

S3 is low-cost compared to many services, but large buckets, old logs, old artifacts, versions, and incomplete multipart uploads can accumulate.

S3 Lifecycle rules can transition objects to lower-cost storage classes, archive them, or delete them. ([AWS Documentation][18])

Good lifecycle examples:

```text
ALB logs:
  transition after 30 days
  expire after 180 days

build artifacts:
  expire after 30–90 days

old object versions:
  expire noncurrent versions after 7–30 days

incomplete multipart uploads:
  abort after 1–7 days
```

---

### Trap 6 — Idle RDS

RDS can be one of the easiest ways to create surprise cost.

Mistake:

```text
Create RDS for testing.
Forget it running.
Also keep snapshots.
```

Fix:

```text
Use small dev DB.
Stop eligible dev DB when not needed.
Use DynamoDB/serverless for low-cost labs where possible.
Delete lab DB after use.
Use final snapshot only if needed.
```

---

### Trap 7 — Public IPv4

Public IPv4 addresses are no longer “invisible” from a cost perspective in many AWS setups.

Good habit:

```text
Do not give public IPs to private app servers.
Use ALB, SSM Session Manager, private subnets, NAT/endpoints where needed.
Release unused Elastic IPs.
```

---

## 14. FinOps lifecycle

Think in this loop:

```text
Inform:
  make cost visible

Optimize:
  remove waste and right-size

Operate:
  make cost governance continuous
```

Practical weekly FinOps routine:

```text
Monday:
  review Cost Explorer service-level spend

Tuesday:
  review Cost Optimization Hub/Compute Optimizer

Wednesday:
  create cleanup/right-size pull requests

Thursday:
  apply safe cleanup in dev/staging

Friday:
  report savings and risky items
```

Production rule:

```text
Cost optimization should become a sprint habit,
not a panic reaction after the bill arrives.
```

---

## 15. Cost governance by environment

| Environment      | Cost rule                                                   |
| ---------------- | ----------------------------------------------------------- |
| Sandbox          | strict budgets, auto-cleanup, service restrictions          |
| Dev              | small instances, short retention, no Multi-AZ unless needed |
| Staging          | production-like but scheduled down where possible           |
| Prod             | optimize carefully, prioritize reliability and SLOs         |
| Shared services  | chargeback/showback, owner required                         |
| Security/logging | optimize retention but do not break audit requirements      |

Never optimize production blindly.

```text
Bad:
  reduce RDS size during business hours without testing

Good:
  analyze metrics
  test in staging
  plan change window
  update IaC
  monitor after change
```

---

## 16. Hands-On Lab 18A — Read-Only Cost Visibility With AWS CLI

This lab does not create workload resources.

It reads cost data. Billing/Cost Explorer permissions are required.

Cost note:

```text
Use only a few API calls.
For daily learning, the console is safer.
```

### Step 1 — Set dates

```bash
START_DATE="$(date -u +%Y-%m-01)"
END_DATE="$(date -u -d tomorrow +%Y-%m-%d)"

echo "START_DATE=$START_DATE"
echo "END_DATE=$END_DATE"
```

### Step 2 — Cost by service this month

```bash
aws ce get-cost-and-usage \
  --region us-east-1 \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[].{Service:Keys[0],Cost:Metrics.UnblendedCost.Amount,Unit:Metrics.UnblendedCost.Unit}' \
  --output table
```

### Step 3 — Cost by region

```bash
aws ce get-cost-and-usage \
  --region us-east-1 \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=REGION \
  --query 'ResultsByTime[0].Groups[].{Region:Keys[0],Cost:Metrics.UnblendedCost.Amount,Unit:Metrics.UnblendedCost.Unit}' \
  --output table
```

### Step 4 — Daily cost trend

```bash
aws ce get-cost-and-usage \
  --region us-east-1 \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity DAILY \
  --metrics UnblendedCost \
  --query 'ResultsByTime[].{Date:TimePeriod.Start,Cost:Total.UnblendedCost.Amount,Unit:Total.UnblendedCost.Unit}' \
  --output table
```

If you get `AccessDenied`, your IAM identity needs Billing/Cost Explorer permissions.

---

## 17. Hands-On Lab 18B — Create a Local FinOps Design Pack

This lab creates local files only.

No AWS resources.

```bash
mkdir -p ~/aws-masterclass/finops/{notes,scripts,policies,runbooks,reports}
cd ~/aws-masterclass/finops
```

### Step 1 — Create tagging standard

```bash
cat > notes/tagging-standard.md <<'EOF'
# AWS Tagging Standard

## Required tags

Project:
  application or project name

Environment:
  dev, staging, prod, sandbox

Owner:
  person/team responsible

ManagedBy:
  terraform, cloudformation, console, pipeline

CostCenter:
  finance/cost allocation code

Application:
  service or app name

DataClassification:
  public, internal, confidential, restricted

AutoDelete:
  true or false

ExpiresOn:
  YYYY-MM-DD for temporary resources

## Example

Project=todo-app
Environment=dev
Owner=vivek
ManagedBy=terraform
CostCenter=learning
Application=todo-api
DataClassification=internal
AutoDelete=true
ExpiresOn=2026-07-31
EOF
```

### Step 2 — Create cost review checklist

```bash
cat > reports/weekly-cost-review.md <<'EOF'
# Weekly AWS Cost Review

## Questions

1. Which service cost increased this week?
2. Which account or environment owns the increase?
3. Which region owns the increase?
4. Which tag/project owns the increase?
5. Is the spend expected?
6. Is the resource still needed?
7. Can it be deleted, stopped, right-sized, scheduled, or moved to a cheaper tier?
8. Does IaC need updating?
9. Does a budget/anomaly alert need tuning?
10. What savings were achieved?

## Services to check

- EC2
- EBS
- NAT Gateway
- ALB/NLB
- RDS
- S3
- CloudWatch Logs
- Lambda
- API Gateway
- ECS/Fargate
- DynamoDB
- CloudFront

## Output

Findings:
Actions:
Owner:
Due date:
Expected monthly savings:
Risk:
EOF
```

### Step 3 — Create idle resource scanner script

This script is read-only.

```bash
cat > scripts/aws-cost-scan.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

echo "===== AWS Cost Scan: $AWS_REGION ====="

echo
echo "Caller:"
aws sts get-caller-identity

echo
echo "Running EC2 instances:"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Type:InstanceType,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value,Project:Tags[?Key==`Project`]|[0].Value,Owner:Tags[?Key==`Owner`]|[0].Value}' \
  --output table || true

echo
echo "Unattached EBS volumes:"
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[].{VolumeId:VolumeId,SizeGiB:Size,Type:VolumeType,Created:CreateTime,Name:Tags[?Key==`Name`]|[0].Value,Project:Tags[?Key==`Project`]|[0].Value}' \
  --output table || true

echo
echo "Elastic IPs:"
aws ec2 describe-addresses \
  --query 'Addresses[].{PublicIp:PublicIp,AllocationId:AllocationId,AssociationId:AssociationId,InstanceId:InstanceId,NetworkInterfaceId:NetworkInterfaceId}' \
  --output table || true

echo
echo "NAT Gateways:"
aws ec2 describe-nat-gateways \
  --filter Name=state,Values=available,pending \
  --query 'NatGateways[].{NatGatewayId:NatGatewayId,State:State,VpcId:VpcId,SubnetId:SubnetId,Created:CreateTime}' \
  --output table || true

echo
echo "Load balancers:"
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].{Name:LoadBalancerName,Type:Type,Scheme:Scheme,State:State.Code,DNS:DNSName}' \
  --output table || true

echo
echo "RDS instances:"
aws rds describe-db-instances \
  --query 'DBInstances[].{DB:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass,Engine:Engine,MultiAZ:MultiAZ,Public:PubliclyAccessible}' \
  --output table || true

echo
echo "CloudWatch log groups without short retention:"
aws logs describe-log-groups \
  --query 'logGroups[].{Name:logGroupName,Retention:retentionInDays,StoredBytes:storedBytes}' \
  --output table || true

echo
echo "Scan complete. Review before deleting anything."
EOF

chmod +x scripts/aws-cost-scan.sh
```

Run:

```bash
AWS_REGION=ap-south-1 ./scripts/aws-cost-scan.sh
```

---

## 18. Optional Lab 18C — Create a $5 Monthly AWS Budget

This creates a billing alert resource. Use your real email.

```bash
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUDGET_NAME="aws-masterclass-monthly-lab-budget"
EMAIL="your-email@example.com"
```

Create budget JSON:

```bash
cat > /tmp/aws-masterclass-budget.json <<EOF
{
  "BudgetName": "$BUDGET_NAME",
  "BudgetLimit": {
    "Amount": "5",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false,
    "IncludeRefund": true,
    "IncludeCredit": true,
    "IncludeUpfront": true,
    "IncludeRecurring": true,
    "IncludeOtherSubscription": true,
    "IncludeSupport": true,
    "IncludeDiscount": true,
    "UseAmortized": false
  }
}
EOF
```

Create notifications:

```bash
cat > /tmp/aws-masterclass-budget-notifications.json <<EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 50,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$EMAIL"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$EMAIL"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$EMAIL"
      }
    ]
  }
]
EOF
```

Create budget:

```bash
aws budgets create-budget \
  --region us-east-1 \
  --account-id "$ACCOUNT_ID" \
  --budget file:///tmp/aws-masterclass-budget.json \
  --notifications-with-subscribers file:///tmp/aws-masterclass-budget-notifications.json
```

Verify:

```bash
aws budgets describe-budget \
  --region us-east-1 \
  --account-id "$ACCOUNT_ID" \
  --budget-name "$BUDGET_NAME"
```

Delete later only if you intentionally no longer need the alert:

```bash
aws budgets delete-budget \
  --region us-east-1 \
  --account-id "$ACCOUNT_ID" \
  --budget-name "$BUDGET_NAME"
```

For learning accounts, I recommend keeping a small monthly budget alert active.

---

## 19. Optional Lab 18D — Set CloudWatch Log Retention

CloudWatch Logs retains logs indefinitely by default unless changed. ([AWS Documentation][17])

Set retention for a dev log group:

```bash
LOG_GROUP="/aws/lambda/example-dev-function"

aws logs put-retention-policy \
  --region ap-south-1 \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 7
```

List log groups with no retention:

```bash
aws logs describe-log-groups \
  --region ap-south-1 \
  --query 'logGroups[?retentionInDays==null].{Name:logGroupName,StoredBytes:storedBytes}' \
  --output table
```

Production rule:

```text
Do not blindly set short retention for security/audit logs.
Use different retention for dev, staging, prod, and compliance logs.
```

---

## 20. Optional Lab 18E — S3 Lifecycle Rule for Lab Buckets

S3 Lifecycle rules can transition, archive, or delete objects. ([AWS Documentation][18])

Example for a lab bucket:

```bash
BUCKET="your-lab-bucket-name"
```

Lifecycle policy:

```bash
cat > /tmp/lab-s3-lifecycle.json <<'EOF'
{
  "Rules": [
    {
      "ID": "lab-cleanup-rule",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "Expiration": {
        "Days": 30
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 7
      },
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 1
      }
    }
  ]
}
EOF
```

Apply:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration file:///tmp/lab-s3-lifecycle.json
```

Verify:

```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket "$BUCKET"
```

---

## 21. Terraform cost guardrails

In Terraform projects, add rules like:

```text
required tags:
  Project
  Environment
  Owner
  ManagedBy

for dev:
  no NAT Gateway unless explicitly enabled
  no Multi-AZ RDS unless explicitly enabled
  no public RDS
  no large instance types
  log retention required
  S3 lifecycle required
```

Example variable:

```hcl
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway. This can create recurring hourly and data-processing cost."
  type        = bool
  default     = false
}
```

Example tag locals:

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}
```

Example lifecycle protection for prod:

```hcl
resource "aws_db_instance" "prod" {
  # production database configuration

  deletion_protection = true

  tags = local.common_tags
}
```

Cost optimization should be built into IaC, not remembered manually.

---

## 22. DevOps cleanup checklist after every lab

Run this after AWS labs:

```text
EC2:
  terminate instances

EBS:
  delete unattached volumes
  review snapshots

Elastic IP:
  release unused addresses

ALB/NLB:
  delete load balancers
  delete target groups

NAT Gateway:
  delete NAT gateways
  release EIPs

RDS:
  delete lab DBs
  remove snapshots only if not needed

ECS:
  scale services to 0 or delete
  delete clusters if lab-only

ECR:
  delete old images/repositories

CloudFront:
  disable then delete distributions

S3:
  empty and delete lab buckets
  delete old versions/delete markers

CloudWatch:
  set retention or delete lab log groups

API Gateway/Lambda:
  delete test APIs/functions

DynamoDB:
  delete lab tables

IAM:
  delete lab roles/policies after resources are gone
```

---

## 23. Cost optimization by service

### EC2

```text
Right-size instances.
Use Auto Scaling.
Stop dev instances when idle.
Use Graviton where compatible.
Use Spot for fault-tolerant workloads.
Use Savings Plans for stable baseline usage.
Delete unused EBS volumes.
```

### RDS

```text
Use correct instance class.
Use storage autoscaling carefully.
Do not enable Multi-AZ in dev unless needed.
Use read replicas only when needed.
Stop eligible dev DBs.
Delete old snapshots by retention policy.
Use Aurora Serverless only when workload pattern fits.
```

### S3

```text
Use lifecycle rules.
Use Intelligent-Tiering where access patterns are unknown and object size/access economics fit.
Expire old versions.
Abort incomplete multipart uploads.
Avoid unnecessary cross-region replication.
Analyze storage class transitions carefully.
```

### Lambda

```text
Tune memory and timeout.
Avoid oversized packages.
Use provisioned concurrency only when needed.
Avoid excessive logging.
Use Compute Optimizer recommendations.
```

### ECS/Fargate

```text
Right-size CPU/memory.
Use autoscaling.
Avoid over-provisioned desired count.
Use Spot capacity where suitable.
Enable split cost allocation for ECS/EKS when needed.
```

### CloudWatch

```text
Set log retention.
Reduce debug logs in production.
Avoid excessive custom metrics.
Review high-cardinality metrics.
Review VPC Flow Log volume.
```

### Network

```text
Avoid unnecessary NAT Gateway.
Use VPC endpoints for S3/DynamoDB/ECR/CloudWatch where suitable.
Minimize cross-AZ traffic.
Review data transfer.
Delete idle load balancers.
```

---

## 24. Common cost incidents and fixes

### Incident 1 — NAT Gateway bill spike

Symptoms:

```text
VPC cost increased.
NATGateway-Bytes or NAT data processing usage increased.
```

Check:

```bash
aws ce get-cost-and-usage \
  --region us-east-1 \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity DAILY \
  --metrics UnblendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Virtual Private Cloud"]}}' \
  --group-by Type=DIMENSION,Key=USAGE_TYPE \
  --output table
```

Fix:

```text
Identify private subnet traffic.
Add S3/DynamoDB Gateway Endpoints.
Add interface endpoints for ECR/Logs/Secrets where justified.
Keep NAT and resources in same AZ when possible.
Remove unused NAT gateways.
```

---

### Incident 2 — CloudWatch Logs bill spike

Symptoms:

```text
CloudWatch cost increased.
Logs ingestion/storage increased.
```

Fix:

```text
Find largest log groups.
Set retention.
Reduce debug noise.
Check runaway application loop.
Check VPC Flow Logs volume.
Move archival logs to S3 if suitable.
```

Command:

```bash
aws logs describe-log-groups \
  --region ap-south-1 \
  --query 'sort_by(logGroups,&storedBytes)[-20:].{Name:logGroupName,StoredBytes:storedBytes,Retention:retentionInDays}' \
  --output table
```

---

### Incident 3 — EC2 cost higher than expected

Fix checklist:

```text
running instances?
stopped instances with EBS?
wrong instance family?
public IPv4?
unattached EBS?
snapshots?
load balancer still running?
Auto Scaling desired count too high?
```

---

### Incident 4 — S3 cost grows slowly every month

Fix checklist:

```text
old versions?
old logs?
multipart uploads?
replication?
large object count?
wrong storage class?
no lifecycle rule?
```

---

### Incident 5 — RDS lab cost continues

Fix checklist:

```text
DB instance still running?
Multi-AZ enabled?
read replica exists?
snapshots retained?
automated backups retained?
storage large?
```

---

## 25. Production FinOps dashboard

A good FinOps dashboard shows:

```text
Monthly spend by service
Daily spend trend
Spend by account
Spend by environment
Spend by project
Top 10 cost increases
Untagged resource cost
NAT Gateway cost
EC2 cost by instance family
RDS cost by engine
S3 storage by bucket/class
CloudWatch log ingestion/storage
Savings Plan coverage/utilization
Budget status
Anomalies
Optimization opportunities
```

For a multi-account setup:

```text
Management account:
  consolidated billing

Log archive:
  cost reports and CUR/Data Exports bucket

Security account:
  monitors spend anomalies and guardrails

Workload accounts:
  tagged resources and team-level cost ownership
```

---

## 26. Production cost governance checklist

```text
1. Monthly budget exists.
2. Cost Anomaly Detection exists.
3. Cost Explorer reviewed weekly.
4. Required tags are defined.
5. Cost allocation tags are activated.
6. Untagged resources are reported.
7. CUR/Data Exports enabled for serious reporting.
8. Log retention policy exists.
9. S3 lifecycle policy exists.
10. NAT Gateway usage is reviewed.
11. Idle load balancers are deleted.
12. Unattached EBS volumes are reported.
13. Old snapshots are reviewed.
14. Dev/staging resources have schedules.
15. Compute Optimizer is reviewed.
16. Savings Plans are purchased only after right-sizing.
17. Prod optimization is tested before changes.
18. IaC includes cost guardrails.
19. Team owners receive cost reports.
20. Savings are measured after changes.
```

---

## 27. Certification angle

### CLF-C02

Know:

```text
AWS Budgets:
  alerting and tracking spend/usage

Cost Explorer:
  analyze historical cost and forecast

Cost and Usage Reports/Data Exports:
  detailed billing data

Savings Plans:
  commitment-based compute discounts

Reserved Instances:
  reservation-style discounts

Tags:
  cost allocation

S3 Lifecycle:
  transition/archive/delete objects

Compute Optimizer:
  right-sizing recommendations
```

### SAA-C03

Know deeply:

```text
right-sizing
storage lifecycle
NAT Gateway cost traps
multi-AZ cost tradeoffs
data transfer cost awareness
VPC endpoints to reduce NAT path usage
CloudWatch log retention
S3 version cleanup
RDS snapshot retention
Savings Plans vs RIs
cost-aware architecture decisions
```

### DOP-C02

Know operationally:

```text
cost guardrails in CI/CD
FinOps dashboards
Cost Explorer investigations
CUR/Data Exports reporting
automated cleanup scripts
tag enforcement
budget/anomaly alert routing
Compute Optimizer review process
Terraform policy-as-code cost checks
post-incident cost analysis
```

---

## 28. Interview answer

Memorize this:

```text
Cost optimization on AWS is not just reducing spend. It is a continuous FinOps process where engineering, finance, and product teams work together to make cost visible, allocate it correctly, remove waste, right-size resources, and choose the correct pricing model while still meeting reliability and performance requirements.

I use AWS Budgets for threshold alerts, Cost Explorer for cost investigation, Cost Anomaly Detection for unusual spend, Cost and Usage Reports or Data Exports for detailed reporting, cost allocation tags for ownership, and Compute Optimizer or Cost Optimization Hub for recommendations. I make tags such as Project, Environment, Owner, CostCenter, Application, and ManagedBy mandatory so costs can be mapped to teams and workloads.

My first cost optimization step is always waste removal: delete idle load balancers, NAT gateways, unattached EBS volumes, old snapshots, old logs, unused ECR images, and forgotten test databases. Then I right-size EC2, RDS, Lambda, EBS, and ECS/Fargate based on metrics. Only after right-sizing do I consider Savings Plans or Reserved Instances for stable baseline usage.

I also design infrastructure to avoid known cost traps. I set CloudWatch log retention, add S3 lifecycle policies, avoid unnecessary NAT Gateway traffic by using VPC endpoints where appropriate, keep dev resources small or scheduled, and enforce cost guardrails through Terraform, budgets, dashboards, and weekly reviews.
```

---

## 29. Quick quiz

```text
1. What is FinOps?
2. What is AWS Budgets used for?
3. Does AWS Budgets automatically stop all spending?
4. What is Cost Explorer used for?
5. What is Cost Anomaly Detection?
6. What is CUR/Data Exports used for?
7. Why are cost allocation tags important?
8. What is Compute Optimizer?
9. What is Cost Optimization Hub?
10. What is a Savings Plan?
11. What is a Reserved Instance?
12. Why should you right-size before buying commitments?
13. Why can NAT Gateway become expensive?
14. How can VPC endpoints reduce NAT usage?
15. Why should CloudWatch log retention be set?
16. What can S3 Lifecycle do?
17. What is an unattached EBS volume?
18. Why can stopped EC2 still cost money?
19. What tags should every resource have?
20. What is the first step after a cost spike?
```

Answers:

```text
1. A practice where engineering, finance, and product teams manage cloud cost together.
2. Tracking cost/usage and sending alerts.
3. No, it mainly alerts unless specific actions are configured.
4. Analyzing and forecasting AWS cost and usage.
5. ML-based unusual spend detection and alerting.
6. Detailed line-item cost and usage reporting.
7. They map costs to owners, projects, environments, and teams.
8. AWS service that recommends resource right-sizing.
9. AWS feature that consolidates and prioritizes cost optimization recommendations.
10. Commitment-based discount model based on $/hour usage.
11. Reservation-style discount model for predictable usage.
12. Otherwise you may buy discounts for wasted capacity.
13. It has hourly and data-processing/data-transfer cost dimensions.
14. They let private resources access AWS services without routing that traffic through NAT.
15. Logs are kept indefinitely by default and can accumulate cost.
16. Transition, archive, expire/delete objects and clean incomplete uploads.
17. EBS disk not attached to any EC2 instance.
18. EBS volumes, snapshots, Elastic IPs, logs, and other resources may still exist.
19. Project, Environment, Owner, ManagedBy, CostCenter, Application, and lifecycle tags.
20. Identify service/account/region/tag owner in Cost Explorer, then find the resource causing it.
```

# Next Lesson

```text
AWS Lesson 19 — Production Architecture Capstone:
Design a complete AWS production platform using Route 53, CloudFront, WAF, S3, ALB, ECS/Fargate, RDS/DynamoDB, VPC, IAM, Secrets Manager, CloudWatch, CI/CD, multi-account structure, cost controls, and disaster recovery
```

[1]: https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-optimization.html?utm_source=chatgpt.com "Cost optimization - AWS Well-Architected Framework"
[2]: https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/practice-cloud-financial-management.html?utm_source=chatgpt.com "Practice Cloud Financial Management - Cost Optimization Pillar"
[3]: https://docs.aws.amazon.com/cost-management/latest/userguide/?utm_source=chatgpt.com "What is AWS Billing and Cost Management? - AWS Cost Management"
[4]: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html?utm_source=chatgpt.com "Managing your costs with AWS Budgets - AWS Cost Management"
[5]: https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html?utm_source=chatgpt.com "Analyzing your costs and usage with AWS Cost Explorer - AWS Cost Management"
[6]: https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html?utm_source=chatgpt.com "Detecting unusual spend with AWS Cost Anomaly Detection - AWS Cost Management"
[7]: https://docs.aws.amazon.com/prescriptive-guidance/latest/cost-allocation-tagging/apply-tags.html?utm_source=chatgpt.com "Apply the tags - AWS Prescriptive Guidance"
[8]: https://docs.aws.amazon.com/cur/latest/userguide/what-is-cur.html?utm_source=chatgpt.com "What are AWS Cost and Usage Reports? - AWS Data Exports"
[9]: https://docs.aws.amazon.com/cur/latest/userguide/what-is-data-exports.html?utm_source=chatgpt.com "What is AWS Data Exports? - AWS Data Exports"
[10]: https://docs.aws.amazon.com/cur/latest/userguide/split-cost-allocation-data.html?utm_source=chatgpt.com "Understanding split cost allocation data - AWS Data Exports"
[11]: https://docs.aws.amazon.com/cost-management/latest/userguide/cost-optimization-hub.html?utm_source=chatgpt.com "Identifying opportunities with Cost Optimization Hub - AWS Cost Management"
[12]: https://docs.aws.amazon.com/compute-optimizer/latest/APIReference/Welcome.html?utm_source=chatgpt.com "Welcome - AWS Compute Optimizer"
[13]: https://docs.aws.amazon.com/savingsplans/latest/userguide/sp-services.html?utm_source=chatgpt.com "Services eligible for Savings Plans benefits - Savings Plans"
[14]: https://docs.aws.amazon.com/savingsplans/latest/userguide/sp-ris.html?utm_source=chatgpt.com "Compute Savings Plans and Reserved Instances - Savings Plans"
[15]: https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-pricing.html?utm_source=chatgpt.com "Pricing for NAT gateways - Amazon Virtual Private Cloud"
[16]: https://docs.aws.amazon.com/compute-optimizer/latest/ug/automation-rec.html?utm_source=chatgpt.com "Recommended actions - AWS Compute Optimizer"
[17]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html?utm_source=chatgpt.com "What is Amazon CloudWatch Logs? - Amazon CloudWatch Logs"
[18]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html?utm_source=chatgpt.com "Managing the lifecycle of objects - Amazon Simple Storage Service"
