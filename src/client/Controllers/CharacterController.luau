--[[
	Local stance: aim / sprint / crouch input -> movement mode request, and the crouch camera drop.
	The server owns WalkSpeed; this only asks for a mode and mirrors it for local presentation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local Movement = require(shared:WaitForChild("Data"):WaitForChild("Movement"))

local CAMERA_OFFSET_SHARPNESS = 15

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
	self.crouched = false
	self.sprintHeld = false
	self.mode = "Walk"
end

function CharacterController:attach(humanoid: Humanoid?)
	self:reset()
	self.humanoid = humanoid
end

function CharacterController:isAlive(): boolean
	local humanoid = self.humanoid
	return humanoid ~= nil and humanoid.Parent ~= nil and humanoid.Health > 0
end

-- Mode requests start once the server has sent the first weapon state for this life.
function CharacterController:enable()
	self.enabled = true
	self:_push()
end

function CharacterController:_push()
	if not self.enabled then
		return
	end
	local mode = Movement.modeFor(self.crouched, self.aiming, self.sprintHeld)
	if mode ~= self.mode then
		self.mode = mode
		self.remotes.SetMovement:FireServer(mode)
	end
end

function CharacterController:setAiming(aiming: boolean)
	self.aiming = aiming
	self:_push()
end

function CharacterController:setSprinting(held: boolean)
	self.sprintHeld = held
	self:_push()
end

function CharacterController:toggleCrouch()
	self.crouched = not self.crouched
	self:_push()
end

function CharacterController:releaseHeldInputs()
	self.aiming = false
	self.sprintHeld = false
	self:_push()
end

function CharacterController:isSprinting(): boolean
	return self.mode == "Sprint"
end

function CharacterController:isMoving(): boolean
	local humanoid = self.humanoid
	return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05
end

function CharacterController:update(dt: number)
	local humanoid = self.humanoid
	if not humanoid then
		return
	end
	local target = Vector3.new(0, if self.crouched then Movement.crouchCameraOffset else 0, 0)
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, 1 - math.exp(-dt * CAMERA_OFFSET_SHARPNESS))
end

return CharacterController
