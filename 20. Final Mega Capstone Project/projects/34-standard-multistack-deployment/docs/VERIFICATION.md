# Verification record

Checked in the author's Windows workspace on 2026-09-12:

| Check | Result |
|---|---|
| `python scripts/validate.py` | All 15 Kustomize overlays rendered with kubectl 1.36.1; six promotion tests passed |
| `python scripts/test_native.py` | Python 3.14, Node.js 24, and Java 26 passed the shared HTTP checks |
| YAML parsing | All project YAML files parsed successfully |
| Local Markdown links | All project documentation targets resolved |
| Compose configuration | Local Compose configuration parsed; no daemon was needed |

The native checks cover health/readiness, query handling, API identity, version/environment values (including quoted input), JSON 404, and JSON 405. Promotion tests cover ordered progression, exact artifact/source consistency, invalid digests/revisions, directory traversal rejection, and preservation of unrelated stack configuration.

Docker Engine was not running. Container builds, Gunicorn execution, Go and .NET execution, vulnerability/SBOM jobs, GHCR publication, GitHub Actions runs, and live cluster rollout/recovery were **not executed** here. Native Java used source-file launching on the installed JDK, not the Dockerfile's Java 21 compiler. The supplied CI verifies the container images when this project is installed at a repository root and run on a Docker-capable runner.

Offline manifest rendering proves configuration composition only. Before accepting a release, complete server-side admission validation, image-pull tests, all-replica health checks, policy tests, HTTPS verification, and the capstone recovery exercise on the intended platform. Update this record with actual evidence as those steps are completed.
