local QueueBands = {
	{
		min = 1,
		max = 40,
		lobbySize = 6,
	},
	{
		min = 41,
		max = 100,
		lobbySize = 12,
	},
	{
		min = 101,
		max = 500,
		lobbySize = 25,
	},
	{
		min = 501,
		max = math.huge,
		lobbySize = 50,
	},
}

function QueueBands.ResolveLobbySize(queuePopulation)
	local population = math.max(1, math.floor(tonumber(queuePopulation) or 1))
	for _, band in ipairs(QueueBands) do
		if population >= band.min and population <= band.max then
			return band.lobbySize
		end
	end
	return 6
end

return QueueBands
