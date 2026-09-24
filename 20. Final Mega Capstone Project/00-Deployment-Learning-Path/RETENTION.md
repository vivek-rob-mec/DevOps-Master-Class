# Retain mechanisms through repeated use

No method guarantees you will never forget. Aim to recall important mechanisms, recognize gaps, diagnose from evidence, and reconstruct an implementation with documentation when necessary.

Spaced practice, retrieval through quizzes, worked examples alternating with problem-solving, and explanatory questions are supported by the [Institute of Education Sciences practice guide](https://ies.ed.gov/ncee/wwc/PracticeGuide/1). The schedule below is a practical starting routine, not a scientifically prescribed interval for every learner.

## Review small concepts

After a lab, try reviews around days 1, 3, 7, 14, and 30. Adjust gaps to actual recall and available time. If recall fails, correct the underlying explanation and bring the next review closer.

| Review | Activity before looking at your solution |
|---|---|
| End of lab | Draw the mechanism; write three questions with answers stored separately |
| Day 1 | Answer the questions and explain the experiment |
| Day 3 | Reconstruct the smallest useful example with your configuration hidden |
| Day 7 | Diagnose a related failure with a changed port, dependency, or symptom |
| Day 14 | Apply the idea to a different runtime or placement |
| Day 30 | Explain the design and recover the example in an integrated exercise |

Make a prediction before consulting documentation. Exact syntax can be looked up; independent reasoning is the target.

## Track demonstrated ability

Use [progress.csv](progress.csv), one row per concept or experiment. Fill actual dates and evidence paths. The initial row is uncompleted, not an assertion of mastery.

- **0:** Cannot explain yet.
- **1:** Recognizes the explanation while reading.
- **2:** Explains independently but needs build/diagnosis hints.
- **3:** Builds and diagnoses the practiced example, using documentation for syntax.
- **4:** Transfers the idea to changed conditions and explains the tradeoff.

Use two separated score-3 attempts plus one successful variation as a practical competence checkpoint. This is a local learning rubric, not an external certification or a validated scientific threshold.

## Ask causal questions

| Topic | Retrieval question |
|---|---|
| Readiness | A process is alive but cannot serve requests. Should it restart or stop receiving traffic, and why? |
| Networking | The service works inside its container but not from the host. Which addresses, listeners, and mappings do I inspect? |
| Idempotency | A worker sees the same event twice. Where is duplicate suppression enforced, including after a crash? |
| GitOps | A manual rollback succeeds, then disappears. Which actor may have restored the previous desired state? |
| Cross-site recovery | Both application sites are alive but their data link fails. Who may write, and how do we avoid conflicting authority? |

For a roughly 60-minute session, try 10 minutes of recall, 10 of focused theory/design, 30 of one experiment, and 10 of evidence and explanation. Adjust this example to your schedule; no weekly time commitment has been assumed.

Revisit one older incident each week. Periodically rebuild a small earlier deployment from a clean disposable lab. Maintain an error log: prediction, actual result, incorrect assumption, corrected model, and a future retrieval question. Preserve real data and shared resources when resetting labs.

Use small flashcards for causal questions, diagrams for relationships, lab records for procedures, and official documentation for changing syntax. Reading finished YAML repeatedly is not equivalent to retrieving the explanation yourself.
