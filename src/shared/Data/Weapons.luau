--[[
	Weapon definitions. Server and client both read these, so tuning lives in one place.
	Pure data (no Roblox types) so tests/run.luau can load it in the plain Luau CLI.

	Server-authoritative fields: caliber, defaultAmmo, fireModes, magazineCapacity, startingReserve,
	fireInterval, reloadTime, equipTime, maxRange, spread.
	Client presentation fields: model, view, recoil, fieldOfView, sounds.

	Names are generic on purpose. The models are inspired by real platforms (AR-15, AK, a .50 hand
	cannon, a 4.6mm PDW) but real product names are trademarks, so keep them out of shipped text.
]]

export type FireMode = "Semi" | "Auto"

export type WeaponDef = {
	id: string,
	displayName: string,
	caliber: string,
	defaultAmmo: string,
	fireModes: { FireMode }, -- first entry is the default; B cycles
	magazineCapacity: number,
	startingReserve: number, -- per ammo type of this caliber
	fireInterval: number, -- seconds between shots (also the auto cyclic rate)
	reloadTime: number,
	equipTime: number, -- seconds after switching before the weapon can fire
	maxRange: number, -- studs
	spread: { hip: number, ads: number }, -- cone half-angle, degrees
	model: string, -- builder key in Visual/WeaponModels
	view: {
		hip: { number }, -- camera-space offset of the model origin when hip firing {x, y, z}
		eyeRelief: number, -- studs from the eye to the sight's aim point in ADS
		sprint: { number }, -- extra {pitch, yaw, roll} degrees when sprinting
	},
	recoil: {
		hipPitch: number, -- degrees of camera climb added per shot
		adsPitch: number,
		maxPitch: number,
		yaw: number, -- degrees of sideways drift per shot (fixed pattern, not random)
		kick: number, -- studs the viewmodel is pushed back per shot
		rotation: number, -- degrees the viewmodel muzzle flips up per shot
		roll: number, -- degrees of viewmodel roll per shot
		recovery: number, -- spring stiffness: higher returns faster
	},
	fieldOfView: { hip: number, ads: number },
	sounds: string, -- key in Data/WeaponSounds
}

local Weapons: { [string]: WeaponDef } = {
	RangeRifle = {
		id = "RangeRifle",
		displayName = "AR-556 Carbine",
		caliber = "5.56x45",
		defaultAmmo = "556_FMJ",
		fireModes = { "Semi", "Auto" },
		magazineCapacity = 30,
		startingReserve = 120,
		fireInterval = 0.08, -- 750 rpm on auto
		reloadTime = 2.1,
		equipTime = 0.45,
		maxRange = 260,
		spread = { hip = 1.2, ads = 0.24 },
		model = "AR",
		view = { hip = { 0.5, -0.58, -1.05 }, eyeRelief = 0.62, sprint = { -18, 38, 14 } },
		recoil = {
			hipPitch = 1.5,
			adsPitch = 0.95,
			maxPitch = 7,
			yaw = 0.28,
			kick = 0.16,
			rotation = 3.2,
			roll = 2.2,
			recovery = 140,
		},
		fieldOfView = { hip = 74, ads = 58 },
		sounds = "AR",
	},

	KR47 = {
		id = "KR47",
		displayName = "KR-47 Rifle",
		caliber = "7.62x39",
		defaultAmmo = "762_PS",
		fireModes = { "Semi", "Auto" },
		magazineCapacity = 30,
		startingReserve = 120,
		fireInterval = 0.1, -- 600 rpm
		reloadTime = 2.4,
		equipTime = 0.55,
		maxRange = 260,
		spread = { hip = 1.6, ads = 0.32 },
		model = "AK",
		view = { hip = { 0.5, -0.56, -1.1 }, eyeRelief = 0.75, sprint = { -18, 38, 14 } },
		recoil = {
			hipPitch = 2.1,
			adsPitch = 1.45,
			maxPitch = 9,
			yaw = 0.45,
			kick = 0.2,
			rotation = 4.2,
			roll = 3,
			recovery = 110,
		},
		fieldOfView = { hip = 74, ads = 60 },
		sounds = "AK",
	},

	HC50 = {
		id = "HC50",
		displayName = "HC-50 Hand Cannon",
		caliber = ".50AE",
		defaultAmmo = "50AE_FMJ",
		fireModes = { "Semi" },
		magazineCapacity = 7,
		startingReserve = 35,
		fireInterval = 0.32,
		reloadTime = 1.9,
		equipTime = 0.35,
		maxRange = 180,
		spread = { hip = 1.4, ads = 0.38 },
		model = "HandCannon",
		view = { hip = { 0.36, -0.46, -1.15 }, eyeRelief = 0.95, sprint = { -35, 12, 22 } },
		recoil = {
			hipPitch = 4.6,
			adsPitch = 3.6,
			maxPitch = 10,
			yaw = 0.7,
			kick = 0.24,
			rotation = 14,
			roll = 4,
			recovery = 85,
		},
		fieldOfView = { hip = 74, ads = 64 },
		sounds = "HandCannon",
	},

	PDW46 = {
		id = "PDW46",
		displayName = "PDW-46",
		caliber = "4.6x30",
		defaultAmmo = "46_FMJ",
		fireModes = { "Auto", "Semi" },
		magazineCapacity = 40,
		startingReserve = 160,
		fireInterval = 0.075, -- 800 rpm
		reloadTime = 1.8,
		equipTime = 0.4,
		maxRange = 200,
		spread = { hip = 1.0, ads = 0.3 },
		model = "PDW",
		view = { hip = { 0.46, -0.52, -0.95 }, eyeRelief = 0.6, sprint = { -20, 34, 16 } },
		recoil = {
			hipPitch = 0.95,
			adsPitch = 0.6,
			maxPitch = 6,
			yaw = 0.22,
			kick = 0.1,
			rotation = 2,
			roll = 1.6,
			recovery = 170,
		},
		fieldOfView = { hip = 74, ads = 60 },
		sounds = "PDW",
	},
}

for _, def in Weapons do
	table.freeze(def.fireModes)
	table.freeze(def.spread)
	table.freeze(def.view.hip)
	table.freeze(def.view.sprint)
	table.freeze(def.view)
	table.freeze(def.recoil)
	table.freeze(def.fieldOfView)
	table.freeze(def)
end

return table.freeze(Weapons)
