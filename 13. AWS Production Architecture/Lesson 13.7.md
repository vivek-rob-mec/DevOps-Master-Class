# AWS Masterclass — Lesson 6

## Load Balancers and Auto Scaling In Depth — ALB, NLB, GWLB, Target Groups, Listeners, Health Checks, ASG, Launch Templates, Scaling Policies, and Production High Availability

Today we move from:

```text id="from"
One EC2 server
```

to:

```text id="to"
Highly available web application
with multiple EC2 instances
behind a load balancer
with automatic scaling and replacement
```

This topic is directly part of the AWS learning path you uploaded: the AWS Academy outline includes “Introduction to Amazon EC2, Elastic Load Balancing, and Amazon EC2 Auto Scaling” in its AWS review section, and your architect brochure includes AWS Auto Scaling under management/governance topics.  

---

# 1. Why do we need a Load Balancer?

Imagine one EC2 server:

```text id="one-server"
User
  ↓
EC2
```

Problems:

```text id="one-server-problems"
If EC2 fails:
  website down

If traffic increases:
  EC2 overloaded

If you deploy new version:
  downtime risk

If server is in one AZ:
  AZ failure can affect app
```

Better production pattern:

```text id="lb-pattern"
Users
  ↓
Load Balancer
  ↓
EC2 instance 1
EC2 instance 2
EC2 instance 3
```

A load balancer receives traffic and distributes it across multiple healthy targets. AWS Elastic Load Balancing can distribute incoming traffic across targets such as EC2 instances, containers, IP addresses, and Lambda functions across one or more Availability Zones. ([AWS Documentation][1])

Simple analogy:

```text id="lb-analogy"
Load Balancer = receptionist / traffic police

Users come to one address.
Load balancer sends each request to a healthy backend server.
```

---

# 2. What is Elastic Load Balancing?

Elastic Load Balancing, or ELB, is the AWS service family for load balancers.

AWS supports these main load balancer types:

```text id="elb-types"
Application Load Balancer:
  Layer 7 HTTP/HTTPS routing

Network Load Balancer:
  Layer 4 TCP/UDP/TLS routing

Gateway Load Balancer:
  security appliance / firewall appliance traffic insertion

Classic Load Balancer:
  legacy, avoid for new architectures
```

AWS documentation lists Application Load Balancers, Network Load Balancers, Gateway Load Balancers, and Classic Load Balancers as supported Elastic Load Balancing types. ([AWS Documentation][2])

---

# 3. OSI layer meaning — Layer 4 vs Layer 7

You must understand this clearly.

## Layer 4

Layer 4 means:

```text id="layer4"
Transport-level routing
```

It understands:

```text id="l4-understands"
IP
port
TCP
UDP
connection
```

It does **not** deeply understand:

```text id="l4-not"
URL path
HTTP header
cookies
hostnames
```

Example:

```text id="l4-example"
TCP traffic on port 443
```

NLB works mainly at Layer 4.

---

## Layer 7

Layer 7 means:

```text id="layer7"
Application-level routing
```

It understands HTTP/HTTPS details:

```text id="l7-understands"
path
host header
HTTP method
headers
query string
cookies
redirects
fixed responses
```

Example:

```text id="l7-example"
/api/*      → API target group
/images/*   → image service
admin.app.com → admin target group
```

ALB works at Layer 7.

---

# 4. ALB vs NLB vs GWLB

| Load Balancer |                               Layer | Best for                                                        | Example                  |
| ------------- | ----------------------------------: | --------------------------------------------------------------- | ------------------------ |
| ALB           |                             Layer 7 | web apps, APIs, HTTP/HTTPS routing                              | React/Node app, REST API |
| NLB           |                             Layer 4 | very high performance TCP/UDP, static IP needs, TLS passthrough | game server, TCP service |
| GWLB          | Layer 3/4 style appliance insertion | firewalls, IDS/IPS, security appliances                         | inspection VPC           |
| CLB           |                              legacy | old apps only                                                   | old AWS deployments      |

Use simple rule:

```text id="simple-rule"
Web app or API:
  ALB

Raw TCP/UDP or ultra-low latency:
  NLB

Network security appliances:
  GWLB

New project:
  do not choose Classic Load Balancer
```

AWS describes ALB, NLB, and GWLB as different load balancer types for different routing/use cases, with ALB for application traffic and NLB/GWLB for lower-level network patterns. ([Amazon Web Services, Inc.][3])

---

# 5. Application Load Balancer in depth

An ALB has these parts:

```text id="alb-parts"
Load Balancer:
  public entry point

Listener:
  port/protocol rule, for example HTTP:80 or HTTPS:443

Listener rule:
  condition and action

Target group:
  group of backend targets

Targets:
  EC2, IPs, Lambda, containers

Health check:
  checks if target is healthy
```

Architecture:

```text id="alb-architecture"
User
  ↓ HTTP/HTTPS
ALB Listener
  ↓ rule
Target Group
  ↓
Healthy EC2 targets
```

When you create an Application Load Balancer, AWS expects you to create the load balancer, at least one listener, and at least one target group. ([AWS Documentation][4])

---

# 6. Listener

A listener is the front door of the load balancer.

Example:

```text id="listener-example"
HTTP listener:
  port 80

HTTPS listener:
  port 443
```

Listener action:

```text id="listener-action"
Forward to target group
Redirect HTTP to HTTPS
Return fixed response
Authenticate user
```

Example production design:

```text id="prod-listener"
Listener 80:
  redirect to HTTPS 443

Listener 443:
  forward to app target group
```

---

# 7. Listener rules

Listener rules decide routing.

Example:

```text id="listener-rules"
If path is /api/*
  forward to api-target-group

If path is /admin/*
  forward to admin-target-group

If host is app.example.com
  forward to app-target-group

Default:
  forward to default-target-group
```

Production use case:

```text id="prod-routing"
app.yourdatascientist.tech      → frontend target group
api.yourdatascientist.tech      → backend target group
admin.yourdatascientist.tech    → admin target group
```

---

# 8. Target group

A target group is a collection of backend targets.

Target types:

```text id="target-types"
instance:
  EC2 instance ID

ip:
  private IP target, useful for ECS/EKS/on-prem/hybrid

lambda:
  Lambda target for ALB integration

alb:
  used in some NLB-to-ALB patterns
```

For our current learning:

```text id="current-target"
ALB target group:
  EC2 instances
```

Target group settings include:

```text id="tg-settings"
protocol
port
VPC
health check path
healthy threshold
unhealthy threshold
timeout
interval
success codes
deregistration delay
```

AWS Application Load Balancer target groups route requests to registered targets and use health checks to monitor whether those targets are healthy. ([AWS Documentation][5])

---

# 9. Health checks

Health check means:

```text id="health-check-simple"
Load balancer asks:
  Is this backend server healthy?
```

Example:

```text id="health-check-example"
ALB sends:
  GET /health

Target replies:
  HTTP 200 OK

ALB marks target:
  healthy
```

If target fails:

```text id="unhealthy"
Target does not respond
or returns wrong status code
or times out

ALB marks it unhealthy
and stops sending user traffic to it
```

Before an ALB sends health checks to a target, the target must be registered in a target group, the target group must be used by a listener rule, and the target’s Availability Zone must be enabled for the load balancer. ([AWS Documentation][6])

Good health endpoint:

```text id="good-health"
GET /health

Returns:
  200 OK
  quickly
  without database-heavy logic
```

Bad health endpoint:

```text id="bad-health"
GET /
  loads full app
  calls many external APIs
  depends on slow database query
```

Production rule:

```text id="health-rule"
Health check should prove the app can serve traffic,
but it should be lightweight and reliable.
```

---

# 10. What causes ALB target unhealthy?

Most common reasons:

```text id="unhealthy-causes"
1. EC2 security group does not allow traffic from ALB security group.
2. App is listening on wrong port.
3. Health check path is wrong.
4. App returns 404/500 instead of 200.
5. App is still booting.
6. NACL blocks traffic.
7. Instance firewall blocks traffic.
8. Target group uses wrong port.
9. ALB and target are in wrong VPC/subnets.
10. User data failed, so nginx/app never started.
```

AWS troubleshooting guidance specifically notes that the instance security group must allow traffic from the load balancer on the health check port and protocol. ([AWS Documentation][7])

Debug command pattern:

```bash id="debug-target-health"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

---

# 11. Load balancer security group design

## ALB security group

Inbound:

```text id="alb-sg-in"
80 from 0.0.0.0/0
443 from 0.0.0.0/0
```

Outbound:

```text id="alb-sg-out"
app port to EC2 security group
```

## EC2 app security group

Inbound:

```text id="ec2-sg-in"
app port from ALB security group only
```

Not from:

```text id="bad-app-in"
0.0.0.0/0
```

Good production flow:

```text id="sg-flow"
Internet
  ↓
ALB SG
  ↓
EC2 App SG
```

Never expose backend EC2 directly if ALB exists.

---

# 12. Cross-zone load balancing

Cross-zone load balancing means the load balancer can distribute traffic across targets in all enabled AZs.

Example:

```text id="cross-zone"
ALB receives traffic in AZ-a
but can send request to healthy target in AZ-b
```

ALB commonly handles cross-zone balancing for application traffic. For NLB and GWLB, AWS documentation notes cross-zone load balancing is disabled by default. ([AWS Documentation][8])

Production meaning:

```text id="cross-zone-prod"
Use at least two public subnets for ALB.
Use targets in at least two AZs.
Keep capacity balanced.
```

---

# 13. Connection draining / deregistration delay

When an instance is removed from a target group, you do not want active users to be cut immediately.

Deregistration delay means:

```text id="dereg"
Stop sending new requests to target,
but allow existing in-flight requests to complete for a configured time.
```

Use case:

```text id="dereg-use"
Auto Scaling terminates old instance.
ALB drains existing connections.
Then instance terminates safely.
```

Production note:

```text id="dereg-prod"
Short APIs:
  30–60 seconds may be okay

Long requests/uploads:
  longer delay may be needed
```

---

# 14. What is Auto Scaling?

Auto Scaling means AWS automatically adjusts capacity based on demand or health.

For EC2:

```text id="asg-simple"
EC2 Auto Scaling automatically maintains and changes the number of EC2 instances.
```

Example:

```text id="asg-example"
Minimum:
  2 instances

Desired:
  2 instances

Maximum:
  6 instances

If CPU increases:
  scale out to 3, 4, 5, 6

If traffic decreases:
  scale in back to 2
```

EC2 Auto Scaling can help maintain application availability by adding or removing EC2 instances according to conditions you define, and Auto Scaling health checks can detect and replace unhealthy instances. ([AWS Documentation][9])

---

# 15. Auto Scaling Group

An Auto Scaling Group, or ASG, is a group of EC2 instances managed together.

ASG contains:

```text id="asg-parts"
Launch template:
  how to create EC2

Minimum capacity:
  lowest number of instances

Desired capacity:
  target number right now

Maximum capacity:
  upper limit

Subnets:
  where instances launch

Health checks:
  how ASG detects bad instances

Scaling policies:
  when to add/remove instances
```

Simple analogy:

```text id="asg-analogy"
ASG = manager

It watches workers.
If one worker dies, it hires another.
If workload grows, it hires more.
If workload drops, it reduces workers.
```

---

# 16. Launch Template

A launch template is a reusable EC2 launch configuration.

It includes:

```text id="lt-parts"
AMI ID
instance type
security group
IAM instance profile
user data
EBS volume config
metadata options
tags
key pair, if SSH is used
```

Production pattern:

```text id="lt-pattern"
Launch Template
  ↓
Auto Scaling Group
  ↓
EC2 instances
```

Never manually create production EC2 one by one.

Instead:

```text id="prod-instance-rule"
Define how to create instances.
Let ASG create and replace them.
```

---

# 17. Min, desired, max capacity

These three numbers are important.

```text id="capacity"
min:
  minimum instances always running

desired:
  how many ASG wants now

max:
  highest allowed instances
```

Example:

```text id="capacity-example"
min = 2
desired = 2
max = 6
```

Meaning:

```text id="capacity-meaning"
Always keep at least 2.
Normally run 2.
Can scale up to 6.
Never go beyond 6.
```

Production recommendation for web apps:

```text id="prod-min"
Use minimum 2 across two AZs for high availability.
```

---

# 18. ASG health checks

ASG can use:

```text id="asg-health"
EC2 health checks
ELB health checks
custom lifecycle/application patterns
```

## EC2 health check

Checks if EC2 infrastructure is healthy.

Example:

```text id="ec2-health"
instance status check failed
system status check failed
```

## ELB health check

Uses load balancer target group health.

This is better for applications.

Example:

```text id="elb-health"
EC2 is running,
but app on port 80 is broken.

EC2 check:
  healthy

ELB check:
  unhealthy
```

For app workloads behind ALB:

```text id="app-health"
Use ELB health checks with ASG.
```

AWS EC2 Auto Scaling supports health checks for instances in Auto Scaling groups and can replace unhealthy instances. ([AWS Documentation][10])

---

# 19. Health check grace period

When a new instance launches, it needs time to boot and run user data.

Health check grace period means:

```text id="grace"
Do not judge the new instance as unhealthy immediately.
Give it time to initialize.
```

Example:

```text id="grace-example"
health_check_grace_period = 300 seconds
```

Use when:

```text id="grace-use"
app takes time to install packages
container image takes time to pull
service takes time to start
database migration/check takes time
```

AWS describes the health check grace period as a setting that gives instances time to finish initialization before Auto Scaling checks health and potentially replaces them. ([AWS Documentation][11])

---

# 20. Scaling policies

Scaling policy tells ASG when to scale.

Main types:

```text id="scaling-types"
Target tracking scaling
Step scaling
Simple scaling
Scheduled scaling
Predictive scaling
```

---

## Target tracking scaling

Most beginner-friendly.

Example:

```text id="target-tracking"
Keep average CPU around 50%.
```

If CPU > 50:

```text id="scale-out"
add instances
```

If CPU < 50:

```text id="scale-in"
remove instances
```

Good for:

```text id="target-use"
CPU-based web apps
ALB request count per target
average metric target
```

---

## Step scaling

You define steps.

Example:

```text id="step-scaling"
CPU 60–70%:
  add 1 instance

CPU 70–85%:
  add 2 instances

CPU > 85%:
  add 3 instances
```

Good for:

```text id="step-use"
more controlled scaling behavior
clear threshold-based rules
```

---

## Scheduled scaling

Scale at known times.

Example:

```text id="scheduled"
Weekdays 9 AM:
  desired = 4

Night 10 PM:
  desired = 2
```

Good for:

```text id="scheduled-use"
predictable office-hour traffic
batch windows
events
```

---

## Predictive scaling

Uses historical patterns to forecast future demand.

Good for:

```text id="predictive-use"
daily/weekly traffic patterns
predictable repeated spikes
```

---

# 21. Scale out vs scale in

## Scale out

```text id="scale-out-def"
Add more instances.
```

Example:

```text id="scale-out-example"
2 instances → 3 instances → 4 instances
```

## Scale in

```text id="scale-in-def"
Remove instances.
```

Example:

```text id="scale-in-example"
4 instances → 3 instances → 2 instances
```

Production concern:

```text id="scale-in-concern"
Scale-in can terminate a server currently handling requests.
Use ALB deregistration delay and graceful shutdown.
```

---

# 22. Warm-up and cooldown

## Warm-up

Time needed for a new instance to become useful.

Example:

```text id="warmup"
Instance launches.
User data runs.
App starts.
ALB health check passes.
Only then it should handle traffic.
```

## Cooldown

Time to wait before another scaling action.

Purpose:

```text id="cooldown-purpose"
Avoid scaling too aggressively because metrics take time to stabilize.
```

---

# 23. Lifecycle hooks

Lifecycle hooks let you run actions when ASG launches or terminates instances.

Use cases:

```text id="lifecycle-hooks"
Before instance enters service:
  install agent
  register with deployment system
  warm cache

Before instance terminates:
  drain connections
  upload logs
  deregister from external system
```

Production example:

```text id="hook-example"
ASG launches instance
  ↓
Lifecycle hook pauses
  ↓
User data/config management completes
  ↓
Instance continues to InService
```

---

# 24. High availability design

Bad design:

```text id="bad-ha"
One EC2 in one AZ
```

Better design:

```text id="better-ha"
ALB in 2 public subnets
ASG instances in 2 private app subnets
minimum capacity 2
health checks enabled
```

Architecture:

```text id="ha-arch"
Users
  ↓
CloudFront, optional
  ↓
ALB across AZ-a and AZ-b
  ↓
ASG
  ├── EC2 in private subnet AZ-a
  └── EC2 in private subnet AZ-b
```

Why this is better:

```text id="ha-why"
If one EC2 fails:
  ASG replaces it.

If one AZ has trouble:
  other AZ can still serve.

If traffic grows:
  ASG scales out.

If traffic drops:
  ASG scales in.
```

---

# 25. ALB + ASG production flow

Full request lifecycle:

```text id="full-flow"
1. User opens website.
2. DNS resolves to CloudFront or ALB.
3. ALB receives HTTP/HTTPS request.
4. ALB listener rule chooses target group.
5. Target group chooses healthy EC2 target.
6. EC2 app processes request.
7. CloudWatch metrics track CPU/request count/errors.
8. ASG scaling policy detects high load.
9. ASG launches new EC2 from launch template.
10. New EC2 runs user data.
11. Target group health check passes.
12. ALB starts sending traffic to new instance.
13. When traffic drops, ASG scales in.
14. ALB drains old instance before termination.
```

This is the heart of classic AWS web hosting.

---

# 26. Hands-On Lab 6A — ALB + Auto Scaling Web App

This lab creates billable resources:

```text id="lab-resources"
1 Application Load Balancer
1 Target Group
1 Launch Template
1 Auto Scaling Group
2 EC2 instances initially
2 Security Groups
CloudWatch scaling policy
```

Cost warning:

```text id="cost-warning"
ALB, EC2, EBS, and public IPv4 can generate charges.
Do this lab only when you can clean up immediately.
```

Region:

```text id="region"
ap-south-1
```

For simplicity, this lab uses the **default VPC** and default public subnets. In production, we will place EC2 in private subnets behind ALB.

---

## Step 1 — Set region

```bash id="set-region"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

aws sts get-caller-identity
```

---

## Step 2 — Get default VPC and two subnets

```bash id="get-vpc-subnets"
VPC_ID="$(aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)"

SUBNETS="$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
  --query 'Subnets[0:2].SubnetId' \
  --output text)"

SUBNET_1="$(echo "$SUBNETS" | awk '{print $1}')"
SUBNET_2="$(echo "$SUBNETS" | awk '{print $2}')"

echo "VPC_ID=$VPC_ID"
echo "SUBNET_1=$SUBNET_1"
echo "SUBNET_2=$SUBNET_2"
```

---

## Step 3 — Create ALB security group

```bash id="alb-sg"
ALB_SG_ID="$(aws ec2 create-security-group \
  --group-name aws-masterclass-alb-sg \
  --description "ALB SG for AWS Masterclass" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)"

aws ec2 create-tags \
  --resources "$ALB_SG_ID" \
  --tags Key=Name,Value=aws-masterclass-alb-sg Key=Project,Value=aws-masterclass

aws ec2 authorize-security-group-ingress \
  --group-id "$ALB_SG_ID" \
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

echo "ALB_SG_ID=$ALB_SG_ID"
```

---

## Step 4 — Create EC2 security group

EC2 should allow HTTP only from ALB security group.

```bash id="ec2-sg"
EC2_SG_ID="$(aws ec2 create-security-group \
  --group-name aws-masterclass-asg-ec2-sg \
  --description "EC2 SG for ASG behind ALB" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)"

aws ec2 create-tags \
  --resources "$EC2_SG_ID" \
  --tags Key=Name,Value=aws-masterclass-asg-ec2-sg Key=Project,Value=aws-masterclass

aws ec2 authorize-security-group-ingress \
  --group-id "$EC2_SG_ID" \
  --ip-permissions "[
    {
      \"IpProtocol\": \"tcp\",
      \"FromPort\": 80,
      \"ToPort\": 80,
      \"UserIdGroupPairs\": [
        {
          \"GroupId\": \"$ALB_SG_ID\",
          \"Description\": \"HTTP from ALB only\"
        }
      ]
    }
  ]"

echo "EC2_SG_ID=$EC2_SG_ID"
```

---

## Step 5 — Find Ubuntu AMI

```bash id="ami"
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

---

## Step 6 — Create user data

This makes each EC2 show its instance ID.

```bash id="user-data"
cat > /tmp/aws-masterclass-asg-user-data.sh <<'EOF'
#!/bin/bash
set -eux

apt-get update -y
apt-get install -y nginx curl

TOKEN="$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")"

INSTANCE_ID="$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)"

AZ="$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)"

cat > /var/www/html/index.html <<HTML
<!doctype html>
<html>
  <head>
    <title>AWS Masterclass ALB ASG</title>
  </head>
  <body>
    <h1>Hello from Auto Scaling Group</h1>
    <p>Instance ID: ${INSTANCE_ID}</p>
    <p>Availability Zone: ${AZ}</p>
  </body>
</html>
HTML

cat > /var/www/html/health <<'HEALTH'
healthy
HEALTH

systemctl enable nginx
systemctl restart nginx
EOF
```

---

## Step 7 — Create launch template

```bash id="launch-template"
LT_ID="$(aws ec2 create-launch-template \
  --launch-template-name aws-masterclass-web-lt \
  --version-description "v1 nginx web server" \
  --launch-template-data "{
    \"ImageId\": \"$AMI_ID\",
    \"InstanceType\": \"t3.micro\",
    \"SecurityGroupIds\": [\"$EC2_SG_ID\"],
    \"UserData\": \"$(base64 -w 0 /tmp/aws-masterclass-asg-user-data.sh)\",
    \"MetadataOptions\": {
      \"HttpTokens\": \"required\",
      \"HttpEndpoint\": \"enabled\"
    },
    \"BlockDeviceMappings\": [
      {
        \"DeviceName\": \"/dev/sda1\",
        \"Ebs\": {
          \"VolumeSize\": 8,
          \"VolumeType\": \"gp3\",
          \"DeleteOnTermination\": true,
          \"Encrypted\": true
        }
      }
    ],
    \"TagSpecifications\": [
      {
        \"ResourceType\": \"instance\",
        \"Tags\": [
          {\"Key\": \"Name\", \"Value\": \"aws-masterclass-asg-web\"},
          {\"Key\": \"Project\", \"Value\": \"aws-masterclass\"},
          {\"Key\": \"Environment\", \"Value\": \"dev\"}
        ]
      }
    ]
  }" \
  --query 'LaunchTemplate.LaunchTemplateId' \
  --output text)"

echo "LT_ID=$LT_ID"
```

On macOS, if `base64 -w 0` fails, use:

```bash id="mac-base64-note"
base64 < /tmp/aws-masterclass-asg-user-data.sh | tr -d '\n'
```

---

## Step 8 — Create target group

```bash id="target-group"
TG_ARN="$(aws elbv2 create-target-group \
  --name aws-masterclass-web-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id "$VPC_ID" \
  --target-type instance \
  --health-check-protocol HTTP \
  --health-check-path /health \
  --health-check-interval-seconds 15 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --matcher HttpCode=200 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)"

echo "TG_ARN=$TG_ARN"
```

---

## Step 9 — Create ALB

```bash id="create-alb"
ALB_ARN="$(aws elbv2 create-load-balancer \
  --name aws-masterclass-alb \
  --subnets "$SUBNET_1" "$SUBNET_2" \
  --security-groups "$ALB_SG_ID" \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)"

echo "ALB_ARN=$ALB_ARN"

aws elbv2 wait load-balancer-available \
  --load-balancer-arns "$ALB_ARN"
```

Get ALB DNS:

```bash id="alb-dns"
ALB_DNS="$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)"

echo "ALB_DNS=$ALB_DNS"
```

---

## Step 10 — Create listener

```bash id="listener"
LISTENER_ARN="$(aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
  --query 'Listeners[0].ListenerArn' \
  --output text)"

echo "LISTENER_ARN=$LISTENER_ARN"
```

---

## Step 11 — Create Auto Scaling Group

```bash id="asg"
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name aws-masterclass-web-asg \
  --launch-template "LaunchTemplateId=$LT_ID,Version=1" \
  --min-size 2 \
  --desired-capacity 2 \
  --max-size 4 \
  --vpc-zone-identifier "$SUBNET_1,$SUBNET_2" \
  --target-group-arns "$TG_ARN" \
  --health-check-type ELB \
  --health-check-grace-period 300 \
  --tags \
    "Key=Name,Value=aws-masterclass-web-asg,PropagateAtLaunch=false" \
    "Key=Project,Value=aws-masterclass,PropagateAtLaunch=true" \
    "Key=Environment,Value=dev,PropagateAtLaunch=true"
```

Wait a few minutes.

---

## Step 12 — Validate ASG instances

```bash id="validate-asg"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-masterclass-web-asg \
  --query 'AutoScalingGroups[0].{Min:MinSize,Desired:DesiredCapacity,Max:MaxSize,Instances:Instances[].{InstanceId:InstanceId,LifecycleState:LifecycleState,HealthStatus:HealthStatus,AZ:AvailabilityZone}}' \
  --output json
```

---

## Step 13 — Validate target health

```bash id="validate-target-health"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

Wait until targets show:

```text id="healthy"
healthy
```

---

## Step 14 — Test ALB

```bash id="curl-alb"
curl -I "http://$ALB_DNS"
curl "http://$ALB_DNS"
curl "http://$ALB_DNS/health"
```

Run multiple times:

```bash id="curl-loop"
for i in {1..10}; do
  curl -s "http://$ALB_DNS" | grep "Instance ID"
  sleep 1
done
```

You should see responses from different instances over time.

---

## Step 15 — Add target tracking scaling policy

Scale based on average CPU.

```bash id="scaling-policy"
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name aws-masterclass-web-asg \
  --policy-name aws-masterclass-cpu-50-target \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "TargetValue": 50.0
  }'
```

This means:

```text id="target-policy-meaning"
Try to keep average ASG CPU around 50%.
```

---

# 27. Test failure replacement

Terminate one instance manually and watch ASG replace it.

Get instance:

```bash id="get-asg-instance"
INSTANCE_ID="$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-masterclass-web-asg \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)"

echo "$INSTANCE_ID"
```

Terminate:

```bash id="terminate-one"
aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID"
```

Watch ASG:

```bash id="watch-asg"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-masterclass-web-asg \
  --query 'AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,LifecycleState:LifecycleState,HealthStatus:HealthStatus,AZ:AvailabilityZone}' \
  --output table
```

Expected:

```text id="replacement"
ASG notices capacity is below desired.
ASG launches replacement instance.
Target group eventually marks it healthy.
```

This is why ASG matters.

---

# 28. Cleanup Lab 6A

Cleanup order matters.

## Step 1 — Delete scaling policy

```bash id="delete-policy"
aws autoscaling delete-policy \
  --auto-scaling-group-name aws-masterclass-web-asg \
  --policy-name aws-masterclass-cpu-50-target || true
```

## Step 2 — Delete Auto Scaling Group

Set capacity to zero:

```bash id="asg-zero"
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name aws-masterclass-web-asg \
  --min-size 0 \
  --desired-capacity 0 \
  --max-size 0
```

Wait for instances to terminate:

```bash id="wait-scale-down"
sleep 120

aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-masterclass-web-asg \
  --query 'AutoScalingGroups[0].Instances' \
  --output table
```

Delete ASG:

```bash id="delete-asg"
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name aws-masterclass-web-asg \
  --force-delete
```

## Step 3 — Delete listener

```bash id="delete-listener"
aws elbv2 delete-listener \
  --listener-arn "$LISTENER_ARN"
```

## Step 4 — Delete ALB

```bash id="delete-alb"
aws elbv2 delete-load-balancer \
  --load-balancer-arn "$ALB_ARN"

sleep 60
```

## Step 5 — Delete target group

```bash id="delete-tg"
aws elbv2 delete-target-group \
  --target-group-arn "$TG_ARN"
```

If it says target group is in use, wait and retry.

## Step 6 — Delete launch template

```bash id="delete-lt"
aws ec2 delete-launch-template \
  --launch-template-id "$LT_ID"
```

## Step 7 — Delete security groups

```bash id="delete-sgs"
aws ec2 delete-security-group \
  --group-id "$EC2_SG_ID"

aws ec2 delete-security-group \
  --group-id "$ALB_SG_ID"
```

If security group deletion fails, wait until ENIs are released and retry.

## Step 8 — Verify cleanup

```bash id="verify-cleanup"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names aws-masterclass-web-asg \
  --output table

aws elbv2 describe-load-balancers \
  --names aws-masterclass-alb \
  --output table

aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=aws-masterclass" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

---

# 29. Common errors and fixes

## Error 1 — ALB target unhealthy

Check target health:

```bash id="err-target-health"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --output json
```

Fix checklist:

```text id="unhealthy-fix"
EC2 SG allows port 80 from ALB SG
nginx/app is running
/health returns 200
target group port is 80
health check path is /health
instance is in enabled AZ
user data completed
```

---

## Error 2 — ALB returns 503

Meaning:

```text id="alb-503"
ALB has no healthy targets.
```

Fix:

```text id="503-fix"
Fix target group health first.
```

---

## Error 3 — ALB timeout

Possible causes:

```text id="timeout-causes"
EC2 security group blocks ALB
app is not listening
NACL blocks traffic
wrong target port
instance firewall blocks traffic
```

---

## Error 4 — ASG launches instance but it terminates repeatedly

Possible causes:

```text id="flapping-causes"
health check grace period too short
user data fails
app takes too long to start
health check path wrong
ELB health check enabled too early
```

Fix:

```text id="flapping-fix"
increase health check grace period
check /var/log/cloud-init-output.log
fix user data
test health endpoint manually
```

---

## Error 5 — Security group deletion fails

Reason:

```text id="sg-delete-fail"
Security group is still attached to ENI/load balancer/instance.
```

Fix:

```text id="sg-delete-fix"
Wait after deleting ALB/instances.
Then retry.
```

---

# 30. Production best practices

For production:

```text id="prod-best"
Use ALB across at least two AZs.
Use ASG across private app subnets.
Use minimum capacity 2 for HA.
Use launch templates, not manual EC2.
Use IMDSv2.
Use IAM roles.
Use ALB health checks.
Use target tracking or request-count scaling.
Use deregistration delay.
Use CloudWatch alarms.
Use HTTPS listener with ACM certificate.
Use HTTP to HTTPS redirect.
Use WAF for public apps when needed.
Avoid public SSH.
Use SSM.
```

Production architecture:

```text id="prod-arch"
User
  ↓
Route 53
  ↓
CloudFront
  ↓
ALB public subnets
  ↓
ASG EC2 private app subnets
  ↓
RDS private DB subnets
```

---

# 31. Scaling metric selection

Do not always use CPU.

Choose metric based on workload:

| Workload              | Good scaling metric                    |
| --------------------- | -------------------------------------- |
| CPU-heavy API         | CPUUtilization                         |
| Web app               | ALB RequestCountPerTarget              |
| Queue workers         | SQS ApproximateNumberOfMessagesVisible |
| Memory-heavy app      | custom memory metric                   |
| Batch jobs            | queue depth / job count                |
| Latency-sensitive app | custom latency metric                  |
| Network-heavy service | NetworkIn/NetworkOut                   |

Better production thinking:

```text id="metric-thinking"
Scale on the bottleneck.
If CPU is not the bottleneck, CPU scaling will not help.
```

---

# 32. Deployment with ASG

When you need a new app version:

```text id="asg-deploy"
Create new launch template version.
Update ASG to use new version.
Refresh instances gradually.
ALB health checks validate new instances.
Old instances drain and terminate.
```

This is called:

```text id="instance-refresh"
Instance refresh
```

We will cover this in the DevOps deployment section.

---

# 33. Certification angle

## CLF-C02

Know:

```text id="clf"
ELB distributes traffic.
Auto Scaling adjusts capacity.
Load balancing improves availability.
Auto Scaling helps cost and performance.
```

## SAA-C03

Know deeply:

```text id="saa"
ALB vs NLB vs GWLB
listeners
target groups
health checks
path-based routing
host-based routing
multi-AZ ALB
ASG min/desired/max
launch templates
target tracking scaling
private EC2 behind public ALB
ELB health checks with ASG
deregistration delay
```

## DOP-C02

Know operationally:

```text id="dop"
rolling deployments with ASG
instance refresh
CodeDeploy with ALB
health check grace period
lifecycle hooks
CloudWatch scaling alarms
failed deployment rollback
target health troubleshooting
capacity planning
scaling policy tuning
```

---

# 34. Interview answer

Memorize this:

```text id="interview-answer"
Elastic Load Balancing distributes incoming traffic across healthy targets such as EC2 instances, containers, IP addresses, or Lambda functions. For web applications and APIs, I usually use an Application Load Balancer because it supports Layer 7 HTTP/HTTPS routing, host-based routing, path-based routing, redirects, and integration with target groups and health checks.

In production, I place the ALB in public subnets across at least two Availability Zones and place EC2 instances in private app subnets. The ALB security group allows internet traffic on 80 or 443, while the EC2 security group allows application traffic only from the ALB security group. The target group health check verifies that each backend instance can serve traffic before the ALB sends requests to it.

For scaling and high availability, I use an Auto Scaling Group with a launch template. The launch template defines the AMI, instance type, security group, IAM role, storage, user data, and metadata settings. The ASG defines minimum, desired, and maximum capacity across multiple subnets. I usually use ELB health checks so unhealthy application instances are replaced, and target tracking policies such as CPU utilization or ALB request count per target to scale out and scale in automatically. During scale-in or deployments, deregistration delay and graceful shutdown help avoid dropping active requests.
```

---

# 35. Quick quiz

```text id="quiz"
1. Why do we need a load balancer?
2. What is Elastic Load Balancing?
3. What is ALB best for?
4. What is NLB best for?
5. What is GWLB best for?
6. What is a listener?
7. What is a target group?
8. What is a health check?
9. Why does ALB return 503?
10. What is an Auto Scaling Group?
11. What is a launch template?
12. What is min/desired/max capacity?
13. What is scale out?
14. What is scale in?
15. Why use health check grace period?
16. Why use ELB health check with ASG?
17. Why put EC2 in private subnets?
18. Why should EC2 SG allow traffic only from ALB SG?
19. What metric should queue workers scale on?
20. What should you clean up after the lab?
```

Answers:

```text id="answers"
1. To distribute traffic and avoid depending on one server.
2. AWS managed load balancing service family.
3. HTTP/HTTPS web apps and APIs.
4. TCP/UDP/TLS high-performance network traffic.
5. Security appliance and firewall insertion.
6. Front-end port/protocol rule on load balancer.
7. Group of backend targets.
8. Test that target can serve traffic.
9. No healthy targets.
10. Group that maintains/scales EC2 instances.
11. Template defining how EC2 instances are launched.
12. Minimum, current desired, and maximum number of instances.
13. Add instances.
14. Remove instances.
15. Give new instances time to boot and start app.
16. EC2 can be running while app is broken; ELB health checks app health.
17. To avoid direct internet exposure.
18. To force traffic through ALB only.
19. SQS queue depth.
20. ASG, ALB, target group, launch template, EC2 instances, security groups.
```

---

# Next Lesson

```text id="next"
AWS Lesson 7 — Storage From Zero to Production:
S3, EBS, EFS, FSx, Glacier, object vs block vs file storage, encryption, versioning, lifecycle rules, backups, and hosting static content
```

[1]: https://docs.aws.amazon.com/elasticloadbalancing/?utm_source=chatgpt.com "Elastic Load Balancing Documentation"
[2]: https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/what-is-load-balancing.html?utm_source=chatgpt.com "What is Elastic Load Balancing? - Elastic Load Balancing"
[3]: https://aws.amazon.com/compare/the-difference-between-the-difference-between-application-network-and-gateway-load-balancing/?trk=faq_card&utm_source=chatgpt.com "Application, Network, and Gateway Load Balancing - Difference Between Load Balancing Types - AWS"
[4]: https://docs.aws.amazon.com/en_en/elasticloadbalancing/latest/application/create-application-load-balancer.html?utm_source=chatgpt.com "Create an Application Load Balancer - Elastic Load Balancing"
[5]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html?utm_source=chatgpt.com "Target groups for your Application Load Balancers - Elastic Load Balancing"
[6]: https://docs.aws.amazon.com/en_en/elasticloadbalancing/latest/application/target-group-health-checks.html?utm_source=chatgpt.com "Health checks for Application Load Balancer target groups - Elastic Load Balancing"
[7]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-troubleshooting.html?utm_source=chatgpt.com "Troubleshoot your Application Load Balancers - Elastic Load Balancing"
[8]: https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html?utm_source=chatgpt.com "How Elastic Load Balancing works - Elastic Load Balancing"
[9]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-health-checks.html?utm_source=chatgpt.com "Health checks for instances in an Auto Scaling group - Amazon EC2 Auto Scaling"
[10]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/health-checks-overview.html?utm_source=chatgpt.com "About the health checks for your Auto Scaling group - Amazon EC2 Auto Scaling"
[11]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/health-check-grace-period.html?utm_source=chatgpt.com "Set the health check grace period for an Auto Scaling group - Amazon EC2 Auto Scaling"
