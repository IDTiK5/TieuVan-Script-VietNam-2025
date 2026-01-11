--[[
    BoxESP API Module
    Handles all core box ESP logic and calculations
    GitHub Ready
]]

local BoxESP_API = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ===== CONFIG =====
BoxESP_API.CONFIG = {
    -- Main Settings
    Enabled = false,
    ShowSelfBox = false,
    
    -- Box Styling
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxThickness = 0.5,
    ShowInnerBorder = false,
    InnerThickness = 0.5,
    
    -- Self Box
    SelfBoxColor = Color3.fromRGB(255, 255, 255),
    
    -- Team Settings
    EnableTeamCheck = false,
    ShowEnemyOnly = false,
    ShowAlliedOnly = false,
    
    -- Team Colors
    UseTeamColors = false,
    UseActualTeamColors = true,
    EnemyBoxColor = Color3.fromRGB(255, 0, 0),
    AlliedBoxColor = Color3.fromRGB(0, 255, 0),
    NoTeamColor = Color3.fromRGB(255, 255, 255),
    
    -- Gradient
    ShowGradient = false,
    GradientColor1 = Color3.fromRGB(255, 86, 0),
    GradientColor2 = Color3.fromRGB(255, 0, 128),
    GradientTransparency = 0.7,
    GradientRotation = 90,
    EnableGradientAnimation = false,
    GradientAnimationSpeed = 1,
}

-- ===== STATE =====
BoxESP_API.STATE = {
    espBoxes = {},
    gradientAnimationConnection = nil,
}

-- ===== HELPER FUNCTIONS =====
function BoxESP_API:GetCharacter(player)
    return player and player.Character
end

function BoxESP_API:GetCharacterPart(player, partName)
    local char = self:GetCharacter(player)
    return char and char:FindFirstChild(partName)
end

function BoxESP_API:GetHumanoid(player)
    local char = self:GetCharacter(player)
    return char and (char:FindFirstChild("Humanoid") or char:FindFirstChildOfClass("Humanoid"))
end

function BoxESP_API:IsPlayerAlive(player)
    if not self:GetCharacter(player) or not self:GetCharacterPart(player, "HumanoidRootPart") then
        return false
    end
    
    local humanoid = self:GetHumanoid(player)
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    
    return true
end

-- ===== TEAM FUNCTIONS =====
function BoxESP_API:GameHasTeams()
    local teams = game:GetService("Teams")
    if not teams then return false end
    return #teams:GetTeams() > 0
end

function BoxESP_API:GetPlayerTeamColor(targetPlayer)
    if not targetPlayer or not targetPlayer.Team then return nil end
    return targetPlayer.Team.TeamColor.Color
end

function BoxESP_API:IsEnemy(targetPlayer)
    if not targetPlayer or not self:GetCharacter(targetPlayer) then return true end
    
    if not self:GameHasTeams() then return true end
    
    if not LocalPlayer.Team then
        return not (targetPlayer.Team == nil)
    end
    
    if not targetPlayer.Team then return true end
    
    return LocalPlayer.Team ~= targetPlayer.Team
end

function BoxESP_API:ShouldShowPlayer(targetPlayer)
    if not self.CONFIG.EnableTeamCheck then return true end
    
    local isEnemyPlayer = self:IsEnemy(targetPlayer)
    if self.CONFIG.ShowEnemyOnly and not isEnemyPlayer then return false end
    if self.CONFIG.ShowAlliedOnly and isEnemyPlayer then return false end
    
    return true
end

-- ===== COLOR FUNCTIONS =====
function BoxESP_API:GetBoxColor(targetPlayer, isSelf)
    if isSelf then
        if self.CONFIG.UseTeamColors then
            return self:GetPlayerTeamColor(LocalPlayer) or self.CONFIG.SelfBoxColor
        end
        return self.CONFIG.SelfBoxColor
    end
    
    if not self.CONFIG.UseTeamColors then
        return self.CONFIG.BoxColor
    end
    
    if self.CONFIG.UseActualTeamColors then
        local teamColor = self:GetPlayerTeamColor(targetPlayer)
        return teamColor or self.CONFIG.NoTeamColor
    else
        local isEnemyPlayer = self:IsEnemy(targetPlayer)
        return isEnemyPlayer and self.CONFIG.EnemyBoxColor or self.CONFIG.AlliedBoxColor
    end
end

-- ===== POSITION CALCULATION =====
function BoxESP_API:GetScreenPosition(position)
    local screenPos, onScreen = Camera:WorldToScreenPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

function BoxESP_API:CalculateBoxPosition(targetPlayer)
    if not self:IsPlayerAlive(targetPlayer) then return nil end
    
    local humanoidRootPart = self:GetCharacterPart(targetPlayer, "HumanoidRootPart")
    local charSize = self:GetCharacter(targetPlayer):GetExtentsSize()
    
    local boxHeight = charSize.Y * 0.8
    local boxWidth = charSize.X * 0.8
    
    local headTop = humanoidRootPart.Position + Vector3.new(0, charSize.Y / 2, 0)
    local feetBottom = humanoidRootPart.Position - Vector3.new(0, charSize.Y / 1.4, 0)
    
    local headScreenPos = Camera:WorldToScreenPoint(headTop)
    local feetScreenPos = Camera:WorldToScreenPoint(feetBottom)
    
    local screenX = (headScreenPos.X + feetScreenPos.X) / 2
    local screenYTop = headScreenPos.Y
    
    local displayHeight = math.abs(feetScreenPos.Y - headScreenPos.Y)
    local displayWidth = displayHeight * (boxWidth / boxHeight)
    
    local screenSize = Camera.ViewportSize
    local isVisible = headScreenPos.Z > 0 and screenX > 0 and screenX < screenSize.X
    
    return {
        Size = UDim2.new(0, displayWidth, 0, displayHeight),
        Position = UDim2.new(0, screenX - displayWidth / 2, 0, screenYTop),
        IsVisible = isVisible,
        DisplayWidth = displayWidth,
        DisplayHeight = displayHeight
    }
end

-- ===== UPDATE FUNCTIONS =====
function BoxESP_API:UpdateAllThickness()
    for targetPlayer, espData in pairs(self.STATE.espBoxes) do
        if espData then
            if espData.UIStroke then
                espData.UIStroke.Thickness = self.CONFIG.BoxThickness
            end
            if espData.InnerUIStroke then
                espData.InnerUIStroke.Thickness = self.CONFIG.InnerThickness
            end
        end
    end
end

function BoxESP_API:UpdateAllGradients()
    for targetPlayer, espData in pairs(self.STATE.espBoxes) do
        if espData and espData.UIGradient then
            espData.UIGradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0.000, self.CONFIG.GradientColor1),
                ColorSequenceKeypoint.new(1.000, self.CONFIG.GradientColor2)
            }
            if espData.BoxGradient then
                espData.BoxGradient.BackgroundTransparency = self.CONFIG.GradientTransparency
            end
        end
    end
end

-- ===== ANIMATION =====
function BoxESP_API:StartGradientAnimation()
    if self.STATE.gradientAnimationConnection then
        self.STATE.gradientAnimationConnection:Disconnect()
    end
    
    if not self.CONFIG.EnableGradientAnimation then return end
    
    local rotationOffset = 0
    self.STATE.gradientAnimationConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not self.CONFIG.EnableGradientAnimation then
            if self.STATE.gradientAnimationConnection then
                self.STATE.gradientAnimationConnection:Disconnect()
                self.STATE.gradientAnimationConnection = nil
            end
            return
        end
        
        rotationOffset = (rotationOffset + deltaTime * self.CONFIG.GradientAnimationSpeed * 100) % 360
        
        for targetPlayer, espData in pairs(self.STATE.espBoxes) do
            if espData and espData.UIGradient then
                espData.UIGradient.Rotation = self.CONFIG.GradientRotation + rotationOffset
            end
        end
    end)
end

function BoxESP_API:StopGradientAnimation()
    if self.STATE.gradientAnimationConnection then
        self.STATE.gradientAnimationConnection:Disconnect()
        self.STATE.gradientAnimationConnection = nil
    end
    
    for targetPlayer, espData in pairs(self.STATE.espBoxes) do
        if espData and espData.UIGradient then
            espData.UIGradient.Rotation = self.CONFIG.GradientRotation
        end
    end
end

-- ===== BOX ELEMENT FUNCTIONS =====
function BoxESP_API:CreateBoxFrame(parent, name, transparency)
    local Box = Instance.new("Frame", parent)
    Box.Name = name
    Box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Box.BackgroundTransparency = transparency
    Box.BorderSizePixel = 0
    return Box
end

function BoxESP_API:CreateUIStroke(parent, thickness, color)
    local UIStroke = Instance.new("UIStroke", parent)
    UIStroke.Thickness = thickness
    UIStroke.Color = color
    UIStroke.LineJoinMode = Enum.LineJoinMode.Miter
    return UIStroke
end

function BoxESP_API:CreateGradient(parent, gradientColor1, gradientColor2, gradientTransparency, gradientRotation, showGradient)
    local BoxGradient = self:CreateBoxFrame(parent, "BoxGradient", gradientTransparency)
    BoxGradient.Size = UDim2.new(1, 0, 1, 0)
    BoxGradient.Visible = showGradient
    
    local UIGradient = Instance.new("UIGradient", BoxGradient)
    UIGradient.Rotation = gradientRotation
    UIGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.000, gradientColor1),
        ColorSequenceKeypoint.new(1.000, gradientColor2)
    }
    
    return {
        Frame = BoxGradient,
        UIGradient = UIGradient
    }
end

function BoxESP_API:CreateEspBox(parent, targetPlayer)
    local Box = self:CreateBoxFrame(parent, "Box_" .. targetPlayer.Name, 1)
    
    local UIStroke = self:CreateUIStroke(Box, self.CONFIG.BoxThickness, self.CONFIG.BoxColor)
    
    local InnerBorder = self:CreateBoxFrame(Box, "Inner border", 1)
    InnerBorder.ZIndex = 99
    local InnerUIStroke = self:CreateUIStroke(InnerBorder, self.CONFIG.InnerThickness, self.CONFIG.BoxColor)
    InnerBorder.Visible = self.CONFIG.ShowInnerBorder
    
    local Gradient = self:CreateGradient(
        Box,
        self.CONFIG.GradientColor1,
        self.CONFIG.GradientColor2,
        self.CONFIG.GradientTransparency,
        self.CONFIG.GradientRotation,
        self.CONFIG.ShowGradient
    )
    
    return {
        Box = Box,
        InnerBorder = InnerBorder,
        UIStroke = UIStroke,
        InnerUIStroke = InnerUIStroke,
        BoxGradient = Gradient.Frame,
        UIGradient = Gradient.UIGradient
    }
end

function BoxESP_API:CreateSelfBox(parent)
    local Box = self:CreateBoxFrame(parent, "SelfBox", 1)
    Box.Size = UDim2.new(0, 100, 0, 100)
    Box.Position = UDim2.new(0.5, -50, 0.5, -50)
    Box.Visible = false
    
    local UIStroke = self:CreateUIStroke(Box, self.CONFIG.BoxThickness, self.CONFIG.SelfBoxColor)
    
    local InnerBorder = self:CreateBoxFrame(Box, "Inner border", 1)
    InnerBorder.ZIndex = 99
    InnerBorder.Size = UDim2.new(0, 96, 0, 96)
    InnerBorder.Position = UDim2.new(0, 2, 0, 2)
    local InnerUIStroke = self:CreateUIStroke(InnerBorder, self.CONFIG.InnerThickness, self.CONFIG.SelfBoxColor)
    InnerBorder.Visible = self.CONFIG.ShowInnerBorder
    
    local Gradient = self:CreateGradient(
        Box,
        self.CONFIG.GradientColor1,
        self.CONFIG.GradientColor2,
        self.CONFIG.GradientTransparency,
        self.CONFIG.GradientRotation,
        self.CONFIG.ShowGradient
    )
    
    return {
        Box = Box,
        InnerBorder = InnerBorder,
        UIStroke = UIStroke,
        InnerUIStroke = InnerUIStroke,
        BoxGradient = Gradient.Frame,
        UIGradient = Gradient.UIGradient
    }
end

function BoxESP_API:UpdateEspBoxVisuals(espData, boxData)
    if not espData or not espData.Box then return end
    
    espData.Box.Size = boxData.Size
    espData.Box.Position = boxData.Position
    espData.Box.Visible = boxData.IsVisible
    
    if espData.UIStroke then
        espData.UIStroke.Thickness = self.CONFIG.BoxThickness
    end
    if espData.InnerUIStroke then
        espData.InnerUIStroke.Thickness = self.CONFIG.InnerThickness
    end
    
    if espData.InnerBorder then
        if self.CONFIG.ShowInnerBorder then
            espData.InnerBorder.Visible = true
            espData.InnerBorder.Size = UDim2.new(0, boxData.DisplayWidth - 4, 0, boxData.DisplayHeight - 4)
            espData.InnerBorder.Position = UDim2.new(0, 2, 0, 2)
        else
            espData.InnerBorder.Visible = false
        end
    end
    
    if espData.BoxGradient then
        espData.BoxGradient.Visible = self.CONFIG.ShowGradient
        espData.BoxGradient.BackgroundTransparency = self.CONFIG.GradientTransparency
    end
    
    if espData.UIGradient then
        espData.UIGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0.000, self.CONFIG.GradientColor1),
            ColorSequenceKeypoint.new(1.000, self.CONFIG.GradientColor2)
        }
        if not self.CONFIG.EnableGradientAnimation then
            espData.UIGradient.Rotation = self.CONFIG.GradientRotation
        end
    end
end

function BoxESP_API:UpdateBoxColor(espData, color)
    if espData.UIStroke then
        espData.UIStroke.Color = color
    end
    if espData.InnerUIStroke then
        espData.InnerUIStroke.Color = color
    end
end

function BoxESP_API:RemoveEspBox(espData)
    if espData and espData.Box then
        espData.Box:Destroy()
    end
end

function BoxESP_API:SetBoxVisibility(espData, visible)
    if espData and espData.Box then
        espData.Box.Visible = visible
    end
end

return BoxESP_API
