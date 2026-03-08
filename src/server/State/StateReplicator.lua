local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateContract = require(script.Parent:WaitForChild("StateContract"))

local StateReplicator = {}

local started = false
local lobbyStateProvider = nil
local lobbyGetStateRemote = nil
local lobbyUpdatedRemote = nil
local lobbyMessageRemote = nil

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

local function requireState()
	return StateContract.Get()
end

local function updateFolderValues(folder, patch)
	for key, value in pairs(patch) do
		local node = folder:FindFirstChild(key)
		if node and node:IsA("ValueBase") then
			node.Value = value
		end
	end
end

local function newId()
	return ("%d-%d"):format(math.floor(os.clock() * 1000), math.random(100000, 999999))
end

local function defaultLobbyState()
	return {
		version = 0,
		context = "none",
		queuePopulation = 0,
		targetLobbySize = 6,
		oldestQueueAgeSeconds = 0,
		tournamentPath = nil,
		estimatedRounds = nil,
		sessionId = nil,
		queue = nil,
		lobby = nil,
	}
end

function StateReplicator.Start()
	if started then
		return
	end
	started = true

	local refs = StateContract.Ensure()
	local remotesRoot = refs.RemotesRoot or ReplicatedStorage:WaitForChild("Remotes")
	lobbyGetStateRemote = remotesRoot:WaitForChild("LobbyGetState")
	lobbyUpdatedRemote = remotesRoot:WaitForChild("LobbyUpdated")
	lobbyMessageRemote = remotesRoot:WaitForChild("LobbyMessage")

	lobbyGetStateRemote.OnServerInvoke = function(player)
		if lobbyStateProvider then
			local snapshot = lobbyStateProvider(player)
			if type(snapshot) == "table" then
				return snapshot
			end
		end
		return defaultLobbyState()
	end
end

function StateReplicator.SetLobbyStateProvider(provider)
	lobbyStateProvider = provider
end

function StateReplicator.BuildLobbyStateForPlayer(player)
	if lobbyStateProvider then
		local snapshot = lobbyStateProvider(player)
		if type(snapshot) == "table" then
			return snapshot
		end
	end
	return defaultLobbyState()
end

function StateReplicator.PushLobbyStateToPlayer(player)
	if not player or not lobbyUpdatedRemote then
		return
	end
	lobbyUpdatedRemote:FireClient(player, StateReplicator.BuildLobbyStateForPlayer(player))
end

function StateReplicator.PushLobbyStateToAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		StateReplicator.PushLobbyStateToPlayer(player)
	end
end

function StateReplicator.SendLobbyMessage(player, text, isError)
	if not player or not lobbyMessageRemote then
		return
	end
	lobbyMessageRemote:FireClient(player, {
		text = text,
		isError = isError == true,
	})
end

function StateReplicator.SetMatchValues(patch)
	local refs = requireState()
	updateFolderValues(refs.Match, patch)
end

function StateReplicator.SetProgressValues(patch)
	local refs = requireState()
	updateFolderValues(refs.Progress, patch)
end

function StateReplicator.SetLeaderboardEntries(entries)
	local refs = requireState()
	local leaderboard = refs.Leaderboard
	local entriesFolder = ensureFolder(leaderboard, "Entries")
	entriesFolder:ClearAllChildren()

	for index, entry in ipairs(entries or {}) do
		local entryFolder = ensureFolder(entriesFolder, tostring(index))
		ensureValue(entryFolder, "IntValue", "Rank", index).Value = index
		ensureValue(entryFolder, "IntValue", "UserId", entry.userId or 0).Value = entry.userId or 0
		ensureValue(entryFolder, "StringValue", "DisplayName", entry.displayName or "").Value = entry.displayName or ""
		ensureValue(entryFolder, "IntValue", "Keys", entry.keys or 0).Value = entry.keys or 0
		ensureValue(entryFolder, "IntValue", "Gears", entry.gears or 0).Value = entry.gears or 0
		ensureValue(entryFolder, "BoolValue", "Qualified", entry.qualified == true).Value = entry.qualified == true
		ensureValue(entryFolder, "BoolValue", "IsOnline", entry.isOnline ~= false).Value = entry.isOnline ~= false
		ensureValue(
			entryFolder,
			"NumberValue",
			"QualifiedAtServerTime",
			entry.qualifiedAtServerTime or 0
		).Value = entry.qualifiedAtServerTime or 0
		ensureValue(
			entryFolder,
			"NumberValue",
			"FirstKeyAtServerTime",
			entry.firstKeyAtServerTime or 0
		).Value = entry.firstKeyAtServerTime or 0
	end

	leaderboard.UpdatedAt.Value = os.clock()
end

function StateReplicator.ResetLeaderboard()
	StateReplicator.SetLeaderboardEntries({})
end

function StateReplicator.SetPresentationValues(patch)
	local refs = requireState()
	local presentation = refs.Presentation
	updateFolderValues(presentation, patch)
	if presentation:FindFirstChild("UpdatedAt") then
		presentation.UpdatedAt.Value = os.clock()
	end
end

function StateReplicator.SetPresentationShowcaseIds(showcaseIds)
	local refs = requireState()
	local showcaseFolder = ensureFolder(refs.Presentation, "ShowcasedCollectibles")
	showcaseFolder:ClearAllChildren()
	for index, showcaseId in ipairs(showcaseIds or {}) do
		ensureValue(showcaseFolder, "StringValue", tostring(index), showcaseId or "").Value = showcaseId or ""
	end
	if refs.Presentation:FindFirstChild("UpdatedAt") then
		refs.Presentation.UpdatedAt.Value = os.clock()
	end
end

function StateReplicator.ResetPresentation()
	StateReplicator.SetPresentationValues({
		Phase = "Idle",
		ResultsMode = "none",
		PrimaryText = "",
		SecondaryText = "",
		Message = "",
		SpectateTargetUserId = 0,
		SpectateTargetName = "",
	})
	StateReplicator.SetPresentationShowcaseIds({})
end

function StateReplicator.SetPlayerValues(userId, patch)
	local refs = requireState()
	local playerFolder = refs.PlayerState:FindFirstChild(tostring(userId))
	if not playerFolder then
		return
	end
	updateFolderValues(playerFolder, patch)
end

function StateReplicator.BeginPhase(phaseName, durationSeconds, extraMatchPatch)
	local refs = requireState()
	local match = refs.Match
	local now = os.clock()
	local duration = math.max(0, tonumber(durationSeconds) or 0)

	local patch = {
		Phase = phaseName,
		TimerVersion = match.TimerVersion.Value + 1,
		PhaseStartServerTime = now,
		PhaseDuration = duration,
		PhaseEndsServerTime = now + duration,
	}

	if type(extraMatchPatch) == "table" then
		for key, value in pairs(extraMatchPatch) do
			patch[key] = value
		end
	end

	updateFolderValues(match, patch)
end

function StateReplicator.BeginRun(mode)
	local refs = requireState()
	updateFolderValues(refs.Match, {
		Mode = mode or "Regular",
		RunId = newId(),
		RoundId = newId(),
		RoundIndex = 1,
	})
	StateReplicator.ResetLeaderboard()
	StateReplicator.ResetPresentation()
end

function StateReplicator.NextRoundIndex()
	local refs = requireState()
	local match = refs.Match
	match.RoundIndex.Value += 1
	match.RoundId.Value = newId()
	return match.RoundIndex.Value
end

function StateReplicator.ResetProgress(requiredKeys, qualifyCount)
	local refs = requireState()
	updateFolderValues(refs.Progress, {
		RequiredKeys = requiredKeys or 0,
		WinnerUserId = 0,
		DoorState = "Closed",
		QualifyCount = qualifyCount or 0,
		QualifiedCount = 0,
		EscapedCount = 0,
		RemainingQualifierSlots = qualifyCount or 0,
	})
end

return StateReplicator
