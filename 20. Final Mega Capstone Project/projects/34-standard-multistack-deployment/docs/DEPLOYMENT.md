# Deployment procedure

## 1. Choose the platform and ownership

| Situation | Suitable starting point | Shared delivery practice |
|---|---|---|
| Small service with limited operations capacity | Managed container service | Test, scan, publish, deploy by immutable artifact, verify |
| Small internal workload on existing VMs | Containers on a VM with managed ingress and supervised deployment | Same artifact pipeline; replace Argo CD with the VM rollout mechanism |
| Many services on an established platform | Kubernetes with GitOps, as implemented here | Shared policies and environment promotion |
| Event-driven functions | Serverless project 11 | Versioned packages, event contracts, infrastructure review, controlled rollout |

Record the service owner, deployment target, data classification, dependencies, SLO, capacity expectation, and recovery objective before selecting infrastructure. Use the organization's existing supported platform where appropriate.

## 2. Create the application repository

Copy **the contents of project 34, including `.github`**, into a new repository root. The supplied workflow paths and Argo CD examples assume this layout. Nested `.github/workflows` files do not run inside the course repository. If retaining a monorepo, move workflows to the repository's top-level `.github/workflows`, adjust filters/working directories/artifact paths, and use the full project path in Argo CD.

Use short-lived branches and reviewed PRs into `main`. Enable required checks and prohibit direct pushes. Require the configuration validation check for every PR. Require image checks on application changes; path-filtered workflows may stay pending if made mandatory for unrelated configuration PRs, so configure rules accordingly. Assign platform reviewers to `k8s`, `argocd`, and workflow changes, and a production owner to `k8s/overlays/prod`. Enforce ownership using your actual GitHub teams and CODEOWNERS plus repository rules.

## 3. Build and publish

The image workflow runs a five-stack matrix. Each stack is built once, started with runtime restrictions, checked over HTTP, and stopped. CI checks for OOM and forced-kill exit status. Trivy creates an SBOM and scans the exported image; HIGH/CRITICAL findings, including unfixed findings, fail the build. Review and fix failures before release.

After all matrix builds pass on a main-branch push, a separate job downloads the tested image archive and pushes it to `ghcr.io/<lowercase-owner>/standard-<stack>:<source-sha>`. It does not rebuild. Only publishing has `packages: write`. Pull requests and manual validation runs do not publish. This carries the principle of [testing container images before publication](https://docs.docker.com/build/ci/github-actions/test-before-push/) through the archive handoff.

Download `release-python` (or the other stack's artifact) from the successful main workflow run. Its `release-python.json` contains:

```json
{
  "stack": "python",
  "image": "ghcr.io/your-team/standard-python",
  "digest": "sha256:<64 hexadecimal characters from the registry>",
  "revision": "<40-character source Git SHA>"
}
```

This is an explanatory example, not a usable release. Keep the actual record alongside its workflow URL, contract output, scan, and SBOM. Archive release evidence in durable organizational storage before GitHub artifact retention expires. A release JSON file is metadata, not cryptographic provenance.

## 4. Prepare the Kubernetes platform once

Use a supported Kubernetes 1.34+ cluster for this example's native pre-stop sleep handler. The cluster needs a CNI that enforces NetworkPolicy, enough resources for surge replicas, and access to the image registry. Select a supported `kubectl` version compatible with the actual cluster; CI uses 1.36.1 only for offline rendering.

Platform administrators apply the reviewed namespace definitions:

```bash
kubectl apply -f k8s/namespaces/dev.yaml
kubectl apply -f k8s/namespaces/staging.yaml
kubectl apply -f k8s/namespaces/prod.yaml
```

Namespaces enforce the restricted Pod Security profile. They are intentionally outside the application's Argo CD permissions. The default is one cluster with three namespaces for learning. For production isolation, use separate accounts/projects and clusters where required, then update Argo CD destinations.

GHCR packages may be private. Configure namespace-specific registry credentials through your platform's secret manager, and reference the resulting image-pull Secret in the base ServiceAccount before sync. Kubernetes nodes do not inherit CI's GitHub token. If using public images for a lab, make package visibility an explicit choice. Do not put registry tokens into tracked YAML.

The NetworkPolicy permits inbound traffic from the same namespace and pods in `gateway-system`, and denies egress. This is appropriate only for these stateless services. Adapt gateway namespace/pod selectors to the chosen controller. When adding dependencies, explicitly allow DNS and the dependency endpoints using your CNI's supported policy model. Test both allowed and denied traffic.

Service exposure is ClusterIP by default. The optional HTTPRoute requires Gateway API CRDs and a platform-owned HTTPS Gateway, valid certificate, DNS, matching listener name, and `allowedRoutes` for the service namespace. Inspect HTTPRoute `Accepted` and `ResolvedRefs` conditions. The example is applied separately; add Gateway API permissions to the AppProject only if application GitOps will own it.

## 5. Register GitOps

Install and operate Argo CD through the platform. Configure its repository credentials out of band. Replace repository URLs in both `argocd/*.example.yaml` files, apply the AppProject, then create the dev Application **after promoting a real digest**.

```bash
kubectl apply -f argocd/project.example.yaml
kubectl apply -f argocd/application.example.yaml
```

For each additional stack/environment, copy the Application and change its name, `source.path`, and destination namespace. For staging/production, omit the `automated` block initially and have the release owner sync the reviewed revision. Once reviewed Git changes are the approved deployment boundary, automatic sync can be enabled under your organization's controls. Argo CD [automated synchronization](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/) reconciles Git state; it does not by itself create a human approval gate. Pruning is disabled in this example to keep deletion a deliberate operation.

## 6. Promote one release

On an up-to-date branch from main, run:

```bash
python scripts/promote.py --stack python --to dev --release release-python.json
python scripts/validate.py
git diff -- k8s/overlays/dev/python/kustomization.yaml
```

Commit the configuration diff, open a PR, and merge after review. The script does not push or deploy. After Argo CD syncs, verify dev using the next section. Then start another branch from the newly updated main:

```bash
python scripts/promote.py --stack python --to staging --release release-python.json
```

Run validation, review and merge, sync staging, and attach functional/load/security evidence. Repeat with `--to prod` only after production review. The script requires matching digest and revision in the previous environment. It checks **Git configuration order**, not deployed health, approval, signatures, or scan authenticity; those are verified by CI, reviewers, and platform controls. Never manufacture a passing release record.

## 7. Verify the deployment

```bash
kubectl -n standard-dev rollout status deployment/python-deployment-demo --timeout=300s
kubectl -n standard-dev get pods -l app.kubernetes.io/instance=python
kubectl -n standard-dev get deployment python-deployment-demo -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl -n standard-dev port-forward service/python-deployment-demo 8180:80
```

Keep port-forward running and use a second terminal:

```bash
python scripts/smoke.py http://127.0.0.1:8180 --stack python --version SOURCE_GIT_SHA --environment dev
```

Replace `SOURCE_GIT_SHA` with the release record's full revision. Compare the Deployment image to the registry digest, check container `imageID`, and verify the Argo CD revision. Repeat the smoke check through the actual HTTPS hostname to test DNS, certificate, gateway, and policy. Port-forward alone bypasses that route. In staging/prod, inspect all replicas; a single successful request does not prove every pod is running the intended version.

## Production adoption

- Pin approved base and scanner images by digest and refresh them through reviewed update PRs. The sample uses readable version tags, which are mutable. [Docker recommends digest pinning](https://docs.docker.com/build/building/best-practices/) for reproducible base selection. Keep dependency lockfiles and hashes for real application dependencies.
- The workflow pins third-party actions to commit SHAs. Maintain those pins and enable dependency updates; [GitHub's secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use) explains why immutable action references matter.
- Add signed provenance, signature verification, and admission enforcement using project 22. Neither an SBOM nor a vulnerability scan proves artifact identity or authorization.
- Configure auth, secrets rotation, audit logging, request limits, bounded dependency timeouts, and workload identity. For cloud CI access, prefer [OIDC federation](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-cloud-providers) with repository/branch restrictions over long-lived cloud keys. This GHCR-only workflow does not require cloud credentials.
- Add application metrics/traces, an externally measured SLO, alerts with owners, capacity tests, topology spread across failure domains, and a recovery drill. Replica counts and a PDB alone do not establish high availability.
- Introduce databases through separately owned infrastructure and safe migration jobs. Backups need restore evidence. The stateless sample intentionally has no database manifests.
