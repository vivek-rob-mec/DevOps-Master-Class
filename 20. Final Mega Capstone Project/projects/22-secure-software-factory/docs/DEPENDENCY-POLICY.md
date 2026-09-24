# Dependency policy

Pin every CI action to a full commit SHA and annotate its reviewed release. Pin base images by digest after verifying their signature and provenance. Automate update pull requests, but require tests, diff review and refreshed evidence. A scanner result is untrusted input: isolate it from production credentials and verify the scanner artifact before execution.
