local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DOOR_TAG = "FalloutDoor"
local SLIDE_DISTANCE = 13
local SLIDE_DURATION = 3.0
local OPEN_DELAY = 0.5
local ROTATION_DEGREES = 360
local CHECK_INTERVAL = 0.1
local EASING_STYLE = Enum.EasingStyle.Linear

type DoorState = {
	doorPart: BasePart,
	triggerPart: BasePart,
	closedCFrame: CFrame,
	slideDistance: number,
	rotationDegrees: number,
	isOpen: boolean,
	alpha: NumberValue,
	currentTween: Tween?,
}

local function isPlayerInside(triggerPart: BasePart): boolean
	local overlapParameters = OverlapParams.new()
	overlapParameters.FilterType = Enum.RaycastFilterType.Exclude
	overlapParameters.FilterDescendantsInstances = { triggerPart }

	local overlappingParts = workspace:GetPartBoundsInBox(
		triggerPart.CFrame,
		triggerPart.Size,
		overlapParameters
	)

	for _, part in overlappingParts do
		local character = part:FindFirstAncestorOfClass("Model")

		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid and humanoid.Health > 0 and Players:GetPlayerFromCharacter(character) then
				return true
			end
		end
	end

	return false
end

local function setDoorOpen(state: DoorState, shouldOpen: boolean)
	if state.isOpen == shouldOpen then
		return
	end

	state.isOpen = shouldOpen

	if state.currentTween then
		state.currentTween:Cancel()
	end

	local targetValue = if shouldOpen then 1 else 0
	local startValue = state.alpha.Value
	local remainingRatio = math.abs(targetValue - startValue)
	local duration = SLIDE_DURATION * remainingRatio

	if duration <= 0 then
		return
	end

	local easingDirection = if shouldOpen then Enum.EasingDirection.Out else Enum.EasingDirection.In

	local tween = TweenService:Create(
		state.alpha,
		TweenInfo.new(duration, EASING_STYLE, easingDirection),
		{ Value = targetValue }
	)

	state.currentTween = tween
	tween:Play()
end

local function prepareDoorPart(doorInstance: Instance): BasePart?
	if doorInstance:IsA("BasePart") then
		doorInstance.Anchored = true
		return doorInstance
	elseif doorInstance:IsA("Model") then
		local boundingCFrame = doorInstance:GetBoundingBox()
		local referencePart = doorInstance.PrimaryPart or doorInstance:FindFirstChildWhichIsA("BasePart", true)
		local doorRotation = if referencePart then referencePart.CFrame.Rotation else CFrame.identity

		local centerPart = Instance.new("Part")
		centerPart.Name = "AutoCenterPivot"
		centerPart.Size = Vector3.new(1, 1, 1)
		centerPart.Transparency = 1
		centerPart.CanCollide = false
		centerPart.Anchored = true
		centerPart.CFrame = CFrame.new(boundingCFrame.Position) * doorRotation
		centerPart.Parent = doorInstance

		doorInstance.PrimaryPart = centerPart

		for _, descendant in doorInstance:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= centerPart then
				descendant.Anchored = false

				local hasWeld = false
				for _, child in descendant:GetChildren() do
					if child:IsA("WeldConstraint") or child:IsA("Weld") or child:IsA("ManualWeld") then
						hasWeld = true
						break
					end
				end

				if not hasWeld then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = centerPart
					weld.Part1 = descendant
					weld.Parent = descendant
				end
			end
		end

		return centerPart
	end

	return nil
end

local function setupDoor(doorModel: Model)
	task.spawn(function()
		local rawDoor = doorModel:WaitForChild("Door", 5)
		local triggerPart = doorModel:WaitForChild("Trigger", 5) :: BasePart

		if not rawDoor or not triggerPart then
			return
		end

		local doorPart = prepareDoorPart(rawDoor)
		if not doorPart then
			return
		end

		local slideDistance = doorModel:GetAttribute("SlideDistance") or SLIDE_DISTANCE
		local openDelay = doorModel:GetAttribute("OpenDelay") or OPEN_DELAY
		local rotationDegrees = doorModel:GetAttribute("RotationDegrees") or ROTATION_DEGREES

		triggerPart.Anchored = true
		triggerPart.CanCollide = false
		triggerPart.CanTouch = false
		triggerPart.Transparency = 1

		local alpha = Instance.new("NumberValue")
		alpha.Value = 0

		local closedCFrame = doorPart.CFrame

		local state: DoorState = {
			doorPart = doorPart,
			triggerPart = triggerPart,
			closedCFrame = closedCFrame,
			slideDistance = slideDistance,
			rotationDegrees = rotationDegrees,
			isOpen = false,
			alpha = alpha,
			currentTween = nil,
		}

		alpha.Changed:Connect(function(value)
			local translation = CFrame.new(-state.slideDistance * value, 0, 0)
			local rotation = CFrame.Angles(0, 0, math.rad(state.rotationDegrees * value))
			state.doorPart.CFrame = state.closedCFrame * translation * rotation
		end)

		local triggerStartTime: number? = nil

		while doorModel.Parent do
			local playerInside = isPlayerInside(triggerPart)

			if playerInside then
				if not state.isOpen then
					if not triggerStartTime then
						triggerStartTime = os.clock()
					elseif os.clock() - triggerStartTime >= openDelay then
						setDoorOpen(state, true)
					end
				else
					triggerStartTime = nil
				end
			else
				triggerStartTime = nil
				if state.isOpen then
					setDoorOpen(state, false)
				end
			end

			task.wait(CHECK_INTERVAL)
		end

		alpha:Destroy()
	end)
end

for _, doorModel in CollectionService:GetTagged(DOOR_TAG) do
	setupDoor(doorModel)
end

CollectionService:GetInstanceAddedSignal(DOOR_TAG):Connect(function(instance)
	setupDoor(instance :: Model)
end)
