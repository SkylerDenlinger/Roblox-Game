local StateContract = require(script.Parent:WaitForChild("StateContract"))
local StateReplicator = require(script.Parent:WaitForChild("StateReplicator"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local SessionStateController = {}

function SessionStateController.Start()
	StateContract.Ensure()
	StateReplicator.Start()
	PlayerStateService.Start()
end

function SessionStateController.GetContract()
	return StateContract
end

function SessionStateController.GetReplicator()
	return StateReplicator
end

function SessionStateController.GetPlayerStateService()
	return PlayerStateService
end

return SessionStateController
