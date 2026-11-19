--[[
	Range target dummies: identifying hits, reading worn armor, applying damage, resetting.

	A target is a Model directly inside Workspace.LastShiftRange.Targets with attributes
	  Health      number
	  MaxHealth   number (optional; defaults to the starting Health)
	  Helmet      armor id or ""   (see Data/Armor.slotAttribute)
	  BodyArmor   armor id or ""
	and hittable BasePart children carrying a `Zone` attribute (Data/Zones).
	Players are not damageable in Milestone 001; PvP will add a second target kind here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local data = shared:WaitForChild("Data")
local Armor = require(data:WaitForChild("Armor"))
local Zones = require(data:WaitForChild("Zones"))
local Damage = require(shared:WaitForChild("Combat"):WaitForChild("Damage"))

local RESET_DELAY = 2.5
local DOWNED_TRANSPARENCY = 0.8

local TargetService = {}

local targetsFolder: Instance? = nil
local baseTransparency: { [BasePart]: number } = {}
local warnedArmorIds: { [string]: boolean } = {}

local function setActive(model: Model, active: boolean)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.CanQuery = active
			part.Transparency = if active then (baseTransparency[part] or 0) else DOWNED_TRANSPARENCY
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

function TargetService.init()
	local folder = Workspace:WaitForChild("LastShiftRange"):WaitForChild("Targets")
	targetsFolder = folder
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and typeof(model:GetAttribute("Health")) == "number" then
			if typeof(model:GetAttribute("MaxHealth")) ~= "number" then
				model:SetAttribute("MaxHealth", model:GetAttribute("Health"))
			end
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					baseTransparency[part] = part.Transparency
				end
			end
		end
	end
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
		task.delay(RESET_DELAY, function()
			if model.Parent then
				model:SetAttribute("Health", maxHealth)
				setActive(model, true)
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

return TargetService
