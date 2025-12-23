return function(AimbotTab, Config)
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
		Default = true,
		Callback = function(value)
			Config.LockBreakOnDeath = value
		end
	})

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

	AimbotTab:ColorPicker({
		Name = "Màu FOV",
		Flag = "FOVColor",
		Color = Color3.fromRGB(255, 255, 255),
		Callback = function(color)
			Config.FOV.Color = color
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
		Name = "Dự đoán vị trí",
		Flag = "PredictionEnabled",
		Default = false,
		Callback = function(value)
			Config.Prediction.Enabled = value
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
		Name = "Velocity Smooth",
		Flag = "VelocitySmooth",
		Min = 0,
		Max = 0.9,
		Default = 0.5,
		Round = 2,
		Callback = function(value)
			Config.Prediction.VelocitySmooth = value
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
		Round = 1,
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

	AimbotTab:Toggle({
		Name = "Kiểm tra Team",
		Flag = "TeamCheckEnabled",
		Default = false,
		Callback = function(value)
			Config.TeamCheck = value
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
		Name = "Kiểm tra sống",
		Flag = "AliveCheckEnabled",
		Default = true,
		Callback = function(value)
			Config.AliveCheck = value
		end
	})

	AimbotTab:Slider({
		Name = "Mouse Sensitivity",
		Flag = "MouseSensitivity",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Round = 1,
		Callback = function(value)
			Config.MouseSensitivity = value
		end
	})

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
		Min = 1,
		Max = 100,
		Default = 100,
		Round = 0,
		Callback = function(value)
			Config.SilentAim.HitChance = value
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
		Name = "Reset tất cả",
		Callback = function()
			Config.State.LockedPlayer = nil
			Config.State.CurrentTarget = nil
			Config.State.VelocityCache = {}
			Config.State.RainbowHue = 0
			Config.State.FrameCount = 0
		end
	})
end
