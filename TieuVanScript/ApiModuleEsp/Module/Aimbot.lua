local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
	Enabled = false,
	FOVSize = 100,
	Speed = 0.5,
	MaxRange = 5000,
	TeamCheck = false,
	WallCheck = false,
	AimPart = "Head",
	PredictionEnabled = false,
	PredictionFactor = 0.12,
	OffsetY = 0,
	FOVOffsetY = 0,
	LockTarget = false,
	SwitchKey = Enum.KeyCode.E,
	FOVColor = Color3.fromRGB(255, 255, 255),
}

local LockedTarget = nil
local LastTargetCheck = 0
local TARGET_CHECK_INTERVAL = 0.1
local VelocityCache = {}

--=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================

local function GetCharacter(player)
	return player and player.Character
end

local function GetCharacterPart(player, partName)
	if not partName then return nil end
	local char = GetCharacter(player)
	return char and char:FindFirstChild(partName)
end

local function GetHumanoid(player)
	local char = GetCharacter(player)
	return char and (char:FindFirstChild("Humanoid") or char:FindFirstChildOfClass("Humanoid"))
end

local function GetLocalHRP()
	return GetCharacterPart(LocalPlayer, "HumanoidRootPart")
end

local function GetTargetPart(player)
	local targetPart = GetCharacterPart(player, CONFIG.AimPart)
	if not targetPart and (CONFIG.AimPart == "UpperTorso" or CONFIG.AimPart == "LowerTorso") then
		targetPart = GetCharacterPart(player, "Torso")
	end
	return targetPart
end

local function GetScreenPosition(position)
	local screenPos, onScreen = Camera:WorldToScreenPoint(position)
	return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetScreenCenter()
	return Vector2.new(Camera.ViewportSize.X / 2.0, Camera.ViewportSize.Y / 2.0 + CONFIG.FOVOffsetY)
end

local function GetAngularDistance(position)
	local camPos = Camera.CFrame.Position
	local camLook = Camera.CFrame.LookVector
	local toTarget = (position - camPos).Unit
	
	local dot = camLook:Dot(toTarget)
	dot = math.clamp(dot, -1, 1)
	local angle = math.acos(dot)
	local angleDegrees = math.deg(angle)
	
	return angleDegrees
end

local function GetFOVAngleFromPixels()
	local viewportSize = Camera.ViewportSize
	local halfFOV = math.rad(Camera.FieldOfView / 2)
	local pixelsPerDegree = (viewportSize.Y / 2) / math.deg(halfFOV)
	return CONFIG.FOVSize / pixelsPerDegree
end

local function IsVisibleTarget(player)
	if not CONFIG.WallCheck then return true end
	
	local targetPart = GetTargetPart(player)
	if not targetPart then return false end
	
	local origin = Camera.CFrame.Position
	local targetPos = targetPart.Position
	local direction = targetPos - origin
	local distance = direction.Magnitude
	
	if distance < 1 then return true end
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {GetCharacter(LocalPlayer), GetCharacter(player)}
	rayParams.IgnoreWater = true
	
	local result = Workspace:Raycast(origin, direction.Unit * (distance - 1), rayParams)
	return result == nil
end

local function IsValidTarget(player, skipFOVCheck)
	if not player or player == LocalPlayer then return false end
	
	local char = GetCharacter(player)
	if not char then return false end
	if not char:IsDescendantOf(Workspace) then return false end
	
	local hrp = GetCharacterPart(player, "HumanoidRootPart")
	if not hrp then return false end
	
	local hum = GetHumanoid(player)
	if not hum or hum.Health <= 0 then return false end
	
	if CONFIG.TeamCheck then
		if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
			return false
		end
	end
	
	local localHRP = GetLocalHRP()
	if not localHRP then return false end
	
	local targetPart = GetTargetPart(player)
	if not targetPart then return false end
	
	local worldDist = (targetPart.Position - localHRP.Position).Magnitude
	if worldDist > CONFIG.MaxRange then return false end
	
	if not skipFOVCheck then
		local angularDist = GetAngularDistance(targetPart.Position)
		local fovAngle = GetFOVAngleFromPixels()
		if angularDist > fovAngle then return false end
	end
	
	if CONFIG.WallCheck and not IsVisibleTarget(player) then
		return false
	end
	
	return true
end

--=============================================================================
-- VELOCITY & PREDICTION
--=============================================================================

local function CalculateVelocity(player, currentPos)
	local cache = VelocityCache[player]
	local now = tick()
	
	if not cache then
		VelocityCache[player] = {
			Position = currentPos,
			Time = now,
			Velocity = Vector3.zero
		}
		return Vector3.zero
	end
	
	local deltaTime = now - cache.Time
	if deltaTime < 0.016 then
		return cache.Velocity
	end
	
	local velocity = (currentPos - cache.Position) / deltaTime
	
	VelocityCache[player] = {
		Position = currentPos,
		Time = now,
		Velocity = velocity
	}
	
	return velocity
end

local function PredictPosition(player, targetPart)
	if not CONFIG.PredictionEnabled then return targetPart.Position end
	if not targetPart then return targetPart.Position end
	
	local currentPos = targetPart.Position
	local velocity = CalculateVelocity(player, currentPos)
	
	return currentPos + velocity * CONFIG.PredictionFactor
end

--=============================================================================
-- TARGET SELECTION
--=============================================================================

local function GetClosestTarget()
	local bestTarget = nil
	local bestDistance = math.huge
	
	for _, player in ipairs(Players:GetPlayers()) do
		if IsValidTarget(player, false) then
			local targetPart = GetTargetPart(player)
			if targetPart then
				local angularDist = GetAngularDistance(targetPart.Position)
				if angularDist < bestDistance then
					bestTarget = player
					bestDistance = angularDist
				end
			end
		end
	end
	
	return bestTarget
end

local function ShouldSwitchTarget()
	if not CONFIG.LockTarget then return true end
	if not LockedTarget then return true end
	
	if not IsValidTarget(LockedTarget, true) then
		return true
	end
	
	local targetPart = GetTargetPart(LockedTarget)
	if targetPart then
		local angularDist = GetAngularDistance(targetPart.Position)
		local fovAngle = GetFOVAngleFromPixels()
		
		if angularDist > fovAngle * 2 then
			return true
		end
	end
	
	return false
end

local function GetNextTarget()
	local validTargets = {}
	
	for _, player in ipairs(Players:GetPlayers()) do
		if IsValidTarget(player, false) then
			local targetPart = GetTargetPart(player)
			if targetPart then
				table.insert(validTargets, {
					player = player,
					distance = GetAngularDistance(targetPart.Position)
				})
			end
		end
	end
	
	table.sort(validTargets, function(a, b)
		return a.distance < b.distance
	end)
	
	local currentIndex = 0
	for i, data in ipairs(validTargets) do
		if data.player == LockedTarget then
			currentIndex = i
			break
		end
	end
	
	if currentIndex > 0 and currentIndex < #validTargets then
		return validTargets[currentIndex + 1].player
	elseif #validTargets > 0 then
		return validTargets[1].player
	end
	
	return nil
end

--=============================================================================
-- AIMING
--=============================================================================

local function AimAtPosition(targetPos)
	if not targetPos then return end
	
	local currentCF = Camera.CFrame
	local targetCF = CFrame.new(currentCF.Position, targetPos)
	
	Camera.CFrame = currentCF:Lerp(targetCF, CONFIG.Speed)
end

--=============================================================================
-- FOV CIRCLE
--=============================================================================

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.NumSides = 100
fovCircle.Radius = CONFIG.FOVSize
fovCircle.Filled = false
fovCircle.Visible = false
fovCircle.ZIndex = 999
fovCircle.Color = Color3.fromRGB(255, 255, 255)

--=============================================================================
-- EVENT HANDLERS
--=============================================================================

Players.PlayerRemoving:Connect(function(player)
	VelocityCache[player] = nil
	if LockedTarget == player then
		LockedTarget = nil
	end
end)

RunService.RenderStepped:Connect(function()
	if not CONFIG.Enabled then return end
	
	local now = tick()
	local target
	
	if CONFIG.LockTarget then
		if now - LastTargetCheck > TARGET_CHECK_INTERVAL then
			LastTargetCheck = now
			
			if ShouldSwitchTarget() then
				LockedTarget = GetClosestTarget()
			end
		end
		target = LockedTarget
	else
		target = GetClosestTarget()
	end
	
	if target then
		local targetPart = GetTargetPart(target)
		if targetPart then
			local predictedPos = PredictPosition(target, targetPart)
			predictedPos = predictedPos + Vector3.new(0, CONFIG.OffsetY, 0)
			AimAtPosition(predictedPos)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local center = GetScreenCenter()
	fovCircle.Position = center
	fovCircle.Visible = CONFIG.Enabled
	fovCircle.Radius = CONFIG.FOVSize
	fovCircle.Color = CONFIG.FOVColor
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == CONFIG.SwitchKey and CONFIG.Enabled and CONFIG.LockTarget then
		LockedTarget = GetNextTarget()
	end
end)

--=============================================================================
-- PUBLIC API
--=============================================================================

local AimbotAPI = {}

function AimbotAPI:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function AimbotAPI:GetConfig()
	return CONFIG
end

function AimbotAPI:Toggle(state)
	CONFIG.Enabled = state
	if not state then
		LockedTarget = nil
	end
end

function AimbotAPI:Destroy()
	fovCircle:Remove()
	VelocityCache = {}
	LockedTarget = nil
end

return AimbotAPI
