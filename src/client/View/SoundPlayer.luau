--[[
	Plays Data/WeaponSounds entries: random pitch, optional delay, and a short fade at `length`
	so multi-take library clips only play their first take. Each play is a fresh Sound, so rapid
	shots overlap naturally instead of cutting each other off.

	Sounds route through SoundService groups:
	  LastShiftWeapons  gunshots (compressor + low-end boost)
	  LastShiftFoley    reloads, casings, impacts
]]

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local FADE_TIME = 0.08
local FADE_INFO = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local SoundPlayer = {}

local random = Random.new()
local groups: { [string]: SoundGroup } = {}

local function group(name: string, build: (SoundGroup) -> ()): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = name
	build(soundGroup)
	soundGroup.Parent = SoundService
	return soundGroup
end

function SoundPlayer.init()
	groups.Weapons = group("LastShiftWeapons", function(g)
		g.Volume = 0.9
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 4
		eq.MidGain = 0
		eq.HighGain = -1.5
		eq.Priority = 1
		eq.Parent = g
		local compressor = Instance.new("CompressorSoundEffect")
		compressor.Threshold = -14
		compressor.Ratio = 4
		compressor.Attack = 0.005
		compressor.Release = 0.18
		compressor.GainMakeup = 3
		compressor.Priority = 2
		compressor.Parent = g
	end)
	groups.Foley = group("LastShiftFoley", function(g)
		g.Volume = 0.9
	end)
	-- A big concrete room. Applies to every sound in this client.
	SoundService.AmbientReverb = Enum.ReverbType.Hangar
end

-- Starts downloading every id so the first shot isn't silent.
function SoundPlayer.preload(entries: { any })
	local sounds = {}
	local seen = {}
	for _, entry in entries do
		if not seen[entry.id] then
			seen[entry.id] = true
			local sound = Instance.new("Sound")
			sound.SoundId = entry.id
			table.insert(sounds, sound)
		end
	end
	task.spawn(function()
		local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
		if not ok then
			warn("[LastShift] Sound preload failed: " .. tostring(err))
		end
	end)
end

export type PlayOptions = {
	groupName: string?, -- "Weapons" (default) or "Foley"
	volumeScale: number?,
	pitchScale: number?,
	rollOff: number?, -- RollOffMaxDistance for 3D sounds
}

-- Plays `entry` on `parent` (a BasePart/Attachment for 3D, or SoundService/nil for 2D).
-- Returns the thread scheduling it so callers can cancel a delayed sound.
function SoundPlayer.play(entry, parent: Instance?, options: PlayOptions?): thread
	local opts: PlayOptions = options or {}
	local function start()
		local sound = Instance.new("Sound")
		sound.Name = "LastShiftSfx"
		sound.SoundId = entry.id
		sound.Volume = entry.volume * (opts.volumeScale or 1)
		sound.PlaybackSpeed = random:NextNumber(entry.pitch[1], entry.pitch[2]) * (opts.pitchScale or 1)
		sound.SoundGroup = groups[opts.groupName or "Weapons"]
		if opts.rollOff then
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = 8
			sound.RollOffMaxDistance = opts.rollOff
		end
		sound.Parent = parent or SoundService
		sound:Play()
		local length = entry.length
		if length then
			-- `length` is in clip time; PlaybackSpeed changes how long that takes in real time.
			local realLength = length / sound.PlaybackSpeed
			task.delay(math.max(0, realLength - FADE_TIME), function()
				if sound.Parent then
					TweenService:Create(sound, FADE_INFO, { Volume = 0 }):Play()
				end
			end)
			Debris:AddItem(sound, realLength + 0.05)
		else
			sound.Ended:Once(function()
				sound:Destroy()
			end)
			Debris:AddItem(sound, 10)
		end
	end
	if entry.delay and entry.delay > 0 then
		return task.delay(entry.delay, start)
	end
	return task.spawn(start)
end

function SoundPlayer.pick(list: { any })
	return list[random:NextInteger(1, #list)]
end

return SoundPlayer
