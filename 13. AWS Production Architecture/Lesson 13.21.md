# AWS Masterclass — Lesson 20

## Final AWS Interview and Certification Revision — CLF-C02, SAA-C03, DOP-C02, Scenarios, Troubleshooting, Projects, and Resume Positioning

This is the final revision lesson for the AWS track.

You should now be able to explain AWS from:

```text
absolute beginner:
  What is cloud? What is EC2? What is S3?

to production architect:
  How do I design secure, resilient, high-performing, cost-optimized systems?

to DevOps engineer:
  How do I automate, monitor, deploy, troubleshoot, roll back, and secure AWS workloads?
```

AWS’s official exam guides position **CLF-C02** as overall AWS Cloud knowledge, **SAA-C03** as designing Well-Architected solutions, and **DOP-C02** as provisioning, operating, and managing distributed systems and services on AWS. ([AWS Documentation][1])

---

## 1. Certification path for you

For your DevOps/cloud career path, follow this order:

```text
Step 1:
  AWS Certified Cloud Practitioner — CLF-C02

Step 2:
  AWS Certified Solutions Architect Associate — SAA-C03

Step 3:
  AWS Certified DevOps Engineer Professional — DOP-C02
```

Why this order?

```text
CLF-C02:
  teaches AWS vocabulary and service purpose

SAA-C03:
  teaches architecture decisions

DOP-C02:
  teaches automation, operations, deployment, monitoring, incident response, and governance
```

CLF-C02 is intended for people who can demonstrate overall AWS Cloud knowledge independent of a specific job role, SAA-C03 targets solutions architect work and recommends at least 1 year of hands-on AWS cloud design experience, and DOP-C02 targets DevOps engineers with 2 or more years of AWS provisioning, operating, and management experience. ([AWS Documentation][1])

---

## 2. CLF-C02 final map

Official CLF-C02 domain weights:

| Domain                        | Weight |
| ----------------------------- | -----: |
| Cloud Concepts                |    24% |
| Security and Compliance       |    30% |
| Cloud Technology and Services |    34% |
| Billing, Pricing, and Support |    12% |

AWS’s official CLF-C02 guide says the exam validates cloud value, shared responsibility, Well-Architected basics, security best practices, AWS costs/economics, core services, and common use cases. ([AWS Documentation][1])

### What you must know for CLF-C02

```text
Cloud concepts:
  Region, AZ, Edge, elasticity, scalability, high availability, fault tolerance

Security:
  shared responsibility, IAM, MFA, root user, least privilege, KMS, WAF, Shield

Core services:
  EC2, S3, RDS, DynamoDB, Lambda, VPC, CloudFront, Route 53, CloudWatch

Billing:
  Budgets, Cost Explorer, Savings Plans, Reserved Instances, Free Tier, Support plans
```

### CLF-C02 decision shortcuts

```text
Need virtual server?
  EC2

Need object storage?
  S3

Need managed relational database?
  RDS / Aurora

Need serverless NoSQL?
  DynamoDB

Need run code without servers?
  Lambda

Need CDN?
  CloudFront

Need DNS?
  Route 53

Need monitoring?
  CloudWatch

Need audit logs?
  CloudTrail

Need encryption keys?
  KMS

Need threat detection?
  GuardDuty

Need vulnerability scanning?
  Inspector

Need estimate and control cost?
  Pricing Calculator, Budgets, Cost Explorer
```

---

## 3. SAA-C03 final map

Official SAA-C03 domain weights:

| Domain                               | Weight |
| ------------------------------------ | -----: |
| Design Secure Architectures          |    30% |
| Design Resilient Architectures       |    26% |
| Design High-Performing Architectures |    24% |
| Design Cost-Optimized Architectures  |    20% |

AWS’s SAA-C03 guide says the exam validates the ability to design solutions that meet business requirements and future needs, and to design architectures that are secure, resilient, high-performing, and cost-optimized. ([AWS Documentation][2])

### What SAA-C03 really tests

It does not ask only:

```text
What is EC2?
```

It asks:

```text
Given this business problem,
which AWS architecture is most secure,
resilient,
high-performing,
cost-optimized,
and operationally practical?
```

### SAA-C03 architecture patterns

```text
Static website:
  S3 + CloudFront + Route 53 + ACM

Dynamic web app:
  CloudFront + ALB + ECS/EC2 + RDS

Highly available app:
  ALB across 2 AZs + ASG/ECS across 2 AZs + Multi-AZ database

Private app:
  public ALB + private app subnet + private DB subnet

Serverless API:
  API Gateway + Lambda + DynamoDB

Async processing:
  SQS + Lambda/ECS worker + DLQ

Fanout:
  SNS topic + multiple SQS/Lambda subscribers

Event routing:
  EventBridge + rules + targets

Hybrid connectivity:
  VPN / Direct Connect + Transit Gateway + Route 53 Resolver

Private S3 through CDN:
  CloudFront + OAC + private S3 bucket
```

### SAA-C03 exam language decoder

```text
"least operational overhead":
  prefer managed/serverless services

"most cost-effective":
  remove waste, use right storage class, choose Spot/Savings Plans carefully

"high availability":
  multiple AZs, load balancing, failover, managed HA services

"decouple components":
  SQS, SNS, EventBridge

"global low latency":
  CloudFront, Global Accelerator, DynamoDB Global Tables, Route 53 routing

"private connectivity to AWS services":
  VPC endpoints

"secure access to private S3":
  CloudFront OAC or appropriate bucket/IAM policy

"temporary secure access to object":
  pre-signed URL or CloudFront signed URL/cookie

"database read scaling":
  read replicas, cache, DynamoDB design

"database high availability":
  Multi-AZ, Aurora cluster, backups, failover

"object archive":
  S3 Glacier storage classes
```

---

## 4. DOP-C02 final map

Official DOP-C02 domain weights:

| Domain                           | Weight |
| -------------------------------- | -----: |
| SDLC Automation                  |    22% |
| Configuration Management and IaC |    17% |
| Resilient Cloud Solutions        |    15% |
| Monitoring and Logging           |    15% |
| Incident and Event Response      |    14% |
| Security and Compliance          |    17% |

AWS’s DOP-C02 guide says the exam validates skills such as continuous delivery, automated security controls, governance, compliance validation, monitoring/logging, highly available and self-healing systems, and operational automation. ([AWS Documentation][3])

### What DOP-C02 really tests

DOP-C02 is not only architecture.

It asks:

```text
How do you automate it?
How do you deploy it safely?
How do you detect failure?
How do you roll back?
How do you secure the pipeline?
How do you troubleshoot incidents?
How do you enforce governance?
```

### DOP-C02 service focus

```text
CI/CD:
  CodePipeline, CodeBuild, CodeDeploy, ECR, ECS deployments

IaC:
  CloudFormation, Terraform concepts, StackSets, change sets, drift detection

Monitoring:
  CloudWatch metrics, logs, alarms, dashboards, X-Ray

Incident response:
  EventBridge, Systems Manager, runbooks, automation, CloudTrail

Security:
  IAM, SCPs, permission boundaries, KMS, Secrets Manager, Config, GuardDuty, Inspector

Resilience:
  Auto Scaling, Multi-AZ, backups, failover, Route 53 health checks

Deployment:
  rolling, blue/green, canary, linear, rollback
```

---

## 5. Final AWS service selection table

| Requirement                  | Best AWS choice                                   |
| ---------------------------- | ------------------------------------------------- |
| Host static website          | S3 + CloudFront                                   |
| Store private files          | S3 with IAM/bucket policy                         |
| CDN and HTTPS edge           | CloudFront                                        |
| DNS                          | Route 53                                          |
| TLS certificate              | ACM                                               |
| Run VM/server                | EC2                                               |
| Scale EC2 automatically      | Auto Scaling Group                                |
| Balance HTTP traffic         | ALB                                               |
| Balance TCP/UDP traffic      | NLB                                               |
| Run containers simply        | ECS Fargate                                       |
| Run Kubernetes               | EKS                                               |
| Store container images       | ECR                                               |
| Run code on events           | Lambda                                            |
| Public serverless API        | API Gateway + Lambda                              |
| SQL database                 | RDS / Aurora                                      |
| NoSQL key-value/document DB  | DynamoDB                                          |
| Cache                        | ElastiCache                                       |
| Queue                        | SQS                                               |
| Pub/sub fanout               | SNS                                               |
| Event routing                | EventBridge                                       |
| Workflow orchestration       | Step Functions                                    |
| Secret storage               | Secrets Manager                                   |
| Secure config                | SSM Parameter Store                               |
| Encryption keys              | KMS                                               |
| Monitoring                   | CloudWatch                                        |
| Audit API calls              | CloudTrail                                        |
| Threat detection             | GuardDuty                                         |
| Vulnerability scanning       | Inspector                                         |
| Compliance/resource tracking | AWS Config                                        |
| Web firewall                 | WAF                                               |
| DDoS protection              | Shield                                            |
| Hybrid VPN                   | Site-to-Site VPN                                  |
| Dedicated hybrid link        | Direct Connect                                    |
| Multi-VPC hub                | Transit Gateway                                   |
| Data transfer/migration      | DataSync                                          |
| Database migration           | DMS                                               |
| Server migration             | AWS Transform MGN / Application Migration Service |
| Large offline data transfer  | Snow Family                                       |
| Cost alerts                  | AWS Budgets                                       |
| Cost analysis                | Cost Explorer                                     |

---

## 6. Final architecture interview scenario

Question:

```text
Design a production web application on AWS.
```

Strong answer:

```text
I would use Route 53 for DNS and CloudFront as the global HTTPS edge. CloudFront would use an ACM certificate in us-east-1 and AWS WAF for web protection. Static assets would be served from a private S3 bucket through Origin Access Control, and API requests would be routed to an Application Load Balancer in ap-south-1.

The ALB would run in public subnets across at least two Availability Zones and forward traffic to ECS Fargate tasks in private app subnets. The ECS service would use a task definition with CloudWatch logging, health checks, Secrets Manager integration, and separate task execution and task roles. The database would run in private DB subnets using RDS/Aurora for relational workloads or DynamoDB for serverless NoSQL needs.

For operations, I would configure CloudWatch metrics, logs, alarms, dashboards, ALB target health checks, and incident runbooks. For deployment, I would use CI/CD to build Docker images, push them to ECR with commit SHA tags, deploy new ECS task definitions, validate health, and roll back if needed. For security, I would use least-privilege IAM, KMS encryption, no hardcoded secrets, S3 Block Public Access, CloudTrail, GuardDuty, and WAF. For cost, I would enforce tags, budgets, log retention, S3 lifecycle, ECR lifecycle, and periodic idle-resource scans.
```

---

## 7. Troubleshooting drills

### Drill 1 — CloudFront returns 403

Check:

```text
1. Is WAF blocking?
2. Is OAC attached?
3. Does S3 bucket policy allow CloudFront service principal?
4. Does SourceArn match the distribution?
5. Does the object exist?
6. Is the cache behavior routing to the right origin?
7. Is DefaultRootObject configured?
8. Is the object encrypted with KMS and missing kms:Decrypt permission?
```

Best explanation:

```text
A CloudFront 403 is usually an authorization, object path, origin, OAC, WAF, or signed URL/cookie issue.
```

---

### Drill 2 — ALB returns 503

Meaning:

```text
Usually no healthy targets.
```

Check:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

Then check:

```text
health check path
container/app port
security group from ALB SG to app SG
target group target type
ECS task logs
EC2 user_data logs
app listening on 0.0.0.0
```

---

### Drill 3 — ECS task cannot pull image

Check:

```text
ECR image exists
image tag is correct
ECS task execution role has ECR permissions
private subnet has NAT or ECR VPC endpoints
repository is in correct account and region
CloudWatch logs show pull error
```

Never confuse:

```text
task execution role:
  pulls image and writes logs

task role:
  app runtime AWS permissions
```

---

### Drill 4 — Lambda cannot access DynamoDB

Check:

```text
Lambda execution role
dynamodb action
table ARN
region
account
KMS permissions if encrypted with customer-managed key
resource policy if applicable
```

Debug:

```bash
aws lambda get-function-configuration \
  --function-name "$FUNCTION_NAME" \
  --query 'Role'
```

---

### Drill 5 — Terraform gets AccessDenied on EC2

Check:

```text
caller identity
region
ec2:RunInstances
ec2:CreateTags
ec2:Describe*
iam:PassRole if instance profile is used
permission boundary
SCP
session policy
resource condition
```

Start with:

```bash
aws sts get-caller-identity
aws configure list
```

---

### Drill 6 — Monthly AWS bill increased suddenly

Check Cost Explorer by:

```text
service
region
account
tag
usage type
daily trend
```

Common suspects:

```text
NAT Gateway
ALB/NLB
RDS
EC2
EBS snapshots
CloudWatch Logs
S3 versions
public IPv4
CloudFront data transfer
```

---

## 8. Final hands-on project explanation

Your AWS production project can be presented like this:

```text
I designed and implemented an AWS production-style platform for a containerized web application. The frontend/static layer used S3 and CloudFront, with private S3 access through OAC. The backend API ran behind an ALB using ECS Fargate tasks in private subnets. The architecture used a three-tier VPC with public, private app, and private database subnets.

I implemented IAM least-privilege roles, separated task execution and task runtime permissions, stored secrets in Secrets Manager, and used CloudWatch logs and alarms for observability. The CI/CD flow built Docker images, pushed them to ECR with commit SHA tags, deployed ECS task definition revisions, validated health checks, and supported rollback to the previous task definition.

I also added production operations practices such as cost tags, AWS Budgets, log retention, S3 lifecycle rules, backup planning, incident runbooks, and troubleshooting scripts for ALB, ECS, CloudFront, IAM, and cost issues.
```

---

## 9. Resume positioning

Use this version:

```text
Designed a production-grade AWS cloud platform using Route 53, CloudFront, AWS WAF, private S3 with OAC, ALB, ECS Fargate, RDS/DynamoDB, VPC private networking, IAM least-privilege roles, Secrets Manager, CloudWatch observability, CI/CD deployment flow, rollback runbooks, cost controls, and disaster recovery planning.
```

Stronger DevOps version:

```text
Built an AWS DevOps architecture blueprint for a containerized application with ECR image publishing, ECS Fargate deployments, ALB health checks, CloudWatch monitoring, IAM-secured CI/CD roles, rollback strategy, Terraform-ready module mapping, and production runbooks aligned with AWS Well-Architected principles.
```

Interview headline:

```text
I can design, deploy, monitor, troubleshoot, secure, and cost-optimize production AWS workloads.
```

---

## 10. Final scenario questions

### Scenario 1

A company wants to host a static React app globally with HTTPS and private storage.

Answer:

```text
S3 private bucket + CloudFront + OAC + ACM certificate in us-east-1 + Route 53 Alias.
```

---

### Scenario 2

A backend API should run containers without managing servers.

Answer:

```text
ECS Fargate behind ALB, tasks in private subnets, images in ECR, logs in CloudWatch.
```

---

### Scenario 3

A database must support SQL joins and automatic failover.

Answer:

```text
RDS or Aurora with Multi-AZ, private DB subnets, backups, encryption, SG access only from app SG.
```

---

### Scenario 4

A workload needs serverless key-value access at high scale.

Answer:

```text
DynamoDB with correct partition key design, on-demand or provisioned capacity, PITR if critical.
```

---

### Scenario 5

A slow external process should not block API responses.

Answer:

```text
API writes message to SQS; worker Lambda/ECS processes asynchronously; configure DLQ.
```

---

### Scenario 6

One business event must notify email, analytics, and warehouse systems.

Answer:

```text
SNS fanout or EventBridge event routing, depending filtering and integration needs.
```

---

### Scenario 7

A company needs private connectivity from on-premises to many VPCs.

Answer:

```text
Site-to-Site VPN or Direct Connect into Transit Gateway, with non-overlapping CIDRs and Route 53 Resolver for hybrid DNS.
```

---

### Scenario 8

A production deployment must reduce blast radius.

Answer:

```text
Blue/green, canary, or linear deployment with CloudWatch alarms and rollback.
```

---

### Scenario 9

A team needs central access to many AWS accounts.

Answer:

```text
AWS Organizations + IAM Identity Center + permission sets + cross-account roles.
```

---

### Scenario 10

Security wants to know who changed a security group.

Answer:

```text
CloudTrail lookup-events.
```

---

## 11. Final “never forget” rules

```text
1. Root user is not for daily work.
2. IAM explicit deny always wins.
3. SCPs and permission boundaries do not grant permissions.
4. CloudFront custom-domain ACM certificate must be in us-east-1.
5. ALB runs in public subnets; apps usually run in private subnets.
6. Databases should not be publicly accessible.
7. Fargate target groups use target type ip.
8. Use OAC for private S3 behind CloudFront.
9. Use SQS to decouple workloads.
10. Use SNS for pub/sub fanout.
11. Use EventBridge for event routing.
12. Use Step Functions for workflows.
13. Use CloudTrail to answer who did what.
14. Use CloudWatch to monitor health.
15. Use GuardDuty for threat detection.
16. Use Inspector for vulnerability findings.
17. Use Secrets Manager or Parameter Store, not hardcoded secrets.
18. Use KMS carefully; key policy matters.
19. Use tags for cost ownership.
20. Always clean up NAT Gateway, ALB, RDS, EBS, snapshots, CloudWatch logs, and CloudFront labs.
```

---

## 12. Final quiz

```text
1. What is the difference between Region and AZ?
2. What is the difference between IAM user and IAM role?
3. What does explicit deny do?
4. What is iam:PassRole?
5. What is the difference between SG and NACL?
6. What makes a subnet public?
7. What is NAT Gateway used for?
8. Why use VPC endpoints?
9. What is CloudFront?
10. What is OAC?
11. Why does CloudFront ACM need us-east-1?
12. What is ALB used for?
13. What is Auto Scaling?
14. What is ECS Fargate?
15. What is the difference between task role and execution role?
16. What is RDS Multi-AZ?
17. What is DynamoDB best for?
18. What is SQS visibility timeout?
19. What is a DLQ?
20. What is EventBridge?
21. What is Step Functions?
22. What does CloudTrail record?
23. What does CloudWatch monitor?
24. What does GuardDuty detect?
25. What is AWS Budgets used for?
```

Answers:

```text
1. Region is geographic AWS area; AZ is isolated data center group inside a Region.
2. User has long-term identity; role is assumed for temporary credentials.
3. Overrides any allow.
4. Permission to pass a role to an AWS service.
5. SG is stateful resource firewall; NACL is stateless subnet firewall.
6. A route table route to Internet Gateway plus resource public addressing where needed.
7. Private subnet outbound internet access.
8. Private access to AWS services without public internet/NAT path.
9. AWS CDN/global edge service.
10. Origin Access Control for secure CloudFront-to-S3 private access.
11. CloudFront viewer certificates are managed from us-east-1.
12. Layer 7 HTTP/HTTPS load balancing.
13. Automatic capacity adjustment/replacement.
14. Serverless container compute for ECS.
15. Execution role is ECS platform; task role is app permissions.
16. Standby/failover database deployment across AZs.
17. Serverless NoSQL key-value/document workloads.
18. Time SQS hides a message while consumer processes it.
19. Dead Letter Queue for failed messages/events.
20. Event bus/router.
21. Serverless workflow orchestration.
22. AWS API activity: who did what, when, from where.
23. Metrics, logs, alarms, dashboards.
24. Suspicious or malicious activity.
25. Cost/usage tracking and alerts.
```

---

# AWS Masterclass Complete

You have completed the AWS foundation-to-production track:

```text
1. Cloud and AWS basics
2. IAM and account safety
3. Networking fundamentals
4. VPC design
5. EC2
6. Load balancers and Auto Scaling
7. Storage
8. Databases
9. Route 53, ACM, CloudFront basics
10. CloudFront deep dive
11. Containers on AWS
12. Serverless
13. Security and IAM production
14. Observability and operations
15. Hybrid cloud and migration
16. DevOps on AWS
17. Multi-account architecture
18. Cost optimization and FinOps
19. Production architecture capstone
20. Final interview and certification revision
```

Next best move: build the final architecture with Terraform in `ap-south-1`, then prepare a 2-minute and 10-minute interview explanation from the same project.

[1]: https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02.html "AWS Certified Cloud Practitioner (CLF-C02) - AWS Certified Cloud Practitioner"
[2]: https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03.html "AWS Certified Solutions Architect - Associate (SAA-C03) - AWS Certified Solutions Architect - Associate"
[3]: https://docs.aws.amazon.com/aws-certification/latest/devops-engineer-professional-02/devops-engineer-professional-02.html "AWS Certified DevOps Engineer - Professional (DOP-C02) - AWS Certified DevOps Engineer - Professional"
