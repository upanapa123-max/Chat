--[[
	First-person weapon presentation. Purely cosmetic: nothing here decides a hit or an ammo count.

	One rig per weapon (built lazily from Visual/WeaponModels plus gloved arms). Every frame the
	rig is placed relative to the camera from:
	  hip/ADS pose      ADS lines the model's `Aim` attachment up with the eye, so every sight is
	                    centred without hand-tuned offsets
	  sway, bob         mouse-look lag and walk cycle
	  sprint, equip     pose blends
	  reload            magazine drops out, left hand fetches a new one, bolt/slide is racked
	  recoil            springs: camera pitch + fixed yaw pattern, viewmodel kick/flip/roll

	Camera recoil uses a restore/apply pair so it never accumulates into the real aim:
	  restoreCamera()  bound just BEFORE Roblox's camera update: undoes last frame's recoil
	  render()         bound just AFTER it: remembers the clean CFrame, then adds recoil
	The shot direction is read from the camera with recoil applied, so fast follow-up shots land
	higher until the spring settles. The yaw drift follows a fixed per-shot pattern, never RNG.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("LastShift")
local WeaponModels = require(shared:WaitForChild("Visual"):WaitForChild("WeaponModels"))
local WeaponSounds = require(shared:WaitForChild("Data"):WaitForChild("WeaponSounds"))
local SoundPlayer = require(script.Parent:WaitForChild("SoundPlayer"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local rad = math.rad
local clamp = math.clamp
local E = math.exp(1)

local BLEND_SHARPNESS = 14
local FLASH_LIFETIME = 0.05
local SLIDE_CYCLE = 0.07
local SHOT_RESET = 0.35 -- seconds without firing before the yaw pattern restarts
local SPRING_STEP = 1 / 240

local SLEEVE = Color3.fromRGB(96, 92, 72)
local SLEEVE_DARK = Color3.fromRGB(72, 70, 56)
local GLOVE = Color3.fromRGB(30, 30, 29)
local GLOVE_PAD = Color3.fromRGB(52, 50, 46)
local CASING_SCALE = { AR = 1, AK = 1.15, PDW = 0.8, HandCannon = 1.25 }

local Viewmodel = {}
Viewmodel.__index = Viewmodel

type Spring = { x: number, v: number }

local function spring(): Spring
	return { x = 0, v = 0 }
end

-- Critically damped spring towards 0.
local function stepSpring(s: Spring, stiffness: number, dt: number)
	local damping = 2 * math.sqrt(stiffness)
	local remaining = math.min(dt, 0.1)
	while remaining > 0 do
		local h = math.min(SPRING_STEP, remaining)
		s.v += (-stiffness * s.x - damping * s.v) * h
		s.x += s.v * h
		remaining -= h
	end
end

-- Velocity that makes a critically damped spring at rest peak at `amount`.
local function kickSpring(s: Spring, amount: number, stiffness: number)
	s.v += amount * math.sqrt(stiffness) * E
end

local function smooth(a: number, b: number, t: number): number
	local x = clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

-- Gloved hands and sleeves, in weapon model space, placed from the Grip/Support attachments.
local function addArms(model: Model, parts: { BasePart }, grip: Vector3, support: Vector3, pistol: boolean)
	local function add(part: BasePart, name: string, cf: CFrame, color: Color3, material: Enum.Material, group: string)
		part.Name = name
		part.CFrame = cf
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part:SetAttribute("Group", group)
		part.Parent = model
		table.insert(parts, part)
	end
	local function box(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, group: string)
		local part = Instance.new("Part")
		part.Size = size
		add(part, name, cf, color, material, group)
	end
	local function limb(name: string, a: Vector3, b: Vector3, d: number, color: Color3, group: string)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new((b - a).Magnitude, d, d)
		add(part, name, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0), color, Enum.Material.Fabric, group)
		local cap = Instance.new("Part")
		cap.Shape = Enum.PartType.Ball
		cap.Size = Vector3.new(d, d, d)
		add(cap, name .. " end", CFrame.new(b), color, Enum.Material.Fabric, group)
	end

	-- Right hand wraps the pistol grip, index finger along the trigger guard.
	local gripCF = CFrame.new(grip) * CFrame.Angles(rad(-16), 0, 0)
	box("Right glove", Vector3.new(0.13, 0.15, 0.17), gripCF * CFrame.new(0.015, -0.01, 0.01), GLOVE, Enum.Material.Fabric, "Body")
	box("Right knuckles", Vector3.new(0.135, 0.06, 0.1), gripCF * CFrame.new(0.02, 0.03, -0.08), GLOVE_PAD, Enum.Material.Rubber, "Body")
	box("Right thumb", Vector3.new(0.04, 0.04, 0.12), gripCF * CFrame.new(-0.07, 0.06, -0.03), GLOVE, Enum.Material.Fabric, "Body")
	box("Trigger finger", Vector3.new(0.035, 0.035, 0.14), gripCF * CFrame.new(0.06, 0.07, -0.1), GLOVE, Enum.Material.Fabric, "Body")
	local rightWrist = grip + Vector3.new(0.04, -0.07, 0.12)
	local rightElbow = grip + (if pistol then Vector3.new(0.22, -0.32, 0.75) else Vector3.new(0.24, -0.4, 0.85))
	limb("Right cuff", grip + Vector3.new(0.02, -0.04, 0.06), rightWrist + Vector3.new(0.01, -0.01, 0.05), 0.15, GLOVE, "Body")
	limb("Right sleeve", rightWrist + Vector3.new(0.01, -0.01, 0.04), rightElbow, 0.2, SLEEVE, "Body")
	limb("Right sleeve cuff", rightWrist + Vector3.new(0.01, -0.01, 0.04), rightWrist + Vector3.new(0.03, -0.05, 0.14), 0.215, SLEEVE_DARK, "Body")

	-- Left hand: under the handguard on long guns, cupping the right hand on the pistol.
	local supportCF = CFrame.new(support) * CFrame.Angles(0, 0, rad(if pistol then 30 else 70))
	box("Left glove", Vector3.new(0.13, 0.15, 0.19), supportCF, GLOVE, Enum.Material.Fabric, "LeftHand")
	box("Left fingers", Vector3.new(0.05, 0.14, 0.16), supportCF * CFrame.new(0.08, 0.04, 0), GLOVE_PAD, Enum.Material.Rubber, "LeftHand")
	local leftWrist = support + (if pistol then Vector3.new(-0.06, -0.06, 0.1) else Vector3.new(-0.07, -0.08, 0.11))
	local leftElbow = support + (if pistol then Vector3.new(-0.32, -0.36, 0.6) else Vector3.new(-0.42, -0.36, 0.72))
	limb("Left cuff", support + Vector3.new(-0.03, -0.04, 0.05), leftWrist + Vector3.new(-0.01, -0.01, 0.05), 0.15, GLOVE, "LeftHand")
	limb("Left sleeve", leftWrist + Vector3.new(-0.01, -0.01, 0.04), leftElbow, 0.2, SLEEVE, "LeftHand")
	limb("Left sleeve cuff", leftWrist + Vector3.new(-0.01, -0.01, 0.04), leftWrist + Vector3.new(-0.04, -0.05, 0.14), 0.215, SLEEVE_DARK, "LeftHand")
end

local function buildRig(def)
	local built = WeaponModels.build(def.model)
	local function at(name: string): Vector3
		return WeaponModels.attachment(built, name).Position
	end
	local pistol = def.model == "HandCannon"
	addArms(built.model, built.parts, at("Grip"), at("Support"), pistol)
	for _, part in built.parts do
		part.Anchored = true
	end
	built.root.Anchored = true
	built.model.Name = "LocalViewmodel_" .. def.id

	local items = {}
	local flash = {}
	for _, part in built.parts do
		local group = part:GetAttribute("Group") or "Body"
		table.insert(items, { part = part, offset = part.CFrame, group = group })
		if group == "Flash" then
			table.insert(flash, part)
		end
	end
	return {
		def = def,
		model = built.model,
		items = items,
		flash = flash,
		muzzle = at("Muzzle"),
		aim = at("Aim"),
		eject = at("Eject"),
		support = at("Support"),
		magWell = at("MagWell"),
		pistol = pistol,
	}
end

function Viewmodel.new()
	local self = setmetatable({}, Viewmodel)
	self.rigs = {}
	self.rig = nil
	self.def = nil
	self.random = Random.new()
	self.flashTime = -math.huge
	self.slideTime = -math.huge
	self.lastShot = -math.huge
	self.shotIndex = 0
	self.sounds = nil
	self.reloadThreads = {}

	-- World-space muzzle light and smoke (lights/particles are most reliable outside the camera).
	local fx = Instance.new("Part")
	fx.Name = "LocalMuzzleFx"
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanTouch = false
	fx.CanQuery = false
	fx.CastShadow = false
	fx.Transparency = 1
	fx.Size = Vector3.new(0.1, 0.1, 0.1)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 186, 104)
	light.Range = 16
	light.Brightness = 5
	light.Shadows = true
	light.Enabled = false
	light.Parent = fx
	local attachment = Instance.new("Attachment")
	attachment.Parent = fx
	local smoke = Instance.new("ParticleEmitter")
	smoke.Enabled = false
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(170, 170, 165))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.9) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.6, 1.2)
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.Drag = 3
	smoke.Acceleration = Vector3.new(0, 1.2, 0)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.LightInfluence = 1
	smoke.Parent = attachment
	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.04, 0.1)
	sparks.Speed = NumberRange.new(20, 35)
	sparks.SpreadAngle = Vector2.new(12, 12)
	sparks.LightEmission = 1
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Parent = attachment
	fx.Parent = Workspace
	self.fx = { part = fx, light = light, smoke = smoke, sparks = sparks }

	-- Springs: camera (degrees) and viewmodel (studs / degrees).
	self.camPitch = spring()
	self.camYaw = spring()
	self.kick = spring()
	self.flip = spring()
	self.roll = spring()
	self.fovPunch = spring()

	self:reset()
	return self
end

function Viewmodel:_cancelReloadSounds()
	for _, thread in self.reloadThreads do
		pcall(task.cancel, thread)
	end
	table.clear(self.reloadThreads)
end

function Viewmodel:reset()
	if self.rig then
		self.rig.model.Parent = nil
	end
	self:_cancelReloadSounds()
	self.ads = 0
	self.sprint = 0
	self.equip = 1
	self.phase = 0
	self.swayX = 0
	self.swayY = 0
	self.reloadStart = nil :: number?
	self.reloadEmpty = false
	self.empty = false
	self.prevLook = nil :: CFrame?
	self.camera = nil :: Camera?
	self.baseCamera = nil :: CFrame?
	self.muzzle = nil :: Vector3?
	self.pose = nil :: CFrame?
	for _, s in { self.camPitch, self.camYaw, self.kick, self.flip, self.roll, self.fovPunch } do
		s.x = 0
		s.v = 0
	end
end

function Viewmodel:setWeapon(def)
	if self.def == def then
		return
	end
	if self.rig then
		self.rig.model.Parent = nil
	end
	self:_cancelReloadSounds()
	self.reloadStart = nil
	local rig = self.rigs[def.id]
	if not rig then
		rig = buildRig(def)
		self.rigs[def.id] = rig
		local set = WeaponSounds.weapons[def.sounds]
		local preload = { set.magOut, set.magIn, set.bolt, set.equip, set.dry }
		for _, layer in set.fire do
			table.insert(preload, layer)
		end
		SoundPlayer.preload(preload)
	end
	self.rig = rig
	self.def = def
	self.sounds = WeaponSounds.weapons[def.sounds]
	self.equip = 1
	self.shotIndex = 0
	SoundPlayer.play(self.sounds.equip, nil, { groupName = "Foley" })
end

function Viewmodel:isShown(): boolean
	return self.rig ~= nil and self.rig.model.Parent ~= nil
end

function Viewmodel:setEmpty(empty: boolean)
	self.empty = empty
end

function Viewmodel:fire(aiming: boolean)
	local def = self.def
	if not def then
		return
	end
	local recoil = def.recoil
	local now = os.clock()
	if now - self.lastShot > SHOT_RESET then
		self.shotIndex = 0
	end
	self.shotIndex += 1
	self.lastShot = now

	-- Camera: climb plus a fixed left/right pattern (same every spray, so it can be learned).
	local camStiffness = recoil.recovery
	kickSpring(self.camPitch, if aiming then recoil.adsPitch else recoil.hipPitch, camStiffness)
	local pattern = math.sin(self.shotIndex * 1.37 + 0.6) * 0.8 + 0.35
	kickSpring(self.camYaw, recoil.yaw * pattern, camStiffness)

	-- Viewmodel: snappier springs, a little organic roll.
	local vmStiffness = recoil.recovery * 2.2
	local adsScale = if aiming then 0.55 else 1
	kickSpring(self.kick, recoil.kick * adsScale, vmStiffness)
	kickSpring(self.flip, recoil.rotation * adsScale, vmStiffness)
	kickSpring(self.roll, recoil.roll * self.random:NextNumber(-1, 1), vmStiffness)
	kickSpring(self.fovPunch, 0.9, vmStiffness)

	self.flashTime = now
	self.slideTime = now
	for _, layer in self.sounds.fire do
		SoundPlayer.play(layer)
	end

	local fx = self.fx
	fx.light.Enabled = true
	fx.sparks:Emit(4)
	fx.smoke:Emit(if self.shotIndex > 3 then 2 else 1)

	-- Casing out of the ejection port, inheriting the player's movement.
	local pose = self.pose
	if pose then
		local ejectCF = pose * CFrame.new(self.rig.eject)
		local carry = Vector3.zero
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			carry = root.AssemblyLinearVelocity
		end
		local velocity = pose.RightVector * self.random:NextNumber(8, 12)
			+ pose.UpVector * self.random:NextNumber(4, 7)
			+ pose.LookVector * self.random:NextNumber(-2.5, 0)
			+ carry
		Effects.casing(ejectCF * CFrame.Angles(0, rad(90), 0), velocity, CASING_SCALE[def.model] or 1)
	end
end

function Viewmodel:dryFire()
	if self.sounds then
		SoundPlayer.play(self.sounds.dry, nil, { groupName = "Foley" })
	end
end

-- Called when the server starts or ends a reload.
function Viewmodel:setReloading(reloading: boolean, wasEmpty: boolean)
	self:_cancelReloadSounds()
	if reloading and self.def then
		self.reloadStart = os.clock()
		self.reloadEmpty = wasEmpty
		local set = self.sounds
		local opts = { groupName = "Foley" }
		table.insert(self.reloadThreads, SoundPlayer.play(set.magOut, nil, opts))
		table.insert(self.reloadThreads, SoundPlayer.play(set.magIn, nil, opts))
		if wasEmpty or self.rig.pistol then
			table.insert(self.reloadThreads, SoundPlayer.play(set.bolt, nil, opts))
		end
	else
		self.reloadStart = nil
	end
end

function Viewmodel:restoreCamera(camera: Camera?)
	if camera and camera == self.camera and self.baseCamera then
		camera.CFrame = self.baseCamera
	end
	self.baseCamera = nil
end

function Viewmodel:render(camera: Camera, dt: number, aiming: boolean, crouched: boolean, sprinting: boolean, reloading: boolean, moving: boolean)
	local def = self.def
	local rig = self.rig
	if not def or not rig then
		return
	end
	local now = os.clock()
	local blend = 1 - math.exp(-dt * BLEND_SHARPNESS)
	self.ads += ((if aiming and not reloading and not sprinting then 1 else 0) - self.ads) * blend
	self.sprint += ((if sprinting and not reloading then 1 else 0) - self.sprint) * blend
	self.equip *= math.exp(-dt * 4.5 / def.equipTime)
	self.phase += dt * (if sprinting then 13 elseif crouched then 6 else 9)

	local recoil = def.recoil
	local vmStiffness = recoil.recovery * 2.2
	stepSpring(self.camPitch, recoil.recovery, dt)
	stepSpring(self.camYaw, recoil.recovery, dt)
	stepSpring(self.kick, vmStiffness, dt)
	stepSpring(self.flip, vmStiffness, dt)
	stepSpring(self.roll, vmStiffness, dt)
	stepSpring(self.fovPunch, vmStiffness, dt)
	self.camPitch.x = math.min(self.camPitch.x, recoil.maxPitch)

	-- Clean camera, then camera recoil on top (undone next frame by restoreCamera).
	local clean = camera.CFrame
	self.camera = camera
	self.baseCamera = clean
	camera.CFrame = clean * CFrame.Angles(rad(self.camPitch.x), rad(self.camYaw.x), 0)
	local fov = def.fieldOfView
	camera.FieldOfView = fov.hip + (fov.ads - fov.hip) * self.ads + self.fovPunch.x

	-- Mouse-look sway: the gun lags slightly behind fast turns.
	if self.prevLook then
		local rx, ry = self.prevLook:ToObjectSpace(clean):ToEulerAnglesYXZ()
		local scale = 1 - 0.75 * self.ads
		local targetX = clamp(-rx * 1.6, -0.08, 0.08) * scale
		local targetY = clamp(-ry * 1.6, -0.1, 0.1) * scale
		local swayBlend = 1 - math.exp(-dt * 10)
		self.swayX += (targetX - self.swayX) * swayBlend
		self.swayY += (targetY - self.swayY) * swayBlend
	end
	self.prevLook = clean

	-- Base pose: hip offset blended to an ADS pose that puts the Aim point on the eye line.
	local hip = def.view.hip
	local hipCF = CFrame.new(hip[1], hip[2], hip[3])
	local adsCF = CFrame.new(0, 0, -def.view.eyeRelief) * CFrame.new(-rig.aim)
	local offset = hipCF:Lerp(adsCF, self.ads)

	local bob = if moving then 0.02 * (1 - 0.85 * self.ads) * (1 + self.sprint) else 0
	local breathe = math.sin(now * 1.3) * 0.004 * (1 - 0.7 * self.ads)
	offset = CFrame.new(math.sin(self.phase) * bob, math.abs(math.cos(self.phase)) * -bob + breathe, 0)
		* offset
		* CFrame.Angles(self.swayX, self.swayY, self.swayY * 0.6)

	local s = def.view.sprint
	local sp = self.sprint
	offset *= CFrame.new(0.08 * sp, -0.12 * sp, 0.05 * sp) * CFrame.Angles(rad(s[1]) * sp, rad(s[2]) * sp, rad(s[3]) * sp)

	-- Reload choreography (progress 0..1 over the weapon's reloadTime).
	local magOffset = CFrame.identity
	local leftOffset = CFrame.identity
	local slideOffset = 0
	if self.reloadStart then
		local r = clamp((now - self.reloadStart) / def.reloadTime, 0, 1)
		local tilt = smooth(0.02, 0.15, r) - smooth(0.8, 0.96, r)
		offset *= CFrame.new(-0.06 * tilt, 0.04 * tilt, 0.08 * tilt) * CFrame.Angles(rad(10) * tilt, rad(-12) * tilt, rad(30) * tilt)
		local down = smooth(0.1, 0.3, r) - smooth(0.48, 0.7, r)
		local magVector = Vector3.new(0, -1.1, 0.12) * down
		magOffset = CFrame.new(magVector)
		local reach = smooth(0.04, 0.16, r) - smooth(0.7, 0.86, r)
		leftOffset = CFrame.new((rig.magWell - rig.support) * reach + magVector)
		if self.reloadEmpty or rig.pistol then
			local rack = smooth(0.76, 0.82, r) - smooth(0.84, 0.92, r)
			slideOffset = 0.12 * rack
			if rig.pistol and self.reloadEmpty and r < 0.8 then
				slideOffset = 0.11 -- held open on an empty pistol until the slide release
			end
		end
	elseif rig.pistol and self.empty then
		slideOffset = 0.11
	end
	local sinceShot = now - self.slideTime
	if sinceShot < SLIDE_CYCLE then
		slideOffset = math.max(slideOffset, 0.11 * (1 - sinceShot / SLIDE_CYCLE))
	end

	-- Equip: rises from below and rolls in.
	local e = self.equip
	offset *= CFrame.new(0.05 * e, -0.55 * e, 0.15 * e) * CFrame.Angles(rad(-30) * e, rad(10) * e, rad(20) * e)

	-- Viewmodel recoil.
	offset *= CFrame.new(0, 0, self.kick.x) * CFrame.Angles(rad(self.flip.x), 0, rad(self.roll.x))

	local pose = camera.CFrame * offset
	self.pose = pose

	-- Muzzle flash: random roll and size for a frame or two.
	local flashAge = now - self.flashTime
	local flashOn = flashAge < FLASH_LIFETIME
	local flashOffset = CFrame.identity
	if flashOn then
		local m = rig.muzzle
		flashOffset = CFrame.new(m)
			* CFrame.Angles(0, 0, self.random:NextNumber(0, math.pi * 2))
			* CFrame.new(0, 0, self.random:NextNumber(-0.03, 0.03))
			* CFrame.new(-m)
		for _, part in rig.flash do
			part.Transparency = if flashAge < FLASH_LIFETIME * 0.5 then 0 else 0.45
		end
	elseif rig.flash[1] and rig.flash[1].Transparency < 1 then
		for _, part in rig.flash do
			part.Transparency = 1
		end
	end
	self.fx.light.Enabled = flashOn

	local groupOffset = {
		Body = CFrame.identity,
		Mag = magOffset,
		LeftHand = leftOffset,
		Slide = CFrame.new(0, 0, slideOffset),
		Flash = flashOffset,
	}
	local parts = table.create(#rig.items)
	local cframes = table.create(#rig.items)
	for i, item in rig.items do
		parts[i] = item.part
		cframes[i] = pose * (groupOffset[item.group] or CFrame.identity) * item.offset
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	if rig.model.Parent ~= camera then
		rig.model.Parent = camera
	end

	local muzzleCF = pose * CFrame.new(rig.muzzle)
	self.muzzle = muzzleCF.Position
	self.fx.part.CFrame = muzzleCF
end

function Viewmodel:muzzlePosition(): Vector3?
	return self.muzzle
end

return Viewmodel
