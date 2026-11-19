--[[
	Server-side body poses for each stance (R15 rigs).

	Posing on the server is what makes the hitbox smaller: the parts the server raycasts against
	really are lower when crouched and flat when prone. Joint C0s are tweened over the stance's
	transition time and the change replicates to every client. Animations still play on top
	(they drive Motor6D.Transform, not C0).

	Crouch: hips drop by the HipHeight difference; thighs swing forward, shins back, feet stay flat
	        under the hips; slight forward lean.
	Prone:  the body pivots flat face-down at the waist and slides back so the head sits over the
	        root part (where the camera is); legs trail behind. While prone the body parts are
	        massless and don't collide with the world, so the lying body can't snag on the floor
	        or tip the character. The HumanoidRootPart keeps colliding as normal.

	Other rigs (R6) keep their standing pose; speed, camera and shot origin still follow stance.
]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local Movement = require(shared:WaitForChild("Data"):WaitForChild("Movement"))

local StancePose = {}

-- Prone body parts: no collision with the world.
StancePose.PRONE_GROUP = "LastShiftProneBody"
-- Server hitscan rays use this group so they still hit prone bodies (a ray in "Default" would
-- skip parts whose group doesn't collide with "Default").
StancePose.HITSCAN_GROUP = "LastShiftHitscan"

local CROUCH_LEAN = math.rad(14)
local PRONE_NECK_LIFT = math.rad(70)
local DEFAULT_HEAD_REACH = 2

local JOINTS = {
	root = { "LowerTorso", "Root" },
	waist = { "UpperTorso", "Waist" },
	neck = { "Head", "Neck" },
	leftHip = { "LeftUpperLeg", "LeftHip" },
	leftKnee = { "LeftLowerLeg", "LeftKnee" },
	leftAnkle = { "LeftFoot", "LeftAnkle" },
	rightHip = { "RightUpperLeg", "RightHip" },
	rightKnee = { "RightLowerLeg", "RightKnee" },
	rightAnkle = { "RightFoot", "RightAnkle" },
}
local LEGS = {
	{ "leftHip", "leftKnee", "leftAnkle" },
	{ "rightHip", "rightKnee", "rightAnkle" },
}

-- Weak keys: entries vanish with the character.
local restC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local activeTweens: { [Motor6D]: Tween } = setmetatable({}, { __mode = "k" }) :: any
local savedBody: { [BasePart]: { group: string, massless: boolean } } = setmetatable({}, { __mode = "k" }) :: any

local function findJoint(character: Model, spec: { string }): Motor6D?
	local part = character:FindFirstChild(spec[1])
	local joint = part and part:FindFirstChild(spec[2])
	if joint and joint:IsA("Motor6D") then
		return joint
	end
	return nil
end

-- The first time a joint is posed its C0 is still the rig's rest pose; remember it.
local function rest(joint: Motor6D): CFrame
	local c0 = restC0[joint]
	if not c0 then
		c0 = joint.C0
		restC0[joint] = c0
	end
	return c0
end

-- Distance from the waist pivot to the centre of the head along the spine, from the rig's joints.
local function headReach(joints: { [string]: Motor6D }): number
	local root, waist, neck = joints.root, joints.waist, joints.neck
	if not (root and waist and neck) then
		return DEFAULT_HEAD_REACH
	end
	local reach = (waist.C0.Position.Y - root.C1.Position.Y)
		+ (neck.C0.Position.Y - waist.C1.Position.Y)
		- neck.C1.Position.Y
	return math.clamp(reach, 0.5, 4)
end

local function poseTargets(character: Model, root: BasePart, stance: string, standHip: number): { [Motor6D]: CFrame }
	local joints: { [string]: Motor6D } = {}
	local targets: { [Motor6D]: CFrame } = {}
	for key, spec in JOINTS do
		local joint = findJoint(character, spec)
		if joint then
			joints[key] = joint
			targets[joint] = rest(joint)
		end
	end

	if stance == "Crouch" then
		local drop = standHip - Movement.hipHeight("Crouch", standHip)
		for _, leg in LEGS do
			local hip, knee, ankle = joints[leg[1]], joints[leg[2]], joints[leg[3]]
			if hip and knee and ankle then
				local thigh = (knee.C0.Position - hip.C1.Position).Magnitude
				local shin = (ankle.C0.Position - knee.C1.Position).Magnitude
				if thigh > 0.05 and shin > 0.05 then
					local a, b = Movement.legAngles(thigh, shin, drop)
					targets[hip] = rest(hip) * CFrame.Angles(a, 0, 0)
					targets[knee] = rest(knee) * CFrame.Angles(-(a + b), 0, 0)
					targets[ankle] = rest(ankle) * CFrame.Angles(b, 0, 0)
				end
			end
		end
		if joints.waist then
			targets[joints.waist] = rest(joints.waist) * CFrame.Angles(-CROUCH_LEAN, 0, 0)
		end
		if joints.neck then
			targets[joints.neck] = rest(joints.neck) * CFrame.Angles(CROUCH_LEAN, 0, 0)
		end
	elseif stance == "Prone" and joints.root then
		local rootRest = rest(joints.root)
		local proneHip = Movement.hipHeight("Prone", standHip)
		-- Lower the waist pivot to the prone body height above the ground ...
		local dy = Movement.proneBodyHeight - (proneHip + root.Size.Y / 2 + rootRest.Position.Y)
		-- ... slide it back so the head ends up over the root part, then tip the body forward 90°.
		local back = headReach(joints)
		targets[joints.root] = CFrame.new(0, dy, back) * rootRest * CFrame.Angles(-math.pi / 2, 0, 0)
		if joints.neck then
			targets[joints.neck] = rest(joints.neck) * CFrame.Angles(PRONE_NECK_LIFT, 0, 0)
		end
	end
	return targets
end

local function setProneBody(character: Model, prone: boolean)
	for _, part in character:GetDescendants() do
		if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then
			continue
		end
		if prone then
			if part.CollisionGroup ~= StancePose.PRONE_GROUP then
				savedBody[part] = { group = part.CollisionGroup, massless = part.Massless }
				part.CollisionGroup = StancePose.PRONE_GROUP
				part.Massless = true
			end
		elseif part.CollisionGroup == StancePose.PRONE_GROUP then
			local saved = savedBody[part]
			part.CollisionGroup = if saved then saved.group else "Default"
			part.Massless = if saved then saved.massless else false
			savedBody[part] = nil
		end
	end
end

-- Starts the tween into `stance`. Call restoreBody once a transition out of prone has finished.
function StancePose.apply(character: Model, humanoid: Humanoid, root: BasePart, stance: string, standHip: number, duration: number)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local info = TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for joint, target in poseTargets(character, root, stance, standHip) do
		local previous = activeTweens[joint]
		if previous then
			previous:Cancel()
		end
		local tween = TweenService:Create(joint, info, { C0 = target })
		activeTweens[joint] = tween
		tween:Play()
	end
	if stance == "Prone" then
		setProneBody(character, true)
	end
end

function StancePose.restoreBody(character: Model)
	setProneBody(character, false)
end

function StancePose.init()
	for _, group in { StancePose.PRONE_GROUP, StancePose.HITSCAN_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(StancePose.PRONE_GROUP, "Default", false)
end

return StancePose
