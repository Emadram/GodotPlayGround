# Sprint 07 Notes — General abilities & progression
Date: 2026-05-01  
Status: **In progress** — JSON commander abilities, CP on training (not buildings), hotkeys.

## Goal
Layer strategic progression (command points, unlock flags, future ability cooldowns) without destabilizing command queueing or combat.

## Start gate (met for scaffold)
- Sprint 6 **tactical minimap** and FoW baseline are in tree; full **inspect UI** remains Sprint 6b.
- Detailed benchmarks / regression tables: **[`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md)**.

## Implemented (this increment)
- **`data/commander_abilities.json`** — commander powers with optional **`params`** per `effect`. Loaded in **`AbilityProgression._ready`**; invalid file keeps defaults.
- **[`script/CommanderEffectLibrary.gd`](../script/CommanderEffectLibrary.gd)** — registry: built-in **`airstrike`** (`radius`, `damage`), **`supply_drop`** / **`grant_resources`** (`amount`); **`register_ground` / `register_instant`** for extensions.
- **CP on training** — [`UnitData`](../script/data/UnitData.gd) `command_point_cost`; spend + refunds in [`ConstructionSite`](../script/ConstructionSite.gd). **Buildings** use cash only ([`Dozer`](../script/Dozer.gd), [`BuildingData`](../script/data/BuildingData.gd)).
- **Match start:** +2 CP after `reset_for_match` in [`GameManager.start_match`](../script/GameManager.gd).
- **Unlocks:** [`AbilityProgression.notify_structure_completed`](../script/AbilityProgression.gd) from completed [`ConstructionSite`](../script/ConstructionSite.gd) (`usa_hq_complete`, `usa_barracks_online`). Example gated ability: **War Bonds** in JSON (`unlock_id: usa_hq_complete`).
- **Radial menu:** [`script/CommanderRadialMenu.gd`](../script/CommanderRadialMenu.gd); **comma** `commander_radial_toggle`, **Esc** closes ([`DebugHUD`](../script/DebugHUD.gd)).
- **Hotkeys:** F5 / F6 / F7 → slots 0–2; **F** airstrike uses **`try_cast_ground(cmd_airstrike)`** ([`Player_Interface`](../script/Player_Interface.gd)).
- **Ability bar** rebuilds when JSON slot count changes ([`DebugHUD._ensure_ability_bar`](../script/DebugHUD.gd)).

## Planned next
- Register-only custom effects via autoload or DLC scripts calling `CommanderEffectLibrary.register_*`.
- Radial polish (icons, gamepad); fill Sprint 7 benchmark table in [`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) after playtest.

## Files touched (recent)
- `data/commander_abilities.json`
- `script/AbilityProgression.gd`, `script/CommanderEffectLibrary.gd`, `script/CommanderRadialMenu.gd`
- `script/ConstructionSite.gd`, `script/Dozer.gd`, `script/GameManager.gd`
- `script/data/UnitData.gd`, `script/data/BuildingData.gd`
- `data/units/*.tres`, `data/buildings/*.tres`
- `script/DebugHUD.gd`, `script/Player_Interface.gd`
- `docs/sprint-09-review-qa-notes.md`
- `project.godot` (input: `game_pause` = P)

## Validation
- Edit JSON, reload scene: ability bar matches file.
- Queue ranger with CP=0 fails; earn CP (promotions), queue succeeds; cancel refunds CP.
- Place building: cash-only; cancel ghost build refunds cash (partial), not CP.
- **P** (`game_pause`) toggles match pause via [`GameManager`](../script/GameManager.gd) (`PROCESS_MODE_ALWAYS` so unpause works).
