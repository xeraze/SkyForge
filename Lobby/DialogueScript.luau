local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")

local player = Players.LocalPlayer
local gui = script.Parent
local frame = gui:WaitForChild("DialogueFrame")
local nameLabel = frame:WaitForChild("NPCName")
local textLabel = frame:WaitForChild("DialogueText")
local optionsContainer = frame:WaitForChild("OptionsContainer")
local closeBtn = frame:WaitForChild("CloseButton")

local Config = require(gui:WaitForChild("DialogueConfig"))
local Settings = Config.Settings
local NODES = Config.Nodes
local START_NODE = Config.StartNode
local NPC_NAME = Config.NPCName

local remote = ReplicatedStorage:FindFirstChild(Settings.RemoteName)

local currentNodeId = nil
local isActive = false
local typewriterConnection = nil

local function getLocale()
	local locale = LocalizationService.RobloxLocaleId
	if string.sub(locale, 1, 2) == "ru" then
		return "RU"
	end
	return "EN"
end

local function resolveText(value)
	if type(value) == "function" then
		value = value(player)
	end
	if type(value) == "table" then
		local locale = getLocale()
		return value[locale] or value.EN or value.RU or ""
	end
	return tostring(value)
end

local function findPrompt()
	local npcPart = Workspace:FindFirstChild("DialogueNPC")
	if not npcPart then
		npcPart = Workspace:WaitForChild("DialogueNPC", 10)
	end
	if not npcPart then
		return nil
	end
	return npcPart:FindFirstChildOfClass("ProximityPrompt")
end

local function stopTypewriter()
	if typewriterConnection then
		typewriterConnection:Disconnect()
		typewriterConnection = nil
	end
end

local function showText(text)
	stopTypewriter()
	textLabel.Text = ""

	local i = 0
	local lastUpdate = os.clock()
	typewriterConnection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - lastUpdate >= Settings.TypewriterSpeed then
			lastUpdate = now
			i += 1
			if i <= #text then
				textLabel.Text = string.sub(text, 1, i)
			else
				textLabel.Text = text
				stopTypewriter()
			end
		end
	end)
end

local function clearOptions()
	for _, child in optionsContainer:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	optionsContainer.Visible = false
end

local function createOptionButton(text, bgColor, onClick)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(Settings.OptionWidth, 0, 0, Settings.OptionHeight)
	btn.BackgroundColor3 = bgColor
	btn.Text = text
	btn.TextColor3 = Settings.OptionTextColor
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 16
	btn.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Settings.OptionHoverColor }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = bgColor }):Play()
	end)
	btn.MouseButton1Click:Connect(onClick)

	btn.BackgroundTransparency = 1
	btn.TextTransparency = 1
	btn.Parent = optionsContainer
	TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0,
		TextTransparency = 0,
	}):Play()

	return btn
end

local function showOptions(options, onSelected)
	clearOptions()
	if not options or #options == 0 then
		return
	end

	for _, option in ipairs(options) do
		local optText = resolveText(option.text)
		createOptionButton(optText, Settings.OptionColor, function()
			onSelected(option)
		end)
	end
	optionsContainer.Visible = true
end

local closeDialogue

local function goToNode(nodeId)
	if nodeId == "__exit" then
		closeDialogue()
		return
	end

	local node = NODES[nodeId]
	if not node then
		return
	end

	currentNodeId = nodeId
	clearOptions()
	showText(resolveText(node.text))

	local opts = type(node.options) == "function" and node.options(player) or node.options

	if opts and #opts > 0 then
		showOptions(opts, function(option)
			stopTypewriter()
			if option.action and remote then
				remote:FireServer(option.action)
			end
			goToNode(option.target)
		end)
	elseif node.next then
		local btn = createOptionButton("Next", Color3.fromRGB(100, 150, 200), function()
			stopTypewriter()
			goToNode(node.next)
		end)
		btn.Name = "AutoNext"
		optionsContainer.Visible = true
	else
		local btn = createOptionButton("Close", Color3.fromRGB(100, 150, 200), function()
			stopTypewriter()
			closeDialogue()
		end)
		btn.Name = "EndDialogue"
		optionsContainer.Visible = true
	end
end

local function openDialogue()
	if not frame then
		return
	end
	isActive = true
	nameLabel.Text = NPC_NAME
	frame.Visible = true
	frame.Position = UDim2.new(0.2, 0, 1, 0)
	TweenService:Create(frame, TweenInfo.new(Settings.SlideDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.2, 0, 0.65, 0),
	}):Play()
	goToNode(START_NODE)
	local prompt = findPrompt()
	if prompt then
		prompt.Enabled = false
	end
end

closeDialogue = function()
	if not frame then
		return
	end
	isActive = false
	stopTypewriter()
	clearOptions()
	local tween = TweenService:Create(frame, TweenInfo.new(Settings.SlideDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.2, 0, 1, 0),
	})
	tween:Play()
	tween.Completed:Connect(function()
		if not isActive then
			frame.Visible = false
		end
	end)
	local prompt = findPrompt()
	if prompt then
		prompt.Enabled = true
	end
end

if closeBtn then
	closeBtn.MouseButton1Click:Connect(function()
		if isActive then
			closeDialogue()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isActive then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
		if typewriterConnection then
			stopTypewriter()
			if currentNodeId and NODES[currentNodeId] then
				textLabel.Text = resolveText(NODES[currentNodeId].text)
			end
			return
		end
		local autoBtn = optionsContainer and optionsContainer:FindFirstChild("AutoNext")
		if autoBtn then
			autoBtn.MouseButton1Click:Fire()
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if isActive then
			closeDialogue()
		end
	end
end)

local promptConnection = nil

local function setupPrompt()
	if promptConnection then
		return
	end
	local prompt = findPrompt()
	if prompt then
		promptConnection = prompt.Triggered:Connect(function()
			if not isActive then
				openDialogue()
			end
		end)
	end
end

task.spawn(function()
	for _ = 1, 5 do
		setupPrompt()
		if promptConnection then
			break
		end
		task.wait(1)
	end
end)

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") and descendant.Parent and descendant.Parent.Name == "DialogueNPC" then
		if promptConnection then
			promptConnection:Disconnect()
			promptConnection = nil
		end
		setupPrompt()
	end
end)
