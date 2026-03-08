local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ScreenFlowSignals = require(script.Parent:WaitForChild("ScreenFlowSignals"))

local localPlayer = Players.LocalPlayer

local HUD_NAME = "InRoundHUD"
local TEMP_SPECTATE_BOT_NAME = "TempSpectateBot"
local MAX_LEADERBOARD_ROWS = 8
local UPDATE_INTERVAL_SECONDS = 0.1

local function waitForChildTimeout(parent, name, timeoutSeconds, context)
	local startedAt = os.clock()
	local child = parent:FindFirstChild(name)
	while not child do
		if os.clock() - startedAt >= timeoutSeconds then
			error(("%s timed out waiting for '%s' under %s"):format(context or "HUD", name, parent:GetFullName()))
		end
		task.wait(0.05)
		child = parent:FindFirstChild(name)
	end
	return child
end

local function formatTime(seconds)
	local clamped = math.max(0, math.floor((seconds or 0) + 0.5))
	local minutes = math.floor(clamped / 60)
	local remainder = clamped % 60
	if minutes > 0 then
		return ("%d:%02d"):format(minutes, remainder)
	end
	return tostring(remainder)
end

local function getOrCreateGui()
	local playerGui = waitForChildTimeout(localPlayer, "PlayerGui", 10, "HUD")
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
	gui.DisplayOrder = 220
	gui.Parent = playerGui
	return gui
end

local function makeLabel(parent, options)
	local label = Instance.new("TextLabel")
	label.Name = options.name
	label.AnchorPoint = options.anchorPoint or Vector2.new(0, 0)
	label.Position = options.position
	label.Size = options.size
	label.BackgroundTransparency = options.backgroundTransparency or 1
	label.BackgroundColor3 = options.backgroundColor3 or Color3.fromRGB(0, 0, 0)
	label.BorderSizePixel = 0
	label.Font = options.font or Enum.Font.Gotham
	label.TextSize = options.textSize or 18
	label.TextColor3 = options.textColor3 or Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = options.textStrokeTransparency or 0.4
	label.TextXAlignment = options.textXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = options.textYAlignment or Enum.TextYAlignment.Center
	label.TextWrapped = options.textWrapped == true
	label.Text = options.text or ""
	label.Parent = parent
	return label
end

local function makeFrame(parent, options)
	local frame = Instance.new("Frame")
	frame.Name = options.name
	frame.AnchorPoint = options.anchorPoint or Vector2.new(0, 0)
	frame.Position = options.position
	frame.Size = options.size
	frame.BackgroundColor3 = options.backgroundColor3 or Color3.fromRGB(18, 18, 18)
	frame.BackgroundTransparency = options.backgroundTransparency or 0
	frame.BorderSizePixel = 0
	frame.Visible = options.visible ~= false
	frame.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = options.strokeColor or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = options.strokeThickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	return frame
end

local function makeButton(parent, options)
	local button = Instance.new("TextButton")
	button.Name = options.name
	button.AnchorPoint = options.anchorPoint or Vector2.new(0, 0)
	button.Position = options.position
	button.Size = options.size
	button.BackgroundColor3 = options.backgroundColor3 or Color3.fromRGB(255, 180, 82)
	button.BackgroundTransparency = options.backgroundTransparency or 0
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = options.font or Enum.Font.GothamBold
	button.TextSize = options.textSize or 20
	button.TextColor3 = options.textColor3 or Color3.fromRGB(17, 17, 17)
	button.Text = options.text or ""
	button.Visible = options.visible ~= false
	button.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = options.strokeColor or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	return button
end

local function buildHud(gui)
	gui:ClearAllChildren()

	local statusPanel = makeFrame(gui, {
		name = "StatusPanel",
		position = UDim2.new(0, 18, 0, 18),
		size = UDim2.new(0, 360, 0, 228),
		backgroundTransparency = 0.18,
	})

	local phaseLabel = makeLabel(statusPanel, {
		name = "PhaseLabel",
		position = UDim2.new(0, 16, 0, 12),
		size = UDim2.new(1, -32, 0, 28),
		font = Enum.Font.GothamBlack,
		textSize = 24,
		textColor3 = Color3.fromRGB(255, 196, 95),
		text = "ROUND STATUS",
	})

	local mapLabel = makeLabel(statusPanel, {
		name = "MapLabel",
		position = UDim2.new(0, 16, 0, 48),
		size = UDim2.new(1, -32, 0, 22),
		textSize = 17,
	})

	local timerLabel = makeLabel(statusPanel, {
		name = "TimerLabel",
		position = UDim2.new(0, 16, 0, 74),
		size = UDim2.new(1, -32, 0, 22),
		textSize = 17,
	})

	local keysLabel = makeLabel(statusPanel, {
		name = "KeysLabel",
		position = UDim2.new(0, 16, 0, 100),
		size = UDim2.new(1, -32, 0, 22),
		textSize = 17,
	})

	local gearsLabel = makeLabel(statusPanel, {
		name = "GearsLabel",
		position = UDim2.new(0, 16, 0, 126),
		size = UDim2.new(1, -32, 0, 22),
		textSize = 17,
	})

	local qualifyLabel = makeLabel(statusPanel, {
		name = "QualifyLabel",
		position = UDim2.new(0, 16, 0, 152),
		size = UDim2.new(1, -32, 0, 22),
		textSize = 17,
	})

	local doorLabel = makeLabel(statusPanel, {
		name = "DoorLabel",
		position = UDim2.new(0, 16, 0, 178),
		size = UDim2.new(1, -32, 0, 22),
		textSize = 17,
	})

	local messageLabel = makeLabel(statusPanel, {
		name = "MessageLabel",
		position = UDim2.new(0, 16, 0, 204),
		size = UDim2.new(1, -32, 0, 18),
		textSize = 14,
		textColor3 = Color3.fromRGB(244, 214, 142),
		textWrapped = true,
	})

	local spectateLabel = makeLabel(gui, {
		name = "SpectateLabel",
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 18),
		size = UDim2.new(0, 620, 0, 42),
		backgroundTransparency = 0.18,
		backgroundColor3 = Color3.fromRGB(18, 18, 18),
		font = Enum.Font.GothamBlack,
		textSize = 22,
		textColor3 = Color3.fromRGB(255, 196, 95),
		textXAlignment = Enum.TextXAlignment.Center,
		text = "",
	})

	local leaderboardFrame = makeFrame(gui, {
		name = "LeaderboardFrame",
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -18, 0, 18),
		size = UDim2.new(0, 360, 0, 278),
		backgroundTransparency = 0.14,
	})

	makeLabel(leaderboardFrame, {
		name = "LeaderboardTitle",
		position = UDim2.new(0, 16, 0, 12),
		size = UDim2.new(1, -32, 0, 28),
		font = Enum.Font.GothamBlack,
		textSize = 24,
		textColor3 = Color3.fromRGB(255, 196, 95),
		text = "LEADERBOARD",
	})

	local leaderboardRows = {}
	for index = 1, MAX_LEADERBOARD_ROWS do
		local row = makeFrame(leaderboardFrame, {
			name = ("Row%d"):format(index),
			position = UDim2.new(0, 14, 0, 44 + ((index - 1) * 28)),
			size = UDim2.new(1, -28, 0, 24),
			backgroundTransparency = 0.18,
			backgroundColor3 = Color3.fromRGB(36, 36, 36),
			strokeThickness = 1,
		})
		local rowLabel = makeLabel(row, {
			name = "Label",
			position = UDim2.new(0, 8, 0, 0),
			size = UDim2.new(1, -16, 1, 0),
			textSize = 15,
			text = "",
		})
		table.insert(leaderboardRows, {
			frame = row,
			label = rowLabel,
		})
	end

	makeLabel(leaderboardFrame, {
		name = "LeaderboardHint",
		position = UDim2.new(0, 16, 1, -30),
		size = UDim2.new(1, -32, 0, 18),
		textSize = 13,
		textColor3 = Color3.fromRGB(210, 210, 210),
		text = "Qualified players rank first by escape time.",
	})

	local resultsFrame = makeFrame(gui, {
		name = "ResultsFrame",
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.new(0.5, 0, 0.58, 0),
		size = UDim2.new(0, 620, 0, 300),
		backgroundTransparency = 0.08,
		visible = false,
	})

	local resultsTitle = makeLabel(resultsFrame, {
		name = "ResultsTitle",
		position = UDim2.new(0, 0, 0, 22),
		size = UDim2.new(1, 0, 0, 40),
		font = Enum.Font.GothamBlack,
		textSize = 36,
		textColor3 = Color3.fromRGB(255, 196, 95),
		textXAlignment = Enum.TextXAlignment.Center,
		text = "",
	})

	local resultsSubtitle = makeLabel(resultsFrame, {
		name = "ResultsSubtitle",
		position = UDim2.new(0, 24, 0, 82),
		size = UDim2.new(1, -48, 0, 34),
		font = Enum.Font.GothamBold,
		textSize = 24,
		textColor3 = Color3.fromRGB(255, 255, 255),
		textXAlignment = Enum.TextXAlignment.Center,
		text = "",
	})

	local resultsDetails = makeLabel(resultsFrame, {
		name = "ResultsDetails",
		position = UDim2.new(0, 24, 0, 126),
		size = UDim2.new(1, -48, 0, 56),
		textSize = 18,
		textColor3 = Color3.fromRGB(235, 241, 249),
		textXAlignment = Enum.TextXAlignment.Center,
		textWrapped = true,
		text = "",
	})

	local resultsFootnote = makeLabel(resultsFrame, {
		name = "ResultsFootnote",
		position = UDim2.new(0, 24, 0, 188),
		size = UDim2.new(1, -48, 0, 22),
		textSize = 15,
		textColor3 = Color3.fromRGB(255, 188, 102),
		textXAlignment = Enum.TextXAlignment.Center,
		textWrapped = true,
		text = "",
	})

	local returnButton = makeButton(resultsFrame, {
		name = "ReturnButton",
		position = UDim2.new(0.5, -196, 1, -74),
		size = UDim2.new(0, 180, 0, 44),
		backgroundColor3 = Color3.fromRGB(228, 228, 228),
		textColor3 = Color3.fromRGB(24, 24, 24),
		text = "Menu",
		visible = false,
	})

	local queueAgainButton = makeButton(resultsFrame, {
		name = "QueueAgainButton",
		position = UDim2.new(0.5, 16, 1, -74),
		size = UDim2.new(0, 180, 0, 44),
		backgroundColor3 = Color3.fromRGB(255, 188, 82),
		textColor3 = Color3.fromRGB(20, 20, 20),
		text = "Queue Again",
		visible = false,
	})

	return {
		gui = gui,
		statusPanel = statusPanel,
		phaseLabel = phaseLabel,
		mapLabel = mapLabel,
		timerLabel = timerLabel,
		keysLabel = keysLabel,
		gearsLabel = gearsLabel,
		qualifyLabel = qualifyLabel,
		doorLabel = doorLabel,
		messageLabel = messageLabel,
		spectateLabel = spectateLabel,
		leaderboardFrame = leaderboardFrame,
		leaderboardRows = leaderboardRows,
		resultsFrame = resultsFrame,
		resultsTitle = resultsTitle,
		resultsSubtitle = resultsSubtitle,
		resultsDetails = resultsDetails,
		resultsFootnote = resultsFootnote,
		returnButton = returnButton,
		queueAgainButton = queueAgainButton,
	}
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

local function readIntValue(parent, name)
	local node = parent and parent:FindFirstChild(name)
	if node and node:IsA("IntValue") then
		return node.Value
	end
	return 0
end

local function readNumberValue(parent, name)
	local node = parent and parent:FindFirstChild(name)
	if node and node:IsA("NumberValue") then
		return node.Value
	end
	return 0
end

local function readBoolValue(parent, name)
	local node = parent and parent:FindFirstChild(name)
	if node and node:IsA("BoolValue") then
		return node.Value
	end
	return false
end

local function readStringValue(parent, name)
	local node = parent and parent:FindFirstChild(name)
	if node and node:IsA("StringValue") then
		return node.Value
	end
	return ""
end

local function toDoorOpen(doorState)
	return string.lower(tostring(doorState or "")) == "open"
end

local function run()
	local gui = getOrCreateGui()
	local ui = buildHud(gui)

	local stateRoot = waitForChildTimeout(ReplicatedStorage, "State", 20, "HUD")
	local match = waitForChildTimeout(stateRoot, "Match", 20, "HUD")
	local progress = waitForChildTimeout(stateRoot, "Progress", 20, "HUD")
	local leaderboard = waitForChildTimeout(stateRoot, "Leaderboard", 20, "HUD")
	local presentation = waitForChildTimeout(stateRoot, "Presentation", 20, "HUD")
	local playerStateRoot = waitForChildTimeout(stateRoot, "PlayerState", 20, "HUD")
	local leaderboardEntriesFolder = waitForChildTimeout(leaderboard, "Entries", 20, "HUD")

	local spectate = {
		active = false,
		entryIndex = 1,
		targets = {},
	}
	local flowHidden = false
	local hiddenSessionId = nil
	local lastSessionId = ""
	local lastUpdateAt = 0

	local function readLeaderboardEntries()
		local entries = {}
		for _, child in ipairs(leaderboardEntriesFolder:GetChildren()) do
			if child:IsA("Folder") then
				table.insert(entries, {
					rank = readIntValue(child, "Rank"),
					userId = readIntValue(child, "UserId"),
					displayName = readStringValue(child, "DisplayName"),
					keys = readIntValue(child, "Keys"),
					gears = readIntValue(child, "Gears"),
					qualified = readBoolValue(child, "Qualified"),
					isOnline = readBoolValue(child, "IsOnline"),
				})
			end
		end
		table.sort(entries, function(a, b)
			return a.rank < b.rank
		end)
		return entries
	end

	local function readModel()
		local playerFolder = playerStateRoot:FindFirstChild(tostring(localPlayer.UserId))
		return {
			sessionId = readStringValue(match, "SessionId"),
			phase = readStringValue(match, "Phase"),
			phaseEndsAt = readNumberValue(match, "PhaseEndsServerTime"),
			currentMapName = readStringValue(match, "CurrentMapName"),
			requiredKeys = readIntValue(progress, "RequiredKeys"),
			qualifyCount = readIntValue(progress, "QualifyCount"),
			qualifiedCount = readIntValue(progress, "QualifiedCount"),
			doorState = readStringValue(progress, "DoorState"),
			presentationPrimary = readStringValue(presentation, "PrimaryText"),
			presentationSecondary = readStringValue(presentation, "SecondaryText"),
			presentationMessage = readStringValue(presentation, "Message"),
			keys = readIntValue(playerFolder, "Keys"),
			gears = readIntValue(playerFolder, "Gears"),
			qualified = readBoolValue(playerFolder, "Qualified"),
			placement = readIntValue(playerFolder, "Placement"),
			resultMode = readStringValue(playerFolder, "ResultMode"),
			lastRoundKeys = readIntValue(playerFolder, "LastRoundKeys"),
			lastRoundGears = readIntValue(playerFolder, "LastRoundGears"),
			leaderboardEntries = readLeaderboardEntries(),
		}
	end

	local function getSpectateTargets(entries)
		local targets = {}
		for _, entry in ipairs(entries or {}) do
			if entry.userId ~= localPlayer.UserId and entry.isOnline ~= false then
				table.insert(targets, entry)
			end
		end
		return targets
	end

	local function resolveSpectateSubject(entry)
		if entry then
			local player = Players:GetPlayerByUserId(entry.userId)
			local humanoid = getCharacterHumanoid(player)
			if humanoid then
				return humanoid, entry.displayName
			end
		end
		return getBotSpectateSubject()
	end

	local function stopSpectate()
		if not spectate.active then
			return
		end
		spectate.active = false
		spectate.entryIndex = 1
		spectate.targets = {}
		ui.spectateLabel.Visible = false
		restoreLocalCamera()
	end

	local function startSpectate(entries)
		spectate.targets = getSpectateTargets(entries)
		spectate.active = true
		if spectate.entryIndex > #spectate.targets then
			spectate.entryIndex = 1
		end
	end

	local function cycleSpectate(offset)
		if not spectate.active or #spectate.targets == 0 then
			return
		end
		spectate.entryIndex += offset
		if spectate.entryIndex < 1 then
			spectate.entryIndex = #spectate.targets
		elseif spectate.entryIndex > #spectate.targets then
			spectate.entryIndex = 1
		end
	end

	UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if gameProcessed or not spectate.active then
			return
		end
		if inputObject.KeyCode == Enum.KeyCode.Left then
			cycleSpectate(-1)
		elseif inputObject.KeyCode == Enum.KeyCode.Right then
			cycleSpectate(1)
		end
	end)

	ScreenFlowSignals.OnReturnToMenu(function()
		flowHidden = true
		hiddenSessionId = lastSessionId
		stopSpectate()
		ui.gui.Enabled = false
	end)

	ScreenFlowSignals.OnQueueAgain(function()
		flowHidden = true
		hiddenSessionId = lastSessionId
		stopSpectate()
		ui.gui.Enabled = false
	end)

	ui.returnButton.MouseButton1Click:Connect(function()
		ScreenFlowSignals.FireReturnToMenu()
	end)

	ui.queueAgainButton.MouseButton1Click:Connect(function()
		ScreenFlowSignals.FireQueueAgain()
	end)

	local function applyLeaderboard(entries)
		ui.leaderboardFrame.Visible = #entries > 0 and lastSessionId ~= ""
		for index = 1, MAX_LEADERBOARD_ROWS do
			local row = ui.leaderboardRows[index]
			local entry = entries[index]
			if entry then
				local suffix = entry.qualified and "QUAL" or ("%dK %dG"):format(entry.keys, entry.gears)
				row.label.Text = ("#%d  %s  |  %s"):format(entry.rank, entry.displayName, suffix)
				if entry.userId == localPlayer.UserId then
					row.frame.BackgroundColor3 = Color3.fromRGB(76, 54, 18)
					row.label.TextColor3 = Color3.fromRGB(255, 226, 164)
				elseif entry.qualified then
					row.frame.BackgroundColor3 = Color3.fromRGB(24, 64, 34)
					row.label.TextColor3 = Color3.fromRGB(143, 255, 171)
				else
					row.frame.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
					row.label.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
				row.frame.Visible = true
			else
				row.frame.Visible = false
			end
		end
	end

	local function applySpectate(model)
		if not model.qualified or model.phase ~= "Collectathon" or model.sessionId == "" then
			stopSpectate()
			return
		end
		if not spectate.active then
			startSpectate(model.leaderboardEntries)
		else
			spectate.targets = getSpectateTargets(model.leaderboardEntries)
			if spectate.entryIndex > math.max(1, #spectate.targets) then
				spectate.entryIndex = 1
			end
		end

		local targetEntry = spectate.targets[spectate.entryIndex]
		local subject, targetName = resolveSpectateSubject(targetEntry)
		if subject then
			applySpectateCamera(subject)
		end
		ui.spectateLabel.Visible = true
		ui.spectateLabel.Text = #spectate.targets > 0
			and ("SPECTATING %s  |  LEFT/RIGHT TO CYCLE"):format(targetName or "Target")
			or "SPECTATING TEMP BOT"
	end

	local function shouldShowResults(model)
		if model.resultMode == "none" then
			return false
		end
		if model.sessionId == "" then
			return true
		end
		return model.phase == "RoundResults" or model.phase == "NextRoundTransition" or model.phase == "WinnerCeremony"
	end

	local function applyResults(model)
		local visible = shouldShowResults(model)
		ui.resultsFrame.Visible = visible
		if not visible then
			ui.returnButton.Visible = false
			ui.queueAgainButton.Visible = false
			return
		end

		local title = "ROUND COMPLETE"
		local subtitle = model.presentationPrimary ~= "" and model.presentationPrimary or "Round complete"
		local details = ("Placement #%d  |  Keys %d  |  Gears %d"):format(
			math.max(1, model.placement),
			model.lastRoundKeys,
			model.lastRoundGears
		)
		local footnote = model.presentationMessage

		if model.resultMode == "winner" then
			title = "WINNER"
			subtitle = "You won the final round"
			if model.presentationPrimary ~= "" then
				footnote = model.presentationPrimary
			end
		elseif model.resultMode == "qualified" then
			title = "QUALIFIED"
			subtitle = "You advance to the next round"
			footnote = model.presentationMessage ~= "" and model.presentationMessage or "Stay ready for the next lobby."
		elseif model.resultMode == "eliminated" then
			title = "ELIMINATED"
			subtitle = "You did not qualify"
			footnote = model.presentationMessage ~= "" and model.presentationMessage or "Return to menu or queue for another run."
		end

		ui.resultsTitle.Text = title
		ui.resultsSubtitle.Text = subtitle
		ui.resultsDetails.Text = details
		ui.resultsFootnote.Text = footnote

		local allowPostgameActions = model.resultMode == "eliminated" or (model.resultMode == "winner" and model.sessionId == "")
		ui.returnButton.Visible = allowPostgameActions
		ui.queueAgainButton.Visible = allowPostgameActions
	end

	local function applyStatus(model)
		local sessionActive = model.sessionId ~= ""
		ui.statusPanel.Visible = sessionActive
		ui.phaseLabel.Text = model.presentationPrimary ~= "" and model.presentationPrimary or string.upper(model.phase)
		ui.mapLabel.Text = ("Map: %s"):format(model.currentMapName ~= "" and model.currentMapName or "TBD")
		ui.timerLabel.Text = ("Timer: %s"):format(formatTime(model.phaseEndsAt - os.clock()))
		ui.keysLabel.Text = ("Keys: %d / %d"):format(model.keys, model.requiredKeys)
		ui.gearsLabel.Text = ("Gears: %d"):format(model.gears)
		ui.qualifyLabel.Text = ("Qualified: %d / %d"):format(model.qualifiedCount, model.qualifyCount)
		ui.doorLabel.Text = ("Door: %s"):format(toDoorOpen(model.doorState) and "OPEN" or "CLOSED")
		ui.doorLabel.TextColor3 = toDoorOpen(model.doorState)
			and Color3.fromRGB(112, 255, 118)
			or Color3.fromRGB(255, 128, 128)
		ui.messageLabel.Text = model.presentationMessage ~= "" and model.presentationMessage or model.presentationSecondary
	end

	RunService.RenderStepped:Connect(function()
		if os.clock() - lastUpdateAt < UPDATE_INTERVAL_SECONDS then
			return
		end
		lastUpdateAt = os.clock()

		local model = readModel()
		if flowHidden and model.sessionId ~= "" and model.sessionId ~= hiddenSessionId then
			flowHidden = false
			hiddenSessionId = nil
		end
		lastSessionId = model.sessionId
		ui.gui.Enabled = not flowHidden
		if not ui.gui.Enabled then
			return
		end

		applyStatus(model)
		applyLeaderboard(model.leaderboardEntries)
		applySpectate(model)
		applyResults(model)
	end)
end

local ok, err = pcall(run)
if not ok then
	warn(("[InRoundHUD] Failed to initialize: %s"):format(tostring(err)))
end
