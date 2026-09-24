# Lesson 6.5 — Docker Compose Masterclass

# Multi-Container Apps, Service Names, Env Files, Volumes, Networks, and Production-Style Compose Structure

Until now, you manually ran containers like this:

```bash
docker run -d \
  --name demo-node-api \
  --network demo-app-net \
  -e APP_ENV=dev \
  -p 3000:3000 \
  demo-node-api:0.1.9
```

That is fine for learning, but real projects usually need multiple containers:

```text
backend API
database
redis
nginx
worker
frontend
```

Running all of them manually with `docker run` becomes painful.

Docker Compose solves this.

---

# 1. Beginner Level — What Is Docker Compose?

Docker Compose lets you define multiple containers in one YAML file.

Instead of running many `docker run` commands, you write:

```yaml
services:
  backend:
    image: demo-node-api:0.1.9
    ports:
      - "3000:3000"
```

Then run:

```bash
docker compose up -d
```

Compose creates:

```text
containers
networks
volumes
environment variables
port mappings
service DNS names
```

Simple definition:

```text
Docker Compose is a tool for running multi-container applications using a YAML file.
```

---

# 2. Why Compose Matters in Real DevOps

Without Compose:

```bash
docker network create app-net

docker run -d --name mongo --network app-net mongo:7

docker run -d \
  --name backend \
  --network app-net \
  -e DATABASE_URL=mongodb://mongo:27017/demo \
  -p 3000:3000 \
  demo-node-api:0.1.9

docker run -d \
  --name nginx \
  --network app-net \
  -p 8080:80 \
  nginx:alpine
```

With Compose:

```bash
docker compose up -d
```

Compose is used for:

```text
local development
integration testing
CI pipeline services
demo environments
single-server deployments
developer onboarding
internal tools
```

Production Kubernetes is different, but Compose teaches the same core ideas:

```text
services
networks
volumes
env vars
health checks
dependencies
logs
restart policies
```

---

# 3. Beginner Mental Model

Compose file:

```text
compose.yaml
```

Defines the desired stack:

```text
backend service
database service
nginx service
network
volume
environment variables
ports
```

Then Docker Compose turns that into running containers.

```text
compose.yaml
   ↓
docker compose up
   ↓
Docker containers + networks + volumes
```

Important:

```text
service name becomes DNS name
```

If your Compose service is named `mongo`, other services can connect to:

```text
mongodb://mongo:27017/demo
```

Not:

```text
mongodb://localhost:27017/demo
```

---

# 4. Create Compose Lab Directory

Run:

```bash
cd ~/devops-masterclass/06-docker-containers
mkdir -p compose-demo
cd compose-demo
```

Create basic structure:

```bash
mkdir -p nginx
touch compose.yaml
```

---

# 5. Build Your App Image First

Before Compose runs the app, make sure image exists:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.1.9 ./scripts/docker-build.sh
```

Check:

```bash
docker images | grep demo-node-api
```

Expected:

```text
demo-node-api   0.1.9
```

Return to Compose directory:

```bash
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

---

# 6. Beginner Compose File — One Service

Create:

```bash
nano compose.yaml
```

Paste:

```yaml
services:
  backend:
    image: demo-node-api:0.1.9
    container_name: compose-demo-backend
    ports:
      - "3000:3000"
    environment:
      APP_ENV: dev
      PORT: "3000"
      LOG_LEVEL: info
      LOAD_DOTENV: "false"
```

Start:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
docker ps
```

Test:

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/version | jq .
```

Logs:

```bash
docker compose logs backend
```

Follow logs:

```bash
docker compose logs -f backend
```

Stop:

```bash
docker compose down
```

---

# 7. Intermediate Level — Compose Service Names

In Compose, the service name is important.

Here:

```yaml
services:
  backend:
```

The service name is:

```text
backend
```

Other containers in the same Compose project can reach it using:

```text
http://backend:3000
```

This is internal Docker DNS.

So if Nginx is another service, Nginx should proxy to:

```nginx
proxy_pass http://backend:3000;
```

Not:

```nginx
proxy_pass http://localhost:3000;
```

Because inside the Nginx container:

```text
localhost = Nginx container itself
```

---

# 8. Add Nginx Reverse Proxy Service

Create Nginx config:

```bash
nano nginx/default.conf
```

Paste:

```nginx
server {
    listen 80;

    location = /nginx-health {
        access_log off;
        return 200 "nginx ok\n";
    }

    location / {
        proxy_pass http://backend:3000;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Request-ID $request_id;

        proxy_connect_timeout 5s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
```

Update `compose.yaml`:

```yaml
services:
  backend:
    image: demo-node-api:0.1.9
    container_name: compose-demo-backend
    environment:
      APP_ENV: dev
      PORT: "3000"
      LOG_LEVEL: info
      LOAD_DOTENV: "false"

  nginx:
    image: nginx:alpine
    container_name: compose-demo-nginx
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
```

Start:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
```

Test through Nginx:

```bash
curl -i http://127.0.0.1:8080/nginx-health
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
```

Notice:

```text
backend has no host port now
nginx is the public entrypoint
```

This is production-style.

---

# 9. Beginner Mistake — Publishing Every Port

Bad Compose:

```yaml
services:
  backend:
    ports:
      - "3000:3000"

  mongo:
    ports:
      - "27017:27017"

  redis:
    ports:
      - "6379:6379"
```

This exposes too much.

Better:

```yaml
services:
  nginx:
    ports:
      - "8080:80"

  backend:
    expose:
      - "3000"

  mongo:
    expose:
      - "27017"

  redis:
    expose:
      - "6379"
```

Important difference:

```text
ports  = publish to host
expose = document/internal container port
```

Production rule:

```text
Only publish public entrypoints. Keep backend, database, and cache internal.
```

---

# 10. Add Explicit Network

Compose automatically creates a default network.

But production-style Compose should define networks explicitly.

Update `compose.yaml`:

```yaml
services:
  backend:
    image: demo-node-api:0.1.9
    container_name: compose-demo-backend
    expose:
      - "3000"
    environment:
      APP_ENV: dev
      PORT: "3000"
      LOG_LEVEL: info
      LOAD_DOTENV: "false"
    networks:
      - app_net

  nginx:
    image: nginx:alpine
    container_name: compose-demo-nginx
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
    networks:
      - app_net

networks:
  app_net:
    driver: bridge
```

Apply:

```bash
docker compose down
docker compose up -d
```

Inspect network:

```bash
docker network ls | grep compose-demo
docker compose ps
```

Test:

```bash
curl -s http://127.0.0.1:8080/health | jq .
```

---

# 11. Intermediate Level — `.env` File for Compose Variables

Compose automatically reads a file named:

```text
.env
```

from the same directory as `compose.yaml`.

This is for Compose variable substitution.

Create:

```bash
nano .env
```

Paste:

```bash
APP_IMAGE=demo-node-api
APP_VERSION=0.1.9
HOST_HTTP_PORT=8080
APP_ENV=dev
LOG_LEVEL=info
```

Update `compose.yaml`:

```yaml
services:
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    container_name: compose-demo-backend
    expose:
      - "3000"
    environment:
      APP_ENV: ${APP_ENV}
      PORT: "3000"
      LOG_LEVEL: ${LOG_LEVEL}
      LOAD_DOTENV: "false"
    networks:
      - app_net

  nginx:
    image: nginx:alpine
    container_name: compose-demo-nginx
    ports:
      - "${HOST_HTTP_PORT}:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
    networks:
      - app_net

networks:
  app_net:
    driver: bridge
```

Validate resolved config:

```bash
docker compose config
```

Start:

```bash
docker compose up -d
```

Test:

```bash
curl -s http://127.0.0.1:8080/health | jq .
```

Important distinction:

```text
Compose .env file = variable substitution for compose.yaml
container env vars = environment passed into container
```

They are related but not exactly the same.

---

# 12. Use `env_file` for App Runtime Config

For app runtime variables, many teams use a separate env file.

Create:

```bash
nano backend.env
```

Paste:

```bash
APP_ENV=dev
PORT=3000
LOG_LEVEL=info
LOAD_DOTENV=false
APP_NAME=demo-node-api
APP_VERSION=0.1.9
COMMIT_SHA=compose-local
REQUEST_TIMEOUT_MS=5000
STARTUP_DELAY_MS=0
```

Update backend service:

```yaml
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    container_name: compose-demo-backend
    expose:
      - "3000"
    env_file:
      - ./backend.env
    networks:
      - app_net
```

Full file:

```yaml
services:
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    container_name: compose-demo-backend
    expose:
      - "3000"
    env_file:
      - ./backend.env
    networks:
      - app_net

  nginx:
    image: nginx:alpine
    container_name: compose-demo-nginx
    ports:
      - "${HOST_HTTP_PORT}:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
    networks:
      - app_net

networks:
  app_net:
    driver: bridge
```

Restart:

```bash
docker compose down
docker compose up -d
```

Check app config summary:

```bash
curl -s http://127.0.0.1:8080/config-summary | jq .
```

Production caution:

```text
Do not commit real secret env files.
Commit backend.env.example instead.
```

Create example:

```bash
cp backend.env backend.env.example
```

Add to `.gitignore` later:

```gitignore
backend.env
.env
```

---

# 13. Advanced Level — Add MongoDB Service

Now let’s add a database container.

Update `backend.env`:

```bash
nano backend.env
```

Set:

```bash
APP_ENV=prod
PORT=3000
LOG_LEVEL=info
LOAD_DOTENV=false
APP_NAME=demo-node-api
APP_VERSION=0.1.9
COMMIT_SHA=compose-local
DATABASE_URL=mongodb://mongo:27017/demo
CORS_ORIGIN=http://localhost:8080
ENABLE_CACHE=false
REQUEST_TIMEOUT_MS=5000
STARTUP_DELAY_MS=0
```

Important:

```text
DATABASE_URL=mongodb://mongo:27017/demo
```

Because Compose service name will be:

```yaml
mongo:
```

Add MongoDB service and volume:

```yaml
services:
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    container_name: compose-demo-backend
    expose:
      - "3000"
    env_file:
      - ./backend.env
    depends_on:
      - mongo
    networks:
      - app_net

  mongo:
    image: mongo:7
    container_name: compose-demo-mongo
    expose:
      - "27017"
    volumes:
      - mongo_data:/data/db
    networks:
      - app_net

  nginx:
    image: nginx:alpine
    container_name: compose-demo-nginx
    ports:
      - "${HOST_HTTP_PORT}:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
    networks:
      - app_net

volumes:
  mongo_data:

networks:
  app_net:
    driver: bridge
```

Start:

```bash
docker compose down
docker compose up -d
```

Check:

```bash
docker compose ps
```

Test readiness:

```bash
curl -s http://127.0.0.1:8080/ready | jq .
```

Your app currently only checks whether `DATABASE_URL` exists, not whether MongoDB is truly reachable. That is okay for now. Later we can add real DB connectivity checks.

---

# 14. Volumes — Beginner to Production

This line:

```yaml
volumes:
  - mongo_data:/data/db
```

Means:

```text
Docker named volume mongo_data stores MongoDB files
MongoDB data survives container recreation
```

Check volumes:

```bash
docker volume ls
```

Inspect:

```bash
docker volume inspect compose-demo_mongo_data
```

Bring stack down but keep data:

```bash
docker compose down
```

Bring stack up:

```bash
docker compose up -d
```

Data remains.

Remove stack and volume:

```bash
docker compose down -v
```

Danger:

```text
docker compose down -v deletes named volumes for this stack.
For databases, that means data loss.
```

Production rule:

```text
Never run down -v casually on database stacks.
```

---

# 15. `depends_on` — Important Limitation

This:

```yaml
depends_on:
  - mongo
```

Means:

```text
start mongo container before backend container
```

It does not always mean:

```text
MongoDB is fully ready to accept connections
```

Beginner misconception:

```text
depends_on waits until service is ready
```

Better understanding:

```text
depends_on controls startup order
healthchecks control readiness
```

We will improve it with healthchecks.

---

# 16. Add Healthchecks

Update Compose:

```yaml
services:
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    container_name: compose-demo-backend
    expose:
      - "3000"
    env_file:
      - ./backend.env
    depends_on:
      mongo:
        condition: service_started
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:3000/ready || exit 1"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 10s
    networks:
      - app_net

  mongo:
    image: mongo:7
    container_name: compose-demo-mongo
    expose:
      - "27017"
    volumes:
      - mongo_data:/data/db
    healthcheck:
      test: ["CMD-SHELL", "mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    networks:
      - app_net

  nginx:
    image: nginx:alpine
    container_name: compose-demo-nginx
    ports:
      - "${HOST_HTTP_PORT}:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - app_net

volumes:
  mongo_data:

networks:
  app_net:
    driver: bridge
```

Apply:

```bash
docker compose down
docker compose up -d
```

Watch:

```bash
docker compose ps
```

Inspect health:

```bash
docker inspect compose-demo-backend --format '{{json .State.Health}}' | jq .
docker inspect compose-demo-mongo --format '{{json .State.Health}}' | jq .
```

Important production idea:

```text
Startup order is not enough. Health and readiness matter.
```

---

# 17. Advanced Production Structure — Public and Private Networks

Right now all services share one network.

Better production-style design:

```text
public_net:
  nginx
  backend

private_net:
  backend
  mongo
```

Nginx does not need direct access to MongoDB.

MongoDB does not need to be on the public network.

Update Compose:

```yaml
services:
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    container_name: compose-demo-backend
    expose:
      - "3000"
    env_file:
      - ./backend.env
    depends_on:
      mongo:
        condition: service_started
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:3000/ready || exit 1"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 10s
    networks:
      - public_net
      - private_net

  mongo:
    image: mongo:7
    container_name: compose-demo-mongo
    expose:
      - "27017"
    volumes:
      - mongo_data:/data/db
    healthcheck:
      test: ["CMD-SHELL", "mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    networks:
      - private_net

  nginx:
    image: nginx:alpine
    container_name: compose-demo-nginx
    ports:
      - "${HOST_HTTP_PORT}:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - public_net

volumes:
  mongo_data:

networks:
  public_net:
    driver: bridge
  private_net:
    driver: bridge
```

Start:

```bash
docker compose down
docker compose up -d
```

Test:

```bash
curl -s http://127.0.0.1:8080/health | jq .
```

Debug network membership:

```bash
docker network ls | grep compose-demo
docker network inspect compose-demo_public_net | jq '.[0].Containers'
docker network inspect compose-demo_private_net | jq '.[0].Containers'
```

Expected:

```text
public_net: nginx, backend
private_net: backend, mongo
```

This is closer to corporate architecture.

---

# 18. Restart Policies

Add restart policies:

```yaml
restart: unless-stopped
```

Example:

```yaml
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    restart: unless-stopped
```

Common policies:

| Policy           | Meaning                         |
| ---------------- | ------------------------------- |
| `no`             | do not restart automatically    |
| `always`         | always restart                  |
| `unless-stopped` | restart unless manually stopped |
| `on-failure`     | restart only on failure         |

For local development:

```text
no or unless-stopped
```

For simple server deployment:

```text
unless-stopped
```

In Kubernetes:

```text
Kubernetes manages restart policy differently
```

Use:

```yaml
restart: unless-stopped
```

for `backend`, `nginx`, and `mongo`.

---

# 19. Logging Behavior in Compose

View all logs:

```bash
docker compose logs
```

Follow:

```bash
docker compose logs -f
```

Only backend:

```bash
docker compose logs -f backend
```

Last lines:

```bash
docker compose logs --tail 50 backend
```

Production note:

```text
Containers should log to stdout/stderr.
Docker or the orchestrator collects logs.
Do not write important logs only inside container files.
```

Optional Compose logging limit:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Add to services if desired:

```yaml
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

Why?

```text
Prevents Docker JSON logs from consuming unlimited disk on a single server.
```

This is important on real VMs.

---

# 20. Full Production-Style Local Compose File

Use this as your final `compose.yaml`:

```yaml
services:
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    container_name: compose-demo-backend
    restart: unless-stopped
    expose:
      - "3000"
    env_file:
      - ./backend.env
    depends_on:
      mongo:
        condition: service_started
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:3000/ready || exit 1"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 10s
    networks:
      - public_net
      - private_net
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  mongo:
    image: mongo:7
    container_name: compose-demo-mongo
    restart: unless-stopped
    expose:
      - "27017"
    volumes:
      - mongo_data:/data/db
    healthcheck:
      test: ["CMD-SHELL", "mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    networks:
      - private_net
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    image: nginx:alpine
    container_name: compose-demo-nginx
    restart: unless-stopped
    ports:
      - "${HOST_HTTP_PORT}:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - public_net
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  mongo_data:

networks:
  public_net:
    driver: bridge
  private_net:
    driver: bridge
```

Apply:

```bash
docker compose down
docker compose up -d
```

Validate:

```bash
docker compose ps
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
curl -s http://127.0.0.1:8080/config-summary | jq .
```

---

# 21. Compose Commands You Must Know

Start foreground:

```bash
docker compose up
```

Start background:

```bash
docker compose up -d
```

Stop and remove containers/network:

```bash
docker compose down
```

Stop without removing:

```bash
docker compose stop
```

Start stopped services:

```bash
docker compose start
```

Restart service:

```bash
docker compose restart backend
```

View containers:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs -f backend
```

Run command in service container:

```bash
docker compose exec backend sh
```

Run one-off container:

```bash
docker compose run --rm backend node -v
```

Validate final config:

```bash
docker compose config
```

Pull images:

```bash
docker compose pull
```

Recreate after config change:

```bash
docker compose up -d --force-recreate
```

Remove volumes too:

```bash
docker compose down -v
```

Danger:

```text
down -v deletes named volumes. Do not use casually with databases.
```

---

# 22. Build Image Inside Compose

Instead of using prebuilt image, Compose can build.

For development:

```yaml
services:
  backend:
    build:
      context: ../../05-application-runtime/demo-node-api
      dockerfile: Dockerfile.industry
      target: runtime
      args:
        APP_VERSION: ${APP_VERSION}
        COMMIT_SHA: compose-build
    image: ${APP_IMAGE}:${APP_VERSION}
```

Then:

```bash
docker compose build backend
docker compose up -d
```

For CI/CD or production, better pattern is often:

```text
CI builds image
CI pushes image to registry
server pulls exact image tag
Compose runs image
```

Why?

```text
build is reproducible in CI
image is scanned
image is versioned
deployment server does not need source code/build tools
rollback uses previous image tag
```

---

# 23. Corporate Example — Local Dev Stack

A corporate team may have:

```text
frontend
backend
postgres
redis
mailhog
nginx
```

Developers run:

```bash
docker compose up -d
```

Then they get a complete local environment.

Example behavior:

```text
frontend calls backend by http://backend:3000
backend calls postgres by postgres:5432
backend calls redis by redis:6379
nginx exposes localhost:8080
```

This avoids:

```text
manual database setup
manual Redis setup
different versions on each laptop
slow onboarding
```

Common corporate onboarding command:

```bash
make dev-up
```

which internally runs:

```bash
docker compose up -d
```

---

# 24. Corporate Example — Single Server Deployment

For small internal apps, Compose may run on a VM:

```text
VM
├── nginx container
├── backend container
├── redis container
└── postgres/mongo container
```

Deployment:

```bash
docker compose pull
docker compose up -d
```

Better deployment pattern:

```text
1. CI builds image with git SHA tag
2. CI pushes image to registry
3. server updates .env APP_VERSION=<sha>
4. docker compose pull
5. docker compose up -d
6. run health check
7. rollback by previous APP_VERSION
```

For larger systems, Kubernetes replaces this pattern, but Compose is still excellent for:

```text
local development
small internal tools
POCs
integration testing
single-node deployments
```

---

# 25. Masterclass Pattern — Compose File Split

In real projects, teams often split Compose files:

```text
compose.yaml
compose.override.yaml
compose.prod.yaml
```

## `compose.yaml`

Base services.

## `compose.override.yaml`

Automatically loaded by Compose for local development.

Example:

```yaml
services:
  backend:
    volumes:
      - ../../05-application-runtime/demo-node-api:/app
    environment:
      LOG_LEVEL: debug
```

## `compose.prod.yaml`

Production-specific settings.

Run:

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

This pattern allows:

```text
same base stack
different local/prod behavior
cleaner config
less duplication
```

We will use this later when we create Docker capstone.

---

# 26. Create `.gitignore` for Compose Demo

Create:

```bash
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano .gitignore
```

Paste:

```gitignore
.env
backend.env
```

Create safe examples:

```bash
cp .env .env.example
cp backend.env backend.env.example
```

Now your repo can include:

```text
.env.example
backend.env.example
```

but not real env files.

---

# 27. Create Compose Notes

Create:

```bash
cd ~/devops-masterclass/06-docker-containers
nano docker-compose-masterclass.md
```

Paste:

````markdown
# Docker Compose Masterclass

## What Compose Does

Docker Compose runs multi-container applications using a YAML file.

It manages:

- services
- containers
- networks
- volumes
- environment variables
- port publishing
- healthchecks
- logs
- restart policies

## Core Commands

```bash
docker compose up -d
docker compose ps
docker compose logs -f
docker compose logs -f backend
docker compose exec backend sh
docker compose config
docker compose down
docker compose down -v
````

## Important Concepts

### Service Name DNS

Services can call each other by service name.

```text
backend -> mongo:27017
nginx -> backend:3000
```

### Ports vs Expose

```yaml
ports:
  - "8080:80"
```

Publishes to host.

```yaml
expose:
  - "3000"
```

Documents/internal port only.

### Volumes

Named volumes persist data.

```yaml
volumes:
  mongo_data:
```

Do not run `docker compose down -v` casually.

### Env Files

Compose `.env` is used for variable substitution.

`env_file` passes variables into containers.

## Production Rules

* publish only public entrypoints
* keep databases private
* use named volumes for data
* use healthchecks
* use restart policies
* limit logs
* separate public/private networks
* use image tags, not latest
* do not commit secret env files

````

---

# 28. Create Compose Troubleshooting Playbook

Create:

```bash
nano compose-troubleshooting-playbook.md
````

Paste:

````markdown
# Docker Compose Troubleshooting Playbook

## Service Not Running

```bash
docker compose ps
docker compose logs service-name
docker inspect container-name --format '{{json .State}}' | jq .
````

## Nginx 502

```bash
docker compose logs nginx
docker compose logs backend
docker compose exec nginx nginx -t
docker compose exec nginx wget -qO- http://backend:3000/health
```

## Backend Cannot Reach Mongo

```bash
docker compose exec backend sh
```

Inside backend container:

```sh
wget -qO- http://backend:3000/health
```

Check env:

```bash
docker compose exec backend env | sort
```

Correct URL should use service name:

```text
mongodb://mongo:27017/demo
```

## DNS Issue

```bash
docker compose exec backend cat /etc/resolv.conf
docker compose exec backend getent hosts mongo
```

If tool missing, use an Alpine debug container:

```bash
docker run --rm --network compose-demo_private_net alpine:3.20 sh -c \
  "apk add --no-cache bind-tools curl && nslookup mongo"
```

## Port Not Accessible from Host

```bash
docker compose ps
docker port compose-demo-nginx
```

Only services with `ports` are reachable from host.

## Volume/Data Issue

```bash
docker volume ls
docker volume inspect compose-demo_mongo_data
```

Danger:

```bash
docker compose down -v
```

This deletes project volumes.

````

---

# 29. Add Makefile for Developer Experience

Create:

```bash
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano Makefile
````

Paste:

```Makefile
.PHONY: up down ps logs backend-logs nginx-logs config test restart clean

up:
	docker compose up -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f

backend-logs:
	docker compose logs -f backend

nginx-logs:
	docker compose logs -f nginx

config:
	docker compose config

test:
	curl -fsS http://127.0.0.1:8080/nginx-health
	curl -fsS http://127.0.0.1:8080/health | jq .
	curl -fsS http://127.0.0.1:8080/ready | jq .
	curl -fsS http://127.0.0.1:8080/version | jq .

restart:
	docker compose restart backend

clean:
	docker compose down
```

Now use:

```bash
make up
make ps
make test
make logs
make down
```

This is corporate-style developer experience.

---

# 30. Final Validation

Run:

```bash
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

Validate config:

```bash
docker compose config
```

Start:

```bash
docker compose up -d
```

Check services:

```bash
docker compose ps
```

Test endpoints:

```bash
curl -i http://127.0.0.1:8080/nginx-health
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
curl -s http://127.0.0.1:8080/config-summary | jq .
```

Check DNS:

```bash
docker compose exec nginx wget -qO- http://backend:3000/health
```

Check Mongo network isolation:

```bash
docker network inspect compose-demo_public_net | jq '.[0].Containers'
docker network inspect compose-demo_private_net | jq '.[0].Containers'
```

Check logs:

```bash
docker compose logs --tail 30 backend
docker compose logs --tail 30 nginx
docker compose logs --tail 30 mongo
```

Stop:

```bash
docker compose down
```

Keep database volume:

```text
Do not use -v unless you intentionally want to delete Mongo data.
```

---

# 31. Commit Work

Run:

```bash
cd ~/devops-masterclass

git status
git add 06-docker-containers
git commit -m "feat: add Docker Compose multi-container stack"
git push
```

---

# 32. Interview Explanation

## What is Docker Compose?

Strong answer:

```text
Docker Compose is a tool for defining and running multi-container Docker applications using a YAML file. It manages services, networks, volumes, environment variables, port mappings, healthchecks, logs, and restart policies.
```

## Why use service names in Compose?

Strong answer:

```text
Compose creates a project network and provides DNS resolution for services. Containers can communicate using service names like backend or mongo instead of dynamic container IPs. This makes service-to-service communication stable and portable.
```

## Difference between `ports` and `expose`?

Strong answer:

```text
ports publishes a container port to the host, making it reachable from outside Docker. expose only documents or exposes the port internally to other containers on the Docker network. In production, only public entrypoints should use ports.
```

## What is the purpose of volumes?

Strong answer:

```text
Volumes persist data outside the container writable layer. They are used for databases, uploads, caches, or any data that must survive container recreation. Without volumes, data written inside a container can be lost when the container is removed.
```

## Does `depends_on` wait until a dependency is ready?

Strong answer:

```text
depends_on controls startup order, but startup is not the same as readiness. For reliable startup behavior, services should define healthchecks and dependent services should wait for healthy dependencies where supported.
```

## How would you design a production-style Compose stack?

Strong answer:

```text
I would publish only the reverse proxy ports, keep backend and databases on private networks, use service-name DNS, named volumes for persistent data, env files or secrets for runtime config, healthchecks for readiness, restart policies, log rotation options, immutable image tags, and separate public/private networks.
```

---

# Today’s Core Rules

```text
Compose runs multi-container stacks.
Service names become DNS names.
Use user-defined networks.
Use ports only for public entrypoints.
Use expose for internal services.
Use named volumes for persistent data.
Do not commit secret env files.
Compose .env is for substitution.
env_file passes runtime env vars.
depends_on is not full readiness by itself.
Use healthchecks.
Use restart policies.
Limit container logs on single servers.
Separate public and private networks.
Do not run docker compose down -v casually.
```

Next lesson:

# Lesson 6.6 — Docker Volumes and Persistent Data Masterclass: named volumes, bind mounts, database persistence, backup/restore, permissions, and production storage patterns.
