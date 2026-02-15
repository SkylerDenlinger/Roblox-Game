local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CollectiblesService = {}

local TOUCH_COOLDOWN = 0.75

local function requireChild(parent, name)
	local c = parent:FindFirstChild(name)
	if not c then
		error(("CollectiblesService missing '%s' under %s"):format(name, parent:GetFullName()))
	end
	return c
end

local function getMatchPhase()
	local stateRoot = requireChild(ReplicatedStorage, "State")
	local match = requireChild(stateRoot, "Match")
	local phase = requireChild(match, "Phase")
	return phase.Value
end

local function getPlayerFromHit(hit)
	if not hit then return nil end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function getPlayerKeysValue(player)
	local stateRoot = ReplicatedStorage:FindFirstChild("State")
	if not stateRoot then return nil end
	local ps = stateRoot:FindFirstChild("PlayerState")
	if not ps then return nil end
	local pf = ps:FindFirstChild(tostring(player.UserId))
	if not pf then return nil end
	return pf:FindFirstChild("Keys")
end

local function ensureRoundFolders()
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

	return collectibles
end

local function bindTouch(keyInstance)
	local part = keyInstance:IsA("BasePart") and keyInstance or keyInstance:FindFirstChildWhichIsA("BasePart", true)
	if not part then return end

	part.CanTouch = true
	keyInstance:SetAttribute("Picked", false)

	local lastTouch = 0

	part.Touched:Connect(function(hit)
		if getMatchPhase() ~= "Collectathon" then return end

		local now = os.clock()
		if now - lastTouch < TOUCH_COOLDOWN then return end
		lastTouch = now

		if keyInstance:GetAttribute("Picked") then return end

		local player = getPlayerFromHit(hit)
		if not player then return end

		local keysVal = getPlayerKeysValue(player)
		if not keysVal then return end

		keyInstance:SetAttribute("Picked", true)
		keysVal.Value += 1
		keyInstance:Destroy()
	end)
end

function CollectiblesService.SpawnKeys(count)
	local folder = ensureRoundFolders()
	folder:ClearAllChildren()

	local prefabs = requireChild(ServerStorage, "Prefabs")
	local prefab = requireChild(prefabs, "Key")

	for i = 1, count do
		local k = prefab:Clone()
		k.Parent = folder
		bindTouch(k)
	end
end

function CollectiblesService.ClearKeys()
	local folder = Workspace:FindFirstChild("RoundObjects")
	if not folder then return end
	local collectibles = folder:FindFirstChild("Collectibles")
	if collectibles then
		collectibles:ClearAllChildren()
	end
end

return CollectiblesService
