# AWS Masterclass — Lesson 5

## EC2 From Zero to Production — AMI, Instance Type, CPU/RAM Selection, EBS, Key Pair, SSH vs SSM, User Data, Public/Private IP, Security Groups, Server Sizing, and Cost-Safe Hosting

Today we learn **EC2 deeply**.

EC2 is one of the most important AWS services because it teaches you the basics of servers, networking, storage, IAM, monitoring, security, scaling, and troubleshooting.

Your uploaded architect course includes **Amazon EC2** under Compute and Serverless, along with related compute services such as Elastic Beanstalk, Lambda, Fargate, Outposts, Wavelength, and VMware Cloud on AWS . So EC2 is not just one service; it is the foundation for understanding many other compute options.

---

# 1. What is EC2?

EC2 means:

```text id="ec2-full-form"
Elastic Compute Cloud
```

Simple meaning:

```text id="ec2-simple"
EC2 is a virtual server rented from AWS.
```

Think of EC2 like:

```text id="ec2-analogy"
A computer in AWS data center
with CPU
RAM
disk
network
operating system
security settings
```

But instead of physically buying it, you create it from:

```text id="create-methods"
AWS Console
AWS CLI
Terraform
CloudFormation
SDK/API
CI/CD pipeline
```

AWS describes EC2 instance types as different combinations of CPU, memory, storage, and networking capacity, letting you choose the right mix for your workload. ([docs.aws.amazon.com](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html))

---

# 2. What does “Elastic” mean?

Elastic means:

```text id="elastic"
You can increase, decrease, create, replace, or terminate compute capacity based on demand.
```

Old data center style:

```text id="old-style"
Buy server
wait days/weeks
install OS
configure network
use for years
pay even if idle
```

EC2 style:

```text id="ec2-style"
Launch server in minutes
choose CPU/RAM
attach storage
bootstrap with script
stop/start/terminate
scale using Auto Scaling
pay while used
```

---

# 3. EC2 is not one thing

When you launch EC2, many AWS concepts come together:

```text id="ec2-parts"
AMI:
  operating system image

Instance type:
  CPU/RAM/network hardware profile

VPC:
  network where instance lives

Subnet:
  exact subnet/AZ placement

Security group:
  firewall

Key pair or SSM:
  access method

EBS volume:
  disk

IAM role:
  permissions for the instance

User data:
  startup script

Tags:
  ownership and cost tracking

CloudWatch:
  monitoring

Elastic IP/public IP:
  internet address if needed
```

So EC2 is a perfect service to understand AWS architecture.

---

# 4. AMI — Amazon Machine Image

AMI means:

```text id="ami"
Amazon Machine Image
```

Simple meaning:

```text id="ami-simple"
AMI is the template used to create an EC2 instance.
```

Like:

```text id="ami-analogy"
AMI = operating system installer + preconfigured software image
EC2 instance = running server created from that image
```

Examples:

```text id="ami-examples"
Ubuntu 24.04 AMI
Amazon Linux 2023 AMI
Red Hat AMI
Windows Server AMI
custom company AMI
marketplace AMI
```

AWS defines an AMI as an image that provides the software required to set up and boot an EC2 instance. ([docs.aws.amazon.com](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html))

---

## AMI vs snapshot vs instance

Never confuse:

```text id="ami-vs-snapshot"
AMI:
  bootable template for launching instances

Snapshot:
  backup copy of an EBS volume

Instance:
  running virtual server
```

Example:

```text id="ami-flow"
Ubuntu AMI
  ↓ launch
EC2 instance
  ↓ root disk
EBS volume
  ↓ backup
EBS snapshot
```

---

## Public AMI vs private AMI

```text id="ami-types"
Public AMI:
  provided by AWS, Canonical, Red Hat, Microsoft, Marketplace vendors

Private AMI:
  created by your company/account

Shared AMI:
  private AMI shared with selected AWS accounts
```

Production pattern:

```text id="golden-ami"
Create golden AMI:
  hardened OS
  security agents
  monitoring agents
  baseline packages
  approved configuration

Then launch app servers from that AMI.
```

---

# 5. Instance type — how you choose CPU/RAM

Instance type decides the virtual hardware.

Example:

```text id="instance-type-example"
t3.micro
t3.small
t4g.micro
m7i.large
c7i.large
r7i.large
```

Instance type controls:

```text id="instance-type-controls"
vCPU
RAM
network performance
EBS bandwidth
processor architecture
instance storage support
cost
```

AWS says instance types provide different combinations of CPU, memory, storage, and networking capacity. ([docs.aws.amazon.com](https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-types.html))

---

## Instance family naming

Example:

```text id="instance-name"
t3.micro
```

Breakdown:

```text id="instance-breakdown"
t:
  family

3:
  generation

micro:
  size
```

Another example:

```text id="m7i"
m7i.large

m:
  general purpose

7:
  generation

i:
  Intel-based variant

large:
  size
```

---

# 6. Main EC2 instance families

## General purpose

Examples:

```text id="general"
t3
t4g
m7i
m8g
```

Use for:

```text id="general-use"
web servers
small APIs
backend apps
dev/test
balanced workloads
```

Mental model:

```text id="general-model"
balanced CPU + RAM + network
```

---

## Compute optimized

Examples:

```text id="compute"
c7i
c8g
```

Use for:

```text id="compute-use"
CPU-heavy APIs
batch processing
encoding
high-performance web servers
scientific workloads
game servers
```

Mental model:

```text id="compute-model"
more CPU power per memory
```

---

## Memory optimized

Examples:

```text id="memory"
r7i
r8g
x2idn
```

Use for:

```text id="memory-use"
large databases
caches
in-memory analytics
big JVM apps
Redis-like workloads
```

Mental model:

```text id="memory-model"
more RAM per CPU
```

---

## Storage optimized

Examples:

```text id="storage"
i4i
im4gn
d3
```

Use for:

```text id="storage-use"
high IOPS workloads
local NVMe workloads
data processing
search engines
NoSQL systems
```

Mental model:

```text id="storage-model"
fast local disk / high storage throughput
```

---

## Accelerated computing

Examples:

```text id="accelerated"
g5
g6
p5
inf2
trn1
```

Use for:

```text id="accelerated-use"
GPU workloads
machine learning
deep learning
video rendering
inference
training
```

Mental model:

```text id="accelerated-model"
GPU/accelerator attached
```

---

# 7. How to choose the right server size

Use this decision table.

| Workload            | Start with               | Why                    |
| ------------------- | ------------------------ | ---------------------- |
| Beginner Linux lab  | `t3.micro` / `t4g.micro` | Low cost, small        |
| Small web app       | `t3.small` / `t4g.small` | Light CPU/RAM          |
| Node.js API         | `t3.small` → `t3.medium` | Burstable/general      |
| Jenkins             | `t3.medium` / `t3.large` | Needs RAM              |
| Docker host         | `t3.medium`+             | Containers need memory |
| Small database test | `t3.medium`              | Avoid tiny RAM         |
| Production web      | `m` family or ASG        | Balanced               |
| CPU-heavy app       | `c` family               | CPU optimized          |
| Redis/cache         | `r` family               | Memory optimized       |
| ML/GPU              | `g` / `p` family         | GPU                    |

Rule:

```text id="server-rule"
Do not guess forever.
Start small, monitor CPU/RAM/disk/network, then resize.
```

Production selection method:

```text id="selection-method"
1. Estimate CPU requirement.
2. Estimate memory requirement.
3. Estimate disk size and IOPS.
4. Estimate network traffic.
5. Choose architecture: x86 or ARM.
6. Start with right family.
7. Load test.
8. Monitor.
9. Resize or scale horizontally.
```

---

# 8. Vertical scaling vs horizontal scaling

## Vertical scaling

```text id="vertical"
Make one server bigger.
```

Example:

```text id="vertical-example"
t3.micro → t3.medium → m7i.large
```

Pros:

```text id="vertical-pros"
simple
no app architecture change
```

Cons:

```text id="vertical-cons"
single server can fail
upper size limit
downtime may be needed
```

## Horizontal scaling

```text id="horizontal"
Add more servers.
```

Example:

```text id="horizontal-example"
2 EC2 instances behind ALB
4 EC2 instances behind ALB
Auto Scaling Group
```

Pros:

```text id="horizontal-pros"
high availability
better scaling
failure tolerance
```

Cons:

```text id="horizontal-cons"
app must support multiple instances
sessions/files/database must be designed properly
```

Production preference:

```text id="prod-preference"
Use horizontal scaling behind ALB for production web apps.
```

---

# 9. EBS — EC2 disk

EBS means:

```text id="ebs"
Elastic Block Store
```

Simple meaning:

```text id="ebs-simple"
EBS is a virtual disk attached to EC2.
```

Like:

```text id="ebs-analogy"
EC2 = computer
EBS = hard disk / SSD
```

AWS says EBS volumes persist independently from the running life of an EC2 instance and include volume types such as gp2/gp3 SSD, io1/io2 SSD, st1 HDD, and sc1 HDD. ([docs.aws.amazon.com](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volumes.html))

---

## Root volume vs data volume

```text id="root-vs-data"
Root volume:
  OS disk
  created from AMI

Data volume:
  extra disk attached for application/data
```

Example:

```text id="volume-example"
EC2:
  /dev/xvda = root volume, 20 GiB
  /dev/xvdf = data volume, 100 GiB
```

---

## EBS volume types simplified

| Volume type | Meaning             | Use case             |
| ----------- | ------------------- | -------------------- |
| gp3         | General purpose SSD | most workloads       |
| gp2         | older general SSD   | legacy               |
| io2         | high IOPS SSD       | critical databases   |
| st1         | throughput HDD      | big sequential data  |
| sc1         | cold HDD            | rarely accessed data |

Beginner default:

```text id="ebs-default"
Use gp3 unless you have a specific reason not to.
```

---

# 10. Instance store vs EBS

Some EC2 types have local instance store.

Never confuse:

```text id="instance-store-vs-ebs"
EBS:
  network-attached persistent block storage

Instance store:
  local temporary disk physically attached to host
```

Important:

```text id="instance-store-warning"
Instance store data can be lost when the instance stops, terminates, or underlying host fails.
```

Use instance store for:

```text id="instance-store-use"
temporary cache
scratch data
high-speed temporary processing
```

Use EBS for:

```text id="ebs-use"
OS disk
persistent app data
database storage
important files
```

---

# 11. Key pair — SSH access

A key pair is used to prove your identity when connecting to an EC2 instance.

It has:

```text id="key-pair"
public key:
  stored on EC2

private key:
  kept by you
```

For Linux instances, AWS places the public key you specify at launch inside the instance’s `~/.ssh/authorized_keys` during first boot. ([docs.aws.amazon.com](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html))

SSH command:

```bash id="ssh-command"
ssh -i my-key.pem ubuntu@PUBLIC_IP
```

Important permissions:

```bash id="key-permission"
chmod 400 my-key.pem
```

If key is too open, SSH rejects it.

---

# 12. SSH vs SSM

## SSH

SSH needs:

```text id="ssh-needs"
key pair
public IP or reachable private IP
port 22 allowed in security group
network route
Linux user
```

Common users:

```text id="linux-users"
Ubuntu AMI:
  ubuntu

Amazon Linux:
  ec2-user

RHEL:
  ec2-user or cloud-user

Debian:
  admin or debian
```

Problem with SSH:

```text id="ssh-problem"
If you open port 22 to 0.0.0.0/0,
the internet can try to attack your server.
```

---

## SSM Session Manager

SSM Session Manager lets you connect without opening inbound SSH.

AWS Session Manager is a fully managed capability that lets you manage EC2 instances through an interactive browser-based shell or AWS CLI, and AWS notes it can be used without opening inbound ports or managing bastion hosts/SSH keys. ([docs.aws.amazon.com](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html))

SSM needs:

```text id="ssm-needs"
SSM Agent running on instance
IAM role attached to EC2
AmazonSSMManagedInstanceCore permission
outbound HTTPS path to SSM
AWS CLI/session manager plugin if using CLI
```

Start session:

```bash id="ssm-start"
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
```

Production preference:

```text id="ssm-preference"
Prefer SSM over public SSH for administration.
```

---

# 13. Public IP, private IP, Elastic IP

## Private IP

Every EC2 in a VPC gets private IP.

Example:

```text id="private-ip"
10.0.11.25
```

Used for:

```text id="private-ip-use"
internal app communication
ALB to EC2
EC2 to database
private subnet traffic
```

## Public IP

Public IP lets the internet reach the instance if routes and SG allow it.

Example:

```text id="public-ip"
13.x.x.x
```

Beginner labs sometimes use public IP.

Production apps usually avoid public EC2 IP.

## Elastic IP

Elastic IP is a static public IPv4 address.

Use carefully:

```text id="eip-use"
small fixed-IP workloads
NAT Gateway
legacy integrations
```

Cost warning:

```text id="ipv4-cost"
Public IPv4 addresses can generate charges, including addresses attached to resources. AWS public IPv4 usage should be monitored and minimized.
```

AWS’s public IPv4 pricing information states that in-use public IPv4 addresses, including Amazon-provided public IPv4 and Elastic IP addresses assigned to resources in a VPC, are charged. ([aws.amazon.com](https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/))

---

# 14. User data — bootstrapping EC2

User data is a script that runs when the instance launches.

Simple meaning:

```text id="user-data-simple"
User data is first-boot automation.
```

Example:

```bash id="user-data-example"
#!/bin/bash
apt-get update -y
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
echo "hello from EC2" > /var/www/html/index.html
```

AWS EC2 user data lets you run commands when launching an instance, commonly for automated bootstrapping. ([docs.aws.amazon.com](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html))

Important:

```text id="user-data-important"
User data usually runs only on first boot.
Check logs if it fails.
```

Common log:

```bash id="user-data-log"
sudo cat /var/log/cloud-init-output.log
```

---

# 15. IAM role for EC2

Never put AWS access keys inside EC2.

Bad:

```text id="bad-keys"
Store AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY on server.
```

Good:

```text id="good-role"
Attach IAM role to EC2.
App gets temporary credentials automatically.
```

Example:

```text id="role-example"
EC2 role:
  AppServerRole

Policy:
  allow s3:GetObject on app bucket

App:
  reads S3 without hardcoded keys
```

EC2 uses instance profiles as the container for IAM role information attached to EC2 instances. ([docs.aws.amazon.com](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html))

---

# 16. Security group for EC2

For beginner direct web server:

```text id="beginner-sg"
Inbound:
  80 from 0.0.0.0/0
  22 from your IP only, not world

Outbound:
  all traffic
```

For production app server behind ALB:

```text id="prod-sg"
Inbound:
  app port from ALB security group only

Outbound:
  needed destinations only or controlled egress
```

Best production design:

```text id="prod-flow"
Internet
  ↓
CloudFront
  ↓
ALB SG
  ↓
EC2 App SG
  ↓
DB SG
```

Never open:

```text id="never-open"
SSH 22 from 0.0.0.0/0
RDP 3389 from 0.0.0.0/0
Database ports from 0.0.0.0/0
```

---

# 17. EC2 lifecycle

An EC2 instance has states:

```text id="lifecycle"
pending
running
stopping
stopped
shutting-down
terminated
```

## Stop

```text id="stop"
Instance shuts down.
EBS root volume usually remains.
You can start again.
Instance store data may be lost.
Public IP may change unless Elastic IP is used.
```

## Terminate

```text id="terminate"
Instance is deleted.
Root EBS may be deleted depending DeleteOnTermination.
```

Production rule:

```text id="prod-termination"
Do not rely on one EC2 instance as permanent infrastructure.
Use AMI, user data, Terraform, Ansible, Auto Scaling, backups.
```

---

# 18. Monitoring EC2

Minimum things to monitor:

```text id="monitor"
CPUUtilization
StatusCheckFailed
disk usage
memory usage
network in/out
application health
logs
```

Important:

```text id="memory-note"
EC2 basic CloudWatch metrics do not include memory/disk usage by default.
Use CloudWatch Agent for memory and disk metrics.
```

We will configure this later in the monitoring module.

---

# 19. Server sizing method

When someone asks:

```text id="question"
Which EC2 server should I use?
```

Do not answer randomly.

Ask:

```text id="sizing-questions"
1. What application?
2. Expected users?
3. Expected requests per second?
4. CPU-heavy or memory-heavy?
5. Is it stateless?
6. Does it store files locally?
7. Does it need GPU?
8. Does it need high network throughput?
9. Is it production or dev?
10. Budget?
11. HA requirement?
12. Expected growth?
```

Example decision:

```text id="decision-example"
Small Node.js API:
  start with t3.small/t4g.small for dev
  use t3.medium/m family for production baseline
  put behind ALB
  scale horizontally with ASG
  monitor CPU/memory/latency
```

---

# 20. Hands-On Lab 5A — Launch a Cost-Safe EC2 Web Server

This lab creates:

```text id="lab-create"
1 security group
1 EC2 instance
1 small EBS root volume
nginx installed using user data
```

Cost warning:

```text id="lab-cost"
EC2, EBS, and public IPv4 can generate charges.
Terminate the instance after the lab.
```

Region:

```text id="region"
ap-south-1
```

We use the default VPC for this beginner EC2 lab to keep it simple. Later we will place EC2 in our custom private subnet behind ALB.

---

## Step 1 — Set region

```bash id="set-region"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

aws sts get-caller-identity
```

---

## Step 2 — Get default VPC

```bash id="default-vpc"
VPC_ID="$(aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)"

echo "VPC_ID=$VPC_ID"
```

If output is `None`, you do not have default VPC. We will use custom VPC later.

---

## Step 3 — Get a default subnet

```bash id="default-subnet"
SUBNET_ID="$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
  --query 'Subnets[0].SubnetId' \
  --output text)"

echo "SUBNET_ID=$SUBNET_ID"
```

---

## Step 4 — Create security group

```bash id="create-sg"
SG_ID="$(aws ec2 create-security-group \
  --group-name aws-masterclass-ec2-web-sg \
  --description "AWS Masterclass EC2 web SG" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)"

echo "SG_ID=$SG_ID"
```

Tag it:

```bash id="tag-sg"
aws ec2 create-tags \
  --resources "$SG_ID" \
  --tags Key=Name,Value=aws-masterclass-ec2-web-sg Key=Project,Value=aws-masterclass
```

Allow HTTP:

```bash id="allow-http"
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --ip-permissions '[
    {
      "IpProtocol": "tcp",
      "FromPort": 80,
      "ToPort": 80,
      "IpRanges": [
        {
          "CidrIp": "0.0.0.0/0",
          "Description": "HTTP from internet for lab"
        }
      ]
    }
  ]'
```

We are not opening SSH. We will use user data and later SSM.

---

## Step 5 — Find latest Ubuntu AMI

```bash id="find-ubuntu"
AMI_ID="$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters \
    "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
    "Name=architecture,Values=x86_64" \
    "Name=virtualization-type,Values=hvm" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)"

echo "AMI_ID=$AMI_ID"
```

Owner `099720109477` is Canonical’s AWS account for Ubuntu images. In production, always verify AMI owners and avoid random untrusted AMIs.

---

## Step 6 — Create user data file

```bash id="user-data-file"
cat > /tmp/aws-masterclass-user-data.sh <<'EOF'
#!/bin/bash
set -eux

apt-get update -y
apt-get install -y nginx

cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html>
  <head>
    <title>AWS Masterclass EC2</title>
  </head>
  <body>
    <h1>Hello from AWS EC2</h1>
    <p>This server was bootstrapped using EC2 user data.</p>
  </body>
</html>
HTML

cat > /var/www/html/health <<'EOF_HEALTH'
healthy
EOF_HEALTH

systemctl enable nginx
systemctl restart nginx
EOF
```

---

## Step 7 — Launch EC2

```bash id="run-instance"
INSTANCE_ID="$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --associate-public-ip-address \
  --user-data file:///tmp/aws-masterclass-user-data.sh \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
  --block-device-mappings '[
    {
      "DeviceName": "/dev/sda1",
      "Ebs": {
        "VolumeSize": 8,
        "VolumeType": "gp3",
        "DeleteOnTermination": true,
        "Encrypted": true
      }
    }
  ]' \
  --tag-specifications '[
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "aws-masterclass-ec2-web"},
        {"Key": "Project", "Value": "aws-masterclass"},
        {"Key": "Environment", "Value": "dev"}
      ]
    }
  ]' \
  --query 'Instances[0].InstanceId' \
  --output text)"

echo "INSTANCE_ID=$INSTANCE_ID"
```

Wait:

```bash id="wait-instance"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
```

---

## Step 8 — Get public IP

```bash id="get-ip"
PUBLIC_IP="$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)"

echo "PUBLIC_IP=$PUBLIC_IP"
```

---

## Step 9 — Validate

```bash id="curl"
curl -I "http://$PUBLIC_IP"
curl "http://$PUBLIC_IP/health"
```

Expected:

```text id="expected"
HTTP 200
healthy
```

If it fails, wait 1–2 minutes for user data to finish.

---

# 21. Troubleshoot Lab 5A

## Check instance state

```bash id="state"
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,SubnetId:SubnetId,VpcId:VpcId}' \
  --output table
```

## Check status checks

```bash id="status"
aws ec2 describe-instance-status \
  --instance-ids "$INSTANCE_ID" \
  --include-all-instances \
  --output table
```

## Check security group

```bash id="sg-check"
aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].IpPermissions' \
  --output json
```

## Common causes

```text id="common-causes"
Instance still booting.
User data still running.
Security group missing port 80.
No public IP.
Wrong region.
Nginx failed.
AMI package repository slow.
```

---

# 22. Cleanup Lab 5A

Terminate instance:

```bash id="terminate"
aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID"

aws ec2 wait instance-terminated \
  --instance-ids "$INSTANCE_ID"
```

Delete security group:

```bash id="delete-sg"
aws ec2 delete-security-group \
  --group-id "$SG_ID"
```

Verify no lab instances:

```bash id="verify-cleanup"
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=aws-masterclass" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

---

# 23. Production EC2 design pattern

For production, do not expose EC2 directly.

Use:

```text id="prod-ec2"
CloudFront
  ↓
ALB in public subnets
  ↓
EC2 in private app subnets
  ↓
RDS in private DB subnets
```

Access:

```text id="prod-access"
No public SSH
Use SSM
Use IAM role
Use private subnets
Use Auto Scaling Group
Use Launch Template
Use CloudWatch alarms
Use centralized logs
```

---

# 24. EC2 production checklist

Before launching EC2 in production:

```text id="checklist"
1. Correct region?
2. Correct VPC?
3. Correct subnet?
4. Public or private subnet?
5. Public IP needed?
6. Security group least privilege?
7. AMI trusted?
8. Instance type sized?
9. EBS encrypted?
10. Root volume delete behavior understood?
11. IAM role attached?
12. IMDSv2 required?
13. User data tested?
14. Logs/monitoring configured?
15. Backup/snapshot strategy?
16. Patch strategy?
17. Auto Scaling needed?
18. ALB target group health check configured?
19. Cost tags added?
20. Cleanup/termination protection decision?
```

---

# 25. Certification angle

## CLF-C02

Know:

```text id="clf"
EC2 is virtual server compute.
Instance type controls CPU/RAM/network.
AMI is launch image.
EBS is block storage.
Security Group controls traffic.
Pricing depends on usage.
```

## SAA-C03

Know:

```text id="saa"
EC2 placement in public/private subnets.
ALB + Auto Scaling pattern.
Instance family selection.
EBS volume types.
IAM role for EC2.
IMDSv2.
SSM vs SSH.
Multi-AZ design.
AMI and launch template strategy.
```

## DOP-C02

Know:

```text id="dop"
user data bootstrapping.
golden AMI pipelines.
Systems Manager automation.
patch management.
CloudWatch monitoring.
Auto Scaling rolling deployments.
CodeDeploy/blue-green.
IAM instance profiles.
incident troubleshooting.
```

---

# 26. Interview answer

Memorize this:

```text id="interview-answer"
Amazon EC2 provides virtual servers in AWS. When launching an EC2 instance, I choose an AMI for the operating system and baseline software, an instance type for CPU, memory, storage, and network capacity, a subnet for network placement, security groups for firewall rules, EBS volumes for persistent block storage, an IAM role for AWS permissions, and user data for first-boot automation.

For production, I usually avoid exposing EC2 directly to the internet. I place EC2 instances in private app subnets behind an Application Load Balancer, use security groups that allow traffic only from the ALB security group, enforce IMDSv2, attach an IAM role instead of storing access keys, encrypt EBS volumes, and use Systems Manager Session Manager instead of public SSH. I size EC2 by understanding CPU, memory, disk, and network requirements, then monitor and scale horizontally using Auto Scaling when needed.
```

---

# 27. Quick quiz

```text id="quiz"
1. What is EC2?
2. What is an AMI?
3. What is an instance type?
4. What does t3.micro mean?
5. What is EBS?
6. What is root volume?
7. What is a key pair?
8. What is user data?
9. What is IMDSv2?
10. Why attach IAM role to EC2?
11. Why avoid hardcoded AWS keys?
12. Why avoid public SSH?
13. What is SSM Session Manager?
14. What is Elastic IP?
15. What is the production placement for EC2 app servers?
16. What is vertical scaling?
17. What is horizontal scaling?
18. Which family for CPU-heavy workload?
19. Which family for memory-heavy workload?
20. What should you clean up after EC2 lab?
```

Answers:

```text id="answers"
1. Virtual server in AWS.
2. Bootable image/template for EC2.
3. CPU/RAM/network/storage capacity profile.
4. t family, generation 3, micro size.
5. Persistent block storage for EC2.
6. OS disk.
7. SSH credential pair.
8. First-boot script.
9. Secure instance metadata service version requiring token.
10. To give temporary AWS permissions to apps on EC2.
11. They can leak and are long-lived.
12. It exposes admin access to internet attacks.
13. Secure shell access through AWS Systems Manager without inbound SSH.
14. Static public IPv4 address.
15. Private app subnet behind ALB.
16. Making one server bigger.
17. Adding more servers.
18. C family.
19. R family.
20. Terminate instance and delete security group.
```

---

# Next Lesson

```text id="next"
AWS Lesson 6 — Load Balancers and Auto Scaling:
ALB, NLB, target groups, listeners, health checks, Auto Scaling Groups, launch templates, scaling policies, and production high availability
```
