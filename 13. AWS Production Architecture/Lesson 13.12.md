# AWS Masterclass — Lesson 11

## Containers on AWS — Docker, ECR, ECS, Fargate, EKS, Task Definitions, Services, Load Balancing, Autoscaling, and Choosing EC2 vs ECS vs EKS vs Lambda

Today we move from:

```text id="old-way"
Install app directly on EC2
configure server manually
run process with systemd/PM2
patch server
repeat for every machine
```

to:

```text id="container-way"
Package app into container image
push image to registry
run image on ECS/EKS/Fargate
replace containers safely during deployment
scale containers automatically
```

Containers are one of the most important modern DevOps skills.

---

# 1. What is a container?

A container is a packaged runtime unit for an application.

It contains:

```text id="container-contains"
application code
runtime
libraries
dependencies
startup command
environment configuration
```

Simple meaning:

```text id="container-simple"
A container is a lightweight, portable package that runs your app in a consistent environment.
```

Example:

```text id="container-example"
Node.js app container:
  Node.js runtime
  package.json dependencies
  server.js
  startup command: node server.js
```

Without container:

```text id="without-container"
Server A has Node 18
Server B has Node 20
Server C missing dependency
Deployment breaks differently everywhere
```

With container:

```text id="with-container"
Build image once
Run same image everywhere
local laptop
EC2
ECS
EKS
CI/CD
```

---

# 2. Image vs container

Never confuse these two.

| Term      | Meaning                   | Analogy                  |
| --------- | ------------------------- | ------------------------ |
| Image     | packaged app template     | class / blueprint        |
| Container | running instance of image | object / running process |

Example:

```text id="image-container"
Image:
  todo-api:v1

Containers:
  todo-api container 1
  todo-api container 2
  todo-api container 3
```

An image is not running by itself.

A container is the running process created from that image.

---

# 3. Container registry

A registry stores container images.

Examples:

```text id="registries"
Amazon ECR
Docker Hub
GitHub Container Registry
GitLab Container Registry
Harbor
```

AWS container registry service:

```text id="ecr"
Amazon ECR = Elastic Container Registry
```

Amazon ECR is AWS’s fully managed container registry for storing, sharing, and deploying container images and artifacts. ([AWS Documentation][1])

Production flow:

```text id="registry-flow"
Developer / CI
  ↓ docker build
Container image
  ↓ docker push
Amazon ECR
  ↓ ECS/EKS pulls image
Running containers
```

---

# 4. What is ECS?

ECS means:

```text id="ecs-full"
Elastic Container Service
```

Simple meaning:

```text id="ecs-simple"
ECS is AWS's managed container orchestration service.
```

Orchestration means:

```text id="orchestration"
running containers
restarting failed containers
scaling containers
deploying new versions
connecting containers to load balancers
placing containers on compute capacity
```

Amazon ECS is a fully managed container orchestration service for deploying, managing, and scaling containerized applications. ([AWS Documentation][2])

Think:

```text id="ecs-analogy"
Docker:
  runs one container

ECS:
  manages many containers in production
```

---

# 5. ECS core concepts

ECS has these main building blocks:

```text id="ecs-blocks"
Cluster:
  logical group where containers run

Task definition:
  blueprint for running one or more containers

Task:
  running copy of a task definition

Service:
  keeps desired number of tasks running

Launch type / capacity:
  Fargate or EC2

Container image:
  image pulled from ECR or another registry

Task execution role:
  lets ECS pull image and write logs

Task role:
  permissions your application gets

Load balancer:
  sends traffic to healthy tasks
```

---

# 6. ECS cluster

An ECS cluster is a logical grouping.

```text id="cluster-simple"
Cluster = place where ECS manages tasks and services.
```

Example:

```text id="cluster-example"
dev-cluster
staging-cluster
prod-cluster
```

Important:

```text id="cluster-note"
An ECS cluster is not automatically a server.
With Fargate, AWS manages the compute.
With EC2 launch type, your EC2 instances provide the compute.
```

---

# 7. Task definition

Task definition is one of the most important ECS concepts.

Simple meaning:

```text id="task-def-simple"
Task definition = recipe/blueprint for running your container.
```

It defines:

```text id="task-def-contains"
container image
CPU and memory
container port
environment variables
secrets
IAM roles
logging
health checks
network mode
startup command
volume mounts
```

AWS describes ECS task definitions as blueprints for your application, and ECS services can launch replacement tasks from the task definition when tasks fail or stop. ([AWS Documentation][3])

Example:

```text id="task-def-example"
Task definition:
  family: todo-api
  image: ECR/todo-api:v1
  cpu: 256
  memory: 512
  container port: 3000
  logs: CloudWatch Logs
```

Never confuse:

```text id="task-def-never"
Task definition:
  blueprint

Task:
  running copy of blueprint
```

---

# 8. Task

A task is a running container workload.

```text id="task-simple"
Task = running instance of a task definition.
```

Example:

```text id="task-example"
Task definition:
  todo-api:1

Running tasks:
  task-abc
  task-def
  task-xyz
```

If you run desired count 3:

```text id="desired-3"
ECS runs 3 tasks from the same task definition.
```

---

# 9. ECS service

An ECS service keeps tasks running.

```text id="service-simple"
Service = controller that maintains desired number of tasks.
```

Example:

```text id="service-example"
Service:
  todo-api-service

Desired count:
  2

Meaning:
  ECS keeps 2 todo-api tasks running.
```

If one task dies:

```text id="service-replace"
ECS service scheduler launches another task.
```

AWS ECS services are used to run and maintain a specified number of task-definition instances simultaneously, and the service scheduler replaces tasks that fail or stop. ([AWS Documentation][4])

Production meaning:

```text id="service-prod"
For long-running web apps/APIs:
  use ECS service

For one-time batch job:
  use ECS run-task
```

---

# 10. Fargate

Fargate is serverless compute for containers.

Simple meaning:

```text id="fargate-simple"
With Fargate, you run containers without managing EC2 servers.
```

You define:

```text id="fargate-you-define"
container image
CPU
memory
network
IAM
logs
scaling
```

AWS manages:

```text id="fargate-aws"
underlying hosts
capacity placement
host patching
container runtime infrastructure
```

Amazon ECS can run services or tasks on AWS Fargate, where the serverless infrastructure is managed by ECS/Fargate instead of you managing EC2 container instances. ([AWS Documentation][5])

Use Fargate when:

```text id="fargate-use"
you want less infrastructure management
small/medium container apps
APIs
background workers
event-driven container jobs
teams without Kubernetes requirement
```

---

# 11. ECS on EC2

ECS can also run containers on EC2 instances.

Simple meaning:

```text id="ecs-ec2-simple"
You manage EC2 instances.
ECS schedules containers onto those instances.
```

You manage:

```text id="ec2-you-manage"
EC2 instance type
AMI
patching
cluster capacity
Auto Scaling Group
ECS agent
host-level security
bin packing
```

Use ECS on EC2 when:

```text id="ecs-ec2-use"
you need more control over host
special instance types
GPU workloads
very cost-optimized steady workloads
custom networking/daemon/agent needs
reserved capacity strategy
```

---

# 12. Fargate vs ECS on EC2

| Decision            | Fargate                                 | ECS on EC2                                       |
| ------------------- | --------------------------------------- | ------------------------------------------------ |
| Server management   | AWS manages                             | you manage EC2                                   |
| Operational effort  | lower                                   | higher                                           |
| Control             | less host control                       | more host control                                |
| Scaling             | task-level                              | task + instance capacity                         |
| Good for            | APIs, normal services, quick production | special workloads, cost tuning, GPU/host control |
| Beginner production | easier                                  | more moving parts                                |

Simple rule:

```text id="fargate-rule"
For most new simple containerized apps:
  start with ECS Fargate.

When you need host-level control or advanced cost optimization:
  consider ECS on EC2.
```

---

# 13. ECS networking

For Fargate, the common network mode is:

```text id="awsvpc"
awsvpc
```

Meaning:

```text id="awsvpc-simple"
Each task gets its own Elastic Network Interface,
private IP,
and security group.
```

Production placement:

```text id="ecs-placement"
ALB:
  public subnets

ECS Fargate tasks:
  private app subnets

Database:
  private database subnets
```

Architecture:

```text id="ecs-architecture"
User
  ↓
CloudFront
  ↓
ALB
  ↓
ECS Fargate tasks in private subnets
  ↓
RDS/DynamoDB/S3
```

---

# 14. Task execution role vs task role

This is exam and production critical.

## Task execution role

Used by ECS agent/platform.

It allows ECS to:

```text id="execution-role"
pull image from ECR
send logs to CloudWatch Logs
retrieve secrets for container startup
```

## Task role

Used by your application code inside the container.

It allows app to:

```text id="task-role"
read S3 object
write DynamoDB item
read Secrets Manager secret
publish SQS message
call AWS APIs
```

Never confuse:

```text id="role-never"
Execution role:
  ECS platform permissions

Task role:
  application permissions
```

Example:

```text id="role-example"
Execution role:
  pull image from ECR
  write logs

Task role:
  app reads s3://my-bucket/config.json
```

---

# 15. Load balancing with ECS

For a web/API service, you usually connect ECS service to ALB.

Flow:

```text id="ecs-alb-flow"
User
  ↓
ALB listener 80/443
  ↓
Target group
  ↓
ECS tasks
```

AWS recommends using Application Load Balancers for Amazon ECS services unless the service specifically needs NLB or GWLB-only capabilities. ([AWS Documentation][6])

Important difference from EC2 target groups:

```text id="target-type"
For ECS Fargate with awsvpc:
  target group target type = ip
```

Because:

```text id="why-ip-target"
Fargate task gets its own private IP.
ALB targets the task IP.
```

---

# 16. ECS deployment

When you push a new image:

```text id="deployment-flow"
1. Build new image.
2. Push to ECR.
3. Register new task definition revision.
4. Update ECS service.
5. ECS starts new tasks.
6. ALB health checks new tasks.
7. ECS stops old tasks after new tasks are healthy.
```

This is much cleaner than SSH-ing into EC2 and running commands manually.

Production deployment strategies:

```text id="deployment-types"
rolling deployment
blue/green deployment with CodeDeploy
canary-style traffic shifting through advanced patterns
```

---

# 17. Container logs

Containers should not write important logs only to local files.

Good pattern:

```text id="logs-good"
Application logs to stdout/stderr.
ECS sends logs to CloudWatch Logs.
```

Task definition logging:

```text id="logs-task-def"
log driver:
  awslogs

log group:
  /ecs/todo-api

stream prefix:
  ecs
```

Production monitoring:

```text id="logs-monitoring"
CloudWatch Logs
CloudWatch metrics
ALB target health
ECS service events
container health checks
application metrics
traces
```

---

# 18. Container health checks

There are two levels:

```text id="health-levels"
Container health check:
  inside ECS/container

ALB health check:
  load balancer checks HTTP endpoint
```

Good health endpoint:

```text id="health-good"
GET /health
returns 200 quickly
does not perform heavy database query
```

Bad health endpoint:

```text id="health-bad"
GET /
loads full frontend
calls slow external services
depends on heavy report query
```

---

# 19. Secrets in containers

Bad:

```text id="bad-secrets"
Put DB_PASSWORD directly in Dockerfile.
Commit .env file to Git.
Store AWS keys inside image.
```

Good:

```text id="good-secrets"
Store secrets in Secrets Manager or SSM Parameter Store.
Reference secrets in ECS task definition.
Give task execution role permission to read startup secrets.
Give task role only the application permissions needed.
```

Never build secrets into images.

```text id="secret-rule"
Container images should be reusable and non-secret.
Secrets should be injected securely at runtime.
```

---

# 20. What is EKS?

EKS means:

```text id="eks-full"
Elastic Kubernetes Service
```

Simple meaning:

```text id="eks-simple"
EKS is AWS-managed Kubernetes.
```

Amazon EKS is a managed service that lets you run Kubernetes on AWS without installing and operating your own Kubernetes clusters/control plane. ([AWS Documentation][7])

Since you already studied Kubernetes deeply, connect it like this:

```text id="eks-k8s-map"
Kubernetes cluster:
  EKS cluster

Pod:
  one or more containers

Deployment:
  desired state for Pods

Service:
  stable networking to Pods

Ingress:
  HTTP routing into cluster

Node:
  EC2 instance or managed node

Fargate profile:
  run selected Pods without managing nodes
```

---

# 21. EKS vs ECS

| Requirement                                   | ECS                        | EKS                    |
| --------------------------------------------- | -------------------------- | ---------------------- |
| AWS-native simple container orchestration     | excellent                  | possible, more complex |
| Kubernetes ecosystem required                 | no                         | yes                    |
| Team already strong in Kubernetes             | okay                       | strong fit             |
| Simpler learning curve                        | ECS                        | harder                 |
| Portability across clouds                     | less                       | more                   |
| Fine-grained Kubernetes controllers/operators | no                         | yes                    |
| Small production app                          | ECS Fargate usually easier | can be overkill        |
| Platform engineering at scale                 | possible                   | very strong            |

Simple rule:

```text id="ecs-eks-rule"
Use ECS when you want simple AWS-native container orchestration.
Use EKS when you specifically need Kubernetes ecosystem, APIs, portability, or platform engineering patterns.
```

---

# 22. ECS vs EKS vs Lambda vs EC2

This is interview-critical.

| Service     | Best when                                                       |
| ----------- | --------------------------------------------------------------- |
| EC2         | you need full server control                                    |
| ECS Fargate | you want simple containerized services without managing servers |
| ECS on EC2  | you want containers plus EC2 host control/cost tuning           |
| EKS         | you need Kubernetes                                             |
| Lambda      | event-driven functions, short-lived/serverless execution        |
| App Runner  | simple web app/container deployment with minimal infra control  |

Decision examples:

```text id="decision-examples"
Small Node.js API:
  ECS Fargate

Kubernetes-based platform:
  EKS

Simple event handler:
  Lambda

GPU model server:
  EC2, ECS on EC2, or EKS with GPU nodes

Static frontend:
  S3 + CloudFront

Legacy monolith needing OS control:
  EC2 first, then containerize later
```

---

# 23. Production container architecture

A strong AWS container architecture:

```text id="prod-container-arch"
Route 53
  ↓
CloudFront
  ↓
ALB public subnets
  ↓
ECS Fargate service private app subnets
  ↓
RDS private DB subnets
```

Supporting services:

```text id="supporting"
ECR:
  image registry

CloudWatch Logs:
  container logs

IAM:
  task execution role and task role

Secrets Manager:
  DB password/API keys

Auto Scaling:
  scale ECS tasks

VPC endpoints:
  private access to ECR, CloudWatch Logs, Secrets Manager, S3

WAF:
  protect CloudFront/ALB

CloudTrail:
  audit API actions
```

---

# 24. Hands-On Lab 11A — Build and Push a Container Image to ECR

This lab creates:

```text id="lab11a-create"
1 ECR repository
1 local Docker image
1 pushed image tag
```

Cost note:

```text id="lab11a-cost"
ECR image storage can generate small charges.
Delete the repository after the lab.
```

Region:

```text id="lab11a-region"
ap-south-1
```

---

## Step 1 — Set variables

```bash id="vars"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REPO_NAME="aws-masterclass-node-api"
IMAGE_TAG="v1"

echo "ACCOUNT_ID=$ACCOUNT_ID"
echo "REPO_NAME=$REPO_NAME"
```

---

## Step 2 — Create a tiny Node.js app

```bash id="create-app"
mkdir -p ~/aws-masterclass/containers/node-api
cd ~/aws-masterclass/containers/node-api

cat > package.json <<'EOF'
{
  "name": "aws-masterclass-node-api",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
EOF

cat > server.js <<'EOF'
const express = require("express");

const app = express();
const port = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.json({
    message: "Hello from AWS containers",
    service: "aws-masterclass-node-api",
    version: "v1"
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({ status: "healthy" });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Server listening on port ${port}`);
});
EOF
```

---

## Step 3 — Create Dockerfile

```bash id="dockerfile"
cat > Dockerfile <<'EOF'
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY server.js .

ENV PORT=3000

EXPOSE 3000

CMD ["npm", "start"]
EOF
```

Add `.dockerignore`:

```bash id="dockerignore"
cat > .dockerignore <<'EOF'
node_modules
npm-debug.log
.git
.env
EOF
```

---

## Step 4 — Build and test locally

```bash id="docker-build"
docker build -t "$REPO_NAME:$IMAGE_TAG" .
```

Run locally:

```bash id="docker-run"
docker run --rm -p 3000:3000 "$REPO_NAME:$IMAGE_TAG"
```

In another terminal:

```bash id="curl-local"
curl http://localhost:3000/
curl http://localhost:3000/health
```

Stop the container with `Ctrl+C`.

---

## Step 5 — Create ECR repository

```bash id="create-ecr"
aws ecr create-repository \
  --repository-name "$REPO_NAME" \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --tags Key=Project,Value=aws-masterclass Key=Environment,Value=dev
```

Get repository URI:

```bash id="repo-uri"
REPO_URI="$(aws ecr describe-repositories \
  --repository-names "$REPO_NAME" \
  --query 'repositories[0].repositoryUri' \
  --output text)"

echo "REPO_URI=$REPO_URI"
```

---

## Step 6 — Login Docker to ECR

```bash id="ecr-login"
aws ecr get-login-password --region ap-south-1 \
  | docker login \
      --username AWS \
      --password-stdin "${ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com"
```

---

## Step 7 — Tag and push image

```bash id="tag-push"
docker tag "$REPO_NAME:$IMAGE_TAG" "$REPO_URI:$IMAGE_TAG"

docker push "$REPO_URI:$IMAGE_TAG"
```

Validate:

```bash id="validate-ecr"
aws ecr describe-images \
  --repository-name "$REPO_NAME" \
  --query 'imageDetails[].{Tags:imageTags,PushedAt:imagePushedAt,Size:imageSizeInBytes}' \
  --output table
```

---

# 25. Optional Lab 11B — Run the Image on ECS Fargate

This lab creates billable resources:

```text id="lab11b-resources"
ECS cluster
CloudWatch log group
IAM roles
task definition
one Fargate task
security group
public IP for simple test
```

This is simpler than full ALB service. It runs one public test task, then you delete it.

Production will use private subnets behind ALB later.

---

## Step 1 — Create ECS cluster

```bash id="create-cluster"
aws ecs create-cluster \
  --cluster-name aws-masterclass-ecs-cluster \
  --tags key=Project,value=aws-masterclass key=Environment,value=dev
```

---

## Step 2 — Create CloudWatch log group

```bash id="create-log-group"
aws logs create-log-group \
  --log-group-name /ecs/aws-masterclass-node-api || true
```

---

## Step 3 — Create task execution role

Create trust policy:

```bash id="ecs-trust"
cat > /tmp/ecs-task-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create role:

```bash id="create-execution-role"
aws iam create-role \
  --role-name aws-masterclass-ecs-task-execution-role \
  --assume-role-policy-document file:///tmp/ecs-task-trust-policy.json
```

Attach AWS managed execution policy:

```bash id="attach-execution-policy"
aws iam attach-role-policy \
  --role-name aws-masterclass-ecs-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

Wait a little for IAM propagation:

```bash id="iam-wait"
sleep 20
```

Get role ARN:

```bash id="exec-role-arn"
EXEC_ROLE_ARN="$(aws iam get-role \
  --role-name aws-masterclass-ecs-task-execution-role \
  --query 'Role.Arn' \
  --output text)"

echo "$EXEC_ROLE_ARN"
```

---

## Step 4 — Register task definition

```bash id="taskdef"
cat > /tmp/node-api-taskdef.json <<EOF
{
  "family": "aws-masterclass-node-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "${EXEC_ROLE_ARN}",
  "containerDefinitions": [
    {
      "name": "node-api",
      "image": "${REPO_URI}:${IMAGE_TAG}",
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
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/aws-masterclass-node-api",
          "awslogs-region": "ap-south-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

aws ecs register-task-definition \
  --cli-input-json file:///tmp/node-api-taskdef.json
```

---

## Step 5 — Get default VPC and subnet for quick lab

```bash id="network"
VPC_ID="$(aws ec2 describe-vpcs \
  --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' \
  --output text)"

SUBNET_ID="$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
  --query 'Subnets[0].SubnetId' \
  --output text)"

echo "VPC_ID=$VPC_ID"
echo "SUBNET_ID=$SUBNET_ID"
```

Create security group:

```bash id="ecs-sg"
ECS_SG_ID="$(aws ec2 create-security-group \
  --group-name aws-masterclass-ecs-task-sg \
  --description "ECS Fargate test task SG" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)"

aws ec2 authorize-security-group-ingress \
  --group-id "$ECS_SG_ID" \
  --ip-permissions '[
    {
      "IpProtocol": "tcp",
      "FromPort": 3000,
      "ToPort": 3000,
      "IpRanges": [
        {
          "CidrIp": "0.0.0.0/0",
          "Description": "temporary public test access"
        }
      ]
    }
  ]'

echo "ECS_SG_ID=$ECS_SG_ID"
```

This public rule is for a short lab only. In production, traffic should come from ALB security group.

---

## Step 6 — Run one Fargate task

```bash id="run-task"
TASK_ARN="$(aws ecs run-task \
  --cluster aws-masterclass-ecs-cluster \
  --launch-type FARGATE \
  --task-definition aws-masterclass-node-api \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$ECS_SG_ID],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)"

echo "TASK_ARN=$TASK_ARN"
```

Wait:

```bash id="wait-task"
aws ecs wait tasks-running \
  --cluster aws-masterclass-ecs-cluster \
  --tasks "$TASK_ARN"
```

---

## Step 7 — Get task public IP

```bash id="get-task-ip"
ENI_ID="$(aws ecs describe-tasks \
  --cluster aws-masterclass-ecs-cluster \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value | [0]' \
  --output text)"

PUBLIC_IP="$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$ENI_ID" \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)"

echo "PUBLIC_IP=$PUBLIC_IP"
```

Test:

```bash id="test-task"
curl "http://${PUBLIC_IP}:3000/"
curl "http://${PUBLIC_IP}:3000/health"
```

---

## Step 8 — Check logs

```bash id="logs"
aws logs describe-log-streams \
  --log-group-name /ecs/aws-masterclass-node-api \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

---

# 26. Cleanup Labs 11A and 11B

## Stop ECS task

```bash id="stop-task"
aws ecs stop-task \
  --cluster aws-masterclass-ecs-cluster \
  --task "$TASK_ARN" \
  --reason "Lab cleanup"
```

Wait:

```bash id="wait-stopped"
aws ecs wait tasks-stopped \
  --cluster aws-masterclass-ecs-cluster \
  --tasks "$TASK_ARN"
```

## Delete security group

```bash id="delete-sg"
aws ec2 delete-security-group \
  --group-id "$ECS_SG_ID"
```

## Delete ECS cluster

```bash id="delete-cluster"
aws ecs delete-cluster \
  --cluster aws-masterclass-ecs-cluster
```

## Delete IAM role

```bash id="delete-role"
aws iam detach-role-policy \
  --role-name aws-masterclass-ecs-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam delete-role \
  --role-name aws-masterclass-ecs-task-execution-role
```

## Delete log group

```bash id="delete-log-group"
aws logs delete-log-group \
  --log-group-name /ecs/aws-masterclass-node-api
```

## Delete ECR repository and image

```bash id="delete-ecr"
aws ecr delete-repository \
  --repository-name "$REPO_NAME" \
  --force
```

Verify:

```bash id="verify-cleanup"
aws ecr describe-repositories \
  --repository-names "$REPO_NAME" || true

aws ecs describe-clusters \
  --clusters aws-masterclass-ecs-cluster
```

---

# 27. Full production ECS service pattern

For production, instead of running one public task, use:

```text id="prod-service-pattern"
VPC:
  public subnets
  private app subnets
  private database subnets

ALB:
  public subnets

ECS Fargate service:
  private app subnets
  assignPublicIp = DISABLED

Target group:
  target type = ip

Security:
  ALB SG allows 80/443 from internet
  ECS task SG allows app port only from ALB SG

Database:
  RDS SG allows DB port only from ECS task SG
```

Architecture:

```text id="prod-ecs-arch"
User
  ↓
Route 53
  ↓
CloudFront
  ↓
ALB
  ↓
ECS Fargate tasks
  ↓
RDS / DynamoDB / S3
```

---

# 28. ECS autoscaling

ECS services can scale task count.

Scale based on:

```text id="ecs-scaling-metrics"
CPU utilization
memory utilization
ALB request count per target
SQS queue depth
custom CloudWatch metrics
```

Example:

```text id="ecs-scale-example"
desired tasks = 2

CPU > 60%:
  scale out to 3, 4, 5

CPU low:
  scale in to 2
```

Production rule:

```text id="scale-rule"
Scale on the bottleneck.
API often scales on CPU or ALB request count.
Queue workers often scale on queue depth.
Memory-heavy apps need memory metrics.
```

---

# 29. Common container mistakes

## Mistake 1 — Building secrets into image

Bad:

```dockerfile id="bad-docker-secret"
ENV DB_PASSWORD=mysecret
```

Good:

```text id="good-secret-pattern"
Secrets Manager / SSM Parameter Store
runtime injection
least-privilege IAM role
```

---

## Mistake 2 — Running app on localhost only

Bad app binding:

```text id="bad-bind"
app.listen(3000, "127.0.0.1")
```

Good:

```text id="good-bind"
app.listen(3000, "0.0.0.0")
```

Why?

```text id="bind-why"
Inside a container, binding to 127.0.0.1 can make the app unreachable from outside the container.
```

---

## Mistake 3 — Wrong target group type

For ECS Fargate:

```text id="fargate-target"
target group target type:
  ip
```

Not:

```text id="wrong-target"
instance
```

---

## Mistake 4 — Confusing execution role and task role

Fix:

```text id="role-fix"
Image pull/logs:
  execution role

App AWS permissions:
  task role
```

---

## Mistake 5 — No logs

Bad:

```text id="bad-logs"
Container writes only to local file.
No CloudWatch Logs configured.
```

Good:

```text id="good-logs-pattern"
stdout/stderr
awslogs driver
CloudWatch Logs group
structured JSON logs where possible
```

---

## Mistake 6 — Public ECS tasks in production

Bad:

```text id="bad-public-task"
Fargate task with public IP
security group open to internet
```

Good:

```text id="good-private-task"
Fargate task in private subnet
no public IP
ALB forwards traffic
task SG allows only ALB SG
```

---

# 30. Troubleshooting ECS

## Task does not start

Check service/task events:

```bash id="task-events"
aws ecs describe-tasks \
  --cluster aws-masterclass-ecs-cluster \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].{LastStatus:lastStatus,DesiredStatus:desiredStatus,StoppedReason:stoppedReason,Containers:containers[].{Name:name,LastStatus:lastStatus,Reason:reason,ExitCode:exitCode}}'
```

Common causes:

```text id="task-start-causes"
image not found
ECR permission issue
wrong execution role
CPU/memory invalid
container exits immediately
bad command
secret permission missing
subnet has no outbound path
```

---

## Cannot pull image

Check:

```text id="pull-check"
ECR repository exists
image tag exists
task execution role has ECR permissions
private subnet has NAT or ECR VPC endpoints
correct account/region image URI
```

---

## ALB target unhealthy

Check:

```text id="alb-unhealthy-check"
container listens on correct port
task security group allows ALB SG
target group health path returns 200
target group target type is ip
service attached to correct target group
task is in subnet enabled for ALB routing
```

---

## Logs missing

Check:

```text id="logs-check"
awslogs log driver configured
log group exists or execution role can create it
execution role has logs permissions
container starts long enough to emit logs
correct AWS region in log config
```

---

# 31. Certification angle

## CLF-C02

Know:

```text id="clf"
Containers package applications and dependencies.
ECR stores container images.
ECS runs and manages containers.
Fargate runs containers without managing servers.
EKS is managed Kubernetes.
```

## SAA-C03

Know deeply:

```text id="saa"
ECS cluster/task definition/task/service
Fargate vs ECS on EC2
task execution role vs task role
ALB with ECS service
target group type ip for Fargate
private subnet ECS tasks
ECR image pull permissions
container logs to CloudWatch
ECS service autoscaling
EKS when Kubernetes is required
```

## DOP-C02

Know operationally:

```text id="dop"
CI/CD image build and push to ECR
task definition revision deployments
blue/green deployment with ECS and CodeDeploy
rollback by previous task definition
CloudWatch logs and metrics
service events troubleshooting
container health checks
secrets injection
image scanning
least-privilege IAM for pipelines and tasks
```

---

# 32. Interview answer

Memorize this:

```text id="interview-answer"
Containers package an application with its runtime and dependencies so the same image can run consistently across local development, CI/CD, and production. On AWS, I store container images in Amazon ECR and run them using ECS, EKS, or another compute option depending on requirements.

Amazon ECS is AWS’s managed container orchestration service. In ECS, a task definition is the blueprint that defines the container image, CPU, memory, ports, environment variables, secrets, logging, and IAM roles. A task is a running copy of that definition, and an ECS service maintains the desired number of running tasks and replaces failed tasks. With Fargate, AWS manages the underlying compute, so I only define the container, resources, networking, IAM, and scaling.

For production web services, I usually run ECS Fargate tasks in private app subnets with no public IP, behind an Application Load Balancer in public subnets. The ALB target group uses target type ip for Fargate. The ALB security group accepts internet traffic on 80/443, and the ECS task security group allows application traffic only from the ALB security group. I use a task execution role for pulling images and sending logs, and a separate task role for application permissions such as reading S3 or DynamoDB. I use CloudWatch Logs, health checks, autoscaling, Secrets Manager, and least-privilege IAM.

I choose ECS Fargate for simpler AWS-native container workloads, ECS on EC2 when I need host-level control or special instance types, EKS when Kubernetes APIs and ecosystem are required, Lambda for event-driven functions, and EC2 when I need full server control.
```

---

# 33. Quick quiz

```text id="quiz"
1. What is a container?
2. What is a container image?
3. What is a registry?
4. What is ECR?
5. What is ECS?
6. What is Fargate?
7. What is an ECS cluster?
8. What is a task definition?
9. What is a task?
10. What is an ECS service?
11. What is the difference between task execution role and task role?
12. What target group type is used for Fargate?
13. Where should production ECS tasks run?
14. Should production Fargate tasks have public IPs?
15. What is EKS?
16. When should you choose EKS?
17. When should you choose ECS Fargate?
18. Why should apps bind to 0.0.0.0 inside containers?
19. Where should container logs go?
20. Why should secrets not be built into images?
```

Answers:

```text id="answers"
1. Packaged runtime unit for an application.
2. Template used to create containers.
3. Place to store container images.
4. AWS managed container registry.
5. AWS managed container orchestration service.
6. Serverless compute for containers.
7. Logical group where ECS runs tasks/services.
8. Blueprint defining container image, CPU, memory, ports, roles, logs, etc.
9. Running copy of task definition.
10. Controller that maintains desired number of tasks.
11. Execution role is for ECS platform actions; task role is for app AWS permissions.
12. ip.
13. Private app subnets behind ALB.
14. Usually no.
15. AWS managed Kubernetes.
16. When Kubernetes ecosystem/APIs/portability are required.
17. When you want simple AWS-native serverless containers.
18. So traffic can reach the app from outside the container.
19. stdout/stderr to CloudWatch Logs.
20. Images can leak and should be reusable; secrets must be injected securely at runtime.
```

---

# Next Lesson

```text id="next"
AWS Lesson 12 — Serverless on AWS:
Lambda, API Gateway, DynamoDB, SQS, SNS, EventBridge, Step Functions, IAM roles, cold starts, retries, DLQs, event-driven architecture, and choosing serverless vs containers
```

[1]: https://docs.aws.amazon.com/ecr/?icmpid=docs_homepage_containers&utm_source=chatgpt.com "Amazon Elastic Container Registry Documentation"
[2]: https://docs.aws.amazon.com/ecs/?utm_source=chatgpt.com "Amazon Elastic Container Service Documentation"
[3]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html?utm_source=chatgpt.com "Amazon ECS task definitions - Amazon Elastic Container Service"
[4]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html?utm_source=chatgpt.com "Amazon ECS services - Amazon Elastic Container Service"
[5]: https://docs.aws.amazon.com/AmazonECS/latest/APIReference/Welcome.html?utm_source=chatgpt.com "Welcome - Amazon Elastic Container Service"
[6]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-load-balancing.html?utm_source=chatgpt.com "Use load balancing to distribute Amazon ECS service traffic - Amazon Elastic Container Service"
[7]: https://docs.aws.amazon.com/eks/?utm_source=chatgpt.com "Amazon Elastic Kubernetes Service Documentation"
