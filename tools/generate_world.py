"""Generate Crownless's editable low-poly hub and starter mine as a Rojo model."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src" / "world" / "CrownlessWorld.model.json"

COLORS = {
    "grass": [0.25, 0.34, 0.24],
    "grass_light": [0.31, 0.40, 0.28],
    "stone": [0.40, 0.39, 0.36],
    "stone_light": [0.54, 0.51, 0.44],
    "stone_dark": [0.22, 0.23, 0.22],
    "wood": [0.29, 0.20, 0.14],
    "wood_light": [0.46, 0.31, 0.20],
    "roof": [0.20, 0.18, 0.17],
    "plaster": [0.62, 0.53, 0.39],
    "plaster_light": [0.72, 0.63, 0.48],
    "iron": [0.22, 0.25, 0.26],
    "gold": [0.73, 0.54, 0.25],
    "glass": [0.18, 0.29, 0.30],
    "water": [0.14, 0.28, 0.31],
    "leaf": [0.20, 0.29, 0.21],
    "leaf_light": [0.29, 0.36, 0.24],
    "ember": [0.84, 0.39, 0.15],
    "bone": [0.70, 0.66, 0.56],
}

world = {"ClassName": "Model", "Children": []}
folders: dict[str, dict] = {}
part_count = 0


def folder(name: str, parent: dict | None = None) -> dict:
    target = parent if parent is not None else world
    item = {"Name": name, "ClassName": "Folder", "Children": []}
    target["Children"].append(item)
    return item


terrain = folder("Terrain")
town = folder("GreyfenTown")
plaza = folder("MarketSquare", town)
buildings = folder("Buildings", town)
props = folder("StreetProps", town)
foliage = folder("MarchWood")
approach = folder("MineApproach")
mine = folder("ThePlagueMine")
mine_entrance = folder("EntranceAndDrift", mine)
mine_chambers = folder("CollapsedVault", mine)
spawns = folder("SpawnPoints")
interaction = folder("Interactables")


def add(
    name: str,
    class_name: str,
    size: tuple[float, float, float],
    pos: tuple[float, float, float],
    color: list[float],
    material: str = "WoodPlanks",
    parent: dict | None = None,
    *,
    anchored: bool = True,
    collide: bool = True,
    transparency: float = 0,
    shape: str | None = None,
    rotation_z: float = 0,
    rotation_y: float = 0,
) -> dict:
    global part_count
    target = parent if parent is not None else world
    if shape:
        class_name = "Part"
    props = {
        "Anchored": anchored,
        "CanCollide": collide,
        "CanQuery": True,
        "CanTouch": False,
        "Color": color,
        "Material": material,
        "Position": list(pos),
        "Size": list(size),
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if transparency:
        props["Transparency"] = transparency
    if shape:
        props["Shape"] = shape
    if rotation_z or rotation_y:
        import math

        z = math.radians(rotation_z)
        y = math.radians(rotation_y)
        cz, sz = math.cos(z), math.sin(z)
        cy, sy = math.cos(y), math.sin(y)
        # Y rotation composed with Z rotation, in Roblox CFrame matrix order.
        matrix = [
            cy * cz, -cy * sz, sy,
            sz, cz, 0,
            -sy * cz, sy * sz, cy,
        ]
        props.pop("Position")
        props.pop("Size")
        props["CFrame"] = [*pos, *matrix]
        props["Size"] = list(size)

    item = {"Name": name, "ClassName": class_name, "Properties": props}
    target["Children"].append(item)
    part_count += 1
    return item


def block(name, size, pos, color, material="WoodPlanks", parent=None, **kwargs):
    return add(name, "Part", size, pos, color, material, parent, **kwargs)


def sign(parent, title, subtitle, pos, width=24, height=8, rotation_y=0, face="Back"):
    board = block(
        title.replace(" ", "") + "Sign",
        (width, height, 1.5),
        pos,
        COLORS["wood"],
        "WoodPlanks",
        parent,
        rotation_y=rotation_y,
    )
    board["Children"] = [
        {
            "Name": "FaceText",
            "ClassName": "SurfaceGui",
            "Properties": {"Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": 24},
            "Children": [
                {
                    "Name": "Title",
                    "ClassName": "TextLabel",
                    "Properties": {
                        "BackgroundColor3": COLORS["wood"],
                        "BackgroundTransparency": 0,
                        "BorderSizePixel": 0,
                        "Font": "GothamBold",
                        "Size": {"UDim2": [[1, 0], [1, 0]]},
                        "Text": title.upper() + "\n" + subtitle,
                        "TextColor3": COLORS["plaster_light"],
                        "TextScaled": True,
                        "TextWrapped": True,
                    },
                }
            ],
        }
    ]
    return board


def prompt(parent, name, action, object_text, pos, max_distance=12):
    part = block(
        name,
        (5, 1, 2),
        pos,
        COLORS["gold"],
        "Wood",
        parent,
        collide=False,
        transparency=1,
    )
    part["Children"] = [
        {
            "Name": "OpenGroupFinder",
            "ClassName": "ProximityPrompt",
            "Properties": {
                "ActionText": action,
                "ObjectText": object_text,
                "KeyboardKeyCode": "E",
                "HoldDuration": 0,
                "MaxActivationDistance": max_distance,
                "RequiresLineOfSight": False,
            },
        }
    ]


def house(name, center, width, depth, wall_color, roof_color, sign_title, subtitle):
    x, _, z = center
    model = folder(name, buildings)
    foundation_h = 2
    wall_h = 17
    floor_y = 1
    wall_y = foundation_h + wall_h / 2
    front_z = z + depth / 2
    back_z = z - depth / 2

    block(name + "StoneFoundation", (width + 4, foundation_h, depth + 4), (x, floor_y, z), COLORS["stone"], "Slate", model)
    # The foundation doubles as an interior floor; dress it with a walkable finish.
    block(name + "InteriorFloor", (width - 5, 0.3, depth - 5), (x, 2.12, z), COLORS["wood_light"], "WoodPlanks", model)
    # Let adjoining wall ends overlap, so seams do not leave daylight through the corners.
    block(name + "RearWall", (width + 4, wall_h, 2), (x, wall_y, back_z), wall_color, "WoodPlanks", model)
    block(name + "WestWall", (4, wall_h, depth + 4), (x - width / 2, wall_y, z), wall_color, "WoodPlanks", model)
    block(name + "EastWall", (4, wall_h, depth + 4), (x + width / 2, wall_y, z), wall_color, "WoodPlanks", model)

    # Split front wall leaves a real, walkable central doorway.
    door_w = 9
    side_w = (width - door_w) / 2
    block(name + "FrontLeft", (side_w + 4, wall_h, 2), (x - (door_w + side_w + 4) / 2, wall_y, front_z), wall_color, "WoodPlanks", model)
    block(name + "FrontRight", (side_w + 4, wall_h, 2), (x + (door_w + side_w + 4) / 2, wall_y, front_z), wall_color, "WoodPlanks", model)
    block(name + "Lintel", (door_w + 1, 4, 3), (x, foundation_h + wall_h - 2, front_z), COLORS["wood"], "Wood", model)
    block(name + "Door", (door_w - 1, 13, 1), (x, 7.5, front_z + 1), COLORS["wood_light"], "WoodPlanks", model, collide=False)
    block(name + "DoorHandle", (0.6, 0.6, 0.4), (x + 2.8, 7.5, front_z + 1.7), COLORS["gold"], "Metal", model, collide=False)

    # Three broad steps bridge the raised stone floor to the lane.
    for index, (offset, y) in enumerate(((4.7, 0.36), (3.2, 0.91), (1.7, 1.46)), start=1):
        block(name + "EntryStep", (door_w + 1, 1.08, 2.1), (x, y, front_z + offset), COLORS["stone_light"], "Slate", model)

    # Timber framing and warm windows make the buildings legible at a distance.
    for offset in (-width / 2 + 3, width / 2 - 3):
        block(name + "FrontPost", (2, wall_h + 2, 2), (x + offset, wall_y, front_z + 0.2), COLORS["wood"], "Wood", model)
    for side_x in (-1, 1):
        for side_z in (-1, 1):
            block(
                name + "CornerPost",
                (3, wall_h + 1, 3),
                (x + side_x * width / 2, wall_y, z + side_z * depth / 2),
                COLORS["wood"],
                "Wood",
                model,
            )
    for window_x in (-width * 0.27, width * 0.27):
        wx = x + window_x
        block(name + "WindowGlass", (5, 6, 0.5), (wx, 12, front_z + 1.2), COLORS["glass"], "Glass", model, collide=False)
        for trim_y in (8.7, 15.3):
            block(name + "WindowTrim", (6, 0.7, 0.8), (wx, trim_y, front_z + 1.5), COLORS["wood"], "Wood", model, collide=False)
        block(name + "WindowMullion", (0.6, 6, 0.8), (wx, 12, front_z + 1.5), COLORS["wood"], "Wood", model, collide=False)

    # A stepped shingle roof reads clearly in the low-poly style and is easy to edit.
    roof_step = (width / 2 + 2) / 3
    roof_y = foundation_h + wall_h + 1.5
    for side in (-1, 1):
        for index in range(3):
            center_offset = width / 2 - roof_step / 2 - index * (roof_step - 1)
            block(
                name + "RoofCourse",
                (roof_step + 1.5, 3, depth + 9),
                (x + side * center_offset, roof_y + index * 2.6, z),
                roof_color,
                "Slate",
                model,
            )
    block(name + "RidgeCap", (5, 3, depth + 10), (x, roof_y + 7.8, z), roof_color, "Slate", model)
    sign(model, sign_title, subtitle, (x, foundation_h + wall_h + 1.5, front_z + 5.5), min(width * 0.72, 32), 5)
    return model


def interior_table(parent, name, x, z, width=14, depth=5):
    block(name + "Top", (width, 1.4, depth), (x, 4.1, z), COLORS["wood_light"], "WoodPlanks", parent)
    for dx in (-width / 2 + 1.2, width / 2 - 1.2):
        for dz in (-depth / 2 + 0.8, depth / 2 - 0.8):
            block(name + "Leg", (1.1, 3.4, 1.1), (x + dx, 2.3, z + dz), COLORS["wood"], "Wood", parent)


def interior_bench(parent, x, z, width=10, rotation_y=0):
    block("BenchSeat", (width, 1.2, 2.5), (x, 3.3, z), COLORS["wood_light"], "Wood", parent, rotation_y=rotation_y)
    for dx in (-width / 2 + 1, width / 2 - 1):
        block("BenchLeg", (1.1, 2.5, 2), (x + dx, 1.8, z), COLORS["wood"], "Wood", parent, rotation_y=rotation_y)


def furnish_building(name, center, width, depth):
    x, _, z = center
    model = next(child for child in buildings["Children"] if child["Name"] == name)
    if name == "GuildHall":
        interior_table(model, "CharterTable", x, z - 9, 23, 7)
        for offset in (-15, 15):
            interior_bench(model, x + offset, z - 9, 8)
        block("RealmMapBoard", (17, 8, 0.8), (x, 8, z - depth / 2 + 3), COLORS["wood"], "WoodPlanks", model)
        block("GuildHearth", (7, 7, 5), (x - width / 2 + 7, 5.5, z - depth / 2 + 5), COLORS["stone_dark"], "Slate", model)
        block("HearthGlow", (3, 2, 2), (x - width / 2 + 7, 4.5, z - depth / 2 + 2), COLORS["ember"], "Neon", model, collide=False)
    elif name == "IronwoldInn":
        block("InnBarCounter", (27, 4, 5), (x, 4, z - 12), COLORS["wood"], "WoodPlanks", model)
        for dx in (-10, -3, 4, 11):
            block("BarrelStool", (2.4, 2.6, 2.4), (x + dx, 3.3, z - 6), COLORS["wood_light"], "Wood", model)
        for dx in (-11, 11):
            interior_table(model, "TaproomTable", x + dx, z + 2, 11, 5)
            interior_bench(model, x + dx, z + 7, 9)
        block("InnHearth", (8, 9, 5), (x - width / 2 + 7, 6.5, z - depth / 2 + 6), COLORS["stone_dark"], "Slate", model)
        glow = block("InnFire", (3, 3, 2), (x - width / 2 + 7, 4.8, z - depth / 2 + 3), COLORS["ember"], "Neon", model, collide=False)
        glow["Children"] = [{"Name": "HearthLight", "ClassName": "PointLight", "Properties": {"Brightness": 0.7, "Color": [1, 0.51, 0.25], "Range": 14, "Shadows": False}}]
        for level in range(3):
            block("Cask", (4, 5, 4), (x + width / 2 - 6, 4.5, z + 8 - level * 7), COLORS["wood_light"], "Wood", model, shape="Cylinder")
    elif name == "Blacksmith":
        block("AnvilHorn", (7, 3.5, 4), (x + 9, 3.7, z - 7), COLORS["iron"], "Metal", model)
        block("AnvilBase", (5, 3, 5), (x + 9, 2.3, z - 7), COLORS["stone_dark"], "Slate", model)
        block("ForgeStone", (9, 6, 6), (x - 12, 5, z - 12), COLORS["stone_dark"], "Slate", model)
        forge = block("ForgeCoal", (4, 2, 3), (x - 12, 7.5, z - 12), COLORS["ember"], "Neon", model, collide=False)
        forge["Children"] = [{"Name": "ForgeLight", "ClassName": "PointLight", "Properties": {"Brightness": 1.1, "Color": [1, 0.38, 0.13], "Range": 18, "Shadows": True}}]
        block("SmithWorktable", (18, 3, 5), (x + 8, 3.6, z + 6), COLORS["wood"], "WoodPlanks", model)
        block("WeaponRack", (2, 12, 11), (x + width / 2 - 3, 8, z + 5), COLORS["wood_light"], "Wood", model)
        for dz in (-3, 0, 3):
            block("PracticeBlade", (0.6, 8, 1), (x + width / 2 - 2, 8, z + 5 + dz), COLORS["iron"], "Metal", model, collide=False)
    elif name == "Apothecary":
        block("ApothecaryCounter", (25, 3.5, 5), (x, 3.7, z + 7), COLORS["wood"], "WoodPlanks", model)
        for side in (-1, 1):
            shelf_x = x + side * (width / 2 - 5)
            block("HerbShelf", (3, 12, 14), (shelf_x, 8, z - 10), COLORS["wood_light"], "Wood", model)
            for shelf_y in (5, 9, 13):
                block("ShelfBoard", (4, 0.8, 15), (shelf_x, shelf_y, z - 10), COLORS["wood"], "Wood", model)
                for jar_index, jar_z in enumerate((-15, -10, -5)):
                    jar = block("HerbJar", (1.7, 2.8, 1.7), (shelf_x + (0.7 if jar_index % 2 else -0.7), shelf_y + 1.6, z + jar_z), COLORS["glass"], "Glass", model, collide=False, shape="Cylinder")
                    jar["Children"] = [{"Name": "JarTint", "ClassName": "PointLight", "Properties": {"Brightness": 0.08, "Color": [0.43, 0.68, 0.49], "Range": 4, "Shadows": False}}]
        block("Mortar", (4, 3, 4), (x - 7, 4.5, z + 7), COLORS["stone_light"], "Slate", model)
        block("DriedHerbs", (8, 2, 4), (x + 7, 4.5, z + 7), COLORS["leaf_light"], "Grass", model)


def npc_spawn(parent, name, x, y, z):
    marker = block(name, (2, 0.25, 2), (x, y, z), COLORS["gold"], "Neon", parent, collide=False, transparency=1)
    marker["Properties"]["CanQuery"] = False
    marker["Properties"]["CanTouch"] = False


def lamp(parent, x, z, name="MarchLantern"):
    block(name + "Base", (4, 1, 4), (x, 0.5, z), COLORS["stone"], "Slate", parent)
    block(name + "Post", (1.2, 12, 1.2), (x, 7, z), COLORS["wood"], "Wood", parent)
    block(name + "IronArm", (4, 0.8, 0.8), (x + 1.5, 12.2, z), COLORS["iron"], "Metal", parent)
    lantern = block(name + "Lantern", (2, 3, 2), (x + 3, 10.8, z), COLORS["ember"], "Glass", parent, collide=False)
    lantern["Children"] = [{"Name": "WarmLight", "ClassName": "PointLight", "Properties": {"Brightness": 1.2, "Color": [1, 0.68, 0.36], "Range": 18, "Shadows": True}}]


def tree(x, z, index):
    model = folder(f"Oak{index:02d}", foliage)
    height = 10 + (index % 4) * 2
    block("Trunk", (3, height, 3), (x, height / 2, z), COLORS["wood"], "Wood", model)
    for layer in range(3):
        size = 17 - layer * 3
        leafy = add(
            "Canopy",
            "Part",
            (size, 11 - layer, size),
            (x, height + layer * 4, z),
            COLORS["leaf"] if (index + layer) % 2 else COLORS["leaf_light"],
            "LeafyGrass",
            model,
            collide=False,
            shape="Ball",
        )
        leafy["Properties"]["Material"] = "Grass"


def pines(x, z, index):
    model = folder(f"Pine{index:02d}", foliage)
    block("Trunk", (2, 12, 2), (x, 6, z), COLORS["wood"], "Wood", model)
    for layer, width in enumerate((15, 12, 9, 6)):
        block("BoughTier", (width, 7, width), (x, 9 + layer * 4, z), COLORS["leaf"], "Grass", model)


def octagon_ring(parent, name, center, radius, height, width, color, material):
    x, y, z = center
    # Axis-aligned stone segments create a readable low-poly octagonal ring.
    block(name + "North", (radius * 1.35, height, width), (x, y, z - radius), color, material, parent)
    block(name + "South", (radius * 1.35, height, width), (x, y, z + radius), color, material, parent)
    block(name + "East", (width, height, radius * 1.35), (x + radius, y, z), color, material, parent)
    block(name + "West", (width, height, radius * 1.35), (x - radius, y, z), color, material, parent)
    for sx in (-1, 1):
        for sz in (-1, 1):
            block(name + "Corner", (width, height, width), (x + sx * radius * 0.72, y, z + sz * radius * 0.72), color, material, parent)


# Continuous ground slab plus overlapping meadow plates keep the outskirts walkable
# and remove the sharp empty edge visible beyond the first forest ring.
block("GreyfenMarchGround", (1120, 12, 900), (150, -5.75, 0), COLORS["grass"], "Grass", terrain)
block("NorthMeadow", (1080, 0.8, 170), (150, 0.2, -365), COLORS["grass_light"], "Grass", terrain, collide=False)
block("SouthMeadow", (1080, 0.8, 170), (150, 0.2, 365), COLORS["grass_light"], "Grass", terrain, collide=False)
block("WestMeadow", (170, 0.8, 620), (-335, 0.2, 0), COLORS["grass_light"], "Grass", terrain, collide=False)
block("EastMeadow", (170, 0.8, 620), (635, 0.2, 0), COLORS["grass_light"], "Grass", terrain, collide=False)

# Shallow, collidable rises soften the flat map perimeter into traversable marchland.
for index, (x, z, width, height, depth) in enumerate((
    (-190, -315, 185, 30, 112), (25, -335, 210, 36, 132),
    (260, -322, 220, 32, 118), (470, -290, 165, 28, 122),
    (-240, 306, 190, 27, 110), (-30, 330, 210, 31, 126),
    (205, 326, 220, 30, 120), (430, 306, 185, 28, 132),
    (-340, -80, 95, 23, 175), (648, 60, 98, 25, 190),
)):
    add(
        f"MarchlandRise{index + 1:02d}", "Part", (width, height, depth),
        (x, -1.8, z), COLORS["grass"] if index % 2 else COLORS["grass_light"],
        "Grass", terrain, collide=True, shape="Ball",
    )

# Low stone-paved market square, with subtle alternating paver color.
for ix in range(-5, 6):
    for iz in range(-5, 6):
        color = COLORS["stone_light"] if (ix + iz) % 4 else COLORS["stone"]
        block("MarketPaver", (9.2, 0.45, 9.2), (ix * 9.5, 0.22, iz * 9.5), color, "Cobblestone", plaza, collide=False)

# Main roads, raised borders, and a broad road out to the plague mine.
for x in range(-70, 181, 10):
    for lane in (-1, 0, 1):
        block("EastRoadPaver", (9.5, 0.45, 8.5), (x, 0.24, lane * 8.5), COLORS["stone"] if x % 30 else COLORS["stone_light"], "Cobblestone", approach, collide=False)
for z in range(-100, 111, 10):
    for lane in (-1, 0, 1):
        block("NorthSouthRoadPaver", (8.5, 0.45, 9.5), (lane * 8.5, 0.25, z), COLORS["stone_light"] if z % 30 else COLORS["stone"], "Cobblestone", town, collide=False)

block("NorthWall", (272, 9, 4), (0, 4.5, -124), COLORS["stone"], "Slate", town)
block("SouthWall", (272, 9, 4), (0, 4.5, 124), COLORS["stone"], "Slate", town)
block("WestWall", (4, 9, 248), (-134, 4.5, 0), COLORS["stone"], "Slate", town)
block("EastWall", (4, 9, 103), (134, 4.5, -72.5), COLORS["stone"], "Slate", town)
block("EastWall", (4, 9, 103), (134, 4.5, 72.5), COLORS["stone"], "Slate", town)
for x in (-134, 134):
    for z in (-124, 124):
        block("WallMerlon", (8, 12, 8), (x, 6, z), COLORS["stone_light"], "Slate", town)

# The bridge, stream, and southern approach make the spawn point feel like a town entrance.
block("SlowMarchStream", (230, 0.8, 15), (0, 0.05, 151), COLORS["water"], "Water", terrain, collide=False, transparency=0.2)
for x in (-16, -8, 0, 8, 16):
    block("BridgePlank", (7.5, 1.2, 21), (x, 1.1, 151), COLORS["wood_light"], "WoodPlanks", town)
for x in (-20, 20):
    block("BridgeRail", (2, 4, 22), (x, 3, 151), COLORS["wood"], "Wood", town)
for z in (142, 160):
    for x in (-20, 20):
        block("BridgePost", (2.5, 6, 2.5), (x, 4, z), COLORS["stone"], "Slate", town)

# Four useful town buildings frame the central square.
house("GuildHall", (-57, 0, -72), 54, 38, COLORS["plaster_light"], COLORS["roof"], "The Wayfarers' Hall", "PARTIES  •  CONTRACTS")
house("IronwoldInn", (58, 0, 69), 52, 40, COLORS["plaster"], [0.28, 0.21, 0.17], "The Ironwold Inn", "REST  •  REPAIR")
house("Blacksmith", (75, 0, -70), 43, 35, [0.40, 0.36, 0.31], COLORS["roof"], "Marr's Forge", "REPAIR  •  CRAFT")
house("Apothecary", (-76, 0, 68), 42, 34, [0.55, 0.56, 0.44], [0.25, 0.25, 0.22], "The Bitterleaf", "HERBS  •  TONICS")
for building_name, center, width, depth in (
    ("GuildHall", (-57, 0, -72), 54, 38),
    ("IronwoldInn", (58, 0, 69), 52, 40),
    ("Blacksmith", (75, 0, -70), 43, 35),
    ("Apothecary", (-76, 0, 68), 42, 34),
):
    furnish_building(building_name, center, width, depth)

npc_markers = folder("NPCSpawnPoints", town)
npc_spawn(npc_markers, "Tamsin", -57, 2.28, -71)
npc_spawn(npc_markers, "Hedd", 58, 2.28, 73)
npc_spawn(npc_markers, "Marr", 75, 2.28, -68)
npc_spawn(npc_markers, "Nera", -76, 2.28, 68)

# Market canopy stalls, benches, barrels, and a stone well.
for index, x in enumerate((-37, 0, 37)):
    stall = folder(f"MarketStall{index + 1}", props)
    block("Counter", (22, 4, 8), (x, 2, -34), COLORS["wood"], "Wood", stall)
    for post_x in (-9, 9):
        block("AwningPost", (1.5, 12, 1.5), (x + post_x, 6, -42), COLORS["wood_light"], "Wood", stall)
    block("ClothAwning", (24, 1.5, 15), (x, 12, -42), [0.49, 0.29, 0.22] if index % 2 else [0.42, 0.45, 0.33], "Fabric", stall, collide=False)
    for barrel_x in (-6, 6):
        add("TradeBarrel", "Part", (3.2, 4.5, 3.2), (x + barrel_x, 2.25, -28), COLORS["wood_light"], "Wood", stall, shape="Cylinder")

octagon_ring(plaza, "DryWell", (0, 3, 0), 10, 5, 3, COLORS["stone_light"], "Slate")
block("WellDarkWater", (10, 0.5, 10), (0, 4.3, 0), COLORS["water"], "Water", plaza, collide=False)
for x in (-7, 7):
    block("WellPillar", (1.2, 10, 1.2), (x, 10.5, 0), COLORS["wood"], "Wood", plaza)
block("WellCrossbeam", (18, 1.5, 1.5), (0, 16, 0), COLORS["wood_light"], "Wood", plaza)
block("WellRope", (0.5, 8, 0.5), (0, 11.5, 0), COLORS["wood"], "Wood", plaza, collide=False)

# Guild board and a physical activation prompt; the client opens the party UI on E.
board = folder("WayfarersNoticeBoard", interaction)
block("BoardLeg", (2, 14, 2), (-61, 7, -47), COLORS["wood"], "Wood", board)
block("BoardLeg", (2, 14, 2), (-53, 7, -47), COLORS["wood"], "Wood", board)
sign(board, "Wayfarer's Board", "PRESS E TO FIND A PARTY", (-57, 12, -46), 18, 8)
prompt(board, "PartyBoardPrompt", "Open Group Finder", "Wayfarer's Board", (-57, 3, -39))

# Streetside lights and resting spots.
for index, (x, z) in enumerate(((-94, 0), (94, 0), (0, -98), (-99, 60), (99, -60), (-35, 180))):
    lamp(props, x, z, f"MarchLantern{index + 1}")
for x, z in ((-34, 30), (33, 30), (-36, -20), (36, -20)):
    bench = folder("OakBench", props)
    block("Seat", (13, 1.2, 3), (x, 2, z), COLORS["wood_light"], "Wood", bench)
    for leg_x in (-5, 5):
        block("BenchLeg", (1.3, 3, 2), (x + leg_x, 0.7, z), COLORS["wood"], "Wood", bench)

# The eastern gate and a rocky ridge frame the visible mine approach.
for z in (-17, 17):
    block("MineGatePost", (8, 24, 10), (136, 12, z), COLORS["stone_light"], "Slate", approach)
block("MineGateLintel", (8, 5, 44), (136, 24, 0), COLORS["stone"], "Slate", approach)
for x in (147, 166, 185):
    for z in (-44, 44):
        block("RidgeRock", (30, 26 + (x % 3) * 5, 36), (x, 13, z), COLORS["stone_dark"], "Rock", approach)
for z in (-55, 55):
    block("RidgeShoulder", (115, 22, 24), (205, 11, z), COLORS["stone"], "Rock", approach)
for x in (157, 178, 199, 220, 241):
    for z in (-10, 10):
        block("MineRoadStone", (17, 0.5, 9), (x, 0.28, z), COLORS["stone_dark"], "Slate", approach, collide=False)

entrance = folder("CaveMouth", approach)
block("CaveDarkness", (3, 22, 27), (174, 10, 0), [0.055, 0.06, 0.055], "Slate", entrance, collide=False)
for z in (-18, 18):
    block("CaveArchStone", (9, 21, 8), (174, 10.5, z), COLORS["stone_light"], "Slate", entrance)
block("CaveArchTop", (10, 5, 45), (174, 21, 0), COLORS["stone_light"], "Slate", entrance)
block("MineLintelSign", (18, 6, 1.5), (174, 28, 0), COLORS["wood"], "Wood", entrance)
sign(entrance, "Plague Mine", "CLOSED BY ORDER OF THE MARCH", (174, 28, 1.1), 24, 6, rotation_y=90, face="Front")
prompt(entrance, "MinePartyPrompt", "Open Group Finder", "Plague Mine", (161, 2, 0), 14)

# Cave drift has a floor, cut-stone side walls, timber braces, and rusty rail track.
block("MineFloor", (200, 1.2, 54), (281, -0.1, 0), COLORS["stone_dark"], "Slate", mine_entrance)
block("MineLeftWall", (200, 23, 3), (281, 11, -27), COLORS["stone"], "Rock", mine_entrance)
block("MineRightWall", (200, 23, 3), (281, 11, 27), COLORS["stone"], "Rock", mine_entrance)
block("MineRoof", (200, 3, 54), (281, 22, 0), COLORS["stone_dark"], "Rock", mine_entrance)
for x in range(202, 371, 28):
    for z in (-21, 21):
        block("TimberBracePost", (2, 20, 2), (x, 10, z), COLORS["wood"], "Wood", mine_entrance)
    block("TimberBraceHeader", (3, 2, 44), (x, 19, 0), COLORS["wood_light"], "Wood", mine_entrance)
    lamp(mine_entrance, x, -12, "MineLantern")
for z in (-4, 4):
    block("MineCartRail", (190, 0.6, 0.8), (281, 1, z), COLORS["iron"], "Metal", mine_entrance)
for x in range(200, 372, 15):
    block("MineRailSleeper", (2, 0.6, 12), (x, 0.7, 0), COLORS["wood_light"], "Wood", mine_entrance)

# A small abandoned cart and ore crates make the tunnel read as a working mine.
cart = folder("BrokenMineCart", mine_entrance)
block("CartBox", (11, 6, 8), (256, 4, 12), COLORS["wood"], "WoodPlanks", cart)
block("CartRim", (12, 1.5, 9), (256, 7.6, 12), COLORS["iron"], "Metal", cart)
for dx in (-4, 4):
    for dz in (-5, 5):
        add("CartWheel", "Part", (2, 3, 3), (256 + dx, 1.8, 12 + dz), COLORS["iron"], "Metal", cart, shape="Cylinder")
for index, pos in enumerate(((238, 2, -12), (350, 2, 13), (313, 2, -15), (224, 2, 14))):
    block(f"OreCrate{index + 1}", (7, 4, 7), pos, COLORS["wood_light"], "WoodPlanks", mine_entrance)

# The collapsed vault is a broad, readable encounter room beyond the mine drift.
vault = folder("ForemansVault", mine_chambers)
block("VaultFloor", (130, 1.5, 112), (425, -0.2, 0), [0.27, 0.27, 0.25], "Slate", vault)
for z in (-57, 57):
    block("VaultWall", (132, 27, 5), (425, 13, z), COLORS["stone"], "Slate", vault)
for z in (-47, 47):
    block("VaultEntryWall", (5, 27, 22), (361, 13, z), COLORS["stone"], "Slate", vault)
block("VaultEndWall", (5, 27, 115), (489, 13, 0), COLORS["stone"], "Slate", vault)
block("VaultCeiling", (132, 4, 115), (425, 27, 0), COLORS["stone_dark"], "Rock", vault)
for x in (378, 408, 438, 468):
    for z in (-41, 41):
        block("VaultPillar", (8, 24, 8), (x, 12, z), COLORS["stone_light"], "Slate", vault)

# Raised foreman dais and a dormant add-spawn ring, marked for future encounter scripting.
octagon_ring(vault, "ForemanDais", (445, 1.8, 0), 15, 2, 4, COLORS["stone_light"], "Slate")
block("DaisTop", (23, 1, 23), (445, 3.5, 0), COLORS["stone_dark"], "Slate", vault)
for index, (x, z) in enumerate(((405, 0), (430, -29), (474, 0), (430, 29))):
    add(f"AddSpawnMarker{index + 1}", "Part", (8, 0.35, 8), (x, 0.8, z), COLORS["ember"], "Neon", vault, collide=False, transparency=0.45)
for index, (x, z) in enumerate(((395, -40), (395, 40), (465, -40), (465, 40))):
    torch = block("VaultSconce", (2, 5, 2), (x, 18, z), COLORS["ember"], "Neon", vault, collide=False)
    torch["Children"] = [{"Name": "SconceLight", "ClassName": "PointLight", "Properties": {"Brightness": 0.8, "Color": [1, 0.47, 0.20], "Range": 13, "Shadows": False}}]
sign(vault, "The Collapsed Vault", "BOSS ROOM  •  TWO PHASES", (445, 24, 50), 28, 7)

# Main live spawn and clearly named inactive destination markers for a future instanced dungeon.
spawn = add("GreyfenArrival", "SpawnLocation", (12, 1, 12), (0, 0.8, 91), COLORS["gold"], "Slate", spawns)
spawn["Properties"].update({"Neutral": True, "Enabled": True, "Duration": 0, "Transparency": 1, "CanCollide": False})
block("ArrivalMedallion", (18, 0.35, 18), (0, 0.25, 91), COLORS["gold"], "Slate", spawns, collide=False)
mine_spawn = add("MinePartySpawn", "SpawnLocation", (10, 1, 10), (188, 0.7, 0), COLORS["ember"], "Slate", spawns)
mine_spawn["Properties"].update({"Neutral": True, "Enabled": False, "Duration": 0, "Transparency": 1, "CanCollide": False})
for index, role in enumerate(("Tank", "Healer", "Damage", "Controller")):
    role_spawn = add(f"{role}EncounterSpawn", "Part", (4, 0.4, 4), (192, 0.5, -12 + index * 8), COLORS["gold"], "Neon", spawns, collide=False, transparency=0.35)

# A forested boundary and a few dead trees cue the plague-mine direction.
tree_index = 0
for x, z in ((-220, -190), (-180, -225), (-125, -194), (-70, -224), (5, -206), (90, -215), (170, -206), (240, -205), (310, -195), (390, -208), (-230, 192), (-175, 218), (-118, 194), (185, 203), (255, 205), (335, 198), (412, 192), (-255, -60), (-245, 24), (-224, 93), (426, -75), (448, -10), (431, 85), (-178, 145), (265, 150), (370, 146)):
    tree_index += 1
    tree(x, z, tree_index)
for index, (x, z) in enumerate(((-200, -130), (-180, 105), (300, -155), (345, 140), (420, 135), (280, 188)), start=1):
    pines(x, z, index)

# Layered, non-colliding hill silhouettes give the march a visible horizon.
backdrop = folder("DistantScenery", foliage)
hill_sites = (
    (-190, 25, -248, 112, 48, 84), (-45, 23, -276, 130, 44, 78),
    (105, 30, -282, 146, 58, 90), (260, 27, -278, 135, 52, 88),
    (408, 23, -254, 132, 46, 82), (-238, 21, -82, 86, 42, 105),
    (-246, 24, 106, 88, 48, 116), (-196, 25, 228, 130, 50, 100),
    (-42, 25, 276, 122, 49, 88), (123, 27, 278, 142, 55, 92),
    (286, 26, 275, 145, 52, 95), (475, 27, 195, 122, 54, 115),
    (486, 24, 53, 105, 45, 120), (492, 24, -115, 112, 48, 112),
    (-285, 31, -421, 190, 62, 98), (-63, 34, -432, 220, 70, 112),
    (185, 32, -430, 210, 66, 105), (418, 34, -411, 205, 72, 110),
    (-258, 30, 420, 205, 62, 108), (-20, 34, 432, 220, 72, 110),
    (224, 33, 427, 218, 68, 116), (466, 29, 410, 194, 60, 120),
)
for index, (x, y, z, width, height, depth) in enumerate(hill_sites, start=1):
    hill_color = COLORS["grass_light"] if index % 3 else COLORS["grass"]
    add(f"MarchHorizon{index:02d}", "Part", (width, height, depth), (x, y, z), hill_color, "Grass", backdrop, collide=False, shape="Ball")
    if index % 2 == 0:
        add(f"HorizonRock{index:02d}", "Part", (width * 0.42, height * 0.7, depth * 0.42), (x + width * 0.18, y + height * 0.34, z - depth * 0.08), COLORS["stone_dark"], "Rock", backdrop, collide=False, shape="Ball")

# A fallow roadside croft and a broken watch-post give the outskirts a lived-in scale.
croft = folder("AbandonedCroft", backdrop)
block("CroftField", (36, 0.4, 30), (-183, 0.25, 37), [0.35, 0.37, 0.27], "Ground", croft, collide=False)
for x in (-202, -164):
    block("CroftFence", (1.5, 3.5, 32), (x, 1.9, 37), COLORS["wood"], "Wood", croft)
for z in (21, 53):
    block("CroftFence", (40, 3.5, 1.5), (-183, 1.9, z), COLORS["wood"], "Wood", croft)
for row in range(5):
    for crop in range(7):
        block("FallowRow", (0.7, 2.1, 0.7), (-198 + crop * 4.8, 1.3, 27 + row * 5), COLORS["leaf"], "Grass", croft, collide=False)
ruin = folder("BrokenMarchWatch", backdrop)
block("WatchTowerBase", (15, 20, 15), (372, 10, 201), COLORS["stone_dark"], "Slate", ruin)
block("WatchTowerBreak", (13, 12, 13), (372, 26, 201), COLORS["stone"], "Rock", ruin)
block("WatchTowerLintel", (21, 3, 4), (372, 15, 192), COLORS["stone_light"], "Slate", ruin)
block("BrokenKeepWall", (44, 8, 4), (400, 4, 211), COLORS["stone"], "Slate", ruin)
for post_x in (384, 416):
    block("KeepWallPost", (4, 14, 4), (post_x, 7, 211), COLORS["stone_light"], "Slate", ruin)

# An abandoned border tollhouse sits beyond the north trail as a readable horizon landmark.
tollhouse = folder("OldBorderTollhouse", backdrop)
for x, height in ((310, 31), (347, 25), (384, 34)):
    block("TollhouseTower", (13, height, 13), (x, height / 2, -374), COLORS["stone_dark"], "Slate", tollhouse)
    block("TollhouseCap", (18, 3, 18), (x, height + 1.5, -374), COLORS["stone_light"], "Slate", tollhouse)
block("TollhouseCurtainWall", (42, 15, 5), (347, 7.5, -361), COLORS["stone"], "Rock", tollhouse)
block("TollhouseGateGap", (13, 12, 2), (347, 6, -357), COLORS["stone_dark"], "Slate", tollhouse, collide=False)

# Tree lines wrap the play space without crossing its roads or the mine gate.
for index, x in enumerate(range(-205, 431, 42), start=40):
    tree(x, -186 - (index % 3) * 11, index)
    if x < 150 or x > 245:
        tree(x + 14, 185 + (index % 4) * 9, index + 1)
for index, z in enumerate(range(-126, 141, 34), start=70):
    tree(-177 - (index % 2) * 13, z, index)
    if abs(z) > 45:
        tree(454 + (index % 3) * 7, z, index + 1)

# Additional distant tree lines frame the expanded walkable meadows without crossing the road.
for index, x in enumerate(range(-340, 691, 52), start=120):
    tree(x, -388 - (index % 3) * 12, index)
    tree(x + 8, 388 + (index % 4) * 10, index + 1)
for index, z in enumerate(range(-278, 279, 42), start=160):
    tree(-347 - (index % 2) * 10, z, index)
    tree(665 + (index % 3) * 6, z, index + 1)

# Mine warning stones and role-neutral encounters landmarks.
for x in (145, 158, 171):
    block("RoadMarker", (4, 3, 4), (x, 1.5, 24), COLORS["stone_light"], "Slate", approach)
sign(approach, "Greyfen March", "KEEP TO THE LANTERNS", (109, 8, 27), 20, 6)

# Local, non-combat target posts let new characters try their starter kits.
target_spawns = folder("TrainingTargets", town)
for index, x in enumerate((34, 49, 64), start=1):
    npc_spawn(target_spawns, f"PracticeDummy{index}", x, 0.25, 109)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps(world, indent=2), encoding="utf-8")
print(f"Wrote {OUTPUT} with {part_count} anchored map pieces.")
