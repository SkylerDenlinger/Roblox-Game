-- Modes/ThrustMode.lua
local RunService=game:GetService("RunService")
local ThrustMode={}

local function scaleAllAnimationTracks(humanoid,scale)
	local animator=humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:AdjustSpeed(scale)
	end
end

local function disconnectStateConns(state)
	if not state then return end
	if state.ThrustAnimConn then state.ThrustAnimConn:Disconnect() state.ThrustAnimConn=nil end
	if state.ThrustRunConn then state.ThrustRunConn:Disconnect() state.ThrustRunConn=nil end
	if state.ThrustHBConn then state.ThrustHBConn:Disconnect() state.ThrustHBConn=nil end
end

function ThrustMode:Enter(ctx)
	if ctx.Controls then ctx.Controls:Disable() end
	if ctx.Humanoid then
		ctx.Humanoid.WalkSpeed=0
		ctx.Humanoid.AutoRotate=false
	end

	local humanoid=ctx.Humanoid
	local animator=humanoid and humanoid:FindFirstChildOfClass("Animator")
	local state=ctx.State
	local speed=(ctx.Config and ctx.Config.ThrustAnimationSpeed) or 0.5

	if state then
		disconnectStateConns(state)
		state.ThrustAnimSpeed=speed
	end

	scaleAllAnimationTracks(humanoid,speed)

	if animator and state then
		state.ThrustAnimConn=animator.AnimationPlayed:Connect(function(track)
			track:AdjustSpeed(speed)
		end)
	end

	if humanoid and state then
		state.ThrustRunConn=humanoid.Running:Connect(function(_)
			-- Animate adjusts speed inside Running; re-apply AFTER it does.
			task.defer(function()
				scaleAllAnimationTracks(humanoid,speed)
			end)
		end)
	end

	-- Light enforcer: correct any overrides while thrusting
	if state then
		local acc=0
		state.ThrustHBConn=RunService.Heartbeat:Connect(function(dt)
			acc=acc+dt
			if acc>=0.08 then
				acc=0
				scaleAllAnimationTracks(humanoid,speed)
			end
		end)
	end
end

function ThrustMode:Exit(ctx)
	if ctx.State then
		disconnectStateConns(ctx.State)
		ctx.State.ThrustAnimSpeed=nil
	end
	scaleAllAnimationTracks(ctx.Humanoid,1)
end

return ThrustMode
