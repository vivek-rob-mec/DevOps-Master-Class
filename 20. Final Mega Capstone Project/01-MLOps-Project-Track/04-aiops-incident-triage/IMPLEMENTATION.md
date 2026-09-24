# Implemented v1 and deliberate limits

| Concern | Implemented behavior |
|---|---|
| Telemetry | Shared SQLite events from actual API middleware, release activation, and explicitly marked fault fixtures |
| Features | Per-service 60-second mean latency, error fraction, maximum reported queue depth; minimum five samples |
| ML | Isolation Forest fitted only on healthy fixture windows; static-rule comparison on an independent healthy/fault fixture set |
| Incidents | Durable evidence snapshots and deterministic IDs for identical event boundaries/detector releases |
| Triage | Multiple hypotheses with next checks; recent release-event references when relevant |
| Review | Pending/approved/rejected state, immutable finalized review, explicit `executed: false` |
| Integration proof | Test drives actual M1 API failures, then proves AIOps ingests their HTTP telemetry |
| Frontend | Incident Desk: service-window cards, incident search/state/source filters, signal and hypothesis panels, original event snapshots, saved human review, detector comparison |
| Observation states | No recent samples, insufficient samples, or eligible window; missing telemetry is not classified as healthy |
| Source preservation | New incidents copy sample/release events into evidence JSON; legacy records retain their original schema with unavailable details identified |
| Analysis history | Latest ten completed analyses with detector release, eligible-window count, and returned incident IDs; analysis is on demand |
| Controlled replay | Three bounded scenarios for the three MLOps services; ten tagged samples per replay, optional simulated release marker; retry deduplication in the telemetry transaction |
| Review timestamps | Additive nullable creation/review timestamps; identical retries preserve first finalization time; historical timestamps are not invented |
| Degraded detector | Ledger remains readable if model evidence is unavailable; Analyze is disabled in the UI and returns 503 through the API |

The service reports a changed event window as new evidence and may create another incident. It does not yet group neighboring windows into an incident episode or apply alert suppression. Synthetic thresholds are not calibrated per-service SLOs. A detector alert can reflect a baseline mismatch, not a real outage.

Authentication, external telemetry collectors, root-cause validation, production alert delivery, metric/log/trace joins across hosts, and a remediation executor are deferred. Even an approved review is a recorded human judgment, not authorization that triggers infrastructure changes.

The frontend and API share one FastAPI process. Shared rendering and same-origin write checks come from `../mlops_common`; these checks are not authentication. The fixture endpoint writes simulated telemetry only, using a persisted request ID and payload hash. It does not produce a real outage or promote an actual model.

HTTP middleware records latency and server-error indicators, but supplies a default zero queue field. Incident Desk explicitly marks that queue as unmeasured; nonzero queue scenarios are fixtures in this implementation. Current windows may contain both HTTP and fixture samples. The model is still trained on a shared synthetic healthy baseline, not automatically on observed service traffic.

Incident listing is limited to the latest 100 records; counters cover the whole local ledger. A selected incident displays up to 200 saved source/release events with the total disclosed. There is no automatic evidence-retention policy, pagination, incident-episode grouping, scheduler, or production capacity qualification.
