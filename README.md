# 🏎️ FlowState: Anime Touge Racer

A high-octane, stylized mobile anime arcade touge racing game built in **Godot 4.3 (Mobile & Compatibility Renderers)**. Experience procedural mountain highway generation, dynamic traffic overtaking, physics-informed drift mechanics, cel-shaded ink aesthetics, and a full Eurobeat & house rally audio suite.

---

## ⚡ Core Features

- **Stylized Anime Graphics Pipeline**: Custom multi-pass cel shaders, halftone screen-space ink cross-hatching, rim lighting, comic outline post-processing, and parallax skybox with dynamic weather (sunny, rain, snow, sunset, midnight).
- **Audio Architecture & Shuffler**:
  - Authentic roaring sports car engine sound loop with RPM/gear modulation.
  - Realistic tire screech audio scaled dynamically to tire lateral slip velocity.
  - 18-track rally playlist with track metadata HUD and random shuffle playback.
  - Radio chatter alerts and high-impact crash audio.
- **Mobile-Optimized Architecture**:
  - Directional shadow maps optimized to 1024 cascade resolution for maximum mobile GPU fillrate efficiency.
  - Dynamic 3D resolution scaling at 88% bilinear upsampling for thermal control and battery preservation.
  - Engine locked to a solid 60 FPS cap (`run/max_fps=60`) to avoid overheating on 120Hz mobile screens.
  - Compatibility renderer fallback for HTML5 Web / iOS Safari execution.

---

## 🎮 Controls

### Mobile (Touch / On-Screen)
- **Left / Right Screen Sides**: Steer vehicle laterally across lanes.
- **Brake / Drift Button**: Engage rear-wheel break to induce lateral slip drift.
- **Boost Button**: Turbo acceleration boost.

### Desktop (Keyboard)
- **A / D** or **Left / Right Arrow**: Steer
- **W** or **Up Arrow**: Accelerate
- **S** or **Down Arrow**: Brake / Reverse
- **Space**: Handbrake / Drift
- **Shift**: Nitro Boost

---

## 🌐 Web & iOS Safari Hosting

This project is configured for single-threaded WebGL2 export (`gl_compatibility`), making it fully compatible with:
- **iOS Safari / iPadOS** (Zero `SharedArrayBuffer` requirement or COOP/COEP header blocks).
- **GitHub Pages** (Automated continuous deployment via GitHub Actions).
- **Itch.io & Netlify / Vercel**.

### GitHub Pages Deployment
1. Go to repository **Settings** -> **Pages**.
2. Under **Build and deployment** -> **Source**, select **GitHub Actions**.
3. Push to `main` — GitHub Actions will automatically export the Godot 4 Web build and publish your playable web link!

---

## 🛠️ Project Structure

- `monolithic_testbed.gd`: Primary gameplay, physics, traffic spawning, road spline extrusion, and audio mixer orchestrator.
- `comic_*.gdshader`, `highway_road.gdshader`: Shading and post-processing visual pipeline.
- `assets/audio/`: Authentic engine recordings, tire screech samples, rally playlist, and crash effects.
- `assets/vehicles/`: Low-poly stylized vehicles (Player Sports Car, Muscle, Sedans, Police Interceptors, Heavy Trucks).
- `.github/workflows/deploy_pages.yml`: Automated Godot 4 Web export and GitHub Pages deployment.
