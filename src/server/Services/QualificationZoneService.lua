local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StateContract=require(script.Parent:WaitForChild("StateContract"))
local RoundEvents=require(script.Parent:WaitForChild("RoundEvents"))

local QualificationZoneService={}

local zonePart=nil
local touchCooldown={}
local TOUCH_CD=0.75

local function requireChild(parent,name)
	local c=parent:FindFirstChild(name)
	if not c then
		error(("QualificationZoneService missing '%s' under %s"):format(name,parent:GetFullName()))
	end
	return c
end

local function getPhase()
	local refs=StateContract.Get()
	local match=refs.Match
	local phase=requireChild(match,"Phase")
	return phase.Value
end

local function getProgress()
	return StateContract.Get().Progress
end

local function getPlayerFromHit(hit)
	if not hit then return nil end
	local character=hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function getKeysValue(player)
	local refs=StateContract.Get()
	local pf=refs.PlayerState:FindFirstChild(tostring(player.UserId))
	if not pf then return nil end
	return pf:FindFirstChild("Keys")
end

local function canQualifyNow(player)
	if getPhase()~="Collectathon" then return false end
	local progress=getProgress()
	local keysVal=getKeysValue(player)
	if not keysVal then return false end
	if keysVal.Value<progress.RequiredKeys.Value then return false end
	return true
end

local function tryQualify(player)
	if not canQualifyNow(player) then return end
	RoundEvents.FirePlayerQualified(player.UserId)
end

local function bindZone(part)
	zonePart=part
	zonePart.CanTouch=true
	zonePart.Touched:Connect(function(hit)
		if getPhase()~="Collectathon" then return end
		local player=getPlayerFromHit(hit)
		if not player then return end
		local now=os.clock()
		local last=touchCooldown[player.UserId] or 0
		if now-last<TOUCH_CD then return end
		touchCooldown[player.UserId]=now
		tryQualify(player)
	end)
end

function QualificationZoneService.BindZone(part)
	bindZone(part)
end

function QualificationZoneService.ResetForNewRound()
	touchCooldown={}
end

function QualificationZoneService.Start()
	local z=Workspace:FindFirstChild("QualificationZone")
	if not z or not z:IsA("BasePart") then
		warn("QualificationZoneService: QualificationZone not found in Workspace")
		return
	end
	bindZone(z)
end

return QualificationZoneService
