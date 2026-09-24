# AWS Masterclass — Lesson 19

## Production Architecture Capstone — Complete AWS Platform Design

Today we design a complete production-style AWS platform using everything you learned:

```text
Route 53
CloudFront
AWS WAF
S3 private origin with OAC
ALB
ECS/Fargate
RDS or DynamoDB
VPC
IAM
Secrets Manager
CloudWatch
CI/CD
multi-account structure
cost controls
backup
disaster recovery
```

This is the architecture you should be able to explain in interviews and later build with Terraform.

AWS Well-Architected is built around six pillars: operational excellence, security, reliability, performance efficiency, cost optimization, and sustainability. This capstone follows that same production mindset. ([AWS Documentation][1])

---

## 1. Capstone goal

Design a production-ready platform for a web application like your Todo/DevOps app.

The app should support:

```text
frontend static assets
backend API
private application networking
managed database
HTTPS domain
CDN caching
WAF protection
central logs
CI/CD deployment
rollback
backup
cost controls
DR plan
```

Target region:

```text
Primary AWS Region:
  ap-south-1

CloudFront ACM certificate:
  us-east-1
```

---

## 2. Final architecture

```text
Users
  ↓
Route 53
  ↓
CloudFront + AWS WAF
  ├── /assets/* → Private S3 bucket through OAC
  └── /api/*    → ALB in ap-south-1
                    ↓
                  ECS Fargate service in private app subnets
                    ↓
                  RDS/Aurora or DynamoDB
```

Supporting platform:

```text
CI/CD:
  GitHub → CodePipeline/CodeBuild or GitHub Actions → ECR → ECS

Security:
  IAM roles, Secrets Manager, KMS, WAF, GuardDuty, CloudTrail

Observability:
  CloudWatch metrics, logs, alarms, dashboards, X-Ray/OpenTelemetry

Cost:
  Budgets, tags, log retention, S3 lifecycle, cleanup automation

DR:
  backups, snapshots, cross-Region/cross-account copy where needed
```

---

## 3. Why this architecture is production-style

Beginner architecture:

```text
User → public EC2 → app + database on same server
```

Production architecture:

```text
User
  ↓
global edge and HTTPS
  ↓
load balancer
  ↓
private compute
  ↓
private database
  ↓
central logs, backup, monitoring, CI/CD, IAM, cost guardrails
```

The biggest mindset shift is this:

```text
Production is not just running an app.

Production means:
  secure access
  controlled deployment
  private networking
  monitoring
  rollback
  backup
  cost control
  incident response
```

---

## 4. Multi-account layout

For a real company, do not put everything in one AWS account.

Recommended starter layout:

```text
AWS Organization
  ├── Management account
  ├── Log Archive account
  ├── Security Tooling account
  ├── Network account
  ├── Shared Services / CI-CD account
  ├── Dev workload account
  ├── Staging workload account
  └── Prod workload account
```

For your learning account, you can simulate this with naming, tagging, and separate Terraform workspaces. For real production, separate accounts reduce blast radius and make security/cost ownership cleaner.

---

## 5. Network design

Use a 3-tier VPC:

```text
VPC:
  10.30.0.0/16

Public subnets:
  10.30.1.0/24
  10.30.2.0/24

Private app subnets:
  10.30.11.0/24
  10.30.12.0/24

Private DB subnets:
  10.30.21.0/24
  10.30.22.0/24
```

Resource placement:

```text
Public subnets:
  ALB
  NAT Gateway, only when required

Private app subnets:
  ECS Fargate tasks
  EC2 app servers, if used

Private DB subnets:
  RDS/Aurora
  ElastiCache
```

Production security group flow:

```text
CloudFront
  ↓
ALB SG:
  allow 443/80 from internet or CloudFront-facing design

ECS task SG:
  allow app port only from ALB SG

Database SG:
  allow DB port only from ECS task SG
```

---

## 6. Edge layer: Route 53, CloudFront, WAF

Domain pattern:

```text
app.yourdatascientist.tech
api.yourdatascientist.tech
```

Route 53:

```text
app.yourdatascientist.tech
  A Alias → CloudFront

api.yourdatascientist.tech
  A Alias → CloudFront or ALB, depending design
```

CloudFront:

```text
Viewer protocol policy:
  redirect-to-https

Origins:
  private S3 origin
  ALB origin

Behaviors:
  /assets/* → S3
  /api/*    → ALB
```

AWS WAF web ACLs can protect CloudFront, API Gateway, ALB, AppSync, Cognito, App Runner, Amplify, and other supported resources. ([AWS Documentation][2])

S3 private content should use CloudFront Origin Access Control. CloudFront supports OAC and OAI for authenticated requests to S3 origins, and OAC is the modern pattern for private S3 access through CloudFront. ([AWS Documentation][3])

---

## 7. Compute layer: ECS/Fargate

Use ECS Fargate for a clean production container architecture:

```text
ECR:
  stores container images

ECS cluster:
  logical cluster

Task definition:
  container image, CPU, memory, port, logs, env, secrets

ECS service:
  keeps desired tasks running

ALB:
  routes traffic to healthy tasks
```

For Fargate using `awsvpc` network mode, the target group target type must be `ip`, not `instance`. ([AWS Documentation][4])

Production deployment pattern:

```text
Git commit
  ↓
Docker build
  ↓
ECR image tagged with commit SHA
  ↓
new ECS task definition revision
  ↓
ECS service deployment
  ↓
ALB health checks
  ↓
CloudWatch validation
```

---

## 8. Data layer choice

Choose based on workload.

| Requirement                               | Use                            |
| ----------------------------------------- | ------------------------------ |
| SQL joins, transactions, relational model | RDS PostgreSQL/MySQL or Aurora |
| Serverless key-value/document workload    | DynamoDB                       |
| Cache/session/rate limit                  | ElastiCache                    |
| Analytics warehouse                       | Redshift                       |
| Object files/static/assets/logs           | S3                             |

For relational production workloads, RDS Multi-AZ improves availability by maintaining a standby in another Availability Zone and automatically failing over during planned or unplanned outages. ([AWS Documentation][5])

For global serverless NoSQL, DynamoDB global tables replicate table data across AWS Regions without you building your own replication system. ([AWS Documentation][6])

---

## 9. Secrets and IAM

Never store secrets in:

```text
Git
Dockerfile
Terraform tfvars
EC2 user_data
plain environment files
pipeline logs
```

Use:

```text
Secrets Manager:
  database password
  API keys
  third-party tokens

SSM Parameter Store:
  app config
  simpler secure parameters
```

IAM role separation:

```text
CI/CD deployment role:
  deploy app/infrastructure

ECS task execution role:
  pull image from ECR
  write logs

ECS task role:
  app runtime permissions

RDS access:
  network SG + credentials/secret

CloudFront to S3:
  OAC + bucket policy
```

Important production rule:

```text
Do not give the app AdministratorAccess.
Give the app only the exact AWS permissions it needs.
```

---

## 10. Observability layer

Minimum production signals:

```text
CloudFront:
  4xxErrorRate
  5xxErrorRate
  CacheHitRate
  OriginLatency

ALB:
  RequestCount
  TargetResponseTime
  HTTPCode_Target_5XX_Count
  HealthyHostCount
  UnHealthyHostCount

ECS:
  CPUUtilization
  MemoryUtilization
  RunningTaskCount
  deployment events

RDS:
  CPUUtilization
  DatabaseConnections
  FreeStorageSpace
  ReadLatency
  WriteLatency

Application:
  request count
  error rate
  p95 latency
  business events
```

Golden signals:

```text
Latency
Traffic
Errors
Saturation
```

Minimum alarms:

```text
CloudFront 5xx high
ALB target 5xx high
ALB unhealthy targets > 0
ECS running tasks below desired count
RDS storage low
RDS connections high
API p95 latency high
Budget threshold crossed
GuardDuty high-severity finding
```

---

## 11. CI/CD design

Production pipeline:

```text
GitHub
  ↓
Build/test
  ↓
Docker build
  ↓
ECR push
  ↓
Security scan
  ↓
Deploy to dev
  ↓
Integration tests
  ↓
Manual approval
  ↓
Deploy to prod
  ↓
Smoke test
  ↓
Monitor alarms
```

Artifacts:

```text
Docker image:
  todo-api:<commit-sha>

Task definition:
  exact container runtime config

Deployment metadata:
  commit SHA
  build ID
  image URI
  environment
  deploy time
```

Rollback options:

```text
ECS:
  update service to previous task definition

Lambda:
  move alias back to previous version

Frontend S3/CloudFront:
  sync previous build
  invalidate index.html

Terraform:
  apply corrective reviewed change
```

---

## 12. Cost controls

Every resource should have tags:

```text
Project
Environment
Owner
ManagedBy
CostCenter
Application
AutoDelete
ExpiresOn
```

Cost guardrails:

```text
AWS Budget:
  monthly account/project alert

CloudWatch Logs:
  retention policy

S3:
  lifecycle policy

NAT Gateway:
  avoid unless needed
  use S3/DynamoDB gateway endpoints where possible

EBS:
  scan unattached volumes

ECR:
  lifecycle policy for old images

RDS:
  avoid oversized dev DBs
  delete lab DBs
```

---

## 13. Disaster recovery design

DR starts with two numbers:

```text
RTO:
  Recovery Time Objective
  how quickly service must be restored

RPO:
  Recovery Point Objective
  how much data loss is acceptable
```

AWS Reliability guidance states that RTO and RPO are the objectives for restoration of a workload. ([AWS Documentation][7])

Starter production DR:

```text
S3:
  versioning
  lifecycle
  optional cross-Region replication

RDS:
  automated backups
  snapshots
  Multi-AZ for HA
  cross-Region snapshot copy for DR where needed

DynamoDB:
  PITR
  backups
  global tables for multi-Region active-active use cases

ECR:
  image replication or rebuild from Git

Terraform:
  remote state backup/versioning

Secrets:
  backup/replication strategy

Runbooks:
  restore procedure tested
```

AWS Backup supports centralized backup management and can use backup policies across AWS accounts in an organization; cross-Region backup is useful when continuity or compliance requires backups away from production data. ([AWS Documentation][8])

---

# Hands-On Lab 19A — Build Your Production Architecture Capstone Pack

This lab creates local files only.

No AWS resources. No charges.

## Step 1 — Create folders

```bash
mkdir -p ~/aws-masterclass/production-capstone/{diagrams,docs,terraform-notes,runbooks,policies,scripts,reports}
cd ~/aws-masterclass/production-capstone
```

---

## Step 2 — Create architecture diagram

```bash
cat > diagrams/production-platform.mmd <<'EOF'
flowchart TD
  User[Users] --> R53[Route 53]
  R53 --> CF[CloudFront + WAF]

  CF -->|/assets/*| S3[Private S3 Bucket with OAC]
  CF -->|/api/*| ALB[Application Load Balancer]

  ALB --> ECS[ECS Fargate Service]
  ECS --> RDS[(RDS/Aurora Private DB)]
  ECS --> DDB[(DynamoDB)]
  ECS --> SM[Secrets Manager]

  GitHub[GitHub] --> Pipeline[CI/CD Pipeline]
  Pipeline --> ECR[ECR]
  ECR --> ECS

  ECS --> CW[CloudWatch Logs/Metrics]
  ALB --> CW
  CF --> CW
  RDS --> CW

  CW --> Alarms[CloudWatch Alarms]
  Alarms --> OnCall[On-call / Incident Runbook]

  Backup[AWS Backup] --> RDS
  Backup --> CrossRegion[Cross-Region/Cross-Account Backup Copy]

  CloudTrail[CloudTrail] --> LogArchive[Log Archive Account]
  GuardDuty[GuardDuty] --> Security[Security Tooling Account]
EOF
```

---

## Step 3 — Create architecture decision record

```bash
cat > docs/architecture-decision-record.md <<'EOF'
# Architecture Decision Record — AWS Production Platform

## Application

Production web application with frontend static assets and backend API.

## Primary Region

ap-south-1

## Global Services

CloudFront
Route 53
AWS WAF for CloudFront
ACM certificate for CloudFront in us-east-1

## Edge

Route 53 routes app domain to CloudFront.
CloudFront terminates HTTPS, applies WAF, caches static content, and routes API paths to ALB.

## Origins

/assets/*:
  Private S3 bucket through CloudFront OAC

/api/*:
  Application Load Balancer in ap-south-1

## Compute

ECS Fargate in private app subnets.
Tasks have no public IP.
ALB forwards to ECS tasks using target type ip.

## Data

RDS/Aurora for relational data.
DynamoDB for serverless key-value/document use cases.
S3 for objects/static/logs.

## Security

IAM least privilege.
Secrets Manager for credentials.
KMS for customer-managed encryption where required.
WAF on CloudFront.
CloudTrail and GuardDuty enabled.
S3 Block Public Access enabled.

## Observability

CloudWatch metrics, logs, alarms, dashboards.
Application structured JSON logs.
ALB/CloudFront access logs where required.
Runbooks for common incidents.

## CI/CD

Image built from Git commit.
Image pushed to ECR with commit SHA tag.
ECS service deployed through pipeline.
Production requires approval and post-deploy validation.

## Cost

Required tags.
Budgets.
Log retention.
S3 lifecycle.
ECR lifecycle.
NAT Gateway avoided unless necessary.

## Disaster Recovery

RTO and RPO defined by workload criticality.
RDS backups and snapshots.
AWS Backup plan.
Cross-Region/cross-account copy for critical data.
Restore runbooks tested periodically.
EOF
```

---

## Step 4 — Create Terraform module map

```bash
cat > terraform-notes/module-map.md <<'EOF'
# Terraform Module Map

## Root

environments/
  dev/
  staging/
  prod/

## Modules

networking:
  VPC
  public subnets
  private app subnets
  private DB subnets
  route tables
  optional NAT
  VPC endpoints

security-groups:
  ALB SG
  ECS task SG
  RDS SG

edge:
  CloudFront
  WAF
  ACM reference
  Route 53 records

storage:
  S3 private bucket
  OAC bucket policy
  lifecycle
  encryption
  versioning

compute:
  ECS cluster
  ECS task definition
  ECS service
  ALB target group attachment

database:
  RDS/Aurora
  subnet group
  parameter group
  backups
  deletion protection

iam:
  ECS task execution role
  ECS task role
  CI/CD deploy role
  least-privilege policies

observability:
  CloudWatch log groups
  alarms
  dashboards

backup:
  AWS Backup vault
  backup plan
  backup selection
EOF
```

---

## Step 5 — Create production checklist

```bash
cat > reports/production-readiness-checklist.md <<'EOF'
# Production Readiness Checklist

## Domain and Edge

- [ ] Route 53 hosted zone confirmed
- [ ] ACM certificate for CloudFront issued in us-east-1
- [ ] CloudFront alternate domain configured
- [ ] HTTP redirects to HTTPS
- [ ] WAF attached to CloudFront
- [ ] CloudFront cache behaviors reviewed
- [ ] S3 origin uses OAC

## Network

- [ ] VPC CIDR does not overlap with future networks
- [ ] ALB in public subnets
- [ ] ECS tasks in private app subnets
- [ ] Database in private DB subnets
- [ ] No public database
- [ ] Security groups use SG-to-SG references
- [ ] NAT Gateway justified or avoided
- [ ] VPC endpoints considered

## Compute

- [ ] ECS tasks have no public IP
- [ ] Target group target type is ip for Fargate
- [ ] Health check endpoint exists
- [ ] Desired count at least 2 for production
- [ ] Autoscaling configured
- [ ] Container logs go to CloudWatch
- [ ] Task execution role and task role separated

## Data

- [ ] RDS Multi-AZ decision documented
- [ ] Backups enabled
- [ ] Deletion protection enabled for prod DB
- [ ] Secrets stored in Secrets Manager
- [ ] Encryption enabled
- [ ] Restore process documented

## IAM and Security

- [ ] Least-privilege IAM roles
- [ ] No hardcoded AWS keys
- [ ] iam:PassRole restricted
- [ ] S3 Block Public Access enabled
- [ ] CloudTrail enabled
- [ ] GuardDuty enabled for important accounts
- [ ] KMS key policy reviewed where used

## Observability

- [ ] CloudWatch alarms exist
- [ ] Dashboard exists
- [ ] Log retention configured
- [ ] Application logs include requestId
- [ ] Runbooks written
- [ ] Incident contacts documented

## CI/CD

- [ ] Images tagged with commit SHA
- [ ] ECR lifecycle policy exists
- [ ] Dev deploy automated
- [ ] Prod deploy requires approval
- [ ] Smoke tests after deploy
- [ ] Rollback runbook tested

## Cost

- [ ] Budget alert configured
- [ ] Required tags applied
- [ ] S3 lifecycle configured
- [ ] CloudWatch log retention configured
- [ ] Idle resource scan process exists
- [ ] NAT and public IPv4 usage reviewed

## Disaster Recovery

- [ ] RTO defined
- [ ] RPO defined
- [ ] Backup plan exists
- [ ] Restore tested
- [ ] Cross-Region/cross-account backup decision documented
EOF
```

---

## Step 6 — Create incident runbook

```bash
cat > runbooks/production-incident-runbook.md <<'EOF'
# Production Incident Runbook

## Incident type

Production web/API degradation.

## First 5 minutes

1. Check user-facing health endpoint.
2. Check CloudFront 5xx/4xx metrics.
3. Check ALB target health.
4. Check ECS service deployment status.
5. Check latest deployment time.
6. Check application logs.
7. Check RDS/DynamoDB metrics.
8. Check CloudTrail for recent changes.

## Commands

ALB target health:

aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table

ECS service state:

aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Deployments:deployments[*].{Status:status,TaskDef:taskDefinition,Desired:desiredCount,Running:runningCount}}'

Recent CloudTrail events:

aws cloudtrail lookup-events \
  --max-results 10 \
  --query 'Events[].{Time:EventTime,Name:EventName,User:Username,Source:EventSource}' \
  --output table

## Mitigation

- Roll back latest ECS task definition if issue started after deploy.
- Scale ECS service if saturation is high.
- Fail over database only through approved procedure.
- Disable bad CloudFront behavior/rule only after approval.
- Preserve logs before restarting tasks.

## Rollback

ECS rollback:

aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --task-definition "$PREVIOUS_TASK_DEFINITION"

Wait:

aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME"

Validate:

curl -f "$APP_URL/health"

## Resolution criteria

- Health endpoint returns 200.
- ALB targets healthy.
- Error rate normal.
- p95 latency normal.
- No new critical logs.
- Business transaction works.

## Post-incident

- Write timeline.
- Identify root cause.
- Add missing alarm/test/policy.
- Update runbook.
- Create follow-up tasks.
EOF
```

---

## Step 7 — Create cost cleanup scanner

```bash
cat > scripts/production-cost-scan.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

echo "===== Production Cost Scan: $AWS_REGION ====="

echo
echo "Caller:"
aws sts get-caller-identity

echo
echo "Running or stopped EC2:"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Type:InstanceType,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value,Project:Tags[?Key==`Project`]|[0].Value,Environment:Tags[?Key==`Environment`]|[0].Value}' \
  --output table || true

echo
echo "Unattached EBS volumes:"
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[].{VolumeId:VolumeId,SizeGiB:Size,Type:VolumeType,Created:CreateTime,Name:Tags[?Key==`Name`]|[0].Value}' \
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
echo "CloudWatch log groups without retention:"
aws logs describe-log-groups \
  --query 'logGroups[?retentionInDays==null].{Name:logGroupName,StoredBytes:storedBytes}' \
  --output table || true

echo
echo "Cost scan complete. Review before deleting anything."
EOF

chmod +x scripts/production-cost-scan.sh
```

Run later with:

```bash
AWS_REGION=ap-south-1 ./scripts/production-cost-scan.sh
```

---

## Step 8 — Create validation script

```bash
cat > scripts/validate-capstone-pack.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Validating AWS production capstone pack..."

required_files=(
  "diagrams/production-platform.mmd"
  "docs/architecture-decision-record.md"
  "terraform-notes/module-map.md"
  "reports/production-readiness-checklist.md"
  "runbooks/production-incident-runbook.md"
  "scripts/production-cost-scan.sh"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing: $file"
    exit 1
  fi
  echo "OK: $file"
done

echo
echo "Capstone pack validation passed."
EOF

chmod +x scripts/validate-capstone-pack.sh
./scripts/validate-capstone-pack.sh
```

Expected:

```text
Capstone pack validation passed.
```

---

# 14. Production failure scenarios to explain in interview

## Scenario 1 — CloudFront returns 403

Check:

```text
WAF block?
S3 object exists?
OAC attached?
Bucket policy SourceArn correct?
CloudFront behavior routes to correct origin?
Default root object configured?
```

## Scenario 2 — ALB returns 503

Usually:

```text
no healthy targets
```

Check:

```text
target group health
ECS task logs
container port
health check path
security group from ALB to task
target type ip
```

## Scenario 3 — ECS deployment failed

Check:

```text
ECR image exists
task execution role
task role
CloudWatch logs
app binds to 0.0.0.0
health endpoint
CPU/memory
subnet outbound path
```

## Scenario 4 — App cannot connect to database

Check:

```text
DB endpoint
DB SG inbound from ECS SG
private subnet route/NACL
secret value
database credentials
RDS status
DNS resolution
```

## Scenario 5 — Cost suddenly increased

Check:

```text
Cost Explorer by service
NAT Gateway
ALB/NLB
RDS
EC2
CloudWatch Logs
S3 versions
EBS snapshots
public IPv4
```

---

# 15. Resume-ready project description

Use this:

```text
Designed a production-grade AWS platform architecture using Route 53, CloudFront, AWS WAF, private S3 with OAC, ALB, ECS Fargate, RDS/DynamoDB, VPC private networking, IAM least-privilege roles, Secrets Manager, CloudWatch observability, CI/CD deployment flow, cost guardrails, backup strategy, and disaster recovery runbooks. Created architecture diagrams, readiness checklists, incident runbooks, Terraform module mapping, and operational validation scripts.
```

Stronger resume bullet:

```text
Built an AWS production architecture capstone covering edge delivery, private containerized compute, managed data services, CI/CD, observability, IAM security, cost governance, and DR planning, with reusable runbooks and validation scripts aligned to AWS Well-Architected principles.
```

---

# 16. Interview answer

Memorize this:

```text
For a production AWS web platform, I use Route 53 for DNS, CloudFront as the global HTTPS edge, and AWS WAF for request filtering. CloudFront routes static paths such as /assets/* to a private S3 bucket through Origin Access Control and dynamic API paths such as /api/* to an Application Load Balancer.

The ALB runs in public subnets and forwards traffic to ECS Fargate tasks in private app subnets. The ECS tasks have no public IPs and are registered in an ALB target group with target type ip. The database layer runs in private DB subnets using RDS/Aurora for relational workloads or DynamoDB for serverless key-value workloads. Secrets are stored in Secrets Manager, and IAM roles are separated between CI/CD deployment, ECS task execution, and application runtime permissions.

For operations, I use CloudWatch metrics, logs, alarms, dashboards, and runbooks. I monitor CloudFront errors, ALB 5xx, ECS task health, application latency, database saturation, and budget alarms. Deployment is done through CI/CD where images are built from Git commits, pushed to ECR with commit SHA tags, and deployed to ECS with health checks and rollback. For reliability, I define RTO and RPO, enable backups, test restores, and use cross-Region or cross-account backup copies when required. For cost, I enforce tags, budgets, log retention, S3 lifecycle, ECR lifecycle, and cleanup scanning.
```

---

# 17. Quick quiz

```text
1. Why should ECS tasks run in private subnets?
2. Why does CloudFront need OAC for private S3?
3. What does AWS WAF protect against?
4. What target group type is required for Fargate with awsvpc?
5. Why should RDS run in private DB subnets?
6. What is the difference between ECS task role and task execution role?
7. Why should Docker images be tagged with commit SHA?
8. What metrics tell you ALB is failing?
9. What is RTO?
10. What is RPO?
11. Why is CloudWatch log retention important?
12. Why should production deploys have rollback?
13. What should be checked during a CloudFront 403?
14. What should be checked during an ALB 503?
15. What does Secrets Manager protect?
16. What does CloudTrail answer?
17. What does GuardDuty detect?
18. Why are cost tags important?
19. Why should NAT Gateway usage be reviewed?
20. What makes this architecture production-ready?
```

Answers:

```text
1. To avoid direct public exposure and force traffic through controlled entry points.
2. To keep S3 private while allowing CloudFront to read objects securely.
3. HTTP/S web requests such as common attacks, bad bots, and rate-abuse patterns.
4. ip.
5. Databases should not be directly reachable from the internet.
6. Execution role is for ECS platform actions; task role is for app AWS permissions.
7. For traceability, reproducibility, and rollback.
8. Target 5xx, ELB 5xx, unhealthy targets, high target response time.
9. Maximum acceptable recovery time.
10. Maximum acceptable data loss.
11. Logs can otherwise accumulate cost indefinitely.
12. Bad deployments happen; rollback reduces user impact.
13. WAF, OAC, bucket policy, object path, cache behavior, default root object.
14. Target group health, app port, health path, ECS logs, security groups.
15. Credentials such as DB passwords and API keys.
16. Who did what, when, from where.
17. Suspicious or potentially malicious activity.
18. They map spend to owners/projects/environments.
19. NAT has hourly and data-processing cost traps.
20. Secure edge, private compute/data, IAM least privilege, CI/CD, observability, rollback, backup, DR, and cost controls.
```

# Next Lesson

```text
AWS Lesson 20 — Final AWS Interview and Certification Revision:
CLF-C02, SAA-C03, DOP-C02 revision maps, scenario questions, architecture interview questions, troubleshooting drills, hands-on project explanation, and final resume positioning
```

[1]: https://docs.aws.amazon.com/wellarchitected/2025-02-25/framework/definitions.html?utm_source=chatgpt.com "Definitions - AWS Well-Architected Framework"
[2]: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl.html?utm_source=chatgpt.com "Configuring protection in AWS WAF - AWS WAF, AWS Firewall Manager, AWS Shield Advanced, and AWS Shield network security director"
[3]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html?utm_source=chatgpt.com "Restrict access to an Amazon S3 origin - Amazon CloudFront"
[4]: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LoadBalancer.html?utm_source=chatgpt.com "LoadBalancer - Amazon Elastic Container Service"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html?utm_source=chatgpt.com "Failing over a Multi-AZ DB instance for Amazon RDS - Amazon Relational Database Service"
[6]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html?utm_source=chatgpt.com "Global tables - multi-active, multi-Region replication - Amazon DynamoDB"
[7]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/plan-for-disaster-recovery-dr.html?utm_source=chatgpt.com "Plan for Disaster Recovery (DR) - Reliability Pillar"
[8]: https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html?utm_source=chatgpt.com "What is AWS Backup? - AWS Backup"
