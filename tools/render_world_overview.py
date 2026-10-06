"""Render a labeled top-down review image from the generated Rojo model."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "src" / "world" / "CrownlessWorld.model.json"
OUTPUT = ROOT / "world-overview.png"
WIDTH, HEIGHT = 1440, 940
LEFT, TOP, SCALE = 92, 155, 1.55

image = Image.new("RGB", (WIDTH, HEIGHT), (25, 28, 27))
draw = ImageDraw.Draw(image, "RGBA")


def font(size: int, bold: bool = False):
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def to_screen(x: float, z: float) -> tuple[float, float]:
    return LEFT + (x + 260) * SCALE, TOP + (z + 230) * SCALE


def walk(node):
    yield node
    for child in node.get("Children", []):
        yield from walk(child)


data = json.loads(MODEL.read_text(encoding="utf-8"))
items = []
for instance in walk(data):
    properties = instance.get("Properties", {})
    size = properties.get("Size")
    position = properties.get("Position")
    if "CFrame" in properties:
        frame = properties["CFrame"]
        position = frame[:3]
    if not size or not position:
        continue
    items.append((position[1], instance, properties, size, position))

for _, instance, properties, size, position in sorted(items, key=lambda item: item[0]):
    x, z = position[0], position[2]
    sx, sz = size[0], size[2]
    x0, y0 = to_screen(x - sx / 2, z - sz / 2)
    x1, y1 = to_screen(x + sx / 2, z + sz / 2)
    # Keep distant hill silhouettes inside the map frame, away from the title/footer.
    x0, y0 = max(x0, LEFT), max(y0, TOP)
    x1, y1 = min(x1, WIDTH - 55), min(y1, HEIGHT - 72)
    if x0 >= x1 or y0 >= y1:
        continue
    rgb = properties.get("Color", [0.5, 0.5, 0.5])
    color = tuple(max(0, min(255, round(component * 255))) for component in rgb)
    alpha = round((1 - properties.get("Transparency", 0)) * 255)
    if properties.get("Shape") == "Ball":
        draw.ellipse((x0, y0, x1, y1), fill=(*color, alpha))
    else:
        draw.rectangle((x0, y0, x1, y1), fill=(*color, alpha))

draw.rectangle((LEFT, TOP, WIDTH - 55, HEIGHT - 72), outline=(166, 149, 111, 150), width=2)


def marker(world_x: float, world_z: float, title: str, subtitle: str = ""):
    px, py = to_screen(world_x, world_z)
    radius = 7
    draw.ellipse((px - radius, py - radius, px + radius, py + radius), fill=(212, 172, 103, 255), outline=(24, 26, 24, 255), width=2)
    line = title.upper()
    if subtitle:
        line += "\n" + subtitle
    box = draw.multiline_textbbox((0, 0), line, font=font(13, True), spacing=2)
    width = box[2] - box[0] + 16
    height = box[3] - box[1] + 12
    anchor_x = min(max(px + 12, LEFT + 8), WIDTH - width - 26)
    anchor_y = min(max(py - height / 2, TOP + 3), HEIGHT - height - 80)
    draw.rounded_rectangle((anchor_x, anchor_y, anchor_x + width, anchor_y + height), radius=6, fill=(24, 26, 24, 226), outline=(122, 105, 74, 220), width=1)
    draw.multiline_text((anchor_x + 8, anchor_y + 5), line, font=font(13, True), fill=(231, 222, 198, 255), spacing=2)


marker(0, 0, "Market Square", "Dry well · trading stalls")
marker(-57, -72, "Wayfarers' Hall", "NPC steward · party muster")
marker(58, 69, "Ironwold Inn", "Rest & repair")
marker(75, -70, "Marr's Forge", "Repair & craft")
marker(-76, 68, "The Bitterleaf", "Herbs & tonics")
marker(0, 91, "Arrival", "Active spawn")
marker(174, 0, "Plague Mine", "Group finder entrance")
marker(281, 0, "Old Drift", "Cart rails · timber braces")
marker(425, 0, "Collapsed Vault", "Boss arena · 2-phase layout")

draw.text((62, 34), "CROWNLESS  /  GREYFEN", font=font(29, True), fill=(233, 221, 194, 255))
draw.text((64, 76), "THE LOWLAND MARCH   ·   HUB + PLAGUE MINE BLOCKOUT", font=font(13, True), fill=(180, 162, 121, 255))
draw.text((64, HEIGHT - 50), f"TOP-DOWN WORLD REVIEW   ·   {len(items)} STATIC MAP PIECES   ·   1 ACTIVE HUB SPAWN", font=font(12, True), fill=(160, 157, 143, 255))

image.save(OUTPUT)
print(f"Rendered {OUTPUT}")
