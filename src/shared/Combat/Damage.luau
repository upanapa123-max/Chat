--[[
	Pure damage rules. No Roblox services and no requires, so it runs both in Roblox and in the
	standalone Luau CLI (tests/run.luau). The server is the only caller that applies the result.

	Armor outcome against a protected zone:
	  penetration >= protection                 -> "Penetrated" (full damage; lethal zones kill)
	  lethal zone and penetration < protection  -> "Stopped"    (helmets stop or fail, never reduce)
	  penetration <  protection * STOP_FRACTION -> "Stopped"
	  otherwise                                 -> "Reduced"    (damage * REDUCED_SCALE)
	Unprotected zones report "None".
]]

local Damage = {}

Damage.STOP_FRACTION = 0.6
Damage.REDUCED_SCALE = 0.4

export type ArmorOutcome = "None" | "Penetrated" | "Reduced" | "Stopped"

export type Result = {
	damage: number,
	armor: ArmorOutcome,
	lethal: boolean,
	falloffScale: number,
}

-- Fraction of base damage kept at `distance` studs.
function Damage.falloffScale(ammo, distance: number): number
	local beyond = math.max(0, distance - ammo.effectiveRange)
	return math.max(ammo.minDamageScale, 1 - beyond * ammo.falloffPerStud)
end

--[[
	ammo        AmmoDef (Data/Ammo)
	zone        "Head" | "Torso" | "Arms" | "Legs"
	distance    studs from shot origin to hit
	protection  armor protection on that zone, 0 when unarmored
	health      target's current health (damage is capped to it)
	zones       Data/Zones table
]]
function Damage.resolve(ammo, zone: string, distance: number, protection: number, health: number, zones): Result
	local falloff = Damage.falloffScale(ammo, distance)
	local armor: ArmorOutcome = "None"
	local armorScale = 1

	if protection > 0 then
		if ammo.penetration >= protection then
			armor = "Penetrated"
		elseif zones.lethal[zone] or ammo.penetration < protection * Damage.STOP_FRACTION then
			return { damage = 0, armor = "Stopped", lethal = false, falloffScale = falloff }
		else
			armor = "Reduced"
			armorScale = Damage.REDUCED_SCALE
		end
	end

	if zones.lethal[zone] then
		return { damage = health, armor = armor, lethal = true, falloffScale = falloff }
	end

	local zoneScale = zones.damageScale[zone] or 0
	local raw = math.floor(ammo.damage * falloff * armorScale * zoneScale + 0.5)
	local damage = math.min(health, raw)
	return { damage = damage, armor = armor, lethal = damage >= health, falloffScale = falloff }
end

return table.freeze(Damage)
