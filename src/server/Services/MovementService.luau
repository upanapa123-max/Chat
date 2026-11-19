--[[
	Server-owned stance and movement. The client sends SetMovement(seq, stance, aiming, sprinting);
	the server decides what actually happens:
	  - stance changes obey Movement transition times, and rising needs headroom
	  - the movement mode (and so WalkSpeed) comes from the accepted stance and intent; sprint only
	    counts when standing, and speed is capped while a stance change is in progress
	  - HipHeight, jumping, the body pose (StancePose) and the shot origin follow the stance
	  - firing is blocked while dropping into or getting up from prone
	Every request is answered with MovementState(seq, stance) so the predicting client can correct
	itself when a change was refused.

	Still to come (multiplayer milestone): speed / position integrity checks. The owning client
	simulates its own character's physics, so the server's HipHeight and WalkSpeed are what an
	honest client uses, not a guarantee against exploits.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local Movement = require(shared:WaitForChild("Data"):WaitForChild("Movement"))
local Stance = require(shared:WaitForChild("Stance"))
local PlayerSessions = require(script.Parent.PlayerSessions)
local StancePose = require(script.Parent.StancePose)

-- Back-to-back requests can arrive closer together than they were sent; don't refuse legit ones.
local BUSY_TOLERANCE = 0.08
local MAX_SEQ = 2 ^ 30

export type BodyState = {
	stance: string,
	aiming: boolean,
	sprinting: boolean,
	busyUntil: number,
	blocksFire: boolean,
	standHip: number,
	jumpPower: number,
	jumpHeight: number,
}

local MovementService = {}

MovementService.HITSCAN_GROUP = StancePose.HITSCAN_GROUP

local function refresh(session: PlayerSessions.Session)
	local body: BodyState = session.body
	local mode = Movement.modeFor(body.stance, body.aiming, body.sprinting)
	session.movement = mode
	local speed = Movement.speed[mode]
	if os.clock() < body.busyUntil then
		speed = math.min(speed, Movement.transitionSpeed)
	end
	session.humanoid.WalkSpeed = speed
end

local function changeStance(session: PlayerSessions.Session, target: string)
	local body: BodyState = session.body
	local from = body.stance
	local humanoid = session.humanoid
	local root = humanoid.RootPart
	local now = os.clock()
	if target == from or not root or now < body.busyUntil - BUSY_TOLERANCE then
		return
	end
	if from == "Stand" then
		body.standHip = humanoid.HipHeight
	end
	if Movement.isRising(from, target) and not Stance.hasHeadroom(session.character, humanoid, root, target, body.standHip) then
		return
	end

	local duration = Movement.transitionTime(from, target)
	body.stance = target
	body.busyUntil = now + duration
	body.blocksFire = Movement.blocksFire(from, target)

	if Stance.usesHipHeight(humanoid) then
		humanoid.HipHeight = Movement.hipHeight(target, body.standHip)
	end
	local canJump = Movement.stance[target].canJump
	humanoid.JumpPower = if canJump then body.jumpPower else 0
	humanoid.JumpHeight = if canJump then body.jumpHeight else 0
	session.character:SetAttribute("Stance", target)
	StancePose.apply(session.character, humanoid, root, target, body.standHip, duration)

	task.delay(duration, function()
		if not PlayerSessions.isCurrent(session) then
			return
		end
		refresh(session) -- lifts the transition speed cap
		if body.stance ~= "Prone" then
			StancePose.restoreBody(session.character)
		end
	end)
end

-- False while getting into or out of prone.
function MovementService.canFire(session: PlayerSessions.Session): boolean
	local body: BodyState? = session.body
	return body == nil or not (body.blocksFire and os.clock() < body.busyUntil)
end

-- Eye position for the current stance (matches the client's camera). Falls back to the root
-- part when something solid sits between the root and the eye, so nobody fires through a ceiling.
function MovementService.shotOrigin(session: PlayerSessions.Session, params: RaycastParams): Vector3?
	local body: BodyState? = session.body
	local humanoid = session.humanoid
	local root = humanoid.RootPart
	if not body or not root then
		return nil
	end
	local eye = Stance.eyePosition(humanoid, root, body.stance, body.standHip)
	if Workspace:Raycast(root.Position, eye - root.Position, params) then
		return root.Position
	end
	return eye
end

function MovementService.init(remotes: { [string]: RemoteEvent })
	StancePose.init()

	PlayerSessions.onStarted(function(session)
		local humanoid = session.humanoid
		session.body = {
			stance = "Stand",
			aiming = false,
			sprinting = false,
			busyUntil = 0,
			blocksFire = false,
			standHip = humanoid.HipHeight,
			jumpPower = humanoid.JumpPower,
			jumpHeight = humanoid.JumpHeight,
		} :: BodyState
		session.character:SetAttribute("Stance", "Stand")
		refresh(session)
	end)

	remotes.SetMovement.OnServerEvent:Connect(function(player, seq, stance, aiming, sprinting)
		local session = PlayerSessions.gate(player)
		if not session or not session.body then
			return
		end
		if typeof(seq) ~= "number" or not (seq >= 0 and seq <= MAX_SEQ) or seq % 1 ~= 0 then
			return
		end
		if not Movement.isStance(stance) or typeof(aiming) ~= "boolean" or typeof(sprinting) ~= "boolean" then
			return
		end
		local body: BodyState = session.body
		changeStance(session, stance)
		body.aiming = aiming
		body.sprinting = sprinting
		refresh(session)
		remotes.MovementState:FireClient(player, seq, body.stance)
	end)
end

return MovementService
