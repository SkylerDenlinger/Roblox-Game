local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StateContract = require(script.Parent:WaitForChild("StateContract"))
local RoundEvents = require(script.Parent:WaitForChild("RoundEvents"))

local QualificationService = {}

local qualifiedSet = {}

local function getProgress()
	return StateContract.Get().Progress
end

function QualificationService.ResetForNewRound()
	qualifiedSet = {}
	local progress = getProgress()
	progress.QualifiedCount.Value = 0
end

function QualificationService.SetQualifyCountFromActivePlayers()
	local progress = getProgress()
	local active = #Players:GetPlayers()
	local target = math.max(1, math.floor(active / 2))
	progress.QualifyCount.Value = target
end

function QualificationService.MarkQualified(userId)
	if qualifiedSet[userId] then return end

	qualifiedSet[userId] = true

	local progress = getProgress()
	progress.QualifiedCount.Value += 1

	if progress.QualifiedCount.Value >= progress.QualifyCount.Value then
		RoundEvents.RequestEndCollectathon("QualifyCountReached")
	end
end

function QualificationService.IsQualified(userId)
	return qualifiedSet[userId] == true
end

function QualificationService.Start()
	RoundEvents.OnPlayerQualified(function(userId)
		QualificationService.MarkQualified(userId)
	end)
end

return QualificationService
