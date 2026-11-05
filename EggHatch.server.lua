--!strict
-- EggHatch.server.lua
-- Put in ServerScriptService.
-- Watches the HatchPad for eggs landing on it. When an egg rests on the pad
-- for a moment, it "hatches": the egg fades out, a burst of light appears,
-- and a pet is revealed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CONFIG = {
	-- Name of the hatch pad part in the workspace.
	HatchPadName = "HatchPad",
	-- Folder of pet models in ReplicatedStorage.
	PetsFolder = "Pets",
	-- Default pet name if no folder is found.
	DefaultPetName = "Head",
	-- How long (seconds) an egg must rest on the pad before hatching.
	HatchDelay = 1.0,
	-- Duration of the hatching flash/pet reveal animation.
	HatchTime = 0.9,
	-- How long the pet stays before fading away.
	PetShowTime = 8,
}

local hatchPad: BasePart? = workspace:FindFirstChild(CONFIG.HatchPadName)
if hatchPad and not hatchPad:IsA("BasePart") then
	hatchPad = nil
end
if not hatchPad then
	warn("[EggHatch] No HatchPad found in workspace. Script will idle.")
end

local petsFolder = ReplicatedStorage:FindFirstChild(CONFIG.PetsFolder)

-- Pick a random pet from the folder. Falls back to a default part.
local function pickPet(): Model?
	if not petsFolder then
		return nil
	end
	local pool: { Instance } = {}
	for _, child in ipairs(petsFolder:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			table.insert(pool, child)
		end
	end
	if #pool == 0 then
		return nil
	end
	local chosen = pool[math.random(1, #pool)]
	if chosen:IsA("Model") then
		return chosen
	end
	-- Wrap a single part in a model.
	local wrapper = Instance.new("Model")
	chosen.Parent = wrapper
	wrapper.Parent = workspace
	return wrapper
end

-- Hatch the egg, revealing a pet over the pad.
local function hatchEgg(egg: Model)
	if not hatchPad then
		return
	end

	local primary = egg.PrimaryPart
	if not primary then
		return
	end

	local hatchPosition = hatchPad.Position + Vector3.new(0, hatchPad.Size.Y / 2 + 2, 0)

	-- 1) Fade the egg out.
	local fadeTween = TweenService:Create(primary, TweenInfo.new(0.25), {
		Transparency = 1,
	})
	fadeTween:Play()
	task.wait(0.3)

	-- 2) Bright flash where the egg was.
	local flash = Instance.new("Part")
	flash.Name = "HatchFlash"
	flash.Anchored = true
	flash.CanCollide = false
	flash.Transparency = 0.2
	flash.Size = Vector3.new(2, 2, 2)
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 255, 150)
	flash.CFrame = CFrame.new(hatchPosition)
	flash.Parent = workspace

	local flashTween = TweenService:Create(flash, TweenInfo.new(0.4), {
		Size = Vector3.new(6, 6, 6),
		Transparency = 1,
	})
	flashTween:Play()
	Debris:AddItem(flash, 0.6)

	-- 3) Reveal the pet.
	local template = pickPet()
	local pet: Model
	if template then
		pet = template:Clone()
	else
		-- Fallback pet: a simple neon part.
		local fallback = Instance.new("Part")
		fallback.Name = "Pet"
		fallback.Shape = Enum.PartType.Ball
		fallback.Size = Vector3.one * 2
		fallback.Anchored = false
		fallback.Material = Enum.Material.Neon
		fallback.Color = Color3.fromRGB(255, 100, 200)
		pet = Instance.new("Model")
		pet.Name = CONFIG.DefaultPetName
		fallback.Parent = pet
	end

	pet.Name = template and template.Name or CONFIG.DefaultPetName
	pet.Parent = workspace
	pet.PivotTo(CFrame.new(hatchPosition))

	-- Unanchor any parts so the pet falls naturally.
	for _, part in ipairs(pet:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true
		end
	end

	-- 4) Clean up the old egg.
	egg:Destroy()

	-- Let the pet live for a while, then fade and remove it.
	task.wait(CONFIG.PetShowTime)
	if pet and pet.Parent then
		for _, part in ipairs(pet:GetDescendants()) do
			if part:IsA("BasePart") then
				local petTween = TweenService:Create(part, TweenInfo.new(0.5), {
					Transparency = 1,
				})
				petTween:Play()
			end
		end
		task.wait(0.6)
		pet:Destroy()
	end
end

-- Watch the hatch pad for eggs resting on it.
if hatchPad then
	hatchPad.Touched:Connect(function(other: BasePart)
		local egg = other.Parent
		if not egg or not egg:IsA("Model") then
			return
		end
		-- Only handle eggs (named Egg_...).
		if not string.find(egg.Name, "^Egg_") then
			return
		end
		-- Make sure it's actually resting (near-zero vertical velocity).
		local vy = other.AssemblyLinearVelocity.Y
		if math.abs(vy) > 1 then
			return
		end

		task.wait(CONFIG.HatchDelay)
		-- Confirm the egg is still present and still resting on the pad.
		if not (egg and egg.Parent) then
			return
		end
		local resting = false
		if egg.PrimaryPart then
			local dy = (egg.PrimaryPart.Position - hatchPad.Position).Magnitude
			resting = dy < hatchPad.Size.Magnitude + 8
				and math.abs(egg.PrimaryPart.AssemblyLinearVelocity.Y) < 1
		end
		if not resting then
			return
		end
		hatchEgg(egg)
	end)
end

print("[EggHatch] Ready.")
