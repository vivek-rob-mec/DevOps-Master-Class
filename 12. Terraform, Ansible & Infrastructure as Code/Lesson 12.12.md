# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.12 — Ansible Inventory and Roles

In Lesson 12.11, you built the IAM troubleshooting toolkit:

```text id="recap-12-11"
caller identity diagnostics
iam:PassRole simulation
EC2 runtime role checks
CloudFront OAC bucket-policy debugging
S3 policy simulation
AccessDenied runbooks
least-privilege policy examples
```

Now we start the **Ansible deep dive**.

Terraform created infrastructure. Ansible will configure and validate servers.

```text id="terraform-ansible-model"
Terraform:
  creates VPC, EC2, ALB, S3, CloudFront, IAM

Ansible:
  configures OS packages, files, services, templates, users, app runtime, validation
```

Ansible inventory defines the managed nodes Ansible can target, including host groups and variables. Ansible also supports `group_vars` and `host_vars`, which are loaded relative to the inventory source or playbook path. ([Ansible Documentation][1])

---

# 1. Goal

You will build a production-style Ansible foundation inside your Module 12 repo.

You will create:

```text id="goal"
ansible.cfg
static localhost inventory
Terraform-output-generated inventory
group_vars
host_vars
roles
common role
nginx_hardening role
app_runtime role
validation playbooks
inventory generator script
Ansible lint-style sanity script
SSH vs SSM notes
troubleshooting runbooks
```

This lesson is designed to be safe:

```text id="safe-design"
Default hands-on target:
  localhost

Optional AWS target:
  EC2 from Terraform outputs

Current EC2 access model:
  SSM preferred
  SSH optional only if you later add key pair + port 22 safely
```

---

# 2. What You Will Learn

```text id="lesson-map"
12.12.1   Ansible mental model
12.12.2   inventory basics
12.12.3   static inventory
12.12.4   generated inventory from Terraform outputs
12.12.5   ansible.cfg
12.12.6   group_vars
12.12.7   host_vars
12.12.8   roles
12.12.9   tasks
12.12.10  handlers
12.12.11  templates
12.12.12  facts
12.12.13  idempotency
12.12.14  check mode
12.12.15  diff mode
12.12.16  tags
12.12.17  SSH connection model
12.12.18  SSM connection model
12.12.19  validation playbooks
12.12.20  troubleshooting runbooks
```

Ansible connection plugins control how Ansible connects to managed nodes; the connection can be set globally, through CLI options, in a play, or via inventory variables. ([Ansible Documentation][2])

---

# 3. Never Confuse These

## Inventory vs Playbook

```text id="inventory-vs-playbook"
Inventory:
  which hosts exist and how to connect to them

Playbook:
  what tasks to run on those hosts
```

Example:

```yaml id="inventory-example"
all:
  children:
    local:
      hosts:
        localhost:
          ansible_connection: local
```

Playbook:

```yaml id="playbook-example"
- name: Configure hosts
  hosts: local
  roles:
    - common
```

---

## Group Vars vs Host Vars

```text id="group-vs-host-vars"
group_vars:
  variables applied to a group

host_vars:
  variables applied to one host
```

Example:

```text id="vars-example"
group_vars/web.yml:
  app_port: 80

host_vars/app-1.yml:
  ansible_host: 10.10.1.25
```

---

## Role vs Playbook

```text id="role-vs-playbook"
Role:
  reusable unit of automation

Playbook:
  orchestration file that calls roles/tasks against hosts
```

Ansible roles use a defined directory structure with standard directories such as `tasks`, `handlers`, `templates`, `files`, `vars`, `defaults`, and `meta`. ([Ansible Documentation][3])

---

## Handler vs Task

```text id="handler-vs-task"
Task:
  runs during normal playbook execution

Handler:
  runs only when notified by a changed task
```

Example:

```yaml id="handler-example"
- name: Deploy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: restart nginx
```

Handler:

```yaml id="handler-task"
- name: restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

---

## SSH vs SSM

```text id="ssh-vs-ssm"
SSH:
  uses network path, key pair, port 22, security group ingress

SSM:
  uses AWS Systems Manager Session Manager path
  does not need inbound SSH from internet
```

The `amazon.aws.aws_ssm` connection plugin connects to EC2 instances through AWS Systems Manager sessions, while the built-in SSH connection plugin uses the normal SSH client. ([Ansible Documentation][4])

Important for your current Terraform EC2:

```text id="current-access"
Your current EC2 module did not create a key pair.
So SSH inventory is optional/future.
SSM is the preferred AWS access model.
Localhost is the safe default for this lesson.
```

---

# 4. Create Ansible Project Structure

From repo root:

```bash id="create-structure"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/ansible/{inventories/{local,dev,staging,prod}/{group_vars,host_vars},playbooks,roles,scripts,runbooks,reports,templates}
mkdir -p 12-terraform-ansible-iac/12.12-ansible-inventory-roles/{notes,scripts,runbooks,reports,examples}
```

Create role directories:

```bash id="create-role-dirs"
cd ~/devops-masterclass/12-terraform-ansible-iac/ansible

for role in common nginx_hardening app_runtime; do
  mkdir -p roles/$role/{defaults,tasks,handlers,templates,files,vars,meta}
  touch roles/$role/{defaults/main.yml,tasks/main.yml,handlers/main.yml,vars/main.yml,meta/main.yml}
done
```

Check:

```bash id="tree-ansible"
cd ~/devops-masterclass

tree -L 5 12-terraform-ansible-iac/ansible
```

Expected:

```text id="tree-expected"
ansible/
├── inventories/
│   ├── local/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── playbooks/
├── roles/
│   ├── common/
│   ├── nginx_hardening/
│   └── app_runtime/
├── scripts/
├── runbooks/
└── reports/
```

---

# 5. Create `ansible.cfg`

```bash id="ansible-cfg"
cd ~/devops-masterclass/12-terraform-ansible-iac/ansible

cat > ansible.cfg <<'EOF'
[defaults]
inventory = inventories/local/hosts.yml
roles_path = roles
host_key_checking = True
retry_files_enabled = False
stdout_callback = yaml
bin_ansible_callbacks = True
interpreter_python = auto_silent
forks = 10
timeout = 30
gathering = smart
fact_caching = jsonfile
fact_caching_connection = .ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = False
become_method = sudo
become_ask_pass = False

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
EOF
```

Ansible configuration can come from `ansible.cfg`, environment variables, command-line options, playbook keywords, and variables; Ansible’s docs also provide `ansible-config` to inspect settings and where values come from. ([Ansible Documentation][5])

Validate config:

```bash id="ansible-config-check"
ansible-config dump --only-changed
```

Expected:

```text id="cfg-expected"
DEFAULT_HOST_LIST
DEFAULT_ROLES_PATH
HOST_KEY_CHECKING
RETRY_FILES_ENABLED
```

---

# 6. Create Local Inventory

This inventory runs safely on your control machine.

```bash id="local-inventory"
cat > inventories/local/hosts.yml <<'EOF'
all:
  children:
    local:
      hosts:
        localhost:
          ansible_connection: local
          ansible_python_interpreter: "{{ ansible_playbook_python }}"
EOF
```

Create local group vars:

```bash id="local-group-vars"
cat > inventories/local/group_vars/all.yml <<'EOF'
---
project_name: devops-masterclass
environment: local
managed_by: ansible
app_name: demo-node-api
app_port: 8080
nginx_listen_port: 8080
nginx_server_name: localhost
enable_nginx: true
enable_app_runtime: true
common_packages:
  - curl
  - jq
  - ca-certificates
  - gnupg
  - lsb-release
EOF
```

Test inventory:

```bash id="test-inventory"
ansible-inventory -i inventories/local/hosts.yml --graph
ansible-inventory -i inventories/local/hosts.yml --list
```

Ping localhost:

```bash id="ping-local"
ansible -i inventories/local/hosts.yml local -m ansible.builtin.ping
```

Expected:

```text id="ping-expected"
localhost | SUCCESS
```

---

# 7. Create Ansible Mental Model Notes

```bash id="mental-note"
cd ~/devops-masterclass

cat > 12-terraform-ansible-iac/12.12-ansible-inventory-roles/notes/ansible-mental-model.md <<'EOF'
# Ansible Mental Model

## Ansible control node

The machine where Ansible runs.

## Managed node

The target machine Ansible configures.

## Inventory

Defines managed nodes and groups.

## Playbook

Defines automation workflow.

## Role

Reusable automation unit with tasks, handlers, templates, defaults, and metadata.

## Module

Reusable Ansible unit that performs an action.

Examples:

- ansible.builtin.apt
- ansible.builtin.template
- ansible.builtin.service
- ansible.builtin.copy
- ansible.builtin.file

## Idempotency

A task is idempotent when repeated runs do not keep changing the system if the desired state is already present.

## Golden rule

Terraform creates infrastructure.
Ansible configures and validates systems.
EOF
```

---

# 8. Create Never-Forget Notes

````bash id="never-note"
cat > 12-terraform-ansible-iac/12.12-ansible-inventory-roles/notes/never-confuse-ansible-points.md <<'EOF'
# Never Forget — Ansible Inventory and Roles

## 1. Inventory is target selection

Inventory answers:
  where should Ansible run?

## 2. Playbook is execution logic

Playbook answers:
  what should Ansible do?

## 3. Role is reusable structure

Roles keep playbooks clean.

## 4. Defaults are easy to override

Role defaults go in:

```text
roles/<role>/defaults/main.yml
````

## 5. Handlers run only when notified

Use handlers for service restarts.

## 6. Templates are dynamic files

Use Jinja2 templates for config files.

## 7. Use modules before shell

Prefer ansible.builtin.apt, service, file, copy, template over raw shell commands.

## 8. SSH needs network path

SSH requires key, port 22, SG ingress, NACL, route, and user.

## 9. SSM needs IAM and agent

SSM needs instance profile, SSM permissions, agent, AWS CLI/session manager plugin, and connection plugin.

## 10. Idempotency is production readiness

A playbook should be safe to run repeatedly.
EOF

````

---

# 9. Build `common` Role

## Defaults

```bash id="common-defaults"
cd ~/devops-masterclass/12-terraform-ansible-iac/ansible

cat > roles/common/defaults/main.yml <<'EOF'
---
common_update_cache: true
common_packages:
  - curl
  - jq
  - ca-certificates
common_create_motd: true
common_motd_path: /etc/motd
EOF
````

## Tasks

```bash id="common-tasks"
cat > roles/common/tasks/main.yml <<'EOF'
---
- name: Show target context
  ansible.builtin.debug:
    msg:
      - "inventory_hostname={{ inventory_hostname }}"
      - "ansible_connection={{ ansible_connection | default('not-set') }}"
      - "environment={{ environment | default('unknown') }}"
      - "ansible_os_family={{ ansible_os_family | default('unknown') }}"

- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600
  become: true
  when:
    - common_update_cache | bool
    - ansible_os_family == "Debian"

- name: Install common packages
  ansible.builtin.apt:
    name: "{{ common_packages }}"
    state: present
  become: true
  when: ansible_os_family == "Debian"

- name: Create managed MOTD
  ansible.builtin.template:
    src: motd.j2
    dest: "{{ common_motd_path }}"
    owner: root
    group: root
    mode: "0644"
  become: true
  when: common_create_motd | bool
EOF
```

## Template

```bash id="common-template"
cat > roles/common/templates/motd.j2 <<'EOF'
Managed by Ansible
Project: {{ project_name | default('unknown') }}
Environment: {{ environment | default('unknown') }}
Host: {{ inventory_hostname }}
Connection: {{ ansible_connection | default('unknown') }}
EOF
```

## Handler

```bash id="common-handlers"
cat > roles/common/handlers/main.yml <<'EOF'
---
# Common role currently has no handlers.
EOF
```

## Metadata

```bash id="common-meta"
cat > roles/common/meta/main.yml <<'EOF'
---
galaxy_info:
  role_name: common
  author: vivek
  description: Common OS baseline role for DevOps Masterclass
  license: MIT
  min_ansible_version: "2.15"
dependencies: []
EOF
```

---

# 10. Build `nginx_hardening` Role

## Defaults

```bash id="nginx-defaults"
cat > roles/nginx_hardening/defaults/main.yml <<'EOF'
---
nginx_package_name: nginx
nginx_service_name: nginx
nginx_listen_port: 8080
nginx_server_name: localhost
nginx_root: /var/www/devops-masterclass
nginx_health_path: /health
nginx_index_message: "DevOps Masterclass managed by Ansible"
EOF
```

## Tasks

```bash id="nginx-tasks"
cat > roles/nginx_hardening/tasks/main.yml <<'EOF'
---
- name: Install nginx
  ansible.builtin.apt:
    name: "{{ nginx_package_name }}"
    state: present
    update_cache: true
    cache_valid_time: 3600
  become: true
  when: ansible_os_family == "Debian"

- name: Ensure nginx root exists
  ansible.builtin.file:
    path: "{{ nginx_root }}"
    state: directory
    owner: www-data
    group: www-data
    mode: "0755"
  become: true

- name: Deploy index page
  ansible.builtin.template:
    src: index.html.j2
    dest: "{{ nginx_root }}/index.html"
    owner: www-data
    group: www-data
    mode: "0644"
  become: true

- name: Deploy nginx site config
  ansible.builtin.template:
    src: devops-masterclass.conf.j2
    dest: /etc/nginx/sites-available/devops-masterclass.conf
    owner: root
    group: root
    mode: "0644"
    validate: "nginx -t -c %s"
  become: true
  notify: restart nginx

- name: Enable nginx site
  ansible.builtin.file:
    src: /etc/nginx/sites-available/devops-masterclass.conf
    dest: /etc/nginx/sites-enabled/devops-masterclass.conf
    state: link
    force: true
  become: true
  notify: restart nginx

- name: Disable default nginx site
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  become: true
  notify: restart nginx

- name: Ensure nginx is enabled and running
  ansible.builtin.service:
    name: "{{ nginx_service_name }}"
    state: started
    enabled: true
  become: true

- name: Validate local nginx health endpoint
  ansible.builtin.uri:
    url: "http://127.0.0.1:{{ nginx_listen_port }}{{ nginx_health_path }}"
    method: GET
    return_content: true
    status_code: 200
  register: nginx_health_result
  changed_when: false
EOF
```

## Handlers

```bash id="nginx-handlers"
cat > roles/nginx_hardening/handlers/main.yml <<'EOF'
---
- name: restart nginx
  ansible.builtin.service:
    name: "{{ nginx_service_name }}"
    state: restarted
  become: true
EOF
```

## Templates

```bash id="nginx-index-template"
cat > roles/nginx_hardening/templates/index.html.j2 <<'EOF'
<!doctype html>
<html>
  <head>
    <title>{{ project_name | default('DevOps Masterclass') }}</title>
  </head>
  <body>
    <h1>{{ nginx_index_message }}</h1>
    <p>Environment: {{ environment | default('unknown') }}</p>
    <p>Host: {{ inventory_hostname }}</p>
    <p>Managed by Ansible role: nginx_hardening</p>
  </body>
</html>
EOF
```

```bash id="nginx-config-template"
cat > roles/nginx_hardening/templates/devops-masterclass.conf.j2 <<'EOF'
server {
    listen {{ nginx_listen_port }} default_server;
    listen [::]:{{ nginx_listen_port }} default_server;

    server_name {{ nginx_server_name }};
    root {{ nginx_root }};
    index index.html;

    add_header X-Managed-By "Ansible" always;
    add_header X-Environment "{{ environment | default('unknown') }}" always;

    location / {
        try_files $uri $uri/ =404;
    }

    location {{ nginx_health_path }} {
        add_header Content-Type text/plain;
        return 200 "healthy\n";
    }
}
EOF
```

## Metadata

```bash id="nginx-meta"
cat > roles/nginx_hardening/meta/main.yml <<'EOF'
---
galaxy_info:
  role_name: nginx_hardening
  author: vivek
  description: Nginx configuration and health endpoint role
  license: MIT
  min_ansible_version: "2.15"
dependencies: []
EOF
```

---

# 11. Build `app_runtime` Role

This role creates a lightweight runtime directory and app metadata. Later, you can expand this role for Node.js, PM2, Docker, or systemd deployment.

## Defaults

```bash id="app-defaults"
cat > roles/app_runtime/defaults/main.yml <<'EOF'
---
app_name: demo-node-api
app_user: devopsapp
app_group: devopsapp
app_base_dir: /opt/devops-masterclass
app_release_dir: "{{ app_base_dir }}/releases"
app_current_dir: "{{ app_base_dir }}/current"
app_port: 3002
app_environment: "{{ environment | default('dev') }}"
app_runtime_packages:
  - curl
  - jq
EOF
```

## Tasks

```bash id="app-tasks"
cat > roles/app_runtime/tasks/main.yml <<'EOF'
---
- name: Ensure app group exists
  ansible.builtin.group:
    name: "{{ app_group }}"
    system: true
    state: present
  become: true

- name: Ensure app user exists
  ansible.builtin.user:
    name: "{{ app_user }}"
    group: "{{ app_group }}"
    system: true
    shell: /usr/sbin/nologin
    create_home: false
    state: present
  become: true

- name: Install app runtime packages
  ansible.builtin.apt:
    name: "{{ app_runtime_packages }}"
    state: present
    update_cache: true
    cache_valid_time: 3600
  become: true
  when: ansible_os_family == "Debian"

- name: Ensure app directories exist
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    mode: "0755"
  become: true
  loop:
    - "{{ app_base_dir }}"
    - "{{ app_release_dir }}"

- name: Create current app directory
  ansible.builtin.file:
    path: "{{ app_current_dir }}"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    mode: "0755"
  become: true

- name: Deploy app runtime metadata
  ansible.builtin.template:
    src: app-metadata.json.j2
    dest: "{{ app_current_dir }}/metadata.json"
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    mode: "0644"
  become: true

- name: Read deployed app metadata
  ansible.builtin.command:
    cmd: "cat {{ app_current_dir }}/metadata.json"
  register: app_metadata_read
  changed_when: false

- name: Show app metadata
  ansible.builtin.debug:
    var: app_metadata_read.stdout
EOF
```

## Template

```bash id="app-template"
cat > roles/app_runtime/templates/app-metadata.json.j2 <<'EOF'
{
  "app_name": "{{ app_name }}",
  "environment": "{{ app_environment }}",
  "app_port": {{ app_port }},
  "managed_by": "ansible",
  "inventory_hostname": "{{ inventory_hostname }}",
  "role": "app_runtime"
}
EOF
```

## Metadata

```bash id="app-meta"
cat > roles/app_runtime/meta/main.yml <<'EOF'
---
galaxy_info:
  role_name: app_runtime
  author: vivek
  description: Application runtime directory and metadata role
  license: MIT
  min_ansible_version: "2.15"
dependencies: []
EOF
```

---

# 12. Create Local Playbook

```bash id="local-playbook"
cat > playbooks/local-site.yml <<'EOF'
---
- name: Configure local Ansible lab host
  hosts: local
  gather_facts: true

  roles:
    - role: common
      tags: ["common"]

    - role: nginx_hardening
      tags: ["nginx"]

    - role: app_runtime
      tags: ["app"]
EOF
```

Syntax check:

```bash id="syntax-check"
ansible-playbook -i inventories/local/hosts.yml playbooks/local-site.yml --syntax-check
```

Dry run:

```bash id="check-mode"
ansible-playbook -i inventories/local/hosts.yml playbooks/local-site.yml --check --diff
```

Run:

```bash id="run-local-playbook"
ansible-playbook -i inventories/local/hosts.yml playbooks/local-site.yml --diff
```

Validate:

```bash id="validate-local-nginx"
curl -I http://127.0.0.1:8080/
curl http://127.0.0.1:8080/health
cat /opt/devops-masterclass/current/metadata.json | jq .
```

Run again to prove idempotency:

```bash id="idempotency-run"
ansible-playbook -i inventories/local/hosts.yml playbooks/local-site.yml
```

Expected second run:

```text id="idempotency-expected"
changed=0 or very low
failed=0
```

Ansible playbooks are designed around desired state and idempotency, so repeated runs should not keep changing systems that already match the declared state. ([Ansible Documentation][6])

---

# 13. Create Validation Playbook

```bash id="validate-playbook"
cat > playbooks/validate-site.yml <<'EOF'
---
- name: Validate configured hosts
  hosts: all
  gather_facts: true

  tasks:
    - name: Show host identity
      ansible.builtin.debug:
        msg:
          - "host={{ inventory_hostname }}"
          - "connection={{ ansible_connection | default('unknown') }}"
          - "os={{ ansible_distribution | default('unknown') }} {{ ansible_distribution_version | default('unknown') }}"

    - name: Validate nginx health endpoint
      ansible.builtin.uri:
        url: "http://127.0.0.1:{{ nginx_listen_port | default(8080) }}/health"
        method: GET
        status_code: 200
        return_content: true
      register: health_result
      changed_when: false
      when: enable_nginx | default(true) | bool

    - name: Validate app metadata file
      ansible.builtin.stat:
        path: "{{ app_current_dir | default('/opt/devops-masterclass/current') }}/metadata.json"
      register: app_metadata_stat
      changed_when: false

    - name: Assert app metadata exists
      ansible.builtin.assert:
        that:
          - app_metadata_stat.stat.exists
        fail_msg: "App metadata file is missing."
        success_msg: "App metadata file exists."
EOF
```

Run:

```bash id="run-validate"
ansible-playbook -i inventories/local/hosts.yml playbooks/validate-site.yml
```

---

# 14. Generate Inventory from Terraform Outputs

This script reads your Terraform `future_ansible_inventory_contract` output and creates a YAML inventory.

Because your current EC2 module does not configure SSH key pairs, the script supports two modes:

```text id="inventory-modes"
CONNECTION_MODE=ssh:
  uses public IP and ubuntu user
  requires key pair + SG port 22

CONNECTION_MODE=ssm:
  uses EC2 instance ID
  requires amazon.aws collection, AWS CLI, SSM plugin, EC2 SSM online
```

Create script:

```bash id="gen-script"
cat > scripts/generate-inventory-from-terraform.py <<'EOF'
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

base = Path(__file__).resolve().parents[1]
tf_dir = base / "environments" / ENVIRONMENT
inventory_dir = base / "ansible" / "inventories" / ENVIRONMENT
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
EOF
```

Make executable:

```bash id="chmod-gen"
chmod +x scripts/generate-inventory-from-terraform.py
```

Install PyYAML if needed:

```bash id="install-pyyaml"
python3 -m pip install --user pyyaml
```

Generate SSM inventory:

```bash id="generate-ssm-inventory"
cd ~/devops-masterclass/12-terraform-ansible-iac

ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./ansible/scripts/generate-inventory-from-terraform.py
```

View:

```bash id="view-generated"
cat ansible/inventories/dev/hosts.yml
cat ansible/inventories/dev/group_vars/all.yml
```

---

# 15. Optional SSM Setup Notes

Create collections requirements:

```bash id="collections"
cd ~/devops-masterclass/12-terraform-ansible-iac/ansible

cat > requirements.yml <<'EOF'
---
collections:
  - name: amazon.aws
  - name: community.aws
EOF
```

Install:

```bash id="install-collections"
ansible-galaxy collection install -r requirements.yml
```

Check connection plugin docs locally:

```bash id="ansible-doc-ssm"
ansible-doc -t connection amazon.aws.aws_ssm
```

The `amazon.aws.aws_ssm` plugin connects via AWS Systems Manager and does not use `remote_user`/`ansible_user` in the same way SSH does. ([Ansible Documentation][4])

Important:

```text id="ssm-warning"
SSM Ansible execution may need:
  AWS CLI
  Session Manager plugin
  amazon.aws collection
  EC2 instance online in SSM
  IAM permissions for SSM session
  optional S3 bucket settings for file transfer depending on plugin behavior
```

For this reason:

```text id="course-approach"
12.12:
  builds inventory and roles

12.13:
  integrates Terraform + Ansible execution safely
  including SSM/SSH decision
```

---

# 16. Create AWS Playbook

```bash id="aws-playbook"
cat > playbooks/aws-site.yml <<'EOF'
---
- name: Configure AWS web hosts from Terraform inventory
  hosts: web
  gather_facts: true

  roles:
    - role: common
      tags: ["common"]

    - role: nginx_hardening
      tags: ["nginx"]

    - role: app_runtime
      tags: ["app"]
EOF
```

Syntax check:

```bash id="aws-syntax"
ansible-playbook -i inventories/dev/hosts.yml playbooks/aws-site.yml --syntax-check
```

SSM dry-run command:

```bash id="aws-check-mode"
ansible-playbook -i inventories/dev/hosts.yml playbooks/aws-site.yml --check --diff
```

Actual run only when SSM connection is confirmed:

```bash id="aws-run"
ansible-playbook -i inventories/dev/hosts.yml playbooks/aws-site.yml --diff
```

Validate:

```bash id="aws-validate"
ansible-playbook -i inventories/dev/hosts.yml playbooks/validate-site.yml
```

---

# 17. Create Inventory Audit Script

```bash id="inventory-audit"
cat > scripts/inventory-audit.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

INVENTORY="${INVENTORY:-inventories/local/hosts.yml}"

echo "===== Ansible Inventory Audit ====="
echo "Inventory: $INVENTORY"

ansible-inventory -i "$INVENTORY" --graph

echo
echo "Inventory list:"
ansible-inventory -i "$INVENTORY" --list

echo
echo "Ping test:"
ansible -i "$INVENTORY" all -m ansible.builtin.ping
EOF
```

Make executable:

```bash id="chmod-audit"
chmod +x scripts/inventory-audit.sh
```

Run local:

```bash id="run-audit-local"
cd ~/devops-masterclass/12-terraform-ansible-iac/ansible

INVENTORY=inventories/local/hosts.yml ./scripts/inventory-audit.sh
```

Run dev inventory if generated and connection ready:

```bash id="run-audit-dev"
INVENTORY=inventories/dev/hosts.yml ./scripts/inventory-audit.sh
```

---

# 18. Create Role Structure Audit Script

```bash id="role-audit"
cat > scripts/role-structure-audit.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Ansible Role Structure Audit ====="

required_dirs=(
  defaults
  tasks
  handlers
  templates
  files
  vars
  meta
)

for role_dir in roles/*; do
  [ -d "$role_dir" ] || continue
  role_name="$(basename "$role_dir")"

  echo
  echo "Checking role: $role_name"

  for dir in "${required_dirs[@]}"; do
    test -d "$role_dir/$dir" || {
      echo "Missing directory: $role_dir/$dir"
      exit 1
    }
  done

  test -f "$role_dir/tasks/main.yml" || {
    echo "Missing tasks/main.yml for $role_name"
    exit 1
  }

  test -f "$role_dir/defaults/main.yml" || {
    echo "Missing defaults/main.yml for $role_name"
    exit 1
  }

  test -f "$role_dir/meta/main.yml" || {
    echo "Missing meta/main.yml for $role_name"
    exit 1
  }
done

echo
echo "Role structure audit passed."
EOF
```

Make executable:

```bash id="chmod-role-audit"
chmod +x scripts/role-structure-audit.sh
```

Run:

```bash id="run-role-audit"
./scripts/role-structure-audit.sh
```

---

# 19. Create Ansible Sanity Script

```bash id="sanity-script"
cat > scripts/ansible-sanity.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Ansible Sanity ====="

ansible --version
ansible-config dump --only-changed

echo
echo "Checking inventory..."
ansible-inventory -i inventories/local/hosts.yml --graph

echo
echo "Syntax checks..."
for playbook in playbooks/*.yml; do
  echo "Checking $playbook"
  ansible-playbook -i inventories/local/hosts.yml "$playbook" --syntax-check
done

echo
echo "Role structure..."
./scripts/role-structure-audit.sh

echo
echo "Local ping..."
ansible -i inventories/local/hosts.yml local -m ansible.builtin.ping

echo
echo "Ansible sanity passed."
EOF
```

Make executable:

```bash id="chmod-sanity"
chmod +x scripts/ansible-sanity.sh
```

Run:

```bash id="run-sanity"
./scripts/ansible-sanity.sh
```

---

# 20. Create Lesson Validation Script

```bash id="lesson-validation"
cd ~/devops-masterclass

cat > 12-terraform-ansible-iac/12.12-ansible-inventory-roles/scripts/validate-lesson-12-12.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.12 ====="

BASE="12-terraform-ansible-iac"
ANSIBLE_DIR="$BASE/ansible"
LESSON="$BASE/12.12-ansible-inventory-roles"

test -d "$ANSIBLE_DIR/inventories/local"
test -d "$ANSIBLE_DIR/playbooks"
test -d "$ANSIBLE_DIR/roles/common"
test -d "$ANSIBLE_DIR/roles/nginx_hardening"
test -d "$ANSIBLE_DIR/roles/app_runtime"
test -d "$ANSIBLE_DIR/scripts"

test -f "$ANSIBLE_DIR/ansible.cfg"
test -f "$ANSIBLE_DIR/inventories/local/hosts.yml"
test -f "$ANSIBLE_DIR/inventories/local/group_vars/all.yml"
test -f "$ANSIBLE_DIR/playbooks/local-site.yml"
test -f "$ANSIBLE_DIR/playbooks/validate-site.yml"
test -f "$ANSIBLE_DIR/playbooks/aws-site.yml"

test -f "$LESSON/notes/ansible-mental-model.md"
test -f "$LESSON/notes/never-confuse-ansible-points.md"

test -x "$ANSIBLE_DIR/scripts/generate-inventory-from-terraform.py"
test -x "$ANSIBLE_DIR/scripts/inventory-audit.sh"
test -x "$ANSIBLE_DIR/scripts/role-structure-audit.sh"
test -x "$ANSIBLE_DIR/scripts/ansible-sanity.sh"

ansible --version >/dev/null
ansible-playbook --version >/dev/null
ansible-inventory --version >/dev/null

cd "$ANSIBLE_DIR"

./scripts/ansible-sanity.sh

echo
echo "Running localhost check mode..."
ansible-playbook -i inventories/local/hosts.yml playbooks/local-site.yml --check >/dev/null

echo
echo "Lesson 12.12 validation passed."
EOF
```

Make executable:

```bash id="chmod-validation"
chmod +x 12-terraform-ansible-iac/12.12-ansible-inventory-roles/scripts/validate-lesson-12-12.sh
```

Run:

```bash id="run-validation"
./12-terraform-ansible-iac/12.12-ansible-inventory-roles/scripts/validate-lesson-12-12.sh
```

---

# 21. Create Cleanup Script

This only cleans local Ansible artifacts. It does not touch AWS.

```bash id="cleanup-script"
cat > 12-terraform-ansible-iac/12.12-ansible-inventory-roles/scripts/cleanup-lesson-12-12-local.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.12 Local Artifacts ====="

BASE="12-terraform-ansible-iac"
ANSIBLE_DIR="$BASE/ansible"

rm -rf "$ANSIBLE_DIR/.ansible_facts"
rm -f "$ANSIBLE_DIR"/*.retry
rm -f "$ANSIBLE_DIR/playbooks"/*.retry
rm -f "$BASE/12.12-ansible-inventory-roles/reports/"*.json
rm -f "$BASE/12.12-ansible-inventory-roles/reports/"*.txt

echo "Local Ansible artifacts cleaned."
echo "No AWS resources were changed."
EOF
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 12-terraform-ansible-iac/12.12-ansible-inventory-roles/scripts/cleanup-lesson-12-12-local.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.12-ansible-inventory-roles/scripts/cleanup-lesson-12-12-local.sh
```

---

# 22. Create Inventory and Roles Runbook

````bash id="runbook"
cat > 12-terraform-ansible-iac/12.12-ansible-inventory-roles/runbooks/ansible-inventory-roles-runbook.md <<'EOF'
# Ansible Inventory and Roles Runbook

## 1. Check Ansible

```bash
ansible --version
ansible-config dump --only-changed
````

## 2. Check inventory

```bash
ansible-inventory -i inventories/local/hosts.yml --graph
ansible-inventory -i inventories/local/hosts.yml --list
```

## 3. Ping hosts

```bash
ansible -i inventories/local/hosts.yml local -m ansible.builtin.ping
```

## 4. Syntax check

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/local-site.yml --syntax-check
```

## 5. Dry run

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/local-site.yml --check --diff
```

## 6. Apply

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/local-site.yml --diff
```

## 7. Validate

```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/validate-site.yml
```

## 8. Generate AWS inventory from Terraform

```bash
ENVIRONMENT=dev CONNECTION_MODE=ssm AWS_REGION=ap-south-1 \
./ansible/scripts/generate-inventory-from-terraform.py
```

## 9. Role structure

Required role structure:

```text
roles/<role>/
  defaults/main.yml
  tasks/main.yml
  handlers/main.yml
  templates/
  files/
  vars/main.yml
  meta/main.yml
```

## Golden rule

Keep playbooks thin and roles reusable.
EOF

````

---

# 23. Create Ansible Troubleshooting Runbook

```bash id="troubleshoot-runbook"
cat > 12-terraform-ansible-iac/12.12-ansible-inventory-roles/runbooks/ansible-troubleshooting-runbook.md <<'EOF'
# Ansible Troubleshooting Runbook

## Error: inventory host not found

Check:

```bash
ansible-inventory -i INVENTORY --graph
````

Fix:

* correct inventory path
* correct group name
* check YAML indentation

## Error: permission denied

For localhost:

```bash
sudo -v
```

For SSH:

* check key path
* check ansible_user
* check security group port 22
* check public IP
* check host key

For SSM:

* check EC2 SSM online
* check AWS identity
* check amazon.aws collection
* check Session Manager plugin
* check instance profile

## Error: sudo password required

Fix:

```bash
ansible-playbook ... --ask-become-pass
```

or configure passwordless sudo only where appropriate.

## Error: nginx config invalid

Check:

```bash
sudo nginx -t
```

Ansible template task uses validate before replacing config.

## Error: task changes every run

Check idempotency:

* avoid raw shell when module exists
* define creates/removes for command tasks
* use changed_when carefully
* use service/file/template modules

## Error: Python missing on target

Set:

```yaml
ansible_python_interpreter: /usr/bin/python3
```

or install Python on target.

## Golden rule

Debug Ansible in this order:

1. inventory
2. connection
3. privilege escalation
4. variables
5. module behavior
6. service/application logs
   EOF

````

---

# 24. Common Mistakes and Fixes

## Mistake 1 — Using shell for everything

Bad:

```yaml id="bad-shell"
- name: Install nginx
  ansible.builtin.shell: apt install nginx -y
````

Good:

```yaml id="good-apt"
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present
```

---

## Mistake 2 — Putting all tasks in one huge playbook

Bad:

```text id="huge-playbook"
site.yml with 500 tasks
```

Good:

```text id="roles-good"
roles/common
roles/nginx_hardening
roles/app_runtime
```

---

## Mistake 3 — Hardcoding environment values in tasks

Bad:

```yaml id="bad-env"
dest: /opt/prod/app
```

Good:

```yaml id="good-env"
dest: "{{ app_base_dir }}"
```

---

## Mistake 4 — Not using handlers

Bad:

```yaml id="bad-restart"
- name: Restart nginx every run
  ansible.builtin.service:
    name: nginx
    state: restarted
```

Good:

```yaml id="good-handler"
notify: restart nginx
```

---

## Mistake 5 — Confusing Terraform outputs with inventory

Terraform output is not automatically Ansible inventory.

Correct flow:

```text id="tf-inventory-flow"
Terraform output -json
  ↓
inventory generator script
  ↓
Ansible inventory YAML
  ↓
ansible-playbook
```

---

# 25. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is Ansible inventory?
What is a playbook?
What is a role?
What is group_vars?
What is host_vars?
What is ansible.cfg?
What is a task?
What is a handler?
What is a template?
What is an Ansible fact?
What is idempotency?
Why prefer modules over shell?
How do you run check mode?
How do you run diff mode?
How do you generate inventory from Terraform outputs?
Why is localhost the safe first target?
Why does your current EC2 prefer SSM over SSH?
What does amazon.aws.aws_ssm do?
What does ansible.builtin.ssh do?
How do you validate role structure?
How do you troubleshoot Ansible connection failures?
```

Strong interview answer:

```text id="interview-answer"
I structure Ansible automation around inventories, playbooks, roles, group variables, and host variables. Inventory defines the managed hosts and connection details, playbooks orchestrate the automation, and roles package reusable configuration logic such as common OS setup, nginx configuration, and application runtime preparation.

I keep roles idempotent by using Ansible modules such as apt, file, template, service, uri, and user instead of raw shell commands. I use handlers for service restarts so services restart only when configuration changes. I use ansible.cfg for project-level defaults, group_vars for environment-wide values, and Terraform outputs to generate inventory for AWS hosts.

For AWS EC2, I understand both SSH and SSM connection models. SSH requires a network path, key pair, port 22, and security group ingress. SSM uses AWS Systems Manager and IAM permissions and avoids exposing SSH to the internet. In production, I prefer thin playbooks, reusable roles, check mode, diff mode, validation playbooks, and repeatable idempotent runs.
```

Resume bullet:

```text id="resume-bullet"
Built a production-style Ansible automation foundation with ansible.cfg, static and Terraform-generated inventories, group_vars and host_vars structure, reusable common/nginx_hardening/app_runtime roles, handlers, Jinja2 templates, localhost validation, optional AWS EC2 inventory generation for SSH or SSM connection models, idempotency checks, check/diff mode workflows, inventory and role audits, validation playbooks, cleanup scripts, and Ansible troubleshooting runbooks.
```

---

# 26. Commit Lesson 12.12

Clean:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.12-ansible-inventory-roles/scripts/cleanup-lesson-12-12-local.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.12-ansible-inventory-roles/scripts/validate-lesson-12-12.sh
```

Review:

```bash id="review"
git status

find 12-terraform-ansible-iac/12.12-ansible-inventory-roles -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/ansible -maxdepth 5 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add Ansible inventory and roles foundation"

git push
```

---

# 27. Next Lesson

```text id="next-lesson"
12.13 — Terraform + Ansible Integration
```

We will connect the full workflow:

```text id="next-topics"
Terraform apply
Terraform output contracts
inventory generation
Ansible execution after infrastructure
SSM connection workflow
SSH connection workflow
Makefile orchestration
CI/CD handoff
post-apply validation
ALB/CloudFront validation with Ansible
rollback thinking
safe integration runbooks
```

[1]: https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html?utm_source=chatgpt.com "How to build your inventory — Ansible Community Documentation"
[2]: https://docs.ansible.com/projects/ansible/latest/plugins/connection.html?utm_source=chatgpt.com "Connection plugins — Ansible Community Documentation"
[3]: https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html?utm_source=chatgpt.com "Roles — Ansible Community Documentation"
[4]: https://docs.ansible.com/ansible/devel/collections/amazon/aws/aws_ssm_connection.html?utm_source=chatgpt.com "amazon.aws.aws_ssm connection – connect to EC2 instances via AWS Systems Manager — Ansible Community Documentation"
[5]: https://docs.ansible.com/projects/ansible/latest/reference_appendices/config.html?utm_source=chatgpt.com "Ansible Configuration Settings — Ansible Community Documentation"
[6]: https://docs.ansible.com/projects/ansible-core/devel/playbook_guide/playbooks_intro.html?utm_source=chatgpt.com "Ansible playbooks — Ansible Core Documentation"
