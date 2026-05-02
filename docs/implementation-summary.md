# Implementation summary (consolidated)

Date: 2026-05-01  
Purpose: One-page record of **major gameplay and documentation work** delivered in recent iterations (abilities HUD through skirmish loop, docs, and fixes). For day-to-day roadmap detail, keep using [`project-notes.md`](project-notes.md).

---

## Commander abilities and CP

- **JSON-driven abilities** (`data/commander_abilities.json`) loaded by [`AbilityProgression`](../script/AbilityProgression.gd); effects via [`CommanderEffectLibrary`](../script/CommanderEffectLibrary.gd) (airstrike, supply drop, grant resources, extensible `register_*`).
- **CP** on **unit training** only ([`UnitData.command_point_cost`](../script/data/UnitData.gd), spend/refund in [`ConstructionSite`](../script/ConstructionSite.gd)); **buildings do not use CP** (removed from [`BuildingData`](../script/data/BuildingData.gd), [`Dozer`](../script/Dozer.gd), building `.tres`).
- **HUD:** ability bar with cooldown rings ([`AbilityCooldownOverlay`](../script/AbilityCooldownOverlay.gd)), radial menu ([`CommanderRadialMenu`](../script/CommanderRadialMenu.gd)), hotkeys F5–F7 / F / comma; wired through [`Player_Interface`](../script/Player_Interface.gd) and [`DebugHUD`](../script/DebugHUD.gd).
- **Unlocks** from completed structures (`AbilityProgression.notify_structure_completed`). Sprint detail: [`sprint-07-abilities-notes.md`](sprint-07-abilities-notes.md).

---

## Pause

- **`game_pause` (P)** toggles match pause via [`GameManager`](../script/GameManager.gd): `PROCESS_MODE_ALWAYS`, `_unhandled_input`, `toggle_pause()` / `get_tree().paused`. Ignored in VICTORY / DEFEAT / BOOT.

---

## Power and production (Sprint 10)

- **Low power** when `power_used > power_available` ([`GameManager.is_power_low()`](../script/GameManager.gd)).
- **New training** blocked in [`ConstructionSite.queue_unit`](../script/ConstructionSite.gd); **active production timer pauses** in `_process_production` until surplus returns.
- **HUD:** `LOW POWER` in stats; building bar disables train buttons and shows queue stall. Notes: [`sprint-10-power-production-notes.md`](sprint-10-power-production-notes.md).

---

## Match outcomes (Sprint 11)

- [`MatchDirector`](../script/MatchDirector.gd) on [`world.tscn`](../scene/world.tscn): **victory** when all **living** enemy combat units are gone (after at least one existed); **defeat** when the player had combat units, has none left, and enemies remain.
- **Living combat** excludes dead units (`is_dead`, `current_health` ≤ 0, `get_health_ratio` ≤ 0) so victory is not delayed until `queue_free()` after the death animation timer in [`testunit.die()`](../script/testunit.gd). `Node.get()` uses a single argument (GDScript 4).
- **Overlay** (layer 110) + **Restart mission** (`reload_current_scene`). [`GameManager.end_match`](../script/GameManager.gd) pauses tree and is idempotent; `start_match` clears pause.
- Notes: [`sprint-11-match-outcomes-notes.md`](sprint-11-match-outcomes-notes.md); QA §8 in [`sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md).

---

## Skirmish AI (Sprint 12)

- [`EnemyBrain`](../script/EnemyBrain.gd): periodic **attack-move** for team 2 toward friendly team-1 centroid (only while `GameManager.state == RUNNING`).

---

## UI polish (Sprint 6b scope)

- **Inspect panel** (top-left): single-selection readout from [`Player_Interface.get_inspect_panel_state()`](../script/Player_Interface.gd); building data via [`ConstructionSite.get_inspect_summary()`](../script/ConstructionSite.gd).
- **Minimap:** scroll-wheel **zoom** on world bounds ([`MinimapView`](../script/MinimapView.gd)).
- Sprint handoff: [`sprint-06-fog-of-war-ui-notes.md`](sprint-06-fog-of-war-ui-notes.md).

---

## Documentation and workflow

| Doc | Role |
|-----|------|
| [`player-guide.md`](player-guide.md) | Controls, economy, power, build/train, abilities, match flow, HUD. |
| [`world-scene-workflow.md`](world-scene-workflow.md) | Duplicating maps, **Main Scene** swap, required nodes/groups, regression pointer. |
| [`sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) | Consolidated QA matrices; §8–§10 updated for match end, AI smoke, power. |
| [`sprint-08-lockstep-notes.md`](sprint-08-lockstep-notes.md) | Phase 0 note to record **Main Scene** when multiple worlds exist. |
| [`project-notes.md`](project-notes.md) | Top links to player guide + workflow; map-scene bullet; cadence note for re-running sprint-09 on new main scenes. |

---

## Primary code touchpoints (quick index)

| System | Files |
|--------|--------|
| Match + pause | [`GameManager.gd`](../script/GameManager.gd), [`MatchDirector.gd`](../script/MatchDirector.gd) |
| Enemy macro | [`EnemyBrain.gd`](../script/EnemyBrain.gd) |
| Production + power | [`ConstructionSite.gd`](../script/ConstructionSite.gd) |
| Build (cash only) | [`Dozer.gd`](../script/Dozer.gd), [`BuildingData`](../script/BuildingData.gd), `data/buildings/*.tres` |
| HUD | [`DebugHUD.gd`](../script/DebugHUD.gd), [`MinimapView.gd`](../script/MinimapView.gd) |
| Input | [`project.godot`](../project.godot) `[input]` |
| World wiring | [`scene/world.tscn`](../scene/world.tscn) |

---

## Still open (high level)

- Deeper **Sprint 7** polish (radial art, benchmarks filled from playtests). **Sprint 8** lockstep remains a stub until determinism spike.
- **New map scene** as a real duplicate of `world.tscn` (optional file) when art/terrain is ready—workflow is documented only until then.
- Runtime tuning: navigation stress, combat balance, FoW edge cases—see sprint notes and sprint-09 matrices.

This file is a **snapshot summary**; individual sprint docs remain authoritative for benchmarks and checklists.
