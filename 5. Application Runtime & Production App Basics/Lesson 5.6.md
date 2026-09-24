# Lesson 5.6 — HTTPS, TLS, Certificates, Certbot, Redirect HTTP to HTTPS, and Production Domain Setup

In Lesson 5.5, we placed Nginx in front of the Node app:

```text
User → Nginx :80 → Node app :3000
```

Now we upgrade the production entrypoint:

```text
User → HTTPS :443 → Nginx → Node app :3000
```

This lesson is about:

```text
HTTP vs HTTPS
TLS certificates
Certbot
Let’s Encrypt
Nginx HTTPS config
HTTP to HTTPS redirect
domain DNS basics
production troubleshooting
```

---

# 1. HTTP vs HTTPS

## HTTP

```text
http://example.com
port 80
unencrypted
```

Problem:

```text
traffic can be read or modified between client and server
```

## HTTPS

```text
https://example.com
port 443
encrypted with TLS
```

Benefits:

```text
encryption
identity verification
data integrity
browser trust
required for secure cookies
required for many modern APIs
```

Production rule:

```text
Public production apps should use HTTPS.
```

---

# 2. What Is TLS?

TLS means Transport Layer Security.

It provides:

```text
encryption
server identity
protection from tampering
```

People often say SSL, but modern systems use TLS.

Correct modern term:

```text
TLS certificate
```

Common casual term:

```text
SSL certificate
```

---

# 3. What Is a Certificate?

A certificate proves that a server is allowed to serve a domain.

Example:

```text
Domain: api.example.com
Certificate says: this server is trusted for api.example.com
Issued by: Let’s Encrypt
```

Browser checks:

```text
Is certificate valid?
Is certificate expired?
Does certificate match domain?
Was certificate issued by trusted CA?
Is the TLS handshake successful?
```

If any check fails, browser shows a warning.

---

# 4. What Is Let’s Encrypt?

Let’s Encrypt is a free certificate authority.

It provides free TLS certificates.

Certificates are commonly issued for:

```text
example.com
www.example.com
api.example.com
*.example.com
```

Normal certificates are usually domain-specific:

```text
api.example.com
```

Wildcard certificates cover subdomains:

```text
*.example.com
```

Wildcard certificates usually require DNS validation.

For this lesson, we use normal HTTP validation.

---

# 5. What Is Certbot?

Certbot is a tool that can:

```text
request Let’s Encrypt certificates
prove domain ownership
configure Nginx automatically
renew certificates automatically
```

Typical command:

```bash
sudo certbot --nginx -d example.com
```

Certbot can edit Nginx config and add HTTPS settings.

---

# 6. Domain and DNS Requirement

Before Certbot works, your domain must point to your server.

Example:

```text
Domain: app.example.com
Server public IP: 13.201.10.20
```

DNS record:

```text
Type: A
Name: app
Value: 13.201.10.20
```

Then:

```text
app.example.com → 13.201.10.20
```

Check DNS:

```bash
dig app.example.com
```

or:

```bash
nslookup app.example.com
```

Check from server:

```bash
curl -I http://app.example.com
```

Important:

```text
Certbot HTTP validation requires port 80 reachable from the internet.
```

So security group/firewall must allow:

```text
80/tcp
443/tcp
```

---

# 7. Target Architecture

```text
Browser
  ↓
https://app.example.com
  ↓
Nginx :443
  ↓
127.0.0.1:3000
  ↓
demo-node-api
```

HTTP should redirect:

```text
http://app.example.com → https://app.example.com
```

Final production flow:

```text
User → HTTPS → Nginx TLS termination → internal HTTP → Node app
```

This is common.

The internal app does not need to handle TLS directly.

---

# 8. Install Certbot

On Ubuntu:

```bash
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

Check:

```bash
certbot --version
```

---

# 9. Prepare Nginx Server Name

Open your Nginx config:

```bash
sudo nano /etc/nginx/sites-available/demo-node-api
```

Currently you may have:

```nginx
server_name _;
```

For Certbot, replace it with your real domain:

```nginx
server_name app.example.com;
```

Example for your own domain:

```nginx
server_name app.yourdatascientist.tech;
```

Then test:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Test HTTP:

```bash
curl -I http://app.example.com
```

You should get a response from Nginx.

---

# 10. Issue Certificate with Certbot

Run:

```bash
sudo certbot --nginx -d app.example.com
```

For both root and www:

```bash
sudo certbot --nginx -d example.com -d www.example.com
```

Certbot will ask:

```text
email address
agree to terms
share email or not
redirect HTTP to HTTPS or not
```

Choose redirect when asked.

Expected result:

```text
Successfully received certificate.
Certificate is saved at /etc/letsencrypt/live/app.example.com/fullchain.pem
Key is saved at /etc/letsencrypt/live/app.example.com/privkey.pem
```

---

# 11. Check HTTPS

Run:

```bash
curl -I https://app.example.com
```

Expected:

```text
HTTP/2 200
```

or:

```text
HTTP/1.1 200 OK
```

Check redirect:

```bash
curl -I http://app.example.com
```

Expected:

```text
HTTP/1.1 301 Moved Permanently
Location: https://app.example.com/
```

Check endpoints:

```bash
curl -s https://app.example.com/health | jq .
curl -s https://app.example.com/ready | jq .
curl -s https://app.example.com/version | jq .
```

---

# 12. What Certbot Adds to Nginx

Certbot usually modifies your config and adds something like:

```nginx
listen 443 ssl;
ssl_certificate /etc/letsencrypt/live/app.example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;
include /etc/letsencrypt/options-ssl-nginx.conf;
ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
```

And an HTTP redirect block:

```nginx
server {
    listen 80;
    server_name app.example.com;
    return 301 https://$host$request_uri;
}
```

This means:

```text
port 80 receives HTTP
Nginx redirects to HTTPS
port 443 serves encrypted traffic
```

---

# 13. Manual HTTPS Nginx Config Example

Certbot can generate this automatically, but you should understand the final structure.

Example:

```nginx
server {
    listen 80;
    server_name app.example.com;

    location = /nginx-health {
        access_log off;
        return 200 "nginx ok\n";
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name app.example.com;

    ssl_certificate /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;

    access_log /var/log/nginx/demo-node-api-access.log main_with_request_id;
    error_log  /var/log/nginx/demo-node-api-error.log;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    client_max_body_size 2m;

    gzip on;
    gzip_types text/plain application/json application/javascript text/css;
    gzip_min_length 1024;

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

---

# 14. Certificate Renewal

Let’s Encrypt certificates expire periodically, so renewal matters.

Certbot usually installs a systemd timer.

Check:

```bash
systemctl list-timers | grep certbot
```

or:

```bash
sudo systemctl status certbot.timer --no-pager
```

Test renewal:

```bash
sudo certbot renew --dry-run
```

Expected:

```text
Congratulations, all simulated renewals succeeded
```

Production rule:

```text
Always test certificate renewal after setup.
```

A valid certificate today is not enough. Renewal must work too.

---

# 15. Firewall and Cloud Security Group

Your server must allow:

```text
80/tcp
443/tcp
```

On Ubuntu firewall:

```bash
sudo ufw allow 'Nginx Full'
sudo ufw status
```

Or manually:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

On AWS security group:

```text
Inbound rule:
HTTP  TCP 80   0.0.0.0/0
HTTPS TCP 443  0.0.0.0/0
SSH   TCP 22   your-ip/32
```

For IPv6, also allow:

```text
::/0
```

when your server and DNS use IPv6.

---

# 16. Common Certbot Failures

## Failure 1 — DNS does not point to server

Error may say validation failed.

Check:

```bash
dig app.example.com
curl -I http://app.example.com
```

Fix:

```text
create or correct DNS A record
wait for DNS propagation
```

---

## Failure 2 — Port 80 blocked

Let’s Encrypt cannot reach your server.

Check locally:

```bash
sudo ss -tulnp | grep ':80'
```

Check firewall:

```bash
sudo ufw status
```

Check cloud security group:

```text
allow inbound TCP 80
```

---

## Failure 3 — Wrong Nginx server_name

Certbot cannot match the domain.

Check:

```bash
sudo nginx -T | grep server_name
```

Fix:

```nginx
server_name app.example.com;
```

Reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## Failure 4 — Nginx config invalid

Check:

```bash
sudo nginx -t
```

Fix error, then reload:

```bash
sudo systemctl reload nginx
```

---

## Failure 5 — Cloudflare proxy or CDN issue

If using Cloudflare/CloudFront/CDN, validation can become confusing.

For basic Certbot HTTP validation, direct DNS to the server first.

Later, CDN can be added after TLS is working.

---

# 17. TLS Debugging Commands

Check certificate from command line:

```bash
openssl s_client -connect app.example.com:443 -servername app.example.com </dev/null
```

Show certificate dates:

```bash
echo | openssl s_client -servername app.example.com -connect app.example.com:443 2>/dev/null \
  | openssl x509 -noout -dates
```

Check issuer and subject:

```bash
echo | openssl s_client -servername app.example.com -connect app.example.com:443 2>/dev/null \
  | openssl x509 -noout -issuer -subject
```

Check Nginx TLS config:

```bash
sudo nginx -T | grep -E 'ssl_certificate|server_name|listen 443'
```

Check logs:

```bash
sudo tail -n 100 /var/log/nginx/demo-node-api-error.log
sudo tail -n 100 /var/log/nginx/error.log
```

---

# 18. HTTPS and App Awareness

Nginx terminates TLS.

The app receives internal HTTP:

```text
Nginx HTTPS :443 → Node app HTTP :3000
```

But app should know the original request was HTTPS.

That is why we send:

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
```

And in Express:

```javascript
app.set("trust proxy", true);
```

This helps with:

```text
secure cookies
redirect URLs
logging
security decisions
```

---

# 19. HSTS

HSTS means HTTP Strict Transport Security.

It tells browsers:

```text
Always use HTTPS for this domain in future.
```

Nginx header:

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

Be careful.

Do not enable HSTS too early if:

```text
you are still testing DNS/TLS
some subdomains do not support HTTPS
you might need HTTP temporarily
```

For learning, add it only after HTTPS is stable.

Production mature config:

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

---

# 20. Update Nginx Example in Repo

Create HTTPS example:

```bash
cd ~/devops-masterclass/05-application-runtime
nano examples/nginx/demo-node-api-https.conf
```

Paste:

```nginx
server {
    listen 80;
    server_name app.example.com;

    location = /nginx-health {
        access_log off;
        return 200 "nginx ok\n";
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name app.example.com;

    ssl_certificate /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;

    access_log /var/log/nginx/demo-node-api-access.log main_with_request_id;
    error_log  /var/log/nginx/demo-node-api-error.log;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    # Enable only after HTTPS is stable:
    # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    client_max_body_size 2m;

    gzip on;
    gzip_types text/plain application/json application/javascript text/css;
    gzip_min_length 1024;

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

---

# 21. Add HTTPS Notes

Create:

```bash
nano https-tls-certbot.md
```

Paste:

````markdown
# HTTPS, TLS, Certbot, and Production Domain Setup

## Request Flow

```text
User
  ↓ HTTPS :443
Nginx
  ↓ HTTP :3000
Node app
````

## Requirements

* domain points to server
* port 80 open for HTTP validation
* port 443 open for HTTPS
* Nginx server_name matches domain
* app is running behind Nginx

## Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d app.example.com
sudo certbot renew --dry-run
```

## Checks

```bash
dig app.example.com
curl -I http://app.example.com
curl -I https://app.example.com
sudo nginx -t
sudo systemctl reload nginx
systemctl list-timers | grep certbot
```

## Common Failures

| Problem              | Cause                               |
| -------------------- | ----------------------------------- |
| validation failed    | DNS wrong or port 80 blocked        |
| 502 after HTTPS      | app not running or wrong proxy_pass |
| certificate mismatch | wrong domain/server_name            |
| renewal failure      | DNS/firewall/Nginx issue            |

## Core Rules

* Use HTTPS for public production apps.
* Keep app traffic internal behind Nginx.
* Redirect HTTP to HTTPS.
* Test certificate renewal.
* Keep ports 80 and 443 open.
* Use `X-Forwarded-Proto`.
* Enable HSTS only after HTTPS is stable.

````

---

# 22. Production Domain Setup Checklist

Use this checklist when setting up a real domain.

```text
1. Create DNS A record.
2. Confirm domain resolves to server IP.
3. Open ports 80 and 443.
4. Configure Nginx server_name.
5. Confirm HTTP works.
6. Run Certbot.
7. Confirm HTTPS works.
8. Confirm HTTP redirects to HTTPS.
9. Confirm app endpoints work through HTTPS.
10. Test certbot renew --dry-run.
11. Archive config examples in repo.
````

Commands:

```bash
dig app.example.com
curl -I http://app.example.com
sudo nginx -t
sudo certbot --nginx -d app.example.com
curl -I https://app.example.com
curl -I http://app.example.com
sudo certbot renew --dry-run
```

---

# 23. Validation Commands

For local VM without real domain, you cannot complete Let’s Encrypt HTTP validation.

But you can still validate:

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
curl -I http://127.0.0.1/nginx-health
curl -I http://127.0.0.1/health
```

For real server with domain:

```bash
DOMAIN=app.example.com

dig "$DOMAIN"
curl -I "http://$DOMAIN"

sudo certbot --nginx -d "$DOMAIN"

curl -I "https://$DOMAIN"
curl -I "http://$DOMAIN"
curl -s "https://$DOMAIN/health" | jq .

sudo certbot renew --dry-run
```

---

# 24. Commit Work

From repo root:

```bash
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: add HTTPS TLS Certbot runtime lesson"
git push
```

---

# 25. Interview Explanation

Question:

```text
Why do we use HTTPS in production?
```

Strong answer:

```text
HTTPS encrypts traffic between the client and server, verifies server identity through a trusted certificate, and protects data from tampering. It is required for secure production applications, secure cookies, modern browser features, and user trust.
```

Question:

```text
What does Certbot do?
```

Strong answer:

```text
Certbot automates requesting, installing, and renewing Let’s Encrypt TLS certificates. With the Nginx plugin, it can update Nginx configuration, configure HTTPS, and optionally redirect HTTP traffic to HTTPS.
```

Question:

```text
How do you debug Certbot validation failure?
```

Strong answer:

```text
I check whether DNS points to the correct server, whether port 80 is reachable from the internet, whether the Nginx server_name matches the domain, and whether the Nginx config is valid. I use commands like dig, curl, nginx -t, ss, ufw status, and Nginx logs.
```

Question:

```text
What is TLS termination?
```

Strong answer:

```text
TLS termination means the reverse proxy, such as Nginx or a load balancer, handles HTTPS encryption and decryption. After terminating TLS, it forwards traffic internally to the application over HTTP. The app still receives forwarded headers like X-Forwarded-Proto so it knows the original request was HTTPS.
```

---

# Today’s Core Rules

```text
Public production apps should use HTTPS.
Nginx commonly terminates TLS.
The app can run internally on HTTP.
DNS must point to the server before Certbot works.
Port 80 must be open for HTTP validation.
Port 443 must be open for HTTPS.
Redirect HTTP to HTTPS.
Test cert renewal with certbot renew --dry-run.
Use X-Forwarded-Proto.
Enable HSTS only after HTTPS is stable.
```

Next lesson:

# Lesson 5.7 — Deployment Layouts, Release Directories, Symlinks, Atomic Deployments, and Rollback Basics.
