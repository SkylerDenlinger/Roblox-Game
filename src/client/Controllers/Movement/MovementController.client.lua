-- MovementController.client.lua
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local folder=script.Parent
local Config=require(folder.Config)
local State=require(folder.State)
local Input=require(folder.Input)
local Motor=require(folder.Motor)
local Clamp=require(folder.Clamp)
local Modes={
	Normal=require(folder.Modes.NormalMode),
	Thrust=require(folder.Modes.ThrustMode)
}
local Mechanics={
	require(folder.Mechanics.Steering),
	require(folder.Mechanics.Thrust),
	require(folder.Mechanics.Jump),
	require(folder.Mechanics.SuperJump),
	require(folder.Mechanics.Gravity),
	require(folder.Mechanics.GroundSnap)
}
local controls=nil
local character=nil
local humanoid=nil
local root=nil
local motor=nil
local input=Input.new()
local lastToggle=0
local TOGGLE_COOLDOWN=0.25
local function tryGetControls()
	local ok,ctrl=pcall(function()
		local ps=player:WaitForChild("PlayerScripts")
		local pm=ps:WaitForChild("PlayerModule")
		local mod=require(pm)
		return mod:GetControls()
	end)
	if ok then return ctrl end
	return nil
end
local function getCameraBasisXZ()
	local cam=Workspace.CurrentCamera
	if not cam then
		return Vector3.new(1,0,0),Vector3.new(0,0,-1)
	end
	local cf=cam.CFrame
	local right=Vector3.new(cf.RightVector.X,0,cf.RightVector.Z)
	local forward=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z)
	if right.Magnitude>0 then right=right.Unit else right=Vector3.new(1,0,0) end
	if forward.Magnitude>0 then forward=forward.Unit else forward=Vector3.new(0,0,-1) end
	return right,forward
end
local function localToWorldDir(localDir)
	if localDir.Magnitude<=0 then return Vector3.zero end
	local right,forward=getCameraBasisXZ()
	local world=(right*localDir.X+forward*localDir.Z)
	world=Vector3.new(world.X,0,world.Z)
	return world.Magnitude>0 and world.Unit or Vector3.zero
end
local function getThrustSpeed()
	if Config.ThrustOverride~=nil then
		return Config.ThrustOverride
	end
	if Config.UseServerThrustAttribute and character then
		return character:GetAttribute(Config.ServerThrustAttributeName) or 0
	end
	return 0
end
local function buildCtx(dt,consumeActions)
	local localMove,localMag=input:GetMoveVector()
	local inputDir=localToWorldDir(localMove)
	local grounded=false
	if humanoid and humanoid.FloorMaterial~=Enum.Material.Air then
		grounded=true
	end
	local f=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
	if f.Magnitude>0 then f=f.Unit else f=Vector3.new(0,0,-1) end
	local jumpPressed=false
	local superJumpPressed=false
	if consumeActions then
		jumpPressed=input:ConsumeJumpPressed()
		superJumpPressed=input:ConsumeSuperJumpPressed()
	end
	return {
		Player=player,
		Config=Config,
		State=State,
		Controls=controls,
		Character=character,
		Humanoid=humanoid,
		Root=root,
		Motor=motor,
		DeltaTime=dt,
		Grounded=grounded,
		InputDir=inputDir,
		InputMag=localMag,
		Forward=f,
		JumpPressed=jumpPressed,
		SuperJumpPressed=superJumpPressed,
		ThrustSpeed=getThrustSpeed(),
		JumpApplied=false
	}
end
local function teardownThrust()
	if motor then
		motor:Destroy()
		motor=nil
	end
end
local function setMode(modeName)
	if State.Mode==modeName then return end
	if character and humanoid and root then
		local ctxExit=buildCtx(0,false)
		if State.Mode=="Thrust" then
			Modes.Thrust:Exit(ctxExit)
			teardownThrust()
		elseif State.Mode=="Normal" then
			Modes.Normal:Exit(ctxExit)
		end
	end
	State.Mode=modeName
	if character and humanoid and root then
		if State.Mode=="Normal" then
			local ctxEnter=buildCtx(0,false)
			Modes.Normal:Enter(ctxEnter)
		else
			if not motor then
				motor=Motor.new(root,Config)
				motor:Ensure()
			end
			local ctxEnter=buildCtx(0,false)
			ctxEnter.Motor=motor
			Modes.Thrust:Enter(ctxEnter)
		end
	end
end
local function toggleMode()
	local now=os.clock()
	if now-lastToggle<TOGGLE_COOLDOWN then return end
	lastToggle=now
	if State.Mode=="Thrust" then
		setMode("Normal")
	else
		setMode("Thrust")
	end
end
local function bindCharacter(char)
	character=char
	humanoid=character:WaitForChild("Humanoid")
	root=character:WaitForChild("HumanoidRootPart")
	controls=controls or tryGetControls()
	input:Bind()
	teardownThrust()
	State.Mode="None"
	setMode("Normal")
end
if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)
UserInputService.InputBegan:Connect(function(inputObj,gpe)
	if inputObj.KeyCode~=Config.ToggleKey then return end
	if gpe and UserInputService:GetFocusedTextBox() then return end
	toggleMode()
end)
RunService.Heartbeat:Connect(function(dt)
	if not character or not humanoid or not root then return end
	if State.Mode~="Thrust" then return end
	if not motor then
		motor=Motor.new(root,Config)
		motor:Ensure()
	end
	local ctx=buildCtx(dt,true)
	ctx.Motor=motor
	local v=Vector3.new(0,root.AssemblyLinearVelocity.Y,0)
	local rotDir=nil
	for _,m in ipairs(Mechanics) do
		if m.Get then
			local add,rd=m:Get(ctx)
			if add then v=v+add end
			if (not rotDir) and rd then rotDir=rd end
		elseif m.Apply then
			v=m:Apply(v,ctx) or v
		end
	end
	v=Clamp:Apply(v,Config)
	motor:ApplyVelocity(v)
	motor:ApplyRotation(rotDir,dt)
end)
_G.ForceThrust=function()
	setMode("Thrust")
end
_G.ForceNormal=function()
	setMode("Normal")
end
