local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PhysicsService=game:GetService("PhysicsService")
local StateContract=require(script.Parent:WaitForChild("StateContract"))

local ExitDoorService={}

local DOOR_GROUP="ExitDoor"
local PASS_GROUP="DoorPass"

local doorAccess={}
local keyConns={}
local charConns={}

local doorPart=nil
local enabled=false

local grantedCount=0

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

local function updateDoorVisuals()
	local refs=StateContract.Get()
	if grantedCount>0 then
		refs.Progress.DoorState.Value="Open"
		if doorPart then
			doorPart.Color=OPEN_COLOR
		end
	else
		refs.Progress.DoorState.Value="Closed"
		if doorPart then
			doorPart.Color=CLOSED_COLOR
		end
	end
end

local function grantDoorAccess(player)
	if doorAccess[player.UserId] then return end
	doorAccess[player.UserId]=true
	grantedCount+=1
	if player.Character then
		setCharacterGroup(player.Character,PASS_GROUP)
	end
	updateDoorVisuals()
end

local function revokeDoorAccess(player)
	if not doorAccess[player.UserId] then return end
	doorAccess[player.UserId]=nil
	grantedCount=math.max(0,grantedCount-1)
	if player.Character then
		setCharacterGroup(player.Character,"Default")
	end
	updateDoorVisuals()
end

local function evaluate(player)
	if not enabled then return end
	if doorAccess[player.UserId] then return end
	local keysVal=getKeysValue(player)
	if not keysVal then return end
	if keysVal.Value>=getRequiredKeys() then
		grantDoorAccess(player)
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
		if doorAccess[player.UserId] then
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
		revokeDoorAccess(p)
	end
	for plr,conn in pairs(keyConns) do
		conn:Disconnect()
		keyConns[plr]=nil
	end
	for plr,conn in pairs(charConns) do
		conn:Disconnect()
		charConns[plr]=nil
	end
	grantedCount=0
	if doorPart then
		doorPart.Color=CLOSED_COLOR
		doorPart.CanCollide=true
	end
	local refs=StateContract.Get()
	refs.Progress.DoorState.Value="Closed"
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
