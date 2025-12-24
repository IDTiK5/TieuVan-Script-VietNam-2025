return function(AimbotTab, Config)
	-- ===== CHỨC NĂNG CHÍNH =====
	AimbotTab:Toggle({
		Name = "Bật Aimbot",
		Flag = "AimbotEnabled",
		Default = false,
		Callback = function(value)
			Config.Enabled = value
		end
	})

	AimbotTab:Dropdown({
		Name = "Kiểu Aim",
		Flag = "AimMethod",
		Items = {"Camera", "Mouse", "Hybrid"},
		Default = "Camera",
		Callback = function(value)
			Config.AimMethod = value
		end
	})

	AimbotTab:Slider({
		Name = "Tốc độ Aim",
		Flag = "AimSpeed",
		Min = 0.1,
		Max = 1,
		Default = 0.5,
		Round = 2,
		Callback = function(value)
			Config.Speed = value
		end
	})

	AimbotTab:Slider({
		Name = "Phạm vi",
		Flag = "AimRange",
		Min = 100,
		Max = 5000,
		Default = 5000,
		Round = 0,
		Callback = function(value)
			Config.Range = value
		end
	})

	AimbotTab:Dropdown({
		Name = "Mục tiêu chính",
		Flag = "TargetPart",
		Items = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
		Default = "Head",
		Callback = function(value)
			Config.Target = value
		end
	})

	AimbotTab:Dropdown({
		Name = "Độ ưu tiên mục tiêu",
		Flag = "TargetPriority",
		Items = {"Head", "HumanoidRootPart", "UpperTorso"},
		Default = "Head",
		Callback = function(value)
			Config.TargetPriority = {value, "HumanoidRootPart", "UpperTorso"}
		end
	})

	-- ===== KHÓA MỤC TIÊU =====
	AimbotTab:Toggle({
		Name = "Khóa mục tiêu",
		Flag = "LockTarget",
		Default = false,
		Callback = function(value)
			Config.LockEnabled = value
		end
	})

	AimbotTab:Toggle({
		Name = "Phá khóa khi chết",
		Flag = "LockBreakOnDeath",
		Default = false,
		Callback = function(value)
			Config.LockBreakOnDeath = value
		end
	})

	AimbotTab:Toggle({
		Name = "Sticky Aim",
		Flag = "StickyAimEnabled",
		Default = false,
		Callback = function(value)
			Config.StickyAim.Enabled = value
		end
	})

	AimbotTab:Slider({
		Name = "Sticky Multiplier",
		Flag = "StickyMultiplier",
		Min = 1,
		Max = 3,
		Default = 1.5,
		Round = 2,
		Callback = function(value)
			Config.StickyAim.Multiplier = value
		end
	})

	AimbotTab:Slider({
		Name = "Sticky Break Distance",
		Flag = "StickyBreakDistance",
		Min = 100,
		Max = 500,
		Default = 300,
		Round = 0,
		Callback = function(value)
			Config.StickyAim.BreakDistance = value
		end
	})

	-- ===== DỰ ĐOÁN VỊ TRÍ =====
	AimbotTab:Toggle({
		Name = "Dự đoán vị trí",
		Flag = "PredictionEnabled",
		Default = false,
		Callback = function(value)
			Config.Prediction.Enabled = value
		end
	})

	AimbotTab:Dropdown({
		Name = "Chế độ dự đoán",
		Flag = "PredictionMode",
		Items = {"Linear", "Quadratic", "Adaptive"},
		Default = "Linear",
		Callback = function(value)
			Config.Prediction.Mode = value
		end
	})

	AimbotTab:Slider({
		Name = "Hệ số dự đoán",
		Flag = "PredictionFactor",
		Min = 0.05,
		Max = 0.5,
		Default = 0.12,
		Round = 2,
		Callback = function(value)
			Config.Prediction.Factor = value
		end
	})

	AimbotTab:Slider({
		Name = "Velocity Smooth",
		Flag = "VelocitySmooth",
		Min = 0.1,
		Max = 1,
		Default = 0.5,
		Round = 2,
		Callback = function(value)
			Config.Prediction.VelocitySmooth = value
		end
	})

	AimbotTab:Toggle({
		Name = "AI Prediction",
		Flag = "AIPredictionEnabled",
		Default = false,
		Callback = function(value)
			Config.Prediction.AIEnabled = value
		end
	})

	AimbotTab:Slider({
		Name = "AI Strength",
		Flag = "AIStrength",
		Min = 0.1,
		Max = 1,
		Default = 0.5,
		Round = 2,
		Callback = function(value)
			Config.Prediction.AIStrength = value
		end
	})

	AimbotTab:Toggle({
		Name = "AI Adaptive",
		Flag = "AIAdaptive",
		Default = false,
		Callback = function(value)
			Config.Prediction.AIAdaptive = value
		end
	})

	AimbotTab:Slider({
		Name = "History Size",
		Flag = "HistorySize",
		Min = 5,
		Max = 30,
		Default = 10,
		Round = 0,
		Callback = function(value)
			Config.Prediction.HistorySize = value
		end
	})

	AimbotTab:Slider({
		Name = "Acceleration Factor",
		Flag = "AccelerationFactor",
		Min = 0.1,
		Max = 1,
		Default = 0.2,
		Round = 2,
		Callback = function(value)
			Config.Prediction.AccelerationFactor = value
		end
	})

	AimbotTab:Slider({
		Name = "Direction Weight",
		Flag = "DirectionWeight",
		Min = 0.1,
		Max = 1,
		Default = 0.7,
		Round = 2,
		Callback = function(value)
			Config.Prediction.DirectionWeight = value
		end
	})

	-- ===== LÀMCHÉM =====
	AimbotTab:Dropdown({
		Name = "Kiểu Smoothing",
		Flag = "SmoothingType",
		Items = {"Linear", "OutQuad", "OutCubic", "OutQuart", "OutQuint", "OutExpo", "InOutSine", "OutBack", "OutElastic"},
		Default = "OutQuad",
		Callback = function(value)
			Config.Smoothing.EaseType = value
		end
	})

	AimbotTab:Slider({
		Name = "Mouse Sensitivity",
		Flag = "MouseSensitivity",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Round = 2,
		Callback = function(value)
			Config.MouseSensitivity = value
		end
	})

	AimbotTab:Slider({
		Name = "Offset Correction X",
		Flag = "OffsetCorrectionX",
		Min = -100,
		Max = 100,
		Default = 0,
		Round = 0,
		Callback = function(value)
			Config.OffsetCorrection = Vector3.new(value, Config.OffsetCorrection.Y, Config.OffsetCorrection.Z)
		end
	})

	AimbotTab:Slider({
		Name = "Offset Correction Y",
		Flag = "OffsetCorrectionY",
		Min = -100,
		Max = 100,
		Default = 0,
		Round = 0,
		Callback = function(value)
			Config.OffsetCorrection = Vector3.new(Config.OffsetCorrection.X, value, Config.OffsetCorrection.Z)
		end
	})

	AimbotTab:Slider({
		Name = "Offset Correction Z",
		Flag = "OffsetCorrectionZ",
		Min = -100,
		Max = 100,
		Default = 0,
		Round = 0,
		Callback = function(value)
			Config.OffsetCorrection = Vector3.new(Config.OffsetCorrection.X, Config.OffsetCorrection.Y, value)
		end
	})

	-- ===== FOV =====
	AimbotTab:Slider({
		Name = "Kích thước FOV",
		Flag = "FOVSize",
		Min = 50,
		Max = 500,
		Default = 100,
		Round = 0,
		Callback = function(value)
			Config.FOV.Size = value
		end
	})

	AimbotTab:Slider({
		Name = "FOV Offset X",
		Flag = "FOVOffsetX",
		Min = -200,
		Max = 200,
		Default = 0,
		Round = 0,
		Callback = function(value)
			Config.FOV.OffsetX = value
		end
	})

	AimbotTab:Slider({
		Name = "FOV Offset Y",
		Flag = "FOVOffsetY",
		Min = -200,
		Max = 200,
		Default = 0,
		Round = 0,
		Callback = function(value)
			Config.FOV.OffsetY = value
		end
	})

	AimbotTab:ColorPicker({
		Name = "Màu FOV",
		Flag = "FOVColor",
		Color = Color3.fromRGB(255, 255, 255),
		Callback = function(color)
			Config.FOV.Color = color
		end
	})

	AimbotTab:Toggle({
		Name = "Rainbow FOV",
		Flag = "RainbowFOV",
		Default = false,
		Callback = function(value)
			Config.FOV.Rainbow.Enabled = value
		end
	})

	AimbotTab:Slider({
		Name = "Tốc độ Rainbow",
		Flag = "RainbowSpeed",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Round = 1,
		Callback = function(value)
			Config.FOV.Rainbow.Speed = value
		end
	})

	AimbotTab:Toggle({
		Name = "Ẩn FOV",
		Flag = "FOVHidden",
		Default = false,
		Callback = function(value)
			Config.FOV.Hidden = value
		end
	})

	AimbotTab:Button({
		Name = "Reset FOV to Default",
		Callback = function()
			Config.FOV.Size = Config.FOV.DefaultSize
			Config.FOV.OffsetX = Config.FOV.DefaultOffsetX
			Config.FOV.OffsetY = Config.FOV.DefaultOffsetY
		end
	})

	-- ===== AUTO SWITCH =====
	AimbotTab:Toggle({
		Name = "Auto Switch Target",
		Flag = "AutoSwitchEnabled",
		Default = false,
		Callback = function(value)
			Config.AutoSwitch.Enabled = value
		end
	})

	AimbotTab:Slider({
		Name = "Switch Delay",
		Flag = "SwitchDelay",
		Min = 0.1,
		Max = 1,
		Default = 0.3,
		Round = 2,
		Callback = function(value)
			Config.AutoSwitch.Delay = value
		end
	})

	-- ===== CHUYỂN ĐỘNG =====
	AimbotTab:Dropdown({
		Name = "Movement Mode",
		Flag = "MovementMode",
		Items = {"Both", "Standing", "Running"},
		Default = "Both",
		Callback = function(value)
			Config.MovementMode.Mode = value
		end
	})

	AimbotTab:Slider({
		Name = "Standing Threshold",
		Flag = "StandingThreshold",
		Min = 0,
		Max = 10,
		Default = 2,
		Round = 1,
		Callback = function(value)
			Config.MovementMode.StandingThreshold = value
		end
	})

	AimbotTab:Slider({
		Name = "Running Threshold",
		Flag = "RunningThreshold",
		Min = 0,
		Max = 50,
		Default = 10,
		Round = 1,
		Callback = function(value)
			Config.MovementMode.RunningThreshold = value
		end
	})

	-- ===== KIỂM TRA =====
	AimbotTab:Toggle({
		Name = "Kiểm tra sống",
		Flag = "AliveCheckEnabled",
		Default = false,
		Callback = function(value)
			Config.AliveCheck = value
		end
	})

	AimbotTab:Toggle({
		Name = "Kiểm tra tường",
		Flag = "WallCheckEnabled",
		Default = false,
		Callback = function(value)
			Config.WallCheck = value
		end
	})

	AimbotTab:Toggle({
		Name = "Kiểm tra Team",
		Flag = "TeamCheckEnabled",
		Default = false,
		Callback = function(value)
			Config.TeamCheck = value
		end
	})

	-- ===== SILENT AIM =====
	AimbotTab:Toggle({
		Name = "Silent Aim",
		Flag = "SilentAimEnabled",
		Default = false,
		Callback = function(value)
			Config.SilentAim.Enabled = value
		end
	})

	AimbotTab:Slider({
		Name = "Silent Aim Hit Chance",
		Flag = "SilentAimHitChance",
		Min = 0,
		Max = 1,
		Default = 1,
		Round = 2,
		Callback = function(value)
			Config.SilentAim.HitChance = value
		end
	})

	-- ===== VISIBILITY DOT =====
	AimbotTab:Toggle({
		Name = "Visibility Dot",
		Flag = "VisibilityDotEnabled",
		Default = false,
		Callback = function(value)
			Config.VisibilityDot.Enabled = value
		end
	})

	AimbotTab:Slider({
		Name = "Visibility Dot Size",
		Flag = "VisibilityDotSize",
		Min = 1,
		Max = 20,
		Default = 5,
		Round = 0,
		Callback = function(value)
			Config.VisibilityDot.Size = value
		end
	})

	AimbotTab:ColorPicker({
		Name = "Visibility Dot Color",
		Flag = "VisibilityDotColor",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(color)
			Config.VisibilityDot.Color = color
		end
	})

	AimbotTab:Toggle({
		Name = "Visibility Dot Filled",
		Flag = "VisibilityDotFilled",
		Default = false,
		Callback = function(value)
			Config.VisibilityDot.Filled = value
		end
	})

	AimbotTab:Slider({
		Name = "Visibility Dot Transparency",
		Flag = "VisibilityDotTransparency",
		Min = 0,
		Max = 1,
		Default = 0,
		Round = 2,
		Callback = function(value)
			Config.VisibilityDot.Transparency = value
		end
	})

	AimbotTab:Toggle({
		Name = "Visibility Dot Outline",
		Flag = "VisibilityDotOutline",
		Default = false,
		Callback = function(value)
			Config.VisibilityDot.OutlineEnabled = value
		end
	})

	AimbotTab:ColorPicker({
		Name = "Visibility Dot Outline Color",
		Flag = "VisibilityDotOutlineColor",
		Color = Color3.fromRGB(0, 0, 0),
		Callback = function(color)
			Config.VisibilityDot.OutlineColor = color
		end
	})

	AimbotTab:Slider({
		Name = "Visibility Dot Outline Thickness",
		Flag = "VisibilityDotOutlineThickness",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Round = 1,
		Callback = function(value)
			Config.VisibilityDot.OutlineThickness = value
		end
	})

	-- ===== HITBOX =====
	AimbotTab:Toggle({
		Name = "Hitbox Enabled",
		Flag = "HitboxEnabled",
		Default = false,
		Callback = function(value)
			Config.Hitbox.Enabled = value
		end
	})

	AimbotTab:Dropdown({
		Name = "Hitbox Mode",
		Flag = "HitboxMode",
		Items = {"Head", "Body", "Both"},
		Default = "Head",
		Callback = function(value)
			Config.Hitbox.Mode = value
		end
	})

	AimbotTab:Slider({
		Name = "Hitbox Head Size",
		Flag = "HitboxHeadSize",
		Min = 0.5,
		Max = 5,
		Default = 2,
		Round = 1,
		Callback = function(value)
			Config.Hitbox.HeadSize = value
		end
	})

	AimbotTab:Slider({
		Name = "Hitbox Body Size",
		Flag = "HitboxBodySize",
		Min = 0.5,
		Max = 5,
		Default = 1.5,
		Round = 1,
		Callback = function(value)
			Config.Hitbox.BodySize = value
		end
	})

	AimbotTab:ColorPicker({
		Name = "Hitbox Color",
		Flag = "HitboxColor",
		Color = Color3.fromRGB(255, 0, 255),
		Callback = function(color)
			Config.Hitbox.Color = color
		end
	})

	AimbotTab:Slider({
		Name = "Hitbox Transparency",
		Flag = "HitboxTransparency",
		Min = 0,
		Max = 1,
		Default = 0.7,
		Round = 2,
		Callback = function(value)
			Config.Hitbox.Transparency = value
		end
	})

	AimbotTab:Toggle({
		Name = "Hitbox Visible Only",
		Flag = "HitboxVisibleOnly",
		Default = false,
		Callback = function(value)
			Config.Hitbox.VisibleOnly = value
		end
	})

	-- ===== CÀI ĐẶT NÂNG CAO =====
	AimbotTab:Slider({
		Name = "Update Rate",
		Flag = "UpdateRate",
		Min = 1,
		Max = 10,
		Default = 1,
		Round = 0,
		Callback = function(value)
			Config.UpdateRate = value
		end
	})

	AimbotTab:Toggle({
		Name = "Debug Mode",
		Flag = "DebugModeEnabled",
		Default = false,
		Callback = function(value)
			Config.Debug = value
		end
	})

	-- ===== NÚT HÀNH ĐỘNG =====
	AimbotTab:Button({
		Name = "Bỏ khóa mục tiêu",
		Callback = function()
			Config.State.LockedPlayer = nil
			Config.State.CurrentTarget = nil
		end
	})

	AimbotTab:Button({
		Name = "Reset Velocity Cache",
		Callback = function()
			Config.State.VelocityCache = {}
		end
	})

	AimbotTab:Button({
		Name = "Reset Movement History",
		Callback = function()
			Config.State.MovementHistory = {}
		end
	})

	AimbotTab:Button({
		Name = "Reset Acceleration Cache",
		Callback = function()
			Config.State.AccelerationCache = {}
		end
	})

	AimbotTab:Button({
		Name = "Reset tất cả",
		Callback = function()
			Config.State.LockedPlayer = nil
			Config.State.CurrentTarget = nil
			Config.State.VelocityCache = {}
			Config.State.MovementHistory = {}
			Config.State.AccelerationCache = {}
			Config.State.RainbowHue = 0
			Config.State.FrameCount = 0
			Config.State.SmoothedVelocity = {}
			Config.State.VisibilityDots = {}
			Config.State.HitboxParts = {}
		end
	})
end
