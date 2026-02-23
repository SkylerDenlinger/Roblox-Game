-- Mechanics/GroundSnap.lua
local GroundSnap={}
function GroundSnap:Apply(v,ctx)
	if not ctx.Grounded then return v end
	if ctx.JumpApplied then return v end
	if v.Y<0 then
		return Vector3.new(v.X,0,v.Z)
	end
	return v
end
return GroundSnap
