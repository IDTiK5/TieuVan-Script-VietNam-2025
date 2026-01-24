local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

--=============================================================================
-- CONFIG
--=============================================================================

local CONFIG = {
	InfiniteJump = false,
	Fly = false,
	FlySpeed = 5,
	MaxFlySpeed = 500,
	Acceleration = 10,
	Speed = false,
	SpeedValue = 50,
	Jump = false,
	JumpPower = 50,
	AutoJump = false,
	Noclip = false,
}

--=============================================================================
-- STATE
--=============================================================================

local bodyVelocity
local bodyGyro
local flyConnection
local speedConnection
local jumpConnection
local autoJumpConnection
local noclipConnection

--=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================

local function GetCharacterParts()
	local character = player.Character
	if not character then return nil, nil, nil end
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character, humanoidRootPart, humanoid
end

local function CleanupFlyInstances()
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end
	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
end

--=============================================================================
-- FLY SYSTEM
--=============================================================================

local function StopFly()
	CONFIG.Fly = false
	CleanupFlyInstances()
	local _, _, humanoid = GetCharacterParts()
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function StartFly()
	CleanupFlyInstances()
	CONFIG.Fly = true
	
	local character, humanoidRootPart, humanoid = GetCharacterParts()
	if not character or not humanoidRootPart or not humanoid then
		return
	end
	
	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyVelocity.Parent = humanoidRootPart
	
	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bodyGyro.Parent = humanoidRootPart
	
	humanoid.PlatformStand = true
	
	flyConnection = RunService.RenderStepped:Connect(function()
		local char, hrp, hum = GetCharacterParts()
		
		if not CONFIG.Fly or not char or not hrp or not bodyVelocity or not bodyGyro then
			CleanupFlyInstances()
			return
		end
		
		if not bodyVelocity.Parent or not bodyGyro.Parent then
			CleanupFlyInstances()
			if CONFIG.Fly then
				task.defer(StartFly)
			end
			return
		end
		
		bodyGyro.CFrame = workspace.CurrentCamera.CFrame
		
		local cameraCF = workspace.CurrentCamera.CFrame
		local moveVector = hum.MoveDirection
		local lookVector = cameraCF.LookVector
		
		local velocity = Vector3.new(0, 0, 0)
		
		if moveVector.Magnitude > 0 then
			CONFIG.FlySpeed = math.min(CONFIG.FlySpeed + CONFIG.Acceleration, CONFIG.MaxFlySpeed)
			
			local dotProduct = moveVector:Dot(lookVector)
			local verticalComponent = lookVector.Y * CONFIG.FlySpeed * (dotProduct > 0 and 1 or -1)
			velocity = moveVector * CONFIG.FlySpeed
			velocity = velocity + Vector3.new(0, verticalComponent, 0)
		else
			CONFIG.FlySpeed = 5
		end
		
		bodyVelocity.Velocity = velocity
	end)
end

--=============================================================================
-- SPEED SYSTEM
--=============================================================================

local function StopSpeed()
	CONFIG.Speed = false
	if speedConnection then
		speedConnection:Disconnect()
		speedConnection = nil
	end
end

local function StartSpeed()
	if CONFIG.Speed then return end
	CONFIG.Speed = true
	
	speedConnection = RunService.RenderStepped:Connect(function()
		if not CONFIG.Speed then
			StopSpeed()
			return
		end
		
		local _, hrp, humanoid = GetCharacterParts()
		if not hrp or not humanoid then return end
		
		if humanoid.Health > 0 then
			local moveDirection = humanoid.MoveDirection
			if moveDirection.Magnitude > 0 then
				hrp.CFrame = hrp.CFrame + moveDirection * (CONFIG.SpeedValue / 1000)
			end
		end
	end)
end

--=============================================================================
-- JUMP SYSTEM
--=============================================================================

local function StopJump()
	CONFIG.Jump = false
	if jumpConnection then
		jumpConnection:Disconnect()
		jumpConnection = nil
	end
end

local function StartJump()
	if CONFIG.Jump then return end
	CONFIG.Jump = true
	
	jumpConnection = RunService.RenderStepped:Connect(function()
		if not CONFIG.Jump then
			StopJump()
			return
		end
		
		local _, _, humanoid = GetCharacterParts()
		if not humanoid then return end
		
		if humanoid.Health > 0 then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = CONFIG.JumpPower
		end
	end)
end

--=============================================================================
-- INFINITE JUMP SYSTEM
--=============================================================================

local function StartInfiniteJump()
	if CONFIG.InfiniteJump then return end
	CONFIG.InfiniteJump = true
	getgenv().InfiniteJump = true
end

local function StopInfiniteJump()
	CONFIG.InfiniteJump = false
	getgenv().InfiniteJump = false
end

UserInputService.JumpRequest:Connect(function()
	if CONFIG.InfiniteJump == true then
		pcall(function()
			if Players.LocalPlayer.Character then
				local humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end)
	end
end)

--=============================================================================
-- AUTO JUMP SYSTEM
--=============================================================================

local function StopAutoJump()
	CONFIG.AutoJump = false
	if autoJumpConnection then
		autoJumpConnection:Disconnect()
		autoJumpConnection = nil
	end
end

local function StartAutoJump()
	if CONFIG.AutoJump then return end
	CONFIG.AutoJump = true
	
	autoJumpConnection = RunService.Heartbeat:Connect(function()
		if not CONFIG.AutoJump then
			StopAutoJump()
			return
		end
		
		if not player.Character or not player.Character:FindFirstChild("Humanoid") then
			return
		end
		
		local humanoid = player.Character:FindFirstChild("Humanoid")
		
		if humanoid and humanoid.Health > 0 then
			local state = humanoid:GetState()
			if state == Enum.HumanoidStateType.Running or 
			   state == Enum.HumanoidStateType.RunningNoPhysics or
			   state == Enum.HumanoidStateType.Landed then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)
end

--=============================================================================
-- NOCLIP SYSTEM
--=============================================================================

local function StopNoclip()
	CONFIG.Noclip = false
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	
	if player.Character then
		for _, part in pairs(player.Character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end
end

local function StartNoclip()
	if CONFIG.Noclip then return end
	CONFIG.Noclip = true
	
	noclipConnection = RunService.RenderStepped:Connect(function()
		if not CONFIG.Noclip then
			StopNoclip()
			return
		end
		
		if player.Character then
			for _, part in pairs(player.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end)
end

--=============================================================================
-- CHARACTER RESPAWN HANDLER
--=============================================================================

player.CharacterAdded:Connect(function(newCharacter)
	newCharacter:WaitForChild("HumanoidRootPart")
	newCharacter:WaitForChild("Humanoid")
	task.wait(0.1)
	
	if CONFIG.Fly then
		StartFly()
	end
	
	if CONFIG.Speed then
		CONFIG.Speed = false
		StartSpeed()
	end
	
	if CONFIG.Jump then
		CONFIG.Jump = false
		StartJump()
	end
	
	if CONFIG.Noclip then
		CONFIG.Noclip = false
		StartNoclip()
	end
	
	if CONFIG.AutoJump then
		CONFIG.AutoJump = false
		StartAutoJump()
	end
end)

--=============================================================================
-- ANTI-SPEED CHECK HOOK
--=============================================================================

local function InstallAntiSpeedCheck()
	local mt = getrawmetatable(game)
	setreadonly(mt, false)
	local old = mt.__namecall
	mt.__namecall = newcclosure(function(...)
		local args = {...}
		local method = getnamecallmethod()
		
		if method == "FireServer" or method == "InvokeServer" then
			if args[1] == "WalkSpeed" or args[1] == "Speed" or args[1] == "CheckSpeed" then
				return
			end
		end
		return old(...)
	end)
	setreadonly(mt, true)
end

--=============================================================================
-- PUBLIC API
--=============================================================================

local PlayerAPI = {}

function PlayerAPI:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function PlayerAPI:GetConfig()
	return CONFIG
end

function PlayerAPI:EnableFly()
	StartFly()
end

function PlayerAPI:DisableFly()
	StopFly()
end

function PlayerAPI:SetFlySpeed(speed)
	CONFIG.FlySpeed = speed
end

function PlayerAPI:SetMaxFlySpeed(speed)
	CONFIG.MaxFlySpeed = speed
end

function PlayerAPI:SetAcceleration(accel)
	CONFIG.Acceleration = accel
end

function PlayerAPI:EnableSpeed()
	StartSpeed()
end

function PlayerAPI:DisableSpeed()
	StopSpeed()
end

function PlayerAPI:SetSpeedValue(value)
	CONFIG.SpeedValue = value
end

function PlayerAPI:EnableJump()
	StartJump()
end

function PlayerAPI:DisableJump()
	StopJump()
end

function PlayerAPI:SetJumpPower(power)
	CONFIG.JumpPower = power
end

function PlayerAPI:EnableInfiniteJump()
	StartInfiniteJump()
end

function PlayerAPI:DisableInfiniteJump()
	StopInfiniteJump()
end

function PlayerAPI:EnableAutoJump()
	StartAutoJump()
end

function PlayerAPI:DisableAutoJump()
	StopAutoJump()
end

function PlayerAPI:EnableNoclip()
	StartNoclip()
end

function PlayerAPI:DisableNoclip()
	StopNoclip()
end

function PlayerAPI:ResetCharacter()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end
end

function PlayerAPI:DisableAll()
	StopFly()
	StopSpeed()
	StopJump()
	StopInfiniteJump()
	StopAutoJump()
	StopNoclip()
end

function PlayerAPI:Install()
	InstallAntiSpeedCheck()
end

return PlayerAPI
