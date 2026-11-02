local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local config = require(ReplicatedStorage:WaitForChild("InventoryConfig"))
local InventoryCore = require(ReplicatedStorage:WaitForChild("InventoryCore"))
local inventoryRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InventoryRemote")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("InventoryGui")
local slotsGui = playerGui:WaitForChild("SlotsGui")

local hudSlotFrames = {}
for index = 1, 8 do
	hudSlotFrames[index] = slotsGui:WaitForChild("Slot" .. index .. "Frame")
end

local function requireDescendant(root: Instance, name: string): Instance
	local existing = root:FindFirstChild(name, true)
	if existing == nil then
		error(`InventoryGui: объект "{name}" не найден`)
	end
	return existing
end

local viewportFrame = requireDescendant(gui, "ViewportFrame")
local weaponsFrame = requireDescendant(gui, "WeaponsFrame")
local armorFrame = requireDescendant(gui, "ArmorFrame")
local itemsFrame = requireDescendant(gui, "ItemsFrame")
local groundPanel = requireDescendant(gui, "VelocityFrame")
local inventoryPanel = requireDescendant(gui, "InventoryFrame")
local groundContainer = requireDescendant(groundPanel, "VelocityFrame")
local gridContainer = requireDescendant(inventoryPanel, "Frame")

local gridTemplate = requireDescendant(gridContainer, "ImageLabel")
local groundTemplate = requireDescendant(groundContainer, "ImageLabel")

local serverState = nil
local isInventoryOpen = false
local dragging = nil
local renderState

local gridMetrics = {
	PadX = gridTemplate.Position.X.Scale,
	PadY = gridTemplate.Position.Y.Scale,
	CellW = gridTemplate.Size.X.Scale,
	CellH = gridTemplate.Size.Y.Scale,
}

local groundMetrics = {
	PadX = groundTemplate.Position.X.Scale,
	PadY = groundTemplate.Position.Y.Scale,
	CellW = groundTemplate.Size.X.Scale,
	CellH = groundTemplate.Size.Y.Scale,
}

local function markGenerated(object)
	object:SetAttribute("Generated", true)
	return object
end

local function clearGenerated(parent)
	for _, child in parent:GetChildren() do
		if child:GetAttribute("Generated") then
			child:Destroy()
		end
	end
end

local function getScreenPosition(screenPosition)
	local inset = GuiService:GetGuiInset()
	return screenPosition - inset
end

local function createScrollContainer(parent)
	local scrolling = Instance.new("ScrollingFrame")
	scrolling.Name = "GeneratedScroll"
	scrolling.BackgroundTransparency = 1
	scrolling.BorderSizePixel = 0
	scrolling.Size = UDim2.fromScale(1, 1)
	scrolling.ScrollBarThickness = 4
	scrolling.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
	scrolling.CanvasSize = UDim2.fromScale(1, 1)
	scrolling.ZIndex = 2
	scrolling.Parent = parent
	return scrolling
end

local gridScroll = createScrollContainer(gridContainer)
local groundScroll = createScrollContainer(groundContainer)
gridTemplate.Visible = false
groundTemplate.Visible = false

local function getCellWidthPixels()
	local width = gridMetrics.CellW * gridScroll.AbsoluteSize.X
	if width <= 0 then
		width = gridMetrics.CellW * gui.AbsoluteSize.X
	end
	return width
end

local function getCellHeightPixels()
	local height = gridMetrics.CellH * gridScroll.AbsoluteSize.Y
	if height <= 0 then
		height = gridMetrics.CellH * gui.AbsoluteSize.Y
	end
	return height
end

local gridHighlight = markGenerated(Instance.new("Frame"))
gridHighlight.Name = "GridHighlight"
gridHighlight.BackgroundTransparency = 0.55
gridHighlight.BorderSizePixel = 0
gridHighlight.ZIndex = 6
gridHighlight.Visible = false
gridHighlight.Parent = gridScroll

local absoluteHighlight = markGenerated(Instance.new("Frame"))
absoluteHighlight.Name = "AbsoluteHighlight"
absoluteHighlight.BackgroundTransparency = 0.55
absoluteHighlight.BorderSizePixel = 0
absoluteHighlight.ZIndex = 30
absoluteHighlight.Visible = false
absoluteHighlight.Parent = gui

local function getSortedImageLabels(frame, sortBy)
	local labels = {}
	for _, child in frame:GetChildren() do
		if child:IsA("ImageLabel") then
			labels[#labels + 1] = child
		end
	end
	table.sort(labels, function(a, b)
		if sortBy == "x" then
			return a.Position.X.Scale < b.Position.X.Scale
		end
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	return labels
end

local armorLabels = getSortedImageLabels(armorFrame, "y")
local attributeLabels = getSortedImageLabels(itemsFrame, "y")
local hotbarLabels = getSortedImageLabels(weaponsFrame, "x")

local equipmentSlotLabels = {}
do
	local armorIndex = 1
	local attributeIndex = 1
	for _, slotDefinition in config.EquipmentSlots do
		local label
		if slotDefinition.ParentFrameName == "ArmorFrame" then
			label = armorLabels[armorIndex]
			armorIndex += 1
		elseif slotDefinition.ParentFrameName == "ItemsFrame" then
			label = attributeLabels[attributeIndex]
			attributeIndex += 1
		end
		if label then
			equipmentSlotLabels[slotDefinition.Id] = label
		end
	end
end

local function styleIconFrame(frame, definition)
	frame.BackgroundColor3 = config.TypeColors[definition.Type] or Color3.fromRGB(90, 90, 90)
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(30, 30, 34)
	stroke.Parent = frame
end

local function createIconContent(container, definition)
	if definition.Icon ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = definition.Icon
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromScale(1, 1)
		icon.Parent = container
	else
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.Font = Enum.Font.GothamMedium
		textLabel.Text = definition.Name
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true
		textLabel.TextWrapped = true
		textLabel.Parent = container
	end
end

local function isInsideBounds(screenPosition, frame)
	local framePosition = frame.AbsolutePosition
	local frameSize = frame.AbsoluteSize
	return screenPosition.X >= framePosition.X
		and screenPosition.X <= framePosition.X + frameSize.X
		and screenPosition.Y >= framePosition.Y
		and screenPosition.Y <= framePosition.Y + frameSize.Y
end

local function resolveTarget(screenPosition)
	if not serverState then
		return nil
	end
	local placements = serverState.Placements
	local capacityCells = serverState.CapacityCells

	if isInsideBounds(screenPosition, gridScroll) then
		local gridPosition = gridScroll.AbsolutePosition
		local gridSize = gridScroll.AbsoluteSize
		local column = math.floor((screenPosition.X - gridPosition.X) / (gridMetrics.CellW * gridSize.X))
		local contentY = screenPosition.Y - gridPosition.Y + gridScroll.CanvasPosition.Y
		local row = math.floor((contentY / gridSize.Y - gridMetrics.PadY) / gridMetrics.CellH)
		if column < 0 or column >= config.GridColumns or row < 0 then
			return nil
		end
		local cursorCell = row * config.GridColumns + column + 1
		local anchorCell = cursorCell - dragging.GrabY * config.GridColumns - dragging.GrabX
		if anchorCell < 1 then
			return { Container = "grid", Cell = anchorCell, Valid = false }
		end
		local valid = InventoryCore.CanPlaceInContainer(
			placements,
			config,
			"grid",
			anchorCell,
			dragging.DefinitionId,
			dragging.Rotated,
			dragging.Uid,
			capacityCells
		)
		return { Container = "grid", Cell = anchorCell, Valid = valid }
	end

	if isInsideBounds(screenPosition, groundScroll) then
		return { Container = "ground", Valid = true }
	end

	for hotbarIndex, label in hotbarLabels do
		if isInsideBounds(screenPosition, label) then
			local valid = InventoryCore.CanPlaceInContainer(
				placements,
				config,
				"hotbar",
				hotbarIndex,
				dragging.DefinitionId,
				false,
				dragging.Uid,
				capacityCells
			)
			return { Container = "hotbar", Cell = hotbarIndex, Valid = valid }
		end
	end

	for slotId, label in equipmentSlotLabels do
		if isInsideBounds(screenPosition, label) then
			local valid = InventoryCore.CanEquipItem(config, placements, slotId, dragging.DefinitionId, dragging.Uid)
			return { Container = "equipment", Slot = slotId, Valid = valid }
		end
	end

	return nil
end

local function updateHighlight(target)
	gridHighlight.Visible = false
	absoluteHighlight.Visible = false
	if not target then
		return
	end

	local color = target.Valid and Color3.fromRGB(70, 220, 110) or Color3.fromRGB(230, 70, 70)

	if target.Container == "grid" then
		if target.Cell < 1 then
			return
		end
		local definition = config.Items[dragging.DefinitionId]
		local width, height = InventoryCore.GetItemDimensions(definition, dragging.Rotated)
		local column = (target.Cell - 1) % config.GridColumns
		local row = math.floor((target.Cell - 1) / config.GridColumns)
		gridHighlight.BackgroundColor3 = color
		gridHighlight.Position = UDim2.fromScale(
			gridMetrics.PadX + column * gridMetrics.CellW,
			gridMetrics.PadY + row * gridMetrics.CellH
		)
		gridHighlight.Size = UDim2.fromScale(width * gridMetrics.CellW, height * gridMetrics.CellH)
		gridHighlight.Visible = true
		return
	end

	local targetFrame
	if target.Container == "ground" then
		targetFrame = groundScroll
	elseif target.Container == "hotbar" then
		targetFrame = hotbarLabels[target.Cell]
	elseif target.Container == "equipment" then
		targetFrame = equipmentSlotLabels[target.Slot]
	end

	if targetFrame then
		absoluteHighlight.BackgroundColor3 = color
		absoluteHighlight.Position = UDim2.fromOffset(targetFrame.AbsolutePosition.X, targetFrame.AbsolutePosition.Y)
		absoluteHighlight.Size = UDim2.fromOffset(targetFrame.AbsoluteSize.X, targetFrame.AbsoluteSize.Y)
		absoluteHighlight.Visible = true
	end
end

local function updateDrag()
	if not dragging then
		return
	end
	local screenPosition = getScreenPosition(UserInputService:GetMouseLocation())
	dragging.Target = resolveTarget(screenPosition)
	dragging.Ghost.Position =
		UDim2.fromOffset(screenPosition.X - dragging.GrabPixelX, screenPosition.Y - dragging.GrabPixelY)
	updateHighlight(dragging.Target)
end

local function endDrag()
	if not dragging then
		return
	end
	if dragging.SourceView and dragging.SourceView.Parent then
		dragging.SourceView.Visible = true
	end
	dragging.Ghost:Destroy()
	dragging = nil
	gridHighlight.Visible = false
	absoluteHighlight.Visible = false
end

local function beginDrag(uid, sourceView, input)
	if dragging or not serverState then
		return
	end
	local placement = serverState.Placements[uid]
	if not placement then
		return
	end
	local definition = config.Items[placement.DefinitionId]
	if not definition then
		return
	end

	local grabX = 0
	local grabY = 0
	if placement.Container == "grid" then
		local width, height = InventoryCore.GetItemDimensions(definition, placement.Rotated)
		local cellWidth = getCellWidthPixels()
		local cellHeight = getCellHeightPixels()
		local mousePosition = getScreenPosition(input.Position)
		local relativeX = mousePosition.X - sourceView.AbsolutePosition.X
		local relativeY = mousePosition.Y - sourceView.AbsolutePosition.Y
		grabX = math.clamp(math.floor(relativeX / cellWidth), 0, width - 1)
		grabY = math.clamp(math.floor(relativeY / cellHeight), 0, height - 1)
	end

	local width, height = InventoryCore.GetItemDimensions(definition, placement.Rotated)
	local cellWidth = getCellWidthPixels()
	local cellHeight = getCellHeightPixels()

	local ghost = sourceView:Clone()
	ghost.Name = "DragGhost"
	ghost.ZIndex = 50
	ghost.Visible = true
	ghost.Size = UDim2.fromOffset(width * cellWidth, height * cellHeight)
	ghost.Parent = gui

	sourceView.Visible = false
	dragging = {
		Uid = uid,
		DefinitionId = placement.DefinitionId,
		Definition = definition,
		Rotated = placement.Rotated,
		GrabX = grabX,
		GrabY = grabY,
		GrabPixelX = grabX * cellWidth,
		GrabPixelY = grabY * cellHeight,
		SourceView = sourceView,
		Ghost = ghost,
		Target = nil,
	}
	updateDrag()
end

local function rotateDraggedItem()
	if not dragging then
		return
	end
	dragging.Rotated = not dragging.Rotated
	local width, height = InventoryCore.GetItemDimensions(dragging.Definition, dragging.Rotated)
	dragging.GrabX = math.min(dragging.GrabX, width - 1)
	dragging.GrabY = math.min(dragging.GrabY, height - 1)
	dragging.GrabPixelX = dragging.GrabX * getCellWidthPixels()
	dragging.GrabPixelY = dragging.GrabY * getCellHeightPixels()
	dragging.Ghost.Size = UDim2.fromOffset(width * getCellWidthPixels(), height * getCellHeightPixels())
	updateDrag()
end

local function createItemView(uid, definition)
	local view = Instance.new("TextButton")
	view.Name = "InventoryItem"
	view.Text = ""
	view.AutoButtonColor = false
	markGenerated(view)
	styleIconFrame(view, definition)
	createIconContent(view, definition)
	view.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			beginDrag(uid, view, input)
		end
	end)
	return view
end

local function createEquippedHolder(definition)
	local holder = Instance.new("Frame")
	holder.Name = "EquippedItem"
	markGenerated(holder)
	styleIconFrame(holder, definition)
	holder.Size = UDim2.new(1, -4, 1, -4)
	createIconContent(holder, definition)
	return holder
end

local function handleHotbarClick(hotbarIndex)
	if not serverState then
		return
	end
	for _, placement in pairs(serverState.Placements) do
		if placement.Container == "hotbar" and placement.Cell == hotbarIndex then
			local definition = config.Items[placement.DefinitionId]
			if definition and definition.WeaponIndex then
				player:SetAttribute("EquippedWeaponIndex", definition.WeaponIndex)
				renderState()
			end
			return
		end
	end
end

local function renderHotbarHud()
	if not serverState then
		return
	end
	local placements = serverState.Placements
	local equippedWeaponIndex = player:GetAttribute("EquippedWeaponIndex")

	for hotbarIndex = 1, config.HotbarSize do
		local slotFrame = hudSlotFrames[hotbarIndex]
		if slotFrame then
			clearGenerated(slotFrame)
			for _, placement in pairs(placements) do
				if placement.Container == "hotbar" and placement.Cell == hotbarIndex then
					local definition = config.Items[placement.DefinitionId]
					if definition then
						local holder = createEquippedHolder(definition)
						holder.ZIndex = 1
						holder.Parent = slotFrame

						if definition.WeaponIndex and definition.WeaponIndex == equippedWeaponIndex then
							local selectedStroke = markGenerated(Instance.new("UIStroke"))
							selectedStroke.Color = Color3.fromRGB(255, 200, 60)
							selectedStroke.Thickness = 2
							selectedStroke.Parent = holder
						end

						local button = markGenerated(Instance.new("TextButton"))
						button.Name = "HotbarHudButton"
						button.Text = ""
						button.AutoButtonColor = false
						button.BackgroundTransparency = 1
						button.Size = UDim2.fromScale(1, 1)
						button.ZIndex = 2
						button.Parent = slotFrame
						button.Activated:Connect(function()
							handleHotbarClick(hotbarIndex)
						end)
					end
					break
				end
			end
		end
	end
end

renderState = function()
	if not serverState then
		return
	end
	local placements = serverState.Placements
	local capacityCells = serverState.CapacityCells
	local gridRows = math.ceil(capacityCells / config.GridColumns)

	clearGenerated(gridScroll)
	gridScroll.CanvasSize =
		UDim2.fromScale(1, gridMetrics.PadY + gridRows * gridMetrics.CellH + gridMetrics.PadY)

	for cell = 1, capacityCells do
		local column = (cell - 1) % config.GridColumns
		local row = math.floor((cell - 1) / config.GridColumns)
		local slot = gridTemplate:Clone()
		slot.Name = "GridSlot"
		slot.Visible = true
		slot.ZIndex = 1
		slot.Position = UDim2.fromScale(
			gridMetrics.PadX + column * gridMetrics.CellW,
			gridMetrics.PadY + row * gridMetrics.CellH
		)
		markGenerated(slot)
		slot.Parent = gridScroll
	end

	for uid, placement in pairs(placements) do
		if placement.Container == "grid" then
			local definition = config.Items[placement.DefinitionId]
			if definition then
				local width, height = InventoryCore.GetItemDimensions(definition, placement.Rotated)
				local column = (placement.Cell - 1) % config.GridColumns
				local row = math.floor((placement.Cell - 1) / config.GridColumns)
				local view = createItemView(uid, definition)
				view.Position = UDim2.fromScale(
					gridMetrics.PadX + column * gridMetrics.CellW,
					gridMetrics.PadY + row * gridMetrics.CellH
				)
				view.Size = UDim2.fromScale(width * gridMetrics.CellW, height * gridMetrics.CellH)
				view.ZIndex = 2
				view.Parent = gridScroll
			end
		end
	end

	clearGenerated(groundScroll)
	local groundEntries = {}
	for uid, placement in pairs(placements) do
		if placement.Container == "ground" then
			groundEntries[#groundEntries + 1] = { Uid = uid, Placement = placement }
		end
	end
	table.sort(groundEntries, function(a, b)
		return a.Placement.Cell < b.Placement.Cell
	end)

	local cursorColumn = 0
	local cursorRow = 0
	local rowHeight = 0
	for _, entry in groundEntries do
		local definition = config.Items[entry.Placement.DefinitionId]
		if definition then
			local width, height = InventoryCore.GetItemDimensions(definition, entry.Placement.Rotated)
			if cursorColumn + width > config.GridColumns then
				cursorColumn = 0
				cursorRow = cursorRow + rowHeight
				rowHeight = 0
			end
			local view = createItemView(entry.Uid, definition)
			view.Position = UDim2.fromScale(
				groundMetrics.PadX + cursorColumn * groundMetrics.CellW,
				groundMetrics.PadY + cursorRow * groundMetrics.CellH
			)
			view.Size = UDim2.fromScale(width * groundMetrics.CellW, height * groundMetrics.CellH)
			view.ZIndex = 2
			view.Parent = groundScroll
			cursorColumn = cursorColumn + width
			rowHeight = math.max(rowHeight, height)
		end
	end
	local groundRows = cursorRow + rowHeight
	groundScroll.CanvasSize =
		UDim2.fromScale(1, groundMetrics.PadY + math.max(groundRows, 1) * groundMetrics.CellH + groundMetrics.PadY)

	for slotId, label in equipmentSlotLabels do
		clearGenerated(label)
		for _, placement in pairs(placements) do
			if placement.Container == "equipment" and placement.Slot == slotId then
				local definition = config.Items[placement.DefinitionId]
				if definition then
					local holder = createEquippedHolder(definition)
					holder.ZIndex = 5
					holder.Parent = label
				end
				break
			end
		end
	end

	local equippedWeaponIndex = player:GetAttribute("EquippedWeaponIndex")
	for hotbarIndex, label in hotbarLabels do
		clearGenerated(label)
		for _, placement in pairs(placements) do
			if placement.Container == "hotbar" and placement.Cell == hotbarIndex then
				local definition = config.Items[placement.DefinitionId]
				if definition then
					local holder = createEquippedHolder(definition)
					holder.ZIndex = 5
					holder.Parent = label

					if definition.WeaponIndex and definition.WeaponIndex == equippedWeaponIndex then
						local selectedStroke = markGenerated(Instance.new("UIStroke"))
						selectedStroke.Color = Color3.fromRGB(255, 200, 60)
						selectedStroke.Thickness = 2
						selectedStroke.Parent = holder
					end

					local button = markGenerated(Instance.new("TextButton"))
					button.Name = "HotbarButton"
					button.Text = ""
					button.AutoButtonColor = false
					button.BackgroundTransparency = 1
					button.Size = UDim2.fromScale(1, 1)
					button.ZIndex = 6
					button.Parent = label
					button.Activated:Connect(function()
						handleHotbarClick(hotbarIndex)
					end)
				end
				break
			end
		end
	end

	renderHotbarHud()
end

local function updateViewport()
	for _, child in viewportFrame:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end

	local character = player.Character
	if not character then
		return
	end

	local characterClone = character:Clone()
	characterClone.Name = "InventoryCharacter"

	local viewportCamera = Instance.new("Camera")
	viewportCamera.Parent = viewportFrame
	viewportFrame.CurrentCamera = viewportCamera
	characterClone.Parent = viewportFrame

	local boundingCFrame, boundingSize = characterClone:GetBoundingBox()
	local distance = math.max(boundingSize.X, boundingSize.Y, boundingSize.Z) * 1.8 + 2
	local focus = boundingCFrame.Position + Vector3.new(0, boundingSize.Y * 0.05, 0)
	viewportCamera.CFrame = CFrame.lookAt(focus - boundingCFrame.LookVector * distance, focus)

	local humanoid = characterClone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R15
				and "rbxassetid://507766666"
			or "rbxassetid://180435571"
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play()
	end
end

local function setOpen(open)
	if isInventoryOpen == open then
		return
	end
	isInventoryOpen = open
	gui.Enabled = open
	player:SetAttribute("IsInventoryOpen", open)
	UserInputService.MouseIconEnabled = open
	player.CameraMode = open and Enum.CameraMode.Classic or Enum.CameraMode.LockFirstPerson

	if open then
		if not serverState then
			inventoryRemote:FireServer("request")
		end
		updateViewport()
		renderState()
	elseif dragging then
		endDrag()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == config.OpenKeyCode then
		setOpen(not isInventoryOpen)
	elseif input.KeyCode == Enum.KeyCode.R and dragging then
		rotateDraggedItem()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
		local target = dragging.Target
		if target and target.Valid then
			inventoryRemote:FireServer("move", {
				Uid = dragging.Uid,
				Container = target.Container,
				Slot = target.Slot,
				Cell = target.Cell,
				Rotated = dragging.Rotated,
			})
		end
		endDrag()
	end
end)

RunService.RenderStepped:Connect(updateDrag)

inventoryRemote.OnClientEvent:Connect(function(action, data)
	if action == "state" then
		serverState = data
		if isInventoryOpen then
			renderState()
		else
			renderHotbarHud()
		end
	end
end)

player:GetAttributeChangedSignal("EquippedWeaponIndex"):Connect(renderHotbarHud)

player.CharacterAdded:Connect(function()
	if isInventoryOpen then
		task.defer(updateViewport)
	end
end)

gui.Enabled = false
inventoryRemote:FireServer("request")
