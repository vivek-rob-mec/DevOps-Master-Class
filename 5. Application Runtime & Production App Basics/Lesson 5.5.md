# Lesson 5.5 — Reverse Proxy with Nginx

# Public Port 80/443 to Internal App Port

Until now, your Node app runs on an internal port:

```text id="p9d2wh"
demo-node-api → port 3000
```

But production users usually access apps through:

```text id="t67a6n"
http://yourdomain.com
https://yourdomain.com
```

That means public traffic usually comes through:

```text id="3n0w4x"
port 80  → HTTP
port 443 → HTTPS
```

Your app should not usually bind directly to public port 80/443.

Instead, we use a **reverse proxy**.

---

# 1. What Is a Reverse Proxy?

A reverse proxy sits in front of your application.

```text id="lk6l3p"
User Browser
  ↓
Nginx on port 80/443
  ↓
Node app on port 3000
```

Nginx accepts public traffic and forwards it to the internal app.

Example:

```text id="3vdsx5"
http://server-ip/
  ↓
Nginx :80
  ↓
http://127.0.0.1:3000
```

The user never needs to know port `3000`.

---

# 2. Why Use Nginx?

Nginx gives production features:

```text id="7w01yk"
public HTTP/HTTPS entrypoint
reverse proxy routing
TLS termination
static file serving
request headers
compression
timeouts
rate limiting
basic security headers
access/error logs
health route forwarding
multiple apps on one server
```

Without Nginx:

```text id="u5ewav"
User → Node app directly on port 3000
```

With Nginx:

```text id="6umugm"
User → Nginx on 80/443 → Node app on 3000
```

Production rule:

```text id="w7ltpb"
Expose Nginx publicly. Keep app ports private/internal.
```

---

# 3. Reverse Proxy vs Forward Proxy

## Forward proxy

Used by clients.

```text id="tpo46g"
User → Proxy → Internet
```

Example:

```text id="cxj4kw"
corporate proxy
VPN proxy
browser proxy
```

## Reverse proxy

Used by servers.

```text id="s0l07h"
Internet → Reverse Proxy → App Servers
```

Example:

```text id="qfcbax"
Nginx
HAProxy
AWS ALB
CloudFront
Traefik
Envoy
```

In DevOps deployments, we usually mean reverse proxy.

---

# 4. Target Architecture for This Lab

```text id="v4updm"
Browser/curl
  ↓
Nginx :80
  ↓
127.0.0.1:3000
  ↓
demo-node-api
```

Endpoints:

```text id="2y4585"
http://127.0.0.1/health  → Nginx → app /health
http://127.0.0.1/ready   → Nginx → app /ready
http://127.0.0.1/version → Nginx → app /version
```

---

# 5. Install Nginx

Run:

```bash id="qjyy8w"
sudo apt update
sudo apt install -y nginx
```

Check:

```bash id="q1ksod"
nginx -v
sudo systemctl status nginx --no-pager
```

Start and enable:

```bash id="zt7co1"
sudo systemctl start nginx
sudo systemctl enable nginx
```

Check port 80:

```bash id="8tlbp8"
ss -tuln | grep ':80'
```

Test default page:

```bash id="ddor1v"
curl -I http://127.0.0.1
```

Expected:

```text id="fky4lt"
HTTP/1.1 200 OK
```

---

# 6. Make Sure App Is Running

Use PM2 or systemd from Lesson 5.4.

For quick PM2 run:

```bash id="ae8359"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

pm2 delete demo-node-api || true
APP_ENV=dev PORT=3000 LOG_LEVEL=info LOAD_DOTENV=false \
pm2 start server.js --name demo-node-api
```

Check app directly:

```bash id="1brk1h"
curl -s http://127.0.0.1:3000/health | jq .
```

Check port:

```bash id="otwknd"
ss -tuln | grep ':3000'
```

---

# 7. Create Nginx Site Config

Create:

```bash id="dx0yjr"
sudo nano /etc/nginx/sites-available/demo-node-api
```

Paste:

```nginx id="pgzbrp"
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/demo-node-api-access.log;
    error_log  /var/log/nginx/demo-node-api-error.log;

    location / {
        proxy_pass http://127.0.0.1:3000;

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

Enable site:

```bash id="vaegbd"
sudo ln -sf /etc/nginx/sites-available/demo-node-api /etc/nginx/sites-enabled/demo-node-api
```

Disable default site:

```bash id="tyfzn7"
sudo rm -f /etc/nginx/sites-enabled/default
```

Test config:

```bash id="avlwzc"
sudo nginx -t
```

Reload:

```bash id="p2meqb"
sudo systemctl reload nginx
```

---

# 8. Test Reverse Proxy

Now test through Nginx:

```bash id="idmtxw"
curl -s http://127.0.0.1/ | jq .
curl -s http://127.0.0.1/health | jq .
curl -s http://127.0.0.1/ready | jq .
curl -s http://127.0.0.1/version | jq .
```

Direct app:

```bash id="5yekf0"
curl -s http://127.0.0.1:3000/health | jq .
```

Through Nginx:

```bash id="puvv4l"
curl -s http://127.0.0.1/health | jq .
```

Both should work.

This proves:

```text id="77ls8z"
Nginx :80 → app :3000
```

---

# 9. Understanding `proxy_pass`

This line is the core:

```nginx id="7chhr4"
proxy_pass http://127.0.0.1:3000;
```

It means:

```text id="aqhs97"
Forward matching requests to app running at 127.0.0.1:3000
```

Nginx listens publicly on:

```nginx id="7j3yfn"
listen 80;
```

App listens internally on:

```text id="pc3wwa"
127.0.0.1:3000 or 0.0.0.0:3000
```

---

# 10. Why Proxy Headers Matter

These headers preserve important request information.

```nginx id="c70kx8"
proxy_set_header Host $host;
```

Passes original hostname.

```nginx id="awlnyn"
proxy_set_header X-Real-IP $remote_addr;
```

Passes client IP.

```nginx id="etw3lk"
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

Passes proxy chain of client IPs.

```nginx id="gbpdmj"
proxy_set_header X-Forwarded-Proto $scheme;
```

Tells app whether original request was HTTP or HTTPS.

```nginx id="xhwea8"
proxy_set_header X-Request-ID $request_id;
```

Adds request ID for tracing.

These are important for:

```text id="r8irnu"
logs
security
redirects
rate limiting
debugging
audit trails
```

---

# 11. Update App to Trust Proxy Request Info

Express needs proxy awareness if behind Nginx.

Open:

```bash id="wea3lj"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
nano server.js
```

After:

```javascript id="13jcqh"
const app = express();
```

Add:

```javascript id="rvwlkk"
app.set("trust proxy", true);
```

This helps Express understand proxy headers like `X-Forwarded-For`.

Restart app:

```bash id="iig5ax"
pm2 restart demo-node-api
```

Test:

```bash id="ow9e7u"
curl -s -H "x-request-id: nginx-test-123" http://127.0.0.1/health | jq .
```

Check app logs:

```bash id="a7488i"
pm2 logs demo-node-api --lines 20
```

You should see request logs with request ID.

---

# 12. Nginx Access Logs

Check Nginx access logs:

```bash id="r0hm83"
sudo tail -f /var/log/nginx/demo-node-api-access.log
```

In another terminal:

```bash id="l6t1xj"
curl -s http://127.0.0.1/health | jq .
curl -s http://127.0.0.1/simulate-error
```

You should see access log entries.

Nginx logs answer:

```text id="kx91ak"
Which client requested what?
What HTTP status was returned?
How many bytes?
Which user agent?
```

App logs answer:

```text id="puu7ww"
What did the app do internally?
How long did request handling take?
Was there app-level error logic?
```

Both are useful.

---

# 13. Nginx Error Logs

Check:

```bash id="bpljxz"
sudo tail -f /var/log/nginx/demo-node-api-error.log
```

Stop app:

```bash id="i1vjv6"
pm2 stop demo-node-api
```

Request through Nginx:

```bash id="urq9hr"
curl -i http://127.0.0.1/health
```

Expected:

```text id="m37542"
HTTP/1.1 502 Bad Gateway
```

Why?

```text id="w8gz3g"
Nginx is running, but upstream app is unavailable.
```

Check error log:

```bash id="0hjp45"
sudo tail -n 50 /var/log/nginx/demo-node-api-error.log
```

Start app again:

```bash id="vhdqhk"
pm2 start demo-node-api
```

Test:

```bash id="p8hh4s"
curl -i http://127.0.0.1/health
```

---

# 14. Important Nginx Status Codes

Common reverse proxy status codes:

```text id="01vrp8"
200 OK
301/302 redirect
400 bad request
403 forbidden
404 not found
413 payload too large
499 client closed request
500 internal server error
502 bad gateway
503 service unavailable
504 gateway timeout
```

Important ones:

## 502 Bad Gateway

Usually:

```text id="0sxmun"
upstream app is down
wrong proxy_pass port
connection refused
app crashed
```

Debug:

```bash id="zmi2gf"
curl http://127.0.0.1:3000/health
sudo ss -tulnp | grep ':3000'
sudo tail -n 50 /var/log/nginx/demo-node-api-error.log
```

## 504 Gateway Timeout

Usually:

```text id="k48e7t"
upstream app too slow
proxy_read_timeout exceeded
app stuck
database slow
```

Debug:

```bash id="x4hb6i"
check app logs
check duration_ms
check database/API dependencies
increase timeout only if justified
```

## 413 Payload Too Large

Usually:

```text id="q23tdw"
client uploaded body larger than Nginx limit
```

Fix with:

```nginx id="8pyrp1"
client_max_body_size 10m;
```

---

# 15. Add Custom Nginx Log Format with Request ID

Default logs are okay, but production logs should include request ID.

Create Nginx config snippet:

```bash id="p6rc7a"
sudo nano /etc/nginx/conf.d/log-format.conf
```

Paste:

```nginx id="4aeomx"
log_format main_with_request_id
    '$remote_addr - $remote_user [$time_local] '
    '"$request" $status $body_bytes_sent '
    '"$http_referer" "$http_user_agent" '
    'request_id="$request_id" '
    'upstream_addr="$upstream_addr" '
    'upstream_status="$upstream_status" '
    'request_time="$request_time" '
    'upstream_response_time="$upstream_response_time"';
```

Update site config:

```bash id="3wtgsi"
sudo nano /etc/nginx/sites-available/demo-node-api
```

Change:

```nginx id="zkqw3c"
access_log /var/log/nginx/demo-node-api-access.log;
```

to:

```nginx id="uxm9wz"
access_log /var/log/nginx/demo-node-api-access.log main_with_request_id;
```

Test and reload:

```bash id="b0hpbq"
sudo nginx -t
sudo systemctl reload nginx
```

Generate request:

```bash id="jblndu"
curl -s http://127.0.0.1/health | jq .
```

Check log:

```bash id="2nt5lt"
sudo tail -n 5 /var/log/nginx/demo-node-api-access.log
```

Now you can connect:

```text id="7n45tb"
Nginx request ID
App request ID
```

---

# 16. Add Security Headers

Open site config:

```bash id="txtm21"
sudo nano /etc/nginx/sites-available/demo-node-api
```

Inside `server { ... }`, add:

```nginx id="xbs8zw"
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

Full example:

```nginx id="jmoe74"
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/demo-node-api-access.log main_with_request_id;
    error_log  /var/log/nginx/demo-node-api-error.log;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://127.0.0.1:3000;

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

Reload:

```bash id="gztpnw"
sudo nginx -t
sudo systemctl reload nginx
```

Check headers:

```bash id="099mnf"
curl -I http://127.0.0.1/health
```

You should see:

```text id="a4fvyk"
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
```

---

# 17. Add Dedicated Health Route in Nginx

Sometimes you want Nginx itself to respond for proxy health.

Add:

```nginx id="ygz24o"
location = /nginx-health {
    access_log off;
    return 200 "nginx ok\n";
}
```

Add inside `server {}` before `location /`.

Reload:

```bash id="b2vqan"
sudo nginx -t
sudo systemctl reload nginx
```

Test:

```bash id="id2s02"
curl -i http://127.0.0.1/nginx-health
```

Difference:

```text id="o7bjfu"
/nginx-health checks Nginx only
/health checks app through Nginx
```

Both are useful.

---

# 18. Add Body Size and Compression

For APIs with JSON payloads:

```nginx id="l4yj82"
client_max_body_size 2m;
```

For compression:

```nginx id="1ofimj"
gzip on;
gzip_types text/plain application/json application/javascript text/css;
gzip_min_length 1024;
```

Add inside `server {}` or http-level config.

For this demo, add inside `server {}`:

```nginx id="06zq81"
client_max_body_size 2m;

gzip on;
gzip_types text/plain application/json application/javascript text/css;
gzip_min_length 1024;
```

Reload:

```bash id="fs7daj"
sudo nginx -t
sudo systemctl reload nginx
```

---

# 19. Full Nginx Config Example

Final `/etc/nginx/sites-available/demo-node-api`:

```nginx id="nrmxpf"
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/demo-node-api-access.log main_with_request_id;
    error_log  /var/log/nginx/demo-node-api-error.log;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    client_max_body_size 2m;

    gzip on;
    gzip_types text/plain application/json application/javascript text/css;
    gzip_min_length 1024;

    location = /nginx-health {
        access_log off;
        return 200 "nginx ok\n";
    }

    location / {
        proxy_pass http://127.0.0.1:3000;

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

Validate:

```bash id="04n5bx"
sudo nginx -t
sudo systemctl reload nginx
```

---

# 20. Reverse Proxy Debugging Checklist

When app through Nginx fails:

## Step 1 — Is Nginx running?

```bash id="7fsrsw"
sudo systemctl status nginx --no-pager
```

## Step 2 — Is Nginx listening on 80?

```bash id="qlpim4"
ss -tuln | grep ':80'
```

## Step 3 — Is config valid?

```bash id="rkqkkb"
sudo nginx -t
```

## Step 4 — Is app running?

```bash id="kp6ks7"
pm2 list
curl -i http://127.0.0.1:3000/health
```

## Step 5 — Does proxy work?

```bash id="78bdvh"
curl -i http://127.0.0.1/health
```

## Step 6 — Check Nginx logs

```bash id="fdin67"
sudo tail -n 50 /var/log/nginx/demo-node-api-error.log
sudo tail -n 50 /var/log/nginx/demo-node-api-access.log
```

## Step 7 — Check app logs

```bash id="ziat8l"
pm2 logs demo-node-api --lines 100
```

---

# 21. Add Nginx Config to Repo

Create examples folder:

```bash id="btcxwz"
cd ~/devops-masterclass/05-application-runtime
mkdir -p examples/nginx
nano examples/nginx/demo-node-api.conf
```

Paste:

```nginx id="yc0n2g"
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/demo-node-api-access.log main_with_request_id;
    error_log  /var/log/nginx/demo-node-api-error.log;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    client_max_body_size 2m;

    gzip on;
    gzip_types text/plain application/json application/javascript text/css;
    gzip_min_length 1024;

    location = /nginx-health {
        access_log off;
        return 200 "nginx ok\n";
    }

    location / {
        proxy_pass http://127.0.0.1:3000;

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

Create log format example:

```bash id="e8x9oh"
nano examples/nginx/log-format.conf
```

Paste:

```nginx id="cdhu4c"
log_format main_with_request_id
    '$remote_addr - $remote_user [$time_local] '
    '"$request" $status $body_bytes_sent '
    '"$http_referer" "$http_user_agent" '
    'request_id="$request_id" '
    'upstream_addr="$upstream_addr" '
    'upstream_status="$upstream_status" '
    'request_time="$request_time" '
    'upstream_response_time="$upstream_response_time"';
```

---

# 22. Add Nginx Notes

Create:

```bash id="dyvi6u"
nano reverse-proxy-nginx.md
```

Paste:

````markdown id="qgsk1x"
# Reverse Proxy with Nginx

## Request Flow

```text
User
  ↓
Nginx :80/:443
  ↓
App :3000
````

## Why Nginx?

* public HTTP/HTTPS entrypoint
* reverse proxy routing
* TLS termination
* headers
* logs
* compression
* request size limits
* security headers
* multiple apps on one server

## Key Config

```nginx
location / {
    proxy_pass http://127.0.0.1:3000;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Request-ID $request_id;
}
```

## Debug Commands

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo systemctl reload nginx

curl -i http://127.0.0.1/nginx-health
curl -i http://127.0.0.1/health
curl -i http://127.0.0.1:3000/health

sudo tail -n 50 /var/log/nginx/demo-node-api-access.log
sudo tail -n 50 /var/log/nginx/demo-node-api-error.log

pm2 logs demo-node-api --lines 100
```

## Status Codes

| Code | Meaning                  |
| ---- | ------------------------ |
| 502  | upstream app unavailable |
| 504  | upstream timeout         |
| 413  | request body too large   |
| 499  | client closed connection |

## Core Rules

* expose Nginx publicly
* keep app port internal
* preserve proxy headers
* add request IDs
* check Nginx logs and app logs
* use `/nginx-health` for Nginx
* use `/health` for app

```
```

---

# 23. Validate Work

Run:

```bash id="ndrl7u"
sudo nginx -t
sudo systemctl reload nginx
```

Make sure app is running:

```bash id="tgh3ze"
pm2 list
pm2 restart demo-node-api || pm2 start ecosystem.config.example.js
```

Test:

```bash id="oi265c"
curl -i http://127.0.0.1/nginx-health
curl -i http://127.0.0.1/health
curl -i -H "x-request-id: lesson-5-5" http://127.0.0.1/version
```

Check logs:

```bash id="y5evig"
sudo tail -n 10 /var/log/nginx/demo-node-api-access.log
pm2 logs demo-node-api --lines 20
```

---

# 24. Commit Work

From repo root:

```bash id="rsnrc9"
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: add Nginx reverse proxy runtime lesson"
git push
```

---

# 25. Interview Explanation

Question:

```text id="dvz7vp"
What is a reverse proxy?
```

Strong answer:

```text id="eugtk0"
A reverse proxy sits in front of backend applications and accepts client traffic on public ports like 80 or 443. It forwards requests to internal application ports such as 3000 or 8000. It can handle routing, TLS termination, headers, logs, compression, timeouts, and security controls.
```

Question:

```text id="8qntpq"
Why use Nginx in front of Node.js?
```

Strong answer:

```text id="igf4v3"
Nginx provides a stable public HTTP/HTTPS entrypoint and proxies traffic to the Node.js app running on an internal port. It also provides access logs, error logs, request headers, compression, request size limits, security headers, and TLS termination. This keeps the Node app focused on application logic.
```

Question:

```text id="rer99l"
How do you debug a 502 from Nginx?
```

Strong answer:

```text id="esr4zd"
A 502 usually means Nginx cannot reach the upstream app. I check whether the app is running, whether it is listening on the expected port, whether `proxy_pass` points to the correct address, and then inspect Nginx error logs and app logs. Commands include `curl http://127.0.0.1:3000/health`, `ss -tulnp`, `sudo nginx -t`, and `tail /var/log/nginx/error.log`.
```

Question:

```text id="9lfva7"
What are `X-Forwarded-For` and `X-Forwarded-Proto`?
```

Strong answer:

```text id="hwhkwa"
`X-Forwarded-For` passes the original client IP or proxy chain to the backend app. `X-Forwarded-Proto` tells the app whether the original request used HTTP or HTTPS. These headers are important for logging, redirects, security decisions, and accurate request context behind a reverse proxy.
```

---

# Today’s Core Rules

```text id="zt21v6"
Use Nginx as public entrypoint.
Keep app port internal.
Proxy port 80/443 to app port 3000.
Use proxy headers.
Use request IDs.
Check Nginx access and error logs.
502 usually means upstream app problem.
504 usually means upstream timeout.
Use /nginx-health for Nginx health.
Use /health for app health.
Do not run app directly on public 80/443 unless justified.
```

Next lesson:

# Lesson 5.6 — HTTPS, TLS, Certificates, Certbot, Redirect HTTP to HTTPS, and Production Domain Setup.
