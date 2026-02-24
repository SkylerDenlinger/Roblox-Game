-- Mechanics/Jump.lua
local Jump={}

local function getJumpVelocityTargets(ctx)
	local jumpForce=ctx.Config.JumpForce or 50
	local maxVelocity=ctx.Config.JumpMaxVelocity or jumpForce
	local fullVelocity=math.min(jumpForce,maxVelocity)
	local tapRatio=ctx.Config.JumpTapHeightRatio or 0.5
	tapRatio=math.clamp(tapRatio,0,1)
	local tapVelocity=fullVelocity*tapRatio
	return tapVelocity,fullVelocity
end

local function getHeldFrames(state,ctx)
	state.JumpHoldFrames=(state.JumpHoldFrames or 0)+((ctx.DeltaTime or 0)*60)
	return state.JumpHoldFrames
end

local function getFrameDrivenTargetVelocity(state,ctx)
	local tapFrames=ctx.Config.JumpTapFrames or 5
	local fullFrames=ctx.Config.JumpFullFrames or 20
	if fullFrames<tapFrames then
		fullFrames=tapFrames
	end

	local heldFrames=getHeldFrames(state,ctx)
	local tapVelocity,fullVelocity=getJumpVelocityTargets(ctx)
	if heldFrames<=tapFrames then
		return tapVelocity,false
	end

	if fullFrames==tapFrames then
		return fullVelocity,true
	end

	if heldFrames>=fullFrames then
		return fullVelocity,true
	end

	local ratio=math.clamp((heldFrames-tapFrames)/(fullFrames-tapFrames),0,1)
	local easeOutPower=ctx.Config.JumpHoldEaseOutPower or 3
	if easeOutPower<1 then
		easeOutPower=1
	end
	local easedRatio=1-((1-ratio)^easeOutPower)
	return tapVelocity+((fullVelocity-tapVelocity)*easedRatio),false
end

local function beginJump(v,ctx,isSingleJump)
	local state=ctx.State
	local tapVelocity=getJumpVelocityTargets(ctx)
	state.JumpHoldFrames=0
	state.JumpBoostActive=true
	state.JumpHoldRemaining=0
	state.JumpAutoHoldRemaining=0
	state.JumpReleaseRequired=true
	if isSingleJump then
		state.SingleJumpUsed=true
		state.JumpGrounded=false
		state.CoyoteFramesRemaining=0
		state.CoyoteRemaining=0
	else
		state.DoubleJumpUsed=true
	end
	ctx.JumpApplied=true
	return Vector3.new(v.X,tapVelocity,v.Z)
end

function Jump:Apply(v,ctx)
	local state=ctx.State
	local jumpGrounded=ctx.JumpGrounded and true or false
	local allowDouble=(ctx.Config.MaxJumpCount or 2)>=2

	if state.JumpReleaseRequired and (not ctx.JumpHeld) then
		state.JumpReleaseRequired=false
	end

	if ctx.JumpPressed then
		if state.JumpReleaseRequired then
			return v
		end
		if jumpGrounded and (not state.SingleJumpUsed) then
			return beginJump(v,ctx,true)
		elseif allowDouble and (not jumpGrounded) and (not state.DoubleJumpUsed) then
			return beginJump(v,ctx,false)
		end
	end

	if state.JumpBoostActive then
		if not ctx.JumpHeld then
			state.JumpBoostActive=false
		elseif v.Y>0 then
			local targetY,boostComplete=getFrameDrivenTargetVelocity(state,ctx)
			if v.Y<targetY then
				v=Vector3.new(v.X,targetY,v.Z)
			end
			if boostComplete then
				state.JumpBoostActive=false
			end
		end
	end

	return v
end
return Jump
