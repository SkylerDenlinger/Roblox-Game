local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoundRules = require(Shared:WaitForChild("Config"):WaitForChild("RoundRules"))

local serverRoot = script.Parent.Parent.Parent

local PlayerStateService = require(serverRoot:WaitForChild("State"):WaitForChild("PlayerStateService"))
local MapManifestLoader = require(script.Parent:WaitForChild("Pregame"):WaitForChild("MapManifestLoader"))
local KeyCollectibleService = require(script.Parent:WaitForChild("Gameplay"):WaitForChild("KeyCollectibleService"))
local GearCollectibleService = require(script.Parent:WaitForChild("Gameplay"):WaitForChild("GearCollectibleService"))
local ExitDoorService = require(script.Parent:WaitForChild("Gameplay"):WaitForChild("ExitDoorService"))
local QualificationZoneService = require(script.Parent:WaitForChild("Gameplay"):WaitForChild("QualificationZoneService"))
local RoundLeaderboardService = require(script.Parent:WaitForChild("Gameplay"):WaitForChild("RoundLeaderboardService"))
local RegularRoundContext = require(script.Parent:WaitForChild("RegularRoundContext"))
local PregamePhase = require(script.Parent:WaitForChild("Pregame"):WaitForChild("PregamePhase"))
local GameplayPhase = require(script.Parent:WaitForChild("Gameplay"):WaitForChild("GameplayPhase"))
local EndingPhase = require(script.Parent:WaitForChild("Ending"):WaitForChild("EndingPhase"))

local RegularRoundRuntimeService = {}

local stateReplicator = nil
local activeRoundContext = nil

function RegularRoundRuntimeService.Start(options)
	options = options or {}
	stateReplicator = options.stateReplicator
	if not stateReplicator then
		error("RegularRoundRuntimeService.Start requires stateReplicator")
	end

	QualificationZoneService.SetQualificationHandler(function(userId, serverTimestamp)
		RegularRoundRuntimeService.TryQualifyPlayer(userId, serverTimestamp)
	end)
end

function RegularRoundRuntimeService.TryQualifyPlayer(userId, serverTimestamp)
	if not activeRoundContext then
		return false
	end
	return activeRoundContext:TryQualifyPlayer(userId, serverTimestamp)
end

function RegularRoundRuntimeService.RunRound(sessionId, roundSpec)
	if not stateReplicator then
		error("RegularRoundRuntimeService.RunRound called before Start")
	end

	local context = RegularRoundContext.new(sessionId, roundSpec, {
		roundRules = RoundRules,
		stateReplicator = stateReplicator,
		playerStateService = PlayerStateService,
		roundLeaderboardService = RoundLeaderboardService,
		exitDoorService = ExitDoorService,
	})

	activeRoundContext = context

	local function cleanup()
		KeyCollectibleService.EndRound()
		GearCollectibleService.EndRound()
		QualificationZoneService.EndRound()
		ExitDoorService.EndRound()
		stateReplicator.SetPresentationShowcaseIds({})
		context:DestroyArtifacts()
		activeRoundContext = nil
	end

	local ok, resultOrError = pcall(function()
		context:InitializeReplicatedState()

		PregamePhase.Run(context, {
			mapManifestLoader = MapManifestLoader,
			exitDoorService = ExitDoorService,
			qualificationZoneService = QualificationZoneService,
		})

		local gameplayOutcome = GameplayPhase.Run(context, {
			keyCollectibleService = KeyCollectibleService,
			gearCollectibleService = GearCollectibleService,
			exitDoorService = ExitDoorService,
			qualificationZoneService = QualificationZoneService,
		})

		local endingOutcome = EndingPhase.Run(context, gameplayOutcome)
		return {
			qualifiedUserIds = context:CloneUserIds(gameplayOutcome.qualifiedUserIds),
			eliminatedUserIds = context:CloneUserIds(endingOutcome.eliminatedUserIds),
			qualifiedOrder = context:CloneUserIds(context.qualifiedOrder),
			leaderboardEntries = gameplayOutcome.finalEntries,
			winnerUserId = endingOutcome.winnerUserId,
			endedBy = gameplayOutcome.endedBy,
			usedFallback = gameplayOutcome.usedFallback,
			mapId = context.manifest and context.manifest.id or context.mapId,
			playerStatsByUserId = endingOutcome.playerStatsByUserId,
		}
	end)

	cleanup()

	if not ok then
		error(resultOrError)
	end

	return resultOrError
end

return RegularRoundRuntimeService
