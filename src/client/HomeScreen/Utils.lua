local Utils = {}

function Utils.waitForChildTimeout(parent, name, timeoutSeconds, contextName)
	local t0 = os.clock()
	local child = parent:FindFirstChild(name)
	while not child do
		if os.clock() - t0 >= timeoutSeconds then
			local context = contextName or "HomeScreen"
			error(("%s timed out waiting for '%s' under %s"):format(context, name, parent:GetFullName()))
		end
		child = parent:FindFirstChild(name)
		task.wait(0.05)
	end
	return child
end

function Utils.partyDisplayName(entry)
	local display = entry.displayName or entry.fromDisplayName or entry.name or entry.fromName or ("User " .. tostring(entry.userId or entry.fromUserId or 0))
	local name = entry.name or entry.fromName
	if name and display ~= name then
		return ("%s (@%s)"):format(display, name)
	end
	return display
end

return Utils
