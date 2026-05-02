# Sprint 06 — Fog of War, UI, and presentation handoff
Date: 2026-05-01  
Status: **In progress** — core FoW + tactical **minimap** shipped; **inspect panel** (selection readout) + **minimap zoom** (scroll wheel) landed in execution pass; further art polish remains optional.

## Purpose of this document
Sprint 6 spans **visibility**, **terrain readability**, and **unit/building presentation**. As systems accumulate, this file is the **single sprint handoff**: what shipped, where it lives, how it interacts with other layers, and what to validate next. Pair with **`docs/project-notes.md`** for roadmap-wide state. **How to use** the minimap, inspect readout, and HUD in play: **[`docs/player-guide.md`](player-guide.md)**.

## Goal (from plan)
Improve battlefield readability and decision speed through consistent visibility rules, clearer construction feedback, and readable unit visuals—without blocking later minimap or dedicated UI panels.

## What was implemented (summary)

### Fog of war — gameplay
- **`GameManager._update_fog_of_war`**: Team **1** units in group `units` plus non-ghost **`buildings`** with `team_id == 1` act as vision sources. Enemies are **`visible = false`** when no source’s `get_vision_range()` circle contains them. `[Fog]` prints on visibility changes.
- **`_is_position_visible`**: Generic circle test; range defaults to **12** unless the source implements **`get_vision_range()`**.
- **Combat**: Auto-targeting skips enemies that are not `visible` (see `testunit` target scan).

### Fog of war — terrain (visual)
- **`FogOfWarOverlay`** (`script/FogOfWarOverlay.gd`): Child of the ground `MeshInstance3D` in `world.tscn`. Each frame packs up to **32** circles **`(world_x, world_z, radius, 0)`** into shader uniform `vision_packed`; **units first**, then **buildings** (same filters as `GameManager`).
- **`shader/fog_of_war_overlay.gdshader`**: Unshaded translucent overlay; **revealed** = inside any circle (soft edge via `edge_softness`).

### Building vision (data + site)
- **`BuildingData.sight_range`**: Per-building vision radius (default **12**); tune in `.tres` files.
- **`ConstructionSite.get_vision_range()`**: **0** for ghosts; otherwise **`building_data.sight_range`**. Keeps overlay and enemy reveal aligned.

### Infantry presentation (`testunit.gd` + `scene/testunit.tscn`)
- **Health bar**: Stays under unit root (not skinned mesh child). **Y-billboard** + **no depth test** + **cull disabled** on bar materials so it stays visible from the RTS camera; bar always shown, fill reflects HP.
- **Animation policy**: **Hold** forces guard-style idle before selected/social idle. **`_has_nearby_friendly_infantry`** ignores friendlies in **GUARD** or **hold** so guards do not trigger **Idle_Talking** on neighbors.
- **Ranger rifle visual**: **`weapon_data.id == "rifle"`** loads **`res://gltf/Pistol_5.obj`** (requires **`gltf/Pistol_5.obj.import`**). Scaled to **`pistol_grip_target_length`**, rigged to skeleton bone **`hand_r`** via **`BoneAttachment3D`** when `Soldier_02` skeleton is present; else socket fallback under `WeaponProp`. Rocket keeps procedural boxes.
- **Code comments**: Short section headers at weapon setup, FoW-related animation rules, health fill anchoring, and file role—see source for details.

### HUD minimap (`MinimapView` + `DebugHUD`)
- **[`script/MinimapView.gd`](../script/MinimapView.gd)** on **`DebugHUD`** in [`scene/world.tscn`](../scene/world.tscn): draws **team 1** units/buildings always; **enemies** only when `visible` (same as gameplay FoW); **other-team buildings** only when `GameManager.is_position_revealed_to_team` is true. **LMB** pans camera. Bounds default **±38** XZ; size **~290×290** (tune in scene exports).

### Construction site labels (`scene/construction_site.tscn`)
- **Progress** (`ProgressLabel`): **Black** text, **larger font**, **white outline** for contrast on dark FoW / ground.
- **Cancel**: Slightly larger font; color unchanged for affordance.

## Architecture map (quick)
```
GameManager._update_fog_of_war
  ├─ sources: units (team 1) + buildings (team 1, not ghost)
  └─ enemy.visible from _is_position_visible

FogOfWarOverlay._fill_vision_buffer  →  shader vision_packed / vision_count

ConstructionSite.get_vision_range  ←  BuildingData.sight_range

testunit: vision via unit_data.sight_range; weapon + health + animation branches
```

## Files touched (this sprint scope)
| Area | Files |
|------|--------|
| FoW logic | `script/GameManager.gd` (`get_fog_sources_for_team`, `is_position_revealed_to_team`, minimap parity) |
| Terrain FoW | `shader/fog_of_war_overlay.gdshader`, `script/FogOfWarOverlay.gd`, `scene/world.tscn` |
| Building vision | `script/data/BuildingData.gd`, `script/ConstructionSite.gd` |
| Infantry / weapon / UI-adjacent | `script/testunit.gd`, `scene/testunit.tscn` |
| HUD minimap | `script/MinimapView.gd`, `scene/world.tscn` (`DebugHUD/MinimapView`), `script/Player_Interface.gd` |
| Asset import | `gltf/Pistol_5.obj`, `gltf/Pistol_5.obj.import` |

## Validation checklist (before treating Sprint 6 as “done”)

Numbered checks + cross-regression: **[`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §5–§6**.

## Sprint 6 product decisions (roadmap execution, 2026-05-01)

**Health bar at full HP:** Keep **always visible** for prototype RTS readability; optional later pass: fade at full HP or show on damage only — log product choice if changed.

**Minimap (baseline):** tactical blips + click-to-pan implemented (see **HUD minimap** above). Frame/zoom/minimap-textures = optional **Sprint 6b** polish.

**Dedicated inspect panels:** still **Sprint 6b** (see [`project-notes.md`](../project-notes.md)).

**Vision edge playtest (manual):** steps in **[`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §5**.

**FoW + construction regression:** place building → % and cancel labels → enemy remains hidden until **combined** unit + completed-building vision.

## Known gaps / next (still Sprint 6b or early Sprint 7)
- **Dedicated unit/building inspect panels** — Sprint 6b.
- **FoW for other teams** if multiplayer: `friendly_team_id` and team `1` literals need data-driven faction.
- **Documentation habit**: after each meaningful chunk, extend **this** sprint note + **`project-notes.md`** “Current State” and “Checkup” so complexity stays navigable.

## Handoff to next sprint
Visibility and presentation hooks are stable enough to drive **ability UI** (Sprint 7): show cooldowns and targets using the same “clear state, no ambiguity” bar established here.
