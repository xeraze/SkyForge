local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local config = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local weaponEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponEvent")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local currentWeaponIndex = 1
local ammoCounts = {}
for index, weapon in ipairs(config) do
	ammoCounts[index] = weapon.mag
end

local lastShotTime = 0
local isReloading = false
local isAiming = false
local isHoldingFire = false
local recoilOffset = 0
local recoilVelocity = 0
local swayTime = 0
local viewModel = nil
local viewModelParts = {}
local defaultFieldOfView = 70

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size = UDim2.fromOffset(200, 40)
ammoLabel.Position = UDim2.new(1, -220, 1, -60)
ammoLabel.BackgroundTransparency = 1
ammoLabel.TextColor3 = Color3.new(1, 1, 1)
ammoLabel.TextSize = 28
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
ammoLabel.Parent = screenGui

local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.fromOffset(6, 6)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
crosshair.BorderSizePixel = 0
crosshair.Parent = screenGui

local scopeOverlay = Instance.new("Frame")
scopeOverlay.Size = UDim2.fromScale(1, 1)
scopeOverlay.BackgroundTransparency = 1
scopeOverlay.Visible = false
scopeOverlay.Parent = screenGui
for _, overlayData in ipairs({
	{ UDim2.new(0.5, -1, 0, 0), UDim2.new(0, 2, 1, 0) },
	{ UDim2.new(0, 0, 0.5, -1), UDim2.new(1, 0, 0, 2) },
}) do
	local bar = Instance.new("Frame")
	bar.Position = overlayData[1]
	bar.Size = overlayData[2]
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BorderSizePixel = 0
	bar.Parent = scopeOverlay
end

local function updateAmmoLabel()
	local weapon = config[currentWeaponIndex]
	ammoLabel.Text = weapon.name .. "  " .. ammoCounts[currentWeaponIndex] .. "/" .. weapon.mag
end

local function createViewModelPart(size, color, parent)
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function buildViewModel()
	if viewModel then
		viewModel:Destroy()
	end

	local weapon = config[currentWeaponIndex]
	viewModel = Instance.new("Model")
	viewModel.Name = "ViewModel"
	viewModelParts = {}
	viewModelParts.gun = createViewModelPart(weapon.size, weapon.color, viewModel)
	viewModelParts.frontArm = createViewModelPart(Vector3.new(0.3, 0.3, 1.2), Color3.fromRGB(230, 185, 150), viewModel)
	viewModelParts.backArm = createViewModelPart(Vector3.new(0.3, 0.3, 1.2), Color3.fromRGB(230, 185, 150), viewModel)
	viewModel.Parent = camera
end

local hipOffset = CFrame.new(0.9, -0.8, -1.6)
local aimOffset = CFrame.new(0, -0.45, -1.4)
local currentViewOffset = hipOffset

local function equipWeapon(index)
	if not config[index] then
		return
	end

	currentWeaponIndex = index
	isReloading = false
	isAiming = false
	buildViewModel()
	updateAmmoLabel()
end

player:GetAttributeChangedSignal("EquippedWeaponIndex"):Connect(function()
	local weaponIndex = player:GetAttribute("EquippedWeaponIndex")
	if typeof(weaponIndex) == "number" and config[weaponIndex] then
		equipWeapon(weaponIndex)
	end
end)

local function setEquippedWeapon(weaponIndex)
	if not config[weaponIndex] then
		return
	end
	if player:GetAttribute("EquippedWeaponIndex") == weaponIndex then
		equipWeapon(weaponIndex)
	else
		player:SetAttribute("EquippedWeaponIndex", weaponIndex)
	end
end

local function fireWeapon()
	local weapon = config[currentWeaponIndex]
	local currentTime = os.clock()
	if isReloading or ammoCounts[currentWeaponIndex] <= 0 or currentTime - lastShotTime < weapon.rate then
		return
	end

	lastShotTime = currentTime
	ammoCounts[currentWeaponIndex] -= 1
	updateAmmoLabel()
	weaponEvent:FireServer("fire", currentWeaponIndex, camera.CFrame.Position, camera.CFrame.LookVector)
	recoilVelocity += weapon.recoil

	if ammoCounts[currentWeaponIndex] <= 0 then
		weaponEvent:FireServer("reload", currentWeaponIndex)
		isReloading = true
	end
end

local function reloadWeapon()
	if isReloading or ammoCounts[currentWeaponIndex] >= config[currentWeaponIndex].mag then
		return
	end

	isReloading = true
	weaponEvent:FireServer("reload", currentWeaponIndex)
end

weaponEvent.OnClientEvent:Connect(function(action, weaponId, newAmmoCount)
	if action == "ammo" then
		ammoCounts[weaponId] = newAmmoCount
		if weaponId == currentWeaponIndex then
			if newAmmoCount == config[currentWeaponIndex].mag then
				isReloading = false
			end
			updateAmmoLabel()
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isHoldingFire = true
		fireWeapon()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		isAiming = true
	elseif input.KeyCode == Enum.KeyCode.R then
		reloadWeapon()
	elseif input.KeyCode == Enum.KeyCode.One then
		setEquippedWeapon(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		setEquippedWeapon(2)
	elseif input.KeyCode == Enum.KeyCode.Three then
		setEquippedWeapon(3)
	elseif input.KeyCode == Enum.KeyCode.Four then
		setEquippedWeapon(4)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isHoldingFire = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		isAiming = false
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	local weapon = config[currentWeaponIndex]
	if isHoldingFire and weapon.auto then
		fireWeapon()
	end

	recoilVelocity = recoilVelocity * math.exp(-12 * deltaTime)
	recoilOffset = recoilOffset + (recoilVelocity - recoilOffset) * math.min(deltaTime * 20, 1)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local isMoving = humanoid and humanoid.MoveDirection.Magnitude > 0
	swayTime += deltaTime * (isMoving and 8 or 1.5)

	local swayAmplitude = isMoving and 0.03 or 0.005
	local sway = CFrame.new(
		math.sin(swayTime) * swayAmplitude,
		math.abs(math.cos(swayTime)) * swayAmplitude,
		0
	)

	local targetOffset = isAiming and aimOffset or hipOffset
	currentViewOffset = currentViewOffset:Lerp(targetOffset, math.min(deltaTime * 14, 1))

	local kick = CFrame.new(0, 0, recoilOffset * 0.04) * CFrame.Angles(math.rad(recoilOffset * 1.5), 0, 0)

	local reloadSwing = 0
	if isReloading then
		reloadSwing = math.sin(os.clock() * 6) * 0.15 + 0.5
	end

	local viewModelCFrame = camera.CFrame
		* currentViewOffset
		* sway
		* kick
		* CFrame.Angles(math.rad(-reloadSwing * 40), 0, 0)
		* CFrame.new(0, -reloadSwing * 0.3, 0)

	if viewModelParts.gun then
		viewModelParts.gun.CFrame = viewModelCFrame
		viewModelParts.frontArm.CFrame = viewModelCFrame * CFrame.new(0.25, -0.25, 0.4) * CFrame.Angles(math.rad(-10), 0, 0)
		viewModelParts.backArm.CFrame = viewModelCFrame * CFrame.new(-0.25, -0.2, -0.3) * CFrame.Angles(math.rad(-10), 0, 0)
	end

	local targetFieldOfView = isAiming and weapon.fov or defaultFieldOfView
	camera.FieldOfView += (targetFieldOfView - camera.FieldOfView) * math.min(deltaTime * 12, 1)

	local isScoped = isAiming and currentWeaponIndex == 4
	scopeOverlay.Visible = isScoped
	crosshair.Visible = not isScoped
	if viewModel then
		for _, part in viewModelParts do
			part.LocalTransparencyModifier = isScoped and 1 or 0
		end
	end

	camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(recoilOffset * 0.08), 0, 0)
end)

player.CharacterAdded:Connect(function()
	for index, weapon in ipairs(config) do
		ammoCounts[index] = weapon.mag
	end
	isReloading = false
	buildViewModel()
	updateAmmoLabel()
end)

UserInputService.MouseIconEnabled = false
player.CameraMode = Enum.CameraMode.LockFirstPerson
setEquippedWeapon(1)