return function(AimPage, AimbotAPI)
	local AimSection = AimPage:Section({
		Name = "Aimbot",
		Description = "advanced aimbot",
		Icon = "10709818534",
		Side = 2
	})

	AimSection:Toggle({
		Name = "Enable",
		Flag = "AimbotEnable",
		Default = false,
		Callback = function(Value)
			AimbotAPI:UpdateConfig({Enabled = Value})
			AimbotAPI:Toggle(Value)
		end
	})

	AimSection:Slider({
		Name = "FOV Size",
		Flag = "AimbotFOV",
		Min = 1,
		Max = 500,
		Default = 100,
		Decimals = 1,
		Suffix = "px",
		Callback = function(Value)
			AimbotAPI:UpdateConfig({FOVSize = Value})
		end
	})

	AimSection:Label("FOV Color"):Colorpicker({
		Name = "FOV Color",
		Flag = "AimbotFOVColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			AimbotAPI:UpdateConfig({FOVColor = Value})
		end
	})

	AimSection:Slider({
		Name = "Aim Speed",
		Flag = "AimbotSpeed",
		Min = 1,
		Max = 100,
		Default = 50,
		Decimals = 1,
		Suffix = "%",
		Callback = function(Value)
			AimbotAPI:UpdateConfig({Speed = Value / 100})
		end
	})

	AimSection:Slider({
		Name = "Max Range",
		Flag = "AimbotRange",
		Min = 1,
		Max = 10000,
		Default = 5000,
		Decimals = 1,
		Suffix = "m",
		Callback = function(Value)
			AimbotAPI:UpdateConfig({MaxRange = Value})
		end
	})

	AimSection:Toggle({
		Name = "Team Check",
		Flag = "AimbotTeamCheck",
		Default = false,
		Callback = function(Value)
			AimbotAPI:UpdateConfig({TeamCheck = Value})
		end
	})

	AimSection:Toggle({
		Name = "Wall Check",
		Flag = "AimbotWallCheck",
		Default = false,
		Callback = function(Value)
			AimbotAPI:UpdateConfig({WallCheck = Value})
		end
	})

	AimSection:Dropdown({
		Name = "Aim Part",
		Flag = "AimbotPart",
		Default = "Head",
		Items = {"Head", "UpperTorso", "LowerTorso"},
		Multi = false,
		Callback = function(Value)
			if type(Value) == "table" then
				AimbotAPI:UpdateConfig({AimPart = Value[1]})
			else
				AimbotAPI:UpdateConfig({AimPart = Value})
			end
		end
	})

	AimSection:Toggle({
		Name = "Lock Target",
		Flag = "AimbotLockTarget",
		Default = false,
		Callback = function(Value)
			AimbotAPI:UpdateConfig({LockTarget = Value})
		end
	})

	AimSection:Toggle({
		Name = "Prediction",
		Flag = "AimbotPrediction",
		Default = false,
		Callback = function(Value)
			AimbotAPI:UpdateConfig({PredictionEnabled = Value})
		end
	})

	AimSection:Slider({
		Name = "Prediction Factor",
		Flag = "AimbotPredictionFactor",
		Min = 0.01,
		Max = 1,
		Default = 0.12,
		Decimals = 0.01,
		Suffix = "x",
		Callback = function(Value)
			AimbotAPI:UpdateConfig({PredictionFactor = Value})
		end
	})

	AimSection:Slider({
		Name = "Vertical Offset",
		Flag = "AimbotVerticalOffset",
		Min = -1,
		Max = 1,
		Default = 0,
		Decimals = 0.1,
		Suffix = "m",
		Callback = function(Value)
			AimbotAPI:UpdateConfig({OffsetY = Value})
		end
	})

	AimSection:Slider({
		Name = "FOV Vertical Offset",
		Flag = "AimbotFOVVerticalOffset",
		Min = -100,
		Max = 100,
		Default = 0,
		Decimals = 1,
		Suffix = "px",
		Callback = function(Value)
			AimbotAPI:UpdateConfig({FOVOffsetY = Value})
		end
	})
end
