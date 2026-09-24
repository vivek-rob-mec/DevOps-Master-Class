# Lab: explain a forecast release and recover a failed batch

Run commands from this project folder using `..\.venv\Scripts\python.exe` on Windows. Install through the track quick start first.

1. **Design first.** Draw sales history -> features -> model -> forecast store -> planner. Explain why recorded sales may differ from unmet demand. Identify the state that must survive an API restart.
2. **Predict the baseline.** Read `generate`, `features`, and `rows` in `app.py`. Calculate one seasonal-naive prediction manually. Explain which data exists at the forecast origin and why a rolling statistic must not include its target.
3. **Train without deploying.** Run `run.py train`. Open the new release's `dataset.json`, `splits.json`, and `metrics.json` in `state/releases/ID/`. Explain the validation/holdout difference. Identify whether the candidate passed each gate and which method is eligible.
4. **Deploy deliberately.** Run `run.py promote --release ID`, then the explicit forecast command in the README. Start `run.py serve`, inspect `/report` and `/v1/forecasts/SKU-000`, and compare the published release ID with the active model. Stop/restart the API and show the forecasts persist.
5. **Break and recover.** Run `run.py exercise`. Explain why a failure just before publication cannot expose only half a batch. Describe how rollback differs from recalculating published forecasts.
6. **Defend the result.** Compare model error with the inventory simulation. Explain why better validation error does not guarantee lower holdout error or inventory cost. Preserve a rejected result rather than changing the final holdout to obtain a win.

Deliver: one diagram, one manually calculated feature/prediction, release ID and checksums, baseline/candidate report, batch failure evidence, and a two-minute explanation recorded without notes. After a delay, rebuild the smallest example with another product and explain a stale forecast.

Continue with [PLANNER-WALKTHROUGH.md](PLANNER-WALKTHROUGH.md): use the full dashboard, save stock and decisions, reproduce a two-tab revision conflict, and trace the UI through the API to SQLite. Repeat its recall exercises after 1, 3, 7, and 14 days.
