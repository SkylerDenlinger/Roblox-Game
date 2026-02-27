local PlayMainMenuSection = require(script.Parent.Parent:WaitForChild("MainMenu"):WaitForChild("Play"):WaitForChild("Section"))
local ReplaysMainMenuSection = require(script.Parent.Parent:WaitForChild("MainMenu"):WaitForChild("Replays"):WaitForChild("Section"))
local TrainMainMenuSection = require(script.Parent.Parent:WaitForChild("MainMenu"):WaitForChild("Train"):WaitForChild("Section"))
local TutorialsMainMenuSection = require(script.Parent.Parent:WaitForChild("MainMenu"):WaitForChild("Tutorials"):WaitForChild("Section"))

local OverlayBuilder = {}

function OverlayBuilder.GetOrCreateGui(localPlayer, guiName, waitForChildTimeout)
	local playerGui = waitForChildTimeout(localPlayer, "PlayerGui", 5, "HomepageOverlay")
	local existing = playerGui:FindFirstChild(guiName)
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = guiName
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end

function OverlayBuilder.Build(gui, widgets, themeColors, constants)
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui

	local tint = Instance.new("Frame")
	tint.Name = "Tint"
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = themeColors.black
	tint.BackgroundTransparency = 0.5
	tint.BorderSizePixel = 0
	tint.Parent = root

	local tintGradient = Instance.new("UIGradient")
	tintGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 8, 8)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(12, 12, 12)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 14, 0)),
	})
	tintGradient.Rotation = 18
	tintGradient.Parent = tint

	local titleCard = Instance.new("Frame")
	titleCard.Name = "TitleCard"
	titleCard.Position = UDim2.new(0.05, 0, 0.07, 0)
	titleCard.Size = UDim2.new(0.54, 0, 0, 178)
	titleCard.BackgroundColor3 = themeColors.charcoal
	titleCard.BackgroundTransparency = 0.18
	titleCard.BorderSizePixel = 0
	titleCard.Parent = root
	widgets.styleSharpOutline(titleCard, themeColors.black, 0)

	local titleCardInner = Instance.new("Frame")
	titleCardInner.Name = "InnerBorder"
	titleCardInner.Size = UDim2.new(1, -10, 1, -10)
	titleCardInner.Position = UDim2.new(0, 5, 0, 5)
	titleCardInner.BackgroundTransparency = 1
	titleCardInner.BorderSizePixel = 0
	titleCardInner.Parent = titleCard

	local titleCardInnerStroke = Instance.new("UIStroke")
	titleCardInnerStroke.Color = themeColors.white
	titleCardInnerStroke.Thickness = 1
	titleCardInnerStroke.Transparency = 0.5
	titleCardInnerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleCardInnerStroke.Parent = titleCardInner

	local titleCardAccent = Instance.new("Frame")
	titleCardAccent.Name = "Accent"
	titleCardAccent.Size = UDim2.new(0, 8, 1, 0)
	titleCardAccent.BackgroundColor3 = themeColors.orange
	titleCardAccent.BorderSizePixel = 0
	titleCardAccent.Parent = titleCard

	local titleCardGradient = Instance.new("UIGradient")
	titleCardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, themeColors.orangeLight),
		ColorSequenceKeypoint.new(1, themeColors.orangeDark),
	})
	titleCardGradient.Rotation = 90
	titleCardGradient.Parent = titleCardAccent

	local gameTitleLabel = widgets.makeTextLabel(
		titleCard,
		"GameTitle",
		"OVERCLOCK",
		UDim2.new(1, -32, 0, 110),
		UDim2.new(0, 20, 0, 18),
		Enum.Font.GothamBlack,
		80,
		themeColors.white,
		Enum.TextXAlignment.Left
	)
	gameTitleLabel.TextStrokeColor3 = themeColors.black
	gameTitleLabel.TextStrokeTransparency = 0.05

	local gameTitleSizeConstraint = Instance.new("UITextSizeConstraint")
	gameTitleSizeConstraint.MinTextSize = 38
	gameTitleSizeConstraint.MaxTextSize = 84
	gameTitleSizeConstraint.Parent = gameTitleLabel

	local titleSubLabel = widgets.makeTextLabel(
		titleCard,
		"GameSubtitle",
		"SPEEDRUN COLLECTATHON",
		UDim2.new(1, -32, 0, 26),
		UDim2.new(0, 22, 1, -34),
		Enum.Font.GothamBold,
		18,
		themeColors.orangeLight,
		Enum.TextXAlignment.Left
	)
	titleSubLabel.TextStrokeColor3 = themeColors.black
	titleSubLabel.TextStrokeTransparency = 0.2

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.AnchorPoint = Vector2.new(1, 0.5)
	menu.Position = UDim2.new(0.96, 0, 0.5, 0)
	menu.Size = UDim2.new(0.3, 0, 0.66, 0)
	menu.BackgroundTransparency = 1
	menu.Parent = root

	local title = widgets.makeTextLabel(
		menu,
		"Title",
		"MODE SELECT",
		UDim2.new(1, 0, 0, 36),
		UDim2.new(0, 0, 0, 0),
		Enum.Font.GothamBlack,
		26,
		themeColors.offWhite,
		Enum.TextXAlignment.Left
	)
	title.TextStrokeColor3 = themeColors.black
	title.TextStrokeTransparency = 0.15

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.new(0, 0, 0, 46)
	tabs.Size = UDim2.new(1, 0, 1, -46)
	tabs.BackgroundTransparency = 1
	tabs.Parent = menu

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 12)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.Parent = tabs

	local playButton = PlayMainMenuSection.CreateTabButton(widgets, tabs)
	local trainButton = TrainMainMenuSection.CreateTabButton(widgets, tabs)
	local replayButton = ReplaysMainMenuSection.CreateTabButton(widgets, tabs)
	local tutorialsButton = TutorialsMainMenuSection.CreateTabButton(widgets, tabs)

	local partyTabButton = widgets.createActionButton(
		root,
		"PartyTabButton",
		"Invite friends",
		UDim2.new(0.34, 0, 0, 52),
		UDim2.new(0.5, 0, 1, -12),
		themeColors.orange,
		themeColors.black
	)
	partyTabButton.AnchorPoint = Vector2.new(0.5, 1)
	partyTabButton.TextSize = 26

	local partyPanel = Instance.new("Frame")
	partyPanel.Name = "PartyPanel"
	partyPanel.AnchorPoint = Vector2.new(0.5, 1)
	partyPanel.Position = UDim2.new(0.5, 0, 1, -76)
	partyPanel.Size = UDim2.new(0.9, 0, 0.38, 0)
	partyPanel.BackgroundColor3 = themeColors.charcoal
	partyPanel.BackgroundTransparency = 0.1
	partyPanel.BorderSizePixel = 0
	partyPanel.Visible = false
	partyPanel.Parent = root
	widgets.styleSharpOutline(partyPanel, themeColors.black, 0)

	widgets.makeTextLabel(
		partyPanel,
		"PartyTitle",
		"PARTY",
		UDim2.new(0, 200, 0, 36),
		UDim2.new(0, 12, 0, 8),
		Enum.Font.GothamBlack,
		32,
		themeColors.white,
		Enum.TextXAlignment.Left
	).TextStrokeTransparency = 0

	local closePartyButton = widgets.createActionButton(
		partyPanel,
		"ClosePartyButton",
		"X",
		UDim2.new(0, 42, 0, 32),
		UDim2.new(1, -54, 0, 8),
		themeColors.charcoalLight,
		themeColors.black
	)
	closePartyButton.Font = Enum.Font.GothamBlack
	closePartyButton.TextSize = 20

	local partyStatusLabel = widgets.makeTextLabel(
		partyPanel,
		"PartyStatus",
		"Invite friends to form a party.",
		UDim2.new(1, -280, 0, 24),
		UDim2.new(0, 220, 0, 14),
		Enum.Font.Gotham,
		16,
		themeColors.offWhite,
		Enum.TextXAlignment.Left
	)

	local leavePartyButton = widgets.createActionButton(
		partyPanel,
		"LeavePartyButton",
		"LEAVE",
		UDim2.new(0, 118, 0, 30),
		UDim2.new(1, -130, 0, 44),
		themeColors.charcoalLight,
		themeColors.black
	)
	leavePartyButton.TextSize = 18
	leavePartyButton.Visible = false

	local refreshPartyButton = widgets.createActionButton(
		partyPanel,
		"RefreshPartyButton",
		"REFRESH",
		UDim2.new(0, 118, 0, 30),
		UDim2.new(1, -254, 0, 44),
		themeColors.orange,
		themeColors.black
	)
	refreshPartyButton.TextSize = 18

	widgets.makeTextLabel(
		partyPanel,
		"MembersTitle",
		"Party Members",
		UDim2.new(0.27, -8, 0, 22),
		UDim2.new(0.02, 0, 0, 80),
		Enum.Font.GothamSemibold,
		18,
		themeColors.offWhite,
		Enum.TextXAlignment.Left
	)
	local membersList = widgets.makeList(partyPanel, "MembersList", UDim2.new(0.27, -8, 1, -112), UDim2.new(0.02, 0, 0, 104))

	widgets.makeTextLabel(
		partyPanel,
		"InvitesTitle",
		"Incoming Invites",
		UDim2.new(0.29, -8, 0, 22),
		UDim2.new(0.31, 0, 0, 80),
		Enum.Font.GothamSemibold,
		18,
		themeColors.offWhite,
		Enum.TextXAlignment.Left
	)
	local invitesList = widgets.makeList(partyPanel, "InvitesList", UDim2.new(0.29, -8, 1, -112), UDim2.new(0.31, 0, 0, 104))

	widgets.makeTextLabel(
		partyPanel,
		"FriendsTitle",
		"Online Friends",
		UDim2.new(0.36, -8, 0, 22),
		UDim2.new(0.62, 0, 0, 80),
		Enum.Font.GothamSemibold,
		18,
		themeColors.offWhite,
		Enum.TextXAlignment.Left
	)
	local friendsList = widgets.makeList(partyPanel, "FriendsList", UDim2.new(0.36, -8, 1, -112), UDim2.new(0.62, 0, 0, 104))

	local playScreen = Instance.new("Frame")
	playScreen.Name = "PlayScreen"
	playScreen.Size = UDim2.fromScale(1, 1)
	playScreen.BackgroundTransparency = 1
	playScreen.Visible = false
	playScreen.Parent = root

	widgets.makeTextLabel(
		playScreen,
		"PlayTitle",
		"PLAY",
		UDim2.new(0, 180, 0, 42),
		UDim2.new(0.5, -90, 0, 22),
		Enum.Font.GothamBlack,
		38,
		themeColors.white,
		Enum.TextXAlignment.Center
	).TextStrokeTransparency = 0

	local playQueueStatusLabel = widgets.makeTextLabel(
		playScreen,
		"PlayQueueStatus",
		"Finding match...",
		UDim2.new(1, 0, 0, 28),
		UDim2.new(0, 0, 0, 74),
		Enum.Font.GothamBold,
		24,
		themeColors.white,
		Enum.TextXAlignment.Center
	)
	playQueueStatusLabel.TextStrokeColor3 = themeColors.black
	playQueueStatusLabel.TextStrokeTransparency = 0.25
	playQueueStatusLabel.Visible = false

	local playMainMenuButton = widgets.createActionButton(
		playScreen,
		"PlayMainMenuButton",
		"MAIN MENU",
		UDim2.new(0, 190, 0, 46),
		UDim2.new(0, 24, 0, 24),
		themeColors.charcoalLight,
		themeColors.black
	)
	playMainMenuButton.TextSize = 24

	local playSearchButton = widgets.createActionButton(
		playScreen,
		"PlaySearchButton",
		"SEARCH ONLINE MATCH",
		UDim2.new(0, 320, 0, 64),
		UDim2.new(1, -344, 0.5, -32),
		themeColors.orange,
		themeColors.black
	)
	playSearchButton.TextSize = 26

	local playCancelButton = widgets.createActionButton(
		playScreen,
		"PlayCancelButton",
		"CANCEL",
		UDim2.new(0, 220, 0, 64),
		UDim2.new(0, 24, 0.5, -32),
		themeColors.charcoalLight,
		themeColors.black
	)
	playCancelButton.TextSize = 26
	playCancelButton.Visible = false

	local lobbyRosterPanel = Instance.new("Frame")
	lobbyRosterPanel.Name = "LobbyRosterPanel"
	lobbyRosterPanel.AnchorPoint = Vector2.new(1, 0.5)
	lobbyRosterPanel.Position = UDim2.new(1, -24, 0.5, 0)
	lobbyRosterPanel.Size = UDim2.new(0, 360, 0, 324)
	lobbyRosterPanel.BackgroundColor3 = themeColors.charcoal
	lobbyRosterPanel.BackgroundTransparency = 0.08
	lobbyRosterPanel.BorderSizePixel = 0
	lobbyRosterPanel.Visible = false
	lobbyRosterPanel.Parent = playScreen
	widgets.styleSharpOutline(lobbyRosterPanel, themeColors.black, 0)

	local lobbyRosterHeader = widgets.makeTextLabel(
		lobbyRosterPanel,
		"RosterHeader",
		"MATCH LOBBY",
		UDim2.new(1, -22, 0, 34),
		UDim2.new(0, 12, 0, 10),
		Enum.Font.GothamBlack,
		24,
		themeColors.white,
		Enum.TextXAlignment.Left
	)
	lobbyRosterHeader.TextStrokeColor3 = themeColors.black
	lobbyRosterHeader.TextStrokeTransparency = 0.05

	local lobbyRosterStatusLabel = widgets.makeTextLabel(
		lobbyRosterPanel,
		"RosterStatus",
		"Waiting for players",
		UDim2.new(1, -22, 0, 22),
		UDim2.new(0, 12, 0, 42),
		Enum.Font.GothamSemibold,
		16,
		themeColors.orangeLight,
		Enum.TextXAlignment.Left
	)
	lobbyRosterStatusLabel.TextStrokeColor3 = themeColors.black
	lobbyRosterStatusLabel.TextStrokeTransparency = 0.2

	local lobbyRosterCountLabel = widgets.makeTextLabel(
		lobbyRosterPanel,
		"RosterCount",
		("1/%d"):format(constants.LOBBY_PLAYER_TARGET),
		UDim2.new(0, 80, 0, 28),
		UDim2.new(1, -92, 0, 12),
		Enum.Font.GothamBlack,
		22,
		themeColors.orange,
		Enum.TextXAlignment.Right
	)
	lobbyRosterCountLabel.TextStrokeColor3 = themeColors.black
	lobbyRosterCountLabel.TextStrokeTransparency = 0.05

	local rosterSlots = Instance.new("Frame")
	rosterSlots.Name = "RosterSlots"
	rosterSlots.Size = UDim2.new(1, -24, 1, -78)
	rosterSlots.Position = UDim2.new(0, 12, 0, 64)
	rosterSlots.BackgroundTransparency = 1
	rosterSlots.Parent = lobbyRosterPanel

	local rosterLayout = Instance.new("UIListLayout")
	rosterLayout.Padding = UDim.new(0, 8)
	rosterLayout.FillDirection = Enum.FillDirection.Vertical
	rosterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rosterLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	rosterLayout.Parent = rosterSlots

	local lobbySlotRows = {}
	local lobbySlotLabels = {}
	for i = 1, constants.LOBBY_PLAYER_TARGET do
		local row = Instance.new("Frame")
		row.Name = ("Slot%d"):format(i)
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = themeColors.charcoalLight
		row.BackgroundTransparency = 0.12
		row.BorderSizePixel = 0
		row.Parent = rosterSlots
		widgets.styleSharpOutline(row, themeColors.black, 0)
		lobbySlotRows[i] = row

		local indexLabel = widgets.makeTextLabel(
			row,
			"Index",
			tostring(i),
			UDim2.new(0, 28, 1, 0),
			UDim2.new(0, 8, 0, 0),
			Enum.Font.GothamBlack,
			16,
			themeColors.orange,
			Enum.TextXAlignment.Center
		)
		indexLabel.TextStrokeColor3 = themeColors.black
		indexLabel.TextStrokeTransparency = 0.1

		local nameLabel = widgets.makeTextLabel(
			row,
			"PlayerName",
			"Waiting for player...",
			UDim2.new(1, -48, 1, 0),
			UDim2.new(0, 40, 0, 0),
			Enum.Font.GothamSemibold,
			15,
			themeColors.offWhite,
			Enum.TextXAlignment.Left
		)
		nameLabel.TextStrokeColor3 = themeColors.black
		nameLabel.TextStrokeTransparency = 0.3
		lobbySlotLabels[i] = nameLabel
	end

	return {
		root = root,
		menu = menu,
		playButton = playButton,
		trainButton = trainButton,
		replayButton = replayButton,
		tutorialsButton = tutorialsButton,
		partyTabButton = partyTabButton,
		partyPanel = partyPanel,
		closePartyButton = closePartyButton,
		partyStatusLabel = partyStatusLabel,
		leavePartyButton = leavePartyButton,
		refreshPartyButton = refreshPartyButton,
		membersList = membersList,
		invitesList = invitesList,
		friendsList = friendsList,
		playScreen = playScreen,
		playMainMenuButton = playMainMenuButton,
		playSearchButton = playSearchButton,
		playCancelButton = playCancelButton,
		playQueueStatusLabel = playQueueStatusLabel,
		lobbyRosterPanel = lobbyRosterPanel,
		lobbyRosterStatusLabel = lobbyRosterStatusLabel,
		lobbyRosterCountLabel = lobbyRosterCountLabel,
		lobbySlotRows = lobbySlotRows,
		lobbySlotLabels = lobbySlotLabels,
	}
end

return OverlayBuilder
