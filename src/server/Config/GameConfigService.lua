local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local FeatureFlags = require(Shared:WaitForChild("Config"):WaitForChild("FeatureFlags"))
local QueueBands = require(Shared:WaitForChild("Config"):WaitForChild("QueueBands"))
local TournamentTemplates = require(Shared:WaitForChild("Config"):WaitForChild("TournamentTemplates"))
local RoundRules = require(Shared:WaitForChild("Config"):WaitForChild("RoundRules"))
local MapManifest = require(Shared:WaitForChild("Content"):WaitForChild("Maps"):WaitForChild("MapManifest"))
local RemoteSchemas = require(Shared:WaitForChild("Contracts"):WaitForChild("RemoteSchemas"))

local GameConfigService = {}

function GameConfigService.GetFeatureFlags()
	return FeatureFlags
end

function GameConfigService.GetQueueBands()
	return QueueBands
end

function GameConfigService.GetTournamentTemplates()
	return TournamentTemplates
end

function GameConfigService.GetRoundRules()
	return RoundRules
end

function GameConfigService.GetMapManifest()
	return MapManifest
end

function GameConfigService.GetRemoteSchemas()
	return RemoteSchemas
end

return GameConfigService
