return function(EspPage, NameESPAPI)
	local Section = EspPage:Section({
		Name = "Name ESP",
		Description = "Display player names",
		Icon = "113157514619684",
		Side = 2
	})

	Section:Toggle({
		Name = "Name ESP",
		Flag = "NameESP",
		Default = false,
		Callback = function(Value)
			NameESPAPI:UpdateConfig({Enabled = Value})
			NameESPAPI:Toggle(Value)
		end
	})

	Section:Toggle({
		Name = "Hide Player Names",
		Flag = "HidePlayerNames",
		Default = false,
		Callback = function(Value)
			NameESPAPI:UpdateConfig({HidePlayerNames = Value})
		end
	})

	Section:Toggle({
		Name = "Team Check",
		Flag = "NameTeamCheck",
		Default = false,
		Callback = function(Value)
			NameESPAPI:UpdateConfig({EnableTeamCheck = Value})
		end
	})

	Section:Toggle({
		Name = "Enemy Only",
		Flag = "NameEnemyOnly",
		Default = false,
		Callback = function(Value)
			NameESPAPI:UpdateConfig({ShowEnemyOnly = Value})
		end
	})

	Section:Toggle({
		Name = "Allied Only",
		Flag = "NameAlliedOnly",
		Default = false,
		Callback = function(Value)
			NameESPAPI:UpdateConfig({ShowAlliedOnly = Value})
		end
	})

	Section:Slider({
		Name = "Name Text Size",
		Flag = "NameTextSize",
		Min = 6,
		Max = 24,
		Default = 8,
		Decimals = 1,
		Suffix = "px",
		Callback = function(Value)
			NameESPAPI:UpdateConfig({NameTextSize = Value})
		end
	})

	Section:Toggle({
		Name = "Use Team Colors",
		Flag = "NameUseTeamColors",
		Default = false,
		Callback = function(Value)
			NameESPAPI:UpdateConfig({UseTeamColors = Value})
		end
	})

	Section:Toggle({
		Name = "Use Actual Team Colors",
		Flag = "NameUseActualTeamColors",
		Default = true,
		Callback = function(Value)
			NameESPAPI:UpdateConfig({UseActualTeamColors = Value})
		end
	})

	Section:Label("Name Color"):Colorpicker({
		Name = "Name Color",
		Flag = "NameColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			NameESPAPI:UpdateConfig({NameColor = Value})
		end
	})

	Section:Label("Enemy Color"):Colorpicker({
		Name = "Enemy Name Color",
		Flag = "EnemyNameColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			NameESPAPI:UpdateConfig({EnemyNameColor = Value})
		end
	})

	Section:Label("Allied Color"):Colorpicker({
		Name = "Allied Name Color",
		Flag = "AlliedNameColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			NameESPAPI:UpdateConfig({AlliedNameColor = Value})
		end
	})

	Section:Label("No Team Color"):Colorpicker({
		Name = "No Team Color",
		Flag = "NameNoTeamColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			NameESPAPI:UpdateConfig({NoTeamColor = Value})
		end
	})
end
