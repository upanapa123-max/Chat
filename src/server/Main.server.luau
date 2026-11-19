--[[
	Server bootstrap. Order matters:
	  1. remotes exist before any handler connects
	  2. services register their PlayerSessions.onStarted callbacks
	  3. PlayerSessions.init() starts tracking players last, so callbacks see every spawn
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local Net = require(shared:WaitForChild("Net"))

local services = script.Parent:WaitForChild("Services")
local PlayerSessions = require(services:WaitForChild("PlayerSessions"))
local TargetService = require(services:WaitForChild("TargetService"))
local MovementService = require(services:WaitForChild("MovementService"))
local WeaponService = require(services:WaitForChild("WeaponService"))
local OperatorService = require(services:WaitForChild("OperatorService"))

local remotes = Net.create(shared)

TargetService.init()
MovementService.init(remotes)
WeaponService.init(remotes)
OperatorService.init()
PlayerSessions.init()
