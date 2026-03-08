local serverRoot = script.Parent.Parent.Parent.Parent
local StateReplicator = require(serverRoot:WaitForChild("State"):WaitForChild("StateReplicator"))

local RegularStateController = {}

function RegularStateController.BeginSessionRun()
	StateReplicator.BeginRun("Regular")
end

function RegularStateController.ResetToIdle()
	StateReplicator.BeginPhase("Idle", 0, {
		SessionId = "",
		EntrantCount = 0,
		RoundTargetQualifiers = 0,
		CurrentMapId = "",
		CurrentMapName = "",
		NextMapId = "",
		NextMapName = "",
	})
	StateReplicator.SetProgressValues({
		RequiredKeys = 0,
		WinnerUserId = 0,
		DoorState = "Closed",
		QualifyCount = 0,
		QualifiedCount = 0,
		EscapedCount = 0,
		RemainingQualifierSlots = 0,
	})
	StateReplicator.ResetLeaderboard()
	StateReplicator.ResetPresentation()
end

function RegularStateController.BeginIdleRun()
	RegularStateController.BeginSessionRun()
	RegularStateController.ResetToIdle()
end

return RegularStateController
