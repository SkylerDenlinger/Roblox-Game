local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))
local QueueBands = require(Shared:WaitForChild("QueueBands"))
local TournamentTemplates = require(Shared:WaitForChild("TournamentTemplates"))
local RoundRules = require(Shared:WaitForChild("RoundRules"))
local MapManifest = require(Shared:WaitForChild("MapManifest"))
local RemoteSchemas = require(Shared:WaitForChild("RemoteSchemas"))

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
