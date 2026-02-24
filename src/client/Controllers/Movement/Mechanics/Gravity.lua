-- Mechanics/Gravity.lua
local Workspace=game:GetService("Workspace")
local Gravity={}
function Gravity:Apply(v,ctx)
	if ctx.TouchingGround then
		return v
	end
	local y=v.Y-Workspace.Gravity*ctx.DeltaTime
	local term=ctx.Config.TerminalVelocity or -120
	if y<term then y=term end
	return Vector3.new(v.X,y,v.Z)
end
return Gravity
