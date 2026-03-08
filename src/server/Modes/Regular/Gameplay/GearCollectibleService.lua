local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local serverRoot = script.Parent.Parent.Parent.Parent
local PlayerStateService = require(serverRoot:WaitForChild("State"):WaitForChild("PlayerStateService"))

local GearCollectibleService = {}

local TOUCH_COOLDOWN = 0.6

local activeToken = 0
local activeFolder = nil
local isPlayerAllowedCallback = nil
local onCollectedCallback = nil

local function ensureCollectiblesFolder()
	local roundObjects = Workspace:FindFirstChild("RoundObjects")
	if not roundObjects then
		roundObjects = Instance.new("Folder")
		roundObjects.Name = "RoundObjects"
		roundObjects.Parent = Workspace
	end
	local collectibles = roundObjects:FindFirstChild("Collectibles")
	if not collectibles then
		collectibles = Instance.new("Folder")
		collectibles.Name = "Collectibles"
		collectibles.Parent = roundObjects
	end
	local gears = collectibles:FindFirstChild("Gears")
	if not gears then
		gears = Instance.new("Folder")
		gears.Name = "Gears"
		gears.Parent = collectibles
	end
	return gears
end

local function getPlayerFromHit(hit)
	if not hit then
		return nil
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function resolvePrefab()
	local prefabs = ServerStorage:FindFirstChild("Prefabs")
	if prefabs then
		local gear = prefabs:FindFirstChild("Gear")
		if gear then
			return gear
		end
	end
	return nil
end

local function setCollectibleTransform(instance, spawnPoint)
	local part = spawnPoint
	if type(spawnPoint) == "table" then
		part = spawnPoint.part
	end
	if not part then
		return
	end
	local pivot = part.CFrame + Vector3.new(0, 2.5, 0)
	if instance:IsA("Model") then
		instance:PivotTo(pivot)
	else
		local targetPart = instance:IsA("BasePart") and instance or instance:FindFirstChildWhichIsA("BasePart", true)
		if targetPart then
			targetPart.CFrame = pivot
		end
	end
end

local function bindTouch(instance, token)
	local touchPart = instance:IsA("BasePart") and instance or instance:FindFirstChildWhichIsA("BasePart", true)
	if not touchPart then
		return
	end
	touchPart.CanTouch = true
	instance:SetAttribute("Picked", false)
	local lastTouchByUserId = {}

	touchPart.Touched:Connect(function(hit)
		if token ~= activeToken then
			return
		end
		if instance:GetAttribute("Picked") then
			return
		end
		local player = getPlayerFromHit(hit)
		if not player then
			return
		end
		if isPlayerAllowedCallback and not isPlayerAllowedCallback(player.UserId) then
			return
		end
		local now = os.clock()
		local previous = lastTouchByUserId[player.UserId] or 0
		if now - previous < TOUCH_COOLDOWN then
			return
		end
		lastTouchByUserId[player.UserId] = now

		instance:SetAttribute("Picked", true)
		local gears = PlayerStateService.IncrementGears(player.UserId, 1)
		if onCollectedCallback then
			onCollectedCallback(player.UserId, now, gears, instance:GetAttribute("SpawnId"))
		end
		instance:Destroy()
	end)
end

function GearCollectibleService.StartRound(options)
	activeToken += 1
	local token = activeToken
	activeFolder = ensureCollectiblesFolder()
	activeFolder:ClearAllChildren()

	options = options or {}
	isPlayerAllowedCallback = options.isPlayerAllowed
	onCollectedCallback = options.onCollected
	local spawnPoints = options.spawnPoints or {}
	local spawnPlan = options.spawnPlan
	local spawnCount = math.max(0, math.floor(options.count or 0))

	local prefab = resolvePrefab()
	if not prefab then
		warn("GearCollectibleService: missing ServerStorage/Prefabs/Gear")
		return
	end
	if spawnPlan and #spawnPlan == 0 then
		warn("GearCollectibleService: no gear spawn plan generated")
		return
	end
	if not spawnPlan and #spawnPoints == 0 then
		warn("GearCollectibleService: no gear spawn points in map manifest")
		return
	end

	local selectedSpawns = spawnPlan
	if not selectedSpawns then
		selectedSpawns = {}
		for index = 1, spawnCount do
			table.insert(selectedSpawns, spawnPoints[((index - 1) % #spawnPoints) + 1])
		end
	end

	for _, spawnPoint in ipairs(selectedSpawns) do
		local gear = prefab:Clone()
		gear.Parent = activeFolder
		if type(spawnPoint) == "table" then
			gear:SetAttribute("SpawnId", spawnPoint.id)
		end
		setCollectibleTransform(gear, spawnPoint)
		bindTouch(gear, token)
	end
end

function GearCollectibleService.EndRound()
	activeToken += 1
	isPlayerAllowedCallback = nil
	onCollectedCallback = nil
	if activeFolder then
		activeFolder:ClearAllChildren()
	end
end

return GearCollectibleService
