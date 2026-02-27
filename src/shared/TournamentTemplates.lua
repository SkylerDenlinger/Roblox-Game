local TournamentTemplates = {
	[50] = { 50, 25, 12, 6, 1 },
	[25] = { 25, 12, 6, 1 },
	[12] = { 12, 6, 1 },
	[6] = { 6, 1 },
}

local function clonePath(path)
	local copy = {}
	for _, value in ipairs(path) do
		table.insert(copy, value)
	end
	return copy
end

local function insertStart(path, startSize)
	if path[1] == startSize then
		return path
	end
	local withStart = { startSize }
	for _, value in ipairs(path) do
		if value < startSize then
			table.insert(withStart, value)
		end
	end
	if withStart[#withStart] ~= 1 then
		table.insert(withStart, 1)
	end
	return withStart
end

function TournamentTemplates.BuildPath(startSize)
	local size = math.max(2, math.floor(tonumber(startSize) or 2))
	local template = nil
	if size >= 50 then
		template = TournamentTemplates[50]
	elseif size >= 25 then
		template = TournamentTemplates[25]
	elseif size >= 12 then
		template = TournamentTemplates[12]
	elseif size >= 6 then
		template = TournamentTemplates[6]
	else
		template = { 6, 1 }
	end
	return insertStart(clonePath(template), size)
end

return TournamentTemplates
