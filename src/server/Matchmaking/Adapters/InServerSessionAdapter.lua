local InServerSessionAdapter = {}
InServerSessionAdapter.__index = InServerSessionAdapter

function InServerSessionAdapter.new()
	return setmetatable({}, InServerSessionAdapter)
end

function InServerSessionAdapter:StartSession(_sessionSpec)
	return true
end

function InServerSessionAdapter:EndSession(_sessionId)
	return true
end

return InServerSessionAdapter
