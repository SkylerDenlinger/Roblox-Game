local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateService = {}

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	if f then
		f:Destroy()
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function ensureValue(parent, className, name, defaultValue)
	local v = parent:FindFirstChild(name)
	if v and v.ClassName == className then
		return v
	end
	if v then
		v:Destroy()
	end
	v = Instance.new(className)
	v.Name = name
	v.Value = defaultValue
	v.Parent = parent
	return v
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
		end
	end
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
