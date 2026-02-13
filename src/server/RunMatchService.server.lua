local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("RunMatchService: boot")

-- Ensure replicated state exists
local StateContract = require(ReplicatedStorage:WaitForChild("State"):WaitForChild("StateContract"))
StateContract.Ensure()
print("RunMatchService: state ensured")

-- Since this script is now inside ServerScriptService/Server,
-- script.Parent is the Server folder and Services is a child of it.
local serverFolder = script.Parent
local servicesFolder = serverFolder:WaitForChild("Services")

-- Start PlayerStateService
local PlayerStateService = require(servicesFolder:WaitForChild("PlayerStateService"))
PlayerStateService.Start()
print("RunMatchService: PlayerState started")

-- Start QualificationService
local QualificationService = require(servicesFolder:WaitForChild("QualificationService"))
QualificationService.Start()
print("RunMatchService: QualificationService started")

-- Start RoundOrchestrator
local RoundOrchestrator = require(servicesFolder:WaitForChild("RoundOrchestrator"))
RoundOrchestrator.Start()
print("RunMatchService: RoundOrchestrator started")

-- Bind Exit Door (if it exists)
local ExitDoorService = require(servicesFolder:WaitForChild("ExitDoorService"))
local door = workspace:FindFirstChild("ExitDoor")
if door then
	ExitDoorService.BindDoor(door)
	print("RunMatchService: ExitDoor bound")
else
	warn("RunMatchService: ExitDoor not found in Workspace")
end

-- Start MatchService loop (spawned so it doesn't block boot)
local MatchService = require(servicesFolder:WaitForChild("MatchService"))
print("RunMatchService: starting match loop")

task.spawn(function()
	MatchService.RunLoop()
end)
