--[[
	Range targets: identifying hits, reading worn armor, applying damage, resetting, and showing
	the worn armor as visible gear.

	A target is a Model directly inside Workspace.LastShiftRange.Targets with attributes
	  Health      number
	  MaxHealth   number (optional; defaults to the starting Health)
	  Helmet      armor id or ""   (see Data/Armor.slotAttribute)
	  BodyArmor   armor id or ""
	  Kind        optional: "Steel" for aim-trainer plates (clang instead of flesh)
	  ResetDelay  optional: seconds before a downed target stands back up (default 2.5)
	and hittable BasePart children carrying a `Zone` attribute (Data/Zones).

	Visible armor is rebuilt from Visual/ArmorModels whenever Helmet/BodyArmor change. Armor
	pieces carry the Zone they cover, so hitting a helmet counts as a head hit (and the helmet's
	protection applies). The head part anchors helmets; the part named "Chest" (or "Torso")
	anchors body armor.
	Players are not damageable in Milestone 001; PvP will add a second target kind here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local data = shared:WaitForChild("Data")
local Armor = require(data:WaitForChild("Armor"))
local Zones = require(data:WaitForChild("Zones"))
local Damage = require(shared:WaitForChild("Combat"):WaitForChild("Damage"))
local ArmorModels = require(shared:WaitForChild("Visual"):WaitForChild("ArmorModels"))

local DEFAULT_RESET_DELAY = 2.5
local DOWNED_TRANSPARENCY = 0.8

local TargetService = {}

local targetsFolder: Instance? = nil
local warnedArmorIds: { [string]: boolean } = {}
local resetTokens: { [Model]: number } = {}

local function baseTransparency(part: BasePart): number
	local value = part:GetAttribute("BaseTransparency")
	return if typeof(value) == "number" then value else 0
end

local function setActive(model: Model, active: boolean)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.CanQuery = active
			part.Transparency = if active then baseTransparency(part) else math.max(DOWNED_TRANSPARENCY, baseTransparency(part))
		end
	end
end

local function armorFor(model: Model, zone: string): Armor.ArmorDef?
	local slot = Zones.armorSlot[zone]
	if not slot then
		return nil
	end
	local id = model:GetAttribute(Armor.slotAttribute[slot])
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	local def = Armor.definitions[id]
	if not def or def.slot ~= slot then
		if not warnedArmorIds[id] then
			warnedArmorIds[id] = true
			warn(("[LastShift] Target %s wears unknown or mis-slotted armor %q; treating as unarmored"):format(
				model.Name,
				id
			))
		end
		return nil
	end
	return def
end

local function anchorFor(model: Model, slot: string): BasePart?
	local names = if slot == "Head" then { "Head" } else { "Chest", "Torso" }
	for _, name in names do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") and part:GetAttribute("ArmorPiece") == nil then
			return part
		end
	end
	return nil
end

-- Rebuilds the visible armor of one slot from the model's attribute.
local function dressSlot(model: Model, slot: string)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("ArmorSlot") == slot then
			child:Destroy()
		end
	end
	local id = model:GetAttribute(Armor.slotAttribute[slot])
	local anchor = anchorFor(model, slot)
	if typeof(id) ~= "string" or id == "" or not anchor or not ArmorModels.has(id) then
		return
	end
	local down = (model:GetAttribute("Health") :: number? or 1) <= 0
	for _, part in ArmorModels.build(id, anchor, slot, { parent = model, hittable = true, anchored = true }) do
		part:SetAttribute("ArmorSlot", slot)
		if down then
			part.CanQuery = false
			part.Transparency = math.max(DOWNED_TRANSPARENCY, baseTransparency(part))
		end
	end
end

local function track(model: Model)
	if typeof(model:GetAttribute("MaxHealth")) ~= "number" then
		model:SetAttribute("MaxHealth", model:GetAttribute("Health"))
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("BaseTransparency") == nil then
			part:SetAttribute("BaseTransparency", part.Transparency)
		end
	end
	for slot, attribute in Armor.slotAttribute do
		dressSlot(model, slot)
		model:GetAttributeChangedSignal(attribute):Connect(function()
			dressSlot(model, slot)
		end)
	end
end

function TargetService.init()
	local folder = Workspace:WaitForChild("LastShiftRange"):WaitForChild("Targets")
	targetsFolder = folder
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and typeof(model:GetAttribute("Health")) == "number" then
			track(model)
		end
	end
end

function TargetService.targets(): { Model }
	local list = {}
	if targetsFolder then
		for _, model in targetsFolder:GetChildren() do
			if model:IsA("Model") and typeof(model:GetAttribute("Health")) == "number" then
				table.insert(list, model)
			end
		end
	end
	return list
end

-- Returns the target model and zone for a raycast hit, or nil if it is not a live target.
function TargetService.fromInstance(instance: Instance): (Model?, string?)
	local model = instance.Parent
	if not model or model.Parent ~= targetsFolder or not model:IsA("Model") then
		return nil, nil
	end
	local zone = instance:GetAttribute("Zone")
	if typeof(zone) ~= "string" or Zones.damageScale[zone] == nil then
		return nil, nil
	end
	local health = model:GetAttribute("Health")
	if typeof(health) ~= "number" or health <= 0 then
		return nil, nil
	end
	return model, zone
end

-- Which impact effect a hit on this target shows: "Armor" (spark/clang), or "Flesh".
function TargetService.impactKind(model: Model, report): string
	if model:GetAttribute("Kind") == "Steel" or report.armor == "Stopped" then
		return "Armor"
	end
	return "Flesh"
end

local function revive(model: Model)
	resetTokens[model] = (resetTokens[model] or 0) + 1
	model:SetAttribute("Health", model:GetAttribute("MaxHealth"))
	setActive(model, true)
end

-- Applies one hit and returns the fields ShotResult reports for a target hit.
function TargetService.applyHit(model: Model, zone: string, ammo, distance: number)
	local health = model:GetAttribute("Health") :: number
	local maxHealth = (model:GetAttribute("MaxHealth") :: number?) or health
	local armorDef = armorFor(model, zone)
	local protection = if armorDef then armorDef.protection else 0

	local result = Damage.resolve(ammo, zone, distance, protection, health, Zones)
	local remaining = health - result.damage
	model:SetAttribute("Health", remaining)

	if remaining <= 0 then
		setActive(model, false)
		local token = (resetTokens[model] or 0) + 1
		resetTokens[model] = token
		local delay = model:GetAttribute("ResetDelay")
		task.delay(if typeof(delay) == "number" then delay else DEFAULT_RESET_DELAY, function()
			if model.Parent and resetTokens[model] == token then
				revive(model)
			end
		end)
	end

	return {
		targetName = model.Name,
		zone = zone,
		damage = result.damage,
		armor = result.armor,
		armorName = if armorDef then armorDef.displayName else "None",
		protection = protection,
		penetration = ammo.penetration,
		falloffScale = result.falloffScale,
		lethal = result.lethal,
		health = remaining,
		maxHealth = maxHealth,
	}
end

-- Range console: stand every target back up at full health.
function TargetService.resetAll()
	for _, model in TargetService.targets() do
		revive(model)
	end
end

-- Range console: next armor in Data/Armor.cycle for one slot of one target. Returns the new id.
function TargetService.cycleArmor(model: Model, slot: string): string?
	local attribute = Armor.slotAttribute[slot]
	local order = Armor.cycle[slot]
	if not attribute or not order or model.Parent ~= targetsFolder then
		return nil
	end
	local current = model:GetAttribute(attribute)
	local index = table.find(order, if typeof(current) == "string" then current else "") or 1
	local nextId = order[index % #order + 1]
	model:SetAttribute(attribute, nextId)
	revive(model)
	return nextId
end

return TargetService
