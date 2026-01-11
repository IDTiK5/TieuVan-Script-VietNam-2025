local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local CONFIG = {
	TracerColor = Color3.fromRGB(255, 255, 255),
	TracerThickness = 1,
	TracerTransparency = 1,
	Origin = "Top",
	Target = "Head",
	OffsetX = 0,
	OffsetY = 0,
	AliveOnly = true,
	DrawOffscreen = true,
	
	Enabled = false,
	ToggleKey = Enum.KeyCode.LeftAlt,
	
	EnableTeamCheck = false,
	ShowEnemyOnly = false,
	ShowAlliedOnly = false,
	
	UseTeamColors = false,
	UseActualTeamColors = true,
	EnemyTracerColor = Color3.fromRGB(255, 0, 0),
	AlliedTracerColor = Color3.fromRGB(0, 255, 0),
	NoTeamColor = Color3.fromRGB(255, 255, 255),
}

local tracers = {}
local drawingPool = {}
local poolSize = 0
local MAX_POOL_SIZE = 100
local isInitialized = false

--=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================

local function gameHasTeams()
	local success, teams = pcall(function()
		return game:GetService("Teams")
	end)
	if not success or not teams then return false end
	
	local teamList = teams:GetTeams()
	return teamList and #teamList > 0
end

local function getPlayerTeamColor(targetPlayer)
	if not targetPlayer then return nil end
	if not targetPlayer.Team then return nil end
	
	local success, color = pcall(function()
		return targetPlayer.Team.TeamColor.Color
	end)
	
	return success and color or nil
end

local function isEnemy(targetPlayer)
	if not targetPlayer then return true end
	if not targetPlayer.Character then return true end
	if not gameHasTeams() then return true end
	if not player.Team then
		if not targetPlayer.Team then return false end
		return true
	end
	if not targetPlayer.Team then return true end
	return player.Team ~= targetPlayer.Team
end

local function shouldShowPlayer(targetPlayer)
	if not CONFIG.EnableTeamCheck then return true end
	local isEnemyPlayer = isEnemy(targetPlayer)
	if CONFIG.ShowEnemyOnly and not isEnemyPlayer then return false end
	if CONFIG.ShowAlliedOnly and isEnemyPlayer then return false end
	return true
end

local function isAlive(character)
	if not character then return false end
	local humanoid = character:FindFirstChild("Humanoid")
	return humanoid and humanoid.Health > 0
end

local function getTracerColor(targetPlayer)
	if not CONFIG.UseTeamColors then
		return CONFIG.TracerColor
	end
	
	if CONFIG.UseActualTeamColors then
		local teamColor = getPlayerTeamColor(targetPlayer)
		return teamColor or CONFIG.NoTeamColor
	else
		return isEnemy(targetPlayer) and CONFIG.EnemyTracerColor or CONFIG.AlliedTracerColor
	end
end

local function getOriginPoint(screenSize, localRootPos)
	local success, point3D = pcall(function()
		return camera:WorldToViewportPoint(localRootPos)
	end)
	
	if not success or not point3D or point3D.Z < 0 then 
		return nil 
	end
	
	local origin = CONFIG.Origin
	
	if origin == "Top" then
		return Vector2.new(point3D.X, 0)
	elseif origin == "Center" then
		return Vector2.new(point3D.X, screenSize.Y / 2)
	elseif origin == "Mouse" then
		local success2, mousePos = pcall(function()
			return UserInputService:GetMouseLocation()
		end)
		return success2 and mousePos or Vector2.new(screenSize.X / 2, screenSize.Y)
	else
		return Vector2.new(point3D.X, screenSize.Y)
	end
end

local function getTargetScreenPos(character)
	if not character then return nil end
	
	local target = CONFIG.Target
	local targetPos = nil
	
	if target == "Head" then
		local head = character:FindFirstChild("Head")
		if head then targetPos = head.Position end
	elseif target == "Torso" then
		local torso = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
		if torso then targetPos = torso.Position end
	elseif target == "Feet" then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then targetPos = root.Position - Vector3.new(0, 3, 0) end
	else
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then targetPos = root.Position end
	end
	
	if not targetPos then return nil end
	
	local success, result = pcall(function()
		return camera:WorldToViewportPoint(targetPos)
	end)
	
	return success and result or nil
end

--=============================================================================
-- DRAWING POOL MANAGEMENT
--=============================================================================

local function getDrawing()
	if poolSize > 0 and drawingPool[poolSize] then
		local line = drawingPool[poolSize]
		drawingPool[poolSize] = nil
		poolSize = poolSize - 1
		return line
	end
	
	local success, line = pcall(function()
		return Drawing.new("Line")
	end)
	
	return success and line or nil
end

local function returnDrawing(line)
	if not line then return end
	
	if type(poolSize) ~= "number" then
		poolSize = 0
	end
	
	if type(MAX_POOL_SIZE) ~= "number" then
		MAX_POOL_SIZE = 100
	end
	
	pcall(function()
		line.Visible = false
	end)
	
	if poolSize < MAX_POOL_SIZE then
		poolSize = poolSize + 1
		drawingPool[poolSize] = line
	else
		pcall(function()
			line:Remove()
		end)
	end
end

--=============================================================================
-- TRACER MANAGEMENT
--=============================================================================

local function createTracer(targetPlayer)
	if tracers[targetPlayer] or targetPlayer == player then return end
	
	local drawing = getDrawing()
	if not drawing then return end
	
	pcall(function()
		drawing.Visible = false
		drawing.Color = CONFIG.TracerColor
		drawing.Thickness = CONFIG.TracerThickness
		drawing.Transparency = CONFIG.TracerTransparency
	end)
	
	tracers[targetPlayer] = {
		drawing = drawing
	}
end

local function removeTracer(targetPlayer)
	local tracerData = tracers[targetPlayer]
	if tracerData then
		if tracerData.drawing then
			returnDrawing(tracerData.drawing)
		end
		tracers[targetPlayer] = nil
	end
end

local function updateTracer(targetPlayer, tracerData)
	if not tracerData or not tracerData.drawing then return end
	
	local drawing = tracerData.drawing
	
	if not CONFIG.Enabled then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	local character = targetPlayer and targetPlayer.Character
	if not character then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	local targetRoot = character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	if CONFIG.AliveOnly and not isAlive(character) then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	if not shouldShowPlayer(targetPlayer) then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	local localChar = player.Character
	local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if not localRoot then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	local screenSize = camera.ViewportSize
	local originPoint = getOriginPoint(screenSize, localRoot.Position)
	
	if not originPoint then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	local targetPoint3D = getTargetScreenPos(character)
	
	if not targetPoint3D or typeof(targetPoint3D) ~= "Vector3" then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	if targetPoint3D.Z < 0 then
		pcall(function() drawing.Visible = false end)
		return
	end
	
	if not CONFIG.DrawOffscreen then
		if targetPoint3D.X < 0 or targetPoint3D.X > screenSize.X or 
		   targetPoint3D.Y < 0 or targetPoint3D.Y > screenSize.Y then
			pcall(function() drawing.Visible = false end)
			return
		end
	end
	
	local targetPoint = Vector2.new(
		targetPoint3D.X + CONFIG.OffsetX, 
		targetPoint3D.Y + CONFIG.OffsetY
	)
	
	pcall(function()
		drawing.From = originPoint
		drawing.To = targetPoint
		drawing.Color = getTracerColor(targetPlayer)
		drawing.Thickness = CONFIG.TracerThickness
		drawing.Transparency = CONFIG.TracerTransparency
		drawing.Visible = true
	end)
end

local function updateAllTracers()
	if not isInitialized then return end
	
	for targetPlayer, tracerData in pairs(tracers) do
		if targetPlayer and targetPlayer.Parent then
			updateTracer(targetPlayer, tracerData)
		else
			task.defer(function()
				removeTracer(targetPlayer)
			end)
		end
	end
end

local function cleanup()
	for targetPlayer, _ in pairs(tracers) do
		removeTracer(targetPlayer)
	end
	
	for i = 1, poolSize do
		if drawingPool[i] then
			pcall(function()
				drawingPool[i]:Remove()
			end)
			drawingPool[i] = nil
		end
	end
	poolSize = 0
end

--=============================================================================
-- EVENT HANDLERS
--=============================================================================

local function onPlayerAdded(newPlayer)
	if newPlayer ~= player then
		task.delay(0.5, function()
			if newPlayer and newPlayer.Parent then
				createTracer(newPlayer)
			end
		end)
	end
end

local function onPlayerRemoving(leavingPlayer)
	task.defer(function()
		removeTracer(leavingPlayer)
	end)
end

local function initialize()
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			createTracer(otherPlayer)
		end
	end
	
	isInitialized = true
end

--=============================================================================
-- INITIALIZATION
--=============================================================================

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

RunService.RenderStepped:Connect(function()
	if isInitialized then
		updateAllTracers()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == CONFIG.ToggleKey then
		CONFIG.Enabled = not CONFIG.Enabled
	end
end)

player.AncestryChanged:Connect(function(_, parent)
	if not parent then
		cleanup()
	end
end)

task.delay(0.1, initialize)

--=============================================================================
-- PUBLIC API
--=============================================================================

local TracerESPAPI = {}

function TracerESPAPI:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function TracerESPAPI:GetConfig()
	return CONFIG
end

function TracerESPAPI:Toggle(state)
	CONFIG.Enabled = state
end

function TracerESPAPI:Destroy()
	cleanup()
end

return TracerESPAPI
