local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local GUI_NAME = "HomepageOverlay"

local CHARACTER_POSITION = Vector3.new(-150, 58, 218)
local CAMERA_POSITION = Vector3.new(-145, 61, 210)
local CAMERA_FOCUS_HEIGHT = 1.35
local CAMERA_FOV = 60
local CAMERA_RIGHT_YAW_DEGREES = 30
local PLAYER_RIGHT_YAW_DEGREES = -30

local CAMERA_SWAY_YAW_DEGREES = 1.2
local CAMERA_SWAY_PITCH_DEGREES = 0.3
local CAMERA_SWAY_YAW_HZ = 0.045
local CAMERA_SWAY_PITCH_HZ = 0.031
local CAMERA_FOV_BREATHE_DELTA = 0.7
local CAMERA_FOV_BREATHE_HZ = 0.035
local CAMERA_MOTION_BLEND_SPEED = 4.0
local CAMERA_FOCUS_DISTANCE = 64
local LOBBY_PLAYER_TARGET = 6

local cameraLockConn = nil
local lockedCameraCFrame = nil
local lockedCameraFocus = nil
local controls = nil

local ui = nil
local partyRemotes = nil
local lobbyRemotes = nil
local partyPanelManualOpen = false
local currentPartyExists = false
local isInPlayScreen = false
local isSearchingForMatch = false
local playStatusText = nil
local playStatusIsError = false
local currentLobbyContext = "none"
local lobbyPreviewMembers = {}

local homeCameraMotionEnabled = true
local cameraMotionBlend = 1
local cameraMotionTarget = 1
local lastCameraMotionTick = os.clock()

local THEME = {
	orange = Color3.fromRGB(255, 136, 24),
	orangeLight = Color3.fromRGB(255, 184, 90),
	orangeDark = Color3.fromRGB(216, 86, 0),
	charcoal = Color3.fromRGB(20, 20, 20),
	charcoalLight = Color3.fromRGB(38, 38, 38),
	white = Color3.fromRGB(255, 255, 255),
	offWhite = Color3.fromRGB(236, 242, 250),
	black = Color3.fromRGB(0, 0, 0),
}

local TAB_THEME_BY_NAME = {
	PLAY = {
		base = Color3.fromRGB(255, 146, 36),
		light = Color3.fromRGB(255, 190, 102),
		dark = Color3.fromRGB(222, 90, 0),
	},
	TRAIN = {
		base = Color3.fromRGB(255, 132, 14),
		light = Color3.fromRGB(255, 176, 84),
		dark = Color3.fromRGB(210, 80, 0),
	},
	REPLAY = {
		base = Color3.fromRGB(244, 248, 255),
		light = Color3.fromRGB(255, 255, 255),
		dark = Color3.fromRGB(255, 206, 143),
		text = THEME.black,
		stroke = THEME.orangeDark,
		accent = THEME.orange,
	},
	TUTORIALS = {
		base = Color3.fromRGB(244, 248, 255),
		light = Color3.fromRGB(255, 255, 255),
		dark = Color3.fromRGB(255, 206, 143),
		text = THEME.black,
		stroke = THEME.orangeDark,
		accent = THEME.orange,
	},
	PARTY = {
		base = Color3.fromRGB(247, 136, 20),
		light = Color3.fromRGB(255, 182, 88),
		dark = Color3.fromRGB(202, 84, 0),
	},
}

local function waitForChildTimeout(parent, name, timeoutSeconds)
	local t0 = os.clock()
	local child = parent:FindFirstChild(name)
	while not child do
		if os.clock() - t0 >= timeoutSeconds then
			error(("HomepageOverlay timed out waiting for '%s' under %s"):format(name, parent:GetFullName()))
		end
		child = parent:FindFirstChild(name)
		task.wait(0.05)
	end
	return child
end

local function styleSharpOutline(frame, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

local function addButtonChrome(button, topColor, bottomColor)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(0.55, Color3.new(
			math.clamp((topColor.R + bottomColor.R) * 0.5, 0, 1),
			math.clamp((topColor.G + bottomColor.G) * 0.5, 0, 1),
			math.clamp((topColor.B + bottomColor.B) * 0.5, 0, 1)
		)),
		ColorSequenceKeypoint.new(1, bottomColor),
	})
	gradient.Rotation = 90
	gradient.Parent = button

	local topEdge = Instance.new("Frame")
	topEdge.Name = "TopEdge"
	topEdge.Size = UDim2.new(1, -6, 0, 1)
	topEdge.Position = UDim2.new(0, 3, 0, 2)
	topEdge.BackgroundColor3 = THEME.white
	topEdge.BackgroundTransparency = 0.45
	topEdge.BorderSizePixel = 0
	topEdge.ZIndex = button.ZIndex + 1
	topEdge.Parent = button

	local innerBorder = Instance.new("Frame")
	innerBorder.Name = "InnerBorder"
	innerBorder.Size = UDim2.new(1, -6, 1, -6)
	innerBorder.Position = UDim2.new(0, 3, 0, 3)
	innerBorder.BackgroundTransparency = 1
	innerBorder.BorderSizePixel = 0
	innerBorder.ZIndex = button.ZIndex + 1
	innerBorder.Parent = button

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = THEME.white
	innerStroke.Thickness = 1
	innerStroke.Transparency = 0.62
	innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerStroke.Parent = innerBorder
end

local function makeTextLabel(parent, name, text, size, position, font, textSize, color, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeList(parent, name, size, position)
	local list = Instance.new("ScrollingFrame")
	list.Name = name
	list.Size = size
	list.Position = position
	list.BackgroundColor3 = THEME.charcoal
	list.BackgroundTransparency = 0.18
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = parent
	styleSharpOutline(list, THEME.black, 0)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = list

	return list
end

local function clearListRows(list)
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function createActionButton(parent, name, text, size, position, bgColor, outlineColor)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = bgColor
	button.BackgroundTransparency = 0.04
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 21
	button.TextColor3 = THEME.white
	button.TextStrokeColor3 = THEME.black
	button.TextStrokeTransparency = 0
	button.Parent = parent
	styleSharpOutline(button, outlineColor or THEME.black, 0)
	addButtonChrome(
		button,
		Color3.new(
			math.clamp(bgColor.R + 0.15, 0, 1),
			math.clamp(bgColor.G + 0.15, 0, 1),
			math.clamp(bgColor.B + 0.15, 0, 1)
		),
		Color3.new(
			math.clamp(bgColor.R - 0.1, 0, 1),
			math.clamp(bgColor.G - 0.1, 0, 1),
			math.clamp(bgColor.B - 0.1, 0, 1)
		)
	)

	button.MouseEnter:Connect(function()
		button.BackgroundTransparency = 0
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = 0.04
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundTransparency = 0
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundTransparency = 0
	end)

	return button
end

local function createTabButton(parent, text)
	local theme = TAB_THEME_BY_NAME[text]
	local isHeroStyle = theme ~= nil
	local baseTheme = theme or TAB_THEME_BY_NAME.PLAY

	local button = Instance.new("TextButton")
	button.Name = text .. "Tab"
	button.Size = UDim2.new(1, 0, 0, 62)
	button.BackgroundColor3 = isHeroStyle and baseTheme.base or THEME.charcoal
	button.BackgroundTransparency = isHeroStyle and 0.04 or 0.18
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = baseTheme.text or THEME.white
	button.TextSize = isHeroStyle and 28 or 24
	button.TextStrokeColor3 = baseTheme.stroke or THEME.black
	button.TextStrokeTransparency = 0
	button.Parent = parent

	styleSharpOutline(button, THEME.black, 0)
	addButtonChrome(button, baseTheme.light, baseTheme.dark)

	if baseTheme.accent then
		local accentBar = Instance.new("Frame")
		accentBar.Name = "AccentBar"
		accentBar.Size = UDim2.new(0, 8, 1, -8)
		accentBar.Position = UDim2.new(1, -12, 0, 4)
		accentBar.BackgroundColor3 = baseTheme.accent
		accentBar.BorderSizePixel = 0
		accentBar.ZIndex = button.ZIndex + 1
		accentBar.Parent = button
	end

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MinTextSize = 15
	sizeConstraint.MaxTextSize = 28
	sizeConstraint.Parent = button

	local hoverTransparency = 0
	local idleTransparency = isHeroStyle and 0.04 or 0.18
	local downTransparency = 0

	button.MouseEnter:Connect(function()
		button.BackgroundTransparency = hoverTransparency
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = idleTransparency
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundTransparency = downTransparency
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundTransparency = hoverTransparency
	end)
	button.MouseButton1Click:Connect(function()
		print(("HomepageOverlay: %s clicked"):format(text))
	end)

	return button
end

local function getOrCreateGui()
	local playerGui = waitForChildTimeout(localPlayer, "PlayerGui", 5)
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end

local function buildOverlay(gui)
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui

	local tint = Instance.new("Frame")
	tint.Name = "Tint"
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = THEME.black
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
	titleCard.BackgroundColor3 = THEME.charcoal
	titleCard.BackgroundTransparency = 0.18
	titleCard.BorderSizePixel = 0
	titleCard.Parent = root
	styleSharpOutline(titleCard, THEME.black, 0)

	local titleCardInner = Instance.new("Frame")
	titleCardInner.Name = "InnerBorder"
	titleCardInner.Size = UDim2.new(1, -10, 1, -10)
	titleCardInner.Position = UDim2.new(0, 5, 0, 5)
	titleCardInner.BackgroundTransparency = 1
	titleCardInner.BorderSizePixel = 0
	titleCardInner.Parent = titleCard

	local titleCardInnerStroke = Instance.new("UIStroke")
	titleCardInnerStroke.Color = THEME.white
	titleCardInnerStroke.Thickness = 1
	titleCardInnerStroke.Transparency = 0.5
	titleCardInnerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleCardInnerStroke.Parent = titleCardInner

	local titleCardAccent = Instance.new("Frame")
	titleCardAccent.Name = "Accent"
	titleCardAccent.Size = UDim2.new(0, 8, 1, 0)
	titleCardAccent.BackgroundColor3 = THEME.orange
	titleCardAccent.BorderSizePixel = 0
	titleCardAccent.Parent = titleCard

	local titleCardGradient = Instance.new("UIGradient")
	titleCardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.orangeLight),
		ColorSequenceKeypoint.new(1, THEME.orangeDark),
	})
	titleCardGradient.Rotation = 90
	titleCardGradient.Parent = titleCardAccent

	local gameTitleLabel = makeTextLabel(
		titleCard,
		"GameTitle",
		"OVERCLOCK",
		UDim2.new(1, -32, 0, 110),
		UDim2.new(0, 20, 0, 18),
		Enum.Font.GothamBlack,
		80,
		THEME.white,
		Enum.TextXAlignment.Left
	)
	gameTitleLabel.TextStrokeColor3 = THEME.black
	gameTitleLabel.TextStrokeTransparency = 0.05

	local gameTitleSizeConstraint = Instance.new("UITextSizeConstraint")
	gameTitleSizeConstraint.MinTextSize = 38
	gameTitleSizeConstraint.MaxTextSize = 84
	gameTitleSizeConstraint.Parent = gameTitleLabel

	local titleSubLabel = makeTextLabel(
		titleCard,
		"GameSubtitle",
		"SPEEDRUN COLLECTATHON",
		UDim2.new(1, -32, 0, 26),
		UDim2.new(0, 22, 1, -34),
		Enum.Font.GothamBold,
		18,
		THEME.orangeLight,
		Enum.TextXAlignment.Left
	)
	titleSubLabel.TextStrokeColor3 = THEME.black
	titleSubLabel.TextStrokeTransparency = 0.2

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.AnchorPoint = Vector2.new(1, 0.5)
	menu.Position = UDim2.new(0.96, 0, 0.5, 0)
	menu.Size = UDim2.new(0.3, 0, 0.66, 0)
	menu.BackgroundTransparency = 1
	menu.Parent = root

	local title = makeTextLabel(
		menu,
		"Title",
		"MODE SELECT",
		UDim2.new(1, 0, 0, 36),
		UDim2.new(0, 0, 0, 0),
		Enum.Font.GothamBlack,
		26,
		THEME.offWhite,
		Enum.TextXAlignment.Left
	)
	title.TextStrokeColor3 = THEME.black
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

	local playButton = createTabButton(tabs, "PLAY")
	local trainButton = createTabButton(tabs, "TRAIN")
	local replayButton = createTabButton(tabs, "REPLAY")
	local tutorialsButton = createTabButton(tabs, "TUTORIALS")

	local partyTabButton = createActionButton(
		root,
		"PartyTabButton",
		"Invite friends",
		UDim2.new(0.34, 0, 0, 52),
		UDim2.new(0.5, 0, 1, -12),
		THEME.orange,
		THEME.black
	)
	partyTabButton.AnchorPoint = Vector2.new(0.5, 1)
	partyTabButton.TextSize = 26

	local partyPanel = Instance.new("Frame")
	partyPanel.Name = "PartyPanel"
	partyPanel.AnchorPoint = Vector2.new(0.5, 1)
	partyPanel.Position = UDim2.new(0.5, 0, 1, -76)
	partyPanel.Size = UDim2.new(0.9, 0, 0.38, 0)
	partyPanel.BackgroundColor3 = THEME.charcoal
	partyPanel.BackgroundTransparency = 0.1
	partyPanel.BorderSizePixel = 0
	partyPanel.Visible = false
	partyPanel.Parent = root
	styleSharpOutline(partyPanel, THEME.black, 0)

	makeTextLabel(
		partyPanel,
		"PartyTitle",
		"PARTY",
		UDim2.new(0, 200, 0, 36),
		UDim2.new(0, 12, 0, 8),
		Enum.Font.GothamBlack,
		32,
		THEME.white,
		Enum.TextXAlignment.Left
	).TextStrokeTransparency = 0

	local closePartyButton = createActionButton(
		partyPanel,
		"ClosePartyButton",
		"X",
		UDim2.new(0, 42, 0, 32),
		UDim2.new(1, -54, 0, 8),
		THEME.charcoalLight,
		THEME.black
	)
	closePartyButton.Font = Enum.Font.GothamBlack
	closePartyButton.TextSize = 20

	local partyStatusLabel = makeTextLabel(
		partyPanel,
		"PartyStatus",
		"Invite friends to form a party.",
		UDim2.new(1, -280, 0, 24),
		UDim2.new(0, 220, 0, 14),
		Enum.Font.Gotham,
		16,
		THEME.offWhite,
		Enum.TextXAlignment.Left
	)

	local leavePartyButton = createActionButton(
		partyPanel,
		"LeavePartyButton",
		"LEAVE",
		UDim2.new(0, 118, 0, 30),
		UDim2.new(1, -130, 0, 44),
		THEME.charcoalLight,
		THEME.black
	)
	leavePartyButton.TextSize = 18
	leavePartyButton.Visible = false

	local refreshPartyButton = createActionButton(
		partyPanel,
		"RefreshPartyButton",
		"REFRESH",
		UDim2.new(0, 118, 0, 30),
		UDim2.new(1, -254, 0, 44),
		THEME.orange,
		THEME.black
	)
	refreshPartyButton.TextSize = 18

	makeTextLabel(
		partyPanel,
		"MembersTitle",
		"Party Members",
		UDim2.new(0.27, -8, 0, 22),
		UDim2.new(0.02, 0, 0, 80),
		Enum.Font.GothamSemibold,
		18,
		THEME.offWhite,
		Enum.TextXAlignment.Left
	)
	local membersList = makeList(partyPanel, "MembersList", UDim2.new(0.27, -8, 1, -112), UDim2.new(0.02, 0, 0, 104))

	makeTextLabel(
		partyPanel,
		"InvitesTitle",
		"Incoming Invites",
		UDim2.new(0.29, -8, 0, 22),
		UDim2.new(0.31, 0, 0, 80),
		Enum.Font.GothamSemibold,
		18,
		THEME.offWhite,
		Enum.TextXAlignment.Left
	)
	local invitesList = makeList(partyPanel, "InvitesList", UDim2.new(0.29, -8, 1, -112), UDim2.new(0.31, 0, 0, 104))

	makeTextLabel(
		partyPanel,
		"FriendsTitle",
		"Online Friends",
		UDim2.new(0.36, -8, 0, 22),
		UDim2.new(0.62, 0, 0, 80),
		Enum.Font.GothamSemibold,
		18,
		THEME.offWhite,
		Enum.TextXAlignment.Left
	)
	local friendsList = makeList(partyPanel, "FriendsList", UDim2.new(0.36, -8, 1, -112), UDim2.new(0.62, 0, 0, 104))

	local playScreen = Instance.new("Frame")
	playScreen.Name = "PlayScreen"
	playScreen.Size = UDim2.fromScale(1, 1)
	playScreen.BackgroundTransparency = 1
	playScreen.Visible = false
	playScreen.Parent = root

	makeTextLabel(
		playScreen,
		"PlayTitle",
		"PLAY",
		UDim2.new(0, 180, 0, 42),
		UDim2.new(0.5, -90, 0, 22),
		Enum.Font.GothamBlack,
		38,
		THEME.white,
		Enum.TextXAlignment.Center
	).TextStrokeTransparency = 0

	local playQueueStatusLabel = makeTextLabel(
		playScreen,
		"PlayQueueStatus",
		"Finding match...",
		UDim2.new(1, 0, 0, 28),
		UDim2.new(0, 0, 0, 74),
		Enum.Font.GothamBold,
		24,
		THEME.white,
		Enum.TextXAlignment.Center
	)
	playQueueStatusLabel.TextStrokeColor3 = THEME.black
	playQueueStatusLabel.TextStrokeTransparency = 0.25
	playQueueStatusLabel.Visible = false

	local playMainMenuButton = createActionButton(
		playScreen,
		"PlayMainMenuButton",
		"MAIN MENU",
		UDim2.new(0, 190, 0, 46),
		UDim2.new(0, 24, 0, 24),
		THEME.charcoalLight,
		THEME.black
	)
	playMainMenuButton.TextSize = 24

	local playSearchButton = createActionButton(
		playScreen,
		"PlaySearchButton",
		"SEARCH ONLINE MATCH",
		UDim2.new(0, 320, 0, 64),
		UDim2.new(1, -344, 0.5, -32),
		THEME.orange,
		THEME.black
	)
	playSearchButton.TextSize = 26

	local playCancelButton = createActionButton(
		playScreen,
		"PlayCancelButton",
		"CANCEL",
		UDim2.new(0, 220, 0, 64),
		UDim2.new(0, 24, 0.5, -32),
		THEME.charcoalLight,
		THEME.black
	)
	playCancelButton.TextSize = 26
	playCancelButton.Visible = false

	local lobbyRosterPanel = Instance.new("Frame")
	lobbyRosterPanel.Name = "LobbyRosterPanel"
	lobbyRosterPanel.AnchorPoint = Vector2.new(1, 0.5)
	lobbyRosterPanel.Position = UDim2.new(1, -24, 0.5, 0)
	lobbyRosterPanel.Size = UDim2.new(0, 360, 0, 324)
	lobbyRosterPanel.BackgroundColor3 = THEME.charcoal
	lobbyRosterPanel.BackgroundTransparency = 0.08
	lobbyRosterPanel.BorderSizePixel = 0
	lobbyRosterPanel.Visible = false
	lobbyRosterPanel.Parent = playScreen
	styleSharpOutline(lobbyRosterPanel, THEME.black, 0)

	local lobbyRosterHeader = makeTextLabel(
		lobbyRosterPanel,
		"RosterHeader",
		"MATCH LOBBY",
		UDim2.new(1, -22, 0, 34),
		UDim2.new(0, 12, 0, 10),
		Enum.Font.GothamBlack,
		24,
		THEME.white,
		Enum.TextXAlignment.Left
	)
	lobbyRosterHeader.TextStrokeColor3 = THEME.black
	lobbyRosterHeader.TextStrokeTransparency = 0.05

	local lobbyRosterStatusLabel = makeTextLabel(
		lobbyRosterPanel,
		"RosterStatus",
		"Waiting for players",
		UDim2.new(1, -22, 0, 22),
		UDim2.new(0, 12, 0, 42),
		Enum.Font.GothamSemibold,
		16,
		THEME.orangeLight,
		Enum.TextXAlignment.Left
	)
	lobbyRosterStatusLabel.TextStrokeColor3 = THEME.black
	lobbyRosterStatusLabel.TextStrokeTransparency = 0.2

	local lobbyRosterCountLabel = makeTextLabel(
		lobbyRosterPanel,
		"RosterCount",
		("1/%d"):format(LOBBY_PLAYER_TARGET),
		UDim2.new(0, 80, 0, 28),
		UDim2.new(1, -92, 0, 12),
		Enum.Font.GothamBlack,
		22,
		THEME.orange,
		Enum.TextXAlignment.Right
	)
	lobbyRosterCountLabel.TextStrokeColor3 = THEME.black
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
	for i = 1, LOBBY_PLAYER_TARGET do
		local row = Instance.new("Frame")
		row.Name = ("Slot%d"):format(i)
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = THEME.charcoalLight
		row.BackgroundTransparency = 0.12
		row.BorderSizePixel = 0
		row.Parent = rosterSlots
		styleSharpOutline(row, THEME.black, 0)
		lobbySlotRows[i] = row

		local indexLabel = makeTextLabel(
			row,
			"Index",
			tostring(i),
			UDim2.new(0, 28, 1, 0),
			UDim2.new(0, 8, 0, 0),
			Enum.Font.GothamBlack,
			16,
			THEME.orange,
			Enum.TextXAlignment.Center
		)
		indexLabel.TextStrokeColor3 = THEME.black
		indexLabel.TextStrokeTransparency = 0.1

		local nameLabel = makeTextLabel(
			row,
			"PlayerName",
			"Waiting for player...",
			UDim2.new(1, -48, 1, 0),
			UDim2.new(0, 40, 0, 0),
			Enum.Font.GothamSemibold,
			15,
			THEME.offWhite,
			Enum.TextXAlignment.Left
		)
		nameLabel.TextStrokeColor3 = THEME.black
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

local function buildMenuRig()
	local characterPosition = CHARACTER_POSITION
	local cameraPosition = CAMERA_POSITION
	local toCameraFlat = Vector3.new(
		cameraPosition.X - characterPosition.X,
		0,
		cameraPosition.Z - characterPosition.Z
	)
	if toCameraFlat.Magnitude < 0.001 then
		toCameraFlat = Vector3.new(0, 0, -1)
	end

	local playerForward = toCameraFlat.Unit
	local baseCameraForward = -playerForward
	local cameraForward = (CFrame.Angles(0, math.rad(-CAMERA_RIGHT_YAW_DEGREES), 0):VectorToWorldSpace(baseCameraForward)).Unit
	local cameraCFrame = CFrame.lookAt(cameraPosition, cameraPosition + cameraForward)
	local cameraFocusPoint = cameraPosition + cameraForward * 64

	return {
		characterPosition = characterPosition,
		focusPosition = cameraFocusPoint,
		cameraCFrame = cameraCFrame,
	}
end

local function placeCharacterFeetAtPosition(character, feetPosition, cameraPosition)
	local lookTarget = Vector3.new(cameraPosition.X, feetPosition.Y, cameraPosition.Z)
	local baseFacing = CFrame.lookAt(feetPosition, lookTarget)
	local rotatedFacing = baseFacing * CFrame.Angles(0, math.rad(-PLAYER_RIGHT_YAW_DEGREES), 0)
	character:PivotTo(rotatedFacing)

	local boundsCf, boundsSize = character:GetBoundingBox()
	local minY = boundsCf.Position.Y - (boundsSize.Y * 0.5)
	local deltaY = feetPosition.Y - minY
	if math.abs(deltaY) > 0.0001 then
		character:PivotTo(character:GetPivot() + Vector3.new(0, deltaY, 0))
	end
end

local function getControls()
	if controls then
		return controls
	end

	local ok, result = pcall(function()
		local playerScripts = waitForChildTimeout(localPlayer, "PlayerScripts", 5)
		local playerModule = playerScripts:WaitForChild("PlayerModule")
		return require(playerModule):GetControls()
	end)

	if ok then
		controls = result
	end

	return controls
end

local function disableControls()
	local playerControls = getControls()
	if playerControls and playerControls.Disable then
		playerControls:Disable()
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function lockCharacterMotion(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
end

local function resolveRunAnimationId(character, humanoid)
	local animateScript = character:FindFirstChild("Animate")
	if animateScript then
		local runNode = animateScript:FindFirstChild("run")
		if runNode then
			for _, child in ipairs(runNode:GetChildren()) do
				if child:IsA("Animation") and child.AnimationId ~= "" then
					return child.AnimationId
				end
			end
		end
	end

	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return "rbxassetid://180426354"
	end
	return "rbxassetid://507767714"
end

local function forceCharacterRunAnimation(character)
	local animateScript = character:FindFirstChild("Animate")
	if animateScript and (animateScript:IsA("LocalScript") or animateScript:IsA("Script")) then
		animateScript.Enabled = false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local runAnimation = Instance.new("Animation")
	runAnimation.Name = "MenuRunAnimation"
	runAnimation.AnimationId = resolveRunAnimationId(character, humanoid)
	runAnimation.Parent = character

	local runTrack = animator:LoadAnimation(runAnimation)
	runTrack.Looped = true
	runTrack.Priority = Enum.AnimationPriority.Movement
	runTrack:Play(0.1, 1, 1)
end

local function setHomeCameraMotionEnabled(enabled, immediate)
	homeCameraMotionEnabled = enabled == true
	cameraMotionTarget = homeCameraMotionEnabled and 1 or 0
	if immediate then
		cameraMotionBlend = cameraMotionTarget
	end
end

local function getLockedFocusDistance()
	if typeof(lockedCameraFocus) ~= "Vector3" or not lockedCameraCFrame then
		return CAMERA_FOCUS_DISTANCE
	end

	local dist = (lockedCameraFocus - lockedCameraCFrame.Position).Magnitude
	if dist > 0.1 then
		return dist
	end
	return CAMERA_FOCUS_DISTANCE
end

local function resetCameraToLockedBase()
	local camera = Workspace.CurrentCamera
	if not camera or not lockedCameraCFrame then
		return
	end

	local focusDistance = getLockedFocusDistance()

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA_FOV
	camera.CFrame = lockedCameraCFrame
	camera.Focus = CFrame.new(lockedCameraCFrame.Position + (lockedCameraCFrame.LookVector * focusDistance))
end

local function computeCameraMotion(now)
	local yaw = math.sin((now * math.pi * 2 * CAMERA_SWAY_YAW_HZ) + 0.2) * math.rad(CAMERA_SWAY_YAW_DEGREES)
	local pitch = math.sin((now * math.pi * 2 * CAMERA_SWAY_PITCH_HZ) + 1.1) * math.rad(CAMERA_SWAY_PITCH_DEGREES)
	local fovDelta = math.sin((now * math.pi * 2 * CAMERA_FOV_BREATHE_HZ) + 0.8) * CAMERA_FOV_BREATHE_DELTA
	return yaw, pitch, fovDelta
end

local function setCameraLock(cameraCFrame, focusPosition)
	lockedCameraCFrame = cameraCFrame
	lockedCameraFocus = focusPosition

	if cameraLockConn then
		return
	end

	cameraLockConn = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera or not lockedCameraCFrame then
			return
		end

		local now = os.clock()
		local dt = math.max(0, now - lastCameraMotionTick)
		lastCameraMotionTick = now
		local blendAlpha = 1 - math.exp(-CAMERA_MOTION_BLEND_SPEED * dt)
		cameraMotionBlend += (cameraMotionTarget - cameraMotionBlend) * blendAlpha
		if math.abs(cameraMotionTarget - cameraMotionBlend) < 0.0005 then
			cameraMotionBlend = cameraMotionTarget
		end

		local yawOffset, pitchOffset, fovDelta = computeCameraMotion(now)
		local appliedYaw = yawOffset * cameraMotionBlend
		local appliedPitch = pitchOffset * cameraMotionBlend
		local appliedFovDelta = fovDelta * cameraMotionBlend
		local animatedCFrame = lockedCameraCFrame * CFrame.Angles(appliedPitch, appliedYaw, 0)
		local focusDistance = getLockedFocusDistance()

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = CAMERA_FOV + appliedFovDelta
		camera.CFrame = animatedCFrame
		camera.Focus = CFrame.new(animatedCFrame.Position + (animatedCFrame.LookVector * focusDistance))
	end)
end

local function hideDebugHud()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local function hideOne(name)
		local guiRef = playerGui:FindFirstChild(name)
		if guiRef and guiRef:IsA("ScreenGui") then
			guiRef.Enabled = false
		end
	end

	hideOne("DebugHUD")
	hideOne("ThrustDebugHUD")

	playerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") and (child.Name == "DebugHUD" or child.Name == "ThrustDebugHUD") then
			child.Enabled = false
		end
	end)
end

local function setPartyStatus(text, isError)
	if not ui then
		return
	end
	ui.partyStatusLabel.Text = text
	ui.partyStatusLabel.TextColor3 = isError and THEME.orangeLight or THEME.offWhite
end

local function setPlayStatus(text, isError)
	if text == nil or text == "" then
		playStatusText = nil
		playStatusIsError = false
		return
	end

	playStatusText = tostring(text)
	playStatusIsError = isError == true
end

local function partyDisplayName(entry)
	local display = entry.displayName or entry.fromDisplayName or entry.name or entry.fromName or ("User " .. tostring(entry.userId or entry.fromUserId or 0))
	local name = entry.name or entry.fromName
	if name and display ~= name then
		return ("%s (@%s)"):format(display, name)
	end
	return display
end

local function makePartyRow(list, height)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -4, 0, height or 34)
	row.BackgroundColor3 = THEME.charcoalLight
	row.BackgroundTransparency = 0.14
	row.BorderSizePixel = 0
	row.Parent = list
	styleSharpOutline(row, THEME.black, 0)
	return row
end

local function getPartyRemotes()
	if partyRemotes then
		return partyRemotes
	end

	local remotesRoot = waitForChildTimeout(ReplicatedStorage, "Remotes", 10)
	partyRemotes = {
		getState = waitForChildTimeout(remotesRoot, "PartyGetState", 10),
		invite = waitForChildTimeout(remotesRoot, "PartyInvite", 10),
		respondInvite = waitForChildTimeout(remotesRoot, "PartyRespondInvite", 10),
		leave = waitForChildTimeout(remotesRoot, "PartyLeave", 10),
		updated = waitForChildTimeout(remotesRoot, "PartyUpdated", 10),
		message = waitForChildTimeout(remotesRoot, "PartyMessage", 10),
	}

	return partyRemotes
end

local function getLobbyRemotes()
	if lobbyRemotes then
		return lobbyRemotes
	end

	local remotesRoot = waitForChildTimeout(ReplicatedStorage, "Remotes", 10)
	lobbyRemotes = {
		getState = waitForChildTimeout(remotesRoot, "LobbyGetState", 10),
		command = waitForChildTimeout(remotesRoot, "LobbyCommand", 10),
		updated = waitForChildTimeout(remotesRoot, "LobbyUpdated", 10),
		message = waitForChildTimeout(remotesRoot, "LobbyMessage", 10),
	}

	return lobbyRemotes
end

local LobbyQueueClient = {}

function LobbyQueueClient.StartSearch()
	local remotes = getLobbyRemotes()
	remotes.command:FireServer({
		op = "QueueJoin",
		mode = "Public",
	})
	return true
end

function LobbyQueueClient.CancelSearch()
	local remotes = getLobbyRemotes()
	remotes.command:FireServer({
		op = "QueueCancel",
	})
	return true
end

function LobbyQueueClient.GetState()
	local remotes = getLobbyRemotes()
	local ok, state = pcall(function()
		return remotes.getState:InvokeServer()
	end)
	if not ok or type(state) ~= "table" then
		return nil
	end
	return state
end

local function applyPartyPanelVisibility()
	if not ui then
		return
	end

	if isInPlayScreen then
		ui.partyPanel.Visible = false
		ui.closePartyButton.Visible = false
		return
	end

	if currentPartyExists then
		ui.partyPanel.Visible = true
		ui.closePartyButton.Visible = false
	else
		ui.partyPanel.Visible = partyPanelManualOpen
		ui.closePartyButton.Visible = partyPanelManualOpen
	end
end

local function updateLobbyRosterUi()
	if not ui then
		return
	end

	local joinedCount = math.min(#lobbyPreviewMembers, LOBBY_PLAYER_TARGET)
	local showRoster = isInPlayScreen and (isSearchingForMatch or currentLobbyContext == "lobby" or joinedCount > 0)
	ui.lobbyRosterPanel.Visible = showRoster
	if not showRoster then
		return
	end

	ui.lobbyRosterCountLabel.Text = ("%d/%d"):format(joinedCount, LOBBY_PLAYER_TARGET)

	if joinedCount >= LOBBY_PLAYER_TARGET or currentLobbyContext == "lobby" then
		ui.lobbyRosterStatusLabel.Text = "Round begins now"
		ui.lobbyRosterStatusLabel.TextColor3 = THEME.orange
	else
		ui.lobbyRosterStatusLabel.Text = "Waiting for players"
		ui.lobbyRosterStatusLabel.TextColor3 = THEME.offWhite
	end

	for i = 1, LOBBY_PLAYER_TARGET do
		local row = ui.lobbySlotRows[i]
		local label = ui.lobbySlotLabels[i]
		local member = lobbyPreviewMembers[i]
		if member then
			label.Text = partyDisplayName(member)
			label.TextColor3 = THEME.white
			row.BackgroundColor3 = THEME.charcoalLight
			row.BackgroundTransparency = 0.06
		else
			label.Text = "Waiting for player..."
			label.TextColor3 = THEME.orangeLight
			row.BackgroundColor3 = THEME.charcoal
			row.BackgroundTransparency = 0.22
		end
	end
end

local function updatePlayScreenUi()
	if not ui then
		return
	end

	ui.playScreen.Visible = isInPlayScreen
	ui.menu.Visible = not isInPlayScreen
	ui.partyTabButton.Visible = not isInPlayScreen

	ui.playSearchButton.Visible = isInPlayScreen and (not isSearchingForMatch)
	ui.playCancelButton.Visible = isInPlayScreen and isSearchingForMatch

	if isSearchingForMatch then
		ui.playQueueStatusLabel.Visible = isInPlayScreen
		ui.playQueueStatusLabel.Text = "Finding match..."
		ui.playQueueStatusLabel.TextColor3 = THEME.white
	elseif playStatusText and playStatusText ~= "" then
		ui.playQueueStatusLabel.Visible = isInPlayScreen
		ui.playQueueStatusLabel.Text = playStatusText
		ui.playQueueStatusLabel.TextColor3 = playStatusIsError and THEME.orangeLight or THEME.white
	else
		ui.playQueueStatusLabel.Visible = false
	end

	applyPartyPanelVisibility()
	updateLobbyRosterUi()
end

local function snapshotLobbyMembersFromState(state)
	local members = {}
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
				if #members >= LOBBY_PLAYER_TARGET then
					break
				end
			end
		end
	end

	return members
end

local function applyLobbyState(state)
	if type(state) ~= "table" then
		return
	end

	local context = state.context
	currentLobbyContext = context or "none"
	lobbyPreviewMembers = snapshotLobbyMembersFromState(state)
	if context == "queued" then
		isSearchingForMatch = true
		if playStatusText == "Lobby formed." then
			setPlayStatus(nil, false)
		end
	elseif context == "lobby" then
		isSearchingForMatch = false
		setPlayStatus("Lobby formed.", false)
	else
		isSearchingForMatch = false
		if playStatusText == "Lobby formed." or playStatusText == "Searching for match..." or playStatusText == "Cancelling search..." then
			setPlayStatus(nil, false)
		end
	end

	updatePlayScreenUi()
end

local function renderPartyState(state)
	if not ui then
		return
	end

	clearListRows(ui.membersList)
	clearListRows(ui.invitesList)
	clearListRows(ui.friendsList)

	local partyData = state and state.party or nil
	local incomingInvites = (state and state.incomingInvites) or {}
	local friends = (state and state.friends) or {}
	local capacity = (partyData and partyData.capacity) or (state and state.partyCapacity) or 4
	local hadParty = currentPartyExists
	currentPartyExists = partyData ~= nil

	if currentPartyExists then
		local memberCount = #(partyData.members or {})
		setPartyStatus(("Party %d/%d"):format(memberCount, capacity), false)
		ui.partyTabButton.Text = ("Party %d/%d"):format(memberCount, capacity)
		ui.leavePartyButton.Visible = true
		partyPanelManualOpen = true
	else
		setPartyStatus("No party yet. Invite a friend to create one.", false)
		ui.partyTabButton.Text = "Invite friends"
		ui.leavePartyButton.Visible = false
		if hadParty then
			partyPanelManualOpen = false
		end
	end

	applyPartyPanelVisibility()

	local members = partyData and partyData.members or {}
	if #members == 0 then
		local emptyRow = makePartyRow(ui.membersList, 32)
		makeTextLabel(
			emptyRow,
			"EmptyMembersLabel",
			"No party members.",
			UDim2.new(1, -12, 1, 0),
			UDim2.new(0, 8, 0, 0),
			Enum.Font.Gotham,
			14,
			THEME.offWhite,
			Enum.TextXAlignment.Left
		)
	else
		for _, member in ipairs(members) do
			local row = makePartyRow(ui.membersList, 34)
			local isLeader = partyData.leaderUserId == member.userId
			makeTextLabel(
				row,
				"MemberName",
				partyDisplayName(member) .. (isLeader and " (Leader)" or ""),
				UDim2.new(1, -12, 1, 0),
				UDim2.new(0, 8, 0, 0),
				Enum.Font.GothamSemibold,
				14,
				THEME.white,
				Enum.TextXAlignment.Left
			)
		end
	end

	if #incomingInvites == 0 then
		local emptyRow = makePartyRow(ui.invitesList, 32)
		makeTextLabel(
			emptyRow,
			"EmptyInvitesLabel",
			"No incoming invites.",
			UDim2.new(1, -12, 1, 0),
			UDim2.new(0, 8, 0, 0),
			Enum.Font.Gotham,
			14,
			THEME.offWhite,
			Enum.TextXAlignment.Left
		)
	else
		local remotes = getPartyRemotes()
		for _, invite in ipairs(incomingInvites) do
			local row = makePartyRow(ui.invitesList, 42)

			makeTextLabel(
				row,
				"InviteFrom",
				partyDisplayName(invite),
				UDim2.new(1, -170, 0, 20),
				UDim2.new(0, 8, 0, 2),
				Enum.Font.GothamSemibold,
				13,
				THEME.white,
				Enum.TextXAlignment.Left
			)

			makeTextLabel(
				row,
				"InviteMeta",
				("Party %d/%d"):format(invite.partySize or 1, invite.partyCapacity or capacity),
				UDim2.new(1, -170, 0, 16),
				UDim2.new(0, 8, 0, 22),
				Enum.Font.Gotham,
				12,
				THEME.orangeLight,
				Enum.TextXAlignment.Left
			)

			local acceptButton = createActionButton(
				row,
				"AcceptInvite",
				"ACCEPT",
				UDim2.new(0, 72, 0, 28),
				UDim2.new(1, -156, 0, 7),
				THEME.orange,
				THEME.black
			)
			acceptButton.TextSize = 14
			acceptButton.MouseButton1Click:Connect(function()
				remotes.respondInvite:FireServer(invite.fromUserId, true)
			end)

			local declineButton = createActionButton(
				row,
				"DeclineInvite",
				"DECLINE",
				UDim2.new(0, 72, 0, 28),
				UDim2.new(1, -78, 0, 7),
				THEME.charcoalLight,
				THEME.black
			)
			declineButton.TextSize = 14
			declineButton.MouseButton1Click:Connect(function()
				remotes.respondInvite:FireServer(invite.fromUserId, false)
			end)
		end
	end

	if #friends == 0 then
		local emptyRow = makePartyRow(ui.friendsList, 32)
		makeTextLabel(
			emptyRow,
			"EmptyFriendsLabel",
			"No online friends in this server.",
			UDim2.new(1, -12, 1, 0),
			UDim2.new(0, 8, 0, 0),
			Enum.Font.Gotham,
			14,
			THEME.offWhite,
			Enum.TextXAlignment.Left
		)
	else
		local remotes = getPartyRemotes()
		for _, friend in ipairs(friends) do
			local row = makePartyRow(ui.friendsList, 42)

			makeTextLabel(
				row,
				"FriendName",
				partyDisplayName(friend),
				UDim2.new(1, -140, 0, 20),
				UDim2.new(0, 8, 0, 2),
				Enum.Font.GothamSemibold,
				13,
				THEME.white,
				Enum.TextXAlignment.Left
			)

			local reasonText = friend.reason or "Ready to invite"
			makeTextLabel(
				row,
				"FriendReason",
				reasonText,
				UDim2.new(1, -140, 0, 16),
				UDim2.new(0, 8, 0, 22),
				Enum.Font.Gotham,
				12,
				friend.canInvite and THEME.orangeLight or THEME.offWhite,
				Enum.TextXAlignment.Left
			)

			local inviteButton = createActionButton(
				row,
				"InviteFriend",
				friend.canInvite and "INVITE" or "LOCKED",
				UDim2.new(0, 110, 0, 28),
				UDim2.new(1, -118, 0, 7),
				friend.canInvite and THEME.orange or THEME.charcoalLight,
				THEME.black
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

local function requestPartyState()
	local remotes = getPartyRemotes()
	local ok, state = pcall(function()
		return remotes.getState:InvokeServer()
	end)
	if not ok or type(state) ~= "table" then
		setPartyStatus("Failed to load party state.", true)
		return
	end
	renderPartyState(state)
end

local function requestLobbyState()
	local state = LobbyQueueClient.GetState()
	if state then
		applyLobbyState(state)
		return
	end

	isSearchingForMatch = false
	currentLobbyContext = "none"
	lobbyPreviewMembers = {}
	setPlayStatus("Failed to load lobby state.", true)
	updatePlayScreenUi()
end

local function bindPartyUi()
	local remotes = getPartyRemotes()

	remotes.updated.OnClientEvent:Connect(function(state)
		if type(state) == "table" then
			renderPartyState(state)
		end
	end)

	remotes.message.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			setPartyStatus(tostring(payload.text or ""), payload.isError == true)
		elseif payload ~= nil then
			setPartyStatus(tostring(payload), false)
		end
	end)

	ui.partyTabButton.MouseButton1Click:Connect(function()
		if isInPlayScreen then
			return
		end

		if currentPartyExists then
			applyPartyPanelVisibility()
			requestPartyState()
			return
		end

		partyPanelManualOpen = not partyPanelManualOpen
		applyPartyPanelVisibility()
		if partyPanelManualOpen then
			requestPartyState()
		end
	end)

	ui.closePartyButton.MouseButton1Click:Connect(function()
		if currentPartyExists then
			return
		end
		partyPanelManualOpen = false
		applyPartyPanelVisibility()
	end)

	ui.refreshPartyButton.MouseButton1Click:Connect(function()
		requestPartyState()
	end)

	ui.leavePartyButton.MouseButton1Click:Connect(function()
		remotes.leave:FireServer()
	end)
end

local function bindLobbyUi()
	local remotes = getLobbyRemotes()

	remotes.updated.OnClientEvent:Connect(function(state)
		if type(state) == "table" then
			applyLobbyState(state)
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
			setPlayStatus(tostring(text), isError)
			updatePlayScreenUi()
		end
	end)

	requestLobbyState()
end

local function bindPlayUi()
	ui.playButton.MouseButton1Click:Connect(function()
		isInPlayScreen = true
		requestLobbyState()
		updatePlayScreenUi()
	end)

	ui.playMainMenuButton.MouseButton1Click:Connect(function()
		if isSearchingForMatch then
			LobbyQueueClient.CancelSearch()
		end
		isInPlayScreen = false
		updatePlayScreenUi()
	end)

	ui.playSearchButton.MouseButton1Click:Connect(function()
		if isSearchingForMatch then
			return
		end

		local ok = LobbyQueueClient.StartSearch()
		if not ok then
			setPlayStatus("Queue unavailable", true)
			updatePlayScreenUi()
			return
		end

		currentLobbyContext = "queued"
		lobbyPreviewMembers = {
			{
				userId = localPlayer.UserId,
				name = localPlayer.Name,
				displayName = localPlayer.DisplayName,
			},
		}
		isSearchingForMatch = true
		setPlayStatus(nil, false)
		updatePlayScreenUi()
	end)

	ui.playCancelButton.MouseButton1Click:Connect(function()
		if not isSearchingForMatch then
			return
		end

		local ok = LobbyQueueClient.CancelSearch()
		if ok then
			isSearchingForMatch = false
			currentLobbyContext = "none"
			lobbyPreviewMembers = {}
			setPlayStatus("Cancelling search...", false)
		else
			setPlayStatus("Queue unavailable", true)
		end
		updatePlayScreenUi()
	end)
end

local function bindHomeCameraLifecycle(gui)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			setHomeCameraMotionEnabled(true, false)
			return
		end

		setHomeCameraMotionEnabled(false, true)
		resetCameraToLockedBase()
	end)

	gui.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end

		setHomeCameraMotionEnabled(false, true)
		resetCameraToLockedBase()
		if cameraLockConn then
			cameraLockConn:Disconnect()
			cameraLockConn = nil
		end
	end)
end

local function stageCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not root then
		return
	end

	local rig = buildMenuRig()
	placeCharacterFeetAtPosition(character, rig.characterPosition, rig.cameraCFrame.Position)
	forceCharacterRunAnimation(character)
	lockCharacterMotion(character)
	setCameraLock(rig.cameraCFrame, rig.focusPosition)
	disableControls()
end

local gui = getOrCreateGui()
ui = buildOverlay(gui)
bindHomeCameraLifecycle(gui)
updatePlayScreenUi()
bindPlayUi()
bindPartyUi()
bindLobbyUi()
hideDebugHud()
requestPartyState()

localPlayer.CharacterAdded:Connect(function(character)
	task.wait(0.1)
	stageCharacter(character)
end)

if localPlayer.Character then
	stageCharacter(localPlayer.Character)
end
