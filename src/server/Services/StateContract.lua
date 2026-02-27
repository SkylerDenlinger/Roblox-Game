-- ServerScriptService/Server/Services/StateContract.lua
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
local function requireChild(parent, name)
	local c = parent:FindFirstChild(name)
	if not c then
		error(("StateContract missing '%s' under %s"):format(name, parent:GetFullName()))
	end
	return c
end
function StateContract.Ensure()
	local stateRoot = ensureFolder(ReplicatedStorage, "State")
	local remotesRoot = ensureFolder(ReplicatedStorage, "Remotes")
	ensureValue(remotesRoot, "RemoteEvent", "SubmitMapVote")
	ensureValue(remotesRoot, "RemoteFunction", "PartyGetState")
	ensureValue(remotesRoot, "RemoteEvent", "PartyInvite")
	ensureValue(remotesRoot, "RemoteEvent", "PartyRespondInvite")
	ensureValue(remotesRoot, "RemoteEvent", "PartyLeave")
	ensureValue(remotesRoot, "RemoteEvent", "PartyUpdated")
	ensureValue(remotesRoot, "RemoteEvent", "PartyMessage")
	ensureValue(remotesRoot, "RemoteFunction", "LobbyGetState")
	ensureValue(remotesRoot, "RemoteEvent", "LobbyCommand")
	ensureValue(remotesRoot, "RemoteEvent", "LobbyUpdated")
	ensureValue(remotesRoot, "RemoteEvent", "LobbyMessage")
	local matchFolder = ensureFolder(stateRoot, "Match")
	ensureValue(matchFolder, "StringValue", "Phase", "Lobby")
	ensureValue(matchFolder, "StringValue", "Mode", "FFA")
	ensureValue(matchFolder, "StringValue", "RunId", "")
	ensureValue(matchFolder, "StringValue", "SessionId", "")
	ensureValue(matchFolder, "IntValue", "RoundIndex", 0)
	ensureValue(matchFolder, "StringValue", "RoundId", "")
	ensureValue(matchFolder, "IntValue", "EntrantCount", 0)
	ensureValue(matchFolder, "IntValue", "RoundTargetQualifiers", 0)
	ensureValue(matchFolder, "IntValue", "TimerVersion", 0)
	ensureValue(matchFolder, "NumberValue", "PhaseStartServerTime", 0)
	ensureValue(matchFolder, "NumberValue", "PhaseDuration", 0)
	ensureValue(matchFolder, "NumberValue", "PhaseEndsServerTime", 0)
	ensureValue(matchFolder, "StringValue", "CurrentMapId", "")
	ensureValue(matchFolder, "StringValue", "CurrentMapName", "")
	ensureValue(matchFolder, "StringValue", "NextMapId", "")
	ensureValue(matchFolder, "StringValue", "NextMapName", "")
	local progressFolder = ensureFolder(stateRoot, "Progress")
	ensureValue(progressFolder, "IntValue", "RequiredKeys", 0)
	ensureValue(progressFolder, "IntValue", "WinnerUserId", 0)
	ensureValue(progressFolder, "StringValue", "DoorState", "Closed")
	ensureValue(progressFolder, "IntValue", "QualifyCount", 0)
	ensureValue(progressFolder, "IntValue", "QualifiedCount", 0)
	ensureValue(progressFolder, "IntValue", "EscapedCount", 0)
	ensureValue(progressFolder, "IntValue", "RemainingQualifierSlots", 0)
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
	local playerStateFolder = ensureFolder(stateRoot, "PlayerState")
	local legacyMatch = stateRoot:FindFirstChild("MatchState")
	if legacyMatch then legacyMatch:Destroy() end
	local legacyProgress = stateRoot:FindFirstChild("ProgressState")
	if legacyProgress then legacyProgress:Destroy() end
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
	local stateRoot = requireChild(ReplicatedStorage, "State")
	return {
		Match = requireChild(stateRoot, "Match"),
		Progress = requireChild(stateRoot, "Progress"),
		Vote = requireChild(stateRoot, "VoteState"),
		PlayerState = requireChild(stateRoot, "PlayerState"),
		Remotes = requireChild(ReplicatedStorage, "Remotes"),
	}
end
return StateContract
