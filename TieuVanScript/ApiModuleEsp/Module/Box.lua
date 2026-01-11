local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local CONFIG = {
	BoxColor = Color3.fromRGB(255, 255, 255),
	BoxThickness = 0.5,
	ShowInnerBorder = false,
	InnerThickness = 0.5,
	ShowSelfBox = false,
	SelfBoxColor = Color3.fromRGB(255, 255, 255),
	
	Enabled = false,
	ToggleKey = Enum.KeyCode.G,
	
	EnableTeamCheck = false,
	ShowEnemyOnly = false,
	ShowAlliedOnly = false,
	
	UseTeamColors = false,
	UseActualTeamColors = true,
	EnemyBoxColor = Color3.fromRGB(255, 0, 0),
	AlliedBoxColor = Color3.fromRGB(0, 255, 0),
	NoTeamColor = Color3.fromRGB(255, 255, 255),
	
	ShowGradient = false,
	GradientColor1 = Color3.fromRGB(255, 86, 0),
	GradientColor2 = Color3.fromRGB(255, 0, 128),
	GradientTransparency = 0.7,
	GradientRotation = 90,
	EnableGradientAnimation = false,
	GradientAnimationSpeed = 1,
}

local playerGui = player:WaitForChild("PlayerGui")
local mainScreenGui = Instance.new("ScreenGui")
mainScreenGui.Name = "BoxESP"
mainScreenGui.ResetOnSpawn = false
mainScreenGui.Parent = playerGui

local espBoxes = {}
local gradientAnimationConnection = nil

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

local function getBoxColor(targetPlayer, isSelf)
	if isSelf then
		if CONFIG.UseTeamColors then
			return getPlayerTeamColor(player) or CONFIG.SelfBoxColor
		end
		return CONFIG.SelfBoxColor
	end
	
	if not CONFIG.UseTeamColors then
		return CONFIG.BoxColor
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
			return CONFIG.EnemyBoxColor
		else
			return CONFIG.AlliedBoxColor
		end
	end
end

--=============================================================================
-- BOX CREATION & MANAGEMENT
--=============================================================================

local function updateAllThickness()
	for targetPlayer, espData in pairs(espBoxes) do
		if espData then
			if espData.UIStroke then
				espData.UIStroke.Thickness = CONFIG.BoxThickness
			end
			if espData.InnerUIStroke then
				espData.InnerUIStroke.Thickness = CONFIG.InnerThickness
			end
		end
	end
end

local function updateAllGradients()
	for targetPlayer, espData in pairs(espBoxes) do
		if espData and espData.UIGradient then
			espData.UIGradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.000, CONFIG.GradientColor1),
				ColorSequenceKeypoint.new(1.000, CONFIG.GradientColor2)
			}
			if espData.BoxGradient then
				espData.BoxGradient.BackgroundTransparency = CONFIG.GradientTransparency
			end
		end
	end
end

local function startGradientAnimation()
	if gradientAnimationConnection then
		gradientAnimationConnection:Disconnect()
	end
	
	if not CONFIG.EnableGradientAnimation then return end
	
	local rotationOffset = 0
	gradientAnimationConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not CONFIG.EnableGradientAnimation then
			gradientAnimationConnection:Disconnect()
			gradientAnimationConnection = nil
			return
		end
		
		rotationOffset = (rotationOffset + deltaTime * CONFIG.GradientAnimationSpeed * 100) % 360
		
		for targetPlayer, espData in pairs(espBoxes) do
			if espData and espData.UIGradient then
				espData.UIGradient.Rotation = CONFIG.GradientRotation + rotationOffset
			end
		end
	end)
end

local function stopGradientAnimation()
	if gradientAnimationConnection then
		gradientAnimationConnection:Disconnect()
		gradientAnimationConnection = nil
	end
	
	for targetPlayer, espData in pairs(espBoxes) do
		if espData and espData.UIGradient then
			espData.UIGradient.Rotation = CONFIG.GradientRotation
		end
	end
end

local function createEspBox(targetPlayer)
	if espBoxes[targetPlayer] then return end
	
	local Box = Instance.new("Frame", mainScreenGui)
	Box.Name = "Box_" .. targetPlayer.Name
	Box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Box.BackgroundTransparency = 1
	Box.BorderSizePixel = 0
	
	local UIStroke = Instance.new("UIStroke", Box)
	UIStroke.Thickness = CONFIG.BoxThickness
	UIStroke.Color = CONFIG.BoxColor
	UIStroke.LineJoinMode = Enum.LineJoinMode.Miter
	
	local InnerBorder = Instance.new("Frame", Box)
	InnerBorder.Name = "Inner border"
	InnerBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	InnerBorder.BackgroundTransparency = 1
	InnerBorder.BorderSizePixel = 0
	InnerBorder.ZIndex = 99
	
	local InnerUIStroke = Instance.new("UIStroke", InnerBorder)
	InnerUIStroke.Thickness = CONFIG.InnerThickness
	InnerUIStroke.Color = CONFIG.BoxColor
	InnerUIStroke.LineJoinMode = Enum.LineJoinMode.Miter
	
	local BoxGradient = Instance.new("Frame", Box)
	BoxGradient.Name = "BoxGradient"
	BoxGradient.BorderSizePixel = 0
	BoxGradient.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	BoxGradient.Size = UDim2.new(1, 0, 1, 0)
	BoxGradient.BackgroundTransparency = CONFIG.GradientTransparency
	BoxGradient.Visible = CONFIG.ShowGradient
	
	local UIGradient = Instance.new("UIGradient", BoxGradient)
	UIGradient.Rotation = CONFIG.GradientRotation
	UIGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0.000, CONFIG.GradientColor1),
		ColorSequenceKeypoint.new(1.000, CONFIG.GradientColor2)
	}
	
	espBoxes[targetPlayer] = {
		Box = Box,
		InnerBorder = InnerBorder,
		UIStroke = UIStroke,
		InnerUIStroke = InnerUIStroke,
		BoxGradient = BoxGradient,
		UIGradient = UIGradient
	}
	
	return espBoxes[targetPlayer]
end

local function updateEspBox(targetPlayer, espData)
	if not espData or not espData.Box then return end
	if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
		espData.Box.Visible = false
		return
	end
	
	local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		espData.Box.Visible = false
		return
	end
	
	if CONFIG.EnableTeamCheck then
		local isEnemyPlayer = isEnemy(targetPlayer)
		if CONFIG.ShowEnemyOnly and not isEnemyPlayer then
			espData.Box.Visible = false
			return
		end
		if CONFIG.ShowAlliedOnly and isEnemyPlayer then
			espData.Box.Visible = false
			return
		end
	end
	
	local humanoidRootPart = targetPlayer.Character.HumanoidRootPart
	local charSize = targetPlayer.Character:GetExtentsSize()
	local boxHeight = charSize.Y * 0.8
	local boxWidth = charSize.X * 0.8
	
	local screenSize = mainScreenGui.AbsoluteSize
	local headTop = humanoidRootPart.Position + Vector3.new(0, charSize.Y / 2, 0)
	local feetBottom = humanoidRootPart.Position - Vector3.new(0, charSize.Y / 1.4, 0)
	
	local headScreenPos = camera:WorldToScreenPoint(headTop)
	local feetScreenPos = camera:WorldToScreenPoint(feetBottom)
	
	local screenX = (headScreenPos.X + feetScreenPos.X) / 2
	local screenYTop = headScreenPos.Y
	
	local displayHeight = math.abs(feetScreenPos.Y - headScreenPos.Y)
	local displayWidth = displayHeight * (boxWidth / boxHeight)
	
	espData.Box.Size = UDim2.new(0, displayWidth, 0, displayHeight)
	espData.Box.Position = UDim2.new(0, screenX - displayWidth / 2, 0, screenYTop)
	
	if espData.UIStroke then
		espData.UIStroke.Thickness = CONFIG.BoxThickness
	end
	if espData.InnerUIStroke then
		espData.InnerUIStroke.Thickness = CONFIG.InnerThickness
	end
	
	if espData.InnerBorder then
		if CONFIG.ShowInnerBorder then
			espData.InnerBorder.Visible = true
			espData.InnerBorder.Size = UDim2.new(0, displayWidth - 4, 0, displayHeight - 4)
			espData.InnerBorder.Position = UDim2.new(0, 2, 0, 2)
		else
			espData.InnerBorder.Visible = false
		end
	end
	
	if espData.BoxGradient then
		espData.BoxGradient.Visible = CONFIG.ShowGradient
		espData.BoxGradient.BackgroundTransparency = CONFIG.GradientTransparency
	end
	
	if espData.UIGradient then
		espData.UIGradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0.000, CONFIG.GradientColor1),
			ColorSequenceKeypoint.new(1.000, CONFIG.GradientColor2)
		}
		if not CONFIG.EnableGradientAnimation then
			espData.UIGradient.Rotation = CONFIG.GradientRotation
		end
	end
	
	local boxColor = getBoxColor(targetPlayer, false)
	if espData.UIStroke then
		espData.UIStroke.Color = boxColor
	end
	if espData.InnerUIStroke then
		espData.InnerUIStroke.Color = boxColor
	end
	
	if headScreenPos.Z > 0 and screenX > 0 and screenX < screenSize.X then
		espData.Box.Visible = true
	else
		espData.Box.Visible = false
	end
end

local function removeEspBox(targetPlayer)
	if espBoxes[targetPlayer] then
		espBoxes[targetPlayer].Box:Destroy()
		espBoxes[targetPlayer] = nil
	end
end

local function createSelfBox()
	if not player.Character then return end
	if espBoxes[player] then return end
	
	local Box = Instance.new("Frame", mainScreenGui)
	Box.Name = "SelfBox"
	Box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Box.BackgroundTransparency = 1
	Box.BorderSizePixel = 0
	Box.Size = UDim2.new(0, 100, 0, 100)
	Box.Position = UDim2.new(0.5, -50, 0.5, -50)
	Box.Visible = false
	
	local UIStroke = Instance.new("UIStroke", Box)
	UIStroke.Thickness = CONFIG.BoxThickness
	UIStroke.Color = CONFIG.SelfBoxColor
	UIStroke.LineJoinMode = Enum.LineJoinMode.Miter
	
	local InnerBorder = Instance.new("Frame", Box)
	InnerBorder.Name = "Inner border"
	InnerBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	InnerBorder.BackgroundTransparency = 1
	InnerBorder.BorderSizePixel = 0
	InnerBorder.ZIndex = 99
	InnerBorder.Size = UDim2.new(0, 96, 0, 96)
	InnerBorder.Position = UDim2.new(0, 2, 0, 2)
	InnerBorder.Visible = CONFIG.ShowInnerBorder
	
	local InnerUIStroke = Instance.new("UIStroke", InnerBorder)
	InnerUIStroke.Thickness = CONFIG.InnerThickness
	InnerUIStroke.Color = CONFIG.SelfBoxColor
	InnerUIStroke.LineJoinMode = Enum.LineJoinMode.Miter
	
	local BoxGradient = Instance.new("Frame", Box)
	BoxGradient.Name = "BoxGradient"
	BoxGradient.BorderSizePixel = 0
	BoxGradient.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	BoxGradient.Size = UDim2.new(1, 0, 1, 0)
	BoxGradient.BackgroundTransparency = CONFIG.GradientTransparency
	BoxGradient.Visible = CONFIG.ShowGradient
	
	local UIGradient = Instance.new("UIGradient", BoxGradient)
	UIGradient.Rotation = CONFIG.GradientRotation
	UIGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0.000, CONFIG.GradientColor1),
		ColorSequenceKeypoint.new(1.000, CONFIG.GradientColor2)
	}
	
	espBoxes[player] = {
		Box = Box,
		InnerBorder = InnerBorder,
		UIStroke = UIStroke,
		InnerUIStroke = InnerUIStroke,
		BoxGradient = BoxGradient,
		UIGradient = UIGradient
	}
end

local function updateSelfBox()
	if not espBoxes[player] then return end
	
	local espData = espBoxes[player]
	
	if not CONFIG.ShowSelfBox or not CONFIG.Enabled then
		if espData.Box then
			espData.Box.Visible = false
		end
		return
	end
	
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		espData.Box.Visible = false
		return
	end
	
	local humanoid = player.Character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		espData.Box.Visible = false
		return
	end
	
	local humanoidRootPart = player.Character.HumanoidRootPart
	local charSize = player.Character:GetExtentsSize()
	local boxHeight = charSize.Y * 0.8
	local boxWidth = charSize.X * 0.8
	
	local screenSize = mainScreenGui.AbsoluteSize
	local headTop = humanoidRootPart.Position + Vector3.new(0, charSize.Y / 2, 0)
	local feetBottom = humanoidRootPart.Position - Vector3.new(0, charSize.Y / 1.4, 0)
	
	local headScreenPos = camera:WorldToScreenPoint(headTop)
	local feetScreenPos = camera:WorldToScreenPoint(feetBottom)
	
	local screenX = (headScreenPos.X + feetScreenPos.X) / 2
	local screenYTop = headScreenPos.Y
	
	local displayHeight = math.abs(feetScreenPos.Y - headScreenPos.Y)
	local displayWidth = displayHeight * (boxWidth / boxHeight)
	
	espData.Box.Size = UDim2.new(0, displayWidth, 0, displayHeight)
	espData.Box.Position = UDim2.new(0, screenX - displayWidth / 2, 0, screenYTop)
	
	if espData.UIStroke then
		espData.UIStroke.Thickness = CONFIG.BoxThickness
	end
	if espData.InnerUIStroke then
		espData.InnerUIStroke.Thickness = CONFIG.InnerThickness
	end
	
	local boxColor = getBoxColor(player, true)
	if espData.UIStroke then
		espData.UIStroke.Color = boxColor
	end
	if espData.InnerUIStroke then
		espData.InnerUIStroke.Color = boxColor
	end
	
	if espData.InnerBorder then
		if CONFIG.ShowInnerBorder then
			espData.InnerBorder.Visible = true
			espData.InnerBorder.Size = UDim2.new(0, displayWidth - 4, 0, displayHeight - 4)
			espData.InnerBorder.Position = UDim2.new(0, 2, 0, 2)
		else
			espData.InnerBorder.Visible = false
		end
	end
	
	if espData.BoxGradient then
		espData.BoxGradient.Visible = CONFIG.ShowGradient
		espData.BoxGradient.BackgroundTransparency = CONFIG.GradientTransparency
	end
	
	if espData.UIGradient then
		espData.UIGradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0.000, CONFIG.GradientColor1),
			ColorSequenceKeypoint.new(1.000, CONFIG.GradientColor2)
		}
		if not CONFIG.EnableGradientAnimation then
			espData.UIGradient.Rotation = CONFIG.GradientRotation
		end
	end
	
	if headScreenPos.Z > 0 and screenX > 0 and screenX < screenSize.X then
		espData.Box.Visible = true
	else
		espData.Box.Visible = false
	end
end

local function updateAllEsp()
	for targetPlayer, espData in pairs(espBoxes) do
		if targetPlayer and targetPlayer.Parent and espData then
			if targetPlayer == player then
				continue
			end
			
			if CONFIG.Enabled and shouldShowPlayer(targetPlayer) then
				updateEspBox(targetPlayer, espData)
			else
				espData.Box.Visible = false
			end
		else
			removeEspBox(targetPlayer)
		end
	end
end

--=============================================================================
-- EVENT HANDLERS
--=============================================================================

local function onPlayerAdded(newPlayer)
	if newPlayer ~= player then
		if shouldShowPlayer(newPlayer) then
			wait(0.5)
			createEspBox(newPlayer)
		end
	end
end

local function onPlayerRemoving(leavingPlayer)
	removeEspBox(leavingPlayer)
end

--=============================================================================
-- INITIALIZATION
--=============================================================================

createSelfBox()
player.CharacterAdded:Connect(function()
	wait(0.5)
	if espBoxes[player] then
		espBoxes[player].Box:Destroy()
	end
	espBoxes[player] = nil
	createSelfBox()
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, otherPlayer in pairs(Players:GetPlayers()) do
	if otherPlayer ~= player then
		onPlayerAdded(otherPlayer)
	end
end

RunService.RenderStepped:Connect(function()
	updateAllEsp()
	updateSelfBox()
end)

--=============================================================================
-- PUBLIC API
--=============================================================================

local BoxESPAPI = {}

function BoxESPAPI:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function BoxESPAPI:GetConfig()
	return CONFIG
end

function BoxESPAPI:Toggle(state)
	CONFIG.Enabled = state
end

function BoxESPAPI:Destroy()
	for targetPlayer in pairs(espBoxes) do
		removeEspBox(targetPlayer)
	end
	mainScreenGui:Destroy()
end

return BoxESPAPI
