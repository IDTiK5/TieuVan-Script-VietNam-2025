--[[================================================================================
                            PHẦN 1: SERVICES & CONFIG
================================================================================
--]]

-- ===== CACHE GLOBALS (Performance) =====
local Game = game
local Math = math
local Table = table
local Pairs = pairs
local Type = type
local Tick = tick
local Pcall = pcall
local Print = print
local Tonumber = tonumber
local Tostring = tostring

-- ===== MATH CACHE =====
local MathFloor = Math.floor
local MathMin = Math.min
local MathMax = Math.max

-- ===== CONSTRUCTORS CACHE =====
local Color3New = Color3.new
local Color3FromRGB = Color3.fromRGB
local Color3FromHSV = Color3.fromHSV
local Vector2New = Vector2.new
local Vector3New = Vector3.new

-- ===== SERVICES =====
local Players = Game:GetService("Players")
local RunService = Game:GetService("RunService")
local Workspace = Game:GetService("Workspace")

-- ===== LOCAL PLAYER (với fallback wait) =====
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- ===== DRAWING HealthAPI =====
local DrawingNew = Drawing.new

-- ===== CONFIGURATION CENTRALIZED =====
-- Tất cả cấu hình được quản lý tập trung tại đây
local Configuration = {
    -- [Cài đặt chung]
    enabled = true,                                 -- Bật/tắt ESP
    maxDistance = 5000,                             -- Khoảng cách tối đa hiển thị
    debugMode = false,                              -- Chế độ debug (in log)
    
    -- [Team Filter]
    teamFilter = false,                             -- Bật lọc team (ẩn teammate)
    teamFilterMode = "standard",                    -- "standard" hoặc "attribute"
    
    -- [Bar Style - Horizontal]
    barStyle = "horizontal",                        -- "horizontal" hoặc "vertical"
    barWidth = 60,                                  -- Chiều rộng bar horizontal
    barHeight = 4,                                  -- Chiều cao bar horizontal
    barOffsetY = -5,                                -- Offset Y từ đầu player
    
    -- [Bar Style - Vertical]
    verticalWidth = 4,                              -- Chiều rộng bar vertical
    verticalHeight = 40,                            -- Chiều cao bar vertical
    verticalOffsetX = -35,                          -- Offset X từ player
    
    -- [Outline]
    outlineSize = 1,                                -- Độ dày outline
    outlineColor = Color3FromRGB(0, 0, 0),          -- Màu outline
    
    -- [Bar Colors]
    barColorMode = "gradient",                      -- "static", "gradient", "rainbow"
    barColorHigh = Color3FromRGB(0, 255, 0),        -- Màu máu cao (xanh lá)
    barColorMid = Color3FromRGB(255, 255, 0),       -- Màu máu trung bình (vàng)
    barColorLow = Color3FromRGB(255, 0, 0),         -- Màu máu thấp (đỏ)
    barColorStatic = Color3FromRGB(0, 255, 0),      -- Màu static
    backgroundColor = Color3FromRGB(40, 40, 40),    -- Màu nền bar
    
    -- [Animation]
    lerpSpeed = 0.15,                               -- Tốc độ lerp health bar
    fadeInOut = false,                              -- Bật fade in/out effect
    fadeSpeed = 0.1,                                -- Tốc độ fade
    
    -- [Health Text]
    showHealthText = false,                         -- Hiển thị text máu
    textMode = "percent",                           -- "percent", "value", "both"
    textPosition = "top",                           -- "top", "bottom", "left", "right", "center"
    textSize = 13,                                  -- Kích thước font
    textColor = Color3FromRGB(255, 255, 255),       -- Màu chữ
    textOutline = true,                             -- Bật outline text
    textOutlineColor = Color3FromRGB(0, 0, 0),      -- Màu outline text
    textOffsetX = 0,                                -- Offset X của text
    textOffsetY = -15,                              -- Offset Y của text
    
    -- [Whitelist/Blacklist]
    useWhitelist = false,                           -- Bật whitelist mode
    whitelist = {},                                 -- Danh sách whitelist {["PlayerName"] = true}
    useBlacklist = false,                           -- Bật blacklist mode
    blacklist = {},                                 -- Danh sách blacklist {["PlayerName"] = true}
    
    -- [Error Recovery]
    enableErrorRecovery = true,                     -- Bật hệ thống phục hồi lỗi
    maxErrorsBeforeDisable = 10,                    -- Số lỗi tối đa trước khi tự disable
    errorWindowDuration = 5                         -- Thời gian reset error count (giây)
}

-- ===== STATE OBJECT =====
-- Quản lý trạng thái runtime của hệ thống
local State = {
    espData = {},                                   -- Cache ESP data cho mỗi player
    renderConnection = nil,                         -- Connection RenderStepped
    playerAddedConnection = nil,                    -- Connection PlayerAdded
    playerRemovingConnection = nil,                 -- Connection PlayerRemoving
    rainbowHue = 0,                                 -- Hue hiện tại cho rainbow mode
    errorCount = 0,                                 -- Đếm số lỗi
    lastErrorTime = 0,                              -- Thời điểm lỗi cuối
    isInitialized = false                           -- Đã khởi tạo chưa
}

--[[
================================================================================
                            PHẦN 2: UTILITY FUNCTIONS
================================================================================
--]]

-- ===== SAFE CALL =====
-- Wrapper an toàn cho function calls, tránh crash
-- @param func: Function cần gọi
-- @param ...: Arguments truyền vào function
-- @return: Kết quả của function hoặc nil nếu lỗi
local function SafeCall(func, ...)
    local success, result = Pcall(func, ...)
    if success then
        return result
    end
    return nil
end

-- ===== DEBUG LOG =====
-- In log khi ở chế độ debug
-- @param message: Nội dung log
local function DebugLog(message)
    if Configuration.debugMode then
        Print("[HealthBar ESP]", Tostring(message))
    end
end

-- ===== LINEAR INTERPOLATE (LERP) =====
-- Nội suy tuyến tính giữa 2 giá trị
-- @param startValue: Giá trị bắt đầu
-- @param endValue: Giá trị kết thúc
-- @param alpha: Hệ số nội suy (0-1)
-- @return: Giá trị đã nội suy
local function LinearInterpolate(startValue, endValue, alpha)
    return startValue + (endValue - startValue) * alpha
end

-- ===== LINEAR INTERPOLATE COLOR =====
-- Nội suy tuyến tính giữa 2 màu
-- @param colorStart: Màu bắt đầu
-- @param colorEnd: Màu kết thúc
-- @param alpha: Hệ số nội suy (0-1)
-- @return: Màu đã nội suy
local function LinearInterpolateColor(colorStart, colorEnd, alpha)
    return Color3New(
        LinearInterpolate(colorStart.R, colorEnd.R, alpha),
        LinearInterpolate(colorStart.G, colorEnd.G, alpha),
        LinearInterpolate(colorStart.B, colorEnd.B, alpha)
    )
end

-- ===== HANDLE ERROR =====
-- Xử lý và theo dõi lỗi, tự động disable nếu quá nhiều lỗi
-- @param errorMessage: Nội dung lỗi
local function HandleError(errorMessage)
    -- Bỏ qua nếu không bật error recovery
    if not Configuration.enableErrorRecovery then
        return
    end
    
    local currentTime = Tick()
    
    -- Reset error count nếu đã qua thời gian window
    if currentTime - State.lastErrorTime > Configuration.errorWindowDuration then
        State.errorCount = 0
    end
    
    -- Tăng error count và cập nhật thời gian
    State.errorCount = State.errorCount + 1
    State.lastErrorTime = currentTime
    
    -- Log lỗi (luôn in kể cả không debug mode vì đây là lỗi thật)
    DebugLog("Error: " .. Tostring(errorMessage))
    
    -- Auto disable nếu quá nhiều lỗi
    if State.errorCount >= Configuration.maxErrorsBeforeDisable then
        Configuration.enabled = false
        DebugLog("Too many errors! ESP temporarily disabled.")
    end
end

--[[
================================================================================
                            PHẦN 3: VALIDATION FUNCTIONS
================================================================================
--]]

-- ===== GET CAMERA =====
-- Lấy camera hiện tại
-- @return: CurrentCamera hoặc nil
local function GetCamera()
    return Workspace.CurrentCamera
end

-- ===== IS SAME TEAM =====
-- Kiểm tra 2 player có cùng team không
-- Hỗ trợ cả standard team và custom attribute
-- @param playerOne: Player thứ nhất
-- @param playerTwo: Player thứ hai
-- @return: true nếu cùng team
local function IsSameTeam(playerOne, playerTwo)
    -- Null check
    if not playerOne or not playerTwo then
        return false
    end
    
    -- Mode: Attribute (check custom Team attribute trên character)
    if Configuration.teamFilterMode == "attribute" then
        local charOne = playerOne.Character
        local charTwo = playerTwo.Character
        
        if charOne and charTwo then
            local teamAttrOne = charOne:GetAttribute("Team")
            local teamAttrTwo = charTwo:GetAttribute("Team")
            
            -- Nếu cả 2 có attribute Team và giống nhau
            if teamAttrOne and teamAttrTwo and teamAttrOne == teamAttrTwo then
                return true
            end
        end
    end
    
    -- Mode: Standard (check Team property)
    if playerOne.Team and playerTwo.Team then
        return playerOne.Team == playerTwo.Team
    end
    
    return false
end

-- ===== IS PLAYER ALLOWED =====
-- Kiểm tra player có được phép hiển thị ESP không
-- Dựa trên whitelist/blacklist
-- @param player: Player cần kiểm tra
-- @return: true nếu được phép
local function IsPlayerAllowed(player)
    local playerName = player.Name
    
    -- Whitelist mode: chỉ hiển thị player trong whitelist
    if Configuration.useWhitelist then
        return Configuration.whitelist[playerName] == true
    end
    
    -- Blacklist mode: ẩn player trong blacklist
    if Configuration.useBlacklist then
        return Configuration.blacklist[playerName] ~= true
    end
    
    -- Mặc định: cho phép tất cả
    return true
end

-- ===== VALIDATE PLAYER =====
-- Kiểm tra và lấy dữ liệu player hợp lệ
-- Thực hiện tất cả validation cần thiết
-- @param player: Player cần validate
-- @param myPosition: Vị trí của LocalPlayer (để tính distance)
-- @return: Table chứa data hoặc nil nếu không hợp lệ
local function ValidatePlayer(player, myPosition)
    -- Check character tồn tại
    local character = player.Character
    if not character then
        return nil
    end
    
    -- Check humanoid tồn tại và còn sống
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil
    end
    
    -- Check root part tồn tại (cần cho position)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return nil
    end
    
    -- Check head tồn tại (cần cho screen position)
    local head = character:FindFirstChild("Head")
    if not head then
        return nil
    end
    
    -- Tính distance
    local distance = (rootPart.Position - myPosition).Magnitude
    
    -- Check distance limit
    if distance > Configuration.maxDistance then
        return nil
    end
    
    -- Check team filter
    if Configuration.teamFilter and IsSameTeam(LocalPlayer, player) then
        return nil
    end
    
    -- Check whitelist/blacklist
    if not IsPlayerAllowed(player) then
        return nil
    end
    
    -- Return validated data
    return {
        character = character,
        humanoid = humanoid,
        rootPart = rootPart,
        head = head,
        distance = distance
    }
end

--[[
================================================================================
                            PHẦN 4: COLOR SYSTEM
================================================================================
--]]

-- ===== GET HEALTH COLOR =====
-- Tính màu health bar dựa trên health percent và color mode
-- @param healthPercent: Phần trăm máu (0-1)
-- @return: Color3 của health bar
local function GetHealthColor(healthPercent)
    local colorMode = Configuration.barColorMode
    
    -- Mode: Static - màu cố định
    if colorMode == "static" then
        return Configuration.barColorStatic
    end
    
    -- Mode: Rainbow - màu cầu vồng xoay vòng
    if colorMode == "rainbow" then
        return Color3FromHSV(State.rainbowHue, 1, 1)
    end
    
    -- Mode: Gradient - màu gradient theo health
    -- 0% = Low (đỏ) -> 50% = Mid (vàng) -> 100% = High (xanh)
    if healthPercent > 0.5 then
        -- Nửa trên: Mid -> High
        local alpha = (healthPercent - 0.5) * 2
        return LinearInterpolateColor(Configuration.barColorMid, Configuration.barColorHigh, alpha)
    else
        -- Nửa dưới: Low -> Mid
        local alpha = healthPercent * 2
        return LinearInterpolateColor(Configuration.barColorLow, Configuration.barColorMid, alpha)
    end
end

--[[
================================================================================
                            PHẦN 5: DRAWING MANAGEMENT
================================================================================
--]]

-- ===== CREATE DRAWING ELEMENTS =====
-- Tạo bộ drawing objects mới cho một player
-- Bao gồm: outline, background, healthBar, healthText
-- @return: Table chứa tất cả drawing objects và cache fields
local function CreateDrawingElements()
    -- Tạo các drawing objects
    local drawingData = {
        -- Drawing objects
        outline = DrawingNew("Square"),
        background = DrawingNew("Square"),
        healthBar = DrawingNew("Square"),
        healthText = DrawingNew("Text"),
        
        -- Cache fields cho animation
        smoothedHealthPercent = 1,      -- Health percent đã lerp (smooth)
        currentOpacity = 0,             -- Opacity hiện tại
        targetOpacity = 0,              -- Opacity mục tiêu
        isVisible = false               -- Trạng thái hiển thị
    }
    
    -- ===== Setup Outline =====
    drawingData.outline.Filled = true
    drawingData.outline.Visible = false
    drawingData.outline.ZIndex = 1
    
    -- ===== Setup Background =====
    drawingData.background.Filled = true
    drawingData.background.Visible = false
    drawingData.background.ZIndex = 2
    
    -- ===== Setup Health Bar =====
    drawingData.healthBar.Filled = true
    drawingData.healthBar.Visible = false
    drawingData.healthBar.ZIndex = 3
    
    -- ===== Setup Health Text =====
    drawingData.healthText.Center = true
    drawingData.healthText.Visible = false
    drawingData.healthText.ZIndex = 4
    
    return drawingData
end

-- ===== HIDE ALL DRAWINGS =====
-- Ẩn tất cả drawing objects của một player
-- @param drawingData: Table chứa drawing objects
local function HideAllDrawings(drawingData)
    drawingData.outline.Visible = false
    drawingData.background.Visible = false
    drawingData.healthBar.Visible = false
    drawingData.healthText.Visible = false
    drawingData.isVisible = false
end

-- ===== REMOVE PLAYER ESP =====
-- Xóa hoàn toàn ESP của một player (destroy drawings)
-- @param player: Player cần xóa ESP
local function RemovePlayerESP(player)
    local drawingData = State.espData[player]
    
    if drawingData then
        -- Safely remove tất cả drawings
        SafeCall(function()
            drawingData.outline:Remove()
            drawingData.background:Remove()
            drawingData.healthBar:Remove()
            drawingData.healthText:Remove()
        end)
        
        -- Xóa khỏi cache
        State.espData[player] = nil
        
        DebugLog("Removed ESP for: " .. player.Name)
    end
end

-- ===== CREATE PLAYER ESP =====
-- Tạo ESP mới cho một player
-- Sẽ remove ESP cũ nếu đã tồn tại
-- @param player: Player cần tạo ESP
local function CreatePlayerESP(player)
    -- Bỏ qua LocalPlayer
    if player == LocalPlayer then
        return
    end
    
    -- Remove ESP cũ nếu có
    RemovePlayerESP(player)
    
    -- Tạo ESP mới
    State.espData[player] = CreateDrawingElements()
    
    DebugLog("Created ESP for: " .. player.Name)
end

--[[
================================================================================
                            PHẦN 6: RENDER FUNCTIONS
================================================================================
--]]

-- ===== FORMAT HEALTH TEXT =====
-- Format text hiển thị health dựa trên textMode
-- @param current: Máu hiện tại
-- @param max: Máu tối đa
-- @param percent: Phần trăm máu (0-1)
-- @return: String đã format
local function FormatHealthText(current, max, percent)
    -- Handle edge case
    if not max or max == 0 then
        return "???"
    end
    
    local textMode = Configuration.textMode
    local currentInt = MathFloor(current)
    local maxInt = MathFloor(max)
    local percentInt = MathFloor(percent * 100)
    
    -- Mode: Value - hiển thị "current/max"
    if textMode == "value" then
        return currentInt .. "/" .. maxInt
    end
    
    -- Mode: Both - hiển thị "current (percent%)"
    if textMode == "both" then
        return currentInt .. " (" .. percentInt .. "%)"
    end
    
    -- Mode: Percent - hiển thị "percent%"
    return percentInt .. "%"
end

-- ===== RENDER HORIZONTAL BAR =====
-- Vẽ health bar theo chiều ngang
-- @param drawingData: Table chứa drawing objects
-- @param screenPos: Vị trí trên screen (Vector2)
-- @param healthColor: Màu health bar
-- @return: posX, posY, width, height (để render text)
local function RenderHorizontalBar(drawingData, screenPos, healthColor)
    local width = Configuration.barWidth
    local height = Configuration.barHeight
    local outline = Configuration.outlineSize
    
    -- Tính position (căn giữa theo X)
    local posX = screenPos.X - width / 2
    local posY = screenPos.Y + Configuration.barOffsetY
    
    local opacity = drawingData.currentOpacity
    
    -- ===== Render Outline =====
    drawingData.outline.Position = Vector2New(posX - outline, posY - outline)
    drawingData.outline.Size = Vector2New(width + outline * 2, height + outline * 2)
    drawingData.outline.Color = Configuration.outlineColor
    drawingData.outline.Transparency = opacity
    drawingData.outline.Visible = true
    
    -- ===== Render Background =====
    drawingData.background.Position = Vector2New(posX, posY)
    drawingData.background.Size = Vector2New(width, height)
    drawingData.background.Color = Configuration.backgroundColor
    drawingData.background.Transparency = opacity
    drawingData.background.Visible = true
    
    -- ===== Render Health Bar =====
    -- Width dựa trên smoothed health percent
    local healthWidth = width * drawingData.smoothedHealthPercent
    
    drawingData.healthBar.Position = Vector2New(posX, posY)
    drawingData.healthBar.Size = Vector2New(healthWidth, height)
    drawingData.healthBar.Color = healthColor
    drawingData.healthBar.Transparency = opacity
    drawingData.healthBar.Visible = true
    
    return posX, posY, width, height
end

-- ===== RENDER VERTICAL BAR =====
-- Vẽ health bar theo chiều dọc
-- Health fill từ dưới lên
-- @param drawingData: Table chứa drawing objects
-- @param screenPos: Vị trí trên screen (Vector2)
-- @param healthColor: Màu health bar
-- @return: posX, posY, width, height (để render text)
local function RenderVerticalBar(drawingData, screenPos, healthColor)
    local width = Configuration.verticalWidth
    local height = Configuration.verticalHeight
    local outline = Configuration.outlineSize
    
    -- Tính position (căn giữa theo Y)
    local posX = screenPos.X + Configuration.verticalOffsetX
    local posY = screenPos.Y - height / 2
    
    local opacity = drawingData.currentOpacity
    
    -- ===== Render Outline =====
    drawingData.outline.Position = Vector2New(posX - outline, posY - outline)
    drawingData.outline.Size = Vector2New(width + outline * 2, height + outline * 2)
    drawingData.outline.Color = Configuration.outlineColor
    drawingData.outline.Transparency = opacity
    drawingData.outline.Visible = true
    
    -- ===== Render Background =====
    drawingData.background.Position = Vector2New(posX, posY)
    drawingData.background.Size = Vector2New(width, height)
    drawingData.background.Color = Configuration.backgroundColor
    drawingData.background.Transparency = opacity
    drawingData.background.Visible = true
    
    -- ===== Render Health Bar =====
    -- Height dựa trên smoothed health percent
    -- Fill từ dưới lên (position Y thay đổi)
    local healthHeight = height * drawingData.smoothedHealthPercent
    local healthPosY = posY + (height - healthHeight)
    
    drawingData.healthBar.Position = Vector2New(posX, healthPosY)
    drawingData.healthBar.Size = Vector2New(width, healthHeight)
    drawingData.healthBar.Color = healthColor
    drawingData.healthBar.Transparency = opacity
    drawingData.healthBar.Visible = true
    
    return posX, posY, width, height
end

-- ===== RENDER TEXT =====
-- Vẽ health text
-- @param drawingData: Table chứa drawing objects
-- @param posX: Position X của bar
-- @param posY: Position Y của bar
-- @param barWidth: Width của bar
-- @param barHeight: Height của bar
-- @param currentHealth: Máu hiện tại
-- @param maxHealth: Máu tối đa
-- @param healthPercent: Phần trăm máu (0-1)
local function RenderText(drawingData, posX, posY, barWidth, barHeight, currentHealth, maxHealth, healthPercent)
    -- Skip nếu không bật show health text
    if not Configuration.showHealthText then
        drawingData.healthText.Visible = false
        return
    end
    
    -- Tính base position (center của bar)
    local textX = posX + barWidth / 2 + Configuration.textOffsetX
    local textY = posY + Configuration.textOffsetY
    
    -- Điều chỉnh position theo textPosition
    local textPosition = Configuration.textPosition
    
    if textPosition == "bottom" then
        textY = posY + barHeight + 5
    elseif textPosition == "left" then
        textX = posX - 30
        textY = posY + barHeight / 2
    elseif textPosition == "right" then
        textX = posX + barWidth + 30
        textY = posY + barHeight / 2
    elseif textPosition == "center" then
        textY = posY + barHeight / 2
    end
    -- "top" là default, không cần điều chỉnh thêm
    
    -- ===== Render Text =====
    drawingData.healthText.Position = Vector2New(textX, textY)
    drawingData.healthText.Text = FormatHealthText(currentHealth, maxHealth, healthPercent)
    drawingData.healthText.Size = Configuration.textSize
    drawingData.healthText.Color = Configuration.textColor
    drawingData.healthText.Outline = Configuration.textOutline
    drawingData.healthText.OutlineColor = Configuration.textOutlineColor
    drawingData.healthText.Transparency = drawingData.currentOpacity
    drawingData.healthText.Visible = true
end

--[[
================================================================================
                            PHẦN 7: MAIN UPDATE LOGIC
================================================================================
--]]

-- ===== UPDATE ESP =====
-- Main render function, được gọi mỗi frame từ RenderStepped
-- Xử lý tất cả logic rendering cho ESP
local function UpdateESP()
    local success, errorMessage = Pcall(function()
        -- Check enabled TRƯỚC và return ngay
        if not Configuration.enabled then
            for _, data in Pairs(State.espData) do
                if data.isVisible then  -- Chỉ hide nếu đang visible
                    data.targetOpacity = 0
                    data.currentOpacity = 0
                    HideAllDrawings(data)
                end
            end
            return  -- QUAN TRỌNG: return ngay, không process tiếp
        end
        
        -- Check camera
        local camera = GetCamera()
        if not camera then
            return
        end
        
        -- ===== Update Rainbow Hue =====
        -- Chỉ update 1 lần/frame (shared cho tất cả players)
        if Configuration.barColorMode == "rainbow" then
            State.rainbowHue = (State.rainbowHue + 0.005) % 1
        end
        
        -- ===== Get LocalPlayer Position =====
        local myCharacter = LocalPlayer.Character
        if not myCharacter then
            return
        end
        
        local myRootPart = myCharacter:FindFirstChild("HumanoidRootPart")
        if not myRootPart then
            return
        end
        
        local myPosition = myRootPart.Position
        
        -- ===== Process Each Player =====
        for player, drawingData in Pairs(State.espData) do
            -- Validate player và lấy data
            local playerData = ValidatePlayer(player, myPosition)
            
            -- ===== Handle Invalid Player =====
            if not playerData then
                -- Set target opacity về 0
                drawingData.targetOpacity = 0
                
                -- Handle fade out hoặc instant hide
                if Configuration.fadeInOut then
                    -- Fade out smoothly
                    drawingData.currentOpacity = LinearInterpolate(
                        drawingData.currentOpacity, 
                        0, 
                        Configuration.fadeSpeed
                    )
                    
                    -- Hide hoàn toàn khi đã mờ
                    if drawingData.currentOpacity < 0.01 then
                        HideAllDrawings(drawingData)
                    end
                else
                    -- Instant hide
                    HideAllDrawings(drawingData)
                end
                
                continue
            end
            
            -- ===== Check On Screen =====
            -- Tính vị trí đỉnh đầu
            local headTopPosition = playerData.head.Position + Vector3New(0, playerData.head.Size.Y / 2 + 0.5, 0)
            local screenPos, isOnScreen = camera:WorldToViewportPoint(headTopPosition)
            
            -- Hide nếu không trên màn hình
            if not isOnScreen then
                HideAllDrawings(drawingData)
                continue
            end
            
            -- ===== Update Opacity =====
            drawingData.targetOpacity = 1
            
            if Configuration.fadeInOut then
                -- Fade in smoothly
                drawingData.currentOpacity = LinearInterpolate(
                    drawingData.currentOpacity, 
                    1, 
                    Configuration.fadeSpeed
                )
            else
                -- Instant show
                drawingData.currentOpacity = 1
            end
            
            -- ===== Calculate Health =====
            local humanoid = playerData.humanoid
            local currentHealth = humanoid.Health
            local maxHealth = humanoid.MaxHealth
            local healthPercent = currentHealth / maxHealth
            
            -- Clamp health percent (đề phòng edge cases)
            healthPercent = MathMax(0, MathMin(1, healthPercent))
            
            -- ===== Lerp Smoothed Health Percent =====
            drawingData.smoothedHealthPercent = LinearInterpolate(
                drawingData.smoothedHealthPercent,
                healthPercent,
                Configuration.lerpSpeed
            )
            
            -- ===== Get Health Color =====
            -- Sử dụng smoothed percent để màu cũng smooth
            local healthColor = GetHealthColor(drawingData.smoothedHealthPercent)
            
            -- ===== Convert to Screen Position =====
            local screenPosition2D = Vector2New(screenPos.X, screenPos.Y)
            
            -- ===== Render Bar =====
            local barPosX, barPosY, barWidth, barHeight
            
            if Configuration.barStyle == "vertical" then
                barPosX, barPosY, barWidth, barHeight = RenderVerticalBar(
                    drawingData, 
                    screenPosition2D, 
                    healthColor
                )
            else
                -- Default: horizontal
                barPosX, barPosY, barWidth, barHeight = RenderHorizontalBar(
                    drawingData, 
                    screenPosition2D, 
                    healthColor
                )
            end
            
            -- ===== Render Text =====
            RenderText(
                drawingData,
                barPosX,
                barPosY,
                barWidth,
                barHeight,
                currentHealth,
                maxHealth,
                healthPercent
            )
            
            -- Mark as visible
            drawingData.isVisible = true
        end
    end)
    
    -- Handle errors
    if not success then
        HandleError(errorMessage)
    end
end

--[[
================================================================================
                            PHẦN 8: CONNECTION MANAGEMENT
================================================================================
--]]

-- ===== INITIALIZE CONNECTIONS =====
-- Setup tất cả connections cần thiết
local function InitializeConnections()
    -- ===== PlayerAdded Connection =====
    -- Tạo ESP cho player mới join
    State.playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        CreatePlayerESP(player)
    end)
    
    -- ===== PlayerRemoving Connection =====
    -- Cleanup ESP khi player rời
    State.playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        RemovePlayerESP(player)
    end)
    
    -- ===== RenderStepped Connection =====
    -- Main update loop
    State.renderConnection = RunService.RenderStepped:Connect(UpdateESP)
    
    DebugLog("Connections initialized")
end

-- ===== DISCONNECT ALL =====
-- Disconnect tất cả connections (cleanup)
local function DisconnectAll()
    if State.renderConnection then
        State.renderConnection:Disconnect()
        State.renderConnection = nil
    end
    
    if State.playerAddedConnection then
        State.playerAddedConnection:Disconnect()
        State.playerAddedConnection = nil
    end
    
    if State.playerRemovingConnection then
        State.playerRemovingConnection:Disconnect()
        State.playerRemovingConnection = nil
    end
    
    DebugLog("All connections disconnected")
end

-- ===== INITIALIZE ESP FOR EXISTING PLAYERS =====
-- Tạo ESP cho tất cả players đã có trong game
local function InitializeExistingPlayers()
    for _, player in Pairs(Players:GetPlayers()) do
        CreatePlayerESP(player)
    end
    
    DebugLog("Initialized ESP for " .. #Players:GetPlayers() - 1 .. " existing players")
end

--[[
================================================================================
                            PHẦN 9: PUBLIC HealthAPI
================================================================================
--]]

local HealthAPI = {}

-- ===== TOGGLE =====
-- Bật/tắt ESP
-- @param state: true/false
function HealthAPI:Toggle(state)
    Configuration.enabled = state
    
    -- Hide tất cả nếu disable
    if not state then
        for _, data in Pairs(State.espData) do
            -- Reset cả opacity để tránh bị bật lại
            data.targetOpacity = 0
            data.currentOpacity = 0
            HideAllDrawings(data)
        end
    end
    
    DebugLog("ESP toggled: " .. Tostring(state))
end

-- ===== UPDATE CONFIG =====
-- Cập nhật configuration
-- @param newConfig: Table chứa config mới (merge với existing)
-- @return: true nếu thành công
function HealthAPI:UpdateConfig(newConfig)
    -- Validate input
    if not newConfig or Type(newConfig) ~= "table" then
        return false
    end
    
    -- Merge config
    for key, value in Pairs(newConfig) do
        -- Chỉ update nếu key tồn tại trong config gốc
        if Configuration[key] ~= nil then
            -- Validate barStyle
            if key == "barStyle" then
                if value == "horizontal" or value == "vertical" then
                    Configuration[key] = value
                end
            -- Validate barColorMode
            elseif key == "barColorMode" then
                if value == "static" or value == "gradient" or value == "rainbow" then
                    Configuration[key] = value
                end
            -- Validate textPosition
            elseif key == "textPosition" then
                if value == "top" or value == "bottom" or value == "left" or value == "right" or value == "center" then
                    Configuration[key] = value
                end
            -- Validate textMode
            elseif key == "textMode" then
                if value == "percent" or value == "value" or value == "both" then
                    Configuration[key] = value
                end
            -- Validate teamFilterMode
            elseif key == "teamFilterMode" then
                if value == "standard" or value == "attribute" then
                    Configuration[key] = value
                end
            else
                -- Other configs: direct assign
                Configuration[key] = value
            end
        end
    end
    
    DebugLog("Configuration updated")
    return true
end

-- ===== GET CONFIG =====
-- Lấy configuration hiện tại
-- @return: Table configuration
function HealthAPI:GetConfig()
    return Configuration
end

-- ===== GET ENABLED =====
-- Kiểm tra trạng thái enabled
-- @return: true/false
function HealthAPI:GetEnabled()
    return Configuration.enabled
end

-- ===== WHITELIST FUNCTIONS =====

-- Thêm player vào whitelist
-- @param name: Tên player
function HealthAPI:AddToWhitelist(name)
    Configuration.whitelist[name] = true
    DebugLog("Added to whitelist: " .. name)
end

-- Xóa player khỏi whitelist
-- @param name: Tên player
function HealthAPI:RemoveFromWhitelist(name)
    Configuration.whitelist[name] = nil
    DebugLog("Removed from whitelist: " .. name)
end

-- Xóa toàn bộ whitelist
function HealthAPI:ClearWhitelist()
    Configuration.whitelist = {}
    DebugLog("Whitelist cleared")
end

-- ===== BLACKLIST FUNCTIONS =====

-- Thêm player vào blacklist
-- @param name: Tên player
function HealthAPI:AddToBlacklist(name)
    Configuration.blacklist[name] = true
    DebugLog("Added to blacklist: " .. name)
end

-- Xóa player khỏi blacklist
-- @param name: Tên player
function HealthAPI:RemoveFromBlacklist(name)
    Configuration.blacklist[name] = nil
    DebugLog("Removed from blacklist: " .. name)
end

-- Xóa toàn bộ blacklist
function HealthAPI:ClearBlacklist()
    Configuration.blacklist = {}
    DebugLog("Blacklist cleared")
end

-- ===== DESTROY =====
-- Cleanup hoàn toàn hệ thống ESP
function HealthAPI:Destroy()
    -- Disconnect tất cả connections
    DisconnectAll()
    
    -- Remove tất cả ESP drawings
    for player, _ in Pairs(State.espData) do
        RemovePlayerESP(player)
    end
    
    -- Clear state
    State.espData = {}
    State.isInitialized = false
    
    Print("[HealthBar ESP] Destroyed successfully")
end

-- ===== REFRESH =====
-- Refresh lại toàn bộ ESP (recreate all)
function HealthAPI:Refresh()
    -- Remove tất cả ESP hiện tại
    for player, _ in Pairs(State.espData) do
        RemovePlayerESP(player)
    end
    
    -- Recreate cho tất cả players
    InitializeExistingPlayers()
    
    DebugLog("ESP refreshed")
end

-- ===== RESET ERRORS =====
-- Reset error count (cho phép ESP hoạt động lại sau khi bị disable do lỗi)
function HealthAPI:ResetErrors()
    State.errorCount = 0
    State.lastErrorTime = 0
    Configuration.enabled = true
    
    DebugLog("Errors reset, ESP re-enabled")
end

-- ===== GET STATE =====
-- Lấy state hiện tại (debug purpose)
-- @return: Table state
function HealthAPI:GetState()
    return {
        playerCount = 0, -- Sẽ tính bên dưới
        errorCount = State.errorCount,
        isInitialized = State.isInitialized,
        rainbowHue = State.rainbowHue
    }
end

--[[
================================================================================
                            PHẦN 10: INITIALIZATION
================================================================================
--]]

-- ===== MAIN INITIALIZATION =====
-- Ở phần INITIALIZATION, thay thế:
local function Initialize()
    if State.isInitialized then
        DebugLog("Already initialized, skipping...")
        return
    end
    
    -- THÊM: Đợi character load
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- THÊM: Đợi camera
    repeat 
        task.wait() 
    until Workspace.CurrentCamera
    
    InitializeExistingPlayers()
    InitializeConnections()
    State.isInitialized = true
    
    DebugLog("HealthBar ESP initialized successfully!")
end


-- Run initialization
Initialize()

-- Return HealthAPI
return HealthAPI
