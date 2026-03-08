local GameplayPhase = {}

local function startCollectibles(context, services)
	services.keyCollectibleService.StartRound({
		spawnPlan = context.spawnPlan.keySpawnPlan,
		isPlayerAllowed = function(userId)
			return context.entrants[userId] == true
		end,
		onCollected = function(userId, collectedAt, keysCount)
			context:HandleKeyCollected(userId, collectedAt, keysCount)
		end,
	})

	services.gearCollectibleService.StartRound({
		spawnPlan = context.spawnPlan.gearSpawnPlan,
		isPlayerAllowed = function(userId)
			return context.entrants[userId] == true
		end,
		onCollected = function(userId, _collectedAt, gearsCount)
			context:HandleGearCollected(userId, gearsCount)
		end,
	})
end

local function stopCollectibles(services)
	services.keyCollectibleService.EndRound()
	services.gearCollectibleService.EndRound()
end

function GameplayPhase.Run(context, services)
	local durations = context.phaseDurations

	services.exitDoorService.StartRound({
		requiredKeys = context.requiredKeys,
		entrantUserIds = context.entrantUserIds,
	})
	services.qualificationZoneService.StartRound({
		entrantUserIds = context.entrantUserIds,
	})
	startCollectibles(context, services)

	context:SetPhase("Collectathon", durations.Collectathon, nil, {
		Phase = "Collectathon",
		PrimaryText = "Collectathon",
		SecondaryText = ("%d qualify | %d keys"):format(context.targetQualifiers, context.requiredKeys),
		Message = "Race to the exit.",
	})

	local endedBy = "Timeout"
	local collectathonEnd = os.clock() + durations.Collectathon
	local leaderboardRefreshAt = 0
	while os.clock() < collectathonEnd do
		if #context.qualifiedOrder >= context.targetQualifiers then
			endedBy = "QualifyCountReached"
			break
		end
		if os.clock() >= leaderboardRefreshAt then
			context:RefreshLeaderboardState()
			leaderboardRefreshAt = os.clock() + (context.roundRules.Leaderboard.RefreshIntervalSeconds or 0.25)
		end
		task.wait(0.1)
	end

	stopCollectibles(services)
	services.qualificationZoneService.EndRound()
	services.exitDoorService.EndRound()

	local qualifiedUserIds = context:BuildQualifiedUserIds()
	local usedFallback = false
	if #qualifiedUserIds < context.targetQualifiers then
		qualifiedUserIds, usedFallback = context:ApplyFallbackPromotions(collectathonEnd)
	end

	return {
		qualifiedUserIds = qualifiedUserIds,
		finalEntries = context:RefreshLeaderboardState(),
		endedBy = endedBy,
		usedFallback = usedFallback,
	}
end

return GameplayPhase
