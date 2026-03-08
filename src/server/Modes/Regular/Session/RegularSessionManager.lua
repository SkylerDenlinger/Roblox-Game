local RegularSessionFlowController = require(script.Parent:WaitForChild("RegularSessionFlowController"))
local RegularStateController = require(script.Parent.Parent:WaitForChild("State"):WaitForChild("RegularStateController"))

local RegularSessionManager = {}

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
	for _, userId in ipairs(userIds or {}) do
		table.insert(out, userId)
	end
	return out
end

local function buildSessionRecord(sessionSpec)
	local entrants = cloneUserIds(sessionSpec.memberUserIds or {})
	return {
		id = sessionSpec.sessionId,
		mode = sessionSpec.mode,
		targetLobbySize = sessionSpec.targetLobbySize,
		queuePopulation = sessionSpec.queuePopulation,
		oldestQueueAgeSeconds = sessionSpec.oldestQueueAgeSeconds or 0,
		tournamentPath = sessionSpec.tournamentPath,
		estimatedRounds = sessionSpec.estimatedRounds,
		initialLobbySize = #entrants,
		currentEntrants = entrants,
		createdAt = sessionSpec.createdAt or os.clock(),
	}
end

local function ensureRunner()
	if runnerActive then
		return
	end

	runnerActive = true
	task.spawn(function()
		while #pendingSessions > 0 do
			local session = table.remove(pendingSessions, 1)
			RegularSessionFlowController.RunSession(session, {
				queueService = queueService,
				roundRuntimeService = roundRuntimeService,
				stateReplicator = stateReplicator,
				sessionTransportAdapter = sessionTransportAdapter,
				persistenceAdapter = persistenceAdapter,
				regularStateController = RegularStateController,
			})
			sessionsById[session.id] = nil
		end
		runnerActive = false
	end)
end

function RegularSessionManager.Start(options)
	options = options or {}
	queueService = options.queueService
	roundRuntimeService = options.roundRuntimeService
	stateReplicator = options.stateReplicator
	sessionTransportAdapter = options.sessionTransportAdapter
	persistenceAdapter = options.persistenceAdapter

	if not queueService or not roundRuntimeService or not stateReplicator then
		error("RegularSessionManager.Start missing required dependencies")
	end
	if not sessionTransportAdapter then
		error("RegularSessionManager.Start requires sessionTransportAdapter")
	end
	if not persistenceAdapter then
		error("RegularSessionManager.Start requires persistenceAdapter")
	end
end

function RegularSessionManager.StartSession(sessionSpec)
	if type(sessionSpec) ~= "table" then
		return false, "Invalid session spec."
	end
	if sessionsById[sessionSpec.sessionId] then
		return false, "Session already exists."
	end

	local accepted = sessionTransportAdapter:StartSession(sessionSpec)
	if accepted == false then
		-- Transport adapter refusal falls back to the in-server session flow.
	end

	local session = buildSessionRecord(sessionSpec)
	sessionsById[session.id] = session
	table.insert(pendingSessions, session)
	ensureRunner()
	return true
end

function RegularSessionManager.GetSession(sessionId)
	return sessionsById[sessionId]
end

return RegularSessionManager
