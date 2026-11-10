# Phase 1 Replan: Grounded 4-Wheel Raycast Suspension & Per-Axle Friction Model

## 1. Problem Statement & Motivation
The original Phase 1 implementation modeled an anti-gravity hovercraft with isotropic lateral damping. The updated mandate requires a **Grounded 4-Wheel Performance Car** with distinct front and rear axle kinematics, sharp front-end steering bite, rear slip angle on drift flick, visual chassis roll on lateral Gs, and heavy ground-effect downforce for banked ghat mountain switchbacks.

---

## 2. Kinematics & Architectural Mandate

### A. Grounded 4-Wheel Struts (Raycast Suspension)
- **Vehicle Type**: Grounded dynamic 4-wheel sports chassis (`RigidBody3D`, mass = 1200 kg).
- **Strut Geometry**:
  - Front-Left (FL): `(-0.8, 0.0, -1.4)`
  - Front-Right (FR): `(0.8, 0.0, -1.4)`
  - Rear-Left (RL): `(-0.8, 0.0, 1.4)`
  - Rear-Right (RR): `(0.8, 0.0, 1.4)`
- **Suspension Parameters**:
  - Tire Radius: `0.35m`
  - Rest Length: `0.55m` (Total ray reach = $0.90\text{m}$)
  - Spring Stiffness ($k$): `450.0`
  - Suspension Damping ($c$): `32.0`
  - Force Equation per wheel:
    $$F_{spring} = \max\left(0, (k \cdot (rest\_len - (dist - tire\_radius)) - c \cdot v_{compression})\right) \cdot \frac{mass}{4}$$

### B. Per-Axle Lateral Traction & Friction Curves
- **Front Axle (Steering & Bite)**:
  - Steered wheel orientation: Yaw offset $= \text{steer\_input} \times 28^\circ$.
  - Front Lateral Grip: `0.95` (sharp, zero float, razor response).
  - Eliminates understeer float by directly canceling 95% of lateral slip along the steered tire's contact patch.
- **Rear Axle (Traction & Oversteer/Drift)**:
  - Rear Lateral Grip (Cruise): `0.90` (planted, stable high-speed tracking).
  - Rear Lateral Grip (Drift Active): `0.28` (allows rear end to break loose into controlled oversteer).
  - Drift Exit Snap: Counter-steering or releasing drift snaps rear grip back to `0.90` and unleashes $+15.0\text{ m/s}$ forward exit impulse.

### C. Visual Chassis Roll (G-Force Lean)
- **Chassis Roll Node**: Child node `VisualChassis` (holds body mesh and visual components).
- **Roll Response**: Local Z-axis tilt proportional to lateral acceleration:
  $$\theta_{roll} = \text{clamp}\left(-\frac{a_{lateral}}{g} \times 0.08, -0.12, 0.12\right)\text{ rad}$$
- Interpolated with smooth response ($\sim 14.0 \times \Delta t$) for dynamic weight-shift visual feedback.

### D. Ground-Effect Downforce for Banked Mountain Switchbacks
- Surface normal averaged across contacting tire patches.
- Heavy ground-effect downforce ($35.0\text{ m/s}^2$) directed strictly along $-\vec{N}_{ground}$ to suck the chassis onto steep banks, cambers, and undulating ghat highways.

---

## 3. Tasks & Deliverables

1. **Task 1.1**: Rewrite [`vehicle_controller.gd`](file:///c:/Users/jatin/Downloads/game%20idea/vehicle_controller.gd) to implement:
   - Grounded 4-wheel raycast struts with tire radius offset ($k=450, c=32$).
   - Per-axle friction model (Front grip = 0.95; Rear grip = 0.90 normal / 0.28 drift).
   - Steered front wheel slip angle projection.
   - Body roll angle calculation and application to `VisualChassis`.
   - Banked surface suction downforce ($35\text{ m/s}^2$).
2. **Task 1.2**: Update [`test_track.gd`](file:///c:/Users/jatin/Downloads/game%20idea/test_track.gd) to feature a banked mountain highway curve with camber and elevation undulations.
3. **Task 1.3**: Update [`test_scene.tscn`](file:///c:/Users/jatin/Downloads/game%20idea/test_scene.tscn) with `VisualChassis` hierarchy and updated strut ray lengths.
4. **Task 1.4**: Update `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, and `.planning/STATE.md`.

---

## 4. Verification & Acceptance Criteria
- [ ] Wheels stay grounded with $0.35\text{m}$ tire clearance; no floating hover feel.
- [ ] Front steering at $0.95$ grip immediately initiates turn without front-end push.
- [ ] Triggering drift drops rear grip to $0.28$, allowing rear slip and yaw rotation.
- [ ] Snapping steering/drift releases $+15\text{ m/s}$ boost and restores $0.90$ rear grip.
- [ ] VisualChassis rolls realistically into corners when undergoing lateral acceleration.
