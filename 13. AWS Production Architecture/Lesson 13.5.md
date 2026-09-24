# AWS Masterclass — Lesson 4

## VPC Design In Depth — Public, Private, Database Subnets, NAT, VPC Endpoints, Route Strategy, and 3-Tier Architecture

Today we go from “I know what a VPC is” to “I can design a production VPC.”

Your AWS architect outline includes networking/content delivery topics like **VPC, Route 53, CloudFront, Direct Connect, PrivateLink, and Transit Gateway** . These are not optional architect topics. They are the backbone of AWS architecture.

---

# 1. What is VPC design?

VPC design means deciding:

```text id="47x1a0"
What IP range should my AWS network use?
How many subnets do I need?
Which subnets are public?
Which subnets are private?
Where should ALB live?
Where should app servers live?
Where should database live?
How does internet traffic enter?
How does private traffic go out?
How do AWS services get accessed privately?
How will this connect to on-premise later?
How do I avoid IP conflict in hybrid cloud?
```

AWS VPC lets you define a logically isolated network, including IP ranges, subnets, route tables, gateways, and security controls. Subnets are IP ranges inside a VPC and each subnet exists in one Availability Zone. ([Amazon Web Services, Inc.][1])

---

# 2. The production VPC mental model

Think of your application as three layers:

```text id="three-tier"
Layer 1:
  Public entry layer

Layer 2:
  Private application layer

Layer 3:
  Private database layer
```

Architecture:

```text id="arch"
Internet
  ↓
CloudFront
  ↓
Application Load Balancer
  ↓
Private app servers / containers
  ↓
Private database
```

VPC layout:

```text id="vpc-layout"
VPC: 10.0.0.0/16

AZ ap-south-1a:
  public subnet       10.0.1.0/24
  private app subnet  10.0.11.0/24
  private db subnet   10.0.21.0/24

AZ ap-south-1b:
  public subnet       10.0.2.0/24
  private app subnet  10.0.12.0/24
  private db subnet   10.0.22.0/24
```

Why two AZs?

```text id="two-az"
If one Availability Zone has a problem,
your app can still run in the other AZ.
```

The AWS Well-Architected Reliability pillar emphasizes designing workloads to perform correctly and consistently, including using appropriate multi-location deployment choices for reliability. ([AWS Documentation][2])

---

# 3. Public subnet, private subnet, database subnet

## Public subnet

A subnet is public when its route table has:

```text id="public-route"
0.0.0.0/0 → Internet Gateway
```

Usually place these in public subnets:

```text id="public-resources"
Application Load Balancer
NAT Gateway
bastion host, only when really needed
public-facing firewall appliance, if used
```

Do **not** think:

```text id="wrong-public"
Public subnet = all resources inside are automatically public
```

Correct thinking:

```text id="correct-public"
Public subnet means the subnet has a route to an Internet Gateway.
A resource still needs public IP, security group permission, and app listener to be reachable.
```

---

## Private app subnet

A private app subnet normally does **not** route directly to Internet Gateway.

Usually place these here:

```text id="private-app"
EC2 application servers
ECS tasks
EKS worker nodes
internal services
background workers
```

The private app layer receives traffic from ALB, not directly from the internet.

```text id="app-flow"
Internet
  ↓
ALB in public subnet
  ↓
App server in private app subnet
```

---

## Private database subnet

A private database subnet is even more restricted.

Usually place these here:

```text id="db-subnet"
RDS
Aurora
ElastiCache
DocumentDB
database replicas
```

Database subnet should not have direct internet route.

```text id="db-rule"
Database should receive traffic only from application security group.
```

Example:

```text id="sg-flow"
ALB SG
  ↓ allowed to app port
App SG
  ↓ allowed to DB port
DB SG
```

---

# 4. Route table strategy

Route tables are what make subnets behave differently.

## Public route table

```text id="public-rt"
Destination        Target
10.0.0.0/16        local
0.0.0.0/0          Internet Gateway
```

Used by:

```text id="public-rt-used"
public subnets
```

Meaning:

```text id="public-meaning"
Traffic inside VPC stays local.
All external traffic goes to internet gateway.
```

---

## Private app route table with NAT

```text id="private-app-rt"
Destination        Target
10.0.0.0/16        local
0.0.0.0/0          NAT Gateway
```

Used by:

```text id="private-app-used"
private app subnets
```

Meaning:

```text id="private-app-meaning"
App servers can go out to internet.
Internet cannot directly initiate inbound connection to them.
```

AWS NAT devices allow instances in private subnets to connect to the internet or other AWS services while preventing the internet from initiating connections to those instances. ([AWS Repost][3])

---

## Private database route table

```text id="private-db-rt"
Destination        Target
10.0.0.0/16        local
```

Used by:

```text id="private-db-used"
database subnets
```

Meaning:

```text id="db-meaning"
Database can communicate inside VPC only.
No direct internet route.
```

This is the safest default.

---

# 5. NAT Gateway design

NAT Gateway is for **outbound internet from private subnets**.

Example:

```text id="nat-flow"
Private EC2
  ↓
Private app route table
  ↓
NAT Gateway in public subnet
  ↓
Internet Gateway
  ↓
Internet
```

Use NAT when private resources need to:

```text id="nat-use"
download OS packages
call third-party APIs
pull external dependencies
access public internet endpoints
```

## One NAT Gateway vs one per AZ

### Cheaper beginner design

```text id="one-nat"
1 NAT Gateway in one public subnet
private subnets in both AZs route to same NAT
```

Problem:

```text id="one-nat-problem"
If NAT AZ has issue,
private outbound internet can fail for both AZs.
Cross-AZ data path can also be less ideal.
```

### Production design

```text id="nat-per-az"
1 NAT Gateway per AZ

private app subnet in AZ-a → NAT in AZ-a
private app subnet in AZ-b → NAT in AZ-b
```

Better for availability.

Cost warning:

```text id="nat-cost"
NAT Gateway has hourly and data processing charges.
Do not create it casually in labs.
```

---

# 6. VPC Endpoints — the NAT cost saver and security booster

A VPC endpoint lets resources inside your VPC reach supported AWS services privately.

Simple meaning:

```text id="endpoint-simple"
Private EC2 can access AWS services without going through public internet.
```

Without endpoint:

```text id="without-endpoint"
Private EC2
  ↓
NAT Gateway
  ↓
Internet Gateway
  ↓
AWS service public endpoint
```

With endpoint:

```text id="with-endpoint"
Private EC2
  ↓
VPC Endpoint
  ↓
AWS service privately
```

AWS PrivateLink lets you connect your VPC to supported AWS services as if those services were inside your VPC, without using an internet gateway. ([AWS Documentation][4])

There are two important endpoint types:

```text id="endpoint-types"
Gateway endpoint:
  S3
  DynamoDB

Interface endpoint:
  SSM
  EC2 messages
  CloudWatch Logs
  ECR
  Secrets Manager
  KMS
  many other AWS services
```

Important production use case:

```text id="ssm-endpoints"
Private EC2 with no NAT can still use SSM if you create required interface endpoints:
  ssm
  ssmmessages
  ec2messages
```

---

# 7. The best beginner production VPC pattern

Use this as your default architecture:

```text id="default-vpc"
VPC:
  10.0.0.0/16

Public subnets:
  ALB
  NAT Gateway

Private app subnets:
  EC2 / ECS / EKS workloads

Private db subnets:
  RDS / Aurora / ElastiCache

Connectivity:
  Internet → CloudFront → ALB → App → DB

Admin access:
  SSM, not public SSH
```

Diagram:

```text id="diagram"
Internet
  ↓
CloudFront
  ↓
ALB SG
  ↓
App SG
  ↓
DB SG

Public Subnets:
  ALB
  NAT Gateway

Private App Subnets:
  EC2/ECS/EKS

Private DB Subnets:
  RDS/Aurora/Redis
```

---

# 8. CIDR planning in depth

CIDR planning is where many beginners make long-term mistakes.

Bad VPC design:

```text id="bad-cidr"
VPC:
  10.0.0.0/24
```

Problem:

```text id="bad-cidr-problem"
Too small.
You will run out of IPs quickly.
```

Good beginner VPC:

```text id="good-cidr"
VPC:
  10.0.0.0/16
```

Then divide:

```text id="cidr-divide"
Public:
  10.0.1.0/24
  10.0.2.0/24

Private app:
  10.0.11.0/24
  10.0.12.0/24

Private db:
  10.0.21.0/24
  10.0.22.0/24
```

Better enterprise planning:

```text id="enterprise-cidr"
Dev VPC:
  10.10.0.0/16

Staging VPC:
  10.20.0.0/16

Prod VPC:
  10.30.0.0/16

Shared services VPC:
  10.40.0.0/16

On-prem:
  172.16.0.0/16
```

Golden rule for hybrid:

```text id="hybrid-rule"
Never overlap AWS VPC CIDR with on-premise CIDR.
```

Why?

```text id="overlap-problem"
If AWS and on-prem both use 10.0.0.0/16,
routing becomes confusing or impossible.
```

---

# 9. Subnet sizing strategy

AWS reserves five IP addresses in each subnet, so do not make subnets too small. For IPv4 subnets, AWS supports subnet CIDR sizes from `/16` to `/28`, and reserves the first four and last IP address. ([Amazon Web Services, Inc.][1])

Practical subnet choices:

| Subnet size | Total IPs | Usable AWS IPs | Use case                    |
| ----------- | --------: | -------------: | --------------------------- |
| `/28`       |        16 |             11 | tiny test only              |
| `/27`       |        32 |             27 | very small                  |
| `/26`       |        64 |             59 | small                       |
| `/24`       |       256 |            251 | common beginner/prod subnet |
| `/20`       |      4096 |           4091 | large EKS/ECS workloads     |

For Kubernetes/EKS:

```text id="eks-ip"
Use larger private app subnets.
Pods and nodes consume many IPs.
```

For simple EC2 app:

```text id="ec2-ip"
A /24 per subnet is usually enough for labs and small apps.
```

---

# 10. Security group design pattern

Use security groups like this:

## ALB security group

Inbound:

```text id="alb-inbound"
80 from 0.0.0.0/0
443 from 0.0.0.0/0
```

Outbound:

```text id="alb-outbound"
app port to App SG
```

## App security group

Inbound:

```text id="app-inbound"
app port from ALB SG
```

Outbound:

```text id="app-outbound"
DB port to DB SG
HTTPS 443 to internet or VPC endpoints
```

## Database security group

Inbound:

```text id="db-inbound"
DB port from App SG only
```

Outbound:

```text id="db-outbound"
usually restricted or default depending service
```

Never do this:

```text id="bad-sg"
DB port 5432 from 0.0.0.0/0
SSH port 22 from 0.0.0.0/0
App server port from 0.0.0.0/0 when ALB exists
```

Correct production flow:

```text id="correct-sg"
Internet
  ↓
ALB only
  ↓
App only from ALB
  ↓
DB only from App
```

---

# 11. NACL design strategy

For most workloads:

```text id="nacl-basic"
Keep default NACL simple.
Use Security Groups for fine-grained control.
```

Use custom NACLs when:

```text id="nacl-use"
you need subnet-level deny rules
you have compliance requirement
you want coarse network segmentation
you need extra defense-in-depth
```

Remember:

```text id="nacl-reminder"
NACL is stateless.
If you allow inbound, you must also allow outbound response traffic.
```

Beginner recommendation:

```text id="beginner-nacl"
Do not overcomplicate NACLs early.
Master Security Groups first.
```

---

# 12. DNS settings inside VPC

Usually enable:

```text id="dns"
enableDnsSupport = true
enableDnsHostnames = true
```

Why?

```text id="dns-why"
EC2 gets DNS names.
AWS internal DNS resolution works properly.
Private hosted zones work later.
SSM and service discovery become easier.
```

For production:

```text id="prod-dns"
Use Route 53 public hosted zone for internet names.
Use Route 53 private hosted zone for internal service names.
Use Route 53 Resolver endpoints for hybrid DNS with on-premise.
```

---

# 13. Hybrid architecture VPC thinking

Hybrid means:

```text id="hybrid"
Some systems run on-premise.
Some systems run in AWS.
Both need to communicate.
```

Common hybrid components:

```text id="hybrid-components"
Site-to-Site VPN:
  encrypted tunnel over internet

Direct Connect:
  private dedicated connection

Transit Gateway:
  central router for multiple VPCs/VPNs/DX

Route 53 Resolver:
  hybrid DNS forwarding

PrivateLink:
  private service access

Storage Gateway:
  on-prem to AWS storage bridge

DataSync:
  file/data transfer

DMS:
  database migration
```

First hybrid rule:

```text id="hybrid-first"
CIDR ranges must not overlap.
```

Example good design:

```text id="hybrid-example"
On-prem:
  172.16.0.0/16

AWS prod VPC:
  10.30.0.0/16

AWS dev VPC:
  10.10.0.0/16
```

Bad:

```text id="hybrid-bad"
On-prem:
  10.0.0.0/16

AWS VPC:
  10.0.0.0/16
```

---

# 14. How to decide resource placement

## ALB

Place in:

```text id="alb-placement"
public subnets across at least two AZs
```

Because:

```text id="alb-why"
users from internet need to reach ALB
ALB distributes traffic to private app targets
```

## EC2 app servers

Place in:

```text id="app-placement"
private app subnets
```

Because:

```text id="app-why"
users should not directly access EC2
only ALB should reach app servers
```

## RDS database

Place in:

```text id="rds-placement"
private database subnets
```

Because:

```text id="rds-why"
database should not be internet-facing
only app should reach database
```

## NAT Gateway

Place in:

```text id="nat-placement"
public subnet
```

Because:

```text id="nat-why"
NAT needs route to Internet Gateway
private subnets route outbound traffic to NAT
```

## VPC endpoints

Place in:

```text id="endpoint-placement"
private subnets or route tables depending endpoint type
```

Gateway endpoints attach to route tables.

Interface endpoints create ENIs in subnets.

---

# 15. Exam-critical comparison table

| Component          | Purpose                              | Lives where?           | Common mistake                       |
| ------------------ | ------------------------------------ | ---------------------- | ------------------------------------ |
| VPC                | private AWS network                  | Region                 | CIDR overlaps                        |
| Subnet             | smaller network                      | One AZ                 | thinking name decides public/private |
| Public subnet      | internet-routable subnet             | one AZ                 | putting databases here               |
| Private app subnet | app workloads                        | one AZ                 | no NAT/endpoints for updates         |
| Private DB subnet  | data tier                            | one AZ                 | public DB access                     |
| Route table        | traffic path                         | associated with subnet | wrong default route                  |
| IGW                | internet gateway                     | attached to VPC        | no public IP/SG                      |
| NAT Gateway        | outbound internet for private subnet | public subnet          | expensive if forgotten               |
| VPC endpoint       | private AWS service access           | VPC/subnets            | missing endpoint SG/DNS              |
| SG                 | stateful resource firewall           | ENI/resource           | opening 0.0.0.0/0                    |
| NACL               | stateless subnet firewall            | subnet                 | forgetting return traffic            |

---

# 16. Hands-On Lab 4A — Build a 3-Tier VPC Skeleton

This lab creates:

```text id="lab-create"
1 VPC
2 public subnets
2 private app subnets
2 private database subnets
1 Internet Gateway
1 public route table
1 private app route table
1 private database route table
route table associations
```

It does **not** create:

```text id="lab-no"
EC2
NAT Gateway
ALB
RDS
Elastic IP
```

Cost:

```text id="lab-cost"
VPC, subnets, route tables, and Internet Gateway have no hourly charge.
NAT Gateway is intentionally not created.
```

Region:

```text id="lab-region"
ap-south-1
```

---

## Step 1 — Set region

```bash id="set-region"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

aws sts get-caller-identity
```

---

## Step 2 — Create VPC

```bash id="create-vpc"
VPC_ID="$(aws ec2 create-vpc \
  --cidr-block 10.60.0.0/16 \
  --query 'Vpc.VpcId' \
  --output text)"

aws ec2 create-tags \
  --resources "$VPC_ID" \
  --tags Key=Name,Value=aws-masterclass-3tier-vpc Key=Project,Value=aws-masterclass Key=Environment,Value=dev

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-support "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}"

echo "VPC_ID=$VPC_ID"
```

---

## Step 3 — Select two AZs

```bash id="azs"
AZ1="$(aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[0].ZoneName' \
  --output text)"

AZ2="$(aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[1].ZoneName' \
  --output text)"

echo "AZ1=$AZ1"
echo "AZ2=$AZ2"
```

---

## Step 4 — Create six subnets

```bash id="create-subnets"
PUBLIC_1="$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.60.1.0/24 \
  --availability-zone "$AZ1" \
  --query 'Subnet.SubnetId' \
  --output text)"

PUBLIC_2="$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.60.2.0/24 \
  --availability-zone "$AZ2" \
  --query 'Subnet.SubnetId' \
  --output text)"

APP_1="$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.60.11.0/24 \
  --availability-zone "$AZ1" \
  --query 'Subnet.SubnetId' \
  --output text)"

APP_2="$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.60.12.0/24 \
  --availability-zone "$AZ2" \
  --query 'Subnet.SubnetId' \
  --output text)"

DB_1="$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.60.21.0/24 \
  --availability-zone "$AZ1" \
  --query 'Subnet.SubnetId' \
  --output text)"

DB_2="$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.60.22.0/24 \
  --availability-zone "$AZ2" \
  --query 'Subnet.SubnetId' \
  --output text)"

echo "$PUBLIC_1 $PUBLIC_2 $APP_1 $APP_2 $DB_1 $DB_2"
```

---

## Step 5 — Tag subnets

```bash id="tag-subnets"
aws ec2 create-tags --resources "$PUBLIC_1" \
  --tags Key=Name,Value=aws-masterclass-public-1 Key=Tier,Value=public Key=Project,Value=aws-masterclass

aws ec2 create-tags --resources "$PUBLIC_2" \
  --tags Key=Name,Value=aws-masterclass-public-2 Key=Tier,Value=public Key=Project,Value=aws-masterclass

aws ec2 create-tags --resources "$APP_1" \
  --tags Key=Name,Value=aws-masterclass-app-1 Key=Tier,Value=app Key=Project,Value=aws-masterclass

aws ec2 create-tags --resources "$APP_2" \
  --tags Key=Name,Value=aws-masterclass-app-2 Key=Tier,Value=app Key=Project,Value=aws-masterclass

aws ec2 create-tags --resources "$DB_1" \
  --tags Key=Name,Value=aws-masterclass-db-1 Key=Tier,Value=database Key=Project,Value=aws-masterclass

aws ec2 create-tags --resources "$DB_2" \
  --tags Key=Name,Value=aws-masterclass-db-2 Key=Tier,Value=database Key=Project,Value=aws-masterclass
```

Enable public IP auto-assign only on public subnets:

```bash id="public-ip"
aws ec2 modify-subnet-attribute \
  --subnet-id "$PUBLIC_1" \
  --map-public-ip-on-launch

aws ec2 modify-subnet-attribute \
  --subnet-id "$PUBLIC_2" \
  --map-public-ip-on-launch
```

---

## Step 6 — Create and attach Internet Gateway

```bash id="igw"
IGW_ID="$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)"

aws ec2 create-tags \
  --resources "$IGW_ID" \
  --tags Key=Name,Value=aws-masterclass-3tier-igw Key=Project,Value=aws-masterclass

aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

echo "IGW_ID=$IGW_ID"
```

---

## Step 7 — Create route tables

```bash id="route-tables"
PUBLIC_RT="$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text)"

APP_RT="$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text)"

DB_RT="$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text)"

aws ec2 create-tags --resources "$PUBLIC_RT" \
  --tags Key=Name,Value=aws-masterclass-public-rt Key=Project,Value=aws-masterclass

aws ec2 create-tags --resources "$APP_RT" \
  --tags Key=Name,Value=aws-masterclass-app-rt Key=Project,Value=aws-masterclass

aws ec2 create-tags --resources "$DB_RT" \
  --tags Key=Name,Value=aws-masterclass-db-rt Key=Project,Value=aws-masterclass

echo "PUBLIC_RT=$PUBLIC_RT"
echo "APP_RT=$APP_RT"
echo "DB_RT=$DB_RT"
```

---

## Step 8 — Add public internet route

Only public route table gets internet route:

```bash id="public-route"
aws ec2 create-route \
  --route-table-id "$PUBLIC_RT" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID"
```

Notice:

```text id="no-private-route"
APP_RT has no 0.0.0.0/0 route.
DB_RT has no 0.0.0.0/0 route.
```

So app and db subnets are private/isolated for this lab.

---

## Step 9 — Associate route tables

```bash id="associate"
PUB_ASSOC_1="$(aws ec2 associate-route-table \
  --subnet-id "$PUBLIC_1" \
  --route-table-id "$PUBLIC_RT" \
  --query 'AssociationId' \
  --output text)"

PUB_ASSOC_2="$(aws ec2 associate-route-table \
  --subnet-id "$PUBLIC_2" \
  --route-table-id "$PUBLIC_RT" \
  --query 'AssociationId' \
  --output text)"

APP_ASSOC_1="$(aws ec2 associate-route-table \
  --subnet-id "$APP_1" \
  --route-table-id "$APP_RT" \
  --query 'AssociationId' \
  --output text)"

APP_ASSOC_2="$(aws ec2 associate-route-table \
  --subnet-id "$APP_2" \
  --route-table-id "$APP_RT" \
  --query 'AssociationId' \
  --output text)"

DB_ASSOC_1="$(aws ec2 associate-route-table \
  --subnet-id "$DB_1" \
  --route-table-id "$DB_RT" \
  --query 'AssociationId' \
  --output text)"

DB_ASSOC_2="$(aws ec2 associate-route-table \
  --subnet-id "$DB_2" \
  --route-table-id "$DB_RT" \
  --query 'AssociationId' \
  --output text)"
```

---

# 17. Validate the 3-Tier VPC

## VPC

```bash id="validate-vpc"
aws ec2 describe-vpcs \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].{VpcId:VpcId,Cidr:CidrBlock,State:State,IsDefault:IsDefault}' \
  --output table
```

## Subnets

```bash id="validate-subnets"
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].{SubnetId:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone,PublicIP:MapPublicIpOnLaunch,Tier:Tags[?Key==`Tier`]|[0].Value,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

Expected:

```text id="subnet-expected"
public subnets:
  PublicIP = true

app/db subnets:
  PublicIP = false
```

## Route tables

```bash id="validate-routes"
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[].{RouteTableId:RouteTableId,Routes:Routes[].{Destination:DestinationCidrBlock,Gateway:GatewayId,Nat:NatGatewayId,State:State},Associations:Associations[].SubnetId,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output json
```

Expected:

```text id="route-expected"
public route table:
  0.0.0.0/0 → igw

app route table:
  local route only

db route table:
  local route only
```

---

# 18. Cleanup Lab 4A

Delete in reverse order.

```bash id="cleanup-assoc"
aws ec2 disassociate-route-table --association-id "$PUB_ASSOC_1"
aws ec2 disassociate-route-table --association-id "$PUB_ASSOC_2"
aws ec2 disassociate-route-table --association-id "$APP_ASSOC_1"
aws ec2 disassociate-route-table --association-id "$APP_ASSOC_2"
aws ec2 disassociate-route-table --association-id "$DB_ASSOC_1"
aws ec2 disassociate-route-table --association-id "$DB_ASSOC_2"
```

Delete route tables:

```bash id="cleanup-rt"
aws ec2 delete-route-table --route-table-id "$PUBLIC_RT"
aws ec2 delete-route-table --route-table-id "$APP_RT"
aws ec2 delete-route-table --route-table-id "$DB_RT"
```

Detach/delete IGW:

```bash id="cleanup-igw"
aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

aws ec2 delete-internet-gateway \
  --internet-gateway-id "$IGW_ID"
```

Delete subnets:

```bash id="cleanup-subnets"
for subnet in "$PUBLIC_1" "$PUBLIC_2" "$APP_1" "$APP_2" "$DB_1" "$DB_2"; do
  aws ec2 delete-subnet --subnet-id "$subnet"
done
```

Delete VPC:

```bash id="cleanup-vpc"
aws ec2 delete-vpc --vpc-id "$VPC_ID"
```

Verify:

```bash id="cleanup-verify"
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=aws-masterclass" \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,State:State,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

---

# 19. Production design checklist

Before creating a VPC, answer these:

```text id="checklist"
1. Which region?
2. How many AZs?
3. What VPC CIDR?
4. Will this connect to on-prem later?
5. Does CIDR overlap with other VPCs/on-prem?
6. How many public subnets?
7. How many private app subnets?
8. How many database subnets?
9. Do private app subnets need outbound internet?
10. NAT Gateway or VPC endpoints?
11. One NAT or NAT per AZ?
12. Which resources need public IP?
13. What security group flow?
14. Is SSH required or can SSM be used?
15. Are VPC DNS settings enabled?
16. What tags are mandatory?
17. What is the cleanup plan?
```

---

# 20. Best-practice default answer

For most production web apps:

```text id="best-practice"
Use:
  1 VPC per environment or workload boundary
  at least 2 AZs
  public subnets for ALB/NAT
  private app subnets for application compute
  private db subnets for databases
  security groups referencing security groups
  SSM instead of public SSH
  VPC endpoints for AWS services where useful
  NAT Gateway only when needed
  non-overlapping CIDR for future hybrid
```

---

# 21. Certification angle

## CLF-C02

Know the basic meaning of:

```text id="clf"
VPC
subnet
public subnet
private subnet
security group
NACL
Route 53
CloudFront
```

## SAA-C03

Know design decisions:

```text id="saa"
where ALB should go
where EC2 should go
where RDS should go
how private subnet gets outbound internet
why NAT Gateway is used
when VPC endpoints are better
how to design multi-AZ VPC
how to avoid CIDR overlap
how SG-to-SG references work
```

## DOP-C02

Know operational decisions:

```text id="dop"
private deployment pipelines
SSM access to private EC2
VPC endpoints for CI/CD agents
ALB target health troubleshooting
network route troubleshooting
drift detection for networking
CloudWatch/Flow Logs for network debugging
```

---

# 22. Interview answer

Memorize this:

```text id="interview-answer"
For a production AWS VPC, I usually design a multi-AZ 3-tier network. Public subnets contain internet-facing components such as Application Load Balancers and NAT Gateways. Private app subnets contain EC2, ECS, or EKS workloads. Private database subnets contain RDS, Aurora, or cache services.

A subnet becomes public only when its route table has a default route to an Internet Gateway. Private app subnets usually route outbound traffic through NAT Gateways or use VPC endpoints to access AWS services privately. Database subnets normally have only local VPC routes and no direct internet path.

For security, I use security group chaining: internet traffic reaches the ALB security group, the app security group allows traffic only from the ALB security group, and the database security group allows traffic only from the app security group. I avoid public SSH and prefer Systems Manager Session Manager. For hybrid architecture, I make sure the AWS VPC CIDR does not overlap with on-premise networks.
```

---

# 23. Quick quiz

```text id="quiz"
1. What makes a subnet public?
2. Where should ALB live?
3. Where should EC2 app servers live?
4. Where should RDS live?
5. Why use private database subnets?
6. What does NAT Gateway do?
7. Where should NAT Gateway live?
8. What is a VPC endpoint?
9. Why use VPC endpoints?
10. Why avoid CIDR overlap?
11. What is better: app SG open to 0.0.0.0/0 or app SG open from ALB SG?
12. Why use two AZs?
13. What route should database subnet usually have?
14. What is the difference between NAT and IGW?
15. Why prefer SSM over public SSH?
```

Answers:

```text id="answers"
1. Route table has 0.0.0.0/0 to Internet Gateway.
2. Public subnets across at least two AZs.
3. Private app subnets.
4. Private database subnets.
5. To prevent direct internet exposure.
6. Outbound internet for private subnet resources.
7. Public subnet.
8. Private connection from VPC to supported AWS services.
9. Better security and reduced dependency on NAT/public internet.
10. Hybrid routing breaks or becomes complex with overlapping CIDRs.
11. App SG open only from ALB SG.
12. High availability.
13. Local route only, unless specific private routes are required.
14. IGW gives public internet path; NAT gives private outbound-only internet path.
15. No inbound SSH exposure, IAM-auditable access.
```

---

# Next Lesson

```text id="next"
AWS Lesson 5 — EC2 From Zero to Production:
AMI, instance type, CPU/RAM selection, EBS, key pair, SSH vs SSM, user_data, public/private IP, security groups, server sizing, and cost-safe hosting
```

[1]: https://aws.amazon.com/vpc/faqs/?utm_source=chatgpt.com "Amazon VPC FAQs"
[2]: https://docs.aws.amazon.com/wellarchitected/2025-02-25/framework/reliability.html?utm_source=chatgpt.com "Reliability - AWS Well-Architected Framework"
[3]: https://repost.aws/knowledge-center/nat-gateway-vpc-private-subnet?utm_source=chatgpt.com "Set up NAT gateway for private subnet in Amazon VPC | AWS re:Post"
[4]: https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html?utm_source=chatgpt.com "Access AWS services through AWS PrivateLink - Amazon Virtual Private Cloud"
