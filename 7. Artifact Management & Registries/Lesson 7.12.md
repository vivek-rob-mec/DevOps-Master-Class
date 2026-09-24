# Lesson 7.12 — Artifact Cleanup, Retention, and Rollback Safety Deep Dive

# Safe Cleanup Rules, ECR Lifecycle Policies, GHCR Cleanup Strategy, Rollback Windows, Stable Release Protection, Untagged Images, Storage Cost vs Safety, and Cleanup Automation

In Lesson 7.11, we secured access to the registry.

Now we answer a very practical production question:

```text id="l0w6bj"
When can we safely delete old artifacts?
```

This sounds simple, but it is dangerous.

Bad cleanup can break rollback.

Bad cleanup can delete audit evidence.

Bad cleanup can remove the exact image used in production.

A professional cleanup policy balances:

```text id="htl1th"
storage cost
security risk
rollback safety
audit/compliance
release frequency
developer productivity
```

Amazon ECR lifecycle policies are designed to manage image cleanup in private repositories; rules can expire images based on selection criteria, and ECR records lifecycle-policy actions in CloudTrail. ([AWS Documentation][1])

---

# 1. Beginner Level — Why Artifact Cleanup Matters

Every CI/CD pipeline creates artifacts:

```text id="o12xon"
Docker images
SBOM files
scan reports
provenance files
signing records
release metadata
deployment reports
temporary build cache
test reports
tar.gz release bundles
```

Over time, storage grows.

Example:

```text id="6tirxk"
10 builds per day
each image 300 MB
30 days = 90 GB
multiple services = hundreds of GB
```

So cleanup is necessary.

But deleting blindly is risky.

Bad:

```text id="gyk74x"
delete everything older than 7 days
```

Why bad?

```text id="bqgqkd"
previous production version may be older than 7 days
stable release may be needed for audit
rollback image may disappear
SBOM/provenance evidence may be deleted
incident investigation becomes harder
```

Core rule:

```text id="trhayr"
Cleanup must protect rollback and audit before reducing storage.
```

---

# 2. Beginner Mental Model

Think of artifacts like medical records plus spare parts.

```text id="r944xm"
current production image:
  must keep

previous production image:
  must keep for rollback

stable release records:
  keep for audit

dev images:
  can expire faster

PR images:
  can expire fastest

untagged images:
  usually safe to delete after grace period
```

A safe cleanup policy asks:

```text id="9kxu3g"
Is this artifact currently deployed?
Is it the previous production version?
Is it a stable release?
Is it referenced by release metadata?
Is it needed for audit?
Is it needed for rollback?
Is it only a temporary dev/PR build?
```

If yes to rollback/audit/current production, do not delete.

---

# 3. Artifact Categories

Classify artifacts before cleanup.

```text id="s25yl6"
production-current:
  currently running in production

production-previous:
  previous known-good production version

stable-release:
  official version tag, audit-worthy

release-candidate:
  staging or QA candidate

dev-build:
  main branch or dev branch build

pr-build:
  pull request build

untagged-image:
  image with no tag

build-cache:
  temporary cache

reports:
  scan/SBOM/test/provenance/deployment evidence
```

Recommended retention:

```text id="phrrpm"
production-current:
  keep

production-previous:
  keep at least rollback window

stable-release:
  keep long term

release-candidate:
  keep medium term

dev-build:
  keep short term

pr-build:
  keep very short term

untagged-image:
  delete after short grace period

build-cache:
  clean regularly

release evidence:
  keep with stable releases
```

---

# 4. Cleanup Anti-Patterns

Avoid these:

```text id="t0h4vd"
delete all images older than X days
delete untagged images immediately
delete without checking deployment records
delete stable releases to save small cost
delete SBOM/provenance but keep image
delete image but keep release metadata pointing to it
let developers manually delete production images
allow lifecycle policy to delete rollback target
```

Professional rule:

```text id="ilf2lf"
Cleanup should be policy-driven, not emotional or manual.
```

---

# 5. Rollback Window

A rollback window is the minimum time you keep rollback artifacts.

Example:

```text id="ppvsgu"
production rollback window:
  30 days

regulated/audit-heavy app:
  90 days, 180 days, or longer

portfolio/demo app:
  14-30 days is enough
```

For your DevOps learning project:

```text id="pkrx7a"
stable releases:
  keep

current production:
  keep

previous production:
  keep at least 30 days

staging candidates:
  keep 14-30 days

dev builds:
  keep last 20-30

PR builds:
  keep 7 days

untagged:
  delete after 7 days
```

---

# 6. ECR Lifecycle Policy Concepts

ECR lifecycle policies contain ordered rules. Each rule defines image selection criteria and an expiration action. ECR lifecycle policy examples include rules for expiring untagged images, keeping a specific number of images, and using tag prefix or tag pattern selection. ([AWS Documentation][2])

Important lifecycle selection fields:

```text id="cikqcu"
tagStatus:
  tagged, untagged, any

tagPrefixList:
  match images with tag prefixes

tagPatternList:
  match tag patterns with wildcards

countType:
  imageCountMoreThan
  sinceImagePushed

countNumber:
  number threshold

countUnit:
  days, when using sinceImagePushed
```

ECR docs recommend using `tagPatternList` for tagged images when you want wildcard-style matching, such as `prod*`. ([AWS Documentation][3])

---

# 7. ECR Lifecycle Policy Design

Bad policy:

```json id="ri9r4z"
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Delete everything older than 7 days",
      "selection": {
        "tagStatus": "any",
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
```

Why bad?

```text id="p4ggki"
may delete production rollback image
may delete stable releases
may delete release candidates still under testing
```

Better policy:

```text id="a7r5hd"
delete old dev images by prefix/count
delete old PR images by prefix/time
delete untagged images after grace period
do not target stable release tags
do not target production tags
```

---

# 8. Tag Naming for Cleanup

Cleanup is easier when tags are structured.

Good tag strategy:

```text id="w6jy4t"
stable:
  0.7.0-a1b2c3d

dev:
  dev-0.7.0-a1b2c3d

pr:
  pr-123-a1b2c3d

rc:
  0.8.0-rc.1-a1b2c3d

hotfix:
  0.7.1-hotfix-a1b2c3d
```

Cleanup-friendly:

```text id="yp5lrl"
dev-*:
  short retention

pr-*:
  very short retention

*-rc.*:
  medium retention

semver stable:
  long retention
```

Bad:

```text id="irzbut"
latest
test
new
old
final
prod
backup
```

---

# 9. Hands-On — Create Cleanup Directory

Run:

```bash id="ru86tp"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p cleanup/{policies,reports,runbooks,examples,state}
```

Check:

```bash id="5i2hqn"
tree -L 2 cleanup
```

Expected:

```text id="5fhdxb"
cleanup
├── examples
├── policies
├── reports
├── runbooks
└── state
```

---

# 10. Create Retention Policy

Create:

```bash id="1t7a1u"
nano cleanup/policies/demo-node-api-retention-policy.json
```

Paste:

```json id="x1pslj"
{
  "service_name": "demo-node-api",
  "retention_policy_version": "1.0",
  "rules": {
    "production_current": {
      "action": "keep",
      "reason": "currently deployed"
    },
    "production_previous": {
      "action": "keep",
      "minimum_days": 30,
      "reason": "rollback safety"
    },
    "stable_releases": {
      "action": "keep",
      "minimum_days": 180,
      "reason": "release audit and rollback"
    },
    "release_candidates": {
      "action": "expire",
      "keep_last": 10,
      "minimum_days": 30,
      "tag_patterns": [
        "*-rc.*"
      ]
    },
    "dev_builds": {
      "action": "expire",
      "keep_last": 30,
      "tag_prefixes": [
        "dev-"
      ]
    },
    "pr_builds": {
      "action": "expire",
      "minimum_days": 7,
      "tag_prefixes": [
        "pr-"
      ]
    },
    "untagged_images": {
      "action": "expire",
      "minimum_days": 7
    },
    "release_evidence": {
      "action": "keep_with_release",
      "items": [
        "sbom",
        "provenance",
        "signing_record",
        "scan_report",
        "promotion_record",
        "deployment_report"
      ]
    }
  },
  "never_delete_if": [
    "currently_deployed",
    "previous_production",
    "referenced_by_release_metadata",
    "referenced_by_deployment_report",
    "under_active_incident_review",
    "stable_release_inside_audit_window"
  ]
}
```

This becomes your human-readable governance source.

---

# 11. Create ECR Lifecycle Policy — Safe Starter

Create:

```bash id="jttw7f"
nano cleanup/policies/ecr-safe-lifecycle-policy.json
```

Paste:

```json id="0li95a"
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire old PR images older than 7 days",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["pr-"],
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
      "description": "Keep only last 30 dev images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["dev-"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
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
    }
  ]
}
```

Notice what this does **not** target:

```text id="c5z4uw"
stable semver tags
production tags
release candidate tags
current production
previous production
```

ECR supports rules for untagged images and count-based cleanup; AWS examples show policies such as keeping only one untagged image and expiring the rest, or expiring images by tag prefix/count. ([AWS Documentation][2])

---

# 12. Apply ECR Lifecycle Policy

Use your earlier script or create a cleanup-specific one.

Create:

```bash id="3loqap"
nano scripts/apply-safe-ecr-cleanup-policy.sh
```

Paste:

```bash id="mr1acc"
#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-demo-node-api}"
POLICY_FILE="${POLICY_FILE:-cleanup/policies/ecr-safe-lifecycle-policy.json}"

if [ ! -f "$POLICY_FILE" ]; then
  echo "ERROR: lifecycle policy file not found: $POLICY_FILE" >&2
  exit 1
fi

echo "===== Apply Safe ECR Cleanup Policy ====="
echo "Repository: $ECR_REPOSITORY"
echo "Region: $AWS_REGION"
echo "Policy: $POLICY_FILE"

aws ecr put-lifecycle-policy \
  --repository-name "$ECR_REPOSITORY" \
  --lifecycle-policy-text "file://$POLICY_FILE" \
  --region "$AWS_REGION"

echo
echo "Applied lifecycle policy:"
aws ecr get-lifecycle-policy \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq .
```

Make executable:

```bash id="b8uz33"
chmod +x scripts/apply-safe-ecr-cleanup-policy.sh
```

Run when AWS permissions are available:

```bash id="7i5iuo"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/apply-safe-ecr-cleanup-policy.sh
```

---

# 13. ECR Lifecycle Preview

Before applying cleanup, preview.

Create:

```bash id="vyyc5n"
nano scripts/preview-ecr-lifecycle-policy.sh
```

Paste:

```bash id="wucnwf"
#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-demo-node-api}"
POLICY_FILE="${POLICY_FILE:-cleanup/policies/ecr-safe-lifecycle-policy.json}"

if [ ! -f "$POLICY_FILE" ]; then
  echo "ERROR: policy file not found: $POLICY_FILE" >&2
  exit 1
fi

echo "===== Preview ECR Lifecycle Policy ====="
echo "Repository: $ECR_REPOSITORY"
echo "Region: $AWS_REGION"
echo "Policy: $POLICY_FILE"

aws ecr start-lifecycle-policy-preview \
  --repository-name "$ECR_REPOSITORY" \
  --lifecycle-policy-text "file://$POLICY_FILE" \
  --region "$AWS_REGION" \
  >/tmp/ecr-lifecycle-preview-start.json

cat /tmp/ecr-lifecycle-preview-start.json | jq .

echo
echo "Waiting briefly before reading preview..."
sleep 5

aws ecr get-lifecycle-policy-preview \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq .
```

Make executable:

```bash id="3c7w4b"
chmod +x scripts/preview-ecr-lifecycle-policy.sh
```

Run:

```bash id="wok2uk"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/preview-ecr-lifecycle-policy.sh
```

Professional rule:

```text id="lc31uo"
Preview cleanup before applying it when the registry supports preview.
```

---

# 14. ECR Cleanup Safety Check

Before deleting anything manually, check current and previous versions.

Create:

```bash id="owvzu4"
nano scripts/ecr-cleanup-safety-check.sh
```

Paste:

```bash id="en3rk4"
#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-demo-node-api}"
STATE_FILE="${STATE_FILE:-promotion/state/environments.json}"
OUTPUT_DIR="${OUTPUT_DIR:-cleanup/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$OUTPUT_DIR/ecr-cleanup-safety-$TIMESTAMP.json"

mkdir -p "$OUTPUT_DIR"

echo "===== ECR Cleanup Safety Check ====="
echo "Repository: $ECR_REPOSITORY"
echo "Region: $AWS_REGION"

PROD_CURRENT=""
PROD_PREVIOUS=""
STAGING_CURRENT=""

if [ -f "$STATE_FILE" ]; then
  PROD_CURRENT="$(jq -r '.production.current_version // ""' "$STATE_FILE")"
  PROD_PREVIOUS="$(jq -r '.production.previous_version // ""' "$STATE_FILE")"
  STAGING_CURRENT="$(jq -r '.staging.current_version // ""' "$STATE_FILE")"
fi

IMAGE_DETAILS="$(aws ecr describe-images \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  --output json)"

cat > "$REPORT_FILE" <<EOF
{
  "repository": "$ECR_REPOSITORY",
  "region": "$AWS_REGION",
  "state_file": "$STATE_FILE",
  "protected_versions": {
    "production_current": "$PROD_CURRENT",
    "production_previous": "$PROD_PREVIOUS",
    "staging_current": "$STAGING_CURRENT"
  },
  "image_count": $(echo "$IMAGE_DETAILS" | jq '.imageDetails | length'),
  "images": $(echo "$IMAGE_DETAILS" | jq '[.imageDetails[] | {imageTags, imageDigest, imagePushedAt, imageSizeInBytes}]'),
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$REPORT_FILE" | jq .
echo
echo "Report written: $REPORT_FILE"
```

Make executable:

```bash id="mrg1n5"
chmod +x scripts/ecr-cleanup-safety-check.sh
```

Run:

```bash id="9u0xft"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/ecr-cleanup-safety-check.sh
```

---

# 15. Manual Delete Safety Rule

Manual deletion must be rare.

Before deleting:

```text id="xay1ch"
confirm image is not current production
confirm image is not previous production
confirm image is not staging current
confirm image is not stable release
confirm image is not referenced by release metadata
confirm image is not under incident review
confirm rollback window has passed
```

Manual ECR delete command:

```bash id="nbls6d"
aws ecr batch-delete-image \
  --repository-name demo-node-api \
  --image-ids imageTag=TAG_TO_DELETE \
  --region ap-south-1
```

Only do this for safe candidates.

Never manually delete:

```text id="2poogo"
current production
previous production
stable release inside retention period
image referenced by deployment records
```

---

# 16. GHCR Cleanup Strategy

GitHub Packages supports deleting and restoring packages and package versions from the UI, and the REST API includes endpoints for deleting and restoring package versions. ([GitHub Docs][4])

GitHub’s REST package docs state that deleting package versions requires token scopes such as `read:packages` and `delete:packages`, and restore endpoints also exist for packages/package versions. ([GitHub Docs][5])

For GHCR, use this strategy:

```text id="m2nhw5"
do not automate deletion early
make package cleanup a reviewed workflow
delete only dev/pr versions first
keep stable release versions
keep production current and previous
avoid deleting versions referenced by release records
```

Professional caution:

```text id="2a8pvt"
GHCR cleanup should be conservative because package permissions and restore behavior depend on package/repository context.
```

---

# 17. GHCR Manual Cleanup Checklist

Before deleting a GHCR package version:

```text id="jfhnd2"
1. Confirm image tag.
2. Confirm it is not production current.
3. Confirm it is not previous production.
4. Confirm it is not a stable release.
5. Confirm no deployment record references it.
6. Confirm no incident investigation needs it.
7. Confirm token/user has delete permission.
8. Delete package version.
9. Record cleanup action.
```

Create:

```bash id="yf8xkh"
nano cleanup/runbooks/ghcr-cleanup-runbook.md
```

Paste:

````markdown id="3pmh5m"
# GHCR Cleanup Runbook

## Goal

Delete old GHCR package versions safely without breaking rollback.

## Never Delete

- current production image
- previous production image
- stable release inside retention period
- image referenced by release metadata
- image under incident investigation

## Preferred Delete Candidates

- old PR images
- old dev images
- failed experimental builds
- unreferenced temporary tags

## Manual UI Path

GitHub profile or organization:

```text
Packages -> demo-node-api -> Package version -> Delete version
````

## API Cleanup Warning

Only use API cleanup with a tightly scoped token and a dry-run/report step.

Required concepts:

* token needs package delete capability
* cleanup workflow should be approved
* cleanup should produce audit record

## Rollback Safety

Before deletion, check:

```bash
cat promotion/state/environments.json | jq .
grep -R "TAG_TO_DELETE" release-records promotion signing provenance sbom || true
```

````

---

# 18. Docker Hub Cleanup Strategy

Docker Hub supports repository access management features such as visibility, collaborators, roles, teams, and organization access tokens. :contentReference[oaicite:6]{index=6}

Docker Hub also exposes API activity names around tags, including tag push and tag delete activity labels in its API reference. :contentReference[oaicite:7]{index=7}

For Docker Hub:

```text id="3fbayp"
use immutable tag policy where available
restrict delete permission
delete dev/pr tags conservatively
keep stable releases
avoid production latest
monitor usage/limits
use access tokens, not passwords
````

Docker personal access token docs show tokens have metadata such as scope, active/inactive status, creation date, last-used time, and expiration date. ([Docker Documentation][6])

---

# 19. Local Docker Cleanup

Local Docker cleanup is separate from registry cleanup.

Commands:

```bash id="co9uab"
docker system df
docker image ls
docker container ls -a
docker volume ls
docker buildx du || true
```

Safe local cleanup:

```bash id="vbv1ad"
docker container prune
docker image prune
docker builder prune
```

Dangerous cleanup:

```bash id="677smn"
docker system prune -a --volumes
```

Why dangerous?

```text id="1t53bt"
deletes unused images
may delete local rollback images
deletes unused volumes if --volumes used
can remove database data if volume is unused
```

Professional local cleanup rule:

```text id="tr5m0e"
Never run volume cleanup on a production server unless you know exactly what volumes are safe.
```

Docker BuildKit garbage collection evaluates GC policies in order from more specific to broader rules, preserving valuable cache while freeing space. ([Docker Documentation][7])

---

# 20. Create Local Docker Cleanup Report

Create:

```bash id="2yi5vf"
nano scripts/local-docker-cleanup-report.sh
```

Paste:

```bash id="j9rs21"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-cleanup/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/local-docker-cleanup-report-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

{
  echo "===== Local Docker Cleanup Report ====="
  echo "Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo

  echo "## Docker disk usage"
  docker system df || true
  echo

  echo "## Images"
  docker image ls || true
  echo

  echo "## Containers"
  docker container ls -a || true
  echo

  echo "## Volumes"
  docker volume ls || true
  echo

  echo "## Buildx disk usage"
  docker buildx du || true
} | tee "$REPORT_FILE"

echo
echo "Report written: $REPORT_FILE"
```

Make executable:

```bash id="dyowry"
chmod +x scripts/local-docker-cleanup-report.sh
```

Run:

```bash id="1epj0i"
./scripts/local-docker-cleanup-report.sh
```

---

# 21. Safe Local Cleanup Script

Create:

```bash id="fnw7dr"
nano scripts/safe-local-docker-cleanup.sh
```

Paste:

```bash id="3umb90"
#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-true}"
PRUNE_CONTAINERS="${PRUNE_CONTAINERS:-true}"
PRUNE_DANGLING_IMAGES="${PRUNE_DANGLING_IMAGES:-true}"
PRUNE_BUILDER_CACHE="${PRUNE_BUILDER_CACHE:-true}"
PRUNE_VOLUMES="${PRUNE_VOLUMES:-false}"

echo "===== Safe Local Docker Cleanup ====="
echo "Dry run: $DRY_RUN"
echo "Prune containers: $PRUNE_CONTAINERS"
echo "Prune dangling images: $PRUNE_DANGLING_IMAGES"
echo "Prune builder cache: $PRUNE_BUILDER_CACHE"
echo "Prune volumes: $PRUNE_VOLUMES"

echo
docker system df || true

if [ "$DRY_RUN" = "true" ]; then
  echo
  echo "DRY RUN ONLY. No cleanup executed."
  echo "Set DRY_RUN=false to execute safe cleanup."
  exit 0
fi

if [ "$PRUNE_CONTAINERS" = "true" ]; then
  docker container prune -f
fi

if [ "$PRUNE_DANGLING_IMAGES" = "true" ]; then
  docker image prune -f
fi

if [ "$PRUNE_BUILDER_CACHE" = "true" ]; then
  docker builder prune -f
fi

if [ "$PRUNE_VOLUMES" = "true" ]; then
  echo "WARNING: pruning volumes can delete data."
  docker volume prune -f
fi

echo
echo "Cleanup complete."
docker system df || true
```

Make executable:

```bash id="4ucd8t"
chmod +x scripts/safe-local-docker-cleanup.sh
```

Dry run:

```bash id="or3yx6"
./scripts/safe-local-docker-cleanup.sh
```

Execute safe cleanup without volumes:

```bash id="kh800l"
DRY_RUN=false ./scripts/safe-local-docker-cleanup.sh
```

Do not prune volumes unless you are absolutely sure:

```bash id="dvgsdb"
DRY_RUN=false PRUNE_VOLUMES=true ./scripts/safe-local-docker-cleanup.sh
```

---

# 22. Release Evidence Retention

When you delete old images, also think about release evidence.

Release evidence includes:

```text id="hgvwl1"
release metadata
SBOM
scan report
provenance
signature verification report
promotion record
deployment report
rollback report
checksums
```

Production rule:

```text id="m1o60l"
If you keep a stable image, keep its evidence.
If you delete an image, decide whether evidence remains for audit.
```

Recommended:

```text id="sxetln"
stable release evidence:
  keep with stable release

dev/pr evidence:
  expire with dev/pr artifact

incident evidence:
  keep until incident is closed and retention period passes
```

---

# 23. Cleanup Candidate Finder

Create a local script that looks at your repo evidence and identifies old/unreferenced files.

Create:

```bash id="1ae02z"
nano scripts/find-cleanup-candidates.sh
```

Paste:

```bash id="x6bkbc"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-.}"
OLDER_THAN_DAYS="${OLDER_THAN_DAYS:-30}"
OUTPUT_DIR="${OUTPUT_DIR:-cleanup/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$OUTPUT_DIR/cleanup-candidates-$TIMESTAMP.txt"

mkdir -p "$OUTPUT_DIR"

echo "===== Find Cleanup Candidates ====="
echo "Older than days: $OLDER_THAN_DAYS"
echo "Root: $ROOT_DIR"

{
  echo "Cleanup candidates generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Older than days: $OLDER_THAN_DAYS"
  echo

  echo "## Old reports"
  find reports cleanup/reports security/reports sbom/reports -type f -mtime +"$OLDER_THAN_DAYS" 2>/dev/null || true
  echo

  echo "## Old dev/pr promotion records"
  find promotion/records -type f -mtime +"$OLDER_THAN_DAYS" 2>/dev/null | grep -E 'dev|pr|staging' || true
  echo

  echo "## Old temporary examples/checksums"
  find examples checksums -type f -mtime +"$OLDER_THAN_DAYS" 2>/dev/null || true
  echo

  echo "## Protected references"
  echo "Environment state:"
  cat promotion/state/environments.json 2>/dev/null || true
} | tee "$REPORT_FILE"

echo
echo "Report written: $REPORT_FILE"
echo "No files were deleted."
```

Make executable:

```bash id="wpr6a0"
chmod +x scripts/find-cleanup-candidates.sh
```

Run:

```bash id="e970mo"
OLDER_THAN_DAYS=30 ./scripts/find-cleanup-candidates.sh
```

This script only reports. That is intentional.

---

# 24. Cleanup Record Script

Every cleanup action should create a record.

Create:

```bash id="jc99je"
nano scripts/create-cleanup-record.sh
```

Paste:

```bash id="1xzqbb"
#!/usr/bin/env bash
set -euo pipefail

ARTIFACT="${ARTIFACT:-}"
CLEANUP_ACTION="${CLEANUP_ACTION:-candidate_review}"
REASON="${REASON:-retention_policy}"
APPROVED_BY="${APPROVED_BY:-$(whoami)}"
OUTPUT_DIR="${OUTPUT_DIR:-cleanup/reports}"

if [ -z "$ARTIFACT" ]; then
  echo "ERROR: ARTIFACT is required" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

SAFE_ARTIFACT="$(echo "$ARTIFACT" | tr '/:@' '____')"
OUTPUT_FILE="$OUTPUT_DIR/$SAFE_ARTIFACT.cleanup-record.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "artifact": "$ARTIFACT",
  "cleanup_action": "$CLEANUP_ACTION",
  "reason": "$REASON",
  "approved_by": "$APPROVED_BY",
  "recorded_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "recorded"
}
EOF

cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="yxjbjf"
chmod +x scripts/create-cleanup-record.sh
```

Example:

```bash id="t7yq84"
ARTIFACT="demo-node-api:dev-old-tag" \
CLEANUP_ACTION="delete_candidate" \
REASON="dev_build_retention_expired" \
./scripts/create-cleanup-record.sh
```

---

# 25. Cleanup Runbook

Create:

```bash id="adz5xk"
nano cleanup/runbooks/artifact-cleanup-runbook.md
```

Paste:

````markdown id="6hpuw8"
# Artifact Cleanup Runbook

## Goal

Clean old artifacts without breaking rollback or audit.

## Safe Cleanup Order

1. Generate cleanup report.
2. Check current environment state.
3. Check release metadata references.
4. Check deployment reports.
5. Preview lifecycle policy if supported.
6. Delete only approved candidates.
7. Record cleanup action.
8. Validate rollback target still exists.

## Never Delete

- current production image
- previous production image
- stable releases inside retention window
- image referenced by release metadata
- image referenced by deployment report
- evidence for active incident

## Preferred Delete Candidates

- old PR images
- old dev images
- untagged images after grace period
- failed experimental builds
- old local build cache

## ECR Commands

Preview lifecycle policy:

```bash
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api ./scripts/preview-ecr-lifecycle-policy.sh
````

Apply safe policy:

```bash
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api ./scripts/apply-safe-ecr-cleanup-policy.sh
```

Safety report:

```bash
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api ./scripts/ecr-cleanup-safety-check.sh
```

## Local Docker Cleanup

Dry run:

```bash
./scripts/safe-local-docker-cleanup.sh
```

Execute safe cleanup:

```bash
DRY_RUN=false ./scripts/safe-local-docker-cleanup.sh
```

## Emergency Stop

If cleanup deleted an important artifact:

1. Stop deployments.
2. Check running containers.
3. Pull from another registry/replica if available.
4. Restore from backup if available.
5. Rebuild only if source/provenance is trusted.
6. Create incident record.

````

---

# 26. Cleanup Incident Scenarios

## Scenario 1 — Previous production image deleted

Impact:

```text id="eajxr0"
rollback fails
MTTR increases
incident pressure rises
````

Response:

```text id="2px5dy"
check whether image exists in another registry
check local server image cache
check previous deployment host
verify digest/signature
restore tag if possible
update lifecycle policy
```

---

## Scenario 2 — Lifecycle deletes staging candidate

Impact:

```text id="mqg2ev"
QA/release process interrupted
candidate must be rebuilt or repushed
```

Response:

```text id="9yzswi"
check if source commit still available
rebuild only through trusted CI
generate new SBOM/provenance/signature
record new artifact identity
```

---

## Scenario 3 — Untagged image was actually important

Impact:

```text id="i49rfw"
digest-only deployment or signature reference may break
```

Response:

```text id="799wod"
avoid digest-only untagged cleanup too aggressively
tag important digest before cleanup
record digest in release metadata
```

Professional rule:

```text id="6b5k27"
Untagged does not always mean useless. Check digest references.
```

---

# 27. Terraform ECR Lifecycle Policy

Add to your Terraform ECR example if not already present.

In:

```bash id="xytrrx"
cd ~/devops-masterclass/07-artifact-management-registries/terraform/ecr
```

Use a safer lifecycle policy:

```hcl id="bt948c"
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire PR images older than 7 days"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["pr-"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 30 dev images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Expire untagged images older than 7 days"
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
```

Then:

```bash id="5mr50w"
terraform fmt
terraform validate
terraform plan
```

---

# 28. Cleanup Automation Maturity Levels

## Level 1 — Manual cleanup

```text id="5zpnke"
manual reports
manual deletion
good for learning
```

## Level 2 — Policy-based reports

```text id="86bpdx"
scripts identify candidates
humans approve deletion
```

## Level 3 — Registry lifecycle policy

```text id="78romh"
ECR lifecycle automatically expires dev/pr/untagged images
stable releases protected by tag strategy
```

## Level 4 — Release-aware cleanup

```text id="ifna3i"
cleanup checks deployment records
cleanup checks promotion state
cleanup checks release metadata
cleanup blocks protected artifacts
```

## Level 5 — Enterprise retention governance

```text id="q3j8dv"
compliance retention
legal hold
incident hold
multi-region replication
automatic evidence archival
approval workflows
audit logging
```

Your current lesson takes you to Level 2-3, with foundations for Level 4.

---

# 29. Update Makefile

Open:

```bash id="79jc1b"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Add:

```Makefile id="aml53z"
.PHONY: cleanup-report cleanup-local cleanup-candidates cleanup-record ecr-cleanup-preview ecr-cleanup-apply ecr-cleanup-safety

cleanup-report:
	./scripts/local-docker-cleanup-report.sh

cleanup-local:
	./scripts/safe-local-docker-cleanup.sh

cleanup-candidates:
	./scripts/find-cleanup-candidates.sh

cleanup-record:
	@test -n "$(ARTIFACT)" || (echo "Usage: make cleanup-record ARTIFACT=<artifact>" && exit 1)
	ARTIFACT="$(ARTIFACT)" CLEANUP_ACTION="$${CLEANUP_ACTION:-candidate_review}" REASON="$${REASON:-retention_policy}" ./scripts/create-cleanup-record.sh

ecr-cleanup-preview:
	./scripts/preview-ecr-lifecycle-policy.sh

ecr-cleanup-apply:
	./scripts/apply-safe-ecr-cleanup-policy.sh

ecr-cleanup-safety:
	./scripts/ecr-cleanup-safety-check.sh
```

Use:

```bash id="dti80f"
make cleanup-report
make cleanup-candidates
make cleanup-local
make cleanup-record ARTIFACT="demo-node-api:dev-old-tag" CLEANUP_ACTION=delete_candidate
```

For ECR:

```bash id="97lwfm"
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api make ecr-cleanup-preview
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api make ecr-cleanup-apply
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api make ecr-cleanup-safety
```

---

# 30. Final Validation

Run:

```bash id="ee8qiy"
cd ~/devops-masterclass/07-artifact-management-registries

./scripts/local-docker-cleanup-report.sh
./scripts/safe-local-docker-cleanup.sh
./scripts/find-cleanup-candidates.sh
```

Create cleanup record:

```bash id="p87vfb"
ARTIFACT="demo-node-api:dev-old-example" \
CLEANUP_ACTION="candidate_review" \
REASON="dev_build_retention_policy" \
./scripts/create-cleanup-record.sh
```

Validate policies exist:

```bash id="ypmc37"
ls -lh cleanup/policies
cat cleanup/policies/demo-node-api-retention-policy.json | jq .
cat cleanup/policies/ecr-safe-lifecycle-policy.json | jq .
```

Optional ECR checks:

```bash id="adgsyk"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/ecr-cleanup-safety-check.sh
```

Preview lifecycle:

```bash id="s9i7u5"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/preview-ecr-lifecycle-policy.sh
```

Apply only after preview looks safe:

```bash id="sclzg0"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/apply-safe-ecr-cleanup-policy.sh
```

---

# 31. Commit Work

Run:

```bash id="uv9s5u"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: add artifact cleanup retention and rollback safety workflows"
git push
```

---

# 32. Interview Explanation

## Why is artifact cleanup dangerous?

Strong answer:

```text id="ulxstv"
Artifact cleanup is dangerous because deleting the wrong image can break rollback, remove audit evidence, or make incident investigation harder. Cleanup policies must protect current production, previous production, stable releases, and artifacts referenced by release metadata.
```

## How would you design a safe ECR lifecycle policy?

Strong answer:

```text id="n3fctr"
I would target short-lived dev and PR tags first, such as `dev-` and `pr-`, and untagged images after a grace period. I would avoid targeting stable release tags or production rollback tags. I would preview the lifecycle policy and ensure current and previous production artifacts are protected.
```

## What should never be deleted automatically?

Strong answer:

```text id="y6fg7n"
Current production images, previous production images, stable releases inside the retention window, artifacts referenced by deployment records, SBOM/provenance/signing evidence for production releases, and anything under incident review should not be deleted automatically.
```

## How do you balance storage cost and rollback safety?

Strong answer:

```text id="ueaejd"
I reduce storage by expiring temporary dev, PR, untagged, and failed experimental images, while retaining production current, production previous, stable releases, and required release evidence. Cleanup should be more aggressive for low-value temporary artifacts and conservative for production artifacts.
```

## What is the difference between deleting local Docker images and registry images?

Strong answer:

```text id="75hhbt"
Deleting local Docker images only affects the local host cache. Deleting registry images affects the central artifact source used by deployments. Registry cleanup is much riskier because it can break deployments and rollback across environments.
```

## Why keep SBOM/provenance after release?

Strong answer:

```text id="qwkeo9"
SBOM and provenance are release evidence. They help with vulnerability response, audit, and supply-chain verification. If I keep a production artifact, I should keep its evidence as well.
```

---

# Today’s Core Rules

```text id="1n5kct"
Cleanup must protect rollback first.
Do not delete current production.
Do not delete previous production within rollback window.
Do not delete stable releases blindly.
Do not delete release evidence for production artifacts.
Delete dev, PR, and untagged images first.
Use tag prefixes to make cleanup safe.
Preview lifecycle policies when possible.
Record cleanup actions.
Local Docker cleanup is not the same as registry cleanup.
Never prune production volumes casually.
Untagged does not always mean useless; check digest references.
Retention policy is part of production reliability.
```

---

# Next Lesson

# Lesson 7.13 — Artifact Management CI/CD Capstone

We will combine the whole Module 7 into one production-grade artifact workflow:

```text id="nxev0e"
version computation
Docker image build
test gate
scan gate
SBOM generation
provenance generation
image signing
registry push
release metadata
promotion records
verify-before-deploy
rollback-safe retention
cleanup policy
final runbook
GitHub Actions workflow
Jenkins mapping
portfolio README
module tag v0.7.0
```

[1]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html?utm_source=chatgpt.com "Automate the cleanup of images by using lifecycle policies ..."
[2]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/lifecycle_policy_examples.html?utm_source=chatgpt.com "Examples of lifecycle policies in Amazon ECR"
[3]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/lifecycle_policy_parameters.html?utm_source=chatgpt.com "Lifecycle policy properties in Amazon ECR"
[4]: https://docs.github.com/en/packages/learn-github-packages/deleting-and-restoring-a-package?utm_source=chatgpt.com "Deleting and restoring a package"
[5]: https://docs.github.com/rest/reference/packages?utm_source=chatgpt.com "REST API endpoints for packages"
[6]: https://docs.docker.com/security/access-tokens/?utm_source=chatgpt.com "Personal access tokens"
[7]: https://docs.docker.com/build/cache/garbage-collection/?utm_source=chatgpt.com "Build garbage collection"
