local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

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

local stateRoot = waitForChildTimeout(ReplicatedStorage, "State", 5)
local match = waitForChildTimeout(stateRoot, "Match", 5)
local progress = waitForChildTimeout(stateRoot, "Progress", 5)

local phase = waitForChildTimeout(match, "Phase", 5)
local phaseEnds = waitForChildTimeout(match, "PhaseEndsServerTime", 5)
local phaseDuration = waitForChildTimeout(match, "PhaseDuration", 5)
local timerVersion = waitForChildTimeout(match, "TimerVersion", 5)

local requiredKeys = waitForChildTimeout(progress, "RequiredKeys", 5)
local qualifyCount = waitForChildTimeout(progress, "QualifyCount", 5)
local qualifiedCount = waitForChildTimeout(progress, "QualifiedCount", 5)
local doorState = waitForChildTimeout(progress, "DoorState", 5)

-- OPTIONAL: if you track player keys in PlayerState/<UserId>/Keys
local function getLocalPlayerKeysValue()
	local ps = stateRoot:FindFirstChild("PlayerState")
	if not ps then return nil end
	local me = Players.LocalPlayer
	if not me then return nil end
	local pf = ps:FindFirstChild(tostring(me.UserId))
	if not pf then return nil end
	return pf:FindFirstChild("Keys")
end

-- Replace these stubs with your real UI writes.
local function setPhaseText(_txt) end
local function setTimerText(_txt) end
local function setKeysText(_txt) end
local function setQualifyText(_txt) end
local function setDoorText(_txt) end

local function refreshStatic()
	setPhaseText(phase.Value)
	setKeysText(tostring(requiredKeys.Value))
	setQualifyText(tostring(qualifiedCount.Value) .. "/" .. tostring(qualifyCount.Value))
	setDoorText(doorState.Value)
end

phase.Changed:Connect(function()
	setPhaseText(phase.Value)
end)

requiredKeys.Changed:Connect(function()
	setKeysText(tostring(requiredKeys.Value))
end)

qualifiedCount.Changed:Connect(function()
	setQualifyText(tostring(qualifiedCount.Value) .. "/" .. tostring(qualifyCount.Value))
end)

qualifyCount.Changed:Connect(function()
	setQualifyText(tostring(qualifiedCount.Value) .. "/" .. tostring(qualifyCount.Value))
end)

doorState.Changed:Connect(function()
	setDoorText(doorState.Value)
end)

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

RunService.RenderStepped:Connect(function()
	local remaining = phaseEnds.Value - os.clock()
	setTimerText(formatTime(remaining))
end)

timerVersion.Changed:Connect(function()
	-- Forces any UI that depends on timer resets to update immediately
	local remaining = phaseEnds.Value - os.clock()
	setTimerText(formatTime(remaining))
end)

refreshStatic()

-- Optional local player keys binding (if you show it)
local keysVal = getLocalPlayerKeysValue()
if keysVal then
	keysVal.Changed:Connect(function()
		-- If you have a "my keys" UI label, update it here
	end)
end
