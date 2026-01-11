return function(espPage, ChamsAPI)
	local ChamsSection = espPage:Section({
		Name = "Chams ESP",
		Description = "Highlight players through walls",
		Icon = "10709782230",
		Side = 2
	})

	ChamsSection:Toggle({
		Name = "Enable Chams",
		Flag = "ChamsToggle",
		Default = false,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({enabled = Value})
			ChamsAPI:Toggle(Value)
		end
	})

	ChamsSection:Toggle({
		Name = "Team Check",
		Flag = "ChamsTeamCheck",
		Default = false,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({EnableTeamCheck = Value})
		end
	})

	ChamsSection:Toggle({
		Name = "Enemy Only",
		Flag = "ChamsEnemyOnly",
		Default = false,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({ShowEnemyOnly = Value})
		end
	})

	ChamsSection:Toggle({
		Name = "Allied Only",
		Flag = "ChamsAlliedOnly",
		Default = false,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({ShowAlliedOnly = Value})
		end
	})

	ChamsSection:Toggle({
		Name = "Use Visibility Colors",
		Flag = "ChamsVisibilityColors",
		Default = false,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({useVisibilityColors = Value})
		end
	})

	ChamsSection:Toggle({
		Name = "Use Raycasting",
		Flag = "ChamsRaycasting",
		Default = false,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({useRaycasting = Value})
		end
	})

	ChamsSection:Dropdown({
		Name = "Depth Mode",
		Flag = "ChamsDepthMode",
		Default = "AlwaysOnTop",
		Items = {"AlwaysOnTop", "Occluded"},
		Multi = false,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({depthMode = Value})
		end
	})

	ChamsSection:Slider({
		Name = "Max Distance",
		Flag = "ChamsMaxDistance",
		Min = 0,
		Max = 50000,
		Default = 10000,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({maxDistance = Value})
		end
	})

	ChamsSection:Slider({
		Name = "Batch Size",
		Flag = "ChamsBatchSize",
		Min = 1,
		Max = 20,
		Default = 5,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({batchSize = Value})
		end
	})

	ChamsSection:Slider({
		Name = "Update Interval",
		Flag = "ChamsUpdateInterval",
		Min = 0.01,
		Max = 0.5,
		Default = 0.05,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({updateInterval = Value})
		end
	})

	ChamsSection:Slider({
		Name = "Fill Transparency",
		Flag = "ChamsFillTransparency",
		Min = 0,
		Max = 1,
		Default = 0.5,
		Decimals = 0.01,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({fillTransparency = Value})
		end
	})

	ChamsSection:Slider({
		Name = "Outline Transparency",
		Flag = "ChamsOutlineTransparency",
		Min = 0,
		Max = 1,
		Default = 0,
		Decimals = 0.01,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({outlineTransparency = Value})
		end
	})

	ChamsSection:Toggle({
		Name = "Use Team Colors",
		Flag = "ChamsUseTeamColors",
		Default = false,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({UseTeamColors = Value})
		end
	})

	ChamsSection:Toggle({
		Name = "Use Actual Team Colors",
		Flag = "ChamsUseActualTeamColors",
		Default = true,
		Callback = function(Value)
			ChamsAPI:UpdateConfig({UseActualTeamColors = Value})
		end
	})

	ChamsSection:Label("Fill Color"):Colorpicker({
		Name = "Fill Color",
		Flag = "ChamsFillColor",
		Default = Color3.fromRGB(0, 255, 140),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({fillColor = Value})
		end
	})

	ChamsSection:Label("Outline Color"):Colorpicker({
		Name = "Outline Color",
		Flag = "ChamsOutlineColor",
		Default = Color3.fromRGB(0, 255, 140),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({outlineColor = Value})
		end
	})

	ChamsSection:Label("Enemy Fill Color"):Colorpicker({
		Name = "Enemy Fill Color",
		Flag = "ChamsEnemyFillColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({EnemyFillColor = Value})
		end
	})

	ChamsSection:Label("Enemy Outline Color"):Colorpicker({
		Name = "Enemy Outline Color",
		Flag = "ChamsEnemyOutlineColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({EnemyOutlineColor = Value})
		end
	})

	ChamsSection:Label("Allied Fill Color"):Colorpicker({
		Name = "Allied Fill Color",
		Flag = "ChamsAlliedFillColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({AlliedFillColor = Value})
		end
	})

	ChamsSection:Label("Allied Outline Color"):Colorpicker({
		Name = "Allied Outline Color",
		Flag = "ChamsAlliedOutlineColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({AlliedOutlineColor = Value})
		end
	})

	ChamsSection:Label("No Team Color"):Colorpicker({
		Name = "No Team Color",
		Flag = "ChamsNoTeamColor",
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({NoTeamColor = Value})
		end
	})

	ChamsSection:Label("Visible Fill Color"):Colorpicker({
		Name = "Visible Fill Color",
		Flag = "ChamsVisibleFillColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({visibleFillColor = Value})
		end
	})

	ChamsSection:Label("Visible Outline Color"):Colorpicker({
		Name = "Visible Outline Color",
		Flag = "ChamsVisibleOutlineColor",
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({visibleOutlineColor = Value})
		end
	})

	ChamsSection:Label("Hidden Fill Color"):Colorpicker({
		Name = "Hidden Fill Color",
		Flag = "ChamsHiddenFillColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({hiddenFillColor = Value})
		end
	})

	ChamsSection:Label("Hidden Outline Color"):Colorpicker({
		Name = "Hidden Outline Color",
		Flag = "ChamsHiddenOutlineColor",
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({hiddenOutlineColor = Value})
		end
	})
end
