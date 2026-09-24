# Module 13 — AWS Production Architecture

# Lesson 37 — Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 3: Pilot Light vs Warm Standby — Production Multi-Region Architecture

We finished Backup & Restore.

Now we move one step closer to real production readiness.

The key change is:

```text
BACKUP & RESTORE

Primary Region
████████████

DR Region
Backups only
```

becomes:

```text
PILOT LIGHT

Primary Region
████████████

DR Region
██
```

or:

```text
WARM STANDBY

Primary Region
████████████

DR Region
█████
```

AWS defines **warm standby** as a scaled-down but fully functional copy of production running in another Region. Pilot light keeps only the critical core required for recovery running, while additional application infrastructure is started or deployed after disaster declaration. ([AWS Documentation][1])

---

# 37.143 The problem Pilot Light and Warm Standby solve

Backup & Restore may require:

```text
Disaster
   ↓
Restore database
   ↓
Create VPC
   ↓
Create ALB
   ↓
Deploy compute
   ↓
Restore secrets/config
   ↓
Deploy application
   ↓
Validate
   ↓
Redirect users
```

Suppose that takes:

```text
2–6 hours
```

but the business says:

```text
RTO = 30 minutes
```

Backup & Restore may be insufficient.

So we start moving infrastructure **before the disaster happens**.

---

# 37.144 The DR spectrum

Think of recovery readiness as a dial:

```text
                 MORE ALREADY RUNNING

Backup        Pilot         Warm          Active/
Restore       Light         Standby       Active

  0%           20%            60%          100%
   │             │              │             │
   └─────────────┴──────────────┴─────────────┘

          generally faster recovery →
```

The percentages are conceptual, not AWS-defined values.

The idea is simple:

> The more of the recovery environment that already exists and operates correctly, the less work remains during the incident.

---

# 37.145 Pilot Light mental model

Imagine a traditional gas pilot light.

A tiny flame stays alive.

When needed:

```text
pilot flame
    ↓
full burner starts
```

AWS analogy:

```text
DR REGION

critical data/state
critical core services
network foundation
replication

already ready

BUT

full application capacity
is not running yet
```

AWS's classic DR guidance differentiates Pilot Light from Warm Standby on exactly this basis: Pilot Light still requires additional application deployment/startup during recovery. ([AWS Documentation][1])

---

# 37.146 Pilot Light architecture

Primary:

```text
                   ap-south-1
                  PRIMARY REGION

                       Route53
                          │
                          ▼
                         ALB
                          │
                ┌─────────┼─────────┐
                ▼         ▼         ▼
               ECS       ECS       ECS
                │
                ▼
              Aurora
                │
                │ replication
                ▼
```

Recovery Region:

```text
                 ap-southeast-1
                    DR REGION

                 VPC             ✓
                 Subnets         ✓
                 IAM             ✓
                 Data replica    ✓

                 ALB             maybe prepared
                 Compute         stopped/minimal
                 ASG capacity    low/zero
                 full app fleet  ✕
```

During disaster:

```text
Scale/deploy compute
       ↓
activate app
       ↓
promote data if required
       ↓
validate
       ↓
switch traffic
```

---

# 37.147 What should already exist in Pilot Light?

There is no universal list.

But production Pilot Light commonly prepares things that are:

```text
slow to reconstruct
stateful
security-sensitive
hard to validate during an emergency
```

For example:

```text
VPC
subnets
route tables
security groups

IAM roles
KMS configuration

replicated data

container images
AMIs/artifacts

Secrets/configuration strategy

DNS records/health checks

Terraform definitions
```

The principle:

> Keep the minimum viable recovery core alive, but make everything else rapidly deployable and tested.

---

# 37.148 Pilot Light does NOT mean "nothing running"

If the DR Region contains only:

```text
Terraform files
+
backup files
```

that's much closer to:

# Backup & Restore.

Pilot Light means some critical live recovery capability is already present.

AWS describes it as maintaining critical core infrastructure while application servers or other resources are brought online during recovery. ([AWS Documentation][1])

---

# 37.149 Warm Standby mental model

Warm Standby goes further.

The DR Region contains:

> **A complete, functional version of production, but at reduced capacity.**

AWS explicitly defines Warm Standby this way. ([AWS Documentation][1])

Example:

Primary:

```text
ALB

20 ECS tasks

large DB capacity

10 workers

large cache
```

DR:

```text
ALB

2 ECS tasks

smaller DB capacity

1 worker

smaller cache
```

The DR application is alive.

It can actually serve requests.

But not necessarily full production load.

---

# 37.150 Warm Standby architecture

```text
                      GLOBAL USERS

                           │
                        Route53
                           │
                         PRIMARY
                           │
                           ▼

                    ap-south-1
                 FULL PRODUCTION

                       ALB
                        │
                ┌───────┼───────┐
                ▼       ▼       ▼
              ECS      ECS      ECS
             many      many     many
                        │
                     Database
                        │
                 replication
                        ▼


                 ap-southeast-1
                 WARM STANDBY

                       ALB
                        │
                       ECS
                    few tasks
                        │
                  DR Database
```

Normal traffic:

```text
Mumbai
████████████

Singapore
█ minimal traffic / readiness
```

Disaster:

```text
Mumbai X

Singapore
█
 ↓
████████████
scale up
```

---

# 37.151 The key difference

Memorize:

```text
PILOT LIGHT
───────────
core survives
full app not necessarily running


WARM STANDBY
────────────
full app already works
but at reduced scale
```

That's the cleanest distinction.

---

# 37.152 Recovery steps comparison

## Pilot Light

```text
Disaster
   ↓
start/deploy application infrastructure
   ↓
scale compute
   ↓
promote/switch data
   ↓
validate
   ↓
traffic cutover
```

## Warm Standby

```text
Disaster
   ↓
scale existing environment
   ↓
promote/switch data if required
   ↓
validate
   ↓
traffic cutover
```

Because Warm Standby already contains a working copy, AWS positions it as generally faster to recover than Pilot Light. ([AWS Documentation][1])

---

# 37.153 One architecture, two different sizes

Suppose production runs:

```text
10 ECS tasks

DB:
large instance / cluster

Redis:
3 nodes

worker fleet:
8 workers
```

Warm standby might run:

```text
2 ECS tasks

DB:
smaller standby/read-capable capacity

Redis:
minimal functional cluster

worker fleet:
1 worker
```

At disaster:

```text
desired_count = 2
      ↓
desired_count = 10
```

and infrastructure scales toward required production capacity.

---

# 37.154 Important: "Warm" means functional

A Warm Standby environment should be able to actually execute the application.

That means you should be able to validate:

```text
GET /health
        ✓

DB connection
        ✓

secret lookup
        ✓

queue access
        ✓

cache access
        ✓

internal DNS
        ✓
```

If most of the application isn't deployable until the disaster occurs, you're drifting back toward Pilot Light.

---

# 37.155 Why Warm Standby enables better testing

Pilot Light often requires startup actions before you can fully test the application.

Warm Standby is already running.

Therefore you can continuously test:

```text
HTTP health

database read path

secrets

dependencies

DNS

IAM permissions

certificates
```

AWS specifically notes that Warm Standby makes continuous recovery testing easier because the recovery workload is already operational. ([AWS Documentation][1])

---

# 37.156 Our production example

We'll use:

```text
Primary:
ap-south-1
Mumbai

DR:
ap-southeast-1
Singapore
```

Architecture:

```text
                        INTERNET
                           │
                           ▼
                        Route53
                           │
                    ┌──────┴──────┐
                    │             │
                    ▼             ▼

               ap-south-1    ap-southeast-1

                 PRIMARY          DR
                   │               │
                  ALB             ALB
                   │               │
                  ECS             ECS
                   │               │
                   └──── DATA ─────┘
```

Now let's inspect every dependency.

---

# 37.157 DR cannot start at the application server

You must reconstruct the dependency chain.

For example:

```text
Application
   │
   ├── VPC
   ├── Subnets
   ├── Security Groups
   ├── ALB
   ├── ECS
   ├── ECR
   ├── Database
   ├── Redis
   ├── SQS
   ├── Secrets
   ├── KMS
   ├── ACM
   ├── IAM
   ├── Route53
   └── Logs/Monitoring
```

Question:

> Which of these are already available in the DR Region?

That's the heart of Pilot Light/Warm Standby architecture.

---

# 37.158 Network foundation

One of the first things I'd usually pre-create is:

```text
DR VPC

subnets

route tables

security groups

NAT/egress strategy where needed

VPC endpoints where needed

TGW/hybrid connectivity where needed
```

Why?

Because during a disaster is a terrible time to discover:

```text
Singapore CIDR overlaps
corporate network
```

or:

```text
DB subnet group missing
```

or:

```text
security group rules don't allow AD
```

Network design should be tested beforehand.

---

# 37.159 Example regional CIDR strategy

Primary:

```text
ap-south-1

10.64.0.0/16
```

DR:

```text
ap-southeast-1

10.80.0.0/16
```

Why different CIDRs?

Because if the Regions ever need simultaneous connectivity:

```text
Region A ↔ Region B

On-Prem ↔ both Regions
```

overlapping IP space creates serious routing complexity.

Lesson 36's IPAM principles continue here.

---

# 37.160 Terraform should support both Regions

Bad:

```text
main.tf

hardcoded:
region = ap-south-1

CIDRs = Mumbai-only

AMI = Mumbai AMI
```

Better:

```text
modules/
   ├── vpc/
   ├── app/
   ├── database/
   └── monitoring/

environments/
   ├── primary/
   │     ap-south-1
   │
   └── dr/
         ap-southeast-1
```

Conceptually:

```hcl
module "primary" {
  source = "./modules/application"

  region = "ap-south-1"
  scale  = "full"
}

module "dr" {
  source = "./modules/application"

  region = "ap-southeast-1"
  scale  = "reduced"
}
```

Same architecture.

Different capacity.

---

# 37.161 DR Terraform must not be "the old code"

Imagine production code is:

```text
version 4.7
```

but DR Terraform repository still deploys:

```text
version 3.2
```

because nobody maintained it.

When disaster occurs:

```text
Terraform works
```

but creates:

```text
wrong architecture.
```

Therefore:

> DR infrastructure should evolve through the same delivery lifecycle as production.

---

# 37.162 Container images — hidden DR dependency

Suppose primary ECS pulls:

```text
123456789012.dkr.ecr.ap-south-1.amazonaws.com/payments:v7
```

The Singapore ECS cluster needs the image too.

If:

```text
ap-south-1 unavailable
```

and your recovery process requires pulling the image only from Mumbai:

```text
DR compute exists

BUT

application cannot start.
```

Amazon ECR supports both cross-Region and cross-account replication, making container images available in destination registries. ([AWS Documentation][2])

---

# 37.163 ECR cross-Region replication

Concept:

```text
Mumbai ECR
payments:v7
     │
     │ replicate
     ▼
Singapore ECR
payments:v7
```

Then DR tasks pull locally:

```text
ap-southeast-1 ECR
```

rather than depending on the primary Region.

Current ECR replication configurations are registry-level policies, and AWS supports both cross-Region and cross-account destinations. ([AWS Documentation][2])

---

# 37.164 ECR cross-account nuance

If destination replication is:

```text
same account
different Region
```

the setup is relatively straightforward.

If:

```text
different account
```

the destination registry must authorize replication from the source through the appropriate registry permissions policy. ([AWS Documentation][3])

That's another example of:

```text
DATA/ARTIFACT replication
+
IAM
```

both being necessary.

---

# 37.165 AMIs are another dependency

If you're running EC2 instead of containers, perhaps production launches:

```text
ami-prod-v42
```

The equivalent machine image needs to be available in the DR Region.

Otherwise disaster workflow becomes:

```text
find source image
      ↓
copy/build it
      ↓
wait
      ↓
launch DR
```

which consumes precious RTO.

For Pilot Light/Warm Standby, you normally want the deployment artifact available **before** disaster declaration.

---

# 37.166 Golden image principle

Don't let DR depend on:

```text
"the currently running Mumbai EC2 instance."
```

Better:

```text
Packer/image pipeline
       │
       ├── Mumbai AMI
       └── Singapore AMI
```

or rebuild/copy in a controlled release pipeline.

Then both environments originate from:

```text
the same build definition.
```

---

# 37.167 Secrets Manager — critical DR dependency

Application may require:

```text
DB password

API keys

JWT key

third-party credential
```

If secret exists only in:

```text
ap-south-1
```

then the application in Singapore may not have the configuration it needs.

AWS Secrets Manager supports replicating secrets to multiple Regions. The service replicates encrypted secret data and metadata such as tags and resource policies, and a replica can later be promoted to a standalone secret if needed. ([AWS Documentation][4])

---

# 37.168 Secrets replication architecture

```text
PRIMARY REGION

Secret:
payments/db

       │
       │ replicate
       ▼

DR REGION

Replica:
payments/db
```

Application DR configuration references the Region-local replica.

Normal:

```text
Mumbai ECS
  ↓
Mumbai Secret
```

DR:

```text
Singapore ECS
  ↓
Singapore Secret
```

This reduces a cross-Region dependency during recovery.

---

# 37.169 Secret failover nuance

The Singapore copy begins as a:

```text
replica secret
```

not an independently writable primary secret.

If needed, AWS supports promoting the replica to a standalone secret by stopping replication from the replica Region. ([AWS Documentation][5])

That matters for post-failover operations.

Suppose production fails over permanently to Singapore.

Now you may need:

```text
Singapore secret
```

to become independently maintained.

---

# 37.170 KMS affects secret replication

Secrets Manager replication relies on encryption.

AWS's current troubleshooting guidance notes that if the encryption key used for the primary secret is disabled or deleted, replication can fail. ([AWS Documentation][6])

So:

```text
Secret replication
```

is not an isolated feature.

It depends on:

```text
Secrets Manager
+
KMS
+
permissions
```

Again:

> DR is a dependency graph.

---

# 37.171 KMS mental model

Don't assume:

```text
"Primary has a KMS key,
so Singapore automatically has it."
```

Regional encryption architecture must be planned.

For example, you might design:

```text
Mumbai KMS key

Singapore KMS key
```

with policies allowing Region-specific resources to use their local key.

Or evaluate AWS KMS multi-Region keys where their semantics and use case fit.

We'll go deeper into the data/encryption layer in Part 6.

For now, remember:

```text
encrypted copy exists
```

does not guarantee:

```text
DR application can decrypt it.
```

---

# 37.172 ACM certificates are regional

This is another classic DR trap.

AWS Certificate Manager certificates are **regional resources**. If the same domain needs certificates on Regional Elastic Load Balancers in multiple Regions, you must request or import certificates in each Region. ([AWS Documentation][7])

Example:

```text
api.example.com
```

Primary ALB:

```text
ap-south-1

ACM cert A
```

DR ALB:

```text
ap-southeast-1

ACM cert B
```

You can't simply reuse the Mumbai certificate ARN on the Singapore ALB.

---

# 37.173 Production outage scenario

Everything is ready in Singapore:

```text
VPC              ✓
ECS              ✓
DB               ✓
Secrets          ✓
ECR image        ✓
ALB              ✓
```

Traffic shifts.

But HTTPS fails.

Why?

```text
No ACM certificate
in ap-southeast-1.
```

That's exactly the kind of dependency a DR readiness checklist should catch.

---

# 37.174 CloudFront certificate exception

Remember from our earlier AWS work:

CloudFront is different.

For an ACM certificate used by CloudFront, AWS requires the certificate in:

```text
us-east-1
```

regardless of the Regional origins behind the distribution. ([AWS Documentation][8])

Therefore:

```text
Regional ALB certificates
→ each ALB Region


CloudFront ACM certificate
→ us-east-1
```

Very important distinction.

---

# 37.175 Pilot Light certificate readiness

Even if DR ALB isn't actively serving traffic yet, you may still want:

```text
ACM certificate validated
```

before disaster.

Why?

Because certificate issuance/validation shouldn't be an emergency-path dependency.

Pilot Light principle:

> Pre-create things whose emergency creation introduces uncertain time or manual steps.

---

# 37.176 Warm Standby certificate readiness

For Warm Standby it's even clearer.

If DR ALB is already functional:

```text
HTTPS
```

should already work.

Therefore:

```text
certificate
listener
security group
health check
```

must all be valid before the disaster.

---

# 37.177 Load balancer difference

Pilot Light might have:

```text
VPC ready
DB ready
IaC ready

ALB possibly ready

App capacity minimal/stopped
```

Warm Standby should normally have:

```text
ALB     ✓
listener ✓
target group ✓
healthy app targets ✓
```

because the environment is supposed to be functional.

---

# 37.178 Auto Scaling becomes the recovery accelerator

Warm Standby:

```text
DR desired capacity = 2
```

Disaster:

```text
desired capacity = 20
```

Conceptually:

```text
Singapore

Before:
██

After:
████████████████████
```

This is one reason stateless compute is so powerful.

Compute capacity can often be expanded rapidly if:

```text
AMI/image
IAM
networking
quotas
dependencies
```

are already correct.

---

# 37.179 But Auto Scaling cannot fix missing dependencies

Bad thinking:

> "No problem, ASG can launch 50 instances."

But:

```text
AMI missing       ✕
subnet capacity   ✕
quota insufficient ✕
secret missing    ✕
DB unreachable    ✕
```

Then:

```text
ASG launches
```

does not produce:

```text
healthy application.
```

Scaling is only one part of recovery.

---

# 37.180 Service quotas are a DR dependency

Suppose Singapore normally runs:

```text
2 tasks
```

but needs:

```text
200 tasks
```

during recovery.

If your Region/account capacity limits don't support it:

```text
Warm Standby
```

may not scale to:

```text
production capacity.
```

Therefore recovery planning must verify:

```text
EC2 capacity
service quotas
EIP limits
NAT architecture
load balancer capacity behavior
database scale limits
```

before disaster.

AWS's DR guidance repeatedly emphasizes readiness and capacity as part of recovery planning, not merely the existence of standby resources. ([AWS Documentation][9])

---

# 37.181 Capacity during warm standby

Suppose:

```text
Normal DR capacity:
10%
```

During disaster:

```text
must scale:
10% → 100%
```

Question:

> How long does this take?

That's part of RTO.

If ECS scales in 5 minutes but database resizing takes 40 minutes:

```text
database
```

may become your recovery bottleneck.

Same dependency-chain principle from Part 1.

---

# 37.182 Hot Standby

AWS also uses the term:

# Hot Standby

for a standby environment deployed at full production capacity. AWS Well-Architected notes that Warm Standby running at full capacity is considered hot standby. ([AWS Documentation][9])

Think:

```text
Warm Standby

Primary:
████████████

DR:
████


Hot Standby

Primary:
████████████

DR:
████████████
```

The second environment may still be passive in terms of user traffic even though full capacity is running.

---

# 37.183 Hot Standby vs Active/Active

This is important.

## Hot Standby

```text
Region A
ACTIVE

Region B
FULL CAPACITY
but STANDBY
```

## Active/Active

```text
Region A
ACTIVE

Region B
ACTIVE
```

Both may have full infrastructure.

But traffic behavior is different.

---

# 37.184 Database is usually the hardest component

Stateless app tier:

```text
build same image
run more copies
```

Database:

```text
Who is primary?

How is replication done?

Can DR read?

Can DR write?

What happens during promotion?

What replication lag exists?

How do we avoid split brain?

How do we fail back?
```

Therefore Pilot Light/Warm Standby architecture is usually constrained by:

# DATA STRATEGY.

We'll do the full service comparison in Part 6.

---

# 37.185 Warm Standby data example

Conceptually:

```text
Mumbai Database
PRIMARY WRITE

        │
        │ replicate
        ▼

Singapore Database
STANDBY / REPLICA
```

Normal:

```text
writes
  ↓
Mumbai
```

Disaster:

```text
Mumbai X

promote/switch
     ↓

Singapore
becomes write endpoint
```

Then application points to Singapore database.

The exact mechanics depend on the chosen database technology.

---

# 37.186 "Replica exists" does not equal "ready for failover"

Check:

```text
replication healthy?

replication lag?

correct DB version?

parameter groups?

security groups?

subnet groups?

KMS?

capacity?

application connection config?

promotion procedure?
```

Otherwise:

```text
Replica status:
available
```

can still coexist with:

```text
DR application:
broken.
```

---

# 37.187 Queue/event dependencies

Imagine application uses:

```text
SQS
SNS
EventBridge
```

Ask:

```text
Are these queues Regional?

Does equivalent DR infrastructure exist?

What happens to messages in primary Region?

Will producers switch too?

Can consumers safely replay?

Are events duplicated?
```

Multi-Region recovery for event-driven systems can be harder than simple HTTP failover.

We will revisit this when we study active/active and data-layer patterns.

---

# 37.188 Configuration dependencies

Applications often depend on:

```text
SSM Parameter Store

Secrets Manager

feature flags

environment variables

AppConfig

DNS names
```

If DR stack launches with:

```text
DATABASE_HOST=prod-db.ap-south-1...
```

you've successfully started Singapore compute that still depends on Mumbai.

That's not good DR.

---

# 37.189 Region-local dependency rule

A strong DR design asks:

> **What happens if the primary Region is completely unreachable?**

For every dependency, ask:

```text
Can DR use a local equivalent?
```

Example:

```text
Container image
→ Singapore ECR


Secret
→ Singapore replica


Certificate
→ Singapore ACM


Database
→ Singapore replica


Logs
→ Singapore logging destination


App instances
→ Singapore capacity
```

The fewer mandatory calls back to the failed Region, the stronger the Regional isolation.

---

# 37.190 DNS traffic cutover

At some point users must stop going to:

```text
Mumbai
```

and start going to:

```text
Singapore.
```

A simple conceptual pattern:

```text
                    Route53

              ┌────────┴────────┐
              │                 │
              ▼                 ▼
        Mumbai ALB         Singapore ALB
         PRIMARY             SECONDARY
```

Part 4 will go deeply into:

```text
Route53 failover routing
health checks
TTL
DNS caching
failover records
ARC routing control
```

For now:

```text
traffic switch
```

is part of your RTO.

---

# 37.191 Why TTL matters

Suppose DNS TTL is:

```text
300 seconds
```

Some clients/resolvers may cache the old result for up to that caching period.

So even if you update DNS instantly:

```text
10:00:00
```

some users might continue using the old endpoint temporarily.

Therefore DR traffic cutover isn't simply:

```text
change Route53 record
=
every user immediately moves
```

We'll cover exact DNS failure mechanics in Part 4.

---

# 37.192 Pilot Light failure sequence

Let's build a full sequence.

Normal:

```text
Mumbai
FULL PROD

Singapore
VPC              ✓
database replica ✓
images           ✓
secrets          ✓
IAM              ✓
app compute      minimal/not full
```

Disaster:

```text
T0
Mumbai declared unavailable

T1
verify data state

T2
promote/switch DR database

T3
start/scale compute

T4
validate health

T5
change traffic routing

T6
monitor Singapore

T7
declare recovery complete
```

Your measured:

```text
T7 - T0
```

is part of actual recovery time.

---

# 37.193 Warm Standby failure sequence

Normal:

```text
Mumbai
FULL PROD

Singapore
FULL FUNCTIONAL STACK
reduced scale
```

Disaster:

```text
T0
declare primary unavailable

T1
verify/promo data

T2
scale DR

T3
validate

T4
traffic shift

T5
monitor
```

Fewer startup actions.

That's why Warm Standby normally supports tighter RTO than Pilot Light. ([AWS Documentation][1])

---

# 37.194 Pilot Light advantages

```text
Lower standby compute cost

Stateful core already ready

Faster than Backup & Restore

Good middle ground

Less full-time infrastructure
than Warm Standby
```

But disadvantages:

```text
more startup actions

more emergency automation

harder full-stack continuous validation

more RTO uncertainty
```

---

# 37.195 Warm Standby advantages

```text
Full app already operational

Regular testing easier

Fewer deployment steps in disaster

Faster recovery potential

Configuration problems discovered earlier
```

Trade-offs:

```text
more steady-state cost

more resources to patch/update

more cross-Region drift risk

database + app complexity remains
```

---

# 37.196 Cost isn't only AWS resource cost

This is important.

Consider:

```text
Pilot Light
```

may save:

```text
EC2/ECS runtime cost
```

but requires:

```text
more automation
more testing
more complicated runbooks
higher operational burden
```

Warm Standby costs more infrastructure but might simplify recovery.

Therefore true cost includes:

```text
AWS bill
+
engineering time
+
operational risk
+
recovery complexity
+
business outage cost
```

---

# 37.197 Configuration drift

This is one of the biggest standby killers.

Primary:

```text
App version 8.4

SG rule updated

DB parameter updated

secret rotated

new IAM permission

new ECR tag
```

DR:

```text
App version 7.9

old SG

old parameter

old secret

old IAM role
```

Then disaster:

```text
DR starts
```

but application doesn't behave like production.

That's:

# Configuration drift.

---

# 37.198 Avoid drift by using the same delivery path

Better:

```text
Git Commit
    │
    ▼
CI/CD
    │
    ├── deploy Primary
    │
    └── update DR
```

For example:

```text
new container image
    │
    ├── Mumbai ECR
    └── replicated → Singapore ECR
```

ECR's native cross-Region replication helps keep destination container repositories aligned when correctly configured. ([AWS Documentation][2])

---

# 37.199 Deploy code to DR continuously

Warm Standby should ideally not be:

```text
6 months behind production.
```

Application releases should update:

```text
Primary
+
Standby
```

with the standby running at reduced scale.

That way recovery means:

```text
activate the same version
```

not:

```text
deploy six months of changes
during an emergency.
```

---

# 37.200 But be careful with bad deployments

Suppose deployment contains a fatal bug.

If CI/CD immediately deploys it to:

```text
Mumbai
+
Singapore
```

you can destroy both environments.

This is a classic tension:

```text
DR consistency
vs
failure independence
```

Possible controls:

```text
staged rollout

deployment waves

release delay

immutable artifacts

rollback versions

manual approval for standby
```

depending on your requirements.

---

# 37.201 Same infrastructure does not mean same failure

We want:

```text
configuration consistency
```

without blindly reproducing:

```text
every mistake simultaneously.
```

For example:

```text
Region A deployment
      ↓
verification
      ↓
Region B deployment
```

may provide a small safety window.

But larger delay increases drift.

This is an architectural trade-off.

---

# 37.202 Secret rotation issue

Imagine primary secret rotates:

```text
password A
    ↓
password B
```

but DR uses:

```text
password A.
```

Failover:

```text
Singapore app
→ authentication failure
```

Multi-Region Secrets Manager replication can keep replicated secret data synchronized across configured Regions. ([AWS Documentation][4])

This is exactly why recovery dependencies must be automated rather than documented in someone's spreadsheet.

---

# 37.203 Region-local certificates

Same with ACM.

Release process creates:

```text
api.example.com certificate

Mumbai ✓
```

but nobody provisions:

```text
Singapore ✕
```

Warm Standby HTTPS health test should expose that immediately because ACM certificates for Regional load balancers are regional and must exist in each Region. ([AWS Documentation][7])

Pilot Light needs a readiness check to detect it before disaster.

---

# 37.204 Pilot Light readiness test

At least periodically:

```text
Deploy DR application capacity
       ↓
connect to DR data
       ↓
test secrets
       ↓
test certificate
       ↓
test dependencies
       ↓
run smoke test
       ↓
scale back down
```

This proves:

```text
Pilot Light
```

can actually become:

```text
full application.
```

Otherwise you're relying on untested IaC and assumptions.

---

# 37.205 Warm Standby continuous test

Because it is already functional:

```text
Synthetic test
every few minutes

        ↓

Singapore ALB
        ↓
DR app
        ↓
DB read
        ↓
secret
        ↓
dependency
```

Example:

```text
GET /dr-readiness
```

could verify:

```text
app version
database access
secret access
critical dependencies
```

without serving normal production traffic.

---

# 37.206 Read-only testing is often safer

If DR database is only a replica, you may not want readiness tests generating writes.

So test:

```text
read query
```

rather than:

```text
financial transaction write.
```

Your health endpoint should reflect the actual safety rules of the data architecture.

---

# 37.207 Full-scale DR test

Eventually you must test:

```text
Can Singapore handle
100% of production?
```

A reduced Warm Standby stack being healthy doesn't prove that it can scale to production demand.

Test:

```text
scale app
scale DB if needed
load test
verify quotas
measure latency
measure errors
```

then scale back.

---

# 37.208 Capacity ramp is part of RTO

Suppose:

```text
Traffic failover:
2 minutes

Application scale:
5 minutes

Database scale:
25 minutes
```

Your recovery isn't really:

```text
2 minutes.
```

If production capacity isn't sufficient until:

```text
25+ minutes
```

then business recovery must account for that.

---

# 37.209 Graceful degradation

Maybe DR doesn't need to support every production feature immediately.

Example during disaster:

```text
CHECKOUT       ✓
LOGIN          ✓
ORDER STATUS   ✓

RECOMMENDATION ✕
ANALYTICS      ✕
REPORT EXPORT  ✕
```

This can reduce required DR capacity.

Business question:

> Which capabilities are critical during recovery?

This is often more cost-effective than insisting that every background feature recover simultaneously.

---

# 37.210 Critical-path recovery

Production service graph:

```text
                     E-COMMERCE

           ┌────────────┼─────────────┐
           ▼            ▼             ▼
       Checkout      Search      Analytics
           │
           ▼
       Payment
```

DR priority:

```text
Checkout       P0
Payment        P0
Login          P0

Search         P1

Analytics      P3
```

Your Warm Standby can prioritize:

```text
P0 capacity first
```

to meet RTO.

---

# 37.211 Regional health endpoint

A useful pattern:

```text
https://dr-api.example.com/health
```

may validate:

```text
ALB
   ↓
ECS
   ↓
DB read
   ↓
Secret
```

But make sure health checks don't create external side effects or depend on a system outside your DR scope in a way that causes false negatives.

---

# 37.212 External dependencies

Suppose payment service relies on:

```text
third-party fraud provider
```

that only allowlists:

```text
Mumbai NAT public IP.
```

Fail over to Singapore:

```text
Singapore NAT EIP
```

is not allowlisted.

Application fails.

You need a DR inventory that includes:

```text
third-party IP allowlists

webhooks

SaaS credentials

partner VPNs

firewall rules

external DNS

licenses
```

not just AWS resources.

---

# 37.213 Hybrid-network dependency

Remember Lesson 36.

What if Singapore DR must access:

```text
corporate Oracle
```

but your corporate network has connectivity only to:

```text
Mumbai.
```

Then:

```text
DR app ✓
```

but:

```text
Hybrid dependency ✕
```

Your DR architecture might require:

```text
VPN/DX connectivity to both Regions
```

or an intentional inter-Region path, depending on architecture.

Lesson 36 directly feeds Lesson 37.

---

# 37.214 Region-specific DNS dependencies

Suppose:

```text
Singapore app
```

must resolve:

```text
oracle.corp.internal
```

Do your hybrid DNS Resolver rules/endpoints exist and function in the recovery architecture?

If not:

```text
IP route may work
```

but:

```text
application hostname resolution fails.
```

Again:

```text
DR dependency graph.
```

---

# 37.215 Warm Standby network checklist

Before declaring DR ready:

```text
VPC                 ✓

subnets             ✓

NACL                 ✓

SG                   ✓

NAT/egress           ✓

VPC endpoints        ✓

TGW/VPN/DX           ✓ if needed

hybrid DNS           ✓ if needed

Route53              ✓

WAF                  ✓

certificates         ✓
```

No assumption that the application layer alone defines readiness.

---

# 37.216 IAM is another hidden dependency

Suppose DR ECS task starts.

Task role expects:

```text
s3:GetObject

secretsmanager:GetSecretValue

kms:Decrypt

sqs:ReceiveMessage
```

but Singapore deployment's IAM conditions/resource ARNs don't match.

App starts:

```text
container RUNNING
```

but logs:

```text
AccessDenied
```

So:

```text
ECS RUNNING
≠
application recovered.
```

---

# 37.217 Region hard-coding in IAM

Watch for policies such as:

```text
arn:aws:secretsmanager:ap-south-1:...
```

when DR needs:

```text
ap-southeast-1
```

or:

```text
arn:aws:kms:ap-south-1:...
```

that don't match DR resources.

Multi-Region recovery often exposes hard-coded ARNs/Region assumptions that never appeared in single-Region operation.

---

# 37.218 Application code can be Region-coupled too

Bad:

```python
region = "ap-south-1"
```

Better pattern:

```text
region
comes from environment/runtime configuration
```

Then:

```text
Mumbai:
AWS_REGION=ap-south-1

Singapore:
AWS_REGION=ap-southeast-1
```

Portable application design makes DR much easier.

---

# 37.219 Database endpoint hard-coding

Bad:

```text
db-prod.cluster-abc.ap-south-1.rds.amazonaws.com
```

embedded in application code.

Better:

```text
DB endpoint
       ↓
configuration/secret
       ↓
Region-specific value
```

or another carefully designed indirection mechanism.

Then DR only changes:

```text
configuration
```

instead of recompiling the application.

---

# 37.220 Region abstraction

Application should ideally ask:

```text
"What is my database?"
```

not:

```text
"Connect specifically to Mumbai forever."
```

Possible abstractions:

```text
Secrets Manager
Parameter Store
DNS
service discovery
environment configuration
```

We'll examine the best patterns in the data-layer parts.

---

# 37.221 Pilot Light Terraform pattern

Conceptually:

```hcl
module "dr_network" {
  source = "./modules/network"

  region = "ap-southeast-1"
}

module "dr_database" {
  source = "./modules/database"

  mode = "replica"
}

module "dr_app" {
  source = "./modules/app"

  desired_count = 0
}
```

During recovery:

```text
desired_count
0 → production scale
```

This is conceptual; exact values depend on service/application type.

---

# 37.222 Warm Standby Terraform pattern

```hcl
module "dr_app" {
  source = "./modules/app"

  desired_count = 2
}
```

Production:

```hcl
module "primary_app" {
  source = "./modules/app"

  desired_count = 20
}
```

Same module.

Different:

```text
capacity.
```

That's an elegant Warm Standby pattern.

---

# 37.223 Capacity variables

You can model:

```hcl
variable "environment_mode" {
  type = string
}
```

or explicit values:

```hcl
app_desired_capacity
app_max_capacity
worker_capacity
db_size
```

For example:

```text
PRIMARY

app desired = 20
max = 100


DR NORMAL

app desired = 2
max = 100
```

Notice something:

```text
DR desired is small
```

but:

```text
max should support recovery demand.
```

---

# 37.224 Don't set DR max too low

Bad:

```text
DR desired = 2
DR max     = 4
```

Primary load needs:

```text
40.
```

Disaster:

```text
scale!
```

ASG replies:

```text
max capacity = 4
```

You built a Warm Standby that cannot become production.

---

# 37.225 Database capacity matters similarly

Suppose DR DB normally supports:

```text
read-only checks
```

but during disaster receives:

```text
all customer writes.
```

A tiny instance/class may:

```text
promote successfully
```

then collapse under load.

So:

```text
RTO
```

must include any required DB scale operation or pre-provision sufficient capacity.

---

# 37.226 Capacity vs cost decision

You can choose:

```text
DR database already full-size
```

Higher cost:

```text
$$$$
```

but faster failover.

Or:

```text
DR database small
```

Lower cost:

```text
$$
```

but requires scale operation:

```text
longer RTO.
```

That's exactly the recovery spectrum.

---

# 37.227 Pilot Light decision example

Workload:

```text
internal CRM

RTO:
90 minutes

RPO:
5 minutes
```

You might choose:

```text
replicated data
network ready
images ready
secrets ready

compute mostly off
```

because 90-minute RTO may give enough time to bring compute online.

---

# 37.228 Warm Standby decision example

Workload:

```text
customer checkout

RTO:
15 minutes

RPO:
very small
```

You may decide:

```text
working Singapore stack
+
small application capacity
+
data replication
+
prevalidated certificates/secrets
+
fast scaling
```

fits better.

Still, actual database technology determines achievable RPO and failover semantics.

---

# 37.229 The business must define minimum capacity

A useful question:

> During DR, must we serve **100%** of normal traffic immediately?

Possible answer:

```text
No.

First 15 min:
50%

Within 30 min:
100%
```

Then your recovery architecture can support staged ramp-up.

This may materially reduce standby cost.

---

# 37.230 Operational recovery tiers

Example:

```text
T+0–5 min

activate DR


T+5–15

critical APIs
50% capacity


T+15–30

full checkout


T+30–60

background workers


T+60+

analytics/reporting
```

That's much more realistic than:

```text
everything instantly perfect.
```

---

# 37.231 Failback starts during failover design

Never build Singapore only to answer:

```text
How do we get there?
```

Also ask:

```text
How do we leave it?
```

During outage, Singapore starts accepting writes.

When Mumbai returns:

```text
Singapore has newer data.
```

You cannot simply route users back to stale Mumbai.

---

# 37.232 Failback flow

Conceptually:

```text
Mumbai failure
    ↓
Singapore promoted
    ↓
Singapore receives new writes
    ↓
Mumbai restored
    ↓
synchronize Mumbai from Singapore
    ↓
validate Mumbai
    ↓
prepare traffic shift
    ↓
fail back
```

This can be significantly harder than failover.

---

# 37.233 The old primary may become the new standby

A common recovery pattern:

```text
Before:

Mumbai      PRIMARY
Singapore   STANDBY


After disaster:

Singapore   PRIMARY


Mumbai returns:

Mumbai      NEW STANDBY
```

Once stable:

```text
either keep Singapore primary
```

or deliberately fail back later.

Don't rush just because the original Region is back online.

---

# 37.234 Why rushed failback is dangerous

Suppose Mumbai becomes reachable for:

```text
3 minutes.
```

You immediately switch back.

Then Mumbai fails again.

Now:

```text
Mumbai → Singapore → Mumbai → Singapore
```

customers suffer repeated disruption.

Operationally you may require:

```text
stability window

data validation

capacity validation

business approval
```

before failback.

---

# 37.235 Failure detection vs disaster declaration

This distinction is important.

Health monitor sees:

```text
one ALB health check fail
```

Does that mean:

```text
promote entire secondary Region?
```

Usually not automatically.

You need criteria for:

```text
failure
```

versus:

```text
disaster.
```

Example:

```text
single EC2 failure
→ Auto Scaling


single AZ impairment
→ Multi-AZ handling


regional application outage
→ maybe regional recovery


confirmed regional disaster
→ execute DR
```

Do not use Region-level DR to solve every small failure.

---

# 37.236 HA before DR

Your primary Region should already tolerate:

```text
instance failure

AZ failure

container failure

DB instance failure
```

through Multi-AZ/HA mechanisms.

DR becomes the next layer.

Never make Singapore compensate for a Mumbai application that cannot survive one EC2 dying.

---

# 37.237 Pilot Light / Warm Standby checklist

Before declaring either ready, ask:

```text
NETWORK
───────
VPC?
Subnets?
Routes?
Security?
Hybrid connectivity?


COMPUTE
───────
Images?
Capacity?
Quotas?
Launch configuration?


DATA
────
Replication?
Lag?
Promotion?
Backup?


SECURITY
────────
IAM?
KMS?
Secrets?
Certificates?


APP
───
Correct release?
Configuration?
Dependencies?


TRAFFIC
───────
DNS?
Health checks?
Failover method?


OPERATIONS
──────────
Monitoring?
Runbook?
Automation?
Testing?
Failback?
```

If any major category is missing:

```text
DR plan incomplete.
```

---

# 37.238 Pilot Light vs Warm Standby table

| Area                       | Pilot Light               | Warm Standby                  |
| -------------------------- | ------------------------- | ----------------------------- |
| Critical data              | Ready/replicating         | Ready/replicating             |
| Network                    | Usually prebuilt          | Prebuilt                      |
| Full application stack     | Not necessarily running   | Running                       |
| Compute capacity           | Zero/minimal              | Reduced                       |
| ALB/app endpoint           | May be prepared           | Operational                   |
| Routine full-stack testing | Harder                    | Easier                        |
| Recovery work              | Start/deploy + scale      | Mostly scale                  |
| Typical relative RTO       | Higher                    | Lower                         |
| Steady-state cost          | Lower                     | Higher                        |
| Drift risk                 | Significant if not tested | Easier to detect continuously |

The fundamental AWS distinction is whether a full functioning scaled-down workload already runs in the recovery Region. ([AWS Documentation][1])

---

# 37.239 Never-forget artifact rule

No DR application should depend on fetching its executable artifact solely from the failed Region.

Examples:

```text
Container
→ replicate ECR


AMI
→ prepare/copy to DR


Lambda package
→ ensure DR deployment pipeline/artifact exists


Static application assets
→ cross-Region strategy
```

ECR's current native replication capability makes cross-Region container-image availability straightforward to automate. ([AWS Documentation][2])

---

# 37.240 Never-forget configuration rule

No DR application should require:

```text
Mumbai secret

Mumbai DB endpoint

Mumbai-only ACM certificate

Mumbai-only KMS access
```

during a Mumbai outage.

Secrets Manager supports Region replicas, while ACM certificates for Regional load balancers must be separately provisioned in each Region. ([AWS Documentation][4])

---

# 37.241 One sentence defining Pilot Light

Interview answer:

> **Pilot Light keeps critical core components—especially the data and essential recovery foundation—ready in the recovery Region, while additional application infrastructure is started, deployed, or scaled after disaster declaration.**

That matches AWS's classic DR model. ([AWS Documentation][1])

---

# 37.242 One sentence defining Warm Standby

Interview answer:

> **Warm Standby maintains a complete, functional copy of the workload in another Region at reduced capacity and scales that environment during failover.**

That's directly aligned with AWS guidance. ([AWS Documentation][1])

---

# 37.243 Interview trap

> "Pilot Light is just a smaller Warm Standby."

Not quite.

The important distinction isn't merely:

```text
number of instances.
```

It's:

```text
Is the complete application stack
already operational?
```

If yes at reduced capacity:

```text
Warm Standby.
```

If critical core exists but significant app components still need activation/deployment:

```text
Pilot Light.
```

---

# 37.244 Another trap

> "Warm Standby is active/active."

No.

Warm Standby can be:

```text
ACTIVE/PASSIVE
```

where the secondary stack is functional but not normally receiving normal production traffic.

Active/active means both Regions actively serve production.

We'll cover that in Part 5.

---

# 37.245 Another trap

> "ECR is global."

No.

Amazon ECR registries/repositories are Region-scoped, although ECR supports native cross-Region and cross-account replication. ([AWS Documentation][2])

Therefore container availability in the DR Region must be deliberately designed.

---

# 37.246 Another trap

> "One ACM certificate works on both regional ALBs."

No.

ACM certificates are Regional resources; request/import one in each Region for Regional services such as Elastic Load Balancing. ([AWS Documentation][7])

CloudFront is the special case using an ACM certificate in `us-east-1`. ([AWS Documentation][10])

---

# 37.247 Another trap

> "Replicated secret can always be edited independently."

A Secrets Manager replica is managed as part of the replication relationship. AWS provides a promotion operation to make a replica standalone before independently managing replication from that Region. ([AWS Documentation][4])

---

# 37.248 A very strong DR design question

When reviewing architecture, ask:

> **If I turn off all access to `ap-south-1` right now, what in `ap-southeast-1` still secretly depends on it?**

Then inspect:

```text
container registry
secrets
KMS
database
DNS
IAM
logging
metrics
third-party integrations
hybrid network
artifact store
config
```

Anything mandatory pointing back to Mumbai is a potential Regional recovery dependency.

---

# 37.249 Failure-domain purity

A Multi-Region design is strongest when:

```text
Region B
```

doesn't require:

```text
Region A
```

to become operational.

Think:

```text
Singapore
   │
   ├── local app
   ├── local images
   ├── local secrets
   ├── local certificate
   ├── local data capability
   └── local dependencies
```

rather than:

```text
Singapore
   │
   ├── app local
   ├── image from Mumbai
   ├── secret from Mumbai
   └── DB from Mumbai
```

The second is not strong Region isolation.

---

# 37.250 Part 3 final architecture

```text
                         GLOBAL USERS
                              │
                              ▼
                          Route 53
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼

                PRIMARY REGION       DR REGION
                 ap-south-1        ap-southeast-1

                   ALB                 ALB
                    │                   │
                ECS × 20            ECS × 2
                    │                   │
                    ▼                   ▼
                  DATA ──────────→ DR DATA
                    │
                    │
               replication

          ECR ─────────────────────→ ECR
          images                       images

          Secrets ─────────────────→ Secrets
                                    replicas

          ACM cert                 ACM cert
          Mumbai                   Singapore

          KMS                      KMS
          configuration            configuration

          VPC                      VPC
          10.64/16                 10.80/16

          Monitoring               Monitoring

                              │
                              ▼
                         DR TESTING
```

For:

```text
PILOT LIGHT
```

reduce/stop substantial application components.

For:

```text
WARM STANDBY
```

keep the complete stack operational at reduced capacity.

---

# 37.251 The five things to remember forever

```text
1.

Pilot Light keeps the
critical recovery core alive.


2.

Warm Standby keeps the
whole application alive,
but smaller.


3.

DR must include artifacts,
secrets, certificates, IAM,
networking and data—
not only compute.


4.

If DR secretly depends on
the failed Region,
you don't have clean
Regional isolation.


5.

Failover is incomplete
until failback has
also been designed.
```

---

# Lesson 37 progress

```text
Part 1  HA vs DR + RTO/RPO               ✓

Part 2  Backup & Restore                  ✓

Part 3  Pilot Light + Warm Standby        ✓

Part 4  Active/Passive Multi-Region       NEXT

Part 5  Active/Active Multi-Region

Part 6  Multi-Region Data Layer

Part 7  Application Recovery Controller

Part 8  DR Automation / Testing / Chaos

Part 9  Complete DR Capstone

Part 10 Final Revision
```

# Next — Lesson 37, Part 4

## Active/Passive Multi-Region — Route 53 Failover, Health Checks & Traffic Cutover

Next we'll answer the question we've deliberately postponed:

> **The Singapore recovery stack is ready—but how do users actually get moved from Mumbai to Singapore?**

We will build:

```text
                        USERS
                          │
                       Route 53
                          │
                 ┌────────┴────────┐
                 │                 │
              PRIMARY          SECONDARY
                 │                 │
                 ▼                 ▼

            ap-south-1       ap-southeast-1
                 │                 │
                ALB               ALB
                 │                 │
                App               App
```

Then we'll go deep into **Route 53 failover routing, health checks, alias records, TTL, DNS caching, health-check failure thresholds, application vs infrastructure health, false failovers, dependency health, DNS propagation myths, weighted canary recovery, Global Accelerator comparison, failover sequencing, data promotion before traffic shift, split-brain risks, and production runbooks**.

[1]: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html?utm_source=chatgpt.com "Disaster recovery options in the cloud"
[2]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/replication.html?utm_source=chatgpt.com "Private image replication in Amazon ECR"
[3]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry-settings-examples.html?utm_source=chatgpt.com "Private image replication examples for Amazon ECR"
[4]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/replicate-secrets.html?utm_source=chatgpt.com "Replicate AWS Secrets Manager secrets across Regions"
[5]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/standalone-secret.html?utm_source=chatgpt.com "Promote a replica secret to a standalone secret in AWS ..."
[6]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/replicate-secrets_troubleshoot.html?utm_source=chatgpt.com "Troubleshoot AWS Secrets Manager replication"
[7]: https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html?utm_source=chatgpt.com "What is AWS Certificate Manager?"
[8]: https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html?utm_source=chatgpt.com "Import certificates into AWS Certificate Manager"
[9]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_disaster_recovery.html?utm_source=chatgpt.com "REL13-BP02 Use defined recovery strategies to meet the ..."
[10]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html?utm_source=chatgpt.com "Requirements for using SSL/TLS certificates with CloudFront"
