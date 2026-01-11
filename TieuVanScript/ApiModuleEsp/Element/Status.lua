return function(EspPage, StatusESPAPI)
	local Section = EspPage:Section({
		Name = "Info ESP",
		Description = "Show distance and status info",
		Icon = "113157514619684",
		Side = 1
	})

	Section:Toggle({
		Name = "Enable Info ESP",
		Flag = "InfoESPToggle",
		Default = false,
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({Enabled = Value})
			StatusESPAPI:Toggle(Value)
		end
	})

	Section:Toggle({
		Name = "Show Distance",
		Flag = "ShowDistance",
		Default = true,
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({ShowDistance = Value})
		end
	})

	Section:Toggle({
		Name = "Show Status",
		Flag = "ShowStatus",
		Default = true,
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({ShowStatus = Value})
		end
	})

	Section:Toggle({
		Name = "Team Check",
		Flag = "InfoTeamCheck",
		Default = false,
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({EnableTeamCheck = Value})
		end
	})

	Section:Toggle({
		Name = "Enemy Only",
		Flag = "InfoEnemyOnly",
		Default = false,
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({ShowEnemyOnly = Value})
		end
	})

	Section:Toggle({
		Name = "Allied Only",
		Flag = "InfoAlliedOnly",
		Default = false,
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({ShowAlliedOnly = Value})
		end
	})

	Section:Slider({
		Name = "Distance Text Size",
		Flag = "DistanceTextSize",
		Min = 6,
		Max = 20,
		Default = 8,
		Decimals = 1,
		Suffix = "px",
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({DistanceTextSize = Value})
		end
	})

	Section:Slider({
		Name = "Status Text Size",
		Flag = "StatusTextSize",
		Min = 6,
		Max = 20,
		Default = 8,
		Decimals = 1,
		Suffix = "px",
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({StatusTextSize = Value})
		end
	})

	Section:Toggle({
		Name = "Use Team Colors",
		Flag = "InfoUseTeamColors",
		Default = false,
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({UseTeamColors = Value})
		end
	})

	Section:Toggle({
		Name = "Use Actual Team Colors",
		Flag = "InfoUseActualTeamColors",
		Default = true,
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({UseActualTeamColors = Value})
		end
	})

	Section:Label("Distance Color"):Colorpicker({
		Name = "Distance Color",
		Flag = "DistanceColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({DistanceColor = Value})
		end
	})

	Section:Label("Status Color"):Colorpicker({
		Name = "Status Color",
		Flag = "StatusColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({StatusColor = Value})
		end
	})

	Section:Label("Enemy Color"):Colorpicker({
		Name = "Enemy Info Color",
		Flag = "EnemyInfoColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({EnemyInfoColor = Value})
		end
	})

	Section:Label("Allied Color"):Colorpicker({
		Name = "Allied Info Color",
		Flag = "AlliedInfoColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({AlliedInfoColor = Value})
		end
	})

	Section:Label("No Team Color"):Colorpicker({
		Name = "No Team Color",
		Flag = "InfoNoTeamColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			StatusESPAPI:UpdateConfig({NoTeamColor = Value})
		end
	})
end
