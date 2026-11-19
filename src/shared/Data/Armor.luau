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
	MidHelmet = { id = "MidHelmet", displayName = "Ballistic helmet", slot = "Head", protection = 50 },
	HeavyHelmet = { id = "HeavyHelmet", displayName = "Heavy helmet + visor", slot = "Head", protection = 65 },
	SoftVest = { id = "SoftVest", displayName = "Soft vest", slot = "Torso", protection = 55 },
	PlateCarrier = { id = "PlateCarrier", displayName = "Plate carrier", slot = "Torso", protection = 70 },
	HeavyPlates = { id = "HeavyPlates", displayName = "Heavy assault armor", slot = "Torso", protection = 85 },
}

-- Order the range console cycles through for each slot ("" = none). Light to heavy.
local cycle = {
	Head = { "", "LightHelmet", "MidHelmet", "HeavyHelmet" },
	Torso = { "", "SoftVest", "PlateCarrier", "HeavyPlates" },
}

for _, def in definitions do
	table.freeze(def)
end

for _, list in cycle do
	table.freeze(list)
end

return table.freeze({
	definitions = table.freeze(definitions),
	cycle = table.freeze(cycle),
	slotAttribute = table.freeze({ Head = "Helmet", Torso = "BodyArmor" }),
})
