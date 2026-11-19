-- Desktop keyboard + mouse bindings. Gamepad/touch come in a later milestone.
return table.freeze({
	fire = Enum.UserInputType.MouseButton1,
	aim = Enum.UserInputType.MouseButton2, -- hold
	sprint = Enum.KeyCode.LeftShift, -- hold
	crouch = Enum.KeyCode.C, -- toggle (from prone: crouch)
	prone = Enum.KeyCode.X, -- toggle (from prone: stand)
	-- Space (Roblox's jump) while crouched / prone gets up one stance.
	reload = Enum.KeyCode.R,
	nextWeapon = Enum.KeyCode.Q, -- mouse wheel also cycles weapons
	fireMode = Enum.KeyCode.B, -- semi / auto on weapons that have both
	-- Index into the equipped weapon's caliber ammo list (Data/Calibers).
	ammoSlots = table.freeze({
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
	}),
})
