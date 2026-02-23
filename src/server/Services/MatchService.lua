local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateContract = require(script.Parent:WaitForChild("StateContract"))
local RoundEvents = require(script.Parent:WaitForChild("RoundEvents"))

local MatchService = {}

local PHASES = {
	Lobby = "Lobby",
	Countdown = "Countdown",
	Collectathon = "Collectathon",
	MatchEnded = "MatchEnded",
	Intermission = "Intermission",
}

local forcedEnd = false

RoundEvents.OnEndCollectathonRequested(function(_reason)
	forcedEnd = true
end)

local function newId()
	return tostring(math.floor(os.clock() * 1000)) .. "-" .. tostring(math.random(100000, 999999))
end

local function setPhase(matchFolder, phaseName, durationSeconds)
	matchFolder.Phase.Value = phaseName
	matchFolder.TimerVersion.Value += 1
	local now = os.clock()
	matchFolder.PhaseStartServerTime.Value = now
	matchFolder.PhaseDuration.Value = durationSeconds
	matchFolder.PhaseEndsServerTime.Value = now + durationSeconds
end

function MatchService.StartRun()
	local refs = StateContract.Ensure()
	local matchFolder = refs.Match
	matchFolder.Mode.Value = "FFA"
	matchFolder.RunId.Value = newId()
	matchFolder.RoundIndex.Value = 1
	matchFolder.RoundId.Value = newId()
	setPhase(matchFolder, PHASES.Lobby, 3)
end

function MatchService.AdvancePhase()
	local refs = StateContract.Get()
	local matchFolder = refs.Match
	local phase = matchFolder.Phase.Value

	if phase == PHASES.Lobby then
		setPhase(matchFolder, PHASES.Countdown, 3)
	elseif phase == PHASES.Countdown then
		setPhase(matchFolder, PHASES.Collectathon, 600)
	elseif phase == PHASES.Collectathon then
		setPhase(matchFolder, PHASES.MatchEnded, 8)
	elseif phase == PHASES.MatchEnded then
		setPhase(matchFolder, PHASES.Intermission, 20)
	elseif phase == PHASES.Intermission then
		matchFolder.RoundIndex.Value += 1
		matchFolder.RoundId.Value = newId()
		setPhase(matchFolder, PHASES.Lobby, 15)
	end
end

function MatchService.RunLoop()
	MatchService.StartRun()

	while true do
		local refs = StateContract.Get()
		local matchFolder = refs.Match
		local endsAt = matchFolder.PhaseEndsServerTime.Value

		while os.clock() < endsAt do
			if forcedEnd and matchFolder.Phase.Value == PHASES.Collectathon then
				forcedEnd = false
				setPhase(matchFolder, PHASES.MatchEnded, 8)
				break
			end
			task.wait(0.25)
		end

		if matchFolder.Phase.Value ~= PHASES.MatchEnded or os.clock() >= matchFolder.PhaseEndsServerTime.Value then
			MatchService.AdvancePhase()
		end
	end
end

return MatchService
