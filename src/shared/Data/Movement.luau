--[[
	Stances and movement modes. All movement tuning lives here.

	The client requests a stance plus aim / sprint intent. The server validates the stance change
	(transition time, headroom), derives the movement mode from it, and owns WalkSpeed, HipHeight,
	the body pose and the shot origin. Client and server use the same pure helpers below, so the
	client's prediction matches what the server decides.

	Heights:
	  hipScale   HipHeight as a fraction of the character's standing HipHeight (R15)
	  eyeScale   Eye (camera / shot origin) height above the ground, as a fraction of standing
	Scaling from the standing values keeps every avatar size proportional.
]]

local Movement = {}

Movement.stance = table.freeze({
	Stand = table.freeze({ level = 3, hipScale = 1, eyeScale = 1, canJump = true }),
	Crouch = table.freeze({ level = 2, hipScale = 0.5, eyeScale = 0.68, canJump = false }),
	Prone = table.freeze({ level = 1, hipScale = 0.15, eyeScale = 0.2, canJump = false }),
})

Movement.speed = table.freeze({
	Walk = 14,
	Sprint = 21,
	Aim = 10,
	Crouch = 8,
	CrouchAim = 6,
	Prone = 3,
	ProneAim = 2,
})

-- WalkSpeed cap while a stance change is in progress (getting down or up).
Movement.transitionSpeed = 4

-- Seconds to change stance. Getting down is quicker than getting up; prone is the slowest.
local TRANSITION_TIME = table.freeze({
	Stand = table.freeze({ Crouch = 0.22, Prone = 0.6 }),
	Crouch = table.freeze({ Stand = 0.26, Prone = 0.5 }),
	Prone = table.freeze({ Crouch = 0.5, Stand = 0.75 }),
})

-- Height of the body's centreline above the ground when lying prone, studs.
Movement.proneBodyHeight = 0.6
-- Space above the eye that must be clear before the server lets you rise into a stance, studs.
Movement.headClearance = 0.55

function Movement.isStance(value: unknown): boolean
	return type(value) == "string" and Movement.stance[value] ~= nil
end

function Movement.transitionTime(from: string, to: string): number
	if from == to then
		return 0
	end
	return TRANSITION_TIME[from][to]
end

-- Rising needs headroom; getting lower never does.
function Movement.isRising(from: string, to: string): boolean
	return Movement.stance[to].level > Movement.stance[from].level
end

-- No shooting while dropping into or getting up from prone (hands are on the ground).
function Movement.blocksFire(from: string, to: string): boolean
	return from ~= to and (from == "Prone" or to == "Prone")
end

function Movement.hipHeight(stance: string, standHip: number): number
	return standHip * Movement.stance[stance].hipScale
end

function Movement.eyeHeight(stance: string, standEye: number): number
	return standEye * Movement.stance[stance].eyeScale
end

function Movement.isAiming(mode: string): boolean
	return mode == "Aim" or mode == "CrouchAim" or mode == "ProneAim"
end

-- Sprint only counts while standing; aiming beats sprint.
function Movement.modeFor(stance: string, aiming: boolean, sprinting: boolean): string
	if stance == "Prone" then
		return if aiming then "ProneAim" else "Prone"
	elseif stance == "Crouch" then
		return if aiming then "CrouchAim" else "Crouch"
	elseif aiming then
		return "Aim"
	elseif sprinting then
		return "Sprint"
	end
	return "Walk"
end

--[[
	Crouch leg pose. Returns the thigh's forward swing and the shin's backward swing (radians,
	both measured from vertical) that shorten a straight leg by `drop` while the foot stays
	directly under the hip:
	    thigh*cos(a) + shin*cos(b) = thigh + shin - drop      thigh*sin(a) = shin*sin(b)
]]
function Movement.legAngles(thigh: number, shin: number, drop: number): (number, number)
	local reach = thigh + shin
	local height = math.clamp(reach - drop, reach * 0.25, reach)
	local cosThigh = (thigh * thigh + height * height - shin * shin) / (2 * thigh * height)
	local cosShin = (shin * shin + height * height - thigh * thigh) / (2 * shin * height)
	return math.acos(math.clamp(cosThigh, -1, 1)), math.acos(math.clamp(cosShin, -1, 1))
end

return table.freeze(Movement)
