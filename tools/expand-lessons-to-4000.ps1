param(
    [int]$MinimumLines = 4000,
    [int]$TargetLines = 4100,
    [int[]]$Modules = @(15, 16, 17, 18, 19, 20),
    [switch]$OnlyBelowMinimum,
    [switch]$WhatIfMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($TargetLines -lt $MinimumLines) {
    throw 'TargetLines must be greater than or equal to MinimumLines.'
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$startMarker = '<!-- GENERATED-MASTERY-WORKBOOK:START -->'
$endMarker = '<!-- GENERATED-MASTERY-WORKBOOK:END -->'

$levels = @(
    'Beginner',
    'Intermediate',
    'Expert',
    'Professional',
    'Industry-ready',
    'Certification review',
    'Interview defense'
)

$lenses = @(
    'correctness',
    'availability',
    'latency',
    'capacity',
    'security',
    'privacy',
    'cost efficiency',
    'delivery safety',
    'operability',
    'recovery',
    'multi-tenancy',
    'data integrity',
    'change management',
    'observability',
    'automation safety',
    'dependency failure',
    'regional resilience',
    'governance',
    'developer experience',
    'business value'
)

$environments = @(
    'a disposable local lab',
    'an isolated CI environment',
    'a shared nonproduction cluster',
    'a production canary with an approved change window',
    'peak traffic with bounded synthetic load',
    'a one-zone-loss exercise',
    'a dependency brownout exercise',
    'an operator handoff',
    'a security and audit review',
    'a regional recovery tabletop'
)

function Get-ModuleProfile {
    param([int]$Module)

    switch ($Module) {
        14 {
            return @{
                Artifacts = @(
                    'an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence',
                    'a Git promotion commit, pull-request review, sync result, and rollback record',
                    'a Helm or Kustomize render, schema validation, diff, and environment comparison',
                    'a sync-wave, resource-hook, or progressive-delivery execution and health report',
                    'a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle',
                    'an Argo CD metrics, notification, incident timeline, and troubleshooting record'
                )
                Failures = @(
                    'introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence',
                    'simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path',
                    'break repository authentication, manifest rendering, a required CRD, or destination selection',
                    'make a sync hook, health check, canary analysis, or rollback condition fail safely',
                    'remove one cluster, API server, repo-server, cache, or controller dependency',
                    'test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration'
                )
                Certification = 'Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.'
            }
        }
        15 {
            return @{
                Artifacts = @(
                    'a PromQL, LogQL, or TraceQL investigation',
                    'an OpenTelemetry Collector pipeline and validation report',
                    'a dashboard, recording rule, alert, and runbook',
                    'a telemetry schema and cardinality budget',
                    'an end-to-end signal and notification canary',
                    'a metrics-to-trace-to-log correlation record'
                )
                Failures = @(
                    'inject a scrape, discovery, or label mismatch',
                    'block a telemetry exporter and observe the bounded queue',
                    'introduce malformed or high-cardinality telemetry',
                    'remove trace-context propagation at one boundary',
                    'delay storage or query availability',
                    'make the notification receiver reject a synthetic test'
                )
                Certification = 'Map the result to the current Prometheus or OpenTelemetry objectives and state which behavior was proved.'
            }
        }
        16 {
            return @{
                Artifacts = @(
                    'an exact SLI/SLO and error-budget decision record',
                    'an executable runbook and peer-test report',
                    'an incident timeline, change ledger, and status update',
                    'a toil inventory and bounded automation review',
                    'a capacity, risk, and failure-domain model',
                    'a restore, RTO, RPO, and integrity report'
                )
                Failures = @(
                    'inject a symptom that has two plausible causes',
                    'remove one page-delivery or diagnostic dependency',
                    'create a retry-amplified dependency brownout',
                    'make a runbook precondition false',
                    'remove one node, zone, or recovery dependency',
                    'introduce a misleading dashboard or incomplete timeline'
                )
                Certification = 'Relate the result to current SRE, cloud reliability, Kubernetes, or incident-management objectives without claiming an exam guarantee.'
            }
        }
        17 {
            return @{
                Artifacts = @(
                    'a requirement, invariant, and architecture decision record',
                    'a capacity, latency, storage, and bandwidth calculation',
                    'an API, data, or event contract with failure semantics',
                    'a context, data-flow, trust, and failure-domain diagram',
                    'a load-test and graceful-degradation report',
                    'a multi-region failover and failback state machine'
                )
                Failures = @(
                    'introduce a timeout and retry amplification path',
                    'create a hot key, partition, cache, or queue condition',
                    'remove a shared dependency or one failure domain',
                    'make data arrive duplicated, late, or out of order',
                    'overload the system beyond its modeled queueing knee',
                    'make a regional writer or routing decision ambiguous'
                )
                Certification = 'Map the design evidence to the current cloud architecture, DevOps, or Kubernetes objectives and defend the trade-off provider-neutrally.'
            }
        }
        18 {
            return @{
                Artifacts = @(
                    'a platform capability canvas and user-journey baseline',
                    'a versioned capability API with conditions and lifecycle',
                    'a golden-path template and upgrade test',
                    'a catalog, ownership, scorecard, and documentation record',
                    'a tenant baseline with adversarial isolation evidence',
                    'a developer-experience study and platform SLO report'
                )
                Failures = @(
                    'stop a provider after partial self-service provisioning',
                    'attempt cross-tenant or privilege escalation',
                    'break a shared workflow or template version',
                    'make the portal or control plane unavailable',
                    'make policy or secret delivery partially unavailable',
                    'attempt deletion while retention or ownership is unclear'
                )
                Certification = 'Relate the artifact to the current platform-engineering, Kubernetes, GitOps, or supply-chain objectives and identify the product outcome.'
            }
        }
        19 {
            return @{
                Artifacts = @(
                    'a reconciled allocation and data-quality report',
                    'a budget, forecast, variance, and anomaly record',
                    'a rightsizing or scheduling experiment with guardrails',
                    'a Kubernetes, storage, network, or telemetry cost model',
                    'a commitment scenario with utilization and coverage',
                    'a unit-economics and realized-savings analysis'
                )
                Failures = @(
                    'inject a billing delay or allocation-quality defect',
                    'create an unexpected usage or unit-cost anomaly',
                    'make an optimization violate an SLO or recovery reserve',
                    'shift cost to another team, region, or shared service',
                    'interrupt discounted capacity and measure repeated work',
                    'make a forecast assumption or commitment demand disappear'
                )
                Certification = 'Map the decision to the current FinOps Framework or certification objectives and separate estimate, implementation, and realized outcome.'
            }
        }
        20 {
            return @{
                Artifacts = @(
                    'a traceable requirement, ADR, implementation, and test record',
                    'a Terraform, EKS, GitOps, and identity validation bundle',
                    'an idempotency, outbox, migration, and data-integrity report',
                    'a supply-chain, provenance, admission, and runtime record',
                    'an SLO investigation, incident, restore, and game-day report',
                    'a platform journey, allocation, unit-cost, and portfolio artifact'
                )
                Failures = @(
                    'combine a bad release with a dependency brownout',
                    'remove a zone while capacity or rollout is constrained',
                    'break telemetry and the primary page path together',
                    'make CI, GitOps, policy, or secret evidence unavailable',
                    'introduce a regional data-authority and routing conflict',
                    'create a cost anomaly while a customer SLO is at risk'
                )
                Certification = 'Trace the evidence to the latest selected certification objective and explain what remains simulated, assumed, or unproved.'
            }
        }
        default {
            throw "Unsupported module: $Module"
        }
    }
}

function Remove-GeneratedWorkbook {
    param([string[]]$Lines)

    $start = [Array]::IndexOf($Lines, $startMarker)
    if ($start -lt 0) {
        return ,$Lines
    }

    $finish = [Array]::IndexOf($Lines, $endMarker)
    if ($finish -lt $start) {
        throw 'A generated workbook start marker exists without a matching end marker.'
    }

    $result = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($index -lt $start -or $index -gt $finish) {
            $result.Add($Lines[$index])
        }
    }

    return ,$result.ToArray()
}

function Get-Concepts {
    param(
        [string[]]$Lines,
        [int]$Module,
        [int]$Lesson
    )

    $headingPatterns = @("^# $Module\.$Lesson\.(\d+)\s+(.+)$")
    if ($Module -eq 14) {
        $headingPatterns += "^#\s+$Module\.(\d+)\s+(.+)$"
        $headingPatterns += '^#\s+(\d+)\.\s+(.+)$'
    }
    $headings = [System.Collections.Generic.List[object]]::new()

    foreach ($headingPattern in $headingPatterns) {
        for ($index = 0; $index -lt $Lines.Count; $index++) {
            if ($Lines[$index] -match $headingPattern) {
                $headings.Add([pscustomobject]@{
                        Index = $index
                        Number = [int]$Matches[1]
                        Name = $Matches[2].Trim()
                    })
            }
        }
        if ($headings.Count -gt 0) {
            break
        }
    }

    $concepts = [System.Collections.Generic.List[object]]::new()
    for ($headingIndex = 0; $headingIndex -lt $headings.Count; $headingIndex++) {
        $heading = $headings[$headingIndex]
        $blockEnd = if ($headingIndex + 1 -lt $headings.Count) {
            $headings[$headingIndex + 1].Index - 1
        }
        else {
            $Lines.Count - 1
        }

        $anchorParts = [System.Collections.Generic.List[string]]::new()
        for ($lineIndex = $heading.Index + 1; $lineIndex -le $blockEnd; $lineIndex++) {
            $candidate = $Lines[$lineIndex].Trim()
            if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
            if ($candidate.StartsWith('#')) { continue }
            if ($candidate.StartsWith('```')) { continue }
            if ($candidate.StartsWith('|')) { continue }
            if ($candidate -match '^\[\d+\]:') { continue }
            if ($candidate -match '^[-*]\s+') { continue }
            if ($candidate -match '^\d+\.\s+') { continue }
            $anchorParts.Add(($candidate -replace '[`*_>#]', '').Trim())
            if (($anchorParts -join ' ').Length -ge 220) { break }
        }

        $anchor = ($anchorParts -join ' ').Trim()
        if ([string]::IsNullOrWhiteSpace($anchor)) {
            $anchor = "The lesson establishes $($heading.Name) as a concept that must be explained, implemented, tested, and defended."
        }
        if ($anchor.Length -gt 260) {
            $anchor = $anchor.Substring(0, 257).TrimEnd() + '...'
        }

        $concepts.Add([pscustomobject]@{
                Number = $heading.Number
                Name = $heading.Name
                Anchor = $anchor
            })
    }

    if ($concepts.Count -eq 0) {
        $concepts.Add([pscustomobject]@{
                Number = 1
                Name = 'Lesson purpose and production application'
                Anchor = 'Explain the lesson from first principles, then prove it through safe implementation, failure testing, and operational evidence.'
            })
    }

    return ,$concepts.ToArray()
}

function Add-WorkbookIntroduction {
    param(
        [System.Collections.Generic.List[string]]$Workbook,
        [int]$Module,
        [int]$Lesson,
        [int]$SectionNumber,
        [string]$Title,
        [int]$ConceptCount
    )

    $Workbook.Add($startMarker)
    $Workbook.Add('')
    $Workbook.Add("# $Module.$Lesson.$SectionNumber Professional Mastery Workbook")
    $Workbook.Add('')
    $Workbook.Add("This workbook expands **$Title** into deliberate practice without replacing the authored tutorial above.")
    $Workbook.Add('')
    $Workbook.Add('Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.')
    $Workbook.Add('')
    $Workbook.Add('## Workbook learning contract')
    $Workbook.Add('')
    $Workbook.Add("- Concepts covered: $ConceptCount lesson-specific anchors.")
    $Workbook.Add('- Progression: beginner, intermediate, expert, professional, industry-ready, certification review, and interview defense.')
    $Workbook.Add('- Safety: use synthetic data, disposable resources, explicit placeholders, least privilege, and bounded failure experiments.')
    $Workbook.Add('- Completion: retain commands or configuration, observations, screenshots or query output, decisions, rollback evidence, and a short reflection.')
    $Workbook.Add('- Quality rule: a passing answer states assumptions, protects a user or business outcome, names ownership, and validates the final result end to end.')
    $Workbook.Add('- Currency rule: verify current official documentation, versions, limits, pricing, and certification objectives before relying on changing product behavior.')
    $Workbook.Add('')
    $Workbook.Add('## Seven-stage progression')
    $Workbook.Add('')
    $Workbook.Add('| Stage | Learner must demonstrate |')
    $Workbook.Add('|---|---|')
    $Workbook.Add('| Beginner | Explain the concept in plain language and give one safe example. |')
    $Workbook.Add('| Intermediate | Connect components, data, control flow, and normal operating behavior. |')
    $Workbook.Add('| Expert | Analyze trade-offs, edge cases, scaling pressure, and correlated failures. |')
    $Workbook.Add('| Professional | Make a reviewed decision with owner, evidence, rollout, and rollback. |')
    $Workbook.Add('| Industry-ready | Operate the design under security, failure, recovery, cost, and compliance constraints. |')
    $Workbook.Add('| Certification review | Map durable concepts to the latest official objectives without relying on stale wording. |')
    $Workbook.Add('| Interview defense | Answer concisely, clarify assumptions, draw the model, and defend alternatives. |')
    $Workbook.Add('')
}

function Add-ConceptCards {
    param(
        [System.Collections.Generic.List[string]]$Workbook,
        [object[]]$Concepts,
        [hashtable]$Profile
    )

    $Workbook.Add('## Concept mastery cards')
    $Workbook.Add('')

    for ($index = 0; $index -lt $Concepts.Count; $index++) {
        $concept = $Concepts[$index]
        $artifact = $Profile.Artifacts[$index % $Profile.Artifacts.Count]
        $failure = $Profile.Failures[$index % $Profile.Failures.Count]
        $cardNumber = $index + 1

        $Workbook.Add("### Concept card $cardNumber - $($concept.Name)")
        $Workbook.Add('')
        $Workbook.Add("- Lesson anchor: $($concept.Anchor)")
        $Workbook.Add("- Beginner explanation: Restate **$($concept.Name)** using a household, workplace, or public-service analogy without hiding the technical truth.")
        $Workbook.Add('- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.')
        $Workbook.Add("- Concrete example: Apply **$($concept.Name)** to a small todo, checkout, or platform service and name the expected outcome.")
        $Workbook.Add('- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.')
        $Workbook.Add('- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.')
        $Workbook.Add('- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.')
        $Workbook.Add("- Hands-on artifact: Produce $artifact focused on **$($concept.Name)**.")
        $Workbook.Add("- Failure exercise: In an isolated environment, $failure while observing the boundaries around **$($concept.Name)**.")
        $Workbook.Add('- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.')
        $Workbook.Add('- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.')
        $Workbook.Add('- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.')
        $Workbook.Add('- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.')
        $Workbook.Add('- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.')
        $Workbook.Add("- Certification checkpoint: $($Profile.Certification)")
        $Workbook.Add("- Interview prompt: Explain **$($concept.Name)** first in 30 seconds, then defend it in a five-minute system scenario.")
        $Workbook.Add('- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.')
        $Workbook.Add('- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.')
        $Workbook.Add('')
    }
}

function Add-ScenarioDrill {
    param(
        [System.Collections.Generic.List[string]]$Workbook,
        [int]$DrillNumber,
        [object]$PrimaryConcept,
        [object]$SecondaryConcept,
        [string]$Level,
        [string]$Lens,
        [string]$Environment,
        [string]$Artifact,
        [string]$Failure,
        [string]$Certification
    )

    $id = $DrillNumber.ToString('000')
    $Workbook.Add("### Practice case $id - $($PrimaryConcept.Name) x $Lens")
    $Workbook.Add('')
    $Workbook.Add("- Learning level: $Level.")
    $Workbook.Add("- Environment: $Environment.")
    $Workbook.Add("- Scenario: The team must apply **$($PrimaryConcept.Name)** while a change involving **$($SecondaryConcept.Name)** places **$Lens** at risk.")
    $Workbook.Add("- Plain-language question: What problem does **$($PrimaryConcept.Name)** solve here, and who notices first when it fails?")
    $Workbook.Add("- Lesson evidence anchor: $($PrimaryConcept.Anchor)")
    $Workbook.Add("- Objective: Preserve a measurable user or business outcome while making the $Lens decision explicit.")
    $Workbook.Add('- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.')
    $Workbook.Add('- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.')
    $Workbook.Add("- Hands-on build: Produce $Artifact and link it to this practice case ID.")
    $Workbook.Add('- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.')
    $Workbook.Add('- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.')
    $Workbook.Add("- Failure injection: $Failure.")
    $Workbook.Add('- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.')
    $Workbook.Add('- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.')
    $Workbook.Add('- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.')
    $Workbook.Add('- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.')
    $Workbook.Add('- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.')
    $Workbook.Add('- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.')
    $Workbook.Add('- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.')
    $Workbook.Add('- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.')
    $Workbook.Add("- Certification checkpoint: $Certification")
    $Workbook.Add("- Interview prompt: Defend **$($PrimaryConcept.Name)** against an alternative while protecting $Lens under this scenario.")
    $Workbook.Add('- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.')
    $Workbook.Add('- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.')
    $Workbook.Add('- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.')
    $Workbook.Add('')
}

function Get-LessonVisuals {
    param([int]$Lesson)

    switch ($Lesson) {
        1 {
            return @(
                @{ Title='Requirement funnel'; Memory='WHO - WHAT - HOW WELL - LIMITS'; Read='Start with people and journeys, then quality attributes and hard constraints, before selecting architecture.'; Lines=@('flowchart TB','    A["Actors and business outcome"] --> B["Critical user journeys"]','    B --> C["Functional requirements"]','    C --> D["Quality attributes and SLOs"]','    D --> E["Constraints and non-goals"]','    E --> F["Architecture decisions"]','    F --> G["Measurable acceptance evidence"]') },
                @{ Title='System context and trust boundary'; Memory='People outside, system inside, trust at every arrow'; Read='The boundary makes external actors, dependencies, data movement, and trust decisions visible.'; Lines=@('flowchart LR','    User["Customer"] -->|"HTTPS + identity"| System["Order platform"]','    Operator["Operator"] -->|"Privileged workflow"| System','    System -->|"Payment request"| Payment["Payment provider"]','    System -->|"Events"| Fulfillment["Fulfillment partner"]','    System -->|"Telemetry"| Observe["Observability platform"]','    subgraph TrustBoundary["Owned trust boundary"]','        System','    end') },
                @{ Title='Critical journey sequence'; Memory='Accept - Validate - Decide - Persist - Confirm'; Read='A sequence diagram exposes ordering, synchronous latency, authoritative writes, and failure boundaries.'; Lines=@('sequenceDiagram','    actor U as User','    participant A as API','    participant D as Domain service','    participant S as State store','    participant E as Event publisher','    U->>A: Submit command','    A->>D: Validate identity and intent','    D->>S: Commit invariant-preserving state','    S-->>D: Durable result','    D->>E: Publish outcome','    D-->>A: Stable response','    A-->>U: Confirmation') },
                @{ Title='Assumption-to-decision loop'; Memory='Assume - Measure - Decide - Prove - Revisit'; Read='Unverified assumptions become explicit experiments and architecture decisions with revisit triggers.'; Lines=@('flowchart LR','    A["Assumption"] --> B["Risk if wrong"]','    B --> C["Cheapest useful measurement"]','    C --> D{"Evidence sufficient?"}','    D -->|"No"| C','    D -->|"Yes"| E["ADR decision"]','    E --> F["Implementation and test"]','    F --> G["Production evidence"]','    G --> H{"Trigger changed?"}','    H -->|"Yes"| A','    H -->|"No"| I["Keep decision"]') }
            )
        }
        2 {
            return @(
                @{ Title='Workload estimation chain'; Memory='Rate x Time = Volume'; Read='Translate business traffic into storage, bandwidth, concurrency, and compute before choosing instance counts.'; Lines=@('flowchart LR','    A["Users and actions"] --> B["Requests per second"]','    B --> C["Peak and skew multiplier"]','    C --> D["Concurrency = rate x latency"]','    C --> E["Bandwidth = rate x payload"]','    C --> F["Storage = writes x size x retention"]','    D --> G["CPU and memory capacity"]','    E --> H["Network capacity"]','    F --> I["Storage and IOPS capacity"]','    G --> J["Headroom and failure reserve"]','    H --> J','    I --> J') },
                @{ Title='End-to-end latency budget'; Memory='Total latency is the sum of every wait'; Read='Allocate the user objective across network, compute, storage, queues, and retry reserve.'; Lines=@('flowchart LR','    U["User budget 300 ms"] --> N1["Edge 25 ms"]','    N1 --> G["Gateway 15 ms"]','    G --> S["Service 60 ms"]','    S --> D["Database 80 ms"]','    D --> Q["Queue or dependency 40 ms"]','    Q --> R["Retry and variance reserve 80 ms"]','    R --> V{"Sum within 300 ms?"}') },
                @{ Title='Queueing knee and overload'; Memory='Near saturation, waiting grows faster than work'; Read='The safe operating point stays below the queueing knee and sheds load before collapse.'; Lines=@('flowchart TB','    D["Demand"] --> Q["Queue"]','    Q --> W["Workers"]','    W --> O["Completed outcomes"]','    D --> U{"Utilization near limit?"}','    U -->|"No"| S["Stable latency"]','    U -->|"Yes"| L["Queue and latency rise"]','    L --> T["Timeouts and retries"]','    T --> D','    L --> P["Shed, degrade, or add capacity"]') },
                @{ Title='Capacity feedback loop'; Memory='Measure - Predict - Provision - Verify'; Read='Scaling is a controlled loop with lag, limits, cost, and post-scale verification.'; Lines=@('flowchart LR','    M["Demand and saturation signals"] --> P["Forecast required capacity"]','    P --> C["Apply policy and limits"]','    C --> A["Add or remove capacity"]','    A --> W["Warm up and rebalance"]','    W --> V["Verify user SLO and cost"]','    V --> M','    C --> F["Failure reserve"]','    F --> V') }
            )
        }
        3 {
            return @(
                @{ Title='Request path from name to service'; Memory='Name - Secure - Route - Balance - Serve'; Read='Follow the client request through DNS, edge controls, gateway policy, load balancing, and service discovery.'; Lines=@('flowchart LR','    C["Client"] --> DNS["DNS"]','    DNS --> CDN["CDN or edge"]','    CDN --> WAF["WAF and TLS"]','    WAF --> GW["API gateway"]','    GW --> LB["Load balancer"]','    LB --> S1["Service instance A"]','    LB --> S2["Service instance B"]','    S1 --> D["Dependency"]','    S2 --> D') },
                @{ Title='API call with timeout ownership'; Memory='Contract first, timeout always, retry only if safe'; Read='The sequence shows authentication, validation, deadlines, stable errors, and idempotent retry ownership.'; Lines=@('sequenceDiagram','    actor C as Client','    participant G as Gateway','    participant S as Service','    participant D as Dependency','    C->>G: Request + identity + idempotency key','    G->>G: Authenticate and authorize','    G->>S: Validated request + deadline','    S->>D: Bounded call','    alt dependency succeeds','        D-->>S: Valid response','        S-->>C: Stable success','    else timeout or overload','        S-->>C: Stable retryable error','    end') },
                @{ Title='Load-balancing decision tree'; Memory='Health, locality, load, stickiness'; Read='Selection begins with healthy eligible endpoints, then applies locality, load, and session constraints.'; Lines=@('flowchart TB','    A["Incoming request"] --> H{"Healthy endpoints?"}','    H -->|"No"| F["Fail fast or degrade"]','    H -->|"Yes"| L{"Locality required?"}','    L -->|"Yes"| Z["Prefer local zone or region"]','    L -->|"No"| P["All eligible endpoints"]','    Z --> S{"Session affinity needed?"}','    P --> S','    S -->|"Yes"| K["Consistent hash"]','    S -->|"No"| R["Least load or round robin"]') },
                @{ Title='Network failure containment'; Memory='Bound - Isolate - Observe - Recover'; Read='Every remote call receives a deadline, bounded retry, isolation, telemetry, and an explicit fallback or error.'; Lines=@('flowchart LR','    A["Remote call"] --> T["Timeout budget"]','    T --> R{"Safe to retry?"}','    R -->|"Yes"| B["Backoff + jitter + attempt cap"]','    R -->|"No"| E["Stable error"]','    B --> I["Bulkhead or concurrency limit"]','    I --> C["Circuit state"]','    C --> F["Fallback or fail"]','    F --> O["Metrics, trace, and log"]','    O --> V["Recovery validation"]') }
            )
        }
        4 {
            return @(
                @{ Title='Storage choice from access pattern'; Memory='Pattern before product'; Read='Work backward from keys, queries, transactions, scale, and recovery instead of naming a fashionable database.'; Lines=@('flowchart TB','    A["Access patterns"] --> T{"Multi-row transactions?"}','    T -->|"Yes"| R["Relational candidate"]','    T -->|"No"| K{"Key-value access?"}','    K -->|"Yes"| KV["Key-value candidate"]','    K -->|"No"| Q{"Document, graph, search, or time series?"}','    Q --> S["Specialized candidate"]','    R --> V["Validate scale, recovery, and skill"]','    KV --> V','    S --> V') },
                @{ Title='Partition routing and hot-key risk'; Memory='The key decides placement and pain'; Read='A routing layer maps a partition key to shards; skew and resharding must be visible before production.'; Lines=@('flowchart LR','    W["Write or read"] --> K["Extract partition key"]','    K --> H["Hash or range router"]','    H --> S1["Shard 1"]','    H --> S2["Shard 2"]','    H --> S3["Shard 3"]','    K --> X{"Skew or hot key?"}','    X -->|"Yes"| M["Split, salt, isolate, or redesign key"]','    M --> H') },
                @{ Title='Consistency and replication path'; Memory='Acknowledge only what the promise requires'; Read='The acknowledgement point determines durability, latency, failover loss, and what readers may observe.'; Lines=@('sequenceDiagram','    actor C as Client','    participant L as Leader','    participant F1 as Follower A','    participant F2 as Follower B','    C->>L: Write invariant','    L->>L: Validate and append','    par Replicate','        L->>F1: Log entry','        L->>F2: Log entry','    end','    F1-->>L: Ack','    L-->>C: Commit acknowledgement','    C->>F2: Read','    F2-->>C: Value or documented staleness') },
                @{ Title='Expand-migrate-contract schema change'; Memory='Add - Move - Verify - Remove'; Read='Compatibility is maintained while old and new application versions overlap.'; Lines=@('stateDiagram-v2','    [*] --> Expand','    Expand --> DualCompatible: additive schema deployed','    DualCompatible --> Migrate: mixed versions safe','    Migrate --> Verify: data backfill complete','    Verify --> Contract: integrity and usage proved','    Contract --> Cleanup: old readers and writers removed','    Cleanup --> [*]','    Verify --> Rollback: verification fails','    Rollback --> DualCompatible') }
            )
        }
        5 {
            return @(
                @{ Title='Cache hierarchy'; Memory='Nearer is faster but easier to stale'; Read='Each cache layer needs separate ownership, key, freshness, capacity, and bypass behavior.'; Lines=@('flowchart LR','    U["User"] --> B["Browser cache"]','    B --> E["CDN edge"]','    E --> G["Gateway cache"]','    G --> A["Application cache"]','    A --> D["Authoritative data store"]','    D --> A','    A --> G','    G --> E','    E --> B','    B --> U') },
                @{ Title='Cache-aside read path'; Memory='Look - Miss - Load - Store - Return'; Read='The application owns cache misses and must bound stampedes, stale values, and authoritative-store failures.'; Lines=@('sequenceDiagram','    actor C as Client','    participant A as Application','    participant K as Cache','    participant D as Database','    C->>A: Read key','    A->>K: Get key','    alt cache hit','        K-->>A: Cached value','    else cache miss','        A->>D: Read authoritative value','        D-->>A: Value','        A->>K: Set value with TTL','    end','    A-->>C: Response') },
                @{ Title='Invalidation state machine'; Memory='Fresh - Stale - Refresh - Fresh'; Read='Treat freshness as explicit state, including refresh failure and safe stale serving.'; Lines=@('stateDiagram-v2','    [*] --> Fresh','    Fresh --> Stale: TTL or source change','    Stale --> Refreshing: first eligible reader or event','    Refreshing --> Fresh: validated replacement','    Refreshing --> StaleAllowed: source unavailable and policy allows','    StaleAllowed --> Refreshing: retry window','    Stale --> Miss: stale serving forbidden','    Miss --> Fresh: source read succeeds') },
                @{ Title='Stampede protection'; Memory='One loader, many waiters, bounded stale fallback'; Read='Request coalescing prevents a popular expired key from multiplying backend load.'; Lines=@('flowchart TB','    R["Many requests for one key"] --> M{"Fresh cache entry?"}','    M -->|"Yes"| H["Return hit"]','    M -->|"No"| L{"Loader already active?"}','    L -->|"Yes"| W["Wait, serve bounded stale, or reject"]','    L -->|"No"| O["Acquire single-flight ownership"]','    O --> D["Load authoritative value"]','    D --> C["Populate cache"]','    C --> H','    D -->|"Failure"| W') }
            )
        }
        6 {
            return @(
                @{ Title='Event pipeline and ownership'; Memory='Produce - Persist - Deliver - Process - Prove'; Read='The diagram separates producer state, broker durability, consumer work, and observable business outcome.'; Lines=@('flowchart LR','    P["Producer"] --> O["Transactional outbox"]','    O --> X["Publisher"]','    X --> B["Broker or stream"]','    B --> C1["Consumer group A"]','    B --> C2["Consumer group B"]','    C1 --> S1["Consumer state"]','    C2 --> S2["Consumer state"]','    C1 --> D["Outcome telemetry"]','    C2 --> D') },
                @{ Title='Transactional outbox sequence'; Memory='Commit state and intent together'; Read='The outbox removes the unsafe gap between a database commit and message publication.'; Lines=@('sequenceDiagram','    actor U as Caller','    participant S as Service','    participant DB as Database','    participant P as Outbox publisher','    participant B as Broker','    U->>S: Command','    S->>DB: Transaction: business row + outbox row','    DB-->>S: Commit','    S-->>U: Accepted outcome','    P->>DB: Read unpublished outbox rows','    P->>B: Publish event with stable ID','    B-->>P: Ack','    P->>DB: Mark published idempotently') },
                @{ Title='Consumer delivery state'; Memory='Receive - Deduplicate - Apply - Ack'; Read='Acknowledgement happens only after idempotent outcome state is durable.'; Lines=@('stateDiagram-v2','    [*] --> Received','    Received --> DuplicateCheck','    DuplicateCheck --> AlreadyDone: event ID exists','    DuplicateCheck --> Processing: new event','    Processing --> Committed: state and inbox record durable','    Processing --> Retry: transient failure','    Retry --> Processing: bounded backoff','    Retry --> Quarantine: attempts exhausted','    AlreadyDone --> Acknowledged','    Committed --> Acknowledged','    Acknowledged --> [*]') },
                @{ Title='Backpressure and slow-consumer control'; Memory='If arrival exceeds service, the queue must grow or demand must fall'; Read='Bound the queue and choose scale, throttle, degrade, or reject before resource exhaustion.'; Lines=@('flowchart LR','    A["Arrival rate"] --> Q["Bounded queue"]','    Q --> W["Consumer capacity"]','    W --> O["Completed outcomes"]','    Q --> D{"Depth or age high?"}','    D -->|"No"| M["Continue and measure"]','    D -->|"Yes"| S["Scale consumers"]','    D -->|"Yes"| T["Throttle producers"]','    D -->|"Yes"| G["Degrade or reject"]','    S --> D','    T --> D','    G --> D') }
            )
        }
        7 {
            return @(
                @{ Title='Failure-domain-aware redundancy'; Memory='Replicas help only when they do not fail together'; Read='Spread capacity across independent domains and keep enough reserve to survive the declared loss.'; Lines=@('flowchart TB','    R["Regional service"] --> Z1["Zone A"]','    R --> Z2["Zone B"]','    R --> Z3["Zone C"]','    Z1 --> N1["Replicas"]','    Z2 --> N2["Replicas"]','    Z3 --> N3["Replicas"]','    Z1 --> D1["Independent data path"]','    Z2 --> D2["Independent data path"]','    Z3 --> D3["Independent data path"]','    F["Capacity after one-zone loss"] --> R') },
                @{ Title='Graceful degradation ladder'; Memory='Protect the core, shed the optional'; Read='Features are disabled in a planned order so the critical journey survives overload or dependency failure.'; Lines=@('flowchart TB','    A["Healthy: all features"] --> B["Remove recommendations"]','    B --> C["Serve cached or partial reads"]','    C --> D["Delay asynchronous enrichment"]','    D --> E["Protect critical writes"]','    E --> F["Admission control"]','    F --> G["Fail fast with recovery guidance"]','    S["SLO and saturation signals"] --> A','    S --> B','    S --> C','    S --> D','    S --> E') },
                @{ Title='Circuit-breaker states'; Memory='Closed works, open protects, half-open tests'; Read='The breaker contains repeated remote failure but still needs bounded probes and user-visible fallback.'; Lines=@('stateDiagram-v2','    [*] --> Closed','    Closed --> Open: failure threshold reached','    Open --> HalfOpen: cool-down expires','    HalfOpen --> Closed: bounded probes succeed','    HalfOpen --> Open: probe fails','    Open --> Open: fail fast or fallback','    Closed --> Closed: successful calls') },
                @{ Title='Autoscaling with safety limits'; Memory='Signal - Decide - Add - Warm - Verify'; Read='Scaling includes delayed measurement, provisioning, warm-up, stabilization, cost limits, and failure reserve.'; Lines=@('flowchart LR','    D["Demand"] --> S["User and saturation signals"]','    S --> P["Scaling policy"]','    P --> L["Min, max, and rate limits"]','    L --> C["Capacity change"]','    C --> W["Warm and rebalance"]','    W --> V["Verify SLO and cost"]','    V --> S','    F["Failure reserve"] --> P') }
            )
        }
        8 {
            return @(
                @{ Title='Active-passive regional topology'; Memory='One serves, one prepares, both are tested'; Read='Traffic, replication, promotion authority, DNS behavior, and recovery capacity are all explicit.'; Lines=@('flowchart LR','    U["Global users"] --> G["Global routing"]','    G -->|"Active"| R1["Region A services"]','    G -.->|"Standby"| R2["Region B services"]','    R1 --> D1["Authoritative data A"]','    D1 -->|"Replicate"| D2["Recoverable data B"]','    C["Failover controller and human authority"] --> G','    C --> D2','    R2 --> D2') },
                @{ Title='Active-active with data authority'; Memory='Route globally, own writes explicitly'; Read='Active-active compute is safe only when writer authority, conflict rules, and replication behavior are defined.'; Lines=@('flowchart TB','    U["Users"] --> G["Global router"]','    G --> A["Region A"]','    G --> B["Region B"]','    A --> WA["Write authority A"]','    B --> WB["Write authority B"]','    WA <-->|"Replication + conflict policy"| WB','    A --> RA["Local reads"]','    B --> RB["Local reads"]','    F["Fencing and ownership service"] --> WA','    F --> WB') },
                @{ Title='Disaster-recovery timeline'; Memory='Detect - Decide - Recover - Validate - Communicate'; Read='RTO measures elapsed recovery time; RPO measures acceptable data loss or replay gap.'; Lines=@('flowchart LR','    I["Incident begins"] --> D["Detect and classify"]','    D --> A["Authorize recovery"]','    A --> P["Promote platform and dependencies"]','    P --> R["Restore or replay data"]','    R --> V["Validate integrity and user journey"]','    V --> T["Shift traffic"]','    T --> C["Communicate and monitor"]','    I -. RTO clock .-> T','    B["Last recoverable point"] -. RPO gap .-> I') },
                @{ Title='Failover and failback state machine'; Memory='Failback is another risky migration'; Read='The return path waits for stability, data convergence, authority transfer, controlled traffic, and final proof.'; Lines=@('stateDiagram-v2','    [*] --> Primary','    Primary --> Degraded: regional fault','    Degraded --> FailoverAuthorized: criteria met','    FailoverAuthorized --> SecondaryActive: authority fenced and traffic moved','    SecondaryActive --> Converging: original region recovers','    Converging --> FailbackReady: data and dependencies validated','    FailbackReady --> ControlledFailback','    ControlledFailback --> Primary: user journey and integrity proved','    Degraded --> Primary: fault contained without failover') }
            )
        }
        9 {
            return @(
                @{ Title='Zero-trust request path'; Memory='Authenticate, authorize, encrypt, and audit every boundary'; Read='Network location alone grants no trust; identity and resource-level policy travel with the request.'; Lines=@('flowchart LR','    U["User or workload identity"] --> I["Identity provider"]','    I --> G["Gateway policy"]','    G --> S["Service authorization"]','    S --> D["Data authorization"]','    U -.->|"TLS"| G','    G -.->|"mTLS or signed identity"| S','    S -.->|"Encrypted connection"| D','    G --> A["Audit events"]','    S --> A','    D --> A') },
                @{ Title='Telemetry correlation path'; Memory='One journey, one correlation story'; Read='Metrics locate impact, traces follow boundaries, logs explain events, and change markers supply context.'; Lines=@('flowchart TB','    R["User request"] --> S1["Service A span"]','    S1 --> S2["Service B span"]','    S2 --> D["Database span"]','    S1 --> M["Outcome metrics"]','    S2 --> M','    S1 --> L["Structured logs"]','    S2 --> L','    D --> L','    C["Deployment and config markers"] --> M','    C --> L','    M --> X["Correlated investigation"]','    L --> X') },
                @{ Title='Security control loop'; Memory='Prevent - Detect - Respond - Learn'; Read='Controls are incomplete without detection, practiced response, evidence preservation, and improvement ownership.'; Lines=@('flowchart LR','    T["Threat and abuse cases"] --> P["Preventive controls"]','    P --> D["Detective signals"]','    D --> R["Response and containment"]','    R --> V["Recovery and validation"]','    V --> L["Lessons and control changes"]','    L --> T','    A["Audit evidence"] --> D','    A --> R') },
                @{ Title='Operational readiness gate'; Memory='Own - Observe - Operate - Recover'; Read='A service is ready only when ownership, SLOs, diagnostics, safe access, runbooks, and recovery are proved.'; Lines=@('flowchart TB','    B["Build complete"] --> O["Owner and on-call"]','    O --> S["SLIs, SLOs, dashboards, alerts"]','    S --> D["Logs, traces, audit, change markers"]','    D --> R["Runbooks and safe access"]','    R --> F["Failure and restore exercise"]','    F --> G{"Readiness review passed?"}','    G -->|"No"| B','    G -->|"Yes"| P["Progressive production release"]') }
            )
        }
        10 {
            return @(
                @{ Title='Capstone HLD'; Memory='Edge - Services - Events - Data - Evidence'; Read='The complete design makes request paths, asynchronous work, authoritative state, and operational evidence visible.'; Lines=@('flowchart TB','    U["Global users"] --> E["DNS, CDN, WAF"]','    E --> G["API gateway"]','    G --> O["Order service"]','    G --> Q["Query service"]','    O --> P["Payment service"]','    O --> DB["Order database"]','    O --> X["Outbox publisher"]','    X --> B["Event stream"]','    B --> F["Fulfillment workers"]','    B --> N["Notification workers"]','    Q --> C["Read cache and projections"]','    O --> T["Metrics, logs, traces"]','    P --> T','    F --> T') },
                @{ Title='Order command sequence'; Memory='Identity - Idempotency - Invariant - Commit - Publish'; Read='The sequence protects the no-duplicate-charge invariant while returning a stable outcome.'; Lines=@('sequenceDiagram','    actor U as User','    participant A as Order API','    participant O as Order domain','    participant P as Payment adapter','    participant D as Order database','    participant B as Event stream','    U->>A: Create order + idempotency key','    A->>O: Authorized command','    O->>D: Check key and invariant','    O->>P: Idempotent payment authorization','    P-->>O: Payment outcome','    O->>D: Commit order + outbox atomically','    O-->>U: Stable order result','    D-->>B: Outbox publisher emits event') },
                @{ Title='Order lifecycle LLD'; Memory='Every state has an owner and legal transition'; Read='The state machine prevents impossible order and payment combinations and identifies compensation paths.'; Lines=@('stateDiagram-v2','    [*] --> Draft','    Draft --> Validated: command accepted','    Validated --> PaymentPending','    PaymentPending --> Confirmed: payment authorized','    PaymentPending --> PaymentFailed: terminal payment failure','    PaymentPending --> Review: uncertain outcome','    Review --> Confirmed: reconciled success','    Review --> Cancelled: reconciled failure','    Confirmed --> FulfillmentPending','    FulfillmentPending --> Fulfilled','    Confirmed --> Cancelled: approved compensation','    PaymentFailed --> [*]','    Fulfilled --> [*]','    Cancelled --> [*]') },
                @{ Title='Design interview answer loop'; Memory='Clarify - Estimate - Design - Deep dive - Break - Improve'; Read='A strong interview is an iterative reasoning process, not a memorized final diagram.'; Lines=@('flowchart LR','    C["Clarify users, journeys, and constraints"] --> E["Estimate traffic, data, latency, and capacity"]','    E --> H["Draw HLD boundaries and flows"]','    H --> L["Deep-dive LLD contract or component"]','    L --> F["Test scale, failure, security, and recovery"]','    F --> T["Explain trade-offs and alternatives"]','    T --> V["Validate against requirements"]','    V --> C') }
            )
        }
        default {
            throw "No visual set exists for Module 17 Lesson $Lesson."
        }
    }
}

function Add-MermaidVisual {
    param(
        [System.Collections.Generic.List[string]]$Workbook,
        [int]$Number,
        [hashtable]$Visual
    )

    $id = $Number.ToString('00')
    $Workbook.Add("### Visual $id - $($Visual.Title)")
    $Workbook.Add('')
    $Workbook.Add("Memory hook: **$($Visual.Memory)**.")
    $Workbook.Add('')
    $Workbook.Add('```mermaid')
    foreach ($line in $Visual.Lines) {
        $Workbook.Add($line)
    }
    $Workbook.Add('```')
    $Workbook.Add('')
    $Workbook.Add("How to read it: $($Visual.Read)")
    $Workbook.Add('')
    $Workbook.Add('Recall drill: close the diagram, redraw it from the memory hook, label every arrow, then explain one failure and one security concern.')
    $Workbook.Add('')
}

function Add-VisualMemoryAtlas {
    param(
        [System.Collections.Generic.List[string]]$Workbook,
        [int]$Lesson
    )

    $commonVisuals = @(
        @{ Title='HLD-to-LLD evidence chain'; Memory='WHY - WHERE - HOW - PROOF'; Read='Requirements explain why; HLD chooses boundaries and topology; LLD defines exact behavior; tests and telemetry prove the promise.'; Lines=@('flowchart LR','    R["Requirements and constraints"] --> H["HLD boundaries, flows, data, topology"]','    H --> L["LLD interfaces, schemas, states, algorithms"]','    L --> C["Code and configuration"]','    C --> T["Tests and failure exercises"]','    T --> O["Runtime telemetry and user outcomes"]','    O --> D{"Promise proved?"}','    D -->|"No"| R','    D -->|"Yes"| A["Approved evidence"]') },
        @{ Title='Architecture zoom levels'; Memory='Context - Containers - Components - Code'; Read='Move from the outside world to deployable units, internal collaborators, and implementation detail without mixing abstraction levels.'; Lines=@('flowchart TB','    X["Context: users and external systems"] --> N["Containers: applications and data stores"]','    N --> P["Components: responsibilities and contracts"]','    P --> C["Code: modules, classes, functions, schemas"]','    D["Deployment: nodes, zones, regions, networks"] --> N','    S["Sequences: runtime interactions"] --> P','    E["Evidence: tests and telemetry"] --> C') }
    )
    $lessonVisuals = @(Get-LessonVisuals -Lesson $Lesson)

    $Workbook.Add('## Visual memory atlas')
    $Workbook.Add('')
    $Workbook.Add('These diagrams turn the lesson into visual recall cues. Render Mermaid in a compatible Markdown preview, then practice redrawing each diagram without looking.')
    $Workbook.Add('')
    $Workbook.Add('Use the **memory hook** as the shortest possible reconstruction key. During an interview or incident, draw the main boxes first, add arrows second, and annotate constraints, failure, identity, and evidence last.')
    $Workbook.Add('')

    $visualNumber = 0
    foreach ($visual in @($commonVisuals) + @($lessonVisuals)) {
        $visualNumber++
        Add-MermaidVisual -Workbook $Workbook -Number $visualNumber -Visual $visual
    }
}

function Add-HldLldTrack {
    param(
        [System.Collections.Generic.List[string]]$Workbook,
        [object[]]$Concepts,
        [hashtable]$Profile
    )

    $hldDimensions = @(
        @{ Name = 'Problem framing, outcomes, and non-goals'; Meaning = 'Define whose problem is being solved, the measurable outcome, and work deliberately excluded from the design.' },
        @{ Name = 'Functional requirements and user journeys'; Meaning = 'Describe what each actor must accomplish and the important success, alternate, and failure journeys.' },
        @{ Name = 'Quality attributes and constraint priorities'; Meaning = 'Rank availability, latency, durability, security, cost, compliance, delivery speed, and simplicity instead of claiming every attribute is equally critical.' },
        @{ Name = 'System context and external actors'; Meaning = 'Place the system inside its business and technical environment, showing people, upstream systems, downstream systems, and ownership.' },
        @{ Name = 'Architecture boundaries and decomposition'; Meaning = 'Split responsibilities into cohesive components with explicit ownership, reasons to change, and dependency direction.' },
        @{ Name = 'Architecture style and macro-pattern selection'; Meaning = 'Choose deliberately among modular monolith, services, microservices, event-driven, serverless, data-pipeline, and hybrid styles from constraints rather than fashion.' },
        @{ Name = 'End-to-end request and data flows'; Meaning = 'Trace normal and exceptional work across synchronous calls, asynchronous messages, storage, identity, and control-plane decisions.' },
        @{ Name = 'Control plane, data plane, and management plane'; Meaning = 'Separate policy and desired state, runtime workload traffic, and administrative operations so failure and privilege boundaries are explicit.' },
        @{ Name = 'Build, buy, managed-service, and reuse decisions'; Meaning = 'Compare internal implementation, platform reuse, open source, and managed services using capability, risk, operations, lock-in, and total cost.' },
        @{ Name = 'API, protocol, and integration style'; Meaning = 'Choose request-response, streaming, events, batch, files, or shared data deliberately and define boundary semantics.' },
        @{ Name = 'Data ownership, classification, and lifecycle'; Meaning = 'Assign an authoritative owner and define sensitivity, residency, retention, deletion, archival, lineage, and legal obligations.' },
        @{ Name = 'Storage, indexing, and retrieval architecture'; Meaning = 'Select storage engines and access paths from workload shape, query patterns, correctness, recovery, scale, and operational skill.' },
        @{ Name = 'Consistency, transactions, and correctness model'; Meaning = 'State invariants and decide where strong consistency, eventual convergence, sagas, compensation, or reconciliation is acceptable.' },
        @{ Name = 'Events, queues, streams, and background work'; Meaning = 'Define producers, consumers, ordering, duplication, replay, poison work, backpressure, and ownership of asynchronous outcomes.' },
        @{ Name = 'Caching and content-delivery architecture'; Meaning = 'Place caches by access pattern and define ownership, keys, freshness, invalidation, stampede protection, and bypass behavior.' },
        @{ Name = 'Traffic management and service discovery'; Meaning = 'Explain naming, routing, load balancing, health, locality, failover, connection management, and overload behavior.' },
        @{ Name = 'Edge, network, transport, and connectivity architecture'; Meaning = 'Design DNS, TLS, proxies, gateways, firewalls, private connectivity, egress, protocol negotiation, connection reuse, and network failure behavior.' },
        @{ Name = 'Capacity model and scaling strategy'; Meaning = 'Translate demand into CPU, memory, storage, bandwidth, connections, queue depth, replicas, headroom, and scaling triggers.' },
        @{ Name = 'Latency budgets and performance architecture'; Meaning = 'Allocate an end-to-end latency objective across network, compute, storage, queues, retries, and user-perceived rendering.' },
        @{ Name = 'Availability model and failure domains'; Meaning = 'Map component and dependency failure modes across process, node, zone, region, provider, control plane, and human operation.' },
        @{ Name = 'Resilience and graceful degradation'; Meaning = 'Prioritize critical journeys and define timeouts, load shedding, isolation, fallback, partial results, and safe recovery.' },
        @{ Name = 'Multi-region topology and data authority'; Meaning = 'Choose active-passive or active-active behavior and make routing, writer authority, replication lag, conflict, and failback explicit.' },
        @{ Name = 'Backup, restore, disaster recovery, and continuity'; Meaning = 'Connect business impact to RTO, RPO, backup integrity, restore sequence, dependency recovery, communications, and exercises.' },
        @{ Name = 'Identity, trust boundaries, and authorization'; Meaning = 'Identify principals and credentials, authenticate every boundary, authorize least privilege, and preserve auditable decisions.' },
        @{ Name = 'Threat model, abuse cases, and privacy'; Meaning = 'Model assets, attackers, entry points, misuse, data exposure, denial of service, supply-chain risk, and privacy harm.' },
        @{ Name = 'Tenant isolation, quotas, and fairness'; Meaning = 'Define isolation for identity, data, compute, network, keys, logs, and noisy-neighbor control across tenant tiers.' },
        @{ Name = 'Observability and diagnostic architecture'; Meaning = 'Design metrics, logs, traces, profiles, audit events, correlation, change markers, retention, and missing-telemetry behavior.' },
        @{ Name = 'Operability, ownership, and support model'; Meaning = 'Define owners, on-call boundaries, runbooks, access paths, maintenance, escalation, dependency contacts, and operational readiness.' },
        @{ Name = 'Deployment topology and release safety'; Meaning = 'Map artifacts to runtime units and define immutable delivery, compatibility, progressive exposure, rollback, and desired-state convergence.' },
        @{ Name = 'Runtime platform, infrastructure, and provisioning'; Meaning = 'Define compute, orchestration, network, storage, identity, infrastructure as code, policy, environment parity, and control-plane dependencies.' },
        @{ Name = 'Configuration, secrets, and key management'; Meaning = 'Separate code from environment configuration and define validation, distribution, rotation, revocation, encryption, and audit.' },
        @{ Name = 'Cost architecture and unit economics'; Meaning = 'Connect resource drivers and shared costs to a useful business unit, budgets, scaling decisions, waste, and resilience reserve.' },
        @{ Name = 'Evolution, migration, and decommissioning'; Meaning = 'Plan version coexistence, data movement, strangler paths, rollback boundaries, ownership transfer, retention, and safe removal.' },
        @{ Name = 'Organization, team topology, and cognitive load'; Meaning = 'Align system boundaries with ownership, communication paths, operational skill, platform capabilities, and the amount of complexity a team can safely carry.' },
        @{ Name = 'Architecture governance and decision records'; Meaning = 'Record assumptions, options, decisions, consequences, evidence, owner, expiry, standards exceptions, and revisit triggers.' }
    )

    $lldDimensions = @(
        @{ Name = 'Module, package, and namespace structure'; Meaning = 'Translate architecture boundaries into cohesive code units with visible APIs and controlled dependency direction.' },
        @{ Name = 'Layered, hexagonal, clean, and vertical-slice structure'; Meaning = 'Choose an implementation structure that keeps business rules testable while transport, persistence, framework, and vendor details remain replaceable.' },
        @{ Name = 'SOLID, cohesion, coupling, and dependency direction'; Meaning = 'Give units focused reasons to change, depend on stable abstractions, expose narrow contracts, and avoid hidden temporal or global coupling.' },
        @{ Name = 'Interfaces, ports, adapters, and contracts'; Meaning = 'Define behavior at each boundary so implementations can change without leaking transport, vendor, or storage details.' },
        @{ Name = 'Domain model, entities, and value objects'; Meaning = 'Represent business identity, values, relationships, lifecycle, and language without turning persistence rows into the entire model.' },
        @{ Name = 'Aggregates, repositories, domain services, and domain events'; Meaning = 'Choose consistency boundaries and collaboration patterns that enforce invariants without creating oversized aggregates or infrastructure-dependent domain logic.' },
        @{ Name = 'Invariants, validation, and policy rules'; Meaning = 'Place every rule where it can be enforced consistently and distinguish malformed input, forbidden action, and business conflict.' },
        @{ Name = 'Class and object responsibilities'; Meaning = 'Prefer focused responsibilities, composition, explicit collaborators, and testable behavior over deep inheritance and god objects.' },
        @{ Name = 'Creational, structural, and behavioral pattern selection'; Meaning = 'Use factories, builders, adapters, decorators, strategies, observers, commands, or other patterns only when their specific collaboration problem and cost are explicit.' },
        @{ Name = 'Function signatures and dependency injection'; Meaning = 'Make inputs, outputs, side effects, clock, randomness, configuration, and external dependencies explicit and replaceable.' },
        @{ Name = 'API resource and operation design'; Meaning = 'Specify resources, commands, query semantics, pagination, filtering, status, errors, versioning, compatibility, and deprecation.' },
        @{ Name = 'Request, response, and schema validation'; Meaning = 'Define required and optional fields, bounds, formats, defaults, unknown-field behavior, normalization, and safe error disclosure.' },
        @{ Name = 'Error model and failure semantics'; Meaning = 'Use stable error categories with retryability, ownership, client action, correlation, and safe diagnostic context.' },
        @{ Name = 'Idempotency and duplicate suppression'; Meaning = 'Give retried work a stable identity and persist enough outcome state to prevent duplicate externally visible effects.' },
        @{ Name = 'State machines and lifecycle transitions'; Meaning = 'Enumerate states, legal transitions, guards, commands, events, terminal conditions, timeouts, and recovery from partial transitions.' },
        @{ Name = 'Algorithms and complexity budgets'; Meaning = 'Choose an algorithm from correctness and workload bounds, then state time, space, I/O, contention, and degradation complexity.' },
        @{ Name = 'Numeric precision, money, units, and overflow'; Meaning = 'Choose representations and rounding rules for currency, measurements, counters, timestamps, and large values while preventing unit confusion and overflow.' },
        @{ Name = 'Data structures and memory behavior'; Meaning = 'Select structures from access, mutation, ordering, uniqueness, locality, allocation, concurrency, and bounded-memory needs.' },
        @{ Name = 'Language runtime, memory, threads, and asynchronous execution'; Meaning = 'Account for allocation, garbage collection, stack and heap use, thread or event-loop behavior, cancellation, scheduling, and runtime failure.' },
        @{ Name = 'Relational schema, keys, and constraints'; Meaning = 'Encode identity, relationships, uniqueness, nullability, checks, referential integrity, lifecycle, and ownership in the schema.' },
        @{ Name = 'Indexes and query plans'; Meaning = 'Design indexes from measured query patterns and verify selectivity, ordering, write amplification, storage, and planner behavior.' },
        @{ Name = 'Transactions and isolation'; Meaning = 'Choose transaction boundaries and isolation by invariant, anomaly risk, lock behavior, contention, retry, and user-visible outcome.' },
        @{ Name = 'Concurrency, synchronization, and race safety'; Meaning = 'Identify shared state and define atomic operations, ownership, locks, optimistic checks, queues, immutability, or actor boundaries.' },
        @{ Name = 'Distributed leases, locks, and leader work'; Meaning = 'Define lease identity, fencing, expiry, clock assumptions, failover, split-brain protection, and idempotent ownership changes.' },
        @{ Name = 'Time, ordering, and identifier semantics'; Meaning = 'Separate wall time from monotonic duration and define timezone, skew, ordering, uniqueness, and sortable identifier assumptions.' },
        @{ Name = 'Timeout, retry, backoff, and jitter policy'; Meaning = 'Budget attempts end to end, retry only safe failures, spread retries, cap work, and avoid multiplying downstream overload.' },
        @{ Name = 'Rate limits, quotas, and admission control'; Meaning = 'Choose scope, algorithm, fairness, burst, storage, response, bypass authority, and behavior when the limiter is unavailable.' },
        @{ Name = 'Cache keys, TTLs, and invalidation'; Meaning = 'Specify key completeness, value ownership, freshness, negative caching, invalidation events, stampede control, and bypass.' },
        @{ Name = 'Event schema and consumer contract'; Meaning = 'Define event meaning, identity, producer, partition key, ordering, version evolution, sensitive fields, retention, and consumer obligations.' },
        @{ Name = 'Outbox, inbox, replay, and poison work'; Meaning = 'Bridge state and messaging safely with atomic publication, deduplication, bounded retries, quarantine, replay controls, and audit.' },
        @{ Name = 'Serialization and compatibility'; Meaning = 'Define wire types, precision, defaults, unknown fields, enum evolution, size limits, canonicalization, and backward compatibility.' },
        @{ Name = 'DTO, mapper, and boundary-model separation'; Meaning = 'Translate transport, persistence, domain, and presentation models explicitly so validation, versioning, and sensitive fields do not leak across boundaries.' },
        @{ Name = 'Files, objects, uploads, downloads, and streaming I/O'; Meaning = 'Bound size and memory, validate type and name, stream safely, handle partial transfer, scan untrusted content, preserve integrity, and clean temporary state.' },
        @{ Name = 'Configuration and feature-flag behavior'; Meaning = 'Type and validate settings, define precedence and dynamic reload, assign owners and expiry, and specify failure defaults.' },
        @{ Name = 'Authentication and authorization implementation'; Meaning = 'Validate credentials and claims, bind decisions to resource and action, deny safely, prevent confused deputy behavior, and audit.' },
        @{ Name = 'Sensitive data, secret, and cryptographic handling'; Meaning = 'Minimize sensitive material, prevent logging and copying, use approved primitives, rotate keys, and define deletion and incident response.' },
        @{ Name = 'Input safety and output encoding'; Meaning = 'Constrain parsers, paths, queries, templates, uploads, redirects, and rendered output at the boundary where context is known.' },
        @{ Name = 'Logging, metrics, tracing, and audit instrumentation'; Meaning = 'Place structured signals at outcome and boundary transitions with stable names, correlation, cardinality controls, and redaction.' },
        @{ Name = 'Health, readiness, liveness, and dependency checks'; Meaning = 'Make each check answer one operational question without causing restart loops, dependency storms, or false readiness.' },
        @{ Name = 'Resource lifecycle and cleanup'; Meaning = 'Own files, sockets, goroutines, threads, pools, subscriptions, temporary data, and cancellation through success and every failure path.' },
        @{ Name = 'Unit, property, and mutation tests'; Meaning = 'Prove local behavior, invariants, boundary values, generated cases, and test-suite sensitivity without depending on remote systems.' },
        @{ Name = 'Contract, integration, and component tests'; Meaning = 'Verify real boundary semantics, compatibility, persistence, messaging, and failure behavior with controlled dependencies.' },
        @{ Name = 'End-to-end, load, and fault tests'; Meaning = 'Protect a small set of critical journeys and validate scale, overload, partial failure, recovery, and evidence in realistic topology.' },
        @{ Name = 'Performance profiling and optimization'; Meaning = 'Measure latency distributions, allocation, CPU, I/O, locks, queries, and queues before changing the smallest proven bottleneck.' },
        @{ Name = 'Third-party dependency and software-supply-chain design'; Meaning = 'Control versions, provenance, licenses, vulnerabilities, transitive risk, initialization, failure isolation, upgrade testing, and emergency replacement.' },
        @{ Name = 'Backward-compatible rollout and migration code'; Meaning = 'Implement expand-migrate-contract, mixed-version behavior, feature control, resumability, rollback, and cleanup verification.' },
        @{ Name = 'Code ownership, documentation, and maintainability'; Meaning = 'Keep contracts, examples, rationale, operational notes, owners, review rules, and removal criteria beside the implementation.' }
    )

    $traceabilityContracts = @(
        'business outcome to architecture capability',
        'user journey to component interaction',
        'functional requirement to API operation',
        'SLO to latency budget and timeout',
        'throughput estimate to capacity and data structure',
        'business invariant to schema constraint and transaction',
        'consistency choice to read and write behavior',
        'trust boundary to authentication and authorization check',
        'data classification to field handling and retention',
        'failure domain to redundancy and containment',
        'retry policy to idempotency and duplicate suppression',
        'event flow to schema, partitioning, and replay',
        'cache policy to key, freshness, and invalidation',
        'release strategy to compatibility and feature control',
        'observability objective to instrumentation and runbook',
        'recovery objective to persistence, restore, and reconciliation',
        'tenant model to partitioning, quota, and access checks',
        'cost driver to resource budget and useful unit',
        'architecture decision to code ownership and tests',
        'threat or abuse case to preventive and detective control',
        'migration plan to resumable step and rollback boundary',
        'operational risk to health check and failure injection',
        'architecture boundary to package and dependency rule',
        'business lifecycle to domain model and state machine',
        'performance budget to algorithm, index, and profile evidence',
        'external dependency to adapter, resilience, and replacement plan'
    )

    $Workbook.Add('## HLD and LLD - the complete design chain')
    $Workbook.Add('')
    $Workbook.Add('High-level design decides system boundaries, responsibilities, interactions, data authority, topology, quality attributes, and major trade-offs. Low-level design turns those decisions into interfaces, schemas, state machines, algorithms, concurrency rules, failure semantics, instrumentation, and tests.')
    $Workbook.Add('')
    $Workbook.Add('HLD without LLD can look convincing while hiding impossible contracts. LLD without HLD can produce clean code that solves the wrong boundary or violates a system objective. Every decision below therefore requires a trace from user outcome to production evidence.')
    $Workbook.Add('')
    $Workbook.Add('| Design level | Primary question | Required evidence |')
    $Workbook.Add('|---|---|---|')
    $Workbook.Add('| HLD | What system should exist, why, and under which constraints? | Context, containers, flows, data authority, topology, SLOs, threats, capacity, ADRs, and operations. |')
    $Workbook.Add('| LLD | Exactly how will each unit behave and remain correct? | Interfaces, schemas, states, algorithms, errors, concurrency, tests, telemetry, and rollout compatibility. |')
    $Workbook.Add('| Traceability | How does implementation prove the architecture promise? | Requirement IDs, contracts, test IDs, dashboards, runbooks, change evidence, and review decisions. |')
    $Workbook.Add('')
    $Workbook.Add('### Mandatory diagram set')
    $Workbook.Add('')
    $Workbook.Add('- HLD diagrams: system context, containers or services, end-to-end sequence, data flow, trust boundaries, deployment topology, failure domains, and multi-region or recovery state where relevant.')
    $Workbook.Add('- LLD diagrams: component or package view, class or collaboration view where useful, detailed sequence, state machine, schema or entity relationship, concurrency ownership, and rollout or migration state.')
    $Workbook.Add('- Diagram rule: every box needs a responsibility and owner; every arrow needs a protocol, direction, data, authentication, timeout, retry, and failure meaning where applicable.')
    $Workbook.Add('- Evidence rule: diagrams are hypotheses until configuration, code, test output, runtime signals, and recovery behavior agree with them.')
    $Workbook.Add('')

    $Workbook.Add('## Comprehensive HLD decision track')
    $Workbook.Add('')
    for ($index = 0; $index -lt $hldDimensions.Count; $index++) {
        $dimension = $hldDimensions[$index]
        $primary = $Concepts[$index % $Concepts.Count]
        $secondary = $Concepts[(($index * 5) + 2) % $Concepts.Count]
        $artifact = $Profile.Artifacts[$index % $Profile.Artifacts.Count]
        $failure = $Profile.Failures[$index % $Profile.Failures.Count]
        $number = ($index + 1).ToString('00')
        $Workbook.Add("### HLD dimension $number - $($dimension.Name)")
        $Workbook.Add('')
        $Workbook.Add("- Plain-language meaning: $($dimension.Meaning)")
        $Workbook.Add("- Lesson anchor: **$($primary.Name)** - $($primary.Anchor)")
        $Workbook.Add("- Connected concern: explain how **$($secondary.Name)** changes this HLD decision.")
        $Workbook.Add('- Requirements input: list actors, critical journey, measurable outcome, scale, data sensitivity, constraints, non-goals, and unresolved questions.')
        $Workbook.Add('- Decision: state the selected boundary or behavior, two realistic alternatives, rejection reasons, owner, and revisit trigger.')
        $Workbook.Add('- Diagram: show components, responsibilities, protocols, data authority, identity, trust boundaries, deployment locations, and failure domains relevant to this dimension.')
        $Workbook.Add('- Interface view: name each external contract, direction, version owner, latency expectation, timeout, retry, idempotency, and failure response.')
        $Workbook.Add('- Data view: identify authoritative state, read and write paths, consistency, classification, retention, backup, restore, and reconciliation.')
        $Workbook.Add('- Scale view: quantify workload, peak multiplier, skew, growth, bottleneck, headroom, queueing point, and scaling limit.')
        $Workbook.Add("- Failure review: $failure; predict user impact, containment, degraded mode, recovery sequence, and residual risk.")
        $Workbook.Add('- Security review: identify principal, credential, authorization, sensitive data, attacker goal, abuse path, preventive control, detective control, and audit event.')
        $Workbook.Add('- Operations review: define SLI, alert, dashboard, logs or traces, runbook, on-call owner, safe diagnostic access, and maintenance action.')
        $Workbook.Add('- Cost review: connect paid resources and engineering effort to one useful unit, demand assumption, resilience reserve, and cost guardrail.')
        $Workbook.Add("- Hands-on evidence: produce $artifact and attach the decision, rendered or calculated evidence, controlled test, and recovery result.")
        $Workbook.Add('- Review gate: a peer can find every critical assumption, challenge the trade-off, and trace the chosen architecture to a measurable outcome.')
        $Workbook.Add('- Interview defense: explain the decision in two minutes, draw it in five, then answer one scale, failure, security, and migration challenge.')
        $Workbook.Add('')
    }

    $Workbook.Add('## Comprehensive LLD implementation track')
    $Workbook.Add('')
    for ($index = 0; $index -lt $lldDimensions.Count; $index++) {
        $dimension = $lldDimensions[$index]
        $primary = $Concepts[(($index * 3) + 1) % $Concepts.Count]
        $secondary = $Concepts[(($index * 7) + 4) % $Concepts.Count]
        $artifact = $Profile.Artifacts[(($index * 2) + 1) % $Profile.Artifacts.Count]
        $failure = $Profile.Failures[(($index * 5) + 1) % $Profile.Failures.Count]
        $number = ($index + 1).ToString('00')
        $Workbook.Add("### LLD dimension $number - $($dimension.Name)")
        $Workbook.Add('')
        $Workbook.Add("- Plain-language meaning: $($dimension.Meaning)")
        $Workbook.Add("- HLD source: identify which boundary, quality attribute, invariant, or risk from **$($primary.Name)** requires this detailed design.")
        $Workbook.Add("- Connected concern: explain how **$($secondary.Name)** constrains the implementation.")
        $Workbook.Add('- Contract: write preconditions, inputs, outputs, postconditions, side effects, stable errors, retryability, compatibility, and ownership.')
        $Workbook.Add('- Model: define types, identity, invariants, lifecycle, state transitions, illegal states, and where each rule is enforced.')
        $Workbook.Add('- Algorithm: provide pseudocode for the success path, partial failure, cancellation, duplicate work, concurrency conflict, and recovery.')
        $Workbook.Add('- Persistence: specify keys, constraints, indexes, transaction boundary, isolation, retention, migration, and reconciliation where state exists.')
        $Workbook.Add('- Concurrency: name shared state, atomic boundary, ordering, lock or version strategy, timeout, fairness, and crash behavior.')
        $Workbook.Add('- Dependency behavior: define client timeout, retry budget, backoff, circuit or isolation rule, response validation, fallback, and ownership.')
        $Workbook.Add('- Security behavior: validate input, authenticate principal, authorize action and resource, protect sensitive values, encode output, and audit outcome.')
        $Workbook.Add('- Instrumentation: define structured outcome event, metric units and labels, trace spans, profile point, correlation key, redaction, and cardinality limit.')
        $Workbook.Add('- Test design: include examples, boundaries, property or invariant checks, contract cases, integration behavior, race or concurrency tests, load, and faults.')
        $Workbook.Add("- Failure exercise: $failure; demonstrate containment, stable error semantics, cleanup, idempotent retry, and final authoritative state.")
        $Workbook.Add('- Rollout: prove mixed-version compatibility, expand-migrate-contract ordering, feature control, observability, abort condition, and rollback limit.')
        $Workbook.Add("- Hands-on evidence: produce $artifact plus interface or schema, pseudocode or implementation sketch, test table, and observed result.")
        $Workbook.Add('- Code-review gate: behavior is understandable without hidden global state, unsafe defaults, ambiguous errors, unbounded work, or unowned cleanup.')
        $Workbook.Add('- Interview defense: move from class, interface, schema, or algorithm detail back to the HLD outcome and defend one alternative implementation.')
        $Workbook.Add('')
    }

    $Workbook.Add('## HLD-to-LLD traceability contracts')
    $Workbook.Add('')
    for ($index = 0; $index -lt $traceabilityContracts.Count; $index++) {
        $contract = $traceabilityContracts[$index]
        $concept = $Concepts[(($index * 11) + 2) % $Concepts.Count]
        $number = ($index + 1).ToString('00')
        $Workbook.Add("### Traceability contract $number - $contract")
        $Workbook.Add('')
        $Workbook.Add("- Lesson focus: **$($concept.Name)**.")
        $Workbook.Add('- HLD statement: write the user, business, security, reliability, performance, compliance, or cost promise in measurable terms.')
        $Workbook.Add('- LLD realization: name the exact interface, state, schema, algorithm, guard, timeout, telemetry, or test that enforces the promise.')
        $Workbook.Add('- Identifier: assign stable requirement, ADR, contract, test, dashboard, runbook, and change IDs that reviewers can follow.')
        $Workbook.Add('- Positive proof: record a reproducible success case with inputs, environment, version, expected outcome, actual outcome, and evidence.')
        $Workbook.Add('- Negative proof: violate one assumption safely and show the implemented containment, error, alert, cleanup, and recovery behavior.')
        $Workbook.Add('- Drift check: identify how code, configuration, schema, infrastructure, dashboard, or runbook can stop matching the approved design.')
        $Workbook.Add('- Review question: could the HLD remain apparently correct while this LLD silently violates it, and what automated check prevents that?')
        $Workbook.Add('- Completion rule: another engineer can travel from outcome to design to implementation to runtime evidence and back without guessing.')
        $Workbook.Add('')
    }

    $Workbook.Add('## Professional design review packet')
    $Workbook.Add('')
    $Workbook.Add('- One-page brief: problem, actors, outcomes, constraints, non-goals, scale, data classification, SLOs, budget, owner, and open questions.')
    $Workbook.Add('- HLD packet: context, component, sequence, data-flow, trust-boundary, deployment, failure-domain, and recovery diagrams with ADRs.')
    $Workbook.Add('- LLD packet: interfaces, schemas, state machines, core pseudocode, concurrency model, stable errors, dependency policies, and instrumentation.')
    $Workbook.Add('- Verification packet: requirement-to-test matrix, contract tests, load model, threat tests, fault injection, restore evidence, and user-journey proof.')
    $Workbook.Add('- Delivery packet: compatibility matrix, migrations, feature controls, canary measures, abort conditions, rollback limits, and cleanup plan.')
    $Workbook.Add('- Operations packet: ownership, service catalog entry, SLOs, dashboards, alerts, logs or traces, runbooks, access, escalation, maintenance, and capacity review.')
    $Workbook.Add('- Decision packet: options, trade-offs, dissent, risks, mitigations, accepted debt, expiry, follow-up owners, and approval evidence.')
    $Workbook.Add('- Interview packet: 30-second summary, five-minute diagram, estimates, deep-dive component, failure scenario, security challenge, and evolution path.')
    $Workbook.Add('')
}

function Add-WorkbookClosing {
    param(
        [System.Collections.Generic.List[string]]$Workbook,
        [int]$PracticeCount
    )

    $Workbook.Add('## Workbook completion review')
    $Workbook.Add('')
    $Workbook.Add("- Practice cases generated for this lesson: $PracticeCount.")
    $Workbook.Add('- Select at least one case at every learning level and one case for every concept card.')
    $Workbook.Add('- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.')
    $Workbook.Add('- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.')
    $Workbook.Add('- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.')
    $Workbook.Add('')
    $Workbook.Add($endMarker)
}

$results = [System.Collections.Generic.List[object]]::new()
$modulePattern = '^(' + (($Modules | ForEach-Object { [regex]::Escape([string]$_) }) -join '|') + ')\.'
$moduleDirectories = Get-ChildItem -LiteralPath $workspaceRoot -Directory |
    Where-Object { $_.Name -match $modulePattern } |
    Sort-Object Name

foreach ($directory in $moduleDirectories) {
    $module = [int]([regex]::Match($directory.Name, '^(\d+)\.').Groups[1].Value)
    $profile = Get-ModuleProfile -Module $module
    $lessonFiles = Get-ChildItem -LiteralPath $directory.FullName -Filter "Lesson $module.*.md" |
        Sort-Object { [int]([regex]::Match($_.BaseName, "$module\.(\d+)").Groups[1].Value) }

    foreach ($file in $lessonFiles) {
        $lesson = [int]([regex]::Match($file.BaseName, "$module\.(\d+)").Groups[1].Value)
        $raw = [System.IO.File]::ReadAllText($file.FullName, $utf8NoBom).Replace("`r`n", "`n").Replace("`r", "`n")
        $sourceLines = $raw -split "`n"
        $hasGeneratedWorkbook = [Array]::IndexOf($sourceLines, $startMarker) -ge 0
        if ($OnlyBelowMinimum -and $sourceLines.Count -ge $MinimumLines -and -not $hasGeneratedWorkbook) {
            $results.Add([pscustomobject]@{
                    Module = $module
                    Lesson = $lesson
                    Lines = $sourceLines.Count
                    Concepts = '-'
                    PracticeCases = '-'
                    Status = 'Preserved'
                    File = $file.Name
                })
            continue
        }

        $lines = Remove-GeneratedWorkbook -Lines $sourceLines

        while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
            $lines = if ($lines.Count -gt 1) { $lines[0..($lines.Count - 2)] } else { @() }
        }

        $titleMatch = [regex]::Match(($lines -join "`n"), "(?m)^## Lesson (?:${module}\.)?${lesson}\s*(?::|\p{Pd})\s*(.+)$")
        $title = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { "Module $module Lesson $lesson" }
        $concepts = Get-Concepts -Lines $lines -Module $module -Lesson $lesson
        $maximumSection = ($concepts | Measure-Object -Property Number -Maximum).Maximum

        $referenceIndex = -1
        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ($lines[$index] -match '^\[\d+\]:\s+https?://') {
                $referenceIndex = $index
                break
            }
        }
        if ($referenceIndex -lt 0) { $referenceIndex = $lines.Count }

        $beforeReferences = if ($referenceIndex -gt 0) { @($lines[0..($referenceIndex - 1)]) } else { @() }
        $references = if ($referenceIndex -lt $lines.Count) { @($lines[$referenceIndex..($lines.Count - 1)]) } else { @() }
        while ($beforeReferences.Count -gt 0 -and [string]::IsNullOrWhiteSpace($beforeReferences[$beforeReferences.Count - 1])) {
            $beforeReferences = if ($beforeReferences.Count -gt 1) { $beforeReferences[0..($beforeReferences.Count - 2)] } else { @() }
        }

        $workbook = [System.Collections.Generic.List[string]]::new()
        Add-WorkbookIntroduction -Workbook $workbook -Module $module -Lesson $lesson -SectionNumber ($maximumSection + 1) -Title $title -ConceptCount $concepts.Count
        Add-ConceptCards -Workbook $workbook -Concepts $concepts -Profile $profile
        if ($module -eq 17) {
            Add-HldLldTrack -Workbook $workbook -Concepts $concepts -Profile $profile
            Add-VisualMemoryAtlas -Workbook $workbook -Lesson $lesson
        }

        $practiceCount = 0
        $closingReserve = 12
        while (
            $practiceCount -lt 1 -or
            ($beforeReferences.Count + 2 + $workbook.Count + $closingReserve + 2 + $references.Count) -lt $TargetLines
        ) {
            $primaryIndex = $practiceCount % $concepts.Count
            $secondaryIndex = (($practiceCount * 7) + 3) % $concepts.Count
            if ($secondaryIndex -eq $primaryIndex -and $concepts.Count -gt 1) {
                $secondaryIndex = ($secondaryIndex + 1) % $concepts.Count
            }
            $level = $levels[$practiceCount % $levels.Count]
            $lens = $lenses[(($practiceCount * 3) + $lesson) % $lenses.Count]
            $environment = $environments[(($practiceCount * 5) + $module + $lesson) % $environments.Count]
            $artifact = $profile.Artifacts[(($practiceCount * 2) + $lesson) % $profile.Artifacts.Count]
            $failure = $profile.Failures[(($practiceCount * 5) + $module) % $profile.Failures.Count]
            $practiceCount++

            Add-ScenarioDrill -Workbook $workbook -DrillNumber $practiceCount -PrimaryConcept $concepts[$primaryIndex] -SecondaryConcept $concepts[$secondaryIndex] -Level $level -Lens $lens -Environment $environment -Artifact $artifact -Failure $failure -Certification $profile.Certification
        }

        Add-WorkbookClosing -Workbook $workbook -PracticeCount $practiceCount

        $finalLines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $beforeReferences) { $finalLines.Add($line) }
        $finalLines.Add('')
        foreach ($line in $workbook) { $finalLines.Add($line) }
        if ($references.Count -gt 0) {
            $finalLines.Add('')
            foreach ($line in $references) { $finalLines.Add($line) }
        }

        if ($finalLines.Count -lt $MinimumLines) {
            throw "$($file.FullName) generated only $($finalLines.Count) lines."
        }

        if (-not $WhatIfMode) {
            [System.IO.File]::WriteAllText($file.FullName, (($finalLines -join "`n") + "`n"), $utf8NoBom)
        }

        $results.Add([pscustomobject]@{
                Module = $module
                Lesson = $lesson
                Lines = $finalLines.Count
                Concepts = $concepts.Count
                PracticeCases = $practiceCount
                Status = if ($WhatIfMode) { 'Dry run' } else { 'Expanded' }
                File = $file.Name
            })
    }
}

$results |
    Sort-Object Module, Lesson |
    Format-Table Module, Lesson, Lines, Concepts, PracticeCases, Status, File -AutoSize

$summary = $results | Measure-Object -Property Lines -Minimum -Maximum -Sum
"Lessons=$($results.Count) Minimum=$($summary.Minimum) Maximum=$($summary.Maximum) Total=$($summary.Sum) WhatIf=$WhatIfMode"
