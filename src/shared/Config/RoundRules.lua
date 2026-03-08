local RoundRules = {
	Queue = {
		FallbackAfterSeconds = 30,
		MinimumEntrants = 2,
	},
	PhaseDurations = {
		SessionLobby = 4,
		MapSelect = 1,
		IntroCutscene = 6,
		Countdown = 3,
		Collectathon = 300,
		RoundResults = 12,
		NextRoundTransition = 4,
		WinnerCeremony = 15,
	},
	Collectibles = {
		KeyCount = 20,
		GearCount = 12,
		RequiredKeys = 5,
		ShowcaseCount = 5,
	},
	Leaderboard = {
		RefreshIntervalSeconds = 0.25,
	},
	Maps = {
		NoImmediateRepeat = true,
	},
}

return RoundRules
