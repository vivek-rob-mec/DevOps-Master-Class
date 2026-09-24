# Lesson 3.5 — Permissions Masterclass

Now we learn one of the most important Linux topics:

```text
Permissions.
```

This lesson is critical for DevOps because many real errors look like this:

```text
Permission denied
Cannot write file
Cannot execute script
SSH key permissions are too open
Nginx cannot read certificate
Docker cannot access mounted volume
Jenkins cannot write workspace
Application cannot read .env
Kubernetes volume mounted with wrong owner
```

A beginner fixes everything with:

```bash
chmod -R 777 .
```

A DevOps engineer understands ownership, groups, mode bits, sudo, umask, and safe least privilege.

---

# 1. Why Permissions Matter

Linux is multi-user.

That means many users and processes can exist on the same machine:

```text
root
vivek
www-data
nginx
jenkins
docker
postgres
mysql
redis
ubuntu
ec2-user
```

Each file has:

```text
Owner
Group
Permission bits
```

Each process runs as a user.

So the key question is:

```text
Does this process user have permission to access this file?
```

Example:

```text
Nginx process runs as www-data.
TLS certificate is owned by root.
Can www-data read the certificate?
```

Another example:

```text
Jenkins process runs as jenkins.
Workspace directory is owned by root.
Can Jenkins write build files?
```

Permissions are about matching:

```text
Process user → file ownership → allowed operation
```

---

# 2. View File Permissions

Run:

```bash
ls -l
```

Example:

```text
-rw-r--r-- 1 vivek vivek 120 Jun 28 10:00 README.md
drwxr-xr-x 3 vivek vivek 4096 Jun 28 10:01 scripts
-rwxr-xr-x 1 vivek vivek 200 Jun 28 10:02 deploy.sh
```

Understand this part:

```text
-rw-r--r--
```

Breakdown:

```text
-    rw-    r--    r--
│     │      │      │
│     │      │      └── others permissions
│     │      └───────── group permissions
│     └──────────────── owner permissions
└────────────────────── file type
```

File type:

```text
-  regular file
d  directory
l  symbolic link
c  character device
b  block device
s  socket
p  pipe
```

Permission letters:

```text
r = read
w = write
x = execute
```

---

# 3. Permission Meaning for Files

For a file:

```text
r = can read file contents
w = can modify file contents
x = can execute file as a program/script
```

Example:

```text
-rw-r--r-- README.md
```

Meaning:

```text
Owner can read/write.
Group can read.
Others can read.
Nobody can execute.
```

Example:

```text
-rwxr-xr-x deploy.sh
```

Meaning:

```text
Owner can read/write/execute.
Group can read/execute.
Others can read/execute.
```

To run a script directly:

```bash
./deploy.sh
```

It needs execute permission.

Without execute permission, you get:

```text
Permission denied
```

But this can still work:

```bash
bash deploy.sh
```

Because you are executing `bash`, and Bash reads the file.

For direct execution, the file itself needs `x`.

---

# 4. Permission Meaning for Directories

Directory permissions are different.

For a directory:

```text
r = can list directory names
w = can create/delete/rename entries inside
x = can enter/traverse directory
```

This is very important.

Example:

```text
drwxr-xr-x scripts
```

Owner can:

```text
List files
Enter directory
Create/delete files
```

Group and others can:

```text
List files
Enter directory
```

But cannot create/delete.

To access a file inside a directory, you need execute permission on the directory path.

Example:

```text
/home/vivek/private/file.txt
```

You need `x` permission on:

```text
/
/home
/home/vivek
/home/vivek/private
```

And read permission on `file.txt`.

This explains many confusing permission errors.

---

# 5. Numeric Permissions

Permissions also have numbers:

```text
r = 4
w = 2
x = 1
```

Add them:

```text
7 = rwx = 4+2+1
6 = rw- = 4+2
5 = r-x = 4+1
4 = r-- = 4
0 = --- 
```

Common modes:

```text
755 = rwxr-xr-x
644 = rw-r--r--
600 = rw-------
700 = rwx------
775 = rwxrwxr-x
664 = rw-rw-r--
777 = rwxrwxrwx
```

Examples:

```bash
chmod 644 README.md
chmod 755 script.sh
chmod 600 ~/.ssh/id_ed25519
chmod 700 ~/.ssh
```

---

# 6. Symbolic Permissions

Instead of numbers, you can use symbols.

```text
u = user/owner
g = group
o = others
a = all
```

Operators:

```text
+ add permission
- remove permission
= set exact permission
```

Examples:

```bash
chmod u+x script.sh
chmod g+w shared.txt
chmod o-r secret.txt
chmod a-rwx private.key
chmod u=rw,g=r,o= file.txt
```

Make all `.sh` scripts executable:

```bash
chmod u+x *.sh
```

Recursive:

```bash
chmod -R u+rwX,g+rX,o-rwx project/
```

Notice uppercase `X`.

```text
X adds execute only to directories and files that already have execute.
```

Useful for directory trees.

---

# 7. `chmod` — Change Permissions

Make script executable:

```bash
chmod +x script.sh
```

Better:

```bash
chmod u+x script.sh
```

Set common file permission:

```bash
chmod 644 file.txt
```

Set common script permission:

```bash
chmod 755 deploy.sh
```

Set private key permission:

```bash
chmod 600 ~/.ssh/id_ed25519
```

Set SSH directory permission:

```bash
chmod 700 ~/.ssh
```

Dangerous:

```bash
chmod -R 777 .
```

Why dangerous?

```text
Everyone can read, write, and execute everything.
Secrets may be exposed.
Scripts can be modified by other users.
Apps may refuse insecure files.
SSH rejects overly open private keys.
```

---

# 8. `chown` — Change Owner

Check ownership:

```bash
ls -l
```

Example:

```text
-rw-r--r-- 1 root root 100 app.log
```

If your user needs ownership:

```bash
sudo chown vivek:vivek app.log
```

Syntax:

```bash
chown user:group file
```

Change owner only:

```bash
sudo chown vivek file.txt
```

Change group only:

```bash
sudo chown :developers file.txt
```

Recursive:

```bash
sudo chown -R vivek:vivek project/
```

Be careful with recursive `chown`.

Bad:

```bash
sudo chown -R vivek:vivek /
```

Catastrophic.

Production example:

```bash
sudo chown -R www-data:www-data /var/www/myapp
```

But only if `www-data` should own those files.

For static web files, often better:

```text
root owns files
www-data can read
deployment user can update via controlled pipeline
```

---

# 9. `chgrp` — Change Group

Change group:

```bash
sudo chgrp developers shared.txt
```

Recursive:

```bash
sudo chgrp -R developers shared-project/
```

Useful when multiple users need access through a shared group.

---

# 10. Users and Groups

Check current user:

```bash
whoami
```

Check user id and groups:

```bash
id
```

Example:

```text
uid=1000(vivek) gid=1000(vivek) groups=1000(vivek),27(sudo),999(docker)
```

Meaning:

```text
Your primary group is vivek.
You are also in sudo and docker groups.
```

List groups:

```bash
groups
```

Check another user:

```bash
id jenkins
```

Important:

```text
Permissions apply based on user and group membership.
```

If process runs as `jenkins`, check:

```bash
id jenkins
```

If process runs as `www-data`, check:

```bash
id www-data
```

---

# 11. Root User

Root can do almost anything.

Check:

```bash
whoami
```

If output:

```text
root
```

You are root.

Root is powerful and dangerous.

Bad habit:

```bash
sudo su -
```

Then doing everything as root.

Better:

```text
Use normal user.
Use sudo only for commands requiring privilege.
```

Why?

```text
Reduces accidental damage.
Creates clearer audit trail.
Prevents root-owned files in user workspace.
```

Common problem:

```bash
sudo npm install
```

or:

```bash
sudo git clone ...
```

This can create root-owned files in your project.

Then later:

```text
Permission denied
```

Fix ownership:

```bash
sudo chown -R "$USER:$USER" ~/devops-masterclass
```

Use carefully.

---

# 12. `sudo`

`sudo` runs a command with elevated privileges.

Example:

```bash
sudo apt update
```

Check sudo access:

```bash
sudo -v
```

Run command as another user:

```bash
sudo -u www-data whoami
```

Example:

```bash
sudo -u www-data cat /var/www/html/index.html
```

This is useful for testing whether a service user can read a file.

Run shell as another user:

```bash
sudo -u jenkins -s
```

Use carefully.

View sudo config:

```bash
sudo visudo
```

Never edit sudoers directly with normal editor.

Use:

```bash
sudo visudo
```

Because it validates syntax.

---

# 13. Service Users

Many services run as dedicated users:

```text
nginx       or www-data
apache      or www-data
jenkins
postgres
mysql
redis
mongodb
docker-related users
```

Check service process user:

```bash
ps aux | grep nginx
```

Example:

```text
root      nginx master process
www-data  nginx worker process
```

This means:

```text
Master process starts as root to bind port 80/443.
Worker processes handle requests as www-data.
```

When Nginx cannot read files, test:

```bash
sudo -u www-data ls -la /path/to/file
sudo -u www-data cat /path/to/file
```

This is a professional debugging technique.

---

# 14. Permission Debugging Method

When you see:

```text
Permission denied
```

Ask:

```text
Which user is running the command/process?
What file/directory is being accessed?
Who owns the file?
What are file permissions?
What are parent directory permissions?
Is there ACL/AppArmor/SELinux involved?
Is filesystem mounted read-only?
```

Commands:

```bash
whoami
id
ls -l file
namei -l /full/path/to/file
mount | grep " / "
```

Very useful command:

```bash
namei -l /home/vivek/devops-masterclass/script.sh
```

It shows permissions for every path component.

This helps find parent directory traversal issues.

---

# 15. `umask`

`umask` controls default permissions for new files and directories.

Check:

```bash
umask
```

Common:

```text
0022
```

Default base permissions:

```text
Files:       666
Directories: 777
```

Apply umask:

```text
File default:      666 - 022 = 644
Directory default: 777 - 022 = 755
```

Create test:

```bash
umask
touch test-file
mkdir test-dir
ls -ld test-file test-dir
rm test-file
rmdir test-dir
```

Change temporarily:

```bash
umask 0077
touch private-file
mkdir private-dir
ls -ld private-file private-dir
```

You may see:

```text
-rw------- private-file
drwx------ private-dir
```

This is useful for private files.

Do not casually change global umask on production without understanding impact.

---

# 16. Sticky Bit

Sticky bit is common on `/tmp`.

Check:

```bash
ls -ld /tmp
```

You may see:

```text
drwxrwxrwt
```

Notice:

```text
t
```

Sticky bit means:

```text
Users can create files in directory,
but only file owner, directory owner, or root can delete them.
```

Why `/tmp` needs this:

```text
Many users can write to /tmp.
But they should not delete each other’s files.
```

Set sticky bit:

```bash
chmod +t shared-dir
```

Numeric:

```bash
chmod 1777 shared-dir
```

Common permission:

```text
/tmp = 1777
```

---

# 17. setuid

setuid allows executable to run with file owner’s privileges.

Check:

```bash
ls -l /usr/bin/passwd
```

You may see:

```text
-rwsr-xr-x root root /usr/bin/passwd
```

Notice:

```text
s
```

Why?

Normal users need to change their password, which updates protected system files.

`passwd` runs with root privileges in a controlled way.

Set setuid:

```bash
chmod u+s file
```

Remove:

```bash
chmod u-s file
```

Security warning:

```text
setuid is dangerous.
Never set it casually on scripts or custom binaries.
```

---

# 18. setgid

For executable files, setgid runs with group privileges.

For directories, setgid makes new files inherit the directory group.

This is useful for shared project directories.

Example:

```bash
sudo groupadd devteam
mkdir shared
sudo chgrp devteam shared
chmod 2775 shared
```

Check:

```bash
ls -ld shared
```

You may see:

```text
drwxrwsr-x
```

Notice:

```text
s in group execute position
```

Files created inside inherit group `devteam`.

Use case:

```text
Team shared deployment directory
Shared logs directory
Collaborative project folder
```

---

# 19. ACLs — Access Control Lists

Normal permissions have:

```text
owner
group
others
```

ACLs allow more specific permissions.

Check ACL:

```bash
getfacl file.txt
```

Install if missing:

```bash
sudo apt install -y acl
```

Grant user read/write:

```bash
setfacl -m u:jenkins:rw file.txt
```

Grant user access to directory:

```bash
setfacl -m u:jenkins:rwx shared-dir
```

Default ACL for new files:

```bash
setfacl -d -m u:jenkins:rwx shared-dir
```

Remove ACL:

```bash
setfacl -b file.txt
```

ACLs are useful but can make permissions harder to reason about.

Use them when normal owner/group model is not enough.

---

# 20. SSH Permissions

SSH is strict.

Correct permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/authorized_keys
```

Check:

```bash
ls -la ~/.ssh
```

Common error:

```text
WARNING: UNPROTECTED PRIVATE KEY FILE!
Permissions 0644 for 'id_ed25519' are too open.
This private key will be ignored.
```

Fix:

```bash
chmod 600 ~/.ssh/id_ed25519
```

For server login, `authorized_keys` should not be writable by others.

---

# 21. Docker Socket Permission Warning

Docker socket often exists at:

```text
/var/run/docker.sock
```

Check:

```bash
ls -l /var/run/docker.sock
```

Example:

```text
srw-rw---- 1 root docker ... /var/run/docker.sock
```

Users in `docker` group can access it.

Add user to Docker group:

```bash
sudo usermod -aG docker "$USER"
```

Then log out and log back in.

Important security warning:

```text
Docker group is effectively root-level access on many systems.
```

Why?

A Docker user can mount host filesystem into a container and access host files.

So do not add users to Docker group casually on production.

---

# 22. Permission Lab

Create lab:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/labs/permissions
cd 03-linux-bash-networking/labs/permissions
```

Create files:

```bash
echo "hello" > file.txt
echo 'echo "hello from script"' > script.sh
mkdir private-dir
```

Check:

```bash
ls -la
```

Try running script:

```bash
./script.sh
```

You may get:

```text
Permission denied
```

Fix:

```bash
chmod u+x script.sh
./script.sh
```

Set private file:

```bash
chmod 600 file.txt
ls -l file.txt
```

Set private directory:

```bash
chmod 700 private-dir
ls -ld private-dir
```

Test umask:

```bash
umask
touch default-file
mkdir default-dir
ls -ld default-file default-dir
```

Test restrictive umask:

```bash
umask 0077
touch private-file
mkdir private-folder
ls -ld private-file private-folder
```

Restore common umask:

```bash
umask 0022
```

---

# 23. Permission Debug Script

Create script:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/permission-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-}"

if [ -z "$TARGET_PATH" ]; then
  echo "Usage: $0 <path>" >&2
  exit 1
fi

if [ ! -e "$TARGET_PATH" ]; then
  echo "ERROR: Path does not exist: $TARGET_PATH" >&2
  exit 1
fi

echo "===== Permission Check ====="
echo "Target: $TARGET_PATH"
echo "Current user: $(whoami)"
echo "User identity:"
id
echo

echo "===== ls -ld ====="
ls -ld "$TARGET_PATH"
echo

echo "===== stat ====="
stat "$TARGET_PATH"
echo

echo "===== Parent Path Permissions ====="
if command -v namei >/dev/null 2>&1; then
  namei -l "$(realpath "$TARGET_PATH")"
else
  echo "namei command not found"
fi
echo

echo "===== Access Tests for Current User ====="

if [ -r "$TARGET_PATH" ]; then
  echo "Readable: yes"
else
  echo "Readable: no"
fi

if [ -w "$TARGET_PATH" ]; then
  echo "Writable: yes"
else
  echo "Writable: no"
fi

if [ -x "$TARGET_PATH" ]; then
  echo "Executable/traversable: yes"
else
  echo "Executable/traversable: no"
fi

echo
echo "===== ACL ====="
if command -v getfacl >/dev/null 2>&1; then
  getfacl "$TARGET_PATH"
else
  echo "getfacl not installed"
fi

echo
echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/permission-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/permission-check.sh 03-linux-bash-networking/labs/permissions/file.txt
```

Run:

```bash
./03-linux-bash-networking/scripts/permission-check.sh 03-linux-bash-networking/labs/permissions/script.sh
```

This script is useful for debugging permission issues.

---

# 24. Safer Permission Fix Script for Scripts

Create:

```bash
nano 03-linux-bash-networking/scripts/make-scripts-executable.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: Not a directory: $TARGET_DIR" >&2
  exit 1
fi

echo "===== Make Scripts Executable ====="
echo "Target directory: $TARGET_DIR"
echo

echo "Scripts found:"
find "$TARGET_DIR" -type f -name "*.sh" -print
echo

echo "Applying chmod u+x to shell scripts..."
find "$TARGET_DIR" -type f -name "*.sh" -exec chmod u+x {} \;

echo
echo "Result:"
find "$TARGET_DIR" -type f -name "*.sh" -exec ls -l {} \;

echo
echo "Done."
```

Run:

```bash
chmod +x 03-linux-bash-networking/scripts/make-scripts-executable.sh

./03-linux-bash-networking/scripts/make-scripts-executable.sh 03-linux-bash-networking/scripts
```

Why `chmod u+x` instead of `chmod 777`?

```text
Only the owner gets execute permission.
We do not open write access to everyone.
```

---

# 25. Create Permissions Notes

Create:

```bash
nano 03-linux-bash-networking/permissions.md
```

Paste:

````markdown
# Linux Permissions Masterclass

## Permission Model

Every file has:

- Owner
- Group
- Permission bits

Permissions:

- `r` = read
- `w` = write
- `x` = execute/traverse

## File Permissions

For files:

- `r` means read contents
- `w` means modify contents
- `x` means execute as program/script

## Directory Permissions

For directories:

- `r` means list names
- `w` means create/delete/rename entries
- `x` means enter/traverse directory

## Common Modes

| Mode | Meaning | Use |
|---|---|---|
| 644 | rw-r--r-- | normal files |
| 755 | rwxr-xr-x | scripts/directories |
| 600 | rw------- | private files/SSH keys |
| 700 | rwx------ | private directories |
| 775 | rwxrwxr-x | shared group dirs |
| 1777 | rwxrwxrwt | /tmp style shared temp dir |

## Commands

```bash
ls -l
chmod u+x script.sh
chmod 644 file.txt
chmod 755 script.sh
chmod 600 ~/.ssh/id_ed25519
chmod 700 ~/.ssh
sudo chown user:group file
sudo chgrp group file
id
groups
whoami
namei -l /path/to/file
getfacl file
setfacl -m u:jenkins:rw file
umask
````

## Special Bits

* Sticky bit: users can only delete their own files in shared directory
* setuid: executable runs as file owner
* setgid: executable runs as group or directory inherits group

## Rules

* Do not use `chmod -R 777`.
* Check process user before fixing permissions.
* Use least privilege.
* Use `namei -l` to debug parent directory permissions.
* SSH private keys should be `600`.
* `.ssh` directory should be `700`.
* Docker group is powerful and should be treated carefully.

````

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/permissions.md \
        03-linux-bash-networking/scripts/permission-check.sh \
        03-linux-bash-networking/scripts/make-scripts-executable.sh \
        03-linux-bash-networking/labs/permissions

git diff --staged

git commit -m "docs: add Linux permissions masterclass"
git push
````

---

# 26. Real Production Scenario — Jenkins Permission Denied

Problem:

```text
Jenkins build fails:
permission denied: ./build.sh
```

Debug:

```bash
ls -l build.sh
```

Output:

```text
-rw-r--r-- build.sh
```

No execute permission.

Fix:

```bash
chmod u+x build.sh
git add build.sh
git commit -m "fix: make build script executable"
```

Do not fix only on server manually.

Why?

```text
The permission should be version-controlled.
```

Git tracks executable bit.

Check:

```bash
git diff --summary
```

You may see:

```text
mode change 100644 => 100755 build.sh
```

This is good.

---

# 27. Real Production Scenario — Nginx Cannot Read Static Files

Problem:

```text
403 Forbidden
```

Nginx logs:

```text
permission denied
```

Check Nginx user:

```bash
ps aux | grep nginx
```

Check path:

```bash
namei -l /var/www/myapp/index.html
```

Check file:

```bash
ls -l /var/www/myapp/index.html
```

Test as Nginx user:

```bash
sudo -u www-data cat /var/www/myapp/index.html
```

Fix may involve:

```bash
sudo chmod o+rx /var/www
sudo chmod -R o+rX /var/www/myapp
```

or better ownership/group model:

```bash
sudo chown -R root:www-data /var/www/myapp
sudo chmod -R 750 /var/www/myapp
```

Exact fix depends on deployment model.

Never blindly:

```bash
sudo chmod -R 777 /var/www/myapp
```

---

# 28. Real Production Scenario — SSH Key Refused

Error:

```text
WARNING: UNPROTECTED PRIVATE KEY FILE!
```

Check:

```bash
ls -la ~/.ssh
```

Fix:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/authorized_keys
```

Then retry:

```bash
ssh -T git@github.com
```

---

# 29. Real Production Scenario — Docker Volume Permission

Problem:

```text
Container cannot write to mounted directory.
```

Example:

```bash
docker run -v "$PWD/data:/app/data" myapp
```

Inside container, app runs as user ID `1000` or `node`.

Host directory may be owned by root.

Debug:

```bash
ls -ld data
```

Check container user:

```bash
docker run --rm myapp id
```

Possible fixes:

```bash
sudo chown -R 1000:1000 data
```

or configure Dockerfile/app user correctly.

In Kubernetes, similar issue may require:

```yaml
securityContext:
  runAsUser: 1000
  fsGroup: 1000
```

We will cover this later.

---

# 30. Interview Answers

Question:

```text
Why is chmod 777 dangerous?
```

Strong answer:

```text
chmod 777 gives read, write, and execute permissions to owner, group, and everyone else. This violates least privilege. Other users or compromised processes may modify files, read secrets, or replace scripts with malicious content. It can also cause services like SSH to reject files because permissions are too open. A better approach is to identify the process user, file owner, group, and exact permission needed.
```

Question:

```text
How do you debug permission denied in Linux?
```

Strong answer:

```text
I first identify which user is running the command or process using whoami, id, ps, or systemd service configuration. Then I inspect the target file with ls -l and stat. I also check parent directory permissions using namei -l because directory traversal requires execute permission. If needed, I test access as the service user using sudo -u. Then I fix ownership or permissions with least privilege instead of using chmod 777.
```

Question:

```text
What permissions should SSH private keys have?
```

Strong answer:

```text
The .ssh directory should usually be 700, private keys like id_ed25519 should be 600, public keys can be 644, and authorized_keys is commonly 600. SSH rejects private keys that are too open because they may be readable by other users.
```

---

# Today’s Core Rules

```text
Permissions connect process user to file access.
Files and directories interpret rwx differently.
Use chmod for permissions.
Use chown for ownership.
Use chgrp for group ownership.
Use id to check user/group membership.
Use namei -l for parent path permission debugging.
Use sudo only when needed.
Never fix blindly with chmod 777.
SSH private keys must be private.
Docker group is powerful.
Use least privilege.
```

Next lesson:

# Lesson 3.6 — Users, Groups, sudo, SSH Access, Service Accounts, and Linux Access Control in Production
