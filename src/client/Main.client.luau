--[[
	Client bootstrap: builds controllers/views for the starting weapon, routes input,
	listens to server messages and drives per-frame rendering.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("LastShift")
local data = shared:WaitForChild("Data")
local Net = require(shared:WaitForChild("Net"))
local Weapons = require(data:WaitForChild("Weapons"))
local Loadout = require(data:WaitForChild("Loadout"))

local Keybinds = require(script.Parent:WaitForChild("Keybinds"))
local controllers = script.Parent:WaitForChild("Controllers")
local views = script.Parent:WaitForChild("View")
local CharacterController = require(controllers:WaitForChild("CharacterController"))
local WeaponController = require(controllers:WaitForChild("WeaponController"))
local Viewmodel = require(views:WaitForChild("Viewmodel"))
local DebugHud = require(views:WaitForChild("DebugHud"))
local SoundPlayer = require(views:WaitForChild("SoundPlayer"))
local Effects = require(views:WaitForChild("Effects"))
local HitFeedback = require(views:WaitForChild("HitFeedback"))
local StanceSounds = require(views:WaitForChild("StanceSounds"))

local remotes = Net.waitFor(shared)
local weaponDef = Weapons[Loadout.startingWeapon]

SoundPlayer.init()
Effects.init()
StanceSounds.init() -- after SoundPlayer: uses its Foley group

local character = CharacterController.new(remotes)
local viewmodel = Viewmodel.new()
local hud = DebugHud.new(player, weaponDef)
local feedback = HitFeedback.new(player:WaitForChild("PlayerGui"))
local weapon = WeaponController.new(remotes, weaponDef, character, viewmodel, hud, Effects)

player.CameraMode = Enum.CameraMode.LockFirstPerson
UserInputService.MouseIconEnabled = false

-- Lifecycle -------------------------------------------------------------------

local function onCharacterAdded(model: Model)
	character:attach(nil)
	weapon:reset()
	local humanoid = model:WaitForChild("Humanoid")
	if model == player.Character and humanoid:IsA("Humanoid") then
		character:attach(humanoid)
	end
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

remotes.WeaponState.OnClientEvent:Connect(function(state)
	weapon:onState(state)
end)

remotes.ShotResult.OnClientEvent:Connect(function(result)
	weapon:onShot(result)
	feedback:onShot(result)
end)

remotes.ShotFx.OnClientEvent:Connect(function(fx)
	Effects.remoteShot(fx)
end)

remotes.MovementState.OnClientEvent:Connect(function(seq, stance)
	character:onServerState(seq, stance)
end)

-- Input -----------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not character:isAlive() then
		return
	end
	local key = input.KeyCode
	if input.UserInputType == Keybinds.fire then
		weapon:setTrigger(true)
	elseif input.UserInputType == Keybinds.aim then
		character:setAiming(true)
	elseif key == Keybinds.sprint then
		character:setSprinting(true)
	elseif key == Keybinds.crouch then
		character:toggleCrouch()
	elseif key == Keybinds.prone then
		character:toggleProne()
	elseif key == Keybinds.reload then
		weapon:reload()
	elseif Keybinds.ammoSlots[key] then
		weapon:selectSlot(Keybinds.ammoSlots[key])
	elseif key == Keybinds.nextWeapon then
		weapon:cycleWeapon(1)
	elseif key == Keybinds.fireMode then
		weapon:cycleFireMode()
	end
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if processed or not character:isAlive() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel and input.Position.Z ~= 0 then
		weapon:cycleWeapon(if input.Position.Z > 0 then -1 else 1)
	end
end)

-- Releases are handled even when a GUI ate the input, so ADS/sprint never get stuck.
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Keybinds.fire then
		weapon:setTrigger(false)
	elseif input.UserInputType == Keybinds.aim then
		character:setAiming(false)
	elseif input.KeyCode == Keybinds.sprint then
		character:setSprinting(false)
	end
end)

-- Space while crouched / prone gets up one stance (jumping is disabled while low).
UserInputService.JumpRequest:Connect(function()
	if character:isAlive() then
		character:onJumpRequest()
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	character:releaseHeldInputs()
	weapon:setTrigger(false)
end)

-- Rendering -------------------------------------------------------------------

RunService:BindToRenderStep("LastShiftRestoreCamera", Enum.RenderPriority.Camera.Value - 1, function()
	viewmodel:restoreCamera(Workspace.CurrentCamera)
end)

RunService:BindToRenderStep("LastShiftView", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = Workspace.CurrentCamera
	if not camera or not character:isAlive() then
		if viewmodel:isShown() then
			viewmodel:reset()
		end
		hud:setCrosshairVisible(false)
		return
	end

	weapon:update()
	if not weapon.ready then
		return
	end

	character:update(dt)
	local sprinting = character:isSprinting()
	viewmodel:render(
		camera,
		dt,
		character.aiming,
		character.crouched,
		sprinting,
		weapon.reloading,
		character:isMoving()
	)
	hud:setCrosshairVisible(not sprinting and not weapon.reloading)
end)
