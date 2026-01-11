return function(page, ChamsAPI)
	-- Tạo Section cho Chams
	local ChamsSection = page:Section({
		Name = "Chams ESP",
		Description = "Highlight players through walls"
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
		List = {"AlwaysOnTop", "Occluded"},
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
		Increment = 0.01,
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
		Increment = 0.01,
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
		Increment = 0.01,
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

	ChamsSection:Color({
		Name = "Fill Color",
		Flag = "ChamsFillColor",
		Color = Color3.fromRGB(0, 255, 140),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({fillColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Outline Color",
		Flag = "ChamsOutlineColor",
		Color = Color3.fromRGB(0, 255, 140),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({outlineColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Enemy Fill Color",
		Flag = "ChamsEnemyFillColor",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({EnemyFillColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Enemy Outline Color",
		Flag = "ChamsEnemyOutlineColor",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({EnemyOutlineColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Allied Fill Color",
		Flag = "ChamsAlliedFillColor",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({AlliedFillColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Allied Outline Color",
		Flag = "ChamsAlliedOutlineColor",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({AlliedOutlineColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "No Team Color",
		Flag = "ChamsNoTeamColor",
		Color = Color3.fromRGB(255, 255, 255),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({NoTeamColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Visible Fill Color",
		Flag = "ChamsVisibleFillColor",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({visibleFillColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Visible Outline Color",
		Flag = "ChamsVisibleOutlineColor",
		Color = Color3.fromRGB(0, 255, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({visibleOutlineColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Hidden Fill Color",
		Flag = "ChamsHiddenFillColor",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({hiddenFillColor = Value})
		end
	})

	ChamsSection:Color({
		Name = "Hidden Outline Color",
		Flag = "ChamsHiddenOutlineColor",
		Color = Color3.fromRGB(255, 0, 0),
		Callback = function(Value)
			ChamsAPI:UpdateConfig({hiddenOutlineColor = Value})
		end
	})
end
