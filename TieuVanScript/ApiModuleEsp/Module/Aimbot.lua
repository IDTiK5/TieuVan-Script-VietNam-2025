local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = false,
    FOV = {
        Size = 100,
        Hidden = false,
        Color = Color3.fromRGB(255, 255, 255),
        Rainbow = {Enabled = false, Speed = 1},
        OffsetX = 0,
        OffsetY = 0,
        DefaultSize = 100,
        DefaultOffsetX = 0,
        DefaultOffsetY = 0
    },
    Target = "Head",
    TargetPriority = {"Head", "HumanoidRootPart", "UpperTorso"},
    Range = 5000,
    Speed = 50,
    TeamCheck = false,
    WallCheck = false,
    AliveCheck = false,
    LockEnabled = false,
    LockBreakOnDeath = false,
    MovementMode = {
        Mode = "Both",
        StandingThreshold = 2,
        RunningThreshold = 10
    },
    Prediction = {
        Enabled = false,
        Factor = 12,
        Mode = "Linear",
        VelocitySmooth = 50,
        AIEnabled = false,
        AIStrength = 50,
        AIAdaptive = false,
        HistorySize = 10,
        AccelerationFactor = 20,
        DirectionWeight = 70
    },
    Smoothing = {
        Type = "Ease",
        EaseType = "OutQuad"
    },
    StickyAim = {
        Enabled = false,
        Multiplier = 150,
        BreakDistance = 300
    },
    AutoSwitch = {
        Enabled = false,
        Delay = 30
    },
    AimMethod = "Camera",
    MouseSensitivity = 100,
    OffsetCorrection = Vector3.new(0, 0, 0),
    SilentAim = {
        Enabled = false,
        HitChance = 100
    },
    UpdateRate = 1,
    Debug = false,
    VisibilityDot = {
        Enabled = false,
        Color = Color3.fromRGB(255, 0, 0),
        Size = 5,
        Filled = false,
        Transparency = 0,
        OutlineEnabled = false,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        OutlineThickness = 1
    },
    Hitbox = {
        Enabled = false,
        Mode = "Head",
        HeadSize = 200,
        BodySize = 150,
        Color = Color3.fromRGB(255, 0, 255),
        Transparency = 70,
        VisibleOnly = false
    }
}

local State = {
    LockedPlayer = nil,
    LastSwitchTime = 0,
    LastTargetPos = nil,
    VelocityCache = {},
    FrameCount = 0,
    RainbowHue = 0,
    IsInGame = false,
    LastAimTime = 0,
    SmoothedVelocity = {},
    CurrentTarget = nil,
    AimActive = false,
    MovementHistory = {},
    AccelerationCache = {},
    VisibilityDots = {},
    HitboxParts = {}
}

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.NumSides = 100
fovCircle.Radius = Config.FOV.Size
fovCircle.Filled = false
fovCircle.Visible = false
fovCircle.ZIndex = 999
fovCircle.Color = Config.FOV.Color

local EaseFuncs = {
    Linear = function(t) return t end,
    OutQuad = function(t) return 1 - (1 - t) ^ 2 end,
    OutCubic = function(t) return 1 - (1 - t) ^ 3 end,
    OutQuart = function(t) return 1 - (1 - t) ^ 4 end,
    OutQuint = function(t) return 1 - (1 - t) ^ 5 end,
    OutExpo = function(t) return t == 1 and 1 or 1 - 2 ^ (-10 * t) end,
    InOutSine = function(t) return -(math.cos(math.pi * t) - 1) / 2 end,
    OutBack = function(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
    end,
    OutElastic = function(t)
        if t == 0 or t == 1 then return t end
        return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
    end
}

local function GetCharacter(player)
    return player and player.Character
end

local function GetCharacterPart(player, partName)
    local char = GetCharacter(player)
    return char and char:FindFirstChild(partName)
end

local function GetHumanoid(player)
    local char = GetCharacter(player)
    return char and (char:FindFirstChild("Humanoid") or char:FindFirstChildOfClass("Humanoid"))
end

local function IsAlive(player)
    local hum = GetHumanoid(player)
    return hum and hum.Health > 0
end

local function GetLocalCharacter()
    return LocalPlayer and LocalPlayer.Character
end

local function GetLocalHRP()
    return GetCharacterPart(LocalPlayer, "HumanoidRootPart")
end

local function CheckInGame()
    local char = GetLocalCharacter()
    if not char then return false end
    
    local hum = GetHumanoid(LocalPlayer)
    if not hum or hum.Health <= 0 then return false end
    
    local hrp = GetLocalHRP()
    if not hrp then return false end
    
    if Camera.CameraSubject then
        if Camera.CameraSubject:IsA("Humanoid") then
            local subjectPlayer = Players:GetPlayerFromCharacter(Camera.CameraSubject.Parent)
            if subjectPlayer and subjectPlayer ~= LocalPlayer then
                return false
            end
        end
    end
    
    return true
end

local function GetPlayerMovementState(player)
    local hrp = GetCharacterPart(player, "HumanoidRootPart")
    if not hrp then return "Unknown" end
    
    local velocity = hrp.AssemblyLinearVelocity
    local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    
    if horizontalSpeed <= Config.MovementMode.StandingThreshold then
        return "Standing"
    elseif horizontalSpeed >= Config.MovementMode.RunningThreshold then
        return "Running"
    else
        return "Walking"
    end
end

local function MatchesMovementMode(player)
    local mode = Config.MovementMode.Mode
    if mode == "Both" then return true end
    
    local state = GetPlayerMovementState(player)
    
    if mode == "Standing" then
        return state == "Standing"
    elseif mode == "Running" then
        return state == "Running" or state == "Walking"
    end
    
    return true
end

local function IsValidTarget(player)
    if not player or player == LocalPlayer then return false end
    
    local char = GetCharacter(player)
    if not char then return false end
    
    local hrp = GetCharacterPart(player, "HumanoidRootPart")
    if not hrp then return false end
    
    if Config.AliveCheck then
        local hum = GetHumanoid(player)
        if not hum or hum.Health <= 0 then return false end
    end
    
    if Config.TeamCheck then
        if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            return false
        end
    end
    
    if not char:IsDescendantOf(Workspace) then return false end
    
    if not MatchesMovementMode(player) then return false end
    
    return true
end

local function IsVisible(targetPart)
    if not Config.WallCheck then return true end
    if not targetPart then return false end
    
    local origin = Camera.CFrame.Position
    local targetPos = targetPart.Position
    local direction = (targetPos - origin)
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {GetLocalCharacter(), targetPart.Parent}
    rayParams.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, rayParams)
    return result == nil
end

local function IsHeadVisible(player)
    local head = GetCharacterPart(player, "Head")
    if not head then return false end
    
    local origin = Camera.CFrame.Position
    local targetPos = head.Position
    local direction = (targetPos - origin)
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {GetLocalCharacter(), GetCharacter(player)}
    rayParams.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, rayParams)
    return result == nil
end

local function GetScreenPosition(position)
    local screenPos, onScreen = Camera:WorldToScreenPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetScreenCenter()
    local offsetX = Config.FOV.OffsetX
    local offsetY = Config.FOV.OffsetY
    return Vector2.new(Camera.ViewportSize.X / 2 + offsetX, Camera.ViewportSize.Y / 2 + offsetY)
end

local function GetScreenDistance(position)
    local screenPos, onScreen = GetScreenPosition(position)
    if not onScreen then return math.huge end
    return (GetScreenCenter() - screenPos).Magnitude
end

local function GetWorldDistance(position)
    local localHRP = GetLocalHRP()
    if not localHRP then return math.huge end
    return (localHRP.Position - position).Magnitude
end

local function ResetFOVToDefault()
    Config.FOV.Size = Config.FOV.DefaultSize
    Config.FOV.OffsetX = Config.FOV.DefaultOffsetX
    Config.FOV.OffsetY = Config.FOV.DefaultOffsetY
end

local function UpdateMovementHistory(player, currentPos, currentTime)
    if not State.MovementHistory[player] then
        State.MovementHistory[player] = {}
    end
    
    local history = State.MovementHistory[player]
    table.insert(history, {Position = currentPos, Time = currentTime})
    
    local maxHistory = Config.Prediction.HistorySize
    while #history > maxHistory do
        table.remove(history, 1)
    end
end

local function CalculateAcceleration(player, currentVelocity)
    local cache = State.AccelerationCache[player]
    local now = tick()
    
    if not cache then
        State.AccelerationCache[player] = {
            Velocity = currentVelocity,
            Time = now,
            Acceleration = Vector3.zero
        }
        return Vector3.zero
    end
    
    local deltaTime = now - cache.Time
    if deltaTime < 0.016 then
        return cache.Acceleration
    end
    
    local acceleration = (currentVelocity - cache.Velocity) / deltaTime
    
    State.AccelerationCache[player] = {
        Velocity = currentVelocity,
        Time = now,
        Acceleration = acceleration
    }
    
    return acceleration
end

local function CalculateVelocity(player, currentPos)
    local cache = State.VelocityCache[player]
    local now = tick()
    
    UpdateMovementHistory(player, currentPos, now)
    
    if not cache then
        State.VelocityCache[player] = {
            Position = currentPos,
            Time = now,
            Velocity = Vector3.zero,
            SmoothedVelocity = Vector3.zero
        }
        return Vector3.zero
    end
    
    local deltaTime = now - cache.Time
    if deltaTime < 0.016 then
        return cache.SmoothedVelocity
    end
    
    local rawVelocity = (currentPos - cache.Position) / deltaTime
    
    local smoothFactor = Config.Prediction.VelocitySmooth / 100
    local smoothedVelocity = cache.SmoothedVelocity:Lerp(rawVelocity, 1 - smoothFactor)
    
    local maxSpeed = 200
    if smoothedVelocity.Magnitude > maxSpeed then
        smoothedVelocity = smoothedVelocity.Unit * maxSpeed
    end
    
    State.VelocityCache[player] = {
        Position = currentPos,
        Time = now,
        Velocity = rawVelocity,
        SmoothedVelocity = smoothedVelocity
    }
    
    return smoothedVelocity
end

local function PredictDirectionChange(player)
    local history = State.MovementHistory[player]
    if not history or #history < 3 then
        return Vector3.zero
    end
    
    local directions = {}
    for i = 2, #history do
        local dir = (history[i].Position - history[i-1].Position).Unit
        if dir.Magnitude > 0 then
            table.insert(directions, dir)
        end
    end
    
    if #directions < 2 then
        return Vector3.zero
    end
    
    local avgChange = Vector3.zero
    for i = 2, #directions do
        avgChange = avgChange + (directions[i] - directions[i-1])
    end
    avgChange = avgChange / (#directions - 1)
    
    return avgChange * (Config.Prediction.DirectionWeight / 100)
end

local function AIPredictPosition(player, currentPos, velocity)
    if not Config.Prediction.AIEnabled then
        return currentPos + velocity * (Config.Prediction.Factor / 100)
    end
    
    local acceleration = CalculateAcceleration(player, velocity)
    local directionChange = PredictDirectionChange(player)
    
    local aiStrength = Config.Prediction.AIStrength / 100
    local factor = Config.Prediction.Factor / 100
    local accelFactor = Config.Prediction.AccelerationFactor / 100
    
    local basePredict = velocity * factor
    local accelPredict = acceleration * factor * factor * accelFactor * 0.5
    local dirPredict = directionChange * velocity.Magnitude * factor
    
    local finalPredict = basePredict + (accelPredict + dirPredict) * aiStrength
    
    if Config.Prediction.AIAdaptive then
        local speed = velocity.Magnitude
        local adaptiveFactor = math.clamp(speed / 50, 0.5, 2)
        finalPredict = finalPredict * adaptiveFactor
    end
    
    return currentPos + finalPredict
end

local function PredictPosition(player, targetPart)
    if not Config.Prediction.Enabled then return targetPart.Position end
    if not targetPart then return targetPart.Position end
    
    local currentPos = targetPart.Position
    local velocity = CalculateVelocity(player, currentPos)
    
    local predictedPos
    
    if Config.Prediction.AIEnabled then
        predictedPos = AIPredictPosition(player, currentPos, velocity)
    else
        local factor = Config.Prediction.Factor / 100
        
        if Config.Prediction.Mode == "Quadratic" then
            local localHRP = GetLocalHRP()
            if localHRP then
                local dist = (currentPos - localHRP.Position).Magnitude
                factor = factor * math.clamp(dist / 100, 0.5, 2)
            end
        elseif Config.Prediction.Mode == "Adaptive" then
            local speed = velocity.Magnitude
            factor = factor * math.clamp(speed / 50, 0.5, 2)
        end
        
        predictedPos = currentPos + velocity * factor
    end
    
    predictedPos = predictedPos + Config.OffsetCorrection
    
    return predictedPos
end

local function GetBestTargetPart(player)
    for _, partName in ipairs(Config.TargetPriority) do
        local part = GetCharacterPart(player, partName)
        if part then
            if partName == Config.Target then
                return part
            end
        end
    end
    
    return GetCharacterPart(player, Config.Target)
end

local function ScoreTarget(player, targetPart)
    if not targetPart then return math.huge end
    
    local screenDist = GetScreenDistance(targetPart.Position)
    local worldDist = GetWorldDistance(targetPart.Position)
    
    local score = screenDist
    
    if Config.StickyAim.Enabled and player == State.LockedPlayer then
        score = score / (Config.StickyAim.Multiplier / 100)
    end
    
    score = score + (worldDist / Config.Range) * 10
    
    if IsVisible(targetPart) then
        score = score * 0.8
    end
    
    return score
end

local function GetClosestTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local localHRP = GetLocalHRP()
    
    if not localHRP then return nil end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if IsValidTarget(player) then
            local targetPart = GetBestTargetPart(player)
            if targetPart then
                local worldDist = GetWorldDistance(targetPart.Position)
                local screenDist = GetScreenDistance(targetPart.Position)
                
                if worldDist <= Config.Range and screenDist <= Config.FOV.Size then
                    if IsVisible(targetPart) then
                        local score = ScoreTarget(player, targetPart)
                        if score < bestScore then
                            bestTarget = player
                            bestScore = score
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

local function ApplySmoothing(currentCF, targetCF, delta)
    local speed = (Config.Speed / 100) * delta * 60
    local easedSpeed = EaseFuncs[Config.Smoothing.EaseType](math.clamp(speed, 0, 1))
    return currentCF:Lerp(targetCF, easedSpeed)
end

local function AimAtPosition(targetPos, delta)
    if not targetPos then return end
    
    local currentCF = Camera.CFrame
    local targetCF = CFrame.new(currentCF.Position, targetPos)
    
    if Config.AimMethod == "Camera" then
        Camera.CFrame = ApplySmoothing(currentCF, targetCF, delta)
        
    elseif Config.AimMethod == "Mouse" then
        local screenTarget = GetScreenPosition(targetPos)
        local screenCenter = GetScreenCenter()
        local diff = screenTarget - screenCenter
        
        local sensitivity = (Config.MouseSensitivity / 100) * (Config.Speed / 100)
        local moveX = diff.X * sensitivity * delta
        local moveY = diff.Y * sensitivity * delta
        
        mousemoverel(moveX, moveY)
        
    elseif Config.AimMethod == "Hybrid" then
        Camera.CFrame = ApplySmoothing(currentCF, targetCF, delta * 0.7)
        
        local screenTarget = GetScreenPosition(targetPos)
        local screenCenter = GetScreenCenter()
        local diff = screenTarget - screenCenter
        
        if diff.Magnitude > 5 then
            local sensitivity = (Config.MouseSensitivity / 100) * (Config.Speed / 100) * 0.3
            local moveX = diff.X * sensitivity * delta
            local moveY = diff.Y * sensitivity * delta
            
            if mousemoverel then
                mousemoverel(moveX, moveY)
            end
        end
    end
end

local function UpdateRainbowColor(delta)
    if not Config.FOV.Rainbow.Enabled then return end
    
    State.RainbowHue = (State.RainbowHue + delta * Config.FOV.Rainbow.Speed) % 1
    Config.FOV.Color = Color3.fromHSV(State.RainbowHue, 1, 1)
end

local function UpdateFOVCircle()
    local center = GetScreenCenter()
    fovCircle.Position = center
    fovCircle.Visible = Config.Enabled and not Config.FOV.Hidden
    fovCircle.Radius = Config.FOV.Size
    fovCircle.Color = Config.FOV.Color
end

local function CreateVisibilityDot(player)
    local dot = Drawing.new("Circle")
    dot.Thickness = 1
    dot.NumSides = 30
    dot.Radius = Config.VisibilityDot.Size
    dot.Filled = Config.VisibilityDot.Filled
    dot.Visible = false
    dot.ZIndex = 1000
    dot.Color = Config.VisibilityDot.Color
    dot.Transparency = 1 - (Config.VisibilityDot.Transparency / 100)
    
    local outline = nil
    if Config.VisibilityDot.OutlineEnabled then
        outline = Drawing.new("Circle")
        outline.Thickness = Config.VisibilityDot.OutlineThickness
        outline.NumSides = 30
        outline.Radius = Config.VisibilityDot.Size + 1
        outline.Filled = false
        outline.Visible = false
        outline.ZIndex = 999
        outline.Color = Config.VisibilityDot.OutlineColor
    end
    
    State.VisibilityDots[player] = {Dot = dot, Outline = outline}
    return State.VisibilityDots[player]
end

local function UpdateVisibilityDots()
    if not Config.VisibilityDot.Enabled then
        for player, dots in pairs(State.VisibilityDots) do
            if dots.Dot then dots.Dot.Visible = false end
            if dots.Outline then dots.Outline.Visible = false end
        end
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local dots = State.VisibilityDots[player]
            if not dots then
                dots = CreateVisibilityDot(player)
            end
            
            local head = GetCharacterPart(player, "Head")
            local isVisible = head and IsHeadVisible(player)
            
            if isVisible and head then
                local screenPos, onScreen = GetScreenPosition(head.Position + Vector3.new(0, 1.5, 0))
                
                if onScreen then
                    dots.Dot.Position = screenPos
                    dots.Dot.Visible = true
                    dots.Dot.Radius = Config.VisibilityDot.Size
                    dots.Dot.Color = Config.VisibilityDot.Color
                    dots.Dot.Filled = Config.VisibilityDot.Filled
                    dots.Dot.Transparency = 1 - (Config.VisibilityDot.Transparency / 100)
                    
                    if dots.Outline and Config.VisibilityDot.OutlineEnabled then
                        dots.Outline.Position = screenPos
                        dots.Outline.Visible = true
                        dots.Outline.Radius = Config.VisibilityDot.Size + 1
                        dots.Outline.Color = Config.VisibilityDot.OutlineColor
                        dots.Outline.Thickness = Config.VisibilityDot.OutlineThickness
                    elseif dots.Outline then
                        dots.Outline.Visible = false
                    end
                else
                    dots.Dot.Visible = false
                    if dots.Outline then dots.Outline.Visible = false end
                end
            else
                dots.Dot.Visible = false
                if dots.Outline then dots.Outline.Visible = false end
            end
        end
    end
end

local function GetHitboxPart(player)
    if Config.Hitbox.Mode == "Head" then
        return GetCharacterPart(player, "Head")
    elseif Config.Hitbox.Mode == "Body" then
        return GetCharacterPart(player, "HumanoidRootPart") or GetCharacterPart(player, "UpperTorso") or GetCharacterPart(player, "Torso")
    elseif Config.Hitbox.Mode == "Both" then
        return GetCharacterPart(player, "HumanoidRootPart") or GetCharacterPart(player, "Head")
    end
    return GetCharacterPart(player, "Head")
end

local function UpdateHitboxes()
    if not Config.Hitbox.Enabled then
        for player, parts in pairs(State.HitboxParts) do
            for _, part in pairs(parts) do
                if part and part.Parent then
                    part.Size = part:GetAttribute("OriginalSize") or part.Size
                    part.Transparency = part:GetAttribute("OriginalTransparency") or 0
                end
            end
        end
        State.HitboxParts = {}
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsValidTarget(player) then
            local shouldShow = true
            if Config.Hitbox.VisibleOnly then
                local targetPart = GetHitboxPart(player)
                shouldShow = targetPart and IsVisible(targetPart)
            end
            
            if shouldShow then
                local char = GetCharacter(player)
                if char then
                    if not State.HitboxParts[player] then
                        State.HitboxParts[player] = {}
                    end
                    
                    local partsToModify = {}
                    
                    if Config.Hitbox.Mode == "Head" or Config.Hitbox.Mode == "Both" then
                        local head = GetCharacterPart(player, "Head")
                        if head then table.insert(partsToModify, {Part = head, SizeMultiplier = Config.Hitbox.HeadSize / 100}) end
                    end
                    
                    if Config.Hitbox.Mode == "Body" or Config.Hitbox.Mode == "Both" then
                        local bodyParts = {"HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso"}
                        for _, partName in ipairs(bodyParts) do
                            local part = GetCharacterPart(player, partName)
                            if part then 
                                table.insert(partsToModify, {Part = part, SizeMultiplier = Config.Hitbox.BodySize / 100})
                            end
                        end
                    end
                    
                    for _, data in ipairs(partsToModify) do
                        local part = data.Part
                        local multiplier = data.SizeMultiplier
                        
                        if not part:GetAttribute("OriginalSize") then
                            part:SetAttribute("OriginalSize", part.Size)
                            part:SetAttribute("OriginalTransparency", part.Transparency)
                        end
                        
                        local originalSize = part:GetAttribute("OriginalSize")
                        part.Size = originalSize * multiplier
                        part.Transparency = Config.Hitbox.Transparency / 100
                        part.Color = Config.Hitbox.Color
                        
                        State.HitboxParts[player][part.Name] = part
                    end
                end
            else
                if State.HitboxParts[player] then
                    for _, part in pairs(State.HitboxParts[player]) do
                        if part and part.Parent then
                            part.Size = part:GetAttribute("OriginalSize") or part.Size
                            part.Transparency = part:GetAttribute("OriginalTransparency") or 0
                        end
                    end
                    State.HitboxParts[player] = nil
                end
            end
        else
            if State.HitboxParts[player] then
                for _, part in pairs(State.HitboxParts[player]) do
                    if part and part.Parent then
                        part.Size = part:GetAttribute("OriginalSize") or part.Size
                        part.Transparency = part:GetAttribute("OriginalTransparency") or 0
                    end
                end
                State.HitboxParts[player] = nil
            end
        end
    end
end

local function ProcessAimbot(delta)
    State.FrameCount = State.FrameCount + 1
    if State.FrameCount % Config.UpdateRate ~= 0 then return end
    
    State.IsInGame = CheckInGame()
    if not State.IsInGame then
        return
    end
    
    local target = nil
    
    if Config.LockEnabled then
        if State.LockedPlayer then
            if IsValidTarget(State.LockedPlayer) then
                local part = GetBestTargetPart(State.LockedPlayer)
                if part then
                    local screenDist = GetScreenDistance(part.Position)
                    local breakDist = Config.StickyAim.Enabled 
                        and Config.StickyAim.BreakDistance 
                        or Config.FOV.Size * 2
                    
                    if screenDist <= breakDist and IsVisible(part) then
                        target = State.LockedPlayer
                    else
                        State.LockedPlayer = nil
                    end
                else
                    State.LockedPlayer = nil
                end
            else
                if Config.LockBreakOnDeath and not IsAlive(State.LockedPlayer) then
                    State.LockedPlayer = nil
                end
            end
        end
        
        if not State.LockedPlayer then
            State.LockedPlayer = GetClosestTarget()
            target = State.LockedPlayer
        end
    else
        local newTarget = GetClosestTarget()
        
        if Config.AutoSwitch.Enabled then
            if newTarget ~= State.CurrentTarget then
                local now = tick()
                if now - State.LastSwitchTime >= (Config.AutoSwitch.Delay / 100) then
                    State.CurrentTarget = newTarget
                    State.LastSwitchTime = now
                end
            end
            target = State.CurrentTarget
        else
            target = newTarget
            State.CurrentTarget = newTarget
        end
    end
    
    if target then
        local targetPart = GetBestTargetPart(target)
        if targetPart then
            local predictedPos = PredictPosition(target, targetPart)
            AimAtPosition(predictedPos, delta)
            State.AimActive = true
        else
            State.AimActive = false
        end
    else
        State.AimActive = false
    end
end

RunService:BindToRenderStep("AdvancedAimbotV2", Enum.RenderPriority.Camera.Value + 1, function(delta)
    UpdateRainbowColor(delta)
    UpdateFOVCircle()
    UpdateVisibilityDots()
    UpdateHitboxes()
    
    if Config.Enabled then
        ProcessAimbot(delta)
    end
end)

local oldNamecall
if Config.SilentAim.Enabled then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod():lower()
        local args = {...}
        
        local isRaycast = method == "raycast"
        local isFindPart = method == "findpartonraywithignorelist" or method == "findpartonray"
        
        if isRaycast or isFindPart then
            local target = State.LockedPlayer or State.CurrentTarget
            
            if target and target.Parent then
                local char = GetCharacter(target)
                
                if char and char.Parent then
                    local targetPart = GetBestTargetPart(target)
                    
                    if targetPart and targetPart.Parent then
                        if math.random(1, 100) <= Config.SilentAim.HitChance then
                            
                            if isRaycast then
                                local origin = args[1]
                                if typeof(origin) == "Vector3" and typeof(args[2]) == "Vector3" then
                                    local newDirection = (targetPart.Position - origin).Unit * args[2].Magnitude
                                    args[2] = newDirection
                                end
                                
                            elseif isFindPart then
                                if typeof(args[1]) == "Ray" then
                                    local origin = args[1].Origin
                                    local newDirection = (targetPart.Position - origin).Unit * args[1].Direction.Magnitude
                                    args[1] = Ray.new(origin, newDirection)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        return oldNamecall(self, unpack(args))
    end)
end

local function CleanupPlayer(player)
    State.VelocityCache[player] = nil
    State.MovementHistory[player] = nil
    State.AccelerationCache[player] = nil
    
    if State.VisibilityDots[player] then
        if State.VisibilityDots[player].Dot then
            State.VisibilityDots[player].Dot:Remove()
        end
        if State.VisibilityDots[player].Outline then
            State.VisibilityDots[player].Outline:Remove()
        end
        State.VisibilityDots[player] = nil
    end
    
    if State.HitboxParts[player] then
        for _, part in pairs(State.HitboxParts[player]) do
            if part and part.Parent then
                part.Size = part:GetAttribute("OriginalSize") or part.Size
                part.Transparency = part:GetAttribute("OriginalTransparency") or 0
            end
        end
        State.HitboxParts[player] = nil
    end
    
    if State.LockedPlayer == player then 
        State.LockedPlayer = nil 
    end
    if State.CurrentTarget == player then
        State.CurrentTarget = nil
    end
end

task.spawn(function()
    while true do
        task.wait(5)
        for player, _ in pairs(State.VelocityCache) do
            if not player.Parent then
                State.VelocityCache[player] = nil
                State.MovementHistory[player] = nil
                State.AccelerationCache[player] = nil
            end
        end
    end
end)

Players.PlayerRemoving:Connect(CleanupPlayer)

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    fovCircle.Position = GetScreenCenter()
end)

Camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
    State.IsInGame = CheckInGame()
end)

return Config
