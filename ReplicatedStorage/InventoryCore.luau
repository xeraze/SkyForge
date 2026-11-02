local InventoryCore = {}

function InventoryCore.GetItemDimensions(itemDefinition: any, isRotated: boolean): (number, number)
	if isRotated then
		return itemDefinition.Height, itemDefinition.Width
	end
	return itemDefinition.Width, itemDefinition.Height
end

function InventoryCore.GetRectCells(startCell: number, width: number, height: number, columns: number): { number }?
	local startColumn = (startCell - 1) % columns + 1
	if startColumn + width - 1 > columns then
		return nil
	end
	local cells = {}
	for rowOffset = 0, height - 1 do
		for columnOffset = 0, width - 1 do
			cells[#cells + 1] = startCell + rowOffset * columns + columnOffset
		end
	end
	return cells
end

function InventoryCore.GetEquippedDefinitionIds(placements: { [string]: any }): { string }
	local definitionIds = {}
	for _, placement in pairs(placements) do
		if placement.Container == "equipment" then
			definitionIds[#definitionIds + 1] = placement.DefinitionId
		end
	end
	return definitionIds
end

function InventoryCore.GetCapacity(config: any, placements: { [string]: any }): number
	local capacityCells = config.BaseCells
	for _, definitionId in InventoryCore.GetEquippedDefinitionIds(placements) do
		local definition = config.Items[definitionId]
		if definition and definition.CellsBonus then
			capacityCells = capacityCells + definition.CellsBonus
		end
	end
	return capacityCells
end

function InventoryCore.GetRows(config: any, capacityCells: number): number
	return math.ceil(capacityCells / config.GridColumns)
end

function InventoryCore.BuildOccupancy(placements: { [string]: any }, containerName: string, config: any): { [number]: string }
	local occupancy = {}
	for uid, placement in pairs(placements) do
		if placement.Container == containerName then
			if containerName == "grid" then
				local definition = config.Items[placement.DefinitionId]
				if definition then
					local width, height = InventoryCore.GetItemDimensions(definition, placement.Rotated)
					local cells = InventoryCore.GetRectCells(placement.Cell, width, height, config.GridColumns)
					if cells then
						for _, cell in cells do
							occupancy[cell] = uid
						end
					end
				end
			else
				occupancy[placement.Cell] = uid
			end
		end
	end
	return occupancy
end

function InventoryCore.CanPlaceInContainer(
	placements: { [string]: any },
	config: any,
	containerName: string,
	startCell: number,
	definitionId: string,
	isRotated: boolean,
	excludedUid: string?,
	capacityCells: number?
): boolean
	local definition = config.Items[definitionId]
	if not definition or startCell < 1 or startCell % 1 ~= 0 then
		return false
	end

	if containerName == "grid" then
		local capacity = capacityCells or InventoryCore.GetCapacity(config, placements)
		local width, height = InventoryCore.GetItemDimensions(definition, isRotated)
		local cells = InventoryCore.GetRectCells(startCell, width, height, config.GridColumns)
		if not cells then
			return false
		end
		local occupancy = InventoryCore.BuildOccupancy(placements, "grid", config)
		for _, cell in cells do
			if cell > capacity then
				return false
			end
			local occupant = occupancy[cell]
			if occupant ~= nil and occupant ~= excludedUid then
				return false
			end
		end
		return true
	end

	if containerName == "hotbar" then
		if startCell > config.HotbarSize then
			return false
		end
		if not config.HotbarAcceptedTypes[definition.Type] then
			return false
		end
		local occupancy = InventoryCore.BuildOccupancy(placements, "hotbar", config)
		local occupant = occupancy[startCell]
		return occupant == nil or occupant == excludedUid
	end

	if containerName == "ground" then
		return true
	end

	return false
end

function InventoryCore.CanEquipItem(
	config: any,
	placements: { [string]: any },
	slotId: string,
	definitionId: string,
	excludedUid: string?
): boolean
	local slotDefinition
	for _, equipmentSlot in config.EquipmentSlots do
		if equipmentSlot.Id == slotId then
			slotDefinition = equipmentSlot
			break
		end
	end
	if not slotDefinition then
		return false
	end

	local definition = config.Items[definitionId]
	if not definition or not slotDefinition.AcceptedTypes[definition.Type] then
		return false
	end

	for uid, placement in pairs(placements) do
		if placement.Container == "equipment" and placement.Slot == slotId and uid ~= excludedUid then
			return false
		end
	end
	return true
end

function InventoryCore.FindFreeStartCell(
	placements: { [string]: any },
	config: any,
	definitionId: string,
	isRotated: boolean,
	capacityCells: number
): number?
	local definition = config.Items[definitionId]
	if not definition then
		return nil
	end
	for startCell = 1, capacityCells do
		if InventoryCore.CanPlaceInContainer(placements, config, "grid", startCell, definitionId, isRotated, nil, capacityCells) then
			return startCell
		end
	end
	return nil
end

return InventoryCore
