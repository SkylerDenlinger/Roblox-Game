local ScreenFlowSignals = {}

local returnToMenuEvent = Instance.new("BindableEvent")
local queueAgainEvent = Instance.new("BindableEvent")

function ScreenFlowSignals.OnReturnToMenu(callback)
	return returnToMenuEvent.Event:Connect(callback)
end

function ScreenFlowSignals.OnQueueAgain(callback)
	return queueAgainEvent.Event:Connect(callback)
end

function ScreenFlowSignals.FireReturnToMenu()
	returnToMenuEvent:Fire()
end

function ScreenFlowSignals.FireQueueAgain()
	queueAgainEvent:Fire()
end

return ScreenFlowSignals
