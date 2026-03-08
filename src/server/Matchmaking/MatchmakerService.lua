local MatchmakerService = {}

local queueService = nil
local sessionManager = nil
local stateReplicator = nil
local started = false

local MATCHMAKER_TICK_SECONDS = 0.5

function MatchmakerService.Start(options)
	if started then
		return
	end
	started = true
	options = options or {}

	queueService = options.queueService
	sessionManager = options.sessionManager
	stateReplicator = options.stateReplicator

	if not queueService or not sessionManager then
		error("MatchmakerService.Start requires queueService and sessionManager")
	end

	task.spawn(function()
		while true do
			local formed = MatchmakerService.Tick(os.clock())
			if #formed > 0 and stateReplicator then
				stateReplicator.PushLobbyStateToAllPlayers()
			end
			task.wait(MATCHMAKER_TICK_SECONDS)
		end
	end)
end

function MatchmakerService.Tick(now)
	local formedSessions = queueService.TryFormSessions(now)
	for _, sessionSpec in ipairs(formedSessions) do
		sessionManager.StartSession(sessionSpec)
	end
	return formedSessions
end

return MatchmakerService
