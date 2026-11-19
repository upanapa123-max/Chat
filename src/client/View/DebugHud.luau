--[[
	Developer HUD for balancing and troubleshooting combat. Everything it shows about ammo,
	hits, damage and armor comes from server messages (WeaponState / ShotResult).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local data = shared:WaitForChild("Data")
local Ammo = require(data:WaitForChild("Ammo"))
local Calibers = require(data:WaitForChild("Calibers"))

local AMBER = Color3.fromRGB(250, 193, 107)
local WHITE = Color3.fromRGB(239, 239, 229)
local GRAY = Color3.fromRGB(170, 180, 184)
local OUTCOME_COLORS = {
	None = WHITE,
	Penetrated = Color3.fromRGB(255, 120, 92),
	Reduced = AMBER,
	Stopped = Color3.fromRGB(105, 199, 255),
}
local SEP = "   ·   "

local DebugHud = {}
DebugHud.__index = DebugHud

local function label(parent: Instance, name: string, y: number, height: number, size: number, color: Color3)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Position = UDim2.fromOffset(14, y)
	text.Size = UDim2.new(1, -28, 0, height)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamMedium
	text.TextSize = size
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = ""
	text.Parent = parent
	return text
end

local function shortName(ammoId: string?): string
	local def = ammoId and Ammo[ammoId]
	return if def then def.shortName else tostring(ammoId)
end

function DebugHud.new(player: Player, def)
	local self = setmetatable({}, DebugHud)
	self.def = def
	local caliber = Calibers[def.caliber]

	local gui = Instance.new("ScreenGui")
	gui.Name = "LastShiftDebug"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 20, 1, -20)
	panel.Size = UDim2.fromOffset(540, 196)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 25)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = gui

	label(panel, "Weapon", 9, 22, 17, AMBER).Text = def.displayName .. SEP .. caliber.displayName
	self.ammo = label(panel, "Ammo", 33, 20, 15, WHITE)
	self.reserve = label(panel, "Reserve", 53, 18, 13, GRAY)
	self.hit = label(panel, "Hit", 77, 19, 15, WHITE)
	self.armor = label(panel, "Armor", 97, 18, 13, WHITE)
	self.target = label(panel, "Target", 116, 18, 13, GRAY)

	label(panel, "Controls", 146, 16, 12, GRAY).Text =
		"LMB Fire" .. SEP .. "RMB ADS" .. SEP .. "R Reload" .. SEP .. "Shift Sprint" .. SEP .. "C Crouch"
	local keys = {}
	for index, ammoId in caliber.ammo do
		table.insert(keys, ("%d %s"):format(index, shortName(ammoId)))
	end
	label(panel, "AmmoKeys", 164, 16, 12, GRAY).Text = table.concat(keys, SEP) .. SEP .. "R loads the selected type"

	local dot = Instance.new("Frame")
	dot.Name = "Crosshair"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BorderSizePixel = 0
	dot.Parent = gui
	self.dot = dot

	self:reset()
	return self
end

function DebugHud:reset()
	self.ammo.Text = "Waiting for server..."
	self.reserve.Text = ""
	self.hit.Text = "Hit —"
	self.hit.TextColor3 = WHITE
	self.armor.Text = "Armor —"
	self.armor.TextColor3 = WHITE
	self.target.Text = ""
	self.dot.Visible = false
	self.dot.BackgroundColor3 = WHITE
end

function DebugHud:setCrosshairVisible(visible: boolean)
	self.dot.Visible = visible
end

function DebugHud:setWeaponState(state)
	local text = ("%s   %02d / %d   (reserve %d)"):format(
		shortName(state.loadedAmmo),
		state.magazine,
		state.capacity,
		state.reserve[state.loadedAmmo] or 0
	)
	if state.selectedAmmo ~= state.loadedAmmo then
		text ..= SEP .. ("Next: %s — press R"):format(shortName(state.selectedAmmo))
	end
	if state.reloading then
		text ..= SEP .. "RELOADING"
	end
	self.ammo.Text = text

	local parts = {}
	for _, ammoId in Calibers[self.def.caliber].ammo do
		table.insert(parts, ("%s %d"):format(shortName(ammoId), state.reserve[ammoId] or 0))
	end
	self.reserve.Text = "Reserve   " .. table.concat(parts, SEP)
end

function DebugHud:showShot(result)
	local ammoName = shortName(result.ammoId)
	if result.surface ~= "Target" then
		self.hit.Text = ("%s%s%s"):format(if result.surface == "World" then "Hit wall" else "Miss", SEP, ammoName)
		self.hit.TextColor3 = GRAY
		self.armor.Text = "Armor —"
		self.armor.TextColor3 = GRAY
		self.target.Text = ("%.1f studs"):format(result.distance)
		self.dot.BackgroundColor3 = WHITE
		return
	end

	local outcome = result.armor
	self.hit.Text = ("%s%s%d damage%s%s"):format(
		string.upper(result.zone),
		SEP,
		result.damage,
		if result.lethal then SEP .. "LETHAL" else "",
		SEP .. ammoName
	)
	self.hit.TextColor3 = if result.damage > 0 then WHITE else GRAY

	if outcome == "None" then
		self.armor.Text = ("No armor on %s"):format(result.zone)
	else
		self.armor.Text = ("%s (protection %d) vs %s (penetration %d)  →  %s"):format(
			result.armorName,
			result.protection,
			ammoName,
			result.penetration,
			string.upper(outcome)
		)
	end
	self.armor.TextColor3 = OUTCOME_COLORS[outcome] or WHITE

	self.target.Text = ("%s%s%d / %d HP%s%.1f studs%sfalloff %d%%"):format(
		result.targetName,
		SEP,
		math.max(0, result.health),
		result.maxHealth,
		SEP,
		result.distance,
		SEP,
		math.floor(result.falloffScale * 100 + 0.5)
	)
	self.dot.BackgroundColor3 = if result.damage > 0
		then Color3.fromRGB(255, 165, 101)
		elseif outcome == "Stopped" then OUTCOME_COLORS.Stopped
		else WHITE
end

return DebugHud
