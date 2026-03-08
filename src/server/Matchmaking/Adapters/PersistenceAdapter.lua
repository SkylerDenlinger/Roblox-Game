local PersistenceAdapter = {}
PersistenceAdapter.__index = PersistenceAdapter

function PersistenceAdapter.new()
	return setmetatable({}, PersistenceAdapter)
end

function PersistenceAdapter:SaveSessionResult(_session)
	-- Launch scope: no ranked/MMR persistence yet.
	return true
end

return PersistenceAdapter
