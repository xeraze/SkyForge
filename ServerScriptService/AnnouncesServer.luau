local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local GroupService = game:GetService("GroupService")

local function getOrCreateRemote(name: string): RemoteEvent
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local displayRemote = getOrCreateRemote("DisplayGlobalAnnouncement")
local sendRemote = getOrCreateRemote("SendAnnouncementRemote")

local messagesGui = StarterGui:WaitForChild("Messages", 5)

local GROUP_ID = 0 -- TODO: ID твоей группы
local REQUIRED_RANK = 0 -- TODO: минимальный ранг для объявлений
local ALLOWED_USER_IDS = {} -- TODO: список ID пользователей с доступом

local GLOBAL_COMMAND = (messagesGui and messagesGui:GetAttribute("GlobalCommand")) or "?global"
local LOCAL_COMMAND = (messagesGui and messagesGui:GetAttribute("LocalCommand")) or "?local"
local MESSAGING_TOPIC = (messagesGui and messagesGui:GetAttribute("MessagingTopic")) or "GlobalAnnouncement"
local DISPLAY_DURATION = (messagesGui and messagesGui:GetAttribute("DisplayDuration")) or 7

local NAME_COLORS = {
	Color3.fromRGB(255, 70, 73),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 230, 80),
	Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(80, 190, 255),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 120, 200),
}

local VERIFIED_ICON = utf8.char(0xE000)
local random = Random.new()
local allowedCache: { [Player]: boolean } = {}

local function refreshAllowed(player: Player)
	local allowed = table.find(ALLOWED_USER_IDS, player.UserId) ~= nil

	if not allowed then
		local success, result = pcall(function()
			return GroupService:GetRolesInGroupAsync(player.UserId, GROUP_ID)
		end)
		if success and typeof(result) == "table" and typeof(result.Roles) == "table" then
			for _, role in result.Roles do
				if typeof(role.Rank) == "number" and role.Rank >= REQUIRED_RANK then
					allowed = true
					break
				end
			end
		end
	end

	allowedCache[player] = allowed
end

local function isAllowed(player: Player): boolean
	local cached = allowedCache[player]
	if cached == nil then
		refreshAllowed(player)
		return allowedCache[player] == true
	end
	return cached
end

local function formatAnnouncement(player: Player, message: string): string
	local nameColor = NAME_COLORS[random:NextInteger(1, #NAME_COLORS)]
	local colorText = string.format(
		"rgb(%d,%d,%d)",
		math.floor(nameColor.R * 255 + 0.5),
		math.floor(nameColor.G * 255 + 0.5),
		math.floor(nameColor.B * 255 + 0.5)
	)

	return string.format(
		"<font color='%s'>%s</font>%s : %s",
		colorText,
		player.DisplayName,
		VERIFIED_ICON,
		message
	)
end

local function resolveText(primary: unknown, fallback: unknown): string?
	if typeof(primary) == "string" and not primary:match("^%s*$") then
		return primary
	end
	if typeof(fallback) == "string" and not fallback:match("^%s*$") then
		return fallback
	end
	return nil
end

type AnnouncementPayload = { UserId: number, TextEN: string, TextRU: string }

local function isValidPayload(payload: unknown): AnnouncementPayload?
	if typeof(payload) ~= "table" then
		return nil
	end
	local data = payload :: { [string]: any }
	if typeof(data.UserId) ~= "number" or typeof(data.TextEN) ~= "string" or typeof(data.TextRU) ~= "string" then
		return nil
	end
	return {
		UserId = data.UserId,
		TextEN = data.TextEN,
		TextRU = data.TextRU,
	}
end

local function displayLocally(payload: AnnouncementPayload)
	displayRemote:FireAllClients(payload, DISPLAY_DURATION)
end

local function broadcastGlobally(payload: AnnouncementPayload)
	local success, err = pcall(function()
		MessagingService:PublishAsync(MESSAGING_TOPIC, payload)
	end)
	if not success then
		warn("[AnnouncesServer] PublishAsync failed:", err)
	end
end

local function parseCommand(chatMessage: string): (string?, string?)
	for _, command in { GLOBAL_COMMAND, LOCAL_COMMAND } do
		local prefix = command .. " "
		if chatMessage:sub(1, #prefix) == prefix then
			local body = chatMessage:sub(#prefix + 1)
			if body ~= "" then
				return command, body
			end
			return command, nil
		end
	end
	return nil, nil
end

local function onPlayerChatted(player: Player, chatMessage: string)
	if not isAllowed(player) then
		return
	end

	local command, message = parseCommand(chatMessage)
	if not command or not message then
		return
	end

	local formattedMessage = formatAnnouncement(player, message)
	local payload = {
		UserId = player.UserId,
		TextEN = formattedMessage,
		TextRU = formattedMessage,
	}

	if command == GLOBAL_COMMAND then
		broadcastGlobally(payload)
	elseif command == LOCAL_COMMAND then
		displayLocally(payload)
	end
end

sendRemote.OnServerEvent:Connect(function(player: Player, textEN: unknown, textRU: unknown, isGlobal: unknown)
	if not isAllowed(player) then
		warn(player.Name .. " attempted to send an announcement without permission")
		return
	end

	local cleanEN = resolveText(textEN, textRU)
	local cleanRU = resolveText(textRU, textEN)
	if not cleanEN or not cleanRU then
		return
	end

	local payload = {
		UserId = player.UserId,
		TextEN = formatAnnouncement(player, cleanEN),
		TextRU = formatAnnouncement(player, cleanRU),
	}

	if isGlobal == true then
		broadcastGlobally(payload)
	else
		displayLocally(payload)
	end
end)

local function onPlayerAdded(player: Player)
	refreshAllowed(player)
	player.Chatted:Connect(function(chatMessage)
		onPlayerChatted(player, chatMessage)
	end)
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	allowedCache[player] = nil
end)

local subscribeSuccess, subscribeErr = pcall(function()
	MessagingService:SubscribeAsync(MESSAGING_TOPIC, function(message)
		local data = isValidPayload(message.Data)
		if data then
			displayLocally(data)
		end
	end)
end)
if not subscribeSuccess then
	warn("[AnnouncesServer] SubscribeAsync failed:", subscribeErr)
end
