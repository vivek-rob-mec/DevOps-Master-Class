# Lesson 3.15 — Networking Foundation

Now we start **Linux networking**, one of the most important DevOps skills.

Almost every production issue eventually touches networking:

```text
Website not opening
API timeout
DNS not resolving
Port not reachable
Load balancer health check failing
Container cannot reach database
Kubernetes pod cannot reach service
SSH not connecting
TLS certificate issue
Firewall blocking traffic
Security group misconfigured
```

A beginner says:

```text
Server is down.
```

A DevOps engineer says:

```text
DNS resolves correctly, TCP connection to port 443 succeeds, TLS handshake succeeds, but backend returns 502 because Nginx cannot connect to upstream 127.0.0.1:3000.
```

That level of clarity comes from networking fundamentals.

---

# 1. What is Networking?

Networking means communication between systems.

Examples:

```text
Your laptop → GitHub
Browser → CloudFront
CloudFront → ALB
ALB → EC2
Frontend → Backend API
Backend → MongoDB
App → Redis
App → S3
Jenkins → Deployment server
Kubernetes pod → Kubernetes service
```

Networking is about:

```text
Who is talking?
To whom?
Using which protocol?
On which IP?
On which port?
Is name resolution working?
Is routing working?
Is firewall allowing it?
Is the service listening?
Is TLS working?
```

---

# 2. The Core Networking Model

When one machine talks to another:

```text
Application
  ↓
Protocol
  ↓
Port
  ↓
IP address
  ↓
Network route
  ↓
Firewall/security rules
  ↓
Remote service
```

Example:

```bash
curl https://api.example.com/todos
```

Behind the scenes:

```text
Resolve api.example.com to IP using DNS
Connect to IP on port 443
Perform TCP handshake
Perform TLS handshake
Send HTTP request
Receive HTTP response
```

If any layer fails, the request fails.

---

# 3. IP Address

An IP address identifies a network interface.

Examples:

```text
127.0.0.1
192.168.1.10
10.0.1.25
172.16.0.5
8.8.8.8
```

Check your IPs:

```bash
ip addr
```

Shorter:

```bash
ip -br addr
```

Example:

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             172.20.10.5/24
```

Important interfaces:

```text
lo      loopback interface
eth0    common network interface name
ens*    common cloud/server interface name
wlan0   wireless interface
docker0 Docker bridge interface
```

---

# 4. Loopback: `127.0.0.1` and `localhost`

`127.0.0.1` means:

```text
This same machine.
```

`localhost` usually resolves to:

```text
127.0.0.1
```

Check:

```bash
getent hosts localhost
```

Example:

```text
127.0.0.1 localhost
```

Important:

```text
127.0.0.1 on your laptop means your laptop.
127.0.0.1 inside a container means that container.
127.0.0.1 on an EC2 server means that EC2 server.
```

This is a very common beginner mistake.

Example:

```text
Frontend container calls http://localhost:3000
```

Inside frontend container, `localhost` means frontend container itself, not backend container.

In Docker Compose, use service name:

```text
http://backend:3000
```

---

# 5. Private IP vs Public IP

## Private IP

Private IPs are used inside private networks.

Common private ranges:

```text
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
```

Examples:

```text
10.0.1.25
172.31.10.5
192.168.1.100
```

Used in:

```text
Home LAN
AWS VPC
Kubernetes pod networks
Docker networks
Private subnets
```

## Public IP

Public IPs are reachable over the internet, subject to firewall/routing.

Examples:

```text
8.8.8.8
1.1.1.1
Public EC2 IP
Load balancer DNS IPs
```

Production rule:

```text
Databases should usually not have public IP access.
Apps usually talk to databases over private IP/network.
```

---

# 6. CIDR Notation

You will see IPs like:

```text
10.0.1.25/24
```

`/24` is the subnet mask.

It means:

```text
Network part: first 24 bits
Host part: remaining 8 bits
```

For practical DevOps:

```text
10.0.1.25/24 belongs to network 10.0.1.0/24
```

That subnet has addresses roughly:

```text
10.0.1.0 to 10.0.1.255
```

Common CIDR examples:

```text
10.0.0.0/16      large VPC network
10.0.1.0/24      subnet
0.0.0.0/0        anywhere
127.0.0.1/8      loopback
```

Very important:

```text
0.0.0.0/0 means all IPv4 addresses.
```

In AWS Security Groups:

```text
Allow SSH from 0.0.0.0/0
```

means SSH is open to the entire internet.

Avoid this in production.

---

# 7. Port

A port identifies a service on a machine.

Examples:

```text
22    SSH
80    HTTP
443   HTTPS
3000  common Node.js app
5432  PostgreSQL
3306  MySQL
6379  Redis
27017 MongoDB
9090  Prometheus
3000  Grafana also commonly uses 3000
```

Same server can run multiple services using different ports:

```text
10.0.1.10:22     SSH
10.0.1.10:80     Nginx HTTP
10.0.1.10:443    Nginx HTTPS
10.0.1.10:3000   Node app
```

Format:

```text
IP:PORT
```

Example:

```text
127.0.0.1:3000
```

---

# 8. Listening Port

A service must listen on a port to accept connections.

Check listening ports:

```bash
ss -tulnp
```

Meaning:

```text
-t   TCP
-u   UDP
-l   listening
-n   numeric output
-p   process info
```

Example:

```bash
sudo ss -tulnp
```

Example output:

```text
Netid State  Local Address:Port  Peer Address:Port Process
tcp   LISTEN 0.0.0.0:80          0.0.0.0:*         users:(("nginx",pid=1234))
tcp   LISTEN 127.0.0.1:3000      0.0.0.0:*         users:(("node",pid=2222))
tcp   LISTEN 0.0.0.0:22          0.0.0.0:*         users:(("sshd",pid=1111))
```

Interpretation:

```text
0.0.0.0:80       listens on all IPv4 interfaces
127.0.0.1:3000   listens only locally
0.0.0.0:22       SSH reachable on all interfaces, if firewall allows
```

---

# 9. `127.0.0.1` vs `0.0.0.0`

This is critical.

## `127.0.0.1`

```text
Only local machine can connect.
```

Example:

```text
127.0.0.1:3000
```

Nginx on same server can connect to it, but external users cannot.

## `0.0.0.0`

```text
Listen on all network interfaces.
```

Example:

```text
0.0.0.0:3000
```

External machines may connect if firewall/security group allows.

Production pattern:

```text
App listens on 127.0.0.1:3000
Nginx listens on 0.0.0.0:80/443
Nginx proxies to app locally
```

This keeps app port private.

---

# 10. Protocols: TCP and UDP

## TCP

TCP is connection-oriented and reliable.

Used by:

```text
HTTP
HTTPS
SSH
PostgreSQL
MySQL
MongoDB
Redis
SMTP
```

TCP has:

```text
Connection
Handshake
Reliability
Ordering
Retransmission
```

## UDP

UDP is connectionless and lightweight.

Used by:

```text
DNS
DHCP
Some streaming
Some VPNs
QUIC/HTTP3
```

UDP does not guarantee delivery or ordering.

DevOps practical rule:

```text
Most application troubleshooting is TCP.
DNS is often UDP, but can use TCP too.
```

---

# 11. TCP Handshake

Before TCP data flows, client and server perform a handshake:

```text
Client → SYN
Server → SYN-ACK
Client → ACK
```

Then connection is established.

If handshake fails, possible causes:

```text
Service not listening
Firewall blocking
Wrong IP
Wrong port
Route missing
Security group blocking
Server down
```

Tools:

```bash
nc -vz host port
telnet host port
curl -v http://host:port
```

Install netcat if needed:

```bash
sudo apt install -y netcat-openbsd
```

Test TCP port:

```bash
nc -vz 127.0.0.1 22
```

Example success:

```text
Connection to 127.0.0.1 22 port [tcp/ssh] succeeded!
```

Failure:

```text
Connection refused
```

or:

```text
Connection timed out
```

These mean different things.

---

# 12. Connection Refused vs Timed Out

## Connection refused

Usually means:

```text
Host reachable, but nothing is listening on that port
or firewall actively rejected it.
```

Example:

```bash
curl http://127.0.0.1:9999
```

Possible output:

```text
Connection refused
```

Debug:

```bash
sudo ss -tulnp | grep ':9999'
```

## Connection timed out

Usually means:

```text
Packets are not getting a response.
Firewall/security group/routing issue possible.
```

Examples:

```text
Security group blocks port
NACL blocks port
Server unreachable
Wrong private network route
Firewall drops traffic
```

Debug:

```bash
ping host
traceroute host
nc -vz host port
```

Install traceroute:

```bash
sudo apt install -y traceroute
```

---

# 13. DNS

DNS converts names to IP addresses.

Example:

```text
github.com → IP address
api.example.com → IP address
```

Commands:

```bash
nslookup github.com
dig github.com
getent hosts github.com
```

Install DNS tools:

```bash
sudo apt install -y dnsutils
```

Use:

```bash
dig github.com
```

Short answer:

```bash
dig +short github.com
```

Check a specific record:

```bash
dig A github.com
dig AAAA github.com
dig CNAME www.example.com
dig MX gmail.com
dig TXT example.com
```

Practical DevOps DNS questions:

```text
Does the domain resolve?
Does it resolve to expected IP/load balancer?
Is CNAME correct?
Is TTL too high?
Is private DNS resolving inside VPC?
Is container using correct DNS?
```

---

# 14. `/etc/hosts`

Local hostname overrides can be defined in:

```text
/etc/hosts
```

View:

```bash
cat /etc/hosts
```

Example:

```text
127.0.0.1 localhost
10.0.1.10 internal-api.local
```

If you add:

```text
10.0.1.10 api.example.com
```

then your machine may resolve `api.example.com` to `10.0.1.10`, ignoring public DNS.

Good for testing.

Dangerous if forgotten.

Edit safely:

```bash
sudo cp -a /etc/hosts "/etc/hosts.$(date +%Y%m%d-%H%M%S).bak"
sudo nano /etc/hosts
```

Check:

```bash
getent hosts api.example.com
```

---

# 15. DNS Resolution Order

Linux may check multiple sources:

```text
/etc/hosts
DNS server
mDNS
systemd-resolved
```

Config:

```bash
cat /etc/nsswitch.conf
```

Look for:

```text
hosts: files dns
```

Meaning:

```text
Check files first, then DNS.
```

So `/etc/hosts` can override DNS.

---

# 16. Default Gateway and Routing

A route tells Linux where to send packets.

Show routes:

```bash
ip route
```

Example:

```text
default via 192.168.1.1 dev eth0
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.50
```

Meaning:

```text
For unknown destinations, send traffic to gateway 192.168.1.1.
Local subnet 192.168.1.0/24 is directly reachable via eth0.
```

Check route to a target:

```bash
ip route get 8.8.8.8
```

Example:

```text
8.8.8.8 via 192.168.1.1 dev eth0 src 192.168.1.50
```

This answers:

```text
Which interface and source IP will Linux use to reach this destination?
```

Very useful.

---

# 17. Ping

`ping` tests basic IP reachability using ICMP.

```bash
ping -c 4 8.8.8.8
```

Ping domain:

```bash
ping -c 4 github.com
```

If IP ping works but domain ping fails:

```text
DNS problem likely.
```

If domain resolves but ping fails:

```text
ICMP may be blocked.
Do not assume service is down only because ping fails.
```

Many servers block ICMP.

For service checks, use TCP tools:

```bash
curl
nc
ss
```

---

# 18. `curl`

`curl` is one of the most important DevOps tools.

Basic:

```bash
curl http://example.com
```

Show headers:

```bash
curl -I https://example.com
```

Verbose:

```bash
curl -v https://example.com
```

Fail on HTTP error:

```bash
curl -f https://example.com
```

Silent but show errors:

```bash
curl -sS https://example.com
```

Common health check:

```bash
curl -fsS http://127.0.0.1:3000/health
```

With timeout:

```bash
curl --connect-timeout 5 --max-time 10 -fsS http://127.0.0.1:3000/health
```

Print status code only:

```bash
curl -o /dev/null -s -w "%{http_code}\n" https://example.com
```

Print timing:

```bash
curl -o /dev/null -s -w "dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} total=%{time_total}\n" https://example.com
```

This is very useful for performance troubleshooting.

---

# 19. HTTP Status Codes

Common status codes:

```text
200 OK
201 Created
204 No Content
301 Moved Permanently
302 Found
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
429 Too Many Requests
500 Internal Server Error
502 Bad Gateway
503 Service Unavailable
504 Gateway Timeout
```

DevOps interpretation:

```text
2xx    success
3xx    redirect
4xx    client/auth/path/rate-limit issue
5xx    server/upstream/backend issue
```

Common production meanings:

```text
502 from Nginx/ALB: upstream backend problem
503: service unavailable/no healthy backend
504: upstream timeout
403: auth/WAF/permission/static file issue
404: route/path/deploy mismatch
```

---

# 20. Firewalls

A firewall controls traffic.

Linux firewall tools:

```text
ufw
iptables
nftables
firewalld
```

Ubuntu often uses `ufw`.

Check:

```bash
sudo ufw status verbose
```

Allow port:

```bash
sudo ufw allow 80/tcp
```

Deny port:

```bash
sudo ufw deny 3306/tcp
```

Enable firewall:

```bash
sudo ufw enable
```

Be careful with SSH.

Before enabling firewall on remote server:

```bash
sudo ufw allow ssh
sudo ufw enable
```

Production warning:

```text
You can lock yourself out if SSH is blocked.
```

In AWS, you also have Security Groups and NACLs.

Linux firewall may allow traffic, but AWS SG may block it.

Or AWS SG may allow traffic, but Linux firewall may block it.

Check both.

---

# 21. AWS Security Group Mental Model

A Security Group is a virtual firewall around ENIs/resources.

Common inbound rules:

```text
22/tcp from your IP        SSH
80/tcp from 0.0.0.0/0      HTTP
443/tcp from 0.0.0.0/0     HTTPS
3000/tcp from ALB SG only  app port
27017/tcp from app SG only MongoDB
```

Bad:

```text
MongoDB 27017 from 0.0.0.0/0
```

Good:

```text
MongoDB 27017 from backend security group only
```

Production rule:

```text
Expose only load balancer/public reverse proxy to internet.
Keep app/database ports private.
```

---

# 22. Network Troubleshooting Flow

When connection fails, follow this:

```text
1. Is the name resolving?
2. Is the IP correct?
3. Is the route correct?
4. Is the remote host reachable?
5. Is the port open/listening?
6. Is firewall/security group allowing?
7. Is the application responding?
8. Is TLS valid?
9. Are logs showing errors?
```

Commands:

```bash
dig +short host
getent hosts host
ip route get <ip>
ping -c 4 <ip>
nc -vz host port
curl -v http://host:port
sudo ss -tulnp
sudo ufw status verbose
journalctl -u service -n 100
```

---

# 23. Lab — Local Port and Curl

Start a local HTTP server:

```bash
cd ~/devops-masterclass
python3 -m http.server 8080 &
HTTP_PID=$!
```

Check listening:

```bash
sudo ss -tulnp | grep ':8080'
```

Curl:

```bash
curl -I http://127.0.0.1:8080
```

Status code only:

```bash
curl -o /dev/null -s -w "%{http_code}\n" http://127.0.0.1:8080
```

Test with `localhost`:

```bash
curl -I http://localhost:8080
```

Stop:

```bash
kill "$HTTP_PID"
```

Confirm:

```bash
sudo ss -tulnp | grep ':8080' || echo "port 8080 is free"
```

---

# 24. Lab — Connection Refused

Try:

```bash
curl -v http://127.0.0.1:9999
```

You may see:

```text
Connection refused
```

Check:

```bash
sudo ss -tulnp | grep ':9999' || echo "nothing listening"
```

Lesson:

```text
Connection refused usually means the host is reachable but no process is listening on that port.
```

---

# 25. Lab — DNS

Run:

```bash
dig +short github.com
getent hosts github.com
nslookup github.com
```

Check DNS config:

```bash
cat /etc/resolv.conf
```

On systemd-resolved systems:

```bash
resolvectl status
```

If `resolvectl` does not exist, skip.

---

# 26. Lab — Routes

Run:

```bash
ip route
ip route get 8.8.8.8
```

Check your default gateway:

```bash
ip route | grep default
```

This tells how your machine reaches the internet.

---

# 27. Create Network Debug Script

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/network-debug.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
PORT="${2:-}"

usage() {
  echo "Usage: $0 <host> [port]" >&2
  echo "Example: $0 github.com 443" >&2
}

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

if [ -z "$HOST" ]; then
  usage
  exit 1
fi

section "Input"
echo "Host: $HOST"
echo "Port: ${PORT:-not provided}"
echo "Time: $(date -Is)"

section "Local Network Interfaces"
ip -br addr || true

section "Routes"
ip route || true

section "DNS Resolution"
getent hosts "$HOST" || true

if command -v dig >/dev/null 2>&1; then
  echo
  echo "--- dig +short ---"
  dig +short "$HOST" || true
fi

section "Route to Host"
if HOST_IP="$(getent hosts "$HOST" | awk '{print $1}' | head -1)"; then
  if [ -n "$HOST_IP" ]; then
    echo "Resolved IP: $HOST_IP"
    ip route get "$HOST_IP" || true
  else
    echo "Could not resolve host to IP"
  fi
fi

section "Ping"
ping -c 4 "$HOST" || true

if [ -n "$PORT" ]; then
  section "TCP Port Check"

  if command -v nc >/dev/null 2>&1; then
    nc -vz "$HOST" "$PORT" || true
  else
    echo "nc not installed. Install: sudo apt install -y netcat-openbsd"
  fi

  section "Curl Check"
  if command -v curl >/dev/null 2>&1; then
    if [ "$PORT" = "443" ]; then
      curl -Iv --connect-timeout 5 --max-time 10 "https://$HOST" || true
    else
      curl -v --connect-timeout 5 --max-time 10 "http://$HOST:$PORT" || true
    fi
  else
    echo "curl not installed"
  fi
fi

section "Local Listening Ports"
sudo ss -tulnp 2>/dev/null || ss -tuln || true

echo
echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/network-debug.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/network-debug.sh github.com 443
```

Run local:

```bash
python3 -m http.server 8080 &
HTTP_PID=$!

./03-linux-bash-networking/scripts/network-debug.sh 127.0.0.1 8080

kill "$HTTP_PID"
```

---

# 28. Create Port Check Script

Create:

```bash
nano 03-linux-bash-networking/scripts/check-port.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
PORT="${2:-}"
TIMEOUT_SECONDS="${3:-5}"

usage() {
  echo "Usage: $0 <host> <port> [timeout-seconds]" >&2
  echo "Example: $0 127.0.0.1 3000 5" >&2
}

if [ -z "$HOST" ] || [ -z "$PORT" ]; then
  usage
  exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: port must be numeric" >&2
  exit 1
fi

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: timeout must be numeric" >&2
  exit 1
fi

if command -v nc >/dev/null 2>&1; then
  if timeout "${TIMEOUT_SECONDS}s" nc -vz "$HOST" "$PORT"; then
    echo "OK: $HOST:$PORT is reachable"
  else
    echo "ERROR: $HOST:$PORT is not reachable" >&2
    exit 1
  fi
else
  echo "ERROR: nc not installed. Install: sudo apt install -y netcat-openbsd" >&2
  exit 1
fi
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/check-port.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/check-port.sh github.com 443
```

---

# 29. Create HTTP Check Script

Create:

```bash
nano 03-linux-bash-networking/scripts/http-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

URL="${1:-}"
EXPECTED_STATUS="${2:-200}"

usage() {
  echo "Usage: $0 <url> [expected-status]" >&2
  echo "Example: $0 https://example.com 200" >&2
}

if [ -z "$URL" ]; then
  usage
  exit 1
fi

if ! [[ "$EXPECTED_STATUS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: expected status must be numeric" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not installed" >&2
  exit 1
fi

STATUS_CODE="$(
  curl -o /dev/null \
       -s \
       -w "%{http_code}" \
       --connect-timeout 5 \
       --max-time 10 \
       "$URL"
)"

echo "URL: $URL"
echo "Expected: $EXPECTED_STATUS"
echo "Actual: $STATUS_CODE"

if [ "$STATUS_CODE" = "$EXPECTED_STATUS" ]; then
  echo "OK"
else
  echo "ERROR: unexpected HTTP status" >&2
  exit 1
fi
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/http-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/http-check.sh https://github.com 200
```

For redirects, expected may be `301` or `302` depending on URL.

---

# 30. Create Networking Notes

Create:

```bash
nano 03-linux-bash-networking/networking-foundation.md
```

Paste:

````markdown
# Networking Foundation

## Core Concepts

Networking troubleshooting asks:

```text
Who is talking?
To whom?
Using which protocol?
On which IP?
On which port?
Is DNS working?
Is routing working?
Is firewall allowing it?
Is service listening?
Is application responding?
````

## Important Commands

```bash
ip addr
ip -br addr
ip route
ip route get 8.8.8.8
ss -tulnp
sudo ss -tulnp
ping -c 4 host
dig +short host
nslookup host
getent hosts host
curl -v http://host:port
curl -I https://host
nc -vz host port
sudo ufw status verbose
traceroute host
```

## Important Concepts

| Concept    | Meaning                               |
| ---------- | ------------------------------------- |
| IP address | Identifies network interface          |
| Port       | Identifies service on a host          |
| TCP        | Reliable connection-oriented protocol |
| UDP        | Lightweight connectionless protocol   |
| DNS        | Converts names to IPs                 |
| Route      | Tells Linux where to send packets     |
| Firewall   | Allows/blocks traffic                 |
| 127.0.0.1  | Local machine only                    |
| 0.0.0.0    | Listen on all interfaces              |
| 0.0.0.0/0  | Anywhere/all IPv4 addresses           |

## Common Ports

|  Port | Service            |
| ----: | ------------------ |
|    22 | SSH                |
|    80 | HTTP               |
|   443 | HTTPS              |
|  3000 | Common app/Grafana |
|  5432 | PostgreSQL         |
|  3306 | MySQL              |
|  6379 | Redis              |
| 27017 | MongoDB            |
|  9090 | Prometheus         |

## Troubleshooting Flow

```text
1. DNS: does the name resolve?
2. Route: does Linux know where to send packets?
3. Reachability: can host be reached?
4. Port: is the service listening?
5. Firewall: is traffic allowed?
6. Application: does HTTP/API respond correctly?
7. Logs: what does service say?
```

## Rules

* `localhost` means the current network namespace.
* `127.0.0.1` inside a container means that container.
* `0.0.0.0` means listen on all interfaces.
* `connection refused` usually means no listener or active reject.
* `timeout` often means firewall/routing/drop.
* DNS success does not mean application success.
* Ping failure does not always mean service failure.
* Use `curl` or `nc` for service checks.

````

---

# 31. Commit Work

Run:

```bash
git status
git diff
````

Add:

```bash
git add 03-linux-bash-networking/networking-foundation.md \
        03-linux-bash-networking/scripts/network-debug.sh \
        03-linux-bash-networking/scripts/check-port.sh \
        03-linux-bash-networking/scripts/http-check.sh
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "docs: add networking foundation"
git push
```

---

# 32. Real Production Scenario — Backend Port Not Reachable

Problem:

```text
Frontend cannot call backend API.
```

Check backend server:

```bash
sudo ss -tulnp | grep ':3000'
```

If nothing:

```text
Backend app is not listening.
```

Check service:

```bash
systemctl status todo-api
journalctl -u todo-api -n 100
```

If listening on `127.0.0.1:3000`:

```text
Only local machine can connect.
```

If frontend is on another server, backend must either:

```text
listen on private IP/0.0.0.0 with firewall restrictions
or be reached through Nginx/load balancer
```

Check from frontend server:

```bash
nc -vz backend-private-ip 3000
curl -v http://backend-private-ip:3000/health
```

If timeout:

```text
Firewall/security group/routing issue likely.
```

If refused:

```text
No listener on backend IP/port or app bound only to localhost.
```

---

# 33. Real Production Scenario — Domain Not Working

Problem:

```text
api.example.com is not opening.
```

Check DNS:

```bash
dig +short api.example.com
getent hosts api.example.com
```

Check HTTPS:

```bash
curl -Iv https://api.example.com
```

Check status:

```bash
curl -o /dev/null -s -w "%{http_code}\n" https://api.example.com
```

If DNS fails:

```text
DNS record missing/wrong.
```

If DNS points wrong:

```text
Record points to wrong load balancer/IP.
```

If TLS fails:

```text
Certificate/domain mismatch or expired certificate.
```

If 502:

```text
Reverse proxy/load balancer cannot reach backend.
```

If 403:

```text
WAF, permission, auth, bucket policy, or app-level block.
```

---

# 34. Real Production Scenario — SSH Timeout

Problem:

```bash
ssh ubuntu@server-ip
```

hangs or times out.

Check:

```bash
ping -c 4 server-ip
nc -vz server-ip 22
```

Possible causes:

```text
Security group does not allow your IP
Server firewall blocks 22
sshd not running
Wrong public IP
Server in private subnet
Route/NACL issue
Instance down
```

If you have console/session access, check server:

```bash
sudo systemctl status ssh
sudo ss -tulnp | grep ':22'
sudo ufw status verbose
```

AWS side:

```text
Inbound SG: 22/tcp from your current public IP
Route table: public subnet route to internet gateway
NACL allows inbound/outbound
Instance has public IP or reachable through bastion/VPN/SSM
```

---

# 35. Interview Answers

Question:

```text
How do you troubleshoot a service not reachable on a port?
```

Strong answer:

```text
I first check whether the service is listening locally using sudo ss -tulnp and confirm the IP and port it is bound to. Then I test locally with curl or nc. If local works, I test from the client machine using nc -vz or curl -v. If it is refused, usually nothing is listening on that address/port. If it times out, I investigate firewall, security group, routing, or network ACLs. I also check DNS if a hostname is used and service logs for application errors.
```

Question:

```text
What is the difference between 127.0.0.1 and 0.0.0.0?
```

Strong answer:

```text
127.0.0.1 is the loopback address and only accepts connections from the same machine or network namespace. 0.0.0.0 means the service listens on all available IPv4 interfaces. In production, apps may listen on 127.0.0.1 behind Nginx, while public services like Nginx listen on 0.0.0.0 for ports 80 and 443.
```

Question:

```text
What is the difference between connection refused and timeout?
```

Strong answer:

```text
Connection refused usually means the host is reachable but there is no process listening on that port, or a firewall actively rejected the connection. A timeout usually means packets are being dropped or not routed correctly, often due to firewall, security group, NACL, routing, or host reachability issues.
```

Question:

```text
How do you check DNS resolution in Linux?
```

Strong answer:

```text
I use getent hosts to check the system resolver path and dig or nslookup for DNS queries. I also check /etc/hosts because it can override DNS depending on nsswitch.conf. If DNS resolves to the wrong IP, I verify the DNS record, CNAME, TTL, and whether I am inside a private network using private DNS.
```

---

# Today’s Core Rules

```text
Networking failures happen at layers.
Always separate DNS, route, port, firewall, TLS, and application.
Use ip addr to inspect local IPs.
Use ip route to inspect routing.
Use ss to check listening ports.
Use dig/getent for DNS.
Use nc for TCP port checks.
Use curl for HTTP checks.
127.0.0.1 means local namespace only.
0.0.0.0 means all interfaces.
Connection refused and timeout mean different things.
Do not expose database ports publicly.
```

Next lesson:

# Lesson 3.16 — Deep Networking Troubleshooting: curl timing, traceroute, mtr, tcpdump, DNS debugging, TLS checks, firewall debugging, and real incident workflows.
