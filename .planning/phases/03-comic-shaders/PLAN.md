# Phase 3 Plan: Comic Shaders & Visual Shell (Ligne Claire & Moebius)

## Phase Goal
Implement the full visual pipeline matching the "Ultimate Spider-Man + Moebius" comic book aesthetic: zero external assets, step-lit toon shading, screen-space 45° crosshatch in shadows, inverted-hull distance-scaled outlines, and the master palette constants.

---

## 1. Specifications & Palette Constants

### Color Palette
- **Sunlight**: Warm Ivory `#FFF5E4` (`Color(1.0, 0.961, 0.894)`), positioned at 45° downward angle.
- **Base Surface (Road)**: Bone White / Sand `#EADBC8` (`Color(0.918, 0.859, 0.784)`).
- **Ambient Shadow**: Deep Violet `#2B1E3A` (`Color(0.169, 0.118, 0.227)`), strict rule: *never black or neutral gray*.
- **Vehicle Primary**: Bold Vermilion / Comic Red `#E63946` / Bone Sand `#EADBC8` two-tone accents.

### Shading Logic
1. **Toon Step Lighting**:
   $$\text{light\_factor} = \text{smoothstep}(0.0, 0.04, N \cdot L \times \text{attenuation})$$
2. **Screen-Space 45° Crosshatching**:
   - Screen-space coordinates at 45° angle.
   - Frequency / Density: `160.0` cycles relative to portrait viewport height.
   - Injected strictly into the shadow regions $(\text{light\_factor} < 0.85)$ to evoke hand-inked crosshatching.
3. **Inverted-Hull Outlines**:
   - Pass configuration: `cull_front`, `unshaded`.
   - Extrusion equation:
     $$\text{extrusion} = 0.025 \times \text{clamp}(d_{cam} \times 0.15, 0.8, 2.5)$$
   - Color: Deep Violet `#2B1E3A`.

---

## 2. Deliverables & Tasks

1. **Task 3.1**: Create `comic_toon.gdshader`
   - Step lighting with smoothstep transition.
   - Screen-space 45° crosshatch pattern for shadow tones.
   - Configurable albedo, shadow tint, and hatch parameters.

2. **Task 3.2**: Create `inverted_hull_outline.gdshader`
   - Inverted vertex extrusion with camera distance compensation.
   - Deep Violet ink line.

3. **Task 3.3**: Create Procedural Vehicle Shell
   - Stylish low-poly sports racer body using procedural CSG or multi-box primitives.
   - Apply toon material and next-pass inverted-hull outline material.

4. **Task 3.4**: Integrate Shaders and Environment into `test_scene.tscn`
   - Setup Warm Ivory `#FFF5E4` sunlight at 45°.
   - Setup stylized comic sky & ambient environment.
   - Apply sand road material to banked mountain highway.
