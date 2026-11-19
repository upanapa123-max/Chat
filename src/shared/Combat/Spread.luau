--[[
	Shot spread: picks a direction uniformly inside a cone around `aim`.
	Called by the server only; the client never decides where a bullet goes.
]]

local Spread = {}

function Spread.apply(aim: Vector3, halfAngleDegrees: number, rng: Random): Vector3
	local radius = math.tan(math.rad(halfAngleDegrees))
	local angle = rng:NextNumber(0, 2 * math.pi)
	local offset = radius * math.sqrt(rng:NextNumber())
	local basis = CFrame.lookAlong(Vector3.zero, aim)
	return (
		basis.LookVector
		+ basis.RightVector * (math.cos(angle) * offset)
		+ basis.UpVector * (math.sin(angle) * offset)
	).Unit
end

return table.freeze(Spread)
