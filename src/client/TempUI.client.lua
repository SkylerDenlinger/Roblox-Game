local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function waitForChildTimeout(parent, name, timeoutSeconds)
	local t0 = os.clock()
	local child = parent:FindFirstChild(name)
	while not child do
		if os.clock() - t0 >= timeoutSeconds then
			error(("HUD timed out waiting for '%s' under %s"):format(name, parent:GetFullName()))
		end
		child = parent:FindFirstChild(name)
		task.wait(0.05)
	end
	return child
end

local function getOrCreateScreenGui()
	local playerGui = waitForChildTimeout(Players.LocalPlayer, "PlayerGui", 5)
	local existing = playerGui:FindFirstChild("DebugHUD")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui
	return gui
end

local function newLabel(parent, name, yOffset)
	local lbl = parent:FindFirstChild(name)
	if lbl and lbl:IsA("TextLabel") then
		return lbl
	end
	if lbl then
		lbl:Destroy()
	end
	lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.AnchorPoint = Vector2.new(0, 0)
	lbl.Position = UDim2.new(0, 12, 0, 12 + yOffset)
	lbl.Size = UDim2.new(0, 360, 0, 22)
	lbl.BackgroundTransparency = 0.35
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 16
	lbl.Text = name .. ": ..."
	lbl.Parent = parent
	return lbl
end

local function formatTime(seconds)
	if seconds < 0 then seconds = 0 end
	local s = math.floor(seconds + 0.5)
	local m = math.floor(s / 60)
	s = s % 60
	if m > 0 then
		return tostring(m) .. ":" .. string.format("%02d", s)
	end
	return tostring(s)
end

local gui = getOrCreateScreenGui()
local phaseLbl = newLabel(gui, "PhaseLabel", 0)
local timerLbl = newLabel(gui, "TimerLabel", 26)
local keysLbl = newLabel(gui, "KeysLabel", 52)
local qualifyLbl = newLabel(gui, "QualifyLabel", 78)
local doorLbl = newLabel(gui, "DoorLabel", 104)

local stateRoot = waitForChildTimeout(ReplicatedStorage, "State", 5)
local match = waitForChildTimeout(stateRoot, "Match", 5)
local progress = waitForChildTimeout(stateRoot, "Progress", 5)

local phase = waitForChildTimeout(match, "Phase", 5)
local phaseEnds = waitForChildTimeout(match, "PhaseEndsServerTime", 5)
local timerVersion = waitForChildTimeout(match, "TimerVersion", 5)

local requiredKeys = waitForChildTimeout(progress, "RequiredKeys", 5)
local qualifyCount = waitForChildTimeout(progress, "QualifyCount", 5)
local qualifiedCount = waitForChildTimeout(progress, "QualifiedCount", 5)
local doorState = waitForChildTimeout(progress, "DoorState", 5)

local function refreshStatic()
	phaseLbl.Text = "Phase: " .. tostring(phase.Value)
	keysLbl.Text = "RequiredKeys: " .. tostring(requiredKeys.Value)
	qualifyLbl.Text = "Qualified: " .. tostring(qualifiedCount.Value) .. " / " .. tostring(qualifyCount.Value)
	doorLbl.Text = "DoorState: " .. tostring(doorState.Value)
end

phase.Changed:Connect(refreshStatic)
requiredKeys.Changed:Connect(refreshStatic)
qualifiedCount.Changed:Connect(refreshStatic)
qualifyCount.Changed:Connect(refreshStatic)
doorState.Changed:Connect(refreshStatic)
timerVersion.Changed:Connect(function()
	timerLbl.Text = "Timer: " .. formatTime(phaseEnds.Value - os.clock())
end)

RunService.RenderStepped:Connect(function()
	timerLbl.Text = "Timer: " .. formatTime(phaseEnds.Value - os.clock())
end)

refreshStatic()
