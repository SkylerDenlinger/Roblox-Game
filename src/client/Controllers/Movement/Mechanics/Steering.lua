-- Mechanics/Steering.lua
local Steering={}
function Steering:Get(ctx)
	if ctx.InputMag<=0 or ctx.InputDir.Magnitude<=0 then
		return Vector3.zero,nil
	end
	local sp=ctx.Config.ThrustInputSpeed or 16
	return ctx.InputDir*(sp*ctx.InputMag),ctx.InputDir
end
return Steering
