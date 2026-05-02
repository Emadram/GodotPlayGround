# Sprint 10 — Power and production rules
Date: 2026-05-01  
Status: **Implemented** — low power blocks new training and pauses in-progress timers.

## Goal
Make the power economy legible: players cannot queue through a deficit, and active production stalls until capacity returns.

## Rules (locked)
- **Deficit:** `GameManager.power_used > GameManager.power_available` → **low power** ([`GameManager.is_power_low`](../script/GameManager.gd)).
- **New queues:** [`ConstructionSite.queue_unit`](../script/ConstructionSite.gd) returns `false` with a log line when low power (after unit data validation, before cash/CP spend).
- **Active production:** [`ConstructionSite._process_production`](../script/ConstructionSite.gd) does not decrement the build timer while low power (timer resumes when a plant completes or demand drops).
- **Construction:** new foundations are **not** blocked by low power in this sprint (per roadmap scope).

## Benchmark (fill in playtest)
| Step | Pass |
|------|------|
| Barracks + depot online, **no** extra plant → power in deficit | Train buttons disabled / queue rejected |
| Start Ranger production → timer **stalls** in red | Timer holds until a Power Plant completes |
| After surplus restored → timer **continues** and unit spawns | |

Regression list: [`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §3 and §10.

## Files
- [`script/GameManager.gd`](../script/GameManager.gd) — `is_power_low()`
- [`script/ConstructionSite.gd`](../script/ConstructionSite.gd) — gate + pause
- [`script/Player_Interface.gd`](../script/Player_Interface.gd) — `power_low` in building bar state
- [`script/DebugHUD.gd`](../script/DebugHUD.gd) — stats line + train affordance
