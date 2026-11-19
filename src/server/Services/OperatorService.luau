--[[
	Operator look: every player character is dressed as a tactical operator, and their equipped
	gun is shown on them for everyone else. Purely cosmetic and server-built so it replicates.

	  - Avatar accessories and clothing are removed; body colours become a field uniform.
	  - Gear parts (helmet with NVG mount and ear pro, plate carrier, pouches, gloves, knee pads,
	    boots) are welded on. They are Massless, CanCollide/CanQuery/CanTouch false, so they never
	    change movement or hit detection.
	  - The equipped weapon (character attribute "EquippedWeapon", set by WeaponService) is built
	    from Visual/WeaponModels and welded to the upper torso in a shouldered position, with the
	    arms posed forward to hold it.

	Works with R15 and R6 rigs. In first person, Roblox already hides your own character's parts,
	so this gear never blocks your view.

	Known limit: the arm pose is a static Motor6D offset; walk animations still swing the arms a
	little. Proper hold/aim animations need Animation assets uploaded to your account.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local Weapons = require(shared:WaitForChild("Data"):WaitForChild("Weapons"))
local WeaponModels = require(shared:WaitForChild("Visual"):WaitForChild("WeaponModels"))

local PlayerSessions = require(script.Parent.PlayerSessions)

local rad = math.rad
local APPEARANCE_TIMEOUT = 8

-- Uniform palette
local SHIRT = Color3.fromRGB(110, 104, 82) -- coyote / ranger green blend
local PANTS = Color3.fromRGB(74, 78, 62)
local GEAR = Color3.fromRGB(86, 82, 64)
local GEAR_DARK = Color3.fromRGB(58, 56, 46)
local BLACK = Color3.fromRGB(28, 28, 28)
local BOOT = Color3.fromRGB(52, 42, 34)
local HELMET = Color3.fromRGB(92, 88, 70)

local OperatorService = {}

local function find(character: Model, ...: string): BasePart?
	for _, name in { ... } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function gearPart(folder: Instance, anchor: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	if shape then
		part.Shape = shape
	end
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

-- Ellipsoid via a Sphere SpecialMesh (the part's box doesn't matter: CanQuery is off).
local function ellipsoid(part: Part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

local function stripAvatar(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if not colors then
		colors = Instance.new("BodyColors")
		colors.Parent = character
	end
	colors.TorsoColor3 = SHIRT
	colors.LeftArmColor3 = SHIRT
	colors.RightArmColor3 = SHIRT
	colors.LeftLegColor3 = PANTS
	colors.RightLegColor3 = PANTS
end

local function dress(character: Model)
	local old = character:FindFirstChild("LastShiftGear")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "LastShiftGear"

	local head = find(character, "Head")
	local torso = find(character, "UpperTorso", "Torso")
	local lowerTorso = find(character, "LowerTorso", "Torso")

	if head then
		local s = head.Size
		local dome = gearPart(folder, head, "Helmet", Vector3.new(s.X * 1.32, s.Y * 0.95, s.Z * 1.42), CFrame.new(0, s.Y * 0.22, 0.02), HELMET, Enum.Material.Fabric)
		ellipsoid(dome)
		gearPart(folder, head, "Helmet rim", Vector3.new(s.X * 1.3, s.Y * 0.1, s.Z * 1.36), CFrame.new(0, s.Y * 0.02, 0.03), GEAR_DARK, Enum.Material.Plastic)
		gearPart(folder, head, "NVG shroud", Vector3.new(s.X * 0.32, s.Y * 0.22, s.Z * 0.12), CFrame.new(0, s.Y * 0.42, -s.Z * 0.7), BLACK, Enum.Material.Metal)
		gearPart(folder, head, "Rail L", Vector3.new(s.X * 0.08, s.Y * 0.16, s.Z * 0.8), CFrame.new(-s.X * 0.64, s.Y * 0.18, 0), BLACK, Enum.Material.Plastic)
		gearPart(folder, head, "Rail R", Vector3.new(s.X * 0.08, s.Y * 0.16, s.Z * 0.8), CFrame.new(s.X * 0.64, s.Y * 0.18, 0), BLACK, Enum.Material.Plastic)
		gearPart(folder, head, "Ear cup L", Vector3.new(s.X * 0.16, s.Y * 0.42, s.Y * 0.42), CFrame.new(-s.X * 0.58, -s.Y * 0.05, 0.02), BLACK, Enum.Material.Plastic, Enum.PartType.Cylinder)
		gearPart(folder, head, "Ear cup R", Vector3.new(s.X * 0.16, s.Y * 0.42, s.Y * 0.42), CFrame.new(s.X * 0.58, -s.Y * 0.05, 0.02), BLACK, Enum.Material.Plastic, Enum.PartType.Cylinder)
		gearPart(folder, head, "Counterweight", Vector3.new(s.X * 0.4, s.Y * 0.22, s.Z * 0.14), CFrame.new(0, s.Y * 0.25, s.Z * 0.7), GEAR_DARK, Enum.Material.Fabric)
	end

	if torso then
		local s = torso.Size
		local plateH = s.Y * (if torso.Name == "Torso" then 0.72 else 0.9)
		local plateY = if torso.Name == "Torso" then s.Y * 0.08 else 0
		gearPart(folder, torso, "Front plate", Vector3.new(s.X * 0.86, plateH, 0.32), CFrame.new(0, plateY, -s.Z / 2 - 0.12), GEAR, Enum.Material.Fabric)
		gearPart(folder, torso, "Back plate", Vector3.new(s.X * 0.86, plateH, 0.3), CFrame.new(0, plateY, s.Z / 2 + 0.11), GEAR, Enum.Material.Fabric)
		gearPart(folder, torso, "Cummerbund L", Vector3.new(0.18, plateH * 0.7, s.Z + 0.3), CFrame.new(-s.X * 0.42, plateY - plateH * 0.12, 0), GEAR_DARK, Enum.Material.Fabric)
		gearPart(folder, torso, "Cummerbund R", Vector3.new(0.18, plateH * 0.7, s.Z + 0.3), CFrame.new(s.X * 0.42, plateY - plateH * 0.12, 0), GEAR_DARK, Enum.Material.Fabric)
		gearPart(folder, torso, "Shoulder strap L", Vector3.new(s.X * 0.18, 0.12, s.Z + 0.5), CFrame.new(-s.X * 0.28, plateY + plateH / 2, 0), GEAR_DARK, Enum.Material.Fabric)
		gearPart(folder, torso, "Shoulder strap R", Vector3.new(s.X * 0.18, 0.12, s.Z + 0.5), CFrame.new(s.X * 0.28, plateY + plateH / 2, 0), GEAR_DARK, Enum.Material.Fabric)
		for i = -1, 1 do
			gearPart(folder, torso, "Mag pouch", Vector3.new(s.X * 0.22, plateH * 0.42, 0.26), CFrame.new(i * s.X * 0.25, plateY - plateH * 0.22, -s.Z / 2 - 0.38), GEAR_DARK, Enum.Material.Fabric)
			gearPart(folder, torso, "Mag in pouch", Vector3.new(s.X * 0.16, plateH * 0.14, 0.16), CFrame.new(i * s.X * 0.25, plateY + plateH * 0.04, -s.Z / 2 - 0.38), BLACK, Enum.Material.Plastic)
		end
		gearPart(folder, torso, "Radio", Vector3.new(0.3, plateH * 0.5, 0.22), CFrame.new(-s.X * 0.3, plateY + plateH * 0.15, s.Z / 2 + 0.36), BLACK, Enum.Material.Plastic)
		gearPart(folder, torso, "Antenna", Vector3.new(0.05, plateH * 0.9, 0.05), CFrame.new(-s.X * 0.36, plateY + plateH * 0.75, s.Z / 2 + 0.36), BLACK, Enum.Material.Rubber)
		gearPart(folder, torso, "Admin pouch", Vector3.new(s.X * 0.4, plateH * 0.25, 0.14), CFrame.new(s.X * 0.1, plateY + plateH * 0.28, -s.Z / 2 - 0.33), GEAR, Enum.Material.Fabric)
	end

	if lowerTorso and lowerTorso ~= torso then
		local s = lowerTorso.Size
		gearPart(folder, lowerTorso, "Belt", Vector3.new(s.X * 1.08, s.Y * 0.45, s.Z * 1.12), CFrame.new(0, s.Y * 0.1, 0), GEAR_DARK, Enum.Material.Fabric)
		gearPart(folder, lowerTorso, "Holster", Vector3.new(0.28, s.Y * 1.2, 0.5), CFrame.new(s.X * 0.62, -s.Y * 0.3, 0), BLACK, Enum.Material.Plastic)
		gearPart(folder, lowerTorso, "IFAK", Vector3.new(0.4, s.Y * 0.7, 0.3), CFrame.new(-s.X * 0.2, 0, s.Z * 0.62), Color3.fromRGB(120, 40, 34), Enum.Material.Fabric)
	end

	for _, name in { "LeftHand", "RightHand" } do
		local hand = find(character, name)
		if hand then
			gearPart(folder, hand, "Glove", hand.Size * 1.12, CFrame.identity, BLACK, Enum.Material.Fabric)
		end
	end
	for _, pair in { { "LeftLowerLeg", "Left Leg" }, { "RightLowerLeg", "Right Leg" } } do
		local leg = find(character, pair[1], pair[2])
		if leg then
			local s = leg.Size
			local kneeY = if leg.Name == pair[1] then s.Y * 0.32 else -s.Y * 0.05
			gearPart(folder, leg, "Knee pad", Vector3.new(s.X * 0.9, s.Y * 0.3, 0.22), CFrame.new(0, kneeY, -s.Z / 2 - 0.06), BLACK, Enum.Material.Rubber)
		end
	end
	for _, pair in { { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } } do
		local foot = find(character, pair[1], pair[2])
		if foot then
			local s = foot.Size
			local isR6 = foot.Name == pair[2]
			local size = if isR6 then Vector3.new(s.X * 1.08, s.Y * 0.25, s.Z * 1.25) else s * Vector3.new(1.1, 1.15, 1.2)
			local offset = if isR6 then CFrame.new(0, -s.Y * 0.4, -s.Z * 0.1) else CFrame.new(0, 0, -s.Z * 0.06)
			gearPart(folder, foot, "Boot", size, offset, BOOT, Enum.Material.Leather)
		end
	end

	folder.Parent = character
end

-- Arm pose that brings the hands up to a shouldered weapon. Applied once to the shoulder joints'
-- C0, so animations still play on top of it.
local function poseArms(character: Model)
	if character:GetAttribute("LastShiftArmsPosed") then
		return
	end
	local upper = find(character, "UpperTorso")
	if upper then
		local right = find(character, "RightUpperArm")
		local left = find(character, "LeftUpperArm")
		local rightShoulder = right and right:FindFirstChild("RightShoulder")
		local leftShoulder = left and left:FindFirstChild("LeftShoulder")
		if rightShoulder and rightShoulder:IsA("Motor6D") then
			rightShoulder.C0 *= CFrame.Angles(rad(80), 0, rad(8))
		end
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.C0 *= CFrame.Angles(rad(85), rad(-35), rad(-10))
		end
	else
		local torso = find(character, "Torso")
		local right = torso and torso:FindFirstChild("Right Shoulder")
		local left = torso and torso:FindFirstChild("Left Shoulder")
		if right and right:IsA("Motor6D") then
			right.C0 *= CFrame.Angles(0, 0, rad(80))
		end
		if left and left:IsA("Motor6D") then
			left.C0 *= CFrame.Angles(rad(-20), 0, rad(-80))
		end
	end
	character:SetAttribute("LastShiftArmsPosed", true)
end

local function showWeapon(character: Model)
	local old = character:FindFirstChild("LastShiftWorldWeapon")
	if old then
		old:Destroy()
	end
	local def = Weapons[character:GetAttribute("EquippedWeapon")]
	local torso = find(character, "UpperTorso", "Torso")
	if not def or not torso or not WeaponModels.has(def.model) then
		return
	end
	local built = WeaponModels.build(def.model)
	local model = built.model
	model.Name = "LastShiftWorldWeapon"
	-- Third-person models are a little larger than the viewmodel so they read at distance.
	local scale = if def.model == "HandCannon" then 1.25 else 1.5
	model:ScaleTo(scale)
	local grip = WeaponModels.attachment(built, "Grip")
	-- Shouldered: right of centre, chest high, pointing where the character faces.
	local s = torso.Size
	local mount = CFrame.new(s.X * 0.32, s.Y * 0.18, -s.Z / 2 - 0.9) * CFrame.Angles(rad(-4), rad(3), 0)
	model:PivotTo(torso.CFrame * mount * CFrame.new(-grip.Position))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = part:GetAttribute("Group") ~= "Flash"
			if part ~= built.root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = built.root
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = built.root
	weld.Parent = built.root
	model.Parent = character
	poseArms(character)
end

local function setup(session: PlayerSessions.Session)
	local player, character = session.player, session.character
	if not player:HasAppearanceLoaded() then
		local loaded = false
		local connection = player.CharacterAppearanceLoaded:Connect(function()
			loaded = true
		end)
		local deadline = os.clock() + APPEARANCE_TIMEOUT
		while not loaded and os.clock() < deadline and character.Parent do
			task.wait(0.1)
		end
		connection:Disconnect()
	end
	if not PlayerSessions.isCurrent(session) then
		return
	end
	stripAvatar(character)
	dress(character)
	showWeapon(character)
	-- Late accessories (some avatars stream in after load).
	character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			task.defer(function()
				child:Destroy()
			end)
		end
	end)
	character:GetAttributeChangedSignal("EquippedWeapon"):Connect(function()
		showWeapon(character)
	end)
end

function OperatorService.init()
	PlayerSessions.onStarted(function(session)
		setup(session)
	end)
end

return OperatorService
