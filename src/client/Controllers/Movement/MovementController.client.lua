-- MovementController.client.lua
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
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
local input=Input.new(Config)
local lastToggle=0
local TOGGLE_COOLDOWN=0.25
local gearsValue=nil
local thrustLabel=nil
local setMode

local function ensureThrustLabel()
	if thrustLabel and thrustLabel.Parent then
		return thrustLabel
	end

	local playerGui=player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	local gui=playerGui:FindFirstChild("ThrustDebugHUD")
	if gui and (not gui:IsA("ScreenGui")) then
		gui:Destroy()
		gui=nil
	end
	if not gui then
		gui=Instance.new("ScreenGui")
		gui.Name="ThrustDebugHUD"
		gui.ResetOnSpawn=false
		gui.IgnoreGuiInset=false
		gui.Parent=playerGui
	end

	local lbl=gui:FindFirstChild("ThrustLabel")
	if lbl and (not lbl:IsA("TextLabel")) then
		lbl:Destroy()
		lbl=nil
	end
	if not lbl then
		lbl=Instance.new("TextLabel")
		lbl.Name="ThrustLabel"
		lbl.AnchorPoint=Vector2.new(1,0)
		lbl.Position=UDim2.new(1,-12,0,12)
		lbl.Size=UDim2.new(0,350,0,24)
		lbl.BackgroundTransparency=0.35
		lbl.TextXAlignment=Enum.TextXAlignment.Right
		lbl.Font=Enum.Font.Gotham
		lbl.TextSize=15
		lbl.TextColor3=Color3.new(1,1,1)
		lbl.TextStrokeTransparency=0.7
		lbl.Parent=gui
	end

	thrustLabel=lbl
	return thrustLabel
end

local function updateThrustLabel(currentSpeed)
	local lbl=ensureThrustLabel()
	if not lbl then return end

	local level=State.ThrustLevel or 0
	local unlocked=State.ThrustUnlockedLevel or 0
	local gears=(gearsValue and gearsValue.Parent and gearsValue.Value) or 0
	lbl.Text=string.format(
		"Thrust Lvl: %d/%d | Speed: %.1f | Gears: %d",
		level,
		unlocked,
		currentSpeed or 0,
		gears
	)
end
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
local function getThrustConfig()
	local tc=Config.ThrustLevels or {}
	local minLevel=tc.MinLevel or 0
	local maxLevel=tc.MaxLevel or 7
	if maxLevel<minLevel then
		maxLevel=minLevel
	end
	return tc,minLevel,maxLevel
end

local function getPlayerGearsValue()
	if gearsValue and gearsValue.Parent then
		return gearsValue
	end

	local stateCfg=Config.ThrustGearState or {}
	local stateRoot=ReplicatedStorage:FindFirstChild(stateCfg.StateRootName or "State")
	if not stateRoot then return nil end
	local playerState=stateRoot:FindFirstChild(stateCfg.PlayerStateFolderName or "PlayerState")
	if not playerState then return nil end
	local playerFolder=playerState:FindFirstChild(tostring(player.UserId))
	if not playerFolder then return nil end
	local v=playerFolder:FindFirstChild(stateCfg.GearsValueName or "Gears")
	if v and v:IsA("IntValue") then
		gearsValue=v
		return gearsValue
	end
	return nil
end

local function getUnlockedThrustLevel(minLevel,maxLevel)
	local stateCfg=Config.ThrustGearState or {}
	local debugGears=stateCfg.DebugOverrideGears
	if debugGears~=nil then
		return math.clamp(math.floor(debugGears),minLevel,maxLevel)
	end

	local gears=getPlayerGearsValue()
	if not gears then
		return minLevel
	end
	return math.clamp(math.floor(gears.Value),minLevel,maxLevel)
end

local function getThrustSpeedForLevel(level)
	local tc=getThrustConfig()
	local speedByLevel=tc and tc.SpeedByLevel
	if speedByLevel and speedByLevel[level]~=nil then
		return speedByLevel[level]
	end
	if level<=0 then
		return 0
	end
	return 0
end

local function getTurnResponsivenessForThrustSpeed(thrustSpeed)
	local turnCfg=Config.ThrustTurnScaling
	if not turnCfg or not turnCfg.Enabled then
		return Config.TurnResponsiveness or 8
	end

	local maxResp=turnCfg.MaxResponsiveness or (Config.TurnResponsiveness or 8)
	local minResp=turnCfg.MinResponsiveness or maxResp
	if minResp>maxResp then
		minResp,maxResp=maxResp,minResp
	end

	local tc=Config.ThrustLevels or {}
	local speedByLevel=tc.SpeedByLevel or {}
	local minNonZero=nil
	local maxSpeed=0
	for level,speed in pairs(speedByLevel) do
		if type(level)=="number" and type(speed)=="number" and level>0 and speed>0 then
			if (not minNonZero) or speed<minNonZero then
				minNonZero=speed
			end
			if speed>maxSpeed then
				maxSpeed=speed
			end
		end
	end

	if thrustSpeed<=0 or (not minNonZero) or maxSpeed<=minNonZero then
		return maxResp
	end

	local t=math.clamp((thrustSpeed-minNonZero)/(maxSpeed-minNonZero),0,1)
	return maxResp+(minResp-maxResp)*t
end

local function updateThrustLevel(consumeActions)
	local tc,minLevel,maxLevel=getThrustConfig()
	local unlocked=getUnlockedThrustLevel(minLevel,maxLevel)
	local prevUnlocked=State.ThrustUnlockedLevel or minLevel
	State.ThrustUnlockedLevel=unlocked

	local startLevel=tc.StartLevel or 1
	local prevLevel=State.ThrustLevel
	local changedByInput=false
	if State.ThrustLevel==nil then
		State.ThrustLevel=startLevel
	elseif prevUnlocked<=minLevel and unlocked>minLevel and State.ThrustLevel==minLevel then
		State.ThrustLevel=startLevel
	end

	if consumeActions then
		if input:ConsumeThrustDownPressed() then
			State.ThrustLevel=State.ThrustLevel-1
			changedByInput=true
		end
		if input:ConsumeThrustUpPressed() then
			State.ThrustLevel=State.ThrustLevel+1
			changedByInput=true
		end
	end

	State.ThrustLevel=math.clamp(State.ThrustLevel,minLevel,unlocked)
	local currentLevel=State.ThrustLevel or minLevel
	local previousLevel=prevLevel
	if previousLevel==nil then
		previousLevel=currentLevel
	end
	return previousLevel,currentLevel,changedByInput
end

local function applyAutoThrustModeSwitch()
	if not Config.UseThrustLevelSystem then return end

	local previousLevel,currentLevel,changedByInput=updateThrustLevel(true)
	if not changedByInput then
		return
	end

	if previousLevel>0 and currentLevel<=0 and State.Mode=="Thrust" then
		setMode("Normal")
		return
	end

	if previousLevel<=0 and currentLevel>0 and State.Mode=="Normal" then
		setMode("Thrust")
	end
end

local function getThrustSpeed(consumeActions)
	if Config.UseThrustLevelSystem then
		updateThrustLevel(consumeActions)
		return getThrustSpeedForLevel(State.ThrustLevel or 0)
	end
	if Config.ThrustOverride~=nil then
		return Config.ThrustOverride
	end
	if Config.UseServerThrustAttribute and character then
		return character:GetAttribute(Config.ServerThrustAttributeName) or 0
	end
	return 0
end
local function updateJumpRuntime(touchingGroundForJump)
	local coyoteFrames=Config.CoyoteFrames or math.floor(((Config.CoyoteTime or 0.25)*60)+0.5)
	if coyoteFrames<0 then coyoteFrames=0 end

	if touchingGroundForJump then
		State.CoyoteFramesRemaining=coyoteFrames
		State.CoyoteRemaining=coyoteFrames/60
		State.JumpGrounded=true
		if not State.WasGrounded then
			State.SingleJumpUsed=false
			State.DoubleJumpUsed=false
		end
	else
		if State.SingleJumpUsed then
			State.CoyoteFramesRemaining=0
		elseif State.WasGrounded then
			State.CoyoteFramesRemaining=coyoteFrames
		else
			State.CoyoteFramesRemaining=math.max((State.CoyoteFramesRemaining or 0)-1,0)
		end
		State.CoyoteRemaining=(State.CoyoteFramesRemaining or 0)/60
		State.JumpGrounded=(not State.SingleJumpUsed) and ((State.CoyoteFramesRemaining or 0)>0)
	end

	State.Grounded=State.JumpGrounded and true or false
	State.WasGrounded=touchingGroundForJump
end
local function buildCtx(dt,consumeActions)
	local localMove,localMag=input:GetMoveVector()
	local inputDir=localToWorldDir(localMove)
	local grounded=false
	if humanoid and humanoid.FloorMaterial~=Enum.Material.Air then
		grounded=true
	end
	local jumpGroundContact=grounded and root.AssemblyLinearVelocity.Y<=1
	updateJumpRuntime(jumpGroundContact)
	local f=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
	if f.Magnitude>0 then f=f.Unit else f=Vector3.new(0,0,-1) end
	local jumpPressed=false
	local superJumpPressed=false
	local jumpHeld=input:GetJumpHeld()
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
		Grounded=State.Grounded and true or false,
		TouchingGround=grounded,
		JumpGrounded=State.JumpGrounded and true or false,
		InputDir=inputDir,
		InputMag=localMag,
		Forward=f,
		JumpHeld=jumpHeld,
		JumpPressed=jumpPressed,
		SuperJumpPressed=superJumpPressed,
		ThrustSpeed=getThrustSpeed(consumeActions),
		JumpApplied=false,
		CoyoteRemaining=State.CoyoteRemaining or 0
	}
end
local function teardownThrust()
	if motor then
		motor:Destroy()
		motor=nil
	end
end
setMode=function(modeName)
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
	State.CoyoteRemaining=0
	State.CoyoteFramesRemaining=0
	State.JumpGrounded=true
	State.Grounded=true
	State.SingleJumpUsed=false
	State.DoubleJumpUsed=false
	State.JumpHoldRemaining=0
	State.JumpAutoHoldRemaining=0
	State.JumpHoldFrames=0
	State.JumpBoostActive=false
	State.JumpReleaseRequired=false
	State.WasGrounded=false
	State.ThrustLevel=nil
	State.ThrustUnlockedLevel=0
	gearsValue=nil
	ensureThrustLabel()
	updateThrustLabel(0)
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
	if inputObj.KeyCode~=(Config.KeyboardMouse and Config.KeyboardMouse.ToggleKey or Enum.KeyCode.F) then return end
	if gpe and UserInputService:GetFocusedTextBox() then return end
	toggleMode()
end)
RunService.Heartbeat:Connect(function(dt)
	if not character or not humanoid or not root then return end
	applyAutoThrustModeSwitch()
	if State.Mode~="Thrust" then
		updateThrustLabel(getThrustSpeed(false))
		return
	end
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
	motor:ApplyRotation(rotDir,dt,getTurnResponsivenessForThrustSpeed(ctx.ThrustSpeed))
	updateThrustLabel(ctx.ThrustSpeed)
end)
_G.ForceThrust=function()
	setMode("Thrust")
end
_G.ForceNormal=function()
	setMode("Normal")
end
