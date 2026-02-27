local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local root = script.Parent

local Constants = require(root:WaitForChild("Constants"))
local Theme = require(root:WaitForChild("Theme"))
local Utils = require(root:WaitForChild("Utils"))
local CommonWidgets = require(root:WaitForChild("UI"):WaitForChild("CommonWidgets"))
local OverlayBuilder = require(root:WaitForChild("UI"):WaitForChild("OverlayBuilder"))
local HomeCameraController = require(root:WaitForChild("Camera"):WaitForChild("HomeCameraController"))
local PlayController = require(root:WaitForChild("MainMenu"):WaitForChild("Play"):WaitForChild("Controller"))
local InviteFriendsController = require(root:WaitForChild("InviteFriends"):WaitForChild("InviteFriendsController"))

local HomeScreenMain = {}

local REMOTE_BIND_RETRY_ATTEMPTS = 30
local REMOTE_BIND_RETRY_SECONDS = 1

function HomeScreenMain.Start()
	local localPlayer = Players.LocalPlayer
	local widgets = CommonWidgets.new(Theme.Colors, Theme.TabThemeByName)
	local gui = OverlayBuilder.GetOrCreateGui(localPlayer, Constants.GUI_NAME, Utils.waitForChildTimeout)
	local ui = OverlayBuilder.Build(gui, widgets, Theme.Colors, Constants)

	local cameraController = HomeCameraController.new({
		localPlayer = localPlayer,
		runService = RunService,
		userInputService = UserInputService,
		workspace = Workspace,
		constants = Constants,
		waitForChildTimeout = Utils.waitForChildTimeout,
	})
	cameraController:SetOverlayGui(gui)
	cameraController:BindHomeCameraLifecycle(gui)

	local inviteFriendsController = InviteFriendsController.new({
		localPlayer = localPlayer,
		replicatedStorage = ReplicatedStorage,
		ui = ui,
		widgets = widgets,
		waitForChildTimeout = Utils.waitForChildTimeout,
		themeColors = Theme.Colors,
		partyDisplayName = Utils.partyDisplayName,
	})

	local playController = PlayController.new({
		localPlayer = localPlayer,
		replicatedStorage = ReplicatedStorage,
		ui = ui,
		waitForChildTimeout = Utils.waitForChildTimeout,
		themeColors = Theme.Colors,
		constants = Constants,
		partyDisplayName = Utils.partyDisplayName,
	})

	playController:SetOnPlayScreenChanged(function(isInPlayScreen)
		inviteFriendsController:SetInPlayScreen(isInPlayScreen)
	end)
	playController:SetOnLobbyFormed(function()
		cameraController:ExitHomeScreenToGame()
	end)

	playController:UpdatePlayScreenUi()
	playController:BindPlayUi()

	cameraController:HideDebugHud()

	localPlayer.CharacterAdded:Connect(function(character)
		cameraController:OnCharacterAdded(character)
	end)
	cameraController:StageCurrentCharacterIfPresent()

	task.spawn(function()
		for attempt = 1, REMOTE_BIND_RETRY_ATTEMPTS do
			local ok, err = pcall(function()
				playController:BindLobbyUi()
				inviteFriendsController:Bind()
				inviteFriendsController:RequestPartyState()
			end)
			if ok then
				return
			end
			warn(("[HomeScreen] Remote bind attempt %d/%d failed: %s"):format(attempt, REMOTE_BIND_RETRY_ATTEMPTS, tostring(err)))
			task.wait(REMOTE_BIND_RETRY_SECONDS)
		end
		warn("[HomeScreen] Failed to bind remotes after retries.")
	end)
end

return HomeScreenMain
