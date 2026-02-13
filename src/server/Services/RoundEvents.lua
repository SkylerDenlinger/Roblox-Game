local RoundEvents = {}

local playerQualifiedEvent = Instance.new("BindableEvent")
local endCollectathonEvent = Instance.new("BindableEvent")

function RoundEvents.OnPlayerQualified(cb)
	return playerQualifiedEvent.Event:Connect(cb)
end

function RoundEvents.FirePlayerQualified(userId)
	playerQualifiedEvent:Fire(userId)
end

function RoundEvents.OnEndCollectathonRequested(cb)
	return endCollectathonEvent.Event:Connect(cb)
end

function RoundEvents.RequestEndCollectathon(reason)
	endCollectathonEvent:Fire(reason)
end

return RoundEvents
