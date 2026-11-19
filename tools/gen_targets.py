"""Generates src/range/Targets.project.json: every target on the test range.

Run from the project folder:  python tools/gen_targets.py

Layout (firing line at z=-5, shooter faces -z):
  DISTANCE lane   x=-26   unarmored dummies at 25/50/75/100/140 studs
  ARMOR lane      x=-10.5..10.5, z=-38   four dummies; armor is set by attributes and can be
                  changed from the range console (RangeService). TargetService builds the
                  visible armor from Visual/ArmorModels at runtime.
  AIM TRAINER     x=18..34   steel plates that clang and drop, plus one dummy on a moving sled

Every hittable part carries a `Zone` attribute (Head/Torso/Arms/Legs). A target is a Model
directly inside Targets with Health/MaxHealth/Helmet/BodyArmor attributes (see TargetService).
Stands and signs live in sub-folders so they are never treated as targets.
"""

import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "range", "Targets.project.json")

FIRING_LINE_Z = -5


def rgb(r, g, b):
    return [round(r / 255, 4), round(g / 255, 4), round(b / 255, 4)]


def rot_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


FACE = rot_y(180)  # dummy front (-Z) turned towards the shooter (+z world)
IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def cf(pos, rot=None):
    return {"CFrame": {"position": [round(v, 4) for v in pos],
                       "orientation": [[round(v, 6) for v in row] for row in (rot or IDENTITY)]}}


def part(size, pos, color, material, rot=None, shape=None, zone=None, anchored=True, collide=False,
         extra=None, children=None):
    props = {"Anchored": anchored, "CanCollide": collide, "CanTouch": False,
             "Size": [round(v, 4) for v in size], "CFrame": cf(pos, rot), "Color": color, "Material": material,
             "TopSurface": "Smooth", "BottomSurface": "Smooth"}
    if shape:
        props["Shape"] = shape
    attrs = {}
    if zone:
        attrs["Zone"] = {"String": zone}
    if extra:
        attrs.update(extra)
    if attrs:
        props["Attributes"] = attrs
    node = {"$className": "Part", "$properties": props}
    if children:
        node.update(children)
    return node


SKIN = rgb(176, 166, 148)
STEEL = rgb(84, 88, 90)
SHIRTS = [rgb(86, 92, 74), rgb(70, 74, 80), rgb(96, 84, 66), rgb(64, 68, 60)]
PANTS = [rgb(58, 62, 70), rgb(76, 72, 60), rgb(52, 56, 50)]
BOOT = rgb(46, 38, 32)


def upright(lean=0):
    # Cylinder (axis X) stood up, optionally leaning sideways by `lean` degrees.
    return mul(FACE, rot_z(90 + lean))


def dummy(x, z, helmet="", body="", shirt=0, pants=0, health=100, extra_attrs=None):
    s = SHIRTS[shirt % len(SHIRTS)]
    p = PANTS[pants % len(PANTS)]
    attrs = {"Health": {"Float64": health}, "MaxHealth": {"Float64": health},
             "Helmet": {"String": helmet}, "BodyArmor": {"String": body}}
    if extra_attrs:
        attrs.update(extra_attrs)
    m = {"$className": "Model", "$properties": {"Attributes": attrs}}

    def add(name, node):
        key = name
        n = 2
        while key in m:
            key = f"{name} {n}"
            n += 1
        m[key] = node

    # Dummy-local x is mirrored by FACE, so "left"/"right" are from the dummy's point of view.
    for side in (-1, 1):
        sx = x + side * 0.42
        add("Foot", part((0.55, 0.3, 0.95), (sx, 0.15, z + 0.12), BOOT, "Leather", rot=FACE, zone="Legs"))
        add("Shin", part((1.15, 0.5, 0.5), (sx, 0.88, z), p, "Fabric", rot=upright(), shape="Cylinder", zone="Legs"))
        add("Knee", part((0.52, 0.52, 0.52), (sx, 1.45, z), p, "Fabric", shape="Ball", zone="Legs"))
        add("Thigh", part((1.15, 0.62, 0.62), (sx, 2.03, z), p, "Fabric", rot=upright(), shape="Cylinder", zone="Legs"))
        ax = x + side * 1.2
        add("Upper arm", part((1.05, 0.45, 0.45), (ax, 4.18, z), s, "Fabric", rot=upright(side * 6), shape="Cylinder", zone="Arms"))
        add("Elbow", part((0.42, 0.42, 0.42), (x + side * 1.25, 3.62, z), s, "Fabric", shape="Ball", zone="Arms"))
        add("Forearm", part((1.0, 0.4, 0.4), (x + side * 1.29, 3.1, z + 0.04), s, "Fabric", rot=upright(side * 3), shape="Cylinder", zone="Arms"))
        add("Hand", part((0.42, 0.42, 0.42), (x + side * 1.31, 2.5, z + 0.06), SKIN, "SmoothPlastic", shape="Ball", zone="Arms"))
    add("Pelvis", part((1.5, 0.55, 0.8), (x, 2.84, z), p, "Fabric", rot=FACE, zone="Torso"))
    add("Abdomen", part((1.55, 0.8, 0.78), (x, 3.5, z), s, "Fabric", rot=FACE, zone="Torso"))
    add("Chest", part((1.95, 1.05, 0.9), (x, 4.35, z), s, "Fabric", rot=FACE, zone="Torso"))
    add("Neck", part((0.35, 0.45, 0.45), (x, 5.05, z), SKIN, "SmoothPlastic", rot=upright(), shape="Cylinder", zone="Torso"))
    add("Head", part((1.0, 1.15, 1.05), (x, 5.75, z), SKIN, "SmoothPlastic", rot=FACE, zone="Head", children={
        "Mesh": {"$className": "SpecialMesh", "$properties": {"MeshType": "Head", "Scale": [1, 1, 1]}}}))
    return m


def stand(folder, x, z, label):
    folder[f"Base {label}"] = part((2.8, 0.25, 1.8), (x, 0.125, z - 0.35), rgb(52, 54, 55), "DiamondPlate",
                                   collide=True)
    folder[f"Post {label}"] = part((0.28, 5.0, 0.28), (x, 2.75, z - 0.6), STEEL, "Metal")
    folder[f"Arm {label}"] = part((0.25, 0.25, 0.5), (x, 4.35, z - 0.48), STEEL, "Metal")


def plate(x, z, height, diameter):
    attrs = {"Health": {"Float64": 1}, "MaxHealth": {"Float64": 1}, "Helmet": {"String": ""},
             "BodyArmor": {"String": ""}, "Kind": {"String": "Steel"}, "ResetDelay": {"Float64": 1.2}}
    m = {"$className": "Model", "$properties": {"Attributes": attrs}}
    m["Plate"] = part((0.18, diameter, diameter), (x, height, z), rgb(196, 190, 170), "Metal",
                      rot=rot_y(90), shape="Cylinder", zone="Torso")
    m["Plate face"] = part((0.02, diameter * 0.35, diameter * 0.35), (x, height, z + 0.1), rgb(220, 70, 50),
                           "SmoothPlastic", rot=rot_y(90), shape="Cylinder", zone="Torso")
    return m


def plate_stand(folder, key, x, z, height):
    folder[f"Plate post {key}"] = part((0.2, height, 0.2), (x, height / 2, z - 0.25), STEEL, "Metal")
    folder[f"Plate foot {key}"] = part((1.6, 0.2, 1.2), (x, 0.1, z - 0.25), rgb(52, 54, 55), "Metal", collide=True)


def floor_sign(text, pos, size=(5, 0.05, 1.4), color=rgb(232, 196, 120)):
    return part(size, pos, rgb(30, 32, 30), "Metal", children={
        "SurfaceGui": {"$className": "SurfaceGui",
                       "$properties": {"Face": "Top", "LightInfluence": 1, "PixelsPerStud": 40,
                                       "SizingMode": "PixelsPerStud"},
                       "Label": {"$className": "TextLabel",
                                 "$properties": {"BackgroundTransparency": 1, "Font": "GothamBold",
                                                 "Size": {"UDim2": [[1, 0], [1, 0]]}, "Text": text,
                                                 "TextColor3": color, "TextScaled": True,
                                                 "Rotation": 180}}}})


def hanging_sign(text, pos, width, color):
    return part((width, 1.6, 0.2), pos, rgb(26, 28, 27), "Metal", children={
        "SurfaceGui": {"$className": "SurfaceGui",
                       "$properties": {"Face": "Back", "LightInfluence": 0.4, "PixelsPerStud": 40,
                                       "SizingMode": "PixelsPerStud"},
                       "Label": {"$className": "TextLabel",
                                 "$properties": {"BackgroundTransparency": 1, "Font": "GothamBlack",
                                                 "Size": {"UDim2": [[0.94, 0], [0.8, 0]]},
                                                 "Position": {"UDim2": [[0.03, 0], [0.1, 0]]},
                                                 "Text": text, "TextColor3": color, "TextScaled": True}}}})


tree = {"$className": "Folder"}
stands = {"$className": "Folder"}
signs = {"$className": "Folder"}

# Distance lane
for i, d in enumerate((25, 50, 75, 100, 140)):
    z = FIRING_LINE_Z - d
    tree[f"D{d}  DISTANCE {d}"] = dummy(-26, z, shirt=i, pants=i)
    stand(stands, -26, z, f"D{d}")
    signs[f"Plaque D{d}"] = floor_sign(f"{d} STUDS", (-26, 0.03, z + 2.2))

# Armor lane
ARMOR = [("", ""), ("LightHelmet", "SoftVest"), ("MidHelmet", "PlateCarrier"), ("HeavyHelmet", "HeavyPlates")]
for i, (x, (helmet, body)) in enumerate(zip((-10.5, -3.5, 3.5, 10.5), ARMOR)):
    tree[f"A{i + 1}  ARMOR {i + 1}"] = dummy(x, -38, helmet, body, shirt=i + 1, pants=i,
                                            extra_attrs={"ArmorLane": {"Float64": i + 1}})
    stand(stands, x, -38, f"A{i + 1}")
    signs[f"Plaque A{i + 1}"] = floor_sign(f"A{i + 1}", (x, 0.03, -35.6), size=(2, 0.05, 1.2))

# Aim trainer: steel plates
PLATES = [(19, -22, 4.6, 1.3), (24, -30, 3.2, 1.0), (29, -40, 5.2, 0.9), (34, -48, 2.4, 1.2),
          (20, -62, 4.8, 0.9), (27, -84, 3.6, 1.2), (33, -110, 4.4, 1.4)]
for i, (x, z, h, d) in enumerate(PLATES):
    tree[f"S{i + 1}  STEEL {i + 1}"] = plate(x, z, h, d)
    plate_stand(stands, f"S{i + 1}", x, z, h - d / 2)

# Aim trainer: moving dummy (RangeService slides the whole model along x)
mover = dummy(25, -70, shirt=3, pants=2, extra_attrs={"Mover": {"Bool": True}})
mover["Sled"] = part((2.8, 0.3, 1.8), (25, 0.15, -70.35), rgb(150, 120, 40), "Metal")
mover["Sled post"] = part((0.28, 5.0, 0.28), (25, 2.75, -70.6), STEEL, "Metal")
tree["M1  MOVER"] = mover

# Lane headers, hanging over the firing line
signs["Header distance"] = hanging_sign("DISTANCE", (-26, 10.4, -9), 12, rgb(232, 196, 120))
signs["Header armor"] = hanging_sign("ARMOR TEST", (0, 10.4, -9), 16, rgb(120, 200, 255))
signs["Header aim"] = hanging_sign("AIM TRAINER", (26, 10.4, -9), 12, rgb(255, 140, 110))

# Spotlights so every target reads clearly against the dark hall.
lights = {"$className": "Folder"}


def spot(key, x, z, color, brightness=3.2, angle=40):
    lights[key] = part((0.9, 0.35, 0.9), (x, 13.2, z + 3.5), rgb(24, 24, 24), "Metal", children={
        "SpotLight": {"$className": "SpotLight",
                      "$properties": {"Face": "Bottom", "Angle": angle, "Brightness": brightness, "Range": 20,
                                      "Shadows": True, "Color": color}}})


for d in (25, 50, 75, 100, 140):
    spot(f"Spot D{d}", -26, FIRING_LINE_Z - d, rgb(255, 232, 196))
for i, x in enumerate((-10.5, -3.5, 3.5, 10.5)):
    spot(f"Spot A{i + 1}", x, -38, rgb(225, 238, 255), brightness=3.6, angle=34)
for i, (x, z, _, _) in enumerate(PLATES):
    spot(f"Spot S{i + 1}", x, z, rgb(255, 214, 190), brightness=2.4, angle=30)
spot("Spot M1", 25, -70, rgb(255, 214, 190), brightness=3, angle=70)
# The mover's rail.
stands["Mover rail"] = part((18, 0.12, 0.5), (25, 0.06, -70.35), rgb(150, 120, 40), "Metal")
tree["Lights"] = lights
tree["Stands"] = stands
tree["Signs"] = signs

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    json.dump({"name": "Targets", "tree": tree}, f, indent=1)
    f.write("\n")
print("wrote", OUT)
