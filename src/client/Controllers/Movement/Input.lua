-- Input.lua
local UserInputService=game:GetService("UserInputService")
local Input={}
Input.__index=Input

function Input.new()
	local self=setmetatable({},Input)
	self.state={W=false,A=false,S=false,D=false}
	self.moveStick=Vector2.zero
	self.jumpPressed=false
	self.jumpHeld=false
	self.superJumpPressed=false
	self.bound=false
	return self
end

function Input:Bind()
	if self.bound then return end
	self.bound=true

	UserInputService.InputBegan:Connect(function(i,gpe)
		if gpe then return end

		-- Keyboard movement
		if i.KeyCode==Enum.KeyCode.W then self.state.W=true end
		if i.KeyCode==Enum.KeyCode.A then self.state.A=true end
		if i.KeyCode==Enum.KeyCode.S then self.state.S=true end
		if i.KeyCode==Enum.KeyCode.D then self.state.D=true end

		-- Jump (Space / Gamepad A)
		if i.KeyCode==Enum.KeyCode.Space or i.KeyCode==Enum.KeyCode.ButtonA then
			self.jumpPressed=true
			self.jumpHeld=true
		end

		-- Super jump (Up arrow / Gamepad Y)
		if i.KeyCode==Enum.KeyCode.Up or i.KeyCode==Enum.KeyCode.ButtonY then
			self.superJumpPressed=true
		end
	end)

	UserInputService.InputEnded:Connect(function(i,_)
		if i.KeyCode==Enum.KeyCode.W then self.state.W=false end
		if i.KeyCode==Enum.KeyCode.A then self.state.A=false end
		if i.KeyCode==Enum.KeyCode.S then self.state.S=false end
		if i.KeyCode==Enum.KeyCode.D then self.state.D=false end

		if i.KeyCode==Enum.KeyCode.Space or i.KeyCode==Enum.KeyCode.ButtonA then
			self.jumpHeld=false
		end
	end)

	-- Thumbstick movement
	UserInputService.InputChanged:Connect(function(i,_)
		if i.UserInputType==Enum.UserInputType.Gamepad1 and i.KeyCode==Enum.KeyCode.Thumbstick1 then
			self.moveStick=i.Position
		end
	end)
end

function Input:GetMoveVector()
	local x,z=0,0

	-- Keyboard
	if self.state.W then z+=1 end
	if self.state.S then z-=1 end
	if self.state.A then x-=1 end
	if self.state.D then x+=1 end

	-- Controller stick overrides keyboard if active
	if self.moveStick.Magnitude>0.1 then
		x=self.moveStick.X
		z=self.moveStick.Y
	end

	local v=Vector3.new(x,0,z)
	local m=math.clamp(v.Magnitude,0,1)
	return m>0 and v.Unit or Vector3.zero,m
end

function Input:GetJumpHeld()
	return self.jumpHeld
end

function Input:ConsumeJumpPressed()
	if self.jumpPressed then
		self.jumpPressed=false
		return true
	end
	return false
end

function Input:ConsumeSuperJumpPressed()
	if self.superJumpPressed then
		self.superJumpPressed=false
		return true
	end
	return false
end

return Input