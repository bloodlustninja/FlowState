# FlowState (Portrait Anti-Gravity Precision Racer / Auto Modellista Manga Arcade)

## Vision & Overview
FlowState is a mobile portrait arcade highway precision racer featuring an Auto Modellista / Initial D manga cel-shaded aesthetic and high-intensity, responsive driving physics. The player pilots a classic Japanese comic-styled muscle car through endless procedural mountain highway curves, weaving through dense dynamic traffic, chaining razor-thin near-miss grazes, and surviving high-speed lane cuts.

## Core Technical Stack & Constraints
- **Primary Engine**: Godot 4.3 (GDScript, Mobile Vulkan renderer).
- **Form Factor**: Mobile Portrait (9:16 aspect ratio).
- **Coordinate System**: Y-Up, -Z Forward, +X Right.
- **Physics Timestep**: 60 Hz fixed timestep.
- **Visual Style**: Auto Modellista & Initial D manga ligne claire, 2-step toon shading, directional comic edge speedlines, screen-space Sobel depth/normal ink lines, and 3D projected manga livery decals.

## Vehicle Kinematic Specifications (Grounded 4-Wheel Performance Car)
- **Chassis Type**: Grounded 4-wheel dynamic performance car (`AnimatableBody3D`/`Node3D` road spline lock).
- **Hero Vehicle**: White Muscle Car in warm comic paper cream (`#EAE6DC`) with dual cobalt blue stripes and unshaded crimson taillights (`#FF1E27`).
- **Speed Profile**: Cruise = 46 m/s (~165 km/h), Boost = 58 m/s (~210 km/h), Drift exit slingshot impulse = +14 m/s.
- **Lateral Agility**: 22 m/s lateral transition with proportional deadzone steering and dynamic centrifugal roll.
- **Drift Mechanic**: Powerslide yaw kicks in strictly on deliberate swipe-down flick with discrete procedural rubber skid marks.

## Scoring & Traffic Systems
- **Near-Miss Graze Engine**: 0.60m lateral proximity zone, 2.5s combo chain multiplier window (up to 4x), 250 × multiplier score reward, 0.035s hitstop microfreeze (`Engine.time_scale = 0.08`), and floating 3D unprojected comic badges.
- **Dynamic Traffic AI**: 25% designated lane switchers merging 35–55m ahead of player over 1.2s with 4° visual chassis tilt, heavy roadblocks, anti-penetration spacing, and horizon fog recycling.
