local HomeCameraController = {}
HomeCameraController.__index = HomeCameraController

function HomeCameraController.new(options)
	local self = setmetatable({}, HomeCameraController)
	self.localPlayer = options.localPlayer
	self.runService = options.runService
	self.userInputService = options.userInputService
	self.workspace = options.workspace
	self.constants = options.constants
	self.waitForChildTimeout = options.waitForChildTimeout

	self.controls = nil
	self.menuStagingEnabled = true
	self.cameraLockConn = nil
	self.lockedCameraCFrame = nil
	self.lockedCameraFocus = nil
	self.homeCameraMotionEnabled = true
	self.cameraMotionBlend = 1
	self.cameraMotionTarget = 1
	self.lastCameraMotionTick = os.clock()
	self.overlayGui = nil
	return self
end

function HomeCameraController:SetOverlayGui(gui)
	self.overlayGui = gui
end

function HomeCameraController:GetMenuStagingEnabled()
	return self.menuStagingEnabled
end

function HomeCameraController:GetControls()
	if self.controls then
		return self.controls
	end

	local ok, result = pcall(function()
		local playerScripts = self.waitForChildTimeout(self.localPlayer, "PlayerScripts", 5, "HomepageOverlay")
		local playerModule = playerScripts:WaitForChild("PlayerModule")
		return require(playerModule):GetControls()
	end)
	if ok then
		self.controls = result
	end

	return self.controls
end

function HomeCameraController:DisableControls()
	local playerControls = self:GetControls()
	if playerControls and playerControls.Disable then
		playerControls:Disable()
	end
	self.userInputService.MouseBehavior = Enum.MouseBehavior.Default
end

function HomeCameraController:EnableControls()
	local playerControls = self:GetControls()
	if playerControls and playerControls.Enable then
		playerControls:Enable()
	end
end

function HomeCameraController:LockCharacterMotion(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
end

function HomeCameraController:UnlockCharacterMotion(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	root.Anchored = false
	humanoid.AutoRotate = true
	if humanoid.WalkSpeed <= 0 then
		humanoid.WalkSpeed = 16
	end
	if humanoid.UseJumpPower then
		if humanoid.JumpPower <= 0 then
			humanoid.JumpPower = 50
		end
	else
		if humanoid.JumpHeight <= 0 then
			humanoid.JumpHeight = 7.2
		end
	end

	local animateScript = character:FindFirstChild("Animate")
	if animateScript and (animateScript:IsA("LocalScript") or animateScript:IsA("Script")) then
		animateScript.Enabled = true
	end
end

function HomeCameraController:SnapCameraBehindCharacter(character)
	local camera = self.workspace.CurrentCamera
	if not camera or not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	local look = root.CFrame.LookVector
	if look.Magnitude < 0.001 then
		look = Vector3.new(0, 0, -1)
	end

	local cameraPos = root.Position - look * 12 + Vector3.new(0, 4, 0)
	local focusPos = root.Position + Vector3.new(0, 2, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(cameraPos, focusPos)
	camera.Focus = CFrame.new(focusPos)
	camera.CameraSubject = humanoid
	camera.CameraType = Enum.CameraType.Custom

	task.defer(function()
		if self.localPlayer.Character ~= character then
			return
		end
		if not root.Parent then
			return
		end
		local deferredLook = root.CFrame.LookVector
		if deferredLook.Magnitude < 0.001 then
			deferredLook = Vector3.new(0, 0, -1)
		end
		local deferredPos = root.Position - deferredLook * 12 + Vector3.new(0, 4, 0)
		local deferredFocus = root.Position + Vector3.new(0, 2, 0)
		camera.CameraSubject = humanoid
		camera.CameraType = Enum.CameraType.Custom
		camera.CFrame = CFrame.lookAt(deferredPos, deferredFocus)
	end)
end

function HomeCameraController:SetHomeCameraMotionEnabled(enabled, immediate)
	self.homeCameraMotionEnabled = enabled == true
	self.cameraMotionTarget = self.homeCameraMotionEnabled and 1 or 0
	if immediate then
		self.cameraMotionBlend = self.cameraMotionTarget
	end
end

function HomeCameraController:GetLockedFocusDistance()
	if typeof(self.lockedCameraFocus) ~= "Vector3" or not self.lockedCameraCFrame then
		return self.constants.CAMERA_FOCUS_DISTANCE
	end
	local dist = (self.lockedCameraFocus - self.lockedCameraCFrame.Position).Magnitude
	if dist > 0.1 then
		return dist
	end
	return self.constants.CAMERA_FOCUS_DISTANCE
end

function HomeCameraController:ResetCameraToLockedBase()
	local camera = self.workspace.CurrentCamera
	if not camera or not self.lockedCameraCFrame then
		return
	end
	local focusDistance = self:GetLockedFocusDistance()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = self.constants.CAMERA_FOV
	camera.CFrame = self.lockedCameraCFrame
	camera.Focus = CFrame.new(self.lockedCameraCFrame.Position + (self.lockedCameraCFrame.LookVector * focusDistance))
end

function HomeCameraController:ComputeCameraMotion(now)
	local yaw = math.sin((now * math.pi * 2 * self.constants.CAMERA_SWAY_YAW_HZ) + 0.2) * math.rad(self.constants.CAMERA_SWAY_YAW_DEGREES)
	local pitch = math.sin((now * math.pi * 2 * self.constants.CAMERA_SWAY_PITCH_HZ) + 1.1) * math.rad(self.constants.CAMERA_SWAY_PITCH_DEGREES)
	local fovDelta = math.sin((now * math.pi * 2 * self.constants.CAMERA_FOV_BREATHE_HZ) + 0.8) * self.constants.CAMERA_FOV_BREATHE_DELTA
	return yaw, pitch, fovDelta
end

function HomeCameraController:SetCameraLock(cameraCFrame, focusPosition)
	self.lockedCameraCFrame = cameraCFrame
	self.lockedCameraFocus = focusPosition

	if self.cameraLockConn then
		return
	end

	self.cameraLockConn = self.runService.RenderStepped:Connect(function()
		local camera = self.workspace.CurrentCamera
		if not camera or not self.lockedCameraCFrame then
			return
		end

		local now = os.clock()
		local dt = math.max(0, now - self.lastCameraMotionTick)
		self.lastCameraMotionTick = now
		local blendAlpha = 1 - math.exp(-self.constants.CAMERA_MOTION_BLEND_SPEED * dt)
		self.cameraMotionBlend += (self.cameraMotionTarget - self.cameraMotionBlend) * blendAlpha
		if math.abs(self.cameraMotionTarget - self.cameraMotionBlend) < 0.0005 then
			self.cameraMotionBlend = self.cameraMotionTarget
		end

		local yawOffset, pitchOffset, fovDelta = self:ComputeCameraMotion(now)
		local appliedYaw = yawOffset * self.cameraMotionBlend
		local appliedPitch = pitchOffset * self.cameraMotionBlend
		local appliedFovDelta = fovDelta * self.cameraMotionBlend
		local animatedCFrame = self.lockedCameraCFrame * CFrame.Angles(appliedPitch, appliedYaw, 0)
		local focusDistance = self:GetLockedFocusDistance()

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = self.constants.CAMERA_FOV + appliedFovDelta
		camera.CFrame = animatedCFrame
		camera.Focus = CFrame.new(animatedCFrame.Position + (animatedCFrame.LookVector * focusDistance))
	end)
end

function HomeCameraController:BuildMenuRig()
	local characterPosition = self.constants.CHARACTER_POSITION
	local cameraPosition = self.constants.CAMERA_POSITION
	local toCameraFlat = Vector3.new(
		cameraPosition.X - characterPosition.X,
		0,
		cameraPosition.Z - characterPosition.Z
	)
	if toCameraFlat.Magnitude < 0.001 then
		toCameraFlat = Vector3.new(0, 0, -1)
	end

	local playerForward = toCameraFlat.Unit
	local baseCameraForward = -playerForward
	local cameraForward = (CFrame.Angles(0, math.rad(-self.constants.CAMERA_RIGHT_YAW_DEGREES), 0):VectorToWorldSpace(baseCameraForward)).Unit
	local cameraCFrame = CFrame.lookAt(cameraPosition, cameraPosition + cameraForward)
	local cameraFocusPoint = cameraPosition + cameraForward * 64

	return {
		characterPosition = characterPosition,
		focusPosition = cameraFocusPoint,
		cameraCFrame = cameraCFrame,
	}
end

function HomeCameraController:PlaceCharacterFeetAtPosition(character, feetPosition, cameraPosition)
	local lookTarget = Vector3.new(cameraPosition.X, feetPosition.Y, cameraPosition.Z)
	local baseFacing = CFrame.lookAt(feetPosition, lookTarget)
	local rotatedFacing = baseFacing * CFrame.Angles(0, math.rad(-self.constants.PLAYER_RIGHT_YAW_DEGREES), 0)
	character:PivotTo(rotatedFacing)

	local boundsCf, boundsSize = character:GetBoundingBox()
	local minY = boundsCf.Position.Y - (boundsSize.Y * 0.5)
	local deltaY = feetPosition.Y - minY
	if math.abs(deltaY) > 0.0001 then
		character:PivotTo(character:GetPivot() + Vector3.new(0, deltaY, 0))
	end
end

function HomeCameraController:ResolveRunAnimationId(character, humanoid)
	local animateScript = character:FindFirstChild("Animate")
	if animateScript then
		local runNode = animateScript:FindFirstChild("run")
		if runNode then
			for _, child in ipairs(runNode:GetChildren()) do
				if child:IsA("Animation") and child.AnimationId ~= "" then
					return child.AnimationId
				end
			end
		end
	end

	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return "rbxassetid://180426354"
	end
	return "rbxassetid://507767714"
end

function HomeCameraController:ForceCharacterRunAnimation(character)
	local animateScript = character:FindFirstChild("Animate")
	if animateScript and (animateScript:IsA("LocalScript") or animateScript:IsA("Script")) then
		animateScript.Enabled = false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local runAnimation = Instance.new("Animation")
	runAnimation.Name = "MenuRunAnimation"
	runAnimation.AnimationId = self:ResolveRunAnimationId(character, humanoid)
	runAnimation.Parent = character

	local runTrack = animator:LoadAnimation(runAnimation)
	runTrack.Looped = true
	runTrack.Priority = Enum.AnimationPriority.Movement
	runTrack:Play(0.1, 1, 1)
end

function HomeCameraController:StageCharacter(character)
	if not self.menuStagingEnabled then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 30)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 30)
	if not humanoid or not root then
		warn("[HomeCameraController] Failed to stage character: missing humanoid/root")
		return
	end

	local rig = self:BuildMenuRig()
	self:PlaceCharacterFeetAtPosition(character, rig.characterPosition, rig.cameraCFrame.Position)
	self:ForceCharacterRunAnimation(character)
	self:LockCharacterMotion(character)
	self:SetCameraLock(rig.cameraCFrame, rig.focusPosition)
	self:DisableControls()
end

function HomeCameraController:ExitHomeScreenToGame()
	self.menuStagingEnabled = false
	if self.overlayGui then
		self.overlayGui.Enabled = false
	end

	if self.cameraLockConn then
		self.cameraLockConn:Disconnect()
		self.cameraLockConn = nil
	end
	self.lockedCameraCFrame = nil
	self.lockedCameraFocus = nil

	self:SetHomeCameraMotionEnabled(false, true)
	self:EnableControls()
	local character = self.localPlayer.Character
	if character then
		self:UnlockCharacterMotion(character)
		self:SnapCameraBehindCharacter(character)
	end
end

function HomeCameraController:BindHomeCameraLifecycle(gui)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			if not self.menuStagingEnabled then
				return
			end
			self:SetHomeCameraMotionEnabled(true, false)
			return
		end

		if not self.menuStagingEnabled then
			return
		end
		self:SetHomeCameraMotionEnabled(false, true)
		self:ResetCameraToLockedBase()
	end)

	gui.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end

		if self.menuStagingEnabled then
			self:SetHomeCameraMotionEnabled(false, true)
			self:ResetCameraToLockedBase()
		end
		if self.cameraLockConn then
			self.cameraLockConn:Disconnect()
			self.cameraLockConn = nil
		end
	end)
end

function HomeCameraController:OnCharacterAdded(character)
	task.wait(0.1)
	if self.menuStagingEnabled then
		self:StageCharacter(character)
	else
		self:UnlockCharacterMotion(character)
		self:SnapCameraBehindCharacter(character)
	end
end

function HomeCameraController:StageCurrentCharacterIfPresent()
	if self.localPlayer.Character then
		if self.menuStagingEnabled then
			self:StageCharacter(self.localPlayer.Character)
		else
			self:UnlockCharacterMotion(self.localPlayer.Character)
			self:SnapCameraBehindCharacter(self.localPlayer.Character)
		end
	end
end

function HomeCameraController:HideDebugHud()
	local playerGui = self.localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local function hideOne(name)
		local guiRef = playerGui:FindFirstChild(name)
		if guiRef and guiRef:IsA("ScreenGui") then
			guiRef.Enabled = false
		end
	end

	hideOne("DebugHUD")
	hideOne("ThrustDebugHUD")

	playerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") and (child.Name == "DebugHUD" or child.Name == "ThrustDebugHUD") then
			child.Enabled = false
		end
	end)
end

return HomeCameraController
