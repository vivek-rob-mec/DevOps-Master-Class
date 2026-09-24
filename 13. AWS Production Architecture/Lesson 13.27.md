# AWS Masterclass — Phase 3

# Lesson 26: Amazon ElastiCache for Valkey and Redis OSS

## 1. Lesson objective

In this lesson, you will learn how to build a production caching layer using Amazon ElastiCache.

We will cover:

* What ElastiCache is and where it fits.
* Valkey, Redis OSS and Memcached.
* Serverless caches and node-based clusters.
* Primary nodes, replicas, shards and replication groups.
* Cluster mode disabled versus enabled.
* Multi-AZ and automatic failover.
* Cache-aside, session storage and rate limiting.
* TTLs, eviction policies and cache invalidation.
* Cache stampedes, hot keys and distributed locks.
* Encryption, authentication and RBAC.
* Backups and disaster recovery.
* Scaling, data tiering and Global Datastore.
* Monitoring, troubleshooting and Terraform.

---

# 2. Production architecture

A common architecture looks like this:

```text
                            Internet
                                |
                         Route 53 / DNS
                                |
                           CloudFront
                                |
                    Application Load Balancer
                         /              \
                EC2 Instance        EC2 Instance
                         \              /
                          \            /
                       RDS Proxy / RDS
                              |
                         Source data

                Application instances also connect to:

                  ElastiCache replication group
                 /                           \
        Primary node                    Replica node
        AZ-A                             AZ-B
        Reads + writes                   Reads
```

The responsibilities are different:

```text
RDS:
Permanent relational source of truth

ElastiCache:
Fast temporary or semi-persistent data access layer

EC2 Auto Scaling:
Application compute capacity

ALB:
Traffic distribution
```

ElastiCache is a managed distributed in-memory cache and data-store service supporting Valkey, Redis OSS and Memcached. It is designed to reduce the complexity of provisioning, managing and scaling caching infrastructure. ([AWS Documentation][1])

---

# 3. Why do we need a cache?

Assume your API repeatedly performs this database query:

```sql
SELECT *
FROM products
WHERE category_id = 10
ORDER BY popularity DESC
LIMIT 20;
```

The result changes only every few minutes, but users request it thousands of times per minute.

Without a cache:

```text
Every request
    ↓
Application
    ↓
Database query
    ↓
Disk/memory processing
    ↓
Result returned
```

With a cache:

```text
First request
    ↓
Cache miss
    ↓
Database query
    ↓
Store result in cache
    ↓
Return result

Later requests
    ↓
Cache hit
    ↓
Return directly from cache
```

A cache can reduce:

* Database CPU.
* Database connections.
* Query latency.
* Repeated computation.
* Load on downstream APIs.
* Application response time.

ElastiCache provides an in-memory environment designed for very low-latency access compared with repeatedly retrieving the same information from slower backing stores. ([Amazon Web Services, Inc.][2])

---

# 4. Cache is not automatically the source of truth

The most important mental model is:

```text
Database:
Authoritative permanent data

Cache:
Optimized copy of frequently accessed data
```

For example:

```text
RDS customer record:
Authoritative

Cached customer profile:
Temporary copy
```

If the cache disappears, the application should normally be able to rebuild its cached content from the source database.

This design is called:

```text
Disposable cache architecture
```

However, Valkey and Redis OSS can also be used for data structures such as sessions, counters, leaderboards and coordination state. In those cases, you must explicitly decide how much data loss is acceptable and whether backups or another authoritative system are required.

---

# 5. Supported ElastiCache engines

Amazon ElastiCache supports:

```text
Valkey
Redis OSS
Memcached
```

([AWS Documentation][3])

## Valkey

Valkey is an open-source, Redis-compatible in-memory data store.

It supports:

* Strings.
* Hashes.
* Lists.
* Sets.
* Sorted sets.
* Streams.
* Pub/Sub.
* Transactions.
* Lua scripts.
* Expiration.
* Replication.
* Sharding.
* Access control lists.

For new Redis-compatible ElastiCache workloads, Valkey is an important engine option to evaluate.

## Redis OSS

ElastiCache continues to support specified Redis OSS versions. Older Redis OSS 4 and 5 versions reached the end of standard ElastiCache support on January 31, 2026, so production systems running older versions require an upgrade or an applicable extended-support strategy. ([AWS Documentation][4])

## Memcached

Memcached is simpler and primarily provides distributed key-value caching.

Use it when:

* You need a simple disposable cache.
* You do not need replication.
* You do not need rich data structures.
* You do not need sorted sets, streams or transactions.
* You can tolerate losing all cached data.

## Simplified decision

```text
Need replication, failover, rich structures or sessions?
    → Valkey or Redis OSS

Need only simple distributed object caching?
    → Memcached may be sufficient
```

This lesson primarily focuses on **Valkey**, while most concepts also apply to Redis OSS.

---

# 6. Serverless versus node-based ElastiCache

ElastiCache provides two broad deployment models:

```text
1. Serverless caches
2. Node-based clusters
```

([AWS Documentation][5])

## Serverless cache

AWS manages the underlying cache capacity and automatically adjusts to workload demand.

You primarily configure:

* Engine.
* Cache name.
* VPC and subnets.
* Security groups.
* Data-storage limits.
* Processing limits.
* Encryption.
* Authentication.
* Backup settings.

Suitable for:

* Unpredictable traffic.
* Rapidly changing workloads.
* Teams that do not want to size nodes or shards.
* New applications.
* Workloads with idle and burst periods.
* Simpler operational management.

## Node-based cluster

You choose and manage:

* Node family and size.
* Number of shards.
* Number of replicas.
* Availability Zone placement.
* Cluster mode.
* Scaling strategy.
* Maintenance configuration.
* Parameter groups.

Suitable for:

* Predictable workloads.
* Detailed capacity control.
* Reserved-node cost optimization.
* Specific node families.
* Data-tiering requirements.
* Detailed topology requirements.
* Workloads requiring precise shard and replica design.

## Mental model

```text
Serverless:
AWS manages capacity units and infrastructure scaling.

Node-based:
You select the cache nodes, shards and replicas.
```

---

# 7. Core Valkey terminology

You must clearly distinguish these terms.

## Node

A node is an individual cache server.

```text
Node:
One running Valkey cache process
```

## Primary node

A primary accepts:

```text
Writes
Reads
```

## Replica node

A replica normally accepts:

```text
Read traffic
Replication updates from primary
```

## Shard

A shard contains:

```text
One primary
Zero to five replicas
```

Replication occurs within a shard. ([AWS Documentation][6])

## Replication group

An AWS ElastiCache resource that manages one or more Valkey/Redis OSS shards and their replicas.

## Cluster

The term “cluster” may refer broadly to the complete ElastiCache deployment.

## Never-forget hierarchy

```text
Replication group
    |
    ├── Shard 1
    │    ├── Primary
    │    └── Replica
    |
    ├── Shard 2
    │    ├── Primary
    │    └── Replica
    |
    └── Shard 3
         ├── Primary
         └── Replica
```

---

# 8. Cluster mode disabled

A cluster-mode-disabled replication group has:

```text
Exactly one shard
One primary
Zero to five replicas
```

([AWS Documentation][7])

Architecture:

```text
                 Primary
              Reads + writes
                    |
          asynchronous replication
             /              \
        Replica A          Replica B
        Read-only          Read-only
```

## Advantages

* Simpler application client configuration.
* One primary endpoint.
* No key-slot management.
* Multi-key operations are straightforward.
* Easy starting architecture.
* Read scaling through replicas.

## Limitations

* All data must fit within one shard’s capacity.
* Write throughput is limited by one primary.
* Horizontal write scaling through additional shards is unavailable.
* The node must hold the entire dataset plus operational overhead.

## Suitable workloads

```text
Sessions
Moderate-sized application cache
Rate limiting
Small leaderboards
Feature flags
Frequently accessed configuration
```

---

# 9. Cluster mode enabled

Cluster mode enabled partitions data across multiple shards.

```text
                    Valkey cluster
              /           |           \
          Shard 1       Shard 2       Shard 3
          P + R         P + R         P + R
```

Each key is assigned to a hash slot, and hash slots are distributed across shards.

Cluster mode enabled allows data and workload to be distributed horizontally. Current ElastiCache documentation supports up to 500 shards for eligible Valkey and Redis OSS configurations, with one to five replicas per shard. ([AWS Documentation][8])

## Advantages

* Horizontal write scaling.
* Horizontal memory scaling.
* Data distributed across multiple primaries.
* Larger total dataset.
* Reduced single-primary bottleneck.
* Online resharding support.

## Challenges

* Clients must understand cluster redirections.
* Multi-key commands may require keys in the same hash slot.
* Transactions across different hash slots are restricted.
* Hot key distribution becomes important.
* Operational design is more complex.

## Suitable workloads

```text
Large distributed caches
High-throughput applications
Large session stores
Real-time counters
Large leaderboards
High-volume API caching
```

---

# 10. Hash slots

Valkey cluster mode uses hash slots to determine where keys live.

Conceptually:

```text
user:101 → hash slot → Shard 1
user:202 → hash slot → Shard 3
order:900 → hash slot → Shard 2
```

A cluster-aware client:

1. Connects to the cluster.
2. Learns the slot map.
3. Calculates the key’s slot.
4. Sends the command to the correct shard.
5. Handles redirection responses when topology changes.

## Hash tags

You can force related keys into the same hash slot by placing a shared value inside `{}`.

Example:

```text
cart:{user-101}
cart-items:{user-101}
cart-summary:{user-101}
```

Only the content inside braces is used to calculate the slot.

This allows commands involving related keys to execute within the same shard.

## Warning

Poor hash-tag design can create a hot shard:

```text
product:{all}:1
product:{all}:2
product:{all}:3
```

Because every key uses `{all}`, every key goes to one shard.

---

# 11. ElastiCache endpoints

Applications should connect using AWS-provided DNS endpoints, not node IP addresses.

## Primary endpoint

Used for writes in cluster-mode-disabled deployments:

```text
Primary endpoint
    ↓
Current primary node
```

## Reader endpoint

Distributes eligible read connections across replicas in cluster-mode-disabled replication groups.

```text
Reader endpoint
    ↓
Replica A or Replica B
```

The reader endpoint performs DNS-level endpoint distribution. It does not make a single established TCP connection automatically move between replicas.

## Configuration endpoint

Used by cluster-aware clients for cluster-mode-enabled deployments.

```text
Configuration endpoint
    ↓
Client discovers shards and slot ownership
```

## Never hard-code node IPs

During:

* Failover.
* Scaling.
* Maintenance.
* Node replacement.
* Resharding.

The underlying node can change while the logical endpoint remains the application’s connection target.

---

# 12. Replication behaviour

Within each shard:

```text
Write sent to primary
        ↓
Primary applies write
        ↓
Primary acknowledges operation
        ↓
Replicas receive update asynchronously
```

Valkey/Redis OSS replicas are updated asynchronously, so a replica can temporarily return older data. ([AWS Documentation][9])

This delay is called:

```text
Replication lag
```

## Example

```text
1. User updates their session on primary.
2. Application immediately reads from replica.
3. Replica has not yet applied the update.
4. Application sees an older session value.
```

For consistency-sensitive reads:

```text
Read from primary
```

For eventually consistent reads:

```text
Read from replicas
```

---

# 13. Multi-AZ and automatic failover

A production node-based replication group should usually include replicas in different Availability Zones.

```text
Availability Zone A             Availability Zone B

Primary node                    Replica node
Reads + writes                  Read-only
       |                              ^
       └── asynchronous replication ──┘
```

With Multi-AZ and automatic failover enabled, ElastiCache can promote a replica when the primary becomes unreachable. Multi-AZ requires at least one replica in the shard. ([AWS Documentation][10])

## Before failover

```text
Primary endpoint
      ↓
Primary in AZ-A
```

## Failure

```text
Primary in AZ-A becomes unavailable
```

## After failover

```text
Replica in AZ-B promoted
      ↓
Primary endpoint updated
      ↓
Application reconnects
```

ElastiCache promotes an existing replica rather than waiting to provision an entirely new primary, reducing write downtime. ([AWS Documentation][11])

---

# 14. What automatic failover does not guarantee

Automatic failover does not mean:

```text
No requests will ever fail.
```

During failover, applications may observe:

```text
Connection reset
Socket closed
Timeout
READONLY errors
DNS changes
Temporary command failure
```

The application should:

1. Use the logical endpoint.
2. Set reasonable connection and command timeouts.
3. Reconnect after failures.
4. Retry safe operations with backoff.
5. Refresh cluster topology.
6. Avoid infinite retries.
7. Avoid retry storms.

## Retry pattern

```text
Command fails
    ↓
Retry after 50 ms
    ↓
Retry after 100 ms
    ↓
Retry after 200 ms
    ↓
Stop after bounded attempts
```

Use:

```text
Exponential backoff
+
Random jitter
```

The jitter prevents all application instances from reconnecting at precisely the same time.

---

# 15. Cache-aside pattern

Cache-aside is the most common caching pattern.

The application explicitly controls the cache.

## Read flow

```text
1. Application checks cache.
2. If value exists, return it.
3. If value is missing, query database.
4. Store database result in cache.
5. Return result.
```

Pseudo-code:

```javascript
async function getProduct(productId) {
  const key = `product:${productId}`;

  const cached = await cache.get(key);

  if (cached) {
    return JSON.parse(cached);
  }

  const product = await database.findProductById(productId);

  if (product) {
    await cache.set(
      key,
      JSON.stringify(product),
      "EX",
      300
    );
  }

  return product;
}
```

## Advantages

* Cache is populated only when data is requested.
* Application remains in control.
* Cache failure can fall back to the database.
* Simple to understand.

## Disadvantages

* First request is slower.
* Data can become stale.
* Application must implement invalidation.
* Cache misses can overload the database.

---

# 16. Write-through pattern

In write-through caching, application writes update both:

```text
Database
Cache
```

Flow:

```text
Application write
    ↓
Write database
    ↓
Update cache
    ↓
Return success
```

Example:

```javascript
async function updateProduct(productId, update) {
  const product = await database.updateProduct(
    productId,
    update
  );

  await cache.set(
    `product:${productId}`,
    JSON.stringify(product),
    "EX",
    300
  );

  return product;
}
```

## Risk

Suppose:

```text
Database update succeeds.
Cache update fails.
```

Now the cache may contain old data.

A safer alternative is often:

```text
Database write succeeds
    ↓
Delete cache key
    ↓
Next read rebuilds cache
```

---

# 17. Cache invalidation

Cache invalidation means removing or updating cached data after the source changes.

This is one of the hardest caching problems.

## Example

Cached key:

```text
product:101
```

Database product changes.

The application must decide:

```text
Update the cached value?
Delete the cached value?
Wait for TTL expiration?
```

## Common strategy: delete after database update

```javascript
async function updateProduct(productId, update) {
  const product = await database.updateProduct(
    productId,
    update
  );

  await cache.del(`product:${productId}`);

  return product;
}
```

The next read recreates the key from the database.

## Why delete can be safer than update

Updating the cache requires you to reproduce the complete canonical cached representation.

Deleting says:

```text
“This data is no longer trusted. Rebuild it.”
```

---

# 18. TTL — Time to Live

A TTL automatically deletes a cache key after a configured duration.

```text
TTL = 300 seconds
```

After five minutes:

```text
Key expires
```

Example:

```bash
SET product:101 '{"name":"Laptop"}' EX 300
```

## Choosing a TTL

| Data                     |              Example TTL |
| ------------------------ | -----------------------: |
| Highly dynamic inventory |             5–30 seconds |
| Product details          |             5–30 minutes |
| Feature configuration    |              1–5 minutes |
| Public content           |            15–60 minutes |
| User session             | 15 minutes–several hours |
| Expensive report         |             5–60 minutes |

These are starting points, not universal production values.

Choose based on:

```text
How stale may the data become?
How expensive is regeneration?
How often does the data change?
What happens when every key expires?
```

---

# 19. Add TTL jitter

Suppose 100,000 product keys are cached at 12:00 with the same TTL:

```text
TTL = 300 seconds
```

At 12:05:

```text
100,000 keys expire together
```

The application sends a huge number of queries to the database.

This is called:

```text
Cache avalanche
```

Add random variation:

```javascript
const baseTtl = 300;
const jitter = Math.floor(Math.random() * 60);

await cache.set(
  key,
  JSON.stringify(value),
  "EX",
  baseTtl + jitter
);
```

Now expiration is spread across:

```text
300–359 seconds
```

---

# 20. Cache stampede

A cache stampede happens when many requests attempt to rebuild the same missing value simultaneously.

Example:

```text
Popular key expires.

Request 1 → Cache miss → Database query
Request 2 → Cache miss → Database query
Request 3 → Cache miss → Database query
...
Request 10,000 → Database query
```

One expired key can overwhelm the database.

## Solution 1: distributed rebuild lock

```text
Request 1 obtains lock
    ↓
Rebuilds cache

Other requests:
Wait, retry or use stale value
```

Example concept:

```bash
SET lock:product:101 unique-value NX EX 10
```

* `NX`: Set only if the key does not exist.
* `EX 10`: Lock expires after ten seconds.

## Solution 2: stale-while-revalidate

```text
Serve slightly stale value
    +
One process refreshes in background
```

## Solution 3: refresh before expiration

A scheduled process refreshes popular keys before they expire.

## Solution 4: request coalescing

Multiple requests inside the same application instance share one database operation.

---

# 21. Be careful with distributed locks

A basic Valkey lock is useful, but lock design is subtle.

Problems include:

* Process pauses.
* Network delays.
* Lock expiration while work is still running.
* Client crashes.
* Duplicate lock holders.
* Clock assumptions.
* Unlocking another client’s lock.

Always store a unique lock value:

```javascript
const lockValue = crypto.randomUUID();

const acquired = await cache.set(
  "lock:report",
  lockValue,
  "NX",
  "PX",
  10000
);
```

Release only when the stored value belongs to you, typically with an atomic Lua script.

```lua
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
end

return 0
```

For highly critical distributed coordination, evaluate whether a cache-based lock provides the guarantees your system actually requires.

---

# 22. Session storage

In a single-server application:

```text
User session stored in server memory
```

This becomes a problem with Auto Scaling:

```text
Request 1 → EC2-A → Session created
Request 2 → EC2-B → Session missing
```

Centralized sessions solve this:

```text
EC2-A ─┐
EC2-B ─┼──> ElastiCache session store
EC2-C ─┘
```

Session key:

```text
session:92bce5d8...
```

Value:

```json
{
  "userId": 104,
  "roles": ["customer"],
  "lastActivity": "2026-07-27T10:00:00Z"
}
```

Set an expiration:

```text
Session TTL = 30 minutes
```

## Session architecture advantages

* Application instances remain stateless.
* Any EC2 instance can process the next request.
* Auto Scaling can terminate instances safely.
* Session lookups are fast.

## Session risks

* Cache failure can log out users.
* Replication lag may temporarily expose old session state.
* Poor TTL configuration can retain inactive sessions.
* Large session objects waste memory.
* Sensitive session values require encryption and strict access control.

---

# 23. Rate limiting

Valkey is commonly used for distributed rate limiting.

Example requirement:

```text
Maximum 100 requests per user per minute
```

Simple fixed-window approach:

```text
Key:
rate:user:101:2026-07-27T10:30

Value:
Request count

TTL:
60 seconds
```

Pseudo-code:

```javascript
const key = `rate:user:${userId}:${minuteBucket}`;

const count = await cache.incr(key);

if (count === 1) {
  await cache.expire(key, 60);
}

if (count > 100) {
  throw new TooManyRequestsError();
}
```

For atomic correctness, use a Lua script or a transaction so increment and expiration are safely coordinated.

Other algorithms include:

* Sliding window.
* Token bucket.
* Leaky bucket.
* Sorted-set timestamp tracking.

---

# 24. Leaderboards

Valkey sorted sets are useful for ranking.

```bash
ZADD game:leaderboard 1500 player-101
ZADD game:leaderboard 2200 player-202
ZADD game:leaderboard 1800 player-303
```

Top players:

```bash
ZREVRANGE game:leaderboard 0 9 WITHSCORES
```

Get one player’s rank:

```bash
ZREVRANK game:leaderboard player-101
```

Suitable for:

* Gaming scores.
* Sales rankings.
* Popular content.
* Trending products.
* Competition results.

For permanent history, the authoritative results should usually also be stored in a durable database.

---

# 25. Pub/Sub and queue warning

Valkey Pub/Sub is useful for real-time notifications:

```text
Publisher → Channel → Active subscribers
```

However, traditional Pub/Sub messages are generally not retained for disconnected consumers.

```text
Subscriber offline
    ↓
Message may be missed
```

Use Pub/Sub for:

* Live notifications.
* Cache invalidation signals.
* Real-time UI events.
* Best-effort internal messaging.

For durable business queues, consider:

```text
Amazon SQS
Amazon MSK
Amazon Kinesis
Valkey Streams with carefully designed consumer handling
```

Do not use best-effort Pub/Sub as the only record of a critical payment or order event.

---

# 26. Memory is finite

Valkey primarily keeps active data in memory.

If a node has:

```text
13 GiB available cache memory
```

You cannot safely store exactly 13 GiB of application data.

Memory is also required for:

* Replication buffers.
* Client connections.
* Internal metadata.
* Key overhead.
* Fragmentation.
* Backup operations.
* Failover operations.
* Command processing.

ElastiCache reserves or requires memory for non-data operations, and insufficient operational memory can cause backup or synchronization processes to fail. ([AWS Documentation][12])

---

# 27. Eviction policies

When memory becomes full, the `maxmemory-policy` determines what happens.

Common policies include:

```text
noeviction
allkeys-lru
volatile-lru
allkeys-lfu
volatile-lfu
allkeys-random
volatile-random
volatile-ttl
```

The parameter is configurable for supported node-based deployments, with `volatile-lru` documented as a common default. ([AWS Documentation][13])

## `noeviction`

```text
Do not remove keys automatically.
Reject new writes when memory is exhausted.
```

Suitable when losing cached values is unacceptable, but it requires strict memory monitoring.

## `allkeys-lru`

```text
Evict less recently used keys from all keys.
```

Useful for general-purpose disposable caches.

## `volatile-lru`

```text
Evict less recently used keys only from keys with TTLs.
```

Keys without expiration are protected from normal eviction.

## `allkeys-lfu`

```text
Evict less frequently used keys.
```

Useful when access frequency is more meaningful than recent access.

## Important warning

If you use a volatile policy but many keys do not have TTLs:

```text
Memory becomes full
    ↓
Few or no keys are eligible
    ↓
Writes receive OOM errors
```

---

# 28. Eviction is not the same as expiration

## Expiration

A key is deleted because its TTL ended.

```text
TTL reached
```

## Eviction

A key is deleted because the cache needs memory.

```text
Memory pressure
```

Monitor them separately:

```text
Expired keys:
Expected lifecycle behaviour

Evictions:
Possible capacity or design warning
```

A sudden increase in evictions can indicate:

* Node too small.
* Cache objects too large.
* TTLs too long.
* Traffic growth.
* Hot dataset growth.
* Inappropriate eviction policy.
* Memory fragmentation.

---

# 29. Key design

Good key names should be:

* Predictable.
* Namespaced.
* Compact.
* Easy to invalidate.
* Safe for multi-tenant use.

Examples:

```text
prod:product:101
prod:user:202:profile
prod:session:abc123
prod:rate:user:202:minute:12345
```

## Include environment

Bad:

```text
product:101
```

Better:

```text
dev:product:101
staging:product:101
prod:product:101
```

## Include tenant where required

```text
prod:tenant:acme:product:101
```

## Avoid huge keys

A very long key consumes memory and network bandwidth.

## Avoid huge values

Instead of caching one 100 MiB object, consider:

* Smaller objects.
* Pagination.
* Compression.
* Separate key groups.
* A different storage service.

---

# 30. Hot keys

A hot key receives a disproportionately large amount of traffic.

Example:

```text
homepage:trending
```

One key may receive:

```text
200,000 requests per second
```

Even in a multi-shard cluster, one key belongs to one hash slot and therefore one shard.

Adding more shards does not divide a single key.

Possible solutions:

* Application-local caching.
* Replicas for read traffic.
* Key duplication.
* Request coalescing.
* CDN caching where applicable.
* Short-lived process memory cache.
* Breaking one large object into partitioned keys.

## Key duplication example

Instead of:

```text
homepage:trending
```

Use:

```text
homepage:trending:0
homepage:trending:1
homepage:trending:2
homepage:trending:3
```

The application randomly selects one copy for reads.

Updates must refresh all copies, so this trades operational complexity for load distribution.

---

# 31. Big-key problem

A big key is a key containing an unusually large value or collection.

Examples:

```text
One hash with millions of fields
One list with millions of entries
One 50 MiB JSON value
One sorted set containing the complete event history
```

Big keys can cause:

* High command latency.
* Network congestion.
* Long deletion time.
* Replication pressure.
* Uneven shard memory.
* Failover delays.
* Expensive backups.
* Client timeouts.

Prefer bounded structures:

```text
user-events:101:2026-07
user-events:101:2026-08
```

Instead of:

```text
user-events:101:all-time
```

---

# 32. Network and subnet design

ElastiCache should normally run inside private application-accessible networks.

```text
Public subnets:
ALB

Private application subnets:
EC2, ECS or EKS workloads

Private cache subnets:
ElastiCache nodes
```

A node-based cluster uses a cache subnet group to determine eligible subnets.

Terraform:

```hcl
resource "aws_elasticache_subnet_group" "cache" {
  name = "${var.environment}-cache-subnet-group"

  subnet_ids = [
    aws_subnet.private_cache_a.id,
    aws_subnet.private_cache_b.id
  ]

  tags = {
    Name        = "${var.environment}-cache-subnet-group"
    Environment = var.environment
  }
}
```

Use at least two Availability Zones for a highly available replication group.

---

# 33. Security groups

Use a dedicated cache security group.

## Application security group

```text
application-sg
```

## Cache security group

```text
cache-sg

Inbound:
TCP 6379 from application-sg
```

Terraform:

```hcl
resource "aws_security_group" "cache" {
  name        = "${var.environment}-cache-sg"
  description = "Allow Valkey access from application workloads"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Valkey from application security group"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Do not use:

```text
6379 from 0.0.0.0/0
```

ElastiCache serverless uses ports 6379 and 6380 for relevant internal connection behaviour, so the required security-group configuration differs slightly from node-based clusters. ([AWS Documentation][14])

---

# 34. Encryption

ElastiCache provides:

```text
Encryption in transit
Encryption at rest
```

In-transit encryption protects traffic between applications and the cache and between cache nodes. At-rest encryption protects on-disk data used during synchronization and backup operations. ([AWS Documentation][15])

Terraform:

```hcl
transit_encryption_enabled = true
at_rest_encryption_enabled = true
```

Application connection:

```text
valkeys://
```

or TLS-enabled Redis-compatible client configuration.

Example:

```javascript
const cache = new Redis({
  host: process.env.CACHE_HOST,
  port: 6379,
  tls: {},
  connectTimeout: 5000
});
```

Do not disable TLS certificate validation in production merely to bypass certificate errors.

---

# 35. Authentication and authorization

ElastiCache supports:

* Password or AUTH-based authentication.
* Role-Based Access Control.
* IAM authentication for supported Valkey and Redis OSS versions.

([AWS Documentation][16])

## RBAC

RBAC lets you create users with limited commands and key access.

Example conceptual permissions:

```text
Application user:
Can GET and SET prod:app:* keys

Reporting user:
Can GET report:* keys
Cannot write

Administration user:
Restricted operational access
```

This is better than giving every workload unrestricted command access.

## Dangerous commands

Normal applications usually should not receive unrestricted access to commands such as:

```text
FLUSHALL
FLUSHDB
CONFIG
EVAL
KEYS
SHUTDOWN
```

Access-control design should limit both:

```text
Which commands may be executed?
Which keys may be accessed?
```

---

# 36. IAM authentication

IAM authentication is supported for:

```text
Valkey 7.2 and above
Redis OSS 7.0 and above
```

It requires in-transit encryption. ([AWS Documentation][17])

Flow:

```text
EC2 IAM role
    ↓
Generate short-lived IAM authentication token
    ↓
Connect over TLS
    ↓
Authenticate as ElastiCache user
```

Advantages:

* Reduces long-lived password usage.
* Integrates access with IAM roles.
* Useful for EC2, ECS, EKS and Lambda.
* Supports centralized identity controls.

IAM authentication does not replace RBAC.

```text
IAM:
May this AWS principal authenticate?

RBAC:
Which cache commands and keys may it access?
```

---

# 37. Backups and snapshots

ElastiCache can create snapshots for Valkey and Redis OSS caches.

A snapshot includes cache metadata and data and is stored in Amazon S3-managed backup storage. Restoration creates and populates a new cache. ([AWS Documentation][18])

## Automatic backups

Automatic backups can run daily.

Configuration includes:

* Backup window.
* Retention period.

The maximum automatic-backup retention period is 35 days. Setting retention to zero disables automatic backups. ([AWS Documentation][19])

Terraform:

```hcl
snapshot_retention_limit = 7
snapshot_window          = "18:00-19:00"
```

## Manual backups

Manual backups remain until explicitly deleted; they are not automatically removed through the automatic-backup retention setting. ([AWS Documentation][20])

## Important cache-backup principle

A backup does not turn a cache into a strongly durable transactional database.

You must still define:

```text
RPO:
How much cached state may be lost?

RTO:
How quickly must cache functionality return?

Rebuildability:
Can data be reconstructed from RDS or another source?
```

---

# 38. Should every cache be backed up?

Not necessarily.

## Cache of product data

```text
Source: RDS
Cache: Rebuildable
```

Backups may be unnecessary because the application can refill it.

## User sessions

Losing the cache may log out all users.

Backups might reduce cold-start impact, but restored data may be outdated.

## Real-time leaderboard

If the cache is the only location containing scores, losing it causes permanent data loss.

That indicates:

```text
The cache is being used as a primary database.
```

Store critical events or final scores in a durable source.

## Practical classification

```text
Disposable cache:
No backup required

Expensive-to-rebuild cache:
Backup useful

Business-critical cache-only state:
Redesign durability strategy
```

---

# 39. Vertical scaling

Vertical scaling changes node size.

```text
cache.t4g.small
       ↓
cache.r7g.large
       ↓
cache.r7g.xlarge
```

Scaling up provides:

* More memory.
* More network capacity.
* More CPU.
* Higher command throughput.

ElastiCache supports online vertical scaling for eligible Valkey and Redis OSS clusters while continuing to serve requests, although applications should still be designed for topology and connection changes. ([AWS Documentation][21])

Vertical scaling is useful when:

* Dataset fits one shard.
* One primary provides sufficient write throughput.
* You need more memory or CPU.
* Simplicity is preferred.

---

# 40. Horizontal scaling

Horizontal scaling can mean:

```text
Adding replicas:
More read capacity and availability

Adding shards:
More write capacity and total memory
```

## Adding replicas

```text
Shard:
Primary + one replica
          ↓
Primary + three replicas
```

Eligible deployments can have up to five replicas per shard. ([AWS Documentation][22])

## Adding shards

```text
Two shards
    ↓
Six shards
```

The key space is redistributed through resharding.

Online resharding allows eligible cluster-mode-enabled deployments to add or remove shards without a complete service outage. AWS recommends testing resharding and initiating it before the cache reaches severe resource saturation. ([AWS Documentation][23])

---

# 41. ElastiCache Auto Scaling

Application Auto Scaling can adjust eligible Valkey/Redis OSS cluster capacity.

It can scale:

* Replica count.
* Shard count for supported cluster-mode-enabled deployments.

For example:

```text
Replica target:
Maintain average replica CPU near 50%

Shard target:
Maintain memory utilization below target
```

AWS exposes scalable dimensions such as replicas per shard through Application Auto Scaling. ([AWS Documentation][24])

## Warning

Cache scaling is not instantaneous.

Do not wait until:

```text
Memory = 99%
CPU = 100%
Evictions increasing rapidly
```

Scale before the system reaches its failure boundary.

---

# 42. Data tiering

Data tiering combines:

```text
DRAM
+
Local SSD
```

Frequently accessed data stays in memory, while less frequently accessed data can be placed on local SSD.

ElastiCache supports data tiering on applicable `r6gd` node families. It provides a lower-cost capacity option for datasets larger than available DRAM. ([AWS Documentation][25])

Architecture:

```text
Hot keys
    ↓
Memory

Warm or less frequently accessed keys
    ↓
Local SSD
```

## Suitable workloads

* Large datasets.
* Only part of the dataset is frequently accessed.
* Slightly higher latency for cold data is acceptable.
* Cost-effective capacity is more important than uniform memory latency.

## Not equivalent to durable storage

Local SSD data tiering is part of the managed cache architecture.

It is not a replacement for:

* RDS.
* DynamoDB.
* S3.
* Durable event storage.

---

# 43. Global Datastore

Global Datastore replicates Valkey or Redis OSS data across AWS Regions.

```text
Primary Region: ap-south-1
Primary cluster
       |
       | asynchronous cross-Region replication
       v
Secondary Region: ap-southeast-1
Secondary cluster
```

It supports:

* Cross-Region read access.
* Lower-latency regional reads.
* Disaster-recovery architecture.
* Managed asynchronous replication.

([AWS Documentation][26])

## Important limitations

Because replication is asynchronous:

```text
Regional failure may cause some recent writes to be missing
in the secondary Region.
```

You must define:

* Promotion procedure.
* DNS or application endpoint change.
* Accepted replication lag.
* RPO.
* RTO.
* Failback process.
* Re-establishment of replication.

Global Datastore is an important DR building block, not a complete disaster-recovery runbook.

---

# 44. Serverless cache behaviour

ElastiCache Serverless removes the need to select:

```text
Node type
Number of shards
Replica topology
```

Instead, the service manages capacity according to application demand.

Serverless is useful when:

* Workload is difficult to predict.
* Traffic is highly variable.
* You want minimal cluster operations.
* You need rapid scaling.
* You do not want to manually manage shards.

Serverless Valkey/Redis OSS caches have capacity and request-processing limits, including per-cache and per-slot limits. These limits must still be considered for large or hot-key workloads. ([AWS Documentation][27])

## Serverless does not eliminate application design

You still need to design:

* TTLs.
* Invalidation.
* Retries.
* Key distribution.
* Hot-key handling.
* Security.
* Monitoring.
* Cache fallback.
* Cost controls.

---

# 45. Essential CloudWatch metrics

Node-based Valkey and Redis OSS metrics are published under:

```text
AWS/ElastiCache
```

([AWS Documentation][28])

Important metrics include:

```text
CPUUtilization
EngineCPUUtilization
FreeableMemory
BytesUsedForCache
DatabaseMemoryUsagePercentage
CurrConnections
NewConnections
CacheHits
CacheMisses
CacheHitRate
Evictions
Reclaimed
ReplicationLag
NetworkBytesIn
NetworkBytesOut
SwapUsage
CurrItems
SuccessfulReadRequestLatency
SuccessfulWriteRequestLatency
```

## Serverless metrics

Serverless provides metrics around:

* Cache data stored.
* ElastiCache Processing Units.
* Connections.
* Cache hits and misses.
* Command-specific activity.
* Request latency.

Serverless cache events can also be integrated with EventBridge. ([AWS Documentation][29])

---

# 46. Cache-hit ratio

Cache-hit ratio measures how often requested data is found in cache.

Formula:

```text
Hit ratio =
Cache hits / (Cache hits + Cache misses)
```

Example:

```text
Cache hits:   9,000
Cache misses: 1,000

Hit ratio:
9,000 / 10,000 = 90%
```

A low ratio may mean:

* TTLs are too short.
* Wrong data is being cached.
* Keys are inconsistent.
* Cache is too small.
* High eviction rate.
* Workload rarely repeats.
* Invalidation is too aggressive.

A high ratio is good only when cached values remain sufficiently correct for the business requirement.

---

# 47. Recommended CloudWatch alarms

A production cache should normally alarm on:

```text
High EngineCPUUtilization
Low FreeableMemory
High DatabaseMemoryUsagePercentage
Evictions greater than expected
ReplicationLag
High CurrConnections
Connection growth
High cache-miss ratio
SwapUsage
High request latency
Primary failover events
Node replacement events
Snapshot failures
```

Illustrative Terraform alarm:

```hcl
resource "aws_cloudwatch_metric_alarm" "cache_evictions" {
  alarm_name          = "${var.environment}-cache-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Sum"
  threshold           = 100

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.cache.id
  }

  alarm_description = "ElastiCache is evicting keys"
  alarm_actions     = [aws_sns_topic.operations.arn]
}
```

Metric dimensions can vary by metric and topology, so validate the actual CloudWatch dimensions produced by your cache.

---

# 48. Terraform node-based replication group

The following example creates a Multi-AZ Valkey replication group with one replica:

```hcl
resource "aws_elasticache_subnet_group" "cache" {
  name = "${var.environment}-cache-subnet-group"

  subnet_ids = [
    aws_subnet.private_cache_a.id,
    aws_subnet.private_cache_b.id
  ]
}

resource "aws_elasticache_parameter_group" "valkey" {
  name   = "${var.environment}-valkey-parameters"
  family = var.valkey_parameter_group_family

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

resource "aws_elasticache_replication_group" "cache" {
  replication_group_id = "${var.environment}-application-cache"
  description          = "Production application Valkey cache"

  engine         = "valkey"
  engine_version = var.valkey_engine_version
  node_type      = var.cache_node_type
  port           = 6379

  num_cache_clusters = 2

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name = aws_elasticache_subnet_group.cache.name

  security_group_ids = [
    aws_security_group.cache.id
  ]

  parameter_group_name = (
    aws_elasticache_parameter_group.valkey.name
  )

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 7
  snapshot_window          = "18:00-19:00"
  maintenance_window       = "sun:19:00-sun:20:00"

  auto_minor_version_upgrade = true
  apply_immediately           = false

  tags = {
    Name        = "${var.environment}-application-cache"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

The AWS provider supports Valkey through the ElastiCache replication-group resource, while serverless deployments use the separate serverless-cache resource. ([Terraform Registry][30])

## Production note

Avoid hard-coding:

```hcl
engine_version = "..."
parameter_group_family = "..."
```

across many files.

Keep them as controlled environment variables so engine and parameter-family upgrades can be tested deliberately.

---

# 49. Terraform cluster-mode-enabled example

```hcl
resource "aws_elasticache_replication_group" "clustered_cache" {
  replication_group_id = "${var.environment}-clustered-cache"
  description          = "Sharded Valkey application cache"

  engine         = "valkey"
  engine_version = var.valkey_engine_version
  node_type      = var.cache_node_type

  port = 6379

  num_node_groups         = 3
  replicas_per_node_group = 1

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name = aws_elasticache_subnet_group.cache.name

  security_group_ids = [
    aws_security_group.cache.id
  ]

  parameter_group_name = var.cluster_parameter_group_name

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true

  snapshot_retention_limit = 7
  snapshot_window          = "18:00-19:00"

  apply_immediately = false

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

Capacity:

```text
3 shards
×
1 primary per shard
+
1 replica per shard

Total nodes = 6
```

---

# 50. Node.js cache-aside implementation

Install client:

```bash
npm install ioredis
```

Connection:

```javascript
import Redis from "ioredis";

const cache = new Redis({
  host: process.env.CACHE_HOST,
  port: Number(process.env.CACHE_PORT ?? 6379),

  tls: {},

  connectTimeout: 5000,
  commandTimeout: 2000,

  maxRetriesPerRequest: 2,

  retryStrategy(times) {
    const delay = Math.min(times * 100, 2000);
    const jitter = Math.floor(Math.random() * 100);

    return delay + jitter;
  },

  lazyConnect: true
});

cache.on("connect", () => {
  console.log("Cache connection established");
});

cache.on("error", (error) => {
  console.error("Cache error:", error.message);
});

export async function connectCache() {
  try {
    await cache.connect();
    await cache.ping();
  } catch (error) {
    console.error("Cache unavailable:", error);
  }
}

export { cache };
```

## Cache-aside service

```javascript
import { cache } from "./cache.js";
import { productRepository } from "./product-repository.js";

export async function getProduct(productId) {
  const cacheKey = `prod:product:${productId}`;

  try {
    const cachedValue = await cache.get(cacheKey);

    if (cachedValue) {
      return {
        source: "cache",
        value: JSON.parse(cachedValue)
      };
    }
  } catch (error) {
    console.error("Cache read failed:", error.message);
  }

  const product = await productRepository.findById(productId);

  if (!product) {
    return null;
  }

  try {
    const baseTtlSeconds = 300;
    const jitterSeconds = Math.floor(Math.random() * 60);

    await cache.set(
      cacheKey,
      JSON.stringify(product),
      "EX",
      baseTtlSeconds + jitterSeconds
    );
  } catch (error) {
    console.error("Cache write failed:", error.message);
  }

  return {
    source: "database",
    value: product
  };
}
```

Notice the fallback:

```text
Cache unavailable
    ↓
Application still queries database
```

Whether that fallback is safe depends on whether the database can survive the resulting miss storm.

---

# 51. Cluster-aware Node.js client

For cluster mode enabled:

```javascript
import Redis from "ioredis";

const cluster = new Redis.Cluster(
  [
    {
      host: process.env.CACHE_CONFIGURATION_ENDPOINT,
      port: 6379
    }
  ],
  {
    dnsLookup: (address, callback) => {
      callback(null, address);
    },

    redisOptions: {
      tls: {},
      connectTimeout: 5000,
      commandTimeout: 2000
    },

    clusterRetryStrategy(times) {
      return Math.min(times * 100, 2000);
    },

    scaleReads: "slave"
  }
);
```

Use a library version that explicitly supports your selected Valkey/Redis OSS engine and cluster topology.

Test:

* Failover.
* Resharding.
* DNS changes.
* Connection exhaustion.
* Retry behaviour.
* Cluster redirections.

---

# 52. AWS CLI validation

Describe replication groups:

```bash
aws elasticache describe-replication-groups \
  --region ap-south-1
```

Describe one group:

```bash
aws elasticache describe-replication-groups \
  --replication-group-id production-application-cache \
  --region ap-south-1 \
  --query 'ReplicationGroups[0].{
    Status:Status,
    Engine:Engine,
    AutomaticFailover:AutomaticFailover,
    MultiAZ:MultiAZ,
    ClusterEnabled:ClusterEnabled,
    MemberClusters:MemberClusters
  }'
```

Describe cache clusters and endpoints:

```bash
aws elasticache describe-cache-clusters \
  --show-cache-node-info \
  --region ap-south-1 \
  --query 'CacheClusters[*].{
    Cluster:CacheClusterId,
    Status:CacheClusterStatus,
    AZ:PreferredAvailabilityZone,
    Endpoint:CacheNodes[0].Endpoint.Address,
    Port:CacheNodes[0].Endpoint.Port
  }'
```

List events:

```bash
aws elasticache describe-events \
  --source-type replication-group \
  --source-identifier production-application-cache \
  --duration 1440 \
  --region ap-south-1
```

---

# 53. Connectivity test

Install Valkey or Redis-compatible CLI:

```bash
sudo apt update
sudo apt install -y redis-tools
```

For TLS:

```bash
redis-cli \
  --tls \
  -h "$CACHE_HOST" \
  -p 6379 \
  PING
```

Expected:

```text
PONG
```

Set and retrieve a test value:

```bash
redis-cli --tls -h "$CACHE_HOST" -p 6379 \
  SET lab:message "ElastiCache connection successful" EX 300
```

```bash
redis-cli --tls -h "$CACHE_HOST" -p 6379 \
  GET lab:message
```

Check TTL:

```bash
redis-cli --tls -h "$CACHE_HOST" -p 6379 \
  TTL lab:message
```

Do not expose passwords or IAM authentication tokens in shell history or CI logs.

---

# 54. Test automatic failover

Perform this only in a controlled lab or approved production test.

Identify the primary cluster member:

```bash
aws elasticache describe-replication-groups \
  --replication-group-id production-application-cache \
  --region ap-south-1 \
  --query 'ReplicationGroups[0].NodeGroups[0].NodeGroupMembers[*].{
    ID:CacheClusterId,
    Role:CurrentRole,
    AZ:PreferredAvailabilityZone
  }'
```

For eligible replication groups, initiate a test failover:

```bash
aws elasticache test-failover \
  --replication-group-id production-application-cache \
  --node-group-id 0001 \
  --region ap-south-1
```

During the test, monitor:

```text
Application error rate
Cache connection errors
Retry counts
Latency
Database fallback load
New primary
Replication lag
ElastiCache events
```

Expected sequence:

```text
1. Current primary becomes unavailable for writes.
2. Replica is promoted.
3. Endpoint topology is updated.
4. Clients reconnect.
5. Writes resume.
6. Replacement replica is established.
```

---

# 55. Troubleshooting: connection timeout

Symptom:

```text
Connection timed out
```

Check:

```text
Is the application in the same VPC or connected network?
Does cache SG allow the application SG?
Is the correct port used?
Is DNS resolving?
Is TLS enabled in the client?
Is the cache available?
```

Commands:

```bash
getent hosts "$CACHE_HOST"
```

```bash
nc -vz "$CACHE_HOST" 6379
```

Interpretation:

```text
DNS fails:
Endpoint or VPC DNS issue

TCP timeout:
SG, NACL, route or network issue

TCP works but TLS fails:
TLS or client configuration issue

TLS works but AUTH fails:
User, password, token or RBAC issue
```

---

# 56. Troubleshooting: `READONLY` error

Symptom:

```text
READONLY You can't write against a read only replica
```

Possible causes:

* Client connected directly to a replica.
* Failover occurred and the client retained a stale connection.
* Client does not refresh topology.
* Wrong endpoint was configured.
* Cluster client is not cluster-aware.

Fix:

```text
Use primary or configuration endpoint.
Reconnect after failover.
Use a compatible cluster-aware client.
Do not hard-code node addresses.
```

---

# 57. Troubleshooting: OOM error

Symptom:

```text
OOM command not allowed when used memory > 'maxmemory'
```

Possible causes:

* `noeviction` policy.
* Volatile eviction policy but keys lack TTLs.
* Node too small.
* Values too large.
* TTLs too long.
* Memory fragmentation.
* Sudden dataset growth.
* Hot shard.

Check:

```bash
redis-cli --tls -h "$CACHE_HOST" INFO memory
```

Investigate:

```text
used_memory
used_memory_peak
used_memory_rss
mem_fragmentation_ratio
maxmemory
evicted_keys
expired_keys
```

Solutions:

* Add appropriate TTLs.
* Change eviction policy carefully.
* Scale node size.
* Add shards.
* Reduce object size.
* Delete obsolete data.
* Fix key-distribution problems.

---

# 58. Troubleshooting: high CPU

Possible causes:

* Expensive commands.
* Large Lua scripts.
* Hot keys.
* Large sorted-set operations.
* Large key deletion.
* Excessive connection churn.
* `KEYS *` usage.
* Poorly bounded range queries.
* Too many requests on one shard.

Avoid in production:

```bash
KEYS *
```

`KEYS` can scan the complete key space and block useful processing.

Use incremental scanning:

```bash
SCAN 0 MATCH 'prod:product:*' COUNT 100
```

Even `SCAN` should be operationally controlled on large production caches.

Monitor:

```text
EngineCPUUtilization
Command latency
Hot shard
Request rate
Slow logs where configured
```

---

# 59. Troubleshooting: high replication lag

Possible causes:

* Primary write volume too high.
* Replica node undersized.
* Network pressure.
* Large values.
* Big-key updates.
* Slow replica.
* Backup or maintenance activity.
* Expensive read workload on replica.

Impact:

```text
Stale replica reads
Greater potential data loss during primary failure
Longer synchronization
```

Actions:

* Scale nodes.
* Reduce large writes.
* Add or rebalance shards.
* Route consistency-sensitive reads to primary.
* Investigate hot shards.
* Reduce large replica read operations.
* Monitor network throughput.

---

# 60. Troubleshooting: low cache-hit ratio

Possible causes:

```text
Key naming differs between reads and writes.
TTL too short.
Cache too small.
Frequent evictions.
Wrong data chosen for caching.
Requests are mostly unique.
Application deletes keys too aggressively.
```

Example bug:

```javascript
// Write
cache.set(`product:${productId}`, value);

// Read
cache.get(`products:${productId}`);
```

The difference between `product` and `products` produces permanent misses.

Implement a centralized key builder:

```javascript
const cacheKeys = {
  product: (productId) => `prod:product:${productId}`,
  user: (userId) => `prod:user:${userId}`
};
```

---

# 61. Cache failure and database protection

When the cache fails:

```text
All requests
    ↓
Database
```

This can create a second outage.

```text
Cache outage
    ↓
Database overload
    ↓
Full application outage
```

Protect the database using:

* Rate limiting.
* Circuit breakers.
* Request coalescing.
* Bounded concurrency.
* Stale local cache.
* Graceful degradation.
* Load shedding.
* Precomputed fallback responses.

Example degradation:

```text
Personal recommendations unavailable
    ↓
Return general popular products
```

This is better than allowing every request to execute an expensive recommendation query.

---

# 62. Production checklist

```text
[ ] Correct engine is selected
[ ] Serverless versus node-based decision is documented
[ ] Cluster mode decision is documented
[ ] At least one replica exists for critical node-based workloads
[ ] Multi-AZ automatic failover is enabled
[ ] Cache is placed in private subnets
[ ] Security group allows only trusted applications
[ ] In-transit encryption is enabled
[ ] At-rest encryption is enabled
[ ] RBAC or appropriate authentication is configured
[ ] Application does not use unrestricted administrative commands
[ ] TTL strategy is documented
[ ] TTL jitter is implemented
[ ] Cache invalidation is tested
[ ] Cache stampede protection exists
[ ] Hot-key risks are tested
[ ] Large-key risks are monitored
[ ] Eviction policy matches workload
[ ] Memory headroom is maintained
[ ] Failover is tested
[ ] Application reconnect logic works
[ ] Retries are bounded and use jitter
[ ] Cache failure does not immediately destroy the database
[ ] Cache-hit ratio is monitored
[ ] Evictions are alarmed
[ ] Replication lag is alarmed
[ ] CPU and memory are alarmed
[ ] Backup requirements are documented
[ ] Restore is tested when backups are required
[ ] Regional DR requirements are documented
[ ] Terraform state and secrets are protected
```

---

# 63. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
ElastiCache is a managed in-memory caching service.

It improves application performance by reducing repeated work
against slower backing systems.
```

## Solutions Architect Associate

Understand:

```text
Valkey/Redis OSS versus Memcached
Cache-aside
Cluster mode disabled versus enabled
Primary and replica nodes
Multi-AZ automatic failover
TTL and eviction
Sessions
Read scaling
Sharding
Encryption
```

## DevOps Engineer Professional

Understand:

```text
Failover testing
Online resharding
Application retry behaviour
CloudWatch monitoring
RBAC and IAM authentication
Snapshot automation
Global Datastore
Cache stampede prevention
Infrastructure as Code
Event-driven operational automation
Engine upgrades
```

---

# 64. Interview questions

## Question 1: What is the difference between RDS and ElastiCache?

**Answer:**

RDS is normally the durable relational source of truth. ElastiCache is an in-memory caching and data-structure service used to reduce latency and load on databases or downstream systems. Cached data should usually be rebuildable unless a separate durability design exists.

## Question 2: What is cluster mode?

**Answer:**

Cluster mode enabled partitions keys across multiple shards, providing horizontal memory and write scaling. Cluster mode disabled uses one shard with one primary and optional replicas.

## Question 3: What is a shard?

**Answer:**

A shard is a Valkey or Redis OSS node group containing one primary node and zero or more read replicas. In cluster mode enabled, data is partitioned across multiple shards.

## Question 4: What is the purpose of a replica?

**Answer:**

A replica provides read capacity and can be promoted during automatic failover. Replication is asynchronous, so replica reads may temporarily be stale.

## Question 5: What is cache-aside?

**Answer:**

The application first checks the cache. On a miss, it reads from the database, stores the result in cache and returns it.

## Question 6: What is cache invalidation?

**Answer:**

Cache invalidation removes or updates cached values after the authoritative data changes so applications do not continue serving stale information.

## Question 7: What is a cache stampede?

**Answer:**

It occurs when many requests miss the same key simultaneously and all attempt to rebuild it from the backing database, potentially overwhelming the database.

## Question 8: What is an eviction?

**Answer:**

An eviction occurs when the cache removes a key to free memory according to its configured eviction policy. It is different from normal TTL expiration.

## Question 9: Why use Valkey for application sessions?

**Answer:**

A centralized Valkey session store makes application servers stateless, allowing any server in an Auto Scaling group to process the user’s next request.

## Question 10: What happens during ElastiCache failover?

**Answer:**

An eligible replica is promoted to primary, endpoints and cluster topology are updated, and applications reconnect. Some operations can fail temporarily, so retry and reconnect logic is required.

## Question 11: Does adding shards fix every hot-key problem?

**Answer:**

No. A single key belongs to one hash slot and one shard. More shards distribute different keys but do not split one hot key.

## Question 12: When would you use ElastiCache Serverless?

**Answer:**

It is useful when demand is unpredictable or when a team wants AWS to manage the underlying capacity and scaling instead of selecting node types, shard counts and replica topology.

---

# 65. Never-forget revision

```text
ElastiCache:
Managed in-memory cache and data store.

Valkey:
Redis-compatible open-source engine.

Primary:
Accepts reads and writes.

Replica:
Read-only copy that can be promoted.

Shard:
One primary plus replicas.

Cluster mode disabled:
One shard.

Cluster mode enabled:
Multiple shards and partitioned data.

Multi-AZ:
Places primary and replicas across Availability Zones.

Automatic failover:
Promotes a replica when the primary fails.

Cache-aside:
Check cache, then database, then populate cache.

TTL:
Automatic expiration time.

Eviction:
Cache removes keys because memory is full.

Cache stampede:
Many requests rebuild the same missing key.

Hot key:
One key receives excessive traffic.

RBAC:
Controls commands and key access.

Global Datastore:
Asynchronous cross-Region replication.

Data tiering:
Stores hot data in memory and less-active data on local SSD.
```

## One-line memory trick

```text
RDS stores the truth.
ElastiCache stores speed.
TTL controls freshness.
Eviction controls memory.
Replicas improve reads and availability.
Shards improve total capacity.
```

## Lesson 26 outcome

You can now design a caching architecture where:

```text
Repeated database queries
    → Served from cache.

An EC2 instance is replaced
    → User session remains available.

Cache primary fails
    → Replica is promoted.

Cache dataset grows
    → Node or shard capacity is increased.

One cache key expires under heavy load
    → Stampede protection limits database queries.

A Region becomes unavailable
    → Global Datastore supports the recovery design.
```

**Next lesson: Lesson 27 — Amazon Route 53, DNS records, hosted zones, domain delegation, routing policies, health checks, failover, private DNS and production troubleshooting.**

[1]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.html?utm_source=chatgpt.com "What is Amazon ElastiCache? - Amazon ..."
[2]: https://aws.amazon.com/elasticache/?utm_source=chatgpt.com "Amazon ElastiCache"
[3]: https://docs.aws.amazon.com/elasticache/?utm_source=chatgpt.com "Amazon ElastiCache Documentation"
[4]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/extended-support-versions.html?utm_source=chatgpt.com "Versions with ElastiCache Extended Support"
[5]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html?utm_source=chatgpt.com "Choosing between deployment options - Amazon ElastiCache"
[6]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.Components.html?utm_source=chatgpt.com "ElastiCache components and features"
[7]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Replication.Redis-RedisCluster.html?utm_source=chatgpt.com "Valkey and Redis OSS Cluster Mode Disabled vs. Enabled"
[8]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Replication.html?utm_source=chatgpt.com "High availability using replication groups"
[9]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/disaster-recovery-resiliency.html?utm_source=chatgpt.com "Resilience in Amazon ElastiCache"
[10]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/AutoFailover.html?utm_source=chatgpt.com "Minimizing downtime in ElastiCache by using Multi-AZ with ..."
[11]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/multi-az.html?utm_source=chatgpt.com "Minimizing downtime with Multi-AZ - Amazon ElastiCache"
[12]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/redis-memory-management.html?utm_source=chatgpt.com "Managing reserved memory for Valkey and Redis OSS - Amazon ElastiCache"
[13]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/ParameterGroups.Engine.html?utm_source=chatgpt.com "Engine specific parameters - Amazon ElastiCache"
[14]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/set-up.html?utm_source=chatgpt.com "Setting up ElastiCache"
[15]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/encryption.html?utm_source=chatgpt.com "Data security in Amazon ElastiCache"
[16]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth-redis.html?utm_source=chatgpt.com "Authentication and Authorization - Amazon ElastiCache"
[17]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth-iam.html?utm_source=chatgpt.com "Authenticating with IAM - Amazon ElastiCache"
[18]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/backups.html?utm_source=chatgpt.com "Snapshot and restore - Amazon ElastiCache"
[19]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/backups-automatic.html?utm_source=chatgpt.com "Scheduling automatic backups - Amazon ElastiCache"
[20]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/backups-manual.html?utm_source=chatgpt.com "Taking manual backups - Amazon ElastiCache"
[21]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/redis-cluster-vertical-scaling.html?utm_source=chatgpt.com "Online vertical scaling by modifying node type - Amazon ElastiCache"
[22]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/increase-replica-count.html?utm_source=chatgpt.com "Increasing the number of replicas in a shard - Amazon ElastiCache"
[23]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/scaling-redis-cluster-mode-enabled.html?utm_source=chatgpt.com "Scaling Valkey or Redis OSS (Cluster Mode Enabled) clusters - Amazon ElastiCache"
[24]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/AutoScaling-Register-Policy.html?utm_source=chatgpt.com "Registering a Scalable Target - Amazon ElastiCache"
[25]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/data-tiering.html?utm_source=chatgpt.com "Data tiering in ElastiCache - AWS Documentation - Amazon.com"
[26]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Redis-Global-Datastore.html?utm_source=chatgpt.com "Replication across AWS Regions using global datastores"
[27]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/RedisConfiguration.html?utm_source=chatgpt.com "Valkey and Redis OSS configuration and limits - Amazon ElastiCache"
[28]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/CacheMetrics.Redis.html?utm_source=chatgpt.com "Metrics for Valkey and Redis OSS"
[29]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/serverless-metrics-events-redis.html?utm_source=chatgpt.com "Metrics and events for Valkey and Redis OSS serverless caches"
[30]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group?utm_source=chatgpt.com "aws_elasticache_replication_gro..."
