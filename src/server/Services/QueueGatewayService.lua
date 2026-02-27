local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local StateContract = require(script.Parent:WaitForChild("StateContract"))

local QueueGatewayService = {}

local started = false
local queueService = nil
local partyService = nil
local stateReplicator = nil
local fillLobbyService = nil
local lobbyCommandRemote = nil

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
	local partySnapshot = partyService.GetPartySnapshotForUserId(player.UserId)
	if not partySnapshot then
		return { player.UserId }, nil
	end
	if partySnapshot.leaderUserId ~= player.UserId then
		return nil, "Only the party leader can queue."
	end
	return partySnapshot.memberUserIds, nil
end

local function validateGroupQueueEligibility(memberUserIds)
	local members = getMemberPlayerObjects(memberUserIds)
	if not members then
		return "All party members must be online to queue."
	end
	for _, member in ipairs(members) do
		local context = queueService.GetContextForUserId(member.UserId)
		if context ~= "none" then
			return ("Player %s is already %s."):format(member.DisplayName, context)
		end
	end
	return nil
end

local function notifyMembers(memberUserIds, text, isError)
	for _, userId in ipairs(memberUserIds) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			stateReplicator.SendLobbyMessage(player, text, isError)
		end
	end
end

local function onQueueJoinRequested(player, mode)
	mode = mode or "Public"
	if mode ~= "Public" then
		stateReplicator.SendLobbyMessage(player, "Unsupported queue mode.", true)
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end

	local context = queueService.GetContextForUserId(player.UserId)
	if context ~= "none" then
		if context == "queued" then
			stateReplicator.SendLobbyMessage(player, "Already searching for a match.", true)
		else
			stateReplicator.SendLobbyMessage(player, "Already in a lobby.", true)
		end
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end

	local memberUserIds, err = groupMemberUserIdsForLeader(player)
	if not memberUserIds then
		stateReplicator.SendLobbyMessage(player, err or "Queue join failed.", true)
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end

	local eligibilityErr = validateGroupQueueEligibility(memberUserIds)
	if eligibilityErr then
		stateReplicator.SendLobbyMessage(player, eligibilityErr, true)
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end

	local queueMemberUserIds = memberUserIds
	local usedFillLobby = false
	if fillLobbyService then
		queueMemberUserIds, usedFillLobby = fillLobbyService.AugmentQueueMembers(
			memberUserIds,
			queueService.GetTargetLobbySize(),
			mode
		)
	end

	local ok, joinErr = queueService.JoinPublic(player.UserId, queueMemberUserIds)
	if not ok then
		stateReplicator.SendLobbyMessage(player, joinErr or "Queue join failed.", true)
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end

	print(("[telemetry] queue_joined %s"):format(HttpService:JSONEncode({
		leaderUserId = player.UserId,
		memberCount = #memberUserIds,
		mode = "Public",
	})))

	if usedFillLobby then
		stateReplicator.SendLobbyMessage(player, "Studio FillLobby enabled: filling remaining slots with bots.")
	end

	notifyMembers(memberUserIds, "Searching for match...", false)
	stateReplicator.PushLobbyStateToAllPlayers()
end

local function onQueueCancelRequested(player)
	local state = queueService.BuildLobbyStateForPlayer(player)
	if state.context ~= "queued" or type(state.queue) ~= "table" then
		stateReplicator.SendLobbyMessage(player, "You are not queued.", true)
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end

	local leaderUserId = state.queue.leaderUserId
	if leaderUserId ~= player.UserId then
		stateReplicator.SendLobbyMessage(player, "Only the party leader can cancel queue.", true)
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end

	local removed = queueService.Cancel(leaderUserId)
	if not removed then
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end

	notifyMembers(removed.memberUserIds, "Match search cancelled.", false)
	stateReplicator.PushLobbyStateToAllPlayers()
end

local function onLobbyLeaveRequested(player)
	local state = queueService.BuildLobbyStateForPlayer(player)
	if state.context ~= "lobby" then
		stateReplicator.SendLobbyMessage(player, "You are not in a lobby.", true)
		stateReplicator.PushLobbyStateToPlayer(player)
		return
	end
	stateReplicator.SendLobbyMessage(player, "Lobby leave is unavailable after matchmaking.", true)
	stateReplicator.PushLobbyStateToPlayer(player)
end

local function onCommand(player, payload)
	if type(payload) ~= "table" then
		stateReplicator.SendLobbyMessage(player, "Invalid lobby command payload.", true)
		stateReplicator.PushLobbyStateToPlayer(player)
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
		stateReplicator.SendLobbyMessage(player, "Ready state not wired yet.", false)
		stateReplicator.PushLobbyStateToPlayer(player)
	else
		stateReplicator.SendLobbyMessage(player, "Unknown lobby command.", true)
		stateReplicator.PushLobbyStateToPlayer(player)
	end
end

function QueueGatewayService.Start(options)
	if started then
		return
	end
	started = true
	options = options or {}

	queueService = options.queueService
	partyService = options.partyService
	stateReplicator = options.stateReplicator
	fillLobbyService = options.fillLobbyService
	if not queueService or not partyService or not stateReplicator then
		error("QueueGatewayService.Start requires queueService, partyService, and stateReplicator")
	end

	stateReplicator.SetLobbyStateProvider(function(player)
		return queueService.BuildLobbyStateForPlayer(player)
	end)

	local refs = StateContract.Ensure()
	lobbyCommandRemote = refs.RemotesRoot:WaitForChild("LobbyCommand")
	lobbyCommandRemote.OnServerEvent:Connect(onCommand)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			stateReplicator.PushLobbyStateToPlayer(player)
			stateReplicator.PushLobbyStateToAllPlayers()
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		queueService.OnPlayerRemoving(player.UserId)
		task.defer(stateReplicator.PushLobbyStateToAllPlayers)
	end)
end

return QueueGatewayService
