# Lesson 6.8 — Container Security Masterclass

# Image Scanning, Non-Root Users, Capabilities, Seccomp, Read-Only Filesystems, Docker Socket Risks, and Supply-Chain Basics

Container security is not one thing.

It is a layered practice:

```text id="dcjwh3"
secure image
secure Dockerfile
secure runtime flags
secure Compose config
secure secrets
secure network exposure
secure registry
secure CI/CD
secure host
```

Docker’s own security docs say containers are generally more secure when processes run as non-privileged users inside containers, and Docker also supports extra layers such as AppArmor, SELinux, and other host hardening systems. ([Docker Documentation][1])

Today we will secure your Docker stack like a real DevOps/SRE engineer.

---

# 1. Beginner Level — What Are We Protecting?

A containerized app has multiple attack surfaces:

```text id="c0i8iw"
base image vulnerabilities
npm package vulnerabilities
secrets accidentally copied into image
container running as root
too many Linux capabilities
writable filesystem
public database ports
Docker socket mount
privileged containers
bad Compose config
unscanned images
mutable latest tags
```

Security goal:

```text id="xkdkq2"
reduce what the attacker can do if the app is compromised
```

This is called:

```text id="lnnbro"
defense in depth
```

One control is not enough.

---

# 2. Beginner Mental Model

Imagine your app has a bug.

Without hardening:

```text id="2tut4c"
attacker exploits app
container runs as root
filesystem writable
extra capabilities available
Docker socket mounted
secrets visible
database public
host may be at risk
```

With hardening:

```text id="cz3bzn"
attacker exploits app
container runs as non-root
root filesystem read-only
capabilities dropped
no Docker socket
secrets limited
DB private network only
resource limits applied
logs monitored
```

The bug still exists, but blast radius is smaller.

Core security rule:

```text id="f5pn1j"
Assume something will fail. Design so failure causes minimum damage.
```

---

# 3. Security Layers We Will Apply

Today’s hardening stack:

```text id="h68203"
1. Image hygiene
2. Vulnerability scanning
3. SBOM awareness
4. Non-root runtime user
5. Read-only root filesystem
6. tmpfs for writable temp paths
7. Drop Linux capabilities
8. no-new-privileges
9. Seccomp/AppArmor awareness
10. Secrets as files
11. Private Docker networks
12. Avoid Docker socket
13. Resource limits
14. CI/CD security gate
```

---

# 4. Image Scanning — Beginner Concept

A Docker image contains:

```text id="74ejsi"
OS packages
language dependencies
application code
metadata
```

Any of those can have vulnerabilities.

Image scanners compare installed packages against vulnerability databases.

Common scanners:

```text id="tkegov"
Docker Scout
Trivy
Grype
Snyk
GitLab Container Scanning
ECR image scanning
```

Docker Scout analyzes images, builds an SBOM inventory, and matches it against vulnerability data to identify weaknesses. ([Docker Documentation][2])

Trivy is a widely used open-source scanner that can scan container images, filesystems, Git repositories, VM images, Kubernetes, and more. ([GitHub][3])

Core rule:

```text id="pg3jkm"
Do not deploy images that have never been scanned.
```

---

# 5. Scan Image with Docker Scout

Build your image:

```bash id="x8gz51"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.2.0 ./scripts/docker-build.sh
```

Scan with Docker Scout:

```bash id="nvcjgo"
docker scout cves demo-node-api:0.2.0
```

Docker’s CLI reference says `docker scout cves` analyzes an image or other supported artifact for vulnerabilities. ([Docker Documentation][4])

You can also inspect recommendations:

```bash id="7yn2cf"
docker scout recommendations demo-node-api:0.2.0
```

Possible outcomes:

```text id="3lgf4g"
no critical vulnerabilities
base image update recommended
npm package update recommended
unfixed vulnerability present
```

Production interpretation:

```text id="2yt7w7"
scanner finding = risk signal
not always instant deploy blocker
must be triaged by severity, exploitability, fix availability, and exposure
```

---

# 6. Scan Image with Trivy

Option 1 — run Trivy as a container:

```bash id="2ov8y8"
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image demo-node-api:0.2.0
```

Option 2 — if Trivy is installed locally:

```bash id="90vquj"
trivy image demo-node-api:0.2.0
```

Scan only high/critical:

```bash id="klna6b"
trivy image --severity HIGH,CRITICAL demo-node-api:0.2.0
```

Fail build on high/critical:

```bash id="fgbdk3"
trivy image \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  demo-node-api:0.2.0
```

Trivy’s image command supports scanning container images and filtering by severity such as `HIGH,CRITICAL`. ([Trivy][5])

Important warning:

```text id="ha4sbq"
Mounting /var/run/docker.sock gives the scanner broad access to Docker. Use this carefully, especially on shared systems.
```

For CI, scanning a pushed registry image is often cleaner.

---

# 7. SBOM — Intermediate Concept

SBOM means:

```text id="c8gy02"
Software Bill of Materials
```

It is an inventory of components in your image:

```text id="mnk1h6"
OS packages
npm packages
libraries
versions
metadata
```

Why it matters:

```text id="8nqwum"
when a new CVE appears, you can identify affected images
security teams can audit dependencies
supply-chain risk becomes visible
```

Docker Scout’s image analysis extracts an SBOM and evaluates it against vulnerability advisories. ([Docker Documentation][6])

Generate SBOM with Docker Scout:

```bash id="gsc3gd"
docker scout sbom demo-node-api:0.2.0
```

With Trivy:

```bash id="4qa9bq"
trivy image --format cyclonedx --output sbom-demo-node-api.json demo-node-api:0.2.0
```

Production rule:

```text id="r344ld"
For regulated or enterprise environments, store SBOMs as build artifacts.
```

---

# 8. Non-Root User — Beginner to Advanced

Bad:

```Dockerfile id="968o5h"
FROM node:22-alpine
WORKDIR /app
COPY . .
CMD ["node", "server.js"]
```

May run as root.

Better:

```Dockerfile id="66xtz9"
USER node
```

Your `Dockerfile.industry` already uses:

```Dockerfile id="17az48"
USER node
```

Verify:

```bash id="q56ucd"
docker run --rm --entrypoint whoami demo-node-api:0.2.0
```

Expected:

```text id="vhvkui"
node
```

Check inside running container:

```bash id="i3khyv"
docker run --rm demo-node-api:0.2.0 id
```

If default command starts app, override entrypoint:

```bash id="alvz8y"
docker run --rm --entrypoint id demo-node-api:0.2.0
```

Production rule:

```text id="r9icy1"
Application containers should run as non-root unless there is a strong technical reason.
```

---

# 9. Runtime User Override

Even if image has `USER node`, you can enforce a user at runtime.

Docker run:

```bash id="hmwtvq"
docker run --rm \
  --user 1000:1000 \
  demo-node-api:0.2.0 id
```

Compose:

```yaml id="skcuc9"
services:
  backend:
    user: "1000:1000"
```

But be careful:

```text id="ut6wpi"
If UID/GID does not match file ownership inside image or mounted volumes, app may fail with permission denied.
```

For your app, the built-in `node` user is fine.

---

# 10. Read-Only Root Filesystem

A container should not need to modify its image filesystem at runtime.

Run:

```bash id="bjv97s"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  --read-only \
  --tmpfs /tmp \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  demo-node-api:0.2.0
```

Test:

```bash id="poykro"
curl -s http://127.0.0.1:3000/health | jq .
```

Try to write inside root filesystem:

```bash id="tzjn85"
docker exec demo-node-api sh -c 'echo test > /app/test.txt'
```

Expected:

```text id="kvuwc9"
Read-only file system
```

Clean:

```bash id="87f6uv"
docker rm -f demo-node-api
```

Datadog’s security guidance describes read-only root filesystems as treating the container root filesystem like a “golden image,” preventing runtime writes to it. ([Datadog][7])

Production rule:

```text id="287qpo"
Use read-only root filesystem for stateless app containers when possible.
```

---

# 11. tmpfs for Writable Temp Paths

Some apps need `/tmp`.

Use:

```bash id="265nr9"
--tmpfs /tmp
```

Compose:

```yaml id="mlv144"
read_only: true
tmpfs:
  - /tmp
```

For Nginx, read-only root often needs writable tmpfs:

```yaml id="mri8xl"
tmpfs:
  - /var/cache/nginx
  - /var/run
  - /tmp
```

Core rule:

```text id="k9c1fo"
Make the root filesystem read-only, then explicitly allow only required writable paths.
```

---

# 12. Linux Capabilities — Intermediate Concept

Linux capabilities split root privileges into smaller permissions.

Examples:

```text id="3gfsnr"
NET_BIND_SERVICE = bind low ports like 80
CHOWN = change file ownership
SETUID = change user identity
NET_ADMIN = modify network settings
SYS_ADMIN = very broad and dangerous
```

Default Docker containers get a limited set of capabilities.

More secure pattern:

```yaml id="xyly0i"
cap_drop:
  - ALL
```

Then add only what is required:

```yaml id="bhhk4z"
cap_add:
  - NET_BIND_SERVICE
```

For backend Node app on port 3000:

```yaml id="upbqdt"
cap_drop:
  - ALL
```

Usually works.

For Nginx listening on port 80 as non-root, you may need:

```yaml id="3yf8p7"
cap_add:
  - NET_BIND_SERVICE
```

But official Nginx image often starts as root to bind/configure and then workers run as nginx. Hardening Nginx fully is more nuanced.

Core rule:

```text id="j16pm1"
Drop all capabilities and add back only what is required.
```

---

# 13. Test Capability Dropping

Run backend:

```bash id="bm5nqq"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  --cap-drop ALL \
  --read-only \
  --tmpfs /tmp \
  -p 3000:3000 \
  -e APP_ENV=dev \
  demo-node-api:0.2.0
```

Validate:

```bash id="xq2m0n"
curl -s http://127.0.0.1:3000/health | jq .
docker logs demo-node-api --tail 20
```

Clean:

```bash id="lnp1fl"
docker rm -f demo-node-api
```

If app works, good.

Production rule:

```text id="zdw3ui"
Start with least privilege and test functionality.
```

---

# 14. `no-new-privileges`

This prevents a process from gaining additional privileges through mechanisms like setuid binaries.

Compose:

```yaml id="df8rj1"
security_opt:
  - no-new-privileges:true
```

Docker run:

```bash id="5zeu0m"
docker run --security-opt no-new-privileges:true ...
```

Use it for most app containers.

Core rule:

```text id="2kukw7"
Prevent privilege escalation inside containers when possible.
```

---

# 15. Seccomp — Advanced Concept

Seccomp filters Linux system calls.

Docker’s default seccomp profile blocks dozens of system calls while keeping broad compatibility. Docker docs describe the default seccomp profile as a “sane default” that disables about 44 system calls out of 300+. ([Docker Documentation][8])

Default is usually good:

```text id="g60sid"
do not disable seccomp casually
```

Bad:

```bash id="pmg9nt"
--security-opt seccomp=unconfined
```

Use custom seccomp only when:

```text id="2qh6vz"
you understand syscall requirements
you tested the app
you have a clear security requirement
```

Production rule:

```text id="gxq1a1"
Keep Docker's default seccomp profile unless you have a justified, reviewed exception.
```

---

# 16. AppArmor / SELinux

On Linux hosts, AppArmor or SELinux can provide extra mandatory access control.

Docker security docs mention AppArmor and SELinux as additional host hardening layers. ([Docker Documentation][1])

Check AppArmor profiles:

```bash id="lqdd6c"
sudo aa-status 2>/dev/null || true
```

Docker default profile often appears as:

```text id="5v6anv"
docker-default
```

Production rule:

```text id="ou7qbb"
Do not run containers with AppArmor/SELinux disabled unless there is a documented exception.
```

Bad:

```yaml id="58r4wb"
security_opt:
  - apparmor=unconfined
```

Use only for special cases.

---

# 17. Privileged Containers — Big Warning

Bad:

```bash id="eag799"
docker run --privileged image
```

Bad Compose:

```yaml id="q9665x"
privileged: true
```

Docker’s container security FAQ warns that privileged containers and flags like `--pid=host` or `--cap-add` run with elevated privileges and can access VM internals and Docker Engine internals in Docker Desktop contexts. ([Docker Documentation][9])

Production rule:

```text id="wf95gs"
Never use privileged containers for normal applications.
```

Only rare exceptions:

```text id="v5i92o"
low-level monitoring agents
device management
Docker-in-Docker build runners
special security-reviewed infrastructure tools
```

Even then, isolate them carefully.

---

# 18. Docker Socket Risk

Dangerous mount:

```yaml id="bg96yu"
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

Why dangerous?

```text id="rtinuv"
A container with Docker socket access can control Docker.
Docker control can often become host control.
```

Example risk:

```text id="8v29o4"
container creates privileged container
mounts host filesystem
reads host files
modifies host
```

Avoid unless absolutely necessary.

Common tools that ask for Docker socket:

```text id="cme8ek"
Traefik auto-discovery
Portainer
Watchtower
CI runners
monitoring tools
```

Use safer alternatives where possible:

```text id="rm8irm"
read-only socket proxy
least-privileged socket proxy
separate Docker host
rootless Docker
Kubernetes service account controls
manual static config
```

Production rule:

```text id="vg1p9p"
Treat Docker socket access like root access.
```

---

# 19. Rootless Docker

Rootless Docker runs the Docker daemon and containers as a non-root user.

Docker’s rootless mode docs say it runs the daemon and containers as a non-root user to mitigate vulnerabilities in the daemon and runtime, and it does not require root privileges as long as prerequisites are met. ([Docker Documentation][10])

Benefits:

```text id="g3qths"
reduces daemon root risk
good for developer machines
useful on shared systems
```

Limitations:

```text id="x27kae"
networking differences
port binding limitations
storage driver considerations
some features may not work the same
performance differences in some setups
```

Install/check later:

```bash id="a93mss"
dockerd-rootless-setuptool.sh install
docker context use rootless
docker info | grep -i rootless
```

Production note:

```text id="ngnqdq"
Rootless Docker is valuable, but it does not replace image, runtime, network, and secret hardening.
```

---

# 20. Network Security Recap

Bad:

```yaml id="1nk2y4"
mongo:
  ports:
    - "27017:27017"
```

Better:

```yaml id="brs5dg"
mongo:
  expose:
    - "27017"
  networks:
    - private_net
```

Only public entrypoint:

```yaml id="5qdwkz"
nginx:
  ports:
    - "8080:80"
```

Core rule:

```text id="0ngvrz"
Do not expose databases or internal services to the host/public internet unless strictly required.
```

---

# 21. Secrets Security Recap

Bad:

```yaml id="0w1rax"
environment:
  DATABASE_URL: mongodb://root:password@mongo:27017/demo
```

Better:

```yaml id="dd79j2"
secrets:
  backend_database_url:
    file: ./secrets/backend_database_url.txt
```

And app reads:

```text id="7cnshk"
/run/secrets/backend_database_url
```

Core rule:

```text id="70rrl3"
Secrets should be mounted only into services that need them.
```

---

# 22. Harden `compose.prod.yaml`

Open:

```bash id="3lu28b"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano compose.prod.yaml
```

Use this refined version:

```yaml id="szja61"
services:
  backend:
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    pids_limit: 100
    mem_limit: 256m
    cpus: 0.5
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /var/cache/nginx
      - /var/run
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    pids_limit: 100
    mem_limit: 128m
    cpus: 0.25
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  mongo:
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    pids_limit: 300
    mem_limit: 512m
    cpus: 1.0
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

Validate:

```bash id="ebgxrz"
docker compose -f compose.yaml -f compose.prod.yaml config
```

Deploy:

```bash id="delvjw"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Check:

```bash id="2qjp8v"
docker inspect compose-demo-backend --format '{{.HostConfig.ReadonlyRootfs}}'
docker inspect compose-demo-backend --format '{{json .HostConfig.CapDrop}}'
docker inspect compose-demo-backend --format '{{json .HostConfig.SecurityOpt}}'
docker inspect compose-demo-backend --format '{{.HostConfig.Memory}}'
docker inspect compose-demo-backend --format '{{.HostConfig.PidsLimit}}'
```

Expected:

```text id="ldn0kd"
ReadonlyRootfs true
CapDrop includes ALL
SecurityOpt includes no-new-privileges:true
Memory non-zero
PidsLimit 100
```

---

# 23. Create Security Scan Script

Go to app:

```bash id="5jm8gw"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Create:

```bash id="82ivyu"
nano scripts/docker-security-scan.sh
```

Paste:

```bash id="r5o6tv"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
VERSION="${VERSION:-0.2.0}"
IMAGE="$IMAGE_NAME:$VERSION"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"

echo "===== Docker Security Scan ====="
echo "Image: $IMAGE"
echo "Severity gate: $SEVERITY"

echo
echo "1. Image metadata:"
docker image inspect "$IMAGE" --format '{{json .Config.Labels}}' | jq . || true

echo
echo "2. Docker history:"
docker history "$IMAGE" || true

echo
echo "3. Checking runtime user:"
docker run --rm --entrypoint id "$IMAGE"

echo
echo "4. Docker Scout CVE scan:"
if docker scout version >/dev/null 2>&1; then
  docker scout cves "$IMAGE" || true
else
  echo "Docker Scout not available."
fi

echo
echo "5. Trivy scan if available locally:"
if command -v trivy >/dev/null 2>&1; then
  trivy image --severity "$SEVERITY" --exit-code 1 "$IMAGE"
else
  echo "Trivy not installed locally."
  echo "Alternative:"
  echo "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity $SEVERITY $IMAGE"
fi

echo
echo "Security scan completed."
```

Make executable:

```bash id="pbx7h1"
chmod +x scripts/docker-security-scan.sh
```

Run:

```bash id="u7ia7k"
VERSION=0.2.0 ./scripts/docker-security-scan.sh
```

---

# 24. Create Compose Security Check Script

Go to Compose demo:

```bash id="5oa3do"
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

Create:

```bash id="3ykots"
nano scripts/compose-security-check.sh
```

Paste:

```bash id="oh7dms"
#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"

compose_args=()
for file in $COMPOSE_FILES; do
  compose_args+=("-f" "$file")
done

echo "===== Compose Security Check ====="
echo "Compose files: $COMPOSE_FILES"

echo
echo "1. Rendered config:"
docker compose "${compose_args[@]}" config >/tmp/compose-security-rendered.yaml
echo "Rendered to /tmp/compose-security-rendered.yaml"

echo
echo "2. Checking for privileged containers:"
if grep -n "privileged: true" /tmp/compose-security-rendered.yaml; then
  echo "ERROR: privileged container found" >&2
  exit 1
else
  echo "OK: no privileged: true"
fi

echo
echo "3. Checking Docker socket mount:"
if grep -n "/var/run/docker.sock" /tmp/compose-security-rendered.yaml; then
  echo "ERROR: Docker socket mount found" >&2
  exit 1
else
  echo "OK: no Docker socket mount"
fi

echo
echo "4. Checking latest tag usage:"
if grep -n "image: .*:latest" /tmp/compose-security-rendered.yaml; then
  echo "ERROR: latest tag found" >&2
  exit 1
else
  echo "OK: no explicit latest tags"
fi

echo
echo "5. Checking published database ports:"
if awk '/mongo:/,/^[^ ]/' /tmp/compose-security-rendered.yaml | grep -n "published:"; then
  echo "ERROR: Mongo appears to publish a host port" >&2
  exit 1
else
  echo "OK: Mongo has no published host port"
fi

echo
echo "Security check completed."
```

Make executable:

```bash id="yvjytz"
chmod +x scripts/compose-security-check.sh
```

Run:

```bash id="j501np"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/compose-security-check.sh
```

---

# 25. CI/CD Security Gate Example

Create note:

```bash id="1bl3og"
cd ~/devops-masterclass/06-docker-containers
nano container-security-ci-gate.md
```

Paste:

````markdown id="b0jmev"
# Container Security CI Gate

## Goal

Fail CI/CD if container security checks fail.

## Suggested Gates

1. Dockerfile lint
2. Build image
3. Scan image vulnerabilities
4. Generate SBOM
5. Check image runs as non-root
6. Render Compose config
7. Check no privileged containers
8. Check no Docker socket mount
9. Check no latest tags
10. Check DB ports are not published

## Example Commands

```bash
VERSION=${GITHUB_SHA::7} ./scripts/docker-build.sh
VERSION=${GITHUB_SHA::7} ./scripts/docker-security-scan.sh
````

From Compose project:

```bash id="uu7mzj"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/compose-security-check.sh
```

## Production Rule

Security gates should fail builds for critical issues, but findings must be triaged by severity, fix availability, exploitability, and application exposure.

```
```

---

# 26. Supply Chain Security Basics

Container supply chain means:

```text id="4o9unw"
base image
OS packages
npm packages
Dockerfile
build process
CI/CD secrets
registry
image tags
deployment server
runtime config
```

Risks:

```text id="jzozxa"
malicious dependency
compromised base image
stolen registry credentials
mutable image tags
secret leaked into image
unscanned image deployed
CI runner compromised
```

Basic controls:

```text id="slfz14"
pin image versions
scan images
generate SBOM
use lockfiles
use npm ci
protect registry credentials
sign images later
use immutable tags
restrict deploy permissions
audit CI/CD logs
```

Research has found vulnerabilities and leaked secrets in public container images, which reinforces the need for scanning and secret hygiene in image builds. ([arXiv][11])

---

# 27. Corporate Example — Security Review Checklist

A corporate platform team may require:

```text id="d3b4wq"
Dockerfile uses approved base image
image runs as non-root
no secrets in Dockerfile or image
SBOM generated
Trivy/Docker Scout scan passed
critical CVEs blocked
Compose/K8s does not use privileged
Docker socket not mounted
database ports not public
resources limited
logs not leaking secrets
deployment uses immutable tags
```

For your app, your security posture now includes:

```text id="251d2m"
non-root Dockerfile
read-only backend container
cap_drop ALL
no-new-privileges
private Mongo network
Compose secrets
healthchecks
log limits
image scanning script
Compose security check script
immutable tags
```

This is strong for a learning portfolio.

---

# 28. Create Container Security Notes

Create:

```bash id="y5issb"
cd ~/devops-masterclass/06-docker-containers
nano container-security-masterclass.md
```

Paste:

````markdown id="hn1yrg"
# Container Security Masterclass

## Security Layers

- secure base image
- dependency scanning
- SBOM
- non-root user
- read-only root filesystem
- tmpfs for writable temp paths
- drop capabilities
- no-new-privileges
- default seccomp
- AppArmor/SELinux where available
- private networks
- secrets as files
- no Docker socket mount
- resource limits
- immutable image tags

## Dangerous Patterns

```yaml
privileged: true
````

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

```yaml
ports:
  - "27017:27017"
```

```Dockerfile
ENV DATABASE_URL=mongodb://user:password@db/app
```

## Image Scan

```bash
docker scout cves demo-node-api:0.2.0
trivy image --severity HIGH,CRITICAL demo-node-api:0.2.0
```

## Runtime Hardening

```bash
docker run \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  image
```

## Compose Hardening

```yaml
read_only: true
tmpfs:
  - /tmp
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
pids_limit: 100
mem_limit: 256m
```

## Core Rules

* Run as non-root.
* Avoid privileged containers.
* Avoid Docker socket mounts.
* Drop capabilities.
* Use read-only filesystems where possible.
* Use secrets, not baked credentials.
* Scan images before deployment.
* Use immutable tags.
* Keep databases private.
* Generate SBOMs for enterprise readiness.

````

---

# 29. Troubleshooting Security Hardening

## Problem 1 — App fails with read-only filesystem

Check logs:

```bash id="a7wnkl"
docker logs demo-node-api
````

Find write path:

```text id="2vohft"
EACCES
EROFS
read-only file system
```

Fix:

```text id="wjxb60"
mount a specific writable volume/tmpfs
do not disable read_only globally unless necessary
```

Example:

```yaml id="6tl9ln"
tmpfs:
  - /tmp
```

---

## Problem 2 — Permission denied after non-root

Check user:

```bash id="4bwin7"
docker exec container id
```

Check file ownership:

```bash id="3fhv9m"
docker exec container ls -la /app
```

Fix Dockerfile:

```Dockerfile id="dox5n1"
COPY --chown=node:node . .
USER node
```

---

## Problem 3 — Nginx fails with read-only filesystem

Add tmpfs:

```yaml id="pqb26n"
tmpfs:
  - /var/cache/nginx
  - /var/run
  - /tmp
```

Check:

```bash id="7aunvq"
docker compose logs nginx
```

---

## Problem 4 — Scanner reports many vulnerabilities

Do not panic. Triage:

```text id="r8q8sb"
severity
fixed version available?
is vulnerable package reachable?
is exploit public?
is container exposed?
is base image outdated?
```

Fix actions:

```text id="8csjps"
update base image
update npm package
switch base image
remove unused package
accept risk with documented exception
```

---

## Problem 5 — Capability drop breaks container

Start from:

```yaml id="kdwv3v"
cap_drop:
  - ALL
```

Then add only required:

```yaml id="d0r23c"
cap_add:
  - NET_BIND_SERVICE
```

Avoid broad capabilities like:

```text id="lvagjx"
SYS_ADMIN
NET_ADMIN
```

unless fully justified.

---

# 30. Final Validation

Build and scan:

```bash id="r04xf1"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.2.0 ./scripts/docker-build.sh
VERSION=0.2.0 ./scripts/docker-security-scan.sh
```

Deploy hardened Compose:

```bash id="hcxk7c"
cd ~/devops-masterclass/06-docker-containers/compose-demo

COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/compose-security-check.sh
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Validate app:

```bash id="kzu0y6"
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
```

Validate hardening:

```bash id="xtui7x"
docker inspect compose-demo-backend --format 'ReadOnly={{.HostConfig.ReadonlyRootfs}}'
docker inspect compose-demo-backend --format 'CapDrop={{json .HostConfig.CapDrop}}'
docker inspect compose-demo-backend --format 'SecurityOpt={{json .HostConfig.SecurityOpt}}'
docker inspect compose-demo-backend --format 'Memory={{.HostConfig.Memory}}'
docker inspect compose-demo-backend --format 'PidsLimit={{.HostConfig.PidsLimit}}'
docker compose -f compose.yaml -f compose.prod.yaml ps
```

---

# 31. Commit Work

Run:

```bash id="rhhnwq"
cd ~/devops-masterclass

git status
git add 05-application-runtime/demo-node-api/scripts/docker-security-scan.sh \
        06-docker-containers

git commit -m "feat: add container security hardening and scanning"
git push
```

---

# 32. Interview Explanation

## How do you secure a Docker container?

Strong answer:

```text id="ihfc87"
I secure containers in layers. I use trusted base images, scan images for vulnerabilities, generate SBOMs, avoid baking secrets, run as non-root, use read-only root filesystems, mount only required writable paths, drop Linux capabilities, enable no-new-privileges, keep default seccomp/AppArmor protections, avoid privileged mode and Docker socket mounts, keep databases on private networks, use secrets, set resource limits, and deploy immutable image tags through CI/CD.
```

## Why is running as non-root important?

Strong answer:

```text id="9zh13v"
Running as non-root reduces the impact of an application compromise. If an attacker gets code execution inside the container, the process has fewer permissions inside the container and against mounted files. It is a basic least-privilege control.
```

## Why is Docker socket access dangerous?

Strong answer:

```text id="1otzpe"
The Docker socket controls the Docker daemon. A container with access to it can often create new containers, mount host paths, or start privileged containers. That can lead to host compromise, so Docker socket access should be treated like root-level access.
```

## What is seccomp?

Strong answer:

```text id="b7q6cx"
Seccomp is a Linux mechanism for filtering system calls. Docker uses a default seccomp profile that blocks a set of risky syscalls while maintaining broad compatibility. I normally keep the default profile and avoid unconfined seccomp unless there is a documented exception.
```

## What is an SBOM?

Strong answer:

```text id="25dbkk"
An SBOM, or Software Bill of Materials, is an inventory of software components inside an application or image. It helps security and operations teams identify which images are affected when new vulnerabilities are discovered.
```

## How do you handle image vulnerabilities?

Strong answer:

```text id="6h76e4"
I scan images in CI/CD and triage findings by severity, exploitability, fix availability, and exposure. Critical and high vulnerabilities usually block deployment unless there is a documented exception. Fixes include updating the base image, updating dependencies, removing unused packages, or changing the base image.
```

---

# Today’s Core Rules

```text id="hxplys"
Security is layered.
Run containers as non-root.
Scan images before deployment.
Generate SBOMs for visibility.
Do not bake secrets into images.
Use Compose secrets or secret managers.
Use read-only root filesystems where possible.
Use tmpfs for needed writable temp paths.
Drop all capabilities and add back only what is needed.
Use no-new-privileges.
Keep default seccomp/AppArmor protections.
Avoid privileged containers.
Avoid Docker socket mounts.
Keep databases private.
Use immutable image tags.
Set resource and PID limits.
Treat scanner results as security signals requiring triage.
```

Next lesson:

# Lesson 6.9 — Docker Registries and Image Promotion: Docker Hub, GHCR/ECR concepts, login, tag, push, pull, immutable tags, promotion from dev to prod, and registry security.

[1]: https://docs.docker.com/engine/security/?utm_source=chatgpt.com "Docker Engine security"
[2]: https://docs.docker.com/scout/?utm_source=chatgpt.com "Docker Scout"
[3]: https://github.com/aquasecurity/trivy?utm_source=chatgpt.com "aquasecurity/trivy: Find vulnerabilities, misconfigurations ..."
[4]: https://docs.docker.com/reference/cli/docker/scout/cves/?utm_source=chatgpt.com "docker scout cves"
[5]: https://trivy.dev/docs/latest/references/configuration/cli/trivy_image/?utm_source=chatgpt.com "Image"
[6]: https://docs.docker.com/scout/explore/analysis/?utm_source=chatgpt.com "Docker Scout image analysis"
[7]: https://docs.datadoghq.com/security/default_rules/byb-wyq-f3q/?utm_source=chatgpt.com "The container's root filesystem should be set to read-only"
[8]: https://docs.docker.com/engine/security/seccomp/?utm_source=chatgpt.com "Seccomp security profiles for Docker"
[9]: https://docs.docker.com/security/faqs/containers/?utm_source=chatgpt.com "Container security FAQs"
[10]: https://docs.docker.com/engine/security/rootless/?utm_source=chatgpt.com "Rootless mode"
[11]: https://arxiv.org/abs/2006.02932?utm_source=chatgpt.com "Vulnerability Analysis of 2500 Docker Hub Images"
