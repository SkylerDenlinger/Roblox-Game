local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

local LocalQueueAdapter = require(script.Parent:WaitForChild("LocalQueueAdapter"))

local MemoryStoreQueueAdapter = {}
MemoryStoreQueueAdapter.__index = MemoryStoreQueueAdapter

local COUNT_KEY = "public_queue_population"
local LOCK_KEY = "public_queue_matchmaker_lock"
local COUNT_TTL_SECONDS = 90
local LOCK_TTL_SECONDS = 6

local function nowEpochSeconds()
	return os.time()
end

local function randomToken()
	return ("%s:%d:%d"):format(game.JobId, nowEpochSeconds(), math.random(100000, 999999))
end

local function safeUpdateAsync(sortedMap, key, transform, ttlSeconds)
	local ok, result = pcall(function()
		return sortedMap:UpdateAsync(key, transform, ttlSeconds)
	end)
	if ok then
		return true, result
	end
	return false, result
end

local function safeGetAsync(sortedMap, key)
	local ok, result = pcall(function()
		return sortedMap:GetAsync(key)
	end)
	if ok then
		return result
	end
	return nil
end

function MemoryStoreQueueAdapter.new()
	local self = setmetatable({}, MemoryStoreQueueAdapter)
	self.localAdapter = LocalQueueAdapter.new()
	self.sortedMap = nil
	self.disabled = false

	local ok, result = pcall(function()
		return MemoryStoreService:GetSortedMap("roblox_game_public_queue")
	end)
	if ok then
		self.sortedMap = result
	else
		self.disabled = true
		if RunService:IsStudio() then
			warn(("MemoryStoreQueueAdapter disabled: %s"):format(tostring(result)))
		end
	end

	return self
end

function MemoryStoreQueueAdapter:_applyPopulationDelta(delta)
	if self.disabled or not self.sortedMap then
		return
	end
	safeUpdateAsync(self.sortedMap, COUNT_KEY, function(oldValue)
		local previous = tonumber(oldValue) or 0
		local nextValue = math.max(0, previous + delta)
		return nextValue
	end, COUNT_TTL_SECONDS)
end

function MemoryStoreQueueAdapter:GetPopulation()
	local localPopulation = self.localAdapter:GetPopulation()
	if self.disabled or not self.sortedMap then
		return localPopulation
	end
	local globalCount = tonumber(safeGetAsync(self.sortedMap, COUNT_KEY) or 0) or 0
	if globalCount <= 0 then
		return localPopulation
	end
	return math.max(localPopulation, globalCount)
end

function MemoryStoreQueueAdapter:GetLeaderForUser(userId)
	return self.localAdapter:GetLeaderForUser(userId)
end

function MemoryStoreQueueAdapter:GetEntryByLeader(leaderUserId)
	return self.localAdapter:GetEntryByLeader(leaderUserId)
end

function MemoryStoreQueueAdapter:GetOrderedLeaders()
	return self.localAdapter:GetOrderedLeaders()
end

function MemoryStoreQueueAdapter:Join(entry)
	local ok, err = self.localAdapter:Join(entry)
	if not ok then
		return false, err
	end
	self:_applyPopulationDelta(#entry.memberUserIds)
	return true
end

function MemoryStoreQueueAdapter:Cancel(leaderUserId)
	local removed = self.localAdapter:Cancel(leaderUserId)
	if removed then
		self:_applyPopulationDelta(-#removed.memberUserIds)
	end
	return removed
end

function MemoryStoreQueueAdapter:RemovePlayer(userId)
	local removed = self.localAdapter:RemovePlayer(userId)
	if removed then
		self:_applyPopulationDelta(-#removed.memberUserIds)
	end
	return removed
end

function MemoryStoreQueueAdapter:AcquireFormationLock()
	if self.disabled or not self.sortedMap then
		return "local-lock"
	end
	local token = randomToken()
	local ok, result = safeUpdateAsync(self.sortedMap, LOCK_KEY, function(oldValue)
		local now = nowEpochSeconds()
		if type(oldValue) == "table" then
			local expiresAt = tonumber(oldValue.expiresAt) or 0
			if expiresAt > now and oldValue.token ~= token then
				return oldValue
			end
		end
		return {
			token = token,
			expiresAt = now + LOCK_TTL_SECONDS,
		}
	end, LOCK_TTL_SECONDS)
	if not ok then
		return nil
	end
	if type(result) == "table" and result.token == token then
		return token
	end
	return nil
end

function MemoryStoreQueueAdapter:ReleaseFormationLock(token)
	if self.disabled or not self.sortedMap or not token then
		return
	end
	safeUpdateAsync(self.sortedMap, LOCK_KEY, function(oldValue)
		if type(oldValue) == "table" and oldValue.token == token then
			return nil
		end
		return oldValue
	end, 1)
end

return MemoryStoreQueueAdapter
