return function(EspPage, TracerESPAPI)
	local Section = EspPage:Section({
		Name = "Tracer",
		Description = "Draw tracers to players",
		Icon = "10734942351",
		Side = 1
	})

	Section:Toggle({
		Name = "Enabled",
		Flag = "TracerEnabled",
		Default = false,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({Enabled = Value})
			TracerESPAPI:Toggle(Value)
		end
	})

	Section:Dropdown({
		Name = "Origin",
		Flag = "TracerOrigin",
		Default = "Top",
		Items = {"Top", "Bottom", "Center", "Mouse"},
		Multi = false,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({Origin = Value})
		end
	})

	Section:Dropdown({
		Name = "Target",
		Flag = "TracerTarget",
		Default = "Head",
		Items = {"Head", "Torso", "Feet", "Center"},
		Multi = false,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({Target = Value})
		end
	})

	Section:Slider({
		Name = "Transparency",
		Flag = "TracerTransparency",
		Min = 0,
		Max = 1,
		Default = 1,
		Decimals = 0.1,
		Suffix = "",
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({TracerTransparency = Value})
		end
	})

	Section:Slider({
		Name = "Offset X",
		Flag = "TracerOffsetX",
		Min = -50,
		Max = 50,
		Default = 0,
		Decimals = 1,
		Suffix = "px",
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({OffsetX = Value})
		end
	})

	Section:Slider({
		Name = "Offset Y",
		Flag = "TracerOffsetY",
		Min = -50,
		Max = 50,
		Default = 0,
		Decimals = 1,
		Suffix = "px",
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({OffsetY = Value})
		end
	})

	Section:Label("Tracer Color"):Colorpicker({
		Name = "Color",
		Flag = "TracerColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({TracerColor = Value})
		end
	})

	Section:Toggle({
		Name = "Team Check",
		Flag = "TracerTeamCheck",
		Default = false,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({EnableTeamCheck = Value})
		end
	})

	Section:Toggle({
		Name = "Show Enemy Only",
		Flag = "TracerShowEnemyOnly",
		Default = false,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({ShowEnemyOnly = Value})
			if Value then
				TracerESPAPI:UpdateConfig({ShowAlliedOnly = false})
			end
		end
	})

	Section:Toggle({
		Name = "Show Allied Only",
		Flag = "TracerShowAlliedOnly",
		Default = false,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({ShowAlliedOnly = Value})
			if Value then
				TracerESPAPI:UpdateConfig({ShowEnemyOnly = false})
			end
		end
	})

	Section:Toggle({
		Name = "Alive Only",
		Flag = "TracerAliveOnly",
		Default = true,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({AliveOnly = Value})
		end
	})

	Section:Toggle({
		Name = "Draw Offscreen",
		Flag = "TracerDrawOffscreen",
		Default = true,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({DrawOffscreen = Value})
		end
	})

	Section:Toggle({
		Name = "Use Team Colors",
		Flag = "TracerUseTeamColors",
		Default = false,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({UseTeamColors = Value})
		end
	})

	Section:Toggle({
		Name = "Use Actual Team Colors",
		Flag = "TracerUseActualTeamColors",
		Default = true,
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({UseActualTeamColors = Value})
		end
	})

	Section:Label("Enemy Color"):Colorpicker({
		Name = "Enemy",
		Flag = "TracerEnemyColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({EnemyTracerColor = Value})
		end
	})

	Section:Label("Allied Color"):Colorpicker({
		Name = "Allied",
		Flag = "TracerAlliedColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({AlliedTracerColor = Value})
		end
	})

	Section:Label("No Team Color"):Colorpicker({
		Name = "No Team Color",
		Flag = "TracerNoTeamColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			TracerESPAPI:UpdateConfig({NoTeamColor = Value})
		end
	})
end
