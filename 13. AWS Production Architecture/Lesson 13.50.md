# AWS Masterclass — Phase 3

# Lesson 49: Amazon OpenSearch Service Production Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Choose between provisioned OpenSearch domains and OpenSearch Serverless.
* Design production clusters using data and dedicated master nodes.
* Configure Multi-AZ with Standby.
* Understand indexes, documents, fields, mappings and analyzers.
* Select primary shard and replica counts.
* Avoid oversized shards and shard explosions.
* Build full-text, filtered, analytical and vector searches.
* Index data efficiently with the Bulk API.
* Design index templates, aliases, data streams and rollover.
* Move data through hot, warm and cold storage.
* Automate index lifecycle using Index State Management.
* Ingest logs, metrics and traces through OpenSearch Ingestion.
* Implement semantic search and retrieval-augmented generation.
* Secure domains using VPCs, IAM and fine-grained access control.
* Configure encryption, audit logs and least-privilege roles.
* Create and restore automated and manual snapshots.
* Implement cross-cluster replication for disaster recovery.
* Monitor cluster health, JVM memory, storage and thread pools.
* Troubleshoot `403`, `429`, red, yellow and blocked-write incidents.
* Provision OpenSearch using Terraform.

---

# 2. What is Amazon OpenSearch Service?

Amazon OpenSearch Service is a managed search and analytics service based on OpenSearch.

It can be used for:

```text
Application search
Log analytics
Security analytics
Infrastructure observability
Metrics and trace analysis
Business analytics
Vector and semantic search
```

AWS manages much of the underlying cluster infrastructure, including provisioning, hardware replacement, service software updates, snapshots, monitoring integrations and supported scaling operations. ([AWS Documentation][1])

Basic architecture:

```text
Data producers
      |
      v
Ingestion pipeline
      |
      v
Amazon OpenSearch Service
      |
      ├── Indexing
      ├── Full-text search
      ├── Filtering
      ├── Aggregations
      ├── Dashboards
      └── Vector search
```

---

# 3. OpenSearch is not normally your transactional database

OpenSearch is excellent for:

```text
Find all todos containing "AWS"
Filter logs by service and status
Aggregate errors by application
Search product descriptions
Find semantically similar documents
```

It is not normally the authoritative source for:

```text
Bank balances
Order payment state
Inventory transactions
Strongly consistent relational workflows
Foreign-key enforcement
```

Recommended architecture:

```text
Authoritative database
RDS / Aurora / DynamoDB
        |
        | Change event or ingestion
        v
OpenSearch
        |
        v
Search and analytics
```

## Memory trick

```text
Database:
Stores authoritative business state.

OpenSearch:
Makes that state searchable and analyzable.
```

If OpenSearch becomes unavailable, a correctly designed application should not lose the authoritative customer transaction.

---

# 4. Common OpenSearch use cases

## Application search

```text
User searches:
"production AWS monitoring"

OpenSearch returns:
Relevant courses, documents or todos
```

## Log analytics

```text
Application logs
ALB logs
CloudTrail logs
VPC Flow Logs
Container logs
```

## Observability

```text
Logs
Metrics
Traces
Service maps
Error investigations
```

## Security analytics

```text
Authentication failures
Suspicious network traffic
Threat detections
Firewall events
Audit activity
```

## Vector search

```text
Query embedding
      |
      v
Nearest document embeddings
      |
      v
Semantically relevant results
```

OpenSearch supports keyword search, aggregations, log analytics, security analysis and k-nearest-neighbour vector search. ([AWS Documentation][2])

---

# 5. Two main deployment models

Amazon OpenSearch Service provides:

```text
Provisioned OpenSearch domain
OpenSearch Serverless collection
```

## Provisioned domain

You choose and manage:

* Instance families.
* Data-node count.
* Dedicated master nodes.
* Storage type and capacity.
* Availability Zones.
* Shards and replicas.
* Hot, warm and cold tiers.
* Most cluster-level settings.

## OpenSearch Serverless

AWS manages:

* Search and ingestion compute.
* Scaling.
* Sharding.
* Capacity placement.
* Service software.
* OpenSearch-version upgrades.
* Much of index lifecycle and infrastructure tuning.

Serverless separates indexing compute from search compute and stores index data primarily in Amazon S3. Provisioned domains require explicit node and storage sizing. ([AWS Documentation][3])

---

# 6. Provisioned domain versus Serverless

| Requirement                 | Provisioned domain |                         Serverless |
| --------------------------- | -----------------: | ---------------------------------: |
| Choose node types           |                Yes |                                 No |
| Manually size nodes         |                Yes |                                 No |
| Direct shard control        |                Yes |                            Managed |
| UltraWarm and cold tiers    |                Yes | Collection-dependent managed tiers |
| Custom parameter control    |            Greater |                            Limited |
| Automatic compute scaling   |     Limited/manual |                                Yes |
| Dedicated master control    |                Yes |                            Managed |
| Cross-cluster replication   |                Yes |                                 No |
| Manual S3 snapshots         |                Yes |                                 No |
| Automated snapshots         |                Yes |                                Yes |
| Predictable steady workload |         Strong fit |                      Evaluate cost |
| Unpredictable workload      |    More operations |                         Strong fit |
| Full plugin/API flexibility |            Greater |                   Supported subset |

OpenSearch Serverless supports a different subset of APIs and plugins, does not support cross-Region replication, and manages shard count and refresh behaviour internally. ([AWS Documentation][4])

## Selection rule

```text
Need full control, custom topology or hot/warm/cold?
    → Provisioned domain

Need minimum cluster operations and automatic scaling?
    → OpenSearch Serverless

Need cross-cluster replication?
    → Provisioned domain

Need unpredictable log, search or vector workload?
    → Evaluate Serverless
```

---

# 7. Provisioned-domain architecture

```text
Clients and ingestion services
           |
           v
OpenSearch domain endpoint
           |
     ┌─────┴─────┐
     |           |
     v           v
Data nodes   Dedicated master nodes
     |
     ├── Primary shards
     ├── Replica shards
     ├── Search processing
     ├── Indexing processing
     └── Aggregations
```

A production domain can also include:

```text
Dedicated coordinator nodes
UltraWarm nodes
Cold storage
OpenSearch optimized nodes
```

---

# 8. Data nodes

Data nodes perform the primary workload:

* Store index shards.
* Index documents.
* Execute searches.
* Run aggregations.
* Manage segments.
* Serve primary and replica shards.

```text
Data node A
├── Primary shard 0
├── Replica shard 1
└── Primary shard 2
```

```text
Data node B
├── Replica shard 0
├── Primary shard 1
└── Replica shard 2
```

Data-node resource selection affects:

```text
CPU
JVM memory
Filesystem cache
Storage
Network throughput
Indexing throughput
Search throughput
```

---

# 9. Dedicated master nodes

Dedicated master nodes manage cluster-level operations such as:

* Cluster-state updates.
* Node membership.
* Index creation.
* Shard allocation.
* Mapping updates.
* Master election.

They do not normally process application search and indexing traffic.

```text
Dedicated master nodes
├── Master candidate A
├── Master candidate B
└── Master candidate C
```

AWS recommends three dedicated master nodes for production domains and warns against using an even number because cluster leadership depends on maintaining quorum. ([AWS Documentation][5])

## Why three?

```text
Three master nodes
      |
      v
Quorum = 2

One node fails
      |
      v
Two remain
      |
      v
Cluster can elect a master
```

Do not confuse:

```text
Dedicated master node
```

with:

```text
Application master user
```

One manages cluster coordination. The other is a security identity.

---

# 10. Dedicated coordinator nodes

Search requests often require a coordinating node to:

1. Send the query to relevant shards.
2. Receive shard-level results.
3. Merge results.
4. Sort results.
5. Return the final response.

```text
Client
  |
  v
Coordinator
  |
  ├── Shard A
  ├── Shard B
  └── Shard C
  |
  v
Merged response
```

Dedicated coordinator nodes can isolate expensive search coordination and aggregation work from data nodes for eligible domain configurations.

They are most useful when:

* Searches fan out across many shards.
* Aggregations are expensive.
* Responses are large.
* Data nodes are overloaded by coordination work.

They do not store normal index shards.

---

# 11. Multi-AZ with Standby

Multi-AZ with Standby is the recommended production availability model for supported provisioned domains.

It uses:

```text
Three Availability Zones
Three dedicated master nodes
Data-node capacity across all three zones
One zone reserved as standby
```

The standby zone contains a complete data copy but normally does not serve search traffic. If an infrastructure failure occurs, OpenSearch Service can activate the standby capacity without first redistributing all the data. AWS states that this model offers a 99.99% availability SLA and normally activates standby nodes in under one minute. ([AWS Documentation][6])

```text
AZ-A
├── Data nodes serving traffic
└── Dedicated master

AZ-B
├── Data nodes serving traffic
└── Dedicated master

AZ-C
├── Standby data nodes
└── Dedicated master
```

---

# 12. Why standby is valuable

Without reserved standby capacity:

```text
Availability Zone fails
        |
        v
Remaining nodes receive more traffic
        |
        v
Shards begin relocating
        |
        v
CPU, network and storage load increase
```

With standby:

```text
Availability Zone fails
        |
        v
Pre-provisioned standby activates
        |
        v
No large initial shard redistribution
```

Multi-AZ without Standby remains available, but AWS recommends Standby for critical workloads because ordinary Multi-AZ recovery can increase load while shards and nodes are replaced. ([AWS Documentation][6])

---

# 13. OpenSearch data model

The hierarchy is:

```text
Domain or collection
      |
      v
Index
      |
      v
Document
      |
      v
Field
```

Example:

```text
Index:
todos

Document:
todo-501

Fields:
title
status
userId
createdAt
```

Document:

```json
{
  "todoId": "501",
  "userId": "104",
  "title": "Learn Amazon OpenSearch",
  "status": "OPEN",
  "createdAt": "2026-07-30T04:45:00Z"
}
```

---

# 14. What is an index?

An OpenSearch index is a logical collection of related documents.

Examples:

```text
todos
products
application-logs-2026.07.30
security-events-2026.07
```

An index has:

* Mappings.
* Settings.
* Primary shards.
* Replica shards.
* Aliases.
* Lifecycle policies.
* Stored documents.

An OpenSearch index is not exactly the same thing as a relational database index.

```text
Relational index:
Auxiliary access structure on a table.

OpenSearch index:
Main searchable container for documents and inverted indexes.
```

---

# 15. Inverted index mental model

Documents:

```text
Document 1:
"learn aws monitoring"

Document 2:
"learn terraform"

Document 3:
"aws production"
```

Inverted index:

```text
learn
├── Document 1
└── Document 2

aws
├── Document 1
└── Document 3

monitoring
└── Document 1
```

Search:

```text
aws
```

OpenSearch reads the term’s document list instead of scanning every complete document.

This is a major reason full-text search is fast.

---

# 16. `text` versus `keyword`

## `text`

Used for analyzed full-text content.

```json
"title": {
  "type": "text"
}
```

Example value:

```text
Learn AWS Production Architecture
```

It can be analyzed into terms such as:

```text
learn
aws
production
architecture
```

## `keyword`

Used for exact values.

```json
"status": {
  "type": "keyword"
}
```

Suitable for:

* Exact matching.
* Filtering.
* Sorting.
* Aggregations.
* IDs.
* Status values.
* Hostnames.
* Regions.

A `keyword` field is not analyzed and supports exact, case-sensitive matching by default; use `text` for full-text analysis. ([OpenSearch Documentation][7])

---

# 17. Multi-fields

A string may need both full-text and exact behaviour.

```json
"title": {
  "type": "text",
  "fields": {
    "keyword": {
      "type": "keyword",
      "ignore_above": 256
    }
  }
}
```

Usage:

```text
title:
Full-text search

title.keyword:
Exact filtering, sorting and aggregation
```

Example:

```json
{
  "query": {
    "match": {
      "title": "AWS production"
    }
  }
}
```

Aggregation:

```json
{
  "aggs": {
    "titles": {
      "terms": {
        "field": "title.keyword"
      }
    }
  }
}
```

---

# 18. Mappings

A mapping defines how fields are stored and indexed.

Example:

```json
PUT todos-v1
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "todoId": {
        "type": "keyword"
      },
      "userId": {
        "type": "keyword"
      },
      "title": {
        "type": "text",
        "fields": {
          "keyword": {
            "type": "keyword"
          }
        }
      },
      "status": {
        "type": "keyword"
      },
      "createdAt": {
        "type": "date"
      },
      "priority": {
        "type": "integer"
      }
    }
  }
}
```

Index templates can apply predefined settings, mappings and aliases whenever new indexes match a pattern. ([OpenSearch Documentation][8])

---

# 19. Dynamic mapping

Dynamic mapping allows OpenSearch to infer fields automatically.

Document:

```json
{
  "response_time": 184
}
```

OpenSearch may infer:

```text
response_time:
long
```

Another document:

```json
{
  "response_time": "unknown"
}
```

Now the field conflicts with its existing numeric mapping.

For controlled production schemas, use:

```json
"dynamic": "strict"
```

or carefully designed dynamic templates. OpenSearch supports configurable dynamic-mapping behaviour for newly detected fields. ([OpenSearch Documentation][9])

---

# 20. Mapping explosion

Mapping explosion occurs when an index accumulates an excessive number of unique fields.

Problematic log input:

```json
{
  "labels": {
    "request_93f8": "true",
    "request_a621": "true",
    "request_c013": "true"
  }
}
```

Each dynamic key can become a new mapped field:

```text
labels.request_93f8
labels.request_a621
labels.request_c013
```

Consequences:

* Large cluster state.
* High dedicated-master memory.
* Slow mapping updates.
* Indexing failures.
* Search instability.
* Difficult migrations.

Use fixed schemas, flattened representations where appropriate and restrictive mappings. OpenSearch recommends reviewing dynamic mappings and reindexing into more controlled mappings when field counts grow excessively. ([OpenSearch Documentation][10])

---

# 21. Analyzers

Analyzers control how text becomes searchable terms.

An analyzer commonly includes:

```text
Character filters
Tokenizer
Token filters
```

Example:

```text
Input:
"Production-Ready AWS"

Lowercase:
"production-ready aws"

Tokenization:
production
ready
aws
```

Analyzer choice affects:

* Search relevance.
* Case handling.
* Stop words.
* Stemming.
* Language behaviour.
* Autocomplete.
* Synonyms.

Index-time and query-time analysis should be compatible.

---

# 22. Near-real-time search

Indexing a document and searching it are separate stages.

```text
Document indexed
      |
      v
Translog and memory buffers
      |
      v
Index refresh
      |
      v
Document becomes searchable
```

The Refresh API makes indexing operations since the previous refresh visible to search. This means OpenSearch is near real time rather than immediately search-consistent after every write. ([OpenSearch Documentation][11])

Do not assume:

```text
HTTP 201 from indexing
    =
Immediate visibility in search
```

For read-after-write confirmation, either wait for a suitable refresh policy or read from the authoritative database.

---

# 23. Indexing path

Conceptual indexing flow:

```text
Client
  |
  v
Coordinating node
  |
  v
Primary shard
  |
  ├── Validate mapping
  ├── Index document
  ├── Write transaction log
  └── Replicate to replicas
  |
  v
Acknowledge request
```

Later:

```text
Refresh
   |
   v
New searchable segment
```

Over time, small segments are merged into larger segments.

Frequent forced refreshes create more small segments and can reduce indexing efficiency.

---

# 24. Bulk indexing

The Bulk API combines many document operations into one request.

```text
One-document requests:
1,000 network round trips

Bulk request:
One or several larger round trips
```

The Bulk API can index, update and delete several documents in one request and significantly reduce transport overhead. ([OpenSearch Documentation][12])

Example:

```json
POST _bulk
{"index":{"_index":"todos-v1","_id":"501"}}
{"todoId":"501","title":"Learn OpenSearch","status":"OPEN"}
{"index":{"_index":"todos-v1","_id":"502"}}
{"todoId":"502","title":"Build production search","status":"OPEN"}
```

The request body must end with a newline.

---

# 25. Bulk indexing production guidance

Do not choose one enormous bulk request.

Use batches that are:

```text
Large enough:
Reduce request overhead

Small enough:
Avoid timeouts, memory spikes and large retries
```

Production approach:

```text
Start with moderate batch sizes
      |
      v
Measure indexing throughput
      |
      v
Measure rejected writes
      |
      v
Increase gradually
```

When one bulk response contains partial failures, retry only the failed items.

Do not resend every successful item automatically.

---

# 26. Refresh interval during large ingestion

During a large initial import:

```text
Disable or increase refresh frequency
        |
        v
Bulk index data
        |
        v
Restore normal refresh behaviour
        |
        v
Refresh index
```

Also consider temporarily reducing replica count for a controlled rebuild, then restoring replicas before production use.

Do not make these changes during normal production traffic without understanding durability and availability impact.

---

# 27. Shards

An index is divided into primary shards.

```text
todos-v1
├── Primary shard 0
├── Primary shard 1
└── Primary shard 2
```

Each shard is an independent search and indexing unit.

Sharding allows:

* Distribution across nodes.
* Parallel search.
* Horizontal storage scaling.
* Parallel indexing.
* Replica placement.

---

# 28. Primary and replica shards

Example:

```text
Primary shards:
P0 P1 P2

One replica each:
R0 R1 R2
```

Placement:

```text
Node A:
P0 R1

Node B:
P1 R2

Node C:
P2 R0
```

A primary shard and its replica should not be on the same data node.

## Primary shard

* Accepts initial writes for its shard.
* Owns part of the index data.

## Replica shard

* Copies a primary shard.
* Provides search capacity.
* Provides availability if the primary becomes unavailable.

---

# 29. Replicas do not increase indexing capacity

A write to a primary must also be replicated.

```text
Write
  |
  v
Primary shard
  |
  v
Replica shard
```

Adding replicas:

```text
Can increase:
Search capacity
Availability

Can increase:
Write work and storage consumption
```

For greater indexing throughput, consider:

* Additional primary shards.
* More or larger data nodes.
* Better bulk batching.
* Reduced refresh overhead.
* Appropriate storage and instance families.

---

# 30. Choosing primary-shard count

Primary-shard count is one of the most important design decisions.

AWS provides a general planning formula:

```text
(Source data + growth allowance)
× indexing overhead
÷ target shard size
=
Approximate primary shard count
```

AWS recommends roughly `10–30 GiB` shards for search-latency-sensitive workloads and `30–50 GiB` shards for write-heavy workloads such as log analytics. Primary-shard count is difficult to change after index creation, so it should be planned before ingestion. ([AWS Documentation][13])

Example:

```text
Expected source data:
600 GiB

Growth and overhead:
20%

Target shard size:
40 GiB

Calculation:
600 × 1.2 ÷ 40
= 18 primary shards
```

This is an initial estimate. Load testing remains necessary.

---

# 31. Oversharding

Oversharding means creating too many small shards.

Example:

```text
1,000 indexes
×
5 primary shards
×
1 replica
=
10,000 total shards
```

Every shard consumes:

* Heap memory.
* Cluster-state metadata.
* File handles.
* CPU.
* Search coordination.
* Recovery resources.

AWS recommends alerting when total active shards approach `25 × JVM heap GiB × number of data nodes`. ([AWS Documentation][14])

---

# 32. Undersharding

Undersharding means using too few large shards.

Consequences:

* One shard becomes a bottleneck.
* Recovery takes longer.
* Relocation moves large amounts of data.
* Parallelism is limited.
* One node may own too much of the index.
* Scaling may not distribute load effectively.

Bad extremes:

```text
500 MB shard:
Too small

500 GB shard:
Often too large
```

The correct size depends on document size, query patterns, storage and recovery requirements.

---

# 33. Hot shards

A hot shard receives disproportionate traffic.

Causes:

* One tenant has much more data.
* One time period receives all writes.
* Custom routing concentrates keys.
* One shard contains a hot category.
* Poor document-ID distribution.
* One large aggregation targets one index segment.

Symptoms:

```text
One node CPU high
Other nodes idle
One shard indexing slow
One shard search latency high
```

Adding data nodes may not fix the problem if the hot shard cannot split across them.

Possible fixes:

* Reindex with more primary shards.
* Improve routing.
* Separate large tenants.
* Use time-based indexes.
* Split large indexes.
* Avoid one custom routing value.

---

# 34. Cluster health states

## Green

```text
All primary shards assigned
All replica shards assigned
```

## Yellow

```text
All primary shards assigned
One or more replica shards unassigned
```

Search and indexing may continue, but redundancy is reduced.

## Red

```text
One or more primary shards unassigned
```

Some data is unavailable.

AWS recommends immediate alarms for red status and sustained alarms for yellow status. ([AWS Documentation][14])

---

# 35. Why a single-node cluster stays yellow

Suppose an index has:

```text
1 primary
1 replica
```

but the cluster has only:

```text
1 data node
```

OpenSearch cannot place a primary and its replica on the same node.

Result:

```text
Primary assigned
Replica unassigned
Cluster yellow
```

Solutions:

* Add another node.
* Set replicas to zero for development.
* Use a production Multi-AZ design.

Do not remove replicas from production merely to turn the dashboard green.

---

# 36. Search execution

Search flow:

```text
Client query
      |
      v
Coordinating node
      |
      v
Relevant primary or replica shards
      |
      v
Each shard returns local matches
      |
      v
Coordinator merges and ranks
      |
      v
Final response
```

A search can use either primary or replica shard copies, allowing replicas to increase search capacity. ([AWS Documentation][15])

A query targeting 100 shards creates much more coordination work than a query targeting three shards.

---

# 37. Query and filter context

## Query context

Answers:

```text
How well does this document match?
```

Example:

```json
{
  "match": {
    "title": "AWS monitoring"
  }
}
```

Results receive relevance scores.

## Filter context

Answers:

```text
Does this document meet the condition?
```

Example:

```json
{
  "term": {
    "status": "OPEN"
  }
}
```

Filters are suitable for:

* Exact status.
* Tenant ID.
* Date ranges.
* Environment.
* Region.
* Boolean flags.

---

# 38. Boolean query example

```json
GET todos-read/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "title": "AWS production"
          }
        }
      ],
      "filter": [
        {
          "term": {
            "tenantId": "tenant-38"
          }
        },
        {
          "term": {
            "status": "OPEN"
          }
        },
        {
          "range": {
            "createdAt": {
              "gte": "now-30d"
            }
          }
        }
      ]
    }
  }
}
```

Always include tenant authorization constraints in the search design.

Do not retrieve another tenant’s documents and filter them only inside application code.

---

# 39. Aggregations

Aggregations answer analytical questions.

Example:

```text
How many errors occurred per service?
What is p95 response time?
How many todos exist per status?
Which countries generated the most requests?
```

Example:

```json
GET todos-read/_search
{
  "size": 0,
  "aggs": {
    "todos_by_status": {
      "terms": {
        "field": "status"
      }
    }
  }
}
```

Aggregations can be CPU- and memory-intensive, especially across:

* Many shards.
* High-cardinality fields.
* Large date ranges.
* Nested structures.
* Large result buckets.

Use `keyword`, numeric and date fields with appropriate `doc_values` for aggregation workloads.

---

# 40. Deep pagination

Simple pagination:

```json
{
  "from": 0,
  "size": 20
}
```

becomes expensive for deep pages:

```json
{
  "from": 100000,
  "size": 20
}
```

Each shard may need to collect and sort all preceding results before the coordinator discards most of them.

For deep pagination, use:

```text
Point in Time
+
search_after
```

OpenSearch recommends PIT with `search_after` for consistent deep pagination rather than large `from` and `size` values. ([OpenSearch Documentation][16])

---

# 41. Index aliases

An alias is a stable logical name pointing to one or more indexes.

```text
todos-read
      |
      v
todos-v1
```

Create a new index:

```text
todos-v2
```

Reindex data:

```text
todos-v1
    |
    v
todos-v2
```

Atomically switch alias:

```text
todos-read
      |
      v
todos-v2
```

Aliases let applications reindex or change mappings without changing the application endpoint. ([OpenSearch Documentation][17])

---

# 42. Zero-downtime mapping migration

Suppose `priority` was incorrectly mapped as `text`.

Desired type:

```text
integer
```

Workflow:

```text
1. Create todos-v2 with correct mapping.

2. Copy or reindex documents from todos-v1.

3. Validate counts and search behaviour.

4. Pause or dual-process writes if necessary.

5. Apply final incremental changes.

6. Atomically move todos-read alias.

7. Monitor.

8. Retain todos-v1 temporarily for rollback.
```

Do not delete the previous index immediately after switching.

---

# 43. Index templates

A template automatically applies to new matching indexes.

```json
PUT _index_template/todo-logs-template
{
  "index_patterns": [
    "todo-logs-*"
  ],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1
    },
    "mappings": {
      "dynamic": "strict",
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "service": {
          "type": "keyword"
        },
        "message": {
          "type": "text"
        },
        "statusCode": {
          "type": "integer"
        }
      }
    }
  }
}
```

Index templates ensure consistent mappings, shard settings and aliases across automatically created indexes. ([OpenSearch Documentation][18])

---

# 44. Time-based indexes

Logs are commonly divided by time:

```text
application-logs-2026.07.28
application-logs-2026.07.29
application-logs-2026.07.30
```

Benefits:

* Delete old data by removing whole indexes.
* Move old indexes to cheaper storage.
* Limit searches to relevant periods.
* Simplify rollover.
* Reduce very large monolithic indexes.

Do not create tiny hourly indexes when daily or size-based rollover would produce healthier shard sizes.

---

# 45. Data streams

Data streams simplify append-oriented time-series indexing.

```text
todo-logs
    |
    ├── .ds-todo-logs-000001
    ├── .ds-todo-logs-000002
    └── .ds-todo-logs-000003
```

The data stream provides one stable name, while OpenSearch manages backing indexes and rollover.

Data streams are designed primarily for append-only timestamped data and use index templates to define backing-index mappings and settings. ([OpenSearch Documentation][19])

Good for:

* Logs.
* Metrics.
* Traces.
* Security events.
* Time-series telemetry.

---

# 46. Rollover

Rollover creates a new write index when conditions are met.

Example conditions:

```text
Index age:
1 day

Primary storage size:
40 GiB

Document count:
50 million
```

```text
todo-logs-000001
        |
        | Rollover
        v
todo-logs-000002 becomes write index
```

Rollover can target an index alias or data stream and can trigger according to configured conditions. ([OpenSearch Documentation][20])

Size-based rollover is often healthier than blindly creating one index every hour or day.

---

# 47. Index State Management

Index State Management automates actions across an index lifecycle.

Example:

```text
Hot
  |
  | After 10 days
  v
Warm
  |
  | At 90 days
  v
Cold
  |
  | At 365 days
  v
Delete
```

ISM can automate transitions based on:

* Index age.
* Size.
* Document count.
* Rollover conditions.
* State actions.
* Notifications.

AWS provides ISM examples moving indexes from hot to UltraWarm, then cold storage and finally deletion. ([AWS Documentation][21])

---

# 48. Hot storage

Hot storage is used for actively indexed and frequently searched data.

Characteristics:

* Data nodes.
* EBS or supported instance storage.
* Lowest normal query latency.
* Supports writes and updates.
* Highest relative storage cost.

Good for:

```text
Current logs
Recent metrics
Application search
Frequently updated products
Active vector indexes
```

---

# 49. UltraWarm storage

UltraWarm uses S3-backed storage with warm nodes providing query compute and caching.

Use for:

* Older log data.
* Read-only historical indexes.
* Data searched less frequently.
* Reducing hot-storage cost.

Indexes moved to UltraWarm are read-only. Storage reporting differs from hot storage because primary data is stored in S3 and the service manages warm access. ([AWS Documentation][22])

```text
Hot:
Recent 14 days

UltraWarm:
Day 15 through day 90
```

---

# 50. Cold storage

Cold storage is S3-backed storage for infrequently accessed indexes.

```text
Hot
  |
  v
UltraWarm
  |
  v
Cold
```

Cold indexes are detached from active compute and must be attached before searching.

Use for:

* Compliance retention.
* Historical investigations.
* Rare incident analysis.
* Long-duration security logs.

Cold storage avoids normal hot-storage replica and node overhead, but retrieval is slower and operationally different. ([AWS Documentation][23])

---

# 51. OpenSearch optimized instances

OpenSearch optimized families provide an alternative architecture for high-ingestion and large-data workloads.

For supported optimized families, local EBS or NVMe storage serves as active storage while segment data is synchronously copied to Amazon S3 for durability and recovery. ([AWS Documentation][24])

Evaluate these families when:

* Log ingestion is heavy.
* Storage volume is large.
* Fast recovery is important.
* The supported workload and feature constraints fit.

Do not assume the newest family is automatically cheaper for every search workload.

---

# 52. OpenSearch Serverless architecture

```text
Data ingestion
      |
      v
Indexing OCUs
      |
      v
Amazon S3 index storage
      |
      v
Search OCUs
      |
      v
Queries and aggregations
```

Search and indexing compute scale independently.

An OpenSearch Compute Unit contains memory, CPU and data-transfer capacity; Serverless adds or removes search and indexing OCUs based on demand and configured limits. ([AWS Documentation][25])

---

# 53. Serverless collection types

OpenSearch Serverless supports three main collection types:

```text
Search
Time series
Vector search
```

## Search

For:

* Application search.
* Content discovery.
* Document repositories.
* E-commerce search.

## Time series

For:

* Logs.
* Metrics.
* Operational analytics.
* Security telemetry.

## Vector search

For:

* Embeddings.
* Semantic search.
* Recommendations.
* RAG.
* Similarity retrieval.

Collection type cannot be changed after creation. Serverless manages shard count and refresh behaviour, and current feature support differs by collection generation and type. ([AWS Documentation][25])

---

# 54. Serverless considerations

OpenSearch Serverless reduces cluster management but does not eliminate design requirements.

You still must design:

* Mappings.
* Document structure.
* Access policies.
* Network policies.
* Encryption policies.
* Queries.
* Lifecycle policies.
* OCU maximums.
* Cost controls.
* Ingestion retry behaviour.

Important current limitations include no cross-Region replication, no manual snapshots and managed shard and refresh settings. Search and time-series collection refresh is approximately ten seconds. ([AWS Documentation][25])

---

# 55. OpenSearch Ingestion

Amazon OpenSearch Ingestion is a managed serverless ingestion service based on Data Prepper.

It can:

* Receive data.
* Buffer and process events.
* Transform records.
* Enrich records.
* Route data.
* Write to provisioned domains.
* Write to Serverless collections.

OpenSearch Ingestion automatically manages the underlying pipeline infrastructure and can ingest logs, metrics and trace data without operating Logstash or similar collector clusters. ([AWS Documentation][26])

Architecture:

```text
Applications / S3 / Kinesis / Kafka
              |
              v
OpenSearch Ingestion
              |
              ├── Parse
              ├── Filter
              ├── Enrich
              ├── Transform
              └── Route
              |
              v
OpenSearch
```

---

# 56. Buffering ingestion

Avoid connecting every producer directly to OpenSearch.

Better:

```text
Applications
    |
    v
Kinesis / SQS / Kafka / Firehose
    |
    v
Ingestion workers or OSI
    |
    v
OpenSearch
```

Benefits:

* Absorbs traffic spikes.
* Provides retry capability.
* Reduces producer coupling.
* Allows controlled batching.
* Protects the domain during maintenance.
* Enables dead-letter handling.

If OpenSearch rejects writes, producers should not retry immediately without limits.

---

# 57. Log ingestion architecture

```text
ECS application
      |
      v
CloudWatch Logs / OpenTelemetry
      |
      v
OpenSearch Ingestion
      |
      v
Time-series indexes
      |
      v
OpenSearch Dashboards
```

Record example:

```json
{
  "@timestamp": "2026-07-30T04:45:00Z",
  "service": "todo-api",
  "environment": "production",
  "traceId": "4ab1...",
  "level": "ERROR",
  "message": "Database timeout",
  "durationMs": 5031
}
```

Use structured logs. Parsing arbitrary multiline plaintext at query time is slower and less reliable.

---

# 58. Vector search

Vector search stores high-dimensional embeddings.

Example:

```json
{
  "documentId": "aws-lesson-49",
  "content": "Amazon OpenSearch production architecture",
  "embedding": [
    0.013,
    -0.218,
    0.057
  ]
}
```

Query:

```text
"How should I size search shards?"
```

is converted into an embedding.

OpenSearch compares the query vector with document vectors and returns nearest neighbours using supported distance methods such as cosine or Euclidean distance. ([AWS Documentation][2])

---

# 59. Vector index example

```json
PUT aws-lessons-vectors
{
  "settings": {
    "index": {
      "knn": true
    }
  },
  "mappings": {
    "properties": {
      "documentId": {
        "type": "keyword"
      },
      "content": {
        "type": "text"
      },
      "embedding": {
        "type": "knn_vector",
        "dimension": 1024
      }
    }
  }
}
```

The vector dimension must match the embedding model output.

Do not change models without planning how existing vectors will be regenerated and reindexed.

---

# 60. Retrieval-augmented generation

```text
User question
      |
      v
Embedding model
      |
      v
Query vector
      |
      v
OpenSearch vector search
      |
      v
Relevant document chunks
      |
      v
Large language model
      |
      v
Grounded answer
```

Production RAG considerations:

* Chunk size.
* Metadata filtering.
* Tenant isolation.
* Embedding model version.
* Vector dimension.
* Hybrid keyword and vector search.
* Relevance evaluation.
* Access control.
* Source citations.
* Reindexing after model changes.

OpenSearch supports semantic search through k-NN and neural-search workflows. ([AWS Documentation][27])

---

# 61. Vector ingestion

OpenSearch Vector ingestion can load vector documents from S3 into provisioned domains or Serverless collections.

It uses OpenSearch Ingestion underneath and can manage parallel processing and indexing capacity, including supported GPU-accelerated indexing options. ([AWS Documentation][28])

```text
Documents and vectors in S3
           |
           v
Vector ingestion
           |
           v
OpenSearch vector index
```

This is useful for large initial vector imports.

---

# 62. Security layers

A secure provisioned domain uses several controls:

```text
VPC network access
      +
Domain access policy
      +
IAM authentication
      +
Fine-grained access control
      +
TLS
      +
Node-to-node encryption
      +
Encryption at rest
      +
Audit logging
```

Each solves a different problem.

---

# 63. VPC access

Recommended production design:

```text
Private ECS / Lambda / EC2
           |
           v
VPC OpenSearch endpoint
```

The domain endpoint receives private IP addresses in your VPC subnets.

Security groups control network reachability.

```text
OpenSearch security group inbound:
TCP 443
Source:
Application security group
```

A VPC domain cannot later be treated exactly like a publicly reachable endpoint; plan network access for administrators, ingestion services and CI/CD before deployment. ([AWS Documentation][29])

---

# 64. Domain access policy

A domain access policy controls which AWS principals or network conditions may call the domain endpoint.

Conceptual IAM access:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:role/TodoSearchRole"
  },
  "Action": [
    "es:ESHttpGet",
    "es:ESHttpPost",
    "es:ESHttpPut"
  ],
  "Resource": "arn:aws:es:ap-south-1:123456789012:domain/todo-search/*"
}
```

The configuration API and document/search APIs use different authorization contexts.

---

# 65. Fine-grained access control

Fine-grained access control supports permissions at:

```text
Cluster level
Index level
Document level
Field level
```

Example:

```text
todo-api:
Read and write todos-* indexes

security-analyst:
Read security-* indexes

support-user:
Read selected document fields

administrator:
Cluster administration
```

Fine-grained access control requires HTTPS, node-to-node encryption and encryption at rest. ([AWS Documentation][30])

---

# 66. Tenant access

Suppose one index contains several tenants:

```json
{
  "tenantId": "tenant-38",
  "todoId": "501"
}
```

Possible controls:

* Separate index per tenant.
* Document-level security.
* Filtered aliases.
* Application-enforced filters.
* Separate domains for strict boundaries.

Application filtering alone is vulnerable if one code path forgets the tenant filter.

For strong multitenancy, enforce access below the application layer as well.

---

# 67. IAM request signing

When a domain policy uses IAM principals, HTTP requests must normally be signed using AWS Signature Version 4.

Service names:

```text
Provisioned OpenSearch domain:
es

OpenSearch Serverless:
aoss
```

Serverless additionally uses separate data-access policies and network policies. ([AWS Documentation][4])

---

# 68. Encryption

Production recommendations:

```text
Require HTTPS:
true

Node-to-node encryption:
true

Encryption at rest:
true

KMS:
Customer-managed key where required
```

Node-to-node encryption protects traffic between cluster nodes using TLS and cannot be disabled after being enabled on a domain. ([AWS Documentation][31])

Encryption at rest protects indexes, logs and associated storage using AWS KMS. ([AWS Documentation][32])

Do not delete or disable a KMS key used by a live domain.

---

# 69. Audit logs

Audit logs can record:

* Authentication successes and failures.
* OpenSearch requests.
* Index changes.
* Search queries.
* Security events.
* User activity.

OpenSearch Service publishes audit logs, error logs and slow logs to CloudWatch Logs. Audit logging requires fine-grained access control. ([AWS Documentation][33])

Be careful with high-volume audit options:

```text
One audit record per document
inside every bulk request
```

can generate enormous logging volume and cost.

---

# 70. Slow logs

Enable:

```text
Search shard slow logs
Indexing shard slow logs
Application error logs
```

Slow logs help identify:

* Expensive queries.
* Slow shard execution.
* Oversized aggregations.
* Slow indexing.
* Mapping conflicts.
* Cluster exceptions.

Thresholds are configured at index level.

Do not set every threshold to zero in production; that logs every operation.

---

# 71. Automated snapshots

Provisioned OpenSearch domains take automated snapshots for service recovery.

For modern OpenSearch domains, AWS takes hourly snapshots and retains up to 336 snapshots covering 14 days. Automated snapshots are stored in an AWS-managed S3 bucket without separate snapshot-storage charges. ([AWS Documentation][34])

```text
Domain
  |
  v
Hourly automated snapshots
  |
  v
AWS-managed snapshot repository
```

Automated snapshots are primarily for domain and index recovery, not your complete cross-account backup-governance strategy.

---

# 72. Manual snapshots

Manual snapshots are stored in your S3 bucket.

Use for:

* Long-term retention.
* Migration.
* Cross-domain restoration.
* Pre-upgrade protection.
* Cross-account recovery planning.
* Restoring into a different domain.

Manual snapshots require:

* S3 bucket.
* Snapshot IAM role.
* Domain permissions.
* Repository registration.
* Lifecycle policy.

Manual snapshots can be used to migrate data between compatible OpenSearch domains. ([AWS Documentation][34])

---

# 73. Snapshot limitations

Snapshots are incremental, but they are not instantaneous global database transactions.

While a manual snapshot is running:

* Indexing can continue.
* Newer writes may not be included.
* Different primary shards are captured as snapshot processing reaches them.

A snapshot with missing primary shards can be marked partial. ([AWS Documentation][35])

Always verify:

```text
Snapshot state:
SUCCESS
```

before relying on it.

---

# 74. Snapshot restore

Restore options include:

```text
Restore selected indexes
Rename indexes during restore
Delete conflicting indexes first
Restore manual snapshot to another domain
```

You cannot restore an index using the same name when that index already exists unless you remove or rename the conflict. ([AWS Documentation][36])

Recovery workflow:

```text
1. Create or select recovery domain.

2. Register snapshot repository.

3. Verify snapshot state.

4. Restore selected indexes.

5. Validate document counts and mappings.

6. Recreate aliases and security configuration.

7. Switch ingestion and search traffic.
```

---

# 75. Snapshot Management

Snapshot Management can automate creation and deletion of manual snapshots in your registered S3 repository.

It can snapshot groups of indexes according to a schedule and retention policy. ([AWS Documentation][37])

Use when automated service snapshots do not meet:

* Compliance retention.
* Cross-account requirements.
* Migration requirements.
* Independent S3 ownership.
* Custom snapshot schedules.

---

# 76. Cross-cluster replication

Cross-cluster replication copies:

* Index documents.
* Mappings.
* Index metadata.

from a leader domain to a follower domain.

```text
Leader domain
ap-south-1
      |
      | Active-passive replication
      v
Follower domain
ap-southeast-1
```

The follower pulls changes from the leader and is normally used for disaster recovery or geographically local reads. ([AWS Documentation][38])

---

# 77. Cross-cluster replication limitations

Important limitations include:

* Active-passive rather than active-active.
* Domain-to-domain replication only.
* UltraWarm and cold indexes cannot be replicated.
* Deleting the leader index does not automatically delete the follower.
* Replication cannot be chained through follower domains.
* Both leader and follower indexes must remain in hot storage. ([AWS Documentation][38])

For multiple DR Regions:

```text
Leader
├── Follower Region B
└── Follower Region C
```

Do not configure:

```text
Leader
  → Follower B
      → Follower C
```

---

# 78. Disaster-recovery patterns

## Snapshot restore

```text
Cost:
Lower

RTO:
Higher

RPO:
Snapshot dependent
```

## Cross-cluster replication

```text
Cost:
Higher

RTO:
Lower

RPO:
Replication-lag dependent
```

Complete DR also requires:

* Ingestion pipeline.
* Application search endpoints.
* Network policies.
* IAM roles.
* Dashboards.
* KMS keys.
* DNS or application configuration.
* Validation and failover runbooks.

---

# 79. CloudWatch monitoring

OpenSearch Service publishes domain metrics to CloudWatch, usually at one-minute intervals. Metrics cover clusters, nodes, dedicated masters, EBS, warm nodes, coordinator nodes, k-NN, ingestion and other features. ([AWS Documentation][39])

Core production metrics:

```text
ClusterStatus.red
ClusterStatus.yellow
Nodes
CPUUtilization
JVMMemoryPressure
OldGenJVMMemoryPressure
FreeStorageSpace
ClusterIndexWritesBlocked
ThreadpoolWriteQueue
ThreadpoolWriteRejected
ThreadpoolSearchQueue
ThreadpoolSearchRejected
MasterCPUUtilization
MasterJVMMemoryPressure
AutomatedSnapshotFailure
KMSKeyError
KMSKeyInaccessible
```

---

# 80. JVM memory

OpenSearch Service normally allocates approximately half of instance memory to the Java heap, up to a `32 GiB` heap.

The rest supports:

* Operating system.
* Filesystem cache.
* Native processes.
* Off-heap data.
* Network buffers.

AWS recommends alerting when `JVMMemoryPressure` reaches 95% and when old-generation pressure remains above 80%. ([AWS Documentation][14])

High JVM pressure can cause:

* Long garbage collection.
* Slow searches.
* Rejected requests.
* Node instability.
* Out-of-memory failure.

---

# 81. Storage alarms

AWS recommends alarming when free storage reaches approximately 25% of node storage rather than waiting until only a few gigabytes remain. ([AWS Documentation][14])

Low storage can trigger:

```text
ClusterIndexWritesBlocked = 1
```

Symptoms:

```text
429 or cluster block errors
Indexing stops
Dashboards cannot write internal indexes
Shard relocation stalls
```

Storage problems require immediate action.

---

# 82. Thread-pool rejection

Search and indexing use bounded thread pools and queues.

If demand exceeds processing capacity:

```text
Queue fills
    |
    v
Request rejected
    |
    v
HTTP 429
```

Metrics:

```text
ThreadpoolWriteRejected
ThreadpoolSearchRejected
```

AWS recommends alarms on any increase in rejection counts. ([AWS Documentation][14])

Do not simply increase queue sizes indefinitely. Larger queues can move the problem from fast rejection to JVM exhaustion.

---

# 83. Cluster Insights

Cluster Insights provides a consolidated operational view across:

* Nodes.
* Indexes.
* Shards.
* Cluster health.
* Performance risks.
* Capacity issues.

It is designed to correlate operational signals and simplify diagnosis rather than requiring manual comparison of many independent charts. ([AWS Documentation][40])

Use it alongside—not instead of—CloudWatch alarms and application telemetry.

---

# 84. Auto-Tune

Auto-Tune analyses domain performance and can recommend or apply changes involving:

* Queue sizes.
* Cache sizes.
* JVM settings.
* Memory-related settings.

Some changes can be applied while the cluster runs. Others require a blue/green deployment during the configured off-peak window. ([AWS Documentation][41])

Auto-Tune improves selected cluster settings.

It does not fix:

* Bad mappings.
* Oversharding.
* Missing tenant filters.
* Expensive aggregations.
* Poor ingestion design.
* One huge hot shard.

---

# 85. Domain configuration changes

Many OpenSearch Service domain changes use a blue/green deployment:

```text
Current environment
      |
      v
New environment created
      |
      v
Data and configuration migrated
      |
      v
Endpoint moved to new environment
```

OpenSearch Service uses blue/green deployment for eligible configuration changes to reduce disruption. ([AWS Documentation][42])

Before a major domain change:

* Ensure cluster is green.
* Ensure sufficient free storage.
* Confirm snapshots.
* Review off-peak window.
* Check shard health.
* Avoid concurrent bulk ingestion.
* Monitor during and after deployment.

---

# 86. Service software versus engine version

## Service software update

Updates AWS-managed components around the OpenSearch domain.

```text
Security updates
AWS service improvements
Platform fixes
```

## OpenSearch engine upgrade

Changes the OpenSearch version.

```text
OpenSearch 2.x
    |
    v
OpenSearch 3.x
```

These are separate processes. Required service software updates may be automatically applied if not scheduled within the allowed window. ([AWS Documentation][43])

---

# 87. Engine upgrades

OpenSearch Service currently supports OpenSearch 3.x.

For domains on OpenSearch `1.3` or `2.x`, current upgrade guidance requires reaching OpenSearch `2.19` before upgrading to OpenSearch `3.x`. ([AWS Documentation][44])

Upgrade workflow:

```text
1. Review breaking changes.

2. Run upgrade eligibility check.

3. Test clients and plugins.

4. Take manual snapshot.

5. Validate ingestion-service compatibility.

6. Upgrade staging.

7. Load test.

8. Upgrade production.

9. Validate mappings, queries and dashboards.
```

---

# 88. Capacity planning

Start with:

```text
Daily source-data volume
Retention period
Replication factor
Indexing overhead
Target shard size
Peak indexing rate
Peak query rate
Query complexity
Availability requirement
```

Example:

```text
Daily source data:
100 GiB

Hot retention:
14 days

Hot primary data:
1,400 GiB

One replica:
2,800 GiB

Indexing and safety overhead:
30%

Estimated hot storage:
3,640 GiB
```

Then choose:

* Data-node family.
* Data-node count.
* EBS capacity.
* Shard count.
* Dedicated master size.
* Warm/cold policy.
* Growth margin.

Load testing is mandatory because equal data volumes can have radically different query costs.

---

# 89. Production log-analytics architecture

```text
ECS and EC2 applications
          |
          v
CloudWatch Logs / OpenTelemetry
          |
          v
OpenSearch Ingestion
          |
          v
Amazon OpenSearch Service
Multi-AZ with Standby
├── Three dedicated master nodes
├── Hot data nodes
├── UltraWarm nodes
└── Cold storage
          |
          v
OpenSearch Dashboards
```

Lifecycle:

```text
0–14 days:
Hot

15–90 days:
UltraWarm

91–365 days:
Cold

After 365 days:
Delete or archive elsewhere
```

---

# 90. TodoApp search architecture

```text
User
  |
  v
Todo API
  |
  ├── Authoritative write
  |       |
  |       v
  |    Aurora / DynamoDB
  |
  └── Search query
          |
          v
       OpenSearch
```

Change propagation:

```text
Aurora CDC / DynamoDB Streams
        |
        v
EventBridge / Kinesis / ingestion worker
        |
        v
OpenSearch todos index
```

OpenSearch document:

```json
{
  "todoId": "501",
  "tenantId": "tenant-38",
  "userId": "user-104",
  "title": "Learn AWS OpenSearch",
  "description": "Build production search architecture",
  "status": "OPEN",
  "tags": [
    "aws",
    "devops"
  ],
  "createdAt": "2026-07-30T04:45:00Z"
}
```

---

# 91. Terraform provisioned domain

```hcl
resource "aws_opensearch_domain" "todo_search" {
  domain_name    = "production-todo-search"
  engine_version = var.opensearch_engine_version

  cluster_config {
    instance_type  = var.data_node_instance_type
    instance_count = 6

    dedicated_master_enabled = true
    dedicated_master_type    = var.master_node_instance_type
    dedicated_master_count   = 3

    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 3
    }

    multi_az_with_standby_enabled = true
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 500
    iops        = 6000
    throughput  = 500
  }

  vpc_options {
    subnet_ids = [
      aws_subnet.search_a.id,
      aws_subnet.search_b.id,
      aws_subnet.search_c.id
    ]

    security_group_ids = [
      aws_security_group.opensearch.id
    ]
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = aws_kms_key.opensearch.arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = false

    master_user_options {
      master_user_arn = aws_iam_role.opensearch_admin.arn
    }
  }

  software_update_options {
    auto_software_update_enabled = true
  }

  off_peak_window_options {
    enabled = true

    off_peak_window {
      window_start_time {
        hours   = 19
        minutes = 0
      }
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

Use provider documentation to confirm resource fields against the installed AWS provider version.

---

# 92. Terraform security group

```hcl
resource "aws_security_group" "opensearch" {
  name   = "production-todo-search"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTPS from TodoApp services"

    protocol  = "tcp"
    from_port = 443
    to_port   = 443

    security_groups = [
      aws_security_group.todo_api.id,
      aws_security_group.search_ingestion.id
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
    Environment = "production"
  }
}
```

---

# 93. Terraform domain access policy

```hcl
data "aws_iam_policy_document" "opensearch_access" {
  statement {
    sid    = "AllowApplicationAccess"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        aws_iam_role.todo_api.arn,
        aws_iam_role.search_ingestion.arn,
        aws_iam_role.opensearch_admin.arn
      ]
    }

    actions = [
      "es:ESHttpGet",
      "es:ESHttpPost",
      "es:ESHttpPut",
      "es:ESHttpDelete",
      "es:ESHttpHead"
    ]

    resources = [
      "${aws_opensearch_domain.todo_search.arn}/*"
    ]
  }
}

resource "aws_opensearch_domain_policy" "todo_search" {
  domain_name = aws_opensearch_domain.todo_search.domain_name
  access_policies = data.aws_iam_policy_document.opensearch_access.json
}
```

Fine-grained OpenSearch roles should further restrict which indexes and operations each principal can access.

---

# 94. Terraform CloudWatch logs

```hcl
resource "aws_cloudwatch_log_group" "opensearch_application" {
  name              = "/aws/opensearch/production/application"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_cloudwatch_log_group" "opensearch_search_slow" {
  name              = "/aws/opensearch/production/search-slow"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_cloudwatch_log_group" "opensearch_index_slow" {
  name              = "/aws/opensearch/production/index-slow"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_cloudwatch_log_group" "opensearch_audit" {
  name              = "/aws/opensearch/production/audit"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs.arn
}
```

Inside the domain:

```hcl
log_publishing_options {
  enabled                  = true
  log_type                 = "ES_APPLICATION_LOGS"
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_application.arn
}

log_publishing_options {
  enabled                  = true
  log_type                 = "SEARCH_SLOW_LOGS"
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_slow.arn
}

log_publishing_options {
  enabled                  = true
  log_type                 = "INDEX_SLOW_LOGS"
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_index_slow.arn
}

log_publishing_options {
  enabled                  = true
  log_type                 = "AUDIT_LOGS"
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_audit.arn
}
```

The CloudWatch log groups also require resource policies permitting OpenSearch Service to create streams and publish log events.

---

# 95. Terraform alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "cluster_red" {
  alarm_name = "production-opensearch-cluster-red"

  namespace   = "AWS/ES"
  metric_name = "ClusterStatus.red"

  statistic = "Maximum"
  period    = 60

  evaluation_periods  = 1
  datapoints_to_alarm = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1

  dimensions = {
    DomainName = aws_opensearch_domain.todo_search.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  alarm_actions = [
    aws_sns_topic.operations.arn
  ]

  treat_missing_data = "notBreaching"
}
```

Also create alarms for:

```text
ClusterStatus.yellow
FreeStorageSpace
ClusterIndexWritesBlocked
JVMMemoryPressure
OldGenJVMMemoryPressure
Nodes
MasterCPUUtilization
ThreadpoolWriteRejected
ThreadpoolSearchRejected
AutomatedSnapshotFailure
KMSKeyError
```

---

# 96. Terraform Serverless collection

Encryption policy:

```hcl
resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "todo-search-encryption"
  type = "encryption"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource = [
          "collection/todo-search"
        ]
      }
    ]

    AWSOwnedKey = true
  })
}
```

Network policy:

```hcl
resource "aws_opensearchserverless_security_policy" "network" {
  name = "todo-search-network"
  type = "network"

  policy = jsonencode([
    {
      Description = "Private application access"

      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/todo-search"
          ]
        },
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/todo-search"
          ]
        }
      ]

      AllowFromPublic = false

      SourceVPCEs = [
        aws_opensearchserverless_vpc_endpoint.main.id
      ]
    }
  ])
}
```

Collection:

```hcl
resource "aws_opensearchserverless_collection" "todo_search" {
  name = "todo-search"
  type = "SEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption
  ]

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

Serverless also requires a data-access policy granting index and collection operations to the application roles.

---

# 97. Python SigV4 client

```python
from __future__ import annotations

import boto3
from opensearchpy import (
    AWSV4SignerAuth,
    OpenSearch,
    RequestsHttpConnection,
)

region = "ap-south-1"
host = "vpc-production-todo-search.example.ap-south-1.es.amazonaws.com"

credentials = boto3.Session().get_credentials()
auth = AWSV4SignerAuth(credentials, region, "es")

client = OpenSearch(
    hosts=[
        {
            "host": host,
            "port": 443,
        }
    ],
    http_auth=auth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
    pool_maxsize=20,
    timeout=10,
    max_retries=3,
    retry_on_timeout=True,
)

response = client.search(
    index="todos-read",
    body={
        "query": {
            "bool": {
                "must": [
                    {
                        "match": {
                            "title": "AWS production"
                        }
                    }
                ],
                "filter": [
                    {
                        "term": {
                            "tenantId": "tenant-38"
                        }
                    }
                ],
            }
        }
    },
)

print(response["hits"]["hits"])
```

For OpenSearch Serverless, use:

```python
AWSV4SignerAuth(credentials, region, "aoss")
```

---

# 98. Useful inspection commands

Cluster health:

```http
GET /_cluster/health
```

Nodes:

```http
GET /_cat/nodes?v
```

Indexes:

```http
GET /_cat/indices?v&s=store.size:desc
```

Shards:

```http
GET /_cat/shards?v
```

Allocation explanation:

```http
GET /_cluster/allocation/explain
```

Index mapping:

```http
GET /todos-v1/_mapping
```

Index settings:

```http
GET /todos-v1/_settings
```

Pending cluster tasks:

```http
GET /_cluster/pending_tasks
```

Thread pools:

```http
GET /_cat/thread_pool?v
```

---

# 99. Troubleshooting `403 Forbidden`

Possible causes:

* IAM role not allowed by domain policy.
* Request is not SigV4 signed.
* Wrong signing service: `es` versus `aoss`.
* Fine-grained role mapping missing.
* Index permission missing.
* Document-level rule denies result.
* Network policy denies connection.
* VPC endpoint not allowed.
* Application is using the wrong AWS role.
* Dashboards authentication misconfigured.

Troubleshooting layers:

```text
1. Can TCP/TLS reach the endpoint?

2. Does IAM domain or collection policy allow the principal?

3. Is the request correctly signed?

4. Is the IAM backend role mapped?

5. Does the OpenSearch role allow this index and action?
```

---

# 100. Troubleshooting `429 Too Many Requests`

Common causes:

* Write thread pool full.
* Search thread pool full.
* JVM memory pressure.
* CPU saturation.
* Too many concurrent bulk requests.
* Too many shards.
* Expensive aggregations.
* Serverless OCU maximum reached.
* Hot shard.

Check:

```text
ThreadpoolWriteQueue
ThreadpoolWriteRejected
ThreadpoolSearchQueue
ThreadpoolSearchRejected
JVMMemoryPressure
CPUUtilization
```

Client response:

```text
Exponential backoff
+
Jitter
+
Bounded retries
```

Do not retry every rejected request immediately.

---

# 101. Troubleshooting red cluster

Red means one or more primary shards are unassigned.

Run:

```http
GET /_cluster/health
GET /_cat/indices?v
GET /_cat/shards?v
GET /_cluster/allocation/explain
```

Possible causes:

* Node failure.
* Storage exhaustion.
* Corrupt shard.
* KMS problem.
* Too few nodes.
* Invalid allocation settings.
* Failed recovery.
* Snapshot or restore issue.

Recovery options:

* Restore affected index from snapshot.
* Free storage.
* Add nodes.
* Repair allocation problem.
* Reindex from authoritative source.
* Delete only unrecoverable disposable indexes.

Do not delete a red index before confirming whether it contains unique data.

---

# 102. Troubleshooting yellow cluster

Yellow means primary shards are available but one or more replicas are unassigned.

Possible causes:

* Too few data nodes.
* Allocation disabled.
* Node replacement in progress.
* Storage or AZ constraints.
* Replica count too high for topology.
* Shard-size or count constraints.

Development fix:

```json
PUT index-name/_settings
{
  "index": {
    "number_of_replicas": 0
  }
}
```

Production fix is usually:

* Restore healthy nodes.
* Add capacity.
* Correct allocation.
* Use Multi-AZ.
* Maintain replicas.

---

# 103. Troubleshooting high JVM pressure

Check:

* Oversharding.
* Expensive aggregations.
* Large field data.
* High-cardinality queries.
* Large bulk requests.
* Mapping explosion.
* Large query result windows.
* Too many concurrent searches.
* Scripted queries.
* Vector graph memory.
* Cache sizes.

Actions:

* Reduce query concurrency.
* Add data nodes.
* Increase instance size.
* Reduce shard count.
* Reindex into healthier shards.
* Use narrower date ranges.
* Fix mappings.
* Move historical data to warm storage.

Restarting a node without fixing the cause only postpones recurrence.

---

# 104. Troubleshooting blocked writes

Symptoms:

```text
ClusterIndexWritesBlocked = 1
cluster_block_exception
index read-only
```

Most common cause:

```text
Low disk space
```

Actions:

```text
1. Stop or reduce ingestion.

2. Delete safe old indexes.

3. Increase EBS capacity.

4. Add data nodes if required.

5. Verify shard relocation.

6. Confirm write block clears.

7. Correct lifecycle policies.
```

Do not delete individual documents to recover space quickly; segment storage may not be reclaimed immediately.

Deleting whole old indexes is normally faster.

---

# 105. Troubleshooting slow search

Check:

* Query duration by shard.
* Search slow logs.
* Number of shards searched.
* Date-range width.
* Aggregation cardinality.
* Mapping types.
* Sorting fields.
* Deep pagination.
* Scripted fields.
* Wildcards and regex.
* JVM pressure.
* Filesystem cache.
* Coordinator CPU.
* Hot and warm tier placement.

Possible improvements:

* Search fewer indexes.
* Use aliases with date routing.
* Use filters.
* Use `keyword` fields correctly.
* Use PIT and `search_after`.
* Add replicas.
* Add coordinator nodes.
* Precompute aggregations.
* Use rollup indexes.

---

# 106. Troubleshooting slow indexing

Check:

* Bulk size.
* Bulk concurrency.
* Refresh interval.
* Replica count.
* Mapping updates.
* Dynamic-field creation.
* Write rejections.
* Node CPU.
* EBS throughput.
* EBS IOPS.
* Shard count.
* Hot shard.
* Document size.
* Ingest-pipeline complexity.

Possible improvements:

```text
Use Bulk API
Increase refresh interval
Control concurrency
Use explicit mappings
Increase EBS throughput
Add primary shards carefully
Scale data nodes
Buffer traffic
```

---

# 107. Troubleshooting Dashboards

Common causes:

* Domain red or yellow.
* Dashboards system index unassigned.
* Write block from low storage.
* VPC connectivity.
* IAM policy.
* Fine-grained role mapping.
* Cognito or SAML configuration.
* High JVM pressure.
* `429` rejections.
* Service software out of date.

AWS recommends first checking the domain’s notifications, cluster health and available service software updates. ([AWS Documentation][45])

---

# 108. Cost optimization

Major cost drivers:

```text
Data nodes
Dedicated master nodes
Coordinator nodes
EBS storage
Provisioned IOPS and throughput
UltraWarm nodes
Serverless OCUs
Ingestion OCUs
Cross-Region transfer
Snapshots in your S3 bucket
CloudWatch Logs
Vector storage and compute
```

Optimisation practices:

* Use healthy shard sizes.
* Remove unused indexes.
* Use ISM.
* Move older logs to warm and cold tiers.
* Use `gp3` where appropriate.
* Right-size instance families.
* Reduce unnecessary replicas.
* Use rollups.
* Set Serverless OCU maximums.
* Reduce duplicate fields.
* Control audit-log volume.
* Limit high-cardinality aggregations.
* Benchmark optimized instance families.

AWS recommends moving older log data to UltraWarm or cold storage and using gp3 to provision IOPS and throughput independently of EBS volume size. ([AWS Documentation][15])

---

# 109. Production readiness checklist

```text
[ ] OpenSearch is not the only copy of critical transactional data
[ ] Provisioned versus Serverless decision is documented
[ ] Domain runs inside a VPC
[ ] Multi-AZ with Standby is enabled where supported
[ ] Three dedicated master nodes are configured
[ ] Data-node count is compatible with AZ topology
[ ] Instance types are load tested
[ ] Storage has growth headroom
[ ] Free-storage alarms exist
[ ] Primary shard count is planned before indexing
[ ] Target shard size is documented
[ ] Replica count matches availability requirements
[ ] Oversharding is monitored
[ ] Hot-shard risk is tested
[ ] Mappings are explicit
[ ] Dynamic mapping is restricted
[ ] Tenant fields are mandatory
[ ] Index templates are version controlled
[ ] Aliases are used for application index names
[ ] Reindexing procedure is tested
[ ] Time-series indexes use rollover or data streams
[ ] ISM policy controls retention
[ ] Old data moves to cheaper storage
[ ] Bulk indexing uses bounded batches
[ ] Partial bulk failures are retried selectively
[ ] Ingestion is buffered
[ ] Dead-letter handling exists
[ ] HTTPS is enforced
[ ] Node-to-node encryption is enabled
[ ] Encryption at rest is enabled
[ ] KMS key deletion is protected
[ ] IAM domain policy is least privilege
[ ] Fine-grained access control is enabled
[ ] Document and field permissions are reviewed
[ ] Audit logs are enabled
[ ] Slow logs are enabled with sensible thresholds
[ ] Automated snapshots are monitored
[ ] Manual snapshots are created for long-term recovery
[ ] Snapshot restoration is tested
[ ] Cross-Region DR is documented
[ ] Cluster red and yellow alarms exist
[ ] JVM alarms exist
[ ] Thread-pool rejection alarms exist
[ ] Dedicated-master alarms exist
[ ] Auto-Tune and off-peak windows are reviewed
[ ] Service software is current
[ ] Engine upgrades are tested
[ ] Search SLOs are defined
[ ] Cost per indexed GiB and query is reviewed
```

---

# 110. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Amazon OpenSearch Service:
Managed search and analytics.

OpenSearch Dashboards:
Search visualization and analysis.

Index:
Collection of searchable documents.

Document:
JSON record stored in an index.
```

## Solutions Architect Associate

Understand:

```text
VPC domains
Multi-AZ
Dedicated master nodes
Data nodes
Primary shards
Replica shards
Automated snapshots
UltraWarm
OpenSearch Serverless
Fine-grained access control
```

## DevOps Engineer Professional

Understand:

```text
Multi-AZ with Standby
Shard sizing
Index templates
Index State Management
Bulk ingestion
OpenSearch Ingestion
Cross-cluster replication
Slow logs
Audit logs
Thread-pool rejections
JVM pressure
Blue/green domain updates
Terraform deployments
Snapshot recovery
```

---

# 111. Interview questions

## Question 1: What is Amazon OpenSearch Service?

**Answer:**

It is a managed AWS search and analytics service used for full-text search, log analytics, observability, security analytics and vector search.

## Question 2: Should OpenSearch be the primary transactional database?

**Answer:**

Usually not. Critical business data should remain in an authoritative database and be indexed into OpenSearch for search and analytics.

## Question 3: What is an OpenSearch index?

**Answer:**

It is a logical collection of documents with mappings, settings, primary shards and replica shards.

## Question 4: What is an inverted index?

**Answer:**

It maps analyzed terms to the documents containing them, allowing OpenSearch to locate matching documents without scanning every complete document.

## Question 5: What is the difference between `text` and `keyword`?

**Answer:**

`text` fields are analyzed for full-text search. `keyword` fields are used for exact matching, filtering, sorting and aggregations.

## Question 6: What is a primary shard?

**Answer:**

It is one partition of an index that stores and initially processes writes for its section of the data.

## Question 7: What is a replica shard?

**Answer:**

It is a copy of a primary shard used for search capacity and availability.

## Question 8: Do replicas improve indexing throughput?

**Answer:**

No. Every write must also be copied to replicas, so replicas normally add write work while improving read capacity and resilience.

## Question 9: What is oversharding?

**Answer:**

It is creating too many small shards, causing excessive JVM, CPU, cluster-state and file-handle overhead.

## Question 10: What is Multi-AZ with Standby?

**Answer:**

It is a three-AZ OpenSearch Service deployment with dedicated standby data capacity that can be activated rapidly during infrastructure failure.

## Question 11: What is the difference between green, yellow and red cluster health?

**Answer:**

Green means all primaries and replicas are assigned. Yellow means all primaries are assigned but some replicas are unavailable. Red means at least one primary shard is unavailable.

## Question 12: What is the Bulk API?

**Answer:**

It combines several index, update or delete operations into fewer network requests, improving ingestion efficiency.

## Question 13: What is Index State Management?

**Answer:**

It automates index lifecycle actions such as rollover, migration to warm or cold storage and deletion.

## Question 14: What is UltraWarm?

**Answer:**

It is S3-backed, read-only storage with warm compute nodes for older, less frequently searched indexes.

## Question 15: What is OpenSearch Serverless?

**Answer:**

It is an automatically scaling OpenSearch deployment model that separates search and ingestion compute and stores indexes primarily in S3.

## Question 16: What is fine-grained access control?

**Answer:**

It provides cluster, index, document and field-level permissions inside OpenSearch.

## Question 17: What causes `429` responses?

**Answer:**

Search or write queues may be full because the domain is overloaded, JVM pressure is high, shards are unhealthy or concurrency exceeds available capacity.

## Question 18: What is cross-cluster replication?

**Answer:**

It is active-passive replication from leader indexes in one OpenSearch Service domain to follower indexes in another domain.

## Question 19: How do you change an incompatible mapping?

**Answer:**

Create a new index with the correct mapping, reindex the data, validate it and atomically switch an alias.

## Question 20: How would you protect OpenSearch from a log spike?

**Answer:**

Buffer ingestion through Kinesis, Kafka, Firehose or OpenSearch Ingestion; use bounded bulk requests, backoff, dead-letter handling and sufficient indexing capacity.

---

# 112. Never-forget revision

```text
Domain:
Provisioned OpenSearch cluster.

Collection:
OpenSearch Serverless logical workload.

Index:
Collection of documents.

Document:
Searchable JSON record.

Mapping:
Field schema and indexing rules.

Text:
Analyzed full-text field.

Keyword:
Exact-match field.

Primary shard:
Main index partition.

Replica shard:
Availability and search copy.

Oversharding:
Too many small shards.

Multi-AZ with Standby:
Three-AZ production availability design.

Bulk API:
Efficient multi-document indexing.

Refresh:
Makes recent indexing searchable.

Alias:
Stable logical index name.

Data stream:
Managed time-series backing indexes.

Rollover:
Creates a new write index.

ISM:
Automated index lifecycle.

UltraWarm:
S3-backed warm search tier.

Cold storage:
Detached low-cost historical tier.

FGAC:
Fine-grained access control.

OSI:
Managed OpenSearch ingestion.

k-NN:
Vector nearest-neighbour search.

Snapshot:
Index backup.

CCR:
Active-passive cross-cluster replication.

JVM pressure:
Java heap utilisation risk.

Red:
Primary shard unavailable.

Yellow:
Replica shard unavailable.

Green:
All shard copies assigned.
```

## One-line memory trick

```text
Store truth in a database.
Index it for search.
Map fields deliberately.
Keep shards healthy.
Buffer every ingestion spike.
Move old data to cheaper tiers.
Secure every document.
Snapshot and test recovery.
```

## Lesson 49 outcome

You can now design OpenSearch where:

```text
Users need full-text TodoApp search
    → OpenSearch indexes titles and descriptions.

The database remains authoritative
    → CDC sends changes into the search index.

Log volume grows suddenly
    → A managed ingestion pipeline buffers and batches data.

One Availability Zone fails
    → Multi-AZ with Standby activates reserved capacity.

Search traffic grows
    → Replicas and search capacity scale horizontally.

An index becomes too large
    → Rollover creates a new backing index.

Logs become old
    → ISM moves them from hot to warm and cold storage.

A mapping must change
    → A new index is created and an alias is switched.

Users search by meaning
    → Vector embeddings power semantic retrieval.

One primary shard is unavailable
    → The cluster turns red and recovery begins immediately.

A Region fails
    → A cross-cluster follower can support disaster recovery.
```

**Next lesson: Lesson 50 — Amazon Kinesis Data Streams and Amazon MSK production streaming architecture: partitions, shards, producers, consumers, ordering, replay, retention, scaling, delivery guarantees, Kafka operations and event-driven design.**

[1]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/what-is.html?utm_source=chatgpt.com "What is Amazon OpenSearch Service? - Amazon OpenSearch Service"
[2]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/knn.html?utm_source=chatgpt.com "k-Nearest Neighbor (k-NN) search in Amazon OpenSearch ..."
[3]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless.html?utm_source=chatgpt.com "Amazon OpenSearch Serverless - Amazon OpenSearch Service"
[4]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless-comparison.html "Comparing OpenSearch Service and OpenSearch Serverless - Amazon OpenSearch Service"
[5]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-dedicatedmasternodes.html "Dedicated master nodes in Amazon OpenSearch Service - Amazon OpenSearch Service"
[6]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-multiaz.html "Configuring a multi-AZ domain in Amazon OpenSearch Service - Amazon OpenSearch Service"
[7]: https://docs.opensearch.org/latest/mappings/supported-field-types/keyword/?utm_source=chatgpt.com "Keyword field type"
[8]: https://docs.opensearch.org/latest/api-reference/index-apis/create-index-template/?utm_source=chatgpt.com "Create Or Update Index Template API"
[9]: https://docs.opensearch.org/latest/mappings/mapping-parameters/dynamic/?utm_source=chatgpt.com "Dynamic mapping parameter"
[10]: https://docs.opensearch.org/latest/mappings/mapping-explosion/?utm_source=chatgpt.com "Mapping explosion"
[11]: https://docs.opensearch.org/latest/api-reference/index-apis/refresh/?utm_source=chatgpt.com "Refresh Index API"
[12]: https://docs.opensearch.org/latest/api-reference/document-apis/bulk/?utm_source=chatgpt.com "Bulk API"
[13]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/bp-sharding.html "Choosing the number of shards - Amazon OpenSearch Service"
[14]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/cloudwatch-alarms.html "Recommended CloudWatch alarms for Amazon OpenSearch Service - Amazon OpenSearch Service"
[15]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/bp.html?utm_source=chatgpt.com "Operational best practices for Amazon OpenSearch Service - Amazon OpenSearch Service"
[16]: https://docs.opensearch.org/latest/search-plugins/point-in-time/?utm_source=chatgpt.com "Point in Time - OpenSearch Documentation"
[17]: https://docs.opensearch.org/latest/im-plugin/index-alias/?utm_source=chatgpt.com "Index aliases | OpenSearch Documentation"
[18]: https://docs.opensearch.org/latest/api-reference/index-apis/index-templates/?utm_source=chatgpt.com "Index template APIs | OpenSearch Documentation"
[19]: https://docs.opensearch.org/latest/im-plugin/data-streams/?utm_source=chatgpt.com "Data streams - OpenSearch Documentation"
[20]: https://docs.opensearch.org/latest/api-reference/index-apis/rollover/?utm_source=chatgpt.com "Roll Over Index API | OpenSearch Documentation"
[21]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/ism.html "Index State Management in Amazon OpenSearch Service - Amazon OpenSearch Service"
[22]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/ultrawarm.html?utm_source=chatgpt.com "UltraWarm storage for Amazon OpenSearch Service - Amazon OpenSearch Service"
[23]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/cold-storage.html?utm_source=chatgpt.com "Cold storage for Amazon OpenSearch Service - Amazon OpenSearch Service"
[24]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/or1.html?utm_source=chatgpt.com "OpenSearch Optimized Instances for Amazon OpenSearch Service domains - Amazon OpenSearch Service"
[25]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless-overview.html "What is Amazon OpenSearch Serverless? - Amazon OpenSearch Service"
[26]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/ingestion.html?utm_source=chatgpt.com "Overview of Amazon OpenSearch Ingestion - Amazon OpenSearch Service"
[27]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/semantic-search.html?utm_source=chatgpt.com "Semantic search in Amazon OpenSearch Service"
[28]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless-vector-ingestion.html?utm_source=chatgpt.com "Vector ingestion - Amazon OpenSearch Service"
[29]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/vpc.html?utm_source=chatgpt.com "Launching your Amazon OpenSearch Service domains within a VPC - Amazon OpenSearch Service"
[30]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/fgac.html?utm_source=chatgpt.com "Fine-grained access control in Amazon OpenSearch Service - Amazon OpenSearch Service"
[31]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/ntn.html?utm_source=chatgpt.com "Node-to-node encryption for Amazon OpenSearch Service - Amazon OpenSearch Service"
[32]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/encryption-at-rest.html?utm_source=chatgpt.com "Encryption of data at rest for Amazon OpenSearch Service - Amazon OpenSearch Service"
[33]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/audit-logs.html?utm_source=chatgpt.com "Monitoring audit logs in Amazon OpenSearch Service - Amazon OpenSearch Service"
[34]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-snapshots.html "Creating index snapshots in Amazon OpenSearch Service - Amazon OpenSearch Service"
[35]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-snapshot-create.html?utm_source=chatgpt.com "Taking manual snapshots - Amazon OpenSearch Service"
[36]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-snapshot-restore.html?utm_source=chatgpt.com "Restoring data from snapshots"
[37]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-snapshot-mgmt.html?utm_source=chatgpt.com "Automating snapshots with Snapshot Management"
[38]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/replication.html "Cross-cluster replication for Amazon OpenSearch Service - Amazon OpenSearch Service"
[39]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-cloudwatchmetrics.html?utm_source=chatgpt.com "Monitoring OpenSearch cluster metrics with Amazon ..."
[40]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/cluster-insights.html?utm_source=chatgpt.com "Unified operational monitoring with Cluster Insights"
[41]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/auto-tune.html?utm_source=chatgpt.com "Auto-Tune for Amazon OpenSearch Service - Amazon OpenSearch Service"
[42]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-configuration-changes.html?utm_source=chatgpt.com "Making configuration changes in Amazon OpenSearch Service - Amazon OpenSearch Service"
[43]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/service-software.html?utm_source=chatgpt.com "Service software updates in Amazon OpenSearch Service - Amazon OpenSearch Service"
[44]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/version-migration.html?utm_source=chatgpt.com "Upgrading Amazon OpenSearch Service domains - Amazon OpenSearch Service"
[45]: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/dashboards-troubleshooting.html?utm_source=chatgpt.com "Troubleshooting OpenSearch Dashboards - Amazon OpenSearch Service"
