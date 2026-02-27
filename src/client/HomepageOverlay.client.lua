local Players = game:GetService("Players")

if _G.__HomeScreenBootstrapStarted then
	return
end
_G.__HomeScreenBootstrapStarted = true

local MAX_START_ATTEMPTS = 20
local RETRY_SECONDS = 0.5

local function locateMainModule()
	local homeFolder = script.Parent:FindFirstChild("HomeScreen")
	if homeFolder then
		local mainModule = homeFolder:FindFirstChild("Main")
		if mainModule and mainModule:IsA("ModuleScript") then
			return mainModule
		end
	end

	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local playerScripts = player:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return nil
	end
	local clientFolder = playerScripts:FindFirstChild("Client")
	if not clientFolder then
		return nil
	end
	local replicatedHomeFolder = clientFolder:FindFirstChild("HomeScreen")
	if not replicatedHomeFolder then
		return nil
	end
	local replicatedMain = replicatedHomeFolder:FindFirstChild("Main")
	if replicatedMain and replicatedMain:IsA("ModuleScript") then
		return replicatedMain
	end
	return nil
end

local function tryStartHomeScreen()
	local mainModule = locateMainModule()
	if not mainModule then
		return false, "HomeScreen/Main module not available yet."
	end

	local okRequire, homeScreenMain = pcall(require, mainModule)
	if not okRequire then
		return false, ("Failed to require HomeScreen.Main: %s"):format(tostring(homeScreenMain))
	end
	if type(homeScreenMain) ~= "table" or type(homeScreenMain.Start) ~= "function" then
		return false, "HomeScreen.Main does not export Start()."
	end

	local okStart, startErr = pcall(homeScreenMain.Start)
	if not okStart then
		return false, ("HomeScreenMain.Start failed: %s"):format(tostring(startErr))
	end

	return true
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

task.defer(function()
	for attempt = 1, MAX_START_ATTEMPTS do
		local ok, err = tryStartHomeScreen()
		if ok then
			return
		end
		warn(("[HomepageOverlay] Start attempt %d/%d failed: %s"):format(attempt, MAX_START_ATTEMPTS, tostring(err)))
		task.wait(RETRY_SECONDS)
	end
	warn("[HomepageOverlay] Failed to start HomeScreen after retries.")
end)