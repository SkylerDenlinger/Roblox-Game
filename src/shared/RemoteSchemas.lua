local RemoteSchemas = {}

RemoteSchemas.PartyState = {
	party = "table|nil",
	incomingInvites = "table",
	friends = "table",
	partyCapacity = "number",
}

RemoteSchemas.LobbyState = {
	version = "number",
	context = "none|queued|lobby",
	queuePopulation = "number",
	targetLobbySize = "number",
	tournamentPath = "table|nil",
	estimatedRounds = "number|nil",
	sessionId = "string|nil",
	queue = "table|nil",
	lobby = "table|nil",
}

RemoteSchemas.LobbyCommand = {
	op = "QueueJoin|QueueCancel|LobbyLeave|LobbyReady",
	mode = "Public",
}

return RemoteSchemas
