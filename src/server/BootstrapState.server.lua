local servicesFolder=serverFolder:WaitForChild("Services")
local StateContract = require(servicesFolder:WaitForChild("StateContract"))
StateContract.Ensure()
