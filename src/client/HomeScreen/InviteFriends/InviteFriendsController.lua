local InviteFriendsController = {}
InviteFriendsController.__index = InviteFriendsController

function InviteFriendsController.new(options)
	local self = setmetatable({}, InviteFriendsController)
	self.localPlayer = options.localPlayer
	self.replicatedStorage = options.replicatedStorage
	self.ui = options.ui
	self.widgets = options.widgets
	self.waitForChildTimeout = options.waitForChildTimeout
	self.themeColors = options.themeColors
	self.partyDisplayName = options.partyDisplayName

	self.partyRemotes = nil
	self.partyPanelManualOpen = false
	self.currentPartyExists = false
	self.isInPlayScreen = false
	self.bound = false
	return self
end

function InviteFriendsController:SetInPlayScreen(isInPlayScreen)
	self.isInPlayScreen = isInPlayScreen == true
	self:ApplyPartyPanelVisibility()
end

function InviteFriendsController:GetCurrentPartyExists()
	return self.currentPartyExists
end

function InviteFriendsController:SetPartyStatus(text, isError)
	self.ui.partyStatusLabel.Text = text
	self.ui.partyStatusLabel.TextColor3 = isError and self.themeColors.orangeLight or self.themeColors.offWhite
end

function InviteFriendsController:GetPartyRemotes()
	if self.partyRemotes then
		return self.partyRemotes
	end

	local remotesRoot = self.waitForChildTimeout(self.replicatedStorage, "Remotes", 10, "HomepageOverlay")
	self.partyRemotes = {
		getState = self.waitForChildTimeout(remotesRoot, "PartyGetState", 10, "HomepageOverlay"),
		invite = self.waitForChildTimeout(remotesRoot, "PartyInvite", 10, "HomepageOverlay"),
		respondInvite = self.waitForChildTimeout(remotesRoot, "PartyRespondInvite", 10, "HomepageOverlay"),
		leave = self.waitForChildTimeout(remotesRoot, "PartyLeave", 10, "HomepageOverlay"),
		updated = self.waitForChildTimeout(remotesRoot, "PartyUpdated", 10, "HomepageOverlay"),
		message = self.waitForChildTimeout(remotesRoot, "PartyMessage", 10, "HomepageOverlay"),
	}

	return self.partyRemotes
end

function InviteFriendsController:MakePartyRow(list, height)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -4, 0, height or 34)
	row.BackgroundColor3 = self.themeColors.charcoalLight
	row.BackgroundTransparency = 0.14
	row.BorderSizePixel = 0
	row.Parent = list
	self.widgets.styleSharpOutline(row, self.themeColors.black, 0)
	return row
end

function InviteFriendsController:ApplyPartyPanelVisibility()
	if self.isInPlayScreen then
		self.ui.partyPanel.Visible = false
		self.ui.closePartyButton.Visible = false
		return
	end

	if self.currentPartyExists then
		self.ui.partyPanel.Visible = true
		self.ui.closePartyButton.Visible = false
	else
		self.ui.partyPanel.Visible = self.partyPanelManualOpen
		self.ui.closePartyButton.Visible = self.partyPanelManualOpen
	end
end

function InviteFriendsController:RenderPartyState(state)
	self.widgets.clearListRows(self.ui.membersList)
	self.widgets.clearListRows(self.ui.invitesList)
	self.widgets.clearListRows(self.ui.friendsList)

	local partyData = state and state.party or nil
	local incomingInvites = (state and state.incomingInvites) or {}
	local friends = (state and state.friends) or {}
	local capacity = (partyData and partyData.capacity) or (state and state.partyCapacity) or 4
	local hadParty = self.currentPartyExists
	self.currentPartyExists = partyData ~= nil

	if self.currentPartyExists then
		local memberCount = #(partyData.members or {})
		self:SetPartyStatus(("Party %d/%d"):format(memberCount, capacity), false)
		self.ui.partyTabButton.Text = ("Party %d/%d"):format(memberCount, capacity)
		self.ui.leavePartyButton.Visible = true
		self.partyPanelManualOpen = true
	else
		self:SetPartyStatus("No party yet. Invite a friend to create one.", false)
		self.ui.partyTabButton.Text = "Invite friends"
		self.ui.leavePartyButton.Visible = false
		if hadParty then
			self.partyPanelManualOpen = false
		end
	end

	self:ApplyPartyPanelVisibility()

	local members = partyData and partyData.members or {}
	if #members == 0 then
		local emptyRow = self:MakePartyRow(self.ui.membersList, 32)
		self.widgets.makeTextLabel(
			emptyRow,
			"EmptyMembersLabel",
			"No party members.",
			UDim2.new(1, -12, 1, 0),
			UDim2.new(0, 8, 0, 0),
			Enum.Font.Gotham,
			14,
			self.themeColors.offWhite,
			Enum.TextXAlignment.Left
		)
	else
		for _, member in ipairs(members) do
			local row = self:MakePartyRow(self.ui.membersList, 34)
			local isLeader = partyData.leaderUserId == member.userId
			self.widgets.makeTextLabel(
				row,
				"MemberName",
				self.partyDisplayName(member) .. (isLeader and " (Leader)" or ""),
				UDim2.new(1, -12, 1, 0),
				UDim2.new(0, 8, 0, 0),
				Enum.Font.GothamSemibold,
				14,
				self.themeColors.white,
				Enum.TextXAlignment.Left
			)
		end
	end

	if #incomingInvites == 0 then
		local emptyRow = self:MakePartyRow(self.ui.invitesList, 32)
		self.widgets.makeTextLabel(
			emptyRow,
			"EmptyInvitesLabel",
			"No incoming invites.",
			UDim2.new(1, -12, 1, 0),
			UDim2.new(0, 8, 0, 0),
			Enum.Font.Gotham,
			14,
			self.themeColors.offWhite,
			Enum.TextXAlignment.Left
		)
	else
		local remotes = self:GetPartyRemotes()
		for _, invite in ipairs(incomingInvites) do
			local row = self:MakePartyRow(self.ui.invitesList, 42)

			self.widgets.makeTextLabel(
				row,
				"InviteFrom",
				self.partyDisplayName(invite),
				UDim2.new(1, -170, 0, 20),
				UDim2.new(0, 8, 0, 2),
				Enum.Font.GothamSemibold,
				13,
				self.themeColors.white,
				Enum.TextXAlignment.Left
			)

			self.widgets.makeTextLabel(
				row,
				"InviteMeta",
				("Party %d/%d"):format(invite.partySize or 1, invite.partyCapacity or capacity),
				UDim2.new(1, -170, 0, 16),
				UDim2.new(0, 8, 0, 22),
				Enum.Font.Gotham,
				12,
				self.themeColors.orangeLight,
				Enum.TextXAlignment.Left
			)

			local acceptButton = self.widgets.createActionButton(
				row,
				"AcceptInvite",
				"ACCEPT",
				UDim2.new(0, 72, 0, 28),
				UDim2.new(1, -156, 0, 7),
				self.themeColors.orange,
				self.themeColors.black
			)
			acceptButton.TextSize = 14
			acceptButton.MouseButton1Click:Connect(function()
				remotes.respondInvite:FireServer(invite.fromUserId, true)
			end)

			local declineButton = self.widgets.createActionButton(
				row,
				"DeclineInvite",
				"DECLINE",
				UDim2.new(0, 72, 0, 28),
				UDim2.new(1, -78, 0, 7),
				self.themeColors.charcoalLight,
				self.themeColors.black
			)
			declineButton.TextSize = 14
			declineButton.MouseButton1Click:Connect(function()
				remotes.respondInvite:FireServer(invite.fromUserId, false)
			end)
		end
	end

	if #friends == 0 then
		local emptyRow = self:MakePartyRow(self.ui.friendsList, 32)
		self.widgets.makeTextLabel(
			emptyRow,
			"EmptyFriendsLabel",
			"No online friends in this server.",
			UDim2.new(1, -12, 1, 0),
			UDim2.new(0, 8, 0, 0),
			Enum.Font.Gotham,
			14,
			self.themeColors.offWhite,
			Enum.TextXAlignment.Left
		)
	else
		local remotes = self:GetPartyRemotes()
		for _, friend in ipairs(friends) do
			local row = self:MakePartyRow(self.ui.friendsList, 42)

			self.widgets.makeTextLabel(
				row,
				"FriendName",
				self.partyDisplayName(friend),
				UDim2.new(1, -140, 0, 20),
				UDim2.new(0, 8, 0, 2),
				Enum.Font.GothamSemibold,
				13,
				self.themeColors.white,
				Enum.TextXAlignment.Left
			)

			local reasonText = friend.reason or "Ready to invite"
			self.widgets.makeTextLabel(
				row,
				"FriendReason",
				reasonText,
				UDim2.new(1, -140, 0, 16),
				UDim2.new(0, 8, 0, 22),
				Enum.Font.Gotham,
				12,
				friend.canInvite and self.themeColors.orangeLight or self.themeColors.offWhite,
				Enum.TextXAlignment.Left
			)

			local inviteButton = self.widgets.createActionButton(
				row,
				"InviteFriend",
				friend.canInvite and "INVITE" or "LOCKED",
				UDim2.new(0, 110, 0, 28),
				UDim2.new(1, -118, 0, 7),
				friend.canInvite and self.themeColors.orange or self.themeColors.charcoalLight,
				self.themeColors.black
			)
			inviteButton.TextSize = 14
			inviteButton.Active = friend.canInvite
			inviteButton.AutoButtonColor = false
			if not friend.canInvite then
				inviteButton.BackgroundTransparency = 0.25
			end

			inviteButton.MouseButton1Click:Connect(function()
				if not friend.canInvite then
					return
				end
				remotes.invite:FireServer(friend.userId)
			end)
		end
	end
end

function InviteFriendsController:RequestPartyState()
	local remotes = self:GetPartyRemotes()
	local ok, state = pcall(function()
		return remotes.getState:InvokeServer()
	end)
	if not ok or type(state) ~= "table" then
		self:SetPartyStatus("Failed to load party state.", true)
		return
	end
	self:RenderPartyState(state)
end

function InviteFriendsController:Bind()
	if self.bound then
		return
	end
	local remotes = self:GetPartyRemotes()

	remotes.updated.OnClientEvent:Connect(function(state)
		if type(state) == "table" then
			self:RenderPartyState(state)
		end
	end)

	remotes.message.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			self:SetPartyStatus(tostring(payload.text or ""), payload.isError == true)
		elseif payload ~= nil then
			self:SetPartyStatus(tostring(payload), false)
		end
	end)

	self.ui.partyTabButton.MouseButton1Click:Connect(function()
		if self.isInPlayScreen then
			return
		end

		if self.currentPartyExists then
			self:ApplyPartyPanelVisibility()
			self:RequestPartyState()
			return
		end

		self.partyPanelManualOpen = not self.partyPanelManualOpen
		self:ApplyPartyPanelVisibility()
		if self.partyPanelManualOpen then
			self:RequestPartyState()
		end
	end)

	self.ui.closePartyButton.MouseButton1Click:Connect(function()
		if self.currentPartyExists then
			return
		end
		self.partyPanelManualOpen = false
		self:ApplyPartyPanelVisibility()
	end)

	self.ui.refreshPartyButton.MouseButton1Click:Connect(function()
		self:RequestPartyState()
	end)

	self.ui.leavePartyButton.MouseButton1Click:Connect(function()
		remotes.leave:FireServer()
	end)
	self.bound = true
end

return InviteFriendsController
