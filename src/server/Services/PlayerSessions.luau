--[[
	One session per living character. Everything server-side that belongs to "this life"
	(movement mode, weapon state, later health/inventory) hangs off the session table, so a
	respawn starts clean and callbacks from an old life can check `isCurrent` and bail out.

	Every client request goes through `gate`, which returns the session only if the
	character is current and alive and the player is inside their request budget.
]]

local Players = game:GetService("Players")

export type Session = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	movement: string,
	weapon: any?, -- owned by WeaponService
	budget: number,
	budgetTime: number,
}

-- Token bucket shared by all client requests: bursts of BUCKET_SIZE, refilling at REFILL_PER_SECOND.
local BUCKET_SIZE = 24
local REFILL_PER_SECOND = 16
local HUMANOID_TIMEOUT = 10

local PlayerSessions = {}

local sessions: { [Player]: Session } = {}
local startedCallbacks: { (Session) -> () } = {}

function PlayerSessions.onStarted(callback: (Session) -> ())
	table.insert(startedCallbacks, callback)
end

function PlayerSessions.isCurrent(session: Session): boolean
	local player = session.player
	return sessions[player] == session
		and player.Character == session.character
		and session.humanoid.Health > 0
end

function PlayerSessions.get(player: Player): Session?
	local session = sessions[player]
	if session and PlayerSessions.isCurrent(session) then
		return session
	end
	return nil
end

function PlayerSessions.gate(player: Player): Session?
	local session = PlayerSessions.get(player)
	if not session then
		return nil
	end
	local now = os.clock()
	session.budget = math.min(BUCKET_SIZE, session.budget + (now - session.budgetTime) * REFILL_PER_SECOND)
	session.budgetTime = now
	if session.budget < 1 then
		return nil
	end
	session.budget -= 1
	return session
end

local function start(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", HUMANOID_TIMEOUT)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	if player.Character ~= character or player.Parent ~= Players then
		return
	end
	local session: Session = {
		player = player,
		character = character,
		humanoid = humanoid,
		movement = "Walk",
		weapon = nil,
		budget = BUCKET_SIZE,
		budgetTime = os.clock(),
	}
	sessions[player] = session
	for _, callback in startedCallbacks do
		task.spawn(callback, session)
	end
end

local function track(player: Player)
	player.CharacterAdded:Connect(function(character)
		start(player, character)
	end)
	if player.Character then
		task.spawn(start, player, player.Character)
	end
end

-- Call after every service has registered its onStarted callback.
function PlayerSessions.init()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return PlayerSessions
