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
        Rainbow = {Enabled = false, Speed = 1}
    },
    Target = "Head",
    TargetPriority = {"Head", "HumanoidRootPart", "UpperTorso"},
    Range = 10000,
    Speed = 0.5,
    TeamCheck = false,
    WallCheck = false,
    AliveCheck = true,
    LockEnabled = false,
    LockBreakOnDeath = false,
    Prediction = {
        Enabled = false,
        Factor = 0.12,
        Mode = "Linear",
        VelocitySmooth = 0.5
    },
    Smoothing = {
        Type = "Ease",
        EaseType = "OutQuad"
    },
    StickyAim = {
        Enabled = false,
        Multiplier = 1.5,
        BreakDistance = 300
    },
    AutoSwitch = {
        Enabled = false,
        Delay = 0.3
    },
    AimMethod = "Camera",
    MouseSensitivity = 1,
    OffsetCorrection = Vector3.new(0, 0, 0),
    SilentAim = {
        Enabled = false,
        HitChance = 100
    },
    UpdateRate = 1,
    Debug = false
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
    AimActive = false
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

local function GetScreenPosition(position)
    local screenPos, onScreen = Camera:WorldToScreenPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetScreenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
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

local function CalculateVelocity(player, currentPos)
    local cache = State.VelocityCache[player]
    local now = tick()
    
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
    
    local smoothFactor = Config.Prediction.VelocitySmooth
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

local function PredictPosition(player, targetPart)
    if not Config.Prediction.Enabled then return targetPart.Position end
    if not targetPart then return targetPart.Position end
    
    local currentPos = targetPart.Position
    local velocity = CalculateVelocity(player, currentPos)
    
    local factor = Config.Prediction.Factor
    
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
    
    local predictedPos = currentPos + velocity * factor
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
        score = score / Config.StickyAim.Multiplier
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
    local speed = Config.Speed * delta * 60
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
        
        local sensitivity = Config.MouseSensitivity * Config.Speed
        local moveX = diff.X * sensitivity * delta
        local moveY = diff.Y * sensitivity * delta
        
        mousemoverel(moveX, moveY)
        
    elseif Config.AimMethod == "Hybrid" then
        Camera.CFrame = ApplySmoothing(currentCF, targetCF, delta * 0.7)
        
        local screenTarget = GetScreenPosition(targetPos)
        local screenCenter = GetScreenCenter()
        local diff = screenTarget - screenCenter
        
        if diff.Magnitude > 5 then
            local sensitivity = Config.MouseSensitivity * Config.Speed * 0.3
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
                if now - State.LastSwitchTime >= Config.AutoSwitch.Delay then
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
    
    if Config.Enabled then
        ProcessAimbot(delta)
    end
end)

local oldNamecall
if Config.SilentAim.Enabled then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if method == "FindPartOnRayWithIgnoreList" or method == "Raycast" then
            if State.LockedPlayer and Config.SilentAim.Enabled then
                local targetPart = GetBestTargetPart(State.LockedPlayer)
                if targetPart then
                    if math.random(1, 100) <= Config.SilentAim.HitChance then
                        if method == "FindPartOnRayWithIgnoreList" then
                            local origin = args[1].Origin
                            local newDirection = (targetPart.Position - origin).Unit * args[1].Direction.Magnitude
                            args[1] = Ray.new(origin, newDirection)
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
