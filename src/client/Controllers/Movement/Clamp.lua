-- Clamp.lua
local Clamp={}
function Clamp:Apply(v,config)
	if not config.MaxTotalSpeed or config.MaxTotalSpeed<=0 then
		return v
	end
	local xz=Vector3.new(v.X,0,v.Z)
	local m=xz.Magnitude
	if m>config.MaxTotalSpeed then
		local c=xz.Unit*config.MaxTotalSpeed
		return Vector3.new(c.X,v.Y,c.Z)
	end
	return v
end
return Clamp
