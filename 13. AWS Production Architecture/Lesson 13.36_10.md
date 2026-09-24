# Lesson 36 — AWS Hybrid Cloud

# Part 10: Complete Enterprise Hybrid-Cloud Hands-On Capstone

This is the **final build section** of Lesson 36.

After this, only **Part 11 — final revision, architecture decision matrix, interview/exam scenarios, and never-forget sheet** remains.

For the lab, we'll use:

```text
Region: ap-south-1
```

and construct a reproducible simulated enterprise environment.

---

# 36.560 What are we building?

Our target:

```text
                         SIMULATED ON-PREM
                           10.10.0.0/16

                    ┌─────────────────────┐
                    │ Linux VPN Router    │
                    │ StrongSwan + FRR    │
                    │ ASN 65000           │
                    └──────────┬──────────┘
                               │
                          IPsec + BGP
                               │
                               ▼
                    ┌────────────────────┐
                    │ Transit Gateway    │
                    │ enterprise-tgw     │
                    └─────────┬──────────┘
                              │
          ┌───────────────────┼────────────────────┐
          │                   │                    │
          ▼                   ▼                    ▼
      PROD VPC           SHARED VPC          SECURITY VPC
    10.64.0.0/16       10.72.0.0/16        10.73.0.0/16
          │                   │                    │
       App EC2           Route 53 Resolver      Inspection
                              │
                              ▼
                         Hybrid DNS
```

A TGW VPC attachment uses selected subnets as the entry/exit points for TGW traffic, and TGW attachments can be associated with one route table while propagating routes to multiple route tables. Blackhole routes can explicitly discard matching traffic. ([AWS Documentation][1])

---

# 36.561 Important lab-vs-production distinction

Our "corporate data center" will actually be another AWS VPC containing a Linux VPN router.

That's intentional.

It lets us reproduce:

```text
Customer Gateway
IPsec
BGP
TGW
route propagation
return routing
failure scenarios
```

without requiring you to own:

```text
physical data-center hardware
carrier circuit
colocation rack
Direct Connect cross-connect
```

The Site-to-Site VPN customer gateway resource represents your VPN device; the device itself must still be configured separately, and AWS strongly recommends configuring both VPN tunnels. ([AWS Documentation][2])

At the end we'll show exactly where:

```text
Transit VIF → DXGW → TGW
```

replaces the simulated transport in production.

---

# 36.562 Cost warning before we touch anything

This capstone contains **billable networking resources**, particularly Transit Gateway attachments, Site-to-Site VPN, Resolver endpoint ENIs, EC2, logging destinations, and traffic processing. Transit Gateway and VPN attachments have hourly/data-processing charges, and Route 53 Resolver endpoints require multiple endpoint IPs and are billed for endpoint capacity/query processing. ([Amazon Web Services, Inc.][3])

So our rule is:

```text
BUILD
  ↓
TEST
  ↓
BREAK
  ↓
FIX
  ↓
DESTROY
```

Do **not** leave this entire lab running for weeks.

---

# 36.563 Repository

Create:

```bash
mkdir -p ~/aws-hybrid-capstone
cd ~/aws-hybrid-capstone
```

Structure:

```text
aws-hybrid-capstone/
│
├── versions.tf
├── providers.tf
├── variables.tf
├── locals.tf
│
├── vpc-prod.tf
├── vpc-shared.tf
├── vpc-security.tf
├── vpc-onprem.tf
│
├── transit-gateway.tf
├── tgw-routes.tf
│
├── vpn.tf
├── resolver.tf
├── flow-logs.tf
│
├── compute.tf
├── outputs.tf
└── terraform.tfvars
```

We're using separate files for readability.

Terraform still treats all `.tf` files in the directory as one root module.

---

# 36.564 Terraform version/provider

`versions.tf`

```hcl
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

Then:

`providers.tf`

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "hybrid-network-capstone"
      ManagedBy = "terraform"
      Course    = "aws-production-architecture"
    }
  }
}
```

---

# 36.565 Variables

`variables.tf`

```hcl
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "key_name" {
  type = string
}

variable "admin_cidr" {
  type        = string
  description = "Your public IP in CIDR format for SSH, e.g. 1.2.3.4/32"
}
```

`terraform.tfvars`

```hcl
aws_region = "ap-south-1"

key_name = "vivek-temp"

admin_cidr = "YOUR_PUBLIC_IP/32"
```

Never use:

```text
0.0.0.0/0
```

for SSH simply because it's easier.

---

# 36.566 IP plan

Our entire network:

| Network                | CIDR           |
| ---------------------- | -------------- |
| Simulated corporate DC | `10.10.0.0/16` |
| Prod                   | `10.64.0.0/16` |
| Shared                 | `10.72.0.0/16` |
| Security               | `10.73.0.0/16` |

Subnets:

```text
ON-PREM

VPN public subnet
10.10.1.0/24

Corporate workload subnet
10.10.10.0/24


PROD

App-A
10.64.10.0/24

TGW-A
10.64.250.0/28

TGW-B
10.64.250.16/28


SHARED

Resolver-A
10.72.10.0/24

Resolver-B
10.72.20.0/24

TGW-A
10.72.250.0/28

TGW-B
10.72.250.16/28
```

Non-overlapping CIDRs are essential once networks participate in routed TGW/hybrid connectivity. TGW does not provide normal propagation between overlapping VPC CIDRs. ([AWS Documentation][4])

---

# 36.567 Locals

`locals.tf`

```hcl
locals {
  onprem_cidr   = "10.10.0.0/16"
  prod_cidr     = "10.64.0.0/16"
  shared_cidr   = "10.72.0.0/16"
  security_cidr = "10.73.0.0/16"

  onprem_asn = 65000
}
```

---

# 36.568 Build Prod VPC

`vpc-prod.tf`

```hcl
resource "aws_vpc" "prod" {
  cidr_block           = local.prod_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "hybrid-prod-vpc"
  }
}

resource "aws_subnet" "prod_app" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.64.10.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "prod-app-a"
  }
}

resource "aws_subnet" "prod_tgw_a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.64.250.0/28"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "prod-tgw-a"
  }
}

resource "aws_subnet" "prod_tgw_b" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.64.250.16/28"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "prod-tgw-b"
  }
}

resource "aws_route_table" "prod_private" {
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "prod-private-rt"
  }
}

resource "aws_route_table_association" "prod_app" {
  subnet_id      = aws_subnet.prod_app.id
  route_table_id = aws_route_table.prod_private.id
}
```

---

# 36.569 Shared Services VPC

`vpc-shared.tf`

```hcl
resource "aws_vpc" "shared" {
  cidr_block           = local.shared_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "hybrid-shared-vpc"
  }
}

resource "aws_subnet" "resolver_a" {
  vpc_id            = aws_vpc.shared.id
  cidr_block        = "10.72.10.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "resolver-a"
  }
}

resource "aws_subnet" "resolver_b" {
  vpc_id            = aws_vpc.shared.id
  cidr_block        = "10.72.20.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "resolver-b"
  }
}

resource "aws_subnet" "shared_tgw_a" {
  vpc_id            = aws_vpc.shared.id
  cidr_block        = "10.72.250.0/28"
  availability_zone = "${var.aws_region}a"
}

resource "aws_subnet" "shared_tgw_b" {
  vpc_id            = aws_vpc.shared.id
  cidr_block        = "10.72.250.16/28"
  availability_zone = "${var.aws_region}b"
}
```

Route 53 VPC Resolver inbound endpoints accept DNS queries coming into AWS, while outbound endpoints forward selected queries from VPCs toward DNS servers in connected networks. ([AWS Documentation][5])

---

# 36.570 Transit Gateway

`transit-gateway.tf`

```hcl
resource "aws_ec2_transit_gateway" "main" {
  description = "Hybrid enterprise capstone TGW"

  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  dns_support = "enable"

  tags = {
    Name = "hybrid-enterprise-tgw"
  }
}
```

Then route tables:

```hcl
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "PROD-RT"
  }
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "SHARED-RT"
  }
}

resource "aws_ec2_transit_gateway_route_table" "hybrid" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "HYBRID-RT"
  }
}
```

TGW supports multiple route tables specifically so subsets of attachments can be isolated, and an attachment has one associated route table while it may propagate to more than one route table. ([AWS Documentation][1])

---

# 36.571 Attach Prod

```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  vpc_id             = aws_vpc.prod.id
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  subnet_ids = [
    aws_subnet.prod_tgw_a.id,
    aws_subnet.prod_tgw_b.id
  ]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "prod-attachment"
  }
}
```

This resource is directly supported by the current HashiCorp AWS provider. ([Terraform Registry][6])

Associate:

```hcl
resource "aws_ec2_transit_gateway_route_table_association" "prod" {
  transit_gateway_attachment_id =
    aws_ec2_transit_gateway_vpc_attachment.prod.id

  transit_gateway_route_table_id =
    aws_ec2_transit_gateway_route_table.prod.id
}
```

Memory check:

```text
Prod traffic enters TGW
        ↓
Association
        ↓
PROD-RT
```

---

# 36.572 Attach Shared

```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "shared" {
  vpc_id             = aws_vpc.shared.id
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  subnet_ids = [
    aws_subnet.shared_tgw_a.id,
    aws_subnet.shared_tgw_b.id
  ]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "shared-attachment"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "shared" {
  transit_gateway_attachment_id =
    aws_ec2_transit_gateway_vpc_attachment.shared.id

  transit_gateway_route_table_id =
    aws_ec2_transit_gateway_route_table.shared.id
}
```

---

# 36.573 Prod should learn Shared

```hcl
resource "aws_ec2_transit_gateway_route_table_propagation" "shared_to_prod" {
  transit_gateway_attachment_id =
    aws_ec2_transit_gateway_vpc_attachment.shared.id

  transit_gateway_route_table_id =
    aws_ec2_transit_gateway_route_table.prod.id
}
```

Shared should know Prod for the return path:

```hcl
resource "aws_ec2_transit_gateway_route_table_propagation" "prod_to_shared" {
  transit_gateway_attachment_id =
    aws_ec2_transit_gateway_vpc_attachment.prod.id

  transit_gateway_route_table_id =
    aws_ec2_transit_gateway_route_table.shared.id
}
```

Result:

```text
PROD-RT

10.72.0.0/16
    ↓
Shared attachment


SHARED-RT

10.64.0.0/16
    ↓
Prod attachment
```

---

# 36.574 VPC routes

Prod still needs:

```hcl
resource "aws_route" "prod_to_shared" {
  route_table_id         = aws_route_table.prod_private.id
  destination_cidr_block = local.shared_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}
```

Eventually also:

```hcl
resource "aws_route" "prod_to_onprem" {
  route_table_id         = aws_route_table.prod_private.id
  destination_cidr_block = local.onprem_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}
```

This distinction remains fundamental:

```text
VPC RT:
Where do I send the packet when leaving my VPC?

TGW RT:
Which attachment should TGW send it through?
```

---

# 36.575 Simulated corporate data center

Now build:

```text
10.10.0.0/16
```

with:

```text
VPN Router
+
Corporate server
```

The router needs Internet reachability because the normal Site-to-Site VPN customer gateway uses an externally reachable customer-gateway endpoint; AWS Site-to-Site VPN can terminate on Transit Gateway. ([AWS Documentation][7])

`vpc-onprem.tf`

```hcl
resource "aws_vpc" "onprem" {
  cidr_block           = local.onprem_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "simulated-corporate-dc"
  }
}

resource "aws_internet_gateway" "onprem" {
  vpc_id = aws_vpc.onprem.id
}

resource "aws_subnet" "onprem_vpn" {
  vpc_id                  = aws_vpc.onprem.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "onprem_workload" {
  vpc_id            = aws_vpc.onprem.id
  cidr_block        = "10.10.10.0/24"
  availability_zone = "${var.aws_region}a"
}
```

---

# 36.576 Internet route for the VPN router

```hcl
resource "aws_route_table" "onprem_public" {
  vpc_id = aws_vpc.onprem.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.onprem.id
  }
}

resource "aws_route_table_association" "onprem_vpn" {
  subnet_id      = aws_subnet.onprem_vpn.id
  route_table_id = aws_route_table.onprem_public.id
}
```

---

# 36.577 VPN router EC2

We want:

```text
Ubuntu
+
StrongSwan
+
FRRouting
```

and critically:

```text
source/destination check = disabled
```

because this instance acts as a router for other machines.

Conceptually:

```hcl
resource "aws_instance" "vpn_router" {
  ami           = var.ubuntu_ami
  instance_type = "t3.small"

  subnet_id = aws_subnet.onprem_vpn.id

  source_dest_check = false

  key_name = var.key_name

  # security group omitted here for brevity

  tags = {
    Name = "simulated-onprem-vpn-router"
  }
}
```

Then Elastic IP:

```hcl
resource "aws_eip" "vpn_router" {
  domain = "vpc"

  tags = {
    Name = "vpn-router-eip"
  }
}

resource "aws_eip_association" "vpn_router" {
  instance_id   = aws_instance.vpn_router.id
  allocation_id = aws_eip.vpn_router.id
}
```

---

# 36.578 Security group for VPN router

Conceptually we need the AWS VPN endpoints to reach:

```text
UDP 500
UDP 4500
```

and SSH only from your administrative IP.

Example:

```hcl
resource "aws_security_group" "vpn_router" {
  name   = "vpn-router"
  vpc_id = aws_vpc.onprem.id

  ingress {
    description = "SSH admin"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "IKE"
    protocol    = "udp"
    from_port   = 500
    to_port     = 500
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "IPsec NAT-T"
    protocol    = "udp"
    from_port   = 4500
    to_port     = 4500
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

For a production customer gateway, you'd scope rules according to the exact device/network design rather than blindly copying a lab SG.

---

# 36.579 Enable Linux routing

SSH into the VPN router:

```bash
ssh -i vivek-temp.pem ubuntu@<VPN_ROUTER_EIP>
```

Install:

```bash
sudo apt update

sudo apt install -y \
  strongswan \
  strongswan-pki \
  frr \
  tcpdump \
  traceroute \
  mtr-tiny \
  net-tools
```

Enable IPv4 forwarding:

```bash
echo 'net.ipv4.ip_forward=1' \
  | sudo tee /etc/sysctl.d/99-vpn-router.conf

sudo sysctl --system
```

Verify:

```bash
sysctl net.ipv4.ip_forward
```

Expected:

```text
net.ipv4.ip_forward = 1
```

---

# 36.580 Now create the AWS Customer Gateway

`vpn.tf`

```hcl
resource "aws_customer_gateway" "onprem" {
  bgp_asn    = local.onprem_asn
  ip_address = aws_eip.vpn_router.public_ip
  type       = "ipsec.1"

  tags = {
    Name = "simulated-onprem-cgw"
  }
}
```

Remember:

```text
aws_customer_gateway
```

does not install anything on Linux.

It tells AWS:

```text
Remote VPN peer:
<public IP>

Remote ASN:
65000
```

AWS explicitly distinguishes the Customer Gateway AWS resource from the actual customer gateway device. ([AWS Documentation][2])

---

# 36.581 Create VPN → TGW

```hcl
resource "aws_vpn_connection" "onprem" {
  customer_gateway_id = aws_customer_gateway.onprem.id
  transit_gateway_id  = aws_ec2_transit_gateway.main.id

  type = "ipsec.1"

  static_routes_only = false

  tags = {
    Name = "simulated-onprem-to-tgw"
  }
}
```

The current HashiCorp AWS provider supports managing `aws_vpn_connection`, and AWS supports creating Site-to-Site VPNs targeted at a Transit Gateway. ([Terraform Registry][8])

Because:

```text
static_routes_only = false
```

we're preparing for:

```text
BGP
```

rather than static VPN routing.

---

# 36.582 Get the VPN tunnel configuration

After:

```bash
terraform apply
```

run:

```bash
aws ec2 describe-vpn-connections \
  --vpn-connection-ids <vpn-id> \
  --region ap-south-1
```

AWS CLI exposes the customer gateway/tunnel configuration through `describe-vpn-connections`. ([AWS Documentation][9])

AWS also lets you download a device-specific or Generic sample configuration from the console, and the CLI provides `get-vpn-connection-device-sample-configuration`. ([AWS Documentation][10])

---

# 36.583 What you will receive

For each tunnel you'll get values conceptually like:

```text
TUNNEL 1

AWS Outside IP
x.x.x.x

Customer Outside IP
<your EIP>

AWS Inside IP
169.254.x.1

Customer Inside IP
169.254.x.2

Pre-Shared Key
************

AWS ASN
64512 / TGW ASN


TUNNEL 2

different AWS outside IP
different inside /30
different PSK
```

Do not copy example addresses from a tutorial.

Use **your generated VPN values**.

---

# 36.584 StrongSwan mental mapping

Your real values go into something conceptually like:

```text
conn aws-tunnel1

left=
Customer Gateway

right=
AWS Tunnel Outside IP

authentication=
PSK

IKE=
IKEv2

IPsec=
ESP
```

Then Tunnel 2 receives its own configuration.

AWS recommends configuring both tunnels because maintenance or failure can temporarily make an individual tunnel unavailable. ([AWS Documentation][2])

---

# 36.585 FRRouting / BGP

StrongSwan handles:

```text
IPsec
```

FRRouting handles:

```text
BGP
```

Mental architecture:

```text
                 Linux VPN Router

              ┌────────────────────┐
              │                    │
              │ StrongSwan         │
              │     ↓              │
              │   IPsec            │
              │     ↓              │
              │ tunnel interface   │
              │     ↓              │
              │ FRR / BGP          │
              │                    │
              └─────────┬──────────┘
                        │
                        ▼
                       AWS
```

Your BGP configuration will use the **inside tunnel IPs generated for your VPN**, not the public outside addresses.

---

# 36.586 BGP conceptual configuration

Suppose AWS gives you:

```text
Tunnel 1

AWS inside:
169.254.100.1

Customer inside:
169.254.100.2
```

and:

```text
AWS ASN:
64512

Customer ASN:
65000
```

FRR conceptually:

```text
router bgp 65000

 neighbor 169.254.100.1 remote-as 64512

 network 10.10.0.0/16
```

Repeat the neighbor setup for Tunnel 2.

Do **not** use those example `169.254` values unless AWS actually allocated them to you.

---

# 36.587 BGP goal

Customer side advertises:

```text
10.10.0.0/16
```

AWS/TGW side exposes reachable AWS prefixes according to the TGW/VPN routing policy.

Result:

```text
Corporate Router

"I can reach 10.10/16"


AWS TGW

"I can reach 10.64/16"
"I can reach 10.72/16"
```

Dynamic routing is one of AWS Site-to-Site VPN's supported routing models. ([AWS Documentation][11])

---

# 36.588 VPN attachment association

After VPN creation:

```text
TGW
 │
 └── VPN Attachment
```

We want traffic **arriving from on-prem** to use:

```text
HYBRID-RT
```

So associate the VPN attachment with:

```text
HYBRID-RT
```

Depending on how you structure Terraform, you may retrieve the resulting attachment ID or manage association after the VPN attachment appears.

Logical result:

```text
VPN traffic
    ↓
TGW
    ↓
HYBRID-RT
```

---

# 36.589 HYBRID-RT

We want on-prem to reach:

```text
Prod
Shared
```

but later we'll intentionally restrict things.

Conceptually:

```text
HYBRID-RT

10.64.0.0/16
   ↓
Prod Attachment

10.72.0.0/16
   ↓
Shared Attachment
```

Achieve this through appropriate propagation or explicit routes.

---

# 36.590 PROD-RT must know on-prem

Once BGP propagation from VPN is enabled into PROD-RT:

```text
PROD-RT

10.10.0.0/16
      ↓
VPN Attachment
```

Prod can route:

```text
10.10.x.x
```

through the VPN.

But remember the VPC route also needs:

```text
10.10.0.0/16 → TGW
```

which we created earlier.

---

# 36.591 Simulated corporate workload

Launch another EC2:

```text
onprem-app
10.10.10.x
```

This represents:

```text
Oracle
Active Directory
legacy API
file server
```

For an easy TCP test, install nginx:

```bash
sudo apt update
sudo apt install -y nginx
```

Then:

```bash
echo "Hello from simulated corporate data center" \
  | sudo tee /var/www/html/index.html
```

Verify locally:

```bash
curl localhost
```

Expected:

```text
Hello from simulated corporate data center
```

---

# 36.592 On-prem workload route

The corporate private subnet must know:

```text
10.64.0.0/16
10.72.0.0/16
```

are reachable through the Linux VPN router.

Conceptually:

```text
Corporate workload
       │
       ▼
VPC route table

10.64.0.0/16 → VPN router ENI
10.72.0.0/16 → VPN router ENI
```

Remember:

```text
corporate VPC route table
```

is acting as our simulated physical corporate router upstream network.

---

# 36.593 First major test

From Prod:

```bash
curl http://10.10.10.X
```

Expected:

```text
Hello from simulated corporate data center
```

If it works, your packet path is:

```text
PROD EC2
10.64.x.x
    │
    ▼
Prod VPC RT
    │
    ▼
TGW
    │
    ▼
PROD-RT
    │
    ▼
VPN Attachment
    │
    ▼
IPsec Tunnel
    │
    ▼
Linux VPN Router
    │
    ▼
Corporate VPC
    │
    ▼
10.10.10.x
```

Return:

```text
10.10.10.x
    │
VPN Router
    │
IPsec
    │
TGW
    │
Prod
```

That is your first genuine hybrid packet.

---

# 36.594 Verify VPN state

Run:

```bash
aws ec2 describe-vpn-connections \
  --vpn-connection-ids <vpn-id> \
  --query 'VpnConnections[0].VgwTelemetry' \
  --region ap-south-1
```

You're looking for tunnel telemetry such as:

```text
UP
DOWN
```

But remember our lesson:

```text
Tunnel UP
≠
application works
```

---

# 36.595 Verify BGP on Linux

FRR:

```bash
sudo vtysh
```

Then:

```text
show ip bgp summary
```

You want neighbor state consistent with established BGP.

Then:

```text
show ip route
```

and:

```text
show ip bgp
```

Verify that the AWS prefixes you expect actually exist.

---

# 36.596 Now Hybrid DNS

Let's make:

```text
legacy.corp.internal
```

resolve to our simulated corporate server.

Corporate DNS can be simulated with:

```text
BIND9
```

on the corporate server.

Install:

```bash
sudo apt install -y bind9 bind9-utils
```

Create a zone:

```text
corp.internal
```

with:

```text
legacy.corp.internal
     ↓
10.10.10.X
```

Now AWS needs to forward:

```text
*.corp.internal
```

toward that DNS server.

---

# 36.597 Resolver outbound security group

```hcl
resource "aws_security_group" "resolver" {
  name   = "hybrid-resolver"
  vpc_id = aws_vpc.shared.id

  ingress {
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = [local.onprem_cidr]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = [local.onprem_cidr]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Standard Resolver endpoint hybrid DNS needs appropriate TCP/UDP DNS connectivity, and an outbound endpoint forwards matching queries to the target DNS servers specified by Resolver rules. ([AWS Documentation][5])

---

# 36.598 Outbound Resolver endpoint

```hcl
resource "aws_route53_resolver_endpoint" "outbound" {
  name      = "corp-outbound"
  direction = "OUTBOUND"

  security_group_ids = [
    aws_security_group.resolver.id
  ]

  ip_address {
    subnet_id = aws_subnet.resolver_a.id
  }

  ip_address {
    subnet_id = aws_subnet.resolver_b.id
  }
}
```

The current HashiCorp AWS provider supports the Resolver endpoint resource. ([Terraform Registry][12])

---

# 36.599 Forwarding rule

Suppose corporate DNS:

```text
10.10.10.53
```

Then:

```hcl
resource "aws_route53_resolver_rule" "corp_internal" {
  name                 = "corp-internal"
  domain_name          = "corp.internal"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = "10.10.10.53"
  }
}
```

Associate with Prod:

```hcl
resource "aws_route53_resolver_rule_association" "prod_corp" {
  resolver_rule_id = aws_route53_resolver_rule.corp_internal.id
  vpc_id           = aws_vpc.prod.id
}
```

AWS requires the forwarding rule to identify the domain and target DNS resolver, then be associated with the VPCs that should use it. ([AWS Documentation][13])

---

# 36.600 DNS test

From Prod:

```bash
dig legacy.corp.internal
```

Expected:

```text
legacy.corp.internal.
      A
      10.10.10.X
```

Then:

```bash
curl http://legacy.corp.internal
```

Expected:

```text
Hello from simulated corporate data center
```

Now you've validated:

```text
DNS
+
TGW
+
VPN
+
BGP/routing
+
TCP application
```

in one operation.

---

# 36.601 Inbound DNS direction

Now reverse it.

Create AWS private zone:

```text
aws.internal
```

for example:

```text
app.prod.aws.internal
     ↓
10.64.10.X
```

Then create an:

```text
INBOUND Resolver endpoint
```

in the Shared VPC.

AWS inbound endpoints allow connected DNS resolvers to query private AWS names such as private hosted-zone records. ([AWS Documentation][14])

---

# 36.602 Inbound endpoint

```hcl
resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "aws-inbound"
  direction = "INBOUND"

  security_group_ids = [
    aws_security_group.resolver.id
  ]

  ip_address {
    subnet_id = aws_subnet.resolver_a.id
  }

  ip_address {
    subnet_id = aws_subnet.resolver_b.id
  }
}
```

Then your simulated corporate BIND server conditionally forwards:

```text
aws.internal
      ↓
<Resolver inbound IP A>
<Resolver inbound IP B>
```

Now corporate workloads can resolve:

```text
app.prod.aws.internal
```

through AWS Route 53.

---

# 36.603 Bidirectional DNS architecture complete

You have now built:

```text
AWS → On-Prem DNS

Prod
 │
VPC Resolver
 │
corp.internal rule
 │
Outbound Endpoint
 │
TGW
 │
VPN
 │
Corporate DNS


On-Prem → AWS DNS

Corporate DNS
 │
aws.internal forward
 │
VPN
 │
TGW
 │
Inbound Endpoint
 │
Route53
 │
Private Hosted Zone
```

That is the same architectural pattern AWS documents for centralized multi-account hybrid DNS. ([AWS Documentation][15])

---

# 36.604 Add intentional segmentation

Let's now deliberately say:

```text
Prod → Shared
YES

Prod → On-Prem
YES

On-Prem → Prod
YES

On-Prem → Shared
YES
```

Then add another fake Dev CIDR:

```text
10.68.0.0/16
```

and create:

```text
PROD-RT:

10.68.0.0/16 → BLACKHOLE
```

Example:

```hcl
resource "aws_ec2_transit_gateway_route" "prod_block_dev" {
  destination_cidr_block =
    "10.68.0.0/16"

  transit_gateway_route_table_id =
    aws_ec2_transit_gateway_route_table.prod.id

  blackhole = true
}
```

TGW supports explicit blackhole routes that drop matching traffic. ([AWS Documentation][1])

---

# 36.605 Failure injection #1 — remove Prod VPC route

Temporarily remove:

```text
10.10.0.0/16 → TGW
```

Now run:

```bash
curl http://legacy.corp.internal
```

Expected:

```text
DNS may resolve

BUT

connection fails
```

Why?

```text
DNS
✓

VPC routing
✕
```

Excellent proof that:

```text
DNS resolution
≠
network connectivity.
```

Restore the route.

---

# 36.606 Failure injection #2 — remove TGW propagation

Disable the VPN route propagation into:

```text
PROD-RT
```

Now:

```text
Prod VPC knows:
10.10/16 → TGW
```

but:

```text
TGW does not know
where 10.10/16 lives.
```

Packet:

```text
Prod
 ↓
TGW
 ↓
NO ROUTE
 ↓
DROP
```

Restore propagation.

---

# 36.607 Failure injection #3 — break return routing

Remove the AWS network route on the simulated corporate side.

Forward packet might still reach:

```text
10.10.10.x
```

but response cannot get back to:

```text
10.64.0.0/16
```

Your application times out.

Run on Prod:

```bash
sudo tcpdump -ni any host 10.10.10.X
```

Likely pattern:

```text
SYN →
SYN →
SYN →
```

No successful reply.

This should permanently burn the concept of:

# RETURN ROUTE

into your memory.

---

# 36.608 Failure injection #4 — SG

Remove HTTP from the corporate server security group.

Then:

```bash
curl http://10.10.10.X
```

fails.

But:

```text
VPN       ✓
BGP       ✓
TGW       ✓
Routes    ✓
```

Security policy:

```text
✕
```

Restore only the required source CIDR/port.

Don't "fix":

```text
TCP 0-65535
0.0.0.0/0
```

just because you're troubleshooting.

---

# 36.609 Failure injection #5 — DNS forwarding

Remove:

```text
corp.internal
```

Resolver rule association.

Then:

```bash
dig legacy.corp.internal
```

fails.

But:

```bash
curl http://10.10.10.X
```

still works.

Therefore:

```text
IP routing      ✓
DNS forwarding  ✕
```

This is exactly the diagnostic separation we learned in Part 9.

---

# 36.610 Failure injection #6 — Tunnel 1

Disable/configure one customer VPN tunnel incorrectly.

Expected architecture:

```text
Tunnel 1
   X

Tunnel 2
   ✓
```

Traffic should remain viable if Tunnel 2 and routing are correctly configured. AWS provides two Site-to-Site VPN tunnels and recommends configuring both because individual tunnel maintenance/failure can occur. ([AWS Documentation][2])

The lesson isn't:

```text
"one tunnel down means nothing."
```

It's:

```text
service may still be available

BUT

redundancy is degraded.
```

---

# 36.611 Observability — TGW Flow Logs

Create flow logging so you can answer:

> Did my traffic actually cross TGW?

AWS Transit Gateway Flow Logs capture metadata about IP traffic traversing TGW and can publish to CloudWatch Logs, S3, or Firehose. Collection occurs outside the packet-forwarding path. ([AWS Documentation][16])

The HashiCorp provider's `aws_flow_log` resource supports flow-log management. ([Terraform Registry][17])

---

# 36.612 What we inspect

When:

```text
10.64.10.x
     ↓
10.10.10.x
```

fails, ask:

```text
Source VPC Flow Logs:
did traffic leave?

        ↓

TGW Flow Logs:
did TGW see it?

        ↓

Corporate side tcpdump:
did VPN router receive it?

        ↓

Corporate workload tcpdump:
did server receive it?
```

This is the binary-search method from Part 9.

---

# 36.613 tcpdump on VPN router

Run:

```bash
sudo tcpdump -ni any host 10.64.10.X
```

Or:

```bash
sudo tcpdump -ni any \
  host 10.64.10.X and host 10.10.10.X
```

For IPsec transport troubleshooting:

```bash
sudo tcpdump -ni any udp port 500 or udp port 4500
```

Now you can distinguish:

```text
application packet
```

from:

```text
VPN negotiation/transport traffic.
```

---

# 36.614 Validate routes using AWS CLI

TGW:

```bash
aws ec2 describe-transit-gateway-route-tables \
  --region ap-south-1
```

Attachments:

```bash
aws ec2 describe-transit-gateway-attachments \
  --region ap-south-1
```

VPN:

```bash
aws ec2 describe-vpn-connections \
  --region ap-south-1
```

Don't only inspect:

```text
resource exists.
```

Inspect:

```text
state
association
propagation
route
tunnel
```

---

# 36.615 Capstone troubleshooting challenge

Imagine:

```text
dig legacy.corp.internal
```

returns:

```text
10.10.10.50
```

But:

```bash
curl http://legacy.corp.internal
```

times out.

You inspect:

```text
Prod VPC route:
10.10/16 → TGW
✓

PROD-RT:
10.10/16 → VPN
✓

VPN tunnel:
UP
✓

BGP:
UP
✓
```

What do you check next?

You should now think:

```text
1. Is 10.10.10.50 actually included
   in advertised 10.10/16? → yes

2. Corporate firewall/SG?

3. Destination nginx listening?

4. Return route to 10.64/16?

5. tcpdump on VPN router?

6. tcpdump on destination?
```

That's exactly the reasoning ability Lesson 36 was intended to build.

---

# 36.616 Add Direct Connect — production substitution

Our lab currently has:

```text
Corporate Router
       │
     Internet
       │
      IPsec
       │
      TGW
```

In production, add:

```text
Corporate Router
       │
       ▼
Direct Connect
       │
       ▼
Transit VIF
       │
       ▼
DXGW
       │
       ▼
TGW
```

while retaining VPN as backup:

```text
                       CORPORATE DC

                       Router A/B
                           │
               ┌───────────┴───────────┐
               │                       │
               ▼                       ▼
        Direct Connect             IPsec VPN
           PRIMARY                    BACKUP
               │                       │
         Transit VIF                   │
               │                       │
              DXGW                     │
               │                       │
               └───────────┬───────────┘
                           ▼
                          TGW
```

That's the production evolution of the lab.

---

# 36.617 Nothing above TGW needs to care

This is a powerful architecture point.

Your workload still sees:

```text
10.10.0.0/16 → TGW
```

Whether TGW ultimately chooses:

```text
VPN
```

or:

```text
DXGW
```

is an upstream transit decision.

So your Prod application doesn't need:

```text
"DX awareness."
```

It simply needs a valid route to the enterprise transit layer.

---

# 36.618 Complete packet walk — capstone edition

Let's perform one final walk.

Application:

```text
app.prod.aws.internal
10.64.10.20
```

needs:

```text
legacy.corp.internal
10.10.10.50
```

### DNS first

```text
Prod application
      │
      ▼
VPC Resolver
      │
corp.internal rule
      │
      ▼
Outbound Resolver
      │
      ▼
TGW
      │
      ▼
VPN
      │
      ▼
Corporate DNS
      │
      ▼
10.10.10.50
```

Application now knows the IP.

### TCP connection

```text
10.64.10.20
      │
      ▼
Prod subnet RT

10.10/16 → TGW
      │
      ▼
Prod attachment
      │
      ▼
PROD-RT

10.10/16 → VPN
      │
      ▼
VPN attachment
      │
      ▼
IPsec
      │
      ▼
Corporate VPN router
      │
      ▼
Corporate routing
      │
      ▼
10.10.10.50:80
```

### Return

```text
10.10.10.50
      │
      ▼
Corporate route

10.64/16 → VPN router
      │
      ▼
IPsec
      │
      ▼
TGW
      │
      ▼
HYBRID-RT

10.64/16 → Prod
      │
      ▼
Prod attachment
      │
      ▼
10.64.10.20
```

That is the entire hybrid architecture in one transaction.

---

# 36.619 Validation checklist

Before calling the capstone successful, verify:

```text
TGW
───
✓ TGW available
✓ Prod attachment available
✓ Shared attachment available
✓ VPN attachment available
✓ Correct associations
✓ Correct propagations


VPN
───
✓ Tunnel 1 configured
✓ Tunnel 2 configured
✓ IPsec working
✓ BGP neighbors established
✓ 10.10/16 advertised
✓ AWS routes received


PROD
────
✓ 10.10/16 → TGW
✓ 10.72/16 → TGW
✓ Security controls correct


DNS
───
✓ corp.internal Resolver rule
✓ Outbound endpoint healthy
✓ legacy.corp.internal resolves
✓ AWS inbound endpoint works
✓ aws.internal resolves from corporate side


APPLICATION
───────────
✓ curl by IP
✓ curl by DNS name
✓ return traffic successful


OBSERVABILITY
─────────────
✓ VPC Flow Logs
✓ TGW Flow Logs
✓ VPN status visible
✓ tcpdump testing understood
```

---

# 36.620 Cleanup — very important

Start with:

```bash
terraform plan -destroy
```

Inspect carefully.

Then:

```bash
terraform destroy
```

Confirm:

```text
Do you really want to destroy all resources?

yes
```

Pay special attention that these are gone:

```text
Route 53 Resolver endpoints

Site-to-Site VPN

TGW attachments

Transit Gateway

EC2 instances

Elastic IP

log groups / buckets created for lab

Internet Gateway

VPCs
```

This matters because TGW/VPN/Resolver resources can continue generating hourly charges while provisioned. ([Amazon Web Services, Inc.][3])

---

# 36.621 What you have actually learned from the capstone

You did **not** merely learn:

```text
how to create TGW.
```

You learned the full dependency chain:

```text
IP PLAN
   ↓
VPC
   ↓
SUBNET
   ↓
VPC ROUTE
   ↓
TGW ATTACHMENT
   ↓
TGW ASSOCIATION
   ↓
TGW ROUTE / PROPAGATION
   ↓
VPN ATTACHMENT
   ↓
IPsec
   ↓
BGP
   ↓
CUSTOMER ROUTER
   ↓
CORPORATE ROUTING
   ↓
APPLICATION
```

And independently:

```text
DNS NAME
   ↓
VPC RESOLVER
   ↓
RESOLVER RULE
   ↓
OUTBOUND ENDPOINT
   ↓
TGW
   ↓
VPN / DX
   ↓
CORPORATE DNS
```

That is production hybrid-cloud thinking.

---

# 36.622 What Direct Connect changes

Direct Connect does **not** eliminate everything we just learned.

You still need:

```text
CIDR planning
BGP
TGW
route tables
return routing
security
DNS
observability
failover
```

It primarily changes the hybrid **transport architecture**:

```text
VPN transport:

Customer
   ↓
Internet/IP transport
   ↓
AWS VPN


DX transport:

Customer
   ↓
Dedicated connectivity
   ↓
Transit VIF
   ↓
DXGW
   ↓
TGW
```

Which is exactly why learning VPN/TGW/BGP before DX was the correct order.

---

# 36.623 Capstone architecture — final view

```text
                          CORPORATE DATA CENTER
                              10.10.0.0/16

                    ┌────────────────────────┐
                    │ Router / Firewall      │
                    │ ASN 65000              │
                    └──────────┬─────────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
                    ▼                     ▼
              DIRECT CONNECT          IPsec VPN
                 Primary               Backup
                    │                     │
              Transit VIF                 │
                    │                     │
                   DXGW                   │
                    │                     │
                    └──────────┬──────────┘
                               ▼
                    ┌──────────────────────┐
                    │   TRANSIT GATEWAY    │
                    └──────────┬───────────┘
                               │
             ┌─────────────────┼───────────────────┐
             │                 │                   │
             ▼                 ▼                   ▼
          PROD VPC         SHARED VPC        SECURITY VPC
        10.64.0.0/16      10.72.0.0/16      10.73.0.0/16
             │                 │                   │
             │          Route53 Resolver      Network Firewall
             │           IN       OUT          Appliance Mode
             │                 │
            ECS            Hybrid DNS
             │
            RDS

                    CENTRAL ROUTING POLICY

                PROD-RT
                SHARED-RT
                SECURITY-RT
                HYBRID-RT

                         +

                    OBSERVABILITY

                VPC Flow Logs
                TGW Flow Logs
                VPN Logs/Metrics
                Resolver Query Logs
```

That's the architecture Lesson 36 has been building toward since Part 1.

---

# 36.624 Resume-level takeaway

After implementing a real version of this capstone, you could accurately describe the project along the lines of:

> Designed and implemented an AWS hybrid-cloud network using Transit Gateway hub-and-spoke routing, Site-to-Site IPsec VPN with BGP, segmented TGW route tables, bidirectional Route 53 Resolver hybrid DNS, centralized network observability, and Terraform-based infrastructure provisioning, with validated failover, return routing, and route-isolation scenarios.

That's considerably stronger than:

```text
"Worked with AWS VPC."
```

---

# Lesson 36 status

We now have:

```text
Part 1   Site-to-Site VPN                 ✓
Part 2   Transit Gateway                  ✓
Part 3   Direct Connect                   ✓
Part 4   BGP + resilient routing          ✓
Part 5   Private VPN over DX              ✓
Part 6   Route 53 hybrid DNS              ✓
Part 7   Multi-account architecture       ✓
Part 8   Terraform implementation         ✓
Part 9   Troubleshooting/observability    ✓
Part 10  Enterprise capstone              ✓

Part 11  FINAL REVISION                   NEXT
```

# Lesson 36 is now about **95% complete**.

## Next — Lesson 36, Part 11: Final Revision & Interview Mastery

Part 11 will be the **last part of Lesson 36**.

We'll compress this huge lesson into a never-forget framework covering:

```text
VGW vs TGW
CGW vs Customer Gateway Device

VPN vs Direct Connect

Private VIF vs Public VIF vs Transit VIF

DXGW vs TGW

Static routes vs BGP

ASN
AS_PATH
LOCAL_PREF
MED
BGP Communities

TGW association vs propagation

Blackhole routes

Appliance Mode

ECMP

DX + VPN failover

Private-IP VPN over DX

Inbound vs Outbound Resolver

PHZ vs Resolver Rule

AWS RAM

IPAM

Multi-account network ownership

packet-flow troubleshooting
```

Then we'll do **real architecture-selection scenarios and SAA/DOP/DevOps interview traps**, followed by the one-page mental map that you should be able to reconstruct from memory.

After **Part 11, Lesson 36 is officially complete** and we'll immediately move to the **next AWS Production Architecture lesson**.

[1]: https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html?utm_source=chatgpt.com "How AWS Transit Gateway works - Amazon VPC"
[2]: https://docs.aws.amazon.com/vpn/latest/s2svpn/your-cgw.html?utm_source=chatgpt.com "AWS Site-to-Site VPN customer gateway devices"
[3]: https://aws.amazon.com/transit-gateway/pricing/?utm_source=chatgpt.com "AWS Transit Gateway pricing"
[4]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html?utm_source=chatgpt.com "Amazon VPC attachments in AWS Transit Gateway"
[5]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html?utm_source=chatgpt.com "What is Route 53 VPC Resolver?"
[6]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment?utm_source=chatgpt.com "aws_ec2_transit_gateway_vpc_..."
[7]: https://docs.aws.amazon.com/vpn/latest/s2svpn/SetUpVPNConnections.html?utm_source=chatgpt.com "Get started with AWS Site-to-Site VPN"
[8]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection?utm_source=chatgpt.com "aws_vpn_connection | Resources | hashicorp/aws | Terraform"
[9]: https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-vpn-connections.html?utm_source=chatgpt.com "describe-vpn-connections — AWS CLI 2.36.20 Command Reference"
[10]: https://docs.aws.amazon.com/cli/latest/reference/ec2/get-vpn-connection-device-sample-configuration.html?utm_source=chatgpt.com "get-vpn-connection-device-sample-configuration"
[11]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNRoutingTypes.html?utm_source=chatgpt.com "AWS Site-to-Site VPN routing options"
[12]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_endpoint?utm_source=chatgpt.com "aws_route53_resolver_endpoint | Resources | hashicorp/aws"
[13]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-forwarding-outbound-queries.html?utm_source=chatgpt.com "Forwarding outbound DNS queries to your network"
[14]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-overview-DSN-queries-to-vpc.html?utm_source=chatgpt.com "Resolving DNS queries between VPCs and your network"
[15]: https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/set-up-dns-resolution-for-hybrid-networks-in-a-multi-account-aws-environment.html?utm_source=chatgpt.com "Set up DNS resolution for hybrid networks in a multi- ..."
[16]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-flow-logs.html?utm_source=chatgpt.com "AWS Transit Gateway Flow Logs - Amazon VPC"
[17]: https://registry.terraform.io/providers/hashicorp/awS/latest/docs/resources/flow_log?utm_source=chatgpt.com "aws_flow_log | Resources | hashicorp/aws - Terraform Registry"
