# High-level design

Applications emit vendor-neutral OTLP to a collector tier. Collectors enforce memory limits, batch traffic, redact sensitive attributes, and route metrics, traces, and logs to specialized backends. Grafana is the investigation surface; Prometheus evaluates SLO rules. Production separates agent/gateway collectors, uses object storage, authenticates every hop, and scales read/write paths independently.
