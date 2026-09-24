# Operator runbook

Check leader-election lease, work queue depth, reconcile errors and Ready conditions. For a stuck finalizer, inspect dependent namespace state and API errors before any manual removal. For hot loops, pause new CR creation, identify resource-version conflicts or a non-idempotent mutation, then roll back the controller. Back up CRs and document conversion before changing a served/storage API version.
