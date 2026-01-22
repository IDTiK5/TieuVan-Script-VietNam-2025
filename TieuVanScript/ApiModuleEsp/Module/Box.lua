local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

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
	
	-- ⭐ NPC CONFIG
	NPCMode = "Both", -- "Players", "NPCs", "Both"
	NPCBoxColor = Color3.fromRGB(255, 100, 0),
	AggressiveNPCDetection = true,
}

local playerGui = player:WaitForChild("PlayerGui")
local mainScreenGui = Instance.new("ScreenGui")
mainScreenGui.Name = "BoxESP"
mainScreenGui.ResetOnSpawn = false
mainScreenGui.Parent = playerGui

local espBoxes = {}
local gradientAnimationConnection = nil
local rotationOffset = 0
local NPCCache = {}
local PlayerCache = {}
local LastCacheUpdate = 0
local CacheUpdateInterval = 2

-- ⭐ DANH SÁCH TAG NPC
local NPCTags = {
	"NPC", "Npc", "npc", "Enemy", "enemy", "Enemies", "enemies",
	"Hostile", "hostile", "Bad", "bad", "BadGuy", "badguy",
	"Foe", "foe", "Opponent", "opponent", "Bot", "bot", "Bots", "bots",
	"Mob", "mob", "Mobs", "mobs", "Monster", "monster", "Monsters", "monsters",
	"Zombie", "zombie", "Zombies", "zombies", "Creature", "creature",
	"Animal", "animal", "Beast", "beast", "Villain", "villain",
	"Boss", "boss", "MiniBoss", "miniboss", "Guard", "guard",
	"Guardian", "guardian", "Soldier", "soldier", "Warrior", "warrior",
	"Fighter", "fighter", "Target", "target", "Dummy", "dummy",
	"Dummies", "dummies", "Skeleton", "skeleton", "Orc", "orc",
	"Goblin", "goblin", "Robot", "robot", "Drone", "drone",
	"Android", "android", "Cyborg", "cyborg", "Automaton", "automaton",
	"Servant", "servant", "Minion", "minion", "Slave", "slave", "Pawn", "pawn",
	"AI", "ai", "A.I.", "Char", "char", "Character", "character",
	"Model", "model", "Event", "event", "Special", "special",
}

--=============================================================================
-- ⭐ NPC DETECTION FUNCTIONS
--=============================================================================

local function IsPlayer(character)
	if not character or not character:IsA("Model") then return false end
	if character == player.Character then return true end
	local foundPlayer = Players:GetPlayerFromCharacter(character)
	return foundPlayer ~= nil
end

local function IsNPC(character)
	if not character or not character:IsA("Model") then return false end
	if IsPlayer(character) then return false end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not head or not hrp or humanoid.Health <= 0 then return false end
	
	if CONFIG.AggressiveNPCDetection then return true end
	
	local charName = character.Name:lower()
	for _, tag in pairs(NPCTags) do
		if charName:find(tag:lower(), 1, true) then return true end
	end
	
	local npcFolders = {"NPCs", "Enemies", "Bots", "Mobs", "Targets", "Enemy", "Hostile",
		"Monsters", "Zombies", "Creatures", "Characters", "Spawns", "EnemySpawns", "NPCSpawns", "Bosses", "Minions"}
	
	for _, folderName in pairs(npcFolders) do
		local folder = workspace:FindFirstChild(folderName)
		if folder and character:IsDescendantOf(folder) then return true end
	end
	
	return true
end

local function FindNPCsInWorkspaceRecursive(parent)
	local foundNPCs = {}
	for _, child in pairs(parent:GetChildren()) do
		if child:IsA("Model") and IsNPC(child) then
			table.insert(foundNPCs, child)
		end
		if not child:IsA("BasePart") and not child:IsA("Decal") and not child:IsA("Texture") then
			local subNPCs = FindNPCsInWorkspaceRecursive(child)
			for _, npc in pairs(subNPCs) do
				table.insert(foundNPCs, npc)
			end
		end
	end
	return foundNPCs
end

local function UpdateCaches()
	local currentTime = tick()
	if currentTime - LastCacheUpdate < CacheUpdateInterval then return end
	LastCacheUpdate = currentTime
	
	NPCCache = {}
	PlayerCache = {}
	
	-- Tìm NPCs
	local allModels = {}
	for _, model in pairs(workspace:GetChildren()) do
		if model:IsA("Model") and model ~= player.Character then
			table.insert(allModels, model)
		end
	end
	
	local npcFolders = {"NPCs", "Enemies", "Bots", "Mobs", "Targets", "Characters", "Spawns", "Monsters", "Zombies", "Enemy", "Hostile", "Bosses", "Minions"}
	for _, folderName in pairs(npcFolders) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			local npcsInFolder = FindNPCsInWorkspaceRecursive(folder)
			for _, npc in pairs(npcsInFolder) do
				table.insert(allModels, npc)
			end
		end
	end
	
	for _, model in pairs(allModels) do
		local hrp = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		
		if hrp and humanoid and humanoid.Health > 0 then
			if IsPlayer(model) then
				PlayerCache[model] = {Model = model, HRP = hrp, Humanoid = humanoid, Player = Players:GetPlayerFromCharacter(model), IsNPC = false}
			elseif IsNPC(model) then
				NPCCache[model] = {Model = model, HRP = hrp, Humanoid = humanoid, IsNPC = true}
			end
		end
	end
	
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local char = p.Character
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if hrp and humanoid and humanoid.Health > 0 then
				PlayerCache[char] = {Model = char, HRP = hrp, Humanoid = humanoid, Player = p, IsNPC = false}
			end
		end
	end
end

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

local function getBoxColor(target, isSelf, isNPC)
	if isSelf then
		if CONFIG.UseTeamColors then
			return getPlayerTeamColor(player) or CONFIG.SelfBoxColor
		end
		return CONFIG.SelfBoxColor
	end
	
	-- ⭐ MÀU CHO NPC
	if isNPC then
		return CONFIG.NPCBoxColor
	end
	
	if not CONFIG.UseTeamColors then
		return CONFIG.BoxColor
	end
	
	if CONFIG.UseActualTeamColors then
		local teamColor = getPlayerTeamColor(target)
		if teamColor then
			return teamColor
		else
			return CONFIG.NoTeamColor
		end
	else
		local isEnemyPlayer = isEnemy(target)
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
	for target, espData in pairs(espBoxes) do
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
	for target, espData in pairs(espBoxes) do
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
	
	rotationOffset = 0
	gradientAnimationConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not CONFIG.EnableGradientAnimation then
			if gradientAnimationConnection then
				gradientAnimationConnection:Disconnect()
				gradientAnimationConnection = nil
			end
			return
		end
		
		rotationOffset = (rotationOffset + deltaTime * CONFIG.GradientAnimationSpeed * 100) % 360
		
		for target, espData in pairs(espBoxes) do
			if espData and espData.UIGradient then
				espData.UIGradient.Rotation = (CONFIG.GradientRotation + rotationOffset) % 360
			end
		end
	end)
end

local function stopGradientAnimation()
	if gradientAnimationConnection then
		gradientAnimationConnection:Disconnect()
		gradientAnimationConnection = nil
	end
	
	for target, espData in pairs(espBoxes) do
		if espData and espData.UIGradient then
			espData.UIGradient.Rotation = CONFIG.GradientRotation
		end
	end
end

local function createEspBox(target, isNPC)
	if espBoxes[target] then return end
	
	local Box = Instance.new("Frame", mainScreenGui)
	Box.Name = "Box_" .. target.Name
	Box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Box.BackgroundTransparency = 1
	Box.BorderSizePixel = 0
	
	local UIStroke = Instance.new("UIStroke", Box)
	UIStroke.Thickness = CONFIG.BoxThickness
	UIStroke.Color = isNPC and CONFIG.NPCBoxColor or CONFIG.BoxColor
	UIStroke.LineJoinMode = Enum.LineJoinMode.Miter
	
	local InnerBorder = Instance.new("Frame", Box)
	InnerBorder.Name = "Inner border"
	InnerBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	InnerBorder.BackgroundTransparency = 1
	InnerBorder.BorderSizePixel = 0
	InnerBorder.ZIndex = 99
	
	local InnerUIStroke = Instance.new("UIStroke", InnerBorder)
	InnerUIStroke.Thickness = CONFIG.InnerThickness
	InnerUIStroke.Color = isNPC and CONFIG.NPCBoxColor or CONFIG.BoxColor
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
	
	espBoxes[target] = {
		Box = Box,
		InnerBorder = InnerBorder,
		UIStroke = UIStroke,
		InnerUIStroke = InnerUIStroke,
		BoxGradient = BoxGradient,
		UIGradient = UIGradient,
		IsNPC = isNPC
	}
	
	return espBoxes[target]
end

local function updateEspBox(target, espData)
	if not espData or not espData.Box then return end
	if not target or not target:IsDescendantOf(workspace) then
		espData.Box.Visible = false
		return
	end
	
	local humanoidRootPart = target:FindFirstChild("HumanoidRootPart")
	local humanoid = target:FindFirstChild("Humanoid")
	
	if not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
		espData.Box.Visible = false
		return
	end
	
	-- ⭐ KIỂM TRA TEAM CHO PLAYER
	if not espData.IsNPC then
		local targetPlayer = Players:GetPlayerFromCharacter(target)
		if targetPlayer then
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
		end
	end
	
	local charSize = target:GetExtentsSize()
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
	
	local boxColor = getBoxColor(target, false, espData.IsNPC)
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

local function removeEspBox(target)
	if espBoxes[target] then
		espBoxes[target].Box:Destroy()
		espBoxes[target] = nil
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
		UIGradient = UIGradient,
		IsNPC = false
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
	
	local boxColor = getBoxColor(player, true, false)
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
	UpdateCaches()
	
	for targetChar, espData in pairs(espBoxes) do
		if targetChar and targetChar:IsDescendantOf(workspace) and espData then
			if targetChar == player then
				continue
			end
			
			if CONFIG.Enabled then
				local isNPC = espData.IsNPC
				
				-- Kiểm tra mode
				if CONFIG.NPCMode == "Players" and isNPC then
					espData.Box.Visible = false
				elseif CONFIG.NPCMode == "NPCs" and not isNPC then
					espData.Box.Visible = false
				else
					-- Kiểm tra player team nếu không phải NPC
					if not isNPC then
						local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
						if targetPlayer and not shouldShowPlayer(targetPlayer) then
							espData.Box.Visible = false
						else
							updateEspBox(targetChar, espData)
						end
					else
						updateEspBox(targetChar, espData)
					end
				end
			else
				espData.Box.Visible = false
			end
		else
			removeEspBox(targetChar)
		end
	end
end

--=============================================================================
-- EVENT HANDLERS
--=============================================================================

local function onPlayerAdded(newPlayer)
	if newPlayer ~= player then
		wait(0.5)
		if CONFIG.NPCMode == "Players" or CONFIG.NPCMode == "Both" then
			if shouldShowPlayer(newPlayer) then
				createEspBox(newPlayer, false)
			end
		end
	end
end

local function onPlayerRemoving(leavingPlayer)
	removeEspBox(leavingPlayer.Character or leavingPlayer)
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

-- ⭐ TẠO NPC BOX KHI CÓ NPC MỚI
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") and IsNPC(descendant) then
		wait(0.1)
		if not espBoxes[descendant] then
			createEspBox(descendant, true)
		end
	end
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
	
	if newConfig.EnableGradientAnimation ~= nil then
		if newConfig.EnableGradientAnimation then
			startGradientAnimation()
		else
			stopGradientAnimation()
		end
	end
end

function BoxESPAPI:GetConfig()
	return CONFIG
end

function BoxESPAPI:Toggle(state)
	CONFIG.Enabled = state
end

function BoxESPAPI
