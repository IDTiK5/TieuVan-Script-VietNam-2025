--[[
	DeaUI 2.0.0 - standalone UI library for Roblox (executor or Studio)
	The look, the components and the theme engine come from DeaDEX 1.1.0 (Explorer by ServerDead).

	  -- workspace/DeaUI/DeaUI.lua, workspace/DeaUI/Icon/lucide-roblox.luau, workspace/DeaUI/Tools/*.lua
	  local DeaUI = loadstring(readfile("DeaUI/DeaUI.lua"))()
	  DeaUI.Init({ Theme = "Crimson", Language = "vi" })          -- "vi" or "en"
	  local hub = DeaUI.CreateWindow({ Title = "My Hub", Icon = "layout-dashboard" })
	  local page = hub:AddPage({ Id = "main", Text = "Main", Icon = "home", Title = "Main" })
	  local group = page:Group("Combat")
	  group:Toggle({ Title = { en = "Enabled", vi = "Bật" }, Callback = function(on) print(on) end })
	  hub:AddSettingsPage()                                       -- language, theme, config...

	See Example.lua for every element.
]]

local Modules = {}

Modules["Core/Env"] = function(import)
local Env = {}

local genv = _G
local fenv = {}
if type(getgenv) == "function" then
	local ok, value = pcall(getgenv)
	if ok and type(value) == "table" then
		genv = value
	end
end
if type(getfenv) == "function" then
	local ok, value = pcall(getfenv, 0)
	if ok and type(value) == "table" then
		fenv = value
	end
end

local function find(...)
	for index = 1, select("#", ...) do
		local path = select(index, ...)
		local value
		local ok = pcall(function()
			local node = genv
			for part in string.gmatch(path, "[^%.]+") do
				local nextNode = node and (rawget(node, part) or node[part])
				if nextNode == nil and node == genv then
					nextNode = fenv[part]
				end
				node = nextNode
				if node == nil then
					break
				end
			end
			value = node
		end)
		if ok and value ~= nil then
			return value
		end
	end
	return nil
end

Env.Global = genv
Env.Find = find

local function findFunction(...)
	for index = 1, select("#", ...) do
		local path = select(index, ...)
		local value = find(path)
		if type(value) == "function" then
			return value
		end
	end
	return nil
end

Env.FindFunction = findFunction

local TOKEN_SET = "abcdefghijklmnopqrstuvwxyz0123456789"
function Env.Token(prefix)
	local out = table.create(12)
	for index = 1, 12 do
		local pick = math.random(1, #TOKEN_SET)
		out[index] = string.sub(TOKEN_SET, pick, pick)
	end
	return (prefix or "") .. table.concat(out)
end

Env.Name, Env.Version = "Unknown", ""
pcall(function()
	local identify = findFunction("identifyexecutor", "getexecutorname")
	if identify then
		local name, version = identify()
		Env.Name = tostring(name or "Unknown")
		Env.Version = tostring(version or "")
	end
end)

local rawCloneref = findFunction("cloneref", "clonereference")
Env.rawCloneref = rawCloneref
Env.compareInstances = findFunction("compareinstances")
Env.ReferenceFailures = 0

function Env.SameInstance(left, right)
	if rawequal(left, right) then
		return true
	end
	if typeof(left) ~= "Instance" or typeof(right) ~= "Instance" then
		return false
	end
	if Env.compareInstances then
		local ok, same = pcall(Env.compareInstances, left, right)
		if ok and type(same) == "boolean" then
			return same
		end
	elseif Env.Ref then
		return rawequal(Env.Ref(left), Env.Ref(right))
	end
	return false
end

do
	local cloneFunction = findFunction("clonefunction")
	local _, getDebugId = pcall(function()
		return game.GetDebugId
	end)
	if cloneFunction and type(getDebugId) == "function" then
		local ok, cloned = pcall(cloneFunction, getDebugId)
		if ok and type(cloned) == "function" then
			getDebugId = cloned
		end
	end
	local cache = setmetatable({}, { __mode = "v" })
	local references = setmetatable({}, { __mode = "kv" })
	local ids = setmetatable({}, { __mode = "k" })
	local nextId = 0
	Env.cloneref = function(object)
		if typeof(object) ~= "Instance" then
			return object
		end
		local known = references[object]
		if known then
			return known
		end
		local okId, id = pcall(getDebugId, object)
		if okId and type(id) == "string" and cache[id] then
			local cached = cache[id]
			if not Env.compareInstances or Env.SameInstance(cached, object) then
				references[object] = cached
				return cached
			end
		end
		if not rawCloneref then
			return object
		end
		local ok, ref = pcall(rawCloneref, object)
		if not ok or typeof(ref) ~= "Instance" then
			Env.ReferenceFailures += 1
			return object
		end
		references[object] = ref
		references[ref] = ref
		if okId and type(id) == "string" then
			cache[id] = ref
		end
		return ref
	end
	function Env.InstanceId(object)
		local ref = Env.cloneref(object)
		local id = ids[ref]
		if id then
			return id
		end
		nextId += 1
		id = "instance:" .. tostring(nextId)
		ids[ref] = id
		return id
	end
end
Env.Ref = Env.cloneref
Env.gethui = findFunction("gethui", "get_hidden_gui", "gethiddengui")
Env.protectGui = findFunction("syn.protect_gui", "protect_gui", "protectgui")

Env.getCustomAsset = findFunction("getcustomasset", "getsynasset")
Env.setClipboard = findFunction("setclipboard", "toclipboard", "set_clipboard", "Clipboard.set")
Env.writefile = findFunction("writefile")
Env.readfile = findFunction("readfile")
Env.appendfile = findFunction("appendfile")
Env.isfile = findFunction("isfile")
Env.isfolder = findFunction("isfolder")
Env.makefolder = findFunction("makefolder")
Env.listfiles = findFunction("listfiles")
Env.delfile = findFunction("delfile")

Env.Persist = true
Env.Root = "DeaUI"

function Env.Has(...)
	for index = 1, select("#", ...) do
		if Env[select(index, ...)] == nil then
			return false
		end
	end
	return true
end

function Env.Clipboard(text)
	if not Env.setClipboard then
		return false
	end
	return (pcall(Env.setClipboard, tostring(text)))
end

function Env.Path(...)
	local parts = { Env.Root, ... }
	return table.concat(parts, "/")
end

function Env.EnsureFolder(...)
	if not (Env.isfolder and Env.makefolder) then
		return false
	end
	local path = Env.Root
	local parts = { ... }
	local ok = pcall(function()
		if not Env.isfolder(path) then
			Env.makefolder(path)
		end
		for _, part in parts do
			path ..= "/" .. part
			if not Env.isfolder(path) then
				Env.makefolder(path)
			end
		end
	end)
	return ok
end

function Env.Write(path, contents)
	if not Env.writefile then
		return false
	end
	local folder = string.match(path, "^(.*)/[^/]+$")
	if folder and Env.isfolder and Env.makefolder then
		local built = ""
		for part in string.gmatch(folder, "[^/]+") do
			built = built == "" and part or built .. "/" .. part
			pcall(function()
				if not Env.isfolder(built) then
					Env.makefolder(built)
				end
			end)
		end
	end
	return (pcall(Env.writefile, path, contents))
end

function Env.Read(path)
	if not (Env.readfile and Env.isfile) then
		return nil
	end
	local ok, exists = pcall(Env.isfile, path)
	if not ok or not exists then
		return nil
	end
	local okRead, contents = pcall(Env.readfile, path)
	return okRead and contents or nil
end

function Env.SafeName(name)
	local cleaned = string.gsub(tostring(name), "[^%w%-_ %.]", "_")
	cleaned = string.sub(cleaned, 1, 80)
	return cleaned == "" and "unnamed" or cleaned
end

return Env
end

Modules["Core/Store"] = function(import)
local Env = import("Core/Env")
local Signal = import("Core/Signal")
local Services = import("Core/Services")

local Store = {}

local function settingsFile()
	return Env.Path("settings.json")
end

local DEFAULTS = {
	Accent = "Crimson",
	Surface = "Onyx",
	ThemePreset = "Crimson",
	CustomAccent = Color3.fromRGB(229, 36, 59),
	CustomBase = Color3.fromRGB(9, 9, 11),
	CustomText = Color3.fromRGB(237, 237, 240),
	CustomOverrides = {},
	BackgroundEnabled = false,
	BackgroundImage = "",
	BackgroundOpacity = 0.2,
	BackgroundTransparency = 0,
	BackgroundScale = "Crop",
	BackgroundTint = Color3.new(1, 1, 1),
	Animations = true,
	UIScale = 1,
	AllowVisibleGuiFallback = true,
	Language = "",
	Windows = {},
}

local data = table.clone(DEFAULTS)
data.CustomOverrides = {}
Store.Changed = Signal.new()

local THEME_NAMES = { Crimson = true, Ocean = true, Emerald = true, Violet = true, Amber = true, Custom = true }
local ACCENT_COLORS = {
	Crimson = Color3.fromRGB(229, 36, 59),
	Blood = Color3.fromRGB(179, 18, 31),
	Scarlet = Color3.fromRGB(255, 59, 59),
	Ember = Color3.fromRGB(255, 85, 51),
	Rose = Color3.fromRGB(244, 63, 94),
	Garnet = Color3.fromRGB(159, 18, 57),
}
local SURFACE_COLORS = {
	Onyx = { Base = Color3.fromRGB(9, 9, 11), Text = Color3.fromRGB(237, 237, 240) },
	Graphite = { Base = Color3.fromRGB(17, 17, 20), Text = Color3.fromRGB(240, 240, 243) },
	Void = { Base = Color3.new(0, 0, 0), Text = Color3.fromRGB(237, 237, 240) },
}
local COLOR_KEYS = { CustomAccent = true, CustomBase = true, CustomText = true, BackgroundTint = true }
local SCALES = { Crop = true, Fit = true, Stretch = true }
local CUSTOM_TOKENS = {
	Shade = true, Base = true, Panel = true, Raised = true, Field = true, Hover = true, Pressed = true,
	Line = true, LineStrong = true, Text = true, Muted = true, Faint = true,
	Accent = true, AccentHover = true, AccentPressed = true, AccentSoft = true, AccentSofter = true, AccentLine = true, AccentText = true,
	Danger = true, Success = true, Warning = true, Info = true, Logo = true, LogoText = true, Vip = true, VipSoft = true,
}

local function normalizeOverrides(value)
	local result = {}
	for key, color in next, value do
		result[key] = string.upper(string.gsub(color, "^#", ""))
	end
	return result
end

local function component(value)
	return type(value) == "number" and value == value and value >= 0 and value <= 1
end

local function validColor(value)
	return typeof(value) == "Color3" and component(value.R) and component(value.G) and component(value.B)
end

local function valid(key, value)
	if key == "ThemePreset" then
		return type(value) == "string" and THEME_NAMES[value] == true
	elseif key == "Accent" then
		return type(value) == "string" and ACCENT_COLORS[value] ~= nil
	elseif key == "Surface" then
		return type(value) == "string" and SURFACE_COLORS[value] ~= nil
	elseif COLOR_KEYS[key] then
		return validColor(value)
	elseif key == "CustomOverrides" then
		if type(value) ~= "table" then
			return false
		end
		for name, color in next, value do
			if not CUSTOM_TOKENS[name] or type(color) ~= "string" or not string.match(color, "^#?%x%x%x%x%x%x$") then
				return false
			end
		end
		return true
	elseif key == "BackgroundScale" then
		return type(value) == "string" and SCALES[value] == true
	elseif key == "BackgroundOpacity" or key == "BackgroundTransparency" then
		return component(value)
	elseif key == "BackgroundEnabled" then
		return type(value) == "boolean"
	elseif key == "BackgroundImage" then
		return type(value) == "string" and #value <= 1024 and not string.find(value, "%c")
	end
	return true
end

local function encodeValue(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __t = "Color3", value.R, value.G, value.B }
	elseif kind == "EnumItem" then
		return { __t = "Enum", tostring(value.EnumType), value.Name }
	end
	return value
end

local function decodeValue(value)
	if type(value) == "table" and value.__t == "Color3" then
		if not component(value[1]) or not component(value[2]) or not component(value[3]) then
			return nil
		end
		local ok, color = pcall(Color3.new, value[1], value[2], value[3])
		return ok and color or nil
	elseif type(value) == "table" and value.__t == "Enum" then
		local ok, item = pcall(function()
			return Enum[value[1]][value[2]]
		end)
		return ok and item or nil
	end
	return value
end

local function load()
	local raw = Env.Read(settingsFile())
	if not raw then
		return
	end
	local ok, decoded = pcall(Services.HttpService.JSONDecode, Services.HttpService, raw)
	if not ok or type(decoded) ~= "table" then
		return
	end
	for key, value in decoded do
		local parsed = decodeValue(value)
		if parsed ~= nil and valid(key, parsed) and (DEFAULTS[key] == nil or type(parsed) == type(DEFAULTS[key])) then
			data[key] = key == "CustomOverrides" and normalizeOverrides(parsed) or parsed
		end
	end
	if decoded.ThemePreset == nil and (data.Accent ~= DEFAULTS.Accent or data.Surface ~= DEFAULTS.Surface) then
		local surface = SURFACE_COLORS[data.Surface]
		data.ThemePreset = "Custom"
		data.CustomAccent = ACCENT_COLORS[data.Accent]
		data.CustomBase = surface.Base
		data.CustomText = surface.Text
	end
end

local pending = false

local function write()
	local out = {}
	for key, value in data do
		out[key] = encodeValue(value)
	end
	local ok, encoded = pcall(Services.HttpService.JSONEncode, Services.HttpService, out)
	if ok then
		Env.Write(settingsFile(), encoded)
	end
end

function Store.Save()
	if not Env.Persist or pending then
		return
	end
	pending = true
	task.delay(0.4, function()
		pending = false
		write()
	end)
end

-- writes the settings immediately (used when the interface is unloaded)
function Store.Flush()
	if Env.Persist then
		write()
	end
end

function Store.Get(key, fallback)
	local value = data[key]
	if value == nil then
		return fallback
	end
	return value
end

function Store.Set(key, value)
	if not valid(key, value) then
		return false
	end
	if key == "CustomOverrides" then
		value = normalizeOverrides(value)
	end
	if data[key] == value and type(value) ~= "table" then
		return true
	end
	data[key] = value
	Store.Changed:Fire(key, value)
	Store.Save()
	return true
end

function Store.Default(key)
	return DEFAULTS[key]
end

-- Lets add-ons (for example the DeaDEX tools) register their own persisted settings.
-- Registers defaults for new keys (tool settings). It never re-reads the settings file: Store.Load
-- already loaded every saved key, so the keys that are already in memory keep their current value.
function Store.AddDefaults(defaults)
	for key, value in defaults do
		if DEFAULTS[key] == nil then
			DEFAULTS[key] = value
			if data[key] == nil or type(data[key]) ~= type(value) then
				data[key] = type(value) == "table" and table.clone(value) or value
			end
		end
	end
end

function Store.Watch(key, callback)
	callback(data[key])
	return Store.Changed:Connect(function(changed, value)
		if changed == key then
			callback(value)
		end
	end)
end

function Store.Reset()
	for key, value in DEFAULTS do
		data[key] = type(value) == "table" and table.clone(value) or value
		Store.Changed:Fire(key, data[key])
	end
	Store.Save()
end

Store.Load = load

return Store
end

Modules["Core/Util"] = function(import)
local Util = {}

function Util.Hex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

function Util.Lines(text)
	local lines = {}
	text = string.gsub(text, "\r\n", "\n")
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		table.insert(lines, line)
	end
	return lines
end

function Util.Debounce(seconds, callback)
	local scheduled = false
	return function(...)
		if scheduled then
			return
		end
		scheduled = true
		local args = table.pack(...)
		task.delay(seconds, function()
			scheduled = false
			callback(table.unpack(args, 1, args.n))
		end)
	end
end

return Util
end

Modules["Core/Services"] = function(import)
local Env = import("Core/Env")

local Services = {}

return setmetatable(Services, {
	__index = function(self, name)
		local ok, service = pcall(game.GetService, game, name)
		if not ok or service == nil then
			ok, service = pcall(game.FindService, game, name)
		end
		if not ok or service == nil then
			return nil
		end
		service = Env.cloneref(service)
		rawset(self, name, service)
		return service
	end,
})
end

Modules["Core/Signal"] = function(import)
local Signal = {}
Signal.__index = Signal

local Link = {}
Link.__index = Link

function Link:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._links
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end
Link.Destroy = Link.Disconnect

function Signal.new()
	return setmetatable({ _links = {} }, Signal)
end

function Signal:Connect(callback)
	local link = setmetatable({ Connected = true, _signal = self, _callback = callback }, Link)
	table.insert(self._links, link)
	return link
end

function Signal:Once(callback)
	local link
	link = self:Connect(function(...)
		link:Disconnect()
		callback(...)
	end)
	return link
end

function Signal:Fire(...)
	local snapshot = table.clone(self._links)
	for _, link in snapshot do
		if link.Connected then
			task.spawn(link._callback, ...)
		end
	end
end

function Signal:FireSync(...)
	local snapshot = table.clone(self._links)
	for _, link in snapshot do
		if link.Connected then
			local ok, err = pcall(link._callback, ...)
			if not ok then
				warn("" .. tostring(err))
			end
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Clear()
	for _, link in table.clone(self._links) do
		link:Disconnect()
	end
end

return Signal
end

Modules["Core/Scope"] = function(import)
local Scope = {}
Scope.__index = Scope

function Scope.new()
	return setmetatable({ _items = {} }, Scope)
end

function Scope:Add(item)
	if item ~= nil then
		table.insert(self._items, item)
	end
	return item
end

function Scope:Connect(signal, callback)
	return self:Add(signal:Connect(callback))
end

function Scope:Child()
	local child = Scope.new()
	self:Add(child)
	return child
end

local function release(item)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Clean) == "function" then
			item:Clean()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Scope:Clean()
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		pcall(release, items[index])
	end
end
Scope.Destroy = Scope.Clean

return Scope
end

Modules["Core/Input"] = function(import)
local Services = import("Core/Services")
local Signal = import("Core/Signal")

local UIS = Services.UserInputService
local GuiService = Services.GuiService

local Input = {}

local POINTER_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

function Input.IsPrimary(input)
	return POINTER_TYPES[input.UserInputType] == true
end

function Input.IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

-- Touch calibration ---------------------------------------------------------
-- InputObject.Position of a touch lives in a space that may or may not contain the
-- top bar inset, depending on the ScreenGui and on the Roblox client. Our root GUIs
-- ignore every inset, so they need full screen coordinates. Guessing the inset is what
-- shifted the colour picker on phones, so the offset is learned instead: every touch
-- that lands on one of our own GuiObjects must be inside that object's rectangle.
-- Each of those touches narrows the range of possible offsets and the intersection
-- converges after a few taps. Until then the offset between GetMouseLocation() and the
-- raw touch position is used when it is plausible, and finally zero.
local calib = { loX = -math.huge, hiX = math.huge, loY = -math.huge, hiY = math.huge }
local offsets = setmetatable({}, { __mode = "k" })

-- Optional manual override: Input.TouchOffset = Vector2.new(0, 0)
Input.TouchOffset = nil

local function rawPosition(input)
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function within(lo, hi, value)
	return value >= lo - 2 and value <= hi + 2
end

local function axis(lo, hi, guess)
	if hi - lo <= 6 then
		return (lo + hi) / 2
	end
	if guess >= lo and guess <= hi then
		return guess
	end
	if hi - lo < math.huge then
		-- the guess is impossible: the middle of what is still possible has the smallest worst case error
		return (lo + hi) / 2
	end
	return math.clamp(guess, lo, hi)
end

local function estimate(input)
	if typeof(Input.TouchOffset) == "Vector2" then
		return Input.TouchOffset
	end
	local gx, gy = 0, 0
	local ok, mouse = pcall(function()
		return UIS:GetMouseLocation()
	end)
	if ok and typeof(mouse) == "Vector2" then
		local raw = rawPosition(input)
		local dx, dy = mouse.X - raw.X, mouse.Y - raw.Y
		if math.abs(dx) <= 130 and dy >= -2 and dy <= 130 and within(calib.loX, calib.hiX, dx) and within(calib.loY, calib.hiY, dy) then
			gx, gy = dx, dy
		end
	end
	return Vector2.new(axis(calib.loX, calib.hiX, gx), axis(calib.loY, calib.hiY, gy))
end

-- Tells the calibration that this touch started on `gui` (so it is inside its rectangle).
function Input.Learn(gui, input)
	if not gui or not input or input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local position, size = gui.AbsolutePosition, gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local raw = rawPosition(input)
	local loX, hiX = position.X - raw.X, position.X + size.X - raw.X
	local loY, hiY = position.Y - raw.Y, position.Y + size.Y - raw.Y
	local nloX, nhiX = math.max(calib.loX, loX), math.min(calib.hiX, hiX)
	local nloY, nhiY = math.max(calib.loY, loY), math.min(calib.hiY, hiY)
	if nloX > nhiX or nloY > nhiY then
		-- the constraints disagree (rotation, new insets...): start over from this touch
		calib.loX, calib.hiX, calib.loY, calib.hiY = loX, hiX, loY, hiY
	else
		calib.loX, calib.hiX, calib.loY, calib.hiY = nloX, nhiX, nloY, nhiY
	end
end

-- Call when an interaction starts on `gui`: learns from it and freezes the offset for
-- the whole gesture, so the pointer cannot jump in the middle of a drag.
function Input.Begin(gui, input)
	if not input or input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	Input.Learn(gui, input)
	offsets[input] = estimate(input)
end

function Input.Pointer(input)
	if input and input.UserInputType == Enum.UserInputType.Touch then
		local offset = offsets[input] or estimate(input)
		return rawPosition(input) + offset
	end
	return UIS:GetMouseLocation()
end

function Input.Ctrl()
	return UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) or UIS:IsKeyDown(Enum.KeyCode.LeftMeta) or UIS:IsKeyDown(Enum.KeyCode.RightMeta)
end

function Input.Shift()
	return UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
end

function Input.Alt()
	return UIS:IsKeyDown(Enum.KeyCode.LeftAlt) or UIS:IsKeyDown(Enum.KeyCode.RightAlt)
end

function Input.Typing()
	return UIS:GetFocusedTextBox() ~= nil
end

function Input.Touch()
	return UIS.TouchEnabled and not UIS.MouseEnabled
end

function Input.Inside(gui, point)
	point = point or UIS:GetMouseLocation()
	local position, size = gui.AbsolutePosition, gui.AbsoluteSize
	return point.X >= position.X and point.Y >= position.Y and point.X <= position.X + size.X and point.Y <= position.Y + size.Y
end

function Input.Secondary(button, callback, holdTime)
	local began = button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			callback(Input.Pointer(input))
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local start = input.Position
			local fired = false
			local moved = false
			local link
			link = input.Changed:Connect(function()
				if (input.Position - start).Magnitude > 10 then
					moved = true
				end
				if input.UserInputState == Enum.UserInputState.End then
					link:Disconnect()
				end
			end)
			task.delay(holdTime or 0.45, function()
				if not moved and input.UserInputState ~= Enum.UserInputState.End and not fired then
					fired = true
					callback(Input.Pointer(input))
				end
			end)
		end
	end)
	return {
		Disconnect = function()
			began:Disconnect()
		end,
		Clean = function()
			began:Disconnect()
		end,
	}
end

function Input.Drag(handle, callbacks)
	local dragging, startPoint, link
	local function stop()
		if not dragging then
			return
		end
		dragging = false
		if link then
			link:Disconnect()
			link = nil
		end
		if callbacks.End then
			callbacks.End()
		end
	end
	local began = handle.InputBegan:Connect(function(input)
		if not Input.IsPrimary(input) then
			return
		end
		dragging = true
		Input.Begin(handle, input)
		startPoint = Input.Pointer(input)
		if callbacks.Begin then
			callbacks.Begin(startPoint)
		end
		local ended
		ended = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				ended:Disconnect()
				stop()
			end
		end)
		link = UIS.InputChanged:Connect(function(changed)
			if not dragging then
				return
			end
			if changed.UserInputType == Enum.UserInputType.MouseMovement or (changed.UserInputType == Enum.UserInputType.Touch and changed == input) then
				local point = Input.Pointer(changed)
				callbacks.Move(point - startPoint, point)
			end
		end)
	end)
	local endedGlobal = UIS.InputEnded:Connect(function(input)
		if dragging and Input.IsPrimary(input) then
			stop()
		end
	end)
	return { began, endedGlobal, Disconnect = function()
		began:Disconnect()
		endedGlobal:Disconnect()
		stop()
	end }
end

Input.Shortcut = Signal.new()

local binds = {}

function Input.Bind(keyCode, options, callback)
	local bind = { Key = keyCode, Ctrl = options.Ctrl, Shift = options.Shift, Alt = options.Alt, When = options.When, Callback = callback, AllowTyping = options.AllowTyping }
	table.insert(binds, bind)
	return {
		Disconnect = function()
			local index = table.find(binds, bind)
			if index then
				table.remove(binds, index)
			end
		end,
	}
end

function Input.Start(scope)
	scope:Connect(UIS.InputBegan, function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local typing = Input.Typing()
		for _, bind in binds do
			if bind.Key == input.KeyCode and (bind.Ctrl or false) == Input.Ctrl() and (bind.Shift or false) == Input.Shift() and (bind.Alt or false) == Input.Alt() then
				if (not typing or bind.AllowTyping) and (not bind.When or bind.When()) then
					task.spawn(bind.Callback, input, processed)
				end
			end
		end
	end)
end

return Input
end

Modules["Core/I18n"] = function(import)
local Signal = import("Core/Signal")
local Store = import("Core/Store")
local Services = import("Core/Services")

--[[
	Two languages: "en" (English) and "vi" (Tieng Viet).

	Any text given to the library can be
	  - a plain string                      "Enabled"            (translated when a phrase exists)
	  - a table per language                { en = "Enabled", vi = "Bat" }
	  - a function(language) -> string      function(l) return l == "vi" and "Bat" or "On" end
	  - a key registered with I18n.Define   "my.key"

	Labels created through the library are bound to their source, so changing the
	language (Settings -> Language, or DeaUI.SetLanguage("vi")) updates them live.
]]
local I18n = {
	Changed = Signal.new(),
	Languages = {
		{ Code = "en", Name = "English" },
		{ Code = "vi", Name = "Tiếng Việt" },
	},
}

local current = "en"
local phrases = { en = {}, vi = {} }
local keys = {}
local bound = setmetatable({}, { __mode = "k" })

local function valid(code)
	return code == "en" or code == "vi"
end

local function detect()
	local ok, locale = pcall(function()
		return Services.LocalizationService.RobloxLocaleId
	end)
	if (not ok or type(locale) ~= "string" or locale == "") then
		ok, locale = pcall(function()
			return Services.Players.LocalPlayer.LocaleId
		end)
	end
	if ok and type(locale) == "string" and string.sub(string.lower(locale), 1, 2) == "vi" then
		return "vi"
	end
	return "en"
end

-- Phrases are keyed by their English text: I18n.Phrases("vi", { ["Cancel"] = "Huy" }).
function I18n.Phrases(code, map)
	if not valid(code) or type(map) ~= "table" then
		return
	end
	local target = phrases[code]
	for english, text in map do
		target[english] = text
	end
end

-- Keys carry both languages: I18n.Define("greeting", { en = "Hello", vi = "Xin chao" }).
function I18n.Define(key, entry)
	if type(key) == "string" and type(entry) == "table" then
		keys[key] = entry
	end
end

function I18n.Known(text)
	return type(text) == "string" and (keys[text] ~= nil or phrases.vi[text] ~= nil)
end

function I18n.Get()
	return current
end

function I18n.Resolve(source, ...)
	local kind = type(source)
	local text
	if kind == "string" then
		local entry = keys[source]
		if entry then
			text = entry[current] or entry.en or source
		elseif current ~= "en" then
			text = phrases[current][source] or source
		else
			text = source
		end
	elseif kind == "table" then
		text = source[current] or source[string.upper(current)] or source.en or source.EN
		if text == nil then
			for _, value in source do
				if type(value) == "string" then
					text = value
					break
				end
			end
		end
	elseif kind == "function" then
		local ok, value = pcall(source, current)
		text = ok and value or ""
	elseif source == nil then
		text = ""
	else
		text = tostring(source)
	end
	text = tostring(text or "")
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		if ok then
			return formatted
		end
	end
	return text
end
I18n.T = I18n.Resolve

-- Upper case that also understands Vietnamese letters (string.upper is ASCII only).
local UP = {}
do
	local lower = "àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ"
	local upper = "ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ"
	local a, b = {}, {}
	for _, code in utf8.codes(lower) do
		table.insert(a, utf8.char(code))
	end
	for _, code in utf8.codes(upper) do
		table.insert(b, utf8.char(code))
	end
	for index, char in a do
		if b[index] then
			UP[char] = b[index]
		end
	end
end

function I18n.Upper(text)
	text = tostring(text or "")
	local ok, result = pcall(function()
		local out = {}
		for _, code in utf8.codes(text) do
			local char = utf8.char(code)
			out[#out + 1] = UP[char] or string.upper(char)
		end
		return table.concat(out)
	end)
	return ok and result or string.upper(text)
end

-- Binds `instance[property]` to `source`; it is rewritten whenever the language changes,
-- unless someone assigned a different value to the property in the meantime.
function I18n.Bind(instance, property, source)
	local map = bound[instance]
	if not map then
		map = {}
		bound[instance] = map
	end
	local value = I18n.Resolve(source)
	map[property] = { Source = source, Last = value }
	instance[property] = value
	return value
end

function I18n.Unbind(instance, property)
	local map = bound[instance]
	if map then
		if property then
			map[property] = nil
		else
			bound[instance] = nil
		end
	end
end

local function refresh()
	for instance, map in bound do
		for property, entry in map do
			local ok, now = pcall(function()
				return instance[property]
			end)
			if ok and now == entry.Last then
				local value = I18n.Resolve(entry.Source)
				entry.Last = value
				pcall(function()
					instance[property] = value
				end)
			elseif ok then
				map[property] = nil
			end
		end
	end
end

function I18n.Set(code, silent)
	if not valid(code) then
		return false
	end
	if code == current then
		return true
	end
	current = code
	Store.Set("Language", code)
	refresh()
	if not silent then
		I18n.Changed:Fire(code)
	end
	return true
end

function I18n.Toggle()
	return I18n.Set(current == "vi" and "en" or "vi")
end

function I18n.Init(preferred)
	local code = preferred
	if not valid(code) then
		code = Store.Get("Language")
	end
	if not valid(code) then
		code = detect()
	end
	current = code
	return current
end

-- { { Text = "English", Value = "en" }, { Text = "Tiếng Việt", Value = "vi" } }
function I18n.Items()
	local items = {}
	for _, language in I18n.Languages do
		table.insert(items, { Text = language.Name, Value = language.Code })
	end
	return items
end

return I18n
end

Modules["Core/Highlight"] = function(import)
local Theme = import("Theme/Theme")
local Util = import("Core/Util")

local Highlight = {}

local function hex(color)
	return Util.Hex(color)
end

local S = Theme.Syntax
local C = {
	Keyword = hex(S.Keyword),
	Builtin = hex(S.Builtin),
	String = hex(S.String),
	Number = hex(S.Number),
	Comment = hex(S.Comment),
	Function = hex(S.Function),
	Method = hex(S.Method),
	Property = hex(S.Property),
	Operator = hex(S.Operator),
	Literal = hex(S.Literal),
	Self = hex(S.Self),
	Type = hex(S.Type),
}
Highlight.Colors = C

local KEYWORDS = {}
for word in string.gmatch("and break do else elseif end for function if in local not or repeat return then until while continue goto", "%S+") do
	KEYWORDS[word] = true
end

local BUILTINS = {}
for word in string.gmatch("game workspace script plugin shared _G _VERSION print warn error assert pcall xpcall select type typeof tostring tonumber pairs ipairs next rawget rawset rawequal rawlen setmetatable getmetatable require tick wait spawn delay unpack newproxy collectgarbage gcinfo loadstring Enum Instance Vector3 Vector2 CFrame Color3 Color3uint8 UDim UDim2 Ray Rect Region3 NumberSequence NumberSequenceKeypoint NumberRange ColorSequence ColorSequenceKeypoint TweenInfo PhysicalProperties BrickColor Font Random DateTime Faces Axes task math string table coroutine os bit32 utf8 debug buffer vector Drawing getgenv getrenv getsenv getfenv setfenv getgc getreg hookfunction hookmetamethod getrawmetatable setrawmetatable setreadonly isreadonly islclosure iscclosure checkcaller newcclosure getnamecallmethod getcallingscript fireclickdetector firetouchinterest fireproximityprompt getconnections firesignal cloneref gethui getnilinstances getinstances getloadedmodules getrunningscripts getscriptbytecode getscriptclosure getscripthash decompile saveinstance request writefile readfile isfile isfolder makefolder listfiles delfile getcustomasset identifyexecutor", "%S+") do
	BUILTINS[word] = true
end

local CALL_AHEAD = "^%s*[({\"'" .. "`" .. "]"
local OPERATORS = "^[%+%-%*/%%%^#=~<>%.:%?|&]+"

local function escapeRich(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
end
Highlight.Escape = escapeRich

local function closeLong(text, from, level)
	local closer = "]" .. string.rep("=", level) .. "]"
	local _, finish = string.find(text, closer, from, true)
	return finish
end

local function classify(word, afterDot, afterColon, afterFunc, callNext)
	if afterFunc then
		return C.Function
	end
	if afterColon then
		return C.Method
	end
	if afterDot then
		return callNext and C.Function or C.Property
	end
	if KEYWORDS[word] then
		return C.Keyword
	end
	if word == "true" or word == "false" or word == "nil" then
		return C.Literal
	end
	if word == "self" then
		return C.Self
	end
	if BUILTINS[word] then
		return C.Builtin
	end
	if callNext then
		return C.Function
	end
	return nil
end

local function scanNumber(text, i)
	local two = string.sub(text, i, i + 1)
	if two == "0x" or two == "0X" then
		local _, stop = string.find(text, "^0[xX][%x_]*", i)
		i = stop
		local dotStart, dotStop = string.find(text, "^%.[%x_]*", i + 1)
		if dotStart then
			i = dotStop
		end
		local expStart, expStop = string.find(text, "^[pP][%+%-]?[%d_]+", i + 1)
		if expStart then
			i = expStop
		end
		return i
	elseif two == "0b" or two == "0B" then
		local _, stop = string.find(text, "^0[bB][01_]*", i)
		return stop
	end
	local _, stop = string.find(text, "^[%d_]*", i)
	i = stop
	local dotStart, dotStop = string.find(text, "^%.[%d_]*", i + 1)
	if dotStart then
		i = dotStop
	end
	local expStart, expStop = string.find(text, "^[eE][%+%-]?[%d_]+", i + 1)
	if expStart then
		i = expStop
	end
	return i
end

local function scanQuote(text, i, quote)
	local length = #text
	local j = i + 1
	while j <= length do
		local char = string.sub(text, j, j)
		if char == "\\" then
			j += 2
		elseif char == quote then
			return j
		else
			j += 1
		end
	end
	return length
end

local function highlightLine(text, state)
	local length = #text
	local parts = {}
	local count = 0
	local function emit(segment, color)
		if segment == "" then
			return
		end
		count += 1
		local safe = escapeRich(segment)
		parts[count] = color and ('<font color="' .. color .. '">' .. safe .. "</font>") or safe
	end

	local i = 1
	if state then
		local finish = closeLong(text, i, state.level)
		local color = state.kind == "comment" and C.Comment or C.String
		if finish then
			emit(string.sub(text, i, finish), color)
			i = finish + 1
			state = nil
		else
			emit(string.sub(text, i), color)
			return table.concat(parts), state
		end
	end

	local afterDot, afterColon, afterFunc = false, false, false
	while i <= length do
		local space = string.match(text, "^%s+", i)
		if space then
			emit(space, nil)
			i += #space
			continue
		end

		local char = string.sub(text, i, i)
		local two = string.sub(text, i, i + 1)

		if two == "--" then
			local eqs = string.match(text, "^%[(=*)%[", i + 2)
			if eqs then
				local level = #eqs
				local openEnd = i + 2 + #eqs + 1
				local finish = closeLong(text, openEnd + 1, level)
				if finish then
					emit(string.sub(text, i, finish), C.Comment)
					i = finish + 1
				else
					emit(string.sub(text, i), C.Comment)
					return table.concat(parts), { kind = "comment", level = level }
				end
			else
				emit(string.sub(text, i), C.Comment)
				i = length + 1
			end
			afterDot, afterColon, afterFunc = false, false, false
			continue
		end

		if char == "[" then
			local eqs = string.match(text, "^%[(=*)%[", i)
			if eqs then
				local level = #eqs
				local openEnd = i + 1 + #eqs
				local finish = closeLong(text, openEnd + 1, level)
				if finish then
					emit(string.sub(text, i, finish), C.String)
					i = finish + 1
				else
					emit(string.sub(text, i), C.String)
					return table.concat(parts), { kind = "string", level = level }
				end
				afterDot, afterColon, afterFunc = false, false, false
				continue
			end
		end

		if char == '"' or char == "'" or char == "`" then
			local finish = scanQuote(text, i, char)
			emit(string.sub(text, i, finish), C.String)
			i = finish + 1
			afterDot, afterColon, afterFunc = false, false, false
			continue
		end

		local byte = string.byte(text, i)
		local nextByte = string.byte(text, i + 1)
		local digit = byte and byte >= 48 and byte <= 57
		local dotDigit = char == "." and nextByte and nextByte >= 48 and nextByte <= 57
		if digit or dotDigit then
			local finish = scanNumber(text, i)
			emit(string.sub(text, i, finish), C.Number)
			i = finish + 1
			afterDot, afterColon, afterFunc = false, false, false
			continue
		end

		if string.match(char, "[%a_]") then
			local _, finish = string.find(text, "^[%a_][%w_]*", i)
			local word = string.sub(text, i, finish)
			local callNext = string.match(text, CALL_AHEAD, finish + 1) ~= nil
			emit(word, classify(word, afterDot, afterColon, afterFunc, callNext))
			i = finish + 1
			afterDot, afterColon = false, false
			if word == "function" then
				afterFunc = true
			elseif not afterFunc then
				afterFunc = false
			end
			continue
		end

		local operator = string.match(text, OPERATORS, i)
		if operator then
			emit(operator, C.Operator)
			i += #operator
			if operator == "." then
				afterDot = true
				afterColon = false
			elseif operator == ":" then
				afterColon = true
				afterDot = false
			else
				afterDot, afterColon, afterFunc = false, false, false
			end
			continue
		end

		emit(char, nil)
		i += 1
		if char == "(" then
			afterFunc = false
		end
		afterDot, afterColon = false, false
	end

	return table.concat(parts), nil
end

Highlight.LineState = highlightLine

function Highlight.Line(text)
	local rich = highlightLine(text or "", nil)
	return rich
end

function Highlight.Session(lines)
	local self = { Lines = lines }
	local rich = {}
	local states = { [1] = nil }
	local computed = 0

	local function ensure(upto)
		local total = #lines
		if upto > total then
			upto = total
		end
		while computed < upto do
			local index = computed + 1
			local result, nextState = highlightLine(lines[index] or "", states[index])
			rich[index] = result
			states[index + 1] = nextState
			computed = index
		end
	end

	function self:Get(index)
		if index < 1 or index > #lines then
			return ""
		end
		if not rich[index] then
			ensure(index)
		end
		return rich[index]
	end

	function self:Count()
		return #lines
	end

	return self
end

local cache = setmetatable({}, { __mode = "k" })

function Highlight.Lines(lines)
	local cached = cache[lines]
	if cached then
		return cached
	end
	local total = #lines
	local out = table.create(total)
	local state = nil
	for index = 1, total do
		local result, nextState = highlightLine(lines[index] or "", state)
		out[index] = result
		state = nextState
		if index % 2500 == 0 then
			task.wait()
		end
	end
	cache[lines] = out
	return out
end

return Highlight
end

Modules["Theme/Icons"] = function(import)
local Icons = {}

local catalog
local warned = {}

local ALIASES = {
	house = "home",
	["circle-alert"] = "alert-circle",
	["triangle-alert"] = "alert-triangle",
	["circle-x"] = "x-circle",
	["circle-check"] = "check-circle",
	["circle-help"] = "help-circle",
	ellipsis = "more-horizontal",
	["ellipsis-vertical"] = "more-vertical",
	["square-pen"] = "edit-3",
	["pen-line"] = "edit-3",
	["loader-circle"] = "loader-2",
	["chart-line"] = "line-chart",
	["chart-column"] = "bar-chart-3",
	["panel-left"] = "sidebar",
	funnel = "filter",
}

local function load()
	if catalog then
		return catalog
	end
	catalog = {}
	for name, id in string.gmatch(import("Theme/IconCatalog"), "([^;=]+)=([^;]+)") do
		catalog[name] = id
	end
	return catalog
end

function Icons.Id(name)
	if name == nil or name == "" then
		return ""
	end
	if type(name) == "number" then
		return "rbxassetid://" .. tostring(name)
	end
	if string.find(name, "^rbx") then
		return name
	end
	local source = load()
	local id = source[name] or source[ALIASES[name] or ""]
	if not id then
		if not warned[name] then
			warned[name] = true
			warn("missing icon " .. tostring(name))
		end
		id = source["circle-dashed"] or source["square"]
	end
	return "rbxassetid://" .. tostring(id)
end

local sprites
local function loadSprites()
	if sprites then
		return sprites
	end
	sprites = {}
	local ok, source = pcall(function()
		local Env = import("Core/Env")
		return Env.Read(Env.Path("Icon", "lucide-roblox.luau"))
	end)
	if not ok or type(source) ~= "string" then
		return sprites
	end
	local entry = "{%s*(%d+)%s*,%s*{%s*(%d+)%s*,%s*%d+%s*}%s*,%s*{%s*(%d+)%s*,%s*(%d+)%s*}%s*}"
	local function add(name, sheet, width, x, y)
		if width == "48" and sprites[name] == nil then
			sprites[name] = { Image = "rbxassetid://" .. sheet, Size = Vector2.new(48, 48), Offset = Vector2.new(tonumber(x), tonumber(y)) }
		end
	end
	for name, sheet, width, x, y in string.gmatch(source, "%['([%w%-]+)'%]%s*=%s*" .. entry) do
		add(name, sheet, width, x, y)
	end
	for name, sheet, width, x, y in string.gmatch(source, "([%a_][%w_]*)%s*=%s*" .. entry) do
		add(name, sheet, width, x, y)
	end
	return sprites
end

function Icons.Has(name)
	local source = load()
	return source[name] ~= nil or (ALIASES[name] ~= nil and source[ALIASES[name]] ~= nil) or loadSprites()[name] ~= nil
end

function Icons.Names()
	local out = {}
	for name in load() do
		table.insert(out, name)
	end
	for name in loadSprites() do
		if load()[name] == nil then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

function Icons.Register(name, id)
	load()[name] = (string.gsub(tostring(id), "^rbxassetid://", ""))
end

function Icons.Apply(image, name)
	if type(name) == "string" and name ~= "" and not string.find(name, "^rbx") then
		local source = load()
		if source[name] == nil and source[ALIASES[name] or ""] == nil then
			local sprite = loadSprites()[name]
			if sprite then
				image.Image = sprite.Image
				image.ImageRectSize = sprite.Size
				image.ImageRectOffset = sprite.Offset
				return
			end
		end
	end
	if image.ImageRectSize ~= Vector2.zero then
		image.ImageRectSize = Vector2.zero
		image.ImageRectOffset = Vector2.zero
	end
	image.Image = Icons.Id(name)
end

return Icons
end

Modules["Theme/IconCatalog"] = function(import)
return [[a-arrow-down=87834851353233;a-arrow-up=89385437396694;a-large-small=73183249747960;accessibility=109960743825561;activity=137527339160230;activity-square=126953951117387;air-vent=111625153433818;airplay=92171397431531;alarm-check=130501077167542;alarm-clock=118636480109240;alarm-clock-check=70976944787280;alarm-clock-minus=70856300954858;alarm-clock-off=110132709107464;alarm-clock-plus=96736786697131;alarm-minus=77271404005062;alarm-plus=128528043300240;alarm-smoke=76581519928624;album=112445622428637;alert-circle=74115333842618;alert-octagon=138910404523272;alert-triangle=112102474509324;align-center=120408521883501;align-center-horizontal=108597166812858;align-center-vertical=121154206034694;align-end-horizontal=99069601868832;align-end-vertical=117942349521535;align-horizontal-distribute-center=77482483036009;align-horizontal-distribute-end=134639979863642;align-horizontal-distribute-start=134435692726811;align-horizontal-justify-center=92390581039957;align-horizontal-justify-end=104340168067575;align-horizontal-justify-start=78939447794797;align-horizontal-space-around=80515421591545;align-horizontal-space-between=114038806348167;align-justify=92373371786861;align-left=136554315335959;align-right=135067010612236;align-start-horizontal=96834758740744;align-start-vertical=123458513293976;align-vertical-distribute-center=90818078154247;align-vertical-distribute-end=136782098795781;align-vertical-distribute-start=134480830300767;align-vertical-justify-center=130298876730417;align-vertical-justify-end=100777246465864;align-vertical-justify-start=123693071723398;align-vertical-space-around=124225977511288;align-vertical-space-between=81499787439793;ambulance=103392162911629;ampersand=76900943277226;ampersands=86469233094518;anchor=127378493192461;angry=79345553086407;annoyed=104846682265434;antenna=112766612909532;anvil=86432599455606;aperture=139684165362622;app-window=87635787215081;app-window-mac=108549782746996;apple=93203750625654;archive=137249944163344;archive-restore=96820254661076;archive-x=134784309661522;area-chart=107486186614989;armchair=104852764227195;arrow-big-down=134387593103194;arrow-big-down-dash=125189777214718;arrow-big-left=79012356613282;arrow-big-left-dash=132879301629314;arrow-big-right=90405262165720;arrow-big-right-dash=121488142481379;arrow-big-up=95689861013321;arrow-big-up-dash=106976910180035;arrow-down=134161790366779;arrow-down-0-1=140381370510884;arrow-down-1-0=130494621181478;arrow-down-a-z=103554859233661;arrow-down-circle=131404694292521;arrow-down-from-line=81443516391691;arrow-down-left=102509297349411;arrow-down-left-from-circle=73012719459961;arrow-down-left-square=90976696713068;arrow-down-narrow-wide=71046418862578;arrow-down-right=72764732196403;arrow-down-right-from-circle=97668995487103;arrow-down-right-square=128499661363473;arrow-down-square=138838216140198;arrow-down-to-dot=88868273845458;arrow-down-to-line=137644743820952;arrow-down-up=117405374619280;arrow-down-wide-narrow=75826372885867;arrow-down-z-a=118359795316087;arrow-left=90293255250749;arrow-left-circle=130847257582775;arrow-left-from-line=77381869318221;arrow-left-right=112517617090898;arrow-left-square=135104418905606;arrow-left-to-line=130252021035812;arrow-right=134908902120212;arrow-right-circle=94365145580321;arrow-right-from-line=107378199607331;arrow-right-left=111890422557630;arrow-right-square=115337431423227;arrow-right-to-line=103829994761864;arrow-up=104406213770080;arrow-up-0-1=139178256421912;arrow-up-1-0=97298977768167;arrow-up-a-z=97443044644659;arrow-up-circle=75833692771331;arrow-up-down=73746166761985;arrow-up-from-dot=103317134268223;arrow-up-from-line=101711387260955;arrow-up-left=103783370700580;arrow-up-left-from-circle=96382098119619;arrow-up-left-square=101543880954604;arrow-up-narrow-wide=122289869517959;arrow-up-right=115214649052675;arrow-up-right-from-circle=102906718956851;arrow-up-right-square=113196521639031;arrow-up-square=112280252781879;arrow-up-to-line=135365442561417;arrow-up-wide-narrow=79052928363256;arrow-up-z-a=93443333447390;arrows-up-from-line=140178313470659;asterisk=107247711733329;at-sign=94614469252449;atom=119051552929078;audio-lines=133487746892141;audio-waveform=135412900878575;award=82039875682356;axe=84931585672806;axis-3d=83328523632480;baby=75683742350958;backpack=76143965140765;badge=78791133479661;badge-alert=92904571921902;badge-cent=110902979965426;badge-check=76305757263548;badge-dollar-sign=123225256208806;badge-euro=82107326159074;badge-help=83944903318576;badge-indian-rupee=105958255216505;badge-info=109792483526167;badge-japanese-yen=96156476341857;badge-minus=79191240000290;badge-percent=129993801535784;badge-plus=73308743105191;badge-pound-sterling=104904198937382;badge-russian-ruble=91738909980749;badge-swiss-franc=102826901242684;badge-x=117187082865205;baggage-claim=119346910227968;ban=109685306480139;banana=128374499714074;banknote=113703117675594;bar-chart=121570259716677;bar-chart-2=121452498735866;bar-chart-3=130626786024244;bar-chart-4=96221317327213;bar-chart-big=119295298711810;bar-chart-horizontal=109235174327898;bar-chart-horizontal-big=139737497124066;barcode=78580529416152;baseline=116347038683714;bath=89008182357290;battery=102599812606554;battery-charging=91402957855599;battery-full=108407180588179;battery-low=132416805088817;battery-medium=139407584675024;battery-warning=119084304752903;beaker=100026072450383;bean=108654318985558;bean-off=75755103997845;bed=71982795501399;bed-double=97693190540435;bed-single=80557330573152;beef=93001452038647;beer=71718925718592;beer-off=135309228180602;bell=84691420588185;bell-dot=100564215426004;bell-electric=120584905231603;bell-minus=117849268875449;bell-off=115540031372596;bell-plus=85655293455454;bell-ring=71006419366158;between-horizontal-end=97454674221809;between-horizontal-start=122308710081740;between-vertical-end=73288142609772;between-vertical-start=96319480553759;bike=139392597724277;binary=73887562333653;biohazard=137351193301090;bird=78301366757596;bitcoin=87905951788220;blend=99774242136996;blinds=97128563480198;blocks=116361302503360;bluetooth=140648462080543;bluetooth-connected=108047104997672;bluetooth-off=85384277884353;bluetooth-searching=88887842293685;bold=114571598098097;bolt=134172358414310;bomb=85112456002145;bone=110911138031483;book=74111869099427;book-a=130683776374615;book-audio=84765914852101;book-check=116693733550590;book-copy=103556293898971;book-dashed=90144560974060;book-down=102612840928328;book-headphones=101847018803943;book-heart=79225550955168;book-image=97175021450327;book-key=78825638323167;book-lock=136914298397858;book-marked=130311722822005;book-minus=111140800790677;book-open=84762150530577;book-open-check=100175521109916;book-open-text=83251408532985;book-plus=135397977794739;book-text=96481772943887;book-type=80135728169729;book-up=92592832226795;book-up-2=74123009075829;book-user=80586093636888;book-x=75485266769989;bookmark=137439152875860;bookmark-check=103743627936816;bookmark-minus=106761186502279;bookmark-plus=108572239011289;bookmark-x=115354177404954;boom-box=88874304172044;bot=70979486241131;bot-message-square=79709292282995;box=117371753006597;box-select=106969329058115;boxes=95055252135506;braces=92263187057993;brackets=87406077670628;brain=116902501990569;brain-circuit=130830898675113;brain-cog=76347059769903;brick-wall=94677898150825;briefcase=78701740878808;briefcase-business=83989706459460;briefcase-medical=101696204417639;bring-to-front=105016868447258;brush=113475652218451;bug=75649814233484;bug-off=72963988065933;bug-play=109066688101101;building=128630485814878;building-2=97744948701888;bus=115040051931434;bus-front=89834398235413;cable=122718774070506;cable-car=75378206085314;cake=88535465840262;cake-slice=99501344714989;calculator=107281102048400;calendar=126460151885084;calendar-check=116665691227418;calendar-check-2=128139765113287;calendar-clock=91678408267921;calendar-days=83005303274935;calendar-fold=120622111767156;calendar-heart=101728896191412;calendar-minus=97111317408323;calendar-minus-2=114139960753026;calendar-off=72690038281381;calendar-plus=113126930241503;calendar-plus-2=95708816339251;calendar-range=85814519406070;calendar-search=94105486063910;calendar-x=117555084312063;calendar-x-2=137455674513711;camera=114084146151777;camera-off=101456706369049;candlestick-chart=99842864833044;candy=113164012451432;candy-cane=125416183674924;candy-off=122702931937344;captions=105023593632540;captions-off=75480095441780;car=91451724283877;car-front=79993076477613;car-taxi-front=75623233937291;caravan=78521421981947;carrot=71122235024925;case-lower=95359311197985;case-sensitive=133603526051277;case-upper=77340278207531;cassette-tape=113140472253110;cast=119573692041871;castle=104598700669384;cat=118339348494810;cctv=84978679477516;check=86817768619372;check-check=101885204738917;check-circle=105979545056636;check-circle-2=76928915955542;check-square=135686334400788;check-square-2=84113739446686;chef-hat=94153362248387;cherry=116326418543667;chevron-down=71457658246709;chevron-down-circle=130642617728982;chevron-down-square=84683053234548;chevron-first=70831710633364;chevron-last=102556054621077;chevron-left=102314312897830;chevron-left-circle=70732746220332;chevron-left-square=78492542000164;chevron-right=101007429951147;chevron-right-circle=87038574131735;chevron-right-square=119136642030742;chevron-up=98648581502859;chevron-up-circle=111681831848531;chevrons-down=84492998086101;chevrons-down-up=82103880591342;chevrons-left=87881912126351;chevrons-left-right=132331219761704;chevrons-right=134353805354361;chevrons-right-left=96783734429291;chevrons-up=88461690106632;chevrons-up-down=71880540200693;circle-arrow-down=129076838165145;circle-arrow-left=88796613571531;circle-arrow-out-down-left=107231337431973;circle-arrow-out-down-right=70490689174861;circle-arrow-out-up-left=79479678307645;circle-arrow-out-up-right=127093834620465;circle-arrow-right=97664127355280;circle-arrow-up=72634350793509;circle-check=88244323237265;circle-check-big=105847305799404;circle-chevron-down=88531529614731;circle-chevron-left=109806050128867;circle-chevron-right=130159833971034;circle-chevron-up=126990996679640;circle-dashed=122032109800866;circle-divide=136980096833105;circle-dollar-sign=102720278203768;circle-dot=122878673716704;circle-dot-dashed=107222591318022;circle-ellipsis=72989868902667;circle-equal=83415595687523;circle-fading-plus=97734885169321;circle-gauge=79712667314679;circle-help=132353516577418;circle-minus=98163850412523;circle-off=95467094528299;circle-parking=117482323268433;circle-parking-off=80459013698184;circle-pause=88794740338426;circle-percent=125429815212970;circle-play=84481789029543;circle-plus=117262167984222;circle-power=127349877206105;circle-slash=98431785453122;circle-slash-2=79541029224240;circle-stop=109423106908446;circle-user=87167719100614;circle-user-round=113831490904568;circle-x=106305483906363;circuit-board=124136951218642;citrus=79624448772527;clapperboard=132343838416956;clipboard=105021692319787;clipboard-check=90432969741774;clipboard-copy=85387882337161;clipboard-edit=131193135046966;clipboard-list=129402512748462;clipboard-minus=94779294031183;clipboard-paste=79192963603923;clipboard-pen=99195778697194;clipboard-pen-line=103555830963651;clipboard-plus=74352366953056;clipboard-signature=120750772696869;clipboard-type=132835545998943;clipboard-x=132658738057667;clock=136533241128438;clock-1=71498600757409;clock-10=123641121766955;clock-11=85845500811663;clock-12=133878455420257;clock-2=102975079908275;clock-3=119663119982527;clock-4=108792000100666;clock-5=97840714155038;clock-6=102025123837297;clock-7=110824271252901;clock-8=123515589399454;clock-9=126662391246112;cloud=136524873450824;cloud-cog=108438517119798;cloud-download=78768373704516;cloud-drizzle=80789072164434;cloud-fog=110403642693501;cloud-hail=95998880244047;cloud-lightning=118391347029403;cloud-moon=120156057895579;cloud-moon-rain=101513348432910;cloud-off=111796785870393;cloud-rain=130177212410873;cloud-rain-wind=87893934921731;cloud-snow=104971371973617;cloud-sun=140109651313859;cloud-sun-rain=132138781511885;cloud-upload=86452290950086;cloudy=132267475821363;clover=128291338532394;club=83110975306436;code=75851496262862;code-2=79541605299928;code-xml=106124864132557;codepen=131077252082543;codesandbox=139298967633423;coffee=125329933348791;cog=123222732420633;coins=117341212186115;columns=96838631255058;columns-2=110924811097991;columns-3=88214025452433;columns-4=100379574150921;combine=103133480717944;command=90385430770591;compass=73836660434977;component=106556990975641;computer=72888027377165;concierge-bell=134373387272639;cone=80255197365555;construction=77845797691565;contact=102372888309353;contact-2=100454539997812;contact-round=117599766367773;container=135116917100753;contrast=71154426791470;cookie=96083862569395;cooking-pot=100393801714299;copy=116378866141355;copy-check=92397569046734;copy-minus=75815893695780;copy-plus=138173295478363;copy-slash=74395410823283;copy-x=98741265066436;copyleft=103019482632984;copyright=82044483134605;corner-down-left=105689000447775;corner-down-right=82061714010896;corner-left-down=133517193053100;corner-left-up=78035789940893;corner-right-down=135390474501786;corner-right-up=122661540167291;corner-up-left=72973602941956;corner-up-right=108297458644964;cpu=105237370909681;creative-commons=111243376462256;credit-card=124946887228472;croissant=77683374738482;crop=121481502611712;cross=93673591064028;crosshair=83752373575368;crown=92253403464658;cuboid=117329818290748;cup-soda=132120247880161;currency=96706001818192;cylinder=99158693669056;database=99154172590159;diamond=136889727768904;diamond-percent=138695404542126;dice-1=133629376866649;dice-2=137517882571271;dice-3=128612626459042;dice-4=73117400593570;dice-5=107643287892749;dice-6=112067139297943;dices=116678154854810;diff=122850860032588;disc=77318106935130;disc-2=135460247355994;disc-3=118087373340436;disc-album=101298984360789;divide=134571770296218;divide-circle=115849848955050;divide-square=78617148972524;dna=131581201333424;dna-off=90101733367858;dock=96133720652582;dog=123749328846346;dollar-sign=74567340201672;donut=123909563150383;door-closed=118483980594708;door-open=124230332524625;dot=105006331197983;download=109698732019071;download-cloud=122841052352556;drafting-compass=110585086142082;drama=138828515077300;dribbble=112906380564504;drill=113833078477512;droplet=91586468475195;droplets=117720354071548;drum=121019656655547;drumstick=106711459328737;dumbbell=130873531670678;ear=92631431780796;ear-off=81480882487332;earth=75025349205767;earth-lock=103673515494330;eclipse=113566298471092;egg=103880404435578;egg-fried=137654273789326;egg-off=99146230558760;ellipsis=95127553964880;ellipsis-vertical=95771045694204;equal=79273099065269;eraser=71210100060694;euro=139202392240827;expand=107643532357936;external-link=78664150174274;eye=127234874352422;eye-off=85207295981701;facebook=98822363427090;factory=79319339232812;fan=76323281744636;fast-forward=131011550754955;feather=103991922506350;fence=90935998613863;ferris-wheel=94538249337586;figma=103020132259719;file=108499043987115;file-archive=78133118745021;file-audio=101306436065858;file-audio-2=103353018363480;file-axis-3d=136107008496948;file-badge=135829024450190;file-badge-2=87916835926622;file-bar-chart=92900624303400;file-bar-chart-2=133337118425916;file-box=102441183584476;file-check=91719007832323;file-check-2=120611252466724;file-clock=101240345040794;file-code=93918366472395;file-code-2=77999709917415;file-cog=130835463141181;file-diff=132890714271689;file-digit=108016195781167;file-down=79495546108963;file-edit=82156880342025;file-heart=138364329637312;file-image=83675710276234;file-input=78561929224193;file-json=98868866618869;file-json-2=92610524789574;file-key=83249504215614;file-key-2=103006369640378;file-line-chart=84182680444173;file-lock=140186307068344;file-lock-2=126656887901996;file-minus=138371877961417;file-minus-2=107551117550330;file-music=107180630571772;file-output=109566424197143;file-pen=134577965177665;file-pen-line=90852962587361;file-pie-chart=94554256943610;file-plus=74194167957081;file-plus-2=111571245681686;file-question=128415338385227;file-scan=132590981389921;file-search=131130928074464;file-search-2=139930116408040;file-signature=87096324580559;file-sliders=133181135528313;file-spreadsheet=117808207510717;file-stack=132187715148899;file-symlink=122206323516270;file-terminal=91847143440556;file-text=92774566080911;file-type=139551268989315;file-type-2=91173675777316;file-up=99191463679083;file-video=105252283775469;file-video-2=130213998083954;file-volume=119603558694315;file-volume-2=139949156797892;file-warning=89824347717079;file-x=117124390222574;file-x-2=136449417648465;files=78685849153126;film=120941801045330;filter=100930784445785;filter-x=85838104400923;fingerprint=109514257830136;fire-extinguisher=84862159260845;fish=114555142566431;fish-off=99443044829026;fish-symbol=123702927226939;flag=121835250831612;flag-off=90046025355940;flag-triangle-left=73117581559482;flag-triangle-right=106524126597496;flame=125012650497883;flame-kindling=136834319064926;flashlight=110881718712443;flashlight-off=117038550056668;flask-conical=115528123394259;flask-conical-off=102385597737770;flask-round=118701306736141;flip-horizontal=76347241876815;flip-horizontal-2=107329750779249;flip-vertical=121575310281690;flip-vertical-2=77578710261033;flower=98459040977090;flower-2=79478214327919;focus=116191961683883;fold-horizontal=133102230855922;fold-vertical=128556601978376;folder=77937190465422;folder-archive=96956679126324;folder-check=95477621394824;folder-clock=137926892639070;folder-closed=86427718056887;folder-cog=127866486547434;folder-dot=129773010201383;folder-down=82793534945672;folder-edit=102495189191583;folder-git=104507928948019;folder-git-2=85014883332248;folder-heart=110088173047332;folder-input=132837435930621;folder-kanban=138103158509024;folder-key=130401922270021;folder-lock=111493727654155;folder-minus=97790081587083;folder-open=112237915867403;folder-open-dot=90332268376865;folder-output=125946013402264;folder-pen=81838874164795;folder-plus=71462957431660;folder-root=80403663819762;folder-search=109602276944932;folder-search-2=74614286288240;folder-symlink=89907141903257;folder-sync=137088423628527;folder-tree=78199416535568;folder-up=85416900334449;folder-x=103887939759350;folders=97828544806816;footprints=80792036653047;forklift=117529645336183;form-input=73368443063193;forward=78301309129142;frame=81913255681858;framer=117525065607897;frown=88589722723911;fuel=112915457104961;fullscreen=92176335589571;function-square=77009803117016;gallery-horizontal=113964455804231;gallery-horizontal-end=125589356860308;gallery-thumbnails=123093292028306;gallery-vertical=109130466006021;gallery-vertical-end=122352399696695;gamepad=81482768981191;gamepad-2=99293705721130;gantt-chart=122456724985241;gantt-chart-square=73571197135748;gauge=128279962545721;gauge-circle=110231832967256;gavel=118993398179839;gem=125353572203968;ghost=132705178126217;gift=87706885156127;git-branch=101518089376526;git-branch-plus=127909649257701;git-commit-horizontal=91306319670540;git-commit-vertical=101185915909200;git-compare=134611228556653;git-compare-arrows=134203912676625;git-fork=138214272765755;git-graph=126789259203618;git-merge=118868315103570;git-pull-request=117991178843732;git-pull-request-arrow=133155768650667;git-pull-request-closed=74188383635944;git-pull-request-create=108540858735398;git-pull-request-create-arrow=75317536980451;git-pull-request-draft=127220095778670;github=140138081031269;gitlab=109316577965403;glass-water=125170765146614;glasses=77027406085123;globe=125685532120024;globe-2=112945472486319;globe-lock=96469366281710;goal=90015442702200;grab=117741873625250;graduation-cap=140187510907091;grape=73195418744413;grid-2x2=134599229810680;grid-3x3=108197747587523;grip=88188569450143;grip-horizontal=72027364608348;grip-vertical=136050395759142;group=79946652686375;guitar=135654565391445;ham=134057117057030;hammer=73956316105509;hand=83088528355903;hand-coins=85922324710029;hand-heart=124155721578457;hand-helping=95094264299544;hand-metal=105555696144202;hand-platter=101356141176839;handshake=121760224402586;hard-drive=115211376876196;hard-drive-download=115854711953657;hard-drive-upload=112990104477043;hard-hat=105207891316460;hash=128945191245705;haze=86624380139587;hdmi-port=123935181216786;heading=115666667306834;heading-1=82056941503516;heading-2=109194333144049;heading-3=86456694536830;heading-4=108808532352504;heading-5=84468448396475;heading-6=70885434512827;headphones=89990513082092;headset=77155289443816;heart=88525382655929;heart-crack=78532998725036;heart-handshake=88807882205984;heart-off=121500734414824;heart-pulse=101116623654468;heater=75867015789217;help-circle=71693802872044;helping-hand=82838882533396;hexagon=111932983587355;highlighter=124195908160173;history=70375455140492;home=109841253338329;hop=87886892027508;hop-off=124047203843704;hospital=100542468114469;hotel=88463240253197;hourglass=135654740495171;ice-cream=95314536020685;ice-cream-2=93935347717656;ice-cream-bowl=116507918255217;ice-cream-cone=72823870951577;image=114022611279795;image-down=91697762317652;image-minus=111691180013117;image-off=113890586559666;image-plus=131640557457656;image-up=95362531246536;images=87539822715105;import=87776530532335;inbox=131993988107472;indent=111431763044113;indent-decrease=77902371540680;indent-increase=116043459584133;indian-rupee=121515804799242;infinity=77975814002740;info=120620848266512;inspection-panel=93487140703578;instagram=88504800931130;italic=96844815325902;iteration-ccw=114475186061127;iteration-cw=130833288197698;japanese-yen=108845518454015;joystick=75024649968329;kanban=132557744047883;kanban-square=124564901729634;kanban-square-dashed=134205902924289;key=83474888140571;key-round=116918931002434;key-square=79693131186843;keyboard=121978468376124;keyboard-music=74763240290099;lamp=123765123149989;lamp-ceiling=120174084956571;lamp-desk=125995036157694;lamp-floor=102217348025530;lamp-wall-down=134067530649420;lamp-wall-up=101034120941267;land-plot=114974071140535;landmark=130189940998950;languages=130065428637597;laptop=103798905446648;laptop-2=106021728338003;laptop-minimal=91920768368168;lasso=110262485516329;lasso-select=112600066891219;laugh=115974660887808;layers=114499998778667;layers-2=87219208863328;layers-3=114549653986465;layout=75056433029964;layout-dashboard=70433574792490;layout-grid=89644754139307;layout-list=72384664085473;layout-panel-left=117264898598467;layout-panel-top=135570881026156;layout-template=78078135578383;leaf=70846801126940;leafy-green=94770162749325;library=114050057679028;library-big=135791941822287;library-square=132158761398954;life-buoy=99147024142900;ligature=75804099923602;lightbulb=98419938500979;lightbulb-off=126746194476977;line-chart=115214641333880;link=86131768436965;link-2=107339085791087;link-2-off=74994782779018;linkedin=102928864661994;list=101699539545687;list-checks=133109875194066;list-collapse=103651151660786;list-end=116487672075047;list-filter=83186010624431;list-minus=119184210915074;list-music=88988800995482;list-ordered=100068475590931;list-plus=124010335412192;list-restart=91193864293753;list-start=131366235513143;list-todo=83287488939815;list-tree=127759805921507;list-video=117978552190904;list-x=115746075160943;loader=132295854994374;loader-2=128780061297692;loader-circle=71250150569964;locate=106821189831430;locate-fixed=80648116191645;locate-off=121088730454886;lock=119765975153029;lock-keyhole=135504457058301;lock-keyhole-open=132192657766903;lock-open=71186154315213;log-in=82241120685313;log-out=140299936053191;lollipop=102239398934579;luggage=140614046877100;m-square=97856747717836;magnet=97474941633274;mail=77537514051485;mail-check=90824179551389;mail-minus=104189493909738;mail-open=74874447671108;mail-plus=130540869833539;mail-question=128924135790205;mail-search=108269769085404;mail-warning=126275145590627;mail-x=97229750262408;mailbox=104064071799815;mails=120925930542398;map=131325044235094;map-pin=137091405832737;map-pin-off=130126969919710;map-pinned=78894827751778;martini=108853683970464;maximize=116546384863431;maximize-2=130049637400171;medal=97534791863003;megaphone=139746713205639;megaphone-off=130364738220291;meh=117127044934876;memory-stick=82464660673318;menu=83047518441184;menu-square=84168857053009;merge=96640473379848;message-circle=74163263000218;message-circle-code=124462142601421;message-circle-dashed=78559601215727;message-circle-heart=122100978068245;message-circle-more=72969556529414;message-circle-off=106640802525475;message-circle-plus=97202853233666;message-circle-question=85003442346058;message-circle-reply=96024981688039;message-circle-warning=112239075926369;message-circle-x=104081317224904;message-square=86432989388834;message-square-code=139338315973052;message-square-dashed=127422492651127;message-square-diff=120745701209397;message-square-dot=131246995114947;message-square-heart=137436561363370;message-square-more=76812000893936;message-square-off=97376166485199;message-square-plus=77957118386462;message-square-quote=97203851012575;message-square-reply=138540430807955;message-square-share=94526690702300;message-square-text=128095657789286;message-square-warning=83694786088101;message-square-x=83972010967159;messages-square=112345482432498;mic=125870172276779;mic-2=79774423165436;mic-off=84064988822624;mic-vocal=116345765074785;microscope=134078584568005;microwave=109575331253451;milestone=88614752388873;milk=119818923307142;milk-off=72925919409773;minimize=95555494586098;minimize-2=96294437144715;minus=95070996149109;minus-circle=103303552772654;minus-square=96983863580751;monitor=70520152532392;monitor-check=112341875921743;monitor-dot=132673547251589;monitor-down=132502390896673;monitor-off=95048101284680;monitor-pause=99458637542686;monitor-play=107640137618506;monitor-smartphone=81757216234228;monitor-speaker=131099454095944;monitor-stop=99235976282671;monitor-up=116018518624879;monitor-x=102604336229610;moon=98353636264918;moon-star=137086737657962;more-horizontal=101330725759187;more-vertical=76302166494262;mountain=90592200130155;mountain-snow=111710418991773;mouse=122014945028597;mouse-pointer=113428527051320;mouse-pointer-2=84070353881242;mouse-pointer-click=81854854241463;mouse-pointer-square=112337311970951;mouse-pointer-square-dashed=80677641664079;move=77028714324861;move-3d=82487420092874;move-diagonal=111179404262244;move-diagonal-2=128492050787735;move-down=85099736811132;move-down-left=138054515129112;move-down-right=116621809745618;move-horizontal=136107424781093;move-left=89444723083105;move-right=133586722586273;move-up=76410952730524;move-up-left=102293680652367;move-up-right=88087592569369;move-vertical=92087242547029;music=132132095360900;music-2=121112248614371;music-3=75731760539974;music-4=122935411241955;navigation=76549947719521;navigation-2=127270865325663;navigation-2-off=74005663669130;navigation-off=96787422854853;network=110230147673946;newspaper=115179113478597;nfc=119131457808272;notebook=93996170225525;notebook-pen=70494109504383;notebook-tabs=113749031276097;notebook-text=86811328922423;notepad-text=104957079697866;notepad-text-dashed=113624610966525;nut=77621843968987;nut-off=84877157781266;octagon=103646759535962;octagon-alert=101226496664732;octagon-pause=127095623629829;octagon-x=103912968479362;option=77581357923982;orbit=79200159961573;outdent=136657573552804;package=106101842173393;package-2=76736374924338;package-check=100671298334773;package-minus=72114807005321;package-open=86470175749466;package-plus=74357376952178;package-search=108965513580143;package-x=80178189812476;paint-bucket=116536780343642;paint-roller=76545833297923;paintbrush=113234034461805;paintbrush-2=116925836096427;palette=127369887384101;palmtree=85651135388680;panel-bottom=86537618399617;panel-bottom-close=91281796987492;panel-bottom-dashed=130167117027190;panel-bottom-inactive=97483023786802;panel-bottom-open=86549932703136;panel-left=125599129725759;panel-left-close=106532774300164;panel-left-dashed=115976249358122;panel-left-inactive=102689057283340;panel-left-open=126704485649345;panel-right=83386566029978;panel-right-close=133236216519470;panel-right-dashed=138321632890167;panel-right-inactive=95197732140314;panel-right-open=107436518875633;panel-top=80001561556081;panel-top-close=124467779594157;panel-top-dashed=79452019243803;panel-top-inactive=135806161551683;panel-top-open=88468571469051;panels-left-bottom=100709335124708;panels-right-bottom=118563843738058;panels-top-left=119230493302275;paperclip=101144735754292;parentheses=117743859847736;parking-circle=132958171449207;parking-circle-off=90293787674695;parking-meter=95540023655686;parking-square=119709845027214;parking-square-off=111516007201199;party-popper=92886643958723;pause=79610666871575;pause-circle=121009275520669;pause-octagon=75691149975017;paw-print=97578437331341;pc-case=134071343822649;pen=101486948449510;pen-line=108991407462745;pen-square=124290018373176;pen-tool=126917951709518;pencil=113132794872298;pencil-line=97622550721067;pencil-ruler=83914055949508;pentagon=133006808893408;percent=138143948353522;percent-circle=120133426400204;percent-diamond=116484660741674;percent-square=123104718284792;person-standing=101118444346965;phone=110402416146068;phone-call=83844308787978;phone-forwarded=121647613341736;phone-incoming=80024725665109;phone-missed=79555645036339;phone-off=124218610436691;phone-outgoing=107942094735434;pi=94324814221349;pi-square=104995627137456;piano=119387553084830;pickaxe=111300940329486;picture-in-picture=131356651374909;picture-in-picture-2=82685697007608;pie-chart=102602815840153;piggy-bank=137519559090410;pilcrow=73426591830540;pilcrow-square=104294263901485;pill=102063979166015;pin=84152083728286;pin-off=79775551915820;pipette=104047428948587;pizza=137422469806542;plane=123931033451986;plane-landing=127564654216931;plane-takeoff=71424495151201;play=76386816441302;play-circle=94679908148591;play-square=88949301532557;plug=92495517782055;plug-2=90278231790155;plug-zap=120081085677067;plug-zap-2=114634662672913;plus=101123124881873;plus-circle=120968869021626;plus-square=110356023190006;pocket=84604104357709;pocket-knife=75327579226876;podcast=107827753005302;pointer=98931495397575;pointer-off=121208450103912;popcorn=131831744800890;popsicle=104185203372496;pound-sterling=104324833143828;power=89331085993646;power-circle=116376776686511;power-off=71082730746769;power-square=119684962977179;presentation=116401163910084;printer=71465784501775;projector=73231680903652;proportions=78144579158638;puzzle=117598556369229;pyramid=132485249599747;qr-code=113440393569209;quote=131322529504476;rabbit=114280087699339;radar=132868138496209;radiation=100877813176471;radical=108409175619446;radio=99420757373028;radio-receiver=121282639721016;radio-tower=88833838205757;radius=74995747675698;rail-symbol=97316226200213;rainbow=103765621191575;rat=87357329634876;ratio=93282099315884;receipt=92008292109070;receipt-cent=112492211580771;receipt-euro=133191175020669;receipt-indian-rupee=133266746153788;receipt-japanese-yen=124042872765776;receipt-pound-sterling=100101322122623;receipt-russian-ruble=121506664677675;receipt-swiss-franc=99002246681862;receipt-text=100006409297382;rectangle-ellipsis=107119201863591;rectangle-horizontal=138840515431449;rectangle-vertical=105899574411289;recycle=113939163175897;redo=109330889951617;redo-2=139377644547969;redo-dot=103006780441917;refresh-ccw=112330254035751;refresh-ccw-dot=82338761134697;refresh-cw=106497040962250;refresh-cw-off=70915551154203;refrigerator=112780018998815;regex=134026857287988;remove-formatting=138608399804923;repeat=88751041821881;repeat-1=83172378763568;repeat-2=103267027937654;replace=107047557421203;replace-all=100838712445846;reply=92729212112550;reply-all=89383445888953;rewind=112118266859844;ribbon=138074895056157;rocket=109537053598807;rocking-chair=78801538856684;roller-coaster=97027135474963;rotate-3d=97818595741565;rotate-ccw=75086444429266;rotate-ccw-square=109860100695153;rotate-cw=83145058297547;rotate-cw-square=125618900116298;route=92054788599928;route-off=84281383994516;router=137822323057124;rows=137919453076186;rows-2=95783038014917;rows-3=120887473789104;rows-4=116714271746099;rss=133733106949535;ruler=84633402845324;russian-ruble=126835196314974;sailboat=95990070790702;salad=126822773594847;sandwich=125331738014611;satellite=76405829153460;satellite-dish=80919601328215;save=122894934359450;save-all=130108174247404;scale=104058148891720;scale-3d=98514591753294;scaling=101030566996452;scan=125367266780285;scan-barcode=97414347978098;scan-eye=109514269737059;scan-face=98379048258175;scan-line=74491678843147;scan-search=133304136560518;scan-text=135056446730766;scatter-chart=74267179296978;school=127958337382355;school-2=85807427737192;scissors=105992192896067;scissors-line-dashed=136613376152055;scissors-square=74695197837525;scissors-square-dashed-bottom=107920465612561;screen-share=77511025094385;screen-share-off=121685614490746;scroll=120140373437385;scroll-text=93551675076113;search=72296609649861;search-check=135876289053244;search-code=96217854889522;search-slash=103651057689299;search-x=107116182495739;send=94849431195865;send-horizontal=71350661970492;send-to-back=128357510439179;separator-horizontal=138451510103519;separator-vertical=136594330269338;server=105706502741449;server-cog=100022312079887;server-crash=87758222542375;server-off=80255747106695;settings=106205298246017;settings-2=109485777305919;shapes=72318824907864;share=78225483239202;share-2=139712792470775;sheet=74805372511449;shell=103995324275618;shield=106509993556171;shield-alert=91754324662625;shield-ban=124352578023288;shield-check=71867984579031;shield-ellipsis=93065391097116;shield-half=123735656472960;shield-minus=80388855203128;shield-off=98525250043109;shield-plus=121205118266112;shield-question=114815120818758;shield-x=75826463279777;ship=98574156558498;ship-wheel=130141263234416;shirt=128162112866809;shopping-bag=121389568871142;shopping-basket=110161824939086;shopping-cart=79435149356304;shovel=96637119542790;shower-head=114908638980660;shrink=115135316516120;shrub=79864992147519;shuffle=103735725549548;sigma=74383416855806;sigma-square=132360260153111;signal=126197135689656;signal-high=93347669262895;signal-low=84665611291998;signal-medium=75062813653519;signal-zero=109850227743382;signpost=97962937781200;signpost-big=87216549939239;siren=81845882921662;skip-back=137660494219613;skip-forward=121822124041513;skull=101060850237115;slack=107723459729315;slash=77878973734361;slice=140518011325498;sliders=105166722651208;sliders-horizontal=125396339381135;sliders-vertical=75780544616650;smartphone=74962751233767;smartphone-charging=86644420255103;smartphone-nfc=121578015636822;smile=129431925610335;smile-plus=83315367165388;snail=104438747965017;snowflake=70879271596915;sofa=87577807512220;soup=123867447658880;space=86056382889566;spade=121221766194945;sparkle=83114431765537;sparkles=105634041692696;speaker=117894179084666;speech=86788645272110;spell-check=139048235918692;spell-check-2=77691901804556;spline=127621289965723;split=124184087776521;split-square-horizontal=71187946462875;split-square-vertical=77254227779817;spray-can=97652569554326;sprout=100976494216154;square=135105418501265;square-activity=123457120309378;square-arrow-down=116832660638208;square-arrow-down-left=90743878595626;square-arrow-down-right=111115470362134;square-arrow-left=118414350090559;square-arrow-out-down-left=118423572451505;square-arrow-out-down-right=82860326458804;square-arrow-out-up-left=107517171610982;square-arrow-out-up-right=96480170164917;square-arrow-right=137471464720012;square-arrow-up=130005030476582;square-arrow-up-left=103366812234876;square-arrow-up-right=80186154045078;square-asterisk=85576779554554;square-bottom-dashed-scissors=105977668655594;square-check=122631573561562;square-check-big=139404784607168;square-chevron-down=120680078209607;square-chevron-left=75397936728579;square-chevron-right=76189118488226;square-chevron-up=97181506287521;square-code=76845656194464;square-dashed-bottom=133040895929365;square-dashed-bottom-code=103061363625640;square-dashed-kanban=114545633956348;square-dashed-mouse-pointer=123670726680392;square-divide=107353979642451;square-dot=110899495515389;square-equal=124042600382551;square-function=83985860709793;square-gantt-chart=107284369076219;square-kanban=97476877950543;square-library=81887890003221;square-m=135912337332436;square-menu=135438142591878;square-minus=78721357781624;square-mouse-pointer=127552100194692;square-parking=91463654971693;square-parking-off=111927816549509;square-pen=71257379947442;square-percent=113289006657504;square-pi=132511605174622;square-pilcrow=87094629814766;square-play=138697695062525;square-plus=91942389112860;square-power=120703265040347;square-radical=134223878880054;square-scissors=78779074277571;square-sigma=94523643558062;square-slash=78987954134223;square-split-horizontal=125857047694996;square-split-vertical=126418050285776;square-stack=94687061933604;square-terminal=75828907654568;square-user=140235161621168;square-user-round=81288587564855;square-x=76206131996728;squircle=99439828273252;squirrel=120668151944533;stamp=85130810524517;star=72669221096319;star-half=80822269649856;star-off=120003686620511;step-back=120706787286328;step-forward=91046009066136;stethoscope=78571774060105;sticker=139865196874378;sticky-note=98432110278865;stop-circle=97489143368359;store=121962391563311;stretch-horizontal=78770748920269;stretch-vertical=85907320465911;strikethrough=90568214674515;subscript=82653949184992;subtitles=134234590631375;sun=139232691165198;sun-dim=131075444152110;sun-medium=112704797109150;sun-moon=121221641564933;sun-snow=83004210487318;sunrise=116733420530374;sunset=101740056345650;superscript=93191189359166;swatch-book=70990631477660;swiss-franc=72116456510352;switch-camera=124033626341331;sword=121406454377051;swords=99199363807265;syringe=86444160764731;table=100826532869925;table-2=129391889722576;table-cells-merge=118490713113220;table-cells-split=113945031629733;table-columns-split=79195518284331;table-properties=135976623395143;table-rows-split=126696533672175;tablet=90619723471983;tablet-smartphone=78186066591210;tablets=88043022962639;tag=75425807137911;tags=103166221753217;tally-1=90000711698807;tally-2=99935651880614;tally-3=98958831676946;tally-4=128656473677471;tally-5=101955254503648;tangent=103123484115035;target=121091323240554;telescope=103588488639070;tent=91768489962137;tent-tree=85050403463582;terminal=102379915564176;terminal-square=89706340938367;test-tube=139701481278358;test-tube-2=118913572969135;test-tube-diagonal=121621592892259;test-tubes=117323642962952;text=99369759989955;text-cursor=103697482936876;text-cursor-input=84912489891242;text-quote=102573021965795;text-search=114489224126711;text-select=99310852917353;theater=89919220874053;thermometer=90545345642681;thermometer-snowflake=138010690931368;thermometer-sun=82795165216031;thumbs-down=73778874448741;thumbs-up=96046658888813;ticket=126875062984266;ticket-check=117888043623314;ticket-minus=89176175166723;ticket-percent=88410626824232;ticket-plus=83968600419805;ticket-slash=79392492298521;ticket-x=86658718829072;timer=120164083411828;timer-off=116991705734594;timer-reset=79948324123231;toggle-left=105639191695402;toggle-right=129483325318573;tornado=93796857097422;torus=78822043673501;touchpad=112333029100357;touchpad-off=86546394503986;tower-control=128131047012652;toy-brick=81793486260595;tractor=87948191954230;traffic-cone=87190332091101;train-front=91480038985820;train-front-tunnel=77194453402235;train-track=105798879242186;tram-front=80023103356955;trash=94712995845562;trash-2=126010725826757;tree-deciduous=109951315210525;tree-palm=111070569131758;tree-pine=71580980892868;trees=79707751200645;trello=90438659765426;trending-down=122658819043338;trending-up=86000419326493;triangle=134878256295114;triangle-alert=91165848022002;triangle-right=105796120965583;trophy=113055182645565;truck=125468675952181;turtle=73899487161474;tv=130308429701946;tv-2=129500347007411;twitch=90697389361633;twitter=90424880717042;type=70694319369829;umbrella=108749598923776;umbrella-off=111820268638089;underline=127096081441525;undo=111464695038355;undo-2=87358323292564;undo-dot=102793353935041;unfold-horizontal=85781955020909;unfold-vertical=122887666597646;ungroup=76318446818069;university=102146636224428;unlink=102194562745333;unlink-2=108239607794680;unlock=110263656507369;unlock-keyhole=126931549237422;unplug=123150141199349;upload=118488857289315;upload-cloud=121807815408739;usb=75949167692936;user=114567720540659;user-2=92481398073007;user-check=75620511859505;user-check-2=73224920504446;user-circle=111917761312899;user-circle-2=96888447186214;user-cog=87518742987519;user-cog-2=115462370853742;user-minus=94865546608687;user-minus-2=93808234717021;user-plus=101184880550364;user-plus-2=104764183758140;user-round=119713822992150;user-round-check=99288072031664;user-round-cog=127120627937146;user-round-minus=129866427748569;user-round-plus=101991526004413;user-round-search=114857943818454;user-round-x=89227016198055;user-search=110388873642450;user-square=136305896243658;user-square-2=71391894371551;user-x=138436637971548;user-x-2=96976557144947;users=85332511060401;users-2=138651149526372;users-round=103880524805720;utensils=122537080261787;utensils-crossed=100229317932246;utility-pole=137834357386674;variable=73932604072578;vault=107415856993701;vegan=127691293819852;venetian-mask=84202958608655;vibrate=140427675871522;vibrate-off=102494346080496;video=99411215690870;video-off=81634790888002;videotape=92799250697204;view=102821349715124;voicemail=121299677348672;volume=127607149758269;volume-1=115207748957226;volume-2=129861259578431;volume-x=106700331106145;vote=137637654521705;wallet=132318555862654;wallet-2=120839431200970;wallet-cards=86866924072285;wallet-minimal=77655892701714;wallpaper=76631821212930;wand=95424916372879;wand-2=84750107238092;wand-sparkles=115623066336607;warehouse=126757874656976;washing-machine=72331434583186;watch=103181426780078;waves=98840358372718;waypoints=101997233404191;webcam=90027890284611;webhook=110638252405523;webhook-off=71995352392407;weight=79312026690586;wheat=115823998996262;wheat-off=110571881208127;whole-word=110504483563993;wifi=104941258142372;wifi-off=120795495190257;wind=86165302601843;wine=101623153529226;wine-off=131814228138093;workflow=78971198932745;worm=98855303743824;wrap-text=70866394776130;wrench=85345725497834;x=116396312853810;x-circle=111132030834422;x-octagon=105062643930018;x-square=115678228554812;youtube=134880265650906;zap=109718589733073;zap-off=115642996489807;zoom-in=135570550221809;zoom-out=100181096350591]]
end

Modules["Theme/Theme"] = function(import)
local Signal = import("Core/Signal")
local Store = import("Core/Store")

local Theme = {}

local function hex(value)
	value = string.gsub(value, "#", "")
	return Color3.fromRGB(tonumber(string.sub(value, 1, 2), 16), tonumber(string.sub(value, 3, 4), 16), tonumber(string.sub(value, 5, 6), 16))
end
Theme.Hex = hex

Theme.Accents = {
	{ Name = "Crimson", Color = hex("E5243B") },
	{ Name = "Blood", Color = hex("B3121F") },
	{ Name = "Scarlet", Color = hex("FF3B3B") },
	{ Name = "Ember", Color = hex("FF5533") },
	{ Name = "Rose", Color = hex("F43F5E") },
	{ Name = "Garnet", Color = hex("9F1239") },
}

Theme.Surfaces = {
	Onyx = {
		Shade = hex("050506"),
		Base = hex("09090B"),
		Panel = hex("0E0E11"),
		Raised = hex("141418"),
		Field = hex("19191E"),
		Hover = hex("1D1D23"),
		Pressed = hex("25252C"),
		Line = hex("222229"),
		LineStrong = hex("30303A"),
		Text = hex("EDEDF0"),
		Muted = hex("A1A1AC"),
		Faint = hex("62626C"),
	},
	Graphite = {
		Shade = hex("0A0A0C"),
		Base = hex("111114"),
		Panel = hex("16161A"),
		Raised = hex("1C1C21"),
		Field = hex("222228"),
		Hover = hex("27272E"),
		Pressed = hex("303038"),
		Line = hex("2C2C34"),
		LineStrong = hex("3A3A44"),
		Text = hex("F0F0F3"),
		Muted = hex("A8A8B3"),
		Faint = hex("6B6B76"),
	},
	Void = {
		Shade = hex("000000"),
		Base = hex("000000"),
		Panel = hex("060607"),
		Raised = hex("0C0C0E"),
		Field = hex("121215"),
		Hover = hex("17171B"),
		Pressed = hex("1F1F24"),
		Line = hex("1A1A1F"),
		LineStrong = hex("27272E"),
		Text = hex("EDEDF0"),
		Muted = hex("9A9AA5"),
		Faint = hex("5A5A64"),
	},
}

local function palette(values)
	local result = {}
	for key, value in values do
		result[key] = hex(value)
	end
	return result
end

local function preset(name, description, accent, surface)
	return { Name = name, Description = description, Accent = hex(accent), Base = surface.Base, Text = surface.Text, Surface = surface }
end

Theme.Presets = {
	preset("Crimson", "Deep onyx with a vivid red accent", "E5243B", Theme.Surfaces.Onyx),
	preset("Ocean", "Midnight blue with a clear sky accent", "38BDF8", palette({
		Shade = "040811", Base = "080F1A", Panel = "0C1726", Raised = "102033", Field = "152A40",
		Hover = "19324B", Pressed = "1E3B56", Line = "20384D", LineStrong = "2F4F68",
		Text = "E7F3FF", Muted = "9FB6CE", Faint = "6C87A1",
	})),
	preset("Emerald", "Forest green with a fresh jade accent", "34D399", palette({
		Shade = "040A08", Base = "08120F", Panel = "0D1B16", Raised = "12251D", Field = "172F25",
		Hover = "1D382D", Pressed = "254337", Line = "223D31", LineStrong = "315542",
		Text = "E8F5EE", Muted = "A1BDAE", Faint = "6C8B79",
	})),
	preset("Violet", "Dark plum with a soft lavender accent", "A78BFA", palette({
		Shade = "08060E", Base = "100C18", Panel = "181222", Raised = "211A2E", Field = "2A223A",
		Hover = "332944", Pressed = "403354", Line = "372C49", LineStrong = "4B3C62",
		Text = "F2ECFF", Muted = "B8A9CB", Faint = "88759E",
	})),
	preset("Amber", "Warm charcoal with a golden accent", "FBBF24", palette({
		Shade = "0B0803", Base = "151007", Panel = "20190B", Raised = "2C2210", Field = "382C16",
		Hover = "44351A", Pressed = "524120", Line = "443722", LineStrong = "5E4C2E",
		Text = "FFF3DD", Muted = "CAB895", Faint = "998365",
	})),
}

function Theme.GetPreset(name)
	for _, entry in Theme.Presets do
		if entry.Name == name then
			return entry
		end
	end
	return nil
end

function Theme.ApplyPreset(name)
	if name ~= "Custom" and not Theme.GetPreset(name) then
		return false
	end
	return Store.Set("ThemePreset", name)
end

Theme.Syntax = {
	Text = hex("D9D9DF"),
	Keyword = hex("FF5C6C"),
	Builtin = hex("F28C96"),
	String = hex("E8C27B"),
	Number = hex("FF9470"),
	Comment = hex("5E5E69"),
	Function = hex("F7F7F9"),
	Method = hex("FFB3B9"),
	Property = hex("C6C6CF"),
	Operator = hex("8E8E9A"),
	Literal = hex("FF7A85"),
	Self = hex("FF9AA2"),
	Type = hex("E6A4AC"),
}

Theme.Status = {
	Danger = hex("F87171"),
	Success = hex("4ADE80"),
	Warning = hex("F5A524"),
	Info = hex("7AA2F7"),
	Vip = hex("FF9A1F"),
}

Theme.Font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)
Theme.FontMedium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
Theme.FontBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
do
	local mono = Font.fromEnum(Enum.Font.RobotoMono)
	Theme.Mono = mono
	Theme.MonoBold = Font.new(mono.Family, Enum.FontWeight.Bold, mono.Style)
end

Theme.Radius = 8
Theme.RadiusSmall = 5
Theme.Changed = Signal.new()

local tokens = {}
Theme.Tokens = tokens

local function luminance(color)
	local function linear(value)
		return value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
	end
	return linear(color.R) * 0.2126 + linear(color.G) * 0.7152 + linear(color.B) * 0.0722
end

local function contrast(left, right)
	local a, b = luminance(left), luminance(right)
	return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

local function ink(background)
	local black, white = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
	return contrast(background, white) >= contrast(background, black) and white or black
end

local function readableMix(background, foreground, amount, minimum)
	if contrast(background, foreground) < minimum then
		foreground = ink(background)
	end
	local color = background:Lerp(foreground, amount)
	while contrast(background, color) < minimum and amount < 1 do
		amount = math.min(amount + 0.025, 1)
		color = background:Lerp(foreground, amount)
	end
	return color
end

local function customSurface(base, text)
	for _, surface in Theme.Surfaces do
		if base == surface.Base and text == surface.Text then
			return surface
		end
	end
	local dark = luminance(base) < 0.179
	local direction = dark and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	local shade = dark and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
	local panel = base:Lerp(direction, 0.025)
	return {
		Shade = base:Lerp(shade, 0.38), Base = base, Panel = panel,
		Raised = base:Lerp(direction, 0.055), Field = base:Lerp(direction, 0.08),
		Hover = base:Lerp(direction, 0.105), Pressed = base:Lerp(direction, 0.14),
		Line = base:Lerp(direction, 0.13), LineStrong = base:Lerp(direction, 0.22),
		Text = text, Muted = readableMix(panel, text, 0.72, 4.5), Faint = readableMix(panel, text, 0.45, 3),
	}
end

local CUSTOM_TOKENS = {
	Shade = true, Base = true, Panel = true, Raised = true, Field = true, Hover = true, Pressed = true,
	Line = true, LineStrong = true, Text = true, Muted = true, Faint = true,
	Accent = true, AccentHover = true, AccentPressed = true, AccentSoft = true, AccentSofter = true, AccentLine = true, AccentText = true,
	Danger = true, Success = true, Warning = true, Info = true, Logo = true, LogoText = true, Vip = true, VipSoft = true,
}
local PRIMARY_KEYS = { Accent = "CustomAccent", Base = "CustomBase", Text = "CustomText" }

local function compose(surface, accent, overrides)
	local result = {}
	for key, value in surface do
		result[key] = overrides and overrides[key] or value
	end
	local h, s, v = accent:ToHSV()
	result.Accent = accent
	result.AccentHover = Color3.fromHSV(h, math.max(s - 0.08, 0), math.min(v + 0.1, 1))
	result.AccentPressed = Color3.fromHSV(h, s, v * 0.82)
	result.AccentSoft = result.Panel:Lerp(accent, 0.14)
	result.AccentSofter = result.Panel:Lerp(accent, 0.07)
	result.AccentLine = result.Line:Lerp(accent, 0.55)
	result.AccentText = ink(accent)
	result.Danger = Theme.Status.Danger
	result.Success = Theme.Status.Success
	result.Warning = Theme.Status.Warning
	result.Info = Theme.Status.Info
	local vip = overrides and overrides.Vip or Theme.Status.Vip
	result.Vip = vip
	result.VipSoft = result.Panel:Lerp(vip, 0.16)
	result.Logo = accent
	result.LogoText = result.Text
	if overrides then
		for key, value in overrides do
			result[key] = value
		end
	end
	return result
end

local function customTokens()
	local overrides = {}
	local stored = Store.Get("CustomOverrides", {})
	if type(stored) == "table" then
		for key, value in next, stored do
			if CUSTOM_TOKENS[key] and type(value) == "string" and string.match(value, "^#?%x%x%x%x%x%x$") then
				overrides[key] = hex(value)
			end
		end
	end
	local base = overrides.Base or Store.Get("CustomBase", Store.Default("CustomBase"))
	local text = overrides.Text or Store.Get("CustomText", Store.Default("CustomText"))
	local accent = overrides.Accent or Store.Get("CustomAccent", Store.Default("CustomAccent"))
	return compose(customSurface(base, text), accent, overrides)
end

function Theme.GetCustomColor(name)
	if not CUSTOM_TOKENS[name] then
		return nil
	end
	return customTokens()[name]
end

function Theme.SetCustomColor(name, color)
	if not CUSTOM_TOKENS[name] or typeof(color) ~= "Color3" then
		return false
	end
	for _, value in { color.R, color.G, color.B } do
		if value ~= value or value < 0 or value > 1 then
			return false
		end
	end
	local primary = PRIMARY_KEYS[name]
	local overrides = table.clone(Store.Get("CustomOverrides", {}))
	if primary then
		if not Store.Set(primary, color) then
			return false
		end
		if overrides[name] ~= nil then
			overrides[name] = nil
			return Store.Set("CustomOverrides", overrides)
		end
		return true
	end
	local ok, value = pcall(function()
		return color:ToHex()
	end)
	if not ok then
		return false
	end
	overrides[name] = value
	return Store.Set("CustomOverrides", overrides)
end

function Theme.CustomizeCurrent()
	local current = table.clone(tokens)
	local overrides = {}
	for key in CUSTOM_TOKENS do
		if not PRIMARY_KEYS[key] then
			overrides[key] = current[key]:ToHex()
		end
	end
	for key, setting in PRIMARY_KEYS do
		Store.Set(setting, current[key])
	end
	Store.Set("CustomOverrides", overrides)
	return Theme.ApplyPreset("Custom")
end

function Theme.ResetCustom()
	for _, setting in PRIMARY_KEYS do
		Store.Set(setting, Store.Default(setting))
	end
	Store.Set("CustomOverrides", {})
	return Theme.ApplyPreset("Custom")
end

local function rebuild()
	local name = Store.Get("ThemePreset", "Crimson")
	local selected = Theme.GetPreset(name) or Theme.Presets[1]
	local current = name == "Custom" and customTokens() or compose(selected.Surface, selected.Accent)
	for key, value in current do
		tokens[key] = value
	end
end

rebuild()

local bindings = {}
local unmanagedBindings = setmetatable({}, { __mode = "k" })
local destroyed = setmetatable({}, { __mode = "k" })

local function releaseBinding(object, entry)
	if bindings[object] == entry then
		bindings[object] = nil
	end
	if unmanagedBindings[object] == entry then
		unmanagedBindings[object] = nil
	end
	table.clear(entry.Tokens)
	local connection = entry.Connection
	entry.Connection = nil
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

local function createBinding(object)
	local entry = { Tokens = {} }
	local ok, connection = pcall(function()
		return object.Destroying:Connect(function()
			destroyed[object] = true
			releaseBinding(object, entry)
		end)
	end)
	if ok and connection then
		entry.Connection = connection
		if destroyed[object] then
			releaseBinding(object, entry)
			return nil
		end
		bindings[object] = entry
	else
		unmanagedBindings[object] = entry
	end
	return entry
end

local Token = {}
Token.__index = Token

function Theme.T(name)
	return setmetatable({ Name = name }, Token)
end

function Theme.Fn(callback)
	return setmetatable({ Fn = callback }, Token)
end

function Theme.IsToken(value)
	return getmetatable(value) == Token
end

local function resolve(token)
	if token.Fn then
		return token.Fn(tokens)
	end
	local value = tokens[token.Name]
	if value == nil then
		warn("unknown theme token " .. tostring(token.Name))
		return Color3.new(1, 0, 1)
	end
	return value
end
Theme.Resolve = resolve

function Theme.Get(name)
	return tokens[name]
end

function Theme.Bind(object, property, token, silent)
	if destroyed[object] then
		return false
	end
	if type(token) == "string" then
		token = Theme.T(token)
	end
	local entry = bindings[object] or unmanagedBindings[object] or createBinding(object)
	if not entry then
		return false
	end
	entry.Tokens[property] = token
	if not silent then
		object[property] = resolve(token)
	end
	return true
end

function Theme.Unbind(object, property)
	local entry = bindings[object] or unmanagedBindings[object]
	if entry then
		entry.Tokens[property] = nil
		if next(entry.Tokens) == nil then
			releaseBinding(object, entry)
		end
	end
end

local function refreshBindings(entries)
	for object, entry in entries do
		for property, token in entry.Tokens do
			pcall(function()
				object[property] = resolve(token)
			end)
		end
	end
end

function Theme.Refresh()
	rebuild()
	refreshBindings(bindings)
	refreshBindings(unmanagedBindings)
	Theme.Changed:Fire()
end

Store.Changed:Connect(function(key)
	if key == "ThemePreset" or key == "CustomAccent" or key == "CustomBase" or key == "CustomText" or key == "CustomOverrides" then
		Theme.Refresh()
	end
end)

return Theme
end

Modules["Theme/Background"] = function(import)
local Env = import("Core/Env")
local Store = import("Core/Store")

local Background = {}
local windows = setmetatable({}, { __mode = "k" })
local surfaceAlpha = { Base = 0.88, Panel = 0.22, Raised = 0.12 }
local imageTypes = { png = true, jpg = true, jpeg = true, webp = true, bmp = true }
local cachedSource, cachedImage

local function assetId(value)
	if value and #value <= 20 and string.match(value, "^%d+$") and string.find(value, "[1-9]") then
		return "rbxassetid://" .. value
	end
	return nil
end

function Background.Resolve(source)
	if type(source) ~= "string" or #source > 1024 or string.find(source, "%c") then
		return nil, "Enter a Roblox image asset ID or a local image path."
	end
	source = string.match(source, "^%s*(.-)%s*$")
	if source == "" then
		return ""
	end
	local direct = assetId(source) or assetId(string.match(source, "^rbxassetid://(%d+)$"))
	if direct then
		return direct
	end
	local host, path = string.match(source, "^https?://([^/]+)(/.*)$")
	if host then
		host = string.lower(host)
		if host == "www.roblox.com" or host == "roblox.com" then
			local id = string.match(path, "^/asset/%?id=(%d+)$") or string.match(path, "^/asset%?id=(%d+)$")
				or string.match(path, "^/library/(%d+)/") or string.match(path, "^/library/(%d+)$")
			direct = assetId(id)
		elseif host == "create.roblox.com" then
			direct = assetId(string.match(path, "^/store/asset/(%d+)/") or string.match(path, "^/store/asset/(%d+)$"))
		end
		if direct then
			return direct
		end
		return nil, "Use a Roblox image asset ID or a local image in your executor workspace."
	end
	local localPath = string.gsub(source, "\\", "/")
	if string.sub(localPath, 1, 1) == "/" or string.find(localPath, ":", 1, true) then
		return nil, "Local images must use a path relative to the executor workspace."
	end
	for segment in string.gmatch(localPath, "[^/]+") do
		if segment == ".." or segment == "." then
			return nil, "Use a local image path without parent-directory segments."
		end
	end
	local extension = string.lower(string.match(localPath, "%.([^./]+)$") or "")
	if not imageTypes[extension] then
		return nil, "Choose a PNG, JPG, JPEG, WebP or BMP image."
	end
	if type(Env.isfile) ~= "function" or type(Env.getCustomAsset) ~= "function" then
		return nil, "Local image support is unavailable in this executor."
	end
	local okFile, exists = pcall(Env.isfile, localPath)
	if not okFile or not exists then
		return nil, "Image file not found in the executor workspace."
	end
	if cachedSource == localPath then
		return cachedImage
	end
	local okImage, uri = pcall(Env.getCustomAsset, localPath)
	if not okImage or type(uri) ~= "string" or uri == "" or #uri > 2048 then
		return nil, "The executor could not load this image."
	end
	cachedSource, cachedImage = localPath, uri
	return uri
end

local function updateSurfaces(record)
	local transparency = record.Closed and 0 or Store.Get("BackgroundTransparency", 0)
	pcall(function()
		record.Panel.BackgroundTransparency = record.Original + (1 - record.Original) * transparency
		if record.Shadow then
			record.Shadow.ImageTransparency = record.ShadowOriginal + (1 - record.ShadowOriginal) * transparency
		end
	end)
	for object, surface in record.Surfaces do
		pcall(function()
			local alpha = record.Enabled and surface.Alpha or surface.Original
			object.BackgroundTransparency = alpha + (1 - alpha) * transparency
		end)
	end
end

local function updateAvailability(record)
	if record.Closed then
		return
	end
	local ok, loaded = pcall(function()
		return record.Image.IsLoaded
	end)
	record.Enabled = record.Candidate and ok and loaded == true
	updateSurfaces(record)
end

local function refresh(record)
	record.Revision += 1
	local revision = record.Revision
	local image = ""
	if Store.Get("BackgroundEnabled", false) then
		image = Background.Resolve(Store.Get("BackgroundImage", "")) or ""
	end
	if record.Closed or record.Revision ~= revision then
		return
	end
	local opacity = Store.Get("BackgroundOpacity", 0.2)
	local scale = Store.Get("BackgroundScale", "Crop")
	local ok = pcall(function()
		record.Image.Image = image
		record.Image.ImageTransparency = 1 - opacity
		record.Image.ImageColor3 = Store.Get("BackgroundTint", Color3.new(1, 1, 1))
		record.Image.ScaleType = Enum.ScaleType[scale] or Enum.ScaleType.Crop
		record.Image.Visible = image ~= "" and opacity > 0
	end)
	record.Candidate = ok and image ~= "" and opacity > 0
	updateAvailability(record)
end

local function trackSurface(object, alpha)
	if object.BackgroundTransparency ~= 0 then
		return true
	end
	local ancestor = object.Parent
	for _ = 1, 64 do
		if not ancestor then
			return
		end
		local record = windows[ancestor]
		if record then
			if record.Surfaces[object] then
				return true
			end
			local surface = { Original = object.BackgroundTransparency, Alpha = alpha }
			record.Surfaces[object] = surface
			local connected, link = pcall(function()
				return object.Destroying:Connect(function()
					record.Surfaces[object] = nil
				end)
			end)
			if connected then
				surface.Link = link
			end
			local current = record.Enabled and alpha or surface.Original
			object.BackgroundTransparency = current + (1 - current) * Store.Get("BackgroundTransparency", 0)
			return true
		end
		ancestor = ancestor.Parent
	end
end

function Background.TrackSurface(object, tokenName)
	local alpha = surfaceAlpha[tokenName]
	if not alpha then
		return
	end
	local ok, tracked = pcall(trackSurface, object, alpha)
	if ok and not tracked then
		task.defer(function()
			pcall(trackSurface, object, alpha)
		end)
	end
end

function Background.Attach(panel, scope, radius, shadow)
	local image = Instance.new("ImageLabel")
	image.Name = "BackgroundImage"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = ""
	image.Active = false
	image.Selectable = false
	image.Visible = false
	image.ZIndex = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = image
	image.Parent = panel
	local record = {
		Image = image, Panel = panel, Original = panel.BackgroundTransparency,
		Shadow = shadow, ShadowOriginal = shadow and shadow.ImageTransparency or 0,
		Surfaces = {}, Enabled = false, Revision = 0,
	}
	windows[panel] = record
	scope:Add(function()
		record.Closed = true
		record.Enabled = false
		windows[panel] = nil
		updateSurfaces(record)
		for _, surface in record.Surfaces do
			if surface.Link then
				surface.Link:Disconnect()
			end
		end
		table.clear(record.Surfaces)
		image:Destroy()
	end)
	scope:Add(Store.Changed:Connect(function(key)
		if record.Closed then
			return
		end
		if key == "BackgroundTransparency" then
			updateSurfaces(record)
		elseif key == "BackgroundEnabled" or key == "BackgroundImage" or key == "BackgroundOpacity"
			or key == "BackgroundScale" or key == "BackgroundTint" then
			refresh(record)
		end
	end))
	scope:Add(image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
		updateAvailability(record)
	end))
	refresh(record)
	return image
end

return Background
end

Modules["Lang/Phrases"] = function(import)
local I18n = import("Core/I18n")

-- Vietnamese for the texts of the library itself (the key is the English text).
I18n.Phrases("vi", {
	-- general
	["OK"] = "OK",
	["Cancel"] = "Hủy",
	["Apply"] = "Áp dụng",
	["Confirm"] = "Xác nhận",
	["Close"] = "Đóng",
	["Search"] = "Tìm kiếm",
	["Find"] = "Tìm",
	["Previous"] = "Trước",
	["Next"] = "Tiếp",
	["Select..."] = "Chọn...",
	["None"] = "Không",
	["Press a key..."] = "Nhấn một phím...",
	["Run"] = "Chạy",
	["Save"] = "Lưu",
	["Load"] = "Tải",
	["Delete"] = "Xóa",
	["Unload"] = "Gỡ",
	["Loading"] = "Đang tải",
	["Keybinds"] = "Phím tắt",
	["Colour"] = "Màu",
	["Apply color"] = "Áp dụng màu",
	["Cancel color change"] = "Hủy thay đổi màu",
	["Revert to the original colour"] = "Khôi phục màu ban đầu",
	["RECENT"] = "GẦN ĐÂY",
	["Colours you pick show up here"] = "Các màu bạn chọn sẽ hiện ở đây",
	-- settings page
	["Settings"] = "Cài đặt",
	["Language, appearance and configuration of the interface"] = "Ngôn ngữ, giao diện và cấu hình của menu",
	["Interface"] = "Giao diện",
	["Language"] = "Ngôn ngữ",
	["Language of the whole interface"] = "Ngôn ngữ của toàn bộ giao diện",
	["Theme"] = "Chủ đề",
	["Colour preset of the interface"] = "Bộ màu có sẵn của giao diện",
	["Accent colour"] = "Màu nhấn",
	["Replaces the accent of the current theme"] = "Thay màu nhấn của chủ đề hiện tại",
	["Interface scale"] = "Tỉ lệ giao diện",
	["Makes everything bigger or smaller"] = "Phóng to hoặc thu nhỏ mọi thứ",
	["Animations"] = "Hiệu ứng chuyển động",
	["Smooth transitions and movement"] = "Chuyển cảnh và di chuyển mượt mà",
	["Controls"] = "Điều khiển",
	["Menu key"] = "Phím mở/đóng menu",
	["Shows or hides the whole interface"] = "Hiện hoặc ẩn toàn bộ giao diện",
	["Menu button"] = "Nút menu",
	["Round button that opens the menu on touch screens"] = "Nút tròn để mở menu trên màn hình cảm ứng",
	["Watermark"] = "Watermark",
	["Small bar with FPS, ping and time"] = "Thanh nhỏ hiển thị FPS, ping và giờ",
	["Keybind list"] = "Danh sách phím tắt",
	["Shows the active keybinds on screen"] = "Hiện các phím tắt đang dùng trên màn hình",
	["Danger zone"] = "Khu vực nguy hiểm",
	["Unload interface"] = "Gỡ giao diện",
	["Removes the whole interface from the game"] = "Xóa toàn bộ giao diện khỏi game",
	["Everything will be removed. Continue?"] = "Mọi thứ sẽ bị xóa. Tiếp tục?",
	-- configuration
	["Configuration"] = "Cấu hình",
	["Configuration name"] = "Tên cấu hình",
	["Type a name, then press Save"] = "Nhập tên rồi bấm Lưu",
	["Name required"] = "Cần nhập tên",
	["Type a configuration name first"] = "Hãy nhập tên cấu hình trước",
	["Cannot enable"] = "Không thể bật",
	["Save or pick a configuration first"] = "Hãy lưu hoặc chọn một cấu hình trước",
	["Saved configurations"] = "Cấu hình đã lưu",
	["Pick one to load or delete"] = "Chọn một cấu hình để tải hoặc xóa",
	["No configuration"] = "Chưa có cấu hình",
	["Delete configuration"] = "Xóa cấu hình",
	["Load automatically"] = "Tự động tải",
	["Loads the selected configuration when the script starts"] = "Tải cấu hình đã chọn khi script khởi động",
	["Configuration saved"] = "Đã lưu cấu hình",
	["Configuration loaded"] = "Đã tải cấu hình",
	["Configuration deleted"] = "Đã xóa cấu hình",
	["Cannot save"] = "Không thể lưu",
	["Cannot load"] = "Không thể tải",
	["This executor has no file access"] = "Executor này không hỗ trợ ghi file",
})

return true
end

Modules["UI/Root"] = function(import)
local Env = import("Core/Env")
local Services = import("Core/Services")
local Store = import("Core/Store")
local Create = import("UI/Create")

local Root = {}

local function randomName()
	local chars = {}
	for index = 1, 12 do
		chars[index] = string.char(math.random(97, 122))
	end
	return table.concat(chars)
end

local function parentFor(gui)
	local candidates = {}
	if Env.gethui then
		local ok, hui = pcall(Env.gethui)
		if ok and typeof(hui) == "Instance" then
			table.insert(candidates, Env.Ref(hui))
		end
	end
	if Store.Get("AllowVisibleGuiFallback", false) then
		local coreGui = Services.CoreGui
		if coreGui then
			table.insert(candidates, coreGui)
		end
		pcall(function()
			local player = Env.Ref(Services.Players.LocalPlayer)
			local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
			if playerGui then
				table.insert(candidates, Env.Ref(playerGui))
			end
		end)
	end
	for _, candidate in candidates do
		local ok, parented = pcall(function()
			gui.Parent = candidate
			return Env.SameInstance(Env.Ref(gui.Parent), candidate)
		end)
		if ok and parented then
			return candidate
		end
	end
	return nil
end

local function screen(order)
	local gui = Instance.new("ScreenGui")
	gui.Name = randomName()
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	gui.ScreenInsets = Enum.ScreenInsets.None
	if Env.protectGui then
		pcall(Env.protectGui, gui)
	end
	if not parentFor(gui) then
		gui:Destroy()
		error("Hidden GUI unavailable. Visible GUI fallback is disabled.", 2)
	end
	return gui
end

function Root.Init(scope)
	Root.Main = scope:Add(screen(2147483000))
	Root.Bar = scope:Add(screen(2147483050))
	Root.Overlay = scope:Add(screen(2147483100))
	Root.Windows = Create.New("Frame", {
		Name = "Windows",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = Root.Main,
	})
	Root.Layer = Create.New("Frame", {
		Name = "Layer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = Root.Overlay,
	})
	Root.Scale = Store.Get("UIScale")
	return Root
end

function Root.ScreenSize()
	local camera = workspace.CurrentCamera
	if Root.Main and Root.Main.AbsoluteSize.X > 0 then
		return Root.Main.AbsoluteSize
	end
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

function Root.TopInset()
	local ok, rect = pcall(function()
		return Services.GuiService.TopbarInset
	end)
	if ok and rect and rect.Height > 0 then
		return rect.Max.Y
	end
	return Services.GuiService:GetGuiInset().Y
end

function Root.SetVisible(visible)
	Root.Main.Enabled = visible
	Root.Overlay.Enabled = visible
end

return Root
end

Modules["UI/Create"] = function(import)
local Theme = import("Theme/Theme")
local Icons = import("Theme/Icons")
local Background = import("Theme/Background")
local I18n = import("Core/I18n")

local Create = {}

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }
local GUI_DEFAULTS = {
	Frame = { BorderSizePixel = 0 },
	ScrollingFrame = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		ElasticBehavior = Enum.ElasticBehavior.Never,
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
	},
	TextLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	TextButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false, Text = "" },
	TextBox = { BorderSizePixel = 0, BackgroundTransparency = 1, ClearTextOnFocus = false },
	ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	ImageButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false },
	ViewportFrame = { BorderSizePixel = 0 },
	CanvasGroup = { BorderSizePixel = 0 },
}

local function applyValue(object, key, value)
	if Theme.IsToken(value) then
		Theme.Bind(object, key, value)
	else
		object[key] = value
	end
end

local function padding(object, value)
	local pad = Instance.new("UIPadding")
	local t, r, b, l
	if type(value) == "number" then
		t, r, b, l = value, value, value, value
	elseif #value == 2 then
		t, r, b, l = value[1], value[2], value[1], value[2]
	else
		t, r, b, l = value[1], value[2], value[3], value[4]
	end
	pad.PaddingTop = UDim.new(0, t)
	pad.PaddingRight = UDim.new(0, r)
	pad.PaddingBottom = UDim.new(0, b)
	pad.PaddingLeft = UDim.new(0, l)
	pad.Parent = object
	return pad
end

local function stroke(object, value)
	local line = Instance.new("UIStroke")
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.LineJoinMode = Enum.LineJoinMode.Round
	if type(value) == "string" or Theme.IsToken(value) then
		value = { Color = value }
	end
	local color = value.Color or "Line"
	applyValue(line, "Color", type(color) == "string" and Theme.T(color) or color)
	line.Thickness = value.Thickness or 1
	line.Transparency = value.Transparency or 0
	line.Parent = object
	return line
end

local function list(object, value)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = (value.Dir == "X" or value.Dir == "Horizontal") and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, value.Gap or 0)
	if value.Wrap then
		layout.Wraps = true
	end
	if value.HAlign then
		layout.HorizontalAlignment = Enum.HorizontalAlignment[value.HAlign]
	end
	if value.VAlign then
		layout.VerticalAlignment = Enum.VerticalAlignment[value.VAlign]
	end
	layout.Parent = object
	return layout
end

function Create.New(className, props, children)
	local object = Instance.new(className)
	local defaults = GUI_DEFAULTS[className]
	if defaults then
		for key, value in defaults do
			object[key] = value
		end
	end
	if TEXT_CLASSES[className] then
		object.FontFace = Theme.Font
		object.TextSize = 13
		Theme.Bind(object, "TextColor3", "Text")
		if className == "TextBox" then
			Theme.Bind(object, "PlaceholderColor3", "Faint")
		end
	elseif className == "ScrollingFrame" then
		Theme.Bind(object, "ScrollBarImageColor3", "LineStrong")
	end
	local parent, events
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif key == "On" then
				events = value
			elseif key == "Corner" then
				local corner = Instance.new("UICorner")
				corner.CornerRadius = typeof(value) == "UDim" and value or UDim.new(0, value)
				corner.Parent = object
			elseif key == "Stroke" then
				stroke(object, value)
			elseif key == "Padding" then
				padding(object, value)
			elseif key == "List" then
				list(object, value)
			elseif key == "Icon" then
				Icons.Apply(object, value)
			elseif (key == "Text" or key == "PlaceholderText") and TEXT_CLASSES[className] and (type(value) == "table" or type(value) == "function" or I18n.Known(value)) then
				-- translatable text: follows the selected language
				I18n.Bind(object, key, value)
			else
				applyValue(object, key, value)
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = object
		end
	end
	if events then
		for name, callback in events do
			object[name]:Connect(callback)
		end
	end
	if parent then
		object.Parent = parent
	end
	if (className == "Frame" or className == "ScrollingFrame") and props and Theme.IsToken(props.BackgroundColor3) then
		Background.TrackSurface(object, props.BackgroundColor3.Name)
	end
	return object
end

function Create.Icon(name, size, color, props)
	local image = Create.New("ImageLabel", {
		Size = UDim2.fromOffset(size or 16, size or 16),
		ImageColor3 = color or Theme.T("Muted"),
		ScaleType = Enum.ScaleType.Fit,
	})
	Icons.Apply(image, name)
	if props then
		for key, value in props do
			if key == "Parent" then
				continue
			end
			applyValue(image, key, value)
		end
		if props.Parent then
			image.Parent = props.Parent
		end
	end
	return image
end

function Create.SetIcon(image, name)
	Icons.Apply(image, name)
end

function Create.Shadow(parent, zIndex, spread, transparency)
	spread = spread or 18
	return Create.New("ImageLabel", {
		Name = "Shadow",
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = transparency or 0.4,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		Size = UDim2.new(1, spread * 2, 1, spread * 2),
		Position = UDim2.fromOffset(-spread, -spread + 4),
		ZIndex = zIndex or 0,
		Parent = parent,
	})
end

Create.Padding = padding
Create.Stroke = stroke
Create.List = list

return Create
end

Modules["UI/Motion"] = function(import)
local Services = import("Core/Services")
local Store = import("Core/Store")
local Theme = import("Theme/Theme")

local Motion = {
	Fast = 0.12,
	Base = 0.2,
	Slow = 0.32,
}

local active = setmetatable({}, { __mode = "k" })

local function enabled()
	return Store.Get("Animations") ~= false
end
Motion.Enabled = enabled

function Motion.Tween(object, props, duration, style, direction)
	if not enabled() or duration == 0 then
		for key, value in props do
			object[key] = value
		end
		return nil
	end
	local info = TweenInfo.new(duration or Motion.Base, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
	local tween = Services.TweenService:Create(object, info, props)
	tween:Play()
	return tween
end

function Motion.Token(object, property, token, duration)
	if type(token) == "string" then
		token = Theme.T(token)
	end
	Theme.Bind(object, property, token, true)
	local target = Theme.Resolve(token)
	local map = active[object]
	if not map then
		map = {}
		active[object] = map
	end
	if map[property] then
		map[property]:Cancel()
		map[property] = nil
	end
	if enabled() then
		map[property] = Motion.Tween(object, { [property] = target }, duration or Motion.Fast)
	else
		object[property] = target
	end
end

function Motion.Hover(button, target, property, normal, hover, pressed)
	property = property or "BackgroundColor3"
	local hovering = false
	local down = false
	local function update()
		local token = (down and pressed) or (hovering and hover) or normal
		Motion.Token(target, property, token)
	end
	button.MouseEnter:Connect(function()
		hovering = true
		update()
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		down = false
		update()
	end)
	if pressed then
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				down = true
				update()
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				down = false
				update()
			end
		end)
	end
	return function(newNormal, newHover, newPressed)
		normal = newNormal or normal
		hover = newHover or hover
		pressed = newPressed or pressed
		update()
	end
end

return Motion
end

Modules["UI/Drag"] = function(import)
local Services = import("Core/Services")
local Input = import("Core/Input")
local Motion = import("UI/Motion")
local Root = import("UI/Root")

local Drag = {}

-- Fully visible position with a small margin on every side (left, right, top AND bottom).
function Drag.Fit(position, size, margin)
	margin = margin or 8
	local screen = Root.ScreenSize()
	local top = Root.TopInset()
	local minX, minY = margin, top + margin
	local maxX = math.max(minX, screen.X - size.X - margin)
	local maxY = math.max(minY, screen.Y - size.Y - margin)
	return Vector2.new(math.clamp(position.X, minX, maxX), math.clamp(position.Y, minY, maxY))
end

-- Makes `frame` (AnchorPoint 0,0 and an offset Position) draggable through `handle`.
-- The frame eases towards the pointer, and after the release it settles on a fully
-- visible position, so it can never be left half outside of the screen.
--   Options.Clamp(position, size) -> position   limit while dragging (default: keep a part visible)
--   Options.Rest(position, size)  -> position   resting place after release (default: Drag.Fit)
--   Options.OnEnd(position)                      called when the frame has settled
function Drag.Bind(handle, frame, options)
	options = options or {}
	local RunService = Services.RunService
	local startPosition, target, shown, link

	local function current()
		return Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
	end

	local function stop()
		if link then
			link:Disconnect()
			link = nil
		end
		shown = nil
	end

	local function step(dt)
		if not target then
			stop()
			return
		end
		if Motion.Enabled() then
			shown = shown + (target - shown) * (1 - math.exp(-dt * 30))
		else
			shown = target
		end
		frame.Position = UDim2.fromOffset(shown.X, shown.Y)
		if not startPosition and (target - shown).Magnitude < 0.4 then
			frame.Position = UDim2.fromOffset(target.X, target.Y)
			local final = target
			target = nil
			stop()
			if options.OnEnd then
				options.OnEnd(final)
			end
		end
	end

	local function run()
		if not link then
			shown = current()
			link = RunService.RenderStepped:Connect(step)
		end
	end

	local drag = Input.Drag(handle, {
		Begin = function()
			startPosition = (link and target) or current()
			target = startPosition
			run()
		end,
		Move = function(delta)
			if not startPosition then
				return
			end
			local size = frame.AbsoluteSize
			local wanted = startPosition + delta
			if options.Clamp then
				wanted = options.Clamp(wanted, size)
			else
				local screen = Root.ScreenSize()
				wanted = Vector2.new(
					math.clamp(wanted.X, -size.X + 60, screen.X - 60),
					math.clamp(wanted.Y, 0, screen.Y - 30)
				)
			end
			target = wanted
		end,
		End = function()
			if not startPosition then
				return
			end
			startPosition = nil
			local size = frame.AbsoluteSize
			target = (options.Rest or Drag.Fit)(target or current(), size)
			run()
		end,
	})

	return {
		Disconnect = function()
			drag.Disconnect()
			stop()
		end,
	}
end

return Drag
end

Modules["UI/Tooltip"] = function(import)
local Services = import("Core/Services")
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local I18n = import("Core/I18n")

local Tooltip = {}

local frame, label, hint
local owner
local token = 0

local function ensure()
	if frame then
		return
	end
	frame = Create.New("Frame", {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.T("Raised"),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 900,
		Corner = 6,
		Stroke = { Color = "LineStrong", Transparency = 1 },
		Padding = { 5, 9, 5, 9 },
		List = { Dir = "X", Gap = 8, VAlign = "Center" },
		Parent = Root.Layer,
	})
	label = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextSize = 12,
		FontFace = Theme.FontMedium,
		TextTransparency = 1,
		ZIndex = 901,
		Parent = frame,
	})
	hint = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextSize = 11,
		FontFace = Theme.Mono,
		TextColor3 = Theme.T("Faint"),
		TextTransparency = 1,
		ZIndex = 901,
		LayoutOrder = 2,
		Parent = frame,
	})
end

local function place()
	local mouse = Services.UserInputService:GetMouseLocation()
	local screen = Root.ScreenSize()
	local size = frame.AbsoluteSize
	local x = math.clamp(mouse.X + 14, 6, screen.X - size.X - 6)
	local y = mouse.Y + 20
	if y + size.Y > screen.Y - 6 then
		y = mouse.Y - size.Y - 10
	end
	frame.Position = UDim2.fromOffset(x, y)
end

function Tooltip.Show(text, shortcut, anchor)
	ensure()
	token += 1
	owner = anchor
	label.Text = I18n.Resolve(text)
	hint.Text = shortcut or ""
	hint.Visible = shortcut ~= nil and shortcut ~= ""
	frame.Visible = true
	place()
	Motion.Tween(frame, { BackgroundTransparency = 0 }, Motion.Fast)
	Motion.Tween(frame:FindFirstChildOfClass("UIStroke"), { Transparency = 0 }, Motion.Fast)
	Motion.Tween(label, { TextTransparency = 0 }, Motion.Fast)
	Motion.Tween(hint, { TextTransparency = 0 }, Motion.Fast)
end

function Tooltip.Hide(anchor)
	if not frame or (anchor and owner ~= anchor) then
		return
	end
	token += 1
	owner = nil
	frame.Visible = false
	frame.BackgroundTransparency = 1
	frame:FindFirstChildOfClass("UIStroke").Transparency = 1
	label.TextTransparency = 1
	hint.TextTransparency = 1
end

function Tooltip.Attach(gui, text, shortcut)
	local current = token
	local hovering = false
	gui.MouseEnter:Connect(function()
		hovering = true
		token += 1
		current = token
		local textValue = type(text) == "function" and text() or text
		if not textValue or textValue == "" then
			return
		end
		task.delay(0.42, function()
			if hovering and current == token then
				Tooltip.Show(textValue, shortcut, gui)
			end
		end)
	end)
	gui.MouseLeave:Connect(function()
		hovering = false
		Tooltip.Hide(gui)
	end)
	gui.MouseMoved:Connect(function()
		if owner == gui and frame and frame.Visible then
			place()
		end
	end)
	if gui:IsA("GuiButton") then
		gui.Activated:Connect(function()
			hovering = false
			Tooltip.Hide(gui)
		end)
	end
end

return Tooltip
end

Modules["UI/Button"] = function(import)
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Tooltip = import("UI/Tooltip")

local Button = {}

local VARIANTS = {
	Primary = { Fill = "Accent", Hover = "AccentHover", Pressed = "AccentPressed", Text = "AccentText", Icon = "AccentText", Stroke = nil },
	Secondary = { Fill = "Field", Hover = "Hover", Pressed = "Pressed", Text = "Text", Icon = "Muted", Stroke = "Line" },
	Ghost = { Fill = "Panel", Hover = "Hover", Pressed = "Pressed", Text = "Muted", Icon = "Muted", Stroke = nil, Transparent = true },
	Danger = { Fill = "AccentSofter", Hover = "AccentSoft", Pressed = "AccentLine", Text = "Danger", Icon = "Danger", Stroke = "AccentLine" },
}

function Button.new(options)
	local variant = VARIANTS[options.Variant or "Secondary"] or VARIANTS.Secondary
	local height = options.Height or 28
	local root = Create.New("TextButton", {
		Name = options.Name or "Button",
		Size = options.Size or UDim2.fromOffset(0, height),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		AutomaticSize = options.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.T(variant.Fill),
		BackgroundTransparency = variant.Transparent and 1 or 0,
		LayoutOrder = options.LayoutOrder or 0,
		Corner = Theme.RadiusSmall + 1,
		Stroke = variant.Stroke and { Color = variant.Stroke } or nil,
		Padding = { 0, options.Text and 11 or 0, 0, options.Text and (options.Icon and 9 or 11) or 0 },
		Parent = options.Parent,
	})
	local holder = Create.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		List = { Dir = "X", Gap = 6, VAlign = "Center", HAlign = "Center" },
		Parent = root,
	})
	if options.Size then
		holder.Size = UDim2.fromScale(1, 1)
		holder.AutomaticSize = Enum.AutomaticSize.None
	end
	local icon, label
	if options.Icon then
		icon = Create.Icon(options.Icon, options.IconSize or 15, Theme.T(variant.Icon), { LayoutOrder = 1, Parent = holder })
	end
	if options.Text then
		label = Create.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Text = options.Text,
			TextSize = options.TextSize or 13,
			FontFace = Theme.FontMedium,
			TextColor3 = Theme.T(variant.Text),
			LayoutOrder = 2,
			Parent = holder,
		})
	end
	local hovering = false
	local function update(pressed)
		if variant.Transparent then
			Motion.Tween(root, { BackgroundTransparency = (hovering or pressed) and 0 or 1 }, Motion.Fast)
		end
		Motion.Token(root, "BackgroundColor3", pressed and variant.Pressed or (hovering and variant.Hover or variant.Fill))
		if icon and variant.Transparent then
			Motion.Token(icon, "ImageColor3", hovering and "Text" or variant.Icon)
		end
		if label and variant.Transparent then
			Motion.Token(label, "TextColor3", hovering and "Text" or variant.Text)
		end
	end
	root.MouseEnter:Connect(function()
		hovering = true
		update(false)
	end)
	root.MouseLeave:Connect(function()
		hovering = false
		update(false)
	end)
	root.MouseButton1Down:Connect(function()
		update(true)
	end)
	root.MouseButton1Up:Connect(function()
		update(false)
	end)
	if options.Callback then
		root.Activated:Connect(function()
			options.Callback()
		end)
	end
	if options.Tooltip then
		Tooltip.Attach(root, options.Tooltip, options.Shortcut)
	end
	local self = { Instance = root, Icon = icon, Label = label }
	function self:SetText(text)
		if label then
			label.Text = text
		end
	end
	function self:SetIcon(name)
		if icon then
			Create.SetIcon(icon, name)
		end
	end
	function self:SetEnabled(enabled)
		root.Active = enabled
		root.Interactable = enabled
		if icon then
			icon.ImageTransparency = enabled and 0 or 0.6
		end
		if label then
			label.TextTransparency = enabled and 0 or 0.6
		end
	end
	return self
end

function Button.Icon(options)
	local size = options.Size or 26
	local root = Create.New("ImageButton", {
		Name = options.Name or "IconButton",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.T("Hover"),
		BackgroundTransparency = 1,
		LayoutOrder = options.LayoutOrder or 0,
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		Corner = options.Round and UDim.new(1, 0) or Theme.RadiusSmall + 1,
		Parent = options.Parent,
	})
	local icon = Create.Icon(options.Icon, options.IconSize or math.floor(size * 0.58), Theme.T(options.Color or "Muted"), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = root,
	})
	local active = false
	local hovering = false
	local danger = options.Danger
	local function update(pressed)
		local fill = pressed and "Pressed" or (danger and hovering and "AccentSoft" or "Hover")
		Motion.Token(root, "BackgroundColor3", active and "AccentSoft" or fill)
		Motion.Tween(root, { BackgroundTransparency = (hovering or pressed or active) and 0 or 1 }, Motion.Fast)
		local tint = active and "Accent" or (hovering and (danger and "Danger" or "Text") or (options.Color or "Muted"))
		Motion.Token(icon, "ImageColor3", tint)
	end
	root.MouseEnter:Connect(function()
		hovering = true
		update(false)
	end)
	root.MouseLeave:Connect(function()
		hovering = false
		update(false)
	end)
	root.MouseButton1Down:Connect(function()
		update(true)
	end)
	root.MouseButton1Up:Connect(function()
		update(false)
	end)
	if options.Callback then
		root.Activated:Connect(function()
			options.Callback()
		end)
	end
	if options.Tooltip then
		Tooltip.Attach(root, options.Tooltip, options.Shortcut)
	end
	local self = { Instance = root, Icon = icon }
	function self:SetActive(value)
		active = value and true or false
		update(false)
	end
	function self:SetIcon(name)
		Create.SetIcon(icon, name)
	end
	function self:IsActive()
		return active
	end
	return self
end

return Button
end

Modules["UI/Switch"] = function(import)
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Signal = import("Core/Signal")

local Switch = {}

function Switch.new(options)
	local value = options.Value == true
	local root = Create.New("TextButton", {
		Name = "Switch",
		Size = UDim2.fromOffset(30, 17),
		BackgroundColor3 = Theme.T(value and "Accent" or "Pressed"),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		LayoutOrder = options.LayoutOrder or 0,
		Corner = UDim.new(1, 0),
		Parent = options.Parent,
	})
	root.BackgroundTransparency = 0
	local knob = Create.New("Frame", {
		Size = UDim2.fromOffset(13, 13),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, value and 15 or 2, 0.5, 0),
		BackgroundColor3 = Theme.T(value and "AccentText" or "Muted"),
		Corner = UDim.new(1, 0),
		Parent = root,
	})
	local self = { Instance = root, Changed = Signal.new() }
	local function render(animate)
		local duration = animate and Motion.Base or 0
		Motion.Token(root, "BackgroundColor3", value and "Accent" or "Pressed", duration)
		Motion.Token(knob, "BackgroundColor3", value and "AccentText" or "Muted", duration)
		Motion.Tween(knob, { Position = UDim2.new(0, value and 15 or 2, 0.5, 0) }, duration)
	end
	root.Activated:Connect(function()
		if options.Locked then
			return
		end
		value = not value
		render(true)
		self.Changed:Fire(value)
		if options.Callback then
			options.Callback(value)
		end
	end)
	function self:Set(newValue, silent, force)
		newValue = newValue == true
		if newValue == value then
			if force and not silent then
				self.Changed:Fire(value)
			end
			return
		end
		value = newValue
		render(true)
		if not silent then
			self.Changed:Fire(value)
		end
	end
	function self:Get()
		return value
	end
	return self
end

function Switch.Check(options)
	local value = options.Value == true
	local root = Create.New("TextButton", {
		Name = "Check",
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.T(value and "Accent" or "Field"),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		LayoutOrder = options.LayoutOrder or 0,
		Corner = 4,
		Stroke = { Color = value and "Accent" or "LineStrong" },
		Parent = options.Parent,
	})
	root.BackgroundTransparency = 0
	local outline = root:FindFirstChildOfClass("UIStroke")
	local mark = Create.Icon(options.Mixed and "minus" or "check", 12, Theme.T("AccentText"), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageTransparency = value and 0 or 1,
		Parent = root,
	})
	local self = { Instance = root, Changed = Signal.new() }
	local function render()
		Motion.Token(root, "BackgroundColor3", value and "Accent" or "Field")
		Motion.Token(outline, "Color", value and "Accent" or "LineStrong")
		Motion.Tween(mark, { ImageTransparency = value and 0 or 1 }, Motion.Fast)
	end
	root.Activated:Connect(function()
		if options.Locked then
			return
		end
		value = not value
		render()
		self.Changed:Fire(value)
		if options.Callback then
			options.Callback(value)
		end
	end)
	function self:Set(newValue)
		value = newValue == true
		render()
	end
	function self:Get()
		return value
	end
	return self
end

return Switch
end

Modules["UI/Slider"] = function(import)
local Input = import("Core/Input")
local Signal = import("Core/Signal")
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")

local Slider = {}

local KNOB = 12
local KNOB_ACTIVE = 14

local function decimalsOf(step)
	local fraction = string.match(tostring(step), "%.(%d+)$")
	return fraction and #fraction or 0
end

local function snap(value, min, max, step, decimals)
	if step and step > 0 then
		value = min + math.floor((value - min) / step + 0.5) * step
	end
	value = math.clamp(value, min, max)
	return tonumber(string.format("%." .. decimals .. "f", value)) or value
end

local function buildParts(options, labelWidth)
	local root = Create.New("Frame", {
		Name = "Slider",
		Size = UDim2.fromOffset(options.Width or 180, 22),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	})
	local hit = Create.New("TextButton", {
		Name = "Hit",
		Size = UDim2.new(1, -(labelWidth + 10), 1, 0),
		Parent = root,
	})
	local track = Create.New("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB / 2, 0.5, 0),
		Size = UDim2.new(1, -KNOB, 0, 4),
		BackgroundColor3 = Theme.T("Field"),
		Corner = UDim.new(1, 0),
		Stroke = { Color = "Line" },
		Parent = hit,
	})
	local fill = Create.New("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.T("Accent"),
		Corner = UDim.new(1, 0),
		Parent = track,
	})
	local knob = Create.New("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		BackgroundColor3 = Theme.T("Text"),
		Corner = UDim.new(1, 0),
		Stroke = { Color = "Shade", Thickness = 1, Transparency = 0.3 },
		ZIndex = 2,
		Parent = track,
	})
	local label = Create.New("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, labelWidth, 1, 0),
		FontFace = Theme.Mono,
		TextSize = 12,
		TextColor3 = Theme.T("Muted"),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = root,
	})
	return { Root = root, Hit = hit, Track = track, Fill = fill, Knob = knob, Label = label }
end

function Slider.new(options)
	local min = options.Min or 0
	local max = options.Max or 1
	if max <= min then
		max = min + 1
	end
	local step = options.Step
	local decimals = step and decimalsOf(step) or 2
	local parts = buildParts(options, options.LabelWidth or 44)
	local value = snap(options.Value or min, min, max, step, decimals)
	local dragging, hovering = false, false
	local self = { Instance = parts.Root, Changed = Signal.new(), Released = Signal.new() }

	local function format(current)
		if options.Format then
			return options.Format(current)
		end
		return string.format("%." .. decimals .. "f", current) .. (options.Suffix or "")
	end

	local function render(animate)
		local alpha = (value - min) / (max - min)
		local duration = animate == "drag" and 0.06 or (animate and Motion.Base or 0)
		Motion.Tween(parts.Fill, { Size = UDim2.fromScale(alpha, 1) }, duration)
		Motion.Tween(parts.Knob, { Position = UDim2.fromScale(alpha, 0.5) }, duration)
		parts.Label.Text = format(value)
	end

	local function restyle()
		local active = dragging or hovering
		local size = active and KNOB_ACTIVE or KNOB
		Motion.Tween(parts.Knob, { Size = UDim2.fromOffset(size, size) }, Motion.Fast)
		Motion.Token(parts.Fill, "BackgroundColor3", dragging and "AccentHover" or "Accent")
		Motion.Token(parts.Label, "TextColor3", active and "Text" or "Muted")
	end

	local function apply(newValue, animate, notify)
		newValue = snap(newValue, min, max, step, decimals)
		if newValue == value then
			return false
		end
		value = newValue
		render(animate)
		if notify then
			self.Changed:Fire(value)
		end
		if notify == "user" and options.Callback then
			task.spawn(options.Callback, value)
		end
		return true
	end

	local function fromPoint(point)
		local width = parts.Track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((point.X - parts.Track.AbsolutePosition.X) / width, 0, 1)
		apply(min + alpha * (max - min), "drag", "user")
	end

	local startValue
	local drag = Input.Drag(parts.Hit, {
		Begin = function(point)
			dragging = true
			startValue = value
			restyle()
			fromPoint(point)
		end,
		Move = function(_, point)
			fromPoint(point)
		end,
		End = function()
			dragging = false
			restyle()
			if value ~= startValue then
				self.Released:Fire(value)
				if options.OnRelease then
					task.spawn(options.OnRelease, value)
				end
			end
		end,
	})
	parts.Hit.MouseEnter:Connect(function()
		hovering = true
		restyle()
	end)
	parts.Hit.MouseLeave:Connect(function()
		hovering = false
		restyle()
	end)
	parts.Root.Destroying:Connect(function()
		drag.Disconnect()
	end)

	function self:Set(newValue, silent, force)
		if dragging then
			return
		end
		local changed = apply(newValue, true, not silent and "set" or nil)
		if force and not changed and not silent then
			self.Changed:Fire(value)
		end
	end

	function self:Get()
		return value
	end

	render(false)
	return self
end

return Slider
end

Modules["UI/Tabs"] = function(import)
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Signal = import("Core/Signal")

local Tabs = {}

function Tabs.new(options)
	local root = Create.New("Frame", {
		Name = "Tabs",
		Size = options.Size or UDim2.new(1, 0, 0, 28),
		Position = options.Position or UDim2.new(),
		BackgroundColor3 = Theme.T("Field"),
		LayoutOrder = options.LayoutOrder or 0,
		Corner = Theme.RadiusSmall + 1,
		Parent = options.Parent,
	})
	local indicator = Create.New("Frame", {
		Name = "Indicator",
		Size = UDim2.new(1 / #options.Items, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Theme.T("Pressed"),
		Corner = Theme.RadiusSmall,
		Stroke = { Color = "LineStrong" },
		Parent = root,
	})
	local holder = Create.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		List = { Dir = "X" },
		Parent = root,
	})
	local self = { Instance = root, Changed = Signal.new(), Selected = options.Selected or options.Items[1].Id }
	local entries = {}
	local function render(animate)
		for index, entry in entries do
			local selected = entry.Id == self.Selected
			Motion.Token(entry.Label, "TextColor3", selected and "Text" or "Faint")
			if entry.Icon then
				Motion.Token(entry.Icon, "ImageColor3", selected and "Accent" or "Faint")
			end
			if selected then
				local target = UDim2.new((index - 1) / #entries, 2, 0, 2)
				if animate then
					Motion.Tween(indicator, { Position = target }, Motion.Base)
				else
					indicator.Position = target
				end
			end
		end
	end
	for index, item in options.Items do
		local button = Create.New("TextButton", {
			Size = UDim2.new(1 / #options.Items, 0, 1, 0),
			LayoutOrder = index,
			ZIndex = 2,
			Parent = holder,
		})
		local inner = Create.New("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			List = { Dir = "X", Gap = 6, HAlign = "Center", VAlign = "Center" },
			ZIndex = 2,
			Parent = button,
		})
		local icon
		if item.Icon then
			icon = Create.Icon(item.Icon, 13, Theme.T("Faint"), { LayoutOrder = 1, ZIndex = 3, Parent = inner })
		end
		local label = Create.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Text = item.Text,
			TextSize = 12,
			FontFace = Theme.FontMedium,
			TextColor3 = Theme.T("Faint"),
			LayoutOrder = 2,
			ZIndex = 3,
			Parent = inner,
		})
		local entry = { Id = item.Id, Label = label, Icon = icon, Button = button }
		table.insert(entries, entry)
		button.MouseEnter:Connect(function()
			if self.Selected ~= item.Id then
				Motion.Token(label, "TextColor3", "Muted")
			end
		end)
		button.MouseLeave:Connect(function()
			if self.Selected ~= item.Id then
				Motion.Token(label, "TextColor3", "Faint")
			end
		end)
		button.Activated:Connect(function()
			self:Select(item.Id)
		end)
	end
	function self:Select(id, silent)
		if self.Selected == id then
			return
		end
		self.Selected = id
		render(true)
		if not silent then
			self.Changed:Fire(id)
		end
	end
	function self:SetLabel(id, text)
		for _, entry in entries do
			if entry.Id == id then
				entry.Label.Text = text
			end
		end
	end
	render(false)
	return self
end

return Tabs
end

Modules["UI/Field"] = function(import)
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Signal = import("Core/Signal")

local Field = {}

function Field.new(options)
	local height = options.Height or 28
	local root = Create.New("Frame", {
		Name = options.Name or "Field",
		Size = options.Size or UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.T(options.Fill or "Field"),
		LayoutOrder = options.LayoutOrder or 0,
		Position = options.Position or UDim2.new(),
		Corner = Theme.RadiusSmall + 1,
		Parent = options.Parent,
	})
	local outline = Create.Stroke(root, { Color = "Line" })
	local left = 9
	local icon
	if options.Icon then
		icon = Create.Icon(options.Icon, 14, Theme.T("Faint"), {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0),
			Parent = root,
		})
		left = 30
	end
	local right = options.Clearable and 28 or 8
	local box = Create.New("TextBox", {
		Name = "Input",
		Size = UDim2.new(1, -(left + right), 1, 0),
		Position = UDim2.fromOffset(left, 0),
		Text = options.Text or "",
		PlaceholderText = options.Placeholder or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = options.TextSize or 13,
		FontFace = options.Mono and Theme.Mono or Theme.Font,
		ClipsDescendants = true,
		TextTruncate = Enum.TextTruncate.None,
		MultiLine = false,
		Parent = root,
	})
	local clear
	if options.Clearable then
		clear = Create.New("ImageButton", {
			Name = "Clear",
			Size = UDim2.fromOffset(20, 20),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -5, 0.5, 0),
			Image = "",
			Visible = (options.Text or "") ~= "",
			Parent = root,
		})
		local glyph = Create.Icon("x", 13, Theme.T("Faint"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = clear,
		})
		clear.MouseEnter:Connect(function()
			Motion.Token(glyph, "ImageColor3", "Text")
		end)
		clear.MouseLeave:Connect(function()
			Motion.Token(glyph, "ImageColor3", "Faint")
		end)
	end
	local self = {
		Instance = root,
		Box = box,
		Changed = Signal.new(),
		Submitted = Signal.new(),
		Focused = Signal.new(),
	}
	local function focusStyle(focused)
		Motion.Token(outline, "Color", focused and "AccentLine" or "Line")
		if icon then
			Motion.Token(icon, "ImageColor3", focused and "Accent" or "Faint")
		end
	end
	box.Focused:Connect(function()
		focusStyle(true)
		self.Focused:Fire()
	end)
	box.FocusLost:Connect(function(enter)
		focusStyle(false)
		self.Submitted:Fire(box.Text, enter)
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if clear then
			clear.Visible = box.Text ~= ""
		end
		self.Changed:Fire(box.Text)
	end)
	if clear then
		clear.Activated:Connect(function()
			box.Text = ""
			self.Submitted:Fire("", false)
		end)
	end
	function self:Get()
		return box.Text
	end
	function self:Set(text)
		box.Text = text or ""
	end
	function self:Focus()
		box:CaptureFocus()
	end
	return self
end

return Field
end

Modules["UI/Dialog"] = function(import)
local Services = import("Core/Services")
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local Button = import("UI/Button")
local Field = import("UI/Field")

local Dialog = {}

function Dialog.Custom(options)
	local width = options.Width or 360
	local dim = Create.New("TextButton", {
		Name = "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 700,
		Parent = Root.Layer,
	})
	local card = Create.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 702,
		Parent = dim,
	})
	Create.Shadow(card, 701, 26, 0.3)
	local surface = Create.New("Frame", {
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.T("Base"),
		Active = true,
		ZIndex = 702,
		Corner = Theme.Radius + 2,
		Stroke = { Color = "LineStrong" },
		Parent = card,
	})
	local content = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 703,
		Padding = { 16, 16, 14, 16 },
		List = { Gap = 12 },
		Parent = surface,
	})
	local head = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		ZIndex = 703,
		LayoutOrder = 1,
		Parent = content,
	})
	local badge = Create.New("Frame", {
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.T(options.Danger and "AccentSoft" or "AccentSofter"),
		ZIndex = 704,
		Corner = 7,
		Parent = head,
	})
	Create.Icon(options.Icon or "info", 14, Theme.T(options.Danger and "Danger" or "Accent"), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 705,
		Parent = badge,
	})
	Create.New("TextLabel", {
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.fromOffset(34, 0),
		Text = options.Title or "",
		TextSize = 15,
		FontFace = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 704,
		Parent = head,
	})
	if options.Message then
		Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = options.Message,
			TextSize = 13,
			TextColor3 = Theme.T("Muted"),
			TextWrapped = true,
			RichText = options.Rich == true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 704,
			LayoutOrder = 2,
			Parent = content,
		})
	end
	local body = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 704,
		LayoutOrder = 3,
		List = { Gap = 8 },
		Parent = content,
	})
	local footer = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		ZIndex = 704,
		LayoutOrder = 4,
		List = { Dir = "X", Gap = 8, HAlign = "Right", VAlign = "Center" },
		Parent = content,
	})
	local closed = false
	local escape
	local function close(...)
		if closed then
			return
		end
		closed = true
		if escape then
			escape:Disconnect()
		end
		Motion.Tween(dim, { BackgroundTransparency = 1 }, Motion.Fast)
		Motion.Tween(card, { Position = UDim2.new(0.5, 0, 0.5, 8) }, Motion.Fast)
		task.delay(Motion.Enabled() and Motion.Fast or 0, function()
			dim:Destroy()
		end)
		if options.OnClose then
			options.OnClose(...)
		end
	end
	escape = Services.UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			close(nil)
		end
	end)
	dim.Activated:Connect(function()
		if options.DismissOnBackdrop ~= false then
			close(nil)
		end
	end)
	for index, action in options.Actions or {} do
		Button.new({
			Text = action.Text,
			Icon = action.Icon,
			Variant = action.Variant or "Secondary",
			LayoutOrder = index,
			Parent = footer,
			Callback = function()
				local result = action.Value
				if action.Resolve then
					result = action.Resolve()
					if result == false then
						return
					end
				end
				close(result)
			end,
		})
	end
	if options.Build then
		options.Build(body, close)
	end
	for _, descendant in card:GetDescendants() do
		if descendant:IsA("GuiObject") and descendant.ZIndex < 704 then
			descendant.ZIndex = 704
		end
	end
	Motion.Tween(dim, { BackgroundTransparency = 0.45 }, Motion.Base)
	Motion.Tween(card, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Motion.Slow)
	return close, body
end

function Dialog.Confirm(options)
	local thread = coroutine.running()
	local done = false
	Dialog.Custom({
		Title = options.Title,
		Message = options.Message,
		Icon = options.Icon or (options.Danger and "alert-triangle" or "help-circle"),
		Danger = options.Danger,
		Width = options.Width,
		Actions = {
			{ Text = options.Cancel or "Cancel", Value = false, Variant = "Ghost" },
			{ Text = options.Confirm or "Confirm", Icon = options.ConfirmIcon, Value = true, Variant = options.Danger and "Danger" or "Primary" },
		},
		OnClose = function(result)
			if not done then
				done = true
				task.spawn(thread, result == true)
			end
		end,
	})
	return coroutine.yield()
end

function Dialog.Prompt(options)
	local thread = coroutine.running()
	local done = false
	local field
	Dialog.Custom({
		Title = options.Title,
		Message = options.Message,
		Icon = options.Icon or "pencil",
		Width = options.Width,
		Actions = {
			{ Text = "Cancel", Value = nil, Variant = "Ghost" },
			{
				Text = options.Confirm or "Apply",
				Variant = "Primary",
				Resolve = function()
					return field:Get()
				end,
			},
		},
		Build = function(body, close)
			field = Field.new({
				Text = options.Default or "",
				Placeholder = options.Placeholder or "",
				Icon = options.FieldIcon,
				Mono = options.Mono,
				Height = 32,
				Parent = body,
			})
			field.Submitted:Connect(function(text, enter)
				if enter then
					close(text)
				end
			end)
			task.defer(function()
				field:Focus()
			end)
		end,
		OnClose = function(result)
			if not done then
				done = true
				task.spawn(thread, result)
			end
		end,
	})
	return coroutine.yield()
end

return Dialog
end

Modules["UI/Menu"] = function(import)
local Services = import("Core/Services")
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local Tooltip = import("UI/Tooltip")

local Menu = {}

local ROW = 28
local current
local catcher
local escapeConnection

local function textWidth(text, size, font)
	local ok, bounds = pcall(function()
		return Services.TextService:GetTextSize(text, size, font or Enum.Font.BuilderSansMedium, Vector2.new(2000, 40))
	end)
	if ok then
		return bounds.X
	end
	return #text * 7
end
Menu.TextWidth = textWidth

local function closeAll()
	if current then
		for _, frame in current.Frames do
			frame:Destroy()
		end
		local onClose = current.OnClose
		current = nil
		if onClose then
			task.spawn(onClose)
		end
	end
	if catcher then
		catcher.Visible = false
	end
end
Menu.Close = closeAll

local function ensureCatcher()
	if catcher then
		return
	end
	catcher = Create.New("TextButton", {
		Name = "MenuCatcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 800,
		Parent = Root.Layer,
	})
	catcher.MouseButton1Down:Connect(closeAll)
	catcher.MouseButton2Down:Connect(closeAll)
	escapeConnection = Services.UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and current then
			closeAll()
		end
	end)
end

function Menu.Destroy()
	if escapeConnection then
		escapeConnection:Disconnect()
		escapeConnection = nil
	end
	pcall(closeAll)
	if catcher then
		catcher:Destroy()
		catcher = nil
	end
	current = nil
end

local function measure(items)
	local width = 150
	for _, item in items do
		if not item.Separator then
			local w = 12 + 22 + textWidth(item.Text or item.Header or "", 13) + 14
			if item.Shortcut then
				w += textWidth(item.Shortcut, 11, Enum.Font.RobotoMono) + 18
			end
			if item.Children then
				w += 18
			end
			width = math.max(width, w)
		end
	end
	return math.min(width, 340)
end

local build

local function openSub(state, level, items, anchorRow)
	for index = #state.Frames, level + 1, -1 do
		state.Frames[index]:Destroy()
		table.remove(state.Frames, index)
	end
	if not items then
		return
	end
	local position = Vector2.new(anchorRow.AbsolutePosition.X + anchorRow.AbsoluteSize.X + 6, anchorRow.AbsolutePosition.Y - 4)
	build(state, items, position, level + 1, anchorRow)
end

function build(state, items, position, level, anchorRow)
	local width = measure(items)
	local height = 8
	for _, item in items do
		height += item.Separator and 9 or (item.Header and 24 or ROW)
	end
	local screen = Root.ScreenSize()
	local overflow = height > screen.Y - 12
	if overflow then
		height = screen.Y - 12
	end
	local x, y = position.X, position.Y
	if x + width > screen.X - 6 then
		x = anchorRow and (anchorRow.AbsolutePosition.X - width - 6) or (screen.X - width - 6)
	end
	if y + height > screen.Y - 6 then
		y = math.max(6, screen.Y - height - 6)
	end
	local holder = Create.New("Frame", {
		Name = "Menu" .. level,
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromOffset(x, y + 4),
		BackgroundTransparency = 1,
		ZIndex = 808 + level * 10,
		Parent = Root.Layer,
	})
	Create.Shadow(holder, 808 + level * 10)
	local frame = Create.New("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.T("Raised"),
		Active = true,
		ZIndex = 810 + level * 10,
		Corner = Theme.Radius,
		Stroke = { Color = "LineStrong" },
		Padding = not overflow and 4 or nil,
		List = not overflow and { Gap = 0 } or nil,
		Parent = holder,
	})
	local content = frame
	if overflow then
		content = Create.New("ScrollingFrame", {
			Name = "Scroll",
			Size = UDim2.fromScale(1, 1),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ZIndex = frame.ZIndex + 1,
			Padding = 4,
			List = { Gap = 0 },
			Parent = frame,
		})
	end
	table.insert(state.Frames, holder)
	Motion.Tween(holder, { Position = UDim2.fromOffset(x, y) }, Motion.Base)
	for index, item in items do
		if item.Separator then
			local holder = Create.New("Frame", {
				Size = UDim2.new(1, 0, 0, 9),
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Parent = content,
			})
			Create.New("Frame", {
				Size = UDim2.new(1, -8, 0, 1),
				Position = UDim2.fromOffset(4, 4),
				BackgroundColor3 = Theme.T("Line"),
				ZIndex = frame.ZIndex + 1,
				Parent = holder,
			})
			continue
		end
		if item.Header then
			Create.New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 24),
				Text = string.upper(item.Header),
				TextSize = 10,
				FontFace = Theme.FontBold,
				TextColor3 = Theme.T("Faint"),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = index,
				ZIndex = frame.ZIndex + 1,
				Padding = { 6, 0, 0, 10 },
				Parent = content,
			})
			continue
		end
		local disabled = item.Disabled
		local row = Create.New("TextButton", {
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundColor3 = Theme.T("Hover"),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			ZIndex = frame.ZIndex + 1,
			Corner = Theme.RadiusSmall,
			Parent = content,
		})
		local tint = disabled and "Faint" or (item.Danger and "Danger" or "Muted")
		local icon = Create.Icon(item.Icon or "dot", 15, Theme.T(tint), {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0),
			ImageTransparency = item.Icon and 0 or 1,
			ZIndex = frame.ZIndex + 2,
			Parent = row,
		})
		local label = Create.New("TextLabel", {
			Size = UDim2.new(1, -40, 1, 0),
			Position = UDim2.fromOffset(32, 0),
			Text = item.Text or "",
			TextSize = 13,
			FontFace = Theme.FontMedium,
			TextColor3 = Theme.T(disabled and "Faint" or (item.Danger and "Danger" or "Text")),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = frame.ZIndex + 2,
			Parent = row,
		})
		if item.Shortcut then
			Create.New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Size = UDim2.new(0, 80, 1, 0),
				Position = UDim2.new(1, -9, 0, 0),
				Text = item.Shortcut,
				TextSize = 11,
				FontFace = Theme.Mono,
				TextColor3 = Theme.T("Faint"),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = frame.ZIndex + 2,
				Parent = row,
			})
		end
		if item.Children then
			Create.Icon("chevron-right", 13, Theme.T("Faint"), {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -7, 0.5, 0),
				ZIndex = frame.ZIndex + 2,
				Parent = row,
			})
		end
		if item.Tooltip then
			Tooltip.Attach(row, item.Tooltip)
		end
		row.MouseEnter:Connect(function()
			if disabled then
				return
			end
			Motion.Tween(row, { BackgroundTransparency = 0 }, Motion.Fast)
			if item.Danger then
				Motion.Token(row, "BackgroundColor3", "AccentSoft")
			end
			Motion.Token(icon, "ImageColor3", item.Danger and "Danger" or "Accent")
			if item.Children then
				openSub(state, level, item.Children, row)
			elseif #state.Frames > level then
				openSub(state, level, nil)
			end
		end)
		row.MouseLeave:Connect(function()
			Motion.Tween(row, { BackgroundTransparency = 1 }, Motion.Fast)
			Motion.Token(icon, "ImageColor3", tint)
		end)
		row.Activated:Connect(function()
			if disabled then
				return
			end
			if item.Children then
				openSub(state, level, item.Children, row)
				return
			end
			closeAll()
			if item.Callback then
				task.spawn(item.Callback)
			end
		end)
		label.Parent = row
	end
	return frame
end

function Menu.Open(items, position, onClose)
	ensureCatcher()
	closeAll()
	if #items == 0 then
		return
	end
	local cleaned = {}
	local lastSeparator = true
	for _, item in items do
		if item.Separator then
			if not lastSeparator then
				table.insert(cleaned, item)
				lastSeparator = true
			end
		elseif item.Visible ~= false then
			table.insert(cleaned, item)
			lastSeparator = false
		end
	end
	if cleaned[#cleaned] and cleaned[#cleaned].Separator then
		table.remove(cleaned)
	end
	local state = { Frames = {}, OnClose = onClose }
	current = state
	catcher.Visible = true
	position = position or Services.UserInputService:GetMouseLocation()
	build(state, cleaned, position, 1)
	Tooltip.Hide()
end

function Menu.IsOpen()
	return current ~= nil
end

return Menu
end

Modules["UI/Picker"] = function(import)
local Services = import("Core/Services")
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local Field = import("UI/Field")
local VirtualList = import("UI/VirtualList")

local Picker = {}

local ROW = 26
local open

function Picker.Close()
	if open then
		open()
	end
end

function Picker.Open(options)
	Picker.Close()
	local items = options.Items
	local width = options.Width or 240
	local maxRows = options.MaxRows or 10
	local anchor = options.Anchor
	local filtered = items
	local catcher = Create.New("TextButton", {
		Name = "PickerCatcher",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 820,
		Parent = Root.Layer,
	})
	local height = math.min(#items, maxRows) * ROW + 8 + (options.Search ~= false and 36 or 0)
	local screen = Root.ScreenSize()
	local x, y
	if anchor then
		x = anchor.AbsolutePosition.X
		y = anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 4
		width = math.max(width, anchor.AbsoluteSize.X)
	else
		local mouse = Services.UserInputService:GetMouseLocation()
		x, y = mouse.X, mouse.Y
	end
	x = math.clamp(x, 6, screen.X - width - 6)
	if y + height > screen.Y - 6 then
		y = (anchor and anchor.AbsolutePosition.Y - height - 4) or (screen.Y - height - 6)
	end
	local holder = Create.New("Frame", {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.fromOffset(x, y + 4),
		BackgroundTransparency = 1,
		ZIndex = 830,
		Parent = catcher,
	})
	Create.Shadow(holder, 830)
	local panel = Create.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.T("Raised"),
		Active = true,
		ZIndex = 831,
		Corner = Theme.Radius,
		Stroke = { Color = "LineStrong" },
		Parent = holder,
	})
	Motion.Tween(holder, { Position = UDim2.fromOffset(x, y) }, Motion.Base)
	local closed = false
	local escape
	local function close(value)
		if closed then
			return
		end
		closed = true
		open = nil
		if escape then
			escape:Disconnect()
		end
		catcher:Destroy()
		if value ~= nil and options.Callback then
			task.spawn(options.Callback, value)
		end
		if options.OnClose then
			task.spawn(options.OnClose)
		end
	end
	open = function()
		close(nil)
	end
	catcher.MouseButton1Down:Connect(function()
		close(nil)
	end)
	escape = Services.UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			close(nil)
		end
	end)
	local top = 4
	local field
	if options.Search ~= false then
		field = Field.new({
			Icon = "search",
			Placeholder = options.Placeholder or "Search",
			Size = UDim2.new(1, -8, 0, 28),
			Position = UDim2.fromOffset(4, 4),
			Fill = "Field",
			Parent = panel,
		})
		top = 36
	end
	local list
	list = VirtualList.new({
		RowHeight = ROW,
		Size = UDim2.new(1, -8, 1, -(top + 4)),
		Position = UDim2.fromOffset(4, top),
		Parent = panel,
		ZIndex = 832,
		Count = function()
			return #filtered
		end,
		Create = function()
			local row = Create.New("TextButton", {
				Size = UDim2.new(1, -4, 0, ROW),
				BackgroundColor3 = Theme.T("Hover"),
				BackgroundTransparency = 1,
				ZIndex = 833,
				Corner = Theme.RadiusSmall,
			})
			local icon = Create.Icon("dot", 14, Theme.T("Muted"), {
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				ZIndex = 834,
				Parent = row,
			})
			local swatch = Create.New("Frame", {
				Name = "Swatch",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				Visible = false,
				ZIndex = 834,
				Corner = 4,
				Stroke = { Color = "LineStrong" },
				Parent = row,
			})
			local label = Create.New("TextLabel", {
				Name = "Label",
				Size = UDim2.new(1, -60, 1, 0),
				Position = UDim2.fromOffset(30, 0),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 834,
				Parent = row,
			})
			local check = Create.Icon("check", 13, Theme.T("Accent"), {
				Name = "Check",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Visible = false,
				ZIndex = 834,
				Parent = row,
			})
			row.MouseEnter:Connect(function()
				Motion.Tween(row, { BackgroundTransparency = 0 }, Motion.Fast)
				Motion.Token(icon, "ImageColor3", "Accent")
			end)
			row.MouseLeave:Connect(function()
				Motion.Tween(row, { BackgroundTransparency = 1 }, Motion.Fast)
				Motion.Token(icon, "ImageColor3", "Muted")
			end)
			row.Activated:Connect(function()
				local item = row:GetAttribute("Index") and filtered[row:GetAttribute("Index")]
				if item then
					close(item.Value ~= nil and item.Value or item.Text)
				end
			end)
			label.Parent = row
			check.Parent = row
			return row
		end,
		Bind = function(row, index)
			local item = filtered[index]
			row:SetAttribute("Index", index)
			row.Label.Text = item.Text
			local hasColor = item.Color ~= nil
			row.Swatch.Visible = hasColor
			row.Icon.Visible = not hasColor and item.Icon ~= nil
			if hasColor then
				row.Swatch.BackgroundColor3 = item.Color
			elseif item.Icon then
				import("Theme/Icons").Apply(row.Icon, item.Icon)
			end
			row.Label.Position = UDim2.fromOffset((hasColor or item.Icon) and 30 or 10, 0)
			row.Check.Visible = options.Selected ~= nil and (item.Value == options.Selected or item.Text == options.Selected)
		end,
	})
	local function applyFilter(text)
		text = string.lower(text or "")
		if text == "" then
			filtered = items
		else
			filtered = {}
			for _, item in items do
				if string.find(string.lower(item.Text), text, 1, true) then
					table.insert(filtered, item)
				end
			end
		end
		list.Scroll.CanvasPosition = Vector2.zero
		list:Rebind()
	end
	if field then
		field.Changed:Connect(applyFilter)
		field.Submitted:Connect(function(_, enter)
			if enter and filtered[1] then
				close(filtered[1].Value ~= nil and filtered[1].Value or filtered[1].Text)
			end
		end)
		task.defer(function()
			field:Focus()
		end)
	end
	list:Rebind()
	if options.Selected ~= nil then
		for index, item in items do
			if item.Value == options.Selected or item.Text == options.Selected then
				task.defer(function()
					list:ScrollTo(index, true)
				end)
				break
			end
		end
	end
	return close
end

return Picker
end

Modules["UI/Toast"] = function(import)
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local I18n = import("Core/I18n")

local Toast = {}

local KINDS = {
	info = { Icon = "info", Color = "Muted" },
	success = { Icon = "check-circle", Color = "Success" },
	warn = { Icon = "alert-triangle", Color = "Warning" },
	error = { Icon = "x-circle", Color = "Danger" },
	accent = { Icon = "sparkles", Color = "Accent" },
}

local stack

local function ensure()
	if stack then
		return
	end
	stack = Create.New("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(300, 400),
		BackgroundTransparency = 1,
		ZIndex = 950,
		List = { Gap = 8, VAlign = "Bottom", HAlign = "Right" },
		Parent = Root.Layer,
	})
end

local order = 0

Toast.Paused = false
Toast.Queue = {}

function Toast.Hold(on)
	Toast.Paused = on == true
	if not Toast.Paused then
		local queue = Toast.Queue
		Toast.Queue = {}
		for _, entry in queue do
			if not entry.Cancelled then
				Toast.Show(table.unpack(entry.Args, 1, entry.Args.n))
			end
		end
	end
end

function Toast.Show(title, message, kind, duration)
	ensure()
	if Toast.Paused then
		local entry = { Args = table.pack(title, message, kind, duration) }
		table.insert(Toast.Queue, entry)
		return function()
			entry.Cancelled = true
		end
	end
	title = I18n.Resolve(title)
	message = message ~= nil and I18n.Resolve(message) or nil
	local style = KINDS[kind or "info"] or KINDS.info
	order += 1
	local slot = Create.New("Frame", {
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		ZIndex = 950,
		Parent = stack,
	})
	local card = Create.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(320, 0),
		BackgroundColor3 = Theme.T("Raised"),
		ZIndex = 951,
		Corner = Theme.Radius,
		Stroke = { Color = "LineStrong" },
		Padding = { 10, 12, 11, 12 },
		Parent = slot,
	})
	card.BackgroundTransparency = 0
	local accentBar = Create.New("Frame", {
		Size = UDim2.new(0, 2, 1, -18),
		Position = UDim2.new(0, -12, 0, 9),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Theme.T(style.Color),
		ZIndex = 953,
		Corner = 1,
		Parent = card,
	})
	accentBar.Position = UDim2.fromOffset(-6, 2)
	accentBar.Size = UDim2.new(0, 2, 1, -4)
	Create.Icon(style.Icon, 16, Theme.T(style.Color), {
		Position = UDim2.fromOffset(2, 1),
		ZIndex = 952,
		Parent = card,
	})
	local body = Create.New("Frame", {
		Size = UDim2.new(1, -28, 0, 0),
		Position = UDim2.fromOffset(28, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 952,
		List = { Gap = 3 },
		Parent = card,
	})
	Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Text = title,
		TextSize = 13,
		FontFace = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 952,
		LayoutOrder = 1,
		Parent = body,
	})
	if message and message ~= "" then
		Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = message,
			TextSize = 12,
			TextColor3 = Theme.T("Muted"),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 952,
			LayoutOrder = 2,
			Parent = body,
		})
	end
	Motion.Tween(card, { Position = UDim2.fromOffset(0, 0) }, Motion.Slow)
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Motion.Tween(card, { Position = UDim2.fromOffset(320, 0) }, Motion.Base, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(Motion.Enabled() and Motion.Base or 0, function()
			slot:Destroy()
		end)
	end
	card.Activated:Connect(close)
	task.delay(duration or 3.6, close)
	return close
end

function Toast.Info(title, message)
	return Toast.Show(title, message, "info")
end

function Toast.Success(title, message)
	return Toast.Show(title, message, "success")
end

function Toast.Warn(title, message)
	return Toast.Show(title, message, "warn", 5)
end

function Toast.Error(title, message)
	return Toast.Show(title, message, "error", 6)
end

return Toast
end

Modules["UI/ColorPicker"] = function(import)
local Services = import("Core/Services")
local Store = import("Core/Store")
local Input = import("Core/Input")
local Util = import("Core/Util")
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local Field = import("UI/Field")
local Button = import("UI/Button")
local Tooltip = import("UI/Tooltip")

local ColorPicker = {}

local WIDTH = 280
local PAD = 10
local INNER = WIDTH - PAD * 2
local SV_TOP = 40
local SV_H = 160
local HUE_TOP = 210
local HUE_H = 14
local ROW_TOP = 234
local RGB_TOP = 270
local RECENT_TOP = 310
local HEIGHT = 358
local MAX_RECENT = 10
local Z = 860
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local open

function ColorPicker.Close()
	if open then
		open(true)
	end
end

local function hexOf(color)
	return string.sub(Util.Hex(color), 2)
end

local function parseHex(text)
	local clean = string.match(string.upper(tostring(text or "")), "^%s*#?([%x]+)%s*$")
	if not clean then
		return nil
	end
	if #clean == 3 then
		clean = string.gsub(clean, "%x", "%0%0")
	end
	if #clean ~= 6 then
		return nil
	end
	return Color3.fromRGB(tonumber(string.sub(clean, 1, 2), 16), tonumber(string.sub(clean, 3, 4), 16), tonumber(string.sub(clean, 5, 6), 16))
end

local function channels(color)
	return math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)
end

local function recentList()
	local stored = Store.Get("RecentColors")
	local list = {}
	if type(stored) == "table" then
		for _, entry in stored do
			local color = type(entry) == "string" and parseHex(entry)
			if color then
				table.insert(list, color)
			end
		end
	end
	return list
end

local function pushRecent(color)
	local hex = hexOf(color)
	local out = { hex }
	local stored = Store.Get("RecentColors")
	if type(stored) == "table" then
		for _, entry in stored do
			if type(entry) == "string" and string.upper(entry) ~= hex and #out < MAX_RECENT then
				table.insert(out, string.upper(entry))
			end
		end
	end
	Store.Set("RecentColors", out)
end

local function hueSequence()
	local points = {}
	for index = 0, 6 do
		table.insert(points, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV((index % 6) / 6, 1, 1)))
	end
	return ColorSequence.new(points)
end

local function placement(anchor)
	local screen = Root.ScreenSize()
	local x, y
	if anchor then
		x = anchor.AbsolutePosition.X
		y = anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 6
		if y + HEIGHT > screen.Y - 8 then
			y = anchor.AbsolutePosition.Y - HEIGHT - 6
		end
	else
		local mouse = Services.UserInputService:GetMouseLocation()
		x, y = mouse.X + 8, mouse.Y + 8
	end
	x = math.clamp(x, 8, math.max(8, screen.X - WIDTH - 8))
	y = math.clamp(y, 8, math.max(8, screen.Y - HEIGHT - 8))
	return x, y
end

local function buildShell(anchor)
	local catcher = Create.New("TextButton", {
		Name = "ColorPickerCatcher",
		Size = UDim2.fromScale(1, 1),
		ZIndex = Z,
		Parent = Root.Layer,
	})
	local x, y = placement(anchor)
	local holder = Create.New("Frame", {
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = UDim2.fromOffset(x, y + 6),
		BackgroundTransparency = 1,
		Parent = catcher,
	})
	Create.Shadow(holder, 1, 20, 0.35)
	local panel = Create.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.T("Raised"),
		Active = true,
		ZIndex = 2,
		Corner = Theme.Radius + 2,
		Stroke = { Color = "LineStrong" },
		Parent = holder,
	})
	Motion.Tween(holder, { Position = UDim2.fromOffset(x, y) }, Motion.Base)
	return catcher, holder, panel
end

local function buildHeader(panel, title, onDone, onCancel)
	Create.Icon("palette", 14, Theme.T("Accent"), {
		Position = UDim2.fromOffset(PAD + 1, PAD + 3),
		Parent = panel,
	})
	Create.New("TextLabel", {
		Position = UDim2.fromOffset(PAD + 22, PAD),
		Size = UDim2.new(1, -(PAD * 2 + 80), 0, 20),
		Text = title or "Colour",
		TextSize = 13,
		FontFace = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = panel,
	})
	Button.Icon({
		Icon = "check",
		Size = 24,
		Tooltip = "Apply color",
		Color = "Accent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD - 26, 0, PAD - 2),
		Parent = panel,
		Callback = onDone,
	})
	Button.Icon({
		Icon = "x",
		Size = 24,
		Tooltip = "Cancel color change",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD + 2, 0, PAD - 2),
		Parent = panel,
		Callback = onCancel,
	})
end

local function ring(parent, size, zIndex)
	local halo = Create.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size + 6, size + 6),
		BackgroundColor3 = Theme.T("Shade"),
		BackgroundTransparency = 0.55,
		Corner = UDim.new(1, 0),
		ZIndex = zIndex,
		Parent = parent,
	})
	local knob = Create.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE,
		Corner = UDim.new(1, 0),
		Stroke = { Color = "Text", Thickness = 2 },
		ZIndex = zIndex,
		Parent = halo,
	})
	return halo, knob
end

local function buildSquare(panel)
	local square = Create.New("Frame", {
		Name = "Square",
		Position = UDim2.fromOffset(PAD, SV_TOP),
		Size = UDim2.fromOffset(INNER, SV_H),
		BackgroundColor3 = WHITE,
		Corner = 6,
		Parent = panel,
	})
	local gradient = Create.New("UIGradient", {
		Color = ColorSequence.new(WHITE, Color3.fromHSV(0, 1, 1)),
		Parent = square,
	})
	local shade = Create.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		Corner = 6,
		Parent = square,
	})
	Create.New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0),
		Parent = shade,
	})
	Create.New("UIStroke", { Color = Theme.T("Line"), Parent = square })
	local hit = Create.New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = square,
	})
	local halo, knob = ring(square, 12, 4)
	return { Frame = square, Gradient = gradient, Hit = hit, Halo = halo, Knob = knob }
end

local function buildHue(panel)
	local strip = Create.New("Frame", {
		Name = "Hue",
		Position = UDim2.fromOffset(PAD, HUE_TOP),
		Size = UDim2.fromOffset(INNER, HUE_H),
		BackgroundColor3 = WHITE,
		Corner = UDim.new(1, 0),
		Parent = panel,
	})
	Create.New("UIGradient", { Color = hueSequence(), Parent = strip })
	local hit = Create.New("TextButton", {
		Position = UDim2.fromOffset(0, -8),
		Size = UDim2.new(1, 0, 1, 16),
		ZIndex = 3,
		Parent = strip,
	})
	local knob = Create.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(8, HUE_H + 6),
		BackgroundColor3 = WHITE,
		Corner = 4,
		Stroke = { Color = "Text", Thickness = 2 },
		ZIndex = 4,
		Parent = strip,
	})
	return { Frame = strip, Hit = hit, Knob = knob }
end

local function buildPreview(panel, old, onRevert)
	local frame = Create.New("Frame", {
		Position = UDim2.fromOffset(PAD, ROW_TOP),
		Size = UDim2.fromOffset(56, 28),
		BackgroundTransparency = 1,
		Corner = 6,
		Stroke = { Color = "Line" },
		Parent = panel,
	})
	local before = Create.New("TextButton", {
		Size = UDim2.new(0.5, 6, 1, 0),
		BackgroundColor3 = old,
		Corner = 6,
		Parent = frame,
	})
	before.BackgroundTransparency = 0
	Tooltip.Attach(before, "Revert to the original colour")
	before.Activated:Connect(onRevert)
	local after = Create.New("Frame", {
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = old,
		Active = true,
		Corner = 6,
		ZIndex = 2,
		Parent = frame,
	})
	local edge = Create.New("Frame", {
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = old,
		Active = true,
		ZIndex = 2,
		Parent = frame,
	})
	return { after, edge }
end

local function channelField(panel, letter, index)
	local width = math.floor((INNER - 12) / 3)
	local field = Field.new({
		Mono = true,
		Size = UDim2.fromOffset(width, 28),
		Position = UDim2.fromOffset(PAD + (index - 1) * (width + 6), RGB_TOP),
		Parent = panel,
	})
	field.Box.Position = UDim2.fromOffset(24, 0)
	field.Box.Size = UDim2.new(1, -30, 1, 0)
	Create.New("TextLabel", {
		Position = UDim2.fromOffset(9, 0),
		Size = UDim2.new(0, 12, 1, 0),
		Text = letter,
		TextSize = 11,
		FontFace = Theme.FontBold,
		TextColor3 = Theme.T("Faint"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = field.Instance,
	})
	return field
end

local function swatch(parent, color, order, onPick)
	local button = Create.New("TextButton", {
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = color,
		LayoutOrder = order,
		Corner = 5,
		Stroke = { Color = "Line" },
		Parent = parent,
	})
	button.BackgroundTransparency = 0
	local outline = button:FindFirstChildOfClass("UIStroke")
	button.MouseEnter:Connect(function()
		Motion.Token(outline, "Color", "Text")
	end)
	button.MouseLeave:Connect(function()
		Motion.Token(outline, "Color", "Line")
	end)
	button.Activated:Connect(function()
		onPick(color)
	end)
	Tooltip.Attach(button, "#" .. hexOf(color))
	return button
end

local function buildRecent(panel, onPick)
	Create.New("TextLabel", {
		Position = UDim2.fromOffset(PAD, RECENT_TOP),
		Size = UDim2.fromOffset(INNER, 12),
		Text = "RECENT",
		TextSize = 10,
		FontFace = Theme.FontBold,
		TextColor3 = Theme.T("Faint"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local row = Create.New("Frame", {
		Position = UDim2.fromOffset(PAD, RECENT_TOP + 18),
		Size = UDim2.fromOffset(INNER, 20),
		BackgroundTransparency = 1,
		List = { Dir = "X", Gap = 4, VAlign = "Center" },
		Parent = panel,
	})
	local colors = recentList()
	if #colors == 0 then
		Create.New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = "Colours you pick show up here",
			TextSize = 12,
			TextColor3 = Theme.T("Faint"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		return
	end
	for index, color in colors do
		swatch(row, color, index, onPick)
	end
end

local function hookDrag(state, hit, fromPoint)
	table.insert(state.Links, Input.Drag(hit, {
		Begin = function(point)
			state.Dragging = true
			fromPoint(point)
		end,
		Move = function(_, point)
			fromPoint(point)
		end,
		End = function()
			state.Dragging = false
		end,
	}))
end

local function relative(gui, point)
	local position, size = gui.AbsolutePosition, gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return nil
	end
	return math.clamp((point.X - position.X) / size.X, 0, 1), math.clamp((point.Y - position.Y) / size.Y, 0, 1)
end

local function render(state, skip)
	local color = Color3.fromHSV(state.H, state.S, state.V)
	state.Color = color
	local pure = Color3.fromHSV(state.H, 1, 1)
	state.Square.Gradient.Color = ColorSequence.new(WHITE, pure)
	if state.Glide then
		state.Glide()
	else
		state.Square.Halo.Position = UDim2.fromScale(state.S, 1 - state.V)
		state.Hue.Knob.Position = UDim2.fromScale(state.H, 0.5)
	end
	state.Square.Knob.BackgroundColor3 = color
	state.Hue.Knob.BackgroundColor3 = pure
	for _, part in state.After do
		part.BackgroundColor3 = color
	end
	if skip ~= "hex" then
		state.HexField:Set(hexOf(color))
	end
	if skip ~= "rgb" then
		local r, g, b = channels(color)
		state.Channels[1]:Set(tostring(r))
		state.Channels[2]:Set(tostring(g))
		state.Channels[3]:Set(tostring(b))
	end
end

local function emit(state)
	local color = state.Color
	if state.Last and state.Last == color then
		return
	end
	state.Last = color
	if state.Options.Callback then
		task.spawn(state.Options.Callback, color)
	end
end

local function setColor(state, color, skip)
	local h, s, v = color:ToHSV()
	if s > 0 and v > 0 then
		state.H = h
	end
	if v > 0 then
		state.S = s
	end
	state.V = v
	render(state, skip)
	emit(state)
end

local function bindFields(state)
	state.HexField.Submitted:Connect(function(text)
		local color = parseHex(text)
		if color then
			setColor(state, color, nil)
		else
			state.HexField:Set(hexOf(state.Color))
		end
	end)
	for index, field in state.Channels do
		field.Submitted:Connect(function(text)
			local number = tonumber(text)
			if not number then
				render(state, nil)
				return
			end
			local r, g, b = channels(state.Color)
			local values = { r, g, b }
			values[index] = math.clamp(math.floor(number + 0.5), 0, 255)
			setColor(state, Color3.fromRGB(values[1], values[2], values[3]), nil)
		end)
	end
end

local function bindDrags(state)
	hookDrag(state, state.Square.Hit, function(point)
		local x, y = relative(state.Square.Frame, point)
		if x then
			state.S, state.V = x, 1 - y
			render(state, nil)
			emit(state)
		end
	end)
	hookDrag(state, state.Hue.Hit, function(point)
		local x = relative(state.Hue.Frame, point)
		if x then
			state.H = math.min(x, 0.9999)
			render(state, nil)
			emit(state)
		end
	end)
end

function ColorPicker.Open(options)
	ColorPicker.Close()
	options = options or {}
	local original = typeof(options.Color) == "Color3" and options.Color or Theme.Get("Accent")
	local catcher, holder, panel = buildShell(options.Anchor)
	local state = { Options = options, Links = {}, Dragging = false, Last = original, Color = original }
	state.H, state.S, state.V = original:ToHSV()
	local closed = false
	local escape

	local function close(commit)
		if closed then
			return
		end
		closed = true
		open = nil
		if escape then
			escape:Disconnect()
		end
		for _, link in state.Links do
			pcall(link.Disconnect)
		end
		local final = commit and state.Color or nil
		if commit then
			pushRecent(state.Color)
		elseif state.Color ~= original and options.Callback then
			task.spawn(options.Callback, original)
		end
		Motion.Tween(holder, { Position = holder.Position + UDim2.fromOffset(0, 4) }, Motion.Fast)
		task.delay(Motion.Enabled() and Motion.Fast or 0, function()
			catcher:Destroy()
		end)
		if options.OnClose then
			task.spawn(options.OnClose, final)
		end
	end
	open = close

	buildHeader(panel, options.Title, function()
		close(true)
	end, function()
		close(false)
	end)
	state.Square = buildSquare(panel)
	state.Hue = buildHue(panel)

	-- The knobs glide towards the finger with a frame-rate independent ease instead of
	-- jumping, which is what makes the picker feel smooth on touch screens. The colour
	-- itself is always exact: only the knob graphics are eased.
	local shownS, shownV, shownH = state.S, state.V, state.H
	local glide
	local function applyKnobs()
		state.Square.Halo.Position = UDim2.fromScale(shownS, 1 - shownV)
		state.Hue.Knob.Position = UDim2.fromScale(shownH, 0.5)
	end
	state.Glide = function()
		if not Motion.Enabled() then
			shownS, shownV, shownH = state.S, state.V, state.H
			applyKnobs()
			return
		end
		if glide then
			return
		end
		glide = Services.RunService.RenderStepped:Connect(function(dt)
			local alpha = 1 - math.exp(-dt * 40)
			shownS = shownS + (state.S - shownS) * alpha
			shownV = shownV + (state.V - shownV) * alpha
			shownH = shownH + (state.H - shownH) * alpha
			applyKnobs()
			if math.abs(state.S - shownS) < 0.002 and math.abs(state.V - shownV) < 0.002 and math.abs(state.H - shownH) < 0.002 then
				shownS, shownV, shownH = state.S, state.V, state.H
				applyKnobs()
				glide:Disconnect()
				glide = nil
			end
		end)
	end
	table.insert(state.Links, {
		Disconnect = function()
			if glide then
				glide:Disconnect()
				glide = nil
			end
		end,
	})
	state.After = buildPreview(panel, original, function()
		setColor(state, original, nil)
	end)
	state.HexField = Field.new({
		Icon = "hash",
		Placeholder = "#FFFFFF",
		Mono = true,
		Size = UDim2.fromOffset(INNER - 64, 28),
		Position = UDim2.fromOffset(PAD + 64, ROW_TOP),
		Parent = panel,
	})
	state.Channels = { channelField(panel, "R", 1), channelField(panel, "G", 2), channelField(panel, "B", 3) }
	buildRecent(panel, function(color)
		setColor(state, color, nil)
	end)

	setColor(state, original, nil)
	state.Last = original
	bindFields(state)
	bindDrags(state)

	catcher.MouseButton1Down:Connect(function()
		close(true)
	end)
	escape = Services.UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			close(false)
		end
	end)
	return function()
		close(true)
	end
end

return ColorPicker
end

Modules["UI/CodeView"] = function(import)
local Services = import("Core/Services")
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Signal = import("Core/Signal")
local Scope = import("Core/Scope")
local Input = import("Core/Input")
local Util = import("Core/Util")
local Field = import("UI/Field")
local Button = import("UI/Button")
local Highlight = import("Core/Highlight")

local CodeView = {}
CodeView.__index = CodeView

local PAD_X = 10
local PAD_Y = 6
local MAX_COLS = 6000
local MAX_MATCHES = 4000

local function hexOf(name)
	return Util.Hex(Theme.Get(name))
end

function CodeView.new(options)
	local self = setmetatable({}, CodeView)
	self.TextSize = options.TextSize or 13
	self.Editable = options.Editable == true
	self.ShowGutter = options.Gutter ~= false
	self.OnChanged = options.OnChanged
	self.Changed = Signal.new()
	self.Scope = Scope.new()
	self._text = ""
	self.Lines = { "" }
	self.Session = Highlight.Session(self.Lines)
	self._matchRows = {}
	self._matches = {}
	self._matchIndex = 1
	self._maxCols = 1

	self.Instance = Create.New("Frame", {
		Name = "CodeView",
		Size = options.Size or UDim2.fromScale(1, 1),
		Position = options.Position or UDim2.new(),
		BackgroundColor3 = Theme.T("Base"),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = options.Parent,
	})

	self:_measure()
	self:_buildGutter()
	self:_buildCode()
	self:_buildFind()
	self:_bindEvents()
	if options.Text then
		self:SetText(options.Text)
	else
		self:_refresh(true)
	end
	return self
end

function CodeView:_measure()
	local size = self.TextSize
	local charW, lineH = size * 0.6, size + 5
	local ok, bounds = pcall(function()
		return Services.TextService:GetTextSize(string.rep("0", 64), size, Enum.Font.RobotoMono, Vector2.new(100000, 4000))
	end)
	if ok and bounds.X > 0 then
		charW = bounds.X / 64
		lineH = bounds.Y
	end
	self._charW = charW
	self._lineH = math.max(math.floor(lineH + 0.5), size + 3)
end

function CodeView:_gutterWidth()
	if not self.ShowGutter then
		return 0
	end
	local digits = math.max(#tostring(#self.Lines), 2)
	return math.floor(digits * self._charW) + 20
end

function CodeView:_buildGutter()
	local width = self:_gutterWidth()
	self._gutter = Create.New("Frame", {
		Name = "Gutter",
		Size = UDim2.new(0, width, 1, 0),
		BackgroundColor3 = Theme.T("Shade"),
		BackgroundTransparency = self.ShowGutter and 0.4 or 1,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = self.Instance,
	})
	self._gutterLabel = Create.New("TextLabel", {
		Size = UDim2.new(1, -8, 0, self._lineH),
		Position = UDim2.fromOffset(0, PAD_Y),
		FontFace = Theme.Mono,
		TextSize = self.TextSize,
		TextColor3 = Theme.T("Faint"),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		Text = "",
		Visible = self.ShowGutter,
		Parent = self._gutter,
	})
	self._divider = Create.New("Frame", {
		Name = "GutterLine",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.T("Line"),
		Visible = self.ShowGutter,
		Parent = self._gutter,
	})
end

function CodeView:_buildCode()
	local left = self:_gutterWidth()
	self._holder = Create.New("Frame", {
		Name = "Code",
		Size = UDim2.new(1, -left, 1, 0),
		Position = UDim2.fromOffset(left, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.Instance,
	})
	self.Scroll = Create.New("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 5,
		ScrollingDirection = Enum.ScrollingDirection.XY,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		HorizontalScrollBarInset = Enum.ScrollBarInset.None,
		CanvasSize = UDim2.new(),
		Parent = self._holder,
	})
	self._matchLayer = Create.New("Frame", {
		Name = "Matches",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = self.Scroll,
	})
	self._codeLabel = Create.New("TextLabel", {
		Name = "Lines",
		Position = UDim2.fromOffset(PAD_X, PAD_Y),
		Size = UDim2.fromOffset(200, self._lineH),
		FontFace = Theme.Mono,
		TextSize = self.TextSize,
		TextColor3 = Theme.Syntax.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		Text = "",
		ZIndex = 3,
		Parent = self.Scroll,
	})
	if self.Editable then
		self._editBox = Create.New("TextBox", {
			Name = "Editor",
			Position = UDim2.fromOffset(PAD_X, PAD_Y),
			Size = UDim2.fromOffset(200, self._lineH),
			BackgroundTransparency = 1,
			TextTransparency = 1,
			FontFace = Theme.Mono,
			TextSize = self.TextSize,
			TextColor3 = Theme.Syntax.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ClearTextOnFocus = false,
			MultiLine = true,
			TextWrapped = false,
			Text = "",
			ZIndex = 4,
			Parent = self.Scroll,
		})
	else
		self._selBox = Create.New("TextBox", {
			Name = "Selection",
			Position = UDim2.fromOffset(PAD_X, PAD_Y),
			Size = UDim2.fromOffset(200, self._lineH),
			BackgroundTransparency = 1,
			TextTransparency = 1,
			TextEditable = false,
			ClearTextOnFocus = false,
			FontFace = Theme.Mono,
			TextSize = self.TextSize,
			TextColor3 = Theme.Syntax.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			MultiLine = true,
			TextWrapped = false,
			Active = true,
			Text = "",
			ZIndex = 4,
			Parent = self.Scroll,
		})
	end
end

function CodeView:_buildFind()
	local bar = Create.New("Frame", {
		Name = "FindBar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(312, 32),
		BackgroundColor3 = Theme.T("Raised"),
		Visible = false,
		ZIndex = 20,
		Corner = Theme.RadiusSmall + 1,
		Stroke = { Color = "LineStrong" },
		Padding = { 4, 4, 4, 6 },
		List = { Dir = "X", Gap = 4, VAlign = "Center" },
		Parent = self._holder,
	})
	self._findField = Field.new({
		Placeholder = "Find",
		Mono = true,
		Height = 24,
		Size = UDim2.new(1, -118, 0, 24),
		LayoutOrder = 1,
		Parent = bar,
	})
	self._findField.Instance.ZIndex = 21
	self._findCount = Create.New("TextLabel", {
		Size = UDim2.fromOffset(58, 24),
		Text = "",
		TextSize = 11,
		FontFace = Theme.Mono,
		TextColor3 = Theme.T("Faint"),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 21,
		Parent = bar,
	})
	Button.Icon({ Icon = "chevron-up", Size = 24, Tooltip = "Previous", LayoutOrder = 3, Parent = bar, Callback = function()
		self:_step(-1)
	end })
	Button.Icon({ Icon = "chevron-down", Size = 24, Tooltip = "Next", LayoutOrder = 4, Parent = bar, Callback = function()
		self:_step(1)
	end })
	Button.Icon({ Icon = "x", Size = 24, Tooltip = "Close", LayoutOrder = 5, Parent = bar, Callback = function()
		self:_closeFind()
	end })
	self._findBar = bar
	self._findField.Changed:Connect(function(text)
		self:_runFind(text)
	end)
	self._findField.Submitted:Connect(function(_, enter)
		if enter then
			self:_step(1)
		end
	end)
end

function CodeView:_bindEvents()
	self.Scope:Add(self.Scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_refresh()
	end))
	self.Scope:Add(self.Scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_refresh(true)
	end))
	self.Scope:Add(self.Scroll.MouseMoved:Connect(function(_, y)
		local line = self:_lineAtY(y)
		if line ~= self._hoverLine then
			self._hoverLine = line
			self:_paintGutter()
		end
	end))
	self.Scope:Add(self.Scroll.MouseLeave:Connect(function()
		if self._hoverLine then
			self._hoverLine = nil
			self:_paintGutter()
		end
	end))
	self.Scope:Add(Services.UserInputService.InputBegan:Connect(function(input, processed)
		self:_onInput(input, processed)
	end))
	if self.Editable then
		self._debouncedHighlight = Util.Debounce(0.06, function()
			self.Session = Highlight.Session(self.Lines)
			self:_recomputeWidth()
			self:_refresh(true)
		end)
		self.Scope:Add(self._editBox:GetPropertyChangedSignal("Text"):Connect(function()
			if self._syncing then
				return
			end
			self._text = self._editBox.Text
			self.Lines = Util.Lines(self._text)
			self._debouncedHighlight()
			self.Changed:Fire(self._text)
			if self.OnChanged then
				self.OnChanged(self._text)
			end
		end))
	end
	self.Scope:Add(self.Instance)
end

function CodeView:_onInput(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local hovering = Input.Inside(self.Instance)
	if input.KeyCode == Enum.KeyCode.F and Input.Ctrl() and (hovering or self._findBar.Visible) then
		self:_openFind()
	elseif input.KeyCode == Enum.KeyCode.Escape and self._findBar.Visible then
		self:_closeFind()
	elseif input.KeyCode == Enum.KeyCode.Tab and self.Editable and self._editBox:IsFocused() then
		self:_insertTab()
	end
end

function CodeView:_insertTab()
	local box = self._editBox
	local cursor = box.CursorPosition
	if cursor < 1 then
		return
	end
	local text = box.Text
	self._syncing = true
	box.Text = string.sub(text, 1, cursor - 1) .. "    " .. string.sub(text, cursor)
	box.CursorPosition = cursor + 4
	self._syncing = false
	self._text = box.Text
	self.Lines = Util.Lines(self._text)
	self._debouncedHighlight()
	self.Changed:Fire(self._text)
	if self.OnChanged then
		self.OnChanged(self._text)
	end
end

function CodeView:_lineAtY(y)
	local local_ = y - self.Scroll.AbsolutePosition.Y + self.Scroll.CanvasPosition.Y - PAD_Y
	return math.floor(local_ / self._lineH) + 1
end

function CodeView:_recomputeWidth()
	local maxCols = 1
	for _, line in self.Lines do
		local length = #line
		if length > maxCols then
			maxCols = length
		end
	end
	self._maxCols = math.min(maxCols, MAX_COLS)
	local width = self:_gutterWidth()
	self._gutter.Size = UDim2.new(0, width, 1, 0)
	self._gutterLabel.Visible = self.ShowGutter
	self._holder.Size = UDim2.new(1, -width, 1, 0)
	self._holder.Position = UDim2.fromOffset(width, 0)
end

function CodeView:_ensureRows(needed)
	for index = #self._matchRows + 1, needed do
		local frame = Create.New("Frame", {
			Size = UDim2.fromOffset(60, self._lineH),
			BackgroundColor3 = Theme.T("AccentSoft"),
			BackgroundTransparency = 0.35,
			Visible = false,
			ZIndex = 2,
			Corner = 3,
			Parent = self._matchLayer,
		})
		local stroke = Create.Stroke(frame, { Color = "Accent", Transparency = 1 })
		self._matchRows[index] = { Frame = frame, Stroke = stroke }
	end
end

function CodeView:_refresh(force)
	local lines = self.Lines
	local count = #lines
	local lineH = self._lineH
	local canvasH = count * lineH + PAD_Y * 2
	local viewW = self.Scroll.AbsoluteSize.X
	local canvasW = math.max(self._maxCols * self._charW + PAD_X * 2, viewW)
	if force or self._canvasH ~= canvasH or self._canvasW ~= canvasW then
		self._canvasH = canvasH
		self._canvasW = canvasW
		self.Scroll.CanvasSize = UDim2.fromOffset(canvasW, canvasH)
		if self.Editable then
			self._editBox.Size = UDim2.fromOffset(math.max(canvasW - PAD_X, 50), math.max(canvasH - PAD_Y, lineH))
		end
	end

	local canvasY = self.Scroll.CanvasPosition.Y
	local viewH = self.Scroll.AbsoluteSize.Y
	local first = math.max(1, math.floor((canvasY - PAD_Y) / lineH))
	local visible = math.ceil(viewH / lineH) + 3
	local last = math.min(count, first + visible - 1)
	if first < 1 then
		first = 1
	end

	local labelTop = PAD_Y + (first - 1) * lineH
	local richParts = {}
	for index = first, last do
		richParts[#richParts + 1] = self.Session:Get(index)
	end
	self._codeLabel.Position = UDim2.fromOffset(PAD_X, labelTop)
	self._codeLabel.Size = UDim2.fromOffset(math.max(canvasW - PAD_X, 50), (last - first + 1) * lineH + lineH)
	self._codeLabel.Text = table.concat(richParts, "\n")

	self._firstLine = first
	self._lastLine = last
	self:_paintGutter()
	self:_refreshSelection(first, last, canvasW)
	self:_refreshMatches(first, last)
end

function CodeView:_paintGutter()
	if not self.ShowGutter or not self._firstLine then
		return
	end
	local mutedHex = hexOf("Muted")
	local parts = {}
	for index = self._firstLine, self._lastLine do
		if index == self._currentLine or index == self._hoverLine then
			parts[#parts + 1] = '<font color="' .. mutedHex .. '">' .. index .. "</font>"
		else
			parts[#parts + 1] = tostring(index)
		end
	end
	local lineH = self._lineH
	self._gutterLabel.Position = UDim2.fromOffset(0, PAD_Y + (self._firstLine - 1) * lineH - self.Scroll.CanvasPosition.Y)
	self._gutterLabel.Size = UDim2.new(1, -8, 0, (self._lastLine - self._firstLine + 1) * lineH + lineH)
	self._gutterLabel.Text = table.concat(parts, "\n")
end

function CodeView:_refreshSelection(first, last, canvasW)
	if self.Editable or not self._selBox then
		return
	end
	local buf = {}
	for index = first, last do
		buf[#buf + 1] = self.Lines[index]
	end
	self._selBox.Position = UDim2.fromOffset(PAD_X, PAD_Y + (first - 1) * self._lineH)
	self._selBox.Size = UDim2.fromOffset(math.max(canvasW - PAD_X, 50), (last - first + 1) * self._lineH + self._lineH)
	self._selBox.Text = table.concat(buf, "\n")
end

function CodeView:_refreshMatches(first, last)
	local lineH = self._lineH
	local charW = self._charW
	local current = self._matches[self._matchIndex]
	local slot = 0
	for _, match in self._matches do
		if match.line >= first and match.line <= last then
			slot += 1
			self:_ensureRows(slot)
			local entry = self._matchRows[slot]
			entry.Frame.Position = UDim2.fromOffset(PAD_X + (match.col - 1) * charW, PAD_Y + (match.line - 1) * lineH + 1)
			entry.Frame.Size = UDim2.fromOffset(math.max(match.len * charW, 2), lineH - 2)
			entry.Frame.Visible = true
			entry.Stroke.Transparency = (match == current) and 0 or 1
		end
	end
	for index = slot + 1, #self._matchRows do
		self._matchRows[index].Frame.Visible = false
	end
end

function CodeView:_openFind()
	self._findBar.Visible = true
	local current = self._findField:Get()
	if current ~= "" then
		self:_runFind(current)
	end
	self._findField:Focus()
end

function CodeView:_closeFind()
	self._findBar.Visible = false
	self._matches = {}
	self:_refresh(true)
end

function CodeView:_runFind(query)
	self._matches = {}
	if query and query ~= "" then
		local needle = string.lower(query)
		local length = #needle
		for index, line in self.Lines do
			local hay = string.lower(line)
			local from = 1
			while true do
				local start = string.find(hay, needle, from, true)
				if not start then
					break
				end
				self._matches[#self._matches + 1] = { line = index, col = start, len = length }
				from = start + length
				if #self._matches >= MAX_MATCHES then
					break
				end
			end
			if #self._matches >= MAX_MATCHES then
				break
			end
		end
	end
	self._matchIndex = 1
	if #self._matches > 0 then
		for index, match in self._matches do
			if not self._currentLine or match.line >= self._currentLine then
				self._matchIndex = index
				break
			end
		end
		self:_focusMatch()
	else
		self:_updateCount()
		self:_refresh(true)
	end
end

function CodeView:_updateCount()
	if #self._matches == 0 then
		self._findCount.Text = (self._findField:Get() == "") and "" or "none"
	else
		self._findCount.Text = self._matchIndex .. " of " .. #self._matches
	end
end

function CodeView:_step(direction)
	if #self._matches == 0 then
		return
	end
	self._matchIndex = (self._matchIndex - 1 + direction) % #self._matches + 1
	self:_focusMatch()
end

function CodeView:_focusMatch()
	local match = self._matches[self._matchIndex]
	if not match then
		return
	end
	self._currentLine = match.line
	self:_updateCount()
	self:_scrollToLine(match.line, true)
	local x = PAD_X + (match.col - 1) * self._charW
	local viewW = self.Scroll.AbsoluteSize.X
	local currentX = self.Scroll.CanvasPosition.X
	if x < currentX + 20 or x > currentX + viewW - 40 then
		local target = math.clamp(x - viewW / 2, 0, math.max(0, (self._canvasW or 0) - viewW))
		self.Scroll.CanvasPosition = Vector2.new(target, self.Scroll.CanvasPosition.Y)
	end
	self:_refresh(true)
end

function CodeView:_scrollToLine(line, center)
	local lineH = self._lineH
	local viewH = self.Scroll.AbsoluteSize.Y
	local top = PAD_Y + (line - 1) * lineH
	local target = center and (top - viewH / 2 + lineH / 2) or top
	local maxY = math.max(0, (self._canvasH or 0) - viewH)
	target = math.clamp(target, 0, maxY)
	Motion.Tween(self.Scroll, { CanvasPosition = Vector2.new(self.Scroll.CanvasPosition.X, target) }, Motion.Base)
end

function CodeView:SetText(text)
	self._text = text or ""
	self.Lines = Util.Lines(self._text)
	if #self.Lines == 0 then
		self.Lines = { "" }
	end
	self.Session = Highlight.Session(self.Lines)
	self._matches = {}
	self._currentLine = nil
	self._hoverLine = nil
	self:_recomputeWidth()
	if self.Editable and self._editBox then
		self._syncing = true
		self._editBox.Text = self._text
		self._syncing = false
	end
	self.Scroll.CanvasPosition = Vector2.zero
	self:_refresh(true)
end

function CodeView:GetText()
	if self.Editable and self._editBox then
		return self._editBox.Text
	end
	return self._text
end

function CodeView:Find(query)
	self._findBar.Visible = true
	if query then
		self._findField:Set(query)
	end
	self._findField:Focus()
	self:_runFind(self._findField:Get())
end

function CodeView:GotoLine(line)
	local target = math.clamp(line, 1, #self.Lines)
	self._currentLine = target
	self:_scrollToLine(target, true)
	self:_refresh(true)
end

function CodeView:Focus()
	if self.Editable and self._editBox then
		self._editBox:CaptureFocus()
	elseif self._selBox then
		self._selBox:CaptureFocus()
	end
end

function CodeView:SetTextSize(size)
	self.TextSize = math.clamp(size, 9, 28)
	self:_measure()
	self._gutterLabel.TextSize = self.TextSize
	self._codeLabel.TextSize = self.TextSize
	if self._editBox then
		self._editBox.TextSize = self.TextSize
	end
	if self._selBox then
		self._selBox.TextSize = self.TextSize
	end
	self:_recomputeWidth()
	self:_refresh(true)
end

function CodeView:Destroy()
	self.Scope:Clean()
end

return CodeView
end

Modules["UI/VirtualList"] = function(import)
local Create = import("UI/Create")
local Motion = import("UI/Motion")

local VirtualList = {}
VirtualList.__index = VirtualList

function VirtualList.new(options)
	local self = setmetatable({}, VirtualList)
	self.RowHeight = options.RowHeight or 22
	self.Count = options.Count
	self.Make = options.Create
	self.Bind = options.Bind
	self.Padding = options.Padding or 0
	self.Pool = {}
	self.Scroll = Create.New("ScrollingFrame", {
		Name = options.Name or "List",
		Size = options.Size or UDim2.fromScale(1, 1),
		Position = options.Position or UDim2.new(),
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		CanvasSize = UDim2.new(),
		ZIndex = options.ZIndex or 1,
		Parent = options.Parent,
	})
	self.Scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:Refresh()
	end)
	self.Scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Refresh(true)
	end)
	return self
end

function VirtualList:_ensurePool(needed)
	for index = #self.Pool + 1, needed do
		local row = self.Make(index)
		row.Parent = self.Scroll
		self.Pool[index] = { Row = row, Index = nil }
	end
end

function VirtualList:Refresh(force)
	local count = self.Count()
	local rowHeight = self.RowHeight
	local total = count * rowHeight + self.Padding * 2
	if self._total ~= total then
		self._total = total
		self.Scroll.CanvasSize = UDim2.fromOffset(0, total)
	end
	local viewHeight = self.Scroll.AbsoluteSize.Y
	local first = math.max(1, math.floor((self.Scroll.CanvasPosition.Y - self.Padding) / rowHeight) + 1)
	local visible = math.ceil(viewHeight / rowHeight) + 2
	self:_ensurePool(visible)
	for slot = 1, #self.Pool do
		local entry = self.Pool[slot]
		local index = first + slot - 1
		if slot <= visible and index <= count then
			local y = self.Padding + (index - 1) * rowHeight
			if force or entry.Index ~= index or entry.Row.Position.Y.Offset ~= y then
				entry.Index = index
				entry.Row.Position = UDim2.new(0, 0, 0, y)
				entry.Row.Visible = true
				self.Bind(entry.Row, index)
			end
		elseif entry.Row.Visible then
			entry.Row.Visible = false
			entry.Index = nil
		end
	end
end

function VirtualList:Rebind()
	self:Refresh(true)
end

function VirtualList:IndexAtY(y)
	local local_ = y - self.Scroll.AbsolutePosition.Y + self.Scroll.CanvasPosition.Y - self.Padding
	return math.floor(local_ / self.RowHeight) + 1
end

function VirtualList:ScrollTo(index, center, animate)
	local rowHeight = self.RowHeight
	local viewHeight = self.Scroll.AbsoluteSize.Y
	local top = self.Padding + (index - 1) * rowHeight
	local current = self.Scroll.CanvasPosition.Y
	local target
	if center then
		target = top - viewHeight / 2 + rowHeight / 2
	elseif top < current then
		target = top
	elseif top + rowHeight > current + viewHeight then
		target = top + rowHeight - viewHeight
	else
		return
	end
	local maxY = math.max(0, (self._total or 0) - viewHeight)
	target = math.clamp(target, 0, maxY)
	if animate then
		Motion.Tween(self.Scroll, { CanvasPosition = Vector2.new(0, target) }, Motion.Base)
	else
		self.Scroll.CanvasPosition = Vector2.new(0, target)
	end
end

function VirtualList:Rows()
	local list = {}
	for _, entry in self.Pool do
		if entry.Index then
			table.insert(list, entry)
		end
	end
	return list
end

return VirtualList
end

Modules["UI/Window"] = function(import)
local Services = import("Core/Services")
local Signal = import("Core/Signal")
local Scope = import("Core/Scope")
local Store = import("Core/Store")
local Input = import("Core/Input")
local Theme = import("Theme/Theme")
local Background = import("Theme/Background")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local Button = import("UI/Button")
local I18n = import("Core/I18n")

local Window = {}
Window.__index = Window
Window.All = {}
Window.ToolsSuppressed = false
Window.Changed = Signal.new()
Window.Focused = Signal.new()

local HEADER = 38
local GRIP = 7
local SNAP = 14
local topZ = 10

local function bounds()
	local screen = Root.ScreenSize()
	local top = Root.TopInset()
	return screen, top
end

local function saved(id)
	local all = Store.Get("Windows")
	return type(all) == "table" and all[id] or nil
end

local function persist(self)
	if not self.Id then
		return
	end
	local all = table.clone(Store.Get("Windows") or {})
	local position, size = self.Frame.Position, self._size
	all[self.Id] = { position.X.Offset, position.Y.Offset, size.X, size.Y }
	Store.Set("Windows", all)
end

function Window.new(options)
	local self = setmetatable({}, Window)
	self.Id = options.Id
	self.Scope = Scope.new()
	self.MinSize = options.MinSize or Vector2.new(260, 160)
	self.Visible = false
	self.Minimized = false
	self.VisibilityChanged = Signal.new()
	self.Resized = Signal.new()
	self.Closed = Signal.new()
	self._onClose = options.OnClose
	self.IsHub = options.Hub == true
	self._suppressed = not self.IsHub and Window.ToolsSuppressed == true

	local screen, top = bounds()
	local size = options.Size or Vector2.new(420, 320)
	local position
	if options.Dock == "Right" then
		size = Vector2.new(size.X, screen.Y - top - 22)
		position = Vector2.new(screen.X - size.X - 10, top + 12)
	else
		position = options.Position or Vector2.new((screen.X - size.X) / 2, (screen.Y - size.Y) / 2 + 10)
	end
	local memory = options.Remember ~= false and self.Id and saved(self.Id)
	if memory then
		position = Vector2.new(memory[1], memory[2])
		size = Vector2.new(memory[3], memory[4])
	end
	size = Vector2.new(math.max(size.X, self.MinSize.X), math.max(size.Y, self.MinSize.Y))
	self._size = size

	local root = Create.New("Frame", {
		Name = options.Id or "Window",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(position.X, position.Y),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = topZ,
		Parent = Root.Windows,
	})
	self.Frame = root
	self._scale = Create.New("UIScale", { Scale = Store.Get("UIScale") or 1, Parent = root })
	self.Scope:Add(Store.Changed:Connect(function(key, value)
		if key == "UIScale" then
			self._scale.Scale = value
		end
	end))
	self._shadow = Create.Shadow(root, 0, 22, 0.35)

	local panel = Create.New("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.T("Base"),
		ZIndex = 1,
		Corner = Theme.Radius + 2,
		Stroke = { Color = "Line" },
		Parent = root,
	})
	self.Panel = panel
	self.BackgroundImage = Background.Attach(panel, self.Scope, Theme.Radius + 2, self._shadow)

	local header = Create.New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = panel,
	})
	self.Header = header
	local iconWrap = Create.New("Frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.T("AccentSofter"),
		ZIndex = 3,
		Corner = 6,
		Parent = header,
	})
	self.TitleIcon = Create.Icon(options.Icon or "app-window", 13, Theme.T("Accent"), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 4,
		Parent = iconWrap,
	})
	local titleHolder = Create.New("Frame", {
		Size = UDim2.new(1, -160, 1, 0),
		Position = UDim2.fromOffset(40, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
		List = { Dir = "X", Gap = 7, VAlign = "Center" },
		Parent = header,
	})
	self.TitleLabel = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = options.Title or "Window",
		TextSize = 14,
		FontFace = Theme.FontBold,
		ZIndex = 3,
		LayoutOrder = 1,
		Parent = titleHolder,
	})
	self.SubtitleLabel = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = options.Subtitle or "",
		TextSize = 12,
		TextColor3 = Theme.T("Faint"),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		LayoutOrder = 2,
		Parent = titleHolder,
	})
	local actions = Create.New("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 3,
		List = { Dir = "X", Gap = 2, VAlign = "Center" },
		Parent = header,
	})
	self.Actions = actions
	self._actionOrder = 0
	if options.Minimizable ~= false then
		Button.Icon({
			Icon = "minus",
			Tooltip = "Minimize",
			LayoutOrder = 1000,
			Parent = actions,
			Callback = function()
				self:SetMinimized(not self.Minimized)
			end,
		})
	end
	if options.Closable ~= false then
		Button.Icon({
			Icon = "x",
			Tooltip = "Close",
			Danger = true,
			LayoutOrder = 1001,
			Parent = actions,
			Callback = function()
				self:Close()
			end,
		})
	end

	Create.New("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, HEADER),
		BackgroundColor3 = Theme.T("Line"),
		ZIndex = 2,
		Parent = panel,
	})

	self.Body = Create.New("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -(HEADER + 1)),
		Position = UDim2.fromOffset(0, HEADER + 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = panel,
	})

	self._veil = Create.New("Frame", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.T("Base"),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 60,
		Corner = Theme.Radius + 2,
		Parent = panel,
	})

	self:_bindDrag()
	if options.Resizable ~= false then
		self:_bindResize()
	end
	table.insert(Window.All, self)
	return self
end

function Window:AddAction(options)
	self._actionOrder += 1
	options.LayoutOrder = options.LayoutOrder or self._actionOrder
	options.Parent = self.Actions
	return Button.Icon(options)
end

function Window:SetTitle(text)
	I18n.Bind(self.TitleLabel, "Text", text)
end

function Window:SetSubtitle(text)
	I18n.Bind(self.SubtitleLabel, "Text", text or "")
end

function Window:SetIcon(name)
	Create.SetIcon(self.TitleIcon, name)
end

function Window:Focus()
	topZ += 1
	self.Frame.ZIndex = topZ
	Window.Focused:Fire(self)
end

function Window:_clamp(position, size)
	local screen = Root.ScreenSize()
	local x = math.clamp(position.X, -size.X + 80, screen.X - 80)
	local y = math.clamp(position.Y, 0, screen.Y - HEADER)
	return Vector2.new(x, y)
end

-- Where a window comes to rest: fully on screen on every side (left, right, top AND
-- bottom). With `magnet` a window that was released close to an edge is pulled to the
-- margin, which gives the soft "snap back" feeling.
function Window:_rest(position, magnet)
	local screen, top = bounds()
	local size = self.Frame.AbsoluteSize
	local minX, minY = 10, top + 12
	local maxX = math.max(minX, screen.X - size.X - 10)
	local maxY = math.max(minY, screen.Y - size.Y - 10)
	local x, y = position.X, position.Y
	if magnet then
		if x < SNAP then
			x = minX
		end
		if x + size.X > screen.X - SNAP then
			x = maxX
		end
		if y < top + SNAP then
			y = minY
		end
		if y + size.Y > screen.Y - SNAP then
			y = maxY
		end
	end
	return Vector2.new(math.clamp(x, minX, maxX), math.clamp(y, minY, maxY))
end

-- Shrinks a window that is bigger than the screen (phones in landscape, rotation...).
function Window:_fitSize()
	local screen, top = bounds()
	local scale = self._scale and self._scale.Scale or 1
	local maxX = math.max((screen.X - 20) / scale, 200)
	local maxY = math.max((screen.Y - top - 24) / scale, 140)
	local size = self._size
	local width, height = math.min(size.X, maxX), math.min(size.Y, maxY)
	if width ~= size.X or height ~= size.Y then
		self:_applySize(Vector2.new(width, height))
	end
end

-- Brings the window back inside the screen (used on show, rotation and resolution changes).
function Window:Refit(animated)
	self:_fitSize()
	local current = Vector2.new(self.Frame.Position.X.Offset, self.Frame.Position.Y.Offset)
	local rest = self:_rest(current, false)
	if (rest - current).Magnitude > 0.5 then
		if animated and Motion.Enabled() then
			Motion.Tween(self.Frame, { Position = UDim2.fromOffset(rest.X, rest.Y) }, Motion.Base)
		else
			self.Frame.Position = UDim2.fromOffset(rest.X, rest.Y)
		end
	end
end

function Window:_bindDrag()
	local RunService = Services.RunService
	local startPosition, target, shown, link
	local function finish()
		if link then
			link:Disconnect()
			link = nil
		end
		shown = nil
		task.delay(0.1, persist, self)
	end
	-- The frame follows the finger through a frame-rate independent ease instead of
	-- jumping to it, so dragging feels fluid even when touch events arrive unevenly.
	local function step(dt)
		if not target then
			finish()
			return
		end
		if Motion.Enabled() then
			shown = shown + (target - shown) * (1 - math.exp(-dt * 30))
		else
			shown = target
		end
		self.Frame.Position = UDim2.fromOffset(shown.X, shown.Y)
		if not startPosition and (target - shown).Magnitude < 0.4 then
			self.Frame.Position = UDim2.fromOffset(target.X, target.Y)
			target = nil
			finish()
		end
	end
	local function run()
		if not link then
			shown = Vector2.new(self.Frame.Position.X.Offset, self.Frame.Position.Y.Offset)
			link = RunService.RenderStepped:Connect(step)
		end
	end
	self.Scope:Add(function()
		if link then
			link:Disconnect()
			link = nil
		end
	end)
	self.Scope:Add(Input.Drag(self.Header, {
		Begin = function(point)
			if Input.Inside(self.Actions, point) then
				startPosition = nil
				return
			end
			startPosition = Vector2.new(self.Frame.Position.X.Offset, self.Frame.Position.Y.Offset)
			if link and target then
				startPosition = target
			end
			target = startPosition
			self:Focus()
			run()
		end,
		Move = function(delta)
			if not startPosition then
				return
			end
			target = self:_clamp(startPosition + delta, self.Frame.AbsoluteSize)
		end,
		End = function()
			if not startPosition then
				return
			end
			startPosition = nil
			-- every side behaves the same now: released outside (or near an edge) means it
			-- eases back to a fully visible position
			target = self:_rest(target or Vector2.new(self.Frame.Position.X.Offset, self.Frame.Position.Y.Offset), true)
			if not link then
				run()
			end
		end,
	}))
end

function Window:_applySize(size, position)
	self._size = size
	if not self.Minimized then
		self.Frame.Size = UDim2.fromOffset(size.X, size.Y)
	end
	if position then
		self.Frame.Position = UDim2.fromOffset(position.X, position.Y)
	end
	self.Resized:Fire(size)
end

function Window:_bindResize()
	local zones = {
		{ Name = "R", Size = UDim2.new(0, GRIP, 1, -GRIP * 2), Position = UDim2.new(1, -GRIP / 2, 0, GRIP), X = 1, Y = 0 },
		{ Name = "L", Size = UDim2.new(0, GRIP, 1, -GRIP * 2), Position = UDim2.new(0, -GRIP / 2, 0, GRIP), X = -1, Y = 0 },
		{ Name = "B", Size = UDim2.new(1, -GRIP * 2, 0, GRIP), Position = UDim2.new(0, GRIP, 1, -GRIP / 2), X = 0, Y = 1 },
		{ Name = "BR", Size = UDim2.fromOffset(GRIP * 2, GRIP * 2), Position = UDim2.new(1, -GRIP * 1.5, 1, -GRIP * 1.5), X = 1, Y = 1 },
		{ Name = "BL", Size = UDim2.fromOffset(GRIP * 2, GRIP * 2), Position = UDim2.new(0, -GRIP / 2, 1, -GRIP * 1.5), X = -1, Y = 1 },
	}
	for _, zone in zones do
		local grip = Create.New("TextButton", {
			Name = "Grip" .. zone.Name,
			Size = zone.Size,
			Position = zone.Position,
			ZIndex = 70,
			Parent = self.Frame,
		})
		local startSize, startPosition
		self.Scope:Add(Input.Drag(grip, {
			Begin = function()
				if self.Minimized then
					startSize = nil
					return
				end
				startSize = self._size
				startPosition = Vector2.new(self.Frame.Position.X.Offset, self.Frame.Position.Y.Offset)
				self:Focus()
			end,
			Move = function(delta)
				if not startSize then
					return
				end
				local width, height = startSize.X, startSize.Y
				local x = startPosition.X
				if zone.X == 1 then
					width = math.max(self.MinSize.X, startSize.X + delta.X)
				elseif zone.X == -1 then
					width = math.max(self.MinSize.X, startSize.X - delta.X)
					x = startPosition.X + (startSize.X - width)
				end
				if zone.Y == 1 then
					height = math.max(self.MinSize.Y, startSize.Y + delta.Y)
				end
				self:_applySize(Vector2.new(width, height), Vector2.new(x, startPosition.Y))
			end,
			End = function()
				if startSize then
					startSize = nil
					persist(self)
				end
			end,
		}))
	end
end

function Window:SetBounds(position, size)
	if size then
		self:_applySize(Vector2.new(math.max(size.X, self.MinSize.X), math.max(size.Y, self.MinSize.Y)))
	end
	if position then
		self.Frame.Position = UDim2.fromOffset(position.X, position.Y)
	end
	persist(self)
end

function Window.ApplyLayout(all)
	if type(all) ~= "table" then
		return
	end
	local merged = table.clone(Store.Get("Windows") or {})
	for id, memory in all do
		if type(id) == "string" and type(memory) == "table" and type(memory[1]) == "number" and type(memory[2]) == "number"
			and type(memory[3]) == "number" and type(memory[4]) == "number" then
			merged[id] = { memory[1], memory[2], memory[3], memory[4] }
		end
	end
	Store.Set("Windows", merged)
	for _, window in table.clone(Window.All) do
		local memory = window.Id and merged[window.Id]
		if memory then
			window:SetBounds(Vector2.new(memory[1], memory[2]), Vector2.new(memory[3], memory[4]))
		end
	end
end

function Window:SetMinimized(value)
	self.Minimized = value
	local target = value and Vector2.new(self._size.X, HEADER) or self._size
	if not value then
		self.Body.Visible = true
	end
	local tween = Motion.Tween(self.Frame, { Size = UDim2.fromOffset(target.X, target.Y) }, Motion.Base)
	if value then
		local function hideBody()
			if self.Minimized then
				self.Body.Visible = false
			end
		end
		if tween then
			tween.Completed:Once(hideBody)
		else
			hideBody()
		end
	end
end

function Window:Show()
	if self.Visible then
		self:Focus()
		return
	end
	if not self.IsHub and Window.ToolsSuppressed and Window.OnToolShown then
		Window.OnToolShown()
	end
	self.Visible = true
	self:Focus()
	local frame = self.Frame
	frame.Visible = not self._suppressed
	self:Refit(false)
	if Motion.Enabled() then
		local final = frame.Position
		frame.Position = final + UDim2.fromOffset(0, 10)
		self._veil.Visible = true
		self._veil.BackgroundTransparency = 0
		self._shadow.ImageTransparency = 1
		Motion.Tween(frame, { Position = final }, Motion.Slow)
		Motion.Tween(self._shadow, { ImageTransparency = 0.35 }, Motion.Slow)
		local fade = Motion.Tween(self._veil, { BackgroundTransparency = 1 }, Motion.Base, Enum.EasingStyle.Quad)
		fade.Completed:Once(function()
			if self.Visible then
				self._veil.Visible = false
			end
		end)
	end
	self.VisibilityChanged:Fire(true)
	Window.Changed:Fire(self)
end

function Window:Hide()
	if not self.Visible then
		return
	end
	self.Visible = false
	local frame = self.Frame
	if Motion.Enabled() then
		self._veil.Visible = true
		Motion.Tween(self._shadow, { ImageTransparency = 1 }, Motion.Fast)
		local fade = Motion.Tween(self._veil, { BackgroundTransparency = 0 }, Motion.Fast, Enum.EasingStyle.Quad)
		fade.Completed:Once(function()
			if not self.Visible then
				frame.Visible = false
			end
		end)
	else
		frame.Visible = false
	end
	self.VisibilityChanged:Fire(false)
	Window.Changed:Fire(self)
end

function Window:Toggle()
	if self.Visible then
		self:Hide()
	else
		self:Show()
	end
end

function Window:Close()
	self:Hide()
	self.Closed:Fire()
	if self._onClose then
		task.spawn(self._onClose)
	end
end

function Window:SetSuppressed(value)
	value = value == true
	if self._suppressed == value then
		return
	end
	self._suppressed = value
	if self.Visible then
		self.Frame.Visible = not value
	end
end

function Window.SetToolsSuppressed(value)
	value = value == true
	Window.ToolsSuppressed = value
	for _, window in Window.All do
		if not window.IsHub then
			window:SetSuppressed(value)
		end
	end
end

function Window:Destroy()
	self.Scope:Clean()
	local index = table.find(Window.All, self)
	if index then
		table.remove(Window.All, index)
	end
	self.Frame:Destroy()
	Window.Changed:Fire(self)
end

function Window.FocusAt(point)
	local best
	for _, window in Window.All do
		if window.Visible and not window._suppressed and Input.Inside(window.Frame, point) then
			if not best or window.Frame.ZIndex > best.Frame.ZIndex then
				best = window
			end
		end
	end
	if best and best.Frame.ZIndex < topZ then
		best:Focus()
	end
	return best
end

function Window.Start(scope)
	local pending = false
	scope:Connect(Root.Main:GetPropertyChangedSignal("AbsoluteSize"), function()
		if pending then
			return
		end
		pending = true
		task.delay(0.15, function()
			pending = false
			for _, window in Window.All do
				if window.Visible then
					window:Refit(true)
				end
			end
		end)
	end)
	scope:Connect(Services.UserInputService.InputBegan, function(input)
		if Input.IsPrimary(input) or input.UserInputType == Enum.UserInputType.MouseButton2 then
			Window.FocusAt(Input.Pointer(input))
		end
	end)
end

return Window
end

Modules["UI/Watermark"] = function(import)
local Services = import("Core/Services")
local Scope = import("Core/Scope")
local I18n = import("Core/I18n")
local Theme = import("Theme/Theme")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local Drag = import("UI/Drag")

--[[
	Watermark: a small draggable pill (like a HUD) made of icon + text entries.

	local mark = DeaUI.Watermark({ Title = "My Hub", Icon = "sparkles", Corner = "TopRight" })
	mark:AddFPS()
	mark:AddPing()
	mark:AddTime()
	mark:AddUser()
	local custom = mark:AddText({ Icon = "swords", Text = { en = "Aimbot: ON", vi = "Aimbot: BẬT" } })
	custom:SetText("Aimbot: OFF")
	mark:SetVisible(false)
]]
local Watermark = {}
Watermark.__index = Watermark
Watermark.All = {}

local HEIGHT = 28

local function place(self, animate)
	local frame = self.Frame
	local size = frame.AbsoluteSize
	if size.X <= 0 then
		return
	end
	local screen, top = Root.ScreenSize(), Root.TopInset()
	local corner = self.Corner
	local x, y
	if corner then
		x = string.find(corner, "Right") and (screen.X - size.X - 12) or 12
		y = string.find(corner, "Bottom") and (screen.Y - size.Y - 12) or (top + 8)
	else
		x, y = self.Pos.X, self.Pos.Y
	end
	local fitted = Drag.Fit(Vector2.new(x, y), size, 6)
	self.Pos = fitted
	if self.Dragging then
		return
	end
	local goal = UDim2.fromOffset(fitted.X, fitted.Y)
	if animate and self.Placed then
		Motion.Tween(frame, { Position = goal }, Motion.Base)
	else
		frame.Position = goal
	end
	self.Placed = true
end

local function dividers(self)
	local first = true
	for _, item in self.Items do
		if item.Visible then
			item.Divider.Visible = not first
			first = false
		end
	end
end

function Watermark.new(options)
	options = options or {}
	local self = setmetatable({}, Watermark)
	self.Scope = Scope.new()
	self.Items = {}
	self.Visible = options.Visible ~= false
	self.Held = false
	self.Corner = options.Position == nil and (options.Corner or "TopRight") or nil
	self.Pos = typeof(options.Position) == "Vector2" and options.Position or Vector2.new(12, 12)
	self.Placed = false

	local frame = Create.New("CanvasGroup", {
		Name = "Watermark",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, HEIGHT),
		Position = UDim2.fromOffset(self.Pos.X, self.Pos.Y - 10),
		BackgroundColor3 = Theme.T("Panel"),
		BackgroundTransparency = 0.04,
		GroupTransparency = 1,
		Active = true,
		Visible = self.Visible and not self.Held,
		ZIndex = 820,
		Corner = Theme.Radius,
		Stroke = { Color = "LineStrong" },
		List = { Dir = "X", Gap = 0, VAlign = "Center" },
		Parent = Root.Bar,
	})
	self.Frame = frame
	self.Scope:Add(frame)

	-- brand block: accent bar, icon and title
	local brand = Create.New("Frame", {
		Name = "Brand",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Padding = { 0, 8, 0, 10 },
		List = { Dir = "X", Gap = 6, VAlign = "Center" },
		Parent = frame,
	})
	Create.New("Frame", {
		Size = UDim2.fromOffset(3, 14),
		BackgroundColor3 = Theme.T("Accent"),
		Corner = 1,
		LayoutOrder = 0,
		Parent = brand,
	})
	if options.Icon then
		Create.Icon(options.Icon, 14, Theme.T("Accent"), { LayoutOrder = 1, Parent = brand })
	end
	self.TitleLabel = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		Text = options.Title or "DeaUI",
		TextSize = 12,
		FontFace = Theme.FontBold,
		LayoutOrder = 2,
		Parent = brand,
	})
	self.Brand = brand

	self.Scope:Connect(frame:GetPropertyChangedSignal("AbsoluteSize"), function()
		place(self, true)
	end)
	self.Scope:Connect(Root.Main:GetPropertyChangedSignal("AbsoluteSize"), function()
		place(self, true)
	end)

	if options.Draggable ~= false then
		self.Scope:Add(Drag.Bind(frame, frame, {
			Rest = function(position, size)
				self.Dragging = false
				return Drag.Fit(position, size, 6)
			end,
			OnEnd = function(position)
				self.Corner = nil
				self.Pos = position
			end,
		}))
		self.Scope:Connect(frame.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				self.Dragging = true
			end
		end)
	end

	table.insert(Watermark.All, self)
	task.defer(function()
		if self.Destroyed then
			return
		end
		place(self, false)
		if self.Visible and not self.Held then
			Motion.Tween(frame, { GroupTransparency = 0 }, Motion.Slow)
		end
	end)
	return self
end

-- { Id, Icon, Text, Interval, Update = function() -> text, Mono, Color } -> item
function Watermark:AddText(options)
	options = options or {}
	local order = #self.Items + 1
	local holder = Create.New("Frame", {
		Name = options.Id or ("Item" .. order),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		List = { Dir = "X", Gap = 6, VAlign = "Center" },
		Padding = { 0, 8, 0, 0 },
		Parent = self.Frame,
	})
	local divider = Create.New("Frame", {
		Size = UDim2.fromOffset(1, 12),
		BackgroundColor3 = Theme.T("LineStrong"),
		LayoutOrder = 0,
		Parent = holder,
	})
	local item = { Holder = holder, Divider = divider, Visible = true }
	local nextOrder = 1
	if options.Icon then
		item.Icon = Create.Icon(options.Icon, 13, Theme.T(options.Color or "Muted"), { LayoutOrder = nextOrder, Parent = holder })
		nextOrder += 1
	end
	item.Label = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		TextSize = 12,
		FontFace = options.Mono == false and Theme.FontMedium or Theme.Mono,
		TextColor3 = Theme.T("Text"),
		LayoutOrder = nextOrder,
		Parent = holder,
	})
	I18n.Bind(item.Label, "Text", options.Text or "")
	local owner = self
	function item:SetText(text)
		I18n.Bind(self.Label, "Text", text)
	end
	function item:SetIcon(name)
		if self.Icon then
			Create.SetIcon(self.Icon, name)
		end
	end
	function item:SetVisible(visible)
		self.Visible = visible == true
		self.Holder.Visible = self.Visible
		dividers(owner)
	end
	function item:Destroy()
		local index = table.find(owner.Items, self)
		if index then
			table.remove(owner.Items, index)
		end
		self.Holder:Destroy()
		dividers(owner)
	end
	table.insert(self.Items, item)
	dividers(self)

	if options.Update then
		local timer = 0
		local interval = options.Interval or 1
		local function refresh()
			local ok, text = pcall(options.Update)
			if ok and text ~= nil then
				item:SetText(text)
			end
		end
		refresh()
		self.Scope:Connect(Services.RunService.Heartbeat, function(dt)
			timer += dt
			if timer >= interval and self.Visible then
				timer = 0
				refresh()
			end
		end)
	end
	return item
end

function Watermark:AddFPS(options)
	options = options or {}
	local frames, elapsed, fps = 0, 0, 60
	self.Scope:Connect(Services.RunService.RenderStepped, function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= 0.5 then
			fps = frames / elapsed
			frames, elapsed = 0, 0
		end
	end)
	return self:AddText({
		Id = "FPS",
		Icon = options.Icon or "gauge",
		Interval = 0.5,
		Update = function()
			return string.format("%d FPS", math.floor(fps + 0.5))
		end,
	})
end

function Watermark:AddPing(options)
	options = options or {}
	return self:AddText({
		Id = "Ping",
		Icon = options.Icon or "wifi",
		Interval = 1,
		Update = function()
			local ok, ping = pcall(function()
				return Services.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			return string.format("%d ms", ok and math.floor(ping + 0.5) or 0)
		end,
	})
end

function Watermark:AddTime(format, options)
	options = options or {}
	format = format or "%H:%M:%S"
	return self:AddText({
		Id = "Time",
		Icon = options.Icon or "clock",
		Interval = 1,
		Update = function()
			return os.date(format)
		end,
	})
end

function Watermark:AddUser(options)
	options = options or {}
	local player = Services.Players.LocalPlayer
	local name = player and (options.DisplayName == false and player.Name or player.DisplayName) or "Player"
	return self:AddText({ Id = "User", Icon = options.Icon or "user", Text = name })
end

function Watermark:SetTitle(text)
	I18n.Bind(self.TitleLabel, "Text", text)
end

-- self.Visible is what the user asked for; self.Held only hides it while a loader is on screen
local function present(self)
	if self.Destroyed then
		return
	end
	local frame = self.Frame
	if self.Visible and not self.Held then
		frame.Visible = true
		place(self, false)
		Motion.Tween(frame, { GroupTransparency = 0 }, Motion.Base)
		return
	end
	local tween = Motion.Tween(frame, { GroupTransparency = 1 }, Motion.Base)
	if tween then
		tween.Completed:Once(function()
			if not (self.Visible and not self.Held) then
				frame.Visible = false
			end
		end)
	else
		frame.Visible = false
	end
end

function Watermark:SetVisible(visible)
	visible = visible == true
	if self.Visible == visible then
		return
	end
	self.Visible = visible
	present(self)
end

function Watermark:SetHeld(held)
	held = held == true
	if self.Held == held then
		return
	end
	self.Held = held
	present(self)
end

function Watermark:Toggle()
	self:SetVisible(not self.Visible)
end

function Watermark:Destroy()
	self.Destroyed = true
	local index = table.find(Watermark.All, self)
	if index then
		table.remove(Watermark.All, index)
	end
	self.Scope:Clean()
end

return Watermark
end

Modules["Library"] = function(import)
local Env = import("Core/Env")
local Services = import("Core/Services")
local Signal = import("Core/Signal")
local Scope = import("Core/Scope")
local Store = import("Core/Store")
local Input = import("Core/Input")
local Util = import("Core/Util")
local Theme = import("Theme/Theme")
local Icons = import("Theme/Icons")
local Create = import("UI/Create")
local Motion = import("UI/Motion")
local Root = import("UI/Root")
local Window = import("UI/Window")
local Button = import("UI/Button")
local Switch = import("UI/Switch")
local Slider = import("UI/Slider")
local Tabs = import("UI/Tabs")
local Field = import("UI/Field")
local Dialog = import("UI/Dialog")
local Menu = import("UI/Menu")
local Picker = import("UI/Picker")
local Toast = import("UI/Toast")
local Tooltip = import("UI/Tooltip")
local ColorPicker = import("UI/ColorPicker")
local CodeView = import("UI/CodeView")
local VirtualList = import("UI/VirtualList")
local I18n = import("Core/I18n")
local Drag = import("UI/Drag")
local Watermark = import("UI/Watermark")
import("Lang/Phrases")

local HANDLE = "__DeaUI_Active"
local NAV_W = 148
local NAV_ROW = 32
local NAV_GAP = 2
local NAV_TOP = 10

local Library = {
	Version = "2.0.0",
	Initialized = false,
	Destroyed = false,
	Visible = true,
	Capturing = false,
	Hubs = {},
	MobileButtons = {},
	Flags = {},
	VipActive = false,
	Locks = setmetatable({}, { __mode = "k" }),
	LoadingCount = 0,
	Held = {},
	ToolsHidden = false,
	ToolsChanged = Signal.new(),
	VipChanged = Signal.new(),
}

-- Low level building blocks (the original modules, untouched).
Library.Modules = {
	Env = Env, Signal = Signal, Scope = Scope, Store = Store, Input = Input,
	Theme = Theme, Icons = Icons, Create = Create, Motion = Motion, Root = Root,
	Window = Window, Button = Button, Switch = Switch, Slider = Slider, Tabs = Tabs,
	Field = Field, Dialog = Dialog, Menu = Menu, Picker = Picker, Toast = Toast,
	Tooltip = Tooltip, ColorPicker = ColorPicker, CodeView = CodeView, VirtualList = VirtualList,
}

local Hub = {}
Hub.__index = Hub
local Page = {}
Page.__index = Page
local Group = {}
Group.__index = Group

local function safe(callback)
	if type(callback) ~= "function" then
		return nil
	end
	return function(...)
		task.spawn(callback, ...)
	end
end

local function connect(signal, callback)
	callback = safe(callback)
	if callback then
		signal:Connect(callback)
	end
end

local function ensure()
	if Library.Destroyed then
		error("[DeaUI] the library was destroyed - load it again to create a new UI", 3)
	end
	if not Library.Initialized then
		Library.Init()
	end
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

--[[
	DeaUI.Init(options)
	  Folder          string   main folder in the executor workspace (default "DeaUI"): settings.json, configs/, Icon/, Tools/
	  Persist         boolean  save theme / window size and position to disk and reload them every run (default true)
	  Vip             boolean  true = VIP user, unlocks every VIP tab and element (default false)
	  OnVipRequest    function called when a locked VIP item is tapped
	  ToolsToggleKey  Enum.KeyCode | false   key that hides/shows the tool windows (default RightShift)
	  ToolsButton     boolean  round wrench button for the tool windows (default: on touch devices)
	  Theme           string   "Crimson" | "Ocean" | "Emerald" | "Violet" | "Amber" | "Custom"
	  Scale           number   UI scale (default 1)
	  Animations      boolean  default true
	  ToggleKey       Enum.KeyCode | false   key that hides/shows every window (default RightControl)
	  AllowVisibleGui boolean  fall back to CoreGui / PlayerGui when gethui() is missing (default true)
	  Unique          boolean  destroy a previous DeaUI instance on load (default true)
]]
function Library.Init(options)
	options = options or {}
	if Library.Destroyed then
		error("[DeaUI] the library was destroyed - load it again to create a new UI", 2)
	end
	if Library.Initialized then
		return Library
	end

	local previous = Env.Global[HANDLE]
	if options.Unique ~= false and type(previous) == "table" and previous ~= Library and type(previous.Destroy) == "function" then
		pcall(previous.Destroy, previous)
	end

	if type(options.Folder) == "string" and options.Folder ~= "" then
		Env.Root = options.Folder
	end
	Env.Persist = options.Persist ~= false

	if options.Theme then
		Theme.ApplyPreset(options.Theme)
	end
	if options.Scale then
		Store.Set("UIScale", math.clamp(options.Scale, 0.5, 2))
	end
	if options.Animations ~= nil then
		Store.Set("Animations", options.Animations == true)
	end
	Store.Set("AllowVisibleGuiFallback", options.AllowVisibleGui ~= false)

	if Env.Persist then
		Store.Load()
		Theme.Refresh()
	end
	I18n.Init(options.Language)
	Library.VipActive = options.Vip == true
	Library.OnVipRequest = options.OnVipRequest

	Library.Scope = Scope.new()
	Root.Init(Library.Scope)
	Input.Start(Library.Scope)
	Window.Start(Library.Scope)

	local toggleKey = options.ToggleKey
	if toggleKey == nil then
		toggleKey = Enum.KeyCode.RightControl
	end
	Library.ToggleKey = toggleKey
	local toolsKey = options.ToolsToggleKey
	if toolsKey == nil then
		toolsKey = Enum.KeyCode.RightShift
	end
	Library.ToolsToggleKey = toolsKey
	Library.Scope:Connect(Services.UserInputService.InputBegan, function(input, processed)
		if processed or Library.Capturing or Input.Typing() then
			return
		end
		local key = Library.ToggleKey
		if key and input.KeyCode == key then
			Library.Toggle()
		end
		local tools = Library.ToolsToggleKey
		if tools and input.KeyCode == tools then
			Library.ToggleTools()
		end
	end)
	Library.Scope:Connect(Window.Changed, function()
		Library.SyncToolsButton()
	end)
	Window.OnToolShown = function()
		if Library.ToolsHidden then
			Library.SetToolsHidden(false)
		end
	end

	Library.Initialized = true
	Env.Global[HANDLE] = Library
	if options.MobileButton == true or (options.MobileButton == nil and Input.Touch()) then
		Library.MobileButton()
	end
	if options.ToolsButton == true or (options.ToolsButton == nil and Input.Touch()) then
		Library.MobileButton({
			Id = "Tools",
			Icon = "wrench",
			Visible = false,
			Position = Vector2.new(12, Root.ScreenSize().Y * 0.4 + 52),
			Callback = Library.ToggleTools,
		})
	end
	return Library
end

function Library.AnyToolOpen()
	for _, window in Window.All do
		if not window.IsHub and window.Visible then
			return true
		end
	end
	return false
end

function Library.SyncToolsButton()
	local button = Library.MobileButtons.Tools
	if button then
		button:SetVisible(Library.ToolsHidden or Library.AnyToolOpen())
	end
end

function Library.SetToolsHidden(hidden)
	hidden = hidden == true
	Library.ToolsHidden = hidden
	Window.SetToolsSuppressed(hidden)
	if hidden then
		pcall(Menu.Close)
		pcall(Picker.Close)
	end
	Library.SyncToolsButton()
	Library.ToolsChanged:Fire(hidden)
end

function Library.ToggleTools()
	if Library.LoadingCount > 0 then
		return
	end
	Library.SetToolsHidden(not Library.ToolsHidden)
end

-- Hides (and disables) the loose controls while at least one loader is on screen. It only changes
-- how they are presented; every logical Visible flag stays as the user left it.
function Library.ApplyHold()
	local held = Library.LoadingCount > 0
	for _, button in Library.MobileButtons do
		button:SetHeld(held)
	end
	for _, mark in Library.Watermarks do
		mark:SetHeld(held)
	end
	if Library.KeybindPanel then
		Library.KeybindPanel:SetHeld(held)
	end
end

function Library.Path(...)
	return Env.Path(...)
end

function Library.LoadTool(name, ...)
	local file = string.find(name, "%.lua$") and name or (name .. ".lua")
	local path = Env.Path("Tools", file)
	local source = Env.Read(path)
	if not source then
		error(string.format("[DeaUI] tool file not found: %s (put it in workspace/%s/Tools/)", path, Env.Root), 2)
	end
	local chunk, problem = loadstring(source, "=" .. file)
	if not chunk then
		error("[DeaUI] " .. file .. ": " .. tostring(problem), 2)
	end
	local result = chunk()
	if type(result) == "function" then
		return result(Library, ...)
	end
	return result
end

function Library.Destroy()
	if Library.Destroyed then
		return
	end
	Library.Destroyed = true
	pcall(Store.Flush)
	pcall(Menu.Close)
	pcall(Picker.Close)
	pcall(ColorPicker.Close)
	for _, hook in table.clone(Library.DestroyHooks) do
		pcall(hook)
	end
	table.clear(Library.DestroyHooks)
	for _, mark in table.clone(Library.Watermarks) do
		pcall(mark.Destroy, mark)
	end
	table.clear(Library.Watermarks)
	if Library.KeybindPanel then
		pcall(Library.KeybindPanel.Destroy, Library.KeybindPanel)
	end
	for _, button in table.clone(Library.MobileButtons) do
		pcall(button.Destroy, button)
	end
	table.clear(Library.MobileButtons)
	table.clear(Library.Binds)
	for _, hub in table.clone(Library.Hubs) do
		pcall(hub.Destroy, hub)
	end
	table.clear(Library.Hubs)
	table.clear(Library.Flags)
	for _, window in table.clone(Window.All) do
		pcall(window.Destroy, window)
	end
	Window.SetToolsSuppressed(false)
	Window.OnToolShown = nil
	pcall(Toast.Hold, false)
	table.clear(Library.Held)
	pcall(Menu.Destroy)
	Library.ThemeEditorState = nil
	Library.ToolsHidden = false
	Library.LoadingCount = 0
	if Library.Scope then
		Library.Scope:Clean()
	end
	if Env.Global[HANDLE] == Library then
		Env.Global[HANDLE] = nil
	end
	Library.Initialized = false
end

Library.Unload = function()
	return Library.Destroy()
end

-- Quick leak check: call it after Unload; every number should be 0.
function Library.Audit()
	local buttons = 0
	for _ in Library.MobileButtons do
		buttons += 1
	end
	local locks = 0
	for _ in Library.Locks do
		locks += 1
	end
	return {
		Windows = #Window.All,
		Hubs = #Library.Hubs,
		Watermarks = #Library.Watermarks,
		MobileButtons = buttons,
		LockedRows = locks,
		QueuedToasts = #Toast.Queue,
		LoadingCount = Library.LoadingCount,
		ToolsSuppressed = Window.ToolsSuppressed and 1 or 0,
	}
end

function Library.IsVisible()
	for _, hub in Library.Hubs do
		if hub.Window.Visible then
			return true
		end
	end
	return false
end

function Library.SetVisible(visible)
	ensure()
	if Library.LoadingCount > 0 then
		return
	end
	visible = visible == true
	for _, hub in Library.Hubs do
		if visible then
			hub.Window:Show()
		else
			hub.Window:Hide()
		end
	end
	Library.Visible = #Library.Hubs == 0 and visible or Library.IsVisible()
	if not visible then
		Menu.Close()
		Picker.Close()
		ColorPicker.Close()
	end
end

function Library.Toggle()
	if Library.LoadingCount > 0 then
		return
	end
	Library.SetVisible(not Library.IsVisible())
end

function Library.IsVip()
	return Library.VipActive == true
end

function Library.SetVip(value)
	value = value == true
	if Library.VipActive == value then
		return
	end
	Library.VipActive = value
	for _, apply in Library.Locks do
		pcall(apply)
	end
	Library.VipChanged:Fire(value)
end

function Library.RequestVip(info)
	if type(Library.OnVipRequest) == "function" then
		task.spawn(Library.OnVipRequest, info or {})
		return
	end
	Library.Notify(
		{ en = "VIP feature", vi = "Chức năng VIP" },
		{ en = "This feature is only for VIP members.", vi = "Chức năng này chỉ dành cho thành viên VIP." },
		"warn",
		3
	)
end

function Library.SetToggleKey(keyCode)
	Library.ToggleKey = keyCode or nil
end

------------------------------------------------------------------------
-- Notifications and dialogs
------------------------------------------------------------------------

-- Notify("Title", "Message", "info" | "success" | "warn" | "error" | "accent", seconds)
-- or Notify({ Title =, Message =, Kind =, Duration = })
function Library.Notify(title, message, kind, duration)
	ensure()
	if type(title) == "table" and (title.Title ~= nil or title.Message ~= nil or title.Text ~= nil) then
		local o = title
		return Toast.Show(o.Title or "", o.Message or o.Text, o.Kind or o.Type, o.Duration)
	end
	return Toast.Show(title or "", message, kind, duration)
end

-- Confirm / Prompt yield the calling thread, call them inside task.spawn or a callback.
function Library.Confirm(options)
	ensure()
	return Dialog.Confirm(options)
end

function Library.Prompt(options)
	ensure()
	return Dialog.Prompt(options)
end

function Library.Dialog(options)
	ensure()
	return Dialog.Custom(options)
end

function Library.ContextMenu(items, position, onClose)
	ensure()
	return Menu.Open(items, position, onClose)
end

------------------------------------------------------------------------
-- Theme helpers
------------------------------------------------------------------------

function Library.GetThemes()
	local out = {}
	for _, preset in Theme.Presets do
		table.insert(out, preset.Name)
	end
	table.insert(out, "Custom")
	return out
end

function Library.SetTheme(name)
	return Theme.ApplyPreset(name)
end

function Library.GetTheme()
	return Store.Get("ThemePreset", "Crimson")
end

-- Keeps the current surface colours and swaps only the accent.
function Library.SetAccent(color)
	if typeof(color) ~= "Color3" then
		return false
	end
	local current = Store.Get("ThemePreset", "Crimson")
	if current ~= "Custom" then
		local preset = Theme.GetPreset(current)
		if preset then
			Store.Set("CustomBase", preset.Base)
			Store.Set("CustomText", preset.Text)
		end
		Store.Set("CustomOverrides", {})
	end
	Store.Set("CustomAccent", color)
	return Theme.ApplyPreset("Custom")
end

function Library.SetScale(scale)
	return Store.Set("UIScale", math.clamp(scale, 0.5, 2))
end

function Library.SetAnimations(enabled)
	return Store.Set("Animations", enabled == true)
end

function Library.RegisterIcon(name, assetId)
	Icons.Register(name, assetId)
end

function Library.GetFlags()
	local out = {}
	for name, control in Library.Flags do
		out[name] = control:Get()
	end
	return out
end

------------------------------------------------------------------------
-- Layout helpers (same look as the original Settings window)
------------------------------------------------------------------------

local function nextOrder(page)
	page.Order += 1
	return page.Order
end

local function pageHead(page, title, description)
	local head = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(page),
		List = { Gap = 3 },
		Parent = page.Frame,
	})
	Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		Text = title,
		TextSize = 18,
		FontFace = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = head,
	})
	if description and description ~= "" then
		Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = description,
			TextSize = 12,
			TextColor3 = Theme.T("Faint"),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = head,
		})
	end
	return head
end

local function makeGroup(page, title, opts)
	opts = opts or {}
	local holder = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(page),
		List = { Gap = 7 },
		Parent = page.Frame,
	})
	local header, chevron
	if title then
		local parent = holder
		if opts.Collapsible then
			header = Create.New("TextButton", {
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 1,
				Parent = holder,
			})
			chevron = Create.Icon("chevron-down", 14, Theme.T("Faint"), {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -2, 0.5, 0),
				Rotation = opts.Collapsed and -90 or 0,
				Parent = header,
			})
			parent = header
		end
		local caption = Create.New("TextLabel", {
			Size = opts.Collapsible and UDim2.new(1, -24, 1, 0) or UDim2.new(1, 0, 0, 13),
			TextSize = 10,
			FontFace = Theme.FontBold,
			TextColor3 = Theme.T("Faint"),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Padding = opts.Collapsible and nil or { 0, 0, 0, 2 },
			Parent = parent,
		})
		I18n.Bind(caption, "Text", function()
			return I18n.Upper(I18n.Resolve(title))
		end)
	end
	local clip
	local cardParent = holder
	if opts.Collapsible then
		clip = Create.New("Frame", {
			Name = "Clip",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = opts.Collapsed and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = 2,
			Parent = holder,
		})
		cardParent = clip
	end
	local card = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.T("Panel"),
		LayoutOrder = 2,
		Corner = Theme.Radius,
		Stroke = { Color = "Line" },
		List = { HAlign = "Center" },
		Parent = cardParent,
	})
	local group = setmetatable({ Frame = card, Holder = holder, Count = 0, Page = page, Title = title, Collapsed = opts.Collapsed == true }, Group)
	if clip then
		local token = 0
		function group:SetCollapsed(value, instant)
			value = value == true
			if value == self.Collapsed then
				return
			end
			self.Collapsed = value
			token += 1
			local mine = token
			local height = card.AbsoluteSize.Y
			clip.AutomaticSize = Enum.AutomaticSize.None
			if chevron then
				Motion.Tween(chevron, { Rotation = value and -90 or 0 }, instant and 0 or Motion.Base)
			end
			if value then
				clip.Size = UDim2.new(1, 0, 0, height)
				Motion.Tween(clip, { Size = UDim2.new(1, 0, 0, 0) }, instant and 0 or Motion.Base)
			else
				local tween = Motion.Tween(clip, { Size = UDim2.new(1, 0, 0, math.max(height, 1)) }, instant and 0 or Motion.Base)
				local function settle()
					if token == mine and not self.Collapsed then
						clip.AutomaticSize = Enum.AutomaticSize.Y
						clip.Size = UDim2.new(1, 0, 0, 0)
					end
				end
				if tween then
					tween.Completed:Once(settle)
				else
					settle()
				end
			end
		end
		function group:ToggleCollapsed()
			self:SetCollapsed(not self.Collapsed)
		end
		if header then
			header.Activated:Connect(function()
				group:ToggleCollapsed()
			end)
		end
	end
	return group
end

local function iconWell(parent, icon)
	local well = Create.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Theme.T("Raised"),
		Corner = 7,
		Stroke = { Color = "Line" },
		Parent = parent,
	})
	Create.Icon(icon, 14, Theme.T("Muted"), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = well,
	})
	return well
end

local function textColumn(parent, options, width, left)
	local column = Create.New("Frame", {
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + width + (width > 0 and 26 or 14)), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Padding = { 10, 0, 10, 0 },
		List = { Gap = 2 },
		Parent = parent,
	})
	local title = Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Text = options.Title or "",
		TextSize = 13,
		FontFace = Theme.FontMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Parent = column,
	})
	local description
	if options.Description and options.Description ~= "" then
		description = Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = options.Description,
			TextSize = 12,
			TextColor3 = Theme.T("Faint"),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = column,
		})
	end
	return title, description, column
end

local Lookup = {}
do
	local FOLD = {}
	local GROUPS = {
		a = "àáạảãâầấậẩẫăằắặẳẵÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ",
		e = "èéẹẻẽêềếệểễÈÉẸẺẼÊỀẾỆỂỄ",
		i = "ìíịỉĩÌÍỊỈĨ",
		o = "òóọỏõôồốộổỗơờớợởỡÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ",
		u = "ùúụủũưừứựửữÙÚỤỦŨƯỪỨỰỬỮ",
		y = "ỳýỵỷỹỲÝỴỶỸ",
		d = "đĐ",
	}
	for base, chars in GROUPS do
		for _, code in utf8.codes(chars) do
			FOLD[code] = base
		end
	end

	function Lookup.Fold(value)
		local ok, result = pcall(function()
			local out = {}
			for _, code in utf8.codes(tostring(value)) do
				local base = FOLD[code]
				if base then
					out[#out + 1] = base
				elseif code < 128 then
					out[#out + 1] = string.lower(string.char(code))
				elseif code < 0x300 or code > 0x36F then
					out[#out + 1] = utf8.char(code)
				end
			end
			return table.concat(out)
		end)
		return ok and result or string.lower(tostring(value))
	end

	function Lookup.Texts(source, list)
		list = list or {}
		local kind = type(source)
		if kind == "string" then
			list[#list + 1] = source
			local resolved = I18n.Resolve(source)
			if resolved ~= source then
				list[#list + 1] = resolved
			end
		elseif kind == "table" then
			for _, value in source do
				Lookup.Texts(value, list)
			end
		elseif kind == "function" then
			for _, code in { "en", "vi" } do
				local ok, value = pcall(source, code)
				if ok and type(value) == "string" then
					list[#list + 1] = value
				end
			end
		end
		return list
	end

	function Lookup.Hay(sources)
		local list = {}
		for _, source in sources do
			Lookup.Texts(source, list)
		end
		return Lookup.Fold(table.concat(list, " "))
	end

	function Lookup.Tokens(query)
		local tokens = {}
		for word in string.gmatch(Lookup.Fold(query), "%S+") do
			tokens[#tokens + 1] = word
		end
		return tokens
	end

	function Lookup.Match(hay, tokens)
		if #tokens == 0 then
			return false
		end
		for _, token in tokens do
			if not string.find(hay, token, 1, true) then
				return false
			end
		end
		return true
	end
end

Library.Lookup = Lookup

local function lockRow(entry, top, options)
	local lock = { Vip = options.Vip == true, Hard = options.Locked == true, Reason = options.LockedText }
	entry.Lock = lock
	local overlay
	local function apply()
		local locked = lock.Hard or (lock.Vip and not Library.VipActive)
		if locked and not overlay then
			local vip = lock.Vip and not lock.Hard
			overlay = Create.New("TextButton", {
				Name = "Lock",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.T("Base"),
				BackgroundTransparency = 0.35,
				ZIndex = 20,
				Parent = top,
			})
			local badge = Create.New("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(vip and 58 or 26, 22),
				BackgroundColor3 = Theme.T(vip and "VipSoft" or "Raised"),
				Corner = 11,
				Stroke = { Color = vip and "Vip" or "LineStrong" },
				ZIndex = 21,
				Parent = overlay,
			})
			Create.Icon(vip and "crown" or "lock", 12, Theme.T(vip and "Vip" or "Muted"), {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, vip and 9 or 7, 0.5, 0),
				ZIndex = 22,
				Parent = badge,
			})
			if vip then
				Create.New("TextLabel", {
					Position = UDim2.fromOffset(25, 0),
					Size = UDim2.new(1, -29, 1, 0),
					Text = "VIP",
					TextSize = 11,
					FontFace = Theme.FontBold,
					TextColor3 = Theme.T("Vip"),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 22,
					Parent = badge,
				})
			end
			overlay.Activated:Connect(function()
				if lock.Vip and not lock.Hard then
					Library.RequestVip({ Title = options.Title, Kind = "element" })
				else
					Library.Notify(
						{ en = "Locked", vi = "Đã khóa" },
						lock.Reason or { en = "This option is locked.", vi = "Mục này đang bị khóa." },
						"warn",
						2.5
					)
				end
			end)
			Library.Locks[overlay] = apply
		end
		if overlay then
			overlay.Visible = locked
		end
	end
	function entry.SetLocked(value, reason)
		lock.Hard = value == true
		if reason ~= nil then
			lock.Reason = reason
		end
		apply()
	end
	apply()
end

local function indexRow(card, entry, options)
	local page = card.Page
	local hub = page and page.Hub
	if not hub or not hub.Index or options.Title == nil or options.Title == "" then
		return
	end
	table.insert(hub.Index, {
		Page = page,
		Group = card,
		Row = entry.Frame,
		Title = options.Title,
		Description = options.Description,
		Keywords = options.Keywords,
		Icon = options.Icon,
		Vip = options.Vip == true,
	})
end

local function makeRow(card, options)
	if card.Count > 0 then
		Create.New("Frame", {
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = Theme.T("Line"),
			LayoutOrder = card.Count * 2,
			Parent = card.Frame,
		})
	end
	card.Count += 1
	local width = options.Width or 0
	local left = options.Icon and 50 or 14
	local frame = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = card.Count * 2 + 1,
		List = { Gap = 0 },
		Parent = card.Frame,
	})
	local top = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
	})
	if options.Icon then
		iconWell(top, options.Icon)
	end
	local title, description, column = textColumn(top, options, width, left)
	local control = Create.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(width, 28),
		BackgroundTransparency = 1,
		Parent = top,
	})
	if options.Tooltip then
		Tooltip.Attach(top, options.Tooltip)
	end
	local entry = { Frame = frame, Control = control, Title = title, Description = description, Column = column, Width = width }
	-- changes the width reserved for the control (used by toggles with inline keybind/colour)
	function entry.SetWidth(newWidth)
		entry.Width = newWidth
		control.Size = UDim2.fromOffset(newWidth, 28)
		column.Size = UDim2.new(1, -(left + newWidth + (newWidth > 0 and 26 or 14)), 0, 0)
	end
	entry.Frame = frame
	lockRow(entry, top, options)
	if options.Source then
		options.Source.__row = entry
		indexRow(card, entry, options)
	end
	return entry
end

-- A bare row (no title column) for paragraphs, dividers, images and chips.
local function newRow(card, height)
	if card.Count > 0 then
		Create.New("Frame", {
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = Theme.T("Line"),
			LayoutOrder = card.Count * 2,
			Parent = card.Frame,
		})
	end
	card.Count += 1
	return Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, height or 0),
		AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = card.Count * 2 + 1,
		Parent = card.Frame,
	})
end

local function rowOptions(options, width)
	return {
		Icon = options.Icon,
		Title = options.Title,
		Description = options.Description,
		Width = width,
		Vip = options.Vip,
		Locked = options.Locked,
		LockedText = options.LockedText,
		Keywords = options.Keywords,
		Source = options,
	}
end

local function register(options, control)
	local row = options.__row
	if row then
		control.Row = control.Row or row
		control.SetLocked = function(_, value, reason)
			row.SetLocked(value, reason)
		end
	end
	if options.Flag then
		local existing = Library.Flags[options.Flag]
		if existing and existing ~= control then
			warn(string.format('[DeaUI] Flag "%s" is used by more than one element; a configuration only keeps the last one', options.Flag))
		end
		control.Flag = options.Flag
		Library.Flags[options.Flag] = control
	end
	return control
end

local function normalizeItems(list)
	local items = {}
	for _, item in list do
		if type(item) == "table" and item.Text == nil and item.Value == nil and (item.en or item.vi) then
			-- a bare { en = "...", vi = "..." } entry: the English text is the value
			table.insert(items, { Source = item, Text = I18n.Resolve(item), Value = item.en or item.vi })
		elseif type(item) == "table" then
			local value = item.Value
			if value == nil then
				value = item.Text
			end
			local source = item.Text ~= nil and item.Text or value
			table.insert(items, { Source = source, Text = I18n.Resolve(source), Value = value, Icon = item.Icon, Color = item.Color })
		else
			table.insert(items, { Source = item, Text = I18n.Resolve(item), Value = item })
		end
	end
	return items
end

local function localizeItems(items)
	for _, item in items do
		item.Text = I18n.Resolve(item.Source)
	end
end

------------------------------------------------------------------------
-- Group controls
------------------------------------------------------------------------

-- Group:Toggle({ Title, Description, Icon, Default, Callback(value), Flag })
-- returns control with :Get() :Set(value, silent) .Changed
function Group:Toggle(options)
	local entry = makeRow(self, rowOptions(options, 30))
	local control = Switch.new({
		Value = options.Default == true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Parent = entry.Control,
		Locked = options.Locked,
	})
	control.Row = entry
	connect(control.Changed, options.Callback)
	return register(options, control)
end

-- Group:Slider({ Title, Description, Icon, Min, Max, Step, Default, Suffix, Format, Width,
--                Callback(value) -- fires while dragging, OnRelease(value) -- fires on release, Flag })
function Group:Slider(options)
	local width = options.Width or 160
	local entry = makeRow(self, rowOptions(options, width))
	local control = Slider.new({
		Min = options.Min,
		Max = options.Max,
		Step = options.Step,
		Value = options.Default,
		Suffix = options.Suffix,
		Format = options.Format,
		LabelWidth = options.LabelWidth,
		Width = width,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Parent = entry.Control,
	})
	control.Row = entry
	connect(control.Changed, options.Callback)
	connect(control.Released, options.OnRelease)
	return register(options, control)
end

-- Group:Dropdown({ Title, Description, Icon, Options = { "A", "B", { Text, Value, Icon } },
--                  Default, Placeholder, Width, Search, Callback(value), Flag })
function Group:Dropdown(options)
	local width = options.Width or 150
	local entry = makeRow(self, rowOptions(options, width))
	local items = normalizeItems(options.Options or options.Items or {})
	local value = options.Default
	local control = { Changed = Signal.new(), Row = entry }

	local box = Create.New("TextButton", {
		Name = "Dropdown",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.T("Field"),
		BackgroundTransparency = 0,
		Corner = Theme.RadiusSmall + 1,
		Stroke = { Color = "Line" },
		Parent = entry.Control,
	})
	local label = Create.New("TextLabel", {
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Text = "",
		TextSize = 13,
		FontFace = Theme.FontMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = box,
	})
	Create.Icon("chevron-down", 14, Theme.T("Faint"), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Parent = box,
	})
	Motion.Hover(box, box, "BackgroundColor3", "Field", "Hover", "Pressed")

	local function render()
		local text
		for _, item in items do
			if item.Value == value then
				text = item.Text
				break
			end
		end
		if text then
			label.Text = text
			Motion.Token(label, "TextColor3", "Text")
		else
			label.Text = I18n.Resolve(options.Placeholder or "Select...")
			Motion.Token(label, "TextColor3", "Faint")
		end
	end
	self.Page.Hub.Scope:Connect(I18n.Changed, function()
		localizeItems(items)
		render()
	end)

	function control:Get()
		return value
	end
	function control:Set(newValue, silent, force)
		if newValue == value then
			if force and not silent then
				control.Changed:Fire(value)
			end
			return
		end
		value = newValue
		render()
		if not silent then
			control.Changed:Fire(value)
		end
	end
	function control:SetOptions(list, keepValue)
		items = normalizeItems(list)
		if not keepValue then
			value = nil
		end
		render()
	end

	box.Activated:Connect(function()
		local search = options.Search
		if search == nil then
			search = #items > 6
		end
		localizeItems(items)
		Picker.Open({
			Items = items,
			Selected = value,
			Anchor = box,
			Width = width,
			Search = search,
			MaxRows = options.MaxRows,
			Callback = function(picked)
				control:Set(picked)
			end,
		})
	end)

	render()
	connect(control.Changed, options.Callback)
	return register(options, control)
end

-- Group:Button({ Title, Description, Icon, ButtonText, ButtonIcon, Variant = "Primary" | "Secondary" | "Ghost" | "Danger",
--                Width, Tooltip, Callback() })
function Group:Button(options)
	local width = options.Width or 96
	local entry = makeRow(self, rowOptions(options, width))
	local button = Button.new({
		Text = options.ButtonText or "Run",
		Icon = options.ButtonIcon,
		Variant = options.Variant or "Secondary",
		Size = UDim2.fromScale(1, 1),
		Tooltip = options.Tooltip,
		Callback = safe(options.Callback),
		Parent = entry.Control,
	})
	button.Row = entry
	button.SetLocked = function(_, value, reason)
		entry.SetLocked(value, reason)
	end
	return button
end

-- Group:Input({ Title, Description, Icon, Default, Placeholder, Mono, Width, FieldIcon,
--               Callback(text, enterPressed) -- on focus lost, OnChange(text) -- every keystroke })
function Group:Input(options)
	local width = options.Width or 170
	local entry = makeRow(self, rowOptions(options, width))
	local field = Field.new({
		Text = options.Default or "",
		Placeholder = options.Placeholder,
		Mono = options.Mono,
		Icon = options.FieldIcon,
		Clearable = options.Clearable,
		Size = UDim2.fromScale(1, 1),
		Parent = entry.Control,
	})
	field.Row = entry
	connect(field.Submitted, options.Callback)
	connect(field.Changed, options.OnChange)
	return register(options, field)
end

-- Group:Color({ Title, Description, Icon, Default = Color3, Width, Callback(color) -- live while picking })
function Group:Color(options)
	local width = options.Width or 100
	local entry = makeRow(self, rowOptions(options, width))
	local color = typeof(options.Default) == "Color3" and options.Default or Color3.new(1, 1, 1)
	local control = { Changed = Signal.new(), Row = entry }

	local button = Create.New("TextButton", {
		Name = "ColorButton",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.T("Field"),
		BackgroundTransparency = 0,
		Corner = Theme.RadiusSmall + 1,
		Stroke = { Color = "Line" },
		Parent = entry.Control,
	})
	local swatch = Create.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 7, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = color,
		Corner = 4,
		Stroke = { Color = "LineStrong" },
		Parent = button,
	})
	local hex = Create.New("TextLabel", {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -36, 1, 0),
		Text = Util.Hex(color),
		TextSize = 12,
		FontFace = Theme.Mono,
		TextColor3 = Theme.T("Muted"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	})
	Motion.Hover(button, button, "BackgroundColor3", "Field", "Hover", "Pressed")

	function control:Get()
		return color
	end
	function control:Set(newColor, silent, force)
		if typeof(newColor) ~= "Color3" then
			return
		end
		if newColor == color then
			if force and not silent then
				control.Changed:Fire(color)
			end
			return
		end
		color = newColor
		swatch.BackgroundColor3 = color
		hex.Text = Util.Hex(color)
		if not silent then
			control.Changed:Fire(color)
		end
	end

	button.Activated:Connect(function()
		ColorPicker.Open({
			Color = color,
			Title = options.PickerTitle or options.Title,
			Anchor = button,
			Callback = function(picked)
				control:Set(picked)
			end,
		})
	end)

	connect(control.Changed, options.Callback)
	return register(options, control)
end

-- Group:Keybind({ Title, Description, Icon, Default = Enum.KeyCode, Width,
--                 Callback(keyCode) -- when the bind changes, OnPress() -- when the key is pressed })
-- Escape cancels while listening, Backspace clears the bind.
function Group:Keybind(options)
	local width = options.Width or 110
	local entry = makeRow(self, rowOptions(options, width))
	local key = options.Default
	local listening = false
	local listener
	local control = { Changed = Signal.new(), Pressed = Signal.new(), Row = entry }
	local button = Button.new({
		Text = key and key.Name or "None",
		Variant = "Secondary",
		Size = UDim2.fromScale(1, 1),
		Parent = entry.Control,
	})

	local function render()
		if listening then
			button:SetText(I18n.Resolve("Press a key..."))
		else
			button:SetText(key and key.Name or I18n.Resolve("None"))
		end
	end
	self.Page.Hub.Scope:Connect(I18n.Changed, render)
	local function stop()
		listening = false
		if listener then
			listener:Disconnect()
			listener = nil
		end
		render()
		task.delay(0.2, function()
			if not listening then
				Library.Capturing = false
			end
		end)
	end

	function control:Get()
		return key
	end
	function control:Set(newKey, silent, force)
		if newKey == key then
			if force and not silent then
				control.Changed:Fire(key)
			end
			return
		end
		key = newKey
		render()
		if not silent then
			control.Changed:Fire(key)
		end
	end

	button.Instance.Activated:Connect(function()
		if listening then
			stop()
			return
		end
		listening = true
		Library.Capturing = true
		render()
		listener = Services.UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			local picked = input.KeyCode
			stop()
			if picked == Enum.KeyCode.Escape then
				return
			elseif picked == Enum.KeyCode.Backspace then
				control:Set(nil)
			else
				control:Set(picked)
			end
		end)
	end)

	self.Page.Hub.Scope:Connect(Services.UserInputService.InputBegan, function(input, processed)
		if processed or listening or Library.Capturing or Input.Typing() then
			return
		end
		if key and input.KeyCode == key then
			control.Pressed:Fire()
		end
	end)
	self.Page.Hub.Scope:Add(function()
		if listener then
			listener:Disconnect()
		end
	end)

	connect(control.Changed, options.Callback)
	connect(control.Pressed, options.OnPress)
	return register(options, control)
end

-- Group:Label({ Title, Description, Icon, Value, Width }) -> :SetTitle() :SetDescription() :SetValue()
function Group:Label(options)
	local hasValue = options.Value ~= nil
	local width = hasValue and (options.Width or 120) or 0
	local entry = makeRow(self, rowOptions(options, width))
	local valueLabel
	if hasValue then
		valueLabel = Create.New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = tostring(options.Value),
			TextSize = 12,
			FontFace = Theme.Mono,
			TextColor3 = Theme.T("Muted"),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = entry.Control,
		})
	end
	local control = { Row = entry }
	function control:SetTitle(text)
		I18n.Bind(entry.Title, "Text", text)
	end
	function control:SetDescription(text)
		if entry.Description then
			I18n.Bind(entry.Description, "Text", text)
		end
	end
	function control:SetValue(text)
		if valueLabel then
			valueLabel.Text = tostring(text)
		end
	end
	return control
end

-- Group:Block({ Title, Description, Icon }) -> content Frame (AutomaticSize Y) for custom widgets, row
function Group:Block(options)
	local entry = makeRow(self, { Icon = options.Icon, Title = options.Title or "", Description = options.Description, Width = 0 })
	local left = options.Icon and 50 or 14
	local content = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Padding = { 0, 14, 14, left },
		Parent = entry.Frame,
	})
	entry.Content = content
	return content, entry
end

-- Group:Code({ Title, Description, Icon, Text, Editable, Height, TextSize, Gutter }) -> CodeView
function Group:Code(options)
	local content = self:Block(options)
	local holder = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, options.Height or 220),
		BackgroundColor3 = Theme.T("Base"),
		Corner = Theme.RadiusSmall + 1,
		Stroke = { Color = "Line" },
		Parent = content,
	})
	local view = CodeView.new({
		Parent = holder,
		Size = UDim2.fromScale(1, 1),
		Text = options.Text or "",
		Editable = options.Editable,
		TextSize = options.TextSize,
		Gutter = options.Gutter,
	})
	self.Page.Hub.Scope:Add(view)
	return view
end

------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------

function Page:Header(title, description)
	return pageHead(self, title, description)
end

-- page:Group("Title", { Collapsible = true, Collapsed = false })
function Page:Group(title, opts)
	return makeGroup(self, title, opts)
end

function Page:Select()
	self.Hub:SelectIndex(self.Index)
end

------------------------------------------------------------------------
-- Hub (window with a sidebar of pages)
------------------------------------------------------------------------

local function navItem(nav, spec, index, y, onSelect)
	local button = Create.New("TextButton", {
		Name = tostring(spec.Id or index),
		Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, NAV_ROW),
		BackgroundColor3 = Theme.T("Hover"),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Corner = 6,
		Parent = nav,
	})
	local vip = spec.Vip == true
	local icon = Create.Icon(spec.Icon, 15, Theme.T(vip and "Vip" or "Faint"), {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 11, 0.5, 0),
		ZIndex = 3,
		Parent = button,
	})
	local label = Create.New("TextLabel", {
		Position = UDim2.fromOffset(35, 0),
		Size = UDim2.new(1, vip and -68 or -40, 1, 0),
		Text = spec.Text or spec.Title or "Page",
		TextSize = 13,
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.T(vip and "Vip" or "Muted"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = button,
	})
	if vip then
		local pill = Create.New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(26, 16),
			BackgroundColor3 = Theme.T("VipSoft"),
			Corner = 8,
			Stroke = { Color = "Vip" },
			ZIndex = 3,
			Parent = button,
		})
		Create.Icon("crown", 10, Theme.T("Vip"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 4,
			Parent = pill,
		})
	end
	local item = { Button = button, Icon = icon, Label = label, Hovering = false, Selected = false, Y = y }
	function item.Render()
		Motion.Tween(button, { BackgroundTransparency = (item.Hovering and not item.Selected) and 0 or 1 }, Motion.Fast)
		if vip then
			Motion.Token(icon, "ImageColor3", "Vip")
			Motion.Token(label, "TextColor3", "Vip")
			return
		end
		Motion.Token(icon, "ImageColor3", item.Selected and "Accent" or (item.Hovering and "Text" or "Faint"))
		Motion.Token(label, "TextColor3", (item.Selected or item.Hovering) and "Text" or "Muted")
	end
	button.MouseEnter:Connect(function()
		item.Hovering = true
		item.Render()
	end)
	button.MouseLeave:Connect(function()
		item.Hovering = false
		item.Render()
	end)
	button.Activated:Connect(function()
		onSelect(index)
	end)
	return item
end

-- The sidebar scrolls, so it keeps working on small phone screens with many pages.
local function buildNav(body, navWidth, footer)
	local holder = Create.New("Frame", {
		Name = "Nav",
		Size = UDim2.new(0, navWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})
	Create.New("Frame", {
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.T("Line"),
		ZIndex = 4,
		Parent = holder,
	})
	local hasFooter = footer and footer ~= ""
	local nav = Create.New("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, -1, 1, hasFooter and -34 or 0),
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 2,
		Parent = holder,
	})
	local highlight = Create.New("Frame", {
		Position = UDim2.fromOffset(8, NAV_TOP),
		Size = UDim2.new(1, -16, 0, NAV_ROW),
		BackgroundColor3 = Theme.T("AccentSoft"),
		Visible = false,
		ZIndex = 1,
		Corner = 6,
		Parent = nav,
	})
	Create.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(2, 16),
		BackgroundColor3 = Theme.T("Accent"),
		Corner = 1,
		Parent = highlight,
	})
	if hasFooter then
		Create.New("TextLabel", {
			Position = UDim2.new(0, 16, 1, -30),
			Size = UDim2.new(1, -32, 0, 18),
			Text = footer,
			TextSize = 11,
			FontFace = Theme.Mono,
			TextColor3 = Theme.T("Faint"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})
	end
	return nav, highlight, holder
end

local function buildPageLock(hub, body, navWidth)
	local overlay = Create.New("TextButton", {
		Name = "PageLock",
		Position = UDim2.fromOffset(navWidth, 0),
		Size = UDim2.new(1, -navWidth, 1, 0),
		BackgroundColor3 = Theme.T("Base"),
		BackgroundTransparency = 0.18,
		Visible = false,
		ZIndex = 30,
		Parent = body,
	})
	local card = Create.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.T("Raised"),
		Corner = Theme.Radius + 2,
		Stroke = { Color = "Vip" },
		Padding = 18,
		List = { Gap = 8, HAlign = "Center" },
		ZIndex = 31,
		Parent = overlay,
	})
	local ring = Create.New("Frame", {
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = Theme.T("VipSoft"),
		Corner = UDim.new(1, 0),
		Stroke = { Color = "Vip", Thickness = 1.5 },
		LayoutOrder = 1,
		ZIndex = 32,
		Parent = card,
	})
	Create.Icon("crown", 26, Theme.T("Vip"), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 33,
		Parent = ring,
	})
	Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Text = { en = "VIP tab", vi = "Tab dành cho VIP" },
		TextSize = 15,
		FontFace = Theme.FontBold,
		TextColor3 = Theme.T("Vip"),
		LayoutOrder = 2,
		ZIndex = 32,
		Parent = card,
	})
	Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = {
			en = "Unlock VIP to use every feature in this tab.",
			vi = "Mở khóa VIP để dùng toàn bộ chức năng trong tab này.",
		},
		TextSize = 12,
		TextColor3 = Theme.T("Muted"),
		TextWrapped = true,
		LayoutOrder = 3,
		ZIndex = 32,
		Parent = card,
	})
	local button = Create.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.T("Vip"),
		BackgroundTransparency = 0,
		Text = { en = "Unlock VIP", vi = "Mở khóa VIP" },
		TextSize = 13,
		FontFace = Theme.FontBold,
		TextColor3 = Color3.fromRGB(26, 15, 0),
		Corner = 7,
		LayoutOrder = 4,
		ZIndex = 32,
		Parent = card,
	})
	button.Activated:Connect(function()
		local page = hub.Pages[hub.Current]
		Library.RequestVip({ Title = page and page.Text, Kind = "page" })
	end)
	return overlay
end

--[[
	DeaUI.CreateWindow(options)
	  Id, Title, Subtitle, Icon, Size = Vector2, MinSize = Vector2, Position = Vector2,
	  Footer (text at the bottom of the sidebar), NavWidth, Visible (default true),
	  Closable, Minimizable, Resizable, Remember, Dock, OnClose
]]
function Library.CreateWindow(options)
	options = options or {}
	ensure()
	local window = Window.new({
		Hub = true,
		Id = options.Id or ("hub" .. (#Library.Hubs + 1)),
		Title = options.Title or "Window",
		Subtitle = options.Subtitle,
		Icon = options.Icon,
		Size = options.Size or Vector2.new(640, 460),
		MinSize = options.MinSize or Vector2.new(480, 320),
		Position = options.Position,
		Dock = options.Dock,
		Remember = options.Remember,
		Closable = options.Closable,
		Minimizable = options.Minimizable,
		Resizable = options.Resizable,
		OnClose = options.OnClose,
	})
	local navWidth = options.NavWidth or NAV_W
	local nav, highlight, navHolder = buildNav(window.Body, navWidth, options.Footer)
	local pane = Create.New("ScrollingFrame", {
		Name = "Pane",
		Position = UDim2.fromOffset(navWidth, 0),
		Size = UDim2.new(1, -navWidth, 1, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		Parent = window.Body,
	})
	local hub = setmetatable({
		Window = window,
		Scope = window.Scope,
		Nav = nav,
		NavHolder = navHolder,
		NavY = NAV_TOP,
		Highlight = highlight,
		Pane = pane,
		Pages = {},
		Items = {},
		Index = {},
		Current = nil,
	}, Hub)
	table.insert(Library.Hubs, hub)
	window.VisibilityChanged:Connect(function()
		Library.Visible = Library.IsVisible()
	end)
	window.Closed:Connect(function()
		if not Library.ToggleKey and not Library.MobileToggle then
			Library.MobileButton()
		end
	end)
	hub.PageLock = buildPageLock(hub, window.Body, navWidth)
	hub.Scope:Add(Library.VipChanged:Connect(function()
		hub:_syncPageLock()
		if hub.Searching then
			hub:_renderResults(hub.SearchField:Get())
		end
	end))
	if options.Search ~= false then
		hub:_buildSearch()
	end
	if options.Visible ~= false then
		if Library.LoadingCount > 0 then
			Library.Held[window] = true
		else
			window:Show()
		end
	end
	return hub
end

--[[
	hub:AddPage({ Id, Text, Icon, Title, Description })
	  Text = sidebar label, Title / Description = optional header shown at the top of the page.
]]
function Hub:AddPage(spec)
	spec = spec or {}
	local index = #self.Pages + 1
	local frame = Create.New("Frame", {
		Name = tostring(spec.Id or index),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Padding = { 16, 16, 22, 16 },
		List = { Gap = 16 },
	})
	self.Scope:Add(frame)
	local page = setmetatable({
		Hub = self,
		Frame = frame,
		Order = 0,
		Index = index,
		Id = spec.Id or tostring(index),
		Vip = spec.Vip == true,
		Text = spec.Text or spec.Title,
	}, Page)
	self.Pages[index] = page
	local y = self.NavY
	self.NavY = y + NAV_ROW + NAV_GAP
	self.Nav.CanvasSize = UDim2.fromOffset(0, self.NavY + 8)
	self.Items[index] = navItem(self.Nav, spec, index, y, function(picked)
		self:SelectIndex(picked)
	end)
	if spec.Title then
		page:Header(spec.Title, spec.Description)
	end
	if index == 1 then
		self.Highlight.Visible = true
		self:SelectIndex(1, true)
	end
	return page
end

-- Small caption between sidebar entries: hub:AddCategory("Visuals")
function Hub:AddCategory(text)
	local y = self.NavY + (self.NavY > NAV_TOP and 6 or 0)
	local caption = Create.New("TextLabel", {
		Position = UDim2.fromOffset(18, y),
		Size = UDim2.new(1, -30, 0, 16),
		TextSize = 10,
		FontFace = Theme.FontBold,
		TextColor3 = Theme.T("Faint"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self.Nav,
	})
	I18n.Bind(caption, "Text", function()
		return I18n.Upper(I18n.Resolve(text))
	end)
	self.NavY = y + 20
	self.Nav.CanvasSize = UDim2.fromOffset(0, self.NavY + 8)
	return caption
end

function Hub:SelectIndex(index, instant)
	local page = self.Pages[index]
	if self.Searching then
		self:_clearSearch(true)
	end
	if not page or self.Current == index then
		return
	end
	if self.Current and self.Pages[self.Current] then
		self.Pages[self.Current].Frame.Parent = nil
		self.Items[self.Current].Selected = false
		self.Items[self.Current].Render()
	end
	self.Current = index
	local frame = page.Frame
	self.Pane.CanvasPosition = Vector2.zero
	frame.Position = UDim2.fromOffset(0, instant and 0 or 8)
	frame.Parent = self.Pane
	Motion.Tween(frame, { Position = UDim2.fromOffset(0, 0) }, Motion.Base)
	local y = self.Items[index].Y
	Motion.Tween(self.Highlight, { Position = UDim2.fromOffset(8, y) }, instant and 0 or Motion.Base)
	self.Items[index].Selected = true
	self.Items[index].Render()
	local bar = self.Highlight:FindFirstChildOfClass("Frame")
	Motion.Token(self.Highlight, "BackgroundColor3", page.Vip and "VipSoft" or "AccentSoft")
	if bar then
		Motion.Token(bar, "BackgroundColor3", page.Vip and "Vip" or "Accent")
	end
	self:_syncPageLock()
end

function Hub:Select(id)
	for index, page in self.Pages do
		if page.Id == id then
			self:SelectIndex(index)
			return
		end
	end
end

function Hub:_syncPageLock()
	local page = self.Pages[self.Current]
	local locked = page ~= nil and page.Vip and not Library.VipActive and not self.Searching
	if self.PageLock then
		self.PageLock.Visible = locked
	end
end

function Hub:_buildSearch()
	local field = Field.new({
		Name = "Search",
		Icon = "search",
		Placeholder = { en = "Search features", vi = "Tìm chức năng" },
		Height = 26,
		TextSize = 12,
		Clearable = true,
		Size = UDim2.fromOffset(176, 26),
		LayoutOrder = 0,
		Parent = self.Window.Actions,
	})
	self.SearchField = field
	self.Searching = false
	local holder = self.Window.TitleLabel and self.Window.TitleLabel.Parent
	if holder then
		holder.Size = UDim2.new(1, -262, 1, 0)
	end
	self.SearchFrame = Create.New("Frame", {
		Name = "Search",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Padding = { 16, 16, 22, 16 },
		List = { Gap = 6 },
	})
	self.Scope:Add(self.SearchFrame)
	self.Scope:Add(field.Changed:Connect(function(value)
		self:_search(value)
	end))
	self.Scope:Add(field.Submitted:Connect(function(_, enter)
		if enter and self._firstResult then
			self:_open(self._firstResult)
		end
	end))
	self.Scope:Connect(I18n.Changed, function()
		if self.Searching then
			self:_renderResults(field:Get())
		end
	end)
end

function Hub:_search(value)
	value = string.match(value or "", "^%s*(.-)%s*$")
	if value == "" then
		if self.Searching then
			self:_clearSearch(false)
		end
		return
	end
	if not self.Searching then
		self.Searching = true
		local page = self.Pages[self.Current]
		if page then
			page.Frame.Parent = nil
		end
		self.SearchFrame.Parent = self.Pane
		self.Pane.CanvasPosition = Vector2.zero
		self:_syncPageLock()
	end
	self:_renderResults(value)
end

function Hub:_clearSearch(clearField)
	if not self.Searching then
		return
	end
	self.Searching = false
	self.SearchFrame.Parent = nil
	local page = self.Pages[self.Current]
	if page then
		page.Frame.Parent = self.Pane
	end
	if clearField and self.SearchField then
		self.SearchField:Set("")
	end
	self:_syncPageLock()
end

function Hub:_renderResults(query)
	local frame = self.SearchFrame
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local tokens = Lookup.Tokens(query)
	local results = {}
	for _, page in self.Pages do
		page.Hay = page.Hay or Lookup.Hay({ page.Text })
		if Lookup.Match(page.Hay, tokens) then
			table.insert(results, { Page = page })
		end
	end
	for _, item in self.Index do
		item.Hay = item.Hay or Lookup.Hay({ item.Title, item.Description, item.Keywords, item.Page.Text, item.Group.Title })
		if Lookup.Match(item.Hay, tokens) then
			table.insert(results, { Item = item, Page = item.Page })
		end
		if #results >= 60 then
			break
		end
	end
	self._firstResult = results[1]
	Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Text = function()
			return string.format(I18n.Get() == "vi" and "%d kết quả cho “%s”" or "%d results for “%s”", #results, query)
		end,
		TextSize = 11,
		FontFace = Theme.FontBold,
		TextColor3 = Theme.T("Faint"),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = frame,
	})
	if #results == 0 then
		Create.Icon("search-x", 30, Theme.T("Faint"), { LayoutOrder = 1, Parent = frame })
		Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			Text = { en = "No matches found", vi = "Không tìm thấy kết quả" },
			TextSize = 12,
			TextColor3 = Theme.T("Faint"),
			LayoutOrder = 2,
			Parent = frame,
		})
		return
	end
	for index, result in results do
		local item = result.Item
		local page = result.Page
		local vip = (item and item.Vip or page.Vip) and not Library.VipActive
		local button = Create.New("TextButton", {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Theme.T("Panel"),
			BackgroundTransparency = 0,
			Corner = Theme.Radius,
			Stroke = { Color = "Line" },
			LayoutOrder = index,
			Parent = frame,
		})
		local well = Create.New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Theme.T("Raised"),
			Corner = 7,
			Parent = button,
		})
		Create.Icon((item and item.Icon) or "layout-dashboard", 14, Theme.T(page.Vip and "Vip" or "Muted"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = well,
		})
		local title = item and I18n.Resolve(item.Title) or I18n.Resolve(page.Text)
		local path = item and (I18n.Resolve(page.Text) .. (item.Group.Title and ("  ›  " .. I18n.Resolve(item.Group.Title)) or ""))
			or I18n.Resolve({ en = "Page", vi = "Trang" })
		Create.New("TextLabel", {
			Position = UDim2.fromOffset(46, 6),
			Size = UDim2.new(1, -100, 0, 18),
			Text = title,
			TextSize = 13,
			FontFace = Theme.FontMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})
		Create.New("TextLabel", {
			Position = UDim2.fromOffset(46, 24),
			Size = UDim2.new(1, -100, 0, 16),
			Text = path,
			TextSize = 11,
			TextColor3 = Theme.T("Faint"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})
		Create.Icon(vip and "crown" or "chevron-right", vip and 14 or 13, Theme.T(vip and "Vip" or "Faint"), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Parent = button,
		})
		button.MouseEnter:Connect(function()
			Motion.Token(button, "BackgroundColor3", "Hover")
		end)
		button.MouseLeave:Connect(function()
			Motion.Token(button, "BackgroundColor3", "Panel")
		end)
		button.Activated:Connect(function()
			self:_open(result)
		end)
	end
end

function Hub:_open(result)
	self:_clearSearch(true)
	local page = result.Page
	self:SelectIndex(page.Index)
	if result.Item then
		self:_reveal(result.Item)
	end
end

function Hub:_reveal(item)
	local group = item.Group
	if group and group.Collapsed and group.SetCollapsed then
		group:SetCollapsed(false, true)
	end
	task.spawn(function()
		task.wait(0.15)
		local row = item.Row
		if not row or not row.Parent then
			return
		end
		local pane = self.Pane
		local scale = self.Window._scale and self.Window._scale.Scale or 1
		local y = (row.AbsolutePosition.Y - pane.AbsolutePosition.Y) / scale + pane.CanvasPosition.Y - 24
		pane.CanvasPosition = Vector2.new(0, math.max(0, y))
		local stroke = Create.New("UIStroke", {
			Color = Theme.T(item.Vip and "Vip" or "Accent"),
			Thickness = 1.6,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = row,
		})
		Motion.Tween(stroke, { Transparency = 1 }, 1.6)
		task.delay(1.7, function()
			stroke:Destroy()
		end)
	end)
end

-- Adds an icon button to the window header: hub:AddAction({ Icon, Tooltip, Callback })
function Hub:AddAction(options)
	return self.Window:AddAction(options)
end

function Hub:SetTitle(text)
	self.Window:SetTitle(text)
end

function Hub:SetSubtitle(text)
	self.Window:SetSubtitle(text)
end

function Hub:Show()
	self.Window:Show()
end

function Hub:Hide()
	self.Window:Hide()
end

function Hub:Toggle()
	self.Window:Toggle()
end

function Hub:Destroy()
	local index = table.find(Library.Hubs, self)
	if index then
		table.remove(Library.Hubs, index)
	end
	self.Window:Destroy()
end

------------------------------------------------------------------------
-- Language, watermark, keybind list, loader, mobile button
------------------------------------------------------------------------

Library.Binds = {}
Library.Watermarks = {}
Library.DestroyHooks = {}

-- Run `callback` when the library is destroyed (add-ons use it to clean up after themselves).
function Library.OnDestroy(callback)
	table.insert(Library.DestroyHooks, callback)
end
Library.I18n = I18n
Library.Modules.I18n = I18n
Library.Modules.Drag = Drag
Library.Modules.Watermark = Watermark

function Library.SetLanguage(code)
	return I18n.Set(code)
end

function Library.GetLanguage()
	return I18n.Get()
end

function Library.GetLanguages()
	return I18n.Items()
end

-- Library.Define("key", { en = "Hello", vi = "Xin chào" }) then pass "key" as any text
function Library.Define(key, entry)
	I18n.Define(key, entry)
end

-- Library.AddPhrases("vi", { ["Hello"] = "Xin chào" }): plain English texts get translated
function Library.AddPhrases(code, map)
	I18n.Phrases(code, map)
end

Library.T = I18n.Resolve

-- DeaUI.Watermark({ Title, Icon, Corner = "TopRight" | "TopLeft" | "BottomRight" | "BottomLeft",
--                   Position = Vector2, Draggable }) -> :AddText :AddFPS :AddPing :AddTime :AddUser :SetVisible
function Library.Watermark(options)
	ensure()
	local mark = Watermark.new(options)
	table.insert(Library.Watermarks, mark)
	if Library.LoadingCount > 0 then
		mark:SetHeld(true)
	end
	return mark
end

function Library.SetWatermarkVisible(visible)
	for _, mark in Library.Watermarks do
		mark:SetVisible(visible)
	end
end

-- Draggable list of the keybinds registered through Group:Keybind / Toggle { Keybind = ... }.
function Library.KeybindList(options)
	ensure()
	options = options or {}
	if Library.KeybindPanel then
		return Library.KeybindPanel
	end
	local scope = Scope.new()
	local panel = { Visible = options.Visible ~= false, Held = Library.LoadingCount > 0, Scope = scope }
	local frame = Create.New("CanvasGroup", {
		Name = "KeybindList",
		Size = UDim2.fromOffset(176, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(12, 150),
		BackgroundColor3 = Theme.T("Panel"),
		BackgroundTransparency = 0.04,
		GroupTransparency = 1,
		Active = true,
		ZIndex = 815,
		Corner = Theme.Radius,
		Stroke = { Color = "LineStrong" },
		List = { Gap = 0 },
		Parent = Root.Bar,
	})
	scope:Add(frame)
	local head = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
	})
	Create.Icon("keyboard", 13, Theme.T("Accent"), {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Parent = head,
	})
	Create.New("TextLabel", {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -36, 1, 0),
		Text = "Keybinds",
		TextSize = 12,
		FontFace = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = head,
	})
	local list = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Padding = { 0, 10, 8, 10 },
		List = { Gap = 3 },
		Parent = frame,
	})
	scope:Add(Drag.Bind(frame, frame, { Rest = function(position, size)
		return Drag.Fit(position, size, 6)
	end }))

	local rows = {}
	local function refresh()
		local shown = 0
		for _, bind in Library.Binds do
			local row = rows[bind]
			if not row then
				local holder = Create.New("Frame", {
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					LayoutOrder = #list:GetChildren(),
					Parent = list,
				})
				local name = Create.New("TextLabel", {
					Size = UDim2.new(1, -52, 1, 0),
					TextSize = 12,
					TextColor3 = Theme.T("Muted"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = holder,
				})
				local key = Create.New("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, 50, 1, 0),
					TextSize = 11,
					FontFace = Theme.Mono,
					TextColor3 = Theme.T("Faint"),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = holder,
				})
				row = { Frame = holder, Name = name, Key = key, State = false }
				rows[bind] = row
			end
			local key = bind.Key()
			row.Frame.Visible = key ~= nil
			if key then
				shown += 1
				row.Name.Text = I18n.Resolve(bind.Name)
				row.Key.Text = "[" .. key.Name .. "]"
				local active = bind.Active and bind.Active() == true
				if active ~= row.State then
					row.State = active
					Motion.Token(row.Name, "TextColor3", active and "Accent" or "Muted")
					Motion.Token(row.Key, "TextColor3", active and "Text" or "Faint")
				end
			end
		end
		for bind, row in rows do
			if not table.find(Library.Binds, bind) then
				row.Frame:Destroy()
				rows[bind] = nil
			end
		end
		panel.Count = shown
		frame.Visible = panel.Visible and not panel.Held and shown > 0
	end
	local timer = 0
	scope:Connect(Services.RunService.Heartbeat, function(dt)
		timer += dt
		if timer >= 0.15 then
			timer = 0
			refresh()
		end
	end)

	function panel:SetVisible(visible)
		visible = visible == true
		if panel.Visible == visible then
			return
		end
		panel.Visible = visible
		if visible then
			refresh()
			Motion.Tween(frame, { GroupTransparency = 0 }, Motion.Base)
		else
			local tween = Motion.Tween(frame, { GroupTransparency = 1 }, Motion.Fast)
			if tween then
				tween.Completed:Once(function()
					if not panel.Visible then
						frame.Visible = false
					end
				end)
			else
				frame.Visible = false
			end
		end
	end
	function panel:SetHeld(held)
		panel.Held = held == true
		refresh()
	end
	function panel:Destroy()
		Library.KeybindPanel = nil
		scope:Clean()
	end
	refresh()
	if panel.Visible then
		Motion.Tween(frame, { GroupTransparency = 0 }, Motion.Slow)
	end
	Library.KeybindPanel = panel
	return panel
end

-- Round button that opens/closes the whole UI (for phones that have no keyboard).
function Library.MobileButton(options)
	ensure()
	options = options or {}
	local id = options.Id or "Main"
	if Library.MobileButtons[id] then
		return Library.MobileButtons[id]
	end
	local startVisible = options.Visible ~= false
	local scope = Scope.new()
	local button = { Visible = startVisible, Held = Library.LoadingCount > 0, Scope = scope, Id = id }
	local frame = Create.New("CanvasGroup", {
		Name = "MenuButton",
		Size = UDim2.fromOffset(42, 42),
		Position = options.Position and UDim2.fromOffset(options.Position.X, options.Position.Y) or UDim2.fromOffset(12, Root.ScreenSize().Y * 0.4),
		Visible = startVisible and not button.Held,
		BackgroundColor3 = Theme.T("Raised"),
		BackgroundTransparency = 0.05,
		GroupTransparency = 1,
		Active = true,
		ZIndex = 5,
		Corner = UDim.new(1, 0),
		Stroke = { Color = "AccentLine", Thickness = 1.5 },
		Parent = Root.Bar,
	})
	scope:Add(frame)
	local icon = Create.Icon(options.Icon or "layout-dashboard", 20, Theme.T("Accent"), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = frame,
	})
	local moved = 0
	scope:Add(Drag.Bind(frame, frame, { Rest = function(position, size)
		return Drag.Fit(position, size, 6)
	end }))
	scope:Add(Input.Drag(frame, {
		Begin = function()
			moved = 0
		end,
		Move = function(delta)
			moved = math.max(moved, delta.Magnitude)
		end,
		End = function()
			if moved < 8 and not button.Held then
				Motion.Tween(icon, { Rotation = icon.Rotation + 90 }, Motion.Base)
				if options.Callback then
					task.spawn(options.Callback)
				else
					Library.Toggle()
				end
			end
		end,
	}))
	-- button.Visible is the logical state (what the user chose); button.Held only hides it
	-- (and makes it unclickable) while a loader is on screen
	local function present()
		if button.Visible and not button.Held then
			frame.Visible = true
			Motion.Tween(frame, { GroupTransparency = 0 }, Motion.Base)
			return
		end
		local tween = Motion.Tween(frame, { GroupTransparency = 1 }, Motion.Fast)
		if tween then
			tween.Completed:Once(function()
				if not (button.Visible and not button.Held) then
					frame.Visible = false
				end
			end)
		else
			frame.Visible = false
		end
	end
	function button:SetVisible(visible)
		button.Visible = visible == true
		present()
	end
	function button:SetHeld(held)
		held = held == true
		if button.Held == held then
			return
		end
		button.Held = held
		present()
	end
	function button:Destroy()
		Library.MobileButtons[id] = nil
		if Library.MobileToggle == button then
			Library.MobileToggle = nil
		end
		scope:Clean()
	end
	if startVisible and not button.Held then
		Motion.Tween(frame, { GroupTransparency = 0 }, Motion.Slow)
	end
	Library.MobileButtons[id] = button
	if id == "Main" then
		Library.MobileToggle = button
	end
	return button
end

--[[
	DeaUI.Loader({ Title, Subtitle, Icon, Steps = { "Loading...", "Almost there" }, Duration = 2.5, OnDone })
	Shows a splash card with a progress bar. With `Steps` it runs by itself; otherwise drive it:
	  loader:SetProgress(0.5, "Half way")   loader:Finish(callback)
]]
function Library.Loader(options)
	ensure()
	options = options or {}
	local steps = type(options.Steps) == "table" and #options.Steps > 0 and options.Steps or nil
	local height = steps and (206 + #steps * 22 + 34) or 214
	local loader = { Alpha = 0, Shown = 0 }
	local accent = Theme.Get("Accent")
	local rim = Theme.Get("LineStrong")

	Library.LoadingCount += 1
	Toast.Hold(true)
	Library.ApplyHold()
	local timeout
	for _, hub in Library.Hubs do
		if hub.Window.Visible then
			Library.Held[hub.Window] = true
			hub.Window:Hide()
		end
	end

	local backdrop = Create.New("Frame", {
		Name = "Loader",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 990,
		Parent = Root.Bar,
	})
	local card = Create.New("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 20),
		Size = UDim2.fromOffset(340, height),
		BackgroundColor3 = Theme.T("Raised"),
		GroupTransparency = 1,
		ZIndex = 991,
		Corner = Theme.Radius + 6,
		Parent = backdrop,
	})
	local scale = Create.New("UIScale", { Scale = 0.9, Parent = card })
	local border = Create.New("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	})
	local borderGradient = Create.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent),
			ColorSequenceKeypoint.new(0.3, rim),
			ColorSequenceKeypoint.new(0.7, rim),
			ColorSequenceKeypoint.new(1, accent),
		}),
		Parent = border,
	})
	local glow = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0,
		ZIndex = 991,
		Parent = card,
	})
	Create.New("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
		Parent = glow,
	})
	Create.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Corner = UDim.new(1, 0),
		Stroke = { Color = "Line", Thickness = 3 },
		ZIndex = 992,
		Parent = card,
	})
	local ring = Create.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Corner = UDim.new(1, 0),
		ZIndex = 993,
		Parent = card,
	})
	local ringStroke = Create.New("UIStroke", {
		Color = accent,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ring,
	})
	local ringGradient = Create.New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = ringStroke,
	})
	local icon = Create.Icon(options.Icon or "sparkles", 28, Theme.T("Accent"), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 58),
		ZIndex = 994,
		Parent = card,
	})
	local pulse = Create.New("UIScale", { Parent = icon })
	Create.New("TextLabel", {
		Position = UDim2.fromOffset(16, 104),
		Size = UDim2.new(1, -32, 0, 24),
		Text = options.Title or "Loading",
		TextSize = 18,
		FontFace = Theme.FontBold,
		ZIndex = 992,
		Parent = card,
	})
	Create.New("TextLabel", {
		Position = UDim2.fromOffset(16, 130),
		Size = UDim2.new(1, -32, 0, 16),
		Text = options.Subtitle or "",
		TextSize = 12,
		TextColor3 = Theme.T("Faint"),
		ZIndex = 992,
		Parent = card,
	})
	local track = Create.New("Frame", {
		Position = UDim2.fromOffset(28, 164),
		Size = UDim2.new(1, -56, 0, 6),
		BackgroundColor3 = Theme.T("Pressed"),
		Corner = UDim.new(1, 0),
		ZIndex = 992,
		Parent = card,
	})
	local fill = Create.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Corner = UDim.new(1, 0),
		ZIndex = 993,
		Parent = track,
	})
	local shine = Create.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent),
			ColorSequenceKeypoint.new(0.5, accent:Lerp(Color3.new(1, 1, 1), 0.55)),
			ColorSequenceKeypoint.new(1, accent),
		}),
		Parent = fill,
	})
	local status = Create.New("TextLabel", {
		Position = UDim2.fromOffset(28, 178),
		Size = UDim2.new(1, -96, 0, 16),
		TextSize = 11,
		FontFace = Theme.Mono,
		TextColor3 = Theme.T("Muted"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 992,
		Parent = card,
	})
	local percent = Create.New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 178),
		Size = UDim2.fromOffset(56, 16),
		Text = "0%",
		TextSize = 11,
		FontFace = Theme.MonoBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 992,
		Parent = card,
	})
	local rows = {}
	if steps then
		for index, step in steps do
			local row = Create.New("Frame", {
				Position = UDim2.fromOffset(34, 206 + (index - 1) * 22),
				Size = UDim2.new(1, -68, 0, 22),
				BackgroundTransparency = 1,
				ZIndex = 992,
				Parent = card,
			})
			local mark = Create.Icon("circle-dashed", 14, Theme.T("Faint"), {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				ZIndex = 993,
				Parent = row,
			})
			local label = Create.New("TextLabel", {
				Position = UDim2.fromOffset(24, 0),
				Size = UDim2.new(1, -24, 1, 0),
				TextSize = 12,
				TextColor3 = Theme.T("Faint"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 993,
				Parent = row,
			})
			I18n.Bind(label, "Text", step)
			rows[index] = { Mark = mark, Label = label }
		end
	end
	if options.Footer then
		Create.New("TextLabel", {
			Position = UDim2.new(0, 16, 1, -22),
			Size = UDim2.new(1, -32, 0, 14),
			Text = options.Footer,
			TextSize = 10,
			FontFace = Theme.Mono,
			TextColor3 = Theme.T("Faint"),
			ZIndex = 992,
			Parent = card,
		})
	end

	local activeMark
	local function paintSteps(active)
		activeMark = nil
		for index, row in rows do
			if index < active then
				Create.SetIcon(row.Mark, "check-circle")
				Motion.Token(row.Mark, "ImageColor3", "Success")
				Motion.Token(row.Label, "TextColor3", "Muted")
				row.Mark.Rotation = 0
			elseif index == active then
				Create.SetIcon(row.Mark, "loader-2")
				Motion.Token(row.Mark, "ImageColor3", "Accent")
				Motion.Token(row.Label, "TextColor3", "Text")
				activeMark = row.Mark
			else
				Create.SetIcon(row.Mark, "circle-dashed")
				Motion.Token(row.Mark, "ImageColor3", "Faint")
				Motion.Token(row.Label, "TextColor3", "Faint")
			end
		end
	end

	local animated = Motion.Enabled()
	local started = os.clock()
	local connection
	connection = Services.RunService.Heartbeat:Connect(function(dt)
		if not backdrop.Parent then
			connection:Disconnect()
			return
		end
		if animated then
			loader.Shown += (loader.Alpha - loader.Shown) * math.min(1, dt * 6)
		else
			loader.Shown = loader.Alpha
		end
		fill.Size = UDim2.fromScale(loader.Shown, 1)
		percent.Text = string.format("%d%%", math.floor(loader.Shown * 100 + 0.5))
		if animated then
			local elapsed = os.clock() - started
			ringGradient.Rotation = (elapsed * 280) % 360
			borderGradient.Rotation = (elapsed * 70) % 360
			shine.Offset = Vector2.new(((elapsed * 0.9) % 2) - 1, 0)
			pulse.Scale = 1 + math.sin(elapsed * 3.2) * 0.08
			if activeMark then
				activeMark.Rotation = (elapsed * 360) % 360
			end
		end
	end)

	Motion.Tween(backdrop, { BackgroundTransparency = 0.4 }, Motion.Slow)
	Motion.Tween(card, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, Motion.Slow)
	Motion.Tween(scale, { Scale = 1 }, Motion.Slow, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	function loader:SetProgress(alpha, text)
		loader.Alpha = math.clamp(alpha or 0, 0, 1)
		if text ~= nil then
			I18n.Bind(status, "Text", text)
		end
	end

	function loader:SetStep(index, text)
		paintSteps(index)
		local total = math.max(#rows, 1)
		loader:SetProgress((index - 1) / total + 0.6 / total, text or (steps and steps[index]))
	end

	function loader:Finish(callback)
		if loader.Done then
			return
		end
		loader.Done = true
		if timeout and coroutine.running() ~= timeout then
			pcall(task.cancel, timeout)
		end
		loader.Alpha = 1
		paintSteps(#rows + 1)
		task.spawn(function()
			local waited = os.clock()
			while loader.Shown < 0.985 and os.clock() - waited < 0.8 do
				task.wait()
			end
			task.wait(animated and 0.22 or 0)
			Motion.Tween(scale, { Scale = 1.06 }, Motion.Base)
			Motion.Tween(card, { GroupTransparency = 1 }, Motion.Base)
			local fade = Motion.Tween(backdrop, { BackgroundTransparency = 1 }, Motion.Base)
			local function finish()
				connection:Disconnect()
				backdrop:Destroy()
				Library.LoadingCount = math.max(0, Library.LoadingCount - 1)
				Library.ApplyHold()
				if Library.LoadingCount == 0 then
					local held = Library.Held
					Library.Held = {}
					for window in held do
						if window.Frame and window.Frame.Parent then
							window:Show()
						end
					end
					task.delay(0.35, function()
						if Library.LoadingCount == 0 then
							Toast.Hold(false)
						end
					end)
				end
				if callback then
					task.spawn(callback)
				end
			end
			if fade then
				fade.Completed:Once(finish)
			else
				finish()
			end
		end)
	end

	if steps then
		paintSteps(0)
		task.spawn(function()
			local pause = (options.Duration or 2.5) / #steps
			for index in steps do
				if loader.Done then
					return
				end
				loader:SetStep(index)
				task.wait(pause)
			end
			loader:Finish(options.OnDone)
		end)
	end
	timeout = task.delay(options.MaxTime or 30, function()
		loader:Finish(options.OnDone)
	end)
	return loader
end

------------------------------------------------------------------------
-- Theme editor: standalone window to change every color of the interface
------------------------------------------------------------------------

local THEME_GROUPS = {
	{
		Name = { en = "Branding", vi = "Thương hiệu" },
		Icon = "palette",
		Colors = {
			{ "Logo", { en = "Logo icon", vi = "Biểu tượng logo" } },
			{ "LogoText", { en = "Logo text", vi = "Chữ logo" } },
			{ "Accent", { en = "Accent", vi = "Màu nhấn" } },
		},
	},
	{
		Name = { en = "Surfaces", vi = "Nền" },
		Icon = "layers",
		Colors = {
			{ "Base", { en = "Window", vi = "Cửa sổ" } },
			{ "Panel", { en = "Panel", vi = "Bảng" } },
			{ "Raised", { en = "Raised surface", vi = "Bề mặt nổi" } },
			{ "Field", { en = "Input field", vi = "Ô nhập" } },
			{ "Shade", { en = "Shade", vi = "Bóng tối" } },
		},
	},
	{
		Name = { en = "Borders", vi = "Viền" },
		Icon = "square",
		Colors = {
			{ "Line", { en = "Border", vi = "Viền" } },
			{ "LineStrong", { en = "Strong border", vi = "Viền đậm" } },
			{ "AccentLine", { en = "Accent border", vi = "Viền nhấn" } },
		},
	},
	{
		Name = { en = "Text", vi = "Chữ" },
		Icon = "type",
		Colors = {
			{ "Text", { en = "Primary text", vi = "Chữ chính" } },
			{ "Muted", { en = "Secondary text", vi = "Chữ phụ" } },
			{ "Faint", { en = "Subtle text", vi = "Chữ mờ" } },
			{ "AccentText", { en = "Text on accent", vi = "Chữ trên màu nhấn" } },
		},
	},
	{
		Name = { en = "Interaction", vi = "Tương tác" },
		Icon = "mouse-pointer",
		Colors = {
			{ "Hover", { en = "Hover", vi = "Rê chuột" } },
			{ "Pressed", { en = "Pressed", vi = "Đang bấm" } },
			{ "AccentHover", { en = "Accent hover", vi = "Nhấn khi rê" } },
			{ "AccentPressed", { en = "Accent pressed", vi = "Nhấn khi bấm" } },
			{ "AccentSoft", { en = "Soft accent", vi = "Nhấn nhạt" } },
			{ "AccentSofter", { en = "Subtle accent", vi = "Nhấn rất nhạt" } },
		},
	},
	{
		Name = { en = "Status", vi = "Trạng thái" },
		Icon = "shield-alert",
		Colors = {
			{ "Danger", { en = "Danger", vi = "Nguy hiểm" } },
			{ "Success", { en = "Success", vi = "Thành công" } },
			{ "Warning", { en = "Warning", vi = "Cảnh báo" } },
			{ "Info", { en = "Information", vi = "Thông tin" } },
		},
	},
	{
		Name = { en = "VIP", vi = "VIP" },
		Icon = "crown",
		Vip = true,
		Colors = {
			{ "Vip", { en = "VIP orange", vi = "Cam VIP" } },
			{ "VipSoft", { en = "VIP background", vi = "Nền VIP" } },
		},
	},
}

function Library.ThemeEditor()
	ensure()
	local existing = Library.ThemeEditorState
	if existing and existing.Window.Frame and existing.Window.Frame.Parent then
		existing.Window:Show()
		return existing
	end
	local window = Window.new({
		Id = "theme_editor",
		Title = { en = "Theme colors", vi = "Màu giao diện" },
		Icon = "palette",
		Size = Vector2.new(460, 540),
		MinSize = Vector2.new(340, 320),
	})
	local state = { Window = window }
	Library.ThemeEditorState = state
	local content = Create.New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Padding = { 12, 12, 14, 12 },
		List = { Gap = 10 },
		Parent = window.Body,
	})
	local function card(order)
		return Create.New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.T("Panel"),
			LayoutOrder = order,
			Corner = Theme.Radius,
			Stroke = { Color = "Line" },
			Padding = 12,
			List = { Gap = 10 },
			Parent = content,
		})
	end
	local function flow(parent, order)
		local holder = Create.New("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			List = { Dir = "X", Gap = 6, Wrap = true, VAlign = "Center" },
			Parent = parent,
		})
		return holder
	end
	local function caption(parent, source, order)
		return Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			Text = function(code)
				return I18n.Upper(I18n.Resolve(source))
			end,
			TextSize = 10,
			FontFace = Theme.FontBold,
			TextColor3 = Theme.T("Faint"),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			Parent = parent,
		})
	end

	local head = card(1)
	Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = {
			en = "Tap a swatch to change that color. Every change applies to the whole interface instantly.",
			vi = "Bấm vào ô màu để đổi màu đó. Mọi thay đổi áp dụng ngay cho toàn bộ giao diện.",
		},
		TextSize = 12,
		TextColor3 = Theme.T("Muted"),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = head,
	})
	local actions = flow(head, 2)
	local presets = flow(head, 4)
	caption(head, { en = "Presets", vi = "Chủ đề có sẵn" }, 3)

	local function commit(token, color)
		if Store.Get("ThemePreset", "Crimson") ~= "Custom" then
			Theme.CustomizeCurrent()
		end
		if Theme.SetCustomColor(token, color) then
			Theme.ApplyPreset("Custom")
		else
			Library.Notify({ en = "Color unavailable", vi = "Không đổi được màu" }, { en = "This color could not be saved.", vi = "Không thể lưu màu này." }, "warn")
		end
	end

	local function exportTheme()
		local colors = {}
		for _, definition in THEME_GROUPS do
			for _, slot in definition.Colors do
				colors[slot[1]] = string.upper(Theme.Get(slot[1]):ToHex())
			end
		end
		return Services.HttpService:JSONEncode(colors)
	end

	local function importTheme(raw)
		local ok, decoded = pcall(Services.HttpService.JSONDecode, Services.HttpService, raw)
		if not ok or type(decoded) ~= "table" then
			return 0
		end
		if Store.Get("ThemePreset", "Crimson") ~= "Custom" then
			Theme.CustomizeCurrent()
		end
		local count = 0
		for _, definition in THEME_GROUPS do
			for _, slot in definition.Colors do
				local value = decoded[slot[1]]
				if type(value) == "string" and string.match(value, "^#?%x%x%x%x%x%x$") and Theme.SetCustomColor(slot[1], Theme.Hex(value)) then
					count += 1
				end
			end
		end
		Theme.ApplyPreset("Custom")
		return count
	end

	Button.new({
		Text = { en = "Customize current", vi = "Tùy chỉnh từ chủ đề này" },
		Icon = "sliders",
		Variant = "Primary",
		Height = 28,
		LayoutOrder = 1,
		Parent = actions,
		Callback = function()
			Theme.CustomizeCurrent()
		end,
	})
	Button.new({
		Text = { en = "Reset custom", vi = "Đặt lại" },
		Icon = "rotate-ccw",
		Height = 28,
		LayoutOrder = 2,
		Parent = actions,
		Callback = function()
			Theme.ResetCustom()
		end,
	})
	Button.new({
		Text = { en = "Copy", vi = "Sao chép" },
		Icon = "copy",
		Height = 28,
		LayoutOrder = 3,
		Parent = actions,
		Callback = function()
			if Env.Clipboard(exportTheme()) then
				Library.Notify({ en = "Theme copied", vi = "Đã sao chép bảng màu" }, { en = "Paste it with Import to restore it.", vi = "Dùng nút Nhập để dán lại bảng màu này." }, "success")
			else
				Library.Notify({ en = "Clipboard unavailable", vi = "Không dùng được clipboard" }, { en = "Your executor has no setclipboard.", vi = "Executor của bạn không có setclipboard." }, "warn")
			end
		end,
	})
	Button.new({
		Text = { en = "Import", vi = "Nhập" },
		Icon = "download",
		Height = 28,
		LayoutOrder = 4,
		Parent = actions,
		Callback = function()
			task.spawn(function()
				local raw = Dialog.Prompt({
					Title = { en = "Import colors", vi = "Nhập bảng màu" },
					Message = { en = "Paste the text you copied with Copy.", vi = "Dán đoạn văn bản bạn đã sao chép bằng nút Sao chép." },
					Placeholder = '{"Accent":"E5243B"}',
					Confirm = { en = "Import", vi = "Nhập" },
					Mono = true,
				})
				if type(raw) ~= "string" or raw == "" then
					return
				end
				local count = importTheme(raw)
				if count > 0 then
					Library.Notify({ en = "Colors imported", vi = "Đã nhập màu" }, string.format(I18n.Get() == "vi" and "Đã áp dụng %d màu." or "%d colors applied.", count), "success")
				else
					Library.Notify({ en = "Import failed", vi = "Nhập thất bại" }, { en = "That text is not a valid color set.", vi = "Đoạn văn bản này không phải bảng màu hợp lệ." }, "warn")
				end
			end)
		end,
	})

	local chips = {}
	local function addChip(name, color, order)
		local button = Create.New("TextButton", {
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.T("Field"),
			BackgroundTransparency = 0,
			Corner = 6,
			Stroke = { Color = "Line" },
			Padding = { 0, 10, 0, 28 },
			LayoutOrder = order,
			Parent = presets,
		})
		Create.New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -18, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = color,
			Corner = UDim.new(1, 0),
			Parent = button,
		})
		local label = Create.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Text = name == "Custom" and { en = "Custom", vi = "Tùy chỉnh" } or name,
			TextSize = 12,
			FontFace = Theme.FontMedium,
			Parent = button,
		})
		chips[name] = { Stroke = button:FindFirstChildOfClass("UIStroke"), Label = label }
		button.Activated:Connect(function()
			Theme.ApplyPreset(name)
		end)
	end
	for index, preset in Theme.Presets do
		addChip(preset.Name, preset.Accent, index)
	end
	addChip("Custom", Theme.Get("Accent"), #Theme.Presets + 1)

	local preview = card(2)
	caption(preview, { en = "Preview", vi = "Xem trước" }, 1)
	local sample = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		List = { Dir = "X", Gap = 6, Wrap = true, VAlign = "Center" },
		Parent = preview,
	})
	Button.new({ Text = { en = "Primary", vi = "Nút chính" }, Variant = "Primary", Height = 28, LayoutOrder = 1, Parent = sample })
	Button.new({ Text = { en = "Secondary", vi = "Nút phụ" }, Height = 28, LayoutOrder = 2, Parent = sample })
	Button.new({ Text = { en = "Danger", vi = "Xóa" }, Variant = "Danger", Height = 28, LayoutOrder = 3, Parent = sample })
	Switch.new({ Value = true, Parent = sample })
	local function pill(token, source, order)
		local frame = Create.New("Frame", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.T(token),
			BackgroundTransparency = 0.82,
			Corner = 11,
			Stroke = { Color = token, Transparency = 0.5 },
			Padding = { 0, 10, 0, 10 },
			LayoutOrder = order,
			Parent = sample,
		})
		Create.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			Text = source,
			TextSize = 11,
			FontFace = Theme.FontBold,
			TextColor3 = Theme.T(token),
			Parent = frame,
		})
	end
	pill("Success", { en = "Success", vi = "Thành công" }, 5)
	pill("Warning", { en = "Warning", vi = "Cảnh báo" }, 6)
	pill("Info", { en = "Info", vi = "Thông tin" }, 7)
	pill("Vip", "VIP", 8)

	local renderers = {}
	local function slot(parent, token, title, order)
		local control = Create.New("TextButton", {
			Name = "Color" .. token,
			BackgroundColor3 = Theme.T("Field"),
			BackgroundTransparency = 0,
			LayoutOrder = order,
			Corner = 7,
			Stroke = { Color = "Line" },
			Parent = parent,
		})
		Create.New("TextLabel", {
			Position = UDim2.fromOffset(11, 8),
			Size = UDim2.new(1, -57, 0, 18),
			Text = title,
			TextSize = 12,
			FontFace = Theme.FontMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = control,
		})
		local hex = Create.New("TextLabel", {
			Position = UDim2.fromOffset(11, 29),
			Size = UDim2.new(1, -57, 0, 14),
			TextSize = 11,
			FontFace = Theme.Mono,
			TextColor3 = Theme.T("Muted"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = control,
		})
		local swatch = Create.New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			Corner = 6,
			Stroke = { Color = "LineStrong" },
			Parent = control,
		})
		local outline = control:FindFirstChildOfClass("UIStroke")
		control.MouseEnter:Connect(function()
			Motion.Token(outline, "Color", "AccentLine")
		end)
		control.MouseLeave:Connect(function()
			Motion.Token(outline, "Color", "Line")
		end)
		control.Activated:Connect(function()
			local original = Theme.Get(token)
			ColorPicker.Open({
				Color = original,
				Title = I18n.Resolve(title),
				Anchor = control,
				OnClose = function(color)
					if typeof(color) == "Color3" and color ~= original then
						commit(token, color)
					end
				end,
			})
		end)
		table.insert(renderers, function()
			local color = Theme.Get(token)
			swatch.BackgroundColor3 = color
			hex.Text = "#" .. string.upper(color:ToHex())
		end)
	end

	for index, definition in THEME_GROUPS do
		local holder = Create.New("Frame", {
			Name = "Group" .. index,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.T("Panel"),
			LayoutOrder = 10 + index,
			Corner = 8,
			Stroke = { Color = definition.Vip and "Vip" or "Line" },
			List = { HAlign = "Center" },
			Parent = content,
		})
		local header = Create.New("TextButton", {
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 1,
			Parent = holder,
		})
		Create.Icon(definition.Icon, 16, Theme.T(definition.Vip and "Vip" or "Muted"), {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Parent = header,
		})
		Create.New("TextLabel", {
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -96, 1, 0),
			Text = definition.Name,
			TextSize = 13,
			FontFace = Theme.FontMedium,
			TextColor3 = Theme.T(definition.Vip and "Vip" or "Text"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = header,
		})
		Create.New("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -34, 0, 0),
			Size = UDim2.fromOffset(24, 40),
			Text = tostring(#definition.Colors),
			TextSize = 11,
			FontFace = Theme.Mono,
			TextColor3 = Theme.T("Faint"),
			Parent = header,
		})
		local expanded = index == 1
		local chevron = Create.Icon(expanded and "chevron-down" or "chevron-right", 14, Theme.T("Faint"), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Parent = header,
		})
		local count = math.ceil(#definition.Colors / 2)
		local body = Create.New("Frame", {
			Name = "Colors",
			Size = UDim2.new(1, -16, 0, count * 52 + (count - 1) * 8 + 8),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Visible = expanded,
			Parent = holder,
		})
		Create.New("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 52),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = body,
		})
		for position, entry in definition.Colors do
			slot(body, entry[1], entry[2], position)
		end
		header.Activated:Connect(function()
			expanded = not expanded
			body.Visible = expanded
			Create.SetIcon(chevron, expanded and "chevron-down" or "chevron-right")
		end)
	end

	local function refresh()
		for _, render in renderers do
			render()
		end
		local current = Store.Get("ThemePreset", "Crimson")
		for name, chip in chips do
			Motion.Token(chip.Stroke, "Color", name == current and "Accent" or "Line")
			Motion.Token(chip.Label, "TextColor3", name == current and "Text" or "Muted")
		end
	end
	refresh()
	window.Scope:Add(Theme.Changed:Connect(refresh))
	window:Show()
	return state
end

------------------------------------------------------------------------
-- Extra elements (inspired by the element set of Compkiller / Source1)
------------------------------------------------------------------------

local function registerFlag(flag, control)
	if flag then
		local existing = Library.Flags[flag]
		if existing and existing ~= control then
			warn(string.format('[DeaUI] Flag "%s" is used by more than one element; a configuration only keeps the last one', flag))
		end
		control.Flag = flag
		Library.Flags[flag] = control
	end
	return control
end

local function keyText(key)
	return key and key.Name or I18n.Resolve("None")
end

-- compact colour swatch placed inside the control area of a toggle row
local function inlineColor(hub, parent, offset, config, title)
	if typeof(config) == "Color3" then
		config = { Default = config }
	elseif type(config) ~= "table" then
		config = {}
	end
	local color = typeof(config.Default) == "Color3" and config.Default or Color3.new(1, 1, 1)
	local self = { Changed = Signal.new() }
	local button = Create.New("TextButton", {
		Name = "InlineColor",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -offset, 0.5, 0),
		Size = UDim2.fromOffset(24, 22),
		BackgroundColor3 = color,
		Corner = Theme.RadiusSmall,
		Stroke = { Color = "LineStrong" },
		Parent = parent,
	})
	button.BackgroundTransparency = 0
	local outline = button:FindFirstChildOfClass("UIStroke")
	button.MouseEnter:Connect(function()
		Motion.Token(outline, "Color", "Text")
	end)
	button.MouseLeave:Connect(function()
		Motion.Token(outline, "Color", "LineStrong")
	end)
	function self:Get()
		return color
	end
	function self:Set(newColor, silent, force)
		if typeof(newColor) ~= "Color3" then
			return
		end
		if newColor == color then
			if force and not silent then
				self.Changed:Fire(color)
			end
			return
		end
		color = newColor
		Motion.Tween(button, { BackgroundColor3 = color }, Motion.Fast)
		if not silent then
			self.Changed:Fire(color)
		end
	end
	button.Activated:Connect(function()
		ColorPicker.Open({
			Color = color,
			Title = config.Title or title,
			Anchor = button,
			Callback = function(picked)
				self:Set(picked)
			end,
		})
	end)
	return self
end

-- compact key button placed inside the control area of a toggle row; `onPress` / `onRelease`
-- run when the key goes down / up.
local function inlineKeybind(hub, parent, offset, config, onPress, onRelease)
	if typeof(config) == "EnumItem" then
		config = { Default = config }
	elseif type(config) ~= "table" then
		config = {}
	end
	local key = config.Default
	local listening, listener = false, nil
	local self = { Changed = Signal.new(), Mode = config.Mode or "Toggle" }
	local button = Create.New("TextButton", {
		Name = "InlineKeybind",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -offset, 0.5, 0),
		Size = UDim2.fromOffset(56, 22),
		BackgroundColor3 = Theme.T("Field"),
		Corner = Theme.RadiusSmall,
		Stroke = { Color = "Line" },
		Parent = parent,
	})
	button.BackgroundTransparency = 0
	local label = Create.New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		TextSize = 11,
		FontFace = Theme.Mono,
		TextColor3 = Theme.T("Muted"),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	Motion.Hover(button, button, "BackgroundColor3", "Field", "Hover", "Pressed")
	local function render()
		label.Text = listening and "..." or keyText(key)
		Motion.Token(label, "TextColor3", listening and "Accent" or (key and "Text" or "Faint"))
	end
	local function stop()
		listening = false
		if listener then
			listener:Disconnect()
			listener = nil
		end
		render()
		task.delay(0.2, function()
			if not listening then
				Library.Capturing = false
			end
		end)
	end
	function self:Get()
		return key
	end
	function self:Set(newKey, silent, force)
		if newKey ~= nil and typeof(newKey) ~= "EnumItem" then
			return
		end
		if newKey == key then
			if force and not silent then
				self.Changed:Fire(key)
			end
			return
		end
		key = newKey
		render()
		if not silent then
			self.Changed:Fire(key)
		end
	end
	button.Activated:Connect(function()
		if listening then
			stop()
			return
		end
		listening = true
		Library.Capturing = true
		render()
		listener = Services.UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			local picked = input.KeyCode
			stop()
			if picked == Enum.KeyCode.Escape then
				return
			elseif picked == Enum.KeyCode.Backspace then
				self:Set(nil)
			else
				self:Set(picked)
			end
		end)
	end)
	hub.Scope:Connect(Services.UserInputService.InputBegan, function(input)
		if listening or Library.Capturing or Input.Typing() then
			return
		end
		if key and input.KeyCode == key then
			onPress()
		end
	end)
	hub.Scope:Connect(Services.UserInputService.InputEnded, function(input)
		if key and input.KeyCode == key and onRelease then
			onRelease()
		end
	end)
	hub.Scope:Connect(I18n.Changed, render)
	hub.Scope:Add(function()
		if listener then
			listener:Disconnect()
		end
	end)
	render()
	return self
end

local function registerBind(hub, bind)
	table.insert(Library.Binds, bind)
	hub.Scope:Add(function()
		local index = table.find(Library.Binds, bind)
		if index then
			table.remove(Library.Binds, index)
		end
	end)
end

-- Group:Toggle({ Title, Description, Icon, Default, Callback(value), Flag, Tooltip,
--                Keybind = { Default = Enum.KeyCode.X, Mode = "Toggle" | "Hold", Flag },
--                Color = Color3 | { Default = Color3, Callback(color), Flag } })
-- A toggle can carry an inline keybind and/or colour swatch next to its switch.
function Group:Toggle(options)
	local keyConfig, colorConfig = options.Keybind, options.Color
	local hasKey = keyConfig ~= nil and keyConfig ~= false
	local hasColor = colorConfig ~= nil and colorConfig ~= false
	local extra = (hasColor and 30 or 0) + (hasKey and 62 or 0)
	local entry = makeRow(self, rowOptions(options, 30 + extra))
	local control = Switch.new({
		Value = options.Default == true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Parent = entry.Control,
		Locked = options.Locked,
	})
	control.Row = entry
	connect(control.Changed, options.Callback)
	local hub = self.Page.Hub
	local offset = 38
	if hasColor then
		control.Color = inlineColor(hub, entry.Control, offset, colorConfig, options.Title)
		if type(colorConfig) == "table" then
			connect(control.Color.Changed, colorConfig.Callback)
			registerFlag(colorConfig.Flag, control.Color)
		end
		offset += 30
	end
	if hasKey then
		local mode
		control.Bind = inlineKeybind(hub, entry.Control, offset, keyConfig, function()
			if control.Bind.Mode == "Hold" then
				control:Set(true)
			else
				control:Set(not control:Get())
			end
		end, function()
			if control.Bind.Mode == "Hold" then
				control:Set(false)
			end
		end)
		if type(keyConfig) == "table" then
			registerFlag(keyConfig.Flag, control.Bind)
			connect(control.Bind.Changed, keyConfig.Callback)
		end
		registerBind(hub, {
			Name = options.Title,
			Key = function()
				return control.Bind:Get()
			end,
			Active = function()
				return control:Get()
			end,
		})
	end
	return register(options, control)
end

-- Group:Keybind also appears in the keybind list
local baseKeybind = Group.Keybind
function Group:Keybind(options)
	local control = baseKeybind(self, options)
	control.Pressed:Connect(function()
		control.LastPress = os.clock()
	end)
	registerBind(self.Page.Hub, {
		Name = options.Title,
		Key = function()
			return control:Get()
		end,
		Active = function()
			return control.LastPress ~= nil and os.clock() - control.LastPress < 0.35
		end,
	})
	return control
end

-- Group:Checkbox({ Title, Description, Icon, Default, Callback(value), Flag })
function Group:Checkbox(options)
	local entry = makeRow(self, rowOptions(options, 20))
	local box = Switch.Check({
		Value = options.Default == true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Parent = entry.Control,
		Locked = options.Locked,
	})
	local control = { Instance = box.Instance, Changed = Signal.new(), Row = entry }
	box.Changed:Connect(function(value)
		control.Changed:Fire(value)
	end)
	function control:Get()
		return box:Get()
	end
	function control:Set(value, silent, force)
		value = value == true
		if value == box:Get() then
			if force and not silent then
				control.Changed:Fire(value)
			end
			return
		end
		box:Set(value)
		if not silent then
			control.Changed:Fire(value)
		end
	end
	connect(control.Changed, options.Callback)
	return register(options, control)
end

-- Group:Segmented({ Title, Description, Icon, Options = { "A", "B" }, Default, Width, Callback(value), Flag })
-- Radio buttons in one pill; the highlight slides to the selected entry.
function Group:Segmented(options)
	local items = normalizeItems(options.Options or options.Items or {})
	local count = math.max(#items, 1)
	local width = options.Width or math.clamp(count * 74, 140, 280)
	local entry = makeRow(self, rowOptions(options, width))
	local value = options.Default
	if value == nil and items[1] then
		value = items[1].Value
	end
	local control = { Changed = Signal.new(), Row = entry }
	local track = Create.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.T("Field"),
		Corner = Theme.RadiusSmall + 1,
		Stroke = { Color = "Line" },
		Parent = entry.Control,
	})
	local pill = Create.New("Frame", {
		Size = UDim2.new(1 / count, -4, 1, -4),
		Position = UDim2.new(0, 2, 0, 2),
		BackgroundColor3 = Theme.T("AccentSoft"),
		Corner = Theme.RadiusSmall,
		Stroke = { Color = "AccentLine" },
		ZIndex = 1,
		Parent = track,
	})
	local labels = {}
	local function indexOf(target)
		for index, item in items do
			if item.Value == target then
				return index
			end
		end
		return nil
	end
	local function render(animate)
		local index = indexOf(value)
		pill.Visible = index ~= nil
		if index then
			Motion.Tween(pill, { Position = UDim2.new((index - 1) / count, 2, 0, 2) }, animate and Motion.Base or 0)
		end
		for position, label in labels do
			Motion.Token(label, "TextColor3", position == index and "Text" or "Muted")
		end
	end
	for index, item in items do
		local button = Create.New("TextButton", {
			Position = UDim2.fromScale((index - 1) / count, 0),
			Size = UDim2.fromScale(1 / count, 1),
			ZIndex = 2,
			Parent = track,
		})
		local label = Create.New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			TextSize = 12,
			FontFace = Theme.FontMedium,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = button,
		})
		I18n.Bind(label, "Text", item.Source)
		labels[index] = label
		button.Activated:Connect(function()
			control:Set(item.Value)
		end)
	end
	function control:Get()
		return value
	end
	function control:Set(newValue, silent, force)
		if newValue == value then
			if force and not silent then
				control.Changed:Fire(value)
			end
			return
		end
		value = newValue
		render(true)
		if not silent then
			control.Changed:Fire(value)
		end
	end
	render(false)
	connect(control.Changed, options.Callback)
	return register(options, control)
end
Group.Radio = Group.Segmented

-- Group:MultiSelect({ Title, Description, Icon, Options, Default = { values }, Max, Callback(list), Flag })
-- Chips that can be toggled independently (a multi selection dropdown without a popup).
function Group:MultiSelect(options)
	local content, entry = self:Block(options)
	local items = normalizeItems(options.Options or options.Items or {})
	local selected = {}
	local count = 0
	for _, value in options.Default or {} do
		if not selected[value] then
			selected[value] = true
			count += 1
		end
	end
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = content
	local control = { Changed = Signal.new(), Row = entry }
	local chips = {}
	local function render()
		for index, chip in chips do
			local on = selected[items[index].Value] == true
			Motion.Token(chip.Button, "BackgroundColor3", on and "AccentSoft" or "Field")
			Motion.Token(chip.Button, "TextColor3", on and "Text" or "Muted")
			Motion.Token(chip.Stroke, "Color", on and "AccentLine" or "Line")
		end
	end
	local function list()
		local out = {}
		for _, item in items do
			if selected[item.Value] then
				table.insert(out, item.Value)
			end
		end
		return out
	end
	for index, item in items do
		local chip = Create.New("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			BackgroundColor3 = Theme.T("Field"),
			TextSize = 12,
			FontFace = Theme.FontMedium,
			TextColor3 = Theme.T("Muted"),
			LayoutOrder = index,
			Corner = 13,
			Stroke = { Color = "Line" },
			Padding = { 0, 11, 0, 11 },
			Parent = content,
		})
		chip.BackgroundTransparency = 0
		I18n.Bind(chip, "Text", item.Source)
		chips[index] = { Button = chip, Stroke = chip:FindFirstChildOfClass("UIStroke") }
		chip.Activated:Connect(function()
			local value = item.Value
			if selected[value] then
				selected[value] = nil
				count -= 1
			else
				if options.Max and count >= options.Max then
					return
				end
				selected[value] = true
				count += 1
			end
			render()
			control.Changed:Fire(list())
		end)
	end
	function control:Get()
		return list()
	end
	function control:Set(values, silent)
		selected = {}
		count = 0
		for _, value in values or {} do
			if not selected[value] then
				selected[value] = true
				count += 1
			end
		end
		render()
		if not silent then
			control.Changed:Fire(list())
		end
	end
	render()
	connect(control.Changed, options.Callback)
	return register(options, control)
end
Group.MultiDropdown = Group.MultiSelect

-- Group:Stepper({ Title, Description, Icon, Min, Max, Step, Default, Width, Callback(value), Flag })
function Group:Stepper(options)
	local width = options.Width or 132
	local entry = makeRow(self, rowOptions(options, width))
	local min, max = options.Min or -math.huge, options.Max or math.huge
	local step = options.Step or 1
	local value = options.Default or (min ~= -math.huge and min or 0)
	local control = { Changed = Signal.new(), Row = entry }
	local function snap(number)
		if step > 0 and min ~= -math.huge then
			number = min + math.floor((number - min) / step + 0.5) * step
		elseif step > 0 then
			number = math.floor(number / step + 0.5) * step
		end
		return math.clamp(number, min, max)
	end
	local function format(number)
		if number == math.floor(number) then
			return string.format("%d", number)
		end
		return (string.gsub(string.format("%.3f", number), "0+$", ""))
	end
	value = snap(value)
	local field = Field.new({
		Text = format(value),
		Mono = true,
		Size = UDim2.new(1, -64, 1, 0),
		Position = UDim2.fromOffset(32, 0),
		Parent = entry.Control,
	})
	local function bump(direction)
		control:Set(value + step * direction)
	end
	Button.Icon({ Icon = "minus", Size = 28, Position = UDim2.fromOffset(0, 0), Parent = entry.Control, Callback = function()
		bump(-1)
	end })
	Button.Icon({ Icon = "plus", Size = 28, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = entry.Control, Callback = function()
		bump(1)
	end })
	field.Submitted:Connect(function(text)
		local number = tonumber(text)
		if number then
			control:Set(number)
		else
			field:Set(format(value))
		end
	end)
	function control:Get()
		return value
	end
	function control:Set(newValue, silent, force)
		newValue = snap(newValue)
		field:Set(format(newValue))
		if newValue == value then
			if force and not silent then
				control.Changed:Fire(value)
			end
			return
		end
		value = newValue
		if not silent then
			control.Changed:Fire(value)
		end
	end
	connect(control.Changed, options.Callback)
	return register(options, control)
end

-- Group:Progress({ Title, Description, Icon, Min, Max, Default, Color = token, Format(value), Width })
-- :Set(value) animates the bar, :Get()
function Group:Progress(options)
	local width = options.Width or 160
	local entry = makeRow(self, rowOptions(options, width))
	local min, max = options.Min or 0, options.Max or 1
	if max <= min then
		max = min + 1
	end
	local value = math.clamp(options.Default or options.Value or min, min, max)
	local reserve = options.ShowValue == false and 0 or 46
	local track = Create.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, -reserve, 0, 6),
		BackgroundColor3 = Theme.T("Pressed"),
		Corner = UDim.new(1, 0),
		Parent = entry.Control,
	})
	local fill = Create.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.T(options.Color or "Accent"),
		Corner = UDim.new(1, 0),
		Parent = track,
	})
	local label = Create.New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(42, 20),
		TextSize = 12,
		FontFace = Theme.Mono,
		TextColor3 = Theme.T("Muted"),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = options.ShowValue ~= false,
		Parent = entry.Control,
	})
	local control = { Row = entry }
	local function render(animate)
		local alpha = (value - min) / (max - min)
		Motion.Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, animate and Motion.Slow or 0)
		label.Text = options.Format and options.Format(value) or string.format("%d%%", math.floor(alpha * 100 + 0.5))
	end
	function control:Get()
		return value
	end
	function control:Set(newValue)
		value = math.clamp(tonumber(newValue) or value, min, max)
		render(true)
	end
	render(false)
	return control
end

local TAG_KINDS = { success = "Success", warn = "Warning", error = "Danger", info = "Info", accent = "Accent" }

-- Group:Tag({ Title, Description, Icon, Text, Kind = "success" | "warn" | "error" | "info" | "accent" })
function Group:Tag(options)
	local entry = makeRow(self, rowOptions(options, options.Width or 90))
	local token = TAG_KINDS[options.Kind or "accent"] or "Accent"
	local pill = Create.New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		Text = options.Text or "",
		TextSize = 11,
		FontFace = Theme.FontBold,
		TextColor3 = Theme.T(token),
		BackgroundColor3 = Theme.T("Field"),
		Corner = 11,
		Stroke = { Color = token },
		Padding = { 0, 10, 0, 10 },
		Parent = entry.Control,
	})
	pill.BackgroundTransparency = 0
	local outline = pill:FindFirstChildOfClass("UIStroke")
	local control = { Row = entry }
	function control:SetText(text)
		I18n.Bind(pill, "Text", text)
	end
	function control:SetKind(kind)
		local newToken = TAG_KINDS[kind] or "Accent"
		Motion.Token(pill, "TextColor3", newToken)
		Motion.Token(outline, "Color", newToken)
	end
	return control
end

-- Group:Paragraph({ Title, Text, Color = token, Rich })
function Group:Paragraph(options)
	options = options or {}
	local row = newRow(self)
	local body = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Padding = { 10, 14, 11, 14 },
		List = { Gap = 3 },
		Parent = row,
	})
	local title
	if options.Title then
		title = Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			Text = options.Title,
			TextSize = 13,
			FontFace = Theme.FontMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = body,
		})
	end
	local text = Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = options.Text or options.Description or "",
		TextSize = 12,
		TextColor3 = Theme.T(options.Color or "Muted"),
		TextWrapped = true,
		RichText = options.Rich == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = body,
	})
	local control = { Row = row }
	function control:SetText(value)
		I18n.Bind(text, "Text", value)
	end
	function control:SetTitle(value)
		if title then
			I18n.Bind(title, "Text", value)
		end
	end
	return control
end

-- Group:Divider({ Text })
function Group:Divider(options)
	options = options or {}
	local row = newRow(self, 24)
	Create.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.new(1, -28, 0, 1),
		BackgroundColor3 = Theme.T("Line"),
		Parent = row,
	})
	if options.Text then
		local label = Create.New("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 14),
			BackgroundColor3 = Theme.T("Panel"),
			Padding = { 0, 8, 0, 8 },
			TextSize = 10,
			FontFace = Theme.FontBold,
			TextColor3 = Theme.T("Faint"),
			ZIndex = 2,
			Parent = row,
		})
		label.BackgroundTransparency = 0
		I18n.Bind(label, "Text", function()
			return I18n.Upper(I18n.Resolve(options.Text))
		end)
	end
	return { Row = row }
end

-- Group:Image({ Image = "rbxassetid://...", Height, Fit = true })
function Group:Image(options)
	local row = newRow(self, (options.Height or 120) + 20)
	return Create.New("ImageLabel", {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 1, -20),
		Image = options.Image or "",
		ScaleType = options.Fit and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
		Corner = Theme.RadiusSmall + 2,
		Stroke = { Color = "Line" },
		Parent = row,
	})
end

-- Group:Buttons({ { Text, Icon, Variant, Callback, Tooltip }, ... })  one row of equal buttons
function Group:Buttons(list)
	local row = newRow(self, 46)
	local holder = Create.New("Frame", {
		Position = UDim2.fromOffset(14, 9),
		Size = UDim2.new(1, -28, 0, 28),
		BackgroundTransparency = 1,
		List = { Dir = "X", Gap = 8 },
		Parent = row,
	})
	local count = math.max(#list, 1)
	local out = {}
	for index, spec in list do
		out[index] = Button.new({
			Text = spec.Text,
			Icon = spec.Icon,
			Variant = spec.Variant or "Secondary",
			Size = UDim2.new(1 / count, -(8 * (count - 1)) / count, 0, 28),
			Tooltip = spec.Tooltip,
			Callback = safe(spec.Callback),
			LayoutOrder = index,
			Parent = holder,
		})
	end
	return out
end
------------------------------------------------------------------------
-- Config manager and the ready made Settings page
------------------------------------------------------------------------

local Config = {}
Library.Config = Config

local function configPath(name)
	return Env.Path("configs", Env.SafeName(name) .. ".json")
end

local function encodeValue(value)
	local kind = typeof(value)
	if kind == "Color3" then
		-- plain dictionaries only: JSONEncode cannot mix array and dictionary parts
		return { __t = "c", r = value.R, g = value.G, b = value.B }
	elseif kind == "EnumItem" then
		return { __t = "e", t = tostring(value.EnumType), n = value.Name }
	elseif value == nil then
		return { __t = "n" }
	end
	return value
end

local function decodeValue(value)
	if type(value) == "table" and value.__t == "c" then
		return Color3.new(value.r or 0, value.g or 0, value.b or 0)
	elseif type(value) == "table" and value.__t == "e" then
		local ok, item = pcall(function()
			return Enum[value.t][value.n]
		end)
		return ok and item or nil
	elseif type(value) == "table" and value.__t == "n" then
		return nil
	end
	return value
end

function Config.Available()
	return Env.writefile ~= nil and Env.readfile ~= nil
end

-- JSON text with the current value of every control that has a Flag.
function Config.Serialize()
	local flags = {}
	for flag, control in Library.Flags do
		local ok, value = pcall(function()
			return control:Get()
		end)
		if ok then
			if type(value) == "table" and #value > 0 and value.__t == nil then
				local copy = {}
				for index, entry in value do
					copy[index] = encodeValue(entry)
				end
				value = copy
			else
				value = encodeValue(value)
			end
			flags[flag] = value
		end
	end
	return Services.HttpService:JSONEncode({ Version = 2, Flags = flags })
end

function Config.Apply(text)
	local ok, decoded = pcall(function()
		return Services.HttpService:JSONDecode(text)
	end)
	if not ok or type(decoded) ~= "table" or type(decoded.Flags) ~= "table" then
		return false
	end
	for flag, stored in decoded.Flags do
		local control = Library.Flags[flag]
		if control then
			local value
			if type(stored) == "table" and stored.__t == nil then
				value = {}
				for index, entry in stored do
					value[index] = decodeValue(entry)
				end
			else
				value = decodeValue(stored)
			end
			-- force = true: the callback runs for every restored value, even when the UI already
			-- showed it, so the real feature always matches what the control displays
			local applied, problem = pcall(function()
				control:Set(value, false, true)
			end)
			if not applied then
				warn(string.format('[DeaUI] could not restore "%s": %s', flag, tostring(problem)))
			end
		end
	end
	return true
end

function Config.Save(name)
	if not name or name == "" or not Config.Available() then
		return false
	end
	return Env.Write(configPath(name), Config.Serialize())
end

function Config.Exists(name)
	return name ~= nil and name ~= "" and Env.Read(configPath(name)) ~= nil
end

function Config.Load(name)
	if not name or name == "" then
		return false
	end
	local text = Env.Read(configPath(name))
	if not text then
		return false
	end
	return Config.Apply(text)
end

function Config.List()
	local names = {}
	if Env.listfiles then
		local ok, files = pcall(Env.listfiles, Env.Path("configs"))
		if ok and type(files) == "table" then
			for _, file in files do
				local name = string.match(file, "([^/\\]+)%.json$")
				if name then
					table.insert(names, name)
				end
			end
		end
	end
	table.sort(names)
	return names
end

function Config.Delete(name)
	if not name or name == "" or not Env.delfile then
		return false
	end
	return (pcall(Env.delfile, configPath(name)))
end

function Config.SetAutoload(name)
	if not Config.Available() then
		return false
	end
	return Env.Write(Env.Path("autoload.txt"), name or "")
end

-- Name of the configuration the user chose to load automatically. A pointer to a configuration
-- that no longer exists is cleared instead of being reported.
function Config.GetAutoload()
	local text = Env.Read(Env.Path("autoload.txt"))
	if text and text ~= "" then
		if Config.Exists(text) then
			return text
		end
		pcall(Config.SetAutoload, nil)
	end
	return nil
end

-- Call after every control has been created.
function Library.LoadAutoConfig()
	local name = Config.GetAutoload()
	if name and Config.Load(name) then
		Library.Notify("Configuration loaded", name, "success", 3)
		return true
	end
	return false
end

-- page:ConfigGroup() adds the save / load / delete / auto-load controls to a page.
function Page:ConfigGroup(title)
	local group = self:Group(title or "Configuration")
	local name = Config.GetAutoload() or ""
	local selected = name ~= "" and name or nil
	local input = group:Input({
		Title = "Configuration name",
		Description = "Type a name, then press Save",
		Icon = "file-cog",
		Placeholder = "Configuration name",
		Default = name,
		Width = 170,
	})
	local list = group:Dropdown({
		Title = "Saved configurations",
		Description = "Pick one to load or delete",
		Icon = "folder-open",
		Options = Config.List(),
		Default = selected,
		Placeholder = "No configuration",
		Width = 170,
		Callback = function(picked)
			selected = picked
			input:Set(picked or "")
		end,
	})
	local function reload(pick)
		list:SetOptions(Config.List())
		if pick then
			list:Set(pick, true)
			selected = pick
		end
	end
	group:Buttons({
		{ Text = "Save", Icon = "save", Variant = "Primary", Callback = function()
			local target = input:Get()
			if target == "" then
				target = selected or ""
			end
			if target == "" then
				Library.Notify("Name required", "Type a configuration name first", "warn", 3)
				return
			end
			if not Config.Available() then
				Library.Notify("Cannot save", "This executor has no file access", "error")
				return
			end
			if Config.Save(target) then
				reload(Env.SafeName(target))
				Library.Notify("Configuration saved", target, "success", 3)
			else
				Library.Notify("Cannot save", target, "error")
			end
		end },
		{ Text = "Load", Icon = "download", Callback = function()
			if selected and Config.Load(selected) then
				Library.Notify("Configuration loaded", selected, "success", 3)
			else
				Library.Notify("Cannot load", selected or "", "warn")
			end
		end },
		{ Text = "Delete", Icon = "trash-2", Variant = "Danger", Callback = function()
			if not selected then
				return
			end
			local target = selected
			if Library.Confirm({ Title = "Delete configuration", Message = target, Danger = true, Confirm = "Delete" }) then
				Config.Delete(target)
				selected = nil
				reload()
				list:Set(nil, true)
				Library.Notify("Configuration deleted", target, "info", 3)
			end
		end },
	})
	local auto
	auto = group:Toggle({
		Title = "Load automatically",
		Description = "Loads the selected configuration when the script starts",
		Icon = "rotate-cw",
		Default = Config.GetAutoload() ~= nil,
		Callback = function(on)
			if not on then
				Config.SetAutoload(nil)
				return
			end
			local target = selected
			if not target and input:Get() ~= "" then
				target = Env.SafeName(input:Get())
			end
			if not target or not Config.Exists(target) then
				auto:Set(false, true)
				Library.Notify("Cannot enable", "Save or pick a configuration first", "warn", 3)
				return
			end
			Config.SetAutoload(target)
		end,
	})
	return group
end

--[[
	hub:AddSettingsPage({ Id, Text, Icon, Title, Description, Config = true, Unload = true })
	Ready made page: language, theme, accent colour, scale, animations, menu key, watermark,
	keybind list, mobile button, configurations and unload.
]]
function Hub:AddSettingsPage(spec)
	spec = spec or {}
	local hub = self
	local page = self:AddPage({
		Id = spec.Id or "settings",
		Text = spec.Text or "Settings",
		Icon = spec.Icon or "settings",
		Title = spec.Title or "Settings",
		Description = spec.Description or "Language, appearance and configuration of the interface",
	})

	local look = page:Group("Interface")
	local language = look:Dropdown({
		Title = "Language",
		Description = "Language of the whole interface",
		Icon = "languages",
		Options = I18n.Items(),
		Default = I18n.Get(),
		Search = false,
		Width = 150,
		Callback = function(code)
			I18n.Set(code)
		end,
	})
	self.Scope:Connect(I18n.Changed, function(code)
		language:Set(code, true)
	end)
	look:Dropdown({
		Title = "Theme",
		Description = "Colour preset of the interface",
		Icon = "palette",
		Options = Library.GetThemes(),
		Default = Library.GetTheme(),
		Search = false,
		Width = 150,
		Callback = function(name)
			Library.SetTheme(name)
		end,
	})
	look:Color({
		Title = "Accent colour",
		Description = "Replaces the accent of the current theme",
		Icon = "pipette",
		Default = Theme.Get("Accent"),
		Callback = function(color)
			Library.SetAccent(color)
		end,
	})
	look:Button({
		Title = { en = "Color editor", vi = "Trình chỉnh màu" },
		Description = { en = "Change every color of the interface", vi = "Tùy chỉnh toàn bộ màu của giao diện" },
		Icon = "paintbrush",
		ButtonText = { en = "Open", vi = "Mở" },
		Keywords = { "theme", "color", "colour", "mau", "giao dien" },
		Callback = function()
			Library.ThemeEditor()
		end,
	})
	look:Slider({
		Title = "Interface scale",
		Description = "Makes everything bigger or smaller",
		Icon = "scaling",
		Min = 0.7,
		Max = 1.5,
		Step = 0.05,
		Default = Store.Get("UIScale") or 1,
		Suffix = "x",
		Width = 150,
		OnRelease = function(value)
			Library.SetScale(value)
		end,
	})
	look:Toggle({
		Title = "Animations",
		Description = "Smooth transitions and movement",
		Icon = "sparkles",
		Default = Store.Get("Animations") ~= false,
		Callback = function(on)
			Library.SetAnimations(on)
		end,
	})

	local controls = page:Group("Controls")
	controls:Keybind({
		Title = "Menu key",
		Description = "Shows or hides the whole interface",
		Icon = "keyboard",
		Default = Library.ToggleKey,
		Callback = function(key)
			Library.SetToggleKey(key)
		end,
	})
	controls:Toggle({
		Title = "Menu button",
		Description = "Round button that opens the menu on touch screens",
		Icon = "layout-dashboard",
		Default = Library.MobileToggle ~= nil and Library.MobileToggle.Visible,
		Callback = function(on)
			Library.MobileButton():SetVisible(on)
		end,
	})
	controls:Toggle({
		Title = "Watermark",
		Description = "Small bar with FPS, ping and time",
		Icon = "badge-info",
		Default = #Library.Watermarks > 0 and Library.Watermarks[1].Visible,
		Callback = function(on)
			if #Library.Watermarks == 0 then
				local mark = Library.Watermark({ Title = spec.WatermarkTitle or "DeaUI", Icon = "sparkles" })
				mark:AddFPS()
				mark:AddPing()
				mark:AddTime()
			end
			Library.SetWatermarkVisible(on)
		end,
	})
	controls:Toggle({
		Title = "Keybind list",
		Description = "Shows the active keybinds on screen",
		Icon = "list",
		Default = Library.KeybindPanel ~= nil and Library.KeybindPanel.Visible,
		Callback = function(on)
			Library.KeybindList():SetVisible(on)
		end,
	})

	if spec.Config ~= false then
		page:ConfigGroup()
	end

	if spec.Unload ~= false then
		local danger = page:Group("Danger zone")
		danger:Button({
			Title = "Unload interface",
			Description = "Removes the whole interface from the game",
			Icon = "power",
			ButtonText = "Unload",
			ButtonIcon = "power",
			Variant = "Danger",
			Callback = function()
				if Library.Confirm({ Title = "Unload interface", Message = "Everything will be removed. Continue?", Danger = true, Confirm = "Unload" }) then
					Library.Destroy()
				end
			end,
		})
	end
	return page
end

return Library
end

local loaded = {}
local loading = {}

local function import(name)
	local cached = loaded[name]
	if cached ~= nil then
		return cached
	end
	local factory = Modules[name]
	if not factory then
		error("[DeaUI] missing module " .. tostring(name), 2)
	end
	if loading[name] then
		error("[DeaUI] circular import " .. tostring(name), 2)
	end
	loading[name] = true
	local result = factory(import)
	loading[name] = nil
	if result == nil then
		result = true
	end
	loaded[name] = result
	return result
end

local Library = import("Library")

-- Add-ons (for example the DeaDEX tools) share the same module registry.
Library.Import = import
function Library.AddModules(extra)
	for name, factory in extra do
		if Modules[name] == nil then
			Modules[name] = factory
		end
	end
end

return Library
