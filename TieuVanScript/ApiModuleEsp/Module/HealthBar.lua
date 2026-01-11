--[[
    HealthBar API Module
    Handles all core health bar logic and calculations
    GitHub Ready
]]

local HealthBar_API = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ===== CONFIG =====
HealthBar_API.CONFIG = {
    -- Main Settings
    Enabled = false,
    ShowSelfHealthBar = false,
    
    -- Bar Styling
    HealthBarColor = Color3.fromRGB(180, 0, 255),
    HealthBarWidth = 3,
    HealthBarGap = 2,
    Side = "Left",
    OffsetX = 0,
    OffsetY = 0,
    
    -- Team Settings
    EnableTeamCheck = false,
    ShowEnemyOnly = false,
    ShowAlliedOnly = false,
    
    -- Team Colors
    UseTeamColors = false,
    UseActualTeamColors = true,
    EnemyHealthBarColor = Color3.fromRGB(180, 0, 255),
    AlliedHealthBarColor = Color3.fromRGB(0, 255, 0),
    NoTeamColor = Color3.fromRGB(255, 255, 255),
    
    -- Animation
    AnimationSpeed = 0.3,
    AnimationStyle = Enum.EasingStyle.Quart,
    AnimationDirection = Enum.EasingDirection.Out,
    
    -- Effects
    EnableFlashEffect = true,
    DamageFlashColor = Color3.fromRGB(255, 0, 0),
    HealFlashColor = Color3.fromRGB(0, 255, 100),
    FlashDuration = 0.15,
}

-- ===== STATE =====
HealthBar_API.STATE = {
    healthBars = {},
}

-- ===== HELPER FUNCTIONS =====
function HealthBar_API:GetCharacter(player)
    return player and player.Character
end

function HealthBar_API:GetCharacterPart(player, partName)
    local char = self:GetCharacter(player)
    return char and char:FindFirstChild(partName)
end

function HealthBar_API:GetHumanoid(player)
    local char = self:GetCharacter(player)
    return char and (char:FindFirstChild("Humanoid") or char:FindFirstChildOfClass("Humanoid"))
end

function HealthBar_API:IsPlayerAlive(player)
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
function HealthBar_API:GameHasTeams()
    local teams = game:GetService("Teams")
    if not teams then return false end
    return #teams:GetTeams() > 0
end

function HealthBar_API:GetPlayerTeamColor(targetPlayer)
    if not targetPlayer or not targetPlayer.Team then return nil end
    return targetPlayer.Team.TeamColor.Color
end

function HealthBar_API:IsEnemy(targetPlayer)
    if not targetPlayer or not self:GetCharacter(targetPlayer) then return true end
    
    if not self:GameHasTeams() then return true end
    
    if not LocalPlayer.Team then
        return not (targetPlayer.Team == nil)
    end
    
    if not targetPlayer.Team then return true end
    
    return LocalPlayer.Team ~= targetPlayer.Team
end

function HealthBar_API:ShouldShowPlayer(targetPlayer)
    if not self.CONFIG.EnableTeamCheck then return true end
    
    local isEnemyPlayer = self:IsEnemy(targetPlayer)
    if self.CONFIG.ShowEnemyOnly and not isEnemyPlayer then return false end
    if self.CONFIG.ShowAlliedOnly and isEnemyPlayer then return false end
    
    return true
end

-- ===== COLOR FUNCTIONS =====
function HealthBar_API:GetHealthGradientColor(healthPercent)
    if healthPercent > 0.5 then
        local t = (healthPercent - 0.5) * 2
        return Color3.fromRGB(
            math.floor(255 * (1 - t)),
            255,
            0
        )
    else
        local t = healthPercent * 2
        return Color3.fromRGB(
            255,
            math.floor(255 * t),
            0
        )
    end
end

function HealthBar_API:GetBarColor(targetPlayer, healthPercent, isSelf)
    if not self.CONFIG.UseTeamColors then
        return self:GetHealthGradientColor(healthPercent)
    end
    
    if self.CONFIG.UseActualTeamColors then
        local teamColor = self:GetPlayerTeamColor(targetPlayer)
        if teamColor then
            return teamColor
        else
            return isSelf and self:GetHealthGradientColor(healthPercent) or self.CONFIG.NoTeamColor
        end
    else
        if isSelf then
            return self.CONFIG.AlliedHealthBarColor
        end
        
        local isEnemyPlayer = self:IsEnemy(targetPlayer)
        return isEnemyPlayer and self.CONFIG.EnemyHealthBarColor or self.CONFIG.AlliedHealthBarColor
    end
end

-- ===== POSITION CALCULATION =====
function HealthBar_API:GetBoxBounds(targetPlayer)
    if not targetPlayer or not self:GetCharacter(targetPlayer) then return nil end
    
    local humanoidRootPart = self:GetCharacterPart(targetPlayer, "HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    local humanoid = self:GetHumanoid(targetPlayer)
    if not humanoid or humanoid.Health <= 0 then return nil end
    
    local charSize = self:GetCharacter(targetPlayer):GetExtentsSize()
    
    local boxHeight = charSize.Y * 0.8
    local boxWidth = charSize.X * 0.8
    
    local headTop = humanoidRootPart.Position + Vector3.new(0, charSize.Y / 2, 0)
    local feetBottom = humanoidRootPart.Position - Vector3.new(0, charSize.Y / 1.4, 0)
    
    local headScreenPos = Camera:WorldToScreenPoint(headTop)
    local feetScreenPos = Camera:WorldToScreenPoint(feetBottom)
    
    if headScreenPos.Z <= 0 then return nil end
    
    local screenX = (headScreenPos.X + feetScreenPos.X) / 2
    local screenYTop = headScreenPos.Y
    
    local displayHeight = math.abs(feetScreenPos.Y - headScreenPos.Y)
    local displayWidth = displayHeight * (boxWidth / boxHeight)
    
    if displayHeight <= 0 or displayWidth <= 0 then return nil end
    
    return {
        X = screenX - displayWidth / 2,
        Y = screenYTop,
        Width = displayWidth,
        Height = displayHeight,
        Visible = true
    }
end

-- ===== ANIMATION FUNCTIONS =====
function HealthBar_API:CreateFlashEffect(barData, isDamage)
    if not self.CONFIG.EnableFlashEffect or not barData or not barData.FlashOverlay then return end
    
    local flashColor = isDamage and self.CONFIG.DamageFlashColor or self.CONFIG.HealFlashColor
    barData.FlashOverlay.BackgroundColor3 = flashColor
    barData.FlashOverlay.BackgroundTransparency = 0.3
    
    local flashTween = TweenService:Create(
        barData.FlashOverlay,
        TweenInfo.new(self.CONFIG.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    )
    flashTween:Play()
end

function HealthBar_API:AnimateHealthBar(barData, targetPercent, targetColor, isDamage)
    if not barData or not barData.HealthBar then return end
    
    if barData.LastHealth and barData.LastHealth ~= targetPercent then
        self:CreateFlashEffect(barData, isDamage)
    end
    barData.LastHealth = targetPercent
    
    if barData.CurrentTween then
        barData.CurrentTween:Cancel()
    end
    
    local tweenInfo = TweenInfo.new(
        self.CONFIG.AnimationSpeed,
        self.CONFIG.AnimationStyle,
        self.CONFIG.AnimationDirection
    )
    
    local sizeTween = TweenService:Create(
        barData.HealthBar,
        tweenInfo,
        {
            Size = UDim2.new(1, 0, targetPercent, 0),
            Position = UDim2.new(0, 0, 1 - targetPercent, 0)
        }
    )
    
    local colorTween = TweenService:Create(
        barData.HealthBar,
        tweenInfo,
        {BackgroundColor3 = targetColor}
    )
    
    sizeTween:Play()
    colorTween:Play()
    
    barData.CurrentTween = sizeTween
    
    if isDamage and barData.DamageTrail then
        task.delay(0.1, function()
            if barData.DamageTrail then
                local trailTween = TweenService:Create(
                    barData.DamageTrail,
                    TweenInfo.new(self.CONFIG.AnimationSpeed * 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {
                        Size = UDim2.new(1, 0, targetPercent, 0),
                        Position = UDim2.new(0, 0, 1 - targetPercent, 0)
                    }
                )
                trailTween:Play()
            end
        end)
    elseif barData.DamageTrail then
        barData.DamageTrail.Size = UDim2.new(1, 0, targetPercent, 0)
        barData.DamageTrail.Position = UDim2.new(0, 0, 1 - targetPercent, 0)
    end
end

-- ===== HEALTH BAR ELEMENT FUNCTIONS =====
function HealthBar_API:CreateHealthBarFrame(parent, targetPlayer)
    local OutlineBar = Instance.new("Frame")
    OutlineBar.Name = "HealthBar_" .. targetPlayer.Name
    OutlineBar.Size = UDim2.new(0, self.CONFIG.HealthBarWidth, 0, 100)
    OutlineBar.Position = UDim2.new(0, 0, 0, 0)
    OutlineBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    OutlineBar.BackgroundTransparency = 0.3
    OutlineBar.BorderSizePixel = 0
    OutlineBar.AnchorPoint = Vector2.new(0, 0)
    OutlineBar.Visible = false
    OutlineBar.Parent = parent
    
    local OutlineStroke = Instance.new("UIStroke")
    OutlineStroke.Thickness = 1
    OutlineStroke.Color = Color3.fromRGB(0, 0, 0)
    OutlineStroke.LineJoinMode = Enum.LineJoinMode.Miter
    OutlineStroke.Parent = OutlineBar
    
    local DamageTrail = Instance.new("Frame")
    DamageTrail.Name = "DamageTrail"
    DamageTrail.Size = UDim2.new(1, 0, 1, 0)
    DamageTrail.Position = UDim2.new(0, 0, 0, 0)
    DamageTrail.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    DamageTrail.BackgroundTransparency = 0.3
    DamageTrail.BorderSizePixel = 0
    DamageTrail.ZIndex = 1
    DamageTrail.Parent = OutlineBar
    
    local HealthBar = Instance.new("Frame")
    HealthBar.Name = "HealthBar"
    HealthBar.Size = UDim2.new(1, 0, 1, 0)
    HealthBar.Position = UDim2.new(0, 0, 0, 0)
    HealthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    HealthBar.BorderSizePixel = 0
    HealthBar.ZIndex = 2
    HealthBar.Parent = OutlineBar
    
    local FlashOverlay = Instance.new("Frame")
    FlashOverlay.Name = "FlashOverlay"
    FlashOverlay.Size = UDim2.new(1, 0, 1, 0)
    FlashOverlay.Position = UDim2.new(0, 0, 0, 0)
    FlashOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    FlashOverlay.BackgroundTransparency = 1
    FlashOverlay.BorderSizePixel = 0
    FlashOverlay.ZIndex = 3
    FlashOverlay.Parent = OutlineBar
    
    return {
        OutlineBar = OutlineBar,
        HealthBar = HealthBar,
        DamageTrail = DamageTrail,
        FlashOverlay = FlashOverlay,
        IsSelf = false,
        LastHealth = 1,
        CurrentTween = nil
    }
end

function HealthBar_API:CreateHealthBar(parent, targetPlayer)
    if self.STATE.healthBars[targetPlayer] then return end
    self.STATE.healthBars[targetPlayer] = self:CreateHealthBarFrame(parent, targetPlayer)
end

function HealthBar_API:CreateSelfHealthBar(parent)
    if self.STATE.healthBars[LocalPlayer] then return end
    local barData = self:CreateHealthBarFrame(parent, LocalPlayer)
    barData.IsSelf = true
    self.STATE.healthBars[LocalPlayer] = barData
end

function HealthBar_API:UpdateHealthBar(targetPlayer, barData, screenGui)
    if not barData or not barData.OutlineBar or not barData.OutlineBar.Parent then return end
    
    if not self.CONFIG.Enabled then
        barData.OutlineBar.Visible = false
        return
    end
    
    if not targetPlayer or not targetPlayer.Parent or not self:IsPlayerAlive(targetPlayer) then
        barData.OutlineBar.Visible = false
        return
    end
    
    if not barData.IsSelf and not self:ShouldShowPlayer(targetPlayer) then
        barData.OutlineBar.Visible = false
        return
    end
    
    local boxBounds = self:GetBoxBounds(targetPlayer)
    if not boxBounds then
        barData.OutlineBar.Visible = false
        return
    end
    
    local healthBarX = self.CONFIG.Side == "Left" 
        and (boxBounds.X - self.CONFIG.HealthBarWidth - self.CONFIG.HealthBarGap)
        or (boxBounds.X + boxBounds.Width + self.CONFIG.HealthBarGap)
    
    healthBarX = healthBarX + self.CONFIG.OffsetX
    local healthBarY = boxBounds.Y + self.CONFIG.OffsetY
    
    barData.OutlineBar.Size = UDim2.new(0, self.CONFIG.HealthBarWidth, 0, boxBounds.Height)
    barData.OutlineBar.Position = UDim2.new(0, healthBarX, 0, healthBarY)
    
    local humanoid = self:GetHumanoid(targetPlayer)
    local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
    local barColor = self:GetBarColor(targetPlayer, healthPercent, barData.IsSelf)
    local isDamage = barData.LastHealth and healthPercent < barData.LastHealth
    
    if barData.LastHealth ~= healthPercent then
        self:AnimateHealthBar(barData, healthPercent, barColor, isDamage)
    else
        barData.HealthBar.BackgroundColor3 = barColor
    end
    
    local screenSize = screenGui.AbsoluteSize
    local isOnScreen = healthBarX > -50 and healthBarX < screenSize.X + 50 and healthBarY > -50 and healthBarY < screenSize.Y + 50
    barData.OutlineBar.Visible = isOnScreen
end

function HealthBar_API:RemoveHealthBar(targetPlayer)
    if self.STATE.healthBars[targetPlayer] then
        local barData = self.STATE.healthBars[targetPlayer]
        if barData.CurrentTween then
            barData.CurrentTween:Cancel()
        end
        if barData.OutlineBar then
            barData.OutlineBar:Destroy()
        end
        self.STATE.healthBars[targetPlayer] = nil
    end
end

return HealthBar_API
