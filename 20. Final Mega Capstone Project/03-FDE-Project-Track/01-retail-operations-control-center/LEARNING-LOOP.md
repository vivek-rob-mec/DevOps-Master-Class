# Learn, retrieve, and transfer

The aim is to become able to reconstruct the reasoning and recover forgotten details. Completing a walkthrough once is not evidence that you can operate or redesign the system independently.

## Session record

Copy this template into your own notes for each experiment:

```text
Date / exercise:
Customer problem:
What I predict will happen:
Why I predict it:
Command or UI steps:
Actual result / evidence:
What I misunderstood:
Design tradeoff:
How I would recover in a real deployment:
Next recall date:
```

## Repeat without the guide

| When | Retrieval exercise | Check your explanation against |
| --- | --- | --- |
| End of first session | Draw the full import-to-review flow; calculate Coffee's recommendation | HLD and forecast function |
| Next day | Explain request IDs, content hashes, write transactions, and stale reviews without reading | LLD and concurrency tests |
| Three days later | Reproduce an invalid import and a queued job with the worker stopped | Walkthrough; saved database evidence |
| One week later | Explain how a crashed worker is replaced and why its late result is rejected | Lease/token tests |
| Two weeks later | Design a two-warehouse change before opening the code | Customer brief change request |
| One month later | Rebuild a small CSV validator and retry-safe command handler in a separate scratch directory | Compare behavior with the acceptance criteria |

Adjust the intervals when recall is too easy or too difficult; this is a practice schedule, not a promise of permanent memory.

## Questions you should answer in an interview or handoff

1. What makes this a customer delivery exercise rather than merely a forecasting demo?
2. Why must sales and inventory publish together?
3. What happens if an import succeeds but its response is lost?
4. Why must retrying an old import not restore it as the current snapshot?
5. Can two workers execute a job? How many completions can be accepted?
6. Why does API readiness not establish worker health?
7. Which assumptions make 115 a recommendation rather than an executable order?
8. Why does the final observed week belong in the backtest target, not its input prediction?
9. Which business outcomes are unmeasured here?
10. What must change before connecting the existing Demand Desk to customer data?
11. Where would identity, authorization, and tenant boundaries be enforced?
12. How would you prove a restore preserved both decisions and their source evidence?

Score each answer 0 (cannot explain), 1 (can explain with notes), or 2 (can explain and demonstrate without notes). Revisit low scores with an experiment. Keep the code available for verification, but try the explanation first.
