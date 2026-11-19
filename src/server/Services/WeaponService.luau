--[[
	Server-authoritative weapons: magazine and reserve counts, ammo selection, reloads,
	fire cadence, shot origin, spread, raycast and hit resolution.

	The client sends only an aim direction. The server decides:
	  - whether the shot is allowed (alive, not reloading, not sprinting, ammo, cadence)
	  - where it starts (the eye for the current stance, from MovementService)
	  - where it goes (aim + server-random spread)
	  - what it hits and how much damage it does (TargetService / Combat.Damage)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LastShift")
local data = shared:WaitForChild("Data")
local Weapons = require(data:WaitForChild("Weapons"))
local Ammo = require(data:WaitForChild("Ammo"))
local Calibers = require(data:WaitForChild("Calibers"))
local Movement = require(data:WaitForChild("Movement"))
local Loadout = require(data:WaitForChild("Loadout"))
local Spread = require(shared:WaitForChild("Combat"):WaitForChild("Spread"))

local PlayerSessions = require(script.Parent.PlayerSessions)
local MovementService = require(script.Parent.MovementService)
local TargetService = require(script.Parent.TargetService)

-- Accept shots slightly faster than fireInterval so network jitter on legit clicks isn't rejected.
local CADENCE_TOLERANCE = 0.85
local AIM_UNIT_TOLERANCE = 0.01

type WeaponState = {
	def: Weapons.WeaponDef,
	allowedAmmo: { [string]: boolean },
	loaded: string,
	selected: string,
	magazine: number,
	reserve: { [string]: number },
	reloading: boolean,
	reloadToken: number, -- bumped to cancel a pending reload (weapon switched away)
	readyAt: number, -- os.clock() before which the weapon can't fire (equip time)
	lastShot: number,
}

local WeaponService = {}

local remotes: { [string]: RemoteEvent } = {}
local random = Random.new()

local function newWeaponState(weaponId: string): WeaponState
	local def = Weapons[weaponId]
	assert(def, "Unknown weapon " .. weaponId)
	local reserve = {}
	local allowed = {}
	for _, ammoId in Calibers[def.caliber].ammo do
		reserve[ammoId] = def.startingReserve
		allowed[ammoId] = true
	end
	return {
		def = def,
		allowedAmmo = allowed,
		loaded = def.defaultAmmo,
		selected = def.defaultAmmo,
		magazine = def.magazineCapacity,
		reserve = reserve,
		reloading = false,
		reloadToken = 0,
		readyAt = 0,
		lastShot = -math.huge,
	}
end

local function setWorldWeapon(session: PlayerSessions.Session)
	-- Read by OperatorService to show the gun on the character for everyone else.
	session.character:SetAttribute("EquippedWeapon", session.weapon.def.id)
end

local function publish(session: PlayerSessions.Session)
	local weapon: WeaponState = session.weapon
	remotes.WeaponState:FireClient(session.player, {
		weaponId = weapon.def.id,
		loadedAmmo = weapon.loaded,
		selectedAmmo = weapon.selected,
		magazine = weapon.magazine,
		capacity = weapon.def.magazineCapacity,
		reserve = table.clone(weapon.reserve),
		reloading = weapon.reloading,
	})
end

local function fire(session: PlayerSessions.Session, aim: unknown)
	local weapon: WeaponState = session.weapon
	local def = weapon.def
	local now = os.clock()

	if weapon.reloading or weapon.magazine <= 0 or session.movement == "Sprint" or now < weapon.readyAt then
		return
	end
	if not MovementService.canFire(session) then
		return
	end
	if now - weapon.lastShot < def.fireInterval * CADENCE_TOLERANCE then
		return
	end
	-- Written as `not (x < tol)` so NaN vectors are rejected too.
	if typeof(aim) ~= "Vector3" or not (math.abs(aim.Magnitude - 1) < AIM_UNIT_TOLERANCE) then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { session.character }
	-- So rays still hit prone bodies, whose parts don't collide with "Default".
	params.CollisionGroup = MovementService.HITSCAN_GROUP

	local origin = MovementService.shotOrigin(session, params)
	if not origin then
		return
	end

	weapon.lastShot = now
	weapon.magazine -= 1

	local spread = if Movement.isAiming(session.movement) then def.spread.ads else def.spread.hip
	local direction = Spread.apply(aim, spread, random)
	local hit = Workspace:Raycast(origin, direction * def.maxRange, params)
	local endpoint = if hit then hit.Position else origin + direction * def.maxRange

	publish(session)

	local shot = {
		endpoint = endpoint,
		surface = "Miss",
		ammoId = weapon.loaded,
		distance = if hit then hit.Distance else def.maxRange,
		normal = if hit then hit.Normal else nil,
		impact = "Miss",
	}
	if hit then
		local model, zone = TargetService.fromInstance(hit.Instance)
		if model and zone then
			local report = TargetService.applyHit(model, zone, Ammo[weapon.loaded], hit.Distance)
			for key, value in report do
				shot[key] = value
			end
			shot.surface = "Target"
			shot.impact = TargetService.impactKind(model, report)
		else
			shot.surface = "World"
			shot.impact = "World"
		end
	end
	remotes.ShotResult:FireClient(session.player, shot)

	-- Everyone else hears and sees the shot. Cosmetic only: no damage data.
	local fx = {
		shooter = session.player,
		weaponId = def.id,
		origin = origin,
		endpoint = endpoint,
		normal = shot.normal,
		impact = shot.impact,
	}
	for _, other in Players:GetPlayers() do
		if other ~= session.player then
			remotes.ShotFx:FireClient(other, fx)
		end
	end
end

local function reload(session: PlayerSessions.Session)
	local weapon: WeaponState = session.weapon
	local capacity = weapon.def.magazineCapacity
	local selected = weapon.selected
	if weapon.reloading or (weapon.reserve[selected] or 0) <= 0 then
		return
	end
	if selected == weapon.loaded and weapon.magazine >= capacity then
		return
	end

	weapon.reloading = true
	weapon.reloadToken += 1
	local token = weapon.reloadToken
	publish(session)

	task.delay(weapon.def.reloadTime, function()
		if not PlayerSessions.isCurrent(session) or session.weapon ~= weapon or weapon.reloadToken ~= token then
			return
		end
		-- Whole-magazine swap: leftover rounds go back to their own reserve.
		weapon.reserve[weapon.loaded] += weapon.magazine
		weapon.magazine = math.min(capacity, weapon.reserve[selected])
		weapon.reserve[selected] -= weapon.magazine
		weapon.loaded = selected
		weapon.reloading = false
		publish(session)
	end)
end

local function selectAmmo(session: PlayerSessions.Session, ammoId: unknown)
	local weapon: WeaponState = session.weapon
	if typeof(ammoId) ~= "string" or not weapon.allowedAmmo[ammoId] or weapon.reloading then
		return
	end
	if weapon.selected ~= ammoId then
		weapon.selected = ammoId
		publish(session)
	end
end

local function equipId(session: PlayerSessions.Session, weaponId: string?)
	local target = weaponId and session.weapons[weaponId]
	local current: WeaponState = session.weapon
	if not target or target == current then
		return
	end
	-- Switching away abandons a reload in progress; the magazine is left as it was.
	if current.reloading then
		current.reloading = false
		current.reloadToken += 1
	end
	target.readyAt = os.clock() + target.def.equipTime
	session.weapon = target
	setWorldWeapon(session)
	publish(session)
end

local function equip(session: PlayerSessions.Session, slot: unknown)
	if typeof(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 then
		return
	end
	equipId(session, Loadout.weapons[slot])
end

-- Wraps a handler so it only runs for a gated session that has a weapon.
local function armed(handler: (PlayerSessions.Session, ...any) -> ())
	return function(player: Player, ...)
		local session = PlayerSessions.gate(player)
		if session and session.weapon then
			handler(session, ...)
		end
	end
end

-- Range weapon rack (RangeService has already gated the player).
function WeaponService.equipById(session: PlayerSessions.Session, weaponId: string)
	if session.weapons and table.find(Loadout.weapons, weaponId) then
		equipId(session, weaponId)
	end
end

-- Range ammo crate: every weapon's reserves back to their starting amount. Magazines are kept.
function WeaponService.refill(session: PlayerSessions.Session)
	if not session.weapons then
		return
	end
	for _, weapon: WeaponState in session.weapons do
		for ammoId in weapon.reserve do
			weapon.reserve[ammoId] = math.max(weapon.reserve[ammoId], weapon.def.startingReserve)
		end
	end
	publish(session)
end

function WeaponService.init(remoteTable: { [string]: RemoteEvent })
	remotes = remoteTable

	PlayerSessions.onStarted(function(session)
		-- Every loadout weapon keeps its own magazine and reserves for this life.
		local weapons = {}
		for _, weaponId in Loadout.weapons do
			weapons[weaponId] = newWeaponState(weaponId)
		end
		session.weapons = weapons
		session.weapon = weapons[Loadout.startingWeapon] or newWeaponState(Loadout.startingWeapon)
		setWorldWeapon(session)
		publish(session)
	end)

	remotes.Fire.OnServerEvent:Connect(armed(fire))
	remotes.Reload.OnServerEvent:Connect(armed(reload))
	remotes.SelectAmmo.OnServerEvent:Connect(armed(selectAmmo))
	remotes.RequestSync.OnServerEvent:Connect(armed(publish))
	remotes.EquipWeapon.OnServerEvent:Connect(armed(equip))
end

return WeaponService
