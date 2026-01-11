local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	Enabled = false,
	NameColor = Color3.fromRGB(255, 255, 255),
	NameTextSize = 8,
	
	HidePlayerNames = false,
	HideToggleKey = Enum.KeyCode.H,
	
	EnableTeamCheck = false,
	ShowEnemyOnly = false,
	ShowAlliedOnly = false,
	
	UseTeamColors = false,
	UseActualTeamColors = true,
	EnemyNameColor = Color3.fromRGB(255, 0, 0),
	AlliedNameColor = Color3.fromRGB(0, 255, 0),
	NoTeamColor = Color3.fromRGB(255, 255, 255),
}

local playerGui = player:WaitForChild("PlayerGui")
local nameScreenGui = Instance.new("ScreenGui")
nameScreenGui.Name = "NameESP"
nameScreenGui.ResetOnSpawn = false
nameScreenGui.Parent = playerGui

local espData = {}

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

local function getNameColor(targetPlayer)
	if not CONFIG.UseTeamColors then
		return CONFIG.NameColor
	end
	
	if CONFIG.UseActualTeamColors then
		local teamColor = getPlayerTeamColor(targetPlayer)
		if teamColor then
			return teamColor
		else
			return CONFIG.NoTeamColor
		end
	else
		local isEnemyPlayer = isEnemy(targetPlayer)
		if isEnemyPlayer then
			return CONFIG.EnemyNameColor
		else
			return CONFIG.AlliedNameColor
		end
	end
end

--=============================================================================
-- NAME ESP CREATION & MANAGEMENT
--=============================================================================

local function createEsp(targetPlayer)
	if espData[targetPlayer] then return end
	
	local NameContainer = Instance.new("Frame", nameScreenGui)
	NameContainer.Name = "Name_" .. targetPlayer.Name
	NameContainer.BackgroundTransparency = 1
	NameContainer.Size = UDim2.new(0, 150, 0, CONFIG.NameTextSize + 4)
	NameContainer.AnchorPoint = Vector2.new(0.5, 1)
	
	local NameText = Instance.new("TextLabel", NameContainer)
	NameText.BackgroundTransparency = 1
	NameText.Size = UDim2.new(1, 0, 1, 0)
	NameText.Font = Enum.Font.Code
	NameText.TextColor3 = CONFIG.NameColor
	NameText.TextSize = CONFIG.NameTextSize
	NameText.TextStrokeTransparency = 0
	NameText.TextXAlignment = Enum.TextXAlignment.Center
	NameText.TextYAlignment = Enum.TextYAlignment.Bottom
	NameText.Text = targetPlayer.Name
	
	espData[targetPlayer] = {
		Container = NameContainer,
		NameLabel = NameText
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
	
	if CONFIG.EnableTeamCheck then
		local isEnemyPlayer = isEnemy(targetPlayer)
		if CONFIG.ShowEnemyOnly and not isEnemyPlayer then
			data.Container.Visible = false
			return
		end
		if CONFIG.ShowAlliedOnly and isEnemyPlayer then
			data.Container.Visible = false
			return
		end
	end
	
	local hrp = targetPlayer.Character.HumanoidRootPart
	local charSize = targetPlayer.Character:GetExtentsSize()
	
	local boxHeight = charSize.Y * 0.8
	local boxWidth = charSize.X * 0.8
	
	local headTop = hrp.Position + Vector3.new(0, charSize.Y / 2, 0)
	local feetBottom = hrp.Position - Vector3.new(0, charSize.Y / 1.4, 0)
	
	local headScreenPos, onScreen = camera:WorldToScreenPoint(headTop)
	local feetScreenPos = camera:WorldToScreenPoint(feetBottom)
	
	if onScreen and headScreenPos.Z > 0 then
		local displayHeight = math.abs(feetScreenPos.Y - headScreenPos.Y)
		local displayWidth = displayHeight * (boxWidth / boxHeight)
		local screenX = (headScreenPos.X + feetScreenPos.X) / 2
		local screenYTop = headScreenPos.Y
		
		local nameY = screenYTop - 2
		
		data.Container.Position = UDim2.new(0, screenX, 0, nameY)
		data.Container.Visible = true
		
		local nameColor = getNameColor(targetPlayer)
		data.NameLabel.TextColor3 = nameColor
		
		data.NameLabel.TextSize = CONFIG.NameTextSize
		
		data.NameLabel.Visible = true
		data.NameLabel.Text = targetPlayer.DisplayName or targetPlayer.Name
	else
		data.Container.Visible = false
	end
end

local function removeEsp(targetPlayer)
	if espData[targetPlayer] then
		espData[targetPlayer].Container:Destroy()
		espData[targetPlayer] = nil
	end
end

local function applyHideNames()
	for _, targetPlayer in pairs(Players:GetPlayers()) do
		if targetPlayer.Character then
			local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.NameDisplayDistance = CONFIG.HidePlayerNames and 0 or 100
				humanoid.HealthDisplayDistance = CONFIG.HidePlayerNames and 0 or 100
			end
		end
	end
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

RunService.Heartbeat:Connect(function()
	if CONFIG.HidePlayerNames then
		for _, targetPlayer in pairs(Players:GetPlayers()) do
			if targetPlayer.Character then
				local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.NameDisplayDistance = 0
					humanoid.HealthDisplayDistance = 0
				end
			end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.HideToggleKey then
		CONFIG.HidePlayerNames = not CONFIG.HidePlayerNames
		applyHideNames()
	end
end)

Players.PlayerAdded:Connect(function(v)
	if v ~= player then
		v.CharacterAdded:Connect(function(character)
			wait(0.5)
			createEsp(v)
			if CONFIG.HidePlayerNames then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.NameDisplayDistance = 0
					humanoid.HealthDisplayDistance = 0
				end
			end
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

local NameESPAPI = {}

function NameESPAPI:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function NameESPAPI:GetConfig()
	return CONFIG
end

function NameESPAPI:Toggle(state)
	CONFIG.Enabled = state
end

function NameESPAPI:Destroy()
	for targetPlayer in pairs(espData) do
		removeEsp(targetPlayer)
	end
	nameScreenGui:Destroy()
end

return NameESPAPI
