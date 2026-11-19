--[[
	Visible armor, built from parts around a body part. Shared by the range dummies (server,
	hittable) and the operator look on player characters (server, cosmetic).

	ArmorModels.build(armorId, anchor, options) places the pieces for one Data/Armor id around
	`anchor` (a head part for helmets, a chest/upper-torso part for body armor), sized from the
	anchor's Size, facing the anchor's -Z (the way Roblox characters face).

	options
	  parent    where the parts go
	  hittable  true for range dummies: parts get CanQuery and a `Zone` attribute (Head/Torso), so
	            a hit on the armor counts as a hit on the zone it covers. false for players.
	  anchored  true for anchored dummies; false welds every piece to the anchor.

	Every part carries a `BaseTransparency` attribute so TargetService can fade and restore it.
]]

export type Options = {
	parent: Instance,
	hittable: boolean,
	anchored: boolean,
}

local rad = math.rad

local OLIVE = Color3.fromRGB(84, 88, 64)
local OLIVE_DARK = Color3.fromRGB(58, 62, 46)
local COYOTE = Color3.fromRGB(138, 116, 84)
local RANGER = Color3.fromRGB(70, 76, 62)
local BLACK = Color3.fromRGB(26, 26, 26)
local STEEL = Color3.fromRGB(72, 76, 74)
local VISOR = Color3.fromRGB(70, 86, 92)

local ArmorModels = {}

type Ctx = { anchor: BasePart, options: Options, zone: string, parts: { BasePart } }

local function piece(ctx: Ctx, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, kind: string?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	if kind == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif kind == "Ball" then
		part.Shape = Enum.PartType.Ball
	end
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = ctx.options.hittable
	part.Massless = true
	part.CFrame = ctx.anchor.CFrame * offset
	if kind == "Dome" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	if ctx.options.hittable then
		part:SetAttribute("Zone", ctx.zone)
	end
	part:SetAttribute("ArmorPiece", true)
	part:SetAttribute("BaseTransparency", 0)
	if ctx.options.anchored then
		part.Anchored = true
	else
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ctx.anchor
		weld.Part1 = part
		weld.Parent = part
	end
	part.Parent = ctx.options.parent
	table.insert(ctx.parts, part)
	return part
end

local function transparent(part: BasePart, value: number)
	part.Transparency = value
	part:SetAttribute("BaseTransparency", value)
end

local builders: { [string]: (Ctx) -> () } = {}

-- Helmets (anchor = head) ---------------------------------------------------------------------

builders.LightHelmet = function(ctx)
	local s = ctx.anchor.Size
	piece(ctx, "Helmet shell", Vector3.new(s.X * 1.3, s.Y * 0.9, s.Z * 1.36), CFrame.new(0, s.Y * 0.2, s.Z * 0.04), COYOTE, Enum.Material.Fabric, "Dome")
	piece(ctx, "Helmet band", Vector3.new(s.X * 1.24, s.Y * 0.12, s.Z * 1.28), CFrame.new(0, s.Y * 0.04, s.Z * 0.04), OLIVE_DARK, Enum.Material.Fabric)
	piece(ctx, "Chin strap", Vector3.new(s.X * 1.04, s.Y * 0.05, s.Z * 0.12), CFrame.new(0, -s.Y * 0.42, -s.Z * 0.1) * CFrame.Angles(rad(-20), 0, 0), BLACK, Enum.Material.Fabric)
end

builders.MidHelmet = function(ctx)
	local s = ctx.anchor.Size
	piece(ctx, "Helmet shell", Vector3.new(s.X * 1.26, s.Y * 0.82, s.Z * 1.3), CFrame.new(0, s.Y * 0.26, s.Z * 0.02), RANGER, Enum.Material.Plastic, "Dome")
	piece(ctx, "Rail L", Vector3.new(s.X * 0.07, s.Y * 0.15, s.Z * 0.75), CFrame.new(-s.X * 0.6, s.Y * 0.16, 0), BLACK, Enum.Material.Plastic)
	piece(ctx, "Rail R", Vector3.new(s.X * 0.07, s.Y * 0.15, s.Z * 0.75), CFrame.new(s.X * 0.6, s.Y * 0.16, 0), BLACK, Enum.Material.Plastic)
	piece(ctx, "NVG shroud", Vector3.new(s.X * 0.3, s.Y * 0.2, s.Z * 0.1), CFrame.new(0, s.Y * 0.44, -s.Z * 0.66), BLACK, Enum.Material.Metal)
	piece(ctx, "Ear cup L", Vector3.new(s.X * 0.14, s.Y * 0.4, s.Y * 0.4), CFrame.new(-s.X * 0.56, -s.Y * 0.06, s.Z * 0.02), OLIVE_DARK, Enum.Material.Plastic, "Cylinder")
	piece(ctx, "Ear cup R", Vector3.new(s.X * 0.14, s.Y * 0.4, s.Y * 0.4), CFrame.new(s.X * 0.56, -s.Y * 0.06, s.Z * 0.02), OLIVE_DARK, Enum.Material.Plastic, "Cylinder")
	piece(ctx, "Velcro patch", Vector3.new(s.X * 0.45, s.Y * 0.18, s.Z * 0.06), CFrame.new(0, s.Y * 0.5, s.Z * 0.5) * CFrame.Angles(rad(30), 0, 0), COYOTE, Enum.Material.Fabric)
end

builders.HeavyHelmet = function(ctx)
	local s = ctx.anchor.Size
	piece(ctx, "Helmet shell", Vector3.new(s.X * 1.38, s.Y * 1.0, s.Z * 1.42), CFrame.new(0, s.Y * 0.18, s.Z * 0.05), STEEL, Enum.Material.Metal, "Dome")
	piece(ctx, "Helmet skirt", Vector3.new(s.X * 1.34, s.Y * 0.3, s.Z * 1.3), CFrame.new(0, -s.Y * 0.08, s.Z * 0.12), STEEL, Enum.Material.Metal)
	local visor = piece(ctx, "Visor", Vector3.new(s.X * 1.12, s.Y * 0.72, s.Z * 0.1), CFrame.new(0, -s.Y * 0.02, -s.Z * 0.66), VISOR, Enum.Material.Glass)
	transparent(visor, 0.35)
	visor.Reflectance = 0.2
	piece(ctx, "Visor frame", Vector3.new(s.X * 1.16, s.Y * 0.08, s.Z * 0.14), CFrame.new(0, s.Y * 0.36, -s.Z * 0.64), BLACK, Enum.Material.Metal)
	piece(ctx, "Hinge L", Vector3.new(s.X * 0.1, s.Y * 0.22, s.Y * 0.22), CFrame.new(-s.X * 0.66, s.Y * 0.18, -s.Z * 0.4), BLACK, Enum.Material.Metal, "Cylinder")
	piece(ctx, "Hinge R", Vector3.new(s.X * 0.1, s.Y * 0.22, s.Y * 0.22), CFrame.new(s.X * 0.66, s.Y * 0.18, -s.Z * 0.4), BLACK, Enum.Material.Metal, "Cylinder")
	piece(ctx, "Aventail", Vector3.new(s.X * 1.1, s.Y * 0.45, s.Z * 0.18), CFrame.new(0, -s.Y * 0.38, s.Z * 0.6), OLIVE_DARK, Enum.Material.Fabric)
end

-- Body armor (anchor = chest / upper torso) ----------------------------------------------------

local function carrier(ctx: Ctx, color: Color3, plateThickness: number, pouches: boolean)
	local s = ctx.anchor.Size
	local h = s.Y * 0.92
	piece(ctx, "Front panel", Vector3.new(s.X * 0.86, h, plateThickness), CFrame.new(0, s.Y * 0.02, -s.Z / 2 - plateThickness / 2 + 0.02), color, Enum.Material.Fabric)
	piece(ctx, "Back panel", Vector3.new(s.X * 0.86, h, plateThickness), CFrame.new(0, s.Y * 0.02, s.Z / 2 + plateThickness / 2 - 0.02), color, Enum.Material.Fabric)
	piece(ctx, "Side L", Vector3.new(0.16, h * 0.62, s.Z + plateThickness), CFrame.new(-s.X * 0.45, -h * 0.14, 0), OLIVE_DARK, Enum.Material.Fabric)
	piece(ctx, "Side R", Vector3.new(0.16, h * 0.62, s.Z + plateThickness), CFrame.new(s.X * 0.45, -h * 0.14, 0), OLIVE_DARK, Enum.Material.Fabric)
	piece(ctx, "Strap L", Vector3.new(s.X * 0.18, 0.12, s.Z + plateThickness * 2), CFrame.new(-s.X * 0.27, s.Y * 0.02 + h / 2, 0), OLIVE_DARK, Enum.Material.Fabric)
	piece(ctx, "Strap R", Vector3.new(s.X * 0.18, 0.12, s.Z + plateThickness * 2), CFrame.new(s.X * 0.27, s.Y * 0.02 + h / 2, 0), OLIVE_DARK, Enum.Material.Fabric)
	if pouches then
		local z = -s.Z / 2 - plateThickness - 0.11
		for i = -1, 1 do
			piece(ctx, "Mag pouch", Vector3.new(s.X * 0.22, h * 0.36, 0.24), CFrame.new(i * s.X * 0.25, -h * 0.25, z), OLIVE_DARK, Enum.Material.Fabric)
			piece(ctx, "Mag", Vector3.new(s.X * 0.15, h * 0.12, 0.15), CFrame.new(i * s.X * 0.25, -h * 0.02, z), BLACK, Enum.Material.Plastic)
		end
		piece(ctx, "Admin pouch", Vector3.new(s.X * 0.42, h * 0.22, 0.14), CFrame.new(0, h * 0.24, -s.Z / 2 - plateThickness - 0.06), color, Enum.Material.Fabric)
	end
end

builders.SoftVest = function(ctx)
	local s = ctx.anchor.Size
	carrier(ctx, OLIVE, 0.16, false)
	piece(ctx, "Collar", Vector3.new(s.X * 0.6, 0.14, s.Z * 0.9), CFrame.new(0, s.Y * 0.5, 0), OLIVE_DARK, Enum.Material.Fabric)
end

builders.PlateCarrier = function(ctx)
	carrier(ctx, COYOTE, 0.32, true)
end

builders.HeavyPlates = function(ctx)
	local s = ctx.anchor.Size
	carrier(ctx, Color3.fromRGB(46, 48, 44), 0.44, true)
	piece(ctx, "Neck collar", Vector3.new(s.X * 0.72, 0.32, s.Z * 1.25), CFrame.new(0, s.Y * 0.55, 0), Color3.fromRGB(40, 42, 38), Enum.Material.Fabric)
	piece(ctx, "Shoulder L", Vector3.new(s.X * 0.32, 0.22, s.Z * 1.2), CFrame.new(-s.X * 0.62, s.Y * 0.42, 0) * CFrame.Angles(0, 0, rad(25)), Color3.fromRGB(40, 42, 38), Enum.Material.Fabric)
	piece(ctx, "Shoulder R", Vector3.new(s.X * 0.32, 0.22, s.Z * 1.2), CFrame.new(s.X * 0.62, s.Y * 0.42, 0) * CFrame.Angles(0, 0, rad(-25)), Color3.fromRGB(40, 42, 38), Enum.Material.Fabric)
	piece(ctx, "Groin flap", Vector3.new(s.X * 0.42, s.Y * 0.4, 0.2), CFrame.new(0, -s.Y * 0.62, -s.Z / 2 - 0.25), Color3.fromRGB(40, 42, 38), Enum.Material.Fabric)
	piece(ctx, "Plate edge", Vector3.new(s.X * 0.8, 0.06, 0.06), CFrame.new(0, s.Y * 0.46, -s.Z / 2 - 0.44), STEEL, Enum.Material.Metal)
end

function ArmorModels.has(armorId: string): boolean
	return builders[armorId] ~= nil
end

function ArmorModels.build(armorId: string, anchor: BasePart, zone: string, options: Options): { BasePart }
	local build = builders[armorId]
	local ctx: Ctx = { anchor = anchor, options = options, zone = zone, parts = {} }
	if build then
		build(ctx)
	end
	return ctx.parts
end

return table.freeze(ArmorModels)
