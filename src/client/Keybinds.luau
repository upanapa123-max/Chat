-- Desktop keyboard + mouse bindings. Gamepad/touch come in a later milestone.
return table.freeze({
	fire = Enum.UserInputType.MouseButton1,
	aim = Enum.UserInputType.MouseButton2, -- hold
	sprint = Enum.KeyCode.LeftShift, -- hold
	crouch = Enum.KeyCode.C, -- toggle
	reload = Enum.KeyCode.R,
	-- Index into the equipped weapon's caliber ammo list (Data/Calibers).
	ammoSlots = table.freeze({
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
	}),
})
