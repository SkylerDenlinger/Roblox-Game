local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateContract = require(script.Parent:WaitForChild("StateContract"))
local CollectiblesService = require(script.Parent:WaitForChild("CollectiblesService"))
local QualificationService = require(script.Parent:WaitForChild("QualificationService"))
local ExitDoorService = require(script.Parent:WaitForChild("ExitDoorService"))
local QualificationZoneService=require(script.Parent:WaitForChild("QualificationZoneService"))

local RoundOrchestrator = {}

local KEY_COUNT = 20
local REQUIRED_KEYS = 5

local function resetProgressForNewRound()
	local refs = StateContract.Get()
	local progress = refs.Progress
	progress.WinnerUserId.Value = 0
	progress.DoorState.Value = "Closed"
	progress.RequiredKeys.Value = REQUIRED_KEYS
end

function RoundOrchestrator.OnEnterPhase(phase)
	if phase == "Lobby" then
		resetProgressForNewRound()
		QualificationService.ResetForNewRound()
		QualificationService.SetQualifyCountFromActivePlayers()
		ExitDoorService.ResetForNewRound()
		ExitDoorService.SetEnabled(false)
		QualificationZoneService.ResetForNewRound()
	elseif phase == "Collectathon" then
		CollectiblesService.SpawnKeys(KEY_COUNT)
		ExitDoorService.SetEnabled(true)
	elseif phase == "MatchEnded" then
		CollectiblesService.ClearKeys()
		ExitDoorService.SetEnabled(false)
	end
end

function RoundOrchestrator.Start()
	local refs = StateContract.Get()
	local phaseValue = refs.Match:FindFirstChild("Phase")
	if not phaseValue then
		error("RoundOrchestrator missing Match.Phase")
	end

	local lastPhase = phaseValue.Value
	RoundOrchestrator.OnEnterPhase(lastPhase)

	phaseValue.Changed:Connect(function(newPhase)
		lastPhase = newPhase
		RoundOrchestrator.OnEnterPhase(newPhase)
	end)
end

return RoundOrchestrator
