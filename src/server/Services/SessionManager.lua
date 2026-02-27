local Players = game:GetService("Players")

local SessionManager = {}

local queueService = nil
local roundRuntimeService = nil
local stateReplicator = nil
local sessionTransportAdapter = nil
local persistenceAdapter = nil

local sessionsById = {}
local pendingSessions = {}
local runnerActive = false

local function cloneUserIds(userIds)
	local out = {}
	for _, userId in ipairs(userIds) do
		table.insert(out, userId)
	end
	return out
end

local function filterOnlineUserIds(userIds)
	local online = {}
	for _, userId in ipairs(userIds) do
		if Players:GetPlayerByUserId(userId) then
			table.insert(online, userId)
		end
	end
	return online
end

local function emitTelemetry(eventName, payload)
	print(("[telemetry] %s %s"):format(eventName, game:GetService("HttpService"):JSONEncode(payload or {})))
end

local function runSession(session)
	queueService.MarkSessionStarted(session.id)
	stateReplicator.PushLobbyStateToAllPlayers()

	emitTelemetry("session_created", {
		sessionId = session.id,
		entrants = #session.currentEntrants,
		targetLobbySize = session.targetLobbySize,
	})

	stateReplicator.BeginRun("FFA")
	local path = session.tournamentPath or {}
	local currentEntrants = filterOnlineUserIds(cloneUserIds(session.currentEntrants))
	local winnerUserId = 0

	for stageIndex = 2, #path do
		currentEntrants = filterOnlineUserIds(currentEntrants)
		if #currentEntrants == 0 then
			break
		end
		local targetQualifiers = math.max(1, math.min(path[stageIndex], #currentEntrants))
		local roundResult = roundRuntimeService.RunRound(session.id, {
			roundIndex = stageIndex - 1,
			entrantUserIds = currentEntrants,
			targetQualifiers = targetQualifiers,
			mapId = session.mapId,
		})

		emitTelemetry("round_ended", {
			sessionId = session.id,
			roundIndex = stageIndex - 1,
			targetQualifiers = targetQualifiers,
			qualified = #roundResult.qualifiedUserIds,
			endedBy = roundResult.endedBy,
			usedFallback = roundResult.usedFallback,
		})

		currentEntrants = cloneUserIds(roundResult.qualifiedUserIds)
		if targetQualifiers == 1 and #currentEntrants > 0 then
			winnerUserId = currentEntrants[1]
			break
		end
		if #currentEntrants <= 1 then
			winnerUserId = currentEntrants[1] or 0
			break
		end
		stateReplicator.NextRoundIndex()
	end

	if winnerUserId > 0 then
		stateReplicator.SetProgressValues({
			WinnerUserId = winnerUserId,
		})
		emitTelemetry("session_winner", {
			sessionId = session.id,
			winnerUserId = winnerUserId,
		})
	end

	session.completedAt = os.clock()
	session.winnerUserId = winnerUserId
	session.roundCount = math.max(0, #session.tournamentPath - 1)
	persistenceAdapter:SaveSessionResult(session)
	sessionTransportAdapter:EndSession(session.id)
	queueService.MarkSessionEnded(session.id)
	sessionsById[session.id] = nil

	stateReplicator.SetMatchValues({
		SessionId = "",
		EntrantCount = 0,
		RoundTargetQualifiers = 0,
	})
	stateReplicator.PushLobbyStateToAllPlayers()
end

local function ensureRunner()
	if runnerActive then
		return
	end
	runnerActive = true
	task.spawn(function()
		while #pendingSessions > 0 do
			local session = table.remove(pendingSessions, 1)
			runSession(session)
		end
		runnerActive = false
	end)
end

function SessionManager.Start(options)
	options = options or {}
	queueService = options.queueService
	roundRuntimeService = options.roundRuntimeService
	stateReplicator = options.stateReplicator
	sessionTransportAdapter = options.sessionTransportAdapter
	persistenceAdapter = options.persistenceAdapter

	if not queueService or not roundRuntimeService or not stateReplicator then
		error("SessionManager.Start missing required dependencies")
	end
	if not sessionTransportAdapter then
		error("SessionManager.Start requires sessionTransportAdapter")
	end
	if not persistenceAdapter then
		error("SessionManager.Start requires persistenceAdapter")
	end
end

function SessionManager.StartSession(sessionSpec)
	if type(sessionSpec) ~= "table" then
		return false, "Invalid session spec."
	end
	if sessionsById[sessionSpec.sessionId] then
		return false, "Session already exists."
	end

	local accepted = sessionTransportAdapter:StartSession(sessionSpec)
	if accepted == false then
		-- Transport adapter can refuse a staged flow (for example teleport disabled).
		-- Session continues in the active server runtime.
	end

	local session = {
		id = sessionSpec.sessionId,
		mode = sessionSpec.mode,
		targetLobbySize = sessionSpec.targetLobbySize,
		queuePopulation = sessionSpec.queuePopulation,
		tournamentPath = sessionSpec.tournamentPath,
		estimatedRounds = sessionSpec.estimatedRounds,
		currentEntrants = cloneUserIds(sessionSpec.memberUserIds or {}),
		createdAt = sessionSpec.createdAt or os.clock(),
		mapId = sessionSpec.mapId,
	}

	sessionsById[session.id] = session
	table.insert(pendingSessions, session)
	ensureRunner()
	return true
end

function SessionManager.GetSession(sessionId)
	return sessionsById[sessionId]
end

return SessionManager
