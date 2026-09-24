Yes — and at this point **Lesson 36 is in its final stretch**.

We have already completed **7 major parts**:

1. Hybrid networking mental model + Site-to-Site VPN
2. Transit Gateway deep dive
3. Direct Connect deep dive
4. BGP, DX + VPN failover, resilient routing
5. Private-IP VPN over Direct Connect
6. Route 53 Resolver hybrid DNS
7. Multi-account enterprise hybrid networking

What remains is approximately **4 more parts**:

```text
Part 8  → Terraform implementation
Part 9  → Hybrid networking troubleshooting & observability
Part 10 → Complete hands-on enterprise lab / packet-flow validation
Part 11 → Lesson 36 final revision + interview scenarios + architecture decision matrix
```

So we are roughly:

```text
████████████████████░░░░░
~65–70% complete
```

Lesson 36 is intentionally large because **hybrid networking is almost a mini-module by itself**. I don't want to rush Direct Connect/TGW/BGP/DNS into shallow definitions because these are precisely the topics that distinguish basic AWS knowledge from production architecture knowledge.

After Part 11, **Lesson 36 will be complete**, and we'll move to the next AWS Production Architecture lesson.

---

# Lesson 36 — Part 8

# Terraform Enterprise Hybrid Network Build

Now we stop discussing architecture only theoretically.

We're going to translate:

```text
On-Premises
      │
 DX + VPN
      │
     TGW
      │
 ┌────┼──────────┐
 │    │          │
Prod Dev      Shared
              │
        Route53 Resolver
```

into Terraform.

But we're **not** going to dump 1,500 lines of Terraform into one `main.tf`.

We are going to structure it like a real production repository.

---

# 36.422 First rule — Terraform should reflect ownership boundaries

Our enterprise architecture has separate responsibilities:

```text
NETWORK ACCOUNT
───────────────

TGW
VPN
DXGW
IPAM
TGW routing


SECURITY ACCOUNT
────────────────

Inspection VPC
Network Firewall


SHARED SERVICES
───────────────

Resolver endpoints
DNS
Shared infrastructure


WORKLOAD ACCOUNTS
─────────────────

Prod VPC
Dev VPC
Applications
```

Therefore our Terraform should reflect these boundaries.

Bad:

```text
main.tf

15,000 lines
```

Better:

```text
hybrid-cloud/
│
├── modules/
│
├── network/
│
├── security/
│
├── shared-services/
│
└── workloads/
```

---

# 36.423 Production repository structure

A clean structure could look like:

```text
hybrid-cloud/
│
├── modules/
│   │
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── transit-gateway/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ipam/
│   │
│   ├── vpn/
│   │
│   ├── hybrid-dns/
│   │
│   └── inspection/
│
├── network/
│   └── ap-south-1/
│       ├── main.tf
│       ├── providers.tf
│       ├── backend.tf
│       ├── variables.tf
│       ├── locals.tf
│       └── outputs.tf
│
├── security/
│
├── shared-services/
│
└── workloads/
    ├── prod/
    └── dev/
```

The important idea is:

```text
modules/
=
reusable building blocks


network/
security/
shared-services/
workloads/
=
deployments using those modules
```

---

# 36.424 Terraform provider model

In a multi-account setup, one Terraform deployment may need access to multiple AWS accounts.

For example:

```text
Network Account
111111111111

Security Account
222222222222

Prod Account
333333333333

Shared Account
444444444444
```

You could configure provider aliases conceptually like:

```hcl
provider "aws" {
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/TerraformNetworkRole"
  }
}
```

Then:

```hcl
provider "aws" {
  alias  = "security"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/TerraformSecurityRole"
  }
}
```

And:

```hcl
provider "aws" {
  alias  = "prod"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::333333333333:role/TerraformProdRole"
  }
}
```

Then resources can explicitly use:

```hcl
provider = aws.security
```

or:

```hcl
provider = aws.prod
```

This makes account ownership explicit.

---

# 36.425 Why assume-role instead of permanent access keys?

Bad production pattern:

```text
AWS_ACCESS_KEY_ID=AKIA....
AWS_SECRET_ACCESS_KEY=....
```

stored everywhere.

Better pattern:

```text
CI/CD identity
      │
      ▼
AssumeRole
      │
      ▼
Target AWS account
```

That gives us:

```text
temporary credentials
auditable role usage
central identity
smaller secret-management burden
```

This same pattern is common with:

```text
GitHub Actions OIDC
Jenkins
GitLab CI
AWS CodeBuild
Terraform Cloud
```

---

# 36.426 Start with Transit Gateway

At the network-account level:

```hcl
resource "aws_ec2_transit_gateway" "enterprise" {
  description = "Enterprise hybrid transit gateway"

  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  dns_support = "enable"

  tags = {
    Name        = "enterprise-tgw"
    Environment = "shared"
    ManagedBy   = "terraform"
  }
}
```

Notice something important:

```text
default association = disabled

default propagation = disabled
```

Why?

Because in our enterprise design we want explicit control.

We do **not** want:

```text
new attachment
     ↓
automatically connected everywhere
```

Instead:

```text
new attachment
     ↓
deliberate association
     ↓
deliberate propagation
```

That reduces accidental connectivity.

---

# 36.427 Create TGW route tables

We need:

```text
PROD-RT
NONPROD-RT
SHARED-RT
SECURITY-RT
HYBRID-RT
```

Terraform:

```hcl
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.enterprise.id

  tags = {
    Name = "tgw-prod-rt"
  }
}

resource "aws_ec2_transit_gateway_route_table" "nonprod" {
  transit_gateway_id = aws_ec2_transit_gateway.enterprise.id

  tags = {
    Name = "tgw-nonprod-rt"
  }
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.enterprise.id

  tags = {
    Name = "tgw-shared-rt"
  }
}

resource "aws_ec2_transit_gateway_route_table" "security" {
  transit_gateway_id = aws_ec2_transit_gateway.enterprise.id

  tags = {
    Name = "tgw-security-rt"
  }
}

resource "aws_ec2_transit_gateway_route_table" "hybrid" {
  transit_gateway_id = aws_ec2_transit_gateway.enterprise.id

  tags = {
    Name = "tgw-hybrid-rt"
  }
}
```

Now we have routing domains.

---

# 36.428 Build Prod VPC attachment

Suppose:

```text
Prod VPC
10.64.0.0/16
```

has dedicated TGW attachment subnets:

```text
AZ-A
10.64.250.0/28

AZ-B
10.64.250.16/28
```

Attachment:

```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  subnet_ids = [
    aws_subnet.prod_tgw_a.id,
    aws_subnet.prod_tgw_b.id
  ]

  transit_gateway_id = aws_ec2_transit_gateway.enterprise.id
  vpc_id             = aws_vpc.prod.id

  tags = {
    Name          = "prod-tgw-attachment"
    RoutingDomain = "prod"
  }
}
```

---

# 36.429 Associate Prod with PROD-RT

Remember:

```text
Association
=
Which TGW RT incoming Prod traffic reads?
```

Terraform:

```hcl
resource "aws_ec2_transit_gateway_route_table_association" "prod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}
```

Now:

```text
Prod packet
    ↓
TGW
    ↓
PROD-RT
```

---

# 36.430 Shared-services attachment

```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "shared" {
  subnet_ids = [
    aws_subnet.shared_tgw_a.id,
    aws_subnet.shared_tgw_b.id
  ]

  transit_gateway_id = aws_ec2_transit_gateway.enterprise.id
  vpc_id             = aws_vpc.shared.id

  tags = {
    Name = "shared-tgw-attachment"
  }
}
```

Associate:

```hcl
resource "aws_ec2_transit_gateway_route_table_association" "shared" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}
```

---

# 36.431 Propagate Shared into Prod

Remember:

```text
Propagation
=
Which TGW RT learns Shared routes?
```

We want:

```text
Prod → Shared
```

so PROD-RT must know:

```text
10.72.0.0/16
    ↓
Shared attachment
```

We can use propagation:

```hcl
resource "aws_ec2_transit_gateway_route_table_propagation" "shared_to_prod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}
```

Similarly:

```hcl
resource "aws_ec2_transit_gateway_route_table_propagation" "shared_to_nonprod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.nonprod.id
}
```

Now:

```text
Prod → Shared ✓
Dev  → Shared ✓
```

---

# 36.432 Do NOT propagate Prod into NonProd

If Prod attachment propagates into:

```text
NONPROD-RT
```

then Dev may learn:

```text
10.64.0.0/16 → Prod
```

which could violate our segmentation.

So simply:

```text
do not configure
```

that propagation.

This is one of the beautiful aspects of TGW design:

```text
absence of a route
=
isolation
```

---

# 36.433 Add explicit blackhole route

For stronger guardrail:

```hcl
resource "aws_ec2_transit_gateway_route" "prod_block_nonprod" {
  destination_cidr_block         = "10.68.0.0/14"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
  blackhole                      = true
}
```

Now:

```text
Prod → NonProd
```

gets dropped at TGW routing.

This protects against broader routes accidentally attracting that traffic.

---

# 36.434 VPC route tables still matter

Creating the TGW routes is only half of the network.

Prod subnet route table needs:

```hcl
resource "aws_route" "prod_to_shared" {
  route_table_id         = aws_route_table.prod_private.id
  destination_cidr_block = "10.72.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.enterprise.id
}
```

And:

```hcl
resource "aws_route" "prod_to_onprem" {
  route_table_id         = aws_route_table.prod_private.id
  destination_cidr_block = "10.10.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.enterprise.id
}
```

So always remember:

```text
VPC Route
      +
TGW Route
```

Both are required.

---

# 36.435 VPN resources

The AWS-side Customer Gateway represents your corporate VPN device.

Example:

```hcl
resource "aws_customer_gateway" "onprem" {
  bgp_asn    = 65000
  ip_address = var.onprem_vpn_public_ip
  type       = "ipsec.1"

  tags = {
    Name = "onprem-primary-cgw"
  }
}
```

Then Site-to-Site VPN terminating on TGW:

```hcl
resource "aws_vpn_connection" "onprem" {
  customer_gateway_id = aws_customer_gateway.onprem.id
  transit_gateway_id  = aws_ec2_transit_gateway.enterprise.id

  type = "ipsec.1"

  static_routes_only = false

  tags = {
    Name = "onprem-to-aws"
  }
}
```

Because:

```text
static_routes_only = false
```

we are choosing dynamic routing/BGP.

---

# 36.436 VPN becomes another TGW attachment

After VPN creation, TGW effectively has:

```text
VPC attachment
VPC attachment
VPC attachment
VPN attachment
```

Conceptually:

```text
                      TGW
                       │
       ┌───────────────┼───────────────┐
       ▼               ▼               ▼
     PROD            SHARED           VPN
```

Then:

```text
VPN attachment
```

can participate in:

```text
association
propagation
TGW routing
```

just like we've learned.

---

# 36.437 DX is different from Terraform-only networking

Here's an important real-world point.

Terraform can configure AWS-side DX resources.

But it cannot:

```text
install fiber
run a carrier circuit
physically patch a cross-connect
deliver a router to the colo
```

So Direct Connect implementation has two workflows:

```text
PHYSICAL WORKFLOW

Carrier
Cross-connect
LOA-CFA
Colocation


AWS LOGICAL WORKFLOW

DX connection
VIF
DXGW
TGW association
BGP
```

Terraform only handles the AWS/cloud configuration side.

---

# 36.438 DXGW Terraform concept

Example:

```hcl
resource "aws_dx_gateway" "enterprise" {
  name            = "enterprise-dxgw"
  amazon_side_asn = 64512
}
```

Then conceptually:

```text
Transit VIF
    ↓
DXGW
    ↓
TGW
```

The exact DX resource creation depends on whether you're using:

```text
dedicated DX
hosted DX
existing provider circuit
```

In many organizations the DX connection/VIF may already exist and be imported or referenced instead of created from scratch.

---

# 36.439 Inspection VPC

Now we create a security VPC:

```text
Security VPC
10.73.0.0/16
```

with subnets such as:

```text
AZ-A
Firewall subnet
TGW subnet

AZ-B
Firewall subnet
TGW subnet
```

Conceptually:

```text
                    SECURITY VPC

              AZ-A               AZ-B

          TGW subnet         TGW subnet
               │                 │
               ▼                 ▼
          Firewall-A        Firewall-B
               │                 │
               └────────┬────────┘
                        │
                       TGW
```

And the TGW VPC attachment should use appliance mode where appropriate.

---

# 36.440 Appliance mode Terraform

Conceptually:

```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  subnet_ids = [
    aws_subnet.security_tgw_a.id,
    aws_subnet.security_tgw_b.id
  ]

  transit_gateway_id = aws_ec2_transit_gateway.enterprise.id
  vpc_id             = aws_vpc.security.id

  appliance_mode_support = "enable"

  tags = {
    Name = "inspection-tgw-attachment"
  }
}
```

Why?

Because:

```text
stateful firewall
+
multi-AZ
+
TGW
```

should immediately make you think:

```text
appliance mode
```

for the applicable design.

---

# 36.441 Route Prod → Inspection

Instead of:

```text
Prod → VPN directly
```

we want:

```text
Prod
 ↓
Inspection
 ↓
VPN / DX
```

Therefore:

```hcl
resource "aws_ec2_transit_gateway_route" "prod_to_onprem_via_inspection" {
  destination_cidr_block         = "10.10.0.0/16"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
}
```

Now PROD-RT says:

```text
10.10.0.0/16
      ↓
Inspection attachment
```

instead of:

```text
VPN
```

directly.

---

# 36.442 Security route table

The inspection attachment's TGW route table needs to know where to send the packet after inspection.

Conceptually:

```text
SECURITY-RT

10.10.0.0/16 → VPN/DX
10.64.0.0/14 → Prod
10.68.0.0/14 → NonProd
10.72.0.0/16 → Shared
```

This is what creates service insertion.

---

# 36.443 Hybrid DNS Terraform

Shared Services VPC owns Resolver endpoints.

Security group:

```hcl
resource "aws_security_group" "resolver" {
  name   = "resolver-endpoints"
  vpc_id = aws_vpc.shared.id
}
```

Inbound DNS:

```hcl
resource "aws_vpc_security_group_ingress_rule" "dns_udp" {
  security_group_id = aws_security_group.resolver.id

  cidr_ipv4   = "10.10.0.0/16"
  ip_protocol = "udp"
  from_port   = 53
  to_port     = 53
}
```

TCP:

```hcl
resource "aws_vpc_security_group_ingress_rule" "dns_tcp" {
  security_group_id = aws_security_group.resolver.id

  cidr_ipv4   = "10.10.0.0/16"
  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53
}
```

---

# 36.444 Resolver inbound endpoint

```hcl
resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "corp-inbound"
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

This is:

```text
On-Prem DNS
      ↓
AWS
```

---

# 36.445 Resolver outbound endpoint

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

This is:

```text
AWS
 ↓
On-Prem DNS
```

---

# 36.446 Resolver forwarding rule

```hcl
resource "aws_route53_resolver_rule" "corp_internal" {
  domain_name          = "corp.internal"
  name                 = "corp-internal-forward"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = "10.10.1.53"
  }

  target_ip {
    ip = "10.10.1.54"
  }
}
```

Then associate with a VPC:

```hcl
resource "aws_route53_resolver_rule_association" "prod" {
  resolver_rule_id = aws_route53_resolver_rule.corp_internal.id
  vpc_id           = aws_vpc.prod.id
}
```

Result:

```text
Prod asks:

oracle.corp.internal
        ↓
Route53 Resolver
        ↓
On-Prem DNS
```

---

# 36.447 Private Hosted Zone

AWS-owned private namespace:

```text
aws.internal
```

Terraform:

```hcl
resource "aws_route53_zone" "aws_internal" {
  name = "aws.internal"

  vpc {
    vpc_id = aws_vpc.shared.id
  }
}
```

Record:

```hcl
resource "aws_route53_record" "jenkins" {
  zone_id = aws_route53_zone.aws_internal.zone_id

  name = "jenkins.aws.internal"
  type = "A"
  ttl  = 60

  records = [
    "10.72.5.20"
  ]
}
```

Corporate DNS then conditionally forwards:

```text
aws.internal
       ↓
AWS inbound Resolver IPs
```

That on-prem conditional-forwarder configuration lives on your corporate DNS servers rather than inside Terraform's AWS resources unless you also manage those servers through configuration management.

---

# 36.448 Outputs matter

Production Terraform should expose useful outputs.

Example:

```hcl
output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.enterprise.id
}

output "prod_tgw_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.prod.id
}

output "vpn_connection_id" {
  value = aws_vpn_connection.onprem.id
}

output "resolver_inbound_ips" {
  value = aws_route53_resolver_endpoint.inbound.ip_address
}
```

These outputs may feed:

```text
Ansible
CI/CD
DNS automation
documentation
monitoring
other Terraform stacks
```

---

# 36.449 Avoid one giant state file

Imagine this:

```text
terraform.tfstate

contains:

TGW
DX
VPN
Network Firewall
Prod VPC
Dev VPC
QA VPC
RDS
EKS
ECS
Route53
everything
```

A bad change could affect enormous scope.

Better architecture often separates state by lifecycle/ownership:

```text
network-core state
shared-services state
security state
prod-workload state
dev-workload state
```

For example:

```text
s3://company-terraform-state/

network/ap-south-1.tfstate

security/ap-south-1.tfstate

shared/ap-south-1.tfstate

prod/payments.tfstate
```

This helps reduce:

```text
state blast radius
locking conflicts
ownership confusion
```

---

# 36.450 Terraform dependency challenge

But if states are separate:

```text
Prod
```

needs:

```text
TGW ID
```

How does it get it?

Possible mechanisms include:

```text
terraform_remote_state

SSM Parameter Store

explicit pipeline outputs

data sources

module outputs within same stack
```

Each has trade-offs.

In large environments I generally want dependencies to be explicit rather than having every state file casually read every other state file.

---

# 36.451 Never hard-code resource IDs

Bad:

```hcl
transit_gateway_id = "tgw-0abc123def456"
```

Why?

Because:

```text
account changes
Region changes
rebuild happens
resource ID changes
```

Better:

```hcl
transit_gateway_id = module.enterprise_tgw.id
```

or retrieve through an appropriate controlled interface.

---

# 36.452 `locals` become useful

Example:

```hcl
locals {
  onprem_cidr = "10.10.0.0/16"

  prod_cidr   = "10.64.0.0/16"
  dev_cidr    = "10.68.0.0/16"
  shared_cidr = "10.72.0.0/16"

  common_tags = {
    ManagedBy = "terraform"
    Platform  = "enterprise-network"
  }
}
```

Then:

```hcl
tags = merge(
  local.common_tags,
  {
    Name = "enterprise-tgw"
  }
)
```

This keeps naming and tagging consistent.

---

# 36.453 Variables should represent decisions

Good:

```hcl
variable "onprem_bgp_asn" {
  type        = number
  description = "BGP ASN used by the corporate customer gateway"
}
```

Good:

```hcl
variable "onprem_vpn_public_ip" {
  type        = string
  description = "Public address of the customer gateway"
}
```

Less useful:

```hcl
variable "everything" {
  type = any
}
```

Avoid over-generic IaC.

Your variable model should expose architecture decisions cleanly.

---

# 36.454 Validation matters

For ASN:

```hcl
variable "onprem_bgp_asn" {
  type = number

  validation {
    condition     = var.onprem_bgp_asn > 0
    error_message = "BGP ASN must be a positive integer."
  }
}
```

CIDRs can also be validated.

This catches:

```text
bad input
```

before AWS rejects it during apply.

---

# 36.455 Terraform doesn't validate packet flow

This is one of the biggest lessons.

Terraform may print:

```text
Apply complete!

Resources: 38 added, 0 changed, 0 destroyed.
```

That means:

```text
AWS accepted the resources.
```

It does **not** mean:

```text
Prod can reach Oracle.

VPN failover works.

DNS works.

Firewall is symmetric.

BGP learned the expected routes.
```

Infrastructure provisioning and connectivity validation are separate steps.

---

# 36.456 Therefore our workflow becomes

```text
terraform validate
        ↓
terraform plan
        ↓
terraform apply
        ↓
AWS resource validation
        ↓
route validation
        ↓
DNS validation
        ↓
application validation
        ↓
failure testing
```

Never stop at:

```text
terraform apply
```

for networking.

---

# 36.457 Example post-deployment validations

### TGW

Check:

```text
attachments = AVAILABLE

correct associations

correct propagations

expected routes
```

### VPN

Check:

```text
Tunnel 1 = UP

Tunnel 2 = UP

BGP routes received
```

### DNS

Test:

```bash
dig oracle.corp.internal
```

and:

```bash
dig jenkins.aws.internal
```

### Network

Test:

```bash
nc -vz 10.10.50.20 1521
```

### HTTP

```bash
curl -vk https://internal-app.corp.internal
```

### Routing

Use:

```text
VPC Reachability Analyzer
Flow Logs
TGW Flow Logs
```

where appropriate.

---

# 36.458 One production rule for Terraform networking

I want you to remember this:

> **Terraform describes what the network should look like; packet-flow testing proves what the network actually does.**

That distinction is huge.

---

# 36.459 Part 8 architecture summary

Terraform is now implementing:

```text
                    NETWORK ACCOUNT

                      Transit Gateway
                   /       |        \
                Prod     Shared     VPN
                 │          │         │
              PROD-RT   SHARED-RT  HYBRID-RT
                 │          │
                 ▼          ▼
                VPC      Resolver


                    SECURITY ACCOUNT

                      Inspection VPC
                           │
                       Firewall


                    SHARED SERVICES

                  Route53 Resolver
                  Inbound / Outbound


                    ON-PREM

                      CGW
                       │
                      BGP
                       │
                      VPN
```

We're not done with the build yet—but you now understand how every major architectural concept maps into Terraform.

---

# Lesson 36 progress now

After this Part 8:

```text
Part 1  VPN                    ✓
Part 2  TGW                    ✓
Part 3  Direct Connect         ✓
Part 4  Resilient BGP          ✓
Part 5  Private VPN over DX    ✓
Part 6  Hybrid DNS             ✓
Part 7  Multi-account          ✓
Part 8  Terraform architecture ✓

Part 9  Troubleshooting        NEXT
Part 10 Hands-on capstone
Part 11 Final revision
```

We are now roughly **75–80% through Lesson 36**.

---

# Next — Lesson 36, Part 9

## Hybrid Network Troubleshooting & Observability

This next section is particularly important for DevOps/SRE work because we'll deliberately break the architecture.

We'll diagnose scenarios such as:

```text
VPN tunnel DOWN

Tunnel UP but BGP DOWN

BGP UP but route missing

DX physical UP but VIF DOWN

DX + VPN wrong path preference

TGW attachment AVAILABLE but VPC unreachable

TGW association incorrect

TGW propagation missing

Blackhole route accidentally winning

Firewall asymmetric-routing failure

DNS Resolver endpoint reachable but NXDOMAIN

Resolver forwarding loop

Security Group blocking DNS TCP/UDP 53

MTU / MSS black-hole problem

Overlapping CIDRs

Return route missing
```

And we'll use the production troubleshooting toolkit:

```text
AWS Console / CLI
CloudWatch
VPC Flow Logs
Transit Gateway Flow Logs
Route 53 Resolver Query Logs
Reachability Analyzer

ip
ss
ping
tracepath
traceroute
dig
nslookup
nc
curl
tcpdump
mtr
```

Then Part 10 will be the **complete hands-on enterprise hybrid-cloud capstone**, and Part 11 will close Lesson 36 with the final architecture decision matrix and interview/revision drills.
