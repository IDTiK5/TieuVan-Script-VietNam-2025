local LocalPlayer = game.Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

--=============================================================================
-- CONFIG
--=============================================================================

local CONFIG = {
	SpectateEnabled = false,
	SpectateSpeed = 50,
	UnlockCameraEnabled = false,
	MaxZoomDistance = 128,
	ShiftLockEnabled = false,
	FirstPersonMode = false,
	FieldOfView = 70,
	CameraType = "Custom",
	NoClipCamera = false,
	SmoothCamera = false,
	CameraSensitivity = 1,
	CameraOffsetX = 0,
	CameraOffsetY = 0,
	CameraOffsetZ = 0,
}

--=============================================================================
-- STATE
--=============================================================================

local DefaultMaxZoom = LocalPlayer.CameraMaxZoomDistance
local DefaultMinZoom = LocalPlayer.CameraMinZoomDistance
local DefaultCameraMode = LocalPlayer.CameraMode
local DefaultDevCameraMode = LocalPlayer.DevComputerCameraMode

local UnlockCameraEnabled = false
local UnlockCameraConnection = nil
local ShiftLockEnabled = false
local ShiftLockConnection = nil
local SmoothCameraEnabled = false
local CurrentMaxZoom = DefaultMaxZoom

local CameraOffsetX = 0
local CameraOffsetY = 0
local CameraOffsetZ = 0
local CameraSensitivity = 1

local SpectateEnabled = false
local SpectateConnection = nil
local SpectateCameraPosition = nil
local SpectateCameraRotation = nil
local SpectateSpeed = 50
local FrozenCharacterParts = {}
local OriginalAnchored = {}

local MobileJumpHeld = false
local MobileJumpTapTime = 0
local MobileJumpTapThreshold = 0.2
local MobileVerticalDirection = 0
local LastJumpInputTime = 0
local JumpTapCooldown = false

local SpectatePitch = 0
local SpectateYaw = 0

local TouchStartPos = nil
local TouchCameraYaw = 0
local TouchCameraPitch = 0
local TouchConnections = {}

local lastCFrame = Camera.CFrame
local smoothSpeed = 0.15

--=============================================================================
-- FREEZE CHARACTER
--=============================================================================

local function FreezeCharacter(freeze)
	local character = LocalPlayer.Character
	if not character then return end
	
	if freeze then
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				OriginalAnchored[part] = part.Anchored
				part.Anchored = true
			end
		end
		
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.PlatformStand = true
		end
	else
		for part, wasAnchored in pairs(OriginalAnchored) do
			if part and part.Parent then
				part.Anchored = wasAnchored
			end
		end
		OriginalAnchored = {}
		
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
end

--=============================================================================
-- GET SPECTATE INPUT
--=============================================================================

local function GetSpectateInput()
	local moveDirection = Vector3.new(0, 0, 0)
	
	-- Keyboard input (PC)
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDirection = moveDirection + Vector3.new(0, 0, -1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDirection = moveDirection + Vector3.new(0, 0, 1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDirection = moveDirection + Vector3.new(-1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDirection = moveDirection + Vector3.new(1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.E) then
		moveDirection = moveDirection + Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		moveDirection = moveDirection + Vector3.new(0, -1, 0)
	end
	
	-- Mobile thumbstick input
	local PlayerModule = LocalPlayer:FindFirstChild("PlayerScripts")
	if PlayerModule then
		local ControlModule = PlayerModule:FindFirstChild("PlayerModule")
		if ControlModule then
			local success, controls = pcall(function()
				return require(ControlModule):GetControls()
			end)
			if success and controls then
				local moveVector = controls:GetMoveVector()
				if moveVector and moveVector.Magnitude > 0 then
					moveDirection = moveDirection + Vector3.new(moveVector.X, 0, moveVector.Z)
				end
			end
		end
	end
	
	-- Mobile vertical movement
	if MobileJumpHeld then
		moveDirection = moveDirection + Vector3.new(0, 1, 0)
	elseif MobileVerticalDirection ~= 0 then
		moveDirection = moveDirection + Vector3.new(0, MobileVerticalDirection, 0)
	end
	
	-- Shift để tăng tốc (PC)
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		moveDirection = moveDirection * 2
	end
	
	return moveDirection
end

--=============================================================================
-- HANDLE JUMP ACTION
--=============================================================================

local function HandleJumpAction(actionName, inputState, inputObject)
	if not SpectateEnabled then return Enum.ContextActionResult.Pass end
	
	local currentTime = tick()
	
	if inputState == Enum.UserInputState.Begin then
		LastJumpInputTime = currentTime
		MobileJumpHeld = false
		JumpTapCooldown = false
		
		task.spawn(function()
			task.wait(MobileJumpTapThreshold)
			if SpectateEnabled and (tick() - LastJumpInputTime) >= MobileJumpTapThreshold then
				MobileJumpHeld = true
				MobileVerticalDirection = 0
			end
		end)
		
	elseif inputState == Enum.UserInputState.End then
		local holdDuration = currentTime - LastJumpInputTime
		
		if holdDuration < MobileJumpTapThreshold and not JumpTapCooldown then
			MobileJumpHeld = false
			MobileVerticalDirection = -1
			JumpTapCooldown = true
			
			task.spawn(function()
				task.wait(0.15)
				if SpectateEnabled then
					MobileVerticalDirection = 0
				end
				task.wait(0.1)
				JumpTapCooldown = false
			end)
		else
			MobileJumpHeld = false
			MobileVerticalDirection = 0
		end
	end
	
	return Enum.ContextActionResult.Sink
end

--=============================================================================
-- HANDLE TOUCH INPUT
--=============================================================================

local function HandleTouchInput()
	local touchConnection
	local touchEndConnection
	local touchBeginConnection
	
	touchConnection = UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
		if not SpectateEnabled then return end
		if gameProcessed then return end
		
		local screenSize = Camera.ViewportSize
		if touch.Position.X < screenSize.X * 0.4 then return end
		
		if TouchStartPos then
			local delta = touch.Position - TouchStartPos
			TouchStartPos = touch.Position
			
			local sensitivity = 0.005 * CameraSensitivity
			TouchCameraYaw = TouchCameraYaw - delta.X * sensitivity
			TouchCameraPitch = math.clamp(TouchCameraPitch - delta.Y * sensitivity, -math.rad(89), math.rad(89))
		end
	end)
	
	touchBeginConnection = UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
		if not SpectateEnabled then return end
		if gameProcessed then return end
		
		local screenSize = Camera.ViewportSize
		if touch.Position.X >= screenSize.X * 0.4 then
			TouchStartPos = touch.Position
		end
	end)
	
	touchEndConnection = UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
		if not SpectateEnabled then return end
		TouchStartPos = nil
	end)
	
	return {touchConnection, touchEndConnection, touchBeginConnection}
end

--=============================================================================
-- SPECTATE MODE
--=============================================================================

local function StartSpectate()
	SpectateEnabled = true
	SpectateCameraPosition = Camera.CFrame.Position
	SpectateCameraRotation = Camera.CFrame - Camera.CFrame.Position
	
	FreezeCharacter(true)
	Camera.CameraType = Enum.CameraType.Scriptable
	
	if not UserInputService.TouchEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	
	ContextActionService:BindAction("SpectateJump", HandleJumpAction, false, 
		Enum.KeyCode.Space, 
		Enum.KeyCode.ButtonA,
		Enum.PlayerActions.CharacterJump
	)
	
	if UserInputService.TouchEnabled then
		TouchConnections = HandleTouchInput()
	end
	
	if SpectateConnection then
		SpectateConnection:Disconnect()
	end
	
	-- Khởi tạo rotation từ camera hiện tại
	local lookVector = Camera.CFrame.LookVector
	SpectateYaw = math.atan2(-lookVector.X, -lookVector.Z)
	SpectatePitch = math.asin(lookVector.Y)
	
	TouchCameraYaw = SpectateYaw
	TouchCameraPitch = SpectatePitch
	
	SpectateConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not SpectateEnabled then return end
		
		-- Xử lý xoay camera
		if UserInputService.TouchEnabled then
			-- Mobile: sử dụng touch input
			SpectatePitch = TouchCameraPitch
			SpectateYaw = TouchCameraYaw
		else
			-- PC: sử dụng mouse delta
			local mouseDelta = UserInputService:GetMouseDelta()
			local sensitivity = 0.003 * CameraSensitivity
			
			SpectateYaw = SpectateYaw - mouseDelta.X * sensitivity
			SpectatePitch = math.clamp(SpectatePitch - mouseDelta.Y * sensitivity, -math.rad(89), math.rad(89))
		end
		
		-- Tạo rotation từ pitch và yaw
		local rotation = CFrame.Angles(0, SpectateYaw, 0) * CFrame.Angles(SpectatePitch, 0, 0)
		
		-- Xử lý di chuyển camera
		local moveInput = GetSpectateInput()
		if moveInput.Magnitude > 0 then
			local moveVector = rotation:VectorToWorldSpace(moveInput.Unit)
			SpectateCameraPosition = SpectateCameraPosition + moveVector * SpectateSpeed * deltaTime
		end
		
		-- Cập nhật camera
		Camera.CFrame = CFrame.new(SpectateCameraPosition) * rotation
		
		-- Đảm bảo camera vẫn ở chế độ Scriptable
		if Camera.CameraType ~= Enum.CameraType.Scriptable then
			Camera.CameraType = Enum.CameraType.Scriptable
		end
		
		-- Đảm bảo nhân vật vẫn freeze
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid and not humanoid.PlatformStand then
				humanoid.PlatformStand = true
			end
		end
	end)
end

local function StopSpectate()
	SpectateEnabled = false
	
	if SpectateConnection then
		SpectateConnection:Disconnect()
		SpectateConnection = nil
	end
	
	ContextActionService:UnbindAction("SpectateJump")
	
	for _, conn in pairs(TouchConnections) do
		if conn then conn:Disconnect() end
	end
	TouchConnections = {}
	
	MobileJumpHeld = false
	MobileVerticalDirection = 0
	TouchStartPos = nil
	
	FreezeCharacter(false)
	
	Camera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	
	local character = LocalPlayer.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			Camera.CameraSubject = character:FindFirstChild("Humanoid")
		end
	end
end

--=============================================================================
-- UNLOCK CAMERA
--=============================================================================

local function StartUnlockCamera()
	UnlockCameraEnabled = true
	
	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	LocalPlayer.DevComputerCameraMode = Enum.DevComputerCameraMovementMode.Classic
	LocalPlayer.DevTouchCameraMode = Enum.DevTouchCameraMovementMode.Classic
	LocalPlayer.CameraMinZoomDistance = 0.5
	LocalPlayer.CameraMaxZoomDistance = CurrentMaxZoom
	Camera.CameraType = Enum.CameraType.Custom
	
	if UnlockCameraConnection then
		UnlockCameraConnection:Disconnect()
	end
	
	UnlockCameraConnection = RunService.RenderStepped:Connect(function()
		if SpectateEnabled then return end
		
		if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
			LocalPlayer.CameraMode = Enum.CameraMode.Classic
		end
		if LocalPlayer.CameraMinZoomDistance > 0.5 then
			LocalPlayer.CameraMinZoomDistance = 0.5
		end
		if LocalPlayer.CameraMaxZoomDistance ~= CurrentMaxZoom then
			LocalPlayer.CameraMaxZoomDistance = CurrentMaxZoom
		end
		if Camera.CameraType == Enum.CameraType.Scriptable or Camera.CameraType == Enum.CameraType.Fixed then
			Camera.CameraType = Enum.CameraType.Custom
		end
	end)
end

local function StopUnlockCamera()
	UnlockCameraEnabled = false
	
	if UnlockCameraConnection then
		UnlockCameraConnection:Disconnect()
		UnlockCameraConnection = nil
	end
	
	LocalPlayer.CameraMode = DefaultCameraMode
	LocalPlayer.DevComputerCameraMode = DefaultDevCameraMode
	LocalPlayer.CameraMaxZoomDistance = DefaultMaxZoom
	LocalPlayer.CameraMinZoomDistance = DefaultMinZoom
end

--=============================================================================
-- SHIFT LOCK
--=============================================================================

local function StartShiftLock()
	ShiftLockEnabled = true
	
	LocalPlayer.DevEnableMouseLock = true
	
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	
	if humanoid then
		humanoid.AutoRotate = false
	end
	
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	
	if ShiftLockConnection then
		ShiftLockConnection:Disconnect()
	end
	
	ShiftLockConnection = RunService.RenderStepped:Connect(function()
		if SpectateEnabled then return end
		
		local char = LocalPlayer.Character
		if not char then return end
		
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChild("Humanoid")
		
		if hrp and hum then
			local camLookVector = Camera.CFrame.LookVector
			local flatLookVector = Vector3.new(camLookVector.X, 0, camLookVector.Z).Unit
			
			if flatLookVector.Magnitude > 0 then
				local targetCFrame = CFrame.new(hrp.Position, hrp.Position + flatLookVector)
				hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, 0.3)
			end
			
			hum.CameraOffset = Vector3.new(1.75, 0, 0)
		end
		
		if ShiftLockEnabled and not SpectateEnabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end)
end

local function StopShiftLock()
	ShiftLockEnabled = false
	
	if ShiftLockConnection then
		ShiftLockConnection:Disconnect()
		ShiftLockConnection = nil
	end
	
	if not SpectateEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.new(0, 0, 0)
	end
end

--=============================================================================
-- CHARACTER RESPAWN HANDLER
--=============================================================================

LocalPlayer.CharacterAdded:Connect(function(character)
	if SpectateEnabled then
		SpectateEnabled = false
		if SpectateConnection then
			SpectateConnection:Disconnect()
			SpectateConnection = nil
		end
		OriginalAnchored = {}
		Camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		if ShiftLockEnabled then
			humanoid.AutoRotate = false
			humanoid.CameraOffset = Vector3.new(1.75, 0, 0)
		else
			humanoid.CameraOffset = Vector3.new(CameraOffsetX, CameraOffsetY, CameraOffsetZ)
		end
	end
end)

--=============================================================================
-- SMOOTH CAMERA LOGIC
--=============================================================================

RunService.RenderStepped:Connect(function()
	if SpectateEnabled then return end
	
	if not SmoothCameraEnabled then 
		lastCFrame = Camera.CFrame
		return 
	end
	
	local targetCFrame = Camera.CFrame
	Camera.CFrame = lastCFrame:Lerp(targetCFrame, smoothSpeed * CameraSensitivity)
	lastCFrame = Camera.CFrame
end)

--=============================================================================
-- PUBLIC API
--=============================================================================

local CameraAPI = {}

function CameraAPI:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function CameraAPI:GetConfig()
	return CONFIG
end

function CameraAPI:EnableSpectate()
	CONFIG.SpectateEnabled = true
	StartSpectate()
end

function CameraAPI:DisableSpectate()
	CONFIG.SpectateEnabled = false
	StopSpectate()
end

function CameraAPI:SetSpectateSpeed(speed)
	CONFIG.SpectateSpeed = speed
	SpectateSpeed = speed
end

function CameraAPI:EnableUnlockCamera()
	CONFIG.UnlockCameraEnabled = true
	StartUnlockCamera()
end

function CameraAPI:DisableUnlockCamera()
	CONFIG.UnlockCameraEnabled = false
	StopUnlockCamera()
end

function CameraAPI:SetMaxZoomDistance(distance)
	CONFIG.MaxZoomDistance = distance
	CurrentMaxZoom = distance
	if UnlockCameraEnabled then
		LocalPlayer.CameraMaxZoomDistance = distance
	end
end

function CameraAPI:EnableShiftLock()
	CONFIG.ShiftLockEnabled = true
	StartShiftLock()
end

function CameraAPI:DisableShiftLock()
	CONFIG.ShiftLockEnabled = false
	StopShiftLock()
end

function CameraAPI:EnableFirstPerson()
	CONFIG.FirstPersonMode = true
	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end

function CameraAPI:DisableFirstPerson()
	CONFIG.FirstPersonMode = false
	LocalPlayer.CameraMode = Enum.CameraMode.Classic
end

function CameraAPI:SetFieldOfView(fov)
	CONFIG.FieldOfView = fov
	Camera.FieldOfView = fov
end

function CameraAPI:SetCameraType(cameraType)
	CONFIG.CameraType = cameraType
	
	if SpectateEnabled then return end
	
	local cameraTypeMap = {
		["Custom"] = Enum.CameraType.Custom,
		["Follow"] = Enum.CameraType.Follow,
		["Orbital"] = Enum.CameraType.Orbital,
		["Track"] = Enum.CameraType.Track
	}
	
	if cameraTypeMap[cameraType] then
		Camera.CameraType = cameraTypeMap[cameraType]
	end
end

function CameraAPI:EnableNoClipCamera()
	CONFIG.NoClipCamera = true
	LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
end

function CameraAPI:DisableNoClipCamera()
	CONFIG.NoClipCamera = false
	LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
end

function CameraAPI:EnableSmoothCamera()
	CONFIG.SmoothCamera = true
	SmoothCameraEnabled = true
end

function CameraAPI:DisableSmoothCamera()
	CONFIG.SmoothCamera = false
	SmoothCameraEnabled = false
end

function CameraAPI:SetCameraSensitivity(sensitivity)
	CONFIG.CameraSensitivity = sensitivity
	CameraSensitivity = sensitivity
	UserInputService.MouseDeltaSensitivity = sensitivity
end

function CameraAPI:SetCameraOffsetX(offset)
	CONFIG.CameraOffsetX = offset
	CameraOffsetX = offset
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if humanoid and not ShiftLockEnabled then
		humanoid.CameraOffset = Vector3.new(offset, CameraOffsetY, CameraOffsetZ)
	end
end

function CameraAPI:SetCameraOffsetY(offset)
	CONFIG.CameraOffsetY = offset
	CameraOffsetY = offset
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if humanoid and not ShiftLockEnabled then
		humanoid.CameraOffset = Vector3.new(CameraOffsetX, offset, CameraOffsetZ)
	end
end

function CameraAPI:SetCameraOffsetZ(offset)
	CONFIG.CameraOffsetZ = offset
	CameraOffsetZ = offset
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if humanoid and not ShiftLockEnabled then
		humanoid.CameraOffset = Vector3.new(CameraOffsetX, CameraOffsetY, offset)
	end
end

function CameraAPI:SetCameraOffset(x, y, z)
	CONFIG.CameraOffsetX = x
	CONFIG.CameraOffsetY = y
	CONFIG.CameraOffsetZ = z
	
	CameraOffsetX = x
	CameraOffsetY = y
	CameraOffsetZ = z
	
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if humanoid and not ShiftLockEnabled then
		humanoid.CameraOffset = Vector3.new(x, y, z)
	end
end

return CameraAPI
