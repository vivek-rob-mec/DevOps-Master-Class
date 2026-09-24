# Low-level design

Reconcile is level-driven: fetch, handle deletion, ensure finalizer, validate, CreateOrUpdate every dependent, then patch status. Never assume a single event or rely on in-memory state. Conflicts return errors for rate-limited retry. Finalization is explicit and opt-in because namespace deletion is destructive. Add envtest coverage for create, drift, deletion, conflict and upgrade before production use.
