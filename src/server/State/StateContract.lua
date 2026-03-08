local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateContract = {}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureValue(parent, className, name, defaultValue)
	local valueObject = parent:FindFirstChild(name)
	if valueObject and valueObject.ClassName == className then
		return valueObject
	end
	if valueObject then
		valueObject:Destroy()
	end

	valueObject = Instance.new(className)
	valueObject.Name = name
	if defaultValue ~= nil then
		valueObject.Value = defaultValue
	end
	valueObject.Parent = parent
	return valueObject
end

local function requireChild(parent, name)
	local child = parent:FindFirstChild(name)
	if not child then
		error(("StateContract missing '%s' under %s"):format(name, parent:GetFullName()))
	end
	return child
end

function StateContract.Ensure()
	local stateRoot = ensureFolder(ReplicatedStorage, "State")
	local remotesRoot = ensureFolder(ReplicatedStorage, "Remotes")

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
	ensureValue(matchFolder, "StringValue", "Phase", "Idle")
	ensureValue(matchFolder, "StringValue", "Mode", "Regular")
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

	local leaderboardFolder = ensureFolder(stateRoot, "Leaderboard")
	ensureValue(leaderboardFolder, "NumberValue", "UpdatedAt", 0)
	ensureFolder(leaderboardFolder, "Entries")

	local presentationFolder = ensureFolder(stateRoot, "Presentation")
	ensureValue(presentationFolder, "StringValue", "Phase", "Idle")
	ensureValue(presentationFolder, "StringValue", "ResultsMode", "none")
	ensureValue(presentationFolder, "StringValue", "PrimaryText", "")
	ensureValue(presentationFolder, "StringValue", "SecondaryText", "")
	ensureValue(presentationFolder, "StringValue", "Message", "")
	ensureValue(presentationFolder, "IntValue", "SpectateTargetUserId", 0)
	ensureValue(presentationFolder, "StringValue", "SpectateTargetName", "")
	ensureValue(presentationFolder, "NumberValue", "UpdatedAt", 0)
	ensureFolder(presentationFolder, "ShowcasedCollectibles")

	local playerStateFolder = ensureFolder(stateRoot, "PlayerState")

	local legacyMatch = stateRoot:FindFirstChild("MatchState")
	if legacyMatch then
		legacyMatch:Destroy()
	end

	local legacyProgress = stateRoot:FindFirstChild("ProgressState")
	if legacyProgress then
		legacyProgress:Destroy()
	end

	local legacyVote = stateRoot:FindFirstChild("VoteState")
	if legacyVote then
		legacyVote:Destroy()
	end

	local legacyVoteRemote = remotesRoot:FindFirstChild("SubmitMapVote")
	if legacyVoteRemote then
		legacyVoteRemote:Destroy()
	end

	return {
		StateRoot = stateRoot,
		RemotesRoot = remotesRoot,
		Match = matchFolder,
		Progress = progressFolder,
		Leaderboard = leaderboardFolder,
		Presentation = presentationFolder,
		PlayerState = playerStateFolder,
	}
end

function StateContract.Get()
	local stateRoot = requireChild(ReplicatedStorage, "State")
	return {
		Match = requireChild(stateRoot, "Match"),
		Progress = requireChild(stateRoot, "Progress"),
		Leaderboard = requireChild(stateRoot, "Leaderboard"),
		Presentation = requireChild(stateRoot, "Presentation"),
		PlayerState = requireChild(stateRoot, "PlayerState"),
		Remotes = requireChild(ReplicatedStorage, "Remotes"),
	}
end

return StateContract
