local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapManifest = require(Shared:WaitForChild("MapManifest"))

local MapManifestLoader = {}

local ACTIVE_MAP_NAME = "ActiveMap"
local DEFAULT_ORIGIN = Vector3.new(0, 10, 0)

local activeMapId = nil
local activeMapRoot = nil

local function findChildByPath(root, path)
	if not root or type(path) ~= "string" or path == "" then
		return nil
	end

	local current = root
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
		if not current then
			return nil
		end
	end
	return current
end

local function findObjectBySpec(root, spec)
	if not root then
		return nil
	end

	if type(spec) == "string" then
		return findChildByPath(root, spec) or root:FindFirstChild(spec, true)
	end

	if type(spec) == "table" and type(spec.root) == "string" then
		return findChildByPath(root, spec.root) or root:FindFirstChild(spec.root, true)
	end

	return nil
end

local function collectBasePartsFromContainer(container)
	local parts = {}
	if not container then
		return parts
	end

	if container:IsA("BasePart") then
		table.insert(parts, container)
		return parts
	end

	for _, child in ipairs(container:GetDescendants()) do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	return parts
end

local function resolveSourceName(manifest, id)
	if type(manifest.source) == "table" and type(manifest.source.serverStorage) == "string" then
		return manifest.source.serverStorage
	end
	return tostring(manifest.id or id)
end

local function findMapTemplate(sourceName)
	local mapsFolder = ServerStorage:FindFirstChild("Maps")
	if mapsFolder then
		local fromMaps = mapsFolder:FindFirstChild(sourceName)
		if fromMaps then
			return fromMaps
		end
	end
	return ServerStorage:FindFirstChild(sourceName)
end

local function getMapOrigin(manifest)
	if typeof(manifest.origin) == "Vector3" then
		return manifest.origin
	end
	return DEFAULT_ORIGIN
end

local function recenterMap(instance, targetPosition)
	if not instance then
		return
	end

	if instance:IsA("Model") then
		instance:PivotTo(CFrame.new(targetPosition))
		return
	end

	local parts = collectBasePartsFromContainer(instance)
	if #parts == 0 then
		return
	end

	local sum = Vector3.zero
	for _, part in ipairs(parts) do
		sum += part.Position
	end
	local center = sum / #parts
	local offset = targetPosition - center
	for _, part in ipairs(parts) do
		part.CFrame = part.CFrame + offset
	end
end

local function ensureRuntimeMap(manifest, id)
	local requestedId = tostring(manifest.id or id)
	if activeMapRoot and activeMapRoot.Parent and activeMapId == requestedId then
		return activeMapRoot
	end

	if activeMapRoot and activeMapRoot.Parent then
		activeMapRoot:Destroy()
	end
	activeMapRoot = nil
	activeMapId = nil

	local sourceName = resolveSourceName(manifest, id)
	local template = findMapTemplate(sourceName)
	if not template then
		warn(("MapManifestLoader: map template '%s' not found in ServerStorage; falling back to Workspace."):format(sourceName))
		return nil
	end

	local clone = template:Clone()
	clone.Name = ACTIVE_MAP_NAME
	clone.Parent = Workspace
	recenterMap(clone, getMapOrigin(manifest))

	activeMapId = requestedId
	activeMapRoot = clone
	return clone
end

function MapManifestLoader.Resolve(mapId)
	local id = mapId or MapManifest.DefaultId
	local manifest = MapManifest[id] or MapManifest[MapManifest.DefaultId]
	if not manifest then
		error("MapManifestLoader: no manifest available")
	end

	local mapRoot = ensureRuntimeMap(manifest, id)
	local searchRoot = mapRoot or Workspace

	local spawnZones = collectBasePartsFromContainer(findObjectBySpec(searchRoot, manifest.spawnZones))
	local keySpawnPoints = collectBasePartsFromContainer(findObjectBySpec(searchRoot, manifest.keySpawnPoints))
	local gearSpawnPoints = collectBasePartsFromContainer(findObjectBySpec(searchRoot, manifest.gearSpawnPoints))
	local introCutsceneNodes = collectBasePartsFromContainer(findObjectBySpec(searchRoot, manifest.introCutsceneNodes))

	local exitDoor = nil
	local exitDoorObj = findObjectBySpec(searchRoot, manifest.exitDoor)
	if exitDoorObj and exitDoorObj:IsA("BasePart") then
		exitDoor = exitDoorObj
	end

	local qualificationZone = nil
	local qualificationZoneObj = findObjectBySpec(searchRoot, manifest.qualificationZone)
	if qualificationZoneObj and qualificationZoneObj:IsA("BasePart") then
		qualificationZone = qualificationZoneObj
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
