# Sprint 11 — Match outcomes and flow
Date: 2026-05-01  
Status: **Implemented** — elimination victory, attrition defeat, full-screen overlay, restart.

## Rules
- **Victory:** At least one enemy **living combat** unit (`can_attack()` true, not dead / not 0 HP) was present this match, then **zero** remain on the enemy team ([`MatchDirector`](../script/MatchDirector.gd)). Dying units are ignored as soon as `is_dead` or `current_health <= 0` so victory is not blocked by the post-death `queue_free` delay in [`testunit.die()`](../script/testunit.gd).
- **Defeat:** The player fielded at least one friendly **living** combat unit, then **none** remain (alive + can_attack), while the enemy still has at least one **living** combat unit.
- **Non-combat** units (dozer, truck) do not count toward combat totals.
- **Match end:** [`GameManager.end_match`](../script/GameManager.gd) sets `VICTORY` / `DEFEAT`, pauses the scene tree, and raises the overlay.
- **Restart:** Reloads `world.tscn` via `get_tree().reload_current_scene()` (unpauses first).

## Files
- [`script/MatchDirector.gd`](../script/MatchDirector.gd)
- [`script/GameManager.gd`](../script/GameManager.gd) — idempotent `end_match`, `start_match` clears pause
- [`scene/world.tscn`](../scene/world.tscn) — `MatchDirector` node

## Validation
See [`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §8.
