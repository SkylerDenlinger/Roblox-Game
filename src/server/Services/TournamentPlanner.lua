local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QueueBands = require(Shared:WaitForChild("QueueBands"))
local TournamentTemplates = require(Shared:WaitForChild("TournamentTemplates"))

local TournamentPlanner = {}

function TournamentPlanner.ResolveTargetLobbySize(queuePopulation)
	return QueueBands.ResolveLobbySize(queuePopulation)
end

function TournamentPlanner.BuildPath(startSize)
	return TournamentTemplates.BuildPath(startSize)
end

function TournamentPlanner.EstimatedRounds(path)
	local count = math.max(0, #path - 1)
	return count
end

return TournamentPlanner
