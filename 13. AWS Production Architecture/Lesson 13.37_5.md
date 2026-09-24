# Module 13 — AWS Production Architecture

# Lesson 37 — Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 5: Multi-Region Active/Active — Distributed Systems, Multi-Writer Data & Global Traffic

We now make the biggest architectural change in Lesson 37.

Previously:

```text
ACTIVE/PASSIVE

Mumbai
ACTIVE
████████████

Singapore
STANDBY
████
```

Now:

```text
ACTIVE/ACTIVE

Mumbai
ACTIVE
████████████

        +

Singapore
ACTIVE
████████████
```

Both Regions are serving **real production traffic at the same time**.

AWS characterizes Multi-Region active/active as the most aggressive classic DR pattern, potentially approaching zero recovery time and near-zero recovery point objectives. But AWS also warns that synchronizing data and resolving concurrent writes across Regions introduces significant complexity. ([AWS Documentation][1])

---

# 37.331 First mental model — Active/Active changes DR completely

In Warm Standby:

```text
NORMAL

Mumbai
   │
100% users
   │
   ▼
Application

Singapore
READY
but passive
```

During disaster:

```text
Mumbai X
   │
   ▼
activate Singapore
   │
   ▼
100% users → Singapore
```

Active/active:

```text
                   USERS
                     │
                Global Routing
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
       Mumbai                Singapore
       ACTIVE                 ACTIVE
          │                     │
        Users                  Users
          │                     │
          └─────────DATA────────┘
```

There may be **no completely idle DR Region**.

Both environments are production.

---

# 37.332 Failure becomes traffic evacuation

Suppose normally:

```text
Mumbai      60%
Singapore   40%
```

Mumbai fails:

```text
Mumbai      X
Singapore   100%
```

Conceptually:

```text
BEFORE

        60%                40%
Users ───────→ Mumbai   Singapore ←────── Users


AFTER

Mumbai X

All surviving traffic
        │
        ▼
   Singapore
```

For a truly multi-active application/data architecture, recovery can sometimes involve primarily **routing traffic away from the impaired Region**, rather than building a standby stack from scratch. AWS nevertheless emphasizes that the exact RTO/RPO depends on data replication, application behavior, and how conflicts are handled. ([AWS Documentation][1])

---

# 37.333 The huge trap

Do not think:

```text
Two ALBs
+
Two ECS clusters
=
Active/Active architecture complete
```

Compute is the easy part.

The difficult part is:

```text
                 DATA

                   │
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
      Writes    Consistency  Conflicts
        │          │          │
        ▼          ▼          ▼
     Ordering   Replication  Ownership
```

AWS explicitly calls data management one of the most difficult aspects of Multi-Region architecture because geographic distance creates unavoidable replication latency and forces trade-offs among consistency, availability, and latency. ([AWS Documentation][2])

---

# 37.334 Active/Active APPLICATION does not automatically mean Active/Active WRITES

This distinction is extremely important.

You can have:

```text
Mumbai App        ACTIVE
Singapore App     ACTIVE
```

while the database is:

```text
Mumbai DB
WRITER

Singapore DB
READ ONLY
```

That's still an active/active **application-serving** architecture.

But it isn't a true:

```text
Multi-Region multi-writer
database architecture.
```

We therefore need to distinguish multiple active/active designs.

---

# 37.335 Three major active/active data patterns

Think:

```text
ACTIVE/ACTIVE
     │
     ├── Model A
     │   Both Regions serve users
     │   SINGLE WRITE REGION
     │
     ├── Model B
     │   Both Regions write
     │   DIFFERENT DATA SHARDS
     │
     └── Model C
         Both Regions write
         SAME LOGICAL DATASET
```

Complexity increases dramatically as we move down.

---

# 37.336 Model A — Active/Active compute, single writer

Architecture:

```text
                     USERS
                       │
                Global Routing
                 /           \
                ▼             ▼

             Mumbai        Singapore
               APP            APP
                │              │
              READ           READ
                │              │
                └──────┬───────┘
                       ▼
                    WRITER
                    Mumbai
```

Singapore can:

```text
serve application traffic
perform local reads
```

but write requests ultimately go to:

```text
Mumbai
```

This is much easier to reason about than true multi-writer.

---

# 37.337 Aurora Global Database is a good example of this distinction

Traditional **Aurora Global Database** currently has:

```text
ONE primary Region
        │
        ├── writer
        │
        ▼
   asynchronous
   replication
        │
 ┌──────┴──────────┐
 ▼                 ▼
Secondary      Secondary
Region         Region
read-oriented  read-oriented
```

AWS currently supports one primary Aurora cluster and up to 10 secondary Regions. ([AWS Documentation][3])

So don't say:

> "Aurora Global Database means every Region is a database writer."

That is incorrect.

---

# 37.338 Aurora write forwarding does NOT make every Region an independent writer

Aurora Global Database supports write forwarding from secondary clusters for supported configurations.

Application in Singapore can send a write through its local secondary endpoint:

```text
Singapore App
     │
     ▼
Singapore Aurora secondary
     │
     │ write forwarding
     ▼
Mumbai Primary
     │
     ▼
WRITE OCCURS
     │
     ▼
replicate back
```

The actual data change still occurs in the **primary cluster** and is then replicated to the secondary Regions. ([AWS Documentation][4])

So:

```text
write forwarding
≠
independent multi-writer
```

Never forget that.

---

# 37.339 Why single-writer can be attractive

It eliminates many problems involving:

```text
same record updated simultaneously
```

because there is one authoritative write location.

Conceptually:

```text
ALL WRITES
    │
    ▼
ONE AUTHORITY
```

That gives much simpler consistency semantics.

Trade-off:

```text
Singapore user
     │
     ▼
cross-Region write
     │
     ▼
Mumbai
```

may experience higher write latency.

The speed of light and geographic distance do not disappear because we're using AWS. AWS explicitly notes that cross-Region distance creates unavoidable latency trade-offs. ([AWS Documentation][2])

---

# 37.340 Model B — sharded active/active

This is one of my favorite production patterns.

Instead of both Regions writing the exact same customer data, assign ownership.

Example:

```text
CUSTOMERS

India customers
      │
      ▼
    Mumbai
   PRIMARY


Singapore / SEA customers
      │
      ▼
  Singapore
   PRIMARY
```

Architecture:

```text
                      GLOBAL USERS

                  ┌───────┴────────┐
                  │                │
                  ▼                ▼
              Mumbai           Singapore

          Customers A–M      Customers N–Z
             WRITER             WRITER
```

Both Regions are actively writing.

But preferably:

```text
not to the same records.
```

AWS's current Multi-Region guidance specifically recommends considering sharding/cell-style designs because most workloads do not actually need unconstrained active/active writes to the same data. ([AWS Documentation][2])

---

# 37.341 Home Region concept

Suppose:

```text
Customer 1001
Home Region = Mumbai
```

All writes for that customer normally go:

```text
Customer 1001
      │
      ▼
    Mumbai
```

While:

```text
Customer 9001
Home Region = Singapore
```

goes:

```text
Customer 9001
      │
      ▼
 Singapore
```

Now you have:

```text
ACTIVE Region A
+
ACTIVE Region B
```

without having both Regions fight over every item.

---

# 37.342 This is sometimes called a cell/shard architecture

Concept:

```text
GLOBAL ROUTER
     │
     ├──── customer group A ───→ Cell/Region A
     │
     └──── customer group B ───→ Cell/Region B
```

If Mumbai has an outage:

```text
Only Mumbai-owned shard
requires evacuation/recovery.
```

Rather than impacting:

```text
every customer globally.
```

AWS recommends sharding/cell approaches as one way to reduce Multi-Region complexity and limit the scope of impact. ([AWS Documentation][2])

---

# 37.343 Why this can be superior to global multi-writer

Imagine:

```text
Order 123
```

belongs only to Mumbai.

Then Singapore should not normally modify:

```text
Order 123
```

simultaneously.

You avoid:

```text
Mumbai:
OrderStatus = SHIPPED

Singapore:
OrderStatus = CANCELLED
```

at the same moment.

Ownership reduces the conflict domain.

That is often much easier to engineer than arbitrary multi-writer updates.

---

# 37.344 Model C — true multi-active writes

Now the most difficult model:

```text
Mumbai
READ + WRITE

      ↕ replication

Singapore
READ + WRITE
```

Same dataset.

Same logical records can potentially be modified in multiple Regions.

Example:

```text
Mumbai user
updates Customer 42

AT THE SAME TIME

Singapore user
updates Customer 42
```

Now we must answer:

> Which update wins?

This is the heart of distributed data engineering.

---

# 37.345 Example conflict

Initial:

```text
shopping_cart.quantity = 1
```

Mumbai:

```text
quantity = 2
```

Singapore at nearly the same moment:

```text
quantity = 3
```

Replication then sees:

```text
Mumbai version     = 2
Singapore version  = 3
```

Which state is correct?

Possible policies include:

```text
last writer wins

application merge

version checking

conflict rejection

domain-specific resolution
```

There is no universal answer.

---

# 37.346 DynamoDB Global Tables — current active/active example

DynamoDB Global Tables provide multi-Region, multi-active DynamoDB replicas, and any replica can serve reads and writes. ([AWS Documentation][5])

In the traditional/default **Multi-Region Eventual Consistency (MREC)** mode:

```text
Mumbai DynamoDB
READ / WRITE
      │
      │ asynchronous replication
      ▼
Singapore DynamoDB
READ / WRITE
```

Concurrent updates can occur, so DynamoDB uses a last-writer-wins conflict resolution mechanism for MREC replicas. ([AWS Documentation][5])

We'll go much deeper into this in Part 6.

---

# 37.347 Last Writer Wins

Simplified mental example:

```text
Mumbai write
timestamp/version priority A

Singapore write
timestamp/version priority B
```

If DynamoDB determines Singapore's write is the last writer:

```text
Singapore value
      ↓
replicated
      ↓
Mumbai value replaced
```

Eventually:

```text
Mumbai = same result
Singapore = same result
```

That gives convergence.

But it does **not** necessarily preserve both users' intended changes. AWS specifically warns that concurrent Global Tables updates can overwrite one another under last-writer-wins semantics. ([AWS Documentation][6])

---

# 37.348 Dangerous business example

Initial balance:

```text
₹10,000
```

Mumbai request:

```text
withdraw ₹2,000
```

Singapore request:

```text
withdraw ₹5,000
```

A naive application doing:

```text
read balance
modify balance
write balance
```

in two Regions concurrently can produce extremely dangerous behavior.

Financial mutations should not be designed by casually assuming:

```text
eventual replication
will sort everything out.
```

The domain requires carefully chosen transactional/consistency semantics.

---

# 37.349 Active/active forces you to understand consistency

Two common concepts:

```text
STRONG CONSISTENCY

Read returns the latest committed state
according to the system's consistency guarantees.


EVENTUAL CONSISTENCY

A replica can temporarily contain
an older value while replication converges.
```

AWS explicitly highlights consistency/availability/latency trade-offs as fundamental to Multi-Region architecture. ([AWS Documentation][2])

---

# 37.350 Eventual-consistency example

Mumbai writes:

```text
status = PAID
```

At:

```text
12:00:00.000
```

Singapore may briefly still read:

```text
status = PENDING
```

until replication arrives.

Concept:

```text
Mumbai

PENDING
   ↓
PAID
   │
   │ replication delay
   │ ────────────────→
                       Singapore
                       PENDING
                           ↓
                          PAID
```

That window is called:

```text
replication lag / convergence delay
```

in broad terms.

---

# 37.351 Read-your-own-write problem

User writes:

```text
Mumbai
profile.name = Vivek
```

Then their next request is routed:

```text
Singapore
```

before replication arrives.

They read:

```text
old profile name.
```

From the user's perspective:

> "I saved the change and it disappeared."

A system can be technically working as designed and still produce terrible user experience.

---

# 37.352 Session affinity can help

One possible strategy:

```text
User A
      │
      ▼
Mumbai
      │
subsequent requests
      │
      ▼
Mumbai
```

rather than sending each request to an arbitrary Region.

AWS specifically calls out **session affinity** as one of the application concerns that must be considered in Multi-Region active/active designs. ([AWS Documentation][2])

But affinity has trade-offs.

If Mumbai fails:

```text
User A must move to Singapore.
```

So state cannot exist **only** inside Mumbai's application memory.

---

# 37.353 Stateless application servers become even more important

Bad:

```text
Mumbai ECS Task

memory:
session_123 = logged_in
```

Singapore has:

```text
no session_123.
```

Traffic moves to Singapore:

```text
user suddenly logged out
```

or workflow breaks.

Better architectures commonly externalize necessary session state into a suitable shared/replicated mechanism or use self-contained signed tokens where appropriate.

Mental rule:

> **Application instance memory should not be your only durable cross-Region session store.**

---

# 37.354 Sticky sessions are not global state replication

An ALB may keep a user on one target.

That doesn't solve:

```text
Region A disappears.
```

Sticky session:

```text
User → App-A
```

is not the same as:

```text
Session state survives Region failure.
```

Very important distinction.

---

# 37.355 Idempotency becomes mandatory for important writes

Imagine client sends:

```text
POST /payments
₹5,000
```

Mumbai processes the payment.

But before the client receives the response:

```text
network timeout
```

The client retries against Singapore:

```text
POST /payments
₹5,000
```

Without protection:

```text
payment 1 = ₹5,000

payment 2 = ₹5,000
```

Customer charged:

```text
₹10,000
```

Terrible.

AWS's Multi-Region guidance explicitly calls out the need for **idempotent transactions** in active/active application design. ([AWS Documentation][2])

---

# 37.356 Idempotency key

Client generates:

```text
Idempotency-Key:
pay-7f91abc
```

Mumbai receives:

```text
pay-7f91abc
```

Processes it.

Singapore later receives retry:

```text
pay-7f91abc
```

System recognizes:

```text
already processed
```

and returns the original logical result rather than performing the business action twice.

Mental rule:

```text
same business request
+
same idempotency key

=
one side effect
```

This is one of the most important active/active application patterns.

---

# 37.357 Retries are normal, not exceptional

Distributed systems experience:

```text
timeouts
partial failures
connection resets
Region shifts
load-balancer retries
client retries
queue retries
```

So application design should assume:

```text
request may arrive more than once.
```

Not:

```text
"HTTP request happens exactly once."
```

Exactly-once side-effect semantics generally require application/data-level mechanisms rather than network optimism.

---

# 37.358 Network partition — the distributed-systems nightmare

Imagine both Regions are healthy individually.

But communication between them fails:

```text
Mumbai       X       Singapore
ACTIVE               ACTIVE
```

Users can still access both:

```text
India users
→ Mumbai

SEA users
→ Singapore
```

But replication between Regions:

```text
BROKEN.
```

What should the system do?

This is:

# Network partition.

---

# 37.359 CAP mental model

For distributed systems, CAP helps us reason about:

```text
C = Consistency

A = Availability

P = Partition tolerance
```

In the presence of an actual network partition, a distributed system must make trade-offs between maintaining consistency and continuing to accept operations independently on both sides.

AWS's Multi-Region guidance explicitly uses this consistency-versus-availability-under-partition framing when discussing distributed data. ([AWS Documentation][2])

---

# 37.360 Availability-first behavior

During partition:

```text
Mumbai continues writes ✓

Singapore continues writes ✓
```

Great availability.

But now both can diverge:

```text
Mumbai data
    !=
Singapore data
```

After network recovery, you must reconcile them.

This is the world of:

```text
eventual consistency
conflict resolution
merge semantics
```

---

# 37.361 Consistency-first behavior

Alternative:

```text
Cannot safely coordinate?
       │
       ▼
stop or reject some writes
```

Availability decreases.

But you avoid conflicting authoritative states.

This may be preferable for certain:

```text
financial
inventory
security
coordination
```

workloads depending on requirements.

There's no universal "better" answer.

Business semantics determine the correct trade-off.

---

# 37.362 Inventory example

Stock:

```text
1 laptop remaining
```

Mumbai customer buys:

```text
1
```

Singapore customer simultaneously buys:

```text
1
```

If both Regions independently believe:

```text
stock = 1
```

both may accept the order.

Result:

```text
2 sales
1 laptop
```

This is an oversell caused by weak coordination.

For some businesses:

```text
acceptable
→ refund one user
```

For others:

```text
unacceptable.
```

Architecture follows domain requirements.

---

# 37.363 Not all data needs the same consistency level

Example e-commerce system:

### Inventory reservation

May require:

```text
stronger coordination
```

### Product reviews

Could tolerate:

```text
eventual consistency
```

### User analytics

Could tolerate:

```text
significant delay
```

### Authentication revocation

May require:

```text
rapid propagation
```

So don't design:

```text
one global consistency rule
for every table.
```

Classify data by business semantics.

---

# 37.364 Active/active can therefore be hybrid inside one application

Example:

```text
                    APPLICATION

                         │
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
       Catalog         Orders       Analytics
      Active/Active     Single       Eventual
       multi-read       writer       replication
```

An application does not need one identical Multi-Region strategy for every subsystem.

This is sophisticated architecture.

---

# 37.365 Current DynamoDB has TWO Global Tables consistency models

As of 2026, DynamoDB Global Tables support:

```text
MREC
Multi-Region Eventual Consistency

and

MRSC
Multi-Region Strong Consistency
```

With MREC, replication is asynchronous and cross-Region reads can temporarily be stale. With MRSC, DynamoDB synchronously replicates writes according to the multi-Region strong-consistency architecture, and strongly consistent reads can return the latest committed item state. ([AWS Documentation][7])

This is a significant modern DynamoDB capability.

---

# 37.366 MRSC is not simply "click strong on any Regions"

Current MRSC Global Tables have architectural constraints.

AWS currently requires exactly three participating Regions, implemented as either:

```text
3 full replicas

or

2 replicas + 1 witness
```

and the Regions must belong to supported Region sets. ([AWS Documentation][8])

We'll cover this carefully in Part 6 rather than memorizing a generic statement like:

```text
DynamoDB Global Tables are always eventual.
```

That statement is now outdated.

---

# 37.367 Important modern note — Aurora DSQL

AWS also now offers **Amazon Aurora DSQL**, a serverless distributed relational database designed with an active/active architecture, including Multi-Region deployments. ([AWS Documentation][9])

Do not confuse:

```text
Aurora Global Database
```

with:

```text
Aurora DSQL
```

They have different architectures and data semantics.

We'll revisit this distinction in Part 6.

---

# 37.368 Global user routing

Once both Regions are serving users, how do we decide:

```text
who goes where?
```

Common possibilities include:

```text
lowest latency

geography

customer home Region

weighted percentage

health

business tenant/shard
```

Traffic policy and data policy need to agree.

---

# 37.369 Route 53 latency-based routing

For example:

```text
India user
       │
       ▼
Route 53
       │
       ▼
Mumbai


Singapore user
       │
       ▼
Route 53
       │
       ▼
Singapore
```

Route 53 latency-based routing selects among configured AWS Regions based on which Region is expected to provide the lowest network latency for the query/client context, and health can also participate in routing decisions. ([AWS Documentation][10])

---

# 37.370 Latency routing architecture

```text
                        USERS
                          │
                          ▼
                       Route53
                  Latency Routing
                    /          \
                   /            \
                  ▼              ▼

             Mumbai ALB     Singapore ALB

             healthy ✓       healthy ✓
```

If one branch becomes unhealthy, Route 53 health-aware configurations can route to an alternative healthy branch. ([AWS Documentation][11])

But remember Part 4:

```text
Route 53 is DNS-based.
```

So caching behavior still matters.

---

# 37.371 Customer-home-region routing can be more important than lowest latency

Suppose Customer 42's writable dataset is owned by:

```text
Mumbai
```

But latency routing happens to send the customer to:

```text
Singapore.
```

Then Singapore may need to:

```text
proxy writes back to Mumbai
```

or relocate the session.

Instead, your routing may deliberately use:

```text
Customer 42
→ Mumbai
```

regardless of small latency differences.

This shows:

> **Traffic routing must understand data ownership.**

You cannot design routing and data independently.

---

# 37.372 Global Accelerator

For supported public TCP/UDP applications:

```text
Client
   │
   ▼
Global Accelerator
   │
 ┌─┴─────────────┐
 ▼               ▼
Mumbai         Singapore
```

Global Accelerator routes toward healthy regional endpoints and can use endpoint-group and endpoint controls to adjust traffic distribution. ([AWS Documentation][12])

This can be attractive for active/active applications that want:

```text
stable global IPs
+
regional endpoint health
+
network-level traffic control
```

---

# 37.373 Traffic dial nuance

You could conceptually operate:

```text
Mumbai endpoint group
100%

Singapore endpoint group
100%
```

for normal active/active operation.

Or during deployment:

```text
Singapore traffic dial
20%
```

to reduce how much of the traffic already assigned toward that endpoint group is accepted there.

AWS explicitly notes that Global Accelerator's traffic dial is applied to traffic already directed toward that endpoint group, **not as a simple percentage of all global requests**. ([AWS Documentation][13])

Important nuance.

---

# 37.374 Capacity rule in Active/Active

Normal:

```text
Mumbai      50%
Singapore   50%
```

If Mumbai disappears:

```text
Singapore must absorb
100%
```

Question:

> Can it?

If Singapore is sized for only:

```text
60%
```

then your failover architecture is:

```text
routing successful

application overloaded.
```

Not good.

---

# 37.375 N+1 Regional capacity thinking

If two Regions are equal:

```text
Normal:
50 + 50
```

a common resilience question is whether each Region can scale to:

```text
100
```

during failure.

Or perhaps business accepts:

```text
70%
```

with graceful degradation.

The important point:

> Surviving capacity must be part of your RTO design.

Routing traffic somewhere does not create CPU, DB capacity, NAT capacity, or quotas.

---

# 37.376 Graceful degradation active/active

During normal operation:

```text
Checkout            ✓
Search              ✓
Recommendations     ✓
Analytics           ✓
Reporting           ✓
```

One Region fails.

Surviving Region intentionally disables:

```text
Recommendations     ✕
Analytics           ✕
Reporting           ✕
```

but maintains:

```text
Checkout            ✓
Login               ✓
Payment             ✓
```

This can allow the surviving environment to handle critical demand without paying for full duplicate capacity continuously.

---

# 37.377 Multi-Region sessions

Suppose user begins checkout in Mumbai:

```text
cart
shipping
coupon
payment step
```

Then Mumbai fails.

Next request goes Singapore.

Can Singapore reconstruct the workflow?

If not:

```text
session lost.
```

Your choices might include:

```text
replicated session state

durable workflow state

signed/self-contained tokens

reconstruction from database

business-level retry
```

AWS Multi-Region guidance explicitly calls session affinity out as a design concern for active/active workloads. ([AWS Documentation][2])

---

# 37.378 Never store critical workflow state only in process memory

Bad:

```text
ECS Task Mumbai

memory:
checkout_state = step_4
```

Task/Region disappears:

```text
checkout_state disappears.
```

Better:

```text
Durable state
    │
    ▼
database / workflow system /
appropriate resilient store
```

Then another application process can resume.

This principle matters even in single Region, but active/active makes it unavoidable.

---

# 37.379 Event-driven systems are even trickier

Suppose an order emits:

```text
OrderCreated
```

Mumbai queue processes it.

At the same time Region routing changes.

Singapore also receives/replays:

```text
OrderCreated.
```

Could shipping occur twice?

Could email send twice?

Could payment capture twice?

Your consumers should often be designed to tolerate:

```text
duplicate delivery
retries
reordering
```

using business-level IDs and idempotency where appropriate.

---

# 37.380 Event ordering

Suppose events:

```text
1. OrderCreated

2. PaymentCompleted

3. OrderCancelled
```

Cross-Region replication/delivery may not always preserve the intuitive global order your business code assumes.

If consumer sees:

```text
OrderCancelled

then

PaymentCompleted
```

what does it do?

Distributed event design requires:

```text
sequence/version numbers

state-machine rules

idempotency

reconciliation
```

where the domain requires them.

---

# 37.381 Logical disaster still propagates

Active/active protects well against:

```text
Region failure
```

but not necessarily:

```text
bad data mutation.
```

Example:

```sql
DELETE FROM customers;
```

If data replication works perfectly:

```text
Mumbai deleted
      ↓
replication
      ↓
Singapore deleted
```

Your highly available system has now become:

```text
highly available corruption.
```

That's why:

```text
replication
≠
backup
```

Part 2 remains crucial even for active/active.

---

# 37.382 Bad application deployment also propagates

Deployment pipeline:

```text
Version 42
BUG
```

Deploy simultaneously to:

```text
Mumbai
+
Singapore
```

Result:

```text
Region redundancy
but
software failure everywhere.
```

This is a **correlated failure**.

Multi-Region only helps when failure domains are sufficiently independent.

---

# 37.383 Deployment waves

Instead:

```text
Version 42
     │
     ▼
Singapore 5%
     │
validate
     ▼
Singapore full
     │
validate
     ▼
Mumbai
```

or vice versa depending your deployment strategy.

Blue/green and progressive deployment strategies are useful partly because they can limit the blast radius of deployment defects. ([AWS Documentation][14])

Never deploy everywhere at once just because you can.

---

# 37.384 Fault isolation includes deployment isolation

Think:

```text
INFRASTRUCTURE FAILURE DOMAIN

Region A
Region B
```

but also:

```text
CHANGE FAILURE DOMAIN

Deployment wave 1
Deployment wave 2
```

If one pipeline simultaneously changes:

```text
all Regions
all databases
all traffic controls
```

you have recreated a giant shared failure domain at the software/control-plane level.

---

# 37.385 Active/active is not always the best DR architecture

AWS's current Prescriptive Guidance explicitly says that **most workloads using Multi-Region for resilience do not require active/active**. Active/active write-heavy architectures can require intelligent routing, session affinity, idempotency, conflict resolution, and substantial application changes. ([AWS Documentation][2])

This is very important.

Do not become the architect who says:

> "Active/active is always best because downtime is lowest."

Architecture is about requirements and trade-offs.

---

# 37.386 When active/active is compelling

It becomes attractive when business requirements include combinations such as:

```text
very aggressive RTO

global low-latency service

Region-level fault tolerance

large global user base

local reads/writes

continuous capacity utilization
```

and the application/data model is suitable.

The cost is:

```text
distributed-system complexity
+
testing
+
operations
+
cross-Region data handling
+
deployment complexity
```

AWS explicitly frames active/active as the most complex of the classic recovery strategies. ([AWS Documentation][1])

---

# 37.387 A very useful architecture classification

When somebody says:

> "We're active/active."

Ask:

```text
ACTIVE/ACTIVE WHAT?
```

Because it could mean:

```text
Compute?
Traffic?
Reads?
Writes?
Database?
Queues?
Customer shards?
```

Example:

```text
Compute             Active/Active
HTTP traffic         Active/Active
Database reads       Active/Active
Database writes      Single Region
```

That's a perfectly legitimate architecture.

The phrase "active/active" alone is insufficient.

---

# 37.388 Example architecture A — global reads, single writer

```text
                       USERS

              ┌─────────┴─────────┐
              ▼                   ▼

          Mumbai              Singapore
         App ACTIVE           App ACTIVE

          Read ✓               Read ✓
          Write │              Write │
                └──────┬─────────────┘
                       ▼
                 Mumbai Writer
```

Pros:

```text
simpler consistency
local reads
```

Cons:

```text
remote write latency
primary-writer dependency
```

Aurora Global Database is one AWS pattern that fits broadly into this family. ([AWS Documentation][3])

---

# 37.389 Example architecture B — regional shards

```text
                  GLOBAL USERS

              Routing / shard map

            /                   \
           ▼                     ▼

       Mumbai                 Singapore
       ACTIVE                  ACTIVE

Customers 1–500k         Customers 500k–1m

   Writes local              Writes local
```

Pros:

```text
local write latency
fewer same-record conflicts
smaller blast radius
```

Cons:

```text
shard routing
customer migration
evacuation logic
cross-shard operations
```

AWS recommends evaluating sharding/cell techniques to reduce Multi-Region scope and complexity. ([AWS Documentation][2])

---

# 37.390 Example architecture C — true multi-writer

```text
                    GLOBAL USERS

               ┌────────┴────────┐
               ▼                 ▼

            Mumbai           Singapore
            WRITE ✓           WRITE ✓
               │                 │
               └────replication──┘
```

Pros:

```text
local writes
very high regional independence
```

Cons:

```text
consistency semantics
conflict resolution
distributed transactions
write coordination
```

DynamoDB Global Tables are a prominent AWS example of a multi-active database architecture. ([AWS Documentation][5])

---

# 37.391 What happens when Mumbai fails in each model?

### Single writer

If Mumbai owns writer:

```text
Mumbai X
```

you may still need:

```text
database failover/promotion
```

before Singapore becomes fully writable.

So app traffic might already be active/active, but data recovery still has an active/passive component.

---

### Sharded

Mumbai-owned customer shards need:

```text
evacuation
```

to Singapore or another Region.

Singapore-owned customers can continue normally.

Blast radius is reduced.

---

### True multi-writer

If Singapore already accepts the required writes:

```text
Mumbai X

Singapore
continues serving
```

No traditional writer promotion may be required for that data system.

But you still must consider:

```text
capacity
replication uncertainty
routing
sessions
in-flight requests
```

---

# 37.392 RPO "near zero" does not mean magically zero

AWS describes classic Multi-Region active/active as potentially providing near-zero RPO. ([AWS Documentation][1])

But consider asynchronous replication:

```text
Mumbai write accepted
      │
      X Region failure
      │
      ▼
Singapore had not
received it yet
```

Potential data loss:

```text
non-zero.
```

So:

```text
Active/Active
≠
automatic RPO 0
```

The database's replication/consistency mechanism determines the actual behavior.

---

# 37.393 Synchronous replication changes the trade-off

Conceptually:

```text
Mumbai write
      │
      ├────→ remote coordination
      │
      ▼
commit
```

can provide stronger guarantees.

But now:

```text
cross-Region network latency
```

becomes part of write latency.

Again:

```text
Consistency
Availability
Latency
```

are connected.

DynamoDB MRSC and Aurora DSQL are modern AWS examples of managed services that use stronger Multi-Region coordination models, each with its own constraints and semantics. ([AWS Documentation][7])

---

# 37.394 Multi-Region latency cannot be optimized away

Mumbai ↔ Singapore requires a real physical signal to traverse geographic distance.

Therefore synchronous coordination cannot be:

```text
0 ms.
```

This is why workloads must classify:

```text
which operations demand
global coordination
```

versus:

```text
which can be local/eventual.
```

AWS's Multi-Region guidance emphasizes exactly this trade-off between geographic latency and data consistency. ([AWS Documentation][2])

---

# 37.395 Locality-based architecture

Imagine:

```text
India customer data
primarily Mumbai

SEA customer data
primarily Singapore
```

Then most operations avoid:

```text
cross-Region synchronous coordination.
```

Only global operations might require:

```text
cross-Region communication.
```

This can provide a better balance of:

```text
latency
resilience
consistency
```

than treating all records as globally writable everywhere.

---

# 37.396 Active/active security dependencies

Both Regions need:

```text
IAM roles
KMS access
Secrets
Certificates
WAF policy
security groups
logging
guardrails
```

And both are constantly production-critical.

Configuration drift can create:

```text
Mumbai secure
Singapore insecure
```

or:

```text
Mumbai works
Singapore AccessDenied
```

Since both serve users continuously, drift detection and consistent IaC become essential.

---

# 37.397 Region-specific failures should stay Region-specific

Bad architecture:

```text
Mumbai app
     │
     ▼
Singapore central dependency
```

and:

```text
Singapore app
     │
     ▼
same shared dependency
```

If that one dependency fails:

```text
both Regions fail.
```

Your nominal two-Region architecture actually has:

```text
one shared failure domain.
```

Always inventory global/shared dependencies.

---

# 37.398 Example hidden shared dependency

Both applications use:

```text
single third-party API endpoint
```

That provider fails globally.

Result:

```text
Mumbai     broken
Singapore  broken
```

Region redundancy cannot fix:

```text
global external dependency outage.
```

This is why health checks should not assume every dependency becomes healthy simply by changing AWS Region.

---

# 37.399 Observability must become Regional AND global

You need:

```text
Mumbai dashboard

Singapore dashboard

GLOBAL dashboard
```

Example:

```text
GLOBAL

Requests/sec
Error rate
Customer success rate

          │
   ┌──────┴──────┐
   ▼             ▼
Mumbai         Singapore

5xx            5xx
latency        latency
capacity       capacity
replication    replication
```

If one Region degrades, you need to distinguish:

```text
local incident

from

global incident.
```

---

# 37.400 Replication lag becomes a first-class metric

For asynchronous multi-Region data:

```text
Source write
    ↓
replication
    ↓
remote visible
```

you want to understand:

```text
How far behind is the remote Region?
```

Because lag directly affects:

```text
stale reads
RPO
failover safety
user experience
```

The exact metric and meaning depends on the data service.

We'll map them service-by-service in Part 6.

---

# 37.401 Global synthetic tests

Test:

```text
India probe
→ Mumbai

Singapore probe
→ Singapore
```

and potentially:

```text
India probe
→ Singapore

Singapore probe
→ Mumbai
```

for failover readiness.

You don't only want:

```text
endpoint responds.
```

You want:

```text
login works
read works
write works
idempotency works
replication behaves
```

using safe test transactions.

---

# 37.402 Chaos test — kill one Region's application tier

Simulation:

```text
Mumbai ECS desired count
→ 0
```

Expected:

```text
Mumbai health      ✕
Singapore health   ✓
Traffic            → Singapore
```

Then validate:

```text
capacity
latency
errors
sessions
```

This tests compute evacuation.

---

# 37.403 Chaos test — break cross-Region replication

More interesting:

```text
Mumbai      X-link      Singapore
both alive             both alive
```

Now test:

```text
What writes are permitted?

What reads become stale?

Do alerts fire?

Does application know?

Does conflict handling work?
```

This is the test that differentiates:

```text
"we have two Regions"
```

from:

```text
"we understand distributed systems."
```

---

# 37.404 Chaos test — deploy a logical corruption

In lower environment:

```text
write wrong data
```

Verify:

```text
Does it replicate?

Can backup/PITR recover?

Can replication be isolated?

What is the restoration process?
```

Because Region redundancy is not backup protection.

Part 2 and Part 5 must work together.

---

# 37.405 Chaos test — duplicate request

Send:

```text
payment_request ID=abc123
```

to Mumbai.

Force timeout.

Retry:

```text
payment_request ID=abc123
```

to Singapore.

Expected business result:

```text
ONE PAYMENT
```

not:

```text
TWO PAYMENTS.
```

This is how you prove idempotency instead of merely talking about it.

---

# 37.406 Active/active deployment test

Deploy:

```text
Version 42
```

to one Region.

Observe:

```text
errors?
latency?
data compatibility?
```

Then progressively expand.

Do not let:

```text
one bad release
```

become:

```text
global outage
```

by deploying across all active cells simultaneously. Progressive/blue-green deployment practices are specifically intended to reduce change blast radius. ([AWS Documentation][14])

---

# 37.407 Database schema changes become difficult

Suppose Singapore runs:

```text
App v7
```

while Mumbai temporarily runs:

```text
App v8.
```

Schema must often support:

```text
both versions
```

during deployment.

Bad migration:

```sql
ALTER TABLE customers
DROP COLUMN old_field;
```

while Singapore v7 still reads:

```text
old_field
```

Singapore breaks.

Active/active encourages backward-compatible schema migration techniques.

---

# 37.408 Expand-and-contract migration

A useful pattern:

### Step 1 — Expand

```text
add new field/table
keep old
```

### Step 2 — Deploy application

```text
old + new compatible
```

### Step 3 — Migrate data

### Step 4 — Move all Regions to new version

### Step 5 — Contract

```text
remove obsolete schema
```

This avoids having Regional deployment waves depend on an instantly synchronized destructive schema change.

---

# 37.409 Global configuration changes need the same care

Example:

```text
feature flag enabled globally
```

contains bug.

Both Regions break immediately.

You may want:

```text
Region-specific rollout

tenant-based rollout

percentage rollout
```

so configuration changes have manageable blast radius too.

Again:

```text
Regions protect against
infrastructure failures

only if your control plane
doesn't break every Region together.
```

---

# 37.410 Active/active does not eliminate DR runbooks

It changes them.

Instead of:

```text
activate standby
```

you may have:

```text
evacuate Region

increase surviving capacity

disable impaired endpoint

verify data state

handle uncertain writes

replay/reconcile events

monitor surviving Region

restore failed Region

reintroduce traffic
```

There is still substantial operational work.

---

# 37.411 Reintroducing a recovered Region

Mumbai returns.

Do not immediately send:

```text
50% traffic
```

back.

First:

```text
Is data caught up?

Is app current?

Are secrets current?

Are caches safe?

Is capacity healthy?

Are queues synchronized?

Are replication links healthy?
```

Then:

```text
0%
 ↓
1%
 ↓
10%
 ↓
50%
```

as appropriate.

Active/active recovery still needs controlled reintegration.

---

# 37.412 Evacuation vs failback vocabulary

For classic active/passive:

```text
failover
failback
```

makes intuitive sense.

For active/active you will often think:

```text
SHIFT AWAY from Region A

then

REINTRODUCE Region A
```

because Region B was never merely a dormant standby.

That mental model is often cleaner.

---

# 37.413 Interview scenario #1

> Two Regions both serve customers, but all writes go to one Aurora Global Database primary Region. Is the workload active/active?

Best answer:

> The application/traffic tier can be active/active, but the database write architecture is active/single-writer. Aurora Global Database normally has one primary write Region, with secondary Regions receiving replicated data; write forwarding still executes the write on the primary. ([AWS Documentation][3])

Excellent nuanced answer.

---

# 37.414 Interview scenario #2

> Both Regions write to DynamoDB Global Tables. What happens if the same item is concurrently modified in two Regions?

For MREC Global Tables, concurrent updates are reconciled using DynamoDB's last-writer-wins mechanism. The application must therefore understand and tolerate those conflict semantics. ([AWS Documentation][5])

---

# 37.415 Interview scenario #3

> Does DynamoDB Global Tables always mean eventual consistency?

# No — not anymore.

Current Global Tables support both:

```text
MREC
eventual consistency

MRSC
multi-Region strong consistency
```

MRSC has specific topology and Region constraints, so it is not simply interchangeable with MREC. ([AWS Documentation][7])

That's a very current 2026 answer.

---

# 37.416 Interview scenario #4

> Why is idempotency important in Multi-Region active/active?

Because network failures and retries can cause the same logical operation to arrive in another Region after it has already succeeded in the first. Idempotency lets repeated delivery produce one business effect rather than duplicate side effects. AWS explicitly identifies idempotent transactions as a key active/active design requirement. ([AWS Documentation][2])

---

# 37.417 Interview scenario #5

> Can active/active guarantee RPO 0?

No.

The RPO depends on the underlying data replication and consistency mechanism.

For asynchronous replication:

```text
accepted but not yet replicated writes
```

can be at risk during a Regional failure.

AWS describes the general active/active pattern as having **near-zero RPO**, not an automatic universal guarantee of zero data loss. ([AWS Documentation][1])

---

# 37.418 Interview scenario #6

> Why would we use sharding instead of multi-writer everywhere?

Because routing each tenant/customer/data shard primarily to one Region reduces concurrent-write conflicts and limits failure blast radius while still allowing multiple Regions to operate actively. AWS's Multi-Region guidance recommends this kind of cell/shard model for workloads that don't truly require unrestricted multi-active writes. ([AWS Documentation][2])

---

# 37.419 Interview scenario #7

> Route 53 latency routing sends a user to the closest Region. Is that always correct?

No.

Latency may be one factor, but:

```text
data ownership
regulatory requirements
session affinity
capacity
health
```

can require a different Region.

Route 53's latency policy routes toward the Region estimated to give the best latency; the application architecture still has to ensure that Regional choice is compatible with data and business requirements. ([AWS Documentation][10])

---

# 37.420 Interview scenario #8

> Why might active/active be harder than active/passive?

Because you have to continuously manage issues such as:

```text
intelligent traffic routing

session affinity

idempotency

concurrent updates

consistency

replication lag

capacity after Region loss
```

AWS explicitly calls out many of these concerns and notes that most Multi-Region resilience workloads don't necessarily require active/active. ([AWS Documentation][2])

---

# 37.421 Decision framework — should we use active/active?

Ask:

```text
1. Is the RTO aggressive enough
   to justify this complexity?

2. Do users need local Regional latency?

3. Must both Regions accept writes?

4. Can data be partitioned instead?

5. What consistency model is required?

6. Can the business tolerate stale reads?

7. Can conflicts occur?

8. How will conflicts be resolved?

9. Are operations idempotent?

10. How does session state survive?

11. Can one Region handle total load?

12. What happens during partition?

13. How will deployments avoid
    global correlated failure?

14. How will logical corruption recover?

15. How is a Region reintroduced?
```

If those questions don't have clear answers:

```text
active/active architecture
is not finished.
```

---

# 37.422 Active/active architecture maturity levels

### Level 1 — Dual compute

```text
Mumbai App      ACTIVE
Singapore App   ACTIVE

DB writer:
Mumbai only
```

Relatively approachable.

---

### Level 2 — Local reads

```text
Mumbai App
→ Mumbai read

Singapore App
→ Singapore read

Writes
→ Mumbai
```

Better read latency.

---

### Level 3 — Sharded writes

```text
Mumbai
owns customers A

Singapore
owns customers B
```

Both Regions write without normally modifying identical data.

---

### Level 4 — True multi-writer

```text
Mumbai writes dataset
Singapore writes dataset

conflict/consistency semantics required
```

Most complex.

Never jump to Level 4 unless the requirement truly demands it.

---

# 37.423 The strongest never-forget rule from Part 5

> **Active/active is not a networking pattern—it is an application and data-consistency architecture.**

Two healthy ALBs are easy.

The hard part is:

```text
What happens
when two Regions
disagree?
```

---

# 37.424 One-page active/active mental map

```text
                    MULTI-REGION ACTIVE/ACTIVE

                              USERS
                                │
                                ▼
                       GLOBAL TRAFFIC
                  Route53 / Global Accelerator
                         /              \
                        /                \
                       ▼                  ▼

                 MUMBAI                 SINGAPORE
                  ACTIVE                  ACTIVE

                 Compute                Compute
                    │                      │
                    ▼                      ▼

               ┌─────────────────────────────────┐
               │            DATA                 │
               │                                 │
               │  Option A: Single Writer       │
               │                                 │
               │  Option B: Sharded Writers     │
               │                                 │
               │  Option C: Multi-Writer        │
               └─────────────────────────────────┘
                              │
             ┌────────────────┼────────────────┐
             ▼                ▼                ▼

         CONSISTENCY      IDEMPOTENCY       SESSION
             │                │                │
         stale reads       retries         affinity
         conflicts         duplicates      durable state
         partitions

                              │
                              ▼
                         FAILURE TESTING

                      Region evacuation
                      replication failure
                      duplicate requests
                      bad deployment
                      logical corruption
```

---

# 37.425 Final Part 5 rules

Remember these:

```text
1.
Active/active compute
does not automatically mean
multi-writer database.


2.
Single-writer active/active
is much simpler than
arbitrary multi-writer.


3.
Sharding customers/data
can reduce conflict scope.


4.
True multi-writer requires
explicit consistency semantics.


5.
Eventual consistency means
remote reads may temporarily
be stale.


6.
Network partitions force
consistency/availability trade-offs.


7.
Retries mean important
business operations should
be idempotent.


8.
Session state must survive
Regional routing changes.


9.
One surviving Region must
have sufficient capacity.


10.
Replication does not replace
backup.


11.
Multi-Region does not protect
against a bad global deployment.


12.
Deploy changes in waves to
control blast radius.


13.
RPO depends on data technology,
not on the phrase "active/active."


14.
Routing policy must agree with
data ownership.


15.
Active/active should be chosen
because requirements justify it,
not because it sounds advanced.
```

---

# Lesson 37 progress

```text
Part 1
HA vs DR + RTO/RPO                     ✓

Part 2
Backup & Restore                       ✓

Part 3
Pilot Light + Warm Standby             ✓

Part 4
Active/Passive Multi-Region            ✓

Part 5
Active/Active Multi-Region             ✓

Part 6
Multi-Region Data Layer                NEXT

Part 7
Application Recovery Controller

Part 8
DR Automation / Testing / Chaos

Part 9
Complete Multi-Region DR Capstone

Part 10
Final Revision / Interview Mastery
```

# Next — Lesson 37, Part 6

## AWS Multi-Region Data Layer Deep Dive

Now we'll take the hardest part of DR and study each major AWS data system separately:

```text
                     MULTI-REGION DATA

                           │
       ┌───────────────────┼───────────────────┐
       ▼                   ▼                   ▼

      Aurora            DynamoDB              S3
       │                   │                   │
Global Database       Global Tables       CRR / Backup
Writer endpoint       MREC vs MRSC        Replication
Failover              conflicts           Versioning
Write forwarding      witnesses           RTC concepts

                           │
          ┌────────────────┼─────────────────┐
          ▼                ▼                 ▼

        RDS              EFS              EBS
   Cross-Region         backup/          snapshot/
      replicas          replication      cross-Region

                           │
                           ▼

                      Aurora DSQL
                   active/active relational
```

We'll compare **who can write, replication mode, failover mechanics, consistency, RPO/RTO implications, conflict handling, promotion, encryption/KMS, failback, backups, Terraform, and the exact workload each technology fits**.

That next part is where all the RTO/RPO theory becomes concrete database architecture.

[1]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_disaster_recovery.html?utm_source=chatgpt.com "REL13-BP02 Use defined recovery strategies to meet the ..."
[2]: https://docs.aws.amazon.com/prescriptive-guidance/latest/aws-multi-region-fundamentals/fundamental-2.html?utm_source=chatgpt.com "Multi-Region fundamental 2: Understanding the data"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html?utm_source=chatgpt.com "Using Amazon Aurora Global Database"
[4]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-write-forwarding.html?utm_source=chatgpt.com "Using write forwarding in an Amazon Aurora global database"
[5]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html?utm_source=chatgpt.com "Global tables - multi-active, multi-Region replication"
[6]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/globaltables_HowItWorks.html?utm_source=chatgpt.com "Global tables: How it works - Amazon DynamoDB"
[7]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html?utm_source=chatgpt.com "DynamoDB read consistency"
[8]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables_HowItWorks.html?utm_source=chatgpt.com "How DynamoDB global tables work"
[9]: https://docs.aws.amazon.com/aurora-dsql/latest/userguide/what-is-aurora-dsql.html?utm_source=chatgpt.com "When to use Aurora DSQL"
[10]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-latency.html?utm_source=chatgpt.com "Latency-based routing"
[11]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-complex-configs.html?utm_source=chatgpt.com "How health checks work in complex Amazon Route 53 ..."
[12]: https://docs.aws.amazon.com/global-accelerator/latest/dg/introduction-how-it-works.html?utm_source=chatgpt.com "How AWS Global Accelerator works"
[13]: https://docs.aws.amazon.com/global-accelerator/latest/dg/about-endpoint-groups-traffic-dial.html?utm_source=chatgpt.com "Use traffic dials to adjust traffic flow to Regions"
[14]: https://docs.aws.amazon.com/whitepapers/latest/blue-green-deployments/introduction.html?utm_source=chatgpt.com "Introduction - Blue/Green Deployments on AWS"
