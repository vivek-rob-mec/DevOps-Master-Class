# Lesson 1.7 — Environment Setup for the Masterclass

Now we prepare your lab.

From this point onward, every concept will become hands-on. Your original curriculum already includes environment setup: Ubuntu/WSL, Docker, VS Code, GitHub, Docker Hub, AWS account, SSH keys, and terminal practice. 

This lesson makes that setup **production-learning ready**.

---

# 1. Why Environment Setup Matters

A weak setup causes problems like:

```text
Command works in tutorial but not on my machine
Docker permission denied
GitHub SSH not working
Wrong Node version
Different Python version
AWS CLI not configured
Jenkins cannot access Docker
Terraform state issue
Kubernetes context confusion
```

A strong setup gives you:

```text
Repeatable practice environment
Clean folder structure
Proper Git workflow
Docker-ready system
SSH access
Cloud CLI access
Safe place to break things
```

For this masterclass, your local machine is your first “data center.”

---

# 2. Recommended Masterclass Lab Architecture

Since you are on Windows + WSL/Ubuntu, use this setup:

```text
Windows
  ↓
WSL2 Ubuntu
  ↓
VS Code Remote WSL
  ↓
Docker
  ↓
Git + GitHub
  ↓
AWS CLI / Terraform / Ansible / kubectl / Helm
```

Main rule:

```text
Do DevOps work inside Linux/WSL path, not Windows path.
```

Good:

```bash
/home/vivek/devops-masterclass
```

Avoid:

```bash
/mnt/c/Users/Vivek/Desktop/project
```

Why?

Because Docker, permissions, symlinks, scripts, and Linux tools behave better inside the Linux filesystem.

---

# 3. Create Masterclass Workspace

Run this in WSL/Ubuntu:

```bash
mkdir -p ~/devops-masterclass
cd ~/devops-masterclass
```

Create folders:

```bash
mkdir -p \
  00-notes \
  01-linux-bash-networking \
  02-git-github \
  03-python-automation \
  04-app-runtime \
  05-docker \
  06-artifacts-registries \
  07-cicd \
  08-devsecops \
  09-kubernetes \
  10-terraform-ansible \
  11-aws \
  12-gitops-argocd \
  13-observability \
  14-sre-incidents \
  15-system-design \
  16-platform-engineering \
  17-finops \
  18-final-capstone
```

Check:

```bash
ls -la ~/devops-masterclass
```

This becomes your master repository of learning.

---

# 4. Create Notes File

```bash
cd ~/devops-masterclass
touch 00-notes/devops-masterclass-notes.md
```

Open in VS Code:

```bash
code .
```

Add this inside `00-notes/devops-masterclass-notes.md`:

```markdown
# DevOps + DevSecOps + SRE Masterclass Notes

## Learning Method

Concept → Real-world example → Diagram → Commands → Lab → Break it → Debug it → Secure it → Interview answer → Mini project

## Final Masterclass Structure

1. Mental Model & Environment Setup
2. Git, GitHub & Engineering Workflow
3. Linux, Bash & Networking
4. Python for DevOps Automation
5. Application Runtime & Production App Basics
6. Docker & Container Fundamentals
7. Artifact Management & Registries
8. CI/CD Pipelines: GitHub Actions, Jenkins, GitLab CI
9. DevSecOps Security Gates
10. Kubernetes Production Operations
11. Advanced Kubernetes Troubleshooting
12. Terraform, Ansible & Infrastructure as Code
13. AWS Production Architecture
14. GitOps with ArgoCD
15. Observability with Prometheus, Grafana, Loki, Tempo, OpenTelemetry
16. SRE, Incident Response & On-call
17. System Design for DevOps/SRE
18. Platform Engineering
19. FinOps & Cost Optimization
20. Final Mega Capstone Project
```

This file becomes your personal DevOps book.

---

# 5. System Update

Run:

```bash
sudo apt update
sudo apt upgrade -y
```

Install base tools:

```bash
sudo apt install -y \
  curl \
  wget \
  git \
  unzip \
  zip \
  jq \
  tree \
  htop \
  net-tools \
  dnsutils \
  traceroute \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  build-essential
```

Verify:

```bash
git --version
curl --version
jq --version
tree --version
dig google.com
```

---

# 6. Terminal Tools You Must Know

These are not optional. You will use them constantly.

```text
pwd       → Where am I?
ls        → What files are here?
cd        → Move directories
mkdir     → Create directory
touch     → Create file
cat       → Print file
less      → Read large file
cp        → Copy
mv        → Move/rename
rm        → Delete
grep      → Search text
find      → Find files
chmod     → Change permission
chown     → Change owner
sudo      → Run as admin
ss        → Check listening ports
curl      → Test HTTP/API
dig       → Test DNS
journalctl → Read service logs
```

Quick practice:

```bash
cd ~/devops-masterclass
pwd
ls -la
tree -L 2
```

---

# 7. Git Setup

Configure Git:

```bash
git config --global user.name "Vivek Saroj"
git config --global user.email "your-email@example.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
```

Check:

```bash
git config --global --list
```

Create `.gitignore`:

```bash
cd ~/devops-masterclass
cat > .gitignore <<'EOF'
.env
.env.*
*.pem
*.key
*.log
node_modules/
dist/
build/
__pycache__/
.terraform/
terraform.tfstate
terraform.tfstate.*
.DS_Store
EOF
```

Initialize Git:

```bash
git init
git add .
git commit -m "chore: initialize devops masterclass workspace"
```

Important rule:

```text
Never commit secrets.
Never commit private keys.
Never commit .env files.
```

---

# 8. SSH Key Setup for GitHub

Check if key exists:

```bash
ls -la ~/.ssh
```

Create SSH key:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Press Enter for default path.

Start SSH agent:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Print public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Add this public key to GitHub:

```text
GitHub → Settings → SSH and GPG keys → New SSH key
```

Test:

```bash
ssh -T git@github.com
```

Expected style of response:

```text
Hi username! You've successfully authenticated...
```

If you see that, GitHub SSH is ready.

---

# 9. Docker Setup

First check if Docker is available:

```bash
docker --version
docker compose version
```

If Docker Desktop is installed on Windows and WSL integration is enabled, this should work inside WSL.

Test Docker:

```bash
docker run hello-world
```

Then test Nginx:

```bash
docker run -d --name test-nginx -p 8080:80 nginx:alpine
```

Check:

```bash
docker ps
curl http://localhost:8080
```

Clean up:

```bash
docker stop test-nginx
docker rm test-nginx
```

Important commands:

```bash
docker ps
docker ps -a
docker images
docker logs <container>
docker exec -it <container> sh
docker stop <container>
docker rm <container>
docker rmi <image>
docker system df
```

---

# 10. Node.js Setup

Since your projects use Node.js, install Node using `nvm`.

Install `nvm`:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

Reload shell:

```bash
source ~/.bashrc
```

Install Node LTS:

```bash
nvm install --lts
nvm use --lts
```

Verify:

```bash
node -v
npm -v
```

Install useful global tools:

```bash
npm install -g pnpm
```

Verify:

```bash
pnpm -v
```

---

# 11. Python Setup

Check Python:

```bash
python3 --version
pip3 --version
```

Install venv support:

```bash
sudo apt install -y python3-venv python3-pip
```

Create Python automation lab:

```bash
cd ~/devops-masterclass/03-python-automation
python3 -m venv .venv
source .venv/bin/activate
python --version
pip install --upgrade pip
```

Deactivate:

```bash
deactivate
```

Rule:

```text
Use virtual environments for Python projects.
Do not install everything globally.
```

---

# 12. AWS CLI Setup

Install AWS CLI later deeply in AWS module, but basic check:

```bash
aws --version
```

If not installed, we will install it properly during AWS phase.

For now, know that AWS CLI will be used for:

```text
EC2
S3
IAM
ECR
EKS
CloudWatch
Route 53
Secrets Manager
```

Do not put AWS keys directly into code.

Bad:

```text
aws_access_key = "AKIA..."
```

Good:

```text
Use aws configure, IAM roles, GitHub OIDC, or Jenkins credentials.
```

---

# 13. Terraform, Ansible, kubectl, Helm

We will install these when their modules start.

But final environment will include:

```text
Terraform → infrastructure provisioning
Ansible → server configuration
kubectl → Kubernetes control
Helm → Kubernetes package manager
ArgoCD CLI → GitOps
Trivy → security scanning
Gitleaks → secret scanning
Semgrep → SAST
Prometheus/Grafana stack → observability
```

Do not install everything randomly today. We install tools when we need them.

That keeps learning clean.

---

# 14. VS Code Extensions

Install these extensions:

```text
Remote - WSL
Docker
Dev Containers
GitLens
YAML
Terraform
Ansible
Kubernetes
Helm Intellisense
ESLint
Prettier
Python
Markdown All in One
GitHub Actions
```

These make your workspace comfortable.

---

# 15. Your Masterclass Repository Structure

Final structure:

```text
devops-masterclass/
├── 00-notes/
│   └── devops-masterclass-notes.md
├── 01-linux-bash-networking/
├── 02-git-github/
├── 03-python-automation/
├── 04-app-runtime/
├── 05-docker/
├── 06-artifacts-registries/
├── 07-cicd/
├── 08-devsecops/
├── 09-kubernetes/
├── 10-terraform-ansible/
├── 11-aws/
├── 12-gitops-argocd/
├── 13-observability/
├── 14-sre-incidents/
├── 15-system-design/
├── 16-platform-engineering/
├── 17-finops/
└── 18-final-capstone/
```

This is clean and resume-friendly.

---

# 16. Lab — Environment Verification Script

Create a script:

```bash
cd ~/devops-masterclass
mkdir -p 01-linux-bash-networking/scripts
nano 01-linux-bash-networking/scripts/check-env.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== DevOps Masterclass Environment Check ====="
echo

check_cmd() {
  local cmd="$1"
  echo -n "Checking $cmd... "
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK: $($cmd --version 2>/dev/null | head -n 1 || echo installed)"
  else
    echo "MISSING"
  fi
}

check_cmd git
check_cmd curl
check_cmd jq
check_cmd docker
check_cmd node
check_cmd npm
check_cmd python3
check_cmd ssh

echo
echo "Checking Docker daemon..."
if docker info >/dev/null 2>&1; then
  echo "Docker daemon: OK"
else
  echo "Docker daemon: NOT RUNNING or permission issue"
fi

echo
echo "Checking internet..."
if curl -Is https://github.com >/dev/null 2>&1; then
  echo "Internet/GitHub: OK"
else
  echo "Internet/GitHub: FAILED"
fi

echo
echo "Checking DNS..."
if dig google.com >/dev/null 2>&1; then
  echo "DNS: OK"
else
  echo "DNS: FAILED"
fi

echo
echo "===== Check Complete ====="
```

Make executable:

```bash
chmod +x 01-linux-bash-networking/scripts/check-env.sh
```

Run:

```bash
./01-linux-bash-networking/scripts/check-env.sh
```

Commit it:

```bash
git add .
git commit -m "feat: add environment verification script"
```

This is your first real masterclass script.

---

# 17. Common Setup Mistakes

## Mistake 1 — Working inside Windows path

Bad:

```bash
cd /mnt/c/Users/Vivek/project
```

Better:

```bash
cd ~/devops-masterclass
```

---

## Mistake 2 — Running everything with sudo

Bad:

```bash
sudo npm install
sudo docker ...
```

Better:

```bash
Use correct user permissions.
Use sudo only when needed.
```

---

## Mistake 3 — Committing secrets

Bad:

```bash
git add .env
git commit -m "add env"
```

Better:

```bash
Add .env to .gitignore.
Use .env.example without real secrets.
```

---

## Mistake 4 — Installing tools randomly

Bad:

```text
Install 50 tools today without knowing why.
```

Better:

```text
Install each tool when its module starts.
Understand what problem it solves.
```

---

# 18. Mini Interview Answer

Question:

```text
How would you set up a DevOps learning lab?
```

Strong answer:

```text
I would use a Linux-based environment, preferably WSL2 Ubuntu or an Ubuntu VM, because most production systems run on Linux. I would create a clean workspace, use Git from the beginning, configure SSH for GitHub, install base tools like curl, jq, dig, htop, and tree, set up Docker, Node.js, and Python virtual environments, and verify everything using a script. I would avoid working directly in Windows paths, avoid committing secrets, and install advanced tools like Terraform, kubectl, Helm, and security scanners only when I start those modules.
```

---

# Today’s Core Rules

```text
Work inside Linux path.
Use Git from day one.
Never commit secrets.
Use SSH keys properly.
Verify tools with a script.
Install tools when needed, not randomly.
Docker must be tested before container lessons.
Your local lab is your first production-style environment.
```

Next lesson:

# Lesson 1.8 — GitHub Repository Setup: README, Branch Protection, Issues, PR Template, Project Structure
