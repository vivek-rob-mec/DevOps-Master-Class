package finops.attribution
required := {"owner", "product", "environment", "cost_center"}
deny contains message if {
  input.kind == "Deployment"
  missing := required - {key | input.metadata.labels[key]}
  count(missing) > 0
  message := sprintf("workload is missing cost labels: %v", [missing])
}
