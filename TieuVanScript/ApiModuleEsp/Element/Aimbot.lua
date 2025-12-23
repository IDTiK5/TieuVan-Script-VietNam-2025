return function(aimTab, AimbotAPI)
	aimTab:Toggle({
		Name = "Bật Aimbot",
		Flag = "AimbotEnabled",
		Default = false,
		Callback = function(value)
			AimbotAPI.Enabled = value
		end
	})

	aimTab:Dropdown({
		Name = "Kiểu Aim",
		Flag = "AimMethod",
		Items = {"Camera", "Mouse", "Hybrid"},
		Default = "Camera",
		Callback = function(value)
			AimbotAPI.AimMethod = value
		end
	})

	aimTab:Slider({
		Name = "Tốc độ Aim",
		Flag = "AimSpeed",
		Min = 0.1,
		Max = 1,
		Default = 0.5,
		Round = 2,
		Callback = function(value)
			AimbotAPI.Speed = value
		end
	})

	aimTab:Slider({
		Name = "Phạm vi",
		Flag = "AimRange",
		Min = 100,
		Max = 5000,
		Default = 5000,
		Round = 0,
		Callback = function(value)
			AimbotAPI.Range = value
		end
	})

	aimTab:Dropdown({
		Name = "Mục tiêu chính",
		Flag = "TargetPart",
		Items = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
		Default = "Head",
		Callback = function(value)
			AimbotAPI.Target = value
		end
	})

	aimTab:Toggle({
		Name = "Khóa mục tiêu",
		Flag = "LockTarget",
		Default = false,
		Callback = function(value)
			AimbotAPI.LockEnabled = value
		end
	})

	aimTab:Toggle({
		Name = "Phá khóa khi chết",
		Flag = "LockBreakOnDeath",
		Default = true,
		Callback = function(value)
			AimbotAPI.LockBreakOnDeath = value
		end
	})

	aimTab:Dropdown({
		Name = "Kiểu Smoothing",
		Flag = "SmoothingType",
		Items = {"Linear", "OutQuad", "OutCubic", "OutQuart", "OutQuint", "OutExpo", "InOutSine", "OutBack", "OutElastic"},
		Default = "OutQuad",
		Callback = function(value)
			AimbotAPI.Smoothing.EaseType = value
		end
	})

	aimTab:Slider({
		Name = "Kích thước FOV",
		Flag = "FOVSize",
		Min = 50,
		Max = 500,
		Default = 100,
		Round = 0,
		Callback = function(value)
			AimbotAPI.FOV.Size = value
		end
	})

	aimTab:ColorPicker({
		Name = "Màu FOV",
		Flag = "FOVColor",
		Color = Color3.fromRGB(255, 255, 255),
		Callback = function(color)
			AimbotAPI.FOV.Color = color
		end
	})

	aimTab:Toggle({
		Name = "Ẩn FOV",
		Flag = "FOVHidden",
		Default = false,
		Callback = function(value)
			AimbotAPI.FOV.Hidden = value
		end
	})

	aimTab:Toggle({
		Name = "Rainbow FOV",
		Flag = "RainbowFOV",
		Default = false,
		Callback = function(value)
			AimbotAPI.FOV.Rainbow.Enabled = value
		end
	})

	aimTab:Slider({
		Name = "Tốc độ Rainbow",
		Flag = "RainbowSpeed",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Round = 1,
		Callback = function(value)
			AimbotAPI.FOV.Rainbow.Speed = value
		end
	})

	aimTab:Toggle({
		Name = "Dự đoán vị trí",
		Flag = "PredictionEnabled",
		Default = false,
		Callback = function(value)
			AimbotAPI.Prediction.Enabled = value
		end
	})

	aimTab:Slider({
		Name = "Hệ số dự đoán",
		Flag = "PredictionFactor",
		Min = 0.05,
		Max = 0.5,
		Default = 0.12,
		Round = 2,
		Callback = function(value)
			AimbotAPI.Prediction.Factor = value
		end
	})

	aimTab:Dropdown({
		Name = "Chế độ dự đoán",
		Flag = "PredictionMode",
		Items = {"Linear", "Quadratic", "Adaptive"},
		Default = "Linear",
		Callback = function(value)
			AimbotAPI.Prediction.Mode = value
		end
	})

	aimTab:Slider({
		Name = "Velocity Smooth",
		Flag = "VelocitySmooth",
		Min = 0,
		Max = 0.9,
		Default = 0.5,
		Round = 2,
		Callback = function(value)
			AimbotAPI.Prediction.VelocitySmooth = value
		end
	})

	aimTab:Toggle({
		Name = "Sticky Aim",
		Flag = "StickyAimEnabled",
		Default = false,
		Callback = function(value)
			AimbotAPI.StickyAim.Enabled = value
		end
	})

	aimTab:Slider({
		Name = "Sticky Multiplier",
		Flag = "StickyMultiplier",
		Min = 1,
		Max = 3,
		Default = 1.5,
		Round = 1,
		Callback = function(value)
			AimbotAPI.StickyAim.Multiplier = value
		end
	})

	aimTab:Slider({
		Name = "Sticky Break Distance",
		Flag = "StickyBreakDistance",
		Min = 100,
		Max = 500,
		Default = 300,
		Round = 0,
		Callback = function(value)
			AimbotAPI.StickyAim.BreakDistance = value
		end
	})

	aimTab:Toggle({
		Name = "Auto Switch Target",
		Flag = "AutoSwitchEnabled",
		Default = false,
		Callback = function(value)
			AimbotAPI.AutoSwitch.Enabled = value
		end
	})

	aimTab:Slider({
		Name = "Switch Delay",
		Flag = "SwitchDelay",
		Min = 0.1,
		Max = 1,
		Default = 0.3,
		Round = 2,
		Callback = function(value)
			AimbotAPI.AutoSwitch.Delay = value
		end
	})

	aimTab:Toggle({
		Name = "Kiểm tra Team",
		Flag = "TeamCheckEnabled",
		Default = false,
		Callback = function(value)
			AimbotAPI.TeamCheck = value
		end
	})

	aimTab:Toggle({
		Name = "Kiểm tra tường",
		Flag = "WallCheckEnabled",
		Default = false,
		Callback = function(value)
			AimbotAPI.WallCheck = value
		end
	})

	aimTab:Toggle({
		Name = "Kiểm tra sống",
		Flag = "AliveCheckEnabled",
		Default = true,
		Callback = function(value)
			AimbotAPI.AliveCheck = value
		end
	})

	aimTab:Slider({
		Name = "Mouse Sensitivity",
		Flag = "MouseSensitivity",
		Min = 0.1,
		Max = 5,
		Default = 1,
		Round = 1,
		Callback = function(value)
			AimbotAPI.MouseSensitivity = value
		end
	})

	aimTab:Slider({
		Name = "Update Rate",
		Flag = "UpdateRate",
		Min = 1,
		Max = 10,
		Default = 1,
		Round = 0,
		Callback = function(value)
			AimbotAPI.UpdateRate = value
		end
	})

	aimTab:Toggle({
		Name = "Silent Aim",
		Flag = "SilentAimEnabled",
		Default = false,
		Callback = function(value)
			AimbotAPI.SilentAim.Enabled = value
		end
	})

	aimTab:Slider({
		Name = "Silent Aim Hit Chance",
		Flag = "SilentAimHitChance",
		Min = 1,
		Max = 100,
		Default = 100,
		Round = 0,
		Callback = function(value)
			AimbotAPI.SilentAim.HitChance = value
		end
	})

	aimTab:Toggle({
		Name = "Debug Mode",
		Flag = "DebugModeEnabled",
		Default = false,
		Callback = function(value)
			AimbotAPI.Debug = value
		end
	})

	aimTab:Button({
		Name = "Bỏ khóa mục tiêu",
		Callback = function()
			AimbotAPI.State.LockedPlayer = nil
			AimbotAPI.State.CurrentTarget = nil
		end
	})

	aimTab:Button({
		Name = "Reset Velocity Cache",
		Callback = function()
			AimbotAPI.State.VelocityCache = {}
		end
	})

	aimTab:Button({
		Name = "Reset tất cả",
		Callback = function()
			AimbotAPI.State.LockedPlayer = nil
			AimbotAPI.State.CurrentTarget = nil
			AimbotAPI.State.VelocityCache = {}
			AimbotAPI.State.RainbowHue = 0
			AimbotAPI.State.FrameCount = 0
		end
	})
end
