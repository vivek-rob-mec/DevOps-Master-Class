# High-level design

Each cluster runs Istiod, CNI and ztunnel. Ambient L4 identity is the baseline; shared or dedicated waypoints add L7 authorization only where required. Gateway API exposes north-south routes. A common root of trust, explicit trust-domain aliases and east-west gateways connect clusters without turning the mesh into an unrestricted flat network.
