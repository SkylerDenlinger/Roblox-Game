local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateContract = require(script.Parent:WaitForChild("StateContract"))

local StateReplicator = {}

local started = false
local lobbyStateProvider = nil
local lobbyGetStateRemote = nil
local lobbyUpdatedRemote = nil
local lobbyMessageRemote = nil

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
		Mode = mode or "FFA",
		RunId = newId(),
		RoundId = newId(),
		RoundIndex = 1,
	})
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
