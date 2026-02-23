-- Mechanics/Jump.lua
local Jump={}
function Jump:Apply(v,ctx)
	if not ctx.JumpPressed then return v end
	if not ctx.Grounded then return v end
	local jf=ctx.Config.JumpForce or 50
	ctx.JumpApplied=true
	return Vector3.new(v.X,jf,v.Z)
end
return Jump
