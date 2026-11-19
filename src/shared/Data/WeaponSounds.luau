--[[
	Weapon and impact sound sets. Client presentation only.

	Every id below is a free Creator Store sound effect from the Pro Sound Effects library that
	Roblox licenses for use in any experience. On 2026-11-19 each id was checked against the
	Creator Store API: public, free, published by the verified ProSoundEffects account, and the
	description matches the use. They were NOT auditioned by ear, so the `length` cut points and
	volumes are first guesses: tune them in Studio and keep the ids if they sound right.

	Entry fields
	  id       rbxassetid
	  volume   0..10 (Roblox Sound.Volume)
	  pitch    { min, max } PlaybackSpeed, randomised per play so repeats don't sound copy-pasted
	  length   optional: seconds to keep before a short fade-out. Many library clips contain several
	           takes in a row; this keeps only the first one.
	  delay    optional: seconds after the trigger

	A gunshot plays every layer of `fire` at once:
	  report  the main crack of that weapon
	  body    a low thump borrowed from a big-bore rifle, quiet, for weight
	  tail    an indoor take of a carbine, quiet, for the room echo
]]

export type SoundEntry = {
	id: string,
	volume: number,
	pitch: { number },
	length: number?,
	delay: number?,
}

export type WeaponSoundSet = {
	fire: { SoundEntry },
	magOut: SoundEntry,
	magIn: SoundEntry,
	bolt: SoundEntry,
	equip: SoundEntry,
	dry: SoundEntry,
}

local function s(id: number, volume: number, pitchMin: number, pitchMax: number, length: number?, delay: number?): SoundEntry
	return table.freeze({
		id = "rbxassetid://" .. tostring(id),
		volume = volume,
		pitch = table.freeze({ pitchMin, pitchMax }),
		length = length,
		delay = delay,
	})
end

-- Library ids (Creator Store, ProSoundEffects)
local M4_CRACK = 9113188670 -- Assault Rifle, M4A1 Carbine, Crack of Single Shots, Bigger Low End, Long Decay
local M4_INTERIOR = 9113193653 -- Assault Rifle, M4A1 Carbine, Interior or Canyon, Single Shots
local GALIL = 9114551929 -- Galil Assault Rifle, Multiple Single Shots, Very Powerful
local AUG_SHORT = 9113177810 -- Assault Rifle, Steyr AUG Short Barrel, Single Shots
local BERETTA = 9114715847 -- Gun, 9mm Beretta, Live Ammunition, Full flash singles
local WIN_MAG = 9117402631 -- Pistol, L.A.R. Grizzly Win Mag .45, Single Shots, Very Good
local BIG_BORE = 9118173739 -- Rifle, Barrett M82 .50 Cal, Single Shots
local AK_CLIP_A = 9116347612 -- Machine Gun, AK-47, Clip Handling Action, Loading Rifle, Mechanical
local AK_CLIP_B = 9116347811 -- (same session, different take)
local AK_CLIP_C = 9116348211 -- (same session, different take)
local MAG_PISTOL_A = 9113104176 -- Ammo Magazine, Spring Release, Fast Insert, Eject, Pistol
local MAG_PISTOL_B = 9113104337
local MAG_PISTOL_C = 9113104208
local GUN_HANDLING = 9114704338 -- Gun Handling, Pull From Pocket, Metal Rattle, Cloth Rub, Click
local CLICK = 9120407137 -- Vice Grips, Switch, Metallic Clicks (dry fire)

local WeaponSounds: { [string]: WeaponSoundSet } = {
	AR = {
		fire = {
			s(M4_CRACK, 1.1, 0.97, 1.04, 0.9),
			s(BIG_BORE, 0.32, 1.15, 1.22, 0.35),
			s(M4_INTERIOR, 0.35, 0.96, 1.02, 1.4),
		},
		magOut = s(AK_CLIP_A, 0.7, 1.08, 1.12, 0.6, 0.25),
		magIn = s(AK_CLIP_B, 0.8, 1.06, 1.1, 0.6, 1.15),
		bolt = s(AK_CLIP_C, 0.8, 1.12, 1.16, 0.6, 1.65),
		equip = s(GUN_HANDLING, 0.6, 1, 1.05, 0.6),
		dry = s(CLICK, 0.6, 1.2, 1.25, 0.25),
	},
	AK = {
		fire = {
			s(GALIL, 1.2, 0.86, 0.92, 0.95),
			s(BIG_BORE, 0.42, 1.0, 1.06, 0.4),
			s(M4_INTERIOR, 0.4, 0.86, 0.9, 1.5),
		},
		magOut = s(AK_CLIP_A, 0.8, 0.95, 1.0, 0.7, 0.3),
		magIn = s(AK_CLIP_B, 0.9, 0.95, 1.0, 0.7, 1.3),
		bolt = s(AK_CLIP_C, 0.9, 0.96, 1.0, 0.7, 1.9),
		equip = s(GUN_HANDLING, 0.65, 0.92, 0.96, 0.6),
		dry = s(CLICK, 0.6, 1.0, 1.05, 0.25),
	},
	PDW = {
		fire = {
			s(AUG_SHORT, 0.95, 1.1, 1.16, 0.6),
			s(BERETTA, 0.45, 1.02, 1.08, 0.4),
			s(M4_INTERIOR, 0.25, 1.12, 1.18, 1.1),
		},
		magOut = s(MAG_PISTOL_A, 0.7, 0.9, 0.95, 0.6, 0.25),
		magIn = s(MAG_PISTOL_B, 0.8, 0.9, 0.95, 0.6, 1.0),
		bolt = s(AK_CLIP_C, 0.6, 1.25, 1.3, 0.5, 1.4),
		equip = s(GUN_HANDLING, 0.55, 1.08, 1.12, 0.6),
		dry = s(CLICK, 0.6, 1.3, 1.35, 0.25),
	},
	HandCannon = {
		fire = {
			s(WIN_MAG, 1.3, 0.9, 0.95, 1.0),
			s(BIG_BORE, 0.45, 1.22, 1.3, 0.4),
			s(M4_INTERIOR, 0.35, 0.78, 0.82, 1.5),
		},
		magOut = s(MAG_PISTOL_A, 0.8, 1.0, 1.05, 0.6, 0.2),
		magIn = s(MAG_PISTOL_B, 0.9, 1.0, 1.05, 0.6, 1.0),
		bolt = s(MAG_PISTOL_C, 0.9, 0.9, 0.95, 0.6, 1.45),
		equip = s(GUN_HANDLING, 0.55, 1.1, 1.15, 0.6),
		dry = s(CLICK, 0.6, 1.1, 1.15, 0.25),
	},
}

-- Shell casings landing (.45 cartridge drops to concrete). One is picked at random.
local casings = {
	s(9113631437, 0.25, 0.95, 1.15, 0.6, 0.45),
	s(9113631202, 0.25, 0.95, 1.15, 0.6, 0.5),
	s(9113631067, 0.25, 0.95, 1.15, 0.6, 0.42),
	s(9113631209, 0.25, 0.95, 1.15, 0.6, 0.48),
}

-- Bullet impacts, by what the server says was hit.
local impacts = {
	World = { -- Axe Impact, Big Hits Against Concrete (pitched up to sound like a small round)
		s(9113225476, 0.45, 1.7, 2.0, 0.35),
		s(9113225486, 0.45, 1.7, 2.0, 0.35),
	},
	Flesh = { -- Flesh Hits, Low Thuds
		s(9114482142, 0.9, 0.95, 1.1, 0.4),
		s(9114482147, 0.9, 0.95, 1.1, 0.4),
		s(9114482300, 0.9, 0.95, 1.1, 0.4),
	},
	Armor = { -- Ricochet Metal, Bullet Impact, Clang
		s(9118168612, 0.6, 1.0, 1.15, 0.6),
		s(9118168610, 0.6, 1.0, 1.15, 0.6),
	},
}

for _, set in WeaponSounds do
	table.freeze(set.fire)
	table.freeze(set)
end
for _, list in impacts do
	table.freeze(list)
end

return table.freeze({
	weapons = table.freeze(WeaponSounds),
	casings = table.freeze(casings),
	impacts = table.freeze(impacts),
})
