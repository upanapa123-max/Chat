--[[
	Server-owned movement mode and WalkSpeed. The client only *requests* a mode.
	Full movement-integrity checks (speed hacks, pose replication) are a later milestone.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local Movement = require(shared:WaitForChild("Data"):WaitForChild("Movement"))
local PlayerSessions = require(script.Parent.PlayerSessions)

local MovementService = {}

function MovementService.apply(session: PlayerSessions.Session, mode: string)
	session.movement = mode
	session.humanoid.WalkSpeed = Movement.speed[mode]
end

function MovementService.init(remotes: { [string]: RemoteEvent })
	PlayerSessions.onStarted(function(session)
		MovementService.apply(session, "Walk")
	end)

	remotes.SetMovement.OnServerEvent:Connect(function(player, mode)
		local session = PlayerSessions.gate(player)
		if not session or typeof(mode) ~= "string" or Movement.speed[mode] == nil then
			return
		end
		if session.movement ~= mode then
			MovementService.apply(session, mode)
		end
	end)
end

return MovementService
