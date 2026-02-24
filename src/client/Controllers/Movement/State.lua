-- State.lua
local State={}
State.Mode="Normal"
State.Grounded=false
State.InputDir=Vector3.zero
State.InputMag=0
State.Forward=Vector3.zero
State.Velocity=Vector3.zero
State.RotationDir=nil
State.DeltaTime=0
State.CoyoteRemaining=0
State.CoyoteFramesRemaining=0
State.JumpGrounded=true
State.SingleJumpUsed=false
State.DoubleJumpUsed=false
State.JumpHoldRemaining=0
State.JumpAutoHoldRemaining=0
State.JumpHoldFrames=0
State.JumpBoostActive=false
State.JumpReleaseRequired=false
State.WasGrounded=false
State.ThrustLevel=0
State.ThrustUnlockedLevel=0
return State
