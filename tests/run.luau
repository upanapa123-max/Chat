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
for slot, list in Armor.cycle do
	check("armor cycle starts with none " .. slot, list[1] == "")
	for i = 2, #list do
		local def = Armor.definitions[list[i]]
		check("armor cycle entry exists " .. list[i], def ~= nil and def.slot == slot)
	end
end
for _, weaponId in Loadout.weapons do
	check("loadout weapon exists " .. weaponId, Weapons[weaponId] ~= nil)
end
do
	local WeaponSounds = require("../src/shared/Data/WeaponSounds")
	for id, weapon in Weapons do
		check("weapon has sound set " .. id, WeaponSounds.weapons[weapon.sounds] ~= nil)
		check("weapon has fire modes " .. id, #weapon.fireModes >= 1)
	end
end

for zone, slot in Zones.armorSlot do
	check("armored zone has damage scale " .. zone, Zones.damageScale[zone] ~= nil)
	check("zone slot has attribute " .. zone, Armor.slotAttribute[slot] ~= nil)
end

for mode in Movement.speed do
	check("movement speed positive " .. mode, Movement.speed[mode] > 0)
end
check("mode walk", Movement.modeFor("Stand", false, false) == "Walk")
check("mode sprint", Movement.modeFor("Stand", false, true) == "Sprint")
check("mode aim beats sprint", Movement.modeFor("Stand", true, true) == "Aim")
check("mode crouch beats sprint", Movement.modeFor("Crouch", false, true) == "Crouch")
check("mode crouch aim", Movement.modeFor("Crouch", true, false) == "CrouchAim")
check("mode prone beats sprint", Movement.modeFor("Prone", false, true) == "Prone")
check("mode prone aim", Movement.modeFor("Prone", true, false) == "ProneAim")
check("prone aim counts as aiming", Movement.isAiming("ProneAim"))

-- Stances ---------------------------------------------------------------------

local stanceNames = {}
for name in Movement.stance do
	table.insert(stanceNames, name)
end
for _, stance in stanceNames do
	local def = Movement.stance[stance]
	check("stance is valid " .. stance, Movement.isStance(stance))
	check("stance modes have speeds " .. stance, Movement.speed[Movement.modeFor(stance, false, false)] ~= nil
		and Movement.speed[Movement.modeFor(stance, true, false)] ~= nil)
	check("stance scales in 0..1 " .. stance, def.hipScale > 0 and def.hipScale <= 1 and def.eyeScale > 0 and def.eyeScale <= 1)
	for _, other in stanceNames do
		if other ~= stance then
			check(("transition time %s->%s"):format(stance, other), Movement.transitionTime(stance, other) > 0)
			check(("rising is one-way %s->%s"):format(stance, other),
				Movement.isRising(stance, other) ~= Movement.isRising(other, stance))
		end
	end
end
check("not a stance", not Movement.isStance("Fly") and not Movement.isStance(nil) and not Movement.isStance(3))
check("stand is full height", Movement.stance.Stand.hipScale == 1 and Movement.stance.Stand.eyeScale == 1)
check("lower stances are lower", Movement.stance.Prone.eyeScale < Movement.stance.Crouch.eyeScale
	and Movement.stance.Crouch.eyeScale < 1)
check("lower stances are slower", Movement.speed.Prone < Movement.speed.Crouch and Movement.speed.Crouch < Movement.speed.Walk)
check("crouch to stand rises", Movement.isRising("Crouch", "Stand"))
check("prone transitions block fire", Movement.blocksFire("Stand", "Prone") and Movement.blocksFire("Prone", "Crouch"))
check("crouch transitions allow fire", not Movement.blocksFire("Stand", "Crouch") and not Movement.blocksFire("Crouch", "Stand"))
check("transition speed is a cap", Movement.transitionSpeed < Movement.speed.Walk)

-- Crouch leg pose: the leg shortens by `drop` and the foot stays under the hip.
local function close(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end
for _, case in { { 1, 1, 1 }, { 1.2, 0.9, 0.7 }, { 0.8, 1.1, 0.3 } } do
	local thigh, shin, drop = case[1], case[2], case[3]
	local a, b = Movement.legAngles(thigh, shin, drop)
	local name = ("leg angles %.1f/%.1f drop %.1f"):format(thigh, shin, drop)
	check(name .. " height", close(thigh * math.cos(a) + shin * math.cos(b), thigh + shin - drop))
	check(name .. " foot under hip", close(thigh * math.sin(a), shin * math.sin(b)))
end
local a0, b0 = Movement.legAngles(1, 1, 0)
check("leg angles straight at no drop", close(a0, 0) and close(b0, 0))

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
