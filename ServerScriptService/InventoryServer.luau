local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local config = require(ReplicatedStorage:WaitForChild("InventoryConfig"))
local InventoryCore = require(ReplicatedStorage:WaitForChild("InventoryCore"))

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

local inventoryRemote = getOrCreateRemote("InventoryRemote")

local playerStates: { [Player]: any } = {}

local function createState()
	return { Placements = {}, NextUid = 1 }
end

local function addPlacement(state: any, definitionId: string, containerName: string, cell: number, slotId: string?, isRotated: boolean)
	local uid = "item" .. state.NextUid
	state.NextUid = state.NextUid + 1
	state.Placements[uid] = {
		DefinitionId = definitionId,
		Container = containerName,
		Slot = slotId,
		Cell = cell,
		Rotated = isRotated,
	}
	return uid
end

local function getNextGroundCell(state: any): number
	local highestCell = 0
	for _, placement in pairs(state.Placements) do
		if placement.Container == "ground" and placement.Cell > highestCell then
			highestCell = placement.Cell
		end
	end
	return highestCell + 1
end

local function buildStartingState(state: any)
	for hotbarIndex, definitionId in config.StartingHotbar do
		if config.Items[definitionId] and hotbarIndex <= config.HotbarSize then
			addPlacement(state, definitionId, "hotbar", hotbarIndex, nil, false)
		end
	end

	for slotId, definitionId in config.StartingEquipment do
		if config.Items[definitionId] and InventoryCore.CanEquipItem(config, state.Placements, slotId, definitionId, nil) then
			addPlacement(state, definitionId, "equipment", 1, slotId, false)
		end
	end

	for _, definitionId in config.StartingItems do
		if config.Items[definitionId] then
			local capacityCells = InventoryCore.GetCapacity(config, state.Placements)
			local startCell = InventoryCore.FindFreeStartCell(state.Placements, config, definitionId, false, capacityCells)
			if startCell then
				addPlacement(state, definitionId, "grid", startCell, nil, false)
			else
				addPlacement(state, definitionId, "ground", getNextGroundCell(state), nil, false)
			end
		end
	end
end

local function sendState(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end
	inventoryRemote:FireClient(player, "state", {
		Placements = state.Placements,
		CapacityCells = InventoryCore.GetCapacity(config, state.Placements),
	})
end

local function handleMoveRequest(player: Player, data: any)
	local state = playerStates[player]
	if not state or type(data) ~= "table" then
		return
	end

	local uid = data.Uid
	if type(uid) ~= "string" then
		return
	end
	local placement = state.Placements[uid]
	if not placement then
		return
	end

	local containerName = data.Container
	if type(containerName) ~= "string" then
		return
	end

	local isRotated = data.Rotated == true
	local targetCell = tonumber(data.Cell)
	if targetCell then
		targetCell = math.floor(targetCell)
	end

	if containerName == "equipment" then
		local slotId = data.Slot
		if type(slotId) ~= "string" then
			return
		end
		if not InventoryCore.CanEquipItem(config, state.Placements, slotId, placement.DefinitionId, uid) then
			sendState(player)
			return
		end
		placement.Container = "equipment"
		placement.Slot = slotId
		placement.Cell = 1
		placement.Rotated = false
	elseif containerName == "hotbar" or containerName == "grid" then
		if not targetCell then
			return
		end
		local capacityCells = InventoryCore.GetCapacity(config, state.Placements)
		local accepted = InventoryCore.CanPlaceInContainer(
			state.Placements,
			config,
			containerName,
			targetCell,
			placement.DefinitionId,
			isRotated,
			uid,
			capacityCells
		)
		if not accepted then
			sendState(player)
			return
		end
		placement.Container = containerName
		placement.Slot = nil
		placement.Cell = targetCell
		placement.Rotated = isRotated
	elseif containerName == "ground" then
		placement.Container = "ground"
		placement.Slot = nil
		placement.Cell = getNextGroundCell(state)
		placement.Rotated = isRotated
	else
		return
	end

	sendState(player)
end

local function onPlayerAdded(player: Player)
	local state = createState()
	buildStartingState(state)
	playerStates[player] = state
	sendState(player)
end

inventoryRemote.OnServerEvent:Connect(function(player: Player, action: any, data: any)
	if action == "move" then
		handleMoveRequest(player, data)
	elseif action == "request" then
		sendState(player)
	end
end)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player: Player)
	playerStates[player] = nil
end)
