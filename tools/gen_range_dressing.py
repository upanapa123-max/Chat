"""Generates src/range/Dressing.project.json: the set dressing for the indoor shooting range.

Run from the project folder:  python tools/gen_range_dressing.py

Everything here is cosmetic world geometry (pillars, beams, ducts, pipes, benches, booth
partitions, target stands, backstop, barrels, crates, lockers, grime, hanging lamps, dust).
The target dummies themselves stay in Workspace.project.json because the server reads them.

Room reference (from Workspace.project.json): floor top y=0, inner walls x=+-37.5,
z from 15.5 (spawn end) to -159.5 (backstop end), ceiling underside y=13.5.
Targets: 01 (-12,-35), 02 (0,-49), 03 (13,-65), 04 (-15,-112). Firing line z=-5.

Rotations are written as Rojo row-major matrices.
"""

import json
import math
import os
import random

random.seed(1987)  # deterministic output: re-running gives the same file

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "range", "Dressing.project.json")


def rgb(r, g, b):
    return [round(r / 255, 4), round(g / 255, 4), round(b / 255, 4)]


def rot_x(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
ALONG_Z = rot_y(90)  # cylinder (axis X) turned to run along Z
UPRIGHT = rot_z(90)  # cylinder (axis X) turned upright


def rounded(m):
    return [[round(v, 6) for v in row] for row in m]


class Folder:
    def __init__(self):
        self.children = {}
        self.counts = {}

    def _name(self, name):
        n = self.counts.get(name, 0) + 1
        self.counts[name] = n
        return name if n == 1 else f"{name} {n}"

    def add(self, name, node):
        key = self._name(name)
        self.children[key] = node
        return node

    def folder(self, name):
        sub = Folder()
        self.add(name, sub)
        return sub

    def to_json(self):
        out = {"$className": "Folder"}
        for key, node in self.children.items():
            out[key] = node.to_json() if isinstance(node, Folder) else node
        return out


def part(size, pos, color, material, rot=None, shape=None, collide=True, query=True,
         transparency=None, cls="Part", extra=None, children=None, shadow=True):
    props = {
        "Anchored": True,
        "CanTouch": False,
        "Size": [round(v, 4) for v in size],
        "CFrame": {"CFrame": {"position": [round(v, 4) for v in pos],
                              "orientation": rounded(rot or IDENTITY)}},
        "Color": color,
        "Material": material,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if not collide:
        props["CanCollide"] = False
    if not query:
        props["CanQuery"] = False
    if not shadow:
        props["CastShadow"] = False
    if shape:
        props["Shape"] = shape
    if transparency is not None:
        props["Transparency"] = transparency
    if extra:
        props.update(extra)
    node = {"$className": cls, "$properties": props}
    if children:
        node.update(children)
    return node


def sign(text, size, pos, rot=None, color=rgb(232, 196, 120), back=rgb(30, 32, 30), face="Front"):
    return part(size, pos, back, "Metal", rot=rot, children={
        "SurfaceGui": {
            "$className": "SurfaceGui",
            "$properties": {"Face": face, "LightInfluence": 1, "PixelsPerStud": 40,
                            "SizingMode": "PixelsPerStud"},
            "TextLabel": {
                "$className": "TextLabel",
                "$properties": {"BackgroundTransparency": 1, "Font": "GothamBold",
                                "Size": {"UDim2": [[0.92, 0], [0.8, 0]]},
                                "Position": {"UDim2": [[0.04, 0], [0.1, 0]]},
                                "Text": text, "TextColor3": color, "TextScaled": True},
            },
        },
    })


# Palette
CONCRETE = rgb(70, 72, 70)
CONCRETE_DARK = rgb(44, 45, 44)
GRIME = rgb(26, 26, 24)
RUST = rgb(92, 70, 52)
STEEL = rgb(96, 98, 98)
STEEL_DARK = rgb(52, 54, 55)
WOOD = rgb(112, 88, 60)
OLIVE = rgb(70, 74, 54)
HAZARD = rgb(186, 150, 46)
BLACK = rgb(24, 24, 24)

root = Folder()

# --- Structure -------------------------------------------------------------------------------
structure = root.folder("Structure")
PILLAR_Z = [4, -20, -44, -68, -92, -116, -140]
for z in PILLAR_Z:
    for x in (-36.3, 36.3):
        structure.add("Pillar", part((2.4, 13.5, 2.6), (x, 6.75, z), CONCRETE, "Concrete"))
        structure.add("Pillar foot", part((2.8, 1.0, 3.0), (x, 0.5, z), CONCRETE_DARK, "Concrete"))
    structure.add("Ceiling beam", part((75, 1.1, 1.3), (0, 12.95, z), RUST, "CorrodedMetal"))
for x in (-37.25, 37.25):
    structure.add("Wall grime band", part((0.5, 3.2, 175), (x, 1.6, -72), CONCRETE_DARK, "Concrete"))
    structure.add("Wall stripe", part((0.55, 0.35, 175), (x, 3.35, -72), HAZARD, "Concrete"))
structure.add("Backstop berm", part((75, 4.5, 7), (0, 2.25, -156), rgb(104, 90, 70), "Sand"))
for i, x in enumerate((-30, -18, -6, 6, 18, 30)):
    structure.add("Deflector plate",
                  part((11.6, 9, 0.6), (x, 7.5, -152.8), rgb(64, 56, 48), "DiamondPlate", rot=rot_x(-28)))
structure.add("Backstop header", part((75, 1.5, 3), (0, 12.6, -151), STEEL_DARK, "Metal"))

# --- Overhead services -----------------------------------------------------------------------
services = root.folder("Services")
services.add("Duct", part((3.6, 2.2, 168), (-27, 11.4, -70), rgb(110, 112, 110), "Metal"))
for z in range(10, -152, -12):
    services.add("Duct band", part((3.9, 2.5, 0.35), (-27, 11.4, z), rgb(86, 88, 86), "Metal"))
for y, d, col in ((10.6, 0.7, RUST), (11.5, 0.5, rgb(60, 70, 60)), (12.2, 0.35, STEEL_DARK)):
    services.add("Pipe", part((174, d, d), (36.7, y, -72), col, "CorrodedMetal", rot=ALONG_Z, shape="Cylinder"))
for z in range(14, -158, -16):
    services.add("Pipe bracket", part((0.3, 2.2, 0.3), (37.1, 11.3, z), STEEL_DARK, "Metal"))
services.add("Cable tray", part((1.6, 0.25, 174), (-35.8, 9.6, -72), STEEL_DARK, "DiamondPlate"))
services.add("Cables", part((174, 0.45, 0.45), (-35.8, 9.85, -72), BLACK, "Rubber", rot=ALONG_Z, shape="Cylinder"))

# --- Firing line -------------------------------------------------------------------------------
line = root.folder("FiringLine")
x = -31.0
toggle = False
while x < 31:
    line.add("Hazard stripe", part((2, 0.04, 0.7), (x + 1, 0.02, -5.8), HAZARD if toggle else BLACK,
                                   "Concrete", collide=False))
    toggle = not toggle
    x += 2
for bx in (-31, -14, 14, 31):
    line.add("Booth partition", part((0.35, 6.5, 5), (bx, 3.25, -2.8), WOOD, "WoodPlanks"))
    line.add("Partition post", part((0.5, 7, 0.5), (bx, 3.5, -5.3), STEEL_DARK, "Metal"))
for bx in (-22.5, -6.5, 6.5, 22.5):
    line.add("Bench top", part((7.5, 0.3, 1.8), (bx, 3.1, -6.6), WOOD, "WoodPlanks"))
    for lx in (-3.4, 3.4):
        line.add("Bench leg", part((0.25, 2.95, 1.5), (bx + lx, 1.48, -6.6), STEEL_DARK, "Metal"))
    line.add("Ammo can", part((1.1, 0.65, 0.55), (bx - 2.2, 3.58, -6.5), OLIVE, "Metal", rot=rot_y(12)))
    line.add("Ammo can lid", part((1.15, 0.08, 0.6), (bx - 2.2, 3.95, -6.5), rgb(60, 64, 46), "Metal", rot=rot_y(12)))
    line.add("Ear defenders", part((0.5, 0.5, 0.25), (bx + 2.4, 3.5, -6.4), BLACK, "Plastic", rot=rot_y(-30)))
    line.add("Spent casings tray", part((1.4, 0.15, 0.9), (bx + 0.6, 3.33, -6.7), STEEL, "Metal"))
line.add("Range light housing", part((1.2, 0.8, 0.6), (0, 12.6, -5.5), BLACK, "Metal"))
line.add("Range light", part((0.8, 0.5, 0.3), (0, 12.3, -5.9), rgb(255, 40, 30), "Neon", collide=False, query=False,
                             children={"PointLight": {"$className": "PointLight",
                                                      "$properties": {"Color": rgb(255, 50, 40), "Brightness": 1.2,
                                                                      "Range": 10}}}))
line.add("Rule sign", sign("CEASE FIRE ON RED LIGHT   ·   EYE AND EAR PROTECTION", (16, 1.2, 0.15),
                            (0, 10.6, -5.6), rot=rot_y(180), face="Front"))

# --- Target stands (cosmetic, behind the dummies) ------------------------------------------------
stands = root.folder("TargetStands")
for tx, tz in ((-12, -35), (0, -49), (13, -65), (-15, -112)):
    stands.add("Stand base", part((3, 0.25, 2), (tx, 0.125, tz - 0.4), STEEL_DARK, "DiamondPlate"))
    stands.add("Stand post", part((0.3, 6.2, 0.3), (tx, 3.1, tz - 1.1), STEEL, "Metal"))
    stands.add("Stand arm", part((2.2, 0.25, 0.25), (tx, 6.1, tz - 1.1), STEEL, "Metal"))
    stands.add("Lane spot", part((1.0, 0.4, 1.0), (tx, 13.2, tz + 3), BLACK, "Metal", collide=False, query=False,
                                 children={"SpotLight": {"$className": "SpotLight",
                                                         "$properties": {"Face": "Bottom", "Angle": 38,
                                                                         "Brightness": 3.2, "Range": 18,
                                                                         "Shadows": True,
                                                                         "Color": rgb(255, 236, 205)}}}))
    # Floor scuffs where the stand has been dragged around.
    stands.add("Scuff", part((4.5, 0.02, 3), (tx + random.uniform(-0.5, 0.5), 0.011, tz - 0.3), GRIME, "Concrete",
                             collide=False, query=False, transparency=0.55, shadow=False))

# --- Props -----------------------------------------------------------------------------------
props = root.folder("Props")
for (bx, bz, col) in ((-34, 12, rgb(110, 42, 30)), (-31.6, 13, rgb(40, 58, 82)), (-33.8, 9.4, rgb(110, 42, 30)),
                      (33.4, -30, rgb(48, 58, 46)), (35, -32.4, rgb(110, 42, 30)), (-34.5, -128, rgb(48, 58, 46))):
    props.add("Oil drum", part((3, 2, 2), (bx, 1.5, bz), col, "CorrodedMetal", rot=UPRIGHT, shape="Cylinder"))
    props.add("Drum rim", part((0.1, 2.06, 2.06), (bx, 2.96, bz), STEEL_DARK, "Metal", rot=UPRIGHT, shape="Cylinder"))
props.add("Drum on side", part((3, 2, 2), (-30.5, 1.0, 9.0), rgb(82, 70, 40), "CorrodedMetal", rot=rot_y(70), shape="Cylinder"))
for (cx, cy, cz, r) in ((33.5, 1.5, 7, 0), (33.5, 4.5, 7.2, 8), (30.4, 1.5, 7.6, -6), (34, 1.5, -86, 3), (34, 1.5, -89.2, -4)):
    props.add("Crate", part((3, 3, 3), (cx, cy, cz), WOOD, "WoodPlanks", rot=rot_y(r)))
props.add("Pallet", part((4, 0.45, 4), (-33, 0.23, -60), rgb(120, 98, 70), "Wood"))
props.add("Pallet load", part((3.6, 2.2, 3.6), (-33, 1.55, -60), rgb(150, 140, 110), "Fabric"))
for i in range(6):
    props.add("Locker", part((1.9, 6.4, 1.6), (12 + i * 2, 3.2, 14.6), rgb(84, 92, 86), "Metal"))
    props.add("Locker vent", part((1.2, 0.6, 0.05), (12 + i * 2, 5.4, 13.78), BLACK, "Metal"))
for (jx, jz) in ((-33, -80), (-33, -104), (33, -98)):
    props.add("Jersey barrier", part((2.2, 3, 6.5), (jx, 1.5, jz), rgb(150, 148, 140), "Concrete"))
    props.add("Barrier stain", part((2.25, 1.0, 6.55), (jx, 0.5, jz), rgb(80, 76, 70), "Concrete", collide=False))
for (sx, sz) in ((-29, -22), (29, -46), (-28, -96)):
    for i in range(3):
        props.add("Sandbag", part((3.2, 0.8, 1.4), (sx + (i % 2) * 0.6, 0.4 + i * 0.75, sz), rgb(132, 120, 90), "Fabric",
                                  rot=rot_y(random.uniform(-6, 6))))
props.add("Wall sign", sign("SECTOR 4  ·  TRAINING HALL B", (12, 1.6, 0.15), (-37.0, 8, -30), rot=rot_y(90)))
props.add("Wall sign", sign("CONTAMINATION LEVEL: NOMINAL", (10, 1.2, 0.15), (37.0, 7, -70), rot=rot_y(-90),
                            color=rgb(150, 210, 140)))
props.add("Wall sign", sign("NO LIVE FIRE AFTER SIRENS", (10, 1.2, 0.15), (-37.0, 7, -100), rot=rot_y(90),
                            color=rgb(230, 90, 70)))

# --- Grime on the floor ------------------------------------------------------------------------
grime = root.folder("Grime")
for _ in range(26):
    gx = random.uniform(-33, 33)
    gz = random.uniform(-150, 10)
    w = random.uniform(2, 9)
    d = random.uniform(2, 12)
    grime.add("Stain", part((w, 0.02, d), (gx, 0.012, gz), GRIME, "Concrete", rot=rot_y(random.uniform(0, 180)),
                            collide=False, query=False, transparency=round(random.uniform(0.45, 0.75), 2), shadow=False))
for z in range(0, -150, -30):
    grime.add("Floor drain", part((1.6, 0.03, 1.6), (0, 0.016, z - 12), STEEL_DARK, "DiamondPlate", collide=False))

# --- Lamps -----------------------------------------------------------------------------------
lamps = root.folder("Lamps")
LAMP_Z = [2, -26, -54, -82, -110, -138]
flicker = {(20, -54), (-20, -110)}
for z in LAMP_Z:
    for x in (-20, 20):
        warm = rgb(255, 205, 150)
        lamps.add("Lamp cord", part((0.08, 1.9, 0.08), (x, 12.55, z), BLACK, "Rubber", collide=False, query=False,
                                    shadow=False))
        attrs = {"Attributes": {"Flicker": {"Bool": True}}} if (x, z) in flicker else None
        lamps.add("Lamp shade", part((2.6, 0.6, 2.6), (x, 11.4, z), rgb(52, 66, 52), "Metal",
                                     collide=False, query=False, extra=attrs, children={
                                         "SpotLight": {"$className": "SpotLight",
                                                       "$properties": {"Face": "Bottom", "Angle": 110, "Brightness": 2.4,
                                                                       "Range": 34, "Shadows": True, "Color": warm}}}))
        lamps.add("Lamp bulb", part((0.7, 0.7, 0.7), (x, 11.0, z), rgb(255, 214, 160), "Neon", shape="Ball",
                                    collide=False, query=False, shadow=False, extra=attrs))

# --- Air ---------------------------------------------------------------------------------------
air = root.folder("Air")
air.add("Dust volume", part((72, 11, 168), (0, 6.5, -72), rgb(0, 0, 0), "SmoothPlastic", collide=False, query=False,
                            transparency=1, shadow=False, children={
                                "Dust": {"$className": "ParticleEmitter",
                                         "$properties": {
                                             "Texture": "rbxasset://textures/particles/sparkles_main.dds",
                                             "Rate": 40, "Lifetime": {"NumberRange": [8, 14]},
                                             "Speed": {"NumberRange": [0.05, 0.3]},
                                             "SpreadAngle": [180, 180],
                                             "Size": {"NumberSequence": {"keypoints": [
                                                 {"time": 0, "value": 0.05, "envelope": 0},
                                                 {"time": 1, "value": 0.05, "envelope": 0}]}},
                                             "Transparency": {"NumberSequence": {"keypoints": [
                                                 {"time": 0, "value": 1, "envelope": 0},
                                                 {"time": 0.3, "value": 0.55, "envelope": 0},
                                                 {"time": 1, "value": 1, "envelope": 0}]}},
                                             "Color": {"ColorSequence": {"keypoints": [
                                                 {"time": 0, "color": rgb(220, 205, 180)},
                                                 {"time": 1, "color": rgb(220, 205, 180)}]}},
                                             "LightInfluence": 1, "LightEmission": 0.15,
                                             "Shape": "Box", "ShapeStyle": "Volume",
                                         }}}))

project = {"name": "Dressing", "tree": root.to_json()}
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    json.dump(project, f, indent=1)
    f.write("\n")
print("wrote", OUT)
