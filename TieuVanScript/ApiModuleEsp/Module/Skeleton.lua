local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	Enabled = false,
	SkeletonColor = Color3.fromRGB(255, 255, 255),
	SkeletonThickness = 1,
	SkeletonTransparency = 1,
	
	EnableTeamCheck = false,
	ShowEnemyOnly = false,
	ShowAlliedOnly = false,
	
	UseTeamColors = false,
	UseActualTeamColors = true,
	EnemySkeletonColor = Color3.fromRGB(255, 0, 0),
	AlliedSkeletonColor = Color3.fromRGB(0, 255, 0),
	NoTeamColor = Color3.fromRGB(255, 255, 255),
}

local linePool = {}
local poolSize = 0
local MAX_POOL_SIZE = 500

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
	
	if not LocalPlayer.Team then
		if not targetPlayer.Team then return false end
		return true
	end
	
	if not targetPlayer.Team then return true end
	
	return LocalPlayer.Team ~= targetPlayer.Team
end

local function shouldShowPlayer(targetPlayer)
	if not CONFIG.EnableTeamCheck then return true end
	local isEnemyPlayer = isEnemy(targetPlayer)
	if CONFIG.ShowEnemyOnly and not isEnemyPlayer then return false end
	if CONFIG.ShowAlliedOnly and isEnemyPlayer then return false end
	return true
end

local function getSkeletonColor(targetPlayer)
	if not CONFIG.UseTeamColors then
		return CONFIG.SkeletonColor
	end
	
	if CONFIG.UseActualTeamColors then
		local teamColor = getPlayerTeamColor(targetPlayer)
		return teamColor or CONFIG.NoTeamColor
	else
		return isEnemy(targetPlayer) and CONFIG.EnemySkeletonColor or CONFIG.AlliedSkeletonColor
	end
end

--=============================================================================
-- LINE POOL MANAGEMENT
--=============================================================================

local function getLine()
	if poolSize > 0 then
		local line = linePool[poolSize]
		linePool[poolSize] = nil
		poolSize = poolSize - 1
		return line
	end
	
	local success, line = pcall(function()
		return Drawing.new("Line")
	end)
	
	return success and line or nil
end

local function returnLine(line)
	if not line then return end
	
	pcall(function()
		line.Visible = false
	end)
	
	if poolSize < MAX_POOL_SIZE then
		poolSize = poolSize + 1
		linePool[poolSize] = line
	else
		pcall(function()
			line:Remove()
		end)
	end
end

--=============================================================================
-- SKELETON DRAWING
--=============================================================================

local function drawSkeleton(player)
	if not CONFIG.Enabled or not shouldShowPlayer(player) then return end
	
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	
	local skeletonColor = getSkeletonColor(player)
	
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("Motor6D") then
			local part0 = part.Part0
			local part1 = part.Part1
			
			if part0 and part1 then
				local p0 = camera:WorldToViewportPoint(part0.Position)
				local p1 = camera:WorldToViewportPoint(part1.Position)
				
				if p0.Z > 0 and p1.Z > 0 then
					local line = getLine()
					if line then
						pcall(function()
							line.From = Vector2.new(p0.X, p0.Y)
							line.To = Vector2.new(p1.X, p1.Y)
							line.Color = skeletonColor
							line.Thickness = CONFIG.SkeletonThickness
							line.Transparency = CONFIG.SkeletonTransparency
							line.Visible = true
						end)
						
						task.delay(1/60, function()
							returnLine(line)
						end)
					end
				end
			end
		end
	end
end

local function updateSkeleton()
	if not CONFIG.Enabled then return end
	
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			drawSkeleton(player)
		end
	end
end

--=============================================================================
-- INITIALIZATION
--=============================================================================

RunService.RenderStepped:Connect(updateSkeleton)

--=============================================================================
-- PUBLIC API
--=============================================================================

local SkeletonESPAPI = {}

function SkeletonESPAPI:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if CONFIG[key] ~= nil then
			CONFIG[key] = value
		end
	end
end

function SkeletonESPAPI:GetConfig()
	return CONFIG
end

function SkeletonESPAPI:Toggle(state)
	CONFIG.Enabled = state
end

function SkeletonESPAPI:Destroy()
	for i = 1, poolSize do
		if linePool[i] then
			pcall(function()
				linePool[i]:Remove()
			end)
			linePool[i] = nil
		end
	end
	poolSize = 0
end

return SkeletonESPAPI
