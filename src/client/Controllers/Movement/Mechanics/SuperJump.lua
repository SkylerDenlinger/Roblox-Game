-- Mechanics/SuperJump.lua
local SuperJump={}

local function getThrustSpeedForLevel(cfg,level)
	local speeds=cfg and cfg.ThrustLevels and cfg.ThrustLevels.SpeedByLevel
	if not speeds then return 0 end
	local speed=speeds[level]
	if type(speed)=="number" then
		return speed
	end
	return 0
end

local function getSuperJumpForce(ctx)
	local baseForce=ctx.Config.SuperJumpForce or 100
	if not ctx.Config.SuperJumpScalesWithThrust then
		return baseForce
	end

	local referenceLevel=ctx.Config.SuperJumpReferenceThrustLevel or 5
	local referenceThrust=getThrustSpeedForLevel(ctx.Config,referenceLevel)
	if referenceThrust<=0 then
		return baseForce
	end

	local thrustSpeed=math.max(ctx.ThrustSpeed or 0,0)
	local ratio=thrustSpeed/referenceThrust
	local flatten=math.clamp(ctx.Config.SuperJumpScaleFlatten or 0.4,0,1)
	local scale=1+((ratio-1)*flatten)
	if scale<0 then scale=0 end
	return baseForce*scale
end

function SuperJump:Apply(v,ctx)
	if not ctx.SuperJumpPressed then return v end
	if not ctx.Grounded then return v end
	local sj=getSuperJumpForce(ctx)
	if sj<=0 then return v end
	ctx.JumpApplied=true
	return Vector3.new(v.X,sj,v.Z)
end
return SuperJump
