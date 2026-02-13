local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateContract = require(ReplicatedStorage:WaitForChild("State"):WaitForChild("StateContract"))
local RoundEvents = require(script.Parent:WaitForChild("RoundEvents"))

local ExitDoorService = {}

local touchCooldown = {}

local function getPlayerFromHit(hit)
	if not hit then return nil end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function getKeysForPlayer(player)
	local refs = StateContract.Get()
	local pf = refs.PlayerState:FindFirstChild(tostring(player.UserId))
	if not pf then return nil end
	return pf:FindFirstChild("Keys")
end

local function isCollectathon()
	local refs = StateContract.Get()
	return refs.Match.Phase.Value == "Collectathon"
end

function ExitDoorService.BindDoor(part)
	part.CanTouch = true

	part.Touched:Connect(function(hit)
		if not isCollectathon() then return end

		local player = getPlayerFromHit(hit)
		if not player then return end

		local now = os.clock()
		local last = touchCooldown[player.UserId] or 0
		if now - last < 1 then return end
		touchCooldown[player.UserId] = now

		local refs = StateContract.Get()
		local required = refs.Progress.RequiredKeys.Value

		local keysVal = getKeysForPlayer(player)
		if not keysVal then return end

		if keysVal.Value >= required then
			RoundEvents.FirePlayerQualified(player.UserId)
		end
	end)
end

return ExitDoorService
