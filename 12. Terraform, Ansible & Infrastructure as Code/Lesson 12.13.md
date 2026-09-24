# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.13 — Terraform + Ansible Integration

In Lesson 12.12, you built:

```text id="recap-12-12"
ansible.cfg
local inventory
Terraform-generated inventory
group_vars
host_vars structure
common role
nginx_hardening role
app_runtime role
validation playbooks
Ansible sanity scripts
```

Now we connect the full workflow:

```text id="workflow"
Terraform:
  provision AWS infrastructure

Terraform outputs:
  expose infrastructure contracts

Inventory generator:
  converts Terraform outputs to Ansible inventory

Ansible:
  configures and validates hosts

Validation:
  checks EC2, ALB, CloudFront, S3, and app health
```

Terraform’s `terraform output -json` command is designed for machine-readable output, which makes it ideal for handoff into scripts such as Ansible inventory generators. Be careful: Terraform notes that `-json` and `-raw` can display sensitive outputs in plain text. ([HashiCorp Developer][1])

---

# 1. Goal

You will build a production-style Terraform → Ansible integration workflow.

You will create:

```text id="goal"
Terraform output export
Terraform-to-Ansible inventory generation
Terraform-to-Ansible variable export
post-apply Ansible workflow
local validation playbook
AWS validation playbook
SSM/SSH execution wrapper
Makefile orchestration
integration runbooks
rollback notes
validation scripts
cleanup scripts
```

Default safe flow:

```text id="safe-flow"
Terraform apply:
  creates AWS resources

Ansible local validation:
  validates ALB, CloudFront, S3 URLs from control node

Optional Ansible AWS host config:
  runs roles on EC2 through SSM or SSH when connection is ready
```

---

# 2. What You Will Learn

```text id="lesson-map"
12.13.1   Terraform-to-Ansible mental model
12.13.2   output contracts
12.13.3   inventory generation
12.13.4   group_vars export from Terraform
12.13.5   post-apply validation
12.13.6   SSM execution path
12.13.7   SSH execution path
12.13.8   Makefile orchestration
12.13.9   CI/CD handoff pattern
12.13.10  rollback thinking
12.13.11  ALB validation with Ansible
12.13.12  CloudFront validation with Ansible
12.13.13  idempotency checks
12.13.14  troubleshooting
12.13.15  cleanup
```

Ansible inventories define hosts and variables, and Ansible loads `group_vars` and `host_vars` relative to inventory or playbook paths. This is why exporting Terraform values into inventory-specific `group_vars` is a clean integration pattern. ([Ansible Documentation][2])

---

# 3. Never Confuse These

## Terraform Apply vs Ansible Run

```text id="tf-vs-ansible"
terraform apply:
  creates or changes infrastructure resources

ansible-playbook:
  configures operating system, app runtime, files, services, and validation
```

Do not use Ansible to create VPCs here.

Do not use Terraform `user_data` as your full configuration-management system.

---

## Terraform Output vs Ansible Inventory

```text id="output-vs-inventory"
Terraform output:
  raw infrastructure contract

Ansible inventory:
  target host and connection definition
```

Correct flow:

```text id="correct-flow"
terraform output -json
  ↓
inventory generator
  ↓
ansible/inventories/dev/hosts.yml
  ↓
ansible-playbook
```

---

## Post-Apply Validation vs Server Configuration

```text id="validation-vs-config"
Server configuration:
  install packages, render templates, restart services

Post-apply validation:
  verify URLs, target health, CloudFront, S3, ALB, EC2 reachability
```

Both can be done with Ansible, but keep the playbooks separate.

---

## SSM vs SSH Integration

```text id="ssm-vs-ssh"
SSM:
  no inbound SSH needed
  uses EC2 IAM role, SSM Agent, Session Manager, AWS APIs

SSH:
  needs key pair, security group port 22, reachable IP, user, host key
```

The `amazon.aws.aws_ssm` Ansible connection plugin runs tasks on EC2 through AWS Systems Manager Session Manager. It does not use `remote_user` / `ansible_user` in the same way the SSH connection does. ([Ansible Documentation][3])

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.13-terraform-ansible-integration/{notes,scripts,runbooks,reports,examples}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.13-terraform-ansible-integration
```

---

# 5. Create Integration Mental Model Notes

````bash id="mental-note"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/notes/terraform-ansible-integration-mental-model.md <<'EOF'
# Terraform + Ansible Integration Mental Model

## Terraform responsibility

Terraform owns infrastructure lifecycle:

- VPC
- subnets
- security groups
- IAM
- EC2
- ALB
- S3
- CloudFront

## Ansible responsibility

Ansible owns configuration and validation:

- packages
- users
- directories
- templates
- service state
- app runtime
- health checks
- post-apply validation

## Handoff contract

Terraform exports:

- instance IDs
- public IPs
- private IPs
- ALB DNS name
- CloudFront domain
- S3 bucket name
- security group IDs

Ansible consumes:

- inventory
- group_vars
- validation vars

## Production flow

```text
terraform plan
terraform apply
terraform output -json
generate inventory
generate group_vars
ansible --check
ansible-playbook
ansible validation
post-deploy report
````

## Golden rule

Terraform creates the machines.
Ansible prepares and verifies the machines.
EOF

````

---

# 6. Create Never-Forget Notes

```bash id="never-note"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/notes/never-confuse-integration-points.md <<'EOF'
# Never Forget — Terraform + Ansible Integration

## 1. Terraform state is not Ansible inventory

Terraform state contains infrastructure data.
Inventory is a controlled Ansible input file.

## 2. Use outputs, not state scraping

Prefer:

```bash
terraform output -json
````

Avoid manually parsing raw terraform.tfstate.

## 3. Keep secrets out of outputs

Terraform output -json can reveal sensitive values.
Do not export secrets into inventory.

## 4. Generate inventory after apply

Inventory should reflect current infrastructure.

## 5. Validate infrastructure before configuring

Check EC2 running, SSM online, ALB healthy, CloudFront deployed.

## 6. SSM and SSH need different inventory variables

SSM uses instance ID and AWS region.
SSH uses public/private IP, user, key, and port.

## 7. Run Ansible check mode before risky changes

Use:

```bash
ansible-playbook --check --diff
```

## 8. Keep validation playbooks separate

Do not mix heavy configuration changes with lightweight URL checks.

## 9. Make orchestration repeatable

Use scripts and Makefile targets.

## 10. Rollback is not one tool

Terraform rollback:
revert infrastructure code and apply

Ansible rollback:
revert config/app state and rerun

Application rollback:
deploy previous release
EOF

````

Ansible supports check mode and diff mode for validating playbooks before applying changes; `--diff` can be used alone or with `--check`. :contentReference[oaicite:3]{index=3}

---

# 7. Fix the Terraform Inventory Generator Path

Small correction before integration: the generator created in Lesson 12.12 should treat `12-terraform-ansible-iac` as the base directory, not `ansible`.

Replace it:

```bash id="fix-generator"
cd ~/devops-masterclass/12-terraform-ansible-iac

cat > ansible/scripts/generate-inventory-from-terraform.py <<'EOF'
#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Missing PyYAML. Install with: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(1)

ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")
CONNECTION_MODE = os.environ.get("CONNECTION_MODE", "ssm")
AWS_REGION = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"))

if ENVIRONMENT not in {"dev", "staging", "prod"}:
    print("ENVIRONMENT must be dev, staging, or prod", file=sys.stderr)
    sys.exit(1)

if CONNECTION_MODE not in {"ssh", "ssm"}:
    print("CONNECTION_MODE must be ssh or ssm", file=sys.stderr)
    sys.exit(1)

# file path:
# 12-terraform-ansible-iac/ansible/scripts/generate-inventory-from-terraform.py
# parents[2] = 12-terraform-ansible-iac
base = Path(__file__).resolve().parents[2]
tf_dir = base / "environments" / ENVIRONMENT
ansible_dir = base / "ansible"
inventory_dir = ansible_dir / "inventories" / ENVIRONMENT
inventory_file = inventory_dir / "hosts.yml"

if not tf_dir.exists():
    print(f"Terraform environment not found: {tf_dir}", file=sys.stderr)
    sys.exit(1)

inventory_dir.mkdir(parents=True, exist_ok=True)
(inventory_dir / "group_vars").mkdir(exist_ok=True)
(inventory_dir / "host_vars").mkdir(exist_ok=True)

def tf_output_json(name: str):
    result = subprocess.run(
        ["terraform", "output", "-json", name],
        cwd=tf_dir,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        raise RuntimeError(f"terraform output failed for {name}")
    return json.loads(result.stdout)

contract = tf_output_json("future_ansible_inventory_contract")

instance_ids = contract.get("instance_ids", {})
public_ips = contract.get("public_ips", {})
private_ips = contract.get("private_ips", {})
instance_names = contract.get("instance_names", {})
app_port = contract.get("app_port", 80)

hosts = {}

for key, instance_id in instance_ids.items():
    host_name = instance_names.get(key, key)
    public_ip = public_ips.get(key)
    private_ip = private_ips.get(key)

    if CONNECTION_MODE == "ssh":
        hosts[host_name] = {
            "ansible_host": public_ip,
            "ansible_user": "ubuntu",
            "ansible_connection": "ansible.builtin.ssh",
            "ansible_python_interpreter": "/usr/bin/python3",
            "ec2_instance_id": instance_id,
            "ec2_private_ip": private_ip,
            "app_port": app_port,
        }
    else:
        hosts[host_name] = {
            "ansible_host": instance_id,
            "ansible_connection": "amazon.aws.aws_ssm",
            "ansible_aws_ssm_region": AWS_REGION,
            "ansible_python_interpreter": "/usr/bin/python3",
            "ec2_instance_id": instance_id,
            "ec2_public_ip": public_ip,
            "ec2_private_ip": private_ip,
            "app_port": app_port,
        }

inventory = {
    "all": {
        "children": {
            ENVIRONMENT: {
                "children": {
                    "web": {
                        "hosts": hosts
                    }
                }
            }
        }
    }
}

with inventory_file.open("w") as f:
    yaml.safe_dump(inventory, f, sort_keys=False)

group_vars = {
    "project_name": "devops-masterclass",
    "environment": ENVIRONMENT,
    "managed_by": "ansible",
    "enable_nginx": True,
    "enable_app_runtime": True,
    "nginx_listen_port": 80,
    "nginx_server_name": "_",
    "app_name": "demo-node-api",
    "app_port": app_port,
    "common_packages": ["curl", "jq", "ca-certificates", "gnupg", "lsb-release"],
}

with (inventory_dir / "group_vars" / "all.yml").open("w") as f:
    yaml.safe_dump(group_vars, f, sort_keys=False)

print(f"Generated inventory: {inventory_file}")
print(f"Connection mode: {CONNECTION_MODE}")
print(f"Hosts generated: {len(hosts)}")
EOF

chmod +x ansible/scripts/generate-inventory-from-terraform.py
````

---

# 8. Create Terraform Output Vars Exporter

This script exports stack-level Terraform outputs into Ansible `group_vars/terraform_outputs.yml`.

```bash id="export-vars-script"
cat > ansible/scripts/export-terraform-outputs-to-vars.py <<'EOF'
#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Missing PyYAML. Install with: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(1)

ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")

if ENVIRONMENT not in {"dev", "staging", "prod"}:
    print("ENVIRONMENT must be dev, staging, or prod", file=sys.stderr)
    sys.exit(1)

base = Path(__file__).resolve().parents[2]
tf_dir = base / "environments" / ENVIRONMENT
inventory_dir = base / "ansible" / "inventories" / ENVIRONMENT
group_vars_dir = inventory_dir / "group_vars"
output_file = group_vars_dir / "terraform_outputs.yml"

group_vars_dir.mkdir(parents=True, exist_ok=True)

result = subprocess.run(
    ["terraform", "output", "-json"],
    cwd=tf_dir,
    text=True,
    capture_output=True,
)

if result.returncode != 0:
    print(result.stderr, file=sys.stderr)
    sys.exit(result.returncode)

outputs = json.loads(result.stdout)

def value(name, default=None):
    obj = outputs.get(name)
    if obj is None:
        return default
    return obj.get("value", default)

vars_out = {
    "terraform_environment": ENVIRONMENT,
    "terraform_name_prefix": value("name_prefix"),
    "alb_dns_name": value("alb_dns_name"),
    "cloudfront_distribution_id": value("cloudfront_distribution_id"),
    "cloudfront_distribution_domain_name": value("cloudfront_distribution_domain_name"),
    "cloudfront_distribution_status": value("cloudfront_distribution_status"),
    "assets_bucket_name": value("assets_bucket_name"),
    "assets_bucket_regional_domain_name": value("assets_bucket_regional_domain_name"),
    "uploaded_asset_keys": value("uploaded_asset_keys", []),
    "first_ec2_instance_id": value("first_ec2_instance_id"),
    "first_ec2_public_ip": value("first_ec2_public_ip"),
    "ec2_instance_ids": value("ec2_instance_ids", {}),
    "ec2_public_ips": value("ec2_public_ips", {}),
    "ec2_private_ips": value("ec2_private_ips", {}),
}

with output_file.open("w") as f:
    yaml.safe_dump(vars_out, f, sort_keys=False)

print(f"Exported Terraform outputs to: {output_file}")
EOF

chmod +x ansible/scripts/export-terraform-outputs-to-vars.py
```

Run after Terraform apply:

```bash id="run-export-vars"
cd ~/devops-masterclass/12-terraform-ansible-iac

ENVIRONMENT=dev \
./ansible/scripts/export-terraform-outputs-to-vars.py

cat ansible/inventories/dev/group_vars/terraform_outputs.yml
```

---

# 9. Create Cloud Stack Validation Playbook

This validates ALB and CloudFront from the control node.

```bash id="cloud-validate-playbook"
cd ~/devops-masterclass/12-terraform-ansible-iac/ansible

cat > playbooks/validate-cloud-stack.yml <<'EOF'
---
- name: Validate Terraform-provisioned cloud stack from control node
  hosts: localhost
  connection: local
  gather_facts: false

  vars_files:
    - "../inventories/{{ target_environment | default('dev') }}/group_vars/terraform_outputs.yml"

  tasks:
    - name: Show stack endpoints
      ansible.builtin.debug:
        msg:
          - "environment={{ target_environment | default('dev') }}"
          - "alb_dns_name={{ alb_dns_name | default('missing') }}"
          - "cloudfront_domain={{ cloudfront_distribution_domain_name | default('missing') }}"
          - "assets_bucket={{ assets_bucket_name | default('missing') }}"

    - name: Assert ALB DNS exists
      ansible.builtin.assert:
        that:
          - alb_dns_name is defined
          - alb_dns_name | length > 0
        fail_msg: "ALB DNS name is missing from Terraform outputs."

    - name: Assert CloudFront domain exists
      ansible.builtin.assert:
        that:
          - cloudfront_distribution_domain_name is defined
          - cloudfront_distribution_domain_name | length > 0
        fail_msg: "CloudFront domain name is missing from Terraform outputs."

    - name: Validate ALB health endpoint
      ansible.builtin.uri:
        url: "http://{{ alb_dns_name }}/health"
        method: GET
        status_code: 200
        return_content: true
      register: alb_health
      retries: 12
      delay: 10
      until: alb_health.status == 200
      changed_when: false

    - name: Validate CloudFront ALB-origin health endpoint
      ansible.builtin.uri:
        url: "https://{{ cloudfront_distribution_domain_name }}/health"
        method: GET
        status_code: 200
        return_content: true
      register: cloudfront_alb_health
      retries: 12
      delay: 10
      until: cloudfront_alb_health.status == 200
      changed_when: false

    - name: Validate CloudFront S3-origin asset health
      ansible.builtin.uri:
        url: "https://{{ cloudfront_distribution_domain_name }}/assets/health.json"
        method: GET
        status_code: 200
        return_content: true
      register: cloudfront_s3_health
      retries: 12
      delay: 10
      until: cloudfront_s3_health.status == 200
      changed_when: false

    - name: Assert S3 asset content contains healthy status
      ansible.builtin.assert:
        that:
          - "'healthy' in cloudfront_s3_health.content"
          - "'s3' in cloudfront_s3_health.content"
        fail_msg: "CloudFront S3-origin health.json did not contain expected content."
        success_msg: "CloudFront S3-origin asset validation passed."

    - name: Show validation summary
      ansible.builtin.debug:
        msg:
          - "ALB health status={{ alb_health.status }}"
          - "CloudFront ALB-origin status={{ cloudfront_alb_health.status }}"
          - "CloudFront S3-origin status={{ cloudfront_s3_health.status }}"
EOF
```

Run after exporting vars:

```bash id="run-cloud-validate"
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/validate-cloud-stack.yml \
  -e target_environment=dev
```

---

# 10. Create SSM Readiness Playbook

This does not configure the host. It checks whether generated AWS inventory can connect.

```bash id="ssm-readiness-playbook"
cat > playbooks/ssm-readiness.yml <<'EOF'
---
- name: Check SSM Ansible connectivity
  hosts: web
  gather_facts: false

  tasks:
    - name: Run lightweight command through selected connection
      ansible.builtin.command:
        cmd: whoami
      register: whoami_result
      changed_when: false

    - name: Show connection result
      ansible.builtin.debug:
        msg:
          - "host={{ inventory_hostname }}"
          - "connection={{ ansible_connection | default('unknown') }}"
          - "whoami={{ whoami_result.stdout }}"
EOF
```

Run only after generating inventory and confirming SSM prerequisites:

```bash id="run-ssm-readiness"
ansible-playbook \
  -i inventories/dev/hosts.yml \
  playbooks/ssm-readiness.yml
```

---

# 11. Create Integrated Post-Apply Script

This script performs the normal handoff after Terraform apply:

```text id="post-apply-flow"
1. read Terraform outputs
2. generate Ansible inventory
3. export Terraform vars
4. validate Ansible inventory
5. validate ALB and CloudFront from control node
```

```bash id="post-apply-script"
cd ~/devops-masterclass/12-terraform-ansible-iac

cat > 12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
CONNECTION_MODE="${CONNECTION_MODE:-ssm}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

if [[ ! "$CONNECTION_MODE" =~ ^(ssm|ssh)$ ]]; then
  echo "Invalid CONNECTION_MODE=$CONNECTION_MODE. Use ssm or ssh."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ANSIBLE_DIR="$BASE/ansible"
TF_DIR="$BASE/environments/$ENVIRONMENT"

echo "===== Post-Apply Ansible Handoff ====="
echo "Environment: $ENVIRONMENT"
echo "Connection mode: $CONNECTION_MODE"
echo "AWS region: $AWS_REGION"

echo
echo "Terraform context:"
cd "$TF_DIR"
terraform workspace show
terraform output name_prefix
terraform output future_ansible_inventory_contract >/dev/null

cd - >/dev/null

echo
echo "Generating Ansible inventory..."
ENVIRONMENT="$ENVIRONMENT" CONNECTION_MODE="$CONNECTION_MODE" AWS_REGION="$AWS_REGION" \
"$ANSIBLE_DIR/scripts/generate-inventory-from-terraform.py"

echo
echo "Exporting Terraform outputs to Ansible group_vars..."
ENVIRONMENT="$ENVIRONMENT" \
"$ANSIBLE_DIR/scripts/export-terraform-outputs-to-vars.py"

echo
echo "Inventory graph:"
cd "$ANSIBLE_DIR"
ansible-inventory -i "inventories/$ENVIRONMENT/hosts.yml" --graph

echo
echo "Running cloud stack validation from control node..."
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/validate-cloud-stack.yml \
  -e "target_environment=$ENVIRONMENT"

echo
echo "Post-apply Ansible handoff completed."
EOF

chmod +x 12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh
```

Run after Terraform apply:

```bash id="run-post-apply"
cd ~/devops-masterclass

ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh
```

---

# 12. Create Full Dev Orchestration Script

This script plans and optionally applies Terraform, then runs the Ansible handoff.

```bash id="orchestrate-script"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/orchestrate-dev-stack.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
CONNECTION_MODE="${CONNECTION_MODE:-ssm}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

if [ "$ENVIRONMENT" != "dev" ]; then
  echo "This orchestration script is intentionally limited to ENVIRONMENT=dev."
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/dev"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl"
PLAN_NAME="tfplan-12-13-dev"

echo "===== Terraform + Ansible Dev Orchestration ====="
echo "Environment: $ENVIRONMENT"
echo "Connection mode: $CONNECTION_MODE"
echo "AWS region: $AWS_REGION"
echo "Auto approve: $AUTO_APPROVE"

aws sts get-caller-identity >/dev/null

cd "$TF_DIR"

echo
echo "Initializing Terraform..."
terraform init -reconfigure -backend-config="$BACKEND_CONFIG"

echo
echo "Formatting and validating Terraform..."
terraform fmt -recursive
terraform validate

echo
echo "Planning Terraform..."
terraform plan -var-file=terraform.tfvars.example -out="$PLAN_NAME"
terraform show "$PLAN_NAME"

if [ "$AUTO_APPROVE" != "true" ]; then
  echo
  echo "Review the plan above."
  echo "Type APPLY_DEV_STACK to apply:"
  read -r CONFIRM

  if [ "$CONFIRM" != "APPLY_DEV_STACK" ]; then
    echo "Apply cancelled."
    rm -f "$PLAN_NAME"
    exit 0
  fi
fi

echo
echo "Applying Terraform..."
terraform apply "$PLAN_NAME"
rm -f "$PLAN_NAME"

cd - >/dev/null

echo
echo "Running Ansible handoff..."
ENVIRONMENT=dev CONNECTION_MODE="$CONNECTION_MODE" AWS_REGION="$AWS_REGION" \
"./$BASE/12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh"

echo
echo "Dev stack orchestration completed."
EOF

chmod +x 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/orchestrate-dev-stack.sh
```

Run:

```bash id="run-orchestrate"
cd ~/devops-masterclass

ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/orchestrate-dev-stack.sh
```

For non-interactive local lab use only:

```bash id="run-auto"
ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 AUTO_APPROVE=true \
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/orchestrate-dev-stack.sh
```

---

# 13. Create Optional AWS Host Configuration Script

This runs Ansible roles on EC2 after inventory generation. Use it only when SSM or SSH is confirmed.

```bash id="configure-aws-script"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/run-aws-ansible-config.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
CONNECTION_MODE="${CONNECTION_MODE:-ssm}"
CHECK_ONLY="${CHECK_ONLY:-true}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ANSIBLE_DIR="$BASE/ansible"

echo "===== AWS Ansible Configuration ====="
echo "Environment: $ENVIRONMENT"
echo "Connection mode: $CONNECTION_MODE"
echo "Check only: $CHECK_ONLY"

ENVIRONMENT="$ENVIRONMENT" CONNECTION_MODE="$CONNECTION_MODE" \
"$ANSIBLE_DIR/scripts/generate-inventory-from-terraform.py"

cd "$ANSIBLE_DIR"

echo
echo "Inventory graph:"
ansible-inventory -i "inventories/$ENVIRONMENT/hosts.yml" --graph

echo
echo "Checking connectivity:"
ansible-playbook \
  -i "inventories/$ENVIRONMENT/hosts.yml" \
  playbooks/ssm-readiness.yml

if [ "$CHECK_ONLY" = "true" ]; then
  echo
  echo "Running check mode only..."
  ansible-playbook \
    -i "inventories/$ENVIRONMENT/hosts.yml" \
    playbooks/aws-site.yml \
    --check --diff
else
  echo
  echo "Running actual AWS host configuration..."
  ansible-playbook \
    -i "inventories/$ENVIRONMENT/hosts.yml" \
    playbooks/aws-site.yml \
    --diff

  echo
  echo "Validating configured AWS hosts..."
  ansible-playbook \
    -i "inventories/$ENVIRONMENT/hosts.yml" \
    playbooks/validate-site.yml
fi
EOF

chmod +x 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/run-aws-ansible-config.sh
```

Run check mode:

```bash id="run-aws-check"
cd ~/devops-masterclass

ENVIRONMENT=dev CONNECTION_MODE=ssm CHECK_ONLY=true \
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/run-aws-ansible-config.sh
```

Run actual configuration:

```bash id="run-aws-actual"
ENVIRONMENT=dev CONNECTION_MODE=ssm CHECK_ONLY=false \
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/run-aws-ansible-config.sh
```

---

# 14. Update Root Makefile for Integration

Replace Module 12 `Makefile` with integrated targets:

```bash id="makefile"
cd ~/devops-masterclass/12-terraform-ansible-iac

cat > Makefile <<'EOF'
ENV ?= dev
CONNECTION_MODE ?= ssm
AWS_REGION ?= ap-south-1

TF_DIR := environments/$(ENV)
ANSIBLE_DIR := ansible
BACKEND_CONFIG := ../../12.3-terraform-state-backend/backend-configs/$(ENV).s3.hcl
PLAN := tfplan

.PHONY: check-env context tf-init tf-fmt tf-validate tf-plan tf-apply tf-output \
        ansible-sanity ansible-inventory ansible-export-vars ansible-cloud-validate \
        ansible-host-check ansible-host-config-check ansible-host-config \
        post-apply dev-orchestrate clean

check-env:
	@test -d "$(TF_DIR)" || (echo "Invalid ENV=$(ENV). Use dev, staging, or prod."; exit 1)

context: check-env
	@echo "ENV=$(ENV)"
	@echo "TF_DIR=$(TF_DIR)"
	@echo "CONNECTION_MODE=$(CONNECTION_MODE)"
	@echo "AWS_REGION=$(AWS_REGION)"
	@cd $(TF_DIR) && echo "Workspace=$$(terraform workspace show 2>/dev/null || echo not-initialized)"
	@aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table

tf-init: check-env
	cd $(TF_DIR) && terraform init -reconfigure -backend-config="$(BACKEND_CONFIG)"

tf-fmt:
	terraform fmt -recursive

tf-validate: check-env
	cd $(TF_DIR) && terraform validate

tf-plan: check-env context tf-init tf-fmt tf-validate
	cd $(TF_DIR) && terraform plan -var-file=terraform.tfvars.example -out=$(PLAN)

tf-apply: check-env context
	cd $(TF_DIR) && terraform apply $(PLAN)

tf-output: check-env
	cd $(TF_DIR) && terraform output

ansible-sanity:
	cd $(ANSIBLE_DIR) && ./scripts/ansible-sanity.sh

ansible-inventory: check-env
	ENVIRONMENT=$(ENV) CONNECTION_MODE=$(CONNECTION_MODE) AWS_REGION=$(AWS_REGION) \
	./$(ANSIBLE_DIR)/scripts/generate-inventory-from-terraform.py
	cd $(ANSIBLE_DIR) && ansible-inventory -i inventories/$(ENV)/hosts.yml --graph

ansible-export-vars: check-env
	ENVIRONMENT=$(ENV) ./$(ANSIBLE_DIR)/scripts/export-terraform-outputs-to-vars.py

ansible-cloud-validate: ansible-export-vars
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/local/hosts.yml playbooks/validate-cloud-stack.yml -e target_environment=$(ENV)

ansible-host-check: ansible-inventory
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.yml playbooks/ssm-readiness.yml

ansible-host-config-check: ansible-inventory
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.yml playbooks/aws-site.yml --check --diff

ansible-host-config: ansible-inventory
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.yml playbooks/aws-site.yml --diff
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.yml playbooks/validate-site.yml

post-apply:
	ENVIRONMENT=$(ENV) CONNECTION_MODE=$(CONNECTION_MODE) AWS_REGION=$(AWS_REGION) \
	./12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh

dev-orchestrate:
	ENVIRONMENT=dev CONNECTION_MODE=$(CONNECTION_MODE) AWS_REGION=$(AWS_REGION) \
	./12.13-terraform-ansible-integration/scripts/orchestrate-dev-stack.sh

clean:
	find . -name "tfplan" -delete
	find . -name "tfplan-*" -delete
	find . -name "*.tfplan" -delete
	rm -rf ansible/.ansible_facts
	find ansible -name "*.retry" -delete
EOF
```

Use:

```bash id="make-use"
cd ~/devops-masterclass/12-terraform-ansible-iac

make context ENV=dev
make tf-plan ENV=dev
make tf-apply ENV=dev
make post-apply ENV=dev CONNECTION_MODE=ssm
```

---

# 15. Create Integration Context Script

```bash id="context-script"
cd ~/devops-masterclass

cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/integration-context.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
ANSIBLE_DIR="$BASE/ansible"

echo "===== Terraform + Ansible Integration Context ====="

echo
echo "AWS caller:"
aws sts get-caller-identity

echo
echo "AWS region:"
echo "AWS_REGION=${AWS_REGION:-unset}"
echo "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-unset}"

echo
echo "Terraform:"
cd "$TF_DIR"
terraform version
echo "workspace=$(terraform workspace show 2>/dev/null || echo not-initialized)"
terraform output name_prefix 2>/dev/null || true
terraform output alb_dns_name 2>/dev/null || true
terraform output cloudfront_distribution_domain_name 2>/dev/null || true
cd - >/dev/null

echo
echo "Ansible:"
cd "$ANSIBLE_DIR"
ansible --version | head -n 1
ansible-config dump --only-changed || true

echo
echo "Inventories:"
find inventories -maxdepth 3 -type f | sort

if [ -f "inventories/$ENVIRONMENT/hosts.yml" ]; then
  echo
  echo "Inventory graph for $ENVIRONMENT:"
  ansible-inventory -i "inventories/$ENVIRONMENT/hosts.yml" --graph || true
fi
EOF

chmod +x 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/integration-context.sh
```

Run:

```bash id="run-context"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/integration-context.sh
```

---

# 16. Create Integration Validation Script

```bash id="validation-script"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/validate-lesson-12-13.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.13 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.13-terraform-ansible-integration"
ANSIBLE_DIR="$BASE/ansible"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/examples"

test -f "$LESSON/notes/terraform-ansible-integration-mental-model.md"
test -f "$LESSON/notes/never-confuse-integration-points.md"

test -x "$LESSON/scripts/post-apply-ansible-handoff.sh"
test -x "$LESSON/scripts/orchestrate-dev-stack.sh"
test -x "$LESSON/scripts/run-aws-ansible-config.sh"
test -x "$LESSON/scripts/integration-context.sh"

test -x "$ANSIBLE_DIR/scripts/generate-inventory-from-terraform.py"
test -x "$ANSIBLE_DIR/scripts/export-terraform-outputs-to-vars.py"

test -f "$ANSIBLE_DIR/playbooks/validate-cloud-stack.yml"
test -f "$ANSIBLE_DIR/playbooks/ssm-readiness.yml"

test -f "$BASE/Makefile"

terraform version >/dev/null
aws sts get-caller-identity >/dev/null
ansible --version >/dev/null
ansible-playbook --version >/dev/null
python3 --version >/dev/null

cd "$ANSIBLE_DIR"

ansible-playbook -i inventories/local/hosts.yml playbooks/validate-cloud-stack.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml playbooks/ssm-readiness.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml playbooks/aws-site.yml --syntax-check
ansible-playbook -i inventories/local/hosts.yml playbooks/validate-site.yml --syntax-check

./scripts/ansible-sanity.sh

echo
echo "Lesson 12.13 validation passed."
echo
echo "Optional live integration after dev Terraform stack exists:"
echo "ENVIRONMENT=dev CONNECTION_MODE=ssm ./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh"
EOF

chmod +x 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/validate-lesson-12-13.sh
```

Run:

```bash id="run-validation"
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/validate-lesson-12-13.sh
```

---

# 17. Create Local Cleanup Script

```bash id="cleanup-script"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/cleanup-lesson-12-13-local.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.13 Local Artifacts ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete
rm -rf "$BASE/ansible/.ansible_facts"
find "$BASE/ansible" -name "*.retry" -delete

echo "Local Terraform and Ansible artifacts cleaned."
echo "AWS resources were not destroyed."
EOF

chmod +x 12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/cleanup-lesson-12-13-local.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/cleanup-lesson-12-13-local.sh
```

---

# 18. Create Integration Runbook

````bash id="integration-runbook"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/runbooks/terraform-ansible-integration-runbook.md <<'EOF'
# Terraform + Ansible Integration Runbook

## 1. Check context

```bash
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/integration-context.sh
````

## 2. Plan Terraform

```bash
cd 12-terraform-ansible-iac
make tf-plan ENV=dev
```

## 3. Apply Terraform

```bash
make tf-apply ENV=dev
```

## 4. Generate inventory

```bash
make ansible-inventory ENV=dev CONNECTION_MODE=ssm
```

## 5. Export Terraform outputs to Ansible vars

```bash
make ansible-export-vars ENV=dev
```

## 6. Validate cloud endpoints

```bash
make ansible-cloud-validate ENV=dev
```

## 7. Optional host connectivity check

```bash
make ansible-host-check ENV=dev CONNECTION_MODE=ssm
```

## 8. Optional host configuration check mode

```bash
make ansible-host-config-check ENV=dev CONNECTION_MODE=ssm
```

## 9. Optional host configuration apply

```bash
make ansible-host-config ENV=dev CONNECTION_MODE=ssm
```

## Golden rule

Do not run Ansible against generated AWS inventory until Terraform outputs are fresh.
EOF

````

---

# 19. Create SSM Integration Runbook

```bash id="ssm-runbook"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/runbooks/ansible-ssm-integration-runbook.md <<'EOF'
# Ansible SSM Integration Runbook

## Purpose

Use Ansible to run tasks on EC2 through AWS Systems Manager instead of SSH.

## Required

- EC2 instance profile attached
- AmazonSSMManagedInstanceCore or equivalent policy
- SSM Agent running
- outbound path to SSM endpoints
- AWS CLI credentials on control node
- amazon.aws Ansible collection
- Session Manager plugin where required
- Ansible inventory using amazon.aws.aws_ssm connection

## Generate inventory

```bash
ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/ansible/scripts/generate-inventory-from-terraform.py
````

## Check inventory

```bash
cd 12-terraform-ansible-iac/ansible
ansible-inventory -i inventories/dev/hosts.yml --graph
```

## Check SSM status

```bash
INSTANCE_ID="$(cd ../environments/dev && terraform output -raw first_ec2_instance_id)"

aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID"
```

## Check Ansible connection

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/ssm-readiness.yml
```

## Common failures

### TargetNotConnected

Causes:

* EC2 not online in SSM
* SSM agent not running
* IAM role missing SSM permissions
* no outbound path to SSM endpoints

### AccessDenied

Causes:

* control-node AWS identity lacks SSM session permissions
* SCP or permission boundary blocks SSM
* wrong AWS profile/account

### Python interpreter issue

Set:

```yaml
ansible_python_interpreter: /usr/bin/python3
```

## Golden rule

SSM avoids inbound SSH, but it still requires IAM, agent, network egress, and correct Ansible connection plugin configuration.
EOF

````

---

# 20. Create CI/CD Handoff Notes

```bash id="cicd-note"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/notes/cicd-handoff-pattern.md <<'EOF'
# CI/CD Handoff Pattern

## Pipeline stages

```text
1. terraform fmt
2. terraform validate
3. terraform plan
4. manual approval
5. terraform apply
6. terraform output -json
7. generate Ansible inventory
8. ansible syntax check
9. ansible check mode
10. ansible apply
11. post-apply validation
12. publish report
````

## Important artifacts

* Terraform plan file
* Terraform outputs JSON
* generated Ansible inventory
* Ansible run logs
* validation report

## Safety gates

* manual approval before apply
* current AWS account check
* current region check
* Terraform workspace check
* no unexpected destroy
* Ansible check mode before apply
* post-deploy endpoint validation

## Production rule

Infrastructure and configuration pipelines can be separate, but they must share a clear contract.
EOF

````

---

# 21. Create Rollback Notes

```bash id="rollback-note"
cat > 12-terraform-ansible-iac/12.13-terraform-ansible-integration/notes/rollback-thinking.md <<'EOF'
# Rollback Thinking

## Terraform rollback

Terraform rollback is usually:

```text
revert code
terraform plan
terraform apply
````

But some infrastructure changes are destructive or non-reversible.

Examples:

* deleted data
* replaced EC2 instance
* changed subnet CIDR
* destroyed ALB
* deleted CloudFront distribution

## Ansible rollback

Ansible rollback is usually:

```text
restore previous config variables/templates
rerun playbook
restart service through handlers
validate
```

## Application rollback

Application rollback should use release/version strategy.

Examples:

* previous artifact
* previous container image
* previous symlink release
* previous AMI or Launch Template version

## Integrated rollback checklist

1. Identify failure layer.
2. Stop further automation.
3. Preserve logs and state.
4. Check Terraform plan history.
5. Check Ansible diff/output.
6. Decide infra rollback vs config rollback vs app rollback.
7. Validate after rollback.

## Golden rule

Rollback starts by identifying which layer failed:
infrastructure, configuration, or application.
EOF

````

---

# 22. Optional Live End-to-End Test

Use this after your dev stack exists:

```bash id="e2e-live"
cd ~/devops-masterclass/12-terraform-ansible-iac

make context ENV=dev

make ansible-inventory ENV=dev CONNECTION_MODE=ssm

make ansible-export-vars ENV=dev

make ansible-cloud-validate ENV=dev
````

Optional SSM host check:

```bash id="ssm-host-check"
make ansible-host-check ENV=dev CONNECTION_MODE=ssm
```

Optional Ansible check mode on EC2:

```bash id="host-check-mode"
make ansible-host-config-check ENV=dev CONNECTION_MODE=ssm
```

Optional actual EC2 configuration:

```bash id="host-config"
make ansible-host-config ENV=dev CONNECTION_MODE=ssm
```

---

# 23. Common Errors and Fixes

## Error 1 — Terraform output missing

Example:

```text id="missing-output"
terraform output failed for future_ansible_inventory_contract
```

Cause:

```text id="missing-output-cause"
Terraform apply has not been run, or output name changed.
```

Fix:

```bash id="missing-output-fix"
cd 12-terraform-ansible-iac/environments/dev
terraform output
```

---

## Error 2 — Generated inventory has zero hosts

Cause:

```text id="zero-hosts"
EC2 outputs are empty or compute module not applied.
```

Fix:

```bash id="zero-hosts-fix"
terraform output future_ansible_inventory_contract
terraform output ec2_instance_ids
```

---

## Error 3 — SSM Ansible connection fails

Check:

```bash id="ssm-debug"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$(cd 12-terraform-ansible-iac/environments/dev && terraform output -raw first_ec2_instance_id)"
```

Common causes:

```text id="ssm-causes"
SSM agent not online
EC2 role missing SSM policy
control identity lacks SSM permissions
wrong AWS profile
wrong region
amazon.aws collection missing
```

Fix:

```bash id="ssm-fix"
cd 12-terraform-ansible-iac/ansible
ansible-galaxy collection install -r requirements.yml
ansible-doc -t connection amazon.aws.aws_ssm
```

---

## Error 4 — Cloud validation fails but infrastructure exists

Separate the origin:

```bash id="origin-separate"
curl -I "http://$ALB_DNS/health"
curl -I "https://$CF_DOMAIN/assets/index.html"
curl -I "https://$CF_DOMAIN/health"
```

Interpretation:

```text id="origin-interpret"
ALB direct fails:
  fix ALB/target group/EC2 first

CloudFront /assets fails:
  fix S3/OAC/bucket policy/behavior

CloudFront /health fails but ALB works:
  fix CloudFront ALB origin settings/cache/headers/protocol
```

---

## Error 5 — Ansible keeps changing every run

Run:

```bash id="idempotency-debug"
ansible-playbook -i inventories/dev/hosts.yml playbooks/aws-site.yml --diff
ansible-playbook -i inventories/dev/hosts.yml playbooks/aws-site.yml --diff
```

Fix:

```text id="idempotency-fix"
Use modules instead of shell.
Use handlers instead of unconditional restarts.
Use changed_when only when necessary.
Avoid commands that rewrite files every run.
```

---

# 24. Cost Safety

This lesson itself mostly creates local scripts and Ansible files.

But the live integration may require the previous AWS stack:

```text id="billable"
EC2
public IPv4
ALB
CloudFront
S3 objects
EBS root volume
```

Check live resources:

```bash id="cost-check"
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=devops-masterclass" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table

aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code}' \
  --output table

aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,DomainName:DomainName,Status:Status,Enabled:Enabled}' \
  --output table
```

Destroy full dev stack when stopping:

```bash id="destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh
```

---

# 25. Revision Checkpoint

You should now be able to answer:

```text id="revision"
Why integrate Terraform with Ansible?
What should Terraform own?
What should Ansible own?
Why should Ansible consume Terraform outputs instead of raw state?
What does terraform output -json do?
Why can terraform output -json be dangerous with sensitive values?
How do you generate inventory from Terraform outputs?
How do you export Terraform outputs to group_vars?
What is post-apply validation?
How do you validate ALB with Ansible?
How do you validate CloudFront with Ansible?
What is the difference between local validation and remote host configuration?
When should you use SSM connection?
When should you use SSH connection?
What does check mode do?
What does diff mode do?
How would this fit into CI/CD?
How do you decide whether rollback is Terraform, Ansible, or application-level?
```

Strong interview answer:

```text id="interview-answer"
I integrate Terraform and Ansible by treating Terraform outputs as the contract between infrastructure provisioning and configuration management. Terraform creates the infrastructure, including EC2, ALB, S3, CloudFront, IAM, security groups, and networking. After apply, I export `terraform output -json`, generate Ansible inventory and group variables, then run Ansible for configuration and validation.

I keep the workflow safe by checking AWS identity, region, Terraform workspace, backend, and plan before apply. After apply, I generate inventory from current outputs, validate ALB and CloudFront endpoints from the control node, and optionally configure EC2 hosts through SSM or SSH. I prefer SSM where possible because it avoids exposing inbound SSH, but I still validate IAM permissions, SSM agent status, and region settings.

In CI/CD, I would split this into clear stages: Terraform fmt/validate/plan, approval, apply, output export, inventory generation, Ansible syntax check, Ansible check mode, Ansible apply, and post-deploy validation. For rollback, I first identify whether the failure is infrastructure, configuration, or application-layer, then use the right rollback mechanism instead of blindly reapplying everything.
```

Resume bullet:

```text id="resume-bullet"
Built an end-to-end Terraform and Ansible integration workflow that provisions AWS infrastructure, exports Terraform output contracts, generates Ansible inventories and group_vars, validates ALB and CloudFront endpoints with Ansible, supports SSM or SSH execution modes for EC2 configuration, adds Makefile orchestration, post-apply handoff scripts, check/diff workflows, integration context reporting, CI/CD handoff notes, rollback runbooks, troubleshooting automation, and cost-safe cleanup processes.
```

---

# 26. Commit Lesson 12.13

Clean:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/cleanup-lesson-12-13-local.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/validate-lesson-12-13.sh
```

Optional live handoff after dev stack exists:

```bash id="live-handoff"
ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.13-terraform-ansible-integration/scripts/post-apply-ansible-handoff.sh
```

Review:

```bash id="review"
git status

find 12-terraform-ansible-iac/12.13-terraform-ansible-integration -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/ansible -maxdepth 5 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: integrate Terraform outputs with Ansible workflows"

git push
```

---

# 27. Next Lesson

```text id="next-lesson"
12.14 — CI/CD for IaC
```

We will build:

```text id="next-topics"
GitHub Actions or Jenkins IaC pipeline
Terraform fmt/validate/plan
plan artifact handling
manual approval before apply
AWS credentials strategy
environment protection
Ansible syntax check
Ansible check mode
post-apply Ansible validation
drift detection pipeline
safe destroy workflow
pipeline runbooks
production CI/CD guardrails
```

[1]: https://developer.hashicorp.com/terraform/cli/commands/output?utm_source=chatgpt.com "terraform output command reference | Terraform | HashiCorp Developer"
[2]: https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html?utm_source=chatgpt.com "How to build your inventory — Ansible Community Documentation"
[3]: https://docs.ansible.com/ansible/devel/collections/amazon/aws/aws_ssm_connection.html?utm_source=chatgpt.com "amazon.aws.aws_ssm connection – connect to EC2 instances via AWS Systems Manager — Ansible Community Documentation"
