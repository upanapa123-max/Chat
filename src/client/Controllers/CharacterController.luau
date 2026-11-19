--[[
	Local stance and movement intent: stand / crouch / prone, aim and sprint.

	The server owns the outcome (WalkSpeed, HipHeight, body pose, shot origin; see MovementService).
	To keep it responsive the client predicts the stance the moment a key is pressed: it lowers its
	own HipHeight and eases the camera to the new eye height, then sends
	SetMovement(seq, stance, aiming, sprinting). The server answers every request with
	MovementState(seq, stance); if its answer to the latest request differs (no headroom, too soon)
	the client takes the server's stance. Unanswered requests are re-sent.

	Camera: Roblox puts the camera a fixed height above the root part. CameraOffset makes up the
	difference between that and a smoothed eye height, so the view glides between stances even
	though the root part drops or rises abruptly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local Movement = require(shared:WaitForChild("Data"):WaitForChild("Movement"))
local Stance = require(shared:WaitForChild("Stance"))

local RESEND_AFTER = 0.75
local JUMP_PRESS_GAP = 0.25 -- JumpRequest repeats while Space is held; a gap means a new press
local MIN_EYE_SHARPNESS = 4

local CharacterController = {}
CharacterController.__index = CharacterController

function CharacterController.new(remotes: { [string]: RemoteEvent })
	local self = setmetatable({}, CharacterController)
	self.remotes = remotes
	self.humanoid = nil :: Humanoid?
	self:reset()
	return self
end

function CharacterController:reset()
	self.enabled = false
	self.aiming = false
	self.sprintHeld = false
	self.stance = "Stand"
	self.lastFrom = "Stand"
	self.crouched = false -- stance ~= "Stand"; read by the viewmodel
	self.mode = "Walk"
	self.busyUntil = 0
	self.standHip = nil :: number?
	self.eye = nil :: number?
	self.eyeSharpness = 12
	self.seq = 0
	self.acked = 0
	self.sentAt = 0
	self.sentKey = ""
	self.lastJumpRequest = -math.huge
end

function CharacterController:attach(humanoid: Humanoid?)
	self:reset()
	self.humanoid = humanoid
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
	end
end

function CharacterController:isAlive(): boolean
	local humanoid = self.humanoid
	return humanoid ~= nil and humanoid.Parent ~= nil and humanoid.Health > 0
end

-- Requests start once the server has sent the first weapon state for this life.
function CharacterController:enable()
	self.enabled = true
	self:_push(true)
end

function CharacterController:_push(force: boolean?)
	self.mode = Movement.modeFor(self.stance, self.aiming, self.sprintHeld)
	if not self.enabled then
		return
	end
	local key = ("%s|%s|%s"):format(self.stance, tostring(self.aiming), tostring(self.sprintHeld))
	if key == self.sentKey and not force then
		return
	end
	self.sentKey = key
	self.seq += 1
	self.sentAt = os.clock()
	self.remotes.SetMovement:FireServer(self.seq, self.stance, self.aiming, self.sprintHeld)
end

-- Local half of a stance change: HipHeight, jumping, camera easing speed.
function CharacterController:_applyStance(stance: string)
	local from = self.stance
	local humanoid = self.humanoid
	if from == "Stand" and humanoid then
		self.standHip = humanoid.HipHeight
	end
	local duration = Movement.transitionTime(from, stance)
	self.lastFrom = from
	self.stance = stance
	self.crouched = stance ~= "Stand"
	self.busyUntil = os.clock() + duration
	self.eyeSharpness = math.max(MIN_EYE_SHARPNESS, 4 / math.max(duration, 0.05))
	if humanoid then
		if Stance.usesHipHeight(humanoid) and self.standHip then
			humanoid.HipHeight = Movement.hipHeight(stance, self.standHip)
		end
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, Movement.stance[stance].canJump)
	end
end

function CharacterController:requestStance(target: string)
	local humanoid = self.humanoid
	local root = humanoid and humanoid.RootPart
	if not self.enabled or not humanoid or not root or not self:isAlive() then
		return
	end
	if target == self.stance or os.clock() < self.busyUntil then
		return
	end
	local standHip = if self.stance == "Stand" then humanoid.HipHeight else self.standHip or humanoid.HipHeight
	if Movement.isRising(self.stance, target) and not Stance.hasHeadroom(humanoid.Parent :: Model, humanoid, root, target, standHip) then
		return
	end
	self:_applyStance(target)
	self:_push()
end

-- Server's answer. Only the answer to the latest request can correct the prediction.
function CharacterController:onServerState(seq: number, stance: string)
	if typeof(seq) ~= "number" or seq ~= self.seq or not Movement.isStance(stance) then
		return
	end
	self.acked = seq
	if stance ~= self.stance then
		self:_applyStance(stance)
		self.mode = Movement.modeFor(self.stance, self.aiming, self.sprintHeld)
		self.sentKey = ("%s|%s|%s"):format(self.stance, tostring(self.aiming), tostring(self.sprintHeld))
	end
end

function CharacterController:setAiming(aiming: boolean)
	self.aiming = aiming
	self:_push()
end

-- Sprinting from crouch or prone stands you up first.
function CharacterController:setSprinting(held: boolean)
	self.sprintHeld = held
	if held and self.stance ~= "Stand" then
		self:requestStance("Stand")
	end
	self:_push()
end

function CharacterController:toggleCrouch()
	self:requestStance(if self.stance == "Crouch" then "Stand" else "Crouch")
end

function CharacterController:toggleProne()
	self:requestStance(if self.stance == "Prone" then "Stand" else "Prone")
end

-- Space while low: one stance up (prone -> crouch -> stand). Jumping itself is disabled when low.
function CharacterController:onJumpRequest()
	local now = os.clock()
	local isNewPress = now - self.lastJumpRequest > JUMP_PRESS_GAP
	self.lastJumpRequest = now
	if not isNewPress then
		return
	end
	if self.stance == "Prone" then
		self:requestStance("Crouch")
	elseif self.stance == "Crouch" then
		self:requestStance("Stand")
	end
end

function CharacterController:releaseHeldInputs()
	self.aiming = false
	self.sprintHeld = false
	self:_push()
end

function CharacterController:isSprinting(): boolean
	return self.mode == "Sprint" and os.clock() >= self.busyUntil
end

-- Mirrors the server: no shots while sprinting or while getting into / out of prone.
function CharacterController:canFire(): boolean
	if self.mode == "Sprint" then
		return false
	end
	local changingProne = self.stance == "Prone" or self.lastFrom == "Prone"
	return not (changingProne and os.clock() < self.busyUntil)
end

function CharacterController:isMoving(): boolean
	local humanoid = self.humanoid
	return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05
end

function CharacterController:update(dt: number)
	local humanoid = self.humanoid
	local root = humanoid and humanoid.RootPart
	if not humanoid or not root then
		return
	end
	if self.stance == "Stand" and os.clock() >= self.busyUntil then
		self.standHip = humanoid.HipHeight -- follows avatar scaling while standing
	end
	local standHip = self.standHip or humanoid.HipHeight
	local target = Stance.eyeHeight(humanoid, root, self.stance, standHip)
	local eye = self.eye or target
	eye += (target - eye) * (1 - math.exp(-dt * self.eyeSharpness))
	self.eye = eye
	humanoid.CameraOffset = Vector3.new(0, eye - Stance.cameraBaseline(humanoid, root), 0)

	if self.enabled and self.acked < self.seq and os.clock() - self.sentAt > RESEND_AFTER then
		self:_push(true)
	end
end

return CharacterController
