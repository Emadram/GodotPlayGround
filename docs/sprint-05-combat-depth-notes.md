# Sprint 05 Notes - Combat Depth
Date: 2026-05-01
Status: Implemented

## Goal
Add tactical combat differentiation while keeping commands readable and debuggable.

## Planned Scope
- Add weapon type data and armor damage modifiers.
- Apply armor modifiers during projectile damage resolution.
- Add explicit target priority rules for auto-targeting.
- Keep existing veterancy bonuses and make combat transitions easier to debug.

## Progress Log
- Sprint note initialized before implementation.
- Added `damage_type` to `WeaponData`.
- Added armor modifier lookup during projectile damage application.
- Added default infantry armor modifiers for `small_arms`, `explosive`, and `cannon`.
- Added target priority scoring for auto-targeting:
  - combat-capable units are prioritized,
  - builder units are secondary targets,
  - low-health and closer targets gain priority.
- Added concise combat debug prints:
  - `[Combat] <unit> took <amount> <damage_type> damage`.
- Added `Rocket Soldier` as a second Barracks-produced combat unit for matchup testing.
- Added `rocket_launcher` weapon using `explosive` damage.
- Added `light_vehicle` armor data for upcoming vehicle matchup tests.
- Ranger and Rocket Soldier share the same `Soldier_02.glb` animation/model logic.
- Rocket Soldier uses a gray visual tint to distinguish it from Ranger.
- Produced units now receive their `UnitData` before entering the scene, so weapon/armor/tint/animation setup applies correctly.
- Test platform and camera-visible area were enlarged for combat testing.
- Added a team 2 `EnemyRanger` in the test scene as an immediate combat target.
- Ranger unit scene now uses `gltf/Soldier_02.glb`.
- Unit animation playback maps to the requested soldier animations:
  - idle: `Idle`
  - nearby friendly idle: `Idle_Talking`
  - selected: `Pistol_idle`
  - movement: `walk_formal`
  - guard: `crouch_idle`
  - attack/attack-move firing: `Pistol_shoot`
  - death: `Death01`
- Added `[UnitAction]` prints for combat unit movement, attack targeting, firing, stop/hold, and target acquisition.
- `Soldier_02.glb` is imported with animation import enabled.
- Selected combat units show fire range and vision range rings.
- Infantry personal-space separation was strengthened so units avoid stacking on top of each other.

## Files Updated
- `script/data/WeaponData.gd`
- `script/Projectile.gd`
- `script/testunit.gd`
- `scene/testunit.tscn`
- `data/weapons/rifle.tres`
- `data/weapons/rocket_launcher.tres`
- `data/armors/infantry.tres`
- `data/armors/light_vehicle.tres`
- `data/units/usa_rocket_soldier.tres`
- `data/units/usa_ranger.tres`
- `script/data/UnitData.gd`
- `scene/world.tscn`

## Validation Notes
- Lint check passed for updated combat scripts.
- Runtime validation still needed for target priority and matchup feel.
- Skirmish matrix, armor log, `light_vehicle` deferral: **[`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §4**.
