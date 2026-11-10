# Phase 2 Plan: Single-Thumb Input & Follow Camera

## Phase Goal
Deliver a responsive, mobile-portrait touch input system and an elastic follow camera system that integrates directly with the Phase 1 vehicle controller, enabling single-thumb steering, flick-to-drift, and cinematic motion tracking with look-ahead and rotational lag.

---

## 1. Requirements Breakdown

### Input System (`touch_controller.gd` / `TouchController.tscn`)
- **Viewport Region Constraint**: Touch active exclusively in the bottom 40% of the viewport (`touch_pos.y > viewport_height * 0.60`). Desktop mouse emulation (`emulate_touch_from_mouse = true`).
- **Dynamic Anchor**: Touch-down captures $(X_0, Y_0)$ as the local origin.
- **Steering Delta & Saturation**:
  - $\Delta X = X_{\text{current}} - X_0$
  - Deadzone: 8.0 px (no steering input if $|\Delta X| \le 8.0\text{ px}$).
  - Saturation: Clamped at $\pm 120.0\text{ px}$ mapped linearly to $[-1.0, 1.0]$.
  - Injection: Passes normalized value directly to `vehicle.set_steer_input(steer_value)`.
- **Drift / Weight-Shift Flick Trigger**:
  - Downward delta: $\Delta Y = Y_{\text{current}} - Y_0$.
  - Threshold: $\Delta Y > 45.0\text{ px}$ with downward velocity $V_Y > 250.0\text{ px/s}$.
  - State locks into `DRIFT_ACTIVE` (`vehicle.set_drift_state(true)`) until touch release or $\Delta Y$ returns within deadzone ($|\Delta Y| \le 8.0\text{ px}$).
  - Touch release: clears drift state (`vehicle.set_drift_state(false)`), triggering the $+15\text{ m/s}$ drift exit impulse from Section 1.

### Camera System (`follow_camera.gd` / Camera3D node)
- **Mounting & Base Offset**:
  - Mounted with 60° downward pitch.
  - Base offset relative to vehicle orientation: $(0.0, 6.5, 7.5)$ (behind and above the vehicle facing forward along $-Z$).
- **Rotational Lag**:
  - SmoothDamp on vehicle Y-rotation with $0.15\text{s}$ smoothing lag time.
- **Lateral Look-Ahead**:
  - `Cam_X_Offset = vehicle.lateral_velocity * 0.22` (offset camera right/left according to slip/skid velocity).
- **Near-Miss Impact Punch Hook**:
  - Method `trigger_impact_punch(collision_normal: Vector3)`: triggers $40\text{ms}$ time dilation (`Engine.time_scale = 0.1`) and $0.25\text{m}$ lateral camera impulse opposite collision vector.

---

## 2. Tasks & Execution Plan

### Task 2.1: Vehicle Steering Physics Integration
- **File**: `vehicle_controller.gd`
- **Objective**: Add angular torque / yaw turning physics response to `steer_input` inside `_integrate_forces`.
- **Steering Parameters**:
  - Steer Torque: $18000.0\text{ N}\cdot\text{m}$ max yaw torque.
  - High-speed yaw stabilization: Damping angular velocity around local $Y$-axis.

### Task 2.2: Dynamic Anchor Single-Thumb Controller
- **File**: `touch_controller.gd` (Control Node / CanvasLayer)
- **Objective**: Implement touch/mouse events, dynamic anchor tracking, deadzones, steering clamp, downward flick detection, and visual debugging gizmo.

### Task 2.3: Elastic Follow Camera with Rotational Lag & Look-Ahead
- **File**: `follow_camera.gd` (Camera3D)
- **Objective**: Implement 60° pitch mount, $(0.0, 6.5, 7.5)$ local offset, SmoothDamp yaw lag ($0.15\text{s}$), lateral look-ahead ($V_{\text{lat}} \times 0.22$), and near-miss impact punch.

### Task 2.4: Scene Integration & UAT Verification
- **File**: `test_scene.tscn`
- **Objective**: Update test scene with vehicle, touch input overlay, and follow camera. Verify single-thumb drag steering, downward flick drift toggle, and camera trailing.

---

## 3. Verification Criteria (UAT)
1. **Touch Deadzone & Saturation**: Horizontal dragging under 8px produces 0 steering; dragging $\ge 120\text{px}$ saturates at $\pm 1.0$.
2. **Flick Detection**: Fast downward drag $>45\text{px}$ at $>250\text{px/s}$ sets `DRIFT_ACTIVE` to true (reducing lateral grip to $0.22$). Releasing touch turns off drift and unleashes $+15\text{ m/s}$ forward impulse.
3. **Camera Dynamics**: Camera tracks vehicle smoothly at 60° pitch, shows look-ahead when cornering/drifting, and lags by ~0.15s on rapid turns.
