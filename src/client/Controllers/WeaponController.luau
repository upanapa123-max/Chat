--[[
	Local weapon input and presentation glue.

	Prediction policy: recoil, muzzle flash and sound play immediately on click.
	Ammo counts, hits, damage and armor results are shown only when the server reports them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local Calibers = require(shared:WaitForChild("Data"):WaitForChild("Calibers"))

local SYNC_RETRY = 0.5

local WeaponController = {}
WeaponController.__index = WeaponController

function WeaponController.new(remotes, def, character, viewmodel, hud)
	local self = setmetatable({}, WeaponController)
	self.remotes = remotes
	self.def = def
	self.character = character
	self.viewmodel = viewmodel
	self.hud = hud
	self:reset()
	return self
end

function WeaponController:reset()
	self.ready = false
	self.magazine = 0
	self.reloading = false
	self.nextShot = 0
	self.nextSync = 0
	self.viewmodel:reset()
	self.hud:reset()
end

function WeaponController:onState(state)
	if not self.character:isAlive() then
		return
	end
	if state.weaponId ~= self.def.id then
		warn("[LastShift] Server equipped " .. tostring(state.weaponId) .. "; client only has " .. self.def.id)
	end
	self.magazine = state.magazine
	self.reloading = state.reloading
	if not self.ready then
		self.ready = true
		self.character:enable()
	end
	self.hud:setWeaponState(state)
end

function WeaponController:onShot(result)
	if not self.character:isAlive() then
		return
	end
	self.hud:showShot(result)
	self.viewmodel:showTracer(result.endpoint)
end

function WeaponController:tryFire()
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	if not self.ready or not camera or self.reloading or self.magazine <= 0 then
		return
	end
	if self.character:isSprinting() or now < self.nextShot then
		return
	end
	self.nextShot = now + self.def.fireInterval
	self.remotes.Fire:FireServer(camera.CFrame.LookVector)
	self.viewmodel:fire(self.character.aiming)
end

function WeaponController:reload()
	if self.ready then
		self.remotes.Reload:FireServer()
	end
end

function WeaponController:selectSlot(slot: number)
	local ammoId = Calibers[self.def.caliber].ammo[slot]
	if self.ready and ammoId then
		self.remotes.SelectAmmo:FireServer(ammoId)
	end
end

-- Until the first state arrives (e.g. remotes raced the spawn), keep asking for it.
function WeaponController:update()
	if not self.ready and os.clock() >= self.nextSync then
		self.nextSync = os.clock() + SYNC_RETRY
		self.remotes.RequestSync:FireServer()
	end
end

return WeaponController
