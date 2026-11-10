# FlowState Requirements

## Phase 1: Grounded 4-Wheel Performance Chassis Rig (Completed)
- [x] **REQ-1.1**: Grounded 4-wheel raycast wheel struts offset at (±0.8m X, ±1.4m Z) with 0.35m tire radius.
- [x] **REQ-1.2**: Suspension spring stiffness ($k = 450.0$) and damping ($c = 32.0$) with 0.55m rest length.
- [x] **REQ-1.3**: Front axle 0.95 grip bite with ±28° steering angle, zero float.
- [x] **REQ-1.4**: Rear axle 0.90 cruise grip dropping to 0.28 during drift flick.
- [x] **REQ-1.5**: Drift exit counter-steer snap restoring 0.90 grip and releasing +15.0 m/s forward impulse.
- [x] **REQ-1.6**: Visual chassis roll along local Z-axis proportional to lateral acceleration.
- [x] **REQ-1.7**: Banked ghat mountain highway ground-effect downforce ($35.0\text{ m/s}^2$ along $-\vec{N}_{ground}$).
- [x] **REQ-1.8**: S-curved banked mountain highway test bed (`test_track.gd`).

## Phase 2: Single-Thumb Input & Follow Camera (Completed)
- [x] **REQ-2.1**: Dynamic anchor touch tracker covering bottom 40% of viewport.
- [x] **REQ-2.2**: Steering mapping with 8.0px deadzone and ±120.0px clamp to [-1.0, 1.0].
- [x] **REQ-2.3**: Downward flick drift detection (>45px, >250px/s).
- [x] **REQ-2.4**: Follow camera mounted at 60° pitch, offset (0, 6.5, 7.5).
- [x] **REQ-2.5**: Camera rotational lag (SmoothDamp 0.15s) and lateral look-ahead.
- [x] **REQ-2.6**: Near-miss impact punch (40ms time dilation, 0.25m lateral impulse).

## Phase 3: Comic Shaders & Visual Shell (Completed)
- [x] **REQ-3.1**: Procedural box vehicle mesh and road chunk with inverted-hull outline material.
- [x] **REQ-3.2**: Inverted-hull outline material with distance-scaled extrusion (`0.025 * clamp(dist * 0.15, 0.8, 2.5)`).
- [x] **REQ-3.3**: Screen-space 45° crosshatch toon lighting shader (`density = 160.0`).
- [x] **REQ-3.4**: Moebius/Ultimate Spider-Man color palette constants (Warm Ivory `#FFF5E4`, Sand `#EADBC8`, Deep Violet `#2B1E3A`).

## Phase 4: Choreographed Traffic & Near-Miss Detection (Completed)
- [x] **REQ-4.1**: Choreographed procedural traffic spawner (Zipper slalom & Funnel pinch-point formations).
- [x] **REQ-4.2**: AABB near-miss proximity grazing (<0.4m clearance detection).
- [x] **REQ-4.3**: Sub-300ms crash-restart state machine (280ms total restart budget).
- [x] **REQ-4.4**: Playable endless vertical loop with chunk recycling and mobile portrait HUD.

## Phase 5: Auto Modellista Manga Visuals, Scoring Engine & Dynamic Traffic AI (Completed)
- [x] **REQ-5.1**: Near-Miss Graze scoring engine: 0.60m lateral proximity zone with 250 × combo multiplier points.
- [x] **REQ-5.2**: Combo chain multiplier window: 2.5s timer scaling up to 4x, animated shrinking progress bar.
- [x] **REQ-5.3**: Graze hitstop punch: 0.035s time dilation (`Engine.time_scale = 0.08`) with 3D unprojected floating comic text badges.
- [x] **REQ-5.4**: Dynamic Civilian Traffic AI: 25% designated lane switchers merging 35–55m ahead over 1.2s with 4° visual chassis tilt.
- [x] **REQ-5.5**: Auto Modellista manga aesthetic: 2-tone stepped cel-shading, warm Japanese paper tone (`#EAE6DC`), dual cobalt blue stripes, unshaded crimson taillights (`#FF1E27`), 3D projected manga livery decal.
- [x] **REQ-5.6**: Screen-space edge detection post-process (Sobel depth/normal ink contours) and edge-only speedlines (unobstructed central driving corridor).
- [x] **REQ-5.7**: Two-tone manga sky gradient (Zenith Deep Blue `#0B2B68`, Horizon Warm Cream `#F8E9C0`) with dynamic directional sunlight (`Vector3(-45, -35, 0)`).
- [x] **REQ-5.8**: Score & Combo HUD overhaul with rolling lerp score ticker, KM/H velocity, and game-over summary stats (Final Score, Top Speed, Total Grazes) with sub-200ms tap-to-restart.
