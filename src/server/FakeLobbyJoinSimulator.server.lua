-- TEMP TEST SCRIPT: delete after matchmaking/lobby visuals are finalized.
-- Simulates players joining the lobby while searching (1/6 -> 6/6), then marks round start.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local ENABLED = true
if not ENABLED then
	return
end

local TARGET_PLAYERS = 6
local STEP_DELAY_SECONDS = 1.1
local REMOTE_TIMEOUT_SECONDS = 15

local FAKE_BOTS = {
	{ userId = 900001, name = "Blitz" },
	{ userId = 900002, name = "Velocity" },
	{ userId = 900003, name = "Pulse" },
	{ userId = 900004, name = "Apex" },
	{ userId = 900005, name = "Echo" },
}

local runTokenByUserId = {}
local version = 0

local function bumpVersion()
	version += 1
	return version
end

local function nextRunToken(userId)
	local token = (runTokenByUserId[userId] or 0) + 1
	runTokenByUserId[userId] = token
	return token
end

local function isRunActive(userId, token)
	return runTokenByUserId[userId] == token
end

local function waitForLobbyRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", REMOTE_TIMEOUT_SECONDS)
	if not remotesFolder then
		error("FakeLobbyJoinSimulator: Remotes folder not found")
	end

	local command = remotesFolder:WaitForChild("LobbyCommand", REMOTE_TIMEOUT_SECONDS)
	local updated = remotesFolder:WaitForChild("LobbyUpdated", REMOTE_TIMEOUT_SECONDS)
	local message = remotesFolder:WaitForChild("LobbyMessage", REMOTE_TIMEOUT_SECONDS)
	if not command or not updated or not message then
		error("FakeLobbyJoinSimulator: Required lobby remotes are missing")
	end

	return command, updated, message
end

local lobbyCommandRemote, lobbyUpdatedRemote, lobbyMessageRemote = waitForLobbyRemotes()

local function identity(userId, name)
	return {
		userId = userId,
		name = name,
		displayName = name,
	}
end

local function identityFromPlayer(player)
	return {
		userId = player.UserId,
		name = player.Name,
		displayName = player.DisplayName,
	}
end

local function queueStateFor(player, botCount)
	local members = { identityFromPlayer(player) }
	local maxBots = math.min(botCount, TARGET_PLAYERS - 1, #FAKE_BOTS)
	for i = 1, maxBots do
		local bot = FAKE_BOTS[i]
		table.insert(members, identity(bot.userId, bot.name))
	end

	return {
		version = bumpVersion(),
		context = "queued",
		targetPlayers = TARGET_PLAYERS,
		queue = {
			leaderUserId = player.UserId,
			mode = "Public",
			queuedAt = os.clock(),
			requiredPlayers = TARGET_PLAYERS,
			members = members,
		},
		lobby = nil,
	}
end

local function lobbyStateFor(player)
	local members = { identityFromPlayer(player) }
	for i = 1, math.min(TARGET_PLAYERS - 1, #FAKE_BOTS) do
		local bot = FAKE_BOTS[i]
		table.insert(members, identity(bot.userId, bot.name))
	end

	return {
		version = bumpVersion(),
		context = "lobby",
		targetPlayers = TARGET_PLAYERS,
		queue = nil,
		lobby = {
			id = "SIM-LOBBY",
			leaderUserId = player.UserId,
			status = "Formed",
			createdAt = os.clock(),
			requiredPlayers = TARGET_PLAYERS,
			members = members,
		},
	}
end

local function noneState()
	return {
		version = bumpVersion(),
		context = "none",
		targetPlayers = TARGET_PLAYERS,
		queue = nil,
		lobby = nil,
	}
end

local function pushState(player, state)
	lobbyUpdatedRemote:FireClient(player, state)
end

local function pushMessage(player, text, isError)
	lobbyMessageRemote:FireClient(player, {
		text = text,
		isError = isError == true,
	})
end

local function cancelSimulation(player, reasonText)
	nextRunToken(player.UserId)
	pushState(player, noneState())
	if reasonText and reasonText ~= "" then
		pushMessage(player, reasonText, false)
	end
end

local function runSimulation(player)
	local userId = player.UserId
	local token = nextRunToken(userId)

	task.spawn(function()
		pushState(player, queueStateFor(player, 0))
		pushMessage(player, ("Simulation: 1/%d players joined"):format(TARGET_PLAYERS))

		for botCount = 1, TARGET_PLAYERS - 1 do
			task.wait(STEP_DELAY_SECONDS)
			if player.Parent ~= Players or not isRunActive(userId, token) then
				return
			end

			local joinedCount = math.min(botCount + 1, TARGET_PLAYERS)
			pushState(player, queueStateFor(player, botCount))
			pushMessage(player, ("Simulation: %d/%d players joined"):format(joinedCount, TARGET_PLAYERS))
		end

		task.wait(0.8)
		if player.Parent ~= Players or not isRunActive(userId, token) then
			return
		end

		pushState(player, lobbyStateFor(player))
		pushMessage(player, ("Simulation: %d/%d reached. Round begins."):format(TARGET_PLAYERS, TARGET_PLAYERS))
		runTokenByUserId[userId] = nil
	end)
end

local function attachPlayer(player)
	player.Chatted:Connect(function(message)
		local lowered = string.lower(tostring(message))
		if lowered == "/fakelobby" then
			runSimulation(player)
		elseif lowered == "/fakelobbycancel" then
			cancelSimulation(player, "Simulation cancelled.")
		end
	end)
end

lobbyCommandRemote.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then
		return
	end

	local op = payload.op
	if op == "QueueJoin" then
		runSimulation(player)
	elseif op == "QueueCancel" then
		cancelSimulation(player, "Simulation: matchmaking cancelled.")
	end
end)

Players.PlayerAdded:Connect(attachPlayer)
Players.PlayerRemoving:Connect(function(player)
	runTokenByUserId[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	attachPlayer(player)
end

