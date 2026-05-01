# Sprint 02 Notes - Navigation & Avoidance
Date: 2026-05-01
Status: Implemented

## Goal
Improve large-unit movement reliability with separation steering and stuck recovery.

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
- `script/SupplyTruck.gd`
- `script/DebugHUD.gd`

## Validation Notes
- Command execution and movement flow compile cleanly.
- Lint check passed for updated scripts.

## Follow-up
- Run stress playtests with 50+ unit movement and repeated command spam.
- Tune exposed navigation parameters per-map after first benchmark pass.
