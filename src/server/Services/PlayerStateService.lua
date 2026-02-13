local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateService = {}

-- Utility: ensure folder exists
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

-- Utility: ensure value exists
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

function PlayerStateService.EnsurePlayerFolder(player)
	local stateRoot = ReplicatedStorage:WaitForChild("State")
	local playerStateRoot = stateRoot:WaitForChild("PlayerState")

	local playerFolder = ensureFolder(playerStateRoot, tostring(player.UserId))

	-- Core stats
	ensureValue(playerFolder, "IntValue", "Keys", 0)
	ensureValue(playerFolder, "IntValue", "Gears", 0)
	ensureValue(playerFolder, "IntValue", "Thrust", 100)

	-- Special moves folder
	local specials = ensureFolder(playerFolder, "SpecialMoves")
	ensureValue(specials, "BoolValue", "Move1Ready", true)
	ensureValue(specials, "BoolValue", "Move2Ready", true)

	return playerFolder
end

function PlayerStateService.Start()
	-- Existing players (important for Play Solo)
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerStateService.EnsurePlayerFolder(player)
	end

	-- New players
	Players.PlayerAdded:Connect(function(player)
		PlayerStateService.EnsurePlayerFolder(player)
	end)

	-- Cleanup on leave
	Players.PlayerRemoving:Connect(function(player)
		local stateRoot = ReplicatedStorage:WaitForChild("State")
		local playerStateRoot = stateRoot:WaitForChild("PlayerState")

		local folder = playerStateRoot:FindFirstChild(tostring(player.UserId))
		if folder then
			folder:Destroy()
		end
	end)
end

return PlayerStateService
