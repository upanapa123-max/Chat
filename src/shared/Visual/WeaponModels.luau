--[[
	Procedural weapon models built from Roblox parts, so no uploaded meshes are needed and every
	piece is ours to ship. Used for the first-person viewmodel (client) and the third-person model
	on characters (server).

	Model space: -Z is forward along the bore, +Y is up, the origin sits in the receiver on the
	bore axis. Each model has an invisible `Root` part at the origin carrying these Attachments:
	  Muzzle   end of the barrel (flash, tracer start)
	  Aim      the point on the sight line the eye looks through (ADS alignment)
	  Eject    ejection port (shell casings)
	  Grip     where the right hand holds the pistol grip
	  Support  where the left hand holds the gun
	  MagWell  where the left hand goes to swap magazines

	Every visible part carries a `Group` attribute the viewmodel animates as a unit:
	  Body (default), Mag (drops out on reload), Slide (cycles on fire / bolt), Flash (muzzle flash)
]]

export type Built = {
	model: Model,
	root: BasePart,
	parts: { BasePart },
}

local M = Enum.Material
local rad = math.rad

-- Palette
local BLACK = Color3.fromRGB(28, 29, 31)
local GUNMETAL = Color3.fromRGB(46, 48, 50)
local PARKERIZED = Color3.fromRGB(58, 60, 58)
local POLYMER = Color3.fromRGB(34, 35, 36)
local FDE = Color3.fromRGB(150, 128, 96) -- flat dark earth furniture
local WOOD = Color3.fromRGB(112, 58, 30)
local WOOD_DARK = Color3.fromRGB(82, 42, 22)
local BAKELITE = Color3.fromRGB(104, 44, 26)
local STEEL = Color3.fromRGB(150, 152, 155)
local STEEL_DARK = Color3.fromRGB(98, 100, 103)
local RUBBER = Color3.fromRGB(22, 22, 23)
local GLASS = Color3.fromRGB(150, 190, 205)
local DOT = Color3.fromRGB(255, 40, 30)
local FLASH = Color3.fromRGB(255, 200, 120)

local Builder = {}
Builder.__index = Builder

local function newBuilder(name: string)
	local self = setmetatable({}, Builder)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.Massless = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	self.model = model
	self.root = root
	self.parts = {}
	return self
end

function Builder:_add(part: BasePart, name: string, cframe: CFrame, color: Color3, material: Enum.Material, group: string?)
	part.Name = name
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Group", group or "Body")
	part.Parent = self.model
	table.insert(self.parts, part)
	return part
end

-- Box at `pos`, optionally rotated by `rot` (degrees, applied X then Y then Z).
function Builder:box(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material, group: string?, rot: Vector3?)
	local part = Instance.new("Part")
	part.Size = size
	local cf = CFrame.new(pos)
	if rot then
		cf *= CFrame.Angles(rad(rot.X), rad(rot.Y), rad(rot.Z))
	end
	return self:_add(part, name, cf, color, material, group)
end

-- Cylinder lying along Z (the bore axis) unless `axis` is "Y" or "X".
function Builder:cyl(name: string, length: number, diameter: number, pos: Vector3, color: Color3, material: Enum.Material, group: string?, axis: string?)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, diameter, diameter)
	local cf = CFrame.new(pos)
	if axis == "Y" then
		cf *= CFrame.Angles(0, 0, rad(90))
	elseif axis ~= "X" then
		cf *= CFrame.Angles(0, rad(90), 0)
	end
	return self:_add(part, name, cf, color, material, group)
end

function Builder:wedge(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material, rot: Vector3?, group: string?)
	local part = Instance.new("WedgePart")
	part.Size = size
	local cf = CFrame.new(pos)
	if rot then
		cf *= CFrame.Angles(rad(rot.X), rad(rot.Y), rad(rot.Z))
	end
	return self:_add(part, name, cf, color, material, group)
end

function Builder:attach(name: string, pos: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = pos
	attachment.Parent = self.root
	return attachment
end

-- Picatinny rail: a flat bar with cross slots.
function Builder:rail(name: string, length: number, pos: Vector3, color: Color3, teeth: number)
	self:box(name, Vector3.new(0.11, 0.025, length), pos, color, M.Metal)
	local step = length / teeth
	for i = 1, teeth do
		local z = pos.Z - length / 2 + step * (i - 0.5)
		self:box(name .. " tooth", Vector3.new(0.12, 0.022, step * 0.55), Vector3.new(pos.X, pos.Y + 0.022, z), color, M.Metal)
	end
end

-- Compact red dot: base, hood, tinted glass and an emissive dot at the aim point.
function Builder:redDot(aim: Vector3, color: Color3)
	local y, z = aim.Y, aim.Z
	self:box("Optic base", Vector3.new(0.11, 0.05, 0.2), Vector3.new(0, y - 0.085, z), color, M.Metal)
	self:box("Optic hood L", Vector3.new(0.022, 0.13, 0.16), Vector3.new(-0.06, y, z), color, M.Metal)
	self:box("Optic hood R", Vector3.new(0.022, 0.13, 0.16), Vector3.new(0.06, y, z), color, M.Metal)
	self:box("Optic hood top", Vector3.new(0.142, 0.022, 0.16), Vector3.new(0, y + 0.072, z), color, M.Metal)
	self:box("Optic knob", Vector3.new(0.03, 0.045, 0.045), Vector3.new(0.08, y - 0.02, z + 0.02), color, M.Metal)
	local glass = self:box("Optic glass", Vector3.new(0.1, 0.12, 0.006), Vector3.new(0, y, z - 0.07), GLASS, M.Glass)
	glass.Transparency = 0.82
	glass.Reflectance = 0.15
	local dot = Instance.new("Part")
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.new(0.012, 0.012, 0.012)
	self:_add(dot, "Optic dot", CFrame.new(0, y, z - 0.064), DOT, M.Neon)
end

-- Muzzle flash petals: hidden until the viewmodel shows them for a frame or two.
function Builder:flash(muzzle: Vector3, scale: number)
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(0.14, 0.14, 0.14) * scale
	self:_add(core, "Flash core", CFrame.new(muzzle + Vector3.new(0, 0, -0.04 * scale)), FLASH, M.Neon, "Flash")
	for i = 0, 3 do
		local petal = Instance.new("Part")
		petal.Size = Vector3.new(0.025, 0.025, 0.22) * scale
		local cf = CFrame.new(muzzle) * CFrame.Angles(0, 0, rad(45 * i)) * CFrame.Angles(rad(22), 0, 0)
			* CFrame.new(0, 0, -0.1 * scale)
		self:_add(petal, "Flash petal", cf, FLASH, M.Neon, "Flash")
	end
	local cone = Instance.new("Part")
	cone.Size = Vector3.new(0.05, 0.05, 0.34) * scale
	self:_add(cone, "Flash cone", CFrame.new(muzzle + Vector3.new(0, 0, -0.17 * scale)), FLASH, M.Neon, "Flash")
	for _, part in self.parts do
		if part:GetAttribute("Group") == "Flash" then
			part.Transparency = 1
		end
	end
end

-- Builders ------------------------------------------------------------------------------------

local builders: { [string]: (any) -> () } = {}

-- AR-pattern carbine: flat-top upper, free-float handguard, red dot, collapsible stock.
builders.AR = function(b)
	b:box("Upper receiver", Vector3.new(0.15, 0.13, 0.6), Vector3.new(0, 0, 0), GUNMETAL, M.Metal)
	b:rail("Upper rail", 0.58, Vector3.new(0, 0.078, 0), BLACK, 9)
	b:box("Lower receiver", Vector3.new(0.135, 0.13, 0.48), Vector3.new(0, -0.125, 0.04), GUNMETAL, M.Metal)
	b:box("Magwell", Vector3.new(0.15, 0.13, 0.19), Vector3.new(0, -0.22, -0.11), GUNMETAL, M.Metal)
	b:box("Ejection cover", Vector3.new(0.006, 0.055, 0.15), Vector3.new(0.077, -0.005, -0.02), PARKERIZED, M.Metal)
	b:cyl("Forward assist", 0.07, 0.04, Vector3.new(0.08, 0.025, 0.14), PARKERIZED, M.Metal)
	b:box("Charging handle", Vector3.new(0.1, 0.025, 0.07), Vector3.new(0, 0.06, 0.33), BLACK, M.Metal, "Slide")
	b:box("Dust shroud", Vector3.new(0.02, 0.04, 0.06), Vector3.new(0.068, 0.02, 0.27), BLACK, M.Metal)
	b:box("Trigger guard", Vector3.new(0.03, 0.02, 0.17), Vector3.new(0, -0.235, 0.09), BLACK, M.Metal)
	b:box("Trigger", Vector3.new(0.02, 0.06, 0.02), Vector3.new(0, -0.2, 0.07), STEEL_DARK, M.Metal, nil, Vector3.new(-10, 0, 0))
	b:box("Selector", Vector3.new(0.012, 0.025, 0.06), Vector3.new(0.072, -0.11, 0.16), STEEL_DARK, M.Metal)
	b:box("Pistol grip", Vector3.new(0.105, 0.27, 0.13), Vector3.new(0, -0.3, 0.21), POLYMER, M.Plastic, nil, Vector3.new(-18, 0, 0))
	b:box("Grip backstrap", Vector3.new(0.09, 0.22, 0.03), Vector3.new(0, -0.3, 0.29), POLYMER, M.Plastic, nil, Vector3.new(-18, 0, 0))
	-- Curved 30-round magazine
	b:box("Magazine", Vector3.new(0.11, 0.2, 0.17), Vector3.new(0, -0.37, -0.115), FDE, M.Plastic, "Mag")
	b:box("Magazine lower", Vector3.new(0.11, 0.2, 0.17), Vector3.new(0, -0.55, -0.15), FDE, M.Plastic, "Mag", Vector3.new(14, 0, 0))
	b:box("Magazine base", Vector3.new(0.13, 0.035, 0.19), Vector3.new(0, -0.66, -0.18), FDE, M.Plastic, "Mag", Vector3.new(14, 0, 0))
	for i = 0, 2 do
		b:box("Magazine rib", Vector3.new(0.115, 0.015, 0.012), Vector3.new(0, -0.33 - i * 0.06, -0.205), FDE, M.Plastic, "Mag")
	end
	-- Stock
	b:cyl("Buffer tube", 0.36, 0.085, Vector3.new(0, -0.01, 0.48), BLACK, M.Metal)
	b:box("Stock", Vector3.new(0.115, 0.17, 0.3), Vector3.new(0, -0.04, 0.62), POLYMER, M.Plastic)
	b:wedge("Stock cheek", Vector3.new(0.11, 0.06, 0.26), Vector3.new(0, 0.07, 0.63), POLYMER, M.Plastic, Vector3.new(0, 180, 0))
	b:box("Butt pad", Vector3.new(0.125, 0.24, 0.045), Vector3.new(0, -0.06, 0.79), RUBBER, M.Rubber)
	-- Free-float handguard with M-LOK slots and a top rail
	b:box("Handguard", Vector3.new(0.165, 0.155, 0.64), Vector3.new(0, -0.005, -0.62), BLACK, M.Metal)
	b:rail("Handguard rail", 0.62, Vector3.new(0, 0.085, -0.62), BLACK, 10)
	for i = 0, 3 do
		local z = -0.42 - i * 0.14
		b:box("Slot L", Vector3.new(0.006, 0.03, 0.08), Vector3.new(-0.083, -0.01, z), Color3.fromRGB(12, 12, 13), M.SmoothPlastic)
		b:box("Slot R", Vector3.new(0.006, 0.03, 0.08), Vector3.new(0.083, -0.01, z), Color3.fromRGB(12, 12, 13), M.SmoothPlastic)
	end
	b:cyl("Vertical grip", 0.2, 0.07, Vector3.new(0, -0.18, -0.72), POLYMER, M.Plastic, nil, "Y")
	b:box("Flip sight rear", Vector3.new(0.08, 0.04, 0.05), Vector3.new(0, 0.115, 0.24), BLACK, M.Metal)
	b:box("Flip sight front", Vector3.new(0.06, 0.04, 0.05), Vector3.new(0, 0.115, -0.9), BLACK, M.Metal)
	-- Barrel
	b:cyl("Barrel", 0.38, 0.055, Vector3.new(0, 0, -1.12), PARKERIZED, M.Metal)
	b:cyl("Flash hider", 0.13, 0.08, Vector3.new(0, 0, -1.36), BLACK, M.Metal)
	b:cyl("Flash hider tip", 0.02, 0.085, Vector3.new(0, 0, -1.425), PARKERIZED, M.Metal)
	b:redDot(Vector3.new(0, 0.195, -0.04), BLACK)

	b:attach("Muzzle", Vector3.new(0, 0, -1.44))
	b:attach("Aim", Vector3.new(0, 0.195, -0.04))
	b:attach("Eject", Vector3.new(0.09, 0, -0.02))
	b:attach("Grip", Vector3.new(0, -0.27, 0.2))
	b:attach("Support", Vector3.new(0, -0.15, -0.72))
	b:attach("MagWell", Vector3.new(0, -0.3, -0.12))
	b:flash(Vector3.new(0, 0, -1.44), 1)
end

-- AK-pattern rifle: stamped receiver, wood furniture, curved steel magazine, iron sights.
builders.AK = function(b)
	b:box("Receiver", Vector3.new(0.145, 0.15, 0.74), Vector3.new(0, -0.025, 0), GUNMETAL, M.Metal)
	b:cyl("Dust cover", 0.66, 0.14, Vector3.new(0, 0.045, 0.05), GUNMETAL, M.Metal)
	b:box("Rear trunnion", Vector3.new(0.15, 0.06, 0.08), Vector3.new(0, 0.01, 0.38), GUNMETAL, M.Metal)
	b:box("Selector lever", Vector3.new(0.008, 0.035, 0.32), Vector3.new(0.077, 0.0, 0.08), STEEL_DARK, M.Metal)
	b:box("Charging handle", Vector3.new(0.07, 0.03, 0.045), Vector3.new(0.1, 0.015, 0.16), STEEL_DARK, M.Metal, "Slide")
	b:box("Bolt carrier", Vector3.new(0.01, 0.04, 0.3), Vector3.new(0.074, 0.02, 0.05), STEEL_DARK, M.Metal, "Slide")
	b:box("Trigger guard", Vector3.new(0.03, 0.02, 0.2), Vector3.new(0, -0.2, 0.13), STEEL_DARK, M.Metal)
	b:box("Trigger", Vector3.new(0.02, 0.06, 0.02), Vector3.new(0, -0.165, 0.11), STEEL_DARK, M.Metal, nil, Vector3.new(-10, 0, 0))
	b:box("Pistol grip", Vector3.new(0.1, 0.25, 0.13), Vector3.new(0, -0.26, 0.27), BAKELITE, M.Plastic, nil, Vector3.new(-20, 0, 0))
	-- Rear sight leaf and notch
	b:box("Rear sight base", Vector3.new(0.08, 0.05, 0.12), Vector3.new(0, 0.1, -0.36), GUNMETAL, M.Metal)
	b:box("Rear sight leaf", Vector3.new(0.07, 0.012, 0.16), Vector3.new(0, 0.128, -0.33), STEEL_DARK, M.Metal)
	b:box("Rear notch L", Vector3.new(0.022, 0.025, 0.012), Vector3.new(-0.024, 0.146, -0.255), STEEL_DARK, M.Metal)
	b:box("Rear notch R", Vector3.new(0.022, 0.025, 0.012), Vector3.new(0.024, 0.146, -0.255), STEEL_DARK, M.Metal)
	-- Wood furniture
	b:cyl("Upper handguard", 0.42, 0.1, Vector3.new(0, 0.09, -0.62), WOOD_DARK, M.Wood)
	b:box("Lower handguard", Vector3.new(0.15, 0.14, 0.44), Vector3.new(0, -0.04, -0.64), WOOD, M.Wood)
	b:box("Handguard retainer", Vector3.new(0.155, 0.16, 0.03), Vector3.new(0, -0.03, -0.87), STEEL_DARK, M.Metal)
	b:box("Stock", Vector3.new(0.115, 0.18, 0.58), Vector3.new(0, -0.07, 0.66), WOOD, M.Wood, nil, Vector3.new(6, 0, 0))
	b:wedge("Stock comb", Vector3.new(0.11, 0.08, 0.5), Vector3.new(0, 0.05, 0.68), WOOD, M.Wood, Vector3.new(6, 180, 0))
	b:box("Butt plate", Vector3.new(0.12, 0.27, 0.035), Vector3.new(0, -0.1, 0.96), STEEL_DARK, M.Metal, nil, Vector3.new(6, 0, 0))
	-- Gas system, barrel, front sight
	b:cyl("Gas tube", 0.42, 0.06, Vector3.new(0, 0.09, -0.64), GUNMETAL, M.Metal)
	b:box("Gas block", Vector3.new(0.07, 0.13, 0.07), Vector3.new(0, 0.05, -0.92), GUNMETAL, M.Metal)
	b:cyl("Barrel", 0.5, 0.055, Vector3.new(0, 0, -1.1), PARKERIZED, M.Metal)
	b:box("Front sight block", Vector3.new(0.06, 0.07, 0.07), Vector3.new(0, 0.035, -1.28), GUNMETAL, M.Metal)
	b:box("Front sight post", Vector3.new(0.012, 0.075, 0.012), Vector3.new(0, 0.108, -1.28), STEEL_DARK, M.Metal)
	b:box("Front sight ear L", Vector3.new(0.012, 0.07, 0.03), Vector3.new(-0.032, 0.105, -1.28), GUNMETAL, M.Metal)
	b:box("Front sight ear R", Vector3.new(0.012, 0.07, 0.03), Vector3.new(0.032, 0.105, -1.28), GUNMETAL, M.Metal)
	b:cyl("Muzzle brake", 0.11, 0.075, Vector3.new(0, 0, -1.38), GUNMETAL, M.Metal)
	-- Curved steel magazine
	b:box("Magazine", Vector3.new(0.1, 0.19, 0.19), Vector3.new(0, -0.18, -0.2), GUNMETAL, M.Metal, "Mag")
	b:box("Magazine mid", Vector3.new(0.1, 0.19, 0.18), Vector3.new(0, -0.35, -0.25), GUNMETAL, M.Metal, "Mag", Vector3.new(16, 0, 0))
	b:box("Magazine lower", Vector3.new(0.1, 0.18, 0.17), Vector3.new(0, -0.51, -0.34), GUNMETAL, M.Metal, "Mag", Vector3.new(30, 0, 0))
	b:box("Magazine base", Vector3.new(0.115, 0.03, 0.18), Vector3.new(0, -0.6, -0.4), GUNMETAL, M.Metal, "Mag", Vector3.new(30, 0, 0))

	b:attach("Muzzle", Vector3.new(0, 0, -1.44))
	-- Aim point sits just behind the rear notch, on the line to the front post tip.
	b:attach("Aim", Vector3.new(0, 0.146, -0.24))
	b:attach("Eject", Vector3.new(0.09, 0.03, -0.06))
	b:attach("Grip", Vector3.new(0, -0.24, 0.26))
	b:attach("Support", Vector3.new(0, -0.1, -0.62))
	b:attach("MagWell", Vector3.new(0, -0.24, -0.22))
	b:flash(Vector3.new(0, 0, -1.44), 1.15)
end

-- Compact 4.6mm PDW: polymer body, magazine in the grip, folding foregrip, wire stock.
builders.PDW = function(b)
	b:box("Upper", Vector3.new(0.14, 0.14, 0.5), Vector3.new(0, 0, 0), POLYMER, M.Plastic)
	b:rail("Top rail", 0.46, Vector3.new(0, 0.08, 0.0), BLACK, 7)
	b:box("Lower", Vector3.new(0.13, 0.12, 0.42), Vector3.new(0, -0.12, -0.02), POLYMER, M.Plastic)
	b:box("Barrel shroud", Vector3.new(0.11, 0.11, 0.2), Vector3.new(0, -0.01, -0.34), POLYMER, M.Plastic)
	b:cyl("Barrel", 0.14, 0.05, Vector3.new(0, 0, -0.5), PARKERIZED, M.Metal)
	b:cyl("Muzzle device", 0.06, 0.065, Vector3.new(0, 0, -0.58), BLACK, M.Metal)
	b:box("Charging handle", Vector3.new(0.12, 0.02, 0.04), Vector3.new(0, 0.05, 0.24), BLACK, M.Metal, "Slide")
	b:box("Ejection port", Vector3.new(0.006, 0.04, 0.1), Vector3.new(0.071, 0.01, -0.04), Color3.fromRGB(12, 12, 13), M.SmoothPlastic)
	b:box("Trigger guard", Vector3.new(0.03, 0.02, 0.15), Vector3.new(0, -0.21, -0.03), POLYMER, M.Plastic)
	b:box("Grip", Vector3.new(0.105, 0.3, 0.13), Vector3.new(0, -0.3, 0.09), POLYMER, M.Plastic, nil, Vector3.new(-8, 0, 0))
	b:box("Grip texture L", Vector3.new(0.006, 0.18, 0.09), Vector3.new(-0.054, -0.3, 0.09), RUBBER, M.Rubber, nil, Vector3.new(-8, 0, 0))
	b:box("Grip texture R", Vector3.new(0.006, 0.18, 0.09), Vector3.new(0.054, -0.3, 0.09), RUBBER, M.Rubber, nil, Vector3.new(-8, 0, 0))
	b:box("Magazine", Vector3.new(0.085, 0.22, 0.1), Vector3.new(0, -0.43, 0.105), BLACK, M.Plastic, "Mag", Vector3.new(-8, 0, 0))
	b:box("Magazine base", Vector3.new(0.11, 0.03, 0.14), Vector3.new(0, -0.55, 0.125), BLACK, M.Plastic, "Mag", Vector3.new(-8, 0, 0))
	b:box("Foregrip", Vector3.new(0.06, 0.18, 0.06), Vector3.new(0, -0.2, -0.3), POLYMER, M.Plastic, nil, Vector3.new(10, 0, 0))
	b:cyl("Stock rod L", 0.32, 0.025, Vector3.new(-0.05, -0.03, 0.4), BLACK, M.Metal)
	b:cyl("Stock rod R", 0.32, 0.025, Vector3.new(0.05, -0.03, 0.4), BLACK, M.Metal)
	b:box("Butt plate", Vector3.new(0.14, 0.17, 0.04), Vector3.new(0, -0.04, 0.57), POLYMER, M.Plastic)
	b:redDot(Vector3.new(0, 0.19, -0.02), BLACK)

	b:attach("Muzzle", Vector3.new(0, 0, -0.62))
	b:attach("Aim", Vector3.new(0, 0.19, -0.02))
	b:attach("Eject", Vector3.new(0.08, 0.01, -0.04))
	b:attach("Grip", Vector3.new(0, -0.27, 0.09))
	b:attach("Support", Vector3.new(0, -0.2, -0.3))
	b:attach("MagWell", Vector3.new(0, -0.5, 0.11))
	b:flash(Vector3.new(0, 0, -0.62), 0.85)
end

-- .50-caliber hand cannon: big stainless slide, triangular barrel, two-hand hold.
builders.HandCannon = function(b)
	b:box("Barrel top", Vector3.new(0.085, 0.06, 0.6), Vector3.new(0, 0.08, -0.12), STEEL, M.Metal)
	b:box("Barrel rib", Vector3.new(0.03, 0.02, 0.56), Vector3.new(0, 0.12, -0.12), STEEL_DARK, M.Metal)
	b:box("Slide", Vector3.new(0.1, 0.1, 0.5), Vector3.new(0, 0.005, -0.06), STEEL, M.Metal, "Slide")
	for i = 0, 4 do
		b:box("Serration L", Vector3.new(0.004, 0.07, 0.012), Vector3.new(-0.051, 0.005, 0.1 + i * 0.025), STEEL_DARK, M.Metal, "Slide")
		b:box("Serration R", Vector3.new(0.004, 0.07, 0.012), Vector3.new(0.051, 0.005, 0.1 + i * 0.025), STEEL_DARK, M.Metal, "Slide")
	end
	b:box("Ejection port", Vector3.new(0.004, 0.04, 0.1), Vector3.new(0.051, 0.025, -0.06), Color3.fromRGB(20, 20, 20), M.SmoothPlastic, "Slide")
	b:box("Frame", Vector3.new(0.095, 0.06, 0.44), Vector3.new(0, -0.075, -0.13), STEEL_DARK, M.Metal)
	b:box("Dust cover", Vector3.new(0.09, 0.05, 0.16), Vector3.new(0, -0.09, -0.3), STEEL_DARK, M.Metal)
	b:box("Guard front", Vector3.new(0.03, 0.1, 0.025), Vector3.new(0, -0.15, -0.22), STEEL_DARK, M.Metal)
	b:box("Guard bottom", Vector3.new(0.03, 0.02, 0.15), Vector3.new(0, -0.2, -0.15), STEEL_DARK, M.Metal)
	b:box("Trigger", Vector3.new(0.02, 0.06, 0.02), Vector3.new(0, -0.14, -0.1), STEEL_DARK, M.Metal, nil, Vector3.new(-10, 0, 0))
	b:box("Hammer", Vector3.new(0.03, 0.06, 0.03), Vector3.new(0, 0.03, 0.22), STEEL_DARK, M.Metal, "Slide")
	b:box("Grip", Vector3.new(0.105, 0.33, 0.16), Vector3.new(0, -0.26, 0.08), RUBBER, M.Rubber, nil, Vector3.new(-15, 0, 0))
	b:box("Grip strap", Vector3.new(0.085, 0.3, 0.02), Vector3.new(0, -0.25, 0.17), STEEL_DARK, M.Metal, nil, Vector3.new(-15, 0, 0))
	b:box("Magazine", Vector3.new(0.07, 0.3, 0.11), Vector3.new(0, -0.27, 0.07), STEEL_DARK, M.Metal, "Mag", Vector3.new(-15, 0, 0))
	b:box("Magazine base", Vector3.new(0.1, 0.035, 0.16), Vector3.new(0, -0.43, 0.115), RUBBER, M.Rubber, "Mag", Vector3.new(-15, 0, 0))
	-- Sights
	b:box("Rear sight L", Vector3.new(0.022, 0.03, 0.02), Vector3.new(-0.022, 0.135, 0.16), BLACK, M.Metal)
	b:box("Rear sight R", Vector3.new(0.022, 0.03, 0.02), Vector3.new(0.022, 0.135, 0.16), BLACK, M.Metal)
	b:box("Front sight", Vector3.new(0.012, 0.035, 0.015), Vector3.new(0, 0.1335, -0.39), BLACK, M.Metal)

	b:attach("Muzzle", Vector3.new(0, 0.08, -0.43))
	b:attach("Aim", Vector3.new(0, 0.151, 0.17))
	b:attach("Eject", Vector3.new(0.06, 0.03, -0.06))
	b:attach("Grip", Vector3.new(0, -0.23, 0.07))
	b:attach("Support", Vector3.new(-0.05, -0.26, 0.04))
	b:attach("MagWell", Vector3.new(-0.04, -0.46, 0.13))
	b:flash(Vector3.new(0, 0.08, -0.43), 1.25)
end

local WeaponModels = {}

function WeaponModels.has(key: string): boolean
	return builders[key] ~= nil
end

function WeaponModels.build(key: string): Built
	local build = builders[key]
	assert(build, "Unknown weapon model " .. tostring(key))
	local b = newBuilder(key)
	build(b)
	return { model = b.model, root = b.root, parts = b.parts }
end

function WeaponModels.attachment(built: Built, name: string): Attachment
	local attachment = built.root:FindFirstChild(name)
	assert(attachment and attachment:IsA("Attachment"), "Weapon model missing attachment " .. name)
	return attachment
end

return table.freeze(WeaponModels)
