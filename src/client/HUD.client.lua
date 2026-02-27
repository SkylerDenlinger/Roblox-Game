local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local HUD_NAME = "InRoundHUD"
local ROOT_PANEL_NAME = "Panel"
local TEMP_SPECTATE_BOT_NAME = "TempSpectateBot"
local SESSION_VISIBLE_MATCH_VALUE = "SessionId"
local SPECTATE_MIN_SECONDS = 5
local SPECTATE_REFRESH_SECONDS = 0.5

local function waitForChildTimeout(parent, name, timeoutSeconds, context)
	local t0 = os.clock()
	local child = parent:FindFirstChild(name)
	while not child do
		if os.clock() - t0 >= timeoutSeconds then
			error(("%s timed out waiting for '%s' under %s"):format(context or "InRoundHUD", name, parent:GetFullName()))
		end
		task.wait(0.05)
		child = parent:FindFirstChild(name)
	end
	return child
end

local function getOrCreateGui()
	local playerGui = waitForChildTimeout(localPlayer, "PlayerGui", 10, "InRoundHUD")
	local existing = playerGui:FindFirstChild(HUD_NAME)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = HUD_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 210
	gui.Parent = playerGui
	return gui
end

local function makeLabel(parent, name, positionY, textSize, textColor, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.new(0, 14, 0, positionY)
	label.Size = UDim2.new(1, -28, 0, 24)
	label.BackgroundTransparency = 1
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = textColor
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.25
	label.Parent = parent
	return label
end

local function buildHud(gui)
	local existing = gui:FindFirstChild(ROOT_PANEL_NAME)
	if existing and existing:IsA("Frame") then
		existing:Destroy()
	end

	local panel = Instance.new("Frame")
	panel.Name = ROOT_PANEL_NAME
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new(0, 16, 0, 16)
	panel.Size = UDim2.new(0, 320, 0, 150)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	panel.BackgroundTransparency = 0.18
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(0, 0, 0)
	panelStroke.Thickness = 2
	panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelStroke.Parent = panel

	local title = makeLabel(panel, "Title", 10, 20, Color3.fromRGB(255, 196, 95))
	title.Font = Enum.Font.GothamBlack
	title.Text = "ROUND STATUS"

	local keysLabel = makeLabel(panel, "Keys", 42, 18, Color3.fromRGB(255, 255, 255))
	local gearsLabel = makeLabel(panel, "Gears", 68, 18, Color3.fromRGB(255, 255, 255))
	local doorLabel = makeLabel(panel, "Door", 94, 18, Color3.fromRGB(255, 255, 255))
	local qualifiedLabel = makeLabel(panel, "Qualified", 120, 18, Color3.fromRGB(255, 255, 255))

	local spectateLabel = Instance.new("TextLabel")
	spectateLabel.Name = "SpectateLabel"
	spectateLabel.AnchorPoint = Vector2.new(0.5, 0)
	spectateLabel.Position = UDim2.new(0.5, 0, 0, 16)
	spectateLabel.Size = UDim2.new(0, 580, 0, 42)
	spectateLabel.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	spectateLabel.BackgroundTransparency = 0.22
	spectateLabel.BorderSizePixel = 0
	spectateLabel.Font = Enum.Font.GothamBlack
	spectateLabel.TextSize = 24
	spectateLabel.TextColor3 = Color3.fromRGB(255, 196, 95)
	spectateLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	spectateLabel.TextStrokeTransparency = 0.15
	spectateLabel.Visible = false
	spectateLabel.Parent = gui

	local spectateStroke = Instance.new("UIStroke")
	spectateStroke.Color = Color3.fromRGB(0, 0, 0)
	spectateStroke.Thickness = 2
	spectateStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	spectateStroke.Parent = spectateLabel

	local resultsFrame = Instance.new("Frame")
	resultsFrame.Name = "ResultsFrame"
	resultsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	resultsFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	resultsFrame.Size = UDim2.new(0, 560, 0, 260)
	resultsFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	resultsFrame.BackgroundTransparency = 0.12
	resultsFrame.BorderSizePixel = 0
	resultsFrame.Visible = false
	resultsFrame.Parent = gui

	local resultsStroke = Instance.new("UIStroke")
	resultsStroke.Color = Color3.fromRGB(0, 0, 0)
	resultsStroke.Thickness = 2
	resultsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	resultsStroke.Parent = resultsFrame

	local resultsTitle = makeLabel(resultsFrame, "ResultsTitle", 20, 34, Color3.fromRGB(255, 196, 95), Enum.TextXAlignment.Center)
	resultsTitle.Position = UDim2.new(0, 0, 0, 20)
	resultsTitle.Size = UDim2.new(1, 0, 0, 40)
	resultsTitle.Text = "ROUND COMPLETE"
	resultsTitle.Font = Enum.Font.GothamBlack

	local resultsSubtitle = makeLabel(resultsFrame, "ResultsSubtitle", 76, 24, Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Center)
	resultsSubtitle.Position = UDim2.new(0, 0, 0, 76)
	resultsSubtitle.Size = UDim2.new(1, 0, 0, 34)
	resultsSubtitle.Text = ""

	local resultsDetails = makeLabel(resultsFrame, "ResultsDetails", 124, 20, Color3.fromRGB(236, 242, 250), Enum.TextXAlignment.Center)
	resultsDetails.Position = UDim2.new(0, 0, 0, 124)
	resultsDetails.Size = UDim2.new(1, 0, 0, 30)
	resultsDetails.Text = ""

	local resultsFootnote = makeLabel(resultsFrame, "ResultsFootnote", 166, 16, Color3.fromRGB(255, 184, 90), Enum.TextXAlignment.Center)
	resultsFootnote.Position = UDim2.new(0, 0, 0, 166)
	resultsFootnote.Size = UDim2.new(1, 0, 0, 24)
	resultsFootnote.Text = "Preparing next phase..."

	return {
		panel = panel,
		keysLabel = keysLabel,
		gearsLabel = gearsLabel,
		doorLabel = doorLabel,
		qualifiedLabel = qualifiedLabel,
		spectateLabel = spectateLabel,
		resultsFrame = resultsFrame,
		resultsSubtitle = resultsSubtitle,
		resultsDetails = resultsDetails,
	}
end

local function toDoorOpen(doorState)
	return string.lower(tostring(doorState or "")) == "open"
end

local function getCharacterHumanoid(player)
	if not player or not player.Character then
		return nil
	end
	return player.Character:FindFirstChildOfClass("Humanoid")
end

local function getBotSpectateSubject()
	local bot = Workspace:FindFirstChild(TEMP_SPECTATE_BOT_NAME)
	if not bot then
		return nil, nil
	end
	if bot:IsA("Model") then
		local humanoid = bot:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid, "Temp Bot"
		end
		local part = bot:FindFirstChild("HumanoidRootPart", true) or bot.PrimaryPart or bot:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part, "Temp Bot"
		end
	elseif bot:IsA("BasePart") then
		return bot, "Temp Bot"
	end
	return nil, nil
end

local function resolveSpectateSubject()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			local humanoid = getCharacterHumanoid(player)
			if humanoid then
				return humanoid, player.DisplayName or player.Name
			end
		end
	end
	return getBotSpectateSubject()
end

local function applySpectateCamera(subject)
	local camera = Workspace.CurrentCamera
	if not camera or not subject then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = subject
end

local function restoreLocalCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local humanoid = getCharacterHumanoid(localPlayer)
	if humanoid then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end

local function run()
	local gui = getOrCreateGui()
	local ui = buildHud(gui)

	local stateRoot = waitForChildTimeout(ReplicatedStorage, "State", 20, "InRoundHUD")
	local match = waitForChildTimeout(stateRoot, "Match", 20, "InRoundHUD")
	local progress = waitForChildTimeout(stateRoot, "Progress", 20, "InRoundHUD")
	local playerStateRoot = waitForChildTimeout(stateRoot, "PlayerState", 20, "InRoundHUD")

	local requiredKeysValue = waitForChildTimeout(progress, "RequiredKeys", 20, "InRoundHUD")
	local doorStateValue = waitForChildTimeout(progress, "DoorState", 20, "InRoundHUD")
	local qualifyCountValue = waitForChildTimeout(progress, "QualifyCount", 20, "InRoundHUD")
	local qualifiedCountValue = waitForChildTimeout(progress, "QualifiedCount", 20, "InRoundHUD")
	local winnerUserIdValue = waitForChildTimeout(progress, "WinnerUserId", 20, "InRoundHUD")
	local phaseValue = waitForChildTimeout(match, "Phase", 20, "InRoundHUD")
	local sessionIdValue = waitForChildTimeout(match, SESSION_VISIBLE_MATCH_VALUE, 20, "InRoundHUD")

	local model = {
		keys = 0,
		gears = 0,
		requiredKeys = requiredKeysValue.Value,
		doorState = doorStateValue.Value,
		qualified = false,
		qualifyCount = qualifyCountValue.Value,
		qualifiedCount = qualifiedCountValue.Value,
		winnerUserId = winnerUserIdValue.Value,
		phase = phaseValue.Value,
		sessionId = sessionIdValue.Value,
	}

	local spectate = {
		active = false,
		startedAt = 0,
		targetName = "Waiting for target",
	}
	local resultsVisible = false
	local previousQualified = false

	local playerFolder = nil
	local keysValue = nil
	local gearsValue = nil
	local qualifiedValue = nil

	local folderChildAddedConn = nil
	local keysChangedConn = nil
	local gearsChangedConn = nil
	local qualifiedChangedConn = nil

	local function applyHud()
		ui.panel.Visible = model.sessionId ~= ""
		ui.keysLabel.Text = ("Keys: %d / %d"):format(model.keys, model.requiredKeys)
		ui.gearsLabel.Text = ("Gears: %d"):format(model.gears)

		local doorOpen = toDoorOpen(model.doorState)
		ui.doorLabel.Text = ("Exit Door: %s"):format(doorOpen and "OPEN" or "CLOSED")
		ui.doorLabel.TextColor3 = doorOpen and Color3.fromRGB(105, 255, 115) or Color3.fromRGB(255, 125, 125)

		ui.qualifiedLabel.Text = ("Qualified: %s"):format(model.qualified and "YES" or "NO")
		ui.qualifiedLabel.TextColor3 = model.qualified and Color3.fromRGB(105, 255, 115) or Color3.fromRGB(255, 255, 255)
	end

	local function hideResults()
		resultsVisible = false
		ui.resultsFrame.Visible = false
	end

	local function showResults()
		resultsVisible = true
		ui.resultsFrame.Visible = true

		if model.qualified then
			ui.resultsSubtitle.Text = "You qualified for the next round"
			ui.resultsSubtitle.TextColor3 = Color3.fromRGB(105, 255, 115)
		else
			ui.resultsSubtitle.Text = "You did not qualify"
			ui.resultsSubtitle.TextColor3 = Color3.fromRGB(255, 125, 125)
		end

		local winnerText = "Winner: TBD"
		if model.winnerUserId and model.winnerUserId > 0 then
			winnerText = ("Winner UserId: %d"):format(model.winnerUserId)
		end
		ui.resultsDetails.Text = ("%s  |  Qualified %d/%d"):format(winnerText, model.qualifiedCount, model.qualifyCount)
	end

	local function updateSpectateLabel()
		if not spectate.active then
			ui.spectateLabel.Visible = false
			return
		end

		local elapsed = os.clock() - spectate.startedAt
		local remaining = math.max(0, math.ceil(SPECTATE_MIN_SECONDS - elapsed))
		local hasAllQualifiers = model.qualifyCount > 0 and model.qualifiedCount >= model.qualifyCount

		if hasAllQualifiers and remaining > 0 then
			ui.spectateLabel.Text = ("SPECTATING %s  |  RESULTS IN %ds"):format(spectate.targetName, remaining)
		else
			ui.spectateLabel.Text = ("SPECTATING %s"):format(spectate.targetName)
		end
		ui.spectateLabel.Visible = true
	end

	local function stopSpectate()
		if not spectate.active then
			return
		end
		spectate.active = false
		spectate.startedAt = 0
		spectate.targetName = "Waiting for target"
		ui.spectateLabel.Visible = false
		restoreLocalCamera()
	end

	local function shouldCompleteRoundForLocal()
		return model.qualified and model.qualifyCount > 0 and model.qualifiedCount >= model.qualifyCount
	end

	local function maybeAdvanceToResults()
		if not spectate.active then
			return
		end
		if not shouldCompleteRoundForLocal() then
			updateSpectateLabel()
			return
		end
		local elapsed = os.clock() - spectate.startedAt
		if elapsed < SPECTATE_MIN_SECONDS then
			updateSpectateLabel()
			return
		end
		stopSpectate()
		showResults()
	end

	local function startSpectate()
		if spectate.active then
			return
		end
		spectate.active = true
		spectate.startedAt = os.clock()
		hideResults()

		task.spawn(function()
			while spectate.active do
				local subject, targetName = resolveSpectateSubject()
				if subject then
					applySpectateCamera(subject)
					spectate.targetName = targetName or "Target"
				else
					spectate.targetName = "Waiting for target"
				end
				updateSpectateLabel()
				maybeAdvanceToResults()
				task.wait(SPECTATE_REFRESH_SECONDS)
			end
		end)
	end

	local function disconnectValueConnections()
		if keysChangedConn then
			keysChangedConn:Disconnect()
			keysChangedConn = nil
		end
		if gearsChangedConn then
			gearsChangedConn:Disconnect()
			gearsChangedConn = nil
		end
		if qualifiedChangedConn then
			qualifiedChangedConn:Disconnect()
			qualifiedChangedConn = nil
		end
	end

	local function handleQualifiedChanged(newValue)
		model.qualified = newValue == true
		applyHud()

		if model.qualified and not previousQualified and model.sessionId ~= "" then
			startSpectate()
		end
		if not model.qualified then
			stopSpectate()
			hideResults()
		end

		previousQualified = model.qualified
		maybeAdvanceToResults()
	end

	local function bindPlayerFolder(folder)
		playerFolder = folder
		disconnectValueConnections()
		if folderChildAddedConn then
			folderChildAddedConn:Disconnect()
			folderChildAddedConn = nil
		end

		keysValue = nil
		gearsValue = nil
		qualifiedValue = nil

		if not playerFolder then
			model.keys = 0
			model.gears = 0
			handleQualifiedChanged(false)
			return
		end

		local function hookValues()
			keysValue = playerFolder:FindFirstChild("Keys")
			gearsValue = playerFolder:FindFirstChild("Gears")
			qualifiedValue = playerFolder:FindFirstChild("Qualified")

			model.keys = (keysValue and keysValue.Value) or 0
			model.gears = (gearsValue and gearsValue.Value) or 0
			handleQualifiedChanged((qualifiedValue and qualifiedValue.Value) or false)
			applyHud()

			if keysValue and not keysChangedConn then
				keysChangedConn = keysValue.Changed:Connect(function()
					model.keys = keysValue.Value
					applyHud()
				end)
			end
			if gearsValue and not gearsChangedConn then
				gearsChangedConn = gearsValue.Changed:Connect(function()
					model.gears = gearsValue.Value
					applyHud()
				end)
			end
			if qualifiedValue and not qualifiedChangedConn then
				qualifiedChangedConn = qualifiedValue.Changed:Connect(function()
					handleQualifiedChanged(qualifiedValue.Value)
				end)
			end
		end

		hookValues()
		folderChildAddedConn = playerFolder.ChildAdded:Connect(function(child)
			if child.Name == "Keys" or child.Name == "Gears" or child.Name == "Qualified" then
				disconnectValueConnections()
				hookValues()
			end
		end)
	end

	local function tryBindLocalPlayerFolder()
		local folder = playerStateRoot:FindFirstChild(tostring(localPlayer.UserId))
		bindPlayerFolder(folder)
	end

	requiredKeysValue.Changed:Connect(function()
		model.requiredKeys = requiredKeysValue.Value
		applyHud()
	end)

	doorStateValue.Changed:Connect(function()
		model.doorState = doorStateValue.Value
		applyHud()
	end)

	qualifyCountValue.Changed:Connect(function()
		model.qualifyCount = qualifyCountValue.Value
		maybeAdvanceToResults()
		if resultsVisible then
			showResults()
		end
	end)

	qualifiedCountValue.Changed:Connect(function()
		model.qualifiedCount = qualifiedCountValue.Value
		maybeAdvanceToResults()
		if resultsVisible then
			showResults()
		end
	end)

	winnerUserIdValue.Changed:Connect(function()
		model.winnerUserId = winnerUserIdValue.Value
		if resultsVisible then
			showResults()
		end
	end)

	phaseValue.Changed:Connect(function()
		model.phase = phaseValue.Value
		if model.phase == "Lobby" and not model.qualified then
			hideResults()
			stopSpectate()
		end
	end)

	sessionIdValue.Changed:Connect(function()
		local previousSession = model.sessionId
		model.sessionId = sessionIdValue.Value
		applyHud()

		if model.sessionId == "" then
			stopSpectate()
			hideResults()
			return
		end

		if previousSession ~= model.sessionId then
			hideResults()
			if model.qualified then
				startSpectate()
			end
		end
	end)

	playerStateRoot.ChildAdded:Connect(function(child)
		if child.Name == tostring(localPlayer.UserId) then
			tryBindLocalPlayerFolder()
		end
	end)

	playerStateRoot.ChildRemoved:Connect(function(child)
		if child.Name == tostring(localPlayer.UserId) then
			bindPlayerFolder(nil)
		end
	end)

	tryBindLocalPlayerFolder()
	applyHud()
	updateSpectateLabel()
end

local ok, err = pcall(run)
if not ok then
	warn(("[InRoundHUD] Failed to initialize: %s"):format(tostring(err)))
end
