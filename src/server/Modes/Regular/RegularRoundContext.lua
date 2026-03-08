local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local RegularRoundContext = {}
RegularRoundContext.__index = RegularRoundContext

local TEMP_SPECTATE_BOT_NAME = "TempSpectateBot"

local function cloneUserIds(userIds)
	local out = {}
	for _, userId in ipairs(userIds or {}) do
		table.insert(out, userId)
	end
	return out
end

local function makeEntrantSet(userIds)
	local set = {}
	for _, userId in ipairs(userIds or {}) do
		set[userId] = true
	end
	return set
end

local function waitSeconds(duration)
	local finishAt = os.clock() + math.max(0, duration or 0)
	while os.clock() < finishAt do
		task.wait(math.min(0.1, finishAt - os.clock()))
	end
end

local function mergePresentationPatch(patch)
	local merged = {
		ResultsMode = "none",
		PrimaryText = "",
		SecondaryText = "",
		Message = "",
	}
	for key, value in pairs(patch or {}) do
		merged[key] = value
	end
	return merged
end

local function buildWeightedSelection(descriptors, count)
	local pool = {}
	for _, descriptor in ipairs(descriptors or {}) do
		table.insert(pool, descriptor)
	end

	local target = math.min(math.max(0, math.floor(count or 0)), #pool)
	local selected = {}
	while #selected < target and #pool > 0 do
		local totalWeight = 0
		for _, descriptor in ipairs(pool) do
			totalWeight += math.max(0.01, tonumber(descriptor.weight) or 1)
		end

		local roll = math.random() * totalWeight
		local cumulative = 0
		local selectedIndex = #pool
		for index, descriptor in ipairs(pool) do
			cumulative += math.max(0.01, tonumber(descriptor.weight) or 1)
			if roll <= cumulative then
				selectedIndex = index
				break
			end
		end

		table.insert(selected, pool[selectedIndex])
		table.remove(pool, selectedIndex)
	end

	return selected
end

local function buildShowcaseIds(showcaseCount, keySpawnPlan, gearSpawnPlan)
	local showcaseCandidates = {}
	for _, descriptor in ipairs(keySpawnPlan or {}) do
		table.insert(showcaseCandidates, {
			id = ("Key:%s"):format(descriptor.id),
			priority = descriptor.showcasePriority or 0,
		})
	end
	for _, descriptor in ipairs(gearSpawnPlan or {}) do
		table.insert(showcaseCandidates, {
			id = ("Gear:%s"):format(descriptor.id),
			priority = descriptor.showcasePriority or 0,
		})
	end

	table.sort(showcaseCandidates, function(a, b)
		if a.priority == b.priority then
			return a.id < b.id
		end
		return a.priority > b.priority
	end)

	local showcaseIds = {}
	local target = math.min(#showcaseCandidates, math.max(0, math.floor(showcaseCount or 0)))
	for index = 1, target do
		table.insert(showcaseIds, showcaseCandidates[index].id)
	end
	return showcaseIds
end

local function destroyTempSpectateBot()
	local existing = Workspace:FindFirstChild(TEMP_SPECTATE_BOT_NAME)
	if existing then
		existing:Destroy()
	end
end

local function buildFallbackSpectateBot()
	local model = Instance.new("Model")
	model.Name = TEMP_SPECTATE_BOT_NAME

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.CanCollide = false
	head.Anchored = true
	head.Color = Color3.fromRGB(255, 170, 95)
	head.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.CanCollide = false
	torso.Anchored = true
	torso.Color = Color3.fromRGB(45, 60, 95)
	torso.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Part0 = root
	rootWeld.Part1 = torso
	rootWeld.Parent = root

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.Parent = torso

	model.PrimaryPart = root
	return model
end

local function createTempSpectateBot(manifest)
	destroyTempSpectateBot()

	local botModel = nil
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromUserId(1)
	end)
	if ok and result then
		botModel = result
	else
		botModel = buildFallbackSpectateBot()
	end

	botModel.Name = TEMP_SPECTATE_BOT_NAME
	botModel.Parent = Workspace

	local anchorPoint = Vector3.new(0, 12, 0)
	if manifest and manifest.spawnZones and #manifest.spawnZones > 0 then
		anchorPoint = manifest.spawnZones[1].Position + Vector3.new(8, 4, 0)
	end
	botModel:PivotTo(CFrame.new(anchorPoint))

	local root = botModel:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end

	local humanoid = botModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	return botModel
end

local function getCharacterRoot(player)
	if not player or not player.Character then
		return nil
	end
	return player.Character:FindFirstChild("HumanoidRootPart")
end

local function spawnEntrants(manifest, entrantUserIds)
	if not manifest or #manifest.spawnZones == 0 then
		return
	end
	local zone = manifest.spawnZones[math.random(1, #manifest.spawnZones)]
	for index, userId in ipairs(entrantUserIds or {}) do
		local player = Players:GetPlayerByUserId(userId)
		local root = getCharacterRoot(player)
		if root then
			local offsetX = ((index - 1) % 6) * 4 - 10
			local offsetZ = math.floor((index - 1) / 6) * 4
			root.CFrame = zone.CFrame + Vector3.new(offsetX, 4, offsetZ)
		end
	end
end

function RegularRoundContext.new(sessionId, roundSpec, dependencies)
	roundSpec = roundSpec or {}
	dependencies = dependencies or {}

	local roundRules = dependencies.roundRules
	if not roundRules then
		error("RegularRoundContext.new requires roundRules")
	end

	local entrantUserIds = cloneUserIds(roundSpec.entrantUserIds or {})
	local targetQualifiers = math.max(1, math.floor(roundSpec.targetQualifiers or 1))
	local roundIndex = math.max(1, math.floor(roundSpec.roundIndex or 1))
	local totalRounds = math.max(roundIndex, math.floor(roundSpec.totalRounds or roundIndex))
	local requiredKeys = roundRules.Collectibles.RequiredKeys

	local self = setmetatable({
		sessionId = sessionId,
		roundSpec = roundSpec,
		roundRules = roundRules,
		phaseDurations = roundRules.PhaseDurations or {},
		stateReplicator = dependencies.stateReplicator,
		playerStateService = dependencies.playerStateService,
		roundLeaderboardService = dependencies.roundLeaderboardService,
		exitDoorService = dependencies.exitDoorService,
		phase = "Idle",
		startedAt = os.clock(),
		roundIndex = roundIndex,
		totalRounds = totalRounds,
		requiredKeys = requiredKeys,
		targetQualifiers = targetQualifiers,
		isFinalRound = roundSpec.isFinalRound == true or targetQualifiers == 1,
		entrantUserIds = entrantUserIds,
		entrants = makeEntrantSet(entrantUserIds),
		qualifiedAtByUserId = {},
		qualifiedOrder = {},
		keyCountByUserId = {},
		gearCountByUserId = {},
		firstKeyAtByUserId = {},
		leaderboardEntries = {},
		manifest = nil,
		mapId = roundSpec.mapId,
		mapName = roundSpec.mapId or "",
		spawnPlan = nil,
		tempSpectateBot = nil,
	}, RegularRoundContext)

	for _, userId in ipairs(entrantUserIds) do
		self.keyCountByUserId[userId] = 0
		self.gearCountByUserId[userId] = 0
	end

	return self
end

function RegularRoundContext:CloneUserIds(userIds)
	return cloneUserIds(userIds)
end

function RegularRoundContext:WaitSeconds(duration)
	waitSeconds(duration)
end

function RegularRoundContext:InitializeReplicatedState()
	self.playerStateService.ResetRoundStateForUserIds(self.entrantUserIds)
	self.stateReplicator.SetMatchValues({
		SessionId = self.sessionId,
		EntrantCount = #self.entrantUserIds,
		RoundTargetQualifiers = self.targetQualifiers,
		RoundIndex = self.roundIndex,
		RoundId = ("%s-R%d"):format(self.sessionId, self.roundIndex),
		CurrentMapId = "",
		CurrentMapName = "",
		NextMapId = self.roundSpec.mapId or "",
		NextMapName = self.roundSpec.mapId or "",
	})
	self.stateReplicator.ResetProgress(self.requiredKeys, self.targetQualifiers)
	self.stateReplicator.ResetLeaderboard()
	self.stateReplicator.ResetPresentation()
end

function RegularRoundContext:SetPhase(phaseName, duration, extraMatchPatch, presentationPatch)
	self.phase = phaseName
	self.stateReplicator.BeginPhase(phaseName, duration, extraMatchPatch)
	self.stateReplicator.SetPresentationValues(mergePresentationPatch(presentationPatch or {
		Phase = phaseName,
	}))
	self.stateReplicator.SetPresentationValues({
		Phase = phaseName,
	})
end

function RegularRoundContext:SetManifest(manifest)
	self.manifest = manifest
	self.mapId = manifest and manifest.id or self.roundSpec.mapId
	self.mapName = manifest and manifest.name or (self.roundSpec.mapId or "")
end

function RegularRoundContext:CreateTempSpectateBot()
	self.tempSpectateBot = createTempSpectateBot(self.manifest)
	return self.tempSpectateBot
end

function RegularRoundContext:DestroyArtifacts()
	destroyTempSpectateBot()
	self.tempSpectateBot = nil
end

function RegularRoundContext:SpawnEntrants()
	spawnEntrants(self.manifest, self.entrantUserIds)
end

function RegularRoundContext:BuildSpawnPlan()
	local collectibles = self.roundRules.Collectibles or {}
	local keySpawnPlan = buildWeightedSelection(self.manifest and self.manifest.keySpawnPoints or {}, collectibles.KeyCount)
	local gearSpawnPlan = buildWeightedSelection(self.manifest and self.manifest.gearSpawnPoints or {}, collectibles.GearCount)
	return {
		keySpawnPlan = keySpawnPlan,
		gearSpawnPlan = gearSpawnPlan,
		showcaseIds = buildShowcaseIds(collectibles.ShowcaseCount, keySpawnPlan, gearSpawnPlan),
	}
end

function RegularRoundContext:BuildLeaderboardEntries()
	return self.roundLeaderboardService.BuildEntries(self.entrantUserIds, {
		qualifiedAtByUserId = self.qualifiedAtByUserId,
		firstKeyAtByUserId = self.firstKeyAtByUserId,
		keyCountByUserId = self.keyCountByUserId,
		gearCountByUserId = self.gearCountByUserId,
	})
end

function RegularRoundContext:UpdateQualificationProgress()
	local count = #self.qualifiedOrder
	local remaining = math.max(0, self.targetQualifiers - count)
	self.stateReplicator.SetProgressValues({
		QualifiedCount = count,
		EscapedCount = count,
		RemainingQualifierSlots = remaining,
	})
end

function RegularRoundContext:RefreshLeaderboardState()
	local entries = self:BuildLeaderboardEntries()
	self.leaderboardEntries = entries
	self.stateReplicator.SetLeaderboardEntries(entries)

	local topEntry = nil
	for _, entry in ipairs(entries) do
		if entry.isOnline ~= false then
			topEntry = entry
			break
		end
	end

	self.stateReplicator.SetPresentationValues({
		SpectateTargetUserId = topEntry and topEntry.userId or 0,
		SpectateTargetName = topEntry and topEntry.displayName or "",
	})
	return entries
end

function RegularRoundContext:AddQualifiedInternal(userId, serverTimestamp)
	if self.qualifiedAtByUserId[userId] then
		return false
	end
	if #self.qualifiedOrder >= self.targetQualifiers then
		return false
	end

	self.qualifiedAtByUserId[userId] = serverTimestamp
	table.insert(self.qualifiedOrder, userId)
	table.sort(self.qualifiedOrder, function(a, b)
		local at = self.qualifiedAtByUserId[a] or math.huge
		local bt = self.qualifiedAtByUserId[b] or math.huge
		if at == bt then
			return a < b
		end
		return at < bt
	end)

	self.playerStateService.SetQualified(userId, true, serverTimestamp)
	print(("[telemetry] player_qualified %s"):format(HttpService:JSONEncode({
		sessionId = self.sessionId,
		roundIndex = self.roundIndex,
		userId = userId,
		at = serverTimestamp,
	})))
	self:UpdateQualificationProgress()
	self:RefreshLeaderboardState()
	return true
end

function RegularRoundContext:HandleKeyCollected(userId, collectedAt, keysCount)
	if keysCount > 0 and not self.firstKeyAtByUserId[userId] then
		self.firstKeyAtByUserId[userId] = collectedAt
	end
	self.keyCountByUserId[userId] = keysCount
	self.exitDoorService.EvaluateUser(userId)
	self:RefreshLeaderboardState()
end

function RegularRoundContext:HandleGearCollected(userId, gearsCount)
	self.gearCountByUserId[userId] = gearsCount
	self:RefreshLeaderboardState()
end

function RegularRoundContext:BuildQualifiedUserIds()
	local qualified = {}
	for _, userId in ipairs(self.qualifiedOrder or {}) do
		if Players:GetPlayerByUserId(userId) then
			table.insert(qualified, userId)
		end
	end
	return qualified
end

function RegularRoundContext:ApplyFallbackPromotions(collectathonEnd)
	local qualified = self:BuildQualifiedUserIds()
	if #qualified >= self.targetQualifiers then
		return qualified, false
	end

	local needed = self.targetQualifiers - #qualified
	local entries = self:RefreshLeaderboardState()
	local promotions = self.roundLeaderboardService.SelectFallbackQualifiers(entries, qualified, needed)
	if #promotions == 0 then
		return qualified, false
	end

	for index, userId in ipairs(promotions) do
		self:AddQualifiedInternal(userId, collectathonEnd + index * 0.0001)
	end
	return self:BuildQualifiedUserIds(), true
end

function RegularRoundContext:BuildEliminatedUserIds(entries, qualifiedUserIds)
	local qualifiedSet = {}
	for _, userId in ipairs(qualifiedUserIds or {}) do
		qualifiedSet[userId] = true
	end

	local eliminated = {}
	for _, entry in ipairs(entries or {}) do
		if not qualifiedSet[entry.userId] then
			table.insert(eliminated, entry.userId)
		end
	end
	return eliminated
end

function RegularRoundContext:BuildPlayerStats(entries, qualifiedUserIds, winnerUserId)
	local qualifiedSet = {}
	for _, userId in ipairs(qualifiedUserIds or {}) do
		qualifiedSet[userId] = true
	end

	local statsByUserId = {}
	for _, entry in ipairs(entries or {}) do
		statsByUserId[entry.userId] = {
			placement = entry.rank,
			keys = entry.keys,
			gears = entry.gears,
			qualified = qualifiedSet[entry.userId] == true,
			resultMode = (winnerUserId > 0 and entry.userId == winnerUserId and "winner")
				or (qualifiedSet[entry.userId] == true and "qualified")
				or "eliminated",
			qualifiedAtServerTime = entry.qualifiedAtServerTime or 0,
			firstKeyAtServerTime = entry.firstKeyAtServerTime or 0,
			displayName = entry.displayName,
		}
	end
	return statsByUserId
end

function RegularRoundContext:ApplyRoundPlacements(entries, qualifiedUserIds, winnerUserId)
	local qualifiedSet = {}
	for _, userId in ipairs(qualifiedUserIds or {}) do
		qualifiedSet[userId] = true
	end

	for _, entry in ipairs(entries or {}) do
		local resultMode = "eliminated"
		if winnerUserId > 0 and entry.userId == winnerUserId then
			resultMode = "winner"
		elseif qualifiedSet[entry.userId] then
			resultMode = "qualified"
		end

		self.playerStateService.SetValues(entry.userId, {
			Placement = entry.rank,
			ResultMode = resultMode,
			Eliminated = resultMode == "eliminated",
			LastRoundKeys = entry.keys,
			LastRoundGears = entry.gears,
		})
	end
end

function RegularRoundContext:ResolveDisplayName(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName or player.Name
	end
	return tostring(userId or 0)
end

function RegularRoundContext:TryQualifyPlayer(userId, serverTimestamp)
	if self.phase ~= "Collectathon" then
		return false
	end
	if self.entrants[userId] ~= true then
		return false
	end
	if self.playerStateService.GetKeys(userId) < self.requiredKeys then
		return false
	end

	self.exitDoorService.EvaluateUser(userId)
	if not self.exitDoorService.HasAccess(userId) then
		return false
	end

	return self:AddQualifiedInternal(userId, serverTimestamp or os.clock())
end

return RegularRoundContext
