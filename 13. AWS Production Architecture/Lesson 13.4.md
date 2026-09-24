# AWS Masterclass — Lesson 3

## Networking From Absolute Zero — IP, CIDR, Ports, DNS, VPC, Subnet, Route Table, IGW, NAT, SG, NACL

Today is a **deep foundation lesson**. If you understand this properly, AWS VPC, EC2, ALB, CloudFront, Route 53, VPN, Direct Connect, hybrid cloud, and migration will become much easier.

Your uploaded architect course lists **networking concepts and controls** as prerequisites and includes AWS VPC, Route 53, CloudFront, Direct Connect, PrivateLink, and Transit Gateway in the architect path . So we will treat AWS networking as a core skill, not a small topic.

---

# 1. What is networking?

Networking means:

```text id="networking"
Computers talking to other computers using addresses, rules, and paths.
```

Example:

```text id="simple-network"
Your laptop
  ↓
Wi-Fi router
  ↓
Internet
  ↓
AWS server
  ↓
Application response comes back
```

Every network communication needs five basic things:

```text id="five-things"
1. Source address
2. Destination address
3. Protocol
4. Port
5. Route/path
```

Example:

```text id="network-example"
Your laptop:
  source IP = 192.168.1.10

Website:
  destination IP = 13.35.20.10

Protocol:
  TCP

Port:
  443

Route:
  laptop → router → ISP → internet → AWS/CloudFront
```

---

# 2. What is an IP address?

An IP address is the address of a device on a network.

Like:

```text id="address-analogy"
House address:
  tells courier where to deliver parcel

IP address:
  tells network where to deliver packet
```

Example IP addresses:

```text id="ip-examples"
192.168.1.10
10.0.1.25
172.31.5.100
8.8.8.8
```

There are two important types for now:

```text id="ip-types"
IPv4:
  32-bit address, common format like 10.0.1.10

IPv6:
  newer, much larger address space, format like 2406:da1a:...
```

In AWS beginner networking, we start with IPv4.

---

# 3. Public IP vs Private IP

## Private IP

Private IP is used inside private networks.

Common private ranges:

```text id="private-ranges"
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
```

Example:

```text id="private-example"
Your home Wi-Fi:
  192.168.1.10

AWS VPC:
  10.0.1.25
```

Private IPs are not directly reachable from the public internet.

## Public IP

Public IP is reachable on the internet.

Example:

```text id="public-example"
EC2 public IP:
  13.x.x.x

CloudFront edge IP:
  public AWS IP

Your home router public IP:
  assigned by ISP
```

Never confuse:

```text id="public-private-never"
Private IP:
  used inside private networks

Public IP:
  used on internet
```

Production idea:

```text id="production-ip"
Database:
  private IP only

Application server:
  usually private IP only

Load balancer:
  public IP/DNS

CloudFront:
  public global edge
```

---

# 4. What is CIDR?

CIDR means:

```text id="cidr"
Classless Inter-Domain Routing
```

Simple meaning:

```text id="cidr-simple"
CIDR defines a range of IP addresses.
```

Example:

```text id="cidr-examples"
10.0.0.0/16
10.0.1.0/24
192.168.1.0/24
```

The number after `/` tells how large the network is.

Very important:

```text id="cidr-rule"
Smaller slash number = bigger network
Bigger slash number = smaller network
```

Examples:

| CIDR  | Approx total IPs | Simple meaning     |
| ----- | ---------------: | ------------------ |
| `/16` |           65,536 | big network        |
| `/20` |            4,096 | medium network     |
| `/24` |              256 | common subnet size |
| `/28` |               16 | very small subnet  |

AWS recommends using private IPv4 ranges for VPC CIDR blocks, and AWS subnet IPv4 CIDRs can range from `/16` to `/28`. AWS also reserves the first four and last IP address in every subnet CIDR block, so a `/24` has 256 total addresses but 251 usable addresses. ([AWS Documentation][1])

Example:

```text id="cidr-breakdown"
VPC:
  10.0.0.0/16

Subnets:
  10.0.1.0/24
  10.0.2.0/24
  10.0.11.0/24
  10.0.12.0/24
```

Think:

```text id="cidr-analogy"
VPC CIDR:
  full building

Subnet CIDR:
  rooms inside building
```

---

# 5. What is a packet?

A packet is a small piece of network data.

When you open a website, your browser does not send one giant block. It sends/receives many packets.

Packet contains:

```text id="packet"
source IP
destination IP
source port
destination port
protocol
data
```

Example:

```text id="packet-example"
source IP:
  your laptop public IP

destination IP:
  CloudFront IP

destination port:
  443

protocol:
  TCP

data:
  HTTPS request
```

---

# 6. What is a protocol?

Protocol means communication rule.

Common protocols:

| Protocol | Used for                               |
| -------- | -------------------------------------- |
| HTTP     | web traffic without encryption         |
| HTTPS    | secure web traffic                     |
| SSH      | Linux remote login                     |
| RDP      | Windows remote desktop                 |
| ICMP     | ping                                   |
| TCP      | reliable connection                    |
| UDP      | faster connection, no full reliability |

Examples:

```text id="protocol-examples"
Website:
  HTTPS over TCP port 443

Linux login:
  SSH over TCP port 22

DNS:
  usually UDP port 53, sometimes TCP 53

Ping:
  ICMP
```

---

# 7. What is a port?

A port is like a door number on a server.

One server can run many services:

```text id="port-example"
EC2 server:
  port 22  = SSH
  port 80  = HTTP
  port 443 = HTTPS
  port 3000 = React/Node dev app
  port 5432 = PostgreSQL
```

Port table:

|  Port | Service    |
| ----: | ---------- |
|    22 | SSH        |
|    80 | HTTP       |
|   443 | HTTPS      |
|  3306 | MySQL      |
|  5432 | PostgreSQL |
|  6379 | Redis      |
| 27017 | MongoDB    |
|    53 | DNS        |

Production rule:

```text id="prod-port-rule"
Expose 80/443 through ALB or CloudFront.
Do not expose database ports publicly.
Avoid public SSH; prefer SSM.
```

---

# 8. What is DNS?

DNS means:

```text id="dns"
Domain Name System
```

DNS converts human-friendly names to IP addresses.

Example:

```text id="dns-example"
app.yourdatascientist.tech
  ↓ DNS
13.35.20.10
```

Why DNS exists:

```text id="dns-why"
Humans remember names.
Computers route using IP addresses.
```

AWS DNS service:

```text id="route53"
Route 53
```

Route 53 supports DNS records such as A, AAAA, CNAME, MX, TXT, and alias records. Alias records are especially important in AWS because they can point to AWS resources such as CloudFront distributions and S3 buckets. ([AWS Documentation][2])

Important records:

| Record | Meaning                    | Example                   |
| ------ | -------------------------- | ------------------------- |
| A      | name → IPv4                | app.example.com → 1.2.3.4 |
| AAAA   | name → IPv6                | app.example.com → IPv6    |
| CNAME  | name → another name        | www → app.example.com     |
| ALIAS  | Route 53 special AWS alias | domain → CloudFront/ALB   |
| NS     | nameservers                | tells who manages DNS     |
| TXT    | text record                | domain verification, SPF  |

---

# 9. What is TTL?

TTL means:

```text id="ttl"
Time To Live
```

It tells DNS resolvers how long they can cache a record.

Example:

```text id="ttl-example"
TTL = 300 seconds
DNS can cache answer for 5 minutes.
```

Practical meaning:

```text id="ttl-practical"
Low TTL:
  faster DNS changes, more DNS queries

High TTL:
  slower DNS changes, fewer DNS queries
```

For migration or domain switch:

```text id="ttl-migration"
Before migration:
  lower TTL to 300 seconds

After stable:
  increase TTL if desired
```

---

# 10. Now AWS Networking Begins: What is VPC?

VPC means:

```text id="vpc"
Virtual Private Cloud
```

Simple meaning:

```text id="vpc-simple"
A VPC is your private network inside AWS.
```

AWS defines Amazon VPC as a service that lets you launch AWS resources in a logically isolated virtual network that you define. You can choose IP ranges, subnets, route tables, gateways, and security settings. ([AWS Documentation][3])

Think:

```text id="vpc-analogy"
AWS Region:
  city

VPC:
  your private land in that city

Subnet:
  rooms/sections inside your land

Route table:
  road map

Security Group:
  server door lock
```

Example VPC:

```text id="vpc-example"
VPC name:
  prod-vpc

CIDR:
  10.0.0.0/16

Region:
  ap-south-1
```

---

# 11. What is a subnet?

A subnet is a smaller network inside a VPC.

Example:

```text id="subnet-example"
VPC:
  10.0.0.0/16

Public subnet 1:
  10.0.1.0/24

Public subnet 2:
  10.0.2.0/24

Private app subnet 1:
  10.0.11.0/24

Private app subnet 2:
  10.0.12.0/24
```

AWS says a subnet is a range of IP addresses in your VPC, and every subnet belongs to one Availability Zone. Public subnets have a direct route to an internet gateway, while resources in private subnets need a NAT device for outbound public internet access. ([AWS Documentation][4])

Important:

```text id="subnet-az"
One subnet lives in one AZ only.
A subnet cannot span multiple AZs.
```

Production design uses multiple subnets across multiple AZs:

```text id="multi-az"
ap-south-1a:
  public subnet
  private app subnet
  private database subnet

ap-south-1b:
  public subnet
  private app subnet
  private database subnet
```

---

# 12. Public subnet vs private subnet

This is one of the most important AWS concepts.

## Public subnet

A subnet is public if:

```text id="public-subnet"
Its route table has a route:
0.0.0.0/0 → Internet Gateway
```

Usually placed here:

```text id="public-subnet-resources"
Application Load Balancer
NAT Gateway
Bastion host if used
public-facing EC2 only in simple labs
```

## Private subnet

A subnet is private if:

```text id="private-subnet"
It does not have direct route to Internet Gateway.
```

Usually placed here:

```text id="private-resources"
application servers
containers
databases
internal services
cache
workers
```

Private subnet can still access internet **outbound** if it routes through NAT Gateway.

Never forget:

```text id="key-public-private"
Public subnet:
  route to Internet Gateway

Private subnet:
  no direct route to Internet Gateway
```

A subnet is not public just because its name is “public.” It is public because of its route table.

---

# 13. What is a route table?

A route table is the network map for a subnet.

AWS says each route table contains routes that decide where subnet or gateway traffic is directed; each route has a destination CIDR/prefix list and a target such as an internet gateway, NAT gateway, VPC peering connection, or VPN connection. ([AWS Documentation][5])

Example route table:

```text id="route-table-example"
Destination        Target
10.0.0.0/16        local
0.0.0.0/0          igw-123456
```

Meaning:

```text id="route-meaning"
10.0.0.0/16 → local:
  traffic inside VPC stays inside VPC

0.0.0.0/0 → Internet Gateway:
  all other IPv4 traffic goes to internet
```

`0.0.0.0/0` means:

```text id="default-route"
any IPv4 address
```

So:

```text id="route-rule"
0.0.0.0/0 → igw:
  public subnet

0.0.0.0/0 → nat:
  private subnet with outbound internet

no 0.0.0.0/0:
  isolated private subnet
```

---

# 14. What is Internet Gateway?

Internet Gateway, or IGW, connects a VPC to the public internet.

Think:

```text id="igw-analogy"
Internet Gateway = main gate from your VPC to the internet
```

For public internet access, you need:

```text id="igw-requirements"
1. Internet Gateway attached to VPC
2. Subnet route table has 0.0.0.0/0 → IGW
3. Resource has public IP
4. Security Group allows traffic
5. NACL allows traffic
```

All five matter.

If one is missing, connection fails.

---

# 15. What is NAT Gateway?

NAT Gateway lets private subnet resources access the internet outbound without allowing inbound internet connections.

Example:

```text id="nat-flow"
Private EC2
  ↓
NAT Gateway in public subnet
  ↓
Internet Gateway
  ↓
Internet
```

Use case:

```text id="nat-use"
Private EC2 needs:
  apt update
  yum update
  download packages
  call external APIs

But internet should not initiate inbound connection to private EC2.
```

AWS documentation describes NAT devices as enabling instances in private subnets to connect to the internet while preventing the internet from initiating connections to those instances. ([AWS Documentation][6])

Cost warning:

```text id="nat-cost"
NAT Gateway has hourly and data processing charges.
For beginner labs, avoid NAT Gateway unless needed.
Use VPC endpoints where possible for AWS service access.
```

---

# 16. What is Security Group?

Security Group is a virtual firewall attached to ENIs/resources such as EC2, ALB, and RDS.

Think:

```text id="sg-analogy"
Security Group = door lock on the server/resource
```

Important features:

```text id="sg-features"
Stateful
Allow rules only
Attached to resource/network interface
Controls inbound and outbound traffic
```

Stateful means:

```text id="stateful"
If inbound request is allowed,
the response is automatically allowed back.
```

Example EC2 web server SG:

```text id="web-sg"
Inbound:
  TCP 80 from ALB security group

Outbound:
  all traffic allowed
```

Example ALB SG:

```text id="alb-sg"
Inbound:
  TCP 80 from 0.0.0.0/0
  TCP 443 from 0.0.0.0/0

Outbound:
  TCP 80 to EC2 security group
```

AWS describes security groups as virtual firewalls that control inbound and outbound traffic for resources; security groups are stateful, so return traffic for an allowed request is allowed regardless of outbound rules. ([AWS Documentation][6])

---

# 17. What is NACL?

NACL means:

```text id="nacl"
Network Access Control List
```

It is a subnet-level firewall.

Think:

```text id="nacl-analogy"
NACL = gate security for the whole subnet
```

Important features:

```text id="nacl-features"
Stateless
Allow and deny rules
Applies at subnet level
Rules processed by number
Need inbound and outbound rules separately
```

Stateless means:

```text id="stateless"
If inbound traffic is allowed,
response traffic still needs outbound rule.
```

Security Group vs NACL:

| Feature        | Security Group        | NACL                       |
| -------------- | --------------------- | -------------------------- |
| Level          | Resource/ENI          | Subnet                     |
| Type           | Stateful              | Stateless                  |
| Rules          | Allow only            | Allow and deny             |
| Return traffic | Automatically allowed | Must be explicitly allowed |
| Common use     | Main firewall         | Extra subnet guardrail     |

For most beginner and intermediate AWS work:

```text id="sg-nacl-practical"
Use Security Groups carefully.
Keep NACL simple unless you need subnet-level deny rules.
```

---

# 18. Full request flow: user to EC2 through ALB

Example:

```text id="flow-title"
User opens:
http://app.example.com
```

Flow:

```text id="alb-flow"
1. User browser resolves DNS.
2. DNS returns ALB or CloudFront address.
3. Request goes to public ALB.
4. ALB security group allows port 80/443.
5. ALB chooses healthy target from target group.
6. EC2 security group allows traffic from ALB SG.
7. EC2 app responds.
8. Response goes back through ALB to user.
```

Architecture:

```text id="architecture"
Internet
  ↓
Public ALB
  ↓
EC2 in private subnet
  ↓
Database in private database subnet
```

This is the standard production pattern.

---

# 19. Full request flow: private EC2 downloading updates

Example:

```text id="private-update"
Private EC2 runs:
sudo apt update
```

Flow:

```text id="nat-flow-full"
1. EC2 sends request to internet package repository.
2. Private subnet route table sends 0.0.0.0/0 to NAT Gateway.
3. NAT Gateway lives in public subnet.
4. NAT Gateway sends traffic to Internet Gateway.
5. Response comes back to NAT Gateway.
6. NAT Gateway forwards response to private EC2.
```

No inbound internet access to private EC2.

---

# 20. VPC endpoint preview

A VPC endpoint lets private resources reach AWS services privately without going through public internet, IGW, or NAT for supported services.

AWS says VPC endpoints let you connect privately to AWS services without using an internet gateway or NAT device. ([AWS Documentation][3])

Example:

```text id="endpoint-example"
Private EC2
  ↓
VPC Endpoint
  ↓
S3
```

This is useful because:

```text id="endpoint-benefits"
better security
reduced NAT Gateway cost
private AWS service access
```

We will go deep later.

---

# 21. Production VPC design pattern

A good basic production VPC:

```text id="prod-vpc"
VPC:
  10.0.0.0/16

AZ ap-south-1a:
  public subnet       10.0.1.0/24
  private app subnet  10.0.11.0/24
  private db subnet   10.0.21.0/24

AZ ap-south-1b:
  public subnet       10.0.2.0/24
  private app subnet  10.0.12.0/24
  private db subnet   10.0.22.0/24
```

Resource placement:

```text id="placement"
Public subnets:
  ALB
  NAT Gateway

Private app subnets:
  EC2
  ECS tasks
  EKS worker nodes

Private DB subnets:
  RDS
  ElastiCache
```

Why two AZs?

```text id="two-az"
If one AZ fails,
the other AZ can still serve traffic.
```

---

# 22. Common VPC mistakes

## Mistake 1 — Thinking subnet name decides public/private

Wrong:

```text id="wrong-name"
Subnet name = public-subnet
Therefore it is public.
```

Correct:

```text id="correct-route"
Route table decides public/private.
```

---

## Mistake 2 — EC2 has public IP but no internet route

To access EC2 from internet, you need:

```text id="public-access-needs"
public IP
route to IGW
security group allow
NACL allow
OS/app listening
```

---

## Mistake 3 — Private subnet without NAT or endpoint

Private EC2 cannot download packages if there is no outbound path.

Fix:

```text id="private-fix"
NAT Gateway
or VPC endpoints
or pre-baked AMI
```

---

## Mistake 4 — Opening SSH to world

Bad:

```text id="bad-ssh"
TCP 22 from 0.0.0.0/0
```

Better:

```text id="better-ssh"
Use SSM Session Manager
or restricted VPN/office CIDR
```

---

## Mistake 5 — Putting database in public subnet

Bad:

```text id="bad-db"
RDS publicly accessible
public subnet
database port from internet
```

Good:

```text id="good-db"
RDS in private DB subnets
no public access
app SG allowed to DB SG
```

---

# 23. Hands-On Lab 3A — No-Cost Custom VPC Skeleton

This lab creates a VPC, two subnets, an Internet Gateway, and a route table. It does **not** create EC2, NAT Gateway, ALB, or public IPs.

Cost:

```text id="cost"
VPC, subnet, route table, and internet gateway do not have hourly charges.
Do not create NAT Gateway in this lab.
```

Region:

```text id="region"
ap-south-1
```

## Step 1 — Set region

```bash id="set-region"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
```

Check identity:

```bash id="identity"
aws sts get-caller-identity
```

---

## Step 2 — Create VPC

```bash id="create-vpc"
VPC_ID="$(aws ec2 create-vpc \
  --cidr-block 10.50.0.0/16 \
  --query 'Vpc.VpcId' \
  --output text)"

echo "$VPC_ID"
```

Tag it:

```bash id="tag-vpc"
aws ec2 create-tags \
  --resources "$VPC_ID" \
  --tags Key=Name,Value=aws-masterclass-vpc Key=Project,Value=aws-masterclass
```

Enable DNS support and hostnames:

```bash id="vpc-dns"
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-support "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}"
```

---

## Step 3 — Create two public subnets

Get AZ names:

```bash id="azs"
aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[0:2].ZoneName' \
  --output text
```

Store them:

```bash id="store-azs"
AZ1="$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text)"
AZ2="$(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text)"

echo "$AZ1"
echo "$AZ2"
```

Create subnets:

```bash id="create-subnets"
PUBLIC_SUBNET_1="$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.50.1.0/24 \
  --availability-zone "$AZ1" \
  --query 'Subnet.SubnetId' \
  --output text)"

PUBLIC_SUBNET_2="$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.50.2.0/24 \
  --availability-zone "$AZ2" \
  --query 'Subnet.SubnetId' \
  --output text)"

echo "$PUBLIC_SUBNET_1"
echo "$PUBLIC_SUBNET_2"
```

Tag them:

```bash id="tag-subnets"
aws ec2 create-tags \
  --resources "$PUBLIC_SUBNET_1" \
  --tags Key=Name,Value=aws-masterclass-public-1 Key=Project,Value=aws-masterclass

aws ec2 create-tags \
  --resources "$PUBLIC_SUBNET_2" \
  --tags Key=Name,Value=aws-masterclass-public-2 Key=Project,Value=aws-masterclass
```

Enable auto-assign public IPv4 for this public subnet lab:

```bash id="auto-public-ip"
aws ec2 modify-subnet-attribute \
  --subnet-id "$PUBLIC_SUBNET_1" \
  --map-public-ip-on-launch

aws ec2 modify-subnet-attribute \
  --subnet-id "$PUBLIC_SUBNET_2" \
  --map-public-ip-on-launch
```

---

## Step 4 — Create Internet Gateway

```bash id="create-igw"
IGW_ID="$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)"

echo "$IGW_ID"
```

Tag:

```bash id="tag-igw"
aws ec2 create-tags \
  --resources "$IGW_ID" \
  --tags Key=Name,Value=aws-masterclass-igw Key=Project,Value=aws-masterclass
```

Attach to VPC:

```bash id="attach-igw"
aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"
```

---

## Step 5 — Create public route table

```bash id="create-rt"
PUBLIC_RT_ID="$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text)"

echo "$PUBLIC_RT_ID"
```

Tag:

```bash id="tag-rt"
aws ec2 create-tags \
  --resources "$PUBLIC_RT_ID" \
  --tags Key=Name,Value=aws-masterclass-public-rt Key=Project,Value=aws-masterclass
```

Add internet route:

```bash id="create-route"
aws ec2 create-route \
  --route-table-id "$PUBLIC_RT_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID"
```

Associate route table with subnets:

```bash id="associate-rt"
ASSOC_1="$(aws ec2 associate-route-table \
  --subnet-id "$PUBLIC_SUBNET_1" \
  --route-table-id "$PUBLIC_RT_ID" \
  --query 'AssociationId' \
  --output text)"

ASSOC_2="$(aws ec2 associate-route-table \
  --subnet-id "$PUBLIC_SUBNET_2" \
  --route-table-id "$PUBLIC_RT_ID" \
  --query 'AssociationId' \
  --output text)"

echo "$ASSOC_1"
echo "$ASSOC_2"
```

Now these are public subnets because their route table has:

```text id="public-route"
0.0.0.0/0 → Internet Gateway
```

---

# 24. Validate the VPC

```bash id="validate-vpc"
aws ec2 describe-vpcs \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,State:State,IsDefault:IsDefault}' \
  --output table
```

Validate subnets:

```bash id="validate-subnets"
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].{SubnetId:SubnetId,CidrBlock:CidrBlock,AZ:AvailabilityZone,PublicIpOnLaunch:MapPublicIpOnLaunch}' \
  --output table
```

Validate route table:

```bash id="validate-routes"
aws ec2 describe-route-tables \
  --route-table-ids "$PUBLIC_RT_ID" \
  --query 'RouteTables[0].Routes[].{Destination:DestinationCidrBlock,Target:GatewayId,State:State}' \
  --output table
```

You should see:

```text id="expected-routes"
10.50.0.0/16 → local
0.0.0.0/0   → igw-...
```

---

# 25. Cleanup Lab 3A

Cleanup order matters.

Disassociate route table:

```bash id="cleanup-disassociate"
aws ec2 disassociate-route-table --association-id "$ASSOC_1"
aws ec2 disassociate-route-table --association-id "$ASSOC_2"
```

Delete route table:

```bash id="cleanup-rt"
aws ec2 delete-route-table \
  --route-table-id "$PUBLIC_RT_ID"
```

Detach and delete internet gateway:

```bash id="cleanup-igw"
aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID"

aws ec2 delete-internet-gateway \
  --internet-gateway-id "$IGW_ID"
```

Delete subnets:

```bash id="cleanup-subnets"
aws ec2 delete-subnet --subnet-id "$PUBLIC_SUBNET_1"
aws ec2 delete-subnet --subnet-id "$PUBLIC_SUBNET_2"
```

Delete VPC:

```bash id="cleanup-vpc"
aws ec2 delete-vpc --vpc-id "$VPC_ID"
```

Verify:

```bash id="cleanup-verify"
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=aws-masterclass" \
  --query 'Vpcs[].{VpcId:VpcId,CidrBlock:CidrBlock,State:State}' \
  --output table
```

---

# 26. Troubleshooting Lab 3A

## Error: `DependencyViolation`

Meaning:

```text id="dependency"
You are trying to delete a resource that is still attached to another resource.
```

Example:

```text id="dependency-example"
Cannot delete VPC because subnets still exist.
Cannot delete IGW because it is still attached.
Cannot delete route table because association exists.
```

Fix:

```text id="dependency-fix"
Delete in reverse order:
route associations → route table → IGW detach/delete → subnets → VPC
```

---

## Error: cannot create route to IGW

Check:

```bash id="igw-check"
aws ec2 describe-internet-gateways \
  --internet-gateway-ids "$IGW_ID"
```

Make sure IGW is attached to the VPC.

---

## Error: subnet not public

Check route table association:

```bash id="route-association-check"
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$PUBLIC_SUBNET_1" \
  --output table
```

A subnet is public only if its effective route table has:

```text id="route-public"
0.0.0.0/0 → Internet Gateway
```

---

# 27. Production mental model: traffic decision checklist

When traffic fails, ask in this order:

```text id="traffic-checklist"
1. Does DNS resolve?
2. Does route table have path?
3. Is source/destination IP correct?
4. Is security group allowing traffic?
5. Is NACL allowing traffic both ways?
6. Is the server listening on the port?
7. Is the application healthy?
8. Is there a load balancer health check issue?
9. Is there a firewall inside the OS?
10. Is there TLS/certificate issue?
```

For AWS, most beginner issues are:

```text id="common-failures"
wrong route table
missing public IP
security group blocked
NACL blocked
wrong subnet
app not listening
wrong health check path
wrong region
```

---

# 28. Certification angle

## CLF-C02

Know:

```text id="clf"
Region
Availability Zone
Edge Location
VPC
Security Group
CloudFront
Route 53
basic networking security
```

## SAA-C03

Know deeply:

```text id="saa"
multi-AZ VPC design
public/private subnet design
route tables
NAT Gateway
VPC endpoints
ALB placement
RDS private subnet placement
SG vs NACL
hybrid connectivity
Route 53 routing
CloudFront origin patterns
```

## DOP-C02

Know operationally:

```text id="dop"
network troubleshooting
private deployments
SSM instead of SSH
VPC endpoints for automation
CloudWatch VPC metrics/logs
ALB target health
deployment in private subnets
hybrid CI/CD runners
```

---

# 29. Interview answer

Memorize this:

```text id="interview-answer"
A VPC is a logically isolated private network inside AWS where we define IP ranges, subnets, route tables, gateways, and security controls. A subnet is a smaller IP range inside a VPC and belongs to one Availability Zone. A subnet becomes public when its route table has a default route to an Internet Gateway; otherwise it is private or isolated.

In production, I usually place ALBs and NAT Gateways in public subnets, application servers or containers in private app subnets, and databases in private database subnets. Route tables control traffic direction, security groups act as stateful firewalls at the resource level, and NACLs act as stateless firewalls at the subnet level.

For outbound internet access from private subnets, I use NAT Gateway or VPC endpoints depending on the requirement. For inbound user traffic, I prefer CloudFront and ALB rather than exposing EC2 directly. For administration, I prefer SSM Session Manager instead of public SSH.
```

---

# 30. Quick quiz

Answer mentally:

```text id="quiz"
1. What is an IP address?
2. What is CIDR?
3. Is /16 bigger or /24 bigger?
4. What is a private IP?
5. What is a public IP?
6. What is a port?
7. What is DNS?
8. What is a VPC?
9. What is a subnet?
10. What makes a subnet public?
11. What is a route table?
12. What is 0.0.0.0/0?
13. What is an Internet Gateway?
14. What is NAT Gateway?
15. What is Security Group?
16. What is NACL?
17. Which one is stateful: SG or NACL?
18. Where should databases live?
19. Where should ALB live?
20. Why use two AZs?
```

Answers:

```text id="answers"
1. Address of a device on network.
2. IP range notation.
3. /16 is bigger.
4. Internal network IP.
5. Internet-routable IP.
6. Door number for a service.
7. Name-to-IP system.
8. Private network in AWS.
9. Smaller IP range inside VPC.
10. Route table has 0.0.0.0/0 to Internet Gateway.
11. Routing rules for subnet/gateway traffic.
12. Any IPv4 destination.
13. VPC component for internet connectivity.
14. Outbound internet path for private subnet resources.
15. Stateful firewall at resource level.
16. Stateless firewall at subnet level.
17. Security Group.
18. Private database subnets.
19. Public subnets.
20. High availability.
```

---

# Next Lesson

```text id="next"
AWS Lesson 4 — VPC Design In Depth:
public/private/database subnets, NAT Gateway, VPC endpoints, route table strategy, and production 3-tier architecture
```

We will design a real production VPC like an AWS architect.

[1]: https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html?utm_source=chatgpt.com "Subnet CIDR blocks - Amazon Virtual Private Cloud"
[2]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html?utm_source=chatgpt.com "Supported DNS record types - Amazon Route 53"
[3]: https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html?utm_source=chatgpt.com "What is Amazon VPC? - Amazon Virtual Private Cloud"
[4]: https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html?utm_source=chatgpt.com "Subnets for your VPC - Amazon Virtual Private Cloud"
[5]: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html?utm_source=chatgpt.com "Configure route tables - Amazon Virtual Private Cloud"
[6]: https://docs.aws.amazon.com/vpc/latest/userguide/how-it-works.html?linkId=82366793&sc_campaign=Docs&sc_channel=sm&sc_content=Docs&sc_country=Global&sc_outcome=awareness&sc_publisher=LINKEDIN&trk=Docs_LINKEDIN&utm_source=chatgpt.com "How Amazon VPC works - Amazon Virtual Private Cloud"
