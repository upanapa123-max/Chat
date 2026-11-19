--[[
	Weapon definitions. Server and client both read these, so tuning lives in one place.

	Server-authoritative fields: caliber, defaultAmmo, magazineCapacity, startingReserve,
	fireInterval, reloadTime, maxRange, spread.
	Client presentation fields: recoil, fieldOfView, sound.
]]

export type WeaponDef = {
	id: string,
	displayName: string,
	caliber: string,
	defaultAmmo: string,
	fireMode: "Semi",
	magazineCapacity: number,
	startingReserve: number, -- per ammo type of this caliber
	fireInterval: number, -- seconds between shots
	reloadTime: number,
	maxRange: number, -- studs
	spread: { hip: number, ads: number }, -- cone half-angle, degrees
	recoil: {
		hipPitch: number,
		adsPitch: number,
		maxPitch: number, -- degrees of camera climb
		hipKick: number,
		adsKick: number,
		maxKick: number, -- studs of viewmodel push-back
	},
	fieldOfView: { hip: number, ads: number },
	sound: { id: string, volume: number },
}

local Weapons: { [string]: WeaponDef } = {
	RangeRifle = {
		id = "RangeRifle",
		displayName = "5.56mm Range Rifle",
		caliber = "5.56x45",
		defaultAmmo = "556_FMJ",
		fireMode = "Semi",
		magazineCapacity = 30,
		startingReserve = 120,
		fireInterval = 0.15,
		reloadTime = 1.45,
		maxRange = 260,
		spread = { hip = 1.2, ads = 0.26 },
		recoil = {
			hipPitch = 2.2,
			adsPitch = 1.25,
			maxPitch = 5,
			hipKick = 0.19,
			adsKick = 0.12,
			maxKick = 0.28,
		},
		fieldOfView = { hip = 74, ads = 57 },
		-- Creator Store gunshot sample. If it is silent in your place, its permissions block it:
		-- swap in any gunshot sound you own.
		sound = { id = "rbxassetid://213603013", volume = 0.28 },
	},
}

for _, def in Weapons do
	table.freeze(def.spread)
	table.freeze(def.recoil)
	table.freeze(def.fieldOfView)
	table.freeze(def.sound)
	table.freeze(def)
end

return table.freeze(Weapons)
