# Sprint 08 Notes — Multiplayer lockstep R&D
Date: 2026-05-01  
Status: **Not started** (gate: Sprint 7 stable command/event semantics)

## Goal
Prove deterministic simulation + replay for a **small** command subset before any production netcode.

## Start gate
- Sprint 7 abilities/progression integrated enough that **core commands** (move, attack, stop, ability N) are stable and UI-clear.

## Determinism audit stub (fill during first spike)

**Phase 0 (repo hygiene, 2026-05-01):** Lock a **golden frame** test scene list (`world.tscn` + canned inputs) before first replay capture; record Godot patch version in this table when runs begin. When multiple world scenes exist, also record **Project → Run → Main Scene** for each capture so replays stay comparable (see [`docs/world-scene-workflow.md`](world-scene-workflow.md)).

| Source | Risk | Mitigation idea |
|--------|------|-----------------|
| `Random*` usage | Desync | Seeded RNG per match / command stream |
| Node iteration order | Desync | Sort ids or explicit ordering |
| Float drift | Rare desync | Fixed timestep; avoid non-deterministic aggregates |
| `Time.get_ticks_msec` in sim | Desync | Drive sim from frame index only |

## Planned deliverables
1. Replay **capture** for one canned scenario.
2. Replay **verify** (hash or state dump) across two runs same build.
3. Minimal **command stream** prototype (local only) for move + attack.

## Files touched (populate when work begins)
- (TBD)
