# Player guide — prototype RTS (RtsFirst)

Date: 2026-05-01  
Audience: Playtesters and developers running the game in the editor or an exported build.

For roadmap and engineering detail, see [`project-notes.md`](project-notes.md). For **adding or swapping maps**, see [`world-scene-workflow.md`](world-scene-workflow.md).

---

## 1. Camera and view

| Input | Action |
|--------|--------|
| **W / S / A / D** | Pan camera forward / back / left / right (`camera_forward`, etc.). |
| **Mouse wheel up / down** | Zoom in / out (`camera_zoom_in` / `camera_zoom_out`). |
| **Q / E** | Rotate view left / right (`camera_rotate_left` / `camera_rotate_right`). |
| **Middle mouse (hold)** | Mouse orbit rotate (`camera_rotate_mouse`). |

---

## 2. Selection and orders

| Input | Action |
|--------|--------|
| **Left click** | Select unit or building (`mouse_leftclick`). Drag for box selection (where enabled). |
| **Right click** | Context order: move on ground, attack enemy, guard friendly, harvest dock (selected truck), resume construction on unfinished site (dozer). |
| **Shift + right click** | Queue order after current orders (append to queue). |
| **Double-click** a unit | Select all units of the same type currently visible (see baseline checks in [`project-notes.md`](project-notes.md)). |

Bottom **command bar** (when you have a selection): **Stop** (**X**), **Hold** (**H**), **Attack Move** (**R**), **Guard** (**G**). Combat-only buttons hide for non-combat units.

---

## 3. Builders and construction

1. Select a **dozer**.
2. Use **Build CC / Power / Barracks / Supply** HUD buttons, or press **B** for Command Center ghost (`build_mode` — wire may target default building from [`Player_Interface`](../script/Player_Interface.gd)).
3. **Left click** valid ground to place the ghost; invalid placement shows red feedback.
4. The dozer paths to the site and builds. **Right-click** an unfinished site with a stopped dozer to **resume** construction.
5. **Buildings cost cash only** (no command points). Cancel during build refunds **partial cash** (see [`ConstructionSite`](../script/ConstructionSite.gd)).

---

## 4. Economy (supply)

- Select the **supply truck**, **right-click** the **supply dock** to harvest.
- Truck uses **navigation** to reach the dock and a **dropoff** to unload; keep dock collision scale reasonable so the truck can approach (see [`sprint-02` notes](sprint-02-navigation-avoidance-notes.md)).
- Global **cash** and passive **secondary income** are shown on the debug HUD stats block ([`GameManager`](../script/GameManager.gd)).

---

## 5. Power and training

- HUD shows **Power: used / available**. Completing a **power plant** raises available power; powered structures consume power when they come online.
- **Low power** (`used > available`): you **cannot enqueue** new units at production buildings; any **active** training timer **pauses** until you have surplus again. See [`sprint-10-power-production-notes.md`](sprint-10-power-production-notes.md).
- **Training** spends **cash** and may spend **command points (CP)** per unit data ([`UnitData.command_point_cost`](../script/data/UnitData.gd)). **Buildings do not cost CP** to place.

---

## 6. Commander abilities and CP

- **CP** and cooldowns are tracked by [`AbilityProgression`](../script/AbilityProgression.gd); definitions live in [`data/commander_abilities.json`](../data/commander_abilities.json).
- **F5 / F6 / F7** — cast abilities in slots 0–2 (`commander_ability_1` … `3`).
- **F** — ground-targeted **airstrike** path aligned with the ability system (`airstrike`).
- **Comma** — toggle **radial commander menu** (`commander_radial_toggle`); **Esc** closes it when open.
- **Promotions** feed CP over time; some abilities unlock after milestones (e.g. HQ complete). Details: [`sprint-07-abilities-notes.md`](sprint-07-abilities-notes.md).

---

## 7. Match flow (skirmish)

- **Victory:** All **living** enemy combat units eliminated (death counts immediately, not only after the corpse is removed from the scene). [`MatchDirector`](../script/MatchDirector.gd).
- **Defeat:** You had at least one friendly combat unit alive, then **none**, while enemies still have a living combat unit.
- **Restart mission** on the end overlay reloads the current main scene and unpauses.
- **P** — toggle pause (`game_pause`); [`GameManager`](../script/GameManager.gd) uses `PROCESS_MODE_ALWAYS` so pause/unpause stays reliable.

---

## 8. HUD reference

| Element | Role |
|---------|------|
| **Large stats block** (bottom area) | FPS, unit counts, resources, power line (shows **LOW POWER** when in deficit), promotions, CP, game state, production debug line. |
| **Ability bar** (above command row) | Commander powers + cooldown rings. |
| **Command bar** | Stop, hold, attack-move, guard, build shortcuts. |
| **Building bar** (right, when a production building is selected) | Train buttons, queue list, cancel **X**; train disabled when low power. |
| **Inspect panel** (top-left, single selection) | Unit: type, weapon/armor IDs, HP. Building: id, design HP, power +/-, construction % or training queue. |
| **Minimap** (top-right) | Friendly blips always; enemies follow fog rules. **Left click** pans camera. **Mouse wheel** zooms view bounds on the minimap. |

---

## 9. Validation checklists

- Full regression matrices: [`sprint-09-review-qa-notes.md`](sprint-09-review-qa-notes.md).
- Power rules: [`sprint-10-power-production-notes.md`](sprint-10-power-production-notes.md).
- Match end smoke: **§8** in sprint-09.

If something in this guide drifts from `project.godot` input bindings, treat **`project.godot` `[input]`** as source of truth and update this file in the same commit.
