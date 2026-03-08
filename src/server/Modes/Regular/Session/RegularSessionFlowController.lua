local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local MapRotationService = require(script.Parent.Parent:WaitForChild("Pregame"):WaitForChild("MapRotationService"))

local RegularSessionFlowController = {}

local function cloneUserIds(userIds)
	local out = {}
	for _, userId in ipairs(userIds or {}) do
		table.insert(out, userId)
	end
	return out
end

local function filterOnlineUserIds(userIds)
	local online = {}
	for _, userId in ipairs(userIds or {}) do
		if Players:GetPlayerByUserId(userId) then
			table.insert(online, userId)
		end
	end
	return online
end

local function emitTelemetry(eventName, payload)
	print(("[telemetry] %s %s"):format(eventName, HttpService:JSONEncode(payload or {})))
end

local function buildDefaultTournamentPath(entrantCount)
	local size = math.max(2, tonumber(entrantCount) or 2)
	return { size, 1 }
end

local function initializeSessionRun(session)
	session.startedAt = os.clock()
	session.initialEntrants = filterOnlineUserIds(cloneUserIds(session.currentEntrants))
	session.currentEntrants = cloneUserIds(session.initialEntrants)
	session.initialEntrantCount = #session.initialEntrants
	session.mapHistory = session.mapHistory or {}
	session.rounds = {}
	session.qualifiedByRound = {}
	session.eliminatedByRound = {}

	local tournamentPath = session.tournamentPath
	if type(tournamentPath) ~= "table" or #tournamentPath < 2 then
		tournamentPath = buildDefaultTournamentPath(session.initialEntrantCount)
		session.tournamentPath = tournamentPath
	end

	return tournamentPath
end

local function finalizeSessionRun(session, winnerUserId, dependencies)
	local queueService = dependencies.queueService
	local stateReplicator = dependencies.stateReplicator
	local persistenceAdapter = dependencies.persistenceAdapter
	local sessionTransportAdapter = dependencies.sessionTransportAdapter
	local regularStateController = dependencies.regularStateController

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
	session.roundCount = #session.rounds

	persistenceAdapter:SaveSessionResult(session)
	sessionTransportAdapter:EndSession(session.id)
	queueService.MarkSessionEnded(session.id)
	regularStateController.ResetToIdle()
	stateReplicator.PushLobbyStateToAllPlayers()
end

function RegularSessionFlowController.RunSession(session, dependencies)
	local queueService = dependencies.queueService
	local roundRuntimeService = dependencies.roundRuntimeService
	local stateReplicator = dependencies.stateReplicator
	local regularStateController = dependencies.regularStateController

	queueService.MarkSessionStarted(session.id)
	stateReplicator.PushLobbyStateToAllPlayers()

	emitTelemetry("session_created", {
		sessionId = session.id,
		entrants = #session.currentEntrants,
		targetLobbySize = session.targetLobbySize,
	})

	regularStateController.BeginSessionRun()

	local tournamentPath = initializeSessionRun(session)
	local winnerUserId = 0
	local totalRounds = math.max(1, #tournamentPath - 1)

	for stageIndex = 2, #tournamentPath do
		session.currentEntrants = filterOnlineUserIds(session.currentEntrants)
		if #session.currentEntrants == 0 then
			break
		end

		local roundIndex = stageIndex - 1
		local targetQualifiers = math.max(1, math.min(tournamentPath[stageIndex], #session.currentEntrants))
		local previousMapId = session.mapHistory[#session.mapHistory]
		local nextMapId = MapRotationService.SelectNextMap(previousMapId)

		local roundResult = roundRuntimeService.RunRound(session.id, {
			roundIndex = roundIndex,
			totalRounds = totalRounds,
			entrantUserIds = cloneUserIds(session.currentEntrants),
			targetQualifiers = targetQualifiers,
			mapId = nextMapId,
			isFinalRound = stageIndex == #tournamentPath or targetQualifiers == 1,
			sessionInitialEntrantCount = session.initialEntrantCount,
		})

		table.insert(session.rounds, roundResult)
		table.insert(session.mapHistory, roundResult.mapId or nextMapId)
		session.qualifiedByRound[roundIndex] = cloneUserIds(roundResult.qualifiedUserIds)
		session.eliminatedByRound[roundIndex] = cloneUserIds(roundResult.eliminatedUserIds)

		for _, eliminatedUserId in ipairs(roundResult.eliminatedUserIds or {}) do
			queueService.LeaveLobby(eliminatedUserId)
		end
		stateReplicator.PushLobbyStateToAllPlayers()

		emitTelemetry("round_ended", {
			sessionId = session.id,
			roundIndex = roundIndex,
			targetQualifiers = targetQualifiers,
			qualified = #(roundResult.qualifiedUserIds or {}),
			eliminated = #(roundResult.eliminatedUserIds or {}),
			endedBy = roundResult.endedBy,
			usedFallback = roundResult.usedFallback,
			mapId = roundResult.mapId,
		})

		session.currentEntrants = filterOnlineUserIds(cloneUserIds(roundResult.qualifiedUserIds))
		if roundResult.winnerUserId and roundResult.winnerUserId > 0 then
			winnerUserId = roundResult.winnerUserId
			break
		end
		if #session.currentEntrants <= 1 then
			winnerUserId = session.currentEntrants[1] or 0
			break
		end
	end

	finalizeSessionRun(session, winnerUserId, dependencies)
	return session
end

return RegularSessionFlowController
