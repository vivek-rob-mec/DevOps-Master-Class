# AWS Masterclass — Lesson 16

## DevOps on AWS — CodePipeline, CodeBuild, CodeDeploy, ECR, ECS Blue/Green, CloudFormation, Terraform Integration, Rollback, Artifacts, and CI/CD Security

Today we connect everything you have learned so far:

```text
Git
Docker
ECR
ECS
ALB
CloudFront
Lambda
Terraform
IAM
CloudWatch
rollback
security gates
```

The goal is to understand how real companies release software safely on AWS.

---

# 1. What is DevOps on AWS?

DevOps on AWS means:

```text
Code change happens
  ↓
pipeline starts automatically
  ↓
code is tested
  ↓
artifact or container image is built
  ↓
security checks run
  ↓
infrastructure or app is deployed
  ↓
health checks validate
  ↓
rollback happens if deployment fails
```

AWS CodePipeline is AWS’s continuous delivery service for modeling, visualizing, and automating release steps. A pipeline contains stages, stages contain actions, and actions move artifacts between stages. ([AWS Documentation][1])

A production pipeline is not just “build and deploy.”

A production pipeline must answer:

```text
Can we trust this code?
Can we rebuild it?
Can we roll it back?
Can we prove who deployed it?
Can we stop bad infrastructure changes?
Can we detect failure quickly?
Can we avoid storing secrets in the pipeline?
```

---

# 2. AWS DevOps service map

| Need                           | AWS service                                     |
| ------------------------------ | ----------------------------------------------- |
| Release pipeline orchestration | CodePipeline                                    |
| Build, test, package           | CodeBuild                                       |
| Application deployment         | CodeDeploy                                      |
| Container image registry       | ECR                                             |
| Container runtime              | ECS / EKS                                       |
| Infrastructure deployment      | CloudFormation / Terraform                      |
| Secrets                        | Secrets Manager / SSM Parameter Store           |
| Logs and metrics               | CloudWatch                                      |
| Audit                          | CloudTrail                                      |
| Manual approval                | CodePipeline approval action                    |
| Blue/green deployment          | CodeDeploy / ECS deployment controller          |
| Serverless deployment          | Lambda + CodeDeploy aliases                     |
| Security checks                | IAM, CodeBuild tools, Inspector, policy-as-code |

---

# 3. Modern source control note

Historically, many AWS examples used CodeCommit.

But CodeCommit is no longer available to new customers; existing customers can continue using it. ([AWS Documentation][2])

For new pipelines, use:

```text
GitHub
GitLab
Bitbucket
self-managed GitLab
GitHub Enterprise Server
```

through CodePipeline connections. AWS CodePipeline supports `CodeStarSourceConnection` for GitHub, Bitbucket, GitHub Enterprise Server, GitLab.com, and GitLab self-managed source actions. ([AWS Documentation][3])

So for your learning and production direction:

```text
Recommended source:
  GitHub repository

Pipeline source action:
  CodeStarSourceConnection

Avoid for new accounts:
  new CodeCommit dependency
```

---

# 4. Basic production pipeline

A normal app pipeline looks like this:

```text
GitHub
  ↓
CodePipeline Source stage
  ↓
CodeBuild Build/Test stage
  ↓
ECR image push or artifact package
  ↓
Deploy stage
  ↓
ECS / Lambda / EC2 / S3+CloudFront
  ↓
Health validation
  ↓
Rollback if failed
```

For container workloads:

```text
Developer pushes code
  ↓
CodePipeline starts
  ↓
CodeBuild builds Docker image
  ↓
CodeBuild pushes image to ECR
  ↓
Pipeline deploys new ECS task definition
  ↓
ALB health checks new tasks
  ↓
Old tasks are drained
```

For infrastructure:

```text
Developer changes Terraform
  ↓
pipeline runs terraform fmt
  ↓
terraform validate
  ↓
security/policy checks
  ↓
terraform plan
  ↓
manual approval
  ↓
terraform apply
```

---

# 5. CodePipeline in depth

CodePipeline is the orchestrator.

It does not usually compile code itself.

It coordinates actions.

```text
Pipeline
  ├── Source stage
  ├── Build stage
  ├── Test stage
  ├── Security stage
  ├── Approval stage
  └── Deploy stage
```

CodePipeline actions use input and output artifacts stored in an S3 artifact bucket. Every input artifact for an action must match an output artifact from an earlier action. ([AWS Documentation][4])

Simple mental model:

```text
CodePipeline = manager
CodeBuild = worker that builds/tests
CodeDeploy/ECS/CloudFormation = deployment workers
S3 artifact bucket = handover storage between stages
```

---

# 6. CodePipeline stages and actions

## Stage

A stage is a logical phase.

Examples:

```text
Source
Build
Test
SecurityScan
Approval
DeployDev
DeployProd
```

## Action

An action is the actual task inside a stage.

Examples:

```text
Source action:
  pull code from GitHub

Build action:
  run CodeBuild

Deploy action:
  deploy to ECS

Approval action:
  wait for human approval
```

CodePipeline actions are tasks performed on artifacts inside stages. ([AWS Documentation][5])

---

# 7. Artifact

An artifact is the output of one stage passed to another.

Examples:

```text
source.zip
build.zip
Docker image tag
imagedefinitions.json
taskdef.json
appspec.yaml
terraform plan file
```

Important:

```text
Artifact should be reproducible.
Artifact should be versioned.
Artifact should be traceable to a commit SHA.
```

Bad:

```text
Deploy whatever is currently on the server.
```

Good:

```text
Deploy image:
  123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api:commit-a1b2c3d
```

---

# 8. CodeBuild in depth

CodeBuild is managed build compute.

It can:

```text
install dependencies
run tests
run lint
run security scans
build Docker images
push images to ECR
run Terraform plan
package Lambda zip
generate deployment artifacts
```

CodeBuild downloads source into a build environment, uses a build specification called `buildspec`, and sends detailed build information to CloudWatch Logs. ([AWS Documentation][6])

---

# 9. buildspec.yml

`buildspec.yml` tells CodeBuild what commands to run.

Main phases:

```text
install:
  install tools

pre_build:
  login, prepare variables

build:
  run tests/build image/package

post_build:
  push artifact/image, generate deploy files
```

AWS CodeBuild buildspec files define build commands and artifacts; without a buildspec, CodeBuild cannot convert build input into build output or locate output artifacts. ([AWS Documentation][7])

Example structure:

```yaml
version: 0.2

phases:
  install:
    commands:
      - echo "Install dependencies"

  pre_build:
    commands:
      - echo "Login to ECR"

  build:
    commands:
      - echo "Run tests"
      - echo "Build Docker image"

  post_build:
    commands:
      - echo "Push image"
      - echo "Generate deployment artifact"

artifacts:
  files:
    - imagedefinitions.json
```

---

# 10. CodeBuild environment variables

Useful environment variables:

```text
CODEBUILD_SRC_DIR
CODEBUILD_RESOLVED_SOURCE_VERSION
CODEBUILD_BUILD_ID
CODEBUILD_BUILD_NUMBER
AWS_DEFAULT_REGION
```

`CODEBUILD_RESOLVED_SOURCE_VERSION` is very useful because it often contains the commit ID that triggered the build. CodeBuild also supports environment variables, but sensitive values should use Parameter Store or Secrets Manager rather than plaintext variables. ([AWS Documentation][8])

Production image tagging pattern:

```bash
IMAGE_TAG="${CODEBUILD_RESOLVED_SOURCE_VERSION:0:12}"
```

This gives:

```text
todo-api:a1b2c3d4e5f6
```

Better than:

```text
todo-api:latest
```

---

# 11. ECR in CI/CD

ECR stores container images.

Pipeline flow:

```text
CodeBuild
  ↓ docker build
local image
  ↓ docker tag
ECR image URI
  ↓ docker push
ECR repository
  ↓
ECS pulls image
```

Good tagging strategy:

```text
commit SHA:
  todo-api:a1b2c3d4e5f6

environment:
  todo-api:dev-a1b2c3d4e5f6

release:
  todo-api:v1.4.2

avoid as deploy source:
  latest
```

Why avoid `latest`?

```text
latest changes meaning over time.
rollback is unclear.
audit is harder.
two people may deploy different images with same tag.
```

---

# 12. imagedefinitions.json

For simple ECS standard deployment through CodePipeline, the deploy action commonly uses `imagedefinitions.json`.

Example:

```json
[
  {
    "name": "todo-api",
    "imageUri": "123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api:a1b2c3d4e5f6"
  }
]
```

Meaning:

```text
Container name in task definition:
  todo-api

New image to deploy:
  imageUri
```

When CodePipeline uses an ECR source action, the source action can generate an `imageDetail.json` output artifact. ([AWS Documentation][9])

---

# 13. CodeDeploy in depth

CodeDeploy handles application deployment strategies.

It supports:

```text
EC2/on-premises deployments
Lambda deployments
ECS blue/green deployments
```

CodeDeploy has two major deployment types: in-place and blue/green. For Lambda and ECS blue/green deployments, traffic can shift all at once, canary, or linear. ([AWS Documentation][10])

---

# 14. In-place deployment

In-place means:

```text
Deploy new version on the same existing servers.
```

Flow:

```text
EC2 instance running v1
  ↓
CodeDeploy stops old app
  ↓
copies new files
  ↓
starts v2
```

Good for:

```text
simple EC2 apps
small internal apps
legacy apps
```

Risk:

```text
same server is modified
bad deployment can break current capacity
rollback may be slower
```

---

# 15. Blue/green deployment

Blue/green means:

```text
Blue = old live version
Green = new version
Traffic shifts from blue to green
```

Flow:

```text
Users
  ↓
ALB
  ↓
Blue target group: v1 live

Deploy green:
  Green target group: v2 new

Validate green
  ↓
Shift traffic to green
  ↓
Keep or terminate blue
```

Benefits:

```text
safer release
fast rollback
new version is validated before full traffic
old version remains available during deployment
```

---

# 16. Canary deployment

Canary means:

```text
Send a small percentage of traffic to new version first.
```

Example:

```text
10% traffic to v2 for 5 minutes
then 100% if healthy
```

Good for:

```text
risky changes
public APIs
business-critical apps
```

---

# 17. Linear deployment

Linear means:

```text
Shift traffic gradually in equal increments.
```

Example:

```text
10% every 2 minutes
until 100%
```

Good for:

```text
controlled rollout
monitoring during deployment
lower blast radius
```

---

# 18. All-at-once deployment

All-at-once means:

```text
Move 100% traffic immediately.
```

Good for:

```text
dev/test
small internal apps
low-risk changes
```

Risk:

```text
if version is bad, all users are affected immediately
```

---

# 19. ECS blue/green deployment

For ECS, blue/green deployment creates a replacement environment and shifts traffic.

CodeDeploy can perform ECS blue/green deployments by installing the updated version as a new replacement task set. ([AWS Documentation][11])

ECS blue/green concepts:

```text
ECS service
ALB
production listener
test listener, optional
blue target group
green target group
task definition revision
CodeDeploy application
CodeDeploy deployment group
AppSpec file
```

High-level flow:

```text
Existing ECS service:
  task definition v1
  blue target group

New deployment:
  task definition v2
  green target group

CodeDeploy:
  creates replacement task set
  waits for health checks
  shifts ALB traffic
  monitors alarms
  rolls back if needed
```

Amazon ECS blue/green deployment documentation describes concepts such as production listeners, test listeners, target groups, and deployment lifecycle behavior. ([AWS Documentation][12])

---

# 20. appspec.yaml for ECS blue/green

For ECS CodeDeploy deployments, an AppSpec file tells CodeDeploy what ECS task definition and container details to deploy.

Example shape:

```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "<TASK_DEFINITION_ARN>"
        LoadBalancerInfo:
          ContainerName: "todo-api"
          ContainerPort: 3000
```

Production pipelines often generate this file dynamically during build.

---

# 21. taskdef.json

A task definition file defines the ECS container runtime config.

Example pieces:

```json
{
  "family": "todo-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "todo-api",
      "image": "<IMAGE_URI>",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ]
    }
  ]
}
```

During deployment:

```text
Pipeline replaces:
  <IMAGE_URI>

with:
  ECR image URI for this commit
```

---

# 22. CloudFormation in AWS DevOps

CloudFormation is AWS’s native infrastructure-as-code service.

In AWS-native pipelines, CloudFormation can deploy:

```text
VPC
ALB
ECS cluster
ECS service
RDS
IAM roles
Lambda
API Gateway
CloudWatch alarms
```

CodePipeline can integrate with CloudFormation capabilities for continuous delivery. ([AWS Documentation][9])

CloudFormation deployment pattern:

```text
Source
  ↓
Build/test/package
  ↓
CloudFormation change set
  ↓
Manual approval
  ↓
Execute change set
```

Important production concept:

```text
Do not apply infrastructure changes blindly.
Review the change set or Terraform plan first.
```

---

# 23. Terraform integration with AWS CI/CD

Even if you use AWS CodePipeline, you can still use Terraform.

Terraform pipeline:

```text
GitHub
  ↓
CodePipeline
  ↓
CodeBuild: terraform fmt
  ↓
CodeBuild: terraform validate
  ↓
CodeBuild: security/policy checks
  ↓
CodeBuild: terraform plan
  ↓
Manual approval
  ↓
CodeBuild: terraform apply
```

Production Terraform rules:

```text
remote state in S3
state locking
separate dev/staging/prod
plan artifact stored
manual approval before prod apply
least-privilege CI role
policy checks before apply
no secrets in tfvars
```

This fits directly with the Terraform/Ansible module you completed earlier.

---

# 24. Pipeline security model

Pipeline security is critical.

A CI/CD pipeline can create infrastructure, deploy code, pass IAM roles, read secrets, and modify production.

So treat it as highly privileged.

Minimum security rules:

```text
Use IAM roles, not long-lived access keys.
Use GitHub OIDC or AWS connections where possible.
Use least privilege service roles.
Restrict iam:PassRole.
Do not print secrets in logs.
Encrypt artifact buckets.
Enable CloudTrail.
Use manual approval for production.
Separate dev/staging/prod roles.
Use protected branches and required reviews.
```

Bad:

```text
GitHub secret:
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
with AdministratorAccess
```

Better:

```text
GitHub or CodePipeline assumes role
role has narrow permissions
role can deploy only required app/environment
```

---

# 25. CI/CD role types

A pipeline commonly has several roles.

```text
CodePipeline service role:
  orchestrates actions

CodeBuild service role:
  runs build commands

ECS task execution role:
  ECS pulls image and writes logs

ECS task role:
  app permissions inside container

CodeDeploy service role:
  controls deployment and traffic shifting

Terraform deploy role:
  creates/updates infrastructure

CloudFormation execution role:
  stack operations
```

Never confuse:

```text
Pipeline role:
  controls pipeline

Build role:
  builds artifact/image

Runtime role:
  app uses at runtime

Deployment role:
  changes production service
```

---

# 26. `iam:PassRole` in CI/CD

This is one of the most common AWS DevOps failures.

Example:

```text
CodeBuild or CloudFormation tries to create ECS service
with task execution role and task role.

It needs:
  iam:PassRole
```

Safe pattern:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": [
    "arn:aws:iam::123456789012:role/dev-ecs-task-execution-role",
    "arn:aws:iam::123456789012:role/dev-ecs-task-role"
  ],
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}
```

Bad pattern:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

---

# 27. Deployment health checks

A deployment is not successful just because the pipeline is green.

It is successful when:

```text
new tasks are healthy
ALB target group is healthy
app health endpoint returns 200
error rate is normal
latency is normal
logs show no startup crash
critical user flow works
```

Minimum validation:

```bash
curl -f https://app.example.com/health
curl -f https://app.example.com/api/health
```

For ECS:

```bash
aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Deployments:deployments[*].{Status:status,TaskDef:taskDefinition,Desired:desiredCount,Running:runningCount}}'
```

For ALB:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

---

# 28. Rollback strategies

Rollback depends on deployment type.

## ECS standard deployment rollback

You update ECS service back to previous task definition:

```bash
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --task-definition "$PREVIOUS_TASK_DEFINITION"
```

## ECS blue/green rollback

CodeDeploy can shift traffic back to the previous task set if deployment fails or alarms trigger.

## Lambda rollback

Use aliases:

```text
prod alias currently points to version 8
bad deploy points prod to version 9
rollback:
  point prod alias back to version 8
```

## S3/CloudFront frontend rollback

Use versioned artifacts:

```text
releases/
  2026-07-25-a1b2c3/
  2026-07-26-d4e5f6/

current release:
  CloudFront serves latest uploaded build

rollback:
  sync previous build
  invalidate index.html
```

## Terraform rollback

Terraform rollback is not always simple.

Better approach:

```text
review plan carefully
small changes
state backup
versioned modules
manual approval
change windows
```

For infrastructure, “rollback” often means a new corrective change, not simply pressing undo.

---

# 29. CI/CD quality gates

A production pipeline should have gates.

```text
Source gate:
  protected branch
  pull request review
  signed commits, optional

Build gate:
  compile/build succeeds

Test gate:
  unit tests
  integration tests
  contract tests

Security gate:
  dependency scan
  image scan
  secret scan
  IaC scan

Policy gate:
  Terraform plan policy
  no public SSH
  no public DB
  required tags
  encryption enabled

Approval gate:
  manual approval for staging/prod

Deployment gate:
  health checks
  canary/blue-green alarms

Post-deploy gate:
  error rate and latency normal
```

---

# 30. Deployment strategies comparison

| Strategy    |                Risk |  Speed | Rollback | Best for                 |
| ----------- | ------------------: | -----: | -------: | ------------------------ |
| All-at-once |                high |   fast |   medium | dev/test                 |
| Rolling     |              medium | medium |   medium | normal services          |
| Blue/green  |               lower | medium |     fast | production web apps      |
| Canary      | lowest blast radius | slower |     fast | risky production changes |
| Linear      |          controlled | slower |     fast | gradual rollout          |

Simple rule:

```text
Dev:
  all-at-once is okay

Staging:
  rolling or blue/green

Production:
  blue/green or canary for important apps
```

---

# 31. Hands-On Lab 16A — Build a Production AWS CI/CD Design Pack

This lab creates local files only.

No AWS resources.

Goal:

```text
Create reusable files for a containerized AWS deployment pipeline:
  buildspec.yml
  taskdef.json
  appspec.yaml
  imagedefinitions.json generator
  pipeline runbook
  rollback runbook
  IAM policy examples
```

---

## Step 1 — Create folder

```bash
mkdir -p ~/aws-masterclass/devops-aws/{app,pipeline,iam,runbooks,scripts,reports}
cd ~/aws-masterclass/devops-aws
```

---

## Step 2 — Create sample Node.js app

```bash
cat > app/package.json <<'EOF'
{
  "name": "aws-masterclass-devops-api",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "test": "node test.js",
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
EOF

cat > app/server.js <<'EOF'
const express = require("express");

const app = express();
const port = process.env.PORT || 3000;
const version = process.env.APP_VERSION || "local";

app.get("/", (req, res) => {
  res.json({
    message: "Hello from AWS DevOps pipeline",
    service: "aws-masterclass-devops-api",
    version
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
    service: "aws-masterclass-devops-api",
    version
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Server listening on ${port}`);
});
EOF

cat > app/test.js <<'EOF'
console.log("Running minimal test suite...");
console.log("PASS: application test placeholder");
EOF
```

---

## Step 3 — Create Dockerfile

```bash
cat > app/Dockerfile <<'EOF'
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY server.js .
COPY test.js .

ENV PORT=3000

EXPOSE 3000

CMD ["npm", "start"]
EOF

cat > app/.dockerignore <<'EOF'
node_modules
npm-debug.log
.git
.env
coverage
EOF
```

---

## Step 4 — Create buildspec.yml

```bash
cat > pipeline/buildspec.yml <<'EOF'
version: 0.2

env:
  shell: bash
  variables:
    APP_NAME: aws-masterclass-devops-api
    CONTAINER_NAME: aws-masterclass-devops-api
    AWS_REGION: ap-south-1

phases:
  install:
    runtime-versions:
      nodejs: 22
    commands:
      - echo "Install phase started"
      - node --version
      - npm --version

  pre_build:
    commands:
      - echo "Pre-build phase started"
      - cd app
      - npm ci
      - npm test
      - cd ..
      - ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
      - IMAGE_TAG="${CODEBUILD_RESOLVED_SOURCE_VERSION:-local}"
      - IMAGE_TAG="${IMAGE_TAG:0:12}"
      - REPOSITORY_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
      - echo "ACCOUNT_ID=${ACCOUNT_ID}"
      - echo "IMAGE_TAG=${IMAGE_TAG}"
      - echo "REPOSITORY_URI=${REPOSITORY_URI}"
      - aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

  build:
    commands:
      - echo "Build phase started"
      - docker build -t "${APP_NAME}:${IMAGE_TAG}" app
      - docker tag "${APP_NAME}:${IMAGE_TAG}" "${REPOSITORY_URI}:${IMAGE_TAG}"

  post_build:
    commands:
      - echo "Post-build phase started"
      - docker push "${REPOSITORY_URI}:${IMAGE_TAG}"
      - IMAGE_URI="${REPOSITORY_URI}:${IMAGE_TAG}"
      - printf '[{"name":"%s","imageUri":"%s"}]' "${CONTAINER_NAME}" "${IMAGE_URI}" > imagedefinitions.json
      - sed "s|<IMAGE_URI>|${IMAGE_URI}|g" pipeline/taskdef-template.json > taskdef.json
      - cp pipeline/appspec.yaml appspec.yaml
      - echo "Generated deployment artifacts:"
      - cat imagedefinitions.json
      - cat taskdef.json
      - cat appspec.yaml

artifacts:
  files:
    - imagedefinitions.json
    - taskdef.json
    - appspec.yaml
EOF
```

---

## Step 5 — Create ECS task definition template

```bash
cat > pipeline/taskdef-template.json <<'EOF'
{
  "family": "aws-masterclass-devops-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/aws-masterclass-ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/aws-masterclass-ecs-task-role",
  "containerDefinitions": [
    {
      "name": "aws-masterclass-devops-api",
      "image": "<IMAGE_URI>",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "PORT",
          "value": "3000"
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "wget -qO- http://localhost:3000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 20
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/aws-masterclass-devops-api",
          "awslogs-region": "ap-south-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF
```

Replace `<ACCOUNT_ID>` during real deployment.

---

## Step 6 — Create AppSpec for ECS blue/green

```bash
cat > pipeline/appspec.yaml <<'EOF'
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "TASK_DEFINITION"
        LoadBalancerInfo:
          ContainerName: "aws-masterclass-devops-api"
          ContainerPort: 3000
EOF
```

In a real CodeDeploy deployment, the pipeline or deployment action supplies the actual task definition revision.

---

## Step 7 — Create local artifact generator

This simulates what CodeBuild creates.

```bash
cat > scripts/generate-local-artifacts.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="${ACCOUNT_ID:-123456789012}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
APP_NAME="${APP_NAME:-aws-masterclass-devops-api}"
CONTAINER_NAME="${CONTAINER_NAME:-aws-masterclass-devops-api}"
IMAGE_TAG="${IMAGE_TAG:-local-dev}"
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}:${IMAGE_TAG}"

mkdir -p reports/artifacts

printf '[{"name":"%s","imageUri":"%s"}]\n' "${CONTAINER_NAME}" "${IMAGE_URI}" \
  > reports/artifacts/imagedefinitions.json

sed "s|<IMAGE_URI>|${IMAGE_URI}|g; s|<ACCOUNT_ID>|${ACCOUNT_ID}|g" \
  pipeline/taskdef-template.json \
  > reports/artifacts/taskdef.json

cp pipeline/appspec.yaml reports/artifacts/appspec.yaml

echo "Generated:"
echo "  reports/artifacts/imagedefinitions.json"
echo "  reports/artifacts/taskdef.json"
echo "  reports/artifacts/appspec.yaml"
EOF

chmod +x scripts/generate-local-artifacts.sh

./scripts/generate-local-artifacts.sh
```

View:

```bash
cat reports/artifacts/imagedefinitions.json
cat reports/artifacts/taskdef.json
cat reports/artifacts/appspec.yaml
```

---

## Step 8 — Create pipeline runbook

```bash
cat > runbooks/pipeline-runbook.md <<'EOF'
# AWS DevOps Pipeline Runbook

## Pipeline

Application:
Environment:
Repository:
Branch:
AWS Region:
ECR Repository:
ECS Cluster:
ECS Service:
ALB Target Group:

## Normal deployment flow

1. Developer opens pull request.
2. Tests and reviews pass.
3. Merge to protected branch.
4. CodePipeline source stage starts.
5. CodeBuild installs dependencies and runs tests.
6. Docker image is built.
7. Image is tagged with commit SHA.
8. Image is pushed to ECR.
9. Deployment artifact is generated.
10. ECS service is updated or CodeDeploy blue/green deployment starts.
11. ALB health checks validate new tasks.
12. Pipeline validates /health.
13. CloudWatch metrics are checked.

## Required checks

- Unit tests pass.
- Docker build succeeds.
- Image pushed to ECR.
- No secrets in logs.
- ECS tasks running count equals desired count.
- Target group healthy.
- /health returns 200.
- Error rate normal.
- Latency normal.

## Failure investigation

CodeBuild failed:
- Check build logs.
- Check npm/docker command.
- Check ECR login.
- Check IAM role permissions.

ECS deploy failed:
- Check ECS service events.
- Check target group health.
- Check container logs.
- Check task execution role.
- Check image URI/tag.

ALB health check failed:
- Check container port.
- Check /health route.
- Check ECS task SG from ALB SG.
- Check target group target type is ip for Fargate.

## Approval policy

Dev:
- automatic after tests

Staging:
- automatic or team approval

Production:
- manual approval
- change ticket
- rollback plan confirmed
EOF
```

---

## Step 9 — Create rollback runbook

```bash
cat > runbooks/rollback-runbook.md <<'EOF'
# Rollback Runbook

## Rollback triggers

- ALB 5xx exceeds threshold.
- Target group has unhealthy targets.
- New ECS tasks crash.
- Critical API /health fails.
- Database errors increase.
- Latency exceeds SLO.
- Security issue detected.

## ECS standard rollback

1. Find previous task definition:

aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].deployments[].taskDefinition'

2. Update service to previous task definition:

aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --task-definition "$PREVIOUS_TASK_DEFINITION"

3. Wait for stability:

aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME"

4. Validate:

curl -f "$APP_URL/health"

## ECS blue/green rollback

- Stop failed CodeDeploy deployment if still running.
- Let CodeDeploy shift traffic back if automatic rollback is configured.
- Confirm production listener routes to previous target group/task set.
- Validate old version health.

## Frontend CloudFront rollback

1. Sync previous release to S3.
2. Invalidate /index.html and critical paths.
3. Verify CloudFront response.
4. Monitor 4xx/5xx.

## Post-rollback

- Preserve failed logs.
- Record failed image tag/task definition.
- Open incident/postmortem.
- Fix pipeline gate if failure should have been caught earlier.
EOF
```

---

## Step 10 — Create IAM policy examples

CodeBuild ECR push policy example:

```bash
cat > iam/codebuild-ecr-policy-example.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcrAuth",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EcrPushPullSpecificRepo",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/aws-masterclass-devops-api"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CallerIdentity",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

ECS deployment policy example:

```bash
cat > iam/ecs-deploy-policy-example.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcsDeploy",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeTasks",
        "ecs:ListTasks"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PassOnlyEcsTaskRoles",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::123456789012:role/aws-masterclass-ecs-task-execution-role",
        "arn:aws:iam::123456789012:role/aws-masterclass-ecs-task-role"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
EOF
```

---

# 32. Optional Lab 16B — Local Docker Build Validation

This does not create AWS resources.

```bash
cd ~/aws-masterclass/devops-aws/app

docker build -t aws-masterclass-devops-api:local .

docker run --rm -p 3000:3000 \
  -e APP_VERSION=local \
  aws-masterclass-devops-api:local
```

In another terminal:

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
```

Stop with `Ctrl+C`.

---

# 33. Optional Lab 16C — AWS CodeBuild Project Design

Only run this when you are ready to create and clean up resources.

Billable/possibly chargeable resources:

```text
CodeBuild build minutes
CloudWatch Logs
S3 artifact bucket if used
ECR storage if image is pushed
```

High-level setup:

```text
1. Create ECR repo.
2. Create CodeBuild service role.
3. Attach least-privilege permissions.
4. Create CodeBuild project.
5. Connect source or upload source artifact.
6. Start build.
7. Verify ECR image.
8. Delete project, role, logs, ECR repo.
```

For now, your local Lab 16A gives you the files you need before spending anything.

---

# 34. Common CI/CD errors and fixes

## Error 1 — CodeBuild cannot push to ECR

Cause:

```text
missing ecr:GetAuthorizationToken
missing ecr:PutImage
missing upload layer permissions
wrong region
wrong repository ARN
repository does not exist
```

Fix:

```text
check CodeBuild service role
check ECR repository name
check AWS_REGION
check docker tag image URI
```

---

## Error 2 — ECS deployment fails with `iam:PassRole`

Cause:

```text
deployment role cannot pass task execution role or task role
```

Fix:

```text
add iam:PassRole for exact ECS task roles
condition iam:PassedToService = ecs-tasks.amazonaws.com
avoid Resource "*"
```

---

## Error 3 — ECS task cannot pull image

Cause:

```text
task execution role missing ECR permissions
private subnet lacks NAT or ECR VPC endpoints
wrong image URI
wrong image tag
ECR repo in different region/account
```

Fix:

```text
check task execution role
check ECR image exists
check subnet outbound path
check VPC endpoints for private-only architecture
```

---

## Error 4 — ALB target unhealthy after deploy

Cause:

```text
container listens on wrong port
app binds to 127.0.0.1 instead of 0.0.0.0
health check path wrong
security group missing ALB-to-task rule
target group target type wrong
new app crashes at startup
```

Fix:

```text
check ECS service events
check CloudWatch container logs
check target group health reason
verify /health locally
```

---

## Error 5 — Pipeline deployed wrong image

Cause:

```text
using latest tag
image tag overwritten
artifact mismatch
wrong ECR repo
wrong environment variable
manual deployment outside pipeline
```

Fix:

```text
use commit SHA image tags
store image URI artifact
disable manual production mutation
audit CloudTrail
```

---

## Error 6 — Terraform apply changed too much

Cause:

```text
no plan review
provider drift
wrong workspace
wrong tfvars
state mismatch
module version changed
```

Fix:

```text
separate plan and apply
store plan artifact
manual approval
workspace guard
policy-as-code
small changes
```

---

# 35. Production pipeline checklist

Before calling a pipeline production-ready:

```text
1. Source branch protected.
2. Pull request review required.
3. Build is reproducible.
4. Tests run automatically.
5. Docker image tagged with commit SHA.
6. Image pushed to ECR.
7. No secrets printed in logs.
8. Build role is least privilege.
9. Deploy role is least privilege.
10. iam:PassRole is restricted.
11. Artifact bucket encrypted.
12. CloudTrail enabled.
13. Dev/staging/prod separated.
14. Manual approval before prod.
15. Health checks after deploy.
16. CloudWatch alarms connected.
17. Rollback runbook exists.
18. Failed deployment preserves logs.
19. IaC changes use plan review.
20. Deployment is traceable to commit.
```

---

# 36. CI/CD security checklist

```text
Secrets:
  use Secrets Manager / Parameter Store
  never commit .env
  never echo secrets

IAM:
  no AdministratorAccess for pipeline
  use least privilege
  restrict PassRole
  separate build/deploy/runtime roles

Artifacts:
  encrypt artifact bucket
  restrict bucket access
  enable versioning when needed
  avoid public artifacts

Source:
  protected branches
  signed tags/releases when possible
  required reviews
  no direct prod deploy from feature branch

Build:
  dependency scan
  container scan
  secret scan
  IaC scan
  logs reviewed

Deploy:
  manual approval for prod
  blue/green or canary for critical services
  rollback tested
  alarms enabled
```

---

# 37. Resume-ready project takeaway

```text
Built an AWS production CI/CD design using CodePipeline, CodeBuild, ECR, ECS deployment artifacts, IAM least-privilege roles, health validation, rollback runbooks, and Terraform-ready infrastructure gates. Designed deployment artifacts such as buildspec.yml, imagedefinitions.json, taskdef.json, and appspec.yaml for containerized ECS delivery with production rollback and security controls.
```

---

# 38. Certification angle

## CLF-C02

Know:

```text
CodePipeline automates release workflows.
CodeBuild builds/tests code.
CodeDeploy automates deployments.
ECR stores container images.
CloudFormation provisions AWS infrastructure.
CloudWatch monitors deployments.
```

## SAA-C03

Know deeply:

```text
pipeline stages/actions/artifacts
CodeBuild buildspec
ECR image tagging
ECS deployment through CodePipeline
ALB health checks
blue/green vs rolling deployments
manual approval for prod
artifact encryption
least-privilege deployment roles
CloudFormation/Terraform deployment safety
```

## DOP-C02

Know operationally:

```text
blue/green ECS deployments
CodeDeploy traffic shifting
canary and linear deployments
deployment alarms and rollback
pipeline IAM design
iam:PassRole troubleshooting
artifact traceability
Terraform plan/apply pipelines
policy-as-code gates
multi-account CI/CD
incident response after failed deployment
```

---

# 39. Interview answer

Memorize this:

```text
On AWS, I design CI/CD pipelines using CodePipeline as the orchestrator, CodeBuild for build and test automation, ECR for container image storage, and ECS or CodeDeploy for deployment. A pipeline usually starts from GitHub through a CodeStar connection, then runs build, test, security, approval, and deploy stages.

For container workloads, CodeBuild builds a Docker image, tags it with the commit SHA, pushes it to ECR, and generates deployment artifacts such as imagedefinitions.json, taskdef.json, and appspec.yaml. The deploy stage updates an ECS service or starts a blue/green deployment. For production, I prefer blue/green or canary-style deployments for critical services because they reduce blast radius and allow faster rollback.

I secure the pipeline with least-privilege IAM roles, encrypted artifacts, protected branches, manual approval for production, no hardcoded secrets, and restricted iam:PassRole. I also separate build roles, deploy roles, runtime task roles, and task execution roles. For infrastructure, I integrate Terraform or CloudFormation with plan/change-set review, policy checks, and manual approval before production changes.

A deployment is successful only when the new version is healthy, ALB targets are passing health checks, CloudWatch alarms remain normal, logs show no startup errors, and critical smoke tests pass. If something fails, I roll back to the previous ECS task definition, previous Lambda alias version, previous frontend artifact, or corrective infrastructure change depending on the deployment type.
```

---

# 40. Quick quiz

```text
1. What is CodePipeline?
2. What is CodeBuild?
3. What is CodeDeploy?
4. What is ECR?
5. What is a pipeline artifact?
6. What is buildspec.yml?
7. What are CodeBuild phases?
8. Why should image tags use commit SHA?
9. What is imagedefinitions.json used for?
10. What is taskdef.json?
11. What is appspec.yaml?
12. What is in-place deployment?
13. What is blue/green deployment?
14. What is canary deployment?
15. What is linear deployment?
16. Why is iam:PassRole important in CI/CD?
17. Why should production have manual approval?
18. What should happen after deployment?
19. What is the safest rollback for ECS standard deployment?
20. Why should Terraform plan and apply be separated?
```

Answers:

```text
1. AWS continuous delivery pipeline orchestration service.
2. Managed build/test/package service.
3. AWS deployment automation service.
4. Elastic Container Registry for container images.
5. File/output passed between pipeline stages.
6. CodeBuild command/config file.
7. install, pre_build, build, post_build.
8. It makes deployments traceable and rollback reliable.
9. To tell ECS deploy action which container image to use.
10. ECS task definition JSON.
11. CodeDeploy deployment specification file.
12. Updating app on existing servers.
13. Running old and new environments, then shifting traffic.
14. Sending small traffic percentage to new version first.
15. Gradually shifting traffic in increments.
16. Services need it to pass roles to ECS/Lambda/EC2/CloudFormation.
17. To control risk before production changes.
18. Health checks, logs, metrics, and smoke tests should validate.
19. Update ECS service back to previous task definition.
20. To review infrastructure changes before applying them.
```

# Next Lesson

```text
AWS Lesson 17 — Multi-Account AWS Architecture:
AWS Organizations, organizational units, SCPs, Control Tower, IAM Identity Center, shared services account, logging account, security account, network account, workload accounts, cross-account roles, and landing zone design
```

[1]: https://docs.aws.amazon.com/codepipeline/latest/userguide/welcome.html?utm_source=chatgpt.com "What is AWS CodePipeline? - AWS CodePipeline"
[2]: https://docs.aws.amazon.com/codecommit/latest/userguide/history.html?utm_source=chatgpt.com "AWS CodeCommit User Guide document history - AWS CodeCommit"
[3]: https://docs.aws.amazon.com/codepipeline/latest/userguide/integrations-action-type.html?utm_source=chatgpt.com "Integrations with CodePipeline action types - AWS CodePipeline"
[4]: https://docs.aws.amazon.com/codepipeline/latest/userguide/welcome-introducing-artifacts.html?utm_source=chatgpt.com "Input and output artifacts - AWS CodePipeline"
[5]: https://docs.aws.amazon.com/codepipeline/latest/userguide/actions.html?utm_source=chatgpt.com "Use action types, custom actions, and approval actions - AWS CodePipeline"
[6]: https://docs.aws.amazon.com/codebuild/latest/userguide/concepts.html?utm_source=chatgpt.com "AWS CodeBuild concepts - AWS CodeBuild"
[7]: https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html?utm_source=chatgpt.com "Build specification reference for CodeBuild - AWS CodeBuild"
[8]: https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html?utm_source=chatgpt.com "Environment variables in build environments - AWS CodeBuild"
[9]: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-create.html?utm_source=chatgpt.com "Create a pipeline, stages, and actions - AWS CodePipeline"
[10]: https://docs.aws.amazon.com/codedeploy/latest/userguide/deployments.html?utm_source=chatgpt.com "Working with deployments in CodeDeploy - AWS CodeDeploy"
[11]: https://docs.aws.amazon.com/codedeploy/latest/userguide/welcome.html?utm_source=chatgpt.com "What is CodeDeploy? - AWS CodeDeploy"
[12]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-blue-green.html?utm_source=chatgpt.com "Amazon ECS blue/green deployments - Amazon Elastic Container Service"
