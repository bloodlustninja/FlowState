# Phase 3 Replan (HOTFIX): Camera Perspective, Road Generation, and Comic Shader Pipeline

## 1. Problem Diagnosis & Motivation
Testing on mobile hardware revealed three critical visual and structural issues:
1. **Camera Perspective**:
   - Fixed 60° pitch looks down too steeply in portrait (9:16), hiding oncoming traffic and horizons.
   - Default FOV and aspect ratio setting crops lateral vision.
   - Needs arcade chase perspective (pitch ~25°, offset $(0, 3.8, 6.2)$, portrait horizontal FOV lock).
2. **Road Generation & Endless Tiling**:
   - Translating static road chunks caused seam disconnects because the sinusoidal curvature formula depended on local vs world $Z$.
   - Lack of visual road markings, curbs, or guardrails made depth perception difficult.
   - Chunk recycling needs continuous math continuity and colored comic road borders.
3. **Comic Shader Pipeline on Mobile (GLES3 / Compatibility)**:
   - Godot 4's Compatibility renderer (OpenGL ES 3.0) has limited custom `void light()` support on mobile chipsets (Adreno/Mali).
   - Stepped toon lighting and screen-space 45° crosshatching must be calculated robustly in `void fragment()` using directional light vectors, guaranteeing 100% reliable rendering on all mobile GPUs.
   - Outlines must be crisp, high-contrast, and artifact-free.

---

## 2. Technical Solution Specifications

### A. Camera Perspective Calibration (`follow_camera.gd`)
- **Pitch Angle**: Reduced from -60° to **-22.0°** (dynamic high-speed chase perspective showing the car and oncoming traffic up to 120m ahead).
- **Camera Offset**: Calibrated to `(0.0, 3.8, 6.0)` relative to vehicle heading.
- **Portrait FOV**: Set camera `keep_aspect = KEEP_WIDTH` with $72^\circ$ FOV to maximize forward sightlines and lateral track visibility on 9:16 screens.
- **Dynamic Speed FOV**: Slight FOV expansion ($72^\circ \rightarrow 80^\circ$) at top speed ($42\text{ m/s}$) for visceral sense of speed.
- **Preserved**: 0.15s SmoothDamp rotational lag, lateral look-ahead, and near-miss impact punch.

### B. Continuous Road Chunker with Comic Curbs (`test_track.gd`)
- **Formula Continuity**: Both chunks are generated with global coordinate phase continuity so when Chunk B is recycled ahead of Chunk A, the transition is mathematically seamless with zero seams or gaps.
- **Road Width & Curbs**:
  - Central 2-lane road ($14.0\text{m}$ width).
  - Comic Ink Guardrails / Curbs ($0.6\text{m}$ raised curbs with deep violet `#2B1E3A` ink borders) to clearly frame the road.
  - Dashed centerline markings for high-speed motion perception.
- **Banking**: Smooth superelevation banking up to $10^\circ$ on mountain switchbacks.

### C. Mobile-Compatible Comic Toon & Crosshatch Shader (`comic_toon.gdshader`)
- **Fragment-Based Lighting**:
  - Evaluates directional sunlight `vec3(0.5, 0.707, 0.5)` directly in `void fragment()`.
  - Step function: `float NdotL = dot(NORMAL, light_dir); float step_light = smoothstep(0.0, 0.05, NdotL);`
  - Screen-space 45° crosshatch: Evaluates `(FRAGCOORD.x + FRAGCOORD.y) * density` directly in fragment pass, blending hand-inked crosshatch lines into Deep Violet `#2B1E3A` shadow tones.
  - Guaranteed identical rendering across desktop and mobile OpenGL ES / Vulkan.
- **Inverted Hull Outline**:
  - Distance-scaled vertex extrusion `0.022 * clamp(dist * 0.12, 0.7, 2.2)` for clean 2px ink lines.

---

## 3. Tasks & Action Plan
- [x] **Task 3.1**: Refactor `comic_toon.gdshader` to fragment-space lighting for rock-solid mobile GLES3 / Compatibility support.
- [x] **Task 3.2**: Refactor `follow_camera.gd` with 22° chase pitch, $(0, 3.8, 6.0)$ offset, and portrait FOV width lock.
- [x] **Task 3.3**: Refactor `test_track.gd` with seamless chunk regeneration, comic curbs, and dashed lane striping.
- [x] **Task 3.4**: Rebuild, sign, and push updated APK to device via ADB for instant live test.
