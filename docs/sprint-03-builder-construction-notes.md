# Sprint 03 Notes - Builder & Construction
Date: 2026-05-01
Status: Implemented

## Goal
Implement build placement flow with grid snapping, footprint validation, builder travel, and construction progress with power impact.

## Planned Scope
- Ghost placement preview for a selected building.
- Grid snapping for consistent placement.
- Footprint overlap validation before placement.
- Builder receives build command, travels to site, and constructs over time.
- Building construction applies power impact at defined milestones.

## Progress Log
- Added `ConstructionSite` runtime building entity with:
  - ghost vs live construction modes,
  - footprint scaling,
  - progress-based visual update,
  - power impact hooks (`power_consumed` on start, `power_provided` on completion).
- Added explicit building click areas so completed buildings can be selected reliably.
- Added `BuildingData.building_scene` so each building `.tres` can reference its own visual/object scene.
- Custom building scenes are auto-centered and uniformly scaled to fit inside the configured building footprint.
- Completed building interaction/collision areas follow the fitted mesh size instead of the original footprint.
- Buildings under construction show:
  - completion percentage,
  - an `X Cancel` label above the building.
- Clicking the construction cancel area cancels the unfinished building and refunds part of the cost.
- If a dozer stops mid-build, selecting the dozer and right-clicking the unfinished building resumes construction.
- Added placement mode in player interface:
  - `B` hotkey and debug HUD build button,
  - ghost placement preview,
  - grid snapping,
  - footprint overlap validation against units, buildings, and resource nodes.
- Added dedicated `Dozer` builder flow:
  - accepts `BUILD` command,
  - travels to target site,
  - spawns a construction site,
  - advances construction over time at build range.
- Reverted `SupplyTruck` to economy-only responsibility:
  - harvests from supply dock,
  - returns to dropoff,
  - does not construct buildings.
- Locked dozer responsibility to construction/maintenance style commands:
  - build commands are accepted,
  - move/stop are accepted for positioning,
  - attack, attack-move, and guard commands are ignored.
- Added scene and UI wiring:
  - new `scene/construction_site.tscn`,
  - new `scene/dozer.tscn`,
  - `Build CC`, `Power`, `Barracks`, and `Supply` buttons in debug command bar.
- Moved HUD/debug command bar to bottom-left with larger buttons for easier test interaction.
- Command HUD buttons now appear only when relevant:
  - general unit command buttons require a unit selection,
  - combat command buttons require a combat unit selection,
  - build button requires a selected dozer.

## Build validation matrix (Sprint 3 sign-off)

Matrix and ghost/power checks: **[`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §2**.

## Files Updated
- `script/ConstructionSite.gd`
- `script/Dozer.gd`
- `scene/construction_site.tscn`
- `scene/dozer.tscn`
- `script/Player_Interface.gd`
- `script/SupplyTruck.gd`
- `script/DebugHUD.gd`
- `scene/world.tscn`

## Validation Notes
- Lint check passed for all updated scripts.
- Build placement now rejects occupied footprint zones and is issued only to dozers.
- Built structures print `[Selection]` messages when selected or when selection misses.
- Dozers can build:
  - `usa_command_center`,
  - `usa_power_plant`,
  - `usa_barracks`,
  - `usa_supply_depot`.
- Supply trucks remain dedicated to supply collection/dropoff.
- Dozers do not attack or guard.
- Runtime validation confirmed:
  - dozer receives build order,
  - moves to build range,
  - starts construction for `usa_barracks` and `usa_supply_depot`.
- Debug convention: important runtime command transitions should print concise tagged logs such as `[Build]`, `[BuildInput]`, and `[Dozer]`.
