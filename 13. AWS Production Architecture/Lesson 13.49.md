# AWS Masterclass — Phase 3

# Lesson 48: Amazon ElastiCache and MemoryDB Production Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Distinguish Amazon ElastiCache from Amazon MemoryDB.
* Choose between Valkey, Redis OSS and Memcached.
* Decide whether data is disposable cache data or authoritative business data.
* Use ElastiCache Serverless or node-based clusters.
* Understand shards, primary nodes, replicas and cluster mode.
* Configure Multi-AZ and automatic failover.
* Use the correct primary, reader or configuration endpoint.
* Design cache-aside, write-through and invalidation patterns.
* Choose suitable TTLs and prevent cache stampedes.
* Understand eviction policies such as LRU, LFU and `noeviction`.
* Protect RDS, Aurora and external APIs using caching.
* Implement sessions, counters, rate limits and leaderboards.
* Use distributed locks safely.
* Secure connections using TLS, IAM authentication and RBAC.
* Monitor memory, CPU, replication lag, evictions and cache-hit rate.
* Use backups, snapshots and multi-Region architectures.
* Build ElastiCache and MemoryDB using Terraform.

---

# 2. What is Amazon ElastiCache?

Amazon ElastiCache is a managed in-memory data store and caching service.

It supports:

```text
Valkey
Redis OSS
Memcached
```

The service manages infrastructure tasks such as node provisioning, replacement, patching, monitoring, replication and scaling. ([AWS Documentation][1])

Basic architecture:

```text
Application
    |
    v
ElastiCache
    |
    ├── Cached database results
    ├── User sessions
    ├── Counters
    ├── Rate-limit state
    └── Frequently accessed objects
```

The primary purpose of a cache is to serve frequently requested data faster than the original source.

---

# 3. What is Amazon MemoryDB?

Amazon MemoryDB is a durable, Valkey- and Redis OSS-compatible in-memory database.

Unlike a traditional disposable cache, MemoryDB persists writes through a Multi-AZ transactional log and is designed to act as an authoritative primary database for applications requiring ultra-fast access. ([AWS Documentation][2])

```text
Application
    |
    v
MemoryDB
    |
    ├── In-memory primary nodes
    ├── Read replicas
    └── Multi-AZ transactional log
```

## Fundamental distinction

```text
ElastiCache:
Usually accelerates another data source.

MemoryDB:
Can be the primary durable data source.
```

---

# 4. ElastiCache versus MemoryDB

| Requirement                    | ElastiCache                             | MemoryDB                       |
| ------------------------------ | --------------------------------------- | ------------------------------ |
| Main purpose                   | Cache and data acceleration             | Durable in-memory database     |
| Data may be disposable         | Usually yes                             | No                             |
| Durable transaction log        | Optional for eligible Valkey 9 clusters | Core architecture              |
| Typical source of truth        | RDS, DynamoDB, API or another database  | MemoryDB itself                |
| Multi-AZ failover              | Yes with replicas                       | Yes                            |
| Redis/Valkey API compatibility | Yes                                     | Yes                            |
| Backups                        | Supported                               | Supported                      |
| Primary-database use           | Only with deliberate durability design  | Intended use                   |
| Cache-aside pattern            | Excellent fit                           | Possible but often unnecessary |
| Microsecond reads              | Yes                                     | Yes                            |

## Selection rule

```text
Can the data be regenerated?
    → ElastiCache

Must acknowledged data survive failures?
    → MemoryDB or an eligible durability-enabled ElastiCache design

Need a traditional relational source of truth?
    → RDS/Aurora + ElastiCache
```

---

# 5. The changing durability boundary

Historically, ElastiCache was treated almost entirely as disposable cache infrastructure.

As of 2026, eligible **Valkey 9 cluster-mode-enabled** ElastiCache clusters can use a Multi-AZ transactional log.

ElastiCache offers:

```text
Synchronous durable writes:
A write returns only after the transactional log commits it.

Asynchronous durable writes:
The response returns before the log commit.
```

Synchronous durability provides no loss of acknowledged writes during failure, with additional write latency. Asynchronous durability keeps latency closer to ordinary ElastiCache but can lose up to approximately 10 seconds of successful writes during failure. ([AWS Documentation][3])

This means:

```text
ElastiCache without durability:
Treat data as replaceable.

ElastiCache with synchronous durability:
Acknowledged writes are transaction-log protected.

MemoryDB:
Durability is part of its fundamental database architecture.
```

Do not change an application’s source-of-truth design merely because a durability option exists. Recovery, backups, multi-Region behaviour, supported commands and operational guarantees must all meet the business requirement.

---

# 6. Why in-memory systems are fast

Traditional database lookup:

```text
Application
    |
    v
Network
    |
    v
Database engine
    |
    v
Buffer cache or disk
    |
    v
Query processing
```

Cache lookup:

```text
Application
    |
    v
Network
    |
    v
In-memory key lookup
```

Caching removes or reduces:

* SQL parsing.
* Query planning.
* Disk access.
* Joins.
* Repeated computation.
* Calls to expensive external APIs.

The speed improvement is often created by avoiding work, not merely by using faster hardware.

---

# 7. Common ElastiCache use cases

Use ElastiCache for:

* Database-query caching.
* Session storage.
* API response caching.
* Feature-flag caching.
* Rate limiting.
* Counters.
* Leaderboards.
* Real-time statistics.
* Pub/Sub messaging.
* Distributed coordination.
* Geospatial data.
* Frequently accessed configuration.
* Semantic caching for AI applications.

AWS documents semantic caching as a way to reduce generative-AI inference latency and cost by reusing responses for sufficiently similar requests. ([AWS Documentation][4])

---

# 8. Valkey, Redis OSS and Memcached

## Valkey

Valkey is an open-source, Redis-compatible data store supporting rich data structures, replication, clustering, persistence-related capabilities and advanced commands.

For new Redis-compatible AWS workloads, Valkey is generally the preferred engine to evaluate.

## Redis OSS

Use Redis OSS when:

* Existing application compatibility requires it.
* Migration to Valkey has not been validated.
* A specific supported Redis OSS version is required.

AWS notes that features available in Redis OSS 7.2 are available in Valkey 7.2 and later, and supported Redis OSS clusters can be upgraded to Valkey in eligible configurations. ([AWS Documentation][5])

## Memcached

Memcached provides a simpler distributed key-value cache.

Use it when:

* Only basic string/object caching is needed.
* You do not need replication.
* You do not need rich data structures.
* You want simple horizontal cache-node distribution.
* Losing individual cache-node content is acceptable.

---

# 9. Valkey versus Memcached

| Requirement             |                      Valkey/Redis OSS |                    Memcached |
| ----------------------- | ------------------------------------: | ---------------------------: |
| Strings and objects     |                                   Yes |                          Yes |
| Hashes                  |                                   Yes |                           No |
| Lists and queues        |                                   Yes |                           No |
| Sets                    |                                   Yes |                           No |
| Sorted sets             |                                   Yes |                           No |
| Transactions            |                                   Yes |                           No |
| Lua/functions           |            Supported with constraints |                           No |
| Replication             |                                   Yes |                           No |
| Automatic failover      |                                   Yes |                           No |
| Pub/Sub                 |                                   Yes |                           No |
| Cluster sharding        |                                   Yes |     Client-side distribution |
| Backups                 |                                   Yes | Serverless backups supported |
| Authentication/RBAC     |                                   Yes |     Different security model |
| Durable database option | MemoryDB / eligible Valkey durability |                           No |

Use Valkey when application behaviour depends on the data structures—not only when you need a generic object cache.

---

# 10. Common Valkey data structures

## Strings

```text
todo:501:title = "Learn ElastiCache"
```

Use for:

* Serialized JSON.
* Tokens.
* Flags.
* Counters.
* Cached responses.

## Hashes

```text
user:104
├── name = Vivek
├── plan = premium
└── status = active
```

Use for object-like records.

## Lists

```text
queue:notifications
├── item A
├── item B
└── item C
```

Use for simple ordered collections.

## Sets

```text
todo:501:collaborators
├── user-104
├── user-205
└── user-306
```

Use for unique membership.

## Sorted sets

```text
leaderboard
├── user-104 → 970
├── user-205 → 880
└── user-306 → 740
```

Use for:

* Leaderboards.
* Priority ranking.
* Delayed work.
* Time-based indexes.

---

# 11. ElastiCache deployment options

ElastiCache provides two major operational models:

```text
ElastiCache Serverless
Node-based clusters
```

## Serverless

AWS manages:

* Capacity.
* Nodes.
* Shards.
* Scaling.
* Topology changes.

## Node based

You select and manage:

* Node family.
* Node size.
* Number of shards.
* Number of replicas.
* Scaling actions.
* Parameter groups.

ElastiCache Serverless automatically scales vertically and horizontally and exposes a single endpoint. Node-based clusters provide more topology and parameter control but require capacity monitoring and planning. ([AWS Documentation][6])

---

# 12. When to choose ElastiCache Serverless

Choose Serverless when:

* Traffic is unpredictable.
* You do not want to size nodes.
* Rapid growth is expected.
* Workloads are spiky.
* Operational simplicity is important.
* The application supports cluster-aware connections.

ElastiCache Serverless for Valkey and Redis OSS operates using cluster-mode-enabled semantics, so clients must support cluster mode. ([AWS Documentation][6])

Example:

```text
Application
    |
    v
Single serverless endpoint
    |
    v
AWS-managed, dynamically scaled cache topology
```

---

# 13. ElastiCache Serverless capacity model

Serverless Valkey and Redis OSS use:

```text
Data storage
+
ElastiCache Processing Units per second
```

An ECPU represents processing and transferred data for cache requests. Commands using more CPU or transferring more data consume more ECPUs than simple small `GET` and `SET` requests. ([AWS Documentation][7])

This means two commands with the same request count may have very different capacity consumption:

```text
Small GET:
Low ECPU

Large HGETALL:
Higher transferred-data and CPU cost

Complex sorted-set command:
Higher CPU cost
```

Do not capacity-plan Serverless only by requests per second.

---

# 14. Serverless scaling behaviour

Serverless automatically changes capacity, but scaling is not infinitely instantaneous.

AWS documents a base capacity and progressive scaling behaviour for ElastiCache Serverless. Planned large launches may need minimum ECPU or storage limits raised before traffic arrives. ([AWS Documentation][8])

Before a major launch:

```text
Forecast traffic
      |
      v
Estimate ECPU and storage
      |
      v
Raise minimum limits
      |
      v
Load test
      |
      v
Monitor scaling
```

“Serverless” does not remove the need for workload forecasting.

---

# 15. Node-based cluster terminology

```text
Replication group
    |
    ├── Shard 1
    |     ├── Primary
    |     └── Replicas
    |
    ├── Shard 2
    |     ├── Primary
    |     └── Replicas
    |
    └── Shard 3
          ├── Primary
          └── Replicas
```

## Shard

A partition of the key space.

## Primary

Accepts writes for that shard.

## Replica

Asynchronously follows the primary and can serve reads.

## Replication group

The complete collection of shards and replicas.

---

# 16. Cluster mode disabled

Cluster-mode-disabled Valkey or Redis OSS contains:

```text
One shard
```

That shard can have:

```text
One primary
+
Up to five read replicas
```

([AWS Documentation][9])

Architecture:

```text
Primary
├── Replica A
├── Replica B
└── Replica C
```

Advantages:

* Simpler clients.
* One writable primary.
* Easy endpoint model.
* Suitable when the entire data set fits one shard.

Limitation:

```text
Write capacity and memory
are bounded by one primary shard.
```

You can scale the node vertically, but not distribute writes across several primaries.

---

# 17. Cluster mode enabled

Cluster mode enabled divides keys across several shards.

```text
Shard 1:
Hash slots 0–5000

Shard 2:
Hash slots 5001–10000

Shard 3:
Hash slots 10001–16383
```

Each shard has its own primary and optional replicas.

```text
Application
    |
    v
Cluster-aware client
    |
    ├── Shard 1
    ├── Shard 2
    └── Shard 3
```

Cluster mode enables horizontal scaling by adding or removing shards using online resharding while the cluster continues to serve requests. ([AWS Documentation][10])

---

# 18. Cluster-aware clients

A cluster-aware client understands:

* Hash slots.
* Node topology.
* `MOVED` responses.
* `ASK` redirections.
* Topology refresh.
* Failover.
* Resharding.

Example:

```text
Client requests key user:104
        |
        v
Hash slot calculated
        |
        v
Request sent to shard owning slot
```

Using a non-cluster-aware client against a cluster-mode-enabled cache causes connection or redirection failures.

---

# 19. Hash tags

Hash tags place related keys in the same cluster slot.

Keys:

```text
user:{104}:profile
user:{104}:todos
user:{104}:settings
```

Only the content inside braces participates in slot selection:

```text
{104}
```

This is useful when a multi-key operation requires related keys to reside in one shard.

Be careful:

```text
Too many keys using one hash tag
    → Hot shard
```

Hash tags solve locality but can reduce distribution.

---

# 20. Multi-key command limitation

In cluster mode, operations involving several keys normally require the keys to be in the same hash slot.

Potential issue:

```text
MGET user:104 user:205
```

If the keys are on different shards, the command cannot execute as one normal multi-key operation.

Solutions:

* Use hash tags for related keys.
* Split requests per shard.
* Redesign the key model.
* Avoid cross-shard transactions.

Cluster-mode design begins with key-access patterns just as DynamoDB design begins with partition-access patterns.

---

# 21. Primary and replica endpoints

## Cluster mode disabled

Typically exposes:

```text
Primary endpoint:
Writes and strongly current reads

Reader endpoint:
Distributes read connections across replicas
```

## Cluster mode enabled

Typically exposes:

```text
Configuration endpoint:
Cluster-aware topology discovery

Individual node endpoints:
Direct node access where required
```

Applications should use the logical endpoint appropriate for the deployment rather than storing individual node IPs.

---

# 22. Replication

Ordinary ElastiCache Valkey and Redis OSS replication is asynchronous.

```text
Primary
    |
    | Asynchronous replication
    v
Replica
```

During an ordinary failover, a small amount of recent data can be lost if the promoted replica had not received every write. Durability-enabled Valkey 9 clusters restore committed writes through the transactional log instead of relying only on replica state. ([AWS Documentation][11])

Therefore:

```text
Cache data:
Usually acceptable to regenerate.

Authoritative data:
Requires explicit durability guarantees.
```

---

# 23. Multi-AZ automatic failover

Multi-AZ places replicas across Availability Zones.

```text
Availability Zone A
└── Primary

Availability Zone B
└── Replica

Availability Zone C
└── Replica
```

If the primary fails:

```text
Failure detected
      |
      v
Replica promoted
      |
      v
Primary endpoint DNS updated
      |
      v
Application reconnects
```

Multi-AZ requires at least one replica in another Availability Zone. Cluster-mode-enabled deployments enable Multi-AZ when each shard has a suitably placed replica. ([AWS Documentation][11])

---

# 24. Cache failover behaviour

Applications must handle:

* Broken sockets.
* Connection resets.
* DNS changes.
* Replica promotion.
* Temporary command failures.
* Topology changes.
* Retries.

Recommended flow:

```text
Cache request fails
      |
      v
Discard broken connection
      |
      v
Refresh topology or DNS
      |
      v
Reconnect
      |
      v
Retry safe operation
```

Do not retry indefinitely.

If the cache is an optimization, the application should often be able to fall back to the source database.

---

# 25. Cache-aside pattern

Cache-aside is also called lazy loading.

Read flow:

```text
Application requests todo
        |
        v
Check cache
        |
        ├── Hit → Return cached value
        |
        └── Miss
              |
              v
          Read database
              |
              v
          Store in cache
              |
              v
          Return result
```

AWS caching guidance describes cache-aside/lazy loading as a common strategy where data is loaded only when requested. ([AWS Documentation][12])

---

# 26. Cache-aside pseudocode

```javascript
async function getTodo(todoId) {
  const key = `todo:${todoId}`;

  const cached = await cache.get(key);

  if (cached !== null) {
    return JSON.parse(cached);
  }

  const todo = await database.getTodo(todoId);

  if (!todo) {
    return null;
  }

  await cache.set(
    key,
    JSON.stringify(todo),
    { EX: 300 }
  );

  return todo;
}
```

Benefits:

* Only requested data enters the cache.
* Cache failure can fall back to the database.
* Simple operational model.

Risks:

* First request is slow.
* Cached data can become stale.
* A cold cache can overload the database.

---

# 27. Cache invalidation on writes

Update flow:

```text
Application updates database
        |
        v
Database commit succeeds
        |
        v
Delete cache key
```

Pseudocode:

```javascript
async function updateTodo(todoId, changes) {
  const updatedTodo =
    await database.updateTodo(todoId, changes);

  await cache.del(`todo:${todoId}`);

  return updatedTodo;
}
```

This is often called:

```text
Write to database
+
Invalidate cache
```

The next reader repopulates the updated value.

---

# 28. Delete versus update cache

After a database write, you can:

## Delete the cached value

```text
Database update
      |
      v
DEL cache key
```

Advantages:

* Simpler.
* Next read retrieves canonical data.
* Lower dual-write inconsistency risk.

## Update the cached value

```text
Database update
      |
      v
SET cache value
```

Advantages:

* Immediate next read is a cache hit.
* Useful for very hot objects.

Risk:

* Application may write a cache representation differing from committed database state.

Deleting after commit is often safer.

---

# 29. Dual-write failure

Problem:

```text
1. Database update succeeds.
2. Cache invalidation fails.
3. Stale cache entry remains.
```

Mitigations:

* Use TTL as a safety net.
* Retry invalidation.
* Publish invalidation events.
* Use DynamoDB Streams or database CDC.
* Use versioned cache keys.
* Use short TTLs for high-risk data.

Example:

```text
todo:501:v7
```

When database version becomes `8`:

```text
Application requests todo:501:v8
```

The stale version-7 entry is no longer used.

---

# 30. Write-through caching

Write-through updates the cache when the database is written.

```text
Application
    |
    ├── Write database
    └── Write cache
```

AWS caching guidance describes write-through as placing or updating data in the cache whenever the backing database changes. ([AWS Documentation][13])

Benefits:

* Frequently written data is already cached.
* Fewer misses after updates.
* Predictable cache population.

Risks:

* Additional writes.
* Cache may contain data never read.
* Partial dual-write failures.
* More complicated consistency handling.

---

# 31. Write-behind caching

Write-behind means:

```text
Application writes cache
        |
        v
Asynchronous process writes database later
```

This provides low write latency but creates significant durability and consistency risk.

Potential failure:

```text
Cache accepts update
      |
      v
Cache fails before database write
      |
      v
Data lost
```

Use write-behind only with a durable event log or database architecture capable of guaranteeing recovery.

Ordinary disposable ElastiCache should not be used as an unprotected write-behind source of truth.

---

# 32. Read-through caching

With read-through caching, a cache abstraction or library loads missing data automatically.

```text
Application
    |
    v
Caching layer
    |
    ├── Cached → Return
    └── Missing → Call loader → Store → Return
```

ElastiCache itself does not automatically know how to retrieve arbitrary records from your RDS or API backend.

The application or a caching library implements the loader.

---

# 33. TTL

TTL defines how long a key remains valid.

Example:

```text
SET todo:501 value EX 300
```

Meaning:

```text
Expire after 300 seconds
```

TTL protects against:

* Permanently stale values.
* Forgotten cache invalidation.
* Unbounded growth.
* Old sessions.
* Dead rate-limit windows.

---

# 34. Choosing TTL

Use shorter TTLs when:

* Data changes frequently.
* Staleness is dangerous.
* Regeneration is inexpensive.
* Security state is cached.
* Inventory or permissions are involved.

Use longer TTLs when:

* Data changes rarely.
* Regeneration is expensive.
* Slight staleness is acceptable.
* Keys are explicitly invalidated.
* Source systems have strict rate limits.

Example:

```text
Public product description:
1 hour

User permissions:
30–60 seconds

Feature configuration:
1–5 minutes

Short-lived API response:
10–30 seconds

Static reference data:
Several hours
```

TTL should come from business staleness tolerance, not convenience.

---

# 35. TTL jitter

If one million keys receive the same TTL:

```text
Every key expires at 12:00
        |
        v
One million cache misses
        |
        v
Database overload
```

Add random jitter:

```javascript
const baseTtl = 300;
const jitter = Math.floor(Math.random() * 60);

const ttl = baseTtl + jitter;
```

Now expiration occurs between:

```text
300 and 359 seconds
```

This spreads cache repopulation over time.

---

# 36. Cache stampede

A stampede occurs when many requests miss the same hot key simultaneously.

```text
Hot key expires
      |
      v
1,000 requests miss
      |
      v
1,000 database queries
```

The cache was intended to protect the database but briefly amplifies traffic instead.

---

# 37. Stampede prevention

Techniques include:

* TTL jitter.
* Request coalescing.
* Single-flight loading.
* Distributed lock.
* Background refresh.
* Stale-while-revalidate.
* Prewarming.
* Soft and hard expiration times.

Single-flight concept:

```text
First request:
Acquires refresh lock and loads data

Other requests:
Wait briefly or receive stale value
```

---

# 38. Stale-while-revalidate

Store:

```json
{
  "value": { "..." : "..." },
  "refreshAfter": 1785250000,
  "expireAfter": 1785250300
}
```

Flow:

```text
Before refreshAfter:
Return cached value.

After refreshAfter but before expireAfter:
Return stale value and refresh asynchronously.

After expireAfter:
Block and load canonical data.
```

This prevents a hot key from disappearing abruptly while still ensuring eventual refresh.

---

# 39. Negative caching

Negative caching stores “not found” responses briefly.

```text
GET product:999
      |
      v
Database says not found
      |
      v
Cache NOT_FOUND for 15 seconds
```

This protects the source from repeated requests for nonexistent resources.

Keep negative TTL short because the resource may be created shortly afterward.

Do not cache permission-denied results broadly without including user and tenant identity in the cache key.

---

# 40. Cache key design

Good key:

```text
todoapp:production:tenant:38:user:104:todo:501:v2
```

Components:

```text
Application
Environment
Tenant
Entity type
Entity ID
Schema version
```

Benefits:

* Prevents cross-environment collisions.
* Prevents cross-tenant leakage.
* Supports migration.
* Simplifies debugging.
* Enables namespace invalidation.

---

# 41. Cache-key mistakes

Bad:

```text
todo:501
```

when IDs are only unique inside a tenant.

Better:

```text
tenant:38:todo:501
```

Bad:

```text
GET:/todos
```

for a user-specific endpoint.

Better:

```text
tenant:38:user:104:GET:/todos:status=OPEN
```

Every input affecting the response must affect the cache key.

---

# 42. Avoid oversized values

Large cache values cause:

* Higher network latency.
* Higher ECPU consumption in Serverless.
* Longer serialization.
* Memory fragmentation.
* Slow deletion and eviction.
* Client timeouts.
* Increased replication traffic.

Instead of caching one 20-MB result:

```text
Cache several smaller pages
```

Example:

```text
user:104:todos:page:1
user:104:todos:page:2
user:104:todos:page:3
```

---

# 43. Eviction

Eviction occurs when the cache reaches its usable memory limit and the configured policy removes keys.

ElastiCache supports policies including:

```text
volatile-lru
allkeys-lru
volatile-lfu
allkeys-lfu
volatile-random
allkeys-random
volatile-ttl
noeviction
```

The available choices depend on engine and node configuration. The default for many parameter families is `volatile-lru`. ([AWS Documentation][14])

---

# 44. LRU

LRU means:

```text
Least Recently Used
```

## `allkeys-lru`

Evicts the least recently used key from all keys.

Use when:

* Everything is cache data.
* Every key may be discarded.
* Some keys lack TTL.

## `volatile-lru`

Evicts least recently used keys only among keys with an expiry.

Risk:

```text
Keys without TTL cannot be evicted
```

If many permanent keys consume memory, the cache can reject writes even though disposable keys exist elsewhere.

---

# 45. LFU

LFU means:

```text
Least Frequently Used
```

## `allkeys-lfu`

Evicts less frequently accessed keys across the whole key space.

Use when:

* Access frequency matters more than recency.
* A small set of keys remains consistently popular.
* Long-term popularity should influence retention.

Example:

```text
Key A:
Used 5,000 times over one hour

Key B:
Used once 10 seconds ago
```

LRU may prefer B because it was more recent.

LFU may prefer A because it is consistently popular.

---

# 46. `noeviction`

With:

```text
maxmemory-policy = noeviction
```

the system rejects writes when available memory is exhausted rather than deleting keys.

Use when:

* Keys must never be removed automatically.
* The application handles write rejection.
* Memory is monitored very carefully.
* The system is being used for authoritative state.

Risk:

```text
Memory full
    |
    v
Writes receive out-of-memory errors
```

Data-tiering documentation also notes that `noeviction` nodes return out-of-memory errors when they cannot store additional data. ([AWS Documentation][15])

---

# 47. Eviction is not expiration

## Expiration

```text
Key’s TTL ends
    |
    v
Key becomes eligible for deletion
```

## Eviction

```text
Memory pressure
    |
    v
Policy chooses a key to remove
```

A key can be evicted before its TTL expires.

Therefore:

```text
TTL does not guarantee retention.
```

If a value must remain available, a cache is not the only durable copy.

---

# 48. Cache-hit rate

```text
Cache hit rate =
Cache hits / Total cache lookups
```

Example:

```text
Hits:
9,000

Misses:
1,000

Hit rate:
90%
```

A low hit rate may indicate:

* TTL too short.
* Poor key design.
* Cache too small.
* Workload has low reuse.
* Excessive invalidation.
* Random access patterns.
* Cache is being used for unsuitable data.

A high hit rate is not automatically good if stale or unauthorised values are being served.

---

# 49. Database protection

Without cache:

```text
10,000 API requests
        |
        v
10,000 database queries
```

With 95% cache-hit rate:

```text
10,000 API requests
        |
        ├── 9,500 cache hits
        └── 500 database queries
```

Caching can reduce:

* Database CPU.
* Connections.
* Read IOPS.
* Query latency.
* Read-replica requirements.
* External API charges.

But a cache outage can suddenly return all traffic to the database.

The database must survive at least a controlled portion of cache-miss traffic.

---

# 50. Cache failure fallback

```javascript
async function getTodo(todoId) {
  try {
    const cached = await cache.get(`todo:${todoId}`);

    if (cached) {
      return JSON.parse(cached);
    }
  } catch (error) {
    logger.warn("Cache unavailable", {
      todoId,
      message: error.message
    });
  }

  const todo = await database.getTodo(todoId);

  if (!todo) {
    return null;
  }

  try {
    await cache.set(
      `todo:${todoId}`,
      JSON.stringify(todo),
      { EX: 300 }
    );
  } catch (error) {
    logger.warn("Cache write failed", {
      todoId,
      message: error.message
    });
  }

  return todo;
}
```

Cache failure should normally degrade performance, not completely break a database-backed application.

---

# 51. Protecting the database during cache failure

Use:

* Application rate limiting.
* Database connection limits.
* Request queues.
* Circuit breakers.
* Load shedding.
* Retry limits.
* Cache prewarming.
* Gradual traffic restoration.
* Database read replicas.

Avoid:

```text
Cache fails
    |
    v
Every client retries immediately
    |
    v
Database fails
```

This is a cascading failure.

---

# 52. Session storage

Architecture:

```text
User request
    |
    v
Application load balancer
    |
    v
Any ECS task
    |
    v
ElastiCache session store
```

Session key:

```text
session:8fd9a
```

Value:

```json
{
  "userId": "104",
  "tenantId": "38",
  "createdAt": "2026-07-28T01:00:00Z"
}
```

TTL:

```text
30 minutes
```

This removes the need for sticky sessions because any application task can read the same session.

---

# 53. Session security

Do not store:

* Plaintext passwords.
* Long-lived AWS access keys.
* Unnecessary sensitive profile data.
* Full payment data.
* Tokens longer than required.

Use:

* Random high-entropy session IDs.
* TLS.
* Short session TTL.
* Rotation after authentication.
* Explicit logout invalidation.
* Secure browser cookies.
* Tenant-aware key prefixes.
* Appropriate ACLs.

For critical sessions, decide whether session loss should force reauthentication or whether durable session storage is required.

---

# 54. Rate limiting

Simple fixed-window rate limit:

```text
Key:
rate:user:104:202607280100

INCR key

EXPIRE key 60
```

Flow:

```text
Request
   |
   v
Increment counter
   |
   ├── Count <= limit → Allow
   └── Count > limit  → Reject
```

Example:

```text
Maximum:
100 requests per minute
```

Use Lua or an atomic server-side command pattern so increment and expiry cannot be partially applied.

---

# 55. Sliding-window rate limiting

A sorted set can record request timestamps.

```text
rate:user:104
├── request-1 → timestamp
├── request-2 → timestamp
└── request-3 → timestamp
```

Per request:

```text
1. Remove timestamps outside the window.
2. Count remaining entries.
3. Add current request if below limit.
4. Set expiration.
```

Use one atomic Lua script or supported function to prevent race conditions.

---

# 56. Counters

Valkey counters are useful for:

* Page views.
* API usage.
* Active users.
* Inventory reservations with care.
* Retry attempts.
* Rate limits.
* Real-time metrics.

Example:

```text
INCR article:501:views
```

For disposable analytics, ElastiCache is suitable.

For financially or operationally authoritative counters, use:

* MemoryDB.
* DynamoDB atomic counters.
* A relational transaction.
* Durable event aggregation.

---

# 57. Leaderboards

Sorted set:

```text
ZADD leaderboard 950 user-104
ZADD leaderboard 880 user-205
ZADD leaderboard 720 user-306
```

Retrieve top users:

```text
ZREVRANGE leaderboard 0 9 WITHSCORES
```

Use for:

* Gaming.
* Sales rankings.
* Activity scores.
* Priority lists.
* Real-time competitions.

If leaderboard data must survive all failures, use MemoryDB or persist authoritative scoring events elsewhere.

---

# 58. Pub/Sub

Valkey Pub/Sub supports real-time message delivery to connected subscribers.

```text
Publisher
    |
    v
Channel
    |
    ├── Subscriber A
    ├── Subscriber B
    └── Subscriber C
```

Good for:

* Live notifications.
* Cache invalidation.
* Ephemeral presence updates.
* Real-time UI events.

Pub/Sub is not a durable message queue.

If no subscriber is listening:

```text
Message is not stored for later consumption.
```

Use SQS, SNS, EventBridge or streams when durable event delivery is required.

---

# 59. Streams

Valkey streams provide an append-oriented data structure with:

* Message IDs.
* Consumer groups.
* Pending-entry tracking.
* Acknowledgements.
* Multiple consumers.

They are more durable and queue-like than Pub/Sub, but the overall durability guarantee still depends on whether the underlying service is ElastiCache, durability-enabled ElastiCache or MemoryDB.

For critical workflows, compare carefully against SQS and EventBridge before selecting streams.

---

# 60. Distributed locks

Basic lock acquisition:

```text
SET lock:todo:501 unique-owner-id NX PX 10000
```

Meaning:

```text
Create key only if absent.
Expire after 10 seconds.
Store a unique owner token.
```

Release must verify ownership before deleting the key.

Incorrect:

```text
DEL lock:todo:501
```

Correct concept:

```text
Delete the key only when
stored token == caller’s token
```

Use an atomic Lua script for ownership verification and deletion.

---

# 61. Lock-release script

```lua
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
end

return 0
```

This prevents process B from deleting a lock currently owned by process C after process B’s original lock expired.

---

# 62. Lock limitations

A distributed lock can fail logically when:

* Process pauses beyond lock TTL.
* Network delay occurs.
* Failover happens.
* Lock renewal fails.
* Operation lasts longer than expected.
* Clock assumptions are wrong.
* Replica promotion loses an ordinary asynchronous write.
* Client continues after losing ownership.

A lock is a coordination aid—not automatically a correctness guarantee.

---

# 63. Fencing tokens

For strong correctness, use a monotonically increasing fencing token.

```text
Lock owner A:
Token 41

Lock owner B:
Token 42
```

Downstream resource accepts only the highest token seen.

```text
A sends delayed write with 41
    → Reject

B sends write with 42
    → Accept
```

This prevents an old lock holder from modifying protected state after its lease has expired.

Use database conditional updates or another authoritative system to enforce the fencing value.

---

# 64. Redundant lock designs

For extremely critical locking, evaluate:

* Database advisory locks.
* DynamoDB conditional writes.
* Step Functions workflow ownership.
* SQS FIFO message groups.
* MemoryDB durability.
* Application-specific leases with fencing tokens.

Do not implement a complex distributed locking algorithm solely because Valkey exposes `SET NX`.

---

# 65. Data tiering

ElastiCache data tiering uses nodes with both:

```text
DRAM
+
Local NVMe SSD
```

Frequently accessed data remains in memory, while colder data can move to SSD.

Use when:

* The data set is larger than affordable DRAM.
* A meaningful portion of data is cold.
* Some increase in cold-key latency is acceptable.
* Node families supporting tiering fit the workload.

ElastiCache starts evicting according to policy when available DRAM becomes very low; with `noeviction`, writes receive out-of-memory errors. ([AWS Documentation][15])

---

# 66. Scaling node-based clusters

## Vertical scaling

```text
cache.r7g.large
    |
    v
cache.r7g.xlarge
```

Increases:

* CPU.
* Memory.
* Network capability.

## Horizontal read scaling

```text
Add replicas
```

Increases:

* Read capacity.
* Failover targets.

## Horizontal write scaling

```text
Add shards
```

Increases:

* Total memory.
* Total primary write capacity.
* Key-space distribution.

Cluster-mode-enabled clusters support adding and removing shards using online resharding. ([AWS Documentation][10])

---

# 67. Scaling risks

During scaling:

* Topology changes.
* Clients receive redirections.
* Connections reconnect.
* Data moves between shards.
* Latency may change.
* CPU and network use may rise.
* Hot keys may remain hot.

Adding shards does not fix one single extremely hot key because that key still belongs to only one shard.

---

# 68. Read replicas

Replicas improve:

* Read throughput.
* Availability.
* Failover options.

They do not automatically improve:

* Write throughput.
* One hot primary key.
* Cross-shard operations.
* Memory available to one shard.
* Strong read-after-write behaviour.

A replica may return data slightly behind the primary because replication is asynchronous in ordinary ElastiCache deployments. ([AWS Documentation][16])

---

# 69. Client connection management

Avoid creating a new cache connection for every request.

Bad:

```javascript
app.get("/todos/:id", async (request, response) => {
  const client = createClient();

  await client.connect();

  const value = await client.get(
    `todo:${request.params.id}`
  );

  await client.quit();

  response.send(value);
});
```

Better:

```javascript
const cacheClient = createClient({
  url: process.env.CACHE_URL
});

await cacheClient.connect();

app.get("/todos/:id", async (request, response) => {
  const value = await cacheClient.get(
    `todo:${request.params.id}`
  );

  response.send(value);
});
```

Reuse bounded connections.

---

# 70. Connection limits

Individual ElastiCache nodes and Serverless caches support large connection counts, but AWS recommends not operating constantly at the maximum because command processing and response latency degrade as connected-client volume increases. Documentation currently lists up to 65,000 concurrent client connections for a Serverless cache or an individual supported node. ([AWS Documentation][17])

Monitor:

```text
CurrConnections
NewConnections
Connection attempts
Command latency
Engine CPU
```

Use connection pooling and reuse rather than treating the maximum as a performance target.

---

# 71. Timeouts and retries

Configure:

```text
Connection timeout
Command timeout
Socket timeout
Topology refresh
Retry limit
Exponential backoff
Jitter
```

Example:

```text
Connect timeout:
500 ms

Command timeout:
200 ms

Retries:
2

Fallback:
Database
```

A cache should not make an API wait for 30 seconds when the underlying database can answer in 100 milliseconds.

---

# 72. Avoid dangerous commands

Potentially disruptive operations include:

* `KEYS` on large data sets.
* Broad `FLUSHALL`.
* Broad `FLUSHDB`.
* Large blocking Lua scripts.
* Huge `HGETALL`.
* Large multi-key operations.
* Unbounded list or set reads.

Use:

```text
SCAN
HSCAN
SSCAN
ZSCAN
```

for incremental iteration where appropriate.

In node-based cluster-mode-enabled deployments, flush operations need topology-aware behaviour; Serverless abstracts the topology and applies flush commands across the cache. ([AWS Documentation][18])

Production ACLs should deny dangerous administration commands to normal application users.

---

# 73. Slow log

The slow log records commands exceeding a configured execution threshold.

Useful for finding:

* Expensive Lua scripts.
* Large hash retrievals.
* Huge sorted-set operations.
* Blocking commands.
* Oversized payload processing.

ElastiCache parameter groups expose slow-log thresholds and maximum log length. ([AWS Documentation][14])

Do not assume high latency is always caused by network or CPU; one large command can block an event-loop-based engine.

---

# 74. Single-threaded command execution

Valkey and Redis OSS primarily process commands through an event-loop model.

This makes individual operations extremely fast but means one long-running command can delay other clients.

Example:

```text
One huge command:
100 ms

10,000 small commands waiting:
Blocked behind it
```

Optimise:

* Command complexity.
* Value size.
* Lua execution.
* Key cardinality.
* Batch size.

---

# 75. Memory fragmentation

Allocated memory can exceed the logical size of stored data because of allocator behaviour and fragmentation.

Monitor:

```text
BytesUsedForCache
DatabaseMemoryUsagePercentage
MemoryFragmentationRatio
FreeableMemory
SwapUsage
```

Possible mitigations:

* Reduce oversized values.
* Use appropriate data structures.
* Enable or permit active defragmentation where supported.
* Scale node memory.
* Rebuild or replace badly fragmented nodes.
* Avoid frequent huge object resizing.

AWS may perform defragmentation automatically when operationally required on modern Valkey and Redis OSS versions. ([AWS Documentation][14])

---

# 76. Reserved memory

ElastiCache reserves some node memory for:

* Replication buffers.
* Backups.
* Failover.
* Engine overhead.
* Client buffers.
* Snapshot operations.

The complete node memory is not available for application keys.

Backups and synchronization require additional memory for writes occurring during snapshot creation. ([AWS Documentation][19])

Running a cache at nearly 100% usable memory creates failure risk even before eviction begins.

---

# 77. Important ElastiCache metrics

Monitor:

```text
EngineCPUUtilization
CPUUtilization
DatabaseMemoryUsagePercentage
BytesUsedForCache
FreeableMemory
SwapUsage
Evictions
CurrConnections
NewConnections
CacheHits
CacheMisses
ReplicationLag
NetworkBytesIn
NetworkBytesOut
SuccessfulReadRequestLatency
SuccessfulWriteRequestLatency
```

AWS recommends alarms around CPU, memory, swap, evictions, connections, latency and replication behaviour. ([AWS Documentation][20])

---

# 78. CPU metrics

## `EngineCPUUtilization`

Measures cache-engine CPU use.

This is generally the most important metric for command-processing saturation.

## `CPUUtilization`

Measures broader host CPU use.

On larger nodes, one busy engine thread may show high engine CPU while total host CPU appears lower because several vCPUs exist.

Monitor both, but interpret engine CPU carefully.

---

# 79. Eviction monitoring

An increasing `Evictions` metric indicates keys are being removed because of memory pressure and policy.

Ask:

```text
Is eviction expected?
```

For a disposable object cache:

```text
Some eviction may be normal.
```

For sessions or rate-limit state:

```text
Eviction may create correctness or security issues.
```

Possible fixes:

* Increase memory.
* Add shards.
* Shorten TTL.
* Delete unused keys.
* Reduce value size.
* Change eviction policy.
* Separate critical and disposable workloads.

---

# 80. Separate workloads

Avoid one cache for every application concern.

Bad:

```text
One cluster:
Sessions
Database query cache
Rate limits
Pub/Sub
Distributed locks
Leaderboards
```

One high-volume query cache could evict sessions or lock keys.

Better:

```text
Session cache
Query cache
Coordination cache
Analytics cache
```

Separate when workloads have different:

* Eviction requirements.
* TTL policies.
* Security permissions.
* Durability requirements.
* Scaling profiles.
* Maintenance impact.

---

# 81. Replication-lag monitoring

High replication lag can cause:

* Stale reads.
* Greater ordinary failover data loss.
* Delayed replica promotion readiness.
* Inconsistent read behaviour.
* Slow recovery.

Check:

* Primary write rate.
* Replica CPU.
* Network traffic.
* Large values.
* Long commands.
* Replica node size.
* Cross-AZ behaviour.

If replicas are used for reads, define the maximum acceptable stale-data window.

---

# 82. Cache-hit monitoring

Compute:

```text
CacheHitRate =
CacheHits / (CacheHits + CacheMisses)
```

Monitor by application as well as cluster.

Cluster-level metrics may hide:

```text
Service A:
99% hit rate

Service B:
5% hit rate
```

Add application metrics such as:

* Cache lookup duration.
* Cache bypass count.
* Database fallback count.
* Refresh count.
* Negative-cache hit.
* Stale response served.

---

# 83. Security architecture

```text
Application security group
        |
        | TLS connection
        v
Cache security group
        |
        v
Valkey/Redis ACL
```

Security controls include:

* Private VPC placement.
* Security groups.
* TLS.
* At-rest encryption.
* IAM management permissions.
* Valkey/Redis authentication.
* RBAC users and ACLs.
* IAM data-plane authentication.
* CloudTrail for management operations.

ElastiCache supports IAM authentication or AUTH for authentication and RBAC for command-level authorization. ([AWS Documentation][21])

---

# 84. TLS

Enable encryption in transit for production.

```text
Application
    |
    | TLS
    v
ElastiCache
```

AWS raised the minimum supported TLS version to TLS 1.2 for applicable modern ElastiCache Valkey and Redis OSS versions beginning April 28, 2026. ([AWS Documentation][22])

Clients must:

* Support TLS.
* Validate certificates.
* Use the TLS endpoint.
* Reconnect after certificate or topology changes.
* Avoid disabling certificate validation.

---

# 85. At-rest encryption

ElastiCache can encrypt applicable data at rest, including snapshots and supported storage, using AWS-managed or customer-managed KMS keys depending on configuration. ([AWS Documentation][23])

Enable it when creating the replication group or supported cache.

For MemoryDB, at-rest encryption protects the transaction log and snapshot data. ([AWS Documentation][24])

---

# 86. AUTH

Password/token-based authentication requires TLS-enabled ElastiCache.

```text
Client
    |
    | AUTH username password/token
    v
Cache
```

Authentication should be combined with ACL restrictions.

Do not give every application user:

```text
All keys
+
All commands
```

Authentication support through AUTH is available only with in-transit encryption enabled. ([AWS Documentation][25])

---

# 87. RBAC

Create separate cache users:

```text
todo-api
todo-worker
operations-readonly
cache-administrator
```

Example permissions:

```text
todo-api:
Allowed keys:
todoapp:production:*

Allowed commands:
GET SET DEL EXPIRE MGET

Denied:
FLUSHALL CONFIG KEYS
```

RBAC limits the blast radius if one application credential is compromised.

---

# 88. IAM authentication

IAM authentication lets supported Valkey and Redis OSS users connect using short-lived Signature Version 4 authentication tokens instead of long-lived cache passwords.

Requirements include:

* Valkey 7.2 or later, or Redis OSS 7.0 or later.
* TLS enabled.
* ElastiCache user configured for IAM.
* IAM principal permitted to use `elasticache:Connect`.

Tokens are valid for 15 minutes, and IAM-authenticated connections are automatically disconnected after 12 hours unless reauthenticated. ([AWS Documentation][26])

---

# 89. IAM-authenticated client lifecycle

```text
ECS task role
      |
      v
Generate short-lived IAM token
      |
      v
AUTH to cache
      |
      v
Connection established
```

Use a client supporting credential-provider refresh.

Do not generate one token at application startup and assume it remains valid forever.

---

# 90. Private networking

Run caches inside private VPC subnets.

```text
ECS tasks in private subnets
        |
        v
ElastiCache subnet group
        |
        v
Cache nodes in private subnets
```

Security group:

```text
Inbound:
TCP 6379
Source:
Application security group
```

Do not expose cache endpoints directly to the public internet.

---

# 91. Backups and snapshots

ElastiCache supports snapshots for Valkey and Redis OSS caches and selected Serverless engines.

A snapshot can be restored into a new cache or node-based cluster. ([AWS Documentation][27])

```text
Cache
   |
   v
Snapshot
   |
   v
New cache
```

Use snapshots for:

* Migration.
* Pre-upgrade safety.
* Disaster recovery.
* Seeding a new cluster.
* Long-term retention where appropriate.

---

# 92. Cache backups do not replace the source database

If ElastiCache is only a cache:

```text
Canonical data:
RDS/Aurora/DynamoDB

ElastiCache snapshot:
Convenience and faster recovery
```

The source database remains authoritative.

Do not design a disaster-recovery strategy that depends only on a cache snapshot when the backing data lives elsewhere.

---

# 93. Snapshot performance considerations

Creating snapshots can require extra memory because writes continue while the cache data is captured.

AWS recommends ensuring adequate available memory, particularly for node-based clusters under heavy write load. ([AWS Documentation][19])

Schedule automatic snapshots during relatively low write activity where possible.

---

# 94. MemoryDB snapshots

MemoryDB already protects writes with its Multi-AZ transactional log, but snapshots provide point-in-time backup copies for longer-term recovery and migration.

MemoryDB supports automatic and manual snapshots. ([AWS Documentation][28])

```text
Transactional log:
Operational durability

Snapshot:
Recovery checkpoint
```

These solve different problems.

---

# 95. MemoryDB replication

Each MemoryDB shard contains:

```text
Primary
+
Read replicas
+
Multi-AZ transactional log
```

Writes go to the primary and are durably stored. Replicas consume committed changes through the transactional-log architecture and can serve reads. ([AWS Documentation][29])

This enables:

* Fast reads.
* Durable writes.
* Multi-AZ failover.
* Replica-based read scaling.

---

# 96. MemoryDB Multi-Region

MemoryDB Multi-Region provides active-active access:

```text
Mumbai application
    |
    v
Mumbai MemoryDB cluster
    |
    | Asynchronous cross-Region replication
    v
Singapore MemoryDB cluster
    |
    v
Singapore application
```

Applications can read and write locally in each participating Region. Updates normally propagate between Regions asynchronously, commonly in under a second, and conflicts are automatically resolved. ([AWS Documentation][30])

---

# 97. Multi-Region consistency

MemoryDB Multi-Region is:

```text
Locally durable
+
Cross-Region eventually consistent
```

Potential conflict:

```text
Mumbai writes:
status = OPEN

Singapore writes:
status = CLOSED
```

before replication completes.

The application must understand conflict resolution and whether concurrent cross-Region updates to the same key are acceptable.

Multi-Region currently supports up to five participating Regions in eligible configurations. ([AWS Documentation][31])

---

# 98. MemoryDB Multi-Region use cases

Strong fits include:

* Global user profiles.
* Shopping carts.
* Gaming state.
* Session state needing regional resilience.
* Real-time customer state.
* Globally distributed low-latency applications.

Avoid it when:

* Every cross-Region read must be immediately strongly consistent.
* Conflict resolution could violate financial correctness.
* Supported command or data-type limitations are unacceptable.
* Regional topology requirements are unsupported.

---

# 99. ElastiCache versus MemoryDB versus DynamoDB

| Requirement                | ElastiCache                       | MemoryDB                 | DynamoDB                          |
| -------------------------- | --------------------------------- | ------------------------ | --------------------------------- |
| Microsecond reads          | Yes                               | Yes                      | Usually single-digit milliseconds |
| Disposable cache           | Excellent                         | Unnecessary expense      | Not intended                      |
| Durable primary data       | Limited/explicit durability modes | Yes                      | Yes                               |
| Redis/Valkey API           | Yes                               | Yes                      | No                                |
| Rich in-memory structures  | Yes                               | Yes                      | Different model                   |
| Serverless deployment      | Yes                               | Node-based service model | Yes                               |
| Global active-active       | Different service options         | Multi-Region             | Global tables                     |
| Complex atomic structures  | Redis/Valkey commands             | Redis/Valkey commands    | Conditional/transaction APIs      |
| Operational cache patterns | Excellent                         | Possible                 | Not a cache replacement           |

---

# 100. Terraform cache subnet group

```hcl
resource "aws_elasticache_subnet_group" "production" {
  name = "production-cache"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  tags = {
    Environment = "production"
  }
}
```

---

# 101. Terraform cache security group

```hcl
resource "aws_security_group" "cache" {
  name   = "production-todoapp-cache"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Valkey from TodoApp tasks"

    protocol  = "tcp"
    from_port = 6379
    to_port   = 6379

    security_groups = [
      aws_security_group.todo_api.id,
      aws_security_group.todo_worker.id
    ]
  }

  egress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 102. Terraform parameter group

```hcl
resource "aws_elasticache_parameter_group" "valkey" {
  name   = "production-valkey"
  family = "valkey8"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lfu"
  }

  parameter {
    name  = "slowlog-log-slower-than"
    value = "10000"
  }

  parameter {
    name  = "slowlog-max-len"
    value = "256"
  }

  tags = {
    Environment = "production"
  }
}
```

Confirm the parameter-group family against the exact chosen Valkey version.

---

# 103. Terraform cluster-mode-disabled replication group

```hcl
resource "aws_elasticache_replication_group" "sessions" {
  replication_group_id = "production-todoapp-sessions"

  description = "TodoApp production session cache"

  engine         = "valkey"
  engine_version = var.valkey_engine_version

  node_type = "cache.r7g.large"

  port = 6379

  num_cache_clusters = 3

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name = (
    aws_elasticache_subnet_group.production.name
  )

  security_group_ids = [
    aws_security_group.cache.id
  ]

  parameter_group_name = (
    aws_elasticache_parameter_group.valkey.name
  )

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  auth_token = var.cache_auth_token

  snapshot_retention_limit = 7
  snapshot_window          = "18:00-19:00"

  maintenance_window = "sun:19:00-sun:20:00"

  auto_minor_version_upgrade = true

  apply_immediately = false

  tags = {
    Application = "TodoApp"
    Environment = "production"
    Workload    = "sessions"
  }
}
```

Avoid storing `auth_token` directly in plaintext Terraform variables or unprotected state. Prefer IAM authentication or carefully protected secret injection where supported.

---

# 104. Terraform cluster-mode-enabled replication group

```hcl
resource "aws_elasticache_replication_group" "query_cache" {
  replication_group_id = "production-todoapp-query"

  description = "Distributed TodoApp query cache"

  engine         = "valkey"
  engine_version = var.valkey_engine_version

  node_type = "cache.r7g.large"

  port = 6379

  num_node_groups         = 3
  replicas_per_node_group = 1

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name = (
    aws_elasticache_subnet_group.production.name
  )

  security_group_ids = [
    aws_security_group.cache.id
  ]

  parameter_group_name = (
    aws_elasticache_parameter_group.valkey_cluster.name
  )

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 7

  apply_immediately = false

  tags = {
    Application = "TodoApp"
    Environment = "production"
    Workload    = "query-cache"
  }
}
```

---

# 105. Terraform ElastiCache Serverless

```hcl
resource "aws_elasticache_serverless_cache" "todoapp" {
  name        = "production-todoapp"
  description = "TodoApp serverless Valkey cache"

  engine = "valkey"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  security_group_ids = [
    aws_security_group.cache.id
  ]

  daily_snapshot_time      = "18:00"
  snapshot_retention_limit = 7

  cache_usage_limits {
    data_storage {
      maximum = 20
      unit    = "GB"
    }

    ecpu_per_second {
      maximum = 50000
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

Terraform resource fields depend on the installed AWS provider version. Validate the schema before applying.

---

# 106. Terraform MemoryDB subnet group

```hcl
resource "aws_memorydb_subnet_group" "production" {
  name = "production-memorydb"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  tags = {
    Environment = "production"
  }
}
```

---

# 107. Terraform MemoryDB ACL

```hcl
resource "aws_memorydb_user" "todoapp" {
  user_name     = "todoapp"
  access_string = "on ~todoapp:production:* +@read +@write"

  authentication_mode {
    type = "passwords"

    passwords = [
      var.memorydb_password
    ]
  }
}

resource "aws_memorydb_acl" "todoapp" {
  name = "production-todoapp"

  user_names = [
    aws_memorydb_user.todoapp.user_name
  ]
}
```

Store passwords securely and understand that sensitive Terraform values can still appear in state.

---

# 108. Terraform MemoryDB cluster

```hcl
resource "aws_memorydb_parameter_group" "todoapp" {
  name   = "production-todoapp"
  family = "memorydb_valkey7"

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }
}

resource "aws_memorydb_cluster" "todoapp" {
  name = "production-todoapp"

  node_type = "db.r7g.large"

  num_shards             = 2
  num_replicas_per_shard = 1

  acl_name = aws_memorydb_acl.todoapp.name

  subnet_group_name = (
    aws_memorydb_subnet_group.production.name
  )

  security_group_ids = [
    aws_security_group.cache.id
  ]

  parameter_group_name = (
    aws_memorydb_parameter_group.todoapp.name
  )

  tls_enabled = true

  snapshot_retention_limit = 7
  snapshot_window          = "18:00-19:00"

  maintenance_window = "sun:19:00-sun:20:00"

  kms_key_arn = aws_kms_key.memorydb.arn

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

Confirm current engine and parameter family names using the AWS provider and MemoryDB engine-version documentation. MemoryDB manages minor and patch versions through its supported version model. ([AWS Documentation][32])

---

# 109. Application connection example

Node.js with TLS:

```javascript
import { createClient } from "redis";

const client = createClient({
  url: process.env.CACHE_URL,

  socket: {
    tls: true,
    connectTimeout: 1_000,
    reconnectStrategy(retries) {
      if (retries > 5) {
        return new Error("Cache reconnect limit reached");
      }

      return Math.min(
        100 * (2 ** retries) + Math.random() * 100,
        3_000
      );
    }
  }
});

client.on("error", (error) => {
  console.error(JSON.stringify({
    level: "ERROR",
    message: "Cache client error",
    error: error.message
  }));
});

await client.connect();
```

Use the cluster client variant for cluster-mode-enabled node-based clusters where required.

---

# 110. Cache-aside implementation with protection

```javascript
const inflightLoads = new Map();

async function cachedLoad({
  key,
  ttlSeconds,
  loader
}) {
  try {
    const cachedValue = await client.get(key);

    if (cachedValue !== null) {
      return JSON.parse(cachedValue);
    }
  } catch (error) {
    console.warn("Cache read unavailable", {
      key,
      error: error.message
    });
  }

  if (inflightLoads.has(key)) {
    return inflightLoads.get(key);
  }

  const loadPromise = (async () => {
    const value = await loader();

    if (value === null) {
      return null;
    }

    const jitter = Math.floor(
      Math.random() * Math.max(1, ttlSeconds * 0.1)
    );

    try {
      await client.set(
        key,
        JSON.stringify(value),
        {
          EX: ttlSeconds + jitter
        }
      );
    } catch (error) {
      console.warn("Cache write unavailable", {
        key,
        error: error.message
      });
    }

    return value;
  })();

  inflightLoads.set(key, loadPromise);

  try {
    return await loadPromise;
  } finally {
    inflightLoads.delete(key);
  }
}
```

This performs in-process request coalescing. For several application tasks, add distributed coordination only where the increased complexity is justified.

---

# 111. AWS CLI inspection

List replication groups:

```bash
aws elasticache describe-replication-groups \
  --region ap-south-1
```

Inspect one:

```bash
aws elasticache describe-replication-groups \
  --replication-group-id production-todoapp-query \
  --query 'ReplicationGroups[0].{
    Status:Status,
    ClusterEnabled:ClusterEnabled,
    AutomaticFailover:AutomaticFailover,
    MultiAZ:MultiAZ,
    ConfigurationEndpoint:ConfigurationEndpoint,
    NodeGroups:NodeGroups
  }' \
  --region ap-south-1
```

---

# 112. Test using `valkey-cli`

TLS connection:

```bash
valkey-cli \
  --tls \
  --cacert /path/to/aws-ca-bundle.pem \
  -h CACHE_ENDPOINT \
  -p 6379
```

Commands:

```text
PING
SET todo:501 "Learn ElastiCache" EX 300
GET todo:501
TTL todo:501
DEL todo:501
```

AWS documents TLS-capable `valkey-cli` connectivity for encrypted ElastiCache caches. ([AWS Documentation][33])

---

# 113. Triggering a failover test

For a controlled nonproduction replication group, use the supported ElastiCache failover testing operation for a selected node group.

Before testing:

* Confirm replicas are healthy.
* Confirm Multi-AZ.
* Notify stakeholders.
* Monitor application errors.
* Measure recovery.
* Verify DNS and topology refresh.
* Verify cache fallback.

Do not perform an unplanned failover on a production session store.

---

# 114. Troubleshooting connection timeout

Check:

```text
Correct endpoint
Correct port
VPC routing
Application security group
Cache security-group ingress
Network ACL
TLS enabled on both sides
DNS resolution
Client in supported network
Cluster-aware client
```

ElastiCache is a VPC service. The client requires private connectivity through the VPC, peering, Transit Gateway, VPN or another supported private network path.

---

# 115. Troubleshooting authentication errors

Symptoms:

```text
NOAUTH Authentication required
WRONGPASS invalid username-password pair
Authentication token expired
```

Check:

* Correct username.
* Correct ACL.
* AUTH password or IAM token.
* TLS enabled.
* IAM `elasticache:Connect`.
* IAM token not older than 15 minutes.
* Long-running IAM connection reauthenticated before 12 hours.
* Key and command ACL permissions.

IAM authentication requirements and lifetime restrictions are documented by ElastiCache. ([AWS Documentation][26])

---

# 116. Troubleshooting `MOVED`

Example:

```text
MOVED 7365 node.example:6379
```

This means:

```text
The requested key belongs to another shard.
```

Fix:

* Use a cluster-aware client.
* Connect through the configuration endpoint.
* Enable topology refresh.
* Do not manually treat one shard node as the whole cluster.

---

# 117. Troubleshooting high CPU

Check:

* Slow log.
* Large commands.
* Lua scripts.
* `KEYS`.
* Huge collections.
* High connection count.
* Hot key.
* TLS overhead.
* Excessive command rate.
* Serialization size.

Scale only after identifying whether the problem is:

```text
More traffic
or
One expensive command
```

Adding replicas does not reduce write-command CPU on the primary.

---

# 118. Troubleshooting high memory

Check:

```text
BytesUsedForCache
DatabaseMemoryUsagePercentage
Key count
Average value size
TTL coverage
Memory fragmentation
Client buffers
Replication buffers
Pending snapshot
```

Actions:

* Add TTL.
* Delete abandoned namespaces.
* Reduce payload size.
* Change eviction policy.
* Add shards.
* Increase node size.
* Separate workloads.
* Enable data tiering where appropriate.

---

# 119. Troubleshooting evictions

Ask:

1. Is eviction expected?
2. Which policy is active?
3. Do important keys have TTL?
4. Is cache size correct?
5. Is one tenant consuming most memory?
6. Did a deployment increase payload size?
7. Is fragmentation high?
8. Is a snapshot or replica synchronization consuming memory?

If session keys are being evicted from an `allkeys-lru` cache, move sessions to a separate cache or use a policy and capacity model suitable for critical keys.

---

# 120. Troubleshooting low hit rate

Possible causes:

* Cache key includes volatile values.
* TTL is too short.
* Cache is never populated.
* Cache is invalidated too aggressively.
* Query parameters are not normalized.
* Values are evicted.
* Application uses different key versions.
* Each request is unique.
* Cache reads fail silently.
* Cache population has errors.

Example:

```text
/todos?status=OPEN&sort=desc
/todos?sort=desc&status=OPEN
```

Normalize query parameter order so both generate the same key.

---

# 121. Troubleshooting replication lag

Check:

* Primary write throughput.
* Replica size.
* Network throughput.
* Large values.
* CPU saturation.
* Slow commands.
* Resharding or backup activity.
* Availability Zone health.
* Replica connection status.

For ordinary asynchronous replication, increased lag also increases potential stale-read and failover-loss windows. ([AWS Documentation][16])

---

# 122. Troubleshooting OOM errors

Error:

```text
OOM command not allowed when used memory > maxmemory
```

Check:

* `maxmemory-policy`.
* `noeviction`.
* Keys without TTL.
* Memory fragmentation.
* Large client buffers.
* Snapshot memory overhead.
* Hot shard.
* Unbalanced key distribution.

Changing to an eviction policy may restore writes, but only do so when evicting data is semantically safe.

---

# 123. Troubleshooting hot shard

Symptoms:

* One shard has high engine CPU.
* Other shards remain idle.
* One shard has more keys or bytes.
* Command latency affects only selected keys.

Causes:

* Poor key distribution.
* Hash tag overuse.
* One popular key.
* Tenant concentration.
* Sequential or patterned keys with client bug.
* Large collection stored under one key.

Adding shards helps only when data can distribute across them.

One huge key remains on one shard.

---

# 124. Troubleshooting cache stampede

Symptoms:

```text
Cache miss rises
Database CPU rises
Application latency rises
Cache population commands rise
```

Immediate actions:

* Extend TTL for hot keys.
* Enable stale response serving.
* Temporarily prewarm key.
* Rate-limit fallback.
* Coalesce loaders.
* Increase database capacity carefully.

Long-term fix:

* TTL jitter.
* Refresh-ahead.
* Distributed single-flight.
* Better cache namespace.
* Better outage fallback.

---

# 125. TodoApp production architecture

```text
Users
  |
  v
CloudFront
  |
  v
API Gateway / ALB
  |
  v
ECS Fargate Todo API
  |
  ├── ElastiCache query cache
  |
  ├── ElastiCache session cache
  |
  ├── Aurora PostgreSQL
  |
  └── SQS / EventBridge
```

Query flow:

```text
GET /todos/501
      |
      v
Check todo cache
      |
      ├── Hit → Return
      |
      └── Miss
            |
            v
         Aurora
            |
            v
       Cache result
```

---

# 126. Separate TodoApp cache workloads

```text
Session cache:
Cluster mode disabled
Multi-AZ
No mixing with disposable query data
Short session TTL

Query cache:
Cluster mode enabled
Multiple shards
allkeys-lfu
Aggressive eviction acceptable

Rate-limit cache:
Independent namespace or cluster
Atomic scripts
Short TTL
Strong monitoring

Critical workflow state:
MemoryDB or durable database
```

This prevents a large report cache from evicting authentication sessions.

---

# 127. Production readiness checklist

```text
[ ] ElastiCache versus MemoryDB decision is documented
[ ] Source-of-truth system is clearly identified
[ ] Valkey, Redis OSS or Memcached choice is justified
[ ] Serverless versus node-based choice is justified
[ ] Client supports the selected cluster mode
[ ] Shard count is load tested
[ ] At least one replica exists per production shard
[ ] Replicas are placed across Availability Zones
[ ] Multi-AZ is enabled
[ ] Failover has been tested
[ ] Clients refresh DNS and topology
[ ] Connections are reused
[ ] Connection and command timeouts are bounded
[ ] Retries use backoff and jitter
[ ] Cache failure falls back safely
[ ] Database can tolerate controlled cache misses
[ ] Every key includes environment and tenant context
[ ] Cache keys are versioned
[ ] Cache values remain small
[ ] TTL derives from business staleness tolerance
[ ] TTL jitter is applied to high-volume keys
[ ] Stampede protection is implemented
[ ] Negative caching uses short TTLs
[ ] Eviction policy matches workload semantics
[ ] Critical and disposable keys are separated
[ ] Sessions cannot be evicted by query-cache traffic
[ ] TLS is enabled
[ ] Certificate validation is enabled
[ ] At-rest encryption is enabled
[ ] RBAC users are least privilege
[ ] Dangerous commands are denied
[ ] IAM authentication is evaluated
[ ] Security groups reference application groups
[ ] Cache is not publicly accessible
[ ] Snapshots are enabled where useful
[ ] Snapshot restore has been tested
[ ] MemoryDB snapshots are retained appropriately
[ ] Engine CPU alarms exist
[ ] Memory alarms exist
[ ] Eviction alarms exist
[ ] Replication-lag alarms exist
[ ] Connection alarms exist
[ ] Cache-hit rate is measured
[ ] Slow-log review is operationalised
[ ] Hot-key and hot-shard risks are tested
[ ] Distributed locks use owner tokens
[ ] Critical locks use fencing or authoritative conditions
[ ] Multi-Region conflicts are understood
```

---

# 128. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
ElastiCache:
Managed in-memory cache.

MemoryDB:
Durable in-memory database.

Valkey/Redis:
Rich in-memory data structures.

Memcached:
Simple distributed cache.
```

## Solutions Architect Associate

Understand:

```text
Cache-aside
TTL
Eviction
Cluster mode
Shards
Replicas
Multi-AZ
Automatic failover
Sessions
Read scaling
MemoryDB durability
```

## DevOps Engineer Professional

Understand:

```text
Cache-stampede prevention
Hot-key diagnosis
Slow-log analysis
RBAC
IAM authentication
TLS
Automatic failover testing
Online resharding
Serverless ECPUs
Durability-enabled Valkey
Snapshot restoration
Multi-Region MemoryDB
Terraform deployment
```

---

# 129. Interview questions

## Question 1: What is Amazon ElastiCache?

**Answer:**

ElastiCache is a managed in-memory cache and data-store service supporting Valkey, Redis OSS and Memcached.

## Question 2: What is Amazon MemoryDB?

**Answer:**

MemoryDB is a durable Valkey- and Redis OSS-compatible in-memory database that protects writes using a Multi-AZ transactional log.

## Question 3: What is the primary difference between ElastiCache and MemoryDB?

**Answer:**

ElastiCache is primarily used to accelerate another source of truth, while MemoryDB is designed to act as a durable primary database.

## Question 4: What is cache-aside?

**Answer:**

The application checks the cache first. On a miss, it reads the source database, places the result into the cache and returns it.

## Question 5: What is write-through caching?

**Answer:**

The cache is updated whenever the backing database is written.

## Question 6: What is a cache stampede?

**Answer:**

It occurs when many requests miss or expire the same key simultaneously and all query the backing system.

## Question 7: How can you prevent a cache stampede?

**Answer:**

Use TTL jitter, request coalescing, refresh-ahead, stale-while-revalidate, prewarming and controlled distributed locking.

## Question 8: What is the difference between expiration and eviction?

**Answer:**

Expiration occurs when a key’s TTL ends. Eviction occurs when memory pressure causes the cache policy to remove a key.

## Question 9: What is `allkeys-lru`?

**Answer:**

It permits eviction of the least recently used key from the entire key space when memory is full.

## Question 10: What is `noeviction`?

**Answer:**

It prevents automatic key removal and rejects writes when the cache reaches its usable memory limit.

## Question 11: What is cluster mode enabled?

**Answer:**

It shards the key space across several primary nodes, allowing horizontal memory and write scaling.

## Question 12: What is cluster mode disabled?

**Answer:**

It uses one writable shard with optional read replicas.

## Question 13: What is a cluster-aware client?

**Answer:**

It understands hash slots, shard topology, redirections, resharding and failover.

## Question 14: What does Multi-AZ do in ElastiCache?

**Answer:**

It places replicas across Availability Zones and automatically promotes a replica when the primary fails.

## Question 15: Can ordinary ElastiCache replication lose recent writes?

**Answer:**

Yes. Ordinary replication is asynchronous, so recent writes can be lost during failover. Eligible durability-enabled Valkey 9 clusters provide stronger transactional-log options.

## Question 16: What is IAM authentication for ElastiCache?

**Answer:**

It allows supported Valkey and Redis OSS users to authenticate using short-lived IAM-signed tokens instead of long-lived passwords.

## Question 17: Is Valkey Pub/Sub durable?

**Answer:**

No. Subscribers that are disconnected when a message is published do not receive it later.

## Question 18: How should you release a distributed lock?

**Answer:**

Atomically verify that the stored owner token matches the caller’s token before deleting the lock.

## Question 19: What is a fencing token?

**Answer:**

It is a monotonically increasing lock version that lets the protected downstream resource reject operations from stale lock owners.

## Question 20: When should you use MemoryDB instead of ElastiCache?

**Answer:**

Use MemoryDB when the Valkey-compatible data must be durably retained as primary application data rather than regenerated from another system.

---

# 130. Never-forget revision

```text
ElastiCache:
Managed in-memory caching.

MemoryDB:
Durable in-memory primary database.

Valkey:
Redis-compatible in-memory engine.

Memcached:
Simple distributed cache.

Shard:
One partition of the key space.

Primary:
Writable node for a shard.

Replica:
Asynchronous copy used for reads and failover.

Cluster mode disabled:
One shard.

Cluster mode enabled:
Several shards.

Cache-aside:
Load data only after a miss.

Write-through:
Update cache during database writes.

TTL:
Time before expiration.

Eviction:
Memory-pressure key removal.

LRU:
Least recently used.

LFU:
Least frequently used.

Stampede:
Many requests regenerate one expired key.

Jitter:
Random TTL variation.

Negative caching:
Temporarily cache a not-found result.

RBAC:
Command and key-level permissions.

IAM authentication:
Short-lived AWS-signed connection authentication.

Multi-AZ:
Automatic replica failover.

Transactional log:
Durable committed-write record.

Fencing token:
Rejects stale lock owners.
```

## One-line memory trick

```text
Cache only what can be regenerated.
Give every key a purpose and TTL.
Spread shards and replicas.
Expect eviction and failure.
Protect the database from misses.
Use MemoryDB when data must endure.
```

## Lesson 48 outcome

You can now design an architecture where:

```text
Database reads are expensive
    → Cache-aside reduces query load.

A hot key expires
    → Jitter and single-flight prevent a stampede.

Memory becomes full
    → The selected eviction policy removes safe keys.

A cache node fails
    → Multi-AZ promotes a replica.

Write throughput exceeds one node
    → Cluster mode distributes keys across shards.

Application tasks scale rapidly
    → Reused connections and Serverless scaling absorb demand.

Sessions must be shared
    → A dedicated session cache replaces sticky sessions.

A rate limit must be atomic
    → Valkey counters and scripts enforce it.

Coordination requires a lease
    → Owner tokens and fencing prevent stale writers.

Data must survive as primary state
    → MemoryDB or synchronous durable Valkey is evaluated.

Users operate in several Regions
    → MemoryDB Multi-Region provides active-active local access.
```

**Next lesson: Lesson 49 — Amazon OpenSearch Service production architecture: domains, clusters, indexes, shards, replicas, mappings, ingestion, search, observability, security, snapshots and scaling.**

[1]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/SelectEngine.html?utm_source=chatgpt.com "Comparing node-based Valkey, Memcached, and Redis ..."
[2]: https://docs.aws.amazon.com/memorydb/latest/devguide/servicename-feature-overview.html?utm_source=chatgpt.com "Features of MemoryDB"
[3]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Durability.Options.html "Durability options - Amazon ElastiCache"
[4]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/elasticache-use-cases.html?utm_source=chatgpt.com "Common ElastiCache Use Cases and How ..."
[5]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/engine-versions.html?utm_source=chatgpt.com "Engine versions and upgrading in ElastiCache"
[6]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html "Choosing between deployment options - Amazon ElastiCache"
[7]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.corecomponents.html?utm_source=chatgpt.com "How ElastiCache works"
[8]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Scaling-serverless.html?utm_source=chatgpt.com "Scaling ElastiCache Serverless clusters - AWS Documentation"
[9]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Replication.Redis-RedisCluster.html?utm_source=chatgpt.com "Valkey and Redis OSS Cluster Mode Disabled vs. Enabled"
[10]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/scaling-redis-cluster-mode-enabled.html?utm_source=chatgpt.com "Scaling Valkey or Redis OSS (Cluster Mode Enabled) clusters"
[11]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/AutoFailover.html "Minimizing downtime in ElastiCache by using Multi-AZ with Valkey and Redis OSS - Amazon ElastiCache"
[12]: https://docs.aws.amazon.com/whitepapers/latest/database-caching-strategies-using-redis/caching-patterns.html?utm_source=chatgpt.com "Caching patterns - Database Caching Strategies Using Redis"
[13]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Strategies.html?utm_source=chatgpt.com "Caching strategies for Memcached - Amazon ElastiCache"
[14]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/ParameterGroups.Engine.html "Engine specific parameters - Amazon ElastiCache"
[15]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/data-tiering.html?utm_source=chatgpt.com "Data tiering in ElastiCache - AWS Documentation - Amazon.com"
[16]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/ReliabilityPillar.html?utm_source=chatgpt.com "Amazon ElastiCache Well-Architected Lens Reliability Pillar"
[17]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/BestPractices.Clients.Redis.Connections.html?utm_source=chatgpt.com "Large number of connections (Valkey and Redis OSS)"
[18]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/SupportedCommands.html?utm_source=chatgpt.com "Supported Valkey and Redis OSS commands"
[19]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/BestPractices.BGSAVE.html?utm_source=chatgpt.com "Ensuring you have enough memory to make a Valkey or Redis OSS snapshot - Amazon ElastiCache"
[20]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/CacheMetrics.Redis.html?utm_source=chatgpt.com "Metrics for Valkey and Redis OSS"
[21]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth-redis.html?utm_source=chatgpt.com "Authentication and Authorization - Amazon ElastiCache"
[22]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/in-transit-encryption.html?utm_source=chatgpt.com "ElastiCache in-transit encryption (TLS) - Amazon ElastiCache"
[23]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/at-rest-encryption.html?utm_source=chatgpt.com "At-Rest Encryption in ElastiCache - Amazon ElastiCache"
[24]: https://docs.aws.amazon.com/memorydb/latest/devguide/encryption.html?utm_source=chatgpt.com "Data security in MemoryDB - Amazon MemoryDB"
[25]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth.html?utm_source=chatgpt.com "Authenticating with the Valkey and Redis OSS AUTH command - Amazon ElastiCache"
[26]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth-iam.html "Authenticating with IAM - Amazon ElastiCache"
[27]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/backups.html?utm_source=chatgpt.com "Snapshot and restore - Amazon ElastiCache"
[28]: https://docs.aws.amazon.com/memorydb/latest/devguide/snapshots.html?utm_source=chatgpt.com "Snapshot and restore - Amazon MemoryDB"
[29]: https://docs.aws.amazon.com/memorydb/latest/devguide/replication.html?utm_source=chatgpt.com "Understanding MemoryDB replication"
[30]: https://docs.aws.amazon.com/memorydb/latest/devguide/multi-region.html?utm_source=chatgpt.com "MemoryDB Multi-Region - Amazon MemoryDB"
[31]: https://docs.aws.amazon.com/memorydb/latest/devguide/multi-region.prereq.html?utm_source=chatgpt.com "Prerequisites and limitations - Amazon MemoryDB"
[32]: https://docs.aws.amazon.com/memorydb/latest/devguide/engine-versions.html?utm_source=chatgpt.com "Engine versions - Amazon MemoryDB"
[33]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/connect-tls.html?utm_source=chatgpt.com "Connecting to ElastiCache (Valkey) or Amazon ElastiCache for Redis OSS with in-transit encryption using valkey-cli - Amazon ElastiCache"
