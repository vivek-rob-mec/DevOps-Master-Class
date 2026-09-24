# High-level design

The cluster-scoped Environment API is the contract. A leader-elected controller watches desired state and owns Namespace, ResourceQuota, LimitRange and NetworkPolicy resources. Status conditions expose readiness while Kubernetes events and controller-runtime metrics expose operations. Admission schema rejects malformed objects before reconciliation.
