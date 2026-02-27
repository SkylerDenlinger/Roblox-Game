local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local TeleportSessionAdapter = {}
TeleportSessionAdapter.__index = TeleportSessionAdapter

function TeleportSessionAdapter.new()
	return setmetatable({}, TeleportSessionAdapter)
end

function TeleportSessionAdapter:StartSession(_sessionSpec)
	if RunService:IsStudio() then
		warn("TeleportSessionAdapter is not active in Studio; falling back to in-server flow.")
	end
	-- Reserved-server transport is intentionally staged behind feature flags.
	-- This adapter exists so orchestration can be switched without changing service contracts.
	_ = TeleportService
	return false, "Teleport session transport is not enabled."
end

function TeleportSessionAdapter:EndSession(_sessionId)
	return true
end

return TeleportSessionAdapter
