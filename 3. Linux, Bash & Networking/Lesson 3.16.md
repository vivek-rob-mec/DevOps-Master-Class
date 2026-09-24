# Lesson 3.16 — Deep Networking Troubleshooting

Now we go from networking basics to **real troubleshooting workflows**.

In production, networking problems are rarely solved by one command. You need to separate layers:

```text
DNS
Routing
Firewall
TCP connection
TLS handshake
HTTP response
Reverse proxy
Backend service
Application logs
```

A beginner runs:

```bash
ping api.example.com
```

A DevOps engineer runs:

```bash
dig +short api.example.com
ip route get <resolved-ip>
nc -vz api.example.com 443
curl -Iv https://api.example.com
curl -w timing-format https://api.example.com
openssl s_client -connect api.example.com:443 -servername api.example.com
journalctl -u nginx -n 100
sudo ss -tulnp
```

---

# 1. Deep Troubleshooting Mental Model

When a request fails, do not randomly try commands.

Use this flow:

```text
1. Name resolution
2. Route selection
3. Network reachability
4. TCP port connectivity
5. TLS handshake
6. HTTP request/response
7. Reverse proxy/load balancer
8. Backend service
9. Logs and metrics
```

Example:

```bash
curl https://api.example.com/health
```

Can fail because:

```text
DNS does not resolve
DNS resolves to wrong IP
Route missing
Security group blocks traffic
Service not listening on 443
TLS certificate invalid
Nginx returns 502
Backend app down
Backend app returns 500
Database timeout behind backend
```

So we troubleshoot layer by layer.

---

# 2. Quick Network Triage Checklist

For any host and port:

```bash
HOST="api.example.com"
PORT="443"

getent hosts "$HOST"
dig +short "$HOST"
ip route get "$(getent hosts "$HOST" | awk '{print $1}' | head -1)"
nc -vz "$HOST" "$PORT"
curl -Iv "https://$HOST"
```

For local backend:

```bash
sudo ss -tulnp | grep ':3000'
curl -v http://127.0.0.1:3000/health
journalctl -u todo-api -n 100
```

For Nginx reverse proxy:

```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -n 100 /var/log/nginx/error.log
sudo tail -n 100 /var/log/nginx/access.log
```

---

# 3. `curl -v` Deep Dive

`curl -v` shows connection details.

```bash
curl -v https://example.com
```

You may see:

```text
*   Trying 93.184.216.34:443...
* Connected to example.com (93.184.216.34) port 443
* ALPN: curl offers h2,http/1.1
* TLS handshake...
> GET / HTTP/1.1
> Host: example.com
< HTTP/2 200
```

Important sections:

```text
Trying                 DNS resolved and curl is attempting TCP connection
Connected              TCP connection succeeded
TLS handshake           HTTPS negotiation
> lines                 request headers sent by client
< lines                 response headers received from server
HTTP status             application/proxy response
```

If it fails at `Trying`, likely connection/routing/firewall.

If it fails at TLS, certificate/protocol/SNI issue.

If it returns 502/504, likely upstream/backend issue.

---

# 4. `curl -I` Headers Only

Use:

```bash
curl -I https://example.com
```

This sends a HEAD request.

Useful for:

```text
Checking status code
Checking redirects
Checking server headers
Checking cache headers
Checking TLS availability quickly
```

Example:

```bash
curl -I https://github.com
```

Output may include:

```text
HTTP/2 200
server: GitHub.com
content-type: text/html
strict-transport-security: ...
```

For redirects:

```bash
curl -I http://example.com
```

You may see:

```text
HTTP/1.1 301 Moved Permanently
Location: https://example.com/
```

Follow redirects:

```bash
curl -IL http://example.com
```

---

# 5. `curl` Status and Timing

A very useful command:

```bash
curl -o /dev/null -s -w "status=%{http_code} total=%{time_total}s\n" https://example.com
```

Better timing details:

```bash
curl -o /dev/null -s -w \
"dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s starttransfer=%{time_starttransfer}s total=%{time_total}s status=%{http_code}\n" \
https://example.com
```

Meaning:

```text
time_namelookup      DNS lookup time
time_connect         TCP connect completed
time_appconnect      TLS handshake completed
time_starttransfer   time to first byte
time_total           total request time
http_code            HTTP status
```

Interpretation:

```text
High DNS time              DNS resolver issue
High connect time          network/firewall/route issue
High TLS time              TLS/server negotiation issue
High starttransfer time    backend/app/database slow
High total time            large response or slow backend/network
```

---

# 6. Create Curl Timing Script

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/curl-timing.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

URL="${1:-}"

if [ -z "$URL" ]; then
  echo "Usage: $0 <url>" >&2
  echo "Example: $0 https://example.com" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required" >&2
  exit 1
fi

curl -o /dev/null -sS \
  --connect-timeout 10 \
  --max-time 30 \
  -w "url=%{url_effective}\nstatus=%{http_code}\ndns=%{time_namelookup}s\nconnect=%{time_connect}s\ntls=%{time_appconnect}s\nstarttransfer=%{time_starttransfer}s\ntotal=%{time_total}s\nremote_ip=%{remote_ip}\nremote_port=%{remote_port}\n" \
  "$URL"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/curl-timing.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/curl-timing.sh https://github.com
```

---

# 7. DNS Debugging

Use multiple tools because they answer slightly different questions.

System resolver:

```bash
getent hosts example.com
```

DNS query:

```bash
dig example.com
```

Short output:

```bash
dig +short example.com
```

Query specific DNS server:

```bash
dig @8.8.8.8 example.com
dig @1.1.1.1 example.com
```

Trace DNS delegation:

```bash
dig +trace example.com
```

Check record types:

```bash
dig A example.com
dig AAAA example.com
dig CNAME www.example.com
dig MX example.com
dig TXT example.com
dig NS example.com
```

Check local DNS config:

```bash
cat /etc/resolv.conf
cat /etc/nsswitch.conf | grep '^hosts:'
```

On systemd-resolved systems:

```bash
resolvectl status
resolvectl query example.com
```

---

# 8. DNS Problem Patterns

## DNS does not resolve

```bash
getent hosts api.example.com
```

No output.

Possible causes:

```text
Record does not exist
Wrong domain
Private DNS not available from current network
Resolver issue
/etc/resolv.conf wrong
VPN not connected
```

## DNS resolves to wrong IP

```bash
dig +short api.example.com
```

Possible causes:

```text
Wrong A/CNAME record
Old DNS cache
Split-horizon DNS confusion
Wrong environment domain
/etc/hosts override
```

Check:

```bash
grep api.example.com /etc/hosts
```

## Public DNS works, system resolver fails

```bash
dig @8.8.8.8 api.example.com
getent hosts api.example.com
```

If public DNS works but `getent` fails, local resolver config may be broken.

---

# 9. DNS TTL

TTL means Time To Live.

Check:

```bash
dig example.com
```

Output has a number like:

```text
example.com.  300  IN  A  93.184.216.34
```

`300` means DNS response can be cached for 300 seconds.

Why it matters:

```text
DNS changes are not always instant.
Clients and resolvers may cache old values until TTL expires.
```

Production rule:

```text
Before planned DNS migration, reduce TTL ahead of time.
After migration, increase TTL again if appropriate.
```

---

# 10. Routing Debugging

Show route table:

```bash
ip route
```

Route to destination:

```bash
ip route get 8.8.8.8
```

For a resolved host:

```bash
HOST="github.com"
IP="$(getent hosts "$HOST" | awk '{print $1}' | head -1)"
ip route get "$IP"
```

Output example:

```text
140.82.114.3 via 192.168.1.1 dev eth0 src 192.168.1.50
```

Meaning:

```text
Destination: 140.82.114.3
Gateway: 192.168.1.1
Interface: eth0
Source IP: 192.168.1.50
```

Useful when server has multiple interfaces, VPN, Docker bridges, or cloud private networks.

---

# 11. `traceroute`

`traceroute` shows path hops.

Install:

```bash
sudo apt install -y traceroute
```

Run:

```bash
traceroute github.com
```

For TCP traceroute to HTTPS port:

```bash
sudo traceroute -T -p 443 github.com
```

Why TCP traceroute can be better:

```text
ICMP/UDP traceroute may be blocked.
TCP 443 resembles actual HTTPS traffic.
```

Important:

```text
Traceroute output can be incomplete because intermediate routers may block replies.
Asterisks do not always mean failure.
```

---

# 12. `mtr`

`mtr` combines ping and traceroute continuously.

Install:

```bash
sudo apt install -y mtr
```

Run:

```bash
mtr github.com
```

Report mode:

```bash
mtr -rw github.com
```

TCP mode to port 443:

```bash
sudo mtr -rw -T -P 443 github.com
```

Useful for:

```text
Packet loss investigation
Latency across path
Intermittent network issues
ISP/VPN routing issues
```

Interpret carefully:

```text
Packet loss at an intermediate hop may not matter if final destination has no loss.
Focus on final destination and persistent loss.
```

---

# 13. TCP Port Debugging with `nc`

Install:

```bash
sudo apt install -y netcat-openbsd
```

Test TCP:

```bash
nc -vz example.com 443
```

Success:

```text
Connection to example.com 443 port [tcp/https] succeeded!
```

Connection refused:

```text
Host reachable, port closed/no listener/active reject.
```

Timeout:

```text
Firewall/routing/security group/drop issue.
```

Use timeout:

```bash
timeout 5s nc -vz example.com 443
```

Test multiple ports:

```bash
for port in 22 80 443 3000; do
  echo "Checking $port"
  timeout 5s nc -vz example.com "$port" || true
done
```

---

# 14. Local Listener Debugging

On server, check:

```bash
sudo ss -tulnp
```

Specific port:

```bash
sudo ss -tulnp | grep ':3000'
```

Show established connections:

```bash
ss -tan
```

Show TCP states count:

```bash
ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -nr
```

Common TCP states:

```text
LISTEN        service waiting for connections
ESTAB         established connection
TIME-WAIT     recently closed connection waiting cleanup
SYN-SENT      client sent SYN, waiting response
SYN-RECV      server received SYN, waiting final ACK
CLOSE-WAIT    remote closed, local app has not closed yet
```

Lots of `CLOSE-WAIT` may indicate application not closing sockets properly.

Lots of `SYN-SENT` may indicate connection attempts not completing.

---

# 15. TLS Debugging with OpenSSL

For HTTPS/TLS:

```bash
openssl s_client -connect example.com:443 -servername example.com
```

Important:

```text
-servername enables SNI.
```

SNI matters because many servers host multiple domains on one IP.

Show certificate dates:

```bash
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
  | openssl x509 -noout -dates -subject -issuer
```

Output:

```text
notBefore=...
notAfter=...
subject=...
issuer=...
```

Check certificate chain:

```bash
openssl s_client -connect example.com:443 -servername example.com -showcerts
```

Common TLS problems:

```text
Expired certificate
Wrong certificate for domain
Missing intermediate certificate
TLS protocol mismatch
SNI missing/wrong
Backend speaks HTTP but client expects HTTPS
```

---

# 16. TLS with curl

Verbose TLS:

```bash
curl -Iv https://example.com
```

Ignore certificate verification for testing only:

```bash
curl -kIv https://example.com
```

Important:

```text
-k is insecure.
Use only for debugging, never as a real fix.
```

If `curl -k` works but normal curl fails:

```text
Certificate validation problem.
```

Check:

```bash
openssl s_client -connect host:443 -servername host
```

---

# 17. HTTP Host Header Debugging

Sometimes you need to connect to an IP but send a specific Host header.

Example:

```bash
curl -v http://1.2.3.4 -H "Host: api.example.com"
```

For HTTPS, better use `--resolve`:

```bash
curl -v --resolve api.example.com:443:1.2.3.4 https://api.example.com/
```

Meaning:

```text
For this curl command only, resolve api.example.com:443 to 1.2.3.4.
```

This is extremely useful for testing:

```text
New load balancer before DNS cutover
Specific backend IP
TLS/SNI with domain name
Blue-green environments
```

Example:

```bash
curl -Iv --resolve yourdatascientist.tech:443:203.0.113.10 https://yourdatascientist.tech/
```

---

# 18. Firewall Debugging

Linux firewall with UFW:

```bash
sudo ufw status verbose
```

iptables:

```bash
sudo iptables -S
sudo iptables -L -n -v
```

nftables:

```bash
sudo nft list ruleset
```

Which one is active depends on distro/setup.

Ubuntu often uses UFW as frontend.

Check listening service first:

```bash
sudo ss -tulnp | grep ':80'
```

Then firewall:

```bash
sudo ufw status verbose
```

Then cloud firewall/security group.

Production checklist:

```text
Service listening?
Linux firewall allows?
Cloud security group allows?
Network ACL allows?
Route table correct?
Target health check path correct?
```

---

# 19. `tcpdump` Introduction

`tcpdump` captures packets.

Install:

```bash
sudo apt install -y tcpdump
```

List interfaces:

```bash
ip -br addr
```

Capture traffic on port 80:

```bash
sudo tcpdump -i any port 80
```

Capture host and port:

```bash
sudo tcpdump -i any host 1.2.3.4 and port 443
```

Capture DNS:

```bash
sudo tcpdump -i any port 53
```

Write to file:

```bash
sudo tcpdump -i any port 443 -w capture.pcap
```

Read file:

```bash
tcpdump -r capture.pcap
```

Important:

```text
tcpdump can expose sensitive data and metadata.
Use carefully and avoid sharing captures casually.
```

---

# 20. tcpdump Practical Interpretation

Scenario: client cannot reach server port 3000.

On server, run:

```bash
sudo tcpdump -i any port 3000
```

From client, run:

```bash
nc -vz server-ip 3000
```

Interpretation:

```text
No packets seen on server:
  traffic not reaching server: SG/NACL/route/firewall before host

SYN packets seen but no SYN-ACK:
  service not listening or local firewall issue

SYN and SYN-ACK seen:
  TCP handshake likely works; check app/proxy

HTTP request seen but no good response:
  application/proxy issue
```

tcpdump helps prove whether packets reached the machine.

---

# 21. Nginx 502 Deep Workflow

Problem:

```text
User sees 502 Bad Gateway.
```

Step 1: Check response:

```bash
curl -Iv https://api.example.com
```

Step 2: Check Nginx error log:

```bash
sudo tail -n 100 /var/log/nginx/error.log
```

Common error:

```text
connect() failed (111: Connection refused) while connecting to upstream
```

Meaning:

```text
Nginx reached upstream IP/port, but nothing was listening.
```

Check backend:

```bash
sudo ss -tulnp | grep ':3000'
systemctl status todo-api
journalctl -u todo-api -n 100
curl -v http://127.0.0.1:3000/health
```

Another error:

```text
upstream timed out
```

Meaning:

```text
Backend accepted connection but did not respond in time.
```

Check app logs, DB latency, CPU/memory:

```bash
journalctl -u todo-api --since "30 minutes ago"
free -h
uptime
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head
```

---

# 22. Load Balancer Health Check Workflow

Problem:

```text
ALB target is unhealthy.
```

On instance:

```bash
sudo ss -tulnp | grep ':3000'
curl -v http://127.0.0.1:3000/health
curl -v http://PRIVATE_IP:3000/health
```

Important difference:

```text
127.0.0.1 works but PRIVATE_IP fails:
  app is bound only to localhost
```

Fix app binding or proxy design.

Check security group:

```text
ALB security group should be allowed to reach instance security group on target port.
```

Good pattern:

```text
Inbound on app instance:
  port 3000 from ALB security group only
```

Check NACL/routing if needed.

Check health path:

```text
ALB health check path must match real app endpoint.
Example: /health
```

App must return 200 for health check.

---

# 23. Database Connectivity Workflow

Problem:

```text
Backend cannot connect to MongoDB/PostgreSQL/MySQL.
```

From backend host:

```bash
nc -vz db-host 27017
nc -vz db-host 5432
nc -vz db-host 3306
```

DNS:

```bash
getent hosts db-host
```

Route:

```bash
ip route get "$(getent hosts db-host | awk '{print $1}' | head -1)"
```

If port timeout:

```text
Security group/firewall/routing issue.
```

If refused:

```text
DB not listening on that interface/port or local firewall actively rejects.
```

If TCP works but app fails:

```text
Credentials/auth/TLS/database name/client config issue.
```

Check app logs:

```bash
journalctl -u todo-api -n 100
```

---

# 24. Create Deep Network Debug Script

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/deep-network-debug.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

HOST=""
PORT=""
SCHEME="https"
PATH_VALUE="/"
SINCE="30 minutes ago"

usage() {
  cat <<EOF
Usage: $0 --host <host> [options]

Options:
  --host <host>       Hostname or IP
  --port <port>       Port to test
  --scheme <scheme>   http or https. Default: https
  --path <path>       HTTP path. Default: /
  --since <time>      Local journal time window. Default: "30 minutes ago"
  -h, --help          Show help

Examples:
  $0 --host github.com --port 443 --scheme https
  $0 --host 127.0.0.1 --port 8080 --scheme http --path /
EOF
}

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --host)
        HOST="${2:-}"
        [ -n "$HOST" ] || die "--host requires a value"
        shift 2
        ;;
      --port)
        PORT="${2:-}"
        [ -n "$PORT" ] || die "--port requires a value"
        shift 2
        ;;
      --scheme)
        SCHEME="${2:-}"
        [ -n "$SCHEME" ] || die "--scheme requires a value"
        shift 2
        ;;
      --path)
        PATH_VALUE="${2:-}"
        [ -n "$PATH_VALUE" ] || die "--path requires a value"
        shift 2
        ;;
      --since)
        SINCE="${2:-}"
        [ -n "$SINCE" ] || die "--since requires a value"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

validate_inputs() {
  [ -n "$HOST" ] || die "--host is required"

  if [ -n "$PORT" ] && ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    die "--port must be numeric"
  fi

  if [ "$SCHEME" != "http" ] && [ "$SCHEME" != "https" ]; then
    die "--scheme must be http or https"
  fi

  if [ -z "$PORT" ]; then
    if [ "$SCHEME" = "https" ]; then
      PORT="443"
    else
      PORT="80"
    fi
  fi
}

main() {
  parse_args "$@"
  validate_inputs

  local url="${SCHEME}://${HOST}:${PORT}${PATH_VALUE}"

  section "Input"
  echo "Host: $HOST"
  echo "Port: $PORT"
  echo "Scheme: $SCHEME"
  echo "Path: $PATH_VALUE"
  echo "URL: $url"
  echo "Time: $(date -Is)"

  section "Local Interfaces"
  ip -br addr || true

  section "DNS Resolution"
  getent hosts "$HOST" || true
  if command -v dig >/dev/null 2>&1; then
    echo
    dig +short "$HOST" || true
  fi

  section "Route"
  local resolved_ip
  resolved_ip="$(getent hosts "$HOST" | awk '{print $1}' | head -1 || true)"

  if [ -n "$resolved_ip" ]; then
    echo "Resolved IP: $resolved_ip"
    ip route get "$resolved_ip" || true
  else
    echo "No resolved IP available"
  fi

  section "TCP Port Connectivity"
  if command -v nc >/dev/null 2>&1; then
    timeout 10s nc -vz "$HOST" "$PORT" || true
  else
    echo "nc not installed"
  fi

  section "HTTP/TLS Curl Verbose"
  if command -v curl >/dev/null 2>&1; then
    curl -Iv --connect-timeout 10 --max-time 20 "$url" || true
  else
    echo "curl not installed"
  fi

  section "Curl Timing"
  if command -v curl >/dev/null 2>&1; then
    curl -o /dev/null -sS \
      --connect-timeout 10 \
      --max-time 30 \
      -w "status=%{http_code}\ndns=%{time_namelookup}s\nconnect=%{time_connect}s\ntls=%{time_appconnect}s\nstarttransfer=%{time_starttransfer}s\ntotal=%{time_total}s\nremote_ip=%{remote_ip}\nremote_port=%{remote_port}\n" \
      "$url" || true
  fi

  if [ "$SCHEME" = "https" ]; then
    section "TLS Certificate"
    if command -v openssl >/dev/null 2>&1; then
      echo | openssl s_client -connect "${HOST}:${PORT}" -servername "$HOST" 2>/dev/null \
        | openssl x509 -noout -dates -subject -issuer || true
    else
      echo "openssl not installed"
    fi
  fi

  section "Traceroute"
  if command -v traceroute >/dev/null 2>&1; then
    traceroute "$HOST" || true
  else
    echo "traceroute not installed"
  fi

  section "Local Listening Ports"
  sudo ss -tulnp 2>/dev/null || ss -tuln || true

  section "Recent Local Network/System Errors"
  if command -v journalctl >/dev/null 2>&1; then
    journalctl --since "$SINCE" -p err --no-pager || true
  else
    echo "journalctl not found"
  fi

  echo
  echo "Done."
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/deep-network-debug.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/deep-network-debug.sh \
  --host github.com \
  --port 443 \
  --scheme https
```

Test local:

```bash
python3 -m http.server 8080 &
HTTP_PID=$!

./03-linux-bash-networking/scripts/deep-network-debug.sh \
  --host 127.0.0.1 \
  --port 8080 \
  --scheme http

kill "$HTTP_PID"
```

---

# 25. Create TLS Certificate Check Script

Create:

```bash
nano 03-linux-bash-networking/scripts/tls-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
PORT="${2:-443}"

if [ -z "$HOST" ]; then
  echo "Usage: $0 <host> [port]" >&2
  echo "Example: $0 example.com 443" >&2
  exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: port must be numeric" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is required" >&2
  exit 1
fi

echo "===== TLS Certificate Check ====="
echo "Host: $HOST"
echo "Port: $PORT"
echo "Time: $(date -Is)"
echo

echo | openssl s_client -connect "${HOST}:${PORT}" -servername "$HOST" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -serial -fingerprint -sha256

echo
echo "===== Verification with curl ====="
if command -v curl >/dev/null 2>&1; then
  curl -Iv --connect-timeout 10 --max-time 20 "https://${HOST}:${PORT}" || true
else
  echo "curl not installed"
fi
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/tls-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/tls-check.sh github.com
```

---

# 26. Create DNS Debug Script

Create:

```bash
nano 03-linux-bash-networking/scripts/dns-debug.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain>" >&2
  echo "Example: $0 example.com" >&2
  exit 1
fi

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

section "System Resolver"
getent hosts "$DOMAIN" || true

section "/etc/hosts Override Check"
grep -n "$DOMAIN" /etc/hosts || echo "No /etc/hosts entry found for $DOMAIN"

section "Resolver Config"
cat /etc/resolv.conf || true

section "nsswitch hosts"
grep '^hosts:' /etc/nsswitch.conf || true

if command -v resolvectl >/dev/null 2>&1; then
  section "resolvectl query"
  resolvectl query "$DOMAIN" || true
fi

if command -v dig >/dev/null 2>&1; then
  section "dig A"
  dig A "$DOMAIN" || true

  section "dig AAAA"
  dig AAAA "$DOMAIN" || true

  section "dig CNAME"
  dig CNAME "$DOMAIN" || true

  section "dig +short"
  dig +short "$DOMAIN" || true

  section "dig @8.8.8.8"
  dig @8.8.8.8 "$DOMAIN" +short || true

  section "dig @1.1.1.1"
  dig @1.1.1.1 "$DOMAIN" +short || true
else
  echo "dig not installed. Install: sudo apt install -y dnsutils"
fi
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/dns-debug.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/dns-debug.sh github.com
```

---

# 27. Create Notes

Create:

```bash
nano 03-linux-bash-networking/deep-network-troubleshooting.md
```

Paste:

````markdown
# Deep Networking Troubleshooting

## Troubleshooting Layers

```text
DNS
Route
Reachability
TCP port
TLS
HTTP
Reverse proxy/load balancer
Backend service
Application logs
````

## curl Commands

```bash
curl -v https://example.com
curl -I https://example.com
curl -IL http://example.com
curl -o /dev/null -s -w "status=%{http_code} total=%{time_total}s\n" https://example.com
curl -o /dev/null -s -w "dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} starttransfer=%{time_starttransfer} total=%{time_total}\n" https://example.com
curl --resolve example.com:443:1.2.3.4 https://example.com/
```

## DNS Commands

```bash
getent hosts example.com
dig +short example.com
dig @8.8.8.8 example.com
dig A example.com
dig CNAME www.example.com
dig MX example.com
dig TXT example.com
cat /etc/resolv.conf
grep '^hosts:' /etc/nsswitch.conf
```

## Routing Commands

```bash
ip route
ip route get 8.8.8.8
traceroute example.com
sudo traceroute -T -p 443 example.com
mtr -rw example.com
sudo mtr -rw -T -P 443 example.com
```

## TCP and TLS

```bash
nc -vz host port
timeout 5s nc -vz host port
openssl s_client -connect example.com:443 -servername example.com
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -noout -dates -subject -issuer
```

## tcpdump

```bash
sudo tcpdump -i any port 443
sudo tcpdump -i any host 1.2.3.4 and port 443
sudo tcpdump -i any port 53
sudo tcpdump -i any port 443 -w capture.pcap
tcpdump -r capture.pcap
```

## Rules

* Use `getent hosts` to test system resolver behavior.
* Use `dig` to query DNS directly.
* Use `ip route get` to verify route and source IP.
* Use `nc` to test TCP port connectivity.
* Use `curl -v` to inspect HTTP/TLS flow.
* Use curl timing to separate DNS, connect, TLS, and backend latency.
* Use `openssl s_client` for certificate/SNI debugging.
* Use `tcpdump` to prove whether packets reach a host.
* Use `--resolve` to test DNS cutovers before changing public DNS.

````

---

# 28. Commit Work

Run:

```bash
git status
git diff
````

Add:

```bash
git add 03-linux-bash-networking/deep-network-troubleshooting.md \
        03-linux-bash-networking/scripts/curl-timing.sh \
        03-linux-bash-networking/scripts/deep-network-debug.sh \
        03-linux-bash-networking/scripts/tls-check.sh \
        03-linux-bash-networking/scripts/dns-debug.sh
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "docs: add deep networking troubleshooting"
git push
```

---

# 29. Real Incident Workflow — Website Down

Incident:

```text
https://app.example.com is not opening.
```

Step 1: DNS:

```bash
getent hosts app.example.com
dig +short app.example.com
```

Step 2: TCP/TLS/HTTP:

```bash
curl -Iv https://app.example.com
./curl-timing.sh https://app.example.com
```

Step 3: If 502:

```bash
sudo tail -n 100 /var/log/nginx/error.log
sudo ss -tulnp
curl -v http://127.0.0.1:3000/health
systemctl status todo-api
journalctl -u todo-api -n 100
```

Step 4: If timeout:

```bash
nc -vz app.example.com 443
traceroute app.example.com
```

Check cloud load balancer, SG, NACL, instance health.

Step 5: If TLS error:

```bash
./tls-check.sh app.example.com
```

Check certificate expiry, domain mismatch, chain.

---

# 30. Real Incident Workflow — Backend Cannot Reach Database

From backend host:

```bash
getent hosts db.internal
dig +short db.internal
nc -vz db.internal 5432
ip route get "$(getent hosts db.internal | awk '{print $1}' | head -1)"
```

If timeout:

```text
Check DB security group/firewall/routing/private subnet/NACL.
```

If refused:

```text
Check DB process listening address and port.
```

On DB host:

```bash
sudo ss -tulnp | grep ':5432'
sudo ufw status verbose
journalctl -u postgresql -n 100
```

If TCP works but app fails:

```text
Check DB credentials, TLS requirement, database name, auth rules, app config.
```

---

# 31. Real Incident Workflow — Load Balancer 504

504 means gateway timeout.

Likely:

```text
Load balancer/proxy connected to backend but backend did not respond in time,
or could not complete upstream request in configured timeout.
```

Check:

```bash
curl -Iv https://api.example.com/slow-endpoint
```

On backend:

```bash
journalctl -u todo-api --since "30 minutes ago"
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head
free -h
uptime
```

Check DB/dependency latency:

```bash
grep -Ei "timeout|slow|database|redis|mongo" /var/log/todo-api/app.log
```

Possible causes:

```text
Slow database query
Backend CPU saturation
Backend waiting on external API
Thread/connection pool exhaustion
Network path to dependency slow
Bad deployment
```

---

# 32. Interview Answers

Question:

```text
How do you troubleshoot a website connectivity issue?
```

Strong answer:

```text
I troubleshoot layer by layer. First I check DNS with getent hosts and dig to verify the domain resolves to the expected IP or load balancer. Then I check routing with ip route get and TCP connectivity with nc. For HTTPS, I use curl -Iv to inspect TCP, TLS, headers, status codes, and redirects. I use curl timing to identify whether latency is DNS, connect, TLS, or backend time. If the response is 502/504, I check reverse proxy and backend logs, service status, listening ports, and health endpoints.
```

Question:

```text
How do you debug TLS certificate issues?
```

Strong answer:

```text
I use curl -Iv to see the TLS error and openssl s_client with -servername to check the certificate served with SNI. I inspect the certificate subject, issuer, validity dates, and chain. If curl works with -k but not normally, it confirms a certificate validation issue. Common causes are expired certificates, wrong domain, missing intermediate certificates, or the server presenting the wrong certificate due to SNI or proxy configuration.
```

Question:

```text
When would you use tcpdump?
```

Strong answer:

```text
I use tcpdump when I need packet-level evidence, especially to prove whether traffic reaches a host or interface. For example, if a client cannot connect to a server port, I can run tcpdump on the server while testing from the client. If no packets arrive, the issue is likely before the host, such as route, security group, NACL, or firewall. If SYN packets arrive but no response is sent, I check local firewall or service listening state.
```

Question:

```text
How do you interpret curl timing?
```

Strong answer:

```text
Curl timing separates the request into phases. High time_namelookup points to DNS issues. High time_connect points to TCP/network/firewall latency. High time_appconnect points to TLS handshake problems. High time_starttransfer usually means the server or backend was slow to generate the first byte. High total time can mean a slow response body or overall network/backend slowness.
```

---

# Today’s Core Rules

```text
Troubleshoot networking layer by layer.
Use getent and dig for DNS.
Use ip route get for route decisions.
Use nc for TCP connectivity.
Use curl -v for HTTP/TLS details.
Use curl timing to locate latency phase.
Use openssl s_client for TLS/SNI/certificate issues.
Use traceroute/mtr for path and packet loss clues.
Use tcpdump when you need packet-level proof.
502 usually points to upstream/backend connection failure.
504 usually points to upstream/backend timeout.
Timeout and refused are different.
```

Next lesson:

# Lesson 3.17 — Linux Security Basics: SSH hardening, firewall rules, least privilege, secrets handling, audit logs, fail2ban, and baseline server hardening.
