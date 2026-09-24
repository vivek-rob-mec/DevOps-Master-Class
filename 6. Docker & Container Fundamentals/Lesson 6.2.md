# Lesson 6.2 — Dockerfile Basics

# Building Your First Custom Image

In Lesson 6.1, you learned:

```text id="azaz7l"
Dockerfile → docker build → image → docker run → container
```

Now we create our first custom image.

We will containerize the Node.js runtime app from Module 5.

---

# 1. What Is a Dockerfile?

A Dockerfile is a recipe for building a Docker image.

It tells Docker:

```text id="fb9h0g"
which base image to use
which files to copy
which dependencies to install
which port the app uses
which command starts the app
```

Example:

```Dockerfile id="hhby9q"
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

This becomes an image:

```bash id="smw4l8"
docker build -t demo-node-api:0.1.0 .
```

Then you run a container:

```bash id="8l8b9m"
docker run -p 3000:3000 demo-node-api:0.1.0
```

---

# 2. Dockerfile Mental Model

```text id="4n0eva"
Dockerfile instruction
  ↓
image layer
  ↓
cached if unchanged
```

Common Dockerfile instructions:

```text id="bfo8ts"
FROM        base image
WORKDIR     working directory
COPY        copy files into image
RUN         execute command during build
ENV         set default environment variable
EXPOSE      document container port
CMD         default command when container starts
ENTRYPOINT  fixed executable command
USER        run as non-root user
```

Important difference:

```text id="4dooa0"
RUN happens during image build.
CMD happens when container starts.
```

Example:

```Dockerfile id="6l0bn1"
RUN npm install
```

This installs dependencies while building the image.

Example:

```Dockerfile id="7nw5pp"
CMD ["node", "server.js"]
```

This starts the app when the container runs.

---

# 3. Create Docker Work Area

Go to your runtime app:

```bash id="6q4jt1"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Check files:

```bash id="j7jzu1"
ls
```

You should have:

```text id="3id8ke"
server.js
package.json
package-lock.json
src/
scripts/
.env.example
```

---

# 4. Create `.dockerignore`

Before writing a Dockerfile, create `.dockerignore`.

This tells Docker what not to send into the build context.

Create:

```bash id="di3m54"
nano .dockerignore
```

Paste:

```dockerignore id="vj7fts"
node_modules
npm-debug.log
.env
.env.*
!.env.example
app.log
error.log
*.log
.git
.gitignore
Dockerfile
docker-compose.yml
coverage
reports
```

Why?

```text id="3xz7hw"
faster builds
smaller build context
avoid copying secrets
avoid copying local node_modules
avoid copying Git history
```

Core rule:

```text id="d9f6kv"
Always create .dockerignore before building images.
```

---

# 5. Create Basic Dockerfile

Create:

```bash id="s4vh59"
nano Dockerfile
```

Paste:

```Dockerfile id="gac5xn"
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
```

This is the simplest working Dockerfile.

---

# 6. Understand Each Line

## `FROM`

```Dockerfile id="0dgjzy"
FROM node:22-alpine
```

This starts from an official Node.js image.

```text id="awv2wl"
node = Node.js runtime
22 = major version
alpine = small Linux base
```

## `WORKDIR`

```Dockerfile id="8m0a8t"
WORKDIR /app
```

Sets working directory inside image.

Equivalent to:

```bash id="1nqh05"
cd /app
```

inside the container.

## `COPY package*.json ./`

```Dockerfile id="gy9a05"
COPY package*.json ./
```

Copies dependency files first.

This improves caching.

## `RUN npm install --omit=dev`

```Dockerfile id="61h8c4"
RUN npm install --omit=dev
```

Installs production dependencies during build.

## `COPY . .`

```Dockerfile id="2z7w4a"
COPY . .
```

Copies the rest of your application code.

## `EXPOSE`

```Dockerfile id="vb0xvd"
EXPOSE 3000
```

Documents that the container listens on port 3000.

Important:

```text id="14i5wk"
EXPOSE does not publish the port to the host.
docker run -p publishes the port.
```

## `CMD`

```Dockerfile id="r9tx01"
CMD ["node", "server.js"]
```

Default command when container starts.

---

# 7. Build the Image

Run:

```bash id="z7ouiy"
docker build -t demo-node-api:0.1.0 .
```

Check image:

```bash id="49nlew"
docker images | grep demo-node-api
```

Inspect image:

```bash id="k9c2d6"
docker inspect demo-node-api:0.1.0
```

Useful format:

```bash id="b1oh71"
docker inspect demo-node-api:0.1.0 --format '{{.Config.Cmd}}'
docker inspect demo-node-api:0.1.0 --format '{{.Config.WorkingDir}}'
docker inspect demo-node-api:0.1.0 --format '{{.Config.ExposedPorts}}'
```

---

# 8. Run Container from Your Image

Run:

```bash id="xebfdw"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  -e LOG_LEVEL=info \
  -e LOAD_DOTENV=false \
  demo-node-api:0.1.0
```

Check:

```bash id="pcfu1c"
docker ps
```

Test app:

```bash id="mknzke"
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/version | jq .
curl -s http://127.0.0.1:3000/config-summary | jq .
```

Check logs:

```bash id="gu9j6q"
docker logs demo-node-api
```

Stop and remove:

```bash id="shc3zt"
docker rm -f demo-node-api
```

---

# 9. Build Context

When you run:

```bash id="0x1i5j"
docker build -t demo-node-api:0.1.0 .
```

The final dot means:

```text id="jm3ieo"
send current directory as build context
```

Docker can only copy files from the build context.

So this works:

```Dockerfile id="nwuy7b"
COPY server.js .
```

because `server.js` is inside current directory.

This does not work:

```Dockerfile id="dnp3m4"
COPY ../../secret.txt .
```

because it is outside the build context.

Core rule:

```text id="nzzgir"
Dockerfile can only COPY files from the build context.
```

---

# 10. Docker Build Cache

Docker caches layers.

Your Dockerfile:

```Dockerfile id="c412qi"
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
```

This is better than:

```Dockerfile id="u1wrrm"
COPY . .
RUN npm install --omit=dev
```

Why?

With the better version:

```text id="wfl540"
If only server.js changes, npm install layer is reused.
If package.json changes, npm install runs again.
```

This speeds up builds.

Core rule:

```text id="x9jdj1"
Copy dependency files before app source to improve cache.
```

---

# 11. Change App Version and Rebuild

Run:

```bash id="86zh2d"
docker build -t demo-node-api:0.1.1 .
```

Run:

```bash id="8y1tff"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e APP_VERSION=0.1.1 \
  -e COMMIT_SHA=docker-lesson-62 \
  -e PORT=3000 \
  -e LOG_LEVEL=info \
  -e LOAD_DOTENV=false \
  demo-node-api:0.1.1
```

Check:

```bash id="j4wckp"
curl -s http://127.0.0.1:3000/version | jq .
```

Expected:

```json id="a8969s"
{
  "app": "demo-node-api",
  "version": "0.1.1",
  "commit_sha": "docker-lesson-62"
}
```

Clean:

```bash id="hec54x"
docker rm -f demo-node-api
```

---

# 12. Add Image Labels

Labels store metadata inside the image.

Update Dockerfile:

```bash id="3uud3q"
nano Dockerfile
```

Add after `FROM`:

```Dockerfile id="eoh01r"
LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.source="devops-masterclass"
```

Full basic Dockerfile:

```Dockerfile id="gq90il"
FROM node:22-alpine

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.source="devops-masterclass"

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
```

Build:

```bash id="g2vw13"
docker build -t demo-node-api:0.1.2 .
```

Inspect labels:

```bash id="t7gexj"
docker inspect demo-node-api:0.1.2 --format '{{json .Config.Labels}}' | jq .
```

---

# 13. Add Build Arguments

Build args allow passing values during build.

Update Dockerfile near labels:

```Dockerfile id="f2muob"
ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown

ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA
```

Full improved Dockerfile:

```Dockerfile id="k2u8vk"
FROM node:22-alpine

ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.source="devops-masterclass"

ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA
ENV NODE_ENV=production
ENV LOAD_DOTENV=false

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
```

Build with args:

```bash id="l1qm5n"
docker build \
  --build-arg APP_VERSION=0.1.3 \
  --build-arg COMMIT_SHA=build-arg-demo \
  -t demo-node-api:0.1.3 .
```

Run:

```bash id="lowk1m"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  demo-node-api:0.1.3
```

Check:

```bash id="p9l6gu"
curl -s http://127.0.0.1:3000/version | jq .
```

Expected:

```json id="037ct3"
{
  "app": "demo-node-api",
  "version": "0.1.3",
  "commit_sha": "build-arg-demo"
}
```

Clean:

```bash id="buxbfp"
docker rm -f demo-node-api
```

---

# 14. ARG vs ENV

## ARG

Available during build.

```Dockerfile id="dp34x5"
ARG APP_VERSION=0.1.0
```

Use with:

```bash id="s46iko"
docker build --build-arg APP_VERSION=1.0.0 .
```

## ENV

Available inside running container.

```Dockerfile id="27lr7o"
ENV APP_VERSION=$APP_VERSION
```

Use with:

```bash id="xlmu33"
docker run -e APP_ENV=prod image
```

Key difference:

```text id="j9xdkp"
ARG = build-time variable
ENV = runtime/default container variable
```

Core rule:

```text id="04bhvr"
Do not pass secrets using ARG.
```

Why?

```text id="8t0bao"
Build args may appear in image history or build metadata.
```

Secrets should be runtime env vars or secret managers.

---

# 15. Docker History

Inspect image layers:

```bash id="j4c3p3"
docker history demo-node-api:0.1.3
```

This shows:

```text id="jz5b2v"
base image layers
WORKDIR layer
COPY layer
RUN npm install layer
COPY app layer
CMD metadata
```

This is why secrets in Dockerfile are dangerous.

Bad:

```Dockerfile id="lwionr"
ENV API_KEY=real-secret-value
```

Bad:

```Dockerfile id="reeeb3"
RUN echo "password=secret" > /app/config
```

These can leak into image layers.

---

# 16. Run as Non-Root User

By default, many containers run as root.

Check:

```bash id="pic91o"
docker run --rm demo-node-api:0.1.3 whoami
```

Actually this may still run app `CMD`, so use override:

```bash id="06d0uk"
docker run --rm --entrypoint whoami demo-node-api:0.1.3
```

Better Dockerfile uses non-root user.

Node Alpine image has a `node` user.

Update Dockerfile:

```Dockerfile id="ib00r8"
FROM node:22-alpine

ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.source="devops-masterclass"

ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA
ENV NODE_ENV=production
ENV LOAD_DOTENV=false

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY --chown=node:node . .

USER node

EXPOSE 3000

CMD ["node", "server.js"]
```

But there is one issue: `npm install` created `node_modules` as root.

That is okay for read-only runtime in many cases, but `/app` files after COPY are owned by node. To be cleaner:

```Dockerfile id="07i18m"
RUN chown -R node:node /app
```

Final version:

```Dockerfile id="guw15h"
FROM node:22-alpine

ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.source="devops-masterclass"

ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA
ENV NODE_ENV=production
ENV LOAD_DOTENV=false

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY --chown=node:node . .

RUN chown -R node:node /app

USER node

EXPOSE 3000

CMD ["node", "server.js"]
```

Build:

```bash id="q8kz9i"
docker build \
  --build-arg APP_VERSION=0.1.4 \
  --build-arg COMMIT_SHA=non-root-demo \
  -t demo-node-api:0.1.4 .
```

Check user:

```bash id="g8djca"
docker run --rm --entrypoint whoami demo-node-api:0.1.4
```

Expected:

```text id="diy2it"
node
```

Run app:

```bash id="o8zd2w"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  demo-node-api:0.1.4
```

Test:

```bash id="icb0ww"
curl -s http://127.0.0.1:3000/health | jq .
docker logs demo-node-api
```

Clean:

```bash id="kl1rtp"
docker rm -f demo-node-api
```

Core rule:

```text id="vxt18s"
Run containers as non-root whenever possible.
```

---

# 17. Add Healthcheck to Dockerfile

Docker has a `HEALTHCHECK` instruction.

Add before `CMD`:

```Dockerfile id="3wyl3x"
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1
```

Alpine usually has `wget` via BusyBox.

Final Dockerfile:

```Dockerfile id="vtj95w"
FROM node:22-alpine

ARG APP_VERSION=0.1.0
ARG COMMIT_SHA=unknown

LABEL org.opencontainers.image.title="demo-node-api"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.source="devops-masterclass"

ENV APP_VERSION=$APP_VERSION
ENV COMMIT_SHA=$COMMIT_SHA
ENV NODE_ENV=production
ENV LOAD_DOTENV=false

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY --chown=node:node . .

RUN chown -R node:node /app

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "server.js"]
```

Build:

```bash id="saxmtx"
docker build \
  --build-arg APP_VERSION=0.1.5 \
  --build-arg COMMIT_SHA=healthcheck-demo \
  -t demo-node-api:0.1.5 .
```

Run:

```bash id="uojfew"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  demo-node-api:0.1.5
```

Check health:

```bash id="wc93hx"
docker ps
```

Initially:

```text id="zcly8i"
health: starting
```

After some time:

```text id="dbm5wj"
healthy
```

Inspect health details:

```bash id="snn24l"
docker inspect demo-node-api --format '{{json .State.Health}}' | jq .
```

Clean:

```bash id="p4smeq"
docker rm -f demo-node-api
```

---

# 18. Dockerfile Best Practices So Far

```text id="x6cfhx"
Use official base images.
Use specific tags, not latest.
Create .dockerignore.
Copy package files before app source.
Use npm install/ci before copying all source.
Do not bake secrets into image.
Use ENV for safe defaults only.
Use ARG for build metadata.
Run as non-root.
Expose app port.
Add healthcheck when useful.
Keep image small.
```

---

# 19. Add Dockerfile Notes

Create Module 6 notes:

```bash id="qbply5"
cd ~/devops-masterclass/06-docker-containers
nano dockerfile-basics.md
```

Paste:

````markdown id="akqdwy"
# Dockerfile Basics

## Docker Build Flow

```text
Dockerfile -> docker build -> image -> docker run -> container
````

## Common Instructions

| Instruction | Purpose                   |
| ----------- | ------------------------- |
| FROM        | base image                |
| WORKDIR     | working directory         |
| COPY        | copy files into image     |
| RUN         | run command at build time |
| ARG         | build-time variable       |
| ENV         | runtime/default variable  |
| EXPOSE      | document container port   |
| USER        | runtime user              |
| HEALTHCHECK | container health command  |
| CMD         | default container command |

## RUN vs CMD

* `RUN` happens during image build.
* `CMD` happens when the container starts.

## ARG vs ENV

* `ARG` is build-time.
* `ENV` is available at runtime.

Do not use ARG or ENV for real secrets inside images.

## Cache Pattern for Node.js

```Dockerfile
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
```

This allows Docker to reuse the dependency layer when only source files change.

## Port Rule

`EXPOSE 3000` documents the port.

`docker run -p 3000:3000 image` publishes the port.

## Security Rules

* use `.dockerignore`
* do not copy `.env`
* do not bake secrets into images
* run as non-root
* inspect image history

```id="g02zab"
```

---

# 20. Add Dockerfile to Module 6 Examples

Copy Dockerfile example:

```bash id="3xl0mb"
cd ~/devops-masterclass/06-docker-containers
mkdir -p examples/node-dockerfile
cp ../05-application-runtime/demo-node-api/Dockerfile examples/node-dockerfile/Dockerfile
cp ../05-application-runtime/demo-node-api/.dockerignore examples/node-dockerfile/.dockerignore
```

Create README:

```bash id="zpwddb"
nano examples/node-dockerfile/README.md
```

Paste:

````markdown id="xwoold"
# Node.js Dockerfile Example

Build from the demo app directory:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

docker build \
  --build-arg APP_VERSION=0.1.5 \
  --build-arg COMMIT_SHA=local \
  -t demo-node-api:0.1.5 .
````

Run:

```bash id="sbtin5"
docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  demo-node-api:0.1.5
```

Check:

```bash id="4owl46"
curl -s http://127.0.0.1:3000/health | jq .
docker logs demo-node-api
docker inspect demo-node-api --format '{{json .State.Health}}' | jq .
```

````id="rmf6sn"

---

# 21. Validate Everything

From app directory:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
````

Build final image:

```bash id="scr70d"
docker build \
  --build-arg APP_VERSION=0.1.5 \
  --build-arg COMMIT_SHA=lesson62-final \
  -t demo-node-api:0.1.5 .
```

Run:

```bash id="8oaosl"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  -e LOG_LEVEL=info \
  demo-node-api:0.1.5
```

Validate:

```bash id="q88lxz"
docker ps
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/version | jq .
docker logs demo-node-api --tail 20
docker inspect demo-node-api --format '{{json .State.Health}}' | jq .
```

Check non-root:

```bash id="75nbpm"
docker exec demo-node-api whoami
```

Expected:

```text id="aao2q7"
node
```

Cleanup:

```bash id="j7wfpk"
docker rm -f demo-node-api
```

---

# 22. Commit Work

From repo root:

```bash id="a600fe"
cd ~/devops-masterclass

git status
git add 05-application-runtime/demo-node-api/Dockerfile \
        05-application-runtime/demo-node-api/.dockerignore \
        06-docker-containers
git commit -m "feat: add Dockerfile basics for Node runtime app"
git push
```

---

# 23. Interview Explanation

Question:

```text id="237yrn"
What is a Dockerfile?
```

Strong answer:

```text id="ygpe9w"
A Dockerfile is a set of instructions used to build a Docker image. It defines the base image, working directory, dependencies, copied files, environment defaults, exposed ports, runtime user, healthcheck, and default command used when a container starts.
```

Question:

```text id="dltm3r"
What is the difference between RUN and CMD?
```

Strong answer:

```text id="orym12"
`RUN` executes during image build and creates an image layer, for example installing dependencies. `CMD` defines the default command that runs when a container starts, for example starting the application with `node server.js`.
```

Question:

```text id="h8w618"
What is the difference between ARG and ENV?
```

Strong answer:

```text id="wkk8e4"
`ARG` is a build-time variable available only during image build. `ENV` sets environment variables that are available in the running container. ARG is useful for build metadata like version or commit SHA, while ENV is useful for safe runtime defaults. Real secrets should not be baked into images using either ARG or ENV.
```

Question:

```text id="fz7sih"
Why do we copy package.json before copying source code?
```

Strong answer:

```text id="3jlvye"
Copying package.json and package-lock.json before the full source allows Docker to cache the dependency installation layer. If only application source changes, Docker can reuse the npm install layer, making builds faster.
```

Question:

```text id="yrt553"
Why run containers as non-root?
```

Strong answer:

```text id="774o84"
Running containers as non-root reduces risk if the application is compromised. It follows least privilege and limits what the process can do inside the container and potentially on mounted files or container runtime boundaries.
```

---

# Today’s Core Rules

```text id="3vfyzy"
Dockerfile builds an image.
RUN is build time.
CMD is container start time.
ARG is build time.
ENV is runtime/default config.
Use .dockerignore.
Do not copy .env into images.
Do not bake secrets into images.
Copy dependency files before source for cache.
Use specific base image tags.
Run as non-root.
Use EXPOSE for documentation.
Use -p to publish ports.
Add HEALTHCHECK when useful.
```

Next lesson:

# Lesson 6.3 — Docker Image Layers, Cache, Tagging, and Image Size Optimization.
