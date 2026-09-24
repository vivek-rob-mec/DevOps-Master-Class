# Observability platform runbook

When telemetry is missing, verify application export failures, collector receiver/exporter metrics, queue pressure, backend ingestion, and time synchronization in that order. When cardinality spikes, identify the metric and label source, apply an emergency collector filter, preserve evidence, and fix instrumentation. During backend overload, prioritize paging/SLO signals, reduce debug traffic and trace sampling, and protect ingestion from query workloads.
