local PregamePhase = {}

function PregamePhase.Run(context, services)
	local durations = context.phaseDurations

	context:SetPhase("SessionLobby", durations.SessionLobby, {
		RoundIndex = context.roundIndex,
	}, {
		Phase = "SessionLobby",
		PrimaryText = ("Round %d / %d"):format(context.roundIndex, context.totalRounds),
		SecondaryText = ("%d entrants | %d qualify"):format(#context.entrantUserIds, context.targetQualifiers),
		Message = "Waiting for players...",
	})
	context:WaitSeconds(durations.SessionLobby)

	context:SetPhase("MapSelect", durations.MapSelect, nil, {
		Phase = "MapSelect",
		PrimaryText = "Selecting Map",
		SecondaryText = "",
		Message = "Preparing the next arena...",
	})

	local manifest = services.mapManifestLoader.Resolve(context.roundSpec.mapId)
	context:SetManifest(manifest)
	context:CreateTempSpectateBot()
	context.stateReplicator.SetMatchValues({
		CurrentMapId = manifest.id,
		CurrentMapName = manifest.name,
		NextMapId = "",
		NextMapName = "",
	})
	services.exitDoorService.BindDoor(manifest.exitDoor)
	services.qualificationZoneService.BindZone(manifest.qualificationZone)
	context:WaitSeconds(durations.MapSelect)

	context:SpawnEntrants()
	context.spawnPlan = context:BuildSpawnPlan()
	context.stateReplicator.SetPresentationShowcaseIds(context.spawnPlan.showcaseIds)
	context:RefreshLeaderboardState()

	context:SetPhase("IntroCutscene", durations.IntroCutscene, nil, {
		Phase = "IntroCutscene",
		PrimaryText = manifest.name,
		SecondaryText = ("%d collectibles highlighted"):format(#context.spawnPlan.showcaseIds),
		Message = "Scout the strongest pickups before the start.",
	})
	context:WaitSeconds(durations.IntroCutscene)

	context.stateReplicator.SetPresentationShowcaseIds({})
	context:SetPhase("Countdown", durations.Countdown, nil, {
		Phase = "Countdown",
		PrimaryText = "Get Ready",
		SecondaryText = ("%d keys needed | %d qualify"):format(context.requiredKeys, context.targetQualifiers),
		Message = "Collect keys, open your door, and escape.",
	})
	context:WaitSeconds(durations.Countdown)
end

return PregamePhase
