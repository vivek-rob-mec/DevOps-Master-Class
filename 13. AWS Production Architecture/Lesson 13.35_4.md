AWS Masterclass — Lesson 35 Part 4
ECS Production Security, ECR Supply Chain, CI/CD & Complete Container Platform Capstone

In the previous three parts we built:

Part 1
────────────
ECS fundamentals
Cluster
Task Definition
Task
Service
Fargate / EC2 / Managed Instances


Part 2
────────────
Production traffic
ALB
Health checks
Rolling deployment
Blue/Green
Canary
Rollback


Part 3
────────────
Production operations
Auto Scaling
Fargate Spot
Container Insights
FireLens
Cost optimization

Now we secure the entire software supply chain:

Developer
    │
    ▼
   Git
    │
    ▼
CI Pipeline
    │
    ├── test source
    ├── dependency scan
    ├── build container
    ├── scan image
    ├── sign image
    └── identify immutable digest
    │
    ▼
   ECR
    │
    ├── immutable tags
    ├── lifecycle policy
    ├── Inspector scanning
    ├── AWS Signer signatures
    └── repository policies
    │
    ▼
Task Definition Revision
    │
    ▼
ECS Deployment
    │
    ├── verify artifact
    ├── health validation
    ├── CloudWatch alarms
    ├── circuit breaker
    └── rollback
    │
    ▼
Production Tasks
    │
    ├── non-root
    ├── read-only root FS
    ├── least-privilege IAM
    ├── Secrets Manager
    └── GuardDuty Runtime Monitoring

This is the difference between:

"We deployed a Docker container."

and:

"We operate a production container platform."
Part A — The Container Supply Chain

A production container does not begin at ECS.

It begins here:

source code
    │
    ▼
dependencies
    │
    ▼
Dockerfile
    │
    ▼
base image
    │
    ▼
container image
    │
    ▼
registry
    │
    ▼
task definition
    │
    ▼
ECS

An attacker or mistake can enter at any layer:

malicious dependency

compromised base image

secret copied into image

mutable production tag

unscanned vulnerability

overprivileged IAM role

unsigned artifact

manual deployment mistake

So the security problem is:

Software Supply Chain Security
1. Build Once, Deploy Many

A critical production principle is:

BUILD ONCE

PROMOTE THE SAME ARTIFACT

not:

Build dev image

Build staging image again

Build production image again

If you rebuild for every environment:

dev artifact
≠
staging artifact
≠
production artifact

even when they came from the same Git commit.

Different package download timing, base layers, build inputs, or dependency resolution can produce different artifacts.

A stronger pattern is:

Git SHA:
abc123
   │
   ▼
Build exactly once
   │
   ▼
Image digest:
sha256:9f3...
   │
   ├── deploy Dev
   ├── promote Stage
   └── promote Prod

AWS recommends uniquely versioning container images—commonly with the Git commit SHA—and using immutable ECR image tags rather than relying on latest.

Part B — Amazon ECR
2. What Is ECR?

Amazon Elastic Container Registry is AWS's managed OCI-compatible container registry and integrates directly with ECS for private-image storage and retrieval.

Mental model:

Docker Build
    │
    ▼
Container Image
    │
    ▼
Amazon ECR
    │
    ▼
ECS Task

For your backend:

dev-todo-backend

might contain:

abc123
abc124
v1.4.0
v1.4.1
3. Repository vs Registry

Understand:

AWS Account / Region
       │
       ▼
   ECR Registry
       │
       ├── todo-api
       ├── todo-worker
       ├── frontend
       └── migrations

A repository stores versions/artifacts for a logical image.

Example:

123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api
Part C — Never Deploy latest to Production
4. Why latest Is Dangerous

Suppose:

todo-api:latest

currently means:

sha256:AAA

Tomorrow somebody pushes:

todo-api:latest

again.

Now:

latest
→ sha256:BBB

Your deployment configuration still says:

todo-api:latest

but its meaning changed.

That destroys:

repeatability

auditability

predictable rollback

AWS's ECS image guidance recommends using unique tags such as the Git SHA and reserving latest primarily for testing.

5. Better Tags

Use:

git SHA

Example:

todo-api:4c8af91

or:

semantic release
todo-api:v2.8.3

A strong pipeline often records both:

Git SHA
+
ECR image digest

Example:

Git:
4c8af91

ECR:
sha256:f934a80...
Part D — Image Digest
6. Tag vs Digest

A tag is a human-friendly reference:

todo-api:v2.8.3

A digest identifies actual image content:

todo-api@sha256:f9328c...

Think:

TAG
=
name/pointer


DIGEST
=
content identity
7. Strongest Artifact Identity

Deployment by tag:

todo-api:v2.8.3

is good when tags are immutable.

Deployment by digest:

todo-api@sha256:abc123...

is stronger still because it explicitly names the artifact content.

Current ECS service behavior also resolves tagged container images to digests during service deployment so tasks in a service use consistent image content. Once established, ECS reuses that digest for the service revision.

So modern ECS gives you two useful layers:

immutable human-readable tag

+

ECS resolved image digest
8. Why Explicit Digest Pinning Is Still Valuable

If your task definition says:

image =
repository@sha256:abcdef...

there is no ambiguity about:

WHAT BINARY
should run?

This is especially useful for:

production promotion

audit evidence

security approval

incident reconstruction

deterministic rollback
Part E — ECR Tag Immutability
9. Immutable Repository

Create:

aws ecr create-repository \
  --repository-name todo-api \
  --image-tag-mutability IMMUTABLE \
  --region ap-south-1

Then:

push todo-api:abc123
→ success


push different image
again as abc123
→ rejected

ECR returns ImageTagAlreadyExistsException when an immutable existing tag is overwritten.

10. Important 2026 ECR Update — Immutability Exclusions

Modern ECR now also exposes:

IMMUTABLE_WITH_EXCLUSION

MUTABLE_WITH_EXCLUSION

and wildcard exclusion filters.

For example, a repository can conceptually enforce:

all build tags:
IMMUTABLE

except:
latest
development

using exclusion patterns.

This is useful where you want:

abc123       immutable
v2.8.0       immutable

latest       mutable convenience pointer

But for production deployments:

do not deploy latest anyway.
Part F — ECR Lifecycle Policies

Without cleanup:

Build #1   image
Build #2   image
Build #3   image
...
Build #10,000 image

ECR becomes:

old artifacts
+
storage cost
+
operational clutter

Use:

Lifecycle Policies

ECR lifecycle policies can automatically expire or, under current lifecycle capabilities, archive matching images based on rule criteria; AWS recommends previewing a lifecycle policy before applying it.

11. Example Retention Strategy

Keep:

last 30 production releases

last 20 staging releases

remove untagged images after 7 days

Example conceptual lifecycle rule:

{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire old untagged images",

      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },

      "action": {
        "type": "expire"
      }
    }
  ]
}

ECR lifecycle policies support image selection based on tag status/patterns and age/count criteria.

12. Do Not Delete Your Rollback Artifact

Suppose production runs:

v2.8.5

and lifecycle cleanup removes:

v2.8.4

Then your rollback path may become:

Task Definition v42
      │
      ▼
Image no longer exists
      │
      ▼
CannotPullContainerError

So coordinate:

ECR retention window

with:

deployment rollback window.

Current ECS documentation specifically calls out failures when the image backing an established service version is no longer available.

Part G — Image Vulnerability Scanning

An image can deploy successfully while containing:

vulnerable OpenSSL

vulnerable Node package

vulnerable OS library

old runtime

known CVE

Use ECR scanning.

Current ECR provides two scanning modes:

BASIC

ENHANCED

13. Basic Scanning

Current Basic scanning covers:

operating-system vulnerabilities

and can be:

manual

or

scan on push

Useful for:

simple environments

basic container hygiene
14. Enhanced Scanning

Enhanced scanning integrates ECR with:

Amazon Inspector

and supports vulnerabilities in:

operating-system packages

+

programming-language packages

with:

scan on push

or

continuous scanning

This matters for Node.js because you don't only care about:

libssl
glibc

but also application dependency vulnerabilities.

15. Continuous Scanning

This is extremely important.

Suppose Monday:

image built
scan:
0 critical CVEs

Wednesday:

new CVE disclosed

You never rebuilt the image.

With continuous Enhanced scanning, Inspector can update findings as new vulnerabilities become known and can emit findings/events through AWS integrations such as EventBridge.

Meaning:

IMAGE DID NOT CHANGE

but

SECURITY KNOWLEDGE CHANGED.
16. Production Scanning Strategy

A strong pattern:

Development repos
→ scan on push

Production repos
→ continuous enhanced scanning

Current ECR enhanced scanning configuration is registry/Region-level and supports repository filters that determine which repositories are continuously scanned versus scan-on-push.

Part H — CI Vulnerability Gate

The pipeline should not simply:

docker push
→ deploy

Instead:

Push Image
    │
    ▼
Security Scan
    │
    ▼
Any unacceptable findings?
    │
 ┌──┴────┐
YES      NO
 │        │
 ▼        ▼
FAIL    SIGN
pipeline   │
           ▼
         DEPLOY

Your policy may be:

Critical vulnerabilities:
0 allowed

High vulnerabilities:
approved exception required

Medium:
track/remediate according to SLA

The exact threshold is an organizational security policy rather than an ECR service rule.

Part I — Image Signing

Scanning asks:

Does this artifact contain
known vulnerabilities?

Signing asks:

Can I trust
WHERE this artifact came from

and

whether it was tampered with?

Different problems.

17. Current 2026 ECR Signing Model

Amazon ECR integrates with AWS Signer and supports two image-signing approaches:

Managed signing
→ automatic
→ recommended by AWS

Manual signing
→ Notation CLI
→ AWS Signer plugin

Signatures are stored alongside the container image in ECR.

This is an important modern capability older ECS courses may not include.

18. Managed Signing

Current ECR Managed Signing works like:

CI
 │
 ▼
Push Image
 │
 ▼
ECR
 │
 ▼
Signing configuration matches repo
 │
 ▼
AWS Signer
 │
 ▼
Cryptographic signature generated
 │
 ▼
Signature stored in ECR

Amazon ECR can automatically sign images as they are pushed using configured AWS Signer signing profiles and repository filters.

19. Signing Configuration

Conceptually:

{
  "rules": [
    {
      "signingProfileArn":
        "arn:aws:signer:ap-south-1:123456789012:/signing-profiles/prodEcr",

      "repositoryFilters": [
        {
          "filter": "prod-*",
          "filterType": "WILDCARD_MATCH"
        }
      ]
    }
  ]
}

Then:

aws ecr put-signing-configuration \
  --signing-configuration file://signing-config.json \
  --region ap-south-1

ECR currently allows multiple signing rules in a registry and requires the signing profile to be in the same Region as the ECR registry; cross-account signing profiles are supported.

20. Check Signing Status
aws ecr describe-image-signing-status \
  --repository-name todo-api \
  --image-id imageTag=4c8af91 \
  --region ap-south-1

Current managed-signing documentation exposes this workflow for checking whether signing succeeded.

Part J — Signing Is Only Useful If You Verify

This is extremely important:

SIGNED
+
NEVER VERIFIED
=
weak security control

Desired architecture:

Build
 │
 ▼
Sign
 │
 ▼
ECR
 │
 ▼
Deployment
 │
 ▼
VERIFY SIGNATURE
 │
 ├── trusted
 │      ▼
 │    continue
 │
 └── untrusted
        ▼
      BLOCK
21. ECS Signature Verification

As of current AWS guidance, ECS does not simply behave like a universal built-in EKS-style admission verifier. AWS documents using ECS service deployment lifecycle hooks to invoke a Lambda admission-control function that validates ECR image signatures before allowing the deployment to proceed.

Architecture:

ECS deployment
     │
     ▼
Lifecycle Hook
     │
     ▼
Verification Lambda
     │
     ▼
Check ECR signature
     │
 ┌───┴─────┐
 ▼         ▼
trusted   invalid
 │         │
 ▼         ▼
continue  fail deployment

This is an excellent production governance gate.

Part K — ECR Cross-Account Architecture

Large organizations frequently separate:

CI / artifact account

development account

staging account

production account

Example:

                Artifact Account
                       │
                       ▼
                      ECR
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
         Dev         Stage         Prod
       Account      Account       Account

ECR private repository policies can grant other AWS principals/accounts access to specific repositories, while callers still need IAM permission for ecr:GetAuthorizationToken to authenticate to the registry.

22. Cross-Account Repository Policy

Conceptually:

{
  "Version": "2012-10-17",

  "Statement": [
    {
      "Effect": "Allow",

      "Principal": {
        "AWS":
          "arn:aws:iam::PROD_ACCOUNT_ID:role/ecsTaskExecutionRole"
      },

      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability"
      ]
    }
  ]
}

Then the production ECS task execution role receives only the permissions required to retrieve approved artifacts from that repository. Repository policies provide repository-scoped access controls, while IAM policies can grant registry/service-level capabilities.

Part L — Private ECR Connectivity

Your Fargate tasks live in:

PRIVATE SUBNETS

They need to pull:

ECR image

You could provide outbound internet through:

NAT Gateway

but for AWS-private access you can use:

ECR VPC endpoints
+
S3 endpoint

ECR supports PrivateLink interface endpoints so traffic between your VPC and ECR can remain on the AWS network.

23. Required ECR Endpoints

For modern Fargate private ECR pulls, remember:

com.amazonaws.ap-south-1.ecr.api

com.amazonaws.ap-south-1.ecr.dkr

com.amazonaws.ap-south-1.s3

ECR uses the API/registry endpoints for metadata and Docker Registry operations, while image layers are stored in S3; current Fargate platform 1.4+ private endpoint designs need both ECR endpoints plus the S3 gateway endpoint.

24. If You Also Use awslogs

No public internet?

Add:

com.amazonaws.ap-south-1.logs

for CloudWatch Logs. AWS explicitly calls out the Logs interface endpoint for Fargate tasks using awslogs in a VPC without internet connectivity.

If retrieving Secrets Manager secrets privately, also configure the appropriate Secrets Manager interface endpoint.

25. Fully Private Startup Path
Private ECS Task
     │
     ├── ECR API endpoint
     │
     ├── ECR DKR endpoint
     │
     ├── S3 gateway endpoint
     │
     ├── CloudWatch Logs endpoint
     │
     └── Secrets Manager endpoint

This lets many ECS workloads operate without needing NAT solely for these AWS service interactions.

Part M — Runtime Container Security

We have secured the artifact.

Now secure the running container.

26. Run as Non-Root

Bad Dockerfile:

FROM node:22

WORKDIR /app
COPY . .

CMD ["node", "start.js"]

depending on the image configuration, the process may execute with elevated privileges.

Better:

FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --chown=node:node . .

USER node

CMD ["node", "start.js"]

AWS ECS security guidance recommends running containers with a non-root user where possible.

27. Task Definition User

You can also explicitly set:

"user": "1000:1000"

or an appropriate named user supported by the image.

AWS task-definition parameters support user/UID/GID configuration for Linux containers.

Part N — Read-Only Root Filesystem

If an attacker compromises your web app:

remote code execution
        │
        ▼
attacker writes malware
into container filesystem

A read-only root filesystem reduces that write surface.

Task definition:

"readonlyRootFilesystem": true

AWS recommends read-only root filesystems as a container hardening measure, while noting that some software expects writable filesystem locations and must be tested accordingly.

28. But Node Needs Temporary Writes?

Then mount or use explicit writable areas such as:

/tmp

application scratch volume

rather than making the entire container root writable.

Mental model:

Root filesystem
=
READ ONLY


Explicit scratch area
=
WRITE ALLOWED

That is much safer than:

everything writable.
Part O — Linux Capabilities

Root inside a Linux container can carry capabilities such as:

CHOWN

SETUID

NET_RAW

MKNOD
...

AWS ECS security guidance recommends removing unnecessary Linux capabilities rather than granting containers privileges they do not need. Fargate does not support privileged containers.

29. Principle

If your Node API only needs:

listen on port 3002

open outbound network connections

read app files

it probably does not need broad OS-level privileges.

Think:

Container privilege
=
explicit exception

not:

default convenience.
Part P — Never Run Privileged Unless Absolutely Required

On EC2-backed ECS:

privileged=true

gives the container powerful access to the host and should be heavily restricted. AWS advises avoiding privileged containers; privileged mode is not supported on Fargate.

This is especially dangerous because:

container compromise
        │
        ▼
host compromise
        │
        ▼
other workloads compromised

becomes much more plausible.

Part Q — ECS IAM Security

From Part 1:

Execution Role
=
ECS infrastructure


Task Role
=
application

Keep them separate.

30. Execution Role

Typical responsibilities:

pull image from ECR

retrieve task-definition secret references

send awslogs

The ECS task execution role exists specifically so the ECS/Fargate agent can perform these startup/runtime infrastructure operations on the task's behalf.

31. Task Role

Application:

await s3.getObject(...)

needs:

taskRoleArn
→ s3:GetObject

Task-role credentials are provided to the containers and should follow least privilege.

32. Bad Task Role
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}

This means:

RCE in container
        │
        ▼
attacker inherits
massive AWS permissions

Your application IAM role is part of your runtime security boundary.

33. Better Role

Todo API may need only:

Secrets Manager:
GetSecretValue on one secret

S3:
GetObject on one bucket prefix

SQS:
SendMessage on one queue

No reason to grant:

IAM

EC2

DeleteBucket

AdminAccess
Part R — Secret Management

Never bake into Docker:

ENV DB_PASSWORD=supersecret

because image layers can persist and be inspected.

Do not commit:

.env

with production credentials.

Use:

Secrets Manager

or appropriately secured Parameter Store configuration.

34. ECS Secrets Injection

Container definition:

"secrets": [
  {
    "name": "MONGO_URI",
    "valueFrom":
      "arn:aws:secretsmanager:ap-south-1:123456789012:secret:todo/prod/mongo"
  }
]

ECS can inject an entire secret or a selected JSON key/version into container environment variables.

35. Critical Rotation Trap

Suppose:

Task starts
   │
   ▼
DB_PASSWORD=v1

Secrets Manager rotates:

DB_PASSWORD=v2

Does the existing ECS container automatically receive v2?

No.

For environment-variable injection, the secret value is resolved when the task starts. Existing tasks do not automatically receive later secret updates or rotations; you must launch new tasks, for example via a forced service deployment.

36. Rotation Architecture
Secrets Manager
      │
      ▼
rotate secret
      │
      ▼
Force New ECS Deployment
      │
      ▼
new tasks start
      │
      ▼
new secret loaded

Alternatively, applications can retrieve secrets dynamically using AWS SDK-based patterns when immediate rotation awareness is required, rather than relying solely on startup-time environment injection.

37. Environment Variable Security Tradeoff

AWS notes that secrets injected as environment variables are accessible to processes, debugging utilities, and potentially logs inside the container.

So for higher-security scenarios consider:

runtime retrieval

or

sidecar → protected shared volume

rather than placing all sensitive values directly in process environment.

AWS documents the sidecar/shared-volume pattern specifically as an alternative for sensitive ECS data.

Part S — Runtime Threat Detection

Image scanning protects before deployment.

What about:

container was secure
when deployed

BUT

app later exploited?

Use runtime monitoring.

38. GuardDuty Runtime Monitoring

GuardDuty Runtime Monitoring analyzes runtime OS/network/file behavior for supported workloads to identify suspicious activity such as container compromise, credential misuse, privilege escalation attempts, and malicious runtime behavior.

For ECS Fargate, GuardDuty can manage the runtime security agent and inject it as a sidecar into new Fargate tasks/service deployments.

Architecture:

ECS Task
│
├── todo-api
│
└── GuardDuty security agent
        │
        ▼
    GuardDuty
        │
        ▼
    Finding
        │
        ▼
 Security Hub / EventBridge
39. Supply-Time vs Runtime Security

Remember:

ECR Inspector scanning
=
KNOWN VULNERABILITY
before/after image build


AWS Signer
=
ARTIFACT AUTHENTICITY


GuardDuty Runtime Monitoring
=
SUSPICIOUS BEHAVIOR
while workload runs

You want all three layers for stronger defense.

Part T — Production Dockerfile

For your Node.js Todo backend:

FROM node:22-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev \
    && npm cache clean --force

COPY --chown=node:node . .

ENV NODE_ENV=production
ENV PORT=3002

USER node

EXPOSE 3002

CMD ["node", "start.js"]

Then task definition handles:

runtime secret injection

IAM

logs

health

CPU/memory

networking

instead of baking infrastructure concerns into the image.

AWS's ECS image guidance recommends complete, self-contained images, one primary application process, proper SIGTERM handling, stdout/stderr logging, and uniquely versioned image tags.

Part U — .dockerignore

Do not accidentally copy:

.git

node_modules

.env

coverage

private keys

AWS credentials

Terraform state

Jenkins files containing secrets

into image context.

Example:

.git
.gitignore

node_modules

.env
.env.*

coverage

*.pem
*.key

terraform.tfstate
terraform.tfstate.*

Dockerfile*
docker-compose*

Review this list against what your actual build needs; do not exclude a file required for a legitimate build stage.

Part V — CI/CD Pipeline Mental Model

Now build the complete production pipeline:

Git Push
   │
   ▼
Checkout
   │
   ▼
Unit Tests
   │
   ▼
Static Analysis
   │
   ▼
Dependency Scan
   │
   ▼
Docker Build
   │
   ▼
Container Test
   │
   ▼
ECR Push
   │
   ▼
ECR / Inspector Scan
   │
   ▼
Security Gate
   │
   ▼
ECR Signing
   │
   ▼
Record Digest
   │
   ▼
Register ECS Task Revision
   │
   ▼
Deployment Verification Hook
   │
   ▼
ECS Deployment
   │
   ▼
ALB Health
   │
   ▼
CloudWatch Alarm Gate
   │
   ▼
Production Complete
Part W — Jenkins Production Flow

Your Jenkins model can evolve from your atomic PM2 deployment to:

pipeline {
  agent any

  environment {
    AWS_REGION = 'ap-south-1'

    ECR_REPO =
      '123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api'

    ECS_CLUSTER =
      'todo-production'

    ECS_SERVICE =
      'todo-api'
  }

  stages {

    stage('Test') {
      steps {
        sh 'npm ci'
        sh 'npm test'
      }
    }

    stage('Build Image') {
      steps {
        script {
          env.GIT_SHA =
            sh(
              script: 'git rev-parse --short=12 HEAD',
              returnStdout: true
            ).trim()
        }

        sh '''
          docker build \
            -t ${ECR_REPO}:${GIT_SHA} .
        '''
      }
    }

    stage('ECR Login') {
      steps {
        sh '''
          aws ecr get-login-password \
            --region ${AWS_REGION} \
          | docker login \
            --username AWS \
            --password-stdin \
            ${ECR_REPO%/*}
        '''
      }
    }

    stage('Push') {
      steps {
        sh '''
          docker push \
            ${ECR_REPO}:${GIT_SHA}
        '''
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          ./deploy-ecs.sh \
            ${ECR_REPO}:${GIT_SHA}
        '''
      }
    }
  }
}

The important architectural property is:

Git SHA
=
immutable application release identity

which aligns with AWS's ECS recommendation for uniquely versioned image tags.

Part X — Capture the Digest

After push:

IMAGE_DIGEST=$(
  aws ecr describe-images \
    --repository-name todo-api \
    --image-ids imageTag="$GIT_SHA" \
    --query 'imageDetails[0].imageDigest' \
    --output text \
    --region ap-south-1
)

echo "$IMAGE_DIGEST"

Then artifact identity becomes:

123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api@sha256:...

This can be stored as:

Jenkins build metadata

deployment manifest

change ticket

release record
Part Y — Register New Task Definition Revision

Do not manually modify the current running task.

Create:

todo-api:41
      │
      ▼
todo-api:42

with the new image.

Task Definition:

{
  "family": "todo-api",

  "containerDefinitions": [
    {
      "name": "todo-api",

      "image":
        "123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api@sha256:NEW_DIGEST"
    }
  ]
}

ECS task definitions are revisioned application blueprints, and ECS service revisions are immutable records of the configuration being deployed, including task definition and image/digest information.

Part Z — Update ECS Service
aws ecs update-service \
  --cluster todo-production \
  --service todo-api \
  --task-definition todo-api:42 \
  --region ap-south-1

Then ECS performs the deployment strategy you configured.

For rolling deployments, ECS replaces old tasks according to minimumHealthyPercent and maximumPercent; circuit breaker and CloudWatch alarm failure detection can roll back to the prior successful service revision.

Part AA — Wait for Deployment

Pipeline should not say:

update-service returned 200
=
production succeeded

Wrong.

That means:

AWS accepted the request.

You still need:

new tasks running

targets healthy

deployment completed

application healthy
40. CLI Wait
aws ecs wait services-stable \
  --cluster todo-production \
  --services todo-api \
  --region ap-south-1

Then inspect:

aws ecs describe-services \
  --cluster todo-production \
  --services todo-api \
  --region ap-south-1

Check deployment state plus external health/metrics rather than treating service stability alone as proof of business correctness.

Part AB — Production Smoke Test

After deployment:

curl -fsS \
  https://api.yourdatascientist.tech/health

Then:

curl -fsS \
  https://api.yourdatascientist.tech/get-todo

A mature validation step should test:

health endpoint

one authenticated API path

database connectivity

critical business transaction

without creating destructive real customer actions.

Part AC — Deployment Quality Gates

The complete decision:

New task revision
      │
      ▼
Signature valid?
      │
      ├── NO → STOP
      │
      ▼ YES

Tasks start?
      │
      ├── NO → circuit breaker rollback
      │
      ▼ YES

ALB healthy?
      │
      ├── NO → rollback
      │
      ▼ YES

5xx normal?
      │
      ├── NO → alarm rollback
      │
      ▼ YES

Latency normal?
      │
      ├── NO → rollback
      │
      ▼ YES

Business smoke test?
      │
      ├── NO → rollback
      │
      ▼ YES

PRODUCTION COMPLETE

ECS lifecycle hooks provide a current mechanism for custom Lambda deployment validation, including governance checks such as signature verification, while circuit breaker/CloudWatch alarms provide native deployment failure paths.

Part AD — Rollback

Suppose:

todo-api:42

is bad.

You want:

todo-api:41

back.

Modern ECS service revisions provide immutable records of deployed workload configurations, and automatic rollback can restore the most recent successful revision.

Manual task-definition rollback is also straightforward:

aws ecs update-service \
  --cluster todo-production \
  --service todo-api \
  --task-definition todo-api:41 \
  --region ap-south-1

provided the underlying referenced image still exists.

Part AE — Why Image Retention Matters Again
Task Definition 41
       │
       ▼
Image Digest AAA

If ECR deleted:

AAA

your "rollback configuration" exists but the artifact does not.

Therefore:

Git history

Task Definition history

ECR artifact retention

must all agree with your rollback strategy.

Part AF — Database Migrations

This is where many zero-downtime deployments fail.

Imagine deployment:

v17
+
v18

running simultaneously during rolling deployment.

New migration does:

DROP COLUMN old_field;

but v17 still requires:

old_field

Result:

new version works

old version breaks

Zero-downtime container deployment failed because your database deployment wasn't backward compatible.

41. Expand → Migrate → Contract

Use:

EXPAND

Add new schema without breaking old application:

ADD COLUMN new_field;

Then:

MIGRATE

Deploy code that can use the new field and migrate data.

Then later:

CONTRACT

remove old field only after no running version depends on it.

Mental model:

Release N
old schema

      │
      ▼

Expand schema
supports N and N+1

      │
      ▼

Deploy N+1

      │
      ▼

All N removed

      │
      ▼

Contract old schema

This is an application/database compatibility strategy, independent of ECS itself, but critical to safe rolling/blue-green releases.

Part AG — Run Migrations as ECS Task

Instead of:

SSH into server
npm run migrate

use:

CI
 │
 ▼
ECS RunTask
 │
 ▼
migration container
 │
 ▼
database

Example:

aws ecs run-task \
  --cluster todo-production \
  --task-definition todo-migration:17 \
  --launch-type FARGATE \
  --network-configuration \
  'awsvpcConfiguration={
      subnets=[subnet-a,subnet-b],
      securityGroups=[sg-migrations],
      assignPublicIp=DISABLED
   }' \
  --region ap-south-1

Now migrations are:

versioned

auditable

IAM controlled

repeatable

network controlled

rather than manual production shell activity.

Part AH — Environment Promotion

Bad:

Dev:
build abc123


Stage:
rebuild abc123


Prod:
rebuild abc123

Better:

Build once

Digest:
sha256:XYZ
    │
    ├── Dev
    │      ✓
    │
    ├── Stage
    │      ✓
    │
    └── Prod
           ✓

You are promoting:

ARTIFACT IDENTITY

not source-code intent.

42. Promotion Metadata

Release manifest:

{
  "application": "todo-api",

  "gitSha": "4c8af91",

  "image":
    "123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api",

  "digest":
    "sha256:f9328...",

  "taskDefinition":
    "todo-api:42",

  "environment":
    "production"
}

This becomes excellent audit evidence.

Part AI — ECR Retagging

ECR can add a new tag to an existing image manifest without re-pulling and re-pushing all image layers.

For example, after stage approval you might create:

4c8af91

prod-2026-08-14

pointing at the same digest.

With immutable tags, this means:

create NEW promotion tag

not overwrite an existing production tag.

Part AJ — Terraform: ECR

The current HashiCorp AWS provider exposes an aws_ecr_repository resource for ECR repositories and aws_ecr_lifecycle_policy for lifecycle management.

Example:

resource "aws_ecr_repository" "todo_api" {
  name = "todo-api"

  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = "shared"
    Application = "todo-api"
    ManagedBy   = "terraform"
  }
}
43. ECR Lifecycle Terraform
resource "aws_ecr_lifecycle_policy" "todo_api" {
  repository =
    aws_ecr_repository.todo_api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1

        description =
          "Remove untagged images after 7 days"

        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}

Only one Terraform lifecycle-policy resource should manage a given ECR repository; put multiple lifecycle rules inside that policy when needed.

Part AK — Registry Scanning Configuration

Enhanced scanning is configured on the private registry for a Region rather than independently as an arbitrary per-image ECS setting. Current ECR documentation supports repository filters for continuous versus scan-on-push behavior.

Example CLI:

aws ecr put-registry-scanning-configuration \
  --scan-type ENHANCED \
  --rules '[
    {
      "repositoryFilters": [
        {
          "filter": "prod*",
          "filterType": "WILDCARD"
        }
      ],
      "scanFrequency": "CONTINUOUS_SCAN"
    },

    {
      "repositoryFilters": [
        {
          "filter": "*",
          "filterType": "WILDCARD"
        }
      ],
      "scanFrequency": "SCAN_ON_PUSH"
    }
  ]' \
  --region ap-south-1

This matches the current ECR enhanced-scanning model.

Part AL — Hardened ECS Container Definition

Conceptually:

{
  "name": "todo-api",

  "image":
    "ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/todo-api@sha256:...",

  "essential": true,

  "readonlyRootFilesystem": true,

  "user": "1000:1000",

  "portMappings": [
    {
      "containerPort": 3002,
      "protocol": "tcp"
    }
  ],

  "secrets": [
    {
      "name": "MONGO_URI",
      "valueFrom":
        "arn:aws:secretsmanager:ap-south-1:ACCOUNT:secret:todo/prod/mongo"
    }
  ],

  "logConfiguration": {
    "logDriver": "awslogs",

    "options": {
      "awslogs-group": "/ecs/todo-api",
      "awslogs-region": "ap-south-1",
      "awslogs-stream-prefix": "ecs"
    }
  },

  "healthCheck": {
    "command": [
      "CMD-SHELL",
      "wget -q -O - http://localhost:3002/health || exit 1"
    ],

    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 30
  }
}

The security-relevant controls here—non-root operation, read-only root filesystem, secret references, task IAM separation, centralized logs, and health monitoring—align with current ECS security guidance.

Part AM — Production IAM Separation

You should end up with several different IAM identities:

Jenkins / CI role
│
├── ecr push
├── inspect scan/signing status
├── register task definition
└── update ECS service


ECS Execution Role
│
├── ecr pull
├── logs
└── secret bootstrap if referenced


ECS Task Role
│
├── application S3
├── application SQS
└── application AWS API calls


ECS Deployment Hook Role
│
└── invoke validation Lambda


Verification Lambda Role
│
├── inspect ECR artifact/signature
└── report hook result

Do not combine all of this into:

AdministratorAccess

for convenience.

Part AN — CI Role Least Privilege

A deployment pipeline usually needs capabilities in categories such as:

ECR:
push image

ECS:
register task definition
describe service
update service

IAM:
iam:PassRole
only for approved ECS roles

iam:PassRole is particularly important: a deployer that registers task definitions using execution/task roles generally needs permission to pass those roles, so restrict iam:PassRole to the specific approved role ARNs rather than *.

Part AO — Runtime Network Security

Production architecture:

Internet
   │
   ▼
ALB SG
:443 public
   │
   ▼
Task SG
:3002 FROM ALB SG ONLY
   │
   ▼
Database SG
:27017 / 5432
FROM TASK SG ONLY

This creates:

Internet
can reach ALB

ALB
can reach application

application
can reach database

Internet
cannot directly reach app/database

Your security groups become a service-to-service authorization boundary, complementing application authentication and IAM.

Part AP — Complete Todo-App Platform

Now combine everything you've learned.

                         DEVELOPER

                            │
                            ▼
                         Git Repo
                            │
                            ▼
                         Jenkins
                            │
                ┌───────────┼────────────┐
                ▼           ▼            ▼
              Tests      Security      Docker
                         Analysis       Build
                                        │
                                        ▼
                                   Immutable Tag
                                     Git SHA
                                        │
                                        ▼
                                       ECR
                             ┌──────────┼────────────┐
                             ▼          ▼            ▼
                       Inspector     Signer       Lifecycle
                       Scanning     Signature      Policy
                             │          │
                             └────┬─────┘
                                  ▼
                            Release Digest
                                  │
                                  ▼
                       Task Definition Revision
                                  │
                                  ▼
                           ECS Deployment
                                  │
                   ┌──────────────┼──────────────┐
                   ▼              ▼              ▼
                Hook         Circuit Breaker   CW Alarm
                   │              │              │
             signature       startup/health   app health
             verification
                   │              │              │
                   └──────────────┼──────────────┘
                                  ▼
                             ALB HTTPS
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
                Task AZ-A                   Task AZ-B
                private                     private
                    │                           │
                    ▼                           ▼
               Node.js API                 Node.js API
                    │                           │
                    └─────────────┬─────────────┘
                                  │
                     ┌────────────┼────────────┐
                     ▼            ▼            ▼
                 Database        SQS      Secrets Manager


                          SECURITY

             non-root container
                    +
             read-only root FS
                    +
              least-privilege IAM
                    +
               private subnets
                    +
               SG-to-SG access
                    +
            enhanced ECR scanning
                    +
                image signing
                    +
          GuardDuty Runtime Monitoring


                        OPERATIONS

              Service Auto Scaling
                    +
              Container Insights
                    +
                 FireLens
                    +
             CloudWatch alarms
                    +
              EventBridge alerts
                    +
             automatic rollback

That is a serious production container platform.

Part AQ — Incident Walkthrough

Suppose production starts returning:

HTTP 500

after build #915.

Your investigation becomes:

1. Identify deployment

ECS service revision
→ todo-api:42


2. Identify artifact

Task definition
→ Git SHA 4c8af91
→ digest sha256:XYZ


3. Check supply chain

ECR signing status
→ signed

Inspector
→ no blocking vulnerability


4. Check deployment

ECS rollout
→ completed


5. Check ALB

targets healthy


6. Check application

CloudWatch logs
→ Mongo schema error


7. Compare release

v42 introduced incompatible migration


8. Action

rollback service revision
+
restore schema compatibility

Notice the difference from:

"Which Docker container
did Jenkins deploy yesterday?"

Everything is traceable.

Part AR — Security Incident Walkthrough

Suppose GuardDuty reports suspicious container behavior.

Response:

GuardDuty finding
      │
      ▼
Identify ECS task
      │
      ▼
Identify service revision
      │
      ▼
Identify image digest
      │
      ▼
Identify Git SHA
      │
      ▼
Inspect ECR signature
      │
      ▼
Check Inspector findings
      │
      ▼
Check task role permissions
      │
      ▼
Contain task/service
      │
      ▼
Rotate credentials/secrets if needed
      │
      ▼
Patch source/dependency
      │
      ▼
build NEW artifact
      │
      ▼
sign
      │
      ▼
deploy

GuardDuty Runtime Monitoring is specifically designed to provide runtime signals when supported container workloads exhibit suspicious behavior beyond what static image scanning can detect.

Part AS — Common Production Failures
44. CannotPullContainerError

Check:

Does image exist?

Does digest exist?

Did lifecycle policy delete it?

Task execution role permissions?

ECR endpoints?

S3 endpoint?

Network?

Cross-account repository policy?

Current ECR/ECS integration requires ECR authorization and image-layer permissions such as BatchGetImage, GetDownloadUrlForLayer, and registry authentication.

45. Pipeline Push Gets ImageTagAlreadyExistsException

If repository is immutable:

this is expected.

Your pipeline reused a tag.

Fix pipeline:

one unique tag
per immutable artifact

not:

disable immutability.

ECR intentionally rejects overwrites of immutable tags.

46. Inspector Found Critical CVE After Deployment

This can happen because enhanced continuous scanning updates findings as newly disclosed vulnerabilities become known.

Flow:

new CVE finding
     │
     ▼
EventBridge / Security workflow
     │
     ▼
determine deployed-image usage
     │
     ▼
patch base/dependency
     │
     ▼
rebuild new image
     │
     ▼
scan
     │
     ▼
sign
     │
     ▼
deploy

Do not edit the existing image.

47. Secret Rotated but Application Still Uses Old Password

Expected if the secret was injected into the environment when the task started.

Fix:

aws ecs update-service \
  --cluster todo-production \
  --service todo-api \
  --force-new-deployment \
  --region ap-south-1

New tasks retrieve the current secret value when they start.

48. Private Task Cannot Pull ECR Image

Check:

ecr.api endpoint

ecr.dkr endpoint

S3 gateway endpoint

private DNS

endpoint SG :443

task execution role

Those components form the current private ECR pull path for modern Fargate workloads.

49. Private Task Pulls Image but Logs Fail

If there's no NAT/internet path:

ECR works
because endpoints exist

but

CloudWatch Logs endpoint missing

Add the Logs interface endpoint if using awslogs.

50. Image Is Signed but Malicious Image Deploys Anyway

Check:

Was signature verification
actually enforced?

Signing itself does not block deployment. For ECS, current AWS guidance uses deployment lifecycle-hook validation such as a Lambda image-signature admission controller.

51. Container Cannot Write /tmp

If:

readonlyRootFilesystem=true

and your application needs writable scratch space, provide an explicit writable volume/path and test it. AWS explicitly warns that some software packages require writable filesystem areas when root is read-only.

52. Application Gets AWS AccessDenied

Ask:

Did ECS fail to pull/configure?

Then inspect:

Execution Role

But if:

application is already running
and its AWS SDK call fails

inspect:

Task Role

The distinction between task credentials and execution-agent permissions is explicit in ECS's IAM model.

Part AT — Certification / Interview Scenarios
Scenario 1

Prevent developers from overwriting a production image tag.

Use:

ECR Tag Immutability

Scenario 2

Need selected convenience tags mutable while most repository tags remain immutable.

Modern ECR supports:

IMMUTABLE_WITH_EXCLUSION

with wildcard exclusion filters.

Scenario 3

Need continuous detection when a new CVE is discovered after an image was pushed.

Use:

ECR Enhanced Scanning
+
Amazon Inspector
+
continuous scan

Scenario 4

Need verify the image came from the trusted build system.

Think:

ECR image signing
+
AWS Signer

and enforce verification in the deployment path.

Scenario 5

Want automatic signing when images are pushed to ECR.

Current preferred AWS mechanism:

ECR Managed Signing

Scenario 6

Want ECS deployment blocked if signature is invalid.

Think:

ECS deployment lifecycle hook
→ Lambda verification admission control

Scenario 7

Production ECS task must pull ECR images without NAT or internet.

Think:

ECR API interface endpoint

ECR DKR interface endpoint

S3 gateway endpoint

plus other endpoints such as Logs/Secrets Manager according to workload needs.

Scenario 8

Application running inside task needs S3 permissions.

Use:

Task Role

Scenario 9

ECS infrastructure needs permission to pull ECR image.

Use:

Task Execution Role

Scenario 10

Secrets Manager value rotated, but existing Fargate tasks still have old value.

Expected with environment injection.

Use:

new tasks / Force New Deployment

or retrieve the secret dynamically.

Scenario 11

Reduce attacker's ability to modify container filesystem.

Use:

readonlyRootFilesystem=true

where application compatibility allows it.

Scenario 12

Reduce Linux privilege inside container.

Use:

non-root user

drop unnecessary capabilities

avoid privileged containers

Scenario 13

Detect suspicious runtime activity after an ECS Fargate container is compromised.

Use:

GuardDuty Runtime Monitoring

Scenario 14

Need deterministic rollback to exact artifact.

Track:

Task Definition Revision

+
Service Revision

+
Image Digest

and ensure the artifact hasn't been removed from ECR. ECS service revisions include the container image/digest information and are immutable records for a service.

Part AU — Permanent Artifact Identity Model

Memorize this chain:

Git commit
4c8af91
     │
     ▼
Docker build
     │
     ▼
Image tag
todo-api:4c8af91
     │
     ▼
Image digest
sha256:ABC
     │
     ▼
AWS Signer signature
     │
     ▼
Task Definition
todo-api:42
     │
     ▼
ECS Service Revision
     │
     ▼
Deployment
     │
     ▼
Running Task

During an incident you should be able to travel:

RUNNING CONTAINER
      │
      ▼
SERVICE REVISION
      │
      ▼
TASK DEFINITION
      │
      ▼
IMAGE DIGEST
      │
      ▼
IMAGE SIGNATURE
      │
      ▼
GIT COMMIT

That is supply-chain traceability.

53. 45 Rules to Burn Into Memory
1. Production container security begins before ECS.

2. Build once and promote the same artifact.

3. Never rely on :latest for production identity.

4. Use unique image tags.

5. Git SHA is an excellent build tag.

6. Digest identifies actual image content.

7. ECS resolves service image tags to digests
   for version consistency.

8. Explicit digest pinning gives deterministic identity.

9. Enable ECR tag immutability.

10. Modern ECR supports immutability exclusions.

11. Lifecycle policies prevent endless image growth.

12. Don't delete rollback artifacts too early.

13. Basic scanning focuses on OS vulnerabilities.

14. Enhanced scanning integrates with Inspector.

15. Enhanced scanning includes language-package findings.

16. Continuous scanning detects newly disclosed CVEs.

17. Image scanning and signing solve different problems.

18. Scanning asks: "Is it vulnerable?"

19. Signing asks: "Can I trust its origin/integrity?"

20. ECR Managed Signing is the recommended automatic path.

21. AWS Signer creates cryptographic signatures.

22. Signing is useless if you never verify.

23. ECS can enforce verification through deployment hooks.

24. Cross-account ECR uses repository + IAM permissions.

25. GetAuthorizationToken still matters for registry auth.

26. Private Fargate ECR requires ecr.api.

27. It also requires ecr.dkr.

28. ECR layers require S3 access.

29. awslogs without internet may need Logs endpoint.

30. Secrets Manager private access may need its endpoint.

31. Run application processes as non-root.

32. Prefer read-only root filesystems where compatible.

33. Explicitly provide only required writable paths.

34. Drop unnecessary Linux capabilities.

35. Avoid privileged containers.

36. Execution Role belongs to ECS infrastructure actions.

37. Task Role belongs to application AWS actions.

38. Never bake static AWS keys into images.

39. Never bake production secrets into images.

40. Injected ECS environment secrets don't auto-refresh.

41. Secret rotation may require new tasks.

42. GuardDuty handles runtime-threat detection.

43. Database migrations must be rollout-compatible.

44. Rollback means code + configuration + artifact
    must all still exist.

45. Production deployment identity should map:
    Git SHA → digest → task revision → service revision.
✅ Lesson 35 Part 4 Complete

You now understand:

✓ container software supply chain
✓ build once / promote many

✓ Amazon ECR
✓ registries
✓ repositories

✓ image tags
✓ immutable tags
✓ Git SHA tagging
✓ 2026 mutability exclusions

✓ image digests
✓ ECS digest resolution
✓ explicit digest pinning
✓ version consistency

✓ lifecycle policies
✓ image cleanup
✓ rollback retention

✓ ECR basic scanning
✓ Enhanced scanning
✓ Amazon Inspector
✓ continuous CVE detection
✓ EventBridge security workflows

✓ ECR Managed Signing
✓ AWS Signer
✓ manual Notation signing
✓ cryptographic signatures
✓ image verification
✓ ECS lifecycle-hook admission control

✓ cross-account ECR
✓ repository policies
✓ GetAuthorizationToken

✓ ECR PrivateLink
✓ ecr.api endpoint
✓ ecr.dkr endpoint
✓ S3 gateway endpoint
✓ Logs endpoint
✓ Secrets Manager endpoint

✓ non-root containers
✓ read-only root filesystem
✓ Linux capabilities
✓ privileged-container risk

✓ Task Execution Role
✓ Task Role
✓ least privilege
✓ iam:PassRole considerations

✓ Secrets Manager
✓ environment secret injection
✓ secret-rotation behavior
✓ force-new-deployment requirement
✓ sidecar secret pattern

✓ GuardDuty Runtime Monitoring
✓ Fargate runtime security

✓ production Dockerfile
✓ .dockerignore
✓ Jenkins ECS pipeline

✓ immutable artifact promotion
✓ digest capture
✓ task-definition revisions
✓ ECS service revisions

✓ deployment verification gates
✓ deployment rollback
✓ database migrations
✓ expand / migrate / contract

✓ Terraform ECR
✓ lifecycle policy
✓ scanning configuration

✓ production Todo-App ECS architecture
✓ incident traceability
✓ troubleshooting
✓ certification scenarios
✅ Lesson 35 — Amazon ECS, Fargate & Production Containers COMPLETE

You now have the full production ECS model:

                         SOURCE
                           │
                           ▼
                          Git
                           │
                           ▼
                         CI/CD
                           │
          ┌────────────────┼─────────────────┐
          ▼                ▼                 ▼
        Test             Scan              Build
                                             │
                                             ▼
                                            ECR
                                      ┌──────┼──────┐
                                      ▼      ▼      ▼
                                  Inspector Signer Lifecycle
                                      │      │
                                      └──┬───┘
                                         ▼
                                    Image Digest
                                         │
                                         ▼
                                  Task Definition
                                         │
                                         ▼
                                     ECS Service
                                         │
                          ┌──────────────┼───────────────┐
                          ▼              ▼               ▼
                       Fargate       Fargate Spot      EC2 /
                                                     Managed
                                                    Instances
                          │              │
                          └───────┬──────┘
                                  ▼
                                 ALB
                                  │
                                  ▼
                               Customers


                     RELIABILITY

                   Multi-AZ Tasks
                        +
                   Auto Scaling
                        +
                Health Checks
                        +
               Circuit Breaker
                        +
              CloudWatch Alarms
                        +
                 Auto Rollback


                       SECURITY

                 Task IAM Roles
                        +
                 Private Subnets
                        +
                SG-to-SG Access
                        +
                   ECR Scanning
                        +
                  Image Signing
                        +
                Runtime Monitoring
                        +
                  Secret Rotation


                    OBSERVABILITY

                 CloudWatch Logs
                        +
                Container Insights
                        +
                    FireLens
                        +
                     X-Ray /
                  OpenTelemetry
Next — Lesson 36
AWS Hybrid Cloud, Site-to-Site VPN, Transit Gateway & Direct Connect

We now move from:

Everything inside AWS

to real enterprise environments:

                    CORPORATE DATA CENTER

                         10.10.0.0/16
                               │
                               │
              ┌────────────────┼─────────────────┐
              │                                  │
              ▼                                  ▼
       Site-to-Site VPN                    Direct Connect
              │                                  │
              └────────────────┬─────────────────┘
                               ▼
                         Transit Gateway
                               │
               ┌───────────────┼───────────────┐
               ▼               ▼               ▼
            Prod VPC        Dev VPC       Shared VPC
               │               │               │
               ▼               ▼               ▼
              ECS             EKS             RDS

Next we'll go deep into hybrid-cloud mental models, Virtual Private Gateway, Customer Gateway, Site-to-Site VPN, IPsec tunnels, static vs BGP routing, ASN, tunnel redundancy, route propagation, Transit Gateway, TGW route tables, attachments, segmentation, appliance mode, centralized egress/inspection, AWS Direct Connect, dedicated vs hosted connections, VIFs, private/public/transit VIFs, Direct Connect Gateway, MACsec, BGP communities, VPN-over-DX, resilient hybrid architectures, Route 53 Resolver hybrid DNS, multi-account networking, Terraform, troubleshooting, and a complete enterprise on-premises ↔ AWS connectivity architecture.