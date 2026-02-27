local RunService = game:GetService("RunService")

local FillLobbyService = {}

local ENABLED = true

local BOT_POOL = {}
for i = 1, 80 do
	table.insert(BOT_POOL, {
		userId = 91000000 + i,
		name = ("Bot%02d"):format(i),
	})
end

local identityByUserId = {}
for _, bot in ipairs(BOT_POOL) do
	identityByUserId[bot.userId] = bot
end

local function cloneUserIds(userIds)
	local out = {}
	for _, userId in ipairs(userIds) do
		table.insert(out, userId)
	end
	return out
end

local function shouldUseFillLobby(mode)
	return ENABLED and RunService:IsStudio() and mode == "Public"
end

function FillLobbyService.IsEnabledForMode(mode)
	return shouldUseFillLobby(mode)
end

function FillLobbyService.AugmentQueueMembers(memberUserIds, targetLobbySize, mode)
	if not shouldUseFillLobby(mode or "Public") then
		return memberUserIds, false
	end

	local out = cloneUserIds(memberUserIds)
	local seen = {}
	for _, userId in ipairs(out) do
		seen[userId] = true
	end

	local target = math.max(#out, math.floor(tonumber(targetLobbySize) or #out))
	local botIndex = 1
	while #out < target do
		local bot = BOT_POOL[((botIndex - 1) % #BOT_POOL) + 1]
		botIndex += 1
		if not seen[bot.userId] then
			seen[bot.userId] = true
			table.insert(out, bot.userId)
		end
	end

	return out, (#out > #memberUserIds)
end

function FillLobbyService.ResolveIdentity(userId)
	local bot = identityByUserId[userId]
	if not bot then
		return nil
	end
	return {
		userId = userId,
		name = bot.name,
		displayName = bot.name,
	}
end

return FillLobbyService
