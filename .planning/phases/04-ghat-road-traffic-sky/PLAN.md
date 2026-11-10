# Phase 4 Replan: Procedural Ghat Road Spline, 12-Vehicle Traffic Pool, & Mountain Environment

## 1. Problem Statement
The current scene rendered a flat straight road without visible traffic and lacked a mountain environment backdrop. This replan replaces the static track with an endless 3-chunk curved & banked spline road system, activates an explicit 12-vehicle pooled traffic manager moving along lane curves, and builds roadside mountain cuttings, valley drop-offs, and a warm comic procedural sky.

---

## 2. Technical Architecture

### A. Procedural Curved Road Mesh & Inward Banking (`road_chunk.gd` & `test_track.gd`)
- **Chunk Specifications**:
  - Length: 100 meters per chunk.
  - Width: 12.0 meters (3-4 lanes).
  - Cross-sections: 50 segments every 2m.
- **Curve Math & Tangent Continuity**:
  - Hermite / Cubic Bezier curve per chunk: starts at exact end point & exit tangent of previous chunk.
  - Horizontal offset: randomized delta $X \in [-15.0\text{m}, +15.0\text{m}]$ creating real chicanes and bends.
  - Inward banking: roll cross-section on local $Z$ up to $15^\circ - 20^\circ$ into corners ($\theta = \text{curvature} \times \text{bank\_factor}$).
- **Chunk Pooling**:
  - Active array: `[Previous, Current, Next]` (300m total highway).
  - Trimesh collision (`ConcavePolygonShape3D`) aligned to banked mesh.
- **Surface Texture & Centerline**:
  - Warm sun-bleached asphalt `#DCD6CD`, yellow dashed center divider `#E0A938`, and white edge lines.

### B. Dedicated TrafficManager & 12-Vehicle Active Pool (`traffic_manager.gd`)
- **Pre-instantiated Pool**: 12 active vehicle instances loaded from `res://assets/vehicles/traffic/` (sedan, truck, police, suv, muscle).
- **Lanes & Positioning**:
  - 3 Lanes: Left ($-3.5\text{m}$), Center ($0.0\text{m}$), Right ($+3.5\text{m}$) relative to road spline center.
  - Spawn window: $70\text{m}$ to $120\text{m}$ ahead of the player along the curve.
  - Alignment: Yaw oriented along the road tangent vector $\vec{T}$.
- **Kinematics**:
  - Sedans: $25\text{ m/s}$
  - Heavy Trucks: $18\text{ m/s}$
  - Police Cruisers: $32\text{ m/s}$
  - Despawns / recycles when $>30\text{m}$ behind player.

### C. Ghat Mountain Environment & Stylized Sky (`test_track.gd` & `test_scene.tscn`)
- **Left Roadside: Terracotta Mountain Rockface**:
  - Steep low-poly cliff walls rising $8\text{m} - 15\text{m}$.
  - Dusty warm terracotta `#8D5B4C` with comic cel-shading.
- **Right Roadside: Retaining Wall & Valley Drop-off**:
  - Concrete barrier / guardrail ($1.2\text{m}$ high) in bone gray `#C8C2BA`.
  - Dropped valley plane below the road ($Y = -35\text{m}$).
- **Procedural Comic Sky**:
  - Sky Top Color: Soft pastel lavender-blue `#6C7A89` (`Color(0.424, 0.478, 0.537)`)
  - Horizon Color: Warm cream/peach `#F7E7CE` (`Color(0.969, 0.906, 0.808)`)
  - Ground Bottom Color: Deep warm brown `#3E2723` (`Color(0.243, 0.153, 0.137)`)
