--[[
	Test-range feedback on this client, from the server's ShotResult only:
	  - floating damage numbers at the hit point, coloured by armor outcome
	  - a brief flash on the target that was hit
	  - the accuracy board by the firing line (Dressing.Stations.StatsBoard): shots, hits,
	    accuracy, headshots, longest hit and the last few hits

	Shots are counted when the server answers, so the numbers match what the server decided.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local OUTCOME_COLORS = {
	None = Color3.fromRGB(255, 236, 200),
	Penetrated = Color3.fromRGB(255, 120, 92),
	Reduced = Color3.fromRGB(250, 193, 107),
	Stopped = Color3.fromRGB(105, 199, 255),
}
local FLOAT_INFO = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLASH_TIME = 0.08
local RECENT = 6

local HitFeedback = {}
HitFeedback.__index = HitFeedback

local function boardLabel(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3, align: Enum.TextXAlignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.Code
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = align
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = parent
	return label
end

function HitFeedback.new(playerGui: PlayerGui)
	local self = setmetatable({}, HitFeedback)
	self.shots = 0
	self.hits = 0
	self.headshots = 0
	self.longest = 0
	self.recent = {}
	self.flashes = {}

	-- The board's SurfaceGui lives in PlayerGui (adorned to the board part) so it is per-player.
	task.spawn(function()
		local range = Workspace:WaitForChild("LastShiftRange", 30)
		local dressing = range and range:WaitForChild("Dressing", 30)
		local stations = dressing and dressing:WaitForChild("Stations", 30)
		local board = stations and stations:WaitForChild("StatsBoard", 30)
		if not board or not board:IsA("BasePart") then
			return
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = "LastShiftStatsBoard"
		gui.Adornee = board
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(10, 14, 12)
		bg.BorderSizePixel = 0
		bg.Parent = gui
		boardLabel(bg, "Title", UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.92, 0.12), Color3.fromRGB(232, 196, 120), Enum.TextXAlignment.Left).Text = "YOUR SHOOTING"
		self.summary = boardLabel(bg, "Summary", UDim2.fromScale(0.04, 0.2), UDim2.fromScale(0.92, 0.24), Color3.fromRGB(200, 230, 210), Enum.TextXAlignment.Left)
		self.recentLabel = boardLabel(bg, "Recent", UDim2.fromScale(0.04, 0.48), UDim2.fromScale(0.92, 0.48), Color3.fromRGB(170, 180, 184), Enum.TextXAlignment.Left)
		gui.Parent = playerGui
		self:_refresh()
	end)
	return self
end

function HitFeedback:_refresh()
	if not self.summary then
		return
	end
	local accuracy = if self.shots > 0 then math.floor(self.hits / self.shots * 100 + 0.5) else 0
	self.summary.Text = ("Shots %d   Hits %d   Accuracy %d%%\nHeadshots %d   Longest hit %d studs"):format(
		self.shots,
		self.hits,
		accuracy,
		self.headshots,
		math.floor(self.longest)
	)
	self.recentLabel.Text = table.concat(self.recent, "\n")
end

local function findTarget(name: string?): Model?
	if not name then
		return nil
	end
	local range = Workspace:FindFirstChild("LastShiftRange")
	local targets = range and range:FindFirstChild("Targets")
	local model = targets and targets:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

function HitFeedback:_flash(model: Model, color: Color3)
	local highlight = self.flashes[model]
	if not highlight or not highlight.Parent then
		highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.OutlineTransparency = 1
		highlight.Adornee = model
		highlight.Parent = model
		self.flashes[model] = highlight
	end
	highlight.FillColor = color
	highlight.FillTransparency = 0.45
	highlight.Enabled = true
	local stamp = os.clock()
	highlight:SetAttribute("Stamp", stamp)
	task.delay(FLASH_TIME, function()
		if highlight:GetAttribute("Stamp") == stamp then
			highlight.Enabled = false
		end
	end)
end

local function floatNumber(position: Vector3, text: string, color: Color3, big: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(if big then 220 else 160, if big then 44 else 32)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = billboard
	billboard.Parent = anchor
	anchor.Parent = Workspace
	TweenService:Create(billboard, FLOAT_INFO, { StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0) }):Play()
	TweenService:Create(label, FLOAT_INFO, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end

function HitFeedback:onShot(result)
	self.shots += 1
	if result.surface == "Target" then
		self.hits += 1
		if result.zone == "Head" then
			self.headshots += 1
		end
		self.longest = math.max(self.longest, result.distance)
		local outcome = result.armor or "None"
		local color = OUTCOME_COLORS[outcome] or OUTCOME_COLORS.None
		local text = if result.lethal
			then "KILL"
			elseif outcome == "Stopped" then "STOPPED"
			else ("-%d"):format(result.damage)
		floatNumber(result.endpoint, text, color, result.lethal == true)
		local model = findTarget(result.targetName)
		if model then
			self:_flash(model, if result.damage > 0 then Color3.fromRGB(255, 90, 70) else Color3.fromRGB(120, 200, 255))
		end
		local name = string.match(result.targetName, "^(%S+)") or result.targetName
		table.insert(self.recent, 1, ("%-4s %-5s %3d dmg  %-10s %4.0f st"):format(
			name,
			string.upper(result.zone),
			result.damage,
			string.upper(outcome),
			result.distance
		))
		if #self.recent > RECENT then
			table.remove(self.recent)
		end
	end
	self:_refresh()
end

function HitFeedback:resetStats()
	self.shots, self.hits, self.headshots, self.longest = 0, 0, 0, 0
	table.clear(self.recent)
	self:_refresh()
end

return HitFeedback
