local Players = game:GetService("Players")

local serverRoot = script.Parent.Parent.Parent.Parent
local PlayerStateService = require(serverRoot:WaitForChild("State"):WaitForChild("PlayerStateService"))

local RoundLeaderboardService = {}

local function resolveDisplayName(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName or player.Name
	end
	return tostring(userId)
end

local function compareEntries(a, b)
	if a.qualified ~= b.qualified then
		return a.qualified == true
	end
	if a.qualified and b.qualified then
		local aTime = a.qualifiedAtServerTime or math.huge
		local bTime = b.qualifiedAtServerTime or math.huge
		if aTime ~= bTime then
			return aTime < bTime
		end
		return a.userId < b.userId
	end
	if a.keys ~= b.keys then
		return a.keys > b.keys
	end
	if a.gears ~= b.gears then
		return a.gears > b.gears
	end
	local aFirst = a.firstKeyAtServerTime or math.huge
	local bFirst = b.firstKeyAtServerTime or math.huge
	if aFirst ~= bFirst then
		return aFirst < bFirst
	end
	return a.userId < b.userId
end

function RoundLeaderboardService.BuildEntries(entrantUserIds, options)
	options = options or {}
	local qualifiedAtByUserId = options.qualifiedAtByUserId or {}
	local firstKeyAtByUserId = options.firstKeyAtByUserId or {}
	local keyCountByUserId = options.keyCountByUserId or {}
	local gearCountByUserId = options.gearCountByUserId or {}
	local entries = {}

	for _, userId in ipairs(entrantUserIds or {}) do
		local qualifiedAt = qualifiedAtByUserId[userId]
		local keys = keyCountByUserId[userId]
		if keys == nil then
			keys = PlayerStateService.GetKeys(userId)
		end
		local gears = gearCountByUserId[userId]
		if gears == nil then
			gears = PlayerStateService.GetGears(userId)
		end
		table.insert(entries, {
			userId = userId,
			displayName = resolveDisplayName(userId),
			keys = keys or 0,
			gears = gears or 0,
			qualified = qualifiedAt ~= nil,
			qualifiedAtServerTime = qualifiedAt or 0,
			firstKeyAtServerTime = firstKeyAtByUserId[userId] or 0,
			isOnline = Players:GetPlayerByUserId(userId) ~= nil,
		})
	end

	table.sort(entries, compareEntries)
	for index, entry in ipairs(entries) do
		entry.rank = index
	end

	return entries
end

function RoundLeaderboardService.SelectFallbackQualifiers(entries, alreadyQualifiedUserIds, countNeeded)
	local qualifiers = {}
	local qualifiedSet = {}
	for _, userId in ipairs(alreadyQualifiedUserIds or {}) do
		qualifiedSet[userId] = true
	end
	for _, entry in ipairs(entries or {}) do
		if #qualifiers >= countNeeded then
			break
		end
		if entry.isOnline ~= false and not qualifiedSet[entry.userId] then
			qualifiedSet[entry.userId] = true
			table.insert(qualifiers, entry.userId)
		end
	end
	return qualifiers
end

return RoundLeaderboardService
