local EndingPhase = {}

function EndingPhase.Run(context, gameplayOutcome)
	local durations = context.phaseDurations
	local qualifiedUserIds = gameplayOutcome.qualifiedUserIds or {}
	local finalEntries = gameplayOutcome.finalEntries or {}

	local eliminatedUserIds = context:BuildEliminatedUserIds(finalEntries, qualifiedUserIds)
	local winnerUserId = 0
	if context.isFinalRound and #qualifiedUserIds > 0 then
		winnerUserId = qualifiedUserIds[1]
	end

	context.stateReplicator.SetProgressValues({
		QualifiedCount = #qualifiedUserIds,
		EscapedCount = #qualifiedUserIds,
		RemainingQualifierSlots = math.max(0, context.targetQualifiers - #qualifiedUserIds),
		WinnerUserId = winnerUserId,
	})

	context:ApplyRoundPlacements(finalEntries, qualifiedUserIds, winnerUserId)

	context:SetPhase("RoundResults", durations.RoundResults, nil, {
		Phase = "RoundResults",
		ResultsMode = winnerUserId > 0 and "winner" or "round_results",
		PrimaryText = winnerUserId > 0 and "Winner Decided" or "Round Complete",
		SecondaryText = ("%d qualified | %d eliminated"):format(#qualifiedUserIds, #eliminatedUserIds),
		Message = gameplayOutcome.usedFallback and "Timeout fallback filled the remaining qualifier spots."
			or (gameplayOutcome.endedBy == "QualifyCountReached" and "Qualifier count reached."
				or "Time expired."),
	})
	context:WaitSeconds(durations.RoundResults)

	if winnerUserId > 0 then
		context:SetPhase("WinnerCeremony", durations.WinnerCeremony, nil, {
			Phase = "WinnerCeremony",
			ResultsMode = "winner",
			PrimaryText = ("Winner: %s"):format(context:ResolveDisplayName(winnerUserId)),
			SecondaryText = "Final round complete",
			Message = "Crowning the winner.",
		})
		context:WaitSeconds(durations.WinnerCeremony)
	else
		context:SetPhase("NextRoundTransition", durations.NextRoundTransition, nil, {
			Phase = "NextRoundTransition",
			ResultsMode = "qualified",
			PrimaryText = "Next Round",
			SecondaryText = ("%d players advance"):format(#qualifiedUserIds),
			Message = "Preparing the next lobby.",
		})
		context:WaitSeconds(durations.NextRoundTransition)
	end

	return {
		eliminatedUserIds = eliminatedUserIds,
		winnerUserId = winnerUserId,
		playerStatsByUserId = context:BuildPlayerStats(finalEntries, qualifiedUserIds, winnerUserId),
	}
end

return EndingPhase
