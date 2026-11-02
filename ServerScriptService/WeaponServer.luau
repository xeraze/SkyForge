local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local config = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local weaponEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponEvent")

local playerStates = {}

local function initializePlayer(player)
	local weaponsState = {}
	for index, weapon in ipairs(config) do
		weaponsState[index] = {
			ammo = weapon.mag,
			lastShot = 0,
			reloading = false,
		}
	end
	playerStates[player] = weaponsState
end

Players.PlayerAdded:Connect(initializePlayer)
for _, player in Players:GetPlayers() do
	initializePlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

local function applySpread(baseDirection, spreadDegrees)
	if spreadDegrees <= 0 then
		return baseDirection
	end

	local spreadRadians = math.rad(spreadDegrees)
	local baseCFrame = CFrame.lookAt(Vector3.zero, baseDirection)
	local angle = math.random() * math.pi * 2
	local offset = math.sqrt(math.random()) * math.tan(spreadRadians)

	return (baseCFrame * CFrame.new(math.cos(angle) * offset, math.sin(angle) * offset, -1)).Position.Unit
end

weaponEvent.OnServerEvent:Connect(function(player, action, weaponId, origin, lookDirection)
	local weaponsState = playerStates[player]
	local weapon = config[weaponId]
	if not weaponsState or not weapon then
		return
	end

	local weaponState = weaponsState[weaponId]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if action == "reload" then
		if weaponState.reloading or weaponState.ammo >= weapon.mag then
			return
		end

		weaponState.reloading = true
		task.delay(weapon.reload, function()
			if playerStates[player] then
				weaponState.ammo = weapon.mag
				weaponState.reloading = false
				weaponEvent:FireClient(player, "ammo", weaponId, weaponState.ammo)
			end
		end)
		return
	end

	if action ~= "fire" then
		return
	end
	if typeof(origin) ~= "Vector3" or typeof(lookDirection) ~= "Vector3" then
		return
	end
	if lookDirection.Magnitude < 0.001 then
		return
	end
	if weaponState.reloading or weaponState.ammo <= 0 then
		return
	end

	local currentTime = os.clock()
	if currentTime - weaponState.lastShot < weapon.rate * 0.9 then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or (origin - rootPart.Position).Magnitude > 12 then
		return
	end

	weaponState.lastShot = currentTime
	weaponState.ammo -= 1
	weaponEvent:FireClient(player, "ammo", weaponId, weaponState.ammo)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local accumulatedDamage = {}
	for _ = 1, weapon.pellets do
		local direction = applySpread(lookDirection.Unit, weapon.spread)
		local result = workspace:Raycast(origin, direction * weapon.range, raycastParams)
		if result then
			local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
			local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
			if hitHumanoid and hitHumanoid.Health > 0 then
				local damageMultiplier = result.Instance.Name == "Head" and 2 or 1
				accumulatedDamage[hitHumanoid] = (accumulatedDamage[hitHumanoid] or 0) + weapon.dmg * damageMultiplier
			end
		end
	end

	for hitHumanoid, damage in accumulatedDamage do
		hitHumanoid:TakeDamage(damage)
	end
end)
