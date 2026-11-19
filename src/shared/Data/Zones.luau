--[[
	Hit zones. Every hittable target part carries a `Zone` attribute with one of these names.

	damageScale  Multiplier applied to ammunition damage.
	armorSlot    Which armor slot protects the zone (zones not listed are never armored).
	lethal       A hit that is unprotected or penetrates armor kills outright.
	             Armor on a lethal zone never "reduces" — it either stops the round or fails.
]]

return table.freeze({
	damageScale = table.freeze({ Head = 1, Torso = 1, Arms = 0.65, Legs = 0.55 }),
	armorSlot = table.freeze({ Head = "Head", Torso = "Torso" }),
	lethal = table.freeze({ Head = true }),
})
