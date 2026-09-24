# Lesson 3.6 — Users, Groups, sudo, SSH Access, Service Accounts, and Linux Access Control in Production

Now we go deeper into **Linux identity and access control**.

In the previous lesson, we learned file permissions. But permissions are only half of the story.

The other half is:

```text
Who is trying to access the file?
```

That means users, groups, service accounts, sudo, SSH access, and process ownership.

In production, many incidents happen because of bad access design:

```text
Everyone uses root
Developers share one SSH key
Jenkins has too much sudo access
Application runs as root
Docker socket is exposed
Private keys have weak permissions
Service user cannot read config
Service user can write too much
Old employee SSH key still works
```

A DevOps engineer must know how to design access safely.

---

# 1. Linux Access Control Mental Model

Every action on Linux has an identity.

When a process tries to read, write, execute, bind a port, or open a socket, Linux checks:

```text
Which user is running this process?
Which groups does that user belong to?
What permissions exist on the file/directory/socket?
Is sudo involved?
Are ACLs involved?
Are MAC systems like AppArmor/SELinux involved?
```

Basic model:

```text
User
  ↓
Groups
  ↓
Process
  ↓
File / directory / socket / port
  ↓
Permission decision
```

Example:

```text
Jenkins process runs as user: jenkins
Workspace owned by: root
Jenkins tries to write file
Linux says: Permission denied
```

Fixing this properly means understanding users and groups, not blindly running:

```bash
sudo chmod -R 777 /var/lib/jenkins
```

---

# 2. Types of Users in Linux

Linux users are not only humans.

There are three broad categories:

```text
Human users
System users
Service users
```

## Human users

Examples:

```text
vivek
ubuntu
ec2-user
admin
developer1
```

Used by real people to log in.

## System users

Examples:

```text
root
daemon
bin
sys
nobody
```

Used by the operating system.

## Service users

Examples:

```text
www-data
nginx
jenkins
postgres
mysql
redis
mongodb
prometheus
grafana
```

Used by services and applications.

Production rule:

```text
Applications and services should run as dedicated service users, not as root.
```

---

# 3. Check Current User

```bash
whoami
```

Example:

```text
vivek
```

Check identity and groups:

```bash
id
```

Example:

```text
uid=1000(vivek) gid=1000(vivek) groups=1000(vivek),27(sudo),999(docker)
```

Meaning:

```text
uid=1000(vivek)       user ID
gid=1000(vivek)       primary group ID
groups=...            supplementary groups
```

Show all groups:

```bash
groups
```

Show another user:

```bash
id root
id www-data
id jenkins
```

If user does not exist:

```text
id: ‘jenkins’: no such user
```

That simply means Jenkins user is not present on that system.

---

# 4. `/etc/passwd`

User account information lives in:

```text
/etc/passwd
```

View:

```bash
cat /etc/passwd
```

Each line looks like:

```text
vivek:x:1000:1000:Vivek,,,:/home/vivek:/bin/bash
```

Format:

```text
username:password-placeholder:UID:GID:comment:home:shell
```

Example breakdown:

```text
vivek       username
x           password stored in /etc/shadow
1000        user ID
1000        primary group ID
Vivek       comment/GECOS field
/home/vivek home directory
/bin/bash   login shell
```

Show only usernames:

```bash
cut -d: -f1 /etc/passwd
```

Show users with Bash shell:

```bash
grep "/bin/bash" /etc/passwd
```

Important:

```text
/etc/passwd is readable by normal users.
Password hashes are not stored here.
```

---

# 5. `/etc/shadow`

Password hashes live in:

```text
/etc/shadow
```

View requires root:

```bash
sudo cat /etc/shadow
```

This file is sensitive.

Normal permissions are usually:

```bash
ls -l /etc/shadow
```

Example:

```text
-rw-r----- 1 root shadow ... /etc/shadow
```

Do not copy or expose this file.

Production rule:

```text
Never leak /etc/shadow.
```

---

# 6. `/etc/group`

Group information lives in:

```text
/etc/group
```

View:

```bash
cat /etc/group
```

Line example:

```text
docker:x:999:vivek
```

Format:

```text
groupname:password-placeholder:GID:members
```

Show group names:

```bash
cut -d: -f1 /etc/group
```

Find docker group:

```bash
grep "^docker:" /etc/group
```

Find sudo group:

```bash
grep "^sudo:" /etc/group
```

---

# 7. User IDs and Group IDs

Linux internally uses numeric IDs.

```text
UID = user ID
GID = group ID
```

Root always has:

```text
UID 0
```

Check:

```bash
id root
```

Example:

```text
uid=0(root) gid=0(root) groups=0(root)
```

Important:

```text
Linux permissions are based on UID/GID, not usernames.
```

This matters in Docker and Kubernetes.

Example:

```text
Host directory owned by UID 1000.
Container process runs as UID 1001.
Container cannot write.
```

Even if usernames look different, numeric IDs matter.

---

# 8. Create a User

Create normal user:

```bash
sudo adduser devuser
```

`adduser` is interactive and beginner-friendly on Ubuntu.

Another lower-level command:

```bash
sudo useradd devuser
```

With home and shell:

```bash
sudo useradd -m -s /bin/bash devuser
```

Set password:

```bash
sudo passwd devuser
```

Check:

```bash
id devuser
grep "^devuser:" /etc/passwd
ls -ld /home/devuser
```

Delete user:

```bash
sudo deluser devuser
```

Delete user and home directory:

```bash
sudo deluser --remove-home devuser
```

Be careful. Removing home can delete important data.

---

# 9. Create a Group

Create group:

```bash
sudo groupadd devops
```

Check:

```bash
grep "^devops:" /etc/group
```

Add user to group:

```bash
sudo usermod -aG devops vivek
```

Important:

```text
-aG means append to supplementary groups.
```

Do not forget `-a`.

Bad:

```bash
sudo usermod -G devops vivek
```

This may replace existing supplementary groups and remove sudo/docker access.

Good:

```bash
sudo usermod -aG devops vivek
```

After group change, log out and log back in, or use:

```bash
newgrp devops
```

Check:

```bash
id vivek
```

---

# 10. Primary Group vs Supplementary Groups

A user has:

```text
Primary group
Supplementary groups
```

Check:

```bash
id
```

Primary group is shown as:

```text
gid=1000(vivek)
```

Supplementary groups:

```text
groups=1000(vivek),27(sudo),999(docker)
```

When you create a new file, its group is usually your primary group, unless the directory has setgid.

Example:

```bash
touch test.txt
ls -l test.txt
```

To create shared project files with a team group, use setgid directory.

Example:

```bash
sudo groupadd devteam
mkdir shared-project
sudo chgrp devteam shared-project
chmod 2775 shared-project
```

Now files created inside can inherit group `devteam`.

---

# 11. Switch User

Switch to another user:

```bash
su - devuser
```

Run a command as another user:

```bash
sudo -u devuser whoami
```

Run shell as another user:

```bash
sudo -u devuser -s
```

Check environment:

```bash
sudo -u devuser env | sort | head
```

This is very useful for debugging service accounts.

Example:

```bash
sudo -u www-data cat /var/www/html/index.html
```

This answers:

```text
Can the www-data user read this file?
```

---

# 12. What is sudo?

`sudo` allows permitted users to run commands as another user, usually root.

Example:

```bash
sudo apt update
```

This runs `apt update` as root.

Check if you have sudo:

```bash
sudo -v
```

List your sudo privileges:

```bash
sudo -l
```

Example output may show:

```text
User vivek may run the following commands on host:
    (ALL : ALL) ALL
```

Meaning:

```text
vivek can run any command as any user/group using sudo.
```

Powerful. Dangerous.

Production principle:

```text
Give only the sudo access needed.
```

---

# 13. sudoers

Sudo configuration lives in:

```text
/etc/sudoers
/etc/sudoers.d/
```

Never edit `/etc/sudoers` directly with `nano`.

Use:

```bash
sudo visudo
```

For custom rule, use a file under:

```text
/etc/sudoers.d/
```

Example:

```bash
sudo visudo -f /etc/sudoers.d/devops
```

Example rule:

```text
vivek ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart myapp
```

Meaning:

```text
vivek can restart myapp without password.
```

But this exact rule may still be risky because `systemctl` can sometimes be abused depending on allowed commands and service definitions.

A more controlled production setup may use deployment automation instead of broad human sudo.

---

# 14. Dangerous sudo Rules

Bad:

```text
jenkins ALL=(ALL) NOPASSWD: ALL
```

This means Jenkins can run anything as root without password.

If Jenkins is compromised, the server is compromised.

Better:

```text
jenkins ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp
```

Even better:

```text
Use a deployment agent with narrow permissions.
Use systemd service ownership carefully.
Use CI/CD credentials and approvals.
Avoid shell access when possible.
```

Another dangerous rule:

```text
developer ALL=(ALL) NOPASSWD: /bin/bash
```

This is basically full root.

Because:

```bash
sudo /bin/bash
```

gives root shell.

---

# 15. SSH Access Mental Model

SSH access has three parts:

```text
Client private key
Server public key authorization
Server SSH daemon configuration
```

Flow:

```text
Your machine has private key
  ↓
Server has matching public key in authorized_keys
  ↓
SSH proves private key ownership
  ↓
Server allows login
```

Client private key:

```text
~/.ssh/id_ed25519
```

Client public key:

```text
~/.ssh/id_ed25519.pub
```

Server allowed keys:

```text
~/.ssh/authorized_keys
```

Correct permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/authorized_keys
```

---

# 16. Generate SSH Key

Generate key:

```bash
ssh-keygen -t ed25519 -C "vivek@example.com"
```

Recommended modern key type:

```text
ed25519
```

Show public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy public key to server:

```bash
ssh-copy-id user@server-ip
```

Manual method:

```bash
cat ~/.ssh/id_ed25519.pub
```

Then append to server:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Test:

```bash
ssh user@server-ip
```

Verbose debug:

```bash
ssh -v user@server-ip
```

More verbose:

```bash
ssh -vvv user@server-ip
```

---

# 17. SSH Config File

Client config:

```text
~/.ssh/config
```

Example:

```text
Host dev-server
    HostName 203.0.113.10
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    Port 22
```

Then connect:

```bash
ssh dev-server
```

Permissions:

```bash
chmod 600 ~/.ssh/config
```

This is helpful when managing many servers.

Example:

```text
Host prod-web-1
    HostName 10.0.1.15
    User ubuntu
    IdentityFile ~/.ssh/prod_key

Host staging-web-1
    HostName 10.0.2.15
    User ubuntu
    IdentityFile ~/.ssh/staging_key
```

---

# 18. SSH Server Config

Server config:

```text
/etc/ssh/sshd_config
```

View:

```bash
sudo less /etc/ssh/sshd_config
```

Common settings:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Port 22
AllowUsers ubuntu vivek
```

Before editing:

```bash
sudo cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.$(date +%Y%m%d-%H%M%S).bak"
```

Validate:

```bash
sudo sshd -t
```

Reload:

```bash
sudo systemctl reload ssh
```

or on some systems:

```bash
sudo systemctl reload sshd
```

Important production warning:

```text
Never close your current SSH session until you confirm a new SSH session works.
```

Otherwise, you can lock yourself out.

---

# 19. Root SSH Login

Production recommendation:

```text
Disable direct root SSH login.
```

In `/etc/ssh/sshd_config`:

```text
PermitRootLogin no
```

Why?

```text
Attackers commonly brute-force root.
Human users should log in individually.
Privilege escalation should happen through sudo.
This improves auditing.
```

Better flow:

```text
SSH as ubuntu/vivek
  ↓
sudo for privileged command
```

---

# 20. Password SSH Login

Production recommendation:

```text
Disable password SSH login and use keys.
```

In config:

```text
PasswordAuthentication no
PubkeyAuthentication yes
```

Why?

```text
Passwords can be brute-forced.
Keys are stronger when protected properly.
```

But before disabling passwords:

```text
Confirm key login works.
Keep current SSH session open.
Have cloud console/recovery access.
```

---

# 21. Service Accounts

A service account is a user created for a service, not a human.

Examples:

```text
myapp
backup
deploy
prometheus
node_exporter
```

Create service user with no login shell:

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin myapp
```

Check:

```bash
id myapp
grep "^myapp:" /etc/passwd
```

No login shell means humans cannot normally log in as that user.

Why service users?

```text
Least privilege
Isolation
Clear ownership
Better auditing
Safer systemd services
```

Example app directory:

```bash
sudo mkdir -p /opt/myapp
sudo chown -R myapp:myapp /opt/myapp
```

Then systemd service can run as:

```text
User=myapp
Group=myapp
```

We will cover systemd service files later.

---

# 22. Why Apps Should Not Run as Root

Bad:

```text
Node app runs as root
Python app runs as root
Container runs as root
```

Risks:

```text
Application vulnerability becomes root-level compromise.
Bug can overwrite system files.
Compromised app can read sensitive files.
```

Better:

```text
Create dedicated service user.
Give only required access.
Run process as that user.
```

Example:

```bash
sudo useradd --system --shell /usr/sbin/nologin --home /opt/todo-api todo-api
sudo mkdir -p /opt/todo-api
sudo chown -R todo-api:todo-api /opt/todo-api
```

Later systemd:

```ini
User=todo-api
Group=todo-api
WorkingDirectory=/opt/todo-api/current
ExecStart=/usr/bin/node server.js
```

---

# 23. Shared Human Accounts Are Bad

Bad:

```text
Everyone logs in as ubuntu
Everyone uses same private key
Everyone uses root
```

Why bad?

```text
No individual accountability
Hard to revoke one person
Hard to audit actions
High blast radius
```

Better:

```text
Individual user accounts
Individual SSH keys
Group-based permissions
sudo logs
Central identity where possible
```

Cloud examples:

```text
AWS Systems Manager Session Manager
Bastion with individual accounts
LDAP/SSO integration
Teleport
Boundary
```

We will not implement those now, but you should know the direction.

---

# 24. Audit Login Activity

Show currently logged-in users:

```bash
who
```

Show login history:

```bash
last
```

Show failed login attempts, Ubuntu:

```bash
sudo grep "Failed password" /var/log/auth.log
```

Show accepted SSH logins:

```bash
sudo grep "Accepted" /var/log/auth.log
```

Follow auth log:

```bash
sudo tail -f /var/log/auth.log
```

On systemd systems:

```bash
journalctl -u ssh
```

or:

```bash
journalctl -u sshd
```

Sudo logs may also appear in:

```bash
sudo grep "sudo" /var/log/auth.log
```

---

# 25. Lock and Unlock Users

Lock user:

```bash
sudo usermod -L devuser
```

Unlock user:

```bash
sudo usermod -U devuser
```

Expire user password:

```bash
sudo passwd -e devuser
```

Disable login by shell:

```bash
sudo usermod -s /usr/sbin/nologin devuser
```

Check:

```bash
grep "^devuser:" /etc/passwd
```

Delete user after offboarding:

```bash
sudo deluser devuser
```

Production offboarding checklist:

```text
Disable user
Remove SSH keys
Remove sudo privileges
Remove group memberships
Rotate shared secrets if any
Check active sessions
Audit recent activity
```

---

# 26. `nobody` User

`nobody` is a low-privilege user.

Check:

```bash
id nobody
```

Sometimes services use `nobody`, but better practice is usually dedicated service user.

Bad:

```text
Run all low-privilege services as nobody
```

Better:

```text
Run each service as its own account
```

Why?

```text
Isolation.
If multiple services run as nobody, compromise of one may affect files of another.
```

---

# 27. Access to Low Ports

Ports below 1024 are privileged.

Examples:

```text
80
443
22
```

Normally only root can bind them.

That is why Nginx master starts as root, then workers run as non-root.

Options:

```text
Run reverse proxy as root-managed service
Use capabilities
Use higher port like 3000 behind load balancer
Use systemd socket activation
Use container port mapping
```

Capability example:

```bash
sudo setcap 'cap_net_bind_service=+ep' /usr/bin/node
```

But be careful. Capabilities are advanced and should be used intentionally.

Common production pattern:

```text
App runs on 127.0.0.1:3000 as non-root
Nginx/ALB handles 80/443
```

---

# 28. Linux Capabilities Basic Idea

Root privileges can be split into capabilities.

Examples:

```text
CAP_NET_BIND_SERVICE  bind low ports
CAP_NET_ADMIN         network administration
CAP_SYS_ADMIN         very powerful
```

View capabilities of process:

```bash
getpcaps <pid>
```

Install tools if needed:

```bash
sudo apt install -y libcap2-bin
```

View file capabilities:

```bash
getcap /usr/bin/ping
```

Capabilities are useful but advanced.

For now, remember:

```text
Avoid root where possible.
Use narrow privileges where required.
```

---

# 29. Lab — Users and Groups

Create lab group:

```bash
sudo groupadd devops-lab
```

Create lab user:

```bash
sudo useradd -m -s /bin/bash labuser
sudo passwd labuser
```

Add user to group:

```bash
sudo usermod -aG devops-lab labuser
```

Check:

```bash
id labuser
```

Create shared directory:

```bash
mkdir -p ~/devops-masterclass/03-linux-bash-networking/labs/access-control/shared
sudo chgrp devops-lab ~/devops-masterclass/03-linux-bash-networking/labs/access-control/shared
chmod 2775 ~/devops-masterclass/03-linux-bash-networking/labs/access-control/shared
```

Check:

```bash
ls -ld ~/devops-masterclass/03-linux-bash-networking/labs/access-control/shared
```

Test as labuser:

```bash
sudo -u labuser bash -c 'touch ~/test-from-labuser'
```

This writes to labuser’s home.

Test shared dir:

```bash
sudo -u labuser bash -c 'touch /home/vivek/devops-masterclass/03-linux-bash-networking/labs/access-control/shared/labuser-file'
```

If permission denied, inspect:

```bash
namei -l /home/vivek/devops-masterclass/03-linux-bash-networking/labs/access-control/shared
```

This may fail because parent directories under your home may not allow traversal by labuser.

This is an important lesson:

```text
Even if final directory has group write, parent directories must allow traversal.
```

For clean shared labs, create under `/srv` or `/tmp`:

```bash
sudo mkdir -p /srv/devops-lab/shared
sudo chgrp devops-lab /srv/devops-lab/shared
sudo chmod 2775 /srv/devops-lab/shared
sudo -u labuser touch /srv/devops-lab/shared/labuser-file
ls -l /srv/devops-lab/shared
```

Cleanup later:

```bash
sudo rm -rf /srv/devops-lab
sudo deluser --remove-home labuser
sudo groupdel devops-lab
```

---

# 30. Script — User Access Inspector

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/user-access-inspector.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${1:-}"

if [ -z "$TARGET_USER" ]; then
  echo "Usage: $0 <username>" >&2
  exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "ERROR: User does not exist: $TARGET_USER" >&2
  exit 1
fi

echo "===== User Access Inspector ====="
echo "User: $TARGET_USER"
echo "Generated at: $(date)"
echo

echo "===== Identity ====="
id "$TARGET_USER"
echo

echo "===== passwd entry ====="
grep "^${TARGET_USER}:" /etc/passwd || true
echo

echo "===== Groups ====="
groups "$TARGET_USER"
echo

echo "===== Home Directory ====="
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
echo "Home: $USER_HOME"

if [ -d "$USER_HOME" ]; then
  ls -ld "$USER_HOME"
else
  echo "Home directory does not exist"
fi
echo

echo "===== Shell ====="
USER_SHELL="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
echo "Shell: $USER_SHELL"
echo

echo "===== Sudo Privileges ====="
if [ "$TARGET_USER" = "$(whoami)" ]; then
  sudo -l || true
else
  echo "Run manually if needed:"
  echo "sudo -l -U $TARGET_USER"
fi
echo

echo "===== Recent Login Entries ====="
last "$TARGET_USER" | head -10 || true
echo

echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/user-access-inspector.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/user-access-inspector.sh "$USER"
```

Try:

```bash
./03-linux-bash-networking/scripts/user-access-inspector.sh root
```

This script helps audit user identity quickly.

---

# 31. Script — SSH Permission Fix Checker

Create:

```bash
nano 03-linux-bash-networking/scripts/check-ssh-permissions.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SSH_DIR="${HOME}/.ssh"

echo "===== SSH Permission Checker ====="
echo "User: $(whoami)"
echo "SSH directory: $SSH_DIR"
echo

if [ ! -d "$SSH_DIR" ]; then
  echo "No ~/.ssh directory found."
  exit 0
fi

echo "===== Current Permissions ====="
ls -la "$SSH_DIR"
echo

check_mode() {
  local path="$1"
  local expected="$2"

  if [ -e "$path" ]; then
    local actual
    actual="$(stat -c "%a" "$path")"

    if [ "$actual" = "$expected" ]; then
      echo "OK: $path has mode $actual"
    else
      echo "WARN: $path has mode $actual, expected $expected"
    fi
  fi
}

check_mode "$SSH_DIR" "700"
check_mode "$SSH_DIR/id_ed25519" "600"
check_mode "$SSH_DIR/id_rsa" "600"
check_mode "$SSH_DIR/authorized_keys" "600"
check_mode "$SSH_DIR/config" "600"

echo
echo "Suggested fixes:"
echo "chmod 700 ~/.ssh"
echo "chmod 600 ~/.ssh/id_ed25519 2>/dev/null || true"
echo "chmod 600 ~/.ssh/id_rsa 2>/dev/null || true"
echo "chmod 600 ~/.ssh/authorized_keys 2>/dev/null || true"
echo "chmod 600 ~/.ssh/config 2>/dev/null || true"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/check-ssh-permissions.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/check-ssh-permissions.sh
```

This is a useful real-world script.

---

# 32. Create Notes

Create:

```bash
nano 03-linux-bash-networking/users-groups-sudo-ssh.md
```

Paste:

````markdown
# Users, Groups, sudo, SSH, and Service Accounts

## Mental Model

Every Linux access decision starts with identity:

```text
User → Groups → Process → File/socket/port → Permission decision
````

## Important Files

| File                     | Purpose                  |
| ------------------------ | ------------------------ |
| `/etc/passwd`            | User account metadata    |
| `/etc/shadow`            | Password hashes          |
| `/etc/group`             | Group metadata           |
| `/etc/sudoers`           | sudo configuration       |
| `/etc/sudoers.d/`        | sudo rule snippets       |
| `~/.ssh/authorized_keys` | Allowed SSH public keys  |
| `/etc/ssh/sshd_config`   | SSH server configuration |

## Commands

```bash
whoami
id
groups
cat /etc/passwd
cat /etc/group
sudo cat /etc/shadow
sudo adduser devuser
sudo useradd -m -s /bin/bash devuser
sudo passwd devuser
sudo groupadd devops
sudo usermod -aG devops devuser
sudo -u www-data whoami
sudo -l
sudo visudo
ssh -v user@host
last
who
```

## SSH Permissions

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/config
```

## Production Rules

* Do not share human accounts.
* Do not allow direct root SSH login.
* Prefer SSH keys over passwords.
* Use sudo only when needed.
* Avoid broad NOPASSWD sudo rules.
* Run services as dedicated service users.
* Do not run applications as root.
* Use groups for shared access.
* Use least privilege.
* Treat Docker group as powerful.

````

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/users-groups-sudo-ssh.md \
        03-linux-bash-networking/scripts/user-access-inspector.sh \
        03-linux-bash-networking/scripts/check-ssh-permissions.sh

git diff --staged

git commit -m "docs: add users groups sudo and SSH access control"
git push
````

---

# 33. Real Production Scenario — Offboarding User

Situation:

```text
A developer left the company.
```

Checklist:

```text
Disable Linux user
Remove SSH keys
Remove sudo access
Remove from deployment groups
Rotate shared keys/secrets
Check active sessions
Audit recent commands/logins
Remove GitHub/org access
Remove cloud IAM access
Remove VPN access
```

Linux commands:

```bash
sudo usermod -L devuser
sudo usermod -s /usr/sbin/nologin devuser
who
last devuser
sudo grep "devuser" /var/log/auth.log
```

Remove later:

```bash
sudo deluser --remove-home devuser
```

But do not remove immediately if home contains important work. Archive first if policy allows.

---

# 34. Real Production Scenario — Jenkins Needs Limited Restart Permission

Problem:

```text
Jenkins must restart myapp after deployment.
But Jenkins should not have full root.
```

Bad sudo rule:

```text
jenkins ALL=(ALL) NOPASSWD: ALL
```

Better:

```text
jenkins ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp
```

Check exact systemctl path:

```bash
command -v systemctl
```

Edit sudoers safely:

```bash
sudo visudo -f /etc/sudoers.d/jenkins-myapp
```

Add:

```text
jenkins ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp
```

Test:

```bash
sudo -u jenkins sudo /usr/bin/systemctl restart myapp
```

Caution:

```text
Even limited sudo can be risky depending on service file permissions.
If Jenkins can edit myapp.service, it can escalate.
```

So also protect:

```text
/etc/systemd/system/myapp.service
Application startup scripts
Environment files
```

---

# 35. Real Production Scenario — App Service User

Create service account:

```bash
sudo useradd --system --shell /usr/sbin/nologin --home /opt/todo-api todo-api
```

Create app directories:

```bash
sudo mkdir -p /opt/todo-api/releases
sudo mkdir -p /var/log/todo-api
sudo chown -R todo-api:todo-api /opt/todo-api
sudo chown -R todo-api:todo-api /var/log/todo-api
```

Permissions:

```bash
sudo chmod 750 /opt/todo-api
sudo chmod 750 /var/log/todo-api
```

Why?

```text
todo-api user can run app and write logs.
Others cannot casually read/write app data.
```

Later, systemd service:

```ini
User=todo-api
Group=todo-api
WorkingDirectory=/opt/todo-api/current
```

This is production-style service isolation.

---

# 36. Interview Answers

Question:

```text
Why should applications not run as root?
```

Strong answer:

```text
Applications should not run as root because any vulnerability in the application could become a root-level system compromise. Running the app as a dedicated low-privilege service user limits the blast radius. The service user should only have access to the files, directories, ports, and resources the application actually needs.
```

Question:

```text
What is the difference between a human user and a service user?
```

Strong answer:

```text
A human user represents a real person who logs in interactively, usually through SSH. A service user is a non-human account used to run a specific service or application, such as nginx, postgres, jenkins, or a custom app user. Service users usually have limited permissions and often no login shell, following least privilege.
```

Question:

```text
How would you secure SSH access to a Linux server?
```

Strong answer:

```text
I would use key-based authentication, disable direct root login, disable password login after verifying keys work, enforce correct permissions on .ssh and authorized_keys, restrict users where appropriate, monitor auth logs, and ensure each person has an individual account and key. I would avoid shared accounts and remove keys immediately during offboarding.
```

Question:

```text
Why is giving Jenkins NOPASSWD ALL dangerous?
```

Strong answer:

```text
Giving Jenkins NOPASSWD ALL means any Jenkins job or compromised Jenkins plugin can run arbitrary commands as root without a password. That effectively gives Jenkins full control of the server. A safer approach is to grant only the exact commands Jenkins needs, protect related files like systemd units and scripts, and preferably deploy through controlled automation with approvals.
```

---

# Today’s Core Rules

```text
Access starts with identity.
Users can be humans, system users, or service users.
Use id and groups to understand access.
Use /etc/passwd, /etc/group, and /etc/shadow carefully.
Use sudo only when needed.
Edit sudoers with visudo.
Avoid broad NOPASSWD sudo.
Use SSH keys, not shared passwords.
Do not allow direct root SSH in production.
Run services as dedicated non-root users.
Do not share human accounts.
Offboarding must remove all access paths.
```

Next lesson:

# Lesson 3.7 — Processes Masterclass: ps, pgrep, top, htop, kill, signals, nice, renice, lsof, zombies, process troubleshooting
