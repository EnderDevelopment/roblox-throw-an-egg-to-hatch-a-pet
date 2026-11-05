--!strict
-- PowerMeter.client.lua
-- Put in StarterPlayer > StarterPlayerScripts.
-- Builds a power meter GUI. A moving bar sweeps back and forth; the player
-- clicks to stop it. Hitting the "sweet spot" (green zone) multiplies the
-- throw power, driving the egg much further.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CONFIG = {
	-- Time (seconds) for the bar to travel from left to right once.
	SweepTime = 1.1,
	-- Number of back-and-forth sweeps before it auto-releases.
	MaxSweeps = 8,
	-- The "sweet spot" as a fraction of the bar width (0..1). Center 0.5 is
	-- the strongest zone; the multiplier fades with distance from it.
	SweetSpotCenter = 0.5,
	SweetSpotWidth = 0.18,
	-- Maximum throw power multiplier at the exact center of the sweet spot.
	SweetSpotBonus = 2.2,
	-- Base power reached at the far edges of the bar.
	BaseMinPower = 0.25,
	BaseMaxPower = 0.8,
	-- Screen position/size of the meter (ScrollingFrame-like free GUI).
	MeterPosition = UDim2.new(0.5, -200, 0.85, 0),
	MeterSize = UDim2.new(0, 400, 0, 40),
}

-- Remote used to request a throw.
local remoteFolder = ReplicatedStorage:WaitForChild("EggThrowRemotes")
local requestThrow = remoteFolder:WaitForChild("RequestThrow")

-- Build the GUI if it doesn't exist. Returns the ScreenGui with the meter.
local meterGui: ScreenGui
local function ensureGui()
	local existing = playerGui:FindFirstChild("EggPowerMeter")
	if existing and existing:IsA("ScreenGui") then
		meterGui = existing
		return
	end

	meterGui = Instance.new("ScreenGui")
	meterGui.Name = "EggPowerMeter"
	meterGui.ResetOnSpawn = false
	meterGui.IgnoreGuiInset = true
	meterGui.Parent = playerGui

	-- Background frame for the meter.
	local frame = Instance.new("Frame")
	frame.Name = "MeterFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = CONFIG.MeterPosition
	frame.Size = CONFIG.MeterSize
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	frame.BorderSizePixel = 3
	frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	frame.Parent = meterGui

	-- Green sweet-spot zone.
	local sweetSpot = Instance.new("Frame")
	sweetSpot.Name = "SweetSpot"
	sweetSpot.AnchorPoint = Vector2.new(CONFIG.SweetSpotCenter, 0)
	sweetSpot.Position = UDim2.new(CONFIG.SweetSpotCenter, 0, 0, 0)
	sweetSpot.Size = UDim2.new(CONFIG.SweetSpotWidth, 0, 1, 0)
	sweetSpot.BorderSizePixel = 0
	sweetSpot.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
	sweetSpot.BackgroundTransparency = 0.5
	sweetSpot.Parent = frame

	-- The moving bar.
	local bar = Instance.new("Frame")
	bar.Name = "MeterBar"
	bar.AnchorPoint = Vector2.new(0, 0)
	bar.Position = UDim2.new(0, 0, 0, 0)
	bar.Size = UDim2.new(0, 12, 1, -6)
	bar.Position = UDim2.new(0, 0, 0, 3)
	bar.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
	bar.BorderSizePixel = 0
	bar.Parent = frame
end

ensureGui()

local function getFrame(): Frame?
	local screen = meterGui:FindFirstChild("MeterFrame")
	if screen and screen:IsA("Frame") then
		return screen
	end
	return nil
end

local function getBar(): Frame?
	local frame = getFrame()
	return frame and frame:FindFirstChild("MeterBar") as Frame?
end

-- State of the sweep.
local barX = 0
local direction = 1
local sweeping = false
local completedSweeps = 0

-- Compute the current power fraction (0..1) from the bar position.
local function currentPower(): number
	local frame = getFrame()
	if not frame then
		return 0.5
	end
	local width = frame.AbsoluteSize.X
	if width <= 0 then
		return 0.5
	end
	return math.clamp(barX / width, 0, 1)
end

-- Compute effective throw power from a stopped bar position.
local function computeThrowPower(barFraction: number): number
	local normalized = math.clamp(barFraction, 0, 1)

	-- Distance from sweet-spot center.
	local dist = math.abs(normalized - CONFIG.SweetSpotCenter)

	-- Base power scales across the bar.
	local base = CONFIG.BaseMinPower
		+ (CONFIG.BaseMaxPower - CONFIG.BaseMinPower) * normalized

	-- Bonus fades to 1 outside the sweet spot, up to SweetSpotBonus in the center.
	local inside = dist <= CONFIG.SweetSpotWidth / 2
	local strength = inside and (1 - dist / (CONFIG.SweetSpotWidth / 2)) or 0
	local multiplier = 1 + strength * (CONFIG.SweetSpotBonus - 1)

	return math.clamp(base * multiplier, 0, 1)
end

-- Fire the throw request with the computed power.
local function releaseThrow()
	local power = computeThrowPower(currentPower())
	requestThrow:FireServer(power)
	hideMeter()
end

-- Track the bar's current X position live during the tween.
-- The moving bar. As it tweens, keep barX in sync.
local function doSweep()
	local frame = getFrame()
	local bar = getBar()
	if not frame or not bar then
		return
	end
	local width = frame.AbsoluteSize.X
	local barW = bar.AbsoluteSize.X
	local maxX = math.max(0, width - barW)

	local targetX = direction > 0 and maxX or 0

	-- Continuously read the bar's rendered position into barX.
	local readConn
	readConn = bar:GetPropertyChangedSignal("Position"):Connect(function()
		barX = bar.Position.X.Offset
		if not sweeping then
			readConn:Disconnect()
		end
	end)

	local tween = TweenService:Create(bar, TweenInfo.new(CONFIG.SweepTime, Enum.EasingStyle.Linear), {
		Position = UDim2.new(0, targetX, 0, 3),
	})

	tween:Play()
	tween.Completed:Connect(function()
		if not sweeping then
			return
		end
		local finalX = targetX
		barX = finalX
		completedSweeps += 1

		if completedSweeps >= CONFIG.MaxSweeps then
			sweeping = false
			if readConn then
				readConn:Disconnect()
			end
			releaseThrow()
			return
		end

		-- Reverse direction and continue.
		direction = -direction
		task.delay(0.04, doSweep)
	end)
end

local function startSweep()
	local bar = getBar()
	if not bar or sweeping then
		return
	end
	sweeping = true
	completedSweeps = 0
	barX = 0
	direction = 1
	bar.Position = UDim2.new(0, 0, 0, 3)
	doSweep()
end

local function showMeter()
	meterGui.Enabled = true
end

local function hideMeter()
	meterGui.Enabled = false
	sweeping = false
end

-- Initial state: hidden until the server grants an egg.
hideMeter()

-- Listen for the server's "granted" / "thrown" broadcasts.
local throwBroadcast = remoteFolder:WaitForChild("ThrowBroadcast")
throwBroadcast.OnClientEvent:Connect(function(action: string)
	if action == "granted" then
		showMeter()
		startSweep()
	elseif action == "thrown" then
		hideMeter()
	end
end)

-- Turning on the meter also lets the player click to stop.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		if sweeping then
			sweeping = false
			releaseThrow()
		end
	end
end)

print("[PowerMeter] Ready by", player.Name)
