# AWS Masterclass — Phase 3

# Lesson 45: Amazon ECR and the Production Container Supply Chain

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Store Docker and OCI images securely in Amazon ECR.
* Distinguish registries, repositories, images, manifests, layers, tags and digests.
* Authenticate Docker, Jenkins, ECS and other clients to ECR.
* Design repositories for development, staging and production.
* Prevent production tags from being overwritten.
* Deploy images using immutable digests.
* Scan container images for operating-system and application-package vulnerabilities.
* Use Amazon Inspector enhanced scanning.
* Generate and export software bills of materials.
* Attach SBOMs, signatures and attestations to container images.
* Sign images using ECR managed signing and AWS Signer.
* Verify image signatures before deployment.
* Remove or archive unused images through lifecycle policies.
* Replicate images across AWS accounts and Regions.
* Use pull-through cache rules for upstream registries.
* Implement cross-account ECR access.
* Build a production container promotion pipeline.
* Troubleshoot image pushes, pulls, scans, replication and ECS deployment failures.
* Provision ECR repositories using Terraform.

---

# 2. What is Amazon ECR?

Amazon Elastic Container Registry is AWS’s managed container registry.

It stores:

```text
Docker container images
OCI container images
OCI-compatible artifacts
Helm charts
Image signatures
SBOMs
Security attestations
Scan results
```

Amazon ECR supports OCI v1.1 reference artifacts, allowing artifacts such as signatures, SBOMs and attestations to be associated with a specific container image. ([AWS Documentation][1])

Basic architecture:

```text
Developer or CI pipeline
        |
        | Push image
        v
Amazon ECR
        |
        | Pull image
        v
ECS / EKS / Lambda / EC2 / App Runner
```

ECR manages the registry infrastructure, availability, authentication integration, encryption and image-storage backend.

---

# 3. The container supply-chain mental model

A production container journey should look like:

```text
Source code
    |
    v
Build
    |
    v
Unit and integration tests
    |
    v
Container image
    |
    v
Dependency and vulnerability scan
    |
    v
SBOM generation
    |
    v
Image signing
    |
    v
Push to ECR
    |
    v
Promotion approval
    |
    v
Signature and policy verification
    |
    v
ECS / EKS deployment
    |
    v
Runtime monitoring
```

ECR is a central component, but it is not the entire supply chain.

It does not replace:

* Secure source control.
* Code review.
* Dependency management.
* Build isolation.
* CI/CD approval.
* Runtime security.
* Deployment authorization.
* Incident response.

---

# 4. Registry, repository and image

The hierarchy is:

```text
AWS account and Region
        |
        v
Private ECR registry
        |
        v
Repository
        |
        v
Container images and OCI artifacts
```

Example registry:

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com
```

Example repository:

```text
production/todo-api
```

Complete image reference:

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com/production/todo-api:2026.07.28-42
```

Each AWS account has an ECR private registry in each supported Region, and repositories inside that registry are individually manageable through IAM and repository policies. ([AWS Documentation][2])

---

# 5. Private ECR versus ECR Public

## Private ECR

Use for:

* Proprietary application images.
* Internal base images.
* Production workloads.
* Organisation-owned Helm charts.
* Security-sensitive artifacts.

Access requires AWS authentication and authorization.

## ECR Public

Use for:

* Open-source images.
* Public SDK images.
* Public base images.
* Images intentionally available to everyone.

Public repositories are visible through the Amazon ECR Public Gallery and can be pulled publicly. ([AWS Documentation][3])

For your TodoApp production workloads, use private ECR.

---

# 6. Container image structure

A container image consists of:

```text
Image manifest
    |
    ├── Configuration object
    └── Ordered filesystem layers
```

Example Dockerfile:

```dockerfile
FROM node:24-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

CMD ["node", "start.js"]
```

Conceptual layers:

```text
Layer 1:
Base Node.js image

Layer 2:
Working directory metadata

Layer 3:
package.json and package-lock.json

Layer 4:
Installed dependencies

Layer 5:
Application source

Layer 6:
Runtime command metadata
```

When an image is pushed, ECR checks whether individual layers are already available before uploading them. ([AWS Documentation][4])

---

# 7. Docker build-cache design

Put rarely changing operations before frequently changing operations.

Bad:

```dockerfile
COPY . .

RUN npm ci --omit=dev
```

Any source-code modification invalidates the dependency-install layer.

Better:

```dockerfile
COPY package.json package-lock.json ./

RUN npm ci --omit=dev

COPY . .
```

Now dependencies are reinstalled only when package files change.

This improves:

* Build speed.
* CI execution time.
* Layer reuse.
* Image push time.
* Developer feedback.

---

# 8. Tags

A tag is a human-readable reference to an image.

Examples:

```text
todo-api:latest
todo-api:development
todo-api:1.4.2
todo-api:2026.07.28-42
todo-api:git-a19f82c
```

Tags make images easier for humans and deployment systems to reference.

However:

```text
Tag
≠
Image identity
```

A mutable tag can point to a different image later.

---

# 9. Digests

A digest identifies image content cryptographically.

Example:

```text
todo-api@sha256:34d8f0ac...
```

Image reference:

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com/production/todo-api@sha256:34d8f0ac...
```

A digest is content-addressable:

```text
Same image content
    =
Same digest
```

If the image content changes:

```text
Digest changes
```

## Memory trick

```text
Tag:
Human-readable label

Digest:
Immutable image identity
```

ECR and Docker clients support pulling an image either by tag or digest. ([AWS Documentation][5])

---

# 10. Why `latest` is dangerous

Suppose:

```text
todo-api:latest
```

points to image A.

ECS task A starts and pulls image A.

Later, the CI pipeline overwrites `latest` with image B.

New task B starts and pulls image B.

Now:

```text
Same task definition reference
Different running application code
```

This causes:

* Inconsistent deployments.
* Difficult rollback.
* Poor auditability.
* Unclear incident timelines.
* “Works on one task but not another” incidents.

Avoid `latest` for production deployments.

---

# 11. Recommended image identifiers

Use multiple identifiers where appropriate:

```text
Semantic version:
1.4.2

CI build number:
build-1042

Git commit:
git-a19f82c

Release timestamp:
20260728-014500

Image digest:
sha256:...
```

Example:

```text
production/todo-api:1.4.2
production/todo-api:build-1042
production/todo-api:git-a19f82c
```

All three tags can refer to the same digest.

The deployment should record the digest actually released.

---

# 12. Tag immutability

ECR can prevent an existing image tag from being overwritten.

With immutable tags:

```text
Push todo-api:1.4.2
        |
        v
Tag created

Push different image as todo-api:1.4.2
        |
        v
ImageTagAlreadyExistsException
```

ECR supports immutable repositories and newer exclusion-filter modes that can leave selected tags mutable while protecting all others. ([AWS Documentation][6])

Recommended production design:

```text
Repository:
IMMUTABLE

Release tags:
1.4.2
git-a19f82c
build-1042
```

For selected operational tags:

```text
IMMUTABLE_WITH_EXCLUSION

Mutable exclusion:
development
```

Use mutable exclusions sparingly.

---

# 13. Mutable-tag exclusions

A possible policy is:

```text
All tags immutable

Except:
development
integration-test
```

This permits CI to update temporary environment tags while protecting release tags.

However, a clearer design is often:

```text
development/todo-api:
Mutable repository

production/todo-api:
Immutable repository
```

This creates a stronger environment boundary and reduces accidental exceptions.

---

# 14. Repository design strategies

## One repository per application

```text
todo-api
todo-frontend
todo-worker
```

Tags indicate environments:

```text
todo-api:development
todo-api:staging
todo-api:production
```

Advantages:

* Less repository management.
* One image history.

Risks:

* Mutable environment tags.
* Broader permissions.
* Accidental production deployment.

## Separate environment repositories

```text
development/todo-api
staging/todo-api
production/todo-api
```

Advantages:

* Clear IAM isolation.
* Different lifecycle policies.
* Production immutability.
* Easier promotion controls.
* Separate KMS and repository policies.

For a mature multi-account environment, environment-specific accounts and repositories provide the strongest boundary.

---

# 15. Recommended multi-account repository model

```text
Build account
└── candidate/todo-api

Nonproduction account
├── development/todo-api
└── staging/todo-api

Production account
└── production/todo-api
```

Pipeline:

```text
Build candidate once
        |
        v
Scan and sign
        |
        v
Promote same digest to staging
        |
        v
Validate
        |
        v
Promote same digest to production
```

Never rebuild the image separately for production.

---

# 16. Build once, promote many

Bad pipeline:

```text
Build development image
Build staging image
Build production image
```

Even when the source commit is the same, the output may differ because of:

* Dependency updates.
* Base-image updates.
* Build timestamps.
* Network-fetched assets.
* Build-tool differences.
* Nondeterministic build steps.

Better:

```text
Build once
      |
      v
Digest sha256:ABC
      |
      ├── Test in development
      ├── Test in staging
      └── Deploy exact digest in production
```

Environment-specific configuration should be injected at runtime through:

* Secrets Manager.
* Parameter Store.
* AppConfig.
* ECS environment variables.
* Kubernetes ConfigMaps and Secrets.

---

# 17. ECR authentication

Docker does not authenticate to ECR directly using native IAM request signing.

The typical flow is:

```text
IAM principal
      |
      | ecr:GetAuthorizationToken
      v
Temporary registry authorization token
      |
      v
docker login
```

ECR authorization tokens inherit the permissions of the IAM principal that requested them and remain valid for 12 hours. ([AWS Documentation][7])

Authenticate:

```bash
AWS_ACCOUNT_ID="123456789012"
AWS_REGION="ap-south-1"

aws ecr get-login-password \
  --region "$AWS_REGION" |
docker login \
  --username AWS \
  --password-stdin \
  "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
```

Never print or save the token in a CI log.

---

# 18. ECR Docker credential helper

The ECR Docker Credential Helper can retrieve ECR credentials automatically instead of requiring repeated `docker login` commands.

Concept:

```text
Docker pull
    |
    v
Credential helper
    |
    v
IAM credentials
    |
    v
ECR authorization
```

The helper simplifies local and automated usage, although current ECR documentation notes that it does not directly support MFA authentication flows. ([AWS Documentation][7])

In CI/CD, temporary IAM roles are usually preferable.

---

# 19. Push permissions

A principal pushing an image commonly needs:

```text
ecr:GetAuthorizationToken

Repository-scoped:
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

Example policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AuthenticateToECR",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "PushTodoImage",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/candidate/todo-api"
    }
  ]
}
```

`ecr:GetAuthorizationToken` must use `Resource: "*"`, while repository operations can be scoped to specific repositories.

---

# 20. Pull permissions

A principal pulling an image commonly needs:

```text
ecr:GetAuthorizationToken

Repository-scoped:
ecr:BatchCheckLayerAvailability
ecr:GetDownloadUrlForLayer
ecr:BatchGetImage
```

Example ECS execution-role policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/production/todo-api"
    }
  ]
}
```

For ECS, these permissions normally belong to the task execution role rather than the application task role.

---

# 21. IAM policy versus repository policy

## IAM identity policy

Attached to:

* IAM role.
* IAM user.
* Identity Center permission set.
* CI/CD role.
* ECS execution role.

It answers:

```text
What ECR actions may this identity perform?
```

## Repository policy

Attached to an ECR repository.

It answers:

```text
Which principals may access this repository?
```

ECR repository policies are resource policies scoped to individual repositories, while IAM policies can govern ECR access more broadly. ([AWS Documentation][8])

Cross-account access often requires both:

```text
Source identity permission
+
Destination repository permission
```

---

# 22. Cross-account repository access

Example:

```text
Production account:
Owns production/todo-api

Workload account:
Runs ECS tasks
```

The production repository policy can allow a workload account’s ECS execution role to pull images.

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowProductionECSRolePull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:role/ProductionECSTaskExecutionRole"
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
    }
  ]
}
```

The consuming role also needs:

```text
ecr:GetAuthorizationToken
```

through an IAM identity policy.

---

# 23. Encryption at rest

ECR encrypts repositories at rest by default using server-side AES-256 encryption.

A repository can instead use:

* The AWS-managed ECR KMS key.
* A customer-managed KMS key.
* DSSE-KMS where supported.

Repository encryption settings cannot be changed after the repository is created, and a customer-managed KMS key must be in the same Region as the repository. ([AWS Documentation][9])

For regulated production:

```text
Customer-managed KMS key
+
Restricted key policy
+
CloudTrail auditing
```

may be appropriate.

---

# 24. ECR and KMS grants

When a repository uses KMS encryption, ECR creates KMS grants that allow it to encrypt and decrypt repository content.

Do not manually revoke these grants.

If ECR loses access to the KMS key:

```text
Push fails
Pull fails
Image becomes inaccessible
```

AWS advises deleting the repository through the normal ECR process rather than revoking the supporting KMS grants. ([AWS Documentation][9])

---

# 25. Private network access to ECR

Private ECS or EC2 workloads can reach ECR through:

```text
NAT gateway
```

or private VPC endpoints.

A private ECR pull path commonly requires:

```text
ECR API interface endpoint
ECR Docker interface endpoint
S3 gateway endpoint
```

Concept:

```text
Private ECS task
      |
      v
ECR API endpoint
      |
      v
ECR registry endpoint
      |
      v
S3 image-layer storage path
```

Also add CloudWatch Logs, Secrets Manager and other endpoints when those services are used.

---

# 26. Build a production-ready Node.js image

```dockerfile
# syntax=docker/dockerfile:1

FROM node:24-alpine AS dependencies

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev


FROM node:24-alpine AS runtime

ENV NODE_ENV=production
ENV PORT=3002

WORKDIR /app

RUN addgroup -S appgroup \
    && adduser -S appuser -G appgroup

COPY --from=dependencies \
  --chown=appuser:appgroup \
  /app/node_modules \
  ./node_modules

COPY --chown=appuser:appgroup . .

USER appuser

EXPOSE 3002

HEALTHCHECK \
  --interval=30s \
  --timeout=5s \
  --start-period=20s \
  --retries=3 \
  CMD wget --quiet --spider http://localhost:3002/health || exit 1

CMD ["node", "start.js"]
```

Key controls:

```text
Pinned major runtime
Multi-stage build
Production dependencies only
Non-root user
No embedded secrets
Explicit health check
Small runtime stage
```

---

# 27. Use `.dockerignore`

Example:

```text
.git
.gitignore
node_modules
npm-debug.log
Dockerfile*
docker-compose*.yml
.env
.env.*
coverage
tests
docs
README.md
Jenkinsfile
terraform
```

This prevents unnecessary or sensitive files from entering the build context.

Without `.dockerignore`, an accidental:

```text
COPY . .
```

can include:

* `.env` secrets.
* Git history.
* Test reports.
* Local dependencies.
* Cloud credentials.
* Terraform state.

---

# 28. Do not put secrets in Docker build arguments

Bad:

```dockerfile
ARG DATABASE_PASSWORD
ENV DATABASE_PASSWORD=$DATABASE_PASSWORD
```

Build arguments and image-layer history may expose sensitive values.

Also avoid:

```dockerfile
COPY .env .
```

Use runtime secret delivery instead:

```text
ECS task secret
Kubernetes Secret
Secrets Manager
Parameter Store
```

The image should be usable in several environments without containing environment credentials.

---

# 29. Pin base images

Weak:

```dockerfile
FROM node:latest
```

Better:

```dockerfile
FROM node:24.4-alpine
```

Strongest reproducibility:

```dockerfile
FROM node:24.4-alpine@sha256:...
```

Pinning a digest ensures that the build uses the exact expected base-image content.

However, pinned base images do not update automatically.

You need automated tooling to:

* Detect new base-image releases.
* Rebuild images.
* Rescan.
* Promote the new digest safely.

---

# 30. Multiarchitecture images

A manifest list can reference platform-specific images:

```text
todo-api:1.4.2
├── linux/amd64 digest
└── linux/arm64 digest
```

Build:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag \
  123456789012.dkr.ecr.ap-south-1.amazonaws.com/candidate/todo-api:1.4.2 \
  --push .
```

ECR supports pushing and storing multiarchitecture images. Authentication tokens are required for each ECR registry and remain valid for 12 hours. ([AWS Documentation][10])

This lets:

* x86 ECS tasks pull `amd64`.
* Graviton ECS tasks pull `arm64`.

from the same logical tag.

---

# 31. Push an image

Authenticate:

```bash
AWS_ACCOUNT_ID="123456789012"
AWS_REGION="ap-south-1"
REPOSITORY="candidate/todo-api"
IMAGE_TAG="git-a19f82c"

aws ecr get-login-password \
  --region "$AWS_REGION" |
docker login \
  --username AWS \
  --password-stdin \
  "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
```

Build:

```bash
docker build \
  --tag "todo-api:${IMAGE_TAG}" \
  .
```

Tag:

```bash
docker tag \
  "todo-api:${IMAGE_TAG}" \
  "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${IMAGE_TAG}"
```

Push:

```bash
docker push \
  "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${IMAGE_TAG}"
```

---

# 32. Capture the image digest

After pushing:

```bash
IMAGE_DIGEST=$(
  aws ecr describe-images \
    --repository-name "$REPOSITORY" \
    --image-ids imageTag="$IMAGE_TAG" \
    --query 'imageDetails[0].imageDigest' \
    --output text \
    --region "$AWS_REGION"
)

echo "$IMAGE_DIGEST"
```

Save this digest in:

* Build metadata.
* Release record.
* Deployment manifest.
* Change request.
* SBOM metadata.
* Signature verification record.

Production deployments should be traceable to:

```text
Git commit
+
CI build
+
Image digest
+
Deployment ID
```

---

# 33. Vulnerability scanning models

Amazon ECR offers:

```text
Basic scanning
Enhanced scanning
```

## Basic scanning

Provides:

* Operating-system vulnerability scanning.
* Manual scanning.
* Scan-on-push configuration.
* ECR-native findings.

## Enhanced scanning

Uses Amazon Inspector and provides:

* Operating-system vulnerability findings.
* Programming-language package findings.
* Scan-on-push or continuous scanning.
* Updated findings when new vulnerabilities are discovered.
* EventBridge notifications.
* ECS and EKS image-usage context.

([AWS Documentation][11])

---

# 34. Basic scanning

Basic scanning is suitable for:

* Development repositories.
* Low-risk workloads.
* Cost-sensitive environments.
* Simple OS-package checks.
* Additional protection alongside CI scanning.

Limitations:

* Focuses on operating-system vulnerabilities.
* Does not provide continuous programming-language dependency monitoring.
* Findings can become outdated unless rescanned.

Current ECR Basic Scanning uses AWS-native vulnerability intelligence and supports manual or scan-on-push frequencies. ([AWS Documentation][11])

---

# 35. Enhanced scanning

Enhanced scanning integrates ECR with Amazon Inspector.

```text
Image pushed
    |
    v
Amazon Inspector creates software inventory
    |
    v
OS and language dependencies assessed
    |
    v
Findings published
    |
    v
New CVE discovered later
    |
    v
Affected active images rescanned
```

Enhanced scanning can show where images are used across ECS and EKS, helping teams prioritise vulnerabilities found in actively deployed images. ([AWS Documentation][12])

Recommended production policy:

```text
Production repositories:
Continuous enhanced scanning

Candidate repositories:
Scan on push or continuous scanning

Development:
Basic or targeted enhanced scanning
```

---

# 36. Enhanced-scanning filters

Registry-level scan filters can select repository namespaces.

Example:

```text
production/*
    → Continuous scan

candidate/*
    → Scan on push

development/*
    → Off or scan on push
```

If a repository matches both continuous and scan-on-push filters, continuous scanning takes precedence. Repositories that match no enhanced-scanning filter are not scanned through the enhanced-scanning configuration. ([AWS Documentation][12])

---

# 37. Initial enhanced-scanning eligibility

When enhanced scanning is first activated, Amazon Inspector recognises images pushed within the previous 14 days.

Older images can receive:

```text
SCAN_ELIGIBILITY_EXPIRED
```

Pushing those images again makes them eligible for scanning. ([AWS Documentation][12])

Before enabling enhanced scanning on a mature registry:

```text
1. Inventory older production images.
2. Identify images still deployed.
3. Re-push or rebuild important images.
4. Validate scan coverage.
```

---

# 38. Vulnerability severity is not enough

A finding may include:

```text
CVE
Severity
CVSS score
Affected package
Installed version
Fixed version
Exploit information
Image usage
```

Do not gate only on:

```text
Any HIGH vulnerability
```

A better policy considers:

* Is a fix available?
* Is the package reachable?
* Is the vulnerable component used?
* Is the image deployed?
* Is an exploit known?
* Is the workload internet-facing?
* Is there a compensating control?
* How old is the finding?

Example:

```text
Critical + exploitable + internet-facing + fix available
    → Block deployment

High + unused build-only package
    → Investigate and document

Medium + no fix
    → Track and monitor
```

---

# 39. Vulnerability gate strategy

Use several gates:

```text
Developer workstation:
Fast local scan

Pull request:
Dependency and Dockerfile checks

Build pipeline:
Full image scan

After push:
ECR or Inspector scan

Before deployment:
Policy decision

Runtime:
Continuous Inspector updates
```

Do not wait until after production deployment to discover the first vulnerability finding.

---

# 40. Scan EventBridge events

Enhanced scanning emits EventBridge events when:

* An initial scan completes.
* A finding is created.
* A finding is updated.
* A finding is closed.
* A repository’s scan frequency changes.

([AWS Documentation][12])

Architecture:

```text
Amazon Inspector finding
        |
        v
EventBridge
        |
        ├── Security Hub
        ├── SNS alert
        ├── Lambda ticket creator
        └── Step Functions remediation
```

Example response:

```text
Critical vulnerability found
        |
        v
Determine active ECS usage
        |
        v
Create incident
        |
        v
Rebuild patched image
        |
        v
Deploy new digest
```

---

# 41. Scanning does not automatically prevent deployment

Scanning identifies risk.

It does not automatically guarantee that ECS or EKS will reject the image.

You must create an enforcement point:

```text
CI/CD gate
Deployment approval
EKS admission policy
ECS deployment lifecycle hook
Custom policy engine
```

Without enforcement:

```text
Image has critical vulnerabilities
        |
        v
Scan displays findings
        |
        v
Deployment still proceeds
```

A finding is useful only when an owner and response policy exist.

---

# 42. Software bill of materials

An SBOM is an inventory of software components inside an artifact.

It can include:

* Operating-system packages.
* NPM packages.
* Python packages.
* Java libraries.
* Go modules.
* Package versions.
* Package relationships.
* File hashes.
* Licensing information.

Amazon Inspector supports exporting SBOMs in CycloneDX 1.4 and SPDX 2.3-compatible formats as JSON to S3. ([AWS Documentation][13])

---

# 43. Why SBOMs matter

Suppose a new vulnerability is announced in:

```text
library-x version 2.1
```

Without an SBOM:

```text
Which images contain it?
    → Search manually
```

With SBOM inventory:

```text
Query component inventory
    |
    v
Candidate todo-api:1.4.2 contains library-x 2.1
Production worker:3.8.0 does not
```

SBOMs improve:

* Vulnerability response.
* License review.
* Supply-chain visibility.
* Audit evidence.
* Component ownership.
* Dependency risk analysis.

---

# 44. Amazon Inspector SBOM Generator

Amazon Inspector SBOM Generator can produce CycloneDX SBOMs for:

* Container images.
* Directories.
* Archives.
* Local systems.
* Compiled Go binaries.
* Compiled Rust binaries.

Example:

```bash
./inspector-sbomgen container \
  --image todo-api:1.4.2 \
  --output todo-api-sbom.json
```

The generator is also used internally for Amazon Inspector’s ECR image software inventory. ([AWS Documentation][14])

Use this during CI before the image is promoted.

---

# 45. Attach SBOMs to images

ECR’s OCI v1.1 support allows SBOMs and other artifacts to be associated with a subject image through the OCI Referrers API. ([AWS Documentation][1])

Concept:

```text
Image digest:
sha256:ABC
    |
    ├── Signature
    ├── SBOM
    ├── Vulnerability report
    └── Build attestation
```

The related artifacts are stored as separate repository artifacts and count toward image-related repository quotas. ([AWS Documentation][15])

The digest is the stable relationship anchor.

---

# 46. Image signing

Image signing proves:

```text
The image was signed by a trusted identity
+
The image content has not changed since signing
```

Signing does not prove:

* The code is vulnerability-free.
* The code is correct.
* The image is authorised for every environment.
* The build system was secure.
* The signer made a good decision.

Signing provides integrity and provenance evidence.

---

# 47. Managed ECR signing

ECR managed signing automatically generates cryptographic image signatures through AWS Signer when matching images are pushed.

You configure:

```text
AWS Signer profile
+
ECR signing rule
+
Optional repository filters
```

Then:

```text
CI pushes image
      |
      v
ECR matches signing rule
      |
      v
AWS Signer creates signature
      |
      v
Signature attached to image
```

([AWS Documentation][16])

This reduces client-side signing configuration and centralises signing policy at the registry level.

---

# 48. Signing boundaries

You can configure separate signing profiles for:

```text
candidate/*
production/*
security/*
```

Example:

```text
Candidate signing profile:
Build-pipeline identity

Production signing profile:
Release-management identity
```

ECR managed signing supports several signing rules per registry, with repository filters determining which signing profile signs an image. Multiple matching rules can result in multiple signatures. ([AWS Documentation][16])

This can provide dual approval:

```text
Build signature
+
Production release signature
```

---

# 49. Manual signing

Manual signing uses:

```text
Notation CLI
+
AWS Signer plugin
```

Concept:

```bash
notation sign \
  --plugin com.amazonaws.signer.notation.plugin \
  IMAGE_REFERENCE@sha256:DIGEST
```

Manual signing is useful when:

* Signing must happen at a specific pipeline stage.
* External policy engines require Notation.
* The signer needs fine-grained client-side control.
* You need an explicit release-signing job.

ECR and AWS Signer document both managed and manual signing workflows. ([AWS Documentation][15])

---

# 50. Signature verification

Signing is valuable only if deployment verifies it.

ECR documents several verification methods:

```text
EKS managed verification
ECS Lambda admission controller through lifecycle hooks
Manual Notation verification
```

([AWS Documentation][17])

For ECS:

```text
ECS deployment
      |
      v
Lifecycle hook
      |
      v
Lambda verifier
      |
      ├── Signature trusted → Continue
      └── Missing/untrusted → Fail deployment
```

For EKS:

```text
Pod admission
      |
      v
Image signature verification
      |
      ├── Allow
      └── Reject
```

---

# 51. Image signing deployment policy

Example policy:

```text
Production image must:

1. Use an immutable digest.
2. Have a valid AWS Signer signature.
3. Be signed by the approved production profile.
4. Have an attached SBOM.
5. Have no unapproved critical vulnerability.
6. Have build provenance.
7. Originate from an approved repository.
```

Verification should fail closed:

```text
Verification service unavailable
    → Deployment does not continue
```

For low-risk development, a fail-open policy may be acceptable, but not for regulated production.

---

# 52. Provenance and attestations

A build attestation can record:

```text
Source repository
Git commit
Build system
Pipeline execution ID
Builder identity
Build timestamp
Build parameters
Output image digest
```

Concept:

```json
{
  "source": "git@example/todo-api",
  "commit": "a19f82c",
  "pipeline": "jenkins-production",
  "build": "1042",
  "imageDigest": "sha256:ABC"
}
```

ECR can store OCI-compatible attestations as reference artifacts associated with the image digest. ([AWS Documentation][1])

This lets auditors answer:

```text
Who built this?
From which commit?
In which pipeline?
Which digest was produced?
```

---

# 53. Lifecycle policies

ECR lifecycle policies automate:

```text
Expire image
or
Archive image
```

based on criteria such as:

* Tag patterns.
* Tag prefixes.
* Untagged status.
* Image count.
* Time since push.
* Time since pull.
* Time since archival.

Policies are evaluated according to rule priority, and eligible images are generally actioned within 24 hours. Always use lifecycle-policy preview before applying a policy. ([AWS Documentation][18])

---

# 54. Lifecycle policy strategy

Example:

```text
Rule 1:
Keep all production-* images active.

Rule 2:
Keep latest 30 release-* images active.

Rule 3:
Archive images not pulled for 90 days.

Rule 4:
Expire archived images after 365 days.

Rule 5:
Delete untagged images after 7 days.
```

Rule priorities matter:

```text
Priority 1
    >
Priority 2
    >
Priority 3
```

A lower numerical value has higher priority. ([AWS Documentation][18])

---

# 55. Example lifecycle policy

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images older than 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Keep only 30 release images",
      "selection": {
        "tagStatus": "tagged",
        "tagPatternList": [
          "release-*"
        ],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

Before applying:

```bash
aws ecr start-lifecycle-policy-preview \
  --repository-name candidate/todo-api \
  --lifecycle-policy-text file://lifecycle-policy.json \
  --region ap-south-1
```

Never test deletion rules for the first time on the production repository.

---

# 56. Reference artifact lifecycle

When a subject image has related artifacts such as:

```text
Signature
SBOM
Attestation
```

ECR lifecycle policies automatically expire or archive those artifacts after the subject image is deleted or archived according to the documented lifecycle behavior. ([AWS Documentation][18])

This helps prevent orphaned supply-chain metadata.

However, verify your retention and compliance requirements before deleting the source image.

---

# 57. Image archival

ECR supports an Archive storage class for long-term image retention.

Use archival for:

* Historical production releases.
* Compliance evidence.
* Rare rollback images.
* Long-retained golden images.
* Images that must not remain in active standard storage.

Archived images must be restored before they can be pulled or scanned. Restore is expected to complete within approximately 20 minutes. ([AWS Documentation][19])

Therefore:

```text
Archive
≠
Immediate rollback availability
```

Keep recent rollback releases active.

---

# 58. Archive lifecycle design

Example:

```text
Latest 10 production releases:
Active

Releases 11–100:
Archived

Older than two years:
Expired, subject to policy
```

Archived images have a 90-day minimum storage duration. Lifecycle policies cannot expire archived images before that period; manual earlier deletion can still incur the minimum-duration charge. ([AWS Documentation][20])

Use archival for genuinely cold images, not releases likely to be redeployed next week.

---

# 59. Cross-Region replication

ECR can replicate private images to other Regions.

```text
ap-south-1 ECR
      |
      | Replication
      v
ap-southeast-1 ECR
```

Use cases:

* Multi-Region ECS applications.
* Disaster recovery.
* Lower Regional image-pull dependency.
* Region-local deployment.
* Regulatory image placement.

ECR supports both cross-Region and cross-account replication. ([AWS Documentation][21])

---

# 60. Cross-account replication

Example:

```text
Build account ECR
      |
      v
Production account ECR
```

For cross-account replication:

* The source registry defines replication rules.
* The destination registry grants replication permission.
* The destination policy commonly permits `ecr:ReplicateImage`.
* `ecr:CreateRepository` is required when ECR should create destination repositories automatically.

Only the destination account requires the registry permissions policy for the replication action. ([AWS Documentation][21])

---

# 61. Replication is not promotion approval

Automatic replication means:

```text
Image pushed
    |
    v
Image copied automatically
```

It does not necessarily mean:

```text
Security approved
Release approved
Production approved
```

For controlled promotion, use:

```text
Candidate repository
      |
      v
Scan, test and sign
      |
      v
Explicit promotion action
      |
      v
Production repository
```

Use automatic replication for:

* Disaster-recovery copies.
* Region distribution.
* Trusted release namespaces.

Do not replicate every untrusted development image into the production account.

---

# 62. Replication limitations

Important ECR replication behavior includes:

* Replication occurs once for each push or restore.
* Replication does not cascade from one destination into another.
* Deletions and archive actions are not replicated.
* Repository policies and lifecycle policies are not copied by default.
* Repository creation templates can apply required destination settings.
* Replication is asynchronous.

([AWS Documentation][21])

Therefore:

```text
Source repository deleted
    ≠
Destination repository deleted
```

Create lifecycle management independently in every destination.

---

# 63. Repository creation templates

Repository creation templates standardise repositories ECR creates automatically during:

```text
Pull-through cache
Create on push
Replication
```

Templates can define:

* Tag immutability.
* Encryption.
* Repository policy.
* Lifecycle policy.
* Resource tags.

([AWS Documentation][22])

Example namespace:

```text
production/*
```

Template:

```text
Immutable tags
Customer-managed KMS key
Production repository policy
Production lifecycle policy
Cost-centre tags
```

This prevents auto-created repositories from using insecure defaults.

---

# 64. Template precedence

Templates use repository prefixes.

Example:

```text
Template A:
production/

Template B:
production/payments/
```

Repository:

```text
production/payments/api
```

uses the more specific:

```text
production/payments/
```

template.

Repository creation templates apply only when the repository is initially created and do not retroactively modify existing repositories. ([AWS Documentation][22])

---

# 65. Pull-through cache

ECR pull-through cache lets your private ECR registry cache images from supported upstream registries.

```text
ECS or developer
      |
      | Pull through ECR
      v
Private ECR cache
      |
      | Cache miss
      v
Upstream registry
```

After the upstream image is cached:

```text
Subsequent pulls
    |
    v
Private ECR
```

ECR supports pull-through cache rules for supported public and private upstream registries. ([AWS Documentation][23])

---

# 66. Pull-through cache benefits

* Reduce direct dependency on public registries.
* Centralise upstream access.
* Apply repository policy.
* Apply vulnerability scanning.
* Improve image availability.
* Reduce public pull-rate issues.
* Track image consumption.
* Apply lifecycle management.

Example:

```text
docker.io/library/node:24-alpine
        |
        v
123456789012.dkr.ecr.ap-south-1.amazonaws.com/docker-hub/library/node:24-alpine
```

Production builds pull the base image through your controlled ECR registry.

---

# 67. Pull-through cache security

Do not assume cached upstream images are trusted.

Apply:

```text
Enhanced scanning
Approved repository prefixes
Base-image allowlist
Digest pinning
Signature verification
Lifecycle policy
```

A cached malicious image remains malicious.

Pull-through cache improves control and availability; it does not automatically validate upstream content.

---

# 68. Image promotion without pulling

An image can be retagged inside ECR by retrieving and writing its manifest instead of downloading and uploading all layers.

Concept:

```text
candidate/todo-api:build-1042
        |
        v
Same manifest and digest
        |
        v
production/todo-api:1.4.2
```

ECR supports retagging compatible images without a full Docker pull and push, which saves transfer time for large images. ([AWS Documentation][24])

For cross-repository or cross-account promotion, verify that your chosen copy process preserves:

* Image digest.
* Manifest list.
* SBOM.
* Signature.
* Attestations.

---

# 69. Promotion versus copying

## Retagging

```text
Same repository
Same image manifest
New tag
```

## Replication

```text
Registry rule automatically copies image
to Region/account
```

## Promotion job

```text
Approved pipeline intentionally moves
or copies an image into a trusted namespace
```

The promotion job should create an auditable release boundary.

---

# 70. Recommended CI/CD flow

```text
1. Developer pushes source.

2. CI checks out exact commit.

3. Tests run.

4. Docker image is built.

5. Dockerfile and dependencies are scanned.

6. SBOM is generated.

7. Image is pushed to candidate repository.

8. ECR/Inspector scan completes.

9. Security policy evaluates findings.

10. Image is signed.

11. Integration tests deploy the exact digest.

12. Approval is recorded.

13. Same digest is promoted to production.

14. ECS task definition is registered with the digest.

15. ECS canary or rolling deployment starts.

16. Runtime alarms validate release.

17. Deployment record stores commit, digest and task revision.
```

---

# 71. Jenkins pipeline example

```groovy
pipeline {
  agent any

  environment {
    AWS_REGION = 'ap-south-1'
    AWS_ACCOUNT_ID = '123456789012'

    ECR_REPOSITORY = 'candidate/todo-api'

    ECR_REGISTRY = (
      "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    )
  }

  stages {
    stage('Test') {
      steps {
        sh '''
          set -euo pipefail

          npm ci
          npm test
        '''
      }
    }

    stage('Build Image') {
      steps {
        script {
          env.GIT_SHA = sh(
            script: 'git rev-parse --short=12 HEAD',
            returnStdout: true
          ).trim()

          env.IMAGE_TAG = "git-${env.GIT_SHA}"
          env.IMAGE_URI = (
            "${env.ECR_REGISTRY}/" +
            "${env.ECR_REPOSITORY}:" +
            "${env.IMAGE_TAG}"
          )
        }

        sh '''
          set -euo pipefail

          docker build \
            --tag "${IMAGE_URI}" \
            .
        '''
      }
    }

    stage('Authenticate to ECR') {
      steps {
        sh '''
          set -euo pipefail

          aws ecr get-login-password \
            --region "${AWS_REGION}" |
          docker login \
            --username AWS \
            --password-stdin \
            "${ECR_REGISTRY}"
        '''
      }
    }

    stage('Push') {
      steps {
        sh '''
          set -euo pipefail

          docker push "${IMAGE_URI}"
        '''
      }
    }

    stage('Capture Digest') {
      steps {
        script {
          env.IMAGE_DIGEST = sh(
            script: '''
              aws ecr describe-images \
                --repository-name "${ECR_REPOSITORY}" \
                --image-ids imageTag="${IMAGE_TAG}" \
                --query 'imageDetails[0].imageDigest' \
                --output text \
                --region "${AWS_REGION}"
            ''',
            returnStdout: true
          ).trim()
        }

        sh '''
          printf '%s\n' "${IMAGE_DIGEST}" \
            > image-digest.txt
        '''

        archiveArtifacts artifacts: 'image-digest.txt'
      }
    }
  }
}
```

The deployment stage should use:

```text
repository@digest
```

rather than rebuilding or trusting a mutable tag.

---

# 72. Vulnerability-gate pseudocode

```bash
set -euo pipefail

SCAN_JSON=$(
  aws ecr describe-image-scan-findings \
    --repository-name "$ECR_REPOSITORY" \
    --image-id imageDigest="$IMAGE_DIGEST" \
    --region "$AWS_REGION"
)

CRITICAL_COUNT=$(
  jq -r \
    '.imageScanFindings.findingSeverityCounts.CRITICAL // 0' \
    <<< "$SCAN_JSON"
)

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "Deployment blocked: critical findings detected"
  exit 1
fi
```

A real policy should also consider:

* Fix availability.
* Finding suppression.
* Exploitability.
* Approved risk exceptions.
* Finding age.
* Image runtime usage.

---

# 73. Deploy ECS by digest

Task-definition image:

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com/production/todo-api@sha256:ABC
```

Terraform:

```hcl
container_definitions = jsonencode([
  {
    name = "todo-api"

    image = (
      "${aws_ecr_repository.todo_api.repository_url}" +
      "@${var.image_digest}"
    )

    essential = true
  }
])
```

Now the task definition points to one immutable image.

Even if tags are changed elsewhere, this task revision continues referencing the same digest.

---

# 74. Terraform ECR repository

```hcl
resource "aws_ecr_repository" "todo_api" {
  name = "production/todo-api"

  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

Repository encryption must be selected at creation because it cannot be changed later. ([AWS Documentation][9])

---

# 75. Terraform lifecycle policy

```hcl
resource "aws_ecr_lifecycle_policy" "todo_api" {
  repository = aws_ecr_repository.todo_api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1

        description = (
          "Expire untagged images after 7 days"
        )

        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }

        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2

        description = (
          "Keep latest 50 release images"
        )

        selection = {
          tagStatus = "tagged"

          tagPatternList = [
            "release-*"
          ]

          countType   = "imageCountMoreThan"
          countNumber = 50
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

Preview equivalent policies before applying them to important repositories.

---

# 76. Terraform enhanced scanning

```hcl
resource "aws_ecr_registry_scanning_configuration" "main" {
  scan_type = "ENHANCED"

  rule {
    scan_frequency = "CONTINUOUS_SCAN"

    repository_filter {
      filter      = "production/*"
      filter_type = "WILDCARD"
    }
  }

  rule {
    scan_frequency = "SCAN_ON_PUSH"

    repository_filter {
      filter      = "candidate/*"
      filter_type = "WILDCARD"
    }
  }
}
```

Enhanced scanning configuration is registry-level and uses repository filters to determine continuous or scan-on-push behavior. ([AWS Documentation][12])

---

# 77. Terraform repository policy

```hcl
data "aws_iam_policy_document" "todo_api" {
  statement {
    sid    = "AllowProductionECSPull"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        "arn:aws:iam::222222222222:role/ProductionECSTaskExecutionRole"
      ]
    }

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
  }
}

resource "aws_ecr_repository_policy" "todo_api" {
  repository = aws_ecr_repository.todo_api.name
  policy     = data.aws_iam_policy_document.todo_api.json
}
```

---

# 78. Terraform replication configuration

```hcl
resource "aws_ecr_replication_configuration" "main" {
  replication_configuration {
    rule {
      destination {
        region      = "ap-southeast-1"
        registry_id = data.aws_caller_identity.current.account_id
      }

      repository_filter {
        filter      = "production/"
        filter_type = "PREFIX_MATCH"
      }
    }

    rule {
      destination {
        region      = "ap-south-1"
        registry_id = var.dr_account_id
      }

      repository_filter {
        filter      = "production/"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}
```

The destination account must grant the source account the required registry replication permissions for cross-account replication. ([AWS Documentation][21])

---

# 79. Cross-account replication registry policy

Destination-account conceptual policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSourceAccountReplication",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:root"
      },
      "Action": [
        "ecr:CreateRepository",
        "ecr:ReplicateImage"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:222222222222:repository/production/*"
    }
  ]
}
```

Restrict the namespace so the source cannot create arbitrary destination repositories.

---

# 80. Practical lab: create an ECR repository

```bash
AWS_REGION="ap-south-1"
REPOSITORY="lab/todo-api"

aws ecr create-repository \
  --repository-name "$REPOSITORY" \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --region "$AWS_REGION"
```

Inspect:

```bash
aws ecr describe-repositories \
  --repository-names "$REPOSITORY" \
  --region "$AWS_REGION"
```

---

# 81. Practical lab: build and push

Authenticate:

```bash
AWS_ACCOUNT_ID=$(
  aws sts get-caller-identity \
    --query Account \
    --output text
)

REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="lab-$(date +%Y%m%d%H%M%S)"
IMAGE_URI="${REGISTRY}/${REPOSITORY}:${IMAGE_TAG}"

aws ecr get-login-password \
  --region "$AWS_REGION" |
docker login \
  --username AWS \
  --password-stdin \
  "$REGISTRY"
```

Build:

```bash
docker build \
  --tag "$IMAGE_URI" \
  .
```

Push:

```bash
docker push "$IMAGE_URI"
```

---

# 82. Practical lab: retrieve digest

```bash
IMAGE_DIGEST=$(
  aws ecr describe-images \
    --repository-name "$REPOSITORY" \
    --image-ids imageTag="$IMAGE_TAG" \
    --query 'imageDetails[0].imageDigest' \
    --output text \
    --region "$AWS_REGION"
)

echo "$IMAGE_DIGEST"
```

Pull by digest:

```bash
docker pull \
  "${REGISTRY}/${REPOSITORY}@${IMAGE_DIGEST}"
```

Inspect:

```bash
docker image inspect \
  "${REGISTRY}/${REPOSITORY}@${IMAGE_DIGEST}"
```

---

# 83. Practical lab: scan findings

Start a manual basic scan where applicable:

```bash
aws ecr start-image-scan \
  --repository-name "$REPOSITORY" \
  --image-id imageDigest="$IMAGE_DIGEST" \
  --region "$AWS_REGION"
```

Read findings:

```bash
aws ecr describe-image-scan-findings \
  --repository-name "$REPOSITORY" \
  --image-id imageDigest="$IMAGE_DIGEST" \
  --region "$AWS_REGION"
```

When using enhanced scanning, use ECR and Amazon Inspector findings and understand that manual enhanced scans are not supported in the same way. ([AWS Documentation][12])

---

# 84. Practical lab: test tag immutability

Build a changed image:

```bash
docker build \
  --tag "$IMAGE_URI" \
  .
```

Attempt to overwrite the tag:

```bash
docker push "$IMAGE_URI"
```

Expected:

```text
ImageTagAlreadyExistsException
```

Now create a new release tag instead:

```bash
NEW_IMAGE_TAG="lab-$(date +%Y%m%d%H%M%S)"

docker tag \
  "$IMAGE_URI" \
  "${REGISTRY}/${REPOSITORY}:${NEW_IMAGE_TAG}"

docker push \
  "${REGISTRY}/${REPOSITORY}:${NEW_IMAGE_TAG}"
```

---

# 85. Practical lab cleanup

List images:

```bash
aws ecr list-images \
  --repository-name "$REPOSITORY" \
  --region "$AWS_REGION"
```

Delete the lab repository:

```bash
aws ecr delete-repository \
  --repository-name "$REPOSITORY" \
  --force \
  --region "$AWS_REGION"
```

Do not use `--force` against production repositories.

---

# 86. Monitoring and auditing

Monitor:

```text
Repository count
Images per repository
Push and pull API quota usage
Replication failures
Scan coverage
Critical findings
Image-signing status
Image age
Last-pull time
Lifecycle-policy actions
```

ECR publishes usage metrics associated with relevant service quotas, allowing alarms before push or pull API consumption reaches quota limits. ([AWS Documentation][25])

Use CloudTrail for actions such as:

```text
CreateRepository
DeleteRepository
PutImage
BatchDeleteImage
PutLifecyclePolicy
SetRepositoryPolicy
PutReplicationConfiguration
PutRegistryScanningConfiguration
```

ECR API activity and OCI referrer operations can be recorded through CloudTrail. ([AWS Documentation][26])

---

# 87. Security Hub and Config controls

Governance checks can verify that:

* Tag immutability is enabled.
* Lifecycle policies exist.
* Image scanning is enabled.
* Repositories use approved encryption.
* Repository policies are not overly public.

AWS Config provides a managed rule that checks whether private ECR tag immutability is enabled. ([AWS Documentation][27])

Security Hub also includes ECR controls covering repository lifecycle configuration and other ECR security settings. ([AWS Documentation][28])

---

# 88. Troubleshooting Docker login

Error:

```text
no basic auth credentials
```

Check:

1. Correct AWS account.
2. Correct Region.
3. Correct registry hostname.
4. AWS credentials are valid.
5. `ecr:GetAuthorizationToken` is allowed.
6. Docker login was executed for this registry.
7. The token has not expired.
8. Docker credential configuration is not corrupted.

Validate caller:

```bash
aws sts get-caller-identity
```

Repeat login:

```bash
aws ecr get-login-password \
  --region ap-south-1 |
docker login \
  --username AWS \
  --password-stdin \
  123456789012.dkr.ecr.ap-south-1.amazonaws.com
```

---

# 89. Troubleshooting `denied: User is not authorized`

Determine which action failed.

Push failures may require:

```text
InitiateLayerUpload
UploadLayerPart
CompleteLayerUpload
BatchCheckLayerAvailability
PutImage
```

Pull failures may require:

```text
BatchGetImage
GetDownloadUrlForLayer
BatchCheckLayerAvailability
```

Also check:

* IAM permissions boundary.
* SCP.
* Session policy.
* Repository policy.
* KMS key policy.
* VPC endpoint policy.
* Cross-account principal ARN.

---

# 90. Troubleshooting immutable-tag failure

Error:

```text
ImageTagAlreadyExistsException
```

This means the tag already exists in an immutable scope.

Correct response:

```text
Create a new unique release tag
```

Do not disable immutability simply to make the pipeline pass.

Example:

```text
Wrong:
Reuse release-42

Correct:
Create release-43
```

If a mutable operational tag is genuinely required, use a deliberate exclusion or a separate mutable repository.

---

# 91. Troubleshooting scan not appearing

Check:

```text
Basic or enhanced scanning?
Repository matches registry filter?
Scan frequency set to Off?
Image is too old for initial enhanced-scan eligibility?
Image is archived?
Operating system supported?
Scan still in progress?
Correct Region?
Inspector enabled?
```

Archived images cannot be scanned until restored. ([AWS Documentation][11])

For current basic scanning, query findings through:

```text
DescribeImageScanFindings
```

rather than relying on older fields from `DescribeImages`. ([AWS Documentation][11])

---

# 92. Troubleshooting ECS `CannotPullContainerError`

Check:

1. ECR image exists.
2. Tag or digest is correct.
3. ECS task execution role has pull permissions.
4. ECR repository policy allows the role.
5. ECR authentication can be obtained.
6. Private subnet can reach ECR API endpoint.
7. Private subnet can reach ECR Docker endpoint.
8. S3 layer path is available.
9. KMS permissions are valid.
10. Image architecture matches the ECS task architecture.
11. Replication finished in the target Region.
12. Archived image has been restored.

Use:

```bash
aws ecr describe-images \
  --repository-name production/todo-api \
  --image-ids imageDigest="$IMAGE_DIGEST" \
  --region ap-south-1
```

---

# 93. Troubleshooting replication

Check:

```text
Source replication configuration
Destination Region opted in
Destination registry policy
ecr:ReplicateImage permission
ecr:CreateRepository permission
Repository-prefix filter
Destination repository settings
Image was pushed after rule was configured
```

ECR replication does not retroactively cascade images through chained destinations, and repository policies or lifecycle policies are not copied unless separately applied through repository creation templates. ([AWS Documentation][21])

---

# 94. Troubleshooting lifecycle policies

Symptoms:

```text
Expected image not deleted
or
Unexpected image selected
```

Check:

* Rule priority.
* `tagStatus`.
* Tag pattern.
* Tag prefix.
* Image pushed time.
* Last-pull time.
* Image count.
* Manifest-list relationship.
* Subject image and reference artifacts.
* Policy preview.
* 24-hour evaluation window.

An image referenced by a manifest list cannot be expired or archived before the referencing manifest list is handled. ([AWS Documentation][18])

---

# 95. Troubleshooting signature verification

Check:

* Image is addressed by the correct digest.
* Managed-signing rule matched the repository.
* AWS Signer profile is active.
* Pushing role had signing permission.
* Signature artifact exists.
* Verifier trusts the correct profile.
* Notation trust policy is configured.
* ECR authentication works.
* Signature has not expired.
* ECS lifecycle verifier fails closed.

View managed signing status:

```bash
aws ecr describe-image-signing-status \
  --repository-name production/todo-api \
  --image-id imageDigest="$IMAGE_DIGEST" \
  --region ap-south-1
```

Managed ECR signing uses the identity that pushes the image and the matching configured signing profile. ([AWS Documentation][16])

---

# 96. Troubleshooting SBOM mismatch

If the SBOM digest or contents do not match the deployed image:

Possible causes:

* SBOM generated before the final image build.
* Image rebuilt after SBOM creation.
* Tag changed to another image.
* SBOM attached to a tag rather than digest.
* Multiarchitecture child digest differs from index digest.
* Promotion copied image but not reference artifacts.
* CI used a cached older output.

Correct order:

```text
Build final image
      |
      v
Determine final digest
      |
      v
Generate or export SBOM for that digest
      |
      v
Attach SBOM to digest
      |
      v
Sign digest
```

---

# 97. Cost considerations

Major ECR cost drivers include:

* Image storage.
* Archived image storage.
* Cross-Region replication transfer.
* Image data transfer.
* KMS requests.
* Amazon Inspector enhanced scanning.
* Large OCI reference artifacts.
* Excessive retained image versions.
* Repeated large image pushes.
* Public IPv4 and NAT-related paths outside ECR.

Cost controls:

```text
Use lifecycle policies
Archive genuinely cold images
Delete temporary untagged images
Build smaller images
Avoid unnecessary layers
Use local-Region replicas
Use pull-through cache appropriately
Limit oversized SBOM and attestation artifacts
```

Do not delete every previous image merely to reduce storage cost. Retain enough known-good releases for safe rollback.

---

# 98. Production repository checklist

```text
[ ] Private ECR is used for proprietary images
[ ] Repository naming follows environment and ownership conventions
[ ] Production repositories use immutable tags
[ ] Mutable exclusions are rare and documented
[ ] Production deploys by digest
[ ] `latest` is not used for production
[ ] Every image maps to a Git commit
[ ] Every image maps to a CI build
[ ] Build once, promote many is enforced
[ ] Dockerfiles use multi-stage builds
[ ] Containers run as non-root where possible
[ ] `.dockerignore` excludes secrets and unnecessary files
[ ] Base images are pinned
[ ] Base-image updates are automated
[ ] CI uses temporary IAM roles
[ ] Push and pull permissions are least privilege
[ ] Task execution role is repository scoped
[ ] Cross-account policies reference exact roles
[ ] Repository encryption is intentional
[ ] KMS grants are protected
[ ] VPC endpoint access is tested
[ ] Production uses enhanced continuous scanning
[ ] Candidate images are scanned before promotion
[ ] Critical-finding policy is documented
[ ] EventBridge routes important findings
[ ] SBOM is generated
[ ] SBOM is tied to image digest
[ ] Image is cryptographically signed
[ ] Deployment verifies signatures
[ ] Build provenance is recorded
[ ] Lifecycle-policy preview is reviewed
[ ] Untagged-image cleanup exists
[ ] Recent rollback images remain active
[ ] Old compliance images are archived
[ ] Archive restore is tested
[ ] Replication is configured for DR where needed
[ ] Destination repository settings are standardised
[ ] Pull-through cache is used for approved upstream images
[ ] CloudTrail records registry changes
[ ] Repository quota usage is monitored
[ ] ECS pull failure runbook exists
[ ] Image rollback is tested
```

---

# 99. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Amazon ECR:
Managed container registry

Repository:
Container image storage namespace

Tag:
Human-readable image reference

Digest:
Immutable image identity
```

## Solutions Architect Associate

Understand:

```text
Private versus public ECR
Docker authentication
Task execution-role permissions
Tag immutability
Image scanning
Lifecycle policies
Cross-account policies
Cross-Region replication
```

## DevOps Engineer Professional

Understand:

```text
Digest-based deployments
Build-once promotion
Enhanced Inspector scanning
EventBridge vulnerability automation
Repository creation templates
Pull-through cache
Managed image signing
Signature verification
SBOMs and attestations
Cross-account release promotion
Supply-chain policy enforcement
```

---

# 100. Interview questions

## Question 1: What is Amazon ECR?

**Answer:**

Amazon ECR is a managed AWS container registry for storing, scanning, signing, replicating and controlling access to Docker, OCI images and OCI-compatible artifacts.

## Question 2: What is the difference between a repository and registry?

**Answer:**

A registry is the account-and-Region-level container registry endpoint. A repository is a namespace inside that registry containing related images and artifacts.

## Question 3: What is the difference between an image tag and digest?

**Answer:**

A tag is a human-readable reference that may be mutable. A digest is a cryptographic identity tied to exact image content.

## Question 4: Why should production deploy by digest?

**Answer:**

A digest guarantees that every task pulls the exact approved image, even if tags are moved or incorrectly reused.

## Question 5: What is tag immutability?

**Answer:**

It prevents an existing image tag from being overwritten with a different image.

## Question 6: How long is an ECR authorization token valid?

**Answer:**

Twelve hours.

## Question 7: Which ECS role pulls an ECR image?

**Answer:**

The ECS task execution role.

## Question 8: What is the difference between basic and enhanced scanning?

**Answer:**

Basic scanning primarily scans OS packages manually or on push. Enhanced scanning uses Amazon Inspector to scan OS and programming-language packages and can continuously update findings.

## Question 9: Does vulnerability scanning block an ECS deployment?

**Answer:**

Not automatically. A CI/CD gate or deployment verification policy must enforce the findings.

## Question 10: What is an SBOM?

**Answer:**

It is a software bill of materials listing the software components and dependencies contained in an image.

## Question 11: How can SBOMs be associated with ECR images?

**Answer:**

They can be stored as OCI reference artifacts linked to the image digest.

## Question 12: What is ECR managed signing?

**Answer:**

It automatically signs matching images through AWS Signer when they are pushed to ECR.

## Question 13: Does signing prove an image has no vulnerabilities?

**Answer:**

No. Signing proves integrity and trusted origin, not code quality or vulnerability absence.

## Question 14: How can ECS verify an image signature?

**Answer:**

A service deployment lifecycle hook can invoke a Lambda admission controller that checks the image signature before allowing deployment to proceed.

## Question 15: What does an ECR lifecycle policy do?

**Answer:**

It automatically expires or archives images based on tags, age, pull activity or retained-image count.

## Question 16: What happens to signatures when their subject image is deleted?

**Answer:**

ECR lifecycle handling removes or archives associated reference artifacts according to the subject image’s lifecycle.

## Question 17: What is ECR image archival?

**Answer:**

It moves inactive images into a lower-access archive class. Archived images must be restored before they can be pulled or scanned.

## Question 18: What does ECR replication copy?

**Answer:**

It copies matching images to configured Regions or accounts. Repository policies and lifecycle settings are not copied automatically unless creation templates apply them.

## Question 19: What is pull-through cache?

**Answer:**

It lets ECR retrieve and cache images from supported upstream registries so workloads pull through the private ECR registry.

## Question 20: What is build once, promote many?

**Answer:**

It means creating one image digest, testing it and then promoting that exact digest through development, staging and production without rebuilding it.

---

# 101. Never-forget revision

```text
Registry:
Account-and-Region container registry.

Repository:
Namespace containing images.

Image:
Manifest plus filesystem layers.

Tag:
Human-readable image pointer.

Digest:
Immutable content identity.

Tag immutability:
Prevents tag overwrite.

Basic scanning:
ECR OS vulnerability scanning.

Enhanced scanning:
Inspector OS and language-package scanning.

SBOM:
Inventory of image software components.

Signature:
Cryptographic proof of integrity and origin.

Attestation:
Metadata proving build or policy facts.

Lifecycle policy:
Expires or archives images automatically.

Archive:
Cold storage requiring restore before pull.

Replication:
Copies images across Regions or accounts.

Repository template:
Standards for auto-created repositories.

Pull-through cache:
Private ECR cache of upstream images.

Task execution role:
Allows ECS to pull from ECR.

Build once:
Create one digest.

Promote many:
Use the same digest in every environment.
```

## One-line memory trick

```text
Build once.
Scan deeply.
Record the SBOM.
Sign the digest.
Promote the same image.
Verify before running.
Retain safe rollbacks.
Delete only with policy.
```

## Lesson 45 outcome

You can now design a container supply chain where:

```text
A developer pushes application code
    → CI builds one immutable image.

The build finishes
    → A digest identifies the exact artifact.

Dependencies need examination
    → ECR and Inspector scan the image.

A new vulnerability appears later
    → Continuous scanning updates the finding.

Security needs component inventory
    → An SBOM records every package.

Production requires trusted artifacts
    → AWS Signer signs the image digest.

ECS starts a deployment
    → A lifecycle hook verifies the signature.

The same release enters staging and production
    → The exact digest is promoted without rebuilding.

Old images consume storage
    → Lifecycle policies archive or expire them.

Another Region needs the release
    → ECR replication distributes the image.

Public base-image access must be controlled
    → Pull-through cache stores it in private ECR.
```

**Next lesson: Lesson 46 — AWS CodeBuild, CodePipeline and CodeDeploy production CI/CD: secure build environments, artifacts, approvals, cross-account deployment, ECS blue/green releases, rollback and pipeline observability.**

[1]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/images.html "Private images in Amazon ECR - Amazon ECR"
[2]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/Repositories.html?utm_source=chatgpt.com "Amazon ECR private repositories - Amazon ECR"
[3]: https://docs.aws.amazon.com/AmazonECR/latest/public/public-repository-policies.html?utm_source=chatgpt.com "Public repository policies in Amazon ECR Public - Amazon ECR Public"
[4]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/service-quotas.html?utm_source=chatgpt.com "Amazon ECR service quotas - Amazon ECR"
[5]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-pull-ecr-image.html?utm_source=chatgpt.com "Pulling an image to your local environment from an Amazon ECR private repository - Amazon ECR"
[6]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html "Preventing image tags from being overwritten in Amazon ECR - Amazon ECR"
[7]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html "Private registry authentication in Amazon ECR - Amazon ECR"
[8]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policies.html?utm_source=chatgpt.com "Private repository policies in Amazon ECR"
[9]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/encryption-at-rest.html?utm_source=chatgpt.com "Encryption at rest - Amazon ECR"
[10]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-multi-architecture-image.html?utm_source=chatgpt.com "Pushing a multi-architecture image to an Amazon ECR private repository - Amazon ECR"
[11]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html "Scan images for software vulnerabilities in Amazon ECR - Amazon ECR"
[12]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning-enhanced.html "Scan images for OS and programming language package vulnerabilities in Amazon ECR - Amazon ECR"
[13]: https://docs.aws.amazon.com/inspector/latest/user/sbom-export.html "Exporting SBOMs with Amazon Inspector - Amazon Inspector"
[14]: https://docs.aws.amazon.com/inspector/latest/user/sbom-generator.html?utm_source=chatgpt.com "Amazon Inspector SBOM Generator - Amazon Inspector"
[15]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-signing.html?utm_source=chatgpt.com "Sign images in Amazon ECR - Amazon ECR"
[16]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/managed-signing.html "Managed signing - Amazon ECR"
[17]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-signing-verification.html "Signature verification - Amazon ECR"
[18]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html "Automate the cleanup of images by using lifecycle policies in Amazon ECR - Amazon ECR"
[19]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/archive_restore_image.html?utm_source=chatgpt.com "Archiving an image in Amazon ECR - Amazon ECR"
[20]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/archive-image.html?utm_source=chatgpt.com "Archiving an image - Amazon ECR"
[21]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/replication.html "Private image replication in Amazon ECR - Amazon ECR"
[22]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-creation-templates.html "Templates to control repositories created during a pull through cache, create on push, or replication action - Amazon ECR"
[23]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache.html?utm_source=chatgpt.com "Sync an upstream registry with an Amazon ECR private ..."
[24]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-retag.html?utm_source=chatgpt.com "Retagging an image in Amazon ECR"
[25]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/monitoring-usage.html?utm_source=chatgpt.com "Amazon ECR usage metrics - Amazon ECR"
[26]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/logging-using-cloudtrail.html?utm_source=chatgpt.com "Logging Amazon ECR actions with AWS CloudTrail - Amazon ECR"
[27]: https://docs.aws.amazon.com/config/latest/developerguide/ecr-private-tag-immutability-enabled.html?utm_source=chatgpt.com "ecr-private-tag-immutability-enabled - AWS Config"
[28]: https://docs.aws.amazon.com/securityhub/latest/userguide/ecr-controls.html?utm_source=chatgpt.com "Security Hub CSPM controls for Amazon ECR"
