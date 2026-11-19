--[[
	Crouch and prone movement sounds for every character this client can hear.

	The server publishes each character's stance as the "Stance" attribute (MovementService).
	While a character is crouched or prone this mutes Roblox's default "Running" footstep loop on
	it (a local volume change, restored on standing) and plays Data/StanceSounds steps instead:
	soft padded steps when crouched, cloth crawl when prone. Steps space out when moving slower
	than the stance's full speed and stop in the air or when standing still.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local data = shared:WaitForChild("Data")
local Movement = require(data:WaitForChild("Movement"))
local StanceSoundData = require(data:WaitForChild("StanceSounds"))

local SoundPlayer = require(script.Parent:WaitForChild("SoundPlayer"))

local MIN_MOVE_SPEED = 0.6
local FIRST_STEP_DELAY = 0.08
local MAX_INTERVAL_SCALE = 2.5

type Tracked = {
	humanoid: Humanoid,
	root: BasePart,
	timer: number,
	running: Sound?,
	savedVolume: number?,
}

local StanceSounds = {}

local tracked: { [Model]: Tracked } = {}
local random = Random.new()

local function setDefaultFootsteps(state: Tracked, muted: boolean)
	local running = state.running
	if not running or running.Parent == nil then
		local found = state.root:FindFirstChild("Running")
		running = if found and found:IsA("Sound") then found else nil
		state.running = running
	end
	if not running then
		return
	end
	if muted then
		if state.savedVolume == nil then
			state.savedVolume = running.Volume
		end
		running.Volume = 0
	elseif state.savedVolume ~= nil then
		running.Volume = state.savedVolume
		state.savedVolume = nil
	end
end

local function step(state: Tracked, sounds)
	SoundPlayer.play(SoundPlayer.pick(sounds.steps), state.root, { groupName = "Foley", rollOff = sounds.rollOff })
	if sounds.gear and random:NextNumber() < sounds.gearChance then
		SoundPlayer.play(SoundPlayer.pick(sounds.gear), state.root, { groupName = "Foley", rollOff = sounds.rollOff })
	end
end

local function update(model: Model, state: Tracked, dt: number)
	local stance = model:GetAttribute("Stance")
	local sounds = if type(stance) == "string" then StanceSoundData[stance] else nil
	if not sounds or state.humanoid.Health <= 0 then
		setDefaultFootsteps(state, false)
		state.timer = FIRST_STEP_DELAY
		return
	end
	setDefaultFootsteps(state, true)

	local velocity = state.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed < MIN_MOVE_SPEED or state.humanoid.FloorMaterial == Enum.Material.Air then
		state.timer = FIRST_STEP_DELAY
		return
	end
	state.timer -= dt
	if state.timer <= 0 then
		step(state, sounds)
		local fullSpeed = Movement.speed[stance] or speed
		state.timer = sounds.interval * math.clamp(fullSpeed / speed, 1, MAX_INTERVAL_SCALE)
	end
end

local function track(model: Model)
	local humanoid = model:WaitForChild("Humanoid", 10)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end
	if model.Parent == nil then
		return
	end
	tracked[model] = { humanoid = humanoid, root = root, timer = FIRST_STEP_DELAY, running = nil, savedVolume = nil }
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			tracked[model] = nil
		end
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(track)
	if player.Character then
		task.spawn(track, player.Character)
	end
end

function StanceSounds.init()
	local all = {}
	for _, sounds in StanceSoundData do
		for _, entry in sounds.steps do
			table.insert(all, entry)
		end
		for _, entry in sounds.gear or {} do
			table.insert(all, entry)
		end
	end
	SoundPlayer.preload(all)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	RunService.Heartbeat:Connect(function(dt)
		for model, state in tracked do
			update(model, state, dt)
		end
	end)
end

return StanceSounds
