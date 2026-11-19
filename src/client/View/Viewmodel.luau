--[[
	First-person rifle presentation: placeholder geometry, ADS blend, bob, recoil camera pitch,
	viewmodel kick, muzzle flash, report sound and server-confirmed tracers. Purely cosmetic.

	Camera recoil uses a restore/apply pair so it never accumulates into the real aim:
	  restoreCamera()  bound just BEFORE Roblox's camera update: undoes last frame's pitch
	  render()         bound just AFTER it: remembers the clean CFrame, then adds recoil pitch
	Because the shot direction is read from the camera with recoil applied, rapid follow-up
	shots land higher until recoil settles — controllable climb with no random camera shake.
]]

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local MUZZLE_OFFSET = Vector3.new(0, 0.02, -1.27)
local HIP_OFFSET = Vector3.new(0.53, -0.54, -0.98)
local ADS_OFFSET = Vector3.new(0, -0.225, -0.85)
local BLEND_SHARPNESS = 14
local FLASH_LIFETIME = 0.052
local TRACER_LIFETIME = 0.045

local Viewmodel = {}
Viewmodel.__index = Viewmodel

local function piece(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function buildRifle(): Model
	local model = Instance.new("Model")
	model.Name = "LocalRangeRifle"
	model.WorldPivot = CFrame.identity
	local dark = Color3.fromRGB(36, 40, 40)
	local metal = Color3.fromRGB(83, 89, 85)
	local function block(name: string, size: Vector3, offset: Vector3, color: Color3)
		piece(model, name, size, color, Enum.Material.SmoothPlastic).CFrame = CFrame.new(offset)
	end
	block("Receiver", Vector3.new(0.23, 0.22, 0.65), Vector3.new(0, 0, 0), metal)
	block("Handguard", Vector3.new(0.2, 0.19, 0.65), Vector3.new(0, 0.01, -0.54), dark)
	block("Barrel", Vector3.new(0.08, 0.08, 0.44), Vector3.new(0, 0.02, -1.02), metal)
	block("Magazine", Vector3.new(0.13, 0.31, 0.2), Vector3.new(0, -0.2, -0.14), dark)
	block("Stock", Vector3.new(0.16, 0.18, 0.43), Vector3.new(0, -0.01, 0.45), dark)
	block("Sight housing", Vector3.new(0.17, 0.09, 0.21), Vector3.new(0, 0.15, -0.06), dark)
	block("Front sight", Vector3.new(0.03, 0.055, 0.035), Vector3.new(0, 0.225, -0.75), metal)
	return model
end

function Viewmodel.new(def)
	local self = setmetatable({}, Viewmodel)
	self.def = def
	self.model = buildRifle()

	local sound = Instance.new("Sound")
	sound.Name = "Report"
	sound.SoundId = def.sound.id
	sound.Volume = def.sound.volume
	sound.Parent = self.model:FindFirstChild("Receiver")
	self.sound = sound

	self.flashTime = -math.huge
	self:reset()
	return self
end

function Viewmodel:reset()
	self.model.Parent = nil
	self.recoil = 0
	self.kick = 0
	self.ads = 0
	self.dip = 0
	self.phase = 0
	self.muzzle = nil :: Vector3?
	self.camera = nil :: Camera?
	self.baseCamera = nil :: CFrame?
end

function Viewmodel:isShown(): boolean
	return self.model.Parent ~= nil
end

function Viewmodel:fire(aiming: boolean)
	local recoil = self.def.recoil
	self.recoil = math.min(recoil.maxPitch, self.recoil + (if aiming then recoil.adsPitch else recoil.hipPitch))
	self.kick = math.min(recoil.maxKick, self.kick + (if aiming then recoil.adsKick else recoil.hipKick))
	self.flashTime = os.clock()
	self.sound.TimePosition = 0
	self.sound:Play()

	local muzzle = self.muzzle
	if muzzle then
		local flash = piece(Workspace, "LocalFlash", Vector3.new(0.24, 0.24, 0.24), Color3.fromRGB(255, 211, 117), Enum.Material.Neon)
		flash.Shape = Enum.PartType.Ball
		flash.Position = muzzle
		local light = Instance.new("PointLight")
		light.Color = flash.Color
		light.Range = 9
		light.Brightness = 3
		light.Parent = flash
		Debris:AddItem(flash, FLASH_LIFETIME)
	end
end

function Viewmodel:showTracer(endpoint: Vector3)
	local muzzle = self.muzzle
	if not muzzle then
		return
	end
	local length = (endpoint - muzzle).Magnitude
	if length > 0.1 then
		local tracer = piece(Workspace, "LocalTracer", Vector3.new(0.036, 0.036, length), Color3.fromRGB(240, 180, 92), Enum.Material.Neon)
		tracer.CFrame = CFrame.lookAt((endpoint + muzzle) / 2, endpoint)
		Debris:AddItem(tracer, TRACER_LIFETIME)
	end
end

function Viewmodel:restoreCamera(camera: Camera?)
	if camera and camera == self.camera and self.baseCamera then
		camera.CFrame = self.baseCamera
	end
	self.baseCamera = nil
end

function Viewmodel:render(camera: Camera, dt: number, aiming: boolean, crouched: boolean, sprinting: boolean, reloading: boolean, moving: boolean)
	local blend = 1 - math.exp(-dt * BLEND_SHARPNESS)
	self.ads += ((if aiming and not reloading then 1 else 0) - self.ads) * blend
	self.dip += ((if reloading then 1 elseif sprinting then 0.6 else 0) - self.dip) * blend
	-- Hold recoil briefly while the flash is up, then recover quickly.
	self.recoil *= math.exp(-dt * (if os.clock() - self.flashTime < 0.055 then 2 else 12))
	self.kick *= math.exp(-dt * 15)
	self.phase += dt * (if sprinting then 13 elseif crouched then 6 else 9)
	local bob = if moving then 0.022 * (1 - 0.8 * self.ads) else 0

	self.camera = camera
	self.baseCamera = camera.CFrame
	camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(self.recoil), 0, 0)
	local fov = self.def.fieldOfView
	camera.FieldOfView = fov.hip + (fov.ads - fov.hip) * self.ads

	local offset = HIP_OFFSET:Lerp(ADS_OFFSET, self.ads)
	offset += Vector3.new(math.sin(self.phase) * bob, math.cos(self.phase * 2) * bob - self.dip * 0.42, self.kick)
	local pose = camera.CFrame * CFrame.new(offset) * CFrame.Angles(self.kick * 0.37 - self.dip * 0.35, 0, self.dip * 0.2)
	self.model:PivotTo(pose)
	self.model.Parent = camera
	self.muzzle = pose:PointToWorldSpace(MUZZLE_OFFSET)
end

return Viewmodel
