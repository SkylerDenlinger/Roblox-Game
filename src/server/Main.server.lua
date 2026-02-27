local ServerScriptService = game:GetService("ServerScriptService")

if _G.__ROBLOX_GAME_MAIN_BOOTSTRAPPED then
	return
end
_G.__ROBLOX_GAME_MAIN_BOOTSTRAPPED = true

local serverRoot = ServerScriptService:WaitForChild("Server")
local services = serverRoot:WaitForChild("Services")

local StateContract = require(services:WaitForChild("StateContract"))
local GameConfigService = require(services:WaitForChild("GameConfigService"))
local StateReplicator = require(services:WaitForChild("StateReplicator"))
local PlayerStateService = require(services:WaitForChild("PlayerStateService"))
local PartyService = require(services:WaitForChild("PartyService"))
local QueueService = require(services:WaitForChild("QueueService"))
local QueueGatewayService = require(services:WaitForChild("QueueGatewayService"))
local TournamentPlanner = require(services:WaitForChild("TournamentPlanner"))
local MatchmakerService = require(services:WaitForChild("MatchmakerService"))
local SessionManager = require(services:WaitForChild("SessionManager"))
local RoundRuntimeService = require(services:WaitForChild("RoundRuntimeService"))
local FillLobbyService = require(serverRoot:WaitForChild("FillLobby"):WaitForChild("FillLobbyService"))

local InServerSessionAdapter = require(services:WaitForChild("Adapters"):WaitForChild("InServerSessionAdapter"))
local TeleportSessionAdapter = require(services:WaitForChild("Adapters"):WaitForChild("TeleportSessionAdapter"))
local PersistenceAdapter = require(services:WaitForChild("Adapters"):WaitForChild("PersistenceAdapter"))

StateContract.Ensure()
StateReplicator.Start()
PlayerStateService.Start()
PartyService.Start()

QueueService.Start({
	planner = TournamentPlanner,
})
QueueService.SetIdentityResolver(function(userId)
	return FillLobbyService.ResolveIdentity(userId)
end)

RoundRuntimeService.Start({
	stateReplicator = StateReplicator,
})

local featureFlags = GameConfigService.GetFeatureFlags()
local sessionTransportAdapter = nil
if featureFlags.session_transport == "teleport" then
	sessionTransportAdapter = TeleportSessionAdapter.new()
else
	sessionTransportAdapter = InServerSessionAdapter.new()
end

SessionManager.Start({
	queueService = QueueService,
	roundRuntimeService = RoundRuntimeService,
	stateReplicator = StateReplicator,
	sessionTransportAdapter = sessionTransportAdapter,
	persistenceAdapter = PersistenceAdapter.new(),
})

QueueGatewayService.Start({
	queueService = QueueService,
	partyService = PartyService,
	stateReplicator = StateReplicator,
	fillLobbyService = FillLobbyService,
})

MatchmakerService.Start({
	queueService = QueueService,
	sessionManager = SessionManager,
	stateReplicator = StateReplicator,
})

StateReplicator.BeginRun("FFA")
StateReplicator.BeginPhase("Lobby", 0, {
	SessionId = "",
	EntrantCount = 0,
	RoundTargetQualifiers = 0,
})

game:BindToClose(function()
	QueueService.Shutdown()
end)
