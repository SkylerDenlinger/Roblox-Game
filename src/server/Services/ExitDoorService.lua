local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PhysicsService=game:GetService("PhysicsService")
local StateContract = require(script.Parent:WaitForChild("StateContract"))
local RoundEvents=require(script.Parent:WaitForChild("RoundEvents"))
local ExitDoorService={}
local DOOR_GROUP="ExitDoor"
local PASS_GROUP="DoorPass"
local qualified={}
local keyConns={}
local charConns={}
local doorPart=nil
local enabled=false
local CLOSED_COLOR=Color3.fromRGB(0,170,255)
local OPEN_COLOR=Color3.fromRGB(0,255,0)
local function ensureGroups()
	pcall(function() PhysicsService:RegisterCollisionGroup(DOOR_GROUP) end)
	pcall(function() PhysicsService:RegisterCollisionGroup(PASS_GROUP) end)
	PhysicsService:CollisionGroupSetCollidable(DOOR_GROUP,PASS_GROUP,false)
end
local function setCharacterGroup(character,groupName)
	for _,d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup=groupName
		end
	end
end
local function getKeysValue(player)
	local refs=StateContract.Get()
	local pf=refs.PlayerState:FindFirstChild(tostring(player.UserId))
	if not pf then return nil end
	return pf:FindFirstChild("Keys")
end
local function getRequiredKeys()
	local refs=StateContract.Get()
	return refs.Progress.RequiredKeys.Value
end
local function grant(player)
	if qualified[player.UserId] then return end
	qualified[player.UserId]=true
	if player.Character then
		setCharacterGroup(player.Character,PASS_GROUP)
	end
	if doorPart then
		doorPart.Color=OPEN_COLOR
	end
	RoundEvents.FirePlayerQualified(player.UserId)
end
local function revoke(player)
	qualified[player.UserId]=nil
	if player.Character then
		setCharacterGroup(player.Character,"Default")
	end
end
local function evaluate(player)
	if not enabled then return end
	if qualified[player.UserId] then return end
	local keysVal=getKeysValue(player)
	if not keysVal then return end
	if keysVal.Value>=getRequiredKeys() then
		grant(player)
	end
end
local function wirePlayer(player)
	if keyConns[player] then keyConns[player]:Disconnect() end
	local keysVal=getKeysValue(player)
	if not keysVal then return end
	keyConns[player]=keysVal.Changed:Connect(function()
		evaluate(player)
	end)
	if charConns[player] then charConns[player]:Disconnect() end
	charConns[player]=player.CharacterAdded:Connect(function(character)
		if qualified[player.UserId] then
			setCharacterGroup(character,PASS_GROUP)
		else
			setCharacterGroup(character,"Default")
		end
	end)
	evaluate(player)
end
function ExitDoorService.SetEnabled(on)
	enabled=on and true or false
	if enabled then
		for _,p in ipairs(Players:GetPlayers()) do
			wirePlayer(p)
		end
	end
end
function ExitDoorService.ResetForNewRound()
	enabled=false
	for _,p in ipairs(Players:GetPlayers()) do
		revoke(p)
	end
	for plr,conn in pairs(keyConns) do
		conn:Disconnect()
		keyConns[plr]=nil
	end
	for plr,conn in pairs(charConns) do
		conn:Disconnect()
		charConns[plr]=nil
	end
	if doorPart then
		doorPart.Color=CLOSED_COLOR
		doorPart.CanCollide=true
	end
end
function ExitDoorService.BindDoor(part)
	ensureGroups()
	doorPart=part
	doorPart.CanTouch=true
	doorPart.CanCollide=true
	doorPart.Color=CLOSED_COLOR
	doorPart.CollisionGroup=DOOR_GROUP
	Players.PlayerAdded:Connect(function(player)
		if enabled then
			wirePlayer(player)
		end
	end)
	for _,player in ipairs(Players:GetPlayers()) do
		if enabled then
			wirePlayer(player)
		end
	end
end
return ExitDoorService
