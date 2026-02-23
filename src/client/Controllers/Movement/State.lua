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
return State
