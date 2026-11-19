--[[
	Local weapon input and presentation glue.

	Prediction policy: recoil, muzzle flash and sound play immediately on click.
	Ammo counts, hits, damage and armor results are shown only when the server reports them.
	Weapon switches are requested and shown when the server confirms them (WeaponState.weaponId).

	Fire mode (semi/auto) is a local input setting. The server doesn't need it: whatever the mode,
	it only accepts shots at the weapon's fireInterval.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local data = shared:WaitForChild("Data")
local Calibers = require(data:WaitForChild("Calibers"))
local Weapons = require(data:WaitForChild("Weapons"))
local Loadout = require(data:WaitForChild("Loadout"))

local SYNC_RETRY = 0.5

local WeaponController = {}
WeaponController.__index = WeaponController

function WeaponController.new(remotes, def, character, viewmodel, hud, effects)
	local self = setmetatable({}, WeaponController)
	self.remotes = remotes
	self.startDef = def
	self.def = def
	self.character = character
	self.viewmodel = viewmodel
	self.hud = hud
	self.effects = effects
	self.fireModes = {} -- weaponId -> chosen mode, kept across respawns
	self:reset()
	return self
end

function WeaponController:reset()
	self.ready = false
	self.magazine = 0
	self.reloading = false
	self.triggerHeld = false
	self.nextShot = 0
	self.nextSync = 0
	self.def = self.startDef
	self.viewmodel:reset()
	self.viewmodel:setWeapon(self.def)
	self.hud:reset()
	self.hud:setWeapon(self.def)
	self.hud:setFireMode(self:fireMode())
end

function WeaponController:fireMode(): string
	return self.fireModes[self.def.id] or self.def.fireModes[1]
end

function WeaponController:onState(state)
	if not self.character:isAlive() then
		return
	end
	local def = Weapons[state.weaponId]
	if not def then
		warn("[LastShift] Server equipped unknown weapon " .. tostring(state.weaponId))
		return
	end
	if def ~= self.def then
		self.def = def
		self.reloading = false
		self.triggerHeld = false
		self.nextShot = os.clock() + def.equipTime
		self.viewmodel:setWeapon(def)
		self.hud:setWeapon(def)
		self.hud:setFireMode(self:fireMode())
	end
	if state.reloading ~= self.reloading then
		self.viewmodel:setReloading(state.reloading, self.magazine <= 0)
	end
	self.magazine = state.magazine
	self.reloading = state.reloading
	self.viewmodel:setEmpty(state.magazine <= 0)
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
	local muzzle = self.viewmodel:muzzlePosition()
	if muzzle then
		self.effects.tracer(muzzle, result.endpoint)
	end
	self.effects.impact(result.endpoint, result.normal, result.impact or result.surface)
end

-- One shot if allowed. `fromHold` is true for automatic repeats while the trigger stays down.
function WeaponController:tryFire(fromHold: boolean?)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	if not self.ready or not camera or self.reloading then
		return
	end
	if not self.character:canFire() or now < self.nextShot then
		return
	end
	if self.magazine <= 0 then
		if not fromHold then
			self.viewmodel:dryFire()
			self.nextShot = now + 0.25
		end
		return
	end
	self.nextShot = now + self.def.fireInterval
	-- Predicted locally so automatic fire doesn't stall waiting for each WeaponState.
	self.magazine -= 1
	self.remotes.Fire:FireServer(camera.CFrame.LookVector)
	self.viewmodel:fire(self.character.aiming)
end

function WeaponController:setTrigger(held: boolean)
	self.triggerHeld = held
	if held then
		self:tryFire(false)
	end
end

function WeaponController:cycleFireMode()
	local modes = self.def.fireModes
	if #modes < 2 then
		return
	end
	local index = table.find(modes, self:fireMode()) or 1
	local mode = modes[index % #modes + 1]
	self.fireModes[self.def.id] = mode
	self.hud:setFireMode(mode)
	self.viewmodel:dryFire()
end

-- direction: +1 next weapon, -1 previous.
function WeaponController:cycleWeapon(direction: number)
	if not self.ready then
		return
	end
	local count = #Loadout.weapons
	local index = table.find(Loadout.weapons, self.def.id) or 1
	local slot = (index - 1 + direction) % count + 1
	self.remotes.EquipWeapon:FireServer(slot)
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

-- Every frame: keeps asking for state until it arrives, and runs automatic fire.
function WeaponController:update()
	if not self.ready and os.clock() >= self.nextSync then
		self.nextSync = os.clock() + SYNC_RETRY
		self.remotes.RequestSync:FireServer()
	end
	if self.triggerHeld and self:fireMode() == "Auto" then
		self:tryFire(true)
	end
end

return WeaponController
