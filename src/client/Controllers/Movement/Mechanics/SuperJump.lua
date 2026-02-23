-- Mechanics/SuperJump.lua
local SuperJump={}
function SuperJump:Apply(v,ctx)
	if not ctx.SuperJumpPressed then return v end
	if not ctx.Grounded then return v end
	local sj=ctx.Config.SuperJumpForce or 100
	ctx.JumpApplied=true
	return Vector3.new(v.X,sj,v.Z)
end
return SuperJump
