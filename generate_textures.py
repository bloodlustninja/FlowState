import math
import os
from PIL import Image, ImageDraw, ImageFilter

os.makedirs('assets/textures', exist_ok=True)

# 1. GREEN LEAF (512x512 RGBA)
def create_green_leaf():
    size = 512
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    # Draw leaf shape using parametric curve
    points = []
    # Rotate slightly by 25 degrees
    angle_offset = -0.4
    for i in range(120):
        t = i / 120.0 * math.pi * 2
        # Pear / elliptical leaf formula
        r = 180 * math.sin(t / 2) * (1.0 + 0.12 * math.sin(t * 7)) # gentle serration
        px = r * math.cos(t)
        py = -r * math.sin(t) * 1.5 + 40
        # rotate
        rx = px * math.cos(angle_offset) - py * math.sin(angle_offset) + cx
        ry = px * math.sin(angle_offset) + py * math.cos(angle_offset) + cy
        points.append((rx, ry))

    # Ink outline
    draw.polygon(points, fill=(45, 140, 55, 255), outline=(15, 45, 20, 255), width=6)
    
    # Inner gradient / highlights
    highlight_pts = []
    for p in points:
        hx = (p[0] - cx) * 0.85 + cx - 10
        hy = (p[1] - cy) * 0.85 + cy - 10
        highlight_pts.append((hx, hy))
    draw.polygon(highlight_pts, fill=(90, 195, 75, 220))

    # Central stem and secondary veins
    stem_start = (cx + 80, cy + 160)
    stem_end = (cx - 70, cy - 150)
    draw.line([stem_start, stem_end], fill=(210, 245, 180, 240), width=6)
    
    # Veins
    for vi in range(1, 8):
        frac = vi / 8.0
        vx = stem_start[0] + (stem_end[0] - stem_start[0]) * frac
        vy = stem_start[1] + (stem_end[1] - stem_start[1]) * frac
        # Left vein
        draw.line([(vx, vy), (vx - 45 * math.cos(0.5), vy - 45 * math.sin(0.5))], fill=(170, 230, 140, 200), width=3)
        # Right vein
        draw.line([(vx, vy), (vx + 45 * math.cos(0.3), vy - 45 * math.sin(0.3))], fill=(170, 230, 140, 200), width=3)

    img.save("assets/textures/leaf_green.png")
    print("Created assets/textures/leaf_green.png")

# 2. AUTUMN MAPLE LEAF (512x512 RGBA)
def create_autumn_leaf():
    size = 512
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2 + 20

    # 5-lobe Japanese Momiji maple formula
    def get_momiji_point(t):
        # 5 distinct lobes at angles
        r = 175 * (1.0 + 0.65 * math.cos(5 * t) - 0.25 * math.cos(10 * t))
        # Taper bottom stem
        if t < -math.pi * 0.65 or t > math.pi * 0.65:
            r *= 0.35
        x = cx + r * math.sin(t)
        y = cy - r * math.cos(t)
        return (x, y)

    points = []
    num_pts = 180
    for i in range(num_pts):
        t = -math.pi + (i / float(num_pts)) * math.pi * 2
        points.append(get_momiji_point(t))

    # Outer deep crimson ink outline
    draw.polygon(points, fill=(225, 60, 25, 255), outline=(70, 10, 5, 255), width=7)

    # Radiant golden amber inner glow
    inner_pts = []
    for p in points:
        ix = (p[0] - cx) * 0.82 + cx
        iy = (p[1] - cy) * 0.82 + cy
        inner_pts.append((ix, iy))
    draw.polygon(inner_pts, fill=(245, 140, 30, 230))

    # Center golden core
    core_pts = []
    for p in points:
        ix = (p[0] - cx) * 0.55 + cx
        iy = (p[1] - cy) * 0.55 + cy
        core_pts.append((ix, iy))
    draw.polygon(core_pts, fill=(255, 205, 50, 240))

    # 5 primary lobe veins radiating outward
    stem_base = (cx, cy + 90)
    for lobe_ang in [-1.2, -0.6, 0.0, 0.6, 1.2]:
        end_x = cx + 160 * math.sin(lobe_ang)
        end_y = cy - 160 * math.cos(lobe_ang)
        draw.line([stem_base, (end_x, end_y)], fill=(130, 20, 10, 240), width=5)
        # Sub-veins
        for vi in range(1, 5):
            frac = vi / 5.0
            vx = stem_base[0] + (end_x - stem_base[0]) * frac
            vy = stem_base[1] + (end_y - stem_base[1]) * frac
            draw.line([(vx, vy), (vx - 22 * math.cos(lobe_ang), vy - 22 * math.sin(lobe_ang))], fill=(160, 40, 15, 200), width=3)
            draw.line([(vx, vy), (vx + 22 * math.cos(lobe_ang), vy - 22 * math.sin(lobe_ang))], fill=(160, 40, 15, 200), width=3)

    # Stem at base
    draw.line([stem_base, (cx, cy + 160)], fill=(90, 15, 10, 255), width=8)

    img.save("assets/textures/leaf_autumn.png")
    print("Created assets/textures/leaf_autumn.png")

# 3. DETAILED CRYSTALLINE ANIME SNOWFLAKE (512x512 RGBA)
def create_snowflake():
    size = 512
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    # 6-fold radial symmetry
    for arm in range(6):
        theta = arm * (math.pi / 3.0)
        cos_t = math.cos(theta)
        sin_t = math.sin(theta)

        # Main spine
        length = 200.0
        ex = cx + length * cos_t
        ey = cy + length * sin_t
        draw.line([(cx, cy), (ex, ey)], fill=(255, 255, 255, 255), width=8)

        # Arrowhead tip
        tip_len = 35.0
        tip_a1 = theta + math.pi * 0.75
        tip_a2 = theta - math.pi * 0.75
        draw.line([(ex, ey), (ex + tip_len * math.cos(tip_a1), ey + tip_len * math.sin(tip_a1))], fill=(255, 255, 255, 255), width=6)
        draw.line([(ex, ey), (ex + tip_len * math.cos(tip_a2), ey + tip_len * math.sin(tip_a2))], fill=(255, 255, 255, 255), width=6)

        # 3 tiers of chevron branches along the arm
        for tier, dist in [(1, 70.0), (2, 120.0), (3, 160.0)]:
            bx = cx + dist * cos_t
            by = cy + dist * sin_t
            b_len = 45.0 - tier * 8.0
            ang_l = theta + math.pi / 3.0
            ang_r = theta - math.pi / 3.0
            draw.line([(bx, by), (bx + b_len * math.cos(ang_l), by + b_len * math.sin(ang_l))], fill=(255, 255, 255, 255), width=5)
            draw.line([(bx, by), (bx + b_len * math.cos(ang_r), by + b_len * math.sin(ang_r))], fill=(255, 255, 255, 255), width=5)

    # Central hexagonal star
    hex_pts = []
    for h in range(6):
        ht = h * (math.pi / 3.0) + (math.pi / 6.0)
        hex_pts.append((cx + 42 * math.cos(ht), cy + 42 * math.sin(ht)))
    draw.polygon(hex_pts, fill=(215, 245, 255, 255), outline=(255, 255, 255, 255), width=4)

    # Inner core dot
    draw.ellipse([(cx - 14, cy - 14), (cx + 14, cy + 14)], fill=(255, 255, 255, 255))

    img.save("assets/textures/snowflake.png")
    print("Created assets/textures/snowflake.png")

# 4. FOLIAGE ATLAS SHEET (1024x1024 RGBA)
def create_foliage_sheet():
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 4 Quadrants (512x512 each):
    # Q0 (Top-Left): Tall Mountain Cedar / Pine
    # Q1 (Top-Right): Broadleaf Anime Maple
    # Q2 (Bottom-Left): Dense Grove Cluster
    # Q3 (Bottom-Right): Wild Roadside Shrub / Bush

    # Q0: Tall Mountain Pine (cx=256, cy=256)
    cx, cy = 256, 256
    # Trunk
    draw.rectangle([(cx - 14, cy + 40), (cx + 14, cy + 220)], fill=(75, 45, 30, 255), outline=(25, 15, 10, 255), width=4)
    # 5 Tiers of conical pine foliage
    tiers = [(210, -180, 50), (180, -120, 80), (145, -50, 110), (100, 20, 135), (55, 90, 155)]
    for w, y_off, h in reversed(tiers):
        pts = [
            (cx, cy + y_off - h),
            (cx - w // 2, cy + y_off),
            (cx - w // 4, cy + y_off - 12),
            (cx, cy + y_off - 6),
            (cx + w // 4, cy + y_off - 12),
            (cx + w // 2, cy + y_off)
        ]
        # Dark shadow under-tier
        draw.polygon(pts, fill=(20, 60, 35, 255), outline=(10, 25, 15, 255), width=6)
        # Vibrant lit top
        top_pts = [(p[0], p[1] - 8) for p in pts]
        draw.polygon(top_pts, fill=(50, 155, 75, 255))

    # Q1: Broadleaf Anime Maple (cx=768, cy=256)
    cx, cy = 768, 256
    # Trunk
    draw.rectangle([(cx - 18, cy + 70), (cx + 18, cy + 220)], fill=(85, 50, 35, 255), outline=(25, 15, 10, 255), width=5)
    # Canopy puffs
    puffs = [
        (cx, cy - 80, 110),
        (cx - 85, cy - 20, 95),
        (cx + 85, cy - 20, 95),
        (cx - 45, cy + 40, 85),
        (cx + 45, cy + 40, 85),
        (cx, cy + 20, 95)
    ]
    for px, py, r in puffs:
        draw.ellipse([(px - r, py - r), (px + r, py + r)], fill=(28, 85, 45, 255), outline=(12, 35, 20, 255), width=6)
        draw.ellipse([(px - r + 8, py - r + 8), (px + r - 8, py + r - 16)], fill=(65, 180, 80, 255))

    # Q2: Dense Grove Cluster (cx=256, cy=768)
    cx, cy = 256, 768
    # Multi-trunk
    for tx in [-70, 0, 70]:
        draw.rectangle([(cx + tx - 12, cy + 80), (cx + tx + 12, cy + 220)], fill=(70, 42, 28, 255), outline=(20, 12, 8, 255), width=4)
    # Overlapping canopy
    grove_puffs = [
        (cx - 90, cy - 30, 90),
        (cx + 90, cy - 30, 90),
        (cx, cy - 70, 110),
        (cx - 120, cy + 50, 75),
        (cx + 120, cy + 50, 75),
        (cx, cy + 30, 105)
    ]
    for px, py, r in grove_puffs:
        draw.ellipse([(px - r, py - r), (px + r, py + r)], fill=(22, 70, 38, 255), outline=(10, 30, 16, 255), width=6)
        draw.ellipse([(px - r + 10, py - r + 8), (px + r - 10, py + r - 18)], fill=(55, 165, 75, 255))

    # Q3: Wild Roadside Shrub / Bush (cx=768, cy=768)
    cx, cy = 768, 768
    shrub_puffs = [
        (cx, cy + 40, 120),
        (cx - 100, cy + 70, 85),
        (cx + 100, cy + 70, 85),
        (cx - 50, cy - 10, 95),
        (cx + 50, cy - 10, 95),
        (cx, cy - 30, 85)
    ]
    for px, py, r in shrub_puffs:
        draw.ellipse([(px - r, py - r), (px + r, py + r)], fill=(32, 95, 50, 255), outline=(14, 40, 22, 255), width=6)
        draw.ellipse([(px - r + 8, py - r + 6), (px + r - 8, py + r - 14)], fill=(75, 195, 90, 255))

    img.save("assets/textures/foliage_tree_sheet.png")
    print("Created assets/textures/foliage_tree_sheet.png")

create_green_leaf()
create_autumn_leaf()
create_snowflake()
create_foliage_sheet()
