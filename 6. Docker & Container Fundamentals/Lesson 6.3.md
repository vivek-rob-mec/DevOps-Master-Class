# Lesson 6.3 — Docker Image Layers, Cache, Tagging, Image Size Optimization, and Production-Ready Dockerfiles

Today we will go deeper than a beginner Dockerfile.

We will cover:

```text id="x7ojwt"
image layers
build cache
tagging strategy
image size optimization
.dockerignore
multi-stage builds
npm ci vs npm install
non-root runtime
health checks
OCI labels
BuildKit cache mounts
production-ready Node.js Dockerfile
debug vs production image thinking
```

Docker’s own best-practice docs recommend multi-stage builds to keep final images smaller and cleaner, and Docker also documents cache mounts as a way to speed repeated package-install steps during builds. ([Docker Documentation][1])

---

# 1. Mental Model: Docker Image Layers

Every important Dockerfile instruction creates an image layer.

Example:

```Dockerfile id="ip370v"
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
CMD ["node", "server.js"]
```

Think like this:

```text id="zktt2j"
Layer 1: base Node image
Layer 2: /app workdir metadata
Layer 3: package.json copied
Layer 4: npm dependencies installed
Layer 5: app source copied
Layer 6: CMD metadata
```

An image is basically:

```text id="5eoghu"
base layer + extra layers + metadata
```

Check layers:

```bash id="4mf9ms"
docker history demo-node-api:0.1.5
```

More detailed:

```bash id="zvnvzv"
docker inspect demo-node-api:0.1.5 | jq '.[0].RootFS.Layers'
```

Core rule:

```text id="xwxrsr"
Docker images are layered. Good Dockerfiles are written to make layers cacheable, small, and safe.
```

---

# 2. Build Cache: Why Order Matters

Docker reuses cached layers when inputs have not changed.

Bad Dockerfile:

```Dockerfile id="pa4xvb"
FROM node:22-alpine
WORKDIR /app
COPY . .
RUN npm install --omit=dev
CMD ["node", "server.js"]
```

Problem:

```text id="n7oysz"
If any source file changes, COPY . . changes.
Then npm install runs again.
Build becomes slow.
```

Better:

```Dockerfile id="i2q5fv"
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
CMD ["node", "server.js"]
```

Why better?

```text id="pv7rls"
If only server.js changes, npm install layer is reused.
If package.json/package-lock.json changes, npm install runs again.
```

This is called:

```text id="izzpoa"
dependency-first caching
```

Core rule:

```text id="wk1gfw"
Put rarely-changing expensive layers before frequently-changing source layers.
```

---

# 3. `npm install` vs `npm ci`

For production Docker builds, prefer:

```bash id="2wanaj"
npm ci
```

instead of:

```bash id="iyhfcp"
npm install
```

Why?

```text id="e87dig"
npm ci uses package-lock.json exactly
cleaner for CI/CD
more reproducible
fails if package-lock.json and package.json disagree
does not silently update lockfile
```

So change:

```Dockerfile id="8preht"
RUN npm install --omit=dev
```

to:

```Dockerfile id="jtssx9"
RUN npm ci --omit=dev
```

Production rule:

```text id="8h0kd3"
Use npm ci in Docker builds when package-lock.json exists.
```

---

# 4. Image Tagging Strategy

Bad tags:

```text id="rdxnfw"
latest
prod
final
test
new
```

Why bad?

```text id="ez73ug"
not traceable
can change unexpectedly
hard rollback
unclear what commit is running
```

Good tags:

```text id="5e061w"
demo-node-api:0.1.0
demo-node-api:0.1.0-abc1234
demo-node-api:abc1234
demo-node-api:20260701-abc1234
```

Recommended practical strategy:

```text id="qrulqn"
semantic version tag: 0.1.0
git SHA tag: abc1234
environment promotion tag: staging / prod only if carefully controlled
```

Example build:

```bash id="74r8lc"
VERSION=0.1.0
COMMIT_SHA=$(git rev-parse --short HEAD)

docker build \
  --build-arg APP_VERSION="$VERSION" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  -t demo-node-api:$VERSION \
  -t demo-node-api:$COMMIT_SHA \
  -t demo-node-api:$VERSION-$COMMIT_SHA \
  .
```

Check:

```bash id="b41f6i"
docker images | grep demo-node-api
```

Core rule:

```text id="85roby"
Use immutable tags for deployment. Do not depend on latest in production.
```

---

# 5. Image Size Optimization

Check image size:

```bash id="u4c27w"
docker images demo-node-api
```

Inspect history:

```bash id="n9g5dh"
docker history demo-node-api:0.1.5
```

Common causes of large images:

```text id="26wabz"
large base image
dev dependencies
node_modules copied from host
.git copied into image
build tools kept in runtime image
test files copied
logs copied
cache files copied
```

Solutions:

```text id="vbpkqy"
use .dockerignore
use npm ci --omit=dev
use multi-stage builds
copy only runtime files
remove package manager caches
run non-root
avoid installing unnecessary OS packages
```

Docker recommends multi-stage builds to separate build tooling from the final runtime image, so the final image only contains what is needed to run. ([Docker Documentation][1])

---

# 6. Improve `.dockerignore`

Go to app:

```bash id="7cu0h7"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Open:

```bash id="m6g2qq"
nano .dockerignore
```

Use this production-grade version:

```dockerignore id="4s0vtt"
# Dependencies
node_modules
npm-debug.log
yarn-error.log
pnpm-debug.log

# Environment and secrets
.env
.env.*
!.env.example
*.pem
*.key
*.crt

# Logs and reports
*.log
app.log
error.log
coverage
reports

# Git and editor files
.git
.gitignore
.vscode
.idea

# Local/runtime files
Dockerfile*
docker-compose*.yml
ecosystem.config.js
graceful-app.log
graceful-error.log
force-app.log
force-error.log
graceful-curl-output.json
force-curl-output.json

# OS junk
.DS_Store
Thumbs.db
```

Important:

```text id="xfywtm"
.dockerignore protects build context.
.gitignore protects Git commits.
You need both.
```

---

# 7. Production Dockerfile Level 1: Clean Single-Stage

Replace your Dockerfile:

```bash id="saazw1"
nano Dockerfile
```

Paste:

```Dockerfile id="ni9sr6"
# syntax=docker/dockerfile:1

FROM node:22-alpine

ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.version="$APP_VERSION"
LABEL org.opencontainers.image.revision="$COMMIT_SHA"
LABEL org.opencontainers.image.created="$BUILD_DATE"
LABEL org.opencontainers.image.source="devops-masterclass"

ENV NODE_ENV=production
ENV LOAD_DOTENV=false
ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA
ENV PORT=3000

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=node:node server.js ./
COPY --chown=node:node src ./src
COPY --chown=node:node .env.example ./

RUN chown -R node:node /app

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "server.js"]
```

Why this is better than the previous one:

```text id="9fivjm"
uses npm ci
cleans npm cache
copies only runtime files
adds OCI-style labels
sets safe runtime defaults
runs as node user
does not copy scripts/tests/docs into runtime image
```

Docker documents that labels attach metadata to Docker resources, while OCI annotations describe image components such as manifests and descriptors; for Dockerfile image metadata, labels are still commonly used. ([Docker Documentation][2])

Build:

```bash id="jue1f4"
VERSION=0.1.6
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo local)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

docker build \
  --build-arg APP_VERSION="$VERSION" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  -t demo-node-api:$VERSION \
  -t demo-node-api:$COMMIT_SHA \
  .
```

Run:

```bash id="vykcon"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e LOG_LEVEL=info \
  demo-node-api:0.1.6
```

Validate:

```bash id="i9ob1p"
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/version | jq .
docker exec demo-node-api whoami
docker logs demo-node-api --tail 20
docker inspect demo-node-api --format '{{json .Config.Labels}}' | jq .
```

Clean:

```bash id="d5uaij"
docker rm -f demo-node-api
```

---

# 8. Production Dockerfile Level 2: Multi-Stage Build

For a simple Node.js API without TypeScript/build step, multi-stage is not always mandatory, but it is a strong industry pattern because it separates dependency preparation from runtime.

Create:

```bash id="xh762q"
nano Dockerfile.production
```

Paste:

```Dockerfile id="4s770l"
# syntax=docker/dockerfile:1.7

FROM node:22-alpine AS deps

WORKDIR /app

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev && npm cache clean --force


FROM node:22-alpine AS runtime

ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.version="$APP_VERSION"
LABEL org.opencontainers.image.revision="$COMMIT_SHA"
LABEL org.opencontainers.image.created="$BUILD_DATE"
LABEL org.opencontainers.image.source="devops-masterclass"

ENV NODE_ENV=production
ENV LOAD_DOTENV=false
ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA
ENV PORT=3000

WORKDIR /app

COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package*.json ./
COPY --chown=node:node server.js ./
COPY --chown=node:node src ./src
COPY --chown=node:node .env.example ./

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "server.js"]
```

This uses BuildKit cache mount:

```Dockerfile id="36fj3t"
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev
```

Docker’s cache optimization docs describe cache mounts as persistent package caches that speed repeated build steps, especially package-manager downloads. ([Docker Documentation][3])

Build with BuildKit:

```bash id="ywelw0"
VERSION=0.1.7
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo local)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

DOCKER_BUILDKIT=1 docker build \
  -f Dockerfile.production \
  --build-arg APP_VERSION="$VERSION" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  -t demo-node-api:$VERSION \
  -t demo-node-api:$VERSION-$COMMIT_SHA \
  .
```

Run:

```bash id="y0y7wo"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e LOG_LEVEL=info \
  demo-node-api:0.1.7
```

Validate:

```bash id="c6xiij"
docker ps
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/version | jq .
docker exec demo-node-api whoami
docker inspect demo-node-api --format '{{json .State.Health}}' | jq .
```

Clean:

```bash id="1r3m8u"
docker rm -f demo-node-api
```

---

# 9. Why Multi-Stage Helps

Multi-stage build gives:

```text id="289t2t"
clean separation between build/dependency stage and runtime stage
smaller final image
fewer build tools in runtime
better security posture
better maintainability
```

For apps that compile code, multi-stage is even more valuable.

Example TypeScript pattern:

```text id="0ngkgg"
deps stage     → install dependencies
build stage    → run tests/build/transpile
runtime stage  → copy only dist + production node_modules
```

For React/Next frontend:

```text id="aaziuo"
node build stage → npm run build
nginx runtime    → serve static files
```

This is exactly what you already used earlier with frontend Dockerfiles.

---

# 10. Industry-Standard Node.js Dockerfile Pattern

For a real Node.js API with tests/build, this is a stronger pattern.

Create reference file:

```bash id="f4rcp6"
nano Dockerfile.industry
```

Paste:

```Dockerfile id="wl93a4"
# syntax=docker/dockerfile:1.7

############################
# Base
############################
FROM node:22-alpine AS base

WORKDIR /app

ENV NODE_ENV=production
ENV LOAD_DOTENV=false
ENV PORT=3000


############################
# Dependencies
############################
FROM base AS deps

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci


############################
# Test / Build
############################
FROM deps AS build

COPY . .

# Uncomment when your project has tests/build scripts:
# RUN npm test
# RUN npm run build


############################
# Production Dependencies
############################
FROM base AS prod-deps

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev && npm cache clean --force


############################
# Runtime
############################
FROM base AS runtime

ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.version="$APP_VERSION"
LABEL org.opencontainers.image.revision="$COMMIT_SHA"
LABEL org.opencontainers.image.created="$BUILD_DATE"
LABEL org.opencontainers.image.source="devops-masterclass"

ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA

COPY --from=prod-deps --chown=node:node /app/node_modules ./node_modules

COPY --chown=node:node package*.json ./
COPY --chown=node:node server.js ./
COPY --chown=node:node src ./src
COPY --chown=node:node .env.example ./

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "server.js"]
```

This pattern has separate stages:

```text id="56a1nn"
base
deps
build/test
prod-deps
runtime
```

Why this is industry-style:

```text id="zw9l3s"
keeps runtime minimal
supports test/build stage
keeps dev dependencies out of runtime
uses deterministic npm ci
uses BuildKit cache
uses labels
runs as non-root
copies only required runtime files
```

Build only runtime target:

```bash id="htx30o"
VERSION=0.1.8
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo local)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

DOCKER_BUILDKIT=1 docker build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION="$VERSION" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  -t demo-node-api:$VERSION \
  .
```

Run:

```bash id="y0do9p"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e LOG_LEVEL=info \
  demo-node-api:0.1.8
```

Validate:

```bash id="yp5g9j"
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/version | jq .
docker exec demo-node-api whoami
docker logs demo-node-api --tail 10
```

Clean:

```bash id="88w7hc"
docker rm -f demo-node-api
```

---

# 11. Production Dockerfile With TypeScript / Build Output

When your Node app has a build step, the runtime image should not copy all source.

Typical production runtime copies only:

```text id="v6q54t"
dist/
package.json
package-lock.json
node_modules production deps
```

Reference pattern:

```Dockerfile id="sg8ffj"
# syntax=docker/dockerfile:1.7

FROM node:22-alpine AS base
WORKDIR /app

FROM base AS deps
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

FROM deps AS build
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM base AS prod-deps
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev && npm cache clean --force

FROM base AS runtime
ENV NODE_ENV=production
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package*.json ./
USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

This is not for your current plain JS app, but you should know it.

---

# 12. Image Size Comparison

Build all variants:

```bash id="h46zt6"
docker build -f Dockerfile -t demo-node-api:single .
DOCKER_BUILDKIT=1 docker build -f Dockerfile.production -t demo-node-api:multi .
DOCKER_BUILDKIT=1 docker build -f Dockerfile.industry --target runtime -t demo-node-api:industry .
```

Compare:

```bash id="0x8vjf"
docker images | grep demo-node-api
```

Layer history:

```bash id="4z2lmo"
docker history demo-node-api:single
docker history demo-node-api:multi
docker history demo-node-api:industry
```

Image details:

```bash id="xb5g3e"
docker inspect demo-node-api:industry --format '{{.Size}}'
```

Human-readable size:

```bash id="ehwqdf"
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep demo-node-api
```

---

# 13. Debugging Build Cache

Build normally:

```bash id="z4lqjz"
docker build -f Dockerfile.production -t demo-node-api:cache-test .
```

Build without cache:

```bash id="1ofq7x"
docker build --no-cache -f Dockerfile.production -t demo-node-api:no-cache .
```

Plain progress output:

```bash id="5k7w4s"
DOCKER_BUILDKIT=1 docker build --progress=plain -f Dockerfile.production -t demo-node-api:plain .
```

When debugging cache, look for:

```text id="ex2v5f"
CACHED
RUN npm ci executing again
COPY invalidating cache
large build context
```

Check build context size at build start. If it is huge, `.dockerignore` is not good enough.

---

# 14. Never Put Secrets in Images

Bad Dockerfile:

```Dockerfile id="499g3d"
ENV DATABASE_URL=mongodb://user:password@db:27017/app
```

Bad:

```Dockerfile id="gdptww"
RUN echo "$AWS_SECRET_ACCESS_KEY" > /root/key.txt
```

Bad:

```bash id="93h79i"
docker build --build-arg API_KEY=real-secret .
```

Why bad?

```text id="7wca47"
image layers can preserve data
docker history/inspect may reveal metadata
images are pushed to registries
many people/systems can pull images
```

Good:

```bash id="0658j2"
docker run \
  -e DATABASE_URL="$DATABASE_URL" \
  demo-node-api:0.1.8
```

Better in orchestrators:

```text id="zaqb9z"
Docker Compose env_file or secrets
Kubernetes Secret
AWS Secrets Manager
Vault
CI/CD secrets
```

Core rule:

```text id="0bfzge"
Images contain code and safe defaults. Runtime injects secrets.
```

---

# 15. Runtime Config with Docker

Run prod-like config:

```bash id="cy7f14"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=prod \
  -e PORT=3000 \
  -e LOG_LEVEL=info \
  -e DATABASE_URL=mongodb://host.docker.internal:27017/demo \
  -e CORS_ORIGIN=https://example.com \
  demo-node-api:0.1.8
```

On Linux, `host.docker.internal` may need:

```bash id="kaciv3"
--add-host=host.docker.internal:host-gateway
```

Example:

```bash id="9h1i6i"
docker run -d \
  --name demo-node-api \
  --add-host=host.docker.internal:host-gateway \
  -p 3000:3000 \
  -e APP_ENV=prod \
  -e DATABASE_URL=mongodb://host.docker.internal:27017/demo \
  -e CORS_ORIGIN=https://example.com \
  demo-node-api:0.1.8
```

Check:

```bash id="ycxn6g"
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/config-summary | jq .
```

Clean:

```bash id="xu6nvu"
docker rm -f demo-node-api
```

---

# 16. Read-Only Container Filesystem

For stronger runtime safety, run with read-only root filesystem:

```bash id="2qdjnv"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  --read-only \
  --tmpfs /tmp \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  demo-node-api:0.1.8
```

Validate:

```bash id="iptr0q"
curl -s http://127.0.0.1:3000/health | jq .
docker logs demo-node-api --tail 20
```

If app needs to write files, you must mount specific writable directories.

Core production principle:

```text id="zcmh1i"
Make containers immutable. Mount only the paths that need writing.
```

Clean:

```bash id="g69xhv"
docker rm -f demo-node-api
```

---

# 17. Resource Limits

Run with CPU/memory limits:

```bash id="4g31vr"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  --memory=256m \
  --cpus=0.5 \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  demo-node-api:0.1.8
```

Check:

```bash id="p3xs9m"
docker stats demo-node-api
```

Stop stats:

```text id="lw65mc"
Ctrl + C
```

Inspect limits:

```bash id="rc7kxp"
docker inspect demo-node-api --format '{{.HostConfig.Memory}}'
docker inspect demo-node-api --format '{{.HostConfig.NanoCpus}}'
```

Clean:

```bash id="h8vkle"
docker rm -f demo-node-api
```

Production rule:

```text id="j8f8x9"
Containers should have resource limits in production orchestrators.
```

---

# 18. Add Build Script

Create:

```bash id="caj4io"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
nano scripts/docker-build.sh
```

Paste:

```bash id="g3j6q7"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
VERSION="${VERSION:-0.1.0}"
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DOCKERFILE="${DOCKERFILE:-Dockerfile.industry}"

echo "===== Docker Build ====="
echo "Image: $IMAGE_NAME"
echo "Version: $VERSION"
echo "Commit: $COMMIT_SHA"
echo "Dockerfile: $DOCKERFILE"
echo "Build date: $BUILD_DATE"

DOCKER_BUILDKIT=1 docker build \
  -f "$DOCKERFILE" \
  --target runtime \
  --build-arg APP_VERSION="$VERSION" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  -t "$IMAGE_NAME:$VERSION" \
  -t "$IMAGE_NAME:$COMMIT_SHA" \
  -t "$IMAGE_NAME:$VERSION-$COMMIT_SHA" \
  .

echo
echo "Built images:"
docker images "$IMAGE_NAME" --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'
```

Make executable:

```bash id="60gq52"
chmod +x scripts/docker-build.sh
```

Run:

```bash id="wblgxt"
VERSION=0.1.9 ./scripts/docker-build.sh
```

---

# 19. Add Run Script

Create:

```bash id="2m8lrh"
nano scripts/docker-run.sh
```

Paste:

```bash id="nwojlu"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
VERSION="${VERSION:-0.1.9}"
CONTAINER_NAME="${CONTAINER_NAME:-demo-node-api}"
HOST_PORT="${HOST_PORT:-3000}"
CONTAINER_PORT="${CONTAINER_PORT:-3000}"

echo "===== Docker Run ====="
echo "Image: $IMAGE_NAME:$VERSION"
echo "Container: $CONTAINER_NAME"
echo "Port: $HOST_PORT:$CONTAINER_PORT"

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker run -d \
  --name "$CONTAINER_NAME" \
  --read-only \
  --tmpfs /tmp \
  --memory=256m \
  --cpus=0.5 \
  -p "$HOST_PORT:$CONTAINER_PORT" \
  -e APP_ENV="${APP_ENV:-dev}" \
  -e PORT="$CONTAINER_PORT" \
  -e LOG_LEVEL="${LOG_LEVEL:-info}" \
  "$IMAGE_NAME:$VERSION"

echo
docker ps --filter "name=$CONTAINER_NAME"

echo
echo "Waiting for health..."
for attempt in {1..10}; do
  if curl -fsS "http://127.0.0.1:$HOST_PORT/health" >/dev/null; then
    echo "Health passed."
    curl -s "http://127.0.0.1:$HOST_PORT/version" | jq .
    exit 0
  fi

  echo "Health not ready yet: attempt $attempt/10"
  sleep 2
done

echo "ERROR: health check failed" >&2
docker logs "$CONTAINER_NAME" --tail 100
exit 1
```

Make executable:

```bash id="os96q8"
chmod +x scripts/docker-run.sh
```

Run:

```bash id="pqcmru"
VERSION=0.1.9 ./scripts/docker-run.sh
```

Clean:

```bash id="bvkicy"
docker rm -f demo-node-api
```

---

# 20. Add Hadolint Optional Check

Hadolint is a Dockerfile linter.

Install option:

```bash id="654of0"
docker run --rm -i hadolint/hadolint < Dockerfile.industry
```

Or if installed locally:

```bash id="5ogj1t"
hadolint Dockerfile.industry
```

Hadolint helps catch:

```text id="m9qz6c"
bad package install patterns
missing version pinning
shell issues
Dockerfile smells
```

For now, treat it as optional. We will use security scanning later.

---

# 21. Update Module 6 Notes

Create:

```bash id="6cwa15"
cd ~/devops-masterclass/06-docker-containers
nano image-layers-cache-tagging-optimization.md
```

Paste:

````markdown id="3q3kq9"
# Docker Image Layers, Cache, Tagging, and Optimization

## Layers

Each Dockerfile instruction creates image metadata or a filesystem layer.

Inspect:

```bash
docker history image:tag
docker inspect image:tag | jq '.[0].RootFS.Layers'
````

## Cache

Order Dockerfile instructions from least-changing to most-changing.

Good Node pattern:

```Dockerfile
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
```

## Tagging

Avoid relying on `latest` in production.

Use:

```text
app:version
app:gitsha
app:version-gitsha
```

## Image Size

Reduce image size by:

* using `.dockerignore`
* copying only runtime files
* excluding dev dependencies
* using multi-stage builds
* cleaning package manager cache
* avoiding unnecessary OS packages

## Production Dockerfile Rules

* use specific base tags
* prefer `npm ci`
* use BuildKit cache mounts
* run as non-root
* do not bake secrets
* add labels
* add healthcheck when useful
* copy only required files
* use multi-stage builds for build/test/runtime separation

````

---

# 22. Add Dockerfile Best Practice Notes

Create:

```bash id="2i4y3j"
nano production-dockerfile-best-practices.md
````

Paste:

````markdown id="snrz8k"
# Production Dockerfile Best Practices

## Industry Standard Checklist

- Use `.dockerignore`.
- Use specific base image tags.
- Prefer small base images when compatible.
- Use `npm ci`, not `npm install`, in CI/Docker builds.
- Copy dependency manifests before source code.
- Use multi-stage builds.
- Keep dev dependencies out of runtime image.
- Copy only required runtime files.
- Run as non-root.
- Do not bake secrets into images.
- Add OCI-style labels.
- Use image tags with version and commit SHA.
- Add healthcheck when appropriate.
- Keep containers immutable.
- Use runtime environment variables for config.
- Apply memory/CPU limits in runtime/orchestrator.
- Scan images before production.

## Strong Node.js Runtime Pattern

```Dockerfile
# syntax=docker/dockerfile:1.7

FROM node:22-alpine AS base
WORKDIR /app
ENV NODE_ENV=production
ENV LOAD_DOTENV=false
ENV PORT=3000

FROM base AS prod-deps
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev && npm cache clean --force

FROM base AS runtime
ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.version="$APP_VERSION"
LABEL org.opencontainers.image.revision="$COMMIT_SHA"
LABEL org.opencontainers.image.created="$BUILD_DATE"

ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA

COPY --from=prod-deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package*.json ./
COPY --chown=node:node server.js ./
COPY --chown=node:node src ./src

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "server.js"]
````

````

---

# 23. Copy Dockerfiles to Module 6 Examples

Run:

```bash id="qfpbpo"
cd ~/devops-masterclass/06-docker-containers
mkdir -p examples/production-node-dockerfiles

cp ../05-application-runtime/demo-node-api/Dockerfile examples/production-node-dockerfiles/Dockerfile.single-stage
cp ../05-application-runtime/demo-node-api/Dockerfile.production examples/production-node-dockerfiles/Dockerfile.production
cp ../05-application-runtime/demo-node-api/Dockerfile.industry examples/production-node-dockerfiles/Dockerfile.industry
cp ../05-application-runtime/demo-node-api/.dockerignore examples/production-node-dockerfiles/.dockerignore
````

Create README:

```bash id="y2p7yc"
nano examples/production-node-dockerfiles/README.md
```

Paste:

````markdown id="j1vwwq"
# Production Node.js Dockerfile Examples

## Files

```text
Dockerfile.single-stage
Dockerfile.production
Dockerfile.industry
.dockerignore
````

## Build Industry Dockerfile

From app directory:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.1.9 ./scripts/docker-build.sh
```

## Run

```bash
VERSION=0.1.9 ./scripts/docker-run.sh
```

## Validate

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/version | jq .
docker exec demo-node-api whoami
docker inspect demo-node-api --format '{{json .State.Health}}' | jq .
```

````

---

# 24. Final Validation

Run:

```bash id="felbtm"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
````

Build:

```bash id="odlwev"
VERSION=0.1.9 ./scripts/docker-build.sh
```

Run:

```bash id="bovcd0"
VERSION=0.1.9 ./scripts/docker-run.sh
```

Validate manually:

```bash id="72nmhc"
docker ps
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/version | jq .
curl -s http://127.0.0.1:3000/config-summary | jq .
docker exec demo-node-api whoami
docker logs demo-node-api --tail 20
docker inspect demo-node-api --format '{{json .State.Health}}' | jq .
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep demo-node-api
```

Cleanup:

```bash id="4zfxd3"
docker rm -f demo-node-api
```

---

# 25. Commit Work

From repo root:

```bash id="f9dqja"
cd ~/devops-masterclass

git status
git add 05-application-runtime/demo-node-api/.dockerignore \
        05-application-runtime/demo-node-api/Dockerfile \
        05-application-runtime/demo-node-api/Dockerfile.production \
        05-application-runtime/demo-node-api/Dockerfile.industry \
        05-application-runtime/demo-node-api/scripts/docker-build.sh \
        05-application-runtime/demo-node-api/scripts/docker-run.sh \
        06-docker-containers

git commit -m "feat: add production Dockerfile patterns and image optimization"
git push
```

---

# 26. Interview Explanation

Question:

```text id="c25tfz"
How do Docker image layers and cache work?
```

Strong answer:

```text id="elr660"
Docker builds images as a sequence of layers. Instructions like COPY and RUN create layers. Docker reuses cached layers when the instruction and its inputs have not changed. That is why Dockerfiles should copy dependency files first, install dependencies, and then copy application source. This keeps expensive dependency layers cached when only source code changes.
```

Question:

```text id="5ny228"
How do you write a production-ready Dockerfile for Node.js?
```

Strong answer:

```text id="dbkos3"
I use a specific Node base image, a .dockerignore file, npm ci for reproducible installs, dependency-first caching, multi-stage builds, production-only dependencies in the runtime image, non-root user, OCI labels for metadata, safe ENV defaults, no baked secrets, EXPOSE for documentation, and a HEALTHCHECK when appropriate. I tag images with version and commit SHA for traceability.
```

Question:

```text id="oxn518"
Why avoid the latest tag in production?
```

Strong answer:

```text id="yn02ho"
The latest tag is mutable and does not clearly identify what code is running. In production, I prefer immutable tags such as semantic version, git SHA, or version-SHA combination so deployments and rollbacks are traceable.
```

Question:

```text id="e9w4ol"
Why use multi-stage Docker builds?
```

Strong answer:

```text id="w9cvvf"
Multi-stage builds separate dependency, build, test, and runtime stages. This keeps build tools, dev dependencies, and temporary files out of the final runtime image, reducing image size and improving security and maintainability.
```

Question:

```text id="kdpxse"
What should not be inside a Docker image?
```

Strong answer:

```text id="z0h87m"
A Docker image should not contain real secrets, .env files, private keys, Git history, local logs, test reports, unnecessary build tools, or dev dependencies in the runtime image. Secrets should be injected at runtime through environment variables, secret stores, or orchestrator secrets.
```

---

# Today’s Core Rules

```text id="h7u2vd"
Order Dockerfile layers for cache.
Use .dockerignore.
Use npm ci for reproducible builds.
Use multi-stage builds for production.
Keep runtime image minimal.
Do not bake secrets into images.
Use OCI-style labels.
Tag images with version and git SHA.
Avoid latest for production deployments.
Run containers as non-root.
Use BuildKit cache mounts for faster builds.
Use HEALTHCHECK when useful.
Copy only runtime files.
Images should be immutable.
Runtime config comes from environment/secrets.
```

Next lesson:

# Lesson 6.4 — Docker Networking: bridge networks, container DNS, service-to-service communication, and why localhost behaves differently inside containers.

[1]: https://docs.docker.com/build/building/best-practices/?utm_source=chatgpt.com "Building best practices"
[2]: https://docs.docker.com/build/metadata/annotations/?utm_source=chatgpt.com "Annotations"
[3]: https://docs.docker.com/build/cache/optimize/?utm_source=chatgpt.com "Optimize cache usage in builds"
