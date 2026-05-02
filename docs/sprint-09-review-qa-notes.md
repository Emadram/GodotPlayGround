# Sprint 09 — Review, QA, benchmarks (consolidated)
Date: 2026-05-01  
Status: **Active** — execution checklists for Sprints 2–6 live here; sprint feature notes stay in `docs/sprint-0X-*.md`.

Use this file during **release / milestone reviews** and **regression passes**. Fill tables with dates and Pass/Fail; link bugs to issues or commits.

---

## 1. Sprint 2 — Navigation benchmark

**Scenario:** World test map (`world.tscn`), navigation region active, flat ground + at least one static choke (building footprint or dock cluster).

**Load:** Ramp **10 → 30 → 50** combat units (`testunit`), plus supply truck + dozer as needed. Issue **move, attack-move, guard** for **≥ 3 minutes**, including one **choke pass** and one **open-field cross**.

**Pass:** No soft-lock; stuck recovery not unbounded; spacing readable.  
**Fail:** Tunneling through statics; stall > `stuck_timeout` with no recovery.

**Results log**

| Date | Build | Unit count | Command mix | Stuck recoveries (approx) | Pass/Fail | Notes |
|------|-------|------------|---------------|---------------------------|-----------|-------|
| 2026-05-01 | dev smoke (headless load) | 1 scripted Ranger | none | n/a | Pending | Full 50+ run in editor; copy HUD moving count / nav recoveries. |

**Stress procedure (50+):** duplicate or spawn 50+ `testunit`; use Debug HUD metrics; tune `nav_radius`, `separation_radius`, `stuck_timeout`, `stuck_repath_offset` if fail.

---

## 2. Sprint 3 — Build validation matrix

*Dozer: `CharacterBody3D` + `move_and_collide`; verify `build_range` still starts construction.*

| Building ID | Valid ghost + place | Invalid / overlap rejected | Build completes | Cancel mid-build | Stop dozer + resume (RMB site) |
|-------------|---------------------|------------------------------|-----------------|------------------|--------------------------------|
| `usa_command_center` | Manual | Manual | Manual | Manual | Manual |
| `usa_power_plant` | Manual | Manual | Manual | Manual | Manual |
| `usa_barracks` | Manual | Manual | Manual | Manual | Manual |
| `usa_supply_depot` | Manual | Manual | Manual | Manual | Manual |

**Ghost / footprint:** overlap rejected with feedback; edge snap sane. **Power HUD:** updates on construction start/complete.

---

## 3. Sprint 4 — Economy & production checklist

| # | Check | Pass |
|---|--------|------|
| 1 | Each dozer build button places all four structures | Manual |
| 2 | Dozer ghost, move to site, complete | Manual |
| 3 | Supply truck harvests while dozer builds | Manual |
| 4 | Queue `usa_ranger` (cost + time), spawn | Manual |
| 5 | Queue cancel refund; insufficient resources clear | Manual |
| 6 | Command regression: stop, hold, attack-move, guard, harvest, build, train | Manual |

**Power policy (design):** **Block + pause (Sprint 10)** — low power blocks new training and pauses active timers; see [`docs/sprint-10-power-production-notes.md`](sprint-10-power-production-notes.md).

---

## 4. Sprint 5 — Combat skirmish pass

| Scenario | Pass |
|----------|------|
| Ranger vs Ranger | Manual |
| Ranger vs Rocket | Manual |
| Rocket vs mixed clump | Manual |
| `[Combat]` logs sane (no spam) | Manual |

**Armor tuning log:** (append bullets after playtests.)  
**Deferred:** one `light_vehicle` test unit — separate small task.

---

## 5. Sprint 6 — FoW / UI / presentation validation

1. Enemy pop in/out at vision edge; no stuck-visible.  
2. Completed building grants vision; ghost does not.  
3. Fog overlay aligns with gameplay circles.  
4. **32+** vision sources: cap behavior documented (`FogOfWarOverlay`).  
5. Pistol grip / clips acceptable.  
6. Construction % / cancel labels readable.  
7. **Minimap:** top-right HUD blips; **LMB** pans camera to ground XZ (smoke in play).

**Sprint 6b (still separate):** dedicated **inspect panels** and polished **minimap** art (frame, zoom) if desired.

---

## 6. Cross-sprint regression (from `project-notes`)

- HUD: Stop, Hold, Guard, Attack Move.  
- Attack-move cursor + click.  
- Guard on friendly.  
- Harvest truck on dock.  
- Double-click same unit type.

---

## 7. Sprint 7 — Commander abilities & CP benchmark

**Scenario:** Match with promotions earning CP; use ability bar, **F5/F6/F7** hotkeys, **comma** radial toggle; train units (CP per `UnitData`) and place buildings (cash only).

**Log during a 10–15 min skirmish (fill after playtest):**

| Metric | Target / note | Result |
|--------|----------------|--------|
| Blocked ability casts (CP / cooldown / unlock) | Rare misclicks OK; starvation documented | Pending (manual) |
| CP starvation windows (cannot train + cannot cast) | Note if > 60s without options | Pending (manual) |
| Radial (comma) misclick rate | Subjective Pass/Fail | Pending (manual) |
| F-key vs bar airstrike parity | Same CP + damage path after unification | Pass (code) |
| Unlock `usa_hq_complete` → War Bonds appears | After CC completes | Manual |
| **Sprint 10:** Low power blocks queue / pauses timer | Plant completes → timer resumes | Manual |

**Pass:** No soft-lock; unit cancel refunds CP (and building cancel refunds cash); JSON edits reload abilities.  
**Fail:** Spend order breaks economy (cash spent, CP not) or radial blocks all input when closed.

---

## 8. Sprint 11 — Match end smoke

Re-run this section whenever you change **Project → Run → Main Scene** (multiple world scenes); see [`docs/world-scene-workflow.md`](world-scene-workflow.md).

| # | Check | Pass |
|---|--------|------|
| 1 | Kill all enemy combat units → **Victory** overlay within ~1s of lethal hit; scene tree **paused** | Manual |
| 2 | Lose all friendly combat while enemy lives → **Defeat** overlay | Manual |
| 3 | **Restart mission** reloads map and clears pause | Manual |
| 4 | `P` pause still works mid-match; match end blocks further toggles usefully | Manual |

---

## 9. Sprint 12 — Skirmish AI smoke

| # | Check | Pass |
|---|--------|------|
| 1 | Enemy units receive periodic **attack-move** toward friendly centroid | Manual |
| 2 | AI stops issuing orders when match is not `RUNNING` | Manual |

---

## 10. Sprint 10 — Power / production benchmark (short)

| Step | Target | Result |
|------|--------|--------|
| Surplus power | Queue + timer run | Pending |
| Deficit | Cannot enqueue; active timer holds | Pending |
| Recover | Completing plant resumes timer | Pending |

