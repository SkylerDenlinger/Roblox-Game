-- Input.lua
local UserInputService=game:GetService("UserInputService")
local Input={}
Input.__index=Input

function Input.new(config)
	local self=setmetatable({},Input)
	self.config=config or {}
	self.kbmConfig=self.config.KeyboardMouse or {}
	self.controllerConfig=self.config.Controller or {}
	self.state={W=false,A=false,S=false,D=false}
	self.moveStick=Vector2.zero
	self.jumpPressed=false
	self.jumpHeld=false
	self.superJumpPressed=false
	self.thrustDownPressed=false
	self.thrustUpPressed=false
	self.bound=false
	return self
end

function Input:Bind()
	if self.bound then return end
	self.bound=true

	UserInputService.InputBegan:Connect(function(i,gpe)
		if gpe then return end

		local keys=self.kbmConfig.MoveKeys or {}
		local jumpKeys=self.kbmConfig.JumpKeys or {}
		local superJumpKeys=self.kbmConfig.SuperJumpKeys or {}
		local thrustDownKeys=self.kbmConfig.ThrustDownKeys or {}
		local thrustUpKeys=self.kbmConfig.ThrustUpKeys or {}
		local controllerJumpKeys=self.controllerConfig.JumpKeys or {}
		local controllerSuperJumpKeys=self.controllerConfig.SuperJumpKeys or {}
		local controllerThrustDownKeys=self.controllerConfig.ThrustDownKeys or {}
		local controllerThrustUpKeys=self.controllerConfig.ThrustUpKeys or {}

		-- Keyboard movement
		if i.KeyCode==keys.Forward then self.state.W=true end
		if i.KeyCode==keys.Left then self.state.A=true end
		if i.KeyCode==keys.Back then self.state.S=true end
		if i.KeyCode==keys.Right then self.state.D=true end

		-- Jump (Space / Gamepad A)
		for _,k in ipairs(jumpKeys) do
			if i.KeyCode==k then
				self.jumpPressed=true
				self.jumpHeld=true
				break
			end
		end
		for _,k in ipairs(controllerJumpKeys) do
			if i.KeyCode==k then
				self.jumpPressed=true
				self.jumpHeld=true
				break
			end
		end

		-- Super jump (Up arrow / Gamepad Y)
		for _,k in ipairs(superJumpKeys) do
			if i.KeyCode==k then
				self.superJumpPressed=true
				break
			end
		end
		for _,k in ipairs(controllerSuperJumpKeys) do
			if i.KeyCode==k then
				self.superJumpPressed=true
				break
			end
		end

		for _,k in ipairs(thrustDownKeys) do
			if i.KeyCode==k then
				self.thrustDownPressed=true
				break
			end
		end
		for _,k in ipairs(controllerThrustDownKeys) do
			if i.KeyCode==k then
				self.thrustDownPressed=true
				break
			end
		end
		for _,k in ipairs(thrustUpKeys) do
			if i.KeyCode==k then
				self.thrustUpPressed=true
				break
			end
		end
		for _,k in ipairs(controllerThrustUpKeys) do
			if i.KeyCode==k then
				self.thrustUpPressed=true
				break
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(i,_)
		local keys=self.kbmConfig.MoveKeys or {}
		local jumpKeys=self.kbmConfig.JumpKeys or {}
		local controllerJumpKeys=self.controllerConfig.JumpKeys or {}

		if i.KeyCode==keys.Forward then self.state.W=false end
		if i.KeyCode==keys.Left then self.state.A=false end
		if i.KeyCode==keys.Back then self.state.S=false end
		if i.KeyCode==keys.Right then self.state.D=false end

		for _,k in ipairs(jumpKeys) do
			if i.KeyCode==k then
				self.jumpHeld=false
				break
			end
		end
		for _,k in ipairs(controllerJumpKeys) do
			if i.KeyCode==k then
				self.jumpHeld=false
				break
			end
		end
	end)

	-- Thumbstick movement
	UserInputService.InputChanged:Connect(function(i,_)
		local stickKey=self.controllerConfig.MoveThumbstick or Enum.KeyCode.Thumbstick1
		if i.UserInputType==Enum.UserInputType.Gamepad1 and i.KeyCode==stickKey then
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

function Input:ConsumeThrustDownPressed()
	if self.thrustDownPressed then
		self.thrustDownPressed=false
		return true
	end
	return false
end

function Input:ConsumeThrustUpPressed()
	if self.thrustUpPressed then
		self.thrustUpPressed=false
		return true
	end
	return false
end

return Input
