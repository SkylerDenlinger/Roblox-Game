local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapManifest = require(Shared:WaitForChild("Content"):WaitForChild("Maps"):WaitForChild("MapManifest"))
local RoundRules = require(Shared:WaitForChild("Config"):WaitForChild("RoundRules"))

local MapRotationService = {}

local function getOrderedMaps()
	local maps = {}
	for key, definition in pairs(MapManifest) do
		if key ~= "Default" and key ~= "DefaultId" and type(definition) == "table" and definition.id then
			table.insert(maps, definition)
		end
	end

	table.sort(maps, function(a, b)
		return tostring(a.id) < tostring(b.id)
	end)

	return maps
end

local function weightedPick(definitions)
	local totalWeight = 0
	for _, definition in ipairs(definitions) do
		totalWeight += math.max(0.01, tonumber(definition.selectionWeight) or 1)
	end
	if totalWeight <= 0 then
		return definitions[1]
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, definition in ipairs(definitions) do
		cumulative += math.max(0.01, tonumber(definition.selectionWeight) or 1)
		if roll <= cumulative then
			return definition
		end
	end

	return definitions[#definitions]
end

function MapRotationService.SelectNextMap(previousMapId)
	local definitions = getOrderedMaps()
	if #definitions == 0 then
		error("MapRotationService: no maps configured")
	end

	local candidates = definitions
	if RoundRules.Maps and RoundRules.Maps.NoImmediateRepeat and #definitions > 1 and previousMapId then
		candidates = {}
		for _, definition in ipairs(definitions) do
			if definition.id ~= previousMapId then
				table.insert(candidates, definition)
			end
		end
		if #candidates == 0 then
			candidates = definitions
		end
	end

	local picked = weightedPick(candidates)
	return picked and picked.id or MapManifest.DefaultId
end

return MapRotationService
