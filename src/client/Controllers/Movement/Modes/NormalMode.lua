-- Modes/NormalMode.lua
local NormalMode={}
function NormalMode:Enter(ctx)
	if ctx.Controls then ctx.Controls:Enable() end
	if ctx.Humanoid then
		ctx.Humanoid.AutoRotate=true
		ctx.Humanoid.WalkSpeed=ctx.Config.NormalWalkSpeed or 16
	end
end
function NormalMode:Exit(ctx) end
return NormalMode
