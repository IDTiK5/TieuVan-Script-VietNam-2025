local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	Enabled = false,
	
	ShowDistance = true,
	DistanceColor = Color3.fromRGB(255, 255, 255),
	DistanceTextSize = 8,
	DistanceUnit = "St",
	
	ShowStatus = true,
	StatusColor = Color3.fromRGB(255, 255, 255),
	StatusTextSize = 8,
	MovingText = "Moving",
	StandingText = "Standing",
	MovementThreshold = 0.5,
	
	EnableTeamCheck = false,
	ShowEnemyOnly = false,
	ShowAlliedOnly = false,
	
	UseTeamColors = false,
	UseActualTeamColors = true,
	EnemyInfoColor = Color3.fromRGB(255, 0, 0),
	AlliedInfoColor = Color3.fromRGB(0, 255, 0),
	NoTeamColor = Color3.fromRGB(255, 255, 255),
}

local playerGui = player:WaitForChild("PlayerGui")
local infoScreenGui = Instance.new("ScreenGui")
infoScreenGui.Name = "InfoESP"
infoScreenGui.ResetOnSpawn = false
infoScreenGui.Parent = playerGui

local espData = {}
local lastPositions = {}

--=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================

local function gameHasTeams()
	local teams = game:GetService("Teams")
	if not teams then return false end
	return #teams:GetTeams() > 0
end

local function getPlayerTeamColor(targetPlayer)
	if not targetPlayer then return nil end
	if not targetPlayer.Team then return nil end
	return targetPlayer.Team.TeamColor.Color
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

local function getInfoColor(targetPlayer)
	if not CONFIG.UseTeamColors then
		return CONFIG.DistanceColor, CONFIG.StatusColor
	end
	
	if CONFIG.UseActualTeamColors then
		local teamColor = getPlayerTeamColor(targetPlayer)
		if teamColor then
			return teamColor, teamColor
		else
			return CONFIG.NoTeamColor, CONFIG.NoTeamColor
		end
	else
		local isEnemyPlayer = isEnemy(targetPlayer)
		if isEnemyPlayer then
			return CONFIG.EnemyInfoColor, CONFIG.EnemyInfoColor
		else
			return CONFIG.AlliedInfoColor, CONFIG.AlliedInfoColor
		end
	end
end

local function getDistance(targetPlayer)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return 0 end
	if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return 0 end
	return (player.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
end

local function getMovementStatus(targetPlayer)
	if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return CONFIG.StandingText end
	
	local currentPos = targetPlayer.Character.HumanoidRootPart.Position
	local lastPos = lastPositions[targetPlayer]
	lastPositions[targetPlayer] = currentPos
	
	if not lastPos then return CONFIG.StandingText end
	
	local deltaX = currentPos.X - lastPos.X
	local deltaZ = currentPos.Z - lastPos.Z
	local horizontalSpeed = math.sqrt(deltaX^2 + deltaZ^2) * 60
	
	return horizontalSpeed > CONFIG.MovementThreshold and CONFIG.MovingText or CONFIG.StandingText
end

--=============================================================================
-- STATUS ESP CREATION & MANAGEMENT
--=============================================================================

local function createEsp(targetPlayer)
	if espData[targetPlayer] then return end
	
	local InfoContainer = Instance.new("Frame", infoScreenGui)
	InfoContainer.Name = "Info_" .. targetPlayer.Name
	InfoContainer.BackgroundTransparency = 1
	InfoContainer.Size = UDim2.new(0, 100, 0, CONFIG.DistanceTextSize + CONFIG.StatusTextSize + 6)
	InfoContainer.AnchorPoint = Vector2.new(0, 0)
	
	local DistanceText = Instance.new("TextLabel", InfoContainer)
	DistanceText.BackgroundTransparency = 1
	DistanceText.Size = UDim2.new(1, 0, 0, CONFIG.DistanceTextSize + 2)
	DistanceText.Font = Enum.Font.Code
	DistanceText.TextColor3 = CONFIG.DistanceColor
	DistanceText.TextSize = CONFIG.DistanceTextSize
	DistanceText.TextStrokeTransparency = 0
	DistanceText.TextXAlignment = Enum.TextXAlignment.Left
	DistanceText.TextYAlignment = Enum.TextYAlignment.Top
	DistanceText.Text = "0 " .. CONFIG.DistanceUnit
	
	local StatusText = Instance.new("TextLabel", InfoContainer)
	StatusText.BackgroundTransparency = 1
	StatusText.Position = UDim2.new(0, 0, 0, CONFIG.DistanceTextSize + 2)
	StatusText.Size = UDim2.new(1, 0, 0, CONFIG.StatusTextSize + 2)
	StatusText.Font = Enum.Font.Code
	StatusText.TextColor3 = CONFIG.StatusColor
	StatusText.TextSize = CONFIG.StatusTextSize
	StatusText.TextStrokeTransparency = 0
	StatusText.TextXAlignment = Enum.TextXAlignment.Left
	StatusText.TextYAlignment = Enum.TextYAlignment.Top
	StatusText.Text = CONFIG.StandingText
	
	espData[targetPlayer] = {
		Container = InfoContainer,
		Dist = DistanceText,
		Stat = StatusText
	}
end

local function updateEsp(targetPlayer, data)
	if not data or not data.Container then return end
	
	if not CONFIG.Enabled then
		data.Container.Visible = false
		return
	end
	
	if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
		data.Container.Visible = false
		return
	end
	
	local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		data.Container.Visible = false
		return
	end
	
	if not shouldShowPlayer(targetPlayer) then
		data.Container.Visible = false
		return
	end
	
	local hrp = targetPlayer.Character.HumanoidRootPart
	local charSize = targetPlayer.Character:GetExtentsSize()
	
	local boxHeight = charSize.Y * 0.8
	local boxWidth = charSize.X * 0.8
	
	local headTop = hrp.Position + Vector3.new(0, charSize.Y / 2, 0)
	local feetBottom = hrp.Position - Vector3.new(0, charSize.Y / 1.4, 0)
	
	local headScreenPos, onScreen = camera:WorldToScreenPoint(headTop)
	local feetScreenPos = camera:WorldToScreenPoint(feetBottom)
	
	if onScreen then
		local displayHeight = math.abs(feetScreenPos.Y - headScreenPos.Y)
		local displayWidth = displayHeight * (boxWidth / boxHeight)
		local screenX = (headScreenPos.X + feetScreenPos.X) / 2
		local screenYTop = headScreenPos.Y
		
		local boxRightX = screenX + displayWidth / 2 + 3
		
		data.Container.Size = UDim2.new(0, 100, 0, CONFIG.DistanceTextSize + CONFIG.StatusTextSize + 6)
		data.Container.Position = UDim2.new(0, boxRightX, 0, screenYTop)
		data.Container.Visible = true
		
		data.Dist.TextSize = CONFIG.DistanceTextSize
		data.Dist.Size = UDim2.new(1, 0, 0, CONFIG.DistanceTextSize + 2)
		
		data.Stat.TextSize = CONFIG.StatusTextSize
		data.Stat.Position = UDim2.new(0, 0, 0, CONFIG.DistanceTextSize + 2)
		data.Stat.Size = UDim2.new(1, 0, 0, CONFIG.StatusTextSize + 2)
		
		local distColor, statColor = getInfoColor(targetPlayer)
		data.Dist.TextColor3 = distColor
		data.Stat.TextColor3 = statColor
		
		if CONFIG.ShowDistance then
			data.Dist.Visible = true
			data.Dist.Text = math.floor(getDistance(targetPlayer)) .. " " .. CONFIG.DistanceUnit
		else
			data.Dist.Visible = false
		end
		
		if CONFIG.ShowStatus then
			data.Stat.Visible = true
			data.Stat.Text = getMovementStatus(targetPlayer)
		else
			data.Stat.Visible = false
		end
	else
		data.Container.Visible = false
	end
end

local function removeEsp(targetPlayer)
	if espData[targetPlayer] then
		espData[targetPlayer].Container:Destroy()
		espData[targetPlayer] = nil
	end
	lastPositions[targetPlayer] = nil
end

--=============================================================================
-- EVENT HANDLERS
--=============================================================================

RunService.RenderStepped:Connect(function()
	for targetPlayer, data in pairs(espData) do
		if targetPlayer.Parent then
			updateEsp(targetPlayer, data)
		else
			removeEsp(targetPlayer)
		end
	end
end)

Players.PlayerAdded:Connect(function(v)
	if v ~= player then
		v.CharacterAdded:Connect(function(character)
			wait(0.5)
			createEsp(v)
		end)
		if v.Character then 
			createEsp(v) 
		end
	end
end)

Players.PlayerRemoving:Connect(removeEsp)

for _, v in pairs(Players:GetPlayers()) do
	if v ~= player then
		if v.Character then 
			createEsp(v) 
		end
		v.CharacterAdded:Connect(function() 
			wait(0.5) 
			createEsp(v) 
		end)
	end
end

--=============================================================================
-- PUBLIC API
--=============================================================================

local StatusESPAPI = {}

function StatusESPAPI:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function StatusESPAPI:GetConfig()
	return CONFIG
end

function StatusESPAPI:Toggle(state)
	CONFIG.Enabled = state
end

function StatusESPAPI:Destroy()
	for targetPlayer in pairs(espData) do
		removeEsp(targetPlayer)
	end
	infoScreenGui:Destroy()
end

return StatusESPAPI
