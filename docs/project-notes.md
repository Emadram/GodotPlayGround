# Project Notes (Consolidated)
Date: 2026-05-01

## Current State (High Level)
- Core RTS loop is prototyped: unit selection, move/attack orders, and basic combat are working.
- Command queueing exists with context-sensitive orders (move/attack/guard/harvest) and formation spacing.
- Basic economy is in place: supply dock, supply truck (`gltf/NormalCar2.obj` mesh), and dropoff are functional; dock, dropoff, and truck use **physics collision** (`StaticBody3D` / `CharacterBody3D`) for blocking and queries.
- Promotions and global resources/power are tracked at game level; a basic airstrike is available.
- HUD includes debug stats and contextual command buttons at the bottom-left.
- Attack-move mode has a persistent cursor indicator and HUD activation button.
- Dedicated dozers handle construction; supply trucks only collect and deliver supplies.
- Build placement, grid snapping, footprint validation, and construction progress are implemented.
- Building data can reference custom visual/object scenes through `BuildingData.building_scene`.
- Custom building scenes are auto-fit to their footprint when instantiated.
- Completed building interaction areas follow fitted mesh bounds; unfinished buildings show percentage and cancel affordance.
- Stopped dozers can resume unfinished construction by right-clicking the building.
- Economy data drives supply dock amount, truck gather rate, and dropoff timing.
- Basic building production queues exist for completed production buildings.
- Production buttons are contextual: completed production buildings expose unit-name buttons such as `Ranger` and `Rocket Soldier`.
- Selected buildings show a right-side building bar; Barracks exposes unit production with up to 10 queued items and per-item `X` cancellation.
- Combat now supports weapon damage types, armor modifiers, target priority scoring, and concise combat debug prints.
- Barracks can now produce `Ranger` and `Rocket Soldier` for basic small-arms vs explosive matchup testing.
- Ranger uses `gltf/Soldier_02.glb`, with animation mapping for idle, talking idle, selected idle, walking, guard crouch, shooting, and death.
- Rocket Soldier uses the same Soldier animation/model logic with a gray visual tint.
- Selected combat units show fire-range and vision-range rings.
- Infantry separation/personal space has been strengthened to reduce stacking.
- The test platform and camera-visible area are larger, with a team 2 `EnemyRanger` available for combat validation.
- Baseline fog-of-war is implemented: enemy units hide outside friendly vision and print `[Fog]` visibility changes; the ground plane gains a darker overlay outside those vision circles (`FogOfWarOverlay` + shader).
- Friendly **buildings** (non-ghost, team 1) grant vision via `BuildingData.sight_range` and `ConstructionSite.get_vision_range()`, aligned with the terrain FoW pass.
- Infantry now show weapon visuals: **Ranger** uses `gltf/Pistol_5.obj` rigged to **`hand_r`** when the Soldier skeleton is present; Rocket Soldier keeps procedural launcher props.
- **Health bar** stays on the unit root with Y-billboard materials and is always visible; fill shows damage.
- **Construction** sites use larger **black** progress text (white outline) and slightly larger cancel text for readability.
- Important FoW / weapon / animation sections in code carry **short comments** at boundaries to ease onboarding as the project grows.

## Sprint 1 Summary (Command System & Selection UX)
- Unified command flow for units, including queued orders.
- Context right-click: move on ground, attack enemy, guard friendly, harvest resource nodes.
- Control groups and selection quality improvements (drag selection, double-click same type, shift-append).
- Visual feedback: order markers and an attack-move mode cursor.
- HUD command buttons wired to actions; hotkeys are currently disabled for later rebind decision.
- Handoff to Sprint 2: command intent and selection behavior are stable enough to tune movement quality under stress.

## Implemented Sprint Notes
- `docs/sprint-02-navigation-avoidance-notes.md`
- `docs/sprint-03-builder-construction-notes.md`
- `docs/sprint-04-economy-production-notes.md`
- `docs/sprint-05-combat-depth-notes.md`
- `docs/sprint-06-fog-of-war-ui-notes.md`

## Sprint Cadence Guardrails (Applies to Every Sprint)
- One primary feature theme per sprint; avoid mixing unrelated system rewrites.
- Define one measurable benchmark before implementation starts.
- Carry forward a short regression checklist from the previous sprint and run it before sign-off.
- Reserve end-of-sprint time for stabilization and a focused playtest pass.
- Ship with explicit handoff notes: what is done, what remains risky, and what unlocks the next sprint.

## Remaining Sprints (Execution Template)

### Sprint 2: Navigation & Avoidance
**Status**
- Implemented; needs runtime tuning/playtest.

**Goal**
- Make large-unit movement reliable, readable, and recoverable under normal RTS command load.

**Scope (Must-Have)**
- Tune navigation mesh and local avoidance for mixed unit groups.
- Add separation/steering behavior to reduce clumping.
- Add anti-stuck recovery for blocked, oscillating, or stalled units.

**Out of Scope (Nice-to-Have)**
- Advanced tactical formations beyond spacing and collision stability.
- Full map-specific path authoring for custom scenarios.

**Dependencies**
- Sprint 1 command flow and queued order behavior.

**Done Criteria**
- Movement remains stable with 50+ active units in repeated order spam scenarios.
- Stuck/recovery incidents are rare and recover automatically without manual re-issue.
- Group travel spacing remains readable at destination and during turns.

**Validation / Test Focus**
- Benchmark: repeated move/attack-move/guard commands across chokepoints and open fields.
- Track stuck frequency, average time-to-destination, and visible clump rate.

**Handoff to Next Sprint**
- Reliable movement and arrival behavior for builders traveling to construction sites.

### Sprint 3: Builder + Construction
**Status**
- Implemented; needs runtime validation of each build button and placement edge cases.

**Goal**
- Establish a predictable build workflow from placement intent to completed powered structure.

**Scope (Must-Have)**
- Ghost placement, grid snapping, and footprint validation.
- Builder travel-to-site, build start, progress updates, and completion state.
- Apply power impact changes on construction start/completion as defined by design.

**Out of Scope (Nice-to-Have)**
- Complex construction animations/VFX pass.
- Multi-builder acceleration rules and advanced repair systems.

**Dependencies**
- Sprint 2 path reliability and anti-stuck for builder travel.

**Done Criteria**
- Players can place valid structures with clear placement feedback and failure reasons.
- Builder reaches site and completes build without desync between visuals and gameplay state.
- Power state updates are deterministic and visible in HUD/debug stats.

**Validation / Test Focus**
- Benchmark: repeated place/cancel/place/complete loops across different terrain regions.
- Validate blocked placement, edge snapping cases, and interrupted builder paths.

**Handoff to Next Sprint**
- Construction outcomes now provide consistent hooks for economy throughput and production systems.

### Sprint 4: Economy & Production
**Status**
- Implemented baseline; needs runtime validation and queue UX polish.

**Goal**
- Convert functional resource collection into tunable economy pacing and unit production output.

**Scope (Must-Have)**
- Tie `EconomyData` to harvest rates and dropoff timing.
- Implement building production queues with queue controls and output timing.
- Add at least one secondary income source with clear constraints.

**Out of Scope (Nice-to-Have)**
- Full faction-specific macro economy differentiation.
- Late-game economy inflation systems.

**Dependencies**
- Sprint 3 construction lifecycle and power updates.

**Done Criteria**
- Economy values are data-driven and can be tuned without core code changes.
- Production queues are stable under cancel/requeue and low-resource conditions.
- Secondary income source integrates without breaking primary harvest loop.

**Validation / Test Focus**
- Benchmark: time-to-first-produced-unit and sustained income over fixed test windows.
- Validate starvation behavior (insufficient resources), queue interruption, and recovery.

**Handoff to Next Sprint**
- Stable income and production pacing enables meaningful combat balance and counterplay tuning.

### Sprint 5: Combat Depth
**Status**
- Implemented baseline; needs runtime matchup validation.

**Goal**
- Add strategic combat differentiation while preserving readability and control responsiveness.

**Scope (Must-Have)**
- Add armor modifiers and weapon type interactions.
- Implement target priority logic with explicit, testable rules.
- Add veterancy bonuses affecting damage, rate of fire, and healing interactions.

**Out of Scope (Nice-to-Have)**
- Full ability reworks and cinematic combat presentation.
- Deep faction asymmetry pass.

**Dependencies**
- Sprint 4 production/economy pacing for consistent combat test setups.

**Done Criteria**
- Weapon/armor interactions produce measurable matchup differences.
- Targeting rules are deterministic and understandable in playtests.
- Veterancy progression is visible and materially impacts engagements.

**Validation / Test Focus**
- Benchmark: controlled skirmish suites for TTK bands and expected win-rate envelopes.
- Validate edge cases: mixed target classes, retarget churn, and healing stacking.

**Handoff to Next Sprint**
- Combat readability requirements are clear enough to drive Fog of War and UI presentation priorities.

### Sprint 6: Fog of War + UI
**Status**
- Partially implemented: gameplay FoW, terrain shading, building vision, infantry weapon/health/animation polish, construction label pass; minimap and full inspect UI still out of scope for this baseline.

**Goal**
- Improve battlefield readability and player decision speed through visibility and interface upgrades.

**Scope (Must-Have)**
- Implement vision mask and minimap integration.
- Add unit/building info panels with actionable state visibility.
- Improve placement/command feedback for high-frequency interactions.

**Out of Scope (Nice-to-Have)**
- Final art polish for all UI widgets.
- Full tutorialization layer.

**Dependencies**
- Sprint 5 combat data and readability pain points from playtests.

**Done Criteria**
- Vision updates and minimap state are consistent with world visibility rules.
- Core player decisions (select, issue, inspect) require fewer ambiguous UI states.
- Command and placement feedback reduce misclick-driven errors in test sessions.

**Validation / Test Focus**
- Benchmark: task-completion time for scouting, selecting, and issuing commands in FoW.
- Validate visibility edge cases (enter/leave vision, destroyed spotters, rapid camera movement).

**Handoff to Next Sprint**
- Stable UI and visibility signals provide the surface needed for abilities and unlock-tree complexity.

### Sprint 7: General Abilities
**Goal**
- Layer strategic progression systems without destabilizing core command and combat loops.

**Scope (Must-Have)**
- Command points and unlock tree progression.
- Ability cooldown and activation rules.
- Faction variants implemented as constrained data/config differences.

**Out of Scope (Nice-to-Have)**
- Full faction campaign scripting.
- Highly experimental ability archetypes with special simulation rules.

**Dependencies**
- Sprint 6 visibility/UI clarity for communicating ability state and availability.

**Done Criteria**
- Ability unlocks and cooldowns are deterministic and clearly surfaced in UI.
- Faction variants alter play patterns without breaking shared systems.
- Ability usage integrates with existing command queue and combat targeting behavior.

**Validation / Test Focus**
- Benchmark: ability usage frequency and cooldown uptime in mid-length matches.
- Validate interactions with queueing, interrupted casts, and resource constraints.

**Handoff to Next Sprint**
- Ability and progression events are formalized in a deterministic command/event stream.

### Sprint 8: Multiplayer Lockstep R&D
**Goal**
- Validate deterministic simulation feasibility for multiplayer foundations.

**Scope (Must-Have)**
- Deterministic simulation checks over representative gameplay scenarios.
- Command stream prototype for synchronized execution.
- Replay capture and replay verification tooling.

**Out of Scope (Nice-to-Have)**
- Full networking stack and matchmaking.
- Production-ready anti-cheat and reconnect systems.

**Dependencies**
- Sprint 2-7 systems producing stable, deterministic inputs and outcomes.

**Done Criteria**
- Replays produce repeatable outcomes across multiple runs on the same build.
- Determinism breaks are logged with enough context to isolate root causes.
- Prototype command stream handles core RTS actions from move to ability usage.

**Validation / Test Focus**
- Benchmark: multi-seed deterministic replay pass rate across test suites.
- Validate divergence scenarios: stress command spam, simultaneous events, long-session drift.

**Handoff to Next Phase**
- Determinism report and replay tooling baseline for production multiplayer planning.

## Current Implementation Checkup
- Sprint 2 baseline is implemented: navigation tuning exports, separation steering, anti-stuck recovery, and HUD movement metrics.
- Sprint 3 baseline is implemented: dozer-only construction, ghost placement, grid snapping, footprint checks, and construction progress.
- Sprint 4 baseline is implemented: `EconomyData` integration, secondary passive income, completed-building production queues, and added buildable structures.
- Sprint 5 baseline is implemented: weapon damage types, armor modifiers, target priority scoring, and combat debug prints.
- Current buildable structures:
  - `usa_command_center`
  - `usa_power_plant`
  - `usa_barracks`
  - `usa_supply_depot`
- **Sprint 6 (FoW + presentation)**: gameplay visibility (units + buildings), terrain darkening overlay, `Pistol_5` rifle mesh + import, health bar behavior, hold/guard vs social idle rules, construction label styling; see `docs/sprint-06-fog-of-war-ui-notes.md` for file map and validation list.
- Current test roles:
  - `Dozer`: build/move/stop only; no attack, attack-move, or guard.
  - `SupplyTruck`: harvest/dropoff only; no construction.
  - `Ranger`: combat-capable unit produced by eligible buildings.
  - `Rocket Soldier`: explosive infantry produced by Barracks for matchup testing.

## TODO Before Moving Past Sprint 4
1. Runtime-test each dozer build button: Command Center, Power Plant, Barracks, Supply Depot.
2. Confirm a selected dozer enters build mode, shows a blue/red ghost, moves to the site, and completes construction.
3. Confirm supply truck continues harvesting while dozer builds.
4. Confirm completed production buildings can queue and spawn `usa_ranger` with resource cost and build time.
5. Replace temporary/debug building visuals with distinct meshes or materials per building type.
6. Polish visible per-building queue UI beyond the current debug-style queue box.
7. Decide whether power shortages should block production/construction or only display warning state.
8. Re-run command regression: stop, hold, attack-move, guard, harvest, build, train.

## TODO Before Moving Past Sprint 5
1. Runtime-test combat targeting with multiple enemy types once more unit types exist.
2. Validate `[Combat]` print output during projectile hits.
3. Tune armor modifiers after controlled skirmish tests.
4. Add a vehicle unit that uses `light_vehicle` armor so Rocket Soldier matchups can be tested properly.

## TODO Before Moving Past Sprint 6
1. Playtest vision edges: moving spotters, destroyed buildings, and the 32-source cap on `FogOfWarOverlay`.
2. Confirm `Pistol_5.obj.import` is committed so clones reimport; tune grip transform if the mesh clips the hand in some clips.
3. Decide product behavior for **health bar when at full HP** (always-on vs on-damage-only) and document in sprint notes.
4. Schedule **minimap** + **unit/building inspect panels** (original Sprint 6 scope) or explicitly move to Sprint 6b / Sprint 7 UI milestone.
5. Re-run FoW + construction regression: place building, verify %/cancel labels, verify enemy hidden until in combined unit+building vision.

## Per Sprint Validation Checklist
- Confirm the sprint benchmark metric is defined before implementation starts.
- Run the carried-forward regression checklist from the previous sprint.
- Execute at least one stress scenario tied to the sprint's primary feature theme.
- Record known risks and unresolved edge cases in sprint handoff notes.
- Run end-of-sprint stabilization playtest before sign-off.

### Current Build Baseline Checks
- Use HUD buttons for Stop, Hold, Guard, Attack Move.
- Attack-move: press Attack Move, confirm cursor indicator, then click a destination.
- Guard: press Guard, then click a friendly unit.
- Harvest: select truck and right-click supply dock.
- Double-click a unit to select same type in view.
