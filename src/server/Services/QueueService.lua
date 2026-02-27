local Players = game:GetService("Players")

local GameConfigService = require(script.Parent:WaitForChild("GameConfigService"))
local LocalQueueAdapter = require(script.Parent:WaitForChild("Adapters"):WaitForChild("LocalQueueAdapter"))
local MemoryStoreQueueAdapter = require(script.Parent:WaitForChild("Adapters"):WaitForChild("MemoryStoreQueueAdapter"))

local QueueService = {}

local QUEUE_MODE_PUBLIC = "Public"
local MIN_PLAYERS_TO_FORM_LOBBY = 2

local started = false
local backend = nil
local planner = nil
local identityResolver = nil
local version = 0
local targetLobbySize = 6
local queuePopulation = 0

local lobbiesById = {}
local lobbyIdByUserId = {}
local nextSessionId = 1

local function bumpVersion()
	version += 1
	return version
end

local function cloneUserIds(userIds)
	local copy = {}
	for _, userId in ipairs(userIds) do
		table.insert(copy, userId)
	end
	return copy
end

local function playerIdentityByUserId(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return {
			userId = userId,
			name = player.Name,
			displayName = player.DisplayName,
		}
	end

	if identityResolver then
		local resolved = identityResolver(userId)
		if type(resolved) == "table" then
			return {
				userId = resolved.userId or userId,
				name = resolved.name or tostring(userId),
				displayName = resolved.displayName or resolved.name or tostring(userId),
			}
		end
	end

	return {
		userId = userId,
		name = tostring(userId),
		displayName = tostring(userId),
	}
end

local function buildMemberIdentityList(userIds)
	local members = {}
	for _, userId in ipairs(userIds) do
		table.insert(members, playerIdentityByUserId(userId))
	end
	table.sort(members, function(a, b)
		local an = string.lower(a.displayName or a.name or "")
		local bn = string.lower(b.displayName or b.name or "")
		if an == bn then
			return (a.userId or 0) < (b.userId or 0)
		end
		return an < bn
	end)
	return members
end

local function removeLobby(lobbyId)
	local lobby = lobbiesById[lobbyId]
	if not lobby then
		return nil
	end
	lobbiesById[lobbyId] = nil
	for _, userId in ipairs(lobby.memberUserIds) do
		if lobbyIdByUserId[userId] == lobbyId then
			lobbyIdByUserId[userId] = nil
		end
	end
	return lobby
end

local function getQueueSnapshotForUserId(userId)
	local leaderUserId = backend:GetLeaderForUser(userId)
	if not leaderUserId then
		return nil
	end
	local entry = backend:GetEntryByLeader(leaderUserId)
	if not entry then
		return nil
	end
	return {
		leaderUserId = entry.leaderUserId,
		mode = entry.mode,
		queuedAt = entry.queuedAt,
		requiredPlayers = targetLobbySize,
		members = buildMemberIdentityList(entry.memberUserIds),
	}
end

local function getLobbySnapshotForUserId(userId)
	local lobbyId = lobbyIdByUserId[userId]
	if not lobbyId then
		return nil
	end
	local lobby = lobbiesById[lobbyId]
	if not lobby then
		return nil
	end
	return {
		id = lobby.id,
		leaderUserId = lobby.leaderUserId,
		status = lobby.status,
		createdAt = lobby.createdAt,
		requiredPlayers = lobby.targetLobbySize,
		tournamentPath = cloneUserIds(lobby.tournamentPath or {}),
		members = buildMemberIdentityList(lobby.memberUserIds),
	}
end

local function updateQueuePopulationFromBackend()
	queuePopulation = backend:GetPopulation()
end

local function buildSessionId()
	local id = ("S-%d"):format(nextSessionId)
	nextSessionId += 1
	return id
end

local function buildCurrentTournamentPathForPlayerContext(context, queueSnapshot, lobbySnapshot)
	if context == "lobby" and lobbySnapshot and type(lobbySnapshot.requiredPlayers) == "number" then
		local path = nil
		if type(lobbySnapshot.tournamentPath) == "table" and #lobbySnapshot.tournamentPath > 0 then
			path = cloneUserIds(lobbySnapshot.tournamentPath)
		else
			local lobbySize = #lobbySnapshot.members
			path = planner.BuildPath(lobbySize)
		end
		return path, planner.EstimatedRounds(path)
	end
	if context == "queued" and queueSnapshot then
		local path = planner.BuildPath(targetLobbySize)
		return path, planner.EstimatedRounds(path)
	end
	return nil, nil
end

function QueueService.Start(options)
	if started then
		return
	end
	started = true

	options = options or {}
	planner = options.planner
	if not planner then
		error("QueueService.Start requires planner")
	end

	local featureFlags = GameConfigService.GetFeatureFlags()
	if featureFlags.queue_backend == "memory_store" then
		backend = MemoryStoreQueueAdapter.new()
	else
		backend = LocalQueueAdapter.new()
	end

	updateQueuePopulationFromBackend()
	targetLobbySize = planner.ResolveTargetLobbySize(queuePopulation)
end

function QueueService.SetIdentityResolver(resolver)
	identityResolver = resolver
end

function QueueService.GetContextForUserId(userId)
	if lobbyIdByUserId[userId] then
		return "lobby"
	end
	if backend:GetLeaderForUser(userId) then
		return "queued"
	end
	return "none"
end

function QueueService.GetQueuePopulation()
	updateQueuePopulationFromBackend()
	return queuePopulation
end

function QueueService.GetTargetLobbySize()
	return targetLobbySize
end

function QueueService.SetTargetLobbySize(value)
	targetLobbySize = math.max(2, math.floor(value or 2))
end

function QueueService.JoinPublic(leaderUserId, memberUserIds)
	if type(leaderUserId) ~= "number" then
		return false, "Invalid leader."
	end
	if type(memberUserIds) ~= "table" or #memberUserIds == 0 then
		return false, "Invalid group."
	end
	if backend:GetEntryByLeader(leaderUserId) then
		return false, "Already queued."
	end
	for _, userId in ipairs(memberUserIds) do
		if QueueService.GetContextForUserId(userId) ~= "none" then
			return false, ("Player %d already queued or in lobby."):format(userId)
		end
	end

	local ok, err = backend:Join({
		leaderUserId = leaderUserId,
		mode = QUEUE_MODE_PUBLIC,
		memberUserIds = cloneUserIds(memberUserIds),
		queuedAt = os.clock(),
	})
	if not ok then
		return false, err
	end

	updateQueuePopulationFromBackend()
	targetLobbySize = planner.ResolveTargetLobbySize(queuePopulation)
	bumpVersion()
	return true
end

function QueueService.Cancel(leaderUserId)
	local removed = backend:Cancel(leaderUserId)
	if removed then
		updateQueuePopulationFromBackend()
		targetLobbySize = planner.ResolveTargetLobbySize(queuePopulation)
		bumpVersion()
	end
	return removed
end

function QueueService.LeaveLobby(userId)
	local lobbyId = lobbyIdByUserId[userId]
	if not lobbyId then
		return nil
	end
	local lobby = lobbiesById[lobbyId]
	if not lobby then
		lobbyIdByUserId[userId] = nil
		return nil
	end

	for i = #lobby.memberUserIds, 1, -1 do
		if lobby.memberUserIds[i] == userId then
			table.remove(lobby.memberUserIds, i)
			break
		end
	end
	lobbyIdByUserId[userId] = nil

	if #lobby.memberUserIds == 0 then
		removeLobby(lobbyId)
	else
		if lobby.leaderUserId == userId then
			lobby.leaderUserId = lobby.memberUserIds[1]
		end
	end

	bumpVersion()
	return lobby
end

function QueueService.OnPlayerRemoving(userId)
	local queueRemoved = backend:RemovePlayer(userId)
	local lobbyRemoved = QueueService.LeaveLobby(userId)
	if queueRemoved or lobbyRemoved then
		updateQueuePopulationFromBackend()
		targetLobbySize = planner.ResolveTargetLobbySize(queuePopulation)
		bumpVersion()
	end
	return queueRemoved, lobbyRemoved
end

function QueueService.TryFormSessions(now)
	updateQueuePopulationFromBackend()
	targetLobbySize = planner.ResolveTargetLobbySize(queuePopulation)

	local lockToken = backend:AcquireFormationLock()
	if not lockToken then
		return {}
	end

	local formed = {}
	local leaders = backend:GetOrderedLeaders()
	local i = 1

	while i <= #leaders do
		local selectedEntries = {}
		local selectedCount = 0
		local j = i

		while j <= #leaders do
			local entry = backend:GetEntryByLeader(leaders[j])
			if entry then
				local entryCount = #entry.memberUserIds
				if entryCount > targetLobbySize then
					backend:Cancel(entry.leaderUserId)
				elseif selectedCount + entryCount <= targetLobbySize then
					table.insert(selectedEntries, entry)
					selectedCount += entryCount
				else
					break
				end
			end
			j += 1
		end

		local exhausted = j > #leaders
		local canForm = selectedCount >= MIN_PLAYERS_TO_FORM_LOBBY and (selectedCount >= targetLobbySize or exhausted)
		if canForm then
			local memberUserIds = {}
			for _, entry in ipairs(selectedEntries) do
				backend:Cancel(entry.leaderUserId)
				for _, userId in ipairs(entry.memberUserIds) do
					table.insert(memberUserIds, userId)
				end
			end

			local sessionId = buildSessionId()
			local tournamentPath = planner.BuildPath(#memberUserIds)
			local lobby = {
				id = sessionId,
				status = "Formed",
				createdAt = now or os.clock(),
				targetLobbySize = targetLobbySize,
				leaderUserId = selectedEntries[1].leaderUserId,
				memberUserIds = memberUserIds,
				tournamentPath = tournamentPath,
			}
			lobbiesById[sessionId] = lobby
			for _, userId in ipairs(memberUserIds) do
				lobbyIdByUserId[userId] = sessionId
			end

			table.insert(formed, {
				sessionId = sessionId,
				mode = QUEUE_MODE_PUBLIC,
				leaderUserId = lobby.leaderUserId,
				memberUserIds = cloneUserIds(memberUserIds),
				targetLobbySize = targetLobbySize,
				queuePopulation = queuePopulation,
				tournamentPath = tournamentPath,
				estimatedRounds = planner.EstimatedRounds(tournamentPath),
				createdAt = lobby.createdAt,
			})

			i = j
		else
			break
		end
	end

	updateQueuePopulationFromBackend()
	targetLobbySize = planner.ResolveTargetLobbySize(queuePopulation)
	if #formed > 0 then
		bumpVersion()
	end
	backend:ReleaseFormationLock(lockToken)
	return formed
end

function QueueService.MarkSessionStarted(sessionId)
	local lobby = lobbiesById[sessionId]
	if lobby then
		lobby.status = "InProgress"
		bumpVersion()
	end
end

function QueueService.MarkSessionEnded(sessionId)
	if removeLobby(sessionId) then
		bumpVersion()
	end
end

function QueueService.BuildLobbyStateForPlayer(player)
	updateQueuePopulationFromBackend()
	targetLobbySize = planner.ResolveTargetLobbySize(queuePopulation)

	local context = QueueService.GetContextForUserId(player.UserId)
	local queueSnapshot = getQueueSnapshotForUserId(player.UserId)
	local lobbySnapshot = getLobbySnapshotForUserId(player.UserId)
	local tournamentPath, estimatedRounds = buildCurrentTournamentPathForPlayerContext(context, queueSnapshot, lobbySnapshot)
	local sessionId = lobbySnapshot and lobbySnapshot.id or nil

	return {
		version = version,
		context = context,
		queuePopulation = queuePopulation,
		targetLobbySize = targetLobbySize,
		tournamentPath = tournamentPath,
		estimatedRounds = estimatedRounds,
		sessionId = sessionId,
		queue = queueSnapshot,
		lobby = lobbySnapshot,
	}
end

function QueueService.Shutdown()
	local leaders = backend:GetOrderedLeaders()
	for _, leaderUserId in ipairs(leaders) do
		backend:Cancel(leaderUserId)
	end
	for lobbyId in pairs(lobbiesById) do
		removeLobby(lobbyId)
	end
	updateQueuePopulationFromBackend()
	targetLobbySize = planner.ResolveTargetLobbySize(queuePopulation)
	bumpVersion()
end

return QueueService
