local Services = {
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	Workspace = game:GetService("Workspace"),
	UserInputService = game:GetService("UserInputService"),
	HttpService = game:GetService("HttpService")
}

local ESP = {
	config = {
		enabled = false,
		box3D = false,
		boxFilled = false,
		boxOutline = false,
		cornerBox = false,
		dynamicBox = false,
		teamFilter = false,
		teamFilterMode = "standard",
		raycastCheck = false,
		fadeWhenBlocked = false,
		distanceFade = false,
		colorMode = "Static",
		maxDistance = 10000,
		boxColor = Color3.fromRGB(255, 255, 255),
		outlineColor = Color3.fromRGB(255, 255, 255),
		thickness = 1.5,
		outlineThickness = 3,
		transparency = 1,
		cornerLength = 0.25,
		fillTransparency = 0.8,
		updateRate = 1,
		rainbowSpeed = 1,
		maxPlayersPerFrame = 10,
		raycastCacheDuration = 0.1,
		poolCleanupInterval = 30,
		enableErrorRecovery = true,
		debugMode = false
	},
	
	cache = {},
	pools = {
		line = {},
		quad = {},
		count = {line = 0, quad = 0},
		lastCleanup = 0,
		lastGlobalUse = 0
	},
	maxPool = 400,
	
	rainbowHue = 0,
	frameSkip = 0,
	connections = {},
	localPlayer = Services.Players.LocalPlayer,
	currentBoxType = "2D Box",
	
	validationData = {},
	validationTime = {},
	
	raycastCache = {},
	raycastCacheLastClean = 0,
	
	updateQueue = {},
	currentQueueIndex = 1,
	lastQueueBuild = 0,
	queueBuildInterval = 0.5,
	playerCount = 0,
	
	queueDirty = true,
	needsResort = true,
	lastFullSortTime = 0,
	fullSortInterval = 2.0,
	
	errorCount = 0,
	firstErrorTime = 0,
	maxErrorsBeforeDisable = 10,
	errorWindowDuration = 5,
	
	VALIDATION_CACHE_DURATION = 0.05,
	RAYCAST_CACHE_DURATION = 0.1,
	RAYCAST_GRID_SIZE = 3

}

local function safeCall(func, ...)
	local success, result = pcall(func, ...)
	if success then
		return result
	end
	return nil
end

local function safeDrawingNew(drawingType)
	local success, drawing = pcall(Drawing.new, drawingType)
	if success and drawing then
		return drawing
	end
	return nil
end

local function safeSetProperty(drawing, property, value)
	if not drawing then return false end
	local success = pcall(function()
		drawing[property] = value
	end)
	return success
end

function ESP:Log(message, level)
	if not self.config.debugMode then return end
	local prefix = level == "error" and "[ESP ERROR]" or "[ESP]"
	print(prefix, message)
end

function ESP:HandleError(errorMessage, context)
	local currentTime = tick()
	
	if self.errorCount == 0 then
		self.firstErrorTime = currentTime
	end
	
	self.errorCount = self.errorCount + 1
	
	self:Log(string.format("Error in %s: %s", context or "unknown", errorMessage), "error")
	
	if self.config.enableErrorRecovery then
		if currentTime - self.firstErrorTime > self.errorWindowDuration then
			self.errorCount = 1
			self.firstErrorTime = currentTime
		elseif self.errorCount > self.maxErrorsBeforeDisable then
			self:Log("Too many errors, temporarily disabling ESP", "error")
			self.config.enabled = false
			task.delay(5, function()
				self.errorCount = 0
				self.firstErrorTime = 0
				self.config.enabled = true
				self:Log("ESP re-enabled after cooldown")
			end)
		end
	end
end

function ESP:GetCamera()
	local camera = Services.Workspace.CurrentCamera
	if camera then
		return camera
	end
	return safeCall(function()
		return Services.Workspace:WaitForChild("Camera", 1)
	end)
end

function ESP:CleanupPools()
	local currentTime = tick()
	
	if currentTime - self.pools.lastCleanup < self.config.poolCleanupInterval then
		return
	end
	
	if currentTime - self.pools.lastGlobalUse > self.config.poolCleanupInterval then
		for poolType, pool in pairs({line = self.pools.line, quad = self.pools.quad}) do
			local targetSize = math.ceil(self.pools.count[poolType] * 0.5)
			
			while self.pools.count[poolType] > targetSize do
				local idx = self.pools.count[poolType]
				local drawing = pool[idx]
				if drawing then
					pcall(function() drawing:Remove() end)
				end
				pool[idx] = nil
				self.pools.count[poolType] = idx - 1
			end
		end
		
		self:Log(string.format("Pool cleanup complete. Line: %d, Quad: %d", 
			self.pools.count.line, self.pools.count.quad))
	end
	
	self.pools.lastCleanup = currentTime
end

function ESP:GetDrawing(drawingType)
	local pool = self.pools[drawingType]
	local count = self.pools.count[drawingType]
	
	self.pools.lastGlobalUse = tick()
	
	if count > 0 then
		local drawingObject = pool[count]
		pool[count] = nil
		self.pools.count[drawingType] = count - 1
		
		if drawingObject then
			safeSetProperty(drawingObject, "Visible", false)
			return drawingObject
		end
	end
	
	local drawingObject
	if drawingType == "quad" then
		drawingObject = safeDrawingNew("Quad")
	else
		drawingObject = safeDrawingNew("Line")
		if drawingObject then
			safeSetProperty(drawingObject, "Thickness", self.config.thickness)
		end
	end
	
	return drawingObject
end

function ESP:ReturnDrawing(drawingObject, drawingType)
	if not drawingObject then return end
	
	local pool = self.pools[drawingType]
	local count = self.pools.count[drawingType]
	
	safeSetProperty(drawingObject, "Visible", false)
	
	if count < self.maxPool then
		count = count + 1
		pool[count] = drawingObject
		self.pools.count[drawingType] = count
	else
		pcall(function() drawingObject:Remove() end)
	end
end

function ESP:GetCachedValidation(player)
	local cachedTime = self.validationTime[player]
	if not cachedTime then
		return nil, true
	end
	
	local currentTime = tick()
	if currentTime - cachedTime >= self.VALIDATION_CACHE_DURATION then
		return nil, true
	end
	
	return self.validationData[player], false
end

function ESP:SetCachedValidation(player, result)
	self.validationData[player] = result
	self.validationTime[player] = tick()
end

function ESP:ClearValidationCache(player)
	self.validationData[player] = nil
	self.validationTime[player] = nil
end

function ESP:ValidatePlayer(player)
	local cached, needsRefresh = self:GetCachedValidation(player)
	if not needsRefresh then
		return cached
	end
	
	local result = self:DoValidatePlayer(player)
	self:SetCachedValidation(player, result)
	return result
end

function ESP:DoValidatePlayer(player)
	if player == self.localPlayer or not self.config.enabled then
		return nil
	end
	
	local character = player.Character
	if not character or not character.Parent then
		return nil
	end
	
	local humanoidRootPart, humanoid, head
	
	local success = pcall(function()
		humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		humanoid = character:FindFirstChild("Humanoid")
		head = character:FindFirstChild("Head")
	end)
	
	if not success or not humanoidRootPart or not humanoid or not head then
		return nil
	end
	
	local health = 0
	pcall(function()
		health = humanoid.Health
	end)
	
	if health <= 0 then
		return nil
	end
	
	local localCharacter = self.localPlayer.Character
	if not localCharacter then
		return nil
	end
	
	local localHumanoidRootPart = localCharacter:FindFirstChild("HumanoidRootPart")
	if not localHumanoidRootPart then
		return nil
	end
	
	local distance
	local distanceSuccess = pcall(function()
		distance = (humanoidRootPart.Position - localHumanoidRootPart.Position).Magnitude
	end)
	
	if not distanceSuccess or not distance or distance > self.config.maxDistance then
		return nil
	end
	
	if self.config.teamFilter then
		local isSameTeam = false
		
		pcall(function()
			if self.config.teamFilterMode == "standard" then
				if player.Team and player.Team == self.localPlayer.Team then
					isSameTeam = true
				end
			else
				if player.Team and player.Team == self.localPlayer.Team then
					isSameTeam = true
				end
				
				if not isSameTeam then
					local playerTeamAttr = character:GetAttribute("Team")
					local localTeamAttr = localCharacter:GetAttribute("Team")
					
					if playerTeamAttr and playerTeamAttr == localTeamAttr then
						isSameTeam = true
					end
				end
			end
		end)
		
		if isSameTeam then
			return nil
		end
	end
	
	return {
		char = character,
		root = humanoidRootPart,
		hum = humanoid,
		head = head,
		dist = distance,
		localRoot = localHumanoidRootPart
	}
end

function ESP:GetRaycastCacheKey(targetPosition)
	local gridSize = self.RAYCAST_GRID_SIZE
	local keyX = math.floor(targetPosition.X / gridSize)
	local keyY = math.floor(targetPosition.Y / gridSize)
	local keyZ = math.floor(targetPosition.Z / gridSize)
	return keyX * 1000000 + keyY * 1000 + keyZ --[[string.format("%d_%d_%d", keyX, keyY, keyZ)]]--
end

function ESP:CleanupRaycastCache()
	local currentTime = tick()
	if currentTime - self.raycastCacheLastClean < self.config.raycastCacheDuration * 2 then
		return
	end
	
	local threshold = currentTime - self.config.raycastCacheDuration * 2
	local newCache = {}
	
	for key, entry in pairs(self.raycastCache) do
		if entry.time > threshold then
			newCache[key] = entry
		end
	end
	
	self.raycastCache = newCache
	self.raycastCacheLastClean = currentTime
end

function ESP:IsBlocked(targetPosition, targetCharacter, originPosition)
	if not self.config.raycastCheck then
		return false
	end
	
	local currentTime = tick()
	local cacheKey = self:GetRaycastCacheKey(targetPosition)
	
	local cached = self.raycastCache[cacheKey]
	if cached and currentTime - cached.time < self.config.raycastCacheDuration then
		return cached.blocked
	end
	
	local isBlocked = false
	
	local success = pcall(function()
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {self.localPlayer.Character, targetCharacter}
		
		local direction = targetPosition - originPosition
		local raycastResult = Services.Workspace:Raycast(originPosition, direction, raycastParams)
		
		if raycastResult then
			local hitDistance = (raycastResult.Position - originPosition).Magnitude
			local targetDistance = direction.Magnitude
			isBlocked = hitDistance < targetDistance * 0.95
		end
	end)
	
	if success then
		self.raycastCache[cacheKey] = {
			blocked = isBlocked,
			time = currentTime
		}
	end
	
	if math.random() < 0.02 then
		self:CleanupRaycastCache()
	end
	
	return isBlocked
end

function ESP:Calc2DBox(playerData)
	local camera = self:GetCamera()
	if not camera then
		return nil
	end
	
	local boxData
	
	local success = pcall(function()
		local headSize = playerData.head.Size
		local topPosition = playerData.head.Position + Vector3.new(0, headSize.Y / 2 + 0.5, 0)
		local bottomPosition = playerData.root.Position - Vector3.new(0, 3, 0)
		
		local topScreenPosition = camera:WorldToViewportPoint(topPosition)
		local bottomScreenPosition = camera:WorldToViewportPoint(bottomPosition)
		local centerScreenPosition = camera:WorldToViewportPoint(playerData.root.Position)
		
		if topScreenPosition.Z <= 0 or bottomScreenPosition.Z <= 0 then
			return
		end
		
		local boxHeight = math.abs(topScreenPosition.Y - bottomScreenPosition.Y)
		local boxWidth = boxHeight * (self.config.dynamicBox and 0.65 or 0.6)
		
		boxHeight = math.clamp(boxHeight, 10, 1000)
		boxWidth = math.clamp(boxWidth, 6, 650)
		
		local centerX = centerScreenPosition.X
		local halfWidth = boxWidth / 2
		
		boxData = {
			tl = Vector2.new(centerX - halfWidth, topScreenPosition.Y),
			tr = Vector2.new(centerX + halfWidth, topScreenPosition.Y),
			bl = Vector2.new(centerX - halfWidth, bottomScreenPosition.Y),
			br = Vector2.new(centerX + halfWidth, bottomScreenPosition.Y),
			w = boxWidth,
			h = boxHeight
		}
	end)
	
	return success and boxData or nil
end

function ESP:Calc3DBox(character)
	local camera = self:GetCamera()
	if not camera then
		return nil
	end
	
	local screenCorners
	
	local success = pcall(function()
		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		local foundParts = false
		
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 then
				local partPosition = part.Position
				local partSize = part.Size
				
				if partSize.Magnitude < 100 then
					foundParts = true
					local halfX, halfY, halfZ = partSize.X / 2, partSize.Y / 2, partSize.Z / 2
					
					minX = math.min(minX, partPosition.X - halfX)
					maxX = math.max(maxX, partPosition.X + halfX)
					minY = math.min(minY, partPosition.Y - halfY)
					maxY = math.max(maxY, partPosition.Y + halfY)
					minZ = math.min(minZ, partPosition.Z - halfZ)
					maxZ = math.max(maxZ, partPosition.Z + halfZ)
				end
			end
		end
		
		if not foundParts then
			return
		end
		
		local sizeX, sizeY, sizeZ = maxX - minX, maxY - minY, maxZ - minZ
		local boundsSize = math.sqrt(sizeX * sizeX + sizeY * sizeY + sizeZ * sizeZ)
		
		if boundsSize > 50 or boundsSize < 0.1 then
			return
		end
		
		local worldCorners = {
			Vector3.new(minX, minY, minZ),
			Vector3.new(maxX, minY, minZ),
			Vector3.new(maxX, minY, maxZ),
			Vector3.new(minX, minY, maxZ),
			Vector3.new(minX, maxY, minZ),
			Vector3.new(maxX, maxY, minZ),
			Vector3.new(maxX, maxY, maxZ),
			Vector3.new(minX, maxY, maxZ)
		}
		
		screenCorners = {}
		
		for cornerIndex, worldCorner in ipairs(worldCorners) do
			local screenPosition = camera:WorldToViewportPoint(worldCorner)
			
			if screenPosition.Z <= 0 then
				screenCorners = nil
				return
			end
			
			screenCorners[cornerIndex] = Vector2.new(screenPosition.X, screenPosition.Y)
		end
	end)
	
	return success and screenCorners or nil
end

function ESP:LerpColor(colorStart, colorEnd, t)
	t = math.clamp(t, 0, 1)
	return Color3.new(
		colorStart.R + (colorEnd.R - colorStart.R) * t,
		colorStart.G + (colorEnd.G - colorStart.G) * t,
		colorStart.B + (colorEnd.B - colorStart.B) * t
	)
end

function ESP:GetColor(playerData, player)
	local colorMode = self.config.colorMode
	
	if colorMode == "Rainbow" then
		return Color3.fromHSV(self.rainbowHue, 1, 1)
	end
	
	if colorMode == "Health" then
		local healthRatio = 1
		pcall(function()
			healthRatio = math.clamp(playerData.hum.Health / playerData.hum.MaxHealth, 0, 1)
		end)
		return self:LerpColor(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), healthRatio)
	end
	
	if colorMode == "Team" then
		local teamColor
		pcall(function()
			if player.Team then
				teamColor = player.Team.TeamColor.Color
			end
		end)
		return teamColor or self.config.boxColor
	end
	
	if colorMode == "Distance" then
		local distanceRatio = math.clamp(playerData.dist / self.config.maxDistance, 0, 1)
		return self:LerpColor(Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 0, 0), distanceRatio)
	end
	
	return self.config.boxColor
end

function ESP:GetTrans(playerData, isBlocked)
	local baseTransparency = self.config.transparency
	
	if self.config.fadeWhenBlocked and isBlocked then
		baseTransparency = baseTransparency * 0.4
	end
	
	if self.config.distanceFade and self.config.maxDistance > 0 then
		local distanceRatio = math.clamp(playerData.dist / self.config.maxDistance, 0, 1)
		local fadeMultiplier = 1 - (distanceRatio * 0.5)
		baseTransparency = baseTransparency * fadeMultiplier
	end
	
	return math.clamp(baseTransparency, 0, 1)
end

function ESP:ClearCache(playerCache)
	if not playerCache then return end
	
	local lines = playerCache.lines
	if lines then
		for i = 1, #lines do
			local lineObject = lines[i]
			if lineObject then
				safeSetProperty(lineObject, "Visible", false)
				self:ReturnDrawing(lineObject, "line")
				lines[i] = nil
			end
		end
	end
	
	if playerCache.quad then
		safeSetProperty(playerCache.quad, "Visible", false)
		self:ReturnDrawing(playerCache.quad, "quad")
		playerCache.quad = nil
	end
	
	playerCache.lineCount = 0
	playerCache.nextLineIndex = 1
end

function ESP:EnsureLine(playerCache, index)
	if not playerCache.lines then
		playerCache.lines = {}
	end
	
	local existingLine = playerCache.lines[index]
	if existingLine then
		return existingLine
	end
	
	local newLine = self:GetDrawing("line")
	if newLine then
		playerCache.lines[index] = newLine
		return newLine
	end
	
	return nil
end

function ESP:DrawLines(playerCache, linePoints, lineColor, lineTransparency, lineThickness)
	local lineIndex = playerCache.nextLineIndex or 1
	local pointCount = #linePoints
	
	for pointIndex = 1, pointCount, 2 do
		local startPoint = linePoints[pointIndex]
		local endPoint = linePoints[pointIndex + 1]
		
		if startPoint and endPoint then
			local lineObject = self:EnsureLine(playerCache, lineIndex)
			
			if lineObject then
				safeSetProperty(lineObject, "From", startPoint)
				safeSetProperty(lineObject, "To", endPoint)
				safeSetProperty(lineObject, "Color", lineColor)
				safeSetProperty(lineObject, "Thickness", lineThickness)
				safeSetProperty(lineObject, "Transparency", lineTransparency)
				safeSetProperty(lineObject, "Visible", true)
				lineIndex = lineIndex + 1
			end
		end
	end
	
	playerCache.nextLineIndex = lineIndex
end

function ESP:Draw2DBox(playerCache, boxData, boxColor, boxTransparency)
	playerCache.nextLineIndex = 1
	
	local boxEdges = {
		boxData.tl, boxData.tr,
		boxData.tr, boxData.br,
		boxData.br, boxData.bl,
		boxData.bl, boxData.tl
	}
	
	if self.config.boxOutline then
		self:DrawLines(playerCache, boxEdges, self.config.outlineColor, boxTransparency, self.config.outlineThickness)
	end
	
	self:DrawLines(playerCache, boxEdges, boxColor, boxTransparency, self.config.thickness)
	
	if self.config.boxFilled then
		if not playerCache.quad then
			playerCache.quad = self:GetDrawing("quad")
		end
		
		if playerCache.quad then
			safeSetProperty(playerCache.quad, "PointA", boxData.tl)
			safeSetProperty(playerCache.quad, "PointB", boxData.tr)
			safeSetProperty(playerCache.quad, "PointC", boxData.br)
			safeSetProperty(playerCache.quad, "PointD", boxData.bl)
			safeSetProperty(playerCache.quad, "Color", boxColor)
			safeSetProperty(playerCache.quad, "Transparency", 1 - self.config.fillTransparency)
			safeSetProperty(playerCache.quad, "Filled", true)
			safeSetProperty(playerCache.quad, "Visible", true)
		end
	elseif playerCache.quad then
		safeSetProperty(playerCache.quad, "Visible", false)
	end
	
	playerCache.lineCount = playerCache.nextLineIndex - 1
end

function ESP:DrawCornerBox(playerCache, boxData, boxColor, boxTransparency)
	playerCache.nextLineIndex = 1
	
	local cornerLengthRatio = self.config.cornerLength
	local cornerWidth = boxData.w * cornerLengthRatio
	local cornerHeight = boxData.h * cornerLengthRatio
	
	local cornerPoints = {
		boxData.tl, Vector2.new(boxData.tl.X + cornerWidth, boxData.tl.Y),
		boxData.tl, Vector2.new(boxData.tl.X, boxData.tl.Y + cornerHeight),
		boxData.tr, Vector2.new(boxData.tr.X - cornerWidth, boxData.tr.Y),
		boxData.tr, Vector2.new(boxData.tr.X, boxData.tr.Y + cornerHeight),
		boxData.bl, Vector2.new(boxData.bl.X + cornerWidth, boxData.bl.Y),
		boxData.bl, Vector2.new(boxData.bl.X, boxData.bl.Y - cornerHeight),
		boxData.br, Vector2.new(boxData.br.X - cornerWidth, boxData.br.Y),
		boxData.br, Vector2.new(boxData.br.X, boxData.br.Y - cornerHeight)
	}
	
	if self.config.boxOutline then
		self:DrawLines(playerCache, cornerPoints, self.config.outlineColor, boxTransparency, self.config.outlineThickness)
	end
	
	self:DrawLines(playerCache, cornerPoints, boxColor, boxTransparency, self.config.thickness)
	
	playerCache.lineCount = playerCache.nextLineIndex - 1
end

function ESP:Draw3DBox(playerCache, screenCorners, boxColor, boxTransparency)
	playerCache.nextLineIndex = 1
	
	local linePoints = {
		screenCorners[1], screenCorners[2],
		screenCorners[2], screenCorners[3],
		screenCorners[3], screenCorners[4],
		screenCorners[4], screenCorners[1],
		screenCorners[5], screenCorners[6],
		screenCorners[6], screenCorners[7],
		screenCorners[7], screenCorners[8],
		screenCorners[8], screenCorners[5],
		screenCorners[1], screenCorners[5],
		screenCorners[2], screenCorners[6],
		screenCorners[3], screenCorners[7],
		screenCorners[4], screenCorners[8]
	}
	
	if self.config.boxOutline then
		self:DrawLines(playerCache, linePoints, self.config.outlineColor, boxTransparency, self.config.outlineThickness)
	end
	
	self:DrawLines(playerCache, linePoints, boxColor, boxTransparency, self.config.thickness)
	
	playerCache.lineCount = playerCache.nextLineIndex - 1
end

function ESP:UpdatePlayer(player)
	local success, errorMsg = pcall(function()
		local playerData = self:ValidatePlayer(player)
		
		if not playerData then
			self:HidePlayer(player)
			return
		end
		
		if not self.cache[player] then
			self.cache[player] = {
				lines = {},
				lineCount = 0,
				quad = nil,
				nextLineIndex = 1,
				lastBoxType = nil,
				lastUpdate = 0
			}
		end
		
		local playerCache = self.cache[player]
		local currentBoxType = self.config.box3D and "3D" or (self.config.cornerBox and "Corner" or "2D")
		
		if playerCache.lastBoxType and playerCache.lastBoxType ~= currentBoxType then
			self:ClearCache(playerCache)
			self.cache[player] = {
				lines = {},
				lineCount = 0,
				quad = nil,
				nextLineIndex = 1,
				lastBoxType = currentBoxType,
				lastUpdate = tick()
			}
			playerCache = self.cache[player]
		end
		
		playerCache.lastBoxType = currentBoxType
		playerCache.lastUpdate = tick()
		
		local isBlocked = self:IsBlocked(playerData.root.Position, playerData.char, playerData.localRoot.Position)
		
		if isBlocked and not self.config.fadeWhenBlocked then
			self:HidePlayer(player)
			return
		end
		
		local boxData
		if self.config.box3D then
			boxData = self:Calc3DBox(playerData.char)
		else
			boxData = self:Calc2DBox(playerData)
		end
		
		if not boxData then
			self:HidePlayer(player)
			return
		end
		
		local boxColor = self:GetColor(playerData, player)
		local boxTransparency = self:GetTrans(playerData, isBlocked)
		
		if self.config.box3D then
			self:Draw3DBox(playerCache, boxData, boxColor, boxTransparency)
		elseif self.config.cornerBox then
			self:DrawCornerBox(playerCache, boxData, boxColor, boxTransparency)
		else
			self:Draw2DBox(playerCache, boxData, boxColor, boxTransparency)
		end
		
		local lines = playerCache.lines
		if lines then
			local currentLineCount = playerCache.lineCount or 0
			for lineIndex = currentLineCount + 1, #lines do
				local line = lines[lineIndex]
				if line then
					safeSetProperty(line, "Visible", false)
				end
			end
		end
	end)
	
	if not success then
		self:HandleError(errorMsg, "UpdatePlayer")
	end
end

function ESP:HidePlayer(player)
	local playerCache = self.cache[player]
	if not playerCache then return end
	
	local lines = playerCache.lines
	if lines then
		for i = 1, #lines do
			local lineObject = lines[i]
			if lineObject then
				safeSetProperty(lineObject, "Visible", false)
			end
		end
	end
	
	if playerCache.quad then
		safeSetProperty(playerCache.quad, "Visible", false)
	end
end

function ESP:RemovePlayer(player)
	local playerCache = self.cache[player]
	if not playerCache then return end
	
	local lines = playerCache.lines
	if lines then
		for i = 1, #lines do
			local lineObject = lines[i]
			if lineObject then
				self:ReturnDrawing(lineObject, "line")
			end
		end
	end
	
	if playerCache.quad then
		self:ReturnDrawing(playerCache.quad, "quad")
	end
	
	self.cache[player] = nil
	self:ClearValidationCache(player)
	
	self.queueDirty = true
	self.needsResort = true
end

function ESP:MarkQueueDirty()
	self.queueDirty = true
end

function ESP:ForceResort()
	self.queueDirty = true
	self.needsResort = true
end

function ESP:Refresh()
	for player, playerCache in pairs(self.cache) do
		self:ClearCache(playerCache)
	end
	
	self.cache = {}
	self.validationData = {}
	self.validationTime = {}
	self.raycastCache = {}
	self:ForceResort()
end

function ESP:BuildUpdateQueue()
	local currentTime = tick()
	
	local timeForRebuild = currentTime - self.lastQueueBuild >= self.queueBuildInterval
	local queueExhausted = self.currentQueueIndex > #self.updateQueue
	local timeForFullSort = currentTime - self.lastFullSortTime >= self.fullSortInterval
	
	if not self.queueDirty and not timeForRebuild and not queueExhausted then
		return false
	end
	
	local players = Services.Players:GetPlayers()
	local newPlayerCount = #players
	self.playerCount = newPlayerCount
	self.lastQueueBuild = currentTime
	
	local shouldSort = self.needsResort or timeForFullSort or self.queueDirty
	
	local wasDirty = self.queueDirty
	self.queueDirty = false
	
	if shouldSort then
		self.needsResort = false
		self.lastFullSortTime = currentTime
		
		local localRoot = nil
		if self.localPlayer.Character then
			localRoot = self.localPlayer.Character:FindFirstChild("HumanoidRootPart")
		end
		
		local playersWithDistance = {}
		local count = 0
		
		for i = 1, #players do
			local player = players[i]
			if player ~= self.localPlayer then
				local distance = math.huge
				
				if localRoot and player.Character then
					local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
					if playerRoot then
						pcall(function()
							distance = (playerRoot.Position - localRoot.Position).Magnitude
						end)
					end
				end
				
				count = count + 1
				playersWithDistance[count] = {
					player = player,
					distance = distance
				}
			end
		end
		
		table.sort(playersWithDistance, function(a, b)
			return a.distance < b.distance
		end)
		
		self.updateQueue = {}
		for i = 1, count do
			self.updateQueue[i] = playersWithDistance[i].player
		end
		
		self:Log(string.format("Queue rebuilt with sort. Players: %d", count))
	else
		self:Log("Queue index reset (no sort needed)")
	end
	
	self.currentQueueIndex = 1
	return true
end

function ESP:Update()
	if not self.config.enabled then
		for player in pairs(self.cache) do
			self:HidePlayer(player)
		end
		return
	end
	
	self.frameSkip = self.frameSkip + 1
	
	if self.frameSkip < self.config.updateRate then
		return
	end
	
	self.frameSkip = 0
	
	if self.config.colorMode == "Rainbow" then
		self.rainbowHue = (self.rainbowHue + 0.005 * self.config.rainbowSpeed) % 1
	end
	
	self:BuildUpdateQueue()
	
	local processedCount = 0
	local maxToProcess = self.config.maxPlayersPerFrame
	local queueLength = #self.updateQueue
	
	while processedCount < maxToProcess and self.currentQueueIndex <= queueLength do
		local player = self.updateQueue[self.currentQueueIndex]
		
		if player and player.Parent then
			self:UpdatePlayer(player)
		end
		
		self.currentQueueIndex = self.currentQueueIndex + 1
		processedCount = processedCount + 1
	end
	
	self:CleanupPools()
end

function ESP:CleanupConnections()
	for i = 1, #self.connections do
		local connection = self.connections[i]
		if connection then
			pcall(function() connection:Disconnect() end)
		end
	end
	self.connections = {}
end

function ESP:Destroy()
	self:CleanupConnections()
	
	for player in pairs(self.cache) do
		self:RemovePlayer(player)
	end
	
	for poolType, pool in pairs({line = self.pools.line, quad = self.pools.quad}) do
		for _, drawing in pairs(pool) do
			if drawing then
				pcall(function() drawing:Remove() end)
			end
		end
	end
	
	self.pools = {
		line = {},
		quad = {},
		count = {line = 0, quad = 0},
		lastCleanup = 0,
		lastGlobalUse = 0
	}
	
	self.cache = {}
	self.validationData = {}
	self.validationTime = {}
	self.raycastCache = {}
end

function ESP:Init()
	self:CleanupConnections()
	
	local connectionCount = 0
	
	local renderConnection = Services.RunService.RenderStepped:Connect(function()
		local success, err = pcall(function()
			self:Update()
		end)
		
		if not success then
			self:HandleError(err, "RenderStepped")
		end
	end)
	connectionCount = connectionCount + 1
	self.connections[connectionCount] = renderConnection
	
	local playerRemovingConnection = Services.Players.PlayerRemoving:Connect(function(player)
		self:RemovePlayer(player)
	end)
	connectionCount = connectionCount + 1
	self.connections[connectionCount] = playerRemovingConnection
	
	local function setupPlayerConnections(player)
		if player == self.localPlayer then return end
		
		local charAddedConnection = player.CharacterAdded:Connect(function()
			task.delay(0.2, function()
				self:ClearValidationCache(player)
				self:ForceResort()
				self:UpdatePlayer(player)
			end)
		end)
		connectionCount = connectionCount + 1
		self.connections[connectionCount] = charAddedConnection
		
		local charRemovingConnection = player.CharacterRemoving:Connect(function()
			self:HidePlayer(player)
			self:ClearValidationCache(player)
			self:MarkQueueDirty()
		end)
		connectionCount = connectionCount + 1
		self.connections[connectionCount] = charRemovingConnection
	end
	
	for _, player in ipairs(Services.Players:GetPlayers()) do
		setupPlayerConnections(player)
	end
	
	local playerAddedConnection = Services.Players.PlayerAdded:Connect(function(player)
		self:ForceResort()
		setupPlayerConnections(player)
	end)
	connectionCount = connectionCount + 1
	self.connections[connectionCount] = playerAddedConnection
	
	self:Log("ESP initialized successfully")
end

ESP:Init()
return ESP
