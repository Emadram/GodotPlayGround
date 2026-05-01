# Sprint 06 — Fog of War, UI, and presentation handoff
Date: 2026-05-01  
Status: **In progress** (core FoW + presentation done; minimap / full UI spec still open)

## Purpose of this document
Sprint 6 spans **visibility**, **terrain readability**, and **unit/building presentation**. As systems accumulate, this file is the **single sprint handoff**: what shipped, where it lives, how it interacts with other layers, and what to validate next. Pair with **`docs/project-notes.md`** for roadmap-wide state.

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
| FoW logic | `script/GameManager.gd` |
| Terrain FoW | `shader/fog_of_war_overlay.gdshader`, `script/FogOfWarOverlay.gd`, `scene/world.tscn` |
| Building vision | `script/data/BuildingData.gd`, `script/ConstructionSite.gd` |
| Infantry / weapon / UI-adjacent | `script/testunit.gd`, `scene/testunit.tscn` |
| Construction labels | `scene/construction_site.tscn` |
| Asset import | `gltf/Pistol_5.obj`, `gltf/Pistol_5.obj.import` |

## Validation checklist (before treating Sprint 6 as “done”)
1. Enemy pops in/out at vision edge; no stuck-visible after killer leaves range.
2. **Building** completes → contributes vision; **ghost** never does.
3. **Fog overlay** circles align with unit/building positions (no large offset vs gameplay reveal).
4. **32+** simultaneous sources: confirm cap behavior (oldest priority = units first pass, then buildings).
5. **Pistol** grip: acceptable from idle/walk/shoot; tweak `_pistol_bone_local_transform` / exports if clips appear.
6. **Progress / cancel** labels readable at typical zoom.

## Known gaps / next (still Sprint 6 or early Sprint 7)
- **Minimap** and **dedicated unit/building inspect panels** (original Sprint 6 “must-have” wording)—not implemented; defer or split to a **Sprint 6b** milestone.
- **FoW for other teams** if multiplayer: `friendly_team_id` and team `1` literals need data-driven faction.
- **Documentation habit**: after each meaningful chunk, extend **this** sprint note + **`project-notes.md`** “Current State” and “Checkup” so complexity stays navigable.

## Handoff to next sprint
Visibility and presentation hooks are stable enough to drive **ability UI** (Sprint 7): show cooldowns and targets using the same “clear state, no ambiguity” bar established here.
