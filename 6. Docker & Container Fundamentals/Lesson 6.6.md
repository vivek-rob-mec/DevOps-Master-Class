# Lesson 6.6 — Docker Volumes and Persistent Data Masterclass

# Named Volumes, Bind Mounts, Database Persistence, Backup/Restore, Permissions, and Production Storage Patterns

In the previous lessons, we learned:

```text id="ofod24"
container filesystem is temporary
containers should be replaceable
important data must live outside the container writable layer
```

Today we focus on **persistent data**.

This lesson is extremely important because many beginners accidentally delete databases with:

```bash id="rw3b7e"
docker compose down -v
```

or by storing data only inside a container.

---

# 1. Beginner Level — Why Do We Need Volumes?

A container has its own writable filesystem layer.

Example:

```bash id="9bacyu"
docker run -it --name temp-demo alpine:3.20 sh
```

Inside:

```sh id="f516l5"
echo "important data" > /data.txt
cat /data.txt
exit
```

Start same container again:

```bash id="9vxy37"
docker start -ai temp-demo
```

Inside:

```sh id="j2m1wd"
cat /data.txt
exit
```

The file exists because this is the same container.

Now remove the container:

```bash id="yvvlyt"
docker rm temp-demo
```

Create a new one:

```bash id="6mll51"
docker run -it --name temp-demo-2 alpine:3.20 sh
```

Inside:

```sh id="wx6qmw"
cat /data.txt
```

It is gone.

Why?

```text id="grdhwi"
Data written inside the container writable layer is tied to that container.
If the container is deleted, that data can be lost.
```

Core rule:

```text id="xw3d5s"
Containers should be disposable. Data should be persistent.
```

---

# 2. What Is a Docker Volume?

A Docker volume is storage managed by Docker.

Simple definition:

```text id="tamczb"
A Docker volume stores data outside the container writable layer so it can survive container replacement.
```

Example:

```bash id="pfr8kr"
docker volume create demo_data
```

List volumes:

```bash id="gk70zx"
docker volume ls
```

Inspect:

```bash id="7kmulz"
docker volume inspect demo_data
```

Use it:

```bash id="335by2"
docker run -it --rm \
  -v demo_data:/data \
  alpine:3.20 sh
```

Inside:

```sh id="bleh0z"
echo "hello from volume" > /data/message.txt
cat /data/message.txt
exit
```

Run another container with same volume:

```bash id="4pwmjf"
docker run --rm \
  -v demo_data:/data \
  alpine:3.20 cat /data/message.txt
```

Expected:

```text id="rvm39u"
hello from volume
```

The first container is gone, but the data remains.

---

# 3. Beginner Mental Model

Without volume:

```text id="s5hn3i"
Container
└── writable layer
    └── data disappears when container is removed
```

With volume:

```text id="l6g0fg"
Container
└── /data  ---> Docker volume demo_data
               data survives container replacement
```

In Compose:

```yaml id="gtprfa"
volumes:
  mongo_data:
```

and:

```yaml id="pd2zct"
services:
  mongo:
    volumes:
      - mongo_data:/data/db
```

Meaning:

```text id="t0e0pu"
MongoDB writes database files to /data/db
/data/db is backed by Docker volume mongo_data
```

---

# 4. Three Storage Types You Must Know

Docker storage usually appears in three practical forms:

```text id="fo5lgf"
1. Named volumes
2. Bind mounts
3. tmpfs mounts
```

## Named volume

Managed by Docker.

```bash id="2p17pm"
-v mongo_data:/data/db
```

Best for:

```text id="mjjgci"
database data
persistent app data
single-server Docker storage
```

## Bind mount

Maps a specific host path into container.

```bash id="0j4zf6"
-v /host/path:/container/path
```

Best for:

```text id="xr2fb8"
local development source code
config files
Nginx config
mounting known host directories
```

## tmpfs

In-memory temporary filesystem.

```bash id="7wlh7w"
--tmpfs /tmp
```

Best for:

```text id="eagztg"
temporary sensitive data
read-only container root filesystem support
high-speed ephemeral temp files
```

Core rule:

```text id="cixq5w"
Named volumes for persistent app/database data. Bind mounts for host-controlled files. tmpfs for temporary memory-backed data.
```

---

# 5. Intermediate Level — Named Volume Lab

Create volume:

```bash id="3fhpwn"
docker volume create lesson66_data
```

Write data:

```bash id="zkhuv8"
docker run --rm \
  -v lesson66_data:/data \
  alpine:3.20 \
  sh -c 'echo "created at $(date)" > /data/file.txt'
```

Read data:

```bash id="af27xw"
docker run --rm \
  -v lesson66_data:/data \
  alpine:3.20 \
  cat /data/file.txt
```

Inspect volume:

```bash id="b3e0l1"
docker volume inspect lesson66_data
```

Find mount path:

```bash id="bmonck"
docker volume inspect lesson66_data --format '{{.Mountpoint}}'
```

On Linux, Docker stores volume data somewhere like:

```text id="c0drnj"
/var/lib/docker/volumes/lesson66_data/_data
```

Do not manually edit Docker’s internal volume paths unless you know exactly what you are doing.

Production rule:

```text id="7yu750"
Manage volumes through Docker commands, backup tools, or controlled maintenance procedures.
```

---

# 6. Bind Mount Lab

Create host directory:

```bash id="qztnv9"
cd ~/devops-masterclass/06-docker-containers
mkdir -p volume-labs/bind-html
echo "Hello from host bind mount" > volume-labs/bind-html/index.html
```

Run Nginx:

```bash id="3sb3ie"
docker rm -f bind-nginx || true

docker run -d \
  --name bind-nginx \
  -p 8081:80 \
  -v "$PWD/volume-labs/bind-html:/usr/share/nginx/html:ro" \
  nginx:alpine
```

Test:

```bash id="o12yg3"
curl http://127.0.0.1:8081
```

Expected:

```text id="x5r76l"
Hello from host bind mount
```

Change host file:

```bash id="ntnpv2"
echo "Updated from host" > volume-labs/bind-html/index.html
```

Test again:

```bash id="fu5uv4"
curl http://127.0.0.1:8081
```

Expected:

```text id="1r66vu"
Updated from host
```

Why?

```text id="rjxi6q"
The container is reading a real host directory.
```

Clean:

```bash id="7qiz47"
docker rm -f bind-nginx
```

---

# 7. Bind Mount Permissions

Bind mounts can cause permission issues.

Example:

```text id="jutnut"
container process runs as user node
host directory owned by root
container tries to write
permission denied
```

Check container user:

```bash id="zghrlh"
docker run --rm --entrypoint id demo-node-api:0.1.9
```

Check host directory:

```bash id="3nvm7g"
ls -ld volume-labs/bind-html
```

Common fixes:

```bash id="a1pvvw"
sudo chown -R "$(id -u):$(id -g)" volume-labs/bind-html
```

or run container with matching user:

```bash id="3xdfrj"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$PWD/volume-labs/bind-html:/data" \
  alpine:3.20 \
  sh -c 'echo test > /data/test.txt'
```

Production warning:

```text id="2zoais"
Do not solve permission problems by blindly chmod -R 777 on production paths.
```

Better:

```text id="cn1hlr"
use correct ownership
run container as intended user
mount only needed paths
use read-only mounts where possible
```

---

# 8. Read-Only Bind Mounts

This is safer:

```bash id="yy61yg"
-v "$PWD/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro"
```

The `:ro` means:

```text id="bd274v"
container can read the file but cannot modify it
```

Use `:ro` for:

```text id="yig4av"
configuration files
static assets
certificates
read-only data
```

Example:

```bash id="i6huzo"
docker run --rm \
  -v "$PWD/volume-labs/bind-html:/data:ro" \
  alpine:3.20 \
  sh -c 'echo test > /data/test.txt'
```

Expected:

```text id="krjcly"
Read-only file system
```

Production rule:

```text id="9aj3n0"
Mount files read-only unless the container truly needs write access.
```

---

# 9. tmpfs Mount Lab

Run:

```bash id="rcds6t"
docker run --rm -it \
  --tmpfs /secure-temp \
  alpine:3.20 sh
```

Inside:

```sh id="05wkcq"
echo "temporary secret" > /secure-temp/token.txt
cat /secure-temp/token.txt
exit
```

Container exits. Data disappears.

Use tmpfs for:

```text id="mz58kf"
temporary files
short-lived sensitive files
high-speed scratch space
read-only root filesystem support
```

Example with Node app:

```bash id="mgvbfr"
docker run -d \
  --name demo-node-api \
  --read-only \
  --tmpfs /tmp \
  -p 3000:3000 \
  -e APP_ENV=dev \
  demo-node-api:0.1.9
```

Clean:

```bash id="n7sabu"
docker rm -f demo-node-api
```

---

# 10. Intermediate — Docker Compose Volumes

In your Compose demo:

```bash id="ef286p"
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

You already have:

```yaml id="v6wbu3"
volumes:
  mongo_data:
```

and:

```yaml id="nz2467"
mongo:
  volumes:
    - mongo_data:/data/db
```

This means MongoDB data persists.

Start:

```bash id="i68k2x"
docker compose up -d
```

Check volume:

```bash id="8qeuv3"
docker volume ls | grep mongo_data
```

Inspect:

```bash id="5ixzcx"
docker volume inspect compose-demo_mongo_data
```

Stop containers but keep data:

```bash id="flccgn"
docker compose down
```

Start again:

```bash id="ofzbl8"
docker compose up -d
```

Volume remains.

Danger command:

```bash id="c2sapc"
docker compose down -v
```

This removes named volumes associated with the Compose project.

Core rule:

```text id="syqr6a"
Use docker compose down for normal shutdown. Use down -v only when you intentionally want to delete persistent data.
```

---

# 11. Add a Simple Data Test with MongoDB

Enter Mongo container:

```bash id="htmesf"
docker compose exec mongo mongosh
```

Inside Mongo shell:

```javascript id="e4w3wm"
use demo
db.lessons.insertOne({ lesson: "docker-volumes", createdAt: new Date() })
db.lessons.find()
exit
```

Restart stack:

```bash id="r3vclb"
docker compose down
docker compose up -d
```

Enter Mongo again:

```bash id="ox9kif"
docker compose exec mongo mongosh
```

Inside:

```javascript id="ghzq9b"
use demo
db.lessons.find()
exit
```

The document should still exist.

Now if you run:

```bash id="4x8knb"
docker compose down -v
docker compose up -d
```

and check again, data will be gone.

Do this only in learning if you are okay deleting the test data.

---

# 12. Advanced Level — Backup a Named Volume

A named volume is not a backup.

A volume is storage.

A backup is a separate copy that can be restored.

Core rule:

```text id="n0ht70"
Persistence is not backup.
```

Backup `mongo_data` volume using a temporary container:

```bash id="952i42"
cd ~/devops-masterclass/06-docker-containers/compose-demo
mkdir -p backups
```

Stop Mongo for filesystem-consistent simple backup:

```bash id="6wuiuq"
docker compose stop mongo
```

Create backup:

```bash id="3ytwkz"
docker run --rm \
  -v compose-demo_mongo_data:/data:ro \
  -v "$PWD/backups:/backup" \
  alpine:3.20 \
  tar czf /backup/mongo_data_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
```

Start Mongo:

```bash id="wulg8f"
docker compose start mongo
```

List backups:

```bash id="hf359t"
ls -lh backups
```

Important:

```text id="5m6lhd"
For databases, application-level backup tools are usually better than raw filesystem tar while DB is running.
```

For MongoDB, production backups usually use:

```text id="7gi61x"
mongodump/mongorestore
snapshots with consistency guarantees
managed backup service
replica set backup tooling
```

---

# 13. Advanced — MongoDB Logical Backup with `mongodump`

For MongoDB, a better backup is logical backup.

Run:

```bash id="1ck3tt"
mkdir -p backups/mongo-dump
```

Use `mongodump` inside Mongo container:

```bash id="1vjqd0"
docker compose exec mongo mongodump --db demo --out /tmp/mongo-backup
```

Copy from container to host:

```bash id="dhtc65"
docker cp compose-demo-mongo:/tmp/mongo-backup ./backups/mongo-dump/$(date +%Y%m%d_%H%M%S)
```

List:

```bash id="5fqj8o"
find backups/mongo-dump -maxdepth 3 -type f
```

Restore example:

```bash id="lk14ma"
docker cp ./backups/mongo-dump/<backup-folder>/demo compose-demo-mongo:/tmp/restore-demo
docker compose exec mongo mongorestore --db demo_restored /tmp/restore-demo
```

Verify:

```bash id="0ltv52"
docker compose exec mongo mongosh --eval 'show dbs'
```

Production rule:

```text id="z0tlmr"
Use database-native backup tools for database backup when possible.
```

---

# 14. Advanced — Restore a Named Volume Backup

Stop stack:

```bash id="9am5ll"
docker compose down
```

Create a fresh volume:

```bash id="2zmw69"
docker volume rm compose-demo_mongo_data || true
docker volume create compose-demo_mongo_data
```

Restore from tar:

```bash id="v8fn7n"
BACKUP_FILE="$(ls -t backups/mongo_data_*.tar.gz | head -n 1)"

docker run --rm \
  -v compose-demo_mongo_data:/data \
  -v "$PWD/backups:/backup" \
  alpine:3.20 \
  sh -c "tar xzf /backup/$(basename "$BACKUP_FILE") -C /data"
```

Start stack:

```bash id="6k4d4m"
docker compose up -d
```

Check Mongo:

```bash id="lbek0n"
docker compose exec mongo mongosh
```

Inside:

```javascript id="9iu50a"
use demo
db.lessons.find()
exit
```

This teaches volume-level backup/restore.

But remember:

```text id="b4euai"
Database-native backups are safer for real database consistency.
```

---

# 15. Advanced — External Named Volumes

Sometimes a volume is created outside Compose and reused.

Create external volume:

```bash id="n76y38"
docker volume create prod_mongo_data
```

Compose:

```yaml id="igc1b9"
volumes:
  mongo_data:
    external: true
    name: prod_mongo_data
```

Meaning:

```text id="waj81o"
Compose will use existing Docker volume prod_mongo_data
Compose will not create a project-prefixed volume
```

Use this for:

```text id="644gda"
shared persistent data
migration between Compose projects
stable production volume names
```

Production caution:

```text id="3pzjfl"
External volumes reduce accidental deletion by project teardown, but you still need backups.
```

---

# 16. Advanced — Production Storage Patterns

For real corporate production, storage choices depend on the platform.

## Single Docker VM

Common:

```text id="pru5k0"
Docker named volumes
host bind mounts under /srv or /opt
regular backups
disk monitoring
```

Example:

```text id="wul3l9"
/srv/apps/myapp/data
/srv/apps/myapp/backups
/srv/apps/myapp/config
```

## Cloud VM

Better:

```text id="dxnju3"
attached block volume
snapshot backups
filesystem monitoring
Docker volume using mounted disk path
```

Example:

```text id="s2evhe"
AWS EBS volume mounted at /data
Docker bind mount /data/mongo:/data/db
EBS snapshots scheduled
```

## Managed Database

Best for many production apps:

```text id="nbpu73"
MongoDB Atlas
AWS RDS
Amazon DocumentDB
Cloud SQL
Azure Database
```

Why?

```text id="w3fh80"
automated backups
high availability
monitoring
patching
scaling
replication
point-in-time restore
```

Corporate rule:

```text id="atxnxu"
For serious production systems, prefer managed databases unless you have a strong reason and team maturity to self-host.
```

---

# 17. Advanced — Bind Mounts on Mounted Disks

In your previous infrastructure work, you used mounted disks like:

```text id="f53qto"
/media/aaizel/data_disk
/mnt/data_disk
```

For production Docker storage, you might use:

```text id="kt3jtf"
/mnt/data_disk/docker-data/mongo
```

Create:

```bash id="q1yfvf"
sudo mkdir -p /mnt/data_disk/docker-data/mongo
sudo chown -R 999:999 /mnt/data_disk/docker-data/mongo
```

Why `999:999`?

```text id="c90j7u"
Official MongoDB container often runs mongod with a specific internal user ID.
Exact UID can vary by image/version, so verify before production.
```

Check Mongo user inside container:

```bash id="4sw6m1"
docker run --rm mongo:7 id mongodb
```

Compose bind mount example:

```yaml id="35bk6b"
mongo:
  image: mongo:7
  volumes:
    - /mnt/data_disk/docker-data/mongo:/data/db
```

Production warning:

```text id="kzvydz"
When using bind mounts for databases, host filesystem permissions and disk reliability matter a lot.
```

---

# 18. Advanced — Read-Only Root Filesystem with Writable Mounts

Good production hardening pattern:

```yaml id="5wf3f2"
services:
  backend:
    read_only: true
    tmpfs:
      - /tmp
```

If app needs write directory:

```yaml id="7111f5"
    volumes:
      - backend_cache:/app/cache
```

For your backend, because it logs to stdout/stderr and does not need file writes, this can work:

```yaml id="l8ojks"
  backend:
    read_only: true
    tmpfs:
      - /tmp
```

Update Compose backend:

```yaml id="0a1c8n"
    read_only: true
    tmpfs:
      - /tmp
```

Test:

```bash id="evjs8j"
docker compose down
docker compose up -d
curl -s http://127.0.0.1:8080/health | jq .
```

Production rule:

```text id="dv2xfq"
Make containers read-only by default, then explicitly mount writable paths.
```

---

# 19. Advanced — Volume Security

Volumes can expose sensitive data.

Examples:

```text id="hpv65i"
database files
uploaded documents
private keys
application secrets
backups
```

Security rules:

```text id="t7il4o"
restrict host permissions
do not mount Docker socket casually
use read-only mounts where possible
avoid mounting entire host directories
encrypt disks when needed
backup securely
control who can access Docker daemon
```

Dangerous mount:

```yaml id="ntk2pk"
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

Why dangerous?

```text id="a7yl80"
Access to Docker socket can often mean root-level control over the host.
```

Only mount Docker socket for trusted tools and with full understanding.

---

# 20. Advanced — Backup Strategy Checklist

For production data, define:

```text id="il4dvc"
RPO: how much data loss is acceptable?
RTO: how quickly must service be restored?
backup frequency
backup location
retention policy
restore testing
encryption
access control
monitoring backup failures
```

Example:

```text id="xyrmas"
RPO: 15 minutes
RTO: 1 hour
Backup: every 15 minutes incremental, daily full
Retention: 7 daily, 4 weekly, 12 monthly
Restore test: monthly
```

Masterclass rule:

```text id="0z7py7"
A backup you never restore-tested is only a hope, not a recovery plan.
```

---

# 21. Production Compose Storage Example

Here is a stronger storage-aware Compose snippet:

```yaml id="oiynxc"
services:
  backend:
    image: demo-node-api:0.1.9
    read_only: true
    tmpfs:
      - /tmp
    env_file:
      - ./backend.env
    networks:
      - public_net
      - private_net

  mongo:
    image: mongo:7
    volumes:
      - mongo_data:/data/db
      - ./backups:/backups
    networks:
      - private_net

volumes:
  mongo_data:
    name: compose_demo_mongo_data

networks:
  public_net:
  private_net:
```

For real production, you may prefer:

```yaml id="uii4oq"
volumes:
  - /mnt/data_disk/mongo:/data/db
```

if `/mnt/data_disk` is backed by reliable disk with snapshots.

---

# 22. Create Volume Notes

Create:

```bash id="32f1p9"
cd ~/devops-masterclass/06-docker-containers
nano docker-volumes-persistent-data.md
```

Paste:

````markdown id="1beovd"
# Docker Volumes and Persistent Data

## Why Volumes?

Containers are disposable. Data must survive container replacement.

## Storage Types

| Type | Example | Use |
|---|---|---|
| Named volume | `mongo_data:/data/db` | persistent data |
| Bind mount | `/host/path:/container/path` | configs, local dev, known host paths |
| tmpfs | `--tmpfs /tmp` | temporary memory-backed data |

## Named Volume Commands

```bash
docker volume create demo_data
docker volume ls
docker volume inspect demo_data
docker volume rm demo_data
````

## Compose Volume

```yaml
services:
  mongo:
    volumes:
      - mongo_data:/data/db

volumes:
  mongo_data:
```

## Backup Named Volume

```bash
docker run --rm \
  -v my_volume:/data:ro \
  -v "$PWD/backups:/backup" \
  alpine:3.20 \
  tar czf /backup/my_volume.tar.gz -C /data .
```

## Restore Named Volume

```bash
docker run --rm \
  -v my_volume:/data \
  -v "$PWD/backups:/backup" \
  alpine:3.20 \
  tar xzf /backup/my_volume.tar.gz -C /data
```

## Production Rules

* Persistence is not backup.
* Use database-native backups when possible.
* Do not run `docker compose down -v` casually.
* Use read-only mounts where possible.
* Secure backup files.
* Test restores regularly.
* Monitor disk usage.

````

---

# 23. Create Backup Script

Create:

```bash id="gnfwor"
cd ~/devops-masterclass/06-docker-containers/compose-demo
mkdir -p scripts backups
nano scripts/backup-mongo-volume.sh
````

Paste:

```bash id="lcs0oe"
#!/usr/bin/env bash
set -euo pipefail

VOLUME_NAME="${VOLUME_NAME:-compose-demo_mongo_data}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/${VOLUME_NAME}_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "===== Mongo Volume Backup ====="
echo "Volume: $VOLUME_NAME"
echo "Backup: $BACKUP_FILE"

docker run --rm \
  -v "$VOLUME_NAME:/data:ro" \
  -v "$PWD/$BACKUP_DIR:/backup" \
  alpine:3.20 \
  tar czf "/backup/$(basename "$BACKUP_FILE")" -C /data .

echo "Backup created:"
ls -lh "$BACKUP_FILE"
```

Make executable:

```bash id="ioov86"
chmod +x scripts/backup-mongo-volume.sh
```

Run:

```bash id="ytagcg"
./scripts/backup-mongo-volume.sh
```

---

# 24. Create Restore Script

Create:

```bash id="ba0bzm"
nano scripts/restore-mongo-volume.sh
```

Paste:

```bash id="5btv2v"
#!/usr/bin/env bash
set -euo pipefail

VOLUME_NAME="${VOLUME_NAME:-compose-demo_mongo_data}"
BACKUP_FILE="${1:-}"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup-file.tar.gz>" >&2
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: backup file not found: $BACKUP_FILE" >&2
  exit 1
fi

echo "===== Mongo Volume Restore ====="
echo "Volume: $VOLUME_NAME"
echo "Backup: $BACKUP_FILE"

echo "WARNING: This will replace data in volume: $VOLUME_NAME"
echo "Press Ctrl+C now to cancel, or wait 5 seconds..."
sleep 5

docker volume rm "$VOLUME_NAME" >/dev/null 2>&1 || true
docker volume create "$VOLUME_NAME" >/dev/null

docker run --rm \
  -v "$VOLUME_NAME:/data" \
  -v "$PWD/$(dirname "$BACKUP_FILE"):/backup" \
  alpine:3.20 \
  tar xzf "/backup/$(basename "$BACKUP_FILE")" -C /data

echo "Restore completed."
```

Make executable:

```bash id="xw8h8d"
chmod +x scripts/restore-mongo-volume.sh
```

Use carefully:

```bash id="345ucd"
docker compose down
./scripts/restore-mongo-volume.sh backups/<backup-file>.tar.gz
docker compose up -d
```

---

# 25. Create Volume Lab Script

Create:

```bash id="8ba8w0"
cd ~/devops-masterclass/06-docker-containers
nano scripts/docker-volumes-lab.sh
```

Paste:

```bash id="rmsbp9"
#!/usr/bin/env bash
set -euo pipefail

VOLUME_NAME="${VOLUME_NAME:-lesson66_data}"

echo "===== Docker Volumes Lab ====="

echo
echo "1. Creating volume..."
docker volume create "$VOLUME_NAME" >/dev/null

echo
echo "2. Writing data using a temporary container..."
docker run --rm \
  -v "$VOLUME_NAME:/data" \
  alpine:3.20 \
  sh -c 'echo "hello from persistent volume at $(date)" > /data/message.txt'

echo
echo "3. Reading data using another temporary container..."
docker run --rm \
  -v "$VOLUME_NAME:/data" \
  alpine:3.20 \
  cat /data/message.txt

echo
echo "4. Inspecting volume..."
docker volume inspect "$VOLUME_NAME"

echo
echo "Lab completed."
```

Make executable:

```bash id="ei3s00"
chmod +x scripts/docker-volumes-lab.sh
```

Run:

```bash id="zk6vlc"
./scripts/docker-volumes-lab.sh
```

---

# 26. Troubleshooting Playbook

## Problem 1 — Data disappeared

Check if you used:

```bash id="q8czjd"
docker compose down -v
```

Check volumes:

```bash id="5dccvb"
docker volume ls
```

Check Compose project prefix:

```bash id="eza0pq"
docker volume ls | grep compose-demo
```

If volume was deleted and no backup exists, recovery may not be possible.

---

## Problem 2 — Permission denied

Check container user:

```bash id="ebc8vv"
docker compose exec backend id
```

Check host path:

```bash id="xo1osq"
ls -ld /host/path
```

Fix ownership carefully:

```bash id="n45u6x"
sudo chown -R <uid>:<gid> /host/path
```

Avoid:

```bash id="z5l37j"
sudo chmod -R 777 /host/path
```

unless it is a throwaway lab.

---

## Problem 3 — Volume name confusion

Compose prefixes volumes with project name.

Example:

```yaml id="ykeim7"
volumes:
  mongo_data:
```

Actual volume may be:

```text id="11jrjl"
compose-demo_mongo_data
```

Check:

```bash id="hmkxfh"
docker volume ls
docker compose config | grep -A5 volumes
```

Use explicit name:

```yaml id="ny7f9x"
volumes:
  mongo_data:
    name: compose_demo_mongo_data
```

---

## Problem 4 — Backup file created but empty

Check volume has data:

```bash id="h2wb8r"
docker run --rm \
  -v compose-demo_mongo_data:/data:ro \
  alpine:3.20 \
  find /data -maxdepth 2 -type f | head
```

Check correct volume name:

```bash id="8oyao1"
docker volume ls
```

---

## Problem 5 — Database backup inconsistent

Cause:

```text id="nr3jxg"
raw filesystem backup while DB is actively writing
```

Better:

```text id="v1cuow"
stop database before raw tar backup
or use database-native backup like mongodump
or use storage snapshot with consistency guarantees
```

---

# 27. Final Validation

Run:

```bash id="mmu4x5"
cd ~/devops-masterclass/06-docker-containers
./scripts/docker-volumes-lab.sh
```

Run Compose stack:

```bash id="ae6ri7"
cd ~/devops-masterclass/06-docker-containers/compose-demo
docker compose up -d
docker compose ps
```

Add Mongo test data:

```bash id="2eallh"
docker compose exec mongo mongosh --eval 'use demo; db.lessons.insertOne({lesson:"volumes", createdAt:new Date()}); db.lessons.find();'
```

Backup:

```bash id="cj95u4"
./scripts/backup-mongo-volume.sh
ls -lh backups
```

Restart stack:

```bash id="2i69gb"
docker compose down
docker compose up -d
```

Verify data:

```bash id="6024x6"
docker compose exec mongo mongosh --eval 'use demo; db.lessons.find();'
```

Check app:

```bash id="epkx5f"
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
```

---

# 28. Commit Work

Run:

```bash id="u21lp6"
cd ~/devops-masterclass

git status
git add 06-docker-containers
git commit -m "feat: add Docker volumes and persistent data lesson"
git push
```

---

# 29. Interview Explanation

## What is a Docker volume?

Strong answer:

```text id="xl6fxa"
A Docker volume is storage managed by Docker that exists outside the container writable layer. It allows data to persist even when containers are stopped, removed, or recreated. Volumes are commonly used for databases, uploads, and other persistent application data.
```

## Difference between named volume and bind mount?

Strong answer:

```text id="d45b3o"
A named volume is managed by Docker and is usually best for persistent container data like databases. A bind mount maps a specific host path into a container and is often used for local development, configuration files, or known host storage paths. Bind mounts require more attention to host permissions and path management.
```

## Why is `docker compose down -v` dangerous?

Strong answer:

```text id="a98uza"
`docker compose down -v` removes the containers and also deletes named volumes created by the Compose project. If a database stores data in those volumes, this command can delete the database data. It should only be used when intentionally resetting persistent data.
```

## Is a volume a backup?

Strong answer:

```text id="omemkz"
No. A volume provides persistence, but it is not a backup. A backup is a separate recoverable copy stored independently. Production systems need backup frequency, retention, encryption, access control, and regular restore testing.
```

## How do you back up Docker database data?

Strong answer:

```text id="0p6aq3"
For databases, I prefer database-native backup tools such as mongodump for MongoDB or pg_dump for PostgreSQL. For simple volume-level backups, I can stop the database container and use a temporary container to tar the volume contents. In production, backups should be automated, monitored, encrypted, and restore-tested.
```

---

# Today’s Core Rules

```text id="kq2sp0"
Containers are disposable.
Data must live outside container writable layers.
Use named volumes for persistent data.
Use bind mounts for host-controlled paths.
Use tmpfs for temporary memory-backed data.
Use read-only mounts when possible.
Do not commit data or secrets into images.
Do not run docker compose down -v casually.
Persistence is not backup.
Use database-native backups for databases.
Test restore regularly.
Secure backup files.
Monitor disk usage.
Avoid chmod 777 in production.
Use managed databases for serious production when possible.
```

Next lesson:

# Lesson 6.7 — Docker Compose Production Patterns: profiles, override files, secrets, resource limits, health-based deployments, and CI/CD deployment flow.
