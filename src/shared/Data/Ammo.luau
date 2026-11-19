--[[
	Ammunition definitions.

	Values are fictional prototype balance parameters, not real-world ballistics.
	To add a round: add an entry here, then list its id in its caliber (Calibers.luau).
	No weapon code needs to change.

	Fields
	  caliber         Caliber id this round belongs to (Calibers.luau).
	  shortName       Label used on the HUD and keybind hints.
	  damage          Flesh damage at or inside effectiveRange, before zone scaling.
	  penetration     Compared against armor protection (same 0–100 scale as Armor.luau).
	  effectiveRange  Studs of full damage.
	  falloffPerStud  Damage scale lost per stud beyond effectiveRange.
	  minDamageScale  Falloff never drops damage below this fraction.

	Reserved for later milestones (read by nothing yet):
	  muzzleVelocity  studs/s, for projectile travel time and drop.
	  armorDamage     durability removed from armor per hit.
]]

export type AmmoDef = {
	id: string,
	caliber: string,
	shortName: string,
	displayName: string,
	damage: number,
	penetration: number,
	effectiveRange: number,
	falloffPerStud: number,
	minDamageScale: number,
	muzzleVelocity: number?,
	armorDamage: number?,
}

local Ammo: { [string]: AmmoDef } = {
	["556_FMJ"] = {
		id = "556_FMJ",
		caliber = "5.56x45",
		shortName = "FMJ",
		displayName = "5.56 FMJ",
		damage = 36,
		penetration = 45,
		effectiveRange = 90,
		falloffPerStud = 0.006,
		minDamageScale = 0.4,
	},
	["556_AP"] = {
		id = "556_AP",
		caliber = "5.56x45",
		shortName = "AP",
		displayName = "5.56 AP",
		damage = 31,
		penetration = 75,
		effectiveRange = 120,
		falloffPerStud = 0.004,
		minDamageScale = 0.5,
	},
	["556_HP"] = {
		id = "556_HP",
		caliber = "5.56x45",
		shortName = "HP",
		displayName = "5.56 HP",
		damage = 52,
		penetration = 20,
		effectiveRange = 65,
		falloffPerStud = 0.008,
		minDamageScale = 0.35,
	},
	-- 7.62x39 (AK-pattern rifle): heavier, slower round. Hits harder, falls off sooner.
	["762_PS"] = {
		id = "762_PS",
		caliber = "7.62x39",
		shortName = "PS",
		displayName = "7.62 PS",
		damage = 47,
		penetration = 50,
		effectiveRange = 80,
		falloffPerStud = 0.007,
		minDamageScale = 0.4,
	},
	["762_BP"] = {
		id = "762_BP",
		caliber = "7.62x39",
		shortName = "BP",
		displayName = "7.62 BP (AP)",
		damage = 41,
		penetration = 72,
		effectiveRange = 95,
		falloffPerStud = 0.005,
		minDamageScale = 0.45,
	},
	["762_HP"] = {
		id = "762_HP",
		caliber = "7.62x39",
		shortName = "HP",
		displayName = "7.62 HP",
		damage = 60,
		penetration = 22,
		effectiveRange = 55,
		falloffPerStud = 0.009,
		minDamageScale = 0.35,
	},

	-- .50 AE (hand cannon): huge flesh damage, short effective range, weak against plates.
	["50AE_FMJ"] = {
		id = "50AE_FMJ",
		caliber = ".50AE",
		shortName = "FMJ",
		displayName = ".50 AE FMJ",
		damage = 64,
		penetration = 40,
		effectiveRange = 40,
		falloffPerStud = 0.011,
		minDamageScale = 0.35,
	},
	["50AE_CS"] = {
		id = "50AE_CS",
		caliber = ".50AE",
		shortName = "CS",
		displayName = ".50 AE Copper Solid",
		damage = 56,
		penetration = 56,
		effectiveRange = 45,
		falloffPerStud = 0.01,
		minDamageScale = 0.4,
	},
	["50AE_JHP"] = {
		id = "50AE_JHP",
		caliber = ".50AE",
		shortName = "JHP",
		displayName = ".50 AE JHP",
		damage = 78,
		penetration = 24,
		effectiveRange = 32,
		falloffPerStud = 0.013,
		minDamageScale = 0.3,
	},

	-- 4.6x30 (compact PDW): light damage per hit, but the AP load is built to defeat soft armor.
	["46_FMJ"] = {
		id = "46_FMJ",
		caliber = "4.6x30",
		shortName = "FMJ",
		displayName = "4.6 FMJ",
		damage = 27,
		penetration = 40,
		effectiveRange = 55,
		falloffPerStud = 0.008,
		minDamageScale = 0.4,
	},
	["46_AP"] = {
		id = "46_AP",
		caliber = "4.6x30",
		shortName = "AP",
		displayName = "4.6 AP",
		damage = 24,
		penetration = 66,
		effectiveRange = 60,
		falloffPerStud = 0.007,
		minDamageScale = 0.45,
	},
	["46_SUB"] = {
		id = "46_SUB",
		caliber = "4.6x30",
		shortName = "SUB",
		displayName = "4.6 Subsonic HP",
		damage = 35,
		penetration = 16,
		effectiveRange = 40,
		falloffPerStud = 0.01,
		minDamageScale = 0.35,
	},
}

for _, def in Ammo do
	table.freeze(def)
end

return table.freeze(Ammo)
