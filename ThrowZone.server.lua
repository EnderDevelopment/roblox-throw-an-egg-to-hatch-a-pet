--!strict
-- ThrowZone.server.lua
-- Place inside the ThrowZone part in the workspace.
-- Tracks players' eggs, receives the power from the power meter, and launches
-- the egg with a trajectory toward the hatch pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CONFIG = {
	-- Name of the egg template (a Model) inside ReplicatedStorage.
	EggSource = "Egg",
	-- Name of the SpawnPoint part inside this zone part.
	SpawnPointName = "SpawnPoint",
	-- Name of the hatch pad part in the workspace.
	HatchPadName = "HatchPad",
	-- How many seconds before an unthrown egg is cleaned up.
	EggDespawnTime = 25,
	-- Minimum power (0..1) required to throw.
	MinThrowPower = 0.12,
	-- Base launch speed in studs/second at power = 1.
	LaunchSpeed = 70,
	-- Launch angle (degrees above horizontal).
	LaunchAngleDeg = 55,
	-- Speed added toward the hatch pad as a fraction of power.
	HomingFactor = 90,
}

-- Zone model containing the zone part and the player eggs.
local zoneModel = Instance.new("Model")
zoneModel.Name = "ThrowZoneModel"
zoneModel.Parent = workspace

-- Reparent the script's parent (the zone part) into the model.
local zonePart = script.Parent
zonePart.Parent = zoneModel

local spawnPoint: BasePart? = nil
local hatchPad: BasePart? = nil

-- Remotes.
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "EggThrowRemotes"
remoteFolder.Parent = ReplicatedStorage

local requestThrow = Instance.new("RemoteEvent")
requestThrow.Name = "RequestThrow"
requestThrow.Parent = remoteFolder

local throwBroadcast = Instance.new("RemoteEvent")
throwBroadcast.Name = "ThrowBroadcast"
throwBroadcast.Parent = remoteFolder

-- Locate or create the spawn point.
local function setupSpawn()
	for _, child in ipairs(zonePart:GetChildren()) do
		if child.Name == CONFIG.SpawnPointName and child:IsA("BasePart") then
			spawnPoint = child
			break
		end
	end
	if not spawnPoint then
		local point = Instance.new("Part")
		point.Name = CONFIG.SpawnPointName
		point.Anchored = true
		point.CanCollide = false
		point.Transparency = 1
		point.Size = Vector3.new(1, 1, 1)
		point.CFrame = zonePart.CFrame + Vector3.new(0, zonePart.Size.Y / 2, 1)
		point.Parent = zoneModel
		spawnPoint = point
	end
end

-- Locate the hatch pad.
local function setupHatch()
	hatchPad = workspace:FindFirstChild(CONFIG.HatchPadName)
	if hatchPad and not hatchPad:IsA("BasePart") then
		hatchPad = nil
	end
	if not hatchPad then
		warn("[ThrowZone] Could not find HatchPad in workspace.")
	end
end

-- Find the egg template model.
local function getEggTemplate(): Model?
	local source = ReplicatedStorage:FindFirstChild(CONFIG.EggSource)
	if source:IsA("Model") then
		return source
	end
	if source:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		wrapper.Name = "Egg"
		source.Parent = wrapper
		wrapper.Parent = ReplicatedStorage
		return wrapper
	end
	return nil
end

-- Grant an egg to a player at the spawn point.
local function grantEgg(player: Player)
	if not spawnPoint then
		return
	end
	local template = getEggTemplate()
	if not template then
		warn("[ThrowZone] No egg template at ReplicatedStorage." .. CONFIG.EggSource)
		return
	end

	local egg = template:Clone()
	egg.Name = "Egg_" .. player.Name
	egg.Parent = zoneModel

	for _, part in ipairs(egg:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true
			part.Massless = false
		end
	end

	-- Ensure a PrimaryPart exists so we can position and launch the egg.
	local primary = egg.PrimaryPart
	if not primary then
		primary = egg:FindFirstChildWhichIsA("BasePart")
		if primary then
			egg.PrimaryPart = primary
		end
	end

	if egg.PrimaryPart then
		egg:SetPrimaryPartCFrame(spawnPoint.CFrame)
	end

	task.delay(CONFIG.EggDespawnTime, function()
		if egg and egg.Parent then
			egg:Destroy()
		end
	end)

	throwBroadcast:FireClient(player, "granted")
end

-- Launch a player's egg with the given power (0..1).
local function launchEgg(player: Player, power: number)
	local egg = zoneModel:FindFirstChild("Egg_" .. player.Name)
	if not egg then
		return
	end
	local primary = egg.PrimaryPart
	if not primary then
		return
	end

	local launchDir = zonePart.CFrame.LookVector
	local angle = math.rad(CONFIG.LaunchAngleDeg)
	local velocity = Vector3.new(
		launchDir.X,
		math.tan(angle),
		launchDir.Z
	).Unit * CONFIG.LaunchSpeed * power

	-- If there's a hatch pad, add homing toward it.
	if hatchPad then
		local toHatch = (hatchPad.Position - primary.Position)
		toHatch = Vector3.new(toHatch.X, 0, toHatch.Z)
		if toHatch.Magnitude > 1 then
			local home = toHatch.Unit * CONFIG.HomingFactor * power
			velocity = (velocity + home) * 0.75
		end
	end

	primary.AssemblyLinearVelocity = velocity
	throwBroadcast:FireClient(player, "thrown", power)
end

-- Server event for throw requests.
requestThrow.OnServerEvent:Connect(function(player: Player, power: any)
	local p = tonumber(power)
	if not p then
		return
	end
	p = math.clamp(p, 0, 1)
	if p < CONFIG.MinThrowPower then
		return
	end
	launchEgg(player, p)
end)

-- Grant eggs to players entering/joining.
local function grantTo(player: Player)
	task.wait(0.5)
	grantEgg(player)
end

zonePart.Touched:Connect(function(other: BasePart)
	local character = other.Parent
	if not character or not character:IsA("Model") then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		grantEgg(player)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(grantTo, player)
end
Players.PlayerAdded:Connect(grantTo)

setupSpawn()
setupHatch()
print("[ThrowZone] Ready.")
