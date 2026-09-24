# Low-level design

Namespaces opt in with `istio.io/dataplane-mode=ambient`. Service accounts form workload identity. Strict PeerAuthentication and an empty AuthorizationPolicy establish deny-by-default behavior. Explicit principals and operations reopen required paths. NetworkPolicy remains a separate defense layer. DestinationRule handles bounded connection pools and outlier ejection; Gateway API owns public routing.
