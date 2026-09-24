# MLOps runbook

For prediction failures, distinguish service unavailability, model-load failure, feature-contract rejection, and model execution error. Roll back the deployment for runtime regressions; move the champion alias only through the approved promotion workflow for model regressions. Preserve request/model version correlation without logging raw sensitive features.

For drift, validate data-quality and pipeline changes before retraining. Compare slice metrics and calibration, obtain approval, canary the challenger, and retain the previous champion. Restore registry metadata and object artifacts together; verify checksums before serving.
