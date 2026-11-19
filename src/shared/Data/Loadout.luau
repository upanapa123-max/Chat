-- What every player spawns with in the shooting range. Q / mouse wheel cycle through `weapons`.
-- The server only lets a player equip weapons listed here.
return table.freeze({
	startingWeapon = "RangeRifle",
	weapons = table.freeze({ "RangeRifle", "KR47", "PDW46", "HC50" }),
})
