# Phase 4 Plan: Choreographed Traffic & Near-Miss Detection

## Phase Goal
Deliver the core gameplay loop for FlowState: choreographed procedural obstacle traffic (Zipper and Funnel formations), sub-0.4m AABB near-miss proximity grazing linked to camera time dilation, an instant sub-300ms crash-restart state machine, and an endless portrait racing loop.

---

## 1. Specifications & Architecture

### A. Traffic Choreography (`traffic_spawner.gd`)
- **Traffic Formations**:
  - **Zipper**: Alternating left and right lane obstacles positioned ahead along the track, requiring rhythmic slaloming.
  - **Funnel**: Converging outer-lane obstacles that narrow down to a high-speed apex slot.
- **Traffic Vehicles (`traffic_vehicle.gd`)**:
  - Procedural comic vehicle with toon shader + outline in contrasting palette (e.g. Ochre `#E76F51` and Cobalt `#264653`).
  - Cruises forward along track at regular traffic speed ($24.0\text{ m/s}$ vs player cruise of $42.0\text{ m/s}$).
  - Object-pooled or dynamically despawned when falling $>35\text{m}$ behind the player.

### B. Near-Miss Proximity Grazing (<0.4m Clearance)
- **Detection Algorithm**:
  - Evaluates clearance between the player vehicle's bounding box and traffic vehicles every physics tick.
  - If minimum separation clearance $d \in (0.0\text{m}, 0.40\text{m})$ without physical intersection:
    - Triggers near-miss event once per obstacle pass.
    - Calls `camera.trigger_impact_punch(lateral_direction)`:
      - $40\text{ms}$ time dilation (`Engine.time_scale = 0.1`).
      - $0.25\text{m}$ lateral camera punch opposite clearance normal.
    - Displays comic on-screen feedback ("GRAZE", "NEAR MISS", flow points).

### C. Sub-300ms Crash-Restart State Machine (`game_manager.gd`)
- **States**: `RUNNING`, `CRASHED`, `RESETTING`.
- **Timing Budget**:
  - $0\text{ms}$: Full impact detection, stop forward thrust, trigger screen comic flash.
  - $150\text{ms}$: Reset vehicle position, zero velocities, reposition camera.
  - $280\text{ms}$: Traffic queue respawned ahead; transition back to `RUNNING`.
  - Zero reloading pauses or scene-tree reloading overhead.

### D. Endless Vertical Loop & Portrait HUD
- **Dynamic Track Recycling**: Moving or procedurally tiled road chunks ensuring unbroken forward racing.
- **HUD (`hud.gd`)**:
  - Portrait-optimized top-screen HUD:
    - Speedometer ($42.0\text{ m/s} \approx 150\text{ km/h}$).
    - Flow State / Drift Indicator.
    - Near-Miss counter with combo multiplier.

---

## 2. Tasks & Execution Steps

1. **Task 4.1: Traffic Vehicle & Procedural Meshes (`traffic_vehicle.gd`)**
   - Autonomous forward travel, collision shape, and near-miss detection probe.
2. **Task 4.2: Choreographed Traffic Spawner (`traffic_spawner.gd`)**
   - Implements Zipper and Funnel choreography waves ahead of player along track curvature.
3. **Task 4.3: Near-Miss Proximity Grazing & Camera Punch Coupling**
   - Detects sub-0.4m clearance and fires camera punch with time dilation.
4. **Task 4.4: Sub-300ms Crash-Restart State Machine (`game_manager.gd`)**
   - Fast state machine managing instantaneous game reset without scene reload.
5. **Task 4.5: Endless Road Chunker & Portrait HUD Integration (`hud.gd`, `test_scene.tscn`)**
   - Full endless loop assembled and playable in portrait orientation.

---

## 3. Verification Criteria (UAT)
- [ ] Zipper and Funnel formations spawn smoothly ahead of the car.
- [ ] Passing within $0.4\text{m}$ triggers $40\text{ms}$ time dilation and lateral camera shake.
- [ ] Head-on or direct side collision initiates instant sub-300ms restart.
- [ ] Loop runs continuously in 9:16 portrait view without stutters.
