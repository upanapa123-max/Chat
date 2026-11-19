--[[
	Movement modes. The client requests a mode; the server validates it and owns WalkSpeed.
	The server also uses the mode for weapon rules (no firing while sprinting, ADS spread).
]]

local Movement = {}

Movement.speed = table.freeze({
	Walk = 14,
	Sprint = 21,
	Crouch = 8,
	Aim = 10,
	CrouchAim = 7,
})

-- Camera drop while crouched, studs. Also lowers the server's shot origin.
Movement.crouchCameraOffset = -0.85

function Movement.isAiming(mode: string): boolean
	return mode == "Aim" or mode == "CrouchAim"
end

function Movement.isCrouched(mode: string): boolean
	return mode == "Crouch" or mode == "CrouchAim"
end

-- Crouch beats sprint; aiming beats sprint.
function Movement.modeFor(crouched: boolean, aiming: boolean, sprinting: boolean): string
	if crouched then
		return if aiming then "CrouchAim" else "Crouch"
	elseif aiming then
		return "Aim"
	elseif sprinting then
		return "Sprint"
	end
	return "Walk"
end

return table.freeze(Movement)
