-- Motor.lua
local Workspace=game:GetService("Workspace")
local Motor={}
Motor.__index=Motor
function Motor.new(root,config)
	local self=setmetatable({},Motor)
	self.root=root
	self.config=config or {}
	self.attachment=nil
	self.linearVelocity=nil
	self.alignOrientation=nil
	return self
end
function Motor:Ensure()
	if not self.root then return end
	if not self.attachment then
		local a=Instance.new("Attachment")
		a.Name="MoveAttachment"
		a.Parent=self.root
		self.attachment=a
	end
	if not self.linearVelocity then
		local lv=Instance.new("LinearVelocity")
		lv.Name="MoveLinearVelocity"
		lv.Attachment0=self.attachment
		lv.RelativeTo=Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
		lv.MaxForce=math.huge
		lv.VectorVelocity=Vector3.zero
		lv.Parent=self.root
		self.linearVelocity=lv
	end
	if not self.alignOrientation then
		local ao=Instance.new("AlignOrientation")
		ao.Name="MoveAlignOrientation"
		ao.Attachment0=self.attachment
		ao.Mode=Enum.OrientationAlignmentMode.OneAttachment
		ao.ReactionTorqueEnabled=false
		ao.RigidityEnabled=false
		ao.MaxTorque=1e9
		ao.Responsiveness=self.config.TurnResponsiveness or 8
		ao.Enabled=false

		-- HARD UPRIGHT + YAW ONLY
		ao.PrimaryAxisOnly=true
		ao.PrimaryAxis=Vector3.new(0,1,0)
		ao.SecondaryAxis=Vector3.new(0,1,0)

		ao.Parent=self.root
		self.alignOrientation=ao
	end
end
function Motor:ApplyVelocity(v)
	if self.linearVelocity then
		self.linearVelocity.VectorVelocity=v
	end
end
function Motor:ApplyRotation(dir,dt,turnResponsiveness)
	if not self.root then return end
	self.root.AssemblyAngularVelocity=Vector3.zero
	local p=self.root.Position
	if not self.currentYaw then
		local _,y,_=self.root.CFrame:ToOrientation()
		self.currentYaw=y
	end
	local flat=nil
	if dir and dir.Magnitude>0 then
		flat=Vector3.new(dir.X,0,dir.Z)
	else
		flat=Vector3.new(self.root.CFrame.LookVector.X,0,self.root.CFrame.LookVector.Z)
	end
	if flat.Magnitude>0 then flat=flat.Unit else flat=Vector3.new(0,0,-1) end
	local targetYaw=math.atan2(-flat.X,-flat.Z)
	local function shortestAngleDelta(a,b)
		local d=(b-a)%(2*math.pi)
		if d>math.pi then d=d-2*math.pi end
		return d
	end
	local k=turnResponsiveness or self.config.TurnSmoothing or self.config.TurnResponsiveness or 8
	local alpha=1-math.exp(-k*(dt or 0))
	self.currentYaw=self.currentYaw+shortestAngleDelta(self.currentYaw,targetYaw)*alpha
	self.root.CFrame=CFrame.new(p)*CFrame.Angles(0,self.currentYaw,0)
end



function Motor:Destroy()
	if self.linearVelocity then self.linearVelocity:Destroy() self.linearVelocity=nil end
	if self.alignOrientation then self.alignOrientation:Destroy() self.alignOrientation=nil end
	if self.attachment then self.attachment:Destroy() self.attachment=nil end
	self.currentYaw=nil
end
return Motor
