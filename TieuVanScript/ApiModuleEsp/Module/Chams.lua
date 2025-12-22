 --=============================================================================
-- PHẦN 1: SERVICES & CONFIGURATION
--=============================================================================

-- Khai báo tất cả Services cần thiết
local Services = {
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	Workspace = game:GetService("Workspace")
}

-- Lấy LocalPlayer, wait nếu chưa có
local LocalPlayer = Services.Players.LocalPlayer
if not LocalPlayer then
	Services.Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Services.Players.LocalPlayer
end

-- Type definitions cho type safety
type HighlightData = {
	highlight: Highlight?,                    -- Highlight chính (full character)
	partHighlights: {[string]: Highlight}?,   -- Highlights cho từng part riêng
	lastHealth: number,                       -- Health cuối cùng được ghi nhận
	lastVisible: boolean,                     -- Trạng thái visible cuối cùng
	lastDistance: number,                     -- Khoảng cách cuối cùng
	lastUpdateTick: number,                   -- Thời điểm update cuối
	isTeammate: boolean                       -- Cache trạng thái teammate
}

type PlayerCache = {[Player]: HighlightData}

-- Configuration centralized - tất cả settings ở đây
local Config = {
	-- Core settings
	enabled = false,                           -- Bật/tắt chams
	maxDistance = 10000,                      -- Khoảng cách tối đa hiển thị
	updateInterval = 0.05,                    -- Thời gian giữa các lần update (50ms)
	batchSize = 5,                            -- Số players xử lý mỗi frame
	
	-- Màu sắc cơ bản
	fillColor = Color3.fromRGB(0, 255, 140),
	outlineColor = Color3.fromRGB(0, 255, 140),
	fillTransparency = 0.5,
	outlineTransparency = 0,
	
	-- Visibility colors (khi bật useVisibilityColors)
	useVisibilityColors = false,
	visibleFillColor = Color3.fromRGB(0, 255, 0),
	visibleOutlineColor = Color3.fromRGB(0, 255, 0),
	hiddenFillColor = Color3.fromRGB(255, 0, 0),
	hiddenOutlineColor = Color3.fromRGB(255, 0, 0),
	
	-- Team settings
	useTeamFilter = false,                    -- Lọc theo team
	showTeammates = false,                    -- Hiển thị teammates
	teammateFillColor = Color3.fromRGB(0, 150, 255),
	teammateOutlineColor = Color3.fromRGB(0, 150, 255),
	
	-- Depth mode
	depthMode = "AlwaysOnTop",                -- "AlwaysOnTop" hoặc "Occluded"
	
	-- Raycast visibility check
	useRaycasting = false,                    -- Kiểm tra line of sight
	fadeWhenBlocked = false,                  -- Fade khi bị che
	
	-- Rainbow effect
	rainbowEnabled = false,
	rainbowSpeed = 1,
	rainbowSaturation = 1,
	rainbowValue = 1,
	
	-- Pulse effect
	pulseEnabled = false,
	pulseSpeed = 2,
	pulseMinMultiplier = 0.6,
	pulseMaxMultiplier = 1.4,
	
	-- Gradient effect
	gradientEnabled = false,
	gradientColor1 = Color3.fromRGB(255, 0, 0),
	gradientColor2 = Color3.fromRGB(0, 0, 255),
	gradientSpeed = 1,
	
	-- Distance fade
	distanceFadeEnabled = false,
	fadeStartDistance = 500,
	fadeEndDistance = 2000,
	
	-- Health-based coloring
	healthColorEnabled = false,
	healthFullColor = Color3.fromRGB(0, 255, 0),
	healthLowColor = Color3.fromRGB(255, 0, 0),
	
	-- Highlight modes
	outlineOnly = false,                      -- Chỉ hiển thị outline
	highlightSpecificParts = false,           -- Highlight riêng từng part
	partsToHighlight = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
	
	-- Visibility glow
	visibilityGlowEnabled = false,
	glowIntensityMultiplier = 1.5,
	
	-- Error recovery
	enableErrorRecovery = true,
	errorRecoveryThreshold = 5,               -- Số lỗi trước khi recovery
	errorRecoveryCooldown = 3,                -- Cooldown giữa các lần recovery
	maxConsecutiveErrors = 10,                -- Tự động disable nếu vượt
	
	-- Debug
	debugMode = false
}

-- Runtime state - lưu trữ trạng thái runtime
local State = {
	-- Cache data
	highlightData = {} :: PlayerCache,        -- Cache highlight cho mỗi player
	connections = {} :: {[string]: RBXScriptConnection},
	playerConnections = {} :: {[Player]: {[string]: RBXScriptConnection}},
	
	-- Queue management
	playerQueue = {} :: {Player},             -- Queue players cần update
	currentQueueIndex = 1,                    -- Index hiện tại trong queue
	queueDirty = false,                       -- Flag cần rebuild queue
	
	-- Timing
	lastUpdate = 0,                           -- Thời điểm update cuối
	
	-- Effect phases (SHARED - chỉ tính 1 lần/frame)
	rainbowHue = 0,                           -- Hue hiện tại cho rainbow
	pulsePhase = 0,                           -- Phase hiện tại cho pulse
	gradientPhase = 0,                        -- Phase hiện tại cho gradient
	
	-- Depth mode cache
	cachedDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	lastDepthModeConfig = "AlwaysOnTop",
	
	-- Error tracking
	errorCount = 0,                           -- Tổng số lỗi
	consecutiveErrors = 0,                    -- Số lỗi liên tiếp
	lastErrorTime = 0,                        -- Thời điểm lỗi cuối
	lastRecoveryTime = 0,                     -- Thời điểm recovery cuối
	isRecovering = false,                     -- Đang trong quá trình recovery
	errorLog = {} :: {string}                 -- Log các lỗi gần đây
}

--=============================================================================
-- PHẦN 2: UTILITY FUNCTIONS
--=============================================================================

-- Ghi log với level (chỉ print khi debugMode = true hoặc là error)
local function Log(message: string, level: string?)
	if not Config.debugMode and level ~= "error" then return end
	
	local prefix = "[Chams]"
	if level == "error" then
		prefix = "[Chams ERROR]"
	elseif level == "warn" then
		prefix = "[Chams WARN]"
	end
	
	print(prefix, message)
end

-- Ghi nhận lỗi vào error tracking system
local function RecordError(errorMessage: string)
	local currentTime = tick()
	
	State.errorCount = State.errorCount + 1
	State.consecutiveErrors = State.consecutiveErrors + 1
	State.lastErrorTime = currentTime
	
	-- Thêm vào log, giữ tối đa 50 entries
	local logEntry = string.format("[%s] %s", os.date("%H:%M:%S"), errorMessage)
	table.insert(State.errorLog, logEntry)
	
	if #State.errorLog > 50 then
		table.remove(State.errorLog, 1)
	end
	
	Log("Error: " .. errorMessage, "error")
end

-- Reset error counter khi operation thành công
local function ResetConsecutiveErrors()
	State.consecutiveErrors = 0
end

-- SafeCall với error recording
local function SafeCall<T...>(func: (...any) -> T..., ...: any): (boolean, T...)
	local results = {pcall(func, ...)}
	local success = results[1]
	
	if success then
		ResetConsecutiveErrors()
	else
		RecordError(tostring(results[2]))
	end
	
	return table.unpack(results)
end

-- SafeCall không record error (cho operations không quan trọng)
local function SafeCallSilent<T...>(func: (...any) -> T..., ...: any): (boolean, T...)
	return pcall(func, ...)
end

--=============================================================================
-- PHẦN 3: ERROR RECOVERY SYSTEM
--=============================================================================

-- Forward declaration cho PerformErrorRecovery và RebuildPlayerQueue
local PerformErrorRecovery: () -> ()
local RebuildPlayerQueue: () -> ()

-- Kiểm tra có nên thực hiện recovery không
local function ShouldAttemptRecovery(): boolean
	-- Không recovery nếu disabled hoặc đang recovery
	if not Config.enableErrorRecovery then return false end
	if State.isRecovering then return false end
	
	local currentTime = tick()
	local timeSinceLastRecovery = currentTime - State.lastRecoveryTime
	
	-- Chưa đủ cooldown
	if timeSinceLastRecovery < Config.errorRecoveryCooldown then
		return false
	end
	
	-- Quá nhiều lỗi liên tiếp
	if State.consecutiveErrors >= Config.maxConsecutiveErrors then
		return true
	end
	
	-- Nhiều lỗi trong thời gian ngắn
	if State.errorCount >= Config.errorRecoveryThreshold then
		local timeSinceFirstError = currentTime - State.lastErrorTime
		if timeSinceFirstError < 5 then
			return true
		end
	end
	
	return false
end

--=============================================================================
-- PHẦN 4: DEPTH MODE MANAGER
--=============================================================================

-- Lấy depth mode enum, có cache để tránh convert nhiều lần
local function GetDepthMode(): Enum.HighlightDepthMode
	-- Chỉ convert khi config thay đổi
	if Config.depthMode ~= State.lastDepthModeConfig then
		State.lastDepthModeConfig = Config.depthMode
		
		if Config.depthMode == "Occluded" then
			State.cachedDepthMode = Enum.HighlightDepthMode.Occluded
		else
			State.cachedDepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		end
	end
	
	return State.cachedDepthMode
end

--=============================================================================
-- PHẦN 5: COLOR SYSTEM
--=============================================================================

-- Interpolate giữa 2 màu
local function LerpColor(c1: Color3, c2: Color3, t: number): Color3
	return Color3.new(
		c1.R + (c2.R - c1.R) * t,
		c1.G + (c2.G - c1.G) * t,
		c1.B + (c2.B - c1.B) * t
	)
end

-- Lấy màu rainbow từ shared hue
local function GetRainbowColor(): Color3
	return Color3.fromHSV(
		State.rainbowHue,
		Config.rainbowSaturation,
		Config.rainbowValue
	)
end

-- Lấy màu gradient từ shared phase
local function GetGradientColor(): Color3
	local t = (math.sin(State.gradientPhase) + 1) / 2
	return LerpColor(Config.gradientColor1, Config.gradientColor2, t)
end

-- Lấy pulse multiplier từ shared phase
local function GetPulseMultiplier(): number
	local wave = (math.sin(State.pulsePhase) + 1) / 2
	return Config.pulseMinMultiplier + (Config.pulseMaxMultiplier - Config.pulseMinMultiplier) * wave
end

-- Apply pulse effect vào transparency
local function ApplyPulseToTransparency(baseTransparency: number): number
	if not Config.pulseEnabled then
		return baseTransparency
	end
	
	local multiplier = GetPulseMultiplier()
	local pulsedTransparency = baseTransparency * multiplier
	
	return math.clamp(pulsedTransparency, 0, 1)
end

-- Lấy fade multiplier dựa trên distance
local function GetDistanceFadeMultiplier(distance: number): number
	if not Config.distanceFadeEnabled then return 1 end
	
	if distance <= Config.fadeStartDistance then return 1 end
	if distance >= Config.fadeEndDistance then return 0 end
	
	local range = Config.fadeEndDistance - Config.fadeStartDistance
	return 1 - ((distance - Config.fadeStartDistance) / range)
end

-- Lấy màu dựa trên health percent
local function GetHealthColor(healthPercent: number): Color3
	return LerpColor(Config.healthLowColor, Config.healthFullColor, healthPercent)
end

-- Main color getter - quyết định màu dựa trên config và trạng thái
local function GetChamsColors(isVisible: boolean, isTeammate: boolean, healthPercent: number): (Color3, Color3)
	-- Priority: Rainbow > Gradient > Health > Visibility > Teammate > Default
	
	if Config.rainbowEnabled then
		local col = GetRainbowColor()
		return col, col
	end
	
	if Config.gradientEnabled then
		local col = GetGradientColor()
		return col, col
	end
	
	if Config.healthColorEnabled then
		local col = GetHealthColor(healthPercent)
		return col, col
	end
	
	if Config.useVisibilityColors then
		if isVisible then
			return Config.visibleFillColor, Config.visibleOutlineColor
		else
			return Config.hiddenFillColor, Config.hiddenOutlineColor
		end
	end
	
	if isTeammate and Config.showTeammates then
		return Config.teammateFillColor, Config.teammateOutlineColor
	end
	
	return Config.fillColor, Config.outlineColor
end

-- Tính transparency với tất cả effects
local function GetTransparency(isVisible: boolean, distance: number): (number, number)
	local fillTransp = Config.fillTransparency
	local outlineTransp = Config.outlineTransparency
	
	-- Apply pulse effect
	fillTransp = ApplyPulseToTransparency(fillTransp)
	
	-- Fade khi bị blocked
	if Config.fadeWhenBlocked and not isVisible then
		fillTransp = math.min(fillTransp + 0.3, 1)
		outlineTransp = math.min(outlineTransp + 0.3, 1)
	end
	
	-- Distance fade
	local fadeMult = GetDistanceFadeMultiplier(distance)
	if fadeMult < 1 then
		fillTransp = fillTransp + (1 - fadeMult) * (1 - fillTransp)
		outlineTransp = outlineTransp + (1 - fadeMult) * (1 - outlineTransp)
	end
	
	-- Outline only mode
	if Config.outlineOnly then
		fillTransp = 1
	end
	
	return fillTransp, outlineTransp
end

--=============================================================================
-- PHẦN 6: VALIDATION & DETECTION
--=============================================================================

-- Kiểm tra 2 players có cùng team không
local function CheckTeam(player1: Player, player2: Player): boolean
	if not player1 or not player2 then return false end
	
	local success, result = SafeCallSilent(function()
		-- Neutral players không cùng team với ai
		if player1.Neutral and player2.Neutral then return false end
		
		-- So sánh Team object
		if player1.Team and player2.Team then
			return player1.Team == player2.Team
		end
		
		-- So sánh TeamColor
		if player1.TeamColor == player2.TeamColor then
			return true
		end
		
		-- Custom team attribute (cho games custom)
		local char1 = player1.Character
		local char2 = player2.Character
		if char1 and char2 then
			local attr1 = char1:GetAttribute("Team")
			local attr2 = char2:GetAttribute("Team")
			if attr1 and attr2 then
				return attr1 == attr2
			end
		end
		
		return false
	end)
	
	return success and result or false
end

-- Raycast kiểm tra line of sight
local function CheckLineOfSight(fromPos: Vector3, toPos: Vector3, ignoreChars: {Model}): boolean
	local direction = toPos - fromPos
	if direction.Magnitude == 0 then return true end
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreChars
	rayParams.IgnoreWater = true
	
	local success, rayResult = SafeCallSilent(function()
		return Services.Workspace:Raycast(fromPos, direction, rayParams)
	end)
	
	if success and rayResult then
		-- Có hit gì đó
		if rayResult.Instance then
			-- Nếu hit gần target thì coi như visible
			local hitDistance = (rayResult.Position - toPos).Magnitude
			if hitDistance < 5 then
				return true
			end
			
			-- Nếu hit là player khác thì vẫn visible
			local model = rayResult.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChild("Humanoid") then
				return true
			end
			
			return false
		end
	end
	
	return true
end

-- Lấy trạng thái player (có nên highlight không, visible, teammate, distance, health)
local function GetPlayerStatus(player: Player): (boolean, boolean, boolean, number, number)
	-- Quick checks trước
	if not Config.enabled then return false, false, false, 0, 0 end
	if player == LocalPlayer then return false, false, false, 0, 0 end
	
	local success, result = SafeCallSilent(function()
		local character = player.Character
		if not character then return {false, false, false, 0, 0} end
		
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		
		if not hrp or not humanoid then return {false, false, false, 0, 0} end
		
		-- Player đã chết
		if humanoid.Health <= 0 then return {false, false, false, 0, 0} end
		
		-- Lấy vị trí local player
		local myChar = LocalPlayer.Character
		if not myChar then return {false, false, false, 0, 0} end
		
		local myHrp = myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not myHrp then return {false, false, false, 0, 0} end
		
		-- Tính distance
		local distance = (hrp.Position - myHrp.Position).Magnitude
		if distance > Config.maxDistance then
			return {false, false, false, distance, 0}
		end
		
		-- Kiểm tra team
		local isTeammate = CheckTeam(LocalPlayer, player)
		if Config.useTeamFilter and isTeammate and not Config.showTeammates then
			return {false, false, isTeammate, distance, 0}
		end
		
		-- Tính health percent
		local healthPercent = humanoid.Health / humanoid.MaxHealth
		
		-- Kiểm tra visibility (raycast)
		local isVisible = true
		if Config.useRaycasting then
			local charsToIgnore = {myChar, character}
			isVisible = CheckLineOfSight(myHrp.Position, hrp.Position, charsToIgnore)
		end
		
		return {true, isVisible, isTeammate, distance, healthPercent}
	end)
	
	if success and result then
		return result[1], result[2], result[3], result[4], result[5]
	end
	
	return false, false, false, 0, 0
end

-- Kiểm tra highlight data còn valid không
local function IsHighlightValid(data: HighlightData?): boolean
	if not data then return false end
	
	local success, isValid = SafeCallSilent(function()
		if Config.highlightSpecificParts then
			-- Part mode: cần ít nhất 1 part highlight valid
			if not data.partHighlights then return false end
			
			for _, highlight in pairs(data.partHighlights) do
				if highlight and highlight.Parent and highlight.Adornee and highlight.Adornee.Parent then
					return true
				end
			end
			return false
		else
			-- Full mode: cần highlight chính valid
			if not data.highlight then return false end
			return data.highlight.Parent ~= nil
		end
	end)
	
	return success and isValid or false
end

-- Đếm số highlights đang active
local function CountHighlights(): number
	local count = 0
	for _ in pairs(State.highlightData) do
		count = count + 1
	end
	return count
end

--=============================================================================
-- PHẦN 7: HIGHLIGHT CREATION & MANAGEMENT
--=============================================================================

-- Cleanup tất cả part highlights của một player
local function CleanupPartHighlights(data: HighlightData)
	if not data.partHighlights then return end
	
	for partName, highlight in pairs(data.partHighlights) do
		SafeCallSilent(function()
			highlight:Destroy()
		end)
	end
	
	data.partHighlights = nil
end

-- Tạo highlights cho từng part riêng
local function CreatePartHighlights(player: Player, character: Model): {[string]: Highlight}?
	local partHighlights = {}
	local depthMode = GetDepthMode()
	
	local success = SafeCallSilent(function()
		for _, partName in Config.partsToHighlight do
			local part = character:FindFirstChild(partName, true)
			if part and part:IsA("BasePart") then
				local highlight = Instance.new("Highlight")
				highlight.Name = "Chams_" .. player.UserId .. "_" .. partName
				highlight.Adornee = part
				highlight.DepthMode = depthMode
				highlight.Enabled = true
				highlight.Parent = character
				partHighlights[partName] = highlight
			end
		end
	end)
	
	if not success then
		-- Cleanup nếu fail
		for _, highlight in pairs(partHighlights) do
			SafeCallSilent(function() highlight:Destroy() end)
		end
		return nil
	end
	
	return partHighlights
end

-- Tạo highlight cho player (full hoặc part mode)
local function CreateHighlight(player: Player, character: Model): boolean
	local success, result = SafeCallSilent(function()
		-- Cleanup highlight cũ nếu có
		local oldData = State.highlightData[player]
		if oldData then
			if oldData.highlight then
				oldData.highlight:Destroy()
			end
			CleanupPartHighlights(oldData)
		end
		
		-- Lấy thông tin health
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		local currentHealth = humanoid and humanoid.Health or 100
		local maxHealth = humanoid and humanoid.MaxHealth or 100
		
		-- Khởi tạo data mới
		local data: HighlightData = {
			highlight = nil,
			partHighlights = nil,
			lastHealth = currentHealth,
			lastVisible = true,
			lastDistance = 0,
			lastUpdateTick = tick(),
			isTeammate = CheckTeam(LocalPlayer, player)
		}
		
		if Config.highlightSpecificParts then
			-- Part mode
			local partHighlights = CreatePartHighlights(player, character)
			if not partHighlights then return false end
			
			-- Kiểm tra có ít nhất 1 highlight
			local hasAny = false
			for _ in pairs(partHighlights) do
				hasAny = true
				break
			end
			if not hasAny then return false end
			
			data.partHighlights = partHighlights
		else
			-- Full mode
			local highlight = Instance.new("Highlight")
			highlight.Name = "Chams_" .. player.UserId
			highlight.Adornee = character
			highlight.DepthMode = GetDepthMode()
			highlight.Enabled = true
			highlight.Parent = character
			data.highlight = highlight
		end
		
		State.highlightData[player] = data
		return true
	end)
	
	return success and result or false
end

-- Update properties của highlight
local function UpdateHighlightProperties(
	highlight: Highlight,
	fillColor: Color3,
	outlineColor: Color3,
	fillTransp: number,
	outlineTransp: number,
	isVisible: boolean
)
	local finalOutlineColor = outlineColor
	
	-- Visibility glow effect
	if Config.visibilityGlowEnabled and isVisible then
		local h, s, v = outlineColor:ToHSV()
		v = math.min(v * Config.glowIntensityMultiplier, 1)
		s = math.max(s * 0.9, 0)
		finalOutlineColor = Color3.fromHSV(h, s, v)
	end
	
	highlight.FillColor = fillColor
	highlight.OutlineColor = finalOutlineColor
	highlight.FillTransparency = fillTransp
	highlight.OutlineTransparency = outlineTransp
	highlight.DepthMode = GetDepthMode()
end

-- Xóa highlight của player
local function RemoveHighlight(player: Player)
	SafeCallSilent(function()
		local data = State.highlightData[player]
		if data then
			if data.highlight then
				data.highlight:Destroy()
			end
			CleanupPartHighlights(data)
			State.highlightData[player] = nil
		end
	end)
	
	-- Cleanup player connections
	local playerConns = State.playerConnections[player]
	if playerConns then
		for _, conn in pairs(playerConns) do
			SafeCallSilent(function() conn:Disconnect() end)
		end
		State.playerConnections[player] = nil
	end
end

--=============================================================================
-- PHẦN 8: QUEUE MANAGEMENT
--=============================================================================

-- Rebuild player queue (exclude LocalPlayer)
RebuildPlayerQueue = function()
	State.playerQueue = {}
	
	for _, player in Services.Players:GetPlayers() do
		if player ~= LocalPlayer then
			table.insert(State.playerQueue, player)
		end
	end
	
	State.currentQueueIndex = 1
	State.queueDirty = false
	
	Log("Queue rebuilt: " .. #State.playerQueue .. " players")
end

-- Mark queue cần rebuild
local function MarkQueueDirty()
	State.queueDirty = true
end

-- Update tất cả effect phases (CHỈ GỌI 1 LẦN MỖI FRAME)
local function UpdateEffectPhases(deltaTime: number)
	-- Rainbow hue (0 -> 1 loop)
	if Config.rainbowEnabled then
		State.rainbowHue = (State.rainbowHue + deltaTime * Config.rainbowSpeed * 0.1) % 1
	end
	
	-- Pulse phase (sin wave)
	if Config.pulseEnabled then
		State.pulsePhase = State.pulsePhase + deltaTime * Config.pulseSpeed * math.pi
	end
	
	-- Gradient phase (sin wave)
	if Config.gradientEnabled then
		State.gradientPhase = State.gradientPhase + deltaTime * Config.gradientSpeed * math.pi
	end
end

--=============================================================================
-- PHẦN 9: MAIN UPDATE LOGIC
--=============================================================================

-- Update highlight cho 1 player
local function UpdateHighlight(player: Player)
	-- Lấy trạng thái player
	local shouldShow, isVisible, isTeammate, distance, healthPercent = GetPlayerStatus(player)
	
	-- Không nên hiển thị -> xóa highlight
	if not shouldShow then
		RemoveHighlight(player)
		return
	end
	
	local character = player.Character
	if not character then
		RemoveHighlight(player)
		return
	end
	
	local data = State.highlightData[player]
	
	-- Kiểm tra cần tạo mới không
	local needsRecreate = false
	
	if not IsHighlightValid(data) then
		needsRecreate = true
	elseif data then
		-- Mode đã thay đổi
		local currentMode = Config.highlightSpecificParts
		local dataHasParts = data.partHighlights ~= nil
		if currentMode ~= dataHasParts then
			needsRecreate = true
		end
	end
	
	-- Tạo mới nếu cần
	if needsRecreate then
		if not CreateHighlight(player, character) then
			return
		end
		data = State.highlightData[player]
	end
	
	if not data then return end
	
	-- Update cached values
	data.lastVisible = isVisible
	data.lastDistance = distance
	data.lastHealth = healthPercent * 100
	data.lastUpdateTick = tick()
	data.isTeammate = isTeammate
	
	-- Tính màu và transparency
	local fillColor, outlineColor = GetChamsColors(isVisible, isTeammate, healthPercent)
	local fillTransp, outlineTransp = GetTransparency(isVisible, distance)
	
	-- Apply vào highlights
	SafeCallSilent(function()
		if Config.highlightSpecificParts and data.partHighlights then
			-- Part mode: update từng part
			for partName, highlight in pairs(data.partHighlights) do
				local adornee = highlight.Adornee
				local valid = adornee and adornee.Parent and highlight.Parent
				
				if valid then
					UpdateHighlightProperties(highlight, fillColor, outlineColor, fillTransp, outlineTransp, isVisible)
				else
					-- Part không còn valid -> cleanup
					highlight:Destroy()
					data.partHighlights[partName] = nil
				end
			end
			
			-- Thêm parts mới nếu có
			for _, partName in Config.partsToHighlight do
				if not data.partHighlights[partName] then
					local part = character:FindFirstChild(partName, true)
					if part and part:IsA("BasePart") then
						local highlight = Instance.new("Highlight")
						highlight.Name = "Chams_" .. player.UserId .. "_" .. partName
						highlight.Adornee = part
						highlight.DepthMode = GetDepthMode()
						highlight.Enabled = true
						highlight.Parent = character
						data.partHighlights[partName] = highlight
						UpdateHighlightProperties(highlight, fillColor, outlineColor, fillTransp, outlineTransp, isVisible)
					end
				end
			end
		elseif data.highlight then
			-- Full mode
			local adornee = data.highlight.Adornee
			if adornee ~= character then
				data.highlight.Adornee = character
			end
			UpdateHighlightProperties(data.highlight, fillColor, outlineColor, fillTransp, outlineTransp, isVisible)
		end
	end)
end

-- Main update function - gọi mỗi frame
local function UpdateBatchChams()
	if not Config.enabled then return end
	if State.isRecovering then return end
	
	local success, errorMsg = pcall(function()
		local currentTime = tick()
		local deltaTime = currentTime - State.lastUpdate
		
		-- Frame skip check
		if deltaTime < Config.updateInterval then return end
		State.lastUpdate = currentTime
		
		-- Update shared effect phases (1 LẦN DUY NHẤT)
		UpdateEffectPhases(deltaTime)
		
		-- Rebuild queue nếu dirty
		if State.queueDirty then
			RebuildPlayerQueue()
		end
		
		local queueLength = #State.playerQueue
		if queueLength == 0 then
			RebuildPlayerQueue()
			queueLength = #State.playerQueue
			if queueLength == 0 then return end
		end
		
		-- Process batch
		local batchCount = math.min(Config.batchSize, queueLength)
		
		for i = 1, batchCount do
			local index = State.currentQueueIndex
			local player = State.playerQueue[index]
			
			if player and player.Parent then
				UpdateHighlight(player)
			else
				-- Player không còn valid -> remove khỏi queue
				table.remove(State.playerQueue, index)
				queueLength = #State.playerQueue
				
				if queueLength == 0 then break end
				
				-- Adjust index nếu cần
				if State.currentQueueIndex > queueLength then
					State.currentQueueIndex = 1
				end
				continue
			end
			
			-- Move to next in queue
			State.currentQueueIndex = State.currentQueueIndex + 1
			if State.currentQueueIndex > #State.playerQueue then
				State.currentQueueIndex = 1
			end
		end
	end)
	
	if not success then
		RecordError(tostring(errorMsg))
		
		if ShouldAttemptRecovery() then
			PerformErrorRecovery()
		end
	end
end

-- Cleanup tất cả highlights và connections
local function CleanupAll()
	-- Remove tất cả highlights
	for player in pairs(State.highlightData) do
		RemoveHighlight(player)
	end
	
	-- Disconnect global connections
	for name, conn in pairs(State.connections) do
		SafeCallSilent(function() conn:Disconnect() end)
	end
	State.connections = {}
	
	-- Disconnect player connections
	for player, conns in pairs(State.playerConnections) do
		for _, conn in pairs(conns) do
			SafeCallSilent(function() conn:Disconnect() end)
		end
	end
	State.playerConnections = {}
	
	-- Clear queue
	State.playerQueue = {}
	State.currentQueueIndex = 1
	
	Log("Cleanup completed")
end

-- Error recovery - destroy all và rebuild
PerformErrorRecovery = function()
	if State.isRecovering then return end
	
	State.isRecovering = true
	State.lastRecoveryTime = tick()
	
	Log("Performing error recovery...", "warn")
	
	-- Destroy tất cả highlights (không disconnect connections)
	SafeCallSilent(function()
		for player, data in pairs(State.highlightData) do
			if data.highlight then
				data.highlight:Destroy()
			end
			CleanupPartHighlights(data)
		end
	end)
	
	-- Clear cache
	State.highlightData = {}
	State.errorCount = 0
	State.consecutiveErrors = 0
	
	-- Defer rebuild để tránh immediate errors
	task.defer(function()
		task.wait(0.5)
		RebuildPlayerQueue()
		State.isRecovering = false
		Log("Error recovery completed")
	end)
end

--=============================================================================
-- PHẦN 10: CONNECTION MANAGEMENT
--=============================================================================

-- Setup connections cho player mới
local function SetupPlayerConnections(player: Player)
	if player == LocalPlayer then return end
	
	State.playerConnections[player] = {}
	
	-- CharacterAdded: update highlight khi có character mới
	State.playerConnections[player]["charAdded"] = player.CharacterAdded:Connect(function(character)
		task.wait(0.1) -- Đợi character load
		
		if player.Parent and Config.enabled then
			SafeCallSilent(function()
				UpdateHighlight(player)
			end)
		end
	end)
	
	-- CharacterRemoving: cleanup highlight
	State.playerConnections[player]["charRemoving"] = player.CharacterRemoving:Connect(function()
		RemoveHighlight(player)
	end)
	
	-- Thêm vào queue nếu chưa có
	if not table.find(State.playerQueue, player) then
		table.insert(State.playerQueue, player)
	end
end

-- Initialize tất cả events
local function InitializeEvents()
	-- Main update loop
	State.connections.heartbeat = Services.RunService.Heartbeat:Connect(UpdateBatchChams)
	
	-- Player leaving
	State.connections.playerRemoving = Services.Players.PlayerRemoving:Connect(function(player)
		RemoveHighlight(player)
		
		-- Remove khỏi queue
		local index = table.find(State.playerQueue, player)
		if index then
			table.remove(State.playerQueue, index)
			
			-- Adjust queue index
			if State.currentQueueIndex > #State.playerQueue and #State.playerQueue > 0 then
				State.currentQueueIndex = 1
			end
		end
	end)
	
	-- Player joining
	State.connections.playerAdded = Services.Players.PlayerAdded:Connect(SetupPlayerConnections)
	
	-- Local player respawn
	State.connections.localCharAdded = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		
		-- Clear tất cả highlights
		for player in pairs(State.highlightData) do
			RemoveHighlight(player)
		end
		
		task.wait(0.2)
		RebuildPlayerQueue()
	end)
	
	-- Setup cho players hiện tại
	for _, player in Services.Players:GetPlayers() do
		SetupPlayerConnections(player)
	end
	
	-- Build queue ban đầu
	RebuildPlayerQueue()
	
	Log("Events initialized")
end

--=============================================================================
-- PHẦN 11: PUBLIC API
--=============================================================================

local ChamsAPI = {}

-- Bật/tắt chams
function ChamsAPI:Toggle(state: boolean)
	Config.enabled = state
	
	if not state then
		-- Disable: remove tất cả highlights
		for player in pairs(State.highlightData) do
			RemoveHighlight(player)
		end
	else
		-- Enable: rebuild queue
		RebuildPlayerQueue()
	end
	
	Log("Chams " .. (state and "enabled" or "disabled"))
end

-- Update config
function ChamsAPI:UpdateConfig(newConfig: {[string]: any})
	local needsRecreate = false
	
	-- Kiểm tra có cần recreate highlights không
	if newConfig.highlightSpecificParts ~= nil and newConfig.highlightSpecificParts ~= Config.highlightSpecificParts then
		needsRecreate = true
	end
	
	if newConfig.partsToHighlight ~= nil then
		needsRecreate = true
	end
	
	-- Merge config
	for key, value in pairs(newConfig) do
		if Config[key] ~= nil then
			Config[key] = value
		end
	end
	
	-- Invalidate depth mode cache nếu thay đổi
	if newConfig.depthMode then
		State.lastDepthModeConfig = ""
		GetDepthMode()
	end
	
	-- Recreate highlights nếu cần
	if needsRecreate and Config.enabled then
		for player in pairs(State.highlightData) do
			RemoveHighlight(player)
		end
		RebuildPlayerQueue()
	end
	
	Log("Config updated")
end

-- Lấy config hiện tại
function ChamsAPI:GetConfig(): typeof(Config)
	return Config
end

-- Lấy runtime stats
function ChamsAPI:GetRuntimeStats(): {[string]: any}
	return {
		highlightCount = CountHighlights(),
		queueLength = #State.playerQueue,
		currentQueueIndex = State.currentQueueIndex,
		lastUpdate = State.lastUpdate,
		rainbowHue = State.rainbowHue,
		pulsePhase = State.pulsePhase,
		gradientPhase = State.gradientPhase
	}
end

-- Lấy error stats
function ChamsAPI:GetErrorStats(): {[string]: any}
	return {
		errorCount = State.errorCount,
		consecutiveErrors = State.consecutiveErrors,
		lastErrorTime = State.lastErrorTime,
		lastRecoveryTime = State.lastRecoveryTime,
		isRecovering = State.isRecovering,
		recentErrors = State.errorLog
	}
end

-- Reset error tracking
function ChamsAPI:ResetErrorTracking()
	State.errorCount = 0
	State.consecutiveErrors = 0
	State.lastErrorTime = 0
	State.errorLog = {}
	Log("Error tracking reset")
end

-- Force error recovery
function ChamsAPI:ForceRecovery()
	PerformErrorRecovery()
end

-- Force update tất cả players
function ChamsAPI:ForceUpdateAll()
	RebuildPlayerQueue()
	
	for _, player in State.playerQueue do
		UpdateHighlight(player)
	end
	
	Log("Force updated " .. #State.playerQueue .. " players")
end

-- Force rebuild queue
function ChamsAPI:ForceRebuildQueue()
	RebuildPlayerQueue()
end

-- Destroy toàn bộ system
function ChamsAPI:Destroy()
	CleanupAll()
	Log("ChamsAPI destroyed")
end

--=============================================================================
-- INITIALIZATION
--=============================================================================

InitializeEvents()
Log("Chams ESP initialized successfully")

return ChamsAPI
