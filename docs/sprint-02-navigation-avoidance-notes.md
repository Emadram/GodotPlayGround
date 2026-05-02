# Sprint 02 Notes - Navigation & Avoidance
Date: 2026-05-01
Status: Implemented (Sprint 2 closeout: benchmark doc, infantry kinematic collision, stress procedure)

## Goal
Improve large-unit movement reliability with separation steering and stuck recovery.

## Sprint 2 benchmark and stress tables

All **benchmark criteria**, **results log**, and **50+ stress procedure** are maintained under **[`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §1** so this file stays implementation-focused. Update that table during review / playtest milestones.

Stress playtests with 50+ units: same Sprint 9 §1.

## Nav mesh policy (this project)

- [`scene/world.tscn`](../scene/world.tscn) uses [`script/WorldNavigationRegion.gd`](../script/WorldNavigationRegion.gd) to assign a **manual flat navigation quad** covering the play plane (reliable vs empty editor bake). Change size/height only when a measured gap appears (spawn off-mesh, dock outside quad).

## Combat unit collision (decision)

## Implemented
- Enabled configurable `NavigationAgent3D` tuning for combat units and supply trucks.
- Added friendly separation steering to reduce clumping in group movement.
- Added destination slowdown for cleaner arrivals.
- Added anti-stuck recovery with timed repath offsets.
- Added runtime benchmark signals in debug HUD:
  - moving unit count,
  - cumulative stuck recovery count.

## Files Updated
- `script/testunit.gd`
- `scene/testunit.tscn`
- `script/SupplyTruck.gd`
- `script/Dozer.gd`
- `script/DebugHUD.gd`

## Validation Notes
- Command execution and movement flow compile cleanly.
- Lint check passed for updated scripts.
- Headless world load smoke: `testunit` root is `CharacterBody3D`; full 50+ benchmark rows live in **[`docs/sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md) §1**.

## Follow-up
- Fill Sprint 9 §1 results table after first full 50+ playtest.
- Tune exposed navigation parameters per-map after benchmark pass.

## Supply truck and dock (economy path)
- Truck uses `NavigationAgent3D` plus kinematic `move_and_collide`; dock goal uses `_approach_point_outside_node()` with `resource_approach_standoff` in [`script/SupplyTruck.gd`](../script/SupplyTruck.gd).
- **Large `SupplyDock` scene scale** can make static collision dominate the standoff ring so the truck never makes progress until bumped or re-ordered; shrinking dock root scale (or widening standoff in data) fixes apparent “nav stuck” behavior when the nav mesh itself is fine.
