# Sprint 1 Notes
Date: 2026-05-01

## Scope (In Progress)
- Disable command hotkeys pending final rebind decision.
- Add HUD buttons for Stop, Hold, Guard.
- Add persistent attack-move mode cursor indicator.
- Add HUD button to activate attack-move mode.

## Changes
- Commented input actions: attack_move, command_stop, command_hold, command_guard.
- Added HUD buttons and wiring in DebugHUD.
- Added attack-move cursor label that follows the mouse while attack-move mode is active.
- Added Attack Move HUD button to arm attack-move orders.

## Test Checklist
- Select units and click Stop, Hold, Guard buttons.
- Guard flow: press Guard button, then click a friendly unit to guard it.
- Attack-move: press Attack Move button, verify indicator shows and next click issues attack-move.

## Notes / Gaps
- Attack-move mode is activated via HUD button while hotkeys are disabled.
- HUD layout is basic and may need final art pass.

## Sprint Review (Partial)
- Status: done for current tasks.
- Risk: choose final hotkey mapping to complement HUD controls.
- Next: playtest command UI and adjust layout/spacing.
