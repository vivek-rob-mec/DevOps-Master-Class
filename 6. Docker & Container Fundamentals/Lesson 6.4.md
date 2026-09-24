Perfect. From this point onward, **every lesson** will follow this structure:

```text id="odv63v"
1. Beginner level
   - simple definition
   - mental model
   - why it matters

2. Intermediate level
   - practical commands
   - real behavior
   - common mistakes
   - debugging

3. Advanced / production level
   - industry standard pattern
   - real-world corporate example
   - security and reliability concerns
   - production checklist

4. Hands-on lab
5. Troubleshooting playbook
6. Interview explanation
7. Commit commands
8. Next lesson
```

Now let’s continue.

---

# Lesson 6.4 — Docker Networking

# Bridge Networks, Container DNS, Service-to-Service Communication, and Why `localhost` Behaves Differently

Docker networking is one of the most important Docker topics.

Many beginners get stuck because they think:

```text id="gmcyh3"
localhost means the same thing everywhere
```

But inside Docker:

```text id="okbzkx"
localhost inside container = that same container
localhost on host = host machine
localhost inside another container = that other container
```

This lesson will make Docker networking clear from beginner to production level.

---

# 1. Beginner Level — What Is Docker Networking?

A container is isolated.

So it needs networking to communicate with:

```text id="s52hx9"
host machine
internet
other containers
databases
APIs
reverse proxies
```

Docker creates networks to connect containers.

Check Docker networks:

```bash id="cyir4v"
docker network ls
```

Typical output:

```text id="3rp7hu"
NETWORK ID     NAME      DRIVER    SCOPE
xxxx           bridge    bridge    local
xxxx           host      host      local
xxxx           none      null      local
```

Default networks:

```text id="e99wgw"
bridge  = default isolated Docker network
host    = container shares host network
none    = no network
```

Most local Docker containers use:

```text id="1psh8f"
bridge networking
```

---

# 2. Beginner Mental Model

Think of Docker bridge network like a private LAN.

```text id="1gwm48"
Host Machine
  |
  | docker bridge
  |
  +--- container A
  +--- container B
  +--- container C
```

Containers on the same user-defined bridge network can talk to each other.

Docker’s official docs state that user-defined bridge networks provide better isolation and automatic DNS resolution between containers. ([Docker Documentation][1])

So production-style local Docker networking usually means:

```text id="284lfu"
create a user-defined bridge network
attach related containers to it
use container/service names as DNS names
publish only public entrypoints to host
```

---

# 3. Intermediate Level — Default Bridge vs User-Defined Bridge

Docker has a default network named:

```text id="pabnnu"
bridge
```

But for real application stacks, prefer your own network:

```bash id="w5h1oz"
docker network create demo-net
```

Why?

Docker’s docs explain that containers on custom networks use Docker’s embedded DNS server, while default bridge behavior is more limited. ([Docker Documentation][2])

Practical difference:

| Network                 | DNS by container name |     Isolation | Recommended for app stacks |
| ----------------------- | --------------------: | ------------: | -------------------------: |
| default `bridge`        |          weak/limited |         basic |                         no |
| user-defined bridge     |                   yes |        better |                        yes |
| Compose default network |                   yes | project-based |                        yes |

Docker Compose also creates a default network for the app, where services are reachable by service name. ([Docker Documentation][3])

Core rule:

```text id="b1eok0"
Use user-defined bridge networks for multi-container apps.
```

---

# 4. Create a User-Defined Network

Run:

```bash id="4t1toh"
docker network create demo-app-net
```

Inspect:

```bash id="u6mtop"
docker network inspect demo-app-net
```

Useful view:

```bash id="e7patq"
docker network inspect demo-app-net | jq '.[0] | {Name, Driver, Scope, IPAM, Containers}'
```

Expected:

```json id="bb7eoe"
{
  "Name": "demo-app-net",
  "Driver": "bridge",
  "Scope": "local",
  "Containers": {}
}
```

---

# 5. Run Two Containers on Same Network

Run an Nginx container:

```bash id="xdtwsi"
docker rm -f web1 client1 || true

docker run -d \
  --name web1 \
  --network demo-app-net \
  nginx:alpine
```

Run a client container:

```bash id="x369uc"
docker run -it --rm \
  --name client1 \
  --network demo-app-net \
  alpine:3.20 sh
```

Inside `client1`, install curl:

```sh id="76r5na"
apk add --no-cache curl
```

Now call Nginx by container name:

```sh id="m2mwbu"
curl -I http://web1
```

Expected:

```text id="nfk1wm"
HTTP/1.1 200 OK
```

This works because both containers are on the same user-defined bridge network and Docker DNS resolves:

```text id="dsz9sq"
web1 → web1 container IP
```

Exit:

```sh id="xfbagf"
exit
```

Clean later:

```bash id="z1p8p4"
docker rm -f web1
```

---

# 6. Intermediate Concept — Container DNS

On a user-defined bridge network, Docker provides internal DNS.

From inside container:

```sh id="q6j3qf"
cat /etc/resolv.conf
```

You will usually see Docker’s embedded DNS:

```text id="6cjfkd"
nameserver 127.0.0.11
```

Docker’s networking overview documents that containers attached to a custom network use Docker’s embedded DNS server at `127.0.0.11`. ([Docker Documentation][2])

This allows:

```text id="h4pvlv"
container name → container IP
service name → service container IP
```

In Docker Compose, this becomes even more useful:

```text id="eb4a9b"
backend can call mongodb using http://mongo:27017 or mongodb://mongo:27017
frontend can call backend using http://backend:3000
```

---

# 7. The `localhost` Problem

This is the most important Docker networking lesson.

## Case 1 — From host

On your host:

```bash id="8wbwal"
curl http://127.0.0.1:3000
```

Means:

```text id="y6zwzc"
connect to host machine port 3000
```

## Case 2 — From inside app container

Inside container:

```bash id="356hhw"
curl http://127.0.0.1:3000
```

Means:

```text id="79wfff"
connect to same container port 3000
```

## Case 3 — From backend container to database container

If backend uses:

```text id="gje0sc"
mongodb://localhost:27017
```

inside the backend container, it means:

```text id="rtk4sp"
MongoDB inside the backend container
```

But MongoDB is in another container.

Correct:

```text id="iyp9cs"
mongodb://mongo:27017
```

where `mongo` is the database container/service name.

Core rule:

```text id="2sdeh9"
Inside a container, localhost means that container, not another container and not automatically the host.
```

---

# 8. Practical Lab — Container Cannot Reach Host `localhost`

Start your Node app on the host first:

```bash id="p4qivz"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

APP_ENV=dev PORT=3000 LOG_LEVEL=info LOAD_DOTENV=false npm start
```

In another terminal, run:

```bash id="n3ztyt"
docker run --rm alpine:3.20 sh -c "apk add --no-cache curl >/dev/null && curl -s http://127.0.0.1:3000/health"
```

This will likely fail.

Why?

```text id="d7u2ag"
127.0.0.1 inside Alpine container points to Alpine container itself.
Your Node app is running on host, not inside Alpine.
```

On Docker Desktop, `host.docker.internal` often works. On Linux, add host gateway:

```bash id="hv0gt3"
docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  alpine:3.20 \
  sh -c "apk add --no-cache curl >/dev/null && curl -s http://host.docker.internal:3000/health"
```

Stop host app with:

```text id="wsun9r"
Ctrl + C
```

Production note:

```text id="r2lwgh"
Containers should usually communicate with other containers through Docker networks, not through host localhost.
```

---

# 9. Run Your Node App on a Docker Network

Build image if not already built:

```bash id="6cm0f3"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.1.9 ./scripts/docker-build.sh
```

Create network:

```bash id="g3emvc"
docker network create demo-app-net || true
```

Run app without publishing port:

```bash id="rrgfp2"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  --network demo-app-net \
  -e APP_ENV=dev \
  -e PORT=3000 \
  -e LOG_LEVEL=info \
  demo-node-api:0.1.9
```

Notice:

```text id="o6xag8"
No -p 3000:3000
```

So host cannot access it directly:

```bash id="jo2txh"
curl -s http://127.0.0.1:3000/health
```

But another container on the same network can:

```bash id="8j23v8"
docker run --rm \
  --network demo-app-net \
  alpine:3.20 \
  sh -c "apk add --no-cache curl >/dev/null && curl -s http://demo-node-api:3000/health"
```

Expected:

```json id="w4i7x7"
{
  "status": "ok",
  "app": "demo-node-api",
  "environment": "dev"
}
```

This is real service-to-service communication.

Clean:

```bash id="2z0o00"
docker rm -f demo-node-api
```

---

# 10. Public vs Internal Containers

A production-style Docker stack usually has:

```text id="8fn2f0"
public container:
  nginx / reverse proxy
  publishes host port 80/443

internal containers:
  backend API
  database
  redis
  worker
  no host port published
```

Example:

```text id="5ik2my"
Host port 8080
  ↓
nginx container
  ↓ Docker network
demo-node-api container :3000
```

Only Nginx gets:

```bash id="42a7mp"
-p 8080:80
```

Backend does not get `-p`.

Core production rule:

```text id="wk7dqw"
Publish only what must be reached from outside Docker. Keep internal services private on Docker networks.
```

---

# 11. Advanced Lab — Nginx Container Reverse Proxy to Node Container

Create a Docker Nginx config locally.

Go to Module 6:

```bash id="uvbnj2"
cd ~/devops-masterclass/06-docker-containers
mkdir -p docker-networking/nginx
cd docker-networking
```

Create Nginx config:

```bash id="3osv60"
nano nginx/default.conf
```

Paste:

```nginx id="rbzdip"
server {
    listen 80;

    location = /nginx-health {
        access_log off;
        return 200 "nginx ok\n";
    }

    location / {
        proxy_pass http://demo-node-api:3000;

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

Create network:

```bash id="s8meeg"
docker network create demo-app-net || true
```

Run backend internal only:

```bash id="1bdq0q"
docker rm -f demo-node-api demo-nginx || true

docker run -d \
  --name demo-node-api \
  --network demo-app-net \
  -e APP_ENV=dev \
  -e PORT=3000 \
  -e LOG_LEVEL=info \
  demo-node-api:0.1.9
```

Run Nginx public:

```bash id="xjcm3h"
docker run -d \
  --name demo-nginx \
  --network demo-app-net \
  -p 8080:80 \
  -v "$PWD/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro" \
  nginx:alpine
```

Test through Nginx:

```bash id="5z3i7q"
curl -i http://127.0.0.1:8080/nginx-health
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
```

Check containers:

```bash id="a7u4yb"
docker ps
docker logs demo-nginx --tail 20
docker logs demo-node-api --tail 20
```

This is now production-like:

```text id="4nejk2"
host → nginx container → backend container
```

Clean later:

```bash id="yjy4zw"
docker rm -f demo-nginx demo-node-api
```

---

# 12. Advanced Concept — Docker Network Drivers

Important Docker network drivers:

| Driver  | Meaning                                      | Common use                        |
| ------- | -------------------------------------------- | --------------------------------- |
| bridge  | private network on one Docker host           | local apps, Compose               |
| host    | container shares host network namespace      | special performance/network cases |
| none    | no network                                   | highly isolated jobs              |
| overlay | multi-host networking                        | Swarm / distributed systems       |
| macvlan | container appears as physical network device | advanced LAN integration          |

Docker docs describe user-defined bridge networks as local single-host networks, while multi-host networking requires overlay networks, such as in Swarm mode. ([Docker Documentation][4])

For now, your main focus:

```text id="rlkxfg"
bridge
user-defined bridge
Compose default bridge network
```

---

# 13. Host Network Mode

Run:

```bash id="gx4v5o"
docker run --rm --network host alpine:3.20 ip addr
```

In host mode:

```text id="i56idb"
container uses host network directly
no port publishing needed
less network isolation
not portable the same way on all platforms
```

Use host mode only when justified:

```text id="aql0zz"
high-performance networking
special monitoring agents
network troubleshooting
some local development cases
```

Production caution:

```text id="o24p5s"
Host networking reduces isolation. Do not use casually.
```

---

# 14. None Network Mode

Run:

```bash id="l9m1fl"
docker run --rm --network none alpine:3.20 ip addr
```

You will see only loopback.

This is useful for:

```text id="9z65xt"
offline jobs
security-restricted processing
build/test cases that need no network
```

---

# 15. Intermediate Debugging Commands

List networks:

```bash id="c87a2r"
docker network ls
```

Inspect network:

```bash id="31krv0"
docker network inspect demo-app-net
```

Show containers on network:

```bash id="vt0vz3"
docker network inspect demo-app-net | jq '.[0].Containers'
```

Inspect container network settings:

```bash id="lbk96w"
docker inspect demo-node-api | jq '.[0].NetworkSettings.Networks'
```

Enter container:

```bash id="gtmpj6"
docker exec -it demo-node-api sh
```

Inside:

```sh id="tc0vi7"
hostname
ip addr
cat /etc/resolv.conf
wget -qO- http://127.0.0.1:3000/health
exit
```

Test DNS from client:

```bash id="ubrs52"
docker run --rm \
  --network demo-app-net \
  alpine:3.20 \
  sh -c "apk add --no-cache bind-tools >/dev/null && nslookup demo-node-api"
```

Test HTTP:

```bash id="lsc2jz"
docker run --rm \
  --network demo-app-net \
  alpine:3.20 \
  sh -c "apk add --no-cache curl >/dev/null && curl -i http://demo-node-api:3000/health"
```

---

# 16. Corporate / Real-World Example

Imagine a company has this stack:

```text id="p7fvn6"
customer-frontend
order-api
payment-api
postgres
redis
nginx
```

Production-style container networking:

```text id="l5bl43"
public:
  nginx publishes 80/443

private app network:
  nginx → customer-frontend
  nginx → order-api
  order-api → postgres
  order-api → redis
  order-api → payment-api
```

Only Nginx is public.

Databases do not publish host ports.

Bad corporate setup:

```text id="d2kdcw"
postgres published to 0.0.0.0:5432
redis published to 0.0.0.0:6379
backend connects to localhost
everything on default bridge
```

Better:

```text id="gm4k2y"
services use user-defined networks
internal services use DNS names
only reverse proxy exposes public ports
secrets injected at runtime
network separation by app/domain
```

---

# 17. Advanced Production Network Standards

For production-grade Docker/Compose stacks:

```text id="vsykw2"
use user-defined networks
separate public and private networks
publish only reverse proxy ports
do not publish database ports unless required
use service names for internal communication
avoid hardcoded container IPs
avoid host network unless justified
apply firewall/security group rules
document network flow
use TLS at public edge
use health checks
monitor logs and metrics
```

Example architecture:

```text id="qf3gji"
Internet
  ↓
Nginx / Traefik / Caddy
  ↓ public Docker network
Backend API
  ↓ private Docker network
Database / Redis
```

In Compose later, this will become:

```yaml id="9e86vj"
networks:
  public:
  private:
```

Then services attach only to the networks they need.

---

# 18. Create Lesson Notes

Create:

```bash id="lbgq9h"
cd ~/devops-masterclass/06-docker-containers
nano docker-networking.md
```

Paste:

````markdown id="63gw09"
# Docker Networking

## Beginner

Docker networking allows containers to communicate with:

- host
- internet
- other containers
- databases
- reverse proxies

Common networks:

```bash
docker network ls
````

Default drivers:

* bridge
* host
* none

## Intermediate

Use user-defined bridge networks for application stacks:

```bash
docker network create demo-app-net
```

Run containers:

```bash
docker run -d --name backend --network demo-app-net backend-image
docker run --rm --network demo-app-net alpine sh
```

Inside same network:

```bash
curl http://backend:3000/health
```

## Localhost Rule

Inside a container:

```text
localhost = same container
```

Not the host, not another container.

Use service/container names on user-defined networks.

## Advanced Production Rules

* publish only public entrypoints
* keep backend/database internal
* use user-defined networks
* use DNS names, not container IPs
* avoid host networking unless justified
* separate public/private networks
* do not expose databases publicly
* document network flow

## Debug Commands

```bash
docker network ls
docker network inspect demo-app-net
docker inspect container | jq '.[0].NetworkSettings.Networks'
docker exec -it container sh
cat /etc/resolv.conf
ip addr
nslookup service-name
curl -i http://service-name:port/health
```

````

---

# 19. Create Practical Lab Script

Go to Module 6:

```bash id="21hpj9"
cd ~/devops-masterclass/06-docker-containers
mkdir -p scripts
nano scripts/docker-networking-lab.sh
````

Paste:

```bash id="gg0twf"
#!/usr/bin/env bash
set -euo pipefail

NETWORK_NAME="${NETWORK_NAME:-demo-app-net}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-0.1.9}"

echo "===== Docker Networking Lab ====="

echo
echo "1. Creating network..."
docker network create "$NETWORK_NAME" >/dev/null 2>&1 || true

echo
echo "2. Cleaning old containers..."
docker rm -f demo-node-api demo-nginx >/dev/null 2>&1 || true

echo
echo "3. Running backend internally..."
docker run -d \
  --name demo-node-api \
  --network "$NETWORK_NAME" \
  -e APP_ENV=dev \
  -e PORT=3000 \
  -e LOG_LEVEL=info \
  "$IMAGE_NAME:$IMAGE_TAG"

echo
echo "4. Testing backend from another container..."
docker run --rm \
  --network "$NETWORK_NAME" \
  alpine:3.20 \
  sh -c "apk add --no-cache curl >/dev/null && curl -s http://demo-node-api:3000/health"

echo
echo
echo "5. Network containers:"
docker network inspect "$NETWORK_NAME" | jq '.[0].Containers'

echo
echo "Lab completed."
```

Make executable:

```bash id="zq2951"
chmod +x scripts/docker-networking-lab.sh
```

Run after building image:

```bash id="afsixt"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION=0.1.9 ./scripts/docker-build.sh

cd ~/devops-masterclass/06-docker-containers
IMAGE_TAG=0.1.9 ./scripts/docker-networking-lab.sh
```

Clean:

```bash id="rmmglr"
docker rm -f demo-node-api demo-nginx || true
docker network rm demo-app-net || true
```

---

# 20. Troubleshooting Playbook

## Problem 1 — Container cannot reach another container by name

Check network:

```bash id="bqqfkq"
docker inspect container1 | jq '.[0].NetworkSettings.Networks'
docker inspect container2 | jq '.[0].NetworkSettings.Networks'
```

They must share a network.

Fix:

```bash id="f47evx"
docker network connect demo-app-net container1
docker network connect demo-app-net container2
```

Better: recreate containers with `--network demo-app-net`.

---

## Problem 2 — Host cannot reach container

Check port publishing:

```bash id="ke5wks"
docker port demo-node-api
docker ps
```

If no port mapping exists, run with:

```bash id="b09dlv"
-p 3000:3000
```

Remember:

```text id="a6xcye"
EXPOSE does not publish. -p publishes.
```

---

## Problem 3 — Backend uses `localhost` for database

Bad:

```text id="59t7yw"
DATABASE_URL=mongodb://localhost:27017/app
```

Correct in Docker network:

```text id="q3skg4"
DATABASE_URL=mongodb://mongo:27017/app
```

---

## Problem 4 — Nginx gives 502

Check backend container:

```bash id="vu4bul"
docker ps
docker logs demo-node-api --tail 100
```

Check Nginx config:

```bash id="ma3evs"
docker exec demo-nginx nginx -t
docker logs demo-nginx --tail 100
```

Check DNS:

```bash id="t7nlrq"
docker exec -it demo-nginx sh
```

Inside:

```sh id="a25zdd"
wget -qO- http://demo-node-api:3000/health
exit
```

---

## Problem 5 — Using container IPs

Bad:

```text id="ny3493"
http://172.18.0.3:3000
```

Why bad?

```text id="fsg7a3"
container IP can change when container is recreated
```

Correct:

```text id="fqbdwb"
http://demo-node-api:3000
```

---

# 21. Commit Work

Run:

```bash id="l5rr6d"
cd ~/devops-masterclass

git status
git add 06-docker-containers
git commit -m "feat: add Docker networking fundamentals"
git push
```

---

# 22. Interview Explanation

Question:

```text id="bwo0ls"
Why does localhost behave differently inside containers?
```

Strong answer:

```text id="0jz1u5"
Each container has its own network namespace. Inside a container, localhost refers to that container itself, not the host machine and not another container. To communicate between containers, they should be attached to the same Docker network and use container or service names as DNS names.
```

Question:

```text id="g4cfvn"
Why use a user-defined bridge network?
```

Strong answer:

```text id="tzwig5"
A user-defined bridge network gives better isolation and built-in DNS-based service discovery between containers on the same Docker host. Containers can communicate using names instead of dynamic IP addresses, which is much better for application stacks.
```

Question:

```text id="kqsf3j"
Should databases publish ports to the host?
```

Strong answer:

```text id="7izwke"
Usually no. In production-style Docker stacks, databases should stay on private Docker networks and be reachable only by services that need them. Only public entrypoints like Nginx or an API gateway should publish host ports unless there is a specific operational reason.
```

Question:

```text id="668m75"
How do you debug container networking?
```

Strong answer:

```text id="c0w5uq"
I check whether containers are on the same network using docker inspect or docker network inspect. Then I test DNS resolution and connectivity from inside a container using nslookup, wget, or curl. I also check port publishing with docker ps and docker port, and inspect application logs for connection errors.
```

---

# Today’s Core Rules

```text id="05fdfe"
Use user-defined bridge networks.
Containers on same user-defined network can use DNS names.
Inside container, localhost means same container.
Use service/container names, not container IPs.
Publish only public ports.
Keep databases internal.
EXPOSE documents; -p publishes.
Avoid host networking unless justified.
Use docker network inspect for debugging.
Nginx/reverse proxy should be public; backend should be private.
```

Next lesson:

# Lesson 6.5 — Docker Compose: multi-container apps, service names, env files, volumes, networks, and production-style Compose structure.

[1]: https://docs.docker.com/engine/network/drivers/bridge/?utm_source=chatgpt.com "Bridge network driver"
[2]: https://docs.docker.com/engine/network/?utm_source=chatgpt.com "Networking overview"
[3]: https://docs.docker.com/compose/how-tos/networking/?utm_source=chatgpt.com "Networking in Compose"
[4]: https://docs.docker.com/reference/cli/docker/network/create/?utm_source=chatgpt.com "docker network create"
