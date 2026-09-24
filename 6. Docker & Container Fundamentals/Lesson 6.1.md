# Module 6 — Docker and Container Fundamentals

# Lesson 6.1 — What Containers Actually Are

Now we start one of the most important DevOps modules:

```text
Docker and Containers
```

You already learned the runtime layer:

```text
process
port
env vars
logs
health checks
systemd/PM2
Nginx
deployment layout
rollback
```

That foundation is important because Docker does not remove these concepts. Docker packages them.

---

# 1. Why Containers Exist

Before containers, deployment often looked like this:

```text
Developer machine:
  Node.js 20
  npm package versions
  local config
  app works

Server:
  Node.js 18
  missing dependency
  different OS package
  different env
  app fails
```

Classic problem:

```text
It works on my machine.
```

Containers solve this by packaging:

```text
application code
runtime
dependencies
system libraries
startup command
default environment
```

into an image that can run consistently.

Core idea:

```text
Build once. Run anywhere Docker is available.
```

---

# 2. What Is a Container?

A container is a running process with isolation.

Simple definition:

```text
A container is an isolated process created from an image.
```

It has its own view of:

```text
filesystem
processes
network
environment variables
users
resource limits
```

But it still uses the host machine’s Linux kernel.

Very important:

```text
Containers are not tiny virtual machines.
```

A container is closer to:

```text
a normal Linux process with isolation boundaries
```

than a full VM.

---

# 3. Container vs Virtual Machine

## Virtual Machine

```text
Hardware
  ↓
Host OS
  ↓
Hypervisor
  ↓
Guest OS
  ↓
App
```

Each VM has its own guest operating system.

## Container

```text
Hardware
  ↓
Host OS kernel
  ↓
Container runtime
  ↓
Isolated app process
```

Containers share the host kernel.

That makes containers:

```text
faster to start
lighter than VMs
easier to package
good for CI/CD
good for microservices
```

But containers are not security magic. They still need hardening.

---

# 4. Image vs Container

This is the most important Docker distinction.

## Image

An image is the packaged template.

Example:

```text
node:22-alpine
nginx:alpine
mongo:7
my-demo-api:0.1.0
```

An image is not running.

Think:

```text
image = class / blueprint / package
```

## Container

A container is a running instance of an image.

Think:

```text
container = object / running process
```

Example:

```bash
docker run node:22-alpine node -v
```

Here:

```text
node:22-alpine = image
running node process = container
```

Core rule:

```text
Image is the package. Container is the running instance.
```

---

# 5. Docker Mental Model

Docker workflow:

```text
Dockerfile
  ↓ docker build
Image
  ↓ docker run
Container
```

Visual:

```text
+-------------+
| Dockerfile  |
+------+------+
       |
       | docker build
       v
+-------------+
| Image       |
+------+------+
       |
       | docker run
       v
+-------------+
| Container   |
+-------------+
```

Common commands:

```bash
docker build -t my-app:1.0 .
docker images
docker run my-app:1.0
docker ps
docker logs <container>
docker stop <container>
docker rm <container>
```

---

# 6. Install / Verify Docker

On your Ubuntu/WSL environment, first check:

```bash
docker --version
docker compose version
```

Check Docker service:

```bash
sudo systemctl status docker --no-pager
```

If Docker is not installed on Ubuntu:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
```

Start Docker:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

Add your user to docker group:

```bash
sudo usermod -aG docker "$USER"
```

Then log out and log back in, or run:

```bash
newgrp docker
```

Validate:

```bash
docker run hello-world
```

Expected:

```text
Hello from Docker!
```

---

# 7. First Container Commands

Run an Ubuntu container:

```bash
docker run ubuntu:24.04 echo "hello from container"
```

What happened?

```text
Docker checked if image exists locally.
If not, pulled image.
Created container.
Ran echo command.
Container exited.
```

Check all containers:

```bash
docker ps -a
```

You will see exited containers too.

Run interactive container:

```bash
docker run -it ubuntu:24.04 bash
```

Inside container:

```bash
whoami
hostname
cat /etc/os-release
ps aux
ls /
exit
```

Outside container:

```bash
docker ps -a
```

Important:

```text
When the main process exits, the container stops.
```

---

# 8. Container Main Process

Every container has a main process.

Example:

```bash
docker run ubuntu:24.04 echo hello
```

Main process:

```text
echo hello
```

It finishes immediately, so container exits.

Example:

```bash
docker run nginx:alpine
```

Main process:

```text
nginx
```

Nginx keeps running, so container stays running.

Core rule:

```text
A container lives as long as its main process lives.
```

This connects directly to Module 5.

In systemd, the service depends on the main process.

In Docker, the container depends on the main process.

---

# 9. Detached Mode

Run Nginx in background:

```bash
docker run -d --name demo-nginx nginx:alpine
```

Check running containers:

```bash
docker ps
```

Check logs:

```bash
docker logs demo-nginx
```

Stop:

```bash
docker stop demo-nginx
```

Remove:

```bash
docker rm demo-nginx
```

One command to stop and remove if exists:

```bash
docker rm -f demo-nginx || true
```

---

# 10. Port Publishing

If you run:

```bash
docker run -d --name demo-nginx nginx:alpine
```

Nginx runs inside the container on port 80.

But your host cannot access it unless you publish the port.

Run:

```bash
docker rm -f demo-nginx || true

docker run -d \
  --name demo-nginx \
  -p 8080:80 \
  nginx:alpine
```

Meaning:

```text
host port 8080 → container port 80
```

Test:

```bash
curl -I http://127.0.0.1:8080
```

Expected:

```text
HTTP/1.1 200 OK
```

Port mapping format:

```text
-p HOST_PORT:CONTAINER_PORT
```

Examples:

```bash
-p 3000:3000
-p 8080:80
-p 5432:5432
```

Core rule:

```text
EXPOSE documents a container port.
-p actually publishes it to the host.
```

We will use this a lot.

---

# 11. Container Filesystem

Run:

```bash
docker run -it --name fs-demo ubuntu:24.04 bash
```

Inside:

```bash
echo "hello container" > /tmp/demo.txt
cat /tmp/demo.txt
exit
```

Start same container again:

```bash
docker start -ai fs-demo
```

Inside:

```bash
cat /tmp/demo.txt
exit
```

The file is still there because it is the same container.

Now remove container:

```bash
docker rm fs-demo
```

Create new one:

```bash
docker run -it --name fs-demo-2 ubuntu:24.04 bash
```

Inside:

```bash
cat /tmp/demo.txt
```

It will not exist.

Important:

```text
Container filesystem changes belong to that container.
If the container is removed, those changes are lost.
```

For persistent data, use:

```text
volumes
bind mounts
databases outside container
object storage
```

---

# 12. Volumes Preview

Run Nginx with a bind mount:

```bash
mkdir -p ~/devops-masterclass/06-docker-containers/nginx-html
echo "Hello from mounted HTML" > ~/devops-masterclass/06-docker-containers/nginx-html/index.html
```

Run:

```bash
docker rm -f demo-nginx || true

docker run -d \
  --name demo-nginx \
  -p 8080:80 \
  -v ~/devops-masterclass/06-docker-containers/nginx-html:/usr/share/nginx/html:ro \
  nginx:alpine
```

Test:

```bash
curl http://127.0.0.1:8080
```

Expected:

```text
Hello from mounted HTML
```

Meaning:

```text
host directory → container directory
```

The `:ro` means read-only.

Core rule:

```text
Use volumes or bind mounts when data must survive container replacement.
```

---

# 13. Environment Variables in Containers

Run:

```bash
docker run --rm ubuntu:24.04 env
```

Pass env var:

```bash
docker run --rm \
  -e APP_ENV=dev \
  -e PORT=3000 \
  ubuntu:24.04 env
```

You will see:

```text
APP_ENV=dev
PORT=3000
```

This connects to Module 5:

```text
Docker injects runtime config using environment variables.
```

For your Node app later:

```bash
docker run \
  -e APP_ENV=prod \
  -e PORT=3000 \
  -p 3000:3000 \
  demo-node-api:0.1.0
```

---

# 14. Container Logs

Run:

```bash
docker rm -f demo-nginx || true

docker run -d \
  --name demo-nginx \
  -p 8080:80 \
  nginx:alpine
```

Generate traffic:

```bash
curl http://127.0.0.1:8080
```

View logs:

```bash
docker logs demo-nginx
```

Follow logs:

```bash
docker logs -f demo-nginx
```

Last 20 lines:

```bash
docker logs --tail 20 demo-nginx
```

Important:

```text
Docker captures stdout/stderr of the main process.
```

That is why in Module 5 we said:

```text
Apps should log to stdout/stderr.
```

---

# 15. Inspect Containers

Inspect container metadata:

```bash
docker inspect demo-nginx
```

This outputs a large JSON.

Useful filters:

```bash
docker inspect demo-nginx --format '{{.State.Status}}'
docker inspect demo-nginx --format '{{.NetworkSettings.IPAddress}}'
docker inspect demo-nginx --format '{{json .Config.Env}}'
```

Check port mappings:

```bash
docker port demo-nginx
```

Check resource usage:

```bash
docker stats demo-nginx
```

Stop stats:

```text
Ctrl + C
```

---

# 16. Execute Commands Inside Running Container

Run:

```bash
docker exec demo-nginx nginx -v
```

Open shell:

```bash
docker exec -it demo-nginx sh
```

Inside:

```bash
hostname
ps
ls /usr/share/nginx/html
exit
```

Important:

```text
docker exec is useful for debugging.
Do not use it as a normal deployment method.
```

Production principle:

```text
Containers should be recreated, not manually modified.
```

---

# 17. Remove Containers and Images

Stop container:

```bash
docker stop demo-nginx
```

Remove container:

```bash
docker rm demo-nginx
```

Remove image:

```bash
docker rmi nginx:alpine
```

Clean stopped containers:

```bash
docker container prune
```

Clean unused images:

```bash
docker image prune
```

Careful cleanup:

```bash
docker system prune
```

Dangerous if you do not understand what will be removed.

Core rule:

```text
Do not blindly run docker system prune on shared servers.
```

---

# 18. Docker Lab Directory

Create Module 6 directory:

```bash
cd ~/devops-masterclass
mkdir -p 06-docker-containers
cd 06-docker-containers
```

Create notes:

```bash
nano docker-fundamentals.md
```

Paste:

````markdown
# Docker and Container Fundamentals

## Core Concepts

- Image: packaged template
- Container: running instance of an image
- Dockerfile: build instructions for image
- Registry: stores images
- Volume: persistent/mounted data
- Port publishing: maps host port to container port

## Image vs Container

```text
Dockerfile --docker build--> Image --docker run--> Container
````

## Main Process Rule

A container runs as long as its main process runs.

If the main process exits, the container stops.

## Important Commands

```bash
docker --version
docker run hello-world
docker images
docker ps
docker ps -a
docker logs <container>
docker exec -it <container> sh
docker stop <container>
docker rm <container>
docker inspect <container>
docker stats <container>
```

## Port Mapping

```bash
docker run -p 8080:80 nginx:alpine
```

Meaning:

```text
host 8080 -> container 80
```

## Environment Variables

```bash
docker run -e APP_ENV=prod -e PORT=3000 image
```

## Volumes

```bash
docker run -v /host/path:/container/path:ro image
```

## Core Rules

* Image is not running.
* Container is a running instance.
* Container lives as long as its main process.
* Use `-p` to publish ports.
* Use `-e` to pass environment variables.
* Use volumes for persistent data.
* Logs should go to stdout/stderr.
* Recreate containers instead of manually modifying them.

````

---

# 19. Hands-On Practice Commands

Run these one by one:

```bash
docker run --rm hello-world
````

```bash
docker run --rm ubuntu:24.04 cat /etc/os-release
```

```bash
docker run -it --rm ubuntu:24.04 bash
```

Inside:

```bash
hostname
ps aux
env
exit
```

Run Nginx:

```bash
docker rm -f demo-nginx || true

docker run -d \
  --name demo-nginx \
  -p 8080:80 \
  nginx:alpine
```

Validate:

```bash
docker ps
curl -I http://127.0.0.1:8080
docker logs demo-nginx
docker inspect demo-nginx --format '{{.State.Status}}'
docker port demo-nginx
```

Exec:

```bash
docker exec -it demo-nginx sh
```

Inside:

```sh
ls /usr/share/nginx/html
exit
```

Cleanup:

```bash
docker rm -f demo-nginx
```

---

# 20. Common Beginner Mistakes

## Mistake 1 — Thinking image and container are the same

Wrong:

```text
I started an image.
```

Better:

```text
I started a container from an image.
```

## Mistake 2 — Forgetting port publishing

Container runs:

```bash
docker ps
```

But app not accessible.

Check:

```bash
docker port <container>
```

Fix:

```bash
docker run -p 3000:3000 image
```

## Mistake 3 — Saving important data inside container filesystem

Bad:

```text
Database files only inside container writable layer.
```

If container is removed, data can be lost.

Better:

```text
Use Docker volumes or external managed database.
```

## Mistake 4 — Manually editing running container

Bad:

```bash
docker exec -it app sh
vi config.js
```

Better:

```text
Change source/Dockerfile/config.
Build new image.
Run new container.
```

## Mistake 5 — Running multiple apps inside one container

Bad:

```text
Nginx + Node + MongoDB in one container
```

Better:

```text
One main process per container.
Use Compose or Kubernetes to run multiple containers.
```

---

# 21. How This Connects to Module 5

Module 5:

```text
systemd runs Node app
Nginx proxies to app
env file configures app
journalctl captures logs
deployment script switches current symlink
```

Docker version:

```text
Docker runs Node app
port mapping exposes app
-e configures app
docker logs captures logs
image tags define releases
container replacement deploys new version
```

Same concepts, different packaging.

| Module 5 VM Runtime | Docker Runtime                |
| ------------------- | ----------------------------- |
| systemd service     | container                     |
| `/opt/app/current`  | image tag                     |
| env file            | `docker run -e` / Compose env |
| journalctl          | docker logs                   |
| Nginx host install  | nginx container or host Nginx |
| restart service     | replace container             |
| release directory   | image version/tag             |

---

# 22. Interview Explanation

Question:

```text
What is a Docker container?
```

Strong answer:

```text
A Docker container is a running instance of an image. It is an isolated process with its own filesystem view, environment, network namespace, and process namespace, while sharing the host OS kernel. A container runs as long as its main process runs.
```

Question:

```text
What is the difference between image and container?
```

Strong answer:

```text
An image is an immutable packaged template containing application code, runtime, dependencies, and metadata. A container is a running instance of that image. We build images and run containers from them.
```

Question:

```text
Is a container a virtual machine?
```

Strong answer:

```text
No. A virtual machine includes a full guest operating system and runs on a hypervisor. A container shares the host kernel and runs as an isolated process. Containers are usually lighter and faster to start than virtual machines.
```

Question:

```text
Why do containers stop immediately sometimes?
```

Strong answer:

```text
A container stops when its main process exits. For example, if the command is `echo hello`, the command finishes immediately and the container exits. Long-running services like Nginx stay running because their main process keeps running.
```

---

# Today’s Core Rules

```text
Image is the package.
Container is the running instance.
Dockerfile builds an image.
docker run creates a container.
Container lives as long as main process lives.
Use -p to publish ports.
Use -e for environment variables.
Use volumes for persistent data.
Use docker logs for stdout/stderr.
Use docker exec for debugging, not normal changes.
Recreate containers instead of modifying them manually.
```

Next lesson:

# Lesson 6.2 — Dockerfile Basics: Building Your First Custom Image.
