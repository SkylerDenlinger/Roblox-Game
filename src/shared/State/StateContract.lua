local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateContract = {}

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then return f end
	if f then f:Destroy() end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function ensureValue(parent, className, name, defaultValue)
	local v = parent:FindFirstChild(name)
	if v and v.ClassName == className then return v end
	if v then v:Destroy() end
	v = Instance.new(className)
	v.Name = name
	if defaultValue ~= nil then
		v.Value = defaultValue
	end
	v.Parent = parent
	return v
end

local function ensureChoice(parent, index)
	local choiceFolder = ensureFolder(parent, tostring(index))
	ensureValue(choiceFolder, "StringValue", "MapId", "")
	ensureValue(choiceFolder, "StringValue", "MapName", "")
	ensureValue(choiceFolder, "IntValue", "Tally", 0)
	return choiceFolder
end

function StateContract.Ensure()
	local stateRoot = ensureFolder(ReplicatedStorage, "State")
	local remotesRoot = ensureFolder(ReplicatedStorage, "Remotes")

	-- RemoteEvents
	ensureValue(remotesRoot, "RemoteEvent", "SubmitMapVote")

	-- MatchState
	local matchFolder = ensureFolder(stateRoot, "MatchState")
	ensureValue(matchFolder, "StringValue", "Phase", "Lobby")
	ensureValue(matchFolder, "StringValue", "Mode", "FFA")
	ensureValue(matchFolder, "StringValue", "RunId", "")
	ensureValue(matchFolder, "IntValue", "RoundIndex", 0)
	ensureValue(matchFolder, "StringValue", "RoundId", "")
	ensureValue(matchFolder, "IntValue", "TimerVersion", 0)
	ensureValue(matchFolder, "NumberValue", "PhaseStartServerTime", 0)
	ensureValue(matchFolder, "NumberValue", "PhaseDuration", 0)
	ensureValue(matchFolder, "NumberValue", "PhaseEndsServerTime", 0)
	ensureValue(matchFolder, "StringValue", "CurrentMapId", "")
	ensureValue(matchFolder, "StringValue", "CurrentMapName", "")
	ensureValue(matchFolder, "StringValue", "NextMapId", "")
	ensureValue(matchFolder, "StringValue", "NextMapName", "")

	-- ProgressState
	local progressFolder = ensureFolder(stateRoot, "ProgressState")
	ensureValue(progressFolder, "IntValue", "RequiredKeys", 0)
	ensureValue(progressFolder, "IntValue", "WinnerUserId", 0)
	ensureValue(progressFolder, "StringValue", "DoorState", "Closed")
	ensureValue(progressFolder, "IntValue", "QualifyCount", 0)
	ensureValue(progressFolder, "IntValue", "QualifiedCount", 0)

	-- VoteState (for later)
	local voteFolder = ensureFolder(stateRoot, "VoteState")
	ensureValue(voteFolder, "StringValue", "VotePhase", "Idle")

	local choicesFolder = ensureFolder(voteFolder, "Choices")
	for i = 1, 5 do
		ensureChoice(choicesFolder, i)
	end

	ensureFolder(voteFolder, "PlayerVotes")
	ensureValue(voteFolder, "NumberValue", "VoteStartServerTime", 0)
	ensureValue(voteFolder, "NumberValue", "VoteDuration", 0)
	ensureValue(voteFolder, "NumberValue", "VoteEndsServerTime", 0)

	-- PlayerState
	local playerStateFolder = ensureFolder(stateRoot, "PlayerState")

	return {
		StateRoot = stateRoot,
		RemotesRoot = remotesRoot,
		Match = matchFolder,
		Progress = progressFolder,
		Vote = voteFolder,
		PlayerState = playerStateFolder,
	}
end

function StateContract.Get()
	local stateRoot = ReplicatedStorage:WaitForChild("State")
	return {
		Match = stateRoot:WaitForChild("MatchState"),
		Progress = stateRoot:WaitForChild("ProgressState"),
		Vote = stateRoot:WaitForChild("VoteState"),
		PlayerState = stateRoot:WaitForChild("PlayerState"),
		Remotes = ReplicatedStorage:WaitForChild("Remotes"),
	}
end

return StateContract
