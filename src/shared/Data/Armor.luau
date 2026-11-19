--[[
	Armor definitions.

	Targets wear armor by id through attributes on their Model:
	  Helmet     = "<armor id>" or ""   (protects the Head zone)
	  BodyArmor  = "<armor id>" or ""   (protects the Torso zone)
	The attribute for each slot is listed in `slotAttribute` below.

	`protection` uses the same 0–100 scale as ammunition `penetration`.
	Reserved for later milestones: durability, coverage, armor class.
]]

export type ArmorSlot = "Head" | "Torso"

export type ArmorDef = {
	id: string,
	displayName: string,
	slot: ArmorSlot,
	protection: number,
}

local definitions: { [string]: ArmorDef } = {
	LightHelmet = { id = "LightHelmet", displayName = "Light helmet", slot = "Head", protection = 35 },
	HeavyHelmet = { id = "HeavyHelmet", displayName = "Heavy helmet", slot = "Head", protection = 65 },
	SoftVest = { id = "SoftVest", displayName = "Soft vest", slot = "Torso", protection = 55 },
	PlateCarrier = { id = "PlateCarrier", displayName = "Plate carrier", slot = "Torso", protection = 70 },
}

for _, def in definitions do
	table.freeze(def)
end

return table.freeze({
	definitions = table.freeze(definitions),
	slotAttribute = table.freeze({ Head = "Helmet", Torso = "BodyArmor" }),
})
