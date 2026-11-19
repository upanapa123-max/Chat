--[[
	World-space combat effects on this client: tracers, bullet impacts and holes, ejected casings,
	and gunshots from other players. Purely cosmetic; positions come from the server's ShotResult /
	ShotFx messages, or from this client's own viewmodel for its muzzle and casings.

	Particle textures are the ones that ship with every Roblox client (rbxasset://textures/particles),
	so no uploads are needed.
]]

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("LastShift")
local Weapons = require(shared:WaitForChild("Data"):WaitForChild("Weapons"))
local WeaponSounds = require(shared:WaitForChild("Data"):WaitForChild("WeaponSounds"))
local SoundPlayer = require(script.Parent:WaitForChild("SoundPlayer"))

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local TRACER_LIFETIME = 0.05
local HOLE_LIFETIME = 20
local MAX_HOLES = 80
local MAX_CASINGS = 24
local REMOTE_SHOT_ROLLOFF = 700

local Effects = {}

local folder: Folder
local random = Random.new()
local holes: { BasePart } = {}
local casingCount = 0

local function fxPart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = folder
	return part
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Enabled = false
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

-- Impact emitters live on one reusable anchored part that we move to each hit.
local impactPart: Part
local impactAttachment: Attachment
local dust: ParticleEmitter
local sparks: ParticleEmitter
local blood: ParticleEmitter

function Effects.init()
	folder = Instance.new("Folder")
	folder.Name = "LastShiftLocalFx"
	folder.Parent = Workspace

	impactPart = fxPart("Impact")
	impactAttachment = Instance.new("Attachment")
	impactAttachment.Parent = impactPart
	dust = emitter(impactAttachment, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(120, 115, 105)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 1.1),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(25, 25),
		Drag = 4,
		Acceleration = Vector3.new(0, 1.5, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		EmissionDirection = Enum.NormalId.Top,
		LightInfluence = 1,
	})
	sparks = emitter(impactAttachment, {
		Texture = SPARK,
		Color = ColorSequence.new(Color3.fromRGB(255, 205, 140)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.1, 0.25),
		Speed = NumberRange.new(12, 26),
		SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, -40, 0),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
	blood = emitter(impactAttachment, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(96, 12, 10)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(35, 35),
		Drag = 6,
		Acceleration = Vector3.new(0, -14, 0),
		EmissionDirection = Enum.NormalId.Top,
		LightInfluence = 1,
	})

	local preload = {}
	for _, list in WeaponSounds.impacts do
		for _, entry in list do
			table.insert(preload, entry)
		end
	end
	for _, entry in WeaponSounds.casings do
		table.insert(preload, entry)
	end
	SoundPlayer.preload(preload)
end

function Effects.tracer(from: Vector3, to: Vector3, width: number?)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 196, 120)
	tracer.Transparency = 0.25
	local w = width or 0.03
	tracer.Size = Vector3.new(w, w, length)
	tracer.CFrame = CFrame.lookAt((from + to) / 2, to)
	tracer.Parent = folder
	Debris:AddItem(tracer, TRACER_LIFETIME)
end

local function bulletHole(position: Vector3, normal: Vector3)
	local hole = Instance.new("Part")
	hole.Name = "BulletHole"
	hole.Anchored = true
	hole.CanCollide = false
	hole.CanTouch = false
	hole.CanQuery = false
	hole.CastShadow = false
	hole.Shape = Enum.PartType.Cylinder
	hole.Material = Enum.Material.SmoothPlastic
	hole.Color = Color3.fromRGB(14, 13, 12)
	local d = random:NextNumber(0.11, 0.15)
	hole.Size = Vector3.new(0.02, d, d)
	-- Cylinder axis is X: point it along the surface normal.
	hole.CFrame = CFrame.lookAlong(position + normal * 0.01, normal) * CFrame.Angles(0, math.rad(90), 0)
	hole.Parent = folder
	-- A lighter chipped ring around the hole.
	local chip = hole:Clone()
	chip.Name = "Chip"
	chip.Color = Color3.fromRGB(150, 146, 138)
	chip.Transparency = 0.45
	chip.Size = Vector3.new(0.012, d * 2.1, d * 2.1)
	chip.CFrame = hole.CFrame * CFrame.new(-0.004, 0, 0)
	chip.Parent = hole
	Debris:AddItem(hole, HOLE_LIFETIME)
	table.insert(holes, hole)
	if #holes > MAX_HOLES then
		local oldest = table.remove(holes, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

-- kind: "World" | "Flesh" | "Armor" | "Miss"
function Effects.impact(position: Vector3, normal: Vector3?, kind: string)
	if kind == "Miss" then
		return
	end
	local n = if normal and normal.Magnitude > 0.5 then normal.Unit else Vector3.yAxis
	impactPart.CFrame = CFrame.lookAlong(position, n) * CFrame.Angles(-math.rad(90), 0, 0)
	if kind == "Flesh" then
		blood:Emit(10)
	elseif kind == "Armor" then
		sparks:Emit(14)
		dust:Emit(2)
	else
		dust:Emit(6)
		sparks:Emit(4)
		bulletHole(position, n)
	end
	local list = WeaponSounds.impacts[kind]
	if list then
		SoundPlayer.play(SoundPlayer.pick(list), impactAttachment, { groupName = "Foley", rollOff = 160 })
	end
end

function Effects.casing(cframe: CFrame, velocity: Vector3, caliberScale: number)
	if casingCount >= MAX_CASINGS then
		return
	end
	casingCount += 1
	local casing = Instance.new("Part")
	casing.Name = "Casing"
	casing.Shape = Enum.PartType.Cylinder
	casing.Size = Vector3.new(0.11 * caliberScale, 0.035 * caliberScale, 0.035 * caliberScale)
	casing.Color = Color3.fromRGB(196, 150, 72)
	casing.Material = Enum.Material.Metal
	casing.Reflectance = 0.1
	casing.CanTouch = false
	casing.CanQuery = false
	casing.CastShadow = false
	casing.CFrame = cframe
	casing.CustomPhysicalProperties = PhysicalProperties.new(2, 0.4, 0.3)
	casing.Parent = folder
	casing.AssemblyLinearVelocity = velocity
	casing.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-30, 30), random:NextNumber(-30, 30), random:NextNumber(-30, 30))
	Debris:AddItem(casing, 2.5)
	task.delay(2.5, function()
		casingCount -= 1
	end)
	local entry = SoundPlayer.pick(WeaponSounds.casings)
	SoundPlayer.play(entry, casing, { groupName = "Foley", rollOff = 40 })
end

-- Muzzle position of another player's third-person weapon, if it is built.
local function remoteMuzzle(shooter: Player?): Vector3?
	local character = shooter and shooter.Character
	local weapon = character and character:FindFirstChild("LastShiftWorldWeapon")
	local root = weapon and weapon:FindFirstChild("Root")
	local muzzle = root and root:FindFirstChild("Muzzle")
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	return nil
end

-- A gunshot fired by someone else: 3D sound at the shooter, tracer, impact, a quick flash light.
function Effects.remoteShot(fx)
	local def = Weapons[fx.weaponId]
	local set = def and WeaponSounds.weapons[def.sounds]
	local origin = remoteMuzzle(fx.shooter) or fx.origin
	local source = fxPart("RemoteShot")
	source.Position = origin
	Debris:AddItem(source, 2)
	if set then
		for index, layer in set.fire do
			-- Skip the room-tail layer up close; distance already blurs it.
			SoundPlayer.play(layer, source, {
				rollOff = REMOTE_SHOT_ROLLOFF,
				volumeScale = if index == 1 then 1.1 else 0.8,
			})
		end
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 14
	light.Brightness = 4
	light.Parent = source
	Debris:AddItem(light, 0.05)
	Effects.tracer(origin, fx.endpoint, 0.04)
	Effects.impact(fx.endpoint, fx.normal, fx.impact)
end

return Effects
