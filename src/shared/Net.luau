--[[
	Network contract. One RemoteEvent per message, all inside ReplicatedStorage.LastShift.Remotes.
	The server creates them (Net.create); clients wait for them (Net.waitFor).

	Client -> Server (every request passes PlayerSessions.gate: live character + rate limit)
	  Fire(aim: Vector3)            unit camera look vector; server picks origin, spread, hit, damage
	  Reload()
	  SelectAmmo(ammoId: string)    must belong to the equipped weapon's caliber
	  SetMovement(mode: string)     must be a key of Movement.speed
	  RequestSync()                 asks for a fresh WeaponState

	Server -> Client
	  WeaponState(state: WeaponState)
	  ShotResult(result: ShotResult)
]]

export type WeaponState = {
	weaponId: string,
	loadedAmmo: string,
	selectedAmmo: string,
	magazine: number,
	capacity: number,
	reserve: { [string]: number },
	reloading: boolean,
}

export type ShotResult = {
	endpoint: Vector3,
	surface: "Miss" | "World" | "Target",
	ammoId: string,
	distance: number,
	-- The fields below are only set when surface == "Target".
	targetName: string?,
	zone: string?,
	damage: number?,
	armor: string?, -- "None" | "Penetrated" | "Reduced" | "Stopped"
	armorName: string?,
	protection: number?,
	penetration: number?,
	falloffScale: number?,
	lethal: boolean?,
	health: number?,
	maxHealth: number?,
}

local Net = {}

Net.names = table.freeze({
	"Fire",
	"Reload",
	"SelectAmmo",
	"SetMovement",
	"RequestSync",
	"WeaponState",
	"ShotResult",
})

local FOLDER_NAME = "Remotes"

-- Server only. Builds every remote, then parents the folder in one step.
function Net.create(root: Instance): { [string]: RemoteEvent }
	assert(root:FindFirstChild(FOLDER_NAME) == nil, "Remotes already created")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local remotes = {}
	for _, name in Net.names do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	folder.Parent = root
	return remotes
end

-- Client only.
function Net.waitFor(root: Instance): { [string]: RemoteEvent }
	local folder = root:WaitForChild(FOLDER_NAME)
	local remotes = {}
	for _, name in Net.names do
		remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
	return remotes
end

return table.freeze(Net)
