local PlayController = {}
PlayController.__index = PlayController

function PlayController.new(options)
	local self = setmetatable({}, PlayController)
	self.localPlayer = options.localPlayer
	self.replicatedStorage = options.replicatedStorage
	self.ui = options.ui
	self.waitForChildTimeout = options.waitForChildTimeout
	self.themeColors = options.themeColors
	self.constants = options.constants
	self.partyDisplayName = options.partyDisplayName

	self.onLobbyFormed = nil
	self.onPlayScreenChanged = nil
	self.lastEmittedInPlayScreen = nil

	self.lobbyRemotes = nil
	self.isInPlayScreen = false
	self.isSearchingForMatch = false
	self.playStatusText = nil
	self.playStatusIsError = false
	self.currentLobbyContext = "none"
	self.lobbyPreviewMembers = {}
	self.currentLobbyTarget = options.constants.LOBBY_PLAYER_TARGET
	self.playUiBound = false
	self.lobbyUiBound = false
	return self
end

function PlayController:SetOnLobbyFormed(callback)
	self.onLobbyFormed = callback
end

function PlayController:SetOnPlayScreenChanged(callback)
	self.onPlayScreenChanged = callback
end

function PlayController:GetIsInPlayScreen()
	return self.isInPlayScreen
end

function PlayController:SetPlayStatus(text, isError)
	if text == nil or text == "" then
		self.playStatusText = nil
		self.playStatusIsError = false
		return
	end
	self.playStatusText = tostring(text)
	self.playStatusIsError = isError == true
end

function PlayController:GetLobbyRemotes()
	if self.lobbyRemotes then
		return self.lobbyRemotes
	end
	local remotesRoot = self.waitForChildTimeout(self.replicatedStorage, "Remotes", 10, "HomepageOverlay")
	self.lobbyRemotes = {
		getState = self.waitForChildTimeout(remotesRoot, "LobbyGetState", 10, "HomepageOverlay"),
		command = self.waitForChildTimeout(remotesRoot, "LobbyCommand", 10, "HomepageOverlay"),
		updated = self.waitForChildTimeout(remotesRoot, "LobbyUpdated", 10, "HomepageOverlay"),
		message = self.waitForChildTimeout(remotesRoot, "LobbyMessage", 10, "HomepageOverlay"),
	}
	return self.lobbyRemotes
end

function PlayController:StartSearch()
	local remotes = self:GetLobbyRemotes()
	remotes.command:FireServer({
		op = "QueueJoin",
		mode = "Public",
	})
	return true
end

function PlayController:CancelSearch()
	local remotes = self:GetLobbyRemotes()
	remotes.command:FireServer({
		op = "QueueCancel",
	})
	return true
end

function PlayController:GetLobbyState()
	local remotes = self:GetLobbyRemotes()
	local ok, state = pcall(function()
		return remotes.getState:InvokeServer()
	end)
	if not ok or type(state) ~= "table" then
		return nil
	end
	return state
end

function PlayController:SnapshotLobbyMembersFromState(state)
	local members = {}
	local target = math.max(1, self.currentLobbyTarget or self.constants.LOBBY_PLAYER_TARGET)
	local source = nil
	if state.context == "lobby" and type(state.lobby) == "table" and type(state.lobby.members) == "table" then
		source = state.lobby.members
	elseif type(state.queue) == "table" and type(state.queue.members) == "table" then
		source = state.queue.members
	elseif type(state.lobby) == "table" and type(state.lobby.members) == "table" then
		source = state.lobby.members
	end

	if source then
		for _, entry in ipairs(source) do
			if type(entry) == "table" then
				table.insert(members, entry)
				if #members >= target then
					break
				end
			end
		end
	end

	return members
end

function PlayController:UpdateLobbyRosterUi()
	local uiSlots = #self.ui.lobbySlotRows
	local target = math.max(1, self.currentLobbyTarget or self.constants.LOBBY_PLAYER_TARGET)
	local joinedCount = math.min(#self.lobbyPreviewMembers, target)
	local showRoster = self.isInPlayScreen and (self.isSearchingForMatch or self.currentLobbyContext == "lobby" or joinedCount > 0)
	self.ui.lobbyRosterPanel.Visible = showRoster
	if not showRoster then
		return
	end

	self.ui.lobbyRosterCountLabel.Text = ("%d/%d"):format(joinedCount, target)

	if joinedCount >= target or self.currentLobbyContext == "lobby" then
		self.ui.lobbyRosterStatusLabel.Text = "Round begins now"
		self.ui.lobbyRosterStatusLabel.TextColor3 = self.themeColors.orange
	else
		self.ui.lobbyRosterStatusLabel.Text = "Waiting for players"
		self.ui.lobbyRosterStatusLabel.TextColor3 = self.themeColors.offWhite
	end

	for i = 1, uiSlots do
		local row = self.ui.lobbySlotRows[i]
		local label = self.ui.lobbySlotLabels[i]
		local member = self.lobbyPreviewMembers[i]
		if member then
			label.Text = self.partyDisplayName(member)
			label.TextColor3 = self.themeColors.white
			row.BackgroundColor3 = self.themeColors.charcoalLight
			row.BackgroundTransparency = 0.06
		else
			label.Text = "Waiting for player..."
			label.TextColor3 = self.themeColors.orangeLight
			row.BackgroundColor3 = self.themeColors.charcoal
			row.BackgroundTransparency = 0.22
		end
	end
end

function PlayController:EmitPlayScreenChangedIfNeeded()
	if self.lastEmittedInPlayScreen == self.isInPlayScreen then
		return
	end
	self.lastEmittedInPlayScreen = self.isInPlayScreen
	if self.onPlayScreenChanged then
		self.onPlayScreenChanged(self.isInPlayScreen)
	end
end

function PlayController:UpdatePlayScreenUi()
	self.ui.playScreen.Visible = self.isInPlayScreen
	self.ui.menu.Visible = not self.isInPlayScreen
	self.ui.partyTabButton.Visible = not self.isInPlayScreen

	self.ui.playSearchButton.Visible = self.isInPlayScreen and (not self.isSearchingForMatch)
	self.ui.playCancelButton.Visible = self.isInPlayScreen and self.isSearchingForMatch

	if self.isSearchingForMatch then
		self.ui.playQueueStatusLabel.Visible = self.isInPlayScreen
		self.ui.playQueueStatusLabel.Text = "Finding match..."
		self.ui.playQueueStatusLabel.TextColor3 = self.themeColors.white
	elseif self.playStatusText and self.playStatusText ~= "" then
		self.ui.playQueueStatusLabel.Visible = self.isInPlayScreen
		self.ui.playQueueStatusLabel.Text = self.playStatusText
		self.ui.playQueueStatusLabel.TextColor3 = self.playStatusIsError and self.themeColors.orangeLight or self.themeColors.white
	else
		self.ui.playQueueStatusLabel.Visible = false
	end

	self:UpdateLobbyRosterUi()
	self:EmitPlayScreenChangedIfNeeded()
end

function PlayController:ApplyLobbyState(state)
	if type(state) ~= "table" then
		return
	end

	local context = state.context
	self.currentLobbyContext = context or "none"
	if type(state.targetLobbySize) == "number" then
		self.currentLobbyTarget = math.max(1, math.floor(state.targetLobbySize))
	else
		self.currentLobbyTarget = self.constants.LOBBY_PLAYER_TARGET
	end
	self.lobbyPreviewMembers = self:SnapshotLobbyMembersFromState(state)

	if context == "queued" then
		self.isSearchingForMatch = true
		if self.playStatusText == "Lobby formed." then
			self:SetPlayStatus(nil, false)
		end
	elseif context == "lobby" then
		self.isSearchingForMatch = false
		self:SetPlayStatus("Lobby formed.", false)
		if self.isInPlayScreen and self.onLobbyFormed then
			self.onLobbyFormed()
		end
	else
		self.isSearchingForMatch = false
		if self.playStatusText == "Lobby formed." or self.playStatusText == "Searching for match..." or self.playStatusText == "Cancelling search..." then
			self:SetPlayStatus(nil, false)
		end
	end

	self:UpdatePlayScreenUi()
end

function PlayController:RequestLobbyState()
	local state = self:GetLobbyState()
	if state then
		self:ApplyLobbyState(state)
		return
	end

	self.isSearchingForMatch = false
	self.currentLobbyContext = "none"
	self.lobbyPreviewMembers = {}
	self:SetPlayStatus("Failed to load lobby state.", true)
	self:UpdatePlayScreenUi()
end

function PlayController:BindLobbyUi()
	if self.lobbyUiBound then
		return
	end
	local remotes = self:GetLobbyRemotes()

	remotes.updated.OnClientEvent:Connect(function(state)
		if type(state) == "table" then
			self:ApplyLobbyState(state)
		end
	end)

	remotes.message.OnClientEvent:Connect(function(payload)
		local text = nil
		local isError = false
		if type(payload) == "table" then
			text = payload.text
			isError = payload.isError == true
		elseif payload ~= nil then
			text = payload
		end
		if text ~= nil and tostring(text) ~= "" then
			self:SetPlayStatus(tostring(text), isError)
			self:UpdatePlayScreenUi()
		end
	end)

	self:RequestLobbyState()
	self.lobbyUiBound = true
end

function PlayController:BindPlayUi()
	if self.playUiBound then
		return
	end
	self.ui.playButton.MouseButton1Click:Connect(function()
		self.isInPlayScreen = true
		self:RequestLobbyState()
		self:UpdatePlayScreenUi()
	end)

	self.ui.playMainMenuButton.MouseButton1Click:Connect(function()
		if self.isSearchingForMatch then
			self:CancelSearch()
		end
		self.isInPlayScreen = false
		self:UpdatePlayScreenUi()
	end)

	self.ui.playSearchButton.MouseButton1Click:Connect(function()
		if self.isSearchingForMatch then
			return
		end

		local ok = self:StartSearch()
		if not ok then
			self:SetPlayStatus("Queue unavailable", true)
			self:UpdatePlayScreenUi()
			return
		end

		self.currentLobbyContext = "queued"
		self.lobbyPreviewMembers = {
			{
				userId = self.localPlayer.UserId,
				name = self.localPlayer.Name,
				displayName = self.localPlayer.DisplayName,
			},
		}
		self.isSearchingForMatch = true
		self:SetPlayStatus(nil, false)
		self:UpdatePlayScreenUi()
	end)

	self.ui.playCancelButton.MouseButton1Click:Connect(function()
		if not self.isSearchingForMatch then
			return
		end
		local ok = self:CancelSearch()
		if ok then
			self.isSearchingForMatch = false
			self.currentLobbyContext = "none"
			self.lobbyPreviewMembers = {}
			self:SetPlayStatus("Cancelling search...", false)
		else
			self:SetPlayStatus("Queue unavailable", true)
		end
		self:UpdatePlayScreenUi()
	end)
	self.playUiBound = true
end

return PlayController
