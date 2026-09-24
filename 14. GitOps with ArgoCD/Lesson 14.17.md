# Module 14 — GitOps with Argo CD

## Lesson 17: CI + Argo CD — Jenkins, GitHub Actions, GitLab CI & Image Promotion

We now connect software construction to GitOps delivery.

The permanent separation is:

```text
CI
builds and verifies an immutable artifact

Git promotion
declares where that artifact is approved

Argo CD
reconciles the approved declaration
```

Full flow:

```text
application source commit
          │
          ▼
    CI test and scan
          │
          ▼
 immutable image digest
          │
          ▼
 config repository PR
          │
    review / policy
          │
          ▼
        merge
          │
          ▼
       Argo CD
          │
          ▼
 progressive delivery
```

Argo's CI guidance describes this exact GitOps shift: CI builds and publishes an image, updates the Kubernetes configuration in Git, and optionally requests a sync. With automated sync, direct CI access to the Argo API is unnecessary; Argo detects the Git change through webhooks or polling. ([Argo CD][1])

---

# 14.1840 CI and CD are separate trust domains

Traditional pipeline:

```text
CI server
  ├── source access
  ├── registry push
  ├── production kubeconfig
  └── kubectl apply
```

GitOps pipeline:

```text
CI server
  ├── source access
  ├── registry push
  └── config-repo proposal access

Argo CD
  ├── config-repo read
  └── cluster reconciliation access
```

This separates build authority from deployment authority.

---

# 14.1841 CI responsibilities

```text
compile/package

unit and integration tests

static analysis

dependency and secret scanning

container build

container vulnerability scan

SBOM generation

artifact signing/attestation

registry push

release metadata

promotion proposal
```

CI should produce evidence, not only a tag.

---

# 14.1842 Argo CD responsibilities

```text
read approved desired state

render Helm/Kustomize/manifests

compare desired and live

apply authorized resources

prune and self-heal according to policy

report sync and health

coordinate hooks/waves

observe progressive-delivery resources
```

Argo should not compile application source or choose an unapproved production version.

---

# 14.1843 Artifact identity

A mutable tag:

```text
todo-api:latest
```

is a name whose bytes may change.

An image digest:

```text
todo-api@sha256:ab12...
```

identifies exact manifest content.

Production desired state should resolve to immutable bytes.

---

# 14.1844 Commit SHA tag

A useful human-facing tag is:

```text
todo-api:git-a61c92f
```

But strongest deployment identity is still the registry digest.

Record both:

```text
tag
→ traceability

digest
→ immutability
```

Enable registry tag immutability so a commit tag cannot be overwritten. Amazon ECR supports immutable tag configuration that rejects pushes reusing an existing immutable tag. ([AWS][2])

---

# 14.1845 Build once, promote many

Bad:

```text
build dev image

rebuild staging image

rebuild production image
```

Now production was not tested in staging.

Good:

```text
build digest sha256:abc once
       │
       ├── dev declares sha256:abc
       ├── staging declares sha256:abc
       └── production declares sha256:abc
```

Environment configuration changes; artifact identity does not.

---

# 14.1846 Config repository promotion

Example:

```diff
 images:
   - name: todo-api
-    newTag: git-872ce12
+    digest: sha256:ab12cd34...
```

Promotion commit message:

```text
promote(todo-api): production to a61c92f

Source commit: a61c92f
Image digest: sha256:ab12cd34...
CI run: 1842
SBOM: registry ref
Attestation: registry ref
```

---

# 14.1847 PR is a release control

A production config PR provides:

```text
diff

automated validation

approval

policy checks

change record

merge identity

rollback commit
```

Direct bot push to a protected production branch removes an important decision boundary.

Use a PR for production unless the risk model explicitly supports automated promotion.

---

# 14.1848 Repository permissions

CI bot normally needs:

```text
read app source

push image to one registry path

create branch/PR in config repo
```

It does not normally need:

```text
merge its own production PR

modify branch protection

administer Git organization

access production Kubernetes API

read production application secrets
```

---

# 14.1849 Prevent self-approval

If the same identity can:

```text
build image

change config

approve PR

merge PR

bypass policy
```

then separation of duties is mostly cosmetic.

Use:

```text
protected branches

CODEOWNERS

required reviewers

required status checks

bot cannot approve

restricted bypass
```

---

# 14.1850 Validate the promotion PR

Run:

```text
YAML/schema validation

Helm template or Kustomize build

server-side dry run against representative APIs

policy-as-code

image digest existence

signature/attestation verification

vulnerability threshold

environment-specific rules

Argo diff/preview where safely available
```

Do not merge a digest that the target account/region cannot pull.

---

# 14.1851 Image metadata contract

CI should output machine-readable release metadata:

```json
{
  "application": "todo-api",
  "sourceRevision": "a61c92f",
  "image": "123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api",
  "digest": "sha256:ab12cd34...",
  "sbom": "oci://...",
  "provenance": "oci://...",
  "ciRun": "1842"
}
```

Promotion automation consumes this contract instead of scraping console output.

---

# 14.1852 Source-to-production trace

```text
customer Pod
   │ image digest
   ▼
ECR manifest
   │ labels/attestation
   ▼
source commit
   │
   ▼
CI run and tests
   │
   ▼
config promotion PR
   │
   ▼
Argo operation
```

Every production digest should be traceable through this chain.

---

# 14.1853 Jenkins pipeline architecture

```text
Jenkins agent
   │
   ├── checkout app repo
   ├── test/scan/build
   ├── push ECR
   ├── obtain digest
   ├── checkout config repo
   ├── update candidate branch
   └── open pull request

Argo CD
   └── reacts only after merge
```

Jenkins never needs `aws eks update-kubeconfig` in this model.

---

# 14.1854 Jenkinsfile example

```groovy
pipeline {
  agent any

  environment {
    AWS_REGION = 'ap-south-1'
    ECR_REPO   = '123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api'
  }

  stages {
    stage('Test') {
      steps {
        sh './scripts/test.sh'
      }
    }

    stage('Build and Scan') {
      steps {
        sh '''
          set -eu
          docker build -t "$ECR_REPO:git-$GIT_COMMIT" .
          ./scripts/scan-image.sh "$ECR_REPO:git-$GIT_COMMIT"
        '''
      }
    }

    stage('Publish') {
      steps {
        sh './scripts/publish-image.sh'
      }
    }

    stage('Propose Dev Promotion') {
      steps {
        sh './scripts/open-config-promotion.sh dev'
      }
    }
  }
}
```

The scripts should fail closed, avoid printing credentials, and output the resolved digest.

---

# 14.1855 Jenkins credentials

Prefer workload/federated identity for AWS where possible.

For remaining credentials, use Jenkins credential bindings with the narrowest item/folder scope, not literal tokens in the Jenkinsfile. Jenkins stores configured credentials encrypted on the controller and Pipelines reference credential IDs. ([Jenkins][3])

Still assume build code can attempt to exfiltrate exposed job credentials.

Protected credentials must not be available to untrusted pull-request jobs.

---

# 14.1856 Jenkins shared-library trap

A shared library that can mutate production config is a supply-chain component.

Protect:

```text
library repository

version pin

maintainer permissions

review policy

credential exposure
```

Do not load an untrusted branch of a privileged library dynamically.

---

# 14.1857 GitHub Actions architecture

Use short-lived AWS credentials through GitHub OIDC instead of stored AWS access keys. ([GitHub][8])

Workflow permissions should be explicit:

```yaml
permissions:
  contents: read
  id-token: write
```

If the same workflow creates a config-repo PR, give only the narrowly required repository permissions through a GitHub App or scoped token; cross-repository writes are a distinct privilege.

---

# 14.1858 GitHub Actions example

```yaml
name: build-todo-api

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-todo-builder
          aws-region: ap-south-1

      - name: Test
        run: ./scripts/test.sh

      - name: Build, scan, publish, and capture digest
        run: ./scripts/release-image.sh

      - name: Publish release metadata
        uses: actions/upload-artifact@v7
        with:
          name: release-metadata
          path: release.json
```

The moving major tags make the example readable. In production, pin every action to a reviewed full commit SHA and update it through an audited dependency process.

---

# 14.1859 Separate promotion workflow

Safer split:

```text
Workflow A
builds artifact and release.json

Workflow B
uses approved event/environment
to create config PR
```

This prevents ordinary build workflow permissions from silently becoming production-promotion permissions.

Use protected environments and required reviewers where appropriate.

---

# 14.1860 GitHub fork safety

Never expose production-capable secrets or write tokens to untrusted fork code.

Be especially careful with workflows triggered by pull requests and privileged follow-up triggers.

Principle:

```text
untrusted code
must not execute
with trusted release credentials.
```

Build PRs and release trusted main-branch commits through different trust paths.

---

# 14.1861 GitLab CI architecture

GitLab CI can issue OIDC ID tokens through the `id_tokens` keyword for authentication to cloud or secret services. The `aud` claim should match the intended service, and trust policy should bind stable project/ref claims. ([GitLab][4])

Use protected branches, protected environments, and protected runners/variables for release jobs.

---

# 14.1862 GitLab CI example

```yaml
stages:
  - test
  - build
  - promote

variables:
  AWS_REGION: ap-south-1

test:
  stage: test
  script:
    - ./scripts/test.sh

build_image:
  stage: build
  id_tokens:
    AWS_OIDC_TOKEN:
      aud: sts.amazonaws.com
  script:
    - ./scripts/assume-build-role.sh "$AWS_OIDC_TOKEN"
    - ./scripts/release-image.sh
  artifacts:
    paths:
      - release.json

propose_dev:
  stage: promote
  needs: [build_image]
  script:
    - ./scripts/open-config-promotion.sh dev release.json
  rules:
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
```

Validate the AWS/GitLab OIDC audience and subject conditions for your exact provider configuration.

---

# 14.1863 Protected ref matters

Cloud trust should not accept any branch merely because it belongs to the repository.

Bind identity to:

```text
organization/group

project/repository

protected ref

workflow/job identity

environment where supported

audience
```

OIDC removes stored long-lived keys; careless trust can still grant excessive temporary credentials.

---

# 14.1864 Promotion directory model

```text
apps/todo/overlays/
│
├── dev/kustomization.yaml
├── staging/kustomization.yaml
└── prod/kustomization.yaml
```

Promotion changes one overlay at a time.

```text
dev digest     = sha256:abc
staging digest = sha256:abc
prod digest    = sha256:old
```

Production is not automatically latest; it is explicitly approved.

---

# 14.1865 Branch-per-environment tradeoff

Environment branches can work, but they complicate:

```text
merge history

drift comparison

hotfix propagation

base changes

which branch is canonical
```

Directories on one protected main branch often make promotion diffs clearer.

Choose one model deliberately and document merge semantics.

---

# 14.1866 Tag tracking trap

Application source:

```yaml
targetRevision: main
```

is normal for a config branch.

Container value:

```yaml
image: todo-api:latest
```

is not.

Do not confuse a moving Git branch whose commits are audited with a mutable container tag whose bytes can change without a config commit.

---

# 14.1867 Argo webhook

After config merge, a Git provider webhook can fast-track refresh.

```text
merge event
   ↓
Argo webhook endpoint
   ↓
affected Application refresh
```

Without webhook, periodic reconciliation still detects the change.

Configure the provider secret, TLS, ingress restrictions, and payload limits according to Argo's webhook guidance. ([Argo CD][5])

---

# 14.1868 Webhook is a hint, Git is authority

Argo treats webhook payloads as untrusted hints to refresh relevant Applications; it still reads Git to establish desired state. ([Argo CD][6])

Therefore a forged webhook should not be able to supply arbitrary manifests.

It may still cause load.

Protect the endpoint against abuse and monitor webhook rates.

---

# 14.1869 Should CI call `argocd app sync`?

Default with automated sync:

```text
No.
```

The Git commit is sufficient.

Direct sync may be justified for:

```text
manual-sync Application

pipeline that waits on a controlled release gate

special regulated process
```

If used, issue a narrow expiring project token with access to one Application, not an admin token.

---

# 14.1870 Waiting for deployment

Two models:

```text
asynchronous
CI ends after promotion PR/merge
Argo notifications report result

synchronous
release workflow waits for Synced + Healthy
```

Do not keep a build executor blocked for a human canary pause that may last hours.

Use release orchestration/status reporting for long progressive deliveries.

---

# 14.1871 CI success is not release success

```text
CI success
= artifact built and verified

promotion merge
= desired production version approved

Argo Synced
= live objects match desired state

Healthy
= resource health is good

Rollout completed
= progressive strategy promoted fully

customer SLO healthy
= service behavior acceptable
```

Report these stages separately.

---

# 14.1872 Argo CD Image Updater

Image Updater can discover newer image versions and update an Argo-managed desired reference.

Conceptual methods include:

```text
Git write-back

Argo parameter update
```

Git write-back preserves an auditable desired-state change. Parameter-only mutation can create state outside the main config files and requires careful ownership. Follow the installed Image Updater version's current CRD/annotation configuration and update-method documentation. ([Image Updater][7])

---

# 14.1873 Where Image Updater fits

Good use cases:

```text
development environment follows signed patch releases

automated dependency environment

low-risk internal tools
```

Production concern:

```text
newest allowed tag
≠
explicitly promoted and verified release.
```

For critical production, prefer promotion PRs with artifact evidence.

---

# 14.1874 Version strategy

Possible policies:

```text
semantic version constraint

newest build by timestamp

digest change tracking

explicit tag allowlist
```

Never use a policy without defining:

```text
which registry

which repository

which tags are trusted

signature requirements

how rollback works
```

---

# 14.1875 Prevent dual writers

Do not let both:

```text
CI promotion bot

and

Image Updater
```

own the same image field.

Symptoms:

```text
repeated commits

version bouncing

merge conflicts

unclear release authority
```

One field needs one authoritative writer.

---

# 14.1876 Supply-chain admission

Even a reviewed config PR can reference a malicious image.

Layer defenses:

```text
registry allowlist

digest requirement

signature verification

provenance policy

vulnerability policy

admission control

runtime controls
```

Git approval is necessary, not sufficient.

---

# 14.1877 Emergency release

Define a faster path that remains auditable:

```text
incident ticket

approved source fix

normal build/scan with justified exception policy

immutable digest

emergency config PR

named approver

Argo reconciliation

post-release review
```

Emergency must not mean `kubectl set image` with no Git update.

---

# 14.1878 Rollback release

Rollback is a new desired-state change:

```diff
- digest: sha256:newbad
+ digest: sha256:oldgood
```

Verify:

```text
old image still exists

signature still valid

database remains compatible

config remains compatible

traffic rollback path works
```

Then merge and observe.

---

# 14.1879 Promotion race

```text
PR A promotes v42

PR B promotes v43

both created from old base
```

Controls:

```text
required branch update

merge queue

one active promotion per app/environment

compare expected current digest

cancel superseded proposals
```

The promotion script must detect lost updates.

---

# 14.1880 Failure scenario — image pushed but no config PR

Check:

```text
release.json generated?

digest lookup succeeded?

config bot authenticated?

branch push allowed?

PR already exists?

path mapping correct?

fork/cross-repo permission issue?
```

Do not manually type the digest from a console without verifying source evidence.

---

# 14.1881 Failure scenario — PR merged but Argo unchanged

Check:

```text
Application repoURL/targetRevision/path

merged branch

webhook delivery

poll interval

manifest-generate-paths filtering

rendered digest

auto-sync policy

sync window
```

Start by confirming Argo sees the new Git SHA.

---

# 14.1882 Failure scenario — ImagePullBackOff

Check:

```text
digest exists in target ECR region/account

node/Pod IAM pull permission

registry network path

repository policy

architecture platform match

imagePullSecret where applicable
```

CI push success in one account does not prove production pull access in another.

---

# 14.1883 Failure scenario — wrong digest promoted

Contain:

```text
pause/abort progressive rollout

revert desired state in Git

preserve release metadata and CI logs

verify registry manifest

identify mapping or concurrency failure
```

Then fix the automation contract, not only this one YAML line.

---

# 14.1884 Failure scenario — pipeline has Argo admin token

Treat as credential exposure risk.

```text
revoke token

inspect use/audit logs

replace with no direct Argo access if auto-sync suffices

otherwise issue narrow project role token

set expiry

restrict network path

rotate related credentials if exposure suspected
```

---

# 14.1885 Production CI/GitOps checklist

```text
□ CI and CD responsibilities are documented

□ CI has no production kubeconfig

□ Image built once and promoted many

□ Commit tag is immutable

□ Deployment records image digest

□ ECR tag immutability is enabled

□ SBOM and provenance are retained

□ Config promotion uses a PR

□ Bot cannot self-approve production

□ CODEOWNERS and required checks exist

□ Promotion validates render and policy

□ OIDC is used instead of long-lived cloud keys where possible

□ OIDC trust binds project, ref, and audience

□ Untrusted PRs cannot access release credentials

□ Third-party actions/plugins are pinned and reviewed

□ Release metadata is machine-readable

□ Webhook is authenticated and monitored

□ Automated sync removes direct Argo API need

□ Any Argo token is narrow and expiring

□ Image Updater ownership does not conflict with CI

□ Rollback digest remains available

□ Promotion races are prevented

□ Release status covers Synced, Healthy, and rollout completion
```

---

# 14.1886 Interview — what should CI do in GitOps?

> **CI tests source, builds one immutable image, scans and attests it, pushes it to the registry, and proposes a reviewed change to the config repository. Argo CD reads the merged declaration and reconciles it. CI does not need direct Kubernetes or Argo API access when automated sync is enabled.** ([Argo CD][1])

---

# 14.1887 Interview — tag vs digest

> **A tag is a human-friendly reference and may be mutable unless the registry enforces immutability. A digest is content-addressed and identifies exact image content. I may publish a commit-SHA tag for traceability, but production desired state resolves to the verified digest.**

---

# 14.1888 Interview — how do you promote across environments?

> **I build once, capture the immutable digest, deploy that digest to dev, then create explicit config-repository changes that move the same digest to staging and production after their gates. I do not rebuild per environment because that would produce a different untested artifact.**

---

# 14.1889 Interview — does CI need `argocd app sync`?

> **Not normally. With automated sync, the merged Git change is enough and Argo detects it through a webhook or polling. If a controlled manual-sync process requires a call, I use a short-lived, project-scoped token restricted to the specific Application and action.**

---

# 14.1890 Never-forget Lesson 17 rules

```text
1. CI produces artifacts.

2. Git declares promotion.

3. Argo reconciles deployment.

4. CI should not hold production kubeconfig.

5. Build once, promote many.

6. A rebuilt image is a different artifact.

7. Tags aid humans.

8. Digests identify bytes.

9. Enforce tag immutability.

10. Promotion PR is a release control.

11. Bot should not self-approve production.

12. Config repo write is production-sensitive.

13. Promotion validation must render manifests.

14. Verify digest exists in target registry/region.

15. Retain SBOM and provenance.

16. OIDC replaces stored cloud keys, not trust policy.

17. Bind OIDC to project, ref, and audience.

18. Untrusted code gets no release credentials.

19. Webhook accelerates; Git remains authority.

20. Auto-sync usually removes CI-to-Argo access.

21. CI success is not deployment success.

22. Synced is not Healthy.

23. Healthy is not full canary promotion.

24. Image Updater needs explicit ownership.

25. One image field has one writer.

26. Production should not blindly follow newest.

27. Admission policy validates the image too.

28. Emergency releases remain auditable.

29. Rollback is a new Git declaration.

30. Release trace runs from Pod digest back to source and approval.
```

---

# 14.1891 Lesson 17 troubleshooting mnemonic

Memorize:

# **S-B-R-P-G-A**

```text
SOURCE
   ↓
BUILD
   ↓
REGISTRY
   ↓
PROMOTION
   ↓
GIT
   ↓
ARGO
```

The first missing link tells you which team and evidence set to inspect.

---

# ✅ Module 14 — Lesson 17 Complete

You now understand:

```text
✓ CI/CD trust separation

✓ immutable artifacts and digests

✓ build-once/promote-many

✓ config repository promotion PRs

✓ release metadata and traceability

✓ Jenkins GitOps pipelines

✓ GitHub Actions with OIDC

✓ GitLab CI ID tokens

✓ protected release credentials

✓ Argo webhooks and polling

✓ optional Argo API sync

✓ Image Updater tradeoffs

✓ supply-chain admission

✓ emergency release and rollback

✓ CI/GitOps troubleshooting
```

# Next — Module 14, Lesson 18

## Production GitOps Capstone

We will assemble the entire module into one platform:

```text
multi-account EKS

HA Argo CD

AppProjects and ApplicationSets

Kustomize/Helm

External Secrets

sync waves and migration hooks

Argo Rollouts canary

Prometheus analysis

CI image promotion

notifications, DR, and validation
```

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.17.1892 Professional Mastery Workbook

This workbook expands **CI + Argo CD — Jenkins, GitHub Actions, GitLab CI & Image Promotion** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 52 lesson-specific anchors.
- Progression: beginner, intermediate, expert, professional, industry-ready, certification review, and interview defense.
- Safety: use synthetic data, disposable resources, explicit placeholders, least privilege, and bounded failure experiments.
- Completion: retain commands or configuration, observations, screenshots or query output, decisions, rollback evidence, and a short reflection.
- Quality rule: a passing answer states assumptions, protects a user or business outcome, names ownership, and validates the final result end to end.
- Currency rule: verify current official documentation, versions, limits, pricing, and certification objectives before relying on changing product behavior.

## Seven-stage progression

| Stage | Learner must demonstrate |
|---|---|
| Beginner | Explain the concept in plain language and give one safe example. |
| Intermediate | Connect components, data, control flow, and normal operating behavior. |
| Expert | Analyze trade-offs, edge cases, scaling pressure, and correlated failures. |
| Professional | Make a reviewed decision with owner, evidence, rollout, and rollback. |
| Industry-ready | Operate the design under security, failure, recovery, cost, and compliance constraints. |
| Certification review | Map durable concepts to the latest official objectives without relying on stale wording. |
| Interview defense | Answer concisely, clarify assumptions, draw the model, and defend alternatives. |

## Concept mastery cards

### Concept card 1 - CI and CD are separate trust domains

- Lesson anchor: Traditional pipeline: CI server ├── source access ├── registry push ├── production kubeconfig └── kubectl apply GitOps pipeline: CI server ├── source access ├── registry push └── config-repo proposal access Argo CD ├── config-repo read
- Beginner explanation: Restate **CI and CD are separate trust domains** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **CI and CD are separate trust domains** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **CI and CD are separate trust domains**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **CI and CD are separate trust domains**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **CI and CD are separate trust domains** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - CI responsibilities

- Lesson anchor: compile/package unit and integration tests static analysis dependency and secret scanning container build container vulnerability scan SBOM generation artifact signing/attestation registry push release metadata promotion proposal
- Beginner explanation: Restate **CI responsibilities** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **CI responsibilities** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **CI responsibilities**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **CI responsibilities**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **CI responsibilities** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Argo CD responsibilities

- Lesson anchor: read approved desired state render Helm/Kustomize/manifests compare desired and live apply authorized resources prune and self-heal according to policy report sync and health coordinate hooks/waves observe progressive-delivery resources
- Beginner explanation: Restate **Argo CD responsibilities** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Argo CD responsibilities** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Argo CD responsibilities**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Argo CD responsibilities**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Argo CD responsibilities** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Artifact identity

- Lesson anchor: A mutable tag: todo-api:latest is a name whose bytes may change. An image digest: todo-api@sha256:ab12... identifies exact manifest content. Production desired state should resolve to immutable bytes. ---
- Beginner explanation: Restate **Artifact identity** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Artifact identity** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Artifact identity**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Artifact identity**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Artifact identity** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Commit SHA tag

- Lesson anchor: A useful human-facing tag is: todo-api:git-a61c92f But strongest deployment identity is still the registry digest. Record both: tag → traceability digest → immutability Enable registry tag immutability so a commit tag cannot be overwritten. Amazon ECR suppo...
- Beginner explanation: Restate **Commit SHA tag** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Commit SHA tag** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Commit SHA tag**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Commit SHA tag**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Commit SHA tag** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Build once, promote many

- Lesson anchor: Bad: build dev image rebuild staging image rebuild production image Now production was not tested in staging. Good: build digest sha256:abc once │ ├── dev declares sha256:abc ├── staging declares sha256:abc └── production declares sha256:abc
- Beginner explanation: Restate **Build once, promote many** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Build once, promote many** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Build once, promote many**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Build once, promote many**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Build once, promote many** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Config repository promotion

- Lesson anchor: Example: images: +    digest: sha256:ab12cd34... Promotion commit message: promote(todo-api): production to a61c92f Source commit: a61c92f Image digest: sha256:ab12cd34... CI run: 1842 SBOM: registry ref Attestation: registry ref
- Beginner explanation: Restate **Config repository promotion** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Config repository promotion** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Config repository promotion**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Config repository promotion**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Config repository promotion** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - PR is a release control

- Lesson anchor: A production config PR provides: diff automated validation approval policy checks change record merge identity rollback commit Direct bot push to a protected production branch removes an important decision boundary. Use a PR for production unless the risk m...
- Beginner explanation: Restate **PR is a release control** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PR is a release control** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **PR is a release control**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **PR is a release control**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PR is a release control** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Repository permissions

- Lesson anchor: CI bot normally needs: read app source push image to one registry path create branch/PR in config repo It does not normally need: merge its own production PR modify branch protection administer Git organization access production Kubernetes API
- Beginner explanation: Restate **Repository permissions** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Repository permissions** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Repository permissions**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Repository permissions**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Repository permissions** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Prevent self-approval

- Lesson anchor: If the same identity can: build image change config approve PR merge PR bypass policy then separation of duties is mostly cosmetic. Use: protected branches CODEOWNERS required reviewers required status checks bot cannot approve
- Beginner explanation: Restate **Prevent self-approval** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prevent self-approval** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Prevent self-approval**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Prevent self-approval**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prevent self-approval** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Validate the promotion PR

- Lesson anchor: Run: YAML/schema validation Helm template or Kustomize build server-side dry run against representative APIs policy-as-code image digest existence signature/attestation verification vulnerability threshold environment-specific rules
- Beginner explanation: Restate **Validate the promotion PR** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Validate the promotion PR** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Validate the promotion PR**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Validate the promotion PR**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Validate the promotion PR** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Image metadata contract

- Lesson anchor: CI should output machine-readable release metadata: { "application": "todo-api", "sourceRevision": "a61c92f", "image": "123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api", "digest": "sha256:ab12cd34...", "sbom": "oci://...",
- Beginner explanation: Restate **Image metadata contract** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Image metadata contract** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Image metadata contract**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Image metadata contract**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Image metadata contract** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Source-to-production trace

- Lesson anchor: customer Pod │ image digest ▼ ECR manifest │ labels/attestation ▼ source commit │ ▼ CI run and tests │ ▼ config promotion PR │ ▼ Argo operation Every production digest should be traceable through this chain. ---
- Beginner explanation: Restate **Source-to-production trace** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Source-to-production trace** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Source-to-production trace**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Source-to-production trace**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Source-to-production trace** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Jenkins pipeline architecture

- Lesson anchor: Jenkins agent │ ├── checkout app repo ├── test/scan/build ├── push ECR ├── obtain digest ├── checkout config repo ├── update candidate branch └── open pull request Argo CD └── reacts only after merge Jenkins never needs aws eks update-kubeconfig in this model.
- Beginner explanation: Restate **Jenkins pipeline architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Jenkins pipeline architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Jenkins pipeline architecture**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Jenkins pipeline architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Jenkins pipeline architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Jenkinsfile example

- Lesson anchor: pipeline { agent any environment { AWSREGION = 'ap-south-1' ECRREPO   = '123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api' } stages { stage('Test') { steps { sh './scripts/test.sh' } } stage('Build and Scan') { steps {
- Beginner explanation: Restate **Jenkinsfile example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Jenkinsfile example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Jenkinsfile example**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Jenkinsfile example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Jenkinsfile example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Jenkins credentials

- Lesson anchor: Prefer workload/federated identity for AWS where possible. For remaining credentials, use Jenkins credential bindings with the narrowest item/folder scope, not literal tokens in the Jenkinsfile. Jenkins stores configured credentials encrypted on the control...
- Beginner explanation: Restate **Jenkins credentials** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Jenkins credentials** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Jenkins credentials**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Jenkins credentials**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Jenkins credentials** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Jenkins shared-library trap

- Lesson anchor: A shared library that can mutate production config is a supply-chain component. Protect: library repository version pin maintainer permissions review policy credential exposure Do not load an untrusted branch of a privileged library dynamically.
- Beginner explanation: Restate **Jenkins shared-library trap** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Jenkins shared-library trap** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Jenkins shared-library trap**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Jenkins shared-library trap**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Jenkins shared-library trap** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - GitHub Actions architecture

- Lesson anchor: Use short-lived AWS credentials through GitHub OIDC instead of stored AWS access keys. ([GitHub][8]) Workflow permissions should be explicit: permissions: contents: read id-token: write If the same workflow creates a config-repo PR, give only the narrowly r...
- Beginner explanation: Restate **GitHub Actions architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **GitHub Actions architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **GitHub Actions architecture**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **GitHub Actions architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **GitHub Actions architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - GitHub Actions example

- Lesson anchor: name: build-todo-api on: push: branches: [main] permissions: contents: read id-token: write jobs: build: runs-on: ubuntu-latest steps: with: role-to-assume: arn:aws:iam::123456789012:role/github-todo-builder aws-region: ap-south-1
- Beginner explanation: Restate **GitHub Actions example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **GitHub Actions example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **GitHub Actions example**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **GitHub Actions example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **GitHub Actions example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Separate promotion workflow

- Lesson anchor: Safer split: Workflow A builds artifact and release.json Workflow B uses approved event/environment to create config PR This prevents ordinary build workflow permissions from silently becoming production-promotion permissions.
- Beginner explanation: Restate **Separate promotion workflow** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Separate promotion workflow** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Separate promotion workflow**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Separate promotion workflow**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Separate promotion workflow** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - GitHub fork safety

- Lesson anchor: Never expose production-capable secrets or write tokens to untrusted fork code. Be especially careful with workflows triggered by pull requests and privileged follow-up triggers. Principle: untrusted code must not execute
- Beginner explanation: Restate **GitHub fork safety** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **GitHub fork safety** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **GitHub fork safety**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **GitHub fork safety**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **GitHub fork safety** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - GitLab CI architecture

- Lesson anchor: GitLab CI can issue OIDC ID tokens through the idtokens keyword for authentication to cloud or secret services. The aud claim should match the intended service, and trust policy should bind stable project/ref claims. ([GitLab][4])
- Beginner explanation: Restate **GitLab CI architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **GitLab CI architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **GitLab CI architecture**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **GitLab CI architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **GitLab CI architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - GitLab CI example

- Lesson anchor: stages: variables: AWSREGION: ap-south-1 test: stage: test script: buildimage: stage: build idtokens: AWSOIDCTOKEN: aud: sts.amazonaws.com script: artifacts: paths: proposedev: stage: promote needs: [buildimage] script: rules:
- Beginner explanation: Restate **GitLab CI example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **GitLab CI example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **GitLab CI example**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **GitLab CI example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **GitLab CI example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Protected ref matters

- Lesson anchor: Cloud trust should not accept any branch merely because it belongs to the repository. Bind identity to: organization/group project/repository protected ref workflow/job identity environment where supported audience OIDC removes stored long-lived keys; carel...
- Beginner explanation: Restate **Protected ref matters** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Protected ref matters** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Protected ref matters**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Protected ref matters**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Protected ref matters** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - Promotion directory model

- Lesson anchor: apps/todo/overlays/ │ ├── dev/kustomization.yaml ├── staging/kustomization.yaml └── prod/kustomization.yaml Promotion changes one overlay at a time. dev digest     = sha256:abc staging digest = sha256:abc prod digest    = sha256:old
- Beginner explanation: Restate **Promotion directory model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Promotion directory model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Promotion directory model**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Promotion directory model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Promotion directory model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - Branch-per-environment tradeoff

- Lesson anchor: Environment branches can work, but they complicate: merge history drift comparison hotfix propagation base changes which branch is canonical Directories on one protected main branch often make promotion diffs clearer. Choose one model deliberately and docum...
- Beginner explanation: Restate **Branch-per-environment tradeoff** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Branch-per-environment tradeoff** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Branch-per-environment tradeoff**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Branch-per-environment tradeoff**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Branch-per-environment tradeoff** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - Tag tracking trap

- Lesson anchor: Application source: targetRevision: main is normal for a config branch. Container value: image: todo-api:latest is not. Do not confuse a moving Git branch whose commits are audited with a mutable container tag whose bytes can change without a config commit.
- Beginner explanation: Restate **Tag tracking trap** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Tag tracking trap** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Tag tracking trap**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Tag tracking trap**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Tag tracking trap** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - Argo webhook

- Lesson anchor: After config merge, a Git provider webhook can fast-track refresh. merge event ↓ Argo webhook endpoint ↓ affected Application refresh Without webhook, periodic reconciliation still detects the change. Configure the provider secret, TLS, ingress restrictions...
- Beginner explanation: Restate **Argo webhook** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Argo webhook** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Argo webhook**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Argo webhook**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Argo webhook** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - Webhook is a hint, Git is authority

- Lesson anchor: Argo treats webhook payloads as untrusted hints to refresh relevant Applications; it still reads Git to establish desired state. ([Argo CD][6]) Therefore a forged webhook should not be able to supply arbitrary manifests.
- Beginner explanation: Restate **Webhook is a hint, Git is authority** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Webhook is a hint, Git is authority** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Webhook is a hint, Git is authority**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Webhook is a hint, Git is authority**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Webhook is a hint, Git is authority** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - Should CI call `argocd app sync`?

- Lesson anchor: Default with automated sync: No. The Git commit is sufficient. Direct sync may be justified for: manual-sync Application pipeline that waits on a controlled release gate special regulated process If used, issue a narrow expiring project token with access to...
- Beginner explanation: Restate **Should CI call `argocd app sync`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Should CI call `argocd app sync`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Should CI call `argocd app sync`?**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Should CI call `argocd app sync`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Should CI call `argocd app sync`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - Waiting for deployment

- Lesson anchor: Two models: asynchronous CI ends after promotion PR/merge Argo notifications report result synchronous release workflow waits for Synced + Healthy Do not keep a build executor blocked for a human canary pause that may last hours.
- Beginner explanation: Restate **Waiting for deployment** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Waiting for deployment** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Waiting for deployment**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Waiting for deployment**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Waiting for deployment** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - CI success is not release success

- Lesson anchor: CI success = artifact built and verified promotion merge = desired production version approved Argo Synced = live objects match desired state Healthy = resource health is good Rollout completed = progressive strategy promoted fully
- Beginner explanation: Restate **CI success is not release success** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **CI success is not release success** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **CI success is not release success**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **CI success is not release success**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **CI success is not release success** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Argo CD Image Updater

- Lesson anchor: Image Updater can discover newer image versions and update an Argo-managed desired reference. Conceptual methods include: Git write-back Argo parameter update Git write-back preserves an auditable desired-state change. Parameter-only mutation can create sta...
- Beginner explanation: Restate **Argo CD Image Updater** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Argo CD Image Updater** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Argo CD Image Updater**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Argo CD Image Updater**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Argo CD Image Updater** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Where Image Updater fits

- Lesson anchor: Good use cases: development environment follows signed patch releases automated dependency environment low-risk internal tools Production concern: newest allowed tag ≠ explicitly promoted and verified release. For critical production, prefer promotion PRs w...
- Beginner explanation: Restate **Where Image Updater fits** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Where Image Updater fits** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Where Image Updater fits**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Where Image Updater fits**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Where Image Updater fits** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - Version strategy

- Lesson anchor: Possible policies: semantic version constraint newest build by timestamp digest change tracking explicit tag allowlist Never use a policy without defining: which registry which repository which tags are trusted signature requirements
- Beginner explanation: Restate **Version strategy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Version strategy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Version strategy**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Version strategy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Version strategy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - Prevent dual writers

- Lesson anchor: Do not let both: CI promotion bot and Image Updater own the same image field. Symptoms: repeated commits version bouncing merge conflicts unclear release authority One field needs one authoritative writer. ---
- Beginner explanation: Restate **Prevent dual writers** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prevent dual writers** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Prevent dual writers**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Prevent dual writers**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prevent dual writers** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - Supply-chain admission

- Lesson anchor: Even a reviewed config PR can reference a malicious image. Layer defenses: registry allowlist digest requirement signature verification provenance policy vulnerability policy admission control runtime controls Git approval is necessary, not sufficient.
- Beginner explanation: Restate **Supply-chain admission** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Supply-chain admission** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Supply-chain admission**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Supply-chain admission**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Supply-chain admission** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - Emergency release

- Lesson anchor: Define a faster path that remains auditable: incident ticket approved source fix normal build/scan with justified exception policy immutable digest emergency config PR named approver Argo reconciliation post-release review
- Beginner explanation: Restate **Emergency release** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Emergency release** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Emergency release**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Emergency release**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Emergency release** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - Rollback release

- Lesson anchor: Rollback is a new desired-state change: + digest: sha256:oldgood Verify: old image still exists signature still valid database remains compatible config remains compatible traffic rollback path works Then merge and observe.
- Beginner explanation: Restate **Rollback release** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Rollback release** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Rollback release**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Rollback release**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Rollback release** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - Promotion race

- Lesson anchor: PR A promotes v42 PR B promotes v43 both created from old base Controls: required branch update merge queue one active promotion per app/environment compare expected current digest cancel superseded proposals The promotion script must detect lost updates.
- Beginner explanation: Restate **Promotion race** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Promotion race** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Promotion race**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Promotion race**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Promotion race** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Failure scenario — image pushed but no config PR

- Lesson anchor: Check: release.json generated? digest lookup succeeded? config bot authenticated? branch push allowed? PR already exists? path mapping correct? fork/cross-repo permission issue? Do not manually type the digest from a console without verifying source evidence.
- Beginner explanation: Restate **Failure scenario — image pushed but no config PR** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — image pushed but no config PR** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Failure scenario — image pushed but no config PR**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Failure scenario — image pushed but no config PR**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — image pushed but no config PR** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - Failure scenario — PR merged but Argo unchanged

- Lesson anchor: Check: Application repoURL/targetRevision/path merged branch webhook delivery poll interval manifest-generate-paths filtering rendered digest auto-sync policy sync window Start by confirming Argo sees the new Git SHA. ---
- Beginner explanation: Restate **Failure scenario — PR merged but Argo unchanged** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — PR merged but Argo unchanged** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Failure scenario — PR merged but Argo unchanged**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Failure scenario — PR merged but Argo unchanged**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — PR merged but Argo unchanged** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - Failure scenario — ImagePullBackOff

- Lesson anchor: Check: digest exists in target ECR region/account node/Pod IAM pull permission registry network path repository policy architecture platform match imagePullSecret where applicable CI push success in one account does not prove production pull access in another.
- Beginner explanation: Restate **Failure scenario — ImagePullBackOff** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — ImagePullBackOff** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Failure scenario — ImagePullBackOff**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Failure scenario — ImagePullBackOff**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — ImagePullBackOff** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - Failure scenario — wrong digest promoted

- Lesson anchor: Contain: pause/abort progressive rollout revert desired state in Git preserve release metadata and CI logs verify registry manifest identify mapping or concurrency failure Then fix the automation contract, not only this one YAML line.
- Beginner explanation: Restate **Failure scenario — wrong digest promoted** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — wrong digest promoted** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Failure scenario — wrong digest promoted**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Failure scenario — wrong digest promoted**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — wrong digest promoted** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - Failure scenario — pipeline has Argo admin token

- Lesson anchor: Treat as credential exposure risk. revoke token inspect use/audit logs replace with no direct Argo access if auto-sync suffices otherwise issue narrow project role token set expiry restrict network path rotate related credentials if exposure suspected
- Beginner explanation: Restate **Failure scenario — pipeline has Argo admin token** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Failure scenario — pipeline has Argo admin token** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Failure scenario — pipeline has Argo admin token**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Failure scenario — pipeline has Argo admin token**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Failure scenario — pipeline has Argo admin token** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 46 - Production CI/GitOps checklist

- Lesson anchor: □ CI and CD responsibilities are documented □ CI has no production kubeconfig □ Image built once and promoted many □ Commit tag is immutable □ Deployment records image digest □ ECR tag immutability is enabled □ SBOM and provenance are retained
- Beginner explanation: Restate **Production CI/GitOps checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production CI/GitOps checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Production CI/GitOps checklist**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Production CI/GitOps checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production CI/GitOps checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 47 - Interview — what should CI do in GitOps?

- Lesson anchor: CI tests source, builds one immutable image, scans and attests it, pushes it to the registry, and proposes a reviewed change to the config repository. Argo CD reads the merged declaration and reconciles it. CI does not need direct Kubernetes or Argo API acc...
- Beginner explanation: Restate **Interview — what should CI do in GitOps?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — what should CI do in GitOps?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — what should CI do in GitOps?**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — what should CI do in GitOps?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — what should CI do in GitOps?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 48 - Interview — tag vs digest

- Lesson anchor: A tag is a human-friendly reference and may be mutable unless the registry enforces immutability. A digest is content-addressed and identifies exact image content. I may publish a commit-SHA tag for traceability, but production desired state resolves to the...
- Beginner explanation: Restate **Interview — tag vs digest** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — tag vs digest** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — tag vs digest**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — tag vs digest**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — tag vs digest** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 49 - Interview — how do you promote across environments?

- Lesson anchor: I build once, capture the immutable digest, deploy that digest to dev, then create explicit config-repository changes that move the same digest to staging and production after their gates. I do not rebuild per environment because that would produce a differ...
- Beginner explanation: Restate **Interview — how do you promote across environments?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — how do you promote across environments?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — how do you promote across environments?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — how do you promote across environments?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — how do you promote across environments?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 50 - Interview — does CI need `argocd app sync`?

- Lesson anchor: Not normally. With automated sync, the merged Git change is enough and Argo detects it through a webhook or polling. If a controlled manual-sync process requires a call, I use a short-lived, project-scoped token restricted to the specific Application and ac...
- Beginner explanation: Restate **Interview — does CI need `argocd app sync`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — does CI need `argocd app sync`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — does CI need `argocd app sync`?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — does CI need `argocd app sync`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — does CI need `argocd app sync`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 51 - Never-forget Lesson 17 rules

- Lesson anchor: ---
- Beginner explanation: Restate **Never-forget Lesson 17 rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget Lesson 17 rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Never-forget Lesson 17 rules**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Never-forget Lesson 17 rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget Lesson 17 rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 52 - Lesson 17 troubleshooting mnemonic

- Lesson anchor: Memorize: SOURCE ↓ BUILD ↓ REGISTRY ↓ PROMOTION ↓ GIT ↓ ARGO The first missing link tells you which team and evidence set to inspect. --- You now understand: ✓ CI/CD trust separation ✓ immutable artifacts and digests ✓ build-once/promote-many
- Beginner explanation: Restate **Lesson 17 troubleshooting mnemonic** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lesson 17 troubleshooting mnemonic** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Lesson 17 troubleshooting mnemonic**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Lesson 17 troubleshooting mnemonic**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Lesson 17 troubleshooting mnemonic** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - CI and CD are separate trust domains x governance

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **CI and CD are separate trust domains** while a change involving **Artifact identity** places **governance** at risk.
- Plain-language question: What problem does **CI and CD are separate trust domains** solve here, and who notices first when it fails?
- Lesson evidence anchor: Traditional pipeline: CI server ├── source access ├── registry push ├── production kubeconfig └── kubectl apply GitOps pipeline: CI server ├── source access ├── registry push └── config-repo proposal access Argo CD ├── config-repo read
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **CI and CD are separate trust domains** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - CI responsibilities x correctness

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **CI responsibilities** while a change involving **Validate the promotion PR** places **correctness** at risk.
- Plain-language question: What problem does **CI responsibilities** solve here, and who notices first when it fails?
- Lesson evidence anchor: compile/package unit and integration tests static analysis dependency and secret scanning container build container vulnerability scan SBOM generation artifact signing/attestation registry push release metadata promotion proposal
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **CI responsibilities** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Argo CD responsibilities x capacity

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Argo CD responsibilities** while a change involving **GitHub Actions architecture** places **capacity** at risk.
- Plain-language question: What problem does **Argo CD responsibilities** solve here, and who notices first when it fails?
- Lesson evidence anchor: read approved desired state render Helm/Kustomize/manifests compare desired and live apply authorized resources prune and self-heal according to policy report sync and health coordinate hooks/waves observe progressive-delivery resources
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Argo CD responsibilities** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Artifact identity x cost efficiency

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Artifact identity** while a change involving **Promotion directory model** places **cost efficiency** at risk.
- Plain-language question: What problem does **Artifact identity** solve here, and who notices first when it fails?
- Lesson evidence anchor: A mutable tag: todo-api:latest is a name whose bytes may change. An image digest: todo-api@sha256:ab12... identifies exact manifest content. Production desired state should resolve to immutable bytes. ---
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Artifact identity** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Commit SHA tag x recovery

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Commit SHA tag** while a change involving **CI success is not release success** places **recovery** at risk.
- Plain-language question: What problem does **Commit SHA tag** solve here, and who notices first when it fails?
- Lesson evidence anchor: A useful human-facing tag is: todo-api:git-a61c92f But strongest deployment identity is still the registry digest. Record both: tag → traceability digest → immutability Enable registry tag immutability so a commit tag cannot be overwritten. Amazon ECR suppo...
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Commit SHA tag** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Build once, promote many x change management

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Build once, promote many** while a change involving **Rollback release** places **change management** at risk.
- Plain-language question: What problem does **Build once, promote many** solve here, and who notices first when it fails?
- Lesson evidence anchor: Bad: build dev image rebuild staging image rebuild production image Now production was not tested in staging. Good: build digest sha256:abc once │ ├── dev declares sha256:abc ├── staging declares sha256:abc └── production declares sha256:abc
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Build once, promote many** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Config repository promotion x dependency failure

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Config repository promotion** while a change involving **Production CI/GitOps checklist** places **dependency failure** at risk.
- Plain-language question: What problem does **Config repository promotion** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: images: +    digest: sha256:ab12cd34... Promotion commit message: promote(todo-api): production to a61c92f Source commit: a61c92f Image digest: sha256:ab12cd34... CI run: 1842 SBOM: registry ref Attestation: registry ref
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Config repository promotion** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - PR is a release control x developer experience

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **PR is a release control** while a change involving **CI and CD are separate trust domains** places **developer experience** at risk.
- Plain-language question: What problem does **PR is a release control** solve here, and who notices first when it fails?
- Lesson evidence anchor: A production config PR provides: diff automated validation approval policy checks change record merge identity rollback commit Direct bot push to a protected production branch removes an important decision boundary. Use a PR for production unless the risk m...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **PR is a release control** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Repository permissions x availability

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Repository permissions** while a change involving **PR is a release control** places **availability** at risk.
- Plain-language question: What problem does **Repository permissions** solve here, and who notices first when it fails?
- Lesson evidence anchor: CI bot normally needs: read app source push image to one registry path create branch/PR in config repo It does not normally need: merge its own production PR modify branch protection administer Git organization access production Kubernetes API
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Repository permissions** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Prevent self-approval x security

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prevent self-approval** while a change involving **Jenkinsfile example** places **security** at risk.
- Plain-language question: What problem does **Prevent self-approval** solve here, and who notices first when it fails?
- Lesson evidence anchor: If the same identity can: build image change config approve PR merge PR bypass policy then separation of duties is mostly cosmetic. Use: protected branches CODEOWNERS required reviewers required status checks bot cannot approve
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Prevent self-approval** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Validate the promotion PR x delivery safety

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Validate the promotion PR** while a change involving **GitLab CI architecture** places **delivery safety** at risk.
- Plain-language question: What problem does **Validate the promotion PR** solve here, and who notices first when it fails?
- Lesson evidence anchor: Run: YAML/schema validation Helm template or Kustomize build server-side dry run against representative APIs policy-as-code image digest existence signature/attestation verification vulnerability threshold environment-specific rules
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Validate the promotion PR** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Image metadata contract x multi-tenancy

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Image metadata contract** while a change involving **Webhook is a hint, Git is authority** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Image metadata contract** solve here, and who notices first when it fails?
- Lesson evidence anchor: CI should output machine-readable release metadata: { "application": "todo-api", "sourceRevision": "a61c92f", "image": "123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api", "digest": "sha256:ab12cd34...", "sbom": "oci://...",
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Image metadata contract** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Source-to-production trace x observability

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Source-to-production trace** while a change involving **Prevent dual writers** places **observability** at risk.
- Plain-language question: What problem does **Source-to-production trace** solve here, and who notices first when it fails?
- Lesson evidence anchor: customer Pod │ image digest ▼ ECR manifest │ labels/attestation ▼ source commit │ ▼ CI run and tests │ ▼ config promotion PR │ ▼ Argo operation Every production digest should be traceable through this chain. ---
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Source-to-production trace** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Jenkins pipeline architecture x regional resilience

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Jenkins pipeline architecture** while a change involving **Failure scenario — ImagePullBackOff** places **regional resilience** at risk.
- Plain-language question: What problem does **Jenkins pipeline architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Jenkins agent │ ├── checkout app repo ├── test/scan/build ├── push ECR ├── obtain digest ├── checkout config repo ├── update candidate branch └── open pull request Argo CD └── reacts only after merge Jenkins never needs aws eks update-kubeconfig in this model.
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Jenkins pipeline architecture** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Jenkinsfile example x business value

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Jenkinsfile example** while a change involving **Interview — does CI need `argocd app sync`?** places **business value** at risk.
- Plain-language question: What problem does **Jenkinsfile example** solve here, and who notices first when it fails?
- Lesson evidence anchor: pipeline { agent any environment { AWSREGION = 'ap-south-1' ECRREPO   = '123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api' } stages { stage('Test') { steps { sh './scripts/test.sh' } } stage('Build and Scan') { steps {
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Jenkinsfile example** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Jenkins credentials x latency

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Jenkins credentials** while a change involving **Commit SHA tag** places **latency** at risk.
- Plain-language question: What problem does **Jenkins credentials** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prefer workload/federated identity for AWS where possible. For remaining credentials, use Jenkins credential bindings with the narrowest item/folder scope, not literal tokens in the Jenkinsfile. Jenkins stores configured credentials encrypted on the control...
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Jenkins credentials** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Jenkins shared-library trap x privacy

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Jenkins shared-library trap** while a change involving **Image metadata contract** places **privacy** at risk.
- Plain-language question: What problem does **Jenkins shared-library trap** solve here, and who notices first when it fails?
- Lesson evidence anchor: A shared library that can mutate production config is a supply-chain component. Protect: library repository version pin maintainer permissions review policy credential exposure Do not load an untrusted branch of a privileged library dynamically.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Jenkins shared-library trap** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - GitHub Actions architecture x operability

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **GitHub Actions architecture** while a change involving **GitHub Actions example** places **operability** at risk.
- Plain-language question: What problem does **GitHub Actions architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Use short-lived AWS credentials through GitHub OIDC instead of stored AWS access keys. ([GitHub][8]) Workflow permissions should be explicit: permissions: contents: read id-token: write If the same workflow creates a config-repo PR, give only the narrowly r...
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **GitHub Actions architecture** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - GitHub Actions example x data integrity

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **GitHub Actions example** while a change involving **Branch-per-environment tradeoff** places **data integrity** at risk.
- Plain-language question: What problem does **GitHub Actions example** solve here, and who notices first when it fails?
- Lesson evidence anchor: name: build-todo-api on: push: branches: [main] permissions: contents: read id-token: write jobs: build: runs-on: ubuntu-latest steps: with: role-to-assume: arn:aws:iam::123456789012:role/github-todo-builder aws-region: ap-south-1
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **GitHub Actions example** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Separate promotion workflow x automation safety

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Separate promotion workflow** while a change involving **Argo CD Image Updater** places **automation safety** at risk.
- Plain-language question: What problem does **Separate promotion workflow** solve here, and who notices first when it fails?
- Lesson evidence anchor: Safer split: Workflow A builds artifact and release.json Workflow B uses approved event/environment to create config PR This prevents ordinary build workflow permissions from silently becoming production-promotion permissions.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Separate promotion workflow** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - GitHub fork safety x governance

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **GitHub fork safety** while a change involving **Promotion race** places **governance** at risk.
- Plain-language question: What problem does **GitHub fork safety** solve here, and who notices first when it fails?
- Lesson evidence anchor: Never expose production-capable secrets or write tokens to untrusted fork code. Be especially careful with workflows triggered by pull requests and privileged follow-up triggers. Principle: untrusted code must not execute
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **GitHub fork safety** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - GitLab CI architecture x correctness

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **GitLab CI architecture** while a change involving **Interview — what should CI do in GitOps?** places **correctness** at risk.
- Plain-language question: What problem does **GitLab CI architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: GitLab CI can issue OIDC ID tokens through the idtokens keyword for authentication to cloud or secret services. The aud claim should match the intended service, and trust policy should bind stable project/ref claims. ([GitLab][4])
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **GitLab CI architecture** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - GitLab CI example x capacity

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **GitLab CI example** while a change involving **CI responsibilities** places **capacity** at risk.
- Plain-language question: What problem does **GitLab CI example** solve here, and who notices first when it fails?
- Lesson evidence anchor: stages: variables: AWSREGION: ap-south-1 test: stage: test script: buildimage: stage: build idtokens: AWSOIDCTOKEN: aud: sts.amazonaws.com script: artifacts: paths: proposedev: stage: promote needs: [buildimage] script: rules:
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **GitLab CI example** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Protected ref matters x cost efficiency

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Protected ref matters** while a change involving **Repository permissions** places **cost efficiency** at risk.
- Plain-language question: What problem does **Protected ref matters** solve here, and who notices first when it fails?
- Lesson evidence anchor: Cloud trust should not accept any branch merely because it belongs to the repository. Bind identity to: organization/group project/repository protected ref workflow/job identity environment where supported audience OIDC removes stored long-lived keys; carel...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Protected ref matters** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Promotion directory model x recovery

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Promotion directory model** while a change involving **Jenkins credentials** places **recovery** at risk.
- Plain-language question: What problem does **Promotion directory model** solve here, and who notices first when it fails?
- Lesson evidence anchor: apps/todo/overlays/ │ ├── dev/kustomization.yaml ├── staging/kustomization.yaml └── prod/kustomization.yaml Promotion changes one overlay at a time. dev digest     = sha256:abc staging digest = sha256:abc prod digest    = sha256:old
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Promotion directory model** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - Branch-per-environment tradeoff x change management

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Branch-per-environment tradeoff** while a change involving **GitLab CI example** places **change management** at risk.
- Plain-language question: What problem does **Branch-per-environment tradeoff** solve here, and who notices first when it fails?
- Lesson evidence anchor: Environment branches can work, but they complicate: merge history drift comparison hotfix propagation base changes which branch is canonical Directories on one protected main branch often make promotion diffs clearer. Choose one model deliberately and docum...
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Branch-per-environment tradeoff** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Tag tracking trap x dependency failure

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Tag tracking trap** while a change involving **Should CI call `argocd app sync`?** places **dependency failure** at risk.
- Plain-language question: What problem does **Tag tracking trap** solve here, and who notices first when it fails?
- Lesson evidence anchor: Application source: targetRevision: main is normal for a config branch. Container value: image: todo-api:latest is not. Do not confuse a moving Git branch whose commits are audited with a mutable container tag whose bytes can change without a config commit.
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Tag tracking trap** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - Argo webhook x developer experience

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Argo webhook** while a change involving **Supply-chain admission** places **developer experience** at risk.
- Plain-language question: What problem does **Argo webhook** solve here, and who notices first when it fails?
- Lesson evidence anchor: After config merge, a Git provider webhook can fast-track refresh. merge event ↓ Argo webhook endpoint ↓ affected Application refresh Without webhook, periodic reconciliation still detects the change. Configure the provider secret, TLS, ingress restrictions...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Argo webhook** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - Webhook is a hint, Git is authority x availability

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Webhook is a hint, Git is authority** while a change involving **Failure scenario — wrong digest promoted** places **availability** at risk.
- Plain-language question: What problem does **Webhook is a hint, Git is authority** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo treats webhook payloads as untrusted hints to refresh relevant Applications; it still reads Git to establish desired state. ([Argo CD][6]) Therefore a forged webhook should not be able to supply arbitrary manifests.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Webhook is a hint, Git is authority** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - Should CI call `argocd app sync`? x security

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Should CI call `argocd app sync`?** while a change involving **Never-forget Lesson 17 rules** places **security** at risk.
- Plain-language question: What problem does **Should CI call `argocd app sync`?** solve here, and who notices first when it fails?
- Lesson evidence anchor: Default with automated sync: No. The Git commit is sufficient. Direct sync may be justified for: manual-sync Application pipeline that waits on a controlled release gate special regulated process If used, issue a narrow expiring project token with access to...
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Should CI call `argocd app sync`?** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - Waiting for deployment x delivery safety

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Waiting for deployment** while a change involving **Build once, promote many** places **delivery safety** at risk.
- Plain-language question: What problem does **Waiting for deployment** solve here, and who notices first when it fails?
- Lesson evidence anchor: Two models: asynchronous CI ends after promotion PR/merge Argo notifications report result synchronous release workflow waits for Synced + Healthy Do not keep a build executor blocked for a human canary pause that may last hours.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Waiting for deployment** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - CI success is not release success x multi-tenancy

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **CI success is not release success** while a change involving **Source-to-production trace** places **multi-tenancy** at risk.
- Plain-language question: What problem does **CI success is not release success** solve here, and who notices first when it fails?
- Lesson evidence anchor: CI success = artifact built and verified promotion merge = desired production version approved Argo Synced = live objects match desired state Healthy = resource health is good Rollout completed = progressive strategy promoted fully
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **CI success is not release success** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Argo CD Image Updater x observability

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Argo CD Image Updater** while a change involving **Separate promotion workflow** places **observability** at risk.
- Plain-language question: What problem does **Argo CD Image Updater** solve here, and who notices first when it fails?
- Lesson evidence anchor: Image Updater can discover newer image versions and update an Argo-managed desired reference. Conceptual methods include: Git write-back Argo parameter update Git write-back preserves an auditable desired-state change. Parameter-only mutation can create sta...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Argo CD Image Updater** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Where Image Updater fits x regional resilience

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Where Image Updater fits** while a change involving **Tag tracking trap** places **regional resilience** at risk.
- Plain-language question: What problem does **Where Image Updater fits** solve here, and who notices first when it fails?
- Lesson evidence anchor: Good use cases: development environment follows signed patch releases automated dependency environment low-risk internal tools Production concern: newest allowed tag ≠ explicitly promoted and verified release. For critical production, prefer promotion PRs w...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Where Image Updater fits** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Version strategy x business value

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Version strategy** while a change involving **Where Image Updater fits** places **business value** at risk.
- Plain-language question: What problem does **Version strategy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Possible policies: semantic version constraint newest build by timestamp digest change tracking explicit tag allowlist Never use a policy without defining: which registry which repository which tags are trusted signature requirements
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Version strategy** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Prevent dual writers x latency

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Prevent dual writers** while a change involving **Failure scenario — image pushed but no config PR** places **latency** at risk.
- Plain-language question: What problem does **Prevent dual writers** solve here, and who notices first when it fails?
- Lesson evidence anchor: Do not let both: CI promotion bot and Image Updater own the same image field. Symptoms: repeated commits version bouncing merge conflicts unclear release authority One field needs one authoritative writer. ---
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Prevent dual writers** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Supply-chain admission x privacy

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Supply-chain admission** while a change involving **Interview — tag vs digest** places **privacy** at risk.
- Plain-language question: What problem does **Supply-chain admission** solve here, and who notices first when it fails?
- Lesson evidence anchor: Even a reviewed config PR can reference a malicious image. Layer defenses: registry allowlist digest requirement signature verification provenance policy vulnerability policy admission control runtime controls Git approval is necessary, not sufficient.
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Supply-chain admission** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Emergency release x operability

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Emergency release** while a change involving **Argo CD responsibilities** places **operability** at risk.
- Plain-language question: What problem does **Emergency release** solve here, and who notices first when it fails?
- Lesson evidence anchor: Define a faster path that remains auditable: incident ticket approved source fix normal build/scan with justified exception policy immutable digest emergency config PR named approver Argo reconciliation post-release review
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Emergency release** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Rollback release x data integrity

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Rollback release** while a change involving **Prevent self-approval** places **data integrity** at risk.
- Plain-language question: What problem does **Rollback release** solve here, and who notices first when it fails?
- Lesson evidence anchor: Rollback is a new desired-state change: + digest: sha256:oldgood Verify: old image still exists signature still valid database remains compatible config remains compatible traffic rollback path works Then merge and observe.
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Rollback release** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - Promotion race x automation safety

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Promotion race** while a change involving **Jenkins shared-library trap** places **automation safety** at risk.
- Plain-language question: What problem does **Promotion race** solve here, and who notices first when it fails?
- Lesson evidence anchor: PR A promotes v42 PR B promotes v43 both created from old base Controls: required branch update merge queue one active promotion per app/environment compare expected current digest cancel superseded proposals The promotion script must detect lost updates.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Promotion race** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Failure scenario — image pushed but no config PR x governance

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Failure scenario — image pushed but no config PR** while a change involving **Protected ref matters** places **governance** at risk.
- Plain-language question: What problem does **Failure scenario — image pushed but no config PR** solve here, and who notices first when it fails?
- Lesson evidence anchor: Check: release.json generated? digest lookup succeeded? config bot authenticated? branch push allowed? PR already exists? path mapping correct? fork/cross-repo permission issue? Do not manually type the digest from a console without verifying source evidence.
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Failure scenario — image pushed but no config PR** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - Failure scenario — PR merged but Argo unchanged x correctness

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Failure scenario — PR merged but Argo unchanged** while a change involving **Waiting for deployment** places **correctness** at risk.
- Plain-language question: What problem does **Failure scenario — PR merged but Argo unchanged** solve here, and who notices first when it fails?
- Lesson evidence anchor: Check: Application repoURL/targetRevision/path merged branch webhook delivery poll interval manifest-generate-paths filtering rendered digest auto-sync policy sync window Start by confirming Argo sees the new Git SHA. ---
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Failure scenario — PR merged but Argo unchanged** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - Failure scenario — ImagePullBackOff x capacity

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Failure scenario — ImagePullBackOff** while a change involving **Emergency release** places **capacity** at risk.
- Plain-language question: What problem does **Failure scenario — ImagePullBackOff** solve here, and who notices first when it fails?
- Lesson evidence anchor: Check: digest exists in target ECR region/account node/Pod IAM pull permission registry network path repository policy architecture platform match imagePullSecret where applicable CI push success in one account does not prove production pull access in another.
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Failure scenario — ImagePullBackOff** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 044 - Failure scenario — wrong digest promoted x cost efficiency

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Failure scenario — wrong digest promoted** while a change involving **Failure scenario — pipeline has Argo admin token** places **cost efficiency** at risk.
- Plain-language question: What problem does **Failure scenario — wrong digest promoted** solve here, and who notices first when it fails?
- Lesson evidence anchor: Contain: pause/abort progressive rollout revert desired state in Git preserve release metadata and CI logs verify registry manifest identify mapping or concurrency failure Then fix the automation contract, not only this one YAML line.
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Failure scenario — wrong digest promoted** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 045 - Failure scenario — pipeline has Argo admin token x recovery

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Failure scenario — pipeline has Argo admin token** while a change involving **Lesson 17 troubleshooting mnemonic** places **recovery** at risk.
- Plain-language question: What problem does **Failure scenario — pipeline has Argo admin token** solve here, and who notices first when it fails?
- Lesson evidence anchor: Treat as credential exposure risk. revoke token inspect use/audit logs replace with no direct Argo access if auto-sync suffices otherwise issue narrow project role token set expiry restrict network path rotate related credentials if exposure suspected
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Failure scenario — pipeline has Argo admin token** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 046 - Production CI/GitOps checklist x change management

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Production CI/GitOps checklist** while a change involving **Config repository promotion** places **change management** at risk.
- Plain-language question: What problem does **Production CI/GitOps checklist** solve here, and who notices first when it fails?
- Lesson evidence anchor: □ CI and CD responsibilities are documented □ CI has no production kubeconfig □ Image built once and promoted many □ Commit tag is immutable □ Deployment records image digest □ ECR tag immutability is enabled □ SBOM and provenance are retained
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Production CI/GitOps checklist** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 047 - Interview — what should CI do in GitOps? x dependency failure

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Interview — what should CI do in GitOps?** while a change involving **Jenkins pipeline architecture** places **dependency failure** at risk.
- Plain-language question: What problem does **Interview — what should CI do in GitOps?** solve here, and who notices first when it fails?
- Lesson evidence anchor: CI tests source, builds one immutable image, scans and attests it, pushes it to the registry, and proposes a reviewed change to the config repository. Argo CD reads the merged declaration and reconciles it. CI does not need direct Kubernetes or Argo API acc...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Interview — what should CI do in GitOps?** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 048 - Interview — tag vs digest x developer experience

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Interview — tag vs digest** while a change involving **GitHub fork safety** places **developer experience** at risk.
- Plain-language question: What problem does **Interview — tag vs digest** solve here, and who notices first when it fails?
- Lesson evidence anchor: A tag is a human-friendly reference and may be mutable unless the registry enforces immutability. A digest is content-addressed and identifies exact image content. I may publish a commit-SHA tag for traceability, but production desired state resolves to the...
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Interview — tag vs digest** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 049 - Interview — how do you promote across environments? x availability

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Interview — how do you promote across environments?** while a change involving **Argo webhook** places **availability** at risk.
- Plain-language question: What problem does **Interview — how do you promote across environments?** solve here, and who notices first when it fails?
- Lesson evidence anchor: I build once, capture the immutable digest, deploy that digest to dev, then create explicit config-repository changes that move the same digest to staging and production after their gates. I do not rebuild per environment because that would produce a differ...
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Interview — how do you promote across environments?** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 050 - Interview — does CI need `argocd app sync`? x security

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Interview — does CI need `argocd app sync`?** while a change involving **Version strategy** places **security** at risk.
- Plain-language question: What problem does **Interview — does CI need `argocd app sync`?** solve here, and who notices first when it fails?
- Lesson evidence anchor: Not normally. With automated sync, the merged Git change is enough and Argo detects it through a webhook or polling. If a controlled manual-sync process requires a call, I use a short-lived, project-scoped token restricted to the specific Application and ac...
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Interview — does CI need `argocd app sync`?** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 051 - Never-forget Lesson 17 rules x delivery safety

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Never-forget Lesson 17 rules** while a change involving **Failure scenario — PR merged but Argo unchanged** places **delivery safety** at risk.
- Plain-language question: What problem does **Never-forget Lesson 17 rules** solve here, and who notices first when it fails?
- Lesson evidence anchor: ---
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Never-forget Lesson 17 rules** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 052 - Lesson 17 troubleshooting mnemonic x multi-tenancy

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Lesson 17 troubleshooting mnemonic** while a change involving **Interview — how do you promote across environments?** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Lesson 17 troubleshooting mnemonic** solve here, and who notices first when it fails?
- Lesson evidence anchor: Memorize: SOURCE ↓ BUILD ↓ REGISTRY ↓ PROMOTION ↓ GIT ↓ ARGO The first missing link tells you which team and evidence set to inspect. --- You now understand: ✓ CI/CD trust separation ✓ immutable artifacts and digests ✓ build-once/promote-many
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Lesson 17 troubleshooting mnemonic** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 053 - CI and CD are separate trust domains x observability

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **CI and CD are separate trust domains** while a change involving **Artifact identity** places **observability** at risk.
- Plain-language question: What problem does **CI and CD are separate trust domains** solve here, and who notices first when it fails?
- Lesson evidence anchor: Traditional pipeline: CI server ├── source access ├── registry push ├── production kubeconfig └── kubectl apply GitOps pipeline: CI server ├── source access ├── registry push └── config-repo proposal access Argo CD ├── config-repo read
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **CI and CD are separate trust domains** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 054 - CI responsibilities x regional resilience

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **CI responsibilities** while a change involving **Validate the promotion PR** places **regional resilience** at risk.
- Plain-language question: What problem does **CI responsibilities** solve here, and who notices first when it fails?
- Lesson evidence anchor: compile/package unit and integration tests static analysis dependency and secret scanning container build container vulnerability scan SBOM generation artifact signing/attestation registry push release metadata promotion proposal
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **CI responsibilities** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 055 - Argo CD responsibilities x business value

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Argo CD responsibilities** while a change involving **GitHub Actions architecture** places **business value** at risk.
- Plain-language question: What problem does **Argo CD responsibilities** solve here, and who notices first when it fails?
- Lesson evidence anchor: read approved desired state render Helm/Kustomize/manifests compare desired and live apply authorized resources prune and self-heal according to policy report sync and health coordinate hooks/waves observe progressive-delivery resources
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Argo CD responsibilities** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 056 - Artifact identity x latency

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Artifact identity** while a change involving **Promotion directory model** places **latency** at risk.
- Plain-language question: What problem does **Artifact identity** solve here, and who notices first when it fails?
- Lesson evidence anchor: A mutable tag: todo-api:latest is a name whose bytes may change. An image digest: todo-api@sha256:ab12... identifies exact manifest content. Production desired state should resolve to immutable bytes. ---
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Artifact identity** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 057 - Commit SHA tag x privacy

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Commit SHA tag** while a change involving **CI success is not release success** places **privacy** at risk.
- Plain-language question: What problem does **Commit SHA tag** solve here, and who notices first when it fails?
- Lesson evidence anchor: A useful human-facing tag is: todo-api:git-a61c92f But strongest deployment identity is still the registry digest. Record both: tag → traceability digest → immutability Enable registry tag immutability so a commit tag cannot be overwritten. Amazon ECR suppo...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Commit SHA tag** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 57.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/ "Automation from CI Pipelines - Argo CD"
[2]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html "Prevent Image Tags from Being Overwritten - Amazon ECR"
[3]: https://www.jenkins.io/doc/book/using/using-credentials/ "Using Credentials - Jenkins"
[4]: https://docs.gitlab.com/ci/secrets/id_token_authentication/ "OIDC Authentication Using ID Tokens - GitLab"
[5]: https://argo-cd.readthedocs.io/en/stable/operator-manual/webhook/ "Webhook Configuration - Argo CD"
[6]: https://argo-cd.readthedocs.io/en/stable/operator-manual/security/#webhook-payloads "Webhook Payload Security - Argo CD"
[7]: https://argocd-image-updater.readthedocs.io/en/stable/basics/update-methods/ "Image Updater Update Methods"
[8]: https://docs.github.com/en/actions/concepts/security/openid-connect "OpenID Connect - GitHub Actions"
