# Lesson 3.17 — Linux Security Basics

Now we learn **Linux security basics** from a DevOps/SRE perspective.

Security is not only a separate “security team” topic. Every DevOps engineer must know how to secure servers, SSH, users, ports, logs, secrets, and services.

A beginner thinks:

```text
If the app works, server is fine.
```

A DevOps engineer thinks:

```text
Who can log in?
Which ports are exposed?
Which users have sudo?
Are services running as root?
Are secrets protected?
Are logs showing attacks?
Is SSH hardened?
Is the firewall configured?
Can we audit what happened?
```

---

# 1. Linux Security Mental Model

Linux security is about controlling:

```text
Identity      who is doing something
Permission    what they can access
Network       what can connect
Process       what runs and as which user
Secrets       where sensitive values live
Logs          what happened
Updates       known vulnerabilities patched
Audit         can we investigate later
```

Production baseline:

```text
Only required users
Only required ports
Only required privileges
Only required packages
Only required services
```

This is called **least privilege**.

---

# 2. Golden Rule: Least Privilege

Least privilege means:

```text
Give only the minimum access required to do the job.
```

Bad:

```text
All developers get root SSH.
Jenkins gets NOPASSWD: ALL.
App runs as root.
Database port open to 0.0.0.0/0.
.env file readable by everyone.
```

Good:

```text
Developers use individual accounts.
Only selected users have sudo.
Jenkins can run only specific deployment commands.
App runs as dedicated service user.
Database accepts traffic only from app network/security group.
Secrets readable only by required service user/group.
```

DevOps rule:

```text
If something is compromised, least privilege limits blast radius.
```

---

# 3. User and Group Security Review

Check current user:

```bash
whoami
id
groups
```

List users:

```bash
cut -d: -f1,3,7 /etc/passwd
```

Show users with login shells:

```bash
grep -E '/bin/bash|/bin/sh|/usr/bin/zsh' /etc/passwd
```

Show sudo group:

```bash
getent group sudo
```

Check sudo access for current user:

```bash
sudo -l
```

Important files:

```text
/etc/passwd     user account info
/etc/shadow     password hashes, root-readable only
/etc/group      group info
/etc/sudoers    sudo policy
/etc/sudoers.d/ sudo policy snippets
```

Never edit sudoers directly with normal editor.

Use:

```bash
sudo visudo
```

or:

```bash
sudo visudo -f /etc/sudoers.d/deploy
```

---

# 4. Human Users vs Service Users

Human user:

```text
vivek
ubuntu
deploy
jenkins
```

Service user:

```text
todo-api
nginx
postgres
mongodb
prometheus
grafana
```

Service users should usually have:

```text
No interactive shell
Limited file access
Limited sudo or no sudo
Only required directories
```

Create service user:

```bash
sudo useradd --system --shell /usr/sbin/nologin --home /opt/todo-api todo-api
```

Check:

```bash
id todo-api
getent passwd todo-api
```

Example output:

```text
todo-api:x:999:999::/opt/todo-api:/usr/sbin/nologin
```

Meaning:

```text
System user
Home directory /opt/todo-api
Cannot log in interactively
```

---

# 5. Why Apps Should Not Run as Root

Bad systemd service:

```ini
[Service]
User=root
ExecStart=/usr/bin/node server.js
```

Risk:

```text
If app is exploited, attacker gets root-level access.
```

Better:

```ini
[Service]
User=todo-api
Group=todo-api
WorkingDirectory=/opt/todo-api/current
ExecStart=/usr/bin/node server.js
```

Now if app is compromised, attacker has only `todo-api` permissions.

Production rule:

```text
Public-facing application processes should not run as root unless absolutely required.
```

---

# 6. File Permission Security

Check sensitive files:

```bash
ls -l /etc/shadow
ls -l ~/.ssh
ls -l ~/.ssh/authorized_keys
```

Good SSH permissions:

```text
~/.ssh                  700
~/.ssh/authorized_keys  600
private key             600
public key              644
```

Fix:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

For app config:

```bash
sudo mkdir -p /etc/todo-api
sudo nano /etc/todo-api/todo-api.env
```

Secure permissions:

```bash
sudo chown root:todo-api /etc/todo-api/todo-api.env
sudo chmod 640 /etc/todo-api/todo-api.env
```

Meaning:

```text
root can read/write
todo-api group can read
others cannot read
```

---

# 7. Dangerous Permission Patterns

Avoid:

```bash
chmod 777 file
chmod -R 777 /opt/app
chmod -R 777 /var/www
chmod 666 .env
```

Why dangerous?

```text
Any user can modify files.
Any compromised process can alter app code/config.
Secrets can be read.
Attackers can plant scripts or backdoors.
```

Better:

```bash
sudo chown -R todo-api:todo-api /opt/todo-api
sudo chmod -R u=rwX,g=rX,o= /opt/todo-api
```

For shared deploy directories:

```bash
sudo chgrp -R devops /opt/todo-api
sudo chmod -R g+rwX /opt/todo-api
sudo chmod g+s /opt/todo-api
```

Use `chmod 777` only in temporary labs, not production.

---

# 8. SSH Security Basics

SSH is the most important remote access service.

Check status:

```bash
sudo systemctl status ssh
```

or:

```bash
sudo systemctl status sshd
```

Check listening:

```bash
sudo ss -tulnp | grep ':22'
```

SSH config:

```text
/etc/ssh/sshd_config
```

Backup before editing:

```bash
sudo cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.$(date +%Y%m%d-%H%M%S).bak"
```

Edit:

```bash
sudo nano /etc/ssh/sshd_config
```

Validate:

```bash
sudo sshd -t
```

Reload:

```bash
sudo systemctl reload ssh
```

or:

```bash
sudo systemctl reload sshd
```

Important:

```text
Do not close your current SSH session until you verify a new session works.
```

---

# 9. SSH Hardening Options

Recommended baseline:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
```

Example:

```bash
sudo grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|PermitEmptyPasswords|X11Forwarding|MaxAuthTries)' /etc/ssh/sshd_config
```

Add or update:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
```

Validate:

```bash
sudo sshd -t
```

Reload:

```bash
sudo systemctl reload ssh
```

Production note:

```text
Disable password login only after verifying SSH key login works.
```

---

# 10. Root SSH Login

Bad:

```text
PermitRootLogin yes
```

Why?

```text
Attackers know root username exists.
Brute-force target is obvious.
Root compromise is full system compromise.
No individual accountability.
```

Better:

```text
PermitRootLogin no
```

Use normal user + sudo:

```bash
ssh vivek@server
sudo systemctl restart nginx
```

This gives better auditability.

---

# 11. SSH Password Login

Bad for internet-facing servers:

```text
PasswordAuthentication yes
```

Better:

```text
PasswordAuthentication no
```

Use SSH keys:

```bash
ssh-keygen -t ed25519 -C "vivek@example.com"
```

Copy public key:

```bash
ssh-copy-id user@server
```

Manual method:

```bash
cat ~/.ssh/id_ed25519.pub
```

On server:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

# 12. SSH AllowUsers

For stricter access:

```text
AllowUsers vivek deploy
```

This means only these users can SSH.

Add in `/etc/ssh/sshd_config`:

```text
AllowUsers vivek deploy
```

Validate:

```bash
sudo sshd -t
```

Reload:

```bash
sudo systemctl reload ssh
```

Use carefully. If you forget your actual login user, you can lock yourself out.

---

# 13. Firewall Basics with UFW

Check status:

```bash
sudo ufw status verbose
```

Allow SSH before enabling:

```bash
sudo ufw allow OpenSSH
```

or:

```bash
sudo ufw allow 22/tcp
```

Allow HTTP/HTTPS:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

Enable:

```bash
sudo ufw enable
```

Check:

```bash
sudo ufw status numbered
```

Delete a rule:

```bash
sudo ufw delete <rule-number>
```

Example:

```bash
sudo ufw status numbered
sudo ufw delete 3
```

Production warning:

```text
Always allow SSH before enabling UFW on a remote server.
```

---

# 14. Firewall Principle

Expose only required ports.

Typical public web server:

```text
22/tcp    from your IP only, or via bastion/VPN/SSM
80/tcp    from anywhere
443/tcp   from anywhere
```

Not public:

```text
3000/tcp   internal only
5432/tcp   internal only
3306/tcp   internal only
6379/tcp   internal only
27017/tcp  internal only
```

Bad:

```bash
sudo ufw allow 27017/tcp
```

if MongoDB is public-facing.

Better:

```text
DB port allowed only from app server private IP/security group.
```

---

# 15. AWS Security Group Baseline

For production AWS:

```text
ALB Security Group:
  inbound 80/443 from 0.0.0.0/0
  outbound to app SG

App EC2 Security Group:
  inbound app port from ALB SG only
  inbound SSH from your IP or bastion only
  outbound to DB/cache/external APIs as required

DB Security Group:
  inbound DB port from App SG only
```

Bad:

```text
MongoDB 27017 from 0.0.0.0/0
PostgreSQL 5432 from 0.0.0.0/0
Redis 6379 from 0.0.0.0/0
```

Good:

```text
DB accepts from backend app security group only.
```

---

# 16. Secrets Handling

Secrets include:

```text
Passwords
API keys
JWT secrets
OAuth secrets
Private keys
Database URLs with credentials
Cloud credentials
Webhook tokens
Session secrets
```

Never commit secrets:

```text
.env
*.pem
id_rsa
AWS keys
database dump with credentials
```

Use `.gitignore`:

```bash
nano .gitignore
```

Add:

```gitignore
.env
.env.*
*.pem
*.key
id_rsa
id_ed25519
secrets/
```

But keep examples:

```text
.env.example
```

Example:

```text
DATABASE_URL=mongodb://localhost:27017/todo
JWT_SECRET=change-me
PORT=3000
```

No real secrets in `.env.example`.

---

# 17. Check Git History for Secrets

Basic grep:

```bash
git grep -n "AWS_SECRET\|AWS_ACCESS\|PASSWORD\|PRIVATE KEY\|DATABASE_URL"
```

Search full history:

```bash
git log -p --all | grep -i "password\|secret\|private key\|aws_access"
```

Better tools later:

```text
gitleaks
trufflehog
git-secrets
GitHub secret scanning
```

If a secret was committed:

```text
Rotate the secret immediately.
Removing it from Git history is not enough.
```

Production rule:

```text
Once a secret is pushed, assume it is compromised.
```

---

# 18. Environment File Security

For systemd service:

```ini
[Service]
EnvironmentFile=/etc/todo-api/todo-api.env
```

Secure file:

```bash
sudo chown root:todo-api /etc/todo-api/todo-api.env
sudo chmod 640 /etc/todo-api/todo-api.env
```

Check:

```bash
ls -l /etc/todo-api/todo-api.env
```

Bad:

```bash
chmod 777 /etc/todo-api/todo-api.env
chmod 644 /etc/todo-api/todo-api.env
```

`644` means everyone can read secrets.

Better:

```bash
640
```

or stricter:

```bash
600
```

depending on how service reads it.

---

# 19. Avoid Printing Secrets in Logs

Bad:

```bash
echo "$DATABASE_URL"
env
printenv
set -x
```

Danger:

```text
Secrets can appear in terminal logs, CI logs, journal logs, chat screenshots, or build artifacts.
```

Better:

```bash
if [ -n "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is configured"
else
  echo "DATABASE_URL is missing" >&2
fi
```

In Bash scripts:

```bash
set +x
# handle secret
set -x
```

But avoid `set -x` in production scripts unless necessary.

---

# 20. Package Updates

Security patches matter.

Update package lists:

```bash
sudo apt update
```

Show upgradable packages:

```bash
apt list --upgradable
```

Upgrade:

```bash
sudo apt upgrade -y
```

Full upgrade, use carefully:

```bash
sudo apt full-upgrade
```

Remove unused packages:

```bash
sudo apt autoremove -y
```

Check unattended upgrades package:

```bash
dpkg -l | grep unattended-upgrades
```

Install:

```bash
sudo apt install -y unattended-upgrades
```

Production rule:

```text
Patch regularly, but test and schedule changes for critical systems.
```

---

# 21. Reduce Attack Surface

List listening ports:

```bash
sudo ss -tulnp
```

List services:

```bash
systemctl list-units --type=service --state=running
```

Disable unused service:

```bash
sudo systemctl disable --now service-name
```

Remove unused package:

```bash
sudo apt remove package-name
```

Principle:

```text
If it is not needed, do not run it.
If it is not running, it cannot be attacked remotely through that service.
```

---

# 22. Authentication Logs

Ubuntu auth logs:

```bash
sudo less /var/log/auth.log
```

Failed SSH logins:

```bash
sudo grep "Failed password" /var/log/auth.log | tail -50
```

Accepted SSH logins:

```bash
sudo grep "Accepted" /var/log/auth.log | tail -50
```

Sudo usage:

```bash
sudo grep "sudo" /var/log/auth.log | tail -50
```

systemd journal alternative:

```bash
journalctl -u ssh --since "24 hours ago"
```

or:

```bash
journalctl -u sshd --since "24 hours ago"
```

---

# 23. Count Suspicious SSH Attempts

Failed password source IPs:

```bash
sudo grep "Failed password" /var/log/auth.log \
  | grep -oE 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' \
  | awk '{print $2}' \
  | sort \
  | uniq -c \
  | sort -nr \
  | head
```

Accepted login users:

```bash
sudo grep "Accepted" /var/log/auth.log \
  | awk '{print $1, $2, $3, $9, $11}' \
  | tail -20
```

Check recent logins:

```bash
last
```

Check failed login database:

```bash
lastb
```

`lastb` may require `/var/log/btmp` and root.

---

# 24. fail2ban

`fail2ban` watches logs and bans IPs after repeated failures.

Install:

```bash
sudo apt update
sudo apt install -y fail2ban
```

Check:

```bash
sudo systemctl status fail2ban
```

Create local config:

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Better: create small override:

```bash
sudo nano /etc/fail2ban/jail.d/sshd.local
```

Paste:

```ini
[sshd]
enabled = true
port = ssh
maxretry = 5
findtime = 10m
bantime = 1h
```

Restart:

```bash
sudo systemctl restart fail2ban
```

Check status:

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

Unban IP:

```bash
sudo fail2ban-client set sshd unbanip <ip>
```

Note:

```text
fail2ban helps, but it is not a replacement for SSH keys, firewall restrictions, and disabling password login.
```

---

# 25. Audit Useful Commands

Who is logged in now?

```bash
who
w
```

Recent logins:

```bash
last -a | head
```

Sudo activity:

```bash
sudo grep "sudo" /var/log/auth.log | tail -100
```

User accounts:

```bash
cut -d: -f1,3,7 /etc/passwd
```

Sudo users:

```bash
getent group sudo
```

Failed services:

```bash
systemctl --failed
```

Recent critical logs:

```bash
journalctl -p err --since "24 hours ago"
```

---

# 26. Linux Security Baseline Script

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/security-baseline-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

section "System Identity"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Date: $(date -Is)"

section "OS"
if [ -f /etc/os-release ]; then
  grep -E '^(NAME|VERSION)=' /etc/os-release || true
fi

section "Current User"
id
groups

section "Users With Login Shells"
grep -E '/bin/bash|/bin/sh|/usr/bin/zsh' /etc/passwd || true

section "Sudo Group"
getent group sudo || true

section "Listening Ports"
sudo ss -tulnp 2>/dev/null || ss -tuln || true

section "Running Services"
systemctl list-units --type=service --state=running --no-pager || true

section "Failed Services"
systemctl --failed --no-pager || true

section "UFW Status"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw status verbose || true
else
  echo "ufw not installed"
fi

section "SSH Config Important Values"
if [ -f /etc/ssh/sshd_config ]; then
  sudo sshd -T 2>/dev/null | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|x11forwarding)' || true
else
  echo "/etc/ssh/sshd_config not found"
fi

section "SSH Directory Permissions"
if [ -d "$HOME/.ssh" ]; then
  ls -ld "$HOME/.ssh"
  ls -la "$HOME/.ssh" | sed -n '1,30p'
else
  echo "No ~/.ssh directory found"
fi

section "Recent Accepted SSH Logins"
if [ -f /var/log/auth.log ]; then
  sudo grep "Accepted" /var/log/auth.log | tail -20 || true
else
  journalctl -u ssh --since "24 hours ago" --no-pager 2>/dev/null | grep "Accepted" | tail -20 || true
fi

section "Recent Failed SSH Password Attempts"
if [ -f /var/log/auth.log ]; then
  sudo grep "Failed password" /var/log/auth.log | tail -20 || true
else
  journalctl -u ssh --since "24 hours ago" --no-pager 2>/dev/null | grep "Failed password" | tail -20 || true
fi

section "Recent Error Logs"
journalctl -p err --since "24 hours ago" --no-pager 2>/dev/null | tail -100 || true

section "World-Writable Sensitive-Looking Files Under Current Repo"
find . -type f \( -name ".env" -o -name "*.pem" -o -name "*.key" \) -perm -o+r -print 2>/dev/null || true

section "Git Secret Pattern Quick Scan"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git grep -n -I -E 'AWS_SECRET|AWS_ACCESS|PRIVATE KEY|PASSWORD=|SECRET=|TOKEN=' || true
else
  echo "Not inside a Git repository"
fi

echo
echo "Security baseline check completed."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/security-baseline-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/security-baseline-check.sh
```

This is read-only. It checks and reports.

---

# 27. SSH Hardening Check Script

Create:

```bash
nano 03-linux-bash-networking/scripts/ssh-hardening-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== SSH Hardening Check ====="
echo "Time: $(date -Is)"
echo

if [ ! -f /etc/ssh/sshd_config ]; then
  echo "ERROR: /etc/ssh/sshd_config not found" >&2
  exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
  echo "ERROR: sshd command not found" >&2
  exit 1
fi

echo "Validating sshd config syntax..."
if sudo sshd -t; then
  echo "OK: sshd config syntax valid"
else
  echo "ERROR: sshd config syntax invalid" >&2
  exit 1
fi

echo
echo "Effective SSH settings:"
sudo sshd -T 2>/dev/null | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|maxauthtries|x11forwarding|allowusers)' || true

echo
echo "Recommendations:"
echo "- permitrootlogin should usually be no"
echo "- passwordauthentication should usually be no after key login is verified"
echo "- pubkeyauthentication should be yes"
echo "- permitemptypasswords should be no"
echo "- x11forwarding should usually be no on servers"
echo "- maxauthtries should be low, for example 3"
echo
echo "Do not close your current SSH session before testing a new login."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/ssh-hardening-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/ssh-hardening-check.sh
```

---

# 28. Secret Permission Check Script

Create:

```bash
nano 03-linux-bash-networking/scripts/secret-permission-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: target directory not found: $TARGET_DIR" >&2
  exit 1
fi

echo "===== Secret Permission Check ====="
echo "Target: $TARGET_DIR"
echo "Time: $(date -Is)"
echo

echo "Searching for sensitive-looking files..."
find "$TARGET_DIR" \
  -type f \( \
    -name ".env" -o \
    -name ".env.*" -o \
    -name "*.pem" -o \
    -name "*.key" -o \
    -name "id_rsa" -o \
    -name "id_ed25519" \
  \) -print 2>/dev/null | while IFS= read -r file; do
    echo
    echo "--- $file ---"
    ls -l "$file"

    mode="$(stat -c '%a' "$file" 2>/dev/null || true)"

    case "$mode" in
      600|640|400)
        echo "OK-ish: restrictive mode $mode"
        ;;
      *)
        echo "WARNING: mode $mode may be too permissive"
        ;;
    esac
  done

echo
echo "Recommended:"
echo "- private keys: 600 or 400"
echo "- env files with secrets: 600 or 640"
echo "- never commit real secrets to Git"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/secret-permission-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/secret-permission-check.sh .
```

---

# 29. Create Security Notes

Create:

```bash
nano 03-linux-bash-networking/linux-security-basics.md
```

Paste:

````markdown
# Linux Security Basics

## Core Principles

- Least privilege
- Minimal exposed ports
- Dedicated service users
- SSH key authentication
- No direct root SSH
- No public database ports
- Secrets protected by file permissions
- Logs reviewed for suspicious activity
- Regular patching
- Remove unused services/packages

## Important Commands

```bash
id
groups
sudo -l
getent group sudo
grep -E '/bin/bash|/bin/sh|/usr/bin/zsh' /etc/passwd
sudo ss -tulnp
sudo ufw status verbose
systemctl list-units --type=service --state=running
systemctl --failed
sudo sshd -t
sudo sshd -T
sudo grep "Failed password" /var/log/auth.log
sudo grep "Accepted" /var/log/auth.log
journalctl -p err --since "24 hours ago"
````

## SSH Baseline

Recommended settings:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
```

Always validate before reload:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

Do not close your existing SSH session until a new login works.

## File Permissions

Good examples:

```text
~/.ssh                 700
authorized_keys        600
private key            600
.env with secrets      600 or 640
```

Avoid:

```text
chmod 777
world-readable secrets
apps running as root
```

## Firewall Baseline

Public web server:

```text
22/tcp   restricted to admin IP/bastion/VPN
80/tcp   public
443/tcp  public
```

Private/internal only:

```text
3000 app port
5432 PostgreSQL
3306 MySQL
6379 Redis
27017 MongoDB
```

## Secrets Rules

* Do not commit secrets.
* Use `.env.example` without real values.
* Protect env files with permissions.
* Do not print secrets in logs.
* If a secret is committed or leaked, rotate it immediately.

## fail2ban

```bash
sudo apt install -y fail2ban
sudo systemctl status fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

## Production Rules

* Use individual user accounts.
* Avoid shared root access.
* Use sudo intentionally.
* Apps should run as non-root service users.
* Expose only what is necessary.
* Check logs regularly.
* Patch regularly.

````

---

# 30. Commit Work

Run:

```bash
git status
git diff
````

Add:

```bash
git add 03-linux-bash-networking/linux-security-basics.md \
        03-linux-bash-networking/scripts/security-baseline-check.sh \
        03-linux-bash-networking/scripts/ssh-hardening-check.sh \
        03-linux-bash-networking/scripts/secret-permission-check.sh
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "docs: add Linux security basics"
git push
```

---

# 31. Real Production Scenario — Too Many Failed SSH Attempts

Alert:

```text
Many failed SSH login attempts from unknown IPs.
```

Check:

```bash
sudo grep "Failed password" /var/log/auth.log | tail -100
```

Count IPs:

```bash
sudo grep "Failed password" /var/log/auth.log \
  | grep -oE 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' \
  | awk '{print $2}' \
  | sort | uniq -c | sort -nr | head
```

Immediate actions:

```text
Ensure password login is disabled.
Restrict SSH to your IP, VPN, bastion, or SSM.
Install/configure fail2ban if appropriate.
Review successful logins.
Rotate keys if suspicious activity is confirmed.
```

Check successful logins:

```bash
sudo grep "Accepted" /var/log/auth.log | tail -50
last -a | head
```

---

# 32. Real Production Scenario — App Secret Exposed

Problem:

```text
.env file was committed to GitHub.
```

Wrong response:

```text
Delete the file and commit removal.
```

Correct response:

```text
1. Rotate the exposed secret immediately.
2. Remove secret from current repo.
3. Purge from Git history if needed.
4. Check access logs for misuse.
5. Add secret scanning.
6. Add .gitignore and .env.example.
```

Commands:

```bash
echo ".env" >> .gitignore
git rm --cached .env
git commit -m "chore: stop tracking env file"
```

But remember:

```text
Git history may still contain the secret.
Rotation is mandatory.
```

---

# 33. Real Production Scenario — Jenkins Has Too Much Sudo

Bad sudoers:

```text
jenkins ALL=(ALL) NOPASSWD: ALL
```

Risk:

```text
Any Jenkins job compromise becomes root compromise.
```

Better:

```text
jenkins ALL=(root) NOPASSWD: /usr/bin/systemctl restart todo-api, /usr/bin/systemctl status todo-api
```

Edit:

```bash
sudo visudo -f /etc/sudoers.d/jenkins-todo-api
```

Add:

```text
jenkins ALL=(root) NOPASSWD: /usr/bin/systemctl restart todo-api, /usr/bin/systemctl status todo-api
```

But still be careful:

```text
If Jenkins can modify the service file or app binary executed by root, privilege escalation may still be possible.
```

Least privilege must consider the whole chain.

---

# 34. Interview Answers

Question:

```text
How do you harden SSH on a Linux server?
```

Strong answer:

```text
I use SSH key authentication, disable password login after verifying keys, disable direct root login, ensure proper ~/.ssh permissions, restrict SSH access by firewall or security group to trusted IPs or a bastion/VPN, reduce MaxAuthTries, and monitor auth logs for failed and accepted logins. I always validate sshd config with sshd -t before reloading and keep the current session open until a new login is tested.
```

Question:

```text
What is least privilege?
```

Strong answer:

```text
Least privilege means giving users, services, and systems only the minimum permissions required. For example, application services should run as dedicated non-root users, Jenkins should only have sudo access to specific deployment commands, and database ports should only be reachable from application servers. This reduces blast radius if something is compromised.
```

Question:

```text
What do you do if a secret is committed to Git?
```

Strong answer:

```text
I immediately rotate the secret because once it is committed or pushed, it must be treated as compromised. Then I remove it from the repository, add it to .gitignore, replace it with a safe .env.example, scan the repository and history, and investigate whether the secret was used. Removing it from Git history is useful, but it does not replace rotation.
```

Question:

```text
How do you check for suspicious SSH activity?
```

Strong answer:

```text
I check /var/log/auth.log or journalctl for ssh/sshd logs. I look for failed password attempts, accepted logins, source IPs, usernames, and sudo activity. I can count failed attempts by source IP using grep, awk, sort, and uniq. I also check last and lastb where available. If suspicious activity is found, I review access, rotate keys, restrict firewall rules, and harden SSH.
```

---

# Today’s Core Rules

```text
Security starts with least privilege.
Do not run apps as root.
Do not allow public database ports.
Do not use chmod 777 in production.
Disable root SSH login.
Disable SSH password login after keys are verified.
Restrict SSH by firewall/security group.
Protect secrets with file permissions.
Never commit secrets.
Rotate leaked secrets immediately.
Review auth logs.
Patch regularly.
Remove unused services.
Use fail2ban as an additional layer, not the only defense.
```

Next lesson:

# Lesson 3.18 — Linux Troubleshooting Playbooks: production incident workflows for CPU, memory, disk, network, service failure, logs, permissions, and security.
