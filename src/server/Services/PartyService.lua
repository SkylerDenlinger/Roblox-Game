local Players = game:GetService("Players")

local StateContract = require(script.Parent:WaitForChild("StateContract"))

local PartyService = {}

local PARTY_CAPACITY = 4
local INVITE_EXPIRY_SECONDS = 45

local nextPartyId = 1
local partiesById = {}
local partyIdByUserId = {}
local pendingInvitesByTarget = {}

local started = false

local partyGetStateRemote = nil
local partyInviteRemote = nil
local partyRespondInviteRemote = nil
local partyLeaveRemote = nil
local partyUpdatedRemote = nil
local partyMessageRemote = nil

local function partySize(party)
	local count = 0
	for _ in pairs(party.members) do
		count += 1
	end
	return count
end

local function getPartyByUserId(userId)
	local partyId = partyIdByUserId[userId]
	if not partyId then
		return nil
	end
	return partiesById[partyId]
end

local function createParty(leaderUserId)
	local partyId = tostring(nextPartyId)
	nextPartyId += 1

	local party = {
		id = partyId,
		leaderUserId = leaderUserId,
		members = {
			[leaderUserId] = true,
		},
	}

	partiesById[partyId] = party
	partyIdByUserId[leaderUserId] = partyId
	return party
end

local function addMemberToParty(party, userId)
	party.members[userId] = true
	partyIdByUserId[userId] = party.id
end

local function removeMemberFromParty(userId)
	local party = getPartyByUserId(userId)
	if not party then
		return nil
	end

	party.members[userId] = nil
	partyIdByUserId[userId] = nil

	if next(party.members) == nil then
		partiesById[party.id] = nil
		return nil
	end

	if party.leaderUserId == userId or not party.members[party.leaderUserId] then
		for memberUserId in pairs(party.members) do
			party.leaderUserId = memberUserId
			break
		end
	end

	return party
end

local function clearIncomingInvitesFor(targetUserId)
	pendingInvitesByTarget[targetUserId] = nil
end

local function clearOutgoingInvitesFrom(fromUserId)
	for targetUserId, inviteMap in pairs(pendingInvitesByTarget) do
		inviteMap[fromUserId] = nil
		if next(inviteMap) == nil then
			pendingInvitesByTarget[targetUserId] = nil
		end
	end
end

local function clearInvite(targetUserId, fromUserId)
	local inviteMap = pendingInvitesByTarget[targetUserId]
	if not inviteMap then
		return
	end
	inviteMap[fromUserId] = nil
	if next(inviteMap) == nil then
		pendingInvitesByTarget[targetUserId] = nil
	end
end

local function cleanupExpiredInvites()
	local now = os.clock()
	for targetUserId, inviteMap in pairs(pendingInvitesByTarget) do
		for fromUserId, expiresAt in pairs(inviteMap) do
			if expiresAt <= now then
				inviteMap[fromUserId] = nil
			end
		end
		if next(inviteMap) == nil then
			pendingInvitesByTarget[targetUserId] = nil
		end
	end
end

local function areFriends(player, otherUserId)
	local ok, result = pcall(function()
		return player:IsFriendsWith(otherUserId)
	end)
	return ok and result == true
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

local function sortByDisplayName(items)
	table.sort(items, function(a, b)
		local an = string.lower(a.displayName or a.name or "")
		local bn = string.lower(b.displayName or b.name or "")
		if an == bn then
			return (a.userId or 0) < (b.userId or 0)
		end
		return an < bn
	end)
end

local function buildPartyData(player)
	local party = getPartyByUserId(player.UserId)
	if not party then
		return nil
	end

	local members = {}
	for memberUserId in pairs(party.members) do
		table.insert(members, playerIdentityByUserId(memberUserId))
	end
	sortByDisplayName(members)

	return {
		partyId = party.id,
		leaderUserId = party.leaderUserId,
		capacity = PARTY_CAPACITY,
		members = members,
	}
end

local function buildIncomingInvites(player)
	local invites = {}
	local inviteMap = pendingInvitesByTarget[player.UserId]
	if not inviteMap then
		return invites
	end

	local now = os.clock()
	for fromUserId, expiresAt in pairs(inviteMap) do
		if expiresAt <= now then
			inviteMap[fromUserId] = nil
		else
			local fromPlayer = Players:GetPlayerByUserId(fromUserId)
			local fromParty = getPartyByUserId(fromUserId)
			if fromPlayer and fromParty and fromParty.leaderUserId == fromUserId then
				table.insert(invites, {
					fromUserId = fromUserId,
					fromName = fromPlayer.Name,
					fromDisplayName = fromPlayer.DisplayName,
					partySize = partySize(fromParty),
					partyCapacity = PARTY_CAPACITY,
				})
			else
				inviteMap[fromUserId] = nil
			end
		end
	end

	if next(inviteMap) == nil then
		pendingInvitesByTarget[player.UserId] = nil
	end

	table.sort(invites, function(a, b)
		local an = string.lower(a.fromDisplayName or a.fromName or "")
		local bn = string.lower(b.fromDisplayName or b.fromName or "")
		if an == bn then
			return a.fromUserId < b.fromUserId
		end
		return an < bn
	end)

	return invites
end

local function buildFriendsData(player)
	local friends = {}
	local myParty = getPartyByUserId(player.UserId)
	local myPartyIsLeader = (not myParty) or myParty.leaderUserId == player.UserId
	local myPartySize = myParty and partySize(myParty) or 1

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and areFriends(player, otherPlayer.UserId) then
			local canInvite = true
			local reason = nil
			local otherParty = getPartyByUserId(otherPlayer.UserId)

			if not myPartyIsLeader then
				canInvite = false
				reason = "Only leader can invite"
			elseif myParty and myPartySize >= PARTY_CAPACITY then
				canInvite = false
				reason = "Party full"
			elseif otherParty then
				canInvite = false
				if myParty and otherParty.id == myParty.id then
					reason = "Already in your party"
				else
					reason = "Already in a party"
				end
			end

			table.insert(friends, {
				userId = otherPlayer.UserId,
				name = otherPlayer.Name,
				displayName = otherPlayer.DisplayName,
				canInvite = canInvite,
				reason = reason,
			})
		end
	end

	sortByDisplayName(friends)
	return friends
end

local function buildStateForPlayer(player)
	cleanupExpiredInvites()

	return {
		party = buildPartyData(player),
		incomingInvites = buildIncomingInvites(player),
		friends = buildFriendsData(player),
		partyCapacity = PARTY_CAPACITY,
	}
end

local function sendMessage(player, text, isError)
	if not player or not partyMessageRemote then
		return
	end
	partyMessageRemote:FireClient(player, {
		text = text,
		isError = isError == true,
	})
end

local function pushStateToPlayer(player)
	if not player or not partyUpdatedRemote then
		return
	end
	partyUpdatedRemote:FireClient(player, buildStateForPlayer(player))
end

local function pushStateToAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		pushStateToPlayer(player)
	end
end

local function ensureLeaderParty(player)
	local party = getPartyByUserId(player.UserId)
	if not party then
		party = createParty(player.UserId)
	end

	if party.leaderUserId ~= player.UserId then
		return nil, "Only the party leader can invite friends."
	end

	return party, nil
end

local function onInviteRequested(player, targetUserId)
	if typeof(targetUserId) ~= "number" then
		sendMessage(player, "Invalid invite target.", true)
		return
	end

	if targetUserId == player.UserId then
		sendMessage(player, "You cannot invite yourself.", true)
		pushStateToPlayer(player)
		return
	end

	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		sendMessage(player, "That friend is not in this server.", true)
		pushStateToPlayer(player)
		return
	end

	if not areFriends(player, targetUserId) then
		sendMessage(player, "You can only invite players on your friends list.", true)
		pushStateToPlayer(player)
		return
	end

	local party, err = ensureLeaderParty(player)
	if not party then
		sendMessage(player, err or "Could not send invite.", true)
		pushStateToPlayer(player)
		return
	end

	if partySize(party) >= PARTY_CAPACITY then
		sendMessage(player, "Party is full.", true)
		pushStateToPlayer(player)
		return
	end

	local targetParty = getPartyByUserId(targetUserId)
	if targetParty then
		if targetParty.id == party.id then
			sendMessage(player, "That friend is already in your party.", true)
		else
			sendMessage(player, "That friend is already in another party.", true)
		end
		pushStateToPlayer(player)
		return
	end

	local now = os.clock()
	local inviteMap = pendingInvitesByTarget[targetUserId]
	if not inviteMap then
		inviteMap = {}
		pendingInvitesByTarget[targetUserId] = inviteMap
	end

	if inviteMap[player.UserId] and inviteMap[player.UserId] > now then
		sendMessage(player, "Invite already sent.", true)
		pushStateToPlayer(player)
		return
	end

	inviteMap[player.UserId] = now + INVITE_EXPIRY_SECONDS
	sendMessage(player, ("Invite sent to %s."):format(targetPlayer.DisplayName))
	sendMessage(targetPlayer, ("%s invited you to a party."):format(player.DisplayName))
	pushStateToAllPlayers()
end

local function onInviteResponse(player, fromUserId, accepted)
	if typeof(fromUserId) ~= "number" or typeof(accepted) ~= "boolean" then
		sendMessage(player, "Invalid party response.", true)
		return
	end

	cleanupExpiredInvites()
	local inviteMap = pendingInvitesByTarget[player.UserId]
	if not inviteMap or not inviteMap[fromUserId] then
		sendMessage(player, "Invite no longer available.", true)
		pushStateToPlayer(player)
		return
	end

	clearInvite(player.UserId, fromUserId)

	local inviterPlayer = Players:GetPlayerByUserId(fromUserId)
	if not accepted then
		sendMessage(player, "Invite declined.")
		if inviterPlayer then
			sendMessage(inviterPlayer, ("%s declined your party invite."):format(player.DisplayName), true)
		end
		pushStateToAllPlayers()
		return
	end

	if getPartyByUserId(player.UserId) then
		sendMessage(player, "Leave your current party before accepting a new invite.", true)
		pushStateToPlayer(player)
		return
	end

	local inviterParty = getPartyByUserId(fromUserId)
	if not inviterPlayer or not inviterParty or inviterParty.leaderUserId ~= fromUserId then
		sendMessage(player, "That party is no longer available.", true)
		pushStateToAllPlayers()
		return
	end

	if partySize(inviterParty) >= PARTY_CAPACITY then
		sendMessage(player, "That party is full.", true)
		pushStateToAllPlayers()
		return
	end

	addMemberToParty(inviterParty, player.UserId)
	sendMessage(player, ("Joined %s's party."):format(inviterPlayer.DisplayName))
	sendMessage(inviterPlayer, ("%s joined your party."):format(player.DisplayName))
	pushStateToAllPlayers()
end

local function onLeaveRequested(player)
	local party = getPartyByUserId(player.UserId)
	if not party then
		sendMessage(player, "You are not currently in a party.", true)
		pushStateToPlayer(player)
		return
	end

	local wasLeader = party.leaderUserId == player.UserId
	local updatedParty = removeMemberFromParty(player.UserId)

	clearIncomingInvitesFor(player.UserId)
	clearOutgoingInvitesFrom(player.UserId)

	sendMessage(player, "You left the party.")
	if wasLeader and updatedParty then
		local newLeader = Players:GetPlayerByUserId(updatedParty.leaderUserId)
		if newLeader then
			sendMessage(newLeader, "You are now the party leader.")
		end
	end

	pushStateToAllPlayers()
end

local function onPlayerRemoving(player)
	local wasLeader = false
	local existingParty = getPartyByUserId(player.UserId)
	if existingParty and existingParty.leaderUserId == player.UserId then
		wasLeader = true
	end

	local updatedParty = removeMemberFromParty(player.UserId)
	clearIncomingInvitesFor(player.UserId)
	clearOutgoingInvitesFrom(player.UserId)

	if wasLeader and updatedParty then
		local newLeader = Players:GetPlayerByUserId(updatedParty.leaderUserId)
		if newLeader then
			sendMessage(newLeader, "You are now the party leader.")
		end
	end

	task.defer(pushStateToAllPlayers)
end

function PartyService.Start()
	if started then
		return
	end
	started = true

	local refs = StateContract.Ensure()
	local remotesRoot = refs.RemotesRoot

	partyGetStateRemote = remotesRoot:WaitForChild("PartyGetState")
	partyInviteRemote = remotesRoot:WaitForChild("PartyInvite")
	partyRespondInviteRemote = remotesRoot:WaitForChild("PartyRespondInvite")
	partyLeaveRemote = remotesRoot:WaitForChild("PartyLeave")
	partyUpdatedRemote = remotesRoot:WaitForChild("PartyUpdated")
	partyMessageRemote = remotesRoot:WaitForChild("PartyMessage")

	partyGetStateRemote.OnServerInvoke = function(player)
		return buildStateForPlayer(player)
	end

	partyInviteRemote.OnServerEvent:Connect(function(player, targetUserId)
		onInviteRequested(player, targetUserId)
	end)

	partyRespondInviteRemote.OnServerEvent:Connect(function(player, fromUserId, accepted)
		onInviteResponse(player, fromUserId, accepted)
	end)

	partyLeaveRemote.OnServerEvent:Connect(function(player)
		onLeaveRequested(player)
	end)

	Players.PlayerAdded:Connect(function()
		task.defer(pushStateToAllPlayers)
	end)

	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function PartyService.GetPartyMemberUserIds(userId)
	local party = getPartyByUserId(userId)
	if not party then
		return nil
	end

	local members = {}
	for memberUserId in pairs(party.members) do
		table.insert(members, memberUserId)
	end
	table.sort(members)
	return members
end

function PartyService.IsPartyLeader(userId)
	local party = getPartyByUserId(userId)
	return party ~= nil and party.leaderUserId == userId
end

function PartyService.GetPartySnapshotForUserId(userId)
	local party = getPartyByUserId(userId)
	if not party then
		return nil
	end

	local members = PartyService.GetPartyMemberUserIds(userId) or {}
	return {
		id = party.id,
		leaderUserId = party.leaderUserId,
		memberUserIds = members,
	}
end

return PartyService
