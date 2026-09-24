# Design and lab record: <one specific question>

Status: planned / designed / attempted / demonstrated / recalled / transferred

Date:
Stage and related project:
Time/resource budget:
Evidence location:

## Before implementing

1. **What:** Which exact user or operational behavior am I changing?
2. **Why:** What observed problem or learning question justifies it? What happens if I do nothing?
3. **Mechanism:** Explain the relevant process, network, storage, or control loop in plain language.
4. **Design:** Draw the request/data flow, state owner, placement, trust boundaries, and failure boundaries.
5. **Prerequisites:** What can I explain already? What must I look up?
6. **Constraints:** Hardware, cost, data sensitivity, scope, and load assumptions.
7. **Alternatives:** What is the simplest viable alternative? What disadvantage am I accepting?
8. **Prediction:** What observable result should occur? What result would disprove my explanation?

## Command/change review

| Command or change | Purpose | State read or changed | Expected result | Recovery or reversal |
|---|---|---|---|---|
| Fill before execution | | | | |

Record account, cluster/context, namespace, and target paths where relevant. Use synthetic data for failure experiments.

## Experiment and evidence

- Baseline and measurement method:
- One change applied:
- Actual result and evidence:
- Difference from prediction:
- Controlled failure:
- Observed symptom:
- Hypotheses considered:
- Evidence that rejected/supported each hypothesis:
- Recovery and verification:
- Cleanup and remaining resources:

## Architecture decision record

- Decision and status:
- Context and alternatives:
- Consequences, including operating effort and cost:
- Supporting evidence:
- Condition that would make me revisit the decision:

## Teach back without notes

Explain the mechanism in two minutes. Redraw the path. Defend one tradeoff. Predict behavior if one assumption changes. State what the experiment did not prove.

## Delayed review

| Planned date | Closed-note task | Actual result | Error/hint needed | Next review |
|---|---|---|---|---|
| | Explain mechanism | | | |
| | Rebuild a small example | | | |
| | Diagnose a related failure | | | |
| | Transfer to another stack/environment | | | |
