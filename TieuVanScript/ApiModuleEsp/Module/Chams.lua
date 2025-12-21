local Services = {
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	TweenService = game:GetService("TweenService")
}

local LocalPlayer = Services.Players.LocalPlayer
if not LocalPlayer then
	LocalPlayer = Services.Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Services.Players.LocalPlayer
end

type HighlightData = {
	highlight: Highlight?,
	partHighlights: {[string]: Highlight}?,
	lastHealth: number,
	isDead: boolean,
	lastVisible: boolean,
	lastDistance: number,
	lastUpdateTick: number
}

type PlayerCache = {
	[Player]: HighlightData
}

local ChamsAPI = {
  Config = {
	enabled = true,
	enableErrorRecovery = false,
	errorRecoveryThreshold = 5,
	errorRecoveryCooldown = 3,
	maxConsecutiveErrors = 10,
	maxDistance = 10000,
	updateInterval = 0.05,
	batchSize = 5,
	fillColor = Color3.fromRGB(0, 255, 140),
	outlineColor = Color3.fromRGB(0, 255, 140),
	visibleFillColor = Color3.fromRGB(0, 255, 0),
	visibleOutlineColor = Color3.fromRGB(0, 255, 0),
	hiddenFillColor = Color3.fromRGB(255, 0, 0),
	hiddenOutlineColor = Color3.fromRGB(255, 0, 0),
	fillTransparency = 0.5,
	outlineTransparency = 0,
	useTeamFilter = false,
	showTeammates = false,
	teammateFillColor = Color3.fromRGB(0, 150, 255),
	teammateOutlineColor = Color3.fromRGB(0, 150, 255),
	depthMode = "AlwaysOnTop",
	useRaycasting = false,
	fadeWhenBlocked = false,
	useVisibilityColors = false,
	pulseEnabled = false,
	pulseSpeed = 2,
	pulseMinMultiplier = 0.6,
	pulseMaxMultiplier = 1.4,
	rainbowEnabled = false,
	rainbowSpeed = 1,
	rainbowSaturation = 1,
	rainbowValue = 1,
	gradientEnabled = false,
	gradientColor1 = Color3.fromRGB(255, 0, 0),
	gradientColor2 = Color3.fromRGB(0, 0, 255),
	gradientSpeed = 1,
	distanceFadeEnabled = false,
	fadeStartDistance = 500,
	fadeEndDistance = 2000,
	outlineOnly = false,
	dynamicOutlineWidth = false,
	healthColorEnabled = false,
	healthFullColor = Color3.fromRGB(0, 255, 0),
	healthLowColor = Color3.fromRGB(255, 0, 0),
	highlightSpecificParts = false,
	partsToHighlight = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
	visibilityGlowEnabled = false,
	glowIntensityMultiplier = 1.5,
	debugMode = false
}

local RuntimeData = {
	highlightData = {} :: PlayerCache,
	connections = {} :: {[string]: RBXScriptConnection},
	playerConnections = {} :: {[Player]: {[string]: RBXScriptConnection}},
	lastUpdate = 0,
	rainbowHue = 0,
	pulsePhase = 0,
	gradientPhase = 0,
	playerQueue = {} :: {Player},
	currentQueueIndex = 1,
	cachedDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	lastDepthModeConfig = "AlwaysOnTop",
	errorCount = 0,
	lastErrorTime = 0,
	consecutiveErrors = 0,
	lastRecoveryTime = 0,
	isRecovering = false,
	errorLog = {} :: {string}
}

local function Log(message: string, level: string?)
	if not ChamsConfig.debugMode and level ~= "error" then return end
	local prefix = level == "error" and "[Chams ERROR]" or (level == "warn" and "[Chams WARN]" or "[Chams]")
	print(prefix, message)
end

local function RecordError(errorMessage: string)
	local currentTime = tick()
	RuntimeData.errorCount = RuntimeData.errorCount + 1
	RuntimeData.consecutiveErrors = RuntimeData.consecutiveErrors + 1
	RuntimeData.lastErrorTime = currentTime
	
	table.insert(RuntimeData.errorLog, string.format("[%s] %s", os.date("%H:%M:%S"), errorMessage))
	if #RuntimeData.errorLog > 50 then
		table.remove(RuntimeData.errorLog, 1)
	end
	
	Log("Error recorded: " .. errorMessage, "error")
end

local function ResetConsecutiveErrors()
	RuntimeData.consecutiveErrors = 0
end

local function ShouldAttemptRecovery(): boolean
	if not ChamsConfig.enableErrorRecovery then return false end
	if RuntimeData.isRecovering then return false end
	
	local currentTime = tick()
	local timeSinceLastRecovery = currentTime - RuntimeData.lastRecoveryTime
	
	if timeSinceLastRecovery < ChamsConfig.errorRecoveryCooldown then
		return false
	end
	
	if RuntimeData.consecutiveErrors >= ChamsConfig.maxConsecutiveErrors then
		return true
	end
	
	if RuntimeData.errorCount >= ChamsConfig.errorRecoveryThreshold then
		local timeSinceFirstError = currentTime - RuntimeData.lastErrorTime
		if timeSinceFirstError < 5 then
			return true
		end
	end
	
	return false
end

local function SafeCall<T...>(func: (...any) -> T..., ...: any): (boolean, T...)
	local results = {pcall(func, ...)}
	local success = results[1]
	
	if not success then
		local errorMsg = tostring(results[2])
		RecordError(errorMsg)
	else
		ResetConsecutiveErrors()
	end
	
	return table.unpack(results)
end

local function SafeCallSilent<T...>(func: (...any) -> T..., ...: any): (boolean, T...)
	return pcall(func, ...)
end

local function GetDepthMode(): Enum.HighlightDepthMode
	if ChamsConfig.depthMode ~= RuntimeData.lastDepthModeConfig then
		RuntimeData.lastDepthModeConfig = ChamsConfig.depthMode
		RuntimeData.cachedDepthMode = ChamsConfig.depthMode == "Occluded" 
			and Enum.HighlightDepthMode.Occluded 
			or Enum.HighlightDepthMode.AlwaysOnTop
	end
	return RuntimeData.cachedDepthMode
end

local function LerpColor(c1: Color3, c2: Color3, t: number): Color3
	return Color3.new(
		c1.R + (c2.R - c1.R) * t,
		c1.G + (c2.G - c1.G) * t,
		c1.B + (c2.B - c1.B) * t
	)
end

local function GetRainbowColor(): Color3
	return Color3.fromHSV(RuntimeData.rainbowHue, ChamsConfig.rainbowSaturation, ChamsConfig.rainbowValue)
end

local function GetGradientColor(): Color3
	local t = (math.sin(RuntimeData.gradientPhase) + 1) / 2
	return LerpColor(ChamsConfig.gradientColor1, ChamsConfig.gradientColor2, t)
end

local function GetPulseMultiplier(): number
	local wave = (math.sin(RuntimeData.pulsePhase) + 1) / 2
	return ChamsConfig.pulseMinMultiplier + (ChamsConfig.pulseMaxMultiplier - ChamsConfig.pulseMinMultiplier) * wave
end

local function ApplyPulseToTransparency(baseTransparency: number): number
	if not ChamsConfig.pulseEnabled then
		return baseTransparency
	end
	local multiplier = GetPulseMultiplier()
	local pulsedTransparency = baseTransparency * multiplier
	return math.clamp(pulsedTransparency, 0, 1)
end

local function GetDistanceFadeMultiplier(distance: number): number
	if not ChamsConfig.distanceFadeEnabled then return 1 end
	if distance <= ChamsConfig.fadeStartDistance then return 1 end
	if distance >= ChamsConfig.fadeEndDistance then return 0 end
	return 1 - ((distance - ChamsConfig.fadeStartDistance) / (ChamsConfig.fadeEndDistance - ChamsConfig.fadeStartDistance))
end

local function GetHealthColor(healthPercent: number): Color3
	return LerpColor(ChamsConfig.healthLowColor, ChamsConfig.healthFullColor, healthPercent)
end

local function CheckTeam(player1: Player, player2: Player): boolean
	if not player1 or not player2 then return false end
	
	local success, result = SafeCallSilent(function()
		if player1.Neutral and player2.Neutral then return false end
		if player1.Team and player2.Team then return player1.Team == player2.Team end
		if player1.TeamColor == player2.TeamColor then return true end
		
		local char1, char2 = player1.Character, player2.Character
		if char1 and char2 then
			local attr1, attr2 = char1:GetAttribute("Team"), char2:GetAttribute("Team")
			if attr1 and attr2 then return attr1 == attr2 end
		end
		return false
	end)
	
	return success and result or false
end

local function CheckLineOfSight(fromPos: Vector3, toPos: Vector3, ignoreChars: {Model}): boolean
	local direction = toPos - fromPos
	if direction.Magnitude == 0 then return true end
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreChars
	rayParams.IgnoreWater = true
	
	local success, result = SafeCallSilent(function()
		return workspace:Raycast(fromPos, direction, rayParams)
	end)
	
	if success and result then
		if result.Instance then
			local hitDistance = (result.Position - toPos).Magnitude
			if hitDistance < 5 then
				return true
			end
			
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChild("Humanoid") then
				return true
			end
			return false
		end
	end
	return true
end

local function CountHighlights(): number
	local count = 0
	for _ in pairs(RuntimeData.highlightData) do
		count = count + 1
	end
	return count
end

local function IsHighlightValid(highlightData: HighlightData?): boolean
	if not highlightData then return false end
	
	local success, isValid = SafeCallSilent(function()
		if ChamsConfig.highlightSpecificParts then
			if not highlightData.partHighlights then return false end
			for _, highlight in pairs(highlightData.partHighlights) do
				if highlight and highlight.Parent ~= nil and highlight.Adornee ~= nil and highlight.Adornee.Parent ~= nil then
					return true
				end
			end
			return false
		else
			if not highlightData.highlight then return false end
			return highlightData.highlight.Parent ~= nil
		end
	end)
	
	return success and isValid or false
end

local function GetPlayerStatus(player: Player): (boolean, boolean, boolean, number, number)
	if not ChamsConfig.enabled or player == LocalPlayer then 
		return false, false, false, 0, 0 
	end
	
	local success, result = SafeCallSilent(function()
		local character = player.Character
		if not character then 
			return {false, false, false, 0, 0}
		end
		
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		
		if not hrp or not humanoid then 
			return {false, false, false, 0, 0}
		end
		
		if humanoid.Health <= 0 then 
			return {false, false, false, 0, 0}
		end
		
		local myChar = LocalPlayer.Character
		if not myChar then 
			return {false, false, false, 0, 0}
		end
		
		local myHrp = myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not myHrp then 
			return {false, false, false, 0, 0}
		end
		
		local distance = (hrp.Position - myHrp.Position).Magnitude
		if distance > ChamsConfig.maxDistance then 
			return {false, false, false, distance, 0}
		end
		
		local isTeammate = CheckTeam(LocalPlayer, player)
		if ChamsConfig.useTeamFilter and isTeammate and not ChamsConfig.showTeammates then
			return {false, false, isTeammate, distance, 0}
		end
		
		local healthPercent = humanoid.Health / humanoid.MaxHealth
		
		local isVisible = true
		if ChamsConfig.useRaycasting then
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

local function GetChamsColors(isVisible: boolean, isTeammate: boolean, healthPercent: number): (Color3, Color3)
	if ChamsConfig.rainbowEnabled then
		local col = GetRainbowColor()
		return col, col
	end
	
	if ChamsConfig.gradientEnabled then
		local col = GetGradientColor()
		return col, col
	end
	
	if ChamsConfig.healthColorEnabled then
		local col = GetHealthColor(healthPercent)
		return col, col
	end
	
	if ChamsConfig.useVisibilityColors then
		if isVisible then
			return ChamsConfig.visibleFillColor, ChamsConfig.visibleOutlineColor
		else
			return ChamsConfig.hiddenFillColor, ChamsConfig.hiddenOutlineColor
		end
	end
	
	if isTeammate and ChamsConfig.showTeammates then
		return ChamsConfig.teammateFillColor, ChamsConfig.teammateOutlineColor
	end
	
	return ChamsConfig.fillColor, ChamsConfig.outlineColor
end

local function GetTransparency(isVisible: boolean, distance: number): (number, number)
	local fillTransp = ChamsConfig.fillTransparency
	local outlineTransp = ChamsConfig.outlineTransparency
	
	fillTransp = ApplyPulseToTransparency(fillTransp)
	
	if ChamsConfig.fadeWhenBlocked and not isVisible then
		fillTransp = math.min(fillTransp + 0.3, 1)
		outlineTransp = math.min(outlineTransp + 0.3, 1)
	end
	
	local fadeMult = GetDistanceFadeMultiplier(distance)
	if fadeMult < 1 then
		fillTransp = fillTransp + (1 - fadeMult) * (1 - fillTransp)
		outlineTransp = outlineTransp + (1 - fadeMult) * (1 - outlineTransp)
	end
	
	if ChamsConfig.outlineOnly then
		fillTransp = 1
	end
	
	return fillTransp, outlineTransp
end

local function CleanupPartHighlights(data: HighlightData)
	if data.partHighlights then
		for partName, highlight in pairs(data.partHighlights) do
			SafeCallSilent(function() highlight:Destroy() end)
		end
		data.partHighlights = nil
	end
end

local function CreatePartHighlights(player: Player, character: Model): {[string]: Highlight}?
	local partHighlights = {}
	local depthMode = GetDepthMode()
	
	local success = SafeCallSilent(function()
		for _, partName in ChamsConfig.partsToHighlight do
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
		for _, highlight in pairs(partHighlights) do
			SafeCallSilent(function() highlight:Destroy() end)
		end
		return nil
	end
	
	return partHighlights
end

local function CreateHighlight(player: Player, character: Model): boolean
	local success, result = SafeCallSilent(function()
		if RuntimeData.highlightData[player] then
			local oldData = RuntimeData.highlightData[player]
			if oldData.highlight then
				oldData.highlight:Destroy()
			end
			CleanupPartHighlights(oldData)
		end
		
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		local currentHealth = humanoid and humanoid.Health or 100
		local maxHealth = humanoid and humanoid.MaxHealth or 100
		
		local data: HighlightData = {
			highlight = nil,
			partHighlights = nil,
			lastHealth = currentHealth,
			isDead = currentHealth <= 0,
			lastVisible = true,
			lastDistance = 0,
			lastUpdateTick = tick()
		}
		
		if ChamsConfig.highlightSpecificParts then
			local partHighlights = CreatePartHighlights(player, character)
			
			if not partHighlights then
				return false
			end
			
			local hasAnyHighlight = false
			for _ in pairs(partHighlights) do
				hasAnyHighlight = true
				break
			end
			
			if not hasAnyHighlight then
				return false
			end
			
			data.partHighlights = partHighlights
		else
			local highlight = Instance.new("Highlight")
			highlight.Name = "AdvancedChams_" .. player.UserId
			highlight.Adornee = character
			highlight.DepthMode = GetDepthMode()
			highlight.Enabled = true
			highlight.Parent = character
			data.highlight = highlight
		end
		
		RuntimeData.highlightData[player] = data
		return true
	end)
	
	return success and result or false
end

local function RemoveHighlight(player: Player)
	SafeCallSilent(function()
		local data = RuntimeData.highlightData[player]
		if data then
			if data.highlight then
				data.highlight:Destroy()
			end
			CleanupPartHighlights(data)
			RuntimeData.highlightData[player] = nil
		end
	end)
	
	local playerConns = RuntimeData.playerConnections[player]
	if playerConns then
		for _, conn in pairs(playerConns) do
			SafeCallSilent(function() conn:Disconnect() end)
		end
		RuntimeData.playerConnections[player] = nil
	end
end

local function UpdateHighlightProperties(highlight: Highlight, fillColor: Color3, outlineColor: Color3, fillTransp: number, outlineTransp: number, isVisible: boolean)
	local finalOutlineColor = outlineColor
	
	if ChamsConfig.visibilityGlowEnabled and isVisible then
		local h, s, v = outlineColor:ToHSV()
		v = math.min(v * ChamsConfig.glowIntensityMultiplier, 1)
		s = math.max(s * 0.9, 0)
		finalOutlineColor = Color3.fromHSV(h, s, v)
	end
	
	highlight.FillColor = fillColor
	highlight.OutlineColor = finalOutlineColor
	highlight.FillTransparency = fillTransp
	highlight.OutlineTransparency = outlineTransp
	highlight.DepthMode = GetDepthMode()
end

local function UpdateHighlight(player: Player)
	local shouldShow, isVisible, isTeammate, distance, healthPercent = GetPlayerStatus(player)
	
	if not shouldShow then
		RemoveHighlight(player)
		return
	end
	
	local character = player.Character
	if not character then
		RemoveHighlight(player)
		return
	end
	
	local data = RuntimeData.highlightData[player]
	
	local needsRecreate = false
	if not IsHighlightValid(data) then
		needsRecreate = true
	elseif data then
		local currentMode = ChamsConfig.highlightSpecificParts
		local dataHasParts = data.partHighlights ~= nil
		if currentMode ~= dataHasParts then
			needsRecreate = true
		end
	end
	
	if needsRecreate then
		if not CreateHighlight(player, character) then
			return
		end
		data = RuntimeData.highlightData[player]
	end
	
	if not data then return end
	
	data.lastVisible = isVisible
	data.lastDistance = distance
	data.lastHealth = healthPercent * 100
	data.lastUpdateTick = tick()
	
	local fillColor, outlineColor = GetChamsColors(isVisible, isTeammate, healthPercent)
	local fillTransp, outlineTransp = GetTransparency(isVisible, distance)
	
	SafeCallSilent(function()
		if ChamsConfig.highlightSpecificParts and data.partHighlights then
			for partName, highlight in pairs(data.partHighlights) do
				local adornee = highlight.Adornee
				local adorneeValid = adornee and adornee.Parent ~= nil
				local parentValid = highlight.Parent ~= nil
				
				if parentValid and adorneeValid then
					UpdateHighlightProperties(highlight, fillColor, outlineColor, fillTransp, outlineTransp, isVisible)
				else
					highlight:Destroy()
					data.partHighlights[partName] = nil
				end
			end
			
			for _, partName in ChamsConfig.partsToHighlight do
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
			local adornee = data.highlight.Adornee
			if adornee ~= character then
				data.highlight.Adornee = character
			end
			UpdateHighlightProperties(data.highlight, fillColor, outlineColor, fillTransp, outlineTransp, isVisible)
		end
	end)
end

local function RebuildPlayerQueue()
	RuntimeData.playerQueue = {}
	for _, player in Services.Players:GetPlayers() do
		if player ~= LocalPlayer then
			table.insert(RuntimeData.playerQueue, player)
		end
	end
	RuntimeData.currentQueueIndex = 1
end

local function UpdateEffectPhases(deltaTime: number)
	if ChamsConfig.rainbowEnabled then
		RuntimeData.rainbowHue = (RuntimeData.rainbowHue + deltaTime * ChamsConfig.rainbowSpeed * 0.1) % 1
	end
	if ChamsConfig.pulseEnabled then
		RuntimeData.pulsePhase = RuntimeData.pulsePhase + deltaTime * ChamsConfig.pulseSpeed * math.pi
	end
	if ChamsConfig.gradientEnabled then
		RuntimeData.gradientPhase = RuntimeData.gradientPhase + deltaTime * ChamsConfig.gradientSpeed * math.pi
	end
end

local function CleanupAll()
	for player in pairs(RuntimeData.highlightData) do
		RemoveHighlight(player)
	end
	
	for name, conn in pairs(RuntimeData.connections) do
		SafeCallSilent(function() conn:Disconnect() end)
	end
	RuntimeData.connections = {}
	
	for player, conns in pairs(RuntimeData.playerConnections) do
		for _, conn in pairs(conns) do
			SafeCallSilent(function() conn:Disconnect() end)
		end
	end
	RuntimeData.playerConnections = {}
	
	RuntimeData.playerQueue = {}
	RuntimeData.currentQueueIndex = 1
	
	Log("Cleanup completed")
end

local function PerformErrorRecovery()
	if RuntimeData.isRecovering then return end
	
	RuntimeData.isRecovering = true
	RuntimeData.lastRecoveryTime = tick()
	
	Log("Performing error recovery...", "warn")
	
	SafeCallSilent(function()
		for player in pairs(RuntimeData.highlightData) do
			local data = RuntimeData.highlightData[player]
			if data then
				if data.highlight then
					data.highlight:Destroy()
				end
				CleanupPartHighlights(data)
			end
		end
	end)
	
	RuntimeData.highlightData = {}
	RuntimeData.errorCount = 0
	RuntimeData.consecutiveErrors = 0
	
	task.defer(function()
		task.wait(0.5)
		RebuildPlayerQueue()
		RuntimeData.isRecovering = false
		Log("Error recovery completed")
	end)
end

local function UpdateBatchChams()
	if not ChamsConfig.enabled then return end
	if RuntimeData.isRecovering then return end
	
	local success, errorMsg = pcall(function()
		local currentTime = tick()
		local deltaTime = currentTime - RuntimeData.lastUpdate
		
		if deltaTime < ChamsConfig.updateInterval then return end
		RuntimeData.lastUpdate = currentTime
		
		UpdateEffectPhases(deltaTime)
		
		local queueLength = #RuntimeData.playerQueue
		if queueLength == 0 then
			RebuildPlayerQueue()
			queueLength = #RuntimeData.playerQueue
			if queueLength == 0 then return end
		end
		
		local batchCount = math.min(ChamsConfig.batchSize, queueLength)
		
		for i = 1, batchCount do
			local index = RuntimeData.currentQueueIndex
			local player = RuntimeData.playerQueue[index]
			
			if player and player.Parent then
				UpdateHighlight(player)
			else
				table.remove(RuntimeData.playerQueue, index)
				queueLength = #RuntimeData.playerQueue
				if queueLength == 0 then break end
				if RuntimeData.currentQueueIndex > queueLength then
					RuntimeData.currentQueueIndex = 1
				end
			end
			
			RuntimeData.currentQueueIndex = RuntimeData.currentQueueIndex + 1
			if RuntimeData.currentQueueIndex > #RuntimeData.playerQueue then
				RuntimeData.currentQueueIndex = 1
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

local function SetupPlayerConnections(player: Player)
	if player == LocalPlayer then return end
	
	RuntimeData.playerConnections[player] = {}
	
	RuntimeData.playerConnections[player]["charAdded"] = player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		if player.Parent and ChamsConfig.enabled then
			SafeCallSilent(function()
				UpdateHighlight(player)
			end)
		end
	end)
	
	RuntimeData.playerConnections[player]["charRemoving"] = player.CharacterRemoving:Connect(function()
		RemoveHighlight(player)
	end)
	
	if not table.find(RuntimeData.playerQueue, player) then
		table.insert(RuntimeData.playerQueue, player)
	end
end

local function InitializeEvents()
	RuntimeData.connections.heartbeat = Services.RunService.Heartbeat:Connect(UpdateBatchChams)
	
	RuntimeData.connections.playerRemoving = Services.Players.PlayerRemoving:Connect(function(player)
		RemoveHighlight(player)
		
		local index = table.find(RuntimeData.playerQueue, player)
		if index then
			table.remove(RuntimeData.playerQueue, index)
			if RuntimeData.currentQueueIndex > #RuntimeData.playerQueue and #RuntimeData.playerQueue > 0 then
				RuntimeData.currentQueueIndex = 1
			end
		end
	end)
	
	RuntimeData.connections.playerAdded = Services.Players.PlayerAdded:Connect(SetupPlayerConnections)
	
	RuntimeData.connections.localCharAdded = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		for player in pairs(RuntimeData.highlightData) do
			RemoveHighlight(player)
		end
		task.wait(0.2)
		RebuildPlayerQueue()
	end)
	
	for _, player in Services.Players:GetPlayers() do
		SetupPlayerConnections(player)
	end
	
	RebuildPlayerQueue()
end

InitializeEvents()

local ChamsAPI = {}

function ChamsAPI:Toggle(state: boolean)
	ChamsConfig.enabled = state
	if not state then
		for player in pairs(RuntimeData.highlightData) do
			RemoveHighlight(player)
		end
	else
		RebuildPlayerQueue()
	end
	Log("Chams " .. (state and "enabled" or "disabled"))
end

function ChamsAPI:UpdateConfig(config: {[string]: any})
	local needsRecreate = false
	
	if config.highlightSpecificParts ~= nil and config.highlightSpecificParts ~= ChamsConfig.highlightSpecificParts then
		needsRecreate = true
	end
	if config.partsToHighlight ~= nil then
		needsRecreate = true
	end
	
	for key, value in pairs(config) do
		if ChamsConfig[key] ~= nil then
			ChamsConfig[key] = value
		end
	end
	
	if config.depthMode then
		RuntimeData.lastDepthModeConfig = ""
		GetDepthMode()
	end
	
	if needsRecreate and ChamsConfig.enabled then
		for player in pairs(RuntimeData.highlightData) do
			RemoveHighlight(player)
		end
		RebuildPlayerQueue()
	end
	
	Log("Config updated")
end

function ChamsAPI:GetConfig(): typeof(ChamsConfig)
	return ChamsConfig
end

function ChamsAPI:GetRuntimeStats(): {[string]: any}
	return {
		highlightCount = CountHighlights(),
		queueLength = #RuntimeData.playerQueue,
		currentQueueIndex = RuntimeData.currentQueueIndex,
		lastUpdate = RuntimeData.lastUpdate,
		rainbowHue = RuntimeData.rainbowHue,
		pulsePhase = RuntimeData.pulsePhase
	}
end

function ChamsAPI:GetErrorStats(): {[string]: any}
	return {
		errorCount = RuntimeData.errorCount,
		consecutiveErrors = RuntimeData.consecutiveErrors,
		lastErrorTime = RuntimeData.lastErrorTime,
		lastRecoveryTime = RuntimeData.lastRecoveryTime,
		isRecovering = RuntimeData.isRecovering,
		recentErrors = RuntimeData.errorLog
	}
end

function ChamsAPI:ResetErrorTracking()
	RuntimeData.errorCount = 0
	RuntimeData.consecutiveErrors = 0
	RuntimeData.lastErrorTime = 0
	RuntimeData.errorLog = {}
	Log("Error tracking reset")
end

function ChamsAPI:ForceRecovery()
	PerformErrorRecovery()
end

function ChamsAPI:ForceUpdateAll()
	RebuildPlayerQueue()
	for _, player in RuntimeData.playerQueue do
		UpdateHighlight(player)
	end
	Log("Force updated all players")
end

function ChamsAPI:Destroy()
	CleanupAll()
	Log("ChamsAPI destroyed")
end

Log("Chams initialized successfully")

return ChamsAPI
