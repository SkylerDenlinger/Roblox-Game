local serverRoot = script.Parent.Parent

local SessionStateController = require(serverRoot:WaitForChild("State"):WaitForChild("SessionStateController"))
local GameConfigService = require(serverRoot:WaitForChild("Config"):WaitForChild("GameConfigService"))
local PartyService = require(serverRoot:WaitForChild("Social"):WaitForChild("PartyService"))

local matchmakingRoot = serverRoot:WaitForChild("Matchmaking")
local QueueService = require(matchmakingRoot:WaitForChild("QueueService"))
local QueueGatewayService = require(matchmakingRoot:WaitForChild("QueueGatewayService"))
local TournamentPlanner = require(matchmakingRoot:WaitForChild("TournamentPlanner"))
local MatchmakerService = require(matchmakingRoot:WaitForChild("MatchmakerService"))

local regularRoot = serverRoot:WaitForChild("Modes"):WaitForChild("Regular")
local RegularRoundRuntimeService = require(regularRoot:WaitForChild("RegularRoundRuntimeService"))
local RegularSessionManager = require(regularRoot:WaitForChild("Session"):WaitForChild("RegularSessionManager"))
local RegularStateController = require(regularRoot:WaitForChild("State"):WaitForChild("RegularStateController"))

local FillLobbyService = require(serverRoot:WaitForChild("FillLobby"):WaitForChild("FillLobbyService"))

local matchmakingAdapters = matchmakingRoot:WaitForChild("Adapters")
local InServerSessionAdapter = require(matchmakingAdapters:WaitForChild("InServerSessionAdapter"))
local TeleportSessionAdapter = require(matchmakingAdapters:WaitForChild("TeleportSessionAdapter"))
local PersistenceAdapter = require(matchmakingAdapters:WaitForChild("PersistenceAdapter"))

local ServerBootstrap = {}

local started = false

function ServerBootstrap.Start()
	if started or _G.__ROBLOX_GAME_MAIN_BOOTSTRAPPED then
		return
	end
	started = true
	_G.__ROBLOX_GAME_MAIN_BOOTSTRAPPED = true

	SessionStateController.Start()
	local stateReplicator = SessionStateController.GetReplicator()

	PartyService.Start()

	QueueService.Start({
		planner = TournamentPlanner,
	})
	QueueService.SetIdentityResolver(function(userId)
		return FillLobbyService.ResolveIdentity(userId)
	end)

	RegularRoundRuntimeService.Start({
		stateReplicator = stateReplicator,
	})

	local featureFlags = GameConfigService.GetFeatureFlags()
	local sessionTransportAdapter = nil
	if featureFlags.session_transport == "teleport" then
		sessionTransportAdapter = TeleportSessionAdapter.new()
	else
		sessionTransportAdapter = InServerSessionAdapter.new()
	end

	RegularSessionManager.Start({
		queueService = QueueService,
		roundRuntimeService = RegularRoundRuntimeService,
		stateReplicator = stateReplicator,
		sessionTransportAdapter = sessionTransportAdapter,
		persistenceAdapter = PersistenceAdapter.new(),
	})

	QueueGatewayService.Start({
		queueService = QueueService,
		partyService = PartyService,
		stateReplicator = stateReplicator,
		fillLobbyService = FillLobbyService,
	})

	MatchmakerService.Start({
		queueService = QueueService,
		sessionManager = RegularSessionManager,
		stateReplicator = stateReplicator,
	})

	RegularStateController.BeginIdleRun()

	game:BindToClose(function()
		QueueService.Shutdown()
	end)
end

return ServerBootstrap
