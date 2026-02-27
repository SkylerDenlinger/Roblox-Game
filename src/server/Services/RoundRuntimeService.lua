local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoundRules = require(Shared:WaitForChild("RoundRules"))

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local MapManifestLoader = require(script.Parent:WaitForChild("MapManifestLoader"))
local KeyCollectibleService = require(script.Parent:WaitForChild("KeyCollectibleService"))
local GearCollectibleService = require(script.Parent:WaitForChild("GearCollectibleService"))
local ExitDoorService = require(script.Parent:WaitForChild("ExitDoorService"))
local QualificationZoneService = require(script.Parent:WaitForChild("QualificationZoneService"))

local RoundRuntimeService = {}

local stateReplicator = nil
local activeRound = nil

local function makeEntrantSet(userIds)
	local set = {}
	for _, userId in ipairs(userIds) do
		set[userId] = true
	end
	return set
end

local function waitSeconds(duration)
	local finishAt = os.clock() + math.max(0, duration or 0)
	while os.clock() < finishAt do
		task.wait(0.1)
	end
end

local function getCharacterRoot(player)
	if not player or not player.Character then
		return nil
	end
	return player.Character:FindFirstChild("HumanoidRootPart")
end

local function spawnEntrants(manifest, entrantUserIds)
	if #manifest.spawnZones == 0 then
		return
	end
	local zone = manifest.spawnZones[math.random(1, #manifest.spawnZones)]
	for index, userId in ipairs(entrantUserIds) do
		local player = Players:GetPlayerByUserId(userId)
		local root = getCharacterRoot(player)
		if root then
			local offsetX = ((index - 1) % 6) * 4 - 10
			local offsetZ = math.floor((index - 1) / 6) * 4
			root.CFrame = zone.CFrame + Vector3.new(offsetX, 4, offsetZ)
		end
	end
end

local function updateQualificationProgress()
	if not activeRound then
		return
	end
	local count = #activeRound.qualifiedOrder
	local remaining = math.max(0, activeRound.targetQualifiers - count)
	stateReplicator.SetProgressValues({
		QualifiedCount = count,
		EscapedCount = count,
		RemainingQualifierSlots = remaining,
	})
end

local function addQualified(userId, serverTimestamp)
	if not activeRound then
		return false
	end
	if activeRound.qualifiedAtByUserId[userId] then
		return false
	end
	if #activeRound.qualifiedOrder >= activeRound.targetQualifiers then
		return false
	end
	activeRound.qualifiedAtByUserId[userId] = serverTimestamp
	table.insert(activeRound.qualifiedOrder, userId)
	table.sort(activeRound.qualifiedOrder, function(a, b)
		local at = activeRound.qualifiedAtByUserId[a] or math.huge
		local bt = activeRound.qualifiedAtByUserId[b] or math.huge
		if at == bt then
			return a < b
		end
		return at < bt
	end)
	PlayerStateService.SetQualified(userId, true, serverTimestamp)
	print(("[telemetry] player_qualified %s"):format(HttpService:JSONEncode({
		sessionId = activeRound.sessionId,
		roundIndex = activeRound.roundIndex,
		userId = userId,
		at = serverTimestamp,
	})))
	updateQualificationProgress()
	return true
end

local function buildFallbackQualifiers(entrantUserIds, targetCount)
	local ranked = {}
	for _, userId in ipairs(entrantUserIds) do
		if Players:GetPlayerByUserId(userId) then
			table.insert(ranked, {
				userId = userId,
				keys = PlayerStateService.GetKeys(userId),
				firstKeyAt = activeRound and activeRound.firstKeyAtByUserId[userId] or nil,
			})
		end
	end
	table.sort(ranked, function(a, b)
		if a.keys ~= b.keys then
			return a.keys > b.keys
		end
		local af = a.firstKeyAt or math.huge
		local bf = b.firstKeyAt or math.huge
		if af ~= bf then
			return af < bf
		end
		return a.userId < b.userId
	end)
	local qualifiers = {}
	if #ranked == 0 then
		return qualifiers
	end
	local count = math.max(1, math.min(targetCount, #ranked))
	for i = 1, count do
		local row = ranked[i]
		table.insert(qualifiers, row.userId)
		PlayerStateService.SetQualified(row.userId, true, activeRound.startedAt + i * 0.0001)
	end
	return qualifiers
end

local function setPhase(phaseName, duration, patch)
	if not activeRound then
		return
	end
	activeRound.phase = phaseName
	stateReplicator.BeginPhase(phaseName, duration, patch)
end

local function startCollectibles(manifest)
	KeyCollectibleService.StartRound({
		spawnPoints = manifest.keySpawnPoints,
		count = RoundRules.Collectibles.KeyCount,
		isPlayerAllowed = function(userId)
			return activeRound and activeRound.entrants[userId] == true
		end,
		onCollected = function(userId, collectedAt, keysCount)
			if not activeRound then
				return
			end
			if keysCount > 0 and not activeRound.firstKeyAtByUserId[userId] then
				activeRound.firstKeyAtByUserId[userId] = collectedAt
			end
			activeRound.keyCountByUserId[userId] = keysCount
			ExitDoorService.EvaluateUser(userId)
		end,
	})

	GearCollectibleService.StartRound({
		spawnPoints = manifest.gearSpawnPoints,
		count = RoundRules.Collectibles.GearCount,
		isPlayerAllowed = function(userId)
			return activeRound and activeRound.entrants[userId] == true
		end,
	})
end

local function stopCollectibles()
	KeyCollectibleService.EndRound()
	GearCollectibleService.EndRound()
end

function RoundRuntimeService.Start(options)
	options = options or {}
	stateReplicator = options.stateReplicator
	if not stateReplicator then
		error("RoundRuntimeService.Start requires stateReplicator")
	end
	QualificationZoneService.SetQualificationHandler(function(userId, serverTimestamp)
		RoundRuntimeService.TryQualifyPlayer(userId, serverTimestamp)
	end)
end

function RoundRuntimeService.TryQualifyPlayer(userId, serverTimestamp)
	if not activeRound or activeRound.phase ~= "Collectathon" then
		return false
	end
	if activeRound.entrants[userId] ~= true then
		return false
	end
	if PlayerStateService.GetKeys(userId) < activeRound.requiredKeys then
		return false
	end
	ExitDoorService.EvaluateUser(userId)
	if not ExitDoorService.HasAccess(userId) then
		return false
	end
	local added = addQualified(userId, serverTimestamp or os.clock())
	return added
end

function RoundRuntimeService.RunRound(sessionId, roundSpec)
	roundSpec = roundSpec or {}
	local entrantUserIds = roundSpec.entrantUserIds or {}
	local targetQualifiers = math.max(1, math.floor(roundSpec.targetQualifiers or 1))
	local mapId = roundSpec.mapId

	local manifest = MapManifestLoader.Resolve(mapId)
	if manifest.exitDoor then
		ExitDoorService.BindDoor(manifest.exitDoor)
	end
	if manifest.qualificationZone then
		QualificationZoneService.BindZone(manifest.qualificationZone)
	end

	local durations = RoundRules.PhaseDurations
	local requiredKeys = RoundRules.Collectibles.RequiredKeys

	activeRound = {
		sessionId = sessionId,
		roundIndex = roundSpec.roundIndex or 1,
		phase = "Idle",
		startedAt = os.clock(),
		targetQualifiers = targetQualifiers,
		requiredKeys = requiredKeys,
		entrantUserIds = entrantUserIds,
		entrants = makeEntrantSet(entrantUserIds),
		qualifiedAtByUserId = {},
		qualifiedOrder = {},
		keyCountByUserId = {},
		firstKeyAtByUserId = {},
	}

	PlayerStateService.ResetRoundStateForUserIds(entrantUserIds)
	stateReplicator.SetMatchValues({
		SessionId = sessionId,
		EntrantCount = #entrantUserIds,
		RoundTargetQualifiers = targetQualifiers,
		CurrentMapId = manifest.id,
		CurrentMapName = manifest.name,
	})
	stateReplicator.ResetProgress(requiredKeys, targetQualifiers)

	setPhase("Lobby", durations.Lobby, {
		RoundIndex = activeRound.roundIndex,
	})
	spawnEntrants(manifest, entrantUserIds)
	waitSeconds(durations.Lobby)

	setPhase("Countdown", durations.Countdown)
	waitSeconds(durations.Countdown)

	ExitDoorService.StartRound({
		requiredKeys = requiredKeys,
		entrantUserIds = entrantUserIds,
	})
	QualificationZoneService.StartRound({
		entrantUserIds = entrantUserIds,
	})
	startCollectibles(manifest)

	setPhase("Collectathon", durations.Collectathon)
	local collectathonEnd = os.clock() + durations.Collectathon
	local endedBy = "Timeout"
	while os.clock() < collectathonEnd do
		if #activeRound.qualifiedOrder >= targetQualifiers then
			endedBy = "QualifyCountReached"
			break
		end
		task.wait(0.1)
	end

	stopCollectibles()
	QualificationZoneService.EndRound()
	ExitDoorService.EndRound()

	local qualified = {}
	for _, userId in ipairs(activeRound.qualifiedOrder) do
		if Players:GetPlayerByUserId(userId) then
			table.insert(qualified, userId)
		end
	end

	local usedFallback = false
	if #qualified == 0 then
		qualified = buildFallbackQualifiers(entrantUserIds, targetQualifiers)
		usedFallback = true
	end

	stateReplicator.SetProgressValues({
		QualifiedCount = #qualified,
		EscapedCount = #qualified,
		RemainingQualifierSlots = math.max(0, targetQualifiers - #qualified),
	})

	local winnerUserId = 0
	if targetQualifiers == 1 and #qualified > 0 then
		winnerUserId = qualified[1]
		stateReplicator.SetProgressValues({
			WinnerUserId = winnerUserId,
		})
	end

	setPhase("MatchEnded", durations.MatchEnded)
	waitSeconds(durations.MatchEnded)

	setPhase("Intermission", durations.Intermission)
	waitSeconds(durations.Intermission)

	activeRound = nil
	return {
		qualifiedUserIds = qualified,
		winnerUserId = winnerUserId,
		endedBy = endedBy,
		usedFallback = usedFallback,
	}
end

return RoundRuntimeService
