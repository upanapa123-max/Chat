--[[
	Calibers group the ammunition a weapon can load.

	`ammo` is ordered: it sets the 1/2/3 ammo-select keys and the HUD hint order.
	A new weapon of an existing caliber automatically accepts every round listed here.
]]

export type CaliberDef = {
	id: string,
	displayName: string,
	ammo: { string },
}

local Calibers: { [string]: CaliberDef } = {
	["5.56x45"] = {
		id = "5.56x45",
		displayName = "5.56×45mm",
		ammo = { "556_FMJ", "556_AP", "556_HP" },
	},
}

for _, def in Calibers do
	table.freeze(def.ammo)
	table.freeze(def)
end

return table.freeze(Calibers)
