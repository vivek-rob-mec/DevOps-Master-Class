# Lesson 6.11 — Docker Troubleshooting Masterclass

# Build Failures, Container Exits, Networking Issues, Volume Problems, Compose Debugging, Pull Errors, Performance Problems, and Incident Playbooks

This lesson is very important.

A real DevOps engineer is not only someone who writes Dockerfiles.

A real DevOps engineer can debug:

```text id="l7jm4g"
why image build failed
why container exited
why app is not reachable
why Nginx gives 502
why database data disappeared
why Docker Compose is unhealthy
why image pull failed
why disk is full
why container uses too much memory
why deployment failed
```

Today we will build your Docker troubleshooting muscle.

---

# 1. Beginner Level — Docker Troubleshooting Mental Model

When something fails, do not randomly restart everything.

Use a flow:

```text id="7kgiv7"
1. Is the image built?
2. Is the container running?
3. Did the process exit?
4. What do logs say?
5. Is the port published?
6. Is the network correct?
7. Is the config/env correct?
8. Are volumes mounted correctly?
9. Are permissions correct?
10. Are resources enough?
```

Basic Docker debugging commands:

```bash id="nzjt2z"
docker ps
docker ps -a
docker logs <container>
docker inspect <container>
docker exec -it <container> sh
docker images
docker network ls
docker volume ls
docker stats
```

Compose debugging commands:

```bash id="p40t0c"
docker compose ps
docker compose logs
docker compose logs backend
docker compose config
docker compose exec backend sh
docker compose down
docker compose up -d
```

Core rule:

```text id="bh97bm"
Logs first. Inspect second. Restart last.
```

---

# 2. Beginner Problem — Container Exits Immediately

Example:

```bash id="omccum"
docker run --name exit-demo alpine:3.20 echo "hello"
```

Check:

```bash id="t1uc7w"
docker ps
docker ps -a
```

You will see the container exited.

Why?

```text id="rkd8o3"
The main process was echo.
echo finished.
Container stopped.
```

A container lives as long as its main process lives.

Check logs:

```bash id="dyusqs"
docker logs exit-demo
```

Expected:

```text id="gqwvaj"
hello
```

Clean:

```bash id="nyqd7p"
docker rm exit-demo
```

Interview answer:

```text id="u21gz6"
If a container exits immediately, I check docker ps -a and docker logs. Usually the main process finished or crashed. Containers are tied to their main process.
```

---

# 3. Beginner Problem — Container Name Already Exists

Run:

```bash id="5b5tdn"
docker run --name name-demo alpine:3.20 echo one
docker run --name name-demo alpine:3.20 echo two
```

You will get:

```text id="78cntn"
Conflict. The container name is already in use.
```

Fix:

```bash id="epdtk7"
docker rm name-demo
```

Or force remove:

```bash id="wf8tig"
docker rm -f name-demo
```

Production caution:

```text id="3mlif7"
Do not blindly docker rm -f production containers unless you know what owns them.
Use Compose/system orchestrator commands instead.
```

For Compose:

```bash id="yfopqe"
docker compose ps
docker compose down
docker compose up -d
```

---

# 4. Intermediate Problem — Build Fails Because `package-lock.json` Missing

If your Dockerfile uses:

```Dockerfile id="y6kfwe"
RUN npm ci --omit=dev
```

but `package-lock.json` is missing, build fails.

Check:

```bash id="kiknde"
ls package.json package-lock.json
```

Fix:

```bash id="rcgv7z"
npm install
```

This creates `package-lock.json`.

Then:

```bash id="u8ypj7"
docker build -f Dockerfile.industry -t demo-node-api:debug .
```

Core rule:

```text id="s7k4b4"
npm ci requires package-lock.json and expects it to match package.json.
```

---

# 5. Intermediate Problem — Build Context Too Large

Symptom:

```text id="8htjts"
docker build takes long before first step
Sending build context is huge
```

Check files:

```bash id="6mp9rm"
du -sh .
find . -maxdepth 2 -type d -name node_modules -o -name .git
```

Check `.dockerignore`:

```bash id="i81rk3"
cat .dockerignore
```

Fix `.dockerignore`:

```dockerignore id="ewd5r7"
node_modules
.git
.env
.env.*
coverage
reports
*.log
backups
```

Rebuild with plain output:

```bash id="bzof2w"
DOCKER_BUILDKIT=1 docker build --progress=plain -f Dockerfile.industry -t demo-node-api:debug .
```

Core rule:

```text id="2r1ewz"
Large build context usually means .dockerignore is missing or weak.
```

---

# 6. Intermediate Problem — Docker Cache Confusion

Sometimes you change code but Docker seems to use old layers.

Build with no cache:

```bash id="4y2p26"
docker build --no-cache -f Dockerfile.industry -t demo-node-api:no-cache .
```

Build with plain logs:

```bash id="2jb5r8"
DOCKER_BUILDKIT=1 docker build --progress=plain -f Dockerfile.industry -t demo-node-api:plain .
```

Look for:

```text id="p35rx5"
CACHED
COPY step invalidation
npm ci running again
```

Inspect image build history:

```bash id="3e0ae9"
docker history demo-node-api:debug
```

Professional rule:

```text id="60t812"
Use cache for speed, but use --no-cache when debugging suspicious builds.
```

---

# 7. Intermediate Problem — App Not Reachable from Host

Run app without port publishing:

```bash id="8rn1zr"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  -e APP_ENV=dev \
  demo-node-api:0.2.0
```

Try:

```bash id="duwnb2"
curl http://127.0.0.1:3000/health
```

It fails.

Check:

```bash id="scn0b1"
docker ps
docker port demo-node-api
```

No published port.

Fix:

```bash id="0gkd2h"
docker rm -f demo-node-api

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  demo-node-api:0.2.0
```

Test:

```bash id="ksna3p"
curl -s http://127.0.0.1:3000/health | jq .
```

Core rule:

```text id="591kvb"
EXPOSE documents ports. -p publishes ports.
```

Clean:

```bash id="gumgf1"
docker rm -f demo-node-api
```

---

# 8. Intermediate Problem — Wrong Port Mapping

Bad:

```bash id="l1nm5z"
docker run -d \
  --name demo-node-api \
  -p 3000:80 \
  -e APP_ENV=dev \
  demo-node-api:0.2.0
```

Your app listens inside container on `3000`, but you mapped host 3000 to container 80.

Check:

```bash id="k4dbxq"
docker port demo-node-api
docker logs demo-node-api
```

Fix:

```bash id="md8em0"
docker rm -f demo-node-api

docker run -d \
  --name demo-node-api \
  -p 3000:3000 \
  -e APP_ENV=dev \
  demo-node-api:0.2.0
```

Core rule:

```text id="v9a55w"
-p HOST_PORT:CONTAINER_PORT
```

---

# 9. Intermediate Problem — `localhost` Inside Container

If backend container tries:

```text id="e9vi9l"
mongodb://localhost:27017/demo
```

it means:

```text id="7e7l9a"
MongoDB inside the backend container
```

Correct in Compose:

```text id="ou2ng0"
mongodb://mongo:27017/demo
```

Debug from backend:

```bash id="sdwo3v"
cd ~/devops-masterclass/06-docker-containers/compose-demo
docker compose exec backend sh
```

Inside:

```sh id="ys3noc"
cat /etc/resolv.conf
wget -qO- http://127.0.0.1:3000/health
exit
```

Debug from temporary container:

```bash id="h3s8gx"
docker run --rm \
  --network compose-demo_private_net \
  alpine:3.20 \
  sh -c "apk add --no-cache bind-tools >/dev/null && nslookup mongo"
```

Core rule:

```text id="sy2dvi"
Inside a container, localhost means the same container.
```

---

# 10. Professional Problem — Nginx 502 Bad Gateway

Nginx 502 usually means:

```text id="ex611z"
Nginx cannot reach upstream backend
backend is down
wrong upstream hostname
wrong port
network mismatch
backend not ready
```

Check Compose:

```bash id="amvkfo"
cd ~/devops-masterclass/06-docker-containers/compose-demo

docker compose ps
docker compose logs nginx --tail 100
docker compose logs backend --tail 100
```

Check Nginx config:

```bash id="6xl9m6"
docker compose exec nginx nginx -t
```

Test upstream from inside Nginx:

```bash id="bxq1aw"
docker compose exec nginx sh
```

Inside:

```sh id="4h5kyr"
wget -qO- http://backend:3000/health
exit
```

If this fails, check networks:

```bash id="1hyygq"
docker network inspect compose-demo_public_net | jq '.[0].Containers'
docker network inspect compose-demo_private_net | jq '.[0].Containers'
```

Expected:

```text id="rrw7wc"
nginx and backend share public_net
backend and mongo share private_net
```

Fix common Nginx upstream:

```nginx id="o085o9"
proxy_pass http://backend:3000;
```

Not:

```nginx id="94dhv1"
proxy_pass http://localhost:3000;
```

---

# 11. Professional Problem — Compose Service Unhealthy

Check:

```bash id="ldz84e"
docker compose ps
```

If backend is unhealthy:

```bash id="ujismh"
docker inspect compose-demo-backend --format '{{json .State.Health}}' | jq .
```

Look at healthcheck output:

```bash id="k4ybfh"
docker inspect compose-demo-backend | jq '.[0].State.Health.Log'
```

Check logs:

```bash id="c24jiu"
docker compose logs backend --tail 100
```

Common causes:

```text id="66npoz"
wrong healthcheck URL
app starts slowly
readiness dependency missing
DATABASE_URL missing in prod
secret file not mounted
container cannot write to required path
```

Test manually:

```bash id="kcxknf"
docker compose exec backend wget -qO- http://127.0.0.1:3000/ready
```

If `/health` passes but `/ready` fails:

```text id="054a66"
process is alive but app is not ready
```

That is exactly why readiness exists.

---

# 12. Professional Problem — Secret File Missing

Symptom:

```text id="jmv6yo"
DATABASE_URL_FILE points to file that cannot be read
```

Check secrets in Compose config:

```bash id="ze73ua"
docker compose config | grep -A20 secrets
```

Check inside backend:

```bash id="e9uwzf"
docker compose exec backend ls -l /run/secrets
```

Check env:

```bash id="8xnp9i"
docker compose exec backend env | grep DATABASE_URL
```

Expected:

```text id="id8o0a"
DATABASE_URL_FILE=/run/secrets/backend_database_url
```

Fix:

```text id="4tq2ja"
secret file exists on host
top-level secrets section exists
backend service references the secret
.env/backend.env points to correct _FILE path
```

Host check:

```bash id="zkteay"
ls -l secrets
```

Do not print secret values in shared logs.

---

# 13. Professional Problem — Volume Data Disappeared

First question:

```text id="5vdpey"
Did someone run docker compose down -v?
```

Check volumes:

```bash id="lqe2t8"
docker volume ls | grep compose-demo
```

Inspect:

```bash id="75i9d4"
docker volume inspect compose-demo_mongo_data
```

Check Compose volume name:

```bash id="cvp2r0"
docker compose config | grep -A10 volumes
```

If volume was removed and no backup exists:

```text id="pznsax"
data recovery may not be possible
```

Restore if backup exists:

```bash id="gcv8wh"
cd ~/devops-masterclass/06-docker-containers/compose-demo

docker compose down
./scripts/restore-mongo-volume.sh backups/<backup-file>.tar.gz
docker compose up -d
```

Professional rule:

```text id="z7qo9e"
Persistence is not backup. Always test restore.
```

---

# 14. Professional Problem — Permission Denied on Bind Mount

Symptom:

```text id="92irfv"
EACCES
permission denied
cannot write file
```

Check container user:

```bash id="tfbybk"
docker compose exec backend id
```

Check mount:

```bash id="ytwvrj"
docker inspect compose-demo-backend | jq '.[0].Mounts'
```

Check host permissions:

```bash id="1qvzed"
ls -ld /host/path
ls -l /host/path
```

Fix with correct ownership:

```bash id="69m50w"
sudo chown -R <uid>:<gid> /host/path
```

Avoid:

```bash id="5p7kbb"
sudo chmod -R 777 /host/path
```

unless it is a disposable lab.

Production rule:

```text id="9eg0np"
Fix ownership and user mapping. Do not use chmod 777 as a production solution.
```

---

# 15. Expert Problem — Container Killed by OOM

Symptoms:

```text id="hhnh4z"
container exits
ExitCode 137
OOMKilled true
```

Check:

```bash id="ncn8op"
docker inspect compose-demo-backend | jq '.[0].State | {Status, ExitCode, OOMKilled, Error}'
```

Check memory limit:

```bash id="pyzleh"
docker inspect compose-demo-backend --format '{{.HostConfig.Memory}}'
```

Check stats:

```bash id="h4gxkn"
docker stats
```

Possible causes:

```text id="kc7s14"
memory leak
memory limit too low
large request payload
bad dependency behavior
too many concurrent requests
Node heap not tuned
```

For Node.js, you may set:

```bash id="eewcqd"
NODE_OPTIONS=--max-old-space-size=192
```

if container memory limit is 256 MB.

Compose:

```yaml id="b58qpl"
environment:
  NODE_OPTIONS: "--max-old-space-size=192"
mem_limit: 256m
```

Expert rule:

```text id="ms5d2m"
Memory limit and application runtime memory settings should be aligned.
```

---

# 16. Expert Problem — Disk Full Because Docker Logs or Images

Check disk:

```bash id="sgcj0t"
df -h
docker system df
```

Find large Docker directories:

```bash id="c2qk69"
sudo du -sh /var/lib/docker/* 2>/dev/null | sort -h
```

Check container logs:

```bash id="yc2z7s"
docker inspect compose-demo-backend --format '{{.LogPath}}'
sudo ls -lh "$(docker inspect compose-demo-backend --format '{{.LogPath}}')"
```

Fix logging in Compose:

```yaml id="pudbcb"
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Clean unused resources carefully:

```bash id="sr4j0x"
docker system df
docker image prune
docker container prune
docker builder prune
```

Dangerous:

```bash id="56695b"
docker system prune -a --volumes
```

This can delete images and volumes.

Professional rule:

```text id="rnhvw4"
Never run prune with --volumes on production unless you have confirmed what will be deleted.
```

---

# 17. Expert Problem — Image Pull Fails

Error examples:

```text id="7a5tjw"
pull access denied
unauthorized
manifest unknown
repository does not exist
TLS handshake timeout
no space left on device
```

Debug:

```bash id="j1t0hg"
docker pull ghcr.io/YOUR_USER/demo-node-api:TAG
docker login ghcr.io
docker system df
df -h
```

For ECR:

```bash id="s5bwj9"
aws sts get-caller-identity
aws ecr describe-repositories --repository-names demo-node-api --region ap-south-1

aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com
```

If tag missing:

```text id="zms8lb"
CI may not have pushed it
wrong registry
wrong namespace
wrong tag
image lifecycle policy deleted it
```

Professional rule:

```text id="7pn0tm"
Deployment should fail early if the exact image tag cannot be pulled.
```

---

# 18. Expert Problem — Compose Config Is Not What You Think

Rendered Compose config may differ from what you expect because of:

```text id="ao2lrl"
.env substitution
compose.override.yaml auto-merge
multiple -f files
profiles
YAML indentation
duplicate keys
```

Always inspect rendered config:

```bash id="w8hfzd"
docker compose config
docker compose -f compose.yaml -f compose.prod.yaml config
```

Save it:

```bash id="c48xdy"
docker compose -f compose.yaml -f compose.prod.yaml config > /tmp/rendered-compose.yaml
```

Check image:

```bash id="jp97tg"
grep -n "image:" /tmp/rendered-compose.yaml
```

Check ports:

```bash id="bc6qxn"
grep -n "published:" /tmp/rendered-compose.yaml
```

Check secrets:

```bash id="sl7gk7"
grep -n "secrets:" -A20 /tmp/rendered-compose.yaml
```

Core rule:

```text id="7x9f39"
When debugging Compose, always check rendered config.
```

---

# 19. Expert Problem — Deployment Failed But No Rollback

Check deployment report:

```bash id="ikffxc"
cd ~/devops-masterclass/06-docker-containers/compose-demo

ls -lh deployment-records
cat "$(ls -t deployment-records/deploy-*.json | head -n 1)" | jq .
```

Check previous version in `.env` before deployment.

If previous image was not available in registry:

```text id="uijgd7"
rollback cannot pull previous image
```

Check:

```bash id="ixq6qe"
docker images | grep demo-node-api
```

Professional rule:

```text id="60ml9l"
Rollback depends on previous artifact availability.
Do not delete old images too aggressively.
```

---

# 20. Expert Incident-Style Triage Flow

When production is down:

```text id="n1p3pe"
1. Confirm impact.
2. Check public endpoint.
3. Check reverse proxy.
4. Check backend health.
5. Check recent deployment.
6. Check logs.
7. Check resource usage.
8. Rollback if deployment-related.
9. Preserve evidence.
10. Write incident notes.
```

Commands:

```bash id="g0ruwq"
curl -i http://127.0.0.1:8080/health
curl -i http://127.0.0.1:8080/ready

docker compose -f compose.yaml -f compose.prod.yaml ps
docker compose -f compose.yaml -f compose.prod.yaml logs --tail 200

docker stats --no-stream
docker system df
df -h

cat "$(ls -t deployment-records/deploy-*.json | head -n 1)" | jq .
```

Decision:

```text id="rvnrf2"
If issue started after deployment and old version was healthy, rollback first.
Debug deeply after service is restored.
```

SRE principle:

```text id="5xo8kr"
Restore service first. Root cause analysis second.
```

---

# 21. Create Troubleshooting Script

Create:

```bash id="73e5xw"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano scripts/diagnose-compose.sh
```

Paste:

```bash id="t9x0o7"
#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080/health}"
READY_URL="${READY_URL:-http://127.0.0.1:8080/ready}"

compose_args=()
for file in $COMPOSE_FILES; do
  compose_args+=("-f" "$file")
done

echo "===== Compose Diagnostics ====="
echo "Time: $(date -Iseconds)"
echo "Compose files: $COMPOSE_FILES"

echo
echo "1. Docker version:"
docker version --format '{{.Server.Version}}' || true

echo
echo "2. Docker disk usage:"
docker system df || true

echo
echo "3. Host disk:"
df -h || true

echo
echo "4. Rendered compose config image lines:"
docker compose "${compose_args[@]}" config | grep -n "image:" || true

echo
echo "5. Compose services:"
docker compose "${compose_args[@]}" ps || true

echo
echo "6. Public endpoint checks:"
curl -i --max-time 5 "$HEALTH_URL" || true
echo
curl -i --max-time 5 "$READY_URL" || true
echo

echo
echo "7. Backend health details:"
docker inspect compose-demo-backend --format '{{json .State.Health}}' 2>/dev/null | jq . || true

echo
echo "8. Backend state:"
docker inspect compose-demo-backend --format '{{json .State}}' 2>/dev/null | jq . || true

echo
echo "9. Recent backend logs:"
docker compose "${compose_args[@]}" logs --tail 80 backend || true

echo
echo "10. Recent nginx logs:"
docker compose "${compose_args[@]}" logs --tail 80 nginx || true

echo
echo "11. Recent mongo logs:"
docker compose "${compose_args[@]}" logs --tail 80 mongo || true

echo
echo "12. Networks:"
docker network ls | grep compose-demo || true

echo
echo "13. Volumes:"
docker volume ls | grep compose-demo || true

echo
echo "14. Latest deployment report:"
if ls deployment-records/deploy-*.json >/dev/null 2>&1; then
  cat "$(ls -t deployment-records/deploy-*.json | head -n 1)" | jq .
else
  echo "No deployment report found."
fi

echo
echo "Diagnostics completed."
```

Make executable:

```bash id="zsacuy"
chmod +x scripts/diagnose-compose.sh
```

Run:

```bash id="5z269t"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/diagnose-compose.sh
```

This is a practical incident tool.

---

# 22. Create Troubleshooting Notes

Create:

```bash id="hjogn6"
cd ~/devops-masterclass/06-docker-containers
nano docker-troubleshooting-masterclass.md
```

Paste:

````markdown id="72drba"
# Docker Troubleshooting Masterclass

## Core Flow

1. Check container status.
2. Check logs.
3. Check config.
4. Check network.
5. Check volumes.
6. Check resources.
7. Check deployment report.
8. Rollback if deployment-related.

## Basic Commands

```bash
docker ps
docker ps -a
docker logs container
docker inspect container
docker exec -it container sh
docker stats
docker system df
````

## Compose Commands

```bash id="rjvop0"
docker compose ps
docker compose logs --tail 100
docker compose config
docker compose exec backend sh
```

## Common Issues

### Container exited

```bash
docker ps -a
docker logs container
docker inspect container | jq '.[0].State'
```

### Port not reachable

```bash id="h9klbm"
docker port container
docker ps
```

### Nginx 502

```bash id="beq0v3"
docker compose logs nginx
docker compose logs backend
docker compose exec nginx wget -qO- http://backend:3000/health
```

### Volume issue

```bash id="8fqnog"
docker volume ls
docker volume inspect volume
docker compose config | grep -A10 volumes
```

### OOM kill

```bash id="22e100"
docker inspect container | jq '.[0].State | {ExitCode, OOMKilled}'
docker stats
```

### Disk full

```bash id="m5l6dk"
df -h
docker system df
docker image prune
docker builder prune
```

## SRE Rule

Restore service first. Root cause analysis second.

````id="zn5b3a"

---

# 23. Add Makefile Diagnostics Target

Open:

```bash id="or6isw"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano Makefile
````

Add:

```Makefile id="5i7fqp"
.PHONY: diagnose disk stats

diagnose:
	COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/diagnose-compose.sh

disk:
	df -h
	docker system df

stats:
	docker stats
```

Run:

```bash id="dpk4y6"
make diagnose
make disk
```

---

# 24. Hands-On Break/Fix Labs

## Lab 1 — Break Nginx upstream

Edit:

```bash id="zzq0a2"
nano nginx/default.conf
```

Change:

```nginx id="ph1ti7"
proxy_pass http://backend:3000;
```

to:

```nginx id="v9ovob"
proxy_pass http://wrong-backend:3000;
```

Restart:

```bash id="3yufgh"
docker compose -f compose.yaml -f compose.prod.yaml up -d --force-recreate nginx
```

Test:

```bash id="2mjmkd"
curl -i http://127.0.0.1:8080/health
```

Diagnose:

```bash id="swleg6"
make diagnose
docker compose logs nginx --tail 50
```

Fix config back:

```nginx id="xer28t"
proxy_pass http://backend:3000;
```

Restart:

```bash id="nyobdp"
docker compose -f compose.yaml -f compose.prod.yaml up -d --force-recreate nginx
```

---

## Lab 2 — Break backend image

Use broken image from previous lesson:

```bash id="1xfkwh"
APP_IMAGE=demo-node-api \
APP_VERSION=0.2.0-broken \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
AUTO_ROLLBACK=true \
./scripts/deploy-compose.sh || true
```

Check report:

```bash id="16td4m"
make show-report
```

---

## Lab 3 — Break secret mount

Temporarily move secret:

```bash id="ll17pr"
mv secrets/backend_database_url.txt secrets/backend_database_url.txt.bak
```

Deploy:

```bash id="p4c060"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh || true
```

Diagnose:

```bash id="2ohnax"
make diagnose
```

Restore:

```bash id="ty7osy"
mv secrets/backend_database_url.txt.bak secrets/backend_database_url.txt
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

---

# 25. Professional Troubleshooting Checklist

Use this when something fails:

```text id="qb95x2"
What changed recently?
Which service is unhealthy?
Is the public endpoint failing?
Is Nginx reachable?
Can Nginx reach backend?
Is backend healthy locally?
Can backend resolve dependencies?
Are secrets mounted?
Are env vars correct?
Are volumes present?
Is disk full?
Was the container OOMKilled?
Was a new image deployed?
Can rollback restore service?
```

---

# 26. Interview Explanation

## A container keeps restarting. What do you check?

Strong answer:

```text id="l0wtux"
I check docker ps -a or docker compose ps to see the status and exit code. Then I check docker logs for the container, inspect the state for OOMKilled or exit code, verify required environment variables and secrets, and test whether the main process is crashing. If it is Compose-managed, I check the rendered compose config and recent deployment changes.
```

## Nginx returns 502. How do you debug?

Strong answer:

```text id="u0gkkj"
A 502 usually means Nginx cannot reach the upstream. I check Nginx logs, backend logs, and whether both containers share the correct network. Then I exec into the Nginx container and curl or wget the backend service by its Compose service name and port. I also verify the proxy_pass target and backend health.
```

## Container works locally but not in Compose. Why?

Strong answer:

```text id="4ioo3z"
Compose may pass different environment variables, networks, volumes, secrets, or command settings than local docker run. I inspect the rendered config using docker compose config, check service logs, and compare image tags and runtime configuration.
```

## Data disappeared after Compose restart. What happened?

Strong answer:

```text id="sn8tuu"
If containers were only restarted, data in named volumes should remain. I check whether docker compose down -v was used, whether the service was using a named volume or only container writable layer, and whether the volume name changed due to project naming. If a volume was deleted and no backup exists, recovery may not be possible.
```

## How do you handle a failed deployment?

Strong answer:

```text id="x2lyw5"
I check whether the failure started after the deployment. If yes and the previous version was healthy, I rollback first by restoring the previous immutable image tag and redeploying. After service is restored, I investigate logs, health checks, deployment reports, and root cause.
```

---

# Today’s Core Rules

```text id="x5ar9s"
Logs first.
Inspect second.
Restart last.
Always check rendered Compose config.
EXPOSE does not publish ports.
Inside container, localhost means same container.
Use service names in Compose.
Nginx 502 usually means upstream problem.
Health and readiness are different.
Volumes are not backups.
down -v can delete data.
OOMKilled usually means memory limit or memory leak.
Disk full often comes from logs/images/build cache.
Rollback first if production outage is deployment-related.
Restore service before deep root cause analysis.
```

Next lesson:

# Lesson 6.12 — Docker Performance and Resource Management: CPU, memory, pids, logs, disk usage, image cache, Node.js tuning, Compose limits, and production capacity thinking.
