local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local StateContract = require(script.Parent:WaitForChild("StateContract"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local ExitDoorService = {}

local DOOR_GROUP = "ExitDoor"
local PASS_GROUP = "DoorPass"
local CLOSED_COLOR = Color3.fromRGB(0, 170, 255)
local OPEN_COLOR = Color3.fromRGB(0, 255, 0)

local doorPart = nil
local roundEnabled = false
local requiredKeys = 0
local entrants = {}
local granted = {}
local grantedCount = 0

local function setProgressDoorState(stateName)
	local refs = StateContract.Get()
	if refs.Progress:FindFirstChild("DoorState") then
		refs.Progress.DoorState.Value = stateName
	end
end

local function ensureGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(DOOR_GROUP)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PASS_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(DOOR_GROUP, PASS_GROUP, false)
end

local function setCharacterGroup(character, groupName)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end
end

local function updateDoorVisuals()
	if grantedCount > 0 then
		setProgressDoorState("Open")
		if doorPart then
			doorPart.Color = OPEN_COLOR
		end
	else
		setProgressDoorState("Closed")
		if doorPart then
			doorPart.Color = CLOSED_COLOR
		end
	end
end

local function hasEntrant(userId)
	return entrants[userId] == true
end

local function grantAccessForUserId(userId)
	if granted[userId] then
		return false
	end
	granted[userId] = true
	grantedCount += 1
	local player = Players:GetPlayerByUserId(userId)
	if player and player.Character then
		setCharacterGroup(player.Character, PASS_GROUP)
	end
	updateDoorVisuals()
	return true
end

local function revokeAccessForUserId(userId)
	if not granted[userId] then
		return false
	end
	granted[userId] = nil
	grantedCount = math.max(0, grantedCount - 1)
	local player = Players:GetPlayerByUserId(userId)
	if player and player.Character then
		setCharacterGroup(player.Character, "Default")
	end
	updateDoorVisuals()
	return true
end

function ExitDoorService.BindDoor(part)
	ensureGroups()
	doorPart = part
	if doorPart then
		doorPart.CanTouch = true
		doorPart.CanCollide = true
		doorPart.CollisionGroup = DOOR_GROUP
		doorPart.Color = CLOSED_COLOR
	end
end

function ExitDoorService.StartRound(options)
	options = options or {}
	requiredKeys = math.max(0, math.floor(options.requiredKeys or 0))
	entrants = {}
	granted = {}
	grantedCount = 0
	for _, userId in ipairs(options.entrantUserIds or {}) do
		entrants[userId] = true
	end
	roundEnabled = true
	updateDoorVisuals()
end

function ExitDoorService.EndRound()
	roundEnabled = false
	for userId in pairs(granted) do
		revokeAccessForUserId(userId)
	end
	granted = {}
	grantedCount = 0
	entrants = {}
	if doorPart then
		doorPart.Color = CLOSED_COLOR
		doorPart.CanCollide = true
	end
	setProgressDoorState("Closed")
end

function ExitDoorService.EvaluateUser(userId)
	if not roundEnabled or not hasEntrant(userId) then
		return false
	end
	local keys = PlayerStateService.GetKeys(userId)
	if keys >= requiredKeys then
		return grantAccessForUserId(userId)
	end
	return false
end

function ExitDoorService.HasAccess(userId)
	return granted[userId] == true
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		if granted[player.UserId] then
			setCharacterGroup(character, PASS_GROUP)
		else
			setCharacterGroup(character, "Default")
		end
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function(character)
		if granted[player.UserId] then
			setCharacterGroup(character, PASS_GROUP)
		else
			setCharacterGroup(character, "Default")
		end
	end)
end

return ExitDoorService
