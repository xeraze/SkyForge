local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Timer = require(ReplicatedStorage:WaitForChild("Timer"))

local SYNC_INTERVAL = 1

ReplicatedStorage:SetAttribute("Day", Timer.GetDay())
ReplicatedStorage:SetAttribute("TimeOfDay", Timer.GetTimeOfDay())

while true do
	task.wait(SYNC_INTERVAL)
	ReplicatedStorage:SetAttribute("TimeOfDay", Timer.GetTimeOfDay())

	local day = Timer.GetDay()
	if ReplicatedStorage:GetAttribute("Day") ~= day then
		ReplicatedStorage:SetAttribute("Day", day)
	end
end
