local Players = game:GetService("Players")

local QualificationZoneService = {}

local TOUCH_COOLDOWN = 0.75

local zonePart = nil
local touchConn = nil
local enabled = false
local entrants = {}
local cooldownByUserId = {}
local qualificationHandler = nil

local function getPlayerFromHit(hit)
	if not hit then
		return nil
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function onTouched(hit)
	if not enabled then
		return
	end
	local player = getPlayerFromHit(hit)
	if not player then
		return
	end
	if entrants[player.UserId] ~= true then
		return
	end
	local now = os.clock()
	local previous = cooldownByUserId[player.UserId] or 0
	if now - previous < TOUCH_COOLDOWN then
		return
	end
	cooldownByUserId[player.UserId] = now
	if qualificationHandler then
		qualificationHandler(player.UserId, now)
	end
end

function QualificationZoneService.BindZone(part)
	zonePart = part
	if touchConn then
		touchConn:Disconnect()
		touchConn = nil
	end
	if not zonePart then
		return
	end
	zonePart.CanTouch = true
	touchConn = zonePart.Touched:Connect(onTouched)
end

function QualificationZoneService.SetQualificationHandler(handler)
	qualificationHandler = handler
end

function QualificationZoneService.StartRound(options)
	options = options or {}
	entrants = {}
	for _, userId in ipairs(options.entrantUserIds or {}) do
		entrants[userId] = true
	end
	cooldownByUserId = {}
	enabled = true
end

function QualificationZoneService.EndRound()
	enabled = false
	cooldownByUserId = {}
	entrants = {}
end

return QualificationZoneService
