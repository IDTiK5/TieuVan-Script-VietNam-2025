--=============================================================================
-- CHAMS ESP API MODULE
--=============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

type HighlightData = {
	highlight: Highlight?,
	lastUpdateTick: number
}

type PlayerCache = {
	[Player]: HighlightData
}

-- Configuration
local ChamsConfig = {
	enabled = false,
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
	
	EnableTeamCheck = false,
	ShowEnemyOnly = false,
	ShowAlliedOnly = false,
	UseTeamColors = false,
	UseActualTeamColors = true,
	
	EnemyFillColor = Color3.fromRGB(255, 0, 0),
	EnemyOutlineColor = Color3.fromRGB(255, 0, 0),
	AlliedFillColor = Color3.fromRGB(0, 255, 0),
	AlliedOutlineColor = Color3.fromRGB(0, 255, 0),
	NoTeamColor = Color3.fromRGB(255, 255, 255),
	
	depthMode = "AlwaysOnTop",
	useRaycasting = false,
	useVisibilityColors = false,
}

-- Runtime Data
local RuntimeData = {
	highlightData = {} :: PlayerCache,
	connections = {} :: {[string]: RBXScriptConnection},
	playerConnections = {} :: {[Player]: {[string]: RBXScriptConnection}},
	lastUpdate = 0,
	playerQueue = {} :: {Player},
	currentQueueIndex = 1,
	cachedDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
}

--=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================

local function SafeCall(func, ...)
	return pcall(func, ...)
end

local function GetDepthMode()
	return ChamsConfig.depthMode == "Occluded" 
		and Enum.HighlightDepthMode.Occluded 
		or Enum.HighlightDepthMode.AlwaysOnTop
end

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
	
	if not LocalPlayer.Team then
		if not targetPlayer.Team then return false end
		return true
	end
	
	if not targetPlayer.Team then return true end
	
	return LocalPlayer.Team ~= targetPlayer.Team
end

local function shouldShowPlayer(targetPlayer)
	if not ChamsConfig.EnableTeamCheck then return true end
	local isEnemyPlayer = isEnemy(targetPlayer)
	if ChamsConfig.ShowEnemyOnly and not isEnemyPlayer then return false end
	if ChamsConfig.ShowAlliedOnly and isEnemyPlayer then return false end
	return true
end

local function GetChamsColors(targetPlayer: Player, isVisible: boolean)
	if ChamsConfig.useVisibilityColors then
		if isVisible then
			return ChamsConfig.visibleFillColor, ChamsConfig.visibleOutlineColor
		else
			return ChamsConfig.hiddenFillColor, ChamsConfig.hiddenOutlineColor
		end
	end
	
	if not ChamsConfig.UseTeamColors then
		return ChamsConfig.fillColor, ChamsConfig.outlineColor
	end
	
	if ChamsConfig.UseActualTeamColors then
		local teamColor = getPlayerTeamColor(targetPlayer)
		if teamColor then
			return teamColor, teamColor
		else
			return ChamsConfig.NoTeamColor, ChamsConfig.NoTeamColor
		end
	else
		local isEnemyPlayer = isEnemy(targetPlayer)
		if isEnemyPlayer then
			return ChamsConfig.EnemyFillColor, ChamsConfig.EnemyOutlineColor
		else
			return ChamsConfig.AlliedFillColor, ChamsConfig.AlliedOutlineColor
		end
	end
end

local function CheckLineOfSight(fromPos: Vector3, toPos: Vector3, ignoreChars): boolean
	if not ChamsConfig.useRaycasting then return true end
	
	local direction = toPos - fromPos
	if direction.Magnitude == 0 then return true end
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreChars
	rayParams.IgnoreWater = true
	
	local success, result = SafeCall(function()
		return workspace:Raycast(fromPos, direction, rayParams)
	end)
	
	if success and result then
		if result.Instance then
			local hitDistance = (result.Position - toPos).Magnitude
			if hitDistance < 5 then return true end
			
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChild("Humanoid") then return true end
			return false
		end
	end
	return true
end

local function GetPlayerStatus(player: Player): (boolean, boolean, number)
	if not ChamsConfig.enabled or player == LocalPlayer then 
		return false, false, 0
	end
	
	local success, result = SafeCall(function()
		local character = player.Character
		if not character then return {false, false, 0} end
		
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")
		
		if not hrp or not humanoid or humanoid.Health <= 0 then 
			return {false, false, 0}
		end
		
		local myChar = LocalPlayer.Character
		if not myChar then return {false, false, 0} end
		
		local myHrp = myChar:FindFirstChild("HumanoidRootPart")
		if not myHrp then return {false, false, 0} end
		
		local distance = (hrp.Position - myHrp.Position).Magnitude
		if distance > ChamsConfig.maxDistance then 
			return {false, false, distance}
		end
		
		if not shouldShowPlayer(player) then
			return {false, false, distance}
		end
		
		local isVisible = CheckLineOfSight(myHrp.Position, hrp.Position, {myChar, character})
		
		return {true, isVisible, distance}
	end)
	
	if success and result then
		return result[1], result[2], result[3]
	end
	return false, false, 0
end

local function IsHighlightValid(highlightData: HighlightData?): boolean
	if not highlightData or not highlightData.highlight then return false end
	
	local success, isValid = SafeCall(function()
		return highlightData.highlight.Parent ~= nil
	end)
	
	return success and isValid or false
end

local function CreateHighlight(player: Player, character: Model): boolean
	local success = SafeCall(function()
		if RuntimeData.highlightData[player] then
			local oldData = RuntimeData.highlightData[player]
			if oldData.highlight then
				oldData.highlight:Destroy()
			end
		end
		
		local highlight = Instance.new("Highlight")
		highlight.Name = "Chams_" .. player.UserId
		highlight.Adornee = character
		highlight.DepthMode = GetDepthMode()
		highlight.Enabled = true
		highlight.Parent = character
		
		RuntimeData.highlightData[player] = {
			highlight = highlight,
			lastUpdateTick = tick()
		}
		
		return true
	end)
	
	return success
end

local function RemoveHighlight(player: Player)
	SafeCall(function()
		local data = RuntimeData.highlightData[player]
		if data and data.highlight then
			data.highlight:Destroy()
		end
		RuntimeData.highlightData[player] = nil
	end)
	
	local playerConns = RuntimeData.playerConnections[player]
	if playerConns then
		for _, conn in pairs(playerConns) do
			SafeCall(function() conn:Disconnect() end)
		end
		RuntimeData.playerConnections[player] = nil
	end
end

local function UpdateHighlightProperties(highlight: Highlight, fillColor: Color3, outlineColor: Color3)
	highlight.FillColor = fillColor
	highlight.OutlineColor = outlineColor
	highlight.FillTransparency = ChamsConfig.fillTransparency
	highlight.OutlineTransparency = ChamsConfig.outlineTransparency
	highlight.DepthMode = GetDepthMode()
end

local function UpdateHighlight(player: Player)
	local shouldShow, isVisible, distance = GetPlayerStatus(player)
	
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
	
	if not IsHighlightValid(data) then
		if not CreateHighlight(player, character) then
			return
		end
		data = RuntimeData.highlightData[player]
	end
	
	if not data then return end
	
	local fillColor, outlineColor = GetChamsColors(player, isVisible)
	
	SafeCall(function()
		if data.highlight then
			local adornee = data.highlight.Adornee
			if adornee ~= character then
				data.highlight.Adornee = character
			end
			UpdateHighlightProperties(data.highlight, fillColor, outlineColor)
		end
	end)
end

local function RebuildPlayerQueue()
	RuntimeData.playerQueue = {}
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			table.insert(RuntimeData.playerQueue, player)
		end
	end
	RuntimeData.currentQueueIndex = 1
end

local function UpdateBatchChams()
	if not ChamsConfig.enabled then return end
	
	local currentTime = tick()
	local deltaTime = currentTime - RuntimeData.lastUpdate
	
	if deltaTime < ChamsConfig.updateInterval then return end
	RuntimeData.lastUpdate = currentTime
	
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
end

local function SetupPlayerConnections(player: Player)
	if player == LocalPlayer then return end
	
	RuntimeData.playerConnections[player] = {}
	
	RuntimeData.playerConnections[player]["charAdded"] = player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		if player.Parent and ChamsConfig.enabled then
			SafeCall(function()
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
	RuntimeData.connections.heartbeat = RunService.Heartbeat:Connect(UpdateBatchChams)
	
	RuntimeData.connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
		RemoveHighlight(player)
		
		local index = table.find(RuntimeData.playerQueue, player)
		if index then
			table.remove(RuntimeData.playerQueue, index)
			if RuntimeData.currentQueueIndex > #RuntimeData.playerQueue and #RuntimeData.playerQueue > 0 then
				RuntimeData.currentQueueIndex = 1
			end
		end
	end)
	
	RuntimeData.connections.playerAdded = Players.PlayerAdded:Connect(SetupPlayerConnections)
	
	RuntimeData.connections.localCharAdded = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		for player in pairs(RuntimeData.highlightData) do
			RemoveHighlight(player)
		end
		task.wait(0.2)
		RebuildPlayerQueue()
	end)
	
	for _, player in Players:GetPlayers() do
		SetupPlayerConnections(player)
	end
	
	RebuildPlayerQueue()
end

--=============================================================================
-- PUBLIC API
--=============================================================================

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
end

function ChamsAPI:UpdateConfig(newConfig: {[string]: any})
	for key, value in pairs(newConfig) do
		if ChamsConfig[key] ~= nil then
			ChamsConfig[key] = value
		end
	end
end

function ChamsAPI:GetConfig()
	return ChamsConfig
end

function ChamsAPI:Destroy()
	for name, conn in pairs(RuntimeData.connections) do
		SafeCall(function() conn:Disconnect() end)
	end
	RuntimeData.connections = {}
	
	for player, conns in pairs(RuntimeData.playerConnections) do
		for _, conn in pairs(conns) do
			SafeCall(function() conn:Disconnect() end)
		end
	end
	RuntimeData.playerConnections = {}
	
	for player in pairs(RuntimeData.highlightData) do
		RemoveHighlight(player)
	end
	RuntimeData.highlightData = {}
end

--=============================================================================
-- INITIALIZATION
--=============================================================================

InitializeEvents()

return ChamsAPI
