# Low-level design

The Backstage template validates ownership, system, repository, and tier, then renders a minimal service repository. Crossplane exposes a namespaced `App` API and uses a function pipeline to create Kubernetes resources. Argo CD discovers environment directories and reconciles them with prune and self-heal. Kyverno checks immutable image references, non-root execution, read-only filesystems, and resource requests/limits.

Platform APIs are versioned products. Breaking schema changes require a new served version, conversion/migration plan, compatibility tests, and consumer communication.
