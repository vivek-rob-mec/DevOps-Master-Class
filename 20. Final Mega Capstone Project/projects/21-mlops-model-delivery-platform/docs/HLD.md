# High-level design

Training and serving are separate trust/release boundaries. Training produces an evaluated, registered, immutable model artifact. A reviewed alias identifies the approved version. The inference service loads only the approved alias and exposes bounded feature and prediction contracts. Canary analysis gates rollout with live reliability metrics; model-quality monitoring remains separate from infrastructure health.
