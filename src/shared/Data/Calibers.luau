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
	["7.62x39"] = {
		id = "7.62x39",
		displayName = "7.62×39mm",
		ammo = { "762_PS", "762_BP", "762_HP" },
	},
	[".50AE"] = {
		id = ".50AE",
		displayName = ".50 AE",
		ammo = { "50AE_FMJ", "50AE_CS", "50AE_JHP" },
	},
	["4.6x30"] = {
		id = "4.6x30",
		displayName = "4.6×30mm",
		ammo = { "46_FMJ", "46_AP", "46_SUB" },
	},
}

for _, def in Calibers do
	table.freeze(def.ammo)
	table.freeze(def)
end

return table.freeze(Calibers)
