--[[
	Engine-free tests for data integrity and damage rules.
	Run from the project folder (build.bat does this):
	    tools-local\luau\luau.exe tests\run.luau
	Exits with an error on the first failing group; prints a summary otherwise.
]]

local Ammo = require("../src/shared/Data/Ammo")
local Calibers = require("../src/shared/Data/Calibers")
local Weapons = require("../src/shared/Data/Weapons")
local Armor = require("../src/shared/Data/Armor")
local Zones = require("../src/shared/Data/Zones")
local Movement = require("../src/shared/Data/Movement")
local Loadout = require("../src/shared/Data/Loadout")
local Damage = require("../src/shared/Combat/Damage")

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (if detail then "  (" .. detail .. ")" else ""))
	end
end

-- Data integrity --------------------------------------------------------------

for id, def in Ammo do
	check("ammo id matches key " .. id, def.id == id)
	check("ammo caliber exists " .. id, Calibers[def.caliber] ~= nil)
	check("ammo minDamageScale in 0..1 " .. id, def.minDamageScale > 0 and def.minDamageScale <= 1)
end

for id, caliber in Calibers do
	check("caliber id matches key " .. id, caliber.id == id)
	for _, ammoId in caliber.ammo do
		local def = Ammo[ammoId]
		check("caliber ammo exists " .. ammoId, def ~= nil)
		check("caliber ammo belongs to caliber " .. ammoId, def ~= nil and def.caliber == id)
	end
end

for id, weapon in Weapons do
	check("weapon id matches key " .. id, weapon.id == id)
	local caliber = Calibers[weapon.caliber]
	check("weapon caliber exists " .. id, caliber ~= nil)
	check("weapon default ammo fits caliber " .. id, caliber ~= nil and table.find(caliber.ammo, weapon.defaultAmmo) ~= nil)
	check("weapon ads tighter than hip " .. id, weapon.spread.ads < weapon.spread.hip)
end
check("starting weapon exists", Weapons[Loadout.startingWeapon] ~= nil)

for id, def in Armor.definitions do
	check("armor id matches key " .. id, def.id == id)
	check("armor slot has attribute " .. id, Armor.slotAttribute[def.slot] ~= nil)
end

for zone, slot in Zones.armorSlot do
	check("armored zone has damage scale " .. zone, Zones.damageScale[zone] ~= nil)
	check("zone slot has attribute " .. zone, Armor.slotAttribute[slot] ~= nil)
end

for mode in Movement.speed do
	check("movement speed positive " .. mode, Movement.speed[mode] > 0)
end
check("mode walk", Movement.modeFor(false, false, false) == "Walk")
check("mode sprint", Movement.modeFor(false, false, true) == "Sprint")
check("mode aim beats sprint", Movement.modeFor(false, true, true) == "Aim")
check("mode crouch beats sprint", Movement.modeFor(true, false, true) == "Crouch")
check("mode crouch aim", Movement.modeFor(true, true, false) == "CrouchAim")

-- Damage rules ----------------------------------------------------------------

local FMJ, AP, HP = Ammo["556_FMJ"], Ammo["556_AP"], Ammo["556_HP"]
local defs = Armor.definitions
local function protection(id: string?): number
	return if id then defs[id].protection else 0
end

-- { name, ammo, zone, distance, armor id or nil, health, expected damage, expected outcome, expected lethal }
local cases = {
	{ "unarmored head FMJ is lethal", FMJ, "Head", 20, nil, 100, 100, "None", true },
	{ "headshot kills at any health", HP, "Head", 20, nil, 37, 37, "None", true },
	{ "light helmet vs FMJ penetrates, lethal", FMJ, "Head", 20, "LightHelmet", 100, 100, "Penetrated", true },
	{ "light helmet stops HP", HP, "Head", 20, "LightHelmet", 100, 0, "Stopped", false },
	{ "heavy helmet stops FMJ", FMJ, "Head", 20, "HeavyHelmet", 100, 0, "Stopped", false },
	{ "heavy helmet fails vs AP, lethal", AP, "Head", 20, "HeavyHelmet", 100, 100, "Penetrated", true },
	{ "unarmored torso FMJ", FMJ, "Torso", 20, nil, 100, 36, "None", false },
	{ "unarmored torso HP", HP, "Torso", 20, nil, 100, 52, "None", false },
	{ "soft vest reduces FMJ", FMJ, "Torso", 20, "SoftVest", 100, 14, "Reduced", false },
	{ "soft vest stops HP", HP, "Torso", 20, "SoftVest", 100, 0, "Stopped", false },
	{ "soft vest fails vs AP", AP, "Torso", 20, "SoftVest", 100, 31, "Penetrated", false },
	{ "plate reduces FMJ", FMJ, "Torso", 20, "PlateCarrier", 100, 14, "Reduced", false },
	{ "plate fails vs AP", AP, "Torso", 20, "PlateCarrier", 100, 31, "Penetrated", false },
	{ "plate stops HP", HP, "Torso", 20, "PlateCarrier", 100, 0, "Stopped", false },
	{ "arm FMJ", FMJ, "Arms", 20, nil, 100, 23, "None", false },
	{ "leg FMJ", FMJ, "Legs", 20, nil, 100, 20, "None", false },
	{ "FMJ falloff at 190 studs hits floor", FMJ, "Torso", 190, nil, 100, 14, "None", false },
	{ "FMJ falloff at 140 studs", FMJ, "Torso", 140, nil, 100, 25, "None", false },
	{ "damage capped at health", HP, "Torso", 20, nil, 30, 30, "None", true },
}

for _, case in cases do
	local name, ammo, zone, distance, armorId, health, damage, outcome, lethal = table.unpack(case, 1, 9)
	local result = Damage.resolve(ammo, zone, distance, protection(armorId), health, Zones)
	local detail = ("got %d %s lethal=%s"):format(result.damage, result.armor, tostring(result.lethal))
	check(name, result.damage == damage and result.armor == outcome and result.lethal == lethal, detail)
end

check("no falloff inside effective range", Damage.falloffScale(FMJ, FMJ.effectiveRange) == 1)
check("falloff never below floor", Damage.falloffScale(AP, 100000) == AP.minDamageScale)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("tests failed")
end
