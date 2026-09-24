# AWS Masterclass — Lesson 28 Part 5

# Amazon ElastiCache — Valkey, Redis OSS, Memcached, Caching, Sessions & High Availability

We now have:

```text
RDS / Aurora
=
system of record
```

and:

```text
DynamoDB
=
serverless NoSQL database
```

But both can face the same application problem:

```text
Application
    │
    ▼
Database

GET product 123
GET product 123
GET product 123
GET product 123
GET product 123
```

Why repeatedly ask the database to calculate or fetch the same information?

Introduce:

# Cache

```text
                         APPLICATION
                              │
                              ▼
                            CACHE
                              │
                    ┌─────────┴─────────┐
                    │                   │
                 CACHE HIT          CACHE MISS
                    │                   │
                    ▼                   ▼
                 RETURN             DATABASE
                                         │
                                         ▼
                                   populate cache
```

Amazon ElastiCache is AWS's fully managed in-memory caching service and currently supports **Valkey, Redis OSS, and Memcached** engines. ([AWS Documentation][1])

---

# 1. First Rule: Cache ≠ Database

Imagine:

```text
Aurora

PRODUCT#123
price = ₹49,999
```

Cache:

```text
product:123
=
{"price":49999}
```

The database should normally remain the authoritative source.

Think:

```text
                 SOURCE OF TRUTH

                    Aurora
                      │
                      ▼
                 product data
                      │
                      ▼
                  ElastiCache
                 temporary copy
```

If the cache disappears:

```text
application should be able
to rebuild useful cache state
from the source of truth
```

for a normal caching architecture.

### Never forget

```text
DATABASE
=
truth

CACHE
=
acceleration
```

This distinction prevents many disastrous architectures.

---

# 2. Why Caching Works

Suppose an expensive query takes:

```text
40 ms
```

and runs:

```text
20,000 times/sec
```

That is enormous repeated database work.

But if:

```text
95%
```

of requests can be served from memory:

```text
20,000 requests/sec

        │
        ├── 19,000 → cache
        │
        └── 1,000  → database
```

you can dramatically reduce:

```text
database CPU
database I/O
query concurrency
application latency
database cost pressure
```

ElastiCache is designed specifically for low-latency in-memory access and AWS positions it for caching database queries and other frequently accessed data. ([Amazon Web Services, Inc.][2])

---

# 3. But Caching Adds Complexity

Without cache:

```text
App
 │
 ▼
DB
```

Simple.

With cache:

```text
App
 │
 ├──────▶ Cache
 │          │
 │          X stale?
 │          X missing?
 │          X failed?
 │
 └──────▶ Database
```

Now you must reason about:

```text
cache invalidation
TTL
stale data
eviction
cache misses
failover
hot keys
memory limits
stampedes
replication lag
security
```

This is why the famous software-engineering joke exists:

```text
"There are only two hard things
in computer science:

cache invalidation...
..."
```

Caching is powerful precisely because you are deliberately introducing another copy of data.

---

# 4. ElastiCache Engine Choices

Current ElastiCache supports:

```text
Valkey

Redis OSS

Memcached
```

([AWS Documentation][1])

At a high level:

```text
                     ElastiCache

             ┌───────────┼───────────┐
             ▼           ▼           ▼
           Valkey     Redis OSS   Memcached
             │           │           │
        rich data    Redis-compatible simple
        structures     ecosystem      cache
        replication                  model
        HA/sharding
```

---

# 5. Valkey

Valkey is an open-source in-memory data-store engine supported by ElastiCache.

AWS documents that functionality available in Redis OSS 7.2 is available in Valkey 7.2 and later, and supported Redis OSS deployments can be upgraded to Valkey under supported paths. ([AWS Documentation][3])

Valkey supports familiar structures such as:

```text
strings
hashes
lists
sets
sorted sets
streams
Pub/Sub
```

plus richer modern features depending on engine version.

For the rest of the lesson, when architectural behavior applies to both Valkey and Redis OSS, I'll often write:

```text
Valkey / Redis OSS
```

---

# 6. Memcached

AWS recommends considering Memcached when you want things such as:

```text
the simplest caching model
multi-threaded processing
simple object caching
easy horizontal node scaling
```

([AWS Documentation][4])

Think:

```text
key
  │
  ▼
value
```

without many of the richer data-structure and HA capabilities associated with Valkey/Redis OSS.

---

# 7. Quick Engine Mental Model

```text
Need rich data structures?
replication?
HA?
sorted sets?
streams?
Pub/Sub?
distributed counters?
more sophisticated cache behavior?

              │
              ▼
       Valkey / Redis OSS
```

Whereas:

```text
Need extremely simple
distributed object cache?

              │
              ▼
          Memcached
```

This is a workload choice, not a popularity contest.

---

# 8. Important Valkey / Redis OSS Structures

Suppose we need:

### String

```text
user:1001:name
=
"Vivek"
```

### Hash

```text
user:1001

name      = Vivek
plan      = premium
country   = IN
```

### List

```text
recent-events:user1001
```

### Set

```text
online-users
```

### Sorted Set

```text
leaderboard

score → user
```

### Stream

```text
events
```

This lets Valkey/Redis OSS solve more than plain:

```text
key → blob
```

caching.

---

# 9. Cache-Aside — The Most Important Pattern

Also called:

```text
lazy loading
```

AWS describes cache-aside as the most common caching strategy for many application workloads. ([AWS Documentation][5])

Flow:

```text
Application
    │
    ▼
GET product:123
    │
    ▼
Cache
    │
 ┌──┴─────────────┐
 │                │
HIT              MISS
 │                │
 ▼                ▼
return           DB
                  │
                  ▼
               result
                  │
                  ▼
             SET cache
                  │
                  ▼
               return
```

Pseudo-code:

```javascript
async function getProduct(id) {
  const key = `product:${id}`;

  const cached = await cache.get(key);

  if (cached) {
    return JSON.parse(cached);
  }

  const product = await db.getProduct(id);

  await cache.set(
    key,
    JSON.stringify(product),
    { EX: 300 }
  );

  return product;
}
```

---

# 10. Cache Hit

```text
GET product:123
      │
      ▼
CACHE
      │
      ▼
FOUND
      │
      ▼
RETURN
```

Database:

```text
not touched.
```

This is where the latency/capacity benefit comes from.

---

# 11. Cache Miss

```text
GET product:123
      │
      ▼
CACHE
      │
      X
     MISS
      │
      ▼
DATABASE
      │
      ▼
product
      │
      ▼
SET cache
      │
      ▼
return
```

The first request is still expensive.

Later requests become cheap.

---

# 12. Cache Hit Ratio

One of your most important metrics is:

```text
CacheHitRate
```

AWS calculates it from cache hits and misses, essentially:

```text
hits
────────────
hits + misses
```

and provides `CacheHits`, `CacheMisses`, and `CacheHitRate` metrics for Valkey/Redis OSS. ([AWS Documentation][6])

Example:

```text
Cache hits   = 950,000
Cache misses = 50,000

Hit ratio
=
950,000 / 1,000,000

=
95%
```

That's usually far more informative than:

```text
"Redis is running."
```

---

# 13. A Low Hit Rate Can Mean Your Cache Is Useless

Suppose:

```text
CacheHitRate = 5%
```

Then:

```text
95%
```

of lookups still hit the database.

Possible causes:

```text
TTL too short

working set larger than cache

wrong cache keys

data rarely reused

frequent invalidation

evictions

cache warming problem
```

AWS notes that a low cache-hit ratio can indicate many keys are missing, expired, or evicted. ([AWS Documentation][6])

---

# 14. Write Problem

Now suppose database has:

```text
product:123
price = 49999
```

Cache also has:

```text
price = 49999
```

Admin changes DB:

```text
price = 45999
```

but cache still says:

```text
49999
```

Now:

```text
DATABASE
=
correct

CACHE
=
stale
```

Welcome to:

# Cache invalidation

---

# 15. Cache-Aside Write Strategy

Common approach:

```text
Application receives update

        │
        ▼
update database
        │
        ▼
delete cache key
```

Example:

```javascript
await db.updateProduct(id, update);

await cache.del(`product:${id}`);
```

Next reader:

```text
cache miss
    │
    ▼
database
    │
    ▼
fresh value
    │
    ▼
cache repopulated
```

This is often simpler than trying to perfectly update every cached representation of the object.

---

# 16. Why DELETE Is Often Safer Than UPDATE

Suppose product information appears in:

```text
product:123

products:category:laptops

homepage:featured

search:laptop

recommendations:user:1001
```

Updating only:

```text
product:123
```

doesn't update:

```text
homepage:featured
```

Therefore applications often choose:

```text
invalidate related cache entries
```

instead of attempting complex synchronous cache mutation.

Cache design gets harder as the number of derived cached representations grows.

---

# 17. Write-Through

Another pattern:

```text
Application
    │
    ▼
write data
    │
    ├──▶ database
    │
    └──▶ cache
```

so the cache is updated whenever the source changes.

Conceptually:

```text
UPDATE product
      │
      ▼
DATABASE
      │
      ▼
CACHE
```

The benefit:

```text
cache immediately contains fresh data
```

The downside:

```text
every write updates cache

including data
that might never be read
```

AWS's caching-strategy guidance contrasts lazy loading and write-through and recommends TTLs as a way to mitigate tradeoffs. ([AWS Documentation][7])

---

# 18. Cache-Aside vs Write-Through

```text
CACHE-ASIDE

Read miss
   │
   ▼
populate cache

Good:
only cache requested data
```

versus:

```text
WRITE-THROUGH

Every source update
       │
       ▼
also update cache

Good:
fresh cache
```

Neither is universally better.

---

# 19. Write-Behind

Conceptual pattern:

```text
Application
    │
    ▼
Cache
    │
    ▼
acknowledge quickly
    │
    ▼
later persist
to database
```

This can improve apparent write latency but changes the durability model drastically.

If:

```text
cache acknowledges write
```

and then:

```text
cache fails
before DB persistence
```

you may lose acknowledged data.

Therefore don't casually use a cache as a write-behind durability layer for:

```text
payments
orders
bank balances
critical transactions
```

unless the architecture provides explicit durability and recovery guarantees.

For our course:

```text
Cache
normally does NOT become
the authoritative transactional database
```

---

# 20. TTL — Cache Expiration

TTL means:

# Time To Live

Example:

```text
product:123

TTL = 300 seconds
```

After roughly that expiry:

```text
cache key
becomes eligible/expired
```

Then next request performs:

```text
MISS
→ database
→ repopulate
```

AWS explicitly recommends TTLs as a way to combine lazy loading and freshness management. ([AWS Documentation][7])

---

# 21. How Long Should TTL Be?

There is no universal answer.

Think:

```text
How stale may this data become?
```

Examples:

```text
stock price
TTL = seconds
```

```text
product catalog
TTL = minutes
```

```text
country list
TTL = hours/day
```

```text
static configuration
TTL = very long
```

TTL is a business correctness decision, not merely a performance setting.

---

# 22. Short TTL vs Long TTL

### Short TTL

```text
freshness ↑
database load ↑
cache hit rate ↓
```

### Long TTL

```text
cache hit rate ↑
database load ↓
staleness risk ↑
```

So you're balancing:

```text
FRESHNESS
      ▲
      │
      │
      │
      └──────────────▶ PERFORMANCE
```

---

# 23. TTL Jitter

Suppose you cache:

```text
1,000,000 product objects
```

at:

```text
12:00
```

all with:

```text
TTL = 300 seconds
```

At:

```text
12:05
```

they all expire together.

Now:

```text
1,000,000 requests
       │
       ▼
cache misses
       │
       ▼
database
```

This is dangerous.

Instead:

```text
TTL =
300 seconds
+
random jitter
```

for example conceptually:

```text
300–360 seconds
```

so expiry gets distributed over time.

---

# 24. Cache Stampede

This deserves special attention.

Popular key:

```text
homepage
```

expires.

Then:

```text
Request 1 ─┐
Request 2 ─┤
Request 3 ─┤
Request 4 ─┼──▶ cache MISS
...
Request N ─┘
```

All requests then hit:

```text
Aurora
```

simultaneously.

This is:

# Cache stampede

also called:

```text
thundering herd
```

---

# 25. Preventing Cache Stampede

Common techniques include:

```text
TTL jitter

single-flight / request coalescing

short distributed lock around refresh

stale-while-revalidate

background cache refresh

pre-warming
```

Example conceptual flow:

```text
cache miss
    │
    ▼
acquire refresh lock?
    │
 ┌──┴────────┐
 │           │
YES         NO
 │           │
 ▼           ▼
query DB    wait/use stale
 │
 ▼
fill cache
 │
 ▼
unlock
```

This protects the database from simultaneous reconstruction of the same expensive value.

---

# 26. Negative Caching

Suppose bots repeatedly ask:

```text
GET /product/DOES-NOT-EXIST
```

Without negative caching:

```text
request
  ↓
cache MISS
  ↓
DB
  ↓
not found
```

again and again.

Instead cache:

```text
product:DOES-NOT-EXIST
=
NOT_FOUND

TTL = 30 sec
```

Now repeated invalid requests do not continuously hit the DB.

Use shorter TTLs for negative entries because:

```text
the object might legitimately appear later.
```

---

# 27. Expiration vs Eviction

These are different.

### Expiration

```text
key TTL reached
```

### Eviction

```text
cache is under memory pressure

and removes keys
according to policy
```

Think:

```text
EXPIRE
=
time-based
```

```text
EVICT
=
capacity-based
```

AWS exposes `Evictions` specifically as keys removed because the cache hit its memory limit. ([AWS Documentation][6])

---

# 28. Cache Memory Is Finite

Suppose cache can hold:

```text
100 GB
```

but application attempts to store:

```text
150 GB
```

Something has to happen.

Depending on the configured memory policy:

```text
old keys may be evicted
```

or:

```text
writes can fail
```

Valkey/Redis OSS exposes configurable `maxmemory-policy` behavior. ([AWS Documentation][8])

---

# 29. LRU and LFU Mental Models

Common eviction ideas:

### LRU

```text
Least Recently Used
```

Think:

> Which key hasn't been accessed recently?

### LFU

```text
Least Frequently Used
```

Think:

> Which key isn't used very often?

For a cache workload:

```text
hot data survives
cold data leaves
```

if the selected policy matches the access pattern.

---

# 30. `noeviction`

Another important policy:

```text
noeviction
```

means:

```text
don't remove existing keys
to make space
```

Instead writes that require memory can fail once capacity is exhausted.

This can be appropriate for some non-cache use cases, but if your design assumes:

```text
cache automatically drops old data
```

then choosing `noeviction` changes that assumption.

---

# 31. Memory Metrics to Watch

For node-based Valkey/Redis OSS, important memory-related metrics include:

```text
DatabaseMemoryUsagePercentage

DatabaseCapacityUsagePercentage

BytesUsedForCache

Evictions

MemoryFragmentationRatio
```

AWS exposes these in the `AWS/ElastiCache` CloudWatch namespace. ([AWS Documentation][6])

---

# 32. Reserved Memory

Not every byte of a cache node should be filled with application data.

ElastiCache reserves memory for things such as:

```text
buffers
replication activity
memory fragmentation
background operations
```

AWS currently defaults `reserved-memory-percent` to **25%** for applicable node-based Valkey/Redis OSS configurations and warns not to reduce it because doing so can risk reliability/data loss during operations such as upgrades. ([AWS Documentation][9])

This means:

```text
32 GB node
```

does **not** mean:

```text
32 GB safe application dataset.
```

---

# 33. CPU — Important Valkey/Redis Nuance

Valkey/Redis OSS can use multiple threads for some operations, but individual command execution largely depends on the main engine thread. That's why AWS exposes:

```text
EngineCPUUtilization
```

in addition to host-wide:

```text
CPUUtilization
```

for troubleshooting command-processing pressure. ([AWS Documentation][10])

On larger nodes, you can see something like:

```text
CPUUtilization = 25%

EngineCPUUtilization = 95%
```

and still have a cache engine that's effectively saturated.

---

# 34. Slow Commands Can Hurt Everyone

Suppose one client executes a computationally expensive operation over a huge data structure.

Because command processing can bottleneck on the main event-processing thread:

```text
one expensive command
       │
       ▼
blocks command execution
       │
       ▼
latency for other clients rises
```

Therefore don't evaluate only:

```text
number of requests
```

Also inspect:

```text
command type
payload size
data-structure size
latency metrics
```

ElastiCache provides command-category latency metrics for Valkey/Redis OSS. ([AWS Documentation][6])

---

# 35. Connections Matter

Current ElastiCache documentation notes that Serverless caches and individual Redis OSS nodes can support up to **65,000 concurrent client connections**, but AWS explicitly recommends not continually operating at that ceiling because high connection counts can increase response times. ([AWS Documentation][11])

This is another parallel with RDS:

```text
connections
=
resource
```

although the connection model is much lighter than a relational DB session.

---

# 36. Connection Pooling

Bad application behavior:

```text
request arrives
      │
      ▼
open cache connection
      │
      ▼
GET
      │
      ▼
close connection
```

for every request.

Better:

```text
application process
      │
      ▼
persistent connection pool
      │
      ▼
reuse connections
```

This reduces:

```text
TCP/TLS setup
authentication overhead
connection churn
```

especially with TLS-enabled caches.

---

# 37. High Availability — Valkey / Redis OSS

Now we leave pure caching behavior and move into infrastructure.

A replication group can contain:

```text
PRIMARY
   │
   ├── Replica 1
   ├── Replica 2
   └── ...
```

For cluster-mode-disabled Valkey/Redis OSS, there is one shard and up to **five read replicas**. ([AWS Documentation][12])

Architecture:

```text
                  Primary
                 READ/WRITE
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
     Replica A                 Replica B
       READ                      READ
```

---

# 38. Multi-AZ

Place nodes across AZs:

```text
             ap-south-1a

                PRIMARY
                   │
             replication
                   │
                   ▼

             ap-south-1b

                REPLICA
```

Enabling Multi-AZ with automatic failover improves fault tolerance for Valkey/Redis OSS replication groups. It requires a replicated setup with more than one node in a shard. ([AWS Documentation][13])

---

# 39. Automatic Failover

Normal:

```text
Application
    │
    ▼
Primary endpoint
    │
    ▼
Primary AZ-A
```

Primary fails:

```text
Primary AZ-A
     X
```

ElastiCache:

```text
detects failure
     │
     ▼
promotes replica
     │
     ▼
new primary AZ-B
     │
     ▼
primary endpoint follows new role
```

AWS automatically updates the primary endpoint to the promoted replica during Multi-AZ failover. ([AWS Documentation][13])

This is why applications should connect using the managed endpoint rather than individual node IP addresses.

---

# 40. Primary Endpoint

For cluster-mode-disabled replication groups:

```text
PRIMARY ENDPOINT
```

means:

```text
connect me to
the current read/write primary
```

If the primary role changes, the endpoint follows it. ([AWS Documentation][14])

Mental model:

```text
Primary endpoint
=
ROLE-oriented
```

similar to what we learned with Aurora's writer endpoint.

---

# 41. Reader Endpoint

The reader endpoint lets applications send reads toward replicas.

```text
Application reads
      │
      ▼
Reader endpoint
      │
    ┌─┴────┐
    ▼      ▼
Replica1 Replica2
```

The reader endpoint is updated as replicas change during failover/recovery. ([AWS Documentation][15])

But remember:

```text
replicas can lag.
```

So read-after-write consistency requirements still matter.

---

# 42. Replication Is Asynchronous

Valkey/Redis OSS primary-to-replica replication is asynchronous.

Therefore:

```text
WRITE primary

immediate READ replica
```

can theoretically observe older state during replication lag.

AWS exposes:

```text
ReplicationLag
```

for read replicas and reports how far they are behind the primary. ([AWS Documentation][6])

For cache data this may be acceptable.

For something like:

```text
distributed correctness state
```

you must understand the consequence.

---

# 43. Cluster Mode Disabled

Architecture:

```text
ONE SHARD

Primary
   │
   ├── Replica
   ├── Replica
   └── Replica
```

Properties:

```text
one write primary
one shard of data
read replicas available
```

Therefore the entire keyspace must fit within that single shard's capacity.

AWS documents cluster-mode-disabled Valkey/Redis OSS as a one-shard architecture. ([AWS Documentation][12])

---

# 44. Cluster Mode Enabled

Now:

```text
                         CLUSTER

                ┌─────────┼─────────┐
                ▼         ▼         ▼
              SHARD 1   SHARD 2   SHARD 3

Primary P1      Primary P2      Primary P3
   │                │               │
 Replica           Replica          Replica
```

The keyspace is divided into shards.

AWS currently supports up to **500 shards** for cluster-mode-enabled Valkey/Redis OSS. ([AWS Documentation][12])

---

# 45. Why Shard?

Without sharding:

```text
all keys
all write traffic
all primary command load
```

go to one primary shard.

With:

```text
4 shards
```

you can distribute:

```text
keyspace
memory
read load
write load
```

across multiple primaries.

This gives you:

```text
horizontal cache scaling.
```

---

# 46. Hash Slots

Cluster-mode-enabled Valkey/Redis OSS maps keys into hash slots.

Conceptually:

```text
product:123
   │
 hash
   ▼
slot 5123
   │
   ▼
Shard 2
```

Cluster-aware clients understand how to route commands to the correct shard.

This is why client compatibility matters.

---

# 47. Important Serverless Client Requirement

ElastiCache Serverless abstracts the physical cluster topology, but Valkey/Redis OSS Serverless still requires clients compatible with the cluster protocol, and Serverless cache connections require TLS. ([AWS Documentation][16])

Therefore:

```text
old client library
```

that understands only a single standalone Redis endpoint may not work correctly with Serverless.

---

# 48. Configuration Endpoint

For node-based:

```text
cluster mode enabled
```

applications use the:

# Configuration endpoint

which allows a cluster-aware client to discover the shards/nodes. ([AWS Documentation][17])

Mental model:

```text
Application
    │
    ▼
Configuration endpoint
    │
    ▼
cluster topology
    │
 ┌──┼──┐
 ▼  ▼  ▼
S1 S2 S3
```

---

# 49. CROSSSLOT Error

Suppose one multi-key command operates on:

```text
user:1001
```

and:

```text
order:5001
```

but those keys live in different hash slots.

Certain commands requiring related keys on the same shard can produce:

```text
CROSSSLOT
```

errors.

AWS's current troubleshooting guidance specifically calls out `CROSSSLOT` errors as a sign your client/workload may not be correctly handling cluster mode. ([AWS Documentation][18])

This leads us to hash tags.

---

# 50. Hash Tags

Conceptually:

```text
cart:{USER1001}:items

cart:{USER1001}:total
```

The value inside:

```text
{USER1001}
```

can be used by Valkey/Redis cluster hashing to intentionally place related keys into the same slot.

That makes some multi-key operations possible while retaining overall cluster sharding.

But overusing one hash tag can create:

```text
HOT SHARD
```

so this needs deliberate design.

---

# 51. Scaling Cluster Mode Enabled

ElastiCache supports online shard changes for node-based cluster-mode-enabled Valkey/Redis OSS.

You can:

```text
scale out
→ add shards

scale in
→ remove shards

rebalance
→ redistribute slots
```

while continuing to serve traffic under supported online-resizing conditions. ([AWS Documentation][19])

This gives horizontal scaling without rebuilding the entire cache from scratch.

---

# 52. Replica Scaling

Read pressure can be addressed separately by:

```text
more replicas per shard
```

while write/memory pressure may require:

```text
more shards
```

Mental model:

```text
READ SCALE
=
replicas
```

```text
WRITE + MEMORY SCALE
=
shards
```

This is one of the most important Valkey/Redis cluster design distinctions.

---

# 53. Auto Scaling

ElastiCache Auto Scaling can automatically change the desired:

```text
number of shards

or

number of replicas
```

for eligible Valkey/Redis OSS node-based clusters using Application Auto Scaling policies and CloudWatch metrics. ([AWS Documentation][20])

This allows:

```text
read traffic ↑
      │
      ▼
replicas ↑
```

or:

```text
data/write pressure ↑
      │
      ▼
shards ↑
```

depending on the policy.

---

# 54. ElastiCache Serverless

Instead of deciding:

```text
cache.r7g.large

3 shards

2 replicas per shard
```

you can use:

# ElastiCache Serverless

AWS manages much more of:

```text
capacity
horizontal scaling
vertical scaling
underlying nodes
```

for you. AWS currently supports Serverless with Valkey, Redis OSS, and Memcached. ([AWS Documentation][16])

Architecture:

```text
Application
     │
     ▼
ElastiCache Serverless
     │
     ▼
AWS-managed scaling
     │
     ├── capacity
     ├── shards
     └── infrastructure
```

---

# 55. Serverless ECPUs

ElastiCache Serverless uses:

# ECPU

```text
ElastiCache Processing Unit
```

as a request-processing capacity metric.

AWS calculates ECPU consumption based on factors such as command CPU cost and data transferred, using the more expensive dimension for the operation. ([AWS Documentation][16])

Conceptually:

```text
simple GET
≈ small ECPU cost

large HMGET
≈ more CPU/data
≈ greater ECPU usage
```

So:

```text
1000 commands
```

doesn't necessarily mean:

```text
1000 equal-cost operations.
```

---

# 56. Serverless Current Scale Boundaries

Current AWS documentation lists, among other limits for Valkey/Redis OSS Serverless:

```text
up to 5,000 GiB
stored per cache
```

and:

```text
32 GiB per hash slot
```

along with per-slot processing limits. ([AWS Documentation][8])

The practical lesson is:

```text
Serverless
=
capacity management abstraction

NOT
=
no limits
```

Poor key distribution can still matter.

---

# 57. Serverless Is Excellent When

Consider it for:

```text
unpredictable workload

rapidly changing traffic

new applications

operational simplicity

teams that don't want
to size cache nodes/shards
```

AWS contrasts Serverless with node-based deployments specifically on the basis of automatic scaling versus fine-grained infrastructure control. ([AWS Documentation][21])

---

# 58. Node-Based Can Be Better When

Choose node-based when you need more precise control over:

```text
node family

node size

number of shards

number of replicas

AZ placement

scaling timing

specific topology
```

([AWS Documentation][21])

This is analogous to:

```text
Aurora Serverless v2
vs
provisioned Aurora
```

Neither is universally superior.

---

# 59. Session Storage

Classic problem:

```text
User logs in
   │
   ▼
EC2-A

session stored
only in EC2-A memory
```

Next request:

```text
ALB
 ↓
EC2-B
```

EC2-B says:

```text
Who are you?
```

Bad.

---

# 60. Centralized Session Cache

Instead:

```text
                 ALB
                  │
       ┌──────────┼──────────┐
       ▼          ▼          ▼
     EC2-A      EC2-B      EC2-C
       │          │          │
       └──────────┼──────────┘
                  ▼
              ElastiCache
                  │
             SESSION#abc
```

Now every application instance can retrieve:

```text
session:abc
```

regardless of which EC2 received the request.

This supports stateless application servers.

---

# 61. Session TTL

Sessions naturally map to expiration:

```text
session:user123

TTL
=
30 minutes
```

Each authenticated interaction can optionally refresh expiry depending on business design.

Cache/session systems are therefore an excellent use case for TTL.

But ask:

```text
If cache loses the session,
what happens?
```

Potentially:

```text
user logs in again.
```

That might be an acceptable failure mode.

---

# 62. Session Data vs Critical Business Data

Storing:

```text
shopping session
```

in cache may be okay.

Storing:

```text
final payment ledger
```

only in cache is another matter.

Always ask:

```text
What happens if
this key disappears?
```

If the answer is:

```text
business loses money
or data permanently
```

then a plain cache-only architecture needs reconsideration.

---

# 63. Shopping Cart Example

Possible architecture:

```text
DynamoDB
=
durable shopping cart
```

plus:

```text
ElastiCache
=
hot cart acceleration
```

or, for lower-value temporary carts:

```text
ElastiCache session/cart
```

with downstream persistence according to requirements.

Again, the correct answer is driven by:

```text
durability requirement
```

not merely:

```text
"Redis is fast."
```

---

# 64. Rate Limiting

Valkey/Redis OSS can be excellent for:

```text
API rate limits
```

Example:

```text
rate:user1001:minute:202608140102
=
57
```

Request:

```text
INCR counter
```

with expiry:

```text
EXPIRE 60
```

Then:

```text
counter > 100
       │
       ▼
reject request
```

Atomic counter operations make in-memory stores very useful for this workload.

---

# 65. Distributed Counters

Example:

```text
pageviews:article123
```

Operations:

```text
INCR
```

rather than:

```text
READ current
    │
    ▼
current + 1
    │
    ▼
WRITE
```

which can suffer lost updates under concurrency.

Atomic server-side operations are an important advantage of Valkey/Redis OSS.

---

# 66. Leaderboards

Sorted sets naturally model:

```text
score
+
member
```

Example:

```text
ZADD leaderboard 9800 user1001
ZADD leaderboard 8500 user2002
```

Then:

```text
top 10 users
```

can be retrieved efficiently.

This is why a cache/data-structure system can sometimes replace expensive repeated relational ranking calculations.

---

# 67. Pub/Sub

Valkey/Redis OSS also supports:

```text
Publish
Subscribe
```

Concept:

```text
Publisher
   │
   ▼
channel
   │
 ┌─┼───────────┐
 ▼ ▼           ▼
A  B           C
```

Useful for:

```text
real-time transient notifications
live application updates
```

But classic Pub/Sub is not the same durability model as:

```text
SQS
Kafka
Kinesis
```

If a subscriber is disconnected, design expectations differ.

Do not replace a durable message queue with Pub/Sub without understanding delivery semantics.

---

# 68. Streams

Valkey/Redis OSS Streams provide a more persistent stream-style data structure than basic Pub/Sub.

Potential use:

```text
events
consumer groups
ordered stream processing
```

But for large AWS event architectures, compare carefully against:

```text
SQS
Kinesis
MSK
```

because those services have different durability/scaling/operational models.

---

# 69. Distributed Locks

A basic lock idea:

```text
SET lock:job123 <token> NX EX 30
```

means conceptually:

```text
create lock
only if it doesn't exist
and expire it automatically
```

Then:

```text
Worker A
gets lock

Worker B
fails to get lock
```

This can coordinate work.

But distributed locks are subtle.

For correctness-critical operations such as:

```text
financial settlement
inventory ownership
singleton leader safety
```

you must understand:

```text
timeouts
network partitions
lock expiry
process pauses
ownership tokens
fencing
```

A simple cache lock should not become your only correctness boundary without deeper distributed-systems design.

---

# 70. Hot Keys

Suppose:

```text
homepage
```

receives:

```text
2 million GETs/sec
```

while every other key is cold.

Even with many shards:

```text
one key
```

maps to:

```text
one shard
```

for normal single-key operations.

That can create a:

# Hot key

```text
all load
   │
   ▼
one shard/node
```

Horizontal sharding doesn't automatically split one key across 100 shards.

---

# 71. Hot Key Mitigation

Possible strategies:

```text
local/in-process caching

CloudFront for HTTP content

client-side caching

replica reads

application key decomposition

duplicate/sharded derived keys
```

depending on workload.

The most important idea:

```text
SHARDING
solves many-key distribution

NOT
one-key infinite scale.
```

---

# 72. Big Key Problem

Suppose one key contains:

```text
500 MB
```

while most keys are:

```text
1 KB
```

Operations on that giant value can create:

```text
network spikes
latency
memory pressure
replication cost
failover/rebalancing difficulty
```

Avoid designing:

```text
one gigantic JSON value
containing millions of objects
```

when the data can be partitioned more naturally.

---

# 73. Cache Warming

After cache restart/new deployment:

```text
cache
=
EMPTY
```

Immediately sending full traffic causes:

```text
miss
miss
miss
miss
miss
```

and the database suddenly receives the entire workload.

This is:

```text
cold cache
```

problem.

Strategies:

```text
lazy warm naturally

preload popular keys

gradually shift traffic

stale fallback

rate-limit database reconstruction
```

depending on workload.

---

# 74. Why Cache Failure Can Crash the Database

Normal:

```text
90% cache hits

Database sees:
10% requests
```

Cache fails:

```text
Cache
  X
```

Now:

```text
Database sees:
100% requests
```

A database designed for:

```text
10k req/sec
```

may suddenly receive:

```text
100k req/sec
```

and fail too.

This is a:

```text
cascading failure
```

Cache resilience therefore protects not just:

```text
latency
```

but often:

```text
database survival.
```

---

# 75. Graceful Degradation

If cache fails:

Bad application:

```text
cache error
   │
   ▼
HTTP 500
for everyone
```

Potentially better for cache-aside:

```text
cache unavailable
      │
      ▼
database fallback
      │
      ▼
serve request
```

but with protection:

```text
rate limits
circuit breakers
load shedding
database capacity awareness
```

Otherwise:

```text
graceful fallback
```

can itself become:

```text
database DDoS.
```

---

# 76. Multi-AZ Is Important Even for a Cache

Some engineers think:

```text
"It's only cache.
If it dies, rebuild it."
```

That can be true for some systems.

But if cache loss instantly multiplies DB load by:

```text
10×
```

then:

```text
cache availability
```

becomes critical to application availability.

This is why Valkey/Redis OSS replication groups with Multi-AZ and automatic failover are important for production cache architectures. ([AWS Documentation][13])

---

# 77. Global Datastore

ElastiCache supports cross-Region:

# Global Datastore

for Valkey/Redis OSS.

Architecture:

```text
               Primary Region
                 ap-south-1
                     │
                  Primary
                     │
          asynchronous replication
                     │
                     ▼
               Secondary Region
              ap-southeast-1
```

AWS manages asynchronous cross-Region replication between the primary and secondary clusters. ([AWS Documentation][22])

Potential uses:

```text
global reads

regional DR

lower-latency regional cache data
```

---

# 78. Global Datastore ≠ Multi-Region Multi-Writer

Normal Global Datastore architecture is:

```text
PRIMARY REGION
READ + WRITE

SECONDARY
READ
```

with asynchronous replication.

Think:

```text
Aurora Global Database
```

more than:

```text
DynamoDB Global Tables
```

when comparing write topology.

And because replication is asynchronous:

```text
secondary can lag.
```

AWS exposes `GlobalDatastoreReplicationLag`. ([AWS Documentation][22])

---

# 79. Backups

ElastiCache can create snapshots/backups for Valkey, Redis OSS, and Serverless Memcached; backups are written to Amazon S3 and can be restored into new cache resources. ([AWS Documentation][23])

This can be useful for:

```text
cache seeding

migration

recovery of important cache state

restoring data structures
```

But this does **not** mean you should automatically treat a cache snapshot strategy as a replacement for your application's authoritative database backups.

---

# 80. ElastiCache Security Architecture

Production:

```text
                        Private Application
                               App-SG
                                  │
                                  ▼
                          ElastiCache-SG
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                  TLS                       Authentication
                    │                           │
                    ▼                           ▼
             encryption in transit         IAM / AUTH / RBAC
                    │
                    ▼
             encryption at rest
                    │
                    ▼
                   KMS
```

ElastiCache supports TLS in transit, at-rest encryption, IAM authentication, AUTH, and RBAC for supported Valkey/Redis OSS configurations. ([AWS Documentation][24])

---

# 81. Security Groups

Valkey/Redis OSS default port:

```text
6379
```

Memcached:

```text
11211
```

AWS's troubleshooting guidance recommends allowing only the appropriate application-to-cache network path rather than exposing cache access broadly. ([AWS Documentation][10])

Production pattern:

```text
App-SG
   │
   │ TCP 6379
   ▼
Cache-SG
```

not:

```text
Internet
0.0.0.0/0
   │
   ▼
6379
```

Your cache should normally live on private network paths.

---

# 82. TLS

In-transit encryption protects:

```text
application ↔ cache

and

cache node ↔ cache node
```

traffic. ElastiCache TLS also enables server authentication and can be combined with client authentication; ElastiCache does not currently support mutual TLS. ([AWS Documentation][25])

Architecture:

```text
App
 │
 │ TLS
 ▼
ElastiCache
```

---

# 83. IAM Authentication

ElastiCache supports IAM authentication with:

```text
Valkey 7.2+
```

and:

```text
Redis OSS 7.0+
```

and IAM authentication requires TLS. ([AWS Documentation][26])

Conceptually:

```text
EC2/ECS/Lambda Role
       │
       ▼
       IAM
       │
       ▼
temporary auth token
       │
       ▼
ElastiCache
```

This can reduce reliance on long-lived static cache passwords.

---

# 84. AUTH and RBAC

Valkey/Redis OSS also supports:

```text
AUTH
```

and:

```text
role-based access control
```

so you can define users with permissions over commands and key patterns. ([AWS Documentation][24])

For example conceptually:

```text
app-user
   │
   ├── GET
   ├── SET
   ├── DEL
   └── keys app:*
```

while an analytics user might have:

```text
read-only
```

access to selected key patterns.

---

# 85. At-Rest Encryption Caveat

For node-based Valkey/Redis OSS, enabling at-rest encryption on an existing unencrypted replication group is not simply an in-place checkbox change; AWS documents a backup/delete/restore style migration requirement for existing node-based clusters. ([AWS Documentation][27])

This should remind you of our RDS/KMS lessons:

```text
encryption decision
should be made early.
```

---

# 86. Monitoring — Essential Metrics

For Valkey/Redis OSS, monitor at least:

```text
CacheHitRate

CacheHits
CacheMisses

EngineCPUUtilization
CPUUtilization

DatabaseMemoryUsagePercentage

Evictions

CurrConnections

NewConnections

ReplicationLag

SuccessfulReadRequestLatency

SuccessfulWriteRequestLatency

TrafficManagementActive
```

AWS specifically recommends monitoring CPU, engine CPU, memory, evictions, connections, networking, and replication-related metrics. ([AWS Documentation][28])

---

# 87. `Evictions > 0`

Question:

```text
Why?
```

Possible:

```text
cache memory full
```

and memory policy is removing items.

Then inspect:

```text
DatabaseMemoryUsagePercentage

working set size

TTL

key count

value sizes

node size

shard count
```

Do not immediately assume:

```text
eviction is always bad.
```

For a pure cache, eviction is expected behavior.

But rapid unexpected eviction can destroy hit rate and hammer the database.

---

# 88. `CacheHitRate` Falling

Example:

```text
95%
↓
60%
↓
20%
```

Likely effect:

```text
database traffic
↑
↑
↑
```

Investigate:

```text
evictions?

deployment changed keys?

TTL changed?

cache flush?

working set grew?

cold cache?
```

The cache dashboard should be correlated with:

```text
Aurora/RDS DB Load
```

because these systems directly affect each other.

---

# 89. `EngineCPUUtilization` High

Possible causes:

```text
too many commands

expensive commands

large structures

hot key

one-shard limit

inefficient client use
```

Solutions can include:

```text
optimize commands

scale node vertically

add shards

change data model

reduce hot-key pressure
```

depending on cause.

---

# 90. `CurrConnections` High

Investigate:

```text
application instance count

connection pooling

connection leak

Lambda/ECS scaling

short-lived connections

TLS setup churn
```

AWS recommends avoiding permanently operating near the documented connection ceiling even though large numbers of concurrent connections are supported. ([AWS Documentation][11])

---

# 91. `ReplicationLag` High

Think:

```text
primary write volume

replica CPU

network

large operations

replica health
```

If application reads from replicas:

```text
staleness risk increases.
```

Do not route correctness-sensitive read-after-write traffic to badly lagging replicas.

---

# 92. `TrafficManagementActive = 1`

AWS exposes this metric when ElastiCache is actively managing incoming traffic because more work is arriving than the engine can process optimally. ([AWS Documentation][6])

Think:

```text
cache may be undersized
or workload too expensive.
```

Investigate immediately:

```text
command latency
CPU
hot keys
shards
```

---

# 93. Cache Troubleshooting Flow

Application reports:

```text
cache is slow
```

Use:

```text
Can app connect?
      │
      ├── NO
      │    ├── DNS?
      │    ├── SG?
      │    ├── port?
      │    ├── TLS?
      │    └── AUTH/IAM?
      │
      └── YES
           │
           ▼
       latency high?
           │
           ▼
    EngineCPUUtilization?
           │
           ▼
    memory pressure?
           │
           ▼
       evictions?
           │
           ▼
       hot key?
           │
           ▼
    expensive commands?
           │
           ▼
      connections?
           │
           ▼
      shard design?
           │
           ▼
    replication lag?
```

---

# 94. Cache Failure vs Database Failure

Cache unavailable:

```text
App
 │
 X cache
 │
 ▼
DB fallback
```

Database unavailable:

```text
App
 │
 ▼
cache
```

some reads may still temporarily succeed if cached.

This means a cache can sometimes provide:

```text
partial resilience
```

as well as performance.

But you must decide:

```text
Can stale cache data
be served during DB failure?
```

for each business operation.

Example:

```text
product description
→ perhaps yes
```

```text
bank account balance
→ probably not from stale cache
```

---

# 95. Cache Consistency Levels Are Application Decisions

You might define:

```text
Product catalog
=
up to 5 minutes stale okay
```

```text
User profile
=
30 seconds stale okay
```

```text
Inventory count
=
must be near real-time
```

```text
Payment status
=
source-of-truth DB
```

This leads to different:

```text
TTL
invalidation
read routing
```

strategies.

Caching is not one universal policy applied to every table.

---

# 96. Production Architecture With Aurora

```text
                            Internet
                               │
                               ▼
                              ALB
                               │
                   ┌───────────┴───────────┐
                   ▼                       ▼
                EC2-A                   EC2-B
                Node.js                 Node.js
                   │                       │
                   └──────────┬────────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
                 ▼                         ▼
             ElastiCache               RDS Proxy
               Valkey                      │
                 │                         ▼
           cache-aside                  Aurora
                 │
             ┌───┴────┐
             │        │
          Multi-AZ    TTL
             │
          replica
```

Request:

```text
GET /products/123
        │
        ▼
     Valkey
        │
     HIT?
    ┌───┴────┐
    │        │
   YES       NO
    │        │
 return    Aurora
             │
             ▼
          SET cache
             │
             ▼
           return
```

---

# 97. Add DynamoDB

Now our full data layer can become:

```text
                       APPLICATION
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
        ElastiCache      Aurora        DynamoDB
           │               │              │
       hot/cache        relational      NoSQL state
       sessions         transactions     sessions/events
       counters         orders           metadata
```

And:

```text
S3
=
objects
```

Now you should see why AWS has multiple database/storage services.

They aren't duplicates.

They solve different access models.

---

# 98. Terraform — Security Group

```hcl
resource "aws_security_group" "cache" {
  name   = "prod-cache-sg"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "cache_from_app" {
  security_group_id = aws_security_group.cache.id

  referenced_security_group_id =
    aws_security_group.app.id

  from_port   = 6379
  to_port     = 6379
  ip_protocol = "tcp"
}
```

Architecture:

```text
App-SG
  │
  │ 6379
  ▼
Cache-SG
```

---

# 99. Terraform — Node-Based Valkey

A production-oriented replication group can be modeled with Terraform's `aws_elasticache_replication_group` resource. ([Terraform Registry][29])

Conceptually:

```hcl
resource "aws_elasticache_subnet_group" "cache" {
  name = "prod-cache-subnets"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]
}

resource "aws_elasticache_replication_group" "cache" {
  replication_group_id = "prod-valkey"

  description = "Production application cache"

  engine = "valkey"

  node_type = "cache.r7g.large"

  num_cache_clusters = 2

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name =
    aws_elasticache_subnet_group.cache.name

  security_group_ids = [
    aws_security_group.cache.id
  ]

  at_rest_encryption_enabled = true

  transit_encryption_enabled = true
}
```

The exact node type and engine version should be chosen based on current Region support and measured workload rather than copied blindly.

---

# 100. Terraform — Serverless Cache

Current AWS Terraform provider also provides:

```text
aws_elasticache_serverless_cache
```

for Serverless Valkey, Redis OSS, or Memcached. ([Terraform Registry][30])

Conceptually:

```hcl
resource "aws_elasticache_serverless_cache" "cache" {
  engine = "valkey"

  name = "prod-valkey-serverless"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  security_group_ids = [
    aws_security_group.cache.id
  ]
}
```

This removes node/shard sizing from your Terraform architecture.

---

# 101. Hands-On Lab — Simple Cache-Aside

For a safe lab, create a small non-production ElastiCache cache in private subnets and use an EC2 instance or CloudShell-connected VPC environment that can reach it.

For a node-based Valkey cache with TLS, first locate the endpoint:

```bash
aws elasticache describe-replication-groups \
  --region ap-south-1 \
  --query \
  'ReplicationGroups[].{
      ID:ReplicationGroupId,
      Primary:NodeGroups[0].PrimaryEndpoint.Address,
      Reader:NodeGroups[0].ReaderEndpoint.Address
  }' \
  --output table
```

AWS exposes role-oriented primary/reader endpoints for appropriate replicated Valkey/Redis OSS deployments. ([AWS Documentation][15])

---

# 102. Basic CLI Commands

From a host inside the permitted VPC path:

```bash
valkey-cli \
  --tls \
  -h "$CACHE_ENDPOINT" \
  -p 6379
```

Then:

```text
SET greeting "Hello AWS"
```

```text
GET greeting
```

Expected:

```text
Hello AWS
```

TTL:

```text
SET session:abc "user1001" EX 60
```

Check:

```text
TTL session:abc
```

Counter:

```text
INCR pageviews
```

Hash:

```text
HSET user:1001 name Vivek plan premium
```

```text
HGETALL user:1001
```

Sorted set:

```text
ZADD leaderboard 9800 user1001
ZADD leaderboard 8700 user2002
```

```text
ZREVRANGE leaderboard 0 9 WITHSCORES
```

---

# 103. Cache-Aside Node.js Example

Pseudo-production pattern:

```javascript
async function getProduct(productId) {
  const cacheKey = `product:${productId}`;

  try {
    const cached = await redis.get(cacheKey);

    if (cached !== null) {
      return JSON.parse(cached);
    }
  } catch (error) {
    console.error("Cache read failed", error);
  }

  const product = await db.products.findById(productId);

  if (!product) {
    await redis.set(
      cacheKey,
      JSON.stringify({ notFound: true }),
      { EX: 30 }
    );

    return null;
  }

  try {
    const ttl = 300 + Math.floor(Math.random() * 60);

    await redis.set(
      cacheKey,
      JSON.stringify(product),
      { EX: ttl }
    );
  } catch (error) {
    console.error("Cache write failed", error);
  }

  return product;
}
```

Notice:

```text
cache failure
doesn't automatically
take down the source-of-truth read.
```

That's deliberate graceful degradation.

---

# 104. Write Invalidation

```javascript
async function updateProduct(id, changes) {
  const updated =
    await db.products.update(id, changes);

  try {
    await redis.del(`product:${id}`);
  } catch (error) {
    console.error(
      "Cache invalidation failed",
      error
    );
  }

  return updated;
}
```

But now ask:

```text
What happens if:

DB update succeeds
AND
cache DEL fails?
```

Answer:

```text
stale cache remains.
```

This is why robust systems may use:

```text
short TTLs
event-driven invalidation
outbox/CDC
versioned cache keys
```

for stronger consistency.

---

# 105. Event-Driven Cache Invalidation

A more advanced architecture:

```text
Application
    │
    ▼
Aurora
    │
    ▼
change/event
    │
    ▼
Event bus / CDC
    │
    ▼
cache invalidator
    │
    ▼
ElastiCache
```

or:

```text
DynamoDB
   │
   ▼
Streams
   │
   ▼
Lambda
   │
   ▼
invalidate Valkey
```

This reduces the number of application paths that must remember cache invalidation logic.

---

# 106. SAA-C03 Scenario

> RDS handles the same expensive query thousands of times per second and results can be stale for several minutes.

Think:

```text
ElastiCache
+
cache-aside
+
TTL
```

before endlessly scaling the RDS writer.

---

# 107. Scenario

> Need simple object caching and want multi-threaded cache nodes.

Think:

```text
Memcached
```

as a candidate. AWS explicitly calls out simple caching and multi-threaded node use as Memcached strengths. ([AWS Documentation][4])

---

# 108. Scenario

> Need sorted sets for a leaderboard.

Think:

```text
Valkey / Redis OSS
```

rather than Memcached.

---

# 109. Scenario

> Need automatic cache failover across AZs.

Think:

```text
Valkey / Redis OSS
replication group

+
Multi-AZ
+
Automatic Failover
```

([AWS Documentation][13])

---

# 110. Scenario

> Cache dataset no longer fits on one primary shard and write throughput is constrained.

Think:

```text
cluster mode enabled
+
multiple shards
```

not simply:

```text
add read replicas.
```

Read replicas don't distribute primary writes across shards. ([AWS Documentation][12])

---

# 111. Scenario

> Read traffic is high but writer/memory capacity is fine.

Think:

```text
add replicas
```

if the application's consistency requirements permit replica reads.

---

# 112. Scenario

> Team doesn't want to manage cache node sizes/shards and traffic is unpredictable.

Strong candidate:

```text
ElastiCache Serverless
```

because AWS handles vertical and horizontal scaling. ([AWS Documentation][21])

---

# 113. Scenario

> One key receives nearly all traffic even though cluster has 50 shards.

Think:

```text
HOT KEY
```

not:

```text
"we need another 50 shards."
```

That key still maps to a particular slot/shard.

---

# 114. Scenario

> `Evictions` suddenly rises and RDS load rises at the same time.

Likely chain:

```text
cache memory pressure
       │
       ▼
keys evicted
       │
       ▼
CacheHitRate ↓
       │
       ▼
DB misses ↑
       │
       ▼
RDS load ↑
```

This is why cache and database dashboards should be correlated. ([AWS Documentation][6])

---

# 115. Scenario

> Cache CPU looks only 25%, but latency is bad.

If you are using a larger node, inspect:

```text
EngineCPUUtilization
```

because host-wide CPU can hide saturation of the engine command-processing thread. ([AWS Documentation][6])

---

# 116. Scenario

> Application gets connection timeout.

Think:

```text
network
```

first:

```text
VPC?
subnet?
security group?
correct endpoint?
port 6379?
DNS?
```

AWS's connection troubleshooting guidance uses this exact network-first model. ([AWS Documentation][10])

---

# 117. Scenario

> TLS connection works but authentication fails.

Now networking works.

Investigate:

```text
IAM authentication
AUTH token
RBAC user
permissions
token generation
```

not:

```text
security group.
```

---

# 118. Scenario

> Replicas serve stale values.

Think:

```text
ReplicationLag
```

because primary-to-replica replication is asynchronous. ([AWS Documentation][6])

Use primary reads for operations requiring immediate read-after-write semantics.

---

# 119. Scenario

> Cache was flushed and database crashed five seconds later.

Think:

```text
COLD CACHE
+
CACHE STAMPEDE
+
DATABASE CAPACITY
```

Preventive measures:

```text
cache warming
request coalescing
rate limiting
graceful load ramp
Multi-AZ
appropriate DB headroom
```

A cache is part of the system's capacity architecture.

---

# 120. Scenario

> Need a cache copy in Singapore for reads/DR while the writer is in Mumbai.

Think:

```text
ElastiCache Global Datastore
```

with asynchronous cross-Region replication. ([AWS Documentation][22])

---

# 121. Scenario

> Need global multi-active writes in three Regions.

Don't immediately say:

```text
ElastiCache Global Datastore
```

because that isn't the same model.

Depending on data semantics, evaluate:

```text
DynamoDB Global Tables
```

which we covered in Part 4.

Architecture selection depends on whether you're storing:

```text
cache copies
```

or:

```text
authoritative globally writable data.
```

---

# 122. ElastiCache vs DynamoDB DAX

This is another certification trap.

### ElastiCache

```text
generic application cache
```

Can cache:

```text
RDS results
API results
sessions
objects
counters
```

### DAX

```text
DynamoDB-specific
in-memory acceleration layer
```

Think:

```text
Need DynamoDB-compatible cache
with minimal app changes?
→ DAX
```

```text
Need general-purpose cache/data structures?
→ ElastiCache
```

---

# 123. ElastiCache vs RDS Proxy

Different problems:

```text
ElastiCache
=
avoid database work
```

```text
RDS Proxy
=
manage database connections
```

Architecture:

```text
App
 │
 ▼
ElastiCache
 │
 miss
 ▼
RDS Proxy
 │
 ▼
Aurora
```

Using both can make perfect sense.

---

# 124. ElastiCache vs CloudFront

Again different caches.

### CloudFront

```text
edge HTTP cache
```

Near:

```text
global users
```

### ElastiCache

```text
application/data cache
```

Near:

```text
application servers
inside AWS/VPC
```

Example:

```text
Browser
   │
   ▼
CloudFront
   │
   ▼
API
   │
   ▼
ElastiCache
   │
   ▼
Aurora
```

You can have multiple cache layers.

---

# 125. Multi-Layer Cache

Production architecture:

```text
                        USER
                         │
                         ▼
                    CloudFront
                     edge cache
                         │
                         ▼
                       API
                         │
                         ▼
                  local app cache
                         │
                         ▼
                    ElastiCache
                         │
                         ▼
                      Aurora
```

Each layer has a different:

```text
TTL
capacity
failure mode
consistency contract
```

This is high-scale architecture.

---

# 126. Never-Forget Cache Decision Tree

```text
Should data be cached?
       │
       ▼
Is it read repeatedly?
       │
   ┌───┴────┐
   │        │
  NO       YES
   │        │
 don't      ▼
 cache    Can it be stale?
            │
       ┌────┴────┐
       │         │
      NO        YES
       │         │
 careful       CACHE
 design          │
                 ▼
          Which structure?
          │
          ├─ simple objects → Memcached candidate
          │
          └─ rich structures / HA
                       ↓
                 Valkey/Redis OSS
```

Then:

```text
Unknown scaling?
   │
   ▼
Serverless candidate


Need topology control?
   │
   ▼
Node-based
```

---

# 127. Never-Forget Cache-Aside Model

```text
                   READ

App
 │
 ▼
Cache
 │
 ├── HIT ─────────▶ return
 │
 └── MISS
       │
       ▼
      DB
       │
       ▼
     cache
       │
       ▼
     return
```

Write:

```text
                   WRITE

App
 │
 ▼
DB
 │
 ▼
invalidate cache
```

This is the first caching pattern you should be able to draw from memory.

---

# 128. Production Troubleshooting Mental Model

```text
                    CACHE PROBLEM
                         │
          ┌──────────────┼───────────────┐
          ▼              ▼               ▼
       ACCESS        PERFORMANCE       DATA
          │              │               │
       SG/TLS        engine CPU       stale?
       AUTH          memory           expired?
       endpoint      hot keys         evicted?
                     commands         replica lag?
                     connections
                         │
                         ▼
                      SCALE
                ┌────────┴────────┐
                ▼                 ▼
              Reads          Writes/Memory
                │                 │
             replicas           shards
```

For Serverless:

```text
focus more on:
key distribution
ECPU
memory/data limits
command behavior
```

rather than node sizing.

---

# 129. The 25 Rules to Burn Into Memory

```text
1. Cache is normally not the system of record.

2. Cache-aside is the first caching pattern to learn.

3. Cache hit avoids database work.

4. Cache miss falls back to the source of truth.

5. Cache invalidation is a correctness problem.

6. TTL balances freshness vs hit rate.

7. Add TTL jitter to avoid synchronized expiry.

8. Cache stampede can take down the database.

9. Expiration and eviction are different.

10. Evictions rising can destroy cache hit rate.

11. Monitor CacheHitRate, not merely cache uptime.

12. Valkey/Redis OSS supports richer data structures.

13. Memcached is attractive for simpler object caching.

14. Cluster mode disabled = one shard.

15. Cluster mode enabled = partitioned keyspace.

16. Replicas scale reads and support HA.

17. Shards scale memory and primary/write capacity.

18. Multi-AZ enables automatic primary failover.

19. Replica reads can be stale.

20. A hot key can overload one shard despite many shards.

21. ElastiCache Serverless removes most capacity management.

22. TLS and private networking belong in production design.

23. IAM/AUTH/RBAC control cache authentication/authorization.

24. Cache failure can cause a database cascading failure.

25. Caching helps only when data is reused enough
    to justify another data-consistency layer.
```

The most important rule:

```text
A CACHE IS SUCCESSFUL
WHEN IT REDUCES EXPENSIVE WORK

WITHOUT BREAKING
APPLICATION CORRECTNESS.
```

---

# ✅ Lesson 28 Part 5 Complete

You now understand:

```text
✓ ElastiCache fundamentals
✓ Valkey
✓ Redis OSS
✓ Memcached
✓ cache-aside
✓ lazy loading
✓ write-through
✓ write-behind tradeoffs
✓ TTL
✓ cache invalidation
✓ stale data
✓ TTL jitter
✓ negative caching
✓ cache stampede
✓ request coalescing
✓ expiration vs eviction
✓ LRU / LFU concepts
✓ memory pressure
✓ reserved memory
✓ CacheHitRate
✓ Evictions
✓ EngineCPUUtilization
✓ connections
✓ sessions
✓ rate limiting
✓ counters
✓ leaderboards
✓ Pub/Sub
✓ Streams concepts
✓ distributed locking caveats
✓ hot keys
✓ big keys
✓ cache warming
✓ graceful degradation
✓ cascading failures
✓ Valkey replication
✓ Multi-AZ
✓ automatic failover
✓ primary endpoint
✓ reader endpoint
✓ cluster mode disabled
✓ cluster mode enabled
✓ shards
✓ replicas
✓ configuration endpoint
✓ hash slots
✓ CROSSSLOT
✓ horizontal scaling
✓ Auto Scaling
✓ ElastiCache Serverless
✓ ECPUs
✓ Global Datastore
✓ TLS
✓ at-rest encryption
✓ AUTH
✓ IAM authentication
✓ RBAC
✓ CloudWatch metrics
✓ Terraform
✓ cache-aside application code
✓ production troubleshooting
```

# Next — Lesson 28 Part 6

# **AWS Database Decision Architecture — RDS vs Aurora vs DynamoDB vs ElastiCache**

Now we will combine everything from Lesson 28 and solve actual architect problems.

We'll build a decision framework around:

```text
                        DATA REQUIREMENT
                              │
              ┌───────────────┼────────────────┐
              ▼               ▼                ▼
          RELATIONAL        KEY/VALUE          CACHE
              │               │                │
              ▼               ▼                ▼
          RDS/Aurora       DynamoDB        ElastiCache
```

Then go much deeper:

```text
→ SQL vs NoSQL
→ ACID requirements
→ JOIN requirements
→ access-pattern flexibility
→ horizontal scale
→ read/write patterns
→ global active-active
→ Multi-AZ
→ replicas
→ serverless
→ consistency models
→ transaction models
→ RPO/RTO
→ caching
→ connection management
→ cost
→ operational complexity
→ migration decisions
→ anti-patterns
→ polyglot persistence
→ real production architectures
→ SAA-C03 exam scenarios
→ DOP-C02 incident questions
→ server-sizing decisions
→ Terraform reference architecture
→ full Lesson 28 database capstone
```

The key question will no longer be:

```text
"What AWS database services do I know?"
```

It will become:

```text
"Given THIS workload,
which database should I choose,
why,
how should it scale,
how should it fail,
and how should it recover?"
```

That is the mindset of a solutions architect rather than someone memorizing AWS service names.

[1]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.html?utm_source=chatgpt.com "What is Amazon ElastiCache? - Amazon ..."
[2]: https://aws.amazon.com/elasticache/?utm_source=chatgpt.com "Amazon ElastiCache"
[3]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/engine-versions.html?utm_source=chatgpt.com "Engine versions and upgrading in ElastiCache"
[4]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/SelectEngine.html?utm_source=chatgpt.com "Comparing node-based Valkey, Memcached, and Redis ..."
[5]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/ecommerce-caching-valkey.html?utm_source=chatgpt.com "Amazon ElastiCache (Valkey) for e-commerce applications"
[6]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/CacheMetrics.Redis.html?utm_source=chatgpt.com "Metrics for Valkey and Redis OSS - Amazon ElastiCache"
[7]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Strategies.html?utm_source=chatgpt.com "Caching strategies for Memcached - Amazon ElastiCache"
[8]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/RedisConfiguration.html?utm_source=chatgpt.com "Valkey and Redis OSS configuration and limits"
[9]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/redis-memory-management.html?utm_source=chatgpt.com "Managing reserved memory for Valkey and Redis OSS"
[10]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/TroubleshootingConnections.html?utm_source=chatgpt.com "Persistent connection issues - Amazon ElastiCache"
[11]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/BestPractices.Clients.Redis.Connections.html?utm_source=chatgpt.com "Large number of connections (Valkey and Redis OSS)"
[12]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Replication.Redis-RedisCluster.html?utm_source=chatgpt.com "Valkey and Redis OSS Cluster Mode Disabled vs. Enabled"
[13]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/AutoFailover.html?utm_source=chatgpt.com "Minimizing downtime in ElastiCache by using Multi-AZ with ..."
[14]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.Components.html?utm_source=chatgpt.com "ElastiCache components and features"
[15]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Endpoints.html?utm_source=chatgpt.com "Finding connection endpoints in ElastiCache"
[16]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.corecomponents.html?utm_source=chatgpt.com "How ElastiCache works"
[17]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Replication.Endpoints.html?utm_source=chatgpt.com "Finding replication group endpoints - Amazon ElastiCache"
[18]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/wwe-troubleshooting.html?utm_source=chatgpt.com "Common troubleshooting steps and best practices with ..."
[19]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/scaling-redis-cluster-mode-enabled.html?utm_source=chatgpt.com "Scaling Valkey or Redis OSS (Cluster Mode Enabled) clusters"
[20]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/AutoScaling.html?utm_source=chatgpt.com "Auto Scaling Valkey and Redis OSS clusters"
[21]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html?utm_source=chatgpt.com "Choosing between deployment options"
[22]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Redis-Global-Datastore.html?utm_source=chatgpt.com "Replication across AWS Regions using global datastores"
[23]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/backups.html?utm_source=chatgpt.com "Snapshot and restore - Amazon ElastiCache"
[24]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth-redis.html?utm_source=chatgpt.com "Authentication and Authorization - Amazon ElastiCache"
[25]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/in-transit-encryption.html?utm_source=chatgpt.com "ElastiCache in-transit encryption (TLS) - AWS Documentation"
[26]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth-iam.html?utm_source=chatgpt.com "Authenticating with IAM - Amazon ElastiCache"
[27]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/at-rest-encryption.html?utm_source=chatgpt.com "At-Rest Encryption in ElastiCache"
[28]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/CacheMetrics.WhichShouldIMonitor.html?utm_source=chatgpt.com "Which Metrics Should I Monitor? - Amazon ElastiCache"
[29]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group?utm_source=chatgpt.com "aws_elasticache_replication_gro..."
[30]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_serverless_cache?utm_source=chatgpt.com "aws_elasticache_serverless_cac..."
