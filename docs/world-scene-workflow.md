# World scene workflow (multi-map)

Date: 2026-05-01  
Purpose: Add a **new playable map** (terrain, props, nav mesh) without forking gameplay code or autoloads.

## Principles

- **One main scene at a time:** Set **Project → Project Settings → Application → Run → Main Scene** to the map you are testing. Autoloads ([`GameManager`](../script/GameManager.gd), [`DataRegistry`](../script/DataRegistry.gd), [`AbilityProgression`](../script/AbilityProgression.gd)) stay global; do not duplicate them in the scene tree.
- **Clone structure, replace geography:** Start from [`scene/world.tscn`](../scene/world.tscn) (or a saved duplicate such as `scene/world_skirmish_01.tscn`) so node names and paths used by UI scripts stay valid.

## Required / expected nodes

| Area | Why |
|------|-----|
| Root `Node3D` (e.g. `World`) | Typical root for 3D map content. |
| [`Player_Interface`](../script/Player_Interface.gd) | Selection, camera, orders; path `../Player_Interface` from [`DebugHUD`](../script/DebugHUD.gd). |
| `DebugHUD` (`CanvasLayer`, script `DebugHUD.gd`) | Command bar, stats, ability bar, building bar, inspect panel; `player_interface_path` must point at `Player_Interface`. |
| `MinimapView` (child of `DebugHUD`) | Uses same `player_interface_path`; tune [`world_min_xz` / `world_max_xz`](../script/MinimapView.gd) to your playfield. |
| `MatchDirector` + `EnemyBrain` | Skirmish end state and periodic enemy orders ([`MatchDirector.gd`](../script/MatchDirector.gd), [`EnemyBrain.gd`](../script/EnemyBrain.gd)). |
| `NavigationRegion3D` | Units/trucks use navigation; **bake** the mesh after editing terrain/obstacles. |
| `FogOfWarOverlay` (if used) | Keep aligned with ground mesh and vision logic from [`GameManager`](../script/GameManager.gd). |

## Groups used by systems

- **`units`** — Anything counted for FoW, minimap, match combat tallies (`MatchDirector`). Combat units need `team_id`, `can_attack()`, and lifecycle fields (`is_dead`, `current_health`) for correct victory detection.
- **`buildings`** — Construction sites / completed structures for FoW and minimap.
- **`builders`** — Dozers (build commands from [`Player_Interface`](../script/Player_Interface.gd)).

Economy smoke tests still expect a **supply dock**, **dropoff**, and **truck** with valid node paths if you copy the full economy slice from `world.tscn`.

## Regression when switching maps

Run **[`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §8–§9** (match end + skirmish AI) on each scene you set as **Main Scene** before merging.

## Optional next step

Add `scene/world_skirmish_01.tscn` as a real duplicate of `world.tscn`, swap only terrain/meshes/nav, and point **Main Scene** at it during map authoring sprints.
