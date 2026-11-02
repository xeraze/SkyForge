local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("TimerConfig"))

local Timer = {}

function Timer.GetTime(): number
	return (DateTime.now().UnixTimestamp - config.EPOCH) * config.TIME_SCALE
end

function Timer.GetTimeOfDay(): number
	return Timer.GetTime() % config.DAY_LENGTH
end

function Timer.GetDay(): number
	return math.floor(Timer.GetTime() / config.DAY_LENGTH) + 1
end

function Timer.GetDayProgress(): number
	return Timer.GetTimeOfDay() / config.DAY_LENGTH
end

return Timer
