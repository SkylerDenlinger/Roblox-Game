local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateService = {}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureValue(parent, className, name, defaultValue)
	local valueObject = parent:FindFirstChild(name)
	if valueObject and valueObject.ClassName == className then
		return valueObject
	end
	if valueObject then
		valueObject:Destroy()
	end

	valueObject = Instance.new(className)
	valueObject.Name = name
	valueObject.Value = defaultValue
	valueObject.Parent = parent
	return valueObject
end

local function getPlayerStateRoot()
	local stateRoot = ReplicatedStorage:WaitForChild("State")
	return stateRoot:WaitForChild("PlayerState")
end

function PlayerStateService.GetPlayerFolderByUserId(userId)
	local root = getPlayerStateRoot()
	return root:FindFirstChild(tostring(userId))
end

function PlayerStateService.EnsurePlayerFolder(player)
	local playerStateRoot = getPlayerStateRoot()
	local playerFolder = ensureFolder(playerStateRoot, tostring(player.UserId))

	ensureValue(playerFolder, "IntValue", "Keys", 0)
	ensureValue(playerFolder, "IntValue", "Gears", 0)
	ensureValue(playerFolder, "IntValue", "Thrust", 100)
	ensureValue(playerFolder, "BoolValue", "Qualified", false)
	ensureValue(playerFolder, "NumberValue", "QualifiedAtServerTime", 0)
	ensureValue(playerFolder, "IntValue", "Placement", 0)
	ensureValue(playerFolder, "StringValue", "ResultMode", "none")
	ensureValue(playerFolder, "BoolValue", "Eliminated", false)
	ensureValue(playerFolder, "IntValue", "LastRoundKeys", 0)
	ensureValue(playerFolder, "IntValue", "LastRoundGears", 0)

	local specials = ensureFolder(playerFolder, "SpecialMoves")
	ensureValue(specials, "BoolValue", "Move1Ready", true)
	ensureValue(specials, "BoolValue", "Move2Ready", true)

	return playerFolder
end

function PlayerStateService.ResetRoundStateForUserIds(userIds)
	for _, userId in ipairs(userIds) do
		local playerFolder = PlayerStateService.GetPlayerFolderByUserId(userId)
		if playerFolder then
			local keys = playerFolder:FindFirstChild("Keys")
			local gears = playerFolder:FindFirstChild("Gears")
			local qualified = playerFolder:FindFirstChild("Qualified")
			local qualifiedAt = playerFolder:FindFirstChild("QualifiedAtServerTime")
			local placement = playerFolder:FindFirstChild("Placement")
			local resultMode = playerFolder:FindFirstChild("ResultMode")
			local eliminated = playerFolder:FindFirstChild("Eliminated")
			local lastRoundKeys = playerFolder:FindFirstChild("LastRoundKeys")
			local lastRoundGears = playerFolder:FindFirstChild("LastRoundGears")
			if keys then
				keys.Value = 0
			end
			if gears then
				gears.Value = 0
			end
			if qualified then
				qualified.Value = false
			end
			if qualifiedAt then
				qualifiedAt.Value = 0
			end
			if placement then
				placement.Value = 0
			end
			if resultMode then
				resultMode.Value = "none"
			end
			if eliminated then
				eliminated.Value = false
			end
			if lastRoundKeys then
				lastRoundKeys.Value = 0
			end
			if lastRoundGears then
				lastRoundGears.Value = 0
			end
		end
	end
end

function PlayerStateService.SetValues(userId, patch)
	local playerFolder = PlayerStateService.GetPlayerFolderByUserId(userId)
	if not playerFolder or type(patch) ~= "table" then
		return false
	end

	for key, value in pairs(patch) do
		local node = playerFolder:FindFirstChild(key)
		if node and node:IsA("ValueBase") then
			node.Value = value
		end
	end

	return true
end

function PlayerStateService.SetQualified(userId, isQualified, qualifiedAtServerTime)
	local playerFolder = PlayerStateService.GetPlayerFolderByUserId(userId)
	if not playerFolder then
		return false
	end

	local qualified = playerFolder:FindFirstChild("Qualified")
	local qualifiedAt = playerFolder:FindFirstChild("QualifiedAtServerTime")
	if qualified then
		qualified.Value = isQualified == true
	end
	if qualifiedAt then
		qualifiedAt.Value = qualifiedAtServerTime or 0
	end
	return true
end

function PlayerStateService.GetKeys(userId)
	local playerFolder = PlayerStateService.GetPlayerFolderByUserId(userId)
	if not playerFolder then
		return 0
	end

	local keys = playerFolder:FindFirstChild("Keys")
	return keys and keys.Value or 0
end

function PlayerStateService.GetGears(userId)
	local playerFolder = PlayerStateService.GetPlayerFolderByUserId(userId)
	if not playerFolder then
		return 0
	end

	local gears = playerFolder:FindFirstChild("Gears")
	return gears and gears.Value or 0
end

function PlayerStateService.IncrementKeys(userId, amount)
	local playerFolder = PlayerStateService.GetPlayerFolderByUserId(userId)
	if not playerFolder then
		return 0
	end

	local keys = playerFolder:FindFirstChild("Keys")
	if not keys then
		return 0
	end

	keys.Value += amount or 1
	return keys.Value
end

function PlayerStateService.IncrementGears(userId, amount)
	local playerFolder = PlayerStateService.GetPlayerFolderByUserId(userId)
	if not playerFolder then
		return 0
	end

	local gears = playerFolder:FindFirstChild("Gears")
	if not gears then
		return 0
	end

	gears.Value += amount or 1
	return gears.Value
end

function PlayerStateService.Start()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerStateService.EnsurePlayerFolder(player)
	end

	Players.PlayerAdded:Connect(function(player)
		PlayerStateService.EnsurePlayerFolder(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local root = getPlayerStateRoot()
		local folder = root:FindFirstChild(tostring(player.UserId))
		if folder then
			folder:Destroy()
		end
	end)
end

return PlayerStateService
