--[[
	Range ambience on this client: lamps tagged with the `Flicker` attribute stutter now and then,
	like failing ballasts. Cosmetic and local; nothing here affects gameplay.
]]

local Workspace = game:GetService("Workspace")

local random = Random.new()

local function lightsOf(part: BasePart): { Light }
	local lights = {}
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			table.insert(lights, child)
		end
	end
	return lights
end

local function flicker(part: BasePart)
	local lights = lightsOf(part)
	local baseBrightness = {}
	for _, light in lights do
		baseBrightness[light] = light.Brightness
	end
	local baseMaterial = part.Material
	local function set(level: number)
		for _, light in lights do
			light.Brightness = baseBrightness[light] * level
		end
		if baseMaterial == Enum.Material.Neon then
			part.Material = if level > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	task.spawn(function()
		while part.Parent do
			task.wait(random:NextNumber(2.5, 9))
			for _ = 1, random:NextInteger(2, 6) do
				set(random:NextNumber(0, 0.25))
				task.wait(random:NextNumber(0.03, 0.12))
				set(1)
				task.wait(random:NextNumber(0.02, 0.2))
			end
			if random:NextNumber() < 0.2 then
				set(0)
				task.wait(random:NextNumber(0.6, 1.5))
				set(1)
			end
		end
	end)
end

local range = Workspace:WaitForChild("LastShiftRange", 30)
if range then
	for _, part in range:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Flicker") then
			flicker(part)
		end
	end
end
