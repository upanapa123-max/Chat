--[[
	Movement sounds for low stances. Client presentation only.

	While a character is crouched or prone, Roblox's default "Running" footstep loop is muted for
	that character and these play instead, one "step" at a time while it moves on the ground.

	Every id is a free Creator Store sound effect from the Pro Sound Effects library (published by
	the verified ProSoundEffects account). Each id was checked against the Creator Store API on
	2026-11-19: public, free, and the description matches the use. They were NOT auditioned by ear,
	so `length`, volumes and intervals are first guesses: tune them in Studio.

	Entry fields match Data/WeaponSounds (id, volume, pitch {min, max}, optional length).

	Per stance
	  steps      one is picked per step
	  gear       optional quiet kit rattle layered on some steps
	  gearChance 0..1 chance of the gear layer per step
	  interval   seconds between steps at the stance's full speed (slower movement = longer gap)
	  rollOff    how far away other players can hear it, studs
]]

local function entry(id: number, volume: number, pitchMin: number, pitchMax: number, length: number?)
	return table.freeze({
		id = "rbxassetid://" .. id,
		volume = volume,
		pitch = table.freeze({ pitchMin, pitchMax }),
		length = length,
	})
end

-- "Body Pat Muted": cupped hand through clothing, muted, rubbing and scraping. Soft, padded steps.
local SOFT_STEPS = table.freeze({
	entry(9113532211, 0.55, 0.85, 1.0, 0.32),
	entry(9113532220, 0.55, 0.85, 1.0, 0.32),
})

-- "Leather Strap": movement and handling. Webbing and kit shifting.
local GEAR = table.freeze({
	entry(9116257799, 0.25, 0.9, 1.1, 0.45),
})

-- "Camo Suit Crawling On The Ground": clothing movement while crawling.
local CRAWL = table.freeze({
	entry(9113702060, 0.7, 0.9, 1.05, 0.9),
	entry(9113702079, 0.7, 0.9, 1.05, 0.9),
	entry(9113702330, 0.7, 0.9, 1.05, 0.9),
	entry(9113702346, 0.7, 0.9, 1.05, 0.9),
	entry(9113702531, 0.7, 0.9, 1.05, 0.9),
})

return table.freeze({
	Crouch = table.freeze({ steps = SOFT_STEPS, gear = GEAR, gearChance = 0.35, interval = 0.5, rollOff = 45 }),
	Prone = table.freeze({ steps = CRAWL, gear = GEAR, gearChance = 0.2, interval = 0.85, rollOff = 30 }),
})
