local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapManifest = require(Shared:WaitForChild("MapManifest"))

local MapManifestLoader = {}

local function findFolderBySpec(spec)
	if type(spec) == "string" then
		local child = Workspace:FindFirstChild(spec)
		if child and child:IsA("Folder") then
			return child
		end
		return nil
	end

	if type(spec) == "table" and type(spec.root) == "string" then
		local child = Workspace:FindFirstChild(spec.root)
		if child and child:IsA("Folder") then
			return child
		end
	end
	return nil
end

local function collectBasePartsFromFolder(folder)
	local parts = {}
	if not folder then
		return parts
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	return parts
end

function MapManifestLoader.Resolve(mapId)
	local id = mapId or MapManifest.DefaultId
	local manifest = MapManifest[id] or MapManifest[MapManifest.DefaultId]
	if not manifest then
		error("MapManifestLoader: no manifest available")
	end

	local spawnZones = collectBasePartsFromFolder(findFolderBySpec(manifest.spawnZones))
	local keySpawnPoints = collectBasePartsFromFolder(findFolderBySpec(manifest.keySpawnPoints))
	local gearSpawnPoints = collectBasePartsFromFolder(findFolderBySpec(manifest.gearSpawnPoints))
	local introCutsceneNodes = collectBasePartsFromFolder(findFolderBySpec(manifest.introCutsceneNodes))

	local exitDoor = nil
	if type(manifest.exitDoor) == "string" then
		local obj = Workspace:FindFirstChild(manifest.exitDoor)
		if obj and obj:IsA("BasePart") then
			exitDoor = obj
		end
	end

	local qualificationZone = nil
	if type(manifest.qualificationZone) == "string" then
		local obj = Workspace:FindFirstChild(manifest.qualificationZone)
		if obj and obj:IsA("BasePart") then
			qualificationZone = obj
		end
	end

	return {
		id = manifest.id or id,
		name = manifest.name or id,
		spawnZones = spawnZones,
		keySpawnPoints = keySpawnPoints,
		gearSpawnPoints = gearSpawnPoints,
		exitDoor = exitDoor,
		qualificationZone = qualificationZone,
		introCutsceneNodes = introCutsceneNodes,
	}
end

return MapManifestLoader
