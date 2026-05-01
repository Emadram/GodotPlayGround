# Sprint 04 Notes - Economy & Production
Date: 2026-05-01
Status: Implemented

## Goal
Make economy values data-driven and add the first production queue flow.

## Planned Scope
- Tie `EconomyData` into supply dock amount, truck harvest rate, and dropoff timing.
- Add basic building production queue support.
- Add a simple secondary income source for pacing tests.

## Progress Log
- Sprint note initialized before implementation.
- `EconomyData` now drives:
  - supply dock total amount,
  - supply truck gather rate,
  - supply truck dropoff timing.
- Added secondary passive income in `GameManager` for pacing tests.
- Added basic production queue support on completed construction buildings:
  - command center can queue its default produced unit,
  - resources are spent on queue,
  - unit spawns after its `UnitData.build_time`.
- Added `Train` button to debug HUD and production status readout.
- Production button is now contextual:
  - only appears when a completed production building is selected,
  - displays the unit name, such as `Ranger`, instead of generic `Train`,
  - queues production from the selected building only.
- Added right-side building bar:
  - appears only when a building is selected,
  - Barracks shows unit buttons such as `Ranger` and `Rocket Soldier`,
  - queued/active units appear under `Training`,
  - up to 10 units can be queued per production building,
  - each queued/active unit row has an `X` cancel button on the right,
  - cancelled items refund their unit cost.
- Added additional buildable structure data for Sprint 4 testing:
  - `usa_power_plant`,
  - `usa_barracks`,
  - `usa_supply_depot`.
- Supply truck visual in `scene/supply_truck.tscn` uses `gltf/NormalCar2.obj` (`MeshInstance3D` + simple material) instead of the old FBX placeholder.
- **Collision:** `supply_dock.tscn` and `dropoff_point.tscn` add `StaticBody3D` + shape matching visuals; truck root is `CharacterBody3D` with hull `BoxShape3D` (layer/mask 1).

## Files Updated
- `script/GameManager.gd`
- `script/SupplyDock.gd`
- `script/SupplyTruck.gd`
- `script/ConstructionSite.gd`
- `script/DebugHUD.gd`
- `script/Player_Interface.gd`
- `scene/world.tscn`
- `scene/supply_truck.tscn`
- `scene/supply_dock.tscn`
- `scene/dropoff_point.tscn`
- `data/buildings/usa_power_plant.tres`
- `data/buildings/usa_barracks.tres`
- `data/buildings/usa_supply_depot.tres`
- `data/units/usa_rocket_soldier.tres`

## Validation Notes
- Lint check passed for updated scripts.
- Supply truck remains economy-only; dozer remains construction-only.
