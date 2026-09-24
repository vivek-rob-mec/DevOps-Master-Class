# Gap assessment and progressive project plan

## What is already present

The catalog includes 34 projects spanning monoliths, microservices, language stacks, delivery, cloud foundations, security, data, and operations. [Module 17](../../17.%20System%20Design%20for%20DevOps%20%26%20SRE/Lesson%2017.1.md) already teaches requirements, measurable objectives, system models, and architecture decisions. Representative project HLDs include reliability and recovery considerations.

This assessment reviews the catalog, Project 34, and representative design/exercise documents. It is not an execution audit of all projects or an exhaustive reading of every lesson. A concept may already be described somewhere; the goal is to connect concepts into reproducible experiments with evidence.

| Area | Current coverage | What to add |
|---|---|---|
| Different languages | Five independent runtimes in Project 34 | One integrated mixed-stack business journey with explicit API/event compatibility |
| Architecture | Separate monolith and microservice examples | Evolve one domain and justify each boundary using measurements and requirements |
| Design | Module 17, HLD/LLD documents | Learner-authored predictions, alternatives, diagrams, and acceptance checks before each change |
| On-premises | Linux/networking material and deployment guidance | A connected VM lab covering processes, reverse proxy, DNS/TLS, firewall, storage, patching, and recovery |
| Multiple clouds | AWS assets and Azure/GCP foundation projects | Deploy the same contract to a second provider and compare actual platform differences |
| Hybrid | Multi-cluster networking material | A specific on-premises-to-cloud exercise covering routing, private DNS, link loss, and data authority |
| Stateful releases | Database projects and persistence examples | Migration, compatibility, application rollback, and isolated restore in the main learning sequence |
| Verification | Templates, exercises, and some recorded checks | A per-stage record distinguishing configuration rendering from live runtime/recovery evidence |
| Retention | Extensive lessons, workbooks, and interview prompts | Delayed recall, reconstruction, changed scenarios, and an error log |
| Portfolio presentation | Many project templates | One explained evolution with measurements, failed assumptions, and reproducible recovery |

## Separate the dimensions

| Dimension | Examples | Question |
|---|---|---|
| Runtime stack | React, Node, Python, Java, PostgreSQL | What executes and what dependencies does it require? |
| Architecture | Modular monolith, services, asynchronous workers | Where are responsibilities and data ownership boundaries? |
| Release environment | Dev, test, staging, production | Which users, data, and release rules apply? |
| Hosting | Laptop, on-premises, AWS, Azure, GCP | Who provides compute, network, identity, and storage? |
| Deployment mechanism | Native process, VM service, Compose, managed containers, Kubernetes | How does software start, update, scale, and recover? |
| Failure topology | Hosts, zones, regions, sites, clouds | Which failures must the system survive? |

A monolith can run on Kubernetes. Microservices can run on VMs. Five equivalent APIs in different languages are a packaging comparison, not an integrated mixed-stack system. Separate cloud templates do not demonstrate a connected multi-cloud system. Learn these dimensions individually before combining them.

## One continuing business application

Use a support-ticket platform as a proposed continuing domain, adapting [Node Helpdesk, Project 06](../projects/06-node-helpdesk-monolith/README.md). Node is a suggested starting implementation, not a recorded language preference. If another language is chosen, retain the domain and progression.

Begin with the ticket API and PostgreSQL in one deployable application. Add the browser journey. Deploy the same business behavior on Linux, in containers, and in Kubernetes. Later add a Python notification worker to learn cross-language event contracts. Notifications should go to a local sink, not real customers.

The worker introduces a queue, retries, idempotency, dead-letter handling, and consistency between the ticket transaction and event publication. Study an outbox or equivalent mechanism instead of assuming two separate writes succeed together. Extract a service only after identifying a reason such as independent scaling or release ownership; compare its operational cost with retaining a module in the monolith.

This is a proposed evolution. The worker and integration should not be assumed to exist in Project 06 today.

## Basic-to-advanced sequence

Advance when you can demonstrate the exit condition. Every stage uses the design worksheet.

| Stage | Understand first | Implement | Failure and exit evidence |
|---|---|---|---|
| 01. Request/process | HTTP, sockets, bind addresses, process lifecycle | One local API using [Lab 01](labs/01-request-to-process.md) | Distinguish HTTP 404 from connection failure; redraw the path |
| 02. Stateful monolith | Transactions, configuration, data ownership, migrations | One business API and PostgreSQL | Restart the application and prove committed data persists |
| 03. Native Linux deployment | Users, permissions, systemd, logs, proxy, DNS, TLS | Supervised service behind a reverse proxy in one VM | Diagnose wrong upstream port and stopped process; verify supervision |
| 04. On-premises simulation | Subnets, routes, firewall, disks, backups, failure domains | Separate application and database across small VMs | Prove allowed/denied traffic; restore data into an isolated target |
| 05. Containers | Images, processes, volumes, networks, runtime config | Package the same application with Compose | Diagnose bind/port/volume mistakes; prove non-root operation and persistence |
| 06. Delivery pipeline | Tests, artifacts, digests, scan, promotion, rollback | Apply [Project 34](../projects/34-standard-multistack-deployment/README.md) practices | Trace source to artifact; reject a bad candidate; restore a compatible release |
| 07. Kubernetes | Reconciliation, scheduling, Services, probes, resources, RBAC | One application in a small local cluster | Diagnose readiness/image-pull failures; explain rollout and capacity constraints |
| 08. Mixed-stack application | APIs, events, deadlines, retries, idempotency, consistency | Add a second-language worker and queue | Replay duplicate events, stop the worker, recover backlog, prove the invariant |
| 09. Portable deployment | Platform dependencies, state, identity, configuration | Compare native/Compose/Kubernetes placement locally | Document what changes and what remains in the common application contract |
| 10. One cloud, then a second | IAM, private networks, managed data, IaC state, cost | Optional later deployment to one provider, then another | Verify provider identity, recovery, and platform differences; label deferred work |
| 11. Hybrid/cross-site recovery | Address planning, DNS, WAN latency, replication, write authority | Local site/link simulation first; actual hybrid cloud later | Cut a lab link, measure recovery, explain failover and failback authority |
| 12. Operational defense | SLOs, telemetry, security, capacity, incidents, recovery | Integrate the system in a controlled incident exercise | Present release, diagnosis, restore, performance, and resource evidence |

Security, observability, and recovery begin in the earliest relevant stage. The final stage integrates them; it does not postpone them until the end. On a 16 GB laptop, run exercises sequentially and limit the topology rather than forcing every component to remain active.

For Stage 10, cloud deployment is optional until a budget and account controls are established. Local substitutes cannot validate cloud IAM, billing, quotas, managed-service behavior, or regional reliability. For Stage 11, multiple VMs on one host do not provide independent physical availability.

## Reuse the course selectively

| Stages | Relevant modules | Projects to draw from |
|---|---|---|
| 01–04 | 1 setup, 3 Linux/networking, 5 runtime, selected 17 design topics | 06 Node or 07 Python business application |
| 05–06 | 2 Git, 6 Docker, 7 registries, 8 CI, 9 security | 34 common delivery, 22 artifact trust |
| 07–08 | 10 Kubernetes, 11 troubleshooting, 14 GitOps, 17 distributed design | 03/06 architecture comparison, 14 workers |
| 09–11 | 12 IaC, 13 AWS, 17 system design | 24 Azure, 25 GCP, 28 networking, 30 database recovery |
| 12 | 15 observability, 16 SRE, 18 platform, 19 cost | 20 telemetry, 26 recovery, 29 cost, 31 delivery, 32 detection |

Read the relevant explanation and one worked example, perform the experiment, then return to deeper material when evidence exposes a gap. Large lessons are references; reading every page is not an entry condition.

## Design before each implementation

Write one page with the user journey, correctness rule, constraints, traffic assumption, latency/availability target, data owner, deployment view, trust boundaries, likely failure, alternative, and measurement. Mark unmeasured numbers as assumptions.

Use a context view for users/external dependencies, a container view for applications/data stores, and a deployment view for placement. The [C4 model](https://c4model.com/) provides this separation; its term container does not require a Docker container.

For each arrow, explain protocol, name resolution, port, identity, timeout, retry, and failure behavior. For each state store, explain ownership, durability, migration, backup, restore, and deletion. Deepen the explanation as stages advance.

## A portfolio that demonstrates judgment

Show a before/after architecture, a defended worker extraction, performance under a stated load, duplicate-message correctness, an isolated restore, a failed release and recovery, and a placement comparison. Provide scripts and sanitized evidence another learner can reproduce.

Maintain an assumptions log. An example entry might be: "Another replica did not improve throughput; the measured constraint was database connections." Record that only if the experiment actually supports it. Tool count, cloud count, and service count alone are not evidence of competence.
