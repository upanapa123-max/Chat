--[[
	Test-range interactions, all server-side through ProximityPrompts:

	  Range console    select an armor-lane target, cycle its helmet / body armor, reset targets
	  Ammo crate       refill every weapon's reserves
	  Weapon rack      take any loadout weapon (same as Q / wheel, but you can see them)
	  Mover            slides the aim-trainer dummy back and forth

	Every prompt goes through PlayerSessions.gate (live character + rate limit) and a distance
	check against the prompt's part, so it can't be triggered from across the map by an exploit.
	The geometry (console, crate, rack) comes from Dressing.project.json; prompts are added here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local data = shared:WaitForChild("Data")
local Armor = require(data:WaitForChild("Armor"))
local Weapons = require(data:WaitForChild("Weapons"))
local Loadout = require(data:WaitForChild("Loadout"))
local WeaponModels = require(shared:WaitForChild("Visual"):WaitForChild("WeaponModels"))

local PlayerSessions = require(script.Parent.PlayerSessions)
local TargetService = require(script.Parent.TargetService)
local WeaponService = require(script.Parent.WeaponService)

local PROMPT_DISTANCE = 9
local DISTANCE_SLACK = 4 -- extra studs allowed for latency
local MOVER_SPEED = 0.15 -- full left-right sweeps per second
local MOVER_SWEEP = 8 -- studs either side of the start position

local RangeService = {}

local selected = 1
local consoleLabel: TextLabel? = nil
local highlight: Highlight? = nil

local function armorLaneTargets(): { [number]: Model }
	local lane = {}
	for _, model in TargetService.targets() do
		local index = model:GetAttribute("ArmorLane")
		if typeof(index) == "number" then
			lane[index] = model
		end
	end
	return lane
end

local function armorName(id: unknown): string
	local def = typeof(id) == "string" and Armor.definitions[id]
	return if def then def.displayName else "none"
end

local function refreshConsole()
	local lane = armorLaneTargets()
	local model = lane[selected]
	if consoleLabel then
		consoleLabel.Text = if model
			then ("TARGET A%d\nHelmet: %s\nBody: %s"):format(
				selected,
				armorName(model:GetAttribute("Helmet")),
				armorName(model:GetAttribute("BodyArmor"))
			)
			else "NO ARMOR LANE TARGETS"
	end
	if highlight then
		highlight.Adornee = model
	end
end

-- Wraps a prompt handler with the session gate and a server-side distance check.
local function guarded(prompt: ProximityPrompt, handler: (PlayerSessions.Session) -> ())
	prompt.Triggered:Connect(function(player)
		local session = PlayerSessions.gate(player)
		local part = prompt.Parent
		local position = if part and part:IsA("Attachment")
			then part.WorldPosition
			elseif part and part:IsA("BasePart") then part.Position
			else nil
		local root = session and session.character:FindFirstChild("HumanoidRootPart")
		if not session or not position or not root or not root:IsA("BasePart") then
			return
		end
		if (root.Position - position).Magnitude > prompt.MaxActivationDistance + DISTANCE_SLACK then
			return
		end
		handler(session)
	end)
end

local function prompt(parent: Instance, action: string, object: string, key: Enum.KeyCode, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = PROMPT_DISTANCE
	p.RequiresLineOfSight = false
	-- Default exclusivity shows only one prompt per key, so nearby E prompts hid each other.
	p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	p.Parent = parent
	return p
end

local function attachmentAt(part: BasePart, offset: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = offset
	a.Parent = part
	return a
end

local function setupConsole(console: BasePart)
	local s = console.Size
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(8, 14, 12)
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Code
	label.TextColor3 = Color3.fromRGB(120, 230, 160)
	label.TextScaled = true
	label.Rotation = 180
	label.Parent = gui
	gui.Parent = console
	consoleLabel = label

	local h = Instance.new("Highlight")
	h.FillTransparency = 0.85
	h.FillColor = Color3.fromRGB(120, 200, 255)
	h.OutlineColor = Color3.fromRGB(120, 200, 255)
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = console
	highlight = h

	local y = s.Y / 2 + 0.3
	guarded(prompt(attachmentAt(console, Vector3.new(-s.X * 0.35, y, 0)), "Next target", "Range console", Enum.KeyCode.E), function()
		local lane = armorLaneTargets()
		local count = 0
		for _ in lane do
			count += 1
		end
		if count > 0 then
			selected = selected % count + 1
			refreshConsole()
		end
	end)
	guarded(prompt(attachmentAt(console, Vector3.new(-s.X * 0.12, y, 0)), "Cycle helmet", "Selected target", Enum.KeyCode.F), function()
		local model = armorLaneTargets()[selected]
		if model then
			TargetService.cycleArmor(model, "Head")
			refreshConsole()
		end
	end)
	guarded(prompt(attachmentAt(console, Vector3.new(s.X * 0.12, y, 0)), "Cycle body armor", "Selected target", Enum.KeyCode.G), function()
		local model = armorLaneTargets()[selected]
		if model then
			TargetService.cycleArmor(model, "Torso")
			refreshConsole()
		end
	end)
	guarded(prompt(attachmentAt(console, Vector3.new(s.X * 0.35, y, 0)), "Reset all targets", "Range console", Enum.KeyCode.H, 0.4), function()
		TargetService.resetAll()
	end)
	refreshConsole()
end

local function setupCrate(crate: BasePart)
	local top = attachmentAt(crate, Vector3.new(0, crate.Size.Y / 2 + 0.6, 0))
	guarded(prompt(top, "Refill ammo", "Ammo crate", Enum.KeyCode.T), function(session)
		WeaponService.refill(session)
	end)
end

-- Display copies of every loadout weapon on the rack, each with a "Take" prompt.
local function setupRack(rack: BasePart)
	local count = #Loadout.weapons
	for i, weaponId in Loadout.weapons do
		local def = Weapons[weaponId]
		if def and WeaponModels.has(def.model) then
			local built = WeaponModels.build(def.model)
			built.model.Name = "Display " .. def.displayName
			built.model:ScaleTo(1.6)
			-- One gun per peg row, lying sideways in front of the board.
			local y = rack.Size.Y / 2 - (i - 0.5) * (rack.Size.Y / count)
			built.model:PivotTo(rack.CFrame * CFrame.new(0, y, -rack.Size.Z / 2 - 0.3) * CFrame.Angles(0, math.rad(90), 0))
			for _, part in built.model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanQuery = false
				end
			end
			built.model.Parent = rack
			local spot = attachmentAt(rack, Vector3.new(0, y, -rack.Size.Z / 2 - 0.6))
			guarded(prompt(spot, "Take", def.displayName, Enum.KeyCode.E), function(session)
				WeaponService.equipById(session, weaponId)
			end)
		end
	end
end

local function startMovers()
	local movers = {}
	for _, model in TargetService.targets() do
		if model:GetAttribute("Mover") then
			table.insert(movers, { model = model, origin = model:GetPivot() })
		end
	end
	if #movers == 0 then
		return
	end
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		for i, mover in movers do
			local offset = math.sin(t * MOVER_SPEED * math.pi * 2 + i) * MOVER_SWEEP
			mover.model:PivotTo(mover.origin * CFrame.new(offset, 0, 0))
		end
	end)
end

function RangeService.init()
	local range = Workspace:WaitForChild("LastShiftRange")
	local stations = range:WaitForChild("Dressing"):WaitForChild("Stations", 10)
	if stations then
		local console = stations:FindFirstChild("RangeConsole")
		local crate = stations:FindFirstChild("AmmoCrate")
		local rack = stations:FindFirstChild("WeaponRack")
		if console and console:IsA("BasePart") then
			setupConsole(console)
		end
		if crate and crate:IsA("BasePart") then
			setupCrate(crate)
		end
		if rack and rack:IsA("BasePart") then
			setupRack(rack)
		end
	else
		warn("[LastShift] Range stations missing; console, ammo crate and rack are disabled")
	end
	startMovers()
end

return RangeService
