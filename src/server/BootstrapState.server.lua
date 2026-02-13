local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateContract = require(ReplicatedStorage:WaitForChild("State"):WaitForChild("StateContract"))
StateContract.Ensure()
