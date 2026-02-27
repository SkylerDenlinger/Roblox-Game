local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local KeyCollectibleService = {}

local TOUCH_COOLDOWN = 0.6

local activeToken = 0
local activeFolder = nil
local onCollectedCallback = nil
local isPlayerAllowedCallback = nil

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
	local keys = collectibles:FindFirstChild("Keys")
	if not keys then
		keys = Instance.new("Folder")
		keys.Name = "Keys"
		keys.Parent = collectibles
	end
	return keys
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
		local key = prefabs:FindFirstChild("Key")
		if key then
			return key
		end
	end
	return nil
end

local function setCollectibleTransform(instance, spawnPoint)
	local pivot = spawnPoint.CFrame + Vector3.new(0, 2.5, 0)
	if instance:IsA("Model") then
		instance:PivotTo(pivot)
	else
		local part = instance:IsA("BasePart") and instance or instance:FindFirstChildWhichIsA("BasePart", true)
		if part then
			part.CFrame = pivot
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
		local keys = PlayerStateService.IncrementKeys(player.UserId, 1)
		if onCollectedCallback then
			onCollectedCallback(player.UserId, now, keys)
		end
		instance:Destroy()
	end)
end

function KeyCollectibleService.StartRound(options)
	activeToken += 1
	local token = activeToken
	activeFolder = ensureCollectiblesFolder()
	activeFolder:ClearAllChildren()

	options = options or {}
	onCollectedCallback = options.onCollected
	isPlayerAllowedCallback = options.isPlayerAllowed

	local spawnPoints = options.spawnPoints or {}
	local spawnCount = math.max(0, math.floor(options.count or 0))
	local prefab = resolvePrefab()
	if not prefab then
		warn("KeyCollectibleService: missing ServerStorage/Prefabs/Key")
		return
	end

	if #spawnPoints == 0 then
		warn("KeyCollectibleService: no key spawn points in map manifest")
		return
	end

	for i = 1, spawnCount do
		local spawnPoint = spawnPoints[((i - 1) % #spawnPoints) + 1]
		local key = prefab:Clone()
		key.Parent = activeFolder
		setCollectibleTransform(key, spawnPoint)
		bindTouch(key, token)
	end
end

function KeyCollectibleService.EndRound()
	activeToken += 1
	onCollectedCallback = nil
	isPlayerAllowedCallback = nil
	if activeFolder then
		activeFolder:ClearAllChildren()
	end
end

return KeyCollectibleService
