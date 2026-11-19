--[[
	Stance geometry used by both the client's prediction and the server's authority:
	standing eye height, the eye position (camera and shot origin) and headroom checks.

	Roblox's first-person camera sits CAMERA_HEAD_OFFSET above the HumanoidRootPart (plus
	Humanoid.CameraOffset). With the root floating HipHeight above the ground on R15:
	    eye above ground (no CameraOffset) = legs + root half-height + CAMERA_HEAD_OFFSET
	R6 doesn't float on HipHeight; its legs are a fixed 2 studs, so stances only move its camera.
]]

local Workspace = game:GetService("Workspace")

local Movement = require(script.Parent:WaitForChild("Data"):WaitForChild("Movement"))

local CAMERA_HEAD_OFFSET = 1.5
local R6_LEG_HEIGHT = 2
local HEADROOM_RADIUS = 0.45

local Stance = {}

function Stance.usesHipHeight(humanoid: Humanoid): boolean
	return humanoid.RigType == Enum.HumanoidRigType.R15
end

local function rootAboveGround(humanoid: Humanoid, root: BasePart, hip: number): number
	local legs = if Stance.usesHipHeight(humanoid) then hip else R6_LEG_HEIGHT
	return legs + root.Size.Y / 2
end

-- Where Roblox's camera currently sits above the ground, before CameraOffset.
function Stance.cameraBaseline(humanoid: Humanoid, root: BasePart): number
	return rootAboveGround(humanoid, root, humanoid.HipHeight) + CAMERA_HEAD_OFFSET
end

function Stance.standEye(humanoid: Humanoid, root: BasePart, standHip: number): number
	return rootAboveGround(humanoid, root, standHip) + CAMERA_HEAD_OFFSET
end

function Stance.eyeHeight(humanoid: Humanoid, root: BasePart, stance: string, standHip: number): number
	return Movement.eyeHeight(stance, Stance.standEye(humanoid, root, standHip))
end

-- Ground height under the root, assuming the humanoid is standing on something at its HipHeight.
function Stance.groundY(humanoid: Humanoid, root: BasePart): number
	return root.Position.Y - rootAboveGround(humanoid, root, humanoid.HipHeight)
end

-- World position of the eye for a stance. The server fires from here; the client's camera
-- converges on the same point.
function Stance.eyePosition(humanoid: Humanoid, root: BasePart, stance: string, standHip: number): Vector3
	local position = root.Position
	local eye = Stance.eyeHeight(humanoid, root, stance, standHip)
	return Vector3.new(position.X, Stance.groundY(humanoid, root) + eye, position.Z)
end

-- True when there is room above the character to rise into `stance`.
function Stance.hasHeadroom(character: Model, humanoid: Humanoid, root: BasePart, stance: string, standHip: number): boolean
	local ground = Stance.groundY(humanoid, root)
	local top = ground + Stance.eyeHeight(humanoid, root, stance, standHip) + Movement.headClearance
	local startY = ground + HEADROOM_RADIUS + 0.2
	local travel = top - HEADROOM_RADIUS - startY
	if travel <= 0 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local start = Vector3.new(root.Position.X, startY, root.Position.Z)
	return Workspace:Spherecast(start, HEADROOM_RADIUS, Vector3.new(0, travel, 0), params) == nil
end

return table.freeze(Stance)
