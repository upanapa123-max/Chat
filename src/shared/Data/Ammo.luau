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
}

for _, def in Ammo do
	table.freeze(def)
end

return table.freeze(Ammo)
