--[[
	DeaUI-S 1.0.0 - UI library for Roblox Simulator games (executor or Studio).
	A complete redesign of DeaUI 2.0.0: new visual identity, simulator components, asset previews,
	Vietnamese / English localization, themes, mini HUD, loader and a safe persistence layer.

	DeaUI-S is strictly a UI library. It contains no gameplay automation, no remote handling and no
	game-specific logic: your script connects its own logic through callbacks.

	Main folder (executor workspace): DeaUI-S/  ->  /storage/emulated/0/Delta/Workspace/DeaUI-S on Delta

	  local DeaUI_S = loadstring(readfile("DeaUI-S/DeaUI-S.lua"))()
	  local UI = DeaUI_S.Init({ Language = "vi", Theme = "Midnight" })
	  local win = UI.CreateWindow({ Title = "My Hub", Icon = "layout-dashboard" })
	  local page = win:AddPage({ Id = "main", Text = { en = "Main", vi = "Chính" }, Icon = "home" })
	  page:Group("Demo"):Toggle({ Title = "Enabled", Callback = function(on) print(on) end })

	See Example.lua for every component and README.md for the API reference.
]]

local Modules = {}

Modules["Animation"] = function(import)
local Services = import("Core/Services")
local Util = import("Core/Util")
local Theme = import("Theme/Theme")

--[[
	One animation system for the whole interface. All durations, easing and the on/off switch come
	from Animation.Settings, so every component moves the same way. Tweens that touch the same
	property of the same object replace each other (no conflicts on rapid toggling) and everything
	is cancelled on Cleanup.
]]
local Anim = {
	Settings = {
		AnimationEnabled = true,
		AnimationSpeed = 1,
		TransitionDuration = 0.22,
		EasingStyle = Enum.EasingStyle.Quint,
		EasingDirection = Enum.EasingDirection.Out,
		ReducedMotion = false,
	},
}

local active = setmetatable({}, { __mode = "k" }) -- object -> list of entries
local all = {} -- entry -> true (strong, for CancelAll / leak checks)
local counters = {}
local ticker

local function easing(value, fallback, enumType)
	if typeof(value) == "EnumItem" then
		return value
	end
	if type(value) == "string" then
		local ok, item = pcall(function()
			return enumType[value]
		end)
		if ok and item then
			return item
		end
	end
	return fallback
end

-- Configure{ AnimationEnabled, AnimationSpeed, TransitionDuration, EasingStyle, EasingDirection, ReducedMotion }
function Anim.Configure(map)
	local s = Anim.Settings
	for key, value in pairs(map or {}) do
		if key == "AnimationEnabled" or key == "ReducedMotion" then
			s[key] = value == true
		elseif key == "AnimationSpeed" and type(value) == "number" then
			s[key] = Util.clamp(value, 0.25, 3)
		elseif key == "TransitionDuration" and type(value) == "number" then
			s[key] = Util.clamp(value, 0.05, 1)
		elseif key == "EasingStyle" then
			s[key] = easing(value, s[key], Enum.EasingStyle)
		elseif key == "EasingDirection" then
			s[key] = easing(value, s[key], Enum.EasingDirection)
		end
	end
end

function Anim.Enabled()
	return Anim.Settings.AnimationEnabled and not Anim.Settings.ReducedMotion
end

function Anim.Speed()
	return Anim.Settings.AnimationSpeed * (Theme.Metrics().AnimationSpeed or 1)
end

-- "fast" | "base" | "slow" | seconds -> seconds after the global speed
function Anim.Duration(kind)
	local base = Anim.Settings.TransitionDuration
	local seconds
	if type(kind) == "number" then
		seconds = kind
	elseif kind == "fast" then
		seconds = base * 0.55
	elseif kind == "slow" then
		seconds = base * 1.6
	else
		seconds = base
	end
	return seconds / math.max(Anim.Speed(), 0.05)
end

local function release(entry)
	all[entry] = nil
	local list = active[entry.object]
	if list then
		local index = Util.find(list, entry)
		if index then
			table.remove(list, index)
		end
		if #list == 0 then
			active[entry.object] = nil
		end
	end
end

local function cancelEntry(entry, snapNonOverlap, overlap)
	release(entry)
	if entry.connection then
		entry.connection:Disconnect()
	end
	pcall(function()
		entry.tween:Cancel()
	end)
	if snapNonOverlap then
		for property, value in pairs(entry.props) do
			if not overlap[property] then
				pcall(function()
					entry.object[property] = value
				end)
			end
		end
	end
end

-- Tween(object, props, duration | { Duration, Style, Direction, OnComplete })
-- Returns a handle with Cancel(), or nil when the change was applied instantly.
function Anim.Tween(object, props, options)
	if type(options) ~= "table" then
		options = { Duration = options }
	end
	local duration = options.Duration
	if duration == nil then
		duration = Anim.Duration("base")
	elseif options.Raw ~= true then
		duration = Anim.Duration(duration)
	end
	local list = active[object]
	if list then
		for _, entry in ipairs(Util.clone(list)) do
			local overlap = {}
			local shared = false
			for property in pairs(props) do
				if entry.props[property] ~= nil then
					overlap[property] = true
					shared = true
				end
			end
			if shared then
				cancelEntry(entry, true, overlap)
			end
		end
	end
	if not Anim.Enabled() or duration <= 0 then
		for property, value in pairs(props) do
			object[property] = value
		end
		if options.OnComplete then
			options.OnComplete()
		end
		return nil
	end
	local info = TweenInfo.new(duration, options.Style or Anim.Settings.EasingStyle, options.Direction or Anim.Settings.EasingDirection)
	local tween = Services.TweenService:Create(object, info, props)
	local entry = { object = object, props = props, tween = tween }
	active[object] = active[object] or {}
	table.insert(active[object], entry)
	all[entry] = true
	entry.connection = tween.Completed:Connect(function(playback)
		if entry.connection then
			entry.connection:Disconnect()
			entry.connection = nil
		end
		release(entry)
		if playback == Enum.PlaybackState.Completed and options.OnComplete then
			options.OnComplete()
		end
	end)
	tween:Play()
	entry.Cancel = function()
		cancelEntry(entry, false, {})
	end
	return entry
end

function Anim.Cancel(object)
	local list = active[object]
	if list then
		for _, entry in ipairs(Util.clone(list)) do
			cancelEntry(entry, false, {})
		end
	end
end

function Anim.CancelAll()
	for entry in pairs(Util.clone(all)) do
		cancelEntry(entry, false, {})
	end
end

function Anim.ActiveCount()
	local n = 0
	for _ in pairs(all) do
		n = n + 1
	end
	return n
end

-- Tweens `property` to a theme token and keeps it bound, so theme changes follow the current state.
function Anim.Token(object, property, token, duration)
	Theme.Bind(object, property, token, true)
	local target = Theme.Resolve(token)
	if target ~= nil then
		Anim.Tween(object, { [property] = target }, duration or "fast")
	end
end

-- Hover / pressed colors for a button. Returns update(normal, hover, pressed) to change the tokens.
function Anim.Hover(button, target, normal, hover, pressed, property)
	property = property or "BackgroundColor3"
	local hovering, down = false, false
	local function update()
		Anim.Token(target, property, (down and pressed) or (hovering and hover) or normal)
	end
	if not (Services.UserInputService.TouchEnabled and not Services.UserInputService.MouseEnabled) then
		button.MouseEnter:Connect(function()
			hovering = true
			update()
		end)
		button.MouseLeave:Connect(function()
			hovering, down = false, false
			update()
		end)
	end
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

-- Smoothly changing number. One shared Heartbeat connection drives every counter and is
-- disconnected as soon as all counters have settled.
local function step(dt)
	local running = false
	for counter in pairs(counters) do
		local gap = counter.target - counter.value
		if math.abs(gap) <= counter.epsilon then
			counter.value = counter.target
			counters[counter] = nil
			counter.apply(counter.value)
		else
			counter.value = counter.value + gap * (1 - math.exp(-dt * counter.rate))
			counter.apply(counter.value)
			running = true
		end
	end
	if not running and ticker then
		ticker:Disconnect()
		ticker = nil
	end
end

function Anim.Number(initial, apply, options)
	options = options or {}
	local counter = { value = initial or 0, target = initial or 0, apply = apply, rate = options.Rate or 9, epsilon = options.Epsilon or 0.01 }
	function counter:Set(target, instant)
		self.target = target
		if instant or not Anim.Enabled() then
			self.value = target
			counters[self] = nil
			self.apply(target)
			return
		end
		counters[self] = true
		if not ticker then
			ticker = Services.RunService.Heartbeat:Connect(step)
		end
	end
	function counter:Get()
		return self.target
	end
	function counter:Destroy()
		counters[self] = nil
	end
	apply(counter.value)
	return counter
end

function Anim.CounterCount()
	local n = 0
	for _ in pairs(counters) do
		n = n + 1
	end
	return n
end

function Anim.Cleanup()
	Anim.CancelAll()
	counters = {}
	if ticker then
		ticker:Disconnect()
		ticker = nil
	end
end

-- Respect a system reduced-motion setting when the client exposes one.
pcall(function()
	local settings = UserSettings():GetService("UserGameSettings")
	if settings.ReducedMotion == true then
		Anim.Settings.ReducedMotion = true
	end
end)

return Anim
end

Modules["Core/Env"] = function(import)
-- Executor / platform capability detection. Every optional API is looked up once and wrapped,
-- so the library keeps working (without persistence, clipboard, ...) where it is missing.
local Env = {}

local genv = _G
if type(getgenv) == "function" then
	local ok, value = pcall(getgenv)
	if ok and type(value) == "table" then
		genv = value
	end
end
Env.Global = genv

local function find(path)
	local ok, value = pcall(function()
		local node = genv
		for part in string.gmatch(path, "[^%.]+") do
			node = node and (rawget(node, part) or node[part])
			if node == nil then
				return nil
			end
		end
		return node
	end)
	if ok then
		return value
	end
	return nil
end
Env.Find = find

function Env.FindFunction(...)
	for index = 1, select("#", ...) do
		local value = find((select(index, ...)))
		if type(value) == "function" then
			return value
		end
	end
	return nil
end

Env.Name, Env.Version = "Unknown", ""
pcall(function()
	local identify = Env.FindFunction("identifyexecutor", "getexecutorname")
	if identify then
		local name, version = identify()
		Env.Name = tostring(name or "Unknown")
		Env.Version = tostring(version or "")
	end
end)

local rawCloneref = Env.FindFunction("cloneref", "clonereference")
function Env.Ref(object)
	if rawCloneref and typeof(object) == "Instance" then
		local ok, ref = pcall(rawCloneref, object)
		if ok and typeof(ref) == "Instance" then
			return ref
		end
	end
	return object
end

Env.gethui = Env.FindFunction("gethui", "get_hidden_gui", "gethiddengui")
Env.getCustomAsset = Env.FindFunction("getcustomasset", "getsynasset")
Env.setClipboard = Env.FindFunction("setclipboard", "toclipboard", "set_clipboard")
Env.writefile = Env.FindFunction("writefile")
Env.readfile = Env.FindFunction("readfile")
Env.isfile = Env.FindFunction("isfile")
Env.isfolder = Env.FindFunction("isfolder")
Env.makefolder = Env.FindFunction("makefolder")
Env.listfiles = Env.FindFunction("listfiles")
Env.delfile = Env.FindFunction("delfile")
Env.httpRequest = Env.FindFunction("request", "http_request", "syn.request", "http.request")

-- True when the file API needed for persistence exists.
function Env.HasFiles()
	return Env.writefile ~= nil and Env.readfile ~= nil and Env.isfile ~= nil and Env.isfolder ~= nil and Env.makefolder ~= nil
end

-- Main directory. Executor file functions are relative to the executor workspace, so on Delta
-- "DeaUI-S" is /storage/emulated/0/Delta/Workspace/DeaUI-S (see Persistence.Init for the probe).
Env.Root = "DeaUI-S"
Env.AbsoluteRoot = "/storage/emulated/0/Delta/Workspace/DeaUI-S"

function Env.Path(...)
	local parts = { Env.Root, ... }
	return table.concat(parts, "/")
end

function Env.SafeName(name)
	local cleaned = string.gsub(tostring(name), "[^%w%-_ %.]", "_")
	cleaned = string.gsub(cleaned, "%.%.+", "_")
	cleaned = string.sub(cleaned, 1, 80)
	if cleaned == "" or cleaned == "." then
		return "unnamed"
	end
	return cleaned
end

function Env.Clipboard(text)
	if not Env.setClipboard then
		return false
	end
	return (pcall(Env.setClipboard, tostring(text)))
end

function Env.Exists(path)
	if not Env.isfile then
		return false
	end
	local ok, exists = pcall(Env.isfile, path)
	return ok and exists == true
end

function Env.FolderExists(path)
	if not Env.isfolder then
		return false
	end
	local ok, exists = pcall(Env.isfolder, path)
	return ok and exists == true
end

-- Creates every segment of `path` (absolute or relative) that does not exist yet.
function Env.EnsureFolder(path)
	if not (Env.isfolder and Env.makefolder) then
		return false
	end
	local built = string.sub(path, 1, 1) == "/" and "" or nil
	local ok = pcall(function()
		for part in string.gmatch(path, "[^/]+") do
			built = (built == nil) and part or (built .. "/" .. part)
			if not Env.isfolder(built) then
				Env.makefolder(built)
			end
		end
	end)
	return ok and Env.FolderExists(path)
end

function Env.Write(path, contents)
	if not Env.writefile then
		return false
	end
	local folder = string.match(path, "^(.*)/[^/]+$")
	if folder and folder ~= "" and not Env.FolderExists(folder) then
		Env.EnsureFolder(folder)
	end
	return (pcall(Env.writefile, path, contents))
end

function Env.Read(path)
	if not (Env.readfile and Env.isfile) then
		return nil
	end
	if not Env.Exists(path) then
		return nil
	end
	local ok, contents = pcall(Env.readfile, path)
	if ok and type(contents) == "string" then
		return contents
	end
	return nil
end

function Env.Delete(path)
	if not Env.delfile then
		return false
	end
	return (pcall(Env.delfile, path))
end

-- Files directly inside `folder` (full paths as reported by the executor).
function Env.List(folder)
	if not Env.listfiles then
		return {}
	end
	local ok, files = pcall(Env.listfiles, folder)
	if ok and type(files) == "table" then
		return files
	end
	return {}
end

-- GET request through the executor. Returns body or nil, reason.
function Env.HttpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" then
		return body
	end
	if Env.httpRequest then
		local okRequest, response = pcall(Env.httpRequest, { Url = url, Method = "GET" })
		if okRequest and type(response) == "table" and type(response.Body) == "string" and (response.StatusCode == nil or response.StatusCode == 200) then
			return response.Body
		end
	end
	return nil, "request failed"
end

function Env.Describe()
	return {
		Executor = Env.Name .. (Env.Version ~= "" and (" " .. Env.Version) or ""),
		Files = Env.HasFiles(),
		HiddenGui = Env.gethui ~= nil,
		CustomAsset = Env.getCustomAsset ~= nil,
		Clipboard = Env.setClipboard ~= nil,
		Http = Env.httpRequest ~= nil,
	}
end

return Env
end

Modules["Core/Input"] = function(import)
local Services = import("Core/Services")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

local UIS = Services.UserInputService
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

-- Touch calibration (preserved from DeaUI) ----------------------------------------------------
-- InputObject.Position of a touch lives in a space that may or may not include the top bar inset,
-- depending on the ScreenGui and the client. Guessing the inset shifted pickers on phones, so the
-- offset is learned: every touch that starts on one of our GuiObjects must lie inside its rectangle,
-- and each touch narrows the range of possible offsets.
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
		return (lo + hi) / 2
	end
	return Util.clamp(guess, lo, hi)
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
		calib.loX, calib.hiX, calib.loY, calib.hiY = loX, hiX, loY, hiY
	else
		calib.loX, calib.hiX, calib.loY, calib.hiY = nloX, nhiX, nloY, nhiY
	end
end

-- Call when an interaction starts on `gui`: learns from it and freezes the offset for the gesture.
function Input.Begin(gui, input)
	if not input or input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	Input.Learn(gui, input)
	offsets[input] = estimate(input)
end

-- Pointer position in screen pixels (mouse or touch).
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

function Input.Typing()
	return UIS:GetFocusedTextBox() ~= nil
end

-- Touch-only device (phones, tablets). Hybrid devices with a mouse count as desktop.
function Input.Touch()
	return UIS.TouchEnabled == true and UIS.MouseEnabled ~= true
end

function Input.Platform()
	return {
		Touch = UIS.TouchEnabled == true,
		Mouse = UIS.MouseEnabled == true,
		Keyboard = UIS.KeyboardEnabled == true,
		TouchOnly = Input.Touch(),
	}
end

function Input.Inside(gui, point)
	point = point or UIS:GetMouseLocation()
	local position, size = gui.AbsolutePosition, gui.AbsoluteSize
	return point.X >= position.X and point.Y >= position.Y and point.X <= position.X + size.X and point.Y <= position.Y + size.Y
end

-- Right click or long press. Returns an object with Disconnect/Clean.
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

-- Pointer drag on `handle` with callbacks Begin(point), Move(delta, point), End().
-- Only the pointer that started on the handle is followed, so scrolling a ScrollingFrame that
-- merely contains the handle never starts a drag.
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
		if link then
			link:Disconnect()
		end
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
	return {
		Disconnect = function()
			began:Disconnect()
			endedGlobal:Disconnect()
			stop()
		end,
		Clean = function()
			began:Disconnect()
			endedGlobal:Disconnect()
			stop()
		end,
	}
end

Input.Shortcut = Signal.new()

return Input
end

Modules["Core/Scope"] = function(import)
-- Cleanup scope: everything added is released (in reverse order) by Clean()/Destroy().
local Scope = {}
Scope.__index = Scope

function Scope.new()
	return setmetatable({ _items = {}, Cleaned = false }, Scope)
end

function Scope:Add(item)
	if item ~= nil then
		self._items[#self._items + 1] = item
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

function Scope:Remove(item)
	for index = #self._items, 1, -1 do
		if self._items[index] == item then
			table.remove(self._items, index)
			return true
		end
	end
	return false
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

function Scope:Count()
	return #self._items
end

return Scope
end

Modules["Core/Services"] = function(import)
local Env = import("Core/Env")

local Services = {}

return setmetatable(Services, {
	__index = function(self, name)
		local ok, service = pcall(game.GetService, game, name)
		if (not ok or service == nil) and game.FindService then
			ok, service = pcall(game.FindService, game, name)
		end
		if not ok or service == nil then
			return nil
		end
		service = Env.Ref(service)
		rawset(self, name, service)
		return service
	end,
})
end

Modules["Core/Signal"] = function(import)
local Util = import("Core/Util")

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
	local index = Util.find(list, self)
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
	self._links[#self._links + 1] = link
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

-- Asynchronous: every callback runs in its own thread, so one error never stops the others.
function Signal:Fire(...)
	local snapshot = Util.clone(self._links)
	for _, link in ipairs(snapshot) do
		if link.Connected then
			task.spawn(link._callback, ...)
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
	for _, link in ipairs(Util.clone(self._links)) do
		link:Disconnect()
	end
end
Signal.Destroy = Signal.Clear

function Signal:Count()
	return #self._links
end

return Signal
end

Modules["Core/Util"] = function(import)
local Util = {}

function Util.clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

function Util.round(value, step)
	step = step or 1
	if step <= 0 then
		return value
	end
	local snapped = math.floor(value / step + 0.5) * step
	-- remove float noise such as 0.30000000000000004
	return tonumber(string.format("%.10g", snapped)) or snapped
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

function Util.find(list, value)
	for index = 1, #list do
		if list[index] == value then
			return index
		end
	end
	return nil
end

function Util.clone(source)
	local out = {}
	for key, value in pairs(source) do
		out[key] = value
	end
	return out
end

-- Deep copy of plain data tables (Instances and userdata are copied by reference).
function Util.deepClone(source, seen)
	if type(source) ~= "table" then
		return source
	end
	seen = seen or {}
	if seen[source] then
		return seen[source]
	end
	local out = {}
	seen[source] = out
	for key, value in pairs(source) do
		out[key] = Util.deepClone(value, seen)
	end
	return out
end

function Util.merge(base, over)
	local out = Util.clone(base or {})
	for key, value in pairs(over or {}) do
		out[key] = value
	end
	return out
end

function Util.sortedKeys(source)
	local keys = {}
	for key in pairs(source) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

function Util.split(text, separator)
	local out = {}
	separator = separator or ","
	local start = 1
	while true do
		local from, to = string.find(text, separator, start, true)
		if not from then
			out[#out + 1] = string.sub(text, start)
			break
		end
		out[#out + 1] = string.sub(text, start, from - 1)
		start = to + 1
	end
	return out
end

function Util.trim(text)
	return (string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1"))
end

function Util.Lines(text)
	local lines = {}
	text = string.gsub(text, "\r\n", "\n")
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		lines[#lines + 1] = line
	end
	return lines
end

-- UTF-8 aware truncation ("Rất dài..." keeps whole characters).
function Util.Truncate(text, limit, tail)
	text = tostring(text or "")
	tail = tail or "..."
	local ok, length = pcall(utf8.len, text)
	if not ok or not length then
		return string.sub(text, 1, limit)
	end
	if length <= limit then
		return text
	end
	local cut = utf8.offset(text, limit + 1)
	return string.sub(text, 1, (cut or #text + 1) - 1) .. tail
end

function Util.Hex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

-- "#RRGGBB", "RRGGBB" or "#RGB" -> Color3 (nil when invalid)
function Util.FromHex(text)
	if type(text) ~= "string" then
		return nil
	end
	text = string.gsub(Util.trim(text), "^#", "")
	if #text == 3 then
		text = string.gsub(text, ".", "%0%0")
	end
	if not string.match(text, "^%x%x%x%x%x%x$") then
		return nil
	end
	return Color3.fromRGB(tonumber(string.sub(text, 1, 2), 16), tonumber(string.sub(text, 3, 4), 16), tonumber(string.sub(text, 5, 6), 16))
end

-- Stable 64-bit-ish hash for cache file names (arithmetic only, no bit operators).
function Util.hash(text)
	text = tostring(text)
	local a, b = 5381, 52711
	for index = 1, #text do
		local byte = string.byte(text, index)
		a = (a * 33 + byte) % 4294967296
		b = (b * 31 + byte * 7 + index) % 4294967296
	end
	return string.format("%08x%08x", a, b)
end

function Util.Debounce(seconds, callback)
	local scheduled = false
	local args
	return function(...)
		args = table.pack(...)
		if scheduled then
			return
		end
		scheduled = true
		task.delay(seconds, function()
			scheduled = false
			callback(table.unpack(args, 1, args.n))
		end)
	end
end

-- Lower case without diacritics ("Tiền Vàng" -> "tien vang"), so Vietnamese can be searched without accents.
local FOLD = {}
do
	local groups = {
		a = "àáạảãâầấậẩẫăằắặẳẵ", e = "èéẹẻẽêềếệểễ", i = "ìíịỉĩ", o = "òóọỏõôồốộổỗơờớợởỡ", u = "ùúụủũưừứựửữ", y = "ỳýỵỷỹ", d = "đ",
	}
	for base, letters in pairs(groups) do
		for _, code in utf8.codes(letters) do
			FOLD[utf8.char(code)] = base
		end
	end
	local upper = {
		A = "ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ", E = "ÈÉẸẺẼÊỀẾỆỂỄ", I = "ÌÍỊỈĨ", O = "ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ", U = "ÙÚỤỦŨƯỪỨỰỬỮ", Y = "ỲÝỴỶỸ", D = "Đ",
	}
	for base, letters in pairs(upper) do
		for _, code in utf8.codes(letters) do
			FOLD[utf8.char(code)] = string.lower(base)
		end
	end
end

function Util.Fold(text)
	text = tostring(text or "")
	local ok, result = pcall(function()
		local out = {}
		for _, code in utf8.codes(text) do
			local char = utf8.char(code)
			out[#out + 1] = FOLD[char] or string.lower(char)
		end
		return table.concat(out)
	end)
	return ok and result or string.lower(text)
end

Util.Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(text)
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

-- 1234567 -> "1,234,567"
function Util.Format.Number(value)
	if type(value) ~= "number" or value ~= value then
		return tostring(value)
	end
	if math.abs(value) >= 1e15 then
		return string.format("%.2e", value)
	end
	local negative = value < 0
	local whole = string.format("%d", math.floor(math.abs(value) + 0.5))
	local out = string.reverse((string.gsub(string.reverse(whole), "(%d%d%d)", "%1,")))
	out = string.gsub(out, "^,", "")
	return (negative and "-" or "") .. out
end

-- 1234567 -> "1.23M" (simulator style suffixes)
function Util.Format.Compact(value, decimals)
	if type(value) ~= "number" or value ~= value then
		return tostring(value)
	end
	decimals = decimals or 2
	local sign = value < 0 and "-" or ""
	value = math.abs(value)
	if value < 1000 then
		if value == math.floor(value) then
			return sign .. string.format("%d", value)
		end
		return sign .. trimZeros(string.format("%." .. decimals .. "f", value))
	end
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value = value / 1000
		index = index + 1
	end
	if value >= 1000 then
		return sign .. string.format("%.2e", value * 1000 ^ (index - 1))
	end
	return sign .. trimZeros(string.format("%." .. decimals .. "f", value)) .. SUFFIXES[index]
end

function Util.Format.Percent(fraction, decimals)
	return trimZeros(string.format("%." .. (decimals or 0) .. "f", fraction * 100)) .. "%"
end

-- seconds -> "01:05" / "1:02:03" (clock) or "1h 02m 03s" (words)
function Util.Format.Time(seconds, style)
	seconds = math.max(0, math.floor((seconds or 0) + 0.5))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if style == "words" then
		if h > 0 then
			return string.format("%dh %02dm %02ds", h, m, s)
		elseif m > 0 then
			return string.format("%dm %02ds", m, s)
		end
		return string.format("%ds", s)
	end
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%02d:%02d", m, s)
end

-- Applies a Format name or function to a value.
function Util.Format.Apply(format, value)
	if type(format) == "function" then
		local ok, text = pcall(format, value)
		return ok and tostring(text) or tostring(value)
	end
	if type(value) ~= "number" then
		return tostring(value)
	end
	if format == "number" then
		return Util.Format.Number(value)
	elseif format == "percent" then
		return Util.Format.Percent(value)
	elseif format == "time" then
		return Util.Format.Time(value)
	elseif format == "raw" then
		return trimZeros(string.format("%.4f", value))
	end
	return Util.Format.Compact(value)
end

return Util
end

Modules["Library"] = function(import)
local Env = import("Core/Env")
local Signal = import("Core/Signal")
local Scope = import("Core/Scope")
local Util = import("Core/Util")
local Services = import("Core/Services")
local Input = import("Core/Input")
local Loc = import("Localization")
import("Localization/Strings")
local Theme = import("Theme/Theme")
local Icons = import("Theme/Icons")
local Anim = import("Animation")
local Persistence = import("Storage/Persistence")
local AutoLoad = import("Storage/AutoLoad")
local Config = import("Storage/Config")
local Root = import("UI/Root")
local Create = import("UI/Create")
local Kit = import("UI/Kit")
local Popup = import("UI/Popup")
local Tooltip = import("UI/Tooltip")
local Keys = import("UI/Keybinds")
local Notification = import("UI/Notification")
local Dialog = import("UI/Dialog")
local WindowModule = import("UI/Window")
local HUD = import("UI/HUD")
local Loader = import("UI/Loader")
local Assets = import("UI/Assets")
import("UI/Blocks")
import("UI/SettingsPage")

--[[
	DeaUI-S public API. Every function works both as UI.Name(...) and UI:Name(...).
	  Init, Destroy, CreateWindow, Notify, Confirm, Prompt, Dialog, Loader, HUD,
	  SetLanguage / GetLanguage / AddTranslations / Define / T,
	  SetTheme / OverrideTheme / ResetTheme / SaveTheme / LoadTheme / ListThemes / DeleteTheme,
	  SetScale / ConfigureAnimations,
	  SaveConfig / LoadConfig / ListConfigs / DeleteConfig / SetAutoLoad / ClearAutoLoad / LoadAutoConfig,
	  SetVip / GetFlag / SetFlag / Capabilities
]]
local VERSION = "1.0.0"
local HANDLE = "__DeaUI_S"

local Library = {
	Version = VERSION,
	Ready = false,
	Flags = Config.Flags,
	Windows = {},
	OnAutoLoad = Signal.new(),
	-- modules (advanced use)
	Localization = Loc, Theme = Theme, Icons = Icons, Animation = Anim, Storage = Persistence, Config = Config,
	AutoLoad = AutoLoad, Assets = Assets, Keys = Keys, Util = Util, Env = Env,
}

local scope
local general, language, appearance
local locks = {}
local vipActive = false
local pendingNotices = {}
local noticeLink

local function export(name, fn)
	Library[name] = function(first, ...)
		if rawequal(first, Library) then
			return fn(...)
		end
		return fn(first, ...)
	end
end

local function requireReady(name)
	if not Library.Ready then
		error("[DeaUI-S] call Init() before " .. name .. "()", 3)
	end
end

-- Persistence -----------------------------------------------------------------------------------------------------------
local function saveAppearance(chosen)
	if not appearance then
		return
	end
	local theme = Theme.Serialize()
	local data = appearance.Data
	data.Theme, data.Colors, data.Radius, data.Spacing = theme.Base, theme.Colors, theme.Radius, theme.Spacing
	data.AnimationEnabled = Anim.Settings.AnimationEnabled
	data.AnimationSpeed = Anim.Settings.AnimationSpeed
	data.ReducedMotion = Anim.Settings.ReducedMotion
	data.Scale = Root.Scale
	if chosen then
		data.Chosen = true
	end
	appearance:Save()
end

local function noticeFor(kind, relative)
	local map = { corrupt = { "error.config_corrupt", "warn" }, write = { "error.save_failed", "error" }, recovered = { "error.config_recovered", "info" }, encode = { "error.save_failed", "error" } }
	local entry = map[kind]
	if entry then
		pendingNotices[#pendingNotices + 1] = { Title = entry[1], Message = relative, Kind = entry[2], Duration = 5 }
	end
end

local function flushNotices()
	if not Root.Ready then
		return
	end
	local list = pendingNotices
	pendingNotices = {}
	for _, notice in ipairs(list) do
		Notification.Show(notice)
	end
end

-- Locks (VIP / locked rows) ---------------------------------------------------------------------------------------------
local function refreshLock(entry)
	local locked = entry.Kind == "locked" or not vipActive
	entry.Row.Locked = locked
	entry.Overlay.Visible = locked
end

function Library._lock(control, row, o)
	local kind = o.Vip and "vip" or "locked"
	local overlay = Create.New("TextButton", { Name = "LockMask", Size = UDim2.fromScale(1, 1), Text = "", Active = true, BackgroundTransparency = 0.4, ZIndex = 30, Bind = { BackgroundColor3 = "Surface" }, Parent = row.Frame })
	local badge = Kit.Badge(overlay, { Text = kind == "vip" and "common.vip" or "common.locked", Kind = kind == "vip" and "warn" or "muted", Icon = kind == "vip" and "crown" or "lock", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), ZIndex = 31 })
	badge.Frame.ZIndex = 31
	local entry = { Control = control, Row = row, Overlay = overlay, Kind = kind }
	overlay.Activated:Connect(function()
		if kind == "vip" then
			Library.RequestVip(control)
		else
			Notification.Show({ Title = "common.locked", Message = o.LockedText or "world.locked", Kind = "warn", Duration = 2.5 })
		end
	end)
	locks[#locks + 1] = entry
	refreshLock(entry)
	control.Lock = {
		Remove = function()
			for index, other in ipairs(locks) do
				if other == entry then
					table.remove(locks, index)
					break
				end
			end
		end,
	}
end

export("SetVip", function(active)
	vipActive = active == true
	for _, entry in ipairs(locks) do
		refreshLock(entry)
	end
end)

export("IsVip", function()
	return vipActive
end)

export("RequestVip", function(control)
	local handler = Library.Options and Library.Options.OnVipRequest
	if handler then
		Kit.Safe(handler)(control)
	else
		Notification.Show({ Title = "common.vip", Message = "common.vip_required", Kind = "warn", Duration = 3 })
	end
end)

-- Window plumbing ---------------------------------------------------------------------------------------------------------
function Library._windowDestroyed(window)
	for index, other in ipairs(Library.Windows) do
		if other == window then
			table.remove(Library.Windows, index)
			break
		end
	end
end

function Library._toggleKeyChanged(key)
	if general and key then
		general:Set("ToggleKey", key.Name)
	end
end

export("CreateWindow", function(options)
	requireReady("CreateWindow")
	options = options or {}
	if options.ToggleKey == nil then
		local saved = general and general.Data.ToggleKey
		if type(saved) == "string" and saved ~= "" then
			local ok, key = pcall(function()
				return Enum.KeyCode[saved]
			end)
			if ok and key then
				options.ToggleKey = key
			end
		elseif Library.Options and Library.Options.ToggleKey then
			options.ToggleKey = Library.Options.ToggleKey
		end
	end
	local window = WindowModule.Create(Library, options)
	table.insert(Library.Windows, window)
	return window
end)

-- Overlays -------------------------------------------------------------------------------------------------------------------
local function isOptions(value)
	return type(value) == "table" and (value.Title ~= nil or value.Message ~= nil or value.Kind ~= nil or value.Duration ~= nil or value.Actions ~= nil or value.Text ~= nil)
end

export("Notify", function(a, b, c, d)
	requireReady("Notify")
	local options = a
	if not isOptions(a) then
		options = { Title = a, Message = b, Kind = c, Duration = d }
	end
	return Notification.Show(options)
end)

export("ClearNotifications", function()
	Notification.Clear()
end)

export("Confirm", function(a, b)
	requireReady("Confirm")
	local options = a
	if not (type(a) == "table" and (a.Title ~= nil or a.Message ~= nil or a.Yes ~= nil)) then
		options = { Title = a, Message = b }
	end
	return Dialog.Confirm(options)
end)

export("Prompt", function(a, b, c)
	requireReady("Prompt")
	local options = a
	if not (type(a) == "table" and (a.Title ~= nil or a.Message ~= nil or a.Placeholder ~= nil)) then
		options = { Title = a, Message = b, Default = c }
	end
	return Dialog.Prompt(options)
end)

export("Dialog", function(options)
	requireReady("Dialog")
	return Dialog.Show(options)
end)

export("Loader", function(options)
	requireReady("Loader")
	return Loader.Show(options)
end)

export("HUD", function(options)
	requireReady("HUD")
	return HUD.Get(options)
end)

-- Localization ---------------------------------------------------------------------------------------------------------------------
export("SetLanguage", function(code)
	return Loc.Set(code)
end)
export("GetLanguage", function()
	return Loc.Get()
end)
export("ToggleLanguage", function()
	return Loc.Toggle()
end)
export("AddTranslations", function(code, map)
	Loc.AddTranslations(code, map)
end)
Library.AddPhrases = Library.AddTranslations
export("Define", function(key, entry)
	Loc.Define(key, entry)
end)
export("T", function(source, ...)
	return Loc.Resolve(source, ...)
end)

-- Theme ------------------------------------------------------------------------------------------------------------------------------
export("SetTheme", function(name)
	return Theme.Set(name)
end)
export("GetTheme", function()
	return Theme.Get()
end)
export("OverrideTheme", function(map)
	return Theme.Override(map)
end)
export("ResetTheme", function()
	Theme.Reset()
end)
export("Themes", function()
	return Theme.Names()
end)

local function themeFile(name)
	return "Themes/Custom/" .. Env.SafeName(name) .. ".json"
end

export("SaveTheme", function(name)
	if type(name) ~= "string" or Util.trim(name) == "" then
		return false
	end
	return Persistence.WriteJson(themeFile(name), Theme.Serialize())
end)

export("LoadTheme", function(name)
	local data = Persistence.ReadJson(themeFile(name))
	if not data then
		return false
	end
	return Theme.Load(data)
end)

export("ListThemes", function()
	return Persistence.List("Themes/Custom")
end)

export("DeleteTheme", function(name)
	return Persistence.Delete(themeFile(name))
end)

-- Interface scale / animation -------------------------------------------------------------------------------------------------
export("SetScale", function(scale)
	Root.SetScale(scale)
	saveAppearance(true)
end)
export("GetScale", function()
	return Root.Scale
end)
export("ConfigureAnimations", function(map)
	Anim.Configure(map)
	saveAppearance(true)
end)

-- Configurations / AutoLoad ---------------------------------------------------------------------------------------------------
export("SaveConfig", function(name)
	return Config.Save(name)
end)
export("LoadConfig", function(name, options)
	options = options or {}
	return Config.Load(name, { Silent = options.Silent, Restore = options.Restore or { Language = true, Theme = true, HUD = true, Layout = true } })
end)
export("ListConfigs", function()
	return Config.List()
end)
export("DeleteConfig", function(name)
	return Config.Delete(name)
end)
export("SetAutoLoad", function(name, restore)
	return AutoLoad.Set(name, restore)
end)
export("ClearAutoLoad", function()
	return AutoLoad.Clear()
end)
export("GetAutoLoad", function()
	return AutoLoad.Get()
end)
export("LoadAutoConfig", function()
	return Config.ApplyPending()
end)
export("GetFlag", function(flag)
	local control = Config.Flags[flag]
	return control and control:Get() or nil
end)
export("SetFlag", function(flag, value, silent)
	local control = Config.Flags[flag]
	if control then
		control:Set(value, silent)
		return true
	end
	return false
end)

export("Capabilities", function()
	local info = Env.Describe()
	local storage = Persistence.Describe()
	info.Storage = storage.Available
	info.Root = storage.Root
	info.AbsoluteRoot = storage.AbsoluteRoot
	return info
end)

-- DeaUI compatibility wrappers ------------------------------------------------------------------------------------------------
local destroyCallbacks = {}

export("OnDestroy", function(callback)
	if type(callback) == "function" then
		destroyCallbacks[#destroyCallbacks + 1] = callback
	end
end)
export("GetFlags", function()
	return Config.Flags
end)
export("GetLanguages", function()
	return Util.clone(Loc.Languages)
end)
export("GetThemes", function()
	return Theme.Names()
end)
export("SetAccent", function(color)
	return Theme.Override({ Primary = color, Accent = color })
end)
export("SetAnimations", function(enabled)
	Anim.Configure({ AnimationEnabled = enabled ~= false })
	saveAppearance(true)
end)
export("SetToggleKey", function(key)
	for _, window in ipairs(Library.Windows) do
		window:SetToggleKey(key)
	end
end)
export("RegisterIcon", function(name, id)
	Icons.Register(name, id)
end)
export("Path", function(...)
	return Env.Path(...)
end)
export("SetVisible", function(visible)
	if Root.Ready then
		Root.SetVisible(visible ~= false)
	end
end)
export("IsVisible", function()
	for _, window in ipairs(Library.Windows) do
		if window:IsVisible() then
			return true
		end
	end
	return false
end)

-- ThemeEditor now lives in the Appearance group of the settings page: this opens it.
export("ThemeEditor", function()
	for _, window in ipairs(Library.Windows) do
		local page = window.Pages.settings
		if page then
			window:Show()
			window:SelectPage("settings")
			return page
		end
	end
	Notification.Show({ Title = "settings.appearance", Message = "window.search_hint", Kind = "info" })
	return nil
end)

-- ContextMenu({ Items = { { Text, Icon, Callback, Danger, Disabled } | { Divider = true } }, Position = Vector2 (screen), Anchor = GuiObject, Width })
export("ContextMenu", function(options)
	requireReady("ContextMenu")
	options = options or {}
	local items = options.Items or {}
	local rowHeight = Kit.Control() + 2
	local popupOptions = {
		Width = options.Width or 200, MaxHeight = 320,
		Build = function(frame, close)
			local scroll = Kit.Scroll(frame, { Size = UDim2.fromScale(1, 1) })
			Create.Pad(scroll, 6)
			Create.List(scroll, { Padding = 2 })
			local height = 12
			for index, item in ipairs(items) do
				if item.Divider then
					local line = Kit.Divider(scroll, { Order = index })
					line.Size = UDim2.new(1, 0, 0, 1)
					height = height + 5
				else
					height = height + rowHeight + 2
					local row = Create.New("TextButton", { Name = "MenuItem", Size = UDim2.new(1, 0, 0, rowHeight), Text = "", LayoutOrder = index, BackgroundTransparency = 1, Bind = { BackgroundColor3 = "SurfaceHover" }, Parent = scroll })
					Create.Corner(row, "sm")
					local token = item.Danger and "Danger" or (item.Disabled and "Disabled" or "Text")
					Kit.Icon(row, item.Icon, 16, token, { Position = UDim2.new(0, 10, 0.5, -8) })
					Kit.Text(row, { Text = item.Text, Size = 13, Color = token, Position = UDim2.fromOffset(item.Icon and 34 or 12, 0), SizeUDim = UDim2.new(1, -46, 1, 0) })
					Kit.Pressable(row, function(state)
						row.BackgroundTransparency = (state.Hover or state.Down) and not item.Disabled and 0.3 or 1
					end)
					row.Activated:Connect(function()
						if item.Disabled then
							return
						end
						close()
						if item.Callback then
							Kit.Safe(item.Callback)(item)
						end
					end)
				end
			end
			return height
		end,
	}
	if options.Anchor then
		popupOptions.Anchor = options.Anchor
	else
		popupOptions.Origin = Root.ToLocal(options.Position or Services.UserInputService:GetMouseLocation())
		popupOptions.Extent = Vector2.new(0, 0)
	end
	return Popup.Open(popupOptions)
end)

-- Right click / long press on `gui` opens a context menu; items may be a function returning the list.
export("AttachContextMenu", function(gui, items)
	return Input.Secondary(gui, function(point)
		Library.ContextMenu({ Items = type(items) == "function" and items() or items, Position = point })
	end)
end)

-- Watermark(options) -> mark: the DeaUI watermark now is the Mini HUD (AddUser / AddFPS / AddPing / AddTime / AddText / SetVisible)
export("Watermark", function(options)
	requireReady("Watermark")
	options = options or {}
	local hud = HUD.Get({ Builtin = { FPS = false, Ping = false, Time = false } })
	local mark = { HUD = hud, Count = 0 }
	function mark:AddUser()
		local name = "Player"
		pcall(function()
			name = Services.Players.LocalPlayer.DisplayName
		end)
		hud:AddMetric({ Id = "user", Icon = "user", Value = name, Kind = "accent" })
		return self
	end
	function mark:AddFPS()
		hud:SetBuiltin("FPS", true)
		return self
	end
	function mark:AddPing()
		hud:SetBuiltin("Ping", true)
		return self
	end
	function mark:AddTime()
		hud:SetBuiltin("Time", true)
		return self
	end
	function mark:AddText(spec)
		spec = type(spec) == "table" and (spec.Text ~= nil or spec.Icon ~= nil) and spec or { Text = spec }
		self.Count = self.Count + 1
		local id = "text" .. self.Count
		hud:AddMetric({ Id = id, Icon = spec.Icon, Value = spec.Text or "", Kind = spec.Kind or "muted" })
		local entry = {}
		function entry:SetText(text)
			hud:SetMetric(id, text)
		end
		function entry:SetVisible(visible)
			local metric = hud.Metrics[id]
			if metric then
				metric.Cell.Visible = visible ~= false
			end
		end
		function entry:Destroy()
			hud:RemoveMetric(id)
		end
		return entry
	end
	function mark:SetVisible(visible)
		hud:SetVisible(visible)
	end
	function mark:Destroy()
		hud:Destroy()
	end
	if options.Corner then
		task.delay(0.15, function()
			if hud.Destroyed or next(hud.Doc.Data.Position or {}) ~= nil then
				return
			end
			local size = Vector2.new(hud.Frame.AbsoluteSize.X, hud.Frame.AbsoluteSize.Y) / Root.Scale
			local screen, insets = Root.ScreenSize(), Root.Insets()
			local corner = tostring(options.Corner)
			local x = string.find(corner, "Right") and (screen.X - insets.Right - size.X - 12) or (insets.Left + 12)
			local y = string.find(corner, "Bottom") and (screen.Y - insets.Bottom - size.Y - 12) or (insets.Top + 10)
			hud:SetPosition(x, y)
		end)
	end
	return mark
end)

-- Init / Destroy ------------------------------------------------------------------------------------------------------------------
local function applyLayoutSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	local doc = Library.LayoutDoc
	if doc then
		doc.Data.Windows = Util.deepClone(snapshot)
		doc:Save()
	end
	for _, window in ipairs(Library.Windows) do
		local saved = snapshot[window.Id]
		if type(saved) == "table" and type(saved.W) == "number" and type(saved.H) == "number" and type(saved.X) == "number" and type(saved.Y) == "number" then
			window.Size = Vector2.new(saved.W, saved.H)
			window.Position = Vector2.new(saved.X, saved.Y)
			window:_applyLayout(true)
		end
	end
end

function Library.Destroy()
	if not Library.Ready and not scope then
		return
	end
	for _, callback in ipairs(destroyCallbacks) do
		pcall(callback)
	end
	destroyCallbacks = {}
	for _, window in ipairs(Util.clone(Library.Windows)) do
		pcall(window.Destroy, window)
	end
	Library.Windows = {}
	pcall(Popup.Close, true)
	pcall(Dialog.Destroy)
	pcall(Notification.Destroy)
	pcall(Loader.Destroy)
	pcall(HUD.Destroy)
	pcall(Tooltip.Destroy)
	pcall(Assets.StopPreviews)
	pcall(Kit.StopSpinners)
	pcall(Kit.StopTickers)
	pcall(Anim.Cleanup)
	pcall(Keys.Clear)
	pcall(Config.Clear)
	pcall(Persistence.Flush)
	if noticeLink then
		noticeLink:Disconnect()
		noticeLink = nil
	end
	if scope then
		scope:Clean()
		scope = nil
	end
	locks, pendingNotices = {}, {}
	Loc.SaveHook, Theme.SaveHook = nil, nil
	Library.Ready = false
	if Env.Global[HANDLE] and Env.Global[HANDLE].Owner == Library then
		Env.Global[HANDLE] = nil
	end
end

-- options: Language ("en" | "vi"), ForceLanguage, Theme, ThemeOverrides, Persist (default true), Scale, Animations (bool), ToggleKey, ModelPreviews (default true),
--          AutoLoad (default true), AutoLoadCallbacks (default false), Unique (default true), OnVipRequest(control), Vip
function Library.Init(first, second)
	local options = first
	if rawequal(first, Library) then
		options = second
	end
	options = type(options) == "table" and options or {}
	local previous = Env.Global[HANDLE]
	if options.Unique ~= false and type(previous) == "table" and type(previous.Destroy) == "function" then
		pcall(previous.Destroy)
	end
	if Library.Ready then
		Library.Destroy()
	end
	Library.Options = options
	Assets.Enabled3D = options.ModelPreviews ~= false
	scope = Scope.new()
	Persistence.Reset()

	Library.Persisted = Persistence.Init(options)
	noticeLink = Persistence.Errors:Connect(noticeFor)
	general = Persistence.Document(Persistence.Files.General, { Version = 1, ToggleKey = "", LauncherPos = {} })
	language = Persistence.Document(Persistence.Files.Language, { Language = "", Chosen = false })
	appearance = Persistence.Document(Persistence.Files.Appearance, {
		Theme = "Midnight", Colors = {}, Radius = 10, Spacing = 8, AnimationEnabled = true, AnimationSpeed = 1, ReducedMotion = false, Scale = 1, Chosen = false,
	})
	Library.GeneralDoc = general
	Library.LayoutDoc = Persistence.Document(Persistence.Files.Layout, { Windows = {}, Collapsed = {} })

	-- language: saved user choice > Init option > Roblox locale (ForceLanguage makes the option win)
	local code
	if options.ForceLanguage and Loc.IsValid(options.Language) then
		code = options.Language
	elseif language.Data.Chosen and Loc.IsValid(language.Data.Language) then
		code = language.Data.Language
	elseif Loc.IsValid(options.Language) then
		code = options.Language
	else
		code = Loc.Detect()
	end
	Loc.Init(code)
	Loc.SaveHook = function(newCode)
		language.Data.Language = newCode
		language.Data.Chosen = true
		language:Save()
	end

	-- theme and animation
	local data = appearance.Data
	if data.Chosen and Theme.Presets[data.Theme] then
		Theme.Load({ Base = data.Theme, Colors = data.Colors, Radius = data.Radius, Spacing = data.Spacing }, true)
	else
		Theme.Set(options.Theme or "Midnight", true)
		if type(options.ThemeOverrides) == "table" then
			Theme.Override(options.ThemeOverrides, true)
		end
	end
	if data.Chosen then
		Anim.Configure({ AnimationEnabled = data.AnimationEnabled, AnimationSpeed = data.AnimationSpeed, ReducedMotion = data.ReducedMotion or Anim.Settings.ReducedMotion })
	end
	if options.Animations ~= nil then
		Anim.Configure({ AnimationEnabled = options.Animations == true })
	end
	Theme.SaveHook = function()
		saveAppearance(true)
	end

	Root.Scale = Util.clamp(tonumber((data.Chosen and data.Scale) or options.Scale or 1) or 1, 0.7, 1.5)
	Root.Init(scope)
	Keys.Start(scope)
	vipActive = options.Vip == true

	-- configuration providers (UI preferences stored inside configurations)
	Config.Providers.Language = { Get = Loc.Get, Set = function(value)
		Loc.Set(value)
	end }
	Config.Providers.Theme = { Get = Theme.Serialize, Set = function(value)
		Theme.Load(value)
	end }
	Config.Providers.HUD = { Get = HUD.Snapshot, Set = HUD.Restore }
	Config.Providers.Layout = { Get = function()
		return Util.deepClone(Library.LayoutDoc.Data.Windows)
	end, Set = applyLayoutSnapshot }

	-- AutoLoad: restore UI preferences now, control values when their controls are created
	local auto = AutoLoad.Reload() and AutoLoad.Get()
	Library.AutoLoadInfo = nil
	if options.AutoLoad ~= false and auto and auto.Enabled then
		local saved = Config.Read(auto.Config)
		if saved then
			Config.Apply(saved, { Silent = options.AutoLoadCallbacks ~= true, Restore = auto.Restore, Defer = true })
			Library.AutoLoadInfo = { Config = auto.Config, Values = Util.deepClone(saved.Flags) }
		end
	end

	Library.Ready = true
	Env.Global[HANDLE] = { Destroy = Library.Destroy, Version = VERSION, Owner = Library }
	task.defer(function()
		if Library.Ready then
			flushNotices()
			if Library.AutoLoadInfo then
				Library.OnAutoLoad:Fire(Library.AutoLoadInfo)
			end
		end
	end)
	return Library
end

return Library
end

Modules["Localization"] = function(import)
local Signal = import("Core/Signal")
local Services = import("Core/Services")

--[[
	Two languages ship with the library: "en" (English) and "vi" (Tieng Viet). More can be added
	with Localization.AddLanguage. Any text given to the library can be

	  - a plain string                      "Enabled"        shown as written, unless it is a key
	                                                          (library keys such as "common.cancel" or
	                                                          keys registered with Define/AddTranslations)
	  - a table per language                { en = "Enabled", vi = "Bat" }
	  - a function(language) -> string      function(l) return l == "vi" and "Bat" or "On" end

	Developer text is never translated automatically: only explicit tables, functions, keys and
	dictionaries are resolved. Built-in text lives in Localization/Strings and uses namespaced keys.
	Labels created through the library are bound to their source, so changing the language updates
	them live.
]]
local Loc = {
	Changed = Signal.new(),
	Languages = {
		{ Code = "en", Name = "English" },
		{ Code = "vi", Name = "Tiếng Việt" },
	},
	Fallback = "en",
	SaveHook = nil, -- called with the new code after a (non silent) change, used for persistence
}

local current = "en"
local builtin = {} -- builtin[code][key] = text (library strings)
local custom = {} -- custom[code][key or source text] = text (developer dictionaries)
local keys = {} -- keys[key] = { en = "...", vi = "..." } (Define)
local bound = setmetatable({}, { __mode = "k" })
local hooks = {}

local function valid(code)
	if type(code) ~= "string" then
		return false
	end
	for _, language in ipairs(Loc.Languages) do
		if language.Code == code then
			return true
		end
	end
	return false
end
Loc.IsValid = valid

local function bucket(store, code)
	local map = store[code]
	if not map then
		map = {}
		store[code] = map
	end
	return map
end

function Loc.Detect()
	local ok, locale = pcall(function()
		return Services.LocalizationService.RobloxLocaleId
	end)
	if not ok or type(locale) ~= "string" or locale == "" then
		ok, locale = pcall(function()
			return Services.Players.LocalPlayer.LocaleId
		end)
	end
	if ok and type(locale) == "string" then
		local prefix = string.sub(string.lower(locale), 1, 2)
		if valid(prefix) then
			return prefix
		end
	end
	return Loc.Fallback
end

function Loc.AddLanguage(code, name)
	if type(code) == "string" and not valid(code) then
		table.insert(Loc.Languages, { Code = code, Name = tostring(name or code) })
	end
end

-- Library strings: AddBuiltin("vi", { ["common.ok"] = "Đồng ý" })
function Loc.AddBuiltin(code, map)
	local target = bucket(builtin, code)
	for key, text in pairs(map) do
		target[key] = text
	end
end

-- Developer dictionary: AddTranslations("vi", { ["Auto farm"] = "Tự động farm", ["my.key"] = "..." }).
-- Entries are looked up by the exact source string, so only text you list is translated.
function Loc.AddTranslations(code, map)
	if type(map) ~= "table" then
		return
	end
	local target = bucket(custom, code)
	for source, text in pairs(map) do
		target[source] = text
	end
end
Loc.AddPhrases = Loc.AddTranslations -- DeaUI compatibility

-- Define("greeting", { en = "Hello", vi = "Xin chào" })
function Loc.Define(key, entry)
	if type(key) == "string" and type(entry) == "table" then
		keys[key] = entry
	end
end

function Loc.Known(text)
	if type(text) ~= "string" then
		return false
	end
	if keys[text] ~= nil then
		return true
	end
	for _, store in ipairs({ custom, builtin }) do
		for _, map in pairs(store) do
			if map[text] ~= nil then
				return true
			end
		end
	end
	return false
end

function Loc.Get()
	return current
end

function Loc.Name(code)
	for _, language in ipairs(Loc.Languages) do
		if language.Code == (code or current) then
			return language.Name
		end
	end
	return tostring(code)
end

local function lookup(source)
	local entry = keys[source]
	if entry then
		return entry[current] or entry[Loc.Fallback] or source
	end
	local own = custom[current]
	if own and own[source] ~= nil then
		return own[source]
	end
	local fixed = builtin[current]
	if fixed and fixed[source] ~= nil then
		return fixed[source]
	end
	if current ~= Loc.Fallback then
		local fallback = builtin[Loc.Fallback]
		if fallback and fallback[source] ~= nil then
			return fallback[source]
		end
		local fallbackCustom = custom[Loc.Fallback]
		if fallbackCustom and fallbackCustom[source] ~= nil and keys[source] == nil and own == nil then
			return fallbackCustom[source]
		end
	end
	return source
end

function Loc.Resolve(source, ...)
	local kind = type(source)
	local text
	if kind == "string" then
		text = lookup(source)
	elseif kind == "table" then
		text = source[current] or source[string.upper(current)] or source[Loc.Fallback] or source.EN
		if text == nil then
			for _, value in pairs(source) do
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
Loc.T = Loc.Resolve

-- Upper case that understands Vietnamese letters (string.upper is ASCII only).
local UP = {}
do
	local lower = "àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ"
	local upper = "ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ"
	local a, b = {}, {}
	for _, code in utf8.codes(lower) do
		a[#a + 1] = utf8.char(code)
	end
	for _, code in utf8.codes(upper) do
		b[#b + 1] = utf8.char(code)
	end
	for index, char in ipairs(a) do
		if b[index] then
			UP[char] = b[index]
		end
	end
end

function Loc.Upper(text)
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

-- Binds instance[property] to `source`; it is rewritten whenever the language changes, unless
-- someone assigned a different value to the property in the meantime.
function Loc.Bind(instance, property, source, transform)
	local map = bound[instance]
	if not map then
		map = {}
		bound[instance] = map
	end
	local value = Loc.Resolve(source)
	if transform then
		value = transform(value)
	end
	map[property] = { Source = source, Last = value, Transform = transform }
	instance[property] = value
	return value
end

function Loc.Unbind(instance, property)
	local map = bound[instance]
	if map then
		if property then
			map[property] = nil
		else
			bound[instance] = nil
		end
	end
end

-- Runs callback(code) now and after every language change. Returns a connection.
function Loc.Watch(callback)
	callback(current)
	return Loc.Changed:Connect(callback)
end

local function refresh()
	for instance, map in pairs(bound) do
		for property, entry in pairs(map) do
			local ok, now = pcall(function()
				return instance[property]
			end)
			if ok and now == entry.Last then
				local value = Loc.Resolve(entry.Source)
				if entry.Transform then
					value = entry.Transform(value)
				end
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

function Loc.Set(code, silent)
	if not valid(code) then
		return false
	end
	if code == current then
		return true
	end
	current = code
	refresh()
	if not silent then
		if Loc.SaveHook then
			pcall(Loc.SaveHook, code)
		end
		Loc.Changed:Fire(code)
	end
	return true
end

function Loc.Toggle()
	return Loc.Set(current == "vi" and "en" or "vi")
end

-- preferred: explicit code; saved: persisted choice; falls back to the Roblox locale, then English.
function Loc.Init(preferred, saved)
	local code = preferred
	if not valid(code) then
		code = saved
	end
	if not valid(code) then
		code = Loc.Detect()
	end
	current = code
	return current
end

-- { { Text = "English", Value = "en" }, { Text = "Tiếng Việt", Value = "vi" } }
function Loc.Items()
	local items = {}
	for _, language in ipairs(Loc.Languages) do
		items[#items + 1] = { Text = language.Name, Value = language.Code }
	end
	return items
end

return Loc
end

Modules["Localization/Strings"] = function(import)
local Loc = import("Localization")

-- Built-in interface text, English and Vietnamese. Each row: { key, English, Tieng Viet }.
-- Developer text is never added here: use UI.AddTranslations / UI.Define or { en = "...", vi = "..." } tables.
local ROWS = {
	-- navigation presets
	{ "nav.home", "Home", "Trang chủ" },
	{ "nav.overview", "Overview", "Tổng quan" },
	{ "nav.inventory", "Inventory", "Kho đồ" },
	{ "nav.pets", "Pets", "Thú cưng" },
	{ "nav.quests", "Quests", "Nhiệm vụ" },
	{ "nav.upgrades", "Upgrades", "Nâng cấp" },
	{ "nav.worlds", "Worlds", "Thế giới" },
	{ "nav.assets", "Assets", "Tài nguyên" },
	{ "nav.settings", "Settings", "Cài đặt" },
	-- common
	{ "common.all", "All", "Tất cả" },
	{ "common.buy", "Buy", "Mua" },
	{ "common.cancel", "Cancel", "Hủy" },
	{ "common.claim", "Claim", "Nhận" },
	{ "common.close", "Close", "Đóng" },
	{ "common.confirm", "Confirm", "Xác nhận" },
	{ "common.copied", "Copied", "Đã sao chép" },
	{ "common.copy", "Copy", "Sao chép" },
	{ "common.cost", "Cost", "Giá" },
	{ "common.delete", "Delete", "Xóa" },
	{ "common.equip", "Equip", "Trang bị" },
	{ "common.equipped", "Equipped", "Đã trang bị" },
	{ "common.error", "Something went wrong", "Đã xảy ra lỗi" },
	{ "common.level", "Level", "Cấp độ" },
	{ "common.loading", "Loading…", "Đang tải…" },
	{ "common.locked", "Locked", "Đã khóa" },
	{ "common.max", "MAX", "TỐI ĐA" },
	{ "common.more", "Show more", "Xem thêm" },
	{ "common.no", "No", "Không" },
	{ "common.ok", "OK", "OK" },
	{ "common.reset", "Reset", "Đặt lại" },
	{ "common.retry", "Retry", "Thử lại" },
	{ "common.reward", "Reward", "Phần thưởng" },
	{ "common.search_placeholder", "Search…", "Tìm kiếm…" },
	{ "common.select", "Select", "Chọn" },
	{ "common.travel", "Travel", "Di chuyển" },
	{ "common.unequip", "Unequip", "Gỡ ra" },
	{ "common.vip", "VIP", "VIP" },
	{ "common.vip_required", "This feature requires VIP.", "Tính năng này cần VIP." },
	{ "common.yes", "Yes", "Có" },
	-- rarity / status
	{ "rarity.common", "Common", "Thường" },
	{ "rarity.uncommon", "Uncommon", "Khá hiếm" },
	{ "rarity.rare", "Rare", "Hiếm" },
	{ "rarity.epic", "Epic", "Sử thi" },
	{ "rarity.legendary", "Legendary", "Huyền thoại" },
	{ "rarity.mythic", "Mythic", "Thần thoại" },
	{ "rarity.secret", "Secret", "Bí mật" },
	{ "quest.active", "Active", "Đang làm" },
	{ "quest.completed", "Completed", "Hoàn thành" },
	{ "quest.claimed", "Claimed", "Đã nhận" },
	{ "upgrade.maxed", "Maxed", "Tối đa" },
	{ "egg.hatch", "Hatch", "Ấp trứng" },
	{ "world.current", "Current", "Hiện tại" },
	{ "world.locked", "Not unlocked yet.", "Chưa mở khóa." },
	-- controls
	{ "colorpicker.hex", "#RRGGBB", "#RRGGBB" },
	{ "dropdown.none_found", "No results", "Không có kết quả" },
	{ "dropdown.search", "Search options…", "Tìm lựa chọn…" },
	{ "dropdown.select", "Select…", "Chọn…" },
	{ "dropdown.selected_count", "%d selected", "Đã chọn %d" },
	{ "keybind.listening", "Press a key…", "Nhấn phím…" },
	{ "keybind.none", "None", "Chưa gán" },
	{ "gallery.items_count", "%d items", "%d mục" },
	{ "gallery.view", "Switch grid / list view", "Đổi kiểu xem lưới / danh sách" },
	{ "browser.refresh", "Refresh", "Làm mới" },
	{ "browser.source", "Source", "Nguồn" },
	{ "queue.clear", "Clear", "Xóa hết" },
	{ "queue.empty", "The queue is empty.", "Hàng chờ đang trống." },
	{ "queue.title", "Queue", "Hàng chờ" },
	{ "feed.empty", "No activity yet.", "Chưa có hoạt động nào." },
	{ "feed.title", "Activity", "Hoạt động" },
	{ "multiplier.empty", "No active multipliers.", "Chưa có hệ số nhân nào." },
	{ "multiplier.title", "Multipliers", "Hệ số nhân" },
	{ "empty.title", "Nothing here yet", "Chưa có gì ở đây" },
	{ "empty.message", "There is nothing to show right now.", "Hiện chưa có gì để hiển thị." },
	{ "empty.search_title", "No matches", "Không tìm thấy" },
	{ "empty.search_message", "Try a different search or filter.", "Hãy thử từ khóa hoặc bộ lọc khác." },
	-- dialogs / loader / errors
	{ "dialog.confirm_title", "Please confirm", "Vui lòng xác nhận" },
	{ "dialog.prompt_title", "Enter a value", "Nhập giá trị" },
	{ "loader.building", "Building interface", "Đang dựng giao diện" },
	{ "loader.failed", "Could not start", "Không thể khởi động" },
	{ "loader.failed_message", "Something went wrong while loading.", "Đã có lỗi trong lúc tải." },
	{ "loader.loading_modules", "Loading modules", "Đang tải module" },
	{ "loader.loading_settings", "Loading settings", "Đang tải cài đặt" },
	{ "loader.ready", "Ready", "Sẵn sàng" },
	{ "loader.starting", "Starting…", "Đang khởi động…" },
	{ "error.config_corrupt", "A settings file was damaged. Defaults were restored.", "Tệp cài đặt bị hỏng. Đã khôi phục mặc định." },
	{ "error.config_recovered", "A settings file was recovered from a backup.", "Đã khôi phục tệp cài đặt từ bản sao lưu." },
	{ "error.discovery_unavailable", "Could not read the selected source.", "Không thể đọc nguồn đã chọn." },
	{ "error.generic", "Something went wrong.", "Đã xảy ra lỗi." },
	{ "error.save_failed", "Could not save the file.", "Không thể lưu tệp." },
	{ "error.storage_unavailable", "File storage is not available here.", "Môi trường này không hỗ trợ lưu tệp." },
	-- window
	{ "window.close", "Close", "Đóng" },
	{ "window.hidden_title", "Window hidden", "Đã ẩn cửa sổ" },
	{ "window.menu", "Menu", "Menu" },
	{ "window.minimize", "Minimize", "Thu nhỏ" },
	{ "window.open_button", "Open or hide the window", "Mở hoặc ẩn cửa sổ" },
	{ "window.search", "Search", "Tìm kiếm" },
	{ "window.search_hint", "Type to search settings and options.", "Gõ để tìm cài đặt và tùy chọn." },
	{ "window.toggle_hint", "Press %s to show it again.", "Nhấn %s để hiện lại." },
	-- HUD
	{ "hud.compact_mode", "Compact mode", "Chế độ gọn" },
	{ "hud.fps", "FPS", "FPS" },
	{ "hud.layout", "HUD layout", "Bố cục HUD" },
	{ "hud.layout_compact", "Compact", "Gọn" },
	{ "hud.layout_grid", "Grid", "Lưới" },
	{ "hud.layout_horizontal", "Horizontal", "Ngang" },
	{ "hud.layout_vertical", "Vertical", "Dọc" },
	{ "hud.opacity", "Opacity", "Độ mờ" },
	{ "hud.ping", "Ping", "Ping" },
	{ "hud.scale", "HUD size", "Kích thước HUD" },
	{ "hud.time", "Time", "Giờ" },
	-- configurations
	{ "config.autoload", "Load automatically", "Tự động tải" },
	{ "config.autoload_desc", "Load this configuration every time the UI starts.", "Tải cấu hình này mỗi khi giao diện khởi động." },
	{ "config.autoload_off", "AutoLoad turned off", "Đã tắt tự động tải" },
	{ "config.autoload_on", "AutoLoad enabled", "Đã bật tự động tải" },
	{ "config.delete", "Delete", "Xóa" },
	{ "config.deleted", "Deleted", "Đã xóa" },
	{ "config.load", "Load", "Tải" },
	{ "config.loaded", "Loaded", "Đã tải" },
	{ "config.name", "Configuration name", "Tên cấu hình" },
	{ "config.name_desc", "Letters, numbers, spaces, - and _", "Chữ, số, khoảng trắng, - và _" },
	{ "config.name_required", "Enter a name first.", "Hãy nhập tên trước." },
	{ "config.none", "None", "Không có" },
	{ "config.not_found", "Not found", "Không tìm thấy" },
	{ "config.placeholder", "My configuration", "Cấu hình của tôi" },
	{ "config.save", "Save", "Lưu" },
	{ "config.save_first", "Save the configuration first.", "Hãy lưu cấu hình trước." },
	{ "config.saved", "Saved", "Đã lưu" },
	{ "config.select", "Saved configurations", "Cấu hình đã lưu" },
	{ "config.title", "Configurations", "Cấu hình" },
	-- settings page
	{ "settings.animation_speed", "Animation speed", "Tốc độ hiệu ứng" },
	{ "settings.animations", "Animations", "Hiệu ứng chuyển động" },
	{ "settings.animations_desc", "Smooth transitions in the interface.", "Chuyển động mượt trong giao diện." },
	{ "settings.appearance", "Appearance", "Diện mạo" },
	{ "settings.copy_path", "Copy data folder path", "Sao chép đường dẫn thư mục dữ liệu" },
	{ "settings.danger", "Advanced", "Nâng cao" },
	{ "settings.data", "Data", "Dữ liệu" },
	{ "settings.data_folder", "Data folder", "Thư mục dữ liệu" },
	{ "settings.executor", "Executor", "Trình thực thi" },
	{ "settings.hud", "Mini HUD", "HUD mini" },
	{ "settings.hud_desc", "Small overlay with live metrics.", "Lớp phủ nhỏ hiển thị số liệu trực tiếp." },
	{ "settings.hud_show", "Show HUD", "Hiện HUD" },
	{ "settings.interface", "Interface", "Giao diện" },
	{ "settings.language", "Language", "Ngôn ngữ" },
	{ "settings.language_desc", "Applies to the whole interface immediately.", "Áp dụng ngay cho toàn bộ giao diện." },
	{ "settings.reduced_motion", "Reduce motion", "Giảm chuyển động" },
	{ "settings.reduced_motion_desc", "Turns animations off for comfort.", "Tắt hiệu ứng để dễ chịu hơn." },
	{ "settings.reset_theme", "Reset theme", "Đặt lại chủ đề" },
	{ "settings.scale", "Interface scale", "Tỷ lệ giao diện" },
	{ "settings.scale_desc", "Make everything larger or smaller.", "Phóng to hoặc thu nhỏ toàn bộ giao diện." },
	{ "settings.storage", "File storage", "Lưu trữ tệp" },
	{ "settings.storage_ok", "Available", "Khả dụng" },
	{ "settings.subtitle", "Language, appearance, configurations and data.", "Ngôn ngữ, diện mạo, cấu hình và dữ liệu." },
	{ "settings.theme", "Theme", "Chủ đề" },
	{ "settings.theme_desc", "Choose a color theme.", "Chọn bộ màu cho giao diện." },
	{ "settings.title", "Settings", "Cài đặt" },
	{ "settings.toggle_key", "Show / hide key", "Phím hiện / ẩn" },
	{ "settings.toggle_key_desc", "Opens or hides the window.", "Mở hoặc ẩn cửa sổ." },
	{ "settings.unload", "Unload interface", "Gỡ giao diện" },
	{ "settings.unload_confirm", "The interface will be removed. Saved settings are kept.", "Giao diện sẽ bị gỡ. Cài đặt đã lưu được giữ lại." },
	{ "settings.unload_desc", "Closes the window and frees all resources.", "Đóng cửa sổ và giải phóng toàn bộ tài nguyên." },
	{ "settings.version", "Version", "Phiên bản" },
	{ "theme.accent", "Accent color", "Màu nhấn" },
	{ "theme.custom_name", "Custom theme name", "Tên chủ đề tùy chỉnh" },
	{ "theme.custom_placeholder", "My theme", "Chủ đề của tôi" },
	{ "theme.custom_saved", "Saved themes", "Chủ đề đã lưu" },
	{ "theme.primary", "Primary color", "Màu chính" },
	{ "theme.radius", "Corner radius", "Độ bo góc" },
	{ "theme.spacing", "Spacing", "Khoảng cách" },
	{ "theme.save_custom", "Save theme", "Lưu chủ đề" },
	{ "theme.names.Midnight", "Midnight", "Nửa đêm" },
	{ "theme.names.Obsidian", "Obsidian", "Obsidian" },
	{ "theme.names.Emerald", "Emerald", "Ngọc lục bảo" },
	{ "theme.names.Violet", "Violet", "Tím" },
	{ "theme.names.Light", "Light", "Sáng" },
}

local en, vi = {}, {}
for _, row in ipairs(ROWS) do
	en[row[1]] = row[2]
	vi[row[1]] = row[3]
end
Loc.AddBuiltin("en", en)
Loc.AddBuiltin("vi", vi)

return ROWS
end

Modules["Storage/AutoLoad"] = function(import)
local Persistence = import("Storage/Persistence")
local Util = import("Core/Util")

--[[
	AutoLoad remembers which configuration should be loaded when the UI starts and which UI
	preferences it should restore (language, theme, HUD, window layout). It never runs gameplay logic:
	control values are restored silently and your own code reads them through UI.OnAutoLoad.
]]
local AutoLoad = {}

local DEFAULTS = {
	Enabled = false,
	Config = "",
	Restore = { Language = true, Theme = true, HUD = true, Layout = true },
}

local doc

local function ensure()
	if not doc then
		doc = Persistence.Document(Persistence.Files.AutoLoad, DEFAULTS)
	end
	return doc
end

function AutoLoad.Reload()
	doc = nil
	return ensure()
end

function AutoLoad.Get()
	local data = ensure().Data
	local restore = {}
	for key, default in pairs(DEFAULTS.Restore) do
		local value = type(data.Restore) == "table" and data.Restore[key]
		restore[key] = value == nil and default or value == true
	end
	local name = type(data.Config) == "string" and data.Config or ""
	return { Enabled = data.Enabled == true and name ~= "", Config = name ~= "" and name or nil, Restore = restore }
end

function AutoLoad.Set(name, restore)
	local data = ensure()
	if type(name) ~= "string" or name == "" then
		data:Set("Enabled", false)
		data:Set("Config", "")
	else
		data:Set("Config", name)
		data:Set("Enabled", true)
	end
	if type(restore) == "table" then
		local merged = Util.clone(DEFAULTS.Restore)
		for key, value in pairs(restore) do
			if merged[key] ~= nil then
				merged[key] = value == true
			end
		end
		data:Set("Restore", merged)
	end
	data:Save(true)
	return true
end

function AutoLoad.Clear()
	return AutoLoad.Set(nil)
end

function AutoLoad.Name()
	return AutoLoad.Get().Config
end

return AutoLoad
end

Modules["Storage/Config"] = function(import)
local Persistence = import("Storage/Persistence")
local Signal = import("Core/Signal")
local Env = import("Core/Env")
local Util = import("Core/Util")

--[[
	Configurations: the value of every control that has a Flag, plus an optional snapshot of UI
	preferences (language, theme, HUD, layout) supplied by providers that the library registers.
	  Configs/Default.json            the "Default" configuration
	  Configs/Custom/<name>.json      every other configuration
]]
local Config = {
	Flags = {},
	Providers = {}, -- name -> { Get = function() -> data, Set = function(data) }
	Pending = nil, -- values waiting for their control to be created (AutoLoad)
	Applied = Signal.new(),
}

local VERSION = 3

function Config.Register(flag, control)
	if type(flag) ~= "string" or flag == "" then
		return
	end
	Config.Flags[flag] = control
	local pending = Config.Pending
	if pending and pending.Flags[flag] ~= nil then
		local value = pending.Flags[flag]
		pending.Flags[flag] = nil
		pcall(control.Set, control, value, pending.Silent)
	end
end

function Config.Unregister(flag, control)
	if Config.Flags[flag] == control then
		Config.Flags[flag] = nil
	end
end

function Config.Path(name)
	if name == "Default" then
		return Persistence.Files.DefaultConfig
	end
	return "Configs/Custom/" .. Env.SafeName(name) .. ".json"
end

function Config.Available()
	return Persistence.Available()
end

-- Table with the current value of every flagged control (and the UI preferences).
function Config.Serialize()
	local flags = {}
	for flag, control in pairs(Config.Flags) do
		local ok, value = pcall(function()
			return control:Get()
		end)
		if ok and value ~= nil then
			flags[flag] = value
		end
	end
	local ui = {}
	for name, provider in pairs(Config.Providers) do
		local ok, value = pcall(provider.Get)
		if ok and value ~= nil then
			ui[name] = value
		end
	end
	return { Version = VERSION, Saved = os.time(), Flags = flags, UI = ui }
end

local function restoreAllowed(restore, name)
	if restore == nil then
		return true
	end
	return restore[name] == true
end

-- options: Silent (do not fire callbacks), Restore = { Language, Theme, HUD, Layout }, Defer (keep unknown flags pending)
function Config.Apply(data, options)
	options = options or {}
	if type(data) ~= "table" or type(data.Flags) ~= "table" then
		return false, "invalid"
	end
	local applied, deferred = 0, {}
	for flag, value in pairs(data.Flags) do
		local control = Config.Flags[flag]
		if control then
			if pcall(control.Set, control, value, options.Silent) then
				applied = applied + 1
			end
		elseif options.Defer then
			deferred[flag] = value
		end
	end
	if options.Defer then
		Config.Pending = { Flags = deferred, Silent = options.Silent }
	end
	if type(data.UI) == "table" then
		for name, snapshot in pairs(data.UI) do
			local provider = Config.Providers[name]
			if provider and provider.Set and restoreAllowed(options.Restore, name) then
				pcall(provider.Set, snapshot)
			end
		end
	end
	Config.Applied:Fire(applied)
	return true, applied
end

function Config.Save(name)
	if type(name) ~= "string" or Util.trim(name) == "" then
		return false, "name"
	end
	return Persistence.WriteJson(Config.Path(name), Config.Serialize())
end

function Config.Read(name)
	local data, reason = Persistence.ReadJson(Config.Path(name))
	if not data then
		return nil, reason
	end
	if type(data.Flags) ~= "table" then
		return nil, "invalid"
	end
	return data
end

function Config.Load(name, options)
	local data, reason = Config.Read(name)
	if not data then
		return false, reason
	end
	return Config.Apply(data, options)
end

function Config.Exists(name)
	return Persistence.Exists(Config.Path(name))
end

function Config.List()
	local names = Persistence.List("Configs/Custom")
	if Persistence.Exists(Persistence.Files.DefaultConfig) then
		table.insert(names, 1, "Default")
	end
	return names
end

function Config.Delete(name)
	return Persistence.Delete(Config.Path(name))
end

-- Applies values that were deferred by AutoLoad to every control that exists now.
function Config.ApplyPending()
	local pending = Config.Pending
	if not pending then
		return 0
	end
	local count = 0
	for flag, value in pairs(Util.clone(pending.Flags)) do
		local control = Config.Flags[flag]
		if control then
			pending.Flags[flag] = nil
			if pcall(control.Set, control, value, pending.Silent) then
				count = count + 1
			end
		end
	end
	return count
end

function Config.Clear()
	-- cleared in place: UI.Flags keeps pointing at the live registry
	for flag in pairs(Config.Flags) do
		Config.Flags[flag] = nil
	end
	Config.Pending = nil
end

return Config
end

Modules["Storage/Persistence"] = function(import)
local Env = import("Core/Env")
local Signal = import("Core/Signal")
local Services = import("Core/Services")
local Util = import("Core/Util")

--[[
	Persistence: the only module that touches the file system. Everything lives inside the main
	directory (Env.Root = "DeaUI-S", i.e. /storage/emulated/0/Delta/Workspace/DeaUI-S on Delta).

	  DeaUI-S/Settings/{General,Language,Appearance,Layout}.json
	  DeaUI-S/Configs/Default.json, Configs/Custom/<name>.json
	  DeaUI-S/Themes/Custom/<name>.json      DeaUI-S/HUD/Settings.json
	  DeaUI-S/AutoLoad/Config.json           DeaUI-S/Cache/AssetCache/
	  DeaUI-S/Icon/lucide-roblox.luau        (optional icon sprite sheet, as in DeaUI)

	Safe writes: new content goes to <file>.tmp, is read back and verified, the previous file is
	kept as <file>.bak, then <file> is replaced. Loading tries <file>, <file>.tmp, <file>.bak and
	falls back to defaults, so a missing or corrupted file never crashes the UI. When no file API
	exists the data is kept in memory for the session.
]]
local P = { Errors = Signal.new() }

P.Folders = { "Settings", "Configs", "Configs/Custom", "Themes", "Themes/Custom", "HUD", "Cache", "Cache/AssetCache", "AutoLoad", "Icon" }
P.Files = {
	General = "Settings/General.json",
	Language = "Settings/Language.json",
	Appearance = "Settings/Appearance.json",
	Layout = "Settings/Layout.json",
	HUD = "HUD/Settings.json",
	AutoLoad = "AutoLoad/Config.json",
	DefaultConfig = "Configs/Default.json",
}

local ready = false
local mem = {}
local docs = {}
local dirty = {}
local scheduled = false

function P.Available()
	return ready
end

local function probe(root)
	if not Env.EnsureFolder(root) then
		return false
	end
	local path = root .. "/.probe"
	local token = "probe-" .. tostring(os.clock())
	local ok = Env.Write(path, token) and Env.Read(path) == token
	Env.Delete(path)
	return ok
end

-- Finds a working root (relative to the executor workspace first, then the absolute Delta path),
-- creates the folder tree and reports whether disk persistence is usable.
function P.Init(options)
	options = options or {}
	ready = false
	if options.Persist == false or not Env.HasFiles() then
		return false
	end
	local candidates = { Env.Root }
	if Env.Root == "DeaUI-S" then
		candidates[2] = Env.AbsoluteRoot
	end
	for _, root in ipairs(candidates) do
		if probe(root) then
			Env.Root = root
			ready = true
			break
		end
	end
	if ready then
		for _, folder in ipairs(P.Folders) do
			Env.EnsureFolder(Env.Path(folder))
		end
	end
	return ready
end

function P.Root()
	return Env.Root
end

function P.Path(relative)
	return Env.Path(relative)
end

-- Value encoding for JSON -------------------------------------------------------------------
local function encode(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __t = "c", r = value.R, g = value.G, b = value.B }
	elseif kind == "EnumItem" then
		return { __t = "e", t = tostring(value.EnumType), n = value.Name }
	elseif kind == "Vector2" then
		return { __t = "v2", x = value.X, y = value.Y }
	elseif kind == "UDim2" then
		return { __t = "u2", xs = value.X.Scale, xo = value.X.Offset, ys = value.Y.Scale, yo = value.Y.Offset }
	elseif kind == "table" then
		local out = {}
		for key, entry in pairs(value) do
			out[key] = encode(entry)
		end
		return out
	elseif kind == "number" and (value ~= value or value == math.huge or value == -math.huge) then
		return 0
	end
	return value
end

local function decode(value)
	if type(value) ~= "table" then
		return value
	end
	local tag = value.__t
	if tag == "c" then
		return Color3.new(tonumber(value.r) or 0, tonumber(value.g) or 0, tonumber(value.b) or 0)
	elseif tag == "e" then
		local ok, item = pcall(function()
			return Enum[value.t][value.n]
		end)
		return ok and item or nil
	elseif tag == "v2" then
		return Vector2.new(tonumber(value.x) or 0, tonumber(value.y) or 0)
	elseif tag == "u2" then
		return UDim2.new(tonumber(value.xs) or 0, tonumber(value.xo) or 0, tonumber(value.ys) or 0, tonumber(value.yo) or 0)
	end
	local out = {}
	for key, entry in pairs(value) do
		out[key] = decode(entry)
	end
	return out
end
P.Encode, P.Decode = encode, decode

local function toText(data)
	local ok, text = pcall(function()
		return Services.HttpService:JSONEncode(encode(data))
	end)
	if ok then
		return text
	end
	return nil, text
end

-- Files -------------------------------------------------------------------------------------
function P.Exists(relative)
	if not ready then
		return mem[relative] ~= nil
	end
	return Env.Exists(Env.Path(relative))
end

function P.ReadJson(relative)
	if not ready then
		if mem[relative] ~= nil then
			return Util.deepClone(mem[relative])
		end
		return nil, "missing"
	end
	local path = Env.Path(relative)
	local primaryBad = false
	for index, candidate in ipairs({ path, path .. ".tmp", path .. ".bak" }) do
		local text = Env.Read(candidate)
		if text and text ~= "" then
			local ok, decoded = pcall(function()
				return Services.HttpService:JSONDecode(text)
			end)
			if ok and type(decoded) == "table" then
				if index > 1 and primaryBad then
					P.Errors:Fire("recovered", relative, index == 2 and "tmp" or "backup")
				end
				return decode(decoded)
			elseif index == 1 then
				primaryBad = true
			end
		end
	end
	if primaryBad then
		Env.Write(path .. ".corrupt", Env.Read(path) or "")
		P.Errors:Fire("corrupt", relative)
		return nil, "corrupt"
	end
	return nil, "missing"
end

function P.WriteJson(relative, data)
	if not ready then
		mem[relative] = Util.deepClone(data)
		return true
	end
	local text, reason = toText(data)
	if not text then
		P.Errors:Fire("encode", relative, reason)
		return false
	end
	local path = Env.Path(relative)
	local tmp = path .. ".tmp"
	if not Env.Write(tmp, text) or Env.Read(tmp) ~= text then
		Env.Delete(tmp)
		P.Errors:Fire("write", relative)
		return false
	end
	local old = Env.Read(path)
	if old and old ~= "" and old ~= text then
		Env.Write(path .. ".bak", old)
	end
	if not Env.Write(path, text) then
		P.Errors:Fire("write", relative)
		return false
	end
	Env.Delete(tmp)
	return true
end

function P.Delete(relative)
	mem[relative] = nil
	docs[relative] = nil
	dirty[relative] = nil
	if not ready then
		return true
	end
	local path = Env.Path(relative)
	local existed = Env.Exists(path)
	for _, suffix in ipairs({ "", ".bak", ".tmp", ".corrupt" }) do
		Env.Delete(path .. suffix)
	end
	return existed
end

-- Names (without extension) of the .json files inside a folder of the main directory.
function P.List(folder, prefixToSkip)
	local names = {}
	if not ready then
		for key in pairs(mem) do
			local name = string.match(key, "^" .. folder .. "/([^/]+)%.json$")
			if name then
				names[#names + 1] = name
			end
		end
	else
		for _, file in ipairs(Env.List(Env.Path(folder))) do
			local name = string.match(file, "([^/\\]+)%.json$")
			if name and name ~= prefixToSkip then
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	return names
end

-- Documents: typed settings files with defaults ----------------------------------------------
local function sameKind(default, value)
	if default == nil then
		return true
	end
	return typeof(default) == typeof(value)
end

local Doc = {}
Doc.__index = Doc

function Doc:Load()
	local decoded, reason = P.ReadJson(self.Path)
	local data = Util.deepClone(self.Defaults)
	if decoded then
		for key, value in pairs(decoded) do
			local fallback = self.Defaults[key]
			if sameKind(fallback, value) and (not self.Validate or self.Validate(key, value)) then
				data[key] = value
			end
		end
	end
	self.Data = data
	self.LoadReason = decoded and "ok" or reason
	return decoded ~= nil
end

function Doc:Get(key, fallback)
	local value = self.Data[key]
	if value == nil then
		return fallback
	end
	return value
end

local function flush()
	scheduled = false
	for relative, doc in pairs(Util.clone(dirty)) do
		dirty[relative] = nil
		P.WriteJson(relative, doc.Data)
	end
end

function Doc:Save(immediate)
	dirty[self.Path] = self
	if immediate then
		flush()
	elseif not scheduled then
		scheduled = true
		task.delay(0.5, flush)
	end
end

function Doc:Set(key, value, silent)
	if self.Validate and not self.Validate(key, value) then
		return false
	end
	local previous = self.Data[key]
	self.Data[key] = value
	if not silent then
		self.Changed:Fire(key, value)
	end
	if type(value) == "table" or previous ~= value then
		self:Save()
	end
	return true
end

function Doc:Update(map)
	for key, value in pairs(map) do
		self.Data[key] = value
	end
	self:Save()
end

function Doc:Reset()
	self.Data = Util.deepClone(self.Defaults)
	self:Save()
	self.Changed:Fire(nil, nil)
end

function P.Document(relative, defaults, options)
	local existing = docs[relative]
	if existing then
		return existing
	end
	local doc = setmetatable({
		Path = relative,
		Defaults = defaults or {},
		Data = {},
		Changed = Signal.new(),
		Validate = options and options.Validate,
	}, Doc)
	docs[relative] = doc
	doc:Load()
	return doc
end

function P.Flush()
	flush()
end

function P.Describe()
	return {
		Available = ready,
		Root = Env.Root,
		AbsoluteRoot = Env.AbsoluteRoot,
		Executor = Env.Name,
	}
end

-- Flushes pending writes and forgets every document (used by Destroy and in tests).
function P.Reset()
	flush()
	docs = {}
	dirty = {}
end

return P
end

Modules["Theme/IconCatalog"] = function(import)
return [[a-arrow-down=87834851353233;a-arrow-up=89385437396694;a-large-small=73183249747960;accessibility=109960743825561;activity=137527339160230;activity-square=126953951117387;air-vent=111625153433818;airplay=92171397431531;alarm-check=130501077167542;alarm-clock=118636480109240;alarm-clock-check=70976944787280;alarm-clock-minus=70856300954858;alarm-clock-off=110132709107464;alarm-clock-plus=96736786697131;alarm-minus=77271404005062;alarm-plus=128528043300240;alarm-smoke=76581519928624;album=112445622428637;alert-circle=74115333842618;alert-octagon=138910404523272;alert-triangle=112102474509324;align-center=120408521883501;align-center-horizontal=108597166812858;align-center-vertical=121154206034694;align-end-horizontal=99069601868832;align-end-vertical=117942349521535;align-horizontal-distribute-center=77482483036009;align-horizontal-distribute-end=134639979863642;align-horizontal-distribute-start=134435692726811;align-horizontal-justify-center=92390581039957;align-horizontal-justify-end=104340168067575;align-horizontal-justify-start=78939447794797;align-horizontal-space-around=80515421591545;align-horizontal-space-between=114038806348167;align-justify=92373371786861;align-left=136554315335959;align-right=135067010612236;align-start-horizontal=96834758740744;align-start-vertical=123458513293976;align-vertical-distribute-center=90818078154247;align-vertical-distribute-end=136782098795781;align-vertical-distribute-start=134480830300767;align-vertical-justify-center=130298876730417;align-vertical-justify-end=100777246465864;align-vertical-justify-start=123693071723398;align-vertical-space-around=124225977511288;align-vertical-space-between=81499787439793;ambulance=103392162911629;ampersand=76900943277226;ampersands=86469233094518;anchor=127378493192461;angry=79345553086407;annoyed=104846682265434;antenna=112766612909532;anvil=86432599455606;aperture=139684165362622;app-window=87635787215081;app-window-mac=108549782746996;apple=93203750625654;archive=137249944163344;archive-restore=96820254661076;archive-x=134784309661522;area-chart=107486186614989;armchair=104852764227195;arrow-big-down=134387593103194;arrow-big-down-dash=125189777214718;arrow-big-left=79012356613282;arrow-big-left-dash=132879301629314;arrow-big-right=90405262165720;arrow-big-right-dash=121488142481379;arrow-big-up=95689861013321;arrow-big-up-dash=106976910180035;arrow-down=134161790366779;arrow-down-0-1=140381370510884;arrow-down-1-0=130494621181478;arrow-down-a-z=103554859233661;arrow-down-circle=131404694292521;arrow-down-from-line=81443516391691;arrow-down-left=102509297349411;arrow-down-left-from-circle=73012719459961;arrow-down-left-square=90976696713068;arrow-down-narrow-wide=71046418862578;arrow-down-right=72764732196403;arrow-down-right-from-circle=97668995487103;arrow-down-right-square=128499661363473;arrow-down-square=138838216140198;arrow-down-to-dot=88868273845458;arrow-down-to-line=137644743820952;arrow-down-up=117405374619280;arrow-down-wide-narrow=75826372885867;arrow-down-z-a=118359795316087;arrow-left=90293255250749;arrow-left-circle=130847257582775;arrow-left-from-line=77381869318221;arrow-left-right=112517617090898;arrow-left-square=135104418905606;arrow-left-to-line=130252021035812;arrow-right=134908902120212;arrow-right-circle=94365145580321;arrow-right-from-line=107378199607331;arrow-right-left=111890422557630;arrow-right-square=115337431423227;arrow-right-to-line=103829994761864;arrow-up=104406213770080;arrow-up-0-1=139178256421912;arrow-up-1-0=97298977768167;arrow-up-a-z=97443044644659;arrow-up-circle=75833692771331;arrow-up-down=73746166761985;arrow-up-from-dot=103317134268223;arrow-up-from-line=101711387260955;arrow-up-left=103783370700580;arrow-up-left-from-circle=96382098119619;arrow-up-left-square=101543880954604;arrow-up-narrow-wide=122289869517959;arrow-up-right=115214649052675;arrow-up-right-from-circle=102906718956851;arrow-up-right-square=113196521639031;arrow-up-square=112280252781879;arrow-up-to-line=135365442561417;arrow-up-wide-narrow=79052928363256;arrow-up-z-a=93443333447390;arrows-up-from-line=140178313470659;asterisk=107247711733329;at-sign=94614469252449;atom=119051552929078;audio-lines=133487746892141;audio-waveform=135412900878575;award=82039875682356;axe=84931585672806;axis-3d=83328523632480;baby=75683742350958;backpack=76143965140765;badge=78791133479661;badge-alert=92904571921902;badge-cent=110902979965426;badge-check=76305757263548;badge-dollar-sign=123225256208806;badge-euro=82107326159074;badge-help=83944903318576;badge-indian-rupee=105958255216505;badge-info=109792483526167;badge-japanese-yen=96156476341857;badge-minus=79191240000290;badge-percent=129993801535784;badge-plus=73308743105191;badge-pound-sterling=104904198937382;badge-russian-ruble=91738909980749;badge-swiss-franc=102826901242684;badge-x=117187082865205;baggage-claim=119346910227968;ban=109685306480139;banana=128374499714074;banknote=113703117675594;bar-chart=121570259716677;bar-chart-2=121452498735866;bar-chart-3=130626786024244;bar-chart-4=96221317327213;bar-chart-big=119295298711810;bar-chart-horizontal=109235174327898;bar-chart-horizontal-big=139737497124066;barcode=78580529416152;baseline=116347038683714;bath=89008182357290;battery=102599812606554;battery-charging=91402957855599;battery-full=108407180588179;battery-low=132416805088817;battery-medium=139407584675024;battery-warning=119084304752903;beaker=100026072450383;bean=108654318985558;bean-off=75755103997845;bed=71982795501399;bed-double=97693190540435;bed-single=80557330573152;beef=93001452038647;beer=71718925718592;beer-off=135309228180602;bell=84691420588185;bell-dot=100564215426004;bell-electric=120584905231603;bell-minus=117849268875449;bell-off=115540031372596;bell-plus=85655293455454;bell-ring=71006419366158;between-horizontal-end=97454674221809;between-horizontal-start=122308710081740;between-vertical-end=73288142609772;between-vertical-start=96319480553759;bike=139392597724277;binary=73887562333653;biohazard=137351193301090;bird=78301366757596;bitcoin=87905951788220;blend=99774242136996;blinds=97128563480198;blocks=116361302503360;bluetooth=140648462080543;bluetooth-connected=108047104997672;bluetooth-off=85384277884353;bluetooth-searching=88887842293685;bold=114571598098097;bolt=134172358414310;bomb=85112456002145;bone=110911138031483;book=74111869099427;book-a=130683776374615;book-audio=84765914852101;book-check=116693733550590;book-copy=103556293898971;book-dashed=90144560974060;book-down=102612840928328;book-headphones=101847018803943;book-heart=79225550955168;book-image=97175021450327;book-key=78825638323167;book-lock=136914298397858;book-marked=130311722822005;book-minus=111140800790677;book-open=84762150530577;book-open-check=100175521109916;book-open-text=83251408532985;book-plus=135397977794739;book-text=96481772943887;book-type=80135728169729;book-up=92592832226795;book-up-2=74123009075829;book-user=80586093636888;book-x=75485266769989;bookmark=137439152875860;bookmark-check=103743627936816;bookmark-minus=106761186502279;bookmark-plus=108572239011289;bookmark-x=115354177404954;boom-box=88874304172044;bot=70979486241131;bot-message-square=79709292282995;box=117371753006597;box-select=106969329058115;boxes=95055252135506;braces=92263187057993;brackets=87406077670628;brain=116902501990569;brain-circuit=130830898675113;brain-cog=76347059769903;brick-wall=94677898150825;briefcase=78701740878808;briefcase-business=83989706459460;briefcase-medical=101696204417639;bring-to-front=105016868447258;brush=113475652218451;bug=75649814233484;bug-off=72963988065933;bug-play=109066688101101;building=128630485814878;building-2=97744948701888;bus=115040051931434;bus-front=89834398235413;cable=122718774070506;cable-car=75378206085314;cake=88535465840262;cake-slice=99501344714989;calculator=107281102048400;calendar=126460151885084;calendar-check=116665691227418;calendar-check-2=128139765113287;calendar-clock=91678408267921;calendar-days=83005303274935;calendar-fold=120622111767156;calendar-heart=101728896191412;calendar-minus=97111317408323;calendar-minus-2=114139960753026;calendar-off=72690038281381;calendar-plus=113126930241503;calendar-plus-2=95708816339251;calendar-range=85814519406070;calendar-search=94105486063910;calendar-x=117555084312063;calendar-x-2=137455674513711;camera=114084146151777;camera-off=101456706369049;candlestick-chart=99842864833044;candy=113164012451432;candy-cane=125416183674924;candy-off=122702931937344;captions=105023593632540;captions-off=75480095441780;car=91451724283877;car-front=79993076477613;car-taxi-front=75623233937291;caravan=78521421981947;carrot=71122235024925;case-lower=95359311197985;case-sensitive=133603526051277;case-upper=77340278207531;cassette-tape=113140472253110;cast=119573692041871;castle=104598700669384;cat=118339348494810;cctv=84978679477516;check=86817768619372;check-check=101885204738917;check-circle=105979545056636;check-circle-2=76928915955542;check-square=135686334400788;check-square-2=84113739446686;chef-hat=94153362248387;cherry=116326418543667;chevron-down=71457658246709;chevron-down-circle=130642617728982;chevron-down-square=84683053234548;chevron-first=70831710633364;chevron-last=102556054621077;chevron-left=102314312897830;chevron-left-circle=70732746220332;chevron-left-square=78492542000164;chevron-right=101007429951147;chevron-right-circle=87038574131735;chevron-right-square=119136642030742;chevron-up=98648581502859;chevron-up-circle=111681831848531;chevrons-down=84492998086101;chevrons-down-up=82103880591342;chevrons-left=87881912126351;chevrons-left-right=132331219761704;chevrons-right=134353805354361;chevrons-right-left=96783734429291;chevrons-up=88461690106632;chevrons-up-down=71880540200693;circle-arrow-down=129076838165145;circle-arrow-left=88796613571531;circle-arrow-out-down-left=107231337431973;circle-arrow-out-down-right=70490689174861;circle-arrow-out-up-left=79479678307645;circle-arrow-out-up-right=127093834620465;circle-arrow-right=97664127355280;circle-arrow-up=72634350793509;circle-check=88244323237265;circle-check-big=105847305799404;circle-chevron-down=88531529614731;circle-chevron-left=109806050128867;circle-chevron-right=130159833971034;circle-chevron-up=126990996679640;circle-dashed=122032109800866;circle-divide=136980096833105;circle-dollar-sign=102720278203768;circle-dot=122878673716704;circle-dot-dashed=107222591318022;circle-ellipsis=72989868902667;circle-equal=83415595687523;circle-fading-plus=97734885169321;circle-gauge=79712667314679;circle-help=132353516577418;circle-minus=98163850412523;circle-off=95467094528299;circle-parking=117482323268433;circle-parking-off=80459013698184;circle-pause=88794740338426;circle-percent=125429815212970;circle-play=84481789029543;circle-plus=117262167984222;circle-power=127349877206105;circle-slash=98431785453122;circle-slash-2=79541029224240;circle-stop=109423106908446;circle-user=87167719100614;circle-user-round=113831490904568;circle-x=106305483906363;circuit-board=124136951218642;citrus=79624448772527;clapperboard=132343838416956;clipboard=105021692319787;clipboard-check=90432969741774;clipboard-copy=85387882337161;clipboard-edit=131193135046966;clipboard-list=129402512748462;clipboard-minus=94779294031183;clipboard-paste=79192963603923;clipboard-pen=99195778697194;clipboard-pen-line=103555830963651;clipboard-plus=74352366953056;clipboard-signature=120750772696869;clipboard-type=132835545998943;clipboard-x=132658738057667;clock=136533241128438;clock-1=71498600757409;clock-10=123641121766955;clock-11=85845500811663;clock-12=133878455420257;clock-2=102975079908275;clock-3=119663119982527;clock-4=108792000100666;clock-5=97840714155038;clock-6=102025123837297;clock-7=110824271252901;clock-8=123515589399454;clock-9=126662391246112;cloud=136524873450824;cloud-cog=108438517119798;cloud-download=78768373704516;cloud-drizzle=80789072164434;cloud-fog=110403642693501;cloud-hail=95998880244047;cloud-lightning=118391347029403;cloud-moon=120156057895579;cloud-moon-rain=101513348432910;cloud-off=111796785870393;cloud-rain=130177212410873;cloud-rain-wind=87893934921731;cloud-snow=104971371973617;cloud-sun=140109651313859;cloud-sun-rain=132138781511885;cloud-upload=86452290950086;cloudy=132267475821363;clover=128291338532394;club=83110975306436;code=75851496262862;code-2=79541605299928;code-xml=106124864132557;codepen=131077252082543;codesandbox=139298967633423;coffee=125329933348791;cog=123222732420633;coins=117341212186115;columns=96838631255058;columns-2=110924811097991;columns-3=88214025452433;columns-4=100379574150921;combine=103133480717944;command=90385430770591;compass=73836660434977;component=106556990975641;computer=72888027377165;concierge-bell=134373387272639;cone=80255197365555;construction=77845797691565;contact=102372888309353;contact-2=100454539997812;contact-round=117599766367773;container=135116917100753;contrast=71154426791470;cookie=96083862569395;cooking-pot=100393801714299;copy=116378866141355;copy-check=92397569046734;copy-minus=75815893695780;copy-plus=138173295478363;copy-slash=74395410823283;copy-x=98741265066436;copyleft=103019482632984;copyright=82044483134605;corner-down-left=105689000447775;corner-down-right=82061714010896;corner-left-down=133517193053100;corner-left-up=78035789940893;corner-right-down=135390474501786;corner-right-up=122661540167291;corner-up-left=72973602941956;corner-up-right=108297458644964;cpu=105237370909681;creative-commons=111243376462256;credit-card=124946887228472;croissant=77683374738482;crop=121481502611712;cross=93673591064028;crosshair=83752373575368;crown=92253403464658;cuboid=117329818290748;cup-soda=132120247880161;currency=96706001818192;cylinder=99158693669056;database=99154172590159;diamond=136889727768904;diamond-percent=138695404542126;dice-1=133629376866649;dice-2=137517882571271;dice-3=128612626459042;dice-4=73117400593570;dice-5=107643287892749;dice-6=112067139297943;dices=116678154854810;diff=122850860032588;disc=77318106935130;disc-2=135460247355994;disc-3=118087373340436;disc-album=101298984360789;divide=134571770296218;divide-circle=115849848955050;divide-square=78617148972524;dna=131581201333424;dna-off=90101733367858;dock=96133720652582;dog=123749328846346;dollar-sign=74567340201672;donut=123909563150383;door-closed=118483980594708;door-open=124230332524625;dot=105006331197983;download=109698732019071;download-cloud=122841052352556;drafting-compass=110585086142082;drama=138828515077300;dribbble=112906380564504;drill=113833078477512;droplet=91586468475195;droplets=117720354071548;drum=121019656655547;drumstick=106711459328737;dumbbell=130873531670678;ear=92631431780796;ear-off=81480882487332;earth=75025349205767;earth-lock=103673515494330;eclipse=113566298471092;egg=103880404435578;egg-fried=137654273789326;egg-off=99146230558760;ellipsis=95127553964880;ellipsis-vertical=95771045694204;equal=79273099065269;eraser=71210100060694;euro=139202392240827;expand=107643532357936;external-link=78664150174274;eye=127234874352422;eye-off=85207295981701;facebook=98822363427090;factory=79319339232812;fan=76323281744636;fast-forward=131011550754955;feather=103991922506350;fence=90935998613863;ferris-wheel=94538249337586;figma=103020132259719;file=108499043987115;file-archive=78133118745021;file-audio=101306436065858;file-audio-2=103353018363480;file-axis-3d=136107008496948;file-badge=135829024450190;file-badge-2=87916835926622;file-bar-chart=92900624303400;file-bar-chart-2=133337118425916;file-box=102441183584476;file-check=91719007832323;file-check-2=120611252466724;file-clock=101240345040794;file-code=93918366472395;file-code-2=77999709917415;file-cog=130835463141181;file-diff=132890714271689;file-digit=108016195781167;file-down=79495546108963;file-edit=82156880342025;file-heart=138364329637312;file-image=83675710276234;file-input=78561929224193;file-json=98868866618869;file-json-2=92610524789574;file-key=83249504215614;file-key-2=103006369640378;file-line-chart=84182680444173;file-lock=140186307068344;file-lock-2=126656887901996;file-minus=138371877961417;file-minus-2=107551117550330;file-music=107180630571772;file-output=109566424197143;file-pen=134577965177665;file-pen-line=90852962587361;file-pie-chart=94554256943610;file-plus=74194167957081;file-plus-2=111571245681686;file-question=128415338385227;file-scan=132590981389921;file-search=131130928074464;file-search-2=139930116408040;file-signature=87096324580559;file-sliders=133181135528313;file-spreadsheet=117808207510717;file-stack=132187715148899;file-symlink=122206323516270;file-terminal=91847143440556;file-text=92774566080911;file-type=139551268989315;file-type-2=91173675777316;file-up=99191463679083;file-video=105252283775469;file-video-2=130213998083954;file-volume=119603558694315;file-volume-2=139949156797892;file-warning=89824347717079;file-x=117124390222574;file-x-2=136449417648465;files=78685849153126;film=120941801045330;filter=100930784445785;filter-x=85838104400923;fingerprint=109514257830136;fire-extinguisher=84862159260845;fish=114555142566431;fish-off=99443044829026;fish-symbol=123702927226939;flag=121835250831612;flag-off=90046025355940;flag-triangle-left=73117581559482;flag-triangle-right=106524126597496;flame=125012650497883;flame-kindling=136834319064926;flashlight=110881718712443;flashlight-off=117038550056668;flask-conical=115528123394259;flask-conical-off=102385597737770;flask-round=118701306736141;flip-horizontal=76347241876815;flip-horizontal-2=107329750779249;flip-vertical=121575310281690;flip-vertical-2=77578710261033;flower=98459040977090;flower-2=79478214327919;focus=116191961683883;fold-horizontal=133102230855922;fold-vertical=128556601978376;folder=77937190465422;folder-archive=96956679126324;folder-check=95477621394824;folder-clock=137926892639070;folder-closed=86427718056887;folder-cog=127866486547434;folder-dot=129773010201383;folder-down=82793534945672;folder-edit=102495189191583;folder-git=104507928948019;folder-git-2=85014883332248;folder-heart=110088173047332;folder-input=132837435930621;folder-kanban=138103158509024;folder-key=130401922270021;folder-lock=111493727654155;folder-minus=97790081587083;folder-open=112237915867403;folder-open-dot=90332268376865;folder-output=125946013402264;folder-pen=81838874164795;folder-plus=71462957431660;folder-root=80403663819762;folder-search=109602276944932;folder-search-2=74614286288240;folder-symlink=89907141903257;folder-sync=137088423628527;folder-tree=78199416535568;folder-up=85416900334449;folder-x=103887939759350;folders=97828544806816;footprints=80792036653047;forklift=117529645336183;form-input=73368443063193;forward=78301309129142;frame=81913255681858;framer=117525065607897;frown=88589722723911;fuel=112915457104961;fullscreen=92176335589571;function-square=77009803117016;gallery-horizontal=113964455804231;gallery-horizontal-end=125589356860308;gallery-thumbnails=123093292028306;gallery-vertical=109130466006021;gallery-vertical-end=122352399696695;gamepad=81482768981191;gamepad-2=99293705721130;gantt-chart=122456724985241;gantt-chart-square=73571197135748;gauge=128279962545721;gauge-circle=110231832967256;gavel=118993398179839;gem=125353572203968;ghost=132705178126217;gift=87706885156127;git-branch=101518089376526;git-branch-plus=127909649257701;git-commit-horizontal=91306319670540;git-commit-vertical=101185915909200;git-compare=134611228556653;git-compare-arrows=134203912676625;git-fork=138214272765755;git-graph=126789259203618;git-merge=118868315103570;git-pull-request=117991178843732;git-pull-request-arrow=133155768650667;git-pull-request-closed=74188383635944;git-pull-request-create=108540858735398;git-pull-request-create-arrow=75317536980451;git-pull-request-draft=127220095778670;github=140138081031269;gitlab=109316577965403;glass-water=125170765146614;glasses=77027406085123;globe=125685532120024;globe-2=112945472486319;globe-lock=96469366281710;goal=90015442702200;grab=117741873625250;graduation-cap=140187510907091;grape=73195418744413;grid-2x2=134599229810680;grid-3x3=108197747587523;grip=88188569450143;grip-horizontal=72027364608348;grip-vertical=136050395759142;group=79946652686375;guitar=135654565391445;ham=134057117057030;hammer=73956316105509;hand=83088528355903;hand-coins=85922324710029;hand-heart=124155721578457;hand-helping=95094264299544;hand-metal=105555696144202;hand-platter=101356141176839;handshake=121760224402586;hard-drive=115211376876196;hard-drive-download=115854711953657;hard-drive-upload=112990104477043;hard-hat=105207891316460;hash=128945191245705;haze=86624380139587;hdmi-port=123935181216786;heading=115666667306834;heading-1=82056941503516;heading-2=109194333144049;heading-3=86456694536830;heading-4=108808532352504;heading-5=84468448396475;heading-6=70885434512827;headphones=89990513082092;headset=77155289443816;heart=88525382655929;heart-crack=78532998725036;heart-handshake=88807882205984;heart-off=121500734414824;heart-pulse=101116623654468;heater=75867015789217;help-circle=71693802872044;helping-hand=82838882533396;hexagon=111932983587355;highlighter=124195908160173;history=70375455140492;home=109841253338329;hop=87886892027508;hop-off=124047203843704;hospital=100542468114469;hotel=88463240253197;hourglass=135654740495171;ice-cream=95314536020685;ice-cream-2=93935347717656;ice-cream-bowl=116507918255217;ice-cream-cone=72823870951577;image=114022611279795;image-down=91697762317652;image-minus=111691180013117;image-off=113890586559666;image-plus=131640557457656;image-up=95362531246536;images=87539822715105;import=87776530532335;inbox=131993988107472;indent=111431763044113;indent-decrease=77902371540680;indent-increase=116043459584133;indian-rupee=121515804799242;infinity=77975814002740;info=120620848266512;inspection-panel=93487140703578;instagram=88504800931130;italic=96844815325902;iteration-ccw=114475186061127;iteration-cw=130833288197698;japanese-yen=108845518454015;joystick=75024649968329;kanban=132557744047883;kanban-square=124564901729634;kanban-square-dashed=134205902924289;key=83474888140571;key-round=116918931002434;key-square=79693131186843;keyboard=121978468376124;keyboard-music=74763240290099;lamp=123765123149989;lamp-ceiling=120174084956571;lamp-desk=125995036157694;lamp-floor=102217348025530;lamp-wall-down=134067530649420;lamp-wall-up=101034120941267;land-plot=114974071140535;landmark=130189940998950;languages=130065428637597;laptop=103798905446648;laptop-2=106021728338003;laptop-minimal=91920768368168;lasso=110262485516329;lasso-select=112600066891219;laugh=115974660887808;layers=114499998778667;layers-2=87219208863328;layers-3=114549653986465;layout=75056433029964;layout-dashboard=70433574792490;layout-grid=89644754139307;layout-list=72384664085473;layout-panel-left=117264898598467;layout-panel-top=135570881026156;layout-template=78078135578383;leaf=70846801126940;leafy-green=94770162749325;library=114050057679028;library-big=135791941822287;library-square=132158761398954;life-buoy=99147024142900;ligature=75804099923602;lightbulb=98419938500979;lightbulb-off=126746194476977;line-chart=115214641333880;link=86131768436965;link-2=107339085791087;link-2-off=74994782779018;linkedin=102928864661994;list=101699539545687;list-checks=133109875194066;list-collapse=103651151660786;list-end=116487672075047;list-filter=83186010624431;list-minus=119184210915074;list-music=88988800995482;list-ordered=100068475590931;list-plus=124010335412192;list-restart=91193864293753;list-start=131366235513143;list-todo=83287488939815;list-tree=127759805921507;list-video=117978552190904;list-x=115746075160943;loader=132295854994374;loader-2=128780061297692;loader-circle=71250150569964;locate=106821189831430;locate-fixed=80648116191645;locate-off=121088730454886;lock=119765975153029;lock-keyhole=135504457058301;lock-keyhole-open=132192657766903;lock-open=71186154315213;log-in=82241120685313;log-out=140299936053191;lollipop=102239398934579;luggage=140614046877100;m-square=97856747717836;magnet=97474941633274;mail=77537514051485;mail-check=90824179551389;mail-minus=104189493909738;mail-open=74874447671108;mail-plus=130540869833539;mail-question=128924135790205;mail-search=108269769085404;mail-warning=126275145590627;mail-x=97229750262408;mailbox=104064071799815;mails=120925930542398;map=131325044235094;map-pin=137091405832737;map-pin-off=130126969919710;map-pinned=78894827751778;martini=108853683970464;maximize=116546384863431;maximize-2=130049637400171;medal=97534791863003;megaphone=139746713205639;megaphone-off=130364738220291;meh=117127044934876;memory-stick=82464660673318;menu=83047518441184;menu-square=84168857053009;merge=96640473379848;message-circle=74163263000218;message-circle-code=124462142601421;message-circle-dashed=78559601215727;message-circle-heart=122100978068245;message-circle-more=72969556529414;message-circle-off=106640802525475;message-circle-plus=97202853233666;message-circle-question=85003442346058;message-circle-reply=96024981688039;message-circle-warning=112239075926369;message-circle-x=104081317224904;message-square=86432989388834;message-square-code=139338315973052;message-square-dashed=127422492651127;message-square-diff=120745701209397;message-square-dot=131246995114947;message-square-heart=137436561363370;message-square-more=76812000893936;message-square-off=97376166485199;message-square-plus=77957118386462;message-square-quote=97203851012575;message-square-reply=138540430807955;message-square-share=94526690702300;message-square-text=128095657789286;message-square-warning=83694786088101;message-square-x=83972010967159;messages-square=112345482432498;mic=125870172276779;mic-2=79774423165436;mic-off=84064988822624;mic-vocal=116345765074785;microscope=134078584568005;microwave=109575331253451;milestone=88614752388873;milk=119818923307142;milk-off=72925919409773;minimize=95555494586098;minimize-2=96294437144715;minus=95070996149109;minus-circle=103303552772654;minus-square=96983863580751;monitor=70520152532392;monitor-check=112341875921743;monitor-dot=132673547251589;monitor-down=132502390896673;monitor-off=95048101284680;monitor-pause=99458637542686;monitor-play=107640137618506;monitor-smartphone=81757216234228;monitor-speaker=131099454095944;monitor-stop=99235976282671;monitor-up=116018518624879;monitor-x=102604336229610;moon=98353636264918;moon-star=137086737657962;more-horizontal=101330725759187;more-vertical=76302166494262;mountain=90592200130155;mountain-snow=111710418991773;mouse=122014945028597;mouse-pointer=113428527051320;mouse-pointer-2=84070353881242;mouse-pointer-click=81854854241463;mouse-pointer-square=112337311970951;mouse-pointer-square-dashed=80677641664079;move=77028714324861;move-3d=82487420092874;move-diagonal=111179404262244;move-diagonal-2=128492050787735;move-down=85099736811132;move-down-left=138054515129112;move-down-right=116621809745618;move-horizontal=136107424781093;move-left=89444723083105;move-right=133586722586273;move-up=76410952730524;move-up-left=102293680652367;move-up-right=88087592569369;move-vertical=92087242547029;music=132132095360900;music-2=121112248614371;music-3=75731760539974;music-4=122935411241955;navigation=76549947719521;navigation-2=127270865325663;navigation-2-off=74005663669130;navigation-off=96787422854853;network=110230147673946;newspaper=115179113478597;nfc=119131457808272;notebook=93996170225525;notebook-pen=70494109504383;notebook-tabs=113749031276097;notebook-text=86811328922423;notepad-text=104957079697866;notepad-text-dashed=113624610966525;nut=77621843968987;nut-off=84877157781266;octagon=103646759535962;octagon-alert=101226496664732;octagon-pause=127095623629829;octagon-x=103912968479362;option=77581357923982;orbit=79200159961573;outdent=136657573552804;package=106101842173393;package-2=76736374924338;package-check=100671298334773;package-minus=72114807005321;package-open=86470175749466;package-plus=74357376952178;package-search=108965513580143;package-x=80178189812476;paint-bucket=116536780343642;paint-roller=76545833297923;paintbrush=113234034461805;paintbrush-2=116925836096427;palette=127369887384101;palmtree=85651135388680;panel-bottom=86537618399617;panel-bottom-close=91281796987492;panel-bottom-dashed=130167117027190;panel-bottom-inactive=97483023786802;panel-bottom-open=86549932703136;panel-left=125599129725759;panel-left-close=106532774300164;panel-left-dashed=115976249358122;panel-left-inactive=102689057283340;panel-left-open=126704485649345;panel-right=83386566029978;panel-right-close=133236216519470;panel-right-dashed=138321632890167;panel-right-inactive=95197732140314;panel-right-open=107436518875633;panel-top=80001561556081;panel-top-close=124467779594157;panel-top-dashed=79452019243803;panel-top-inactive=135806161551683;panel-top-open=88468571469051;panels-left-bottom=100709335124708;panels-right-bottom=118563843738058;panels-top-left=119230493302275;paperclip=101144735754292;parentheses=117743859847736;parking-circle=132958171449207;parking-circle-off=90293787674695;parking-meter=95540023655686;parking-square=119709845027214;parking-square-off=111516007201199;party-popper=92886643958723;pause=79610666871575;pause-circle=121009275520669;pause-octagon=75691149975017;paw-print=97578437331341;pc-case=134071343822649;pen=101486948449510;pen-line=108991407462745;pen-square=124290018373176;pen-tool=126917951709518;pencil=113132794872298;pencil-line=97622550721067;pencil-ruler=83914055949508;pentagon=133006808893408;percent=138143948353522;percent-circle=120133426400204;percent-diamond=116484660741674;percent-square=123104718284792;person-standing=101118444346965;phone=110402416146068;phone-call=83844308787978;phone-forwarded=121647613341736;phone-incoming=80024725665109;phone-missed=79555645036339;phone-off=124218610436691;phone-outgoing=107942094735434;pi=94324814221349;pi-square=104995627137456;piano=119387553084830;pickaxe=111300940329486;picture-in-picture=131356651374909;picture-in-picture-2=82685697007608;pie-chart=102602815840153;piggy-bank=137519559090410;pilcrow=73426591830540;pilcrow-square=104294263901485;pill=102063979166015;pin=84152083728286;pin-off=79775551915820;pipette=104047428948587;pizza=137422469806542;plane=123931033451986;plane-landing=127564654216931;plane-takeoff=71424495151201;play=76386816441302;play-circle=94679908148591;play-square=88949301532557;plug=92495517782055;plug-2=90278231790155;plug-zap=120081085677067;plug-zap-2=114634662672913;plus=101123124881873;plus-circle=120968869021626;plus-square=110356023190006;pocket=84604104357709;pocket-knife=75327579226876;podcast=107827753005302;pointer=98931495397575;pointer-off=121208450103912;popcorn=131831744800890;popsicle=104185203372496;pound-sterling=104324833143828;power=89331085993646;power-circle=116376776686511;power-off=71082730746769;power-square=119684962977179;presentation=116401163910084;printer=71465784501775;projector=73231680903652;proportions=78144579158638;puzzle=117598556369229;pyramid=132485249599747;qr-code=113440393569209;quote=131322529504476;rabbit=114280087699339;radar=132868138496209;radiation=100877813176471;radical=108409175619446;radio=99420757373028;radio-receiver=121282639721016;radio-tower=88833838205757;radius=74995747675698;rail-symbol=97316226200213;rainbow=103765621191575;rat=87357329634876;ratio=93282099315884;receipt=92008292109070;receipt-cent=112492211580771;receipt-euro=133191175020669;receipt-indian-rupee=133266746153788;receipt-japanese-yen=124042872765776;receipt-pound-sterling=100101322122623;receipt-russian-ruble=121506664677675;receipt-swiss-franc=99002246681862;receipt-text=100006409297382;rectangle-ellipsis=107119201863591;rectangle-horizontal=138840515431449;rectangle-vertical=105899574411289;recycle=113939163175897;redo=109330889951617;redo-2=139377644547969;redo-dot=103006780441917;refresh-ccw=112330254035751;refresh-ccw-dot=82338761134697;refresh-cw=106497040962250;refresh-cw-off=70915551154203;refrigerator=112780018998815;regex=134026857287988;remove-formatting=138608399804923;repeat=88751041821881;repeat-1=83172378763568;repeat-2=103267027937654;replace=107047557421203;replace-all=100838712445846;reply=92729212112550;reply-all=89383445888953;rewind=112118266859844;ribbon=138074895056157;rocket=109537053598807;rocking-chair=78801538856684;roller-coaster=97027135474963;rotate-3d=97818595741565;rotate-ccw=75086444429266;rotate-ccw-square=109860100695153;rotate-cw=83145058297547;rotate-cw-square=125618900116298;route=92054788599928;route-off=84281383994516;router=137822323057124;rows=137919453076186;rows-2=95783038014917;rows-3=120887473789104;rows-4=116714271746099;rss=133733106949535;ruler=84633402845324;russian-ruble=126835196314974;sailboat=95990070790702;salad=126822773594847;sandwich=125331738014611;satellite=76405829153460;satellite-dish=80919601328215;save=122894934359450;save-all=130108174247404;scale=104058148891720;scale-3d=98514591753294;scaling=101030566996452;scan=125367266780285;scan-barcode=97414347978098;scan-eye=109514269737059;scan-face=98379048258175;scan-line=74491678843147;scan-search=133304136560518;scan-text=135056446730766;scatter-chart=74267179296978;school=127958337382355;school-2=85807427737192;scissors=105992192896067;scissors-line-dashed=136613376152055;scissors-square=74695197837525;scissors-square-dashed-bottom=107920465612561;screen-share=77511025094385;screen-share-off=121685614490746;scroll=120140373437385;scroll-text=93551675076113;search=72296609649861;search-check=135876289053244;search-code=96217854889522;search-slash=103651057689299;search-x=107116182495739;send=94849431195865;send-horizontal=71350661970492;send-to-back=128357510439179;separator-horizontal=138451510103519;separator-vertical=136594330269338;server=105706502741449;server-cog=100022312079887;server-crash=87758222542375;server-off=80255747106695;settings=106205298246017;settings-2=109485777305919;shapes=72318824907864;share=78225483239202;share-2=139712792470775;sheet=74805372511449;shell=103995324275618;shield=106509993556171;shield-alert=91754324662625;shield-ban=124352578023288;shield-check=71867984579031;shield-ellipsis=93065391097116;shield-half=123735656472960;shield-minus=80388855203128;shield-off=98525250043109;shield-plus=121205118266112;shield-question=114815120818758;shield-x=75826463279777;ship=98574156558498;ship-wheel=130141263234416;shirt=128162112866809;shopping-bag=121389568871142;shopping-basket=110161824939086;shopping-cart=79435149356304;shovel=96637119542790;shower-head=114908638980660;shrink=115135316516120;shrub=79864992147519;shuffle=103735725549548;sigma=74383416855806;sigma-square=132360260153111;signal=126197135689656;signal-high=93347669262895;signal-low=84665611291998;signal-medium=75062813653519;signal-zero=109850227743382;signpost=97962937781200;signpost-big=87216549939239;siren=81845882921662;skip-back=137660494219613;skip-forward=121822124041513;skull=101060850237115;slack=107723459729315;slash=77878973734361;slice=140518011325498;sliders=105166722651208;sliders-horizontal=125396339381135;sliders-vertical=75780544616650;smartphone=74962751233767;smartphone-charging=86644420255103;smartphone-nfc=121578015636822;smile=129431925610335;smile-plus=83315367165388;snail=104438747965017;snowflake=70879271596915;sofa=87577807512220;soup=123867447658880;space=86056382889566;spade=121221766194945;sparkle=83114431765537;sparkles=105634041692696;speaker=117894179084666;speech=86788645272110;spell-check=139048235918692;spell-check-2=77691901804556;spline=127621289965723;split=124184087776521;split-square-horizontal=71187946462875;split-square-vertical=77254227779817;spray-can=97652569554326;sprout=100976494216154;square=135105418501265;square-activity=123457120309378;square-arrow-down=116832660638208;square-arrow-down-left=90743878595626;square-arrow-down-right=111115470362134;square-arrow-left=118414350090559;square-arrow-out-down-left=118423572451505;square-arrow-out-down-right=82860326458804;square-arrow-out-up-left=107517171610982;square-arrow-out-up-right=96480170164917;square-arrow-right=137471464720012;square-arrow-up=130005030476582;square-arrow-up-left=103366812234876;square-arrow-up-right=80186154045078;square-asterisk=85576779554554;square-bottom-dashed-scissors=105977668655594;square-check=122631573561562;square-check-big=139404784607168;square-chevron-down=120680078209607;square-chevron-left=75397936728579;square-chevron-right=76189118488226;square-chevron-up=97181506287521;square-code=76845656194464;square-dashed-bottom=133040895929365;square-dashed-bottom-code=103061363625640;square-dashed-kanban=114545633956348;square-dashed-mouse-pointer=123670726680392;square-divide=107353979642451;square-dot=110899495515389;square-equal=124042600382551;square-function=83985860709793;square-gantt-chart=107284369076219;square-kanban=97476877950543;square-library=81887890003221;square-m=135912337332436;square-menu=135438142591878;square-minus=78721357781624;square-mouse-pointer=127552100194692;square-parking=91463654971693;square-parking-off=111927816549509;square-pen=71257379947442;square-percent=113289006657504;square-pi=132511605174622;square-pilcrow=87094629814766;square-play=138697695062525;square-plus=91942389112860;square-power=120703265040347;square-radical=134223878880054;square-scissors=78779074277571;square-sigma=94523643558062;square-slash=78987954134223;square-split-horizontal=125857047694996;square-split-vertical=126418050285776;square-stack=94687061933604;square-terminal=75828907654568;square-user=140235161621168;square-user-round=81288587564855;square-x=76206131996728;squircle=99439828273252;squirrel=120668151944533;stamp=85130810524517;star=72669221096319;star-half=80822269649856;star-off=120003686620511;step-back=120706787286328;step-forward=91046009066136;stethoscope=78571774060105;sticker=139865196874378;sticky-note=98432110278865;stop-circle=97489143368359;store=121962391563311;stretch-horizontal=78770748920269;stretch-vertical=85907320465911;strikethrough=90568214674515;subscript=82653949184992;subtitles=134234590631375;sun=139232691165198;sun-dim=131075444152110;sun-medium=112704797109150;sun-moon=121221641564933;sun-snow=83004210487318;sunrise=116733420530374;sunset=101740056345650;superscript=93191189359166;swatch-book=70990631477660;swiss-franc=72116456510352;switch-camera=124033626341331;sword=121406454377051;swords=99199363807265;syringe=86444160764731;table=100826532869925;table-2=129391889722576;table-cells-merge=118490713113220;table-cells-split=113945031629733;table-columns-split=79195518284331;table-properties=135976623395143;table-rows-split=126696533672175;tablet=90619723471983;tablet-smartphone=78186066591210;tablets=88043022962639;tag=75425807137911;tags=103166221753217;tally-1=90000711698807;tally-2=99935651880614;tally-3=98958831676946;tally-4=128656473677471;tally-5=101955254503648;tangent=103123484115035;target=121091323240554;telescope=103588488639070;tent=91768489962137;tent-tree=85050403463582;terminal=102379915564176;terminal-square=89706340938367;test-tube=139701481278358;test-tube-2=118913572969135;test-tube-diagonal=121621592892259;test-tubes=117323642962952;text=99369759989955;text-cursor=103697482936876;text-cursor-input=84912489891242;text-quote=102573021965795;text-search=114489224126711;text-select=99310852917353;theater=89919220874053;thermometer=90545345642681;thermometer-snowflake=138010690931368;thermometer-sun=82795165216031;thumbs-down=73778874448741;thumbs-up=96046658888813;ticket=126875062984266;ticket-check=117888043623314;ticket-minus=89176175166723;ticket-percent=88410626824232;ticket-plus=83968600419805;ticket-slash=79392492298521;ticket-x=86658718829072;timer=120164083411828;timer-off=116991705734594;timer-reset=79948324123231;toggle-left=105639191695402;toggle-right=129483325318573;tornado=93796857097422;torus=78822043673501;touchpad=112333029100357;touchpad-off=86546394503986;tower-control=128131047012652;toy-brick=81793486260595;tractor=87948191954230;traffic-cone=87190332091101;train-front=91480038985820;train-front-tunnel=77194453402235;train-track=105798879242186;tram-front=80023103356955;trash=94712995845562;trash-2=126010725826757;tree-deciduous=109951315210525;tree-palm=111070569131758;tree-pine=71580980892868;trees=79707751200645;trello=90438659765426;trending-down=122658819043338;trending-up=86000419326493;triangle=134878256295114;triangle-alert=91165848022002;triangle-right=105796120965583;trophy=113055182645565;truck=125468675952181;turtle=73899487161474;tv=130308429701946;tv-2=129500347007411;twitch=90697389361633;twitter=90424880717042;type=70694319369829;umbrella=108749598923776;umbrella-off=111820268638089;underline=127096081441525;undo=111464695038355;undo-2=87358323292564;undo-dot=102793353935041;unfold-horizontal=85781955020909;unfold-vertical=122887666597646;ungroup=76318446818069;university=102146636224428;unlink=102194562745333;unlink-2=108239607794680;unlock=110263656507369;unlock-keyhole=126931549237422;unplug=123150141199349;upload=118488857289315;upload-cloud=121807815408739;usb=75949167692936;user=114567720540659;user-2=92481398073007;user-check=75620511859505;user-check-2=73224920504446;user-circle=111917761312899;user-circle-2=96888447186214;user-cog=87518742987519;user-cog-2=115462370853742;user-minus=94865546608687;user-minus-2=93808234717021;user-plus=101184880550364;user-plus-2=104764183758140;user-round=119713822992150;user-round-check=99288072031664;user-round-cog=127120627937146;user-round-minus=129866427748569;user-round-plus=101991526004413;user-round-search=114857943818454;user-round-x=89227016198055;user-search=110388873642450;user-square=136305896243658;user-square-2=71391894371551;user-x=138436637971548;user-x-2=96976557144947;users=85332511060401;users-2=138651149526372;users-round=103880524805720;utensils=122537080261787;utensils-crossed=100229317932246;utility-pole=137834357386674;variable=73932604072578;vault=107415856993701;vegan=127691293819852;venetian-mask=84202958608655;vibrate=140427675871522;vibrate-off=102494346080496;video=99411215690870;video-off=81634790888002;videotape=92799250697204;view=102821349715124;voicemail=121299677348672;volume=127607149758269;volume-1=115207748957226;volume-2=129861259578431;volume-x=106700331106145;vote=137637654521705;wallet=132318555862654;wallet-2=120839431200970;wallet-cards=86866924072285;wallet-minimal=77655892701714;wallpaper=76631821212930;wand=95424916372879;wand-2=84750107238092;wand-sparkles=115623066336607;warehouse=126757874656976;washing-machine=72331434583186;watch=103181426780078;waves=98840358372718;waypoints=101997233404191;webcam=90027890284611;webhook=110638252405523;webhook-off=71995352392407;weight=79312026690586;wheat=115823998996262;wheat-off=110571881208127;whole-word=110504483563993;wifi=104941258142372;wifi-off=120795495190257;wind=86165302601843;wine=101623153529226;wine-off=131814228138093;workflow=78971198932745;worm=98855303743824;wrap-text=70866394776130;wrench=85345725497834;x=116396312853810;x-circle=111132030834422;x-octagon=105062643930018;x-square=115678228554812;youtube=134880265650906;zap=109718589733073;zap-off=115642996489807;zoom-in=135570550221809;zoom-out=100181096350591]]
end

Modules["Theme/Icons"] = function(import)
-- Icon system preserved from DeaUI: Lucide names, numeric ids, "rbx..." strings, aliases and the
-- optional sprite sheet (DeaUI-S/Icon/lucide-roblox.luau). Syntax is unchanged:
--   Icon = "home"  |  Icon = 1234567  |  Icon = "rbxassetid://1234567"
local Icons = {}

local catalog
local warned = {}

local ALIASES = {
	-- names from older Lucide releases (the catalog holds the current names)
	house = "home",
	["circle-alert"] = "alert-circle",
	["edit-3"] = "pen-line",
	edit = "square-pen",
	["edit-2"] = "pen",
	sidebar = "panel-left",
	funnel = "filter",
	["chart-line"] = "line-chart",
	["chart-column"] = "bar-chart-3",
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
		return "rbxassetid://" .. string.format("%d", name)
	end
	if string.find(name, "^rbx") or string.find(name, "^https?://") then
		return name
	end
	local source = load()
	local id = source[name] or source[ALIASES[name] or ""]
	if not id then
		if not warned[name] then
			warned[name] = true
			warn("[DeaUI-S] missing icon " .. tostring(name))
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
	for name in pairs(load()) do
		out[#out + 1] = name
	end
	for name in pairs(loadSprites()) do
		if load()[name] == nil then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

function Icons.Register(name, id)
	load()[name] = (string.gsub(tostring(id), "^rbxassetid://", ""))
end

-- Sets Image (and the sprite rectangle when the icon comes from the sprite sheet).
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

Modules["Theme/Theme"] = function(import)
local Signal = import("Core/Signal")
local Util = import("Core/Util")

--[[
	Design-token theme engine. A theme is a small core palette; every other token (hover colors,
	soft tints, raised surfaces...) is derived from it, so a custom Primary / Background / Surface
	override restyles the whole interface consistently. Components bind properties to token names:
	Theme.Bind(instance, "BackgroundColor3", "Surface") and are updated on every theme change.
]]
local Theme = { Changed = Signal.new(), SaveHook = nil }

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local function hex(value)
	return Util.FromHex(value) or WHITE
end
Theme.Hex = hex

local function mix(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
Theme.Mix = mix

local function luminance(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

Theme.Presets = {
	Midnight = {
		Background = "0B1220", Surface = "111A2C", Border = "1F2C48", Text = "E6EDF7", TextMuted = "9AA8C2",
		Primary = "3B82F6", Accent = "22D3EE", Success = "34D399", Warning = "FBBF24", Danger = "F87171", Info = "60A5FA", Overlay = "050810",
	},
	Obsidian = {
		Background = "0A0A0C", Surface = "131317", Border = "24242B", Text = "EDEDF1", TextMuted = "9A9AA6",
		Primary = "7C9CFF", Accent = "5EEAD4", Success = "4ADE80", Warning = "FBBF24", Danger = "F87171", Info = "7DD3FC", Overlay = "000000",
	},
	Emerald = {
		Background = "09130F", Surface = "0F1D18", Border = "1B332A", Text = "E4F3EC", TextMuted = "93B3A5",
		Primary = "10B981", Accent = "2DD4BF", Success = "34D399", Warning = "FBBF24", Danger = "F87171", Info = "38BDF8", Overlay = "020806",
	},
	Violet = {
		Background = "0F0B1B", Surface = "171229", Border = "2A2247", Text = "ECE8F8", TextMuted = "A59DC4",
		Primary = "8B5CF6", Accent = "C4B5FD", Success = "34D399", Warning = "FBBF24", Danger = "FB7185", Info = "93C5FD", Overlay = "05030C",
	},
	Light = {
		Light = true, Background = "F1F4F9", Surface = "FFFFFF", Border = "DCE2EC", Text = "111827", TextMuted = "5B6577",
		Primary = "2563EB", Accent = "0891B2", Success = "059669", Warning = "D97706", Danger = "DC2626", Info = "2563EB", Overlay = "0F172A",
	},
}
Theme.Order = { "Midnight", "Obsidian", "Emerald", "Violet", "Light" }

Theme.RarityColors = {
	Common = "9CA3AF", Uncommon = "4ADE80", Rare = "60A5FA", Epic = "A78BFA", Legendary = "FBBF24", Mythic = "F472B6", Secret = "22D3EE",
}
Theme.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local COLOR_KEYS = { "Background", "Surface", "Border", "Text", "TextMuted", "Primary", "Accent", "Success", "Warning", "Danger", "Info", "Overlay" }
local ALIAS = { Muted = "TextMuted" }

local state = { Name = "Midnight", Overrides = {}, Metrics = { Radius = 10, Spacing = 8, AnimationSpeed = 1 } }
local tokens = {}
local bound = setmetatable({}, { __mode = "k" })

local function derive()
	local base = Theme.Presets[state.Name] or Theme.Presets.Midnight
	local core = {}
	for _, key in ipairs(COLOR_KEYS) do
		core[key] = hex(state.Overrides[key] and state.Overrides[key] or base[key])
	end
	local light = base.Light == true
	local t = {}
	for key, value in pairs(core) do
		t[key] = value
	end
	t.Light = light
	t.Sidebar = light and mix(core.Background, core.Surface, 0.55) or mix(core.Background, BLACK, 0.28)
	t.SurfaceRaised = mix(core.Surface, core.Text, light and 0.035 or 0.05)
	t.SurfaceHover = mix(core.Surface, core.Text, light and 0.07 or 0.09)
	t.SurfacePressed = mix(core.Surface, core.Text, light and 0.11 or 0.13)
	t.BorderStrong = mix(core.Border, core.Text, 0.16)
	t.TextFaint = mix(core.TextMuted, core.Background, 0.45)
	t.PrimaryHover = light and mix(core.Primary, BLACK, 0.1) or mix(core.Primary, WHITE, 0.14)
	t.PrimaryPressed = light and mix(core.Primary, BLACK, 0.2) or mix(core.Primary, BLACK, 0.16)
	t.PrimaryText = luminance(core.Primary) > 0.62 and hex("0B1220") or WHITE
	t.PrimarySoft = mix(core.Surface, core.Primary, light and 0.12 or 0.2)
	t.PrimarySoftHover = mix(core.Surface, core.Primary, light and 0.2 or 0.32)
	t.DangerHover = light and mix(core.Danger, BLACK, 0.1) or mix(core.Danger, WHITE, 0.12)
	t.DangerPressed = mix(core.Danger, BLACK, 0.16)
	t.DangerText = luminance(core.Danger) > 0.62 and hex("0B1220") or WHITE
	t.AccentSoft = mix(core.Surface, core.Accent, light and 0.12 or 0.18)
	t.SuccessSoft = mix(core.Surface, core.Success, light and 0.14 or 0.16)
	t.WarningSoft = mix(core.Surface, core.Warning, light and 0.16 or 0.16)
	t.DangerSoft = mix(core.Surface, core.Danger, light and 0.12 or 0.16)
	t.InfoSoft = mix(core.Surface, core.Info, light and 0.12 or 0.16)
	t.Shadow = BLACK
	t.OverlayTransparency = light and 0.55 or 0.4
	t.Disabled = mix(core.TextMuted, core.Background, 0.5)
	tokens = t
end
derive()

function Theme.Token(name)
	return tokens[ALIAS[name] or name]
end

-- token name | Color3 | number | function(tokens) -> value
function Theme.Resolve(token)
	local kind = type(token)
	if kind == "string" then
		local value = tokens[ALIAS[token] or token]
		if value == nil then
			value = Theme.Rarity(token)
		end
		return value
	elseif kind == "function" then
		local ok, value = pcall(token, tokens)
		return ok and value or nil
	end
	return token
end

function Theme.Rarity(name)
	local value = Theme.RarityColors[name] or Theme.RarityColors[string.gsub(tostring(name), "^%l", string.upper)]
	if value == nil then
		return tokens.TextMuted
	end
	if typeof(value) == "Color3" then
		return value
	end
	return hex(value)
end

function Theme.AddRarity(name, color)
	if Theme.RarityColors[name] == nil then
		table.insert(Theme.RarityOrder, name)
	end
	Theme.RarityColors[name] = color
end

function Theme.Radius(kind)
	local base = state.Metrics.Radius
	if kind == "sm" then
		return math.max(2, math.floor(base * 0.6 + 0.5))
	elseif kind == "lg" then
		return math.floor(base * 1.4 + 0.5)
	elseif kind == "xl" then
		return math.floor(base * 1.9 + 0.5)
	elseif kind == "pill" then
		return 999
	elseif type(kind) == "number" then
		return kind
	end
	return base
end

function Theme.Space(multiplier)
	return math.floor(state.Metrics.Spacing * (multiplier or 1) + 0.5)
end

function Theme.Metrics()
	return Util.clone(state.Metrics)
end

-- Re-applies every binding (called after a theme change).
local function apply()
	for instance, map in pairs(bound) do
		for property, token in pairs(map) do
			if property == "__radius" then
				pcall(function()
					instance.CornerRadius = UDim.new(0, Theme.Radius(token))
				end)
			elseif property == "__fn" then
				for _, fn in ipairs(token) do
					pcall(fn, tokens)
				end
			else
				local value = Theme.Resolve(token)
				if value ~= nil then
					pcall(function()
						instance[property] = value
					end)
				end
			end
		end
	end
end

-- skipApply: only register the binding (the caller animates the property itself).
function Theme.Bind(instance, property, token, skipApply)
	local map = bound[instance]
	if not map then
		map = {}
		bound[instance] = map
	end
	map[property] = token
	if skipApply then
		return
	end
	local value = Theme.Resolve(token)
	if value ~= nil then
		instance[property] = value
	end
end

-- UICorner radius that follows the theme radius scale ("sm" | "md" | "lg" | "xl" | "pill" | pixels).
function Theme.BindRadius(corner, kind)
	local map = bound[corner]
	if not map then
		map = {}
		bound[corner] = map
	end
	map.__radius = kind or "md"
	corner.CornerRadius = UDim.new(0, Theme.Radius(kind or "md"))
end

-- Runs fn(tokens) now and after every theme change (for properties that depend on several tokens).
function Theme.OnChange(instance, fn)
	local map = bound[instance]
	if not map then
		map = {}
		bound[instance] = map
	end
	map.__fn = map.__fn or {}
	table.insert(map.__fn, fn)
	fn(tokens)
end

function Theme.Unbind(instance, property)
	local map = bound[instance]
	if map then
		if property then
			map[property] = nil
		else
			bound[instance] = nil
		end
	end
end

local function changed(silent)
	derive()
	apply()
	if not silent then
		if Theme.SaveHook then
			pcall(Theme.SaveHook)
		end
		Theme.Changed:Fire(state.Name)
	end
end

function Theme.Names()
	local out = {}
	for _, name in ipairs(Theme.Order) do
		out[#out + 1] = name
	end
	return out
end

function Theme.Get()
	return state.Name
end

function Theme.IsLight()
	return tokens.Light == true
end

-- Switching the preset drops the color overrides unless keepOverrides is true.
function Theme.Set(name, silent, keepOverrides)
	if type(name) ~= "string" or not Theme.Presets[name] then
		return false
	end
	state.Name = name
	if not keepOverrides then
		state.Overrides = {}
	end
	changed(silent)
	return true
end

-- Theme.Override({ Primary = Color3|"#hex", Accent, Background, Surface, Border, Text, Muted, Radius, Spacing, AnimationSpeed })
function Theme.Override(map, silent)
	if type(map) ~= "table" then
		return false
	end
	for key, value in pairs(map) do
		key = ALIAS[key] or key
		if key == "Radius" or key == "Spacing" or key == "AnimationSpeed" then
			if type(value) == "number" then
				state.Metrics[key] = key == "AnimationSpeed" and Util.clamp(value, 0.25, 3) or Util.clamp(value, key == "Radius" and 0 or 4, key == "Radius" and 24 or 16)
			end
		elseif Theme.Presets.Midnight[key] ~= nil and key ~= "Light" then
			if typeof(value) == "Color3" then
				state.Overrides[key] = Util.Hex(value)
			elseif type(value) == "string" and Util.FromHex(value) then
				state.Overrides[key] = value
			elseif value == false or value == "" then
				state.Overrides[key] = nil
			end
		end
	end
	changed(silent)
	return true
end

function Theme.GetOverrides()
	local out = {}
	for key, value in pairs(state.Overrides) do
		out[key] = value
	end
	return out
end

function Theme.Reset(silent)
	state.Overrides = {}
	state.Metrics = { Radius = 10, Spacing = 8, AnimationSpeed = 1 }
	changed(silent)
end

-- Serializable snapshot: { Base = "Midnight", Colors = { Primary = "#3B82F6" }, Radius = 10, ... }
function Theme.Serialize()
	local colors = {}
	for key, value in pairs(state.Overrides) do
		colors[key] = value
	end
	return { Base = state.Name, Colors = colors, Radius = state.Metrics.Radius, Spacing = state.Metrics.Spacing, AnimationSpeed = state.Metrics.AnimationSpeed }
end

function Theme.Load(data, silent)
	if type(data) ~= "table" then
		return false
	end
	local name = Theme.Presets[data.Base] and data.Base or state.Name
	state.Name = name
	state.Overrides = {}
	local map = {}
	if type(data.Colors) == "table" then
		for key, value in pairs(data.Colors) do
			map[key] = value
		end
	end
	for _, key in ipairs({ "Radius", "Spacing", "AnimationSpeed" }) do
		if type(data[key]) == "number" then
			map[key] = data[key]
		end
	end
	return Theme.Override(map, silent)
end

-- Fonts (BuilderSans handles Vietnamese diacritics; preserved from DeaUI)
Theme.Font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)
Theme.FontMedium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
Theme.FontBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
do
	local ok, mono = pcall(function()
		return Font.fromEnum(Enum.Font.RobotoMono)
	end)
	if ok and mono then
		Theme.Mono = mono
		Theme.MonoBold = Font.new(mono.Family, Enum.FontWeight.Bold, mono.Style)
	else
		Theme.Mono, Theme.MonoBold = Theme.Font, Theme.FontBold
	end
end

function Theme.FontFor(weight, mono)
	if mono then
		return weight == "Bold" and Theme.MonoBold or Theme.Mono
	end
	if weight == "Bold" then
		return Theme.FontBold
	elseif weight == "Medium" then
		return Theme.FontMedium
	end
	return Theme.Font
end

return Theme
end

Modules["UI/Assets"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Icons = import("Theme/Icons")
local Anim = import("Animation")
local Kit = import("UI/Kit")
local Env = import("Core/Env")
local Input = import("Core/Input")
local Services = import("Core/Services")
local Persistence = import("Storage/Persistence")
local Util = import("Core/Util")

--[[
	Assets: image / 3D model previews and optional discovery of preview-able objects.
	  Assets.Image(parent, o)   rounded image with loading / error / empty states and a rarity border
	  Assets.Model(parent, o)   ViewportFrame preview of a CLONE of a Model / BasePart (scripts stripped, slow auto rotation)
	  Assets.Discover(o, cb)    lists Models / Parts found in developer chosen containers (metadata only)
	Discovery is separate from rendering: it returns plain tables, the previews only render what they are given.
]]
local Assets = { Cache = {}, MaxRotating = 12, Enabled3D = true }

function Assets.Thumb(kind, id, size)
	size = size or 150
	return string.format("rbxthumb://type=%s&id=%d&w=%d&h=%d", kind or "Asset", id, size, size)
end

-- Returns content, kind ("content" | "url" | "icon") or nil.
function Assets.Resolve(source)
	if source == nil or source == "" then
		return nil
	end
	if type(source) == "number" then
		return "rbxassetid://" .. string.format("%d", source), "content"
	end
	if type(source) ~= "string" then
		return nil
	end
	if string.find(source, "^rbx") then
		return source, "content"
	end
	if string.match(source, "^%d+$") then
		return "rbxassetid://" .. source, "content"
	end
	if string.find(source, "^https?://") then
		if string.find(source, "roblox%.com/asset") then
			return source, "content"
		end
		return source, "url"
	end
	return source, "icon"
end

local pending = {}

-- Downloads an image URL into DeaUI-S/Cache/AssetCache and returns a custom asset id (executor only).
function Assets.Download(url, callback)
	if not (Env.getCustomAsset and Env.writefile and Persistence.Available()) then
		callback(nil, "unsupported")
		return
	end
	local extension = string.lower(string.match(url, "%.(%a%a%a%a?)[%?#]") or string.match(url, "%.(%a%a%a%a?)$") or "png")
	if extension ~= "png" and extension ~= "jpg" and extension ~= "jpeg" and extension ~= "webp" then
		extension = "png"
	end
	local relative = "Cache/AssetCache/" .. Util.hash(url) .. "." .. extension
	local path = Env.Path(relative)
	local function content()
		local ok, id = pcall(Env.getCustomAsset, path)
		if ok and type(id) == "string" and id ~= "" then
			return id
		end
		return nil
	end
	if Env.Exists(path) then
		callback(content(), content() and nil or "failed")
		return
	end
	if pending[url] then
		table.insert(pending[url], callback)
		return
	end
	pending[url] = { callback }
	task.spawn(function()
		local body, reason = Env.HttpGet(url)
		local id
		if body and #body > 0 and #body < 6 * 1024 * 1024 and Env.Write(path, body) then
			id = content()
		end
		local callbacks = pending[url]
		pending[url] = nil
		for _, fn in ipairs(callbacks or {}) do
			fn(id, id and nil or (reason or "failed"))
		end
	end)
end

local function preload(image, content, done)
	local known = Assets.Cache[content]
	if known ~= nil then
		done(known)
		return
	end
	task.spawn(function()
		local failed = false
		local ok = pcall(function()
			Services.ContentProvider:PreloadAsync({ image }, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then
					failed = true
				end
			end)
		end)
		local result = ok and not failed
		local count = 0
		for _ in pairs(Assets.Cache) do
			count = count + 1
		end
		if count > 400 then
			Assets.Cache = {}
		end
		Assets.Cache[content] = result
		done(result)
	end)
end

-- Image preview ----------------------------------------------------------------------------------------------------
local ImageClass = Kit.Class()

function ImageClass:SetState(state)
	self.State = state
	self.Placeholder.Visible = state == "empty" or state == "error"
	if self.Spinner then
		self.Spinner.Visible = state == "loading"
	elseif state == "loading" then
		self.Spinner = Kit.Spinner(self.Frame, 18, "TextMuted", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	end
	if state == "error" then
		Kit.SetIcon(self.Placeholder, "image-off")
		Theme.Bind(self.Placeholder, "ImageColor3", "Danger")
	elseif state == "empty" then
		Kit.SetIcon(self.Placeholder, self.PlaceholderIcon)
		Theme.Bind(self.Placeholder, "ImageColor3", "TextFaint")
	end
	if state == "loaded" then
		Anim.Tween(self.Picture, { ImageTransparency = 0 }, "base")
	else
		Anim.Cancel(self.Picture)
		self.Picture.ImageTransparency = 1
	end
end

-- "Crop" (fill, default) | "Fit" (whole image visible) | "Stretch"
function ImageClass:SetScaleType(name)
	local map = { crop = Enum.ScaleType.Crop, fit = Enum.ScaleType.Fit, stretch = Enum.ScaleType.Stretch }
	self.ScaleType = map[string.lower(tostring(name))] or Enum.ScaleType.Crop
	if self.Picture.ImageColor3 == Color3.new(1, 1, 1) then
		self.Picture.ScaleType = self.ScaleType
	end
end

function ImageClass:SetRarity(rarity)
	self.Rarity = rarity
	if rarity then
		Theme.Bind(self.Stroke, "Color", function()
			return Theme.Rarity(rarity)
		end)
		self.Stroke.Thickness = 1.5
	else
		Theme.Bind(self.Stroke, "Color", "Border")
		self.Stroke.Thickness = 1
	end
end

function ImageClass:Set(source)
	self.Token = self.Token + 1
	local token = self.Token
	local content, kind = Assets.Resolve(source)
	if not content then
		self:SetState("empty")
		return
	end
	local picture = self.Picture
	if kind == "icon" then
		Icons.Apply(picture, content)
		picture.ScaleType = Enum.ScaleType.Fit
		Theme.Bind(picture, "ImageColor3", "TextMuted")
		self:SetState("loaded")
		return
	end
	picture.ImageColor3 = Color3.new(1, 1, 1)
	Theme.Unbind(picture, "ImageColor3")
	picture.ScaleType = self.ScaleType
	local function show(id)
		if token ~= self.Token or self.Destroyed then
			return
		end
		picture.Image = id
		self:SetState("loading")
		preload(picture, id, function(ok)
			if token == self.Token and not self.Destroyed then
				self:SetState(ok and "loaded" or "error")
			end
		end)
	end
	if kind == "url" then
		self:SetState("loading")
		Assets.Download(content, function(id)
			if token ~= self.Token or self.Destroyed then
				return
			end
			if id then
				show(id)
			else
				self:SetState("error")
			end
		end)
	else
		show(content)
	end
end

-- o: Source, Size, Position, Radius, Fit (ScaleType Fit instead of Crop), Rarity, Placeholder (icon), Token, Order
function Assets.Image(parent, o)
	o = o or {}
	local frame = Kit.Panel(parent, { Name = "Image", Size = o.Size or UDim2.fromScale(1, 1), Position = o.Position, AnchorPoint = o.AnchorPoint, Order = o.Order, Token = o.Token or "SurfaceRaised", Radius = o.Radius or "md", Stroke = false, Clip = true })
	local picture = Create.New("ImageLabel", { Name = "Picture", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ImageTransparency = 1, ZIndex = 2, Parent = frame })
	local placeholder = Kit.Icon(frame, o.Placeholder or "image", 22, "TextFaint", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 2 })
	local stroke = Create.Stroke(frame, "Border")
	local object = Kit.New(ImageClass, frame, {
		Picture = picture, Placeholder = placeholder, Stroke = stroke, Token = 0, PlaceholderIcon = o.Placeholder or "image",
		ScaleType = o.Fit and Enum.ScaleType.Fit or Enum.ScaleType.Crop,
	})
	object:SetScaleType(o.ScaleType or (o.Fit and "Fit") or "Crop")
	object:SetRarity(o.Rarity)
	object:Set(o.Source)
	return object
end

-- Model preview ------------------------------------------------------------------------------------------------------
local ModelClass = Kit.Class()
local previews = {}
local previewLink
local previewClock = 0

local function aim(preview)
	local center, radius = preview.Center, preview.Radius
	local fov = preview.Camera.FieldOfView
	local distance = radius / math.sin(math.rad(fov / 2)) * preview.Zoom
	local pitch = preview.Pitch
	local offset = Vector3.new(math.sin(preview.Yaw) * math.cos(pitch), math.sin(pitch), math.cos(preview.Yaw) * math.cos(pitch)) * distance
	preview.Camera.CFrame = CFrame.lookAt(center + offset, center)
end

local function rotateStep(dt)
	previewClock = previewClock + dt
	if previewClock < 1 / 30 then
		return
	end
	local step = previewClock
	previewClock = 0
	local rotating = 0
	for preview in pairs(previews) do
		if preview.Destroyed or not preview.Viewport.Parent then
			previews[preview] = nil
		elseif preview.AutoRotate and preview.Center and Anim.Enabled() and not preview.Dragging then
			rotating = rotating + 1
			if rotating <= Assets.MaxRotating then
				preview.Yaw = preview.Yaw + step * 0.8
				aim(preview)
			end
		end
	end
	if next(previews) == nil and previewLink then
		previewLink:Disconnect()
		previewLink = nil
	end
end

function ModelClass:Clear()
	if self.Clone then
		self.Clone:Destroy()
		self.Clone = nil
	end
	self.Center = nil
	self.BaseSize = nil
end

-- Previews a clone of `source` (Model, BasePart, or any object that contains parts).
function ModelClass:SetModel(source)
	self:Clear()
	if source == nil then
		self.Placeholder.Visible = true
		Kit.SetIcon(self.Placeholder, "box")
		return false
	end
	local ok, clone = pcall(function()
		return source:Clone()
	end)
	if not ok or typeof(clone) ~= "Instance" then
		self.Placeholder.Visible = true
		Kit.SetIcon(self.Placeholder, "image-off")
		Theme.Bind(self.Placeholder, "ImageColor3", "Danger")
		return false
	end
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	local target = clone
	if not (clone:IsA("Model") or clone:IsA("BasePart")) then
		target = Instance.new("Model")
		clone.Parent = target
	end
	target.Parent = self.Viewport
	self.Clone = target
	if self.ModelScale ~= 1 then
		self:_applyScale()
	end
	return self:_measure()
end

-- Bounding box -> camera target; false (placeholder) when the object has no visible size.
function ModelClass:_measure()
	local target = self.Clone
	if not target then
		return false
	end
	local boxOk, cf, size
	if target:IsA("BasePart") then
		boxOk, cf, size = true, target.CFrame, target.Size
	else
		boxOk, cf, size = pcall(function()
			return target:GetBoundingBox()
		end)
	end
	if not boxOk or typeof(size) ~= "Vector3" or size.Magnitude == 0 then
		target:Destroy()
		self.Clone, self.Center = nil, nil
		self.Placeholder.Visible = true
		Kit.SetIcon(self.Placeholder, "image-off")
		return false
	end
	self.Center = cf.Position
	self.Radius = size.Magnitude / 2
	self.Placeholder.Visible = false
	aim(self)
	return true
end

function ModelClass:_applyScale()
	local target = self.Clone
	if not target then
		return
	end
	if target:IsA("Model") then
		pcall(function()
			target:ScaleTo(self.ModelScale)
		end)
	elseif target:IsA("BasePart") then
		target.Size = (self.BaseSize or target.Size) * self.ModelScale
	end
end

-- Camera distance multiplier (1.1 = tight, larger = further away)
function ModelClass:SetZoom(zoom)
	self.Zoom = Util.clamp(tonumber(zoom) or 1.1, 0.3, 5)
	if self.Center then
		aim(self)
	end
end

function ModelClass:SetFieldOfView(fov)
	self.Camera.FieldOfView = Util.clamp(tonumber(fov) or 35, 10, 90)
	if self.Center then
		aim(self)
	end
end

-- Manual rotation in degrees (yaw around the model, pitch up/down)
function ModelClass:SetRotation(yaw, pitch)
	self.Yaw = math.rad(tonumber(yaw) or 0)
	if pitch ~= nil then
		self.Pitch = Util.clamp(math.rad(tonumber(pitch) or 0), -1.3, 1.3)
	end
	if self.Center then
		aim(self)
	end
end

-- { Ambient = Color3, LightColor = Color3, LightDirection = Vector3 }
function ModelClass:SetLighting(map)
	for _, key in ipairs({ "Ambient", "LightColor", "LightDirection" }) do
		if map[key] ~= nil then
			self.Viewport[key] = map[key]
		end
	end
end

-- Color3 | theme token name | nil (theme surface), plus optional transparency
function ModelClass:SetBackground(color, transparency)
	if typeof(color) == "Color3" then
		Theme.Unbind(self.Frame, "BackgroundColor3")
		self.Frame.BackgroundColor3 = color
	else
		Theme.Bind(self.Frame, "BackgroundColor3", color or "SurfaceRaised")
	end
	self.Frame.BackgroundTransparency = transparency or 0
end

-- Scales the preview model (Model:ScaleTo, or the part size) and re-frames the camera.
function ModelClass:SetModelScale(scale)
	self.ModelScale = Util.clamp(tonumber(scale) or 1, 0.05, 20)
	if self.Clone then
		if self.Clone:IsA("BasePart") and not self.BaseSize then
			self.BaseSize = self.Clone.Size
		end
		self:_applyScale()
		self:_measure()
	end
end

function ModelClass:SetRotating(enabled)
	self.AutoRotate = enabled == true
end

function ModelClass:SetRarity(rarity)
	if rarity then
		Theme.Bind(self.Stroke, "Color", function()
			return Theme.Rarity(rarity)
		end)
		self.Stroke.Thickness = 1.5
	else
		Theme.Bind(self.Stroke, "Color", "Border")
		self.Stroke.Thickness = 1
	end
end

function ModelClass:OnDestroy()
	previews[self] = nil
end

-- o: Model, Size, Position, Radius, Rarity, AutoRotate (default true), Zoom (1.0 = tight), FieldOfView, Scale, Background, Lighting, Interactive (drag to rotate), Token
function Assets.Model(parent, o)
	o = o or {}
	if not Assets.Enabled3D then
		-- ViewportFrames switched off (Init option ModelPreviews = false): a static placeholder keeps the layout intact
		local frame = Kit.Panel(parent, { Name = "ModelPreview", Size = o.Size or UDim2.fromScale(1, 1), Position = o.Position, AnchorPoint = o.AnchorPoint, Order = o.Order, Token = o.Token or "SurfaceRaised", Radius = o.Radius or "md", Stroke = false, Clip = true })
		local placeholder = Kit.Icon(frame, "box", 22, "TextFaint", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		local stroke = Create.Stroke(frame, "Border")
		local object = Kit.New(ModelClass, frame, { Placeholder = placeholder, Stroke = stroke })
		function object:SetModel()
			return false
		end
		function object:SetRotating() end
		return object
	end
	local frame = Kit.Panel(parent, { Name = "ModelPreview", Size = o.Size or UDim2.fromScale(1, 1), Position = o.Position, AnchorPoint = o.AnchorPoint, Order = o.Order, Token = o.Token or "SurfaceRaised", Radius = o.Radius or "md", Stroke = false, Clip = true })
	local viewport = Create.New("ViewportFrame", {
		Name = "Viewport", Size = UDim2.fromScale(1, 1), ZIndex = 2,
		Ambient = Color3.fromRGB(190, 190, 205), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1.2, -0.6), Parent = frame,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = o.FieldOfView or 35
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local placeholder = Kit.Icon(frame, "box", 22, "TextFaint", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 1 })
	local stroke = Create.Stroke(frame, "Border")
	local object = Kit.New(ModelClass, frame, {
		Viewport = viewport, Camera = camera, Placeholder = placeholder, Stroke = stroke, Yaw = 0.6, Pitch = 0.35, Zoom = o.Zoom or 1.1, AutoRotate = o.AutoRotate ~= false, ModelScale = o.Scale or 1,
	})
	object:SetRarity(o.Rarity)
	if o.Background ~= nil then
		object:SetBackground(o.Background, o.BackgroundTransparency)
	end
	if o.Lighting then
		object:SetLighting(o.Lighting)
	end
	object:SetModel(o.Model)
	if o.Interactive then
		local scroller
		local startYaw, startPitch
		object.Scope:Add(Input.Drag(frame, {
			Begin = function()
				startYaw, startPitch = object.Yaw, object.Pitch
				object.Dragging = true
				scroller = Kit.ScrollParent(frame)
				if scroller then
					scroller.ScrollingEnabled = false
				end
			end,
			Move = function(delta)
				object.Yaw = startYaw - delta.X * 0.012
				object.Pitch = Util.clamp(startPitch + delta.Y * 0.008, -1.3, 1.3)
				if object.Center then
					aim(object)
				end
			end,
			End = function()
				object.Dragging = false
				if scroller then
					scroller.ScrollingEnabled = true
					scroller = nil
				end
			end,
		}))
	end
	previews[object] = true
	if not previewLink then
		previewLink = Services.RunService.RenderStepped:Connect(rotateStep)
	end
	return object
end

function Assets.StopPreviews()
	previews = {}
	if previewLink then
		previewLink:Disconnect()
		previewLink = nil
	end
end

-- Discovery ---------------------------------------------------------------------------------------------------------------
-- o: Containers (list of Instances), Classes (default { "Model", "BasePart" }), Recursive (default true), Filter(instance) -> bool,
--    Limit (default 200), Sort (default true)
-- Without a callback the scan runs immediately; with a callback it runs in a thread and yields so the UI never freezes.
-- Metadata read from attributes when present: Rarity, Image, Description, DisplayName.
function Assets.Discover(o, callback)
	o = o or {}
	local classes = o.Classes or { "Model", "BasePart" }
	local limit = o.Limit or 200
	local cancelled = false
	local function matches(instance)
		for _, class in ipairs(classes) do
			if instance:IsA(class) then
				return true
			end
		end
		return false
	end
	local function scan()
		local list, seen, visited = {}, {}, 0
		local errors = 0
		for _, container in ipairs(o.Containers or {}) do
			if typeof(container) == "Instance" then
				local ok, nodes = pcall(function()
					return o.Recursive == false and container:GetChildren() or container:GetDescendants()
				end)
				if not ok then
					errors = errors + 1
					nodes = {}
				end
				for _, node in ipairs(nodes) do
					if cancelled or #list >= limit then
						break
					end
					visited = visited + 1
					if callback and visited % 150 == 0 then
						task.wait()
					end
					local good = false
					pcall(function()
						good = matches(node) and node.Archivable ~= false and not seen[node] and (not o.Filter or o.Filter(node))
					end)
					if good then
						seen[node] = true
						local function attribute(name)
							local fine, value = pcall(function()
								return node:GetAttribute(name)
							end)
							return fine and value or nil
						end
						local path = node.Name
						pcall(function()
							path = node:GetFullName()
						end)
						list[#list + 1] = {
							Id = path, Name = attribute("DisplayName") or node.Name, Instance = node, Class = node.ClassName, Path = path,
							Rarity = attribute("Rarity"), Image = attribute("Image"), Description = attribute("Description"),
						}
					end
				end
			end
		end
		if o.Sort ~= false then
			table.sort(list, function(a, b)
				return tostring(a.Name) < tostring(b.Name)
			end)
		end
		return list, errors > 0 and #list == 0 and "unavailable" or nil
	end
	if not callback then
		return scan()
	end
	task.spawn(function()
		local ok, list, reason = pcall(scan)
		if cancelled then
			return
		end
		if ok then
			callback(list, reason)
		else
			callback({}, "unavailable")
		end
	end)
	return {
		Cancel = function()
			cancelled = true
		end,
	}
end

return Assets
end

Modules["UI/Blocks"] = function(import)
local Layout = import("UI/Layout")
local Kit = import("UI/Kit")
local Dashboard = import("UI/Dashboard")
local Cards = import("UI/Cards")
local Gallery = import("UI/Gallery")
local Widgets = import("UI/Widgets")
local Assets = import("UI/Assets")
local Util = import("Core/Util")

-- Registers every block as a method of Page and Group:
--   StatCard StatGrid CurrencyDisplay LevelDisplay MultiplierDisplay ActivityFeed
--   PetCard ItemCard EggCard QuestCard UpgradeCard WorldCard ZoneCard CardGrid
--   AssetGallery AssetBrowser QueueList Timer LoadingIndicator EmptyState SearchBar Image ModelPreview
local B = {}

for _, module in ipairs({ Dashboard, Cards, Gallery }) do
	for name, constructor in pairs(module.Blocks) do
		B[name] = constructor
	end
end

local function wrap(name, builder)
	B[name] = function(container, options)
		local holder = Kit.BlockHolder(container, { Name = name })
		local object = builder(holder, options or {})
		object.Scope:Add(function()
			holder:Destroy()
		end)
		return object
	end
end

wrap("EmptyState", Widgets.EmptyState)
wrap("LoadingIndicator", Widgets.LoadingIndicator)
wrap("SearchBar", Widgets.SearchBar)
wrap("Timer", Widgets.Timer)
wrap("QueueList", Widgets.QueueList)

-- Image / ModelPreview: o.Height (default 140) and the options of Assets.Image / Assets.Model
wrap("Image", function(holder, o)
	local frame = Kit.Panel(holder, { Name = "ImageBlock", Size = UDim2.new(1, 0, 0, o.Height or 140), Stroke = false })
	frame.BackgroundTransparency = 1
	local image = Assets.Image(frame, Util.merge(o, { Source = o.Source or o.Image, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }))
	image.Scope:Add(function()
		frame:Destroy()
	end)
	return image
end)
wrap("ModelPreview", function(holder, o)
	local frame = Kit.Panel(holder, { Name = "ModelBlock", Size = UDim2.new(1, 0, 0, o.Height or 180), Stroke = false })
	frame.BackgroundTransparency = 1
	local preview = Assets.Model(frame, Util.merge(o, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }))
	preview.Scope:Add(function()
		frame:Destroy()
	end)
	return preview
end)

Layout.AttachBlocks(B)

return B
end

Modules["UI/Cards"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Assets = import("UI/Assets")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

--[[
	Simulator cards: PetCard, ItemCard, EggCard, QuestCard, UpgradeCard, WorldCard, ZoneCard.
	One builder renders them all (media + title + chips + progress + cost + action buttons), the
	presets only decide the chips, the default actions and the layout. A card never talks to the game:
	pressing a button calls your Callback(card, actionId); card:Set({ ... }) updates what it shows.
]]
local Cards = { Blocks = {} }
local Card = Kit.Class()

local function rarityText(rarity)
	local key = "rarity." .. string.lower(tostring(rarity))
	return Loc.Known(key) and key or tostring(rarity)
end

-- Chips (small badges) per card kind ---------------------------------------------------------------------------------
local function chips(kind, d)
	local out = {}
	local function add(text, icon, tone, color)
		out[#out + 1] = { Text = text, Icon = icon, Kind = tone or "muted", Color = color }
	end
	if d.Rarity and kind ~= "quest" and kind ~= "upgrade" then
		add(rarityText(d.Rarity), nil, nil, Theme.Rarity(d.Rarity))
	end
	if kind == "pet" then
		if d.Level then add("Lv " .. d.Level, "star", "info") end
		if d.Power then add(Util.Format.Compact(d.Power), "zap", "warn") end
		if d.Multiplier then add("x" .. Util.Format.Compact(d.Multiplier, 2), "trending-up", "accent") end
	elseif kind == "item" then
		if d.Amount then add("x" .. Util.Format.Compact(d.Amount), "package", "info") end
		if d.Value then add(Util.Format.Compact(d.Value), "coins", "warn") end
	elseif kind == "egg" then
		if d.Luck then add("x" .. Util.Format.Compact(d.Luck, 2), "clover", "success") end
		if d.Hatches then add(tostring(d.Hatches), "egg", "info") end
	elseif kind == "quest" then
		local status = string.lower(tostring(d.Status or "active"))
		add("quest." .. status, status == "claimed" and "check" or (status == "completed" and "gift" or "clock"), status == "claimed" and "muted" or (status == "completed" and "success" or "info"))
	elseif kind == "upgrade" then
		if d.Level then add("Lv " .. d.Level .. (d.MaxLevel and ("/" .. d.MaxLevel) or ""), "arrow-up-circle", d.Maxed and "success" or "info") end
		if d.Maxed then add("upgrade.maxed", "check", "success") end
	elseif kind == "world" then
		if d.Requirement then add(d.Requirement, "lock", d.Locked and "warn" or "muted") end
		if d.Current then add("world.current", "map-pin", "success") end
	elseif kind == "zone" then
		if d.Difficulty then add(d.Difficulty, "skull", "warn") end
		if d.Multiplier then add("x" .. Util.Format.Compact(d.Multiplier, 2), "trending-up", "accent") end
		if d.Players then add(tostring(d.Players), "users", "info") end
	end
	for _, extra in ipairs(d.Meta or {}) do
		add(extra.Text, extra.Icon, extra.Kind, extra.Color)
	end
	return out
end

-- Default actions per kind (buttons) --------------------------------------------------------------------------------------
local function actions(kind, d)
	if d.Actions then
		return d.Actions
	end
	if kind == "pet" then
		return { { Id = d.Equipped and "unequip" or "equip", Text = d.Equipped and "common.unequip" or "common.equip", Variant = d.Equipped and "secondary" or "primary" } }
	elseif kind == "egg" then
		return { { Id = "hatch", Text = d.ActionText or "egg.hatch", Icon = "egg", Variant = "primary" } }
	elseif kind == "quest" then
		local status = string.lower(tostring(d.Status or "active"))
		if status == "claimed" then
			return {}
		end
		return { { Id = "claim", Text = "common.claim", Icon = "gift", Variant = "primary", Disabled = status ~= "completed" } }
	elseif kind == "upgrade" then
		return { { Id = "buy", Text = d.Maxed and "common.max" or "common.buy", Variant = "primary", Disabled = d.Maxed or d.Affordable == false } }
	elseif kind == "world" then
		return { { Id = "travel", Text = d.Current and "world.current" or "common.travel", Icon = "map-pin", Variant = "primary", Disabled = d.Locked or d.Current } }
	elseif kind == "zone" then
		return { { Id = "select", Text = d.ActionText or "common.select", Variant = "primary", Disabled = d.Locked } }
	end
	return {}
end

function Card:Get()
	return Util.clone(self.Data)
end

function Card:Set(patch)
	for key, value in pairs(patch) do
		self.Data[key] = value
	end
	self:Refresh(patch)
end

function Card:SetSelected(selected)
	self.Data.Selected = selected == true
	self:_style()
end

function Card:SetLocked(locked, text)
	self.Data.Locked = locked == true
	if text ~= nil then
		self.Data.LockText = text
	end
	self:Refresh({ Locked = true })
end

function Card:_style()
	local d = self.Data
	self.Stroke.Thickness = d.Selected and 2 or 1
	Anim.Token(self.Stroke, "Color", d.Selected and "Primary" or "Border", "fast")
	self.Equipped.Visible = d.Equipped == true
end

function Card:Refresh(patch)
	local d, kind = self.Data, self.Kind
	patch = patch or {}
	if patch.Name ~= nil or patch.Title ~= nil or patch.First then
		Kit.SetText(self.TitleLabel, d.Name or d.Title or "")
	end
	if patch.Subtitle ~= nil or patch.Description ~= nil or patch.First then
		local sub = d.Subtitle or d.Description
		Kit.SetText(self.SubLabel, sub or "")
		self.SubLabel.Visible = sub ~= nil and sub ~= ""
	end
	if patch.Image ~= nil or patch.Model ~= nil or patch.Rarity ~= nil or patch.First then
		if self.Media then
			if d.Model and self.Media.SetModel then
				self.Media:SetModel(d.Model)
			elseif self.Media.Set then
				self.Media:Set(d.Image)
			end
			self.Media:SetRarity(d.Rarity)
		end
	end
	-- chips
	for _, child in ipairs(self.ChipRow:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = chips(kind, d)
	for index, chip in ipairs(list) do
		Kit.Badge(self.ChipRow, { Text = chip.Text, Icon = chip.Icon, Kind = chip.Kind, Color = chip.Color, Order = index, Height = 20 })
	end
	self.ChipRow.Visible = #list > 0
	-- progress
	local progress = d.Progress
	if d.Goal and d.Value then
		progress = d.Goal > 0 and d.Value / d.Goal or 1
	end
	self.ProgressRow.Visible = progress ~= nil
	if progress ~= nil then
		Anim.Tween(self.ProgressFill, { Size = UDim2.fromScale(Util.clamp(progress, 0, 1), 1) }, "base")
		if d.Goal and d.Value then
			self.ProgressText.Text = Util.Format.Compact(math.min(d.Value, d.Goal)) .. " / " .. Util.Format.Compact(d.Goal)
		else
			self.ProgressText.Text = Util.Format.Percent(progress)
		end
		Loc.Unbind(self.ProgressText, "Text")
	end
	-- cost / reward line
	local amount = d.Cost or d.Reward
	self.CostRow.Visible = amount ~= nil
	if amount ~= nil then
		local isReward = d.Cost == nil
		Kit.SetIcon(self.CostIcon, d.CostIcon or d.RewardIcon or (isReward and "gift" or "coins"))
		local affordable = d.Affordable ~= false
		Theme.Bind(self.CostIcon, "ImageColor3", affordable and "Warning" or "Danger")
		self.CostLabel.Text = (type(amount) == "number") and Util.Format.Compact(amount) or tostring(amount)
		Loc.Unbind(self.CostLabel, "Text")
		Theme.Bind(self.CostLabel, "TextColor3", affordable and "Text" or "Danger")
		Kit.SetText(self.CostTitle, isReward and "common.reward" or "common.cost")
	end
	-- actions
	for _, button in ipairs(self.Buttons) do
		button:Destroy()
	end
	self.Buttons = {}
	local specs = actions(kind, d)
	local gap = 6
	for index, spec in ipairs(specs) do
		local button = Kit.Button(self.ButtonRow, {
			Text = spec.Text, Icon = spec.Icon, Variant = spec.Variant, Order = index, Height = Kit.Control() - 2,
			Callback = function()
				if d.Locked then
					return
				end
				if spec.Callback then
					Kit.Safe(spec.Callback)(self, spec.Id)
				end
				if self.Callback then
					self.Callback(self, spec.Id)
				end
				self.Action:Fire(spec.Id)
			end,
		})
		button.Frame.AutomaticSize = Enum.AutomaticSize.None
		button.Frame.Size = UDim2.new(1 / #specs, -(gap * (#specs - 1) / #specs), 0, Kit.Control() - 2)
		button:SetEnabled(not (spec.Disabled or d.Locked))
		self.Buttons[#self.Buttons + 1] = button
	end
	self.ButtonRow.Visible = #specs > 0
	-- locked overlay
	self.LockMask.Visible = d.Locked == true
	if d.Locked then
		Kit.SetText(self.LockLabel, d.LockText or "common.locked")
	end
	self:_style()
end

-- Builds a card. o: Name, Subtitle, Image / Model, Rarity, Level, Power, Multiplier, Amount, Value, Cost, Reward, Progress (0..1) or Value+Goal,
--   Status, Locked, LockText, Equipped, Selected, Actions, Callback(card, actionId), OnSelect(card), Layout ("V" | "H"), Size, MediaHeight, Meta
local function build(parent, kind, o)
	o = o or {}
	local horizontal = (o.Layout or (kind == "quest" or kind == "upgrade" or kind == "zone") and "H" or "V") == "H"
	local frame = Create.New("TextButton", {
		Name = o.Name and "Card" or "Card",
		Size = o.Size or UDim2.new(1, 0, 0, 0),
		AutomaticSize = o.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		Text = "",
		LayoutOrder = o.Order or 0,
		Visible = o.Visible,
		Bind = { BackgroundColor3 = "Surface" },
		Parent = parent,
	})
	Create.Corner(frame, "md")
	local stroke = Create.Stroke(frame, "Border")
	local content = Create.New("Frame", { Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = frame })
	Create.Pad(content, 10)
	Create.List(content, { Padding = 8 })
	local data = Util.clone(o)
	data.Selected = o.Selected == true
	local card = Kit.New(Card, frame, { Kind = kind, Data = data, Stroke = stroke, Buttons = {}, Callback = Kit.Safe(o.Callback) })
	card.Action = Signal.new()
	card.Selected = Signal.new()

	local top = content
	if horizontal then
		top = Create.New("Frame", { Name = "Main", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = content })
		Create.List(top, { Dir = "H", Padding = 10 })
	end
	local mediaSize = horizontal and UDim2.fromOffset(64, 64) or UDim2.new(1, 0, 0, o.MediaHeight or 96)
	if o.Image ~= nil or o.Model ~= nil or kind == "pet" or kind == "item" or kind == "egg" or kind == "world" then
		local holder = Create.New("Frame", { Name = "Media", Size = mediaSize, LayoutOrder = 1, Parent = top })
		if o.Model then
			card.Media = Assets.Model(holder, { Rarity = o.Rarity })
		else
			card.Media = Assets.Image(holder, { Rarity = o.Rarity, Placeholder = kind == "egg" and "egg" or (kind == "world" and "map" or "package") })
		end
		card.Equipped = Kit.Badge(holder, { Text = "common.equipped", Kind = "success", Icon = "check", Position = UDim2.fromOffset(6, 6), ZIndex = 6 })
		card.Equipped.Frame.ZIndex = 6
		card.Equipped = card.Equipped.Frame
	else
		card.Equipped = Create.New("Frame", { Visible = false, Parent = content })
	end
	local column = Create.New("Frame", { Name = "Info", Size = horizontal and UDim2.new(1, -74, 0, 0) or UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = top })
	Create.List(column, { Padding = 4 })
	card.TitleLabel = Kit.Text(column, { Size = 13, Weight = "Bold", Order = 1 })
	card.SubLabel = Kit.Text(column, { Size = 12, Color = "TextMuted", Wrap = true, Auto = "Y", Order = 2 })
	card.ChipRow = Create.New("Frame", { Name = "Chips", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = column })
	Create.List(card.ChipRow, { Dir = "H", Padding = 4, Wrap = true })
	card.ProgressRow = Create.New("Frame", { Name = "Progress", Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 4, Parent = column })
	local track = Create.New("Frame", { Size = UDim2.new(1, -70, 0, 6), Position = UDim2.new(0, 0, 0.5, -3), Bind = { BackgroundColor3 = "SurfacePressed" }, Parent = card.ProgressRow })
	Create.Corner(track, "pill")
	card.ProgressFill = Create.New("Frame", { Size = UDim2.fromScale(0, 1), Bind = { BackgroundColor3 = "Accent" }, Parent = track })
	Create.Corner(card.ProgressFill, "pill")
	card.ProgressText = Kit.Text(card.ProgressRow, { Size = 11, Mono = true, Color = "TextMuted", Align = "Right", Position = UDim2.new(1, -66, 0, 0), SizeUDim = UDim2.new(0, 66, 1, 0) })
	card.CostRow = Create.New("Frame", { Name = "Cost", Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 5, Parent = column })
	card.CostIcon = Kit.Icon(card.CostRow, "coins", 16, "Warning", { Position = UDim2.new(0, 0, 0.5, -8) })
	card.CostLabel = Kit.Text(card.CostRow, { Size = 13, Weight = "Bold", Mono = true, Position = UDim2.fromOffset(22, 0), SizeUDim = UDim2.new(0.5, -22, 1, 0) })
	card.CostTitle = Kit.Text(card.CostRow, { Size = 11, Color = "TextFaint", Align = "Right", Position = UDim2.new(0.5, 0, 0, 0), SizeUDim = UDim2.new(0.5, 0, 1, 0) })
	card.ButtonRow = Create.New("Frame", { Name = "Actions", Size = UDim2.new(1, 0, 0, Kit.Control() - 2), LayoutOrder = 3, Parent = content })
	if horizontal then
		card.ButtonRow.Parent = column
		card.ButtonRow.LayoutOrder = 6
	end
	Create.List(card.ButtonRow, { Dir = "H", Padding = 6 })
	card.LockMask = Create.New("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), ZIndex = 10, Visible = false, BackgroundTransparency = 0.25, Bind = { BackgroundColor3 = "Background" }, Parent = frame })
	Create.Corner(card.LockMask, "md")
	local lockList = Create.New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 11, Parent = card.LockMask })
	Create.List(lockList, { Padding = 4, HAlign = "Center" })
	Kit.Icon(lockList, "lock", 22, "TextMuted", { ZIndex = 11, Order = 1 })
	card.LockLabel = Kit.Text(lockList, { Size = 12, Color = "TextMuted", Align = "Center", Wrap = true, Auto = "Y", ZIndex = 11, Order = 2 })
	if not horizontal then
		-- vertical cards: info column fills the card width
		column.Size = UDim2.new(1, 0, 0, 0)
	end
	frame.Activated:Connect(function()
		if card.Data.Locked then
			return
		end
		if o.OnSelect then
			Kit.Safe(o.OnSelect)(card)
		end
		card.Selected:Fire(card)
	end)
	Kit.Pressable(frame, function(state)
		if not card.Data.Selected then
			Anim.Token(frame, "BackgroundColor3", state.Hover and "SurfaceHover" or "Surface", "fast")
		end
	end)
	card:Refresh({ First = true, Name = true })
	return card
end
Cards.Build = build

for name, kind in pairs({ PetCard = "pet", ItemCard = "item", EggCard = "egg", QuestCard = "quest", UpgradeCard = "upgrade", WorldCard = "world", ZoneCard = "zone" }) do
	Cards.Blocks[name] = function(container, o)
		local holder = Kit.BlockHolder(container, { Name = name })
		local card = build(holder, kind, o)
		card.Holder = holder
		card.Scope:Add(function()
			holder:Destroy()
		end)
		return card
	end
end

-- CardGrid: a responsive grid that creates cards of one kind: grid:Add(kind, data) -------------------------------
local CardGrid = Kit.Class()

function CardGrid:Add(a, b)
	local kind, data = a, b
	if type(a) == "table" then
		kind, data = self.Kind, a
	end
	local card = build(self.Grid.Frame, string.lower(kind or "item"), Util.merge(data, { Order = #self.Cards + 1 }))
	table.insert(self.Cards, card)
	self.Scope:Add(card)
	return card
end

function CardGrid:Clear()
	for _, card in ipairs(self.Cards) do
		card:Destroy()
	end
	self.Cards = {}
end

-- o: Kind ("pet"...), MinWidth, Columns, Items (cards keep an automatic height)
function Cards.Blocks.CardGrid(container, o)
	o = o or {}
	local holder = Kit.BlockHolder(container, { Name = "CardGrid" })
	local grid = Kit.Grid(holder, { Min = o.MinWidth or 150, Max = o.Columns or 4, Gap = 8, Flow = true })
	local object = Kit.New(CardGrid, holder, { Grid = grid, Cards = {}, Kind = o.Kind or "item" })
	for _, item in ipairs(o.Items or {}) do
		object:Add(item)
	end
	return object
end

return Cards
end

Modules["UI/Controls"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Input = import("Core/Input")
local Signal = import("Core/Signal")
local Util = import("Core/Util")
local Popup = import("UI/Popup")
local Keys = import("UI/Keybinds")
local Config = import("Storage/Config")
local Tooltip = import("UI/Tooltip")
local Services = import("Core/Services")

--[[
	General controls. Every control is created from a Group (a card of rows):
	  group:Toggle / Checkbox / Slider / Dropdown / MultiDropdown / SearchableDropdown / NumberInput
	        TextInput / Button / Buttons / Keybind / ColorPicker / ProgressBar / StatusIndicator /
	        Label / Paragraph / Divider / Code / Block        (+ the DeaUI names Input, Stepper, Color,
	        Progress, Tag, Segmented, MultiSelect)
	Common options: Title, Description, Icon, Tooltip, Default, Flag, Callback, Visible, Enabled, Vip, Locked
	Common methods: Get() Set(value, silent) SetVisible() SetEnabled() Destroy() SetTitle() SetDescription()
]]
local Controls = {}
local C = {}
Controls.Constructors = C

local function emit(control, value, silent)
	if silent then
		return
	end
	control.Changed:Fire(value)
	if control.Callback then
		control.Callback(value, control)
	end
end

local RowClass = Kit.Class()

local function subclass()
	local class = setmetatable({}, { __index = RowClass })
	class.__index = class
	return class
end

function RowClass:SetTitle(source)
	self.Row.TitleSource = source
	Kit.SetText(self.Row.Title, source)
	self.Row.Title.Visible = source ~= nil and source ~= ""
end

function RowClass:SetDescription(source)
	self.Row.DescSource = source
	Kit.SetText(self.Row.Description, source)
	self.Row.Description.Visible = source ~= nil and source ~= ""
end

function RowClass:OnDestroy()
	if self.Flag then
		Config.Unregister(self.Flag, self)
	end
	if self.Entry then
		self.Entry.Removed = true
	end
	if self.Row and self.Row.Owner and self.Row.Owner.Page then
		self.Row.Owner.Page:_untrack(self.Row)
	end
	if self.Lock and self.Lock.Remove then
		self.Lock.Remove()
	end
	if self.KeyBind then
		self.KeyBind:Remove()
	end
end

-- Row: title / description / icon on the left, the control (Host) on the right -------------------------
-- o: Title, Description, Icon, HostWidth, HostHeight, Stack (host moves below the text on narrow layouts)
local function makeRow(owner, o)
	local minHeight = Kit.Control() + 20
	local frame = Create.New("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = owner:_order(),
		Parent = owner.Content,
	})
	local sep = Kit.Divider(frame, { Transparency = 0.4 })
	sep.Position = UDim2.fromOffset(14, 0)
	sep.Size = UDim2.new(1, -28, 0, 1)
	local inner = Create.New("Frame", { Name = "Inner", Size = UDim2.new(1, 0, 0, minHeight), AutomaticSize = Enum.AutomaticSize.Y, Parent = frame })
	Create.PadScaled(inner, 14, 10, 14, 10)
	local list = Create.ListScaled(inner, { Dir = "H", Padding = 12, VAlign = "Center" })
	local hostW, hostH = o.HostWidth or 0, o.HostHeight or Kit.Control()
	local info = Create.New("Frame", {
		Name = "Info",
		Size = UDim2.new(1, hostW > 0 and -(hostW + 12) or 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = inner,
	})
	Create.List(info, { Dir = "H", Padding = 10, VAlign = "Center" })
	local well
	local wellWidth = 0
	if o.Icon then
		well = Create.New("Frame", { Name = "IconWell", Size = UDim2.fromOffset(30, 30), LayoutOrder = 1, Bind = { BackgroundColor3 = "PrimarySoft" }, Parent = info })
		Create.Corner(well, "sm")
		Kit.Icon(well, o.Icon, 16, "Primary", { Position = UDim2.new(0.5, -8, 0.5, -8) })
		wellWidth = 40
	end
	local column = Create.New("Frame", { Name = "Text", Size = UDim2.new(1, -wellWidth, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = info })
	Create.List(column, { Padding = 2 })
	local title = Kit.Text(column, { Text = o.Title, Size = 13, Weight = "Medium", Wrap = true, Auto = "Y", Order = 1 })
	local description = Kit.Text(column, { Text = o.Description, Size = 12, Color = "TextMuted", Wrap = true, Auto = "Y", Order = 2 })
	title.Visible = o.Title ~= nil and o.Title ~= ""
	description.Visible = o.Description ~= nil and o.Description ~= ""
	local host = Create.New("Frame", { Name = "Host", Size = UDim2.fromOffset(hostW, hostH), LayoutOrder = 2, Visible = hostW > 0, Parent = inner })
	local row = {
		Frame = frame, Inner = inner, Info = info, Host = host, Title = title, Description = description, Separator = sep,
		TitleSource = o.Title, DescSource = o.Description, Owner = owner, Stacked = false, Stack = o.Stack,
	}
	function row:Layout(width)
		if hostW == 0 then
			return
		end
		local stacked = self.Stack == true and width < 400
		if stacked == self.Stacked then
			return
		end
		self.Stacked = stacked
		list.FillDirection = stacked and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
		list.VerticalAlignment = stacked and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center
		info.Size = stacked and UDim2.new(1, 0, 0, 0) or UDim2.new(1, -(hostW + 12), 0, 0)
		host.Size = stacked and UDim2.new(1, 0, 0, hostH) or UDim2.fromOffset(hostW, hostH)
	end
	return row
end
Controls.MakeRow = makeRow

-- Creates the control object around a row. `fields` become members of the object.
local function newControl(class, owner, o, rowOptions, fields)
	local row = makeRow(owner, Util.merge(o, rowOptions or {}))
	local control = Kit.New(class, row.Frame, fields or {})
	control.Row = row
	control.Host = row.Host
	control.Changed = Signal.new()
	control.Callback = Kit.Safe(o.Callback)
	control.Flag = o.Flag
	control.Tooltip = Tooltip.Attach(row.Frame, o.Tooltip)
	control.Scope:Add(control.Tooltip)
	Kit.Adopt(owner, control)
	owner:_attach(control, row, o)
	return control
end

local function finish(control, o)
	if o.Enabled == false then
		control:SetEnabled(false)
	end
	if o.Visible == false then
		control:SetVisible(false)
	end
	if control.Flag then
		Config.Register(control.Flag, control)
	end
	return control
end

-- Toggle -----------------------------------------------------------------------------------------------
local Toggle = subclass()

local function keyChip(parent, control, spec)
	local chip = Create.New("TextButton", {
		Name = "Key",
		Size = UDim2.fromOffset(66, 26),
		Position = UDim2.new(0, 0, 0.5, -13),
		Text = "",
		Bind = { BackgroundColor3 = "SurfaceRaised" },
		Parent = parent,
	})
	Create.Corner(chip, "sm")
	Create.Stroke(chip, "Border")
	local label = Kit.Text(chip, { Size = 11, Weight = "Medium", Align = "Center", Color = "TextMuted", Mono = true, SizeUDim = UDim2.fromScale(1, 1) })
	local object = { Key = spec.Default, Mode = spec.Mode or "Toggle", Chip = chip }
	local listening = false
	local function render()
		if listening then
			Kit.SetText(label, "keybind.listening")
		else
			local name = Keys.Name(object.Key)
			if name then
				label.Text = name
				Loc.Unbind(label, "Text")
			else
				Kit.SetText(label, "keybind.none")
			end
		end
	end
	function object:Get()
		return self.Key
	end
	function object:Set(key, silent)
		if key ~= nil and typeof(key) ~= "EnumItem" then
			return
		end
		self.Key = key
		if self.Bind then
			self.Bind.Key = key
		end
		render()
		if not silent and spec.OnChange then
			spec.OnChange(key)
		end
	end
	object.Bind = Keys.Register({ Key = object.Key, Allowed = function()
		return control.Enabled and not control.Row.Locked
	end, OnPress = function()
		if object.Mode == "Hold" then
			control:Set(true)
		else
			control:Set(not control.Value)
		end
	end, OnRelease = function()
		if object.Mode == "Hold" then
			control:Set(false)
		end
	end })
	chip.Activated:Connect(function()
		if listening then
			return
		end
		listening = true
		render()
		Keys.Capture(function(key)
			listening = false
			object:Set(key)
		end, function()
			listening = false
			render()
		end)
	end)
	control.Scope:Connect(Loc.Changed, render)
	render()
	return object
end

function Toggle:Get()
	return self.Value
end

function Toggle:Set(value, silent)
	value = value == true
	if value == self.Value and self.Rendered then
		return
	end
	self.Value = value
	self.Rendered = true
	local on = value
	Anim.Token(self.Track, "BackgroundColor3", on and "Primary" or "SurfacePressed", "fast")
	Anim.Token(self.Knob, "BackgroundColor3", on and "PrimaryText" or "TextMuted", "fast")
	Anim.Tween(self.Knob, { Position = UDim2.new(0, on and 23 or 3, 0.5, -9) }, "fast")
	emit(self, value, silent)
end

function Toggle:Toggle()
	self:Set(not self.Value)
end

function C.Toggle(owner, o)
	local keyWidth = o.Keybind and 76 or 0
	local control = newControl(Toggle, owner, o, { HostWidth = 46 + keyWidth, HostHeight = 26 }, { Value = false })
	local host = control.Host
	control.Track = Create.New("TextButton", {
		Name = "Track",
		Size = UDim2.fromOffset(44, 24),
		Position = UDim2.new(1, -44, 0.5, -12),
		Text = "",
		Bind = { BackgroundColor3 = "SurfacePressed" },
		Parent = host,
	})
	Create.Corner(control.Track, "pill")
	control.Knob = Create.New("Frame", { Name = "Knob", Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 3, 0.5, -9), Bind = { BackgroundColor3 = "TextMuted" }, Parent = control.Track })
	Create.Corner(control.Knob, "pill")
	control.Track.Activated:Connect(function()
		control:Toggle()
	end)
	if o.Keybind then
		local holder = Create.New("Frame", { Name = "KeyHolder", Size = UDim2.fromOffset(66, 26), Position = UDim2.new(0, 0, 0, 0), Parent = host })
		control.KeyControl = keyChip(holder, control, o.Keybind)
		control.KeyBind = control.KeyControl.Bind
		if o.Keybind.Flag then
			Config.Register(o.Keybind.Flag, control.KeyControl)
			control.Scope:Add(function()
				Config.Unregister(o.Keybind.Flag, control.KeyControl)
			end)
		end
	end
	control:Set(o.Default == true, true)
	return finish(control, o)
end

-- Checkbox -------------------------------------------------------------------------------------------
local Checkbox = subclass()
Checkbox.Get = Toggle.Get
Checkbox.Toggle = Toggle.Toggle

function Checkbox:Set(value, silent)
	value = value == true
	if value == self.Value and self.Rendered then
		return
	end
	self.Value, self.Rendered = value, true
	Anim.Token(self.Box, "BackgroundColor3", value and "Primary" or "SurfaceRaised", "fast")
	Anim.Tween(self.Mark, { ImageTransparency = value and 0 or 1 }, "fast")
	emit(self, value, silent)
end

function C.Checkbox(owner, o)
	local control = newControl(Checkbox, owner, o, { HostWidth = 26, HostHeight = 26 }, { Value = false })
	control.Box = Create.New("TextButton", { Name = "Box", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -22, 0.5, -11), Text = "", Bind = { BackgroundColor3 = "SurfaceRaised" }, Parent = control.Host })
	Create.Corner(control.Box, "sm")
	Create.Stroke(control.Box, "BorderStrong")
	control.Mark = Kit.Icon(control.Box, "check", 14, "PrimaryText", { Position = UDim2.new(0.5, -7, 0.5, -7) })
	control.Mark.ImageTransparency = 1
	control.Box.Activated:Connect(function()
		control:Toggle()
	end)
	control:Set(o.Default == true, true)
	return finish(control, o)
end

-- Slider -----------------------------------------------------------------------------------------------
local Slider = subclass()

local function decimalsOf(step)
	local text = string.format("%.6f", step)
	text = string.gsub(text, "0+$", "")
	local fraction = string.match(text, "%.(%d*)$") or ""
	return #fraction
end

function Slider:Format(value)
	local text
	if self.FormatFn then
		local ok, result = pcall(self.FormatFn, value)
		text = ok and tostring(result) or tostring(value)
	else
		text = string.format("%." .. self.Decimals .. "f", value)
	end
	return text .. (self.Suffix or "")
end

function Slider:Get()
	return self.Value
end

function Slider:Set(value, silent, instant)
	value = tonumber(value)
	if not value then
		return
	end
	value = Util.clamp(Util.round(value - self.Min, self.Step) + self.Min, self.Min, self.Max)
	local ratio = self.Max > self.Min and (value - self.Min) / (self.Max - self.Min) or 0
	local changed = value ~= self.Value
	self.Value = value
	self.ValueLabel.Text = self:Format(value)
	if instant or self.Dragging then
		self.Fill.Size = UDim2.fromScale(ratio, 1)
		self.Knob.Position = UDim2.new(ratio, 0, 0.5, 0)
	else
		Anim.Tween(self.Fill, { Size = UDim2.fromScale(ratio, 1) }, "fast")
		Anim.Tween(self.Knob, { Position = UDim2.new(ratio, 0, 0.5, 0) }, "fast")
	end
	if changed then
		emit(self, value, silent)
	end
end

function Slider:SetRange(min, max)
	self.Min, self.Max = min, math.max(max, min)
	self:Set(self.Value, true, true)
end

local scrollParent = Kit.ScrollParent
Controls.ScrollParent = scrollParent

function C.Slider(owner, o)
	local min, max = o.Min or 0, o.Max or 100
	local step = o.Step or 1
	local control = newControl(Slider, owner, o, { HostWidth = 210, HostHeight = Kit.Control(), Stack = true }, {
		Min = min, Max = math.max(max, min), Step = step, Decimals = o.Decimals or decimalsOf(step), Suffix = o.Suffix, FormatFn = o.Format, Value = min,
	})
	local host = control.Host
	control.ValueLabel = Kit.Text(host, { Size = 12, Mono = true, Align = "Right", Color = "TextMuted", Position = UDim2.new(1, -54, 0, 0), SizeUDim = UDim2.new(0, 54, 1, 0) })
	local hit = Create.New("TextButton", { Name = "Hit", Size = UDim2.new(1, -64, 1, 0), Text = "", Parent = host })
	local track = Create.New("Frame", { Name = "Track", Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0.5, -2), Bind = { BackgroundColor3 = "SurfacePressed" }, Parent = hit })
	Create.Corner(track, "pill")
	control.Fill = Create.New("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), Bind = { BackgroundColor3 = "Primary" }, Parent = track })
	Create.Corner(control.Fill, "pill")
	control.Knob = Create.New("Frame", { Name = "Knob", Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Bind = { BackgroundColor3 = "Text" }, Parent = track })
	Create.Corner(control.Knob, "pill")
	Create.Stroke(control.Knob, "Primary", 2)
	local scroller
	local function fromPoint(point)
		local width = hit.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local ratio = Util.clamp((point.X - hit.AbsolutePosition.X) / width, 0, 1)
		control:Set(control.Min + (control.Max - control.Min) * ratio)
	end
	control.Scope:Add(Input.Drag(hit, {
		Begin = function(point)
			control.Dragging = true
			scroller = scrollParent(hit)
			if scroller then
				scroller.ScrollingEnabled = false
			end
			fromPoint(point)
		end,
		Move = function(_, point)
			fromPoint(point)
		end,
		End = function()
			control.Dragging = false
			if scroller then
				scroller.ScrollingEnabled = true
				scroller = nil
			end
		end,
	}))
	control:Set(o.Default or min, true, true)
	return finish(control, o)
end

-- Number input (stepper) --------------------------------------------------------------------------------
local Number = subclass()

function Number:Get()
	return self.Value
end

function Number:Set(value, silent)
	value = tonumber(value)
	if not value then
		self.Box.Text = self:Text(self.Value)
		return
	end
	value = Util.clamp(Util.round(value - self.Min, self.Step) + self.Min, self.Min, self.Max)
	local changed = value ~= self.Value
	self.Value = value
	self.Box.Text = self:Text(value)
	if changed then
		emit(self, value, silent)
	end
end

function Number:Text(value)
	return string.format("%." .. self.Decimals .. "f", value)
end

function C.NumberInput(owner, o)
	local step = o.Step or 1
	local control = newControl(Number, owner, o, { HostWidth = 140, HostHeight = Kit.Control() }, {
		Min = o.Min or -math.huge, Max = o.Max or math.huge, Step = step, Decimals = o.Decimals or decimalsOf(step), Value = o.Default or o.Min or 0,
	})
	local height = Kit.Control()
	local function stepper(text, x)
		local button = Create.New("TextButton", { Name = text == "+" and "Plus" or "Minus", Size = UDim2.fromOffset(height, height), Position = UDim2.new(0, x, 0, 0), Text = "", Bind = { BackgroundColor3 = "SurfaceRaised" }, Parent = control.Host })
		Create.Corner(button, "sm")
		Create.Stroke(button, "Border")
		Kit.Text(button, { Text = text, Size = 16, Weight = "Bold", Align = "Center", Color = "Text", SizeUDim = UDim2.fromScale(1, 1) })
		Kit.Pressable(button, function(state)
			Anim.Token(button, "BackgroundColor3", state.Down and "SurfacePressed" or (state.Hover and "SurfaceHover" or "SurfaceRaised"), "fast")
		end)
		return button
	end
	local minus = stepper("-", 0)
	local plus = stepper("+", 140 - height)
	control.Box = Create.New("TextBox", {
		Name = "Box",
		Size = UDim2.new(1, -(height * 2 + 8), 1, 0),
		Position = UDim2.fromOffset(height + 4, 0),
		Text = "",
		ClearTextOnFocus = false,
		TextSize = Kit.Size(13),
		FontFace = Theme.Mono,
		Parent = control.Host,
	})
	minus.Activated:Connect(function()
		control:Set(control.Value - control.Step)
	end)
	plus.Activated:Connect(function()
		control:Set(control.Value + control.Step)
	end)
	control.Box.FocusLost:Connect(function()
		control:Set(control.Box.Text)
	end)
	control:Set(control.Value, true)
	return finish(control, o)
end

-- Text input -----------------------------------------------------------------------------------------
local Text = subclass()

function Text:Get()
	return self.Field.Box.Text
end

function Text:Set(value, silent)
	value = tostring(value or "")
	self.Field.Box.Text = value
	self.Last = value
	emit(self, value, silent)
end

function C.TextInput(owner, o)
	local control = newControl(Text, owner, o, { HostWidth = o.Width or 190, HostHeight = Kit.Control(), Stack = true }, { Last = "" })
	local function commit(text)
		if o.Numeric then
			local filtered = string.gsub(text, "[^%d%.%-]", "")
			if filtered ~= text then
				control.Field.Box.Text = filtered
				text = filtered
			end
		end
		if text ~= control.Last then
			control.Last = text
			emit(control, text, false)
		end
	end
	control.Field = Kit.Field(control.Host, {
		Placeholder = o.Placeholder,
		Text = o.Default or "",
		Mono = o.Mono,
		Clear = o.Clear,
		OnSubmit = function(text)
			commit(text)
		end,
		OnChanged = o.Live and commit or nil,
	})
	control.Last = o.Default or ""
	return finish(control, o)
end

-- Dropdown (single / multiple / searchable) -----------------------------------------------------------
local Dropdown = subclass()

local function normalize(list)
	local out = {}
	for _, entry in ipairs(list or {}) do
		if type(entry) == "table" and (entry.Text ~= nil or entry.Value ~= nil or entry.Name ~= nil) then
			local value = entry.Value
			if value == nil then
				value = entry.Text or entry.Name
			end
			out[#out + 1] = { Text = entry.Text or entry.Name or tostring(value), Value = value, Icon = entry.Icon, Rarity = entry.Rarity }
		else
			out[#out + 1] = { Text = entry, Value = entry }
		end
	end
	return out
end
Controls.NormalizeOptions = normalize

function Dropdown:OptionOf(value)
	for _, option in ipairs(self.Options) do
		if option.Value == value then
			return option
		end
	end
	return nil
end

function Dropdown:Get()
	if self.Multi then
		local out = {}
		for _, option in ipairs(self.Options) do
			if self.Selected[option.Value] then
				out[#out + 1] = option.Value
			end
		end
		return out
	end
	return self.Value
end

function Dropdown:RefreshText()
	local text
	if self.Multi then
		local list = self:Get()
		if #list == 0 then
			text = Loc.Resolve(self.Placeholder or "dropdown.select")
		elseif #list == 1 then
			text = Loc.Resolve(self:OptionOf(list[1]).Text)
		else
			text = Loc.Resolve("dropdown.selected_count", #list)
		end
	else
		local option = self:OptionOf(self.Value)
		text = option and Loc.Resolve(option.Text) or Loc.Resolve(self.Placeholder or "dropdown.select")
	end
	self.Label.Text = text
	Loc.Unbind(self.Label, "Text")
	local selected = self.Multi and #self:Get() > 0 or (not self.Multi and self:OptionOf(self.Value) ~= nil)
	Theme.Bind(self.Label, "TextColor3", selected and "Text" or "TextMuted")
end

function Dropdown:Set(value, silent)
	if self.Multi then
		local selected = {}
		for _, entry in ipairs(type(value) == "table" and value or { value }) do
			if self:OptionOf(entry) then
				selected[entry] = true
			end
		end
		self.Selected = selected
	else
		if value ~= nil and not self:OptionOf(value) then
			return
		end
		if value == self.Value then
			self:RefreshText()
			return
		end
		self.Value = value
	end
	self:RefreshText()
	emit(self, self:Get(), silent)
end

function Dropdown:SetOptions(list)
	self.Options = normalize(list)
	if self.Multi then
		for value in pairs(self.Selected) do
			if not self:OptionOf(value) then
				self.Selected[value] = nil
			end
		end
	elseif self.Value ~= nil and not self:OptionOf(self.Value) then
		self.Value = nil
	end
	self:RefreshText()
end

function Dropdown:Close()
	if self.Handle then
		self.Handle:Close()
	end
end

function Dropdown:Open()
	if not self.Enabled then
		return
	end
	local control = self
	local rowHeight = Kit.Control() + 2
	self.Handle = Popup.Open({
		Anchor = self.Button,
		MinWidth = 190,
		MaxHeight = 300,
		OnClose = function()
			control.Handle = nil
			Anim.Tween(control.Chevron, { Rotation = 0 }, "fast")
		end,
		Build = function(frame, close)
			Anim.Tween(control.Chevron, { Rotation = 180 }, "fast")
			local top = 6
			local search
			if control.Searchable then
				search = Kit.Field(frame, { Placeholder = "dropdown.search", Icon = "search", Clear = true, Position = UDim2.fromOffset(6, 6), SizeUDim = UDim2.new(1, -12, 0, Kit.Control()) })
				top = Kit.Control() + 12
			end
			local scroll = Kit.Scroll(frame, { Size = UDim2.new(1, 0, 1, -top), Position = UDim2.fromOffset(0, top) })
			Create.Pad(scroll, 6, 0, 6, 6)
			Create.List(scroll, { Padding = 2 })
			local function render(filter)
				for _, child in ipairs(scroll:GetChildren()) do
					if child:IsA("GuiObject") then
						child:Destroy()
					end
				end
				local shown = 0
				for index, option in ipairs(control.Options) do
					local label = Loc.Resolve(option.Text)
					if filter == nil or filter == "" or string.find(Util.Fold(label), Util.Fold(filter), 1, true) then
						shown = shown + 1
						if shown > 200 then
							break
						end
						local selected = control.Multi and control.Selected[option.Value] or (not control.Multi and control.Value == option.Value)
						local item = Create.New("TextButton", { Name = "Option", Size = UDim2.new(1, 0, 0, rowHeight), Text = "", LayoutOrder = index, Bind = { BackgroundColor3 = "SurfaceHover" }, Parent = scroll })
						item.BackgroundTransparency = selected and 0.5 or 1
						Create.Corner(item, "sm")
						local x = 10
						if control.Multi then
							local box = Create.New("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 8, 0.5, -8), Bind = { BackgroundColor3 = selected and "Primary" or "SurfaceRaised" }, Parent = item })
							Create.Corner(box, 4)
							Create.Stroke(box, "BorderStrong")
							Kit.Icon(box, "check", 12, "PrimaryText", { Position = UDim2.fromOffset(2, 2) }).Visible = selected == true
							x = 32
						end
						if option.Icon then
							Kit.Icon(item, option.Icon, 16, selected and "Primary" or "TextMuted", { Position = UDim2.new(0, x, 0.5, -8) })
							x = x + 24
						end
						local color = option.Rarity and Theme.Rarity(option.Rarity)
						local text = Kit.Text(item, { Text = option.Text, Size = 13, Color = selected and "Primary" or "Text", Position = UDim2.fromOffset(x, 0), SizeUDim = UDim2.new(1, -(x + (control.Multi and 10 or 34)), 1, 0) })
						if color then
							text.TextColor3 = color
						end
						if not control.Multi and selected then
							Kit.Icon(item, "check", 14, "Primary", { Position = UDim2.new(1, -24, 0.5, -7) })
						end
						Kit.Pressable(item, function(state)
							item.BackgroundTransparency = (state.Hover or state.Down) and 0.2 or (selected and 0.5 or 1)
						end)
						item.Activated:Connect(function()
							if control.Multi then
								control.Selected[option.Value] = (not control.Selected[option.Value]) or nil
								if control.Max and #control:Get() > control.Max then
									control.Selected[option.Value] = nil
								end
								control:RefreshText()
								emit(control, control:Get(), false)
								render(search and search.Box.Text or nil)
							else
								close()
								control:Set(option.Value)
							end
						end)
					end
				end
				if shown == 0 then
					Kit.Text(scroll, { Text = "dropdown.none_found", Size = 12, Color = "TextMuted", Align = "Center", SizeUDim = UDim2.new(1, 0, 0, 36) })
				end
			end
			render(nil)
			if search then
				search.Box:GetPropertyChangedSignal("Text"):Connect(function()
					render(search.Box.Text)
				end)
			end
			return top + #control.Options * (rowHeight + 2) + 10
		end,
	})
end

local function makeDropdown(owner, o, multi, searchable)
	local control = newControl(Dropdown, owner, o, { HostWidth = o.Width or 190, HostHeight = Kit.Control(), Stack = true }, {
		Options = normalize(o.Options), Multi = multi, Selected = {}, Searchable = searchable or o.Searchable == true, Placeholder = o.Placeholder, Max = o.Max,
	})
	control.Button = Create.New("TextButton", { Name = "Button", Size = UDim2.fromScale(1, 1), Text = "", Bind = { BackgroundColor3 = "SurfaceRaised" }, Parent = control.Host })
	Create.Corner(control.Button, "sm")
	local stroke = Create.Stroke(control.Button, "Border")
	control.Label = Kit.Text(control.Button, { Size = 13, Position = UDim2.fromOffset(10, 0), SizeUDim = UDim2.new(1, -34, 1, 0) })
	control.Chevron = Kit.Icon(control.Button, "chevron-down", 14, "TextMuted", { Position = UDim2.new(1, -24, 0.5, -7) })
	Kit.Pressable(control.Button, function(state)
		Anim.Token(control.Button, "BackgroundColor3", state.Down and "SurfacePressed" or (state.Hover and "SurfaceHover" or "SurfaceRaised"), "fast")
	end)
	control.Button.Activated:Connect(function()
		if control.Handle then
			control:Close()
		else
			control:Open()
		end
	end)
	control.Scope:Connect(Loc.Changed, function()
		control:RefreshText()
	end)
	control.Scope:Add(function()
		control:Close()
	end)
	if multi then
		control:Set(o.Default or {}, true)
	else
		local default = o.Default
		if default == nil and o.AllowNone ~= true and control.Options[1] and o.Placeholder == nil then
			default = control.Options[1].Value
		end
		control:Set(default, true)
	end
	return finish(control, o)
end

function C.Dropdown(owner, o)
	return makeDropdown(owner, o, o.Multi == true, o.Searchable == true)
end
function C.MultiDropdown(owner, o)
	return makeDropdown(owner, o, true, o.Searchable == true)
end
function C.SearchableDropdown(owner, o)
	return makeDropdown(owner, o, o.Multi == true, true)
end

-- Segmented (radio buttons with a sliding highlight) -------------------------------------------------------
local Segmented = subclass()

function Segmented:Get()
	return self.Value
end

function Segmented:Set(value, silent)
	local index
	for i, option in ipairs(self.Options) do
		if option.Value == value then
			index = i
		end
	end
	if not index then
		return
	end
	local count = #self.Options
	self.Value = value
	Anim.Tween(self.Highlight, { Position = UDim2.new((index - 1) / count, 2, 0, 2) }, "fast")
	for i, label in ipairs(self.Labels) do
		Anim.Token(label, "TextColor3", i == index and "PrimaryText" or "TextMuted", "fast")
	end
	if value ~= self.Last then
		self.Last = value
		emit(self, value, silent)
	end
end

function C.Segmented(owner, o)
	local options = normalize(o.Options)
	local width = o.Width or math.max(180, #options * 84)
	local control = newControl(Segmented, owner, o, { HostWidth = width, HostHeight = Kit.Control(), Stack = true }, { Options = options, Labels = {} })
	local back = Create.New("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), Bind = { BackgroundColor3 = "SurfaceRaised" }, Parent = control.Host })
	Create.Corner(back, "sm")
	Create.Stroke(back, "Border")
	local count = math.max(#options, 1)
	control.Highlight = Create.New("Frame", { Name = "Highlight", Size = UDim2.new(1 / count, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2), Bind = { BackgroundColor3 = "Primary" }, Parent = back })
	Create.Corner(control.Highlight, "sm")
	for index, option in ipairs(options) do
		local button = Create.New("TextButton", { Name = "Option", Size = UDim2.new(1 / count, 0, 1, 0), Position = UDim2.new((index - 1) / count, 0, 0, 0), Text = "", ZIndex = 2, Parent = back })
		control.Labels[index] = Kit.Text(button, { Text = option.Text, Size = 12, Weight = "Medium", Align = "Center", Color = "TextMuted", SizeUDim = UDim2.fromScale(1, 1), ZIndex = 3 })
		button.Activated:Connect(function()
			control:Set(option.Value)
		end)
	end
	control:Set(o.Default ~= nil and o.Default or (options[1] and options[1].Value), true)
	return finish(control, o)
end

-- Button / Buttons -----------------------------------------------------------------------------------------
local ButtonRow = subclass()

function ButtonRow:Click()
	if self.Enabled and not self.Row.Locked then
		self.Button:Click()
	end
end

function ButtonRow:OnEnabled(enabled)
	if self.Button then
		self.Button:SetEnabled(enabled)
	end
end

function ButtonRow:SetText(source)
	self.Button:SetText(source)
end

function ButtonRow:Get()
	return nil
end

function C.Button(owner, o)
	local control = newControl(ButtonRow, owner, o, { HostWidth = 0 }, {})
	control.Host.Visible = true
	control.Host.AutomaticSize = Enum.AutomaticSize.X
	control.Host.Size = UDim2.fromOffset(0, Kit.Control())
	control.Row.Info.Size = UDim2.new(1, -110, 0, 0)
	if o.Title == nil and o.Description == nil then
		control.Row.Info.Visible = false
	end
	control.Button = Kit.Button(control.Host, { Text = o.ButtonText or o.Text, Icon = o.ButtonIcon, Variant = o.Variant, MinWidth = 84, Callback = o.Callback and function()
		if control.Row.Locked then
			return
		end
		o.Callback(control)
	end or nil, Tooltip = nil })
	control.Callback = nil
	control.Scope:Add(control.Button)
	control.Row.Info.Size = UDim2.new(1, -96, 0, 0)
	return finish(control, o)
end

local Buttons = subclass()

function Buttons:Get()
	return nil
end

function C.Buttons(owner, list, options)
	options = options or {}
	local row = makeRow(owner, { Title = options.Title, Description = options.Description })
	row.Info.Visible = options.Title ~= nil or options.Description ~= nil
	row.Host.Visible = true
	row.Host.Size = UDim2.new(1, 0, 0, 0)
	row.Host.AutomaticSize = Enum.AutomaticSize.Y
	Create.List(row.Host, { Dir = "H", Padding = 8, Wrap = true })
	local control = Kit.New(Buttons, row.Frame, { Row = row, Host = row.Host, Items = {} })
	control.Changed = Signal.new()
	for index, spec in ipairs(list or {}) do
		local button = Kit.Button(row.Host, {
			Text = spec.Text,
			Icon = spec.Icon,
			Variant = spec.Variant,
			MinWidth = spec.MinWidth or 80,
			Order = index,
			Tooltip = spec.Tooltip,
			Callback = spec.Callback,
		})
		control.Scope:Add(button)
		control.Items[index] = button
	end
	Kit.Adopt(owner, control)
	owner:_attach(control, row, options)
	return finish(control, options)
end

-- Keybind ----------------------------------------------------------------------------------------------------
local Keybind = subclass()

function Keybind:Get()
	return self.Chip:Get()
end

function Keybind:Set(key, silent)
	if key ~= nil and typeof(key) ~= "EnumItem" then
		return
	end
	self.Chip:Set(key, true)
	self.KeyBind.Key = key
	emit(self, key, silent)
end

function C.Keybind(owner, o)
	local control = newControl(Keybind, owner, o, { HostWidth = 76, HostHeight = 26 }, {})
	local fake = { Value = false, Enabled = true, Row = control.Row, Set = function() end, Scope = control.Scope }
	local onPress, onRelease = Kit.Safe(o.OnPress), Kit.Safe(o.OnRelease)
	local spec = { Default = o.Default, Mode = "Press", OnChange = function(key)
		control.KeyBind.Key = key
		emit(control, key, false)
	end }
	control.Chip = keyChip(control.Host, fake, spec)
	control.Chip.Bind:Remove()
	control.Chip.Bind = nil
	control.KeyBind = Keys.Register({ Key = o.Default, Allowed = function()
		return control.Enabled and not control.Row.Locked
	end, OnPress = onPress, OnRelease = onRelease })
	return finish(control, o)
end

-- Color picker -----------------------------------------------------------------------------------------------
local ColorControl = subclass()

function ColorControl:Get()
	return self.Color
end

function ColorControl:Set(color, silent)
	if typeof(color) == "string" then
		color = Util.FromHex(color)
	end
	if typeof(color) ~= "Color3" then
		return
	end
	self.Color = color
	self.Swatch.BackgroundColor3 = color
	if self.Picker then
		self.Picker.Refresh(false)
	end
	emit(self, color, silent)
end

local function colorPopup(control)
	local hue, sat, val = control.Color:ToHSV()
	local picker = {}
	control.Handle = Popup.Open({
		Anchor = control.Swatch,
		Width = 232,
		MaxHeight = 280,
		Align = "Right",
		OnClose = function()
			control.Handle = nil
			control.Picker = nil
			local scroller = control.PickerScroller
			if scroller then
				scroller.ScrollingEnabled = true
			end
		end,
		Build = function(frame)
			Create.Pad(frame, 10)
			local square = Create.New("TextButton", { Name = "SV", Size = UDim2.new(1, 0, 0, 130), Text = "", BackgroundColor3 = Color3.fromHSV(hue, 1, 1), BackgroundTransparency = 0, Parent = frame })
			Create.Corner(square, "sm")
			local white = Create.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = square })
			Create.Corner(white, "sm")
			local g1 = Instance.new("UIGradient")
			g1.Transparency = NumberSequence.new(0, 1)
			g1.Parent = white
			local black = Create.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = square })
			Create.Corner(black, "sm")
			local g2 = Instance.new("UIGradient")
			g2.Rotation = 90
			g2.Transparency = NumberSequence.new(1, 0)
			g2.Parent = black
			local cursor = Create.New("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 3, Parent = square })
			Create.Corner(cursor, "pill")
			Create.Stroke(cursor, "Background", 2)
			local bar = Create.New("TextButton", { Name = "Hue", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 140), Text = "", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, Parent = frame })
			Create.Corner(bar, "pill")
			local g3 = Instance.new("UIGradient")
			local stops = {}
			for i = 0, 6 do
				stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 == 1 and 0.9999 or i / 6, 1, 1))
			end
			g3.Color = ColorSequence.new(stops)
			g3.Parent = bar
			local knob = Create.New("Frame", { Size = UDim2.fromOffset(6, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = bar })
			Create.Corner(knob, "sm")
			Create.Stroke(knob, "Background", 2)
			local hex = Kit.Field(frame, { Position = UDim2.fromOffset(0, 168), SizeUDim = UDim2.new(1, 0, 0, Kit.Control()), Mono = true, Placeholder = "colorpicker.hex", Text = Util.Hex(control.Color),
				OnSubmit = function(text)
					local color = Util.FromHex(text)
					if color then
						hue, sat, val = color:ToHSV()
						control:Set(color)
					else
						picker.Refresh(true)
					end
				end })
			function picker.Refresh(fromHex)
				square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
				cursor.Position = UDim2.fromScale(sat, 1 - val)
				knob.Position = UDim2.new(hue, 0, 0.5, 0)
				if fromHex ~= false then
					hex.Box.Text = Util.Hex(control.Color)
				end
			end
			local function apply()
				picker.Refresh(false)
				control.Color = Color3.fromHSV(hue, sat, val)
				control.Swatch.BackgroundColor3 = control.Color
				hex.Box.Text = Util.Hex(control.Color)
				emit(control, control.Color, false)
			end
			local scroller = scrollParent(control.Swatch)
			control.PickerScroller = scroller
			Input.Drag(square, {
				Begin = function(point)
					if scroller then scroller.ScrollingEnabled = false end
					sat = Util.clamp((point.X - square.AbsolutePosition.X) / math.max(square.AbsoluteSize.X, 1), 0, 1)
					val = 1 - Util.clamp((point.Y - square.AbsolutePosition.Y) / math.max(square.AbsoluteSize.Y, 1), 0, 1)
					apply()
				end,
				Move = function(_, point)
					sat = Util.clamp((point.X - square.AbsolutePosition.X) / math.max(square.AbsoluteSize.X, 1), 0, 1)
					val = 1 - Util.clamp((point.Y - square.AbsolutePosition.Y) / math.max(square.AbsoluteSize.Y, 1), 0, 1)
					apply()
				end,
				End = function() end,
			})
			Input.Drag(bar, {
				Begin = function(point)
					hue = Util.clamp((point.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 0.9999)
					apply()
				end,
				Move = function(_, point)
					hue = Util.clamp((point.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 0.9999)
					apply()
				end,
				End = function() end,
			})
			picker.Refresh(true)
			return 168 + Kit.Control() + 20
		end,
	})
	control.Picker = picker
end

function C.ColorPicker(owner, o)
	local control = newControl(ColorControl, owner, o, { HostWidth = 52, HostHeight = 26 }, { Color = o.Default or Color3.fromRGB(59, 130, 246) })
	control.Swatch = Create.New("TextButton", { Name = "Swatch", Size = UDim2.fromOffset(46, 26), Position = UDim2.new(1, -46, 0, 0), Text = "", BackgroundColor3 = control.Color, BackgroundTransparency = 0, Parent = control.Host })
	Create.Corner(control.Swatch, "sm")
	Create.Stroke(control.Swatch, "BorderStrong")
	control.Swatch.Activated:Connect(function()
		if control.Handle then
			control.Handle:Close()
		else
			colorPopup(control)
		end
	end)
	control.Scope:Add(function()
		if control.Handle then
			control.Handle:Close(true)
		end
	end)
	return finish(control, o)
end

-- Progress bar -----------------------------------------------------------------------------------------------
local Progress = subclass()

function Progress:Get()
	return self.Value
end

function Progress:Set(value, silent, instant)
	value = Util.clamp(tonumber(value) or 0, 0, 1)
	self.Value = value
	if instant then
		self.Fill.Size = UDim2.fromScale(value, 1)
	else
		Anim.Tween(self.Fill, { Size = UDim2.fromScale(value, 1) }, "base")
	end
	if self.Text and not self.CustomText then
		self.Text.Text = Util.Format.Percent(value)
	end
	emit(self, value, silent)
end

function Progress:SetText(text)
	self.CustomText = text ~= nil
	if text ~= nil then
		Kit.SetText(self.Text, text)
	else
		self.Text.Text = Util.Format.Percent(self.Value)
	end
end

function C.ProgressBar(owner, o)
	local control = newControl(Progress, owner, o, { HostWidth = 200, HostHeight = 22, Stack = true }, { Value = 0 })
	local width = o.ShowText == false and 0 or 52
	local track = Create.New("Frame", { Name = "Track", Size = UDim2.new(1, -width, 0, 8), Position = UDim2.new(0, 0, 0.5, -4), Bind = { BackgroundColor3 = "SurfacePressed" }, Parent = control.Host })
	Create.Corner(track, "pill")
	control.Fill = Create.New("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), Bind = { BackgroundColor3 = o.Color or "Accent" }, Parent = track })
	Create.Corner(control.Fill, "pill")
	if width > 0 then
		control.Text = Kit.Text(control.Host, { Size = 12, Mono = true, Align = "Right", Color = "TextMuted", Position = UDim2.new(1, -width, 0, 0), SizeUDim = UDim2.new(0, width, 1, 0) })
	end
	control:Set(o.Default or 0, true, true)
	return finish(control, o)
end

-- Status indicator / tag -------------------------------------------------------------------------------------
local Status = subclass()

function Status:Get()
	return self.State
end

local STATES = { online = "success", ready = "success", active = "success", success = "success", idle = "warn", warn = "warn", warning = "warn", busy = "warn", offline = "muted", disabled = "muted", error = "error", failed = "error", danger = "error", info = "info", accent = "accent", primary = "primary" }

function Status:Set(state, silent, text)
	local kind = STATES[string.lower(tostring(state))] or string.lower(tostring(state))
	self.State = state
	local fg = Kit.KindTokens(kind)
	if self.Dot then
		Anim.Token(self.Dot, "BackgroundColor3", fg, "fast")
		Theme.Bind(self.Label, "TextColor3", fg)
	end
	if text ~= nil then
		Kit.SetText(self.Label, text)
	end
	if self.Badge then
		self.Badge:Set(text, kind)
	end
	emit(self, state, silent)
end

function Status:SetText(text)
	if self.Badge then
		self.Badge:Set(text)
	else
		Kit.SetText(self.Label, text)
	end
end

function C.StatusIndicator(owner, o)
	local control = newControl(Status, owner, o, { HostWidth = 150, HostHeight = 24 }, {})
	control.Dot = Create.New("Frame", { Name = "Dot", Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 0, 0.5, -4), Bind = { BackgroundColor3 = "Success" }, Parent = control.Host })
	Create.Corner(control.Dot, "pill")
	control.Label = Kit.Text(control.Host, { Text = o.Text, Size = 12, Weight = "Medium", Position = UDim2.fromOffset(16, 0), SizeUDim = UDim2.new(1, -16, 1, 0), Align = "Left" })
	control.State = o.State or o.Kind or "online"
	control:Set(control.State, true, nil)
	return finish(control, o)
end

function C.Tag(owner, o)
	local control = newControl(Status, owner, o, { HostWidth = 140, HostHeight = 24 }, {})
	control.Label = nil
	control.Badge = Kit.Badge(control.Host, { Text = o.Text, Kind = o.Kind, Icon = o.BadgeIcon, Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
	control.State = o.Kind or "muted"
	return finish(control, o)
end

-- Label (title + value) ------------------------------------------------------------------------------------------
local LabelControl = subclass()

function LabelControl:Get()
	return self.ValueLabel.Text
end

function LabelControl:Set(value, silent)
	Kit.SetText(self.ValueLabel, value == nil and "" or value)
	emit(self, value, silent)
end

LabelControl.SetText = LabelControl.Set

function C.Label(owner, o)
	local control = newControl(LabelControl, owner, o, { HostWidth = o.Value ~= nil and (o.ValueWidth or 150) or 0, HostHeight = 24 }, {})
	control.Host.Visible = true
	control.ValueLabel = Kit.Text(control.Host, { Text = o.Value, Size = 13, Color = "TextMuted", Align = "Right", Mono = o.Mono, SizeUDim = UDim2.fromScale(1, 1) })
	control.Row.Info.Size = UDim2.new(1, -((o.ValueWidth or 150) + 12), 0, 0)
	return finish(control, o)
end

-- Paragraph ---------------------------------------------------------------------------------------------------
local Paragraph = subclass()

function Paragraph:SetText(source)
	Kit.SetText(self.Body, source)
end

function Paragraph:Get()
	return self.Body.Text
end

function C.Paragraph(owner, o)
	local control = newControl(Paragraph, owner, o, { HostWidth = 0 }, {})
	control.Body = Kit.Text(control.Row.Info, { Text = o.Text, Size = 12, Color = "TextMuted", Wrap = true, Auto = "Y" })
	control.Row.Info:FindFirstChildOfClass("UIListLayout").FillDirection = Enum.FillDirection.Vertical
	control.Row.Info.Text.Size = UDim2.new(1, 0, 0, 0)
	return finish(control, o)
end

-- Divider ----------------------------------------------------------------------------------------------------------
local DividerControl = subclass()

function C.Divider(owner, o)
	o = o or {}
	local frame = Create.New("Frame", { Name = "Divider", Size = UDim2.new(1, 0, 0, o.Text and 28 or 12), LayoutOrder = owner:_order(), Parent = owner.Content })
	local line = Kit.Divider(frame)
	line.Position = UDim2.new(0, 14, 0.5, 0)
	line.Size = UDim2.new(1, -28, 0, 1)
	local control = Kit.New(DividerControl, frame, {})
	Kit.Adopt(owner, control)
	if o.Text then
		local back = Create.New("Frame", { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Bind = { BackgroundColor3 = "Surface" }, Parent = frame })
		Create.Pad(back, 8, 0, 8, 0)
		Kit.Text(back, { Text = o.Text, Size = 11, Weight = "Medium", Color = "TextFaint", Auto = "X", SizeUDim = UDim2.new(0, 0, 1, 0), Transform = Loc.Upper })
		back.AutomaticSize = Enum.AutomaticSize.X
	end
	return control
end

-- Code (monospace block, no syntax highlighting) --------------------------------------------------------------------
local CodeControl = subclass()

function CodeControl:Get()
	return self.Body.Text
end

function CodeControl:Set(text)
	self.Body.Text = tostring(text or "")
	Loc.Unbind(self.Body, "Text")
end

function C.Code(owner, o)
	local control = newControl(CodeControl, owner, o, { HostWidth = 0 }, {})
	control.Row.Info.Visible = o.Title ~= nil
	local holder = Create.New("Frame", { Name = "Code", Size = UDim2.new(1, 0, 0, o.Height or 110), LayoutOrder = 3, Bind = { BackgroundColor3 = "Background" }, Parent = control.Row.Inner })
	Create.Corner(holder, "sm")
	Create.Stroke(holder, "Border")
	local scroll = Kit.Scroll(holder, { Size = UDim2.fromScale(1, 1) })
	Create.Pad(scroll, 10)
	control.Body = Kit.Text(scroll, { Text = o.Text or "", Size = 12, Mono = true, Wrap = true, Auto = "Y", Color = "Text" })
	control.Row.Inner:FindFirstChildOfClass("UIListLayout").FillDirection = Enum.FillDirection.Vertical
	return finish(control, o)
end

-- Block (empty frame for custom content) --------------------------------------------------------------------------
local BlockControl = subclass()

function C.Block(owner, o)
	local frame = Create.New("Frame", { Name = "Block", Size = UDim2.new(1, 0, 0, o.Height or 80), LayoutOrder = owner:_order(), Parent = owner.Content })
	local control = Kit.New(BlockControl, frame, { Content = frame })
	Kit.Adopt(owner, control)
	if o.Build then
		Kit.Safe(o.Build)(frame, control)
	end
	return control
end

-- Aliases kept from DeaUI ------------------------------------------------------------------------------------------
C.Input = C.TextInput
C.Stepper = C.NumberInput
C.Color = C.ColorPicker
C.Progress = C.ProgressBar
C.MultiSelect = C.MultiDropdown

-- Adds every control as a method of the Group class.
function Controls.Attach(Group)
	for name, constructor in pairs(C) do
		if name ~= "Row" then
			Group[name] = function(self, ...)
				return constructor(self, ...)
			end
		end
	end
end

return Controls
end

Modules["UI/Create"] = function(import)
local Theme = import("Theme/Theme")
local Loc = import("Localization")

-- Instance factory. Special keys: Bind = { Property = "Token" }, Loc = { Property = source },
-- Children = { ... }; Parent is applied last.
local Create = {}

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

function Create.New(class, props)
	props = props or {}
	local instance = Instance.new(class)
	local bind = props.Bind or {}
	local isGui = class == "Frame" or class == "ScrollingFrame" or class == "CanvasGroup" or class == "ViewportFrame" or TEXT_CLASSES[class] or class == "ImageLabel" or class == "ImageButton"
	if isGui then
		instance.BorderSizePixel = 0
		if props.BackgroundColor3 == nil and bind.BackgroundColor3 == nil and props.BackgroundTransparency == nil then
			instance.BackgroundTransparency = 1
		end
	end
	if TEXT_CLASSES[class] then
		instance.FontFace = Theme.Font
		if props.TextColor3 == nil and bind.TextColor3 == nil then
			Theme.Bind(instance, "TextColor3", "Text")
		end
	end
	if class == "TextButton" or class == "ImageButton" then
		instance.AutoButtonColor = false
	end
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "Bind" and key ~= "Loc" and key ~= "Children" then
			instance[key] = value
		end
	end
	for property, token in pairs(bind) do
		Theme.Bind(instance, property, token)
	end
	if props.Loc then
		for property, source in pairs(props.Loc) do
			Loc.Bind(instance, property, source)
		end
	end
	if props.Children then
		for _, child in ipairs(props.Children) do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

-- UICorner following the theme radius ("sm" | "md" | "lg" | "xl" | "pill" | pixels).
function Create.Corner(parent, radius)
	local corner = Instance.new("UICorner")
	Theme.BindRadius(corner, radius or "md")
	corner.Parent = parent
	return corner
end

function Create.Stroke(parent, token, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	Theme.Bind(stroke, "Color", token or "Border")
	stroke.Parent = parent
	return stroke
end

function Create.Pad(parent, left, top, right, bottom)
	local pad = Instance.new("UIPadding")
	if top == nil then
		top, right, bottom = left, left, left
	end
	pad.PaddingLeft = UDim.new(0, left or 0)
	pad.PaddingTop = UDim.new(0, top or 0)
	pad.PaddingRight = UDim.new(0, right or left or 0)
	pad.PaddingBottom = UDim.new(0, bottom or top or 0)
	pad.Parent = parent
	return pad
end

-- Padding / list gap that follow the theme Spacing metric (base 8): Create.PadScaled / Create.ListScaled
function Create.PadScaled(parent, left, top, right, bottom)
	if top == nil then
		top, right, bottom = left, left, left
	end
	right, bottom = right or left, bottom or top
	local pad = Create.Pad(parent, left, top, right, bottom)
	Theme.OnChange(pad, function()
		local factor = Theme.Metrics().Spacing / 8
		pad.PaddingLeft = UDim.new(0, math.floor(left * factor + 0.5))
		pad.PaddingTop = UDim.new(0, math.floor(top * factor + 0.5))
		pad.PaddingRight = UDim.new(0, math.floor(right * factor + 0.5))
		pad.PaddingBottom = UDim.new(0, math.floor(bottom * factor + 0.5))
	end)
	return pad
end

-- props: Padding (px), Dir = "V" | "H", HAlign, VAlign (names), Wrap
function Create.List(parent, props)
	props = props or {}
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.FillDirection = props.Dir == "H" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, props.Padding or 0)
	if props.HAlign then
		list.HorizontalAlignment = Enum.HorizontalAlignment[props.HAlign]
	end
	if props.VAlign then
		list.VerticalAlignment = Enum.VerticalAlignment[props.VAlign]
	end
	if props.Wrap then
		list.Wraps = true
	end
	list.Parent = parent
	return list
end

function Create.ListScaled(parent, props)
	local list = Create.List(parent, props)
	local base = (props or {}).Padding or 0
	Theme.OnChange(list, function()
		list.Padding = UDim.new(0, math.floor(base * Theme.Metrics().Spacing / 8 + 0.5))
	end)
	return list
end

-- props: Cell = UDim2, Padding = Vector2|number, HAlign
function Create.Grid(parent, props)
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellSize = props.Cell or UDim2.fromOffset(100, 100)
	local pad = props.Padding or 8
	if type(pad) == "number" then
		pad = Vector2.new(pad, pad)
	end
	grid.CellPadding = UDim2.fromOffset(pad.X, pad.Y)
	if props.HAlign then
		grid.HorizontalAlignment = Enum.HorizontalAlignment[props.HAlign]
	end
	grid.Parent = parent
	return grid
end

return Create
end

Modules["UI/Dashboard"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

--[[
	Dashboard blocks (page: or group: methods):
	  StatCard, StatGrid, CurrencyDisplay, LevelDisplay, MultiplierDisplay, ActivityFeed
	All values are plain data: your script pushes numbers in (card:Set(value)) and reads callbacks out.
]]
local Dashboard = { Blocks = {} }
local B = Dashboard.Blocks

-- StatCard ----------------------------------------------------------------------------------------------------------------
local Stat = Kit.Class()

function Stat:Render(value)
	local text = Util.Format.Apply(self.Format, value)
	self.ValueLabel.Text = (self.Prefix or "") .. text .. (self.Suffix or "")
	Loc.Unbind(self.ValueLabel, "Text")
end

function Stat:Set(value, instant)
	value = tonumber(value) or 0
	self.Value = value
	self.Counter:Set(value, instant)
	self.Changed:Fire(value)
end

function Stat:Get()
	return self.Value
end

function Stat:Add(delta)
	self:Set(self.Value + (tonumber(delta) or 0))
end

function Stat:SetTitle(source)
	Kit.SetText(self.TitleLabel, source)
end

function Stat:SetSubtext(source, kind)
	Kit.SetText(self.SubLabel, source or "")
	self.SubLabel.Visible = source ~= nil and source ~= ""
	local fg = Kit.KindTokens(kind or "muted")
	Theme.Bind(self.SubLabel, "TextColor3", fg)
end

function Stat:SetKind(kind)
	local fg, soft = Kit.KindTokens(kind)
	Theme.Bind(self.Well, "BackgroundColor3", soft)
	Theme.Bind(self.IconImage, "ImageColor3", fg)
end

function Stat:SetIcon(name)
	Kit.SetIcon(self.IconImage, name)
end

function Stat:OnDestroy()
	self.Counter:Destroy()
end

-- o: Title, Value, Format ("compact"|"number"|"percent"|"time"|fn), Prefix, Suffix, Icon, Kind, Subtext, SubKind, Size
local function statCard(parent, o)
	o = o or {}
	local card = Kit.Panel(parent, { Name = o.Name or "StatCard", Size = o.Size or UDim2.new(1, 0, 0, 84), Order = o.Order, Visible = o.Visible })
	Create.Pad(card, 12, 10, 12, 10)
	local fg, soft = Kit.KindTokens(o.Kind or "primary")
	local well = Create.New("Frame", { Name = "Well", Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Bind = { BackgroundColor3 = soft }, Parent = card })
	Create.Corner(well, "sm")
	local icon = Kit.Icon(well, o.Icon, 16, fg, { Position = UDim2.new(0.5, -8, 0.5, -8) })
	well.Visible = o.Icon ~= nil
	local title = Kit.Text(card, { Text = o.Title, Size = 12, Color = "TextMuted", SizeUDim = UDim2.new(1, -38, 0, 16) })
	local value = Kit.Text(card, { Size = 20, Weight = "Bold", Position = UDim2.fromOffset(0, 18), SizeUDim = UDim2.new(1, 0, 0, 28) })
	local sub = Kit.Text(card, { Size = 11, Weight = "Medium", Position = UDim2.fromOffset(0, 48), SizeUDim = UDim2.new(1, 0, 0, 14) })
	local object = Kit.New(Stat, card, {
		Format = o.Format, Prefix = o.Prefix, Suffix = o.Suffix, ValueLabel = value, TitleLabel = title, SubLabel = sub, Well = well, IconImage = icon, Value = 0,
	})
	object.Changed = Signal.new()
	object.Counter = Anim.Number(0, function(v)
		object:Render(v)
	end, { Epsilon = o.Format == "percent" and 0.0005 or 0.5 })
	object:Set(o.Value or 0, true)
	object:SetSubtext(o.Subtext, o.SubKind)
	return object
end

function B.StatCard(container, o)
	local holder = Kit.BlockHolder(container, { Name = "StatCard" })
	local card = statCard(holder, o)
	card.Holder = holder
	card.Scope:Add(function()
		holder:Destroy()
	end)
	return card
end

-- StatGrid ------------------------------------------------------------------------------------------------------------------
local StatGrid = Kit.Class()

function StatGrid:Add(o)
	o = o or {}
	local card = statCard(self.Grid.Frame, Util.merge(o, { Size = UDim2.fromOffset(150, 84), Order = #self.Order + 1 }))
	local id = o.Id or ("stat" .. (#self.Order + 1))
	self.Items[id] = card
	table.insert(self.Order, id)
	self.Scope:Add(card)
	return card
end

function StatGrid:Get(id)
	return self.Items[id]
end

function StatGrid:Set(id, value, instant)
	local card = self.Items[id]
	if card then
		card:Set(value, instant)
	end
end

function B.StatGrid(container, o)
	o = o or {}
	local holder = Kit.BlockHolder(container, { Name = "StatGrid" })
	local grid = Kit.Grid(holder, { Min = o.MinWidth or 150, Max = o.Columns or 4, Height = o.CardHeight or 84, Gap = 8 })
	local object = Kit.New(StatGrid, holder, { Grid = grid, Items = {}, Order = {} })
	for _, item in ipairs(o.Items or {}) do
		object:Add(item)
	end
	return object
end

-- CurrencyDisplay --------------------------------------------------------------------------------------------------------------
local Currency = Kit.Class()

function Currency:_pill(id)
	return self.Pills[id or self.Single]
end

function Currency:Set(a, b)
	local id, value = a, b
	if b == nil then
		id, value = self.Single, a
	end
	local pill = self.Pills[id]
	if pill then
		pill.Value = tonumber(value) or 0
		pill.Counter:Set(pill.Value)
		self.Changed:Fire(id, pill.Value)
	end
end

function Currency:Add(a, b)
	local id, delta = a, b
	if b == nil then
		id, delta = self.Single, a
	end
	local pill = self.Pills[id]
	if pill then
		self:Set(id, pill.Value + (tonumber(delta) or 0))
	end
end

function Currency:Get(id)
	local pill = self.Pills[id or self.Single]
	return pill and pill.Value or 0
end

function Currency:SetRate(id, text)
	local pill = self.Pills[id or self.Single]
	if pill and pill.RateLabel then
		Kit.SetText(pill.RateLabel, text or "")
		pill.RateLabel.Visible = text ~= nil and text ~= ""
	end
end

function Currency:OnDestroy()
	for _, pill in pairs(self.Pills) do
		pill.Counter:Destroy()
	end
end

-- o: Id, Icon, Value, Color (Color3), Kind, Rate (text), Format, Callback (shows a "+" button), Items = { {same fields...} }
function B.CurrencyDisplay(container, o)
	o = o or {}
	local holder = Kit.BlockHolder(container, { Name = "CurrencyDisplay" })
	Create.List(holder, { Dir = "H", Padding = 8, Wrap = true })
	holder.AutomaticSize = Enum.AutomaticSize.Y
	local object = Kit.New(Currency, holder, { Pills = {} })
	object.Changed = Signal.new()
	local items = o.Items or { o }
	object.Single = #items == 1 and (items[1].Id or "currency") or nil
	for index, item in ipairs(items) do
		local id = item.Id or "currency"
		local fg = Kit.KindTokens(item.Kind or "warn")
		local pill = Kit.Panel(holder, { Name = "Currency", Size = UDim2.fromOffset(0, 36), Order = index, Radius = "pill", Token = "SurfaceRaised" })
		pill.AutomaticSize = Enum.AutomaticSize.X
		Create.Pad(pill, 8, 0, item.Callback and 4 or 12, 0)
		Create.List(pill, { Dir = "H", Padding = 6, VAlign = "Center" })
		local icon = Kit.Icon(pill, item.Icon or "coins", 18, fg, { Order = 1 })
		if item.Color then
			icon.ImageColor3 = item.Color
			Theme.Unbind(icon, "ImageColor3")
		end
		local label = Kit.Text(pill, { Size = 14, Weight = "Bold", Mono = true, Auto = "X", Order = 2 })
		label.Size = UDim2.new(0, 0, 1, 0)
		local rate = Kit.Text(pill, { Text = item.Rate, Size = 11, Color = "Success", Auto = "X", Order = 3 })
		rate.Size = UDim2.new(0, 0, 1, 0)
		rate.Visible = item.Rate ~= nil
		local entry = { Value = 0, RateLabel = rate }
		entry.Counter = Anim.Number(0, function(v)
			label.Text = Util.Format.Apply(item.Format, v)
			Loc.Unbind(label, "Text")
		end, { Epsilon = 0.5 })
		if item.Callback then
			local plus = Kit.Button(pill, { Icon = "plus", Variant = "soft", Height = 26, Width = 26, Compact = true, Order = 4, Callback = item.Callback })
			object.Scope:Add(plus)
		end
		object.Pills[id] = entry
		entry.Value = item.Value or 0
		entry.Counter:Set(entry.Value, true)
	end
	return object
end

-- LevelDisplay ----------------------------------------------------------------------------------------------------------------------
local Level = Kit.Class()

function Level:Set(level, xp, max)
	if type(level) == "table" then
		level, xp, max = level.Level, level.XP, level.Max
	end
	self.Level = level or self.Level
	self.XP = xp or self.XP
	self.Max = max or self.Max
	self.Badge.Text = tostring(self.Level)
	Loc.Unbind(self.Badge, "Text")
	local fraction = self.Max > 0 and Util.clamp(self.XP / self.Max, 0, 1) or 1
	Anim.Tween(self.Fill, { Size = UDim2.fromScale(fraction, 1) }, "base")
	self.XPLabel.Text = Util.Format.Number(self.XP) .. " / " .. Util.Format.Number(self.Max) .. " XP"
	Loc.Unbind(self.XPLabel, "Text")
	self.Percent.Text = Util.Format.Percent(fraction)
	Loc.Unbind(self.Percent, "Text")
end

function Level:Get()
	return { Level = self.Level, XP = self.XP, Max = self.Max }
end

function Level:SetLevel(level)
	self:Set(level, self.XP, self.Max)
end

function Level:SetXP(xp, max)
	self:Set(self.Level, xp, max or self.Max)
end

-- o: Level, XP, Max, Title (default "Level"), Kind
function B.LevelDisplay(container, o)
	o = o or {}
	local holder = Kit.BlockHolder(container, { Name = "LevelDisplay" })
	local card = Kit.Panel(holder, { Name = "Level", Size = UDim2.new(1, 0, 0, 72) })
	Create.Pad(card, 14, 12, 14, 12)
	local badge = Create.New("Frame", { Name = "Badge", Size = UDim2.fromOffset(46, 46), Bind = { BackgroundColor3 = "PrimarySoft" }, Parent = card })
	Create.Corner(badge, "pill")
	Create.Stroke(badge, "Primary", 2)
	local number = Kit.Text(badge, { Size = 17, Weight = "Bold", Align = "Center", Color = "Primary", SizeUDim = UDim2.fromScale(1, 1), Mono = true })
	Kit.Text(card, { Text = o.Title or "common.level", Size = 13, Weight = "Bold", Position = UDim2.fromOffset(58, 2), SizeUDim = UDim2.new(1, -120, 0, 18) })
	local percent = Kit.Text(card, { Size = 12, Mono = true, Color = "Accent", Align = "Right", Position = UDim2.new(1, -60, 0, 2), SizeUDim = UDim2.new(0, 60, 0, 18) })
	local track = Create.New("Frame", { Size = UDim2.new(1, -58, 0, 8), Position = UDim2.fromOffset(58, 26), Bind = { BackgroundColor3 = "SurfacePressed" }, Parent = card })
	Create.Corner(track, "pill")
	local fill = Create.New("Frame", { Size = UDim2.fromScale(0, 1), Bind = { BackgroundColor3 = "Accent" }, Parent = track })
	Create.Corner(fill, "pill")
	local xpLabel = Kit.Text(card, { Size = 11, Color = "TextMuted", Mono = true, Position = UDim2.fromOffset(58, 38), SizeUDim = UDim2.new(1, -58, 0, 14) })
	local object = Kit.New(Level, holder, { Badge = number, Fill = fill, XPLabel = xpLabel, Percent = percent, Level = o.Level or 1, XP = o.XP or 0, Max = o.Max or 100 })
	object:Set(object.Level, object.XP, object.Max)
	fill.Size = UDim2.fromScale(object.Max > 0 and Util.clamp(object.XP / object.Max, 0, 1) or 1, 1)
	return object
end

-- MultiplierDisplay -------------------------------------------------------------------------------------------------------------------
local Multiplier = Kit.Class()

function Multiplier:Total()
	local total = 1
	for _, entry in ipairs(self.Order) do
		total = total * (tonumber(entry.Data.Value) or 1)
	end
	return total
end

function Multiplier:_refresh()
	self.TotalLabel.Text = "x" .. Util.Format.Compact(self:Total(), 2)
	Loc.Unbind(self.TotalLabel, "Text")
	self.EmptyLabel.Visible = #self.Order == 0
	for index, entry in ipairs(self.Order) do
		entry.Row.LayoutOrder = index
	end
end

function Multiplier:_find(id)
	for index, entry in ipairs(self.Order) do
		if entry.Id == id then
			return entry, index
		end
	end
end

function Multiplier:Remove(id)
	local entry, index = self:_find(id)
	if not entry then
		return false
	end
	table.remove(self.Order, index)
	entry.Row:Destroy()
	self:_refresh()
	return true
end

function Multiplier:Clear()
	for _, entry in ipairs(self.Order) do
		entry.Row:Destroy()
	end
	self.Order = {}
	self:_refresh()
end

function Multiplier:Update(id, patch)
	local entry = self:_find(id)
	if not entry then
		return false
	end
	if type(patch) ~= "table" then
		patch = { Value = patch }
	end
	for key, value in pairs(patch) do
		entry.Data[key] = value
	end
	if patch.Text ~= nil then
		Kit.SetText(entry.Text, patch.Text)
	end
	if patch.Value ~= nil then
		entry.Chip.Text = "x" .. Util.Format.Compact(tonumber(entry.Data.Value) or 1, 2)
		Loc.Unbind(entry.Chip, "Text")
	end
	if patch.Duration ~= nil then
		entry.Until = patch.Duration and (os.clock() + patch.Duration) or nil
	end
	self:_refresh()
	return true
end

function Multiplier:Add(item)
	local id = item.Id or ("mult" .. (#self.Order + 1))
	if self:_find(id) then
		self:Update(id, item)
		return id
	end
	local fg = Kit.KindTokens(item.Kind or "accent")
	local row = Create.New("Frame", { Name = "Multiplier", Size = UDim2.new(1, 0, 0, 34), Parent = self.List })
	local entry = { Id = id, Row = row, Data = Util.clone(item) }
	Kit.Icon(row, item.Icon or "zap", 16, fg, { Position = UDim2.new(0, 0, 0.5, -8) })
	entry.Text = Kit.Text(row, { Text = item.Text, Size = 13, Position = UDim2.fromOffset(26, 0), SizeUDim = UDim2.new(1, -150, 1, 0) })
	entry.Timer = Kit.Text(row, { Size = 11, Mono = true, Color = "TextMuted", Align = "Right", Position = UDim2.new(1, -140, 0, 0), SizeUDim = UDim2.new(0, 60, 1, 0) })
	local chip = Create.New("Frame", { Size = UDim2.fromOffset(64, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Bind = { BackgroundColor3 = "AccentSoft" }, Parent = row })
	Create.Corner(chip, "pill")
	entry.Chip = Kit.Text(chip, { Size = 12, Weight = "Bold", Mono = true, Align = "Center", Color = "Accent", SizeUDim = UDim2.fromScale(1, 1) })
	if item.Duration then
		entry.Until = os.clock() + item.Duration
	end
	table.insert(self.Order, entry)
	self:Update(id, { Value = item.Value or 1 })
	return id
end

-- o: Title, Items = { { Id, Text, Value (2.5 = x2.5), Icon, Kind, Duration (seconds) } }, OnExpire(id)
function B.MultiplierDisplay(container, o)
	o = o or {}
	local holder = Kit.BlockHolder(container, { Name = "MultiplierDisplay" })
	local card = Kit.Panel(holder, { Name = "Multipliers", Size = UDim2.new(1, 0, 0, 0), AutoY = true })
	Create.List(card, { Padding = 0 })
	local header = Create.New("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = card })
	Create.Pad(header, 14, 0, 14, 0)
	Kit.Text(header, { Text = o.Title or "multiplier.title", Size = 13, Weight = "Bold", SizeUDim = UDim2.new(1, -80, 1, 0) })
	local total = Kit.Text(header, { Size = 15, Weight = "Bold", Mono = true, Color = "Accent", Align = "Right", Position = UDim2.new(1, -80, 0, 0), SizeUDim = UDim2.new(0, 80, 1, 0) })
	local body = Create.New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
	Create.Pad(body, 14, 0, 14, 10)
	local list = Create.New("Frame", { Name = "List", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
	Create.List(list, { Padding = 2 })
	local empty = Kit.Text(body, { Text = "multiplier.empty", Size = 12, Color = "TextMuted", SizeUDim = UDim2.new(1, 0, 0, 24) })
	local object = Kit.New(Multiplier, holder, { Order = {}, List = list, TotalLabel = total, EmptyLabel = empty })
	object.Changed = Signal.new()
	local onExpire = Kit.Safe(o.OnExpire)
	object.Scope:Add(Kit.Tick(function()
		for _, entry in ipairs(Util.clone(object.Order)) do
			if entry.Until then
				local left = entry.Until - os.clock()
				if left <= 0 then
					object:Remove(entry.Id)
					if onExpire then
						onExpire(entry.Id)
					end
				else
					entry.Timer.Text = Util.Format.Time(left)
				end
			else
				entry.Timer.Text = ""
			end
		end
	end))
	for _, item in ipairs(o.Items or {}) do
		object:Add(item)
	end
	object:_refresh()
	return object
end

-- ActivityFeed -----------------------------------------------------------------------------------------------------------------------------
local Feed = Kit.Class()

local function ago(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m"
	end
	return math.floor(seconds / 3600) .. "h"
end

function Feed:Add(entry)
	if type(entry) ~= "table" or (entry.Text == nil and entry[1] ~= nil) then
		entry = { Text = type(entry) == "table" and entry[1] or entry }
	end
	local fg = Kit.KindTokens(entry.Kind or "muted")
	local row = Create.New("Frame", { Name = "Entry", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = -self.Counter, Parent = self.Scroll })
	self.Counter = self.Counter + 1
	Create.Pad(row, 0, 5, 0, 5)
	local icon = Kit.Icon(row, entry.Icon or "dot", 14, fg, { Position = UDim2.fromOffset(0, 2) })
	local text = Kit.Text(row, { Text = entry.Text, Size = 12, Wrap = true, Auto = "Y", Position = UDim2.fromOffset(22, 0), SizeUDim = UDim2.new(1, -64, 0, 0) })
	local stamp = Kit.Text(row, { Size = 11, Mono = true, Color = "TextFaint", Align = "Right", Position = UDim2.new(1, -36, 0, 0), SizeUDim = UDim2.new(0, 36, 0, 16) })
	local item = { Row = row, Time = os.clock(), Stamp = stamp }
	stamp.Text = ago(0)
	table.insert(self.Items, item)
	while #self.Items > self.Limit do
		local old = table.remove(self.Items, 1)
		old.Row:Destroy()
	end
	self.EmptyLabel.Visible = false
	self.Scroll.CanvasPosition = Vector2.new(0, 0)
	return item
end

function Feed:Clear()
	for _, item in ipairs(self.Items) do
		item.Row:Destroy()
	end
	self.Items = {}
	self.EmptyLabel.Visible = true
end

-- o: Title, Height, Limit (max entries, default 50), Empty (text), Items
function B.ActivityFeed(container, o)
	o = o or {}
	local holder = Kit.BlockHolder(container, { Name = "ActivityFeed" })
	local card = Kit.Panel(holder, { Name = "Feed", Size = UDim2.new(1, 0, 0, 0), AutoY = true })
	Create.List(card, { Padding = 0 })
	if o.Title ~= false then
		local header = Create.New("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = card })
		Create.Pad(header, 14, 0, 14, 0)
		Kit.Text(header, { Text = o.Title or "feed.title", Size = 13, Weight = "Bold", SizeUDim = UDim2.fromScale(1, 1) })
	end
	local body = Create.New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, o.Height or 200), LayoutOrder = 2, Parent = card })
	local scroll = Kit.Scroll(body, { Size = UDim2.fromScale(1, 1) })
	Create.Pad(scroll, 14, 0, 14, 8)
	Create.List(scroll, { Padding = 0 })
	local empty = Kit.Text(body, { Text = o.Empty or "feed.empty", Size = 12, Color = "TextMuted", Align = "Center", SizeUDim = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 20) })
	local object = Kit.New(Feed, holder, { Scroll = scroll, EmptyLabel = empty, Items = {}, Counter = 0, Limit = o.Limit or 50 })
	object.Scope:Add(Kit.Tick(function()
		for _, item in ipairs(object.Items) do
			item.Stamp.Text = ago(os.clock() - item.Time)
		end
	end))
	for _, entry in ipairs(o.Items or {}) do
		object:Add(entry)
	end
	return object
end

return Dashboard
end

Modules["UI/Dialog"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Root = import("UI/Root")
local Services = import("Core/Services")
local Popup = import("UI/Popup")

--[[
	Modal dialogs with a dimmed backdrop (one at a time, others wait in a queue).
	  Dialog.Show({ Title, Message, Icon, Kind, Buttons = { { Id, Text, Variant, Primary } }, Content = fn(frame, dialog),
	                Dismissible = true, Callback = fn(buttonId) })
	  Dialog.Confirm({ Title, Message, Yes, No, Danger, Callback })  -> true / false   (yields unless a Callback is given)
	  Dialog.Prompt({ Title, Message, Default, Placeholder, Validate })  -> string | nil (yields unless a Callback is given)
	Escape or a click on the backdrop cancels; Enter presses the primary button.
]]
local Dialog = {}

local current
local waiting = {}

local KIND_ICON = { info = "info", success = "check-circle", warn = "alert-triangle", warning = "alert-triangle", danger = "alert-triangle", error = "x-circle" }

local function next_()
	current = nil
	local item = table.remove(waiting, 1)
	if item then
		item()
	end
end

function Dialog.Show(o)
	o = o or {}
	local handle = { Closed = false }
	local function open()
		if not Root.Ready then
			next_()
			return
		end
		Popup.Close(true)
		current = handle
		local screen = Root.ScreenSize()
		local width = math.min(400, screen.X - 32)
		local backdrop = Create.New("TextButton", { Name = "DialogBackdrop", Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1, ZIndex = 300, Bind = { BackgroundColor3 = "Overlay" }, Parent = Root.Layer })
		local card = Create.New("CanvasGroup", { Name = "Dialog", Size = UDim2.new(0, width, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), GroupTransparency = 1, ZIndex = 301, Bind = { BackgroundColor3 = "Surface" }, Parent = backdrop })
		Create.Corner(card, "lg")
		Create.Stroke(card, "BorderStrong")
		local scale = Instance.new("UIScale")
		scale.Scale = 0.95
		scale.Parent = card
		local body = Create.New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
		Create.Pad(body, 20, 20, 20, 18)
		Create.List(body, { Padding = 12 })
		local head = Create.New("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body })
		Create.List(head, { Dir = "H", Padding = 12 })
		local fg, soft = Kit.KindTokens(o.Kind or "primary")
		local well = Create.New("Frame", { Size = UDim2.fromOffset(40, 40), LayoutOrder = 1, Bind = { BackgroundColor3 = soft }, Parent = head })
		Create.Corner(well, "pill")
		Kit.Icon(well, o.Icon or KIND_ICON[string.lower(tostring(o.Kind or "info"))] or "info", 20, fg, { Position = UDim2.new(0.5, -10, 0.5, -10) })
		local text = Create.New("Frame", { Size = UDim2.new(1, -52, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = head })
		Create.List(text, { Padding = 4 })
		Kit.Text(text, { Text = o.Title, Size = 15, Weight = "Bold", Wrap = true, Auto = "Y", Order = 1 })
		if o.Message ~= nil and o.Message ~= "" then
			Kit.Text(text, { Text = o.Message, Size = 13, Color = "TextMuted", Wrap = true, Auto = "Y", Order = 2 })
		end
		if o.Content then
			local holder = Create.New("Frame", { Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = body })
			Kit.Safe(o.Content)(holder, handle)
		end
		local buttons = o.Buttons or { { Id = "ok", Text = "common.ok", Variant = "primary", Primary = true } }
		local row = Create.New("Frame", { Name = "Buttons", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = body })
		local stacked = width < 340
		Create.List(row, { Dir = stacked and "V" or "H", Padding = 8, HAlign = stacked and "Center" or "Right" })
		local primary
		for index = #buttons, 1, -1 do
			local spec = buttons[index]
			local button = Kit.Button(row, { Text = spec.Text, Icon = spec.Icon, Variant = spec.Variant or (spec.Primary and "primary") or "secondary", MinWidth = 88, Order = index, Callback = function()
				handle:Close(spec.Id, spec)
			end })
			if stacked then
				button.Frame.AutomaticSize = Enum.AutomaticSize.None
				button.Frame.Size = UDim2.new(1, 0, 0, Kit.Control())
				button.Frame.LayoutOrder = #buttons - index + 1
			end
			if spec.Primary then
				primary = spec
			end
		end
		handle.Backdrop, handle.Card, handle.Primary = backdrop, card, primary
		local links = {}
		handle.Links = links
		links[#links + 1] = Services.UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape and o.Dismissible ~= false then
				handle:Close(o.CancelId or "cancel")
			elseif (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) and primary and not Services.UserInputService:GetFocusedTextBox() then
				handle:Close(primary.Id, primary)
			end
		end)
		links[#links + 1] = Root.Changed:Connect(function()
			if card.Parent then
				card.Size = UDim2.new(0, math.min(400, Root.ScreenSize().X - 32), 0, 0)
			end
		end)
		backdrop.Activated:Connect(function()
			if o.Dismissible ~= false then
				handle:Close(o.CancelId or "cancel")
			end
		end)
		Anim.Tween(backdrop, { BackgroundTransparency = Theme.Token("OverlayTransparency") or 0.4 }, "base")
		Anim.Tween(card, { GroupTransparency = 0 }, "base")
		Anim.Tween(scale, { Scale = 1 }, "base")
		handle.Scale = scale
	end

	function handle:Close(id, spec)
		if self.Closed then
			return
		end
		self.Closed = true
		for _, link in ipairs(self.Links or {}) do
			link:Disconnect()
		end
		local backdrop, card = self.Backdrop, self.Card
		local function finish()
			if backdrop then
				backdrop:Destroy()
			end
			if current == self then
				next_()
			end
		end
		if backdrop and Anim.Enabled() then
			backdrop.Active = false
			Anim.Tween(backdrop, { BackgroundTransparency = 1 }, "fast")
			Anim.Tween(card, { GroupTransparency = 1 }, { Duration = "fast", OnComplete = finish })
		else
			finish()
		end
		if o.Callback then
			Kit.Safe(o.Callback)(id or "cancel", spec, self)
		end
	end

	handle.Open = open
	if current then
		table.insert(waiting, open)
	else
		open()
	end
	return handle
end

local function wait(show, options, transform)
	if options.Callback then
		return show(options)
	end
	local thread = coroutine.running()
	local settled = false
	local result
	local copy = {}
	for key, value in pairs(options) do
		copy[key] = value
	end
	copy.Callback = function(id, spec, dialog)
		result = transform(id, dialog)
		if settled == "waiting" then
			task.spawn(thread, result)
		end
		settled = true
	end
	show(copy)
	if settled == true then
		return result
	end
	settled = "waiting"
	return coroutine.yield()
end

function Dialog.Confirm(o)
	o = o or {}
	local options = {
		Title = o.Title or "dialog.confirm_title",
		Message = o.Message,
		Kind = o.Danger and "danger" or o.Kind or "primary",
		Icon = o.Icon,
		CancelId = "no",
		Callback = o.Callback and function(id)
			o.Callback(id == "yes")
		end or nil,
		Buttons = {
			{ Id = "no", Text = o.No or "common.cancel" },
			{ Id = "yes", Text = o.Yes or "common.confirm", Variant = o.Danger and "danger" or "primary", Primary = true },
		},
	}
	return wait(Dialog.Show, options, function(id)
		return id == "yes"
	end)
end

function Dialog.Prompt(o)
	o = o or {}
	local field
	local options = {
		Title = o.Title or "dialog.prompt_title",
		Message = o.Message,
		Icon = o.Icon or "pen-line",
		CancelId = "cancel",
		Buttons = { { Id = "cancel", Text = "common.cancel" }, { Id = "ok", Text = o.Ok or "common.ok", Variant = "primary", Primary = true } },
		Content = function(frame, dialog)
			field = Kit.Field(frame, { Placeholder = o.Placeholder, Text = o.Default, OnSubmit = function(_, enter)
				if enter then
					dialog:Close("ok")
				end
			end })
			task.defer(function()
				if field and field.Box.Parent then
					field.Box:CaptureFocus()
				end
			end)
		end,
		Callback = o.Callback and function(id)
			local text = field and field.Box.Text or ""
			if id == "ok" and (not o.Validate or o.Validate(text)) then
				o.Callback(text)
			else
				o.Callback(nil)
			end
		end or nil,
	}
	return wait(Dialog.Show, options, function(id)
		local text = field and field.Box.Text or ""
		if id == "ok" and (not o.Validate or o.Validate(text)) then
			return text
		end
		return nil
	end)
end

function Dialog.Clear()
	waiting = {}
	if current and not current.Closed then
		current:Close("cancel")
	end
end

function Dialog.Destroy()
	waiting = {}
	if current then
		current.Closed = true
		for _, link in ipairs(current.Links or {}) do
			link:Disconnect()
		end
		if current.Backdrop then
			current.Backdrop:Destroy()
		end
	end
	current = nil
end

return Dialog
end

Modules["UI/Drag"] = function(import)
local Services = import("Core/Services")
local Input = import("Core/Input")
local Util = import("Core/Util")
local Anim = import("Animation")
local Root = import("UI/Root")

-- Window / HUD dragging (preserved from DeaUI): the frame eases towards the pointer and, after the
-- release, settles on a fully visible position, so it is never left half outside of the screen.
local Drag = {}

-- Fully visible position with a margin inside the safe area (logical pixels).
function Drag.Fit(position, size, margin)
	margin = margin or 8
	local screen = Root.ScreenSize()
	local insets = Root.Insets()
	local minX, minY = insets.Left + margin, insets.Top + margin
	local maxX = math.max(minX, screen.X - insets.Right - size.X - margin)
	local maxY = math.max(minY, screen.Y - insets.Bottom - size.Y - margin)
	return Vector2.new(Util.clamp(position.X, minX, maxX), Util.clamp(position.Y, minY, maxY))
end

-- Makes `frame` (AnchorPoint 0,0 and an offset Position) draggable through `handle`.
--   Options.Clamp(position, size) -> position   limit while dragging
--   Options.Rest(position, size)  -> position   resting place after release (default: Drag.Fit)
--   Options.OnEnd(position)                      called when the frame has settled
--   Options.OnBegin()                            called when a drag starts
--   Options.Enabled() -> bool                    drag only while true (e.g. not on phones)
function Drag.Bind(handle, frame, options)
	options = options or {}
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
		if Anim.Enabled() then
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
			link = Services.RunService.RenderStepped:Connect(step)
		end
	end

	local drag = Input.Drag(handle, {
		Begin = function()
			if options.Enabled and not options.Enabled() then
				startPosition = nil
				return
			end
			startPosition = (link and target) or current()
			target = startPosition
			if options.OnBegin then
				options.OnBegin()
			end
			run()
		end,
		Move = function(delta)
			if not startPosition then
				return
			end
			local size = Vector2.new(frame.AbsoluteSize.X, frame.AbsoluteSize.Y) / Root.Scale
			local wanted = startPosition + delta / Root.Scale
			if options.Clamp then
				wanted = options.Clamp(wanted, size)
			else
				local screen = Root.ScreenSize()
				local insets = Root.Insets()
				wanted = Vector2.new(
					Util.clamp(wanted.X, insets.Left - size.X + 80, screen.X - insets.Right - 80),
					Util.clamp(wanted.Y, insets.Top, screen.Y - insets.Bottom - 40)
				)
			end
			target = wanted
		end,
		End = function()
			if not startPosition then
				return
			end
			startPosition = nil
			local size = Vector2.new(frame.AbsoluteSize.X, frame.AbsoluteSize.Y) / Root.Scale
			target = (options.Rest or Drag.Fit)(target or current(), size)
			run()
		end,
	})

	return {
		Disconnect = function()
			drag.Disconnect()
			stop()
		end,
		Clean = function()
			drag.Disconnect()
			stop()
		end,
	}
end

return Drag
end

Modules["UI/Gallery"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Assets = import("UI/Assets")
local Widgets = import("UI/Widgets")
local Controls = import("UI/Controls")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

--[[
	AssetGallery: searchable, filterable grid / list of items with image or 3D previews, rarity borders,
	single or multiple selection and a details panel.
	AssetBrowser: a gallery fed by discovery of developer-chosen containers (or by your own provider).
	Items are plain tables: { Id, Name, Image, Model, Rarity, Amount, Subtitle, Description, Data }.
]]
local Gallery = { Blocks = {} }
local G = Kit.Class()

local PAGE = 60

local function rarityText(rarity)
	local key = "rarity." .. string.lower(tostring(rarity))
	return Loc.Known(key) and key or tostring(rarity)
end

function G:GetSelected()
	local out = {}
	for _, item in ipairs(self.Items) do
		if self.Selected[item.Id] then
			out[#out + 1] = item
		end
	end
	return out
end

function G:Get()
	local selected = self:GetSelected()
	if self.Mode == "Multi" then
		return selected
	end
	return selected[1]
end

local function matches(self, item)
	local filter = self.Filter
	if filter and filter ~= "All" and tostring(item.Rarity) ~= filter then
		return false
	end
	local query = self.Query
	if query ~= "" then
		local hay = Util.Fold(Loc.Resolve(item.Name) .. " " .. Loc.Resolve(item.Subtitle or "") .. " " .. tostring(item.Rarity or ""))
		if not string.find(hay, Util.Fold(query), 1, true) then
			return false
		end
	end
	return true
end

function G:_details()
	local panel = self.Details
	if not panel then
		return
	end
	local selected = self:GetSelected()
	local item = selected[1]
	panel.Frame.Visible = item ~= nil and self.ShowDetails
	if item then
		Kit.SetText(panel.Name, item.Name or "")
		Kit.SetText(panel.Text, item.Description or item.Subtitle or "")
		panel.Text.Visible = (item.Description or item.Subtitle) ~= nil
		if item.Rarity then
			panel.Rarity:Set(item.Rarity and rarityText(item.Rarity), nil)
			panel.Rarity:SetColor(Theme.Rarity(item.Rarity))
			panel.Rarity.Frame.Visible = true
		else
			panel.Rarity.Frame.Visible = false
		end
		if #selected > 1 then
			panel.Count.Text = Loc.Resolve("dropdown.selected_count", #selected)
		else
			panel.Count.Text = ""
		end
		Loc.Unbind(panel.Count, "Text")
	end
end

function G:Select(id, silent)
	if self.Mode == "None" then
		return
	end
	if self.Mode == "Multi" then
		self.Selected[id] = (not self.Selected[id]) or nil
	else
		self.Selected = { [id] = true }
	end
	for itemId, tile in pairs(self.Tiles) do
		local on = self.Selected[itemId] == true
		tile.Stroke.Thickness = on and 2 or 1
		Anim.Token(tile.Stroke, "Color", on and "Primary" or "Border", "fast")
		tile.Check.Visible = on
	end
	self:_details()
	if not silent then
		self.Changed:Fire(self:Get())
		if self.OnSelect then
			self.OnSelect(self:Get())
		end
	end
end

function G:Clear()
	self.Selected = {}
	self:Refresh()
end

function G:SetState(state, text)
	self.StateName = state
	self.Loading.Frame.Visible = state == "loading"
	self.Empty.Frame.Visible = state == "empty" or state == "error"
	if state == "error" then
		self.Empty:Set({ Icon = "alert-triangle", Title = "common.error", Message = text or "error.generic" })
	elseif state == "empty" then
		self.Empty:Set({ Icon = self.Query ~= "" and "search-x" or "inbox", Title = self.Query ~= "" and "empty.search_title" or "empty.title", Message = self.Query ~= "" and "empty.search_message" or "empty.message" })
	end
end

function G:Refresh()
	for _, tile in pairs(self.Tiles) do
		tile.Frame:Destroy()
	end
	self.Tiles = {}
	self.More.Frame.Visible = false
	local shown, total = 0, 0
	for _, item in ipairs(self.Items) do
		if matches(self, item) then
			total = total + 1
			if shown < self.Limit then
				shown = shown + 1
				self:_tile(item, shown)
			end
		end
	end
	self.Count.Text = Loc.Resolve("gallery.items_count", total)
	Loc.Unbind(self.Count, "Text")
	self.More.Frame.Visible = total > shown
	if self.StateName ~= "loading" and self.StateName ~= "error" then
		self:SetState(total == 0 and "empty" or "ready")
	end
	self.Grid.Frame.Visible = self.Mode ~= "List" and total > 0
	self.ListFrame.Visible = self.Mode == "List" and total > 0
	self:_details()
end

function G:_tile(item, order)
	local list = self.ViewMode == "List"
	local parent = list and self.ListFrame or self.Grid.Frame
	local tile = {}
	local frame = Create.New("TextButton", { Name = "Tile", Size = list and UDim2.new(1, 0, 0, 52) or UDim2.fromOffset(110, 140), Text = "", LayoutOrder = order, Bind = { BackgroundColor3 = "SurfaceRaised" }, Parent = parent })
	Create.Corner(frame, "md")
	tile.Frame = frame
	tile.Stroke = Create.Stroke(frame, self.Selected[item.Id] and "Primary" or "Border", self.Selected[item.Id] and 2 or 1)
	local mediaSize = list and UDim2.fromOffset(40, 40) or UDim2.new(1, -12, 0, 90)
	local holder = Create.New("Frame", { Name = "Media", Size = mediaSize, Position = UDim2.fromOffset(6, 6), Parent = frame })
	if item.Model then
		tile.Media = Assets.Model(holder, { Model = item.Model, Rarity = item.Rarity, AutoRotate = false })
	else
		tile.Media = Assets.Image(holder, { Source = item.Image, Rarity = item.Rarity, Placeholder = "package" })
	end
	local nameWidth = list and UDim2.new(1, -110, 0, 18) or UDim2.new(1, -12, 0, 16)
	Kit.Text(frame, { Text = item.Name, Size = 12, Weight = "Medium", Position = list and UDim2.fromOffset(54, 8) or UDim2.fromOffset(6, 100), SizeUDim = nameWidth, Align = list and "Left" or "Center" })
	local sub = item.Subtitle or (item.Rarity and rarityText(item.Rarity)) or nil
	if sub then
		local color = Kit.Text(frame, { Text = sub, Size = 11, Color = "TextMuted", Position = list and UDim2.fromOffset(54, 26) or UDim2.fromOffset(6, 118), SizeUDim = nameWidth, Align = list and "Left" or "Center" })
		if item.Rarity then
			color.TextColor3 = Theme.Rarity(item.Rarity)
			Theme.Unbind(color, "TextColor3")
		end
	end
	if item.Amount then
		local badge = Kit.Badge(frame, { Text = "x" .. Util.Format.Compact(item.Amount), Kind = "muted", Height = 18, AnchorPoint = Vector2.new(1, 0), Position = list and UDim2.new(1, -40, 0, 17) or UDim2.new(1, -10, 0, 10), ZIndex = 6 })
		badge.Frame.ZIndex = 6
	end
	tile.Check = Create.New("Frame", { Name = "Check", Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(1, 0), Position = list and UDim2.new(1, -10, 0.5, -9) or UDim2.new(1, -10, 0, 10), Visible = self.Selected[item.Id] == true, ZIndex = 7, Bind = { BackgroundColor3 = "Primary" }, Parent = frame })
	if not list then
		tile.Check.Position = UDim2.new(0, 10, 0, 10)
		tile.Check.AnchorPoint = Vector2.new(0, 0)
	end
	Create.Corner(tile.Check, "pill")
	Kit.Icon(tile.Check, "check", 12, "PrimaryText", { Position = UDim2.fromOffset(3, 3), ZIndex = 8 })
	Kit.Pressable(frame, function(state)
		Anim.Token(frame, "BackgroundColor3", state.Down and "SurfacePressed" or (state.Hover and "SurfaceHover" or "SurfaceRaised"), "fast")
	end)
	frame.Activated:Connect(function()
		self:Select(item.Id)
	end)
	self.Tiles[item.Id] = tile
end

function G:SetItems(items)
	self.Items = {}
	for index, item in ipairs(items or {}) do
		local copy = Util.clone(item)
		copy.Id = copy.Id or ("item" .. index)
		copy.Name = copy.Name or copy.Id
		self.Items[#self.Items + 1] = copy
	end
	local keep = {}
	for _, item in ipairs(self.Items) do
		if self.Selected[item.Id] then
			keep[item.Id] = true
		end
	end
	self.Selected = keep
	self:_buildFilters()
	self:Refresh()
end

function G:SetMode(mode)
	self.ViewMode = mode == "List" and "List" or "Grid"
	self.Mode = self.Mode
	self:Refresh()
end

function G:_buildFilters()
	for _, child in ipairs(self.FilterRow:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local seen, order = {}, {}
	for _, item in ipairs(self.Items) do
		if item.Rarity and not seen[item.Rarity] then
			seen[item.Rarity] = true
			order[#order + 1] = item.Rarity
		end
	end
	local rank = {}
	for index, name in ipairs(Theme.RarityOrder) do
		rank[name] = index
	end
	table.sort(order, function(a, b)
		return (rank[a] or 99) < (rank[b] or 99)
	end)
	self.FilterRow.Visible = #order > 1 and self.Filters
	if #order <= 1 then
		self.Filter = "All"
		return
	end
	table.insert(order, 1, "All")
	for index, name in ipairs(order) do
		local on = self.Filter == name
		local chip = Kit.Button(self.FilterRow, { Text = name == "All" and "common.all" or rarityText(name), Variant = on and "primary" or "secondary", Height = 28, Compact = true, Order = index, Callback = function()
			self.Filter = name
			self:_buildFilters()
			self:Refresh()
		end })
		self.Scope:Add(chip)
	end
end

-- o: Items, Mode ("Single" | "Multi" | "None"), View ("Grid" | "List"), Search, Filters, Details, Height, MinWidth, OnSelect(item|items), Limit
function Gallery.Build(parent, o)
	o = o or {}
	local frame = Kit.Panel(parent, { Name = "AssetGallery", Size = UDim2.new(1, 0, 0, 0), AutoY = true, Order = o.Order, Visible = o.Visible })
	Create.List(frame, { Padding = 0 })
	local top = Create.New("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = frame })
	Create.Pad(top, 10, 10, 10, 6)
	Create.List(top, { Padding = 8 })
	local object = Kit.New(G, frame, {
		Items = {}, Selected = {}, Tiles = {}, Mode = o.Mode or "Single", ViewMode = o.View == "List" and "List" or "Grid", Query = "", Filter = "All",
		Filters = o.Filters ~= false, ShowDetails = o.Details ~= false, Limit = o.Limit or PAGE, OnSelect = Kit.Safe(o.OnSelect), StateName = "ready",
	})
	object.Changed = Signal.new()
	local bar = Create.New("Frame", { Name = "Bar", Size = UDim2.new(1, 0, 0, Kit.Control()), LayoutOrder = 1, Parent = top })
	if o.Search ~= false then
		object.SearchBar = Widgets.SearchBar(bar, { Size = UDim2.new(1, -(Kit.Control() * 2 + 12), 1, 0), OnChanged = function(text)
			object.Query = text
			object:Refresh()
		end })
		object.Scope:Add(object.SearchBar)
	end
	local modeButton = Kit.Button(bar, { Icon = object.ViewMode == "List" and "layout-grid" or "list", Variant = "secondary", Width = Kit.Control(), Position = UDim2.new(1, -(Kit.Control() * 2 + 6), 0, 0), Compact = true, Tooltip = "gallery.view", Callback = function()
		object:SetMode(object.ViewMode == "List" and "Grid" or "List")
		object.ModeButton:SetIcon(object.ViewMode == "List" and "layout-grid" or "list")
	end })
	object.ModeButton = modeButton
	object.Scope:Add(modeButton)
	object.Count = Kit.Text(bar, { Size = 11, Mono = true, Color = "TextMuted", Align = "Right", Position = UDim2.new(1, -Kit.Control(), 0, 0), SizeUDim = UDim2.new(0, Kit.Control(), 1, 0) })
	object.Count.TextTruncate = Enum.TextTruncate.None
	object.Count.Visible = false
	object.FilterRow = Create.New("Frame", { Name = "Filters", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = top })
	Create.List(object.FilterRow, { Dir = "H", Padding = 6, Wrap = true })
	local body = Create.New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, o.Height or 300), LayoutOrder = 2, Parent = frame })
	local scroll = Kit.Scroll(body, { Size = UDim2.fromScale(1, 1) })
	Create.Pad(scroll, 10, 4, 10, 10)
	Create.List(scroll, { Padding = 8 })
	object.Grid = Kit.Grid(scroll, { Min = o.MinWidth or 110, Max = 8, Height = 140, Gap = 8, Order = 1 })
	object.ListFrame = Create.New("Frame", { Name = "List", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Visible = false, Parent = scroll })
	Create.List(object.ListFrame, { Padding = 6 })
	object.More = { Frame = Create.New("Frame", { Name = "More", Size = UDim2.new(1, 0, 0, Kit.Control()), LayoutOrder = 2, Visible = false, Parent = scroll }) }
	local moreButton = Kit.Button(object.More.Frame, { Text = "common.more", Icon = "chevrons-down", Variant = "secondary", Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), Callback = function()
		object.Limit = object.Limit + PAGE
		object:Refresh()
	end })
	object.Scope:Add(moreButton)
	object.Loading = Widgets.LoadingIndicator(body, { Text = "common.loading", Order = 1 })
	object.Loading.Frame.Position = UDim2.fromScale(0.5, 0.5)
	object.Loading.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Loading.Frame.Visible = false
	object.Empty = Widgets.EmptyState(body, { Order = 1 })
	object.Empty.Frame.Position = UDim2.fromScale(0.5, 0.5)
	object.Empty.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Empty.Frame.Visible = false
	if o.Details ~= false then
		local dframe = Create.New("Frame", { Name = "Details", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Visible = false, Parent = frame })
		Create.Pad(dframe, 12, 8, 12, 12)
		Kit.Divider(dframe)
		local inner = Create.New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(0, 10), Parent = dframe })
		Create.List(inner, { Padding = 4 })
		local nameRow = Create.New("Frame", { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = inner })
		Create.List(nameRow, { Dir = "H", Padding = 8, VAlign = "Center" })
		local name = Kit.Text(nameRow, { Size = 14, Weight = "Bold", Auto = "X", Order = 1 })
		name.Size = UDim2.new(0, 0, 1, 0)
		local rarity = Kit.Badge(nameRow, { Text = "", Kind = "muted", Order = 2 })
		local count = Kit.Text(nameRow, { Size = 11, Color = "TextMuted", Auto = "X", Order = 3 })
		count.Size = UDim2.new(0, 0, 1, 0)
		local text = Kit.Text(inner, { Size = 12, Color = "TextMuted", Wrap = true, Auto = "Y", Order = 2 })
		object.Details = { Frame = dframe, Name = name, Text = text, Rarity = rarity, Count = count }
	end
	object:SetItems(o.Items or {})
	return object
end

function Gallery.Blocks.AssetGallery(container, o)
	local holder = Kit.BlockHolder(container, { Name = "AssetGallery" })
	local object = Gallery.Build(holder, o)
	object.Scope:Add(function()
		holder:Destroy()
	end)
	return object
end

-- AssetBrowser ------------------------------------------------------------------------------------------------------------------------
local Browser = Kit.Class()

function Browser:Refresh()
	local source = self.Sources[self.Current]
	if not source then
		self.Gallery:SetItems({})
		return
	end
	if self.Search then
		self.Search.Cancel()
		self.Search = nil
	end
	self.Gallery:SetState("loading")
	local function done(items, reason)
		if self.Destroyed then
			return
		end
		self.Gallery.StateName = "ready"
		if reason then
			self.Gallery:SetItems({})
			self.Gallery:SetState("error", "error.discovery_unavailable")
		else
			self.Gallery:SetItems(items or {})
		end
	end
	if type(source.Provider) == "function" then
		task.spawn(function()
			local ok, items = pcall(source.Provider)
			done(ok and items or {}, (not ok) and "failed" or nil)
		end)
	else
		self.Search = Assets.Discover({ Containers = source.Containers, Classes = source.Classes, Recursive = source.Recursive, Filter = source.Filter, Limit = source.Limit }, done)
	end
end

function Browser:SetSource(id)
	for index, source in ipairs(self.Sources) do
		if source.Id == id then
			self.Current = index
		end
	end
	self:Refresh()
end

function Browser:OnDestroy()
	if self.Search then
		self.Search.Cancel()
	end
end

-- o: Sources = { { Id, Text, Containers = { instances }, Classes, Recursive, Filter, Provider = fn() -> items } }, plus the gallery options
function Gallery.Blocks.AssetBrowser(container, o)
	o = o or {}
	local holder = Kit.BlockHolder(container, { Name = "AssetBrowser" })
	local wrapper = Create.New("Frame", { Name = "Browser", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = holder })
	Create.List(wrapper, { Padding = 8 })
	local object = Kit.New(Browser, holder, { Sources = o.Sources or {}, Current = 1 })
	local head = Create.New("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, Kit.Control() + 20), LayoutOrder = 1, Parent = wrapper })
	local options = {}
	for index, source in ipairs(object.Sources) do
		source.Id = source.Id or ("source" .. index)
		options[index] = { Text = source.Text or source.Id, Value = source.Id }
	end
	local dropdownHolder = Create.New("Frame", { Size = UDim2.new(1, -(Kit.Control() + 8), 1, 0), Parent = head })
	Create.Corner(dropdownHolder, "md")
	local sourceDropdown = Controls.Constructors.Dropdown({ Scope = object.Scope, Content = dropdownHolder, _order = function() return 1 end, _attach = function() end, Page = nil, Window = nil }, { Title = "browser.source", Options = options, Default = options[1] and options[1].Value, Callback = function(id)
		object:SetSource(id)
	end })
	sourceDropdown.Row.Frame.Parent = dropdownHolder
	sourceDropdown.Row.Separator.Visible = false
	object.Scope:Add(sourceDropdown)
	local refresh = Kit.Button(head, { Icon = "refresh-cw", Variant = "secondary", Width = Kit.Control(), Position = UDim2.new(1, -Kit.Control(), 0.5, -Kit.Control() / 2), Tooltip = "browser.refresh", Callback = function()
		object:Refresh()
	end })
	object.Scope:Add(refresh)
	local galleryHolder = Create.New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = wrapper })
	object.Gallery = Gallery.Build(galleryHolder, o)
	object.Scope:Add(object.Gallery)
	object:Refresh()
	return object
end

return Gallery
end

Modules["UI/HUD"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Root = import("UI/Root")
local Drag = import("UI/Drag")
local Persistence = import("Storage/Persistence")
local Services = import("Core/Services")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

--[[
	Mini HUD: a small draggable overlay with live metrics (built-in FPS / Ping / Time and any metric your script
	supplies). Layout presets (Horizontal, Vertical, Grid, Compact), compact mode, scale, colors and opacity are
	adjustable and saved to DeaUI-S/HUD/Settings.json. Values change smoothly; nothing here touches the game.
]]
local HUD = {}
local Class = Kit.Class()

local DEFAULTS = {
	Visible = true,
	Layout = "Horizontal",
	Compact = false,
	Scale = 1,
	Opacity = 0.92,
	Position = {},
	Colors = {},
	Builtin = { FPS = true, Ping = true, Time = false },
}

local BUILTIN = {
	FPS = { Icon = "activity", Label = "hud.fps", Kind = "success" },
	Ping = { Icon = "wifi", Label = "hud.ping", Kind = "info" },
	Time = { Icon = "clock", Label = "hud.time", Kind = "muted" },
}
local BUILTIN_ORDER = { "FPS", "Ping", "Time" }

function Class:_doc()
	return self.Doc
end

function Class:_save()
	self.Doc:Save()
end

function Class:_layoutAll()
	local layout = self.Layout
	local list = self.List
	local compact = self.Compact or layout == "Compact"
	if layout == "Vertical" then
		list.FillDirection = Enum.FillDirection.Vertical
		list.Padding = UDim.new(0, 6)
	else
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, compact and 10 or 14)
	end
	list.Wraps = layout == "Grid"
	self.Holder.Size = layout == "Grid" and UDim2.fromOffset(compact and 190 or 250, 0) or UDim2.fromOffset(0, 0)
	self.Holder.AutomaticSize = layout == "Grid" and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY
	for _, metric in ipairs(self.Order) do
		metric.Label.Visible = not compact and metric.Label.Text ~= ""
		if layout == "Grid" then
			metric.Cell.Size = UDim2.fromOffset(compact and 90 or 120, 22)
			metric.Cell.AutomaticSize = Enum.AutomaticSize.None
		else
			metric.Cell.Size = UDim2.fromOffset(0, 22)
			metric.Cell.AutomaticSize = Enum.AutomaticSize.X
		end
	end
end

function Class:_style()
	local colors = self.Colors
	local function color(key)
		local value = colors[key]
		if typeof(value) == "string" then
			return Util.FromHex(value)
		end
		return value
	end
	local back = color("Background")
	if back then
		Theme.Unbind(self.Panel, "BackgroundColor3")
		self.Panel.BackgroundColor3 = back
	else
		Theme.Bind(self.Panel, "BackgroundColor3", "Surface")
	end
	self.Panel.BackgroundTransparency = 1 - Util.clamp(self.Opacity, 0.2, 1)
	for _, metric in ipairs(self.Order) do
		local text, accent = color("Text"), color("Accent")
		if text then
			Theme.Unbind(metric.Value, "TextColor3")
			metric.Value.TextColor3 = text
		else
			Theme.Bind(metric.Value, "TextColor3", "Text")
		end
		if accent then
			Theme.Unbind(metric.Icon, "ImageColor3")
			metric.Icon.ImageColor3 = accent
		else
			Theme.Bind(metric.Icon, "ImageColor3", metric.Token)
		end
	end
end

function Class:AddMetric(spec)
	local id = spec.Id
	if not id then
		return nil
	end
	if self.Metrics[id] then
		self:SetMetric(id, spec)
		return self.Metrics[id]
	end
	local fg = Kit.KindTokens(spec.Kind or "accent")
	local cell = Create.New("Frame", { Name = "Metric." .. id, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = #self.Order + 1, Parent = self.Holder })
	Create.List(cell, { Dir = "H", Padding = 5, VAlign = "Center" })
	local icon = Kit.Icon(cell, spec.Icon, 14, fg, { Order = 1 })
	local label = Kit.Text(cell, { Text = spec.Label, Size = 11, Color = "TextMuted", Auto = "X", Order = 2 })
	label.Size = UDim2.new(0, 0, 1, 0)
	local value = Kit.Text(cell, { Size = 12, Weight = "Bold", Mono = true, Auto = "X", Order = 3 })
	value.Size = UDim2.new(0, 0, 1, 0)
	local metric = { Id = id, Cell = cell, Icon = icon, Label = label, Value = value, Token = fg, Format = spec.Format, Raw = nil, Numeric = nil }
	metric.Counter = Anim.Number(0, function(v)
		value.Text = (spec.Prefix or "") .. Util.Format.Apply(metric.Format, v) .. (spec.Suffix or "")
		Loc.Unbind(value, "Text")
	end, { Epsilon = 0.5, Rate = 12 })
	icon.Visible = spec.Icon ~= nil
	self.Metrics[id] = metric
	table.insert(self.Order, metric)
	if spec.Value ~= nil then
		self:SetMetric(id, spec.Value, true)
	end
	self:_layoutAll()
	self:_style()
	return metric
end

-- SetMetric(id, value | { Value, Label, Icon, Kind, Format })
function Class:SetMetric(id, value, instant)
	local metric = self.Metrics[id]
	if not metric then
		return false
	end
	local patch = value
	if type(value) ~= "table" or (value.Value == nil and value.Label == nil and value.Icon == nil and value.Kind == nil and value.Format == nil) or Loc.Known(value) then
		patch = { Value = value }
	end
	if patch.Label ~= nil then
		Kit.SetText(metric.Label, patch.Label)
	end
	if patch.Icon ~= nil then
		Kit.SetIcon(metric.Icon, patch.Icon)
	end
	if patch.Kind ~= nil then
		metric.Token = Kit.KindTokens(patch.Kind)
		Theme.Bind(metric.Icon, "ImageColor3", metric.Token)
	end
	if patch.Format ~= nil then
		metric.Format = patch.Format
	end
	if patch.Value ~= nil then
		if type(patch.Value) == "number" then
			metric.Counter:Set(patch.Value, instant)
		else
			metric.Counter:Destroy()
			Kit.SetText(metric.Value, patch.Value)
		end
	end
	return true
end

function Class:GetMetric(id)
	local metric = self.Metrics[id]
	return metric and metric.Counter:Get() or nil
end

function Class:RemoveMetric(id)
	local metric = self.Metrics[id]
	if not metric then
		return
	end
	self.Metrics[id] = nil
	for index, other in ipairs(self.Order) do
		if other == metric then
			table.remove(self.Order, index)
		end
	end
	metric.Counter:Destroy()
	metric.Cell:Destroy()
end

function Class:SetBuiltin(name, enabled)
	if not BUILTIN[name] then
		return
	end
	enabled = enabled == true
	self.Doc.Data.Builtin[name] = enabled
	if enabled and not self.Metrics[name] then
		local spec = Util.clone(BUILTIN[name])
		spec.Id = name
		spec.Value = name == "Time" and os.date("%H:%M") or 0
		self:AddMetric(spec)
		self:_reorder()
		if name == "Time" then
			self.Metrics.Time.Counter:Destroy()
		end
	elseif not enabled and self.Metrics[name] then
		self:RemoveMetric(name)
	end
	self:_save()
end

function Class:_reorder()
	local rank = {}
	for index, name in ipairs(BUILTIN_ORDER) do
		rank[name] = index
	end
	table.sort(self.Order, function(a, b)
		local ra, rb = rank[a.Id] or 100, rank[b.Id] or 100
		if ra ~= rb then
			return ra < rb
		end
		return a.Cell.LayoutOrder < b.Cell.LayoutOrder
	end)
	for index, metric in ipairs(self.Order) do
		metric.Cell.LayoutOrder = index
	end
end

function Class:SetLayout(name)
	if name ~= "Horizontal" and name ~= "Vertical" and name ~= "Grid" and name ~= "Compact" then
		return
	end
	self.Layout = name
	self.Doc.Data.Layout = name
	self:_layoutAll()
	self:_save()
end

function Class:SetCompact(compact)
	self.Compact = compact == true
	self.Doc.Data.Compact = self.Compact
	self:_layoutAll()
	self:_save()
end

function Class:SetScale(scale)
	self.Scale = Util.clamp(tonumber(scale) or 1, 0.6, 1.8)
	self.ScaleObject.Scale = self.Scale
	self.Doc.Data.Scale = self.Scale
	self:_save()
end

function Class:SetOpacity(opacity)
	self.Opacity = Util.clamp(tonumber(opacity) or 1, 0.2, 1)
	self.Doc.Data.Opacity = self.Opacity
	self:_style()
	self:_save()
end

-- SetColors({ Background = Color3|"#hex", Text = ..., Accent = ... }); pass nil to a key (or Reset()) to return to the theme.
function Class:SetColors(map)
	for key, value in pairs(map or {}) do
		if typeof(value) == "Color3" then
			value = Util.Hex(value)
		end
		self.Colors[key] = value
	end
	self.Doc.Data.Colors = Util.clone(self.Colors)
	self:_style()
	self:_save()
end

function Class:ResetColors()
	self.Colors = {}
	self.Doc.Data.Colors = {}
	self:_style()
	self:_save()
end

function Class:SetVisible(visible)
	self.Visible = visible ~= false
	self.Frame.Visible = self.Visible
	self.Doc.Data.Visible = self.Visible
	self:_save()
end

function Class:Toggle()
	self:SetVisible(not self.Visible)
end

function Class:IsVisible()
	return self.Visible
end

function Class:SetPosition(x, y)
	local position = Drag.Fit(Vector2.new(x, y), Vector2.new(self.Frame.AbsoluteSize.X, self.Frame.AbsoluteSize.Y) / Root.Scale, 4)
	self.Frame.Position = UDim2.fromOffset(position.X, position.Y)
	self.Doc.Data.Position = { X = position.X, Y = position.Y }
	self:_save()
end

function Class:Serialize()
	return Util.deepClone(self.Doc.Data)
end

function Class:OnDestroy()
	for _, metric in ipairs(self.Order) do
		metric.Counter:Destroy()
	end
	if self.FrameLink then
		self.FrameLink:Disconnect()
	end
end

local instance

-- options: Metrics = { { Id, Icon, Label, Value, Kind, Format, Prefix, Suffix } }, Visible, Layout, Compact, Scale, Opacity, Position = Vector2, Builtin = { FPS, Ping, Time }
function HUD.Get(options)
	if instance and not instance.Destroyed then
		for _, spec in ipairs((options or {}).Metrics or {}) do
			instance:AddMetric(spec)
		end
		return instance
	end
	options = options or {}
	local doc = Persistence.Document(Persistence.Files.HUD, DEFAULTS)
	local data = doc.Data
	if type(data.Builtin) ~= "table" then
		data.Builtin = Util.deepClone(DEFAULTS.Builtin)
	end
	if options.Builtin then
		for key, value in pairs(options.Builtin) do
			data.Builtin[key] = value == true
		end
	end
	local holderFrame = Create.New("Frame", { Name = "HUD", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, Visible = data.Visible ~= false, ZIndex = 3, Parent = Root.HUDLayer })
	local scaleObject = Instance.new("UIScale")
	scaleObject.Parent = holderFrame
	local panel = Create.New("Frame", { Name = "Panel", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, Bind = { BackgroundColor3 = "Surface" }, Parent = holderFrame })
	Create.Corner(panel, "md")
	Create.Stroke(panel, "Border")
	Create.Pad(panel, 12, 8, 12, 8)
	local holder = Create.New("Frame", { Name = "Metrics", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, Parent = panel })
	local list = Create.List(holder, { Dir = "H", Padding = 14, VAlign = "Center" })
	local object = Kit.New(Class, holderFrame, {
		Doc = doc, Panel = panel, Holder = holder, List = list, ScaleObject = scaleObject, Metrics = {}, Order = {},
		Layout = options.Layout or data.Layout, Compact = options.Compact == nil and data.Compact or options.Compact, Scale = options.Scale or data.Scale,
		Opacity = options.Opacity or data.Opacity, Colors = Util.clone(type(data.Colors) == "table" and data.Colors or {}),
	})
	object.Visible = data.Visible ~= false
	if options.Visible ~= nil then
		object.Visible = options.Visible
		holderFrame.Visible = options.Visible
	end
	scaleObject.Scale = Util.clamp(object.Scale, 0.6, 1.8)
	object.Scale = scaleObject.Scale
	for _, name in ipairs(BUILTIN_ORDER) do
		if data.Builtin[name] then
			local spec = Util.clone(BUILTIN[name])
			spec.Id = name
			spec.Value = name == "Time" and os.date("%H:%M") or 0
			object:AddMetric(spec)
		end
	end
	for _, spec in ipairs(options.Metrics or {}) do
		object:AddMetric(spec)
	end
	object:_reorder()
	object:_layoutAll()
	object:_style()

	-- position
	local insets = Root.Insets()
	local saved = data.Position
	local start = options.Position
	if not start and type(saved) == "table" and type(saved.X) == "number" and type(saved.Y) == "number" then
		start = Vector2.new(saved.X, saved.Y)
	end
	start = start or Vector2.new(insets.Left + 12, insets.Top + 10)
	holderFrame.Position = UDim2.fromOffset(start.X, start.Y)
	object.Scope:Add(Drag.Bind(panel, holderFrame, {
		OnEnd = function(position)
			doc.Data.Position = { X = position.X, Y = position.Y }
			doc:Save()
		end,
		Rest = function(position, size)
			return Drag.Fit(position, size, 4)
		end,
	}))
	-- keep it inside the screen when the viewport changes
	object.Scope:Connect(Root.Changed, function()
		local size = Vector2.new(holderFrame.AbsoluteSize.X, holderFrame.AbsoluteSize.Y) / Root.Scale
		local fitted = Drag.Fit(Vector2.new(holderFrame.Position.X.Offset, holderFrame.Position.Y.Offset), size, 4)
		holderFrame.Position = UDim2.fromOffset(fitted.X, fitted.Y)
	end)

	-- live built-ins: FPS (frames counted per second), Ping, clock
	local frames = 0
	object.Scope:Connect(Services.RunService.Heartbeat, function()
		frames = frames + 1
	end)
	object.Scope:Add(Kit.Tick(function()
		if object.Metrics.FPS then
			object:SetMetric("FPS", { Value = frames })
		end
		frames = 0
		if object.Metrics.Ping then
			local ok, ping = pcall(function()
				return Services.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			if ok and type(ping) == "number" then
				object:SetMetric("Ping", { Value = math.floor(ping + 0.5), Format = function(v)
					return string.format("%dms", v)
				end })
			end
		end
		local clock = object.Metrics.Time
		if clock then
			clock.Value.Text = os.date("%H:%M")
			Loc.Unbind(clock.Value, "Text")
		end
	end))
	instance = object
	object.Scope:Add(function()
		if instance == object then
			instance = nil
		end
	end)
	return object
end

function HUD.Exists()
	return instance ~= nil and not instance.Destroyed
end

function HUD.Destroy()
	if instance then
		instance:Destroy()
		instance = nil
	end
end

-- Config provider snapshot / restore (used by AutoLoad)
function HUD.Snapshot()
	if instance and not instance.Destroyed then
		return instance:Serialize()
	end
	local doc = Persistence.Document(Persistence.Files.HUD, DEFAULTS)
	return Util.deepClone(doc.Data)
end

function HUD.Restore(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	local doc = Persistence.Document(Persistence.Files.HUD, DEFAULTS)
	for key, value in pairs(snapshot) do
		if DEFAULTS[key] ~= nil and typeof(DEFAULTS[key]) == typeof(value) then
			doc.Data[key] = value
		end
	end
	doc:Save()
	if instance and not instance.Destroyed then
		local data = doc.Data
		instance.Layout, instance.Compact, instance.Opacity = data.Layout, data.Compact, data.Opacity
		instance.Colors = Util.clone(data.Colors)
		instance:SetScale(data.Scale)
		instance:SetVisible(data.Visible)
		for _, name in ipairs(BUILTIN_ORDER) do
			instance:SetBuiltin(name, data.Builtin and data.Builtin[name] == true)
		end
		instance:_layoutAll()
		instance:_style()
	end
end

return HUD
end

Modules["UI/Keybinds"] = function(import)
local Services = import("Core/Services")
local Input = import("Core/Input")

-- Keyboard shortcuts: registered binds (Press / Toggle / Hold) and "press a key" capture.
local Keys = { Binds = {}, Capturing = false }

local SHORT = {
	LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt", RightAlt = "RAlt",
	Backquote = "`", Return = "Enter", Escape = "Esc", Delete = "Del", Insert = "Ins", PageUp = "PgUp", PageDown = "PgDn",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
}

function Keys.Name(key)
	if typeof(key) ~= "EnumItem" then
		return nil
	end
	return SHORT[key.Name] or key.Name
end

-- bind: { Key = KeyCode|nil, OnPress = fn, OnRelease = fn, Allowed = fn() -> bool }
function Keys.Register(bind)
	table.insert(Keys.Binds, bind)
	function bind:Remove()
		for index, other in ipairs(Keys.Binds) do
			if other == self then
				table.remove(Keys.Binds, index)
				return
			end
		end
	end
	return bind
end

function Keys.Start(scope)
	scope:Connect(Services.UserInputService.InputBegan, function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard or Keys.Capturing or Input.Typing() then
			return
		end
		for _, bind in ipairs({ table.unpack(Keys.Binds) }) do
			if bind.Key == input.KeyCode and bind.OnPress and (not bind.Allowed or bind.Allowed()) then
				task.spawn(bind.OnPress, input)
			end
		end
	end)
	scope:Connect(Services.UserInputService.InputEnded, function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		for _, bind in ipairs({ table.unpack(Keys.Binds) }) do
			if bind.Key == input.KeyCode and bind.OnRelease then
				task.spawn(bind.OnRelease, input)
			end
		end
	end)
end

-- Waits for the next key. onKey(KeyCode|nil) (nil = cleared with Backspace/Delete); onCancel() on Escape.
function Keys.Capture(onKey, onCancel)
	Keys.Capturing = true
	local link
	local function finish()
		Keys.Capturing = false
		if link then
			link:Disconnect()
			link = nil
		end
	end
	link = Services.UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		finish()
		if input.KeyCode == Enum.KeyCode.Escape then
			if onCancel then
				onCancel()
			end
		elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
			onKey(nil)
		else
			onKey(input.KeyCode)
		end
	end)
	return finish
end

function Keys.Clear()
	Keys.Binds = {}
	Keys.Capturing = false
end

return Keys
end

Modules["UI/Kit"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Icons = import("Theme/Icons")
local Anim = import("Animation")
local Loc = import("Localization")
local Input = import("Core/Input")
local Services = import("Core/Services")
local Scope = import("Core/Scope")
local Util = import("Core/Util")
local Tooltip = import("UI/Tooltip")
local Root = import("UI/Root")

-- Shared building blocks: text, icons, buttons, fields, badges, scroll areas and the component base class.
local Kit = {}

function Kit.Touch()
	return Input.Touch()
end

-- Control height: comfortable touch targets on phones and tablets, tighter on PC.
function Kit.Control()
	return Input.Touch() and 40 or 32
end

function Kit.Size(px)
	return px + (Input.Touch() and 1 or 0)
end

-- Wraps a developer callback so an error never breaks the UI.
function Kit.Safe(callback)
	if type(callback) ~= "function" then
		return nil
	end
	return function(...)
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[DeaUI-S] callback error: " .. tostring(err))
		end
	end
end

-- Text ---------------------------------------------------------------------------------------
-- p: Text (source), Size, Weight ("Regular"|"Medium"|"Bold"), Color (token), Align, VAlign, Wrap, Auto ("X"|"Y"|"XY"),
--    Mono, Rich, Position, AnchorPoint, Order, ZIndex, SizeUDim, Transform(fn(text) -> text)
function Kit.Text(parent, p)
	p = p or {}
	local size = Kit.Size(p.Size or 13)
	local auto = p.Auto
	local label = Create.New("TextLabel", {
		Name = p.Name or "Text",
		Size = p.SizeUDim or (auto == "Y" and UDim2.new(1, 0, 0, 0)) or (auto == "X" and UDim2.new(0, 0, 0, size + 4)) or (auto == "XY" and UDim2.fromOffset(0, 0)) or UDim2.new(1, 0, 0, size + 4),
		AutomaticSize = auto and Enum.AutomaticSize[auto] or Enum.AutomaticSize.None,
		FontFace = Theme.FontFor(p.Weight, p.Mono),
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment[p.Align or "Left"],
		TextYAlignment = Enum.TextYAlignment[p.VAlign or (p.Wrap and "Top" or "Center")],
		TextWrapped = p.Wrap == true,
		TextTruncate = p.Wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
		RichText = p.Rich == true,
		LayoutOrder = p.Order or 0,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		ZIndex = p.ZIndex,
		Visible = p.Visible,
		Bind = { TextColor3 = p.Color or "Text" },
		Parent = parent,
	})
	if p.Text ~= nil then
		Loc.Bind(label, "Text", p.Text, p.Transform)
	end
	return label
end

function Kit.SetText(label, source, transform)
	Loc.Bind(label, "Text", source, transform)
end

function Kit.Icon(parent, name, px, token, extra)
	extra = extra or {}
	local image = Create.New("ImageLabel", {
		Name = extra.Name or "Icon",
		Size = UDim2.fromOffset(px or 16, px or 16),
		ScaleType = Enum.ScaleType.Fit,
		Position = extra.Position,
		AnchorPoint = extra.AnchorPoint,
		LayoutOrder = extra.Order or 0,
		ZIndex = extra.ZIndex,
		Bind = { ImageColor3 = token or "TextMuted" },
		Parent = parent,
	})
	Icons.Apply(image, name)
	image.Visible = name ~= nil and name ~= ""
	return image
end

function Kit.SetIcon(image, name)
	Icons.Apply(image, name)
	image.Visible = name ~= nil and name ~= ""
end

-- Surfaces -----------------------------------------------------------------------------------
-- p: Token ("Surface"), Radius ("md"), Stroke (token | true | false), Size, Position, Name, Order, AutoY, ZIndex
function Kit.Panel(parent, p)
	p = p or {}
	local frame = Create.New("Frame", {
		Name = p.Name or "Panel",
		Size = p.Size or UDim2.new(1, 0, 0, 40),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Order or 0,
		ZIndex = p.ZIndex,
		AutomaticSize = p.AutoY and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		ClipsDescendants = p.Clip == true,
		Visible = p.Visible,
		Bind = { BackgroundColor3 = p.Token or "Surface" },
		Parent = parent,
	})
	if p.Radius ~= false then
		Create.Corner(frame, p.Radius or "md")
	end
	if p.Stroke ~= false then
		Create.Stroke(frame, type(p.Stroke) == "string" and p.Stroke or "Border")
	end
	return frame
end

function Kit.Divider(parent, p)
	p = p or {}
	return Create.New("Frame", {
		Name = "Divider",
		Size = p.Vertical and UDim2.new(0, 1, 1, 0) or UDim2.new(1, 0, 0, 1),
		LayoutOrder = p.Order or 0,
		Position = p.Position,
		BackgroundTransparency = p.Transparency or 0,
		Bind = { BackgroundColor3 = p.Token or "Border" },
		Parent = parent,
	})
end

-- Interaction ---------------------------------------------------------------------------------
-- Tracks hover/pressed state of `gui` and calls onState(state). Touch devices skip hover.
function Kit.Pressable(gui, onState)
	local state = { Hover = false, Down = false }
	if not Input.Touch() then
		gui.MouseEnter:Connect(function()
			state.Hover = true
			onState(state)
		end)
		gui.MouseLeave:Connect(function()
			state.Hover, state.Down = false, false
			onState(state)
		end)
	end
	gui.InputBegan:Connect(function(input)
		if Input.IsPrimary(input) then
			state.Down = true
			onState(state)
		end
	end)
	gui.InputEnded:Connect(function(input)
		if Input.IsPrimary(input) then
			state.Down = false
			onState(state)
		end
	end)
	return state
end

-- Component base class ---------------------------------------------------------------------------
local Base = {}
Base.__index = Base
Kit.Base = Base

function Base:SetVisible(visible)
	self.Visible = visible ~= false
	self.Frame.Visible = self.Visible
end

function Base:IsVisible()
	return self.Visible
end

function Base:SetEnabled(enabled)
	enabled = enabled ~= false
	self.Enabled = enabled
	if self.Mask == nil and not enabled and not self.NoMask then
		local host = self.Frame
		self.Mask = Create.New("TextButton", {
			Name = "DisabledMask",
			Size = UDim2.fromScale(1, 1),
			Text = "",
			Active = true,
			BackgroundTransparency = 0.45,
			ZIndex = 20,
			Visible = false,
			Bind = { BackgroundColor3 = "Surface" },
			Parent = host,
		})
		Create.Corner(self.Mask, "sm")
	end
	if self.Mask then
		self.Mask.Visible = not enabled
	end
	if self.OnEnabled then
		self:OnEnabled(enabled)
	end
end

function Base:IsEnabled()
	return self.Enabled
end

function Base:GetFrame()
	return self.Frame
end

function Base:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	if self.OnDestroy then
		pcall(self.OnDestroy, self)
	end
	self.Scope:Clean()
	if self.Changed and self.Changed.Clear then
		self.Changed:Clear()
	end
	if self.ParentScope then
		self.ParentScope:Remove(self)
		self.ParentScope = nil
	end
	if self.Frame then
		self.Frame:Destroy()
	end
end

-- Makes `child` part of `parent`: destroying the parent (window, page, group...) destroys the child
-- component too, so its connections and timers are released.
function Kit.Adopt(parent, child)
	if parent and parent.Scope and child and child.Scope then
		parent.Scope:Add(child)
		child.ParentScope = parent.Scope
	end
	return child
end

-- Kit.Class() -> class table inheriting Base; Kit.New(class, frame, fields) -> instance
function Kit.Class()
	local class = setmetatable({}, { __index = Base })
	class.__index = class
	return class
end

function Kit.New(class, frame, fields)
	local object = setmetatable(fields or {}, class)
	object.Frame = frame
	object.Scope = Scope.new()
	object.Enabled = true
	object.Visible = true
	return object
end

-- Buttons --------------------------------------------------------------------------------------
local VARIANTS = {
	primary = { bg = "Primary", hover = "PrimaryHover", down = "PrimaryPressed", text = "PrimaryText" },
	secondary = { bg = "SurfaceRaised", hover = "SurfaceHover", down = "SurfacePressed", text = "Text", stroke = "Border" },
	default = { bg = "SurfaceRaised", hover = "SurfaceHover", down = "SurfacePressed", text = "Text", stroke = "Border" },
	ghost = { bg = "Surface", hover = "SurfaceHover", down = "SurfacePressed", text = "TextMuted", hoverText = "Text" },
	soft = { bg = "PrimarySoft", hover = "PrimarySoftHover", down = "PrimarySoftHover", text = "Primary" },
	danger = { bg = "Danger", hover = "DangerHover", down = "DangerPressed", text = "DangerText" },
}
local Button = Kit.Class()
Kit.ButtonClass = Button

-- p: Text, Icon, Variant, Height, Width, MinWidth, Callback, Tooltip, Base (ghost background token), IconRight
function Kit.Button(parent, p)
	p = p or {}
	local height = p.Height or Kit.Control()
	local frame = Create.New("TextButton", {
		Name = p.Name or "Button",
		Size = UDim2.new(0, p.Width or 0, 0, height),
		AutomaticSize = p.Width and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Text = "",
		LayoutOrder = p.Order or 0,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		ZIndex = p.ZIndex,
		Bind = { BackgroundColor3 = "SurfaceRaised" },
		Parent = parent,
	})
	Create.Corner(frame, p.Radius or "sm")
	local stroke = Create.Stroke(frame, "Border")
	Create.Pad(frame, p.Compact and 8 or 12, 0, p.Compact and 8 or 12, 0)
	Create.List(frame, { Dir = "H", Padding = 6, HAlign = "Center", VAlign = "Center" })
	if p.MinWidth then
		local limit = Instance.new("UISizeConstraint")
		limit.MinSize = Vector2.new(p.MinWidth, 0)
		limit.Parent = frame
	end
	local icon = Kit.Icon(frame, p.Icon, p.IconSize or 16, "Text", { Order = p.IconRight and 2 or 0 })
	local label = Kit.Text(frame, { Text = p.Text, Size = 13, Weight = "Medium", Auto = "X", Align = "Center", Color = "Text", Order = 1 })
	label.Visible = p.Text ~= nil and p.Text ~= ""
	local button = Kit.New(Button, frame, { Label = label, IconImage = icon, Stroke = stroke, Variant = string.lower(p.Variant or "secondary"), Base = p.Base })
	button.Host = frame
	button.NoMask = true
	local state = { Hover = false, Down = false }
	function button:Refresh()
		local v = VARIANTS[self.Variant] or VARIANTS.secondary
		local bg, text, line = v.bg, v.text, v.stroke
		if self.Variant == "ghost" and self.Base then
			bg = self.Base
		end
		if not self.Enabled then
			text = "Disabled"
			bg = (self.Variant == "primary" or self.Variant == "danger") and "SurfaceRaised" or bg
		elseif state.Down then
			bg = v.down
		elseif state.Hover then
			bg = v.hover
			text = v.hoverText or text
		end
		Anim.Token(frame, "BackgroundColor3", bg, "fast")
		Anim.Token(label, "TextColor3", text, "fast")
		Anim.Token(icon, "ImageColor3", text, "fast")
		stroke.Enabled = line ~= nil
		if line then
			Theme.Bind(stroke, "Color", line)
		end
	end
	function button:OnEnabled(enabled)
		frame.Active = enabled
		self:Refresh()
	end
	function button:SetText(source)
		Kit.SetText(label, source)
		label.Visible = source ~= nil and source ~= ""
	end
	function button:SetIcon(name)
		Kit.SetIcon(icon, name)
	end
	function button:SetVariant(name)
		self.Variant = string.lower(name or "secondary")
		self:Refresh()
	end
	function button:SetCallback(callback)
		self.Callback = Kit.Safe(callback)
	end
	function button:Click()
		if self.Enabled and self.Callback then
			self.Callback(self)
		end
	end
	button.Callback = Kit.Safe(p.Callback)
	local live = Kit.Pressable(frame, function(s)
		state.Hover, state.Down = s.Hover, s.Down
		if button.Enabled then
			button:Refresh()
		end
	end)
	frame.Activated:Connect(function()
		button:Click()
	end)
	button.Tooltip = Tooltip.Attach(frame, p.Tooltip)
	button.Scope:Add(button.Tooltip)
	button:Refresh()
	frame.BackgroundColor3 = Theme.Resolve((VARIANTS[button.Variant] or VARIANTS.secondary).bg)
	return button
end

-- Scrolling ------------------------------------------------------------------------------------
function Kit.Scroll(parent, p)
	p = p or {}
	return Create.New("ScrollingFrame", {
		Name = p.Name or "Scroll",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = p.Horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
		ScrollingDirection = p.Horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
		ScrollBarThickness = Input.Touch() and 4 or 3,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ScrollBarImageTransparency = 0.2,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		Active = true,
		ClipsDescendants = true,
		ZIndex = p.ZIndex,
		LayoutOrder = p.Order or 0,
		Bind = { ScrollBarImageColor3 = "BorderStrong" },
		Parent = parent,
	})
end

-- Text field -------------------------------------------------------------------------------------
-- p: Text, Placeholder (source), Icon, Height, SizeUDim, Numeric, Align, Mono, OnSubmit(text, enter), OnChanged(text), Clear (show clear button)
function Kit.Field(parent, p)
	p = p or {}
	local height = p.Height or Kit.Control()
	local frame = Create.New("Frame", {
		Name = p.Name or "Field",
		Size = p.SizeUDim or UDim2.new(1, 0, 0, height),
		LayoutOrder = p.Order or 0,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		ZIndex = p.ZIndex,
		Bind = { BackgroundColor3 = "SurfaceRaised" },
		Parent = parent,
	})
	Create.Corner(frame, "sm")
	local stroke = Create.Stroke(frame, "Border")
	local left = 10
	local icon
	if p.Icon then
		icon = Kit.Icon(frame, p.Icon, 14, "TextFaint", { Position = UDim2.new(0, 10, 0.5, -7) })
		left = 30
	end
	local right = p.Clear and 28 or 10
	local box = Create.New("TextBox", {
		Name = "Box",
		Size = UDim2.new(1, -(left + right), 1, 0),
		Position = UDim2.fromOffset(left, 0),
		Text = p.Text or "",
		ClearTextOnFocus = false,
		TextSize = Kit.Size(13),
		TextXAlignment = Enum.TextXAlignment[p.Align or "Left"],
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = p.Mono and Theme.Mono or Theme.Font,
		PlaceholderText = "",
		Bind = { PlaceholderColor3 = "TextFaint" },
		Parent = frame,
	})
	if p.Placeholder ~= nil then
		Loc.Bind(box, "PlaceholderText", p.Placeholder)
	end
	local clear
	if p.Clear then
		clear = Create.New("TextButton", { Name = "Clear", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -25, 0.5, -11), Text = "", Visible = false, Parent = frame })
		Kit.Icon(clear, "x", 12, "TextMuted", { Position = UDim2.new(0.5, -6, 0.5, -6) })
		clear.Activated:Connect(function()
			box.Text = ""
			box:CaptureFocus()
		end)
		local function sync()
			clear.Visible = box.Text ~= ""
		end
		box:GetPropertyChangedSignal("Text"):Connect(sync)
		sync()
	end
	box.Focused:Connect(function()
		Anim.Token(stroke, "Color", "Primary", "fast")
	end)
	box.FocusLost:Connect(function(enter)
		Anim.Token(stroke, "Color", "Border", "fast")
		if p.OnSubmit then
			p.OnSubmit(box.Text, enter)
		end
	end)
	if p.OnChanged then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			p.OnChanged(box.Text)
		end)
	end
	return { Frame = frame, Box = box, Stroke = stroke, Icon = icon, Clear = clear }
end

-- Badge / status pill ----------------------------------------------------------------------------
local KINDS = {
	accent = { "Accent", "AccentSoft" },
	primary = { "Primary", "PrimarySoft" },
	success = { "Success", "SuccessSoft" },
	warn = { "Warning", "WarningSoft" },
	warning = { "Warning", "WarningSoft" },
	error = { "Danger", "DangerSoft" },
	danger = { "Danger", "DangerSoft" },
	info = { "Info", "InfoSoft" },
	muted = { "TextMuted", "SurfaceRaised" },
}

-- Kind name or rarity -> (foreground token, soft background token)
function Kit.KindTokens(kind)
	local entry = KINDS[string.lower(tostring(kind or "muted"))]
	if entry then
		return entry[1], entry[2]
	end
	return "TextMuted", "SurfaceRaised"
end

-- p: Text, Kind, Icon, Height, Color (Color3 override), Order
function Kit.Badge(parent, p)
	p = p or {}
	local fg, bg = Kit.KindTokens(p.Kind)
	local frame = Create.New("Frame", {
		Name = p.Name or "Badge",
		Size = UDim2.fromOffset(0, p.Height or 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = p.Order or 0,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		ZIndex = p.ZIndex,
		Bind = { BackgroundColor3 = bg },
		Parent = parent,
	})
	Create.Corner(frame, "pill")
	Create.Pad(frame, 8, 0, 8, 0)
	Create.List(frame, { Dir = "H", Padding = 4, VAlign = "Center" })
	local icon = Kit.Icon(frame, p.Icon, 12, fg, { Order = 0 })
	local label = Kit.Text(frame, { Text = p.Text, Size = 11, Weight = "Medium", Auto = "X", Color = fg, Order = 1 })
	label.Size = UDim2.new(0, 0, 1, 0)
	local badge = { Frame = frame, Label = label, Icon = icon }
	function badge:SetColor(color)
		Theme.Unbind(frame, "BackgroundColor3")
		Theme.Unbind(label, "TextColor3")
		Theme.Unbind(icon, "ImageColor3")
		Theme.OnChange(frame, function(tokens)
			frame.BackgroundColor3 = Theme.Mix(tokens.Surface, color, tokens.Light and 0.16 or 0.22)
			label.TextColor3 = color
			icon.ImageColor3 = color
		end)
	end
	if p.Color then
		badge:SetColor(p.Color)
	end
	function badge:Set(source, kind, iconName)
		if source ~= nil then
			Kit.SetText(label, source)
		end
		if kind then
			local f, b = Kit.KindTokens(kind)
			Theme.Bind(frame, "BackgroundColor3", b)
			Theme.Bind(label, "TextColor3", f)
			Theme.Bind(icon, "ImageColor3", f)
		end
		if iconName ~= nil then
			Kit.SetIcon(icon, iconName)
		end
	end
	return badge
end

-- Spinner ----------------------------------------------------------------------------------------
local spinners = setmetatable({}, { __mode = "k" })
local spinnerLink

local function spin(dt)
	local any = false
	for image in pairs(spinners) do
		if image.Parent then
			any = true
			if Anim.Enabled() then
				image.Rotation = (image.Rotation + dt * 300) % 360
			end
		else
			spinners[image] = nil
		end
	end
	if not any and spinnerLink then
		spinnerLink:Disconnect()
		spinnerLink = nil
	end
end

function Kit.Spinner(parent, px, token, extra)
	local image = Kit.Icon(parent, "loader-2", px or 16, token or "Primary", extra)
	image.AnchorPoint = (extra and extra.AnchorPoint) or image.AnchorPoint
	spinners[image] = true
	if not spinnerLink then
		spinnerLink = Services.RunService.Heartbeat:Connect(spin)
	end
	return image
end

function Kit.StopSpinners()
	spinners = setmetatable({}, { __mode = "k" })
	if spinnerLink then
		spinnerLink:Disconnect()
		spinnerLink = nil
	end
end

-- Nearest ScrollingFrame above `gui` (so a drag can lock it while it runs).
function Kit.ScrollParent(gui)
	local node = gui.Parent
	while node do
		if node.ClassName == "ScrollingFrame" then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Responsive grid: the number of columns follows the available width.
-- o: Min (minimum cell width), Max (max columns), Gap, Height (cell height), Ratio (height = width * Ratio), Name, Order,
--    Flow (true: children keep an automatic height, only their width is set; used for cards with variable content)
function Kit.Grid(parent, o)
	o = o or {}
	local frame = Create.New("Frame", { Name = o.Name or "Grid", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = o.Order or 0, Parent = parent })
	local gap = o.Gap or 8
	local layout
	if o.Flow then
		layout = Create.ListScaled(frame, { Dir = "H", Padding = gap, Wrap = true })
	else
		layout = Create.Grid(frame, { Cell = UDim2.fromOffset(150, o.Height or 80), Padding = gap })
	end
	local object = { Frame = frame, Grid = layout, Min = o.Min or 150, Max = o.Max or 4, Height = o.Height or 80, Ratio = o.Ratio, Flow = o.Flow == true }
	function object:Refresh()
		local width = frame.AbsoluteSize.X / Root.Scale
		if width <= 0 then
			return
		end
		local columns = Util.clamp(math.floor((width + gap) / (self.Min + gap)), 1, self.Max)
		local cell = math.floor((width - gap * (columns - 1)) / columns)
		self.Columns = columns
		if self.Flow then
			for _, child in ipairs(frame:GetChildren()) do
				if child:IsA("GuiObject") then
					child.Size = UDim2.new(0, cell, 0, 0)
				end
			end
			return
		end
		local height = self.Ratio and math.floor(cell * self.Ratio) or self.Height
		layout.CellSize = UDim2.fromOffset(cell, height)
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		object:Refresh()
	end)
	if o.Flow then
		frame.ChildAdded:Connect(function()
			object:Refresh()
		end)
	end
	object:Refresh()
	return object
end

-- One shared 1 Hz ticker (clocks, countdowns, relative times). Returns a handle with Disconnect().
local tickers = {}
local tickLink
local tickAccumulator = 0

local function tickStep(dt)
	tickAccumulator = tickAccumulator + dt
	if tickAccumulator < 1 then
		return
	end
	tickAccumulator = tickAccumulator - 1
	local count = 0
	for callback in pairs(Util.clone(tickers)) do
		count = count + 1
		local ok, err = pcall(callback)
		if not ok then
			warn("[DeaUI-S] ticker error: " .. tostring(err))
		end
	end
	if count == 0 and tickLink then
		tickLink:Disconnect()
		tickLink = nil
	end
end

function Kit.Tick(callback)
	tickers[callback] = true
	if not tickLink then
		tickAccumulator = 0
		tickLink = Services.RunService.Heartbeat:Connect(tickStep)
	end
	local handle = {}
	function handle.Disconnect()
		tickers[callback] = nil
	end
	handle.Clean = handle.Disconnect
	return handle
end

function Kit.StopTickers()
	tickers = {}
	if tickLink then
		tickLink:Disconnect()
		tickLink = nil
	end
end

-- Wrapper frame for a block (stat grid, gallery, card...) inside a Page or a Group.
function Kit.BlockHolder(container, o)
	o = o or {}
	local frame = Create.New("Frame", {
		Name = o.Name or "Block",
		Size = UDim2.new(1, 0, 0, o.Height or 0),
		AutomaticSize = o.Height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		LayoutOrder = container:_order(),
		Visible = o.Visible,
		Parent = container.Content,
	})
	if container.IsGroup then
		Create.Pad(frame, 12, 10, 12, 12)
	end
	return frame
end

return Kit
end

Modules["UI/Layout"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Kit = import("UI/Kit")
local Root = import("UI/Root")
local Loc = import("Localization")
local Signal = import("Core/Signal")
local Util = import("Core/Util")
local Controls = import("UI/Controls")

--[[
	Page (scrolling content of one navigation entry) and Group (a card of rows).
	Both accept the same component methods: group:Toggle / Slider / Dropdown ... and the blocks
	page:StatGrid / PetCard / AssetGallery ... (see Blocks). Calling a control method directly on a
	Page creates an untitled Group automatically.
]]
local Layout = {}

-- Group -----------------------------------------------------------------------------------------------------------
local Group = Kit.Class()
Group.IsGroup = true
Layout.Group = Group

function Group:_order()
	self._n = (self._n or 0) + 1
	return self._n
end

-- Called by every row based control: first-row separator, responsive tracking, search entry, locks.
function Group:_attach(control, row, o)
	control.Group = self
	if self._rows == 0 then
		row.Separator.Visible = false
	end
	self._rows = self._rows + 1
	if self.Page then
		self.Page:_track(row)
	end
	local window = self.Window
	if window then
		if row.TitleSource ~= nil and row.TitleSource ~= "" then
			control.Entry = window:_addSearch({ Page = self.Page, Group = self, Row = row, Frame = row.Frame })
		end
		if o.Vip or o.Locked then
			window.UI._lock(control, row, o)
		end
	end
end

function Group:SetTitle(source)
	if self.TitleLabel then
		Kit.SetText(self.TitleLabel, source)
	end
end

function Group:SetCollapsed(collapsed)
	collapsed = collapsed == true
	self.Collapsed = collapsed
	self.Content.Visible = not collapsed
	if self.Chevron then
		Anim.Tween(self.Chevron, { Rotation = collapsed and -90 or 0 }, "fast")
	end
	if self.Key and self.Window then
		self.Window:_saveCollapsed(self.Key, collapsed)
	end
end

function Group:OnDestroy()
	if self.Page then
		self.Page.Groups[self] = nil
	end
end

-- Page --------------------------------------------------------------------------------------------------------------
local Page = Kit.Class()
Layout.Page = Page
local Base = Kit.Base

local pageBase = Page
setmetatable(Page, { __index = function(_, key)
	local value = Base[key]
	if value ~= nil then
		return value
	end
	if key ~= "Row" and Controls.Constructors[key] then
		return function(self, ...)
			local group = self:_implicit()
			return group[key](group, ...)
		end
	end
	return nil
end })

function Page:_order()
	self._n = (self._n or 0) + 1
	return self._n
end

function Page:_width()
	return self.Scroll.AbsoluteSize.X / Root.Scale - 32
end

function Page:_track(row)
	self.Rows[row] = true
	row:Layout(self:_width())
end

function Page:_untrack(row)
	self.Rows[row] = nil
end

function Page:_relayout()
	local width = self:_width()
	for row in pairs(self.Rows) do
		row:Layout(width)
	end
end

function Page:_implicit()
	if not self.Implicit or self.Implicit.Destroyed then
		self.Implicit = self:Group(nil, { Name = "Implicit" })
	end
	return self.Implicit
end

-- page:Group(title, { Description, Icon, Collapsible, Collapsed, Id, Badge = { Text, Kind } })
function Page:Group(title, options)
	options = options or {}
	if type(title) == "table" and options.Title == nil and title.Title ~= nil then
		options, title = title, title.Title
	end
	local card = Kit.Panel(self.Content, { Name = options.Name or "Group", Size = UDim2.new(1, 0, 0, 0), AutoY = true, Order = self:_order(), Visible = options.Visible, Clip = false })
	Create.List(card, { Padding = 0 })
	local group = Kit.New(Group, card, { Page = self, Window = self.Window, UI = self.Window and self.Window.UI, _rows = 0, Collapsed = false })
	self.Groups[group] = true
	Kit.Adopt(self, group)
	local key = options.Id or (type(title) == "string" and title) or (type(title) == "table" and (title.en or title.vi)) or nil
	group.Key = key and (self.Id .. "." .. tostring(key)) or nil
	if title ~= nil and title ~= "" then
		local hasDescription = options.Description ~= nil
		local header = Create.New(options.Collapsible and "TextButton" or "Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, hasDescription and 56 or 44), LayoutOrder = 0, Text = options.Collapsible and "" or nil, Parent = card })
		Create.Pad(header, 14, 0, 12, 0)
		group.TitleLabel = Kit.Text(header, { Text = title, Size = 13, Weight = "Bold", Position = UDim2.fromOffset(0, hasDescription and 9 or 0), SizeUDim = UDim2.new(1, -90, 0, hasDescription and 18 or 44) })
		if hasDescription then
			group.DescriptionLabel = Kit.Text(header, { Text = options.Description, Size = 11, Color = "TextMuted", Position = UDim2.fromOffset(0, 28), SizeUDim = UDim2.new(1, -90, 0, 16) })
		end
		if options.Badge then
			local badge = Kit.Badge(header, { Text = options.Badge.Text, Kind = options.Badge.Kind, Position = UDim2.new(1, options.Collapsible and -26 or 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
			group.Badge = badge
		end
		if options.Collapsible then
			group.Chevron = Kit.Icon(header, "chevron-down", 16, "TextMuted", { Position = UDim2.new(1, -16, 0.5, -8) })
			header.Activated:Connect(function()
				group:SetCollapsed(not group.Collapsed)
			end)
		end
	end
	group.Content = Create.New("Frame", { Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
	Create.List(group.Content, { Padding = 0 })
	local collapsed = options.Collapsed == true
	if group.Key and self.Window then
		local saved = self.Window:_isCollapsed(group.Key)
		if saved ~= nil then
			collapsed = saved
		end
	end
	if options.Collapsible and collapsed then
		group:SetCollapsed(true)
	end
	return group
end

-- Heading shown at the top of the page.
function Page:Heading(title, subtitle)
	local holder = Create.New("Frame", { Name = "Heading", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self:_order(), Parent = self.Content })
	Create.List(holder, { Padding = 2 })
	Create.Pad(holder, 2, 0, 2, 4)
	Kit.Text(holder, { Text = title, Size = 20, Weight = "Bold", Order = 1 })
	if subtitle then
		Kit.Text(holder, { Text = subtitle, Size = 12, Color = "TextMuted", Wrap = true, Auto = "Y", Order = 2 })
	end
	return holder
end

function Page:Select()
	self.Window:SelectPage(self.Id)
end

function Page:SetText(source)
	self.Text = source
	if self.Nav then
		self.Nav:SetText(source)
	end
end

function Page:SetIcon(name)
	self.Icon = name
	if self.Nav then
		self.Nav:SetIcon(name)
	end
end

function Page:SetBadge(text, kind)
	if self.Nav then
		self.Nav:SetBadge(text, kind)
	end
end

function Page:SetVisible(visible)
	self.Hidden = visible == false
	if self.Nav then
		self.Nav.Frame.Visible = not self.Hidden
	end
	if self.Hidden and self.Window.Current == self then
		self.Window:SelectFirst()
	end
end

function Page:ScrollTo(frame)
	local scroll = self.Scroll
	local target = frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 12
	Anim.Tween(scroll, { CanvasPosition = Vector2.new(0, math.max(0, target)) }, "base")
end

function Page:Flash(frame)
	local stroke = Create.Stroke(frame, "Primary", 2)
	stroke.Transparency = 0
	local function remove()
		stroke:Destroy()
	end
	task.delay(0.9, function()
		Anim.Tween(stroke, { Transparency = 1 }, { Duration = "base", OnComplete = remove })
		if not Anim.Enabled() then
			remove()
		end
	end)
end

function Page:OnDestroy()
	if self.Window then
		self.Window:_pageDestroyed(self)
	end
end

-- spec: Id, Text (nav label), Icon, Title (heading), Subtitle, Order
function Layout.NewPage(window, spec)
	local scroll = Kit.Scroll(window.PageHost, { Name = "Page." .. spec.Id, Size = UDim2.fromScale(1, 1) })
	scroll.Visible = false
	local content = Create.New("Frame", { Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll })
	local pad = Create.PadScaled(content, 16, 14, 16, 20)
	Create.ListScaled(content, { Padding = 12 })
	local page = Kit.New(Page, scroll, { Id = spec.Id, Window = window, Scroll = scroll, Content = content, Padding = pad, Text = spec.Text, Icon = spec.Icon, Rows = {}, Groups = {} })
	page.Frame = scroll
	local relayout = Util.Debounce(0.05, function()
		if not page.Destroyed then
			page:_relayout()
		end
	end)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	if spec.Title then
		page:Heading(spec.Title, spec.Subtitle)
	end
	return page
end

-- Controls and blocks ---------------------------------------------------------------------------------------------
Controls.Attach(Group)

function Layout.AttachBlocks(blocks)
	for name, constructor in pairs(blocks) do
		local function method(container, ...)
			local object = constructor(container, ...)
			if type(object) == "table" and object.Scope then
				Kit.Adopt(container, object)
			end
			return object
		end
		Group[name] = method
		rawset(Page, name, method)
	end
end

return Layout
end

Modules["UI/Loader"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Root = import("UI/Root")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

--[[
	Loader: a calm centered card (icon, title, status line, thin progress bar, version footer) that fades in,
	runs your steps (or follows your SetProgress / SetStatus calls), then fades out and opens the window.
	It never blocks: Loader.Show returns a controller immediately.
	  controller:SetProgress(0..1)  :SetStatus(text)  :Next()  :Finish()  :Fail(message)  :Close()  :Wait()
	Fail() shows a clean error state with Retry / Close buttons.
]]
local Loader = {}
local Class = Kit.Class()
local current

function Class:SetProgress(fraction, instant)
	fraction = Util.clamp(tonumber(fraction) or 0, 0, 1)
	self.Progress = fraction
	if instant then
		self.Fill.Size = UDim2.fromScale(fraction, 1)
	else
		Anim.Tween(self.Fill, { Size = UDim2.fromScale(fraction, 1) }, "base")
	end
	self.Percent.Text = Util.Format.Percent(fraction)
	Loc.Unbind(self.Percent, "Text")
end

function Class:SetStatus(source)
	Kit.SetText(self.Status, source or "")
end

function Class:Next()
	if self.Done then
		return
	end
	self.StepIndex = math.min(self.StepIndex + 1, #self.Steps)
	local step = self.Steps[self.StepIndex]
	if step ~= nil then
		self:SetStatus(step)
	end
	if #self.Steps > 0 then
		self:SetProgress(self.StepIndex / #self.Steps)
	end
end

function Class:Close(instant)
	if self.Closing then
		return
	end
	self.Closing = true
	self.Done = true
	local function finish()
		self.Finished:Fire()
		if current == self then
			current = nil
		end
		self.Backdrop:Destroy()
	end
	if instant or not Anim.Enabled() then
		finish()
	else
		Anim.Tween(self.Backdrop, { BackgroundTransparency = 1 }, "base")
		Anim.Tween(self.Card, { GroupTransparency = 1 }, { Duration = "base", OnComplete = finish })
		Anim.Tween(self.CardScale, { Scale = 1.03 }, "base")
	end
end

-- Completes the bar, then fades out, runs OnDone and shows the window.
function Class:Finish()
	if self.Done then
		return
	end
	self.Done = true
	self:SetProgress(1)
	self:SetStatus("loader.ready")
	task.delay(Anim.Enabled() and 0.35 or 0, function()
		if self.Closing then
			return
		end
		self.Done = false
		if self.OnDone then
			Kit.Safe(self.OnDone)(self)
		end
		if self.Window and not self.Window.Destroyed then
			self.Window:Show()
		end
		self:Close()
	end)
end

-- Error state: red icon, message, Retry (calls OnRetry) and Close.
function Class:Fail(message)
	if self.Closing then
		return
	end
	self.Failed = true
	self.Done = true
	self.AutoToken = (self.AutoToken or 0) + 1
	Theme.Bind(self.Well, "BackgroundColor3", "DangerSoft")
	Kit.SetIcon(self.IconImage, "alert-triangle")
	Theme.Bind(self.IconImage, "ImageColor3", "Danger")
	Kit.SetText(self.Status, message or "loader.failed_message")
	Theme.Bind(self.Status, "TextColor3", "Danger")
	Kit.SetText(self.Title, "loader.failed")
	self.Track.Visible = false
	self.Percent.Visible = false
	self.ButtonRow.Visible = true
end

function Class:Wait()
	if self.Closing and not self.Backdrop.Parent then
		return
	end
	self.Finished:Wait()
end

local function run(self, duration)
	local steps = self.Steps
	self.AutoToken = (self.AutoToken or 0) + 1
	local token = self.AutoToken
	local per = duration / math.max(#steps, 1)
	task.spawn(function()
		for index = 1, #steps do
			if self.AutoToken ~= token or self.Closing then
				return
			end
			self:Next()
			task.wait(per)
		end
		if self.AutoToken == token then
			self:Finish()
		end
	end)
end

-- options: Title, Subtitle, Icon, Steps = { text... }, Duration (seconds, runs the steps automatically), Footer, Window, OnDone, OnRetry
function Loader.Show(options)
	options = options or {}
	if not Root.Ready then
		error("[DeaUI-S] call Init() before showing the loader", 2)
	end
	if current then
		current:Close(true)
	end
	local backdrop = Create.New("Frame", { Name = "Loader", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1, Bind = { BackgroundColor3 = "Background" }, Parent = Root.LoaderLayer })
	local blocker = Create.New("TextButton", { Name = "Blocker", Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 1, Parent = backdrop })
	local screen = Root.ScreenSize()
	local card = Create.New("CanvasGroup", { Name = "Card", Size = UDim2.new(0, math.min(340, screen.X - 40), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), GroupTransparency = 1, ZIndex = 2, Bind = { BackgroundColor3 = "Surface" }, Parent = backdrop })
	Create.Corner(card, "lg")
	Create.Stroke(card, "BorderStrong")
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.96
	cardScale.Parent = card
	local body = Create.New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	Create.Pad(body, 24, 28, 24, 22)
	Create.List(body, { Padding = 10, HAlign = "Center" })
	local well = Create.New("Frame", { Name = "Well", Size = UDim2.fromOffset(60, 60), LayoutOrder = 1, Bind = { BackgroundColor3 = "PrimarySoft" }, Parent = body })
	Create.Corner(well, "xl")
	local icon = Kit.Icon(well, options.Icon or "layout-dashboard", 28, "Primary", { Position = UDim2.new(0.5, -14, 0.5, -14) })
	local title = Kit.Text(body, { Text = options.Title or "DeaUI-S", Size = 18, Weight = "Bold", Align = "Center", Order = 2 })
	local subtitle = Kit.Text(body, { Text = options.Subtitle, Size = 12, Color = "TextMuted", Align = "Center", Wrap = true, Auto = "Y", Order = 3 })
	subtitle.Visible = options.Subtitle ~= nil
	local spacer = Create.New("Frame", { Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 4, Parent = body })
	local track = Create.New("Frame", { Name = "Track", Size = UDim2.new(1, 0, 0, 5), LayoutOrder = 5, Bind = { BackgroundColor3 = "SurfacePressed" }, Parent = body })
	Create.Corner(track, "pill")
	local fill = Create.New("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), Bind = { BackgroundColor3 = "Primary" }, Parent = track })
	Create.Corner(fill, "pill")
	local row = Create.New("Frame", { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 6, Parent = body })
	local status = Kit.Text(row, { Text = "loader.starting", Size = 12, Color = "TextMuted", SizeUDim = UDim2.new(1, -44, 1, 0) })
	local percent = Kit.Text(row, { Size = 11, Mono = true, Color = "TextFaint", Align = "Right", Position = UDim2.new(1, -44, 0, 0), SizeUDim = UDim2.new(0, 44, 1, 0) })
	local buttons = Create.New("Frame", { Name = "Buttons", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 7, Visible = false, Parent = body })
	Create.List(buttons, { Dir = "H", Padding = 8, HAlign = "Center" })
	local footer = Kit.Text(body, { Text = options.Footer, Size = 11, Color = "TextFaint", Align = "Center", Order = 8 })
	footer.Visible = options.Footer ~= nil

	local controller = Kit.New(Class, backdrop, {
		Backdrop = backdrop, Card = card, CardScale = cardScale, Fill = fill, Percent = percent, Status = status, Title = title, Well = well, IconImage = icon, Track = track,
		ButtonRow = buttons, Steps = options.Steps or {}, StepIndex = 0, Progress = 0, Window = options.Window, OnDone = options.OnDone, OnRetry = options.OnRetry,
	})
	controller.Finished = Signal.new()
	controller:SetProgress(0, true)
	local retry = Kit.Button(buttons, { Text = "common.retry", Icon = "refresh-cw", Variant = "primary", Order = 1, Callback = function()
		controller.Failed, controller.Done, controller.StepIndex = false, false, 0
		controller.ButtonRow.Visible = false
		controller.Track.Visible, controller.Percent.Visible = true, true
		Kit.SetIcon(icon, options.Icon or "layout-dashboard")
		Theme.Bind(icon, "ImageColor3", "Primary")
		Theme.Bind(well, "BackgroundColor3", "PrimarySoft")
		Theme.Bind(status, "TextColor3", "TextMuted")
		Kit.SetText(title, options.Title or "DeaUI-S")
		controller:SetStatus("loader.starting")
		controller:SetProgress(0, true)
		if controller.OnRetry then
			Kit.Safe(controller.OnRetry)(controller)
		elseif options.Duration then
			run(controller, options.Duration)
		end
	end })
	local close = Kit.Button(buttons, { Text = "common.close", Variant = "secondary", Order = 2, Callback = function()
		controller:Close()
	end })
	controller.Scope:Add(retry)
	controller.Scope:Add(close)
	-- enter animation
	Anim.Tween(backdrop, { BackgroundTransparency = 0.12 }, "base")
	Anim.Tween(card, { GroupTransparency = 0 }, "base")
	Anim.Tween(cardScale, { Scale = 1 }, "base")
	current = controller
	if options.Duration and #controller.Steps > 0 then
		run(controller, options.Duration)
	elseif options.Duration then
		controller.Steps = { "loader.loading_modules", "loader.loading_settings", "loader.building" }
		run(controller, options.Duration)
	end
	return controller
end

function Loader.Destroy()
	if current then
		current.AutoToken = (current.AutoToken or 0) + 1
		current:Close(true)
		current = nil
	end
end

return Loader
end

Modules["UI/Notification"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Kit = import("UI/Kit")
local Root = import("UI/Root")
local Signal = import("Core/Signal")

--[[
	Toast notifications: stacked, queued (max 4 visible), hover pauses the countdown, click or the X closes.
	  Notification.Show({ Title, Message, Kind = "info"|"success"|"warn"|"error"|"accent", Duration = 4 (0 = stays),
	                      Icon, Actions = { { Text, Callback, Variant } }, OnClose })
	Title and Message accept localized sources ({ en = "...", vi = "..." } or keys).
]]
local Notification = { MaxVisible = 4 }

local KINDS = {
	info = { "info", "Info" },
	success = { "check-circle", "Success" },
	warn = { "alert-triangle", "Warning" },
	warning = { "alert-triangle", "Warning" },
	error = { "x-circle", "Danger" },
	danger = { "x-circle", "Danger" },
	accent = { "bell", "Primary" },
}

local stack
local active = {}
local queue = {}
local layoutLink

local function place()
	if not stack then
		return
	end
	local metrics = Root.Metrics()
	local insets = metrics.Insets
	if metrics.Compact then
		stack.AnchorPoint = Vector2.new(0.5, 0)
		stack.Position = UDim2.new(0.5, 0, 0, insets.Top + 8)
		stack.Size = UDim2.fromOffset(math.min(metrics.Screen.X - insets.Left - insets.Right - 24, 420), 0)
	else
		stack.AnchorPoint = Vector2.new(1, 0)
		stack.Position = UDim2.new(1, -(insets.Right + 16), 0, insets.Top + 12)
		stack.Size = UDim2.fromOffset(340, 0)
	end
end

local function ensure()
	if stack and stack.Parent then
		return
	end
	stack = Create.New("Frame", { Name = "Notifications", AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 150, Parent = Root.Layer })
	Create.List(stack, { Padding = 8, HAlign = "Right" })
	place()
	if layoutLink then
		layoutLink:Disconnect()
	end
	layoutLink = Root.Changed:Connect(place)
end

local function dispatch()
	while #active < Notification.MaxVisible and #queue > 0 do
		local item = table.remove(queue, 1)
		item()
	end
end

function Notification.Show(o)
	o = o or {}
	if not Root.Ready then
		return nil
	end
	ensure()
	local kind = KINDS[string.lower(tostring(o.Kind or "info"))] or KINDS.info
	local handle = { Closed = false }
	local function start()
		local slot = Create.New("Frame", { Name = "Slot", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = (handle.Order or 0), Parent = stack })
		local toast = Create.New("CanvasGroup", { Name = "Toast", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, Position = UDim2.fromOffset(40, 0), Bind = { BackgroundColor3 = "Surface" }, Parent = slot })
		Create.Corner(toast, "md")
		Create.Stroke(toast, "BorderStrong")
		local accent = Create.New("Frame", { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), Bind = { BackgroundColor3 = kind[2] }, Parent = toast })
		local body = Create.New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = toast })
		Create.Pad(body, 16, 12, 38, 14)
		Create.List(body, { Padding = 4 })
		local head = Create.New("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = body })
		Kit.Icon(head, o.Icon or kind[1], 16, kind[2], { Position = UDim2.new(0, 0, 0.5, -8) })
		Kit.Text(head, { Text = o.Title, Size = 13, Weight = "Bold", Position = UDim2.fromOffset(24, 0), SizeUDim = UDim2.new(1, -24, 1, 0) })
		if o.Message ~= nil and o.Message ~= "" then
			Kit.Text(body, { Text = o.Message, Size = 12, Color = "TextMuted", Wrap = true, Auto = "Y", Order = 2 })
		end
		if o.Actions and #o.Actions > 0 then
			local row = Create.New("Frame", { Name = "Actions", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3, Parent = body })
			Create.List(row, { Dir = "H", Padding = 6 })
			for index, action in ipairs(o.Actions) do
				Kit.Button(row, { Text = action.Text, Variant = action.Variant or "soft", Height = 28, Compact = true, Order = index, Callback = function()
					if action.Callback then
						Kit.Safe(action.Callback)(handle)
					end
					handle:Close()
				end })
			end
		end
		local closeButton = Create.New("TextButton", { Name = "Close", Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Text = "", ZIndex = 5, Parent = toast })
		Kit.Icon(closeButton, "x", 14, "TextMuted", { Position = UDim2.new(0.5, -7, 0.5, -7), ZIndex = 5 })
		closeButton.Visible = o.Closable ~= false
		local bar = Create.New("Frame", { Name = "Timer", Size = UDim2.new(1, 0, 0, 2), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Visible = false, BackgroundTransparency = 0.4, Bind = { BackgroundColor3 = kind[2] }, Parent = toast })
		handle.Slot, handle.Toast = slot, toast

		local duration = o.Duration == nil and 4 or o.Duration
		local remaining = duration
		local started
		local function run()
			if duration <= 0 or handle.Closed then
				return
			end
			started = os.clock()
			bar.Visible = Anim.Enabled()
			Anim.Tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, { Duration = remaining, Raw = true, Style = Enum.EasingStyle.Linear })
			local mine = (handle.Run or 0) + 1
			handle.Run = mine
			task.delay(remaining, function()
				if handle.Run == mine and not handle.Closed then
					handle:Close()
				end
			end)
		end
		local function pause()
			if duration <= 0 or handle.Closed or not started then
				return
			end
			handle.Run = (handle.Run or 0) + 1
			remaining = math.max(0.5, remaining - (os.clock() - started))
			started = nil
			Anim.Cancel(bar)
		end
		if not Kit.Touch() then
			toast.MouseEnter:Connect(pause)
			toast.MouseLeave:Connect(function()
				if not handle.Closed then
					bar.Size = UDim2.new(remaining / math.max(duration, 0.01), 0, 0, 2)
					run()
				end
			end)
		end
		closeButton.Activated:Connect(function()
			handle:Close()
		end)
		Anim.Tween(toast, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, "base")
		run()
	end

	function handle:Close()
		if self.Closed then
			return
		end
		self.Closed = true
		self.Run = (self.Run or 0) + 1
		for index, entry in ipairs(active) do
			if entry == self then
				table.remove(active, index)
				break
			end
		end
		for index, pending in ipairs(queue) do
			if pending == self.Start then
				table.remove(queue, index)
				break
			end
		end
		local slot, toast = self.Slot, self.Toast
		if o.OnClose then
			Kit.Safe(o.OnClose)(self)
		end
		if slot then
			local function finish()
				slot:Destroy()
				dispatch()
			end
			if Anim.Enabled() and toast then
				Anim.Tween(toast, { GroupTransparency = 1, Position = UDim2.fromOffset(40, 0) }, { Duration = "fast", OnComplete = finish })
			else
				finish()
			end
		else
			dispatch()
		end
	end

	function handle:Update(patch)
		-- simple update: close and show again is avoided; only text changes are supported
		for _, child in ipairs(self.Toast and self.Toast:GetDescendants() or {}) do
			if child:IsA("TextLabel") and patch.Message ~= nil and child.Name == "Text" and child.TextSize == Kit.Size(12) then
				Kit.SetText(child, patch.Message)
			end
		end
	end

	Notification.Counter = (Notification.Counter or 0) + 1
	handle.Order = Notification.Counter
	handle.Start = function()
		handle.Start = nil
		if not handle.Closed then
			table.insert(active, handle)
			start()
		end
	end
	if #active >= Notification.MaxVisible then
		-- make room: persistent toasts stay, the oldest timed toast is dismissed
		for _, entry in ipairs(active) do
			if not entry.Persistent then
				entry:Close()
				break
			end
		end
	end
	handle.Persistent = o.Duration == 0
	if #active < Notification.MaxVisible then
		handle.Start()
	else
		table.insert(queue, handle.Start)
	end
	return handle
end

function Notification.Clear()
	queue = {}
	for _, entry in ipairs(table.pack(table.unpack(active))) do
		if type(entry) == "table" and entry.Close then
			entry:Close()
		end
	end
end

function Notification.Destroy()
	queue = {}
	active = {}
	if layoutLink then
		layoutLink:Disconnect()
		layoutLink = nil
	end
	if stack then
		stack:Destroy()
		stack = nil
	end
end

return Notification
end

Modules["UI/Popup"] = function(import)
local Create = import("UI/Create")
local Root = import("UI/Root")
local Anim = import("Animation")
local Services = import("Core/Services")
local Util = import("Core/Util")

-- Anchored popup (dropdown lists, color picker). One at a time; it closes on outside click, Escape
-- or when the viewport changes, and it opens above the anchor when there is no room below.
local Popup = {}

local current

function Popup.Close(instant)
	if current then
		current:Close(instant)
	end
end

function Popup.IsOpen()
	return current ~= nil
end

-- options: Anchor (GuiObject) or Origin (+ Extent) in layer pixels, Width, MinWidth, MaxHeight, Align ("Left"|"Right"), Build(frame, close) -> height, OnClose
function Popup.Open(options)
	Popup.Close(true)
	if not Root.Ready then
		return nil
	end
	local anchor = options.Anchor
	local origin = options.Origin or Root.ToLocal(anchor.AbsolutePosition)
	local extent = options.Extent or Root.ToLocal(anchor.AbsoluteSize)
	local screen = Root.ScreenSize()
	local insets = Root.Insets()
	local margin = 8
	local width = options.Width or math.max(extent.X, options.MinWidth or 160)
	width = math.min(width, screen.X - insets.Left - insets.Right - margin * 2)

	local catcher = Create.New("TextButton", {
		Name = "PopupCatcher",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 100,
		Parent = Root.Layer,
	})
	local frame = Create.New("CanvasGroup", {
		Name = "Popup",
		Size = UDim2.fromOffset(width, 10),
		GroupTransparency = 1,
		ZIndex = 101,
		Bind = { BackgroundColor3 = "Surface" },
		Parent = Root.Layer,
	})
	Create.Corner(frame, "md")
	Create.Stroke(frame, "BorderStrong")

	local handle = { Frame = frame, Closed = false }
	local connections = {}

	function handle:Close(instant)
		if self.Closed then
			return
		end
		self.Closed = true
		if current == self then
			current = nil
		end
		for _, link in ipairs(connections) do
			link:Disconnect()
		end
		connections = {}
		catcher:Destroy()
		local function finish()
			frame:Destroy()
		end
		if instant or not Anim.Enabled() then
			finish()
		else
			Anim.Tween(frame, { GroupTransparency = 1 }, { Duration = "fast", OnComplete = finish })
		end
		if options.OnClose then
			pcall(options.OnClose)
		end
	end

	local content = options.Build(frame, function()
		handle:Close()
	end)
	local available = math.max(80, screen.Y - insets.Top - insets.Bottom - margin * 2)
	local height = Util.clamp(content or 120, 40, math.min(options.MaxHeight or 280, available))
	local below = origin.Y + extent.Y + 4
	local spaceBelow = screen.Y - insets.Bottom - below - margin
	local spaceAbove = origin.Y - insets.Top - margin - 4
	local y
	if height > spaceBelow and spaceAbove > spaceBelow then
		height = math.min(height, spaceAbove)
		y = origin.Y - 4 - height
	else
		height = math.min(height, math.max(spaceBelow, 80))
		y = below
	end
	local x = options.Align == "Right" and (origin.X + extent.X - width) or origin.X
	x = Util.clamp(x, insets.Left + margin, math.max(insets.Left + margin, screen.X - insets.Right - width - margin))
	frame.Size = UDim2.fromOffset(width, height)
	frame.Position = UDim2.fromOffset(x, y + 4)
	Anim.Tween(frame, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, "fast")

	catcher.Activated:Connect(function()
		handle:Close()
	end)
	connections[#connections + 1] = Services.UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			handle:Close()
		end
	end)
	connections[#connections + 1] = Root.Changed:Connect(function()
		handle:Close(true)
	end)
	current = handle
	return handle
end

return Popup
end

Modules["UI/Root"] = function(import)
local Env = import("Core/Env")
local Services = import("Core/Services")
local Signal = import("Core/Signal")
local Input = import("Core/Input")
local Util = import("Core/Util")

--[[
	Root: the ScreenGuis (windows, HUD, overlay, loader), the user interface scale and the responsive
	metrics (screen size, safe insets, device class). Layout code reads Root.Metrics() instead of
	assuming a PC or a phone, and Root.Changed fires when the viewport or the input type changes.
]]
local Root = { Changed = Signal.new(), Scale = 1, Ready = false }

local guis = {}
local layers = {}
local scales = {}
local probeFrame
local lastKey

local function parentFor(gui)
	local candidates = {}
	if Env.gethui then
		local ok, hui = pcall(Env.gethui)
		if ok and typeof(hui) == "Instance" then
			candidates[#candidates + 1] = Env.Ref(hui)
		end
	end
	local coreGui = Services.CoreGui
	if coreGui then
		candidates[#candidates + 1] = coreGui
	end
	pcall(function()
		local player = Services.Players.LocalPlayer
		local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			candidates[#candidates + 1] = playerGui
		end
	end)
	for _, candidate in ipairs(candidates) do
		local ok = pcall(function()
			gui.Parent = candidate
		end)
		if ok and gui.Parent ~= nil then
			return candidate
		end
	end
	return nil
end

local function screen(name, order, insetMode)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	pcall(function()
		gui.ScreenInsets = insetMode or Enum.ScreenInsets.None
	end)
	if not parentFor(gui) then
		gui:Destroy()
		error("[DeaUI-S] could not mount the interface (no GUI container available)", 3)
	end
	return gui
end

local function layer(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = frame
	frame.Parent = parent
	scales[#scales + 1] = { Frame = frame, Scale = scale }
	return frame
end

function Root.Init(scope)
	Root.Main = scope:Add(screen("DeaUI-S.Main", 2147482000))
	Root.HUD = scope:Add(screen("DeaUI-S.HUD", 2147482100))
	Root.Overlay = scope:Add(screen("DeaUI-S.Overlay", 2147482300))
	Root.Loader = scope:Add(screen("DeaUI-S.Loader", 2147482900))
	Root.Windows = layer(Root.Main, "Windows")
	Root.HUDLayer = layer(Root.HUD, "HUD")
	Root.Layer = layer(Root.Overlay, "Layer")
	Root.LoaderLayer = layer(Root.Loader, "Loader")

	local probe = scope:Add(screen("DeaUI-S.Probe", -1, Enum.ScreenInsets.DeviceSafeInsets))
	probeFrame = Instance.new("Frame")
	probeFrame.Name = "Safe"
	probeFrame.BackgroundTransparency = 1
	probeFrame.BorderSizePixel = 0
	probeFrame.Size = UDim2.fromScale(1, 1)
	probeFrame.Parent = probe

	local recompute = Util.Debounce(0.08, function()
		local key = Root.Key()
		if key ~= lastKey then
			lastKey = key
			Root.Changed:Fire(Root.Metrics())
		end
	end)
	scope:Connect(Root.Main:GetPropertyChangedSignal("AbsoluteSize"), recompute)
	scope:Connect(probeFrame:GetPropertyChangedSignal("AbsoluteSize"), recompute)
	scope:Connect(Services.UserInputService:GetPropertyChangedSignal("MouseEnabled"), recompute)
	scope:Connect(Services.UserInputService:GetPropertyChangedSignal("TouchEnabled"), recompute)
	scope:Add(function()
		guis, layers, scales, probeFrame, lastKey = {}, {}, {}, nil, nil
		Root.Main, Root.HUD, Root.Overlay, Root.Loader = nil, nil, nil, nil
		Root.Windows, Root.HUDLayer, Root.Layer, Root.LoaderLayer = nil, nil, nil, nil
		Root.Ready = false
	end)
	Root.Ready = true
	Root.ApplyScale()
	lastKey = Root.Key()
	return Root
end

function Root.ApplyScale()
	local s = Root.Scale
	for _, entry in ipairs(scales) do
		entry.Scale.Scale = s
		entry.Frame.Size = UDim2.fromScale(1 / s, 1 / s)
	end
end

function Root.SetScale(scale, silent)
	scale = Util.clamp(tonumber(scale) or 1, 0.7, 1.5)
	if scale == Root.Scale then
		return
	end
	Root.Scale = scale
	if Root.Ready then
		Root.ApplyScale()
		if not silent then
			lastKey = Root.Key()
			Root.Changed:Fire(Root.Metrics())
		end
	end
end

-- Physical screen size in pixels.
local function physical()
	local main = Root.Main
	if main and main.AbsoluteSize.X > 0 then
		return main.AbsoluteSize
	end
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

-- Logical size (what children of the layers see: physical size divided by the UI scale).
function Root.ScreenSize()
	return physical() / Root.Scale
end

function Root.TopInset()
	local ok, rect = pcall(function()
		return Services.GuiService.TopbarInset
	end)
	if ok and rect and rect.Height and rect.Height > 0 then
		return rect.Max.Y
	end
	local okInset, inset = pcall(function()
		return Services.GuiService:GetGuiInset()
	end)
	if okInset and inset then
		return inset.Y
	end
	return 36
end

-- Safe area in logical pixels: { Left, Top, Right, Bottom }.
function Root.Insets()
	local full = physical()
	local left, top, right, bottom = 0, 0, 0, 0
	if probeFrame then
		local position, size = probeFrame.AbsolutePosition, probeFrame.AbsoluteSize
		if size.X > 0 and size.Y > 0 and size.X <= full.X + 1 and size.Y <= full.Y + 1 then
			left, top = position.X, position.Y
			right = math.max(0, full.X - (position.X + size.X))
			bottom = math.max(0, full.Y - (position.Y + size.Y))
		end
	end
	top = math.max(top, Root.TopInset() * Root.Scale)
	local s = Root.Scale
	return { Left = left / s, Top = top / s, Right = right / s, Bottom = bottom / s }
end

-- { Screen, Safe (size of the usable area), Insets, Device = "Phone"|"Tablet"|"Desktop", Compact, Touch, Mouse }
function Root.Metrics()
	local screenSize = Root.ScreenSize()
	local insets = Root.Insets()
	local safe = Vector2.new(screenSize.X - insets.Left - insets.Right, screenSize.Y - insets.Top - insets.Bottom)
	local device
	if safe.X < 600 or safe.Y < 420 then
		device = "Phone"
	elseif safe.X < 1000 then
		device = "Tablet"
	else
		device = "Desktop"
	end
	local platform = Input.Platform()
	return {
		Screen = screenSize,
		Safe = safe,
		Insets = insets,
		Device = device,
		Compact = device == "Phone",
		Touch = platform.TouchOnly,
		Mouse = platform.Mouse,
		Scale = Root.Scale,
	}
end

function Root.Key()
	local m = Root.Metrics()
	return string.format("%d|%d|%s|%s|%.2f", math.floor(m.Screen.X), math.floor(m.Screen.Y), m.Device, tostring(m.Touch), m.Insets.Top + m.Insets.Left)
end

-- Converts a screen pixel position (pointer, AbsolutePosition) into layer coordinates.
function Root.ToLocal(point)
	return point / Root.Scale
end

function Root.SetVisible(visible)
	for _, gui in ipairs({ Root.Main, Root.HUD, Root.Overlay }) do
		if gui then
			gui.Enabled = visible
		end
	end
end

return Root
end

Modules["UI/SettingsPage"] = function(import)
local Theme = import("Theme/Theme")
local Loc = import("Localization")
local Anim = import("Animation")
local Env = import("Core/Env")
local Util = import("Core/Util")
local Persistence = import("Storage/Persistence")
local AutoLoad = import("Storage/AutoLoad")
local Config = import("Storage/Config")
local Layout = import("UI/Layout")
local WindowModule = import("UI/Window")
local HUD = import("UI/HUD")
local Dialog = import("UI/Dialog")

--[[
	window:AddSettingsPage(options) builds a ready made page: language, theme (presets, colors, radius, saved custom
	themes), interface (scale, animations, toggle key), HUD, configurations + AutoLoad, data folder and unload.
	page:ConfigGroup() adds only the configuration card to any page. All text is localized.
]]
local Window, Page = WindowModule.Class, Layout.Page

-- Configuration card: name, list, save / load / delete, AutoLoad ----------------------------------------------------
function Page:ConfigGroup(options)
	options = options or {}
	local UI = self.Window.UI
	local group = self:Group("config.title", { Id = "configs", Description = Persistence.Available() and nil or "error.storage_unavailable" })
	local nameInput = group:TextInput({ Title = "config.name", Description = "config.name_desc", Icon = "file-text", Placeholder = "config.placeholder", Default = options.Default or "Default" })
	local selection
	local function names()
		local list = {}
		for _, name in ipairs(Config.List()) do
			list[#list + 1] = { Text = name, Value = name }
		end
		return list
	end
	selection = group:Dropdown({ Title = "config.select", Icon = "folder-open", Options = names(), Placeholder = "config.none", Callback = function(name)
		nameInput:Set(name, true)
	end })
	local function refresh()
		selection:SetOptions(names())
	end
	local function current()
		local name = Util.trim(nameInput:Get())
		if name == "" then
			local picked = selection:Get()
			name = picked or ""
		end
		return name
	end
	group:Buttons({
		{ Text = "config.save", Icon = "save", Variant = "primary", Callback = function()
			local name = current()
			if name == "" then
				UI.Notify({ Title = "config.name", Message = "config.name_required", Kind = "warn" })
				return
			end
			if UI.SaveConfig(name) then
				UI.Notify({ Title = "config.saved", Message = name, Kind = "success", Duration = 2.5 })
				refresh()
				selection:Set(name, true)
			else
				UI.Notify({ Title = "error.save_failed", Message = name, Kind = "error" })
			end
		end },
		{ Text = "config.load", Icon = "folder-open", Callback = function()
			local name = current()
			local ok, err = UI.LoadConfig(name)
			if ok then
				UI.Notify({ Title = "config.loaded", Message = name, Kind = "success", Duration = 2.5 })
			else
				UI.Notify({ Title = err == "corrupt" and "error.config_corrupt" or "config.not_found", Message = name, Kind = "warn" })
			end
		end },
		{ Text = "config.delete", Icon = "trash-2", Variant = "danger", Callback = function()
			local name = current()
			if name == "" or not Config.Exists(name) then
				UI.Notify({ Title = "config.not_found", Message = name, Kind = "warn" })
				return
			end
			task.spawn(function()
				if Dialog.Confirm({ Title = "config.delete", Message = name, Danger = true, Yes = "common.delete" }) then
					UI.DeleteConfig(name)
					refresh()
					UI.Notify({ Title = "config.deleted", Message = name, Kind = "info", Duration = 2.5 })
				end
			end)
		end },
	})
	local auto = AutoLoad.Get()
	local autoToggle
	autoToggle = group:Toggle({ Title = "config.autoload", Description = "config.autoload_desc", Icon = "zap", Default = auto.Enabled, Callback = function(on)
		if on then
			local name = current()
			if name == "" or not Config.Exists(name) then
				UI.Notify({ Title = "config.not_found", Message = "config.save_first", Kind = "warn" })
				autoToggle:Set(false, true)
				return
			end
			UI.SetAutoLoad(name)
			UI.Notify({ Title = "config.autoload_on", Message = name, Kind = "success", Duration = 2.5 })
		else
			UI.ClearAutoLoad()
			UI.Notify({ Title = "config.autoload_off", Kind = "info", Duration = 2 })
		end
	end })
	if auto.Config then
		nameInput:Set(auto.Config, true)
		selection:Set(auto.Config, true)
	end
	return group
end

function Window:AddSettingsPage(options)
	options = options or {}
	local UI = self.UI
	local hide = options.Hide or {}
	local page = self:AddPage({ Id = options.Id or "settings", Text = options.Text or "nav.settings", Icon = options.Icon or "settings", Title = "settings.title", Subtitle = "settings.subtitle" })

	if not hide.Language then
		local group = page:Group("settings.language", { Id = "language" })
		local segmented = group:Segmented({ Title = "settings.language", Description = "settings.language_desc", Icon = "languages", Options = Loc.Items(), Default = Loc.Get(), Callback = function(code)
			UI.SetLanguage(code)
		end })
		page.Scope:Connect(Loc.Changed, function(code)
			segmented:Set(code, true)
		end)
	end

	if not hide.Appearance then
		local group = page:Group("settings.appearance", { Id = "appearance" })
		local items = {}
		for _, name in ipairs(Theme.Names()) do
			items[#items + 1] = { Text = "theme.names." .. name, Value = name }
		end
		local dropdown = group:Dropdown({ Title = "settings.theme", Description = "settings.theme_desc", Icon = "palette", Options = items, Default = Theme.Get(), Callback = function(name)
			UI.SetTheme(name)
		end })
		local primary = group:ColorPicker({ Title = "theme.primary", Icon = "droplet", Default = Theme.Token("Primary"), Callback = function(color)
			UI.OverrideTheme({ Primary = color })
		end })
		local accent = group:ColorPicker({ Title = "theme.accent", Icon = "sparkles", Default = Theme.Token("Accent"), Callback = function(color)
			UI.OverrideTheme({ Accent = color })
		end })
		local radius = group:Slider({ Title = "theme.radius", Icon = "square", Min = 0, Max = 20, Step = 1, Default = Theme.Metrics().Radius, Suffix = "px", Callback = function(value)
			UI.OverrideTheme({ Radius = value })
		end })
		local spacing = group:Slider({ Title = "theme.spacing", Icon = "move-horizontal", Min = 4, Max = 14, Step = 1, Default = Theme.Metrics().Spacing, Suffix = "px", Callback = function(value)
			UI.OverrideTheme({ Spacing = value })
		end })
		group:Button({ Title = "settings.reset_theme", Icon = "rotate-ccw", ButtonText = "common.reset", Callback = function()
			UI.ResetTheme()
		end })
		local customName = group:TextInput({ Title = "theme.custom_name", Icon = "save", Placeholder = "theme.custom_placeholder" })
		local customList
		local function customItems()
			local list = {}
			for _, name in ipairs(UI.ListThemes()) do
				list[#list + 1] = { Text = name, Value = name }
			end
			return list
		end
		customList = group:Dropdown({ Title = "theme.custom_saved", Icon = "folder-open", Options = customItems(), Placeholder = "config.none", Callback = function(name)
			if name and UI.LoadTheme(name) then
				UI.Notify({ Title = "config.loaded", Message = name, Kind = "success", Duration = 2 })
			end
		end })
		group:Buttons({
			{ Text = "theme.save_custom", Icon = "save", Variant = "primary", Callback = function()
				local name = Util.trim(customName:Get())
				if name == "" then
					UI.Notify({ Title = "theme.custom_name", Message = "config.name_required", Kind = "warn" })
					return
				end
				if UI.SaveTheme(name) then
					customList:SetOptions(customItems())
					customList:Set(name, true)
					UI.Notify({ Title = "config.saved", Message = name, Kind = "success", Duration = 2 })
				end
			end },
			{ Text = "config.delete", Icon = "trash-2", Variant = "danger", Callback = function()
				local name = customList:Get()
				if name and UI.DeleteTheme(name) then
					customList:SetOptions(customItems())
					UI.Notify({ Title = "config.deleted", Message = name, Kind = "info", Duration = 2 })
				end
			end },
		})
		page.Scope:Connect(Theme.Changed, function()
			dropdown:Set(Theme.Get(), true)
			primary:Set(Theme.Token("Primary"), true)
			accent:Set(Theme.Token("Accent"), true)
			radius:Set(Theme.Metrics().Radius, true)
			spacing:Set(Theme.Metrics().Spacing, true)
		end)
	end

	if not hide.Interface then
		local group = page:Group("settings.interface", { Id = "interface" })
		group:Slider({ Title = "settings.scale", Description = "settings.scale_desc", Icon = "scaling", Min = 70, Max = 150, Step = 5, Default = math.floor(UI.GetScale() * 100 + 0.5), Suffix = "%", Callback = function(value)
			UI.SetScale(value / 100)
		end })
		group:Toggle({ Title = "settings.animations", Description = "settings.animations_desc", Icon = "wand-2", Default = Anim.Settings.AnimationEnabled, Callback = function(on)
			UI.ConfigureAnimations({ AnimationEnabled = on })
		end })
		group:Slider({ Title = "settings.animation_speed", Icon = "gauge", Min = 0.5, Max = 2, Step = 0.25, Default = Anim.Settings.AnimationSpeed, Suffix = "x", Callback = function(value)
			UI.ConfigureAnimations({ AnimationSpeed = value })
		end })
		group:Toggle({ Title = "settings.reduced_motion", Description = "settings.reduced_motion_desc", Icon = "eye-off", Default = Anim.Settings.ReducedMotion, Callback = function(on)
			UI.ConfigureAnimations({ ReducedMotion = on })
		end })
		group:Keybind({ Title = "settings.toggle_key", Description = "settings.toggle_key_desc", Icon = "keyboard", Default = self.ToggleKey, Callback = function(key)
			if key then
				self:SetToggleKey(key)
			end
		end })
	end

	if not hide.HUD then
		local group = page:Group("settings.hud", { Id = "hud" })
		local snapshot = HUD.Snapshot()
		group:Toggle({ Title = "settings.hud_show", Description = "settings.hud_desc", Icon = "activity", Default = snapshot.Visible == true and HUD.Exists(), Callback = function(on)
			UI.HUD():SetVisible(on)
		end })
		group:Segmented({ Title = "hud.layout", Icon = "layout-grid", Options = {
			{ Text = "hud.layout_horizontal", Value = "Horizontal" }, { Text = "hud.layout_vertical", Value = "Vertical" },
			{ Text = "hud.layout_grid", Value = "Grid" }, { Text = "hud.layout_compact", Value = "Compact" },
		}, Default = snapshot.Layout, Width = 300, Callback = function(value)
			UI.HUD():SetLayout(value)
		end })
		group:Toggle({ Title = "hud.compact_mode", Icon = "minimize-2", Default = snapshot.Compact == true, Callback = function(on)
			UI.HUD():SetCompact(on)
		end })
		group:Slider({ Title = "hud.scale", Icon = "scaling", Min = 60, Max = 180, Step = 10, Default = math.floor((snapshot.Scale or 1) * 100 + 0.5), Suffix = "%", Callback = function(value)
			UI.HUD():SetScale(value / 100)
		end })
		group:Slider({ Title = "hud.opacity", Icon = "droplets", Min = 30, Max = 100, Step = 5, Default = math.floor((snapshot.Opacity or 1) * 100 + 0.5), Suffix = "%", Callback = function(value)
			UI.HUD():SetOpacity(value / 100)
		end })
	end

	if not hide.Config then
		page:ConfigGroup()
	end

	if not hide.Data then
		local group = page:Group("settings.data", { Id = "data", Collapsible = true, Collapsed = true })
		local info = Persistence.Describe()
		group:Label({ Title = "settings.storage", Icon = "hard-drive", Value = info.Available and "settings.storage_ok" or "error.storage_unavailable", ValueWidth = 190 })
		group:Label({ Title = "settings.data_folder", Description = Env.AbsoluteRoot, Icon = "folder", Value = info.Root, Mono = true, ValueWidth = 140 })
		group:Label({ Title = "settings.executor", Icon = "terminal", Value = Env.Describe().Executor, ValueWidth = 190 })
		group:Label({ Title = "settings.version", Icon = "info", Value = UI.Version, Mono = true, ValueWidth = 100 })
		group:Button({ Title = "settings.copy_path", Icon = "copy", ButtonText = "common.copy", Callback = function()
			if Env.Clipboard(Env.AbsoluteRoot) then
				UI.Notify({ Title = "common.copied", Message = Env.AbsoluteRoot, Kind = "success", Duration = 2 })
			else
				UI.Notify({ Title = "error.generic", Message = Env.AbsoluteRoot, Kind = "warn" })
			end
		end })
	end

	if not hide.Unload then
		local group = page:Group("settings.danger", { Id = "danger" })
		group:Button({ Title = "settings.unload", Description = "settings.unload_desc", Icon = "power", ButtonText = "settings.unload", Variant = "danger", Callback = function()
			task.spawn(function()
				if Dialog.Confirm({ Title = "settings.unload", Message = "settings.unload_confirm", Danger = true, Yes = "settings.unload" }) then
					UI.Destroy()
				end
			end)
		end })
	end

	if options.Extend then
		options.Extend(page)
	end
	return page
end

return true
end

Modules["UI/Tooltip"] = function(import)
local Create = import("UI/Create")
local Root = import("UI/Root")
local Loc = import("Localization")
local Input = import("Core/Input")
local Services = import("Core/Services")
local Anim = import("Animation")
local Util = import("Core/Util")

-- One shared tooltip. Text is resolved when it is shown, so it always follows the language.
-- Mouse: appears after a short hover. Touch: appears after a long press.
local Tooltip = {}

local frame, label
local token = 0

local function ensure()
	if frame and frame.Parent then
		return
	end
	frame = Create.New("Frame", {
		Name = "Tooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		ZIndex = 200,
		Bind = { BackgroundColor3 = "SurfaceRaised" },
		Parent = Root.Layer,
	})
	Create.Corner(frame, "sm")
	Create.Stroke(frame, "BorderStrong")
	Create.Pad(frame, 8, 5, 8, 5)
	label = Create.New("TextLabel", {
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		TextSize = 12,
		TextWrapped = true,
		ZIndex = 201,
		Parent = frame,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(260, 400)
	limit.Parent = label
end

function Tooltip.Hide()
	token = token + 1
	if frame then
		frame.Visible = false
	end
end

local function measure(text)
	local ok, size = pcall(function()
		return Services.TextService:GetTextSize(text, 12, Enum.Font.BuilderSansMedium, Vector2.new(260, 1000))
	end)
	return ok and size or Vector2.new(120, 16)
end

function Tooltip.Show(source, point, below)
	local text = Loc.Resolve(source)
	if text == "" or not Root.Ready then
		return
	end
	ensure()
	token = token + 1
	label.Text = text
	local size = measure(text) + Vector2.new(16, 10)
	local screen = Root.ScreenSize()
	local insets = Root.Insets()
	local position = Root.ToLocal(point)
	local x = Util.clamp(position.X + 12, insets.Left + 6, screen.X - insets.Right - size.X - 6)
	local y = below and (position.Y + 20) or (position.Y - size.Y - 10)
	if y < insets.Top + 6 then
		y = position.Y + 22
	end
	y = Util.clamp(y, insets.Top + 6, screen.Y - insets.Bottom - size.Y - 6)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Visible = true
end

-- Attach(gui, source) -> { Set(source), Disconnect() }
function Tooltip.Attach(gui, source)
	local handle = { Source = source }
	if source == nil or source == "" then
		return handle
	end
	local connections = {}
	local function add(link)
		connections[#connections + 1] = link
	end
	if not Input.Touch() then
		add(gui.MouseEnter:Connect(function()
			local mine = token + 1
			token = mine
			task.delay(0.45, function()
				if token == mine and handle.Source ~= nil and handle.Source ~= "" then
					Tooltip.Show(handle.Source, Services.UserInputService:GetMouseLocation(), true)
				end
			end)
		end))
		add(gui.MouseLeave:Connect(Tooltip.Hide))
	end
	add(gui.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local mine = token + 1
			token = mine
			local start = input.Position
			task.delay(0.5, function()
				if token == mine and input.UserInputState ~= Enum.UserInputState.End and (input.Position - start).Magnitude < 10 then
					Tooltip.Show(handle.Source, Input.Pointer(input), false)
					task.delay(1.8, function()
						if token == mine + 1 then
							Tooltip.Hide()
						end
					end)
				end
			end)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			Tooltip.Hide()
		end
	end))
	function handle.Set(newSource)
		handle.Source = newSource
	end
	function handle.Disconnect()
		for _, link in ipairs(connections) do
			link:Disconnect()
		end
		connections = {}
	end
	handle.Clean = handle.Disconnect
	return handle
end

function Tooltip.Destroy()
	if frame then
		frame:Destroy()
		frame, label = nil, nil
	end
end

return Tooltip
end

Modules["UI/Widgets"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Signal = import("Core/Signal")
local Util = import("Core/Util")

-- Small standalone components: EmptyState, LoadingIndicator, SearchBar, Timer, QueueList.
local Widgets = {}

local function holder(parent, o, name)
	return Create.New("Frame", {
		Name = name,
		Size = o.Size or UDim2.new(1, 0, 0, o.Height or 0),
		AutomaticSize = o.Height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		LayoutOrder = o.Order or 0,
		Visible = o.Visible,
		Parent = parent,
	})
end

-- EmptyState -------------------------------------------------------------------------------------------------
local Empty = Kit.Class()

function Empty:Set(o)
	if o.Icon then
		Kit.SetIcon(self.IconImage, o.Icon)
	end
	if o.Title ~= nil then
		Kit.SetText(self.TitleLabel, o.Title)
	end
	if o.Message ~= nil then
		Kit.SetText(self.MessageLabel, o.Message)
		self.MessageLabel.Visible = o.Message ~= ""
	end
	if o.Action ~= nil then
		self:SetAction(o.Action)
	end
end

function Empty:SetAction(action)
	if self.ActionButton then
		self.ActionButton:Destroy()
		self.ActionButton = nil
	end
	if action then
		self.ActionButton = Kit.Button(self.Frame, { Text = action.Text, Icon = action.Icon, Variant = action.Variant or "soft", Callback = action.Callback, Order = 10 })
	end
end

function Widgets.EmptyState(parent, o)
	o = o or {}
	local frame = holder(parent, o, "EmptyState")
	Create.Pad(frame, 16, 20, 16, 20)
	Create.List(frame, { Padding = 8, HAlign = "Center" })
	local well = Create.New("Frame", { Name = "Well", Size = UDim2.fromOffset(52, 52), LayoutOrder = 1, Bind = { BackgroundColor3 = "SurfaceRaised" }, Parent = frame })
	Create.Corner(well, "pill")
	local icon = Kit.Icon(well, o.Icon or "inbox", 24, "TextFaint", { Position = UDim2.new(0.5, -12, 0.5, -12) })
	local title = Kit.Text(frame, { Text = o.Title or "empty.title", Size = 14, Weight = "Bold", Align = "Center", Wrap = true, Auto = "Y", Order = 2 })
	local message = Kit.Text(frame, { Text = o.Message or "empty.message", Size = 12, Color = "TextMuted", Align = "Center", Wrap = true, Auto = "Y", Order = 3 })
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(340, math.huge)
	limit.Parent = message
	local object = Kit.New(Empty, frame, { IconImage = icon, TitleLabel = title, MessageLabel = message })
	message.Visible = o.Message ~= ""
	object:SetAction(o.Action)
	return object
end

-- LoadingIndicator ---------------------------------------------------------------------------------------------
local Loading = Kit.Class()

function Loading:SetText(source)
	Kit.SetText(self.Label, source)
	self.Label.Visible = source ~= nil and source ~= ""
end

local function sweep(object)
	if object.Destroyed or not object.Segment or not Anim.Enabled() then
		return
	end
	object.Segment.Position = UDim2.new(-0.4, 0, 0, 0)
	Anim.Tween(object.Segment, { Position = UDim2.new(1, 0, 0, 0) }, { Duration = 1.1, Raw = true, Style = Enum.EasingStyle.Linear, OnComplete = function()
		sweep(object)
	end })
end

-- o: Style ("Spinner" | "Bar"), Text, Size
function Widgets.LoadingIndicator(parent, o)
	o = o or {}
	local frame = holder(parent, { Height = nil, Order = o.Order, Visible = o.Visible }, "Loading")
	local object = Kit.New(Loading, frame, {})
	if string.lower(o.Style or "spinner") == "bar" then
		Create.List(frame, { Padding = 6 })
		local track = Create.New("Frame", { Name = "Track", Size = UDim2.new(1, 0, 0, 4), ClipsDescendants = true, LayoutOrder = 1, Bind = { BackgroundColor3 = "SurfacePressed" }, Parent = frame })
		Create.Corner(track, "pill")
		object.Segment = Create.New("Frame", { Name = "Segment", Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(-0.4, 0, 0, 0), Bind = { BackgroundColor3 = "Primary" }, Parent = track })
		Create.Corner(object.Segment, "pill")
		object.Label = Kit.Text(frame, { Text = o.Text, Size = 12, Color = "TextMuted", Order = 2 })
		sweep(object)
	else
		Create.List(frame, { Dir = "H", Padding = 8, VAlign = "Center", HAlign = "Center" })
		Create.Pad(frame, 8)
		Kit.Spinner(frame, o.Size or 18, "Primary", { Order = 1 })
		object.Label = Kit.Text(frame, { Text = o.Text or "common.loading", Size = 12, Color = "TextMuted", Auto = "X", Order = 2 })
	end
	object.Label.Visible = o.Text ~= "" and (o.Text ~= nil or o.Style == nil or string.lower(o.Style) ~= "bar")
	return object
end

-- SearchBar ----------------------------------------------------------------------------------------------------
local Search = Kit.Class()

function Search:Get()
	return self.Field.Box.Text
end

function Search:Set(text)
	self.Field.Box.Text = tostring(text or "")
end

function Search:Focus()
	self.Field.Box:CaptureFocus()
end

function Search:Clear()
	self.Field.Box.Text = ""
end

-- o: Placeholder, Debounce, OnChanged(text), OnSubmit(text), Text, Height
function Widgets.SearchBar(parent, o)
	o = o or {}
	local object
	local notify = Util.Debounce(o.Debounce or 0.15, function()
		if object and not object.Destroyed then
			object.Changed:Fire(object:Get())
			if o.OnChanged then
				Kit.Safe(o.OnChanged)(object:Get())
			end
		end
	end)
	local field = Kit.Field(parent, {
		Placeholder = o.Placeholder or "common.search_placeholder",
		Icon = "search",
		Clear = true,
		Text = o.Text,
		Height = o.Height,
		Order = o.Order,
		SizeUDim = o.Size,
		OnChanged = notify,
		OnSubmit = function(text, enter)
			if enter and o.OnSubmit then
				Kit.Safe(o.OnSubmit)(text)
			end
		end,
	})
	object = Kit.New(Search, field.Frame, { Field = field })
	object.Changed = Signal.new()
	return object
end

-- Timer ---------------------------------------------------------------------------------------------------------
local TimerClass = Kit.Class()

function TimerClass:Get()
	if self.Running then
		local remaining = self.Target - os.clock()
		return self.Mode == "Down" and math.max(0, remaining) or (self.Duration or 0) - math.max(0, remaining)
	end
	return self.Value
end

function TimerClass:Render()
	local value = self:Get()
	self.TimeLabel.Text = Util.Format.Time(value, self.Style)
	Loc.Unbind(self.TimeLabel, "Text")
	if self.Bar and self.Duration and self.Duration > 0 then
		local fraction = self.Mode == "Down" and (1 - value / self.Duration) or (value / self.Duration)
		self.Bar.Size = UDim2.fromScale(Util.clamp(fraction, 0, 1), 1)
	end
end

function TimerClass:Start(seconds)
	if seconds then
		self.Duration = seconds
	end
	self.Value = self.Mode == "Down" and (self.Duration or 0) or 0
	self.Target = os.clock() + (self.Duration or 0)
	if self.Mode == "Up" and not self.Duration then
		self.Target = os.clock()
		self.Started = os.clock()
	end
	self.Running, self.Finished = true, false
	self:Render()
end

function TimerClass:Pause()
	if self.Running then
		self.Value = self:Get()
		self.Running = false
		self:Render()
	end
end

function TimerClass:Resume()
	if not self.Running and not self.Finished then
		local remaining = self.Mode == "Down" and self.Value or ((self.Duration or 0) - self.Value)
		self.Target = os.clock() + remaining
		self.Running = true
	end
end

function TimerClass:Reset()
	self.Running, self.Finished = false, false
	self.Value = self.Mode == "Down" and (self.Duration or 0) or 0
	self:Render()
end

function TimerClass:Set(seconds)
	self.Duration = seconds
	self:Reset()
end

function TimerClass:IsRunning()
	return self.Running
end

-- o: Title, Mode ("Down" | "Up"), Duration, Style ("clock" | "words"), AutoStart, ShowBar, OnFinished
function Widgets.Timer(parent, o)
	o = o or {}
	local frame = Kit.Panel(parent, { Name = "Timer", Size = UDim2.new(1, 0, 0, 0), AutoY = true, Order = o.Order, Visible = o.Visible })
	Create.Pad(frame, 14, 12, 14, 12)
	Create.List(frame, { Padding = 4 })
	local title = Kit.Text(frame, { Text = o.Title, Size = 12, Color = "TextMuted", Order = 1 })
	title.Visible = o.Title ~= nil
	local object = Kit.New(TimerClass, frame, { Mode = o.Mode == "Up" and "Up" or "Down", Duration = o.Duration, Style = o.Style or "clock", Value = 0, Running = false, Finished = false, OnFinished = Kit.Safe(o.OnFinished) })
	object.Finished = false
	object.Changed = Signal.new()
	object.TimeLabel = Kit.Text(frame, { Size = 22, Weight = "Bold", Mono = true, Order = 2 })
	if o.ShowBar ~= false and o.Duration then
		local track = Create.New("Frame", { Name = "Track", Size = UDim2.new(1, 0, 0, 4), LayoutOrder = 3, Bind = { BackgroundColor3 = "SurfacePressed" }, Parent = frame })
		Create.Corner(track, "pill")
		object.Bar = Create.New("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), Bind = { BackgroundColor3 = "Accent" }, Parent = track })
		Create.Corner(object.Bar, "pill")
	end
	object.Scope:Add(Kit.Tick(function()
		if object.Running then
			object:Render()
			if object.Mode == "Down" and os.clock() >= object.Target then
				object.Running, object.Finished = false, true
				object.Value = 0
				object:Render()
				object.Changed:Fire(0)
				if object.OnFinished then
					object.OnFinished(object)
				end
			end
		end
	end))
	object.Value = object.Mode == "Down" and (o.Duration or 0) or 0
	object:Render()
	if o.AutoStart then
		object:Start()
	end
	return object
end

-- QueueList -----------------------------------------------------------------------------------------------------
local Queue = Kit.Class()

local STATUS = {
	queued = { "clock", "TextMuted" },
	active = { "loader-2", "Primary" },
	done = { "check-circle", "Success" },
	failed = { "x-circle", "Danger" },
}

function Queue:Count()
	return #self.Order
end

function Queue:_find(id)
	for index, entry in ipairs(self.Order) do
		if entry.Id == id then
			return entry, index
		end
	end
	return nil
end

function Queue:_refresh()
	for index, entry in ipairs(self.Order) do
		entry.Row.LayoutOrder = index
	end
	self.Empty.Visible = #self.Order == 0
	self.CountLabel.Text = tostring(#self.Order)
end

function Queue:Add(item)
	self.Next = self.Next + 1
	local id = item.Id or ("queue" .. self.Next)
	local control = self
	local row = Create.New("Frame", { Name = "Item", Size = UDim2.new(1, 0, 0, Kit.Control() + 8), Bind = { BackgroundColor3 = "SurfaceRaised" }, Parent = self.Scroll })
	Create.Corner(row, "sm")
	local entry = { Id = id, Row = row, Data = Util.clone(item) }
	entry.StatusIcon = Kit.Icon(row, "clock", 16, "TextMuted", { Position = UDim2.new(0, 10, 0.5, -8) })
	entry.Text = Kit.Text(row, { Text = item.Text, Size = 13, Weight = "Medium", Position = UDim2.fromOffset(34, 6), SizeUDim = UDim2.new(1, -112, 0, 18) })
	entry.Detail = Kit.Text(row, { Text = item.Detail, Size = 11, Color = "TextMuted", Position = UDim2.fromOffset(34, 24), SizeUDim = UDim2.new(1, -112, 0, 14) })
	entry.Bar = Create.New("Frame", { Size = UDim2.new(1, -112, 0, 3), Position = UDim2.new(0, 34, 1, -6), Visible = false, Bind = { BackgroundColor3 = "SurfacePressed" }, Parent = row })
	entry.Fill = Create.New("Frame", { Size = UDim2.fromScale(0, 1), Bind = { BackgroundColor3 = "Accent" }, Parent = entry.Bar })
	local remove = Create.New("TextButton", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0.5, -14), Text = "", Parent = row })
	Kit.Icon(remove, "x", 14, "TextMuted", { Position = UDim2.new(0.5, -7, 0.5, -7) })
	remove.Activated:Connect(function()
		local removed = control:Remove(id)
		if removed and control.OnRemove then
			control.OnRemove(id, entry.Data)
		end
	end)
	table.insert(self.Order, entry)
	self:Update(id, item)
	self:_refresh()
	return id
end

function Queue:Update(id, patch)
	local entry = self:_find(id)
	if not entry then
		return false
	end
	for key, value in pairs(patch) do
		entry.Data[key] = value
	end
	if patch.Text ~= nil then
		Kit.SetText(entry.Text, patch.Text)
	end
	if patch.Detail ~= nil then
		Kit.SetText(entry.Detail, patch.Detail)
	end
	local status = STATUS[string.lower(tostring(entry.Data.Status or "queued"))] or STATUS.queued
	Kit.SetIcon(entry.StatusIcon, entry.Data.Icon or status[1])
	Theme.Bind(entry.StatusIcon, "ImageColor3", status[2])
	local progress = entry.Data.Progress
	entry.Bar.Visible = type(progress) == "number"
	if type(progress) == "number" then
		Anim.Tween(entry.Fill, { Size = UDim2.fromScale(Util.clamp(progress, 0, 1), 1) }, "fast")
	end
	return true
end

function Queue:Get(id)
	local entry = self:_find(id)
	return entry and Util.clone(entry.Data) or nil
end

function Queue:Remove(id)
	local entry, index = self:_find(id)
	if not entry then
		return false
	end
	table.remove(self.Order, index)
	entry.Row:Destroy()
	self:_refresh()
	return true
end

function Queue:Move(id, position)
	local entry, index = self:_find(id)
	if not entry then
		return false
	end
	table.remove(self.Order, index)
	table.insert(self.Order, Util.clamp(position, 1, #self.Order + 1), entry)
	self:_refresh()
	return true
end

function Queue:Clear()
	for _, entry in ipairs(self.Order) do
		entry.Row:Destroy()
	end
	self.Order = {}
	self:_refresh()
end

-- o: Title, Height, Empty (text), OnRemove(id, data), Items
function Widgets.QueueList(parent, o)
	o = o or {}
	local frame = Kit.Panel(parent, { Name = "QueueList", Size = UDim2.new(1, 0, 0, 0), AutoY = true, Order = o.Order, Visible = o.Visible })
	Create.List(frame, { Padding = 0 })
	local header = Create.New("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, Parent = frame })
	Create.Pad(header, 14, 0, 10, 0)
	Kit.Text(header, { Text = o.Title or "queue.title", Size = 13, Weight = "Bold", SizeUDim = UDim2.new(1, -120, 1, 0) })
	local count = Kit.Text(header, { Size = 12, Mono = true, Color = "TextMuted", Align = "Right", Position = UDim2.new(1, -118, 0, 0), SizeUDim = UDim2.new(0, 30, 1, 0) })
	local object = Kit.New(Queue, frame, { Order = {}, Next = 0, CountLabel = count, OnRemove = o.OnRemove })
	local clear = Kit.Button(header, { Text = "queue.clear", Icon = "trash-2", Variant = "ghost", Compact = true, Height = 28, Position = UDim2.new(1, -78, 0.5, -14), Base = "Surface", Callback = function()
		object:Clear()
	end })
	clear.Frame.AnchorPoint = Vector2.new(0, 0)
	clear.Frame.Position = UDim2.new(1, -86, 0.5, -14)
	object.Scope:Add(clear)
	local body = Create.New("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, o.Height or 200), LayoutOrder = 2, Parent = frame })
	object.Scroll = Kit.Scroll(body, { Size = UDim2.fromScale(1, 1) })
	Create.Pad(object.Scroll, 10, 0, 10, 10)
	Create.List(object.Scroll, { Padding = 6 })
	object.Empty = Kit.Text(body, { Text = o.Empty or "queue.empty", Size = 12, Color = "TextMuted", Align = "Center", SizeUDim = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 40) })
	for _, item in ipairs(o.Items or {}) do
		object:Add(item)
	end
	object:_refresh()
	return object
end

return Widgets
end

Modules["UI/Window"] = function(import)
local Create = import("UI/Create")
local Theme = import("Theme/Theme")
local Anim = import("Animation")
local Loc = import("Localization")
local Kit = import("UI/Kit")
local Root = import("UI/Root")
local Drag = import("UI/Drag")
local Layout = import("UI/Layout")
local Keys = import("UI/Keybinds")
local Input = import("Core/Input")
local Signal = import("Core/Signal")
local Util = import("Core/Util")
local Services = import("Core/Services")
local Tooltip = import("UI/Tooltip")
local Popup = import("UI/Popup")

--[[
	Window: custom title bar (drag, search, minimize, close), sidebar navigation (icons + labels, categories,
	badges, collapses to icons on narrow windows, becomes a slide-in drawer on phones), animated page
	switching, resize handle, floating launcher button for touch, persistent position / size / page.

	show / hide / minimize run through a small state machine with a token: a new request cancels the
	previous animation and continues from the current values, so rapid toggling never gets stuck, and an
	input blocker keeps the window inert while it animates.
]]
local Window = Kit.Class()
local WindowModule = { Class = Window }

local SIDE_W, SIDE_COLLAPSED = 196, 58
local MARGIN = 6

-- Navigation item -------------------------------------------------------------------------------------------------
local function navItem(window, page)
	local height = Kit.Control() + 6
	local button = Create.New("TextButton", { Name = "Nav", Size = UDim2.new(1, 0, 0, height), Text = "", BackgroundTransparency = 1, Bind = { BackgroundColor3 = "PrimarySoft" }, Parent = window.NavList })
	Create.Corner(button, "sm")
	local bar = Create.New("Frame", { Name = "Bar", Size = UDim2.fromOffset(3, 18), Position = UDim2.new(0, 0, 0.5, -9), Visible = false, Bind = { BackgroundColor3 = "Primary" }, Parent = button })
	Create.Corner(bar, "pill")
	local icon = Kit.Icon(button, page.Icon, 18, "TextMuted", { Position = UDim2.new(0, 14, 0.5, -9) })
	local label = Kit.Text(button, { Text = page.Text, Size = 13, Weight = "Medium", Color = "TextMuted", Position = UDim2.fromOffset(42, 0), SizeUDim = UDim2.new(1, -86, 1, 0) })
	local badge = Kit.Badge(button, { Text = "", Kind = "primary", Height = 18, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0) })
	badge.Frame.Visible = false
	local nav = { Frame = button, Page = page, Selected = false, Hover = false, Badge = badge, Label = label, Icon = icon }
	local tip
	function nav:Refresh()
		local fg = self.Selected and "Primary" or (self.Hover and "Text" or "TextMuted")
		Anim.Token(label, "TextColor3", fg, "fast")
		Anim.Token(icon, "ImageColor3", fg, "fast")
		bar.Visible = self.Selected
		if self.Selected then
			Theme.Bind(button, "BackgroundColor3", "PrimarySoft", true)
			Anim.Tween(button, { BackgroundColor3 = Theme.Token("PrimarySoft"), BackgroundTransparency = 0 }, "fast")
		elseif self.Hover then
			Theme.Bind(button, "BackgroundColor3", "SurfaceHover", true)
			Anim.Tween(button, { BackgroundColor3 = Theme.Token("SurfaceHover"), BackgroundTransparency = 0.4 }, "fast")
		else
			Anim.Tween(button, { BackgroundTransparency = 1 }, "fast")
		end
	end
	function nav:SetSelected(selected)
		self.Selected = selected
		self:Refresh()
	end
	function nav:SetText(source)
		Kit.SetText(label, source)
		tip.Set(window.SidebarCollapsed and source or nil)
	end
	function nav:SetIcon(name)
		Kit.SetIcon(icon, name)
	end
	function nav:SetBadge(text, kind)
		badge.Frame.Visible = text ~= nil and text ~= ""
		badge:Set(text, kind or "primary")
	end
	function nav:SetCollapsed(collapsed)
		label.Visible = not collapsed
		icon.Position = collapsed and UDim2.new(0.5, -9, 0.5, -9) or UDim2.new(0, 14, 0.5, -9)
		badge.Frame.AnchorPoint = collapsed and Vector2.new(1, 0) or Vector2.new(1, 0.5)
		badge.Frame.Position = collapsed and UDim2.new(1, -4, 0, 4) or UDim2.new(1, -8, 0.5, 0)
		tip.Set(collapsed and page.Text or nil)
	end
	-- tooltip is attached lazily: it needs a source, so re-attach when collapsed
	tip = Tooltip.Attach(button, function()
		return window.SidebarCollapsed and Loc.Resolve(page.Text) or ""
	end)
	Kit.Pressable(button, function(state)
		nav.Hover = state.Hover
		nav:Refresh()
	end)
	button.Activated:Connect(function()
		window:SelectPage(page.Id)
		if window.Compact then
			window:CloseDrawer()
		end
	end)
	return nav
end

-- Public API of a window ------------------------------------------------------------------------------------------------
-- spec: Id, Text (nav label), Icon, Title (page heading), Subtitle, Order
function Window:AddPage(spec)
	spec = spec or {}
	local id = spec.Id or ("page" .. (#self.PageList + 1))
	if self.Pages[id] then
		return self.Pages[id]
	end
	spec.Id = id
	spec.Text = spec.Text or spec.Name or id
	local page = Layout.NewPage(self, spec)
	Kit.Adopt(self, page)
	page.Nav = navItem(self, page)
	page.Nav.Frame.LayoutOrder = #self.NavOrder + 1
	table.insert(self.NavOrder, page.Nav.Frame)
	page.Nav:SetCollapsed(self.SidebarCollapsed == true)
	self.Pages[id] = page
	table.insert(self.PageList, page)
	if not self.Current then
		local wanted = self.SavedPage
		if wanted == nil or wanted == id or spec.Default then
			self:SelectPage(id, true)
		end
	elseif self.SavedPage == id then
		self:SelectPage(id, true)
	end
	return page
end

-- Hub compatibility: hub:AddPage({ Id, Text, Icon, Title })
function Window:AddCategory(text)
	local holder = Create.New("Frame", { Name = "Category", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = #self.NavOrder + 1, Parent = self.NavList })
	local label = Kit.Text(holder, { Text = text, Size = 10, Weight = "Bold", Color = "TextFaint", Position = UDim2.fromOffset(12, 8), SizeUDim = UDim2.new(1, -24, 0, 18), Transform = Loc.Upper })
	local line = Kit.Divider(holder, { Transparency = 0.2 })
	line.Position = UDim2.new(0, 14, 0.5, 0)
	line.Size = UDim2.new(1, -28, 0, 1)
	line.Visible = false
	table.insert(self.NavOrder, holder)
	table.insert(self.Categories, { Label = label, Line = line })
	for _, entry in ipairs(self.Categories) do
		entry.Label.Visible = not self.SidebarCollapsed
		entry.Line.Visible = self.SidebarCollapsed == true
	end
	return holder
end

-- Title bar action button: window:AddAction({ Icon, Tooltip, Callback }) -> button (Destroy() removes it)
function Window:AddAction(options)
	options = options or {}
	local button = Kit.Button(self.ActionRow, {
		Icon = options.Icon or "star", Variant = "ghost", Base = "Sidebar", Width = Kit.Control(), Order = options.Order or 0,
		Tooltip = options.Tooltip, Callback = options.Callback,
	})
	button.Frame.ZIndex = 8
	self.Scope:Add(button)
	return button
end

-- Selects the n-th visible page (1 = first).
function Window:SelectIndex(index)
	local count = 0
	for _, page in ipairs(self.PageList) do
		if not page.Hidden then
			count = count + 1
			if count == index then
				self:SelectPage(page.Id)
				return page
			end
		end
	end
	return nil
end

function Window:GetPage(id)
	return self.Pages[id]
end

function Window:SelectFirst()
	for _, page in ipairs(self.PageList) do
		if not page.Hidden then
			self:SelectPage(page.Id)
			return
		end
	end
end

function Window:SelectPage(id, instant)
	local page = self.Pages[id]
	if not page or page == self.Current then
		return page
	end
	self.SwitchToken = self.SwitchToken + 1
	local token = self.SwitchToken
	local previous = self.Current
	self.Current = page
	for _, other in ipairs(self.PageList) do
		other.Nav:SetSelected(other == page)
	end
	Kit.SetText(self.Subtitle, page.Text)
	local function settle()
		for _, other in ipairs(self.PageList) do
			other.Scroll.Visible = other == page
		end
	end
	if instant or not previous or self.State ~= "shown" or not Anim.Enabled() then
		settle()
		page.Scroll.Position = UDim2.fromOffset(0, 0)
		self.PageHost.GroupTransparency = 0
	else
		Anim.Tween(self.PageHost, { GroupTransparency = 1 }, { Duration = "fast", OnComplete = function()
			if token ~= self.SwitchToken then
				return
			end
			settle()
			page.Scroll.Position = UDim2.fromOffset(0, 10)
			Anim.Tween(self.PageHost, { GroupTransparency = 0 }, "fast")
			Anim.Tween(page.Scroll, { Position = UDim2.fromOffset(0, 0) }, "base")
		end })
	end
	self:_closeSearch()
	self:_saveLayout()
	self.PageChanged:Fire(page)
	return page
end
Window.Select = Window.SelectPage

function Window:_pageDestroyed(page)
	if self.Destroyed then
		return
	end
	self.Pages[page.Id] = nil
	for index, other in ipairs(self.PageList) do
		if other == page then
			table.remove(self.PageList, index)
			break
		end
	end
	if page.Nav then
		page.Nav.Frame:Destroy()
	end
	for _, entry in ipairs(self.Search) do
		if entry.Page == page then
			entry.Removed = true
		end
	end
	if self.Current == page then
		self.Current = nil
		self:SelectFirst()
	end
end

function Window:RemovePage(id)
	local page = self.Pages[id]
	if page then
		page:Destroy()
	end
end

-- order: list of page ids
function Window:SetPageOrder(order)
	for index, id in ipairs(order) do
		local page = self.Pages[id]
		if page then
			page.Nav.Frame.LayoutOrder = index
		end
	end
end

-- Search registry --------------------------------------------------------------------------------------------------------
function Window:_addSearch(entry)
	table.insert(self.Search, entry)
	return entry
end

local function resolve(source)
	return source ~= nil and Loc.Resolve(source) or ""
end

function Window:_runSearch(query)
	for _, child in ipairs(self.ResultList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local needle = Util.Fold(Util.trim(query))
	local shown = 0
	if needle ~= "" then
		for _, entry in ipairs(self.Search) do
			if not entry.Removed and entry.Frame and entry.Frame.Parent then
				local title, desc = resolve(entry.Row.TitleSource), resolve(entry.Row.DescSource)
				if string.find(Util.Fold(title .. " " .. desc), needle, 1, true) then
					shown = shown + 1
					if shown > 40 then
						break
					end
					local row = Create.New("TextButton", { Name = "Result", Size = UDim2.new(1, 0, 0, 48), Text = "", LayoutOrder = shown, Bind = { BackgroundColor3 = "SurfaceHover" }, Parent = self.ResultList })
					row.BackgroundTransparency = 1
					Create.Corner(row, "sm")
					Kit.Icon(row, entry.Page and entry.Page.Icon or "search", 16, "Primary", { Position = UDim2.new(0, 10, 0.5, -8) })
					Kit.Text(row, { Text = entry.Row.TitleSource, Size = 13, Weight = "Medium", Position = UDim2.fromOffset(36, 6), SizeUDim = UDim2.new(1, -46, 0, 18) })
					local path = Kit.Text(row, { Size = 11, Color = "TextMuted", Position = UDim2.fromOffset(36, 25), SizeUDim = UDim2.new(1, -46, 0, 16) })
					local function crumbs()
						local group = entry.Group and entry.Group.TitleLabel and entry.Group.TitleLabel.Text or ""
						path.Text = Loc.Resolve(entry.Page.Text) .. (group ~= "" and (" › " .. group) or "")
					end
					crumbs()
					Kit.Pressable(row, function(state)
						row.BackgroundTransparency = (state.Hover or state.Down) and 0.4 or 1
					end)
					row.Activated:Connect(function()
						self:_closeSearch()
						entry.Page:Select()
						task.delay(0.2, function()
							if entry.Frame.Parent then
								entry.Page:ScrollTo(entry.Frame)
								entry.Page:Flash(entry.Frame)
							end
						end)
					end)
				end
			end
		end
	end
	self.SearchEmpty.Visible = shown == 0
	Kit.SetText(self.SearchEmptyText, needle == "" and "window.search_hint" or "empty.search_message")
end

function Window:_openSearch()
	if self.SearchOpen or self.State == "minimized" then
		return
	end
	self.SearchOpen = true
	self.SearchPanel.Visible = true
	self.SearchBar:Clear()
	self:_runSearch("")
	task.defer(function()
		if self.SearchOpen then
			self.SearchBar:Focus()
		end
	end)
end

function Window:_closeSearch()
	if not self.SearchOpen then
		return
	end
	self.SearchOpen = false
	self.SearchPanel.Visible = false
end

-- Layout persistence -----------------------------------------------------------------------------------------------------
function Window:_saveLayout()
	if self.Restoring or not self.UI.LayoutDoc then
		return
	end
	self.SaveSoon()
end

function Window:_isCollapsed(key)
	local map = self.UI.LayoutDoc and self.UI.LayoutDoc.Data.Collapsed
	if type(map) == "table" then
		return map[key]
	end
	return nil
end

function Window:_saveCollapsed(key, collapsed)
	local doc = self.UI.LayoutDoc
	if doc then
		local map = doc.Data.Collapsed
		if type(map) ~= "table" then
			map = {}
			doc.Data.Collapsed = map
		end
		map[key] = collapsed or nil
		doc:Save()
	end
end

-- Responsive layout ----------------------------------------------------------------------------------------------------------
function Window:_titleHeight()
	return Kit.Control() + 16
end

function Window:_applyLayout(animate)
	local metrics = Root.Metrics()
	local insets = metrics.Insets
	local compact = metrics.Compact
	local changedMode = compact ~= self.Compact
	self.Compact = compact
	local titleHeight = self:_titleHeight()
	local safeW, safeH = metrics.Safe.X, metrics.Safe.Y
	local size, position
	if compact then
		size = Vector2.new(safeW - MARGIN * 2, safeH - MARGIN * 2)
		position = Vector2.new(insets.Left + MARGIN, insets.Top + MARGIN)
	else
		size = Vector2.new(Util.clamp(self.Size.X, self.MinSize.X, math.max(self.MinSize.X, safeW - MARGIN * 2)), Util.clamp(self.Size.Y, self.MinSize.Y, math.max(self.MinSize.Y, safeH - MARGIN * 2)))
		position = Drag.Fit(self.Position, size, MARGIN)
		self.Position = position
	end
	self.ShownSize = size
	local height = self.State == "minimized" and titleHeight or size.Y
	local target = { Size = UDim2.fromOffset(size.X, height), Position = UDim2.fromOffset(position.X, position.Y) }
	if animate then
		Anim.Tween(self.Frame, target, "base")
	else
		Anim.Cancel(self.Frame)
		self.Frame.Size, self.Frame.Position = target.Size, target.Position
	end
	-- sidebar mode
	local collapsed = (not compact) and size.X < 560
	self.SidebarCollapsed = collapsed
	local sideWidth = compact and 0 or (collapsed and SIDE_COLLAPSED or SIDE_W)
	self.Sidebar.Visible = not compact
	self.Sidebar.Size = UDim2.new(0, sideWidth, 1, -titleHeight)
	self.Content.Position = UDim2.new(0, sideWidth, 0, titleHeight)
	self.Content.Size = UDim2.new(1, -sideWidth, 1, -titleHeight)
	self.FooterFrame.Visible = not collapsed and not compact
	for _, page in ipairs(self.PageList) do
		page.Nav:SetCollapsed(collapsed)
	end
	for _, entry in ipairs(self.Categories) do
		entry.Label.Visible = not collapsed
		entry.Line.Visible = collapsed
	end
	self.MenuButton.Frame.Visible = compact
	self.ResizeHandle.Visible = not compact and self.Resizable and self.State ~= "minimized"
	self.MinimizeButton.Frame.Visible = not compact
	if changedMode and not compact then
		self:CloseDrawer(true)
	end
	self.TitleBar.Size = UDim2.new(1, 0, 0, titleHeight)
end

function Window:OpenDrawer()
	if not self.Compact or self.DrawerOpen then
		return
	end
	self.DrawerOpen = true
	self.Scrim.Visible = true
	self.Drawer.Visible = true
	Anim.Tween(self.Scrim, { BackgroundTransparency = 0.45 }, "fast")
	Anim.Tween(self.Drawer, { Position = UDim2.new(0, 0, 0, self:_titleHeight()) }, "base")
end

function Window:CloseDrawer(instant)
	if not self.DrawerOpen then
		return
	end
	self.DrawerOpen = false
	local function done()
		if not self.DrawerOpen then
			self.Scrim.Visible = false
			self.Drawer.Visible = false
		end
	end
	if instant or not Anim.Enabled() then
		self.Drawer.Position = UDim2.new(0, -250, 0, self:_titleHeight())
		self.Scrim.BackgroundTransparency = 1
		done()
	else
		Anim.Tween(self.Scrim, { BackgroundTransparency = 1 }, "fast")
		Anim.Tween(self.Drawer, { Position = UDim2.new(0, -250, 0, self:_titleHeight()) }, { Duration = "base", OnComplete = done })
	end
end

-- Visibility state machine ---------------------------------------------------------------------------------------------------------
function Window:IsVisible()
	return self.State == "shown" or self.State == "showing" or self.State == "minimized"
end

function Window:Show(instant)
	if self.Destroyed or self.State == "shown" or self.State == "showing" or self.State == "minimized" then
		return
	end
	self.Token = self.Token + 1
	local token = self.Token
	self.State = "showing"
	self:_applyLayout(false)
	self.Frame.Visible = true
	self.Blocker.Visible = true
	local function done()
		if token == self.Token then
			self.State = "shown"
			self.Blocker.Visible = false
			self.Shown:Fire()
			if self.PendingMinimize then
				self.PendingMinimize = false
				self:Minimize()
			end
		end
	end
	if instant or not Anim.Enabled() then
		self.Body.GroupTransparency = 0
		self.PopScale.Scale = 1
		done()
	else
		Anim.Tween(self.PopScale, { Scale = 1 }, "base")
		Anim.Tween(self.Body, { GroupTransparency = 0 }, { Duration = "base", OnComplete = done })
	end
end

function Window:Hide(instant)
	if self.Destroyed or self.State == "hidden" or self.State == "hiding" then
		return
	end
	self.Token = self.Token + 1
	local token = self.Token
	self.State = "hiding"
	Popup.Close(true)
	Tooltip.Hide()
	self:_closeSearch()
	self:CloseDrawer(true)
	self.Blocker.Visible = true
	local function done()
		if token == self.Token then
			self.State = "hidden"
			self.Frame.Visible = false
			self.Blocker.Visible = false
			self.Hidden:Fire()
		end
	end
	if instant or not Anim.Enabled() then
		self.Body.GroupTransparency = 1
		self.PopScale.Scale = 0.95
		done()
	else
		Anim.Tween(self.PopScale, { Scale = 0.95 }, "fast")
		Anim.Tween(self.Body, { GroupTransparency = 1 }, { Duration = "fast", OnComplete = done })
	end
end

function Window:Toggle()
	if self.State == "hidden" or self.State == "hiding" then
		self:Show()
	else
		self:Hide()
	end
end

-- Close: hides the window (the toggle key / launcher button opens it again). Destroys it when CloseDestroys is set.
function Window:Close()
	if self.CloseDestroys then
		self:Destroy()
		return
	end
	self:Hide()
	if not self.HintShown then
		self.HintShown = true
		local key = self.ToggleKey and Keys.Name(self.ToggleKey) or nil
		if key and not Input.Touch() then
			self.UI.Notify({ Title = "window.hidden_title", Message = Loc.Resolve("window.toggle_hint", key), Kind = "info", Duration = 3 })
		end
	end
end

function Window:Minimize()
	if self.State ~= "shown" then
		return
	end
	self.State = "minimized"
	Popup.Close(true)
	self:_closeSearch()
	self.Content.Visible = false
	self.Sidebar.Visible = false
	self.ResizeHandle.Visible = false
	Anim.Tween(self.Frame, { Size = UDim2.fromOffset(self.ShownSize.X, self:_titleHeight()) }, "base")
	Kit.SetIcon(self.MinimizeIcon, "maximize-2")
	self:_saveLayout()
end

function Window:Restore()
	if self.State ~= "minimized" then
		return
	end
	self.State = "shown"
	Anim.Tween(self.Frame, { Size = UDim2.fromOffset(self.ShownSize.X, self.ShownSize.Y) }, { Duration = "base", OnComplete = function()
		if self.State == "shown" then
			self.Content.Visible = true
			self.Sidebar.Visible = not self.Compact
			self.ResizeHandle.Visible = not self.Compact and self.Resizable
		end
	end })
	self.Content.Visible = true
	self.Sidebar.Visible = not self.Compact
	Kit.SetIcon(self.MinimizeIcon, "minus")
	self:_saveLayout()
end

function Window:ToggleMinimize()
	if self.State == "minimized" then
		self:Restore()
	else
		self:Minimize()
	end
end

function Window:SetTitle(source)
	Kit.SetText(self.TitleLabel, source)
end

function Window:SetSubtitle(source)
	Kit.SetText(self.Subtitle, source)
end

function Window:SetIcon(name)
	Kit.SetIcon(self.IconImage, name)
	if self.LauncherIcon then
		Kit.SetIcon(self.LauncherIcon, name)
	end
end

function Window:Resize(size)
	self.Size = Vector2.new(size.X, size.Y)
	self:_applyLayout(true)
	self:_saveLayout()
end

function Window:Center()
	local metrics = Root.Metrics()
	local size = self.ShownSize or self.Size
	self.Position = Vector2.new(metrics.Insets.Left + (metrics.Safe.X - size.X) / 2, metrics.Insets.Top + (metrics.Safe.Y - size.Y) / 2)
	self:_applyLayout(true)
	self:_saveLayout()
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
	if self.KeyBind then
		self.KeyBind.Key = key
	end
	self.UI._toggleKeyChanged(key)
end

function Window:Notify(...)
	return self.UI.Notify(...)
end

function Window:OnDestroy()
	if self.KeyBind then
		self.KeyBind:Remove()
	end
	if self.Launcher then
		self.Launcher:Destroy()
	end
	self.UI._windowDestroyed(self)
end

-- Construction ------------------------------------------------------------------------------------------------------------------------
-- opts: Id, Title, Subtitle, Icon, Size (Vector2), MinSize, Position, ToggleKey, Footer, StartHidden, Resizable, Draggable, Search,
--       ToggleButton (nil = on touch devices), CloseDestroys
function WindowModule.Create(UI, opts)
	opts = opts or {}
	local id = Util.trim(tostring(opts.Id or (type(opts.Title) == "string" and opts.Title) or (type(opts.Title) == "table" and (opts.Title.en or opts.Title.vi)) or "Window"))
	local metrics = Root.Metrics()
	local titleHeight = Kit.Control() + 16
	local size = opts.Size or Vector2.new(720, 480)
	local shell = Create.New("Frame", { Name = "Window." .. id, Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.fromOffset(100, 80), Visible = false, Parent = Root.Windows })
	local pop = Create.New("Frame", { Name = "Pop", Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = shell })
	local popScale = Instance.new("UIScale")
	popScale.Scale = 0.95
	popScale.Parent = pop
	local body = Create.New("CanvasGroup", { Name = "Body", Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Bind = { BackgroundColor3 = "Background" }, Parent = pop })
	Create.Corner(body, "lg")
	Create.Stroke(body, "BorderStrong")

	local window = Kit.New(Window, shell, {
		UI = UI, Id = id, Pages = {}, PageList = {}, NavOrder = {}, Categories = {}, Search = {}, Body = body, PopScale = popScale,
		Size = size, MinSize = opts.MinSize or Vector2.new(440, 320), Position = Vector2.new(0, 0), State = "hidden", Token = 0, SwitchToken = 0,
		Resizable = opts.Resizable ~= false, Draggable = opts.Draggable ~= false, CloseDestroys = opts.CloseDestroys == true,
		ToggleKey = opts.ToggleKey or Enum.KeyCode.RightControl, Compact = metrics.Compact,
	})
	window.Shown = Signal.new()
	window.Hidden = Signal.new()
	window.PageChanged = Signal.new()
	window.SaveSoon = Util.Debounce(0.4, function()
		if window.Destroyed or not UI.LayoutDoc then
			return
		end
		local windows = UI.LayoutDoc.Data.Windows
		if type(windows) ~= "table" then
			windows = {}
			UI.LayoutDoc.Data.Windows = windows
		end
		windows[window.Id] = {
			X = window.Position.X, Y = window.Position.Y, W = window.Size.X, H = window.Size.Y,
			Minimized = window.State == "minimized", Page = window.Current and window.Current.Id or nil,
		}
		UI.LayoutDoc:Save()
	end)

	-- restore saved layout
	window.Restoring = true
	local saved = UI.LayoutDoc and type(UI.LayoutDoc.Data.Windows) == "table" and UI.LayoutDoc.Data.Windows[id]
	if type(saved) == "table" then
		if type(saved.W) == "number" and type(saved.H) == "number" then
			window.Size = Vector2.new(saved.W, saved.H)
		end
		if type(saved.X) == "number" and type(saved.Y) == "number" then
			window.Position = Vector2.new(saved.X, saved.Y)
		end
		window.SavedPage = type(saved.Page) == "string" and saved.Page or nil
		window.SavedMinimized = saved.Minimized == true
	else
		local insets = metrics.Insets
		window.Position = Vector2.new(insets.Left + (metrics.Safe.X - size.X) / 2, insets.Top + (metrics.Safe.Y - size.Y) / 2)
	end
	if opts.Position then
		window.Position = Vector2.new(opts.Position.X, opts.Position.Y)
	end

	-- title bar
	local titleBar = Create.New("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, titleHeight), ZIndex = 5, Bind = { BackgroundColor3 = "Sidebar" }, Parent = body })
	window.TitleBar = titleBar
	local line = Kit.Divider(titleBar)
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.ZIndex = 6
	local rightWidth = Kit.Control() * 3 + 20
	local dragArea = Create.New("Frame", { Name = "DragArea", Size = UDim2.new(1, -rightWidth, 1, 0), ZIndex = 5, Parent = titleBar })
	local left = 12
	window.MenuButton = Kit.Button(dragArea, { Icon = "menu", Variant = "ghost", Base = "Sidebar", Width = Kit.Control(), Position = UDim2.new(0, 6, 0.5, -Kit.Control() / 2), Tooltip = "window.menu", Callback = function()
		if window.DrawerOpen then
			window:CloseDrawer()
		else
			window:OpenDrawer()
		end
	end })
	window.MenuButton.Frame.ZIndex = 7
	window.Scope:Add(window.MenuButton)
	local iconWell = Create.New("Frame", { Name = "IconWell", Size = UDim2.fromOffset(32, 32), Position = UDim2.new(0, left, 0.5, -16), ZIndex = 6, Bind = { BackgroundColor3 = "PrimarySoft" }, Parent = dragArea })
	Create.Corner(iconWell, "sm")
	window.IconImage = Kit.Icon(iconWell, opts.Icon or "layout-dashboard", 18, "Primary", { Position = UDim2.new(0.5, -9, 0.5, -9), ZIndex = 7 })
	local function arrange()
		local offset = window.Compact and (Kit.Control() + 14) or 0
		iconWell.Position = UDim2.new(0, left + offset, 0.5, -16)
		window.TitleLabel.Position = UDim2.new(0, left + offset + 42, 0.5, -17)
		window.Subtitle.Position = UDim2.new(0, left + offset + 42, 0.5, 1)
	end
	window.TitleLabel = Kit.Text(dragArea, { Text = opts.Title or id, Size = 14, Weight = "Bold", SizeUDim = UDim2.new(1, -(left + 50), 0, 18), ZIndex = 6 })
	window.Subtitle = Kit.Text(dragArea, { Text = opts.Subtitle, Size = 11, Color = "TextMuted", SizeUDim = UDim2.new(1, -(left + 50), 0, 16), ZIndex = 6 })
	arrange()
	window.Arrange = arrange

	local right = Create.New("Frame", { Name = "Buttons", Size = UDim2.new(0, 0, 0, Kit.Control()), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = 7, Parent = titleBar })
	Create.List(right, { Dir = "H", Padding = 4 })
	window.ActionRow = right
	right:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		dragArea.Size = UDim2.new(1, -(right.AbsoluteSize.X / Root.Scale + 16), 1, 0)
	end)
	local function barButton(icon, tip, order, callback)
		local button = Kit.Button(right, { Icon = icon, Variant = "ghost", Base = "Sidebar", Width = Kit.Control(), Order = order, Tooltip = tip, Callback = callback })
		button.Frame.ZIndex = 8
		window.Scope:Add(button)
		return button
	end
	window.SearchButton = barButton("search", "window.search", 1, function()
		if window.SearchOpen then
			window:_closeSearch()
		else
			window:_openSearch()
		end
	end)
	window.SearchButton.Frame.Visible = opts.Search ~= false
	window.MinimizeButton = barButton("minus", "window.minimize", 2, function()
		window:ToggleMinimize()
	end)
	window.MinimizeIcon = window.MinimizeButton.IconImage
	window.CloseButton = barButton("x", "window.close", 3, function()
		window:Close()
	end)

	-- sidebar
	local sidebar = Create.New("Frame", { Name = "Sidebar", Position = UDim2.fromOffset(0, titleHeight), Size = UDim2.new(0, SIDE_W, 1, -titleHeight), Bind = { BackgroundColor3 = "Sidebar" }, ClipsDescendants = true, Parent = body })
	window.Sidebar = sidebar
	local sideLine = Kit.Divider(sidebar, { Vertical = true })
	sideLine.AnchorPoint = Vector2.new(1, 0)
	sideLine.Position = UDim2.fromScale(1, 0)
	local footer = Create.New("Frame", { Name = "Footer", Size = UDim2.new(1, 0, 0, opts.Footer and 36 or 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = sidebar })
	Kit.Text(footer, { Text = opts.Footer, Size = 11, Color = "TextFaint", Position = UDim2.fromOffset(14, 0), SizeUDim = UDim2.new(1, -28, 1, 0) })
	window.FooterFrame = footer
	local navScroll = Kit.Scroll(sidebar, { Size = UDim2.new(1, -1, 1, -(opts.Footer and 36 or 0)), Name = "NavScroll" })
	Create.Pad(navScroll, 8, 10, 8, 10)
	window.NavList = navScroll
	Create.List(navScroll, { Padding = 2 })

	-- content / pages
	local content = Create.New("Frame", { Name = "Content", Position = UDim2.fromOffset(SIDE_W, titleHeight), Size = UDim2.new(1, -SIDE_W, 1, -titleHeight), ClipsDescendants = true, Parent = body })
	window.Content = content
	window.PageHost = Create.New("CanvasGroup", { Name = "PageHost", Size = UDim2.fromScale(1, 1), Parent = content })

	-- search panel
	local panel = Create.New("Frame", { Name = "SearchPanel", Position = UDim2.fromOffset(0, titleHeight), Size = UDim2.new(1, 0, 1, -titleHeight), Visible = false, ZIndex = 20, Bind = { BackgroundColor3 = "Background" }, Parent = body })
	window.SearchPanel = panel
	local barHolder = Create.New("Frame", { Size = UDim2.new(1, -24, 0, Kit.Control()), Position = UDim2.fromOffset(12, 12), ZIndex = 21, Parent = panel })
	local Widgets = import("UI/Widgets")
	window.SearchBar = Widgets.SearchBar(barHolder, { OnChanged = function(text)
		window:_runSearch(text)
	end })
	window.Scope:Add(window.SearchBar)
	local results = Kit.Scroll(panel, { Size = UDim2.new(1, 0, 1, -(Kit.Control() + 24)), Position = UDim2.fromOffset(0, Kit.Control() + 24), ZIndex = 21 })
	Create.Pad(results, 12, 0, 12, 12)
	Create.List(results, { Padding = 4 })
	window.ResultList = results
	window.SearchEmpty = Create.New("Frame", { Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, Kit.Control() + 40), ZIndex = 22, Parent = panel })
	window.SearchEmptyText = Kit.Text(window.SearchEmpty, { Text = "window.search_hint", Size = 12, Color = "TextMuted", Align = "Center", SizeUDim = UDim2.fromScale(1, 1), ZIndex = 22 })

	-- drawer (phones)
	window.Scrim = Create.New("TextButton", { Name = "Scrim", Size = UDim2.new(1, 0, 1, -titleHeight), Position = UDim2.fromOffset(0, titleHeight), Text = "", BackgroundTransparency = 1, ZIndex = 30, Visible = false, Bind = { BackgroundColor3 = "Overlay" }, Parent = body })
	window.Scrim.Activated:Connect(function()
		window:CloseDrawer()
	end)
	window.Drawer = Create.New("Frame", { Name = "Drawer", Size = UDim2.new(0, 240, 1, -titleHeight), Position = UDim2.new(0, -250, 0, titleHeight), Visible = false, ZIndex = 31, Bind = { BackgroundColor3 = "Sidebar" }, Parent = body })
	Create.Stroke(window.Drawer, "Border")

	-- resize handle, input blocker
	local handle = Create.New("TextButton", { Name = "Resize", Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), Text = "", ZIndex = 40, Parent = shell })
	Kit.Icon(handle, "grip", 12, "TextFaint", { Position = UDim2.new(0.5, -6, 0.5, -6), ZIndex = 41 })
	window.ResizeHandle = handle
	window.Blocker = Create.New("TextButton", { Name = "Blocker", Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 100, Visible = false, Active = true, Parent = shell })

	-- dragging and resizing
	local startSize
	window.Scope:Add(Drag.Bind(dragArea, shell, {
		Enabled = function()
			return window.Draggable and not window.Compact and window.State ~= "hiding"
		end,
		Clamp = function(position, sz)
			local screen = Root.ScreenSize()
			local insets = Root.Insets()
			return Vector2.new(Util.clamp(position.X, insets.Left - sz.X + 120, screen.X - insets.Right - 120), Util.clamp(position.Y, insets.Top, screen.Y - insets.Bottom - 48))
		end,
		OnEnd = function(position)
			window.Position = position
			window:_saveLayout()
		end,
	}))
	window.Scope:Add(Input.Drag(handle, {
		Begin = function()
			startSize = Vector2.new(window.ShownSize.X, window.ShownSize.Y)
			local scroller = nil
			window.Resizing = true
		end,
		Move = function(delta)
			if not startSize then
				return
			end
			local metrics2 = Root.Metrics()
			local wanted = startSize + delta / Root.Scale
			window.Size = Vector2.new(Util.clamp(wanted.X, window.MinSize.X, math.max(window.MinSize.X, metrics2.Safe.X - MARGIN * 2)), Util.clamp(wanted.Y, window.MinSize.Y, math.max(window.MinSize.Y, metrics2.Safe.Y - MARGIN * 2)))
			window:_applyLayout(false)
		end,
		End = function()
			startSize = nil
			window.Resizing = false
			window:_saveLayout()
		end,
	}))

	-- relayout when the viewport changes
	window.Scope:Connect(Root.Changed, function()
		window:_applyLayout(false)
		window.Arrange()
	end)
	window.Scope:Connect(Services.UserInputService.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.Escape and window.SearchOpen then
			window:_closeSearch()
		end
	end)

	-- toggle key
	window.KeyBind = Keys.Register({ Key = window.ToggleKey, Allowed = function()
		return not Input.Typing() and not Keys.Capturing
	end, OnPress = function()
		window:Toggle()
	end })

	-- launcher (floating button) for touch
	local wantLauncher = opts.ToggleButton
	if wantLauncher == nil then
		wantLauncher = Input.Touch()
	end
	if wantLauncher then
		local launcher = Create.New("TextButton", { Name = "Launcher", Size = UDim2.fromOffset(46, 46), Text = "", ZIndex = 5, Bind = { BackgroundColor3 = "Primary" }, Parent = Root.HUDLayer })
		Create.Corner(launcher, "pill")
		Create.Stroke(launcher, "BorderStrong")
		window.LauncherIcon = Kit.Icon(launcher, opts.Icon or "layout-dashboard", 22, "PrimaryText", { Position = UDim2.new(0.5, -11, 0.5, -11), ZIndex = 6 })
		local saved2 = UI.GeneralDoc and UI.GeneralDoc.Data.LauncherPos
		local insets = metrics.Insets
		local start = Vector2.new(metrics.Screen.X - insets.Right - 62, insets.Top + 70)
		if type(saved2) == "table" and type(saved2.X) == "number" and type(saved2.Y) == "number" then
			start = Vector2.new(saved2.X, saved2.Y)
		end
		start = Drag.Fit(start, Vector2.new(46, 46), 6)
		launcher.Position = UDim2.fromOffset(start.X, start.Y)
		local pressedAt
		launcher.InputBegan:Connect(function(input)
			if Input.IsPrimary(input) then
				pressedAt = Vector2.new(launcher.Position.X.Offset, launcher.Position.Y.Offset)
			end
		end)
		window.Scope:Add(Drag.Bind(launcher, launcher, {
			OnEnd = function(position)
				if UI.GeneralDoc then
					UI.GeneralDoc:Set("LauncherPos", { X = position.X, Y = position.Y })
				end
			end,
		}))
		launcher.Activated:Connect(function()
			local now = Vector2.new(launcher.Position.X.Offset, launcher.Position.Y.Offset)
			if pressedAt and (now - pressedAt).Magnitude > 8 then
				return
			end
			window:Toggle()
		end)
		window.Launcher = launcher
		window.Scope:Add(Tooltip.Attach(launcher, "window.open_button"))
	end

	window:_applyLayout(false)
	window.Restoring = false
	window.PendingMinimize = window.SavedMinimized == true
	if not opts.StartHidden then
		window:Show(true)
	end
	return window
end

return WindowModule
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
		error("[DeaUI-S] missing module " .. tostring(name), 2)
	end
	if loading[name] then
		error("[DeaUI-S] circular import " .. tostring(name), 2)
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
Library.Import = import
return Library
