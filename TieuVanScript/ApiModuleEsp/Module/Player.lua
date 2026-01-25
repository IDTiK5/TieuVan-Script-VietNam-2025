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

local FLY_ANIMATIONS = {
	Idle = "rbxassetid://83499817314808",
	Move = "rbxassetid://132105268936736",
	Backward = "rbxassetid://74891040412078",
	Left = "rbxassetid://105182810808552",
	Right = "rbxassetid://86441014589019"
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

local flyIdleAnim
local flyMoveAnim
local flyBackwardAnim
local flyLeftAnim
local flyRightAnim
local flyIdleTrack
local flyMoveTrack
local flyBackwardTrack
local flyLeftTrack
local flyRightTrack

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

local function StopFlyAnimations()
	if flyIdleTrack then
		flyIdleTrack:Stop()
		flyIdleTrack = nil
	end
	if flyMoveTrack then
		flyMoveTrack:Stop()
		flyMoveTrack = nil
	end
	if flyBackwardTrack then
		flyBackwardTrack:Stop()
		flyBackwardTrack = nil
	end
	if flyLeftTrack then
		flyLeftTrack:Stop()
		flyLeftTrack = nil
	end
	if flyRightTrack then
		flyRightTrack:Stop()
		flyRightTrack = nil
	end
	if flyIdleAnim then
		flyIdleAnim:Destroy()
		flyIdleAnim = nil
	end
	if flyMoveAnim then
		flyMoveAnim:Destroy()
		flyMoveAnim = nil
	end
	if flyBackwardAnim then
		flyBackwardAnim:Destroy()
		flyBackwardAnim = nil
	end
	if flyLeftAnim then
		flyLeftAnim:Destroy()
		flyLeftAnim = nil
	end
	if flyRightAnim then
		flyRightAnim:Destroy()
		flyRightAnim = nil
	end
end

local function SetupFlyAnimations()
	local character, _, humanoid = GetCharacterParts()
	if not character or not humanoid then return end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	flyIdleAnim = Instance.new("Animation")
	flyIdleAnim.AnimationId = FLY_ANIMATIONS.Idle
	
	flyMoveAnim = Instance.new("Animation")
	flyMoveAnim.AnimationId = FLY_ANIMATIONS.Move
	
	flyBackwardAnim = Instance.new("Animation")
	flyBackwardAnim.AnimationId = FLY_ANIMATIONS.Backward
	
	flyLeftAnim = Instance.new("Animation")
	flyLeftAnim.AnimationId = FLY_ANIMATIONS.Left
	
	flyRightAnim = Instance.new("Animation")
	flyRightAnim.AnimationId = FLY_ANIMATIONS.Right
	
	pcall(function()
		flyIdleTrack = animator:LoadAnimation(flyIdleAnim)
		flyIdleTrack.Priority = Enum.AnimationPriority.Action4
		flyIdleTrack.Looped = true
		
		flyMoveTrack = animator:LoadAnimation(flyMoveAnim)
		flyMoveTrack.Priority = Enum.AnimationPriority.Action4
		flyMoveTrack.Looped = true
		
		flyBackwardTrack = animator:LoadAnimation(flyBackwardAnim)
		flyBackwardTrack.Priority = Enum.AnimationPriority.Action4
		flyBackwardTrack.Looped = true
		
		flyLeftTrack = animator:LoadAnimation(flyLeftAnim)
		flyLeftTrack.Priority = Enum.AnimationPriority.Action4
		flyLeftTrack.Looped = true
		
		flyRightTrack = animator:LoadAnimation(flyRightAnim)
		flyRightTrack.Priority = Enum.AnimationPriority.Action4
		flyRightTrack.Looped = true
	end)
end

local function StopAllFlyAnimationsExcept(exceptTrack)
	if flyIdleTrack and flyIdleTrack ~= exceptTrack and flyIdleTrack.IsPlaying then
		flyIdleTrack:Stop(0.2)
	end
	if flyMoveTrack and flyMoveTrack ~= exceptTrack and flyMoveTrack.IsPlaying then
		flyMoveTrack:Stop(0.2)
	end
	if flyBackwardTrack and flyBackwardTrack ~= exceptTrack and flyBackwardTrack.IsPlaying then
		flyBackwardTrack:Stop(0.2)
	end
	if flyLeftTrack and flyLeftTrack ~= exceptTrack and flyLeftTrack.IsPlaying then
		flyLeftTrack:Stop(0.2)
	end
	if flyRightTrack and flyRightTrack ~= exceptTrack and flyRightTrack.IsPlaying then
		flyRightTrack:Stop(0.2)
	end
end

local function UpdateFlyAnimation(isMoving, isMovingBackward, isMovingLeft, isMovingRight)
	if not CONFIG.Fly then return end
	
	if isMoving then
		if isMovingRight then
			StopAllFlyAnimationsExcept(flyRightTrack)
			if flyRightTrack and not flyRightTrack.IsPlaying then
				flyRightTrack:Play(0.2)
			end
		elseif isMovingLeft then
			StopAllFlyAnimationsExcept(flyLeftTrack)
			if flyLeftTrack and not flyLeftTrack.IsPlaying then
				flyLeftTrack:Play(0.2)
			end
		elseif isMovingBackward then
			StopAllFlyAnimationsExcept(flyBackwardTrack)
			if flyBackwardTrack and not flyBackwardTrack.IsPlaying then
				flyBackwardTrack:Play(0.2)
			end
		else
			StopAllFlyAnimationsExcept(flyMoveTrack)
			if flyMoveTrack and not flyMoveTrack.IsPlaying then
				flyMoveTrack:Play(0.2)
			end
		end
	else
		StopAllFlyAnimationsExcept(flyIdleTrack)
		if flyIdleTrack and not flyIdleTrack.IsPlaying then
			flyIdleTrack:Play(0.2)
		end
	end
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
	StopFlyAnimations()
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
	
	SetupFlyAnimations()
	if flyIdleTrack then
		flyIdleTrack:Play(0.2)
	end
	
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
		local rightVector = cameraCF.RightVector
		
		local velocity = Vector3.new(0, 0, 0)
		local isMoving = moveVector.Magnitude > 0
		local isMovingBackward = false
		local isMovingLeft = false
		local isMovingRight = false
		
		if isMoving then
			local flatMoveVector = Vector3.new(moveVector.X, 0, moveVector.Z).Unit
			local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
			local flatRightVector = Vector3.new(rightVector.X, 0, rightVector.Z).Unit
			
			local forwardDot = flatMoveVector:Dot(flatLookVector)
			local rightDot = flatMoveVector:Dot(flatRightVector)
			
			isMovingRight = rightDot > 0.5
			isMovingLeft = rightDot < -0.5
			isMovingBackward = forwardDot < -0.5 and not isMovingLeft and not isMovingRight
			
			CONFIG.FlySpeed = math.min(CONFIG.FlySpeed + CONFIG.Acceleration, CONFIG.MaxFlySpeed)
			
			local verticalDot = moveVector:Dot(lookVector)
			local verticalComponent = lookVector.Y * CONFIG.FlySpeed * (verticalDot > 0 and 1 or -1)
			velocity = moveVector * CONFIG.FlySpeed
			velocity = velocity + Vector3.new(0, verticalComponent, 0)
		else
			CONFIG.FlySpeed = 5
		end
		
		UpdateFlyAnimation(isMoving, isMovingBackward, isMovingLeft, isMovingRight)
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

local Player2API = {}

function Player2API:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function Player2API:GetConfig()
	return CONFIG
end

function Player2API:EnableFly()
	StartFly()
end

function Player2API:DisableFly()
	StopFly()
end

function Player2API:SetFlySpeed(speed)
	CONFIG.FlySpeed = speed
end

function Player2API:SetMaxFlySpeed(speed)
	CONFIG.MaxFlySpeed = speed
end

function Player2API:SetAcceleration(accel)
	CONFIG.Acceleration = accel
end

function Player2API:SetFlyAnimation(animType, animId)
	if FLY_ANIMATIONS[animType] then
		FLY_ANIMATIONS[animType] = animId
	end
end

function Player2API:EnableSpeed()
	StartSpeed()
end

function Player2API:DisableSpeed()
	StopSpeed()
end

function Player2API:SetSpeedValue(value)
	CONFIG.SpeedValue = value
end

function Player2API:EnableJump()
	StartJump()
end

function Player2API:DisableJump()
	StopJump()
end

function Player2API:SetJumpPower(power)
	CONFIG.JumpPower = power
end

function Player2API:EnableInfiniteJump()
	StartInfiniteJump()
end

function Player2API:DisableInfiniteJump()
	StopInfiniteJump()
end

function Player2API:EnableAutoJump()
	StartAutoJump()
end

function Player2API:DisableAutoJump()
	StopAutoJump()
end

function Player2API:EnableNoclip()
	StartNoclip()
end

function Player2API:DisableNoclip()
	StopNoclip()
end

function Player2API:ResetCharacter()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end
end

function Player2API:DisableAll()
	StopFly()
	StopSpeed()
	StopJump()
	StopInfiniteJump()
	StopAutoJump()
	StopNoclip()
end

function Player2API:Install()
	InstallAntiSpeedCheck()
end

return Player2API
