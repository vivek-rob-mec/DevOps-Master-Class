# Low-level design

The checkout app creates server spans plus bounded route/status metrics and structured logs. The collector removes known sensitive attributes before export. Prometheus records request/error rates and evaluates a fast burn-rate alert. Grafana provisions Prometheus, Tempo, and Loki as code. Resource attributes provide service/environment identity; unbounded cart IDs are trace attributes, never metric labels.
