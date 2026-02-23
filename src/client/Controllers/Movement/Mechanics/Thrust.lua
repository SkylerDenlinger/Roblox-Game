-- Mechanics/Thrust.lua
local Thrust={}
function Thrust:Get(ctx)
	local s=ctx.ThrustSpeed or 0
	if s<=0 then
		return Vector3.zero,nil
	end
	return ctx.Forward*s,nil
end
return Thrust
