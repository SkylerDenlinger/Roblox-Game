local LocalQueueAdapter = {}
LocalQueueAdapter.__index = LocalQueueAdapter

local function cloneUserIds(source)
	local out = {}
	for _, userId in ipairs(source) do
		table.insert(out, userId)
	end
	return out
end

function LocalQueueAdapter.new()
	local self = setmetatable({}, LocalQueueAdapter)
	self.entriesByLeaderUserId = {}
	self.queueOrder = {}
	self.queueLeaderByUserId = {}
	return self
end

function LocalQueueAdapter:GetPopulation()
	local total = 0
	for _, leaderUserId in ipairs(self.queueOrder) do
		local entry = self.entriesByLeaderUserId[leaderUserId]
		if entry then
			total += #entry.memberUserIds
		end
	end
	return total
end

function LocalQueueAdapter:GetLeaderForUser(userId)
	return self.queueLeaderByUserId[userId]
end

function LocalQueueAdapter:GetEntryByLeader(leaderUserId)
	return self.entriesByLeaderUserId[leaderUserId]
end

function LocalQueueAdapter:GetOrderedLeaders()
	local leaders = {}
	for _, leaderUserId in ipairs(self.queueOrder) do
		if self.entriesByLeaderUserId[leaderUserId] then
			table.insert(leaders, leaderUserId)
		end
	end
	return leaders
end

function LocalQueueAdapter:Join(entry)
	local leaderUserId = entry.leaderUserId
	if self.entriesByLeaderUserId[leaderUserId] then
		return false, "Already queued."
	end

	self.entriesByLeaderUserId[leaderUserId] = {
		leaderUserId = leaderUserId,
		mode = entry.mode,
		memberUserIds = cloneUserIds(entry.memberUserIds),
		queuedAt = entry.queuedAt,
	}
	table.insert(self.queueOrder, leaderUserId)
	for _, userId in ipairs(entry.memberUserIds) do
		self.queueLeaderByUserId[userId] = leaderUserId
	end
	return true
end

function LocalQueueAdapter:Cancel(leaderUserId)
	local entry = self.entriesByLeaderUserId[leaderUserId]
	if not entry then
		return nil
	end

	self.entriesByLeaderUserId[leaderUserId] = nil
	for i = #self.queueOrder, 1, -1 do
		if self.queueOrder[i] == leaderUserId then
			table.remove(self.queueOrder, i)
			break
		end
	end
	for _, userId in ipairs(entry.memberUserIds) do
		if self.queueLeaderByUserId[userId] == leaderUserId then
			self.queueLeaderByUserId[userId] = nil
		end
	end
	return entry
end

function LocalQueueAdapter:RemovePlayer(userId)
	local leaderUserId = self.queueLeaderByUserId[userId]
	if not leaderUserId then
		return nil
	end
	return self:Cancel(leaderUserId)
end

function LocalQueueAdapter:AcquireFormationLock()
	return "local-lock"
end

function LocalQueueAdapter:ReleaseFormationLock(_token)
	return
end

return LocalQueueAdapter
