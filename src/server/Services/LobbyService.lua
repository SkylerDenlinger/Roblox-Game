local Players = game:GetService("Players")

local StateContract = require(script.Parent:WaitForChild("StateContract"))
local PartyService = require(script.Parent:WaitForChild("PartyService"))

local LobbyService = {}

local QUEUE_MODE_PUBLIC = "Public"
local MIN_PLAYERS_TO_FORM_LOBBY = 2
local MAX_PLAYERS_PER_LOBBY = 8
local MATCHMAKER_TICK_SECONDS = 0.5

local started = false
local nextLobbyId = 1
local stateVersion = 0

local queueByLeaderUserId = {}
local queueOrder = {}
local queueLeaderByUserId = {}

local lobbiesById = {}
local lobbyIdByUserId = {}

local lobbyGetStateRemote = nil
local lobbyCommandRemote = nil
local lobbyUpdatedRemote = nil
local lobbyMessageRemote = nil

local function bumpVersion()
	stateVersion += 1
	return stateVersion
end

local function playerIdentityByUserId(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return {
			userId = userId,
			name = player.Name,
			displayName = player.DisplayName,
		}
	end
	return {
		userId = userId,
		name = tostring(userId),
		displayName = tostring(userId),
	}
end

local function buildMemberIdentityList(userIds)
	local members = {}
	for _, userId in ipairs(userIds) do
		table.insert(members, playerIdentityByUserId(userId))
	end
	table.sort(members, function(a, b)
		local an = string.lower(a.displayName or a.name or "")
		local bn = string.lower(b.displayName or b.name or "")
		if an == bn then
			return (a.userId or 0) < (b.userId or 0)
		end
		return an < bn
	end)
	return members
end

local function sendMessage(player, text, isError)
	if not player or not lobbyMessageRemote then
		return
	end
	lobbyMessageRemote:FireClient(player, {
		text = text,
		isError = isError == true,
	})
end

local function removeQueueOrderLeader(leaderUserId)
	for i = #queueOrder, 1, -1 do
		if queueOrder[i] == leaderUserId then
			table.remove(queueOrder, i)
			return
		end
	end
end

local function removeQueueEntry(leaderUserId)
	local entry = queueByLeaderUserId[leaderUserId]
	if not entry then
		return nil
	end

	queueByLeaderUserId[leaderUserId] = nil
	removeQueueOrderLeader(leaderUserId)

	for _, memberUserId in ipairs(entry.memberUserIds) do
		if queueLeaderByUserId[memberUserId] == leaderUserId then
			queueLeaderByUserId[memberUserId] = nil
		end
	end

	return entry
end

local function removeLobbyMember(lobby, userId)
	local members = lobby.memberUserIds
	for i = #members, 1, -1 do
		if members[i] == userId then
			table.remove(members, i)
			break
		end
	end
	lobbyIdByUserId[userId] = nil
end

local function removeLobby(lobbyId)
	local lobby = lobbiesById[lobbyId]
	if not lobby then
		return nil
	end

	lobbiesById[lobbyId] = nil
	for _, memberUserId in ipairs(lobby.memberUserIds) do
		if lobbyIdByUserId[memberUserId] == lobbyId then
			lobbyIdByUserId[memberUserId] = nil
		end
	end

	return lobby
end

local function getContextForUserId(userId)
	if lobbyIdByUserId[userId] then
		return "lobby"
	end
	if queueLeaderByUserId[userId] then
		return "queued"
	end
	return "none"
end

local function queueSnapshotForUserId(userId)
	local leaderUserId = queueLeaderByUserId[userId]
	if not leaderUserId then
		return nil
	end

	local entry = queueByLeaderUserId[leaderUserId]
	if not entry then
		return nil
	end

	return {
		leaderUserId = entry.leaderUserId,
		mode = entry.mode,
		queuedAt = entry.queuedAt,
		members = buildMemberIdentityList(entry.memberUserIds),
	}
end

local function lobbySnapshotForUserId(userId)
	local lobbyId = lobbyIdByUserId[userId]
	if not lobbyId then
		return nil
	end

	local lobby = lobbiesById[lobbyId]
	if not lobby then
		return nil
	end

	return {
		id = lobby.id,
		leaderUserId = lobby.leaderUserId,
		status = lobby.status,
		createdAt = lobby.createdAt,
		members = buildMemberIdentityList(lobby.memberUserIds),
	}
end

local function buildStateForPlayer(player)
	return {
		version = stateVersion,
		context = getContextForUserId(player.UserId),
		queue = queueSnapshotForUserId(player.UserId),
		lobby = lobbySnapshotForUserId(player.UserId),
	}
end

local function pushStateToPlayer(player)
	if not player or not lobbyUpdatedRemote then
		return
	end
	lobbyUpdatedRemote:FireClient(player, buildStateForPlayer(player))
end

local function pushStateToAllPlayers()
	bumpVersion()
	for _, player in ipairs(Players:GetPlayers()) do
		pushStateToPlayer(player)
	end
end

local function getMemberPlayerObjects(memberUserIds)
	local members = {}
	for _, userId in ipairs(memberUserIds) do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return nil
		end
		table.insert(members, player)
	end
	return members
end

local function groupMemberUserIdsForLeader(player)
	local partySnapshot = PartyService.GetPartySnapshotForUserId(player.UserId)
	if not partySnapshot then
		return { player.UserId }, nil
	end

	if partySnapshot.leaderUserId ~= player.UserId then
		return nil, "Only the party leader can queue."
	end

	if #partySnapshot.memberUserIds == 0 then
		return { player.UserId }, nil
	end

	return partySnapshot.memberUserIds, nil
end

local function validateGroupQueueEligibility(memberUserIds)
	if #memberUserIds > MAX_PLAYERS_PER_LOBBY then
		return "Group is too large for lobby capacity."
	end

	local members = getMemberPlayerObjects(memberUserIds)
	if not members then
		return "All party members must be online to queue."
	end

	for _, member in ipairs(members) do
		local context = getContextForUserId(member.UserId)
		if context ~= "none" then
			return ("Player %s is already %s."):format(member.DisplayName, context)
		end
	end

	return nil
end

local function onQueueJoinRequested(player, mode)
	mode = mode or QUEUE_MODE_PUBLIC
	if mode ~= QUEUE_MODE_PUBLIC then
		sendMessage(player, "Unsupported queue mode.", true)
		pushStateToPlayer(player)
		return
	end

	local context = getContextForUserId(player.UserId)
	if context ~= "none" then
		if context == "queued" then
			sendMessage(player, "Already searching for a match.", true)
		else
			sendMessage(player, "Already in a lobby.", true)
		end
		pushStateToPlayer(player)
		return
	end

	local memberUserIds, err = groupMemberUserIdsForLeader(player)
	if not memberUserIds then
		sendMessage(player, err or "Queue join failed.", true)
		pushStateToPlayer(player)
		return
	end

	local eligibilityErr = validateGroupQueueEligibility(memberUserIds)
	if eligibilityErr then
		sendMessage(player, eligibilityErr, true)
		pushStateToPlayer(player)
		return
	end

	local entry = {
		leaderUserId = player.UserId,
		mode = mode,
		memberUserIds = memberUserIds,
		queuedAt = os.clock(),
	}

	queueByLeaderUserId[player.UserId] = entry
	table.insert(queueOrder, player.UserId)
	for _, memberUserId in ipairs(memberUserIds) do
		queueLeaderByUserId[memberUserId] = player.UserId
		local memberPlayer = Players:GetPlayerByUserId(memberUserId)
		if memberPlayer then
			sendMessage(memberPlayer, "Searching for match...")
		end
	end

	pushStateToAllPlayers()
end

local function onQueueCancelRequested(player)
	local leaderUserId = queueLeaderByUserId[player.UserId]
	if not leaderUserId then
		sendMessage(player, "You are not queued.", true)
		pushStateToPlayer(player)
		return
	end

	if leaderUserId ~= player.UserId then
		sendMessage(player, "Only the party leader can cancel queue.", true)
		pushStateToPlayer(player)
		return
	end

	local removed = removeQueueEntry(leaderUserId)
	if not removed then
		pushStateToPlayer(player)
		return
	end

	for _, memberUserId in ipairs(removed.memberUserIds) do
		local memberPlayer = Players:GetPlayerByUserId(memberUserId)
		if memberPlayer then
			sendMessage(memberPlayer, "Match search cancelled.")
		end
	end

	pushStateToAllPlayers()
end

local function onLobbyLeaveRequested(player)
	local lobbyId = lobbyIdByUserId[player.UserId]
	if not lobbyId then
		sendMessage(player, "You are not in a lobby.", true)
		pushStateToPlayer(player)
		return
	end

	local lobby = lobbiesById[lobbyId]
	if not lobby then
		lobbyIdByUserId[player.UserId] = nil
		pushStateToPlayer(player)
		return
	end

	local wasLeader = lobby.leaderUserId == player.UserId
	removeLobbyMember(lobby, player.UserId)
	sendMessage(player, "You left the lobby.")

	if #lobby.memberUserIds == 0 then
		lobbiesById[lobby.id] = nil
		pushStateToAllPlayers()
		return
	end

	if wasLeader then
		lobby.leaderUserId = lobby.memberUserIds[1]
		local nextLeader = Players:GetPlayerByUserId(lobby.leaderUserId)
		if nextLeader then
			sendMessage(nextLeader, "You are now the lobby leader.")
		end
	end

	if #lobby.memberUserIds < MIN_PLAYERS_TO_FORM_LOBBY then
		local survivors = table.clone(lobby.memberUserIds)
		removeLobby(lobby.id)
		for _, userId in ipairs(survivors) do
			local memberPlayer = Players:GetPlayerByUserId(userId)
			if memberPlayer then
				sendMessage(memberPlayer, "Lobby closed: not enough players.", true)
			end
		end
	end

	pushStateToAllPlayers()
end

local function onCommand(player, payload)
	if type(payload) ~= "table" then
		sendMessage(player, "Invalid lobby command payload.", true)
		pushStateToPlayer(player)
		return
	end

	local op = payload.op
	if op == "QueueJoin" then
		onQueueJoinRequested(player, payload.mode)
	elseif op == "QueueCancel" then
		onQueueCancelRequested(player)
	elseif op == "LobbyLeave" then
		onLobbyLeaveRequested(player)
	elseif op == "LobbyReady" then
		sendMessage(player, "Ready state not wired yet.")
		pushStateToPlayer(player)
	else
		sendMessage(player, "Unknown lobby command.", true)
		pushStateToPlayer(player)
	end
end

local function formLobbyFromQueueEntries(selectedEntries)
	if #selectedEntries == 0 then
		return
	end

	local memberUserIds = {}
	for _, entry in ipairs(selectedEntries) do
		for _, userId in ipairs(entry.memberUserIds) do
			table.insert(memberUserIds, userId)
		end
		removeQueueEntry(entry.leaderUserId)
	end

	local lobbyId = tostring(nextLobbyId)
	nextLobbyId += 1

	local lobby = {
		id = lobbyId,
		leaderUserId = selectedEntries[1].leaderUserId,
		memberUserIds = memberUserIds,
		createdAt = os.clock(),
		status = "Formed",
	}

	lobbiesById[lobbyId] = lobby
	for _, userId in ipairs(memberUserIds) do
		lobbyIdByUserId[userId] = lobbyId
		local player = Players:GetPlayerByUserId(userId)
		if player then
			sendMessage(player, "Lobby formed.")
		end
	end

	pushStateToAllPlayers()
end

local function tryFormLobbies()
	local leaders = {}
	for _, leaderUserId in ipairs(queueOrder) do
		if queueByLeaderUserId[leaderUserId] then
			table.insert(leaders, leaderUserId)
		end
	end

	if #leaders == 0 then
		return
	end

	local i = 1
	while i <= #leaders do
		local selected = {}
		local selectedCount = 0
		local j = i

		while j <= #leaders do
			local entry = queueByLeaderUserId[leaders[j]]
			if entry then
				local entryCount = #entry.memberUserIds
				if entryCount > MAX_PLAYERS_PER_LOBBY then
					removeQueueEntry(entry.leaderUserId)
				elseif selectedCount + entryCount <= MAX_PLAYERS_PER_LOBBY then
					table.insert(selected, entry)
					selectedCount += entryCount
				else
					break
				end
			end
			j += 1
		end

		if selectedCount >= MIN_PLAYERS_TO_FORM_LOBBY then
			formLobbyFromQueueEntries(selected)
			i = j
		else
			break
		end
	end
end

local function onPlayerRemoving(player)
	local userId = player.UserId

	local queueLeader = queueLeaderByUserId[userId]
	if queueLeader then
		local entry = queueByLeaderUserId[queueLeader]
		if entry then
			local affectedMembers = table.clone(entry.memberUserIds)
			removeQueueEntry(queueLeader)
			for _, memberUserId in ipairs(affectedMembers) do
				if memberUserId ~= userId then
					local memberPlayer = Players:GetPlayerByUserId(memberUserId)
					if memberPlayer then
						sendMessage(memberPlayer, "Queue cancelled: party member left.", true)
					end
				end
			end
		end
	end

	local lobbyId = lobbyIdByUserId[userId]
	if lobbyId then
		local lobby = lobbiesById[lobbyId]
		if lobby then
			local wasLeader = lobby.leaderUserId == userId
			removeLobbyMember(lobby, userId)

			if #lobby.memberUserIds == 0 then
				lobbiesById[lobby.id] = nil
			else
				if wasLeader then
					lobby.leaderUserId = lobby.memberUserIds[1]
					local nextLeader = Players:GetPlayerByUserId(lobby.leaderUserId)
					if nextLeader then
						sendMessage(nextLeader, "You are now the lobby leader.")
					end
				end

				if #lobby.memberUserIds < MIN_PLAYERS_TO_FORM_LOBBY then
					local survivors = table.clone(lobby.memberUserIds)
					removeLobby(lobby.id)
					for _, survivorUserId in ipairs(survivors) do
						local survivor = Players:GetPlayerByUserId(survivorUserId)
						if survivor then
							sendMessage(survivor, "Lobby closed: not enough players.", true)
						end
					end
				end
			end
		end
	end

	task.defer(pushStateToAllPlayers)
end

function LobbyService.Start()
	if started then
		return
	end
	started = true

	local refs = StateContract.Ensure()
	local remotesRoot = refs.RemotesRoot

	lobbyGetStateRemote = remotesRoot:WaitForChild("LobbyGetState")
	lobbyCommandRemote = remotesRoot:WaitForChild("LobbyCommand")
	lobbyUpdatedRemote = remotesRoot:WaitForChild("LobbyUpdated")
	lobbyMessageRemote = remotesRoot:WaitForChild("LobbyMessage")

	lobbyGetStateRemote.OnServerInvoke = function(player)
		return buildStateForPlayer(player)
	end

	lobbyCommandRemote.OnServerEvent:Connect(function(player, payload)
		onCommand(player, payload)
	end)

	Players.PlayerAdded:Connect(function()
		task.defer(pushStateToAllPlayers)
	end)

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			tryFormLobbies()
			task.wait(MATCHMAKER_TICK_SECONDS)
		end
	end)
end

return LobbyService
